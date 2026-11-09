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
