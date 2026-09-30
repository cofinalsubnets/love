; test/host/deepeq.l -- `=` past the region it walks over: the worklist lives in the idle half of
; the minor two-space, a left spine costs two words a level, and past the gap `=` takes a region
; of its own and doubles until the walk fits. the nursery is pulled to its floor through (tune v)
; under a budget read off gauge[8], the live set, which is a whole-seat knob: not in the corpus.
; run: cat test/00-init.l test/host/deepeq.l | out/love

(: (spine n acc) (n < 1 ? acc (spine (n - 1) (. acc 1)))    ; a left spine: n levels of car
   knobs (tune [0 16384 65536 24])              ; the floor, the step, the ratio; budget open
   _ (please 1)                                  ; ..a major, so the count below is the live one
   live (peep (gauge 0) 8 0)                     ; words the major pool holds live
   ; appel hands the nursery (budget - 2*live)/4, so a budget at twice live leaves it
   ; nothing but its floor. derived and not a constant: the live set moves with the image
   _ (tune (pin (tune ()) 0 (2 * live)))
   _ (please 1)
   _ (please 1)
   gap (peep (gauge 0) 0 0)
   n (2 * gap)                                   ; 2n words of worklist over a gap of n
   a (spine n 0) b (spine n 0) c (spine n 1)
   answers [(a = b) (a = c) (elem b [c a]) (elem c [a])]
   (tune knobs,                                  ; the seat goes back before anything else runs
    test (gap <= 16384)                        ; the floor took: the walk is past the region
         (answers = [1 0 1 0]),
    test_fin (),
    puts "deepeq: ok -- a spine twice the gap deep, equal and unequal, `=` and `elem`",
    putc 10))
