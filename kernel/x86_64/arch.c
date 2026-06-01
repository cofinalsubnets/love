// x86_64 architecture-specific C: CPU-exception handling and the COM1
// serial console. the stubs in x86_64.asm (exc_stub_0 .. exc_stub_31,
// funnelling through exc_common) build the frame below and call
// k_exception; uart_isr funnels IRQ4 into k_uart (see the bottom).
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
// sysv_abi: see kb_int in main.c -- arg0 (k_frame*) comes in via rdi
// from exc_common, which is SysV regardless of the build target.
__attribute__((sysv_abi))
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

// --- COM1 serial console ---------------------------------------------
// a 16550 UART at the legacy COM1 I/O ports, used as a second console
// alongside the framebuffer -- and the only console when no framebuffer
// is present. output (serial_putc) is also the reliable panic channel:
// it touches nothing but I/O ports, so it still works when the heap,
// console buffer, or framebuffer are unusable. input is interrupt-
// driven: serial_init enables the UART receive interrupt (IRQ4),
// uart_isr (x86_64.asm) funnels it here, and k_uart drains every ready
// byte into the same input queue kb_int feeds. bytes pass through
// verbatim -- a serial terminal already sends CR for Enter, DEL for
// Backspace, and ESC-prefixed arrow sequences, all of which the gwen
// line editor decodes directly.
#define COM1 0x3f8

static inline void outb(uint16_t port, uint8_t v) {
  asm volatile ("outb %0, %1" :: "a"(v), "Nd"(port)); }
static inline uint8_t inb(uint16_t port) {
  uint8_t v; asm volatile ("inb %1, %0" : "=a"(v) : "Nd"(port)); return v; }

// called once from kmain, just after archinit (so the IDT is live).
void serial_init(void) {
  outb(COM1 + 1, 0x00);    // interrupts off while configuring
  outb(COM1 + 3, 0x80);    // DLAB: address the divisor latch
  outb(COM1 + 0, 0x01);    // divisor low  = 1  -> 115200 baud
  outb(COM1 + 1, 0x00);    // divisor high = 0
  outb(COM1 + 3, 0x03);    // 8 bits, no parity, 1 stop; DLAB off
  outb(COM1 + 2, 0xc7);    // FIFO: enable, clear, 14-byte threshold
  outb(COM1 + 4, 0x0b);    // DTR, RTS, OUT2 (OUT2 gates the IRQ line)
  outb(COM1 + 1, 0x01); }  // IER: interrupt when receive data arrives

void serial_putc(int c) {
  if (c == '\n') serial_putc('\r');
  // bounded spin on "transmit holding register empty" so an absent or
  // wedged port cannot hang output.
  for (int i = 0; i < 100000 && !(inb(COM1 + 5) & 0x20); i++) {}
  outb(COM1, (uint8_t) c); }

// IRQ4 handler body, reached from uart_isr. one interrupt can cover
// several received bytes, so drain the FIFO completely. kq lives in
// k/main.c -- the same input queue the PS/2 keyboard path enqueues to.
void kq(uint8_t);
void k_uart(void) {
  while (inb(COM1 + 5) & 0x01)        // LSR bit 0: receive data ready
    kq(inb(COM1)); }

// (fault n) backend: deliberately raise a CPU exception, indexed by
// the x86 vector numbers that name it. does not return -- k_exception
// reports and halts.
void k_fault_trigger(intptr_t n) {
  switch (n) {
    case 0:   // #DE: integer divide by zero
      asm volatile ("xorl %%edx,%%edx; movl $1,%%eax; xorl %%ecx,%%ecx;"
                    "divl %%ecx" ::: "eax","ecx","edx");
      break;
    case 3:   // #BP: breakpoint
      asm volatile ("int3");
      break;
    case 13:  // #GP: write through a non-canonical address
      *(volatile int*) 0xdeadbeefdeadbeefULL = 0;
      break;
    case 14:  // #PF: write to a canonical but unmapped address
      *(volatile int*) 0x600000000000ULL = 0;
      break;
    default:  // #UD: invalid opcode
      asm volatile ("ud2");
      break; } }
