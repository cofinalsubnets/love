/* a register named as gas spells it, held to gcc: the kernel's __get_user pins its value with
 * `register .. asm("%rdx")`, its stack pointer with `asm("%rsp")`, and clobbers `"%rcx"` -- the
 * `%` is gas's own and names the same register. a target with no template here computes the
 * same. */

#if defined(__x86_64__)
register unsigned long current_stack_pointer asm("%rsp");
static long get8(const long *p) {
  long ret;
  register long val asm("%rdx");
  asm volatile("movq (%0), %1\n xorl %k0, %k0"
               : "=a"(ret), "=r"(val), "+r"(current_stack_pointer)
               : "0"((long)p)
               : "%rcx");
  return ret ? -1 : val;
}
#else
static long get8(const long *p) { return *p; }
#endif

int main(void) {
  long v = 42, w = -7;
  return (get8(&v) != 42) | (get8(&w) != -7) << 1;
}
