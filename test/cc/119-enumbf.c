/* an enum with no negative enumerator is unsigned, so an enum bit-field reads
 * back zero-extended -- by definition, by tag alone, or anonymous in the member.
 * each check adds 1: the exit code is the pass count. */

enum pos { P0 = 0, P148 = 148, P149 };            /* bit 7 set, none negative */
enum neg { N1 = -1, N148 = 148 };                 /* one negative: stays signed */

struct bf {
	enum pos  a : 8;
	enum neg  b : 9;
	unsigned  c : 3;
	int       d : 4;                          /* the plain lanes, unregressed */
};

struct anon { enum { A148 = 148, A149 } y : 8; };

static int widen(enum pos p) { return p; }

int main(void)
{
	struct bf s;
	struct anon t;
	enum pos p = P148;
	enum neg n = N1;
	int r = 0;

	s.a = P148; s.b = N1; s.c = 5; s.d = -3;
	t.y = A148;

	r += s.a == 148;                          /* the 00218 shape */
	r += s.b == -1;                           /* a negative enumerator keeps the sign */
	r += s.c == 5;
	r += s.d == -3;
	r += t.y == 148;
	r += p == 148;
	r += n < 0;
	r += widen(P149) == 149;
	r += sizeof(enum pos) == 4;               /* the width does not move */
	switch (s.a) {
	case P148: r += 1; break;                 /* what took `default` before */
	default:   break;
	}
	return r;
}
