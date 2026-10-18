// src/love/user/main0.c -- love0's boot, the ambient-cc bootstrap: a build tool with args, the
// corpus self-test without. common.mk keeps it out of host_c; the Makefile names it into love0_o
#include "love.h"
#include <stdlib.h>
#include <string.h>

// nokern.c and noblob.c link beside this; no moonlibc, so __love_osv is love.c's weak 0

#include "boot0.h"                                   // src0_<name>[]: one literal per boot file, laid by sed
static char const runner[] = "(reads(tap(s2cl tests)))";   // the stream shell (src/love/boot/post.l) drinks the corpus
// each group evaluates as one text: a text is read whole before its first form runs
static char const *const mods0[] = { src0_holo, src0_x64, src0_a64, NULL };
static char const *const prelpost0[] = { src0_prel, src0_post, NULL };
static char const *const prelev0[] = { src0_prel, src0_ev, NULL };
// one NUL-terminated buffer off the heap, so a collect mid-eval cannot move it; the caller frees
static char *join0(struct g *g, char const *const *v) {
  uintptr_t n = 0;
  for (int i = 0; v[i]; i++) n += strlen(v[i]);
  char *t = alloc(NULL, n + 1), *p = t;
  if (!t) return NULL;
  for (int i = 0; v[i]; i++) { uintptr_t l = strlen(v[i]); memcpy(p, v[i], l); p += l; }
  return *p = 0, t; }
static struct g *evals0(struct g *g, char const *const *v) {
  char *t = join0(g, v);
  if (!t) return g;
  g = evals_(g, t);
  return alloc(t, 0), g; }

// with args, the build tool through the cli driver; without, the corpus via c0, then again
// via the self-hosted ev. the bake words are unused: main() has one call for both builds
struct g *boot(struct g *g, bool argp, char const *bake, char const *bake_load,
                char const *bake_out) {
  (void) bake, (void) bake_load, (void) bake_out;
  if (argp) {
    g = evals0(g, prelpost0);
    g = evals0(g, mods0);
    g = evals_(g, "(borrow 'cli)(borrow 'kanren)(borrow 'verbs)");
    g = shelve(g);
    return evals(g, "(cli-line cmdline 0)"); }
  g = evals0(g, prelpost0);
  g = evals0(g, mods0);
  g = evals_(g, "(borrow 'cli)(borrow 'holo)");
  g = shelve(g);
  g = evals_(g,
    "(borrow 'uu)(: uu (cite 'uu))(borrow 'kanren)(borrow 'posix)"
    "(: (s2cl s) ((: (g i) (? (< i (tally s)) (. (peep s i 0) (g (+ 1 i))))) 0)"
    "   (c0read p) (: q (open p \"r\")"
    "               (? q (: s (slurp q) _ (close q) s)"
    "                  (: _ (say err (\"love0: corpus: cannot open \" + p)) _ (put err 10) (quit 1))))"
    "   (c0split s) (: n (tally s)"
    "                  (go i j acc) (? (n <= i) (rev (? (< j i) (. (snip s j i) acc) acc))"
    "                                 (: c (peep s i 0)"
    "                                    (? (|| (= c 32) (= c 10))"
    "                                       (go (+ i 1) (+ i 1) (? (< j i) (. (snip s j i) acc) acc))"
    "                                       (go (+ i 1) j acc))))"
    "                  (go 0 0 ()))"
    "   fs (c0split (c0read \"out/lib/corpus.list\"))"
    "   _ (? (two? fs) 0 (: _ (say err \"love0: corpus: out/lib/corpus.list names nothing\")"
    "                       _ (put err 10) (quit 1)))"
    "   tests (foldl (\\ a f (a + c0read f)) \"\" fs))");
  g = evals_(g, runner);          // pass 1: corpus via ev = the c0 nif
  char *corpus = join0(g, prelev0);                   // bootstrap: install the self-hosted ev
  if (corpus) g = egg(g, src0_egg, corpus, src0_post), alloc(corpus, 0);
  return evals_(g, runner); }                      // pass 2: corpus via the self-hosted ev
