// loops.c -- the loop shapes rove's tray math runs through, as standalone kernels: mooncc against
// gcc on the CODE, read by ccloops.sh (checksums, then perf instructions and cycles per kernel).
// one binary, argv[1] names the kernel, argv[2] the reps; prints a checksum.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#define N 4096
#define maxrank 8
typedef double flo;
#define NOINL __attribute__((noinline))

// plain elementwise
static NOINL void k_fadd(flo *r, const flo *a, const flo *b, uintptr_t n) {
 for (uintptr_t i = 0; i < n; i++) r[i] = a[i] + b[i]; }
static NOINL void k_iadd(intptr_t *r, const intptr_t *a, const intptr_t *b, uintptr_t n) {
 for (uintptr_t i = 0; i < n; i++) r[i] = (intptr_t)((uintptr_t) a[i] + (uintptr_t) b[i]); }
// the vbin_fill fast path: a select on a loop-invariant flag inside the loop
static NOINL void k_fsel(flo *r, const flo *ap, const flo *bp, flo sa, flo sb, int atray, int btray, uintptr_t n) {
 for (uintptr_t p = 0; p < n; p++) { flo av = atray ? ap[p] : sa, bv = btray ? bp[p] : sb; r[p] = av * bv; } }
static NOINL void k_isel(intptr_t *r, const intptr_t *ap, const intptr_t *bp, intptr_t sa, intptr_t sb, int atray, int btray, uintptr_t n) {
 for (uintptr_t p = 0; p < n; p++) { intptr_t av = atray ? ap[p] : sa, bv = btray ? bp[p] : sb; r[p] = (intptr_t)((uintptr_t) av * (uintptr_t) bv); } }
// masks and min/max
static NOINL void k_fmask(intptr_t *r, const flo *a, const flo *b, uintptr_t n) {
 for (uintptr_t i = 0; i < n; i++) r[i] = a[i] < b[i] ? 1 : 0; }
static NOINL void k_fmin(flo *r, const flo *a, const flo *b, uintptr_t n) {
 for (uintptr_t i = 0; i < n; i++) { flo av = a[i], bv = b[i]; r[i] = av < bv ? av : bv; } }
static NOINL void k_imax(intptr_t *r, const intptr_t *a, const intptr_t *b, uintptr_t n) {
 for (uintptr_t i = 0; i < n; i++) { intptr_t av = a[i], bv = b[i]; r[i] = av > bv ? av : bv; } }
// reductions
static NOINL flo k_fsum(const flo *a, uintptr_t n) {
 flo s = 0; for (uintptr_t i = 0; i < n; i++) s += a[i]; return s; }
static NOINL intptr_t k_isum(const intptr_t *a, uintptr_t n) {
 intptr_t s = 0; for (uintptr_t i = 0; i < n; i++) s += a[i]; return s; }
static NOINL flo k_dot(const flo *a, const flo *b, uintptr_t n) {
 flo s = 0; for (uintptr_t i = 0; i < n; i++) s += a[i] * b[i]; return s; }
static NOINL flo k_fmaxr(const flo *a, uintptr_t n) {
 flo m = a[0]; for (uintptr_t i = 1; i < n; i++) if (a[i] > m) m = a[i]; return m; }
static NOINL intptr_t k_all(const intptr_t *a, uintptr_t n) {
 for (uintptr_t i = 0; i < n; i++) if (!a[i]) return 0; return 1; }
// gather with a default on a miss
static NOINL void k_gather(flo *r, const flo *t, uintptr_t tn, const intptr_t *idx, flo d, uintptr_t n) {
 for (uintptr_t i = 0; i < n; i++) { uintptr_t k = (uintptr_t) idx[i]; r[i] = k < tn ? t[k] : d; } }
// a map through a function pointer, one call per element
static NOINL flo sq1(flo x) { return x * x + 1.0; }
static NOINL void k_map1(flo *r, const flo *a, flo (*fn)(flo), uintptr_t n) {
 for (uintptr_t i = 0; i < n; i++) r[i] = fn(a[i]); }
// float to int with saturation and a NaN to 0 (floor's tray)
static NOINL void k_floor(intptr_t *r, const flo *a, uintptr_t n) {
 for (uintptr_t i = 0; i < n; i++) { flo v = a[i];
  r[i] = v >= (flo) INTPTR_MAX ? INTPTR_MAX : v <= (flo) INTPTR_MIN ? INTPTR_MIN : v != v ? 0 : (intptr_t) v; } }
// the pen hash: two rounds of multiply, shift and mask under 32 bits
static NOINL void k_hash(intptr_t *r, const intptr_t *a, uintptr_t n) {
 for (uintptr_t i = 0; i < n; i++) { uintptr_t x = (uintptr_t) a[i];
  x = (x * 2654435761u) & 0xffffffffu; x ^= x >> 15;
  x = (x * 0x27d4eb2du) & 0xffffffffu; x ^= x >> 13; r[i] = (intptr_t) x; } }
// a 2d row loop, neighbours by index arithmetic
static NOINL void k_2d(flo *r, const flo *a, uintptr_t w, uintptr_t h) {
 for (uintptr_t y = 0; y < h; y++) for (uintptr_t x = 0; x < w; x++) {
  uintptr_t x1 = x + 1 < w ? x + 1 : 0, y1 = y + 1 < h ? y + 1 : 0;
  r[y * w + x] = a[y * w + x] * 0.5 + a[y * w + x1] * 0.25 + a[y1 * w + x] * 0.25; } }
// a strided read
static NOINL void k_stride(flo *r, const flo *a, uintptr_t s, uintptr_t n) {
 for (uintptr_t i = 0; i < n; i++) r[i] = a[i * s]; }
// the broadcast odometer, as love.h spells it
struct bcast { uintptr_t R; uintptr_t const *shape; intptr_t oa, ob, ca[maxrank], cb[maxrank], idx[maxrank]; };
static inline void bc_open(struct bcast *w, uintptr_t R, uintptr_t const *shape, intptr_t const *ca, intptr_t const *cb) {
 w->R = R; w->shape = shape; w->oa = w->ob = 0;
 for (uintptr_t j = 0; j < R; j++) w->ca[j] = ca[j], w->cb[j] = cb[j], w->idx[j] = 0; }
static inline void bc_step(struct bcast *w) {
 for (intptr_t j = (intptr_t) w->R - 1; j >= 0; j--) {
  w->oa += w->ca[j]; w->ob += w->cb[j];
  if (++w->idx[j] < (intptr_t) w->shape[j]) return;
  w->oa -= w->ca[j] * (intptr_t) w->shape[j]; w->ob -= w->cb[j] * (intptr_t) w->shape[j]; w->idx[j] = 0; } }
static NOINL void k_bcast(flo *r, const flo *a, const flo *b, uintptr_t n) {
 uintptr_t shape[2] = { 64, 64 }; intptr_t ca[2] = { 1, 0 }, cb[2] = { 0, 1 };   // a column meets a row
 struct bcast w; bc_open(&w, 2, shape, ca, cb);
 for (uintptr_t p = 0; p < n; p++, bc_step(&w)) r[p] = a[w.oa] + b[w.ob]; }
// a hot polynomial, the sky ramp: several float ops per element, no memory but the ends
static NOINL void k_poly(flo *r, const flo *a, flo k, uintptr_t n) {
 for (uintptr_t i = 0; i < n; i++) { flo x = a[i] * k; r[i] = ((x * 0.5 + 1.0) * x - 0.25) * x + 2.0; } }
// a byte loop: pens into a row of cells
static NOINL void k_bytes(unsigned char *r, const unsigned char *a, const unsigned char *b, uintptr_t n) {
 for (uintptr_t i = 0; i < n; i++) r[i] = (unsigned char) ((a[i] * 3 + b[i]) >> 2); }

static uint64_t bits(flo x) { uint64_t u; memcpy(&u, &x, 8); return u; }

int main(int argc, char **argv) {
 static flo a[N], b[N], r[N], t[N];
 static intptr_t ia[N], ib[N], ir[N], idx[N];
 static unsigned char ba[N], bb[N], br[N];
 const char *k = argc > 1 ? argv[1] : "fadd";
 uintptr_t reps = argc > 2 ? (uintptr_t) atol(argv[2]) : 1000;
 for (uintptr_t i = 0; i < N; i++) {
  a[i] = (flo) ((i * 7) % 13) * 0.5 + 0.25; b[i] = (flo) ((i * 3) % 11) + 1.0; t[i] = (flo) i * 0.125;
  ia[i] = (intptr_t) ((i * 7) % 13) - 6; ib[i] = (intptr_t) ((i * 3) % 11) + 1; idx[i] = (intptr_t) ((i * 37) % (N + 8));
  ba[i] = (unsigned char) (i * 7); bb[i] = (unsigned char) (i * 3); }
 a[17] = 0.0 / 0.0; a[99] = 1e300;   // a NaN and a big one for floor
 flo fs = 0; intptr_t is = 0;
 for (uintptr_t rep = 0; rep < reps; rep++) {
  uintptr_t n = N - (rep & 1);
  if (!strcmp(k, "fadd")) k_fadd(r, a, b, n);
  else if (!strcmp(k, "iadd")) k_iadd(ir, ia, ib, n);
  else if (!strcmp(k, "fsel")) k_fsel(r, a, b, 0, 2.0, 1, rep & 2, n);
  else if (!strcmp(k, "isel")) k_isel(ir, ia, ib, 0, 3, 1, rep & 2, n);
  else if (!strcmp(k, "fmask")) k_fmask(ir, a, b, n);
  else if (!strcmp(k, "fmin")) k_fmin(r, a, b, n);
  else if (!strcmp(k, "imax")) k_imax(ir, ia, ib, n);
  else if (!strcmp(k, "fsum")) fs += k_fsum(a, n);
  else if (!strcmp(k, "isum")) is += k_isum(ia, n);
  else if (!strcmp(k, "dot")) fs += k_dot(a, b, n);
  else if (!strcmp(k, "fmaxr")) fs += k_fmaxr(b, n);
  else if (!strcmp(k, "all")) is += k_all(ib, n);
  else if (!strcmp(k, "gather")) k_gather(r, t, N, idx, -1.0, n);
  else if (!strcmp(k, "map1")) k_map1(r, a, sq1, n);
  else if (!strcmp(k, "floor")) k_floor(ir, a, n);
  else if (!strcmp(k, "hash")) k_hash(ir, ia, n);
  else if (!strcmp(k, "2d")) k_2d(r, a, 64, 64 - (rep & 1));
  else if (!strcmp(k, "stride")) k_stride(r, t, 3, n / 3);
  else if (!strcmp(k, "bcast")) k_bcast(r, a, b, n);
  else if (!strcmp(k, "poly")) k_poly(r, a, 0.75, n);
  else if (!strcmp(k, "bytes")) k_bytes(br, ba, bb, n);
  else { printf("no kernel %s\n", k); return 2; } }
 uint64_t h = 0;
 for (uintptr_t i = 0; i < N; i++) h = h * 1000003u ^ bits(r[i]) ^ (uint64_t) ir[i] ^ br[i];
 printf("%s %llx %llx %ld\n", k, (unsigned long long) h, (unsigned long long) bits(fs), (long) is);
 return 0; }
