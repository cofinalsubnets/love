// i/lib/two.c -- the multi-session probe. two sessions in one process is the
// question every embedder asks first; this is what actually happens.
#include "lv.h"
#include <stdio.h>

static int bad;
static void want(char const *what, long got, long expect) {
  if (got != expect) bad++, printf("  ! %s: %ld, wanted %ld\n", what, got, expect); }

int main(void) {
  struct lv *a = lv_open(NULL), *b = lv_open(NULL);
  if (!a || !b) return fprintf(stderr, "; open failed\n"), 1;
  lv_eval(a, "(: x 111)");
  lv_eval(b, "(: x 222)");
  lv_eval(a, "x");
  printf("a x = %ld\n", (long) lv_toint(a, 0));
  want("a's own x", lv_toint(a, 0), 111);
  lv_eval(b, "x");
  printf("b x = %ld\n", (long) lv_toint(b, 0));
  want("b's own x", lv_toint(b, 0), 222);
  // allocate hard in a, then read b: a collection in one moves only its own pool
  lv_eval(a, "(net (map (+ 1) (jot 200000)))");
  printf("a churn = %ld\n", (long) lv_toint(a, 0));
  want("the churn", lv_toint(a, 0), 20000100000L);
  lv_eval(b, "x");
  printf("b x after a's churn = %ld\n", (long) lv_toint(b, 0));
  want("b survives a's collector", lv_toint(b, 0), 222);
  lv_close(a), lv_close(b);
  printf(bad ? "FAILED (%d)\n" : "ok\n", bad);
  return bad != 0; }
