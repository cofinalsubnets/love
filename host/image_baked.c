// host/image_baked.c -- the in-binary slot for the post-boot heap image (doc/snapshot.md).
// A fixed reserve in its own .image section, filled POST-LINK by the Makefile: `ai` dumps its own
// warmed heap and `objcopy --update-section .image=...` patches the bytes back in. The binary then
// loads ITS OWN dump at startup (main.c) -- identical layout by construction, so the codec's
// same-binary +delta relocation just works. Sentinel-initialized (not {0}) so the reserve lands in
// .data (PROGBITS, patchable in place), never .bss. Bump RESERVE_WORDS if the build errors that the
// image exceeds it.
#include <stdint.h>
#define RESERVE_WORDS 589824u                                  /* 4.5 MiB */
__attribute__((section(".image"))) uint64_t ai_baked_image[RESERVE_WORDS] = {1};
uintptr_t ai_baked_image_len = RESERVE_WORDS * 8u;
