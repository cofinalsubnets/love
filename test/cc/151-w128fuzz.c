/* a seeded differential over the hand-built 128-bit lanes: u128/u64 divide (a
 * divisor past 2^63) and shifts by a register count (0, 64, 127). 20000 rounds
 * hashed into stdout and the exit; refused off the d128 targets. */

typedef unsigned __int128 u128;
typedef __int128 s128;

int printf(const char *, ...);

static unsigned long st = 0x243f6a8885a308d3UL;
static unsigned long rnd(void) {
 st ^= st << 13; st ^= st >> 7; st ^= st << 17; return st; }

/* a macro, not a call: a wide value is not carried as a parameter on any target */
#define mix(v) do { u128 v_ = (v); h = (h ^ v_) * (u128) 0x9e3779b97f4a7c15UL + 1; } while (0)

int main(void) {
 u128 h = 0;
 for (int i = 0; i < 20000; i++) {
  unsigned long a = rnd(), b = rnd(), d = rnd();
  u128 n = ((u128) a << 64) | b;
  if (d == 0) d = 1;

  /* the divide two-step, and the algebra that binds quotient to remainder */
  u128 q = n / (u128) d, r = n % (u128) d;
  mix(q); mix(r);
  if (q * (u128) d + r != n) { printf("DIVFAIL %d\n", i); return 1; }
  if (r >= (u128) d) { printf("REMFAIL %d\n", i); return 1; }
  /* a small divisor is the wide-quotient path (the high half divides too) */
  unsigned long sd = (b & 63) + 1;
  mix(n / (u128) sd); mix(n % (u128) sd);

  /* the v-forms: a random count, then all three boundaries by hand */
  int sh = (int) (d % 128);
  mix(n << sh); mix(n >> sh); mix((u128) (((s128) n) >> sh));
  mix(n << 0); mix(n >> 0); mix((u128) (((s128) n) >> 0));
  mix(n << 64); mix(n >> 64); mix((u128) (((s128) n) >> 64));
  mix(n << 127); mix(n >> 127); mix((u128) (((s128) n) >> 127));

  /* the widening product, the general one, and the carry chain both ways */
  mix((u128) a * b); mix(n * (u128) d);
  mix(n + (u128) d); mix(n - (u128) d); mix(-n);

  /* every relation, both signednesses */
  mix((u128) (n < (u128) d));  mix((u128) (n > (u128) d));
  mix((u128) (n <= (u128) d)); mix((u128) (n >= (u128) d));
  mix((u128) (n == (u128) d)); mix((u128) (n != (u128) d));
  mix((u128) ((s128) n < (s128) d));  mix((u128) ((s128) n > (s128) d));
  mix((u128) ((s128) n <= (s128) d)); mix((u128) ((s128) n >= (s128) d)); }

 printf("%016lx%016lx\n", (unsigned long) (h >> 64), (unsigned long) h);
 unsigned long f = (unsigned long) (h >> 64) ^ (unsigned long) h;
 return (int) ((f ^ f >> 7 ^ f >> 14 ^ f >> 21) & 127); }   /* under 128: no exit reads as a signal */
