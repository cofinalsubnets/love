/* the flags word through the stack, held to gcc: a save reads it with pushf/pop into any
 * register or memory ("=rm"), a restore writes it back with push/popf. bit 1 always reads
 * set, and user code runs with interrupts on. a target with no template computes the same. */

static unsigned long save(void) {
#if defined(__x86_64__)
  unsigned long flags;
  asm volatile("# __raw_save_flags\n\tpushf ; pop %0" : "=rm"(flags) : : "memory");
  return flags;
#else
  return 0x202;
#endif
}

static void restore(unsigned long f) {
#if defined(__x86_64__)
  asm volatile("push %0 ; popfq" : : "g"(f) : "memory", "cc");
#else
  (void)f;
#endif
}

int main(void) {
  unsigned long f = save();
  restore(f);
  unsigned long g = save();
  return ((f & 0x202) != 0x202) | (((g & 0x202) != 0x202) << 1);
}
