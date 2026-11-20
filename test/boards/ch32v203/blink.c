// ch32v203 blink: the qt py's one led, a ws2812 on PA4, from reset on the 8 MHz HSI.
// a 0 is high for two stores (~0.3 us), a 1 for the stores and five nops (~0.9 us); the
// low between bits is the loop's, well under the 50 us that latches
#include <stdint.h>
#define R(a) (*(volatile uint32_t *)(uintptr_t)(a))
#define APB2PCENR 0x40021018u
#define GPIOA_CFGLR 0x40010800u
#define GPIOA_BSHR 0x40010810u   // BCR the word after

static void pix(uint32_t grb) {
  uint32_t m = 1u << 4, b = GPIOA_BSHR;
  for (int i = 23; i >= 0; i--) {
    if (grb >> i & 1)
      asm volatile ("sw %0, 0(%1)\n nop\n nop\n nop\n nop\n nop\n sw %0, 4(%1)" :: "r"(m), "r"(b) : "memory");
    else
      asm volatile ("sw %0, 0(%1)\n sw %0, 4(%1)" :: "r"(m), "r"(b) : "memory"); } }

static void wait(uint32_t n) { for (volatile uint32_t k = 0; k < n; k++) {} }

void cmain(void) {
  R(APB2PCENR) |= 1u << 2;                                   // IOPA's clock
  R(GPIOA_CFGLR) = (R(GPIOA_CFGLR) & ~(0xfu << 16)) | (0x3u << 16);   // PA4 push-pull out
  R(GPIOA_BSHR + 4) = 1u << 4;
  wait(2000);
  for (uint32_t t = 0;; t++) {
    pix(t & 1 ? 0x001000u : 0x100000u);                      // grb: green, then red
    wait(200000); } }
