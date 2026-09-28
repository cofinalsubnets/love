/* `return f();` in a void function, f void: the return still returns. the inliner splices a
 * small f into the caller's return, and an f that runs off its end left the caller running
 * on -- only below an if nested in another if's block, where no else carried the rest. and a
 * void f spliced whole, whose own `return g();` must still call g. held to gcc. */

static int n;
void say(int k) { n = n * 10 + k; }

void nested(int a, int b) {
  if (a) {
    if (b) return say(1); }
  say(2); }

void braced(int a, int b) {
  if (a) {
    if (b) { return say(1); } }
  say(2); }

void twice(int a, int b) {
  if (a) {
    if (b) return say(1);
    if (!b) return say(3); }
  say(2); }

static void inner(int b) {
  if (b) return say(4);
  say(5); }
static void outer(int b) { inner(b); say(6); }

/* a label sends the splice down the jump lane: each return a jump to its end */
static void jumpy(int b) {
  if (b > 1) goto out;
  if (b) return say(7);
out:
  say(8); }
static void jumper(int b) { jumpy(b); say(9); }

void (*volatile via)(int, int) = nested;

/* the first check that misses, by number: an exit code carries eight bits */
#define CK(k, e) do { n = 0; e; if (n != want[k]) return k; } while (0)
static int const want[] = { 0, 1, 2, 2, 1, 1, 3, 1, 46, 56, 79, 89 };

int main(void) {
  CK(1, nested(1, 1));
  CK(2, nested(1, 0));
  CK(3, nested(0, 1));
  CK(4, braced(1, 1));
  CK(5, twice(1, 1));
  CK(6, twice(1, 0));
  CK(7, via(1, 1));
  CK(8, outer(1));
  CK(9, outer(0));
  CK(10, jumper(1));
  CK(11, jumper(2));
  return 0;
}
