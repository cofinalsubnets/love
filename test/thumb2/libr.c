/* AAPCS32 memory returns, mooncc side: a composite past 4 bytes that is no VFP
   HFA fills the caller's temp, whose address rides r0, and the arguments start
   at r1. i8/c12/big are all-int; mix mixes a float and an int, f5 is five floats
   (one past an HFA), m16 two float bases in 16 bytes: all memory under the VFP
   variant too. f3 IS an HFA, s0-s2, the register lane beside them. the g* functions
   are gcc's, so the lane crosses in both directions. */
struct i8 { int a, b; };
struct c12 { unsigned g, fg, bg; };
struct big { int a[20]; };
struct mix { float f; int i; };
struct f5 { float a[5]; };
struct m16 { float a, b; double c; };
struct f3 { float a, b, c; };

struct c12 gmk12(int x);                  /* the harness's: gcc returns into our temp */
struct big gmkbig(int x);

struct i8 mk8(int a, int b) { struct i8 r; r.a = a; r.b = b; return r; }
struct c12 mk12(unsigned x) { struct c12 r = { x, x + 1, x + 2 }; return r; }
struct c12 lit12(unsigned x) { return (struct c12) { x << 8, x, 7 }; }
struct big mkbig(int x) { struct big r; int i; for (i = 0; i < 20; i++) r.a[i] = x + i; return r; }
struct mix mkmix(float f, int i) { struct mix r; r.f = f * 2.0f; r.i = i; return r; }
struct f5 mkf5(float x) { struct f5 r; int i; for (i = 0; i < 5; i++) r.a[i] = x + (float) i; return r; }
struct m16 mkm16(float x) { struct m16 r = { x, x * 2.0f, 0.5 }; return r; }
struct f3 mkf3(float x) { struct f3 r = { x, x + 1.0f, x + 2.0f }; return r; }
/* four args past the hidden pointer: d rides the stack */
struct c12 mk4(int a, int b, int c, int d) { struct c12 r = { a + b, c, d }; return r; }
/* a float and a double in the s/d file beside the hidden pointer in r0 */
struct mix mkfd(float f, double d, int i) { struct mix r; r.f = f + (float) d; r.i = i; return r; }
/* forwarded: our sret handed straight to another memory return */
struct c12 fwd12(unsigned x) { return mk12(x * 3); }
/* ours calling gcc's, then reading members off the results */
int viag(int x) { struct c12 c = gmk12(x); struct big b = gmkbig(x);
  return (int) (c.g + c.fg + c.bg) + b.a[0] + b.a[19]; }
/* a member read straight off a call result */
unsigned mid12(unsigned x) { return mk12(x).fg; }
