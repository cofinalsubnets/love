// the SDK half, the only file that includes pd_api.h: every crossing flattens to ints and
// pointers, so the seam stays word-only (logToConsole's `...` needs that); floats pass straight
#include "pd_api.h"
#include "../../love.h"                   // alloc, the runtime's one heap door
#include "pdglue.h"
#include "../../hornring.h"

_Static_assert(PDG_ROWSIZE == LCD_ROWSIZE, "LCD rowsize drifted");
_Static_assert(PDG_ROWS == LCD_ROWS, "LCD rows drifted");

static PlaydateAPI *PD;
static PDButtons b_current, b_pushed, b_released;

int pdg_crank_docked(void) { return PD->system->isCrankDocked(); }
int pdg_crank_deg(void) { return (int) PD->system->getCrankAngle() % 360; }
void pdg_poll_buttons(void) { PD->system->getButtonState(&b_current, &b_pushed, &b_released); }
unsigned pdg_pushed(void) { return (unsigned) b_pushed; }
unsigned pdg_held(void) { return (unsigned) b_current; }
void *pdg_realloc(void *p, size_t n) { return PD->system->realloc(p, n); }
unsigned pdg_ms(void) { return PD->system->getCurrentTimeMilliseconds(); }
void pdg_log(const char *s) { PD->system->logToConsole("%s", s); }
unsigned char *pdg_frame(void) { return PD->graphics->getFrame(); }
void pdg_mark_updated(void) { PD->graphics->markUpdatedRows(0, LCD_ROWS); }
void pdg_set_update(int (*cb)(void *)) { PD->system->setUpdateCallback(cb, NULL); }
int pdg_file_size(const char *path) {
  FileStat st;
  return PD->file->stat(path, &st) ? -1 : (int) st.size; }
// a whole bundled file into buf (<= cap bytes), -1 none: how the wake image rides the pdx
int pdg_file_read(const char *path, void *buf, unsigned cap) {
  SDFile *f = PD->file->open(path, kFileRead);
  if (!f) return -1;
  int n = PD->file->read(f, buf, cap);
  PD->file->close(f);
  return n; }

// the horn: the SDK pulls on its audio side, love pushes; hornring.h between them (lawed off
// the device by test/front/hornseat.l)
enum { pdg_hn = 1 << 17 };                // 131072 frames, ~6 s at 22.05k: a slow frame's paint
static int16_t h_buf[pdg_hn * 2];
static struct horn_ring h_ring = { h_buf, pdg_hn, 0, 0 };
static SoundSource *h_src;
// at half the device's rate each frame plays twice, the first halfway from the one before
static struct { int step; int16_t l, r; } h_up;

static int pdg_horn_pull(void *ctx, int16_t *l, int16_t *r, int len) {
  if (h_up.step == 1) return hring_pull(&h_ring, l, r, len), 1;
  int16_t sl[128], sr[128];
  for (int o = 0; o < len; o += 256) {
    int m = len - o < 256 ? (len - o + 1) / 2 : 128;
    hring_pull(&h_ring, sl, sr, m);
    for (int i = 0, j = o; i < m; i++, j += 2) {
      l[j] = (int16_t) ((h_up.l + sl[i]) >> 1), r[j] = (int16_t) ((h_up.r + sr[i]) >> 1);
      if (j + 1 < len) l[j + 1] = sl[i], r[j + 1] = sr[i];
      h_up.l = sl[i], h_up.r = sr[i]; } }
  return 1; }                             // 1: this source produced output

int pdg_horn_open(int rate) {
  if (rate != PDG_HORN_RATE && rate * 2 != PDG_HORN_RATE) return -1;
  h_ring.rd = h_ring.wr = 0;
  h_up.step = PDG_HORN_RATE / rate, h_up.l = h_up.r = 0;
  if (!h_src) h_src = PD->sound->addSource(pdg_horn_pull, NULL, 1);
  return h_src ? 0 : -1; }
int pdg_horn_push(const void *pcm, int n) { return hring_push(&h_ring, pcm, n); }
int pdg_horn_lag(void) { return (int) hring_lag(&h_ring); }
// the source stays added, playing silence: never removed from under a mid-buffer callback
void pdg_horn_close(void) { h_ring.rd = h_ring.wr = 0; }

// the SDK's realloc is the whole heap, so alloc is defined here and alloc.c not linked. on
// device this file replaces setup.c (the entry and the malloc trio); the simulator keeps it,
// and takes the host's heap: its realloc holds the device's 16 MB, which 64-bit words outgrow
#if TARGET_PLAYDATE
void *alloc(void *p, size_t n) {
  return n ? pdg_realloc(NULL, n) : (pdg_realloc(p, 0), NULL); }
#else
#include <stdlib.h>
void *alloc(void *p, size_t n) { return n ? malloc(n) : (free(p), NULL); }
#endif

static int pd_event(PlaydateAPI *pd, PDSystemEvent event, uint32_t arg) {
  if (event != kEventInit) return 0;
  PD = pd;
  love_init();
  return 0; }

#if TARGET_PLAYDATE
int eventHandlerShim(PlaydateAPI *pd, PDSystemEvent event, uint32_t arg) {
  return pd_event(pd, event, arg); }
// ldbare32 enters at _start, the SDK's link script names eventHandlerShim: both hold
int _start(PlaydateAPI *pd, PDSystemEvent event, uint32_t arg) {
  return eventHandlerShim(pd, event, arg); }
void *malloc(size_t n) { return pdg_realloc(NULL, n); }
void *realloc(void *p, size_t n) { return pdg_realloc(p, n); }
void free(void *p) { if (p) pdg_realloc(p, 0); }
#else
int eventHandler(PlaydateAPI *pd, PDSystemEvent event, uint32_t arg) {
  return pd_event(pd, event, arg); }
#endif
