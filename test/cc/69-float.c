/* the float scalar: 4-byte storage, xmm arithmetic, conversions, the ABI.
   values chosen exactly representable in single AND double, so double-precision
   intermediates match gcc's single-precision to the bit. */
float scale(float x, float k) { return x * k; }   /* float param + float return */
int cmp(float a, float b) { return a < b; }
float g = 6.25f;                                   /* a float global (single-precision image) */
struct V { float x; float y; int n; };
struct V vv = {1.5f, 2.5f, 3};                     /* floats inside a global struct */
int main() {
  float a = 1.5f;
  float b = 2.25f;
  float c = a + b;                                 /* 3.75 */
  int r = (int)(c * 4.0f);                         /* 15 */
  float s = scale(2.5f, 3.0f);                     /* 7.5 */
  r = r + (int)s;                                  /* 22 */
  r = r + cmp(1.0f, 2.0f) + cmp(9.0f, 2.0f);       /* +1 +0 = 23 */
  float arr[3] = {0.5f, 1.5f, 2.0f};
  float acc = 0.0f;
  for (int i = 0; i < 3; i++) acc = acc + arr[i];  /* 4.0 */
  r = r + (int)acc;                                /* 27 */
  struct V lv;
  lv.x = 4.5f; lv.y = 0.5f;
  r = r + (int)(lv.x + lv.y);                      /* +5 = 32 */
  r = r + (int)g + (int)vv.x + (int)vv.y + vv.n;   /* +6 +1 +2 +3 = 44 */
  return r - 2;                                    /* 42 */
}
