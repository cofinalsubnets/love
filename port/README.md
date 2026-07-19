# port -- the freestanding targets of the ai lisp

This tree holds every non-host target. The core freestanding kernel is
`inle/` (the kernel grown into a self-driving agent -- a ship in port):
`kmain.c` + `k.h`, the agent sketch `inle.l`, and the per-arch backends
`inle/x86_64/` and `inle/aarch64/` (arch.c + the boot `.S` + the `.lds`
linker script, built by the root Makefile's `kernel` target). It lives here
alongside the device ports below; `arch/` was merged into `port/` on
2026-06-15 (`arch/<a>/` -> `port/<a>/`), then the kernel was gathered under
`port/inle/<a>/` on 2026-06-17. See `crew/inle.md`.

The device ports were split out of the main repo's arch/ tree on 2026-06-09
(main repo: the `l` darcs repo; git provenance hashes below refer to its
git history). Each port was a subdirectory of arch/ in the main tree and
builds against it (R := ../.. + common.mk); wiring them to build from this
repo instead -- point R (or an L variable) at an l checkout -- is TODO.

Pulled back into the main (now `love`) tree under port/ on 2026-06-14 from
the love-ports darcs repo (working files only, no _darcs history). The
playdate/rp2040 entries below still carry their pre-rename notes; the new
teensy41/ port is written against the current ai.h contract.

## archlinux/

Arch Linux package (`PKGBUILD`, `love-git`): a `-git` package that clones
the GitHub repo, builds the host CLI (`make host`), runs `make test` as the
check, and installs via the main Makefile's `install` target (binary, manpage,
the `love/*.l` egg sources, `liblove.{a,so}`, `ai.h`, and the vim files)
under `usr/` into `$pkgdir`. Not a device port -- the host package, kept here
so every downstream packaging recipe lives under port/.

## playdate/

Panic Playdate shell. Own Makefile: needs PLAYDATE_SDK_PATH and
arm-none-eabi-gcc; `make` builds the device + simulator pdx into the main
repo's out/playdate. Imported live from l git 0b5aee2 (current,
post-rename). Source/pdex.* are build products (see .boring).

## rp2040/

Bare-metal RP2040 (Cortex-M0+; no Pico SDK, no CMake): a freestanding
thumbv6m build linked at flash XIP behind a 256-byte checksummed boot2,
packed into a flashable .uf2. Dropped from the main tree in git dca7134
("not enough RAM on the part"); imported here from its last state at git
5f63da8, which is PRE-RENAME (gwen-era: .g sources, gl/gl0, gwen.c/h) --
it needs the gwen->l rename applied before it can build against current
l. Makefile.upstream is the rp2040 build section verbatim from the old
top-level Makefile. boot2.bin is a vendored source artifact (the stage-2
payload pad_checksum.g stamps a CRC onto it), tracked despite the .bin
extension. tools/ holds the rp2040-only flashing tools (elf2uf2,
pad_checksum) as l programs plus their frozen-Python references.

## teensy41/

Bare-metal Teensy 4.1 (NXP i.MX RT1062, Cortex-M7 @ 600 MHz, double-precision
FPU, ~1 MB on-chip SRAM): a freestanding thumbv7em hard-float build booting XIP
from the 8 MB FlexSPI NOR behind the FlexSPI config block + IVT the boot ROM
walks, packed into a flashable .hex (teensy_loader_cli). The roomy analogue of
rp2040/ -- where the M0+ was dropped for "not enough RAM", the RT1062 fits the
self-hosting double-bake easily. Console is LPUART6 on pin 0/1 at 115200 8N1
(USB CDC is a TODO). Self-contained Makefile (`make`/`make flash`), written
against the current ai.h names -- a structurally complete scaffold, not yet
silicon-verified; the FlexSPI/IVT/LUT bytes and register offsets (lifted from
the i.MX RT1060 RM + PJRC cores/teensy4) are the verify-first surface. See
teensy41/README.md for the full TODO list.
