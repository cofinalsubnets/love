/* a test pushed down through a `!` into a callee of many returns: each constant return takes
 * the caller's arm, and a missing else stays missing (arm64 do_page_fault's
 * `if (fault_from_pkey(..)) {}` over arch_vma_access_permitted). */
static int seen;
__attribute__((noinline)) int h(int x) { seen++; return x & 1; }
static int g(int x) { if (x > 5) return 1; if (x < -5) return 1; return h(x); }
static int f(int x) { if (!x) return 0; return !g(x); }
static int k(int x) { if (x == 3) return 0; return !f(x); }

__attribute__((noinline)) int t0(int x) { if (f(x)) {} return seen; }
__attribute__((noinline)) int t1(int x) { if (f(x)) return 1; return 2; }
__attribute__((noinline)) int t2(int x) { int r = 0; if (f(x)) r = 3; else r = 4; return r; }
__attribute__((noinline)) int t3(int x) { if (!f(x)) {} else seen += 10; return seen; }
__attribute__((noinline)) int t4(int x) { if (k(x)) return 5; return 6; }

int main(void)
{
    int s = 0, xs[] = {0, 7, -7, 2, 3};
    for (int i = 0; i < 5; i++)
        s = s * 3 + t1(xs[i]) + t2(xs[i]) + t4(xs[i]);
    s += t0(2) + t3(2) + t3(7);
    return s % 251;   /* gcc: 114 */
}
