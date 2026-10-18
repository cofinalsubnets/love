// Teensy 4.1 bare-metal arch backend: clocks, the LPUART6 console, GPT1, the LED. the boot
// image, crt0, HardFault shim and barrier helpers are mkboot.l's
#include <stdint.h>
#include "teensy41.h"
#include "../bput.h"

// teensy41.lds's bounds and mkboot.l's vectors
extern uint32_t __data_start__[], __data_end__[], __data_load__[];
extern uint32_t __bss_start__[], __bss_end__[];
extern void *const vectors[];

int main(void);

// the stacked frame from mkboot.l's isr_hardfault (r0), kept where an SWD debugger finds it
volatile struct fault {
  uint32_t r0, r1, r2, r3, r12, lr, pc, psr, sp, magic;
} fault;

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
      bput_s(serial_putc, tags[k]);
      bput_x(serial_putc, v[k], 8); }
    serial_putc('\r'); serial_putc('\n'); }
  for (;;) {} }   // a bkpt here would re-enter DebugMon

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

// from mkboot.l's cstartup, the stack laid
void cmain(void) {
  // the LED before anything that can hang: a cold boot dying in clock bring-up still shows it
  gpio_init(LED_BIT); gpio_set_dir(LED_BIT, 1); gpio_put(LED_BIT, 1);
  // FPU on (CP10/CP11) before any float code
  REG(SCB_CPACR) |= (0xFu << 20);
  // MON_EN: a bkpt with no debugger vectors to the fault reporter rather than a mute lockup
  REG(0xE000EDFCu) |= (1u << 16);
  arm_dsb_isb();
  caches_init();
  clocks_init();          // no .data/.bss reads, so the copy below runs at 600 MHz
  for (uint32_t *s = __data_load__, *d = __data_start__; d < __data_end__; ) *d++ = *s++;
  for (uint32_t *b = __bss_start__; b < __bss_end__; b++) *b = 0;
  REG(SCB_VTOR) = (uint32_t)(uintptr_t) vectors;
  serial_init();
  main();
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

void serial_init(void) {
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
// serial_putc's TDRE stalls too. an overrun desyncs the FIFO: read what's there, flush, clear
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
uint32_t serial_rx_lost(void) {
  uint32_t n = rx_lost;
  return rx_lost = 0, n; }

void serial_putc(int c) {
  while (!(REG(LPUART_STAT) & LPUART_STAT_TDRE)) rx_pump();
  REG(LPUART_DATA) = (uint32_t)(c & 0xff); }

int serial_rx_ready(void) {
  rx_pump();
  return rx_w != rx_r; }

int serial_getc(void) {
  while (rx_w == rx_r) rx_pump();
  return rx_ring[rx_r++ & 1023u]; }

uintptr_t love_clock(void) { return REG(GPT1_CNT) / 1000u; }

// rp2040.c's gpio_* contract; pin is a GPIO2 bit, only the LED's pad muxed. TODO: the full pin map
void gpio_init(unsigned pin) {
  if (pin == LED_BIT) REG(IOMUXC_SW_MUX_GPIO_B0_03) = MUX_ALT(5);
  REG(GPIO2_GDIR) &= ~(1u << pin); }            // input until set_dir

void gpio_set_dir(unsigned pin, int out) {
  if (out) REG(GPIO2_GDIR) |= (1u << pin);
  else     REG(GPIO2_GDIR) &= ~(1u << pin); }

void gpio_put(unsigned pin, int hi) {
  REG(hi ? GPIO2_DR_SET : GPIO2_DR_CLEAR) = 1u << pin; }

int gpio_get(unsigned pin) { return (REG(GPIO2_PSR) >> pin) & 1u; }
