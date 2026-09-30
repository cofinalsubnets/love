; closure -- higher-order stress. `(2 (+ i))` is church-2 of the section (+ i), so applied to i it is
; 3i. the composition inlines, leaving a rolling-hash loop loopclose cannot collapse to a formula: a
; real 100000-iteration loop, glazed native. checksum = the hash.
(: hmod 1000000007
   (hof i acc) (i < 100000 ? (hof (i + 1) ((acc * 31 + (2 (+ i)) i) % hmod)) acc)
 (bench "closure" (_ \ hof 0 0)))
