// FIXME this file is too short
// cats.h -- the baked source main.c and kmain.c both warm from: one definition (cats.c), not a
// static apiece. not love0's, which lays the header (lcat.l) and boots off out/lib/boot0.h
#ifndef CATS_H
#define CATS_H

// the glaze exists here and this vm can call it: it emits the tail-threaded lvm ABI, which a
// trampoline build lacks. spelled once, for the blob and its callers in separate TUs
#if (defined(__x86_64__) || defined(__aarch64__)) && tco
#define LvGlazed 1
#endif

struct g
 *cats_egg(struct g *g),
 *cats_lib(struct g *g),
 *cats_glaze(struct g *g);

#endif
