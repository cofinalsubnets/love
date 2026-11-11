// x64 C: CPU exceptions (mkvec.l's stubs, through exc_common), the COM1 console, the RTC
#include <errno.h>
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

// a guest of the firmware runs no timer of its own: the ticks follow the tsc
extern uint64_t kticks;
void k_tick_sync(void) {
  if (kboot.efi_st && kboot.tsc_khz)
    kticks = (k_rdtsc() - kboot.tsc0) / (kboot.tsc_khz * 10); }   // k_tick_ms

// ..and its keys are ConIn's, the firmware's serial terminal and keyboards alike: a key's
// unicode as utf-8, an arrow or edit key as the vt sequence the console reads
void k_kb_sync(int room) {
  if (!kboot.efi_st) return;
  void **st = kboot.efi_st, **in = st[6];
  static char const *const scan[24] = {
    [1] = "\033[A", [2] = "\033[B", [3] = "\033[C", [4] = "\033[D", [5] = "\033[H", [6] = "\033[F",
    [7] = "\033[2~", [8] = "\033[3~", [9] = "\033[5~", [10] = "\033[6~", [23] = "\033" };
  for (struct { uint16_t sc, ch; } key; room >= 4
       && !kboot.efi_call(in[1], (uintptr_t) in, (uintptr_t) &key, 0, 0, 0, 0); ) {
    uint32_t c = key.ch;
    if (c) {
      if (c < 0x80) kq((uint8_t) c), room--;
      else if (c < 0x800) kq((uint8_t) (0xc0 | c >> 6)), kq((uint8_t) (0x80 | (c & 63))), room -= 2;
      else kq((uint8_t) (0xe0 | c >> 12)), kq((uint8_t) (0x80 | (c >> 6 & 63))),
           kq((uint8_t) (0x80 | (c & 63))), room -= 3; }
    else if (key.sc < 24 && scan[key.sc])
      for (char const *s = scan[key.sc]; *s; s++) kq((uint8_t) *s), room--; } }

// (kexec path cmd) for a guest: the firmware loads path off our own volume, '/' its '\\', and
// starts it with cmd as its LoadOptions; it answers the status should the image return, a
// refused load -1000 less its EFI status
long k_kexec(char const *p, uintptr_t pn, char const *cmd, uintptr_t cn) {
  if (!kboot.efi_st) return -ENOSYS;
  void **st = kboot.efi_st, **bs = st[12];
  uintptr_t (*ec)(void *, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t) = kboot.efi_call;
  static uint8_t const
    lip_g[16] = {0xa1,0x31,0x1b,0x5b,0x62,0x95,0xd2,0x11,0x8e,0x3f,0x00,0xa0,0xc9,0x69,0x72,0x3b},
    dp_g[16] = {0x91,0x6e,0x57,0x09,0x3f,0x6d,0xd2,0x11,0x8e,0x39,0x00,0xa0,0xc9,0x69,0x72,0x3b};
  void **lip = 0;
  uint8_t *dp = 0;
  if (ec(bs[19], (uintptr_t) kboot.efi_image, (uintptr_t) lip_g, (uintptr_t) &lip, 0, 0, 0)
      || ec(bs[19], (uintptr_t) lip[3], (uintptr_t) dp_g, (uintptr_t) &dp, 0, 0, 0)) return -ENODEV;
  // the volume's path, then a file node and the end
  uintptr_t vn = 0;
  while (dp[vn] != 0x7f) vn += (uintptr_t) (dp[vn + 2] | dp[vn + 3] << 8);
  uintptr_t fn = 4 + 2 * (pn + 1), n = vn + fn + 4;
  uint8_t *path = 0;
  if (ec(bs[8], 2, n, (uintptr_t) &path, 0, 0, 0)) return -ENOMEM;   // AllocatePool, LoaderData
  for (uintptr_t i = 0; i < vn; i++) path[i] = dp[i];
  uint8_t *f = path + vn;
  f[0] = 4, f[1] = 4, f[2] = (uint8_t) fn, f[3] = (uint8_t) (fn >> 8);
  for (uintptr_t i = 0; i <= pn; i++) {
    uint16_t c = i < pn ? (uint8_t) p[i] : 0;
    if (c == '/') c = '\\';
    f[4 + 2 * i] = (uint8_t) c, f[5 + 2 * i] = (uint8_t) (c >> 8); }
  f[fn] = 0x7f, f[fn + 1] = 0xff, f[fn + 2] = 4, f[fn + 3] = 0;
  void *h = 0;
  uintptr_t r = ec(bs[25], 0, (uintptr_t) kboot.efi_image, (uintptr_t) path, 0, 0, (uintptr_t) &h);
  ec(bs[9], (uintptr_t) path, 0, 0, 0, 0, 0);
  if (r) return -1000 - (long) (r & 0xffff);         // the EFI status, past -errno's range
  // LoadOptions: cmd as UCS-2, nul-terminated, in pool the child may keep
  uint16_t *o = 0;
  void **cl = 0;
  if (!ec(bs[8], 2, 2 * (cn + 1), (uintptr_t) &o, 0, 0, 0)
      && !ec(bs[19], (uintptr_t) h, (uintptr_t) lip_g, (uintptr_t) &cl, 0, 0, 0)) {
    for (uintptr_t i = 0; i < cn; i++) o[i] = (uint8_t) cmd[i];
    o[cn] = 0;
    ((uint32_t *) cl)[12] = (uint32_t) (2 * (cn + 1));
    cl[7] = o; }
  return (long) ec(bs[26], (uintptr_t) h, 0, 0, 0, 0, 0); }

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
