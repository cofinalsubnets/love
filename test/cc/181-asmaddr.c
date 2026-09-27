/* an "i" operand that is an address, held to gcc: the kernel's bug table names a string by
 * `%c[msg] - .` and pads its entry with `.org 2b + %c[size]`, a percpu read names a global,
 * a static call a function. a const local folds into an "i" as gcc -O2 folds it; an asm's
 * output and memory input are writes and takes, so those locals never fold. a target with
 * no template here computes the same. */

struct ent { int at, msg; short line, fl; };
long cell[4];
static int f5(void) { return 5; }
extern const long __start_tai_w[];

#if defined(__x86_64__) || defined(__aarch64__)   /* riscv gcc spells no %c */
#define ENT(line, fl)                                                                        \
  asm volatile("1: nop\n.pushsection tai_tab, \"aw\"\n.balign 4\n2:\n.long 1b - .\n"          \
               ".long %c[msg] - .\n.2byte %c[ln]\n.2byte %c[f]\n.org 2b + %c[sz]\n.popsection" \
               : : [msg] "i" ("oops"), [ln] "i" (line), [f] "i" (fl), [sz] "i" (sizeof(struct ent)))
static int ping(int x) {
  enum { flags = (1 << 0) | (9 << 8) };
  ENT(57, flags);
  return x + 1;
}
extern const struct ent __start_tai_tab[], __stop_tai_tab[];
#endif

static int writes(void) {
  int x = 5, y = 6, z = 9, w = 0;
#if defined(__x86_64__)
  asm("mov $7, %0" : "=r"(x));
  asm("add $1, %0" : "+r"(y));
  asm("mov %1, %0" : "=r"(w) : "m"(z));
#else
  x = 7, y = 7, w = z;
#endif
  return (x != 7) | (y != 7) << 1 | (w != 9) << 2;
}

int main(void) {
  int bad = writes();
#if defined(__x86_64__)
  long r, q;
  asm("lea %c1(%%rip), %0" : "=r"(r) : "i"(&cell[2]));
  asm("lea %P1(%%rip), %0" : "=r"(q) : "i"(f5));
  if (r != (long)&cell[2]) bad |= 8;
  if (((int (*)(void))q)() != 5) bad |= 16;
  long a;                                   /* a displacement in its own parens, as WARN spells it */
  asm("lea (2f)(%%rip), %0\n.pushsection tai_w, \"aw\"\n.balign 8\n2: .quad 77\n.popsection" : "=r"(a));
  if (a != (long)__start_tai_w || *(long *)a != 77) bad |= 512;
#else
  if (f5() != 5) bad |= 16;
#endif
#if defined(__x86_64__) || defined(__aarch64__)
  if (ping(1) != 2) bad |= 32;
  if (__stop_tai_tab - __start_tai_tab != 1) bad |= 64;
  const struct ent *e = __start_tai_tab;
  const char *m = (const char *)&e->msg + e->msg;
  if (m[0] != 'o' || m[3] != 's' || m[4]) bad |= 128;
  if (e->line != 57 || e->fl != 0x901) bad |= 256;
#endif
  return bad;
}
