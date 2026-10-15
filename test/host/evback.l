; test/host/evback.l -- ev's show, read and evaluated, is an ev that agrees with ev, for two
; generations; the bare interpreter too. unmopped, as ev closes over doors the mop drops:
;   cat test/00-init.l test/host/evback.l | LOVE_NO_IMAGE=1 LOVE_NO_MOP=1 out/love

(: forms ['5 '(+ 1 2) '(* 3 4) '(cap [7 8]) '((\ x (x + 1)) 4) '(map (+ 1) [1 2])
          '(: x 0 (? x 1 2)) '(: f (\ n (? n 1 2)) (f 0)) '(: (f n) (g n) (g n) (n + 1) (f 1))
          '(: (f n) (? n (n * f (n - 1)) 1) (f 5)) '(foldl (+) 0 (jot 10)) '(show (\ x (x * 2)))]
   (agree e) (all (x \ (e x = ev x)) forms)
   s0 (show ev)
   e1 (ev <(sound s0))
   e2 (ev <(sound (show e1)))
   b1 (ev <(sound (show (cite 'glaze 'base-ev))))
   b2 (ev <(sound (show b1)))
   (test (tally s0 < 200000) (has? s0 "(cite 'glaze ")   ; the glaze's own names, cited
         (agree e1) (agree e2) (agree b1) (agree b2),
    test_fin (),
    puts "evback: ok -- ev's show read back is an ev, and so is that one's; the interpreter's too\n",
    0))
