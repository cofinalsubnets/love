/* a compound literal in a static initializer is an object of its own, with static storage
 * (C11 6.5.2.5): linux's clk tables point at them -- `.hw.init = &(struct clk_init_data){..}`,
 * `.parent_names = (const char *[]){ "a", "b" }` -- and an array-typed element decays to its
 * first element's address, a row of a 2-D table (`.regs = pll_regs[N]`) or `&a[0][0]`.
 * freestanding, exit-code only. */

struct init { const char *name; const char *const *parents; int n; };
struct hw { const struct init *init; int id; };

static const unsigned char pll_regs[3][4] = { {1, 2, 3, 4}, {5, 6, 7, 8}, {9, 10, 11, 12} };
static const signed char lut[2][3] = { {-1, 2, -3}, {4, -5, 6} };

static struct hw clk_a = {
	.init = &(struct init){ .name = "a", .parents = (const char *const []){ "p0", "p1" }, .n = 2 },
	.id = 7,
};
static struct hw clk_b = { &(struct init){ "b", (const char *const []){ "q0" }, 1 }, 8 };
static const unsigned char *const regs = pll_regs[1];
static const signed char *const lp = &lut[1][0];
static const int *const ints = (const int []){ 10, 20, 30 };
static const struct init *const nested = &(struct init){ "n", (const char *const []){ "x", "y", "z" }, 3 };
/* two equal literals are two objects: each is its own, and writable */
static int *const w1 = (int []){ 1 };
static int *const w2 = (int []){ 1 };

static int str_eq(const char *a, const char *b)
{
	while (*a && *a == *b) a++, b++;
	return *a == *b;
}

int main(void)
{
	int bad = 0;
	if (!str_eq(clk_a.init->name, "a") || clk_a.init->n != 2 || clk_a.id != 7) bad |= 1;
	if (!str_eq(clk_a.init->parents[0], "p0") || !str_eq(clk_a.init->parents[1], "p1")) bad |= 2;
	if (!str_eq(clk_b.init->name, "b") || !str_eq(clk_b.init->parents[0], "q0") || clk_b.id != 8) bad |= 4;
	if (regs[0] != 5 || regs[3] != 8) bad |= 8;
	if (lp[0] != 4 || lp[1] != -5 || lp[2] != 6) bad |= 16;
	if (ints[0] != 10 || ints[2] != 30) bad |= 32;
	if (nested->n != 3 || !str_eq(nested->parents[2], "z")) bad |= 64;
	if (clk_a.init == clk_b.init || w1 == w2) bad |= 128;     /* two literals, two objects */
	*w1 = 5;
	if (*w2 != 1 || *w1 != 5) bad |= 128;                    /* and writable apart */
	return bad;
}
