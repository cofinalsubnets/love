# jitgroupir completion — porting the remaining group lanes to the neutral IR

The integer group compiler exists in two forms. The **byte path** (`jitgroup`/`cgg`/`cggv`/`cggt`/
`mkouter` in `love/glaze/emit.l`) emits raw x86-64 byte lists with hand-counted rel32 offsets and owns
every lane. The **IR path** (`jitgroupir`/`cggir`/`cggvir`/`consir`/`mkouterir`/`mkhir`) emits neutral
crew/asm/ IR — labels, no hand offsets — and currently owns only **integer arithmetic** and **value-mode
cons** groups. A transitional gate (`jgir-ok?`) routes a group to the IR path when it fits, else falls
back to the byte path; `auto.l`'s `rewrite-bindings` calls it (line ~833). This doc plans porting the
**five remaining lanes** so the gate becomes vacuous and the byte path retires.

## What's already done (landed on `post`)

| lane | byte path | IR path | gate |
|---|---|---|---|
| integer arith (`+ - * // % & \| ^ < <= > >= =`, `?`, calls) | `cgg` | `cggir` ✅ | op-coverage |
| value-mode cons (`link`, `?`, param-return, value-group calls) | `cggv` | `cggvir`+`consir` ✅ | op-coverage |
| string (`peep`/`tally`) | `cgg` 223-237 | `cggir` ✅ (+ `smask` guard in `mkouterir`) | op-coverage |
| cask (`pin`) | `cgg` 238-244 | `cggir` ✅ (`stxb`; + `bufmask` guard) | op-coverage |
| map (`mpeep`/`mpin`) | `cgg` 227-236 (asmx) | `cggir` ✅ (`relabel`'d probe; + `mmask` guard) | op-coverage |
| chain (`cap`/`cup`/`two?`) | `cgg` 245-250 | `cggir` ✅ (`cmask`, no entry guard; `cap`/`cup` deopt inline) | op-coverage |
| TCO (tail self-call → loop) | `cggt` | `cggtir` ✅ (+ `Lbody` in `mkhir`) | n/a |

**The gate is now vacuous** — `jgir-supported` holds every op the recognizer admits, so `jgir-ok?`
is true for any admitted group and the byte path (`jitgroup`) is unreachable. Stage 7 retires it.
| TCO (tail self-call → loop) | `cggt` | — (compiles as `call`: correct, O(n) stack) | n/a |

The string lane needed a new assembler primitive: the IR had no byte-width memory op, but `peep` is a
`movzx` byte read (and `pin`, stage 3, a byte store). Added **`ldxb`/`stxb`** (indexed zero-extend
load / low-byte store) to `crew/asm/x64.l` — objdump-verified, `asmtest.l` entries, baked into love0. Shared
prerequisite for string + cask.

The IR path's neutral register roles are stable: `argregir` = the callee-saved arg bank (x64
`r3/r12/r13/r14`), `govf` = the OVF anchor (x64 `r11` IR = machine `r12`), `acc`=`r0`, `tmp`=`r7`,
`sp`=`r1`, `hp`=`r2`, `ip`=`r5`. IR `r8`/`r9`/`r10` are **free scratch** in the group ABI — the map
probe (`mprobe-ir`, uses IR `r0`/`r7`/`r8`/`r9`/`r10`) fits with no clash against `govf`/`sp`/`hp`/args.

## The key simplification — the gate is op-coverage, not a re-validated grammar

`jgir-ok?` is reached **only after the recognizer** (`auto.l` `groupok?`/`vok?`/`cok?`/`grpfix`) has
already proven the group glazeable by the byte path's full grammar — shapes, arities, the
int/chain/value typing, the interprocedural string inference, all of it. So the gate must NOT
re-derive the grammar. Its only job: *does the IR path implement every op this group uses, yet?*

So replace the current grammar-mirroring `jgir-e?`/`jgvir-e?` with **one op-coverage walk**: collect
every operator head appearing in every body (skipping group-call names), and return true iff the set
⊆ the IR-supported set. The supported set GROWS one entry per lane landed. When it covers everything
`cgg` handles, the gate is vacuously true for any recognizer-admitted group → `jitgroup` retires.

```
jgir-supported '(+ - * // % & | ^ < <= > >= = ? link peep tally pin mpeep mpin cap cup two?)
(jgir-ok? defs) (: syms (map (\ d (cap (cap d))) defs)
   (all (\ d (allops? syms (cup d))) defs))          ; allops? walks the body; every non-call head ∈ supported
```

This is more robust than the current gate (no chance of the gate and recognizer disagreeing on the
grammar) and it's why the port is *additive*: each lane = one op added to `jgir-supported` + the
codegen case + the entry mask. Until a lane lands its op stays out of the set, so those groups keep
taking the (working) byte path.

## Where masks live — only the entry's outer needs them

A group fn's body codegen dispatches on the **op** to learn a param's type (`peep P` ⇒ `P` is a
string; `mpeep P` ⇒ a map; `+P` ⇒ a raw int). Siblings receive args already in raw form from the
caller (`cggir` computes raw ints; `cap E` yields a raw chain pointer), so **no sibling guards**. Only
the **entry's outer** (`mkouterir`) guards the *external* arguments and decides raw-vs-sar per param:

- **int** param: `test`-low-bit (fixnum? else → OVF/deopt), then `sar` (untag), push.
- **string/map/cask** param: `test`-low-bit (a fixnum can't be a heap object → OVF), load `[arg]`,
  compare against the kind constant (`strkind`=`(apof "")` / `mapkind` / `bufkind`=`(apof (cask 1))`;
  else → OVF), push **raw** (no sar).
- **chain** param: **no guard**, push raw. (`two?` is total — a non-chain reads false; `cap`/`cup`
  guard inline and deopt a non-chain.)

This mirrors the byte path's `mkguards`+`mkig`+the `pushargs` sar-skip exactly. `jitgroupir` computes
the four masks for the entry by **reusing the byte path's already-defined helpers** (`suse?`/`cuse?`/
`muse?`/`buse?` + the interprocedural `smfix`/`fnsm`/`gsm` fixpoint; `mmask`/`bufmask`/`cmask` are
direct `gfilt`s over the entry params — see `jitgroup` lines 388-392). They're in scope (defined
before `jitgroup`, and `jitgroupir` sits after). `mkouterir` grows from
`(tgt k entry arity valt)` to also take `smask mmask bufmask cmask`; `imask` = the complement.

Kind constants in IR: `(li reg kind)` — `li` already carries full 64-bit immediates (`mprobe-ir`'s
`(li r0 mapmix)`). `cmp` against a 64-bit pointer needs the constant in a register first
(`(li r8 kind) (cmp T r8)`), since `cmp`-imm is 32-bit.

## Per-lane codegen (into `cggir`, x64-correct; IR stays target-neutral where free)

All new IR written with the backtick list ctor `` ` `` (per house pref), wrapped one level for `asm`
(`asm` is `foldl-(+)`; each element a *list* of IR forms, so a single form is `` `(`('op ..)) ``).

**chain** — `R` = the chain param's arg reg (`argregir`); `A`=acc, `T`=tmp:
- `(two? E)`: `E`→acc via `cggir`; gensym labels `z`/`e`; `test A 1` → if odd (fixnum) jump `z`;
  `(ld T A 0)`; `(li r8 chainkind)`; `(cmp T r8)`; `br ne z`; `(li A 1) (jmp e) (label z) (li A 0)
  (label e)`. Total, no deopt.
- `(cap E)`: `E`→acc; chain-guard → OVF (`test A 1` `br eq` no… `br ne OVF` on the odd bit? a fixnum
  `cap` deopts: `test A 1`/`br ne OVF`; `(ld T A 0)`/`(li r8 chainkind)`/`(cmp T r8)`/`br ne OVF`);
  then `(ld A A 8)`. (`cup` = same with `(ld A A 16)`.) Result is a raw chain word — only ever a call
  arg or under another `cap`/`cup` (the recognizer's `cok?` forbids it in an int slot, cf. test `rcb`).

**string** — `R` = the string param reg:
- `(tally STR)`: `(ld A R 8)` (acc = the len at `[STR+8]`, raw). No guard (entry guarded it).
- `(peep STR i d)`: `i`→acc via `cggir`; gensym `in`/`end`; `(cmp A <len>)` where `<len>`=`(ld T R
  8)` first; `br below in`; OOB: `(li A d) (jmp end)`; `(label in)`; byte load `[STR + i + 16]`
  zero-extended → acc (`ldx`-byte, scale 1, disp 16, base `R`); `(label end)`. `d` defaults 0.

**cask** — `R` = the buf param reg:
- `(pin C i V)`: `i`→acc; push; `V`→acc; pop `T`(=i); `(ld r9 R 8)` (backing str from `[C+8]`); store
  `V`'s low byte at `[r9 + i + 16]` (`stx`-byte); `(mov A R)` — result is the cask (raw ptr; usually
  `_`-bound for effect). `r9` is free scratch.

**map** — `R` = the map param reg. The probe (`mprobe-ir` + tails) already IS crew/asm/ IR with symbolic
labels `loop`/`hit`/`miss`/`end`(/`deopt` for `mpin`). Splicing it inline N times would collide those
labels in the single group `assemble`. Fix with a **generic relabel pass** `(relabel ir alist)` that
deep-substitutes symbols in the IR forms (labels are bare-symbol operands, disjoint from `r0`..`rN`):
per site, map the four/five labels to fresh `(mint 0)` gensyms — and for `mpin`, map `deopt` → the
group's `DEOPT` label so the miss-grow path reaches the group deopt (resolved naturally by the
assembler, no `asmx-seed` offset math). Setup per the byte path: map reg → acc, tagged key → IR `r10`
(`leax`), spill `v` for `mpin`. `mpeep` (READ, no deopt) could alternatively be `asmx`'d to bytes and
spliced as `(raw ..)`, but the uniform relabel path handles both — prefer it.

**TCO** (`cggtir`, the integer-body tail-position variant — value bodies use `cggvir`, no TCO, as the
byte path's `bc` does): `mkhir` emits a body-start label `Lbody` after `loadargsir`, and drives the
integer body through `cggtir nm Lbody` instead of `cggir`. `cggtir`: a tail **self-call** (head = `nm`,
arity matches) → push the new args, pop them into the arg regs, `(jmp Lbody)` (frame reused, O(1)
stack); a tail `?` → test non-tail (`cggir`), both branches tail; anything else → `cggir` + fall to
restore+ret. TCO is an **optimization, not a correctness gate** — without it tail self-calls are plain
`call`s (correct). Land it so the IR path doesn't regress loop perf when it takes over from `jitgroup`.

## Staging — one lane per commit, each verified against `test/glaze-x86.l`

The AUTO block already asserts each lane end-to-end (`= (base-ev …) (ev …)`, i.e. native == interp);
porting a lane just re-routes its asserts from `jitgroup` to `jitgroupir` with no test change:

1. **gate refactor** ✅ (`a7975b15`) — op-coverage `jgir-ok?`/`jgir-ops-ok?` over a growing
   `jgir-supported`; behavioral no-op.
2. **string** ✅ — `peep`/`tally` in `cggir`; `mkouterir` grew four masks (`smask mmask bufmask cmask`,
   all computed now, only `smask` populated this stage) with per-param guards (int fixnum-guard + sar;
   string/map/cask kind-guard `(test;br ne)` + raw; chain raw); `ldxb`/`stxb` in `crew/asm/x64.l`.
   Verified through `make test_glaze` (NOT a standalone run — see gotchas).
3. **cask** ✅ — `pin` in `cggir` (`stxb` byte store into `[C+8]`'s backing + idx; returns `C`, so it
   threads as a sibling-call cask arg); `bufmask` already computed+guarded (stage 2). `leff` stays
   interp (effectful `_`-bound `pin`); the glazed path is `castbuild`'s lifted fill loop (cb*).
4. **map** ✅ — `mpeep`/`mpin` in `cggir` reusing the `mprobe-ir`/`mpeep-ir`/`mpin-ir` IR fragments
   through a generic `relabel` pass (gensym the fixed `loop`/`hit`/`miss`/`end` labels per site; `mpin`'s
   `deopt` → the group's **`OVF`**, matching the byte path's seed — the full unwind, not bare `DEOPT`).
   `mmask` guard already landed (stage 2). **Also fixed `jitgroupir`'s `fb`**: `mpeep`/`mpin` are
   glaze-internal names, not real fns, so the interp deopt fallback must alias them to the core
   `peep`/`pin` (the byte path does this; without it the fallback hit unbound `mpeep` → `(() m 3 -1)` =
   const-1 = -1 — the silent trap, found via the grow-deopt path). The sequence law makes the alias
   `(mpeep mc mk md) (peep mc mk md)` read the *previous*/global `peep`, not recurse.
5. **chain** ✅ — `cap`/`cup`/`two?` in `cggir`; `cmask` params raw, NO entry guard (`two?` total;
   `cap`/`cup` chain-guard inline → `OVF`). `rcl` (tree walk) glazes `ck`; `rcb` stays interp (recognizer
   rejects `cap`-into-arith). GOTCHA: in backtick IR, write `'OVF` (the literal label) — bare `OVF` is a
   variable read → missing → `()` → `undef-label ()`.
6. **TCO** ✅ — `cggtir` (tail self-call → compute new args, pop into arg regs, `jmp Lbody`; tail `?`
   recurses tail; else `cggir`) + `Lbody` label in `mkhir` after loadargs. Self-only (sibling tail-calls
   stay `call`, as the byte path). **Required before the vacuous gate is safe**: a 1M-deep tail loop via
   jitgroupir without TCO SIGSEGVs (verified exit 139 → fixed; the 1M loop now returns its value).
7. **retire** ✅ (functional) — the gate's `jitgroup` fallback is replaced by `val` (interp), so
   `autogroup` never calls the byte path; `jgir-ok?` stays as a soundness backstop (an uncovered group
   interps, never miscompiles). `jitgroupir` is the **sole live group lane**. *Queued hygiene* (a clean
   follow-up — the removal is interleaved with KEEP items, so do it fresh): physically delete
   `cgg`/`cggv`/`cggt`/`gargs`/`consemit`/`mkguards`/`mkig`/`mkouter`/`jitgroup` + the byte-ABI helpers
   (`arx`/`pshr`/`popr`/`ldr`) from `emit.l`, and the now-redundant byte-path `jitgroup` asserts from
   `test/glaze-x86.l`'s EMIT block. KEEP `hasl`, `suse?`/`cuse?`/`muse?`/`buse?`/`dedup`/`gsm`/`fnsm`/
   `smfix` (jitgroupir reuses them), `mprobe-ir`/`mpeep-ir`/`mpin-ir`, the kind consts, and the
   leaf/loop/float byte lanes (those are separate, not retired here).

## Touch list & gotchas

- `mkouterir` signature grows (+4 masks) → the direct test call `(mkouterir 'arm64 1 'fib 1 0 …)` in
  `test/glaze-x86.l` needs the new args (currently `… 1 0`). Default all masks `()` for the int case.
- `emit.l`'s `asm` is one-level concat — wrap single forms; flatten byte builders. The `assert` in the
  EMIT block surfaces only the FIRST failure (fixing one unmasks the next).
- ai `+` is **dyadic** — always nest byte/offset math in codegen (`(+ a (+ b c))`), never `(+ a b c)`
  (that church-exponentiates). The idiv "hang" bug was exactly this.
- A silent reader stop (exit 0, no `zz-fin`) = paren imbalance. The whole `test/glaze-x86.l` runs in
  ~1.5–1.8s; a hang/crawl is a *bug*, not slow benches (see CLAUDE.md "SPEED IS A SIGNAL").
- **Run the glaze test via `make test_glaze`, never `out/host/love test/glaze-x86.l` standalone.** The
  harness *cats emit.l + auto.l ahead* of the test; standalone, `base-ev`/`jitgroupir`/the internals are
  unbound → `()` → `(base-ev '(..))` = const-1 = 1 SILENTLY skips every assert block, yet the top-level
  `(say "..ok")` still prints — a false pass. Same trap when probing an internal (`(cggir ..)` with
  cggir unbound = `(() ..)` = 1, not an error). Defenses now in the file: a **top-level** `(assert
  (lit? base-ev) (lit? jitgroupir) ..)` that scares on a wrong invocation, and a per-block `lit?`
  dependency guard. When probing by hand, cat the same files: `cat love/glaze/emit.l love/glaze/auto.l
  probe.l | out/host/love`. (`assemble` is a core service — bound even standalone — so it alone won't
  catch a wrong context.)
- x64 only in practice (`auto.l` calls `jitgroupir … 'x64`); the IR is kept neutral where free, but
  arm64 group codegen is unverified (no harness) — don't chase it here.
- Discriminator for image-vs-egg divergence: `AI_NO_IMAGE=1`.
