// rp2350 (Arm) bare-metal arch backend, the C half (no pico SDK): crt0's body, the 150 MHz
// clocks, timer0's microseconds, SIO GPIO, the chip's id and the rom's usb
// boot. the vector table, the image definition and the asm helpers are mkboot.l's
#include <stdint.h>
#include "rp2350.h"
#include "../crt0.h"
#include "../../../src/inle/bput.h"

void arm_dsb_isb(void);
void arm_wfi(void);

int main(void);

// isr_hardfault (mkboot.l) branches here with the frame in r0, on a fresh stack
void hardfault_report(uint32_t *frame) {
  const char *tags[4] = { "\r\n; FAULT pc=", " lr=", " cfsr=", " bfar=" };
  uint32_t v[4] = { frame[6], frame[5], REG(0xE000ED28u), REG(0xE000ED38u) };
  for (int k = 0; k < 4; k++) {
    bput_s(serial_putc, tags[k]);
    bput_x(serial_putc, v[k], 8); }
  serial_putc('\r'); serial_putc('\n');
  for (;;) {} }

// mkboot.l's cstartup falls in here
void cmain(void) {
  // the fpu on before any float code: thumb2sp rides the S registers
  REG(CPACR_ADDR) |= (0xFu << 20);
  arm_dsb_isb();
  crt0(8);
  clocks_init();
  main();
  for (;;) arm_wfi(); }

// --- clocks: XOSC (12 MHz) + PLL_SYS -> 150 MHz clk_sys; clk_peri off XOSC --
void clocks_init(void) {
  REG(XOSC_CTRL) = XOSC_CTRL_1_15MHZ;
  REG(XOSC_STARTUP) = 47;
  REG(XOSC_CTRL + REG_SET) = XOSC_CTRL_ENABLE;
  while (!(REG(XOSC_STATUS) & XOSC_STATUS_STABLE)) {}

  // clk_ref -> xosc; clk_sys parked on clk_ref while the PLL moves
  REG(CLK_REF_DIV) = CLK_DIV_1;
  REG(CLK_REF_CTRL) = CLK_REF_SRC_XOSC;
  while (REG(CLK_REF_SELECTED) != (1u << CLK_REF_SRC_XOSC)) {}
  REG(CLK_SYS_CTRL) = CLK_SYS_SRC_REF;
  while (REG(CLK_SYS_SELECTED) != (1u << CLK_SYS_SRC_REF)) {}
  // timer0 and the watchdog count microseconds of clk_ref; the rom's reboot waits on the
  // watchdog, so without its tick a reboot never comes
  REG(TICKS_TIMER0_CYCLES) = 12u;
  REG(TICKS_TIMER0_CTRL) = 1u;
  REG(TICKS_WATCHDOG_CYCLES) = 12u;
  REG(TICKS_WATCHDOG_CTRL) = 1u;

  // PLL_SYS from its reset: refdiv 1, fbdiv 125 -> VCO 1500 MHz; postdiv 5/2 -> 150 MHz
  REG(RESETS_RESET + REG_SET) = RST_PLL_SYS;
  REG(RESETS_RESET + REG_CLR) = RST_PLL_SYS;
  while (!(REG(RESETS_RESET_DONE) & RST_PLL_SYS)) {}
  REG(PLL_CS) = 1;
  REG(PLL_FBDIV) = 125;
  REG(PLL_PWR + REG_CLR) = PLL_PWR_PD | PLL_PWR_VCOPD;
  while (!(REG(PLL_CS) & PLL_CS_LOCK)) {}
  REG(PLL_PRIM) = (5u << 16) | (2u << 12);
  REG(PLL_PWR + REG_CLR) = PLL_PWR_POSTDIVPD;

  // clk_sys -> PLL, glitchless: AUXSRC with SRC=ref, then SRC=aux
  REG(CLK_SYS_DIV) = CLK_DIV_1;
  REG(CLK_SYS_CTRL) = (CLK_SYS_AUX_PLLSYS << CLK_AUXSRC_LSB) | CLK_SYS_SRC_REF;
  REG(CLK_SYS_CTRL) = (CLK_SYS_AUX_PLLSYS << CLK_AUXSRC_LSB) | CLK_SYS_SRC_AUX;
  while (REG(CLK_SYS_SELECTED) != (1u << CLK_SYS_SRC_AUX)) {}

  // clk_peri -> xosc, the exact 12 MHz for the baud divisor
  REG(CLK_PERI_CTRL) = 0;
  REG(CLK_PERI_CTRL) = CLK_PERI_ENABLE | (CLK_PERI_AUX_XOSC << CLK_AUXSRC_LSB);

  // the blocks the board uses, out of reset
  uint32_t const want = RST_IO_BANK0 | RST_PADS_BANK0 | RST_TIMER;
  REG(RESETS_RESET + REG_CLR) = want;
  while ((REG(RESETS_RESET_DONE) & want) != want) {} }

// a pad set up for SIO, then let out of isolation
static void pad_on(unsigned pin) {
  REG(PADS_BANK0_GPIO(pin) + REG_CLR) = PADS_OD;
  REG(PADS_BANK0_GPIO(pin) + REG_SET) = PADS_IE;
  REG(PADS_BANK0_GPIO(pin) + REG_CLR) = PADS_ISO; }

// --- clock: milliseconds since boot (64-bit us timer) --------------------
uint32_t clock_ms(void) {
  uint32_t lo = REG(TIMER_TIMELR);
  uint32_t hi = REG(TIMER_TIMEHR);
  return (uint32_t) ((((uint64_t) hi << 32) | lo) / 1000u); }

// --- GPIO via SIO ---------------------------------------------------------
void gpio_init(unsigned pin) {
  REG(IO_BANK0_GPIO_CTRL(pin)) = IO_FUNC_SIO;
  pad_on(pin);
  REG(SIO_GPIO_OE_CLR) = 1u << pin; }

void gpio_set_dir(unsigned pin, int out) {
  REG(out ? SIO_GPIO_OE_SET : SIO_GPIO_OE_CLR) = 1u << pin; }

void gpio_put(unsigned pin, int hi) {
  REG(hi ? SIO_GPIO_OUT_SET : SIO_GPIO_OUT_CLR) = 1u << pin; }

int gpio_get(unsigned pin) { return (REG(SIO_GPIO_IN) >> pin) & 1u; }

// --- the rom: its lookup takes a code and the caller's kind (arm secure, 4) --
static void *rom_fn(uint32_t code) {
  typedef void *(*lookup_t)(uint32_t, uint32_t);
  lookup_t const look = (lookup_t) (uintptr_t) *(uint16_t const *) 0x16u;
  return look(code, 4u); }

// the chip's id from get_sys_info's chip info: words 2 and 3, high byte first
void chip_uid(uint8_t id[8]) {
  typedef int (*info_t)(uint32_t *, uint32_t, uint32_t);
  uint32_t w[9] = { 0 };
  ((info_t) rom_fn('G' | 'S' << 8))(w, 9, 1u);
  for (uint32_t i = 0; i < 8; i++) id[i] = (uint8_t) (w[2u + (7u - i) / 4u] >> 8u * ((7u - i) % 4u)); }

// reboot into bootsel (type 2), not returning, after 10 ms
void rom_bootsel(void) {
  typedef int (*reboot_t)(uint32_t, uint32_t, uint32_t, uint32_t);
  ((reboot_t) rom_fn('R' | 'B' << 8))(0x102u, 10u, 0, 0);
  for (;;) {} }
