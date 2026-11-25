/* a constant memcpy to or from a small local array, beside its elements: in, out, array to
 * array, part of one, through a pointer the copy rewrites, an argument with an effect, an
 * unaligned source, and the arrays that must stay whole. 0 is agreement */
void *memcpy(void *, void const *, unsigned long);
typedef unsigned int u32;
typedef unsigned long long u64;

#define NI __attribute__((noinline))
#define R(x, n) ((x) << (n) | (x) >> (32 - (n)))

NI static void mix(u32 const *in, u32 *out) {
  u32 x[16];
  memcpy(x, in, sizeof x);
  for (int i = 0; i < 4; i++) x[0] += x[4], x[12] = R(x[12] ^ x[0], 16), x[5] ^= x[12] + x[15];
  for (int i = 0; i < 16; i++) out[i] = x[i] + in[i]; }

/* the same with the copy hidden: what mix must answer */
NI static void mixv(u32 const *in, u32 *out) {
  volatile u32 x[16];
  for (int i = 0; i < 16; i++) x[i] = in[i];
  for (int i = 0; i < 4; i++) x[0] += x[4], x[12] = R(x[12] ^ x[0], 16), x[5] ^= x[12] + x[15];
  for (int i = 0; i < 16; i++) out[i] = x[i] + in[i]; }

/* in place: both ends one object */
NI static void turn(u32 *p) {
  u32 x[4];
  memcpy(x, p, 16);
  u32 t = x[0]; x[0] = x[1]; x[1] = x[2]; x[2] = x[3]; x[3] = t;
  memcpy(p, x, 16); }

/* array to array, then part of one */
NI static u32 two(u32 const *p) {
  u32 a[4], b[4];
  memcpy(a, p, sizeof a);
  a[0]++;
  memcpy(b, a, sizeof b);
  a[0] = 9;
  memcpy(b, a, 8);
  return b[0] + b[1] * 10 + b[2] * 100 + b[3] * 1000; }

/* the first element's width is not the source's */
NI static u64 wide(unsigned char const *p) {
  u64 w[2];
  memcpy(w, p + 1, 16);
  return w[0] ^ w[1]; }

/* the pointers themselves are what is copied over */
static void *cell[2];
NI static int self(void) {
  void **p = cell, *q[2];
  cell[0] = cell, cell[1] = &cell[1];
  q[0] = cell + 1, q[1] = cell;
  memcpy(p[0], q, sizeof q);
  return (cell[0] != (void *) (cell + 1)) | (cell[1] != (void *) cell) << 1 | (q[0] != (void *) (cell + 1)) << 2; }

/* an argument's effect once, and an index off the array being filled */
static int hits;
NI static u32 *step(u32 *p) { hits++; return p; }
NI static int once(u32 *p) {
  u32 x[2];
  x[0] = 1, x[1] = 0;
  memcpy(x, step(p) + x[0], sizeof x);
  if (hits) memcpy(step(p), x, sizeof x);
  return hits != 2 || x[0] != p[0] || x[1] != p[1]; }

/* as an arm of its own, its value read, a variable index, floats, chars, a shadowed name */
NI static u32 arm(int c, u32 const *p) {
  u32 x[2] = { 1, 2 };
  if (c) memcpy(x, p, sizeof x); else memcpy(x, p + 2, sizeof x);
  return x[0] * 16 + x[1]; }
NI static u32 val(u32 const *p) { u32 x[2]; u32 *q = memcpy(x, p, sizeof x); return q[0] + x[1]; }
NI static u32 var(u32 const *p, int i) { u32 x[4]; memcpy(x, p, sizeof x); return x[i] + x[1]; }
NI static float flt(float const *p) { float x[2]; memcpy(x, p, sizeof x); return x[0] - x[1]; }
NI static int chr(char const *p) { char x[4]; memcpy(x, p, 4); return x[0] + x[3]; }
static void zap(void *d, void const *s, unsigned long n) { *(u32 *) d = 7; (void) s, (void) n; }
NI static u32 shade(u32 const *p) {
  void (*memcpy)(void *, void const *, unsigned long) = zap;
  u32 x[2];
  x[0] = 1, x[1] = 2;
  memcpy(x, p, sizeof x);
  return x[0] * 10 + x[1]; }

/* the whole ones: onto itself, half an element, a char alias, the bytes through a union, inside */
NI static u32 same(u32 const *p) { u32 x[2]; x[0] = p[0], x[1] = p[1]; memcpy(x, x, sizeof x); return x[0] * 10 + x[1]; }
NI static u32 half(u32 const *p) {
  u32 x[2] = { 0x11111111u, 0x22222222u }, y[2];
  memcpy(x, p, 6);
  memcpy(y, x, 8);
  unsigned char c[8], *q = (unsigned char *) y;
  for (int i = 0; i < 8; i++) c[i] = q[i];
  return c[7] == 0x22 && c[6] == 0x22 && x[0] == p[0]; }
NI static u32 ali(u32 const *p) { u32 x[2]; memcpy(x, p, sizeof x); ((unsigned char *) x)[0] ^= 0; return ((unsigned char *) x)[0] == ((unsigned char const *) p)[0] && x[1] == p[1]; }
NI static u32 uni(u32 const *p) { union { u32 w[2]; unsigned char b[8]; } u; memcpy(u.w, p, 8); return u.b[0] == ((unsigned char const *) p)[0] && u.w[1] == p[1]; }
NI static u32 in1(u32 const *p) { u32 x[3] = { 9, 9, 9 }; memcpy(x + 1, p, 8); return x[0] * 100 + x[1] * 10 + x[2]; }
NI static u32 part(u32 const *p) { u32 x[4] = { 9, 9, 9, 9 }; memcpy(x, p, 8); return x[0] * 1000 + x[1] * 100 + x[2] * 10 + x[3]; }

int main(void) {
  u32 in[16], a[16], b[16];
  for (int i = 0; i < 16; i++) in[i] = 0x9e3779b9u * (u32) (i + 1);
  mix(in, a), mixv(in, b);
  for (int i = 0; i < 16; i++) if (a[i] != b[i]) return 1;
  u32 t[4] = { 1, 2, 3, 4 };
  turn(t);
  if (t[0] != 2 || t[1] != 3 || t[2] != 4 || t[3] != 1) return 2;
  if (two(t) != 9 + 30 + 400 + 1000) return 3;
  unsigned char raw[24];
  for (int i = 0; i < 24; i++) raw[i] = (unsigned char) (i * 7 + 1);
  u64 w0 = 0, w1 = 0;
  memcpy(&w0, raw + 1, 8), memcpy(&w1, raw + 9, 8);
  if (wide(raw) != (w0 ^ w1)) return 4;
  if (self()) return 5;
  u32 s[4] = { 5, 6, 7, 8 };
  if (once(s)) return 6;
  u32 v[4] = { 1, 2, 3, 4 };
  if (arm(1, v) != 18 || arm(0, v) != 52) return 7;
  if (val(v) != 3 || var(v, 3) != 6) return 8;
  float f[2] = { 2.5f, 1.0f };
  if (flt(f) != 1.5f || chr("abcd") != 'a' + 'd') return 9;
  if (same(v) != 12 || !half(v) || !ali(v) || !uni(v) || in1(v) != 912 || part(v) != 1299) return 11;
  return shade(v) != 72 ? 10 : 0; }
