// asmops -- the x64 privileged instructions, one static inline each, in GNU AT&T templates
// that clang reads and mooncc lowers through holo's gas.l; test/gate/asmops.sh compares the
// two compilers' objects op by op. an operand's register spells at its C type's width, so the
// register-contracted ops pin by constraint letter; a template separates on `\n` or `;`
#pragma once
#include <stdint.h>

static inline void k_cli(void) { asm volatile ("cli"); }
static inline void k_sti(void) { asm volatile ("sti"); }
// the idle wait; a64's twin of this name is wfi
static inline void k_wait(void) { asm volatile ("hlt"); }

static inline uint64_t k_rd_cr2(void) {
  uint64_t v;
  asm volatile ("mov %%cr2, %0" : "=r"(v));
  return v; }

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

static inline void k_wr_cr3(uint64_t v) {
  asm volatile ("mov %0, %%cr3" :: "r"(v) : "memory"); }

static inline void k_wr_cr4(uint64_t v) {
  asm volatile ("mov %0, %%cr4" :: "r"(v) : "memory"); }

// enable x87/SSE, before any other C in kmain: either compiler may emit SSE (a struct copy
// will), which #UDs into a silent triple fault. one block, its "memory" clobber a fence
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

// the MSR number rides ecx, the value edx:eax
static inline uint64_t k_rdmsr(uint32_t msr) {
  uint32_t lo, hi;
  asm volatile ("rdmsr" : "=a"(lo), "=d"(hi) : "c"(msr));
  return ((uint64_t) hi << 32) | lo; }

static inline void k_wrmsr(uint32_t msr, uint64_t v) {
  asm volatile ("wrmsr" :: "a"((uint32_t) v), "d"((uint32_t) (v >> 32)), "c"(msr)); }

// eax is a tied output, as a compiler cannot clobber an input register, then dropped
static inline void k_cpuid(uint32_t leaf, uint32_t *b, uint32_t *c, uint32_t *d) {
  uint32_t ra, rb, rc, rd;
  asm volatile ("cpuid" : "=a"(ra), "=b"(rb), "=c"(rc), "=d"(rd) : "0"(leaf));
  (void) ra;
  *b = rb; *c = rc; *d = rd; }

// SVM (svm.c): vmrun/vmload/vmsave take the VMCB's physical address in rax. the clobber list
// is the contract: #VMEXIT restores no other GPR. rbp, the frame pointer, cannot be named, so
// a guest running real code wants a save/restore stub, not this inline
#define k_svm_clobbers "rbx", "rcx", "rdx", "rsi", "rdi", "r8", "r9", \
                       "r10", "r11", "r12", "r13", "r14", "r15", "memory"

static inline void k_vmrun(uint64_t vmcb_pa) {
  asm volatile ("vmrun %%rax" :: "a"(vmcb_pa) : k_svm_clobbers); }

// vmrun does not save FS, GS, TR, LDTR or the syscall MSRs: vmsave before, vmload after
static inline void k_vmsave(uint64_t vmcb_pa) {
  asm volatile ("vmsave %%rax" :: "a"(vmcb_pa) : "memory"); }

static inline void k_vmload(uint64_t vmcb_pa) {
  asm volatile ("vmload %%rax" :: "a"(vmcb_pa) : "memory"); }

// #VMEXIT leaves GIF clear: a missing stgi is a deaf machine that looks hung
static inline void k_stgi(void) { asm volatile ("stgi" ::: "memory"); }
static inline void k_clgi(void) { asm volatile ("clgi" ::: "memory"); }

// VMX (vmx.c): vmxon, vmclear, vmptrld take a memory operand holding a physical address
static inline void k_vmxon(uint64_t *pa) {
  asm volatile ("vmxon %0" :: "m"(*pa) : "cc", "memory"); }

static inline void k_vmclear(uint64_t *pa) {
  asm volatile ("vmclear %0" :: "m"(*pa) : "cc", "memory"); }

static inline void k_vmptrld(uint64_t *pa) {
  asm volatile ("vmptrld %0" :: "m"(*pa) : "cc", "memory"); }

static inline void k_vmxoff(void) { asm volatile ("vmxoff" ::: "cc", "memory"); }

// ModRM.reg names the field in both directions
static inline uint64_t k_vmread(uint64_t field) {
  uint64_t v;
  asm volatile ("vmread %1, %0" : "=r"(v) : "r"(field) : "cc");
  return v; }

static inline void k_vmwrite(uint64_t field, uint64_t v) {
  asm volatile ("vmwrite %1, %0" :: "r"(field), "r"(v) : "cc"); }

static inline void k_sgdt(void *p) {
  asm volatile ("sgdt %0" :: "m"(*(char (*)[10]) p) : "memory"); }

static inline void k_sidt(void *p) {
  asm volatile ("sidt %0" :: "m"(*(char (*)[10]) p) : "memory"); }

// every VMX exit reloads GDTR from the VMCS
static inline void k_lgdt(void const *p) {
  asm volatile ("lgdt %0" :: "m"(*(char const (*)[10]) p) : "memory"); }

// an exit resumes at the VMCS's HOST_RIP and HOST_RSP, so the block points both at itself
// first. a refused launch falls through, an exit lands on 1:, and only bad tells them apart.
// no GPR but rsp is restored: a guest writing more than rax wants a save/restore stub
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

// port I/O: "a" pins the datum, "Nd" the port (dx or a byte immediate)
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

// deliberate faults, for `fault`. int3 is the one-byte CC, not CD 03
static inline void k_int3(void) { asm volatile ("int3"); }

static inline void k_ud2(void) { asm volatile ("ud2"); }

// #DE: the divisor is zeroed here, so no caller can make it not fault
static inline void k_divzero(void) {
  asm volatile ("xorl %%edx,%%edx; movl $1,%%eax; xorl %%ecx,%%ecx;"
                "divl %%ecx" ::: "eax","ecx","edx"); }
