; a map/filter/fold LIST pipeline: sum the squares of the odd numbers in [0, N).
; written in the naive functional style -- (foldl + 0 (map sq (filter odd (jot N)))) -- which under a
; plain interpreter materializes THREE intermediate lists (the jot range, the filtered odds, the
; squares). the glaze's DEFORESTATION pass (ai/glaze/auto.l defoliate) fuses the whole pipeline into
; ONE native counted loop with NO intermediate allocation -- map substitutes the element, filter guards
; the step, foldl-over-jot lowers to the loop the group compiler natives -- so the cozy functional
; source runs as a hand-written loop would. the array-idiom counterpart is `mapfilter` (baked kernels);
; this is the LIST-pipeline idiom made fast by fusion, not by rewriting to arrays.
; checksum = sum_{odd k < 20000} k^2 = 1333333330000 (< 2^53, exact in every language).
;
; WHAT THE CROSS-LANGUAGE ROW MEASURES (read honestly): the abstraction cost of the functional-pipeline
; IDIOM, not a fixed algorithm. each language's number reflects how it handles the intermediates -- ai
; FUSES them (deforestation); lua/fennel have no map/filter so a hand loop fuses them by hand; python/
; clojure/hy are LAZY (no intermediate lists, per-element overhead); node/ruby/schemes allocate eagerly.
; the clean reading is the anchor: ai's deforested pipeline lands at luajit's HAND-WRITTEN loop -- i.e.
; the high-level functional source costs what the loop costs. (the purest deforestation A/B is ai with
; the glaze on vs off; we keep the glaze always-on for benches and watch the gate for regressions.)
(: (work n) (foldl (+) 0 (map (\ x (* x x)) (filter (\ x (= 1 (% x 2))) (jot n))))
 (bench "deforest" (\ _ (work 20000))))
