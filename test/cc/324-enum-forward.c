/* an enum named before its definition is the type the definition lays, as gcc reads it: a
 * byte-wide pointee, a signed typedef, a by-value parameter. exit-code only (55) */
enum E;
enum F;
enum G;
struct s { enum E *p; };
typedef enum F F_t;
int take(enum G g);

enum E { EA, EB } __attribute__((__mode__(byte)));
enum F { FN = -1, FA };
enum G { GN = -1, GA, GB };

__attribute__((noinline)) int take(enum G g) { return g < 0 ? 1 : 2; }

int main(void)
{
	unsigned char buf[4] = { 1, 0xff, 0xff, 0xff };
	struct s v = { (enum E *) buf };
	F_t f = FN;
	int bad = 0;
	bad |= sizeof(enum E) != 1 || sizeof *v.p != 1 || *v.p != EB;
	bad |= !(f < 0) || sizeof(F_t) != sizeof(int);
	bad |= take(GN) != 1 || take(GB) != 2;
	return bad ? 1 : 55;
}
