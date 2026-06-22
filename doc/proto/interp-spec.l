; interp-spec.l -- the interpreter-specialization benchmark: does partial evaluation of an INTERPRETER
; pay off on this VM? (the real Futamura question -- the 1st projection specializes interp to a program.)
;
; ev1 is a tiny expression interpreter over an AST -- (lit n) (var) (add a b) (mul a b) -- that
; recurses on the tree and DISPATCHES on each node's head. the program P is the Horner form of
; 2x^3 + 3x^2 + 5x + 7; the residual a perfect specializer wants is the straight-line
;   (+ (* (+ (* (+ (* 2 x) 3) x) 5) x) 7).
; three loops of identical shape, only the inner expression differs:
;   interp -- ev1 over a DYNAMIC program (carried in via a param) => pure interpretation, no spec
;   pe     -- ev1 over the CONSTANT P inline => the in-compiler unfold (ai/ev.l feel/cprop) may specialize
;   hand   -- the straight-line residual => the ideal the specializer is chasing
;
; RESULT (host, 2026-06-22, 1e6 iters):
;   interp 550 ms | pe 576 ms | hand 84 ms
;   interpretation overhead interp/hand ~ 6.5x  -- THE PRIZE IS REAL AND LARGE
;   unfold capture     interp/pe   ~ 1.0x  -- the unfold captures NONE of it (pe ~= interp, a hair slower)
; WHY the unfold misses it: cprop folds the ARITHMETIC ops (opval = + - * ...) but NOT the structural
;   navigation (cap/cup/caup/cuup) or id?, so it cannot fold (caup P) to a constant sub-AST and drive
;   the recursion THROUGH the program; and cpcond was removed (wxc prunes downstream), so there is no
;   cprop-level dispatch pruning to follow only the live branch. it specializes ~one level, then
;   residualizes to full interpretation. CLOSING THE GAP (route #2) = add the structural ops to foldc
;   AND restore a CORRECT cpcond so the unfold folds the dispatch and recurses on constant sub-ASTs.
;   this benchmark is the yardstick for that work: pe should move from ~interp toward ~hand.
;
; run:  out/host/ai doc/proto/interp-spec.l
((\ pd
  (: (ev1 nd x) (? (id? (cap nd) 'lit) (caup nd)
                   (id? (cap nd) 'var) x
                   (id? (cap nd) 'add) (+ (ev1 (caup nd) x) (ev1 (cap (cuup nd)) x))
                   (id? (cap nd) 'mul) (* (ev1 (caup nd) x) (ev1 (cap (cuup nd)) x))
                   0)
     P '(add (mul (add (mul (add (mul (lit 2) (var)) (lit 3)) (var)) (lit 5)) (var)) (lit 7))
     N 1000000
     (interp z) ((: (lp i acc) (? (< i N) (lp (+ i 1) (+ acc (ev1 pd (% i 13)))) acc)) z 0)   ; dynamic program
     (pe z)     ((: (lp i acc) (? (< i N) (lp (+ i 1) (+ acc (ev1 P  (% i 13)))) acc)) z 0)   ; constant program
     (hand z)   ((: (lp i acc) (? (< i N) (: x (% i 13) (lp (+ i 1) (+ acc (+ (* (+ (* (+ (* 2 x) 3) x) 5) x) 7)))) acc)) z 0)
     ci (interp 0) cp (pe 0) ch (hand 0)
     _ (. (+ (+ "checksums: interp=" (show ci)) (+ (+ " pe=" (show cp)) (+ " hand=" (show ch))))) _ (. "\n")
     _ (. (? (&& (= ci cp) (= ci ch)) "all match\n" "MISMATCH\n"))
     a0 (clock 0) _ (interp 0) a1 (clock 0) _ (pe 0) a2 (clock 0) _ (hand 0) a3 (clock 0)
     ti (- a1 a0) tp (- a2 a1) th (- a3 a2)
     _ (. (+ "interp (dynamic program):     " (+ (show ti) " ms\n")))
     _ (. (+ "pe     (constant P, unfold):  " (+ (show tp) " ms\n")))
     _ (. (+ "hand   (ideal residual):      " (+ (show th) " ms\n")))
     _ (. (+ "interpretation overhead (interp/hand): x" (+ (show (// (* 100 ti) (+ 1 th))) "/100\n")))
     (. (+ "unfold capture          (interp/pe):   x" (+ (show (// (* 100 ti) (+ 1 tp))) "/100\n")))))
 '(add (mul (add (mul (add (mul (lit 2) (var)) (lit 3)) (var)) (lit 5)) (var)) (lit 7)))
