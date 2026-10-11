/* a64 literal loads as head.S spells them: `ldr x, =sym` and `=constant` from the section's
 * pool, `ldr x, label` and `ldrsw` across sections, `.long sym` and a `.set` read before it is
 * made, all linked here. a target with no template here computes the same in C. */
typedef unsigned long u64;

u64 tab[2] = {40, 2};
int neg = -9;

#if defined(__aarch64__)
u64 litsum(void);
__asm__(".text\n"
        ".globl litsum\n"
        "litsum:\n"
        "  ldr x0, =tab\n"
        "  ldr x1, [x0]\n"
        "  ldr x2, =tab + 8\n"
        "  ldr x2, [x2]\n"
        "  ldr x3, =0x123456789\n"
        "  ldr w4, =0x7\n"
        "  ldr x5, far\n"
        "  ldrsw x6, far + 8\n"
        "  ldr w7, word\n"
        "  add x0, x1, x2\n"
        "  add x0, x0, x5\n"
        "  add x0, x0, x6\n"
        "  add x0, x0, x7\n"
        "  ldr w9, absw\n"
        "  ldr x10, =tab\n"
        "  sub x9, x9, x10\n"
        "  add x0, x0, x9\n"
        "  movz x8, #0x2345, lsl #16\n"
        "  movk x8, #0x6789\n"
        "  movk x8, #0x1, lsl #32\n"
        "  cmp x3, x8\n"
        "  b.ne 1f\n"
        "  add x0, x0, x4\n"
        "1: ret\n"
        "  .ltorg\n"
        "word: .long .Lahead\n"
        "absw: .long tab\n"
        ".section .rodata.lit, \"a\"\n"
        "far: .quad 100\n"
        "  .long -5\n"
        ".set .Lahead, 3\n"
        ".text\n");
#else
static u64 litsum(void) { return tab[0] + tab[1] + 100 - 5 + 3 + 7; }
#endif

int main(void) { return litsum() == 40 + 2 + 100 - 5 + 3 + 7 && neg == -9 ? 0 : 1; }
