// test/gate/rvboot.c -- the riscv bring-up on a real hart: mkboot.l's sv39 lane and
// src/riscv64_dtb.c's door, entered the way the kernel will be entered (qemu -M virt,
// OpenSBI, S-mode at the ELF's entry with a1 holding the tree) and asked whether the
// world it built is the world it promised.
//
// This is not the kernel -- kmain here is the gate, so nothing but the boot stub, the
// device-tree door and this file is in the link. What it proves is exactly the pair of
// rungs underneath it: the map comes on, the hhdm window reaches physical memory, the
// tree qemu built is read through it, and C is reached with a stack it can call on.
//
// exit 42 = every law held; 1 = one did not (the UART says which); 98 would be a trap,
// which nothing here can report yet -- stvec is rung 3's, and until then a fault is a
// hang the gate's timeout catches.
#define k_hhdm    0xffffffc000000000ull
#define k_map_top 0x100000000ull
#include "k.h"

// the two symbols the door borrows: kmain owns kboot, and the projection patches
// k_image_top. Here the gate owns both -- 0x80400000 is comfortably past this small
// image, and the door must hand the heap nothing below it.
struct k_boot kboot;
uintptr_t const k_image_top = 0x80400000;

// the metal, all of it under the first gigabyte and so inside the identity window:
// virt's ns16550 and the sifive test finisher, whose word carries our exit code out.
#define UART    ((volatile uint8_t *) 0x10000000u)
#define TESTDEV (*(volatile uint32_t *) 0x100000u)
static void putc_(char c) { while (!(UART[5] & 0x20)) ; UART[0] = (uint8_t) c; }
static void puts_(char const *s) { while (*s) putc_(*s++); }
static void hex_(uint64_t v) {
  int i; puts_("0x");
  for (i = 60; i >= 0; i -= 4) putc_("0123456789abcdef"[(v >> i) & 15]); }
static void exit_(unsigned code) {
  TESTDEV = (code << 16) | 0x3333u; for (;;) ; }

static int bad;
static void law(char const *what, uint64_t want, uint64_t got) {
  if (want == got) { puts_("  ok   "); puts_(what); putc_('\n'); return; }
  puts_("  FAIL "); puts_(what); puts_(" want "); hex_(want);
  puts_(" got "); hex_(got); putc_('\n'); bad = 1; }

// the privileged reads, through the same asmops seam the kernel will use
static uint64_t rd_satp(void) {
  uint64_t v; asm volatile ("csrr %0, satp" : "=r"(v)); return v; }
static uint64_t rd_sstatus(void) {
  uint64_t v; asm volatile ("csrr %0, sstatus" : "=r"(v)); return v; }

static uint64_t witness;              // a word to find again through the other window

void kmain(void) {
  uint64_t ram_end = 0;
  uint32_t i;
  puts_("\nrvboot: the map, the window and the tree\n");

  // 1. the map is on and it is sv39: mode 8 in satp's top nibble.
  law("satp.mode", 8, rd_satp() >> 60);

  // 2. FP is open before any C ran -- a reset leaves FS Off and the first fld traps.
  // ⚠ this law cannot fail on THIS firmware: OpenSBI hands over with FS already
  // Dirty, so it holds with the stub's own set removed. It is here for the machine
  // that does not (the ox64's chain is its own), and it says what C is owed.
  law("sstatus.FS", 3, (rd_sstatus() >> 13) & 3);

  // 3. the door recorded the window the stub actually installed.
  law("kboot.hhdm", k_hhdm, kboot.hhdm);

  // 4. THE WINDOW ITSELF. the kernel runs identity, so a variable's address IS its
  // physical address; the same word read through the hhdm must be the same word.
  // this is the one law a wrong page table cannot fake.
  witness = 0x5eed1eaf5eed1eafull;
  law("hhdm.reads", witness, *(volatile uint64_t *) (k_hhdm + (uintptr_t) &witness));
  *(volatile uint64_t *) (k_hhdm + (uintptr_t) &witness) = 0xf00dcafef00dcafeull;
  law("hhdm.writes", 0xf00dcafef00dcafeull, witness);

  // 5. the tree qemu built, read by src/dtb.h through that window: one bank, starting
  // where the image ends rather than where RAM does (the firmware is down there and
  // still running), ending at the top of what -m gave us.
  law("ram_n", 1, kboot.ram_n);
  for (i = 0; i < kboot.ram_n; i++) ram_end = kboot.ram[i].base + kboot.ram[i].len;
  law("ram.base", k_image_top, kboot.ram[0].base);
  law("ram.end",  0x88000000, ram_end);

  // 6. ..and the command line, which is how the kernel is told what to run.
  law("cmdline", 0, (uint64_t) (kboot.cmdline[0] == 'r' && kboot.cmdline[1] == 'v'
                                && kboot.cmdline[2] == '-' && kboot.cmdline[3] == 'g'
                                && kboot.cmdline[4] == 'a' && kboot.cmdline[5] == 't'
                                && kboot.cmdline[6] == 'e' && kboot.cmdline[7] == 0
                                ? 0 : 1));

  puts_(bad ? "rvboot: a law failed\n" : "rvboot: all laws hold\n");
  exit_(bad ? 1 : 42); }
