# inle -- love in kernel mode

src/love/ is everything over one interface, moonlibc's `__ai_sys`; a platform answers
it from one side. In user mode another kernel answers -- linux and the BSDs by trap,
an SDK for the seats in src/love/user/. In kernel mode we answer: that is inle, the
kernel (`kmain.c`, the syscall table `sys.c`, its drivers) and its machines. The
bare boards below are reduced kernel seats; nucleo446 and rp2040 carry no love at
all and are the toolchain on silicon. Every device target is self-contained (own
Makefile, `R := ../..` back to the repo root); the qemu boot gates live in
test/test.mk and ride `make test_slow`. A seat's own vocabulary comes in through
`ai_defn` -- a board's console -- so src/love/ never learns a device's name.

## the kernel

The bare-metal build of love, a tty and a repl on raw hardware: `kmain.c` +
`k.h` with per-arch backends `x64/`, `a64/` and `rv64/` (arch.c + boot `.S` +
`.lds`), built by the root Makefile's `kernel` target. Gates: test_disk,
test_uefi (OVMF), test_kernel_a64, test_kernel_rv64, test_uefi_a64.

## mps2/

The qemu Cortex-M reference machine (ARM MPS2 boards): love compiled WHOLE by
mooncc boots and bakes its egg on-device. Three faces: thumb2 on the M7
(test_mps2), thumb1 -- the ARMv6-M/RP2040 ISA (test_mps2_t1), and the
build-time image bake that a different binary wakes (test_mps2_wake). No
silicon; this is where the thumb backends verify.

## nucleo446/

ST Nucleo-F446RE (STM32F446RE, Cortex-M4F @ 180 MHz, 128 KB SRAM -- firmware
only, no love). All C through `mooncc -t thumb2sp`: cold boot, 180 MHz PLL
with bounded ready-waits falling back to HSI, USART2 console on the ST-LINK
VCP, and a 28-check on-silicon battery (soft doubles, 64-bit, am math,
composites). `make flash` via st-flash; gate test_nucleo446 boots the
semihosting face on qemu's netduinoplus2 (STM32F405 -- same UART/RCC map).

## the playdate

A user-mode seat -- the SDK answers, not us -- so it lives at src/love/user/playdate/.
Its image still bakes here, on mps2's baker (`make -C src/inle/mps2 imgpd`).

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
are not in src/love/holo/link.l), and there is no .uf2 packer -- `make bin` writes
the raw flash image, and a UF2 wants one written.

## teensy41/

Bare-metal Teensy 4.1 (NXP i.MX RT1062, Cortex-M7 @ 600 MHz, ~1 MB SRAM):
love LIVE ON SILICON -- all-mooncc `-t thumb2` build, XIP boot from the 8 MB
FlexSPI NOR behind the config block + IVT, LPUART6 console on pins 0/1 at
115200, image boot (a build-time qemu bake wakes in ~1 s where the on-device
egg bake took ~55 s). `make` / `make flash` (teensy_loader_cli). See
teensy41/README.md.
