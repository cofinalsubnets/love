// the SDK half: the only file that includes pd_api.h. every crossing flattens
// to ints and pointers here, so the seam stays word-only -- which buys the
// variadic logToConsole, whose `...` no pointer type carries. floats need no
// flattening either way: a pointer's own parameter list places an argument and
// a result is read from s0, so getCrankAngle answers straight.
#include "pd_api.h"
#include "pdglue.h"
#include "../hornring.h"

_Static_assert(PDG_ROWSIZE == LCD_ROWSIZE, "LCD rowsize drifted");
_Static_assert(PDG_ROWS == LCD_ROWS, "LCD rows drifted");

static PlaydateAPI *PD;
static PDButtons b_current, b_pushed, b_released;

int pdg_crank_docked(void) { return PD->system->isCrankDocked(); }
int pdg_crank_deg(void) { return (int) PD->system->getCrankAngle() % 360; }
void pdg_poll_buttons(void) { PD->system->getButtonState(&b_current, &b_pushed, &b_released); }
unsigned pdg_pushed(void) { return (unsigned) b_pushed; }
void *pdg_realloc(void *p, size_t n) { return PD->system->realloc(p, n); }
unsigned pdg_ms(void) { return PD->system->getCurrentTimeMilliseconds(); }
void pdg_log(const char *s) { PD->system->logToConsole("%s", s); }
unsigned char *pdg_frame(void) { return PD->graphics->getFrame(); }
void pdg_mark_updated(void) { PD->graphics->markUpdatedRows(0, LCD_ROWS); }
void pdg_set_update(int (*cb)(void *)) { PD->system->setUpdateCallback(cb, NULL); }
// read a whole bundled data file into buf (<= cap bytes); -1 = no file.
// the wake image rides the pdx this way (kFileRead reads the bundle).
int pdg_file_read(const char *path, void *buf, unsigned cap) {
  SDFile *f = PD->file->open(path, kFileRead);
  if (!f) return -1;
  int n = PD->file->read(f, buf, cap);
  PD->file->close(f);
  return n; }

// --- the horn's device -----------------------------------------------------------
// the SDK PULLS -- an AudioSourceFunction, one buffer per channel, as many frames as it
// wants -- and the horn PUSHES interleaved stereo. i/hornring.h is the ring between
// them, shared with the test frontend so the awkward half is lawed off the device
// (t/front/hornseat.l); what is here is only the SDK's own shape.
//
// the pull runs on the audio side -- a thread in the simulator, a DMA refill on the
// device -- and the push on love's, which is the single-producer/single-consumer the
// ring is written for.
enum { pdg_hn = 1 << 14 };                // 16384 frames, ~370 ms at 44.1k
static int16_t h_buf[pdg_hn * 2];
static struct horn_ring h_ring = { h_buf, pdg_hn, 0, 0 };
static SoundSource *h_src;

static int pdg_horn_pull(void *ctx, int16_t *l, int16_t *r, int len) {
  hring_pull(&h_ring, l, r, len);
  return 1; }                             // 1: this source produced output

int pdg_horn_open(int rate) {
  if (rate != PDG_HORN_RATE) return -1;
  h_ring.rd = h_ring.wr = 0;
  if (!h_src) h_src = PD->sound->addSource(pdg_horn_pull, NULL, 1);
  return h_src ? 0 : -1; }
int pdg_horn_push(const void *pcm, int n) { return hring_push(&h_ring, pcm, n); }
int pdg_horn_lag(void) { return (int) hring_lag(&h_ring); }
// the source stays added and plays silence: taking it out from under a callback that
// may be mid-buffer buys nothing this seat needs.
void pdg_horn_close(void) { h_ring.rd = h_ring.wr = 0; }

// on device this file also replaces the SDK's setup.c, which did three things: name
// the entry, capture the realloc, and answer malloc/free over it. the malloc trio
// matters because moonlibc's own reaches for a heap this seat has no syscall to ask
// for -- the SDK realloc IS the heap here, 16 MB of it. the SIMULATOR keeps setup.c
// (it is an ordinary hosted .so), so there the shim and the trio are its.
static int pd_event(PlaydateAPI *pd, PDSystemEvent event, uint32_t arg) {
  if (event != kEventInit) return 0;
  PD = pd;
  love_init();
  return 0; }

#if TARGET_PLAYDATE
int eventHandlerShim(PlaydateAPI *pd, PDSystemEvent event, uint32_t arg) {
  return pd_event(pd, event, arg); }
// ldbare32 takes _start for e_entry and the SDK's link script names eventHandlerShim;
// a loader may read either, so both are true here and the named one is the real function.
int _start(PlaydateAPI *pd, PDSystemEvent event, uint32_t arg) {
  return eventHandlerShim(pd, event, arg); }
void *malloc(size_t n) { return pdg_realloc(NULL, n); }
void *realloc(void *p, size_t n) { return pdg_realloc(p, n); }
void free(void *p) { if (p) pdg_realloc(p, 0); }
#else
int eventHandler(PlaydateAPI *pd, PDSystemEvent event, uint32_t arg) {
  return pd_event(pd, event, arg); }
#endif
