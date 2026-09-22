; --- test/host/shaft.l: the elevator shaft, headless ---
; not in the test/*.l corpus (it loads a crew module). the scene is pure love, so
; everything but the tty runner gates here: the frame's shape and the lights' blink, the
; lay's gaps and where they are not, walking and turning, a jump up and down, a gap
; jumped and a gap walked into, a fall's flash by the fall, a ladder up and down, the
; top door and the lower ones, and the song into a jug.
;   cat test/00-init.l test/host/shaft.l | out/love

(borrow 'shaft)   ; the artifact's module, warm from the tree

(: (count s n) (:- (go 0 0) (go i k) (i + #n <= #s ? (go (i + 1) (k + (n = snip s i (i + #n)))) k))
   (rows s) (1 + count s "\r\n")
   ; so many frames, a key each or none
   (tick st k) (: _ (? (charm? k) (shaft-step st k)) _ (shaft-move st) (pin st 't (st 't + 1)))
   (run st n) (? (0 < n) (tick st (), run st (n - 1)) st)
   (walk st k n) (? (0 < n) (tick st k, walk st k (n - 1)) st)
   ; ..until the player stands on something, or too long
   (settle st n) (? (st 'ground || n <= 0) st (tick st (), settle st (n - 1)))
   (fresh _) (shaft-new 80 48 (wheel 5))
   (at st x z y) (pins st 'px x 'pz z 'y y 'ground 1 'vy 0.0 'vx 0.0 'vz 0.0 'rung ())
   ; ..standing on the ring at s, in from the wall
   (on st s y) (: e (ring-pt s walk-q) (at st (e 0) (e 1) y))
   (near? a b) (: d (a - b) (d * d < 0.0001))
   half-on (int (fps * light-on / 2.0))
   half-off (int (fps * (light-on + light-period) / 2.0)))

; --- the frame: half the pixel rows in cells, the same state the same frame, a wide
; --- one wider; the lights blink -- on then off within a period, and the wall with them
; --- on it paints differently lit and dark
(: st (fresh ()) f (shaft-frame st) f2 (shaft-frame st)
   wide (shaft-new 120 60 (wheel 5))
   _ (on st shaft-r 0.0) _ (pins st 'th 1.5707963 't half-on) lit (shaft-frame st)   ; facing the wall at x = r
   _ (pin st 't half-off) dark (shaft-frame st)
 (test (rows f = 24) (f = f2) (rows (shaft-frame wide) = 30)
       (blink half-on 0 = 1.0) (blink half-off 0 = 0.0) (all (t \ 0.0 <= blink t 0 <= 1.0) ^300)
       (lit != dark)
       ; the floors drift apart: a tick where the ground floor is full on and the top is not
       (any (t \ blink t 0 = 1.0 && blink t (floors - 1) < 1.0) ^3000)
       ; the hole over a ladder is drawn -- the frame differs with it and without -- and stood on
       (: l <ladders e (ring-pt (l 0) walk-q) (ledge-under? (st 'lay) 1 (e 0) (e 1)))))

; --- the lay: gaps on every ring above the floor, each within one wall and clear of its
; --- ends, and no gap under a ladder or the door; the floor everywhere and the middle of
; --- the shaft under no ledge; the same die the same lay
(: st (fresh ()) lay (st 'lay)
   rings (map (+ 1) ^(floors - 1))
   gaps (map (f \ peep (lay 'gaps) f ()) rings)
   (within-wall? g) (wall-of (g 0) = wall-of (g 1 - 0.001))
   (clear-of? p) (all (f \ ledge? lay f p) ^floors)
   g <(peep (lay 'gaps) 1 ()) e (ring-pt ((g 0 + g 1) / 2.0) walk-q)
 (test (all (gs \ 0 < #gs) gaps)
       (all (gs \ all within-wall? gs) gaps)
       (all (f \ all (g \ !(ledge? lay f (g 0 + 0.01))) (peep (lay 'gaps) f ())) rings)   ; a gap is no ledge
       (all (l \ clear-of? (l 0) && clear-of? (l 0 + ladder-w) && clear-of? (l 0 - ladder-w)) ladders)
       (clear-of? door-s) (clear-of? (door-s + door-w)) (clear-of? (door-s - door-w))
       (all (s \ ledge? lay 0 s) (map (* 0.5) ^48))
       (!(ledge-under? lay 1 (e 0) (e 1))) (ledge-under? lay 0 (e 0) (e 1))
       (: e2 (ring-pt (<ladders 0) walk-q) (ledge-under? lay 1 (e2 0) (e2 1)))
       (all (f \ !(ledge-under? lay f 0.0 0.0)) rings) (ledge-under? lay 0 0.0 0.0)
       (show lay = show ((shaft-new 80 48 (wheel 5)) 'lay))))

; --- walking: k steps the way you face, j back, a key a frame; h and l turn, all the way
; --- round; a wall stops you ---
(: st (fresh ()) x0 (st 'px) z0 (st 'pz) th0 (st 'th)
   _ (walk st 107 10) x1 (st 'px) z1 (st 'pz)
   _ (walk st 106 5) x2 (st 'px)
   _ (walk st 104 10) thl (st 'th) _ (walk st 108 20) thr (st 'th)
   _ (pins st 'th 0.0) _ (walk st 107 300) zw (st 'pz)
   _ (each ^100 (i \ shaft-step st 108)) thw (st 'th)
 (test (x0 < x1) (near? z0 z1) (x2 < x1) (x2 != x0)
       (thl < th0) (th0 < thr) (near? (thr - th0) (10 * turn-step))
       (near? zw (shaft-r - body-r)) (st 'ground) (0.0 = st 'y)
       (thw * thw <= 9.8696045)))                                     ; wrapped: never past pi

; --- a jump: up off the floor and back down onto it, carrying the walk; none from the air ---
(: st (fresh ()) x0 (st 'px)
   _ (tick st 107, shaft-jump st) g0 (st 'ground)
   _ (run st 3) y3 (st 'y)
   _ (shaft-jump st) vy-mid (st 'vy)
   _ (settle st 200)
   st2 (fresh ()) _ (shaft-jump st2) _ (settle st2 200)
 (test (nil? g0) (0.0 < y3) (vy-mid < jump-v) (st 'ground) (0.0 = st 'y) (x0 < st 'px)
       (st2 'ground) (near? (st2 'px) x0)))                           ; stood still: straight up and down

; --- a gap: walked into, the player falls to what is under it; jumped, they land past it ---
(: st (fresh ()) lay (st 'lay) g <(peep (lay 'gaps) 1 ()) g0 (g 0) g1 (g 1) th (tangent-of g0)
   _ (on st (g0 - 0.3) floor-h) _ (pin st 'th th)
   _ (walk st 107 12) fell (nil? (st 'ground)) yf (st 'y)
   _ (settle st 300) yl (st 'y)
   st2 (fresh ()) _ (on st2 (g0 - 0.1) floor-h) _ (pin st2 'th th)
   _ (tick st2 107, shaft-jump st2) _ (settle st2 300)
   nw (near-wall (st2 'px) (st2 'pz))
 (test fell (yf < floor-h) (st 'ground) (yl < floor-h) (yl = ground-at lay (st 'px) (st 'pz) yl)
       (st2 'ground) (st2 'y = floor-h) (g1 < nw 1) (nw 2 <= ledge-d)))

; --- a fall: from a floor up, the screen flashes and the flash fades; from two floors
; --- up it flashes more and fades slower; a thud is due either way ---
(: st (fresh ()) lay (st 'lay) g <(peep (lay 'gaps) 1 ()) s ((g 0 + g 1) / 2.0)
   _ (on st s floor-h) _ (pin st 'ground 0)
   _ (settle st 300) a1 (st 'flash) k1 (st 'flash-k) n1 #(st 'sfx)
   _ (run st 30) a1b (st 'flash)
   _ (run st 3000) a1c (st 'flash)
   st2 (fresh ()) _ (on st2 s (2.0 * floor-h)) _ (pin st2 'ground 0)
   _ (settle st2 300) a2 (st2 'flash) k2 (st2 'flash-k)
 (test (0.0 = st 'y) (0.0 < a1 <= 1.0) (a1b < a1) (0.0 = a1c) (0 < n1)
       (0.0 = st2 'y) (a1 < a2 <= 1.0) (k1 < k2 < 1.0)))

; --- a ladder: space at its foot takes hold, k climbs to the ledge above and lets go
; --- there; space at the top takes hold, j climbs down; space midway lets go, and down
; --- you come ---
(: st (fresh ()) l <ladders
   _ (on st (l 0) (l 1)) _ (shaft-step st 32) held (st 'rung)
   _ (walk st 107 5) yb (st 'y) th (st 'th)
   _ (walk st 107 300) ya (st 'y) held2 (st 'rung)
   _ (shaft-step st 32) held3 (st 'rung) _ (walk st 106 300) yd (st 'y)
   _ (shaft-step st 32) _ (walk st 107 20) ym (st 'y) _ (shaft-step st 32) let-go (st 'rung)
   _ (settle st 300)
   st2 (fresh ()) _ (shaft-step st2 32)                              ; space away from a ladder: a jump
 (test (two? held) (l 1 < yb < l 2) (near? th (tangent-of (l 0) + 1.5707963))
       (ya = l 2) (nil? held2) (st 'ground)
       (two? held3) (yd = l 1) (st 'ground)
       (l 1 < ym) (nil? let-go) (st 'ground) (st 'y = l 1)
       (nil? (st2 'rung)) (nil? (st2 'ground))))

; --- the look: u and n tilt it and no further than the screen allows ---
(: st (fresh ()) hz0 (st 'hz) h (st 'h)
   _ (shaft-step st 117) hzu (st 'hz) _ (shaft-step st 110) hzn (st 'hz)
   _ (each ^100 (i \ shaft-step st 117)) top (st 'hz)
   _ (each ^200 (i \ shaft-step st 110)) bot (st 'hz)
 (test (hz0 < hzu) (hzn = hz0) (top = 7 * h // 8) (bot = h // 8)))

; --- the doors: standing at the top one opens it, which is the level done, and the
; --- frame shows it; standing at a lower one does nothing ---
(: st (fresh ()) top ((floors - 1) * floor-h)
   _ (on st door-s floor-h) _ (run st 3) d1 (st 'done)
   _ (on st door-s top) _ (pin st 'th (tangent-of door-s + 1.5707963))   ; facing the door wall
   shut (shaft-frame st)
   _ (run st 3) d2 (st 'done)
   open (shaft-frame st)
   _ (shaft-step st 107) _ (run st 2) x (st 'px)
 (test (nil? d1) (d2 = 1) (shut != open) (near? x (ring-pt door-s walk-q 0)) (elem 'door (st 'sfx))))

; --- the song: silence until something happens, then not; a chunk a feed ---
(: j (jug 0) s (shaft-song-new j (wheel 7)) st (fresh ())
   _ (each ^5 (i \ (shaft-sfx s st, shaft-song-feed s)))
   quiet (slurp j)
   j2 (jug 0) s2 (shaft-song-new j2 (wheel 7))
   _ (pins st 'sfx [['thud 0.8]])
   _ (each ^5 (i \ (shaft-sfx s2 st, shaft-song-feed s2)))
   loud (slurp j2)
 (test (#quiet = 5 * 4 * song-chunk) (all (i \ 0 = quiet i) ^#quiet)
       (#loud = #quiet) (any (i \ 0 != loud i) ^#loud) (nil? (st 'sfx))))

(test_fin (),
 puts "shaft: ok -- the walk goes where you face, a jump lands, a gap is jumped or fallen through, a fall flashes by the fall, the ladder climbs on space, the lights blink, and the top door opens\n")
