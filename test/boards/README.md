# test/boards -- mooncc's battery on silicon

Boards too small to hold love, so their firmware is the toolchain's own check: mooncc,
holo's lays and our linker, run on the chip and read off its console. They share
src/inle/port.mk and bput.h with the love ports there. Gates: test_<board> builds and
verifies the boot image, test_<board>_board runs the battery on a host with the board's cap.
A board lane runs the battery from SRAM wherever the chip allows it, so it never writes flash;
each battery says `; from sram` or `; from flash`, and a RAM image's lane wants the first.
The arm boards share three files: boardld.l links over holo's ldbare32, each board's map a
call to it; armboot.l lays the thumb2 boards' vector table and fault shim from holo IR, each
board's mkboot.l a call to it; crt0.h is the C start they all make, and the thumb1 boards'
vector table.

## nucleo446/

ST Nucleo-F446RE (STM32F446RE, Cortex-M4F @ 180 MHz, 128 KB SRAM -- firmware
only, no love). All C through `mooncc -t thumb2sp`: cold boot, 180 MHz PLL
with bounded ready-waits falling back to HSI, USART1 console on PA9/PA10 (the headers,
D8/D2), and a 28-check on-silicon battery (soft doubles, 64-bit, lm math,
composites). `make flash` via st-flash; gate test_nucleo446 boots the
semihosting face on qemu's netduinoplus2 (STM32F405 -- same UART/RCC map);
test_nucleo446_board runs firm-ram.bin from SRAM over swd on a host with nucleo446-swd.

## nrf52840/

Seeed XIAO nRF52840 Sense (Cortex-M4F @ 64 MHz, 256 KB SRAM -- firmware only, no
love). No swd on the board and a UF2 bootloader that only writes flash, so the flash holds
loader.c once, linked at 0x27000 above the bootloader's softdevice and packed by
src/tools/uf2.l (family 0xADA52840): over its own usb serial port it takes firm-ram.pkt,
nucleo446's battery through `mooncc -t thumb2sp` for SRAM's base, and runs it. usb.c is the
nRF52's usbd under src/inle/usbcdc.h, both images' console; 134 baud on an image resets into the
loader, on the loader brings up the UF2 drive. `make flash` copies loader.uf2 there; gate
test_nrf52840 verifies both images, and test_nrf52840_board runs the battery from SRAM on a host
with nrf52840-loader. qemu has no nRF52 machine.

## microbit/

BBC micro:bit v2 (nRF52833, Cortex-M4F @ 64 MHz, 128 KB SRAM -- firmware only, no
love). The battery (../battery.h, nucleo446's and nrf52840's too) through `mooncc -t
thumb2sp`, linked at flash 0: no bootloader on the target, the DAPLink beside it writes
flash. UART0 console on P0.06/P1.08, the DAPLink's VCP; after the battery the 5x5 matrix shows
lore's savers, slop's drift all green and matrix rain a miss, and a ble beacon (the radio
driven bare, ADV_NONCONN_IND) names the result and the die's temperature, `mb 28/28 23.25C`,
with the same in manufacturer data under the test company 0xFFFF.
`make flash` copies firm.hex onto the DAPLink's drive; test_microbit builds it and
verifies the boot surface, test_microbit_board runs firm-ram.bin from SRAM over the
DAPLink's CMSIS-DAP on a host with microbit-swd and reads the battery.

## rp2040/

Raspberry Pi Pico (RP2040, Cortex-M0+ @ 125 MHz, 264 KB SRAM -- firmware
only, no love: the baked image is ~544 KB, so this is the toolchain on
silicon, like nucleo446). ARMv6-M is the leanest target mooncc has -- no FPU
and no divide instruction, so every `/`, `%`, float and double is a libcall --
and main.c is a 32-check battery over exactly those. The one port with **no
`.S` anywhere**: the vector table and crt0 are C (../crt0.h), and boot2 -- the
256-byte stage the mask ROM CRC-checks before running -- is laid by mkboot2.l
into a named section. Gate test_rp2040 verifies the boot image (boot2 CRC, SP,
thumb-bit reset entry); qemu has no RP2040 machine, so test_mps2_t1 is where
this ISA actually runs. arm-none-eabi-ld still binds it (thumb relocations
are not in src/love/holo/link.l); `make bin` writes the raw flash image, which
src/tools/uf2.l packs as a UF2 (family 0xE48BFF56). The battery reports on UART0 and,
to each host that opens it, on the chip's own usb serial port. test_rp2040_board puts
love-ram.bin (no boot2) in SRAM over swd on a host with rp2040-swd and starts it through the
ROM's warm entry, a watchdog reset that keeps SRAM.


## rp2350/

Raspberry Pi Pico 2 (RP2350 on its Cortex-M33s @ 150 MHz, 520 KB SRAM, the
single-precision FPU): mooncc -t thumb2sp end to end, the nucleo's battery
(../battery.h) on v8-M. No boot2: the ROM sets up flash itself and wants an
image definition in the first 4 KB, which mkboot.l lays behind the vector
table. The console is the chip's own usb, ../rp2040/usb.c built against
rp2350.h; 134 baud on it reboots into the ROM's drive (the reboot waits on
the watchdog, whose tick rp2350.c starts). `make` also builds probe.uf2,
../rp2040/probe.c on this chip. test_rp2350 verifies the boot image;
test_rp2350_board writes firm-ram.uf2, based in SRAM, raw to the ROM's drive on a host
with rp2350-uf2 (the ROM runs it there) and reads the battery off its usb console.

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
it and verifies the image; test_ch32v203_board writes it from this box's USB through
src/tools/wchisp.l and the mask rom's USB ISP, which shows only with BOOT held over a reset.

## trinkey/

Adafruit NeoKey Trinkey M0 (ATSAMD21E18, Cortex-M0+ @ 48 MHz, 32 KB SRAM -- firmware only,
no love). ../battery1.h, the RP2040's thumb1 checks without lm, through `mooncc -t thumb1`,
its USB CDC console ours (usb.c under src/inle/usbcdc.h) on a crystalless 48 MHz: the DFLL
locks to the host's start of frame. SRAM only, in two stages, since the UF2 bootloader holds
SRAM's low 12 KB while it loads: its SAM-BA (test/gate/samba.sh) puts the first stage (crt0,
clocks, the watchdog, USB) high and starts it, and the first host to open the console sends
the second, the battery and rt.o (stage2.pkt), to SRAM's base. The flash keeps whatever
sketch it holds. The image sets the bootloader's double tap as it starts, so 134 baud or a
hang the watchdog catches comes back to the bootloader. test_trinkey builds both stages and
verifies the layout; test_trinkey_board runs them on a host with trinkey-samba.
