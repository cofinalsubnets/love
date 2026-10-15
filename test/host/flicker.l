; test/host/flicker.l -- src/apps/lore/flicker.l's brightness curves
; run: cat test/00-init.l test/host/flicker.l | out/love
(borrow 'flicker)

(: ts (map (i \ i * 0.05) ^4000)
   st (map (t \ flicker-stammer t 0) ts) st2 (map (t \ flicker-stammer t 1) ts)
   bl (map (t \ flicker-blink t 2.0 0.9 0.3) ts)
 (test (all (v \ 0.0 <= v <= 1.0) st) (100 < #(filter (v \ v < 0.5) st)) (3000 < #(filter (v \ v = 1.0) st)) (st != st2)
       (all (t \ 0.86 <= flicker-buzz t <= 1.0) ts) (any (t \ flicker-buzz t < 0.95) ts)
       (all (t \ 0.4 - 1e-12 <= flicker-pulse t 0.7 0.3 1.7 0.5 <= 1.0 + 1e-12) ts)
       (flicker-pulse 0.0 0.7 0.3 1.7 0.0 = 0.7)
       (all (v \ 0.0 <= v <= 1.0) bl) (flicker-blink 0.45 2.0 0.9 0.3 = 1.0) (flicker-blink 1.5 2.0 0.9 0.3 = 0.0)
       (flicker-blink 2.45 2.0 0.9 0.3 = 1.0) (flicker-blink 0.15 2.0 0.9 0.3 = 0.5)
       (all (t \ flicker-tv t 3 0.0 = 1.0) ts) (any (t \ flicker-tv t 3 1.0 < 0.8) ts) (all (t \ flicker-tv t 3 1.0 <= 1.25) ts)))
(test_fin ())
(puts "flicker: ok\n")
