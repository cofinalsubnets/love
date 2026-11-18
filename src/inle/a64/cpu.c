// a64, every board's: the generic timer, exception reporting, the fault trigger. the board's
// file (arch.c, or a board's own) has the console, the interrupt controller and the reset
#include <stdint.h>
#include "asmops.h"                    // the privileged instructions, both spellings
#include "k.h"                       // kputc/kputs/kputn (src/inle/kmain.c)

// the EL1 physical timer at ~100 Hz; the reload also deasserts the interrupt
static uint64_t timer_interval;        // CNTFRQ_EL0 / 100

void k_timer_rearm(void) { k_wr_cntp_tval_el0(timer_interval); }

void k_timer_init(void) {
  timer_interval = k_rd_cntfrq_el0() / 100;
  k_timer_rearm();
  k_wr_cntp_ctl_el0(1); }               // enable

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
