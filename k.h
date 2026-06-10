// Freestanding-kernel glue shared by kmain.c and the per-arch backends.
// Combines the former free/k.h (kernel logging) and free/k_boot.h (the boot
// hand-off struct).
#pragma once
#include "l.h"

void
 k_logf(char const*, ...),
 k_vlogf(char const*, va_list),
 k_log_clear(void),
 k_log_char(char);

// k_boot -- the small struct the bootloader hand-off populates before
// kmain() runs. kmain.c reads this in meminit/fbinit; the Limine path
// fills it in limine_to_kboot(). Adding a new backend is just "write
// something that fills kboot, then jump to kmain."
#include <stdint.h>
#include <stdbool.h>

#define k_boot_ram_max 64

struct k_boot {
  uint32_t ram_n;
  struct { uintptr_t base, len; } ram[k_boot_ram_max];
  uintptr_t hhdm;                     // 0 means identity-mapped (UEFI path)
  struct {
    void    *base;                    // framebuffer linear address
    uint16_t w, h;                    // pixels
    uint32_t pitch_px;                // pixels per scanline (not bytes)
  } fb;
  bool has_fb;
};

extern struct k_boot kboot;
