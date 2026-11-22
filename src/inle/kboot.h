// the boot hand-off: each door fills it its own way (pvh_to_kboot, the UEFI loader, dtb.c),
// then kmain runs. stdint and stdbool alone, so uefi/loader.c includes it as k.h does
#pragma once
#include <stdint.h>
#include <stdbool.h>

#define k_boot_ram_max 64

struct k_boot {
 uint32_t ram_n;
 struct { uintptr_t base, len; } ram[k_boot_ram_max];
 uintptr_t hhdm;                     // 0 means identity-mapped
 struct {
  void    *base;                    // framebuffer linear address
  uint16_t w, h;                    // pixels
  uint32_t pitch_px;                // pixels per scanline (not bytes)
  uint8_t  scale;                   // pixels per glyph pixel; 0 = kmain's fbscale picks
  // the most pixels a resizable screen (the wasm canvas) may ever hold, kept out of the heap; 0 = w*h
  uint32_t cap_px;
 } fb;
 bool has_fb; // FIXME how is this different from fb.base == NULL
 uint64_t date;                      // the wall date at boot, unix seconds; 0 = unknown, kmain asks the rtc
 char cmdline[1024];                 // "" is a plain boot: the console shell; the pi's firmware leads with ~230 of its own
 // a heap image the door carries (the wasm page's), woken before baked_pick; 0 = none
 void const *image;
 uintptr_t image_len;
 // qemu's -initrd or PVH's first module, read-only at /proc/initrd; 0 = none
 void const *initrd;
 uintptr_t initrd_len;
 // a guest of the firmware (uefi/loader.c with love.stay beside it): boot services live on,
 // the devices stay theirs. 0 = we own the machine
 void *efi_st;                       // the EFI system table
 void *efi_image;                    // our image handle, LoadImage's parent
 uintptr_t (*efi_call)(void *fn, uintptr_t a, uintptr_t b, uintptr_t c, uintptr_t d, uintptr_t e, uintptr_t f);
 void *efi_back;                     // a protocol's ms entry: calls the sysv fn its second word holds
 uint64_t tsc0, tsc_khz; };          // the clock: the tsc at the hand-off, and its rate
