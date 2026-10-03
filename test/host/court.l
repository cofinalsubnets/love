; test/host/court.l -- the courtyard, headless: the frame in both palettes, the sun by
; the hour, the low sun on the top of the wall it faces, walking, looking, and the clock.
; not in the corpus: a crew module. run: cat test/00-init.l test/host/court.l | out/love

(borrow 'court)   ; the artifact's module, warm from the tree
(borrow 'vec)

(: (count s n) (:- (go 0 0) (go i k) (i + #n <= #s ? (go (i + 1) (k + (n = snip s i (i + #n)))) k))
   (rows s) (1 + count s "\r\n")
   day0 (1.0 * 1790812800)                          ; 2026-10-01, midnight on the wall clock
   (at hr) (court-new 80 48 [(day0 + hr * 3600.0) 3600])
   ; ..and on another day of 2026, at noon
   (on m d) (court-new 80 48 [(86400.0 * (cite 'cal 'epoch-days) 2026 m d + 12.0 * 3600.0) 3600])
   (near? a b) (a - b @ d (d * d < 0.0001))
   (keys! st ks) (each ks (k \ court-step st k)))

; --- the frame: half the pixel rows in cells, the same state the same frame, in the 256
; --- palette and in 24 bits; the clock in the corner at the start and gone after. the
; --- leaves drawn settle on how many in a frame or two, so the first frames are let go
(: st (at 12.0) _ (court-frame st) _ (court-frame st) f (court-frame st) f2 (court-frame st)
   deep (court-frame (pin (at 12.0) 'deep 1))
   _ (pin st 't 100) quiet (court-frame st)
 (test (rows f = 24) (f = f2) (rows deep = 24) (f != deep)
       (has? f "38;5;") (has? deep "38;2;")
       (has? f (court-clock st)) !(has? quiet (court-clock st))))

; --- the sun: up by day and down by night, south at noon, east in the morning and west in
; --- the evening, a unit vector; summer's hour is taken off the wall clock
(: (sun hr) (court-sun (at hr)) n (sun 13.0) m (sun 8.0) e (sun 18.0) mid (sun 1.0)
   (len s) (s 0 * s 0 + s 1 * s 1 + s 2 * s 2)
 (test (0.0 < n 1) (mid 1 < 0.0) (m 1 < n 1) (e 1 < n 1)
       (n 2 < 0.0) (0.0 < m 0) (e 0 < 0.0)
       (near? (len n) 1.0) (near? (len e) 1.0)
       (sun 13.0 = court-sun (court-new 80 48 [(day0 + 12.0 * 3600.0) 0]))))

; --- the light: day at noon and none at midnight, the eye's gain up in the dark; and the
; --- low sun orange, the high sun near white
(: noon (court-light (at 13.0)) night (court-light (at 1.0)) low (court-light (at 17.6))
 (test (noon 'day = 1.0) (night 'day = 0.0) (noon 'expo < night 'expo)
       (0.0 < low 'sunk) (low 'sunc 2 < 0.5) (0.75 < noon 'sunc 2)))

; --- the low sun on the rim: an hour before sunset, looking up the east wall from across
; --- the yard, the top of the wall is warm and lit and its foot is not
(: st (pins (at 17.4) 'px (0.0 - yard-a + 0.5) 'pz 0.0 'th (pi / 2.0) 'ph 1.1)
   c (court-pens st) w (st 'w)
   ; the column down the middle: the rim's row is the first from the top that is wall
   (px k y) (peep (c k) (y * w + w // 2) 0.0)
   (warm? y) (px 2 y + 0.08 < px 0 y)
   top (foldl (a \ y \ (a < 0 && warm? y ? y a)) -1 ^(st 'h))
 (test (0 <= top) !(warm? (st 'h - 1))))

; --- walking: k steps the way you face, j back; h and l turn; the walls stop you; u and
; --- n tilt the look, never past straight up or down ---
(: st (at 12.0) z0 (st 'pz) th0 (st 'th)
   _ (keys! st [107 107 107]) z1 (st 'pz)
   _ (keys! st [106]) z2 (st 'pz)
   _ (keys! st [108 108]) th1 (st 'th)
   _ (keys! st (map (i \ 107) ^400)) far (st 'px)
   _ (keys! st (map (i \ 117) ^100)) up (st 'ph)
   _ (keys! st (map (i \ 110) ^100)) down (st 'ph)
 (test (z0 < z1) (z2 < z1) (z0 < z2) (th0 < th1)
       (near? far (yard-a - body-r)) (up <= 1.45) (1.4 < up) (-1.21 < down) (down < -1.1)))

; --- the time: ] and [ an hour on and back, t the pace, a frame its share of it ---
(: st (at 12.0) s0 (st 'sim)
   _ (keys! st [93 93 91]) s1 (st 'sim)
   _ (court-move st) s2 (st 'sim)
   _ (keys! st [116]) _ (court-move st) s3 (st 'sim)
   _ (keys! st [116 116]) _ (court-move st) s4 (st 'sim)
 (test (near? (s1 - s0) 3600.0) (near? (s2 - s1) (paces 0 / fps))
       (near? (s3 - s2) (paces 1 / fps)) (near? s4 s3)
       (court-clock st = "13:00")
       (court-now () @ n (two? n && 0.0 < n 0))))

; --- the battlements: the sun past the north wall's middle third, and stopped by a block
; --- over an outer third; a block's face high enough sees over the far one
(: s (unit [0.0 0.2 1.0]) b0 (0.0 - yard-b)
 (test (sun-clear 0.0 12.6 b0 s = 1) (sun-clear 2.5 12.6 b0 s = 0)
       (sun-clear 2.5 14.0 b0 s = 1) (sun-clear 2.5 12.6 b0 (unit [0.0 1.0 0.1]) = 1)
       (sun-clear 0.0 1.0 0.0 (unit [0.0 -0.1 1.0]) = 0)))

; --- the tree: the same seed the same tree; planted in the north-east quarter, leaning
; --- toward the middle, forked in the third floor, every leaf inside the walls below their
; --- tops, the crown from a metre under them (its fronds hanging lower) to well over;
; --- and drawn: the frame with it is not the frame without
(: t1 (tree-grow 7) t2 (tree-grow 7) t3 (tree-grow 8) bs (t1 'base) segs (t1 'segs)
   fork (filter (sg \ sg 2 = 0.14) segs @ (l . _) (l 0)) n (#(t1 'x))
   (in? k lim) (aall (mag (t1 k) <= lim + 0.0001 + 99.0 * (wall-h <= t1 'y)))
   st (pins (at 12.0) 'px -2.0 'pz -3.5 'th 0.6 'ph 0.9)
   f1 (court-frame st) f2 (court-frame (pin st 'tree (tree-grow 7 @ tr (pins tr 'segs () 'kind (tr 'kind * 0.0 - 1.0) 'x (tr 'x * 0.0 - 99.0)))))
 (test (show (t1 'segs) = show (t2 'segs)) (aall (t1 'x = t2 'x)) (show (t1 'segs) != show (t3 'segs))
       (0.0 < bs 0) (0.0 < bs 2) (mag (fork 0) < bs 0) (mag (fork 2) < bs 2)
       (7.0 < fork 1 < 8.0) (8 < #segs) (all (sg \ sqrt (sq (sg 1 0 - sg 0 0) + sq (sg 1 1 - sg 0 1) + sq (sg 1 2 - sg 0 2)) <= 1.0) segs) (5000 < n)
       (in? 'x (yard-a - 0.1)) (in? 'z (yard-b - 0.1)) (aall (0.0 < t1 'y))
       (aall (0 < (t1 'kind != 2.0) + (wall-h - 1.4 <= t1 'y))) (wall-h + 2.0 < amax (t1 'y))
       (f1 != f2)))

; --- the trunk stands in the way: walking into it, the player stays a body's width off
(: st (at 12.0) bs (st 'tree 'base)
   _ (pins st 'px (bs 0) 'pz (bs 2 - 1.5) 'th 0.0)
   _ (keys! st (map (i \ 107) ^60))
 (test (0.55 < sqrt (sq (st 'px - bs 0) + sq (st 'pz - bs 2)))))

; --- the floor's litter: the sticks lie in a ring round the trunk's foot, the leaves flat on
; --- the ground, all of it inside the walls; and the leaves a falling one starts from, high in the crown
(: st (at 12.0) bs (st 'tree 'base) L (st 'litter) P (L 'pts) X (P 'x) Y (P 'y) Z (P 'z)
   d (sq (X - bs 0) + sq (Z - bs 2)) G (L 'leaves)
   (out Q) ((yard-a < mag (Q 'x)) + (yard-b < mag (Q 'z)))
   tops (L 'tops) ty (map (q \ q 1) tops)
 (test (100 < #X) (0 = net (Y < 0.009)) (0 = net (1 - (0.09 < d) * (d < 0.5625)))
       (1000 < #(G 'x)) (0 = net (0.01 < G 'y)) (0 = net (G 'up < 1.0))
       (0 = net (out P)) (0 = net (out G))
       (two? tops) (all (y \ amax (st 'tree 'y) - 1.5 < y) ty)))

; --- falling leaves: now and then one lets go of the top of the crown and comes down, and
; --- it lies on the floor where it lands, inside the walls; the frame draws them
(: st (on 10 25) seen {}
   (tick k) (pin st 't k, court-move st,
             (two? (st 'fall) ? (pin seen 'fell (cat (peep seen 'fell ()) [(rev (st 'fall) 0 1)]))))
   _ (each ^1500 tick)
   ys (peep seen 'fell ()) fl (st 'fallen)
   f (court-frame st)
 (test (two? ys) (two? fl) (all (q \ q 1 < 0.01) fl)
       (all (q \ mag (q 0) < yard-a && mag (q 2) < yard-b) fl)
       (5.0 < foldl (a \ b \ a < b ? b a) 0.0 ys) (foldl (a \ b \ a < b ? a b) 99.0 ys < 1.0) (rows f = 24)))

; --- the seasons: bare in january with last fall's leaves thick on the ground, leafing out
; --- in may, green and full in july with little underfoot, gold by late october and
; --- dropping fast; no leaf falls from a bare tree; and the crown is drawn as the season has it
(: jan (court-season (on 1 15)) may (court-season (on 5 1)) jul (court-season (on 7 4))
   oct (court-season (on 10 25)) dec (court-season (on 12 20))
   bare (on 1 15) _ (each ^800 (k \ (pin bare 't k, court-move bare)))
   (look st) (court-frame (pins st 'tree (court-new 80 48 [(day0 + 12.0 * 3600.0) 3600] 'tree)
                                   'px 0.0 'pz (0.0 - yard-b + 1.0) 'th 0.4 'ph 1.0))
 (test (jan 'share = 0.0) (0.8 < jan 'ground) (jan 'every = 0)
       (0.0 < may 'share) (may 'share < 1.0) (may 'turn = 0.0)
       (jul 'share = 1.0) (jul 'turn = 0.0) (jul 'ground < 0.2) (0 < jul 'every)
       (oct 'turn = 1.0) (0.0 < oct 'share) (oct 'share < 1.0) (0 < oct 'every) (oct 'every < jul 'every)
       (dec 'share = 0.0) (0.9 < dec 'ground)
       !(two? (bare 'fall)) !(two? (bare 'fallen))
       (look (on 7 4) != look (on 1 15)) (look (on 7 4) != look (on 10 25))
       ; ..and the season leaves the light alone: the yard at noon is not dark
       (court-pens (on 10 25) @ c (0.1 < net (c 0) / #(c 0)))))

(borrow 'sky)

; --- the weather by season: january's odds lean overcast and july's clear; left to the
; --- season it drifts a notch at a time as the hours turn; a cover chosen holds
(: (odds m) (map (k \ court-wx-pick m k) ^20) jan (odds 1) jul (odds 7)
   (n c l) #(filter (x \ x = c) l)
   st (on 1 15) seen {}
   (hop k) (pin st 'sim (st 'sim + 3600.0), court-move st, pin seen k (st 'wx 'cover))
   _ (each ^300 hop)
   cs (map (k \ seen k) ^300) steps (map (k \ cs (k + 1) - cs k) ^299)
   fx (on 1 15) _ (pins fx 'drift 0 'wx (sky-weather 2 'smooth))
   _ (each ^300 (k \ (pin fx 'sim (fx 'sim + 3600.0), court-move fx)))
 (test (#jan = 20) (n 3 jul < n 3 jan) (n 0 jan < n 0 jul)
       (all (d \ -1 <= d && d <= 1) steps) (any (d \ d != 0) steps)
       (fx 'wx 'cover = 2) (court-month day0 = 10)))

; --- the words: a date, a time, a pace and the weather, in any order, each at most once;
; --- a date alone keeps now's hour; a pace leads the paces t steps through; words it cannot
; --- read refuse
(: o (court-opts ["--date" "2026-10-25" "--time" "16:30" "--pace" "120" "--weather" "overcast" "--sky" "pixel"])
   w (court-opts ["partly"]) n (court-opts [])
   d (court-opts ["--date" "2026-07-04"]) dn (court-now ())
   bad (map court-opts [["--date" "2026-13-01"] ["--time" "25:00"] ["--pace" "x"] ["--pace"]
                        ["clear" "--weather" "mostly"] ["--sky" "smooth" "pixel"] ["nope"]])
   (day v) (int (v 0) // 86400)
 (test (o 'pace = 120.0) (o 'wx 'cover = 3) (o 'wx 'style = 'pixel)
       (day (o 'now) = (cite 'cal 'epoch-days) 2026 10 25) (int (o 'now 0) % 86400 = 59400)
       (o 'now 1 = 3600) (court-clock {'sim (o 'now 0)} = "16:30")
       (w 'wx 'cover = 1) (w 'wx 'style = 'smooth) (w 'pace = ()) (n 'wx = ()) (two? (n 'now))
       (day (d 'now) = (cite 'cal 'epoch-days) 2026 7 4) (int (d 'now 0) % 86400 = int (dn 0) % 86400)
       (all (v \ v = ()) bad)
       ; ..a cover said holds the weather; a style alone leaves it to the season
       (o 'fix = 1) (w 'fix = 1) (court-opts ["--sky" "pixel"] @ k (k 'fix = 0 && k 'wx 'style = 'pixel))))

(borrow 'sky)

; --- the weather: c steps the cover, v the style; the more cover, the more of the sky is
; --- cloud in either style; under overcast the sun is all but off the walls; and the
; --- styles draw different skies
(: st (at 13.0)
   _ (pin st 'wx (sky-weather 0 'smooth))
   _ (keys! st [99]) w1 (st 'wx)
   _ (keys! st [118]) w2 (st 'wx)
   _ (keys! st [99 99 99]) w3 (st 'wx)
   clear (sky-light (court-sun st) (sky-weather 0 'smooth) (st 'sim))
   oc (sky-light (court-sun st) (sky-weather 3 'smooth) (st 'sim))
   ; the sky above 25 degrees, a golden spiral of rays: the share of it that is not the
   ; clear sky's colour
   n 3000 i (iota n) y (0.42 + 0.58 * (i + 0.5) / n) r (sqrt (1.0 - y * y))
   dx (r * cos (i * 2.39996)) dz (r * sin (i * 2.39996)) sim (st 'sim) s (court-sun st)
   (cloud c sty) (: wx (sky-weather c sty) lt (sky-light s wx sim)
                    k (sky-colour lt wx dx y dz 0.0 0.0 sim 0)
                    k0 (sky-colour lt (sky-weather 0 sty) dx y dz 0.0 0.0 sim 0)
                    (net (0.15 < mag (k 0 - k0 0) + mag (k 1 - k0 1) + mag (k 2 - k0 2)) / (1.0 * n)))
   (rises sty) (: f (map (c \ cloud c sty) [1 2 3]) (f 0 < f 1 && f 1 < f 2 && 0.1 < f 0 && 0.9 < f 2))
   sm (court-frame (pins (at 15.0) 'ph 1.4 'wx (sky-weather 2 'smooth)))
   px (court-frame (pins (at 15.0) 'ph 1.4 'wx (sky-weather 2 'pixel)))
 (test (w1 'cover = 1) (w1 'style = 'smooth) (w2 'cover = 1) (w2 'style = 'pixel)
       (w3 'cover = 0) (w3 'style = 'pixel)
       (oc 'sunk < 0.25 * clear 'sunk) (clear 'cover < oc 'cover)
       (rises 'smooth) (rises 'pixel) (sm != px)))
(test_fin ())
(puts "court: ok")
