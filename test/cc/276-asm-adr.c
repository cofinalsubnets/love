/* a64 adr as the kernel spells it: to a label in its own section, with an addend, and across
 * sections through R_AARCH64_ADR_PREL_LO21, linked here; an in-section literal load past a label
 * keeps its addend too. a target with no template here computes the same in C. */
typedef unsigned long u64;

#if defined(__aarch64__)
u64 adrsum(void);
__asm__(".text\n"
        ".globl adrsum\n"
        "adrsum:\n"
        "  adr x0, far\n"
        "  ldr x0, [x0]\n"
        "  adr x1, far + 8\n"
        "  ldr x1, [x1]\n"
        "  add x0, x0, x1\n"
        "  adr x2, 1f + 4\n"
        "  ldr w2, [x2]\n"
        "  add x0, x0, x2\n"
        "  ldr w3, 1f + 8\n"
        "  add x0, x0, x3\n"
        "  adr x4, .\n"
        "  adr x5, . + 8\n"
        "  sub x4, x5, x4\n"
        "  add x0, x0, x4\n"
        "  ret\n"
        "1: .long 1, 2, 3\n"
        ".section .rodata.adr, \"a\"\n"
        "far: .quad 100, 20\n"
        ".text\n");
#else
static u64 adrsum(void) { return 100 + 20 + 2 + 3 + 12; }
#endif

int main(void) { return adrsum() == 137 ? 0 : 1; }
