/* a memory output, held to gcc: the kernel's atomics and counters, `lock xadd %0, %1` with a
 * "+m" beside a "+r", cmpxchg's "=a" and "+m", xchg, inc/dec/add/or on a counter, bts, and an
 * "=m" store. the asm writes the memory itself, so nothing stores back. a target with no
 * template here computes the same. */

struct atom { int counter; };
static long flags[2];

static int fetch_add(struct atom *v, int i) {
#if defined(__x86_64__)
  asm volatile("lock xaddl %0, %1" : "+r"(i), "+m"(v->counter) : : "memory");
  return i;
#else
  int o = v->counter; v->counter += i; return o;
#endif
}

static long cas(long *p, long old, long new) {
  long ret;
#if defined(__x86_64__)
  asm volatile("lock cmpxchgq %2, %1" : "=a"(ret), "+m"(*p) : "r"(new), "0"(old) : "memory");
#else
  ret = *p; if (ret == old) *p = new;
#endif
  return ret;
}

int main(void) {
  int bad = 0;
  struct atom a = {5};
  long w = 10;
  unsigned char c = 7;
  short h = 300;
  if (fetch_add(&a, 3) != 5 || a.counter != 8) bad |= 1;
  if (cas(&w, 10, 42) != 10 || w != 42) bad |= 2;
  if (cas(&w, 10, 99) != 42 || w != 42) bad |= 4;
#if defined(__x86_64__)
  unsigned char x = 9;
  asm volatile("xchgb %0, %1" : "+q"(x), "+m"(c));
  if (x != 7 || c != 9) bad |= 8;
  asm volatile("lock incl %0" : "+m"(a.counter));
  asm volatile("lock decl %0\n lock addl %1, %0" : "+m"(a.counter) : "ir"(5));
  if (a.counter != 13) bad |= 16;
  asm volatile("orw %1, %0" : "+m"(h) : "ri"((short)0x1001));
  if (h != (300 | 0x1001)) bad |= 32;
  asm volatile("lock btsq %1, %0" : "+m"(flags[1]) : "Ir"(3L) : "memory");
  if (flags[1] != 8) bad |= 64;
  long st;
  asm("movq %1, %0" : "=m"(st) : "r"(77L));
  if (st != 77) bad |= 128;
#else
  flags[1] = 8;
  if (c != 7 || h != 300) bad |= 8;
#endif
  return bad;
}
