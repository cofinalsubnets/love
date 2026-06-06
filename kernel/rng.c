#include "i.h"

// Step 8 -- random numbers. xoshiro256++ (Blackman & Vigna, public domain)
// seeded by SplitMix64. State is a rank-1 i64 vec of length 4 (256 bits) that
// rides the existing vec machinery -- no data sentinel, no enum q / G_DATA_VT_N
// / gen_data_vt / wasm-vt changes (cf. complex, Step 7). The payload is treated
// as raw bytes (memcpy), never via the typed vec_get/put accessors, so the
// 64-bit limbs survive on 32-bit ports and a given seed reproduces the same
// sequence on host/kernel/MCU/WASM/Playdate. Two stream flavors share the one
// representation: a global stream in f->rng (mutated in place by rand/randf) and
// a functional stream threaded explicitly (rand-next/randf-next copy the input
// state, step the copy, return (value . new-state) -- the input is never
// mutated). Not a CSPRNG. See [[project-todo-math]] step 8.

static g_inline uint64_t rotl64(uint64_t x, int k) {
 return (x << k) | (x >> (64 - k)); }

// All the uint64_t scratch (s[4]) lives in these g_noinline helpers that move it
// via memcpy: taking &s in a VM handler would defeat the Continue() sibcall (see
// the flo_get note in i.h), and memcpy is alignment-safe (a 32-bit port's
// vec_data is only 4-byte aligned, so a raw uint64_t* deref could fault).

// Advance the 4-word state stored at `payload` and return one 64-bit draw.
static g_noinline uint64_t rng_step(void *payload) {
 uint64_t s[4];
 memcpy(s, payload, sizeof s);
 uint64_t const result = rotl64(s[0] + s[3], 23) + s[0];
 uint64_t const t = s[1] << 17;
 s[2] ^= s[0]; s[3] ^= s[1]; s[1] ^= s[2]; s[0] ^= s[3];
 s[2] ^= t; s[3] = rotl64(s[3], 45);
 memcpy(payload, s, sizeof s);
 return result; }

// Fill the 4-word state at `payload` from a 64-bit seed via SplitMix64. The
// all-zero state is xoshiro's fixed point, so substitute a nonzero word if it
// ever arises (SplitMix64 makes that practically impossible, but be exact).
static g_noinline void rng_seed_into(void *payload, uint64_t seed) {
 uint64_t s[4], x = seed;
 for (int i = 0; i < RNG_STATE_LEN; i++) {
  uint64_t z = (x += (uint64_t) 0x9e3779b97f4a7c15);
  z = (z ^ (z >> 30)) * (uint64_t) 0xbf58476d1ce4e5b9;
  z = (z ^ (z >> 27)) * (uint64_t) 0x94d049bb133111eb;
  s[i] = z ^ (z >> 31); }
 if (!(s[0] | s[1] | s[2] | s[3])) s[0] = 1;
 memcpy(payload, s, sizeof s); }

// Map a 64-bit draw to a float in [0,1): keep the high mantissa bits and scale.
static g_inline g_flo_t u64_to_unit(uint64_t u) {
#if WBITS >= 64
 return (g_flo_t) (u >> 11) * (g_flo_t) 0x1.0p-53;
#else
 return (g_flo_t) (uint32_t) (u >> 40) * (g_flo_t) 0x1.0p-24f;
#endif
}

// Shape v as an i64 state vec (rank 1, len 4) and seed it. Exposed for the eager
// seed in g_ini_0. ini_vec + a pointer write only, so an inlining caller keeps
// its tail call; the &s scratch stays inside rng_seed_into.
void g_rng_seed(struct g_vec *v, uint64_t seed) {
 ini_vec(v, g_vt_i64, 1);
 v->shape[0] = RNG_STATE_LEN;
 rng_seed_into(vec_data(v), seed); }

// Is x a well-formed state vec (rank-1 i64, length 4)?
static g_inline bool rng_state_p(word x) {
 return vecp(x) && vec(x)->rank == 1 && vec(x)->type == g_vt_i64
        && vec(x)->shape[0] == RNG_STATE_LEN; }

// Build a fresh state vec at Hp, copying the 4 limbs of `src` into it. Caller
// holds Have(RNG_VEC_REQ). Both pointers are heap pointers -> no &local escape.
static g_inline struct g_vec *rng_copy(g_word **hp, struct g_vec *src) {
 struct g_vec *v = (struct g_vec*) *hp;
 *hp += RNG_VEC_REQ;
 ini_vec(v, g_vt_i64, 1);
 v->shape[0] = RNG_STATE_LEN;
 memcpy(vec_data(v), vec_data(src), RNG_PAYLOAD_BYTES);
 return v; }

// (rng-seed n): a fresh state vec deterministically seeded from fixnum n. A
// non-fixnum seeds from 0.
g_vm(g_vm_rng_seed) {
 word n = Sp[0];
 uint64_t seed = nump(n) ? (uint64_t) (intptr_t) getnum(n) : 0;
 Have(RNG_VEC_REQ);
 struct g_vec *v = (struct g_vec*) Hp; Hp += RNG_VEC_REQ;
 g_rng_seed(v, seed);
 return Sp[0] = word(v), Ip++, Continue(); }

// (rng-get _): a snapshot copy of the global state vec (never aliases it).
g_vm(g_vm_rng_get) {
 Have(RNG_VEC_REQ);
 struct g_vec *src = vec(f->rng);            // re-read post-Have (GC may move it)
 struct g_vec *v = rng_copy(&Hp, src);
 return Sp[0] = word(v), Ip++, Continue(); }

// (rng-set v): install v's 4 limbs into the global state (copies, never aliases),
// returning v; nil if v isn't a valid state vec.
g_vm(g_vm_rng_set) {
 word v = Sp[0];
 if (!rng_state_p(v)) return Sp[0] = nil, Ip++, Continue();
 memcpy(vec_data(vec(f->rng)), vec_data(vec(v)), RNG_PAYLOAD_BYTES);
 return Ip++, Continue(); }            // Sp[0] (== v) is the result

// (rand n): global draw, fixnum in [0,n); n <= 0 (incl. nil) -> a full-width
// non-negative fixnum. No allocation (the result is always a fixnum), so no Have
// and no GC concern from mutating f->rng in place.
g_vm(g_vm_rand) {
 word n = Sp[0];
 uint64_t r = rng_step(vec_data(vec(f->rng)));
 intptr_t out = nump(n) && getnum(n) > 0
   ? (intptr_t) (r % (uint64_t) getnum(n))
   : (intptr_t) (r & (uint64_t) FIX_MAX);
 return Sp[0] = putnum(out), Ip++, Continue(); }

// (randf _): global draw, float in [0,1). Have() runs before stepping so a
// GC-triggered handler restart doesn't double-advance the state.
g_vm(g_vm_randf) {
 word _res;
 Have(BOX_REQ);
 uint64_t r = rng_step(vec_data(vec(f->rng)));
 g_flo_t u = u64_to_unit(r);
 EMIT_FLO(u);
 return Sp[0] = _res, Ip++, Continue(); }

// (rand-next st): functional draw -> (value . st'), value a full-width
// non-negative fixnum. st is copied (referentially transparent); st' is the
// stepped copy.
g_vm(g_vm_rand_next) {
 word st = Sp[0];
 if (!rng_state_p(st)) return Sp[0] = nil, Ip++, Continue();
 Have(RNG_VEC_REQ + Width(struct g_pair));
 st = Sp[0];                                 // re-read post-Have
 struct g_vec *v = rng_copy(&Hp, vec(st));
 uint64_t r = rng_step(vec_data(v));
 struct g_pair *p = (struct g_pair*) Hp; Hp += Width(struct g_pair);
 ini_two(p, putnum((intptr_t) (r & (uint64_t) FIX_MAX)), word(v));
 return Sp[0] = word(p), Ip++, Continue(); }

// (randf-next st): functional draw -> (float . st'), float in [0,1).
g_vm(g_vm_randf_next) {
 word st = Sp[0], _res;
 if (!rng_state_p(st)) return Sp[0] = nil, Ip++, Continue();
 Have(RNG_VEC_REQ + BOX_REQ + Width(struct g_pair));
 st = Sp[0];                                 // re-read post-Have
 struct g_vec *v = rng_copy(&Hp, vec(st));
 uint64_t r = rng_step(vec_data(v));
 g_flo_t u = u64_to_unit(r);
 EMIT_FLO(u);                                // box at Hp, into _res
 struct g_pair *p = (struct g_pair*) Hp; Hp += Width(struct g_pair);
 ini_two(p, _res, word(v));
 return Sp[0] = word(p), Ip++, Continue(); }
