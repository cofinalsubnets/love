// cats.c -- the baked source, one copy for the whole link: the egg's four texts, the
// module registry, the glaze and the CLI driver, laid by tools/lcat.l into one header, the
// texts DEFLATED. src/host/main.c and src/inle/kmain.c both warm from these through the
// calls below; see src/host/cats.h.
// only a love with no image to wake reads any of it, so the inflate lands on the lane
// that was already warming an egg -- never on a shipped boot.
#include "love.h"
#include "cats.h"
// ONE registry, every frontend and every face: the roster and its order are the
// header's, and every build takes the whole set -- `from` on an unregistered module
// answers () rather than scaring, so a short registry is a silent wrong binding.
#include "baked.h"

// a blob to a NUL-terminated buffer off the heap, so a collect mid-eval cannot move it.
// NULL on refusal, which leaves the caller's g untouched and the boot to fail where it
// would have failed anyway -- a short registry is the thing to avoid, not to paper over.
static char *cat_open(struct ai *g, unsigned char const *z, uintptr_t zn, uintptr_t raw) {
  char *t = g->alloc(g, NULL, raw + 1);
  if (!t) return NULL;
  if (ai_inflate_raw(z, zn, (unsigned char*) t, raw) != (intptr_t) raw)
    return g->alloc(g, t, 0), NULL;
  return t[raw] = 0, t; }
#define CatOpen(g, nm) cat_open((g), nm, sizeof nm - 1, nm##_raw)

static struct ai *cat_eval(struct ai *g, unsigned char const *z, uintptr_t zn, uintptr_t raw) {
  char *t = cat_open(g, z, zn, raw);
  if (!t) return g;
  g = ai_evals_(g, t);
  return g->alloc(g, t, 0), g; }
#define CatEval(g, nm) cat_eval((g), nm, sizeof nm - 1, nm##_raw)

// the egg wants its four texts at once, so all four are open across the one call.
struct ai *ai_cats_egg(struct ai *g) {
  char *e = CatOpen(g, ai_cat_egg_z), *p = CatOpen(g, ai_cat_p1_z),
       *r = CatOpen(g, ai_cat_prel_z), *o = CatOpen(g, ai_cat_post_z);
  if (e && p && r && o) g = ai_egg_(g, e, p, r, o);     // prel carries ev's half spliced after its own
  g->alloc(g, e, 0), g->alloc(g, p, 0), g->alloc(g, r, 0), g->alloc(g, o, 0);
  return g; }

// the arch's holo, scan riding it; every other module registers as post is sat
struct ai *ai_cats_mods(struct ai *g) {
#ifdef AiCatModsH
  g = CatEval(g, ai_cat_mods_h_z);
#endif
  return g; }

#ifdef AiGlazed
// 138 KB of text that only a `love bake` reads, for 41 KB of .rodata
struct ai *ai_cats_glaze(struct ai *g) { return CatEval(g, src_glaze_z); }
#else
struct ai *ai_cats_glaze(struct ai *g) { return g; }
#endif

