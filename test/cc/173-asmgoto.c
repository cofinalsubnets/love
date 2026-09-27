/* gcc's asm goto, held to gcc: the jump lands on the function's own label, numbered
 * after every operand (past two, %l3 is the second) or named (%l[five]); a value the fall-through
 * knows does not ride the asm's edge; an edge back up is a loop; a label is reached by
 * the asm and a plain goto alike. a target with no template here computes the same. */

#if defined(__x86_64__)
#define PICK  "cmpq $5, %0\n\tje %l[five]\n\tcmpq $7, %0\n\tje %l3"
#define NZ    "testq %0, %0\n\tjnz %l[t]"
#define LESS  "cmpq %1, %0\n\tjl %l[top]"
#define ALWAYS "jmp %l0"
#elif defined(__aarch64__)
#define PICK  "cmp %0, #5\n\tb.eq %l[five]\n\tcmp %0, #7\n\tb.eq %l3"
#define NZ    "cmp %0, #0\n\tb.ne %l[t]"
#define LESS  "cmp %0, %1\n\tb.lt %l[top]"
#define ALWAYS "b %l0"
#elif defined(__riscv)
#define PICK  "beq %0, %1, %l[five]\n\tli %1, 7\n\tbeq %0, %1, %l3"
#define NZ    "bnez %0, %l[t]"
#define LESS  "blt %0, %1, %l[top]"
#define ALWAYS "j %l0"
#endif

#ifdef PICK
static int pick(long x) {
  long k = 5;
  asm goto(PICK : : "r"(x), "r"(k) : "cc" : five, seven);
  return 1;
five:
  return 5;
seven:
  return 7;
}

static long nz(long x) {
  long y = x + 3;
  asm goto(NZ : : "r"(x) : "cc" : t);
  y = 10;
t:
  return y;
}

static long nz2(long x) {
  long y = x;
  asm goto(NZ : : "r"(x) : "cc" : t);
  y = x * 0 + 10;
t:
  return y + 1;
}

static long upto(long n) {
  long i = 0;
top:
  i++;
  asm volatile goto(LESS : : "r"(i), "r"(n) : "cc" : top);
  return i;
}

static int both(int x) {
  int r = 0;
  if (x > 100) goto out;
  r = 1;
  __asm__ __volatile__ goto(ALWAYS : : : : out);
  r = 2;
out:
  return r + x;
}
#else
static int pick(long x) { return x == 5 ? 5 : x == 7 ? 7 : 1; }
static long nz(long x) { return x ? x + 3 : 10; }
static long nz2(long x) { return x ? x + 1 : 11; }
static long upto(long n) { long i = 0; do i++; while (i < n); return i; }
static int both(int x) { return x > 100 ? x : 1 + x; }
#endif

int main(void) {
  int bad = 0;
  if (pick(5) != 5 || pick(7) != 7 || pick(3) != 1) bad |= 1;
  if (nz(0) != 10 || nz(4) != 7 || nz2(0) != 11 || nz2(4) != 5) bad |= 2;
  if (upto(1) != 1 || upto(6) != 6) bad |= 4;
  if (both(200) != 200 || both(5) != 6) bad |= 8;
  return bad;
}
