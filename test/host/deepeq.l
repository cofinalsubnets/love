; test/host/deepeq.l -- `=` on a spine deeper than the minor gap its worklist borrows, so it
; takes a region of its own. host-side: (tune v) pulls the nursery to its floor for the whole image.
; run: cat test/00-init.l test/host/deepeq.l | out/love

(: (spine n acc) (n < 1 ? acc (spine (n - 1) (. acc 1)))    ; a left spine: n levels of car
   knobs (tune [0 16384 65536 24])              ; the floor, the step, the ratio; budget open
   _ (please 1)                                  ; ..a major, so the count below is the live one
   live (peep (gauge 0) 8 0)                     ; words the major pool holds live
   ; nursery gets (budget - 2*live)/4: twice live leaves only its floor
   _ (tune (pin (tune ()) 0 (2 * live)))
   _ (please 1)
   _ (please 1)
   gap (peep (gauge 0) 0 0)
   n (2 * gap)                                   ; 2n words of worklist over a gap of n
   a (spine n 0) b (spine n 0) c (spine n 1)
   answers [(a = b) (a = c) (elem b [c a]) (elem c [a])]
   (tune knobs,                                  ; restore before anything else runs
    test (gap <= 16384)                        ; the floor took: the walk is past the region
         (answers = [1 0 1 0]),
    test_fin (),
    puts "deepeq: ok -- a spine twice the gap deep, equal and unequal, `=` and `elem`",
    putc 10))
