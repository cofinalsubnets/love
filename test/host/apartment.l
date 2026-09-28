; --- test/host/apartment.l: the glass cube on the plain, headless ---
; not in the test/*.l corpus (it loads a crew module). the level is pure love, so
; everything but the tty runner gates here: the lay -- the road, the cubes each with a
; path to it, yours closed round you with the stranger at its pane -- the names in
; blocks, the sign, glass that holds, the talk through the pane from its first node to
; a leaf, and the end: the stranger gone, the pane open, the drum asked for, the grass
; outside gone to sand and the plain reachable; and the song into a jug.
;   cat test/00-init.l test/host/apartment.l | out/love

(borrow 'apartment)   ; the artifact's module, warm from the tree
(borrow 'rove)        ; dat, open?, the words

(: (find h n i) (i + #n < 1 + #h ? (n = snip h i (i + #n) ? 1 (find h n (i + 1))) 0)
   (count s n) (:- (go 0 0) (go i k) (i + #n <= #s ? (go (i + 1) (k + (n = snip s i (i + #n)))) k))
   (rows s) (1 + count s "\r\n")
   (range a b) (map (+ a) ^(b - a))
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

; --- the lay: eight cubes in an octagon, yours the left of the top pair, the road west
; --- from the hub, every cube a path to it, and yours closed with you inside and the
; --- stranger outside at the pane; someone in every other cube, wandering it
(: g (apartment-new 80 22 (wheel 5)) d (g 'd) w 80 h 22 c (d 'cube) p (g 'p) npc (g 'npc)
   (t x y) (dat d x y)
   hub (d 'hub) hx <hub hy <>hub east (d 'east)
   pn (c 4)
   in (reach g)
   f (apartment-frame g) f2 (apartment-frame g)
   ; the river's row in a column -- the stone's counts, it stands in the water -- or -1 where there is none
   (river-at x) (: ys (filter (y \ elem (t x y) '(4 8)) ^h) (two? ys ? <ys -1))
   ; a cube's pane is its glass, in its middle column on the river's side, and the
   ; column from there to the river is path
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
   _ (each ^30 (i \ apartment-turn g '(0 -1)))                   ; thirty turns at the wall
   now (map (m \ [(m 'x) (m 'y)]) (g 'ms))
 (test (rows f = h + 2) (f = f2)                                ; the note row, the plain, the bar
       (all (x \ 0 <= river-at x) ^w)                            ; the river, edge to edge
       (hx < east < w - 1)
       (all (x \ |(river-at x - river-at (x + 1)) <= 1) ^(w - 1))   ; ..a row a column, never a jump
       (any (x \ river-at x != river-at 0) ^w)                   ; ..and it wanders
       ; ..but keeps a row of grass off every cube it passes
       (all (cb \ all (x \ (: ry (river-at x)
                              (ry < 0 || cb 1 + cube-h < ry || ry + river-h < cb 1)))
                      (range (cb 0) (cb 0 + cube-w)))
            (d 'cubes))
       (all (cb \ cb 0 + cube-w - 1 <= east) (d 'cubes))
       (: st (d 'stone) (8 = t <st <>st && <st < 5 && |(<>st - river-at (<st - 1)) <= 1))   ; the stone in the bed near the west edge
       (8 = #(d 'cubes)) (all pathed? (d 'cubes))               ; eight, each with a path in
       (all (cb \ all (i \ 6 = peep (d 't) i 0) (walls cb)) (d 'cubes))   ; ..each glass all round
       (all (cb \ c 1 <= cb 1) (d 'cubes))                     ; yours on the top row
       (any (cb \ cb 1 = c 1 && c 0 < cb 0) (d 'cubes))         ; ..the left of a pair there
       (c 0 + cube-w // 2 < hx) (c 1 + cube-h // 2 < hy)         ; ..up and left of the hub
       (inside? c (p 'x) (p 'y)) (1 = t (p 'x) (p 'y))         ; you, on grass inside yours
       (all (i \ inside? c (i % w) (i // w)) (keys in))         ; ..and closed: nowhere to walk but inside
       (#(keys in) = (cube-w - 2) * (cube-h - 2))
       (tablet? npc) (!(inside? c (npc 'x) (npc 'y)))           ; the stranger outside
       (6 = t <pn <>pn) (g 'pane = <pn + w * <>pn)              ; ..a pane between, on your glass
       (|(npc 'x - <pn) <= 1) (|(npc 'y - <>pn) <= 1)           ; ..which they stand against
       (7 = #(g 'ms))                                            ; the others, one to a cube, none in yours
       (all (m \ inside? (m 'cube) (m 'x) (m 'y) && !(inside? c (m 'x) (m 'y))) (g 'ms))
       (was != now)                                              ; ..and they wander, inside still
       (blocky? (npc 'nm))                                       ; named in blocks
       (!(g 'talk))
       (: g1 (apartment-new 80 22 (wheel 5)) (two? (g1 'sign) && (apartment-turn g1 32, !(g1 'sign))))   ; the opening sign stands, and a key takes it down
       ; the same seed lays the same plain and names the same stranger
       (: g2 (apartment-new 80 22 (wheel 5)) (g2 'npc 'nm = npc 'nm && g2 'd 'cube = c))))

; where you stand to bump the pane from inside: the interior cell nearest it, and the step
(: (clampi v lo hi) (v < lo ? lo (hi < v ? hi v))
   (by-pane c) (: pn (c 4) ix (clampi <pn (c 0 + 1) (c 0 + cube-w - 2)) iy (clampi <>pn (c 1 + 1) (c 1 + cube-h - 2))
                  [ix iy [(<pn - ix) (<>pn - iy)]]))

; --- glass holds, but for the pane the stranger stands at, which opens the talk ---
(: g (apartment-new 80 22 (wheel 5)) d (g 'd) w 80 c (d 'cube) p (g 'p) npc (g 'npc)
   _ (apartment-turn g 32)
   _ (pins p 'x (c 0 + 1) 'y (c 1 + 1)) _ (apartment-turn g '(-1 -1))   ; up into the corner
   x1 (p 'x) y1 (p 'y) m1 (g 'msg) k1 (g 'talk)
   bp (by-pane c)
   _ (pins p 'x (bp 0) 'y (bp 1)) _ (apartment-turn g (bp 2))     ; into the pane
   sg (g 'sign)
 (test (x1 = c 0 + 1) (y1 = c 1 + 1) (0 < #m1) (nil? k1)      ; held, and something said
       ('start = g 'talk) (two? sg) (<sg = npc 'nm)             ; the talk, under the stranger's name
       (p 'x = bp 0) (p 'y = bp 1)))                             ; ..and you never moved

; --- the talk walks its tree; a leaf closes it, and that is the end ---
(: g (apartment-new 80 22 (wheel 5)) d (g 'd) w 80 h 22 c (d 'cube) p (g 'p) npc (g 'npc)
   (t x y) (dat d x y) pn (c 4)
   _ (apartment-turn g 32)
   bp (by-pane c)
   _ (pins p 'x (bp 0) 'y (bp 1)) _ (apartment-turn g (bp 2))
   root (chat-node 'start) c1 <(root 2)
   _ (apartment-turn g (48 + <c1)) k1 (g 'talk)
   _ (apartment-turn g 120) k2 (g 'talk)                          ; x is no choice: shown again
   leaf <(filter (e \ atom? (e 2)) chat-book)
   ; a grass cell outside the cube, and one inside, before the end
   out (<(filter (i \ 1 = peep (d 't) i 0 && !(inside? c (i % w) (i // w))) ^(w * h)))
   _ (chat g <leaf) s1 (g 'sign)
   _ (apartment-turn g 32)
   in (reach g)
   bones (map (m \ [(m 'x) (m 'y)]) (g 'ms))
   _ (each ^20 (i \ apartment-turn g '(-1 -1)))                  ; twenty turns at the corner
 (test (k1 = c1 2) (k2 = c1 2) (two? s1)
       (!(g 'talk)) (!(g 'sign)) (!(g 'npc))                    ; closed, and the stranger gone
       (elem 'drum (g 'sfx)) (0 < #(g 'msg))                     ; the drum asked for, and something said
       (7 = t <pn <>pn) (open? d <pn <>pn)                       ; the pane is shards, and a way
       (g 'desert) (2 = peep (d 't) out 0)                        ; the grass outside is sand
       (1 = t (p 'x) (p 'y)) (all (i \ 1 = peep (d 't) i 0) (filter (i \ inside? c (i % w) (i // w)) ^(w * h)))
       (any (i \ 5 = peep (d 't) i 0) (keys in))                 ; ..and the riverbed is a walk away
       (all (m \ m 'bones && m 'gl = bones-glyph) (g 'ms))        ; the others are bones
       (bones = map (m \ [(m 'x) (m 'y)]) (g 'ms))               ; ..where they stood
       (pins p 'x (bp 0) 'y (bp 1), apartment-turn g (bp 2), p 'x = <pn && p 'y = <>pn)   ; out onto the pane
       (rows (apartment-frame g) = h + 2)
       ; the river is dry to the west edge, and walked: a step onto the stone reads it,
       ; and a step west off the map along the bed is the way out
       (all (i \ 4 != peep (d 't) i 0) ^(w * h))
       (any (i \ 0 = i % w && 5 = peep (d 't) i 0) (keys in))
       (: st (d 'stone) _ (pins p 'x (<st + 1) 'y <>st) _ (apartment-turn g '(-1 0))
          (p 'x = <st && p 'y = <>st && two? (g 'sign)))
       (: st (d 'stone) _ (apartment-turn g 32) wy (<(filter (y \ 5 = t 0 y) ^h))
          _ (pins p 'x 0 'y wy) _ (apartment-turn g '(-1 0))
          ('west = g 'over))))

; --- the river runs on its own clock: further along it, its cells paint differently and
; --- the grass paints the same; dry, its bed stands still with the rest
(: g (apartment-new 80 22 (wheel 5)) d (g 'd) w 80 h 22
   (cells t) (filter (i \ t = peep (d 't) i 0) ^(w * h))
   (faces is) (map (apartment-face g) is)
   water (cells 4) grass (cells 1)
   aw (faces water) ag (faces grass) _ (pin g 'wt 2.0) bw (faces water) bg (faces grass)
   _ (pin g 'wt 0.0) cw (faces water)
   _ (pins g 'desert 1) _ (each (cells 4) (i \ pin (d 't) i 5))
   bed (cells 5) dry (faces bed) _ (pin g 'wt 2.0) dry2 (faces bed)
 (test (aw != bw) (ag = bg) (aw = cw) (dry = dry2)))

; --- the song: the drone from the first frame, the phrase soon after and again every so
; --- often, each note with its echoes behind it; the drum sounds where it is asked for
(: j (jug 0) s (apartment-song-new j (wheel 7))
   _ (each ^5 (i \ apartment-song-feed s))
   quiet (slurp j) k0 (s 'struck)
   n0 #(s 'vs)
   _ (each ^(30 * (phrase-first + 1)) (i \ apartment-song-feed s))    ; on past the first
   heard (slurp j) k1 (s 'struck)
   _ (each ^(30 * 3 * phrase-every) (i \ apartment-song-feed s))       ; a minute more
   k2 (s 'struck)
   s2 (apartment-song-new (jug 0) (wheel 7))
   _ (each ^(5 + 30 * (phrase-first + 1) + 30 * 3 * phrase-every) (i \ apartment-song-feed s2))   ; as far as s
   g (apartment-new 80 22 (wheel 5))
   d (apartment-song-new (jug 0) (wheel 9))
   _ (pin g 'sfx '(drum))
   _ (apartment-sfx d g)
   n1 #(d 'vs)
   j2 (jug 0) _ (pin d 'h j2)
   _ (each ^40 (i \ apartment-song-feed d))
   loud (slurp j2)
 (test (#quiet = 5 * 4 * song-chunk) (any (i \ 0 != quiet (i * 89)) ^(#quiet // 89)) (k0 = 0)   ; the drone, before any phrase
       (n0 = 1)
       (: y ((drone-voice ()) 1 (iota 4800)) (1.0 < amax y - amin y))   ; ..and it is a wave, not a level
       (k1 = 1) (any (i \ 0 != heard (i * 89)) ^(#heard // 89))          ; the phrase, once, and heard
       ; a phrase is its notes and each note's echoes, every echo behind its note and softer
       (: s3 (apartment-song-new (jug 0) (wheel 7)) _ (apartment-song-feed s3) _ (pin s3 'next 0) _ (apartment-song-feed s3)
          vs >(s3 'vs)
          (#vs = #phrase * (1 + #phrase-echoes) && all (v \ v 0 < 1099511627776) vs))
       (2 <= k2 - k1 <= 4)                                                ; ..and every so often after
       (s2 'struck = k2) (s2 'next = s 'next)                             ; the same seed strikes the same
       (0 < n1) (!(g 'sfx))
       (#loud = 40 * 4 * song-chunk) (any (i \ 0 != loud (i * 89)) ^400)))

(test_fin (),
 puts "apartment: ok -- the plain is laid, the cube is closed, the stranger talks through the pane, and the end opens it\n")
