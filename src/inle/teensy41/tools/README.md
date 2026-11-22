# teensy41/tools

The Teensy 4.1 flashing path needs no bespoke tooling: the i.MX RT1062 boots a plain
Intel HEX, and the PJRC bootloader chip on the board accepts it directly.

## Producing the image

The `Makefile` runs `ocopy.l -O ihex` -- `src/love/holo/copy.l`, our own objcopy --
on the linked ELF to make `$R/out/teensy41/love.hex`, and `-O binary` for `love.bin`. The flashable layout
(FlexSPI config block at `0x60000000`, IVT at `0x60001000`, boot data, then
code) is established by `../tlink.l`'s memory map and the blocks `../mkboot.l`
lays, so the flatten is the whole "packer".

## Flashing

Tap the white button on the Teensy 4.1 to enter the bootloader, or, with this
image running, set its USB port to 134 baud (the loaders' ask, as Teensyduino's), then
from the tree's root:

```
stty -F /dev/serial/by-id/usb-love_inle_teensy41_1-if00 134   # no button
out/love src/tools/halfkay.l write out/teensy41/love.bin      # or: make flash
```

`src/tools/halfkay.l` is our own HalfKay programmer (doc/misc/halfkay.md): it writes the
`.bin` by flash offset over the bootloader's hid interface and starts the program. The
Teensy Loader GUI that ships with Teensyduino takes the `.hex` of the same image.

## Recovery

If a bad image bricks the console, the bootloader chip is independent of the
i.MX RT1062 -- the button always re-enters it, so a re-flash always recovers the
board. (There is no equivalent to soldering or UF2-mass-storage gymnastics.)
