// asmops -- the x64 privileged instructions, one static inline each.
//
// the kernel is the last place in the tree that talks to the machine in
// assembler, and it says each thing ONCE, in GNU's AT&T template: clang reads
// it natively, and mooncc lowers the same text to holo's neutral IR
// (core/holo/gas.l -- the registers, `$` immediates, disp(%base) memory,
// the `1:`/`1f` local labels and the size suffix all read as GNU does). so the
// spelling lives HERE, once per operation, every call site says the operation's
// NAME, and the clang build stays alive as the differential twin: both
// compilers compile the same kernel from the same lines (test/gate/asmops.sh
// compares the two objects op by op).
//
// worth knowing before editing: an operand's register spells at its C type's
// width (a uint8_t is %al, a uint16_t %dx), so the register-contracted ops
// (in/out, rdmsr, cpuid, vmrun) pin by constraint letter and name the register
// only for the reader; and a multi-instruction template separates on `\n` or
// `;`, either way.
#pragma once
#include <stdint.h>

// --- the interrupt flag, and the wait ---------------------------------
static inline void k_cli(void) { asm volatile ("cli"); }
static inline void k_sti(void) { asm volatile ("sti"); }
// the idle wait, kmain's kwait: halt until the next interrupt. the a64
// twin of this name is `wfi`, which is the whole reason kmain calls k_wait()
// and not either mnemonic.
static inline void k_wait(void) { asm volatile ("hlt"); }

// --- control registers ------------------------------------------------
// #PF reports the faulting address in CR2.
static inline uint64_t k_rd_cr2(void) {
  uint64_t v;
  asm volatile ("mov %%cr2, %0" : "=r"(v));
  return v; }

// VMX needs the host's own CR0/CR3/CR4 written into the VMCS, and CR4.VMXE set
// before vmxon -- so the control registers grew readers beside CR2's.
static inline uint64_t k_rd_cr0(void) {
  uint64_t v;
  asm volatile ("mov %%cr0, %0" : "=r"(v));
  return v; }

static inline uint64_t k_rd_cr3(void) {
  uint64_t v;
  asm volatile ("mov %%cr3, %0" : "=r"(v));
  return v; }

static inline uint64_t k_rd_cr4(void) {
  uint64_t v;
  asm volatile ("mov %%cr4, %0" : "=r"(v));
  return v; }

static inline void k_wr_cr0(uint64_t v) {
  asm volatile ("mov %0, %%cr0" :: "r"(v) : "memory"); }

static inline void k_wr_cr4(uint64_t v) {
  asm volatile ("mov %0, %%cr4" :: "r"(v) : "memory"); }

// CR0.EM=0 / CR0.MP=1 and CR4.OSFXSR|OSXMMEXCPT: enable x87/SSE. this runs
// before ANY other C in kmain -- neither compiler guarantees it will not emit
// an SSE instruction (a struct copy is enough), and one of those #UDs into a
// triple fault with no output while SSE is still masked. ONE asm block, with
// the "memory" clobber holding any vectorized access below it.
static inline void k_sse_enable(void) {
  asm volatile (
    "mov %%cr0, %%rax\n\t"
    "and $~(1 << 2), %%rax\n\t"        // CR0.EM = 0
    "or  $(1 << 1), %%rax\n\t"         // CR0.MP = 1
    "mov %%rax, %%cr0\n\t"
    "mov %%cr4, %%rax\n\t"
    "or  $((1 << 9) | (1 << 10)), %%rax\n\t"   // CR4.OSFXSR | CR4.OSXMMEXCPT
    "mov %%rax, %%cr4"
    ::: "rax", "memory"); }

// --- model-specific registers -----------------------------------------
// rdmsr/wrmsr are register-CONTRACTED like the port ops: the MSR number rides
// ecx and the value edx:eax, so the operands pin by letter and the template
// names nothing.
static inline uint64_t k_rdmsr(uint32_t msr) {
  uint32_t lo, hi;
  asm volatile ("rdmsr" : "=a"(lo), "=d"(hi) : "c"(msr));
  return ((uint64_t) hi << 32) | lo; }

static inline void k_wrmsr(uint32_t msr, uint64_t v) {
  asm volatile ("wrmsr" :: "a"((uint32_t) v), "d"((uint32_t) (v >> 32)), "c"(msr)); }

// CPUID: the leaf rides eax, the answers come back in eax/ebx/ecx/edx. eax is
// named as the tied output it architecturally is (a compiler cannot clobber a
// register it is also given as an input), and then dropped: the max-leaf probe
// is the only caller that ever wanted it, and it asks a different question.
static inline void k_cpuid(uint32_t leaf, uint32_t *b, uint32_t *c, uint32_t *d) {
  uint32_t ra, rb, rc, rd;
  asm volatile ("cpuid" : "=a"(ra), "=b"(rb), "=c"(rc), "=d"(rd) : "0"(leaf));
  (void) ra;
  *b = rb; *c = rc; *d = rd; }

// --- SVM, the AMD-V lane (inle/x64/svm.c) ---------------------
// vmrun/vmload/vmsave take the VMCB's PHYSICAL address in rax and name no
// operand of their own; the template names %rax for the reader.
//
// ⚠ THE CLOBBER LIST IS THE CONTRACT. #VMEXIT restores RAX, RSP, RIP, RFLAGS,
// the segments and the control registers from the host save area -- and NO
// other GPR. rbx/rcx/rdx/rsi/rdi/r8..r15 come back holding whatever the guest
// left in them, so the compiler is told so by name (mooncc saves the
// callee-saved ones around the body; the rest hold nothing of its own). rbp
// is not nameable (it is the frame pointer), which is the standing reason a
// guest that runs real code wants a save/restore stub around vmrun rather than
// this inline.
#define k_svm_clobbers "rbx", "rcx", "rdx", "rsi", "rdi", "r8", "r9", \
                       "r10", "r11", "r12", "r13", "r14", "r15", "memory"

static inline void k_vmrun(uint64_t vmcb_pa) {
  asm volatile ("vmrun %%rax" :: "a"(vmcb_pa) : k_svm_clobbers); }

// the host state vmrun does NOT save: FS, GS, TR, LDTR and the syscall MSRs.
// vmsave before the entry and vmload after it are what keep the kernel's own
// segment state off the guest's floor.
static inline void k_vmsave(uint64_t vmcb_pa) {
  asm volatile ("vmsave %%rax" :: "a"(vmcb_pa) : "memory"); }

static inline void k_vmload(uint64_t vmcb_pa) {
  asm volatile ("vmload %%rax" :: "a"(vmcb_pa) : "memory"); }

// the global interrupt flag. ⚠ #VMEXIT leaves GIF CLEAR: between the exit and
// the stgi the machine takes no interrupt at all, so a missing stgi is a deaf
// machine wearing a hang's face.
static inline void k_stgi(void) { asm volatile ("stgi" ::: "memory"); }
static inline void k_clgi(void) { asm volatile ("clgi" ::: "memory"); }

// --- VMX, the Intel lane (inle/x64/vmx.c) ---------------------
// Nothing here is register-contracted the way SVM's ops are: vmxon, vmclear and
// vmptrld take a MEMORY operand holding a physical address ("m", which mooncc
// lowers to the address in a register plus a zero displacement). sgdt/sidt/lgdt
// below ride the same door.
static inline void k_vmxon(uint64_t *pa) {
  asm volatile ("vmxon %0" :: "m"(*pa) : "cc", "memory"); }

static inline void k_vmclear(uint64_t *pa) {
  asm volatile ("vmclear %0" :: "m"(*pa) : "cc", "memory"); }

static inline void k_vmptrld(uint64_t *pa) {
  asm volatile ("vmptrld %0" :: "m"(*pa) : "cc", "memory"); }

static inline void k_vmxoff(void) { asm volatile ("vmxoff" ::: "cc", "memory"); }

// the field pair. ModRM.reg names the FIELD in both directions.
static inline uint64_t k_vmread(uint64_t field) {
  uint64_t v;
  asm volatile ("vmread %1, %0" : "=r"(v) : "r"(field) : "cc");
  return v; }

static inline void k_vmwrite(uint64_t field, uint64_t v) {
  asm volatile ("vmwrite %1, %0" :: "r"(field), "r"(v) : "cc"); }

// the descriptor-table READS. lgdt/lidt were here from the bring-up; VMX is
// what needs to write the bases down before it can promise to restore them.
static inline void k_sgdt(void *p) {
  asm volatile ("sgdt %0" :: "m"(*(char (*)[10]) p) : "memory"); }

static inline void k_sidt(void *p) {
  asm volatile ("sidt %0" :: "m"(*(char (*)[10]) p) : "memory"); }

// ..and the write back, which VMX needs because every exit reloads GDTR from
// the VMCS and the table it names is not the one the boot laid.
static inline void k_lgdt(void const *p) {
  asm volatile ("lgdt %0" :: "m"(*(char const (*)[10]) p) : "memory"); }

// k_vmlaunch -- the entry, which on this vendor cannot be one instruction.
//
// ⚠ A VM EXIT DOES NOT RESUME AFTER `vmlaunch`. It resumes at the HOST_RIP in
// the VMCS with the HOST_RSP in the VMCS, so this block writes both to its own
// label and its own stack pointer first. That is the whole structural
// difference from SVM's `vmrun`, which simply came back.
//
// ⚠ And the two outcomes arrive at the same place by different roads: a
// REFUSED launch falls THROUGH to the next instruction, while a guest that ran
// and exited lands on the label. Only the marker register tells them apart --
// it is set to 1 before the launch and to 0 on the label.
//
// ⚠ VMX saves no guest GPR: rax is read at the label because by the next
// instruction it is gone. By the same token the host's own GPRs are NOT
// restored on exit (rsp and rip are, and nothing else), so a guest that writes
// more than rax wants a save/restore stub around this instead of an inline.
static inline int k_vmlaunch(uint64_t *guest_rax) {
  uint64_t bad, grax;
  asm volatile (
    "movq %%rsp, %%rax\n"      // the rsp the exit has to come back to
    "movq $0x6c14, %%rcx\n"    // HOST_RSP
    "vmwrite %%rax, %%rcx\n"
    "leaq 1f(%%rip), %%rax\n"
    "movq $0x6c16, %%rcx\n"    // HOST_RIP
    "vmwrite %%rax, %%rcx\n"
    "movq $1, %0\n"
    "vmlaunch\n"
    "jmp 2f\n"
    "1:\n"
    "movq %%rax, %1\n"         // the guest's rax, before anything else takes it
    "movq $0, %0\n"
    "2:"
    : "=r"(bad), "=r"(grax) :: "rax", "rcx", "cc", "memory");
  *guest_rax = grax;
  return (int) bad; }

// --- port I/O ---------------------------------------------------------
// the port rides dx, the datum al/ax/eax: "a" pins the datum, "Nd" the port
// (dx, or a byte immediate where a compiler would rather). both operands are
// named for the reader only -- the instruction has no operand of its own.
static inline void k_outb(uint16_t port, uint8_t v) {
  asm volatile ("outb %0, %1" :: "a"(v), "Nd"(port)); }

static inline uint8_t k_inb(uint16_t port) {
  uint8_t v;
  asm volatile ("inb %1, %0" : "=a"(v) : "Nd"(port));
  return v; }

static inline void k_outl(uint16_t port, uint32_t v) {
  asm volatile ("outl %0, %w1" :: "a"(v), "Nd"(port)); }

static inline uint32_t k_inl(uint16_t port) {
  uint32_t v;
  asm volatile ("inl %1, %0" : "=a"(v) : "Nd"(port));
  return v; }

// --- deliberate faults (the `fault` builtin's backend) ----------------
// int3 is CC, the one-byte breakpoint, the same one every debugger plants; the
// two-byte CD 03 is a different instruction under vm86.
static inline void k_int3(void) { asm volatile ("int3"); }

static inline void k_ud2(void) { asm volatile ("ud2"); }

// #DE: 1 / 0. the divisor register is zeroed right here rather than passed in,
// so nothing about the caller can make this NOT fault.
static inline void k_divzero(void) {
  asm volatile ("xorl %%edx,%%edx; movl $1,%%eax; xorl %%ecx,%%ecx;"
                "divl %%ecx" ::: "eax","ecx","edx"); }
