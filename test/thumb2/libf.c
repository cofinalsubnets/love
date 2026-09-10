/* AAPCS-VFP bare floats, mooncc side. A float rides an s-register, not a widened
   double in a d-register: s0..s15, back-filled around the doubles, and the return
   in s0. gcc -mfloat-abi=hard is the reference at every seam below. */
float fadd(float a, float b){ return a + b; }

/* back-fill: a->s0, b->d1 (d0 is half-taken), c->s1, d->s4, e->d3, f->s5 */
float fbf(float a, double b, float c, float d, double e, float f){
 return a + (float)b*2.0f + c*4.0f + d*8.0f + (float)e*16.0f + f*32.0f; }

/* floats never consume a core register, so i and j ride r0 and r1 */
float fmix(int i, float a, float b, int j){ return a*(float)i + b - (float)j; }

/* seventeen: s0..s15 fill, then the stack takes the last one in a 4-byte slot */
float fovf(float a,float b,float c,float d,float e,float f,float g,float h,
           float i,float j,float k,float l,float m,float n,float o,float p,float q){
 return a+b+c+d+e+f+g+h+i+j+k+l+m+n+o+p+q*100.0f; }

float f2f(double d){ return (float)(d + 0.5); }
double f2d(float x){ return (double)x * 2.0; }
int fcmp(float a, float b){ return a < b ? 3 : a == b ? 5 : 7; }

/* a float HFA aligns to ONE slot, so struct F2 can straddle a d-register: here a
   leading float pushes it to s1,s2 and the trailing one back-fills nothing */
struct F2 { float a, b; };
struct F4 { float a, b, c, d; };
struct D2 { double a, b; };
float fh2(float x, struct F2 s, float y){ return x + s.a*2.0f + s.b*4.0f + y*8.0f; }
float fh4(float x, struct F4 s, float y){
 return x + s.a*2.0f + s.b*4.0f + s.c*8.0f + s.d*16.0f + y*32.0f; }
float fhd(float x, struct D2 s, float y){ return x + (float)s.a*2.0f + (float)s.b*4.0f + y*8.0f; }
struct F2 fmk(float a, float b){ struct F2 s; s.a = a; s.b = b; return s; }

/* the other direction: our code calls gcc's, so we do the staging */
extern float gback(float a, double b, float c);
float fout(float x){ return gback(x, 2.0, 0.5f) + 1.0f; }

/* through a POINTER, which is the playdate's whole seam: every pd->* entry is a
   function pointer. the pointer type carries its parameter list, so the arguments
   classify by the prototype and a float rides its s-slot exactly as a direct
   call's does -- the value alone could never say so, being the widened double. */
float fvia(float (*p)(int, int), int a, int b){ return p(a, b) + 1.0f; }
float fviaf(float (*p)(float, double, float), float a, float b){
 return p(a, 2.0, b) + 1.0f; }

/* the playdate's own shape: a struct of them, reached through `->` */
struct api { float (*mix)(int, float, float, int); };
float fvias(const struct api *g, float a, float b){ return g->mix(3, a, b, 2); }

/* ..and a dispatch table, where the element type reaches the call head through
   the pointer sum a[i] desugars to */
float fviat(float (**tbl)(float, float), float a, float b){ return tbl[1](a, b) * 2.0f; }
