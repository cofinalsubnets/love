; spec-glaze -- an internal perf check for autospec, not a cross-language bench, so it is off the
; default BENCHES: `make -C bench BENCHES=spec-glaze` (love only).
; a tree-walking interpreter ev1 over a fixed AST P (Horner form of 2x^3+3x^2+5x+7), summing
; P(i mod 97) mod 1e9+7 over i < N. autospec (src/love/boot/glaze.l) applies ev1 to the static P at
; compile time, so the dispatch folds to native arithmetic; the modulus keeps it in int64.
; checksum = sum_{i<N} P(i mod 97) mod 1000000007, N=10^6.
(: (ev1 nd x) (? (<nd == 'lit) (caup nd)  (<nd == 'var) x
                 (<nd == 'add) (ev1 (caup nd) x + ev1 (cap (cuup nd)) x)
                 (<nd == 'mul) (ev1 (caup nd) x * ev1 (cap (cuup nd)) x)  0)
   P '(add (mul (add (mul (add (mul (lit 2) (var)) (lit 3)) (var)) (lit 5)) (var)) (lit 7))
   (run n) ((: (go i a) (i < n ? (go (i + 1) ((a + ev1 P (i % 97)) % 1000000007)) a)) 0 0)
   (bench "spec-glaze" (_ \ run 1000000)))
