/* forms the kernel's x86-64 units read with: a cleanup on one declarator of several, a
 * _Pragma a macro spells, __builtin_strcmp over two literals (the dead arm's call never
 * links) and over a runtime string, an enum named ahead of its definition, a block static
 * named into a section of its own. held to gcc. */
#include <stdio.h>

static int freed;
static void undo(char **p) { freed += *p ? (*p)[0] : 100; }
static int many(int k) {
  {
    char *a __attribute__((cleanup(undo))) = "a", *b = "x", *c __attribute__((cleanup(undo))) = k ? "c" : 0;
    if (k) return b[0];
  }
  return 0;
}

#define str1(s) #s
#define str(s) str1(s)
#define diag(s) _Pragma(str(GCC diagnostic s))
#define diag_push() diag(push)
#define diag_ignore(o) diag(ignored o)
diag_push();
diag_ignore("-Wformat");
static int quiet(void) { return 7; }

extern void never_linked(void);
#define cmp(a, op, b) ({ int r_ = 0; \
  if (!__builtin_strcmp(op, "<")) r_ = (a) < (b); \
  else if (!__builtin_strcmp(op, ">=")) r_ = (a) >= (b); \
  else never_linked(); r_; })

extern enum mode later;
enum mode { M0, M1, M2 };
enum mode later = M2;

#if defined(__ELF__)
struct rec { int v; struct rec *n; };
static struct rec *head;
extern struct rec __start_kfrec[], __stop_kfrec[];
static void push(int v) {
  static struct rec r __attribute__((section("kfrec"), used));
  r.v = v; r.n = head; head = &r;
}
static int recs(void) { push(5); return (int)(__stop_kfrec - __start_kfrec) + head->v; }
#else
static int recs(void) { return 6; }
#endif

int main(void) {
  char buf[] = "abd";
  int r = many(1), f1 = freed, f0;
  freed = 0; many(0); f0 = freed;
  int c1 = cmp(3, "<", 4), c2 = cmp(3, ">=", 4);
  int s1 = __builtin_strcmp("abc", "abd") < 0, s2 = __builtin_strcmp(str(xyz), "xyz"), s3 = __builtin_strcmp(buf, "abc") > 0;
  printf("%d %d %d\n", r, f1, f0);
  printf("%d %d %d\n", quiet(), c1, c2);
  printf("%d %d %d\n", s1, s2, s3);
  printf("%d %d %d\n", (int)later, (int)sizeof later, recs());
  return (r + f1 + f0 + quiet() + c1 + c2 + s1 + s2 + s3 + later + recs()) & 255;
}
