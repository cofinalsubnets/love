#include "i.h"

g_noinline g_vm(g_vm_gc, uintptr_t n) {
 Pack(f);
 if (!g_ok(f = g_please(f, n))) return gtrap(f);
 return Unpack(f), Continue(); }

static word gcp(struct g*, word, word const *, word const *);

g_inline struct g *have(struct g *f, uintptr_t n) {
 return !g_ok(f) || avail(f) >= n ? f : g_please(f, n); }

static g_inline void evac_two(struct g*f, word const*const p0, word const*const t0) {
 struct g_pair *w = (struct g_pair*) f->cp;
 f->cp += Width(struct g_pair);
 w->a = gcp(f, w->a, p0, t0);
 w->b = gcp(f, w->b, p0, t0); }

static g_inline void evac_vec(struct g*f, word const*const p0, word const*const t0) {
 f->cp += b2w(g_vec_bytes(vec(f->cp))); }

static g_inline void evac_str(struct g*f, word const*const p0, word const*const t0) {
 f->cp += b2w(sizeof(struct g_str) + str(f->cp)->len); }

static g_inline void evac_sym(struct g*f, word const*const p0, word const*const t0) {
 f->cp += Width(struct g_atom) - (sym(f->cp)->nom ? 0 : 2); }

static g_inline void evac_tbl(struct g*f, word const*const p0, word const*const t0) {
 struct g_tab *t = (struct g_tab*) f->cp;
 f->cp += Width(struct g_tab) + t->cap + t->len * Width(struct g_kvs);
 for (intptr_t i = 0, lim = t->cap; i < lim; i++)
  for (struct g_kvs*e = t->tab[i]; e;
   e->key = gcp(f, e->key, p0, t0),
   e->val = gcp(f, e->val, p0, t0),
   e = e->next); }

static g_inline void evac_thd(struct g *g, word const *const p0, word const*const t0) {
  for (g->cp += 2; g->cp[-2]; g->cp[-2] = gcp(g, g->cp[-2], p0, t0), g->cp++); }

static g_inline void evac_data(struct g *g, word const *const p0, word const*const t0) {
  switch (typ(g->cp)) {
   default: __builtin_trap();
   case vec_q: return evac_vec(g, p0, t0);
   case sym_q: return evac_sym(g, p0, t0);
   case two_q: return evac_two(g, p0, t0);
   case tbl_q: return evac_tbl(g, p0, t0);
   case text_q: return evac_str(g, p0, t0); } }

static g_inline void run_finalizers(struct g*g) {
 struct g_fz *new_fz = NULL;
 for (struct g_fz *fz = g->fz; fz; fz = fz->next) {
  word fwd = fz->p->x;
  if (homp(fwd) && ptr(g) <= ptr(fwd) && ptr(fwd) < ptr(g) + g->len) {
   struct g_fz *nn = bump(g, Width(struct g_fz));
   nn->p = cell(fwd), nn->fn = fz->fn, nn->next = new_fz, new_fz = nn;
  } else fz->fn(fz->p); }
 g->fz = new_fz; }

static g_noinline struct g *gcg(struct g*g, struct g *p1, uintptr_t len1, struct g *f) {
 memcpy(g, f, sizeof(struct g));
 g->pool = (void*) p1;
 g->len = len1;
 uintptr_t const len0 = f->len;
 word const *p0 = ptr(f),
            *t0 = ptr(f) + len0, // source top
            *sp0 = f->sp;
 word h = t0 - sp0; // stack height
 g->sp = ptr(g) + len1 - h;
 g->hp = g->cp = g->end;
 g->ip = cell(gcp(g, word(g->ip), p0, t0));
 g->tasks = cell(gcp(g, word(g->tasks), p0, t0));
 g->symbols = 0;
 for (word i = 0; i < g->end - &g->v0; i++) (&g->v0)[i] = gcp(g, (&g->v0)[i], p0, t0);               // core live variables
 for (word n = 0; n < h; n++) g->sp[n] = gcp(g, sp0[n], p0, t0);                     // stack
 for (struct g_r *s = g->root; s; s = s->n) *s->x = gcp(g, *s->x, p0, t0); // C live variables
 while (g->cp < g->hp) (datp(g->cp) ? evac_data : evac_thd)(g, p0, t0);              // cheney algorithm
 run_finalizers(g);
 return g; }


g_noinline struct g *g_please(struct g *f, uintptr_t req0) {
 uintptr_t const
  t0 = f->t0, // end of last gc period
  t1 = g_clock(), // end of current non-gc period
  len0 = f->len;
 // find alternate pool
 struct g *g = off_pool(f);
 f = gcg(g, f->pool, f->len, f);
 uintptr_t const
  v_lo = 4,
  v_hi = v_lo * v_lo,
  req = req0 + len0 - avail(f),
  t2 = g_clock();
 uintptr_t
  len1 = len0,
  v = t2 == t1 ? v_hi : (t2 - t0) / (t2 - t1);
 if (len1 < req || v < v_lo) // if too small
  do len1 <<= 1, v <<= 1; // then grow
  while (len1 < req || v < v_lo);
 else if (len1 > 2 * req && v > v_hi) // else if too big
  do len1 >>= 1, v >>= 1; // then shrink
  while (len1 > 2 * req && v > v_hi);
 else return f->t0 = t2, f; // else right size -> all done
 return // allocate a new pool with target size
  !(g = f->malloc(f, len1 * 2 * sizeof(word))) ? // if malloc fails but pool is big enough
   encode(f, req <= len0 ? g_status_ok : g_status_oom) : // we can still report success
  (g = gcg(g, g, len1, f),
   f->free(f, f->pool),
   g->t0 = g_clock(),
   g); }

static g_inline word copy_two(struct g*f, struct g_pair *src, word const *const p0, word const *const t0) {
 struct g_pair *dst = bump(f, Width(struct g_pair));
 ini_two(dst, src->a, src->b);
 src->ap = (g_vm_t*) dst;
 return word(dst); }

static g_inline word copy_vec(struct g*f, struct g_vec *src, word const *const p0, word const*const t0) {
 uintptr_t bytes = g_vec_bytes(src);
 struct g_vec *dst = bump(f, b2w(bytes));
 src->ap = memcpy(dst, src, bytes);
 return word(dst); }

static g_inline word copy_str(struct g*f, struct g_str *src, word const *const p0, word const*const t0) {
 uintptr_t bytes = sizeof(struct g_str) + src->len;
 struct g_str *dst = bump(f, b2w(bytes));
 src->ap = memcpy(dst, src, bytes);
 return word(dst); }

static g_inline word copy_sym(struct g*f, struct g_atom *src, word const *const p0, word const*const t0) {
 struct g_atom *dst;
 if (src->nom) dst = intern_checked(f, (struct g_str*) gcp(f, word(src->nom), p0, t0));
 else dst = bump(f, Width(struct g_atom) - 2),
      ini_anon(dst, src->code);
 return word(src->ap = (g_vm_t*) dst); }

static g_inline word copy_tbl(struct g*f, struct g_tab *src, word const*const p0, word const*const t0) {
 uintptr_t len = src->len, cap = src->cap;
 struct g_tab *dst = bump(f, Width(struct g_tab) + cap + Width(struct g_kvs) * len);
 struct g_kvs **tab = (struct g_kvs**) (dst + 1),
              *dd = (struct g_kvs*) (tab + cap);
 ini_tab(dst, len, cap, tab);
 src->ap = (g_vm_t*) dst;
 for (struct g_kvs *d, *s, *last; cap--; tab[cap] = last)
  for (s = src->tab[cap], last = NULL; s;
   d = dd++, d->key = s->key, d->val = s->val, d->next = last,
   last = d, s = s->next);
 return word(dst); }

static g_inline word copy_data(struct g *f, union u *src, word const *const p0, word const *const t0) {
 switch (typ(src)) {
  default: __builtin_trap();
  case two_q: return copy_two(f, two(src), p0, t0);
  case vec_q: return copy_vec(f, vec(src), p0, t0);
  case sym_q: return copy_sym(f, sym(src), p0, t0);
  case tbl_q: return copy_tbl(f, tbl(src), p0, t0);
  case text_q: return copy_str(f, str(src), p0, t0); } }

static g_inline word copy_thread(struct g *f, union u *src, word const *const p0, word const *const t0) {
 // it's a thread, find the end to find the head
 struct g_tag *t = ttag(src);
 union u *ini = t->head, *d = bump(f, t->end - ini), *dst = d;
 // copy source contents to dest and write dest addresses to source
 for (union u*s = ini; (d->x = s->x); s++->x = (word) d++);
 ((struct g_tag*) d)->head = dst;
 return (word) (dst + (src - ini)); }

static g_noinline intptr_t gcp(struct g *f, word x, word const *p0, word const *t0) {
 // if it's a number or it's outside managed memory then return it
 if (nump(x) || ptr(x) < p0 || ptr(x) >= t0) return x;
 union u *src = cell(x);
 x = src->x; // get its contents
 // if it contains a pointer to the new space then return the pointer
 return homp(x) && ptr(f) <= ptr(x) && ptr(x) < ptr(f) + f->len ? x :
        x == (word) g_vm_data ? copy_data(f, src, p0, t0) :
                                copy_thread(f, src, p0, t0); }
