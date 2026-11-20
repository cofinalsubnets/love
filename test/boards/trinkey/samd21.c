// the atsamd21's bare backend: vectors, crt0, the crystalless 48 MHz and a millisecond off
// systick. the image runs from sram, put there and started by the uf2 bootloader's sam-ba
#include <stdint.h>
#include "samd21.h"

extern uint32_t __data_start__[], __data_end__[], __data_load__[];
extern uint32_t __bss_start__[], __bss_end__[], __stack_top__[];
extern void *const vectors[];

int main(void);
static void wdt_init(void);

// v6-M has no fault status registers: a halt leaves the frame for swd
void isr_hardfault(void) { for (;;) asm volatile("bkpt #0"); }

static void default_handler(void) { for (;;) asm volatile("bkpt #0"); }

// sam-ba's go has taken sp from vectors[0] and left the bootloader's interrupts on: they go off
// before the vector table moves, since nothing here is an interrupt's. the double tap next: any
// reset after, the watchdog's on a hang, comes back to the bootloader
__attribute__((used, noreturn)) void reset_handler(void) {
  REG(SYST_CSR) = 0;
  REG(NVIC_ICER) = ~0u;
  REG(NVIC_ICPR) = ~0u;
  REG(ICSR_ADDR) = ICSR_PENDSTCLR;
  REG(BOOT_TAP) = BOOT_MAGIC;
  wdt_init();
  REG(VTOR_ADDR) = (uint32_t) (uintptr_t) vectors;
  // .data's load address follows .rodata's bytes, so it may sit at any byte
  uint8_t const *s = (uint8_t const *) __data_load__;
  for (uint8_t *d = (uint8_t *) __data_start__; d < (uint8_t *) __data_end__; ) *d++ = *s++;
  for (uint32_t *b = __bss_start__; b < __bss_end__; b++) *b = 0;
  clocks_init();
  main();
  for (;;) asm volatile("bkpt #0"); }

__attribute__((section(".vectors"), used))
void *const vectors[] = {
  (void *) __stack_top__,   // 0  initial SP
  reset_handler,            // 1  reset
  default_handler,          // 2  NMI
  isr_hardfault,            // 3  HardFault
  0, 0, 0, 0, 0, 0, 0,      // 4..10 reserved
  default_handler,          // 11 SVCall
  0, 0,                     // 12..13 reserved
  default_handler,          // 14 PendSV
  default_handler,          // 15 SysTick
};

static void dfll_wait(void) { while (!(REG(SYSCTRL_PCLKSR) & PCLKSR_DFLLRDY)) {} }
static void gclk_wait(void) { while (REG8(GCLK_STATUS) & GCLK_SYNCBUSY) {} }
static void wdt_wait(void) { while (REG8(WDT_STATUS) & 0x80u) {} }

// the watchdog on gclk 2, the 32 kHz ulp rc over 32: 2048 of its ticks, 2 s
static void wdt_init(void) {
  REG(GCLK_GENDIV) = 2u | 4u << 8;
  REG(GCLK_GENCTRL) = 2u | GEN_SRC_ULP32K | GEN_GENEN | GEN_DIVSEL;
  gclk_wait();
  REG16(GCLK_CLKCTRL) = CLK_ID_WDT | 2u << 8 | CLK_CLKEN;
  REG8(WDT_CTRL) = 0;
  wdt_wait();
  REG8(WDT_CONFIG) = 8u;
  wdt_wait();
  REG8(WDT_CTRL) = 2u;
  wdt_wait(); }

// a clear while one syncs would stall the bus, so a busy watchdog waits for the next
void wdt_feed(void) { if (!(REG8(WDT_STATUS) & 0x80u)) REG8(WDT_CLEAR) = 0xA5u; }

// gclk 0 steps onto the 8 MHz rc while the dfll is set again: open at its factory coarse,
// closed on usb's start of frame once the host sends them, x48000. it is written enabled
// alone first, since a disabled or on-demand dfll never shows ready. one flash wait state at 48
void clocks_init(void) {
  REG(NVM_CTRLB) = (REG(NVM_CTRLB) & ~(15u << 1)) | (1u << 1);
  REG(SYSCTRL_OSC8M) &= ~(3u << 8);                 // prescaler 1
  REG(GCLK_GENCTRL) = 0u | GEN_SRC_OSC8M | GEN_GENEN;
  gclk_wait();
  REG16(SYSCTRL_DFLLCTRL) = DFLL_ENABLE;
  dfll_wait();
  uint32_t coarse = REG(NVM_CAL1) >> 26;
  if (coarse == 0x3Fu) coarse = 0x1Fu;
  REG(SYSCTRL_DFLLVAL) = coarse << 10 | 512u;
  dfll_wait();
  REG(SYSCTRL_DFLLMUL) = 1u << 26 | 1u << 16 | 48000u;   // csteps 1, fsteps 1
  dfll_wait();
  REG16(SYSCTRL_DFLLCTRL) = DFLL_CCDIS | DFLL_USBCRM | DFLL_MODE | DFLL_ENABLE;
  dfll_wait();
  REG(GCLK_GENCTRL) = 0u | GEN_SRC_DFLL | GEN_GENEN | GEN_IDC;
  gclk_wait();
  REG(SYST_RVR) = 0xFFFFFFu;
  REG(SYST_CVR) = 0;
  REG(SYST_CSR) = 5u; }                              // the core's clock, no interrupt

// systick's 24 bits wrap every 0.35 s at 48 MHz, so a caller looks at least that often
uint32_t clock_ms(void) {
  static uint32_t last, ticks, ms;
  uint32_t const now = REG(SYST_CVR);
  ticks += (last - now) & 0xFFFFFFu, last = now;
  ms += ticks / 48000u, ticks %= 48000u;
  return ms; }

void chip_uid(uint32_t id[4]) {
  id[0] = REG(NVM_UID0), id[1] = REG(NVM_UID1), id[2] = REG(NVM_UID1 + 4u), id[3] = REG(NVM_UID1 + 8u); }

// the bootloader's double tap, then a reset: it stays, its drive and sam-ba up again
void boot_loader(void) {
  REG(BOOT_TAP) = BOOT_MAGIC;
  REG(AIRCR_ADDR) = 0x05FA0004u;
  for (;;) {} }
