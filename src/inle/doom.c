// src/inle/doom.c -- doomgeneric's platform doors and the nifs that drive it. 0BSD glue, built
// only with DOOM=1 (dl/doomgeneric, dl/doom1.wad).
//   (doom ())             inle: runs the game whole, answering when doom quits
//   (doom-start wad)      host: set up with that IWAD -> 1 | 0 (already running)
//   (doom-tick ())        one frame -> 1 drawn, 0 not, -1 once the game has quit
//   (doom-frame cask)     copy the frame (640x400 BGRX) into the cask -> bytes copied
//   (doom-key k pressed)  queue a key (doomkeys.h's codes) -> ()
// on inle the WAD is a baked ramfs row (k_baked), read through sys.c's fopen
#include "love.h"
#include "vfs.h"
#include <stdint.h>
#include <string.h>
#include "doomgeneric.h"
#include "doomkeys.h"
#include "i_system.h"

bool k_fb(volatile uint32_t **p, int *w, int *h, int *pitch);
void k_scan_arm(int on);
int k_scan_pop(void);
uintptr_t k_clock_ms(void);
void k_sleep(uintptr_t ms);
void k_fb_touch(void);

// laid by src/tools/mkblob.l
extern unsigned char const doom_wad[];
extern uintptr_t const doom_wad_len;

// kmain.c's weak hook: one baked row, mtime 0 because the blob carries none
int k_baked(struct vfs_file *rows, int cap) {
 if (rows && cap > 0)
  rows[0] = (struct vfs_file) { "usr/share/doom1.wad", (char const *) doom_wad, doom_wad_len, 0 };
 return 1; }

static bool hosted(void) { return __love_osv >= 0; }

#define dh_keys 64
static struct {
 uintptr_t epoch;
 int keys[dh_keys];                  // pressed << 8 | key
 unsigned kh, kt;
 int frame, started, quit;
 char wad[256];
} dh;

// doom's quit returns after its exit hooks; registered first, this runs last
static void dg_quit(void) { dh.quit = 1; }

// ENDOOM ends in exit(), no door on the kernel and too early on the host
extern int show_endoom;
void DG_Init(void) {
 dh.epoch = hosted() ? love_clock() : k_clock_ms();
 show_endoom = 0;
 if (!hosted()) k_scan_arm(1); }

// the frame centred, unscaled: a smaller mode shows the part that fits
void DG_DrawFrame(void) {
 if (hosted()) { dh.frame = 1; return; }
 volatile uint32_t *fb;
 int w, h, pitch;
 if (!k_fb(&fb, &w, &h, &pitch)) return;
 int cw = w < DOOMGENERIC_RESX ? w : DOOMGENERIC_RESX,
     ch = h < DOOMGENERIC_RESY ? h : DOOMGENERIC_RESY,
     ox = (w - cw) / 2, oy = (h - ch) / 2;
 for (int y = 0; y < ch; y++) {
  volatile uint32_t *d = fb + (uintptr_t) (y + oy) * pitch + ox;
  uint32_t const *s = DG_ScreenBuffer + (uintptr_t) y * DOOMGENERIC_RESX;
  for (int x = 0; x < cw; x++) d[x] = s[x]; }
 k_fb_touch(); }

void DG_SleepMs(uint32_t ms) { if (hosted()) love_sleep(ms); else k_sleep(ms); }

uint32_t DG_GetTicksMs(void) {
 return (uint32_t) ((hosted() ? love_clock() : k_clock_ms()) - dh.epoch); }

void DG_SetWindowTitle(char const *t) { }

// PS/2 set 1 make codes; an extended key wears 0x100 (k_scan_pop's fold)
static char const sc_ascii[] =
  "\0\0" "1234567890-=" "\0\0" "qwertyuiop[]" "\0\0" "asdfghjkl;'`"
  "\0" "\\" "zxcvbnm,./";
static unsigned char sc_key(int sc) {
 switch (sc) {
  case 0x01: return KEY_ESCAPE;
  case 0x0e: return KEY_BACKSPACE;
  case 0x0f: return KEY_TAB;
  case 0x1c: case 0x11c: return KEY_ENTER;
  case 0x1d: case 0x11d: return KEY_FIRE;          // either ctrl fires
  case 0x2a: case 0x36: return KEY_RSHIFT;
  case 0x38: case 0x138: return KEY_LALT;
  case 0x39: return KEY_USE;                       // space
  case 0x3a: return KEY_CAPSLOCK;
  // the arrows and the keypad alike: doom's KEYP_8 is KEY_UPARROW
  case 0x48: case 0x148: return KEY_UPARROW;
  case 0x50: case 0x150: return KEY_DOWNARROW;
  case 0x4b: case 0x14b: return KEY_LEFTARROW;
  case 0x4d: case 0x14d: return KEY_RIGHTARROW;
  case 0x47: case 0x147: return KEY_HOME;
  case 0x4f: case 0x14f: return KEY_END;
  case 0x49: case 0x149: return KEY_PGUP;
  case 0x51: case 0x151: return KEY_PGDN;
  case 0x52: case 0x152: return KEY_INS;
  case 0x53: case 0x153: return KEY_DEL;
  default: break; }
 if (sc >= 0x3b && sc <= 0x44) return (unsigned char) (0x80 + sc);   // F1..F10
 if (sc > 0 && sc < (int) sizeof sc_ascii - 1) return (unsigned char) sc_ascii[sc];
 return 0; }

int DG_GetKey(int *pressed, unsigned char *key) {
 if (hosted()) {
  if (dh.kh == dh.kt) return 0;
  int v = dh.keys[dh.kh++ % dh_keys];
  return *pressed = v >> 8 & 1, *key = (unsigned char) v, 1; }
 for (;;) {
  int c = k_scan_pop();
  if (c < 0) return 0;
  unsigned char k = sc_key((c & ~0x80) | (c & 0x100));
  if (!k) continue;
  return *pressed = !(c & 0x80), *key = k, 1; } }

// doom keeps argv for the run, so never the heap's
static char *dg_argv[4];
static void dg_create(void) {
 dg_argv[0] = (char*) "doom", dg_argv[1] = (char*) "-iwad", dg_argv[2] = dh.wad, dg_argv[3] = 0;
 I_AtExit(dg_quit, true);
 doomgeneric_Create(3, dg_argv); }

static void doom_run(void) {
 memcpy(dh.wad, "/usr/share/doom1.wad", 21);   // the baked row
 for (dg_create(); !dh.quit;) doomgeneric_Tick();
 k_scan_arm(0); }

static lvm(lvm_doom) {
 doom_run();
 love_musttail return Next(1); }

// the IWAD path is doom's for the run, so it is copied out of the heap
static lvm(lvm_doom_start) {
 word x = Sp[0];
 if (dh.started || !hosted() || !strp(x) || len(str(x)) >= sizeof dh.wad)
  love_musttail return Answer(putcharm(0));
 memcpy(dh.wad, txt(str(x)), len(str(x)));
 dh.wad[len(str(x))] = 0;
 dh.started = 1;
 dg_create();
 love_musttail return Answer(putcharm(1)); }

static lvm(lvm_doom_tick) {
 if (!dh.started) love_musttail return Answer(putcharm(0));
 if (dh.quit) love_musttail return Answer(putcharm(-1));
 dh.frame = 0;
 doomgeneric_Tick();
 love_musttail return Answer(putcharm(dh.frame)); }

static lvm(lvm_doom_frame) {
 word x = Sp[0];
 uintptr_t n = 0;
 if (dh.started && caskp(x) && DG_ScreenBuffer) {
  struct str *s = cask(x)->str;
  n = len(s) < DOOMGENERIC_RESX * DOOMGENERIC_RESY * 4 ? len(s) : DOOMGENERIC_RESX * DOOMGENERIC_RESY * 4;
  memcpy(txt(s), DG_ScreenBuffer, n); }
 love_musttail return Answer(putcharm((intptr_t) n)); }

// a full queue drops the oldest
static lvm(lvm_doom_key) {
 word k = Sp[0], p = Sp[1];
 if (charmp(k)) {
  if (dh.kt - dh.kh == dh_keys) dh.kh++;
  dh.keys[dh.kt++ % dh_keys] = (int) (getcharm(k) & 0xff) | (p != ZeroPoint && (!charmp(p) || getcharm(p))) << 8; }
 Sp[1] = ZeroPoint;
 love_musttail return Nextp(1, 1); }

LvDef("doom", doom, 1, NULL);
LvDef("doom-start", doom_start, 1, NULL);
LvDef("doom-tick", doom_tick, 1, NULL);
LvDef("doom-frame", doom_frame, 1, NULL);
LvDef("doom-key", doom_key, 2, NULL);
