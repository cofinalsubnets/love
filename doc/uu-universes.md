# Scoping: a universe hierarchy for uu (retire type-in-type)

**Goal.** Replace uu's type-in-type (`test/uu.l`) with a predicative cumulative universe
hierarchy, so uu's *own* kernel is consistent — the soundness keystone. Today uu relies on the
Rocq export (`tools/uu2coq.l`) to filter out unsound proofs; after this, uu means something on
its own, and `but_seriously_the_world_explodes : empty` (uu.l:~1370) flips from provable to
*rejected*. The reference (UniMath/Foundations) is itself predicative — it only `Unset Universe
Checking` for convenience — so this restores the intended metatheory, it doesn't invent one.

## Where type-in-type lives today (the whole surface to change)

The kernel carries NO levels: the sole sort is the bare symbol `'UU`, and every type-former
returns it flat. Exactly two loci:

1. **`inf-sym` (uu.l:113-114)** — the sort's own type:
   - `(id? x 'UU) 'UU`            ← `UU : UU`, the inconsistency
   - `(member? x '(nat bool unit empty)) 'UU`  ← the base inductives are types
2. **The type-formers in `inf` (uu.l:166-200)** — each checks components against `'UU` and
   returns `'UU`, with no level arithmetic:
   - `pi`     (166-171): `chk A:UU`, `chk B:UU` ⟹ `UU`
   - `total2` (172-177): same shape (Σ)
   - `coprod` (178-179): `chk A:UU`, `chk B:UU` ⟹ `UU`
   - `paths`  (180-185): `chk A:UU`, `chk a,b:A` ⟹ `UU`
   - `the`    (196-200): `chk T:UU`, `chk t:T` ⟹ `T`
   - recursor motives (e.g. `nat_rect`, 206-214) check `P` against `(pi x nat UU)` (large elim)

Everything else — `vof` (eval/NbE), `conv` (definitional conversion), `vapp`/`capp`, the
recursor reductions `donr`/`dobr`/… — is **untouched**: levels ride on the sort *value*, and the
neutral-application NbE doesn't care. This is why the change is localized and low-risk to the
evaluator.

## Design

### Level representation
- Sort value becomes `('U i)` (i a charm). Surface: bare `UU` ≡ `(U 0)`; add `(UU i)` for an
  explicit level. `vof` gains a case mapping `UU`→`('U 0)` and `(UU i)`→`('U i)` (today `UU`
  evaluates to itself as a neutral; it becomes a first-class sort value).
- `conv` already handles 2-lists structurally (uu.l:104), so `('U i)` vs `('U j)` compares by
  `i = j` for free. Cumulativity (`i ≤ j`) is a deliberate ADD-ON, below.

### The typing rules (predicative, à la UniMath — no impredicative Prop)
- `UUᵢ : UUᵢ₊₁`  →  `inf-sym` of `UU` returns `('U 1)` (was `'UU`); `(UU i)` returns `('U (i+1))`.
- `nat, bool, unit, empty : UU₀`  →  `inf-sym` returns `('U 0)`.
- **Π/Σ formation (the heart):** `A : UUᵢ`, `x:A ⊢ B : UUⱼ`  ⟹  `∏(x:A),B : UU_{max(i,j)}`.
  So `inf` of `pi`/`total2` changes from "`chk` both against `'UU`, return `'UU`" to "**`inf`
  each component's sort, assert it's a `('U _)`, return `('U (max i j))`**". A small helper
  `(sortof cx en d T)` = `inf` then assert/extract `('U i)` (scare `uu-not-a-type` otherwise).
- `coprod`: `A+B : UU_{max(i,j)}`.
- `paths A a b : UUᵢ` where `A : UUᵢ` (the identity type stays at A's level).
- `the`/`let`/recursor motives: motive into `('U i)` for the level in use (large elimination
  into any universe is fine; track i rather than hard-coding `UU`).

### Two stages — and why the split is exactly the export boundary
**Stage 1 — concrete levels (bounded, recommended first).** Levels are concrete charms; Π/Σ
compute `max`; no constraint solving. This is fully SOUND and is the minimal change.
- Predicativity makes universe-quantifying defs climb: `iscontr : ∏(T:UU₀),UU₀` has type
  `UU_{max(1,1)} = UU₁`; `weq`, `isweq`, `hProp`, the hlevel tower follow to UU₁/UU₂…
- **Crucially, the exported predicative core stays at level 0.** `add`/`mul`/`natplus*`/… are
  `nat→…→nat` (UU₀). The path-algebra combinators (`idfun`, `maponpaths`, `pathscomp0`, …) have
  *types* in UU₁ but are *instantiated at UU₀* (applied to `nat`), which checks fine. So the
  whole uugen-exported fragment (74/250) type-checks at concrete level 0 — Stage 1 makes
  precisely the part we export SOUND, with no annotations.
- The univalence/hlevel tower may need explicit `(UU i)` bumps or get parked — acceptable,
  since it's exactly the part the export already skips.

**Stage 2 — universe polymorphism (later, for full UniMath).** Floating level variables +
a `≤`-constraint graph checked for acyclicity (Coq-style), so a lemma proved once is usable at
many levels. This is the bigger lift and is only needed to bring the *whole* corpus back green;
the predicative core doesn't need it.

### Cumulativity (optional within Stage 1)
`A : UUᵢ`, `i ≤ j` ⟹ `A : UUⱼ`. Implement as a subsumption case where `chk` meets a sort: in
the `chk` fallback (uu.l:158-159) when the expected `T = ('U j)` and inferred `Ti = ('U i)`,
accept `i ≤ j` instead of exact `conv`. Sound, and removes the need for manual lifts. Can be
deferred — exact levels are still sound, just less convenient.

## Change sites (all in test/uu.l)
- `vof`: add `UU`/`(UU i)` → `('U i)` (the one evaluator touch).
- `inf-sym` (113-114): `UU`→`('U 1)`, `(UU i)`→`('U (i+1))`, base inductives→`('U 0)`.
- `inf` formers (166-200): `pi`/`total2`/`coprod`/`paths`/`the` → infer component sorts, return
  `('U max)`. Add the `sortof` helper.
- recursor motive checks (206+): `(pi x nat UU)` → allow `(pi x nat (U i))`.
- drivers `defn`/`axm`/`defq` (264-289): `(chk 0 0 0 T 'UU)` → "`T` is a type" = `(sortof …)`
  succeeds (T inhabits *some* `('U i)`), not "T : UU₀".
- Flip `the_world_explodes` / `but_seriously_the_world_explodes` (and the type-in-type ordinal
  bits `whoa`/`irref` already blacklisted in uu2coq) from `defq` to `(rejects …)` negative tests.

## Landmark / test plan
- **The flip:** `(rejects (\ z (defn 'boom 'empty '(the_world_explodes empty)))) = 'rejected`
  (was provable). Girard's paradox needs `U:U`; with `UU₀:UU₁` it no longer type-checks.
- **No regression on the core:** the predicative corpus (nat arithmetic, path algebra) and
  `make test_uugen` (the 74 exports) stay green — Stage 1's whole point.
- New positive sort checks: `(defn 'u0type 'UU '(U 0))`-style — `(U 0) : (U 1)` accepted;
  `(rejects … (U 0) : (U 0))` rejected (no type-in-type).
- `tools/py/uu_parity.py`: names stay UniMath-compatible (`UU` kept, `(UU i)` is a local form).
- After Stage 1, uu2coq's universe-rescue note is no longer load-bearing for the exported
  fragment (uu's own kernel is sound there); the translator can keep mapping `('U i)`→`Type`
  (let Coq infer) or emit `Type@{i}`.

## Effort / risk
- Stage 1: ~6 functions + the drivers + flipping 2 defns. The evaluator/NbE is untouched. Main
  work is `sortof` + the four formers + getting `max`/large-elim right without breaking the
  level-0 core. Risk concentrated in: (a) recursor large-elimination levels, (b) the univalence
  tower needing UU₁+ (parked, not core). Bounded.
- Stage 2 (polymorphism): a real project — level vars, constraint graph, acyclicity. Only for
  full-corpus parity. Defer.

## LANDED (Stage 1, 2026-06-26) — `test/uu.l`, gate green

Realized as a **predicative checker beside** the type-in-type one (NOT an in-place flip), because
predicative concrete levels break UniMath's universe-*polymorphic* tower (most of uu.l). So the
sound checker verifies the predicative core; the tower stays parked in the old checker — exactly
the fragment uu2coq already skips. `pinf`/`pchk`/`sortof`/`cleq`/`predpi` share `vof`/`conv`
verbatim. Sorts: `UU0` = the symbol `UU`; `UU_i` (i≥1) = `('U i)`; `ulvl`/`umk` convert.

Verified by assert (placed BEFORE the negative-test window — see gotcha — so a false one scares
loudly; break-tested):
- `UU0 : UU1`, `nat : UU0` (the hierarchy).
- **Predicativity:** `sortof (pi T UU T) = 1` — `∏(T:UU),T` lives ONE level up, in UU1; `nat→nat`
  stays in UU0.
- The ported core laws (`uu-app` const_one / identity) check under `pchk`.
- **The keystone:** `(! (cleq 0 (pinf UU) UU))` — UU's type does NOT fit in UU0, so `UU : UU` is
  rejected (Girard can't form the fixpoint); `(cleq 0 (pinf UU) (U 1))` — but `UU : UU1` holds.

Scope of the parallel checker: the constructs the core + landmarks need (`pi`/`total2` formation,
`lam`, app-spine, `paths`/`idpath`, `the`/`let`/`succ`) + cumulativity. It does NOT re-implement the
full recursor suite (`nat_rect` etc.) — the core LAWS' proofs are `idpath`/lemma-application, not raw
recursors, so inference never needs them. `pdefn` checks-without-pinning (no GLOB pollution; uu2coq
ignores it).

Gotchas hit:
- `assert` (prel.l:517) scares on a false claim, but uu.l installs a scare-SWALLOWING help for its
  negative-test window (uu.l:~2335 → `(: help 0)`). A predicative `(assert …)` placed inside that
  window passes VACUOUSLY. Fix: place it before the window; express the rejection as a pure boolean
  `cleq` (not `rejects`, which needs that window's HELPC-delegating help).
- A silent reader-stop also exits 0 — confirm a section ran by probing a binding it defines AND by
  break-testing an assert (flip it, expect a `;; assert …` scare), not by exit code alone.

Still open for "make predicative the DEFAULT / retire type-in-type": Stage 2 universe polymorphism
(floating levels + acyclicity) to bring the univalence tower; and the full recursor large-elimination
rules if the predicative checker is to type the whole corpus.

## Why this is the right first expansion
It is the one change that alters uu's *kind* — from "a proof format sound only after export" to
"a consistent prover" — for the fragment we actually export, at bounded cost, while keeping the
export as the independent cross-check (de Bruijn criterion intact). See
`doc/archive/uu-rocq-bridge.md` for the bridge this sits under.
