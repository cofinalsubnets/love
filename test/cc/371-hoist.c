// wide literals and addresses made in loops, whatever way the loop is entered
#include <stdint.h>
static const unsigned char tab[4] = { 3, 5, 7, 11 };
static int other[3] = { 1, 2, 3 };

static uint64_t mix(uint64_t h, int n) {
 for (int i = 0; i < n; i++) { h ^= 0x9e3779b185ebca87ULL; h *= 0xc2b2ae3d27d4eb4fULL; h += 0x9e3779b185ebca87ULL; }
 return h;
}
static int tabs(int n) {
 int s = 0;
 for (int i = 0; i < n; i++) { s += tab[i & 3]; if (i & 1) s += other[i % 3]; else s -= other[(i + 1) % 3]; }
 return s;
}
// the literal lies past a label jumped to from outside the loop
static uint64_t into(int n, int skip) {
 uint64_t h = 1;
 int i = 0;
 if (skip) goto in;
 while (i < n) {
  h += 7;
in:
  h ^= 0x1234567890abcdefULL;
  i++;
 }
 return h;
}
static uint64_t nest(int n) {
 uint64_t h = 0;
 for (int i = 0; i < n; i++) {
  uint64_t a = 0xfedcba9876543210ULL;
  for (int j = 0; j <= i; j++) h += a >> j;
  do { h ^= 0xabcdef0123456789ULL; } while (h & 1 && (h = h >> 1));
 }
 return h;
}
static int many(int n) {
 uint64_t s = 0;
 for (int i = 0; i < n; i++)
  s += 0x1111111111111ULL + 0x2222222222222ULL * i + (0x3333333333333ULL ^ i) + (0x4444444444444ULL | i)
     + (0x5555555555555ULL & i) + (0x6666666666666ULL - i);
 return (int) (s >> 32);
}

int main(void) {
 uint64_t t = mix(5, 3) + tabs(9) + into(3, 0) + into(3, 1) + into(0, 1) + nest(4) + (uint64_t) many(5);
 return (int) ((t ^ t >> 32) % 251);
}
