/* directives in a function's asm, held to gcc: the template pushes a table section, names its
 * own numbered label from there (`1b - .`, and absolutely), and pops back to lay the rest of
 * the function -- the kernel's lock prefix, bug table and alternatives rows. two asms in one
 * function each lay their own `1:`; how many copies an inline function leaves is the
 * compiler's. a used static a pushed section names is laid, and the linker brackets each
 * table. a target with no template here computes the same. */

static __attribute__((used)) int helper(void) { return 5; }

#if defined(__x86_64__)
#define INC "1: lea 1(%1), %0\n"
#elif defined(__aarch64__)
#define INC "1: add %0, %1, #1\n"
#elif defined(__riscv)
#define INC "1: addi %0, %1, 1\n"
#endif

#ifdef INC
#define TAB(tag) ".pushsection tsx_tab, \"a\"\n.balign 4\n.long 1b - .\n.long " #tag "\n.popsection\n" \
                 ".pushsection tsx_abs, \"aw\"\n.balign 8\n.quad 1b\n.popsection\n"
static long bump(long x) { long r; asm volatile(INC TAB(7) : "=r"(r) : "r"(x)); return r; }
static inline long twin(long x) { long r; asm volatile(INC TAB(9) : "=r"(r) : "r"(x)); return r; }
static long pair(long x) {
  long r, s;
  asm volatile(INC TAB(3) : "=r"(r) : "r"(x));
  asm volatile(INC TAB(4) : "=r"(s) : "r"(r));
  return s;
}
static void pin(void) { asm volatile(".pushsection tsx_ptr, \"aw\"\n.balign 8\n.quad helper\n.popsection\n" : : : "memory"); }
extern const int __start_tsx_tab[], __stop_tsx_tab[];
extern char *const __start_tsx_abs[], *const __stop_tsx_abs[];
extern int (*const __start_tsx_ptr[])(void);
#endif

int main(void) {
  int bad = 0;
#ifdef INC
  long a = bump(1), b = twin(2) + twin(3), c = pair(10);
  pin();
  if (a != 2 || b != 7 || c != 12) bad |= 1;
  int n = (int)(__stop_tsx_abs - __start_tsx_abs), seen[10] = {0};
  if (__stop_tsx_tab - __start_tsx_tab != 2 * n) bad |= 2;
  for (int i = 0; i < n; i++) {
    const int *e = &__start_tsx_tab[2 * i];
    const char *at = (const char *)e + *e;
    int k;
    for (k = 0; k < n && __start_tsx_abs[k] != at; k++) ;
    if (k == n) bad |= 4;
    for (k = 0; k < i; k++)
      if (__start_tsx_abs[k] == __start_tsx_abs[i]) bad |= 8;
    if (0 <= e[1] && e[1] < 10) seen[e[1]]++;
  }
  if (seen[7] != 1 || seen[3] != 1 || seen[4] != 1 || seen[9] < 1 || seen[9] > 2 ||
      n != 3 + seen[9]) bad |= 16;
  if (__start_tsx_ptr[0]() != 5) bad |= 32;
#else
  if (helper() != 5) bad |= 1;
#endif
  return bad;
}
