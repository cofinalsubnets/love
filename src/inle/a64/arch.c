// a64 arch C: the PL011 console, the GICv2, the generic timer, exception reporting. the
// vectors are src/inle/mkvec.l's; the contract is x64/arch.c's (archinit, serial_*, k_reset)
#include <stdint.h>
#include "asmops.h"                    // the privileged instructions, both spellings
#include "k.h"                       // kboot, and kputc/kputs/kputn (src/inle/kmain.c)
#include "../mmio.h"                  // mmio_rd/mmio_wr, device registers off the direct map

void kq(uint8_t);                      // kmain's input queue, one byte

// qemu virt's fixed MMIO; another board would read the device tree
#define UART_PHYS   0x09000000         // PL011 UART
#define RTC_PHYS    0x09010000         // PL031 RTC -- inside the UART's 2MiB block
#define GICD_PHYS   0x08000000         // GICv2 distributor
#define GICC_PHYS   0x08010000         // GICv2 CPU interface
#define VIRTIO_PHYS 0x0a000000         // the 32 virtio-mmio slots (blk.c scans them)
#define UART_INTID  33                 // PL011 -> SPI 1 -> INTID 32+1
#define TIMER_INTID 30                 // EL1 physical timer -> PPI INTID 30

// the HHDM covers RAM only: mmio_map lays 2MiB blocks for the devices in the live TTBR1
// tables, one L2 for the first 1GiB. MAIR is shared with the standing mappings: read, never edited
#define PA_MASK  0x0000fffffffff000ULL  // descriptor output addr, bits 47:12
#define BLK_MASK 0x0000ffffffe00000ULL  // 2MiB block output addr, bits 47:21

static uint64_t l2_table[512] __attribute__((aligned(4096)));

static uintptr_t va2pa(void *va) {
  uint64_t par = k_at_s1e1w_par(va);
  return (par & PA_MASK) | ((uintptr_t) va & 0xfff); }

// the MAIR slot for devices: a Device attribute, then Normal non-cacheable, then write-back
static uint32_t mmio_attr_index(void) {
  uint64_t mair = k_rd_mair_el1();
  static uint8_t const prefer[] = { 0x00, 0x04, 0x08, 0x0c, 0x44, 0xff };
  for (uint32_t p = 0; p < sizeof prefer; p++)
    for (uint32_t i = 0; i < 8; i++)
      if (((mair >> (i*8)) & 0xff) == prefer[p]) return i;
  return 0; }

static void mmio_map(void) {
  uint32_t attr = mmio_attr_index();
  uint64_t ttbr1 = k_rd_ttbr1_el1();
  uint64_t *l0 = (uint64_t*) (khhdm + (ttbr1 & PA_MASK));

  // the devices share L0/L1 indices
  uintptr_t va = khhdm + GICD_PHYS;
  uint64_t l0e = l0[(va >> 39) & 0x1ff];
  uint64_t *l1 = (uint64_t*) (khhdm + (l0e & PA_MASK));
  uint64_t l1e = l1[(va >> 30) & 0x1ff];
  uint64_t *l2;
  if (l1e & 1) l2 = (uint64_t*) (khhdm + (l1e & PA_MASK));
  else {                                       // empty slot: supply our own L2
    l2 = l2_table;
    l1[(va >> 30) & 0x1ff] = (va2pa(l2_table) & PA_MASK) | 3; }

  uintptr_t const dev[] = { GICD_PHYS, UART_PHYS, VIRTIO_PHYS };
  for (uint32_t i = 0; i < 3; i++)
    l2[((khhdm + dev[i]) >> 21) & 0x1ff] =
        (dev[i] & BLK_MASK)
      | (1ULL << 54) | (1ULL << 53)            // UXN | PXN: never execute
      | (1ULL << 10)                           // AF: access flag
      | (3ULL << 8)                            // inner shareable
      | ((uint64_t) attr << 2)                 // MAIR attribute index
      | 1ULL;                                  // valid; bit 1 clear => block

  k_tlbi_all(); }

// PL011 console, also the panic channel. input by interrupt: a burst at the FIFO threshold,
// a lone key by the receive timeout
#define UARTDR    0x000                // data register
#define UARTFR    0x018                // flag register
#define UARTLCR_H 0x02c                // line control
#define UARTCR    0x030                // control register
#define UARTIMSC  0x038                // interrupt mask set/clear
#define UARTICR   0x044                // interrupt clear
#define FR_RXFE   (1u << 4)            // receive holding register empty
#define FR_TXFF   (1u << 5)            // transmit holding register full

// the PL031 RTC, unix seconds; mapped by the UART's block, so only after archinit
uint64_t k_rtc(void) { return mmio_rd(RTC_PHYS, 0); }

// once from kmain, after archinit has the GIC up
void serial_init(void) {
  mmio_wr(UART_PHYS, UARTCR, 0);                  // disable while configuring
  mmio_wr(UART_PHYS, UARTICR, 0x7ff);             // clear any pending interrupts
  mmio_wr(UART_PHYS, UARTLCR_H, (3u<<5)|(1u<<4)); // 8 bits, no parity, FIFO on
  mmio_wr(UART_PHYS, UARTIMSC, (1u<<4)|(1u<<6));  // receive + receive-timeout
  mmio_wr(UART_PHYS, UARTCR, (1u<<0)|(1u<<8)|(1u<<9)); }  // UARTEN|TXE|RXE

void serial_putc(int c) {
  if (c == '\n') serial_putc('\r');
  // bounded, so an absent or wedged port can't hang output
  for (int i = 0; i < 100000 && (mmio_rd(UART_PHYS, UARTFR) & FR_TXFF); i++) {}
  mmio_wr(UART_PHYS, UARTDR, (uint8_t) c); }

// from k_irq: drain, then clear receive and receive-timeout
static void k_uart(void) {
  while (!(mmio_rd(UART_PHYS, UARTFR) & FR_RXFE))
    kq(mmio_rd(UART_PHYS, UARTDR) & 0xff);
  mmio_wr(UART_PHYS, UARTICR, (1u<<4) | (1u<<6)); }

// GICv2
#define GICD_CTLR       0x000          // distributor control
#define GICD_ISENABLER  0x100          // set-enable, +4*(intid/32)
#define GICD_IPRIORITYR 0x400          // priority, byte at +intid
#define GICD_ITARGETSR  0x800          // CPU target, byte at +intid
#define GICC_CTLR       0x000          // CPU interface control
#define GICC_PMR        0x004          // priority mask
#define GICC_IAR        0x00c          // interrupt acknowledge
#define GICC_EOIR       0x010          // end of interrupt

static void gic_enable(uint32_t intid, int is_spi) {
  mmio_wr8(GICD_PHYS, GICD_IPRIORITYR + intid, 0);     // highest priority
  if (is_spi)                                          // SPIs need CPU routing;
    mmio_wr8(GICD_PHYS, GICD_ITARGETSR + intid, 1);    // PPIs are banked per-CPU
  mmio_wr(GICD_PHYS, GICD_ISENABLER + 4*(intid/32), 1u << (intid%32)); }

static void gic_init(void) {
  mmio_wr(GICC_PHYS, GICC_CTLR, 0);          // CPU interface off while configuring
  mmio_wr(GICD_PHYS, GICD_CTLR, 0);          // distributor off
  gic_enable(TIMER_INTID, 0);
  gic_enable(UART_INTID, 1);
  mmio_wr(GICD_PHYS, GICD_CTLR, 1);          // enable distributor
  mmio_wr(GICC_PHYS, GICC_PMR, 0xf0);        // unmask all interrupt priorities
  mmio_wr(GICC_PHYS, GICC_CTLR, 1); }        // enable CPU interface

// the EL1 physical timer at ~100 Hz; the reload also deasserts the interrupt
static uint64_t timer_interval;        // CNTFRQ_EL0 / 100

static inline void rearm_timer(void) { k_wr_cntp_tval_el0(timer_interval); }

static void timer_init(void) {
  timer_interval = k_rd_cntfrq_el0() / 100;
  rearm_timer();
  k_wr_cntp_ctl_el0(1); }               // enable

// from the IRQ vector; an INTID of 1020+ is spurious and must not be acknowledged
void k_irq(void) {
  uint32_t iar = mmio_rd(GICC_PHYS, GICC_IAR), intid = iar & 0x3ff;
  if (intid >= 1020) return;
  if (intid == TIMER_INTID) kticks++, rearm_timer();
  else if (intid == UART_INTID) k_uart();
  mmio_wr(GICC_PHYS, GICC_EOIR, iar); }

// CPU exception reporting
static char const *fault_kind(uint64_t esr) {
  switch (esr >> 26) {                 // ESR_EL1.EC -- exception class
    case 0x15: return "SVC";
    case 0x20: case 0x21: return "instruction abort";
    case 0x22: return "PC alignment";
    case 0x24: case 0x25: return "data abort";
    case 0x26: return "SP alignment";
    case 0x2c: return "FP";
    default:   return "?"; } }

// from the sync/FIQ/SError vectors: report and halt. kput* need no struct g
void k_fault(uint64_t esr, uint64_t elr, uint64_t far) {
  k_daif_mask_all();                   // all interrupts off while reporting
  static int nested;
  if (nested) for (;;) k_wait();
  nested = 1;
  kputs("\n*** CPU exception ("), kputs(fault_kind(esr));
  kputs(") esr="), kputn(esr, 16);
  kputs(" elr="),  kputn(elr, 16);
  kputs(" far="),  kputn(far, 16);
  kputc('\n');
  fbdraw();
  for (;;) k_wait(); }

// archinit finds EL1, the MMU, a stack and the HHDM up: it adds vectors, GIC and timer
void archinit(void) {
  // a bootloader may enter at EL1t with FP/SIMD trapping: settle both before anything faults
  k_sp_to_el1h();
  k_fpen_enable();
  k_wr_vbar_el1((uintptr_t) vectors);
  if (khhdm) mmio_map();
  gic_init();
  timer_init();
  k_daif_unmask_irq(); }               // unmask IRQ (DAIF.I = 0)

// (fault n): n is an x86 vector number; 3 a breakpoint, 13/14 a data abort, else undefined.
// k_fault halts
void k_fault_trigger(intptr_t n) {
 switch (n) {
  case 3:            // breakpoint
   k_brk0();
   break;
  case 13: case 14:  // data abort: write to an unmapped address
   *(volatile int*) 0x600000000000ULL = 0;
   break;
  default:           // undefined instruction
   k_udf0();
   break; } }

// PSCI SYSTEM_RESET, over HVC on virt
void k_reset(void) {
  k_psci_system_reset();
  for (;;) k_wait(); }
