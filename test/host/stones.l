; test/host/stones.l -- the canyon and the bowl, headless. a crew module, not in the corpus:
; cat test/00-init.l test/host/00-host.l test/host/stones.l | out/love

(borrow 'stones)
(borrow 'vec)
(borrow 'view)     ; pi, wrap
(: stones-kb (view-bind view-binds stones-binds))

   ; the cell row the words n first appear on, or -1
(: (row-of s n) (:- (go 0) (go i) (i + #n <= #s ? (n = snip s i (i + #n) ? (h-count (snip s 0 i) "\r\n") (go (i + 1))) -1))
   day0 (1.0 * 1790812800)                          ; 2026-10-01 midnight, wall clock
   (at hr sd) (stones-new 80 48 [(day0 + hr * 3600.0) 3600] sd)
   (keys! st ks) (each ks (k \ (stones-step st (stones-kb k), stones-move st)))
   (ang b) (: x (b 0 + 1e-9) a (atan ((b 2 - zc) / x)) (x < 0.0 ? (a + pi) a)))

; the frame: deterministic, in the 256 palette and in 24 bits
(: st (at 12.0 7) f (stones-frame st) f2 (stones-frame st)
   deep (stones-frame (pin (at 12.0 7) 'deep 1))
 (test (h-rows f = 24) (f = f2) (h-rows deep = 24) (f != deep)
       (has? f "38;5;") (has? deep "38;2;")))
; ..the keys named on the bottom row at the start, gone a while in; one synchronised update
(: st (at 12.0 7) f (stones-frame st) g (stones-frame (pin (at 12.0 7) 'mt 30.0))
 (test (row-of f "h/j/k/l move" = 23) (has? f "space interacts") !(has? g "h/j/k/l")
       !(has? f "\e[24;1H") (snip f 0 8 = "\e[?2026h") (snip f (#f - 8) #f = "\e[?2026l")))
; ..the choices a third of the way up, the marked one first
(: st (pin (at 12.0 7) 'dlg 0) f (stones-frame st) d (stones-frame (pin (at 12.0 7) 'deep 1 @ s (pin s 'dlg 1)))
 (test (row-of f "1  Breathe" = 24 - 24 // 3 - 4 + 1) (row-of f "5  Wait" = 24 - 24 // 3 - 4 + 5)
       (has? f " › 1  Breathe") (has? d " › 2  Weep") (h-rows f = 24) (h-rows d = 24) !(has? f "H\e[")))

; ..and as kitty's pixels: ids 7 and 8 by turns, each frame deleting the last after it
(: kt (pin (at 12.0 7) 'kitty 1) k (stones-frame kt) k2 (stones-frame kt)
   k8 (stones-frame (stones-size (pin (at 12.0 7) 'kitty 1) 80 24))
   k1 (stones-frame (stones-size (pins (at 12.0 7) 'kitty 1 'scale 1) 80 24))
 (test (snip k 0 8 = "\e[?2026h") (snip k (#k - 8) #k = "\e[?2026l")
       (has? k "i=7,s=") (has? k "a=d,d=I,i=8,") (has? k2 "i=8,s=") (has? k2 "a=d,d=I,i=7,") (has? k "f=24") (has? k "C=1") (has? k "s=80,v=48,c=80,r=24,") (has? k "m=0;")
       (has? k8 "s=320,v=192,c=80,r=24,") (has? k1 "s=640,v=384,c=80,r=24,") ((stones-size (at 12.0 7) 80 24) 'kp = 1)))
; ..the choices' cells blanked over the picture once, the frame they are put away
(: kb (pin (at 12.0 7) 'kitty 1) r ((kb 'h) // 2) r0 (max2 0 (r - r // 3 - 4)) c0 (max2 0 ((kb 'w - 22) // 2))
   gap ("\e[" + show (r0 + 1) + ";" + show (c0 + 1) + "H\e[0m" + cats (map (_ \ " ") (jot 22)))
   f0 (stones-frame kb) _ (pin kb 'dlg 0) _ (stones-frame kb) _ (pin kb 'dlg ())
   f2 (stones-frame kb) f3 (stones-frame kb)
 (test !(has? f0 gap) (has? f2 gap) !(has? f3 gap)))

; the words: the hour today, and kitty's or the cells
(: (opt as k) (stones-opts as @ o (tablet? o ? (o k) 'bad))
 (test (opt ["--time" "6:30"] 'time = 23400) (opt ["--kitty" "--time" "18:05"] 'time = 65100)
       (opt ["--time" "18:05" "--cells"] 'md = 'cells) (opt [] 'md = ())
       (opt ["--time" "24:00"] 'time = 'bad) (opt ["--time"] 'time = 'bad) (opt ["--kitty" "--kitty"] 'md = 'bad)
       (opt ["--cells" "--kitty"] 'md = 'bad) (opt ["--day"] 'md = 'bad)))

; the rock: open at the eye, solid either side of the slot and over the bowl's rim
(: st (at 12.0 7) x (st 'px)
 (test (0.3 < stones-field x eye-h 0.0) (stones-field x -0.1 0.0 < 0.0)
       (stones-field (x + 4.0) 1.0 0.0 < 0.0) (stones-field (x - 4.0) 1.0 0.0 < 0.0)
       (stones-field (slot-x 50.0) 1.0 50.0 > 0.0) (stones-field 0.0 1.0 zc > 0.0) (stones-field 0.0 -0.1 zc < 0.0)
       (stones-field (rim-r + 3.0) 9.0 zc < 0.0) (stones-field 20.0 1.0 (exit-z - 10.0) > 0.0)
       (stones-ground x 0.0 = 0.0) (stones-ground 0.0 zc = 0.0)
       (h-rows * row-h - 1.0 < stones-ground (floor-r + h-rows * row-w - 0.5) zc)))

; the blocks: the altar, a ring of seven (the octagon less north of north-west), and three
; to six of the audience on the rows, none in the slot's notch; the same run the same audience
(: bs (stones-blocks 7) al <bs ring (filter (b \ b 7 = 1 && sqrt (sq (b 0) + sq (b 2 - zc)) < 7.0) bs)
   aud (filter (b \ b 7 = 1 && 7.0 < sqrt (sq (b 0) + sq (b 2 - zc))) bs)
   (slot b) (int (wrap (ang b) / (pi / 4.0) + 8.0) % 8)
   places (sort (map slot ring))
   (on-row? b) (: g (stones-ground (b 0) (b 2)) (row-h - 0.1 <= g && g <= h-rows * row-h))
   (notch? b) (mag (wrap (ang b + pi / 2.0)) < 0.4)
   counts (map (sd \ #(stones-blocks sd) - 8) ^40)
 (test (al 7 = 0) (al 0 = 0.0) (al 2 = zc) (#ring = 7) (places = [0 1 3 4 5 6 7])
       !(any (b \ b 2 < zc && mag (b 0) < al 4 + b 4) ring)
       (3 <= #aud) (#aud <= 6) (all on-row? aud) !(any notch? aud)
       (show (stones-blocks 7) = show bs) (show (stones-blocks 8) != show bs)
       (all (n \ 3 <= n && n <= 6) counts) (any (n \ n != 3) counts)))

; walking: the slot's walls stop you and you slide along them; the eye rides the ground
(: st (at 12.0 7) z0 (st 'pz) th0 (st 'th)
   _ (keys! st [107 107 107]) z1 (st 'pz)
   _ (keys! st [106]) z2 (st 'pz)
   _ (keys! st [108 108]) th1 (st 'th)
   st2 (pins (at 12.0 7) 'th (pi / 2.0)) _ (keys! st2 (map (i \ 107) ^200)) x2 (st2 'px)
   _ (keys! st (map (i \ 117) ^100)) up (st 'ph)
 (test (z0 < z1) (z2 < z1) (z0 < z2) (th0 < th1)
       (mag (x2 - slot-x (st2 'pz)) < 2.0) (stones-field x2 1.0 (st2 'pz) > 0.0)
       (up <= 1.45) (1.4 < up) (st 'py = eye-h)))

; up the rows and down again, never past the last row; the altar stands in the way
(: st (pins (at 12.0 7) 'px 0.0 'pz (zc + floor-r - 0.5) 'th 0.0 'py eye-h 'blocks [])
   _ (keys! st (map (i \ 107) ^600)) top (st 'py)
   ab (pins (at 12.0 7) 'px 0.0 'pz (zc - 3.0) 'th 0.0 'py eye-h)
   _ (keys! ab (map (i \ 107) ^100))
 (test (eye-h + (h-rows - 1) * row-h < top) (top < eye-h + h-rows * row-h + 0.5)
       (ab 'pz < zc - 0.5)))

; out of the mouth the run is done, and the keys do no more
(: st (pins (at 12.0 7) 'th pi)
   _ (keys! st (map (i \ 107) ^700)) z (st 'pz)
   _ (keys! st [107 107])
 (test (st 'done = 1) (z < exit-z) (st 'pz = z)))
; the altar: space near it goes to it and kneels, facing it, with no jump between frames; walking keys
; go unheard; space again stands it up where it knelt
(: st (at 15.5 7) z0 (zc - 2.6) g0 (stones-ground 0.8 z0)
   _ (pins st 'px 0.8 'pz z0 'th 0.25 'ph 0.0 'py (g0 + eye-h) 'dt 0.05)
   _ (stones-step st (stones-kb 32)) began (st 'eye)
   ; ..ticks until the move is done: the most the eye went in one, up and round
   (run n jy jt) (: y (st 'py) t (st 'th) _ (stones-move st)
                    jy2 (max2 jy (mag (st 'py - y))) jt2 (max2 jt (mag (wrap (st 'th - t))))
                    (st 'eye = 'move && n < 400 ? (run (n + 1) jy2 jt2) [n jy2 jt2]))
   k (run 0 0.0 0.0) knelt (st 'eye) kx (st 'px) ky (st 'py) kth (st 'th)
   _ (stones-step st (stones-kb 107)) _ (stones-move st) still (st 'px = kx)
   _ (stones-step st (stones-kb 32)) u (run 0 0.0 0.0) stood (st 'eye)
 (test (began = 'move) (knelt = 'kneel) (still)
       (ky < stones-ground kx (st 'pz) + 1.3) (mag (wrap (atan2 (0.0 - kx) (zc - st 'pz) - kth)) < 0.5)
       (k 1 < 0.06) (k 2 < 0.12) (u 1 < 0.06) (stood = 'walk)
       (mag (st 'py - stones-ground (st 'px) (st 'pz) - eye-h) < 0.01)))

; ..and away from it space kneels where the eye stands, facing on; the choices never come,
; and space stands it again
(: st (at 15.5 7) x0 (st 'px) z0 (st 'pz) th0 (st 'th) _ (pin st 'dt 0.05)
   (until f n) (stones-move st, f () || 400 < n ? n (until f (n + 1)))
   _ (stones-step st (stones-kb 32)) began (st 'eye)
   n (until (_ \ st 'eye != 'move) 0) knelt (st 'eye)
   _ (until (_ \ charm? (st 'dlg)) 0) asked (st 'dlg)
   _ (stones-step st (stones-kb 32)) _ (until (_ \ st 'eye != 'move) 0)
 (test (began = 'move) (n < 400) (knelt = 'kneel) (asked = ())
       (mag (st 'th - th0) < 1e-9) (mag (st 'py - stones-ground (st 'px) (st 'pz) - eye-h) < 0.01)
       (st 'eye = 'walk)))

; the choices: once knelt they come; bleed is a move and they come back after it; wait
; puts them away and stays knelt, till a walking key stands the eye up
(: st (at 15.5 7) z0 (zc - 2.6)
   _ (pins st 'px 0.3 'pz z0 'th 0.0 'ph 0.0 'py (stones-ground 0.3 z0 + eye-h) 'dt 0.05)
   _ (stones-step st (stones-kb 32))
   (until f n) (stones-move st, f () || 400 < n ? n (until f (n + 1)))
   _ (until (_ \ charm? (st 'dlg)) 0) shown (st 'dlg)
   _ (stones-step st (stones-kb 106)) marked (st 'dlg)
   _ (stones-step st (stones-kb 51)) acting (st 'eye) hid (st 'dlg)
   _ (until (_ \ charm? (st 'dlg)) 0) back (st 'dlg)
   tops (filter (d \ 0.6 < d 'p 1) (st 'splats))
   _ (stones-step st (stones-kb 53)) waited [(st 'dlg) (st 'eye)]
   _ (stones-step st (stones-kb 104)) rising (st 'eye)
 (test (shown = 0) (marked = 1) (acting = 'move) (hid = ()) (back = 2) (0 < #tops)
       (waited = [() 'kneel]) (rising = 'move)))

; space at the choices stands; wait is remembered by the lamppost; off the rows' edge into
; the slot is no step; at night, half an hour waited, the missing stone glows till you stand
(: st (at 15.5 7) z0 (zc - 2.6)
   _ (pins st 'px 0.3 'pz z0 'th 0.0 'ph 0.0 'py (stones-ground 0.3 z0 + eye-h) 'dt 0.05)
   _ (stones-step st (stones-kb 32))
   (until s f n) (stones-move s, f () || 400 < n ? n (until s f (n + 1)))
   _ (until st (_ \ charm? (st 'dlg)) 0)
   _ (stones-step st (stones-kb 32)) spaced [(st 'dlg) (st 'eye)]
   ; ..knelt again, and waited
   w (at 15.5 7) _ (pins w 'px 0.3 'pz z0 'th 0.0 'ph 0.0 'py (stones-ground 0.3 z0 + eye-h) 'dt 0.05)
   _ (stones-step w (stones-kb 32)) _ (until w (_ \ charm? (w 'dlg)) 0) _ (stones-step w (stones-kb 53))
   post (post-batch w (stones-light w))
   ; ..the rows beside the slot, stepping toward it
   x0 3.2 rz 95.0 g0 (stones-ground x0 rz)
   e (at 15.5 7) _ (pins e 'px x0 'pz rz 'th (0.0 - pi / 2.0) 'py (g0 + eye-h) 'dt 0.05)
   _ (each ^12 (_ \ stones-step e (stones-kb 107)))
   ; ..the same wait at night, half an hour on
   n (at 23.0 7) _ (pins n 'px 0.3 'pz z0 'th 0.0 'ph 0.0 'py (stones-ground 0.3 z0 + eye-h) 'dt 0.05)
   _ (stones-step n (stones-kb 32)) _ (until n (_ \ charm? (n 'dlg)) 0) _ (stones-step n (stones-kb 53))
   early (ghost-on? n (stones-light n))
   _ (pin n 'wait-at (n 'mt - 1900.0)) late (ghost-on? n (stones-light n))
   _ (stones-step n (stones-kb 107)) gone (ghost-on? n (stones-light n))
 (test (spaced = [() 'move]) (w 'waited = 1) (w 'dlg = ()) (w 'eye = 'kneel) (two? post)
       (0 < g0) (mag (stones-ground (e 'px) (e 'pz) - g0) < 0.9)
       (early = 0) (late = 1) (gone = 0)))

; the help lists walking, kneel, help and quit; the choices are the dialog's own, unlisted
(: hl (view-help stones-kb (view-listed ['kneel]))
 (test (#hl = 9) (hl 6 = "space  kneel") (hl 8 = "esc q  quit")
       !(any (l \ 1 < #(split "bleed" l) || 1 < #(split "choose" l)) hl)))

; w steps as k does and d strafes square to the facing; the mouse turns and tilts the eye
; while walking, and not while kneeling
(: sw (at 12.0 7) _ (pin sw 'th 0.0) x0 (sw 'px) z0 (sw 'pz)
   _ (stones-step sw (stones-kb 119)) z1 (sw 'pz) x1 (sw 'px)
   _ (stones-step sw (stones-kb 100)) x2 (sw 'px) z2 (sw 'pz)
   _ (stones-look sw 40 -20) th (sw 'th) ph (sw 'ph)
   _ (pin sw 'eye 'kneel) _ (stones-look sw 40 -20)
 (test (z1 > z0) (mag (x1 - x0) < 1e-9) (x2 > x1) (mag (z2 - z1) < 1e-9)
       (mag (th - 0.1) < 1e-9) (mag (ph - 0.05) < 1e-9) (sw 'th = th) (sw 'ph = ph)))

(test_fin ())
(puts "stones: ok\n")
