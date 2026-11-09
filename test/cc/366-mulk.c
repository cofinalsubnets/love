// a multiply by a constant, as a shift or a lea or an imul, answers as the multiply; narrow types wrap
static unsigned long long hash = 14695981039346656037ULL;
static void mix(unsigned long long x) { for (int i = 0; i < 8; i++, x >>= 8) hash = (hash ^ (x & 255)) * 1099511628211ULL; }
volatile long vl[] = { 0, 1, -1, 7, -7, 1000, -1000, 0x7fffffffL, -0x7fffffffL - 1 };
volatile int vi[] = { 0, 1, -1, 7, 65536, 0x7fffffff, -0x7fffffff - 1, 0x40000000 };
volatile unsigned vu[] = { 0, 1, 0xffffffffu, 0x80000000u, 0x55555555u };
volatile short vs[] = { 0, 1, -1, 32767, -32768 };
volatile unsigned long long vq[] = { 0, 3, 0xffffffffffffffffULL, 0x8000000000000000ULL };
struct s3 { char a[3]; }; struct s8 { long long a; }; struct s24 { long long a[3]; }; struct s40 { long long a[5]; };
#define K(x, T) do { T v_ = (x); mix((unsigned long long) (v_ * 2)); mix((unsigned long long) (v_ * 3)); mix((unsigned long long) (v_ * 4)); \
  mix((unsigned long long) (5 * v_)); mix((unsigned long long) (v_ * 6)); mix((unsigned long long) (v_ * 7)); mix((unsigned long long) (8 * v_)); \
  mix((unsigned long long) (v_ * 9)); mix((unsigned long long) (v_ * 10)); mix((unsigned long long) (v_ * 12)); mix((unsigned long long) (v_ * 18)); \
  mix((unsigned long long) (v_ * 36)); mix((unsigned long long) (v_ * 72)); mix((unsigned long long) (v_ * 1000)); mix((unsigned long long) (v_ * 1024)); \
  mix((unsigned long long) (v_ * -8)); mix((unsigned long long) (v_ * 1)); mix((unsigned long long) (v_ * 0)); } while (0)
static struct s3 a3[4]; static struct s8 a8[4]; static struct s24 a24[4]; static struct s40 a40[4];
int main(void) {
  for (int i = 0; i < (int) (sizeof vl / sizeof vl[0]); i++) { int t = vl[i]; if (t <= 1000 && t >= -1000) K(t, int); K((unsigned) t, unsigned); }
  for (int i = 0; i < (int) (sizeof vi / sizeof vi[0]); i++) { int t = vi[i]; if (t <= 8 && t >= -8) K(t, int); K((unsigned) t, unsigned); }
  for (int i = 0; i < (int) (sizeof vu / sizeof vu[0]); i++) K(vu[i], unsigned);
  for (int i = 0; i < (int) (sizeof vs / sizeof vs[0]); i++) K((unsigned short) vs[i], unsigned);
  for (int i = 0; i < (int) (sizeof vq / sizeof vq[0]); i++) K(vq[i], unsigned long long);
  for (volatile int i = 0; i < 4; i++) {
    mix((unsigned long long) ((char *) &a3[i] - (char *) a3)); mix((unsigned long long) ((char *) (a8 + i) - (char *) a8));
    mix((unsigned long long) ((char *) &a24[i] - (char *) a24)); mix((unsigned long long) ((char *) (a40 + i) - (char *) a40));
    mix((unsigned long long) ((a40 + i) - a40));
  }
  return (int) ((hash ^ hash >> 32) % 251);
}
