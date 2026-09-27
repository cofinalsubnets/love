/* __builtin_offsetof over a runtime index, held to gcc: `n[i]` is the member's offset plus
 * i elements, an expression and not a constant, nested members and a second index ride
 * it, and linux's container_of over `node[idx]` finds its struct again. a constant index
 * still folds where a constant is owed. */

struct In { char c; int b; short z[3]; };
struct S { int a; int n[4]; struct In in[5]; };

enum { K = __builtin_offsetof(struct S, n[2]) };
static int fixed[__builtin_offsetof(struct S, in[1].b)];

#define container_of(p, T, m) ((T *)((char *)(p) - __builtin_offsetof(T, m)))

static struct S *owner(struct In *p, int idx) { return container_of(p, struct S, in[idx]); }

int main(void) {
  int bad = 0;
  struct S s;
  int i = 2, j = 1;
  long k = 3;

  if (__builtin_offsetof(struct S, n[i]) != __builtin_offsetof(struct S, n[2])) bad |= 1;
  if (__builtin_offsetof(struct S, n[k]) != (char *)&s.n[3] - (char *)&s) bad |= 2;
  if (__builtin_offsetof(struct S, in[i].b) != (char *)&s.in[2].b - (char *)&s) bad |= 4;
  if (__builtin_offsetof(struct S, in[i].z[j]) != (char *)&s.in[2].z[1] - (char *)&s) bad |= 8;
  if (K != (char *)&s.n[2] - (char *)&s) bad |= 16;
  if (sizeof fixed != __builtin_offsetof(struct S, in[1].b) * sizeof(int)) bad |= 32;
  if (owner(&s.in[4], 4) != &s || owner(&s.in[0], 0) != &s) bad |= 64;
  if (sizeof(__builtin_offsetof(struct S, n[i])) != sizeof(unsigned long)) bad |= 128;

  return bad;
}
