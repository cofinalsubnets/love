# wev — the weak evaluator

`peval/wev.l` is a **partial evaluator written in ai**: feed it a function and
*some* of its inputs, and it hands back a smaller function — the residual program,
with everything statically known already computed. The pitch, like telescope's, is
**ai already ships most of it.** The compiler's own prepass (`ev.l`'s `wev`) is a
partial evaluator in miniature: it folds a pure global application whose arguments
are all constant (`(+ 1 2)` → `3`), inlines a matching nif, and — in `aco` — drops a
cond branch whose test folds to a constant. That is *constant folding*: the
all-or-nothing corner of partial evaluation, where **every** argument must be known.
wev-the-crew lifts that machinery out and generalizes it to the full **mix** —
specialize on input that is only *partially* known — and follows the road that opens
up: the **Futamura projections**.

(wev is weak the way weak-head-normal-form is weak: it reduces what it can see and
stops honestly at what it cannot. zev hunts a string into a tree; wev reduces a tree
into a smaller tree. Both were lifted from the same place — the compiler's own gut,
zev from cook's embedded parser block, wev from `ev`'s prepass — so they are
litter-mates, not lovers.)

## Agent brief — you are the wev thread

You build wev, in parallel with the aineko / bao / cook / kship / siri / telescope /
zev threads. Like cook and zev you are **pure ai over the core** — no host nif, no
entry change, no core change — so you have the lightest coupling and move without
waiting on anyone. wev is a **source → source** transform: it eats ai forms and emits
ai forms (it does *not* emit bytecode — that boundary is the compiler's, and it stays
the compiler's). Your one hard constraint is the corpus: wev rides the **global
concatenated scope** `make test` runs, so it may leak **exactly one** global.

- **Your territory (you own these):** `peval/wev.l` (the library), `test/wev.l` (the
  gate — a normal corpus test), `doc/wev.3` (a man page; section **3**, it is a
  library, not a CLI). The `peval/` dir is yours, new, mirroring `parse/` and `cook/`.
- **Read-only for you:** `ai/ev.l` (the reference — `ev.l:15-56` is `wevs`, the
  value→ap fold memo, and `ev.l:129-175` is the `wev` prepass you are generalizing;
  `cval`/`hgen`/`opof`/the curated `names`/`pureset` are the parts you lift), `ai.h`,
  `CLAUDE.md` (the bootstrapping + reader-operators sections are your spec), and the
  prel names wev leans on (`map` `foldl` `cat` `link` `cap`/`cup` `atom?` `nom?`
  `two?` `assq` `memq` …). Probe them at the binary; a vocab rename in the corpus
  surfaces as wev going mass-red.
- **DO NOT EDIT `ai.c` / `ai.h` / `main.c`** or other threads' files (`host/*.c`,
  `cook/cook.l`, `parse/zev.l`, `tools/aineko.l`, `ai/bao.l`, `telescope/`,
  `port/kship/`). wev needs **no core change** — if you think you do, you have
  reinvented something the prel already has; ask the core thread (the main session).
- **`ai/ev.l` is CORE territory.** wev is *born from* `ev`'s prepass but does not edit
  it. Phase 4 (offering the generalized fold back to the compiler) touches `ev.l` —
  that is the **core thread's** call; propose the diff, never land it from this session.

## ★ The free name — wev is already mopped

zev had to fight for its single global (`parse`/`span`/`sat` all collide with egg
globals). wev gets its name **for free**, and the reason is the spec itself: the
compiler's `wev` is a closure-private binding inside `ev` (`ev.l:129`, never a book
key), and its `wevs` table is a global the **egg mops before birth** (the
compiler-machinery mop list — `boxfix`, `wev`/`wevs`, the num-ap helpers). So at the
surface, post-birth, **`wev` names nothing** — `(book 'wev)` is the zero point. The
crew member claims it with zero collision, by construction. One book key (`wev`), every
internal closure-private, the same trick bao and zev use. (Confirm at the binary with
`(id? wev ())` — TRUE, i.e. `wev` reads as the zero point, the face of a missing name;
`book` itself is mopped too, so even `(book 'wev)` is the zero-point-as-const-1. Do NOT
probe with `(lit? wev)`: the zero point is itself a `lit?`, so that can't tell missing
from present. If `(id? wev ())` ever goes false, the mop list drifted — tell siri.)

## The model — the mix, and the weak discipline

A partial evaluator is one function:

```
(mix f env)   ; env = a tablet of {name -> known value}; result = a residual fn
```

`(mix f env)` returns a new function that, given the *rest* of `f`'s inputs, computes
what `f` would — but with every subterm that `env` makes closed already reduced away.
With `env` empty it is the identity (nothing is known, nothing folds); with `env`
total it is just `(f known-args)` (everything is known, it runs to a value). The
compiler's `wev` is the **empty-then-constant** slice of this: it only ever folds the
subterms that are *already* closed, because at compile time it has no `env`. wev-the-
crew adds the `env`.

The reductions, lifted and then generalized from `ev.l`:

- **fold** (have it): a pure global applied to all-constant args → its value. `cval`
  (`ev.l:18`) decides "is this source a constant, and what is it"; `hgen` (`ev.l:28`)
  walks the args and applies the function when they are all constant + pure. *Generalize:*
  a name bound in `env` is now a constant too.
- **propagate** (new): substitute an `env` binding at its references (copy propagation),
  so a parameter known to be `3` turns `(+ x 1)` into `4`.
- **prune** (have it, in `aco`): a `?` whose test folds to a constant picks its branch
  outright, dropping the dead one — the compiler does this for closed tests; with `env`
  it fires far more often. The `(? !e a b)` → `(? e b a)` flip wev already does
  (`CLAUDE.md`, the wev bullet) rides along.
- **unfold** (new, the dangerous one): a *known* lambda applied to args is beta-reduced
  inline. This is what turns an interpreter's dispatch loop into straight-line code —
  and what can loop forever, so it lives behind the discipline below.

**The weak discipline is the whole safety story.** wev is *weak* — it reduces redexes
but **does not reduce under a binder whose value it does not know**, and it folds
**only pure operations**. ai hands you the safe-set already curated: `ev.l:38-46`'s
`names`/`pureset` is exactly "the globals it is sound to run at transform time"
(arithmetic, comparison, the pure list/string/complex/transcendental ops). Do not
widen it without proof — folding an impure or input-dependent op is silently wrong.
ai's totality *helps* here: `(/ 0 0)` is `0`, a type error is `nil`, so a fold never
faults where the runtime wouldn't. Lean on that; do not exploit it past `names`.

## Roadmap

1. **Lift (parity).** Move the fold core (`cval`, `hgen`, `opof`, the `names`/`pureset`
   safe-set) out of `ev.l` into `peval/wev.l` behind the single global `wev`. Prove
   parity by re-deriving the compiler's *own* folds as a library call:
   `(mix '(+ 1 2) ())` ⇒ `3`, `(mix '(cap (\ (1 2 3))) ())` ⇒ `1` — the same folds
   `ev` bakes, now callable on arbitrary source. No `env`, no new behavior yet.
2. **The mix.** Add the `env`: copy-propagation, fold-with-known-names, branch-prune
   when a test closes, and guarded **unfold** of statically-applied lambdas. Bound
   unfolding with a **fuel cap** — mirror `apcap` exactly (ai's own "don't run O(k) on a
   runaway count" instinct; a runaway unfold raises `(scare 'wevcap k)` rather than
   looping). Termination and code-blowup are the two failure modes (see Risks); fuel is
   the answer to both, generalization (don't unfold under unknown control) the refinement.
3. **The Futamura projections (the payoff).** ai is the rare substrate where `ev` is
   *itself* ordinary ai source, so the projections are literal expressions, not theory:
   - **1st** — `(mix interp src)` is a **compiler**: specialize a tiny ai interpreter
     (a stack machine, or a string matcher) to a fixed program and show the dispatch
     overhead is *gone* from the residual — measured faster with `(clock 0)` / `(gauge 0)`.
   - **2nd** — `(mix mix interp)` is a **compiler generator**.
   - **3rd** — `(mix mix mix)` is a **compiler-generator generator**.
   Even reaching the 1st projection on a toy interpreter is the headline demo: *a
   partial evaluator, in the language, specializing the language's own interpreters.*
4. **Adopt (the proof of reuse), with the core thread.** The strongest tie-back: offer
   wev's generalized fold to the compiler — could `ev`'s inline prepass *call the
   library* instead of carrying its own copy? That edits `ev.l` (CORE), so **coordinate**
   — propose it, hand the diff to the core thread, never land it here. Lighter, friendly-
   territory demos: specialize a telescope hot loop, or a cook recipe, to a constant shape.

## Gate

wev is pure ai with no host nif, so it gets a **normal corpus test**: drop the asserts
in `test/wev.l` and `make test` covers it (host + ai0 ×2) with **no Makefile edit** —
the corpus globs `test/*.l` and runs them concatenated in one global scope. That scope
is exactly why the single-global design holds: leak a colliding name and the gate goes
red and tells you. Keep every helper local; the only name `test/wev.l` may add to the
global book is `wev` itself. The rocq spec, the order law, and `make valg` are unaffected
by a pure-library addition — but run host + ai0 before every handoff, and a fold that
changes a value is a soundness bug, not a perf nit: every reduction must preserve meaning,
asserted both ways (`(mix src env)` applied = `src` applied).

## Risks

- **Soundness of folding.** Fold only the curated pure set (`ev.l`'s `names`). A fold
  that crosses an effect or an input-dependent op is silently wrong — the most dangerous
  bug a partial evaluator has, because the residual still *runs*, just wrong. Assert
  every fold against running the original.
- **Termination.** Unfolding a recursive call whose arg looks "known enough" can loop
  forever. The weak discipline (no reduction under unknown control) plus a fuel cap
  (`wevcap`, mirroring `apcap`) is the guard. A partial evaluator that hangs the
  corpus is worse than one that folds less.
- **Code blowup.** Aggressive unfold/inline explodes the residual. Ship conservative
  (fold + propagate + prune; unfold only obviously-bounded applications) and add
  generalization later — small and correct beats clever and exponential.
- **Corpus collision.** One global only. `wev` is free because the compiler's is
  closure-private + mopped (above) — keep it that way; never re-export an internal.
- **Don't redesign the compiler.** `ev`'s `wev` emits `iop`/`apx` nodes for the threaded
  backend and carries the natjit hook — that is *backend* concern. wev-the-library is a
  source→source transform producing plain ai source. Keep the boundary clean: you
  generalize the *fold*, not the codegen.
