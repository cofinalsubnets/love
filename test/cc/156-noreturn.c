/* a fn no path leaves restores no callee-saved registers. spin holds values across
 * opaque calls (the volatile pointers earn the registers), and is never entered. */
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
