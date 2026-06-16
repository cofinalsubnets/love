// Teensy 4.1 bare-metal arch backend (no Teensyduino core): the FlexSPI boot
// image the i.MX RT1062 ROM walks (config block + IVT + boot data), the crt0
// startup, a minimal CCM clock bring-up, the LPUART6 console, GPT1 as the
// millisecond timer, and a thin GPIO layer for the on-board LED. Plays the
// role of arch/<arch>/arch.c for the freestanding kernel, but for a Cortex-M7
// booting XIP from QSPI flash. The FlexSPI/IVT/boot-data blocks and the LUT
// are lifted from the i.MX RT1060 Reference Manual (Serial NOR boot) and
// PJRC's cores/teensy4 bootdata.c; treat them as the verify-first surface.
#include "../../ai.h"
#include "teensy41.h"

// Linker-provided bounds (teensy41.lds).
extern uint32_t __data_start__[], __data_end__[], __data_load__[];
extern uint32_t __bss_start__[], __bss_end__[], __stack_top__[];
extern uint32_t __image_size__[];          // boot_data.length (bytes in flash)
extern void *const vectors[];              // ARM vector table (for VTOR)

int main(void);
void cstartup(void);

// --- the FlexSPI boot image (flash offset 0x000 / 0x1000) ----------------
// 1. FlexSPI Configuration Block at 0x60000000: tells the ROM how to talk to
//    the QSPI NOR (pad type, clock, and the LUT for the quad read at 0xEB).
//    448 meaningful bytes inside a 512-byte block (RT1060 RM 9.6.3.1).
__attribute__((section(".flashconfig"), used))
const uint32_t flexspi_nor_config[128] = {
  [0]  = 0x42464346u,   // "FCFB" tag
  [1]  = 0x56010000u,   // version V1.0
  [3]  = 0x00030301u,   // readSampleClkSrc, csHold=3, csSetup=3, colAddrWidth=0
  [4]  = 0x00000000u,   // deviceModeCfgEnable=0
  [0x18 / 4] = 0x00080401u, // deviceType=1(NOR), padType=4(quad), serialClkFreq=8
  [0x1C / 4] = 0x00000000u,
  [0x1C / 4 + 1] = 0x00800000u, // sflashA1Size = 8 MB (Teensy 4.1)
  // lookupTable[0..]: read sequence (CMD 0xEB, RADDR 24b, DUMMY, READ x4).
  [0xA0 / 4]     = 0x0A1804EBu,
  [0xA0 / 4 + 1] = 0x26043206u,
};

// 2. Image Vector Table at 0x60001000 -- the ROM finds it at the fixed serial
//    NOR offset, validates the header, and jumps to `entry` (our startup).
//    Address fields are uintptr_t (pointer-width = 4 bytes on the thumbv7em
//    target) so the link-time-constant initialisers below need no truncating
//    cast; the IVT stays a packed 8-word block.
struct ivt { uint32_t hdr; uintptr_t entry; uint32_t rsv1; uintptr_t dcd, boot, self, csf; uint32_t rsv2; };
extern const struct ivt image_vector_table;
struct boot_data { uintptr_t start, length, plugin; };

__attribute__((section(".bootdata"), used))
const struct boot_data boot_data = {
  FLASH_BASE, (uintptr_t) __image_size__, 0 };

__attribute__((section(".ivt"), used))
const struct ivt image_vector_table = {
  .hdr   = 0x402000D1u,                  // tag 0xD1, len 0x0020, ver 0x40
  .entry = (uintptr_t) cstartup,         // ROM jumps here
  .dcd   = 0,
  .boot  = (uintptr_t) &boot_data,
  .self  = (uintptr_t) &image_vector_table,
  .csf   = 0 };

// --- fault diagnostics ----------------------------------------------------
// ARMv7E-M HardFault: capture the stacked exception frame so an attached SWD
// debugger lands on a known address. CFSR/HFSR live at the SCB but the frame
// pointer alone localises most faults (pc = the faulting instruction).
volatile struct ai_fault {
  uint32_t r0, r1, r2, r3, r12, lr, pc, psr, sp, magic;
} ai_fault;

__attribute__((used)) void hardfault_report(uint32_t *frame) {
  ai_fault.r0  = frame[0]; ai_fault.r1 = frame[1]; ai_fault.r2 = frame[2];
  ai_fault.r3  = frame[3]; ai_fault.r12 = frame[4]; ai_fault.lr = frame[5];
  ai_fault.pc  = frame[6]; ai_fault.psr = frame[7];
  ai_fault.sp  = (uint32_t)(uintptr_t) frame;
  ai_fault.magic = 0xFA017EDu;
  for (;;) __asm volatile("bkpt 0"); }

__attribute__((naked)) void isr_hardfault(void) {
  __asm volatile(
    "tst lr, #4        \n"   // EXC_RETURN bit 2: which SP was active
    "ite eq            \n"
    "mrseq r0, msp     \n"
    "mrsne r0, psp     \n"
    "b hardfault_report\n"); }

static void default_handler(void) { for (;;) __asm volatile("wfi"); }

// --- crt0 / startup -------------------------------------------------------
// The ROM jumps to `entry` (= reset_handler) with a ROM-provided SP. Establish
// our own stack first, then fall into the C startup. reset_handler is the IVT
// entry; cstartup does the real work once SP is ours.
__attribute__((naked, used, noreturn, section(".startup")))
void cstartup(void) {
  __asm volatile(
    "ldr sp, =__stack_top__ \n"
    "b   cmain              \n"); }

__attribute__((used, noreturn)) void cmain(void) {
  // FPU on (CP10/CP11 full access) before any float-typed code runs.
  REG(SCB_CPACR) |= (0xFu << 20);
  __asm volatile("dsb; isb");
  // .data from its flash load address into OCRAM2; zero .bss.
  for (uint32_t *s = __data_load__, *d = __data_start__; d < __data_end__; ) *d++ = *s++;
  for (uint32_t *b = __bss_start__; b < __bss_end__; b++) *b = 0;
  REG(SCB_VTOR) = (uint32_t)(uintptr_t) vectors;
  clocks_init();
  serial_init();
  main();
  for (;;) __asm volatile("wfi"); }

// --- ARM vector table (in flash; VTOR points here) ------------------------
// The ROM does not use this -- it boots via the IVT -- but the CPU needs it
// for exceptions once we are running. vectors[0] is the initial SP value
// (also loaded by cstartup); the ROM-jump path makes the SP word advisory.
__attribute__((section(".vectors"), used))
void *const vectors[] = {
  (void *) __stack_top__,   // 0  initial SP
  cstartup,                 // 1  reset
  default_handler,          // 2  NMI
  isr_hardfault,            // 3  HardFault
  default_handler,          // 4  MemManage
  default_handler,          // 5  BusFault
  default_handler,          // 6  UsageFault
  0, 0, 0, 0,               // 7..10 reserved
  default_handler,          // 11 SVCall
  default_handler,          // 12 DebugMon
  0,                        // 13 reserved
  default_handler,          // 14 PendSV
  default_handler,          // 15 SysTick
};

// --- clocks ---------------------------------------------------------------
// Scaffold policy: leave the ARM core on the ROM's clock and only set up the
// two roots this frontend reads -- the LPUART clock (24 MHz osc) and GPT1
// (24 MHz osc). Bringing the M7 up to 600 MHz via ARM_PLL is a documented
// TODO (README); it does not change the console or the timebase math.
void clocks_init(void) {
  // Gate LPUART6 (CCGR3 CG3) and GPT1 (CCGR1 CG10/CG11) on.
  REG(CCM_CCGR3) |= CCGR_ON(3);
  REG(CCM_CCGR1) |= CCGR_ON(GPT1_CCGR_BUS) | CCGR_ON(GPT1_CCGR_SERIAL);
  // LPUART clock = 24 MHz osc, no further divide.
  uint32_t c = REG(CCM_CSCDR1);
  c = (c & ~CSCDR1_UART_CLK_PODF_MASK) | CSCDR1_UART_CLK_SEL_OSC;
  REG(CCM_CSCDR1) = c;

  // GPT1: reset, then free-run off the 24 MHz osc with a /24 prescaler so the
  // counter ticks at 1 MHz (1 us). ai_clock() divides to milliseconds.
  REG(GPT1_CR) = GPT_CR_SWR;
  while (REG(GPT1_CR) & GPT_CR_SWR) {}
  REG(GPT1_PR) = 24u - 1u;
  REG(GPT1_CR) = GPT_CR_CLKSRC_24M | GPT_CR_FRR | GPT_CR_ENMOD;
  REG(GPT1_CR) |= GPT_CR_EN; }

// --- LPUART6 console ------------------------------------------------------
void serial_init(void) {
  // pin1 -> LPUART6_TX, pin0 -> LPUART6_RX (both ALT2); daisy-chain the RX.
  REG(IOMUXC_SW_MUX_GPIO_AD_B0_02) = MUX_ALT(2);
  REG(IOMUXC_SW_MUX_GPIO_AD_B0_03) = MUX_ALT(2);
  REG(IOMUXC_LPUART6_RX_SELECT) = 1u;            // select GPIO_AD_B0_03

  // 115200 8N1 from the 24 MHz UART clock: OSR=16, SBR=13 -> 115384 (+0.16%).
  REG(LPUART_CTRL) = 0;                           // disable while configuring
  REG(LPUART_BAUD) = LPUART_BAUD_OSR(16) | LPUART_BAUD_SBR(13) | LPUART_BAUD_BOTHEDGE;
  REG(LPUART_FIFO) |= LPUART_FIFO_TXFE | LPUART_FIFO_RXFE;
  REG(LPUART_CTRL) = LPUART_CTRL_TE | LPUART_CTRL_RE; }

void serial_putc(int c) {
  while (!(REG(LPUART_STAT) & LPUART_STAT_TDRE)) {}
  REG(LPUART_DATA) = (uint32_t)(c & 0xff); }

int serial_rx_ready(void) { return !!(REG(LPUART_STAT) & LPUART_STAT_RDRF); }

int serial_getc(void) {
  while (!(REG(LPUART_STAT) & LPUART_STAT_RDRF)) {}
  return REG(LPUART_DATA) & 0xff; }

// --- clock: milliseconds since boot (GPT1 counts microseconds) -----------
uintptr_t ai_clock(void) { return REG(GPT1_CNT) / 1000u; }

// --- GPIO -----------------------------------------------------------------
// Scaffold scope: GPIO2 bit operations plus the IOMUXC mux for pin 13 (the
// LED). A full Teensy pin map (pad -> GPIO bank/bit -> ALT5 mux, all 55 pins)
// is a TODO; here `pin` is a GPIO2 bit index and pin 13 (LED_BIT) is the one
// pad we mux. Mirrors rp2040.c's gpio_* contract so main.c's nifs are shared.
void gpio_init(unsigned pin) {
  if (pin == LED_BIT) REG(IOMUXC_SW_MUX_GPIO_B0_03) = MUX_ALT(5);
  REG(GPIO2_GDIR) &= ~(1u << pin); }            // input until set_dir

void gpio_set_dir(unsigned pin, int out) {
  if (out) REG(GPIO2_GDIR) |= (1u << pin);
  else     REG(GPIO2_GDIR) &= ~(1u << pin); }

void gpio_put(unsigned pin, int hi) {
  REG(hi ? GPIO2_DR_SET : GPIO2_DR_CLEAR) = 1u << pin; }

int gpio_get(unsigned pin) { return (REG(GPIO2_PSR) >> pin) & 1u; }
