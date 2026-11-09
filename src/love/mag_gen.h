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
  i++;
 }
 while (i < n) {
  s = (dlimb) a[i] + c;
  r[i] = (love_limb) s;
  c = s >> limb_bits;
  i++;
 }
 if (c) {
  r[i] = (love_limb) c;
  i++;
 }
 return (int) i;
}
static love_noinline int mag_sub(love_limb *r, love_limb const *a, int na, love_limb const *b, int nb) {
 uintptr_t n = (uintptr_t) na, m = (uintptr_t) nb, i;
 dlimb s, c;
 i = 0;
 c = 0;
 while (i < m) {
  s = (dlimb) a[i] + limb_base - ((dlimb) b[i] + c);
  r[i] = (love_limb) s;
  c = 1 - (s >> limb_bits);
  i++;
 }
 while (i < n) {
  s = (dlimb) a[i] + limb_base - c;
  r[i] = (love_limb) s;
  c = 1 - (s >> limb_bits);
  i++;
 }
 return (int) n;
}
static love_noinline int mag_mul_add_small(love_limb *a, int na, love_limb ml, love_limb ad) {
 uintptr_t n = (uintptr_t) na, i;
 dlimb s, c;
 i = 0;
 c = (dlimb) ad;
 while (i < n) {
  s = (dlimb) a[i] * (dlimb) ml + c;
  a[i] = (love_limb) s;
  c = s >> limb_bits;
  i++;
 }
 if (c) {
  a[i] = (love_limb) c;
  i++;
 }
 return (int) i;
}
