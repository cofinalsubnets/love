/* the watching side: stubs in asm, every answer worked out here */
#include <stdarg.h>
#include <setjmp.h>
#include <stdio.h>
typedef unsigned long ul;
struct s24 { long a, b, c; };
extern long m_live(long, long, long, long, long, long, double, double, double), m_back(long), m_tail(long, long), m_stack(long),
  m_vsum(int, ...), m_vcopy(int, ...), m_big(long), m_vtake(int, va_list);
extern double m_dvsum(int, ...);
extern int m_al(int);
extern long m_narrow(signed char, unsigned char, short, unsigned short, _Bool);
static int nbad;
static void want(const char *nm, long g, long w) { if (g != w) nbad++, printf("seam %s got %ld want %ld\n", nm, g, w); }

#ifdef __x86_64__
/* wreck: ruin each caller-saved register. its answer is rdi plus the double */
__asm__(".text\n.globl p_wreck\np_wreck:\n cvttsd2si %xmm0,%rax\n add %rdi,%rax\n mov $-1,%rcx\n mov %rcx,%rdx\n mov %rcx,%rsi\n mov %rcx,%rdi\n"
        " mov %rcx,%r8\n mov %rcx,%r9\n mov %rcx,%r10\n mov %rcx,%r11\n"
        " pcmpeqd %xmm0,%xmm0\n movaps %xmm0,%xmm1\n movaps %xmm0,%xmm2\n movaps %xmm0,%xmm3\n movaps %xmm0,%xmm4\n movaps %xmm0,%xmm5\n movaps %xmm0,%xmm6\n movaps %xmm0,%xmm7\n"
        " movaps %xmm0,%xmm8\n movaps %xmm0,%xmm9\n movaps %xmm0,%xmm10\n movaps %xmm0,%xmm11\n movaps %xmm0,%xmm12\n movaps %xmm0,%xmm13\n movaps %xmm0,%xmm14\n movaps %xmm0,%xmm15\n ret\n"
/* aligned: 1 when rsp is 16 aligned before the call, and the stack argument is right */
        ".globl p_aligned\np_aligned:\n lea 8(%rsp),%rax\n and $15,%eax\n neg %rax\n add 8(%rsp),%rax\n ret\n"
/* al: the upper bound of vector registers used, at least what was passed and at most 8 */
        ".globl p_al\np_al:\n movzbl %al,%eax\n cmp %edi,%eax\n jl 1f\n cmp $8,%eax\n jg 1f\n mov $1,%eax\n ret\n1: xor %eax,%eax\n ret\n"
/* saved: marks in rbx rbp r12-r15, mxcsr, x87 cw and df; calls rdi with rsi rdx; rax a bit per loss */
        ".globl saved\nsaved:\n push %rbx\n push %rbp\n push %r12\n push %r13\n push %r14\n push %r15\n sub $24,%rsp\n"
        " stmxcsr (%rsp)\n fnstcw 4(%rsp)\n mov %rsp,marks(%rip)\n"
        " mov $0x1111111111,%rbx\n mov $0x2222222222,%rbp\n mov $0x3333333333,%r12\n mov $0x4444444444,%r13\n mov $0x5555555555,%r14\n mov $0x6666666666,%r15\n"
        " mov %rdi,%rax\n mov %rsi,%rdi\n mov %rdx,%rsi\n call *%rax\n mov %rax,saved_ans(%rip)\n xor %eax,%eax\n"
        " mov $0x1111111111,%rcx\n cmp %rcx,%rbx\n je 1f\n or $1,%eax\n1: mov $0x2222222222,%rcx\n cmp %rcx,%rbp\n je 1f\n or $2,%eax\n"
        "1: mov $0x3333333333,%rcx\n cmp %rcx,%r12\n je 1f\n or $4,%eax\n1: mov $0x4444444444,%rcx\n cmp %rcx,%r13\n je 1f\n or $8,%eax\n"
        "1: mov $0x5555555555,%rcx\n cmp %rcx,%r14\n je 1f\n or $16,%eax\n1: mov $0x6666666666,%rcx\n cmp %rcx,%r15\n je 1f\n or $32,%eax\n"
        "1: cmp %rsp,marks(%rip)\n je 1f\n or $64,%eax\n mov marks(%rip),%rsp\n1: stmxcsr 8(%rsp)\n mov 8(%rsp),%ecx\n xor (%rsp),%ecx\n test $0xffc0,%ecx\n je 1f\n or $128,%eax\n"
        "1: fnstcw 12(%rsp)\n mov 12(%rsp),%cx\n cmp 4(%rsp),%cx\n je 1f\n or $256,%eax\n1: pushf\n pop %rcx\n test $0x400,%ecx\n je 1f\n or $512,%eax\n cld\n"
        "1: add $24,%rsp\n pop %r15\n pop %r14\n pop %r13\n pop %r12\n pop %rbp\n pop %rbx\n ret\n"
        ".bss\nmarks: .quad 0\n.globl saved_ans\nsaved_ans: .quad 0\n.text\n");
#elif defined(__aarch64__)
/* the same on a64: x0-x17 and the vector registers but v8-v15's low halves are the caller's; x18 is left alone */
__asm__(".text\n.globl p_wreck\np_wreck:\n fcvtzs x9, d0\n add x0, x0, x9\n mov x1, #-1\n"
        " mov x2, x1\n mov x3, x1\n mov x4, x1\n mov x5, x1\n mov x6, x1\n mov x7, x1\n"
        " mov x8, x1\n mov x9, x1\n mov x10, x1\n mov x11, x1\n mov x12, x1\n mov x13, x1\n"
        " mov x14, x1\n mov x15, x1\n mov x16, x1\n mov x17, x1\n movi v0.2d, #0xffffffffffffffff\n mov v1.16b, v0.16b\n"
        " mov v2.16b, v0.16b\n mov v3.16b, v0.16b\n mov v4.16b, v0.16b\n mov v5.16b, v0.16b\n mov v6.16b, v0.16b\n mov v7.16b, v0.16b\n"
        " mov v16.16b, v0.16b\n mov v17.16b, v0.16b\n mov v18.16b, v0.16b\n mov v19.16b, v0.16b\n mov v20.16b, v0.16b\n mov v21.16b, v0.16b\n"
        " mov v22.16b, v0.16b\n mov v23.16b, v0.16b\n mov v24.16b, v0.16b\n mov v25.16b, v0.16b\n mov v26.16b, v0.16b\n mov v27.16b, v0.16b\n"
        " mov v28.16b, v0.16b\n mov v29.16b, v0.16b\n mov v30.16b, v0.16b\n mov v31.16b, v0.16b\n ret\n"
/* aligned: 1 when sp is 16 aligned, and the seventh argument is right */
        ".globl p_aligned\np_aligned:\n mov x9, sp\n and x9, x9, #15\n sub x0, x6, x9\n ret\n"
/* saved: marks in x19-x29, d8-d15 and fpcr; calls x0 with x1 x2; x0 a bit per loss, sp 2048 */
        ".globl saved\nsaved:\n stp x29, x30, [sp, #-176]!\n stp x19, x20, [sp, #16]\n stp x21, x22, [sp, #32]\n stp x23, x24, [sp, #48]\n"
        " stp x25, x26, [sp, #64]\n stp x27, x28, [sp, #80]\n stp d8, d9, [sp, #96]\n stp d10, d11, [sp, #112]\n stp d12, d13, [sp, #128]\n stp d14, d15, [sp, #144]\n"
        " mrs x9, fpcr\n str x9, [sp, #160]\n mov x9, sp\n adrp x10, marks\n str x9, [x10, :lo12:marks]\n mov x19, #1901\n"
        " mov x20, #2001\n mov x21, #2101\n mov x22, #2201\n mov x23, #2301\n mov x24, #2401\n mov x25, #2501\n"
        " mov x26, #2601\n mov x27, #2701\n mov x28, #2801\n mov x29, #2901\n fmov d8, x19\n fmov d9, x20\n"
        " fmov d10, x21\n fmov d11, x22\n fmov d12, x23\n fmov d13, x24\n fmov d14, x25\n fmov d15, x26\n"
        " mov x9, x0\n mov x0, x1\n mov x1, x2\n blr x9\n adrp x10, saved_ans\n str x0, [x10, :lo12:saved_ans]\n"
        " mov x0, #0\n mov x9, #1901\n cmp x19, x9\n b.eq 1f\n orr x0, x0, #1\n1:\n"
        " mov x9, #2001\n cmp x20, x9\n b.eq 1f\n orr x0, x0, #2\n1:\n mov x9, #2101\n"
        " cmp x21, x9\n b.eq 1f\n orr x0, x0, #4\n1:\n mov x9, #2201\n cmp x22, x9\n"
        " b.eq 1f\n orr x0, x0, #8\n1:\n mov x9, #2301\n cmp x23, x9\n b.eq 1f\n"
        " orr x0, x0, #16\n1:\n mov x9, #2401\n cmp x24, x9\n b.eq 1f\n orr x0, x0, #32\n"
        "1:\n mov x9, #2501\n cmp x25, x9\n b.eq 1f\n orr x0, x0, #64\n1:\n"
        " mov x9, #2601\n cmp x26, x9\n b.eq 1f\n orr x0, x0, #128\n1:\n mov x9, #2701\n"
        " cmp x27, x9\n b.eq 1f\n orr x0, x0, #256\n1:\n mov x9, #2801\n cmp x28, x9\n"
        " b.eq 1f\n orr x0, x0, #512\n1:\n mov x9, #2901\n cmp x29, x9\n b.eq 1f\n"
        " orr x0, x0, #1024\n1:\n adrp x10, marks\n ldr x9, [x10, :lo12:marks]\n mov x11, sp\n cmp x11, x9\n"
        " b.eq 1f\n orr x0, x0, #2048\n mov sp, x9\n1:\n fmov x9, d8\n mov x11, #1901\n"
        " cmp x9, x11\n b.eq 1f\n orr x0, x0, #4096\n1:\n fmov x9, d9\n mov x11, #2001\n"
        " cmp x9, x11\n b.eq 1f\n orr x0, x0, #8192\n1:\n fmov x9, d10\n mov x11, #2101\n"
        " cmp x9, x11\n b.eq 1f\n orr x0, x0, #16384\n1:\n fmov x9, d11\n mov x11, #2201\n"
        " cmp x9, x11\n b.eq 1f\n orr x0, x0, #32768\n1:\n fmov x9, d12\n mov x11, #2301\n"
        " cmp x9, x11\n b.eq 1f\n orr x0, x0, #65536\n1:\n fmov x9, d13\n mov x11, #2401\n"
        " cmp x9, x11\n b.eq 1f\n orr x0, x0, #131072\n1:\n fmov x9, d14\n mov x11, #2501\n"
        " cmp x9, x11\n b.eq 1f\n orr x0, x0, #262144\n1:\n fmov x9, d15\n mov x11, #2601\n"
        " cmp x9, x11\n b.eq 1f\n orr x0, x0, #524288\n1:\n mrs x9, fpcr\n ldr x11, [sp, #160]\n"
        " cmp x9, x11\n b.eq 1f\n orr x0, x0, #1048576\n1:\n ldp x19, x20, [sp, #16]\n ldp x21, x22, [sp, #32]\n"
        " ldp x23, x24, [sp, #48]\n ldp x25, x26, [sp, #64]\n ldp x27, x28, [sp, #80]\n ldp d8, d9, [sp, #96]\n ldp d10, d11, [sp, #112]\n ldp d12, d13, [sp, #128]\n"
        " ldp d14, d15, [sp, #144]\n ldp x29, x30, [sp], #176\n ret\n"
        ".bss\n.p2align 3\nmarks: .quad 0\n.globl saved_ans\nsaved_ans: .quad 0\n.text\n");
#else
/* the same on i386: arguments on the stack, ebx esi edi ebp saved, every xmm the caller's */
__asm__(".text\n.globl p_wreck\np_wreck:\n cvttsd2si 8(%esp),%eax\n add 4(%esp),%eax\n mov $-1,%ecx\n mov %ecx,%edx\n"
        " pcmpeqd %xmm0,%xmm0\n movaps %xmm0,%xmm1\n movaps %xmm0,%xmm2\n movaps %xmm0,%xmm3\n movaps %xmm0,%xmm4\n movaps %xmm0,%xmm5\n movaps %xmm0,%xmm6\n movaps %xmm0,%xmm7\n ret\n"
/* aligned: 1 when esp is 16 aligned before the call, and the last stack argument is right */
        ".globl p_aligned\np_aligned:\n lea 4(%esp),%eax\n and $15,%eax\n neg %eax\n add 28(%esp),%eax\n ret\n"
/* saved: marks in ebx esi edi ebp, mxcsr, x87 cw and df; calls the first argument with the next two; eax a bit per loss */
        ".globl saved\nsaved:\n push %ebx\n push %esi\n push %edi\n push %ebp\n sub $28,%esp\n"
        " stmxcsr 8(%esp)\n fnstcw 12(%esp)\n mov %esp,marks\n"
        " mov 52(%esp),%eax\n mov %eax,(%esp)\n mov 56(%esp),%eax\n mov %eax,4(%esp)\n mov 48(%esp),%eax\n"
        " mov $0x11111111,%ebx\n mov $0x22222222,%esi\n mov $0x33333333,%edi\n mov $0x44444444,%ebp\n"
        " call *%eax\n mov %eax,saved_ans\n xor %eax,%eax\n"
        " cmp $0x11111111,%ebx\n je 1f\n or $1,%eax\n1: cmp $0x22222222,%esi\n je 1f\n or $2,%eax\n"
        "1: cmp $0x33333333,%edi\n je 1f\n or $4,%eax\n1: cmp $0x44444444,%ebp\n je 1f\n or $8,%eax\n"
        "1: cmp %esp,marks\n je 1f\n or $64,%eax\n mov marks,%esp\n1: stmxcsr 16(%esp)\n mov 16(%esp),%ecx\n xor 8(%esp),%ecx\n test $0xffc0,%ecx\n je 1f\n or $128,%eax\n"
        "1: fnstcw 20(%esp)\n mov 20(%esp),%cx\n cmp 12(%esp),%cx\n je 1f\n or $256,%eax\n1: pushf\n pop %ecx\n test $0x400,%ecx\n je 1f\n or $512,%eax\n cld\n"
        "1: add $28,%esp\n pop %ebp\n pop %edi\n pop %esi\n pop %ebx\n ret\n"
        ".bss\nmarks: .long 0\n.globl saved_ans\nsaved_ans: .long 0\n.text\n");
#endif
extern long saved(void *, long, long), saved_ans;

long p_down(long n, long (*f)(long)) { return f(n - 1); }
long p_vsum(int n, va_list a) { long r = 0; for (int i = 0; i < n; i++) r = r * 3 + va_arg(a, long); return r; }
double p_dvsum(int n, va_list a) { double r = 0; for (int i = 0; i < n; i++) r = r * 2 + va_arg(a, double) + va_arg(a, int); return r; }
struct s24 p_big(long n) { struct s24 s = {n, n + 1, n + 2}; return s; }
static long vhand(int n, ...) { va_list a; va_start(a, n); long r = m_vtake(n, a); va_end(a); return r; }
static jmp_buf jb;
static long thrower(long n) { if (n == 2) longjmp(jb, 7); return m_back(n); }
static long live(long a, long b) { return m_live(a, b, 3, 4, 5, 6, 1.0, 2.0, 3.0); }
static void jumped(void) {
  int r = setjmp(jb);
  if (!r) { thrower(2); want("longjmp", 0, 1); } else want("longjmp", r, 7);
}
int main(void) {
  long fold = 0;
  for (int i = 1; i <= 12; i++) fold = fold * 3 + i;
  want("vsum", m_vsum(12, 1L, 2L, 3L, 4L, 5L, 6L, 7L, 8L, 9L, 10L, 11L, 12L), fold);
  want("vtake", vhand(12, 1L, 2L, 3L, 4L, 5L, 6L, 7L, 8L, 9L, 10L, 11L, 12L), fold);
  want("vcopy", m_vcopy(9, 1L, 2L, 3L, 4L, 5L, 6L, 7L, 8L, 9L), 0);
  double d = 0;
  for (int i = 1; i <= 10; i++) d = d * 2 + (i + .5) + i;
  want("dvsum", (long)(1024 * m_dvsum(10, 1.5, 1, 2.5, 2, 3.5, 3, 4.5, 4, 5.5, 5, 6.5, 6, 7.5, 7, 8.5, 8, 9.5, 9, 10.5, 10)), (long)(1024 * d));
  want("live", live(1, 2), LIVE);
  want("back", m_back(40), 820);
  want("big", m_big(5), 5 + 12 + 28);
  for (long n = 0; n < 40; n++) want("stack alignment", m_stack(n), 15);
#ifdef __x86_64__
  for (int k = 0; k < 4; k++) want("al", m_al(k), 1);
  want("saved over al", saved(m_al, 3, 0), 0);
#endif
  want("tail", m_tail(40, 2), 44);
  want("saved over live", saved(live, 1, 2), 0); want("saved live answer", saved_ans, LIVE);
  want("saved over m_live", saved(m_live, 1, 2), 0);
  want("saved over back", saved(m_back, 30, 0), 0);
  want("saved over stack", saved(m_stack, 9, 0), 0);
  want("saved over tail", saved(m_tail, 4, 5), 0);
  want("saved over big", saved(m_big, 3, 0), 0);
#ifdef HELD
  want("narrow", ((long (*)(long, long, long, long, long))m_narrow)(0x7fffff81, 0x7fffff82, 0x7fff8003, 0x7fff8004, 1), -127 + 0x82 * 2 + (0x8003 - 65536) * 3L + 0x8004 * 4L + 1);
#endif
  jumped();
  return nbad != 0;
}
