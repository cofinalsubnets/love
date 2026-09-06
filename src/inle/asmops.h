// asmops -- the privileged instructions, one static inline each. two readers, one file.
//
// mooncc takes the top half: holo's neutral text under __attribute__((holo)) (src/core/
// holo/text.l -- mnemonic then operands, one instruction per LINE, the abstract file r0..,
// `;` a comment to end of line). one dialect for every machine, so the ops holo names alike
// everywhere are said once and the rest sit under the machine's own predefine, spelled
// the way holo spells them: x64 r0=rax r1=rcx r2=rdx r3=rbx r5=rsi r6=rdi r7..r14=r8..r15,
// ldcr/stcr for the control-register moves, the register-contracted ops bare; a64 rN=xN,
// msri for the PSTATE immediate, dbrk for `hlt #imm`, `tlbi op, zr` whole-system, sp
// moved by lea; rv64 r0..r7=a0..a7, sys/trap for ecall/ebreak. a pin is by neutral name
// ("r0"), the clobbers likewise.
//
// every other compiler takes the bottom half: the per-arch GNU templates in x64/, a64/,
// rv64/, which mooncc reads too (src/core/holo/gas.l). test/gate/asmops.sh compiles both
// halves and compares them op by op, so neither spelling drifts from the other.
#pragma once
#include <stdint.h>

#ifdef __mooncc__
#define k_asm __attribute__((holo)) asm volatile

// --- said once: what every backend names alike ---------------------------------
// the breakpoint, the `fault` builtin's backend: int3 / brk #0 / ebreak are one `trap`.
static inline void k_int3(void)   { k_asm ("trap"); }
static inline void k_brk0(void)   { k_asm ("trap"); }
static inline void k_ebreak(void) { k_asm ("trap"); }

#if defined(__x86_64__)
// --- the interrupt flag, and the wait ----------------------------------------
static inline void k_cli(void)  { k_asm ("cli"); }
static inline void k_sti(void)  { k_asm ("sti"); }
static inline void k_wait(void) { k_asm ("hlt"); }        // kmain's kwait; the arm twin is wfi

// --- control registers ---------------------------------------------------------
static inline uint64_t k_rd_cr2(void) { uint64_t v; k_asm ("ldcr %0, 2" : "=r"(v)); return v; }
static inline uint64_t k_rd_cr0(void) { uint64_t v; k_asm ("ldcr %0, 0" : "=r"(v)); return v; }
static inline uint64_t k_rd_cr3(void) { uint64_t v; k_asm ("ldcr %0, 3" : "=r"(v)); return v; }
static inline uint64_t k_rd_cr4(void) { uint64_t v; k_asm ("ldcr %0, 4" : "=r"(v)); return v; }
static inline void k_wr_cr0(uint64_t v) { k_asm ("stcr 0, %0" :: "r"(v) : "memory"); }
static inline void k_wr_cr4(uint64_t v) { k_asm ("stcr 4, %0" :: "r"(v) : "memory"); }

// CR0.EM=0 / CR0.MP=1 and CR4.OSFXSR|OSXMMEXCPT: enable x87/SSE, before any other C
// in kmain -- a compiler may emit an SSE instruction anywhere, and one #UDs into a
// triple fault while SSE is masked. one block, the "memory" clobber holding what follows.
static inline void k_sse_enable(void) {
  k_asm ("ldcr r0, 0\n"
         "and r0, r0, -5\n"          // CR0.EM = 0
         "or r0, r0, 2\n"            // CR0.MP = 1
         "stcr 0, r0\n"
         "ldcr r0, 4\n"
         "or r0, r0, 1536\n"         // CR4.OSFXSR | CR4.OSXMMEXCPT
         "stcr 4, r0"
         ::: "r0", "memory"); }

// --- model-specific registers: the number in ecx, the value in edx:eax -----------
static inline uint64_t k_rdmsr(uint32_t msr) {
  uint32_t lo, hi;
  k_asm ("rdmsr" : "=r0"(lo), "=r2"(hi) : "r1"(msr));
  return ((uint64_t) hi << 32) | lo; }
static inline void k_wrmsr(uint32_t msr, uint64_t v) {
  k_asm ("wrmsr" :: "r0"((uint32_t) v), "r2"((uint32_t) (v >> 32)), "r1"(msr)); }

// CPUID: the leaf in eax, the answers in eax/ebx/ecx/edx. eax's answer is not named --
// the max-leaf probe is the only caller that ever wanted it, and it asks differently.
static inline void k_cpuid(uint32_t leaf, uint32_t *b, uint32_t *c, uint32_t *d) {
  uint32_t rb, rc, rd;
  k_asm ("cpuid" : "=r3"(rb), "=r1"(rc), "=r2"(rd) : "r0"(leaf));
  *b = rb; *c = rc; *d = rd; }

// --- SVM, the AMD-V lane (x64/svm.c): the vmcb's physical address in rax ----------
// #VMEXIT restores rax, rsp, rip, rflags, the segments and the control registers, and
// NO other GPR -- the list is the contract (the callee-saved ones are saved around the
// body). rbp is not nameable, the standing reason a real guest wants a stub, not this.
#define k_svm_clobbers "r3", "r1", "r2", "r5", "r6", "r7", "r8", "r9", "r10", \
                       "r11", "r12", "r13", "r14", "memory"
static inline void k_vmrun(uint64_t vmcb_pa)  { k_asm ("vmrun"  :: "r0"(vmcb_pa) : k_svm_clobbers); }
// the host state vmrun does not save (FS, GS, TR, LDTR, the syscall MSRs): vmsave
// before the entry, vmload after it
static inline void k_vmsave(uint64_t vmcb_pa) { k_asm ("vmsave" :: "r0"(vmcb_pa) : "memory"); }
static inline void k_vmload(uint64_t vmcb_pa) { k_asm ("vmload" :: "r0"(vmcb_pa) : "memory"); }
// the global interrupt flag. #VMEXIT leaves GIF clear: a missing stgi is a deaf machine.
static inline void k_stgi(void) { k_asm ("stgi" ::: "memory"); }
static inline void k_clgi(void) { k_asm ("clgi" ::: "memory"); }

// --- VMX, the Intel lane (x64/vmx.c): memory operands, a field pair, the tables ---
static inline void k_vmxon(uint64_t *pa)   { k_asm ("vmxon %0"   :: "m"(*pa) : "cc", "memory"); }
static inline void k_vmclear(uint64_t *pa) { k_asm ("vmclear %0" :: "m"(*pa) : "cc", "memory"); }
static inline void k_vmptrld(uint64_t *pa) { k_asm ("vmptrld %0" :: "m"(*pa) : "cc", "memory"); }
static inline void k_vmxoff(void)          { k_asm ("vmxoff" ::: "cc", "memory"); }
static inline uint64_t k_vmread(uint64_t field) {
  uint64_t v; k_asm ("vmread %0, %1" : "=r"(v) : "r"(field) : "cc"); return v; }
static inline void k_vmwrite(uint64_t field, uint64_t v) {
  k_asm ("vmwrite %0, %1" :: "r"(field), "r"(v) : "cc"); }
static inline void k_sgdt(void *p)       { k_asm ("sgdt %0" :: "m"(*(char (*)[10]) p) : "memory"); }
static inline void k_sidt(void *p)       { k_asm ("sidt %0" :: "m"(*(char (*)[10]) p) : "memory"); }
static inline void k_lgdt(void const *p) { k_asm ("lgdt %0" :: "m"(*(char const (*)[10]) p) : "memory"); }

// k_vmlaunch -- the entry, which on this vendor cannot be one instruction. a VM exit
// resumes at the VMCS's HOST_RIP with its HOST_RSP, so the block writes both first; a
// REFUSED launch falls through where a guest that ran lands on the label, and the marker
// register (1 before, 0 on the label) tells them apart. rax is read on the label because
// by the next instruction it is gone; no other host GPR comes back, hence the stub for a
// guest that writes more than rax.
static inline int k_vmlaunch(uint64_t *guest_rax) {
  uint64_t bad, grax;
  k_asm ("lea r0, sp, 0\n"          // the rsp the exit has to come back to
         "li r1, 27668\n"           // HOST_RSP  (0x6c14)
         "vmwrite r1, r0\n"
         "la r0, vmx-back\n"
         "li r1, 27670\n"           // HOST_RIP  (0x6c16)
         "vmwrite r1, r0\n"
         "li %0, 1\n"
         "vmlaunch\n"
         "jmp vmx-done\n"
         "label vmx-back\n"
         "mov %1, r0\n"             // the guest's rax, before anything else takes it
         "li %0, 0\n"
         "label vmx-done"
         : "=r"(bad), "=r2"(grax) :: "r0", "r1", "cc", "memory");
  *guest_rax = grax;
  return (int) bad; }

// --- port I/O: the port in dx, the datum in al/ax/eax, no operand of their own --------
static inline void k_outb(uint16_t port, uint8_t v)  { k_asm ("outb" :: "r0"(v), "r2"(port)); }
static inline void k_outl(uint16_t port, uint32_t v) { k_asm ("outl" :: "r0"(v), "r2"(port)); }
static inline uint8_t k_inb(uint16_t port) {
  uint8_t v; k_asm ("inb" : "=r0"(v) : "r2"(port)); return v; }
static inline uint32_t k_inl(uint16_t port) {
  uint32_t v; k_asm ("inl" : "=r0"(v) : "r2"(port)); return v; }

// --- the other deliberate faults --------------------------------------------------
static inline void k_ud2(void) { k_asm ("ud2"); }
// #DE: 1 / 0, the divisor zeroed right here so nothing about the caller can make this NOT fault
static inline void k_divzero(void) {
  k_asm ("li r0, 1\n li r1, 0\n xor r2, r2, r2\n divl r1" ::: "r0", "r1", "r2", "cc"); }

#elif defined(__aarch64__)
// --- barriers and the wait ----------------------------------------------------------
static inline void k_isb(void)     { k_asm ("isb" ::: "memory"); }
static inline void k_dsb_ish(void) { k_asm ("dsb ish" ::: "memory"); }
static inline void k_wait(void)    { k_asm ("wfi"); }     // kmain's kwait; the x64 twin is hlt

// --- system registers: holo carries the names (src/core/holo/a64.l) -------------------
static inline uint64_t k_rd_ctr_el0(void)    { uint64_t v; k_asm ("mrs %0, ctr_el0"    : "=r"(v)); return v; }
static inline uint64_t k_rd_mair_el1(void)   { uint64_t v; k_asm ("mrs %0, mair_el1"   : "=r"(v)); return v; }
static inline uint64_t k_rd_ttbr1_el1(void)  { uint64_t v; k_asm ("mrs %0, ttbr1_el1"  : "=r"(v)); return v; }
static inline uint64_t k_rd_cntfrq_el0(void) { uint64_t v; k_asm ("mrs %0, cntfrq_el0" : "=r"(v)); return v; }
static inline void k_wr_cntp_tval_el0(uint64_t v) { k_asm ("msr cntp_tval_el0, %0" :: "r"(v)); }
static inline void k_wr_cntp_ctl_el0(uint64_t v)  { k_asm ("msr cntp_ctl_el0, %0"  :: "r"(v)); }
// the vector base, with the isb that makes it live before the next fetch
static inline void k_wr_vbar_el1(uintptr_t v) { k_asm ("msr vbar_el1, %0\n isb" :: "r"(v) : "memory"); }

// --- PSTATE fields, the msr-immediate form (a different instruction: msri) -----------
static inline void k_daif_mask_all(void)   { k_asm ("msri daifset, 15"); }   // D, A, I, F
static inline void k_daif_unmask_irq(void) { k_asm ("msri daifclr, 2"); }    // DAIF.I = 0

// --- address translation and the TLB ------------------------------------------------
// AT writes its answer to PAR_EL1, and the isb is what makes it readable
static inline uint64_t k_at_s1e1w_par(void *va) {
  uint64_t par;
  k_asm ("at s1e1w, %1\n isb\n mrs %0, par_el1" : "=r"(par) : "r"(va) : "memory");
  return par; }
// the whole EL1 TLB, inner-shareable, between the barriers that publish the descriptor
// and make the mapping usable
static inline void k_tlbi_all(void) { k_asm ("dsb ish\n tlbi vmalle1is, zr\n dsb ish\n isb" ::: "memory"); }

// --- cache maintenance (__clear_cache's two halves) ------------------------------------
static inline void k_dc_cvau(uintptr_t p) { k_asm ("dc cvau, %0" :: "r"(p) : "memory"); }
static inline void k_ic_ivau(uintptr_t p) { k_asm ("ic ivau, %0" :: "r"(p) : "memory"); }

// --- bring-up ---------------------------------------------------------------------------
// EL1t -> EL1h: exception entry switches to SP_EL1, which EL1 cannot write by msr, so:
// capture sp, select SP_EL1, write sp -- one block, the value unchanged across the switch
static inline void k_sp_to_el1h(void) {
  k_asm ("lea r9, sp, 0\n msri spsel, 1\n lea sp, r9, 0" ::: "r9", "memory"); }
// CPACR_EL1.FPEN = 0b11, so C may use doubles (a bootloader can leave FPEN clear)
static inline void k_fpen_enable(void) {
  k_asm ("mrs r9, cpacr_el1\n"
         "or r9, r9, 3145728\n"      // 3 << 20
         "msr cpacr_el1, r9\n"
         "isb"
         ::: "r9", "memory"); }

// --- the other deliberate fault, and the two hypercall-shaped exits --------------------
static inline void k_udf0(void) { k_asm ("udf 0"); }
// ARM semihosting SYS_EXIT: x0 the operation, x1 the {reason, code} block, `hlt #0xf000`
// (holo's dbrk) the trap
static inline void k_semihost_exit(volatile uint64_t *block) {
  uint64_t op = 0x18, arg = (uint64_t) (uintptr_t) block;
  k_asm ("dbrk 61440" :: "r0"(op), "r1"(arg) : "memory"); }
// PSCI SYSTEM_RESET over HVC (what QEMU's 'virt' exposes); the function id rides x0
static inline void k_psci_system_reset(void) {
  uint64_t fn = 0x84000009;
  k_asm ("hvc 0" : "+r0"(fn) :: "memory"); }

#elif defined(__riscv)
// --- the wait, and the fence -----------------------------------------------------------
static inline void k_wait(void)  { k_asm ("wfi"); }       // kmain's kwait; the x64 twin is hlt
static inline void k_fence(void) { k_asm ("fence" ::: "memory"); }   // fence iorw, iorw

// --- csr reads and writes: holo carries the names (src/core/holo/rv64.l) ---------------
static inline uint64_t k_rd_time(void) { uint64_t v; k_asm ("csrr %0, time" : "=r"(v)); return v; }
static inline void k_wr_stvec(uintptr_t v) { k_asm ("csrw stvec, %0" :: "r"(v) : "memory"); }
static inline void k_sie_set(uint64_t bits) { k_asm ("csrs sie, %0" :: "r"(bits) : "memory"); }
// sstatus.SIE, the one interrupt switch; the immediate forms take the bit as 2
static inline void k_sie_on(void)  { k_asm ("csrsi sstatus, 2" ::: "memory"); }
static inline void k_sie_off(void) { k_asm ("csrci sstatus, 2" ::: "memory"); }

// --- the SBI call: a7 the extension, a6 the function, a0/a1 the arguments and the
// (error, value) answer ------------------------------------------------------------------
#define SBI_TIME 0x54494D45
#define SBI_SRST 0x53525354
static inline int64_t k_sbi(uint64_t ext, uint64_t fn, uint64_t a0, uint64_t a1) {
  k_asm ("sys" : "+r0"(a0), "+r1"(a1) : "r6"(fn), "r7"(ext) : "memory");
  return (int64_t) a0; }

// --- the other deliberate fault: the 32-bit `unimp` is a csrrw against a csr that
// cannot be written --------------------------------------------------------------------
static inline void k_unimp(void) { k_asm ("csrw cycle, zr"); }
#endif

#undef k_asm
#else
#if defined(__x86_64__)
#include "x64/asmops.h"
#elif defined(__aarch64__)
#include "a64/asmops.h"
#elif defined(__riscv)
#include "rv64/asmops.h"
#endif
#endif
