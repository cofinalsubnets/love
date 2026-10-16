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
