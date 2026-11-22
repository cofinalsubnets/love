# inle -- love in kernel mode

src/love/ is everything over one interface, moonlibc's `__love_sys`; a platform answers
it from one side. In user mode another kernel answers -- linux and the BSDs by trap,
an SDK for the seats in src/love/user/. In kernel mode we answer: that is inle, the
kernel (`kmain.c`, the syscall table `sys.c`, its drivers) and its machines. The
bare boards below are reduced kernel seats; the boards too small for love, which run
only mooncc's battery, are test/boards/. Every device target is self-contained (own
Makefile, `R := ../../..` back to the repo root); the qemu boot gates live in
test/test.mk and ride `make test_slow`. A seat's own vocabulary comes in through
`defn` -- a board's console -- so src/love/ never learns a device's name.

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

## the playdate

A user-mode seat -- the SDK answers, not us -- so it lives at src/love/user/playdate/.
Its image still bakes here, on mps2's baker (`make -C src/inle/mps2 imgpds`).

## teensy41/

The inle kernel on the Teensy 4.1 (NXP i.MX RT1062, Cortex-M7 @ 600 MHz): an all-mooncc
`-t arm` (Thumb-2) build, XIP boot from the 8 MB FlexSPI NOR behind the config block and
IVT, the shell on the usb cdc and LPUART6, the PSRAM as RAM, the microSD as the disk, the
board's pins through the gpio words, and an image baked under qemu-arm. `make` / `make
flash` (src/tools/halfkay.l). See teensy41/README.md.
