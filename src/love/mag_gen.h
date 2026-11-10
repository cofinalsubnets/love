// mag_gen.h -- laid by src/love/mag.l, `make mx`. edit that file.
static love_inline int mag_add_ge(love_limb *r, love_limb const *a, int na, love_limb const *b, int nb) {
 uintptr_t n = (uintptr_t) na, m = (uintptr_t) nb, i;
 dlimb s, c;
 i = 0;
 c = 0;
 while (i < m) {
  s = (dlimb) a[i] + (dlimb) b[i] + c;
  r[i] = (love_limb) s;
  c = s >> limb_bits;
  i++; }
 while (i < n) {
  s = (dlimb) a[i] + c;
  r[i] = (love_limb) s;
  c = s >> limb_bits;
  i++; }
 if (c) {
  r[i] = (love_limb) c;
  i++; }
 return (int) i; }
static love_noinline int mag_sub(love_limb *r, love_limb const *a, int na, love_limb const *b, int nb) {
 uintptr_t n = (uintptr_t) na, m = (uintptr_t) nb, i;
 dlimb s, c;
 i = 0;
 c = 0;
 while (i < m) {
  s = (dlimb) a[i] + limb_base - ((dlimb) b[i] + c);
  r[i] = (love_limb) s;
  c = 1 - (s >> limb_bits);
  i++; }
 while (i < n) {
  s = (dlimb) a[i] + limb_base - c;
  r[i] = (love_limb) s;
  c = 1 - (s >> limb_bits);
  i++; }
 return (int) n; }
static love_noinline int mag_mul_add_small(love_limb *a, int na, love_limb ml, love_limb ad) {
 uintptr_t n = (uintptr_t) na, i;
 dlimb s, c;
 i = 0;
 c = (dlimb) ad;
 while (i < n) {
  s = (dlimb) a[i] * (dlimb) ml + c;
  a[i] = (love_limb) s;
  c = s >> limb_bits;
  i++; }
 if (c) {
  a[i] = (love_limb) c;
  i++; }
 return (int) i; }
static love_noinline void mag_mul_rows(love_limb *r, love_limb const *a, int i0, int end, love_limb const *b, int nb) {
 uintptr_t p = (uintptr_t) i0, n = (uintptr_t) end, m = (uintptr_t) nb, i, k;
 love_limb ai;
 dlimb s, c;
 if (!p) for (k = 0; k < m; k++) r[k] = 0;
 for (i = p; i < n; i++) {
  ai = (love_limb) a[i];
  c = 0;
  for (k = 0; k < m; k++) {
   s = (dlimb) ai * (dlimb) b[k] + (dlimb) r[i + k] + c;
   r[i + k] = (love_limb) s;
   c = s >> limb_bits; }
  r[i + m] = (love_limb) c; } }
static void mag_add_off(love_limb *r, int rn, love_limb const *s, int sn, int off) {
 uintptr_t n = (uintptr_t) rn, m = (uintptr_t) sn, o = (uintptr_t) off, i;
 dlimb t, c;
 c = 0;
 for (i = 0; i < m; i++) {
  t = (dlimb) r[o + i] + (dlimb) s[i] + c;
  r[o + i] = (love_limb) t;
  c = t >> limb_bits; }
 while (o + i < n) {
  if (!c) break;
  t = (dlimb) r[o + i] + c;
  r[o + i] = (love_limb) t;
  c = t >> limb_bits;
  i++; } }
static void mag_dnorm(love_limb *un, love_limb *vn, love_limb const *u, int nu, love_limb const *v, int nv, int sh) {
 uintptr_t m = (uintptr_t) nu, n = (uintptr_t) nv, s = (uintptr_t) sh, i;
 love_limb d;
 dlimb t, c;
 d = (love_limb) 1 << s;
 c = 0;
 for (i = 0; i < n; i++) {
  t = (dlimb) v[i] * (dlimb) d + c;
  vn[i] = (love_limb) t;
  c = t >> limb_bits; }
 c = 0;
 for (i = 0; i < m; i++) {
  t = (dlimb) u[i] * (dlimb) d + c;
  un[i] = (love_limb) t;
  c = t >> limb_bits; }
 un[m] = (love_limb) c; }
static void mag_ddenorm(love_limb *r, love_limb const *un, int nn, int sh) {
 uintptr_t n = (uintptr_t) nn, s = (uintptr_t) sh, i;
 love_limb d;
 dlimb t, c;
 if (!s) for (i = 0; i < n; i++) r[i] = un[i];
 else {
  d = (love_limb) 1 << (limb_bits - s);
  t = (dlimb) un[0] * (dlimb) d;
  c = t >> limb_bits;
  for (i = 0; i < n; i++) {
   t = (dlimb) un[i + 1] * (dlimb) d + c;
   r[i] = (love_limb) t;
   c = t >> limb_bits; } } }
static love_inline int mag_ge(love_limb const *a, int na, love_limb const *b, int nb) {
 uintptr_t n = (uintptr_t) na, m = (uintptr_t) nb, i;
 i = n;
 while (m < i) {
  i = i - 1;
  if (a[i]) return 1; }
 while (0 < i) {
  i = i - 1;
  if (a[i] != b[i])
   if (b[i] < a[i]) return 1;
   else return 0; }
 return 1; }
static love_inline love_limb mag_divstep(love_limb *w, love_limb const *vn, int nn) {
 uintptr_t n = (uintptr_t) nn, i;
 love_limb q;
 dlimb s, t, c, b;
 int x;
 q = mag_qhat(w, vn, nn);
 i = 0;
 c = 0;
 b = 0;
 while (i < n) {
  s = (dlimb) q * (dlimb) vn[i] + c;
  t = (dlimb) w[i] + limb_base - ((dlimb) (love_limb) s + b);
  w[i] = (love_limb) t;
  b = 1 - (t >> limb_bits);
  c = s >> limb_bits;
  i++; }
 t = (dlimb) w[n] + limb_base - (c + b);
 w[n] = (love_limb) t;
 b = 1 - (t >> limb_bits);
 while (b) {
  i = 0;
  c = 0;
  while (i < n) {
   s = (dlimb) w[i] + (dlimb) vn[i] + c;
   w[i] = (love_limb) s;
   c = s >> limb_bits;
   i++; }
  t = (dlimb) w[n] + c;
  w[n] = (love_limb) t;
  b = b - (t >> limb_bits);
  q = q - 1; }
 while (1) {
  x = mag_ge(w, nn + 1, vn, nn);
  if (!x) break;
  i = 0;
  b = 0;
  while (i < n) {
   t = (dlimb) w[i] + limb_base - ((dlimb) vn[i] + b);
   w[i] = (love_limb) t;
   b = 1 - (t >> limb_bits);
   i++; }
  t = (dlimb) w[n] + limb_base - b;
  w[n] = (love_limb) t;
  q = (love_limb) (q + 1); }
 return q; }
