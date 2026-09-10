// i/main0.c -- love0's seat, the third of the three: main.c is hosted love's,
// kmain.c is inle's, this is the ambient-cc bootstrap's. it lays the blob the
// shipped love carries, so it carries none itself, and its whole job is the corpus --
// a build tool from the command line, the self-test with no arguments.
//
// its own translation unit because that IS the seat boundary. common.mk keeps this
// file out of host_c and the Makefile names it into love0_o, the way i/cats.c is
// named out of love0's list: main.c holds what both seats do, and the two things only
// love0 does -- the pasted boot texts and the twice-run corpus -- live here.
#include "love.h"
#include <stdlib.h>
#include <string.h>

// the null seat is i/nokern.c's and the carried blobs i/noblob.c's -- love0 has no
// kmain.c under it and lays the archives rather than carrying them, and so does every
// gate link that builds this C set. both are named into love0_o beside this file.
// love0 has no moonlibc either, so i/noosv.c gives it __ai_osv.

#include "boot0.h"                                   // src0_<name>[]: one literal per boot file, laid by sed
static char const runner[] = "(reads(tap(s2cl tests)))";   // the stream shell (l/boot/post.l) drinks the corpus
// the groups love0 evaluates as ONE text apiece: a text is read whole before its first
// form runs, so joining at boot keeps that seam where the pasted headers had it.
static char const *const mods0[] = { src0_holo, src0_x64, src0_a64, NULL };
static char const *const prelpost0[] = { src0_prel, src0_post, NULL };
static char const *const prelev0[] = { src0_prel, src0_ev, NULL };
// one NUL-terminated buffer off the heap, so a collect mid-eval cannot move it; the caller frees
static char *join0(struct ai *g, char const *const *v) {
  uintptr_t n = 0;
  for (int i = 0; v[i]; i++) n += strlen(v[i]);
  char *t = g->alloc(g, NULL, n + 1), *p = t;
  if (!t) return NULL;
  for (int i = 0; v[i]; i++) { uintptr_t l = strlen(v[i]); memcpy(p, v[i], l); p += l; }
  return *p = 0, t; }
static struct ai *evals0(struct ai *g, char const *const *v) {
  char *t = join0(g, v);
  if (!t) return g;
  g = ai_evals_(g, t);
  return g->alloc(g, t, 0), g; }

// with args, run the build tool (lcat / gen_data) through the CLI driver.
// with no args, self-test: eval prel, load bao (the shell core) as a module, and run
// the baked corpus via c0, then bootstrap the self-hosted ev (egg) and run the corpus
// again through it. bake/bake_load are the full love's words: they stand in the
// signature so main() has one call for both seats, and love0 has no bake verb.
struct ai *boot(struct ai *g, bool argp, char const *bake, char const *bake_load) {
  (void) bake, (void) bake_load;
  if (argp) {
    g = ai_evals_(g, src0_p1);
    g = evals0(g, prelpost0);
    g = evals0(g, mods0);
    g = ai_evals_(g, "(borrow 'cli)(borrow 'kanren)(borrow 'verbs)");
    g = ai_shelve_(g);
    return ai_evals(g, "(cli-line cmdline 0)"); }
  g = ai_evals_(g, src0_p1);                         // its own call: readtext picks its reader once per
  g = evals0(g, prelpost0);                          // text, and p1 seals hook 0 only when this call evaluates
  g = evals0(g, mods0);
  g = ai_evals_(g, "(borrow 'cli)(borrow 'holo)");
  g = ai_shelve_(g);
  g = ai_evals_(g,
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
    "   fs (c0split (c0read \"b/lib/corpus.list\"))"
    "   _ (? (two? fs) 0 (: _ (say err \"love0: corpus: b/lib/corpus.list names nothing\")"
    "                       _ (put err 10) (quit 1)))"
    "   tests (foldl (\\ a f (a + c0read f)) \"\" fs))");
  g = ai_evals_(g, runner);          // pass 1: corpus via ev = the c0 nif
  char *corpus = join0(g, prelev0);                   // bootstrap: install the self-hosted ev
  if (corpus) g = ai_egg_(g, src0_egg, src0_p1, corpus, src0_post), g->alloc(g, corpus, 0);
  return ai_evals_(g, runner); }                      // pass 2: corpus via the self-hosted ev
