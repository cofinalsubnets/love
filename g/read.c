#include "i.h"
static double g_strtod(char const*, char**);
static struct g *flo_alloc(struct g*, g_flo_t);

////
/// " the parser "
//
//
// get the next significant character from the stream. MM-protect the C
// `i` parameter across the multiple port_* calls — each push triggers a
// have() check that may GC and move heap ports.

static struct g* g_z_getc(struct g*f) {
 while (g_ok(f = zgetc(f))) switch (f->b) {
  default: return f;
  case '#': case ';':
   while (g_ok(f = zeof(f)) && !f->b && g_ok(f = zgetc(f)) && f->b != '\n' && f->b != '\r');
  case 0: case ' ': case '\t': case '\n': case '\r': case '\f':
   continue; }
 return f; }

static struct g *grbufn(struct g *f) {
 if (g_ok(f = have(f, str_type_width + 2))) {
  union u *k = bump(f, str_type_width + 1);
  *--f->sp = word(k);
  struct g_str *o = (struct g_str*) k;
  ini_str(o, sizeof(intptr_t)); }
 return f; }

static struct g *grbufg(struct g *f) {
 if (!g_ok(f)) return f;
 size_t len = len(f->sp[0]),
        req = str_type_width + 2 * b2w(len);
 if (g_ok(f = have(f, req))) {
  struct g_str *o = bump(f, req);
  ini_str(o, 2 * len);
  memcpy(txt(o), txt(f->sp[0]), len);
  f->sp[0] = (word) o; }
 return f; }

static struct g *gzreads(struct g *f, bool nested);
static struct g *gzread1(struct g*f) {
 if (!g_ok(f = g_z_getc(f))) goto out;
 int c = f->b;
 switch (c) {
  case '(':  f = gzreads(f, true); goto out;
  case ')': case EOF:  f = encode(f, g_status_eof); goto out;
  case '\'':
   f = gzread1(f);
   if (g_code_of(f) == g_status_eof)               // quote with no operand
    f = encode(g_core_of(f), g_status_more);
   f = gxl(pushq(gxr(push0(f)))); goto out;
  case '"': {
   size_t n = 0;
   struct g_str *b = 0;
   MM(f, (g_word*) &b);
   f = grbufn(f);
   for (size_t lim = sizeof(word); g_ok(f); f = grbufg(f), lim *= 2)
    for (b = (struct g_str*) f->sp[0]; n < lim; txt(b)[n++] = c) {
     if (!g_ok(f = zgetc(f))) goto out_str;     // threaded; char in f->b
     c = f->b;
     if (c == '\\') {                               // escape: take next char
      if (!g_ok(f = zgetc(f))) goto out_str;
      if ((c = f->b) == EOF) { f = encode(f, g_status_more); goto out_str; }
      if (c == 'n') c = '\n';
      else if (c == 't') c = '\t';
      else if (c == 'r') c = '\r';
      else if (c == '0') c = '\0';
      else if (c == 'x') {                          // \xHH: two hex digits
       if (!g_ok(f = zgetc(f))) goto out_str;
       int h1 = f->b;
       if (h1 == EOF) { f = encode(f, g_status_more); goto out_str; }
       if (!g_ok(f = zgetc(f))) goto out_str;
       int h2 = f->b;
       if (h2 == EOF) { f = encode(f, g_status_more); goto out_str; }
       int v1 = h1 <= '9' ? h1 - '0' : (h1 | 0x20) - 'a' + 10;
       int v2 = h2 <= '9' ? h2 - '0' : (h2 | 0x20) - 'a' + 10;
       c = ((v1 & 0xf) << 4) | (v2 & 0xf); } }
     else if (c == EOF) { f = encode(f, g_status_more); goto out_str; }
     else if (c == '"') { len(b) = n; goto out_str; } }
out_str: UM(f); goto out; } }

 {
  uintptr_t n = 1, lim = sizeof(intptr_t);
  struct g_str *b = 0;
  MM(f, (g_word*) &b);
  if (g_ok(f = grbufn(f)))
   for (txt((struct g_str*) f->sp[0])[0] = c; g_ok(f); f = grbufg(f), lim *= 2)
    for (b = (struct g_str*) f->sp[0]; n < lim; txt(b)[n++] = c) {
     if (!g_ok(f = zgetc(f))) goto out_atom;
     switch (c = f->b) {
      default: continue;
      case ' ': case '\n': case '\t': case '\r': case '\f': case ';': case '#':
      case '(': case ')': case '"': case '\'': case 0 : case EOF:
       f = zungetc(f, c);
       if (!g_ok(f)) goto out_atom;
       b = (struct g_str*) f->sp[0];
       len(b) = n;
       txt(b)[n] = 0; // zero terminate for strtol ; n < lim so this is safe
       char *e;
       long j = strtol(txt(b), &e, 0);
       if (*e == 0) f->sp[0] = putnum(j);
       else {
        char *fe;
        double d = g_strtod(txt(b), &fe);
        if (fe != txt(b) && *fe == 0) {
         f = flo_alloc(f, d);                  // pushes box; collapse scratch slot
         if (g_ok(f)) f->sp[1] = f->sp[0], f->sp++;
        } else f = intern(f); }
       goto out_atom; } }
out_atom: UM(f); }
out: return f; }
g_vm(g_vm_str) {
 uintptr_t n = llen(Sp[0]);
 // FIXME use Have instead of Pack/Unpack
 Pack(f);
 if (!g_ok(f = str0(f, n))) return f;
 // sp[0] is the new string; sp[1] is the original charlist.
 char *t = txt(f->sp[0]);
 uintptr_t i = 0;
 for (word l = f->sp[1]; twop(l); l = B(l)) t[i++] = (char) getnum(A(l));
 f->sp[1] = f->sp[0];
 f->sp += 1;
 Unpack(f);
 Ip += 1;
 return Continue(); }
struct g *g_read1(struct g*f, struct g_io *i) {
 return g_core_of(f)->io = i, gzread1(f); }

static struct g *gzreads(struct g *f, bool nested) {
 intptr_t n = 0;
 for (int c; g_ok(f = g_z_getc(f)); n++) {
  c = f->b;
  if (c == ')') break;                          // list closed
  if (c == EOF) {                               // end of input...
   if (nested) return encode(f, g_status_more); 
   break; }                                     //  ...at top level: done
  f = zungetc(f, c);
  f = gzread1(f); }
 for (f = push0(f); n--; f = gxr(f));
 return f; }

struct g *g_reads(struct g *f, struct g_io* i, bool nested) {
 return g_core_of(f)->io = i, gzreads(f, nested); }

// Read one datum, transactionally. On g_status_more (or any non-ok
// result) the VM stack is rolled back to its pre-parse depth, so a
// deferred parse leaves no residue and the identical input can be
// re-read once more of it arrives. The depth is kept as a word count,
// not a pointer, because a collection during the parse relocates the
// stack. The input source (g_in) is untouched -- the caller manages it.
struct g *g_read(struct g *f, struct g_io *i) {
 if (!g_ok(f)) return f;
 uintptr_t depth = ((word*) f + f->len) - f->sp;
 f = g_read1(f, i);
 if (!g_ok(f)) {
  struct g *c = g_core_of(f);
  c->sp = (word*) c + c->len - depth; }
 return f; }



// Strict parse of a gwen-string's bytes as a decimal float. g_noinline +
// by-value struct return so the &e and &buf escapes stay inside this
// frame and never reach g_vm_flo, which needs to TCO out via Continue().
struct g_strtod_r { double d; bool ok; };
static g_noinline struct g_strtod_r parse_flo_strict(char const *bytes, size_t len) {
 struct g_strtod_r r = { 0, false };
 char buf[64];
 if (len == 0 || len >= sizeof buf) return r;
 memcpy(buf, bytes, len);
 buf[len] = 0;
 char *e;
 r.d = g_strtod(buf, &e);
 r.ok = e != buf && *e == 0;
 return r; }

// (flo s) — parse a gwen string as a decimal float. Returns a rank-0
// f64 box if the entire string parses, else nil. Used by the gwen-side
// reader in repl.g to match the C reader's strtol → strtod → intern
// cascade on float-shaped tokens.
g_vm(g_vm_flo) {
 word x = Sp[0];
 if (!strp(x)) { Sp[0] = nil; Ip += 1; return Continue(); }
 struct g_strtod_r p = parse_flo_strict(str(x)->bytes, str(x)->len);
 if (!p.ok) { Sp[0] = nil; Ip += 1; return Continue(); }
 uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));
 Have(req);
 struct g_vec *r = (struct g_vec*) Hp;
 Hp += req;
 r->ap = g_vm_data;
 r->typ = vec_q;
 r->type = G_VT_FLO;
 r->rank = 0;
 flo_put(r->shape, (g_flo_t) p.d);
 Sp[0] = word(r);
 Ip += 1;
 return Continue(); }

// Decimal float parser: [-+]? digits ('.' digits)? ([eE] [-+]? digits)?.
// Adequate for round-trip of literals the printer emits; not IEEE
// round-to-nearest correct. Returns 0 with *end == s when nothing was
// consumed.
static double g_strtod(char const *s, char **end) {
 char const *p = s;
 int sign = 1;
 if (*p == '-') sign = -1, p++;
 else if (*p == '+') p++;
 bool any = false;
 double v = 0;
 while ('0' <= *p && *p <= '9') v = v * 10 + (*p++ - '0'), any = true;
 if (*p == '.') {
  p++;
  double scale = 0.1;
  while ('0' <= *p && *p <= '9') v += (*p++ - '0') * scale, scale *= 0.1, any = true; }
 if (!any) { if (end) *end = (char*) s; return 0; }
 if (*p == 'e' || *p == 'E') {
  char const *q = p++;
  int esign = 1;
  if (*p == '-') esign = -1, p++;
  else if (*p == '+') p++;
  if (!('0' <= *p && *p <= '9')) p = q;                  // not a real exponent
  else {
   int e = 0;
   while ('0' <= *p && *p <= '9') e = e * 10 + (*p++ - '0');
   double scale = 1;
   while (e--) scale *= 10;
   v = esign > 0 ? v * scale : v / scale; } }
 if (end) *end = (char*) p;
 return sign * v; }

// Allocate a rank-0 G_VT_FLO g_vec wrapping v, push on Sp.
static struct g *flo_alloc(struct g *f, g_flo_t v) {
 uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));
 f = have(f, req + 1);
 if (g_ok(f)) {
  struct g_vec *r = bump(f, req);
  r->ap = g_vm_data;
  r->typ = vec_q;
  r->type = G_VT_FLO;
  r->rank = 0;
  flo_put(vec_data(r), v);
  *--f->sp = word(r); }
 return f; }
