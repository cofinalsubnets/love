// i/lib/demo.c -- a host program that embeds love. it includes lv.h and nothing
// else of the tree: no love.h, no word, no struct ai.
#include "lv.h"
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <stdlib.h>

static void say(void *ud, int fd, char const *s, size_t n) {
  fwrite(s, 1, n, fd == 2 ? stderr : stdout); }

// a host function love can call: (hypot a b) over the C library's own doubles.
static int host_hypot(struct lv *L, void *ud, int n) {
  double a = lv_toflo(L, 0), b = lv_toflo(L, 1);
  return lv_pushflo(L, __builtin_sqrt(a * a + b * b)); }

static double ms(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }

int main(void) {
  char const *img = getenv("LV_IMAGE");
  void *ib = NULL; size_t ilen = 0;
  if (img) {
    FILE *f = fopen(img, "rb");
    if (f) { fseek(f, 0, SEEK_END); ilen = ftell(f); rewind(f);
             ib = malloc(ilen);
             if (fread(ib, 1, ilen, f) != ilen) ib = NULL, ilen = 0;
             fclose(f); } }
  double t0 = ms();
  struct lv_opt o = { say, NULL, 0, ib, ilen };
  struct lv *L = lv_open(&o);
  if (!L) return fprintf(stderr, "; lv_open failed\n"), 1;
  printf("open        %.0f ms  (%s)\n", ms() - t0, ib ? "image wake" : "egg bake");
  if (getenv("LV_SAVE")) {
    size_t n = 0;
    void *b = lv_save(L, &n);
    FILE *f = b ? fopen(getenv("LV_SAVE"), "wb") : NULL;
    if (f) fwrite(b, 1, n, f), fclose(f);
    printf("save        %zu bytes -> %s\n", n, getenv("LV_SAVE"));
    return lv_free(b), 0; }

  // 1. eval, and read the answer back as a C scalar
  lv_eval(L, "+[1 2 3 4]");
  printf("net         %ld  (type %d)\n", (long) lv_toint(L, 0), lv_type_at(L, 0));
  lv_pop(L, 1);

  // 2. a string out
  lv_eval(L, "(\"hello \" + \"world\")");
  { char buf[64];
    lv_strcpy(L, 0, buf, sizeof buf);
    printf("string      %s\n", buf); }
  lv_pop(L, 1);

  // 3. a list out, element by element
  lv_eval(L, "(map (+ 1) [1 2 3])");
  printf("list        #%d = [", lv_count(L, 0));
  for (int i = 0; i < lv_count(L, 0); i++) {
    lv_at(L, 0, i);
    printf("%s%ld", i ? " " : "", (long) lv_toint(L, 0));
    lv_pop(L, 1); }
  printf("]\n");
  lv_pop(L, 1);

  // 4. apply a love closure to C-made arguments -- no source text per call
  lv_eval(L, "(a \\ b \\ a * a + b)");
  lv_pushint(L, 7);
  lv_pushint(L, 5);
  // stack: [5 7 f ..] -- args pushed in order, f beneath them
  if (lv_apply(L, 2)) printf("apply       FAILED: %s", lv_error(L));
  else printf("apply       %ld\n", (long) lv_toint(L, 0));
  lv_pop(L, 1);

  // ..and the cost of one such call
  { lv_eval(L, "(a \\ b \\ a * a + b)");
    enum { n = 20000 };
    double t = ms();
    for (int i = 0; i < n; i++) {
      lv_dup(L, 0);
      lv_pushint(L, 7);
      lv_pushint(L, 5);
      lv_apply(L, 2);
      lv_pop(L, 1); }
    printf("apply cost  %.2f us/call\n", (ms() - t) * 1e3 / n);
    lv_pop(L, 1); }

  // 5. love calling C
  lv_defn(L, "hypot", 2, host_hypot, NULL);
  lv_eval(L, "(hypot 3.0 4.0)");
  printf("callback    %g\n", lv_toflo(L, 0));
  lv_pop(L, 1);

  // 6. a scare is a return code, not a longjmp -- and the session survives it
  if (lv_eval(L, "(scare 'boom 42)")) printf("scare       %s", lv_error(L));
  printf("after scare stack depth %d, ok=%d\n", lv_top(L), lv_ok(L));

  lv_close(L);
  return 0; }
