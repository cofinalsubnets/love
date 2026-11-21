// the xiao nrf52840's resident loader, the app in its flash, its ram sram's top 16 KB: an image
// for sram's base comes over its usb serial port as 'L', its length, its bytes and their sum,
// each word little-endian, and runs once it fits and sums right. the image is a whole one,
// vectors first, and the loader goes off the bus and enters through its reset word. 134 baud
// asks for the uf2 bootloader's drive, which takes a new loader
#include <stdint.h>
#include "nrf52840.h"
#include "../../../src/inle/bput.h"

extern uint8_t __data_start__[];

void usb_reboot(void) { usb_off(); reboot_uf2(); }

static void say(char const *s) { bput_s(serial_putc, s); usb_flush(); }

// the port tended while the loader waits: rx_ready takes a 134 baud ask. inside an image, half a
// second's silence ends it: a byte lost costs that try, not the loader
static int quiet;
static uint32_t byte(int timed) {
  for (uint32_t t = clock_ms(); !usb_rx_ready(); usb_poll())
    if (timed && clock_ms() - t > 500u) { quiet = 1; return 0; }
  return (uint32_t) usb_getc(); }

static uint32_t word(void) { uint32_t w = 0; for (uint32_t i = 0; i < 32; i += 8) w |= byte(1) << i; return w; }

// the image's length, 0 when it ran past the room below the loader's ram, summed wrong or stopped
static uint32_t take(void) {
  while (byte(0) != 'L') {}
  quiet = 0;
  uint8_t *const at = (uint8_t *) SRAM_BASE;
  uint32_t const n = word(), room = (uint32_t) (__data_start__ - at);
  uint32_t sum = 0;
  for (uint32_t i = 0; i < n && !quiet; i++) {
    uint32_t const b = byte(1);
    if (i < room) at[i] = (uint8_t) b;
    sum += b; }
  uint32_t const want = word();
  return !quiet && n <= room && want == sum ? n : 0; }

int main(void) {
  led_init(); led_put(LED_BLUE, 1);
  usb_init();
  for (;;) {
    while (!usb_up()) usb_poll(), (void) usb_rx_ready();
    uint32_t const n = take();
    uint32_t const *const v = (uint32_t const *) SRAM_BASE;
    uint32_t const end = SRAM_BASE + n;
    if (!n || v[0] <= SRAM_BASE || v[0] > SRAM_BASE + SRAM_SIZE || !(v[1] & 1u) || v[1] <= SRAM_BASE || v[1] >= end) {
      say("; the image came short, summed wrong, or has no sram entry\n");
      continue; }
    say("; loaded, go\n");
    led_put(LED_BLUE, 0);
    usb_off();
    arm_irq_off();
    ((void (*)(void)) (uintptr_t) v[1])(); } }
