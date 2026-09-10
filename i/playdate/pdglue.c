// the SDK half: the only file that includes pd_api.h. every crossing flattens
// to ints and pointers here, so the seam stays word-only -- which buys the
// variadic logToConsole, whose `...` no pointer type carries. floats need no
// flattening either way: a pointer's own parameter list places an argument and
// a result is read from s0, so getCrankAngle answers straight.
#include "pd_api.h"
#include "pdglue.h"

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
