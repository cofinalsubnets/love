/* gcc's named variadic parameter (`fmt...`, kconfig's printd and the kernel's pr_*), with
 * ## elision and # over the tail; and range designators past the old 1024 cap, imaged at
 * file scope and filled in a frame (bytes: the thumb boards have 16 KiB of ram). */

#define pick(mask, fmt...) ((mask) ? sum(fmt) : -1)
#define tail(first, rest...) first + count(0, ##rest)
#define say(args...) #args
#define self(x...) x

static int sum(int a, int b, int c) { return a + b + c; }
static int count(int n, ...) { return n; }

struct head { unsigned char first; };
static struct head table[1U << 12] = { [0 ... ((1U << 12) - 1)] = { .first = 0 } };
static unsigned char marks[2048] = { [0 ... 2046] = 7, [2047] = 9 };

int main(void) {
  int bad = 0;
  if (pick(1, 1, 2, 3) != 6 || pick(0, 1, 2, 3) != -1) bad |= 1;
  if (tail(5) != 5 || tail(5, 1) != 5) bad |= 2;
  if (say(abc)[2] != 'c' || sizeof say(abc) != 4 || sizeof say() != 1) bad |= 4;
  if (self(1, 2) != 2) bad |= 8;

  if (sizeof table != (1U << 12) || table[(1U << 12) - 1].first) bad |= 16;
  if (marks[0] != 7 || marks[2046] != 7 || marks[2047] != 9) bad |= 32;

  unsigned char local[1100] = { [0 ... 1098] = 3 };
  if (local[0] != 3 || local[1098] != 3 || local[1099] != 0) bad |= 64;
  return bad;
}
