// the start every arm board's C makes, from reset or from a bootloader's go: systick and the
// nvic's first n words of interrupts off and none pending, .data in from where it is stored,
// .bss zeroed, the vector table moved. .data is stored straight after .rodata's last byte, at
// any address, so it is copied bytewise: a v6-M word load off a word faults.
// CRT0_V6M adds the thumb1 boards' vector table, whose reset is the board's reset_handler
#pragma once
#include <stdint.h>

extern uint32_t __data_start__[], __data_end__[], __data_load__[];
extern uint32_t __bss_start__[], __bss_end__[], __stack_top__[];
extern void *const vectors[];

#define CRT0_REG(a) (*(volatile uint32_t *) (uintptr_t) (a))

static void crt0(uint32_t n) {
  CRT0_REG(0xE000E010u) = 0;                                   // SYST_CSR
  for (uint32_t i = 0; i < n; i++)
    CRT0_REG(0xE000E180u + 4u * i) = ~0u, CRT0_REG(0xE000E280u + 4u * i) = ~0u;   // ICER, ICPR
  CRT0_REG(0xE000ED04u) = 1u << 25;                            // ICSR's PENDSTCLR
  uint8_t const *s = (uint8_t const *) __data_load__;
  for (uint8_t *d = (uint8_t *) __data_start__; d < (uint8_t *) __data_end__; ) *d++ = *s++;
  for (uint32_t *b = __bss_start__; b < __bss_end__; b++) *b = 0;
  CRT0_REG(0xE000ED08u) = (uint32_t) (uintptr_t) vectors; }    // VTOR

#ifdef CRT0_V6M
void reset_handler(void);

// v6-M has no fault status registers: a halt leaves the frame for swd
void isr_hardfault(void) { for (;;) asm volatile("bkpt #0"); }

static void default_handler(void) { for (;;) asm volatile("bkpt #0"); }

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
#endif
