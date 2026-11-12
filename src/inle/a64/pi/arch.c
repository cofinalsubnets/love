// a64 on the raspberry pi zero 2 w (bcm2837, as the 3's): the mini uart console on gpio14/15,
// the bcm2836 local intc and the bcm2835 armctrl, the pm watchdog's reset. stands in for
// a64/arch.c; the stub maps the peripherals, so nothing is mapped here
#include <stdint.h>
#include "../asmops.h"                 // the privileged instructions, both spellings
#include "k.h"                       // kticks, kq's queue
#include "../../mmio.h"               // mmio_rd/mmio_wr, device registers off the direct map

void kq(uint8_t);                      // kmain's input queue, one byte
void k_timer_init(void), k_timer_rearm(void);   // cpu.c

#define PERI    0x3f000000             // the peripherals, as the arm sees them
#define AUX     (PERI + 0x215000)      // the mini uart's block
#define ARMCTL  (PERI + 0x00b200)      // the gpu's interrupts, as the arm takes them
#define PM      (PERI + 0x100000)      // power management: the watchdog
#define LOCAL   0x40000000             // the bcm2836 per-core block

#define AUX_ENABLES 0x04               // bit 0: the mini uart
#define MU_IO       0x40               // data
#define MU_IER      0x44               // bit 0: receive interrupt
#define MU_LCR      0x4c               // 3: 8 bits
#define MU_LSR      0x54               // line status
#define MU_CNTL     0x60               // 3: receive and transmit on
#define LSR_RX      (1u << 0)          // a byte waits
#define LSR_TXE     (1u << 5)          // room for one

#define IRQ_PEND1   0x04               // gpu interrupts 0-31, pending
#define IRQ_EN1     0x10               // ..set-enable
#define AUX_BIT     (1u << 29)         // aux is gpu interrupt 29

#define CORE0_TIMER 0x40               // core 0's timer interrupt control
#define CORE0_SRC   0x60               // core 0's interrupt source
#define SRC_CNTPNS  (1u << 1)          // the el1 physical timer
#define SRC_GPU     (1u << 8)          // the armctrl's, routed to core 0

// no clock on the board: kmain asks the network, or keeps 0
uint64_t k_rtc(void) { return 0; }

// the firmware laid the pins and the baud (enable_uart=1); only the fifo and the irq are ours
void serial_init(void) {
  mmio_wr(AUX, AUX_ENABLES, mmio_rd(AUX, AUX_ENABLES) | 1);
  mmio_wr(AUX, MU_LCR, 3);
  mmio_wr(AUX, MU_CNTL, 3);
  mmio_wr(AUX, MU_IER, 1);
  mmio_wr(ARMCTL, IRQ_EN1, AUX_BIT); }

void serial_putc(int c) {
  if (c == '\n') serial_putc('\r');
  // bounded, so an absent or wedged port can't hang output
  for (int i = 0; i < 100000 && !(mmio_rd(AUX, MU_LSR) & LSR_TXE); i++) {}
  mmio_wr(AUX, MU_IO, (uint8_t) c); }

// reading the fifo dry clears the receive interrupt
static void k_uart(void) {
  while (mmio_rd(AUX, MU_LSR) & LSR_RX)
    kq(mmio_rd(AUX, MU_IO) & 0xff); }

// from the IRQ vector: the local block says which, the armctrl says which gpu interrupt
void k_irq(void) {
  uint32_t src = mmio_rd(LOCAL, CORE0_SRC);
  if (src & SRC_CNTPNS) kticks++, k_timer_rearm();
  if ((src & SRC_GPU) && (mmio_rd(ARMCTL, IRQ_PEND1) & AUX_BIT)) k_uart(); }

// archinit finds EL1 (the stub dropped from EL2), the MMU, a stack and the HHDM up
void archinit(void) {
  k_sp_to_el1h();
  k_fpen_enable();
  k_wr_vbar_el1((uintptr_t) vectors);
  mmio_wr(LOCAL, CORE0_TIMER, SRC_CNTPNS);       // the physical timer's irq to core 0
  k_timer_init();
  k_daif_unmask_irq(); }

// the watchdog, a short count and a full reset; the firmware boots again
#define PM_RSTC 0x1c
#define PM_WDOG 0x24
#define PM_PW   0x5a000000u
void k_reset(void) {
  mmio_wr(PM, PM_WDOG, PM_PW | 10);
  mmio_wr(PM, PM_RSTC, PM_PW | (mmio_rd(PM, PM_RSTC) & ~0x30u) | 0x20);
  for (;;) k_wait(); }
