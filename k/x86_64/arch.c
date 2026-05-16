// x86_64 CPU-exception handling. the stubs in arch.asm (exc_stub_0 ..
// exc_stub_31, funnelling through exc_common) build the frame below and
// call k_exception. this is the only architecture-specific C so far.
#include <stdint.h>
void k_halt(void);

// the frame exc_common hands us, lowest address (rsp) first:
//   the push15 saved registers, then the stub's (vector, error code),
//   then the iret frame the CPU pushed on exception entry.
struct k_frame {
  uint64_t r15, r14, r13, r12, r11, r10, r9, r8,
           rdi, rsi, rdx, rcx, rbx, rax, rbp,
           vector, error, rip, cs, rflags, rsp, ss; };

// console output, from g.c / main.c. gputc appends a char and gputn a
// number (in the given base) to the console ring buffer (kcb); fbdraw
// renders that buffer to the framebuffer.
struct g;
struct cb;
extern int gputc(struct g*, int),
           gputs(struct g*, char const*),
           gputn(struct g*, intptr_t, uint8_t);
extern void fbdraw(void);
extern struct cb *kcb;

static char const *const exc_name[32] = {
  [0]  = "#DE", [1]  = "#DB", [2]  = "NMI", [3]  = "#BP", [4]  = "#OF",
  [5]  = "#BR", [6]  = "#UD", [7]  = "#NM", [8]  = "#DF", [10] = "#TS",
  [11] = "#NP", [12] = "#SS", [13] = "#GP", [14] = "#PF", [16] = "#MF",
  [17] = "#AC", [18] = "#MC", [19] = "#XM", [20] = "#VE", [21] = "#CP", };


// every CPU exception (vectors 0..31) arrives here via exc_common.
// fr->rip is the faulting instruction: a __builtin_trap() faults with
// fr->vector == 6 and fr->rip at its ud2, so it maps straight back to
// whichever guard fired. faults are not resumed -- returning from
// #UD/#GP/#PF would just re-execute the instruction and fault again.
void k_exception(struct k_frame *fr) {
  asm volatile ("cli");                // no interrupts while reporting
  static int nested;
  if (nested) k_halt();                // faulted while reporting -- stop
  nested = 1;

  if (kcb) {                           // console up? report to the screen
    char const *name = fr->vector < 32 ? exc_name[fr->vector] : 0;
    gputs(0, "\n*** CPU exception ");
    gputn(0, fr->vector, 10);
    gputs(0, " ("), gputs(0, name ? name : "?"), gputs(0, ") rip=");
    gputn(0, fr->rip, 16);
    gputs(0, " err=");
    gputn(0, fr->error, 16);
    if (fr->vector == 14) {            // #PF: also the faulting address
      uint64_t cr2;
      asm volatile ("mov %%cr2, %0" : "=r"(cr2));
      gputs(0, " cr2="), gputn(0, cr2, 16); }
    gputc(0, '\n');
    fbdraw(); }

  k_halt();
}

/* COM1 serial logging -- parked for now. this is the reliable panic
   channel: it touches only I/O ports, so it still works when the heap,
   console, or framebuffer are corrupt -- exactly the cases where the
   kcb path above cannot be trusted. to bring it back: uncomment, call
   serial_init() once at the top of k_exception, and emit the report to
   serial *before* the kcb block, so a fault during kcb output cannot
   lose the serial copy.

#define COM1 0x3f8

static inline void outb(uint16_t port, uint8_t v) {
  asm volatile ("outb %0, %1" :: "a"(v), "Nd"(port)); }
static inline uint8_t inb(uint16_t port) {
  uint8_t v; asm volatile ("inb %1, %0" : "=a"(v) : "Nd"(port)); return v; }

static void serial_init(void) {
  outb(COM1 + 1, 0x00);    // interrupts off
  outb(COM1 + 3, 0x80);    // DLAB: address the divisor latch
  outb(COM1 + 0, 0x01);    // divisor = 1  -> 115200 baud
  outb(COM1 + 1, 0x00);
  outb(COM1 + 3, 0x03);    // 8 bits, no parity, 1 stop; DLAB off
  outb(COM1 + 2, 0xc7);    // FIFO: enable, clear, 14-byte threshold
  outb(COM1 + 4, 0x0b); }  // DTR, RTS, OUT2

static void serial_putc(int c) {
  if (c == '\n') serial_putc('\r');
  // bounded spin on "transmit holding register empty" so an absent or
  // wedged port cannot hang the panic.
  for (int i = 0; i < 100000 && !(inb(COM1 + 5) & 0x20); i++) {}
  outb(COM1, (uint8_t) c); }
*/
