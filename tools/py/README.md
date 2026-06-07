# tools/py — the retired Python build tools

These three scripts used to live in `tools/` and were the build's real
codegen/lint helpers. They have since been rewritten in gwen lisp (the `.g`
files one directory up), which is the whole point of the project: the toolchain
that builds gwen should itself be written in gwen, so the only hard build-time
dependency is a C compiler (plus a disassembler for the TCO check).

| Python (here)      | gwen replacement (`tools/`) | what it does |
|--------------------|-----------------------------|--------------|
| `gen_data.py`   | `gen_data.g`             | reflects the data-sentinel stride out of a compiled `data.o` into a generated `data.h` so `g_typ()` is one shift |
| `elf2efi.py`       | `elf2efi.g`                 | wraps a static ELF into a PE32+ `.efi` (riscv64/loongarch64 EFI builds, which can't use lld's COFF backend) |
| `vmret.py`         | `vmret.g`                   | disassembles an ELF and flags `g_vm_*` handlers that emit a `ret` instead of tail-jumping |
| `pad_checksum.py`  | `pad_checksum.g`            | stamps the RP2040 boot2 CRC (CRC-32/MPEG-2 over 252 bytes) and emits the checksummed `.boot2` `.byte` array |
| `elf2uf2.py`       | `elf2uf2.g`                 | packs a linked RP2040 ELF32 into a flashable `.uf2` (256-byte payload blocks, family `0xe48bff56`) |

## Why keep them?

They are the **golden reference** for the rewrites. Each gwen tool is required
to produce byte-for-byte identical output to its Python ancestor, and the
`tools/Makefile` gates (`test_gen_vt`, `test_elf2efi`, `test_vmret`, all run by
`make test_tools` from the root) enforce exactly that by diffing the two over
every build artifact present. Keeping the Python around means a regression in a
`.g` tool — or a behavioural drift introduced by a future change to the gwen
compiler/runtime — is caught immediately against an independent implementation.

They are no longer invoked by any build: `gen_data.g` generates every
frontend's `data.h` (host, kernel, playdate, rp2040), `elf2efi.g` stamps the
kernel EFI images, and `make vmret` runs `vmret.g`. The scripts here are frozen
— edit the `.g` tools, not these — and exist solely so the gates have something
trustworthy to check against. If a gwen tool ever needs to intentionally change
its output, update the corresponding Python reference in the same commit so the
gate stays meaningful.
