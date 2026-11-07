/* an int expression beside an unsigned int converts to it: every int-typed shape, each op that reads
 * signedness, with the unsigned a variable and a constant local */
int printf(const char *, ...);
__attribute__((noinline)) int id(int x) { return x; }
__attribute__((noinline)) unsigned uid(unsigned x) { return x; }
#define T(e) printf("%ld\n", (long) (e)); t += (long) (e)
int main(void) {
  int c = id(1), n = id(-7); unsigned u = uid(7), big = uid(0x80000000u), lit = 0x80000000u, sev = 7; long t = 0; short sh = (short) id(-3);
  T((c - 8) / u); T((c - 8) % u); T((c - 8) < u); T((c - 8) >= u); T((c - 8) == u - 14);
  T(u / (c - 8)); T(u > (c - 8)); T((c - 8) >> 1); T(((c - 8) + u + 3) >> 1);
  T((c - 8) / sev); T((c - 8) < sev); T((c ? 3 : 4) * lit); T((c ? 3 : 4) * big); T((c + 2) * big);
  T(-n / u); T(~n < u); T((n << 1) / u); T((n * n - 99) / u); T((sh + sh) / u); T((n & n) / u); T((n | 1) / u);
  T((c ? n : n + 1) / u); T((c ? n + 1 : u) > 0); T((c ? u : n - 1) > 0); T((long) (n + 1) < (long) u);
  T((n + 1L) / u); T((n + 1L) < u); T((c - 8) / (unsigned long) u); T((c - 8) < (unsigned char) u);
  unsigned a = uid(100); a += c - 8; T(a); a /= c - 2; T(a); a = uid(100); a -= n - 1; T(a); a = uid(9); a %= c - 8; T(a);
  if ((c - 8) < u) t += 1000; if (!((c - 8) >= u)) t += 2000; while ((c - 8) < u) { t += 4000; break; }
  printf("t %ld\n", t);
  return (int) (t & 63);
}
