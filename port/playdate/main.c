// Playdate frontend for love -- the rune CAS workbench riding the crank.
//
// love's frontend contract (love.h): the host defines ai_clock, the
// ai_stdin/ai_stdout ports, the ai_fd_port_vt vtable, and the cooperative-wait
// hooks. Here the console is a quay cb (50x30 cells of the 8x8 CGA font)
// blitted to the 1-bit LCD each frame; stdout/stderr both land there, so the
// prel's puts IS the screen and a scare face is visible. The heap rides
// pd->system->realloc through ai_ini_m. The bootstrap egg compiles the love
// compiler with the C evaluator, recompiles it with itself, installs it, then
// crew/rune/ bakes in as a registered module and cas.l (this folder) drives
// the demo: the C update just clears the console, fires (cas ()), and blits.
#include "pd_api.h"
#include "../../love.h"
#include "quay.h"

#define NROWS 30
#define NCOLS 50
#define kcb (&K.cb)
static struct k {
  struct ai *g;
  PlaydateAPI *pd;
  int dead;                    // a scare froze the session; keep blitting it
  struct { PDButtons current, pushed, released; } b;
  union {
    struct cb cb;
    uint8_t cb_bytes[sizeof(struct cb) + sizeof(uint32_t) * NROWS * NCOLS]; };
} K;

// --- clock + cooperative waits ---------------------------------------------
static unsigned int (*clockfp)(void);
ai_noinline uintptr_t ai_clock(void) { return clockfp ? clockfp() : 0; }
void ai_sleep(uintptr_t ms) {
  uintptr_t start = ai_clock();
  if (ms) while (ai_clock() - start < ms) ;
}
bool ai_ready(int fd) { return fd >= 0; }
void ai_wait_fds(int const *fds, int n, uintptr_t ms) { ai_sleep(ms); }

// --- port vtable: both ports ride the console buffer -----------------------
static struct ai *_getc(struct ai *g) {
  struct ai *fc = ai_core_of(g);
  struct ai_io *i = fc->io;
  if (getcharm(i->ungetc_buf) != EOF) {
    fc->b = getcharm(i->ungetc_buf);
    i->ungetc_buf = putcharm(EOF);
    return g; }
  int c = cb_getc(kcb);
  if (c == EOF) i->eof_seen = putcharm(true);
  return fc->b = c, g; }
static struct ai *_ungetc(struct ai *g, int c) {
  struct ai *fc = ai_core_of(g);
  struct ai_io *i = fc->io;
  i->ungetc_buf = putcharm(c);
  i->eof_seen = putcharm(false);
  return fc->b = c, g; }
static struct ai *_eof(struct ai *g) {
  struct ai *fc = ai_core_of(g);
  struct ai_io *i = fc->io;
  return fc->b = (getcharm(i->ungetc_buf) == EOF) && getcharm(i->eof_seen), g; }
static struct ai *_putc(struct ai *g, int c) { return cb_putc(kcb, c), g; }
static struct ai *_flush(struct ai *g) { return g; }

struct ai_io ai_stdin  = { .ap = lvm_port_io, .fd = putcharm(0), .ungetc_buf = putcharm(EOF), .eof_seen = putcharm(false) };
struct ai_io ai_stdout = { .ap = lvm_port_io, .fd = putcharm(1), .ungetc_buf = putcharm(EOF), .eof_seen = putcharm(false) };
// No separate error stream on the device; the scare face lands on the LCD too.
struct ai_io ai_stderr = { .ap = lvm_port_io, .fd = putcharm(1), .ungetc_buf = putcharm(EOF), .eof_seen = putcharm(false) };
struct ai_port_vt const ai_fd_port_vt = { _getc, _ungetc, _eof, _putc, _flush, NULL, NULL };

// --- the playdate nifs ------------------------------------------------------
// (crank ())     -- the crank angle 0..359, or () docked
// (pushed ())    -- this frame's fresh button bits (left 1 right 2 up 4
//                   down 8 B 16 A 32)
// (cur_set r c)  -- seat the console's write cursor
static lvm(ai_crank) {
  int d = K.pd->system->isCrankDocked();
  float a = K.pd->system->getCrankAngle();
  Sp[0] = d ? ai_nil : putcharm((int) a % 360);
  Ip += 1;
  return Continue(); }
static lvm(ai_pushed) {
  Sp[0] = putcharm(K.b.pushed);
  Ip += 1;
  return Continue(); }
static lvm(ai_cur_set) {
  cb_cur(kcb, getcharm(Sp[0]), getcharm(Sp[1]));
  Sp += 1;
  Ip += 1;
  return Continue(); }

static union u const
  nif_crank[]   = {{ai_crank}, {lvm_ret0}},
  nif_pushed[]  = {{ai_pushed}, {lvm_ret0}},
  nif_cur_set[] = {{lvm_cur}, {.x = putcharm(2)}, {ai_cur_set}, {lvm_ret0}};
static struct ai_def defs[] = {
  {"crank",   (intptr_t) nif_crank},
  {"pushed",  (intptr_t) nif_pushed},
  {"cur_set", (intptr_t) nif_cur_set} };

// --- the frame --------------------------------------------------------------
static void blit(void) {
  uint8_t *frame = K.pd->graphics->getFrame();
  for (uint32_t i = 0; i < NROWS; i++)
    for (uint32_t j = 0; j < NCOLS; j++) {
      uint8_t ch = cb_ch(K.cb.cb[i * NCOLS + j]);
      uint8_t const *bmp = cga_8x8[ch == '\n' ? 0 : ch];
      for (uint32_t b = 0; b < 8; b++)
        frame[LCD_ROWSIZE * (8 * i + b) + j] = bmp[b]; }
  K.pd->graphics->markUpdatedRows(0, LCD_ROWS); }

static int k_update(void *_) {
  K.pd->system->getButtonState(&K.b.current, &K.b.pushed, &K.b.released);
  if (!K.dead) {
    cb_cur(kcb, 0, 0);
    cb_fill(kcb, 0);
    K.g = ai_evals_(K.g, "(cas ())");
    if (!ai_ok(K.g)) {
      // honest face: the condition prints to the console, and the screen
      // freezes on it (reset the device to go again)
      if (ai_code_of(K.g) == ai_status_scare) ai_scare_face_(K.g);
      K.dead = 1; } }
  blit();
  return 1; }

#if TARGET_PLAYDATE
// newlib syscall stubs: love.c's strtod/strtol pull gdtoa, whose error paths
// reach abort and the stdio buffer setup; none of them can actually run here,
// the linker just wants the names.
int _write(int fd, const void *b, size_t n) { return n; }
void __attribute__((noreturn)) _exit(int c) { for (;;) ; }
int _fstat(int fd, void *st) { return -1; }
int _isatty(int fd) { return 0; }
int _kill(int pid, int sig) { return -1; }
int _getpid(void) { return 1; }
int _close(int fd) { return -1; }
long _lseek(int fd, long o, int w) { return -1; }
int _read(int fd, void *b, size_t n) { return 0; }
void *_sbrk(intptr_t n) { return (void *) -1; }
#endif

// --- entry -------------------------------------------------------------------
static void *pd_alloc(struct ai *g, void *p, size_t n) {
  return n ? K.pd->system->realloc(NULL, n) : (K.pd->system->realloc(p, 0), NULL); }

int eventHandler(PlaydateAPI *pd, PDSystemEvent event, uint32_t arg) {
  if (event != kEventInit) return 0;
  K.pd = pd;
  clockfp = pd->system->getCurrentTimeMilliseconds;
  cb_open(kcb, NROWS, NCOLS);
  kcb->flag |= cb_lnm | cb_wrap;   // console discipline + autowrap the long forms
  // first light before the bake: the egg takes a while on the device, and a
  // blank LCD reads as a hang
  for (char const *s = "; love/playdate -- baking the egg"; *s; s++)
    cb_putc(kcb, *s);
  blit();
  struct ai *g = ai_defn(ai_ini_m(pd_alloc), defs, countof(defs));
  // bound the collector well under the device's 16 MB (the Appel knob)
  if (ai_ok(g)) ai_core_of(g)->budget = (8u << 20) / sizeof(ai_word);
  K.g = ai_evals_(g, "("
#include "egg.h"
    ai_egg_pre
#include "prel.h"
    " "
#include "ev.h"
    ai_egg_post
#include "rune.h"
    " "
#include "runeseal.h"
    " "
#include "cas.h"
    "0)");
  if (ai_ok(K.g))
    pd->system->setUpdateCallback(k_update, NULL);
  return 0; }
