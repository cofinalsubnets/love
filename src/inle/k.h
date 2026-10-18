// kernel glue shared by kmain.c and the per-arch backends: logging and the boot hand-off
#pragma once
#include "love.h"

void kputc(int c), kputs(char const *s), kputn(uintptr_t n, int base);

// k_boot: each door fills it its own way (pvh_to_kboot, the UEFI loader, dtb.c), then kmain runs
#include <stdint.h>
#include <stdbool.h>

// the higher-half direct map: physical P at khhdm + P; 0 = identity-mapped
extern uintptr_t khhdm;
// the image window: physical P runs at k_xw + P. x64 runs high, leaving the low half to a process
#if defined(__x86_64__)
#define k_xw 0xffffff8000000000ull
#else
#define k_xw 0ull
#endif
extern uint64_t kticks;                // timer ticks, counted up by the arch's irq
extern uint8_t vectors[];              // the trap entry (mkvec.l)
void fbdraw(void);                     // kmain.c: paint the console ring to the framebuffer

// hda.c: probe with one DMA block; the idle wait's poll silences what has played
void k_hda_init(void *dma), k_horn_poll(void);

// the arch backend (<a>/arch.c) gives kmain these
void archinit(void), serial_init(void), serial_putc(int), k_reset(void), k_fault_trigger(intptr_t n);
uint64_t k_rtc(void);                  // the machine's own clock, unix seconds (0 = none)

// the x64 virtualization doors (src/inle/x64/svm.c, src/inle/x64/vmx.c)
uintptr_t k_svm_need(void), k_vmx_need(void);
bool k_svm_ok(void), k_vmx_ok(void);
int k_svm_spike(void *mem, uint64_t *code, uint64_t *rax, uint64_t *rip),
    k_vmx_spike(void *mem, uint64_t *reason, uint64_t *rax, uint64_t *rip, uint64_t *err);

#define k_boot_ram_max 64

struct k_boot {                       // uefi/loader.c copies this layout by hand
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
 char cmdline[256];                  // "" is a plain boot: the console shell
 // a heap image the door carries (the wasm page's), woken before baked_pick; 0 = none
 void const *image;
 uintptr_t image_len;
 // qemu's -initrd or PVH's first module, read-only at /proc/initrd; 0 = none
 void const *initrd;
 uintptr_t initrd_len; };

extern struct k_boot kboot;

// n bounds a source that may not be NUL-terminated (the DTB prop); ~0 for a C string
static inline void k_cmdline(char const *s, uintptr_t n) {
 uintptr_t i = 0;
 for (; i < n && i + 1 < sizeof kboot.cmdline && s[i]; i++) kboot.cmdline[i] = s[i];
 kboot.cmdline[i] = 0; }

// one usable span of RAM from a door's map; one too small for a pointer pair is dropped
static inline void k_ram_give(uint64_t base, uint64_t len) {
 if (len < 2 * sizeof(uintptr_t) || kboot.ram_n >= k_boot_ram_max) return;
 kboot.ram[kboot.ram_n].base = base;
 kboot.ram[kboot.ram_n].len  = len;
 kboot.ram_n++; }
