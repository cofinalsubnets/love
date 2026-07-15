# moon-userland — growing mooncc by building the LFS packages

The idea: build the conventional GNU/Linux userland (the Linux-From-Scratch package
set — bzip2, gzip, sed, grep, make, bash, coreutils, …) **with mooncc**, in LFS build
order, as a **conventional overlay over the ai base system**. Two payoffs at once:

- each real package drives mooncc through real-world C it has never seen, growing the
  compiler the same way ai.c grew it (doc/moon.md's "gen choke list" — refuse a
  construct, add it, move on), and
- the result is a familiar POSIX userland whose *entire toolchain underneath* is
  ai/mooncc/holo — the "conventional overlay, ai floor" the arc is aiming at.

This is the RIGHT ladder. The kernel (doc/moon.md:16, "the one imported artifact") is a
cliff — inline asm + a register allocator to bind its operands, `__attribute__` honesty,
bitfields, computed goto (see the gap table at the bottom). The LFS *userland* packages
are ordinary C: the first one is a day of header-shim + declaration work away, not a
compiler rewrite. So climb the userland ladder first; the kernel is its far end.

The base is [[ai-distro]] rung 4 — the gcc-free, glibc-free static `ai` (out/host/ai-raw,
`make test_raw`) — booting as pid 1 on the Linux kernel via `init/boot.l` + `mk/distro.mk`
(`make distro-run`). The overlay is these packages, laid beside kore under /usr.

## first rung, MEASURED: bzip2 1.0.8

bzip2 is the ideal first package — it's *in* the LFS book, ~7.3k lines of plain C89, and
has **no `./configure`** (a plain Makefile), so it isolates mooncc's C coverage from the
shell/autotools bootstrap. Probed 2026-07-15 (`mooncc -c` per file):

```
  ALL 8 FILES COMPILE (rungs A + B + C + D landed): crctable randtable huffman
  blocksort compress decompress bzlib bzip2  ->  a real, working `bzip2` binary
```

**A complete, working `bzip2` built entirely by mooncc.** Compress/decompress round-trips
byte-perfect in BOTH file mode and `-c` stdout mode, the compressed bytes are **byte-identical
to a gcc -O0 build**, and it interoperates BOTH ways with the system tool (system `bunzip2`
decodes mooncc's output; mooncc decodes system `bzip2`'s). Linked with `gcc -no-pie` (the ai.c
ladder's convention). So mooncc's codegen for the whole program — incl. decompress.c's
nested-case coroutine (rung A) — is verified against gcc AND the real bzip2 format.

**5 of 8 library files compile** with the landed header shims. The rungs:

1. **missing `<ctype.h>`** — LANDED (`crew/moon/include/ctype.h`). mooncc ships headers
   "sized to ai.c/host" (doc/moon.md); ctype was not one, and ai.c never needs it. bzip2's
   `#include <ctype.h>` then **fell through to glibc's `/usr/include/ctype.h`**
   (GNU-extension-laden) and mooncc choked there. The 15-decl shim took crctable.c from
   refuse → a real 1947-byte `.o`.
   *Methodology note (still open):* the silent fall-through to /usr/include is itself a gap
   — an LFS build must run mooncc with a complete sysroot (mooncc has no `-nostdinc` yet),
   OR mooncc should REFUSE a header it doesn't own rather than defer to glibc's.

2. **incomplete stdio decls** — LANDED (`ungetc`/`getc`/`getchar` added to
   `crew/moon/include/stdio.h`). Proven: `bzip2.c` advanced past `myfeof` (which calls
   `ungetc`) to the next function, `compressStream` — the shim ladder moves forward one
   decl at a time, as designed.

The remaining rungs:

- **rung A — nested `case` labels — LANDED 2026-07-15** (`crew/moon/{parse,gen}.l`).
  mooncc's parser used to accept `case`/`default` only as a **direct child of the switch's
  compound block**; a `case` at deeper nesting — inside an inner `{}` or a loop (bzip2's
  `GET_BITS` coroutine trick, decompress.c:43-44) — parse-errored. The fix, three parts:
  (1) parse `case`/`default` as label-statements at ANY depth (pstmt), (2) gen keys each
  switch's case-labels by VALUE in a per-switch tablet on a stack `g 'cases` (pushed/popped
  around the body, so a case ties to its NEAREST enclosing switch), (3) a recursive pre-scan
  `scasel` walks the body — through blocks/if/loops, STOPPING at a nested switch — to build
  the dispatch, while `cgstmt` emits each case/default label wherever it sits (`cgitems`
  handles the body, so nested emission is free). Verified: Duff's device + a nested-case /
  fallthrough / nested-switch battery are byte-identical to `gcc -O0`; `make test_moon` +
  `make test_raw` (3453 tests, gcc-free ai) stay green. This un-parse-errors decompress.c
  (which now advances to a codegen rung, below). "Folded case labels" in mooncc's law tail
  is a different, simpler thing (`case 1: case 2:` fallthrough).

- **rung B — `NULL` undefined — LANDED 2026-07-15** (`crew/moon/include/{stdio,stdlib,
  string}.h`). Once rung A let BZ2_decompress parse, it refused at codegen on `(var "NULL")`
  — `s->save_gLimit = NULL`. Not a codegen gap at all: `NULL` was an *undeclared identifier*
  because mooncc defined it only in `<stddef.h>`, while glibc provides `NULL` from
  stdio/stdlib/string too (and bzip2 pulls it via `<stdio.h>`). Fix: a guarded
  `#ifndef NULL / #define NULL ((void*)0)` in those three headers. This took decompress.c
  fully across (a 49 959-byte `.o`) — another header-completeness rung, same family as the
  ctype/ungetc shims, NOT a compiler feature. (Method: a temporary recursive
  cgstmt/cgexpr wrapper that prints the form head on `bad` pinpointed `(var "NULL")` as the
  innermost failure — a reusable gen localizer.)

- **rung C — bzlib.c's undeclared stdio calls — LANDED 2026-07-15** (`crew/moon/include/
  stdio.h`). The localizer pinpointed `(var "ferror")` — `ferror(f)` — as bzlib.c's blocker:
  another missing stdio declaration (glibc has it; mooncc didn't). mooncc's "refuse an
  undeclared call rather than guess the ABI" strictness is arguably *correct*, so the fix is
  headers, not the compiler: added `ferror`/`feof`/`clearerr`/`fdopen`/`rewind` to stdio.h.
  bzlib.c compiled → the whole library builds and round-trips byte-perfect (above). NOTE the
  theme across A/B/C: only rung A was a real compiler feature; B and C were both
  header-completeness. The durable lesson — building third-party C mostly grows a COMPLETE,
  self-contained `crew/moon/include` (run under a sysroot / `-nostdinc`), not the compiler.

- **the bzip2.c CLI tail — LANDED 2026-07-15** (headers only): new `utime.h` + `sys/times.h`;
  `sys/stat.h` gained the permission bits (`S_IRUSR`…) and the `st_atime`/`st_mtime` glibc
  compat macro aliases (`#define st_atime st_atim.tv_sec`); `fchown`/`ferror`/`feof`/`rewind`
  added to unistd/stdio. All 8 files compile after this.

- **rung D — external DATA symbols mis-relocated (a REAL codegen bug, LANDED 2026-07-15)**
  (`crew/holo/obj.l`). Once bzip2.c compiled, the CLI's `-c` (write-to-stdout) mode SEGFAULTED.
  The localizer + `objdump` showed the cause: mooncc emitted `lea stdout(%rip)` with an
  **`R_X86_64_PLT32`** relocation — a *function-call* reloc — for `stdout`, which is external
  DATA. The linker routed it through the PLT (a code stub), so the deref read garbage. ai.c
  never takes the address of an external data symbol (it uses raw `write(1,…)`), so this hid.
  Root: obj.l emitted PLT32 for ALL external refs, not distinguishing a `call`/`jmp` (control
  transfer, PLT32) from an `la`/`lea` (address-of, needs PC32). Fix: carry the byte preceding
  the reloc field (the opcode) into the reloc record; an `E8`/`E9` (call/jmp) → PLT32, anything
  else (a lea's modrm) → PC32. Contained in obj.l — our own linker is unaffected (link.l treats
  PC32≡PLT32), the baked glaze backend (x64.l) is untouched. Verified: `stdout`→PC32,
  `fputs`→PLT32; the full `-c` round-trip works; `test_moon` + `test_raw` (3453) + `test_holo`
  (219) stay green. This was the FIRST real compiler/linker bug the userland ladder surfaced
  beyond a header — every C program using `stdin`/`stdout`/`stderr` (or any `extern` data
  global) needed it.

### the takeaway

The first real LFS package is **~a header-shim day** from compiling, not a rewrite. That
validates the ladder: build a `crew/moon/include` that is self-contained + complete enough
for third-party code (with `-nostdinc`), then walk the LFS order — each package adds a few
header decls and, occasionally, one real parse/gen rung, exactly the ai.c grind.

## suggested order (LFS-shaped, easiest real C first)

bzip2 → gzip → less → m4 → make → sed/grep (gnulib-heavy, harder) → bash → coreutils.
Skip the two-pass cross-toolchain ritual entirely — mooncc/holo/nolibc already ARE the
self-hosting toolchain ([[ai-distro]]). Link initially with a foreign `ld` + the host libc
(the "gcc appears once as ld" precedent), then move packages onto nolibc/holo as their
libc surface is filled in.

## reproduce

```
# base (already green): ai boots as pid 1 on Linux
make distro-run          # or distro-smoke for the headless check

# the bzip2 probe (ctype/ungetc shims now landed in crew/moon/include):
mooncc -Icrew/moon/include -I<bzip2> -c <bzip2>/crctable.c out.o   # -> a real .o
# 5/8 library files compile; decompress.c = rung A (nested case), bzlib/bzip2.c = rung C
```

## the far end — the kernel (for reference)

The same ladder's cliff, from the mooncc-capability survey (2026-07-15): inline asm with
constraints/clobbers is **absent** and there's no register allocator to bind its operands
(stack-machine gen, doc/moon.md:141); `__attribute__` is balance-skipped, not honored (only
`weak`/`section` act); statement-exprs, `typeof`, computed goto, bitfields, `__int128`,
VLAs, and hundreds of `__builtin_*` are absent; no `linux/*`/`asm/*` headers, no atomics/
privileged instructions, the linker refuses foreign `.o` and has no linker-script support.
Don't start here. Fill the userland first; the extensions the last userland packages force
(more `__builtin_*`, attribute honesty) are the same ones the kernel needs — arrive there
having already built them.

Related: [[ai-distro]], doc/moon.md (the compiler), init/boot.l + mk/distro.mk (the base).
