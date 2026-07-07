/* conditional compilation: #if const-expr, #ifdef/#ifndef, #elif */
#define LEVEL 3
#if LEVEL > 2
#define BONUS 20
#else
#define BONUS 0
#endif

#ifndef MISSING
#define HAVE 5
#endif

int main() {
  int r = 0;
#ifdef LEVEL
  r = r + LEVEL;      /* 3 */
#endif
  r = r + BONUS;      /* 20 */
  r = r + HAVE;       /* 5 */
#if 2 + 3 * 4 == 14
  r = r + 1;          /* 1 */
#elif 1
  r = r + 100;
#endif
  return r;           /* 3+20+5+1 = 29 */
}
