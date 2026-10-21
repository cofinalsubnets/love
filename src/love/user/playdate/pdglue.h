// the SDK boundary from gcc-built pdglue.c to the mooncc side: ints and pointers only, no
// floats, no variadics, so the moon<->gcc ABI stays inside what the differential gates prove
#pragma once
#include <stddef.h>

// the 1-bit LCD geometry (pdglue.c static-asserts these against the SDK's)
#define PDG_ROWSIZE 52
#define PDG_ROWS    240

int pdg_crank_docked(void);
int pdg_crank_deg(void);                 // 0..359, whole degrees
void pdg_poll_buttons(void);             // latch this frame's button state
unsigned pdg_pushed(void);               // the latched fresh-press bits
unsigned pdg_held(void);                 // the latched bits down now
void *pdg_realloc(void *p, size_t n);    // the SDK heap (16 MB on device + sim)
unsigned pdg_ms(void);                   // milliseconds since boot
void pdg_log(const char *s);             // one line to the SDK console
unsigned char *pdg_frame(void);          // the LCD frame buffer
void pdg_mark_updated(void);             // mark every row dirty
void pdg_set_update(int (*cb)(void *));  // install the per-frame callback
int pdg_file_read(const char *path, void *buf, unsigned cap);  // whole bundled file -> buf; -1 = absent
void pdg_trail(const char *s);           // log + append to Data/trail.txt
int pdg_file_size(const char *path);     // a bundled file's bytes; -1 = absent

// the horn's device, pulled by the SDK and pushed by love. its rate or half it: horn.c
// reads a refusal as ENODEV
#define PDG_HORN_RATE 44100
int pdg_horn_open(int rate);                     // start the source; 0 ok, -1 refused
int pdg_horn_push(const void *pcm, int n);       // n bytes of interleaved stereo s16; bytes taken
int pdg_horn_lag(void);                          // frames queued and unplayed
void pdg_horn_close(void);

// main.c's: pdglue's eventHandler calls it once at init
void love_init(void);
