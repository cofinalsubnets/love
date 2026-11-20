# test/boards -- mooncc's battery on silicon

Boards too small to hold love, so their firmware is the toolchain's own check: mooncc,
holo's lays and our linker, run on the chip and read off its console. They share
src/inle/port.mk and bput.h with the love ports there. Gates: test_<board> builds and
verifies the boot image, test_<board>_board runs the battery on a host with the board's cap.

## nucleo446/

ST Nucleo-F446RE (STM32F446RE, Cortex-M4F @ 180 MHz, 128 KB SRAM -- firmware
only, no love). All C through `mooncc -t thumb2sp`: cold boot, 180 MHz PLL
with bounded ready-waits falling back to HSI, USART2 console on the ST-LINK
VCP, and a 28-check on-silicon battery (soft doubles, 64-bit, lm math,
composites). `make flash` via st-flash; gate test_nucleo446 boots the
semihosting face on qemu's netduinoplus2 (STM32F405 -- same UART/RCC map).

## nrf52840/

Seeed XIAO nRF52840 Sense (Cortex-M4F @ 64 MHz, 256 KB SRAM -- firmware only, no
love). nucleo446's battery through `mooncc -t thumb2sp`, linked at 0x27000 above the
UF2 bootloader's softdevice, flattened and packed by src/tools/uf2.l (family
0xADA52840). UART0 console on D6/D7 at 115200, TIMER0 microseconds, the RGB LED.
`make flash` copies firm.uf2 onto the bootloader's drive (double tap reset); gate
test_nrf52840 builds it and verifies the boot surface. qemu has no nRF52 machine.

## microbit/

BBC micro:bit v2 (nRF52833, Cortex-M4F @ 64 MHz, 128 KB SRAM -- firmware only, no
love). The battery (../battery.h, nucleo446's and nrf52840's too) through `mooncc -t
thumb2sp`, linked at flash 0: no bootloader on the target, the DAPLink beside it writes
flash. UART0 console on P0.06/P1.08, the DAPLink's VCP; after the battery the 5x5 matrix shows
lore's savers, slop's drift all green and matrix rain a miss, and a ble beacon (the radio
driven bare, ADV_NONCONN_IND) names the result and the die's temperature, `mb 28/28 23.25C`,
with the same in manufacturer data under the test company 0xFFFF.
`make flash` copies firm.hex onto the DAPLink's drive; test_microbit builds it and
verifies the boot surface, test_microbit_board flashes it over the DAPLink's CMSIS-DAP
on a host with microbit-daplink and reads the battery.

## rp2040/

Raspberry Pi Pico (RP2040, Cortex-M0+ @ 125 MHz, 264 KB SRAM -- firmware
only, no love: the baked image is ~544 KB, so this is the toolchain on
silicon, like nucleo446). ARMv6-M is the leanest target mooncc has -- no FPU
and no divide instruction, so every `/`, `%`, float and double is a libcall --
and main.c is a 32-check battery over exactly those. The one port with **no
`.S` anywhere**: the vector table and crt0 are C (rp2040.c), and boot2 -- the
256-byte stage the mask ROM CRC-checks before running -- is laid by mkboot2.l
into a named section. Gate test_rp2040 verifies the boot image (boot2 CRC, SP,
thumb-bit reset entry); qemu has no RP2040 machine, so test_mps2_t1 is where
this ISA actually runs. arm-none-eabi-ld still binds it (thumb relocations
are not in src/love/holo/link.l); `make bin` writes the raw flash image, which
src/tools/uf2.l packs as a UF2 (family 0xE48BFF56).


## esp32c6/

Espressif ESP32-C6 (RV32IMAC @ 160 MHz, 512 KB HP SRAM -- firmware only, no love). The
battery through `mooncc -t rv32`, soft float, compiled and linked by mooncc alone at
0x40800000 with no crt0: src/tools/esprom.l lays the image through the ROM loader on the
chip's own USB-Serial-JTAG and jumps to `_start`, and the battery answers on endpoint 1.
RAM only, the flash never written. test_esp32c6 builds it and verifies where it loads,
test_esp32c6_board runs it on a host with esp32c6-usb and resets the chip into its app.

## ch32v203/

Adafruit QT Py CH32V203 (WCH CH32V203G6, RV32IMAC, 32 KB flash, 10 KB SRAM -- firmware
only, no love). A blink, all `mooncc -t rv32` and linked at flash 0 with no crt0: boot.c's
first words set the stack, and blink.c drives the board's only LED, a WS2812 on PA4, from the
8 MHz HSI with no clock set up. No battery yet: the image has no console. test_ch32v203 builds
it and verifies the image; test_ch32v203_board writes it on a host with ch32v203-isp through
src/tools/wchisp.l and the mask rom's USB ISP, which shows only with BOOT held over a reset.
