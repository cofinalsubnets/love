# c0 under the ()-flip — bootstrap compiler notes

Working notes on the C bootstrap compiler (`c0`, in `ai.c`) and how the
`nil = (word)ai_core_of(g)` flip exposes bugs in it. `c0` only runs in `ai0`
(the bootstrap binary); the host runs the self-hosted `ev` (the egg). So a c0
bug shows up as a *silent ai0 self-test* and *empty `lcat` output* (which then
breaks `make host` when it regenerates `cli.h`/`ev.h`/`repl.h`) while the host
binary — built from a good egg — keeps working. Don't trust a working host as
proof c0 is fine; it may be running a stale/pre-flip egg.

## The core masquerades as a symbol (`mintp(()) == true`)

`()` is `(word)ai_core_of(g)` — a real pointer to the runtime struct. By design
(ai.h:98–103) the core's first word is `lvm_sym`, so `()` prints as `()` and
applies as const-1. But that means the storage predicates misfire:

- `lamp` is just `evenp` (ai.h:330); the core is word-aligned ⇒ `lamp(()) == true`.
- `mintp(_) = lamp(_) && cell(_)->ap == lvm_sym` ⇒ **`mintp(()) == true`**.
- `nomp(_) = mintp(_) || (chainp && strp(A) && mintp(B))` ⇒ **`nomp(()) == true`**,
  and also any `(string . ())` one-element list reads as a `(name . mint)` nom.

So every compiler predicate asking "is this a named symbol?" answers *yes* for
`()`. **Fix:** guard `mintp` against the core. It has no `g`, so thread one in:
`mintp(struct ai *g, word _) = lamp(_) && !nilp(_) && cell(_)->ap == lvm_sym`.
This cascades to `nomp`, `formp`, and the `symeq/hashsym/splicesym` and
`cmp_rank` helpers — all gain a `g` parameter (every caller already has `g` or
a `struct ai*` in scope, e.g. `lam_src1` uses `c`). NB the macro `nilp(_)` =
`word(_)==nil` needs `g` visible.

This guard is **necessary but not sufficient** — see below.

## The scope chain & the faked top scope

c0's env is `struct env` (ai.c:1133): `par, args, imps, stack, lams, len, …`.
It is GC-traced as a text (`tagtext`), so `evac_text` forwards every word incl.
`par` (the chain survives GC). A scope's fresh fields are set to `nil` (= `()`),
which is fine for list fields because `chainp(()) == false`.

The **top-level scope is faked**: `c0` (ai.c:1221) calls
`enscope(g, (struct env*)nil, nil, nil)` — `par = ()`. `ana_v`'s lookup walk
(ai.c:1403) terminates on `nilp(d)` (d == core). There is **no persistent
global scope object** on `struct ai`; `()` doubles as both the value floor and
the "no parent" sentinel. A persistent global-scope field would decouple them.

### symptom: a captured free local resolves flat

`ana_v` dump format used while debugging: `[a=<args> i=<imps> s=<stack> par=…]`
per scope, ending `()END`. A miscompiled capture shows the body's scope chain
*flattened* to a single top scope (`[a=0 i=0 s=1 par=()] ()END`) — the free
local isn't found, falls through to a global, and reads `()` at run time.

## UPDATE — the remaining blocker is a context-dependent c0 codegen bug

After the `mintp` guard, the go/op-* fall-throughs turned out to be RED HERRINGS:
the pre-flip build (`nil = putcharm(0)`) is green and has 64 identical `go`
fall-throughs (the harmless provisional closure-discovery pass). Capture and
recursion resolve correctly in the final pass.

The live blocker: **opfix (`op-core`) mangles a bare define-sugar `:`**. Minimal,
reproduced by dumping c0's opfix in/out on probe forms:

```
(: x 1 x)            -> (: x 1 x)        ✓  value binding
(: a (f x) a)        -> (: a (f x) a)    ✓  sublist as a VALUE
(: x 1 (f x))        -> (: x 1 (f x))    ✓  sublist as RESULT
(: (f x) x)          -> (f x)            ✗  define-sugar head, : + body DROPPED
(: (g i) i)          -> (g i)            ✗  (name-independent)
(: (f x) (h x))      -> (f x)            ✗
(: (f x) x 9)        -> (f x)            ✗
((: (g i) i) 0)      -> ((: (g i) i) 0)  ✓  SAME : but nested in an application
```

`op-core` is a pure source->source function, yet it returns different results for
the *same* input shape depending on call context (bare/shallow vs reached via
op-w recursion). A pure function that is context-sensitive == a **miscompilation**:
c0 emits code for `op-core`/`op-w` that reads a stale/uninitialized stack slot,
and the garbage differs by depth. Pre-flip the stale value was `putcharm(0)`
(harmless); post-flip `nil` is a `g`-expression so the slot holds something else.

NOT a tail-call bug: wrapping opfix as `(: (opfix x) (: _r (op-core x) _r))` (forcing
op-core non-tail) did not change the mangle.

Trigger path: a define-sugar binding head `(f x)` as the FIRST operand makes op-w
take its else branch `(op-del (op-core e) out pend)` — a nested op-core call —
right after the `:` operator branch (op-core prel.l ~387-407). That nested call
corrupts op-w's live locals (`out`/`pend`/`l`), so the accumulation collapses to
just the head. When the same `:` is reached one recursion deeper (the applied
case), the affected slot holds valid data and it works.

NEXT: instrument op-w's lisp execution (add a debug nif `(dbg x)` = print-skeleton
+ return x; splice into op-core's op-w/op-del in prel.l) to watch `out`/`pend`
across the nested op-core call; or read c0's emitted code for op-w around the
arg-eval of a non-tail call and find the slot that isn't preserved. The break is
in c0 (ai.c) codegen for a non-tail call inside a tail-recursive helper, surfaced
by `nil` no longer being `putcharm(0)`. Repro vehicle: the main.c `ANAV_DBG`
opfix probes (kept in the tree).

## (earlier) opfix/op-core mangles forms

`c0` runs the `opfix` prel pass on every form before compiling it (ai.c:1213).
`opfix = (op-core x)` — the operator factor pass (`prel.l` ~230–437), a big
letrec of mutually-capturing helpers (`op-w`, `op-del`, `op-steal`, `op-drain`,
`opfactor`, …). Instrumented dump of c0's opfix call on `s2cldef`:

```
in : (: (s2cl s) ((: (g i) (? (< i (tally s)) …)) 0))   ✓ correct input
out: (s2cl . (s . 0))                                    ✗ : / lambda / body gone
```

So opfix destroys the form, and since it runs on *every* form, the whole
bootstrap collapses. The host's self-hosted `ev` compiles the same `s2cl`
correctly (`(tally (s2cl "ab")) = 2`), so **op-core's prel logic is sound** —
the fault is c0 *miscompiling* op-core (specifically its letrec sibling-capture
/ closure construction) under the flip. The `mintp` guard is one facet of that
capture bug; there is at least one more.

## How to probe (decisive)

- ai0 ignores CLI args under no-arg invocation — `main`'s `boot()` runs only the
  baked self-test (`s2cldef` then `(zevs (sip (s2cl tests)))`). To trace a
  specific compile, set a flag in `main.c` around `ai_evals_(g, s2cldef)` and
  gate C `dprintf(2,…)` on it (ai.c has no stdio; declare `dprintf` locally).
- A value-skeleton dumper (chain → `(A . B)`, nomp → name, charm → number,
  core → `()`) printed at c0's opfix site (before/after) and in `ana_d`
  (before/after boxfix, plus `lambp` per binding) localizes the mangle to one
  pass.
- Build a debug ai0 with `make ai0 CC="cc -DANAV_DBG"` after
  `rm -f out/host/ai0 out/host/0/ai.o out/host/0/main.o`.

## Build-state hazard

A broken ai0 `lcat`s **empty** headers into `out/lib/*.h`, so `make host` then
fails (`cli.h` empty → `main.c` "expected expression"/`rel` undeclared). These
are gitignored build artifacts; they regenerate once ai0 works again.
