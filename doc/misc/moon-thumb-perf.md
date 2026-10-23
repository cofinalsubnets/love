# moon-thumb-perf — mooncc's thumb2 code against gcc's

A **living ledger** for the arc that makes mooncc's `-t thumb2sp` (Cortex-M7, SP-only FPU: the
Playdate) and `-t thumb2` code competitive. The reason: `love lore stones` on the device, whose
music synthesis runs about 1.5x slower than real time. Rows go when they land.

## where the time goes

Love's numbers are doubles. On an SP-only FPU every double op is a soft-float call into
`src/apps/moon/lib/rt.c`, and the array kernels (`sin`, `floor`, `*`, `+` over 735-sample
trays) are nothing but those calls. On the device the drone takes ~32 ms per chunk: 4 `sin`
(~14 ms), 4 `floor` (~4 ms), ~22 multiplies and adds (~7 ms), the rest allocation.

Instructions per call on qemu's M4 (`sh test/thumb2/perf/perf.sh count gcc|libgcc|moon`):

| | gcc -O2 + libgcc | mooncc + libgcc's helpers | mooncc + rt.c |
|---|---|---|---|
| `dmul` | 57 | 85 | 88 |
| `dadd` | 69 | 90 | 97 |
| `sin` (lm.c) | 2,926 | 3,927 | 4,198 |

On v7-M rt.c's hot helpers are thumb2 asm now, near libgcc's: in one `sin`, 26 `dadd`/`dsub`
take ~1,760, 18 `dmul` ~910, the compares and conversions ~160, and mooncc's code for lm.c
itself ~1,370 -- the gap left to gcc is that code (frame traffic, constants, moves). The
~25-instruction overhead per call in the last two columns is the caller's own staging.

## what this branch carries (gated: see the commit)

- `(u64) a * b` of two widened words is one `umull` / `smull` (gen.l `wmul`, read off pwid's fill)
- a pair binop parks its left straight in r2:r3 when the right's forms never name them (`rclean?`)
- r2, r3 pool on thumb2 (`tpool`), temps and homes. both are mints, and `pclash?` (gen.l, at
  vrfix) rebuilds the fn with no pool when a kit's literal r2/r3 write, or a runtime-helper
  call, lands inside a mint's span (a home's span is fn-wide). `MOON_ABLATE=tpool` prices it
- `long long` locals in two callee-saved seats on thumb2 (`ph?`, the d128 `regw` route): read,
  store, decl init, `++`/`--`. params are not pair-homed yet
- rt.c on v7-M, thumb2 asm (file-scope `asm`, GNU unified syntax gcc assembles alike):
  `dadd`/`dsub` and `dmul` for normal operands whose answer stays normal, and a zero beside a
  normal; the six compares over one ordering core; `i2d`/`ui2d`; `d2iz`/`d2uiz` in a word's range.
  anything else falls to `__dadd_any`/`__dmul_any`/`d2lz` with the arguments as they came. each
  mirrors the C it replaced step for step, bit-identical over `perf.sh diff` (now `dcmpge`/`dcmpgt`
  too); building the same rt.c with gcc checks the asm apart from our assembler
- holo's thumb2 gas reads what those take: `b<cc>`, `push`/`pop` lists (16-bit where they fit),
  the flag and carry ops with a modified immediate, a shifted register operand (`alush`),
  `umlal`, register-count shifts, `ubfx`, `clz`, `tst`, `cmn`, `movw`, `addw`/`subw`
- rt.c's C, the general code and v6-M's: compares through a word `dord` (no out-param, no
  `int64_t`), a normal `f2d` in place. `perf.sh diff` covers them too
- thumb2 modified immediates: and/or/xor/tst/cmp/cmn take one (`t2imm?`), and/or the complement's
  as bic/orn (`x & 0x7fffffff` is one bic), a low run of ones as `ubfx`; `twmv` folds a right shift
  and its low mask into one `ubfx`, or drops a mask the shift already cleared
- `twmv` (was a64mv) on thumb2: `(mov d s) (shr d c)` is one `lsr d, s, #c`, likewise the extends and
  mvn; a move or load into a register that only passes it on lands where it goes. `t2nx` drops a
  word's zx4/sx4 at the post-choice chain's head, where they parted those pairs
- earlier in the arc: thumb2 param homes (`nhome` 4, r5..r8 callee-saved), valloc/vpre/vweb/vspare
  on thumb2, float shuttle parks in d-regs, `fleft1`, the float negate fold

## next, by payoff

1. **the device**: `make -C src/love/user/playdate game=stones`, install, read
   `Data/love/trail.txt` (the `song ... ms` lines are the feed's cost per frame)
2. **gas: a numeric label never defined** (`b 7f`, no `7:`) assembles as an undefined `l7.1`
   and fails only at the link, on every target; GNU refuses it at the line
3. **the codegen the lanes now show**: params stored to the frame and reloaded, `cmp` with an imm12 out of modified reach (`0x7fe`) through r0, the a64/rv64 sweeps
   (`swp`) not run on thumb2 at all, a negated literal (`== -0x1fe00`) not folded to an immediate. rt.c checked with `perf.sh diff` against HEAD's (libgcc is no oracle: it mis-rounds
   `0x4340000000000000 + 0xc13e9b8531b800e9`, exact is ...7b)
4. **pair-homed params** (`homefold`): a `uint64_t` param lives in the frame today
5. **seat pressure**: past six cs seats every name spills (C `dadd` had 19 candidates);
   rank by weighted mentions and split. `MOON_DUMP=<fn>` prints ulloc's ranking and map
6. float homes for thumb2 params/locals (a loop reloads `k` from the frame), indexed and
   post-increment addressing, one `push {..}` prologue

## method and traps

- `perf.sh count` steps each fn from its first instruction to `lr` under qemu's gdbstub. gdb's
  `finish` mis-frames mooncc's fns, and arm-none-eabi-gdb's python is broken here (CLI only)
- objdump needs `-M force-thumb` on mooncc objects (no `$t` mapping symbols)
- `perf.sh probe` runs kit.c (pool vs kits) and kit2.c (pair locals); both answer 0
- a playdate audio callback runs unprivileged in an RTOS thread: `mrs psp` reads 0, so the
  device has no pc sampling. time love-level pieces with `(clock 0)` instead
- owed for a gen.l change: the moon lanes in AGENTS.md (test_moon, test_clay, every test_cc%,
  test_fixpoint, test_moonfuzz, test_inle) and the thumb lanes; rt.c rides the bake
