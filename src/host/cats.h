// cats.h -- the baked source both frontends warm from. src/host/main.c (hosted) and
// src/inle/kmain.c (inle) run the same egg and register the same modules, and the artifact
// carries BOTH of them -- so these are one definition (src/host/cats.c) rather than a static
// apiece, which is the whole prel said twice in every link.
// ⚠ not love0's: it LAYS the header (tools/lcat.l), and its own boot rides out/lib/boot0.h.
#ifndef AI_CATS_H
#define AI_CATS_H

// the native JIT exists on this arch, and ai_tco says this vm can call it: the glaze emits
// the tail-threaded lvm shape (g, Ip, Hp, Sp), so a trampoline build calling into it jumps
// with the wrong ABI. one spelling, since the blob and its callers are separate TUs.
#if (defined(__x86_64__) || defined(__aarch64__)) && ai_tco
#define AiGlazed 1
#endif

// the texts ride DEFLATED, so they are reached through calls rather than named: the
// blobs and the inflate are src/host/cats.c's alone, and a frontend asks for the effect.
// warm the egg from its four texts -- prel carries ev's half spliced after its own.
struct ai *ai_cats_egg(struct ai *g);

// register the arch's holo (scan riding it), so each later `use` is a pure splice; the
// rest of the registry is post's, and rides the egg.
struct ai *ai_cats_mods(struct ai *g);

// the glaze: a no-op on an unglazed build, so every eval site stands unconditional
struct ai *ai_cats_glaze(struct ai *g);


#endif
