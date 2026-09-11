// i/lib/lv.c -- the embedding API over the runtime. lv.h is what a host sees;
// this file is the only place the two vocabularies meet.
//
// three things a foreign caller cannot be handed and every one of them is here:
// a moving heap pointer (so values are stack indices), a condition (so a scare
// is a return code and the text is rendered on demand), and a nif cell (so a
// host callback rides an immortal trampoline that carries a slot number).
#include "love.h"
#include "lv.h"

#include <stdlib.h>
#include <string.h>

void lv_seat_sink(lv_writer, void*);      // seat.c

enum { lv_slots = 64 };                   // host callbacks per session

struct lv_slot { lv_fn fn; void *ud; int arity; union u k[5]; };

struct lv {
  struct ai *g;
  lv_writer write;
  void *write_ud;
  struct lv_slot slot[lv_slots];
  int nslot;
  char err[512];
  size_t errlen; };

// the one session a trampoline can reach: a nif cell carries a slot number and
// nothing else, so the session has to be found rather than passed. one console
// and one trampoline table are the same single-session fact -- see the README.
static struct lv *live;

// --- the sink ----------------------------------------------------------------
static void to_host(void *ud, int fd, char const *s, size_t n) {
  struct lv *L = ud;
  if (L->write) L->write(L->write_ud, fd, s, n); }

static void to_err(void *ud, int fd, char const *s, size_t n) {
  struct lv *L = ud;
  size_t room = sizeof L->err - 1 - L->errlen;
  if (n > room) n = room;
  memcpy(L->err + L->errlen, s, n), L->errlen += n, L->err[L->errlen] = 0; }

// --- the stack ---------------------------------------------------------------
// the core sits at the pool's base and the stack descends from its top, so the
// depth is that span. an index is a slot off sp, checked against it.
static word *lv_sp(struct lv const *L) { return ai_core_of(L->g)->sp; }

int lv_top(struct lv const *L) {
  struct ai *c = ai_core_of(L->g);
  return (int) (((word*) c + c->len) - c->sp); }

static word lv_ref(struct lv *L, int idx) {
  return idx >= 0 && idx < lv_top(L) ? lv_sp(L)[idx] : ai_zero; }

void lv_pop(struct lv *L, int n) {
  int have = lv_top(L);
  if (n > have) n = have;
  if (n > 0) ai_core_of(L->g)->sp += n; }

int lv_ok(struct lv const *L) { return ai_ok(L->g); }

static int lv_did(struct lv *L, struct ai *g) {
  L->g = g;
  return ai_ok(g) ? 0 : -1; }

// the pcall contract: a call that scared leaves the stack exactly as deep as it
// found it, and the session usable. the runtime does neither on its own -- love's
// own repl catches at the LOVE level (post.l's `trap`), and nothing in the tree
// re-enters a scared state from C. so the depth is remembered here and the status
// bits are stripped once the condition has been read.
static int lv_ran(struct lv *L, struct ai *g, int depth0) {
  L->g = g;
  if (ai_ok(g)) return 0;
  struct ai *c = ai_core_of(g);
  c->sp = (word*) c + c->len - depth0;
  return -1; }

static void lv_clear(struct lv *L) { L->g = ai_core_of(L->g); }

// --- open and close ----------------------------------------------------------
static struct ai *lv_boot(struct ai *g) {
  g = ai_defn(g, __start_love_nifs, __stop_love_nifs - __start_love_nifs);
  return ai_egg_(g,
#include "egg.h"
    ,
#include "p1.h"
    ,
#include "prel.h"
    " "
#include "ev.h"
    ,
#include "post.h"
    ); }

// waking an image skips the egg bake entirely: the same trade i/playdate makes,
// and the difference between opening a session per request and once per process.
void *lv_save(struct lv *L, size_t *len) {
  uintptr_t n = 0;
  void *b = ai_image_save(L->g, &n, NULL);
  return len ? *len = (size_t) n : 0, b; }

void lv_free(void *p) { if (p) ai_alloc(p, 0); }

struct lv *lv_open(struct lv_opt const *o) {
  struct lv *L = calloc(1, sizeof *L);
  if (!L) return NULL;
  L->write = o ? o->write : NULL;
  L->write_ud = o ? o->write_ud : NULL;
  lv_seat_sink(L->write ? to_host : NULL, L);
  live = L;
  struct ai *woke = o && o->image
                  ? ai_image_load(o->image, (uintptr_t) o->image_len) : NULL;
  struct ai *g = woke ? woke : ai_ini();
  if (ai_ok(g) && o && o->budget_mb)
    ai_core_of(g)->budget = (o->budget_mb << 20) / sizeof(word);
  L->g = woke ? ai_defn(g, __start_love_nifs,
                        __stop_love_nifs - __start_love_nifs)
              : lv_boot(g);
  if (!ai_ok(L->g)) return lv_close(L), NULL;
  L->g = ai_open_(L->g);                    // the session layer: defglob lands here
  if (!ai_ok(L->g)) return lv_close(L), NULL;
  return L; }

void lv_close(struct lv *L) {
  if (!L) return;
  if (live == L) live = NULL, lv_seat_sink(NULL, NULL);
  free(L); }                                // the heap is the process's; ai_fin has no free

// --- running -----------------------------------------------------------------
int lv_eval(struct lv *L, char const *src) {
  int d = lv_top(L);
  return lv_ran(L, ai_evals(L->g, src), d); }

int lv_global(struct lv *L, char const *name) {
  return lv_eval(L, name); }

// apply the value under nargs arguments. the stack holds [a1 .. an f ..]; the
// form is built as a chain of already-evaluated values, which c0 recognises as a
// constructed direct application and compiles without an opfix pass.
int lv_apply(struct lv *L, int nargs) {
  struct ai *g = L->g;
  int d = lv_top(L);
  if (!ai_ok(g)) return -1;
  if (nargs < 0 || d < nargs + 1) return -1;
  // args are at sp[0..n-1] with f at sp[n]; build (f a1 .. an) bottom-up
  g = ai_push(g, 1, ai_zero);                       // the tail, then one cons per arg
  for (int i = 0; i < nargs; i++) {
    if (!ai_ok(g)) return lv_ran(L, g, d);
    g = ai_push(g, 1, ai_core_of(g)->sp[1 + i]);    // sp[1] is the deepest arg == the last
    g = gxl(g); }                                   // (arg . tail)
  if (ai_ok(g)) g = ai_push(g, 1, ai_core_of(g)->sp[nargs + 1]), g = gxl(g);
  if (!ai_ok(g)) return lv_ran(L, g, d);
  // [form a1..an f ..] -> [form ..]
  { struct ai *c = ai_core_of(g);
    c->sp[nargs + 1] = c->sp[0], c->sp += nargs + 1; }
  return lv_ran(L, ai_eval_(g), d - nargs); }

// reading the condition is also what clears it: the face is rendered through the
// runtime's own printer, into the buffer, and the session goes back to ok.
char const *lv_error(struct lv *L) {
  L->err[0] = 0, L->errlen = 0;
  if (ai_code_of(L->g) != ai_status_scare) return L->err;
  lv_seat_sink(to_err, L);
  ai_scare_face_(L->g);
  lv_seat_sink(L->write ? to_host : NULL, L);
  return lv_clear(L), L->err; }

// --- pushing -----------------------------------------------------------------
int lv_pushnil(struct lv *L) { return lv_did(L, ai_push(L->g, 1, ai_zero)); }

int lv_pushint(struct lv *L, intptr_t n) {
  return lv_did(L, ai_push(L->g, 1, putcharm(n))); }

int lv_pushflo(struct lv *L, double d) {
  struct ai *g = ai_have(L->g, gem_req);
  if (!ai_ok(g)) return lv_did(L, g);
  word *hp = ai_core_of(g)->hp;
  word v = mk_gem(&hp, (ai_flo_t) d);
  ai_core_of(g)->hp = hp;
  return lv_did(L, ai_push(g, 1, v)); }

int lv_pushstr(struct lv *L, char const *s, size_t n) {
  if (n == (size_t) -1) n = strlen(s);
  struct ai *g = str0(L->g, n);                // a blank string, pushed
  if (ai_ok(g) && n) memcpy(txt(ai_core_of(g)->sp[0]), s, n);
  return lv_did(L, g); }

int lv_dup(struct lv *L, int idx) {
  return lv_did(L, ai_push(L->g, 1, lv_ref(L, idx))); }

// --- reading -----------------------------------------------------------------
enum lv_type lv_type_at(struct lv *L, int idx) {
  word x = lv_ref(L, idx);
  if (x == ai_zero) return lv_nil;
  switch (ai_kind(x)) {
  case KCharm: case KBig: return lv_int;
  case KGem: return lv_flo;
  case KString: return lv_str;
  case KNom: case KMint: return lv_sym;
  case KChain: return lv_list;
  case KCoin: return lv_fn_t;
  default: return lv_other; } }

intptr_t lv_toint(struct lv *L, int idx) {
  word x = lv_ref(L, idx);
  return charmp(x) ? getcharm(x) : gemp(x) ? (intptr_t) gem_get(x) : 0; }

double lv_toflo(struct lv *L, int idx) {
  word x = lv_ref(L, idx);
  return gemp(x) ? (double) gem_get(x) : charmp(x) ? (double) getcharm(x) : 0; }

char const *lv_tostr(struct lv *L, int idx, size_t *n) {
  word x = lv_ref(L, idx);
  if (!strp(x)) return n ? *n = 0 : 0, NULL;
  if (n) *n = len(x);
  return txt(x); }

size_t lv_strcpy(struct lv *L, int idx, char *dst, size_t cap) {
  size_t n = 0;
  char const *s = lv_tostr(L, idx, &n);
  if (!s || !cap) return n;
  size_t k = n < cap - 1 ? n : cap - 1;
  return memcpy(dst, s, k), dst[k] = 0, n; }

int lv_count(struct lv *L, int idx) {
  word x = lv_ref(L, idx);
  return (int) ai_count(ai_core_of(L->g), x); }

int lv_at(struct lv *L, int idx, int i) {
  word x = lv_ref(L, idx);
  if (strp(x)) return i < 0 || (uintptr_t) i >= len(x) ? lv_pushnil(L)
                    : lv_pushint(L, (unsigned char) txt(x)[i]);
  for (; chainp(x) && i > 0; i--) x = B(x);
  return lv_did(L, ai_push(L->g, 1, chainp(x) ? A(x) : ai_zero)); }

// --- host callbacks ----------------------------------------------------------
// the cell carries a slot number, never a function pointer: an image bakes a nif
// as an index and a raw C address in the heap could not ride one.
static ai_noinline struct ai *tramp_body(struct ai *g, intptr_t s) {
  struct lv *L = live;
  struct lv_slot *sl = &L->slot[s];
  L->g = g;
  int rc = sl->fn(L, sl->ud, sl->arity);
  g = L->g;
  if (rc || !ai_ok(g)) return ai_ok(g) ? ai_err(g, -1), encode(g, ai_status_scare) : g;
  struct ai *c = ai_core_of(g);
  c->sp[sl->arity] = c->sp[0], c->sp += sl->arity;   // [answer args..] -> [answer]
  return g; }

static lvm(lv_tramp) {
  Pack(g);
  g = tramp_body(g, getcharm(Ip[1].x));
  if (!ai_ok(g)) return g;
  Unpack(g);
  Ip += 2;
  return Continue(); }

int lv_defn(struct lv *L, char const *name, int arity, lv_fn fn, void *ud) {
  if (L->nslot >= lv_slots || arity < 1 || arity > 3) return -1;
  struct lv_slot *s = &L->slot[L->nslot];
  s->fn = fn, s->ud = ud, s->arity = arity;
  union u *k = s->k;
  int i = 0;
  if (arity > 1) k[i++].ap = lvm_cur, k[i++].x = putcharm(arity);
  k[i++].ap = lv_tramp;
  k[i++].x = putcharm(L->nslot);
  k[i++].ap = lvm_ret0;
  struct ai_def d = { name, { .k = s->k }, NULL };
  L->nslot += 1;
  return lv_did(L, ai_defn(L->g, &d, 1)); }
