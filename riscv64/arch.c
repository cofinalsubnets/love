// riscv64 architecture-specific C: an SBI-backed serial console,
// an SBI-backed periodic timer, and S-mode trap dispatch. The trap
// vector itself lives in riscv64.S; archinit points stvec at it.
// This is the riscv64 counterpart of x86_64/arch.c -- same contract
// (archinit, serial_init, serial_putc, k_reset), different hardware.
//
// Unlike x86_64 (PIC + COM1 I/O ports) and aarch64 (GIC + PL011
// MMIO), we route everything through OpenSBI: M-mode firmware sits
// between us and the hardware, so we get a portable console, a
// portable timer, and portable reset without ever touching the
// NS16550A UART or the PLIC. The trade-off is polled input: there
// is no SBI "input ready" interrupt, so the timer ISR drains any
// pending console bytes on each tick. At 100 Hz the worst-case
// keystroke latency is one tick, which the line editor doesn't notice.
#include <stdint.h>

extern uintptr_t khhdm;                // unused here; SBI hides MMIO
extern uint64_t kticks;

void kq(uint8_t);

// trap vector (riscv64.S)
extern uint8_t trap_vec[];

// --- SBI shim --------------------------------------------------------
// SBI is the M-mode firmware ABI. ecall traps from S-mode into the
// firmware (OpenSBI under QEMU); a7 carries the extension ID, a6 the
// function ID, a0..a5 the arguments, and a0/a1 the (error, value)
// return pair. The legacy console (EID 1 putchar, EID 2 getchar)
// predates the FID convention -- a7 alone selects the call -- but it
// is universally available and matches what we need. The Time and
// System Reset extensions are SBI v0.2/v1.0, present in every OpenSBI
// the QEMU virt machine ships with.
#define SBI_EID_LEGACY_PUTCHAR  0x01
#define SBI_EID_LEGACY_GETCHAR  0x02
#define SBI_EID_TIME            0x54494D45  // "TIME"
#define SBI_EID_SRST            0x53525354  // "SRST"

static void sbi_putchar(int c) {
  register uintptr_t a0 asm("a0") = (uintptr_t) c;
  register uintptr_t a7 asm("a7") = SBI_EID_LEGACY_PUTCHAR;
  asm volatile ("ecall" : "+r"(a0) : "r"(a7) : "memory"); }

static intptr_t sbi_getchar(void) {
  register intptr_t a0 asm("a0");
  register uintptr_t a7 asm("a7") = SBI_EID_LEGACY_GETCHAR;
  asm volatile ("ecall" : "=r"(a0) : "r"(a7) : "memory");
  return a0; }                          // byte 0..255, or -1 if empty

static void sbi_set_timer(uint64_t when) {
  register uintptr_t a0 asm("a0") = (uintptr_t) when;
  register uintptr_t a6 asm("a6") = 0;
  register uintptr_t a7 asm("a7") = SBI_EID_TIME;
  asm volatile ("ecall" : "+r"(a0) : "r"(a6), "r"(a7) : "memory"); }

static void sbi_system_reset(uintptr_t type, uintptr_t reason) {
  register uintptr_t a0 asm("a0") = type;
  register uintptr_t a1 asm("a1") = reason;
  register uintptr_t a6 asm("a6") = 0;
  register uintptr_t a7 asm("a7") = SBI_EID_SRST;
  asm volatile ("ecall" : "+r"(a0), "+r"(a1) : "r"(a6), "r"(a7) : "memory"); }

// --- serial console --------------------------------------------------
// Routed through SBI: portable across boards (whatever console the
// firmware was configured for receives our output), and short. Input
// is drained from the timer ISR, not from an interrupt -- see comments
// at the top of the file.
void serial_init(void) {}

void serial_putc(int c) {
  if (c == '\n') sbi_putchar('\r');
  sbi_putchar(c); }

static void k_uart_poll(void) {
  intptr_t b;
  while ((b = sbi_getchar()) >= 0) kq((uint8_t) b); }

// --- periodic timer --------------------------------------------------
// The RV64 `time` CSR ticks at a board-defined frequency reported via
// the device tree; on QEMU virt and every real board observed so far
// it is 10 MHz. 100 Hz matches the x86_64 PIT and aarch64 generic
// timer cadence -- the rest of the kernel does not care about the
// exact rate, only that kticks advances predictably.
#define TIMER_HZ      100
#define TIMEBASE      10000000ULL
#define TIMER_PERIOD  (TIMEBASE / TIMER_HZ)

static inline uint64_t rd_time(void) {
  uint64_t v; asm volatile ("rdtime %0" : "=r"(v));  return v; }

static void rearm_timer(void) {
  sbi_set_timer(rd_time() + TIMER_PERIOD); }

// --- trap dispatch ---------------------------------------------------
// scause's MSB distinguishes interrupts (1) from synchronous
// exceptions (0); the remaining bits give the cause code. We only
// route the supervisor timer interrupt (cause 5); the supervisor
// external interrupt would need the PLIC, and we deliberately skip
// it -- input polls from the timer instead. Any other interrupt
// (software, spurious external) just returns silently.
#define SCAUSE_INT          (1ULL << 63)
#define SCAUSE_S_TIMER      5

// Standalone string + hex printers used by the panic path -- no
// dependencies beyond serial_putc, so they work even when the heap,
// framebuffer console, and gwen state are unusable.
static void pserial(char const *s) {
  while (*s) serial_putc(*s++); }
static void pserialx(uint64_t v) {
  static char const hex[] = "0123456789abcdef";
  char buf[16];
  for (int i = 15; i >= 0; i--) buf[i] = hex[v & 0xf], v >>= 4;
  for (int i = 0; i < 16; i++) serial_putc(buf[i]); }

static char const *fault_kind(uint64_t cause) {
  switch (cause) {                     // synchronous exception causes
    case 0:  return "insn misaligned";
    case 1:  return "insn access fault";
    case 2:  return "illegal insn";
    case 3:  return "breakpoint";
    case 4:  return "load misaligned";
    case 5:  return "load access fault";
    case 6:  return "store misaligned";
    case 7:  return "store access fault";
    case 8:  return "ecall U";
    case 9:  return "ecall S";
    case 12: return "insn page fault";
    case 13: return "load page fault";
    case 15: return "store page fault";
    default: return "?"; } }

// Reached from trap_vec. For interrupts, handle and return so sret
// resumes the interrupted code. For exceptions, report and halt --
// returning would re-execute the faulting instruction and fault again.
void k_trap_c(uint64_t cause, uint64_t epc, uint64_t tval) {
  if (cause & SCAUSE_INT) {
    if ((cause & ~SCAUSE_INT) == SCAUSE_S_TIMER)
      kticks++, k_uart_poll(), rearm_timer();
    return; }

  asm volatile ("csrci sstatus, 2");   // SIE off while reporting
  static int nested;
  if (nested) for (;;) asm volatile ("wfi");
  nested = 1;
  // The fault reporter is the panic channel: it must touch nothing
  // but the SBI console. The framebuffer console (gputs/gputn) needs
  // a live gwen state, which we do not have here; serial_putc is
  // standalone (one ecall per byte) and works whether or not the
  // heap, console buffer, and framebuffer ever came up.
  pserial("\n*** CPU exception ("); pserial(fault_kind(cause));
  pserial(") epc=");   pserialx(epc);
  pserial(" cause=");  pserialx(cause);
  pserial(" tval=");   pserialx(tval);
  serial_putc('\n');
  for (;;) asm volatile ("wfi"); }

// --- bring-up and reset ----------------------------------------------
// Limine hands us a civilised environment -- S-mode, MMU on, HHDM in
// place, a stack -- so archinit only has to install our trap vector,
// arm the first timer, and unmask interrupts.
void archinit(void) {
  // sstatus.FS = 0b01 (Initial): enable F/D extension registers.
  // SBI leaves FS = 0b00 (Off), which traps on any FP instruction.
  asm volatile ("csrs sstatus, %0" :: "r"((uintptr_t) (1u << 13)) : "memory");
  // stvec: low 2 bits select mode; 0 = direct (single entry point).
  // trap_vec is 4-byte aligned (.balign 4 in riscv64.S), satisfying
  // the mode-0 alignment requirement.
  asm volatile ("csrw stvec, %0" :: "r"((uintptr_t) trap_vec) : "memory");
  // sie: enable supervisor timer interrupt (STIE = bit 5). Leave SEIE
  // (external) and SSIE (software) masked -- we have no use for them.
  asm volatile ("csrs sie, %0" :: "r"((uintptr_t) (1u << 5)));
  rearm_timer();
  // sstatus.SIE (bit 1): global supervisor interrupt enable.
  asm volatile ("csrsi sstatus, 2"); }

// (fault n) backend: deliberately raise a CPU exception. n indexes the
// x86 vector numbers the builtin shares across arches; on riscv64 we
// map 3 -> breakpoint, 13/14 -> store page/access fault, anything else
// -> illegal instruction. does not return -- k_trap_c reports and halts.
void k_fault_trigger(intptr_t n) {
  switch (n) {
    case 3:            // breakpoint
      asm volatile ("ebreak");
      break;
    case 13: case 14:  // store page/access fault: write to an unmapped address
      *(volatile int*) 0x600000000000ULL = 0;
      break;
    default:           // illegal instruction
      asm volatile ("unimp");
      break; } }

// SBI System Reset: type 0 = shutdown (QEMU exits cleanly). The call
// does not return on a conforming SBI; the wfi loop is a safety net.
void k_reset(void) {
  sbi_system_reset(0, 0);
  for (;;) asm volatile ("wfi"); }
