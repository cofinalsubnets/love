; test/host/gesture.l -- src/apps/lore/gesture.l: keys eased between, a kneel to its spot and
; a stand to the eye's height, an act's events once each, and the eye left on 'then.
; run: cat test/00-init.l test/host/gesture.l | out/love
(borrow 'gesture)
(borrow 'vec)      ; mag

(: ks [[0.0 0.0] [1.0 1.0] [2.0 0.5]]
   vs (map (i \ gesture-curve ks (i / 10.0)) ^21)
   (near a b) (mag (a - b) < 1e-6)
   (ground x z) 0.25
   (run st dt fall) (: (go n) (? (st 'eye != 'move || 2000 < n) n
                                 (: _ (pin st 'mt (st 'mt + dt)) _ (gesture-play st dt fall) (go (n + 1))))
                       (go 0))
   ; ..kneel at [1 3] facing [1 5] from the origin, then an act with its tears, then up
   st {'px 0.0 'py 1.85 'pz 0.0 'th 0.0 'ph 0.0 'ro 0.0 'mt 0.0}
   _ (gesture-begin st (gesture-kneel st [1.0 3.0] [1.0 5.0] ground 1.1)) _ (run st 0.05 (s \ k \ ()))
   kn [(st 'eye) (st 'px) (st 'pz) (st 'py)] kth (st 'th)
   c {'n 0}
   _ (gesture-begin st (gesture-act st (gesture-acts 'weep))) _ (run st 0.05 (s \ k \ (k = 'tear ? (pin c 'n (c 'n + 1)))))
   wp [(st 'eye) (st 'px) (st 'pz)]
   _ (gesture-begin st (gesture-stand st ground 1.6)) _ (run st 0.05 (s \ k \ ()))
 (test (near (vs 0) 0.0) (near (vs 10) 1.0) (near (vs 20) 0.5)
       (all (v \ -1e-9 <= v && v <= 1.0 + 1e-9) vs)                ; between its keys, no overshoot
       (near (gesture-curve ks -1.0) 0.0) (near (gesture-curve ks 9.0) 0.5)
       (kn 0 = 'kneel) (near (kn 1) 1.0) (near (kn 2) 3.0) (near (kn 3) 1.35)   ; on its knees at the spot
       (near kth 0.0)                                                ; facing north, at [1 5]
       (wp 0 = 'kneel) (near (wp 1) 1.0) (near (wp 2) 3.0)           ; an act ends where it began
       (c 'n = #(gesture-acts 'weep 'ev))                           ; each tear once
       (st 'eye = 'walk) (near (st 'py) 1.85) (st 'pz < 3.0)          ; up, a step back
       (all (a \ tablet? (gesture-acts a)) ['breathe 'weep 'bleed 'beg])))

(test_fin (),
 puts "gesture: ok -- keys eased between, a kneel to its spot, an act's tears once each, and up again\n")
