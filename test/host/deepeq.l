; --- test/host/deepeq.l: `=` past the region it walks over ---
; the pair worklist lives in the inactive half of the minor two-space -- scratch, usable
; only because nothing allocates while it is read. the values walked are not bounded by
; it: a left spine costs two words of worklist a level, so a spine twice the gap in levels
; wants twice the words the gap has. past that edge `=` takes a region of its own and
; doubles until the walk fits, so the answer is an answer.
;
;   cat test/00-init.l test/host/deepeq.l | out/love
;
; host-side and not a corpus member for its appetite: it pulls the nursery down to its
; floor, which is a whole-seat knob, and the corpus is one scope on one seat.
;
;   gauge[0]  len    the nursery in words, which is the region's size
;   (tune v)  the knobs: [0] budget [1] nursery floor [2] major step [3] ratio. a bounded
;             budget is what lets the floor bind -- unbounded, appel's rule hands the
;             nursery everything the major pool is not using. the budget is read off
;             gauge[8], the live set, so it holds as the image's weight moves

(: (spine n acc) (n < 1 ? acc (spine (n - 1) (. acc 1)))    ; a left spine: n levels of car
   knobs (tune @(0 16384 65536 24))              ; the floor, the step, the ratio; budget open
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
   _ (tune knobs)                                ; the seat goes back before anything else runs
   _ (test (gap <= 16384)                        ; the floor took: the walk is past the region
           (answers = [1 0 1 0]))
   _ (test_fin ())
   _ (puts "deepeq: ok -- a spine twice the gap deep, equal and unequal, `=` and `elem`")
 (putc 10))
