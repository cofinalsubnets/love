#include "i.h"

static struct g *ggetc(struct g*f)  { return g_core_of(f)->io = &g_stdin, port_vt(g_stdin.fd)->getc(f); }
static struct g *gflush(struct g*f) { return g_core_of(f)->io = &g_stdout, port_vt(g_stdout.fd)->flush(f); }
static int g_dtoa(double, char*, int, int max_frac);
static struct g *gfputx(struct g *f, struct g_io *o, intptr_t x);
// --- port dispatch -------------------------------------------------------
// fd >= 0 routes through g_fd_port_vt (frontend-provided). fd <= -1 indexes
// the synthetic table. Per-port method pointers no longer live on the port
// instance; the vtable is selected by fd value.
static struct g
 *noop_getc(struct g*),
 *noop_ungetc(struct g*, int),
 *noop_eof(struct g*),
 *noop_putc(struct g*, int),
 *noop_flush(struct g*),
 *ti_getc(struct g*),
 *ti_ungetc(struct g*, int),
 *ti_eof(struct g*),
 *ci_getc(struct g*),
 *to_putc(struct g*, int),
 *to_flush(struct g*);

// No-op methods occupy unused vtable slots so dispatch needs no NULL guards.
// Misuse policy (matches existing bif behavior): reading from a write-only
// port returns EOF and latches eof_seen; writing to a read-only port
// silently discards the byte. ungetc on a write-only port ignores the
// pushed byte (subsequent reads still return EOF via noop_getc).
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
 { ci_getc,   ti_ungetc,   ti_eof,   noop_putc, noop_flush },
};

g_vm(g_vm_putc) {
 Pack(f);
 if (!g_ok(f = gputc(f, getnum(*Sp)))) return f;
 Unpack(f);
 Ip += 1;
 return Continue(); }

// (fputc port byte) — write byte to port; return byte.
g_vm(g_vm_fputc) {
 if (iop(Sp[0])) {
  struct g_io *o = (struct g_io*) Sp[0];
  Pack(f);
  f->io = o;
  if (!g_ok(f = zputc(f, getnum(f->sp[1])))) return f;
  Unpack(f); }
 Sp += 1;
 Ip += 1;
 return Continue(); }

// (fflush port) — flush; return the port.
g_vm(g_vm_fflush) {
 if (iop(Sp[0])) {
  struct g_io *o = (struct g_io*) Sp[0];
  Pack(f);
  f->io = o;
  if (!g_ok(f = zflush(f))) return f;
  Unpack(f); }
 Ip += 1;
 return Continue(); }

// (fputs port s) — write every byte of string s through port; return the
// port. No-op when args are misused (non-port or non-string). Re-reads
// Sp[1] each iteration so GC inside zputc (e.g., growing a sink buffer)
// can forward the string safely.
g_vm(g_vm_fputs) {
 if (iop(Sp[0]) && strp(Sp[1])) {
  Pack(f);
  f->io = (struct g_io*) f->sp[0];
  for (uintptr_t i = 0; g_ok(f) && i < len(f->sp[1]);)
   f = zputc(f, txt(f->sp[1])[i++]);
  if (!g_ok(f)) return f;
  Unpack(f); }
 Sp += 1;
 Ip += 1;
 return Continue(); }

g_vm(g_vm_puts) {
 if (strp(Sp[0])) {
  Pack(f);
  for (uintptr_t i = 0; i < len(f->sp[0]);) f = gputc(f, txt(f->sp[0])[i++]);
  if (!g_ok(f = gflush(f))) return f;
  Unpack(f); }
 Ip += 1;
 return Continue(); }

g_vm(g_vm_putn) {
 Pack(f);
 uintptr_t n = getnum(Sp[0]), b = getnum(Sp[1]);
 if (!g_ok(f = g_putn(f, &g_stdout, n, b))) return f;
 Unpack(f);
 Sp[1] = Sp[0];
 Sp += 1;
 Ip += 1;
 return Continue(); }

g_vm(g_vm_dot) {
 Pack(f);
 if (!g_ok(f = gfputx(f, &g_stdout, f->sp[0]))) return f;
 Unpack(f);
 Ip += 1;
 return Continue(); }

// Heap-allocate a fresh data-sink port. Bumps Width(struct to) + ttag, fills
// fields, and pushes the port pointer on Sp.
static struct g *to_alloc(struct g *f) {
 f = str0(f, 32);                          // initial buf on Sp[0]
 if (!g_ok(f)) return f;
 uintptr_t n = Width(struct to);
 if (!g_ok(f = have(f, n + Width(struct g_tag)))) return f;
 union u *k = bump(f, n + Width(struct g_tag));
 struct to *o = (struct to*) k;
 o->io.ap = g_vm_port_io;
 o->io.fd = putnum(-2);
 o->io.ungetc_buf = putnum(EOF);
 o->io.eof_seen = putnum(false);
 o->buf = (struct g_str*) f->sp[0];        // adopt the buf
 o->i = putnum(0);
 struct g_tag *t = (struct g_tag*) (k + n);
 t->null = NULL;
 t->head = k;
 f->sp[0] = (word) o;                      // replace buf slot with port
 return f; }

// Harvest the bytes written so far into a fresh exact-sized g_vec on top of
// Sp. The port stays where it was on the value stack.
static struct g *to_harvest(struct g *f, struct to *o) {
 MM(f, (g_word*) &o);
 f = str0(f, getnum(o->i));
 UM(f);
 if (!g_ok(f)) return f;
 memcpy(txt(f->sp[0]), txt(o->buf), getnum(o->i));
 return f; }

static struct g*gzputc(struct g*f, int c) { return g_ok(f) ? port_vt(f->io->fd)->putc(f, c) : f; }

static struct g*gzputn(struct g *f, intptr_t n, uint8_t b) {
 uintptr_t
  m = n >= 0 || b != 10 ? (uintptr_t) n : (f = gzputc(f, '-'), -(uintptr_t) n),
  q = m / b,
  r = m % b;
 if (q) f = gzputn(f, q, b);
 return gzputc(f, g_digits[r]); }

struct g *g_putn(struct g *f, struct g_io *o, intptr_t n, uint8_t b) {
 g_core_of(f)->io = o;
 return gzputn(f, n, b); }

static struct g*gvzprintf(struct g*f, char const *fmt, va_list xs) {
 for (int c; (c = *fmt++);) {
  if (c != '%') f = gzputc(f, c);
  else pass: switch ((c = *fmt++)) {
   case 0: goto out;
   case 'l': goto pass;
   case 'b': f = gzputn(f, va_arg(xs, uintptr_t), 2); continue;
   case 'o': f = gzputn(f, va_arg(xs, uintptr_t), 8); continue;
   case 'd': f = gzputn(f, va_arg(xs, uintptr_t), 10); continue;
   case 'x': f = gzputn(f, va_arg(xs, uintptr_t), 16); continue;
   default: f = gzputc(f, c); } } out:
 return f; }


static struct g *gzprintf(struct g *f, char const *fmt, ...) {
 va_list xs;
 va_start(xs, fmt);
 f = gvzprintf(f, fmt, xs);
 va_end(xs);
 return f; }

static struct g *gzputx(struct g *f, intptr_t x);

static g_inline struct g*gzput_two(struct g*f, word x) {
 MM(f, &x);
 struct g_str *n;
 if (symp(A(x)) && (n = sym(A(x))->nom) && len(n) == 1 && txt(n)[0] == '`' && twop(B(x))) {
   f = gzputc(f, '\'');
   f = gzputx(f, AB(x));
   goto out; }
 for (f = gzputc(f, '(');; f = gzputc(f, ' '), x = B(x)) {
  f = gzputx(f, A(x));
  if (!twop(B(x))) { f = gzputc(f, ')'); goto out; } }
out: return UM(f), f; }


static g_inline struct g*gzput_vec(struct g*f, word x) {
 MM(f, &x);
 if (vec(x)->rank == 0 && vec(x)->type == G_VT_FLO) {
  char buf[32];
  // 7 sig digits is enough for round-trip on f32; 15 for f64.
  int max_frac = sizeof(g_flo_t) == 4 ? 7 : 15;
  int n = g_dtoa((double) flo_get(x), buf, (int) sizeof buf, max_frac);
  for (int i = 0; g_ok(f) && i < n; i++) f = gzputc(f, buf[i]);
  return UM(f), f; }
 uintptr_t type = vec(x)->type, rank = vec(x)->rank;
 f = gzprintf(f, "#vec@%x:%d.%d", vec(x), type, rank);
 for (uintptr_t i = 0; i < rank && g_ok(f); i++)
  f = gzprintf(f, ".%d", (intptr_t) vec(x)->shape[i]);
 return UM(f), f; }

static g_inline struct g*gzput_str(struct g*f, word x) {
 MM(f, &x);
 uintptr_t slen = len(x);
 f = gzputc(f, '"');
 for (uintptr_t i = 0; g_ok(f) && i < slen; i++) {
  char c = txt(x)[i];
  if (c == '\\' || c == '"') f = gzputc(f, '\\');
  else if (c == '\n') f = gzputc(f, '\\'), c = 'n';
  else if (c == '\t') f = gzputc(f, '\\'), c = 't';
  else if (c == '\r') f = gzputc(f, '\\'), c = 'r';
  else if (c == '\0') f = gzputc(f, '\\'), c = '0';
  else if ((unsigned char) c < 32) {           // other ctl bytes -> \xHH
   f = gzputc(f, '\\');
   f = gzputc(f, 'x');
   f = gzputc(f, g_digits[(c >> 4) & 0xf]);
   c = g_digits[c & 0xf]; }
  f = gzputc(f, c); }
 f = gzputc(f, '"');
 return UM(f), f; }


static g_inline struct g*gzput_sym(struct g*f, word x) {
 MM(f, &x);
 struct g_str *s = sym(x)->nom;
 if (s) {
  uintptr_t slen = len(s);
  for (uintptr_t i = 0; g_ok(f) && i < slen; i++)
   f = gzputc(f, txt(s)[i]); }
 else f = gzprintf(f, "#sym@%x", x);
 return UM(f), f; }

static g_inline struct g*gzput_tbl(struct g*f, word x) {
 return gzprintf(f, "#tab@%x:%d/%d", x, tbl(x)->len, tbl(x)->cap); }

static struct g *gzputx(struct g *f, intptr_t x) {
 if (nump(x)) return gzprintf(f, "%d", getnum(x));
 if (!datp(x)) return gzprintf(f, "#%lx", (long) x);
 switch (typ(x)) {
   default: __builtin_trap();
   case two_q: return gzput_two(f, x);
   case vec_q: return gzput_vec(f, x);
   case sym_q: return gzput_sym(f, x);
   case tbl_q: return gzput_tbl(f, x);
   case text_q: return gzput_str(f, x); } }

static struct g *gfputx(struct g *f, struct g_io *o, intptr_t x) {
 return g_core_of(f)->io = o, gzputx(f, x); }

struct g *gputx(struct g*f, word x) {
 return gfputx(f, &g_stdout, x); }

struct g *gputn(struct g*f, intptr_t n, uint8_t b) {
  return g_putn(f, &g_stdout, n, b); }



// (inspect x) -> string. Alloc a heap data-sink, gfputx x into it, harvest.
// Stack walk:
//   in:                  Sp = [x, ...]
//   after to_alloc:      Sp = [port, x, ...]
//   after gfputx:        Sp = [port, x, ...]  (slots may be forwarded)
//   after to_harvest:    Sp = [str, port, x, ...]
//   drop port and x:     Sp = [str, ...]
g_vm(g_vm_inspect) {
 Pack(f);
 if (!g_ok(f = to_alloc(f))) return f;
 if (!g_ok(f = gfputx(f, (struct g_io*) f->sp[0], f->sp[1]))) return f;
 if (!g_ok(f = to_harvest(f, (struct to*) f->sp[0]))) return f;
 f->sp[2] = f->sp[0];
 f->sp += 2;
 Unpack(f);
 Ip += 1;
 return Continue(); }

// Decimal float printer. Writes up to cap bytes into buf; returns the
// byte count written. Strategy: sign, integer part via integer math,
// then up to 15 fractional digits with trailing zeros trimmed; for very
// large or very small magnitudes, normalize to [1,10) and append eE.
static int g_dtoa(double v, char *buf, int cap, int max_frac) {
 char *p = buf, *end = buf + cap;
 if (v != v) { if (end - p >= 3) memcpy(p, "nan", 3), p += 3; return p - buf; }
 if (v < 0) { if (p < end) *p++ = '-'; v = -v; }
 if (v > 1e308) { if (end - p >= 3) memcpy(p, "inf", 3), p += 3; return p - buf; }
 int exp = 0;
 bool sci = false;
 if (v != 0 && (v >= 1e16 || v < 1e-4)) {
  sci = true;
  while (v >= 10) v /= 10, exp++;
  while (v < 1)  v *= 10, exp--; }
 // integer part, lsb-first then reversed
 uint64_t ip = (uint64_t) v;
 double frac = v - (double) ip;
 char ib[24]; int ib_n = 0;
 if (ip == 0) ib[ib_n++] = '0';
 while (ip) ib[ib_n++] = '0' + ip % 10, ip /= 10;
 while (ib_n > 0) { ib_n--; if (p < end) *p++ = ib[ib_n]; }
 // fractional digits; in non-scientific mode always emit at least ".0"
 // so the result is visually distinguishable from a fixnum.
 bool emit_frac = frac > 0 || !sci;
 if (emit_frac) {
  char fb[16]; int fb_n = 0;
  if (max_frac > 15) max_frac = 15;
  for (int i = 0; i < max_frac && frac > 0; i++) {
   frac *= 10;
   int d = (int) frac;
   if (d > 9) d = 9;
   fb[fb_n++] = '0' + d;
   frac -= d; }
  while (fb_n > 0 && fb[fb_n - 1] == '0') fb_n--;
  if (!sci && fb_n == 0) fb[fb_n++] = '0';      // force "X.0" for ints
  if (fb_n > 0) {
   if (p < end) *p++ = '.';
   for (int i = 0; i < fb_n; i++) if (p < end) *p++ = fb[i]; } }
 if (sci) {
  if (p < end) *p++ = 'e';
  if (exp < 0) { if (p < end) *p++ = '-'; exp = -exp; }
  char eb[8]; int eb_n = 0;
  if (exp == 0) eb[eb_n++] = '0';
  while (exp) eb[eb_n++] = '0' + exp % 10, exp /= 10;
  while (eb_n > 0) { eb_n--; if (p < end) *p++ = eb[eb_n]; } }
 return p - buf; }

g_vm(g_vm_getc) {
 if (!g_ready(getnum(g_stdin.fd))) {
  f->next_wait_fd = getnum(g_stdin.fd);
  return Ap(g_vm_yield_sw, f); }
 Pack(f);
 if (!g_ok(f = ggetc(f))) return f;
 Unpack(f);
 Sp[0] = putnum(f->b);
 Ip += 1;
 return Continue(); }


// (fread port e) — read one datum from `port`. On success returns the
// datum. On clean EOF returns `e` (the caller-supplied sentinel). On
// g_status_more (EOF reached inside an unfinished form) returns the port
// itself — distinct from `e`, so callers like the REPL editor can tell
// "this charlist parses to nothing" apart from "this charlist is mid-form,
// keep editing." `(: read (fread in))` in boot.g recovers the old single-
// arg `read` for stdin. Misuse (non-port at Sp[0]) leaves `e` in place.
g_vm(g_vm_fread) {
 if (!iop(Sp[0])) { Sp += 1; Ip += 1; return Continue(); }
 struct g_io *i = (struct g_io*) Sp[0];
 Pack(f);
 f = g_read(f, i);
 if (g_ok(f)) {
  // Sp[0]=datum, Sp[1]=port, Sp[2]=e. Want top=datum, consume 2.
  f->sp[2] = f->sp[0];
  f->sp += 2;
 } else switch (g_code_of(f)) {
  case g_status_eof:
   f = g_core_of(f);
   f->sp += 1;                                   // pop port; top = e
   break;
  case g_status_more:
   f = g_core_of(f);
   f->sp[1] = f->sp[0];                          // e := port; pop one
   f->sp += 1;
   break;
  default: return f; }                           // propagate other errors
 Unpack(f);
 Ip += 1;
 return Continue(); }

// Heap-allocate a ci port. Expects the charlist on Sp[0]; on return Sp[0]
// holds the port (the charlist is preserved inside port->head). Same shape
// as to_alloc / g_io_alloc.
static struct g *ci_alloc(struct g *f) {
 uintptr_t n = Width(struct ci);
 if (!g_ok(f = have(f, n + Width(struct g_tag)))) return f;
 union u *k = bump(f, n + Width(struct g_tag));
 struct ci *i = (struct ci*) k;
 i->io.ap = g_vm_port_io;
 i->io.fd = putnum(-4);
 i->io.ungetc_buf = putnum(EOF);
 i->io.eof_seen = putnum(false);
 i->head = f->sp[0];
 struct g_tag *t = (struct g_tag*) (k + n);
 t->null = NULL;
 t->head = k;
 f->sp[0] = (word) i;
 return f; }
// (strin cl) — make a read-only synth port (fd=-4, ci) whose getc walks
// the charlist `cl`. The port stays live on the gwen heap and is GC-
// traced; its `head` slot is updated each getc.
g_vm(g_vm_strin) {
 Pack(f);
 if (!g_ok(f = ci_alloc(f))) return f;
 Unpack(f);
 Ip += 1;
 return Continue(); }

struct g *gputc(struct g*f, int c)  { return g_core_of(f)->io = &g_stdout, port_vt(g_stdout.fd)->putc(f, c); }
// Default fd-keyed waits. Frontends override; defaults are conservative
// (all fds always-ready; multi-source wait collapses to plain sleep) so
// frontends that don't multitask (lcat, pd) link without providing impls.
__attribute__((weak)) bool g_ready(int fd) { (void) fd; return true; }
__attribute__((weak)) void g_wait_fds(int const *fds, int n, uintptr_t ticks) {
  (void) fds; (void) n; g_sleep(ticks); }

// Default fd close is a no-op. The host overrides with close(2); kernel
// and pd don't have real OS fds to release, so the no-op is correct.
__attribute__((weak)) void g_fd_close(int fd) { (void) fd; }

struct g*gputs(struct g*f, char const*s) {
 while (*s) f = gputc(f, *s++);
 return f; }
// (feof port) — -1 if at end of stream, nil otherwise.
g_vm(g_vm_feof) {
 if (iop(Sp[0])) {
  struct g_io *i = (struct g_io*) Sp[0];
  Pack(f);
  f->io = i;
  if (!g_ok(f = zeof(f))) return f;
  Unpack(f);
  Sp[0] = f->b ? putnum(-1) : nil; }
 Ip += 1;
 return Continue(); }


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
   if (!g_ok(f = zgetc(f))) return f;
   Unpack(f);
   Sp[0] = putnum(f->b); }
 Ip += 1;
 return Continue(); }

// (fungetc port byte) — push back one byte, return the byte.
g_vm(g_vm_fungetc) {
 if (iop(Sp[0])) {
  struct g_io *i = (struct g_io*) Sp[0];
  Pack(f);
  f->io = i;
  if (!g_ok(f = zungetc(f, getnum(f->sp[1])))) return f;
  Unpack(f); }
 Sp += 1;
 Ip += 1;
 return Continue(); }

// Finalizer for heap stream ports: extract the fd and ask the frontend to
// close it. Runs inside GC (run_finalizers); fz->p still points at the
// from-space port so its fields are readable. Skip if fd < 0 — that means
// either the port was already closed explicitly (fd mutated to a synth
// sentinel) or the caller wrapped a non-OS fd.
static void io_close(void *p) {
 struct g_io *io = p;
 intptr_t fd = getnum(io->fd);
 if (fd >= 0) g_fd_close(fd); }

// Heap-allocate a stream port for the given OS fd. Pushes the port pointer
// on Sp[0] and registers io_close as its finalizer. The fd >= 0 path of
// the dispatcher routes through g_fd_port_vt, so the host's read/write
// methods see this port like any other.
struct g *g_io_alloc(struct g *f, int fd) {
 uintptr_t n = Width(struct g_io);
 if (!g_ok(f = have(f, n + Width(struct g_tag) + 1))) return f;
 union u *k = bump(f, n + Width(struct g_tag));
 struct g_io *io = (struct g_io*) k;
 io->ap = g_vm_port_io;
 io->fd = putnum(fd);
 io->ungetc_buf = putnum(EOF);
 io->eof_seen = putnum(false);
 struct g_tag *t = (struct g_tag*) (k + n);
 t->null = NULL;
 t->head = k;
 *--f->sp = (word) io;            // stack slot reserved by the +1 in have()
 // g_finalize MM-protects its `p` argument internally across its own
 // allocation, and the stack slot we just pushed will be forwarded by GC
 // if a collection happens, so Sp[0] holds the live port on return.
 return g_finalize(f, (union u*) f->sp[0], io_close); }
