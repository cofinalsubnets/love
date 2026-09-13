; rove -- quay's roguelike engine, and the tower it carries.
;
; a floor is tiles in a cask (0 rock, 1 floor, 2 the stair up) carved by delve, with a
; seen cask for what the climber has been shown; fov is line-of-sight over bresenham
; strides; the painter says a frame of painted cells into any port, so frames gate
; headless; the helm turns a key into a steer. each tier is built of its own stuff and
; its litter is the cell's own dice, so a floor reproduces with its rooms.
;
; the climb rides all of it: the garden, the middle and heaven, pennies underfoot and a
; stair above, then the circle. pure state in, pure state out, one key per turn. it is
; not a game about fighting -- a turn spent acting mends the bar and a turn passed does
; not, so a climber dies only by standing still beside something.
;
; a floor's music is a rule and not a recording, built off the cycle number through the
; same dice that strews it, and fed to the card from the climb's own loop.
;
; run: love tower. the engine is pure love and gates headless in t/host/rove.l; only
; tower-run ties the tty, and t/host/tty.l plays it on a pty.
(module (rove tower-run tower-main dat open? dput delve fov clear? paint steer tap-steer
         crawl-new crawl-turn crawl-frame crawl-bar note mob-new mob-at mob-set roll stock
         mend ascend fill fit circle? circle-new circle-stride circle-frame
         circle-r circle-wall on-ring? reveal? done? tokens floors due?
         themes plan tile-face strewn pink-ramp grass-ramp pink-front skin-pen
         flavour mutter underfoot sign-box sign-over stream feat-book her-floors ents loot-face
         city carve-floor car-new car-head drive run-down corner? road? lit? climb-hp deal first-n
         sky her-lines mirror
         songs tower-bars tower-tune song-vol song-new song-feed song-tier song-sfx drain-keys
         garden-bars middle-bars sky-bars heart-bars heart-rate tune?)
; posix is optional -- the page's seat (i/wasm) links none of it and this file runs
; there, so ask before splicing: an absent module is a scare.
(? (cite 'posix) (borrow 'posix) ())
; and ink, which the last floor paints with: the shader the walk runs, stopped
(borrow 'ink)
(:
 ; --- the floor: tiles in a cask, (x y) indexed; 0 rock, 1 ground, 2 the stair, 3 water,
 ; 4 a building's floor, 5 a door, 6 glass -- looked through and never entered: a road's
 ; end off the map, heaven's void -- 7 a step and 8 a platform ---
 (dat d x y) (0 <= x < d 'w && 0 <= y < d 'h ? (peep (d 't) (x + (d 'w) * y) 0) 0)
 (open? d x y) (: t (dat d x y) (0 < t && t != 6))     ; walked
 (lit? d x y) (0 < dat d x y)                           ; looked through
 (dput d x y v) (pin (d 't) (x + (d 'w) * y) v)

 ; a spun rng: the functional state in a box, one draw steps it
 (roll sb n) (: p (random (peep sb () 0) n) (pin sb () >p, <p))

 ; --- delve: carve rooms, lash them with corridors ---
 ; a room is [x y rw rh]; its center anchors the corridors. rooms keep a
 ; one-cell gap so no two merge; each new room tunnels to the previous one,
 ; so the whole floor is connected by construction. answers (floor . st').
 ; the plan is the tier's own -- wide from, wide by, tall from, tall by, and one
 ; try per so many cells -- which is what makes the garden a patch of small beds
 ; and heaven a few long blocks.
 (delve w h st pl) (:
   d {'w w 'h h 't (cask (w * h)) 'seen (cask (w * h)) 'rooms ()}
   sb {st}
   (mid rm) [(peep rm 0 0 + peep rm 2 1 // 2) (peep rm 1 0 + peep rm 3 1 // 2)]
   (carve x0 y0 rw rh) (: (row y x) (x < x0 + rw ? (dput d x y 1, row y (x + 1)))
                          (rows y) (y < y0 + rh ? (row y x0, rows (y + 1)))
                          (rows y0))
   (hallx y xa xb) (carve (xa < xb ? xa xb) y (1 + |(xb - xa)) 1)
   (hally x ya yb) (carve x (ya < yb ? ya yb) 1 (1 + |(yb - ya)))
   (lash [ax ay] [bx by])
    (roll sb 2 ? (hallx ay ax bx, hally bx ay by)
                 (hally ax ay by, hallx by ax bx))
   (apart? rm) (all (o \ 1 + peep rm 0 0 + peep rm 2 1 <= peep o 0 0 ||
                         1 + peep o 0 0 + peep o 2 1 <= peep rm 0 0 ||
                         1 + peep rm 1 0 + peep rm 3 1 <= peep o 1 0 ||
                         1 + peep o 1 0 + peep o 3 1 <= peep rm 1 0))
   (try n) (? (0 < n)
            (: rw ((pl 0) + roll sb (pl 1)) rh ((pl 2) + roll sb (pl 3))
               (? (w <= rw + 2 || h <= rh + 2) (try (n - 1))
                ; the span a room of width rw can start at, keeping a 1-cell border: x is
                ; 1 + roll(w - rw - 1), so the far edge lands at w-2 at worst. (this read `+ 1`
                ; while the additive band folded right and w - (rw + 1) is the same number --
                ; the hand made the arithmetic say what it means.)
                (: x (1 + roll sb (w - rw - 1)) y (1 + roll sb (h - rh - 1))
                   rm [x y rw rh]
                 (? !(apart? rm (d 'rooms)) (try (n - 1))
                  (carve x y rw rh,
                   d 'rooms ? (lash (mid rm) (mid <(d 'rooms))),
                   pin d 'rooms (rm . d 'rooms),
                   try (n - 1)))))))
   _ (try ((w * h) // (pl 4)))
   ; a cramped floor can come up short: guarantee two joined rooms
   _ (#(d 'rooms) < 2 ?
      (: r1 '(1 1 3 3) r2 [(w - 4) (h - 4) 3 3]
         (carve 1 1 3 3, carve (w - 4) (h - 4) 3 3,
          lash (mid r1) (mid r2), pin d 'rooms [r2 r1])))
   _ (pins d 'in (mid (last (d 'rooms)))
             'stair (mid <(d 'rooms)))
   _ (dput d <(d 'stair) <>(d 'stair) 2)
   ; ..and a second stair in another room, where the floor has one to spare
   _ (? (2 < #(d 'rooms)) (: s2 (mid ((d 'rooms) 1)) (dput d <s2 <>s2 2)))
   (d . peep sb () 0))

 ; --- city: the middle is not delved but laid -- streets on a grid, two cells across
 ; and one along, and the blocks between them buildings: a wall ring with a floor
 ; inside, and two or three doors on different walls, every wall facing a street. the
 ; climber arrives inside the last building; the stairs are inside two others. a
 ; block too small to hold a room stays solid. answers (floor . st') like delve. ---
 street-x 12                                            ; a block's stride across, and along
 street-y 6
 (city w h st) (:
   d {'w w 'h h 't (cask (w * h)) 'seen (cask (w * h)) 'rooms ()}
   sb {st}
   (mid rm) [(peep rm 0 0 + peep rm 2 1 // 2) (peep rm 1 0 + peep rm 3 1 // 2)]
   ; where the streets start: from a, at the stride and a jitter, the last one at lim
   (spine a lim step jit) (:- (go a [a])
     (go x acc) (: nx (x + step + roll sb jit)
                   (nx + (step // 2) < lim ? (go nx (nx . acc)) (rev (lim . acc)))))
   xs (spine 1 (w - 3) street-x 6)
   ys (spine 1 (h - 2) street-y 2)
   _ (each xs (x \ each ^h (y \ (dput d x y 1, dput d (x + 1) y 1))))
   _ (each ys (y \ each ^w (x \ dput d x y 1)))
   ; every road runs off the map: its border cell is glass, driven through and not walked
   (glass x y) (? (1 = dat d x y) (dput d x y 6))
   _ (each xs (x \ (glass x 0, glass (x + 1) 0, glass x (h - 1), glass (x + 1) (h - 1))))
   _ (each ys (y \ (glass 0 y, glass (w - 1) y)))
   ; a block between four streets: the wall ring is left as rock, the inside is floor
   (build xa xb ya yb) (: x0 (xa + 2) x1 (xb - 1) y0 (ya + 1) y1 (yb - 1)
                          bw (x1 - x0 + 1) bh (y1 - y0 + 1)
                          (? (bw >= 5 && bh >= 3)
                             (: _ (each ^(bh - 2) (j \ each ^(bw - 2) (i \ dput d (x0 + 1 + i) (y0 + 1 + j) 4)))
                                ; the doors: two or three walls of the four, one door each
                                walls (deal sb '(n s w e))
                                (door wl) (wl @ 'n (dput d (x0 + 1 + roll sb (bw - 2)) y0 5)
                                                's (dput d (x0 + 1 + roll sb (bw - 2)) y1 5)
                                                'w (dput d x0 (y0 + 1 + roll sb (bh - 2)) 5)
                                                   (dput d x1 (y0 + 1 + roll sb (bh - 2)) 5))
                                _ (each (first-n (2 + roll sb 2) walls) door)
                                (pin d 'rooms ([(x0 + 1) (y0 + 1) (bw - 2) (bh - 2)] . d 'rooms)))))
   (pairs l) (two? >l ? ([<l (l 1)] . pairs >l) ())
   _ (each (pairs ys) (yy \ each (pairs xs) (xx \ build <xx <>xx <yy <>yy)))
   rms (d 'rooms)
   ; a floor too small for three buildings is delved instead, like any other
   (#rms < 3 ? (delve w h st (plan 2))
    (: _ (pins d 'in (mid (last rms)) 'stair (mid <rms))
       _ (dput d <(d 'stair) <>(d 'stair) 2)
       s2 (mid (rms 1))
       _ (dput d <s2 <>s2 2)
       (d . peep sb () 0))))
 ; --- heaven: platforms in a void. a platform is a rhombus of checkered floor, twice as
 ; wide as it is tall because a cell is; each one is joined to the one before it by a
 ; stairway, a line of steps three cells across so it is walked without a diagonal
 ; step. the void between is glass: looked across, never entered. answers like delve ---
 plat-from 4                                            ; a platform's half-width, from and by
 plat-by 5
 (sky w h st) (:
   d {'w w 'h h 't (cask (w * h)) 'seen (cask (w * h)) 'rooms ()}
   sb {st}
   _ (each ^(w * h) (i \ pin (d 't) i 6))
   (mid rm) [(peep rm 0 0 + peep rm 2 1 // 2) (peep rm 1 0 + peep rm 3 1 // 2)]
   (rhomb cx cy a b f) (each ^(2 * b + 1) (j \ each ^(2 * a + 1)
                                                (i \ (: x (cx - a + i) y (cy - b + j)
                                                        (|(x - cx) * b + |(y - cy) * a <= a * b ? (f x y))))))
   (plat cx cy a b) (rhomb cx cy a b (\ x y (dput d x y 8)))
   ; the stairway: bresenham from middle to middle, a step laid on the void either side
   (step x y) (? (6 = dat d x y) (dput d x y 7))
   (walk [ax ay] [bx by]) (:
     dx |(bx - ax) dy (0 - |(by - ay))
     sx (? (ax < bx) 1 -1) sy (? (ay < by) 1 -1)
     (go x y e) (: _ (step (x - 1) y, step x y, step (x + 1) y)
                   (? (x = bx && y = by) ()
                      (: e2 (2 * e) mx (dy <= e2) my (e2 <= dx)
                         (go (mx ? (x + sx) x) (my ? (y + sy) y) (e + (mx ? dy) + (my ? dx))))))
     (go ax ay (dx + dy)))
   ; a cell of void between any two platforms' bounds -- a rhombus leaves its corners
   ; empty, so two that nearly touch still have the void between them
   (apart? rm) (all (o \ 1 + peep rm 0 0 + peep rm 2 1 <= peep o 0 0 ||
                         1 + peep o 0 0 + peep o 2 1 <= peep rm 0 0 ||
                         1 + peep rm 1 0 + peep rm 3 1 <= peep o 1 0 ||
                         1 + peep o 1 0 + peep o 3 1 <= peep rm 1 0))
   ; ..and a platform stands off the last one both ways, so the stairway between them
   ; is a diagonal: that is what makes them look to be at different heights
   (askew? m o) (2 <= |(<m - <o) && 2 <= |(<>m - <>o))
   (try n) (? (0 < n)
            (: a (plat-from + roll sb plat-by) b (a // 2)
               (? (w <= 2 * a + 3 || h <= 2 * b + 3) (try (n - 1))
                (: cx (a + 1 + roll sb (w - 2 * a - 2)) cy (b + 1 + roll sb (h - 2 * b - 2))
                   rm [(cx - a) (cy - b) (2 * a + 1) (2 * b + 1)]
                 (? !(apart? rm (d 'rooms)) (try (n - 1))
                    (d 'rooms && !(askew? (mid rm) (mid <(d 'rooms)))) (try (n - 1))
                  (d 'rooms ? (walk (mid rm) (mid <(d 'rooms))),
                   plat cx cy a b,
                   pin d 'rooms (rm . d 'rooms),
                   try (n - 1)))))))
   _ (try ((w * h) // 25))
   rms (d 'rooms)
   ; a floor too cramped for two platforms is delved instead, like any other
   (#rms < 2 ? (delve w h st (plan 3))
    (: _ (pins d 'in (mid (last rms)) 'stair (mid <rms))
       _ (dput d <(d 'stair) <>(d 'stair) 2)
       s2 (mid (rms 1))
       _ (dput d <s2 <>s2 2)
       (d . peep sb () 0))))
 ; a floor is delved or laid by its tier
 (carve-floor w h st lvl) (lvl @ 2 (city w h st) 3 (sky w h st) (delve w h st (plan lvl)))

 ; a list dealt out in a random order, and the first n of one
 (deal sb l) (:- (go l ())
   (go l acc) (two? l ? (: k (roll sb #l) (go (cat (snip-l l 0 k) (nth-on l (k + 1))) ((l k) . acc))) acc))
 (snip-l l a b) (a >= b ? () ((l a) . snip-l l (a + 1) b))
 (nth-on l k) (k <= 0 ? l (nth-on >l (k - 1)))
 (first-n n l) (0 < n && two? l ? (<l . first-n (n - 1) >l) ())

 ; --- the lantern: line-of-sight fov over bresenham strides ---
 ; a stride is clear when every cell strictly between the ends is looked through; the
 ; endpoint itself may be rock -- that is how a wall catches the light.
 (clear? d x0 y0 x1 y1) (:
   dx |(x1 - x0) dy (0 - |(y1 - y0))
   sx (? (x0 < x1) 1 -1) sy (? (y0 < y1) 1 -1)
   (go x y e) (? (x = x1 && y = y1) 1
               (: e2 (2 * e)
                  mx (dy <= e2) my (e2 <= dx)
                  nx (? mx (x + sx) x) ny (? my (y + sy) y)
                  ne (e + (mx ? dy) + (my ? dx))
                  (? (nx = x1 && ny = y1) 1
                     (lit? d nx ny) (go nx ny ne)
                     0)))
   (go x0 y0 (dx + dy)))

 ; the visible set: a tablet of cell indices, radius-bounded and stride-clear;
 ; each visible cell is also pinned into the floor's seen cask (the memory).
 ; a closing pass glows the rock beside every lit floor cell, so corridors
 ; wear their walls (a bare stride only catches rock end-on)
 (fov d px py r) (:
   vis {} w (d 'w) h (d 'h) sn (d 'seen) r2 (1 + r * r)
   (glow x y) (: i (x + w * y) (pin vis i 1, pin sn i 1, ()))
   (cell x y) (2 (x - px) + 2 (y - py) <= r2 && clear? d px py x y ? (glow x y))
   (row y x) (x <= px + r ? (cell x y, row y (x + 1)))
   (rows y) (y <= py + r ? (row y (px - r), rows (y + 1)))
   _ (rows (py - r))
   _ (flip map (keys vis) (i \ 0 < peep (d 't) i 0 ?
      (: x (i % w) y (i // w)
       (map (\ o (: nx (x + <o) ny (y + <>o)
                  (0 <= nx < w && 0 <= ny < h && dat d nx ny = 0 ? (glow nx ny))))
            '((-1 -1) (0 -1) (1 -1) (-1 0)
              (1 0) (-1 1) (0 1) (1 1))))))
   vis)

 ; --- the painter: one frame said into a port as painted cells ---
 ; glyph/hue per cell -- an ent on a lit cell, else loot, else the tile: lit
 ; tiles bright, remembered ones dim, the dark a bare space. one SGR per hue
 ; change, threaded down the frame; the port is any jug, so frames gate headless.
 pens {}
 (pen n) (: s (pens n) (string? s ? s
          (: s2 ("\e[38;5;" + show n + "m") (pin pens n s2, s2))))
 ; two multiply-shift rounds masked to 32 bits: the dice a cell throws for itself,
 ; so the same cell of the same floor always throws the same number.
 lim 4294967296
 (mix a) (: h ((a * 2654435761) % lim)
            h2 ((h ^ (h >> 15)) * 2246822519 % lim)
            (h2 ^ (h2 >> 13)))
 (dice x y s k) ((mix (y * 374761393 + x * 668265263 + s * 2654435761 + 1)) % k)

 ; --- the make of each floor: rock, the ground, what is strewn over it, and the plan
 ; its rooms are cut to -- the only place a tier's look is written. a face is
 ; (glyph lit dim), and a strewing carries a fourth number: cells in a hundred -- and
 ; may carry a sixth, its weight inside a bed, where flowers grow together.
 th-garden '((38 28 22) (46 137 94)                     ; hedge and dirt
             ((42 212 89 1 "aster" 30) (42 220 136 1 "marigold" 30)
              (44 71 65 34 "tuft") (34 34 22 30 "grass") (126 38 24 3 "runnel"))
             (4 7 2 4 14))                              ; beds, wide and a good many
 th-middle '((35 246 238) (46 245 239)                  ; stone and flagstone
             ((44 241 237 16 "rubble") (58 240 236 10 "gravel")
              (37 187 95 6 "bones") (42 251 244 4 "quartz"))
             (4 7 3 4 24))                              ; rooms, the middling sort
 ; ..and a fifth thing where the floor has glass in it: what is seen through it, strewn
 ; the same way over nothing. the middle's is the road going on; heaven's is stars.
 th-heaven '((35 255 249) (32 0 0)                      ; marble, and the dark
             ()
             (8 9 4 5 40)                               ; blocks, if it must be delved
             ((42 231 239 2 "star") (46 250 239 5 "star") ("·" 245 239 2 "star")))
 themes [th-garden th-middle th-heaven]
 ; heaven's floors: a platform is checkered, light grey and blue, and a step between two
 ; of them is the grey in between
 plat-grey '("█" 252 245)
 plat-blue '("█" 33 24)
 step-face '("▒" 245 239)
 (plat-face x y lit) (wear ((x + y) % 2 = 0 ? plat-grey plat-blue) lit)
 ; the garden's greens are not one green, nor its browns one brown: the hedge wears a
 ; still frame of the walk's shimmer -- the circle's field -- and the ground another,
 ; out of phase, so a bed is one shade here and another there in bands, not the mottle
 ; dice would give. the ramps run pale to deep, keyed by the pen the theme gave the
 ; cell; only the lantern's light shows a grade, memory is flat.
 hedge-ramp [70 34 34 28 28 22 22 22]
 lawn-ramp [118 112 76 70 40 34 28 22]
 dirt-ramp [180 137 137 136 94 94 95 58]
 garden-greens {28 'hedge 137 'dirt 34 'lawn 71 'lawn}
 (plan lvl) ((peep themes (lvl - 1) th-heaven) 3)
 stair-face '(60 220 136)                               ; < the stair, gold on every floor
 water-face '(126 39 24)                                ; ~ the stream, where it shows
 floor-face '(46 240 236)                               ; . a building's floor, dark
 door-face '(43 137 94)                                 ; + a door, brown
 ; what lies on a cell besides pennies: furniture, which stands there to be bumped and
 ; says one thing. glyph, pen lit, pen dim, the line. a glyph here is a string, so
 ; the page's own letters serve (quay folds them onto its face).
 ; ..and a fifth thing where there is one: a book the piece opens, its title then its
 ; pages, a stanza to a page
 feat-book {'table ["π" 240 236 "an overgrown stone table stained with dark liquid"]
            'throne ["H" 130 94 "a large tree stump carved into an ornate throne sits empty"]
            'chair ["h" 137 94 "a chair, pushed back from nothing"]
            'bed ["=" 131 95 "a bed, made, and cold"]
            'crate ["x" 136 94 "a crate. it has been opened and closed again"]
            'fountain ["☼" 226 136 "a fountain, and what it throws up and catches is stars"]
            'mirror ["@" 93 54 "a mirror, and the one in it is not quite you"]
            'shelf ["≡" 180 137 "a bookshelf, and one book on it: Muse"
                    '("Muse"
                      ("by Donald Revell"
                       ""
                       "You are somewhere very close to the porch."
                       "The evening makes crazy sounds, but makes sense."
                       "The unpackaged, greeny neighborhood settles"
                       "into true night far from the expressway"
                       "and farther from the calligrams of the downtown."
                       "The visits to the paintings failed me."
                       "The new music faded underground with the last trains,"
                       "with stripped hours and many lovers.")
                      ("I did not imagine a stronger life,"
                       "listening for your step on the porch step,"
                       "imagining your dress a size too large"
                       "billowing the obscene print of summer."
                       "Anything composed is an obscenity:"
                       "a painter's phlox in vertical brushstrokes,"
                       "a dressmaker's parody of stupid earth,"
                       "a radio's jazz clawed by cats.")
                      ("A stronger life exists but is no one's friend."
                       "She lives in the crook of the expressway"
                       "in a high building. She tucks her hair behind"
                       "her ears and carries a clear drink to the window."
                       "No one ever paints her portrait. Her name"
                       "is ugly and can't be put to music."
                       "And at her neck and ankles a long dress"
                       "blackens calligrams I read with my fingers.")
                      ("The truth of those black messages is cold."
                       "The imagination has no power over life,"
                       "and between inspirations that are lovers"
                       "and inspirations that are a kind of machinery"
                       "repainted every year but irreparable"
                       "the only thing actual at day's end"
                       "is night's uncomposed, leafy tunelessness."
                       "I will not open the door when you arrive.")
                      ("I will not call my lost loves to wish them well."
                       "In my house in darkness behind the porch"
                       "I pound the walls and make an animal noise"
                       "as the neighborhood rises and runs en masse"
                       "onto the expressway to be destroyed"
                       "or dragged downtown to touch the calligrams"
                       "and feel nothing that is green, made, or harmonious."
                       "It is loveless time, the neck and ankles of time.")
                      ("I need more loneliness than alone is,"
                       "the deep, uninspired dark of America"
                       "where sexy lawns, the phlox, the print dresses"
                       "and hymn stanzas like tiny, circular railroads"
                       "ask for no response and no love"
                       "but a clear drink in the solitary evening"
                       "when no muse visits, when crazy animal sounds"
                       "make sense and I read the truth with my hands."))]}
 (feat-of k) (peep feat-book k '("?" 250 244 ""))
 (feat-face k) (: r (feat-of k) [(r 0) (r 1) (r 2)])
 (feat-line k) ((feat-of k) 3)
 (feat-lines k) (peep (feat-of k) 4 ())
 ; a piece with a book opens it a page at a time: every page is a sign under the book's
 ; title, and the key that takes one down puts the next up. the foot is read here and
 ; not in the words below: a lambda reads a value bound above it, never one below
 page-foot "-- ~ of ~, any key --"
 (bump-feat g k) (: bk (feat-lines k)
                    _ (note g (feat-line k))
                    (two? bk ?
                     (: n #>bk
                        (page i) (<bk . ((>bk i) + ["" (fill page-foot [(i + 1) n])]))
                        pgs (map page ^n)
                        (pins g 'sign <pgs 'pages >pgs))))
 ; a pile of pennies is bright and only under the lantern; furniture is remembered
 (loot-face it lit) (<it @ 'penny '(36 172) (wear (feat-face <it) lit))

 ; a cell's face: the stair, the rock, or the ground with whatever it was strewn with
 (make d) (peep d 'th th-middle)                        ; a floor nobody dressed is stone
 (wear r lit) [<r (lit ? (r 1) (r 2))]
 ; a bed is a block of cells that throws one die together, so what clusters, clusters
 bed-w 5
 bed-h 3
 bed-share 30
 (bed? x y s) ((dice (x // bed-w) (y // bed-h) (s + 7) 100) < bed-share)
 (strew l x y s bed) (: (wt r) (bed && 5 < #r ? (r 5) (r 3))
                        (go l h) (two? l ?  (: r <l w (wt r) (h < w ? r (go >l (h - w)))))
                        (go l (dice x y s 100)))
 (strewn th x y s) (strew (th 2) x y s (bed? x y s))
 (tile-face th t lit x y s)
  (t @ 2 (wear stair-face lit)
       3 (wear water-face lit)
       4 (wear floor-face lit)
       5 (wear door-face lit)
       6 (: r (strew (peep th 4 ()) x y (s + 3) 0) (wear (two? r ? r (th 1)) lit))
       7 (wear step-face lit)
       8 (plat-face x y lit)
       0 (wear <th lit)
         (: r (strewn th x y s) (wear (two? r ? r (th 1)) lit)))
 (paint j d vis loot ents msg bar) (:
   w (d 'w) h (d 'h) sn (d 'seen)
   th (make d) sd (peep d 'sd 0)
   skin (d 'skin)
   ; the scrutinee in its own parens: an infix ? left bare would take the @- as its arm
   (shade gh x y) ((tablet? skin ? (garden-greens <>gh) ()) @- gh
                   'hedge [<gh (ramp-pen hedge-ramp (peep (skin 'hedge) [y x] 0.0))]
                   'lawn [<gh (ramp-pen lawn-ramp (peep (skin 'ground) [y x] 0.0))]
                   'dirt [<gh (ramp-pen dirt-ramp (peep (skin 'ground) [y x] 0.0))])
   spot (foldl (\ t e (pin t (e 'x + w * e 'y) e)) {} ents)
   ; the note row through `fit`: a message may carry the token's braces, and an
   ; escape is no width, so the cut is made in what a reader sees
   _ (say j $ "\e[H\e[0m" + (fit msg w) + "\e[K\r\n")
   (cell i lit) (: e (lit ? (spot i))
                   l (loot i)
                   it (l && (lit || (<l != 'penny && peep sn i 0)) ? l ())
                   (? e [(e 'gl) (e 'hue)]
                      it (loot-face it lit)
                      (peep sn i 0)
                       (: gh (tile-face th (peep (d 't) i 0) lit (i % w) (i // w) sd)
                          (lit ? (shade gh (i % w) (i // w)) gh))
                      '(32 0)))
   (row y x i p) (x >= w ? p
                  (: gh (cell i (peep vis i 0))
                     p2 <>gh
                   (p != p2 ? (say j (pen p2)),
                    say j (string <gh),
                    row y (x + 1) (i + 1) p2)))
   (rows y p) (y >= h ? p (rows (y + 1) (: p2 (row y 0 (w * y) p) _ (say j "\r\n") p2)))
   (rows 0 -1,
    say j "\e[0m", say j bar, say j "\e[K",
    j))

 ; --- the helm: a key (cli's edkey: a byte, an arrow code, an alt letter) -> one steer,
 ; a move pair; any other key answers as itself ---
 (steer k)
  (k @ (104 || -1) '(-1 0)  (106 || -9) '(0 1)  (107 || -8) '(0 -1)  (108 || -2) '(1 0)
       (121 || 377) '(-1 -1) (117 || 373) '(1 -1) (98 || 354) '(-1 1) (110 || 366) '(1 1)
       k)

 ; ..and a tap is a place rather than a letter: one step of the eight toward the cell it
 ; landed on, and a tap on the cell you stand on is the stair. the note row is the
 ; screen's first, so a screen y is a floor y and one. c is [x y], cli's edtap.
 (toward a b) (a < b ? 1 (a > b ? -1 0))
 (tap-steer g c) (: p (g 'p)
                    dx (toward (p 'x) <c)
                    dy (toward (p 'y) (<>c - 1))
                    (dx = 0 && dy = 0 ? 60 [dx dy]))

 ; --- the words: every line the climb says. a ~ takes the next value and {braces} are
 ; the token's pen; nothing below is built, so this block is the whole of the text.
 w-open   "the tower stands over you. get the {token}"
 w-floor  "this is ~. get the {token}"
 w-strike "you strike the ~ (~)"
 w-kill   "the ~ is done for"
 w-bite   "the ~ bites you (~)"
 w-dead   "you are done for"
 w-car    "a car takes you off your feet (~)"
 w-wall   "~ holds"
 w-glass  "nothing is there, and it holds"
 w-mirror "the mirror takes you, and lets you out of another"
 w-alone  "the mirror shows you yourself, and keeps you"
 w-stair  "no stair here"
 w-penny  "you pocket ~ pennies"
 w-ring   "you strike the circle"
 w-bar    "~  hp ~/~  pennies ~"
 w-bar-up "~  hp ~/~  pennies ~  < climbs"
 w-won    "the {token} is yours: {~} -- and ~ pennies besides"
 w-fled   "you leave the tower with ~ pennies"
 w-lost   "the tower keeps you, in ~"
 w-args   "tower: takes no arguments, not ~\n"
 floors   '("the garden" "the middle" "heaven" "the circle")
 (here g) (floors (g 'lvl - 1))                         ; the floor, by name
 ; the sign the tower opens on; a {brace} is the token's pen. kept short: twenty rows
 ; leave eighteen for the map, and a taller box is one with its foot cut off.
 sign-ttl "the tower"
 sign-open '("you are @, at the foot of the tower."
             ""
             "move     h j k l    or the arrow keys"
             "         y u b n    for the corners"
             "wait     .          a turn passes, nothing mends"
             "climb    < or enter while you stand on a stair"
             "leave    q          or esc"
             ""
             "a stair is a gold < set in one of the rooms:"
             "walk onto it and press < to take it up."
             ""
             "get the {token}, and the pennies on the way."
             ""
             "-- any key --")
 ; the tower's fauna: name, glyph, pen, hp, bite, pace. pace is turns per stir, so
 ; heaven's shapes take two and a climber who would rather not fight walks past them.
 mob-book '(("rat" 114 137 3 1 1) ("lanternfly" 108 175 3 1 1)
            ("gnome" 119 101 6 2 1) ("goblin" 103 71 8 2 1) ("hobgoblin" 71 64 11 3 1)
            ("d4" 52 189 4 1 2) ("d6" 54 189 6 2 2) ("d8" 56 189 8 2 2)
            ("d12" 100 189 12 3 2) ("d20" 118 189 20 3 2)  ; duodecimal, vigesimal
            ("triangle" 94 213 8 2 2) ("square" 37 213 11 2 2) ("hexagon" 38 213 15 3 2))
 ; which rows of it a floor bears
 (mob-set lvl) (lvl @ 1 '(0 1) 2 '(2 3 4) '(5 6 7 8 9 10 11 12))
 ; and what the token turns out to have been, drawn once at the end
 tokens '("the thumbworn phone" "the stubnibbed pencil" "the faded script"
          "the solebare shoe" "the handpaged book" "the rubbed coin"
          "the relit candle" "the lockmachined key" "the refolded map"
          "the carbonized lamp" "the residual spectacles" "the steamset kettle"
          "the gearworn watch" "the lowlife battery" "the treasured index card")
 token-pen 201                                          ; and the pen it is named in

 ; --- the music: a slot is a voice tablet play can sound or () for silence, a bar is
 ; slots across one cycle, and a floor answers a list of bars sounded together. all of
 ; it off the cycle number through the floors' own dice, so nothing is stored.
 ; `songs` is how loud a floor is; the circle's is the ring's size instead.
 songs '(2.00 1.60 2.60 2.60)
 (vox nm nt gn lg) {'s nm 'note nt 'gain gn 'legato lg}

 ; the garden: chimes nobody strikes -- mostly nothing, now and then a note, now and
 ; then a gust of three. a pentatonic has no interval in it that can sound wrong.
 chime-tones [0 2 4 7 9 12 14 16 19 21 24 26]
 chime-slots 16
 (gust? c i) (0 <= i && dice i c 12 100 < 7)
 (chime-slot c i)
  (dice i c 11 100 < 11 ||
      gust? c (i - 1) ||
      gust? c (i - 2) ?
     (vox (dice i c 14 3 = 0 ? "tri" "sin")
          (chime-tones (dice i c 13 #chime-tones))
          (0.55 + dice i c 15 45 / 100.0)
          (1.30 + dice i c 16 120 / 100.0)))
 (garden-bars c) [(map (chime-slot c) ^chime-slots)]

 ; the middle: traffic, a horn being two notes a major third apart and gone. a third
 ; of the time it settles into five minor phrases instead -- and the roll is on the run
 ; of five, not the bar, so a tune arrives as one and leaves as one.
 horn-tones [24 26 27 29 31]
 horn-slots 12
 blue-phrases '((-3 0 4 2 0 -1) (-3 -1 0 2 4 2) (5 4 2 0 -1 -3)
                (-3 4 2 -1 0 -3) (0 2 4 5 4 2))
 blue-drop 12                                           ; ..sounded below where it is written
 (horn-on? c i) ((dice i c 21 100) < 9)
 (horn-slot c i k)
  (horn-on? c i ?
   (vox "sqr" (horn-tones (dice i c 22 #horn-tones) + 4 * k)
        0.40 (0.20 + dice i c 23 45 / 100.0)))
 (tune? c) ((dice (c // #blue-phrases) 0 31 100) < 34)
 (blue-bars c) (: ph (blue-phrases (c % #blue-phrases))
                  (v i) (vox (i % 2 = 0 ? "tri" "sqr")
                             (ph i - blue-drop) 0.95 0.52)
                  [(map v ^#ph)])
 (middle-bars c) (? (tune? c) (blue-bars c)
                    [(map (i \ horn-slot c i 0) ^horn-slots)
                     (map (i \ horn-slot c i 1) ^horn-slots)])

 ; heaven: long sequences, four bars each, rolled per block so the city goes round
 ; something but not to a schedule. two are hopeful about it and one is not sure.
 sky-songs
 '((((12 16 19 24 19 16) (14 17 21 26 21 17) (16 19 23 28 23 19) (12 19 24 31 24 19))
    "tri" 1.00)
   (((12 15 19 22 19 15) (13 17 20 25 20 17) (10 14 17 22 17 14) (8 15 20 24 20 15))
    "sin" 1.24)
   (((19 24 26 31 26 24) (17 22 26 29 26 22) (16 19 24 28 24 19) (12 19 24 28 31 24))
    "tri" 0.90))
 sky-run 4                                              ; bars to a sequence
 (sky-bars c) (: s (sky-songs (dice (c // sky-run) 0 41 #sky-songs))
                 phs <s
                 ph (phs (c % sky-run))
                 [(map (n \ vox (s 1) n (s 2) 0.55) ph)])

 ; the circle: a heart, lub then dub a quarter-beat behind, three beats to a bar while
 ; the ring is wide and one at the point. the fade is the ring's too.
 ; two voices to a beat because the kick alone runs 134 Hz down to 46 and a small
 ; speaker answers none of it; the snare over it is noise, which every speaker answers.
 heart-lub {'s "bd" 'gain 0.90}
 heart-dub {'s "bd" 'gain 0.55 'speed 1.25}
 knock-lub {'s "sn" 'gain 0.40 'legato 0.13}
 knock-dub {'s "sn" 'gain 0.26 'legato 0.10 'speed 1.30}
 heart-div 8                                            ; slots to a beat
 (heart-rate r) (1 + (r // 3))
 (heart-bars r) (: n (heart-rate r)
                   (beat lub dub i) (: j (i % heart-div)
                                       (? (j = 0) lub (j = 2) dub ()))
                   ix (jot (heart-div * n))
                   [(map (beat heart-lub heart-dub) ix)
                    (map (beat knock-lub knock-dub) ix)])

 ; the floor's bars: which cycle it is, and how wide the ring is if it is the ring's
 (tower-bars lvl c r) (lvl @ 1 (garden-bars c) 2 (middle-bars c) 3 (sky-bars c)
                               (heart-bars r))

 song-rate 48000
 song-cps 0.5                                           ; cycles a second
 song-chunk 1600                                        ; a frame's worth, thirty a second
 song-gain 5200.0

 ; --- the flavour: a row is a strewing's or a mob's name, then its lines. which line
 ; is the cell's own dice, so one tuft always says the same thing and its neighbour
 ; says another. a name with no row here is silent.
 flavour
 '(("tuft"       "the grass here has gone to seed"
                 "a beetle leaves the way you came"
                 "something slept here and is gone")
   ("grass"      "the grass comes up past your ankles"
                 "seed heads stick to your legs"
                 "it is wet down where the light does not get")
   ("aster"      "an aster, pink and past its best"
                 "the petals are going brown at the edge"
                 "it is facing the way the light was")
   ("marigold"   "marigolds, and the smell of them on your hands"
                 "the yellow is louder than the flower"
                 "one is open and the rest are waiting")
   ("stream"     "the stream runs quick over the stones, and the sound of it settles you"
                 "minnows, a swarm of them, turn as one away from your foot"
                 "clear to the bottom, and the bottom is all small fish, moving"
                 "cold through your shoes, and the noise of it is the calmest thing here")
   ("floor"      "a floor nobody has swept in a while"
                 "boards, and they give a little"
                 "dust, and your prints in it")
   ("door"       "a door, and it stands open"
                 "the frame is lower than you are"
                 "you turn sideways to get through")
   ("platform"   "a floor of squares, and nothing under every one of them"
                 "the stars are below you as well as above"
                 "the checkers do not ring underfoot, which they should")
   ("steps"      "steps, going down to the next floor, or up -- it is hard to say"
                 "there is no rail on the steps, and the void either side"
                 "the steps are wide enough. you do not look over")
   ("runnel"     "a thread of water, going somewhere"
                 "colder and quicker than it looks"
                 "it has cut its own small channel here")
   ("rubble"     "stone that used to be somewhere higher"
                 "it turns underfoot"
                 "someone swept it into this corner, once")
   ("gravel"     "gravel, and the sound of you on it"
                 "it has been walked before"
                 "small stones, worn round")
   ("bones"      "bones, picked clean and set down tidily"
                 "not lately"
                 "small ones: a rat, or a rat's dinner")
   ("quartz"     "a seam of quartz takes your light and keeps it"
                 "it is warmer than the stone around it"
                 "the wall is brighter here for a step")
   ("cobbles"    "cobbles, laid by someone with time"
                 "worn hollow down the middle"
                 "the joints are packed with nothing at all")
   ("lamp"       "a lamp, lit, with nobody to have lit it"
                 "the light does not flicker"
                 "it is warm and gives nothing off")
   ("bench"      "a bench, facing the street"
                 "it has been sat on"
                 "nothing is carved into it, which is strange")
   ("fountain"   "a fountain runs with nobody to hear it"
                 "the water goes up as fast as it comes down"
                 "there is money in the bottom, and it is not pennies")
   ("star"       "a star, at ankle height"
                 "it does not move when you do"
                 "the floor is a sky here, briefly")
   ("stair"      "a stair, and it goes up into the dark"
                 "the steps are worn hollow in the middle"
                 "it is colder on the stair than off it")
   ("pennies"    "copper, gone green at the rims"
                 "somebody counted these out and left them"
                 "they have been here longer than you have"
                 "warm, which is the strange part")
   ("rat"        "a rat, and it has seen worse than you"
                 "it does not hurry")
   ("lanternfly" "a lanternfly, spotted and slow"
                 "it lands on you as though you were furniture")
   ("gnome"      "a gnome: a worm the length of your arm"
                 "it goes on longer than it looks")
   ("goblin"     "a goblin, in something it took off someone"
                 "it is working out whether you are worth it")
   ("hobgoblin"  "a hobgoblin, and it is not working anything out"
                 "bigger than the door it came through")
   ("d4"         "a d4, which lands wrong whatever it does"
                 "it is the one that hurts to stand on")
   ("d6"         "a d6, honest and unremarkable"
                 "the pips are worn smooth on the six")
   ("d8"         "a d8, turning to show you every face"
                 "it has settled on nothing")
   ("d12"        "a d12, with more faces than it has any use for"
                 "it rolls a long way")
   ("d20"        "a d20, and it knows what it is for"
                 "it is waiting on the one number")
   ("triangle"   "a triangle, and it has made its mind up"
                 "three sides and no argument")
   ("square"     "a square, sat exactly where it is"
                 "it will not be moved a hair")
   ("hexagon"    "a hexagon, eyed the whole way round"
                 "every eye is on you, which is the point of it"))

 ; a name's lines, and the one it says this time
 (lines-of nm)
  (:- (go flavour) (go l)
   (two? l ? (: r <l (? (nm = <r) >r (go >l)))))
 (mutter k nm)
  (lines-of nm @ ls (two? ls ? (peep ls (k % #ls) "") ""))

 ; a line and its holes: each ~ takes the next value, a string as itself and anything
 ; else as show, so a table line reads as the line it prints.
 (hole v) (string? v ? v (show v))
 (fill s vs) (: (go i acc vs)
                 (? (i >= #s) acc
                    (: c (s i)
                       (? (c = 126 && two? vs) (go (i + 1) (acc + hole <vs) >vs)
                          (go (i + 1) (acc + string c) vs))))
                (go 0 "" vs))
 ; ..and its braces, put on at the port. an escape is no width, so this is also where
 ; a line is cut to fit: the row's span is what a reader sees, not what a cask holds.
 (fit s w) (: on ("\e[38;5;" + show token-pen + "m") off "\e[0m"
              (go i n acc)
               (? ((i >= #s) || (n >= w)) acc
                  (: c (s i)
                     (? (c = 123) (go (i + 1) n (acc + on))
                        (c = 125) (go (i + 1) n (acc + off))
                        (go (i + 1) (n + 1) (acc + string c)))))
              (go 0 0 ""))

 ; --- the sign: a box over the frame, story's lighthouse way. braces cost no width, so
 ; it is measured in what a reader sees, and it runs to the row's end so no pen meets.
 sign-pen 252
 (vlen s) (: (go i n) (? (i >= #s) n
                         (: c (s i) (go (i + 1) (? ((c = 123) || (c = 125)) n (n + 1)))))
             (go 0 0))
 (pad s n c) (: v (vlen s) (v >= n ? s (s + ((n - v) (\ t (t + c)) ""))))
 (sign-box ttl ls) (:
   w (foldl (\ a l (vlen l @ v (a < v ? v a))) (vlen ttl) ls)
   ww (w + 4)
   top ("+-" + pad (ttl + " ") (ww - 3) "-" + "+")
   bot ("+" + ((ww - 2) (t \ t + "-") "") + "+")
   ([top] + (map (l \ "| " + pad l (ww - 4) " " + " |") ls) + [bot]))
 ; the first n cells of a painted row: an SGR has no width, so the count is of glyphs.
 ; a painted row ends on \e[K, an escape with no m, so the skip stops at the end too
 (cells-cut r n) (:- (go 0 0 "")
                  (past i) (i >= #r ? i (r i @ 109 (i + 1) (past (i + 1))))
                  (go i k acc)
                   (i >= #r || k >= n ? acc
                    (r i @ 27 (past i @ e (go e k (acc + snip r i e)))
                     (go (i + 1) (k + 1) (acc + string (r i))))))
 ; ..and the other side of the same cut: the cells from n on. EVERY escape is kept, from
 ; the row's start and not from n, because a colour is a state and the one in force at
 ; cell n was set somewhere to its left -- drop those and the tail wears whatever the
 ; caller happened to leave on.
 (cells-from r n) (:- (go 0 0 "")
                   (past i) (i >= #r ? i (r i @ 109 (i + 1) (past (i + 1))))
                   (go i k acc)
                    (i >= #r ? acc
                     (r i @ 27 (past i @ e (go e k (acc + snip r i e)))
                      (go (i + 1) (k + 1) (k >= n ? (acc + string (r i)) acc)))))
 ; a frame with the box centred over its rows a .. a+n, for a screen w wide. a line
 ; wider than the screen is reflowed at its words -- story's own wrap -- and the box
 ; takes the rows it makes
 (sign-over f ttl ls a n w) (:- (go 0 "")
   rs (split "\r\n" f)
   wr (cite 'story 'wrap)
   (flow l) (wr && (w - 4) < vlen l ? (wr l (w - 4)) [l])
   box (sign-box ttl (foldl (+) () (map flow ls)))
   ww (vlen <box)
   x0 (: q ((w - ww) // 2) (0 < q ? q 0))
   y0 (: q (a + (n - #box) // 2) (a < q ? q a))
   ; ..and never past the rows it was given: a box too tall for the screen loses its
   ; foot, which is the screen's doing, but the bar under it is not the box's to take
   (lay i) (rs i @ r
            (!(y0 <= i < y0 + #box && i < a + n) ? r
             ; the field either side of the box, and the box between them. the tail is
             ; not decoration: a row that stops at the box leaves the cells past it
             ; holding whatever the LAST frame put there, and the floor before this one
             ; is where that comes from.
             (cells-cut r x0 + "\e[0m" + pen sign-pen + fit (box (i - y0)) 400
              + "\e[0m" + cells-from r (x0 + ww))))
   (go i acc) (i >= #rs ? acc (go (i + 1) (acc + (0 < i ? "\r\n" "") + lay i))))

 ; keys typed at a game are not typed at the shell: raw mode does not echo them, so
 ; whatever is left takes the next reader's line. the bin, before cooked mode returns.
 (drain-keys _) (cue? 0 ? (see in, drain-keys ()))

 ; --- the climb: the proving game. state in a tablet, one key per turn ---
 ; the bar is not a resource: a turn spent acting mends and a turn passed does not.
 ; forty against a worst bite of three means one mob is a nuisance and two are a death.
 regen 2
 climb-hp 20
 (mend g) (: p (g 'p) h ((p 'hp) + regen) (pin p 'hp (h < p 'mx ? h (p 'mx))))
 (mob-row k) (peep mob-book k <mob-book)
 (mob-name k) <(mob-row k)
 (mob-new k x y) (: r (mob-row k)
                   {'x x 'y y 'gl (peep r 1 114) 'hue (peep r 2 137)
                    'hp (peep r 3 3) 'dm (peep r 4 1) 'pc (peep r 5 1) 'nm <r})

 ; --- the cars: the middle's traffic, on the roads and never off them. a car keeps
 ; its heading and its speed, turns at a crossing now and then and nowhere else, and
 ; drives off the map where its road does, to come in again by another. one that
 ; reaches you takes you off your feet -- a step aside, where there is one -- and
 ; sounds its horn twice. it waits for nothing but another car, and cannot be struck.
 car-speed 3
 car-dm 10
 car-pens '(196 226 39 250 208 201)
 (car-glyph dx dy) (? (0 < dx) "►" (dx < 0) "◄" (0 < dy) "▼" "▲")   ; the face's own arrows
 (car-new x y dx dy hue) {'x x 'y y 'dx dx 'dy dy 'gl (car-glyph dx dy) 'hue hue
                          'car 1 'nm "car" 'hp 99 'dm car-dm 'pc 1}
 (car-head m dx dy) (pins m 'dx dx 'dy dy 'gl (car-glyph dx dy))
 (car-back m) (car-head m (0 - m 'dx) (0 - m 'dy))
 (street? d x y) (1 = dat d x y)
 (road? d x y) (: t (dat d x y) (t = 1 || t = 6))
 ; a corner is where the road across runs two cells that way: the other lane of your
 ; own road is one cell of it, and a building's wall none
 (corner? d x y dx dy) (road? d (x + dx) (y + dy) && road? d (x + 2 * dx) (y + 2 * dy))
 ; the horn, twice, and the hurt: what a car does when it reaches you either way
 (run-down g m) (: p (g 'p)
                   _ (pin p 'hp (p 'hp - car-dm))
                   _ (note g (fill w-car [car-dm]))
                   _ (pin g 'sfx ('horn . g 'sfx))
                   _ (shove g m)
                   (0 >= p 'hp ? (pin g 'over 'dead, note g w-dead)))
 ; ..and the step aside: to either side of the car's line, where a cell is free
 (shove g m) (: p (g 'p) sb (g 'sb)
                cs (roll sb 2 = 0 ? [[(m 'dy) (0 - m 'dx)] [(0 - m 'dy) (m 'dx)]]
                                    [[(0 - m 'dy) (m 'dx)] [(m 'dy) (0 - m 'dx)]])
                (go l) (two? l ? (: c <l nx (p 'x + <c) ny (p 'y + <>c)
                                    (blocked? g nx ny ? (go >l) (pins p 'x nx 'y ny))))
                (go cs))
 (swerve g m) (: d (g 'd) sb (g 'sb)
                 c (roll sb 2 = 0 ? [(m 'dy) (0 - m 'dx)] [(0 - m 'dy) (m 'dx)])
                 (corner? d (m 'x) (m 'y) <c <>c ? (car-head m <c <>c)))
 ; off the map, and in again by a gate: a road's border cell, headed inward
 (car-gone g m) (: gs (g 'gates) sb (g 'sb)
                   (go n) (: e (gs (roll sb #gs))
                             (0 < n && mob-at g <e (e 1) ? (go (n - 1))
                              (pins m 'x <e 'y (e 1), car-head m (e 2) (e 3))))
                   (two? gs ? (go 4) (car-back m)))
 (drive g m) (:- (go car-speed)
   d (g 'd) p (g 'p)
   (go n) (? (0 < n)
             (: nx (m 'x + m 'dx) ny (m 'y + m 'dy)
                (? (nx = p 'x && ny = p 'y) (run-down g m)
                   !(0 <= nx < d 'w && 0 <= ny < d 'h) (car-gone g m)
                   (mob-at g nx ny) ()
                   (road? d nx ny)
                    (: _ (pins m 'x nx 'y ny)
                       _ (? (roll (g 'sb) 4 = 0) (swerve g m))
                       (go (n - 1)))
                   (car-back m)))))

 ; --- her: on the first floors, somewhere, once. bumped, she has her say in a box
 ; over the map and is gone; the box is a sign, so the next key takes it down. ---
 her-glyph "Φ"
 her-pen 219
 her-floors 3
 her-ttl "Orozcalia"
 ; what she says is the floor's: one page each, and the box reflows a long line
 her-book '(("A wizened gnome enjoys the garden."
             "\"Rats tend the hedges underneath the roots.\" She aims a bony claw below."
             "\"Ye'd blanch to ken their deepwrought burrowings.\" "
             "You blink and she's gone."
             "-- any key --")
            ("A wizened gnome leans on a lamppost."
             "\"Ash and metal oxen rule the pathways of this poisoned land.\""
             "\"Even the gnomes of this unhallowed district grew verminous.\""
             "She snatches a squirming-by gnome and slurps it down in one heroic swallow."
             "\"Disgusting.\" Orozcalia sublimates into an oily mephitis and vanishes."
             "-- any key --")
            ("\"My tongue won't shape the sound these poor shapes call this dirtened nowhere.\""
             "Orozcalia signs a cantrip of warding."
             "\"Mere quantities. Hurry on, get on now.\""
             "-- any key --"))
 (her-lines lvl) (peep her-book (lvl - 1) <her-book)
 (her-at? g x y) (: h (g 'her) (h && x = h 'x && y = h 'y))
 (meet-her g) (pins g 'her () 'sign (her-ttl . her-lines (g 'lvl)))
 ; everything the painter draws over the floor: the climber, her, the mobs
 (ents g) (: h (g 'her) (g 'p . (h ? (h . g 'ms) (g 'ms))))

 ; stock a fresh floor: mobs and pennies in every room but the climber's own. the
 ; token is not on any floor -- it is what the circle turns out to have been.
 last-floor 3
 (stock g) (:
   d (g 'd) sb (g 'sb) lvl (g 'lvl) loot {} ks (mob-set lvl)
   (drop-at rm) [(peep rm 0 0 + roll sb (peep rm 2 1)) (peep rm 1 0 + roll sb (peep rm 3 1))]
   (ground? x y) (elem (dat d x y) '(1 4 8))
   (mobs rm n acc) (? (0 < n)
                    (: xy (drop-at rm) x <xy y <>xy
                       (? (ground? x y &&
                           !(loot (x + d 'w * y)) &&
                           !(any ({'x ^x 'y ^y} \ 1) acc))
                        (mobs rm (n - 1) (mob-new (peep ks (roll sb #ks) 0) x y . acc))
                        (mobs rm (n - 1) acc)))
                    acc)
   ; every room has pennies, which are the point of the place. the tile is read through
   ; `dat`: a cask does not answer to being applied, so (d 't i) is () for every cell
   (treasure rm n) (? (0 < n)
                    (: xy (drop-at rm) x <xy y <>xy
                       _ (? (ground? x y)
                            (pin loot (x + (d 'w) * y) ['penny (3 + roll sb 12)]))
                       (treasure rm (n - 1))))
   rms (init (d 'rooms))
   ms (foldl (\ acc rm (treasure rm (2 + roll sb 2), mobs rm (roll sb (2 + lvl)) acc))
             () rms)
   ; a cell in some room with nothing on it yet, or () when the dice will not give one
   (free? x y) (ground? x y && !(loot (x + d 'w * y)) && !(any ({'x ^x 'y ^y} \ 1) ms))
   (spot-in rm n) (? (0 < n) (: xy (drop-at rm)
                                (free? <xy <>xy ? xy (spot-in rm (n - 1)))))
   (spot n) (two? rms ? (spot-in (rms (roll sb #rms)) n) ())
   (furnish-in rm k) (: xy (spot-in rm 40) (xy ? (pin loot (<xy + d 'w * <>xy) [k])))
   (furnish k) (two? rms ? (furnish-in (rms (roll sb #rms)) k) ())
   _ (? (1 = lvl) (furnish 'table, furnish 'throne))
   ; the middle's buildings are lived in: a few pieces each, and one holds the shelf
   pieces '(chair bed crate)
   _ (? (2 = lvl)
        (: _ (each rms (rm \ each ^(1 + roll sb 3) (_ \ furnish-in rm (pieces (roll sb #pieces)))))
           (furnish 'shelf)))
   ; heaven's platforms: fountains, and mirrors on platforms of their own -- one mirror
   ; lets out of another, so there are two at least where there are two platforms
   _ (? (3 = lvl)
        (: _ (each ^(2 + roll sb 2) (_ \ furnish 'fountain))
           (each (first-n (2 + roll sb 2) (deal sb rms)) (rm \ furnish-in rm 'mirror))))
   ; ..and its streets driven: a car for so many cells of street, headed along it
   streets (? (2 = lvl) (filter (i \ street? d (i % d 'w) (i // d 'w)) ^(d 'w * d 'h)) ())
   (car-at i) (: x (i % d 'w) y (i // d 'w)
                 along (road? d x (y - 1) && road? d x (y + 1))
                 sg (roll sb 2 = 0 ? 1 -1)
                 (car-new x y (along ? 0 sg) (along ? sg 0) (car-pens (roll sb #car-pens))))
   cars (two? streets ? (map (_ \ car-at (streets (roll sb #streets))) ^(2 + #streets // 40)) ())
   ; the gates: every road's glass end, and the way in from it
   w (d 'w) h (d 'h)
   (gate i) (: x (i % w) y (i // w)
               (6 = dat d x y ? [x y (? (x = 0) 1 (x = w - 1) -1 0) (? (y = 0) 1 (y = h - 1) -1 0)] ()))
   gates (? (2 = lvl) (filter two? (map gate ^(w * h))) ())
   her (? (lvl <= her-floors) (: xy (spot 40)
                                 (xy ? {'x <xy 'y <>xy 'gl her-glyph 'hue her-pen})))
   (pins g 'ms (cat cars ms) 'loot loot 'her her 'gates gates))

 ; the garden's hedge, worn thin: an inner rock cell with four or more open neighbours
 ; of its eight becomes ground on a roll, over a few passes. every pass reads the floor
 ; it started from, so the wearing has no direction and the border stays hedge.
 wear-passes 2
 wear-share 50
 (wear-thin d sb) (: w (d 'w) h (d 'h)
   (around x y) #(filter (o \ open? d (x + <o) (y + <>o))
                               '((-1 -1) (0 -1) (1 -1) (-1 0) (1 0) (-1 1) (0 1) (1 1)))
   (pass n) (? (0 < n)
               (: cut (filter (i \ (: x (i % w) y (i // w)
                                      (0 < x && x < (w - 1) && 0 < y && y < (h - 1) &&
                                       0 = dat d x y && 4 <= around x y &&
                                       roll sb 100 < wear-share)))
                              ^(w * h))
                  _ (each cut (i \ dput d (i % w) (i // w) 1))
                  (pass (n - 1))))
   (pass wear-passes))

 ; the garden's stream: from the top edge to the bottom, a row a step and now and then
 ; a column's drift, cut through hedge and bed alike -- water is ground you can cross,
 ; so it is also a way through. the stair is never in it.
 (stream d sb) (: w (d 'w) h (d 'h)
                  (go x y) (? (y < h)
                              (: _ (? (2 != dat d x y) (dput d x y 3))
                                 nx (roll sb 2 = 0 ? (x + roll sb 3 - 1) x)
                                 (go (nx < 1 ? 1 (nx > (w - 2) ? (w - 2) nx)) (y + 1))))
                  (go (2 + roll sb (w - 4)) 0))

 ; a floor wears its tier: the make it is built of, and the salt its litter is dealt
 ; from -- one draw, so the same seed strews the same floor
 (dress d lvl sb) (: _ (pins d 'th (peep themes (lvl - 1) th-heaven) 'sd (roll sb 1000000))
                     (1 = lvl ? (: _ (wear-thin d sb)
                                   _ (stream d sb)
                                   ph (roll sb 1000 / 10.0)
                                   ph2 (roll sb 1000 / 10.0)
                                   (pin d 'skin {'hedge (ink-drift (d 'h) (d 'w) ph 0.0)
                                                 'ground (ink-drift (d 'h) (d 'w) ph2 0.0)}))
                          d))

 ; a fresh climb: the garden delved from the seed state, the climber at 'in
 (crawl-new w h st) (:
   p0 (carve-floor w h st 1) d <p0
   st1 >p0 sb {st1}                                 ; the brace boxes; #st1 would count it
   _ (dress d 1 sb)
   pl {'x <(d 'in) 'y <>(d 'in) 'gl 64 'hue 228 'hp 40 'mx 40 'penny 0}
   g {'d d 'lvl 1 'tn 0 'sb sb 'p pl 'msg "" 'over 0}
   _ (stock g)
   _ (note g w-open)
   _ (pin g 'sign (sign-ttl . sign-open))
   (pin g 'vis (fov d (pl 'x) (pl 'y) 8)))

 (note g s) (pin g 'msg (g 'msg ? (g 'msg + "; " + s) s))
 (mob-at g x y) <(filter (m \ x = m 'x && y = m 'y) (g 'ms))
 (blocked? g x y) (!(open? (g 'd) x y) ||
                   (x = g 'p 'x && y = g 'p 'y) ||
                   her-at? g x y ||
                   (: l (g 'loot (x + g 'd 'w * y)) (l && <l != 'penny)) ||
                   mob-at g x y)

 ; the climber's stride: bump a mob to strike it, step onto pennies to take them
 ; the first blow is also an introduction, whoever throws it, and a thing introduces
 ; itself once
 (meet g m) (? (m 'met) ()
              (: _ (pin m 'met 1)
                 s (mutter (roll (g 'sb) 97) (m 'nm))
                 (s ? (note g s))))
 ; ..and what it was carrying, which is pennies and always pennies. a pile already on
 ; the cell takes them up rather than being written over
 (drop g m) (: i (m 'x + g 'd 'w * m 'y)
               it (g 'loot i)
               n ((two? it ? <>it 0) + 1 + roll (g 'sb) (2 + 2 * g 'lvl))
               (pin (g 'loot) i ['penny n]))
 (strike g m) (: _ (meet g m)
                 dm (1 + roll (g 'sb) 3)
                 _ (pin m 'hp (m 'hp - dm))
                 (? (0 < m 'hp) (note g (fill w-strike [(m 'nm) dm]))
                  (pin g 'ms (filter (\ o !(= o m)) (g 'ms)),
                   drop g m,
                   note g (fill w-kill [(m 'nm)]))))
 (take g i it)
  (: d (g 'd)
     _ (pull (g 'loot) i ())
     _ (pin (g 'p) 'penny (g 'p 'penny + <>it))
     _ (note g (fill w-penny [<>it]))
     s (mutter (dice (i % d 'w) (i // d 'w) (2 + peep d 'sd 0) 97) "pennies")
     (s ? (note g s)))

 ; what the ground underfoot has to say for itself -- "" where nothing is strewn. the
 ; line is the cell's, off a second salt, so it does not follow which thing lies there
 (underfoot g x y) (: d (g 'd) sd (peep d 'sd 0) k (dice x y (1 + sd) 97)
                      (? (2 = dat d x y) (mutter k "stair")
                         (3 = dat d x y) (mutter k "stream")
                         (4 = dat d x y) (mutter k "floor")
                         (5 = dat d x y) (mutter k "door")
                         (7 = dat d x y) (mutter k "steps")
                         (8 = dat d x y) (mutter k "platform")
                         (: r (strewn (make d) x y sd)
                            (two? r ? (mutter k (r 4)) ""))))
 (tread g x y) (: s (underfoot g x y) (s ? (note g s)))

 ; a mirror bumped lets you out beside another one, whichever the dice pick; alone on
 ; its floor, or hemmed in, it keeps you where you are
 (mirror g i) (: d (g 'd) w (d 'w) sb (g 'sb)
                 others (filter (j \ j != i && 'mirror = <(g 'loot j)) (keys (g 'loot)))
                 (beside j) (: x (j % w) y (j // w)
                               (filter (o \ !(blocked? g (x + <o) (y + <>o)))
                                       '((-1 -1) (0 -1) (1 -1) (-1 0) (1 0) (-1 1) (0 1) (1 1))))
                 (out j) (: cs (beside j)
                            (two? cs ? (: o (cs (roll sb #cs))
                                          _ (pins (g 'p) 'x (j % w + <o) 'y (j // w + <>o))
                                          (note g w-mirror))
                                       (note g w-alone)))
                 (two? others ? (out (others (roll sb #others))) (note g w-alone)))

 (stride g mv) (: p (g 'p) nx (p 'x + <mv) ny (p 'y + <>mv)
                  m (mob-at g nx ny)
                  i (nx + (g 'd 'w) * ny)
                  it (g 'loot i)
                  (? (her-at? g nx ny) (meet-her g)
                     (m && m 'car) (run-down g m)
                     m (strike g m)
                     (it && <it = 'mirror) (mirror g i)
                     (it && <it != 'penny) (bump-feat g <it)
                     (6 = dat (g 'd) nx ny) (note g w-glass)
                     !(open? (g 'd) nx ny) (note g (fill w-wall [(here g)]))
                     (: _ (pin p 'x nx, pin p 'y ny)
                        _ (it ? (take g i it))
                        (tread g nx ny))))


 ; the floor stirs: a mob that sees you closes in; struck close, it bites
 (sgn n) (? (0 < n) 1 (n < 0) -1 0)
 (bite g m) (: _ (meet g m)
               dm (1 + roll (g 'sb) (m 'dm))
               _ (pin (g 'p) 'hp (g 'p 'hp - dm))
               _ (note g (fill w-bite [(m 'nm) dm]))
               (0 >= g 'p 'hp ? (pin g 'over 'dead, note g w-dead)))
 (shift g m mv) (: nx (m 'x + <mv) ny (m 'y + <>mv)
                 (blocked? g nx ny ? () (pin m 'x nx, pin m 'y ny)))
 (stir g m) (: p (g 'p) dx ((p 'x) - m 'x) dy ((p 'y) - m 'y)
               (? (|dx <= 1 && |dy <= 1) (bite g m)
                  (dx * dx + dy * dy <= 65 &&
                   clear? (g 'd) (m 'x) (m 'y) (p 'x) (p 'y))
                   (: sx (sgn dx) sy (sgn dy)
                      ox (m 'x) oy (m 'y)
                      _ (shift g m [sx sy])
                      (ox = m 'x && oy = m 'y ?
                       (shift g m [sx 0],
                        ox = m 'x && oy = m 'y ? (shift g m [0 sy]))))
                  (roll (g 'sb) 3 < 1)
                   (shift g m [(roll (g 'sb) 3 - 1) (roll (g 'sb) 3 - 1)])))
 ; a mob stirs on the turns its pace divides, so heaven moves at half a climber's rate
 (due? g m) (: q ((g 'tn) % (m 'pc)) (0 = q))

 ; up the stair: a fresh floor restocked, or the circle if heaven is behind you
 (ascend g) (? (last-floor <= g 'lvl) (circle-new g)
              (: p0 (carve-floor (g 'd 'w) (g 'd 'h) (peep (g 'sb) () 0) (1 + g 'lvl))
                 d <p0
                 _ (pin (g 'sb) () >p0)
                 _ (pins g 'd d 'lvl (1 + g 'lvl))
                 _ (dress d (g 'lvl) (g 'sb))
                 _ (pins (g 'p) 'x <(d 'in) 'y <>(d 'in))
                 ; a floor climbed is twenty more of the bar, and the bar filled by it
                 _ (pins (g 'p) 'mx (g 'p 'mx + climb-hp) 'hp (g 'p 'hp + climb-hp))
                 _ (stock g)
                 (note g (fill w-floor [(here g)]))))

 ; --- the circle: the last floor, and not a delve at all. the ring is cells and not
 ; a mob -- it does not strike back, and every hit draws it in one step with the wall
 ; following it down. at the middle it is one square, then a smaller one, then the
 ; field opens and there is only the point.
 circle-r0 8
 ring-pen 231
 disc-pen 244
 wall-glyph 35
 grass-glyph 34
 ; the last field is one frame of the walk's shimmer, held still -- no dice in it, the
 ; grade is the wave. these ramps run pale to deep rather than looping: a still frame
 ; never wraps. span is the band of skin they cover, the four sines seldom leaving +-3.
 ;
 ; which ramp is the ring's doing: the middle takes the grass the climber came up
 ; through, and slop's pink waits past the corner of the board until the ring is down
 ; to half, so the first half of the work is grass and the second is the shore early.
 grass-ramp [194 157 120 114 78 71 34 22]
 pink-ramp [224 218 217 212 211 206 205 199]
 pink-span 3.0
 ; the board's reach from the middle, in the ring's own quarter-unit measure
 (circle-far g) (: d (g 'd) dx ((d 'w) // 2) dy ((d 'h) // 2)
                   ((dx * dx) + (4 * dy * dy)))
 ; how far out the pink front stands, as a share of that reach: past the corner --
 ; which is to say nowhere on the board -- until the ring is half its first size, and
 ; then in to a little under half the board by the time the ring is a point
 pink-start (circle-r0 // 2)
 pink-floor 0.45
 (pink-front g) (: r (circle-r g)
                   (? (pink-start <= r) 1.0
                      (pink-floor + (((1.0 - pink-floor) * r) / pink-start))))
 (ramp-pen rp v) (: m (#rp - 1)
                    n (int (((v + pink-span) * #rp) / (2.0 * pink-span)))
                    (rp (? (n < 0) 0 (m < n) m n)))
 (skin-pen g x y) (: v (peep (g 'sk) [y x] 0.0)
                     f (pink-front g)
                     (ramp-pen ((circle-q g x y) > (f * f * circle-far g)
                                ? pink-ramp grass-ramp)
                               v))

 (circle? g) (last-floor < g 'lvl)
 (circle-new g) (: d (g 'd) cx (d 'w // 2) cy (d 'h // 2)
                   ph (roll (g 'sb) 1000 / 10.0)      ; where in the drift it stopped
                   _ (pins g 'lvl (1 + last-floor) 'cx cx 'cy cy 'st 0 'ms () 'loot {} 'her ()
                            'sk (ink-drift (d 'h) (d 'w) ph 0.0))
                   _ (pins (g 'p) 'x cx 'y (cy - circle-r0 - 1))
                   (note g (fill w-floor [(here g)])))
 (circle-r g) (: st (g 'st) (st < circle-r0 ? (circle-r0 - st) 0))
 ; a cell is about twice as tall as it is wide, so a round ring is an ellipse in cells:
 ; the measure counts a row twice, in quarter units, where radius r stands at (2r)^2.
 (sq n) (n * n)
 (circle-q g x y) (: dx (x - g 'cx) dy (y - g 'cy) ((dx * dx) + (4 * dy * dy)))
 ; a cell is on the ring when its measure falls in the radius's own band -- a circle of
 ; grid squares, not a box, so it stays round at every size it passes through
 (on-ring? g x y) (: r (circle-r g) q (circle-q g x y)
                     (r @ 0 (q = 0)
                      (sq (2 * r - 1) <= q < sq (2 * r + 1))))
 (circle-wall g) (3 + circle-r g)
 (circle-wq g) (sq (2 * circle-wall g))
 disc-q 36                                              ; the grey floor left at the end
 (ring-glyph g) (: st (g 'st)
                   (? (st <= circle-r0) 79 (st = circle-r0 + 1) 111 46))
 (reveal? g) (circle-r0 + 2 <= g 'st)
 (done? g) (circle-r0 + 2 < g 'st)

 ; the wall follows the ring down, so a climber standing where it now stands is carried
 ; in with it -- toward the middle until the floor is under them again
 (circle-push g) (: p (g 'p) wq (circle-wq g)
                    (go x y) (? (circle-q g x y < wq) (pins p 'x x 'y y)
                                (go (x + sgn (g 'cx - x)) (y + sgn (g 'cy - y))))
                    (go (p 'x) (p 'y)))
 (circle-stride g mv)
  (: p (g 'p) nx (p 'x + <mv) ny (p 'y + <>mv)
     d (g 'd) wq (circle-wq g)
     (? (on-ring? g nx ny)
          (: _ (pin g 'st (1 + g 'st))
             _ (done? g ? (pin g 'over 'won) (note g w-ring))
             (g 'over ? () (circle-push g)))
        ; the board's own edge counts as wall too: the room may reach past the view
        (0 <= nx < d 'w && 0 <= ny < d 'h && circle-q g nx ny < wq)
         (pins p 'x nx 'y ny)
        (note g (fill w-wall [(here g)]))))

 ; --- the painter's other face: the circle's room, which has no lantern in it ---
 (circle-frame g) (:
   j (jug 0) d (g 'd) w (d 'w) h (d 'h) p (g 'p)
   rv (reveal? g) wq (circle-wq g)
   _ (say j $ "\e[H\e[0m" + (fit (g 'msg) w) + "\e[K\r\n")
   (cell x y) (: q (circle-q g x y)
                 (? (x = p 'x && y = p 'y) [(p 'gl) (p 'hue)]
                    (on-ring? g x y) [(ring-glyph g) ring-pen]
                    rv (q <= disc-q ? [46 disc-pen] [grass-glyph (skin-pen g x y)])
                    (wq <= q) [wall-glyph (skin-pen g x y)]
                    '(46 240)))
   (row y x pn) (x >= w ? pn
                 (: gh (cell x y) p2 <>gh
                  (pn != p2 ? (say j (pen p2)),
                   say j (string <gh),
                   row y (x + 1) p2)))
   (rows y pn) (y >= h ? pn (rows (y + 1) (: p2 (row y 0 pn) (say j "\r\n", p2))))
   _ (rows 0 -1)
   _ (say j "\e[0m", say j (crawl-bar g), say j "\e[K")
   (slurp j))

 ; one turn: the climber's steer, then every mob its pace is due, then the lantern
 (crawl-turn g k) (:
   _ (pins g 'msg "" 'tn (1 + g 'tn))
   ; a sign standing is what the key buys: it comes down, and the turn is not taken
   sg (g 'sign)
   _ (sg && pin g 'sign ())
   ; ..unless it was a page and the book has another: that one goes up in its place
   _ (? (sg && two? (g 'pages)) (pins g 'sign <(g 'pages) 'pages >(g 'pages)))
   _ (? (sg || g 'over || k = 46) ()
        (circle? g) (two? k ? (circle-stride g k))
        (two? k) (stride g k, mend g)
        (k @ (60 || 32 || 13 || 10) 1 0)
         (: _ (dat (g 'd) (g 'p 'x) (g 'p 'y) @ 2 (ascend g) (note g w-stair))
            (mend g)))
   _ ((sg || (g 'over || circle? g)) ? ()
      (each (g 'ms) (m \ !(g 'over) && due? g m && (m 'car ? (drive g m) (stir g m)))))
   (circle? g ? g (pin g 'vis (fov (g 'd) (g 'p 'x) (g 'p 'y) 8))))

 ; the bar, and on a stair the one thing worth saying there
 (crawl-bar g) (: p (g 'p)
                  up (!(circle? g) && 2 = dat (g 'd) (p 'x) (p 'y))
                  (fill (up ? w-bar-up w-bar)
                        [(here g) (p 'hp) (p 'mx) (p 'penny)]))
 (crawl-frame g) (: f (circle? g ? (circle-frame g)
                      (:- (slurp j) j
                       (paint (jug 0) (g 'd) (g 'vis) (g 'loot)
                        (ents g) (g 'msg) (crawl-bar g))))
                    sg (g 'sign)
                    (two? sg ? (sign-over f <sg >sg 1 (g 'd 'h) (g 'd 'w)) f))

 ; --- the song: a floor's bar, out the card a chunk at a time -----------------------
 ; it stands below the circle because song-vol reads circle-r0, and a value read from
 ; above where it is bound answers () rather than scaring -- a silent song, in silence.
 ; harp and play are cited by name, never borrowed: borrowing harp would put its rev
 ; and every over prel's for everything below.
 ;
 ; the harp of it is one line -- lay the slots across the cycle, sound the bars
 ; together. a slot's tablet is what mkvoice reads, so no control word is wanted.
 (tower-tune lvl c r) (:
   hush (cite 'harp 'hush) pure (cite 'harp 'pure)
   fastcat (cite 'harp 'fastcat) stack (cite 'harp 'stack)
   (bar sl) (fastcat (map (v \ (tablet? v ? (pure v) hush)) sl))
   (stack (map bar (tower-bars lvl c r))))

 ; how loud this floor is. the first three are their own row's; the circle's is the
 ; ring, so the heart goes quiet exactly as the circle closes and is gone at the point.
 (song-vol g) (? (circle? g) (: r (circle-r g) ((r * 1.0) / (circle-r0 * 1.0)))
                  (peep songs ((g 'lvl) - 1) <songs))

 (song-new h) {'h h 'fpos 0 'cyc 0 'next 0 'vs () 'lvl 1 'rad circle-r0
               'voices (cite 'play 'cyc-voices)
               'mix (cite 'play 'mixdown) 'pk (cite 'play 'pack)}
 ; where the game is, read off it each frame. only a bar not yet built reads them, so
 ; a stair or a struck ring lands at the next bar line and never cuts the one sounding.
 (song-tier s g) (pins s 'lvl (g 'lvl) 'rad (circle? g ? (circle-r g) 0), song-sfx s g)
 ; what the game asked to hear this turn, put in at the write head so it sounds in the
 ; next chunk: a horn is two short square beeps, a driver's double tap
 beep-note 8
 beep-gap 0.11
 beep-len 0.07
 (song-sfx s g) (: fx (g 'sfx)
                   mk (cite 'play 'mkvoice)
                   (beep k) (mk (s 'fpos + int (k * beep-gap * song-rate))
                                {'s "sqr" 'note beep-note 'gain 0.8 'legato beep-len} song-rate)
                   vs (foldl (\ acc f (f @ 'horn (cat acc [(beep 0) (beep 1)]) acc)) () fx)
                   _ (pin g 'sfx ())
                   (pin s 'vs (cat (s 'vs) (filter two? vs))))
 ; one chunk out the card. whole cycles are pulled in ahead of the write head and
 ; dropped once their end frame is behind it, so the live list is what is sounding.
 (song-feed s vol) (:
   spc (int (song-rate / song-cps))
   (fill _) (? (s 'next <= s 'fpos + song-chunk)
               (: p (tower-tune (s 'lvl) (s 'cyc) (s 'rad))
                  _ (pin s 'vs (cat (s 'vs)
                                    (s 'voices p (s 'cyc) 0 spc song-rate)))
                  _ (pins s 'cyc (s 'cyc + 1) 'next (s 'next + spc))
                (fill ())))
   _ (fill ())
   base (s 'fpos)
   live (filter (v \ v 0 >= base) (s 'vs))
   _ (pins s 'vs live 'fpos (base + song-chunk))
   (say (s 'h) (s 'pk (s 'mix live base song-chunk) song-chunk (song-gain * vol))))

 ; --- tower: the climb on cli's stage. any seed climbs; q or esc leaves ---
 ; the token is the last thing the tower says, and the field it opens onto is the next
 ; thing on the same screen: the walk takes the stage the climb already raised, so
 ; nothing between the circle and the slop is torn down. slop is cited at the door,
 ; not borrowed, so a seat that carries no walk still climbs.
 (tower-win g) (: tk (tokens (roll (g 'sb) #tokens))
                  _ (pin g 'msg (fill w-won [tk (g 'p 'penny)]))
                  _ (say out (crawl-frame g), flush out, rest 2200)
                  _ (drain-keys ())
                  walk (cite 'slop 'slop-walk)
                  (walk && walk tk (g 'p 'penny)))
 ; the climb keeps its own stage rather than cli's: stage blocks on a key, and a card
 ; with nothing coming out of it is a card that stops. the raising and the putting back
 ; are stage's, line for line; what is different is the wait in the middle.
 (tower-run _) (: ws (tty 1)
             r (two? ws && 7 < <ws ? (<ws - 2) 22)
             c (two? ws && 19 < <>ws ? <>ws 80)
             g (crawl-new (c < 100 ? c 100) r (wheel (clock 0)))
             ; the card, if this seat has one: no harp or no horn and the tower is quiet
             hn (? (tablet? (cite 'harp))
                   (: q (horn song-rate 2) (? (nom? q) () q)) ())
             sng (? hn (song-new hn) ())
             ; the wait IS the song: a chunk goes out at the speed the card plays it, so
             ; a loop that feeds one while no key is waiting keeps time without a rest.
             ; with no card it is a plain poll, and the tower is silent as it was.
             (hold _) (? (cue? 0) ()
                         (: _ (? sng (song-feed sng (song-vol g)) (rest 30))
                            (hold ())))
             (turn k) (k @ (113 || 27 || -7) (pin g 'over 'fled)
                       -12 (crawl-turn g (tap-steer g (edtap ())))
                       (crawl-turn g (steer k)))
             (loop _) (? (g 'over) ()
                         (: _ (say out (crawl-frame g), flush out)
                            _ (hold ())
                            _ (turn (edkey in))
                            _ (? sng (song-tier sng g) ())
                            (loop ())))
             _ (raw 1)
             _ (say out "\e[?1049h\e[?25l\e[2J")
             _ (loop ())
             ; an end shows its frame for a beat before the screen is given back
             _ (say out (crawl-frame g), flush out, rest 1200)
             ; ..and the card goes back before the walk asks for it
             _ (? hn (: _ (flush hn) (close hn)) ())
             _ (g 'over = 'won ? (tower-win g))
             _ (say out "\e[0m\e[?25h\e[?1049l")
             _ (flush out)
             _ (drain-keys ())
             _ (raw 0)
             ; won: the token line is still in the note row, and goes to the shell too
             (g 'over @ 'won (puts $ fit (g 'msg) 200 + "\n", 0)
              (puts $ (g 'over @ 'dead (fill w-lost [(here g)])
                                       (fill w-fled [(g 'p 'penny)])) + "\n",
               g 'p 'penny)))
 tower-usage "usage: love tower   (no options; q or esc leaves the tower)"
 ; tower takes nothing: a word here is a mistake, and the climb would swallow it
 (tower-main as) (one? as ? (tower-run ())
                    (say err (fill w-args [<as]), flush err, 2))
 _ (pins (cite 'verbs 'tab) 'tower (udoor 'tower tower-main tower-usage 1 1)))
) ; module rove
