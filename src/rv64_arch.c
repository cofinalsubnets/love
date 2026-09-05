// rv64 architecture-specific C: the ns16550 serial console, the PLIC, the
// SBI timer, and trap reporting. the trap entry itself is laid by src/mkvec.l;
// archinit points stvec at it. the a64 file's contract (archinit,
// serial_init, serial_putc, k_reset), the riscv 'virt' machine's hardware.
#include <stdint.h>
#include "asmops.h"                    // the privileged instructions, both spellings
#include "k.h"                       // kboot, and kputc/kputs/kputn (src/kmain.c)

void kq(uint8_t);                      // kmain's input queue, one byte

// --- QEMU 'virt' machine fixed MMIO layout ---------------------------
// every device sits under the first gigabyte, inside the window mkboot.l's
// stub already maps: a base sv39 pte says nothing about memory type, so there
// is no device mapping to add the way a64's mmio_map does.
#define UART_PHYS   0x10000000         // ns16550a, byte registers
#define RTC_PHYS    0x00101000         // goldfish rtc
#define PLIC_PHYS   0x0c000000
#define UART_IRQ    10
#define PLIC_CTX    1                  // hart 0's S-mode context: 2 * hart + 1
#define TIMEBASE    10000000           // mtime ticks per second on virt

static inline uint8_t mmio_rd8(uintptr_t phys, uintptr_t off) {
  return *(volatile uint8_t*) (khhdm + phys + off); }
static inline void mmio_wr8(uintptr_t phys, uintptr_t off, uint8_t v) {
  *(volatile uint8_t*) (khhdm + phys + off) = v; }
static inline uint32_t mmio_rd(uintptr_t phys, uintptr_t off) {
  return *(volatile uint32_t*) (khhdm + phys + off); }
static inline void mmio_wr(uintptr_t phys, uintptr_t off, uint32_t v) {
  *(volatile uint32_t*) (khhdm + phys + off) = v; }

// --- ns16550 serial console -------------------------------------------
// x64's COM1 with the same register file behind memory instead of ports:
// the console beside the framebuffer, and the only one when there is none.
// input is interrupt-driven: the PLIC delivers UART_IRQ, k_trap claims it,
// and k_uart drains the FIFO into the same queue the rest of the kernel reads.
#define RBR 0                          // receive buffer (read)
#define THR 0                          // transmit holding (write)
#define IER 1                          // interrupt enable
#define FCR 2                          // fifo control
#define LCR 3                          // line control
#define MCR 4                          // modem control
#define LSR 5                          // line status
#define LSR_DR   0x01                  // receive data ready
#define LSR_THRE 0x20                  // transmit holding register empty

// called once from kmain, just after archinit (so the PLIC is up).
void serial_init(void) {
  mmio_wr8(UART_PHYS, IER, 0x00);      // interrupts off while configuring
  mmio_wr8(UART_PHYS, LCR, 0x80);      // DLAB: address the divisor latch
  mmio_wr8(UART_PHYS, 0, 0x01);        // divisor low = 1
  mmio_wr8(UART_PHYS, 1, 0x00);        // divisor high = 0
  mmio_wr8(UART_PHYS, LCR, 0x03);      // 8 bits, no parity, 1 stop; DLAB off
  mmio_wr8(UART_PHYS, FCR, 0xc7);      // FIFO: enable, clear, 14-byte threshold
  mmio_wr8(UART_PHYS, MCR, 0x0b);      // DTR, RTS, OUT2
  mmio_wr8(UART_PHYS, IER, 0x01); }    // interrupt when receive data arrives

void serial_putc(int c) {
  if (c == '\n') serial_putc('\r');
  // bounded spin on "transmit holding register empty" so an absent or
  // wedged port cannot hang output.
  for (int i = 0; i < 100000 && !(mmio_rd8(UART_PHYS, LSR) & LSR_THRE); i++) {}
  mmio_wr8(UART_PHYS, THR, (uint8_t) c); }

// reached from k_trap. one interrupt can cover several received bytes, so
// drain the FIFO completely.
static void k_uart(void) {
  while (mmio_rd8(UART_PHYS, LSR) & LSR_DR)
    kq(mmio_rd8(UART_PHYS, RBR)); }

// --- the wall clock: the goldfish rtc -----------------------------------
// nanoseconds since the epoch in two words; reading the low word latches the
// high one. -> UNIX SECONDS.
uint64_t k_rtc(void) {
  uint64_t lo = mmio_rd(RTC_PHYS, 0), hi = mmio_rd(RTC_PHYS, 4);
  return (hi << 32 | lo) / 1000000000; }

// --- the PLIC ----------------------------------------------------------
// one source (the UART) routed to this hart's S-mode context at any priority.
#define PLIC_PRIORITY   0x000          // +4*irq
#define PLIC_ENABLE     0x2000         // +0x80*ctx, one bit per irq
#define PLIC_THRESHOLD  0x200000       // +0x1000*ctx
#define PLIC_CLAIM      0x200004       // +0x1000*ctx: read claims, write completes

static void plic_init(void) {
  mmio_wr(PLIC_PHYS, PLIC_PRIORITY + 4 * UART_IRQ, 1);
  mmio_wr(PLIC_PHYS, PLIC_ENABLE + 0x80 * PLIC_CTX + 4 * (UART_IRQ / 32),
          1u << (UART_IRQ % 32));
  mmio_wr(PLIC_PHYS, PLIC_THRESHOLD + 0x1000 * PLIC_CTX, 0); }

// --- the timer, through SBI -------------------------------------------
// fires the supervisor timer interrupt at ~100 Hz, matching the other two
// arches; the handler rearms it, which is also what clears the pending bit.
static uint64_t timer_interval;        // TIMEBASE / 100

static inline void rearm_timer(void) {
  k_sbi(SBI_TIME, 0, k_rd_time() + timer_interval, 0); }

static void timer_init(void) {
  timer_interval = TIMEBASE / 100;
  rearm_timer(); }

// --- trap dispatch and fault reporting --------------------------------
static char const *fault_kind(uint64_t cause) {
  switch (cause) {
    case 0:  return "instruction misaligned";
    case 1:  return "instruction access";
    case 2:  return "illegal instruction";
    case 3:  return "breakpoint";
    case 4:  return "load misaligned";
    case 5:  return "load access";
    case 6:  return "store misaligned";
    case 7:  return "store access";
    case 8:  return "ecall";
    case 12: return "instruction page fault";
    case 13: return "load page fault";
    case 15: return "store page fault";
    default: return "?"; } }

// reached from the trap entry (mkvec.l) with scause, sepc and stval. the hart
// masked sstatus.SIE on the way in, so the handler cannot nest and sepc holds
// across the call; sret returns through it. an interrupt is served and
// returns; anything else is a fault, reported and halted -- faults are not
// resumed (returning would just re-fault). kput* reach the serial console
// even when no framebuffer is up.
void k_trap(uint64_t cause, uint64_t epc, uint64_t tval) {
  if (cause >> 63) {
    uint64_t n = cause & 0xff;
    if (n == 5) kticks++, rearm_timer();                 // supervisor timer
    else if (n == 9) {                                   // supervisor external
      uint32_t irq = mmio_rd(PLIC_PHYS, PLIC_CLAIM + 0x1000 * PLIC_CTX);
      if (irq == UART_IRQ) k_uart();
      if (irq) mmio_wr(PLIC_PHYS, PLIC_CLAIM + 0x1000 * PLIC_CTX, irq); }
    return; }
  static int nested;
  if (nested) for (;;) k_wait();
  nested = 1;
  kputs("\n*** CPU exception ("), kputs(fault_kind(cause));
  kputs(") cause="), kputn(cause, 16);
  kputs(" epc="),  kputn(epc, 16);
  kputs(" tval="), kputn(tval, 16);
  kputc('\n');
  fbdraw();
  for (;;) k_wait(); }

// --- bring-up and reset -----------------------------------------------
// archinit runs into a civilised environment -- S-mode, sv39 on, a stack, the
// FPU open and the window in place, laid by mkboot.l's stub -- so it only has
// to install the trap entry, the interrupt controller and the timer, then
// unmask interrupts.
void archinit(void) {
  k_wr_stvec((uintptr_t) vectors);
  plic_init();
  timer_init();
  k_sie_set(1u << 5 | 1u << 9);        // STIE | SEIE
  k_sie_on(); }

// (fault n) backend: deliberately raise a CPU exception. n indexes the x86
// vector numbers the builtin shares across arches; here 3 -> breakpoint,
// 13/14 -> store page fault, anything else -> illegal instruction. does not
// return -- k_trap reports and halts.
void k_fault_trigger(intptr_t n) {
 switch (n) {
  case 3:
   k_ebreak();
   break;
  case 13: case 14:  // the first gigabyte past the window's four
   *(volatile int*) 0xffffffc100000000ULL = 0;
   break;
  default:
   k_unimp();
   break; } }

// SBI system reset, a cold reboot. under qemu -no-reboot this is the exit.
void k_reset(void) {
  k_sbi(SBI_SRST, 0, 1, 0);
  for (;;) k_wait(); }
