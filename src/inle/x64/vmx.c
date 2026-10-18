// vmx -- svm.c's Intel twin: enable VMX, build one VMCS, run a seven-byte 32-bit guest that
// loads a sentinel and executes CPUID, and take the exit back in C. the guest runs paged under
// EPT, so the gate's laws pass only if both translations happened. physical is va - khhdm,
// true of heap memory and not of image statics: everything is carved from one k_vmx_need block
#include "k.h"
#include "asmops.h"
#include <stdint.h>

#define msr_feature_control 0x3au
#define msr_vmx_basic       0x480u
#define msr_vmx_pinbased    0x481u
#define msr_vmx_procbased   0x482u
#define msr_vmx_exit        0x483u
#define msr_vmx_entry       0x484u
#define msr_vmx_cr0_fixed0  0x486u
#define msr_vmx_cr0_fixed1  0x487u
#define msr_vmx_cr4_fixed0  0x488u
#define msr_vmx_cr4_fixed1  0x489u
// the TRUE_* capability MSRs: only when IA32_VMX_BASIC bit 55 says so, else reading one faults
#define msr_vmx_true_pin    0x48du
#define msr_vmx_true_proc   0x48eu
#define msr_vmx_true_exit   0x48fu
#define msr_vmx_true_entry  0x490u
#define msr_vmx_proc2       0x48bu   // the secondary controls' allowed bits
#define msr_vmx_ept_cap     0x48cu   // IA32_VMX_EPT_VPID_CAP

// VMCS field encodings (arch/x86/include/asm/vmx.h's numbers)
#define f_vpid              0x0000
#define f_guest_es_sel      0x0800
#define f_guest_tr_sel      0x080e
#define f_host_es_sel       0x0c00
#define f_host_cs_sel       0x0c02
#define f_host_tr_sel       0x0c0c
#define f_eptp              0x201a
#define f_vmcs_link         0x2800
#define f_pin_ctl           0x4000
#define f_cpu_ctl           0x4002
#define f_excep_bitmap      0x4004
#define f_cr3_target_count  0x400a
#define f_exit_ctl          0x400c
#define f_exit_msr_store    0x400e
#define f_exit_msr_load     0x4010
#define f_entry_ctl         0x4012
#define f_entry_msr_load    0x4014
#define f_entry_intr        0x4016
#define f_secondary_ctl     0x401e
#define f_vm_insn_error     0x4400
#define f_exit_reason       0x4402
#define f_guest_es_limit    0x4800
#define f_guest_gdtr_limit  0x4810
#define f_guest_idtr_limit  0x4812
#define f_guest_es_ar       0x4814
#define f_guest_ldtr_ar     0x4820
#define f_guest_tr_ar       0x4822
#define f_guest_intr_state  0x4824
#define f_guest_activity    0x4826
#define f_guest_sysenter_cs 0x482a
#define f_host_sysenter_cs  0x4c00
#define f_cr0_mask          0x6000
#define f_cr4_mask          0x6002
#define f_cr0_shadow        0x6004
#define f_cr4_shadow        0x6006
#define f_guest_cr0         0x6800
#define f_guest_cr3         0x6802
#define f_guest_cr4         0x6804
#define f_guest_es_base     0x6806
#define f_guest_tr_base     0x6814
#define f_guest_gdtr_base   0x6816
#define f_guest_idtr_base   0x6818
#define f_guest_dr7         0x681a
#define f_guest_rsp         0x681c
#define f_guest_rip         0x681e
#define f_guest_rflags      0x6820
#define f_guest_pending_dbg 0x6822
#define f_guest_sysenter_sp 0x6824
#define f_guest_sysenter_ip 0x6826
#define f_host_cr0          0x6c00
#define f_host_cr3          0x6c02
#define f_host_cr4          0x6c04
#define f_host_fs_base      0x6c06
#define f_host_gs_base      0x6c08
#define f_host_tr_base      0x6c0a
#define f_host_gdtr_base    0x6c0c
#define f_host_idtr_base    0x6c0e
#define f_host_sysenter_sp  0x6c10
#define f_host_sysenter_ip  0x6c12

// the segment fields march 2 apart: es cs ss ds fs gs ldtr tr
#define seg_es 0
#define seg_cs 1
#define seg_ss 2
#define seg_ds 3
#define seg_fs 4
#define seg_gs 5
#define seg_ldtr 6
#define seg_tr 7

#define vmx_pg     4096u
// vmxon, VMCS, guest code, its directory, GDT, TSS, four EPT levels
#define vmx_pages  10u
// guest-physical, made so only by the EPT
#define gpa_code   0x0000u
#define gpa_pd     0x1000u
#define vmx_sentinel 0x1234u
// our GDT's 64-bit TSS descriptor, index 3
#define vmx_tr_sel 0x18u

uintptr_t k_vmx_need(void) { return vmx_pages * vmx_pg + vmx_pg - 1; }

static void vmx_zero(unsigned char *p, uintptr_t n) { while (n--) *p++ = 0; }
static uint64_t pa_of(void const *va) { return (uint64_t) ((uintptr_t) va - khhdm); }
static void w64(unsigned char *p, uintptr_t off, uint64_t v) {
  *(uint64_t*) (p + off) = v; }

// a control word fit to the capability MSR (low half must be 1, high half may be): a misfit
// is a refused entry with no other symptom
static uint32_t ctl_fit(uint32_t msr, uint32_t want) {
  uint64_t m = k_rdmsr(msr);
  return (want | (uint32_t) m) & (uint32_t) (m >> 32); }

// VMX offered and reachable: locked with outside-SMX clear is the BIOS's off, and CR4.VMXE
// would then triple fault
bool k_vmx_ok(void) {
  uint32_t b, c, d;
  k_cpuid(1, &b, &c, &d);
  if (!(c & (1u << 5))) return false;                    // ECX.VMX
  uint64_t fc = k_rdmsr(msr_feature_control);
  if ((fc & 1) && !(fc & (1u << 2))) return false;       // locked, and locked OFF
  // EPT is required: secondary controls, a 4-level walk, write-back
  if (!(k_rdmsr(msr_vmx_procbased) & (1ull << 63))) return false;   // secondary allowed
  if (!(k_rdmsr(msr_vmx_proc2) & (1ull << 33))) return false;       // ..and EPT among them
  uint64_t ec = k_rdmsr(msr_vmx_ept_cap);
  return (ec & (1ull << 6)) && (ec & (1ull << 14)); }  // 4-level walk, write-back

int k_vmx_spike(void *mem, uint64_t *reason, uint64_t *rax, uint64_t *rip,
                uint64_t *err) {
  if (!k_vmx_ok()) return -1;
  unsigned char *base = (unsigned char*)
    (((uintptr_t) mem + vmx_pg - 1) & ~(uintptr_t) (vmx_pg - 1));
  unsigned char *vmxon = base,
                *vmcs  = base + 1 * vmx_pg,
                *guest = base + 2 * vmx_pg,
                *gpd   = base + 3 * vmx_pg,   // the guest's 4 MiB-page directory
                *gdt   = base + 4 * vmx_pg,
                *tss   = base + 5 * vmx_pg,
                *ept4  = base + 6 * vmx_pg,   // the four EPT levels, pml4 down to pt
                *ept3  = base + 7 * vmx_pg,
                *ept2  = base + 8 * vmx_pg,
                *ept1  = base + 9 * vmx_pg;
  vmx_zero(base, vmx_pages * vmx_pg);

  // CPUID exits unconditionally under VMX; the hlt is a backstop
  guest[0] = 0xb8;                                       // mov eax, imm32
  guest[1] = (unsigned char) (vmx_sentinel & 0xff);
  guest[2] = (unsigned char) (vmx_sentinel >> 8);
  guest[3] = 0; guest[4] = 0;
  guest[5] = 0x0f; guest[6] = 0xa2;                      // cpuid
  guest[7] = 0xf4;                                       // hlt

  // the guest's own paging: 4 MiB pages, linear onto guest-physical one to one
  for (uint32_t i = 0; i < 1024; i++)
    *(uint32_t*) (gpd + 4 * i) = (i << 22) | 0x83u;      // present, write, PS

  // the EPT maps just the two pages; a leaf needs a memory type (bits 5:3, write-back 6) or
  // the entry is refused
  w64(ept4, 0, pa_of(ept3) | 0x7);                       // read | write | execute
  w64(ept3, 0, pa_of(ept2) | 0x7);
  w64(ept2, 0, pa_of(ept1) | 0x7);
  w64(ept1, 8 * (gpa_code >> 12), pa_of(guest) | 0x7 | (6u << 3));
  w64(ept1, 8 * (gpa_pd >> 12), pa_of(gpd) | 0x7 | (6u << 3));

  // our own GDT, since host TR may not be 0. the boot descriptors are written, not copied: the
  // live GDTR base predates paging. an exit loads this GDTR, so the foot puts the old one back
  unsigned char gdtr[10], idtr[10];
  k_sgdt(gdtr);
  k_sidt(idtr);
  w64(gdt, 0x00, 0);
  w64(gdt, 0x08, 0x00209a0000000000ull);                 // mkboot.l's code selector
  w64(gdt, 0x10, 0x0000920000000000ull);                 // ..and its data twin
  // limit 0x67, type 9 (available), present
  uint64_t tb = (uint64_t) (uintptr_t) tss;
  w64(gdt, 0x18, 0x67u | ((tb & 0xffffffu) << 16) | (0x89ull << 40)
                 | (((tb >> 24) & 0xffu) << 56));
  w64(gdt, 0x20, tb >> 32);

  // enable: CR4.VMXE, both control registers' fixed bits, the revision ids
  uint64_t fc = k_rdmsr(msr_feature_control);
  if (!(fc & 1)) k_wrmsr(msr_feature_control, fc | 5);   // lock it on, ours to set
  uint64_t cr4 = k_rd_cr4() | (1ull << 13);              // CR4.VMXE
  cr4 = (cr4 | k_rdmsr(msr_vmx_cr4_fixed0)) & k_rdmsr(msr_vmx_cr4_fixed1);
  k_wr_cr4(cr4);
  // CR0 written back, not just computed: vmxon #GPs unless the live CR0 has FIXED0's NE
  uint64_t cr0 = (k_rd_cr0() | k_rdmsr(msr_vmx_cr0_fixed0))
                 & k_rdmsr(msr_vmx_cr0_fixed1);
  k_wr_cr0(cr0);

  uint64_t basic = k_rdmsr(msr_vmx_basic);
  *(uint32_t*) vmxon = (uint32_t) basic & 0x7fffffffu;
  *(uint32_t*) vmcs  = (uint32_t) basic & 0x7fffffffu;
  uint32_t true_msrs = (basic >> 55) & 1;

  uint64_t pa = pa_of(vmxon);
  k_vmxon(&pa);
  pa = pa_of(vmcs);
  k_vmclear(&pa);
  k_vmptrld(&pa);

  // the controls
  k_vmwrite(f_pin_ctl, ctl_fit(true_msrs ? msr_vmx_true_pin : msr_vmx_pinbased, 0));
  k_vmwrite(f_cpu_ctl, ctl_fit(true_msrs ? msr_vmx_true_proc : msr_vmx_procbased,
                               1u << 31));              // activate secondary controls
  // the secondary word has no TRUE_ twin
  k_vmwrite(f_secondary_ctl, ctl_fit(msr_vmx_proc2, 1u << 1));
  // EPTP: write-back (6), walk length 4 given as 3
  k_vmwrite(f_eptp, pa_of(ept4) | 6u | (3u << 3));
  k_vmwrite(f_exit_ctl, ctl_fit(true_msrs ? msr_vmx_true_exit : msr_vmx_exit,
                                1u << 9));               // host address-space size
  k_vmwrite(f_entry_ctl, ctl_fit(true_msrs ? msr_vmx_true_entry : msr_vmx_entry, 0));
  k_vmwrite(f_excep_bitmap, 0);
  k_vmwrite(f_cr3_target_count, 0);
  k_vmwrite(f_exit_msr_store, 0);
  k_vmwrite(f_exit_msr_load, 0);
  k_vmwrite(f_entry_msr_load, 0);
  k_vmwrite(f_entry_intr, 0);
  k_vmwrite(f_vpid, 0);
  k_vmwrite(f_cr0_mask, 0);
  k_vmwrite(f_cr4_mask, 0);
  // ~0, not 0: zero is a shadow VMCS pointer, and refused
  k_vmwrite(f_vmcs_link, ~0ull);

  // host state: all an exit restores, the general registers excepted
  k_vmwrite(f_host_cr0, cr0);
  k_vmwrite(f_host_cr3, k_rd_cr3());
  k_vmwrite(f_host_cr4, cr4);
  k_vmwrite(f_host_cs_sel, 0x08);
  // es ss ds fs gs: the host fields run es cs ss ds fs gs tr
  for (int s = 0; s < 7; s++)
    if (s != 1 && s != 6) k_vmwrite(f_host_es_sel + 2 * s, 0x10);
  k_vmwrite(f_host_tr_sel, vmx_tr_sel);
  k_vmwrite(f_host_tr_base, tb);
  k_vmwrite(f_host_gdtr_base, (uintptr_t) gdt);
  k_vmwrite(f_host_idtr_base, *(uint64_t const*) (idtr + 2));
  k_vmwrite(f_host_fs_base, 0);
  k_vmwrite(f_host_gs_base, 0);
  k_vmwrite(f_host_sysenter_cs, 0);
  k_vmwrite(f_host_sysenter_sp, 0);
  k_vmwrite(f_host_sysenter_ip, 0);

  // guest state, every segment based at 0: rip reads 5 at the exit, as svm's does
  uint64_t gcr0 = (0x80000021ull | k_rdmsr(msr_vmx_cr0_fixed0))
                  & k_rdmsr(msr_vmx_cr0_fixed1);         // PG | NE | PE
  uint64_t gcr4 = ((1ull << 4) | k_rdmsr(msr_vmx_cr4_fixed0))
                  & k_rdmsr(msr_vmx_cr4_fixed1);         // CR4.PSE
  k_vmwrite(f_guest_cr0, gcr0);
  k_vmwrite(f_guest_cr3, gpa_pd);                        // a GUEST-physical address now
  k_vmwrite(f_guest_cr4, gcr4);
  k_vmwrite(f_cr0_shadow, gcr0);
  k_vmwrite(f_cr4_shadow, gcr4);
  for (int s = 0; s < 8; s++) {
    k_vmwrite(f_guest_es_sel + 2 * s, s == seg_cs ? 0x08 :
                                      s == seg_tr ? vmx_tr_sel :
                                      s == seg_ldtr ? 0 : 0x10);
    k_vmwrite(f_guest_es_base + 2 * s, s == seg_tr ? tb : 0);
    k_vmwrite(f_guest_es_limit + 2 * s, s == seg_tr ? 0x67 : 0xffffffffu);
    // 32-bit code and data, an unusable ldtr (bit 16), a busy TSS: tr may not be unusable
    k_vmwrite(f_guest_es_ar + 2 * s, s == seg_cs ? 0xc09b :
                                     s == seg_ldtr ? 0x10000 :
                                     s == seg_tr ? 0x8b : 0xc093);
  }
  k_vmwrite(f_guest_gdtr_base, (uintptr_t) gdt);
  k_vmwrite(f_guest_gdtr_limit, 0x2f);
  k_vmwrite(f_guest_idtr_base, 0);
  k_vmwrite(f_guest_idtr_limit, 0xffff);
  k_vmwrite(f_guest_dr7, 0x400);
  k_vmwrite(f_guest_rsp, 0);
  k_vmwrite(f_guest_rip, 0);
  k_vmwrite(f_guest_rflags, 0x2);                        // bit 1 reads 1, always
  k_vmwrite(f_guest_pending_dbg, 0);
  k_vmwrite(f_guest_intr_state, 0);
  k_vmwrite(f_guest_activity, 0);
  k_vmwrite(f_guest_sysenter_cs, 0);
  k_vmwrite(f_guest_sysenter_sp, 0);
  k_vmwrite(f_guest_sysenter_ip, 0);

  int bad = k_vmlaunch(rax);
  *reason = bad ? 0 : (k_vmread(f_exit_reason) & 0xffff);
  *rip = bad ? 0 : k_vmread(f_guest_rip);
  *err = bad ? k_vmread(f_vm_insn_error) : 0;
  // the GDT back before these pages stop being ours, and VMX off for the next ask
  k_lgdt(gdtr);
  k_vmxoff();
  return bad ? 1 : 0; }
