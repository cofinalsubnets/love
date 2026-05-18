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

struct g_in_ed { struct g_in _i, *i; struct g_ed e; };

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

// --- keystroke decoding ----------------------------------------------
#define EV_QUIT  (-100)
#define EV_ENTER (-101)

static int rb(void) {                      // read one raw byte; -1 at EOF
  unsigned char c;
  return read(STDIN_FILENO, &c, 1) == 1 ? c : -1; }

// decode one keystroke into a g_edit_ev, a character (> 0), 0 to ignore,
// EV_ENTER (submit) or EV_QUIT (^D / EOF). a bare ESC blocks for the next
// key -- fine here; Ctrl-D is the reliable quit.
static int read_event(void) {
  int c = rb();
  switch (c) {
    case -1: case 4:           return EV_QUIT;
    case '\r': case '\n':      return EV_ENTER;
    case 8: case 127:          return g_ed_bsp;    // Backspace
    case 1:                    return g_ed_home;   // Ctrl-A
    case 5:                    return g_ed_end;    // Ctrl-E
    case 27:                                       // ESC: an escape seq
      if (rb() != '[') return 0;
      switch (c = rb()) {
        case 'D': return g_ed_left;
        case 'C': return g_ed_right;
        case 'A': return g_ed_up;
        case 'B': return g_ed_down;
        case 'H': return g_ed_home;
        case 'F': return g_ed_end;
        case '1': case '7': return rb(), g_ed_home;
        case '4': case '8': return rb(), g_ed_end;
        case '3':           return rb(), g_ed_del;
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

static int rendered;      // terminal cursor column relative to the start
                          // of the edit region (just after the prompt)

// redraw the edit line in place. all motion is relative to the region
// start, so it never disturbs whatever prompt precedes it on the line.
// edl is stored reversed; to walk the line in display order it is drained
// onto edr in place -- just repointing cdrs, no allocation -- then the
// same number of cells are rewound afterward, restoring the cursor split.
static void render(struct g *f) {
  size_t left = 0, total = 0;                   // |edl| (= cursor offset), |line|
  for (g_word p; twop(f->e.l); left++)          // drain edl onto edr in place
    p = f->e.l, f->e.l = B(p), B(p) = f->e.r, f->e.r = p;

  if (rendered) printf("\x1b[%dD", rendered);   // back to the region start
  fputs("\x1b[K", stdout);                      // clear to end of line
  for (g_word l = f->e.r; twop(l); l = B(l), total++) {
    int c = g_getnum(A(l));                     // edr now holds the whole line
    putchar(c >= ' ' && c < 127 ? c : ' '); }

  for (size_t i = left; i--; ) {                // rewind: edr -> edl, restoring
    g_word p = f->e.r;                          //  the original cursor split
    f->e.r = B(p), B(p) = f->e.l, f->e.l = p; }

  if (total > left) printf("\x1b[%zuD", total - left);  // cursor to the split
  rendered = left;
  fflush(stdout); }

// edit one line: a keystroke loop until Enter (or ^D). on return the
// editor buffer (f->e.l/f->e.r) holds the line. threads f -- g_edit
// allocates and the collection it may trigger relocates the runtime.
static g_inline struct g *edit_line(struct g *f) {
  rendered = 0;                            // cursor sits at the region start
  for (;;) {
    render(f);
    int ev = read_event();
    if (ev == EV_QUIT)  return f->e.in_eof = g_putnum(1), f;
    if (ev == EV_ENTER) return putchar('\n'), fflush(stdout), f;
    if (!g_ok(f = g_edit(f, ev))) return f; } }

// --- host input hooks ------------------------------------------------
// _getc serves the next input character. interactively it runs the line
// editor to refill once a line is used up; otherwise it raw-reads stdin.
static struct g *_getc(struct g *f, struct g_in*) {
  if (twop(f->e.r))                              // the edited line, char by char
    return f->b = g_getnum(A(f->e.r)), f->e.r = B(f->e.r), f;
  if (!isatty(STDIN_FILENO)) {                   // non-tty: raw bytes
    int c = rb();
    return f->b = c, f->e.in_eof = g_putnum(c < 0 ? 1 : 0), f; }
  if (g_getnum(f->e.in_eof)) return f->b = EOF, f;
  f = edit_line(f);                              // refill: edit a fresh line
  if (!g_ok(f)) return f;
  if (g_getnum(f->e.in_eof)) return f->b = EOF, f;              // ^D ended the session
  f = g_edit(f, g_ed_end);                       // flatten the line into edr,
  f = g_edit(f, '\n');                           //  terminated by a newline,
  if (!g_ok(f = g_edit(f, g_ed_home))) return f; //  in reading order
  if (!twop(f->e.r)) return f->b = EOF, f;
  return f->b = g_getnum(A(f->e.r)), f->e.r = B(f->e.r), f; }

// push a character back onto the editor buffer: edr := (c . edr). this
// allocates -- g_read1's token reader refreshes its cached buffer
// pointer from f->sp[0] after the ungetc call, so the relocation is safe.
static struct g *_ungetc(struct g *f, int c, struct g_in*) {
  f = gxl(g_push(f, 2, g_putnum(c), f->e.r));    // gxl: (sp[0] . sp[1])
  if (g_ok(f)) f->e.r = g_pop1(f);
  return f; }

static struct g *_eof(struct g *f, struct g_in*) {
  return f->b = g_getnum(f->e.in_eof), f; }

static struct g_in _g_stdin = { _getc, _ungetc, _eof };
struct g_in *g_stdin = &_g_stdin;

// --- main: load the prelude and run the REPL script ------------------
int main(int argc, char const **argv) {
  if (isatty(STDIN_FILENO)) raw_mode();
  struct g *f;
  for (f = g_ini(); *argv; f = g_strof(f, *argv++));
  for (f = g_push(f, 1, g_nil); argc--; f = gxr(f));
  if (g_ok(f)) {
    struct g_def d[] = {{"argv", g_pop1(f)}, {0}};
    static char const boot[] =
#include "boot.h"
    ;
    static char const repl[] =
#include "repl.h"
    ;
    f = g_evals_(g_defs(f, d), boot);            // the prelude
    f = g_evals_(f, repl); }                     // h/repl.g drives the REPL
  enum g_status s = g_code_of(f);
  g_fin(f);
  return s; }
