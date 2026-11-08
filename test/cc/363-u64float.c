// an unsigned long long to float rounds once: the bits a double would lose still decide
#ifdef SHOW
#include <stdio.h>
#endif
static unsigned long long hash = 14695981039346656037ULL;
static void mix(unsigned long long x) {
#ifdef SHOW
  printf("%llx\n", x);
#endif
  for (int i = 0; i < 8; i++, x >>= 8) hash = (hash ^ (x & 255)) * 1099511628211ULL; }
static int answer(void) { return (int) ((hash ^ hash >> 32) % 251); }
volatile unsigned long long v[] = {
  0, 1, 0x1000001ULL, 0x7fffffffffffffffULL, 0x8000000000000000ULL, 0x8000008000000000ULL, 0x8000008000000001ULL,
  0x8000018000000000ULL, 0x8000017fffffffffULL, 0xffffff8000000000ULL, 0xffffff7fffffffffULL, 0xffffffffffffffffULL,
  0x4000004000000001ULL, 0x4000004000000000ULL,
};
int main(void) {
  for (int i = 0; i < (int) (sizeof v / sizeof v[0]); i++) {
    unsigned long long x = v[i];
    float f = (float) x;
    double d = (double) x;
    unsigned long long b = 0;
    for (int k = 0; k < (int) sizeof f; k++) b = b << 8 | ((unsigned char *) &f)[k];
    mix(b); b = 0;
    for (int k = 0; k < (int) sizeof d; k++) b = b << 8 | ((unsigned char *) &d)[k];
    mix(b);
  }
  return answer();
}
