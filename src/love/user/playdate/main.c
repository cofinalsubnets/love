// the playdate frontend: the rune cas workbench on the crank. the console is a 50x30 quay cb
// blitted to the lcd each frame, stdout and stderr both; each update fires (cas ()).
// mooncc -t thumb2sp on device (f64 softens to __aeabi_*); the SDK is behind pdglue.c
#include "../../love.h"
#include "quay.h"
#include "pdglue.h"

#ifndef EOF
#define EOF (-1)
#endif

#define NROWS 30
#define NCOLS 50
#define kcb (&K.cb)
static struct k {
  struct g *g;
  int dead;                    // a scare froze the session; keep blitting it
  union {
    struct cb cb;
    uint8_t cb_bytes[sizeof(struct cb) + sizeof(struct cb_cell) * NROWS * NCOLS]; };
} K;

uintptr_t love_clock(void) { return pdg_ms(); }
void love_sleep(uintptr_t ms) {
  uintptr_t start = love_clock();
  if (ms) while (love_clock() - start < ms) ;
}
// a negative fd is always ready (main.c's law), and fd 0 is always at its end
bool ready(int fd, int events) { return 1; }
void wait_fds(struct wait_fd *fds, int n, uintptr_t ms) { love_sleep(ms); }

// no text input on the device: stdin is at its end from the first read
static intptr_t fd_readn(struct g *g, unsigned char *dst, uintptr_t n) {
  return -1; }
static struct g *fd_writen(struct g *g, unsigned char const *src, uintptr_t n) {
  for (uintptr_t k = 0; k < n; k++) cb_putc(kcb, src[k]);
  return g->b = (intptr_t) n, g; }
static struct g *_flush(struct g *g) { return g; }

struct fio love_stdin  = { { .ap = lvm_port_io, .vt = &love_fd_port_vt, .ungetc_buf = putcharm(EOF) }, .fd = putcharm(0) };
struct fio love_stdout = { { .ap = lvm_port_io, .vt = &love_fd_port_vt, .ungetc_buf = putcharm(EOF) }, .fd = putcharm(1) };
struct fio love_stderr = { { .ap = lvm_port_io, .vt = &love_fd_port_vt, .ungetc_buf = putcharm(EOF) }, .fd = putcharm(1) };
struct port_vt const love_fd_port_vt = { _flush, fd_writen, fd_readn, NULL };

#include "../../fdrow.h"                       // love_fd_readn / love_fd_say off the two above

// (crank ())     -- the crank angle 0..359, or () docked
// (pushed ())    -- this frame's fresh button bits (left 1 right 2 up 4
//                   down 8 B 16 A 32)
// (cur_set r c)  -- seat the console's write cursor
static lvm(crank) {
  Sp[0] = pdg_crank_docked() ? zero : putcharm(pdg_crank_deg());
  Ip += 1;
  return Continue(); }
static lvm(pushed) {
  Sp[0] = putcharm(pdg_pushed());
  Ip += 1;
  return Continue(); }
static lvm(cur_set) {
  cb_cur(kcb, getcharm(Sp[0]), getcharm(Sp[1]));
  Sp += 1;
  Ip += 1;
  return Continue(); }

// love_horn_seat: horn.c asks these, as inle's hda.c; always stereo (horn_land doubles mono)
int k_horn_open(int rate) { return pdg_horn_open(rate); }
intptr_t k_horn_write(unsigned char const *src, uintptr_t n) {
  return pdg_horn_push(src, (int) n); }
uintptr_t k_horn_lag(void) { return (uintptr_t) pdg_horn_lag(); }
void k_horn_close(void) { pdg_horn_close(); }

static union u const
  nif_crank[]   = {{crank}, {lvm_ret0}},
  nif_pushed[]  = {{pushed}, {lvm_ret0}},
  nif_cur_set[] = {{lvm_cur}, {.x = putcharm(2)}, {cur_set}, {lvm_ret0}};
static struct def defs[] = {
  {"crank",   {.k = nif_crank}},
  {"pushed",  {.k = nif_pushed}},
  {"cur_set", {.k = nif_cur_set}} };

static void blit(void) {
  uint8_t *frame = pdg_frame();
  for (uint32_t i = 0; i < NROWS; i++)
    for (uint32_t j = 0; j < NCOLS; j++) {
      uint8_t ch = cb_437(cb_base(kcb, K.cb.cb[i * NCOLS + j].g));
      uint8_t const *bmp = cga_8x8[ch];
      for (uint32_t b = 0; b < 8; b++)
        frame[PDG_ROWSIZE * (8 * i + b) + j] = bmp[b]; }
  pdg_mark_updated(); }

static int k_update(void *_) {
  pdg_poll_buttons();
  if (!K.dead) {
    cb_cur(kcb, 0, 0);
    cb_fill(kcb, 0);
    K.g = evals_(K.g, "(cas ())");
    if (!ok(K.g)) {
      // the screen freezes on the condition until a reset
      if (code_of(K.g) == status_scare) scare_face(K.g);
      K.dead = 1; } }
  blit();
  return 1; }

#if TARGET_PLAYDATE
// newlib stubs for gdtoa's unreachable error paths: the linker wants the names
int _write(int fd, const void *b, size_t n) { return n; }
void _exit(int c) { for (;;) ; }
int _fstat(int fd, void *st) { return -1; }
int _isatty(int fd) { return 0; }
int _kill(int pid, int sig) { return -1; }
int _getpid(void) { return 1; }
int _close(int fd) { return -1; }
long _lseek(int fd, long o, int w) { return -1; }
int _read(int fd, void *b, size_t n) { return 0; }
void *_sbrk(intptr_t n) { return (void *) -1; }
#endif

// rune does not declare itself, so the wrapper is here; q and kanren ride post
static char const src_mods[] =
"(module 'rune "
#include "rune.h"
")"
;

void love_init(void) {
  pdg_log("love: init");
  cb_open(kcb, NROWS, NCOLS, 0);
  kcb->flag |= cb_lnm | cb_wrap;   // console discipline + autowrap the long forms
  // wake the pdx's baked image first: the on-device bake outlasts the watchdog. a refusal
  // (the 64-bit simulator's, always) answers NULL and bakes from source
  struct g *g0 = NULL;
  uintptr_t t0 = love_clock();
  { enum { imgcap = 2u << 20 };
    void *ib = pdg_realloc(NULL, imgcap);
    int n = ib ? pdg_file_read("love-pd.img", ib, imgcap) : -1;
    if (n > 0) g0 = love_image_load(ib, (uintptr_t) n, 0);
    if (ib) pdg_realloc(ib, 0); }
  int woke = g0 != NULL;
  pdg_log(woke ? "love: image awake" : "love: no image -- baking the egg");
  for (char const *s = woke ? "; src/love/user/playdate -- image awake"
                            : "; src/love/user/playdate -- baking the egg"; *s; s++)
    cb_putc(kcb, *s);
  blit();
  struct g *g = defn(woke ? g0 : ini(), defs, countof(defs));
  // and the LvNif section, as main.c drains it: horn.c's rows ride it
  g = defn(g, __start_love_nifs, __stop_love_nifs - __start_love_nifs);
  // born: this wake's cost, as main.c defines it; the egg lane's egg.l pins its own
  if (woke && ok(g = push(g, 1, putcharm((intptr_t) (love_clock() - t0))))) {
    g = defv(g, "born");
    if (ok(g)) g->sp++; }
  pdg_log(ok(g) ? "love: core up" : "love: core FAILED");
  // a quarter of the device's 16 MB: a major holds old and new pools, so the peak is twice this
  if (ok(g)) g->budget = (4u << 20) / sizeof(word);
  if (woke) {
    K.g = love_open(g);           // the waker opens its own session (the bake carries none)
    pdg_log("love: woke -- workbench up");
    if (ok(K.g)) pdg_set_update(k_update);
    return; }
  K.g = egg(g,
#include "egg.h"
    ,
#include "prel.h"
    " "
#include "ev.h"
    ,
#include "post.h"
    );
  K.g = evals_(K.g, src_mods);
  K.g = evals_(K.g,
    "(borrow 'kanren)"
    " "
    "(borrow 'rune)"
    " "
#include "cas.h"
    " 0");
  // the crank's evals defglob in the session, never in the base
  K.g = love_open(K.g);
  pdg_log(ok(K.g) ? "love: boot eval ok" : "love: boot eval FAILED");
  if (ok(K.g))
    pdg_set_update(k_update);
  else if (code_of(K.g) == status_scare)
    scare_face(K.g),           // the condition lands on the cb...
    blit();                       // ...and freezes on the LCD
}
