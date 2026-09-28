/* a ?: in a static initializer whose condition is known at compile time: a folded integer
 * picking a function's address (the kernel's pm_sleep_ptr), a string literal as the
 * condition (never null -- nf_conntrack_sip's `"f" ? sizeof("f") - 1 : 0`), a static address,
 * and an integer ?: inside arithmetic. held to gcc. */

struct ops { int (*suspend)(int); int (*resume)(int); int (*idle)(int); };
struct hdr { const char *name; unsigned long len; const char *cname; unsigned long clen; };

static int sus(int x) { return x + 1; }
static int res(int x) { return x + 2; }
static int anchor;

#define PTR_IF(c, p) ((c) ? (p) : (void *)0)

static const struct ops pm = { .suspend = PTR_IF(1, sus), .resume = PTR_IF(0, res), .idle = PTR_IF(2 > 1, sus) };
static const struct hdr hs[] = {
  { "From", 4, "f", "f" ? sizeof("f") - 1 : 0 },
  { "CSeq", 4, 0, 0 ? sizeof("x") - 1 : 0 },
};
static int *ap = &anchor ? &anchor : 0;
static long n = 3 + (sizeof(long) == 8 ? 5 : 1) * 2;
static int *zp = 0 ? &anchor : 0;

int main(void) {
  int bad = 0;
  if (pm.suspend != sus || pm.resume || pm.idle != sus || pm.suspend(1) != 2) bad |= 1;
  if (hs[0].clen != 1 || hs[1].clen != 0 || hs[1].cname) bad |= 2;
  if (ap != &anchor || zp) bad |= 4;
  if (n != 3 + (sizeof(long) == 8 ? 5 : 1) * 2) bad |= 8;
  return bad;
}
