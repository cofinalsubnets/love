# net & tally — the two measures, and monadic `*` = prod

A reading of the value space's algebra (user's framing, 2026-06-26), plus one pending
one-line change. The question that started it: *is monadic `*` the counterpart of monadic
`+` (net)?* The answer pulls apart two things CLAUDE.md had quietly fused.

## Two axes, and net sits on the crossing

There are **two** dualities here, not one, and `net` appears in both — which is what makes
it look like monadic `*` should mirror it.

- **Measures** — structure-preserving maps `value → scalar`, one per monoid:
  - **net** = the additive measure, the `+`-hom `(values, +) → (C, +)`. *weight* — "how much."
  - **tally** = the multiplicative measure, the semiring (rig) hom `(values, +, *) → (N, +, ·)`.
    *count* — "how many."
- **Folds** — the operation turned inward over a value's contents:
  - **net** = `foldl (+) 0`.
  - **prod** = `foldl (*) 1`.

`net` is in *both* lists because for `+` the fold **is** the hom (the free-monoid universal
property — same map, two readings). For `*` they **split**: the multiplicative fold is `prod`,
the multiplicative measure is `tally`, and they are **different maps**. So:

- monadic-`*`'s honest twin **by fold** is monadic-`+`: `prod ∥ net`.
- net's honest twin **by measure** is `tally` — **not** monadic-`*`.

`tally` is the multiplicative leg net structurally lacks.

## The verified laws

Probed against the host binary:

| form | value | reading |
|---|---|---|
| `+'(1 2 3 4)` | `10` | net — fold `+`, seed 0 |
| `*'(1 2 3 4)` | `24` | prod — fold `*`, seed 1 |
| `net(a*b)` on `'(2 3) '(4 5)` | `28` | …but `net a · net b = 45` |
| `tally(a+b)` | `4` | `= tally a + tally b` |
| `tally(a*b)` | `4` | `= tally a · tally b` (= 2·2) |
| `tally(xs*n)` on `'(2 3) 3` | `6` | `= tally xs · n` |
| `tally 7` | `0` | tally is cardinality, not weight |

$$\nu(a+b)=\nu a+\nu b,\quad \nu(a*b)\neq\nu a\cdot\nu b \qquad\quad \tau(a+b)=\tau a+\tau b,\quad \tau(a*b)=\tau a\cdot\tau b$$

So **net is a `+`-monoid hom only** (blind to `*`); **tally is the full semiring hom**. That is
the precise sense in which tally is net's twin.

## The cartesian/repeat `*` is the *founded* part

The value space is a genuine **semiring**: `+` = append/concat, `*` = cartesian product, the
shared unit `()` projecting to both `0` and `1`, right-distributive (`(a+b)*c = a*c + b*c`,
exact). `tally` is its rig hom — and it *unifies the lanes*: the **repeat** lane
(`tally(xs*n) = tally xs · n`, the ℕ-action / "`*` is repeated `+`") and the **cartesian** lane
(`tally(xs*ys) = tally xs · tally ys`) are **one law** under tally, since `n` is just the tally
of an n-thing. So cartesian/repeat `*` is not ad hoc — it's the product and module-action faces
of one semiring multiplication, with tally the witness. (`str*str = nil` / `sym*sym = nil` are a
closure issue — the product would type-escape the string kind — defensible.)

## The ad-hoc part: `jot` on the `*` sigil

The only unfounded bit is `jot`. Its body is a rank pun:

```lisp
(jot x) (? (star? x) <0..x-1>      ; iota — a CONSTRUCTOR (scalar)
            (prod x))               ; prod — a FOLD (aggregate)
```

Two unrelated operations welded under one glyph and bound to `*` in `monadics`, dispatched by
rank — iota on scalars, prod on aggregates. They share the slot only because prod-of-a-scalar is
vacuously the scalar (so `*5` "had room" for iota). And it *breaks* a symmetry every other
`monadics` entry keeps: `+5 = 5` (vacuous net), but today `*5 = (0 1 2 3 4)` instead of the
vacuous `5`.

`jot`/`iota` is really the **section of tally** — `tally (jot n) = n` — the canonical witness
builder for a count, a *constructor*, the right-inverse of the measure. A third role, distinct
from both fold and measure; it earns its own name rather than squatting on `*`.

## The decision

1. **Monadic `*` = `prod`, uniformly.** `*x` is `*` turned inward, the multiplicative fold:
   aggregate → product of cells, scalar → itself (vacuous, so `*5 = 5`) — the rank-uniform dual
   of `+x`, exactly as `+5 = 5`.
2. **`tally` is net's documented measure-twin** — the cardinality rig-hom, with both hom laws.
   The trinity: **net** (weight, `+`-hom) · **tally** (count, rig-hom) · **prod** (the `*`-fold,
   an operator, neither measure).
3. **`jot`/`iota` retired to named range constructors** — the section of tally, off the `*` glyph.

Rejected alternative: bind `*` → `tally` so the operator literally *is* the measure-twin. But
`tally` is not "`*` folded inward" — it would break the one invariant every `monadics` entry
honors (sigil = its dyadic op, monadic). `prod` keeps that invariant; `tally` stays a named word.

## Pending implementation (the doc leads the binary here)

The grep proved the surface is tiny — glued `*<scalar>`-as-iota lives **only** in
`test/valence.l`; `(jot n)` the named word is used everywhere and stays.

1. `ai/prel.l:267` — flip the `monadics` table cell: `(L '* 'jot)` → `(L '* 'prod)`.
   *(the whole semantic change)*
2. `ai/prel.l:195` — make `jot` range-only (drop the dead `(prod x)` else-branch; no call site
   passes `jot` a list):
   ```lisp
   (jot x) ((: (go i) (? (< i x) (link i (go (+ i 1))))) 0)   ; the range 0..x-1 (iota its array twin); the * fold is prod
   ```
3. `test/valence.l` — `((jot 7) = *7)` → `(7 = *7)` (line 18); `('(0 1 2 3 4) = (ev (\ *5)))`
   → `(5 = (ev (\ *5)))` (line 51). Line 50 `("*5" = (show (\ *5)))` should stay green (the
   printer re-glues the sigil, surface unchanged) — `make test` confirms.
4. `make test` (host + ai0, both reach `zz-fin`).

Until this lands, the **binary** still gives `*5 = (0 1 2 3 4)`; CLAUDE.md is kept truthful to
that (it still reads "(jot x) is the monadic `*`"). This doc holds the target and the rationale.
