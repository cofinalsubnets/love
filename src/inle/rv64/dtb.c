// dtb -> kboot on rv64: S-mode under SBI, called after mkboot.l turns sv39 on, so the tree
// reads through the window. sv39's upper half starts at 0xffffffc0_00000000; four gigapages
// carry 0..4G. the live SBI firmware sits under the image, so dtb.h's floor keeps it; the tree
// lies in RAM given away, but is read once, before there is a heap
#define k_hhdm    0xffffffc000000000ull
#define k_map_top 0x100000000ull
#include "dtb.h"
