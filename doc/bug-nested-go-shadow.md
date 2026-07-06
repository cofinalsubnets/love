# bug: nested define shadowing a sibling nom miscompiles the recursion (ROOT-CAUSED)

found 2026-07-06 building `au rm -r` (crew/utils/fs.l); root-caused 2026-07-06 in
ev.l's `ale` (the let analyzer). CORE territory. delete this file when the fix
lands (lessons to memory, per the house rule).

## the symptom

a self-recursive lambda (`zap`) whose body opens a nested `:` with a loop named
like a LATER sibling (`go`/`go`) compiles so that every recursive `(zap x)`
INSIDE its own body answers a truthy under-saturated PARTIAL without running the
body -- no effect, no scare. outer callers of zap work; only the self-sites are
short. in rm -r: the tree walk silently skips every child, rmdir answers
ENOTEMPTY.

## the minimal repro (pure -- no fs, no nifs; 12 lines)

```lisp
(: r? (cap (L 1))
   (zap q)
    (? (two? q)
       (: (go m) (? (! (two? m)) 1
                    (: k (zap (cap m))
                       _ (say err (? k "BUG" "ok")) _ (put err 10)
                       (go (cup m))))
          (go q))
       ())
   (go a) (? r? (zap a) 0)
   (go (L 5)))
```

prints BUG (k is a truthy closure; zap's body never ran). rename either `go` ->
ok. make `r?` a literal -> ok (cprop folds the read away, the sibling carries no
import). the fs effects in the original report were a red herring -- the old
"pure transliteration passes" discriminator had dropped the inner loop's
self-recursion, which is load-bearing.

## the necessary ingredients (each probed)

1. `zap` recurses on itself from inside a nested `:` (an inner loop).
2. the inner loop's nom collides with a SIBLING lambda of the enclosing `:`.
3. that sibling carries >= 1 import zap doesn't (a computed pin it reads, an
   enclosing lambda's param -- anything; a folded literal carries none).
4. the inner loop SELF-RECURSES (drop `(go (cup m))` and it heals).

the operand shortfall EQUALS the sibling's import count: with one flag import,
`(k x)` fires zap's body; with two (`(? r? (? f? (zap a) 0) 0)`), `(k x y)`
fires -- probed both ways, exact.

## the mechanism (ev.l, `ale`)

`ale` compiles a `:` in three phases (collect / closures / wire). the letrec
lambdas live in cells; a reference to one compiles via `lz`: quote the entry (or
a backpatch site) then APPLY IT TO ITS IMPORTS, read from the cell at the ref
site (`(apl2r c (cup (cof lfd)))`). the import sets are fixpointed by `fixcaps`
(pour: "k2 references k1 -> pour k1's imports into k2", detected by k1's NOM in
k2's first-build import list), then `wire`/`weave` re-analyzes each lambda with
its final imports and cputs the rebuilt closure.

the chain, step by step:

1. **the self-ref escapes its scope.** the inner `:`'s own 'lam map is pinned by
   its WIRE phase, so during its CLOSURES phase the inner loop's self-reference
   walks the scope chain unshadowed.
2. **first build: the evidence is eaten.** at outer-split time the outer 'lam is
   also unpinned, so the escape lands at book-miss -> a spurious self-nom import
   on the inner closure -- which the inner fixcaps' `dropj` deletes (it matches
   an inner lam name). net: zap's first-build import list never mentions `go`,
   so the outer `pass1` never learns "zap references sibling go" and never
   pre-pours go's imports into zap. (this is why fixcaps -- which exists to
   pre-seed exactly these imports -- misses.)
3. **weave: the poison arrives late.** the outer wire pins the outer 'lam FIRST,
   then weave re-analyzes zap. now the inner closures phase's escaping self-ref
   FINDS the outer sibling `go` in 'lam -> `lz` applies go's imports (`r?`) at
   the site -> resolving those names climbs them into zap's OWN import list,
   mid-analysis.
4. **the self-sites are already short.** zap's recursive self-references inside
   the body compiled via `lz` against zap's cell import list -- still the
   pre-growth `()` -- so they apply zero imports. `ala` then stamps the entry
   with arity = params + GROWN imports, and weave cputs the grown list.
5. runtime: outer sites (woven after the cput) apply the full import row and
   saturate; every self-site feeds the arity-(1+n) entry one operand -> a
   partial -- truthy, effect-free, silent.

corollaries, all probed: the final code's inner self-call targets the INNER go
correctly (the leak injects imports, never miswires the jump); a value alias
pinned after zap (`tz zap`) reads the post-cput cell and works -- routing the
recursion through it is a second workaround beside distinct noms.

## the two candidate seams for a fix

* **(A) shadow the inner 'lam during closures** -- the trigger. the inner let's
  binding names are known at collect time; the closures-phase scope walk should
  treat them as shadowing (e.g. pin 'lam early with the empty cells, or carry a
  shadow set), so an inner-bound nom can never resolve to an enclosing sibling.
  kills this bug at the source and fixes the scope violation itself.
* **(B) close the import-growth seam** -- the hardening. weave assumes ala with
  a given import set won't grow it; `lz` reads `cup (cof cell)` before growth.
  either re-run weave to an import fixpoint when the list grew, or make lz's
  import application read through the cell at BACKPATCH time (sites already
  defer the entry; the import row could defer the same way).

(A) is the true fix; (B) is worth considering because ANY future mid-analysis
import growth would bite the same way.

## until fixed

give nested loops distinct noms in tool code (fs.l's zap walks `ent`, never
`go`).
