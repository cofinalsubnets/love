#ifndef _g_font_h
#define _g_font_h
#include <stdint.h>
struct gf { uint8_t *glyphs, w, h; };
extern uint8_t cga_8x8[256][8];
#endif
