/* the mooncc object beside mipsrel.c's REL ones: its entry, and a function they call */
int cc_main(void);
int mo(int x) { return 3 * x; }
void _start(void) {
  int r = cc_main();
  __attribute__((holo)) asm volatile("mov r2, %0\n\tli r0, 4001\n\tsys" :: "r"(r) : "r0", "r2");
  for (;;);
}
