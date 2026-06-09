// loongarch64 architecture-specific C: a 16550A serial console, the
// LoongArch stable-counter timer, and trap dispatch via the EENTRY CSR.
// The vector itself lives in loongarch64.S; archinit points EENTRY at
// it. This is the loongarch64 counterpart of x86_64/arch.c -- same
// contract (archinit, serial_init, serial_putc, k_reset, k_fault_trigger),
// different hardware.
//
// Like riscv64 we keep input polled: the UART IRQ would route through
// the 7A1000 PCH-PIC / extended interrupt controller, which is a lot of
// wiring for no observable benefit on a 100 Hz tick. The timer ISR
// drains the UART each tick.
#include <stdint.h>

extern uintptr_t khhdm;                // Limine HHDM (cached) base; unused for MMIO
extern uint64_t kticks;

void kq(uint8_t);

// trap vector (loongarch64.S)
extern uint8_t trap_vec[];

// --- CSR / CPUCFG access ---------------------------------------------
// LoongArch CSRs are accessed by csrrd/csrwr/csrxchg with an immediate
// CSR number. csrwr swaps -- the GR ends up with the prior CSR value;
// for write-only use we just discard it. CPUCFG indexes a separate
// configuration register file (cc_freq, cc_mul, cc_div live there).
#define CSR_CRMD       0x0             // current mode (PLV, IE, ...)
#define CSR_ECFG       0x4             // VS and LIE
#define CSR_ESTAT      0x5             // exception status (Ecode, IS)
#define CSR_EENTRY     0xc             // exception entry base
#define CSR_TCFG       0x41            // timer config (En/Periodic/InitVal)
#define CSR_TICLR      0x44            // timer interrupt clear
#define CSR_DMW0       0x180           // direct memory window 0
#define CSR_EUEN       0x2             // FPU/LSX/LASX enable (FPE = bit 0)

#define CSR_RD(csr) ({ uint64_t _v; asm volatile ("csrrd %0, %1" : "=r"(_v) : "i"(csr)); _v; })
#define CSR_WR(csr, v) do { uint64_t _t = (v); \
  asm volatile ("csrwr %0, %1" : "+r"(_t) : "i"(csr) : "memory"); } while (0)

static inline uint32_t cpucfg(uint32_t idx) {
  uint32_t r;
  asm volatile ("cpucfg %0, %1" : "=r"(r) : "r"(idx));
  return r; }

// --- direct memory windows -------------------------------------------
// LoongArch maps physical addresses to virtual through up to four DMW
// CSRs, no TLB needed. Limine protocol revision 3 leaves DMW0-3 in an
// undefined state -- it gives us the HHDM through proper TLB-mapped
// page tables instead, so RAM access via khhdm just works. We install
// DMW0 ourselves to give us a strongly-uncached window for MMIO: the
// UART isn't in the HHDM (which only covers RAM) and isn't cacheable.
// DMW field layout:
//   bit 0: valid at PLV0      bits 4-5: MAT (0=SUC, 1=CC, 2=WUC)
//   bits 60-63: VSEG (the top 4 bits of VA matched by this window)
#define DMW_MMIO_BASE  0x8000000000000000ULL
#define DMW0_VAL       0x8000000000000001ULL  // VSEG=8, MAT=SUC, PLV0

static inline uint8_t mmio_rd8(uintptr_t phys, uintptr_t off) {
  return *(volatile uint8_t*) (DMW_MMIO_BASE + phys + off); }
static inline void mmio_wr8(uintptr_t phys, uintptr_t off, uint8_t v) {
  *(volatile uint8_t*) (DMW_MMIO_BASE + phys + off) = v; }

// --- 16550A serial console -------------------------------------------
// The QEMU 'virt' loongarch64 machine puts a NS16550A UART at the
// Loongson-3 legacy address 0x1FE001E0, byte-stride register file. The
// init sequence and register offsets are the same as the COM1 16550
// in x86_64/arch.c. Output is the panic channel: it touches only the
// UART MMIO so it still works when the heap and framebuffer are
// unusable. Input is polled from the timer ISR.
#define UART_PHYS  0x1FE001E0ULL
#define UART_RBR   0                   // receive buffer (read) / data (write)
#define UART_IER   1                   // interrupt enable
#define UART_FCR   2                   // FIFO control
#define UART_LCR   3                   // line control
#define UART_MCR   4                   // modem control
#define UART_LSR   5                   // line status
#define UART_DLL   0                   // divisor latch low  (when LCR.DLAB=1)
#define UART_DLH   1                   // divisor latch high (when LCR.DLAB=1)
#define LSR_DR     0x01                // receive data ready
#define LSR_THRE   0x20                // transmit holding register empty

void serial_init(void) {
  mmio_wr8(UART_PHYS, UART_IER, 0x00);       // interrupts off (we poll)
  mmio_wr8(UART_PHYS, UART_LCR, 0x80);       // DLAB: address the divisor latch
  mmio_wr8(UART_PHYS, UART_DLL, 0x01);       // divisor low  = 1 -> 115200 baud
  mmio_wr8(UART_PHYS, UART_DLH, 0x00);
  mmio_wr8(UART_PHYS, UART_LCR, 0x03);       // 8N1, DLAB off
  mmio_wr8(UART_PHYS, UART_FCR, 0xc7);       // FIFO: enable, clear, 14-byte threshold
  mmio_wr8(UART_PHYS, UART_MCR, 0x03); }     // DTR, RTS

void serial_putc(int c) {
  if (c == '\n') serial_putc('\r');
  // bounded spin on "transmit holding register empty" so an absent or
  // wedged port cannot hang output.
  for (int i = 0; i < 100000 && !(mmio_rd8(UART_PHYS, UART_LSR) & LSR_THRE); i++) {}
  mmio_wr8(UART_PHYS, UART_RBR, (uint8_t) c); }

static void k_uart_poll(void) {
  while (mmio_rd8(UART_PHYS, UART_LSR) & LSR_DR)
    kq(mmio_rd8(UART_PHYS, UART_RBR)); }

// --- periodic timer --------------------------------------------------
// The LoongArch stable counter ticks at cc_freq * cc_mul / cc_div,
// reported through CPUCFG[4] (cc_freq) and CPUCFG[5] (cc_mul in bits
// 0..15, cc_div in bits 16..31). On QEMU virt this comes out to 100 MHz.
// TCFG holds the periodic reload value in bits 2..N with the low two
// bits forced to zero, plus En (bit 0) and Periodic (bit 1). 100 Hz
// matches the x86_64 PIT and aarch64 generic timer cadence.
#define TIMER_HZ  100

static void timer_init(void) {
  uint32_t cc_freq = cpucfg(4);
  uint32_t cfg = cpucfg(5);
  uint32_t cc_mul = cfg & 0xffff;
  uint32_t cc_div = (cfg >> 16) & 0xffff;
  if (!cc_mul || !cc_div) cc_mul = cc_div = 1;    // fall back if firmware lied
  uint64_t freq = (uint64_t) cc_freq * cc_mul / cc_div;
  uint64_t count = (freq / TIMER_HZ) & ~3ULL;     // low 2 bits forced to 0
  CSR_WR(CSR_TCFG, count | 0x3); }                // InitVal | Periodic | En

// --- trap dispatch ---------------------------------------------------
// ESTAT bits 16-21 hold Ecode, the exception class. Ecode 0 means
// interrupt: ESTAT bits 0-12 (IS) say which source(s) fired -- bit 11
// is TI (timer interrupt). Everything else is a synchronous exception
// we treat as a fatal fault (report and halt: returning would just
// re-execute the faulting instruction).
#define ECODE_SHIFT  16
#define ECODE_MASK   0x3f
#define IS_TIMER     (1u << 11)
#define ECODE_INT    0x00
#define ECODE_PIL    0x01              // page invalid (load)
#define ECODE_PIS    0x02              // page invalid (store)
#define ECODE_PIF    0x03              // page invalid (fetch)
#define ECODE_PME    0x04              // page modify (write to RO)
#define ECODE_ADE    0x08              // address error (fetch or memory; EsubCode picks)
#define ECODE_ALE    0x09              // alignment error
#define ECODE_BCE    0x0a              // bound check error
#define ECODE_SYS    0x0b              // syscall
#define ECODE_BRK    0x0c              // breakpoint
#define ECODE_INE    0x0d              // instruction non-existent
#define ECODE_IPE    0x0e              // instruction privilege error

// Standalone string + hex printers used by the panic path -- no
// dependencies beyond serial_putc, so they work even when the heap,
// framebuffer console, and ll state are unusable.
static void pserial(char const *s) {
  while (*s) serial_putc(*s++); }
static void pserialx(uint64_t v) {
  static char const hex[] = "0123456789abcdef";
  char buf[16];
  for (int i = 15; i >= 0; i--) buf[i] = hex[v & 0xf], v >>= 4;
  for (int i = 0; i < 16; i++) serial_putc(buf[i]); }

static char const *fault_kind(uint64_t ecode) {
  switch (ecode) {
    case ECODE_PIL:  return "page invalid (load)";
    case ECODE_PIS:  return "page invalid (store)";
    case ECODE_PIF:  return "page invalid (fetch)";
    case ECODE_PME:  return "page modify";
    case ECODE_ADE:  return "address error";
    case ECODE_ALE:  return "alignment error";
    case ECODE_BCE:  return "bound check error";
    case ECODE_SYS:  return "syscall";
    case ECODE_BRK:  return "breakpoint";
    case ECODE_INE:  return "illegal instruction";
    case ECODE_IPE:  return "privilege error";
    default:         return "?"; } }

// Reached from trap_vec. For the timer interrupt, advance kticks, drain
// any pending input, then clear TICLR and return so ertn resumes the
// interrupted code. For other interrupt sources (unconfigured here),
// return silently. For synchronous exceptions, report and halt.
void k_trap_c(uint64_t estat, uint64_t era, uint64_t badv) {
  uint64_t ecode = (estat >> ECODE_SHIFT) & ECODE_MASK;
  if (ecode == ECODE_INT) {
    if (estat & IS_TIMER) {
      kticks++;
      k_uart_poll();
      CSR_WR(CSR_TICLR, 1); }
    return; }

  // Exception entry clears CRMD.IE for us; no need to mask interrupts again.
  static int nested;
  if (nested) for (;;) asm volatile ("idle 0");
  nested = 1;
  pserial("\n*** CPU exception ("); pserial(fault_kind(ecode));
  pserial(") era=");    pserialx(era);
  pserial(" estat=");   pserialx(estat);
  pserial(" badv=");    pserialx(badv);
  serial_putc('\n');
  for (;;) asm volatile ("idle 0"); }

// --- bring-up and reset ----------------------------------------------
// Limine hands us a civilised environment -- PLV0, paging on, the HHDM
// in place, a stack -- so archinit only has to install our DMW0 for
// MMIO, the trap vector, the timer, and unmask interrupts.
void archinit(void) {
  // EUEN.FPE = 1: enable basic FPU so g.c can use doubles. Limine
  // leaves FPE = 0 and the first FP instruction would raise #FPD.
  CSR_WR(CSR_EUEN, 1);
  // DMW0 first: until our own SUC window is up, MMIO is unreachable
  // (Limine leaves DMW state undefined under protocol revision 3, and
  // the HHDM only covers RAM).
  CSR_WR(CSR_DMW0, DMW0_VAL);
  CSR_WR(CSR_EENTRY, (uint64_t) trap_vec);       // all exceptions -> trap_vec
  // TLBRENTRY is intentionally left alone: Limine installs a TLB-refill
  // handler that walks the page tables it set up for the kernel image
  // and HHDM, and the kernel relies on those refills working.
  CSR_WR(CSR_ECFG, IS_TIMER);                    // VS=0 (single entry), enable TI in LIE
  timer_init();
  // CRMD.IE = 1: global interrupt enable. csrxchg lets us touch only
  // bit 2 without clobbering PLV / DA / PG.
  uint64_t v = 1ULL << 2, m = 1ULL << 2;
  asm volatile ("csrxchg %0, %1, %2"
                : "+r"(v) : "r"(m), "i"(CSR_CRMD) : "memory"); }

// LoongArch has no standard firmware reset like PSCI/SBI. On QEMU's
// virt machine a clean shutdown would go through the ACPI GED device,
// which needs an AML parser we don't have; halt visibly instead so the
// user can see (reboot) was honoured before terminating QEMU.
void k_reset(void) {
  for (;;) asm volatile ("idle 0"); }

// (fault n) backend: deliberately raise a CPU exception. n indexes the
// x86 vector numbers the builtin shares across arches; on loongarch64
// we map 3 -> break, 13/14 -> address error (write a non-canonical VA;
// ADEM is raised before TLB lookup, so we don't depend on a refill
// handler), anything else -> illegal instruction via a reserved
// encoding. does not return -- k_trap_c reports and halts.
void k_fault_trigger(intptr_t n) {
  switch (n) {
    case 3:            // breakpoint
      asm volatile ("break 0");
      break;
    case 13: case 14:  // address error: non-canonical VA, faulted before TLB
      *(volatile int*) 0x0000800000000000ULL = 0;
      break;
    default:           // illegal instruction (reserved encoding)
      asm volatile (".word 0xffffffff");
      break; } }
