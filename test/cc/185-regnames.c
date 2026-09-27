/* statics spelled like the ir's registers and opcodes. the dead-static sweep reads a laid
 * body's names, where r8 is also a register and add an opcode: each of these is live only
 * through a call, a pointer or a tail jump, and each must survive the sweep. */

static int r8(int x) { return x * 3 + 1; }
static int r1(int x) { return x - 1; }
static int f0(int x) { return x << 2; }
static int add(int a, int b) { return a + b; }
static int mov(int x) { return x ^ 5; }
static int sp(int x) { return x + 100; }
static int (*volatile fp)(int) = r8;                /* named only by an initializer */
static int tail(int x) { return mov(x); }           /* a sibcall to an opcode's name */
static int (*pick(int k))(int) { return k ? sp : f0; }

int main(void) {
  int bad = 0;
  int (*g)(int) = r1;
  if (r8(4) != 13) bad |= 1;
  if (fp(5) != 16) bad |= 2;
  if (g(10) != 9) bad |= 4;
  if (add(3, 4) != 7) bad |= 8;
  if (tail(3) != 6) bad |= 16;
  if (pick(1)(1) != 101 || pick(0)(3) != 12) bad |= 32;
  return bad;
}
