; test/host/gcbudget.l -- under a budget a nursery that grows stays in the room past live, however
; much major pool stands free. host-side: (tune v) moves the budget for the whole image.
; run: cat test/00-init.l test/host/00-host.l test/host/gcbudget.l | out/love

(: was (tune ())
   floor 16384
   _ (tune [0 floor 65536 4096])                ; the floor, the step, a nursery quick to want more
   ballast (cask (8 * 1048576))                 ; a live set whose pool has room to spare
   _ (please 1)
   live (peep (gauge 0) 8 0)
   room (16 * floor)                            ; the most the rule gives, at the budget's edge or not
   _ (tune (pin (tune ()) 0 (2 * live + 4 * room)))
   _ (please 1)
   (len _) (peep (gauge 0) 0 0)
   ; survivors across natural minors, the nursery's size kept at its largest
   (go i most) (? (i < 200)
     (: keep (map (+ 1) ^20000) more (map (+ 2) ^20000)
        (go (i + 1) (max most (len ()) + 0 * #keep * #more)))
     most)
   most (go 0 (len ()))
   left (#ballast)
   _ (tune was)
   (test (left = 8 * 1048576) (floor < most <= room) ,
    test_fin (), puts "gcbudget: ok", putc 10))
