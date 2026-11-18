; test/host/walk.l -- src/apps/lore/walk.l: keys by gait, pitch bounds, wall slides, frame time.
; run: cat test/00-init.l test/host/walk.l | out/love
(borrow 'walk)
(borrow 'view)     ; pi
(borrow 'vec)      ; mag

(: g {'turn 0.1 'walk 0.5 'tilt 0.2 'up 0.3 'down -0.3}
   (at x z th) {'px x 'pz z 'th th 'ph 0.0}
   (put st x z) (pins st 'px x 'pz z)
   (k st key) (walk-key st (view-binds key) g put)
   (near a b) (mag (a - b) < 1e-9)
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

; the gauge: steps of 400 100 25 pixels from the middle, a 100 ms goal, a frame each 100 ms.
; gr answers the steps taken over frames [paint feed low]; gc runs it closed, a frame's paint
; a ms and k ms a pixel at the step it draws, and answers its steps
(: (gr fs) (: g (view-gauge [400 100 25] 1 100.0)
             (map (n \ fs n @ [ms fd lw] (view-gauged g ms fd lw (100 * n))) ^#fs))
   (gc a k n) (: g (view-gauge [400 100 25] 1 100.0)
              (go t i) (t < n ? (: j (view-gauged g (a + k * (g 'pix) i) 10 0 (100 * t)) (j . go (t + 1) j)) ())
              (go 0 1))
   (ch l) (#(filter (x \ x) (map (i \ l i != l (i + 1)) ^(#l - 1))))
   cheap (gr (map (_ \ [15 10 0]) ^40))
   dear (gr (map (_ \ [150 10 0]) ^40))
   low (gr (map (n \ [5 10 (n = 6)]) ^40))
   spike (gr (map (n \ [(n = 15 ? 400 60) 10 0]) ^40))
 (test (cheap 29 = 1) (cheap 30 = 0) (cheap 39 = 0)    ; finer at 3 s, its 60 ms under 0.8 of 90
       (dear 9 = 1) (dear 10 = 2) (dear 19 = 2)        ; coarser after a second over, and back
       (dear 20 = 1) (dear 39 = 1)                     ; a second on: it bought nothing
       (low 5 = 1) (low 6 = 2) (low 35 = 2) (low 36 = 1) ; a low horn at once, finer 3 s on
       (ch spike = 0)                                  ; one 400 ms frame among 60s moves nothing
       (ch (gc 0 0.6 200) = 0)                         ; 60 ms fits, 240 never would
       (gc 0 0.15 200 @ l (ch l = 1 && l 199 = 0))     ; 60 ms finer fits: one step, held
       (gc 0 1.2 200 @ l (ch l = 1 && l 199 = 2))      ; 120 ms over: one step coarser, held
       (gc 95 0.05 200 @ l (l 10 = 2 && l 20 = 1 && ch l = 2)) ; 100 ms over, 96 coarser: tried, and back
       (gc 60 0.4 200 @ l (l 10 = 2 && ch l = 1))))    ; 100 ms over, 70 coarser: one step, held

; a level's bindings over view's: its own win, () unbinds, view's untouched; help in list order
(: wb (view-bind view-binds {112 'where 104 () 108 'spin})
   hl (view-help wb (view-listed ['spin 'where 'nowhere]))
 (test (wb 112 = 'where) (wb 104 = ()) (wb 108 = 'spin) (wb -2 = 'turn-right) (wb -1 = 'turn-left)
       (view-binds 104 = 'turn-left) (view-binds 108 = 'turn-right) (view-binds 112 = ())
       (view-binds 43 = 'finer) (view-binds 61 = 'finer) (view-binds 45 = 'coarser)
       (#hl = 10) (hl 0 = "↑ k    forward") (hl 1 = "↓ j    back") (hl 2 = "←      turn-left")
       (hl 6 = "l      spin") (hl 7 = "p      where") (hl 8 = "?      help") (hl 9 = "esc q  quit")))
(test_fin ())
(puts "walk: ok\n")
