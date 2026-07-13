# open bug: const-list + recursive local + call, one `:` scope = compile/run hang

found 2026-07-13 grinding test/patch.l's tree-lift form; the fifth form's laws
hit it and the whole corpus run went from ~2s to forever (100% cpu, state R —
a compute loop, not a scare block; `ps` lifetime-%cpu lies early, read
/proc/PID/stat utime).

## the minimal repro (hangs, host binary, image or AI_NO_IMAGE)

```ai
(: (f s n) (? (< n 1) s (f (cup s) (- n 1)))
   zz '(aa bb cc dd)
   _ (f zz 1) 0)
```

## the fingerprint (all probed)

the hang needs ALL THREE in ONE body-having `:` scope:
  * a RECURSIVE local closure (non-recursive `(f s n) (link n s)`: fine)
  * a CONSTANT LIST binding (scalar `zz 5`: fine; the list inline at the call
    site with no binding: fine)
  * a CALL of the closure on that binding (defining both without the call:
    fine; even a ZERO-recursion call `(f zz 0)` hangs, so the loop is in a
    compile pass or a miscompiled entry, not the recursion itself)

dodges that prove the shape (and give the workaround):
  * launder the binding: `zz ((\ x x) '(aa bb cc dd))` — fine
  * rebuild it: `zz (mk '(aa bb cc dd))` with `(mk x) (link (cap x) (cup x))` — fine
  * leak instead: a body-LESS `:` binding zz + the call in the NEXT top-level
    form — fine (so the single-scope letrec path is the sick one)
  * route the constant through another fn's parameter first (how every green
    corpus form happens to do it — why the gate never caught this) — fine

NOT a regression of the current working tree: a clean-HEAD build reproduces.
suspects by shape: the pure-global/constant folding (wev) or kconst/monofix
meeting the boxfix single-scope letrec — a specializer chewing a constant list
into a recursive site and not converging.

test/patch.l's fifth form carries the workaround (a `warm` identity on its
quoted witnesses) + a pointer here; sweep it off when this is fixed.
