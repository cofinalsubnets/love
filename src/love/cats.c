// cats.c -- the baked source, deflated by src/tools/lcat.l into one header: the egg's texts,
// the module registry, the glaze. only a love with no image to wake reads it
#include "love.h"
#include "cats.h"
// every build takes the whole registry: `cite` of an unregistered module answers (), silently
#include "baked.h"

// a blob to a NUL-terminated buffer off the heap, so a collect can't move it; NULL on refusal
static char *cat_open(struct g *g, unsigned char const *z, uintptr_t zn, uintptr_t raw) {
  char *t = alloc(NULL, raw + 1);
  if (!t) return NULL;
  if (inflate_raw(z, zn, (unsigned char*) t, raw) != (intptr_t) raw)
    return alloc(t, 0), NULL;
  return t[raw] = 0, t; }
#define CatOpen(g, nm) cat_open((g), nm, sizeof nm - 1, nm##_raw)

static struct g *cat_eval(struct g *g, unsigned char const *z, uintptr_t zn, uintptr_t raw) {
  char *t = cat_open(g, z, zn, raw);
  if (!t) return g;
  g = evals_(g, t);
  return alloc(t, 0), g; }
#define CatEval(g, nm) cat_eval((g), nm, sizeof nm - 1, nm##_raw)

// the egg wants its three texts at once
struct g *cats_egg(struct g *g) {
  char *e = CatOpen(g, cat_egg_z), *r = CatOpen(g, cat_prel_z), *o = CatOpen(g, cat_post_z);
  if (e && r && o) g = egg(g, e, r, o);             // prel carries ev's half spliced after its own
  alloc(e, 0), alloc(r, 0), alloc(o, 0);
  return g; }

// the arch's holo, scan riding it; every other module registers as post is sat
struct g *cats_lib(struct g *g) {
#ifdef LvCatModsH
  g = CatEval(g, cat_lib_h_z);
#endif
  return g; }

#ifdef LvGlazed
// 138 KB of text that only a `love bake` reads, for 41 KB of .rodata
struct g *cats_glaze(struct g *g) { return CatEval(g, src_glaze_z); }
#else
struct g *cats_glaze(struct g *g) { return g; }
#endif

