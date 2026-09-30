// dtb -> kboot on a64: the C half of mkboot.l's hand-off (x64/pvh.c's twin).
// Runs high, MMU on, with the stub's hhdm window (0xffff8000_00000000 over physical
// 0..4G) already mapped; reads the flat device tree qemu lays at the RAM base and
// fills kboot the way every door fills it. The walk is dtb.h's, shared with the riscv
// door; the two numbers below are this stub's. Headless by construction -- the -kernel
// door hands over no framebuffer, so has_fb stays false and kmain runs on serial.
#define k_hhdm    0xffff800000000000ull
#define k_map_top 0x100000000ull
#include "dtb.h"
