/* stage 7c-iii: the C-feature tail love.c exercises -- sizeof(expr), bare void
   return, folded/EOF case labels, function-pointer casts, function-type
   typedefs, multi-declarator typedefs, and object-vs-function macros. */
#ifndef EOF
#define EOF (-1)                 /* an OBJECT macro (space before the paren) */
#endif
#define ADD(a, b) ((a) + (b))    /* a function macro (no space) */

typedef long word, num;          /* multi-declarator typedef */
typedef int ifn(int);            /* function-type typedef */

long table[6];

static int classify(int c) {
  switch (c) {
    case EOF: return 7;          /* EOF -> (-1), folded */
    case '(': case '[': return 2;
    case 1 << 3: return 5;       /* a folded constant expression (8) */
    default: return 0;
  }
}

static int dbl(int x) { return x + x; }

static void bump(long *p) { if (!p) return; *p += 1; }   /* bare void return */

int main(void) {
  int r = 0;
  r += (int) (sizeof(table) / sizeof(*table));   /* sizeof(expr): 6 */
  r += classify(EOF);                            /* 7 */
  r += classify('[');                            /* 2 */
  r += classify(8);                              /* 5 */
  void *fp = (void *) dbl;
  ifn *g = (ifn *) fp;                           /* function-type typedef as a pointer */
  r += ((int (*)(int)) fp)(10);                  /* fn-ptr cast + call: 20 */
  r += g(3);                                     /* 6 */
  long v = 40;
  bump(&v); bump(0);                             /* 41 */
  r += (int) v - 40;                             /* +1 */
  r += ADD(1, 2);                                /* 3 */
  return r;                                      /* 6+7+2+5+20+6+1+3 = 50 */
}
