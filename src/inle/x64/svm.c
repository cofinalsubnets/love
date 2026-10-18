// svm -- the AMD-V spike: a six-byte real-mode guest loads a sentinel and runs CPUID, and the
// intercept comes back as three numbers for the gate. vmrun returns in line, so the exit is plain C.
// a physical address is va - khhdm, true of kernel-heap memory, not image statics: everything is
// carved from the caller's k_svm_need() block. no state: the VMCB is rebuilt every run
#include "k.h"
#include "asmops.h"
#include <stdint.h>

// the VMCB by byte offset (AMD APM vol 2 appendix B): control at 0, guest save state at 0x400
#define vmcb_icept3   0x00c    // INTR..SHUTDOWN: CPUID is bit 18, HLT bit 24
#define vmcb_icept4   0x010    // VMRUN is bit 0
#define vmcb_iopm     0x040
#define vmcb_msrpm    0x048
#define vmcb_asid     0x058
#define vmcb_exitcode 0x070
#define vmcb_es       0x400    // a segment is u16 sel, u16 attrib, u32 limit, u64 base
#define vmcb_cs       0x410
#define vmcb_ss       0x420
#define vmcb_ds       0x430
#define vmcb_cpl      0x4cb
#define vmcb_efer     0x4d0
#define vmcb_cr4      0x548
#define vmcb_cr3      0x550
#define vmcb_cr0      0x558
#define vmcb_rflags   0x570
#define vmcb_rip      0x578
#define vmcb_rax      0x5f8

#define msr_efer      0xc0000080u
#define msr_vm_cr     0xc0010114u
#define msr_vm_hsave  0xc0010117u
#define efer_svme     (1ull << 12)

#define svm_pg        4096u
// hsave, guest VMCB, host VMCB, guest code a page each; IOPM three, MSRPM two
#define svm_pages     9u
// read back from the VMCB, it proves a guest instruction retired, not just that entry was accepted
#define svm_sentinel  0x1234u

uintptr_t k_svm_need(void) { return svm_pages * svm_pg + svm_pg - 1; }

static void svm_zero(unsigned char *p, uintptr_t n) { while (n--) *p++ = 0; }
static void w16(unsigned char *p, uintptr_t off, uint16_t v) {
  *(uint16_t*) (p + off) = v; }
static void w32(unsigned char *p, uintptr_t off, uint32_t v) {
  *(uint32_t*) (p + off) = v; }
static void w64(unsigned char *p, uintptr_t off, uint64_t v) {
  *(uint64_t*) (p + off) = v; }
static uint64_t r64(unsigned char const *p, uintptr_t off) {
  return *(uint64_t const*) (p + off); }
static uint64_t pa_of(void const *va) { return (uint64_t) ((uintptr_t) va - khhdm); }

// one VMCB segment: selector, attributes, limit, base
static void wseg(unsigned char *v, uintptr_t off, uint16_t attr, uint64_t base) {
  w16(v, off, 0); w16(v, off + 2, attr);
  w32(v, off + 4, 0xffff); w64(v, off + 8, base); }

// CPUID before VM_CR, which does not exist without the SVM bit; SVMDIS set would #GP the EFER
// write into a triple fault. no max-leaf probe: Fn8000_000A exists exactly when ECX.SVM is set
bool k_svm_ok(void) {
  uint32_t b, c, d;
  k_cpuid(0x80000001u, &b, &c, &d);
  if (!(c & (1u << 2))) return false;                 // ECX.SVM
  if (k_rdmsr(msr_vm_cr) & (1u << 4)) return false;   // VM_CR.SVMDIS
  k_cpuid(0x8000000au, &b, &c, &d);
  return b > 1; }                                     // ASIDs: we use 1

// one guest: 0 and the three outs, or -1 without SVM
int k_svm_spike(void *mem, uint64_t *exitcode, uint64_t *rax, uint64_t *rip) {
  if (!k_svm_ok()) return -1;
  unsigned char *base = (unsigned char*)
    (((uintptr_t) mem + svm_pg - 1) & ~(uintptr_t) (svm_pg - 1));
  unsigned char *hsave = base,
                *vmcb  = base + 1 * svm_pg,
                *hvmcb = base + 2 * svm_pg,
                *guest = base + 3 * svm_pg,
                *iopm  = base + 4 * svm_pg,
                *msrpm = base + 7 * svm_pg;
  svm_zero(base, svm_pages * svm_pg);

  // saved RIP is the cpuid's own address (an intercept reports the instruction itself);
  // the hlt is an intercepted backstop, reached only if the cpuid intercept did not fire
  guest[0] = 0xb8;                                    // mov ax, imm16
  guest[1] = (unsigned char) (svm_sentinel & 0xff);
  guest[2] = (unsigned char) (svm_sentinel >> 8);
  guest[3] = 0x0f; guest[4] = 0xa2;                   // cpuid
  guest[5] = 0xf4;                                    // hlt

  // consistency checks, each alone exit -1 (INVALID): the VMRUN intercept set, a nonzero ASID,
  // and (below) the guest's EFER.SVME
  w32(vmcb, vmcb_icept3, (1u << 18) | (1u << 24));    // CPUID, HLT
  w32(vmcb, vmcb_icept4, 1u);                         // VMRUN
  w64(vmcb, vmcb_iopm, pa_of(iopm));
  w64(vmcb, vmcb_msrpm, pa_of(msrpm));
  w32(vmcb, vmcb_asid, 1);

  // no nested or guest paging: guest physical is host physical, so CS's base is the code page
  wseg(vmcb, vmcb_cs, 0x009b, pa_of(guest));          // present, code, readable
  wseg(vmcb, vmcb_es, 0x0093, 0);                     // present, data, writable
  wseg(vmcb, vmcb_ss, 0x0093, 0);
  wseg(vmcb, vmcb_ds, 0x0093, 0);
  vmcb[vmcb_cpl] = 0;
  w64(vmcb, vmcb_efer, efer_svme);
  w64(vmcb, vmcb_cr4, 0);
  w64(vmcb, vmcb_cr3, 0);
  w64(vmcb, vmcb_cr0, 0x10);                          // ET; PE and PG clear -> real mode
  w64(vmcb, vmcb_rflags, 0x2);                        // bit 1 reads 1, always
  w64(vmcb, vmcb_rip, 0);
  w64(vmcb, vmcb_rax, 0);

  k_wrmsr(msr_efer, k_rdmsr(msr_efer) | efer_svme);
  k_wrmsr(msr_vm_hsave, pa_of(hsave));

  // clgi so no interrupt lands mid-entry; vmsave/vmload what vmrun does not carry; stgi last,
  // as #VMEXIT leaves GIF clear and the machine deaf
  k_clgi();
  k_vmsave(pa_of(hvmcb));
  k_vmrun(pa_of(vmcb));
  k_vmload(pa_of(hvmcb));
  k_stgi();

  *exitcode = r64(vmcb, vmcb_exitcode);
  *rax = r64(vmcb, vmcb_rax);
  *rip = r64(vmcb, vmcb_rip);
  return 0; }
