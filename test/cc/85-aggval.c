struct c1 { char c; };
struct s2 { short s; };
struct i4 { int i; };
struct p8 { int x; int y; };
struct f8 { float a; float b; };
struct d8 { double d; };
union  u8 { long a; double d; unsigned char b[8]; };
struct ll { long a; long b; };
struct f16 { float a; float b; double c; };
struct c1 mkc(int v){ struct c1 r; r.c = (char)v; return r; }
struct s2 mks(int v){ struct s2 r; r.s = (short)v; return r; }
struct i4 mki(int v){ struct i4 r; r.i = v; return r; }
struct p8 mkp(int x,int y){ struct p8 r; r.x=x; r.y=y; return r; }
struct f8 mkf(float a,float b){ struct f8 r; r.a=a; r.b=b; return r; }
struct d8 mkd(double d){ struct d8 r; r.d=d; return r; }
union  u8 mku(long a){ union u8 r; r.a=a; return r; }
struct ll mkll(long a,long b){ struct ll r; r.a=a; r.b=b; return r; }
struct f16 mkf16(float a,float b,double c){ struct f16 r; r.a=a; r.b=b; r.c=c; return r; }
int tc(struct c1 v){ return v.c; }
int ts(struct s2 v){ return v.s; }
int ti(struct i4 v){ return v.i; }
int tp(struct p8 v){ return v.x + v.y; }
int tf(struct f8 v){ return (int)(v.a + v.b); }
int td(struct d8 v){ return (int)v.d; }
long tu(union u8 v){ return v.a; }
int tf16(struct f16 v){ return (int)(v.a + v.b + v.c); }
int mix(long a, struct p8 b, double c, struct f8 d, union u8 e, long f){
  return (int)(a + b.x + b.y + (int)c + (int)d.a + (int)d.b + e.a + f); }
int many(struct i4 a, struct i4 b, struct i4 c, struct i4 d, struct i4 e, struct i4 f, struct i4 g, struct i4 h){
  return a.i + b.i + c.i + d.i + e.i + f.i + g.i + h.i; }
int main() {
  int r = tc(mkc(1)) + ts(mks(2)) + ti(mki(3)) + tp(mkp(4,5)) + tf(mkf(1.5f,2.5f))
        + td(mkd(6.0)) + (int)tu(mku(7)) + mkll(8,9).b + tf16(mkf16(0.5f,1.5f,2.0));
  r += mix(1, mkp(2,3), 4.0, mkf(0.5f,1.5f), mku(5), 6);
  r += many(mki(1),mki(2),mki(3),mki(4),mki(5),mki(6),mki(7),mki(8));
  struct p8 q = mkp(10,20); struct p8 q2 = q; q2.y += mkp(1,2).y;
  return r + q2.x + q2.y - 60;
}
