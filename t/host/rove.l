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
   row0 (map (x \ skin-pen g x 4) ^60)                  ; the field, before any of it
   _ (hit! ())
   _ (test (7 = circle-r g) (10 = circle-wall g)         ; one hit, one step, wall follows
             (find (g 'msg) "strike the circle" 0))
   (sink n) (? (g 'over) n (32 < n) n (: _ (hit! ()) (sink (n + 1))))
   n (sink 1)
 (test ('won = (g 'over)) (11 = n)                       ; eight steps in, then O, o, point
         (0 = circle-r g) (reveal? g)
         ; ..and the field it opens onto is the walk's own shimmer with the clock
         ; taken out of it: every pen off the pink ramp, graded and not flat, and the
         ; same frame it was when the floor opened, eleven strikes ago
         (: row1 (map (x \ skin-pen g x 4) ^60)
            (&& (row0 = row1)
                (1 < #(keys (foldl (\ t v (pin t v 1)) {} row1)))
                (foldl (\ a v (&& a (elem v pink-ramp))) 1 row1)))))

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
         (find f "the garden  hp 20/20" 0)       ; the bar is not covered
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
  (find f "\e[38;5;143m" 0)                      ; ..in the earth's own pen
  (find f "the garden" 0) (find f "hp 20/20" 0)  ; the bar tells the tale
  (find f "\e[38;5;228m" 0)                      ; your hue, respecified on change
  (find f "\r\n" 0)))                            ; frames ride \r\n

(test_fin ())
(puts "tower: ok")
