// x64 C: CPU exceptions (mkvec.l's stubs, through exc_common), the COM1 console, the RTC
#include <stdint.h>
#include "asmops.h"
#include "k.h"
void k_halt(void);

// exc_common's frame from rsp up: the push15 registers, the stub's (vector, error), the iret frame
struct k_frame {
  uint64_t r15, r14, r13, r12, r11, r10, r9, r8,
           rdi, rsi, rdx, rcx, rbx, rax, rbp,
           vector, error, rip, cs, rflags, rsp, ss; };

// the panic path rides kputc/kputs/kputn, which need no love state

static char const *const exc_name[32] = {
  [0]  = "#DE", [1]  = "#DB", [2]  = "NMI", [3]  = "#BP", [4]  = "#OF",
  [5]  = "#BR", [6]  = "#UD", [7]  = "#NM", [8]  = "#DF", [10] = "#TS",
  [11] = "#NP", [12] = "#SS", [13] = "#GP", [14] = "#PF", [16] = "#MF",
  [17] = "#AC", [18] = "#MC", [19] = "#XM", [20] = "#VE", [21] = "#CP", };


// vectors 0..31; a __builtin_trap is #UD with rip at its ud2. never resumed: it would only
// fault again. one from ring 3 ends its process instead of the machine
void k_proc_fault(uint64_t vector);   // x64/proc.c
void k_exception(struct k_frame *fr) {
  if (fr->cs & 3) k_proc_fault(fr->vector);
  k_cli();                             // no interrupts while reporting
  static int nested;
  if (nested) k_halt();                // faulted while reporting
  nested = 1;

  char const *name = fr->vector < 32 ? exc_name[fr->vector] : 0;
  kputs("\n*** CPU exception ");
  kputn(fr->vector, 10);
  kputs(" ("), kputs(name ? name : "?"), kputs(") rip=");
  kputn(fr->rip, 16);
  kputs(" err=");
  kputn(fr->error, 16);
  if (fr->vector == 14) {
    kputs(" cr2="), kputn(k_rd_cr2(), 16); }
  kputc('\n');
  fbdraw();

  k_halt();
}

// COM1, a 16550: a second console, the only one without a framebuffer, and the panic channel,
// touching nothing but I/O ports. input rides IRQ4 into kb_int's queue, bytes verbatim
#define COM1 0x3f8

// once from kmain, after archinit (the IDT is live)
void serial_init(void) {
  k_outb(COM1 + 1, 0x00);    // interrupts off while configuring
  k_outb(COM1 + 3, 0x80);    // DLAB: address the divisor latch
  k_outb(COM1 + 0, 0x01);    // divisor low  = 1  -> 115200 baud
  k_outb(COM1 + 1, 0x00);    // divisor high = 0
  k_outb(COM1 + 3, 0x03);    // 8 bits, no parity, 1 stop; DLAB off
  k_outb(COM1 + 2, 0xc7);    // FIFO: enable, clear, 14-byte threshold
  k_outb(COM1 + 4, 0x0b);    // DTR, RTS, OUT2 (OUT2 gates the IRQ line)
  k_outb(COM1 + 1, 0x01); }  // IER: interrupt when receive data arrives

// the mc146818 RTC: no door answers a boot date, so (clock 0) is a date only through this.
// -> unix seconds, or 0 when the chip says nothing
static uint8_t cmos(uint8_t r) { return k_outb(0x70, r), k_inb(0x71); }
static uint32_t unbcd(uint32_t v) { return (v >> 4) * 10u + (v & 15); }

// days since 1970-01-01; the year starts in March, so the leap day lands at its end
static int64_t civil_days(int64_t y, uint32_t m, uint32_t d) {
  y -= m <= 2;
  int64_t era = (y >= 0 ? y : y - 399) / 400;
  uint32_t yoe = (uint32_t) (y - era * 400),                          // 0..399
           doy = (153 * (m + (m > 2 ? -3u : 9u)) + 2) / 5 + d - 1,    // 0..365
           doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;               // 0..146096
  return era * 146097 + (int64_t) doe - 719468; }

uint64_t k_rtc(void) {
  // wait an update out, or a read across the tick tears; bounded, as an absent chip reads 0xff
  for (int i = 0; i < 100000 && cmos(0x0a) & 0x80; i++) {}
  uint32_t st = cmos(0x0b), s = cmos(0), mi = cmos(2), h = cmos(4),
           d = cmos(7), mo = cmos(8), y = cmos(9),
           pm = !(st & 2) && (h & 0x80);        // 12-hour mode flags the afternoon
  h &= 0x7f;
  if (!(st & 4)) s = unbcd(s), mi = unbcd(mi), h = unbcd(h), d = unbcd(d),
                 mo = unbcd(mo), y = unbcd(y);  // BCD unless bit 2 says binary
  if (!(st & 2)) h = pm ? h % 12 + 12 : h % 12;
  // no chip, or one nobody set: nothing rather than a plausible wrong date
  if (!mo || mo > 12 || !d || d > 31 || h > 23 || mi > 59 || s > 60) return 0;
  return (uint64_t) (civil_days(2000 + (int64_t) y, mo, d) * 86400
                     + h * 3600 + mi * 60 + s); }

void serial_putc(int c) {
  if (c == '\n') serial_putc('\r');
  // bounded, so an absent or wedged port cannot hang output
  for (int i = 0; i < 100000 && !(k_inb(COM1 + 5) & 0x20); i++) {}
  k_outb(COM1, (uint8_t) c); }

// IRQ4, from uart_isr: one interrupt can cover several bytes, so drain the FIFO
void kq(uint8_t);
void k_uart(void) {
  while (k_inb(COM1 + 5) & 0x01)        // LSR bit 0: receive data ready
    kq(k_inb(COM1)); }

// (fault n): raise exception vector n; k_exception reports and halts
void k_fault_trigger(intptr_t n) {
  switch (n) {
    case 0:   // #DE: integer divide by zero
      k_divzero();
      break;
    case 3:   // #BP: breakpoint
      k_int3();
      break;
    case 13:  // #GP: write through a non-canonical address
      *(volatile int*) 0xdeadbeefdeadbeefULL = 0;
      break;
    case 14:  // #PF: write to a canonical but unmapped address
      *(volatile int*) 0x600000000000ULL = 0;
      break;
    default:  // #UD: invalid opcode
      k_ud2();
      break; } }
