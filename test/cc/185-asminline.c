/* an asm naming a parameter as an immediate compiles only where its function is spliced,
 * held to gcc: the kernel's jump label (`asm goto` over "i"(key), "i"(branch), the entry in
 * its own table, the label its goto reaches) and a cpu-feature test ("i"(bit) and an
 * address off it). each call site lays its own copy, labels and table entry; how many sites
 * the compiler splices is its own, so the table is read as a set. a target with no
 * template here computes the same. */

struct key { int enabled; };
struct key kx = {1}, ky = {0};
unsigned char caps[4] = {0, 0x20, 0, 0};
/* text spelled like the spliced-only fn below names no function (a tracepoint's static_key_false tag) */
const char *nm = "branch";

#if defined(__x86_64__) && (defined(__OPTIMIZE__) || defined(__mooncc__))   /* the splice is the premise: gcc -O0 keeps the call */
static inline __attribute__((always_inline)) int branch(struct key *k, int b) {
  asm goto("jmp %l[yes]\n.pushsection tai_jt, \"aw\"\n.balign 8\n.quad %c0 + %c1\n.popsection"
           : : "i"(k), "i"(b) : : yes);
  return 0;
yes:
  return 1;
}
static inline __attribute__((always_inline)) int has(unsigned short bit) {
  asm goto("testb %[m], %a[byte]\n jnz %l[on]"
           : : [m] "i"(1 << (bit & 7)), [byte] "i"(&caps[bit >> 3]) : : on);
  return 0;
on:
  return 1;
}
extern const long __start_tai_jt[], __stop_tai_jt[];
#else
static int branch(struct key *k, int b) { (void)k; (void)b; return 1; }
static int has(unsigned short bit) { return (caps[bit >> 3] >> (bit & 7)) & 1; }
#endif

int f(int x) {
  if (branch(&kx, 1)) x += 5;
  return x + branch(&ky, 0) * 10 + has(13) * 100 + has(12) * 1000;
}

int main(void) {
  int bad = 0;
  if (f(1) != 116 || nm[0] != 'b') bad |= 1;
#if defined(__x86_64__) && (defined(__OPTIMIZE__) || defined(__mooncc__))
  long n = __stop_tai_jt - __start_tai_jt, sx = 0, sy = 0;
  for (long i = 0; i < n; i++) {
    if (__start_tai_jt[i] == (long)&kx + 1) sx++;
    else if (__start_tai_jt[i] == (long)&ky) sy++;
    else bad |= 2;
  }
  if (sx < 1 || sy < 1 || sx != sy) bad |= 4;
#endif
  return bad;
}
