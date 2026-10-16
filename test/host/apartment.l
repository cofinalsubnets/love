; test/host/apartment.l -- the glass cube on the plain, headless: the lay, glass that holds, the
; talk through the pane, the ending, the song into a jug. not in the corpus: a crew module.
; run: cat test/00-init.l test/host/00-host.l test/host/apartment.l | out/love

(borrow 'apartment)
(borrow 'rove)        ; dat, open?, the words

(: (range a b) (map (+ a) ^(b - a))
   ; the cells you can walk to from where you stand, eight ways at a step
   (reach g) (: d (g 'd) w (d 'w) h (d 'h) seen {}
                (nbs i) (: x (i % w) y (i // w)
                           (filter (j \ 0 <= j)
                                   (map ([dx dy] \ (: nx (x + dx) ny (y + dy)
                                                     (0 <= nx < w && 0 <= ny < h && open? d nx ny ? (nx + w * ny) -1)))
                                        '((1 0) (-1 0) (0 1) (0 -1) (1 1) (-1 -1) (1 -1) (-1 1)))))
                (go l) (l @- seen (i . u) (seen i ? (go u) (pin seen i 1, go (u + nbs i))))
                (go [(g 'p 'x + w * g 'p 'y)]))
   (blocky? s) (0 < #s && 0 = #s % 3 && all (i \ elem (snip s (3 * i) (3 * i + 3)) blocks) ^(#s // 3)))

; the lay: eight cubes round a hub, you closed in yours, the stranger outside at the pane
(: g (apartment-new 80 22 (wheel 5)) d (g 'd) w 80 h 22 c (d 'cube) p (g 'p) npc (g 'npc)
   (t x y) (dat d x y)
   hub (d 'hub) hx <hub hy <>hub east (d 'east)
   pn (c 4)
   in (reach g)
   f (apartment-frame g) f2 (apartment-frame g)
   ; the river's row in a column (the stone counts), or -1
   (river-at x) (filter (y \ elem (t x y) '(4 8)) ^h @ ys (two? ys ? <ys -1))
   ; a cube's pane faces the river, and the column from there to the river is path
   (pathed? cb) (: q (cb 4) x <q y <>q above (y < hy) ry (river-at x)
                   ys (above ? (range (y + 1) ry) (range (ry + river-h) y))
                   (6 = t x y && x = cb 0 + cube-w // 2 && (above ? (y = cb 1 + cube-h - 1) (y = cb 1))
                    && all (yy \ 3 = t x yy) ys))
   (walls cb) (filter (i \ (: x (i % w) y (i // w)
                              (cb 0 <= x < cb 0 + cube-w && cb 1 <= y < cb 1 + cube-h && !(inside? cb x y))))
                      ^(w * h))
   ; the others' places before any turn
   was (map (m \ [(m 'x) (m 'y)]) (g 'ms))
   _ (apartment-turn g 32)
   _ (each ^30 (i \ apartment-turn g '(0 -1)))
   now (map (m \ [(m 'x) (m 'y)]) (g 'ms))
 (test (h-rows f = h + 2) (f = f2)
       (all (x \ 0 <= river-at x) ^w)
       (hx < east < w - 1)
       (all (x \ |(river-at x - river-at (x + 1)) <= 1) ^(w - 1))
       (any (x \ river-at x != river-at 0) ^w)
       ; but keeps a row of grass off every cube
       (all (cb \ all (x \ (river-at x @ ry
                              (ry < 0 || cb 1 + cube-h < ry || ry + river-h < cb 1)))
                      (range (cb 0) (cb 0 + cube-w)))
            (d 'cubes))
       (all (cb \ cb 0 + cube-w - 1 <= east) (d 'cubes))
       (d 'stone @ st (8 = t <st <>st && <st < 5 && |(<>st - river-at (<st - 1)) <= 1))   ; the stone (8) near the west edge
       (8 = #(d 'cubes)) (all pathed? (d 'cubes))
       (all (cb \ all (i \ 6 = peep (d 't) i 0) (walls cb)) (d 'cubes))   ; glass (6) all round
       (all (cb \ c 1 <= cb 1) (d 'cubes))
       (any (cb \ cb 1 = c 1 && c 0 < cb 0) (d 'cubes))
       (c 0 + cube-w // 2 < hx) (c 1 + cube-h // 2 < hy)
       (inside? c (p 'x) (p 'y)) (1 = t (p 'x) (p 'y))         ; you, on grass (1) inside yours
       (all (i \ inside? c (i % w) (i // w)) (keys in))         ; closed: nowhere to walk but inside
       (#(keys in) = (cube-w - 2) * (cube-h - 2))
       (tablet? npc) !(inside? c (npc 'x) (npc 'y))
       (6 = t <pn <>pn) (g 'pane = <pn + w * <>pn)
       (|(npc 'x - <pn) <= 1) (|(npc 'y - <>pn) <= 1)
       (7 = #(g 'ms))
       (all (m \ inside? (m 'cube) (m 'x) (m 'y) && !(inside? c (m 'x) (m 'y))) (g 'ms))
       (was != now)
       (blocky? (npc 'nm))
       !(g 'talk)
       (apartment-new 80 22 (wheel 5) @ g1 (two? (g1 'sign) && (apartment-turn g1 32, !(g1 'sign))))   ; a key takes the opening sign down
       (apartment-new 80 22 (wheel 5) @ g2 (g2 'npc 'nm = npc 'nm && g2 'd 'cube = c))))

; the interior cell nearest the pane, and the step into it
(: (clampi v lo hi) (v < lo ? lo (hi < v ? hi v))
   (by-pane c) (: pn (c 4) ix (clampi <pn (c 0 + 1) (c 0 + cube-w - 2)) iy (clampi <>pn (c 1 + 1) (c 1 + cube-h - 2))
                  [ix iy [(<pn - ix) (<>pn - iy)]]))

; glass holds, but the pane the stranger stands at opens the talk
(: g (apartment-new 80 22 (wheel 5)) d (g 'd) w 80 c (d 'cube) p (g 'p) npc (g 'npc)
   _ (apartment-turn g 32)
   _ (pins p 'x (c 0 + 1) 'y (c 1 + 1), apartment-turn g '(-1 -1))
   x1 (p 'x) y1 (p 'y) m1 (g 'msg) k1 (g 'talk)
   bp (by-pane c)
   _ (pins p 'x (bp 0) 'y (bp 1), apartment-turn g (bp 2))
   sg (g 'sign)
 (test (x1 = c 0 + 1) (y1 = c 1 + 1) (0 < #m1) !k1
       ('start = g 'talk) (two? sg) (<sg = npc 'nm)
       (p 'x = bp 0) (p 'y = bp 1)))

; the talk walks its tree; a leaf ends it
(: g (apartment-new 80 22 (wheel 5)) d (g 'd) w 80 h 22 c (d 'cube) p (g 'p) npc (g 'npc)
   (t x y) (dat d x y) pn (c 4)
   _ (apartment-turn g 32)
   bp (by-pane c)
   _ (pins p 'x (bp 0) 'y (bp 1), apartment-turn g (bp 2))
   root (chat-node 'start) c1 <(root 2)
   _ (apartment-turn g (48 + <c1)) k1 (g 'talk)
   _ (apartment-turn g 120) k2 (g 'talk)                          ; x is no choice: shown again
   leaf <(filter (e \ atom? (e 2)) chat-book)
   out <(filter (i \ 1 = peep (d 't) i 0 && !(inside? c (i % w) (i // w))) ^(w * h))
   _ (chat g <leaf) s1 (g 'sign)
   _ (apartment-turn g 32)
   in (reach g)
   bones (map (m \ [(m 'x) (m 'y)]) (g 'ms))
   (each ^20 (i \ apartment-turn g '(-1 -1)),
    test (k1 = c1 2) (k2 = c1 2) (two? s1)
         !(g 'talk) !(g 'sign) !(g 'npc)
         (elem 'drum (g 'sfx)) (0 < #(g 'msg))
         (7 = t <pn <>pn) (open? d <pn <>pn)                       ; the pane shards (7), and a way
         (g 'desert) (2 = peep (d 't) out 0)                        ; grass outside is sand (2)
         (1 = t (p 'x) (p 'y)) (all (i \ 1 = peep (d 't) i 0) (filter (i \ inside? c (i % w) (i // w)) ^(w * h)))
         (any (i \ 5 = peep (d 't) i 0) (keys in))                 ; the riverbed (5) a walk away
         (all (m \ m 'bones && m 'gl = bones-glyph) (g 'ms))        ; the others bones where they stood
         (bones = map (m \ [(m 'x) (m 'y)]) (g 'ms))
         (pins p 'x (bp 0) 'y (bp 1), apartment-turn g (bp 2), p 'x = <pn && p 'y = <>pn)
         (h-rows (apartment-frame g) = h + 2)
         ; the river dry: the stone reads, and west off the map along the bed is the way out
         (all (i \ 4 != peep (d 't) i 0) ^(w * h))
         (any (i \ 0 = i % w && 5 = peep (d 't) i 0) (keys in))
         (d 'stone @ st
          (pins p 'x (<st + 1) 'y <>st, apartment-turn g '(-1 0),
           (p 'x = <st && p 'y = <>st && two? (g 'sign))))
         (: st (d 'stone) _ (apartment-turn g 32) wy <(filter (y \ 5 = t 0 y) ^h)
            (pins p 'x 0 'y wy, apartment-turn g '(-1 0),
             ('west = g 'over)))))

; the river runs on its own clock; the grass, and a dry bed, stand still
(: g (apartment-new 80 22 (wheel 5)) d (g 'd) w 80 h 22
   (cells t) (filter (i \ t = peep (d 't) i 0) ^(w * h))
   (faces is) (map (apartment-face g) is)
   water (cells 4) grass (cells 1)
   aw (faces water) ag (faces grass) _ (pin g 'wt 2.0) bw (faces water) bg (faces grass)
   _ (pin g 'wt 0.0) cw (faces water)
   _ (pins g 'desert 1, each (cells 4) (i \ pin (d 't) i 5))
   bed (cells 5) dry (faces bed) _ (pin g 'wt 2.0) dry2 (faces bed)
 (test (aw != bw) (ag = bg) (aw = cw) (dry = dry2)))

; the song: the drone at once, the phrase soon and every so often, the drum when asked
(: j (jug 0) s (apartment-song-new j (wheel 7))
   _ (each ^5 (i \ apartment-song-feed s))
   quiet (slurp j) k0 (s 'struck)
   n0 #(s 'vs)
   _ (each ^(30 * (phrase-first + 1)) (i \ apartment-song-feed s))
   heard (slurp j) k1 (s 'struck)
   _ (each ^(30 * 3 * phrase-every) (i \ apartment-song-feed s))
   k2 (s 'struck)
   s2 (apartment-song-new (jug 0) (wheel 7))
   _ (each ^(5 + 30 * (phrase-first + 1) + 30 * 3 * phrase-every) (i \ apartment-song-feed s2))
   g (apartment-new 80 22 (wheel 5))
   d (apartment-song-new (jug 0) (wheel 9))
   _ (pin g 'sfx '(drum))
   _ (apartment-sfx d g)
   n1 #(d 'vs)
   j2 (jug 0) _ (pin d 'h j2)
   _ (each ^40 (i \ apartment-song-feed d))
   loud (slurp j2)
 (test (#quiet = 5 * 4 * song-chunk) (any (i \ 0 != quiet (i * 89)) ^(#quiet // 89)) (k0 = 0)   ; the drone before any phrase
       (n0 = 1)
       (drone-voice () 1 (iota 4800) @ y (1.0 < amax y - amin y))     ; a wave, not a level
       (k1 = 1) (any (i \ 0 != heard (i * 89)) ^(#heard // 89))
       ; a phrase is its notes and each note's echoes
       (: s3 (apartment-song-new (jug 0) (wheel 7)) _ (apartment-song-feed s3, pin s3 'next 0, apartment-song-feed s3)
          vs >(s3 'vs)
          (#vs = #phrase * (1 + #phrase-echoes) && all (v \ v 0 < 1099511627776) vs))
       (2 <= k2 - k1 <= 4)
       (s2 'struck = k2) (s2 'next = s 'next)
       (0 < n1) !(g 'sfx)
       (#loud = 40 * 4 * song-chunk) (any (i \ 0 != loud (i * 89)) ^400)))

; a tap on the talk's sign is a choice's digit, off the box 0 (the node again); with no sign it steers
(: g (apartment-new 80 22 (wheel 5)) d (g 'd) p (g 'p)
   _ (chat g 'start)
   ls >(g 'sign)
   (row-of t) (: (go i) (has? (ls i) t ? i (go (i + 1))) (go 0))
   (tap-at i) (: (go y) (y > 40 ? -1 (i = sign-line <(g 'sign) ls 1 (peep d 'h-rows (d 'h)) (peep d 'cols (d 'w)) y ? y (go (y + 1)))) (go 0))
   k2 (tap-key g [40 (tap-at (row-of "Where is this place?"))])
   k0 (tap-key g [0 0])
   _ (apartment-turn g k2)
   here (g 'talk)
   _ (pins g 'sign () 'talk ())
   (at dx dy) (tap-key g [(p 'x + dx + peep d 'vx 0) (p 'y + dy + 1 + peep d 'vy 0)])
 (test (50 = k2) (0 = k0) ('here = here)
       ('(1 0) = at 5 0) ('(-1 -1) = at -4 -2) ('(0 1) = at 0 3)
       ('(1 0) = rove-key g 108) (113 = rove-key g 113)))

(test_fin (),
 puts "apartment: ok -- the plain is laid, the cube is closed, the stranger talks through the pane, and the end opens it\n")
