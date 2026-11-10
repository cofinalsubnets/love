/* __alignof__ and _Alignof of a type name or an object answer what the layout does: a typedef's
   aligned(N), raised or lowered, the run's, an object's own, a member's. no libc */
typedef int ai __attribute__((aligned(16)));
typedef ai ai2;
typedef int lo __attribute__((aligned(1)));
typedef struct { char c; } as __attribute__((aligned(32)));
typedef char c32[32] __attribute__((aligned(32)));
typedef struct { char c[32]; } big __attribute__((aligned(32)));
typedef big aa[3];
typedef int *ip __attribute__((aligned(16)));
struct st { char c; ai m; int n __attribute__((aligned(8))); as k; char e; };
struct pk { char c; int i; ai a; } __attribute__((packed));
struct an { char c; struct { ai x; }; union { int y __attribute__((aligned(8))); }; };
ai gv;
int gw __attribute__((aligned(64)));
big ga[2];

_Static_assert(_Alignof(ai) == 16 && _Alignof(as) == 32 && _Alignof(ai2) == 16, "typedef");
_Static_assert(__alignof__(aa) == 32 && __alignof__(big[2]) == 32 && __alignof__(c32) == 32, "array");
_Static_assert(__alignof__(ai *) == __alignof__(void *) && __alignof__(ip) == 16, "pointer");
_Static_assert(__alignof__(lo) == 1 && __alignof__(const ai) == 16, "lowered, qualified");
_Static_assert(sizeof(ai) == 4 && sizeof(as) == 1 && sizeof(struct st) == 64, "sizes stand");

_Alignas(ai) char ca;
_Static_assert(__alignof__(ca) == 16, "_Alignas of the typedef");

int main(void)
{
	ai lv;
	int lw __attribute__((aligned(32)));
	ai *p = &lv;
	struct st s;
	struct pk k;
	struct an n;
	_Alignas(16) char cl;
	if (__alignof__(gv) != 16 || __alignof__(gw) != 64 || __alignof__(ga) != 32) return 1;
	if (__alignof__(lv) != 16 || __alignof__(lw) != 32 || __alignof__(cl) != 16) return 2;
	if (__alignof__(p) != __alignof__(void *)) return 3;
	if (__alignof__(s.m) != 16 || __alignof__(s.n) != 8 || __alignof__(s.k) != 32 || __alignof__(s.c) != 1) return 4;
	if (__alignof__(k.i) != 1 || __alignof__(k.a) != 1) return 5;
	if (__alignof__(n.x) != 16 || __alignof__(n.y) != 8) return 6;
	{
		char lw;
		if (__alignof__(lw) != 1) return 7;
	}
	if ((unsigned long)&lv % 16 || (unsigned long)&lw % 32 || (unsigned long)&s.k % 32) return 8;
	if ((unsigned long)&gv % 16 || (unsigned long)&gw % 64 || (unsigned long)&ga[1] % 32) return 9;
	return 0;
}
