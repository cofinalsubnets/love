// Teensy 4.1 bare-metal arch backend: clocks, the LPUART6 console, GPT1, the LED. the boot
// image, crt0, HardFault shim and barrier helpers are mkboot.l's
#include <stdint.h>
#include "teensy41.h"
#include "../bput.h"

// teensy41.lds's bounds and mkboot.l's vectors
extern uint32_t __data_start__[], __data_end__[], __data_load__[];
extern uint32_t __bss_start__[], __bss_end__[];
extern void *const vectors[];

void te_main(void);   // kern.c's kernel, or psram-test.c's probe

// the stacked frame from mkboot.l's isr_hardfault (r0), kept where an SWD debugger finds it
volatile struct fault {
  uint32_t r0, r1, r2, r3, r12, lr, pc, psr, sp, magic;
} fault;

// a face may say a fault on more wires, and end it its own way; by default the uart, then a spin
__attribute__((weak)) void te_fault_putc(int c) { (void) c; }
__attribute__((weak)) void te_fault_end(void) { for (;;) {} }   // a bkpt here would re-enter DebugMon
static void fault_putc(int c) { uart_putc(c), te_fault_putc(c); }

void hardfault_report(uint32_t *frame) {
  fault.r0  = frame[0]; fault.r1 = frame[1]; fault.r2 = frame[2];
  fault.r3  = frame[3]; fault.r12 = frame[4]; fault.lr = frame[5];
  fault.pc  = frame[6]; fault.psr = frame[7];
  fault.sp  = (uint32_t)(uintptr_t) frame;
  fault.magic = 0xFA017EDu;
  // on the wire before the bootloader chip resets us; CFSR/BFAR/MMFAR classify the fault
  { const char *tags[6] = { "\r\n; FAULT pc=", " lr=", " sp=", " cfsr=", " bfar=", " mmfar=" };
    uint32_t v[6] = { frame[6], frame[5], (uint32_t)(uintptr_t) frame,
                      REG(0xE000ED28u), REG(0xE000ED38u), REG(0xE000ED34u) };
    for (int k = 0; k < 6; k++) {
      bput_s(fault_putc, tags[k]);
      bput_x(fault_putc, v[k], 8); }
    fault_putc('\r'); fault_putc('\n'); }
  te_fault_end(); }

// XIP without caches fetches every instruction over QSPI, hours for a bake. the default map
// already types flash and OCRAM cacheable, so no MPU regions; RT1062 L1D: way at bit 30, set at 5
#define SCB_CCR     0xE000ED14u
#define SCB_CCSIDR  0xE000ED80u
#define SCB_CSSELR  0xE000ED84u
#define SCB_ICIALLU 0xE000EF50u
#define SCB_DCISW   0xE000EF60u

static void caches_init(void) {
  arm_dsb_isb();
  REG(SCB_ICIALLU) = 0;
  arm_dsb_isb();
  REG(SCB_CCR) |= 1u << 17;                      // I-cache on
  arm_dsb_isb();
  REG(SCB_CSSELR) = 0;                           // select the L1 D-cache
  arm_dsb();
  uint32_t ccsidr = REG(SCB_CCSIDR);
  uint32_t sets = (ccsidr >> 13) & 0x7FFFu, ways = (ccsidr >> 3) & 0x3FFu;
  for (uint32_t s = 0; s <= sets; s++)
    for (uint32_t w = 0; w <= ways; w++)
      REG(SCB_DCISW) = (w << 30) | (s << 5);
  arm_dsb();
  REG(SCB_CCR) |= 1u << 16;                      // D-cache on
  arm_dsb_isb(); }

int te_in_psram(void) { return (uintptr_t) vectors >= PSRAM_BASE; }

// from mkboot.l's cstartup, the stack laid
void cmain(void) {
  // the LED before anything that can hang: a cold boot dying in clock bring-up still shows it
  gpio_init(LED_PIN); gpio_set_dir(LED_PIN, 1); gpio_put(LED_PIN, 1);
  // FPU on (CP10/CP11) before any float code
  REG(SCB_CPACR) |= (0xFu << 20);
  // MON_EN: a bkpt with no debugger vectors to the fault reporter rather than a mute lockup
  REG(0xE000EDFCu) |= (1u << 16);
  arm_dsb_isb();
  // no .data/.bss reads, so the copy below runs at 600 MHz. in the psram both are the loader's
  // work, and caches_init would drop the image's own lines
  if (!te_in_psram()) caches_init(), clocks_init();
  for (uint32_t *s = __data_load__, *d = __data_start__; d < __data_end__; ) *d++ = *s++;
  for (uint32_t *b = __bss_start__; b < __bss_end__; b++) *b = 0;
  REG(SCB_VTOR) = (uint32_t)(uintptr_t) vectors;
  uart_init();
  te_main();
  for (;;) arm_wfi(); }

// a cold boot can leave a handshake bit stuck: ~10 ms at any clock, 0 = gave up
static int wait_reg(uint32_t addr, uint32_t mask, int want_set) {
  for (uint32_t i = 0; i < 4000000u; i++) {
    uint32_t v = REG(addr) & mask;
    if (want_set ? v != 0 : v == 0) return 1; }
  return 0; }

void clocks_init(void) {
  // the core to 600 MHz, voltage first; a timeout stays near the ROM clock and still boots.
  // the UART and GPT ride the crystal, untouched by the retune
  REG(DCDC_REG3) = (REG(DCDC_REG3) & ~DCDC_REG3_TRG_MASK) | DCDC_TRG_1V25;
  if (!wait_reg(DCDC_REG0, DCDC_REG0_STS_DC_OK, 1)) return;   // no settled supply: stay on the ROM clock
  // park periph_clk on the osc while PLL1 retunes
  REG(CCM_CBCMR) = (REG(CCM_CBCMR) & ~CBCMR_PERIPH_CLK2_MASK) | CBCMR_PERIPH_CLK2_OSC;
  REG(CCM_CBCDR) |= CBCDR_PERIPH_CLK_SEL;
  if (!wait_reg(CCM_CDHIPR, CDHIPR_PERIPH_CLK_SEL_BUSY, 0)) return;
  // 24 MHz * 100 / 2 = 1200 MHz, then /2
  REG(CCM_ANALOG_PLL_ARM) = PLL_ARM_POWERDOWN;
  REG(CCM_ANALOG_PLL_ARM) = PLL_ARM_ENABLE | 100u;
  if (!wait_reg(CCM_ANALOG_PLL_ARM, PLL_ARM_LOCK, 1)) {       // PLL never locked: un-park and live slow
    REG(CCM_CBCDR) &= ~CBCDR_PERIPH_CLK_SEL;
    return; }
  REG(CCM_CCSR) &= ~CCSR_PLL1_SW_CLK_SEL;        // core rides pll1_main
  REG(CCM_CACRR) = 1u;                            // /2
  wait_reg(CCM_CDHIPR, CDHIPR_ARM_PODF_BUSY, 0);
  // AHB /1, IPG /4 (150 MHz, its ceiling); pre-periph the divided PLL; un-park
  REG(CCM_CBCDR) = (REG(CCM_CBCDR) & ~(CBCDR_AHB_PODF_MASK | CBCDR_IPG_PODF_MASK))
                 | CBCDR_IPG_PODF_DIV4;
  wait_reg(CCM_CDHIPR, CDHIPR_AHB_PODF_BUSY, 0);
  REG(CCM_CBCMR) = (REG(CCM_CBCMR) & ~CBCMR_PRE_PERIPH_MASK) | CBCMR_PRE_PERIPH_PLL1;
  REG(CCM_CBCDR) &= ~CBCDR_PERIPH_CLK_SEL;
  wait_reg(CCM_CDHIPR, CDHIPR_PERIPH_CLK_SEL_BUSY, 0);

  REG(CCM_CCGR3) |= CCGR_ON(3);
  REG(CCM_CCGR1) |= CCGR_ON(GPT1_CCGR_BUS) | CCGR_ON(GPT1_CCGR_SERIAL);
  // LPUART clock: the osc, undivided
  uint32_t c = REG(CCM_CSCDR1);
  c = (c & ~CSCDR1_UART_CLK_PODF_MASK) | CSCDR1_UART_CLK_SEL_OSC;
  REG(CCM_CSCDR1) = c;

  // GPT1 free-runs at 1 MHz off the osc
  REG(GPT1_CR) = GPT_CR_SWR;
  while (REG(GPT1_CR) & GPT_CR_SWR) {}
  REG(GPT1_PR) = 24u - 1u;
  REG(GPT1_CR) = GPT_CR_CLKSRC_24M | GPT_CR_EN_24M | GPT_CR_FRR | GPT_CR_ENMOD;
  REG(GPT1_CR) |= GPT_CR_EN; }

void uart_init(void) {
  REG(IOMUXC_SW_MUX_GPIO_AD_B0_02) = MUX_ALT(2);
  REG(IOMUXC_SW_MUX_GPIO_AD_B0_03) = MUX_ALT(2);
  REG(IOMUXC_LPUART6_RX_SELECT) = 1u;            // select GPIO_AD_B0_03
  // the mux alone leaves the pad at a drive strength that does not move the line
  REG(IOMUXC_SW_PAD_GPIO_AD_B0_02) = PAD_CTL_UART;   // TX drive
  REG(IOMUXC_SW_PAD_GPIO_AD_B0_03) = PAD_CTL_UART;   // RX keeper

  // 115200 8N1: OSR=16, SBR=13 -> 115384 (+0.16%)
  REG(LPUART_CTRL) = 0;
  REG(LPUART_BAUD) = LPUART_BAUD_OSR(16) | LPUART_BAUD_SBR(13) | LPUART_BAUD_BOTHEDGE;
  REG(LPUART_FIFO) |= LPUART_FIFO_TXFE | LPUART_FIFO_RXFE;
  REG(LPUART_CTRL) = LPUART_CTRL_TE | LPUART_CTRL_RE;
  // boot-window noise can wedge the FIFO: flush, clear the error flags, drain
  REG(LPUART_FIFO) |= LPUART_FIFO_RXFLUSH;
  REG(LPUART_STAT) = LPUART_STAT_ERR;
  while (REG(LPUART_STAT) & LPUART_STAT_RDRF) (void) REG(LPUART_DATA); }

// the 4-deep RX FIFO loses a paste to the editor's redraws, so a soft ring is pumped from
// uart_putc's TDRE stalls too. an overrun desyncs the FIFO: read what's there, flush, clear
static uint8_t  rx_ring[1024];
static uint32_t rx_w, rx_r, rx_lost;

// a full ring drops the newest byte and counts it, so what survives is a prefix
static void rx_put(uint8_t b) {
  if (rx_w - rx_r < sizeof rx_ring) rx_ring[rx_w++ & 1023u] = b;
  else if (rx_lost != (uint32_t) -1) rx_lost++; }

static void rx_pump(void) {
  for (;;) {
    if (REG(LPUART_STAT) & LPUART_STAT_OR) {
      while (REG(LPUART_STAT) & LPUART_STAT_RDRF)
        rx_put(REG(LPUART_DATA) & 0xff);
      REG(LPUART_FIFO) |= LPUART_FIFO_RXFLUSH;
      REG(LPUART_STAT) = LPUART_STAT_ERR;
      continue; }
    if (!(REG(LPUART_STAT) & LPUART_STAT_RDRF)) return;
    rx_put(REG(LPUART_DATA) & 0xff); } }

// the drops since the last ask, and clears; not reported from rx_pump, which a notice
// on this same UART would re-enter
uint32_t uart_rx_lost(void) {
  uint32_t n = rx_lost;
  return rx_lost = 0, n; }

void uart_putc(int c) {
  while (!(REG(LPUART_STAT) & LPUART_STAT_TDRE)) rx_pump();
  REG(LPUART_DATA) = (uint32_t)(c & 0xff); }

int uart_rx_ready(void) {
  rx_pump();
  return rx_w != rx_r; }

int uart_getc(void) {
  while (rx_w == rx_r) rx_pump();
  return rx_ring[rx_r++ & 1023u]; }

// the board clock in ms, for the drivers; a love face answers love_clock from it
uintptr_t te_ms(void) { return REG(GPT1_CNT) / 1000u; }

// the board's pins 0..54, PJRC's numbering: each a GPIO1..4 bank, its bit and its pad's mux
// offset, as core_pins.h's teensy 4.1 map spells them on the fast banks 6..9 that mirror
// these. 0 a pin the console (0, 1), the microSD (42..47) or the PSRAM (48..54) holds
#define PIN(bank, bit, pad) ((pad) << 16 | (bank) << 8 | (bit))
static uint32_t const pins[55] = {
  0,                         //  0 AD_B0_03, held
  0,                         //  1 AD_B0_02, held
  PIN(4,  4, 0x024u),     //  2 EMC_04
  PIN(4,  5, 0x028u),     //  3 EMC_05
  PIN(4,  6, 0x02Cu),     //  4 EMC_06
  PIN(4,  8, 0x034u),     //  5 EMC_08
  PIN(2, 10, 0x164u),     //  6 B0_10
  PIN(2, 17, 0x180u),     //  7 B1_01
  PIN(2, 16, 0x17Cu),     //  8 B1_00
  PIN(2, 11, 0x168u),     //  9 B0_11
  PIN(2,  0, 0x13Cu),     // 10 B0_00
  PIN(2,  2, 0x144u),     // 11 B0_02
  PIN(2,  1, 0x140u),     // 12 B0_01
  PIN(2,  3, 0x148u),     // 13 B0_03
  PIN(1, 18, 0x104u),     // 14 AD_B1_02
  PIN(1, 19, 0x108u),     // 15 AD_B1_03
  PIN(1, 23, 0x118u),     // 16 AD_B1_07
  PIN(1, 22, 0x114u),     // 17 AD_B1_06
  PIN(1, 17, 0x100u),     // 18 AD_B1_01
  PIN(1, 16, 0x0FCu),     // 19 AD_B1_00
  PIN(1, 26, 0x124u),     // 20 AD_B1_10
  PIN(1, 27, 0x128u),     // 21 AD_B1_11
  PIN(1, 24, 0x11Cu),     // 22 AD_B1_08
  PIN(1, 25, 0x120u),     // 23 AD_B1_09
  PIN(1, 12, 0x0ECu),     // 24 AD_B0_12
  PIN(1, 13, 0x0F0u),     // 25 AD_B0_13
  PIN(1, 30, 0x134u),     // 26 AD_B1_14
  PIN(1, 31, 0x138u),     // 27 AD_B1_15
  PIN(3, 18, 0x094u),     // 28 EMC_32
  PIN(4, 31, 0x090u),     // 29 EMC_31
  PIN(3, 23, 0x0A8u),     // 30 EMC_37
  PIN(3, 22, 0x0A4u),     // 31 EMC_36
  PIN(2, 12, 0x16Cu),     // 32 B0_12
  PIN(4,  7, 0x030u),     // 33 EMC_07
  PIN(2, 29, 0x1B0u),     // 34 B1_13
  PIN(2, 28, 0x1ACu),     // 35 B1_12
  PIN(2, 18, 0x184u),     // 36 B1_02
  PIN(2, 19, 0x188u),     // 37 B1_03
  PIN(1, 28, 0x12Cu),     // 38 AD_B1_12
  PIN(1, 29, 0x130u),     // 39 AD_B1_13
  PIN(1, 20, 0x10Cu),     // 40 AD_B1_04
  PIN(1, 21, 0x110u),     // 41 AD_B1_05
  0,                         // 42 SD_B0_03, held
  0,                         // 43 SD_B0_02, held
  0,                         // 44 SD_B0_01, held
  0,                         // 45 SD_B0_00, held
  0,                         // 46 SD_B0_05, held
  0,                         // 47 SD_B0_04, held
  0,                         // 48 EMC_24, held
  0,                         // 49 EMC_27, held
  0,                         // 50 EMC_28, held
  0,                         // 51 EMC_22, held
  0,                         // 52 EMC_26, held
  0,                         // 53 EMC_25, held
  0,                         // 54 EMC_29, held
};
static uint32_t pin_row(unsigned pin) { return pin < 55 ? pins[pin] : 0; }
static uint32_t pin_bank(uint32_t r) { return GPIO1_BASE + 0x4000u * ((r >> 8 & 7u) - 1u); }

int gpio_ok(unsigned pin) { return pin_row(pin) != 0; }

// the bank's clock on, the pad to GPIO (ALT5, SION so the PSR reads an output back), an
// input until set_dir
void gpio_init(unsigned pin) {
  uint32_t r = pin_row(pin);
  if (!r) return;
  static uint32_t const gate[4][2] = { { CCM_CCGR1, 3u << 26 }, { CCM_CCGR0, 3u << 30 },
                                       { CCM_CCGR2, 3u << 26 }, { CCM_CCGR3, 3u << 12 } };
  uint32_t const *g = gate[(r >> 8 & 7u) - 1u];
  REG(g[0]) |= g[1];
  REG(IOMUXC_BASE + (r >> 16)) = MUX_ALT(5) | 0x10u;
  REG(pin_bank(r) + 0x04u) &= ~(1u << (r & 31u)); }

void gpio_set_dir(unsigned pin, int out) {
  uint32_t r = pin_row(pin);
  if (!r) return;
  if (out) REG(pin_bank(r) + 0x04u) |= 1u << (r & 31u);
  else     REG(pin_bank(r) + 0x04u) &= ~(1u << (r & 31u)); }

void gpio_put(unsigned pin, int hi) {
  uint32_t r = pin_row(pin);
  if (r) REG(pin_bank(r) + (hi ? 0x84u : 0x88u)) = 1u << (r & 31u); }

int gpio_get(unsigned pin) {
  uint32_t r = pin_row(pin);
  return r ? (int) (REG(pin_bank(r) + 0x08u) >> (r & 31u) & 1u) : 0; }
