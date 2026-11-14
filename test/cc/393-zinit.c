/* a large aggregate zeroed by its braces, over a stack dirtied first: the loop's turns, the
 * words past the last four and the bytes past the last word, under a fill that lands on
 * each, a zero it gives, and a zero laid over a value it gave. 0 is agreement */
void *memset(void *, int, unsigned long);

struct Big { char b[1001]; int x; short t[37]; };

__attribute__((noinline)) static void dirty(void) {
  volatile unsigned char junk[4096];
  memset((void *) junk, 0xa5, sizeof junk);
  junk[0] = junk[4095]; }

__attribute__((noinline)) static int sum(unsigned char const *p, unsigned long n) {
  int s = 0;
  for (unsigned long i = 0; i < n; i++) s += p[i];
  return s; }

__attribute__((noinline)) static int big(void) {
  struct Big v = { .x = 3, .t = { [36] = 7 } };
  int bad = sum((unsigned char const *) v.b, sizeof v.b) != 0;
  for (int i = 0; i < 36; i++) bad |= v.t[i] != 0;
  return bad | (v.x != 3) << 1 | (v.t[36] != 7) << 2; }

__attribute__((noinline)) static int arr(void) {
  char a[523] = { 1 };
  return (a[0] != 1) | (sum((unsigned char const *) a + 1, 522) != 0) << 1; }

__attribute__((noinline)) static int words(void) {
  long w[19] = { [18] = 5 };
  int bad = w[18] != 5;
  for (int i = 0; i < 18; i++) bad |= w[i] != 0;
  return bad; }

__attribute__((noinline)) static int zeros(void) {
  int q[40] = { 0, 1, 0, 2, [7] = 9, [7] = 0, [9] = 0, [9] = 4 };
  int bad = q[1] != 1 || q[3] != 2 || q[7] != 0 || q[9] != 4;
  for (int i = 0; i < 40; i++) bad |= (i != 1 && i != 3 && i != 9) && q[i] != 0;
  return bad; }

int main(void) {
  dirty(); int r = big();
  dirty(); r |= arr() << 3;
  dirty(); r |= words() << 5;
  dirty(); r |= zeros() << 6;
  return r; }
