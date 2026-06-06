#include "i.h"

static g_inline bool iop(word x) { return homp(x) && cell(x)->ap == g_vm_port_io; }
static g_inline struct g_port_vt const *port_vt(word fd_tagged) {
 intptr_t fd = getnum(fd_tagged);
 return fd >= 0 ? &g_fd_port_vt : &synth[-(fd + 1)]; }
static g_inline struct g *zgetc(struct g*f)          { return g_ok(f) ? port_vt(f->io->fd)->getc(f) : f; }
static g_inline struct g *zungetc(struct g*f, int c) { return g_ok(f) ? port_vt(f->io->fd)->ungetc(f, c) : f; }
static g_inline struct g *zputc(struct g*f, int c)   { return port_vt(f->io->fd)->putc(f, c); }
static g_inline struct g *zflush(struct g*f)         { return port_vt(f->io->fd)->flush(f); }
static g_inline struct g *zeof(struct g*f)           { return g_ok(f) ? port_vt(f->io->fd)->eof(f) : f; }
struct ci { struct g_io io; g_word head; }; // charlist input
struct to { struct g_io io; struct g_str *buf; g_word i; }; // lisp string output
static struct g *g_dtoa2(struct g*, g_flo_t);
static struct g *gfputx(struct g *f, struct g_io *o, intptr_t x);

static struct g *noop_getc(struct g *f) {
 g_core_of(f)->io->eof_seen = putnum(true);
 return f->b = EOF, f; }
static struct g *noop_ungetc(struct g *f, int c) { (void) c; return f; }
static struct g *noop_eof(struct g *f) { return f->b = true, f; }
static struct g *noop_putc(struct g *f, int c) { (void) c; return f; }
static struct g *noop_flush(struct g *f) { return f; }

static struct g *ti_eof(struct g*f) {
 struct ti *i = (struct ti*) f->io;
 return f->b = (getnum(i->io.ungetc_buf) == EOF) && getnum(i->io.eof_seen), f; }

static struct g *ti_getc(struct g*f) {
 struct ti *i = (struct ti*) f->io;
 if (getnum(i->io.ungetc_buf) != EOF) {
  int c = getnum(i->io.ungetc_buf);
  i->io.ungetc_buf = putnum(EOF);
  return f->b = c, f; }
 if (!i->t[i->i]) { i->io.eof_seen = putnum(true); return f->b = EOF, f; }
 return f->b = i->t[i->i++], f; }

static struct g *ti_ungetc(struct g*f, int c) {
 struct ti *i = (struct ti*) f->io;
 i->io.ungetc_buf = putnum(c);
 i->io.eof_seen = putnum(false);
 return f->b = c, f; }

static struct g *ci_getc(struct g *f) {
 struct ci *i = (struct ci*) f->io;
 if (getnum(i->io.ungetc_buf) != EOF) {
  int c = getnum(i->io.ungetc_buf);
  i->io.ungetc_buf = putnum(EOF);
  return f->b = c, f; }
 if (!twop(i->head)) { i->io.eof_seen = putnum(true); return f->b = EOF, f; }
 int c = getnum(A(i->head));
 i->head = B(i->head);
 return f->b = c, f; }

static struct g *to_putc(struct g *f, int c) {
 struct to *o = (struct to*) f->io;
 uintptr_t i = getnum(o->i);
 if (i >= len(o->buf)) {
  uintptr_t new_cap = len(o->buf) * 2;
  f = str0(f, new_cap);
  if (!g_ok(f)) return f;
  o = (struct to*) f->io;                 // GC may have moved it; f->out is GC-traced
  struct g_str *nb = (struct g_str*) f->sp[0];
  memcpy(txt(nb), txt(o->buf), i);
  o->buf = nb;
  f->sp++; }
 txt(o->buf)[i] = c;
 o->i = putnum(i + 1);
 return f; }
static struct g *to_flush(struct g *f) { return f; }

struct g_port_vt const synth[] = {
 /* fd = -1, ti: read-only string source */
 { ti_getc,   ti_ungetc,   ti_eof,   noop_putc, noop_flush },
 /* fd = -2, to: write-only vec sink   */
 { noop_getc, noop_ungetc, noop_eof, to_putc,   to_flush   },
 /* fd = -3, closed port (post-close)  */
 { noop_getc, noop_ungetc, noop_eof, noop_putc, noop_flush },
 /* fd = -4, ci: read-only charlist source -- ungetc/eof read only the g_io
    fields, so ti_ungetc/ti_eof work unchanged here. */
 { ci_getc,   ti_ungetc,   ti_eof,   noop_putc, noop_flush }, };

// (fputc port byte) — write byte to port; return byte.
g_vm(g_vm_fputc) {
 if (iop(Sp[0])) {
  f->io = (struct g_io*) Sp[0];
  Pack(f);
  if (!g_ok(f = zputc(f, getnum(f->sp[1])))) return gtrap(f);
  Unpack(f); }
 return Sp++, Ip++, Continue(); }

// (fflush port) — flush; return the port.
g_vm(g_vm_fflush) {
 if (iop(Sp[0])) {
  f->io = (struct g_io*) Sp[0];
  Pack(f);
  if (!g_ok(f = zflush(f))) return gtrap(f);
  Unpack(f); }
 return Ip++, Continue(); }

// (fputs port s) — write every byte of string-or-buf s through port; return
// the port. No-op when args are misused (non-port, or neither string nor
// buf). bytes_of resolves either to the g_str holding the bytes, re-read each
// iteration so GC inside zputc (e.g., growing a sink buffer) can forward it
// safely (for a buf, GC may move both the wrapper and its backing string).
g_vm(g_vm_fputs) {
 if (iop(Sp[0]) && (strp(Sp[1]) || bufp(Sp[1]))) {
  f->io = (struct g_io*) Sp[0];
  uintptr_t i = 0, l = len(bytes_of(Sp[1]));
  Pack(f);
  while (g_ok(f) && i < l) f = zputc(f, txt(bytes_of(f->sp[1]))[i++]);
  if (!g_ok(f = zflush(f))) return gtrap(f);
  Unpack(f); }
 return Sp++, Ip++, Continue(); }

g_vm(g_vm_fputx) {
 if (iop(Sp[0])) {
  Pack(f);
  if (!g_ok(f = gfputx(f, (struct g_io*) Sp[0], Sp[1]))) return gtrap(f);
  Unpack(f); }
 return Sp++, Ip++, Continue(); }

static struct g*gfputn(struct g *f, intptr_t n, uint8_t b, struct g_io *o);
g_vm(g_vm_fputn) {
 if (iop(Sp[0])) {
   Pack(f);
   if (!g_ok(f = gfputn(f, getnum(Sp[1]), getnum(Sp[2]), (struct g_io*) Sp[0]))) return gtrap(f);
   Unpack(f);
   Sp[2] = Sp[1]; }
 return Sp += 2, Ip++, Continue(); }

static struct g*gzputc(struct g*f, int c) {
  return port_vt(g_core_of(f)->io->fd)->putc(f, c); }
static struct g*gzputs(struct g*f, char const *s) {
 while (*s) f = gzputc(f, *s++);
 return f; }

static struct g*gzputn(struct g *f, intptr_t n, uint8_t b) {
 uintptr_t
  m = n >= 0 || b != 10 ? (uintptr_t) n : (f = gzputc(f, '-'), -(uintptr_t) n),
  q = m / b,
  r = m % b;
 if (q) f = gzputn(f, q, b);
 return gzputc(f, g_digits[r]); }

static g_inline struct g*gfputn(struct g *f, intptr_t n, uint8_t b, struct g_io *o) {
 return f->io = o, gzputn(f, n, b); }

static struct g*gvzprintf(struct g*f, char const *fmt, va_list xs) {
 for (int c; (c = *fmt++);) {
  if (c != '%') f = gzputc(f, c);
  else pass: switch ((c = *fmt++)) {
   case 0: return f;
   case 'l': goto pass;
   case 'b': f = gzputn(f, va_arg(xs, uintptr_t), 2); continue;
   case 'n': f = gzputn(f, va_arg(xs, uintptr_t), 6); continue;
   case 'o': f = gzputn(f, va_arg(xs, uintptr_t), 8); continue;
   case 'd': f = gzputn(f, va_arg(xs, uintptr_t), 10); continue;
   case 'u': f = gzputn(f, va_arg(xs, uintptr_t), 12); continue;
   case 'x': f = gzputn(f, va_arg(xs, uintptr_t), 16); continue;
   case 'z': f = gzputn(f, va_arg(xs, uintptr_t), 36); continue;
   default: f = gzputc(f, c); } }
 return f; }

static struct g *gzprintf(struct g *f, char const *fmt, ...) {
 va_list xs;
 va_start(xs, fmt);
 f = gvzprintf(f, fmt, xs);
 va_end(xs);
 return f; }

static struct g *gzputx(struct g *f, intptr_t x, uintptr_t off);
static struct g *gzputcs(struct g *f, char const *s);

// --- print cycle detection (tables only) --------------------------------------
// A "seen" list of the tables on the current print path lives in a single stack
// slot at the bottom of the print region (established by gfputx). It moves with
// the stack on GC, so callers locate it by its offset from the stack top (`off`),
// which GC preserves; the offset is threaded down the recursion as an ordinary
// integer (no struct-g state). A table is consed on as we descend into it and
// dropped as we ascend, so the list is exactly the ancestor path of tables. When
// printing finishes gfputx restores the original stack height, discarding it.
static word *seen_slot(struct g *f, uintptr_t off) {
 return topof(g_core_of(f)) - off; }
static bool seen_member(struct g *f, uintptr_t off, word x) {
 for (word l = *seen_slot(f, off); twop(l); l = B(l)) if (A(l) == x) return true;
 return false; }
static struct g *seen_push(struct g *f, uintptr_t off, word x) {   // cons x onto seen
 if (!g_ok(f = g_push(f, 1, x))) return f;                         // protect x across GC
 if (!g_ok(f = g_have(f, Width(struct g_pair)))) return g_pop(f, 1);
 struct g_pair *p = bump(f, Width(struct g_pair));
 word *slot = seen_slot(f, off);                                   // re-read: GC may move it
 ini_two(p, f->sp[0], *slot);
 *slot = (word) p;
 return g_pop(f, 1); }
static void seen_pop(struct g *f, uintptr_t off) {                 // drop the newest entry
 word *slot = seen_slot(f, off);
 *slot = B(*slot); }

static g_inline struct g*gzput_two(struct g*f, word _, uintptr_t off) {
 if (!g_ok(f = g_push(f, 1, _))) return f;
 struct g_str *n;
 // a one-operand `\` pair (`(\ x)`) is quote -> print as 'x; ≥2 operands is a lambda.
 if (symp(A(f->sp[0])) && (n = sym(A(f->sp[0]))->nom) && len(n) == 1 && txt(n)[0] == '\\'
     && twop(B(f->sp[0])) && !twop(BB(f->sp[0])))
  f = gzputx(gzputc(f, '\''), AB(f->sp[0]), off);
 else for (f = gzputc(f, '(');; f = gzputc(f, ' '), f->sp[0] = B(f->sp[0])) {
  f = gzputx(f, A(f->sp[0]), off);            // off threaded so nested tables are still tracked
  if (!twop(B(f->sp[0]))) { f = gzputc(f, ')'); break; } }
 return g_pop(f, 1); }


// Print element i of the array parked at f->sp[0] as a bare number (float ->
// g_dtoa, integer -> base 10). The element value is read before any gzputc, so
// a GC during printing (string-port growth) that relocates the array is safe;
// callers re-fetch vec(f->sp[0]) each call for the same reason.
static struct g *gzput_vec_elem(struct g *f, uintptr_t i) {
 struct g_vec *v = vec(f->sp[0]);
 if (v->type >= g_vt_f32)
  return g_dtoa2(f, vec_get_flo(v, i));
 return gzputn(f, vec_get_int(v, i), 10); }

// element-type code (0..5) -> the prelude symbol bound to it, so the printed
// `arrl` form round-trips: `(arrl i64 …)` reads `i64` back as the code 3.
static char const *const g_vt_names[] = { "i8", "i16", "i32", "i64", "f32", "f64" };

// Print a rank>=1 array (f->sp[0]) as a `,`-prefixed constructor expression that
// reads back to the same array (`,` = uq = identity). A rank-1 i64/f64 array uses
// the terse `,(vec a b …)` (vec infers i64/f64 from its args); anything else uses
// `,(arrl <type> '(shape) '(vals))`, which pins the exact element type and shape.
// The array may move on a GC during printing, so shape/elements are re-fetched
// from f->sp[0] each step (gzput_vec_elem already does this internally).
static struct g *gzput_arr(struct g *f) {
 struct g_vec *v = vec(f->sp[0]);
 uintptr_t rank = v->rank, type = v->type, nelem = 1;
 for (uintptr_t i = 0; i < rank; i++) nelem *= v->shape[i];
 if (rank == 1 && (type == g_vt_i64 || type == g_vt_f64)) {
  f = gzprintf(f, ",(vec");
  for (uintptr_t i = 0; g_ok(f) && i < nelem; i++)
   f = gzput_vec_elem(gzputc(f, ' '), i);
  return g_ok(f) ? gzputc(f, ')') : f; }
 f = gzprintf(f, ",(arrl ");
 for (char const *s = g_vt_names[type]; g_ok(f) && *s; s++) f = gzputc(f, *s);
 f = gzprintf(f, " '(");
 for (uintptr_t i = 0; g_ok(f) && i < rank; i++) {
  if (i) f = gzputc(f, ' ');
  f = gzputn(f, vec(f->sp[0])->shape[i], 10); }
 f = gzprintf(f, ") '(");
 for (uintptr_t i = 0; g_ok(f) && i < nelem; i++) {
  if (i) f = gzputc(f, ' ');
  f = gzput_vec_elem(f, i); }
 return g_ok(f) ? gzprintf(f, "))") : f; }

static g_inline struct g*gzput_vec_scalar_float(struct g*f) {
 return g_dtoa2(f, (g_flo_t) flo_get(f->sp[0])); }

// complex -> ,(cplx re im); round-trips via uq=identity (cplx is a bif). re/im are
// read into C locals up front so a GC during g_dtoa2 can't strand the operand.
static g_inline struct g*gzput_vec_scalar_complex(struct g*f) {
 g_flo_t re = cplx_re(f->sp[0]), im = cplx_im(f->sp[0]);
 f = gzprintf(f, ",(cplx ");
 f = g_dtoa2(f, re);
 f = gzputc(f, ' ');
 f = g_dtoa2(f, im);
 return gzputc(f, ')'); }

static g_inline struct g*gzput_vec(struct g*f, word _) {
 intptr_t rank = vec(_)->rank, type = vec(_)->type;
 if (!g_ok(f = g_push(f, 1, _))) return f;
 if (rank == 0 && type == G_VT_FLO) f = gzput_vec_scalar_float(f);
 else if (rank == 0 && type == G_VT_INT) f = gzputn(f, box_get(f->sp[0]), 10);
 else if (rank == 0 && type == G_VT_CPLX) f = gzput_vec_scalar_complex(f);
 else if (rank >= 1) f = gzput_arr(f);
 else f = gzprintf(f, ",vec@%z:%d.%d", vec(f->sp[0]), type, rank);
 return g_pop(f, 1); }

static g_inline struct g*gzput_str(struct g*f, word _) {
 uintptr_t slen = len(_);
 f = gzputc(g_push(f, 1, _), '"');
 for (uintptr_t i = 0; g_ok(f) && i < slen; i++) {
  char c = txt(f->sp[0])[i];
  if (c == '\\' || c == '"') f = gzputc(f, '\\');
  else if (c == '\n') f = gzputc(f, '\\'), c = 'n';
  else if (c == '\t') f = gzputc(f, '\\'), c = 't';
  else if (c == '\r') f = gzputc(f, '\\'), c = 'r';
  else if (c == '\0') f = gzputc(f, '\\'), c = '0';
  else if ((unsigned char) c < 32)
   f = gzputc(gzputc(gzputc(f, '\\'), 'x'), g_digits[(c >> 4) & 0xf]),
   c = g_digits[c & 0xf];
  f = gzputc(f, c); }
 return g_pop(gzputc(f, '"'), 1); }

// A symbol's nom encodes its kind: 0 = anonymous gensym, a string = interned, a
// symbol = named-uninterned (the naming symbol, whose own nom is the name string).
// Interned syms print bare; the other two get a leading , (parses, won't round-
// trip) -- anonymous as ,sym@<addr>, named-uninterned as ,<name>@<addr>.
static g_inline struct g*gzput_sym(struct g*f, word _) {
 if (g_ok(f = g_push(f, 1, _))) {
  word nom = word(sym(f->sp[0])->nom);
  if (!nom) f = gzprintf(f, "@%z", f->sp[0]);           // anonymous gensym
  else if (strp(nom)) {                                     // interned: bare name
   f->sp[0] = nom;
   for (uintptr_t l = len(nom), i = 0; g_ok(f) && i < l;)
     f = gzputc(f, txt(f->sp[0])[i++]);
  } else {                                                  // named but uninterned
   word name = word(sym(nom)->nom), addr = f->sp[0];
   if (!name || !strp(name)) f = gzprintf(f, "@%z", addr); // named after a nameless sym: fall back
   else {
    f->sp[0] = name;
    for (uintptr_t l = len(name), i = 0; g_ok(f) && i < l;)
        f = gzputc(f, txt(f->sp[0])[i++]);
    if (g_ok(f)) f = gzprintf(f, "@%z", addr); } } }
 return g_pop(f, 1); }

#define fs0(f) (g_core_of(f)->sp[0])

// table -> #(k1 v1 k2 v2 …); the `#` reader macro splices that back into a table
// (#() reads as a fresh empty table). Entries are first snapshotted into an assoc
// list ((k . v) …) in a single allocation, so the g_kvs C-pointer walk can't be
// split by a GC; the list is parked on f->sp[0] and each k/v is re-read from there
// after the printer (which may GC on string-port growth) runs.
static g_inline struct g*gzput_tbl(struct g*f, word x, uintptr_t off) {
 if (!g_ok(f = g_push(f, 1, x))) return f;            // sp[0] = table
 uintptr_t n = tbl(f->sp[0])->len;
 if (!g_ok(f = g_have(f, n * 2 * Width(struct g_pair)))) return g_pop(f, 1);
 struct g_tab *t = tbl(f->sp[0]);                     // re-fetch after possible GC
 struct g_pair *p = bump(f, n * 2 * Width(struct g_pair));
 word list = nil;
 for (uintptr_t i = t->cap; i;)
  for (struct g_kvs *e = t->tab[--i]; e; e = e->next) {
   struct g_pair *kv = p++;
   ini_two(kv, e->key, e->val);                       // (k . v)
   ini_two(p, (word) kv, list);                       // cons onto the snapshot
   list = (word) p++; }
 fs0(f) = list;
 if (g_ok(f = gzprintf(f, "#(")) && twop(fs0(f))) for (bool sp = false;;) {
  if (sp) f = gzputc(f, ' ');                    // space between entries, not before the first
  sp = true;
  f = gzputx(f, AA(g_core_of(f)->sp[0]), off);   // key (re-read after gzputc)
  f = gzputc(f, ' '); f = gzputx(f, BA(g_core_of(f)->sp[0]), off);
  g_core_of(f)->sp[0] = B(g_core_of(f)->sp[0]);
  if (!g_ok(f) || !twop(f->sp[0])) break; }

 return g_pop(g_ok(f) ? gzputc(f, ')') : f, 1); }

// A bignum prints in base 10 (with sign). g_big_dec renders it to a fresh
// string (repeated divide-by-10 of a heap-local copy); we then emit the bytes,
// re-fetching sp[0] each step since gzputc may grow a string port and GC.
static g_inline struct g*gzput_big(struct g*f, word x) {
 if (!g_ok(f = g_push(f, 1, x))) return f;
 f = g_big_dec(f);
 for (uintptr_t i = 0, n = g_ok(f) ? len(f->sp[0]) : 0; g_ok(f) && i < n; i++)
  f = gzputc(f, txt(f->sp[0])[i]);
 return g_pop(f, 1); }

// emit a C string literal byte-for-byte.
static struct g *gzputcs(struct g *f, char const *s) {
 for (; g_ok(f) && *s; s++) f = gzputc(f, *s);
 return f; }

// --- partial-application introspection (mirrors kernel/vm.c g_vm_cur/g_vm_unc) ---
// A partial-app closure is a thread whose head is g_vm_unc (one more arg wanted)
// or [g_vm_cur n][g_vm_unc …] (more wanted). Each g_vm_unc cell holds a captured
// arg at [1] and a link at [2] that points either to the next (older) closure's
// unc cell or, for the last one, two cells into the underlying function's body --
// so the base function value is terminal_link-2 and the captured args are the
// chain of [1] fields, newest first. The chain survives GC (interior pointers are
// relocated), so callers re-walk from the parked, possibly-moved closure.
static bool fn_partialp(union u *k) {
 return k[0].ap == g_vm_unc || (k[0].ap == g_vm_cur && k[2].ap == g_vm_unc); }
static g_inline union u *fn_unc0(union u *k) {
 return k[0].ap == g_vm_cur ? k + 2 : k; }       // first unc cell
static union u *fn_base(union u *k, int *nargs) { // base value + captured-arg count
 union u *u = fn_unc0(k), *link;
 int n = 0;
 for (;;) { link = u[2].m; n++; if (link[0].ap != g_vm_unc) break; u = link; }
 return *nargs = n, link - 2; }
static word fn_arg(union u *k, int i, int nargs) { // i-th arg in application order
 union u *u = fn_unc0(k);
 for (int w = nargs - 1 - i; w > 0; w--) u = u[2].m;
 return u[1].x; }

static struct g *gzput_fn_body(struct g *f, word x, uintptr_t off);

// the in-pool source \-expr stashed at value[-1] by a compiled lambda, or 0.
static word fn_src(struct g *c, union u *k, word x) {
 word s = k[-1].x;
 return ptr(x) > ptr(c) && ptr(x) < ptr(c) + c->len
     && homp(s) && ptr(s) >= ptr(c) && ptr(s) < ptr(c) + c->len && twop(s) ? s : 0; }

// Print a function value. Like vec/cplx/tbl it's a `,`-prefixed value form (so it
// reads back via uq=identity): ,(base arg…) for a partial application / closure,
// ,name for a builtin, ,(\ …) for a compiled lambda (its stored source). An opaque
// thread (continuation, top-level wrap) has no constructor form, so it prints as the
// opaque, re-parsable token ,thd@<addr>. The leading , is emitted once here; body w/o it.
static struct g *gzput_fn(struct g *f, word x, uintptr_t off) {
 union u *k = cell(x);
 bool reprp = fn_partialp(k) || g_bif_name(x) || fn_src(g_core_of(f), k, x);
 return reprp ? gzput_fn_body(f, x, off) : gzprintf(f, "\\%z", x); }

// Render a function as a bare constructor expression (NO leading ,). Detection
// order matters: a bare multi-arg lambda and a partial-app both have a g_vm_cur
// head, and a bif's value[-1] is undefined static data. The partial-app base
// recurses here (not gzput_fn) so it doesn't get its own comma.
static struct g *gzput_fn_body(struct g *f, word x, uintptr_t off) {
 struct g *c = g_core_of(f);
 union u *k = cell(x);
 if (fn_partialp(k)) {                              // (base arg…)
  if (!g_ok(f = g_push(f, 1, x))) return f;         // park: GC relocates the closure
  int na; fn_base(cell(f->sp[0]), &na);
  f = gzputc(f, '(');
  { union u *bk = cell(f->sp[0]); int n2;           // base re-derived after each gzputc
    f = gzput_fn_body(f, (word) fn_base(bk, &n2), off); }
  for (int i = 0; g_ok(f) && i < na; i++) {
   f = gzputc(f, ' ');                              // separate stmt: re-read arg after GC
   f = gzputx(f, fn_arg(cell(f->sp[0]), i, na), off); }
  return g_pop(g_ok(f) ? gzputc(f, ')') : f, 1); }
 char const *nm = g_bif_name(x);                    // builtin -> name
 if (nm) return gzputcs(f, nm);
 word s = fn_src(c, k, x);                          // compiled lambda -> source \-expr
 return s ? gzputx(f, s, off) : gzprintf(f, "\\%z", x); }

static g_noinline struct g *gzputx(struct g *f, intptr_t x, uintptr_t off) {
 if (nump(x)) return gzprintf(f, "%d", getnum(x));
 if (!datp(x)) return gzput_fn(f, x, off);
 // a table is mutable and can contain itself; guard the recursion with the seen
 // list so a self-referential table prints a marker instead of looping forever.
 // (pairs are only cyclic via low-level poke, so we don't pay the cost there.)
 bool cyc = typ(x) == tbl_q;
 if (cyc) {
  if (seen_member(f, off, x)) return gzputcs(f, "<cycle>");
  if (!g_ok(f = seen_push(f, off, x))) return f;
  x = A(*seen_slot(f, off)); }   // seen_push may have GC'd; reload x from the slot it pushed
 switch (typ(x)) {
   default: __builtin_trap();
   case two_q:  f = gzput_two(f, x, off); break;
   case vec_q:  f = gzput_vec(f, x); break;
   case sym_q:  f = gzput_sym(f, x); break;
   case tbl_q:  f = gzput_tbl(f, x, off); break;
   case text_q: f = gzput_str(f, x); break;
   case big_q:  f = gzput_big(f, x); break; }
 if (cyc) seen_pop(f, off);
 return f; }

// Establish a fresh seen-list slot at the bottom of the print region, print, then
// restore the original stack height (discarding the slot and the whole list).
static g_inline struct g *gfputx(struct g *f, struct g_io *o, intptr_t x) {
 struct g *c = g_core_of(f);
 c->io = o;
 uintptr_t base = topof(c) - c->sp;                 // original height (GC-invariant)
 if (!g_ok(f = g_push(f, 1, nil))) return f;        // the seen-list slot
 c = g_core_of(f);
 f = gzputx(f, x, topof(c) - c->sp);                // offset of the slot from the top
 c = g_core_of(f);
 return c->sp = topof(c) - base, f; }               // restore original stack height

// AI slop alert....
//
#if UINTPTR_MAX > 0xffffffffu
#define DTOA_INF    1e308
#define DTOA_SCI_HI 1e16
#define DTOA_SCI_LO 1e-4
#else
#define DTOA_INF    __FLT_MAX__
#define DTOA_SCI_HI 1e16f
#define DTOA_SCI_LO 1e-4f
#endif

static struct g* g_dtoa2(struct g*f, g_flo_t v) {
 int const max_frac = sizeof(g_flo_t) == 4 ? 7 : 15;
 if (v != v) return gzputs(f, "nan");
 if (v < 0) f = gzputc(f, '-'), v = -v;
 if (v > DTOA_INF) return gzputs(f, "inf");
 int exp = 0;
 bool sci = false;
 if (v != 0 && (v >= DTOA_SCI_HI || v < DTOA_SCI_LO)) {
  sci = true;
  while (v >= 10) v /= 10, exp++;
  while (v < 1)  v *= 10, exp--; }
 // integer part, lsb-first then reversed
 word ip = (word) v;
 g_flo_t frac = v - (g_flo_t) ip;
 char ib[24];
 int ib_n = 0;
 if (ip == 0) ib[ib_n++] = '0';
 while (ip) ib[ib_n++] = '0' + ip % 10, ip /= 10;
 while (ib_n > 0) f = gzputc(f, ib[--ib_n]);
 // fractional digits; in non-scientific mode always emit at least ".0"
 // so the result is visually distinguishable from a fixnum.
 bool emit_frac = frac > 0 || !sci;
 if (emit_frac) {
  char fb[16];
  int fb_n = 0;
  for (int i = 0; i < max_frac && frac > 0; i++) {
   frac *= 10;
   int d = (int) frac;
   if (d > 9) d = 9;
   fb[fb_n++] = '0' + d;
   frac -= d; }
  while (fb_n > 0 && fb[fb_n - 1] == '0') fb_n--;
  if (!sci && fb_n == 0) fb[fb_n++] = '0';      // force "X.0" for ints
  if (fb_n > 0) {
   f = gzputc(f, '.');
   for (int i = 0; i < fb_n; i++) f = gzputc(f, fb[i]); } }
 if (sci) {
  f = gzputc(f, 'e');
  if (exp < 0) f = gzputc(f, '-'), exp = -exp;
  char eb[8]; int eb_n = 0;
  if (exp == 0) eb[eb_n++] = '0';
  while (exp) eb[eb_n++] = '0' + exp % 10, exp /= 10;
  while (eb_n > 0) f = gzputc(f, eb[--eb_n]); }
 return f; }

// (feof port) — -1 if at end of stream, nil otherwise.
g_vm(g_vm_feof) {
 if (iop(Sp[0])) {
  f->io = (struct g_io*) Sp[0];
  Pack(f);
  if (!g_ok(f = zeof(f))) return gtrap(f);
  Unpack(f);
  Sp[0] = f->b ? putnum(-1) : nil; }
 return Ip++, Continue(); }

// (fgetc port) — like (getc _) but on an explicit port. Cooperative wait
// uses the port's own fd.
g_vm(g_vm_fgetc) {
 if (iop(Sp[0])) {
  struct g_io *i = (struct g_io*) Sp[0];
  if (!g_ready(getnum(i->fd))) {
   f->next_wait_fd = getnum(i->fd);
   return Ap(g_vm_yield_sw, f); }
  Pack(f);
  f->io = i;
  if (!g_ok(f = zgetc(f))) return gtrap(f);
  Unpack(f);
  Sp[0] = putnum(f->b); }
 return Ip++, Continue(); }

// (fungetc port byte) — push back one byte, return the byte.
g_vm(g_vm_fungetc) {
 if (iop(Sp[0])) {
  struct g_io *i = (struct g_io*) Sp[0];
  Pack(f);
  f->io = i;
  if (!g_ok(f = zungetc(f, getnum(f->sp[1])))) return gtrap(f);
  Unpack(f); }
 return Sp++, Ip++, Continue(); }

// Finalizer for heap stream ports: extract the fd and ask the frontend to
// close it. Runs inside GC (run_finalizers); fz->p still points at the
// from-space port so its fields are readable. Skip if fd < 0 — that means
// either the port was already closed explicitly (fd mutated to a synth
// sentinel) or the caller wrapped a non-OS fd.
static void io_close(void *p) {
 intptr_t fd = getnum(((struct g_io*)p)->fd);
 if (fd >= 0) g_fd_close(fd); }

// Heap-allocate a stream port for the given OS fd. Pushes the port pointer
// on Sp[0] and registers io_close as its finalizer. The fd >= 0 path of
// the dispatcher routes through g_fd_port_vt, so the host's read/write
// methods see this port like any other.
struct g *g_io_alloc(struct g *f, int fd) {
 uintptr_t const n = Width(struct g_io);
 if (g_ok(f = g_have(f, n + Width(struct g_tag) + Width(struct g_fz) + 1))) {
  union u *k = bump(f, n + Width(struct g_tag));
  struct g_io *io = (struct g_io*) k;
  io->ap = g_vm_port_io;
  io->fd = putnum(fd);
  io->ungetc_buf = putnum(EOF);
  io->eof_seen = putnum(false);
  *--f->sp = (word) tagthd(k, n);            // stack slot reserved by the +1 in have()
  struct g_fz *z = bump(f, Width(struct g_fz));
  z->p = k, z->fn = io_close, z->next = f->fz, f->fz = z; }
 return f; }

static struct g *grbufg(struct g *f, uintptr_t len);

// A token is a plain decimal integer iff it is [+-]?[0-9]+ with no leading-zero
// prefix (so "0x.." hex and "0.." octal stay with strtol, and bare "0" parses
// as decimal). These read at full precision through g_big_read_dec.
static g_inline bool is_dec_int(char const *s, uintptr_t n) {
 uintptr_t i = (n && (s[0] == '-' || s[0] == '+')) ? 1 : 0;
 if (i >= n) return false;                       // a lone sign is a symbol
 if (s[i] == '0' && n - i > 1) return false;     // leading zero -> let strtol decide
 for (; i < n; i++) if (s[i] < '0' || s[i] > '9') return false;
 return true; }

static struct g *gz_parse(struct g *f, bool multi);
static g_inline struct g *gzread1sym(struct g*f, int c), *gzread1str(struct g*f);
struct g *g_reads(struct g *f, struct g_io* i) { return g_core_of(f)->io = i, gz_parse(f, true); }
struct g *g_read1(struct g*f, struct g_io *i) { return g_core_of(f)->io = i, gz_parse(f, false); }

static struct g *grbufg(struct g *f, uintptr_t len) {
 if (g_ok(f = str0(f, 2 * len)))
  memcpy(txt(f->sp[0]), txt(f->sp[1]), len),
  f->sp[1] = f->sp[0],
  f->sp++;
 return f; }

static g_noinline double strtod_wrap(struct g*f, word x) {
 struct g_str *s = str(x);
 if (!strp(x) || !s->len) return NAN;
 char *e, *b = off_pool(f);
 memcpy(b, s->bytes, s->len);
 b[s->len] = 0;
 double r = strtod(b, &e);
 return e != b && *e == 0 ? (g_flo_t) r : (g_flo_t) NAN; }

// (flo s) — parse a gwen string as a decimal float. Returns a rank-0
// f64 box if the entire string parses, else nil. Used by the gwen-side
// reader in repl.g to match the C reader's strtol → strtod → intern
// cascade on float-shaped tokens.
g_vm(g_vm_flo) {
 word x = Sp[0];
 double d = strtod_wrap(f, x);
 if (d != d) return Sp[0] = nil, Ip += 1, Continue();
 uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));
 Have(req);
 struct g_vec *r = ini_scalar((struct g_vec*) Hp, G_VT_FLO);
 Hp += req;
 flo_put(r->shape, (g_flo_t) d);
 Sp[0] = word(r);
 return Ip++, Continue(); }

g_vm(g_vm_fread) {
 Ip++;
 if (!iop(Sp[0])) return Sp++, Continue();
 struct g_io *i = (struct g_io*) Sp[0];
 uintptr_t depth = topof(f) - Sp;
 Pack(f);
 if (g_ok(f = g_read1(f, i))) f->sp[2] = f->sp[0], f->sp += 2;
 else {
  struct g *c = g_core_of(f); // reset stack on parse fail
  c->sp = (word*) c + c->len - depth;
  switch (g_code_of(f)) {
   default: return gtrap(f);
   case g_status_more: c->sp[1] = c->sp[0];
   case g_status_eof: f = c, f->sp++; } }
 return Unpack(f), Continue(); }

// (string x): a charlist -> the string of those bytes; a named symbol -> its
// name string; a fixnum -> the one-byte string of its low byte. Identity on any
// other type (strings, anonymous syms, nil, ...).
g_vm(g_vm_string) {
 word x = Sp[0];
 if (nump(x)) {                                     // fixnum -> one-byte string
  uintptr_t req = str_type_width + b2w(1);
  Have(req);
  struct g_str *s = (void*) Hp;
  Hp += req;
  ini_str(s, 1);
  txt(s)[0] = (char) getnum(x);
  return Sp[0] = word(s), Ip++, Continue(); }
 if (symp(x)) {                                      // named symbol -> name string, else identity
  word y = x;
  while (symp(y) && sym(y)->nom && symp(word(sym(y)->nom))) y = word(sym(y)->nom);
  word nom = word(sym(y)->nom);
  if (nom && strp(nom)) Sp[0] = nom;
  return Ip++, Continue(); }
 if (twop(x)) {                                      // charlist -> string
  uintptr_t n = llen(x), req = str_type_width + b2w(n);
  Have(req);
  struct g_str *s = (void*) Hp;
  Hp += req;
  ini_str(s, n);
  for (uintptr_t i = 0; n--; x = B(x)) txt(s)[i++] = (char) getnum(A(x));
  return Sp[0] = word(s), Ip++, Continue(); }
 return Ip++, Continue(); }                          // any other type: identity

////
/// " the parser "
//
//
// get the next significant character from the stream. MM-protect the C
// `i` parameter across the multiple port_* calls — each push triggers a
// have() check that may GC and move heap ports.

// Comments: `;` runs to end of line; a line that *starts* with `;;;` opens a
// block comment that runs until the next line starting with `;;;` (that line is
// consumed too). `#!` (shebang) runs to end of line; a bare `#` is significant
// (the tbl reader macro), as is any other non-whitespace char. `bol` tracks the
// start of a line; it is conservatively false at entry, so a `;;;` block is only
// recognised when preceded by a newline this call has consumed (the common case).
static struct g* g_z_getc(struct g*f) {
 bool bol = false;
 while (g_ok(f = zgetc(f))) switch (f->b) {
  default: bol = false; return f;
  case '\n': case '\r': bol = true; continue;
  case 0: case ' ': case '\t': case '\f': continue;  // whitespace preserves bol
  case '#':                                          // #! is a line comment; bare # is significant
   if (!g_ok(f = zgetc(f))) return f;
   if (f->b != '!') {                                // not a shebang: push back, return #
    if ((int) f->b != EOF && !g_ok(f = zungetc(f, f->b))) return f;
    return f->b = '#', f; }
   while (g_ok(f = zeof(f)) && !f->b && g_ok(f = zgetc(f)) && f->b != '\n' && f->b != '\r');
   bol = true; continue;                             // consumed the newline -> at line start
  case ';':
   if (bol) {                                        // a line-start ;;; opens a block comment
    if (!g_ok(f = zgetc(f))) return f;               // 2nd char
    if (f->b == ';') {
     if (!g_ok(f = zgetc(f))) return f;              // 3rd char
     if (f->b == ';') {                              // ;;; : run to the next ;;;-line
      for (int n = -1; ;) {          // n = leading ; on this line (-1 = line disqualified)
       if (!g_ok(f = zgetc(f)) || (int) f->b == EOF) return f;  // unterminated -> EOF in f->b
       if (f->b == '\n' || f->b == '\r') n = 0;      // new line: count from scratch
       else if (n < 0) continue;                     // line already has a non-; prefix
       else if (f->b == ';') { if (++n == 3) break; }// closing ;;; found
       else n = -1; }                                // non-; in the leading run: disqualify
      while (g_ok(f = zgetc(f)) && f->b != '\n' && f->b != '\r' && (int) f->b != EOF);
      if (!g_ok(f) || (int) f->b == EOF) return f;   // skip the rest of the closing ;;; line
      bol = true; continue; } }
    // not ;;;: the extra char(s) read are part of the comment; if it was already the
    // line's newline (line was ";" or ";;"), the comment is done.
    if (f->b == '\n' || f->b == '\r') { bol = true; continue; } }
   while (g_ok(f = zeof(f)) && !f->b && g_ok(f = zgetc(f)) && f->b != '\n' && f->b != '\r');
   bol = true; continue; }                           // consumed the newline -> at line start
 return f; }

// --- one non-recursive reader for both g_read1 (multi=0) and g_reads (multi=1) ---
// `ctx` (kept at sp[0]) is an explicit stack of frames, top = car, so the nesting
// that used to recurse in C now lives on the gwen heap (and rides GC). A frame is
// either a *list accumulator* — a pair (head . tail) holding the elements read so
// far in source order, ((nil . nil) when empty), built in place by appending at
// `tail` so no reverse pass is needed — or a *reader-macro* — the wrap symbol \ qq
// uq uqs, recognised by symp. A finished datum is `delivered` to the top frame:
// appended to a list, or wrapped and re-delivered; with no frame left it is the
// result. Everything lives on the gwen stack so GC relocates it across the allocs
// that reading does.

static g_inline struct g *push_frame(struct g *f) {     // push an empty (head . tail) accumulator
 return gxl(gxl(g_push(f, 2, nil, nil))); }    // ctx' = ((nil . nil) . ctx)
static g_inline struct g *push_wrap(struct g *f, char const *nom) {
 return gxl(intern(g_strof(f, nom))); }        // ctx' = (wrapsym . ctx)
// recognise the `#` reader-macro wrap (interned `tbl`) so it can splice a list
// operand instead of wrapping it -- see the deliver loop in gz_parse.
static g_inline bool hashsym(word x) {
 struct g_str *s = symp(x) ? sym(x)->nom : 0;
 return s && strp(word(s)) && s->len == 3 &&
   s->bytes[0] == 't' && s->bytes[1] == 'b' && s->bytes[2] == 'l'; }

static struct g *gz_parse(struct g *f, bool multi) {
 // multi: ctx starts with one open accumulator (collects all top-level datums in
 // source order); read1: ctx starts empty (returns the first complete datum).
 f = multi ? gxl(gxl(g_push(f, 3, nil, nil, nil))) : g_push(f, 1, nil);
 for (;;) {
  if (!g_ok(f = g_z_getc(f))) return f;
  int c = f->b, c2 = EOF;
  switch (c) {
   case '(':  f = push_frame(f); continue;
   case '\'': f = push_wrap(f, "\\"); continue;
   case '`':  f = push_wrap(f, "qq"); continue;
   case '#':  f = push_wrap(f, "tbl"); continue;       // #(k v …)->(tbl k v …), #x->(tbl x)
   case ',':                                            // unquote / unquote-splice
    if (!g_ok(f = zgetc(f))) return f;
    if ((c2 = f->b) == '@') { f = push_wrap(f, "uqs"); continue; }
    if (c2 != EOF) f = zungetc(f, c2);
    f = push_wrap(f, "uq"); continue;
   case ')':
    if (nilp(f->sp[0])) return encode(g_core_of(f), g_status_eof);   // stray ) / read1
    if (symp(A(f->sp[0]))) return encode(g_core_of(f), g_status_more); // wrap wants an operand
    f = g_push(f, 1, AA(f->sp[0]));                    // d = head of the closed frame
    if (g_ok(f)) f->sp[1] = B(f->sp[1]);               // pop the closed frame
    break;                                             // -> deliver d
   case EOF:
    if (nilp(f->sp[0])) return encode(g_core_of(f), g_status_eof);
    if (!(multi && nilp(B(f->sp[0])) && !symp(A(f->sp[0]))))
     return encode(g_core_of(f), g_status_more);       // unclosed list / pending wrap
    f = g_push(f, 1, AA(f->sp[0]));                    // close the top accumulator -> its head
    if (g_ok(f)) f->sp[1] = B(f->sp[1]);
    break;
   case '"': f = gzread1str(f); break;
   default:  f = gzread1sym(f, c); break; }
  if (!g_ok(f)) return f;
  // deliver the datum at sp[0] into the frame stack at sp[1]
  for (bool done = false; g_ok(f) && !done; ) {
   if (nilp(f->sp[1])) {                               // no frame left: the result
    f->sp[1] = f->sp[0], f->sp++;
    return f; }
   if (symp(A(f->sp[1]))) {                            // reader-macro wrap, pop the wrap frame
    if (hashsym(A(f->sp[1])) && nilp(f->sp[0])) {      // #() -> (new 0): a fresh empty table
     f = gxr(g_push(f, 1, nil));                       // d (=nil=0) -> (0 . nil) = (0)
     f = gxl(intern(g_strof(f, "new")));               // (new . (0)) = (new 0)
     if (g_ok(f)) f->sp[1] = B(f->sp[1]); }            // pop wrap
    else if (hashsym(A(f->sp[1])) && twop(f->sp[0])) {
     f = gxl(g_push(f, 1, A(f->sp[1])));               // #(k v …) on a list: splice -> (tbl . d)
     if (g_ok(f)) f->sp[1] = B(f->sp[1]); }
    else {                                             // 'x `x ,x #atom -> (wrapsym d)
     f = gxr(g_push(f, 1, nil));                       // (d . nil)
     f = gxl(g_push(f, 1, g_ok(f) ? A(f->sp[1]) : nil)); // (wrapsym . (d))
     if (g_ok(f)) f->sp[1] = B(f->sp[1]); } }
   else {                                              // list: append d at the frame's tail
    f = gxr(g_push(f, 1, nil));                        // newcons = (d . nil)
    if (g_ok(f)) {
     word frame = A(f->sp[1]);                         // (head . tail)
     if (nilp(A(frame))) A(frame) = B(frame) = f->sp[0];  // first element: head = tail = newcons
     else B(B(frame)) = f->sp[0], B(frame) = f->sp[0];    // link onto tail, advance tail
     f->sp++; }                                        // pop newcons -> ctx
    done = true; } }
  if (!g_ok(f)) return f; } }

static g_inline struct g *gzread1str(struct g*f) {
 int c;
 size_t n = 0, lim = sizeof(word);
 for (f = str0(f, lim); g_ok(f); f = grbufg(f, lim), lim *= 2)
  for (; n < lim; txt(f->sp[0])[n++] = c) {
   if (!g_ok(f = zgetc(f))) return f;     // threaded; char in f->b
   else if ((c = f->b) == '"') return len(f->sp[0]) = n, f;
   else if (c == EOF) return encode(f, g_status_more);
   else if (c == '\\') {                               // escape: take next char
    if (!g_ok(f = zgetc(f))) return f;
    else if ((c = f->b) == EOF) return encode(f, g_status_more);
    else if (c == 'n') c = '\n';
    else if (c == 't') c = '\t';
    else if (c == 'r') c = '\r';
    else if (c == '0') c = '\0';
    else if (c == 'x') {                          // \xHH: two hex digits
     if (!g_ok(f = zgetc(f))) return f;
     int h1 = f->b;
     if (h1 == EOF) return encode(f, g_status_more);
     if (!g_ok(f = zgetc(f))) return f;
     int h2 = f->b;
     if (h2 == EOF) return encode(f, g_status_more);
     int v1 = h1 <= '9' ? h1 - '0' : (h1 | 0x20) - 'a' + 10;
     int v2 = h2 <= '9' ? h2 - '0' : (h2 | 0x20) - 'a' + 10;
     c = ((v1 & 0xf) << 4) | (v2 & 0xf); } } }
 return f; }



static g_inline struct g *gzread1sym(struct g*f, int c) {
 uintptr_t n = 1, lim = sizeof(intptr_t);
 if (g_ok(f = str0(f, sizeof(word))))
  for (txt((struct g_str*) f->sp[0])[0] = c; g_ok(f); f = grbufg(f, lim), lim *= 2)
   for (; n < lim; txt(f->sp[0])[n++] = c) {
    if (!g_ok(f = zgetc(f))) return f;
    switch (c = f->b) {
     default: continue;
     case ' ': case '\n': case '\t': case '\r': case '\f': case ';': case '#':
     case '(': case ')': case '"': case '\'': case '`': case ',': case 0 : case EOF:
      if (!g_ok(f = zungetc(f, c))) return f;
      struct g_str *s = str(f->sp[0]);
      txt(s)[len(s) = n] = 0; // zero terminate for strtol ; n < lim so this is safe
      // A plain decimal integer reads at full precision (fixnum / box / bignum);
      // hex/octal/float/symbol tokens keep the strtol -> strtod -> intern path.
      if (is_dec_int(txt(s), n)) return g_big_read_dec(f);
      char *e;
      long j = strtol(txt(s), &e, 0);
      if (*e == 0) {
       if (j >= FIX_MIN && j <= FIX_MAX) return f->sp[0] = putnum(j), f;
       if (g_ok(f = g_have(f, BOX_REQ))) {
        struct g_vec *b = ini_scalar(bump(f, BOX_REQ), G_VT_INT);
        box_put(b->shape, j);
        f->sp[0] = word(b); }
       return f; }
      double d = strtod(txt(s), &e);
      if (e == txt(s) || *e != 0) return intern(f);
      uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));
      if (g_ok(f = g_have(f, req))) {
       struct g_vec *r = ini_scalar(bump(f, req), G_VT_FLO);
       flo_put(r->shape, d);
       f->sp[0] = word(r); }
      return f; } }
 return f; }
