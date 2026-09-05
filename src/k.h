// Freestanding-kernel glue shared by kmain.c and the per-arch backends.
// Combines the former src/k.h (kernel logging) and free/k_boot.h (the boot
// hand-off struct).
#pragma once
#include "love.h"

void kputc(int c), kputs(char const *s), kputn(uintptr_t n, int base);

// k_boot -- the small struct the bootloader hand-off populates before
// kmain() runs. kmain.c reads this in meminit/fbinit; each door fills it
// its own way (pvh_to_kboot, the UEFI loader, dtb.c). Adding a new backend
// is just "write something that fills kboot, then jump to kmain."
#include <stdint.h>
#include <stdbool.h>

// khhdm -- the higher-half direct-map offset (physical P is reachable at
// khhdm + P). Defined in kmain.c. 0 means identity-mapped.
extern uintptr_t khhdm;
extern uint64_t kticks;                // timer ticks, counted up by the arch's irq
extern uint8_t vectors[];              // the trap entry (mkvec.l)
void fbdraw(void);                     // kmain.c: paint the console ring to the framebuffer

// the arch backend (src/<a>_arch.c) gives kmain these
void archinit(void), serial_init(void), serial_putc(int), k_reset(void), k_fault_trigger(intptr_t n);
uint64_t k_rtc(void);                  // the machine's own clock, unix seconds (0 = none)

// the x64 virtualization doors (src/x64_svm.c, src/x64_vmx.c)
uintptr_t k_svm_need(void), k_vmx_need(void);
bool k_svm_ok(void), k_vmx_ok(void);
int k_svm_spike(void *mem, uint64_t *code, uint64_t *rax, uint64_t *rip),
    k_vmx_spike(void *mem, uint64_t *reason, uint64_t *rax, uint64_t *rip, uint64_t *err);

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
 bool has_fb; // FIXME how is this different from fb.base == NULL
 // the wall date at boot, UNIX SECONDS -- what makes ai_clock a clock and not an
 // uptime. NO door answers it now, so every one falls back to the machine's RTC
 // in kmain -- a door that learns a date may still fill this. ⚠ 0 is "nobody
 // knew", not midnight 1970: a stat
 // then reads as its own uptime, which is wrong but at least visibly so.
 uint64_t date;
 // the boot command line, copied whole at hand-off (PVH's start_info, the DTB's
 // /chosen bootargs, and love.cmd beside love.elf on an ESP, firmware carrying
 // no line of its own). "" is a plain boot: the love-side split leaves cmdline
 // seatless and the console shell takes over.
 char cmdline[256]; };

extern struct k_boot kboot;

// copy a hand-off cmdline into kboot; n bounds a source that may not be
// NUL-terminated (the DTB prop), ~0 for the C-string doors.
static inline void k_cmdline(char const *s, uintptr_t n) {
 uintptr_t i = 0;
 for (; i < n && i + 1 < sizeof kboot.cmdline && s[i]; i++) kboot.cmdline[i] = s[i];
 kboot.cmdline[i] = 0; }

// hand kmain one usable span of RAM. every backend walks its own map (PVH's
// e820, the DTB's /memory) and lands here; a span too small to hold a pointer
// pair is not worth a row.
static inline void k_ram_give(uint64_t base, uint64_t len) {
 if (len < 2 * sizeof(uintptr_t) || kboot.ram_n >= k_boot_ram_max) return;
 kboot.ram[kboot.ram_n].base = base;
 kboot.ram[kboot.ram_n].len  = len;
 kboot.ram_n++; }
