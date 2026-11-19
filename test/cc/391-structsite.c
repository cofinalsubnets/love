// a local struct whose address goes to a call that keeps no pointer carries every member to it,
// the ones this function never names as well: linux's update_sched_clock, its read hook
typedef unsigned long long u64;
struct rd { u64 ns, cyc, mask; u64 (*read)(void); unsigned mult, shift; };
struct cd { unsigned seq; struct rd d[2]; u64 (*act)(void); };
static struct cd cd;
static u64 seven(void) { return 7; }
__attribute__((noinline)) static void put(struct rd *r) { cd.d[1] = *r; }
static void upd(void)
{
	struct rd rd;
	rd = cd.d[0];
	u64 cyc = cd.act();
	rd.ns = rd.ns + (((cyc - rd.cyc) & rd.mask) * rd.mult >> rd.shift);
	rd.cyc = cyc;
	put(&rd);
}
__attribute__((noinline)) static int sum(struct rd *r) { return (int) (r->ns + r->cyc + r->mask) + r->mult + r->shift + (r->read == seven); }
static int named(void) { struct rd rd = cd.d[1]; rd.ns = 1; return sum(&rd); }
__attribute__((noinline)) static void bump(struct rd *r) { r->shift += 3; r->mult += 2; }
static int back(void) { struct rd rd; rd = cd.d[0]; rd.ns = 2; bump(&rd); return rd.ns + rd.shift + sum(&rd); }

int main(void)
{
	cd.d[0].read = seven; cd.d[0].mask = ~0ull; cd.d[0].mult = 1; cd.d[0].shift = 1; cd.act = seven;
	upd();
	if (cd.d[1].read != seven || cd.d[1].mult != 1 || cd.d[1].shift != 1) return 1;
	return (named() + back() + (int) cd.d[1].ns) % 251;
}
