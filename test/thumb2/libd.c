typedef unsigned u32;
double gd = 2.5;
float gf = 1.25;
double dadd(double a, double b){ return a + b; }
double dsub(double a, double b){ return a - b; }
double dmul(double a, double b){ return a * b; }
double ddiv(double a, double b){ return a / b; }
double dneg(double a){ return -a; }
int dlt(double a, double b){ return a < b; }
int dle(double a, double b){ return a <= b; }
int dgt(double a, double b){ return a > b; }
int deq(double a, double b){ return a == b; }
int dne(double a, double b){ return a != b; }
int dnot(double a){ return !a; }
double i2d(int x){ return (double)x; }
double u2d(u32 x){ return (double)x; }
int d2i(double d){ return (int)d; }
u32 d2u(double d){ return (u32)d; }
double fload(void){ return gf; }
void fstore(double d){ gf = (float)d; }
double gload(void){ return gd; }
void gstore(double d){ gd = d; }
double mix(int a, double b, int c, double d){ return a + b * c + d; }
double sel2(int c, double a, double b){ return c ? a : b; }
double dloc(double x){ double t = x * 2.0; float f = (float)t; return t + f; }
int isinf9(double d){ return __builtin_isinf(d); }
double mkinf(void){ return __builtin_inf(); }
int dif(double a){ if (a) return 3; return 7; }
typedef long long s64; typedef unsigned long long u64;
double ll2d(s64 x){ return (double)x; }
double ull2d(u64 x){ return (double)x; }
s64 d2ll(double d){ return (s64)d; }
u64 d2ull(double d){ return (u64)d; }
