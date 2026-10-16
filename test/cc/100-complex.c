/* C99 _Complex: the types, the imaginary literal, casts (creal is (double)z),
 * union puns, + - * / and unary -, real<->complex implicit conversions. divisions
 * stay off overflow edges, where gcc's __divdc3 differs from the textbook formula. */

#define complex _Complex
#define __CMPLX(x, y, t) \
	((union { _Complex t __z; t __xy[2]; }){.__xy = {(x),(y)}}.__z)
#define CMPLX(x, y) __CMPLX(x, y, double)
#define CMPLXF(x, y) __CMPLX(x, y, float)
#define creal(x) ((double)(x))
#define crealf(x) ((float)(x))
#define __CIMAG(x, t) \
	(+(union { _Complex t __z; t __xy[2]; }){(_Complex t)(x)}.__xy[1])
#define cimag(x) __CIMAG(x, double)
#define cimagf(x) __CIMAG(x, float)
#define I (0.0f + 1.0fi)

static double complex conj_(double complex z) { return CMPLX(creal(z), -cimag(z)); }
static float complex fmul(float complex a, float complex b) { return a * b; }
static double complex catanish(double complex z)
{
	double complex w;
	double t = creal(z) + cimag(z);
	w = t;                           /* real -> complex assignment */
	w = CMPLX(w, t * 0.5);           /* complex in a real slot reads re */
	return w;
}

int main(void)
{
	double complex z = CMPLX(3.0, 4.0), w = CMPLX(1.0, 2.0);
	double complex s = z + w, d = z - w, p = z * w, q = p / w, n = -z;
	double complex m = 2.0 * z + w * 3 + I;        /* 9 + 15i */
	double complex c = conj_(z);                   /* 3 - 4i */
	double complex a = catanish(z);                /* 7 + 3.5i */
	float complex fz = CMPLXF(1.5f, 2.0f);
	float complex fp = fmul(fz, CMPLXF(2.0f, 0.0f));   /* 3 + 4i */
	double complex wide = (double complex)fz;      /* width flip up */
	float complex narrow = (float complex)z;       /* width flip down */
	int r1 = (int)creal(s) + (int)cimag(s)         /* 4 + 6 */
	       + (int)creal(d) + (int)cimag(d)         /* 2 + 2 */
	       + (int)creal(p) + (int)cimag(p)         /* -5 + 10 */
	       + (int)creal(q) * 10 + (int)cimag(q);   /* 30 + 4 */
	int r2 = (int)creal(n) + (int)cimag(n)         /* -7 */
	       + (int)creal(m) + (int)cimag(m)         /* 24 */
	       + (int)creal(c) - (int)cimag(c);        /* 7 */
	int r3 = (int)creal(a) * 2 + (int)(cimag(a) * 2.0)     /* 14 + 7 */
	       + (int)crealf(fp) + (int)cimagf(fp)             /* 3 + 4 */
	       + (int)creal(wide) * 2 + (int)cimag(wide)       /* 3 + 2 */
	       + (int)crealf(narrow) + (int)cimagf(narrow)     /* 3 + 4 */
	       + (int)sizeof(float complex) + (int)sizeof z;   /* 8 + 16 */
	return r1 + r2 + r3;
}
