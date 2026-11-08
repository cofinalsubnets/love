# teensy41/

Bare-metal Teensy 4.1 (NXP i.MX RT1062, Cortex-M7) port of love -- no
Teensyduino core, no Arduino. A freestanding thumbv7em hard-float build of the
love runtime booting XIP from the 8 MB FlexSPI NOR flash, with a REPL on a
hardware serial console. The closest analogue in the tree is `rp2040/`, but the
RT1062 is a far roomier part: a 600 MHz M7 with a double-precision FPU and ~1 MB
of on-chip SRAM, so unlike the RP2040 (dropped upstream for "not enough RAM")
the self-hosting double-bake fits comfortably.

## Build

```
cd src/inle/teensy41 && make            # -> $R/out/teensy41/love.hex
make flash                           # teensy_loader_cli --mcu=TEENSY41 -w -v ...
```

Compiled END TO END by **mooncc** (`love mooncc -t thumb2`, built by the
root Makefile): love.c, the lm math floor, libc, and the port's own C all go
through the repo's compiler, and `mkboot.l` lays the ROM-facing FlexSPI/IVT/
vector blocks + crt0 + the barrier helpers from holo IR -- there is no `.S`
here and nothing assembles them. `tlink.l` binds the image over holo's
`ldbare32` (the XIP flash map is a table in that file, not a linker script) and
`ocopy.l` writes the `.hex` and `.bin` over holo's `copy.l`. No libgcc --
mooncc's thumb2 lanes are self-contained. The
build also verifies the boot image (FCFB tag at 0, IVT at 0x1000, a thumb-bit
entry); the qemu cousin `src/inle/mps2/` proves the same runtime end to end under
emulation (`make test_mps2`). Needs no foreign toolchain at all -- qemu only,
and only to bake the heap image.

## Console

LPUART6 on **pin 0 (RX1) / pin 1 (TX1)** at 115200 8N1, over a 3.3 V USB-serial
adapter -- the analogue of the rp2040 port's UART0 console. The REPL line editor
in `src/love/boot/post.l` drives it exactly as it drives the kernel's. USB CDC (so the
Teensy's own USB shows up as the console, no adapter) is the obvious next step
and a **TODO** -- bare-metal device USB on the RT1062 is a substantial chunk.

## Memory & boot

The i.MX RT1062 boot ROM reads the **FlexSPI Configuration Block** at flash base
(`0x60000000`), the **Image Vector Table** at `0x60001000`, and the **Boot
Data** that follows, then jumps to our startup. `teensy41.c` supplies all three
plus the crt0 (FPU enable, `.data`/`.bss`, VTOR, clocks, console). `.data`, `.bss`
and the C stack live in the 512 KB **OCRAM2** at `0x20200000`, mapped at reset
whatever the FlexRAM split; the love heap is the 16 MB PSRAM on FlexSPI2
(`psram.c`), with an OCRAM pool as the fallback when no PSRAM answers.

## Status: a live shell on hardware (2026-11-07)

The board boots XIP from flash, brings the core to 600 MHz, finds the PSRAM, wakes the image
baked under qemu (`src/inle/mps2`'s baker) and runs the REPL over LPUART6 at 115200:

```
; inle/teensy41
; core 600 MHz
; psram arena up
; image awake
; image hatched -- shell up
> (+ 2 3)
5
```

The console's register traps, against PJRC's `cores/teensy4` as the authority:

- **TX pad drive** -- the pin mux alone never drives the line; `SW_PAD_CTL` = `0x10B0` on
  both pads does.
- **RX daisy** -- `IOMUXC_LPUART6_RX_SELECT_INPUT` is the second IOMUXC block's `0x150`,
  i.e. `+0x550`, not `+0x520`; with the wrong one RX hears nothing while TX works.

The board has no `posix.c`, so `main.c` gives the line editor a `tty` answering `()`: an
unknown size, laid at 80 columns. Open:

- **ITCM/DTCM** -- left empty; hot code to ITCM and the stack to DTCM (the FlexRAM
  `GPR16/GPR17` bank split) is performance, not correctness.
- **GPIO** -- `gpio_*` covers the GPIO2 bank and muxes pin 13 (the LED). A full
  Teensy pin map (all 55 pads -> bank/bit -> ALT5 mux) is a TODO.
- **USB CDC console** -- see above.

See `tools/README.md` for the flashing path.
