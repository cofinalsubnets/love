/* AAPCS32 memory returns, gcc side (-O2 -mfloat-abi=hard): gcc's hidden-pointer
   return is the reference, crossing to and from mooncc. */
struct i8 { int a, b; };
struct c12 { unsigned g, fg, bg; };
struct big { int a[20]; };
struct mix { float f; int i; };
struct f5 { float a[5]; };
struct m16 { float a, b; double c; };
struct f3 { float a, b, c; };
struct i8 mk8(int, int); struct c12 mk12(unsigned); struct c12 lit12(unsigned);
struct big mkbig(int); struct mix mkmix(float, int); struct f5 mkf5(float);
struct c12 mk4(int, int, int, int); struct mix mkfd(float, double, int);
struct c12 fwd12(unsigned); int viag(int); unsigned mid12(unsigned);
struct m16 mkm16(float); struct f3 mkf3(float);

/* gcc copies an 80-byte struct through memcpy, and nothing else here links one */
void *memcpy(void *d, const void *s, __SIZE_TYPE__ n) {
  volatile unsigned char *o = d; const unsigned char *i = s;
  while (n--) *o++ = *i++;
  return d; }

struct c12 gmk12(int x) { struct c12 r = { (unsigned) x, (unsigned) x * 2, 5 }; return r; }
struct big gmkbig(int x) { struct big r; int i; for (i = 0; i < 20; i++) r.a[i] = x * i; return r; }

static volatile int X = 41;
static volatile float F = 1.5f;
static volatile double D = 0.25;
int run(void){
 int ok = 0;
#define CK(x) do{ ok++; if(!(x)) return 100+ok; }while(0)
 { struct i8 v = mk8(X, -X); CK(v.a == 41 && v.b == -41); }
 { struct c12 v = mk12(X); CK(v.g == 41 && v.fg == 42 && v.bg == 43); }
 { struct c12 v = lit12(X); CK(v.g == 41u << 8 && v.fg == 41 && v.bg == 7); }
 { struct big v = mkbig(X); CK(v.a[0] == 41 && v.a[7] == 48 && v.a[19] == 60); }
 { struct mix v = mkmix(F, X); CK(v.f == 3.0f && v.i == 41); }
 { struct f5 v = mkf5(F); CK(v.a[0] == 1.5f && v.a[4] == 5.5f); }
 { struct c12 v = mk4(1, 2, 3, X); CK(v.g == 3 && v.fg == 3 && v.bg == 41); }
 { struct mix v = mkfd(F, D, -3); CK(v.f == 1.75f && v.i == -3); }
 { struct c12 v = fwd12(X); CK(v.g == 123 && v.fg == 124 && v.bg == 125); }
 CK(viag(X) == 41 + 82 + 5 + 0 + 41 * 19);
 CK(mid12(X) == 42);
 { struct m16 v = mkm16(F); CK(v.a == 1.5f && v.b == 3.0f && v.c == 0.5); }
 { struct f3 v = mkf3(F); CK(v.a == 1.5f && v.b == 2.5f && v.c == 3.5f); }
 return 13;
}
