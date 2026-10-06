/* the layout and call extensions a kernel header leans on: #pragma pack's whole stack (acpi's
 * tables), a transparent union parameter taking any member's type (mm.h's release_pages),
 * and a __COUNTER__ inside an argument naming one variable however often it is used
 * (__UNIQUE_ID). exit-code only: the answers are compared, never hard-coded widths. */
#include <stddef.h>

#pragma pack(push, 1)
struct a { char c; int i; short s; };
#pragma pack(push, 4)
struct b { char c; long l; short s; };
#pragma pack(pop)
struct c { char c; long l; };
#pragma pack(pop)
struct d { char c; long l; };
#pragma pack(2)
struct e { char c; int i; };
#pragma pack()
struct f { char c; int i; };

struct page { int a; };
struct folio { int b; };
typedef union {
	struct page **pages;
	struct folio **folios;
} pages_arg __attribute__((__transparent_union__));
static int release(pages_arg p, int n) { return (*p.pages)->a + n; }

#define CAT(a, b) a ## b
#define XCAT(a, b) CAT(a, b)
#define UNIQUE(p) XCAT(p, __COUNTER__)
#define ONCE(x, u) ({ int u = (x); u + u; })
#define TWICE(x) ONCE(x, UNIQUE(t_))

int main(void)
{
	struct page pg = { 40 };
	struct page *pp = &pg;
	struct folio *fo = (struct folio *)&pg;
	int r = 0;
	r += sizeof(struct a) + sizeof(struct b) * 3 + offsetof(struct b, l) * 5 + sizeof(struct c) * 7;
	r += sizeof(struct d) * 11 + sizeof(struct e) * 13 + offsetof(struct e, i) * 17 + sizeof(struct f) * 19;
	if (release(&pp, 1) != 41 || release(&fo, 2) != 42) return 1;
	if (TWICE(3) != 6 || TWICE(TWICE(2)) != 8) return 2;
	return r & 127;
}
