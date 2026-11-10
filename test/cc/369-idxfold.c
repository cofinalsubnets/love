// an indexed access through a struct member or a table: base and offset fold into the address
struct e { unsigned short v; unsigned char n, b; };
struct t { long pad[3]; struct e a[4]; struct e c[4]; long w[3]; unsigned char s[4]; };
static const unsigned char tab[4] = { 3, 5, 7, 11 };
static const int wide[4] = { 100, 200, 300, 400 };

static int rd(struct t *p, long i, long j) { return p->a[i].n + p->c[j].b + tab[i] + wide[j]; }
static void wr(struct t *p, long i, long j, long v) { p->w[i] = v; p->s[j] = (unsigned char) v; }
static struct t *self(struct t *p) { return &p[0]; }

int main(void) {
 struct t x = {0};
 for (int i = 0; i < 4; i++) { x.a[i].n = (unsigned char) (i + 1); x.c[i].b = (unsigned char) (2 * i); }
 wr(&x, 2, 3, 300);
 return rd(self(&x), 1, 2) - 300 + (int) x.w[2] / 100 + x.s[3] - 44;
}
