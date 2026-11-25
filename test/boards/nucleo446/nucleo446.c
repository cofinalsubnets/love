// nucleo-F446RE arch backend, the C half (no HAL): the 180 MHz PLL, the USART1 console (PA9
// and PA10, on the headers), TIM2's microseconds, LD2 and the button. vectors, crt0 and the asm helpers
// are mkboot.l's
#include <stdint.h>
#include "nucleo446.h"
#include "../crt0.h"
#include "../../../src/inle/bput.h"

int main(void);

// isr_hardfault (mkboot.l) branches here with the frame in r0, on a fresh stack: name the
// fault, then idle (QSMOKE: exit qemu as 98)
void hardfault_report(uint32_t *frame) {
  const char *tags[5] = { "\r\n; FAULT pc=", " lr=", " cfsr=", " bfar=", " mmfar=" };
  uint32_t v[5] = { frame[6], frame[5],
                    REG(0xE000ED28u), REG(0xE000ED38u), REG(0xE000ED34u) };
  for (int k = 0; k < 5; k++) {
    bput_s(serial_putc, tags[k]);
    bput_x(serial_putc, v[k], 8); }
  serial_putc('\r'); serial_putc('\n');
#ifdef QSMOKE
  sh_exit(98);
#endif
  for (;;) {} }

// mkboot.l's cstartup falls in here
void cmain(void) {
  // FPU on before any float code: thumb2sp still rides the S/D registers
  REG(SCB_CPACR) |= (0xFu << 20);
  arm_dsb_isb();
  // .data and .bss before clocks, so no read of a global races the copy
  crt0(8);
  clocks_init();
  serial_init();
  main();
  for (;;) arm_wfi(); }

// 180 MHz: 8 MHz HSE-bypass (ST-LINK MCO) -> PLL /4*180/2, scale 1 + over-drive, 5 wait
// states, APB1 /4, APB2 /2. every wait is bounded: a timeout stays on the 16 MHz HSI, the
// lane qemu always takes (its RCC reads 0)
static int wait_reg(uint32_t addr, uint32_t mask) {
  for (uint32_t i = 0; i < 4000000u; i++)
    if (REG(addr) & mask) return 1;
  return 0; }

void clocks_init(void) {
  REG(RCC_CR) |= RCC_CR_HSEBYP | RCC_CR_HSEON;
  if (!wait_reg(RCC_CR, RCC_CR_HSERDY)) return;      // no HSE: stay on HSI
  // regulator scale 1 before the PLL spins up
  REG(RCC_APB1ENR) |= APB1ENR_PWR;
  REG(PWR_CR) |= PWR_CR_VOS_SCALE1;
  REG(RCC_PLLCFGR) = PLLCFGR_180;
  REG(RCC_CR) |= RCC_CR_PLLON;
  // over-drive (RM0390: above 168 MHz), switched in while the PLL locks
  REG(PWR_CR) |= PWR_CR_ODEN;
  if (!wait_reg(PWR_CSR, PWR_CSR_ODRDY)) { REG(RCC_CR) &= ~RCC_CR_PLLON; return; }
  REG(PWR_CR) |= PWR_CR_ODSWEN;
  if (!wait_reg(PWR_CSR, PWR_CSR_ODSWRDY)) { REG(RCC_CR) &= ~RCC_CR_PLLON; return; }
  if (!wait_reg(RCC_CR, RCC_CR_PLLRDY)) { REG(RCC_CR) &= ~RCC_CR_PLLON; return; }
  // wait states before the switch; bus dividers with it
  REG(FLASH_ACR) = FLASH_ACR_180;
  uint32_t c = REG(RCC_CFGR) & ~(CFGR_PPRE1_MASK | CFGR_PPRE2_MASK | CFGR_SW_MASK);
  REG(RCC_CFGR) = c | CFGR_PPRE1_DIV4 | CFGR_PPRE2_DIV2 | CFGR_SW_PLL;
  for (uint32_t i = 0; i < 4000000u; i++)
    if ((REG(RCC_CFGR) & CFGR_SWS_MASK) == CFGR_SWS_PLL) break; }

// the core clock from the live RCC state, so a failed retune shows on every boot
uint32_t clock_mhz(void) {
  if ((REG(RCC_CFGR) & CFGR_SWS_MASK) != CFGR_SWS_PLL) return 16;   // HSI reset clock
  uint32_t p = REG(RCC_PLLCFGR);
  uint32_t in = (p & (1u << 22)) ? 8u : 16u;         // HSE-bypass 8 / HSI 16
  uint32_t m = p & 0x3Fu, n = (p >> 6) & 0x1FFu;
  uint32_t div = 2u * (((p >> 16) & 3u) + 1u);       // PLLP: 00 = /2
  return in * n / m / div; }

// an APB's clock from its live prescaler: APB1's (TIM2's) at bit 10, APB2's (USART1's) at 13
static uint32_t pclk_hz(uint32_t mask, uint32_t at) {
  uint32_t pre = (REG(RCC_CFGR) & mask) >> at;
  uint32_t hz = clock_mhz() * 1000000u;
  return pre < 4u ? hz : hz >> (pre - 3u); }
static uint32_t pclk1_hz(void) { return pclk_hz(CFGR_PPRE1_MASK, 10); }

// --- USART1 console (PA9 TX / PA10 RX, AF7): PA2/PA3 are the ST-LINK's -----
void serial_init(void) {
  REG(RCC_AHB1ENR) |= AHB1ENR_GPIOA;
  REG(RCC_APB2ENR) |= APB2ENR_USART1;
  uint32_t m = REG(GPIO_MODER(GPIOA_BASE));
  m = (m & ~((3u << 18) | (3u << 20))) | (2u << 18) | (2u << 20);   // PA9/PA10 alternate
  REG(GPIO_MODER(GPIOA_BASE)) = m;
  uint32_t a = REG(GPIO_AFRH(GPIOA_BASE));
  a = (a & ~((0xFu << 4) | (0xFu << 8))) | (7u << 4) | (7u << 8);  // AF7 = USART1
  REG(GPIO_AFRH(GPIOA_BASE)) = a;
  // 115200 8N1, oversample 16
  REG(USART1_CR1) = 0;
  REG(USART1_BRR) = (pclk_hz(CFGR_PPRE2_MASK, 13) + 115200u / 2u) / 115200u;
  REG(USART1_CR1) = USART_CR1_UE | USART_CR1_TE | USART_CR1_RE; }

void serial_putc(int c) {
  while (!(REG(USART1_SR) & USART_SR_TXE)) {}
  REG(USART1_DR) = (uint32_t)(c & 0xff); }

int serial_rx_ready(void) { return (REG(USART1_SR) & USART_SR_RXNE) != 0; }

int serial_getc(void) {
  while (!serial_rx_ready()) {}
  return (int)(REG(USART1_DR) & 0xffu); }

// ms since boot off TIM2's microseconds; its clock is 2x PCLK1 whenever PPRE1 divides
void timer_init(void) {
  REG(RCC_APB1ENR) |= APB1ENR_TIM2;
  uint32_t pre = (REG(RCC_CFGR) & CFGR_PPRE1_MASK) >> 10;
  uint32_t hz = pre < 4u ? pclk1_hz() : 2u * pclk1_hz();
  REG(TIM2_CR1) = 0;
  REG(TIM2_PSC) = hz / 1000000u - 1u;               // 1 MHz tick
  REG(TIM2_ARR) = 0xFFFFFFFFu;
  REG(TIM2_EGR) = TIM_EGR_UG;                       // latch the prescaler
  REG(TIM2_CR1) = TIM_CR1_CEN; }

uint32_t clock_ms(void) { return REG(TIM2_CNT) / 1000u; }

// --- GPIO: the LD2 LED (PA5) and the user button (PC13, low = pressed) ----
void led_init(void) {
  REG(RCC_AHB1ENR) |= AHB1ENR_GPIOA | AHB1ENR_GPIOC;
  uint32_t m = REG(GPIO_MODER(GPIOA_BASE));
  REG(GPIO_MODER(GPIOA_BASE)) = (m & ~(3u << (2u * LED_PIN))) | (1u << (2u * LED_PIN));
  REG(GPIO_MODER(GPIOC_BASE)) &= ~(3u << (2u * BTN_PIN)); }   // input

void led_put(int hi) {
  REG(GPIO_BSRR(GPIOA_BASE)) = hi ? (1u << LED_PIN) : (1u << (LED_PIN + 16u)); }

int btn_get(void) { return !((REG(GPIO_IDR(GPIOC_BASE)) >> BTN_PIN) & 1u); }
