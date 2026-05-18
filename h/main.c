#include "../g/g.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <termios.h>
#include <time.h>

struct g_in_f { struct g_in i; FILE *f; };
struct g_out_f { struct g_out o; FILE *f; };
#define f_i(x) ((struct g_in_f*)(x))->f
#define f_o(x) ((struct g_out_f*)(x))->f

struct g
 *g_in_f_getc(struct g*, struct g_in*),
 *g_in_f_ungetc(struct g*, int, struct g_in*),
 *g_in_f_eof(struct g*, struct g_in*),
 *g_out_f_putc(struct g*, int, struct g_out*),
 *g_out_f_flush(struct g*, struct g_out*);

g_noinline uintptr_t g_clock(void) {
  struct timespec ts;
  return clock_gettime(CLOCK_REALTIME, &ts) ? (uintptr_t) -1
       : (uintptr_t) (ts.tv_sec * 1000 + ts.tv_nsec / 1000000); }


static struct g *_putc(struct g *f, int c, struct g_out*) { return putchar(c), f; }
static struct g *_flush(struct g *f, struct g_out*)       { return fflush(stdout), f; }
static struct g_out _g_stdout = { _putc, _flush };
struct g_out *g_stdout = &_g_stdout;

// --- raw terminal mode -----------------------------------------------
static struct termios saved_termios;
static void restore_termios(void) {
  tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios); }

static void raw_mode(void) {
  tcgetattr(STDIN_FILENO, &saved_termios);
  atexit(restore_termios);                 // restore on normal exit
  struct termios raw = saved_termios;
  raw.c_lflag &= ~(ICANON | ECHO | ISIG | IEXTEN);  // no line buffering/echo
  raw.c_iflag &= ~(IXON | ICRNL | BRKINT | INPCK | ISTRIP);
  raw.c_cc[VMIN] = 1;                      // block for one byte
  raw.c_cc[VTIME] = 0;
  tcsetattr(STDIN_FILENO, TCSANOW, &raw); }
  // c_oflag is left alone, so '\n' on output still becomes CR-LF.

static struct g *raw_getc(struct g *f, struct g_in*) {
  return g_core_of(f)->b = fgetc(stdin), f; }
static struct g *raw_ungetc(struct g *f, int c, struct g_in*) {
  return g_core_of(f)->b = ungetc(c, stdin), f; }
static struct g *raw_eof(struct g *f, struct g_in*) {
  return g_core_of(f)->b = feof(stdin), f; }
static struct g_in raw_stdin = { raw_getc, raw_ungetc, raw_eof };

// --- keystroke decoding ----------------------------------------------
#define EV_QUIT  (-100)
#define EV_ENTER (-101)

// read one raw byte from `i`; -1 at EOF. `i` must not allocate (raw_stdin
// doesn't), so `f` stays valid across the call without rethreading.
static int rb(struct g *f, struct g_in *i) {
  return i->getc(f, i), (int) (g_word) f->b; }

// decode one keystroke into a g_edit_ev, a character (> 0), 0 to ignore,
// EV_ENTER (submit) or EV_QUIT (^D / EOF). a bare ESC blocks for the next
// key -- fine here; Ctrl-D is the reliable quit.
static int read_event(struct g *f, struct g_in *i) {
  int c = rb(f, i);
  switch (c) {
    case -1: case 4:           return EV_QUIT;
    case '\r': case '\n':      return EV_ENTER;
    case 8: case 127:          return g_ed_bsp;    // Backspace
    case 1:                    return g_ed_home;   // Ctrl-A
    case 5:                    return g_ed_end;    // Ctrl-E
    case 27:                                       // ESC: an escape seq
      if (rb(f, i) != '[') return 0;
      switch (c = rb(f, i)) {
        case 'D': return g_ed_left;
        case 'C': return g_ed_right;
        case 'A': return g_ed_up;
        case 'B': return g_ed_down;
        case 'H': return g_ed_home;
        case 'F': return g_ed_end;
        case '1': case '7': return rb(f, i), g_ed_home;
        case '4': case '8': return rb(f, i), g_ed_end;
        case '3':           return rb(f, i), g_ed_del;
        default:            return 0; }
    default:
      return c >= ' ' && c < 127 ? c : 0; } }

// --- charlist access (g.h doesn't export these; copied from g.c) -----
struct g_pair { g_vm_t *ap; uintptr_t typ; intptr_t a, b; };
#define two(o)  ((struct g_pair*)(o))
#define A(o)    two(o)->a
#define B(o)    two(o)->b
#define cell(o) ((union u*)(o))
#define odd(_)  ((uintptr_t)(_) & 1)
#define even(_) (!odd(_))
#define typ(o)  cell(o)[1].typ
enum { two_q };
static g_inline bool twop(g_word x) { return even(x) && typ(x) == two_q; }

// --- the line editor as a struct g_in --------------------------------
// the editor presented as an input pipe: it edits a whole line, then
// hands it back one character at a time, so anything that reads a g_in
// gets cooked input transparently. `i` is the keystroke source it reads
// while editing; `e` is the zipper holding the line. e.l/e.r are gwen
// heap values but live here in host memory, outside the span gcg traces
// wholesale, so rl/rr splice them onto f's GC root list (once, lazily).
struct g_in_ed {
  struct g_in _i;          // the g_in this editor presents (first member)
  struct g_in *i;          // keystroke source read during editing
  struct g_ed e;           // editor zipper: left/right charlists, in_eof
  struct g_r rl, rr;       // root-list nodes pinning e.l and e.r
  bool rooted; };          // whether rl/rr are spliced in yet

// splice e.l and e.r onto f's GC root list, once. idempotent: ed_getc
// calls it before the editor can allocate, so the line is always traced.
static void ed_root(struct g *f, struct g_in_ed *ied) {
  if (ied->rooted) return;
  struct g *c = g_core_of(f);
  ied->rl = (struct g_r){ &ied->e.l, c->root };
  ied->rr = (struct g_r){ &ied->e.r, &ied->rl };
  c->root = &ied->rr, ied->rooted = true; }

// redraw the edit line in place. the region start (just after the prompt)
// is marked once, when edit_line begins, with a DECSC cursor save; every
// render returns there with a DECRC restore, so it holds no display state
// of its own and never disturbs whatever prompt precedes it on the line.
// e->l is stored reversed; to walk the line in display order it is drained
// onto e->r in place -- just repointing cdrs, no allocation -- then the
// same number of cells are rewound afterward, restoring the cursor split.
static void render(struct g_ed *e) {
  size_t left = 0, total = 0;                   // |e->l| (cursor offset), |line|
  for (g_word p; twop(e->l); left++)            // drain e->l onto e->r in place
    p = e->l, e->l = B(p), B(p) = e->r, e->r = p;

  fputs("\x1b""8", stdout);                     // DECRC: back to the region start
  fputs("\x1b[K", stdout);                      // clear to end of line
  for (g_word l = e->r; twop(l); l = B(l), total++) {
    int c = g_getnum(A(l));                     // e->r now holds the whole line
    putchar(c >= ' ' && c < 127 ? c : ' '); }

  for (size_t i = left; i--; ) {                // rewind: e->r -> e->l, restoring
    g_word p = e->r;                            //  the original cursor split
    e->r = B(p), B(p) = e->l, e->l = p; }

  if (total > left) printf("\x1b[%zuD", total - left);  // cursor to the split
  fflush(stdout); }

// edit one line: a keystroke loop until Enter (or ^D). on return the
// zipper ied->e holds the line. threads f -- g_edit allocates and the
// collection it may trigger relocates the runtime.
static g_inline struct g *edit_line(struct g *f, struct g_in_ed *ied) {
  fputs("\x1b""7", stdout);                // DECSC: mark the region start
  for (;;) {
    render(&ied->e);
    int ev = read_event(f, ied->i);
    if (ev == EV_QUIT)  return ied->e.in_eof = g_putnum(1), f;
    if (ev == EV_ENTER) return putchar('\n'), fflush(stdout), f;
    if (!g_ok(f = g_edit(f, &ied->e, ev))) return f; } }

// serve the next input character. once the edited line is used up, run
// the editor to refill it. this is the interactive path: main installs
// it only when stdin is a terminal -- non-tty input bypasses the editor
// and reads its source g_in directly. so ed_getc need not, and cannot,
// re-decide that here: the keystroke source is just `ied->i`, whatever
// it is, with no assumption that it is fd 0.
static struct g *ed_getc(struct g *f, struct g_in *in) {
  struct g_in_ed *ied = (struct g_in_ed*) in;
  ed_root(f, ied);
  if (twop(ied->e.r))                            // the edited line, char by char
    return f->b = g_getnum(A(ied->e.r)), ied->e.r = B(ied->e.r), f;
  if (g_getnum(ied->e.in_eof)) return f->b = EOF, f;
  f = edit_line(f, ied);                         // refill: edit a fresh line
  if (!g_ok(f)) return f;
  if (g_getnum(ied->e.in_eof)) return f->b = EOF, f;   // ^D ended the session
  f = g_edit(f, &ied->e, g_ed_end);              // flatten the line into e.r,
  f = g_edit(f, &ied->e, '\n');                  //  terminated by a newline,
  if (!g_ok(f = g_edit(f, &ied->e, g_ed_home))) return f;  // in reading order
  if (!twop(ied->e.r)) return f->b = EOF, f;
  return f->b = g_getnum(A(ied->e.r)), ied->e.r = B(ied->e.r), f; }

// push a character back onto the editor buffer: e.r := (c . e.r). this
// allocates -- g_read1's token reader refreshes its cached buffer
// pointer from f->sp[0] after the ungetc call, so the relocation is safe.
static struct g *ed_ungetc(struct g *f, int c, struct g_in *in) {
  struct g_in_ed *ied = (struct g_in_ed*) in;
  ed_root(f, ied);
  f = gxl(g_push(f, 2, g_putnum(c), ied->e.r));  // gxl: (sp[0] . sp[1])
  if (g_ok(f)) ied->e.r = g_pop1(f);
  return f; }

static struct g *ed_eof(struct g *f, struct g_in *in) {
  return f->b = g_getnum(((struct g_in_ed*) in)->e.in_eof), f; }

// the line editor, reading its keystrokes off raw_stdin.
static struct g_in_ed ed_stdin = {
  ._i = { ed_getc, ed_ungetc, ed_eof },
  .i  = &raw_stdin,
  .e  = { g_nil, g_nil, g_nil }, };
// default stdin is the raw source; main upgrades it to ed_stdin for a tty.
struct g_in *g_stdin = &raw_stdin;

static char const
boot[] =
#include "boot.h"
,
repl[] =
#include "repl.h"
,
  rel[] = "(:(g e)(: r(read e)(?(= e r)0(: _(ev'ev r)(g e))))(g(sym 0)))"
  ;
// --- main: load the prelude and run the REPL script ------------------
int main(int argc, char const **argv) {
  struct g *f = g_ini();
  bool is_repl = isatty(STDIN_FILENO);
  if (is_repl) {                    // interactive: raw tty + editor
    raw_mode();
    if (g_ok(f)) g_core_of(f)->in = &ed_stdin._i; }
  for (; *argv; f = g_strof(f, *argv++));
  for (f = g_push(f, 1, g_nil); argc--; f = gxr(f));
  if (g_ok(f)) {
    struct g_def d[] = {{"argv", g_pop1(f)}, {0}};
    f = g_defs(f, d);
    f = g_evals_(f, boot);
    f = g_evals_(f, is_repl ? repl : rel); }
  enum g_status s = g_code_of(f);
  g_fin(f);
  return s; }
