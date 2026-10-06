/* an object's or a function's address is never null, so a static initializer's test of one
 * against a null constant, or its negation, is decided at image time (gcc's and clang's
 * reading): linux's OF_DECLARE lays `.data = (fn == (fn_type)NULL) ? fn : fn` into a named
 * section, walked by __start_/__stop_ as the kernel walks its of_device_id tables. every entry
 * must land there with its own value, aligned as the kernel aligns them so the section reads as
 * an array. freestanding, exit-code only. */

struct ofid { char compatible[16]; const void *data; };
typedef void (*initfn)(void *);

static void init_a(void *np) { (void)np; }
static void init_b(void *np) { (void)np; }
static int obj;

static const struct ofid of_a __attribute__((__used__)) __attribute__((__section__("ofl_table"))) __attribute__((__aligned__(__alignof__(struct ofid))))
	= { "a,one", (init_a == (initfn)((void *)0)) ? init_a : init_a };
static const struct ofid of_b __attribute__((__used__)) __attribute__((__section__("ofl_table"))) __attribute__((__aligned__(__alignof__(struct ofid))))
	= { "b,two", (init_b != (initfn)0) ? init_b : 0 };
static const struct ofid of_c __attribute__((__used__)) __attribute__((__section__("ofl_table"))) __attribute__((__aligned__(__alignof__(struct ofid))))
	= { "c,three", !(&obj) ? (const void *)1 : (const void *)&obj };
static const struct ofid of_d __attribute__((__used__)) __attribute__((__section__("ofl_table"))) __attribute__((__aligned__(__alignof__(struct ofid))))
	= { "d,four", (0 == &obj) ? (const void *)2 : (const void *)3 };

extern const struct ofid __start_ofl_table[], __stop_ofl_table[];

int main(void)
{
	const struct ofid *p;
	int bad = 0, n = 0, seen = 0;
	for (p = __start_ofl_table; p < __stop_ofl_table; p++, n++) {
		if (p->compatible[0] == 'a') { seen |= 1; if (p->data != (const void *)init_a) bad |= 2; }
		if (p->compatible[0] == 'b') { seen |= 2; if (p->data != (const void *)init_b) bad |= 4; }
		if (p->compatible[0] == 'c') { seen |= 4; if (p->data != (const void *)&obj) bad |= 8; }
		if (p->compatible[0] == 'd') { seen |= 8; if (p->data != (const void *)3) bad |= 16; }
	}
	if (n != 4 || seen != 15) bad |= 1;
	return bad;
}
