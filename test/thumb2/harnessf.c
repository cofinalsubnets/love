/* AAPCS-VFP bare floats, gcc side (-mfloat-abi=hard): each seam against gcc's own
   placement, twins for the arithmetic. 100+n names the first miss. */
float fadd(float, float);
float fbf(float, double, float, float, double, float);
float fmix(int, float, float, int);
float fovf(float,float,float,float,float,float,float,float,float,
           float,float,float,float,float,float,float,float);
float f2f(double); double f2d(float); int fcmp(float, float);
float fout(float);
float fvia(float (*)(int, int), int, int);
float fviaf(float (*)(float, double, float), float, float);
float fviat(float (**)(float, float), float, float);
struct api { float (*mix)(int, float, float, int); };
float fvias(const struct api *, float, float);

struct F2 { float a, b; };
struct F4 { float a, b, c, d; };
struct D2 { double a, b; };
float fh2(float, struct F2, float);
float fh4(float, struct F4, float);
float fhd(float, struct D2, float);
struct F2 fmk(float, float);

float gback(float a, double b, float c){ return a + (float)b*2.0f + c*4.0f; }
float gcrank(int a, int b){ return (float)a * 0.25f + (float)b; }
float gbf3(float a, double b, float c){ return a + (float)b*2.0f + c*4.0f; }
float gmix4(int i, float a, float b, int j){ return a*(float)i + b - (float)j; }
float gsub2(float a, float b){ return a - b*2.0f; }
static float (*gtbl[2])(float, float) = { 0, gsub2 };

static float t_fadd(float a, float b){ return a + b; }
static float t_fbf(float a, double b, float c, float d, double e, float f){
 return a + (float)b*2.0f + c*4.0f + d*8.0f + (float)e*16.0f + f*32.0f; }
static float t_fmix(int i, float a, float b, int j){ return a*(float)i + b - (float)j; }
static volatile float X = 2.5f, Y = -1.25f;

int run(void){
 int ok = 0;
#define CK(x) do{ ok++; if(!(x)) return 100+ok; }while(0)
 CK(fadd(X, Y) == t_fadd(X, Y));
 CK(fbf(X, 3.0, Y, 0.5f, 0.25f, 1.5f) == t_fbf(X, 3.0, Y, 0.5f, 0.25f, 1.5f));
 CK(fmix(3, X, Y, 2) == t_fmix(3, X, Y, 2));
 CK(fovf(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17) == 136.0f + 1700.0f);
 CK(f2f(2.0) == 2.5f);
 CK(f2d(X) == 5.0);
 CK(fcmp(Y, X) == 3 && fcmp(X, X) == 5 && fcmp(X, Y) == 7);
 CK(fout(X) == gback(X, 2.0, 0.5f) + 1.0f);
 { struct F2 s2 = {1.5f, 2.5f}; struct F4 s4 = {1.5f, 2.5f, 3.5f, 4.5f};
   struct D2 sd = {1.5, 2.5};
   CK(fh2(X, s2, Y) == X + 3.0f + 10.0f + Y*8.0f);
   CK(fh4(X, s4, Y) == X + 3.0f + 10.0f + 28.0f + 72.0f + Y*32.0f);
   CK(fhd(X, sd, Y) == X + 3.0f + 10.0f + Y*8.0f);
   struct F2 m = fmk(X, Y); CK(m.a == X && m.b == Y); }
 CK(fvia(gcrank, 6, 3) == gcrank(6, 3) + 1.0f);
 CK(fviaf(gbf3, X, Y) == gbf3(X, 2.0, Y) + 1.0f);
 { struct api a = { gmix4 }; CK(fvias(&a, X, Y) == gmix4(3, X, Y, 2)); }
 CK(fviat(gtbl, X, Y) == gsub2(X, Y) * 2.0f);
 return 16;
}
