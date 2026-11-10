// inflate.h -- RFC 1951 DEFLATE decoded, for gz.c and for uefi/slot.c, which has no love.
// an includer with bytes.h gets its one-load ld64, else a byte gather
#pragma once
#include "prefix.h"
#include <stdint.h>
#include <string.h>

#ifndef inf_heap
#define inf_heap 0
#endif
#ifndef wideld
#define wideld 0
static uint64_t ld64le(uint8_t const *p) {
 uint64_t v = 0;
 for (int i = 7; i >= 0; i--) v = v << 8 | p[i];
 return v; }
#endif

#if wideld
#define LD64(p) ld64(p)
#else
#define LD64(p) ld64le(p)
#endif

#if wideld
#define ST64(p, v) st64(p, v)
#else
#define ST64(p, v) ((void) 0)
#endif

// the tables, the reader's struct and the decoder, every function of it proved in test/uuinfvc.l
#include "inf_run_gen.h"

// -1 where the twin answers (), -2 past cap. out NULL answers the exact inflated length;
// dic is a preset dictionary of nd bytes before the output (nd 0 for none)
static int64_t inf_rundt(const uint8_t *in, uintptr_t n, uint8_t *out, uintptr_t cap,
                         const uint8_t *dic, uintptr_t nd, struct inf_tabs *t) {
 struct inf_rd r = { in, dic, out, t, n, 0, 0, cap, nd, 0, 0 };
 return inf_start(&r); }
// one block's tables: on the frame, or with inf_heap from alloc, for a stack too small for
// them (a playdate's game task)
static int64_t inf_rund(const uint8_t *in, uintptr_t n, uint8_t *out, uintptr_t cap,
                        const uint8_t *dic, uintptr_t nd) {
#if inf_heap
 struct inf_tabs *t = alloc(NULL, sizeof *t);
 if (!t) return -1;
 int64_t r = inf_rundt(in, n, out, cap, dic, nd, t);
 return alloc(t, 0), r;
#else
 struct inf_tabs t;
 return inf_rundt(in, n, out, cap, dic, nd, &t);
#endif
}
static int64_t inf_run(const uint8_t *in, uintptr_t n, uint8_t *out, uintptr_t cap) {
 return inf_rund(in, n, out, cap, 0, 0); }

// raw DEFLATE for C callers with no g (kmain's initrd)
intptr_t inflate_raw(const unsigned char *in, uintptr_t n, unsigned char *out, uintptr_t cap) {
 return (intptr_t) inf_run(in, n, out, cap); }
intptr_t inflate_dict(const unsigned char *in, uintptr_t n, unsigned char *out, uintptr_t cap,
                         const unsigned char *dic, uintptr_t nd) {
 return (intptr_t) inf_rund(in, n, out, cap, dic, nd); }
// chunks sharing one code: the code a block of no tokens, read once into tabs; a chunk its tokens
// behind the block type deflate reserves, so it can't be taken for a stream
uintptr_t inflate_tabs_size(void) { return sizeof(struct inf_tabs); }
int inflate_tabs_load(const unsigned char *in, uintptr_t n, void *tabs) {
 return inf_rundt(in, n, NULL, 0, 0, 0, tabs) == 0; }
int inflate_shared_is(const unsigned char *in, uintptr_t n) { return n && (in[0] & 7) == 7; }
intptr_t inflate_shared(const unsigned char *in, uintptr_t n, unsigned char *out, uintptr_t cap, void *tabs) {
 struct inf_rd r = { in, 0, out, tabs, n, 0, 0, cap, 0, 0, 0 };
 if (inf_take(&r, 3) != 7) return -1;
 int x = inf_block(&r);
 return x < 0 ? x : (intptr_t) r.op; }
