// noblob.c -- src.c's carried blobs for a link without out/src.o and out/moonlibc.o (love0,
// gate links). kept out of host_c: each link names it or the laid objects, never both.
// the length says whether anything is carried; the arrays are one zero, as [0] is not portable
#include "love.h"
const unsigned char
 srctree[1] = {0},
 rootfs[1] = {0},
 rtzst_tab[1] = {0};
const uintptr_t
 rootfs_len = 0,
 srctree_len = 0,
 rtzst_tab_len = 0;
