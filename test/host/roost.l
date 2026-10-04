; test/host/roost.l -- the nest as a floor (src/apps/lore/roost.l), headless
; the plan is spelled here as src/apps/source.l's nest-plan lays one, so nothing touches a
; home: the opening sign, the perch asked both ways and by a tap, a shelf turned, the door stayed at
; and then taken, and a frame that paints the room.
;
; run:  cat test/00-init.l test/host/roost.l | out/love
(borrow 'roost)
(borrow 'rove)

(: pl {'mine 1790542482 'theirs 1790000000 'verdict 'older 'lay 'lay
       'tools [{'nm "lush" 'was "" 'act 'link}
               {'nm "cook" 'was "/src/apps/cook.l" 'act 'link}
               {'nm "kore" 'was "love" 'act 'keep}]}
   g (roost-new 80 22 pl)
   d (g 'd) p (g 'p)
   ; a step onto (x y) from the cell below it: stand there, then press k
   (bump x y k) (pins p 'x x 'y (y + 1), roost-turn g k)
   _ (test (two? (g 'sign)))                               ; the opening sign stands
   _ (test (string? <(g 'sign)))                           ; ..under user@host, or the nest
   _ (roost-turn g 32)
   _ (test !(g 'sign))                                     ; ..and any key takes it down
   pc (d 'perch)
   _ (bump <pc <>pc 107)
   _ (test (g 'ask = 'perch))                              ; the perch asks
   _ (roost-turn g 50)
   _ (test (pl 'lay = 'keep) !(g 'ask))                    ; 2: leave it as it is
   _ (bump <pc <>pc 107)
   _ (roost-turn g 49)
   _ (test (pl 'lay = 'lay))                               ; 1: lay this build
   ; a tap on a choice is its digit, and off the box it answers nothing
   _ (bump <pc <>pc 107)
   ls >(g 'sign)
   (tap-at i) (: (go y) (y > 40 ? -1 (i = sign-line <(g 'sign) ls 1 (d 'rows) (d 'cols) y ? y (go (y + 1)))) (go 0))
   _ (roost-turn g (tap-key g [0 0]))
   _ (test (g 'ask = 'perch))                              ; off the box: still asked
   _ (roost-turn g (tap-key g [40 (tap-at (#ls - 1))]))
   _ (test (pl 'lay = 'keep) !(g 'ask))                    ; the tap on leave
   _ (bump <pc <>pc 107)
   _ (roost-turn g 49)
   ; the shelves, in the tools' order: cook's is the second
   xs (sort (keys (d 'shelves)))
   sy (: (row y) (5 = peep (d 't) (xs 1 + d 'w * y) 0 ? y (row (y + 1))) (row 0))
   _ (bump (xs 1) sy 107)
   _ (test (pl 'tools 1 'act = 'keep))                     ; cook's link turned off
   _ (bump (xs 2) sy 107)
   _ (test (pl 'tools 2 'act = 'keep))                     ; kore is love's already: no change
   _ (bump (xs 1) sy 107)
   _ (test (pl 'tools 1 'act = 'link))                     ; ..and cook's back on
   dr (d 'door)
   _ (pins p 'x <dr 'y (<>dr - 1))
   _ (roost-turn g 106)
   _ (test (g 'ask = 'door))                               ; the door asks
   _ (roost-turn g 51)
   _ (test !(g 'over) !(g 'ask))                           ; 3: stay
   _ (roost-turn g 106)
   _ (roost-turn g 49)
   _ (test (g 'over = 'apply))                             ; 1: do it
   f (roost-frame g)
   (test (string? f) (0 < #f),
    test_fin (),
    puts "src/apps/lore/roost: ok -- the nest's floor (the perch, the shelves, the door)\n"))
