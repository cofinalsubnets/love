// i/lib/two.c -- the multi-session probe. two sessions in one process is the
// question every embedder asks first; this is what actually happens.
#include "lv.h"
#include <stdio.h>

int main(void) {
  struct lv *a = lv_open(NULL), *b = lv_open(NULL);
  if (!a || !b) return fprintf(stderr, "; open failed\n"), 1;
  lv_eval(a, "(: x 111)");
  lv_eval(b, "(: x 222)");
  lv_eval(a, "x");
  printf("a x = %ld\n", (long) lv_toint(a, 0));
  lv_eval(b, "x");
  printf("b x = %ld\n", (long) lv_toint(b, 0));
  // allocate hard in a, then read b: a collection in one moves only its own pool
  lv_eval(a, "(net (map (+ 1) (jot 200000)))");
  printf("a churn = %ld\n", (long) lv_toint(a, 0));
  lv_eval(b, "x");
  printf("b x after a's churn = %ld\n", (long) lv_toint(b, 0));
  lv_close(a), lv_close(b);
  return 0; }
