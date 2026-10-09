/* a symbol's page and its :lo12: in assembly, as the kernel's adr_l, ldr_l and str_l spell
 * them: adrp, then add, ldr, ldrb and str at :lo12:, an addend riding on the symbol. a target
 * with no template here computes the same in C. */
typedef unsigned long u64;

u64 tab[3] = {40, 2, 9};
unsigned char bytes[4] = {1, 2, 7, 4};
int seen;

#if defined(__aarch64__)
u64 adrsum(void);
__asm__(".text\n"
        ".globl adrsum\n"
        "adrsum:\n"
        "  adrp x0, tab + 8\n"
        "  add x0, x0, :lo12:tab + 8\n"
        "  ldr x1, [x0]\n"
        "  adrp x2, tab\n"
        "  ldr x3, [x2, :lo12:tab]\n"
        "  ldr x4, [x2, :lo12:tab + 16]\n"
        "  adrp x5, bytes\n"
        "  ldrb w6, [x5, :lo12:bytes + 2]\n"
        "  adrp x7, seen\n"
        "  mov w8, #1\n"
        "  str w8, [x7, :lo12:seen]\n"
        "  add x0, x1, x3\n"
        "  add x0, x0, x4\n"
        "  add x0, x0, x6\n"
        "  ret\n");
#else
static u64 adrsum(void) { seen = 1; return tab[1] + tab[0] + tab[2] + bytes[2]; }
#endif

int main(void) { return adrsum() == 2 + 40 + 9 + 7 && seen == 1 ? 0 : 1; }
