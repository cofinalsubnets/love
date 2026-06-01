// k_boot -- the small struct that both bootloader backends populate
// before they call kmain(). main.c reads this in meminit/fbinit; the
// Limine path fills it in limine_to_kboot(), the UEFI path fills it in
// efi_main(). Adding a new backend is just "write something that fills
// kboot, then jump to kmain."
#pragma once
#include <stdint.h>
#include <stdbool.h>

#define K_BOOT_RAM_MAX 64

struct k_boot {
  uint32_t ram_n;
  struct { uintptr_t base, len; } ram[K_BOOT_RAM_MAX];
  uintptr_t hhdm;                     // 0 means identity-mapped (UEFI path)
  struct {
    void    *base;                    // framebuffer linear address
    uint16_t w, h;                    // pixels
    uint32_t pitch_px;                // pixels per scanline (not bytes)
  } fb;
  bool has_fb;
};

extern struct k_boot kboot;
