; test/host/rove.l -- the rove engine and the tower's climb, headless; test/host/tty.l
; plays the tty runner. not in the corpus: it leaks its helpers.
; run: cat test/00-init.l test/host/rove.l | out/love

(borrow 'rove)
(borrow 'tower)

; delve: a seed reproduces its floor; floors are connected and bordered
(: p1 (delve 60 20 (wheel 11) (plan 2))
   p2 (delve 60 20 (wheel 11) (plan 2))
   p3 (delve 60 20 (wheel 12) (plan 2))
   d <p1
   (teq a b) (: (go i ok) (i < 1200 ? (go (i + 1) (ok && peep (a 't) i 0 = peep (b 't) i 0)) ok)
                (go 0 1))
   flood (: mk (cask 1200)
            (go stk n) (!stk ? n (: xy <stk x <xy y <>xy i (x + 60 * y)
                           (!(open? d x y) || peep mk i 0 ? (go >stk n) (pin mk i 1,
                             go (cat [[(x + 1) y] [(x - 1) y] [x (y + 1)] [x (y - 1)]] >stk)
                                   (n + 1)))))
            (go [(d 'in)] 0))
   floors (: (go i n) (i < 1200 ? (go (i + 1) (n + (0 < peep (d 't) i 0 ? 1 0))) n)
             (go 0 0))
   rim (: (go i bad) (i < 60 ? (go (i + 1) (bad || dat d i 0 || dat d i 19)) (: (gov j b2) (j < 20 ? (gov (j + 1) (b2 || dat d 0 j || dat d 59 j)) b2)
                          (gov 0 bad)))
          (go 0 0))
 (test
  (teq <p1 <p2)
  !(teq <p1 <p3)
  (1 < #(d 'rooms))
  (1 = dat d <(d 'in) <>(d 'in))
  (2 = dat d <(d 'stair) <>(d 'stair))
  (flood = floors)
  !rim))

; fov: light reaches, rock blocks, the seen cask remembers. two rooms split at x=4:
;   #########
;   #...#...#
;   #...#...#
;   #...#...#
;   #########
(: hd {'w 9 'h 5 't (cask 45) 'seen (cask 45) 'rooms [[1 1 3 3] [5 1 3 3]]}
   _ (map (y \ (map (x \ (x = 4 ? () (dput hd x y 1))) '(1 2 3 4 5 6 7))) '(1 2 3))
   v (fov hd 1 1 8)
   (test (peep v (1 + 9 * 1) 0)
         (peep v (3 + 9 * 1) 0)
         (peep v (4 + 9 * 1) 0)                         ; the wall catches the light
         !(peep v (5 + 9 * 1) 0)
         !(peep v (7 + 9 * 3) 0)
         (peep v 0 0)                                   ; the corner wall glows (adjacency)
         (peep (hd 'seen) (3 + 9 * 1) 0)
         !(peep (hd 'seen) (5 + 9 * 1) 0),
    (fov hd 5 2 8 @ v2
  (test
   (peep v2 (5 + 9 * 1) 0)
   !(peep v2 (1 + 9 * 1) 0)
   (peep (hd 'seen) (1 + 9 * 1) 0)
   (peep (hd 'seen) (6 + 9 * 2) 0)))))

; the helm: arrows, hjkl yubn, alt letters; anything else is itself
(test
 ('(0 -1) = steer -8) ('(0 1) = steer -9) ('(1 0) = steer -2) ('(-1 0) = steer -1)
 (27 = steer 27)
 ('(-1 0) = steer 104) ('(0 1) = steer 106) ('(0 -1) = steer 107) ('(1 0) = steer 108)
 ('(-1 -1) = steer 121) ('(1 -1) = steer 117) ('(-1 1) = steer 98) ('(1 1) = steer 110)
 ('(-1 -1) = steer 377) ('(1 1) = steer 366)
 (62 = steer 62)
 (113 = steer 113))

; the words: a line fills its holes, and wears its braces at the port
(test
 ("you strike the rat (2)" = fill "you strike the ~ (~)" ["rat" 2])
 ("nothing to fill" = fill "nothing to fill" ())
 ("abc" = fit "abcdef" 3)
 (has? (fit "a {b} c" 40) "38;5;201")               ; the token's pen goes on
 (has? (fit "{abcde}" 5) "abcde")                   ; an escape costs no width
 !(has? (fit "{abcde}" 3) "abcde")                  ; so the cut is honest
 ("日本" = fit "日本語" 5)                               ; a wide character is two cells
 ("a" = fit "a日" 2)                                   ; one crossing the edge stays off
 (4 = vlen "{日本}"))

; the climb on a hand floor: every verb of the game, deterministic
(: (hand-g _) (: hd {'w 9 'h 5 't (cask 45) 'seen (cask 45) 'rooms [[1 1 3 3] [5 1 3 3]]}
                 _ (map (y \ (map (x \ (x = 4 ? () (dput hd x y 1))) '(1 2 3 4 5 6 7))) '(1 2 3))
                 _ (pin hd 'in [1 1], pin hd 'stair [7 3])
                 st (wheel 5) sb {st}
                 pl {'x 1 'y 1 'gl 64 'hue 228 'hp 40 'mx 40 'penny 0}
                 {'d hd 'lvl 1 'tn 0 'sb sb 'p pl 'ms () 'loot {} 'msg "" 'over 0}))

; a stride into rock stands you still, and the floor says its name
(hand-g () @ g
 (crawl-turn g [0 -1],
  test (1 = g 'p 'x) (1 = g 'p 'y) (0 < #(g 'msg))))

(hand-g () @ g
 (dput (g 'd) 2 1 3,
  crawl-turn g [1 0],
  test (2 = g 'p 'x)
       (0 < #(g 'msg))))

; furniture is bumped for its line, never walked onto, and remembered once seen
(hand-g () @ g
 (pin (g 'loot) (2 + 9 * 1) '(table),
  crawl-turn g [1 0],
  test (1 = g 'p 'x) (0 < #(g 'msg))
       (<(loot-face '(table) 1) = <(loot-face '(table) 0))
       (charm? <(loot-face '(penny 3) 1))))

; she is met, not struck: her sign goes up and she leaves; the next key takes it down, no step
(hand-g () @ g
 (pin g 'her {'x 2 'y 1 'gl "x" 'hue 1},
  crawl-turn g [1 0],
  test (1 = g 'p 'x) (two? (g 'sign)) !(g 'her) (1 = #(ents g)),
  crawl-turn g [1 0],
  test (1 = g 'p 'x) !(g 'sign),
  crawl-turn g [1 0],
  test (2 = g 'p 'x)))

; a real climb: the garden's stream and furniture, she on every floor, the stream never the stair
(: g (crawl-new 60 20 (wheel 11))
   d (g 'd)
   (wet _) #(filter (i \ 3 = dat d (i % 60) (i // 60)) ^(60 * 20))
   (kind k) (any (i \ k = <(g 'loot i)) (keys (g 'loot)))
   (climb _) (g 'd @ d
              ((pins (g 'p) 'x <(d 'stair) 'y <>(d 'stair)),
               crawl-turn g 60))
   (crawl-turn g 46,
    test (0 < wet ()) (kind 'table) (kind 'throne) (tablet? (g 'her))
         (2 = dat d <(d 'stair) <>(d 'stair)),
    climb (),
    test (2 = g 'lvl) (tablet? (g 'her)) !(kind 'table),
    climb (),
    test (3 = g 'lvl) (tablet? (g 'her)) (kind 'mirror) (kind 'fountain),
    climb (),
    test (circle? g) (tablet? (g 'her))))

; the city: buildings with doors on two walls, you and both stairs indoors, all of it reachable
(: p (city 60 20 (wheel 7))
   d <p w 60 h 20
   rms (d 'rooms)
   (t x y) (dat d x y)
   (inside? rm x y) (peep rm 0 0 <= x && x < peep rm 0 0 + peep rm 2 1 &&
                     peep rm 1 0 <= y && y < peep rm 1 0 + peep rm 3 1)
   (in-room? x y) (any (rm \ inside? rm x y) rms)
   (doors rm) (: x0 (peep rm 0 0 - 1) y0 (peep rm 1 0 - 1)
                 x1 (x0 + peep rm 2 1 + 1) y1 (y0 + peep rm 3 1 + 1)
                 (wall x y) (? (y = y0) 'n (y = y1) 's (x = x0) 'w 'e)
                 (filter two? (map (xy \ (5 = t <xy <>xy ? [(wall <xy <>xy)] ()))
                                   (cat (map (i \ [(x0 + i) y0]) ^(x1 - x0 + 1))
                                        (map (i \ [(x0 + i) y1]) ^(x1 - x0 + 1))
                                        (map (j \ [x0 (y0 + j)]) ^(y1 - y0 + 1))
                                        (map (j \ [x1 (y0 + j)]) ^(y1 - y0 + 1))))))
   (walls-of rm) (sort (keys (foldl (t \ dr \ (pin t <dr 1)) {} (doors rm))))
   flood (: mk (cask (w * h))
            (go stk n) (!stk ? n (: xy <stk x <xy y <>xy i (x + w * y)
                           (!(open? d x y) || peep mk i 0 ? (go >stk n) (pin mk i 1,
                             go (cat [[(x + 1) y] [(x - 1) y] [x (y + 1)] [x (y - 1)]] >stk)
                                   (n + 1)))))
            (go [(d 'in)] 0))
   opens #(filter (i \ open? d (i % w) (i // w)) ^(w * h))
   stairs (filter (i \ 2 = t (i % w) (i // w)) ^(w * h))
   ; every road cell has a lane, and its mate beside it runs the other way
   roads (filter (i \ elem (t (i % w) (i // w)) '(1 6)) ^(w * h))
   (ln x y) (lane-at d x y)
   (two-lane? i) (: x (i % w) y (i // w) l (ln x y)
                    ((<l != 0 || <>l != 0) &&
                     (<l = 0 || any (o \ <(ln x (y + o)) = 0 - <l) '(-1 1)) &&
                     (<>l = 0 || any (o \ <>(ln (x + o) y) = 0 - <>l) '(-1 1))))
 (test
  (all two-lane? roads)
  (2 < #rms)
  (all (rm \ 2 <= #(walls-of rm)) rms)
  (all (rm \ ([(peep rm 0 0 + peep rm 2 1 // 2) (peep rm 1 0 + peep rm 3 1 // 2)] @ m
                  (elem (t <m <>m) '(4 2)))) rms)
  (in-room? <(d 'in) <>(d 'in))
  (2 = #stairs)
  (all (i \ in-room? (i % w) (i // w)) stairs)
  (flood = opens)
  (0 < #(filter (i \ 1 = t (i % w) (i // w)) ^(w * h)))))

(: d <(delve 60 20 (wheel 11) (plan 2))
 (test (2 = #(filter (i \ 2 = dat d (i % 60) (i // 60)) ^(60 * 20)))))

; a car hits for ten and honks, puts you aside and keeps its heading; walking into one
; hurts the same, and it is never struck
(: g (hand-g ())
   c (car-new 2 1 -1 0 196)
   (pin g 'ms [c],
    crawl-turn g 46,
    test (30 = g 'p 'hp) (has? (g 'msg) "car") (elem 'horn (g 'sfx))
         (-1 = c 'dx) ("◄" = c 'gl) (2 = c 'x)
         (1 = g 'p 'x) (2 = g 'p 'y),
    pin g 'sfx (),
    pins (g 'p) 'x 1 'y 1,
    crawl-turn g [1 0],
    test (20 <= g 'p 'hp && g 'p 'hp <= 22) (elem 'horn (g 'sfx)) (99 = c 'hp) (1 = g 'p 'x)))

; a car turns only where the lane runs the turn's way, and leaves the map to re-enter at a gate
(: hd {'w 9 'h 5 't (cask 45) 'seen (cask 45) 'rooms () 'lane {} 'solid '(6)}
   _ (each ^9 (x \ (dput hd x 2 1, pin (hd 'lane) (x + 9 * 2) '(1 0))))
   _ (each ^5 (y \ (dput hd 4 y 1, pin (hd 'lane) (4 + 9 * y) '(0 -1))))
   _ (pin (hd 'lane) (4 + 9 * 2) '(1 -1))
   _ (each '((0 2) (8 2) (4 0) (4 4)) (c \ dput hd <c <>c 6))
   g {'d hd 'lvl 2 'tn 0 'sb {(wheel 5)} 'p {'x 1 'y 3 'gl 64 'hue 228 'hp 40 'mx 40 'penny 0}
      'ms () 'loot {} 'msg "" 'over 0 'gates '((0 2 1 0) (4 4 0 -1))}
   c (car-new 6 2 1 0 196)
   (pin g 'ms [c],
    test !(corner? hd 2 2 0 -1) (corner? hd 4 2 0 -1) !(corner? hd 4 2 0 1)
         !(open? hd 8 2) (lit? hd 8 2) (road? hd 8 2),
    crawl-turn g 46,
    test (6 = dat hd (c 'x) (c 'y))
         (road? hd (c 'x + c 'dx) (c 'y + c 'dy))))

; a fresh middle's cars and gates all run along their lanes
(: g (crawl-new 60 20 (wheel 11))
   _ (crawl-turn g 46)
   _ (pins (g 'p) 'x <(g 'd 'stair) 'y <>(g 'd 'stair))
   _ (crawl-turn g 60)
   d (g 'd)
   cars (filter (m \ m 'car) (g 'ms))
   (on-lane? x y dx dy) (lane-at d x y @ l (dx != 0 ? (<l = dx) (<>l = dy)))
 (test (2 = g 'lvl) (two? cars) (two? (g 'gates))
       (all (m \ road? d (m 'x) (m 'y) && on-lane? (m 'x) (m 'y) (m 'dx) (m 'dy)) cars)
       (all (e \ 6 = dat d <e (e 1) && on-lane? <e (e 1) (e 2) (e 3)) (g 'gates))))

; the middle's lamps sit on street-facing walls, its braziers indoors
(: g (crawl-new 60 20 (wheel 11))
   _ (crawl-turn g 46)
   _ (pins (g 'p) 'x <(g 'd 'stair) 'y <>(g 'd 'stair))
   _ (crawl-turn g 60)
   d (g 'd) w 60
   (of k) (filter (i \ k = <(g 'loot i)) (keys (g 'loot)))
   lamps (of 'lamp) coals (of 'brazier)
   (t i) (dat d (i % w) (i // w))
   (by-street? i) (: x (i % w) y (i // w)
                     (any (o \ 1 = dat d (x + <o) (y + <>o)) '((-1 0) (1 0) (0 -1) (0 1))))
 (test (2 = g 'lvl) (two? lamps) (two? coals)
       (all (i \ 0 = t i) lamps) (all by-street? lamps)
       (all (i \ 4 = t i) coals)))

(hand-g () @ g
 (pin g 'lvl 2,
  pin g 'her {'x 2 'y 1 'gl "x" 'hue 1},
  crawl-turn g [1 0],
  test (>(g 'sign) = her-lines 2) !(her-lines 1 = her-lines 2) (her-lines 1 = her-lines 9)))

; a line wider than the screen reflows at its words, and the box still fits
(: ln "the quick brown fox jumps over the lazy dog and keeps going past the edge of the screen"
   row (30 (t \ (t + ".")) "")
   f (: (go i acc) (i < 8 ? (go (i + 1) (acc + (0 < i ? "\r\n" "") + row)) acc) (go 0 ""))
   out (sign-over f "t" [ln] 0 8 30)
   (bare s) (: (go i acc) (? (i >= #s) acc
                             (27 = s i) (go (1 + find-m s i) acc)
                             (go (i + 1) (acc + string (s i))))
               (go 0 ""))
   (find-m s i) (109 = s i ? i (find-m s (i + 1)))
   rs (split "\r\n" out)
 (test (8 = #rs) (all (r \ #(bare r) <= 30) rs)
       (has? out "the quick brown") (has? out "screen")))

; a cell is a character, not a byte: a box over three-byte blocks keeps every row screen-wide
(: blk "\xe2\x96\x88"
   row (30 (t \ (t + blk)) "")
   f (: (go i acc) (i < 6 ? (go (i + 1) (acc + (0 < i ? "\r\n" "") + "\e[38;5;33m" + row)) acc) (go 0 ""))
   out (sign-over f "t" ["a line"] 0 6 30)
   (bare s) (: (go i acc) (? (i >= #s) acc
                             (27 = s i) (go (1 + find-m s i) acc)
                             (go (i + 1) (acc + string (s i))))
               (go 0 ""))
   (find-m s i) (109 = s i ? i (find-m s (i + 1)))
   (chars s) #(filter (c \ !(128 <= c && c < 192)) (map (i \ s i) ^#s))
   rs (map bare (split "\r\n" out))
 (test (6 = #rs) (all (r \ 30 = chars r) rs)
       (has? out "a line")
       (has? (rs 1) (blk + "+")) (has? (rs 1) ("+" + blk))
       (30 = chars (rs 0))))

(hand-g () @ g
 (dput (g 'd) 4 2 6,
  pin (g 'd) 'solid '(6),
  pins (g 'p) 'x 3 'y 2,
  crawl-turn g [1 0],
  test (3 = g 'p 'x) (0 < #(g 'msg))
       (clear? (g 'd) 3 2 5 2) (peep (g 'vis) (5 + 9 * 2) 0) !(open? (g 'd) 4 2) (lit? (g 'd) 4 2)))

; heaven: rhombus platforms in a void of glass, seen across never entered, all reachable
(: p (sky 60 20 (wheel 11))
   d <p w 60 h 20
   rms (d 'rooms)
   (t x y) (dat d x y)
   (mid rm) [(peep rm 0 0 + peep rm 2 1 // 2) (peep rm 1 0 + peep rm 3 1 // 2)]
   flood (: mk (cask (w * h))
            (go stk n) (!stk ? n (: xy <stk x <xy y <>xy i (x + w * y)
                           (!(open? d x y) || peep mk i 0 ? (go >stk n) (pin mk i 1,
                             go (cat [[(x + 1) y] [(x - 1) y] [x (y + 1)] [x (y - 1)]] >stk)
                                   (n + 1)))))
            (go [(d 'in)] 0))
   (count k) #(filter (i \ k = t (i % w) (i // w)) ^(w * h))
   opens #(filter (i \ open? d (i % w) (i // w)) ^(w * h))
   stairs (filter (i \ 2 = t (i % w) (i // w)) ^(w * h))
   tints (map (rm \ (mid rm @ m (peep (d 'tint) (<m + w * <>m) ()))) rms)
 (test (1 < #rms)
       (all two? tints) !(tints 0 = tints 1)
       (all (rm \ (mid rm @ m (elem (t <m <>m) '(8 2)))) rms)
       (any (rm \ 6 = t (peep rm 0 0) (peep rm 1 0)) rms)                 ; void at a corner: a rhombus
       (2 = #stairs) (flood = opens) (0 < count 7) (0 < count 6) (0 = count 0)
       (all (i \ lit? d (i % w) (i // w)) ^(w * h))))

(hand-g () @ g
 (pin (g 'loot) (2 + 9 * 1) '(mirror),
  crawl-turn g [1 0],
  test (1 = g 'p 'x) (has? (g 'msg) "is solid"),
  pin (g 'loot) (6 + 9 * 2) '(mirror),
  crawl-turn g [1 0],
  test (0 < #(g 'msg))
       (|(g 'p 'x - 6) <= 1) (|(g 'p 'y - 2) <= 1) !(6 = g 'p 'x && 2 = g 'p 'y)))

(: g (hand-g ())
   _ (dput (g 'd) 2 1 8)
   _ (dput (g 'd) 3 1 7)
   _ (crawl-turn g [1 0])
   m1 (g 'msg)
   (crawl-turn g [1 0],
    ; platform and step say different lines; the text itself is the tower's to reword
    test (0 < #m1)
         (0 < #(g 'msg))
         (m1 != g 'msg)))

; the asked horn is two voices past the write head, one after the other, and the ask is spent
(: s (song-new ())
   g {'sfx '(horn) 'lvl 2 'st 0}
   (pin s 'fpos 4000,
    song-tier s g,
    test (2 = #(s 'vs)) !(g 'sfx)
         (all (v \ 4000 < v 0) (s 'vs))
         !((<(s 'vs) 0) = (s 'vs) 1 0)))

; a shelf's book: a key turns the page and takes no step; the key after the last closes it
(hand-g () @ g
 (pin (g 'loot) (2 + 9 * 1) '(shelf),
  crawl-turn g [1 0],
  test (1 = g 'p 'x) (two? (g 'sign)) ("Muse" = <(g 'sign)) (has? (g 'msg) "one book")
       (has? (last (g 'sign)) "1 of 6") (5 = #(g 'pages)),
  crawl-turn g [1 0],
  test (1 = g 'p 'x) (two? (g 'sign)) (has? (last (g 'sign)) "2 of 6"),
  each ^4 (_ \ crawl-turn g 46),
  test (two? (g 'sign)) (has? (last (g 'sign)) "6 of 6") !(g 'pages),
  crawl-turn g 46,
  test !(g 'sign) (1 = g 'p 'x)))

; the endless book: a Bell number a page; 1 turns, 2 puts it back, until a number would not
; fit the box: then the bookmark
(: g (hand-g ())
   _ (pins (g 'd) 'cols 40)
   _ (pin (g 'loot) (2 + 9 * 1) '(bells))
   _ (crawl-turn g [1 0])
   (line _) (g 'sign 2)
   _ (test (1 = g 'p 'x) ("OEIS A000110" = <(g 'sign)) ("B(0) = 1" = line ()) ('(0 (1)) = g 'bell)
           (has? (g 'msg) "shelf") (any (l \ has? l "put it back") (g 'sign)))
   _ (crawl-turn g 49)
   _ (test ("B(1) = 1" = line ()))
   _ (crawl-turn g 46)
   _ (test ("B(1) = 1" = line ()) ('(1 (1 2)) = g 'bell))
   _ (crawl-turn g 50)
   _ (test !(g 'sign) !(g 'bell) (1 = g 'p 'x))
   _ (crawl-turn g [1 0])
   _ (test ("B(0) = 1" = line ()))
   _ (each ^4 (_ \ crawl-turn g 49))
   _ (test ("B(4) = 15" = line ()) (has? (last (g 'sign)) "page 5"))
   (turn n) ("a bookmark" = <(g 'sign) ? n (crawl-turn g 49, turn (n + 1)))
   n (turn 0)
   (test (10 < n < 40) !(g 'bell) (any (l \ has? l "handwriting") (g 'sign)),
    crawl-turn g 46,
    test !(g 'sign) !(g 'bell) (1 = g 'p 'x)
         ('(1 2) = bell-row [1]) ('(2 3 5) = bell-row [1 2]) ('(5 7 10 15) = bell-row [2 3 5])))

; a tap on a choice is that choice
(: g (hand-g ())
   _ (pins (g 'd) 'rows 12 'cols 40)
   _ (pin (g 'loot) (2 + 9 * 1) '(bells))
   _ (crawl-turn g [1 0])
   ls >(g 'sign)
   (row-of s) (: (go i) (has? (ls i) s ? i (go (i + 1))) (go 0))
   (tap-at i) (: (go y) (i = sign-line <(g 'sign) ls 1 12 40 y ? y (go (y + 1))) (go 0))
 (test (50 = tap-key g [20 (tap-at (row-of "put it back"))])
       (49 = tap-key g [20 (tap-at (row-of "turn the page"))])
       (0 = tap-key g [20 (tap-at (row-of "= 1"))])))

; bytes 1 and 2 mark a choice: no width; fit paints its ground and restores the pen
(: s (string 1 + "ab" + string 2 + "c")
   f (fit-in s 400 "X")
 (test (has? f "\e[48;5;") (has? f "abX") ("c" = snip f (#f - 1) #f)
       (has? (fit s 400) "ab\e[0m")))

; a long note wraps over floor rows: the frame is no taller, the floor stays, taps count the same
(: g (hand-g ())
   _ (pins (g 'd) 'rows 5 'cols 20)
   _ (pin g 'msg "short")
   r1 (split "\r\n" (crawl-frame g))
   _ (pin g 'msg "a note far too long for a screen twenty cells wide")
   r2 (split "\r\n" (crawl-frame g))
   (bare s) (:- (go 0 "")
              (go i acc) (? (i >= #s) acc (s i = 27) (go (1 + past i) acc) (go (i + 1) (acc + string (s i))))
              (past i) (s (i + 1) @ c (? (i + 1 >= #s) i (c = 91 || c < 64) (past (i + 1)) (i + 1))))
 (test (#r1 = #r2) (has? (r2 1) "screen") (bare (r1 3) = bare (r2 3)) (bare (last r1) = bare (last r2))
       (60 = tap-steer g [(g 'p 'x + peep (g 'd) 'vx 0) (g 'p 'y + 1)])))

; on a stair, a tap on any of the nine cells about you is the stair
(: g (hand-g ())
   d (g 'd)
   _ (pins (g 'p) 'x 7 'y 3)
   _ (dput d 7 3 2)
   (tap dx dy) (tap-steer g [(7 + dx) (4 + dy)])
   on [(tap 1 1) (tap -1 0) (tap 0 -1) (tap 0 0)]
   off [(tap 2 0) (tap 0 2)]
   (dput d 7 3 1,
    test (all (= 60) on) !(any (= 60) off) ('(1 1) = tap 1 1) (60 = tap 0 0)))

; live cells (water, coals) are found once and repainted alone under a cursor move,
; none under a wrapped note or a sign's box
(: g (hand-g ())
   d (g 'd)
   _ (pins d 'rows 5 'cols 20 'lit 1)
   _ (each ^45 (i \ pin (d 'seen) i 1))
   _ (dput d 2 2 3, dput d 3 2 3, dput d 1 0 3)
   _ (pin (g 'loot) (5 + 9 * 1) '(brazier))
   ls (live-cells d (g 'loot))
   (live _) (:- (slurp j) j (paint-live (jug 0) d (g 'vis) (cell-face d (g 'vis) (g 'loot) (ents g)) ls))
   (moves s) (: (go i n) (i >= #s ? n (go (i + 1) (n + (s i = 72 ? 1 0)))) (go 0 0))
   (bare s) (:- (go 0 "")
              (go i acc) (? (i >= #s) acc (s i = 27) (go (1 + past i) acc) (go (i + 1) (acc + string (s i))))
              (past i) (s (i + 1) @ c (? (i + 1 >= #s) i (c = 91 || c < 64) (past (i + 1)) (i + 1))))
   _ (pin d 'ft 0)
   f0 (crawl-frame g) l0 (live ())
   _ (pin d 'ft 1)
   f1 (crawl-frame g) l1 (live ())
   _ (test ('(1 14 20 21) = ls) (4 = moves l0) (has? l0 "\e[4;8H") (has? l0 "\e[3;11H")
           (bare f0 = bare f1) !(f0 = f1) !(l0 = l1)
           (has? l0 "\e[38;5;45m") (has? l0 "\e[38;5;38m"))
   _ (pin g 'msg "a note far too long for a screen twenty cells wide")
   _ (crawl-frame g)
   l2 (live ())
   _ (pin g 'msg "")
   _ (pin g 'sign '("a sign" "over the floor"))
   _ (crawl-frame g)
   l3 (live ())
 (test (2 = moves l2) !(has? l2 "\e[2;7H") !(has? l2 "\e[3;")
       (two? (d 'box)) (moves l3 < 4)))

(hand-g () @ g
 (pin (g 'loot) (2 + 9 * 1) ['penny 7],
  crawl-turn g [1 0],
  test (7 = g 'p 'penny) (0 < #(g 'msg)) !(keys (g 'loot))))

; acting mends, passing does not, and mending stops at the brim
(hand-g () @ g
 (pin (g 'p) 'hp 5,
  crawl-turn g [1 0],
  test (7 = g 'p 'hp),
  crawl-turn g 46,
  test (7 = g 'p 'hp),
  pin (g 'p) 'hp 39,
  crawl-turn g [1 0],
  test (40 = g 'p 'hp)))

; mending 2 a turn against a bite of 3: one mob is a nuisance, two kill a climber standing still
(: g (hand-g ())
   _ (pin g 'ms [(mob-new 4 2 1) (mob-new 4 2 2)])
   (go n) (? (g 'over) n (60 < n) n (crawl-turn g 46, go (n + 1)))
   n (go 0)
 (test ('dead = g 'over) (n <= 30) (0 < #(g 'msg))))

(: g (hand-g ())
   m (mob-new 0 2 1)
   _ (pin g 'ms [m])
   (fight i) (i < 8 && g 'ms ? (crawl-turn g [1 0], fight (i + 1)) i)
   n (fight 0)
 (test !(g 'ms) (n <= 4) (0 < #(g 'msg))
         (1 = g 'p 'x)))

; one hp and a pass beside a mob is death
(hand-g () @ g
 ((pin g 'ms [(mob-new 0 2 1)], pin (g 'p) 'hp 1),
  crawl-turn g 46,
  test ('dead = g 'over) (0 < #(g 'msg))))

; pace: a garden mob stirs every turn, a heaven mob every other. row 5 is the d4, pace 2
(: g (hand-g ())
   slow (mob-new 5 7 1) quick (mob-new 0 7 1)
 (test (1 = quick 'pc) (2 = slow 'pc)
         (due? {'tn 1} quick) (due? {'tn 2} quick)
         !(due? {'tn 1} slow) (due? {'tn 2} slow)))

(: (kinds lvl) (crawl-new 60 20 (wheel 3) @ g
                (pin g 'lvl lvl,
                 stock g,
                 sort (keys (foldl (t \ m \ (pin t (nom (m 'nm)) 1)) {} (g 'ms)))))
   (apart? a b) !(any (k \ elem k b) a)
 (test
  (0 < #(kinds 1)) (0 < #(kinds 2)) (0 < #(kinds 3))
  (apart? (kinds 1) (kinds 2)) (apart? (kinds 2) (kinds 3)) (apart? (kinds 1) (kinds 3))))

; a tier is built of its own stuff, and a cell's face is the cell's own dice, not the clock's
(: (kit th) (<(th 1) . map (r \ <r) (th 2))
   (marks th) (map (i \ <(tile-face th 1 1 (i % 40) (i // 40) 5)) ^400)
   (all-of? l ks) (foldl (a \ x \ (a && elem x ks)) 1 l)
 (test
  (all-of? (marks (themes 0)) (kit (themes 0)))
  (all-of? (marks (themes 1)) (kit (themes 1)))
  (all-of? (marks (themes 2)) (kit (themes 2)))
  (marks (themes 0) = marks (themes 0))
  !(marks (themes 0) = marks (themes 1))
  (35 = <(tile-face (themes 1) 0 1 0 0 0))
  (35 = <(tile-face (themes 2) 0 1 0 0 0))
  (28 = tile-face (themes 0) 0 1 0 0 0 1)
  (22 = tile-face (themes 0) 0 0 0 0 0 1)
  (60 = <(tile-face (themes 0) 2 1 0 0 0))       ; the stair is gold on every floor
  (220 = tile-face (themes 2) 2 1 0 0 0 1)))

; nothing on a floor is silent, and nothing says one thing only
(: (says? nm) (0 < #(mutter 0 nm))
   (all-say? l) (foldl (a \ nm \ (a && says? nm)) 1 l)
   (strewings th) (map (r \ (r 4)) (th 2))
 (test
  (all-say? (strewings (themes 0)))
  (all-say? (strewings (themes 1)))
  (all-say? (strewings (themes 2)))
  (all-say? (map (k \ (mob-new k 0 0 'nm)) ^13))
  !(says? "the man in the moon")
  (foldl (t \ k \ (pin t (mutter k "tuft") 1)) {} ^9 @ t
     (1 < #(keys t)))))

; the cell picks the line said underfoot: the same each crossing
(: g (hand-g ())
   _ (pin (g 'd) 'th (themes 0))
   (salt n) (99 < n ? 0 (pin (g 'd) 'sd n, 0 < #(underfoot g 2 1) ? n (salt (n + 1))))
   _ (pin (g 'd) 'sd (salt 0))
   s (underfoot g 2 1)
   (crawl-turn g [1 0],
    test (0 < #s) (has? (g 'msg) s) (s = underfoot g 2 1)))

; a mob speaks the first time you lay into it, and only then
(: g (hand-g ())
   _ (pin g 'ms [(mob-new 0 2 1)])
   (rat? t) (has? t (mutter 0 "rat") || has? t (mutter 1 "rat"))
   _ (crawl-turn g [1 0])
   f (g 'msg)
   (crawl-turn g [1 0],
    test (rat? f) !(rat? (g 'msg))))

; the garden is small beds, heaven a few long blocks: the plan is the whole difference
(: gd <(delve 70 20 (wheel 5) (plan 1))
   hv <(delve 70 20 (wheel 5) (plan 3))
   (span rs) (net (map (r \ (r 2) * (r 3)) rs) // #rs)
 (test (#(hv 'rooms) < #(gd 'rooms))
         (span (gd 'rooms) < span (hv 'rooms))))

; a floor is dressed when cut
(: g (crawl-new 40 16 (wheel 7))
   t1 (g 'd 'th)
   (ascend g,
    test (themes 0 = t1) (themes 1 = g 'd 'th) (charm? (g 'd 'sd))))

; < climbs only on the stair, restocks, and restates the imperative on arrival
(hand-g () @ g
 (crawl-turn g 60,
  test (1 = g 'lvl) (0 < #(g 'msg)),
  dput (g 'd) 1 1 2,
  crawl-turn g 60,
  test (2 = g 'lvl) (0 < #(g 'msg))
         (elem (dat (g 'd) (g 'p 'x) (g 'p 'y)) '(1 4 8))   ; on floor, in a building, or on a platform
         (60 = g 'p 'mx)                         ; a climb is twenty more bar
         (60 = g 'p 'hp || has? (g 'msg) "bites")   ; full, unless something met you
         (tablet? (g 'loot))))

; enter, return and space climb too, for a keyboard with no <
(: (climbs? k) (hand-g () @ g
                (dput (g 'd) 1 1 2,
                 crawl-turn g k,
                 (2 = g 'lvl)))
 (test (climbs? 60) (climbs? 32) (climbs? 13) (climbs? 10)
       !(climbs? 46)))

; a tap is one step of the eight toward where it lands; your own cell is the stair.
; the note row is the screen's first, so a floor y is a screen y less one
(: g (hand-g ())
   p (g 'p)
   (tap x y) (tap-steer g [x y])
 (test (60 = tap (p 'x) (p 'y + 1))
       ('(1 0) = tap (p 'x + 4) (p 'y + 1))
       ('(-1 0) = tap (p 'x - 4) (p 'y + 1))
       ('(0 -1) = tap (p 'x) (p 'y - 3))
       ('(0 1) = tap (p 'x) (p 'y + 6))
       ('(-1 -1) = tap (p 'x - 3) (p 'y - 2))
       ('(1 1) = tap (p 'x + 9) (p 'y + 9))
       ; the nearest as drawn, a cell twice as tall as wide
       ('(1 0) = tap (p 'x + 9) (p 'y + 2))
       ('(0 1) = tap (p 'x + 1) (p 'y + 5))
       ('(0 -1) = tap (p 'x - 1) (p 'y - 3))
       ('(1 1) = tap (p 'x + 3) (p 'y + 3))
       ('(-1 1) = tap (p 'x - 4) (p 'y + 3))))

; a tap while she speaks is the choice it lands on (rows 12 to 14 on 24 rows); off a
; choice it shows the page again; a page without choices closes
(: g (hand-g ())
   _ (pins (g 'd) 'rows 24 'cols 80)
   _ (talk g 'start)
   (tap x y) (tap-key g [x y])
 (test (49 = tap 40 12) (50 = tap 40 13) (51 = tap 40 14)
       (0 = tap 40 10) (0 = tap 40 0) (0 = tap 40 23)
       (crawl-turn g (tap 40 12), 'who = g 'talk)
       (crawl-turn g (tap 40 10), 'who = g 'talk)
       (talk g 'bye, crawl-turn g (tap 40 12), atom? (g 'talk))
       (talk g 'bye, pin g 'talk (), 0 = tap (g 'p 'x + 9) (g 'p 'y + 1))   ; a sign takes a tap as a key
       (pin g 'sign (), '(1 0) = tap (g 'p 'x + 9) (g 'p 'y + 1))))

; the vale: the last floor, three screens tall, lit, laid not delved: a road, seven
; stones and a gap round the fire, her beside it, the cottage, its house and attic
(: g (crawl-new 60 22 (wheel 3))
   _ (ascend g, ascend g, ascend g)
   d (g 'd) w 60 h (d 'h)
   fx (g 'cx) fy (g 'cy)
   (t x y) (dat d x y)
   stones (filter (i \ 'stone = <(g 'loot i)) (keys (g 'loot)))
   spot (oct-pt fx fy 7)
   door (d 'door)
 (test (circle? g) (4 = g 'lvl) (66 = h) (22 = d 'rows) ('walk = g 'phase) (-1 = circle-r g)
       (9 = t (g 'p 'x) (g 'p 'y)) (h - 2 = g 'p 'y)
       (any (x \ 9 = t x (h - 1)) ^w)
       (1 = t fx (fy + 3))
       (9 = t (fx + 1) fy) ('fire = <(g 'loot (fx + w * fy)))
       (7 = #stones) (10 = t <spot <>spot)               ; the eighth's place is lighter grass
       (<spot < fx) (<>spot < fy)
       (<>spot = <>(oct-pt fx fy 0)) (fx < <(oct-pt fx fy 0))   ; the upper left
       (tablet? (g 'her)) (g 'her 'x = fx + 2) (g 'her 'y = fy)
       (5 = t <door (<>door - 1)) (11 = t (<door - 1) (<>door - 1))
       (12 = t fx (<>door - 7))
       ('house = <(exit-at g <door (<>door - 1)))
       (tablet? (g 'scenes 'house)) (tablet? (g 'scenes 'attic))
       (d 'lit) (all (i \ peep (d 'seen) i 0) ^(w * h))
       (filter (i \ 'sign = <(g 'loot i)) (keys (g 'loot)) @ si   ; one wooden sign, on grass, by the foot
          (two? si && atom? >si && 1 = t (<si % w) (<si // w) && h - 5 = <si // w))))

; the story: the attic box names the token; out with it she is gone, the walls draw in
; to a ring, a strike puts you back, and the point is the end
(: g (crawl-new 60 22 (wheel 3))
   _ (ascend g, ascend g, ascend g)
   d (g 'd) w 60
   door (d 'door)
   _ (crawl-turn g 46)
   _ (pins (g 'p) 'x <door 'y <>door)
   _ (crawl-turn g [0 -1])
   _ (test ('house = g 'scene) !(g 'her) (19 = g 'd 'w) (22 = g 'd 'rows))
   hearth (g 'loot (19 // 2 + 19 * 1))
   _ (pins (g 'p) 'x (19 - 3) 'y 2)
   _ (crawl-turn g [0 -1])
   _ (test ('attic = g 'scene) (11 = g 'd 'w) ('hearth = <hearth))
   _ (pins (g 'p) 'x (11 - 3) 'y 2)
   _ (crawl-turn g [1 0])
   _ (test (string? (g 'token)) (elem (g 'token) tokens) (two? (g 'sign))
           (0 < #(last (g 'sign)))
           (any (l \ has? l (g 'token)) (g 'sign)))
   _ (crawl-turn g 46)
   _ (crawl-turn g [1 0])
   _ (test (0 < #(g 'msg)) !(g 'sign))
   _ (pins (g 'p) 'x 2 'y 3)
   _ (crawl-turn g [-1 0])
   _ (test ('house = g 'scene))
   _ (pins (g 'p) 'x (19 // 2) 'y (9 - 2))
   _ (crawl-turn g [0 1])
   wr0 (g 'wr)
   _ (test ('vale = g 'scene) (g 'doom) (g 'rumble) ('close = g 'phase) (0 < wr0)
           !(g 'her)
           (two? (g 'sign))
           (g 'p 'x = <door) (g 'p 'y = <>door)
           !(walled? g 1 1))
   _ (crawl-turn g 46)
   _ (test (wr0 = g 'wr))
   _ (crawl-turn g [0 -1])
   _ (test ('vale = g 'scene) (0 < #(g 'msg)) (wr0 - 2 = g 'wr))
   (until-wall n) (? (walled? g 1 1) n ('ring = g 'phase) -1 (40 < n) -2
                     (crawl-turn g 46, until-wall (n + 1)))
   nw (until-wall 0)
   _ (test (0 <= nw) ('close = g 'phase) !(walled? g (g 'cx) (g 'cy)))   ; the corner walls before the ring; the fire never
   (until-ring n) (? ('ring = g 'phase) n (200 < n) n (crawl-turn g 46, until-ring (n + 1)))
   n (until-ring 0)
   r (circle-r g)
   _ (test ('ring = g 'phase) (n < 60) (0 < #(g 'msg))
           (11 <= r) (on-ring? g (g 'cx) (g 'cy - r)) (walled? g (g 'cx) (g 'cy - r))
           (circle-q g (g 'p 'x) (g 'p 'y) < ring-in g))
   _ (pins (g 'p) 'x (g 'cx) 'y (g 'cy - r + 1))
   py0 (g 'p 'y)
   _ (crawl-turn g [0 -1])
   _ (test (0 < #(g 'msg)) (py0 < g 'p 'y)
           (circle-q g (g 'p 'x) (g 'p 'y) < ring-in g))
   (sink n) (? (g 'over) n (100 < n) n
               (: _ (crawl-turn g 46)
                  ok (circle-q g (g 'p 'x) (g 'p 'y) < ring-in g || done? g)
                  (ok ? (sink (n + 1)) -1)))
   m (sink 0)
 (test ('won = g 'over) (0 <= m) (m < 40) (0 = circle-r g) (done? g)
       (g 'p 'x = g 'cx) (g 'p 'y = g 'cy)))

; her talk: a digit takes a branch, another key shows the page again, a leaf closes;
; she leaves once you come out with the token
(: g (crawl-new 60 22 (wheel 3))
   _ (ascend g, ascend g, ascend g)
   h (g 'her)
   _ (crawl-turn g 46)
   _ (pins (g 'p) 'x (h 'x + 1) 'y (h 'y))
   _ (crawl-turn g [-1 0])
   root (talk-node 'start)
   c1 (root 2 0)
   _ (test (two? (g 'sign)) ('start = g 'talk) (g 'talked) (tablet? (g 'her))
           (has? (g 'sign 1) (root 1 0))
           (any (l \ has? l (show <c1 + "  ")) (g 'sign)))
   _ (crawl-turn g (48 + <c1))
   _ (test (c1 2 = g 'talk) (two? (g 'sign)))
   _ (crawl-turn g 120)
   _ (test (c1 2 = g 'talk) (two? (g 'sign)))
   leaf <(filter (n \ !(two? (n 2))) her-tree)
   (talk g <leaf,
    test (0 < #(last (g 'sign))),
    crawl-turn g 46,
    test !(g 'talk) !(g 'sign) (tablet? (g 'her)) (g 'p 'x = h 'x + 1),
    pin g 'token "the rubbed coin",
    enter g 'house (19 // 2) (9 - 2),
    crawl-turn g [0 1],
    test ('vale = g 'scene) (g 'doom) !(g 'her) ('close = g 'phase)))

; a floor taller than the screen is framed about you; a shorter room is centred and padded
(: g (crawl-new 60 22 (wheel 3))
   _ (ascend g, ascend g, ascend g)
   _ (crawl-turn g 46)
   f (crawl-frame g)
   d (g 'd)
   _ (test (24 = #(split "\r\n" f)) (44 = d 'vy))
   _ (enter g 'house (19 // 2) (9 - 2))
   _ (pin g 'msg "a line longer than the room is wide, every word of it")
   f2 (crawl-frame g)
   hd (g 'd)
   rs (split "\r\n" f2)
 (test (24 = #rs)
       (has? (rs 0) "every word of it")
       (0 < hd 'vx) (hd 'vy < 0)
       (has? (rs 1) "\e[K") !(has? (rs 1) "#")
       (has? (rs 7) "#") (has? (rs 7) "\e[K")
       ; a sign over the narrow attic is laid at the screen's width
       (: _ (enter g 'attic 2 3)
          _ (pin g 'sign '("t" "a line of some length, laid whole across the box" "" "" "" "" "" "" "" "" "" "" "and a foot"))
          f3 (crawl-frame g)
          (bare s) (: (go i acc) (? (i >= #s) acc
                                    (27 = s i) (go (1 + find-m s i) acc)
                                    (go (i + 1) (acc + string (s i))))
                      (go 0 ""))
          ; an escape ends at its first letter: \e[K as much as \e[..m
          (letter? c) (? (65 <= c <= 90) 1 (97 <= c <= 122) 1 0)
          (find-m s i) (i >= #s || letter? (s i) ? i (find-m s (i + 1)))
          ; every row of the box starts at one column
          (find-l r i) (i >= #r || 124 = r i ? i (find-l r (i + 1)))
          lefts (map (r \ find-l r 0) (filter (r \ has? r "|") (map bare (split "\r\n" f3))))
          (has? f3 "a line of some length, laid whole across the box"
              && 12 = #lefts
              && all (l \ l = <lefts) lefts))))

; the pink front: off the board until the ring is past half its scale, then in
(: g (crawl-new 60 22 (wheel 3))
   _ (ascend g, ascend g, ascend g)
   (front r) (pins g 'phase 'ring 'r r, pink-front g)
 (test (1.0 = pink-front g)
       (1.0 = front 8) (1.0 = front 4)
       (front 3 < 1.0)
       (front 2 < front 3) (front 0 < front 2)
       (0.0 < front 0 < 1.0)))

; the last hit opens slop's walk on the climb's own stage, not the verb: a missed cite ends silently
(test !(() = cite 'slop 'slop-walk))

; the horn's lead: a fifth of a second if the box keeps up, else 2.5 gaps, a second at
; most; the pacer holds a gap at its recent worst and lets it go by the clock
(test (song-lead-of 0.0 = song-lead) (song-lead-of 33.0 = song-lead)
      (song-lead < song-lead-of 200.0 < song-lead-max) (song-lead-of 200.0 = int (0.5 * song-rate))
      (song-lead-of 5000.0 = song-lead-max))
(: p (pacer ()) t0 (p 't) g0 (pace! p) t1 (p 't) _ (rest 60) g1 (pace! p) t2 (p 't)
   _ (rest 5) g2 (pace! p) t3 (p 't)
   (law held d) (: v ((d / 2000.0) 0.5 * held) (v < d ? d v))
   d2 (1.0 * (t3 - t2))
 (test (g0 = law 0.0 (1.0 * (t1 - t0))) (g1 = law g0 (1.0 * (t2 - t1))) (g2 = law g1 d2)
       (55.0 <= g1)
       (d2 < 300.0 && d2 < g1 * 0.9 ? (g1 * 0.9 < g2 <= g1) 1)))   ; a long gap held over a short one after it
; the filler feeds up to the lead, bounded even past the card's ring; the lag counts what
; the port still holds
(: h (horn song-rate 2)
   z (string (cask (4 * 480)))
   (feed _) (say h z)
   k1 (nom? h ? 1 (song-fill h 2400 feed))
   k2 (nom? h ? 0 (song-fill h 0 feed))
   k3 (nom? h ? 1 (song-fill h 100000000 feed))
   big (string (cask (4 * 2 * song-rate)))
   c0 (clock 0)
   l0 (nom? h ? 0 (horn-lag h))
   l (nom? h ? (2 * song-rate) (say h big, horn-lag h))
   played ((clock 0 - c0 + 1) * song-rate // 1000)    ; the most the rate plays between the reads
 (test (0 < k1) (k2 = 0) (0 < k3) (2 * song-rate - played <= l - l0 <= 2 * song-rate)))

; the opening sign: the first key takes it down and nothing else; the bar is never covered
(: g (crawl-new 40 16 (wheel 7))
   f (crawl-frame g) bar (crawl-bar g)
   x (g 'p 'x) y (g 'p 'y)
   _ (crawl-turn g [1 0])
   f2 (crawl-frame g)
 (test (has? f "+-")
         (has? f bar)
         (#(split "\r\n" f) = #(split "\r\n" f2))
         (x = g 'p 'x) (y = g 'p 'y)
         !(has? f2 "+-")))

; the stair speaks underfoot, and the bar says more on it than off it
(: g (hand-g ())
   _ (pins (g 'd) 'th (themes 0) 'sd 3)
   _ (dput (g 'd) 2 1 2)
   s (underfoot g 2 1)
   (crawl-turn g [1 0],
    test (0 < #s) (has? (g 'msg) s)
           (hand-g () @ h !(crawl-bar g = crawl-bar h))))

; pennies: a fallen mob drops some where it stood, and they speak when picked up
(: g (hand-g ())
   _ (pin g 'ms [(mob-new 0 2 1)])
   (fight i) (i < 8 && g 'ms ? (crawl-turn g [1 0], fight (i + 1)) i)
   _ (fight 0)
   it (peep (g 'loot) (2 + 9 * 1) ())
   _ (test (two? it) ('penny = <it) (0 < <>it))
   n <>it
   _ (crawl-turn g [1 0])
   (says? t) (foldl (a \ k \ (a || has? t (mutter k "pennies"))) 0 ^4)
 (test (n = g 'p 'penny) (says? (g 'msg))))

; every room but yours carries a pile or more
(crawl-new 60 20 (wheel 3) @ g
 (test (#(g 'd 'rooms) <= #(keys (g 'loot)))))

; the music: no gate can listen, so this holds the slots, their count, and each rule's
; bar as the cycle runs on
(: g (crawl-new 60 22 (wheel 3))
   _ (ascend g, ascend g, ascend g)
   (vat st) (pins g 'phase 'ring 'r (8 - st) 'r0 8, song-vol g)
   (hits bs) (foldl (a \ b \ (a + foldl (t \ v \ (t + (tablet? v ? 1 0))) 0 b)) 0 bs)
   (slots bs) (foldl (a \ b \ (a + #b)) 0 bs)
   ; every slot is a playable voice or nothing
   (sane? bs) (foldl (a \ b \ (a && foldl (t \ v \ (t && ? (tablet? v) (string? (v 's)) !v)) 1 b)) 1 bs)
   (over n f) (foldl (a \ c \ (a + f c)) 0 ^n)
 (test
  (#floors = #songs)
  (foldl (a \ v \ (a && 0.0 < v)) 1 songs)
  ; the garden: sixteen slots, mostly empty, no two bars the same
  (16 = slots (garden-bars 0)) (16 = slots (garden-bars 7))
  (sane? (garden-bars 3))
  (0 < over 40 (c \ hits (garden-bars c)))
  (0 < over 40 (c \ (16 > hits (garden-bars c)) ? 1 0))
  (garden-bars 0 != garden-bars 1)
  ; the middle: two bars to a horn in the same slots
  (middle-bars 4 @ bs
     (2 = #bs && foldl (a \ i \ (a && tablet? (<bs i) = tablet? (bs 1 i))) 1 ^12))
  ; now and then a tune, held for a run of five bars
  (0 < over 200 (c \ (tune? c) ? 1 0))
  (0 < over 200 (c \ (tune? c) ? 0 1))
  (foldl (a \ c \ (a && tune? c = tune? (5 * (c // 5)))) 1 ^40)
  ; heaven: a block's four bars are one sequence in order
  (1 = #(sky-bars 0)) (sane? (sky-bars 0))
  (0 < hits (sky-bars 0))
  (sky-bars 0 != sky-bars 1)
  ; the circle: a heart, slower as the ring shrinks
  (heart-rate 2 < heart-rate 5) (heart-rate 5 < heart-rate 8)
  (1 = heart-rate 0)
  (slots (heart-bars 2) < slots (heart-bars 8))
  (4 = hits (heart-bars 0))                      ; lub and dub, two voices each
  (2 = #(heart-bars 0))
  (sane? (heart-bars 8))
  (1.0 = vat 0)
  (vat 4 < vat 0) (vat 6 < vat 4)
  (0.0 = vat 8)
  (crawl-new 20 10 (wheel 1) @ h (0 < song-vol h))
  ; every floor's bar goes through harp to a pattern
  !(() = tower-tune 1 0 0) !(() = tower-tune 2 0 0)
  !(() = tower-tune 3 0 0) !(() = tower-tune 4 0 8)))

; a seeded random walk holds every invariant. the wheel is boxed, {(wheel 99)}: a bare
; {wheel 99} rolls () forever
(: g (crawl-new 60 20 (wheel 3))
   kb {(wheel 99)}
   dirs [[1 0] [-1 0] [0 1] [0 -1] [1 1] [-1 -1] [1 -1] [-1 1] 46 62]
   (turn i ok) (i < 300 && !(g 'over) ? (: k (peep dirs (roll kb 10) 46)
                   _ (crawl-turn g k)
                   p (g 'p)
                   (turn (i + 1)
                         (ok && open? (g 'd) (p 'x) (p 'y)
                                && p 'hp <= p 'mx
                                && 0 <= p 'penny))) ok)
 (test (turn 0 1)
         (g 'over || 0 < g 'p 'hp)))

; the painter: one frame, glyphs and hues where they belong; the sign down first
(: g (crawl-new 60 20 (wheel 3))
   _ (pin g 'sign ())
   f (crawl-frame g)
 (test
  (string? f)
  (has? f "@")
  (has? f (crawl-bar g))
  (has? f "\r\n")))                            ; frames ride \r\n

; the middle's walls grade off one still frame of the shimmer; the garden's off one frame too
(: g (crawl-new 60 20 (wheel 11))
   _ (crawl-turn g 46)
   gsk (g 'd 'skin)
   _ (pins (g 'p) 'x <(g 'd 'stair) 'y <>(g 'd 'stair))
   _ (crawl-turn g 60)
   d (g 'd) n (60 * 20)
   _ (each ^n (i \ pin (d 'seen) i 1))
   _ (pin g 'vis (foldl (t \ i \ (pin t i 1)) {} ^n))
   _ (pin g 'sign ())
   f (crawl-frame g)
   (pen n) ("\e[38;5;" + show n + "m")
   greys (filter (n \ has? f (pen n)) '(252 250 248 247 245 244 243))
 (test (2 = g 'lvl) (tablet? (d 'skin)) !(() = d 'skin 'ground) !(d 'skin 'hedge)
       (1 < #greys)                                    ; a grade, not a flat grey
       (tablet? gsk) !(gsk 'hedge) !(() = gsk 'ground)))

; sign-over keeps every cell of the rows it covers, or the last frame shows past the box;
; rows end on \e[K, an escape with no m
(: sw 40
   srow ("\e[38;5;34m" + string (map (_ \ 46) ^sw) + "\e[0m\e[K")
   sf (: (go k acc) (6 <= k ? acc (go (k + 1) (acc + (0 < k ? "\r\n" "") + srow)))
         (go 0 ""))
   sout (sign-over sf "sign" ["a line"] 0 6 sw)
   (scells r) (: (past i) (i >= #r ? i (r i @ 109 (i + 1) (past (i + 1))))
                 (go i k) (i >= #r ? k (r i @ 27 (past i @ e (go e k)) (go (i + 1) (k + 1))))
                 (go 0 0))
   srs (split "\r\n" sout)
 (test
  (6 = #srs)
  (all (r \ sw = scells r) srs)
  (has? sout "sign")
  (all (r \ has? r "\e[38;5;34m") srs)
  (all (r \ has? r "\e[K") srs)))

; pens: rgb and back, a glyph on a ground, and a fg legible over a bg
(: (frame gl hue) ({'w 3 'h 1 't (cask 3) 'seen (cask 3)} @ d
                   (each ^3 (i \ pin (d 't) i 1),
                    (:- (slurp j) j (paint (jug 0) d (i \ (i = 1 ? [gl [hue 22]] [35 22])) "" ""))))
   f (frame 64 228)
   (kept? fg bg) (fg = legible fg bg)
 (test (pen-rgb 16 = [0 0 0]) (pen-rgb 231 = [255 255 255]) (pen-rgb 233 = [18 18 18])
       (all (c \ c = (pen-rgb c @ q (rgb-pen (q 0) (q 1) (q 2)))) (map (+ 16) ^240))
       (has? (pen [228 22]) ";48;5;22m") (has? (pen [228 22]) "38;5;228")
       (has? f ";48;5;22m") (has? f "\e[49m")
       (kept? 228 22) (kept? 16 231)
       !(kept? 22 22) !(kept? 244 244) !(kept? 228 187)
       !(kept? 213 118) !(kept? 226 118)                          ; as bright as each other: another
       (all (bg \ (legible bg bg @ fg                                ; always far enough
                     (legible-gap <= pen-gap fg bg && legible-lum <= |(pen-lum fg - pen-lum bg))))
            (map (+ 16) ^240))))

(test_fin ())
(puts "tower: ok")
