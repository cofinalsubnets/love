// FIXME this file is too short
// cats.h -- the baked source both frontends warm from. i/main.c (hosted) and
// i/kmain.c (inle) run the same egg and register the same modules, and the artifact
// carries BOTH of them -- so these are one definition (i/cats.c) rather than a static
// apiece, which is the whole prel said twice in every link.
// not love0's: it LAYS the header (tools/lcat.l), and its own boot rides out/lib/boot0.h.
#ifndef AI_CATS_H
#define AI_CATS_H

// the native JIT exists on this arch, and ai_tco says this vm can call it: the glaze emits
// the tail-threaded lvm shape (g, Ip, Hp, Sp), so a trampoline build calling into it jumps
// with the wrong ABI. one spelling, since the blob and its callers are separate TUs.
#if (defined(__x86_64__) || defined(__aarch64__)) && ai_tco
#define LvGlazed 1
#endif

struct ai
 *ai_cats_egg(struct ai *g),
 *ai_cats_lib(struct ai *g),
 *ai_cats_glaze(struct ai *g);

#endif
