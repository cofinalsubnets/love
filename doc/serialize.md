# Brief: true code serialization

A closure IS its source `\`-expr + its captured values, all serializable, so `show`→reparse
round-trips **code**. Most languages can't serialize closures; ai can, structurally. Scope +
plan below. (Design doc, like galaxy-order.md / stream.md — not yet built.)

## Probed state (2026-06-19, host out/host/ai)

**The show side already works.** `(show (\ x (+ x 1)))` → `(\ d0 (+ d0 1))`; a capture renders as
a **leading application of the open lambda**: `(\ x (+ x n))` w/ n=5 → `((\ d0 d1 (+ d1 d0)) 5)`.

**Round-trip PROVEN** for closed terms + value captures, via
`rt = (\ v (ev (read (tap (map (show v) (jot (tally (show v))))) 'eof)))`:
- plain `((rt (\ x (+ x 10))) 5)` = 15 ✓ · capture (n=100) = 105 ✓ · nested = 12 ✓
- **`(= f (rt f))` = 1** — the reserialized closure is α+structurally EQUAL to the original ✓

**Mechanism** (mapped): a compiled lambda parks its source `\`-expr one cell before the entry
(`fn_src`, ai.c ~3023; set in ev.l `ala` via `(poke -1 s e)`, imports prepended as params). The
printer (`ioput_fn_body`, ai.c ~3106) walks the partial-app capture chain and emits
`(open-lambda cap…)`; bound vars get de Bruijn `d<n>` names (`lam_canon`, ai.c ~3078) so α-equal
closures print identically. `show` = prel.l:201.

## The three gaps

1. **Bare-mint identity (the core "new mint behavior").** A captured bare mint prints `$<serial>`
   which does NOT reparse (gensym identity lost). NAMED noms serialize fine (interned, `'x`
   reparses — KNom). **Recommended design (scoping agent): Option (a) slot-rename** — within a
   serialized closure, dedup distinct captured mints to positional slots `%n`; reparse mints
   them fresh-but-consistent, preserving WITHIN-closure relative identity. Zero collision with
   the live serial stream, GC-transparent, medium cost (printer dedup pass + reader `%n` in
   closure context). Rejected: (b) reader form at a literal serial — collides with the live
   stream, breaks GC monotonicity. (c) content-table — heavier, only buys cross-closure identity
   (not needed; runs are independent).
2. **Free vars resolve at ev-time against the book.** A free reference round-trips iff it's a book
   GLOBAL; a `:`-LOCAL free var (e.g. self-recursion via a let-bound name) becomes missing →
   const-1 on reparse (probed: `rt` of a `:`-local `fac` gives 5 not 120). Expected (the shown
   form is source; free vars bind late). For full fidelity, a self-recursive closure must either
   be a global or capture its own recursion knot as a value.
3. **The `:` even-form trap.** `(: x 1 (a) (b))` parses `(a)`/`(b)` as a binding PAIR (`(a)←(b)`,
   define-sugar), NOT two body effects — silent swallow. Bit every probe in this session.
   Mitigation today: use `_` bindings for effects, or wrap the intended body as ONE form. A
   usability guard (warn when a binding target is a non-name applied form with no body) is a
   candidate workstream — but `:` pairs-then-body is load-bearing, so investigate, don't rush.

**Read-back note:** `(read (tap <bytes>) 'eof)` reads compound forms fine (`(+ 3 4)` → `(+ 3 4)`);
`sip` was the wrong constructor in my early probes. One agent flagged a possible read-then-output
hang under two consecutive reads in one `:` block — likely the `:` trap again; verify before
treating as a bug.

## Concurrency plan

| # | Workstream | Territory | Concurrent? |
|---|---|---|---|
| A | **mint slot-serialization** (gap 1, Option a) | core: ai.c printer+reader | **critical path / blocker** (core thread = this session) |
| B | `:`-trap guard investigation (gap 3) | core: ev.l/reader (`wev`/`:` analysis) | independent of A — concurrent |
| C | read-then-output hang verify + string→form idiom (read-back) | core/prel: read/port | independent — concurrent |
| D | closure-show edge audit (maps/casks/recursion knots, free-var policy doc) | read-only probe | independent — concurrent (done-ish above) |
| E | freeze/thaw API + a `test/serialize.l` corpus | prel + test | **after A** (needs the mint form) |
| F | apps-as-programs: ship bao/ain/cook/kship as program values | per-app crew territory | **after A–E**; then fans out per-app (non-overlapping → concurrent) |
| G | doc remark: `theory.html` function-equivalence (closure = source+captures, comparable AND serializable) | theory.html | draftable now, finalize after A |

Concurrency: **A is the blocker**; B, C, D, G-draft run concurrently now (distinct code paths /
read-only / docs). E waits on A. F fans out per-app once A–E land (the egg already proves the
idea — it serializes the whole corpus into a heap image). Relates: the egg, `theory.html` (function equivalence).

## Spec note — limit/colimit constructions over the mint-NNO (NOT to build; specification only)

User's question: can gems/twins be represented as **limit constructions over mints**, and might
that construction be the **string monoid**?

- **Mint = the NNO (ℕ).** Zero point + successor (the serial stream). The initial algebra of
  `X ↦ 1 + X` — a **colimit** (ω-colimit). This is the seed.
- **ℤ, ℚ = colimits** over ℕ (group completion, localization).
- **Gem (ℝ) = the metric/order completion of ℚ — a LIMIT** (Cauchy/Dedekind: a limit of finite
  approximations). This is the user's "limit construction over mints."
- **Twin (ℂ) = ℝ × ℝ — a binary PRODUCT, the canonical limit.** `~` IS the product pairing,
  `re`/`im` the two projections — literally the limit cone. (Algebraically ℝ[X]/(X²+1), a colimit
  on the *algebra* side; as the value *space* it's the product.)
- **String monoid = Σ\* (free monoid on bytes) = a COLIMIT** (free functor, left adjoint;
  Σ\* = ⊔ₙ Σⁿ). So it is **NOT** the same as the gem/twin construction — it's the **dual pole**:
  numbers are the *limit/completion* side, strings/lists the *free/colimit* side.

**Answer:** gems & twins are **limits** (completion + product); the string monoid is the dual
**colimit** (free). They are two poles of one adjunction over the mint-NNO, **joined by the net**:
strings net *up* into ℕ (the charm-sum homomorphism), the value-built kinds net *down* — exactly
the "**charm as hinge**" of `theory.html` (lattice & order). So the appealing unity is real and already latent there:
one universal machinery over the mint-seed, read as *free* (→ strings/lists) and as
*complete/product* (→ gems/twins), with the net the functor between them. The twin specifically
IS a limit (its `re`/`im` are a literal projection cone) — the cleanest "limit over mints" in the
surface. Candidate as a `theory.html` constellations (numeric tower) aside or a new §spec note; specification only.
