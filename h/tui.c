// Host front-end: a line-editor REPL.
//
// Raw-mode terminal -> the zipper editor (g_edit) -> the parser
// (g_read_edit) -> the evaluator (g_eval). Each keystroke edits the
// current line; Enter parses it. A complete form is evaluated and its
// value printed; incomplete input (an open paren or string) is kept in
// the editor so you can finish typing it; blank input is ignored.
// Ctrl-D quits.
//
// Single-line: the editor buffer renders on one line. No prelude is
// loaded -- the environment is the builtins plus the four special forms;
// `#include "boot.h"` + a g_evals_ call would add the standard library
// (and a b/boot.h prerequisite on the Makefile's tui rule). Nothing here
// reads host stdin -- the editor is the input source -- so ggetc/gungetc/
// geof are stubs; gputc/gflush/g_clock are real.

#include "../g/g.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <termios.h>
#include <time.h>

// --- host I/O hooks the runtime expects ------------------------------
g_noinline uintptr_t g_clock(void) {
  struct timespec ts;
  return clock_gettime(CLOCK_REALTIME, &ts) ? (uintptr_t) -1
       : (uintptr_t) (ts.tv_sec * 1000 + ts.tv_nsec / 1000000); }

struct g *gputc(struct g *f, int c)   { return putchar(c), f; }
struct g *gflush(struct g *f)         { return fflush(stdout), f; }
struct g *ggetc(struct g *f)          { return f->b = -1, f; }  // editor is the source
struct g *gungetc(struct g *f, int c) { return f; }
struct g *geof(struct g *f)           { return f->b = 1, f; }

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

// --- input: raw bytes -> editor events -------------------------------
#define EV_QUIT  (-100)
#define EV_ENTER (-101)

static int rb(void) {                      // read one byte; -1 at EOF
  unsigned char c;
  return read(STDIN_FILENO, &c, 1) == 1 ? c : -1; }

// Decode one keystroke: a g_edit_ev, a character (> 0), 0 to ignore,
// EV_ENTER (submit the line) or EV_QUIT. A bare ESC blocks until the
// next key -- fine for a demo; Ctrl-D is the reliable quit.
static int read_event(void) {
  int c = rb();
  switch (c) {
    case -1: case 4:           return EV_QUIT;     // EOF / Ctrl-D
    case '\r': case '\n':      return EV_ENTER;    // submit
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
      return c >= ' ' && c < 127 ? c : 0; } }     // printable -> insert

// --- rendering -------------------------------------------------------
#define BUF 4096
#define PROMPT "> "

// redraw the prompt and editor buffer on the current line.
static void render(struct g *f) {
  if (!isatty(STDIN_FILENO)) return;
  char buf[BUF];
  size_t cursor, n = g_edit_text(f, buf, BUF, &cursor);
  if (n > BUF) n = BUF;                    // truncated; show what fits
  fputs("\r\x1b[K" PROMPT, stdout);        // CR, erase line, prompt
  for (size_t i = 0; i < n; i++)
    putchar(buf[i] >= ' ' && buf[i] < 127 ? buf[i] : ' ');
  fputs("\r", stdout);
  printf("\x1b[%zuC", cursor + (sizeof PROMPT - 1));   // step to the cursor
  fflush(stdout); }

// --- read / eval / print ---------------------------------------------
// Enter was pressed. Parse the buffer; a complete form is evaluated and
// printed, incomplete input is left in the editor for the user to finish,
// blank input is dropped. Returns a usable (g_ok) core unless the eval
// itself failed.
static struct g *repl_enter(struct g *f) {
  bool i = isatty(STDIN_FILENO);
  f = g_read_edit(f);
  enum g_status s = g_code_of(f);
  f = g_core_of(f);
  if (s == g_status_more) return f;        // incomplete: keep the line
  if (i) fputs("\n", stdout);                     // finish the input line
  if (s != g_status_ok) return f;          // blank input (eof)
  f = g_eval(f);                           // the datum is on the stack
  if (g_ok(f) && i) {
    gputx(f, f->sp[0]);                    // print the result
    fputs("\n", stdout); }
  f = g_pop(f, 1);
  return f; }

int main(int argc, char const **argv) {
  raw_mode();
  struct g *f;
  for (f = g_ini(); *argv; f = g_strof(f, *argv++));
  for (f = g_push(f, 1, g_nil); argc--; f = gxr(f));
  if (g_ok(f)) {
    struct g_def d[] = {{"argv", g_pop1(f)}, {0}};
    static char const p[] =
#include "boot.h"
    ;
    f = g_evals_(g_defs(f, d), p); }
  if (!g_ok(f)) return fputs("g_ini failed\n", stderr), 1;

  if (isatty(STDIN_FILENO)) fputs("gwen repl -- edit the line, Enter to evaluate, ^D to quit\n", stdout);
  for (;;) {
    render(f);
    int ev = read_event();
    if (ev == EV_QUIT) break;
    f = ev == EV_ENTER ? repl_enter(f) : g_edit(f, ev);
    if (!g_ok(f)) {                        // OOM, or a failed evaluation
      fputs("\r\nout of memory\n", stderr);
      return g_fin(f); } }

  fputs("\n", stdout);
  return g_fin(f); }
