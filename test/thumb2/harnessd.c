typedef unsigned u32;
extern double gd; extern float gf;
double dadd(double,double); double dsub(double,double); double dmul(double,double); double ddiv(double,double);
double dneg(double);
int dlt(double,double); int dle(double,double); int dgt(double,double); int deq(double,double); int dne(double,double);
int dnot(double);
double i2d(int); double u2d(u32); int d2i(double); u32 d2u(double);
double fload(void); void fstore(double); double gload(void); void gstore(double);
double mix(int,double,int,double); double sel2(int,double,double); double dloc(double);
int isinf9(double); double mkinf(void); int dif(double);
typedef long long s64; typedef unsigned long long u64;
double ll2d(s64); double ull2d(u64); s64 d2ll(double); u64 d2ull(double);
static volatile s64 LN = -123456789012345LL, LMIN = -9223372036854775807LL - 1;
static volatile u64 UB2 = 18446744073709551615ULL;
static volatile double DB = 1.5e15, DN = -2.9, DH = 1.2e19, DS = 0.5;
static volatile double A = 3.375, B = -1.5, Z = 0.0;
static volatile int I = -7; static volatile u32 U = 0x90000001u;
static volatile double BIG = 3000000000.0;
int run(void){
 int ok = 0;
 double nan = Z / Z, inf = 1.0 / Z;
#define CK(x) do{ ok++; if(!(x)) return 100+ok; }while(0)
 CK(dadd(A,B) == A+B);
 CK(dsub(A,B) == A-B);
 CK(dmul(A,B) == A*B);
 CK(ddiv(A,B) == A/B);
 CK(dneg(A) == -A);
 CK(dlt(B,A) == 1);
 CK(dlt(A,B) == 0);
 CK(dlt(nan,A) == 0);              /* NaN: every relation false */
 CK(dle(A,A) == 1);
 CK(dgt(A,B) == 1);
 CK(dgt(nan,A) == 0);
 CK(deq(A,A) == 1);
 CK(deq(nan,nan) == 0);
 CK(dne(nan,nan) == 1);            /* != is the one true relation on NaN */
 CK(dnot(Z) == 1);
 CK(dnot(A) == 0);
 CK(dnot(nan) == 0);               /* !NaN is false (eq AND ordered) */
 CK(i2d(I) == -7.0);
 CK(u2d(U) == 2415919105.0);       /* high bit set: unsigned, not negative */
 CK(d2i(A) == 3);
 CK(d2i(B) == -1);                 /* toward zero */
 CK(d2u(BIG) == 3000000000u);      /* past 2^31: the U-converter */
 CK(fload() == 1.25);
 fstore(A); CK(gf == 3.375f);      /* narrows exactly */
 CK(gload() == 2.5);
 gstore(B); CK(gd == -1.5);
 CK(mix(2, A, 3, B) == 2 + A*3 + B);
 CK(sel2(1, A, B) == A);
 CK(sel2(0, A, B) == B);
 CK(dloc(A) == A*2.0 + (float)(A*2.0));
 CK(isinf9(inf) == 1);
 CK(isinf9(A) == 0);
 CK(isinf9(nan) == 0);
 CK(mkinf() == inf);
 CK(dif(Z) == 7);
 CK(dif(nan) == 3);                /* a bare NaN condition is true (!= 0.0) */
 CK(dif(A) == 3);
 CK(ll2d(LN) == (double)LN);
 CK(ll2d(LMIN) == (double)LMIN);
 CK(ull2d(UB2) == (double)UB2);
 CK(ull2d(77) == 77.0);
 CK(d2ll(DN) == -2);
 CK(d2ll(DB) == (s64)DB);
 CK(d2ll(DS) == 0);
 CK(d2ull(DH) == (u64)DH);
 return 45;
}
