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
| `dmul` | 57 | 85 | 220 |
| `dadd` | 69 | 90 | 186 |
| `sin` (lm.c) | 2,926 | 3,927 | 9,504 |

mooncc's code for lm.c itself is ~1.3x gcc's. **About 80% of the gap is rt.c's helpers**:
portable v6-M C (16x16 products, a branch-ladder clz) over `uint64_t`, which mooncc keeps in
the frame. The ~25-instruction overhead per call in the middle column is the caller's own
staging.

## what this branch carries (gated: see the commit)

- `(u64) a * b` of two widened words is one `umull` / `smull` (gen.l `wmul`, read off pwid's fill)
- a pair binop parks its left straight in r2:r3 when the right's forms never name them (`rclean?`)
- r2, r3 pool on thumb2 (`tpool`), temps and homes. both are mints, and `pclash?` (gen.l, at
  vrfix) rebuilds the fn with no pool when a kit's literal r2/r3 write, or a runtime-helper
  call, lands inside a mint's span (a home's span is fn-wide). `MOON_ABLATE=tpool` prices it
- `long long` locals in two callee-saved seats on thumb2 (`ph?`, the d128 `regw` route): read,
  store, decl init, `++`/`--`. params are not pair-homed yet
- rt.c `__aeabi_dmul`: a v7-M fast lane for normal x normal -> normal (768 -> 243 instructions);
  anything else falls to the general code. bit-identical to the old over `perf.sh diff`
- rt.c `__aeabi_dadd` (and so `dsub`): the same lane in 32-bit words (450 -> 218), its names few and
  reused in place; `dadd_any`/`dmul_any` hold the general code, so the lanes' names get the seats
- rt.c compares through a word `dord` (no out-param, no `int64_t`); `i2d`/`ui2d` (v7-M, over `clz`),
  `d2iz`/`d2uiz` in a word's range and a normal `f2d` in place. `perf.sh diff` covers them too
- thumb2 modified immediates: and/or/xor/tst/cmp/cmn take one (`t2imm?`), and/or the complement's
  as bic/orn (`x & 0x7fffffff` is one bic)
- `twmv` (was a64mv) on thumb2: `(mov d s) (shr d c)` is one `lsr d, s, #c`, likewise the extends and
  mvn; a move or load into a register that only passes it on lands where it goes. `t2nx` drops a
  word's zx4/sx4 at the post-choice chain's head, where they parted those pairs
- earlier in the arc: thumb2 param homes (`nhome` 4, r5..r8 callee-saved), valloc/vpre/vweb/vspare
  on thumb2, float shuttle parks in d-regs, `fleft1`, the float negate fold

## next, by payoff

1. **the codegen the lanes now show**: params stored to the frame and reloaded, `(x >> s) & 0x7ff`
   with no `ubfx`, `cmp` with an imm12 out of modified reach (`0x7fe`) through r0, the a64/rv64 sweeps
   (`swp`) not run on thumb2 at all, a negated literal (`== -0x1fe00`) not folded to an immediate. rt.c checked with `perf.sh diff` against HEAD's (libgcc is no oracle: it mis-rounds
   `0x4340000000000000 + 0xc13e9b8531b800e9`, exact is ...7b)
2. **pair-homed params** (`homefold`): rt.c's `ua`, `ub` live in the frame today
3. **seat pressure**: past six cs seats every name spills (`dadd` has 19 candidates, `ma` loses);
   rank by weighted mentions and split. `MOON_DUMP=<fn>` prints ulloc's ranking and map
4. float homes for thumb2 params/locals (a loop reloads `k` from the frame), indexed and
   post-increment addressing, one `push {..}` prologue
5. then the device: `make -C src/love/user/playdate game=stones`, install, read
   `Data/love/trail.txt` (the `song ... ms` lines are the feed's cost per frame)

## method and traps

- `perf.sh count` steps each fn from its first instruction to `lr` under qemu's gdbstub. gdb's
  `finish` mis-frames mooncc's fns, and arm-none-eabi-gdb's python is broken here (CLI only)
- objdump needs `-M force-thumb` on mooncc objects (no `$t` mapping symbols)
- `perf.sh probe` runs kit.c (pool vs kits) and kit2.c (pair locals); both answer 0
- a playdate audio callback runs unprivileged in an RTOS thread: `mrs psp` reads 0, so the
  device has no pc sampling. time love-level pieces with `(clock 0)` instead
- owed for a gen.l change: the moon lanes in AGENTS.md (test_moon, test_clay, every test_cc%,
  test_fixpoint, test_moonfuzz, test_inle) and the thumb lanes; rt.c rides the bake
