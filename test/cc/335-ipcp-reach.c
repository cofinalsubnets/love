/* a static fn's constant params are judged by every call a laid body makes: one reached only
 * through an initializer's pointer counts, an unused static inline does not */
static int scale(int v, int k) { return v * k; }
static int viaptr(int v) { return scale(v, 7); }
static int (*const tab[])(int) = { viaptr };
static inline int unused(int v) { return scale(v, 5); }

int main(void)
{
	return scale(tab[0](2), 3) - 2;
}
