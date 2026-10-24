// the playdate frontend: the rune cas workbench on the crank, or with PD_STONES lore's stones.
// the console is a 50x30 quay cb blitted to the lcd each frame, stdout and stderr both; each
// update fires (cas ()), or (pd-frame ()) whose picture (lcd ..) dithers under the console
// mooncc -t thumb2sp on device (f64 softens to __aeabi_*); the SDK is behind pdglue.c
#include "../../love.h"
#include "quay.h"
#include "pdglue.h"

#ifndef EOF
#define EOF (-1)
#endif
#ifndef PD_STONES
#define PD_STONES 0
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

#if PD_STONES
// (held ())      -- the buttons down now, the same bits as pushed
// (lcd f w h)    -- f's w by h 0xrrggbb pixels, the screen's 400 by 240 stretched over them,
//                   its luma ordered-dithered one bit a screen pixel; 1 drawn, 0 refused
static lvm(held) {
  Sp[0] = putcharm(pdg_held());
  Ip += 1;
  return Continue(); }
static uint8_t const bayer8[64] = {
   0, 32,  8, 40,  2, 34, 10, 42, 48, 16, 56, 24, 50, 18, 58, 26,
  12, 44,  4, 36, 14, 46,  6, 38, 60, 28, 52, 20, 62, 30, 54, 22,
   3, 35, 11, 43,  1, 33,  9, 41, 51, 19, 59, 27, 49, 17, 57, 25,
  15, 47,  7, 39, 13, 45,  5, 37, 63, 31, 55, 23, 61, 29, 53, 21 };
static lvm(lcd) {
  word f = Sp[0];
  intptr_t w = getcharm(Sp[1]), h = getcharm(Sp[2]);
  int okf = galaxyp(f) && tray(f)->type == love_Z && w > 0 && h > 0 && tray_nelem(tray(f)) >= (uintptr_t) (w * h);
  if (okf) {
    uint8_t *fr = pdg_frame();
    for (intptr_t y = 0; y < PDG_ROWS; y++) {
      intptr_t sy = y * h / PDG_ROWS;
      for (intptr_t xb = 0; xb < 400 / 8; xb++) {
        uint8_t byte = 0;
        for (intptr_t b = 0; b < 8; b++) {
          intptr_t x = 8 * xb + b;
          uint32_t c = (uint32_t) tray_get_int(tray(f), (uintptr_t) (sy * w + x * w / 400));
          uint32_t l = (77 * (c >> 16 & 255) + 150 * (c >> 8 & 255) + 29 * (c & 255)) >> 8;
          byte |= (uint8_t) ((l > 4u * bayer8[(y & 7) * 8 + (x & 7)] + 2u) << (7 - b)); }
        fr[PDG_ROWSIZE * y + xb] = byte; } } }
  Sp += 2;
  Sp[0] = okf ? putcharm(1) : zero;
  Ip += 1;
  return Continue(); }
#endif

// love_horn_seat: horn.c asks these, as inle's hda.c; always stereo (horn_land doubles mono)
int k_horn_open(int rate) { return pdg_horn_open(rate); }
intptr_t k_horn_write(unsigned char const *src, uintptr_t n) {
  return pdg_horn_push(src, (int) n); }
uintptr_t k_horn_lag(void) { return (uintptr_t) pdg_horn_lag(); }
void k_horn_close(void) { pdg_horn_close(); }

static union u const
  nif_crank[]   = {{crank}, {lvm_ret0}},
  nif_pushed[]  = {{pushed}, {lvm_ret0}},
  nif_cur_set[] = {{lvm_cur}, {.x = putcharm(2)}, {cur_set}, {lvm_ret0}}
#if PD_STONES
  , nif_held[]  = {{held}, {lvm_ret0}},
  nif_lcd[]     = {{lvm_cur}, {.x = putcharm(3)}, {lcd}, {lvm_ret0}}
#endif
  ;
static struct def defs[] = {
  {"crank",   {.k = nif_crank}},
  {"pushed",  {.k = nif_pushed}},
  {"cur_set", {.k = nif_cur_set}},
#if PD_STONES
  {"held",    {.k = nif_held}},
  {"lcd",     {.k = nif_lcd}},
#endif
  };

// the console over the frame: every cell, or with PD_STONES only the written ones, white on black
static void blit(void) {
  uint8_t *frame = pdg_frame();
  for (uint32_t i = 0; i < NROWS; i++)
    for (uint32_t j = 0; j < NCOLS; j++) {
      uint8_t ch = cb_437(cb_base(kcb, K.cb.cb[i * NCOLS + j].g));
      uint8_t const *bmp = cga_8x8[ch];
      if (PD_STONES && (ch == 0 || ch == ' ') && !K.dead) continue;
      for (uint32_t b = 0; b < 8; b++)
        frame[PDG_ROWSIZE * (8 * i + b) + j] = PD_STONES ? (uint8_t) ~bmp[b] : bmp[b]; }
  pdg_mark_updated(); }

static int k_update(void *_) {
  pdg_poll_buttons();
  if (!K.dead) {
    cb_cur(kcb, 0, 0);
    cb_fill(kcb, 0);
    K.g = evals_(K.g, PD_STONES ? "(pd-frame ())" : "(cas ())");
    if (!ok(K.g)) {
      // the screen freezes on the condition until a reset
      if (code_of(K.g) == status_scare) scare_face(K.g);
      K.dead = 1; } }
  blit();
  return 1; }

// the console's written rows into the log, where the simulator shows them
static void log_cb(void) {
  for (uint32_t i = 0; i < NROWS; i++) {
    char line[NCOLS + 1];
    uint32_t n = 0;
    for (uint32_t j = 0; j < NCOLS; j++) {
      uint8_t ch = cb_437(cb_base(kcb, K.cb.cb[i * NCOLS + j].g));
      line[j] = ch >= 32 && ch < 127 ? (char) ch : ' ';
      if (line[j] != ' ') n = j + 1; }
    line[n] = 0;
    if (n) pdg_log(line); } }

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
#if PD_STONES
""
#else
"(module 'rune "
#include "rune.h"
")"
#endif
;

void love_init(void) {
  pdg_log("love: init");
  cb_open(kcb, NROWS, NCOLS, 0);
  kcb->flag |= cb_lnm | cb_wrap;   // console discipline + autowrap the long forms
  // wake the pdx's baked image first: the on-device bake outlasts the watchdog. a refusal
  // (the 64-bit simulator's, always) answers NULL and bakes from source
  struct g *g0 = NULL;
  uintptr_t t0 = love_clock();
  { int imgcap = pdg_file_size("love-pd.img");
    void *ib = imgcap > 0 ? pdg_realloc(NULL, (size_t) imgcap) : NULL;
    int n = ib ? pdg_file_read("love-pd.img", ib, (unsigned) imgcap) : -1;
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
#if PD_STONES
  // ..but the stones live at 3 MB: most of the device, and a major at once so the woken pool
  // is sized under that rather than as the image left it
  // counted in device words, so the 64-bit simulator holds what the device does
  if (ok(g)) g->budget = (6u << 20) / sizeof(uint32_t);
  if (woke && ok(g) && ok(g = gen_major(g, 0, NULL))) g->major_live0 = (uintptr_t) (g->major_hp - g->major_base);
#endif
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
#if PD_STONES
#include "stones.h"
#else
    "(borrow 'kanren)"
    " "
    "(borrow 'rune)"
    " "
#include "cas.h"
#endif
    " 0");
  // the crank's evals defglob in the session, never in the base
  K.g = love_open(K.g);
  pdg_log(ok(K.g) ? "love: boot eval ok" : "love: boot eval FAILED");
  if (ok(K.g))
    pdg_set_update(k_update);
  else if (code_of(K.g) == status_scare)
    scare_face(K.g),           // the condition lands on the cb...
    blit(),                       // ...and freezes on the LCD
    log_cb();                     // ...and the console's log
}
