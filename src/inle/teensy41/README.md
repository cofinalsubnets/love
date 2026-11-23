# teensy41/

The inle kernel on the Teensy 4.1 (NXP i.MX RT1062, Cortex-M7), with no Teensyduino
core and no Arduino: `kmain` over this board's drivers, booting XIP from the 8 MB FlexSPI
NOR flash, its heap the 16 MB PSRAM and its disk the microSD slot, with love's shell on
the USB and serial consoles.

## Build

```
cd src/inle/teensy41 && make            # -> $R/out/teensy41/love.bin, love.hex
make flash                           # love src/tools/halfkay.l write out/teensy41/love.bin
```

Compiled end to end by **mooncc**: `kern.c` and the drivers with `-t arm` (Thumb-2,
the linux EABI), linked with the root's `xa=arm` love objects, so the image an arm love
bakes under qemu-arm is the one the board wakes. `mkboot.l` lays the ROM-facing
FlexSPI/IVT/vector blocks, crt0 and the barrier helpers from holo IR -- there is no `.S`.
`tlink.l` links over holo's `ldbare32` (the XIP flash map is a table in that file, not a
linker script) and `ocopy.l` writes the `.hex` and `.bin` over holo's `copy.l`. The build
checks the boot image (FCFB tag at 0, IVT at 0x1000, a thumb-bit entry). `make test_teensy41`
builds it and `make test_teensy41_board` flashes it on a host with a board. The only
outside program is qemu-arm, to bake the image.

## From the PSRAM

`make loader` builds `loader.c`, a 14 KB flash image that takes a kernel over its USB serial
port into the PSRAM and enters it, and `make ram` that kernel as `love-ram.pkt`: the same
objects under `tlink.l -ram`, vectors first at `0x70000000`, `.data` still copied to OCRAM2.
With the loader in flash (`make flashloader`, one write) a new kernel is a `cat` to the
port, and the flash is not written again. The loader is `love loader` on the bus, the kernel
`inle teensy41`; 134 baud on either asks for HalfKay. The kernel finds itself in the PSRAM by
its vectors' address: it leaves the clocks, caches and PSRAM as the loader set them, and its
heap starts above its own bytes. It says `; from sram` or `; from flash` at boot.

The PSRAM kernel wakes a smaller image than the flash one: the lush cat (`out/.lush-cat.l`,
kore's head with no door), so lush, its builtins and `love`, and no `ls` or `cat`. Its own
bytes come out of the heap's 16 MB, and over all of kore a major collection has no to-space.
The flash kernel carries the whole kore cat.

Two lanes put a kernel on the board. `test_teensy41_board` writes the flash kernel through
HalfKay, and so writes over the loader: `make flashloader` puts it back. `test_teensy41_ram_board`
sends `love-ram.pkt` to the loader and writes nothing; it fails, and says so, when the flash
holds no loader.

## Console

Two at once, the same shell on both. The Teensy's own USB is a CDC-ACM port (`usb.c`,
USB1's ChipIdea controller held at full speed, under `../usbcdc.h`'s class half), seen
as `usb-love_inle_teensy41_1-if00`; output goes only while a host holds DTR. And
LPUART6 on **pin 0 (RX1) / pin 1 (TX1)** at 115200 8N1, over a 3.3 V USB-serial
adapter, which also carries the boot banner and fault reports.

## Memory & boot

The i.MX RT1062 boot ROM reads the **FlexSPI Configuration Block** at flash base
(`0x60000000`), the **Image Vector Table** at `0x60001000`, and the **Boot
Data** that follows, then jumps to our startup. `teensy41.c` supplies all three
plus the crt0 (FPU enable, `.data`/`.bss`, VTOR, clocks, console). `.data`, `.bss`
and the C stack live in the 512 KB **OCRAM2** at `0x20200000`, mapped at reset
whatever the FlexRAM split; the love heap is the 16 MB PSRAM on FlexSPI2
(`psram.c`), with an OCRAM pool as the fallback when no PSRAM answers.

## GPIO

The board's own pin numbers, 0 to 54, through kmain's four words: `(gpio_init 13)`,
`(gpio_dir 13 1)`, `(gpio_put 13 1)`, `(gpio_get 13)`. `teensy41.c` maps each pin to its
bank, bit and pad; pins 0 and 1 (the console), 42-47 (the SD slot) and 48-54 (the PSRAM)
are held, and a held or missing pin answers `()`. Pin 13 is the LED.

## Traps

The console's register traps, against PJRC's `cores/teensy4` as the authority:

- **TX pad drive** -- the pin mux alone never drives the line; `SW_PAD_CTL` = `0x10B0` on
  both pads does.
- **RX daisy** -- `IOMUXC_LPUART6_RX_SELECT_INPUT` is the second IOMUXC block's `0x150`,
  i.e. `+0x550`, not `+0x520`; with the wrong one RX hears nothing while TX works.

- **GPIO read-back** -- a pad muxed to GPIO reads its PSR back only with SION (`0x10`) in
  the mux; without it an output reads 0.

Open: **ITCM/DTCM** are left empty; hot code to ITCM and the stack to DTCM (the FlexRAM
`GPR16/GPR17` bank split) is performance, not correctness.

See `tools/README.md` for the flashing path.
