/* a later designator overrides an earlier one for the same element (C11 6.7.9p19): over a
 * gcc range, back to back, and in a struct, file scope and automatic alike */
struct pt { int x, y; };
static const int tab[6] = { [0 ... 5] = 1, [3] = 4, [1] = 2, };
static const int twice[3] = { [1] = 5, [1] = 6, };
static const struct pt pp = { .x = 1, .y = 2, .x = 3 };

static int sum(const int *a, int n) { int s = 0; for (int i = 0; i < n; i++) s = s * 10 + a[i]; return s; }

int main(void)
{
  int loc[6] = { [0 ... 5] = 1, [3] = 4, [1] = 2, };
  int ok = (sum(tab, 6) == 121411) + 2 * (sum(twice, 3) == 60) + 4 * (pp.x == 3 && pp.y == 2)
           + 8 * (sum(loc, 6) == 121411);
  return 40 + ok;   /* 55 */
}
