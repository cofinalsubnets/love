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
