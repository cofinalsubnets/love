// the teensy 4.1's resident loader, the image in its flash: an image for the psram's base comes
// over its usb serial port as 'L', its length, its bytes and their sum, each word little-endian,
// and runs once it fits and sums right. the image is a whole one, vectors first (tlink.l -ram),
// entered through its reset word with the clocks, the caches and the psram up, the usb off the
// bus and interrupts masked. 134 baud asks for HalfKay, as on any image; the program button
// reaches it whatever the flash holds
#include <stdint.h>
#include "teensy41.h"
#include "psram.h"
#include "../bput.h"

uintptr_t te_ms(void);
static void putc2(int c) { uart_putc(c), usb_putc(c); }
static void say(char const *s) { bput_s(putc2, s); usb_flush(); }

// inside an image half a second's silence ends it: a byte lost costs that try, not the loader
static int quiet;
static uint32_t byte(int timed) {
  for (uint32_t t = te_ms(); !usb_rx_ready(); )
    if (timed && te_ms() - t > 500u) { quiet = 1; return 0; }
  return (uint32_t) usb_getc(); }

static uint32_t word(void) { uint32_t w = 0; for (uint32_t i = 0; i < 32; i += 8) w |= byte(1) << i; return w; }

// the image's length, 0 when it ran past the psram, summed wrong or stopped
static uint32_t take(uint32_t room) {
  while (byte(0) != 'L') {}
  quiet = 0;
  uint8_t *const at = (uint8_t *) PSRAM_BASE;
  uint32_t const n = word();
  uint32_t sum = 0;
  for (uint32_t i = 0; i < n && !quiet; i++) {
    uint32_t const b = byte(1);
    if (i < room) at[i] = (uint8_t) b;
    sum += b; }
  uint32_t const want = word();
  return !quiet && n <= room && want == sum ? n : 0; }

#define SCB_ICIALLU 0xE000EF50u
#define SCB_DCCMVAC 0xE000EF68u
#define MPU_CTRL    0xE000ED94u
#define OCRAM2      0x20200000u
#define OCRAM2_TOP  0x20280000u

void te_main(void) {
  usb_init();
  uint32_t const mb = psram_init();
  for (;;) {
    while (!usb_up()) (void) usb_rx_ready();
    if (!mb) { say("; love loader: no psram answers\n"); while (usb_up()) (void) usb_rx_ready(); continue; }
    uint32_t const n = take(mb << 20);
    uint32_t const *const v = (uint32_t const *) PSRAM_BASE;
    uint32_t const end = PSRAM_BASE + n;
    if (!n || v[0] <= OCRAM2 || v[0] > OCRAM2_TOP || !(v[1] & 1u) || v[1] <= PSRAM_BASE || v[1] >= end) {
      say("; the image came short, summed wrong, or has no psram entry\n");
      continue; }
    say("; loaded, go\n");
    usb_off();
    arm_irq_off();
    // the image's bytes out of the data cache to the psram, and no stale line for a fetch; the
    // mpu's one region was the usb's window, and without it the default map runs the psram
    arm_dsb();
    for (uint32_t a = PSRAM_BASE; a < end; a += 32) REG(SCB_DCCMVAC) = a;
    arm_dsb();
    REG(MPU_CTRL) = 0;
    REG(SCB_ICIALLU) = 0;
    arm_dsb_isb();
    arm_enter(PSRAM_BASE); } }
