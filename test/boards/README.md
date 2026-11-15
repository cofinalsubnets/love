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
flash. UART0 console on P0.06/P1.08, the DAPLink's VCP; the matrix's centre LED blinks.
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

