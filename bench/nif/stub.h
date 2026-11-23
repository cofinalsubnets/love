/* bench/nif/stub.h -- the runtime the host nifs name, and nothing else.
 *
 * a nif file is an ALGORITHM plus a love-facing wrapper. the algorithm is what
 * this corpus differentials, and it is reachable by including the .c: every
 * entry point is a static, so a harness that includes the file sees all of them
 * and needs no seam cut into src/inle/.
 *
 * what the wrapper needs is a handful of runtime symbols -- the string/cask
 * predicates, the allocator door, and four lvm ops the nif's dispatch row names.
 * none of them is called here: main() enters at the algorithm, never at the lvm.
 * they exist so the object LINKS, which is why every body is a stub and why a
 * stub answering nonsense is harmless.
 *
 * include this AFTER the nif source. the types are love.h's and the
 * declarations are love.h's; this only lays the bodies. */
#pragma once
#include "love.h"

const struct mint mint_zero = {0, 0};

#include "../../src/love/alloc.c"               // a real allocator: deflate's arena asks it at run time

struct g *strof(struct g *g, const char *s) { return g; }
struct g *str0(struct g *g, uintptr_t n) { return g; }
struct g *please(struct g *g, uintptr_t n) { return g; }   // have()'s slow path

lvm(lvm_ret0) { return g; }
lvm(lvm_cur) { return g; }
lvm(lvm_cask) { return g; }
lvm(lvm_str) { return g; }              // love.h's inline strp() names it, so every nif does
lvm(lvm_chain) { return g; }
lvm(_lvm_ghelp) { return g; }

// the port side of a nif's state: named by the wrappers, entered by none of these programs.
// each dies by name, so a harness that does reach one says so
#include <stdio.h>
#include <stdlib.h>
static void stub_dead(const char *n) { fputs("stub called: ", stdout), puts(n), fflush(stdout), abort(); }
const struct port_vt state_vt = {0, 0, 0, 0};
union u *new_state(struct g **gp, uintptr_t n, uintptr_t clear) { stub_dead("new_state"); return 0; }
lvm(lvm_port_io) { stub_dead("lvm_port_io"); return g; }
lvm(_lvm_raise) { stub_dead("_lvm_raise"); return g; }
lvm(lvm_gc) { stub_dead("lvm_gc"); return g; }
lvm(lvm_big) { stub_dead("lvm_big"); return g; }
