/* mooncc's half: calls through a function's type keep its parameters and its `...`. 42, else the
   first check that failed */
int nd(double, ...), nf(float, int, ...), nl(long long, int, ...), ns(short, _Bool, ...), un(int, ...);
int mix(double, int, ...), many(int, ...), kr(), fx();
int fx(double, int, double);
typedef int vf(double, ...);
struct s { int (*f)(double, ...); };
int (*volatile pd)(double, ...) = nd;
int (*volatile pf)(float, int, ...) = nf;
int (*volatile pl)(long long, int, ...) = nl;
int (*volatile ps)(short, _Bool, ...) = ns;
int (*volatile pu)(int, ...) = un;
int (*volatile px)(double, int, ...) = mix;
int (*volatile pm)(int, ...) = many;
int (*volatile old)() = fx;
#ifndef SOFT
int (*volatile k)() = kr;
#endif
int (*volatile proto)(double, int, double) = fx;
volatile int one = 1;
vf *get(void) { return nd; }
int byp(int f(double, ...), int i) { return f(i); }
int main(void) {
  int i = 3, m = -5;
  if (!nd(i)) return 1;
  if (!pd(i)) return 2;
  if (!pf(1.5f, 9)) return 3;
  if (!pl(m, 9)) return 4;
  if (!ps(i + 4, 2)) return 5;
  if (!pu(3, 1.5, 7, 2.5)) return 6;
  if (!px(0.5, 3, 1.5)) return 7;
  if (!pm(10, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0)) return 8;
  if (!old(3.0, 4, 2.5)) return 9;
#ifndef SOFT
  if (!k(1.5f, 7, 2.5)) return 10;
#endif
  struct s s = { nd };
  if (!s.f(i)) return 11;
  int (*a[1])(double, ...) = { nd };
  if (!a[0](i)) return 12;
  if (!get()(i)) return 13;
  if (!byp(nd, i)) return 14;
  if (!((int (*)(double, ...)) (void *) nd)(i)) return 15;
  __typeof__(nd) *t = nd;
  if (!t(i)) return 16;
  __typeof__(&nd) u = &nd;
  if (!u(i)) return 17;
  if (!(one ? pd : (vf *) 0)(i)) return 18;
  int (*w)(double, int, double) = proto, (*o)() = old;
  if (!(one ? w : o)(3, 4, 2.5)) return 19;
  if (!(one ? o : w)(3, 4, 2.5)) return 20;
  __typeof__(one ? o : w) c = w;
  if (!c(3, 4, 2.5)) return 21;
  vf *v = nd;
  if (!(**v)(i)) return 22;
  if (_Generic(nd, int (*)(double, ...): 1, default: 0) != 1) return 23;
  if (__builtin_types_compatible_p(int (*)(double, ...), int (*)(double))) return 24;
  if (!(one ? nd : 0)(i)) return 25;
  if (!(*nd)(i)) return 26;
  if (!(0, nd)(i)) return 27;
  if (!(one ? un : un)(3, 1.5, 7, 2.5)) return 28;
  return 42; }
