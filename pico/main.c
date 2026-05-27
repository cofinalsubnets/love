/* 
    This code originates from the Getting started with Raspberry Pi Pico document
    https://datasheets.raspberrypi.org/pico/getting-started-with-pico.pdf
    CC BY-ND Raspberry Pi (Trading) Ltd
*/

#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "pico/binary_info.h"
#include "g.h"

const uint LED_PIN = 25;

uintptr_t g_clock(void) {
  return to_ms_since_boot(get_absolute_time()); }
int gputc(struct g*f, int c) { return putc(c, stdout); }

int main() {
    bi_decl(bi_program_description("PROJECT DESCRIPTION"));
    
    stdio_init_all();

    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);

    struct g *f = g_ini();

    while(1) {
        gpio_put(LED_PIN, 0);
        sleep_ms(250);
        gpio_put(LED_PIN, 1);
        f = g_evals_(f, "(puts \"Jello World\") (putc 10)");
//        puts("Hello World\n");
        sleep_ms(1000);
    }
}
