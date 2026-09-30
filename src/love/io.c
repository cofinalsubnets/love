// io.c -- io. one translation unit of the runtime;
// the shared layouts and the cross-TU seam are src/love/love.h.
#include "love.h"
double am_strtod(char const*, char**);   // correctly rounded read: the printer's twin
#ifndef NAN
#define NAN (__builtin_nanf(""))
#endif
#define ai_digits "0123456789abcdefghijklmnopqrstuvwxyz"
// this file's own, forward-declared so order within it does not matter.
static ai_noinline double strtod_wrap(struct ai*g, word x);
static bool
 bio_wpending(struct ai_bio *b),
 is_dec_int(char const *s, uintptr_t n),
 is_hex_int(char const *s, uintptr_t n),
 is_oct_int(char const *s, uintptr_t n),
 lam_head(struct ai *g, word a);
static intptr_t
 ci_readn(struct ai *g, unsigned char *dst, uintptr_t n);
static struct ai
 *to_writen(struct ai *g, unsigned char const *src, uintptr_t n),
 *applyq(struct ai *g, char const *driver),
 *bio_wgrow(struct ai *g),
 *facex(struct ai *g, word x, int d),
 *io_refill(struct ai *g),
 *io_wdrain(struct ai *g, struct ai_io *i),
 *noop_flush(struct ai *g),
 *qtop(struct ai *g),
 *readonto(struct ai *g, char const *s),
 *readtext(struct ai *g, char const *s),
 *zgetc(struct ai*g),
 *zungetc(struct ai*g, int c),
 *gfputbn(struct ai *g, intptr_t n, uint8_t b, struct ai_io *o),
 *ioputn(struct ai *g, intptr_t n, uint8_t b);
static struct ai_bio *rbio_of(struct ai *g, struct ai_io *i);
static uintptr_t ci_athand(struct ai *g, uintptr_t n);
static union u *fn_unc0(union u *k);
static void io_close(struct ai *g, void *p);
// ============================================================================
// io
// ============================================================================
// the atomic-edge contract: every write can grow a backing (a GC), so an op spanning
// more than one write parks its heap operand on g->sp and re-reads it across each --
// never a raw pointer over an edge. the lam_* helpers are pure and open none.
bool iop(word x) { return evenp(x) && cell(x)->ap == lvm_port_io; }
// the port an op acts on. in/b/err are three names, not three devices: a task wearing
// its own stdio (hook 6, the chain (i o e)) reaches them through here, routed in place so
// the re-read across a GC edge finds the same port. op-level only -- ==, peek, hot? and
// the image still answer the static, since prel's tap/jug read the head by index.
word io_route(struct ai *g, word x) {
 word l = *task_io(g), s;
 if (l == ZeroPoint) return x;
 if (x == (word) &ai_stdin)       s = A(l);
 else if (x == (word) &ai_stdout) s = chainp(B(l)) ? A(B(l)) : zero;
 else if (x == (word) &ai_stderr) s = chainp(B(l)) && chainp(BB(l)) ? A(BB(l)) : zero;
 else return x;
 return iop(s) ? s : x; }
// the two doors whose port is a bio: the fd port, and the horn wearing its shape
static ai_inline bool bio_vt(struct ai_port_vt const *vt) {
 return vt == &ai_fd_port_vt || vt == &ai_horn_vt; }

// the descriptor, and the only way to it: the vt says whether there is one, so a
// port whose door is not a device answers -1 and no cast is ever taken on faith.
intptr_t ai_io_fd(struct ai_io const *i) {
 return bio_vt(i->vt) ? getcharm(((struct ai_fio const*) i)->fd) : -1; }

// --- the buffered lanes (generic, above the vt) ---
// a heap fd port is an ai_bio (love.h), dressed lazily; bio_of is the one guard, and
// nothing reads past the head without it. zgetc serves ungetc -> the pending run -> one
// readn gulp, and that order is the park law: a port holding bytes is readable however
// quiet its fd is, a dry gulp answers IoWouldBlock. a read drains pending writes first.
struct ai_bio *bio_of(struct ai *g, struct ai_io *i) {
 return bio_vt(i->vt) && in_live_pool(ai_core_of(g), (word const*) i)
      ? (struct ai_bio*) i : NULL; }

bool bio_rpending(struct ai_bio *b) {
 return b && b->rbuf && !charmp(b->rbuf) && getcharm(b->rpos) < getcharm(b->rlen); }

static ai_inline bool bio_wpending(struct ai_bio *b) {
 return b && b->wbuf && !charmp(b->wbuf) && getcharm(b->wlen) > 0; }

// the scheduler's half of the park law above: is this parked task sitting on a port already
// holding bytes? bytes live in the port, not the fd; a reader parks with Ip unadvanced, so its
// port is the top of its saved stack. the ap guard is what makes reading x legal: only these
// two ops park with a port at Sp[0]; every other parker answers false first.
bool wait_buffered(struct ai *g, lvm_t *ap, word x, int fd) {
 return (ap == lvm_fgetc || ap == lvm_await) && iop(x)
     && ai_io_fd((struct ai_io*) x) == fd
     && bio_rpending(rbio_of(g, (struct ai_io*) x)); }

// the write run outgrew its backing: double it, pending bytes and all (only
// reachable when a device took less than the whole run)
static struct ai *bio_wgrow(struct ai *g) {
 struct ai_bio *b = (struct ai_bio*) ai_core_of(g)->io;
 uintptr_t n = getcharm(b->wlen), cap = len(str(b->wbuf));
 if (!ai_ok(g = str0(g, cap ? cap * 2 : ai_iobuf))) return g;
 b = (struct ai_bio*) g->io;
 struct ai_str *nb = str(g->sp[0]);
 memcpy(txt(nb), txt(str(b->wbuf)), n);
 b->wbuf = word(nb);
 gen_wb(g, word(b), b->wbuf);
 g->sp += 1;
 return g; }

// what did not land stays pending: the run slides down to the front and the next
// drain carries it (zeroing wlen up front once dropped the tail on a mid-buffer EPIPE)
static struct ai *io_wdrain(struct ai *g, struct ai_io *i) {
 if (!ai_ok(g) || !bio_wpending(bio_of(g, i))) return g;
 struct ai_port_vt const *vt = i->vt;
 if (!vt->writen) return g;                     // no write door: the run waits for one
 for (;;) {
  struct ai_bio *b = (struct ai_bio*) i;
  uintptr_t n = getcharm(b->wlen);
  if (!n) return g;
  intptr_t k;
  avec(g, i, k = ai_core_of(g = vt->writen(g, (unsigned char*) txt(str(b->wbuf)), n))->b);
  if (!ai_ok(g)) return g;
  b = (struct ai_bio*) i;                       // writen may allocate: re-derive
  // the device is gone: drop the run -- keeping it parks a task forever
  // (close and seal wait for an empty run)
  if (k < 0) return b->wlen = putcharm(0), g;
  if (!k) return g;
  char *w = txt(str(b->wbuf));
  if ((uintptr_t) k < n) memmove(w, w + k, n - (uintptr_t) k);
  b->wlen = putcharm(n - (uintptr_t) k); } }
// io_refill's third answer, beside a byte and EOF: the device has nothing right
// now. distinct on purpose; never escapes lvm_fgetc.
#define IoWouldBlock (-2)
// the three answers for every port. no read method = end; no buffer = ask for one byte.
// which bio owns this port's read run: its own, or -- for the static input port on a seat
// that lent it one -- the borrowed one in `inport`. same fd and same vt, so every lane
// below reads it verbatim and `in` keeps the identity (== p in) that bao's `reads` folded
// at egg-compile time. the fd offset the device runs ahead of is the frontend's to rewind.
static ai_inline struct ai_bio *rbio_of(struct ai *g, struct ai_io *i) {
 struct ai_bio *b = bio_of(g, i);
 return b ? b : i == &ai_stdin.io ? (struct ai_bio*) ai_core_of(g)->inport : NULL; }

static struct ai *io_refill(struct ai *g) {                  // g is ok here: zgetc guards
 struct ai_bio *b = rbio_of(g, g->io);
 struct ai_port_vt const *vt = g->io->vt;
 if (!vt->readn) return g->b = EOF, g;
 if (!b) {                                       // no buffer: the same lane at n = 1
  unsigned char c;
  intptr_t k = vt->readn(g, &c, 1);
  if (k > 0) g->b = c;
  else if (k < 0) g->b = EOF;
  else g->b = IoWouldBlock;
  return g; }
 if (bio_wpending(b)) {                          // the crossover: our unsent ask goes first
  if (!ai_ok(g = io_wdrain(g, g->io))) return g;
  b = rbio_of(g, g->io); }
 if (!b->rbuf || charmp(b->rbuf)) {              // first buffered read: dress the backing
  if (!ai_ok(g = str0(g, ai_iobuf))) return g;
  b = rbio_of(g, g->io);                         // the GC may have moved the port
  b->rbuf = g->sp[0];
  b->rpos = b->rlen = putcharm(0);
  gen_wb(g, (word) b, b->rbuf);                  // a tenured port takes a young backing
  g->sp += 1; }
 struct ai_str *r = str(b->rbuf);
 intptr_t k = vt->readn(g, (unsigned char*) txt(r), r->len);
 if (k > 0) {
  b->rlen = putcharm(k), b->rpos = putcharm(1);
  g->b = (unsigned char) txt(r)[0];
  return g; }
 if (k < 0) return g->b = EOF, g;
 // k == 0 is "would block", the ordinary answer. never wait here: a blocking poll under
 // lvm_fgetc stops the whole VM, not the reading task. hand it back and let the caller park.
 return g->b = IoWouldBlock, g; }

static ai_inline struct ai *zgetc(struct ai*g) {
 if (!ai_ok(g)) return g;
 struct ai_io *i = g->io;
 if (getcharm(i->ungetc_buf) != EOF) {
  g->b = getcharm(i->ungetc_buf);
  i->ungetc_buf = putcharm(EOF);
  return g; }
 struct ai_bio *b = rbio_of(g, i);
 if (bio_rpending(b)) {
  uintptr_t p = getcharm(b->rpos);
  g->b = (unsigned char) txt(str(b->rbuf))[p];
  b->rpos = putcharm(p + 1);
  return g; }
 return io_refill(g); }
// the pushback is the port's, not the device's: one head word for every kind of port
static ai_inline struct ai *zungetc(struct ai*g, int c) {
 if (!ai_ok(g)) return g;
 g->io->ungetc_buf = putcharm(c);
 return g->b = c, g; }
struct ai *ioputc(struct ai*g, int c) {
 if (!ai_ok(g)) return g;
 struct ai_bio *b = bio_of(g, g->io);
 struct ai_port_vt const *vt = g->io->vt;
 if (!vt->writen) return g;                      // no write door: the byte goes nowhere
 if (!b) {                                       // no buffer: the same lane at n = 1.
  unsigned char x = (unsigned char) c;           // src is a C local, so a sink that
  if (!ai_core_of(g = vt->writen(g, &x, 1))->b && ai_ok(g))   // grows on the first ask
   g = vt->writen(g, &x, 1);                     // lands it on the second -- room now.
  return g; }
 if (!b->wbuf || charmp(b->wbuf)) {              // dress the write backing
  if (!ai_ok(g = str0(g, ai_iobuf))) return g;
  b = (struct ai_bio*) g->io;
  b->wbuf = g->sp[0];
  b->wlen = putcharm(0);
  gen_wb(g, (word) b, b->wbuf);
  g->sp += 1; }
 uintptr_t n = getcharm(b->wlen);
 if (n >= len(str(b->wbuf))) {       // a drain the device short-changed left
  if (!ai_ok(g = bio_wgrow(g))) return g;        // no room: the residue keeps its place
  b = (struct ai_bio*) g->io; }
 struct ai_str *w = str(b->wbuf);
 txt(w)[n] = (char) c;
 b->wlen = putcharm(n + 1);
 return n + 1 >= w->len ? io_wdrain(g, g->io) : g; }
// flush means try, never wait: what the device would not take stays in the write
// run and lands at the next write, at close, or through the finalizer's drain
struct ai *zflush(struct ai*g) {
 if (!ai_ok(g)) return g;
 g = io_wdrain(g, g->io);
 return ai_ok(g) ? g->io->vt->flush(g) : g; }
// the exported faces (love.h): a host nif consults/drains the read run without
// knowing the bio shape -- swig's first course rides these.
uintptr_t ai_io_pending(struct ai *g, struct ai_io *i) {
 struct ai_bio *b = rbio_of(g, i);
 return bio_rpending(b) ? (uintptr_t)(getcharm(b->rlen) - getcharm(b->rpos)) : 0; }
uintptr_t ai_io_read_drain(struct ai *g, struct ai_io *i, unsigned char *dst, uintptr_t n) {
 struct ai_bio *b = rbio_of(g, i);
 if (!bio_rpending(b)) return 0;
 uintptr_t p = getcharm(b->rpos), l = getcharm(b->rlen), k = l - p < n ? l - p : n;
 memcpy(dst, txt(str(b->rbuf)) + p, k);
 b->rpos = putcharm(p + k);
 return k; }
// `unsee` over a count: move this port's position inside the run it holds, answering how
// many bytes moved -- a short answer is the refusal and the caller's only check. n > 0
// gives back, n < 0 takes; signed because relative does not compose. rbio_of, not bio_of:
// the run borrowed under a static counts, which is what puts bytes back inside stdin's
// seek-back. it reaches only the current run, so the clamp to [0, rlen] answers what is
// really there rather than trusting n.
uintptr_t ai_io_unread(struct ai *g, struct ai_io *i, intptr_t n) {
 struct ai_bio *b = rbio_of(g, i);
 if (!b || !b->rbuf || charmp(b->rbuf)) return 0;
 uintptr_t p = getcharm(b->rpos), l = getcharm(b->rlen);
 if (n >= 0) { uintptr_t k = p < (uintptr_t) n ? p : (uintptr_t) n;
               b->rpos = putcharm(p - k); return k; }
 uintptr_t want = (uintptr_t) -n, room = l > p ? l - p : 0, k = room < want ? room : want;
 b->rpos = putcharm(p + k);
 return k; }
// (chug port): everything already readable, as one exact-length text -- the pushback byte
// if there is one, then the run. it never touches the device and never parks, so the gulp
// is: `see` the first byte (which refills and parks if it must), unsee it, chug the rest.
// "" is the ordinary answer, so a caller draws with `see` rather than spinning here.
static ai_inline struct ai *chug_str(struct ai *g, struct ai_io *i) {
 uintptr_t u = getcharm(i->ungetc_buf) != EOF ? 1 : 0;
 struct ai_port_vt const *vt = i->vt;
 g->io = i;                                   // athand reads it, as readn does
 uintptr_t n = u + (rbio_of(g, i) ? ai_io_pending(g, i)
                    : vt->athand ? vt->athand(g, ai_iobuf) : 0);
 if (!ai_ok(g = str0(g, n))) return g;
 i = g->io;                                   // str0 collects: the port may have moved
 if (n) {
  char *d = txt(g->sp[0]);
  if (u) *d = (char) getcharm(i->ungetc_buf), i->ungetc_buf = putcharm(EOF);
  // the fill splits where the count did: a bio drains its buffer, an at-hand source
  // reads its own text. never a device -- for one, athand answered 0.
  if (n - u) {
   if (rbio_of(g, i)) ai_io_read_drain(g, i, (unsigned char*) d + u, n - u);
   else vt->readn(g, (unsigned char*) d + u, n - u); } }
 return g->sp[1] = g->sp[0], g->sp += 1, g; }

// a charm is a raw fd: it holds nothing of ours, so one gulp off the row is the whole run.
// "" for a busy row as for an ended one -- `see` is what tells those apart.
ai_noinline static struct ai *chug_fd(struct ai *g, intptr_t fd) {
 unsigned char buf[ai_iobuf];
 intptr_t k = fd < 0 ? -1 : ai_fd_readn(g, (int) fd, buf, sizeof buf);
 if (!ai_ok(g = str0(g, k > 0 ? (uintptr_t) k : 0))) return g;
 if (k > 0) memcpy(txt(g->sp[0]), buf, (uintptr_t) k);
 return g->sp[1] = g->sp[0], g->sp += 1, g; }

lvm(lvm_chug) {
 if (*task_io(g) != ZeroPoint) Sp[0] = io_route(g, Sp[0]);
 if (charmp(Sp[0])) LvmCall(g, chug_fd, getcharm(Sp[0]))
 if (!iop(Sp[0])) { Sp[0] = EmptyString; ai_musttail return Next(1); }
 LvmCall(g, chug_str, (struct ai_io*) Sp[0]) }

// (inhand port): how many bytes this port holds ready -- the count `chug` would hand over.
// the borrowed run counts, so a reader can ask whether anyone else has drawn on the port
// since it last looked, which is the only way to know its own charlist is still the port's.
lvm(lvm_inhand) {
 if (*task_io(g) != ZeroPoint) Sp[0] = io_route(g, Sp[0]);
 Sp[0] = putcharm(iop(Sp[0]) ? (word) ai_io_pending(g, (struct ai_io*) Sp[0]) : 0);
 ai_musttail return Next(1); }

// (unchug port n): hand back up to n bytes of the run this port already gave out, so a
// caller that chugged more than it used leaves the rest where the port's position sees it.
// answers how many went back -- a short answer is the refusal (ai_io_unread's notes).
lvm(lvm_unchug) {
 if (*task_io(g) != ZeroPoint) Sp[0] = io_route(g, Sp[0]);
 Sp[1] = putcharm(iop(Sp[0]) && charmp(Sp[1]) && getcharm(Sp[1]) != 0
                  ? (word) ai_io_unread(g, (struct ai_io*) Sp[0],
                                           (intptr_t) getcharm(Sp[1])) : 0);
 ai_musttail return Nextp(1, 1); }

struct ai *ai_io_wflush(struct ai *g, struct ai_io *i) { return io_wdrain(g, i); }

uintptr_t ai_io_wpending(struct ai *g, struct ai_io *i) {
 struct ai_bio *b = bio_of(g, i);
 return bio_wpending(b) ? (uintptr_t) getcharm(b->wlen) : 0; }


struct ci { struct ai_io io; word head; }; // charlist input
struct to { struct ai_io io; struct ai_str *buf; word i; }; // lisp string output
static struct ai *noop_flush(struct ai *g) { return g; }

// the charlist source's read door: walks the spine, never blocks, so a spent list is the
// end. no buffer -- no syscall to amortize, and the spine is the run athand counts.
// a charm outside 0..255 lands as its low byte (test/io.l's tap section).
static uintptr_t ci_athand(struct ai *g, uintptr_t n) {
 word h = ((struct ci*) g->io)->head;
 uintptr_t k = 0;
 while (k < n && chainp(h)) k++, h = B(h);
 return k; }
static intptr_t ci_readn(struct ai *g, unsigned char *dst, uintptr_t n) {
 struct ci *i = (struct ci*) g->io;
 uintptr_t k = 0;
 while (k < n && chainp(i->head))
  dst[k++] = (unsigned char) getcharm(A(i->head)), i->head = B(i->head);
 return k ? (intptr_t) k : -1; }

// the string sink's write door: land what fits, else double and answer 0 having
// landed nothing. the grow and the copy cannot share a call: str0 collects, and
// src may be the very string being printed -- the caller re-derives and comes back.
static struct ai *to_writen(struct ai *g, unsigned char const *src, uintptr_t n) {
 struct to *o = (struct to*) g->io;
 uintptr_t i = getcharm(o->i), cap = len(o->buf);
 if (i < cap) {
  uintptr_t k = cap - i < n ? cap - i : n;
  memcpy(txt(o->buf) + i, src, k);
  o->i = putcharm(i + k);
  return g->b = (intptr_t) k, g; }
 if (!ai_ok(g = str0(g, cap ? cap * 2 : ai_iobuf))) return ai_core_of(g)->b = 0, g;
 o = (struct to*) g->io;                  // GC may have moved it; g->io is GC-traced
 struct ai_str *nb = str(g->sp[0]);
 memcpy(txt(nb), txt(o->buf), i);
 o->buf = nb;
 gen_wb(g, (word) o, (word) nb);   // a tenured string-sink takes a fresh young backing -> remember it
 g->sp++;
 return g->b = 0, g; }


struct ai_port_vt const
 ai_to_vt     = { noop_flush, to_writen, NULL,     NULL },       // a string sink: prel's `jug`
 ai_closed_vt = { noop_flush, NULL,      NULL,     NULL },       // what `close` leaves behind
 ai_ci_vt     = { noop_flush, NULL,      ci_readn, ci_athand },  // a charlist: prel's `tap`
 ai_horn_vt   = { noop_flush, ai_horn_writen, NULL, NULL };      // PCM out: the horn

// (fputc port byte) — write byte to port; return byte. a charm operand is a raw
// fd and the byte goes straight at the row -- nothing to buffer, nothing to flush.
lvm(lvm_fputc) {
 if (*task_io(g) != ZeroPoint) Sp[0] = io_route(g, Sp[0]);
 if (charmp(Sp[0])) {
  intptr_t fd = getcharm(Sp[0]);
  unsigned char c = (unsigned char) getcharm(Sp[1]);
  if (fd >= 0) ai_fd_say((int) fd, &c, 1);
  ai_musttail return Nextp(1, 1); }
 if (iop(Sp[0])) {
  g->io = (struct ai_io*) Sp[0];
  Pack(g);
  // backpressure, as in lvm_fputs -- but the drain is behind the test: draining
  // every put would turn a put loop into one write(2) per byte
  if (ai_io_wpending(g, (struct ai_io*) g->sp[0]) >= ai_iobuf) {
   g = io_wdrain(g, (struct ai_io*) g->sp[0]);
   if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g);
   if (ai_io_wpending(g, (struct ai_io*) g->sp[0]) >= ai_iobuf) {
    Unpack(g);
    g->next_wake_at = ai_clock() + 1;
    ai_musttail return Ap(lvm_yield_sw, g); } }
  if (!ai_ok(g = ioputc(g, getcharm(g->sp[1])))) ai_musttail return Ap(_lvm_ghelp, g);
  Unpack(g); }
 ai_musttail return Nextp(1, 1); }

// (fflush port): flush means deliver -- a short-answering device parks the task
// and the op re-runs (safe: a flush consumes nothing). a raw fd holds nothing of
// love's, so a charm falls through with nothing to do and answers itself.
lvm(lvm_fflush) {
 if (*task_io(g) != ZeroPoint) Sp[0] = io_route(g, Sp[0]);
 if (iop(Sp[0])) {
  g->io = (struct ai_io*) Sp[0];
  Pack(g);
  if (!ai_ok(g = zflush(g))) ai_musttail return Ap(_lvm_ghelp, g);
  if (ai_io_wpending(g, (struct ai_io*) g->sp[0])) {
   Unpack(g);
   g->next_wake_at = ai_clock() + 1;      // the write residue's poll -- see io_wdrain
   ai_musttail return Ap(lvm_yield_sw, g); }
  Unpack(g); }
 ai_musttail return Next(1); }

// (fputs port s) — write every byte of string-or-cask s; no-op on misuse. bytes_of
// re-reads each iteration so GC inside ioputc can forward it. a charm operand is a raw fd:
// ai_fd_say lands the run in one place and never touches love's heap.
lvm(lvm_fputs) {
 if (*task_io(g) != ZeroPoint) Sp[0] = io_route(g, Sp[0]);
 if (charmp(Sp[0]) && (strp(Sp[1]) || caskp(Sp[1]))) {
  intptr_t fd = getcharm(Sp[0]);
  struct ai_str *v = bytes_of(Sp[1]);
  if (fd >= 0) ai_fd_say((int) fd, (unsigned char const*) txt(v), len(v));
  ai_musttail return Nextp(1, 1); }
 if (iop(Sp[0]) && (strp(Sp[1]) || caskp(Sp[1]))) {
  g->io = (struct ai_io*) Sp[0];
  uintptr_t i = 0, l = len(bytes_of(Sp[1]));
  // the bulk lane when the port has one; a 0 makes one byte of progress through ioputc.
  // only for an empty buffer: going direct past a pending run would shuffle the stream.
  struct ai *(*wn)(struct ai*, unsigned char const*, uintptr_t) = g->io->vt->writen;
  Pack(g);
  g = io_wdrain(g, (struct ai_io*) g->sp[0]);   // buffered puts land before the bulk stroke
  // backpressure: the write run is a buffer, not a queue -- an op that would push it past
  // its own size waits for the device. the bound is one buffer plus one say.
  if (ai_ok(g) && ai_io_wpending(g, (struct ai_io*) g->sp[0]) >= ai_iobuf) {
   Unpack(g);
   g->next_wake_at = ai_clock() + 1;            // the write residue's poll -- see io_wdrain
   ai_musttail return Ap(lvm_yield_sw, g); }
  while (ai_ok(g) && i < l) {
   intptr_t k = wn && !bio_wpending(bio_of(g, (struct ai_io*) g->sp[0]))
              ? ai_core_of(g = wn(g, (unsigned char const*) txt(bytes_of(g->sp[1])) + i, l - i))->b : 0;
   if (k > 0) i += (uintptr_t) k;
   else g = ioputc(g, txt(bytes_of(g->sp[1]))[i++]); }
  if (!ai_ok(g = zflush(g))) ai_musttail return Ap(_lvm_ghelp, g);
  Unpack(g); }
 ai_musttail return Nextp(1, 1); }

static struct ai*gfputbn(struct ai *g, intptr_t n, uint8_t b, struct ai_io *o);
lvm(lvm_fputbn) {
 if (*task_io(g) != ZeroPoint) Sp[0] = io_route(g, Sp[0]);
 if (!charmp(Sp[2]) || getcharm(Sp[2]) < 2 || getcharm(Sp[2]) > 36) {   // a base the digits spell
  Sp[2] = ZeroPoint; ai_musttail return Nextp(1, 2); }
 if (iop(Sp[0])) {
   Pack(g);
   g = gfputbn(g, getcharm(Sp[1]), getcharm(Sp[2]), (struct ai_io*) Sp[0]);
   if (!ai_ok(g)) ai_musttail return Ap(_lvm_ghelp, g);
   Unpack(g);
   Sp[2] = Sp[1]; }
 ai_musttail return Nextp(1, 2); }

struct ai*ioputs(struct ai*g, char const *s) {
 while (*s) g = ioputc(g, *s++);
 return g; }

static struct ai*ioputn(struct ai *g, intptr_t n, uint8_t b) {
 uintptr_t
  m = n >= 0 || b != 10 ? (uintptr_t) n : (g = ioputc(g, '-'), -(uintptr_t) n),
  q = m / b,
  r = m % b;
 if (q) g = ioputn(g, q, b);
 return ioputc(g, ai_digits[r]); }

// the terminal scare face's floor: post.l is the printer proper, but by here the VM has
// stopped and there is nobody to run it. this spells the shapes a condition wears -- name,
// text, number, list -- and hands every other kind its address. no allocation, so it is
// safe on an exhausted heap.
static struct ai *facex(struct ai *g, word x, int d) {
 if (charmp(x)) return ioputn(g, getcharm(x), 10);
 if (x == ZeroPoint) return ioputs(g, "()");
 struct ai_str *nm = nom_str(g, x);
 if (!nm && datp(x) && typ(x) == DNom) nm = str(nom(x)->name);
 if (nm) { for (uintptr_t i = 0; ai_ok(g) && i < len(nm); i++) g = ioputc(g, txt(nm)[i]);
           return g; }
 if (datp(x) && typ(x) == DString) {
  g = ioputc(g, '"');
  for (uintptr_t i = 0, n = len(x); ai_ok(g) && i < n; i++) g = ioputc(g, txt(x)[i]);
  return ioputc(g, '"'); }
 if (chainp(x) && d < 4) {                        // bounded: a cyclic condition must not spin
  for (g = ioputc(g, '(');; g = ioputc(g, ' '), x = B(x)) {
   g = facex(g, A(x), d + 1);
   if (!chainp(B(x))) return ioputc(g, ')'); } }
 return ioputn(ioputc(g, '\\'), (intptr_t) x, 36); }

// the terminal scare face (love.h): stashed condition data prints ";; a b" on err;
// the bare scare (oom) prints ";; oom@len=N". best-effort. N is the MAIN POOL's length
// in words -- what the heap had, not what the refused allocation asked for. reading it
// as the ask sends you hunting an oversized request when the story is usually the pool.
void ai_scare_face(struct ai *g) {
 if (!(g = ai_core_of(g))) return;
 g->io = &ai_stderr.io;
 if (zerop(g->scare_a) && zerop(g->scare_b)) {
  g = ioputs(g, ";; oom@len=");
  if (ai_ok(g)) g = ioputn(g, (intptr_t) g->len, 10); }
 else {
  g = ioputs(g, ";; ");
  if (ai_ok(g)) g = facex(g, g->scare_a, 0);
  g = ioputc(g, ' ');
  if (ai_ok(g)) g = facex(g, g->scare_b, 0); }
 g = ioputc(g, '\n');
 zflush(g); }

static ai_inline struct ai*gfputbn(struct ai *g, intptr_t n, uint8_t b, struct ai_io *o) {
 return g->io = o, ioputn(g, n, b); }

// --- partial-application introspection ---
// a partial-app closure is a thread headed lvm_unc (or [lvm_cur n][lvm_unc …]);
// each unc cell holds a captured arg at [1] and a link at [2], so the base value
// is terminal_link-2 and the args are the chain of [1] fields, newest first.
bool fn_partialp(union u *k) {
 return k[0].ap == lvm_unc || (k[0].ap == lvm_cur && k[2].ap == lvm_unc); }
static ai_inline union u *fn_unc0(union u *k) {
 return k[0].ap == lvm_cur ? k + 2 : k; }       // first unc cell
union u *fn_base(union u *k, int *nargs) { // base value + captured-arg count
 union u *u = fn_unc0(k), *link;
 int n = 0;
 for (;;) { link = u[2].m; n++; if (link[0].ap != lvm_unc) break; u = link; }
 return *nargs = n, link - 2; }
word fn_arg(union u *k, int i, int nargs) { // i-th arg in application order
 union u *u = fn_unc0(k);
 for (int w = nargs - 1 - i; w > 0; w--) u = u[2].m;
 return u[1].x; }
// what `=` and the hash read a function value as: a native is its bytecode twin (the code
// is a copy of it, at an address of its own), anything else itself. a native is the one
// cell whose code word is the arena's and repeats in the header one word ahead of the value
// (map.c's nifx), and a twin may be a native again -- a lane that wraps another's answer --
// so this unwraps to the bytecode. x may be any word a thread holds, a return address into
// the middle of another included, so it is read at the value and never walked
word fn_meaning(struct ai *c, word x) {
 while (evenp(x) && in_heap(c, x)) {
  union u *k = cell(x), *cd = k[0].ap == lvm_cur ? k + 2 : k;
  lvm_t *e = cd[0].ap == lvm_lazy ? k[-1].ap : cd[0].ap;      // a woken entry, its chunk unseated
  if ((e != lvm_deferfwd && !code_in(c, (uintptr_t) e)) || k[-1].ap != e) break;   // or a deferred one that declined
  x = cd[1].x; }
 return x; }
// the threads that are carriers, not code: a tablet's two halves, a cask, a coin, a port.
// they are what they are by identity, never by their words
bool fn_carrier(union u *k) {
 return k[0].ap == lvm_map_lookup || k[0].ap == lvm_map_data || k[0].ap == lvm_cask
     || k[0].ap == lvm_coin || k[0].ap == lvm_port_io; }

// in_heap: the main pool or the major pool (tenured objects live there). the two are
// independent mallocs, the major above or below, so each range is tested
bool in_heap(struct ai *c, word x) {
 return (ptr(x) >= ptr(c) && ptr(x) < ptr(c) + c->len) || (ptr(x) >= c->major_base && ptr(x) < c->major_hp); }

// (nifnom f): a nif's roster spelling, or (). the book cannot answer this: two
// names can share one nif value (. and ><, peep and ->), and def1 is which of
// them is the name. the printer's other C-only question.
lvm(lvm_nifnom) {
 char const *nm = ai_nif_name(Sp[0]);
 if (!nm) ai_musttail return Answer(ZeroPoint);
 uintptr_t n = strlen(nm);
 Have(str_width(n));
 struct ai_str *s = ini_str(str(Hp), n); Hp += str_width(n);
 memcpy(txt(s), nm, n);
 ai_musttail return Answer(word(s)); }

static ai_inline bool lam_head(struct ai *g, word a) {        // is a the symbol \ ?
 struct ai_str *nm;                                          // a named sym (name . mint); nom_str is 0 for a bare mint / the core
 return (nm = nom_str(g, a)) && len(nm) == 1 && txt(nm)[0] == '\\'; }

bool lam_isp(struct ai *g, word x) {         // (\ b.. body): >=2 operands
 return chainp(x) && lam_head(g, A(x)) && chainp(B(x)) && chainp(BB(x)); }
// (fgetc port): a non-port reads as an already-empty stream (EOF), so a read-until-(-1)
// loop over a misused port is bounded. a charm is a raw fd, read a byte at a time off the
// row: no pushback of its own, and a busy row parks the task exactly as a port's would.
lvm(lvm_fgetc) {
 if (*task_io(g) != ZeroPoint) Sp[0] = io_route(g, Sp[0]);
 if (charmp(Sp[0])) {
  intptr_t fd = getcharm(Sp[0]);
  unsigned char c;
  intptr_t k;
  Pack(g); k = fd < 0 ? -1 : ai_fd_readn(g, (int) fd, &c, 1); Unpack(g);
  if (!k) { g->next_wait_fd = fd; ai_musttail return Ap(lvm_yield_sw, g); }
  Sp[0] = putcharm(k > 0 ? (word) c : EOF);
  ai_musttail return Next(1); }
 if (iop(Sp[0])) {
  struct ai_io *i = (struct ai_io*) Sp[0];
  struct ai_bio *bb = bio_of(g, i);
  if (bio_wpending(bb)) {                 // our unsent ask goes out before we wait for the answer
   g->io = i;
   Pack(g);
   if (!ai_ok(g = io_wdrain(g, i))) ai_musttail return Ap(_lvm_ghelp, g);
   Unpack(g); }
  // no readiness pre-guard: zgetc already makes that test, and asking first
  // lied on the kernel (reading an output fd parked forever where it now reads
  // the end). cue?/await still ask -- they have no read to answer them.
  Pack(g);
  g->io = i;
  if (!ai_ok(g = zgetc(g))) ai_musttail return Ap(_lvm_ghelp, g);
  Unpack(g);
  if (g->b == IoWouldBlock) {          // the refill raced and lost -- park, don't spin
   g->next_wait_fd = ai_io_fd((struct ai_io*) Sp[0]);   // re-read: the gc may have moved it
   ai_musttail return Ap(lvm_yield_sw, g); }
  Sp[0] = putcharm(g->b); }
 else Sp[0] = putcharm(EOF);
 ai_musttail return Next(1); }

// (await port): cooperatively park until the port's fd is readable, then return
// the port (so it chains into a read) -- for fds you can't drain a byte at a time
// (signalfd, timerfd). Ip is unadvanced, so the task re-checks on reschedule.
lvm(lvm_await) {
 if (*task_io(g) != ZeroPoint) Sp[0] = io_route(g, Sp[0]);   // and the routed port is what it answers -- the read that chains off it lands there too
 if (iop(Sp[0])) {
  intptr_t fd = ai_io_fd((struct ai_io*) Sp[0]);
  // the buffer counts: a port holding bytes is readable however quiet its fd is
  if (fd >= 0 && !bio_rpending(rbio_of(g, (struct ai_io*) Sp[0])) && !ai_ready(fd, ai_wait_in)) {
   g->next_wait_fd = fd;
   ai_musttail return Ap(lvm_yield_sw, g); } }
 ai_musttail return Next(1); }

// (fungetc port byte) — push back one byte, return the byte.
lvm(lvm_fungetc) {
 if (*task_io(g) != ZeroPoint) Sp[0] = io_route(g, Sp[0]);
 if (iop(Sp[0])) {
  struct ai_io *i = (struct ai_io*) Sp[0];
  Pack(g);
  g->io = i;
  if (!ai_ok(g = zungetc(g, getcharm(g->sp[1])))) ai_musttail return Ap(_lvm_ghelp, g);
  Unpack(g); }
 ai_musttail return Nextp(1, 1); }

// heap-port finalizer: runs inside GC (from-space readable); fd < 0 means
// already closed or a non-OS fd
void io_close(struct ai *g, void *p) {
 struct ai_bio *b = p;                         // every finalized port is a bio (ai_io_alloc made it)
 intptr_t fd = ai_io_fd(&b->f.io);
 if (fd < 0) return;
 if (b->wbuf && !charmp(b->wbuf) && getcharm(b->wlen) > 0) // unflushed bytes ride out raw --
  ai_fd_drain((int) fd, txt(str(b->wbuf)), (uintptr_t) getcharm(b->wlen));   // from-space is readable here
 ai_fd_close(fd); }

// heap-allocate a stream port for an OS fd: push it on Sp[0], register io_close
ai_noinline struct ai *ai_io_alloc(struct ai *g, int fd) {
 uintptr_t const n = Width(struct ai_bio);     // a heap fd port carries the buffer lanes (love.h)
 if (ai_ok(g = ai_have(g, n + Width(struct ai_tag) + Width(struct ai_fz) + 1))) {
  union u *k = bump(g, n + Width(struct ai_tag));
  struct ai_bio *io = (struct ai_bio*) k;
  io->f.io.ap = lvm_port_io;
  io->f.io.vt = &ai_fd_port_vt;
  io->f.io.ungetc_buf = putcharm(EOF);
  io->f.fd = putcharm(fd);
  io->rbuf = io->wbuf = 0;                     // never dressed (io_refill/ioputc dress lazily)
  io->rpos = io->rlen = io->wlen = putcharm(0);
  *--g->sp = (word) tagthread(k, n);            // stack slot reserved by the +1 in have()
  struct ai_fz *z = bump(g, Width(struct ai_fz));
  z->p = k, z->fn = io_close, z->next = g->fz, g->fz = z; }
 return g; }

// a token is a plain decimal integer iff it is [+-]?[0-9]+ with no leading-zero
// prefix (a leading zero is octal's prefix; bare "0" parses as decimal).
static ai_inline bool is_dec_int(char const *s, uintptr_t n) {
 uintptr_t i = (n && (s[0] == '-' || s[0] == '+')) ? 1 : 0;
 if (i >= n) return false;                       // a lone sign is a symbol
 if (s[i] == '0' && n - i > 1) return false;     // leading zero -> octal's, below
 for (; i < n; i++) if (s[i] < '0' || s[i] > '9') return false;
 return true; }

// ..a hex integer iff it is [+-]?0[xX][0-9a-fA-F]+ -- at least one digit, so a
// bare "0x" stays an honest symbol..
static ai_inline bool is_hex_int(char const *s, uintptr_t n) {
 uintptr_t i = (n && (s[0] == '-' || s[0] == '+')) ? 1 : 0;
 if (n - i < 3 || s[i] != '0' || (s[i+1] | 32) != 'x') return false;
 for (i += 2; i < n; i++)
  if (!((s[i] >= '0' && s[i] <= '9') || ((s[i] | 32) >= 'a' && (s[i] | 32) <= 'f'))) return false;
 return true; }

// ..and octal iff [+-]?0[0-7]+ ("08" keeps the strtod -> intern path). all three read at
// full precision through ai_big_read_*, so a literal is fixnum / box / bignum by its
// value -- strtol overflowed differently per libc and read one source three ways.
static ai_inline bool is_oct_int(char const *s, uintptr_t n) {
 uintptr_t i = (n && (s[0] == '-' || s[0] == '+')) ? 1 : 0;
 if (n - i < 2 || s[i] != '0') return false;
 for (i += 1; i < n; i++) if (s[i] < '0' || s[i] > '7') return false;
 return true; }

struct ai *grbufg(struct ai *g, uintptr_t len) {
 if (ai_ok(g = str0(g, 2 * len)))
  memcpy(txt(g->sp[0]), txt(g->sp[1]), len),
  g->sp[1] = g->sp[0],
  g->sp++;
 return g; }

static ai_noinline double strtod_wrap(struct ai*g, word x) {
 struct ai_str *s = str(x);
 if (!strp(x) || !s->len) return NAN;
 word *top;
 char *e, *b = (char*) ai_gap(g, &top);
 if (s->len >= (uintptr_t) ((char*) top - b)) return NAN;
 memcpy(b, s->bytes, s->len);
 b[s->len] = 0;
 double r = am_strtod(b, &e);
 return e != b && *e == 0 ? (ai_flo_t) r : (ai_flo_t) NAN; }

// (gem s): parse a string as a decimal float -> a box if the whole string parses,
// else zero (the l-side reader's twin of the C cascade)
lvm(lvm_gem) {
 word x = Sp[0];
 double d = strtod_wrap(g, x);
 if (d != d) ai_musttail return Answer(zero);
 Have(gem_req);
 Sp[0] = mk_gem(&Hp, (ai_flo_t) d);
 ai_musttail return Next(1); }

// (string x): a charlist -> the string of those bytes; a named symbol -> its
// name string; a fixnum -> the one-byte string of its low byte. identity on any
// other type (strings, anonymous syms, zero, ...).
lvm(lvm_string) {
 word x = Sp[0];
 if (charmp(x)) {                                     // fixnum -> one-byte string
  uintptr_t req = str_width(1);
  Have(req);
  struct ai_str *s = (void*) Hp;
  Hp += req;
  ini_str(s, 1);
  txt(s)[0] = (char) getcharm(x);
  ai_musttail return Answer(word(s)); }
 if (nomp(x)) {                                      // a named symbol (name . mint) -> its name string; a bare point -> identity
  struct ai_str *nm = nom_str(g, x);
  Sp[0] = nm ? word(nm) : word(EmptyString);
  ai_musttail return Next(1); }
 if (chainp(x)) {                                      // charlist -> string
  uintptr_t n = llen(x), req = str_width(n);
  Have(req);
  struct ai_str *s = (void*) Hp;
  Hp += req;
  ini_str(s, n);
  for (uintptr_t i = 0; n--; x = B(x)) txt(s)[i++] = (char) getcharm(A(x));
  ai_musttail return Answer(word(s)); }
 if (caskp(x)) {                                      // a cask -> a fresh string copy of its bytes
  uintptr_t n = len(cask(x)->str), req = str_width(n);
  Have(req);
  struct ai_str *src = cask(Sp[0])->str, *s = (void*) Hp;
  Hp += req;
  ini_str(s, n);
  memcpy(txt(s), txt(src), n);
  ai_musttail return Answer(word(s)); }
 // `string` answers a string: a string is the only identity, every other kind coerces
 // through hook 7. px reaches `string` on chains and noms only, so show cannot recur.
 if (x == ZeroPoint) { Sp[0] = word(EmptyString); ai_musttail return Next(1); }   // the empty charlist
 if (strp(x) || !evenp(g->hot_show)) ai_musttail return Next(1);   // ..or the boot window, where identity stands
 Have(2);                                               // the drive grows Sp by two
 { word *dst = Sp - 2;                                  // [x show ret] -- callout_drive's 1-arg shape
   dst[0] = Sp[0], dst[1] = g->hot_show, dst[2] = word(Ip + 1);
   Sp = dst; Ip = (union u*) callout_drive; }
 ai_musttail return Continue(); }

////
/// " the reader "
//
// sound: one datum off a charlist -> (datum . residue), () at a clean end, `torn` where the
// text ran out inside a shape. test/host/p1.l is the same grammar in love, and
// test/host/rdiff.l holds the two readers to each other over the tree.
//
// a state machine the vm runs. each state in rd_k is an lvm_ that hands the stack to a C
// helper, and the helper leaves the next state in g->ip. the reader's state is love data on
// the stack, so a collection moves it and a deep form costs heap, never C stack:
//   sp[0..4]  the registers: the position, the promises forced so far, the height of the
//             open pile, a finished datum on its way out, and the text when it is a string --
//             read in place, its positions charms, and laid down as cells only for a residue
//   then the pile -- the open list's datums, newest first -- its frame's header, and under
//   that the enclosing pile and frame, down to the base frame, the ip to answer to, and the
//   argument's slot. the entry is an op like any other, which the compiler may lay inline:
//   it answers where the next instruction is, never through a return on the stack. a header
//   is a charm, the frame's kind with the enclosing pile's height above it; a mono frame
//   keeps its operator under its header.
// a tail may be a promise. a helper that meets one it has not forced hands it to the vm
// (rd_call) and is run again from the last position it committed; the answer waits in
// the memo, so a walk can always start over.
enum { RdCur, RdMemo, RdCnt, RdVal, RdSrc, RdRegs };
enum { RkOne, RkAll, RkParen, RkList, RkHash, RkTuple, RkQuote, RkLift, RkMono };
enum { RsStart, RsRead, RsClose, RsDatum, RsAll };
#define RdHdr(k, n) putcharm((k) | (intptr_t) (n) << 4)
#define RdKind(h) ((int) (getcharm(h) & 15))
#define RdUnder(h) ((uintptr_t) getcharm(h) >> 4)
#define RdGo(s) (g->ip = (union u*) (rd_k + (s)), g)
// what every state reserves before it reads a register: a frame, a call, a wrap's conses
#define RdSlack 32

// the char classes: whitespace, an operator char, the end of a name-led token, the
// openers and closers, a numeral's sign, where a glued run stops, a digit.
// 12 is form feed, spelled as a number here as in the love it was ported from
enum { RcWs = 1, RcOp = 2, RcEnd = 4, RcOpen = 8, RcClose = 16, RcSign = 32, RcStop = 64, RcDig = 128 };
#define RcW (RcWs | RcEnd | RcStop)
#define RcO (RcEnd | RcOpen)
#define RcC (RcEnd | RcClose | RcStop)
static unsigned char const rd_cls[257] = {
 ['\t'] = RcW, ['\n'] = RcW, [12] = RcW, ['\r'] = RcW, [' '] = RcW,
 ['"'] = RcEnd, [','] = RcEnd, [';'] = RcEnd | RcStop, ['#'] = RcOp | RcEnd,
 ['('] = RcO, ['['] = RcO, ['{'] = RcO, [')'] = RcC, [']'] = RcC, ['}'] = RcC,
 ['+'] = RcOp | RcSign, ['-'] = RcOp | RcSign,
 ['!'] = RcOp, ['$'] = RcOp, ['%'] = RcOp, ['&'] = RcOp, ['*'] = RcOp, ['.'] = RcOp,
 ['/'] = RcOp, [':'] = RcOp, ['<'] = RcOp, ['='] = RcOp, ['>'] = RcOp, ['?'] = RcOp,
 ['@'] = RcOp, ['\\'] = RcOp, ['^'] = RcOp, ['|'] = RcOp, ['~'] = RcOp,
 ['0'] = RcDig, ['1'] = RcDig, ['2'] = RcDig, ['3'] = RcDig, ['4'] = RcDig,
 ['5'] = RcDig, ['6'] = RcDig, ['7'] = RcDig, ['8'] = RcDig, ['9'] = RcDig };

static lvm(lvm_rd_start); static lvm(lvm_rd_read); static lvm(lvm_rd_close);
static lvm(lvm_rd_datum); static lvm(lvm_rd_all); static lvm(lvm_rd_called);
static union u const
 rd_k[] = { {lvm_rd_start}, {lvm_rd_read}, {lvm_rd_close}, {lvm_rd_datum}, {lvm_rd_all} },
 rd_call_k[] = { {lvm_ap}, {lvm_rd_called} },
 rd_reads_k[] = { {lvm_sounds}, {lvm_ret0} };   // the boot's, the same run as the nif's

// a position's char: 256 for a cell that holds no byte (a name's, to every class), -1 at
// the end. a charm is an index into the string src; () is src when there is none
static ai_inline intptr_t rd_at(word src, word p) {
 if (charmp(p))
  return src != ZeroPoint && (uintptr_t) getcharm(p) < len(str(src)) ? (unsigned char) txt(str(src))[getcharm(p)] : -1;
 if (!chainp(p)) return -1;
 word c = A(p);
 return charmp(c) && (uintptr_t) getcharm(c) < 256 ? getcharm(c) : 256; }
static ai_inline unsigned rd_c(word src, word p) { intptr_t c = rd_at(src, p); return c < 0 ? 0 : rd_cls[c]; }
// what a position lays into a text: its byte, or a cell's own value, whose low byte it keeps
static ai_inline intptr_t rd_raw(word src, word p) {
 return charmp(p) ? (unsigned char) txt(str(src))[getcharm(p)] : getcharm(A(p)); }
static ai_inline char rd_byte(word src, word p) { return (char) rd_raw(src, p); }
static ai_inline bool rd_glued(word src, word p) { return rd_at(src, p) >= 0 && !(rd_c(src, p) & RcStop); }
static ai_inline intptr_t rd_low(intptr_t c) { return c >= 'A' && c <= 'Z' ? c + 32 : c; }
static ai_inline bool rd_hex(intptr_t c) {
 return (c >= '0' && c <= '9') || (rd_low(c) >= 'a' && rd_low(c) <= 'f'); }
static ai_inline intptr_t rd_dval(intptr_t c) { return c >= '0' && c <= '9' ? c - '0' : rd_low(c) - 87; }

// a promise: lit?'s upper segment of the lattice, which is what a tail gets called for.
// the slow halves stay out of line: every step of every walk inlines the fast ones
static ai_noinline bool rd_hot(word x) { return evenp(x) && !coinp(x) && ai_kind(x) >= KTablet; }
static ai_inline bool rd_lit(word x) { return evenp(x) && !chainp(x) && x != ZeroPoint && rd_hot(x); }
static ai_noinline word rd_memo(word memo, word t) {
 if (!rd_hot(t)) return t;
 for (; chainp(memo); memo = B(memo)) if (AA(memo) == t) return BA(memo);
 return t; }
// the position after a cell: its tail, or a forced promise's answer out of the memo. one
// not forced yet comes back as itself, for the caller to hand to rd_call
static ai_inline word rd_next(word memo, word p) {
 if (charmp(p)) return putcharm(getcharm(p) + 1);
 word t = B(p);
 return chainp(t) || t == ZeroPoint ? t : rd_memo(memo, t); }

// a string's positions hold no promise, so its walks are byte loops
static ai_inline bool rd_in(word src, word p) { return charmp(p) && src != ZeroPoint; }
static ai_noinline uintptr_t rd_sskip(struct ai_str const *s, uintptr_t i) {
 unsigned char const *t = (unsigned char const*) txt(s);
 uintptr_t const n = len(s);
 while (i < n) {
  unsigned const c = t[i];
  if (rd_cls[c] & RcWs) { i++; continue; }
  if (c == '#' ? i + 1 >= n || t[i + 1] != '!' : c != ';') break;
  for (i += c == '#' ? 2 : 1; i < n && t[i] != '\n' && t[i] != '\r'; i++);
  i += i < n; }
 return i; }
static ai_noinline uintptr_t rd_send(struct ai_str const *s, uintptr_t i) {
 unsigned char const *t = (unsigned char const*) txt(s);
 while (i < len(s) && !(rd_cls[t[i]] & RcEnd)) i++;
 return i; }

// the vm calls f on a, and lvm_rd_called files (t . answer) in the memo and runs the asking
// state again. the four words are RdSlack's
static struct ai *rd_call(struct ai *g, word f, word a, word t) {
 g->sp -= 4;
 g->sp[0] = a, g->sp[1] = f, g->sp[2] = t, g->sp[3] = word(g->ip);
 return g->ip = (union u*) rd_call_k, g; }
#define RdStep(n, p) if (rd_lit(n = rd_next(memo, p))) return rd_call(g, n, ZeroPoint, n)

static struct ai *rd_called(struct ai *g) {             // [v t ip regs ..]
 if (!ai_ok(g = ai_have(g, 2 * chain_req))) return g;
 word v = g->sp[0];
 if (rd_lit(v)) v = ZeroPoint;                          // a promise of a promise ends the text
 struct ai_chain *e = bump(g, chain_req), *m = bump(g, chain_req);
 ini_chain(e, g->sp[1], v), ini_chain(m, word(e), g->sp[3 + RdMemo]);
 g->sp[3 + RdMemo] = word(m);
 g->ip = cell(g->sp[2]), g->sp += 3;
 return g; }

// the room is the caller's, from here down: a cons, and k words in under the registers
static ai_noinline word rd_cons(struct ai *g, word a, word b) {
 return word(ini_chain(bump(g, chain_req), a, b)); }
static ai_inline void rd_open(struct ai *g, uintptr_t k) {
 g->sp -= k, memmove(g->sp, g->sp + k, RdRegs * sizeof(word)); }
static ai_inline void rd_shut(struct ai *g, uintptr_t k) {
 memmove(g->sp + k, g->sp, RdRegs * sizeof(word)), g->sp += k; }
static ai_inline void rd_frame(struct ai *g, int k) {
 rd_open(g, 1);
 g->sp[RdRegs] = RdHdr(k, getcharm(g->sp[RdCnt])), g->sp[RdCnt] = putcharm(0); }
static ai_inline void rd_mono(struct ai *g, word o) {
 rd_open(g, 2);
 g->sp[RdRegs] = RdHdr(RkMono, getcharm(g->sp[RdCnt])), g->sp[RdRegs + 1] = o;
 g->sp[RdCnt] = putcharm(0); }

// out through the base frame: v is the answer, in the argument's slot
static struct ai *rd_done(struct ai *g, word v) {
 uintptr_t i = RdRegs + getcharm(g->sp[RdCnt]);
 for (word h; RdKind(h = g->sp[i]) > RkAll; i += (RdKind(h) == RkMono ? 2 : 1) + RdUnder(h));
 g->ip = cell(g->sp[i + 1]), g->sp += i + 2, g->sp[0] = v;
 return g; }
static struct ai *rd_torn(struct ai *g) { return rd_done(g, g->rnom[RnTorn]); }

static struct ai *rd_enter(struct ai *g, int k) {       // [x ..]
 if (!ai_ok(g = ai_have(g, RdRegs + 2))) return g;
 word x = g->sp[0];
 g->sp -= RdRegs + 2;
 g->sp[RdCur] = x, g->sp[RdMemo] = ZeroPoint, g->sp[RdCnt] = putcharm(0), g->sp[RdVal] = ZeroPoint;
 g->sp[RdSrc] = ZeroPoint;
 g->sp[RdRegs] = RdHdr(k, 0), g->sp[RdRegs + 1] = word(g->ip + 1);
 return RdGo(RsStart); }
static struct ai *rd_one(struct ai *g) { return rd_enter(g, RkOne); }
static struct ai *rd_many(struct ai *g) { return rd_enter(g, RkAll); }

// the doors: a string is read in place, a port flows (post.l's flow, the one
// lazy charlist there is), a promise is forced, and a charlist is read as it stands
static struct ai *rd_start(struct ai *g) {
 if (!ai_ok(g = ai_have(g, RdSlack))) return g;
 word x = g->sp[RdCur];
 if (strp(x)) {
  return g->sp[RdSrc] = x, g->sp[RdCur] = putcharm(0), RdGo(RsRead); }
 if (!iop(x) && !rd_lit(x)) return RdGo(RsRead);
 for (word m = g->sp[RdMemo]; chainp(m); m = B(m))
  if (AA(m) == x) return g->sp[RdCur] = BA(m), RdGo(RsRead);
 if (!iop(x)) return rd_call(g, x, ZeroPoint, x);
 word f = stacklook(g, ZeroPoint, g->rnom[RnFlow]);
 if (!evenp(f) || f == ZeroPoint) return g->sp[RdCur] = ZeroPoint, RdGo(RsRead);
 return rd_call(g, f, x, x); }

// a text's escapes: n t r e 0, \xhh as two chars hex or not, \u{h..} one to six hex
// digits naming a code point outside the surrogates (else a plain u), any other char
// itself. counts the bytes, and lays them too when d is given; -1 torn, -2 a promise to
// force (in *end), else the count with *end past the closing quote
static intptr_t rd_strw(word memo, word src, word p, char *d, word *end) {
 intptr_t k = 0;
 word n, q;
#define Put(b) ((void) (d && (d[k] = (char) (b))), k++)
#define Over(n, p) if (rd_lit(n = rd_next(memo, p))) return *end = n, -2
 for (;;) {
  intptr_t c = rd_at(src, p);
  if (c < 0) return -1;
  Over(n, p);
  if (c == '"') return *end = n, k;
  if (c != '\\') { Put(rd_byte(src, p)), p = n; continue; }
  if ((c = rd_at(src, q = n)) < 0) return -1;
  Over(n, q);
  if (c == 'x') {
   word h;
   if (rd_at(src, n) < 0) return -1;
   Over(h, n);
   if (rd_at(src, h) < 0) return -1;
   Put(rd_dval(rd_raw(src, n)) * 16 + rd_dval(rd_raw(src, h)));
   Over(p, h);
   continue; }
  if (c == 'u' && rd_at(src, n) == '{') {
   intptr_t v = 0, j = 0, h;
   Over(q, n);
   for (; (h = rd_at(src, q)) != '}' && h >= 0 && j < 6 && rd_hex(h); j++) {
    v = v * 16 + rd_dval(h);
    Over(q, q); }
   if (h < 0) return -1;
   if (h == '}' && j && v <= 0x10ffff && (v < 0xd800 || v > 0xdfff)) {
    if (v < 0x80) Put(v);
    else if (v < 0x800) Put(0xc0 | v >> 6), Put(0x80 | (v & 63));
    else if (v < 0x10000) Put(0xe0 | v >> 12), Put(0x80 | (v >> 6 & 63)), Put(0x80 | (v & 63));
    else Put(0xf0 | v >> 18), Put(0x80 | (v >> 12 & 63)), Put(0x80 | (v >> 6 & 63)), Put(0x80 | (v & 63));
    Over(p, q);
    continue; }
   Put('u'), p = n;
   continue; }
  c = rd_raw(src, q);
  Put(c == 'n' ? '\n' : c == 't' ? '\t' : c == 'r' ? '\r' : c == 'e' ? 27 : c == '0' ? 0 : c);
  p = n; }
#undef Put
#undef Over
}

static struct ai *rd_str(struct ai *g) {
 word memo = g->sp[RdMemo], src = g->sp[RdSrc], n, e;
 RdStep(n, g->sp[RdCur]);
 intptr_t k = rd_strw(memo, src, n, NULL, &e);
 if (k == -1) return rd_torn(g);
 if (k == -2) return rd_call(g, e, ZeroPoint, e);
 if (!ai_ok(g = ai_have(g, str_width(k) + RdSlack))) return g;
 memo = g->sp[RdMemo], src = g->sp[RdSrc], n = rd_next(memo, g->sp[RdCur]);
 struct ai_str *s = k ? ini_str(bump(g, str_width(k)), k) : NULL;
 rd_strw(memo, src, n, s ? txt(s) : NULL, &e);
 g->sp[RdVal] = s ? word(s) : EmptyString, g->sp[RdCur] = e;
 return RdGo(RsDatum); }

// a token's text: an integer in any of the three bases, the named infinities, or a float
// if it leads like one (a digit or a dot, past a sign) and parses whole. mk_gem's () for a
// nan would lose the name, so that is no float either
static bool rd_float(char const *t, uintptr_t n, double *d) {
 if (n == 8 && !memcmp(t, "infinity", 8)) return *d = __builtin_inf(), true;
 if (n == 9 && !memcmp(t, "-infinity", 9)) return *d = -__builtin_inf(), true;
 char c = n && (*t == '+' || *t == '-') ? t[1] : *t;   // the NUL past a lone sign leads nothing
 if (!(c >= '0' && c <= '9') && c != '.') return false;
 char *e;
 *d = am_strtod(t, &e);
 return e != t && *e == 0 && *d == *d; }
static bool rd_numeral(struct ai_str *s) {
 double d;
 return is_dec_int(txt(s), len(s)) || is_hex_int(txt(s), len(s)) || is_oct_int(txt(s), len(s))
     || rd_float(txt(s), len(s), &d); }
// the text at sp[0] -> what it spells, a numeral at full precision or else the name
static struct ai *rd_atom(struct ai *g) {
 struct ai_str *s = str(g->sp[0]);
 uintptr_t n = len(s);
 double d;
 if (is_dec_int(txt(s), n)) return ai_big_read_dec(g);
 if (is_hex_int(txt(s), n)) return ai_big_read_hex(g);
 if (is_oct_int(txt(s), n)) return ai_big_read_oct(g);
 if (!rd_float(txt(s), n, &d)) return intern(g);
 if (!ai_ok(g = ai_have(g, gem_req))) return g;
 return g->sp[0] = mk_gem(&g->hp, (ai_flo_t) d), g; }

// a name-led token, whole. a digit-led one that is no numeral and carries an operator
// run is cut one past the run, when a datum is glued there: 2?<>x is 2?<> around x. a
// trailing - before a digit is the next numeral's sign, so the cut falls before it
static struct ai *rd_tok(struct ai *g, bool split) {
 word memo = g->sp[RdMemo], src = g->sp[RdSrc], p = g->sp[RdCur], n;
 uintptr_t len = 0;
 if (rd_in(src, p)) len = rd_send(str(src), getcharm(p)) - getcharm(p);
 else for (; rd_at(src, p) >= 0 && !(rd_c(src, p) & RcEnd); p = n, len++) RdStep(n, p);
 if (!ai_ok(g = ai_have(g, 2 * str_width(len) + RdSlack))) return g;
 memo = g->sp[RdMemo], src = g->sp[RdSrc], p = g->sp[RdCur];
 struct ai_str *s = ini_str(bump(g, str_width(len)), len);
 word lop = ZeroPoint, aop = ZeroPoint;                 // the run's last char, and past it
 uintptr_t k = 0;
 for (uintptr_t i = 0; i < len; i++) {
  txt(s)[i] = rd_byte(src, p), n = rd_next(memo, p);
  if (rd_c(src, p) & RcOp) k = i + 1, lop = p, aop = n;
  p = n; }
 if (split && k && !rd_numeral(s)) {
  bool shed = k > 1 && rd_at(src, lop) == '-' && (rd_c(src, aop) & RcDig);
  word r = shed ? lop : aop;
  if (rd_glued(src, r)) {
   k -= shed;
   struct ai_str *o = ini_str(bump(g, str_width(k)), k);
   memcpy(txt(o), txt(s), k);
   g->sp[RdCur] = r, *--g->sp = word(o);
   if (!ai_ok(g = ai_have(intern(g), 2))) return g;
   rd_mono(g, *g->sp++);
   return RdGo(RsRead); } }
 g->sp[RdCur] = p, *--g->sp = word(s);
 if (!ai_ok(g = rd_atom(g))) return g;
 g->sp[1 + RdVal] = g->sp[0], g->sp++;
 return RdGo(RsDatum); }

// an operator run: the longest run of operator chars, one plain name, and a monadic wrap
// when a datum is glued after it. @ may lead a run but never extend one, a trailing -
// before a digit is shed back to the numeral, and \ never wraps: it is form space
static struct ai *rd_op(struct ai *g) {
 word memo = g->sp[RdMemo], src = g->sp[RdSrc], p = g->sp[RdCur], last = p, n;
 uintptr_t len = 0;
 for (intptr_t c; (c = rd_at(src, p)) >= 0 && (c == '@' ? !len : rd_cls[c] & RcOp); last = p, p = n, len++)
  RdStep(n, p);
 len -= len > 1 && rd_at(src, last) == '-' && (rd_c(src, p) & RcDig);
 if (!ai_ok(g = ai_have(g, str_width(len) + RdSlack))) return g;
 memo = g->sp[RdMemo], src = g->sp[RdSrc], p = g->sp[RdCur];
 struct ai_str *s = ini_str(bump(g, str_width(len)), len);
 for (uintptr_t i = 0; i < len; i++) txt(s)[i] = rd_byte(src, p), p = rd_next(memo, p);
 bool mono = !(len == 1 && txt(s)[0] == '\\') && rd_glued(src, p);
 g->sp[RdCur] = p, *--g->sp = word(s);
 if (!ai_ok(g = ai_have(intern(g), 2))) return g;
 if (mono) return rd_mono(g, *g->sp++), RdGo(RsRead);
 g->sp[1 + RdVal] = g->sp[0], g->sp++;
 return RdGo(RsDatum); }

// the next datum's first char, past whitespace and comments -- ; and #! run through the
// end of the line, and a comment is walked again from its start when a promise inside it
// is forced -- and what that char opens
static struct ai *rd_read(struct ai *g) {
 for (;;) {
  if (!ai_ok(g = ai_have(g, RdSlack))) return g;
  word const memo = g->sp[RdMemo], src = g->sp[RdSrc];
  word p = g->sp[RdCur], n;
  intptr_t c;
  if (rd_in(src, p)) p = putcharm(rd_sskip(str(src), getcharm(p)));
  for (;;) {
   if ((c = rd_at(src, p)) < 0) break;
   if (rd_cls[c] & RcWs) { RdStep(n, p); p = n; continue; }
   if (c != ';' && c != '#') break;
   word const s = p;
   g->sp[RdCur] = s;
   if (c == '#') {
    RdStep(n, p);
    if (rd_at(src, n) != '!') break;
    p = n; }
   do { RdStep(n, p); p = n; } while ((c = rd_at(src, p)) >= 0 && c != '\n' && c != '\r');
   if (c >= 0) { RdStep(n, p); p = n; }
   g->sp[RdCur] = p; }
  g->sp[RdCur] = p;
  word const h = g->sp[RdRegs + getcharm(g->sp[RdCnt])];
  int const k = RdKind(h);
  unsigned const m = c < 0 ? RcClose : rd_cls[c];
  if (m & RcClose)                                       // the end of the text or of a list
   return k >= RkParen && k <= RkTuple ? (c < 0 ? rd_torn(g) : RdGo(RsClose))
        : k == RkOne ? rd_done(g, ZeroPoint)
        : k == RkAll ? RdGo(RsAll)
        : rd_torn(g);
  if (m & RcOpen) {                                      // a list, or the @ wrap turned constructor
   RdStep(n, p);
   if (k == RkLift) g->sp[RdRegs] = RdHdr(RkTuple, RdUnder(h));
   else rd_frame(g, c == '(' ? RkParen : c == '[' ? RkList : RkHash);
   g->sp[RdCur] = n;
   continue; }
  if (c == '"') return rd_str(g);
  if (c == '\'') { RdStep(n, p); rd_frame(g, RkQuote), g->sp[RdCur] = n; continue; }
  if (c == '@' || c == ',' || (m & RcSign)) {            // each looks one char past itself
   RdStep(n, p);
   if (c == ',') return g->sp[RdVal] = g->rnom[RnComma], g->sp[RdCur] = n, RdGo(RsDatum);
   if (c == '@') {                                       // a run, the tuple wrap, or the plain @
    if (rd_c(src, n) & RcOp) return rd_op(g);
    if (rd_glued(src, n)) { rd_frame(g, RkLift), g->sp[RdCur] = n; continue; }
    return g->sp[RdVal] = g->rnom[RnAt], g->sp[RdCur] = n, RdGo(RsDatum); }
   return (rd_c(src, n) & RcDig) || rd_at(src, n) == '.' ? rd_tok(g, false) : rd_op(g); }   // a numeral's sign
  return m & RcOp ? rd_op(g) : rd_tok(g, m & RcDig); } }

// a closer ends the open list: its datums, under the wrap its opener named
static struct ai *rd_close(struct ai *g) {
 uintptr_t const cnt = getcharm(g->sp[RdCnt]);
 if (!ai_ok(g = ai_have(g, (cnt + 2) * chain_req + RdSlack))) return g;
 word const memo = g->sp[RdMemo];
 word n;
 RdStep(n, g->sp[RdCur]);
 word const h = g->sp[RdRegs + cnt];
 word l = ZeroPoint;
 for (uintptr_t i = 0; i < cnt; i++) l = rd_cons(g, g->sp[RdRegs + i], l);
 rd_shut(g, cnt + 1), g->sp[RdCnt] = putcharm(RdUnder(h)), g->sp[RdCur] = n;
 int const k = RdKind(h);
 g->sp[RdVal] = k == RkParen ? l
  : l == ZeroPoint && k != RkList ? rd_cons(g, g->rnom[k == RkHash ? RnTablet : RnIota], rd_cons(g, putcharm(0), ZeroPoint))
  : rd_cons(g, g->rnom[k == RkList ? RnList : k == RkHash ? RnHash : RnTuple], l);
 return RdGo(RsDatum); }

// a string's residue, the cells a caller threads: the text past the position
static ai_noinline word rd_rest(struct ai *g) {
 struct ai_str *s = str(g->sp[RdSrc]);
 word l = ZeroPoint;
 for (uintptr_t i = len(s); i-- > (uintptr_t) getcharm(g->sp[RdCur]);)
  l = rd_cons(g, putcharm((unsigned char) txt(s)[i]), l);
 return l; }

// a datum is done: onto the open pile, or out through the wraps waiting on it
static struct ai *rd_datum(struct ai *g) {
 for (;;) {
  if (!ai_ok(g = ai_have(g, RdSlack))) return g;
  uintptr_t const cnt = getcharm(g->sp[RdCnt]);
  word const h = g->sp[RdRegs + cnt], v = g->sp[RdVal];
  int const k = RdKind(h);
  if (k == RkOne) {
   word r = g->sp[RdCur];
   if (charmp(r)) {
    if (!ai_ok(g = ai_have(g, (len(str(g->sp[RdSrc])) - getcharm(r) + 1) * chain_req))) return g;
    r = rd_rest(g); }
   return rd_done(g, rd_cons(g, g->sp[RdVal], r)); }
  if (k < RkQuote) {                                     // a list's, or the whole text's
   rd_open(g, 1), g->sp[RdRegs] = v, g->sp[RdCnt] = putcharm(cnt + 1);
   return RdGo(RsRead); }
  word const o = g->sp[RdRegs + 1];
  rd_shut(g, k == RkMono ? 2 : 1), g->sp[RdCnt] = putcharm(RdUnder(h));
  g->sp[RdVal] =
     k == RkQuote ? rd_cons(g, g->rnom[RnQuote], rd_cons(g, v, ZeroPoint))             // 'x: (\ x)
   : k == RkMono ? rd_cons(g, g->rnom[RnMono], rd_cons(g, rd_cons(g, o, rd_cons(g, v, ZeroPoint)), ZeroPoint))
   : v == ZeroPoint ? rd_cons(g, g->rnom[RnIota], rd_cons(g, putcharm(0), ZeroPoint))    // @x
   : rd_cons(g, g->rnom[RnTuple], chainp(v) ? v : rd_cons(g, v, ZeroPoint)); } }

static struct ai *rd_all(struct ai *g) {
 uintptr_t const cnt = getcharm(g->sp[RdCnt]);
 if (!ai_ok(g = ai_have(g, cnt * chain_req))) return g;
 word l = ZeroPoint;
 for (uintptr_t i = 0; i < cnt; i++) l = rd_cons(g, g->sp[RdRegs + i], l);
 return rd_done(g, l); }

lvm(lvm_sound) LvmResume(g, rd_one)
// (sounds text): every form of a text, in order, or `torn` -- sound's doors, and the boot's
// reader. a stray closer ends the text
lvm(lvm_sounds) LvmResume(g, rd_many)
static lvm(lvm_rd_start) LvmResume(g, rd_start)
static lvm(lvm_rd_read) LvmResume(g, rd_read)
static lvm(lvm_rd_close) LvmResume(g, rd_close)
static lvm(lvm_rd_datum) LvmResume(g, rd_datum)
static lvm(lvm_rd_all) LvmResume(g, rd_all)
static lvm(lvm_rd_called) LvmResume(g, rd_called)

////
/// " the boot stitch "
//
// the egg's corpus is read whole and handed to the egg expression, which never learns.

// a text -> the list of its forms, pushed. an unfinished shape answers `torn`, which the
// egg would fold as an empty corpus and silently pin ev to 0: refuse it here
static struct ai *readtext(struct ai *g, char const *s) {
 g = gxr(push0(ai_strof(g, s)));                     // ("<text>")
 if (!ai_ok(g = ai_push(g, 1, word(rd_reads_k)))) return g;
 if (!ai_ok(g = ai_eval(gxl(g)))) return g;           // (<reads> "<text>")
 word r = g->sp[0];
 return chainp(r) || r == ZeroPoint ? g : encode(g, ai_status_more); }

// a text's forms, in source order, onto the front of the list under them
static struct ai *readonto(struct ai *g, char const *s) {
 if (!ai_ok(g = readtext(g, s))) return g;
 uintptr_t n = 0;
 for (word l = g->sp[0]; chainp(l); l = B(l)) n++;
 if (!ai_ok(g = ai_have(g, 2 * n * chain_req))) return g;
 word r = ZeroPoint, o = g->sp[1];
 for (word l = g->sp[0]; chainp(l); l = B(l)) r = rd_cons(g, A(l), r);
 for (; chainp(r); r = B(r)) o = rd_cons(g, A(r), o);
 return g->sp[1] = o, g->sp += 1, g; }

static struct ai *qtop(struct ai *g) {                // x on top -> 'x
 return gxl(pushq(gxr(push0(g)))); }                 // (x), then (\ x)

// apply a one-form driver text to the quoted list on top of the stack: (<driver> '(list)),
// the answer at sp[0]
static struct ai *applyq(struct ai *g, char const *driver) {
 g = readonto(gxr(push0(qtop(g))), driver);          // ('(list)), then (driver '(list))
 return ai_eval(g); }

// the plain eval fold: run a list of forms in order, answer the last one's
// value. `ev` is read late so one text drives both of love0's passes. the forms
// left are asked two?, never their truth: that would net the rest of the text per form
static char const evfold[] = "((: (e a b) (? (two? b) (e (ev 'ev (cap b)) (cup b)) a) e) 0)";

// every top-level form of a text, evaluated in order -- the frontends' door for a
// boot tail, a CLI driver, a corpus runner. ai_evals keeps the last form's value at
// sp[0] (a program's status, for the frontend to answer with); ai_evals_ is the same
// with the value dropped -- sequence and sequence_.
ai_noinline struct ai *ai_evals(struct ai *g, char const *s) {
 return applyq(readtext(g, s), evfold); }
ai_noinline struct ai *ai_evals_(struct ai *g, char const *s) {
 return ai_pop(ai_evals(g, s), 1); }

// the egg takes two corpora: `corpus` is sat twice (ev compiles itself), `post`
// once, after the hatch and before the mop -- the seat for love that needs the
// runtime-internal noms (peek/seek) the mop is about to take off the book.
ai_noinline struct ai *ai_egg(struct ai *g, char const *egg, char const *corpus, char const *post) {
 g = gxr(push0(qtop(readtext(g, post))));            // ('post), parked under the corpus
 g = readtext(g, corpus);                            // prel + ev
 g = readonto(gxl(qtop(g)), egg);                    // (egg 'corpus 'post)
 return ai_pop(ai_eval(g), 1); }
