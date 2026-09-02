// dtb -> kboot on riscv64: the aarch64 door's twin, and the same walk (dtb.h) behind
// two of this stub's numbers. Entry is S-mode under SBI -- the firmware hands a0 the
// hartid and a1 the device tree, and mkboot.l's lane turns sv39 on and jumps high
// before calling here, so the tree is read through the window like everywhere else.
//
// Sv39 puts the upper half at 0xffffffc0_00000000, which is where the window starts;
// four gigapages carry physical 0..4G, and a bank past that edge is trimmed.
//
// Two riscv facts the walk already answers. The firmware lives BELOW the kernel
// (0x8000_0000..0x8020_0000 on qemu virt) and is still running -- handing it to the
// heap would clobber the SBI an ecall jumps into -- and k_image_top is above it, so
// the one "everything under the image is spoken for" line covers firmware and kernel
// together. The tree itself is laid HIGH here rather than at the RAM base, so its
// pages do fall in a span we give away; it is read once, before there is a heap to
// give anything to, and nothing reads it again.
#define k_hhdm    0xffffffc000000000ull
#define k_map_top 0x100000000ull
#include "dtb.h"
