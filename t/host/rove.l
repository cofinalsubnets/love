; --- t/host/rove.l: the rove engine and the climb it carries, headless ---
; not in the t/*.l corpus (it loads a crew file and leaks its helpers).
; the engine core is pure love, so everything but the tty runner gates here:
; delve (seeded, connected, bordered), fov (strides, walls, memory), the
; painter (a frame into a jug), the make of each floor and what it says, the helm
; decoder, the words and their holes, the sign the tower opens with, and
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
(: p1 (delve 60 20 (wheel 11) (plan 2))
   p2 (delve 60 20 (wheel 11) (plan 2))
   p3 (delve 60 20 (wheel 12) (plan 2))
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
                 pl {'x 1 'y 1 'gl 64 'hue 228 'hp 40 'mx 40 'penny 0}
                 {'d hd 'lvl 1 'tn 0 'sb sb 'p pl 'ms () 'loot (tablet 0) 'msg "" 'over 0}))

; the floor holds: a stride into rock stands you still, and the floor says its own name
(: g (hand-g ())
   _ (crawl-turn g [0 -1])
 (test (1 = g 'p 'x) (1 = g 'p 'y) (find (g 'msg) "the garden holds" 0)))

; the stream underfoot has its own lines, and they are about water
(: g (hand-g ())
   _ (dput (g 'd) 2 1 3)
   _ (crawl-turn g [1 0])
 (test (2 = g 'p 'x)                                    ; water is walked
       (any (w \ find (g 'msg) w 0) '("stream" "minnows" "fish" "cold"))))

; furniture stands where it is: bumped for its line, never walked onto, and
; remembered once seen
(: g (hand-g ())
   _ (pin (g 'loot) (2 + 9 * 1) '(table))
   _ (crawl-turn g [1 0])
 (test (1 = g 'p 'x) (find (g 'msg) "stone table" 0)
       ("π" = <(loot-face '(table) 1))
       ("π" = <(loot-face '(table) 0))
       (36 = <(loot-face '(penny 3) 1))))

; she is met, not struck: the bump puts up her sign and takes her off the floor, and
; the next key takes the sign down without moving you
(: g (hand-g ())
   _ (pin g 'her {'x 2 'y 1 'gl "x" 'hue 1})
   _ (crawl-turn g [1 0])
   _ (test (1 = g 'p 'x) (two? (g 'sign)) !(g 'her) (1 = #(ents g)))
   _ (crawl-turn g [1 0])
   _ (test (1 = g 'p 'x) !(g 'sign))
   _ (crawl-turn g [1 0])
 (test (2 = g 'p 'x)))

; a real climb: the garden has a stream and its two pieces of furniture, she is on the
; first three floors and not the circle, and the stream is never the stair
(: g (crawl-new 60 20 (wheel 11))
   d (g 'd)
   (wet _) (tally (filter (i \ 3 = dat d (i % 60) (i // 60)) ^(60 * 20)))
   (kind k) (any (i \ k = <(g 'loot i)) (keys (g 'loot)))
   (climb _) (: d (g 'd)                              ; this floor's stair, not the first's
                _ (pins (g 'p) 'x <(d 'stair) 'y <>(d 'stair))
                (crawl-turn g 60))
   _ (crawl-turn g 46)                                ; the opening sign, down
   _ (test (0 < wet ()) (kind 'table) (kind 'throne) (tablet? (g 'her))
           (2 = dat d <(d 'stair) <>(d 'stair)))
   _ (climb ())
   _ (test (2 = g 'lvl) (tablet? (g 'her)) !(kind 'table))
   _ (climb ())
   _ (test (3 = g 'lvl) (tablet? (g 'her)) (kind 'mirror) (kind 'fountain))
   _ (climb ())
 (test (circle? g) !(g 'her)))

; --- the city: streets on a grid, buildings between them with a floor and doors on
; different walls, the climber inside one, the two stairs inside two others, and all
; of it joined -- every open cell reachable from where you arrive
(: p (city 60 20 (wheel 7))
   d <p w 60 h 20
   rms (d 'rooms)
   (t x y) (dat d x y)
   (inside? rm x y) (peep rm 0 0 <= x && x < peep rm 0 0 + peep rm 2 1 &&
                     peep rm 1 0 <= y && y < peep rm 1 0 + peep rm 3 1)
   (in-room? x y) (any (rm \ inside? rm x y) rms)
   ; the doors of a room: the wall ring's cells that are doors, by the wall they are on
   (doors rm) (: x0 (peep rm 0 0 - 1) y0 (peep rm 1 0 - 1)
                 x1 (x0 + peep rm 2 1 + 1) y1 (y0 + peep rm 3 1 + 1)
                 (wall x y) (? (y = y0) 'n (y = y1) 's (x = x0) 'w 'e)
                 (filter two? (map (\ xy (5 = t <xy <>xy ? [(wall <xy <>xy)] ()))
                                   (cat (map (\ i [(x0 + i) y0]) ^(x1 - x0 + 1))
                                        (map (\ i [(x0 + i) y1]) ^(x1 - x0 + 1))
                                        (map (\ j [x0 (y0 + j)]) ^(y1 - y0 + 1))
                                        (map (\ j [x1 (y0 + j)]) ^(y1 - y0 + 1))))))
   (walls-of rm) (sort (keys (foldl (\ t dr (pin t <dr 1)) {} (doors rm))))
   flood (: mk (cask (w * h))
            (go stk n) (? !stk n
                        (: xy <stk x <xy y <>xy i (x + w * y)
                           (? (|| !(open? d x y) (peep mk i 0)) (go >stk n)
                            (: _ (pin mk i 1)
                               (go (cat [[(x + 1) y] [(x - 1) y] [x (y + 1)] [x (y - 1)]] >stk)
                                   (n + 1))))))
            (go [(d 'in)] 0))
   opens (tally (filter (i \ open? d (i % w) (i // w)) ^(w * h)))
   stairs (filter (i \ 2 = t (i % w) (i // w)) ^(w * h))
 (test
  (2 < #rms)                                             ; buildings enough
  (all (rm \ 2 <= #(walls-of rm)) rms)                   ; doors on two walls at least, each
  (all (rm \ (: m [(peep rm 0 0 + peep rm 2 1 // 2) (peep rm 1 0 + peep rm 3 1 // 2)]
                  (elem (t <m <>m) '(4 2)))) rms)        ; a floor inside, dark
  (in-room? <(d 'in) <>(d 'in))                          ; you arrive indoors
  (2 = #stairs)                                          ; two stairs up
  (all (i \ in-room? (i % w) (i // w)) stairs)           ; ..both of them in a building
  (flood = opens)                                        ; and every open cell reachable
  (0 < tally (filter (i \ 1 = t (i % w) (i // w)) ^(w * h)))))  ; streets, which cars want

; ..and every delved floor has its second stair too
(: d <(delve 60 20 (wheel 11) (plan 2))
 (test (2 = tally (filter (i \ 2 = dat d (i % 60) (i // 60)) ^(60 * 20)))))

; a car reaches you: ten off the bar, the horn asked for twice, you a step aside and the
; car still headed the way it was; walking into one is the same hurt. it is never struck.
(: g (hand-g ())
   c (car-new 2 1 -1 0 196)
   _ (pin g 'ms [c])
   _ (crawl-turn g 46)                                  ; a turn passed: the car comes
   _ (test (30 = g 'p 'hp) (find (g 'msg) "car" 0) (elem 'horn (g 'sfx))
           (-1 = c 'dx) ("◄" = c 'gl) (2 = c 'x)          ; ..and it is where it was, still headed your way
           (1 = g 'p 'x) (2 = g 'p 'y))                  ; you are off its line, the one way you could be
   _ (pin g 'sfx ())
   _ (pins (g 'p) 'x 1 'y 1)
   _ (crawl-turn g [1 0])                               ; you walk into it
 (test (20 <= g 'p 'hp && g 'p 'hp <= 22) (elem 'horn (g 'sfx)) (99 = c 'hp) (1 = g 'p 'x)))

; a car turns only at a corner -- the lane beside it is not one -- and goes off the map
; where its road does, to come in again at a gate, headed in
(: hd {'w 9 'h 5 't (cask 45) 'seen (cask 45) 'rooms ()}
   _ (each ^9 (x \ dput hd x 2 1))                     ; a road across, off the map both ends
   _ (each ^5 (y \ dput hd 4 y 1))                     ; ..and one along, crossing it
   _ (each '((0 2) (8 2) (4 0) (4 4)) (c \ dput hd <c <>c 6))
   g {'d hd 'lvl 2 'tn 0 'sb {(wheel 5)} 'p {'x 1 'y 3 'gl 64 'hue 228 'hp 40 'mx 40 'penny 0}
      'ms () 'loot (tablet 0) 'msg "" 'over 0 'gates '((0 2 1 0) (8 2 -1 0) (4 0 0 1) (4 4 0 -1))}
   c (car-new 6 2 1 0 196)
   _ (pin g 'ms [c])
   _ (test !(corner? hd 2 2 0 -1) (corner? hd 4 2 0 -1) (corner? hd 4 2 0 1)
           !(open? hd 8 2) (lit? hd 8 2) (road? hd 8 2))
   _ (crawl-turn g 46)                                  ; three cells: 7, 8, and off
 (test (6 = dat hd (c 'x) (c 'y))                      ; it is at a gate
       (road? hd (c 'x + c 'dx) (c 'y + c 'dy))))      ; ..headed in

; she says the floor's page: the middle's is not the garden's
(: g (hand-g ())
   _ (pin g 'lvl 2)
   _ (pin g 'her {'x 2 'y 1 'gl "x" 'hue 1})
   _ (crawl-turn g [1 0])
 (test (= >(g 'sign) (her-lines 2)) !(= (her-lines 1) (her-lines 2)) (= (her-lines 1) (her-lines 9))))

; a line wider than the screen is reflowed at its words, and the box still fits it
(: ln "the quick brown fox jumps over the lazy dog and keeps going past the edge of the screen"
   row (30 (\ t (t + ".")) "")
   f (: (go i acc) (i < 8 ? (go (i + 1) (acc + (0 < i ? "\r\n" "") + row)) acc) (go 0 ""))
   out (sign-over f "t" [ln] 0 8 30)
   (bare s) (: (go i acc) (? (i >= #s) acc
                             (27 = s i) (go (1 + find-m s i) acc)
                             (go (i + 1) (acc + string (s i))))
               (go 0 ""))
   (find-m s i) (109 = s i ? i (find-m s (i + 1)))
   rs (split "\r\n" out)
 (test (8 = #rs) (all (r \ #(bare r) <= 30) rs)
       (find out "the quick brown" 0) (find out "screen" 0)))

; glass is looked through and not walked: the lantern reaches past it, a stride does not
(: g (hand-g ())
   _ (dput (g 'd) 4 2 6)
   _ (pins (g 'p) 'x 3 'y 2)
   _ (crawl-turn g [1 0])
 (test (3 = g 'p 'x) (find (g 'msg) "nothing is there" 0)
       (clear? (g 'd) 3 2 5 2) (peep (g 'vis) (5 + 9 * 2) 0) !(open? (g 'd) 4 2) (lit? (g 'd) 4 2)))

; --- heaven: platforms in the void, every one a checkered rhombus with a stairway to the
; last, the void glass all round -- looked across and never entered -- and both stairs on
; a platform; every open cell reachable from where you arrive
(: p (sky 60 20 (wheel 11))
   d <p w 60 h 20
   rms (d 'rooms)
   (t x y) (dat d x y)
   (mid rm) [(peep rm 0 0 + peep rm 2 1 // 2) (peep rm 1 0 + peep rm 3 1 // 2)]
   flood (: mk (cask (w * h))
            (go stk n) (? !stk n
                        (: xy <stk x <xy y <>xy i (x + w * y)
                           (? (|| !(open? d x y) (peep mk i 0)) (go >stk n)
                            (: _ (pin mk i 1)
                               (go (cat [[(x + 1) y] [(x - 1) y] [x (y + 1)] [x (y - 1)]] >stk)
                                   (n + 1))))))
            (go [(d 'in)] 0))
   (count k) (tally (filter (i \ k = t (i % w) (i // w)) ^(w * h)))
   opens (tally (filter (i \ open? d (i % w) (i // w)) ^(w * h)))
   stairs (filter (i \ 2 = t (i % w) (i // w)) ^(w * h))
 (test (1 < #rms)
       (all (rm \ (: m (mid rm) (elem (t <m <>m) '(8 2)))) rms)          ; a platform under each middle
       (any (rm \ 6 = t (peep rm 0 0) (peep rm 1 0)) rms)                 ; ..and void at a corner: a rhombus, not a block
       (2 = #stairs) (flood = opens) (0 < count 7) (0 < count 6) (0 = count 0)
       (all (i \ lit? d (i % w) (i // w)) ^(w * h))))                     ; all of it looked through

; a mirror lets you out beside another, and alone it keeps you
(: g (hand-g ())
   _ (pin (g 'loot) (2 + 9 * 1) '(mirror))
   _ (crawl-turn g [1 0])
   _ (test (1 = g 'p 'x) (find (g 'msg) "keeps you" 0))
   _ (pin (g 'loot) (6 + 9 * 2) '(mirror))
   _ (crawl-turn g [1 0])
 (test (find (g 'msg) "takes you" 0)
       (|(g 'p 'x - 6) <= 1) (|(g 'p 'y - 2) <= 1) !(6 = g 'p 'x && 2 = g 'p 'y)))

; the platforms and the steps say what they are
(: g (hand-g ())
   _ (dput (g 'd) 2 1 8)
   _ (dput (g 'd) 3 1 7)
   _ (crawl-turn g [1 0])
   m1 (g 'msg)
   _ (crawl-turn g [1 0])
 (test (find m1 "squares" 0 || find m1 "stars" 0 || find m1 "checkers" 0)
       (find (g 'msg) "steps" 0)))

; the horn the game asked for is two voices in the song, at the write head, and the
; asking is spent by it
(: s (song-new ())
   g {'sfx '(horn) 'lvl 2 'st 0}
   _ (pin s 'fpos 4000)
   _ (song-tier s g)
 (test (2 = #(s 'vs)) !(g 'sfx)
       (all (v \ 4000 < v 0) (s 'vs))                  ; both end past the head
       (!(= (<(s 'vs) 0) ((s 'vs) 1 0)))))             ; ..and not together: one, then the other

; the shelf opens its book a page at a time: a key turns the page and takes no step, and
; the key after the last page closes it
(: g (hand-g ())
   _ (pin (g 'loot) (2 + 9 * 1) '(shelf))
   _ (crawl-turn g [1 0])
   _ (test (1 = g 'p 'x) (two? (g 'sign)) ("Muse" = <(g 'sign)) (find (g 'msg) "bookshelf" 0)
           (find (last (g 'sign)) "1 of 6" 0) (5 = #(g 'pages)))
   _ (crawl-turn g [1 0])
   _ (test (1 = g 'p 'x) (two? (g 'sign)) (find (last (g 'sign)) "2 of 6" 0))
   _ (each ^4 (_ \ crawl-turn g 46))
   _ (test (two? (g 'sign)) (find (last (g 'sign)) "6 of 6" 0) !(g 'pages))
   _ (crawl-turn g 46)
 (test !(g 'sign) (1 = g 'p 'x)))

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
   _ (pin (g 'p) 'hp 39)
   _ (crawl-turn g [1 0])
 (test (40 = g 'p 'hp)))                         ; and never past the brim

; ..and the bar is deep enough that one thing beside you is a nuisance: mending is two
; a turn and the heaviest bite in the book is three, so at the very worst a single mob
; takes a point a turn off forty. two of them bite four against the two and settle it,
; which is the death the climb keeps -- here with the climber standing still, which is
; the only way it ever happens.
(: g (hand-g ())
   _ (pin g 'ms [(mob-new 4 2 1) (mob-new 4 2 2)])   ; two hobgoblins, either side
   (go n) (? (g 'over) n (60 < n) n (: _ (crawl-turn g 46) (go (n + 1))))
   n (go 0)
 (test ('dead = g 'over) (n <= 30) (find (g 'msg) "done for" 0)))

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
  (all-in? (kinds 2) '(gnome goblin hobgoblin car))   ; ..and the middle's traffic
  (all-in? (kinds 3) '(d4 d6 d8 d12 d20 triangle square hexagon))))

; --- the make of a floor: a tier is built of its own stuff, and what a cell wears is
; the cell's own dice -- so a floor strews the same way twice, never out of another
; tier's table, and the two tiers never come out looking alike
(: (kit th) ((<(th 1)) . map (r \ <r) (th 2))    ; the ground, and what lies on it
   (marks th) (map (i \ <(tile-face th 1 1 (i % 40) (i // 40) 5)) ^400)
   (all-of? l ks) (foldl (\ a x (&& a (elem x ks))) 1 l)
 (test
  (all-of? (marks (themes 0)) (kit (themes 0)))
  (all-of? (marks (themes 1)) (kit (themes 1)))
  (all-of? (marks (themes 2)) (kit (themes 2)))
  ((marks (themes 0)) = (marks (themes 0)))      ; the dice are the cell's, not the clock's
  !((marks (themes 0)) = (marks (themes 1)))     ; and no two tiers wear the same face
  (elem 44 (marks (themes 0)))                   ; the garden does grow tufts
  (38 = <(tile-face (themes 0) 0 1 0 0 0))       ; hedge, stone, marble
  (35 = <(tile-face (themes 1) 0 1 0 0 0))
  (35 = <(tile-face (themes 2) 0 1 0 0 0))
  (28 = ((tile-face (themes 0) 0 1 0 0 0) 1))    ; lit and remembered are two pens
  (22 = ((tile-face (themes 0) 0 0 0 0 0) 1))
  (60 = <(tile-face (themes 0) 2 1 0 0 0))       ; and the stair is gold on every floor
  (220 = ((tile-face (themes 2) 2 1 0 0 0) 1))))

; --- the flavour: nothing on a floor is silent, and nothing says one thing only
(: (says? nm) (0 < #(mutter 0 nm))
   (all-say? l) (foldl (\ a nm (&& a (says? nm))) 1 l)
   (strewings th) (map (r \ (r 4)) (th 2))
 (test
  (all-say? (strewings (themes 0)))                ; every strewing of every tier
  (all-say? (strewings (themes 1)))
  (all-say? (strewings (themes 2)))
  (all-say? (map (k \ ((mob-new k 0 0) 'nm)) ^13)) ; ..and every mob in the book
  !(says? "the man in the moon")                   ; a name with no row is silent
  (: t (foldl (\ t k (pin t (mutter k "tuft") 1)) {} ^9)
     (1 < #(keys t)))))                            ; and one thing says several

; ..and it is said when you stand on it: the cell picks the line, so the same cell
; says the same thing every time you cross it
(: g (hand-g ())
   _ (pin (g 'd) 'th (themes 0))
   (salt n) (? (99 < n) 0
               (: _ (pin (g 'd) 'sd n) (0 < #(underfoot g 2 1)) n (salt (n + 1))))
   _ (pin (g 'd) 'sd (salt 0))
   s (underfoot g 2 1)
   _ (crawl-turn g [1 0])
 (test (0 < #s) (find (g 'msg) s 0) (s = underfoot g 2 1)))

; ..and a mob says its piece the first time you lay into it, and only then
(: g (hand-g ())
   _ (pin g 'ms [(mob-new 0 2 1)])
   (rat? t) (|| (find t (mutter 0 "rat") 0) (find t (mutter 1 "rat") 0))
   _ (crawl-turn g [1 0])
   f (g 'msg)
   _ (crawl-turn g [1 0])
 (test (rat? f) !(rat? (g 'msg))))

; ..nor are the tiers laid out alike: the garden is a patch of small beds, heaven a
; few long blocks, and the plan is the whole of the difference
(: gd <(delve 70 20 (wheel 5) (plan 1))
   hv <(delve 70 20 (wheel 5) (plan 3))
   (span rs) ((net (map (r \ (r 2) * (r 3)) rs)) // #rs)
 (test (#(hv 'rooms) < #(gd 'rooms))
         ((span (gd 'rooms)) < (span (hv 'rooms)))))

; ..and a floor is dressed when it is cut, the stair changing what the next one is made of
(: g (crawl-new 40 16 (wheel 7))
   t1 (g 'd 'th)
   _ (ascend g)
 (test ((themes 0) = t1) ((themes 1) = (g 'd 'th)) (charm? (g 'd 'sd))))

; the stair: < climbs only where the stair is cut, and restocks the floor. the
; imperative is restated on arrival, every time.
(: g (hand-g ())
   _ (crawl-turn g 60)
   _ (test (1 = g 'lvl) (find (g 'msg) "no stair" 0))
   _ (dput (g 'd) 1 1 2)
   _ (crawl-turn g 60)
 (test (2 = g 'lvl) (find (g 'msg) "the middle" 0) (find (g 'msg) "get the" 0)
         (elem (dat (g 'd) (g 'p 'x) (g 'p 'y)) '(1 4 8))   ; standing on the fresh floor, in a building, on a platform
         (60 = g 'p 'mx) (60 = g 'p 'hp)         ; a climb is twenty more of the bar
         (tablet? (g 'loot))))

; ..and the same climb by the keys a seat with no < to hand has: enter, return, space
(: (climbs? k) (: g (hand-g ())
                  _ (dput (g 'd) 1 1 2)
                  _ (crawl-turn g k)
                  (2 = g 'lvl))
 (test (climbs? 60) (climbs? 32) (climbs? 13) (climbs? 10)
       !(climbs? 46)))                           ; a turn passed is still a turn passed

; a tap is a place: one step of the eight toward the cell it landed on, however far off
; it lands, and the cell you stand on is the stair. the note row is the screen's first,
; so a floor y is a screen y less one.
(: g (hand-g ())
   p (g 'p)
   (tap x y) (tap-steer g [x y])
 (test (60 = tap (p 'x) (p 'y + 1))
       ('(1 0) = tap (p 'x + 4) (p 'y + 1))
       ('(-1 0) = tap (p 'x - 4) (p 'y + 1))
       ('(0 -1) = tap (p 'x) (p 'y - 3))
       ('(0 1) = tap (p 'x) (p 'y + 6))
       ('(-1 -1) = tap (p 'x - 2) (p 'y - 2))
       ('(1 1) = tap (p 'x + 9) (p 'y + 9))))

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
   row0 (map (x \ skin-pen g x 4) ^60)                  ; the field, before any of it
   sk0 (peep (g 'sk) [4 30] 0.0)
   ; while the ring is wide the front stands past the far corner, so the floor is
   ; grass all the way out and the pink is nowhere on it yet
   _ (test (1.0 = pink-front g)
             (foldl (\ a v (&& a (elem v grass-ramp))) 1 row0)
             (1 < #(keys (foldl (\ t v (pin t v 1)) {} row0))))
   _ (hit! ())
   _ (test (7 = circle-r g) (10 = circle-wall g)         ; one hit, one step, wall follows
             (find (g 'msg) "strike the circle" 0)
             (1.0 = pink-front g))                       ; ..and the floor is grass still
   (sink n) (? (g 'over) n (32 < n) n (: _ (hit! ()) (sink (n + 1))))
   n (sink 1)
 (test ('won = (g 'over)) (11 = n)                       ; eight steps in, then O, o, point
         (0 = circle-r g) (reveal? g)
         (0.45 = pink-front g)
         ; the wave itself never moved: it is one frame of the walk's shimmer, held
         ; still, and the same frame it was eleven strikes ago
         (sk0 = peep (g 'sk) [4 30] 0.0)
         ; what moved is which ramp a cell reads off. the middle is still the grass
         ; the climber came up through and the far ends have gone over to slop's pink,
         ; and both are graded and neither is flat
         ; the middle row -- the ring is an ellipse in cells, and row 4 is far enough
         ; off the middle of it to be out past the front on its own
         (: row1 (map (x \ skin-pen g x 11) ^60)
            (&& (elem (row1 30) grass-ramp)
                (&& (elem (row1 0) pink-ramp) (elem (row1 59) pink-ramp))
                (1 < #(keys (foldl (\ t v (pin t v 1)) {} row1)))))))

; ..and the front itself, which is the whole of the grading law: past the corner of
; the board -- which is to say nowhere on it -- for as long as the ring is at half the
; size it started, and in only as the second half of the work is done
(: g (crawl-new 60 22 (wheel 3))
   _ (ascend g) _ (ascend g) _ (ascend g)
   (front st) (: _ (pin g 'st st) (pink-front g))        ; st strikes in, so r is 8 - st
 (test (1.0 = front 0) (1.0 = front 1) (1.0 = front 4)   ; r 8, 7, 4: no pink anywhere
         ((front 5) < 1.0)                               ; r 3: it starts in
         ((front 6) < (front 5)) ((front 8) < (front 6))  ; ..and keeps coming
         (0.45 = front 8)))                              ; r 0: and stops well short

; ..and the door the last hit opens: the walk PROPER, not the verb, since the stage
; the climb raised is the one the slop is to run on. a missed cite is a silent end.
(test !(() = (cite 'slop 'slop-walk)))

; --- the sign: the tower holds one up before a step is taken, the first key buys its
; coming down and nothing else, and the bar under it is never covered
(: g (crawl-new 40 16 (wheel 7))
   f (crawl-frame g)
   x (g 'p 'x) y (g 'p 'y)
   _ (crawl-turn g [1 0])
   f2 (crawl-frame g)
 (test (find f "+-the tower " 0)                ; the box, titled the way story titles
         (find f "h j k l" 0)                    ; the keys are on it
         (find f "climb" 0)                      ; ..and so is the stair
         (find f "the garden  hp 40/40" 0)       ; the bar is not covered
         (#(split "\r\n" f) = #(split "\r\n" f2))   ; a sign costs no rows
         (x = g 'p 'x) (y = g 'p 'y)             ; the key that took it down took no turn
         !(find f2 "+-the tower " 0)))

; --- the stair says what it is when you stand on it, and the bar says what to do
(: g (hand-g ())
   _ (pins (g 'd) 'th (themes 0) 'sd 3)
   _ (dput (g 'd) 2 1 2)                         ; a stair cut to the right of you
   s (underfoot g 2 1)
   _ (crawl-turn g [1 0])
 (test (0 < #s) (find (g 'msg) s 0)
         (find (crawl-bar g) "< climbs" 0)       ; ..only while you are on it
         (: h (hand-g ()) !(find (crawl-bar h) "< climbs" 0))))

; --- pennies: a thing that goes down leaves some, the ground carries more, and they
; say something for themselves when you pick them up
(: g (hand-g ())
   _ (pin g 'ms [(mob-new 0 2 1)])
   (fight i) (? (&& (i < 8) (g 'ms)) (crawl-turn g [1 0], fight (i + 1)) i)
   _ (fight 0)
   it (peep (g 'loot) (2 + 9 * 1) ())
   _ (test (two? it) ('penny = <it) (0 < <>it))  ; it dropped them where it stood
   n <>it
   _ (crawl-turn g [1 0])
   (says? t) (foldl (\ a k (|| a (find t (mutter k "pennies") 0))) 0 ^4)
 (test (n = g 'p 'penny) (find (g 'msg) "pennies" 0) (says? (g 'msg))))

; ..and a fresh floor is not miserly: every room bar your own carries a pile or more
(: g (crawl-new 60 20 (wheel 3))
 (test (#(g 'd 'rooms) <= #(keys (g 'loot)))))

; --- the music: a floor's bar is built off the cycle, and the circle's off the ring.
; no gate can listen, so what is held is what a bar HOLDS -- the slots, their count,
; and the way each floor's rule answers a different bar as the cycle runs on
(: g (crawl-new 60 22 (wheel 3))
   _ (ascend g) _ (ascend g) _ (ascend g)
   (vat st) (: _ (pin g 'st st) (song-vol g))
   (hits bs) (foldl (\ a b (a + (foldl (\ t v (t + (tablet? v ? 1 0))) 0 b))) 0 bs)
   (slots bs) (foldl (\ a b (a + #b)) 0 bs)
   ; every slot is a voice play can sound, or nothing at all -- there is no third thing
   (sane? bs) (foldl (\ a b (&& a (foldl (\ t v (&& t (? (tablet? v) (string? (v 's)) !v))) 1 b))) 1 bs)
   (over n f) (foldl (\ a c (a + (f c))) 0 ^n)
 (test
  (#floors = #songs)                             ; a floor, a loudness
  (foldl (\ a v (&& a (0.0 < v))) 1 songs)
  ; the garden: sixteen slots to the bar, mostly empty, and never the same two bars
  (16 = slots (garden-bars 0)) (16 = slots (garden-bars 7))
  (sane? (garden-bars 3))
  (0 < over 40 (c \ hits (garden-bars c)))
  (0 < over 40 (c \ (16 > hits (garden-bars c)) ? 1 0))
  ((garden-bars 0) != (garden-bars 1))
  ; the middle: two bars to a horn, struck in the SAME slots -- one horn, two notes
  (: bs (middle-bars 4)
     (&& (2 = #bs)
         (foldl (\ a i (&& a ((tablet? (<bs i)) = (tablet? ((bs 1) i))))) 1 ^12)))
  ; ..and now and then it is a tune instead, which holds for a whole run of bars
  (0 < over 200 (c \ (tune? c) ? 1 0))
  (0 < over 200 (c \ (tune? c) ? 0 1))
  (foldl (\ a c (&& a ((tune? c) = (tune? (5 * (c // 5)))))) 1 ^40)
  ; heaven: one bar of one sequence, and the four bars of a block are that sequence
  ; taken in order -- so bar 0 and bar 4 are different bars of it, or another one
  (1 = #(sky-bars 0)) (sane? (sky-bars 0))
  (0 < hits (sky-bars 0))
  ((sky-bars 0) != (sky-bars 1))
  ; the circle: a heart, and the beats further apart the smaller the ring is
  ((heart-rate 2) < (heart-rate 5)) ((heart-rate 5) < (heart-rate 8))
  (1 = heart-rate 0)
  ((slots (heart-bars 2)) < (slots (heart-bars 8)))
  (4 = hits (heart-bars 0))                      ; lub and dub, two voices each
  (2 = #(heart-bars 0))                          ; ..the kick you feel and the knock you hear
  (sane? (heart-bars 8))
  ; the fade is the ring's own size
  (1.0 = vat 0)
  ((vat 4) < (vat 0)) ((vat 6) < (vat 4))
  (0.0 = vat 8)
  (: h (crawl-new 20 10 (wheel 1)) (0 < song-vol h))   ; a floor with rooms just plays
  ; and every floor's bar goes through harp and comes out a pattern
  !(() = tower-tune 1 0 0) !(() = tower-tune 2 0 0)
  !(() = tower-tune 3 0 0) !(() = tower-tune 4 0 8)))

; --- the whole game, generated: a seeded random walk holds every invariant ---
; the keys come out of a BOXED wheel state -- {wheel 99} boxes the wheel itself, whose
; roll answers () forever, and a walk of three hundred passes holds anything you like
(: g (crawl-new 60 20 (wheel 3))
   kb {(wheel 99)}
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
; the sign comes down first: it is laid OVER the frame, and a garden behind a box is
; not what this is looking at
(: g (crawl-new 60 20 (wheel 3))
   _ (pin g 'sign ())
   f (crawl-frame g)
 (test
  (string? f)
  (find f "@" 0)                                 ; you are on the map
  (find f "&" 0) (find f "." 0)                  ; the garden's hedge and its earth
  (any (n \ find f ("\e[38;5;" + show n + "m") 0)  ; ..the dirt in one of its browns
       '(180 137 136 94 95 58))
  (find f "the garden" 0) (find f "hp 40/40" 0)  ; the bar tells the tale
  (find f "\e[38;5;228m" 0)                      ; your hue, respecified on change
  (find f "\r\n" 0)))                            ; frames ride \r\n

; --- the sign covers the field, and does not eat it ---------------------------------
; sign-over lays a box over the middle rows of a frame. the rows it covers must still
; carry every cell they did: a row that stops at the box leaves the cells past it holding
; whatever the LAST frame wrote there, and the floor before this one is where that comes
; from -- which reads as the level before standing in colour beside the box.
; the row ends on \e[K the way a painted one does: an escape with no m, which a skip
; that only looks for the m walks off the end of.
(: sw 40
   srow ("\e[38;5;34m" + (string (map (\ _ 46) ^sw)) + "\e[0m\e[K")
   sf (: (go k acc) (? (6 <= k) acc (go (k + 1) (acc + (0 < k ? "\r\n" "") + srow)))
         (go 0 ""))
   sout (sign-over sf "sign" ["a line"] 0 6 sw)
   ; cells, counting a whole escape run as none of them
   (scells r) (: (past i) (i >= #r ? i (r i @ 109 (i + 1) (past (i + 1))))
                 (go i k) (? (i >= #r) k
                             (r i @ 27 (past i @ e (go e k)) (go (i + 1) (k + 1))))
                 (go 0 0))
   srs (split "\r\n" sout)
 (test
  (6 = #srs)
  (all (r \ sw = scells r) srs)                  ; every row, its whole width
  (find sout "sign" 0)                           ; ..and the box is really on it
  (all (r \ find r "\e[38;5;34m" 0) srs)         ; the field's pen survives the box
  (all (r \ find r "\e[K" 0) srs)))            ; ..and so does the erase it ends on

(test_fin ())
(puts "tower: ok")
