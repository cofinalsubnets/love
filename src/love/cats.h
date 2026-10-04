// FIXME this file is too short
// cats.h -- the baked source both frontends warm from. src/love/main.c (hosted) and
// src/inle/kmain.c (inle) run the same egg and register the same modules, and the artifact
// carries BOTH of them -- so these are one definition (src/love/cats.c) rather than a static
// apiece, which is the whole prel said twice in every link.
// not love0's: it LAYS the header (src/tools/lcat.l), and its own boot rides out/lib/boot0.h.
#ifndef CATS_H
#define CATS_H

// the native JIT exists on this arch, and tco says this vm can call it: the glaze emits
// the tail-threaded lvm shape (g, Ip, Hp, Sp), so a trampoline build calling into it jumps
// with the wrong ABI. one spelling, since the blob and its callers are separate TUs.
#if (defined(__x86_64__) || defined(__aarch64__)) && tco
#define LvGlazed 1
#endif

struct g
 *cats_egg(struct g *g),
 *cats_lib(struct g *g),
 *cats_glaze(struct g *g);

#endif
