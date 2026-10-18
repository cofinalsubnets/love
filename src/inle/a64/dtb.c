// dtb -> kboot on a64, x64/pvh.c's twin: runs high with the stub's hhdm over physical 0..4G
// already mapped; the walk is dtb.h's. headless: -kernel hands over no framebuffer
#define k_hhdm    0xffff800000000000ull
#define k_map_top 0x100000000ull
#include "dtb.h"
