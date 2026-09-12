; --- t/host/rove.l: the rove engine and the climb it carries, headless ---
; not in the t/*.l corpus (it loads a crew file and leaks its helpers).
; the engine core is pure love, so everything but the tty runner gates here:
; delve (seeded, connected, bordered), fov (strides, walls, memory), the
; painter (a frame into a jug), the helm decoder, the words and their holes, and
; the climb end to end -- combat, pennies, the mending, the pace, the stair,
; death, and the circle that ends it. the tty side (tower-run) is berth-thin over
; what this file proves, and t/host/tty.l plays it on a real pty.
;
;   cat t/00-init.l t/host/rove.l | b/love

(borrow 'rove)   ; the artifact's module, warm from the tree

(: (find h n i) (? (i + tally n < 1 + tally h)
                  (? (n = snip h i (i + tally n)) 1 (find h n (i + 1)))
                  0))

; --- delve: a seed reproduces its floor; floors are connected and bordered ---
(: p1 (delve 60 20 (wheel 11))
   p2 (delve 60 20 (wheel 11))
   p3 (delve 60 20 (wheel 12))
   d <p1
   (teq a b) (: (go i ok) (? (i < 1200) (go (i + 1) (&& ok (peep (a 't) i 0 = peep (b 't) i 0)))
                           ok)
                (go 0 1))
   flood (: mk (cask 1200)
            (go stk n) (? !stk n
                        (: xy <stk x <xy y <>xy i (x + 60 * y)
                           (? (|| !(open? d x y) (peep mk i 0)) (go >stk n)
                            (: _ (pin mk i 1)
                               (go (cat [[(x + 1) y] [(x - 1) y] [x (y + 1)] [x (y - 1)]] >stk)
                                   (n + 1))))))
            (go [(d 'in)] 0))
   floors (: (go i n) (? (i < 1200) (go (i + 1) (n + (? (0 < peep (d 't) i 0) 1 0))) n)
             (go 0 0))
   rim (: (go i bad) (? (i < 60)
                       (go (i + 1) (|| bad (dat d i 0) (dat d i 19)))
                       (: (gov j b2) (? (j < 20) (gov (j + 1) (|| b2 (dat d 0 j) (dat d 59 j))) b2)
                          (gov 0 bad)))
          (go 0 0))
 (test
  (teq <p1 <p2)                                  ; one seed, one floor
  !(teq <p1 <p3)                                 ; another seed, another floor
  (1 < tally (d 'rooms))
  (1 = dat d <(d 'in) <>(d 'in))                 ; you stand on open floor
  (2 = dat d <(d 'stair) <>(d 'stair))           ; the stair is cut
  (flood = floors)                               ; every floor cell reachable
  !rim))                                         ; the border is never breached

; --- fov: strides light what they reach, rock blocks, the seen cask remembers ---
; a hand floor, two rooms split by a wall at x=4:
;   #########
;   #...#...#
;   #...#...#
;   #...#...#
;   #########
(: hd {'w 9 'h 5 't (cask 45) 'seen (cask 45) 'rooms [[1 1 3 3] [5 1 3 3]]}
   _ (map (\ y (map (\ x (? (x = 4) () (dput hd x y 1))) '(1 2 3 4 5 6 7))) '(1 2 3))
   v (fov hd 1 1 8)
 (test
  (peep v (1 + 9 * 1) 0)                         ; your own cell is lit
  (peep v (3 + 9 * 1) 0)                         ; down the room
  (peep v (4 + 9 * 1) 0)                         ; the wall catches the light
  !(peep v (5 + 9 * 1) 0)                        ; ... and keeps the far room dark
  !(peep v (7 + 9 * 3) 0)
  (peep v 0 0)                                   ; the corner wall glows (adjacency)
  (peep (hd 'seen) (3 + 9 * 1) 0)                ; the lantern leaves a memory
  !(peep (hd 'seen) (5 + 9 * 1) 0))
 ; step across: the far room lights, the seen cask keeps both
 (: v2 (fov hd 5 2 8)
  (test
   (peep v2 (5 + 9 * 1) 0)
   !(peep v2 (1 + 9 * 1) 0)
   (peep (hd 'seen) (1 + 9 * 1) 0)
   (peep (hd 'seen) (6 + 9 * 2) 0))))

; --- the helm: arrows, the sailor's keys, alt letters; anything else is itself ---
(test
 ('(0 -1) = steer -8) ('(0 1) = steer -9) ('(1 0) = steer -2) ('(-1 0) = steer -1)
 (27 = (steer 27))
 ('(-1 0) = steer 104) ('(0 1) = steer 106) ('(0 -1) = steer 107) ('(1 0) = steer 108)
 ('(-1 -1) = steer 121) ('(1 -1) = steer 117) ('(-1 1) = steer 98) ('(1 1) = steer 110)
 ('(-1 -1) = steer 377) ('(1 1) = steer 366)
 (62 = (steer 62))
 (113 = (steer 113)))

; --- the words: a line fills its holes, and wears its braces at the port ---
(test
 ("you strike the rat (2)" = fill "you strike the ~ (~)" ["rat" 2])
 ("nothing to fill" = fill "nothing to fill" ())      ; no hole, no change
 ("abc" = fit "abcdef" 3)                             ; a row is cut to fit
 (find (fit "a {b} c" 40) "38;5;201" 0)               ; the token's pen goes on
 (find (fit "{abcde}" 5) "abcde" 0)                   ; ..and an escape costs no width
 !(find (fit "{abcde}" 3) "abcde" 0))                 ; ..so the cut is still honest

; --- the climb on a hand floor: every verb of the game, deterministic ---
(: (hand-g _) (: hd {'w 9 'h 5 't (cask 45) 'seen (cask 45) 'rooms [[1 1 3 3] [5 1 3 3]]}
                 _ (map (\ y (map (\ x (? (x = 4) () (dput hd x y 1))) '(1 2 3 4 5 6 7))) '(1 2 3))
                 _ (pin hd 'in [1 1], pin hd 'stair [7 3])
                 st (wheel 5) sb {st}
                 pl {'x 1 'y 1 'gl 64 'hue 228 'hp 20 'mx 20 'penny 0}
                 {'d hd 'lvl 1 'tn 0 'sb sb 'p pl 'ms () 'loot (tablet 0) 'msg "" 'over 0}))

; the tower holds: a stride into rock stands you still
(: g (hand-g ())
   _ (crawl-turn g [0 -1])
 (test (1 = g 'p 'x) (1 = g 'p 'y) (find (g 'msg) "the tower holds" 0)))

; pennies weigh in, and they are the only thing on the floor
(: g (hand-g ())
   _ (pin (g 'loot) (2 + 9 * 1) ['penny 7])
   _ (crawl-turn g [1 0])
 (test (7 = g 'p 'penny) (find (g 'msg) "pocket 7 pennies" 0) !(keys (g 'loot))))

; the bar is not a resource: a turn spent acting mends, a turn passed does not, and
; the mending stops at the brim
(: g (hand-g ())
   _ (pin (g 'p) 'hp 5)
   _ (crawl-turn g [1 0])
   _ (test (7 = g 'p 'hp))                       ; a step mends
   _ (crawl-turn g 46)
   _ (test (7 = g 'p 'hp))                       ; a pass does not
   _ (pin (g 'p) 'hp 19)
   _ (crawl-turn g [1 0])
 (test (20 = g 'p 'hp)))                         ; and never past the brim

; bump combat: the rat goes down inside its hit points
(: g (hand-g ())
   m (mob-new 0 2 1)
   _ (pin g 'ms [m])
   (fight i) (? (&& (i < 8) (g 'ms)) (crawl-turn g [1 0], fight (i + 1)) i)
   n (fight 0)
 (test !(g 'ms) (n <= 4) (find (g 'msg) "done for" 0)
         (1 = g 'p 'x)))                         ; you strike in place, never through

; the bite: cornered with one hp and standing still, you are done for -- and standing
; still is the only way there, a pass being the one turn that does not mend
(: g (hand-g ())
   _ (pin g 'ms [(mob-new 0 2 1)], pin (g 'p) 'hp 1)
   _ (crawl-turn g 46)
 (test ('dead = (g 'over)) (find (g 'msg) "done for" 0)))

; the pace: a garden mob stirs every turn, a heaven mob every other one, so the shapes
; can be walked past. row 5 is the d4 and it carries pace 2.
(: g (hand-g ())
   slow (mob-new 5 7 1) quick (mob-new 0 7 1)
 (test (1 = quick 'pc) (2 = slow 'pc)
         ("d4" = slow 'nm) ("rat" = quick 'nm)
         (due? {'tn 1} quick) (due? {'tn 2} quick)      ; every turn
         !(due? {'tn 1} slow) (due? {'tn 2} slow)))     ; every other one

; the floors bear their own tier, and nothing from another
(: (kinds lvl) (: g (crawl-new 60 20 (wheel 3))
                  _ (pin g 'lvl lvl)
                  _ (stock g)
                  (sort (keys (foldl (\ t m (pin t (nom (m 'nm)) 1)) {} (g 'ms)))))
   (all-in? ks nms) (foldl (\ a k (&& a (elem k nms))) 1 ks)
 (test
  (all-in? (kinds 1) '(rat lanternfly))
  (all-in? (kinds 2) '(gnome goblin hobgoblin))
  (all-in? (kinds 3) '(d4 d6 d8 d12 d20 triangle square hexagon))))

; the stair: < climbs only where the stair is cut, and restocks the floor. the
; imperative is restated on arrival, every time.
(: g (hand-g ())
   _ (crawl-turn g 60)
   _ (test (1 = g 'lvl) (find (g 'msg) "no stair" 0))
   _ (dput (g 'd) 1 1 2)
   _ (crawl-turn g 60)
 (test (2 = g 'lvl) (find (g 'msg) "the middle" 0) (find (g 'msg) "get the" 0)
         (1 = dat (g 'd) (g 'p 'x) (g 'p 'y))    ; standing on the fresh floor
         (tablet? (g 'loot))))

; --- the circle: the last floor is not a delve, and every hit draws the ring in one
; step with the wall following it down. it does not strike back; it only gives.
(: g (crawl-new 60 22 (wheel 3))
   _ (ascend g) _ (ascend g) _ (ascend g)
   ; stand due north of the ring, one cell outside it, and step in
   (hit! _) (: r (circle-r g)
             _ (pins (g 'p) 'x (g 'cx) 'y ((g 'cy) - (? (0 < r) (r + 1) 1)))
             (circle-stride g '(0 1)))
   _ (test (circle? g) (4 = g 'lvl) !(g 'ms) !(keys (g 'loot))
             (8 = circle-r g) (11 = circle-wall g) !(reveal? g)
             (find (g 'msg) "the circle" 0) (find (g 'msg) "get the" 0)
             (on-ring? g (g 'cx) ((g 'cy) - 8))          ; the ring stands at the radius
             (on-ring? g ((g 'cx) + 16) (g 'cy))         ; ..twice as wide, so it reads round
             !(on-ring? g ((g 'cx) + 8) (g 'cy)))
   _ (hit! ())
   _ (test (7 = circle-r g) (10 = circle-wall g)         ; one hit, one step, wall follows
             (find (g 'msg) "strike the circle" 0))
   (sink n) (? (g 'over) n (32 < n) n (: _ (hit! ()) (sink (n + 1))))
   n (sink 1)
 (test ('won = (g 'over)) (11 = n)                       ; eight steps in, then O, o, point
         (0 = circle-r g) (reveal? g)
         ; ..and the field it opens onto is the walk's own: tufts, bare and shrub
         (elem (<(turf 3 5)) '(34 46 35))))

; --- the whole game, generated: a seeded random walk holds every invariant ---
(: g (crawl-new 60 20 (wheel 3))
   kb {wheel 99}
   dirs [[1 0] [-1 0] [0 1] [0 -1] [1 1] [-1 -1] [1 -1] [-1 1] 46 62]
   (turn i ok) (? (&& (i < 300) !(g 'over)) (: k (peep dirs (roll kb 10) 46)
                   _ (crawl-turn g k)
                   p (g 'p)
                   (turn (i + 1)
                         (&& ok (open? (g 'd) (p 'x) (p 'y))
                                ((p 'hp) <= p 'mx)
                                (0 <= p 'penny))))
                ok)
 (test (turn 0 1)
         (|| (g 'over) (0 < g 'p 'hp))))

; --- the painter: one frame into a jug, glyphs and hues where they belong ---
(: g (crawl-new 60 20 (wheel 3))
   f (crawl-frame g)
 (test
  (string? f)
  (find f "@" 0)                                 ; you are on the map
  (find f "#" 0) (find f "." 0)                  ; walls and floor in the light
  (find f "the garden" 0) (find f "hp 20/20" 0)  ; the bar tells the tale
  (find f "\e[38;5;228m" 0)                      ; your hue, respecified on change
  (find f "\r\n" 0)))                            ; frames ride \r\n

(test_fin ())
(puts "tower: ok")
