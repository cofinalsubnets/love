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
cd port/teensy41 && make            # -> $R/out/teensy41/ai.hex
make flash                           # teensy_loader_cli --mcu=TEENSY41 -w -v ...
```

Standalone (`R := ../..`): it touches no file in the main tree, pulls shared
vars from `common.mk`, and delegates the host interpreter + the `out/lib/*.h`
lcat headers back to the root Makefile. Needs a thumbv7em-capable `clang`
(+ `llvm-objcopy`), or set `KCC=arm-none-eabi-gcc` with `OBJCOPY=arm-none-eabi-objcopy`.

## Console

LPUART6 on **pin 0 (RX1) / pin 1 (TX1)** at 115200 8N1, over a 3.3 V USB-serial
adapter -- the analogue of the rp2040 port's UART0 console. The REPL line editor
in `ai/repl.l` drives it exactly as it drives the kernel's. USB CDC (so the
Teensy's own USB shows up as the console, no adapter) is the obvious next step
and a **TODO** -- bare-metal device USB on the RT1062 is a substantial chunk.

## Memory & boot

The i.MX RT1062 boot ROM reads the **FlexSPI Configuration Block** at flash base
(`0x60000000`), the **Image Vector Table** at `0x60001000`, and the **Boot
Data** that follows, then jumps to our startup. `teensy41.c` supplies all three
plus the crt0 (FPU enable, `.data`/`.bss`, VTOR, clocks, console). We run all
RAM -- `.data`, `.bss`, the love heap pool, and the C stack -- out of the
dedicated 512 KB **OCRAM2** at `0x20200000`, which is mapped at reset
independent of the FlexRAM split, so the scaffold needs no FlexRAM
reconfiguration to have working memory.

## Status: scaffold, not silicon-verified

Structurally complete and written against the current `ai.h` contract
(`lvm_port_io`, the `g_*` frontend hooks, `.l` lcat headers), but **not yet run
on hardware**. The register offsets, the FlexSPI config block, the IVT, and the
QSPI read LUT are lifted from the i.MX RT1060 Reference Manual (Serial NOR boot)
and cross-checked against PJRC's `cores/teensy4`; treat them as the verify-first
surface. Known TODOs:

- **FlexSPI config block / read LUT** -- verify the exact bytes against the
  on-board QSPI part (Teensy 4.1 ships a Winbond/ISSI 8 MB NOR) before trusting
  a first flash.
- **Clock tree** -- `clocks_init` only brings up the LPUART and GPT1 roots off
  the 24 MHz crystal and leaves the M7 on the ROM's clock; raising the core to
  600 MHz via ARM_PLL is a TODO (it changes neither the console nor the
  GPT1-microsecond timebase math).
- **ITCM/DTCM** -- left empty; moving hot code to ITCM and the stack to DTCM
  (via the FlexRAM `GPR16/GPR17` bank split) is a performance optimisation, not
  a correctness need.
- **GPIO** -- `gpio_*` covers the GPIO2 bank and muxes pin 13 (the LED). A full
  Teensy pin map (all 55 pads -> bank/bit -> ALT5 mux) is a TODO.
- **USB CDC console** -- see above.

See `tools/README.md` for the flashing path.
