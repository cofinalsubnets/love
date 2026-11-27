; test/host/tumble.l -- src/apps/lore/tumble.l: a ball and a box let fall come to rest where they
; should, a ball rolls down a slope as fast as rolling allows, energy never grows, a box on its
; edge falls flat, friction holds a box on a gentle slope and lets it go on a steep one; and
; bodies meet: two balls trade their speed, momentum is kept, three boxes stack, a ball lands
; on a box, a sleeping box is woken by a blow; and C's step (tumble-step) answers as the
; love one does, a mixed scene a second on, and a ring of balls into a big box past the grid's cells;
; and a level's faces: rest on a ledge, roll off it, a face pushing only out of its solid.
; run: cat test/00-init.l test/host/tumble.l | out/love
(borrow 'tumble)
(borrow 'vec)
(borrow 'view)     ; pi

(: flat (tb-floor [0.0 1.0 0.0] 0.0)
   (run W t) (tb-step W t)
   (near a b e) (max (a - b) (b - a) < e)
   ; ..a slope of th down toward +x through the origin
   (slope th) (tb-floor [(sin th) (cos th) 0.0] 0.0)
   (along th p) (p 0 * cos th - p 1 * sin th)
   ; ..how far a box's up is from one of its own axes: 0 when it lies on a face
   (lies b) (: R (tb-rot (b 'q)) (1.0 - foldl max 0.0 (map (k \ max (R 1 k) (0.0 - R 1 k)) ^3)))
   ball (tb-sphere [0.0 2.0 0.0] 0.25 1.0)
   W1 (run (tb-world [ball] [flat]) 4.0)
   box (tb-box [0.3 1.0 -0.2] [0.2 0.1 0.3] 2.0)
   W2 (run (tb-world [box] [flat]) 3.0)
   ; ..a ball let go on a 20 degree slope, a second on
   th (20.0 * pi / 180.0) rb (pins (tb-sphere [(0.25 * sin th) (0.25 * cos th) 0.0] 0.25 1.0) 'mu 0.8 'roll 0.0 'e 0.0)
   W3 (run (tb-world [rb] [(slope th)]) 1.0)
   d (along th (rb 'p)) want (0.5 * (5.0 / 7.0) * 9.81 * sin th)
   ; ..a box dropped turned on an edge, its energy each tenth
   tilt (pins (tb-box [0.0 1.0 0.0] [0.25 0.25 0.25] 1.0) 'q (qaxis [1.0 0.0 0.3] 0.7) 'e 0.3)
   W4 (tb-world [tilt] [flat]) e0 (tb-energy W4) es (e0 . map (_ \ (run W4 0.1, tb-energy W4)) ^30)
   ; ..the most it ever rose from one tenth to the next
   up (foldl max 0.0 (map (i \ es (i + 1) - es i) ^(#es - 1)))
   ; ..boxes on slopes: held at 15 degrees by mu 0.6, sliding at 40 by mu 0.3
   (sit th mu) (: b (pins (tb-box [0.0 0.0 0.0] [0.2 0.2 0.2] 1.0) 'mu mu 'e 0.0 'q (qaxis [0.0 0.0 1.0] (0.0 - th)))
                  _ (pin b 'p [(0.2 * sin th) (0.2 * cos th) 0.0])
                  (run (tb-world [b] [(slope th)]) 1.0, along th (b 'p)))
 (test ; the ball: on the floor at its radius, still, asleep
       (near (ball 'p 1) 0.25 0.005) (near (ball 'p 0) 0.0 1e-6) (ball 'still = 1)
       ; the box: on its thinnest side, where it fell, asleep
       (near (box 'p 1) 0.1 0.005) (near (box 'p 0) 0.3 1e-3) (near (box 'p 2) -0.2 1e-3)
       (box 'still = 1) (lies box < 1e-3)
       ; rolling: a = (5/7) g sin th, so s = a/2 in the first second, within 3%
       (near d want (0.03 * want)) (near (rb 'p 2) 0.0 1e-6)
       ; turning as it rolls: w r is the speed
       (near (sqrt (dot (rb 'w) (rb 'w)) * 0.25) (sqrt (dot (rb 'v) (rb 'v))) 0.02)
       ; the tilted box: its energy never rises, and it lies flat
       (up < 1e-6) (near (es 0) 9.81 1e-9) (lies tilt < 1e-3) (tilt 'still = 1) (near (tilt 'p 1) 0.25 0.005)
       ; friction: held within a millimetre, or slid more than a metre
       (near (sit (15.0 * pi / 180.0) 0.6) 0.0 0.001) (sit (40.0 * pi / 180.0) 0.3 > 1.0)))

; --- bodies meeting ---
(: flat (tb-floor [0.0 1.0 0.0] 0.0)
   (near a b e) (max (a - b) (b - a) < e)
   (mom bs) (foldl (\ s b (c+ s (c* (b 'm) (b 'v)))) [0.0 0.0 0.0] bs)
   (free bs) (pin (tb-world bs ()) 'g [0.0 0.0 0.0])
   ; ..head on, no weight: equal balls, a full bounce, the speed passes from one to the other
   a1 (pins (tb-sphere [0.0 0.0 0.0] 0.2 1.0) 'v [2.0 0.0 0.0] 'e 1.0) b1 (pins (tb-sphere [1.0 0.0 0.0] 0.2 1.0) 'e 1.0)
   _ (tb-step (free [a1 b1]) 1.0)
   ; ..a heavy ball glancing off a turning box: momentum the same after as before
   a2 (pins (tb-sphere [-1.0 0.15 0.0] 0.25 3.0) 'v [3.0 0.0 0.0]) b2 (pins (tb-box [0.0 0.0 0.0] [0.3 0.2 0.25] 1.0) 'w [0.0 2.0 1.0])
   m0 (mom [a2 b2]) _ (tb-step (free [a2 b2]) 1.0) m1 (mom [a2 b2])
   ; ..three boxes let down on each other a little apart
   (bx y) (pins (tb-box [0.0 y 0.0] [0.3 0.2 0.3] 1.0) 'e 0.0)
   s0 (bx 0.21) s1 (bx 0.63) s2 (bx 1.05) _ (tb-step (tb-world [s0 s1 s2] [flat]) 3.0)
   ; ..a ball dropped on a box lying on the floor
   lb (tb-box [0.0 0.2 0.0] [0.4 0.2 0.4] 2.0) db (pins (tb-sphere [0.05 1.5 0.0] 0.2 1.0) 'e 0.3)
   _ (tb-step (tb-world [lb db] [flat]) 3.0)
   ; ..a box asleep on the floor, a ball rolled into it
   sb (tb-box [0.0 0.2 0.0] [0.2 0.2 0.2] 1.0) _ (tb-step (tb-world [sb] [flat]) 1.0) slept (sb 'still)
   rl (pins (tb-sphere [-1.0 0.2 0.0] 0.2 2.0) 'v [4.0 0.0 0.0]) _ (tb-step (tb-world [sb rl] [flat]) 0.4)
 (test ; the cradle: the first stops, the second goes on at its speed
       (near (a1 'v 0) 0.0 0.02) (near (b1 'v 0) 2.0 0.02)
       ; momentum kept to a part in ten thousand
       (near (m1 0) (m0 0) 1e-3) (near (m1 1) (m0 1) 1e-3) (near (m1 2) (m0 2) 1e-3) (a2 'v 0 < 3.0)
       ; the stack stands: each on the one below, square over it, all asleep
       (near (s0 'p 1) 0.2 0.01) (near (s1 'p 1) 0.6 0.015) (near (s2 'p 1) 1.0 0.02)
       (near (s2 'p 0) 0.0 0.005) (near (s2 'p 2) 0.0 0.005) (s0 'still + s1 'still + s2 'still = 3)
       ; the ball on the box: on its top, the box not sunk
       (near (db 'p 1) 0.6 0.01) (near (lb 'p 1) 0.2 0.005)
       ; asleep, then knocked away
       (slept = 1) (sb 'p 0 > 0.1)))

; --- C against love: boxes on boxes, balls on a ramp and into each other, a second on ---
(: flat (tb-floor [0.0 1.0 0.0] 0.0) th 0.35
   ramp [[[(sin th) (cos th) 0.0] 0.0] [[0.0 -1.0 0.0] 0.0] [[-1.0 0.0 0.0] 6.0] [[0.0 0.0 1.0] 1.0] [[0.0 0.0 -1.0] 3.0]]
   (scene _) [(pins (tb-box [0.0 0.9 0.0] [0.3 0.2 0.25] 1.0) 'q (qaxis [1.0 0.2 0.3] 0.7) 'w [1.0 -2.0 0.5])
              (tb-box [0.1 0.25 0.05] [0.4 0.25 0.4] 2.0)
              (pins (tb-sphere [0.6 1.4 -0.1] 0.2 1.0) 'v [-1.0 0.0 0.3] 'e 0.7)
              (pins (tb-sphere [-3.0 2.0 -1.0] 0.3 1.0) 'mu 0.6)
              (pins (tb-box [-4.0 2.5 0.2] [0.2 0.2 0.2] 1.0) 'q (qaxis [0.0 0.0 1.0] -0.35) 'mu 0.2)
              (pins (tb-sphere [1.5 0.3 0.0] 0.3 1.0) 'v [-2.0 0.0 0.0])]
   (run e) (: bs (scene ()) (tb-step (pin (tb-world bs [flat ramp]) 'engine e) 1.0, bs))
   L (run 'love) C (run 'c)
   gap (foldl max 0.0 (catmap (i \ catmap (k \ map (j \ mag (L i k j - C i k j)) ^(k = 'q ? 4 3)) ['p 'q 'v 'w]) ^#L))
 (test (gap < 1e-9) (map (b \ b 'still) L = map (b \ b 'still) C)
       ; ..and it moved: the falling box is no longer where it started
       (C 0 'p 1 < 0.8)))


; --- the grid: pairs met across cell edges, below zero, and a big box among small balls ---
(: flat (tb-floor [0.0 1.0 0.0] -3.0)
   (scene _) ([(pins (tb-box [-7.0 -1.5 -7.0] [1.5 1.0 1.5] 8.0) 'w [0.0 0.3 0.0])]
              + map (i \ (: a (0.7 * i) r (6.0 + 0.5 * (i % 3))
                             (pins (tb-sphere [(r * cos a - 7.0) (-2.0 + 0.3 * (i % 4)) (r * sin a - 7.0)] (0.15 + 0.05 * (i % 2)) 1.0)
                                   'v [(-4.0 * cos a) 0.0 (-4.0 * sin a)])))
                    ^24)
   (run e) (: bs (scene ()) (tb-step (pin (tb-world bs [flat]) 'engine e) 1.5, bs))
   L (run 'love) C (run 'c)
   gap (foldl max 0.0 (catmap (i \ catmap (k \ map (j \ mag (L i k j - C i k j)) ^(k = 'q ? 4 3)) ['p 'q 'v 'w]) ^#L))
   ; ..the balls met the box and each other: some ended moving outward
   out (net (map (b \ dot (c- (b 'p) [-7.0 0.0 -7.0]) (b 'v) > 0.0) >L))
 (test (gap < 1e-9) (map (b \ b 'still) L = map (b \ b 'still) C) (out > 0)))


; --- faces: a level's surfaces as convex polygons, solid behind. a ledge half a metre up
; over a floor, its top, its wall, and the floor beyond it ---
(: top [[-1.0 0.5 -1.0] [0.0 0.5 -1.0] [0.0 0.5 1.0] [-1.0 0.5 1.0]]
   wall [[0.0 0.0 -1.0] [0.0 0.5 -1.0] [0.0 0.5 1.0] [0.0 0.0 1.0]]
   floor [[0.0 0.0 -1.0] [3.0 0.0 -1.0] [3.0 0.0 1.0] [0.0 0.0 1.0]]
   fs [[top [0.0 1.0 0.0]] [wall [1.0 0.0 0.0]] [floor [0.0 1.0 0.0]]]
   (run e bs t) (: W (tb-faces (pin (tb-world bs ()) 'engine e) fs) (tb-step W t, bs))
   ; ..a ball and a box let fall on the top rest on it and sleep
   a (run 'c [(tb-sphere [-0.5 1.0 0.0] 0.2 1.0)] 2.0)
   b (run 'c [(pins (tb-box [-0.5 1.0 0.1] [0.2 0.15 0.25] 1.0) 'q (qaxis [1.0 0.2 0.4] 0.6))] 2.5)
   ; ..a ball rolled off the top's edge comes down on the floor past the wall
   c (run 'c [(pins (tb-sphere [-0.6 0.7 0.0] 0.2 1.0) 'v [1.5 0.0 0.0])] 2.0)
   ; ..one under the top, in its solid, is let fall: a face pushes only out of its solid side
   d (run 'c [(tb-sphere [-0.5 0.3 0.0] 0.1 1.0)] 0.5)
   ; ..a ball thrown at the wall's foot comes back off it
   f (run 'c [(pins (tb-sphere [1.5 0.2 0.3] 0.2 1.0) 'v [-3.0 0.0 0.0] 'e 0.8)] 1.0)
   ; ..and C answers as love does, a ball and a box on the ledge going over its edge
   (mixed _) [(pins (tb-box [-0.3 0.8 0.0] [0.2 0.15 0.2] 1.0) 'q (qaxis [0.3 0.1 1.0] 0.5) 'v [1.0 0.0 0.2])
              (pins (tb-sphere [-0.7 0.8 0.3] 0.15 1.0) 'v [2.0 0.0 0.0])]
   L (run 'love (mixed ()) 1.5) C (run 'c (mixed ()) 1.5)
   gap (foldl max 0.0 (catmap (i \ catmap (k \ map (j \ mag (L i k j - C i k j)) ^(k = 'q ? 4 3)) ['p 'q 'v 'w]) ^#L))
 (test (mag (a 0 'p 1 - 0.7) < 0.005) (a 0 'still = 1)
       (mag (b 0 'p 1 - 0.65) < 0.11) (b 0 'p 1 > 0.6) (b 0 'still = 1)
       (c 0 'p 0 > 0.2) (mag (c 0 'p 1 - 0.2) < 0.01)
       (d 0 'p 1 < 0.0)
       (f 0 'v 0 > 0.5)
       (gap < 1e-9) (map (b \ b 'still) L = map (b \ b 'still) C) (C 0 'p 0 > 0.0)))

(test_fin ())
(puts "tumble: ok\n")
