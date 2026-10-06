/* gcc's mode attribute: an integer type laid at the mode's width, its signedness kept (soft-fp's
 * SItype/DItype, libgcc.h's word_type), and an enum laid at a byte (fscache's cookie state, the
 * trace enums under __mode(byte)) carried into the structs that hold it. exit-code only. */
#define __mode(x) __attribute__((__mode__(x)))

typedef int QItype __attribute__((mode(QI)));
typedef unsigned int UQItype __attribute__((mode(QI)));
typedef int HItype __attribute__((mode(HI)));
typedef int SItype __attribute__((mode(SI)));
typedef unsigned int USItype __attribute__((mode(SI)));
typedef int DItype __attribute__((mode(DI)));
typedef unsigned int UDItype __attribute__((mode(DI)));
typedef long s32 __attribute__((__mode__(__SI__)));
typedef int word_type __attribute__ ((mode (__word__)));
typedef unsigned long uptr __attribute__((mode(pointer)));
typedef char byte_t __attribute__((mode(byte)));
__attribute__((mode(DI))) int lead;

enum state {
	S_QUIET,
	S_LOOK,
	S_DROP,
} __mode(byte);
enum signs { M_NEG = -3, M_POS = 5 } __attribute__((mode(byte)));
typedef enum { W_A, W_B = 300 } wide __mode(HI);

struct cookie {
	enum state st;
	char tag;
	enum signs sg;
	wide w;
};

static int narrow(int a, long b __mode(SI), unsigned c __mode(HI))
{
	return sizeof b == 4 && sizeof c == 2 && c == 65535 && a == 1;
}

static int wants(void)
{
	__attribute__((mode(HI))) int h = -2;
	int bad = 0;
	QItype q = -1;
	UQItype uq = 255;
	DItype d = 1;
	UDItype ud = 0;
	struct cookie c;
	enum state s = S_DROP;

	bad |= sizeof(QItype) != 1 || sizeof(HItype) != 2 || sizeof(SItype) != 4;
	bad |= (sizeof(DItype) != 8 || sizeof(UDItype) != 8) << 1;
	bad |= (sizeof(s32) != 4 || sizeof(byte_t) != 1 || sizeof(lead) != 8) << 2;
	bad |= (sizeof(word_type) != sizeof(long) || sizeof(uptr) != sizeof(void *)) << 3;
	bad |= (q >= 0 || uq + 1 != 256 || (UQItype)(uq + 1) != 0) << 4;
	bad |= ((d << 40) >> 40 != 1 || (USItype)-1 < 0 || !(ud - 1 > ud)) << 5;
	bad |= (sizeof(enum state) != 1 || sizeof(enum signs) != 1 || sizeof(wide) != 2) << 6;
	c.sg = M_NEG;
	c.w = W_B;
	c.st = s;
	bad |= (sizeof c != 6 || c.sg != -3 || c.w != 300 || c.st != S_DROP) << 7;
	bad |= (sizeof h != 2 || h != -2 || !narrow(1, 7, -1)) << 8;
	return bad;
}

int main(void)
{
	return wants() != 0;
}
