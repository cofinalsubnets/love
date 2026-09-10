/* rung 5, gcc side (-O2 -mfloat-abi=hard): the HFA d-pairs and the AAPCS32
   variadic word walk cross the gcc<->mooncc boundary in BOTH directions --
   real ABI interop, not just self-consistency. */
struct zn { double re, im; };
struct dd { double d; };
struct ii { short a, b; };
struct zn zmake(double, double); struct zn zadd(struct zn, struct zn);
struct zn zmul(struct zn, struct zn); double znorm(struct zn);
double zmix(double, struct zn, int, struct zn); double zchain(double);
struct dd dmake(double); double dget(struct dd);
struct ii imake(int, int); int isum(struct ii);
int vsum(int, ...); int vnth(int, ...); int vcall(void);
int ovnamed(int, int, int, int, int, ...);

static volatile double X = 2.5, Y = -1.25;
int run(void){
 int ok = 0;
 struct zn a, b, c;
#define CK(x) do{ ok++; if(!(x)) return 100+ok; }while(0)
 a = zmake(X, Y);                       /* HFA return crosses mooncc->gcc */
 CK(a.re == X && a.im == Y);
 b = zmake(1.0, 3.0);
 c = zadd(a, b);                        /* HFA args cross gcc->mooncc */
 CK(c.re == X+1.0 && c.im == Y+3.0);
 c = zmul(a, b);
 CK(c.re == X*1.0 - Y*3.0);
 CK(c.im == X*3.0 + Y*1.0);
 CK(znorm(a) == X*X + Y*Y);
 CK(zmix(0.5, a, 3, b) == 0.5 + X*3 + 3.0);   /* doubles + two HFAs + an int interleave */
 { double x = 1.5;                      /* zchain vs gcc's own arithmetic */
   struct zn ga, gb, gc;
   ga.re = x; ga.im = 2.0*x; gb.re = x+1.0; gb.im = 2.0*x-3.0;
   gc.re = ga.re*gb.re - ga.im*gb.im; gc.im = ga.re*gb.im + ga.im*gb.re;
   CK(zchain(x) == gc.re*gc.re + gc.im*gc.im + gc.re); }
 { struct dd d = dmake(X); CK(d.d == X); CK(dget(d) == X*2.0); }
 { struct ii v = imake(-7, 1000); CK(isum(v) == 993); }
 CK(vsum(0) == 0);
 CK(vsum(1, 42) == 42);
 CK(vsum(6, 1,2,3,4,5,6) == 21);        /* anonymous words past r0-r3 */
 CK(vnth(0, 11, 22, 33) == 11);
 CK(vnth(2, 11, 22, 33) == 33);
 CK(vcall() == 2100 + 9);
 CK(ovnamed(1,2,3,4,5, 6, 7) == 1+20+300+4000+50000+600000+7000000);
 CK(znorm(zadd(zmake(1.0,2.0), zmake(3.0,4.0))) == 4.0*4.0 + 6.0*6.0);
 return 18;
}
