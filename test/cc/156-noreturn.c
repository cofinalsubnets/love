/* a fn no path leaves owes no callee-saved file back: its epilogue is unreachable,
 * so the restores go and the saves with them. spin below holds values across calls
 * the compiler cannot see through -- the volatile pointers are what earn the seats
 * that make the shape bite -- and it is emitted on every target and never entered. */
unsigned long acc;

unsigned long step(unsigned long x) { acc += x + 1; return acc ^ (x << 3); }
void sink(unsigned long x) { acc ^= x; }

unsigned long (* volatile pstep)(unsigned long) = step;
void (* volatile psink)(unsigned long) = sink;

void spin(unsigned long a) {
  unsigned long g = pstep(a);
  unsigned long h = pstep(g);
  psink(g); psink(h);
  h = pstep(g + h);
  psink(g); psink(h); psink(g); psink(h);
  h = pstep(g ^ h);
  psink(g); psink(h); psink(g); psink(h); psink(g); psink(h);
  for (;;) acc = g + h; }               /* the tail no return leaves */

int main(void) {
  unsigned long r = pstep(3);
  r += pstep(r);
  psink(r);
  acc |= 1;
  if (!acc) spin(r);                    /* never taken; spin is emitted regardless */
  return (int) ((acc + r) & 0x7f); }
