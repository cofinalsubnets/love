# the aarch64 glaze — ABI spec & retarget plan

The live glaze (`ai/glaze/emit.l` + `auto.l`) emits **raw x86-64 byte lists inline** and is x86-only.
The path to an aarch64 glaze is to route `emit.l`'s codegen through the neutral assembler
(`asm/asm.l` + backends), after which `asm/arm64.l` carries the second target. This doc is the ABI
spec the retarget needs. The assembler side is **done and gated** (`asm/asmtest.l`); the codegen
retarget is the remaining work.

## How native code is reached (why the ABI is what it is)

The register convention is **not** register-pinning — it is the **platform C calling convention**.
A `nat`/native closure's body is entered as an ordinary indirect *tail call* through a function
pointer whose C type is `lvm_t = struct ai *(*)(struct ai *g, union u *Ip, ai_word *Hp, ai_word *Sp)`
(`ai.h:54,75`). Dispatch is `Continue() = Ip->ap(g, Ip, Hp, Sp)` (`ai.h:55-56`); each op is a
separate `ai_noinline noipa` function ending in a tail `Continue()`, so ops chain by sibling-jump
and **g/Ip/Hp/Sp live in the ABI's first four argument registers across the whole chain**. Apply:
`lvm_ap` (`ai.c:2596`) sets `Ip` to the closure value cell and `Continue()`s straight into the
emitted bytes; install + cell layout `[code,src,code,interp,lvm_ret,n]` in `lvm_nif` (`ai.c:4856`).
The body may scratch other registers but **must preserve g/Ip/Hp/Sp** for the next op and for the
deopt `interp` (`auto.l:1071`).

Consequence — same mechanism, no arch-specific VM code (the dispatch/install/W^X mmap are all plain
C under `#if __STDC_HOSTED__`, never `#if __aarch64__`):

| logical | x86-64 (SysV) | aarch64 (AAPCS64) |
|---|---|---|
| g  | rdi | x0 |
| Ip | rsi | x1 |
| Hp | rdx | x2 |
| Sp | rcx | x3 |
| result slot | `Sp[0]` (stored, then Continue) | `Sp[0]` (same) |

The result is **stored to `Sp[0]` and tail-threaded**, never returned in a register per-op (only the
final `lvm_ret` returns to C). So the accumulator need not be the ABI return register.

## The register-role map (the crux)

`asm/x64.l`'s abstract file is deliberately tuned to SysV: g/Ip/Hp/Sp = abstract **r6/r5/r2/r1**,
acc = r0. `asm/arm64.l` is an **identity** file (rN→xN), so the *same abstract numbers* would land
g/Ip/Hp/Sp in x6/x5/x2/x1 — wrong. AAPCS needs x0/x1/x2/x3. **The arm64 glaze therefore uses a
different role→register map**; the retargeted `emit.l` must select it per target.

| role | x86-64 reg (abstract) | aarch64 reg (abstract) | note |
|---|---|---|---|
| g  | rdi (r6) | x0 (r0) | unused by the integer lane; kept intact |
| Ip | rsi (r5) | x1 (r1) | deopt / Continue |
| Hp | rdx (r2) | x2 (r2) | cons / room guard |
| Sp | rcx (r1) | x3 (r3) | arg slots, result store |
| acc | rax (r0) | x4 (r4) | the accumulator (on arm64 **not** r0) |
| temp | r8 (r7) | x5 (r5) | popped operand |
| loop 0/1/2 | r9/r10/r11 (r8/r9/r10) | x6/x7/x8 (r6/r7/r8) | counted loops |
| scratch (mulo/rem `t`) | rbp (r4) | x9 (r9) | clobbered; ≠ operands |
| args 0–3 | rbx/r13/r14/r15 (r3/r12/r13/r14) | x19–x22 (r19–r22) | **callee-saved**; each H saves/restores |
| OVF anchor | r12 (r11) | x23 (r23) | post-prologue SP snapshot |

x86-15..x18 are absent from the arm64 file on purpose: x16/x17 are IP0/IP1 scratch (the indexed
stores borrow x16) and x18 is platform-reserved. The callee-saved bank x19–x28 + `fp`(x29)/`lr`(x30)
are now exposed.

## aarch64-specific codegen notes (gotchas, all verified)

- **`mov` to/from `sp` must be `lea`, not `mov`.** The ORR-based `mov` reads/writes XZR for register
  31, never sp — `(mov sp r23)` silently assembles to `mov xzr,x23`. Use `(lea r23 sp 0)` to snapshot
  sp into the anchor and `(lea sp r23 0)` for the deopt frame-abandon (x86's `mov rsp,r12`).
- **Save `lr` (x30) around nested calls.** `call`=`BL` clobbers x30; a group `H` that calls a sibling
  must `(push lr)` in its prologue and `(pop lr)` before `(ret)` (x86 gets this free from CALL/RET's
  implicit stack return address). `lr`/`fp` are arm64-only names — `(push lr)` raises `badreg` on x64,
  which is correct (the retarget emits it only for arm64).
- **Overflow is split: `adds`/`subs` + `(br vs …)` for add/sub; fused `mulo` for multiply.** No
  flag-setting multiply on aarch64, so `mulo` is `SMULH t,a,b ; MUL d,a,b ; CMP t, d ASR#63 ; B.NE`
  (overflow ⇔ high half ≠ sign-extension of low half) — hence the explicit scratch `t`.
- **Indexed addressing is synthesized** (no `[base+ix*scale+disp]` single insn): `ldx`/`leax` borrow
  the destination as the address temp; `stx` uses x16.
- **bignum `li`** extracts MOVZ/MOVK lanes with `//`/`%` (not `&`/`>>`, which drop a bignum's high
  limb) — needed for the map hash constant `0x9e3779b97f4a7c15`.
- **I-cache flush (C core, the one non-assembler prerequisite).** aarch64 needs
  `__builtin___clear_cache(base, base+len)` after writing code, before the first jump into it. Noted
  but not yet emitted at `ai.c:4695-4696` (`eat_run`); for `nat` it belongs in `lvm_nif`/`lvm_toast`
  where the bytes are written.

## status

- **Assembler — done & gated** (`asm/asmtest.l`, both targets, every encoding objdump/llvm-mc-verified):
  P0 `jmpr`/`adds`/`subs`/`vs`/`vc`/`mulo`/`set`; P1 shifts/`test`/`div`/`rem`/indexed + the bitmask-
  immediate encoder + the bignum-`li` fix; `lr`/`fp` + the callee-saved bank; the sp-via-`lea` idiom.

- **The codegen retarget — three lanes done & full-`make test`-green**, in `emit.l`, ADDITIVE (the live
  x86 byte path — `jit`/`njit`/`jitn`/`jitgroup` — and `auto.l` are untouched; these are parallel
  `(jit*ir lam tgt)` entries). Shared scaffold: `greg` (the per-target role→reg map above), `cgir`
  (leaf/n-ary expr→IR), `coreir`/`jitcore` (prologue/body/putfix-epilogue+Continue/deopt + install),
  `deoptir`. IR chunks concatenate FLAT via `asm` (emit.l's `foldl-(+)`; on lists of IR forms `+`
  appends) — NOT nested `(cat (cat …))`, which bites paren-counting. ⚠ each `(L 'op …)` builds a form;
  a quoted `'(op A …)` embeds the literal symbol `A`, not the register value — only quote all-literal
  forms (`'(br eq OVF)`), use `(L …)` when a role-reg is an operand.
  - **leaf** `jitir` (arity 1): `var | int | +-*//%&|^ | cmp | ?`; machine-stack nesting; deopt→interp.
  - **n-ary** `jitnir` (arity ≥2): `Sp[i]` param fetch (`fxir`); deopt→interp BODY (`value[1]+16`).
  - **group** `jitgroupir` (mutual recursion): `cggir`/`gargsir`/`mkhir`/`mkouterir`. Calls = `(call
    <name>)`+`(label <name>)` (asm/ resolves rel offsets — the byte path's two-pass offset math is
    gone). Callee-saved arg bank + OVF anchor; per-H save/load/restore + arm64 `lr`-save; the shared
    OVF handler `lea`s sp from the anchor (abandons all frames) then deopts. `slotsz` (8/16) unifies
    the stack math. Covers fib/tak/even-odd + overflow→deopt→bignum.
  Tests live in **`test/glaze-x86.l`** (`make test_glaze`, x86-host-only): x86 native == interp;
  arm64 assembles (data) and is llvm-mc-checked by hand — arm64 EXECUTION still needs the qemu kernel
  harness (no aarch64 host here; cf. `ai/glaze/probe.l`).

- **Remaining (in order):**
  1. **counted-loop lane** — `loopcode` (`jitsum`) and `loopcode-n` (`jitloop-n`) → IR (the back-edge
     loop owner: iterative sums, fib-as-loop). Reuses `greg`/`cgir`; the new piece is the loop
     back-edge + the loop-var registers.
  2. **TCO** — a tail self-call in the group lane → `jmp Lbody` (reuse the frame; O(1) stack), per
     `cggt`. Add a `Lbody` label after the H prologue and detect tail self-calls in `cggir`.
  3. **value-mode** (`cggv`) — list-returning group fns (a `(link A B)` cons body): a room-guard + heap
     write, value-epilogue (store rax as-is, no putfix). Needs `consemit` in IR.
  4. **special ops** — `peep`/`tally` (string), `mpeep`/`mpin` (map — already neutral IR via the
     `asm/` probe, just wire it in), `pin` (cask), `cap`/`cup`/`two?` (chain). Needs byte load/store
     (`ldrb`/`strb`) on the arm64 backend (P2 item) for the string/cask sub-cases.
  5. **wire into `auto.l`** — once a lane is proven equal to the byte path, pick the host target and
     route `auto.l`'s recognizers through the IR entries; then retire the byte path. Add the I-cache
     flush in `nat`/`toast` (`ai.c`) so arm64 can actually run installed code.
  - **P2 (separate sub-project):** the **float/grid lane** (`cgf`/`jitfr`/`loopcode-gridn`) — needs a
    FLOAT register file in `asm/` (xmm/NEON + `movsd`/`addsd`/`mulsd`/`divsd`/`cvtsi2sd`/`ucomisd`/
    `movq`), which the integer-only IR doesn't model yet.

  **How to add a lane** (the proven loop): prototype in scratchpad against `cat emit.l proto.l | ai`
  (x86 behavioral == interp); disassemble the arm64 output with `llvm-mc --disassemble
  --triple=aarch64`; integrate into `emit.l` additively; add `test/glaze-x86.l` coverage; `make
  test_glaze`; then the full `make test`. The glaze is corpus-independent (unbound under
  `AI_NO_IMAGE`; `emit.l` is a host-only bake, not in `ai0`), so only `test_glaze` exercises it.
