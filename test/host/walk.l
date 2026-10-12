; test/host/walk.l -- src/apps/lore/walk.l: each walking key as far as its gait says, the
; pitch held to its bounds, any other key none of its; a step slid along a wall, east or
; north alone, and none into a corner; the frame's time kept to its bounds.
; not in the corpus: a crew module. run: cat test/00-init.l test/host/walk.l | out/love
(borrow 'walk)
(borrow 'view)     ; pi
(borrow 'vec)      ; mag

(: g {'turn 0.1 'walk 0.5 'tilt 0.2 'up 0.3 'down -0.3}
   (at x z th) {'px x 'pz z 'th th 'ph 0.0}
   (put st x z) (pins st 'px x 'pz z)
   (k st key) (walk-key st key g put)
   (near a b) (mag (a - b) < 1e-9)
   ; ..a wall along x = 1: east of it is not free
   (free? st x z) (x < 1.0)
 (test (near (k (at 0.0 0.0 0.0) 104 'th) -0.1) (near (k (at 0.0 0.0 0.0) -2 'th) 0.1)
       (near (k (at 0.0 0.0 0.0) 107 'pz) 0.5) (near (k (at 0.0 0.0 0.0) -9 'pz) -0.5)
       (near (k (at 0.0 0.0 (pi / 2.0)) 107 'px) 0.5)
       (near (k (at 0.0 0.0 0.0) 117 'ph) 0.2) (near (k (k (at 0.0 0.0 0.0) 117) 117 'ph) 0.3)
       (near (k (k (at 0.0 0.0 0.0) 110) 110 'ph) -0.3)
       (k (at 0.0 0.0 0.0) 120 = ()) (k (at 0.0 0.0 0.0) 32 = ())
       ; ..into the wall at a slant: only the northward part goes
       (walk-slide (at 0.8 0.0 0.0) 1.2 0.4 free? @ s (near (s 'px) 0.8 && near (s 'pz) 0.4))
       (walk-slide (at 0.2 0.0 0.0) 0.6 0.4 free? @ s (near (s 'px) 0.6 && near (s 'pz) 0.4))
       (walk-slide (at 0.8 0.0 0.0) 1.2 0.0 (\ st x z 0) @ s (near (s 'px) 0.8 && near (s 'pz) 0.0))
       (walk-dt {} @ s (0.02 <= s 'dt <= 0.25 && charm? (s 'wall)))))
(test_fin ())
(puts "walk: ok\n")
