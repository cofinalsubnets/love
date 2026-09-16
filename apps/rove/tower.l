; tower -- the climb, on quay's roguelike engine (apps/rove/rove.l).
;
; each tier is built of its own stuff and its litter is the cell's own dice, so a floor
; reproduces with its rooms: the garden, the middle and heaven, pennies underfoot and a
; stair above, then the circle. pure state in, pure state out, one key per turn. it is
; not a game about fighting -- a turn spent acting mends the bar and a turn passed does
; not, so a climber dies only by standing still beside something.
;
; a floor's music is a rule and not a recording, built off the cycle number through the
; same dice that strews it, and fed to the card from the climb's own loop.
;
; run: love tower. the climb gates headless in test/host/rove.l; only tower-run ties the
; tty, and test/host/tty.l plays it on a pty.
(module (tower tower-run tower-main tap-key bell-row bell-open bell-key cell-face
         live-cells crawl-new crawl-turn crawl-frame crawl-bar mob-new mob-set stock mend
         ascend circle? vale-new vale-tick walled? on-ring? done? enter exit-at circle-r
         circle-q circle-far ring-in talk talk-key talk-node her-tree open-box doom oct-pt
         tokens floors themes plan tile-face strewn pink-ramp grass-ramp pink-front
         skin-pen flavour mutter underfoot stream feat-book her-floors ents loot-face city
         carve-floor car-new car-head drive run-down corner? road? climb-hp sky her-lines
         mirror lane-at songs tower-bars tower-tune song-vol song-new song-feed song-tier
         song-sfx garden-bars middle-bars sky-bars heart-bars heart-rate tune?)
; posix is optional -- the page's seat (inle/wasm) links none of it and this file runs
; there, so ask before splicing: an absent module is a scare.
(? (cite 'posix) (borrow 'posix) ())
; and ink, which the last floor paints with: the shader the walk runs, stopped
(borrow 'ink)
(borrow 'x11)
(borrow 'rove)
(:
 ; --- the floor: tiles in a cask, (x y) indexed; 0 rock, 1 ground, 2 the stair, 3 water,


 ; --- city: the middle is not delved but laid -- streets on a grid, two cells across
 ; and one along, and the blocks between them buildings: a wall ring with a floor
 ; inside, and two or three doors on different walls, every wall facing a street. the
 ; climber arrives inside the last building; the stairs are inside two others. a
 ; block too small to hold a room stays solid. answers (floor . st') like delve. ---
 street-x 9                                             ; a block's stride across, and along
 street-y 6
 (city w h st) (:
   d {'w w 'h h 't (cask (w * h)) 'seen (cask (w * h)) 'rooms () 'lane {} 'solid '(6)}
   sb {st}
   (mid rm) [(peep rm 0 0 + peep rm 2 1 // 2) (peep rm 1 0 + peep rm 3 1 // 2)]
   ; where the streets start: from a, at the stride and a jitter, the last one at lim
   (spine a lim step jit) (:- (go a [a])
     (go x acc) (: nx (x + step + roll sb jit)
                   (nx + (step // 2) < lim ? (go nx (nx . acc)) (rev (lim . acc)))))
   xs (spine 1 (w - 3) street-x 4)
   ys (spine 1 (h - 3) street-y 2)
   ; every street is two lanes, one each way, and a cell knows its lane: the way
   ; along it, and at a crossing the way along each. driving keeps to the right, so
   ; the west lane runs south and the south lane runs east
   (lane x y dx dy) (: i (x + w * y) l (peep (d 'lane) i '(0 0))
                       (pin (d 'lane) i [(dx = 0 ? <l dx) (dy = 0 ? <>l dy)]))
   _ (each xs (x \ each ^h (y \ (dput d x y 1, lane x y 0 1,
                                  dput d (x + 1) y 1, lane (x + 1) y 0 -1))))
   _ (each ys (y \ each ^w (x \ (dput d x y 1, lane x y -1 0,
                                  dput d x (y + 1) 1, lane x (y + 1) 1 0))))
   ; every road runs off the map: its border cell is glass, driven through and not walked
   (glass x y) (? (1 = dat d x y) (dput d x y 6))
   _ (each xs (x \ (glass x 0, glass (x + 1) 0, glass x (h - 1), glass (x + 1) (h - 1))))
   _ (each ys (y \ (glass 0 y, glass (w - 1) y, glass 0 (y + 1), glass (w - 1) (y + 1))))
   ; a block between four streets: the wall ring is left as rock, the inside is floor
   (build xa xb ya yb) (: x0 (xa + 2) x1 (xb - 1) y0 (ya + 2) y1 (yb - 1)
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



 ; the coloured squares of a platform's checker, one colour to a platform: x11's names,
 ; at the nearest pen the face has, lit and remembered. dealt out, so no two platforms
 ; share one while there are enough to go round.
 plat-hues '(("█" 99 61)                                ; medium slate blue
             ("█" 48 29)                                ; medium spring green
             ("█" 92 54)                                ; dark violet
             ("█" 198 125)                              ; deep pink
             ("█" 170 133)                              ; orchid
             ("█" 168 132))                             ; pale violet red
 (sky w h st) (:
   d {'w w 'h h 't (cask (w * h)) 'seen (cask (w * h)) 'rooms () 'tint {} 'solid '(6)}
   sb {st}
   _ (each ^(w * h) (i \ pin (d 't) i 6))            ; the void this floor is carved out of
   (mid rm) [(peep rm 0 0 + peep rm 2 1 // 2) (peep rm 1 0 + peep rm 3 1 // 2)]
   (rhomb cx cy a b f) (each ^(2 * b + 1) (j \ each ^(2 * a + 1)
                                                (i \ (: x (cx - a + i) y (cy - b + j)
                                                        (|(x - cx) * b + |(y - cy) * a <= a * b ? (f x y))))))
   pal (deal sb plat-hues)
   (plat cx cy a b k) (: c (pal (k % #pal))
                         (rhomb cx cy a b (\ x y (dput d x y 8, pin (d 'tint) (x + w * y) c))))
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
                   plat cx cy a b #(d 'rooms),
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


 ; --- the make of each floor: rock, the ground, what is strewn over it, and the plan
 ; its rooms are cut to -- the only place a tier's look is written. a face is
 ; (glyph lit dim), and a strewing carries a fourth number: cells in a hundred -- and
 ; may carry a sixth, its weight inside a bed, where flowers grow together.
 th-garden '((38 28 22) (46 137 94)                     ; hedge and dirt
             ((42 212 89 1 "aster" 30) (42 220 136 1 "goldenrod" 30)
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
 (plat-face x y lit c) (wear ((x + y) % 2 = 0 ? plat-grey c) lit)





 ; the garden's greens are not one green, nor its browns one brown: the hedge wears a
 ; still frame of the walk's shimmer -- the circle's field -- and the ground another,
 ; out of phase, so a bed is one shade here and another there in bands, not the mottle
 ; dice would give. the ramps run pale to deep, keyed by the pen the theme gave the
 ; cell; only the lantern's light shows a grade, memory is flat.
 hedge-ramp [70 34 34 28 28 22 22 22]
 lawn-ramp [118 112 76 70 40 34 28 22]
 dirt-ramp [180 137 137 136 94 94 95 58]



 ; ..and the middle's stone the same way, walls and flags each on a band of greys. one
 ; frame serves a whole floor: hedge and lawn, or wall and flag, read off the same
 ; wave, so the bands run through both and nothing is mottled
 stone-ramp [252 250 248 247 246 245 244 243]
 flag-ramp [250 249 248 247 246 245 244 243]
 skin-kinds {28 'hedge 137 'dirt 34 'lawn 71 'lawn 246 'stone 245 'flag}





 ; the vale's last field is one frame of the walk's shimmer too, held still, and as the
 ; ring closes the grass past a front goes over to slop's pink. these ramps run pale to
 ; deep rather than looping: a still frame never wraps. span is the band of skin they
 ; cover, the four sines seldom leaving +-3; the front waits beyond the corner of the
 ; board until the ring is half its scale, then comes in to under half the board.
 circle-r0 8                                            ; the ring's scale, for the song and the pink
 grass-ramp [194 157 120 114 78 71 34 22]
 pink-ramp [224 218 217 212 211 206 205 199]
 pink-span 3.0
 pink-start (circle-r0 // 2)
 pink-floor 0.45



 ; the vale: trees for rock, and grass for ground -- no flowers, a tuft here and
 ; there, all of it one green the still shimmer grades; and the house: timber for
 ; rock, boards for ground
 th-vale '(("♣" 28 22) (46 34 22)
           ((44 34 22 12 "tuft") (34 34 22 8 "grass"))
           (4 7 2 4 14))
 th-house '(("#" 130 94) (46 137 94) ((44 137 94 10 "boards")) (4 7 2 4 14))
 road-pens [94 130 137]                                 ; the road's dirt, three shades
 spot-face '(34 120 114)                                ; the eighth stone's place, grass a shade lighter
 timber-face '("#" 130 94)                              ; the cottage's walls from outside
 down-face '(62 220 136)                                ; > a stair down, gold like the other
 garden-bed '((42 212 89 30 "aster") (42 220 136 30 "goldenrod") (44 71 65 25 "tuft") (34 34 22 15 "grass"))
 fire-pens '(208 196 220)                               ; the fire, count to count



 ; ..and what else moves while the climber stands still. the loop keeps a quarter-second
 ; count on the floor, d 'ft, and these are picked by it: water runs a row a count, the
 ; coals breathe on a phase of their own, a star now and then flares or fades
 water-flow '(45 39 38)
 ember-pens {'brazier '(88 124 52 88) 'hearth '(196 160 202 196)}
 star-bright 231
 star-dim 240
 (plan lvl) (peep themes (lvl - 1) th-heaven 3)
 stair-face '(60 220 136)                               ; < the stair, gold on every floor
 water-face '(126 39 24)                                ; ~ the stream, where it shows
 floor-face '(46 240 236)                               ; . a building's floor, dark
 door-face '(43 137 94)                                 ; + a door, brown





 ; what lies on a cell besides pennies: furniture, which stands there to be bumped and
 ; says one thing. glyph, pen lit, pen dim, the line. a glyph here is a string, so
 ; the page's own letters serve (quay folds them onto its face).
 ; ..and a fifth thing where there is one: a book the piece opens, its title then its
 ; pages, a stanza to a page
 feat-book {'table ["π" 240 236 "a rough stone table stained on top with dark liquid"]
            'throne ["H" 130 94 "a tree stump carved into an ornate throne sits empty"]
            'chair ["h" 137 94 "an office chair, the wheels gummed up"]
            'bed ["=" 131 95 "a bed, made and cold"]
            'crate ["x" 136 94 "an empty cardboard delivery box"]
            'fountain ["☼" 226 136 "galaxies whirl in the dazzling spray of this fountain"]
            'fire ["w" 208 130 "a fire burned low and red at the coals"]
            'lamp ["¡" 226 178 "the wall-mounted lamp emits a buzzing sodium glow"]
            'brazier ["▒" 88 52 "a brazier, the coals have been cooling for a while"]
            'hearth ["▓" 196 88 "a hearth, and the embers in it are still bright"]
            'box ["■" 137 94 "a simple wooden box"]
            'pot ["u" 180 137 "a clay pot, with brown crust dried at the bottom"]
            'bronze ["o" 178 136 "a bronze bowl, going green at the rim"]
            'iron ["/" 245 240 "an iron poker for the fire, smells like rust"]
            'cloth ["~" 175 133 "a large colored cloth square carefully folded"]
            'mirror ["@" 93 54 "a mirror, but you look back from somewhere else"]
            'sign ["¶" 137 94 "a hand-painted wooden sign, lettering illegible"]
            'bells ["≡" 180 137 "a heavily thumbed technical manual gathers dust on the top shelf"]
            'shelf ["≡" 180 137 "one book lies half buried in a pile of water-damaged magazines"
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
 (feat-face k) (take 3 $ feat-of k)
 (feat-line k) (feat-of k 3)
 (feat-lines k) (peep (feat-of k) 4 ())



 (bump-feat g k) (: bk (feat-lines k)
                    _ (note g (feat-line k))
                    (? (k = 'bells) (bell-open g)
                       (two? bk) (open-book g bk)
                       0))




 ; the cottage's book: OEIS A000110, the Bell numbers, a page a number and no last page --
 ; the next row of the Bell triangle is made as the page is turned, and B(n) heads it.
 ; a page offers the next or the shelf; when a number would not fit the box a bookmark
 ; falls out instead, and the book ends
 bell-ttl "OEIS A000110"
 bell-foot "-- page ~: 1, 2 --"
 bell-choices '((1 "turn the page") (2 "put it back"))
 mark-ttl "a bookmark"
 mark-lines '("a paper scrap slips out from in between the pages."
              "neat handwriting spells the message:"
              ""
              "it's important for you to start doing what you want as soon as you can"
              ""
              "-- any key --")
 (bell-row r) (: (go a l acc) (one? l ? (rev acc) (go (a + <l) >l ((a + <l) . acc)))
                 (go (last r) r [(last r)]))
 (bell-page g n r) (: line ("B(" + show n + ") = " + show <r)
                      cols (peep (g 'd) 'cols (g 'd 'w))
                      (? (cols - 10 < #line) (pins g 'bell () 'sign (mark-ttl . mark-lines))
                       (pins g 'bell [n r] 'sign
                        (bell-ttl . ["" line ""] + map choice-line bell-choices
                                                 + ["" (fill bell-foot [(n + 1)])]))))
 (bell-open g) (bell-page g 0 [1])

 ; the key on a page: 1 turns it, 2 puts the book back, and anything else shows it again
 (bell-key g k) (: b (g 'bell)
                   (k @ 49 (bell-page g (<b + 1) (bell-row (b 1)))
                        50 (pin g 'bell ())
                        (bell-page g <b (b 1))))

 ; a pile of pennies is bright and only under the lantern; furniture is remembered
 (loot-face it lit) (<it @ 'penny '(36 172)
                          'stone [(string (48 + <>it)) (lit ? 252 245)]
                          (wear (feat-face <it) lit))


 ; a cell's face: the stair, the rock, or the ground with whatever it was strewn with
 (make d) (peep d 'th th-middle)                        ; a floor nobody dressed is stone
 (wear r lit) [<r (lit ? (r 1) (r 2))]

 ; a bed is a block of cells that throws one die together, so what clusters, clusters
 bed-w 5
 bed-h 3
 bed-share 30
 (bed? x y s) (dice (x // bed-w) (y // bed-h) (s + 7) 100 < bed-share)
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
       8 (plat-face x y lit plat-blue)
       9 (: k (dice x y (s + 9) 3) [46 (road-pens k)])
       10 (wear spot-face lit)
       11 (wear timber-face lit)
       12 (: r (strew garden-bed x y (s + 5) 1) (wear (two? r ? r (th 1)) lit))
       13 (wear down-face lit)
       0 (wear <th lit)
         (: r (strewn th x y s) (wear (two? r ? r (th 1)) lit)))



 ; the face of one cell: an ent on a lit cell, else what the floor lays over it, else
 ; loot, else the tile -- lit bright, remembered dim, the dark bare. one closure a frame,
 ; the live painter's too, so a cell is the same in both
 (cell-face d vis loot ents) (:
   w (d 'w) sn (d 'seen)
   th (make d) sd (peep d 'sd 0)
   skin (d 'skin)
   ft (peep d 'ft 0)
   ; the scrutinee in its own parens: an infix ? left bare would take the @- as its arm
   ; ..and on the vale the grass past the pink front takes slop's ramp instead. the
   ; front is () until there is pink anywhere, so the walk never pays for this
   fr (peep d 'front ()) fc (peep d 'fire '(0 0)) fcx <fc fcy <>fc
   (pinkish? x y) (fr && (: dx (x - fcx) dy (y - fcy) (fr < dx * dx + 4 * dy * dy)))
   (shade gh x y) ((tablet? skin ? (skin-kinds <>gh)) @- gh
                   'hedge [<gh (ramp-pen hedge-ramp (peep (skin 'ground) [y x] 0.0))]
                   'lawn [<gh (ramp-pen (pinkish? x y ? pink-ramp lawn-ramp) (peep (skin 'ground) [y x] 0.0))]
                   'dirt [<gh (ramp-pen dirt-ramp (peep (skin 'ground) [y x] 0.0))]
                   'stone [<gh (ramp-pen stone-ramp (peep (skin 'ground) [y x] 0.0))]
                   'flag [<gh (ramp-pen flag-ramp (peep (skin 'ground) [y x] 0.0))])
   ; a lit cell that moves: the count's pen, or a star's dice
   (fmod a m) (: r (a % m) (r < 0 ? (r + m) r))
   (flow gh y) [<gh (water-flow (fmod (y - ft) 3))]
   (ember k gl x y) [gl ((ember-pens k) ((ft // 2 + dice x y sd 4) % 4))]
   (twinkle gh x y) (dice x y (sd + ft) 9 @ 0 [<gh star-bright] 1 [<gh star-dim] gh)
   tint (peep d 'tint ())                             ; heaven's, a colour to a platform
   ov (peep d 'over ())                               ; the vale's: a face laid over a lit cell, or ()
   ; a floor lit end to end says so, and no table of every cell is asked per cell
   lit-all? (peep d 'lit 0)
   spot (foldl (\ t e (pin t (e 'x + w * e 'y) e)) {} ents)
   (\ i (: lit (lit-all? || peep vis i 0)
           e (lit ? (spot i))
           o (lit && ov ? (ov (i % w) (i // w)))
           l (loot i)
           it (l && (lit || <l != 'penny && peep sn i 0) ? l ())
           (? e [(e 'gl) (e 'hue)]
              o o
              it (: k <it gh (loot-face it lit)
                    (? !lit gh
                       (k = 'fire) ["w" (fire-pens (ft % 3))]
                       (ember-pens k) (ember k <gh (i % w) (i // w))
                       gh))
              (peep sn i 0)
               (: t (peep (d 't) i 0) x (i % w) y (i // w)
                  gh (t = 8 && tablet? tint ? (plat-face x y lit (peep tint i plat-blue))
                                              (tile-face th t lit x y sd))
                  (? !lit gh
                     (t = 3) (flow gh y)
                     (t = 6 && <gh != <(th 1)) (twinkle gh x y)
                     (shade gh x y)))
              '(32 0)))))


 ; the cells a floor keeps moving, found once and kept on it: water, a star, the fire
 ; and the coals
 (live-cells d loot) (: l (peep d 'live 0)
   (l @- l 0 (: w (d 'w) th (make d) sd (peep d 'sd 0)
              (live? i) (: t (peep (d 't) i 0) k (loot i) x (i % w) y (i // w)
                           (t = 3 || t = 6 && <(tile-face th 6 1 x y sd) != <(th 1)
                                  || k && (<k = 'fire || ember-pens <k)))
              ls (filter live? ^(w * d 'h))
              (pin d 'live ls, ls))))



 ; ..and a tap on a page with choices -- hers, or the book's -- is the choice it lands
 ; on: the digit that picks it, or 0, which shows the page again. any other tap steers.
 (tap-key g c) (: sg (g 'sign) d (g 'd)
                  (? (sg && (g 'talk || g 'bell))
                     (: j (sign-line <sg >sg 1 (peep d 'rows (d 'h)) (peep d 'cols (d 'w)) <>c)
                        l (0 <= j ? (>sg j) "")
                        (2 < #l && l 0 = 1 ? (l 2) 0))  ; a choice's line opens on 1, its digit next
                     (tap-steer g c)))



 ; --- the words: every line the climb says. a ~ takes the next value and {braces} are
 ; the token's pen; nothing below is built, so this block is the whole of the text.
 w-open   "finally, the tower, at last. get the {token}"
 w-floor  "you climb the stairs to ~. get the {token}"
 w-strike "you strike the ~ (~)"
 w-kill   "the ~ is done for"
 w-bite   "the ~ bites you (~)"
 w-dead   "you are done for"
 w-car    "a car takes you off your feet (~)"
 w-run    "a car runs the ~ down (~)"
 w-wall   "~ holds"
 w-glass  "nothing is there, and it holds"
 w-mirror "the mirror takes you, and lets you out of another"
 w-alone  "the mirror shows you yourself, and keeps you"
 w-stair  "no stair here"
 w-penny  "you pocket ~ pennies"
 w-ring   "you strike the circle, and it puts you back"
 w-circle "and there it is, at the edge of everything: the circle"
 w-empty  "the box, and nothing in it now"
 w-stone  "a standing stone carved deeply with the numeral ~"
 w-shut   "the door will not open now"
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
 sign-open '("at last, you found the tower.  doesn't look much like a tower.  you knew not to take the name too literally, though."
             ""
             "move     h j k l    or the arrow keys"
             "         y u b n    for diagonals"
             "climb    space      while you stand on a stair"
             "leave    q          or esc"
             ""
             "the stairs are a yellow <.  walk onto it and press space to go up."
             ""
             "within the tower lies the fabled {token}, whose boon is said to pass all understanding."
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
 tokens '("the bitten phone" "the gnawed pencil" "the faded manuscript"
          "the tinebent fork" "the handwritten book" "the flipped-out coin"
          "the two-ended candle" "the toothless key" "the manyfolded map"
          "the carbonized lamp" "the greasy spectacles" "the seasoned kettle"
          "the murmuring wristwatch" "the lowlife battery" "the treasured index card")





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
                  (v i) (vox (i % 2 ? "sqr" "tri")
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
 (heart-rate r) (1 + r // 3)
 (heart-bars r) (: n (heart-rate r)
                   (beat lub dub i) (i % heart-div @ 0 lub 2 dub)
                   ix ^(heart-div * n)
                   [(map (beat heart-lub heart-dub) ix)
                    (map (beat knock-lub knock-dub) ix)])



 ; the floor's bars: which cycle it is, and how wide the ring is if it is the ring's
 ; ..the vale's is the garden's chimes until the ring is there, and then the heart
 (tower-bars lvl c r) (lvl @ 1 (garden-bars c) 2 (middle-bars c) 3 (sky-bars c)
                               (r < 0 ? (garden-bars c) (heart-bars r)))



 ; every sample is a closure call, so the wasm seat -- slower, and its page resamples
 ; any rate -- plays at a third of the 48k every card takes
 song-rate (love-arch @ 'wasm 16000 48000)
 song-cps 0.5                                           ; cycles a second
 song-chunk (song-rate // 30)                           ; a frame's worth, thirty a second
 song-gain 5200.0




 ; --- the flavour: a row is a strewing's or a mob's name, then its lines. which line
 ; is the cell's own dice, so one tuft always says the same thing and its neighbour
 ; says another. a name with no row here is silent.
 flavour
 '(("tuft"       "the grass here has gone to seed"
                 "a rat chews the legs of a fat lanternfly"
                 "lanternflies swarm the moldering carcass of a rat")
   ("grass"      "the brush tips of the grass tickle below your knees"
                 "seed clusters cling tenaciously to your legs"
                 "the low grass canopy smells of earthen mildew")
   ("aster"      "an aster, pink and past its best"
                 "the petals are going brown at the edge"
                 "it tries to face the light it remembers")
   ("goldenrod"  "it stands out from the grass like a vein of yellow ore"
                 "you've heard it causes allergies"
                 "the air is thick with pollen")
   ("stream"     "the calm sound of the stream runs silver quick above the stones"
                 "to the minnows in the stream your passing is like a fast moving rock"
                 "you feel like you've stepped in this stream before")
   ("floor"      "filth adheres to sticky gnomish slime trails on the floor and walls"
                 "the floorboards give a little, as if remembering wind"
                 "dim light spins through the motes kicked up by your passage")
   ("door"       "a door, broken-hinged and swinging from its frame"
                 "a low-set doggy door so gnomes can come and go as they please"
                 "you turn sideways to get through")
   ("platform"   "you wonder what happens if you step on the wrong color square"
                 "you try and keep your eyes on the platform"
                 "you feel like a pawn in a game")
   ("steps"      "the stairs between the levels baffle your sense of geometry"
                 "you're sure the plot won't let you fall, better not tempt fate though"
                 "the stairways arcing through the void look almost procedurally generated")
   ("runnel"     "a quick thread of water leaves lightly as it came"
                 "cooler than the air, deeper than it looks"
                 "light shimmers on the submerged roots of the hedges")
   ("rubble"     "stone that used to be somewhere higher"
                 "it turns underfoot"
                 "someone swept it into this corner")
   ("gravel"     "gravel crunches underfoot"
                 "you recall a poem about a pebble"
                 "small stones, worn round")
   ("bones"      "the cars have crushed these bones past hope of recognition"
                 "apparently even gnomes have bones"
                 "rats from the level below consumed this misfortunate denizen")
   ("quartz"     "a seam of quartz retains a fraction of your light"
                 "it channels light, making it warmer than the stone around it"
                 "a quartz deposit brightens the wall here for a step")
   ("cobbles"    "cobbles, laid long ago to harden muddy earth"
                 "worn hollow to the ancient seams"
                 "the joints are packed with pale composite")
   ("lamp"       "a lamp, lit by no one present"
                 "the luminosity varies circularly with time"
                 "it's bright so logically it also feels warm")
   ("bench"      "a bench, facing the wall"
                 "a bench, with spikes, so no one sits"
                 "goblins carved their stolen names into it")
   ("fountain"   "the playing fountain charms a constant shape from water's natural flow"
                 "you wonder where the water pressure comes from"
                 "the pennies at the bottom have hardened to a mineral crust")
   ("star"       "a wandering star levitates at ankle height"
                 "is it hot? you dare not touch"
                 "you thought the stars were merely far away, but some it seems are truly small")
   ("stair"      "a stair to the next level. watch your step"
                 "the steps are worn hollow in the middle"
                 "the chill on the steps defies narration")
   ("pennies"    "copper stamped by time with verdigris"
                 "how many others counted these pennies before?"
                 "the pennies are not the number of pennies"
                 "pennies still warm from another thumb's eager tallying")
   ("rat"        "a plump rat, it looks healthy and happy"
                 "a dirty rat, its paws leave little black prints"
                 "a feral rat, licking open wounds"
                 "it meets your eye and does not hurry")
   ("lanternfly" "a lanternfly, brown black red and white"
                 "they're said to be invasive, but they seem quite at home here now"
                 "it lands on you as though you were furniture")
   ("gnome"      "the gnomes of this land have grown verminous"
                 "a worm the length of your arm, you feel bad for it"
                 "even a gnome will turn, or so the saying goes")
   ("goblin"     "a goblin wearing someone's stolen work uniform"
                 "it's working really hard at its job and it wants you to know that")
   ("hobgoblin"  "it's like a goblin but more of a team player"
                 "earned every ounce of its success")
   ("d4"         "a d4, a hedged bet"
                 "does it like being least?"
                 "four tetrahedral tips gleam menacingly")
   ("d6"         "a d6, a square deal"
                 "the pips are worn smooth on the six")
   ("d8"         "a d8, somehow still six yet more"
                 "it has settled on nothing")
   ("d12"        "a d12, with more faces than meanings"
                 "it rolled so far to get here")
   ("d20"        "a d20, waiting for a natural"
                 "it waits for its number to come up")
   ("triangle"   "a triangle"
                 "its three angles always add up to 180 degrees"
                 "this triangle has one eye")
   ("square"     "a square"
                 "the square looks to be in its element here")
   ("hexagon"    "a hexagon"
                 "the hexagon has seven eyes"))


 ; a name's lines, and the one it says this time
 (lines-of nm)
  (:- (go flavour) (go l)
   (two? l ? (: r <l (nm = <r ? >r (go >l)))))
 (mutter k nm)
  (lines-of nm @ ls (two? ls ? (peep ls (k % #ls) "") ""))


 ; --- the climb: the proving game. state in a tablet, one key per turn ---
 ; the bar is not a resource: a turn spent acting mends and a turn passed does not.
 ; forty against a worst bite of three means one mob is a nuisance and two are a death.
 regen 2
 climb-hp 20
 (mend g) (: p (g 'p) h (p 'hp + regen) (pin p 'hp (h < p 'mx ? h (p 'mx))))
 (mob-row k) (peep mob-book k <mob-book)
 (mob-name k) <(mob-row k)
 (mob-new k x y) (mob-row k @ r
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
 (road? d x y) (dat d x y @ (1 || 6) 1 0)


 ; a corner is a cell whose lane runs the way of the turn: only a crossing has a lane
 ; across, and a turn into the oncoming lane is no corner either
 (lane-at d x y) (peep (peep d 'lane {}) (x + d 'w * y) '(0 0))
 (corner? d x y dx dy) (: l (lane-at d x y) (dx != 0 ? (<l = dx) (<>l = dy)))

 ; the horn, twice, and the hurt: what a car does when it reaches you either way
 (run-down g m) (: p (g 'p)
                   _ (pin p 'hp (p 'hp - car-dm))
                   _ (note g (fill w-car [car-dm]))
                   _ (pin g 'sfx ('horn . g 'sfx))
                   _ (shove g m p)
                   (0 >= p 'hp ? (pin g 'over 'dead, note g w-dead)))

 ; ..and the same for anyone else in the street: the middle keeps nobody. what it was
 ; carrying goes into the road where it falls, for whoever is still standing
 (run-over g m o) (: _ (pin o 'hp (o 'hp - car-dm))
                     _ (note g (fill w-run [(o 'nm) car-dm]))
                     _ (pin g 'sfx ('horn . g 'sfx))
                     _ (shove g m o)
                     (0 >= o 'hp ? (pin g 'ms (filter (!= o) (g 'ms)),
                                    drop g o,
                                    note g (fill w-kill [(o 'nm)]))))

 ; ..and the step aside: to either side of the car's line, where a cell is free
 (shove g m o) (: sb (g 'sb)
                  cs (roll sb 2 = 0 ? [[(m 'dy) (0 - m 'dx)] [(0 - m 'dy) (m 'dx)]]
                                      [[(0 - m 'dy) (m 'dx)] [(m 'dy) (0 - m 'dx)]])
                  (go l) (two? l ? (: c <l nx (o 'x + <c) ny (o 'y + <>c)
                                      (blocked? g nx ny ? (go >l) (pins o 'x nx 'y ny))))
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
                o (mob-at g nx ny)
                (? (nx = p 'x && ny = p 'y) (run-down g m)
                   !(0 <= nx < d 'w && 0 <= ny < d 'h) (car-gone g m)
                   (o && o 'car) ()                    ; a car gives way to a car alone
                   o (run-over g m o)
                   (road? d nx ny)
                    (: _ (pins m 'x nx 'y ny)
                       _ (roll (g 'sb) 4 @ 0 (swerve g m))
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
             "When you blink she's gone."
             "-- any key --")
            ("A wizened gnome leans on a lamppost."
             "\"Ash and metal oxen rule the pathways of this poisoned land.\""
             "\"Even the gnomes of this unhallowed district grew verminous.\""
             "She snatches a bysquirming gnome and slurps it down in one heroic gulp."
             "\"Disgusting.\" Orozcalia sublimates into an oily mephitis and vanishes."
             "-- any key --")
            ("\"This tongue won't form the sound these poor shapes call their dirtened nowhere.\""
             "Orozcalia spits and signs a cantrip of warding."
             "\"Mere quantities. Hurry and get on now.\""
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
   (mobs rm n acc) (0 >= n ? acc
                    (: xy (drop-at rm) x <xy y <>xy
                       (? (ground? x y &&
                           !(loot (x + d 'w * y)) &&
                           !(any ({'x ^x 'y ^y} \ 1) acc))
                        (mobs rm (n - 1) (mob-new (peep ks (roll sb #ks) 0) x y . acc))
                        (mobs rm (n - 1) acc))))
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
   (furnish k) (two? rms && furnish-in (rms (roll sb #rms)) k)
   _ (lvl @ 1 (furnish 'table, furnish 'throne))
   ; the middle's buildings are lived in: a few pieces each, and one holds the shelf
   pieces '(chair bed crate)
   _ (lvl @ 2
      (each rms (rm \ each ^(roll sb 2) (_ \ furnish-in rm (pieces (roll sb #pieces)))),
       furnish 'shelf))
   ; ..and lit: a brazier in every other building, the one red thing there and dim, and a
   ; sodium lamp on one wall of each, facing its street -- on the wall ring, where nobody
   ; walks and every car passes under
   (lamp-on rm) (: x0 (peep rm 0 0 - 1) y0 (peep rm 1 0 - 1)
                   x1 (x0 + peep rm 2 1 + 1) y1 (y0 + peep rm 3 1 + 1)
                   c (roll sb 4 @ 0 [(x0 + 1 + roll sb (x1 - x0 - 1)) y0]
                                  1 [(x0 + 1 + roll sb (x1 - x0 - 1)) y1]
                                  2 [x0 (y0 + 1 + roll sb (y1 - y0 - 1))]
                                    [x1 (y0 + 1 + roll sb (y1 - y0 - 1))])
                   (0 = dat d <c <>c ? (pin loot (<c + d 'w * <>c) '(lamp))))
   _ (lvl @ 2 (each rms (rm \ (lamp-on rm, roll sb 2 @ 0 (furnish-in rm 'brazier)))))
   ; heaven's platforms: fountains, and mirrors on platforms of their own -- one mirror
   ; lets out of another, so there are two at least where there are two platforms.
   ; heaven's furniture is walked round, never through: only where the ring about it is
   ; all walked and bare, so a stairway's mouth or a rim is never the one way past it
   (ringed? x y) (all (o \ (: nx (x + <o) ny (y + <>o) l (loot (nx + d 'w * ny))
                             (open? d nx ny && !(l && <l != 'penny))))
                      '((-1 -1) (0 -1) (1 -1) (-1 0) (1 0) (-1 1) (0 1) (1 1)))
   (furnish-ringed rm k n) (0 < n ? (: xy (spot-in rm 40)
                                     (xy && ringed? <xy <>xy ? (pin loot (<xy + d 'w * <>xy) [k])
                                      (furnish-ringed rm k (n - 1)))))
   ; mirrors first, each on a platform of its own; one too small to ring a mirror hands
   ; it on to the next, so there are two at least wherever two platforms can hold them
   (mirrors ps n) (? (0 < n && two? ps) (mirrors >ps (n - (furnish-ringed <ps 'mirror 40 ? 1 0))))
   _ (lvl @ 3
      (mirrors (deal sb rms) (2 + roll sb 2),
       each ^(2 + roll sb 2) (_ \ two? rms && furnish-ringed (rms (roll sb #rms)) 'fountain 40)))
   ; ..and its streets driven: a car for so many cells of street, headed along it. a
   ; middle delved for want of room has no lanes, and no traffic
   pi (g 'p 'x + d 'w * g 'p 'y)
   streets (2 = lvl && tablet? (d 'lane) ?
            (filter (i \ i != pi && street? d (i % d 'w) (i // d 'w)) ^(d 'w * d 'h)))
   ; ..each headed the way its lane runs, either way at a crossing
   (car-at i) (: x (i % d 'w) y (i // d 'w) l (lane-at d x y)
                 hd (<l != 0 && (<>l = 0 || roll sb 2 = 0) ? [<l 0] [0 <>l])
                 (car-new x y <hd <>hd (car-pens (roll sb #car-pens))))
   cars (two? streets ? (map (_ \ car-at (streets (roll sb #streets))) ^(2 + #streets // 40)))
   ; the gates: a road's glass end whose lane runs in, and that way
   w (d 'w) h (d 'h)
   (gate i) (: x (i % w) y (i // w) l (lane-at d x y)
               ix (? (x = 0) 1 (x = w - 1) -1 0) iy (? (y = 0) 1 (y = h - 1) -1 0)
               (6 = dat d x y && (ix != 0 && <l = ix || iy != 0 && <>l = iy) ? [x y <l <>l]))
   gates (lvl @ 2 (filter two? (map gate ^(w * h))))
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
                                      (0 < x && x < w - 1 && 0 < y && y < h - 1 &&
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
                              (: _ (2 != dat d x y && dput d x y 3)
                                 nx (roll sb 2 = 0 ? (x + roll sb 3 - 1) x)
                                 (go (nx < 1 ? 1 (nx > (w - 2) ? (w - 2) nx)) (y + 1))))
                  (go (2 + roll sb (w - 4)) 0))



 ; a floor wears its tier: the make it is built of, and the salt its litter is dealt
 ; from -- one draw, so the same seed strews the same floor
 (dress d lvl sb) (: _ (pins d 'th (peep themes (lvl - 1) th-heaven) 'sd (roll sb 1000000))
                     ; the garden and the middle each wear one still frame of the shimmer
                     (skin _) (pin d 'skin {'ground (ink-drift (d 'h) (d 'w) (roll sb 1000 / 10.0) 0.0)})
                     (lvl @- d 1 (wear-thin d sb, stream d sb, skin ())
                               2 (skin ())))


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
 (blocked? g x y) (!(open? (g 'd) x y) ||
                   walled? g x y ||
                   (x = g 'p 'x && y = g 'p 'y) ||
                   her-at? g x y ||
                   (: l (g 'loot (x + g 'd 'w * y)) (l && <l != 'penny)) ||
                   mob-at g x y)




 ; the climber's stride: bump a mob to strike it, step onto pennies to take them
 ; the first blow is also an introduction, whoever throws it, and a thing introduces
 ; itself once
 (meet g m) (m 'met ? ()
             (: _ (pin m 'met 1)
                s (mutter (roll (g 'sb) 97) (m 'nm))
              (s && note g s)))


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
                  (pin g 'ms (filter (!= m) (g 'ms)),
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
                    (mutter k $ dat d x y @ 2 "stair" 3 "stream" 4 "floor"
                                            5 "door" 7 "steps" 8 "platform"
                                            (strewn (make d) x y sd @ r (two? r ? (r 4)))))
 (tread g x y) (underfoot g x y @ s (s && note g s))



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
                  ex (exit-at g nx ny)
                  (? (her-at? g nx ny) (circle? g ? (meet-her-vale g) (meet-her g))
                     (m && m 'car) (run-down g m)
                     m (strike g m)
                     (walled? g nx ny) (g 'phase @ 'ring (ring-bump g) (note g w-glass))
                     (<it = 'mirror) (mirror g i)
                     (<it = 'stone) (note g (fill w-stone [<>it]))
                     (<it = 'box) (open-box g)
                     (it && <it != 'penny) (bump-feat g <it)
                     (6 = dat (g 'd) nx ny) (note g w-glass)
                     !(open? (g 'd) nx ny) (note g (fill w-wall [(here g)]))
                     ; a door into another scene, shut once the closing has begun
                     (ex && g 'doom && 'house = <ex) (note g w-shut)
                     ex (enter g <ex (ex 1) (ex 2))
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
                 (blocked? g nx ny ? () (pins m 'x nx 'y ny)))
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



 ; up the stair: a fresh floor restocked, or the circle if heaven is behind you
 (ascend g) (? (last-floor <= g 'lvl) (vale-new g)
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


 ; --- the vale: the last floor, and not a delve at all. a road up through the trees
 ; to a clearing; in it an octagon of stones round a fire with her beside it, and past
 ; it a cottage with the token in its attic. the floor is three screens tall and the
 ; painter shows the rows about the climber; it is lit end to end, and nothing on it
 ; bites. once the token is out of the house the vale closes: walls nobody sees draw
 ; in on the fire, then the ring is there at the screen's edge and draws in too, and
 ; the ring is the end. all of it is measured from the fire, the way the ring always
 ; was: a cell is about twice as tall as it is wide, so the measure counts a row
 ; twice, in quarter units, where radius r stands at (2r)^2.
 ring-glyph "█"                                       ; a solid block, as the slop's water is
 oct-x 9                                                ; the octagon's reach, across and down
 oct-y 4
 close-step 2                                           ; rows the walls draw in a turn
 knock 2                                                ; cells a strike on the ring costs you
 house-w 19
 house-h 9
 attic-w 11
 attic-h 5



 ; what she says by the fire is a tree: a node is its lines and its choices, a choice a
 ; key, its words and the node it leads to; a node with no choices closes on any key.
 ; she is bumped for it and stays, and a second bump starts it over.
 her-tree '((start ("Orozcalia sits by the fire and does not look up.  \"This place seem familiar to you?\"")
                   ((1 "Who are you?" who)
                    (2 "What is this place?" here)
                    (3 "Nope." bye)))
            (who ("\"Orozcalia the calculator.\"")
                 ((1 "Calculator?" name)
                  (2 "Ok." start)))
            (name ("\"Number in, number out.\"  She gestures at the stones.")
                  ((1 "What?" card)
                   (2 "I see." start)))
            (here ("\"If you don't know that, pumpkin, then I dread we're in a pickle.\"  She pokes the fire.")
                  ((1 "Oh..." start)))
            (card ("\"Recursive or coinductive, no job too big. Take my card.\""
                   "She hands you a tasteful business card:"
                   "Orozcalia the Calculator -- Ranked Numeromatrix -- No Job Too Big"
                   "[beyond city limits, well-bottom at forest-edge, no appt. needed]")
             ((1 "Gosh." start)))
            (bye ("\"You know what to do.\""
                  "She pokes the fire.")
                 ()))
 talk-foot "-- ~ --"
 doom-ttl "the vale"
 doom-lines '("the ground shudders under you, once, and is still."
              ""
              "you suddenly feel eligible for something."
              ""
              "-- any key --")
 box-ttl "a simple wooden box"
 box-lines '("you lift the lid. inside, wrapped in threadbare cloth, is what you came for:"
             ""
             "{~}"
             ""
             "-- any key --")
 house-goods '(pot bronze iron bells cloth table chair bed)
 (sq n) (n * n)
 (circle? g) (last-floor < g 'lvl)
 (circle-q g x y) (: dx (x - g 'cx) dy (y - g 'cy) (dx * dx + 4 * dy * dy))

 ; the board's reach from the fire, in the ring's own quarter-unit measure
 (circle-far g) (: d (g 'd) w (d 'w) h (d 'h) cx (g 'cx) cy (g 'cy)
                   dx (cx < w - cx ? (w - cx) cx) dy (cy < h - cy ? (h - cy) cy)
                   (dx * dx + 4 * dy * dy))

 ; the ring's radius in rows, and -1 while there is no ring
 (circle-r g) ('ring = g 'phase ? (g 'r) -1)



 ; how far out the pink front stands, as a share of the board's reach: past the corner
 ; -- which is to say nowhere on the board -- until the ring is half its scale, and then
 ; in to a little under half the board by the time the ring is a point
 (pink-front g) (: r (circle-r g)
                   (? (r < 0 || pink-start <= r) 1.0
                      (pink-floor + (((1.0 - pink-floor) * r) / pink-start))))
 (ramp-pen rp v) (: m (#rp - 1)
                    n (int (((v + pink-span) * #rp) / (2.0 * pink-span)))
                    (rp (? (n < 0) 0 (m < n) m n)))
 (skin-pen g x y) (: v (peep (g 'sk) [y x] 0.0)
                     f (pink-front g)
                     (ramp-pen ((circle-q g x y) > (f * f * circle-far g)
                                ? pink-ramp grass-ramp)
                               v))


 ; a cell is on the ring when its measure falls in the radius's own band -- a circle of
 ; grid squares, not a box, so it stays round at every size it passes through
 (on-ring? g x y) (: r (circle-r g) q (circle-q g x y)
                     (? (r < 0) 0 (r = 0) (q = 0)
                        (sq (2 * r - 1) <= q < sq (2 * r + 1))))
 (ring-in g) (sq (2 * circle-r g - 1))                  ; the measure the ring starts at

 ; the walls nobody sees: past them is not walked. the closing's own, then the ring's
 (walled? g x y) (circle? g && 'vale = g 'scene &&
                  (: q (circle-q g x y)
                     (g 'phase @ 'close (g 'wq <= q)
                                 'ring (ring-in g <= q)
                                 0)))
 (done? g) ('ring = g 'phase && g 'r <= 0)

 ; a strike on the ring: it gives nothing, and you go back toward the fire
 (ring-bump g) (: p (g 'p)
                  (go n) (? (0 < n)
                            (: nx (p 'x + sgn (g 'cx - p 'x)) ny (p 'y + sgn (g 'cy - p 'y))
                               (? (open? (g 'd) nx ny && !(g 'loot (nx + g 'd 'w * ny)))
                                  (pins p 'x nx 'y ny, go (n - 1)))))
                  _ (go knock)
                  (note g w-ring))


 ; the walls and the ring draw in over you, so a climber standing where one now stands
 ; is carried in with it -- toward the fire until the floor is under them again
 (push-in g wq) (: p (g 'p)
                   (go x y) (? (circle-q g x y < wq || x = g 'cx && y = g 'cy) (pins p 'x x 'y y)
                               (go (x + sgn (g 'cx - x)) (y + sgn (g 'cy - y))))
                   (go (p 'x) (p 'y)))


 ; a turn of the closing: the walls in by a step until the octagon holds you, and then
 ; the ring, in a row a turn until it is the point, which is the end
 (vale-tick g) (g 'phase @
   'close (: wr (g 'wr - close-step)
             _ (? (wr <= oct-y + 1)
                  (pins g 'phase 'ring 'r (g 'r0) 'wq (sq (2 * (oct-y + 1))), note g w-circle)
                  (pins g 'wr wr 'wq (sq (2 * wr))))
             (push-in g (g 'wq)))
   'ring (: _ (pin g 'r (g 'r - 1))
            _ (0 < g 'r ? (push-in g (ring-in g)))
            (done? g ? (pin g 'over 'won))))



 ; --- the scenes: the vale, the house and its attic are floors under one climber, and
 ; a cell of one may be a door into another. a scene is its floor, its loot and her.
 (scene-of g k) (g 'scenes k)
 (scene-save g) (pins (scene-of g (g 'scene)) 'loot (g 'loot) 'her (g 'her))

 ; lit end to end: the seen cask filled, the floor marked so, and no table of cells
 (lit-all d) (: sn (d 'seen)
                _ (each ^(d 'w * d 'h) (i \ pin sn i 1))
                _ (pin d 'lit 1)
                {})
 (enter g k x y) (: _ (scene-save g)
                    sc (scene-of g k) d (sc 'd)
                    _ (pins g 'scene k 'd d 'loot (sc 'loot) 'her (sc 'her) 'ms ())
                    _ (pins (g 'p) 'x x 'y y)
                    _ (pin g 'vis (lit-all d))
                    (k @ 'vale (doom g) ()))
 (exit-at g x y) (peep (peep (g 'd) 'exits {}) (x + g 'd 'w * y) ())


 ; out of the house with the token: the shudder, the sign, and the closing begun; and
 ; she is gone from the fire, spoken to or not
 (doom g) (? (g 'token && !(g 'doom))
             (: far (circle-far g)
                wr (1 + int (sqrt (far * 1.0) / 2.0))
                d (g 'd)
                r0 (: a (d 'rows // 2) b (d 'w // 4) (1 + (a < b ? b a)))
                (pins g 'doom 1 'rumble 1 'phase 'close 'wr wr 'wq (sq (2 * wr)) 'r0 r0
                        'sign (doom-ttl . doom-lines) 'her ())))

 ; the box, opened: the token is drawn here and named here, and the box is empty after
 (open-box g) (? (g 'token) (note g w-empty)
                 (tokens (roll (g 'sb) #tokens) @ tk
                  (pins g 'token tk 'sign (box-ttl . map (l \ fill l [tk]) box-lines))))

 ; the tree: a node's sign is its lines, then its choices numbered, then the foot
 (talk-node k) (:- (go her-tree)
   (go l) (two? l ? (: e <l (k = <e ? e (go >l))) ()))
 (joins-with sp l) (? (one? l) "" (one? >l) <l (<l + sp + joins-with sp >l))

 ; a choice's line is marked off between the bytes 1 and 2, which fit paints as a button
 (choice-line c) (string 1 + " " + show <c + "  " + c 1 + " " + string 2)
 (talk g k) (: nd (talk-node k)
               txt (nd 1) chs (nd 2)
               ks (map (show * cap) chs)
               lines (txt + (two? chs ? [""] ()) + (map choice-line chs)
                          + ["" (fill talk-foot [(two? chs ? (joins-with ", " ks) "any key")])])
               (pins g 'talk k 'sign (her-ttl . lines)))


 ; the key at a node: a digit picks its choice, anything else at a node with choices
 ; shows it again, and a node without them closes
 (talk-key g k) (: nd (talk-node (g 'talk)) chs (nd 2)
                 (one? chs ? (pin g 'talk ())
                  (: c (filter (c \ 48 + <c = k) chs)
                   (talk g (two? c ? (<c 2) (g 'talk))))))
 (meet-her-vale g) (pin g 'talked 1, talk g 'start)



 ; --- laying the vale: the road, the clearing, the stones, the fire, the cottage ---
 ; the road wanders on two sines the way the walk's does, five cells wide
 (road-x cx y) (cx + int (3.0 * sin (y * 0.21) + 2.0 * sin (y * 0.063)))



 ; a point of the octagon: k of eight, clockwise from the right of the top pair -- the
 ; octagon stands turned an eighth of a slice, a flat side up -- and the eighth is the
 ; left of that pair
 (oct-pt fx fy k) (: a (k * 0.7853981633974483 - 1.1780972450961724)
                     c (cos a) s (sin a)
                     [(fx + int (oct-x * c + (0.0 < c ? 0.5 -0.5)))
                      (fy + int (oct-y * s + (0.0 < s ? 0.5 -0.5)))])
 (vale w h rows) (:
   d {'w w 'h h 'rows rows 't (cask (w * h)) 'seen (cask (w * h)) 'rooms () 'exits {}}
   cx (w // 2)
   cy (h // 2 - rows // 2) ry (rows * 2 // 3)
   rx (: m (w // 2 - 2) n (2 * ry + 4) (m < n ? m n))
   fx cx fy (cy + ry // 5)
   (fill-box x0 y0 bw bh t) (each ^bh (j \ each ^bw (i \ dput d (x0 + i) (y0 + j) t)))
   ; the clearing: an ellipse of grass
   _ (each ^h (y \ each ^w (x \ (: dx (x - cx) dy (y - cy)
                                    (? (dx * dx * ry * ry + dy * dy * rx * rx <= rx * rx * ry * ry)
                                       (dput d x y 1))))))
   ; the road up from the foot to the clearing, grass two cells either side of it
   _ (each ^(h - 1) (j \ (: y (h - 1 - j) mx (road-x cx y)
                            (? (cy + ry - 2 <= y)
                               (each ^9 (i \ (: x (mx - 4 + i)
                                                (? (0 < x && x < w - 1 && 0 < y)
                                                   (dput d x y (|(x - mx) <= 2 ? 9 1))))))))))
   ; the fire on its dirt, and the stones about it, seven and a bare spot
   _ (fill-box (fx - 2) (fy - 1) 5 3 9)
   spot (oct-pt fx fy 7)
   _ (dput d <spot <>spot 10)
   ; the cottage: timber, a door in its south wall, and the garden behind it
   cy0 (fy - oct-y - 7)
   _ (fill-box (fx - 4) cy0 9 5 11)
   _ (dput d fx (cy0 + 4) 5)
   _ (fill-box (fx - 4) (cy0 - 3) 9 3 12)
   _ (pin (d 'exits) (fx + w * (cy0 + 4)) ['house (house-w // 2) (house-h - 2)])
   foot (road-x cx (h - 2))
   _ (pins d 'in [foot (h - 2)] 'fire [fx fy] 'door [fx (cy0 + 5)] 'th th-vale 'sd 1
            'solid '(11))                                  ; the cottage's timber; its bed is not
   d)


 ; the house: one room of boards with a door south and a stair up; the attic over it.
 ; each is painted at the screen's height, the rows past it blank
 (room w h rows cols) (: d {'w w 'h h 'rows rows 'cols cols 't (cask (w * h)) 'seen (cask (w * h))
                            'rooms () 'exits {}}
                         _ (each ^(h - 2) (j \ each ^(w - 2) (i \ dput d (1 + i) (1 + j) 1)))
                         (pins d 'th th-house 'sd 2))
 (house rows cols) (: d (room house-w house-h rows cols)
                      _ (dput d (house-w // 2) (house-h - 1) 5)
                      _ (dput d (house-w - 3) 1 2)
                      _ (pin (d 'exits) (house-w - 3 + house-w * 1) ['attic 2 (attic-h - 2)])
                      d)
 (attic rows cols) (: d (room attic-w attic-h rows cols)
                      _ (dput d 1 (attic-h - 2) 13)
                      _ (pin (d 'exits) (1 + attic-w * (attic-h - 2)) ['house (house-w - 3) 2])
                      d)
 (vale-new g) (: rows (g 'd 'h) w (g 'd 'w) h (3 * rows)
   sb (g 'sb)
   d (vale w h rows)
   fx <(d 'fire) fy <>(d 'fire)
   ph (roll sb 1000 / 10.0)                            ; where in the drift it stopped
   sk (ink-drift h w ph 0.0)
   _ (pin d 'skin {'ground sk})
   loot {}
   _ (pin loot (fx + w * fy) '(fire))
   _ (each ^7 (k \ (: pt (oct-pt fx fy k) (pin loot (<pt + w * <>pt) ['stone (k + 1)]))))
   ; a wooden sign on the right of the road in, a few rows up from the foot
   sy (h - 5)
   _ (pin loot (road-x fx sy + 3 + w * sy) '(sign))
   her {'x (fx + 2) 'y fy 'gl her-glyph 'hue her-pen}
   hs (house rows w)
   ; ..whose door lets out onto the vale, on the cottage's step
   _ (pin (hs 'exits) (house-w // 2 + house-w * (house-h - 1)) ['vale <(d 'door) <>(d 'door)])
   hl {}
   ; a free cell of the house, off the door's step and the stair
   (spot n) (? (0 < n) (: x (1 + roll sb (house-w - 2)) y (1 + roll sb (house-h - 2))
                          i (x + house-w * y)
                          (1 = dat hs x y && !(hl i) &&
                           !(x = house-w // 2 && y = house-h - 2) &&
                           !(x = house-w - 3 && y = 2) ? i (spot (n - 1)))))
   ; the hearth on the north wall, lit: the one red thing in the house
   _ (pin hl (house-w // 2 + house-w * 1) '(hearth))
   _ (each house-goods (k \ (: i (spot 40) (i ? (pin hl i [k])))))
   at (attic rows w)
   al {}
   _ (pin al (attic-w - 2 + attic-w * (attic-h // 2)) '(box))
   _ (pins g 'lvl (1 + last-floor) 'cx fx 'cy fy 'phase 'walk 'r -1 'ms () 'token () 'talked ()
           'doom () 'talk ()
           'scenes {'vale {'d d 'loot loot 'her her}
                    'house {'d hs 'loot hl 'her ()}
                    'attic {'d at 'loot al 'her ()}}
           'scene 'vale 'd d 'loot loot 'her her
           'sk sk
           'vis (lit-all d))
   _ (pins (g 'p) 'x <(d 'in) 'y <>(d 'in))
   ; the painter's overlay: the ring where it stands, wearing the slop's pink over this
   ; floor's own shimmer -- the ocean at the tower's foot, arriving early. the sample walks
   ; with the radius, so the colour crawls across the ring as it closes
   _ (pin d 'over (\ x y (? ('ring = g 'phase && on-ring? g x y)
                            [ring-glyph (ramp-pen pink-ramp (peep sk [((y + g 'r) % h) x] 0.0))]
                            ())))
   (note g (fill w-floor [(here g)])))


 ; one turn: the climber's steer, then every mob its pace is due, then the lantern
 (crawl-turn g k) (:
   _ (pins g 'msg "" 'tn (1 + g 'tn))
   ; a sign standing is what the key buys: it comes down, and the turn is not taken
   sg (g 'sign)
   _ (sg && pin g 'sign ())
   ; ..unless it was a page and the book has another: that one goes up in its place
   _ (? (sg && two? (g 'pages)) (pins g 'sign <(g 'pages) 'pages >(g 'pages)))
   ; ..and a page of the book that never ends makes the next
   _ (? (sg && g 'bell) (bell-key g k))
   ; ..and a page of her tree takes the key as its answer
   _ (? (sg || g 'over || k = 46) (sg && g 'talk ? (talk-key g k))
        (two? k) (stride g k, mend g)
        (k @ (60 || 32 || 13 || 10) 1 0)
         (: _ (dat (g 'd) (g 'p 'x) (g 'p 'y) @ 2 (ascend g) (note g w-stair))
            (mend g)))
   _ ((sg || (g 'over || circle? g)) ? ()
      (each (g 'ms) (m \ !(g 'over) && due? g m && (m 'car ? (drive g m) (stir g m)))))
   ; the vale's closing takes a turn for every turn taken, and none for a sign's key
   _ (circle? g && !sg && !(g 'over) && vale-tick g)
   _ (circle? g && pin (g 'd) 'front (: f (pink-front g) (f < 1.0 && f * f * circle-far g)))
   (circle? g ? g (pin g 'vis (fov (g 'd) (g 'p 'x) (g 'p 'y) 8))))


 ; the bar, and on a stair the one thing worth saying there
 (crawl-bar g) (: p (g 'p)
                  up (!(circle? g) && 2 = dat (g 'd) (p 'x) (p 'y))
                  (fill (up ? w-bar-up w-bar)
                        [(here g) (p 'hp) (p 'mx) (p 'penny)]))



 ; a floor taller than the screen is shown about the climber: the view's top row,
 ; clamped to the floor, and a jolt of a row either way while the ground shudders
 ; ..and a floor smaller than the screen sits in the middle of it
 (view! g) (: d (g 'd) rows (peep d 'rows (d 'h)) h (d 'h) w (d 'w) cols (peep d 'cols w)
              _ (? (rows < h)
                   (: v (g 'p 'y - rows // 2 + peep d 'jolt 0)
                      (pin d 'vy (? (v < 0) 0 (h - rows < v) (h - rows) v)))
                   (h < rows) (pin d 'vy (0 - (rows - h) // 2)))
              (? (w < cols) (pin d 'vx ((cols - w) // 2))))
 (crawl-frame g) (: d (g 'd) rows (peep d 'rows (d 'h))
                    _ (view! g)
                    f (:- (slurp j) j
                       (paint (jug 0) d (cell-face d (g 'vis) (g 'loot) (ents g))
                        (g 'msg) (crawl-bar g)))
                    sg (g 'sign) cols (peep d 'cols (d 'w))
                    ; ..laid at the screen's width, which a room may be narrower than;
                    ; where it lands is kept, for the live painter to keep out of
                    _ (pin d 'box (two? sg ? (sign-rect <sg >sg 1 rows cols) ()))
                    (two? sg ? (sign-over f <sg >sg 1 rows cols) f))
 (live-frame g) (: d (g 'd) (:- (slurp j) j
                   (paint-live (jug 0) d (g 'vis) (cell-face d (g 'vis) (g 'loot) (ents g)) (live-cells d (g 'loot)))))









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
 (song-vol g) (? (circle? g && 0 <= circle-r g)
                  (: v ((circle-r g * 1.0) / (g 'r0 * 1.0)) (v < 1.0 ? v 1.0))
                  (peep songs ((g 'lvl) - 1) <songs))

 (song-new h) {'h h 'fpos 0 'cyc 0 'next 0 'vs () 'lvl 1 'rad circle-r0
               'voices (cite 'play 'cyc-voices)
               'mix (cite 'play 'mixdown) 'pk (cite 'play 'pack)}




 ; where the game is, read off it each frame. only a bar not yet built reads them, so
 ; a stair or a struck ring lands at the next bar line and never cuts the one sounding.
 ; the ring's radius is scaled to the heart's own eight, so a wide one races and the
 ; point is a beat a bar; -1 is no ring yet
 (song-tier s g) (pins s 'lvl (g 'lvl)
                         'rad (circle? g && 0 <= circle-r g ? ((circle-r g * circle-r0) // g 'r0) -1),
                  song-sfx s g)


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
                   (pin s 'vs (s 'vs + filter two? vs)))


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
 (tower-win g) (: tk (g 'token || tokens (roll (g 'sb) #tokens))
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
             ; ..and while it waits the floor's live cells go on: a quarter-second count
             ; kept on the floor, and each count they are laid again, alone
             (flick! _) (: d (g 'd) t (clock 0 // 250)
                           (? (t != peep d 'ft ()) (pin d 'ft t, say out (live-frame g), flush out)))
             (idle _) (: _ (? sng (song-feed sng (song-vol g)) (rest 30)) (flick! ()))
             ; ..but escape at a standing sign takes the sign down, and nothing else:
             ; a page of the book or her tree is left, not the tower
             (turn k) (? (k = 27 && g 'sign) (pins g 'sign () 'pages () 'bell () 'talk ())
                         (k @ (113 || 27 || -7) (pin g 'over 'fled)
                          -12 (crawl-turn g (tap-key g (edtap ())))
                          (crawl-turn g (steer k))))
             ; the ground shudders: the view jolts a row either way for half a second,
             ; with whatever sign the turn raised held back until it is still
             ; ..and the song is fed through it: two chunks are the beat a jolt holds for
             (rumble! _) (: d (g 'd) sg (g 'sign)
                            _ (pin g 'sign ())
                            (jolt _) (? sng (each ^2 (_ \ song-feed sng (song-vol g))) (rest 66))
                            _ (each ^6 (k \ (pin d 'jolt (k % 2 = 0 ? 1 -1),
                                             say out (crawl-frame g), flush out, jolt ())))
                            (pin d 'jolt 0, pin g 'sign sg, pin g 'rumble ()))
             (loop last t0) (? (g 'over) ()
                               (: _ (say out (crawl-frame g), flush out)
                                  k (key-wait t0 last (g 'sign ? sign-gap repeat-gap) idle)
                                  _ (turn k)
                                  _ (? (g 'rumble) (rumble! ()))
                                  _ (? sng (song-tier sng g) ())
                                  (loop k (clock 0))))
             _ (raw 1)
             _ (say out "\e[?1049h\e[?25l\e[2J")
             _ (loop 0 0)
             ; an end shows its frame for a beat before the screen is given back
             _ (say out (crawl-frame g), flush out, rest 1200)
             ; ..and the card goes back before the walk asks for it
             _ (? hn (: _ (flush hn) (close hn)) ())
             _ (g 'over = 'won ? (tower-win g))
             _ (say out "\e[0m\e[?25h\e[?1049l")
             _ (flush out)
             _ (drain-keys ())
             _ (raw 0)
             ; won: the token line is still in the note row, and goes to the shell too.
             ; the shell hears 0 whichever way the climb ended: a count is not a status
             _ (puts ((g 'over @ 'won (fit (g 'msg) 200)
                                 'dead (fill w-lost [(here g)])
                                 (fill w-fled [(g 'p 'penny)])) + "\n"))
             0)
 tower-usage "usage: love tower   (no options; q or esc leaves the tower)"

 ; tower takes nothing: a word here is a mistake, and the climb would swallow it
 (tower-main as) (one? as ? (tower-run ())
                    (say err (fill w-args [<as]), flush err, 2))
 _ (pins (cite 'verbs 'tab) 'tower (udoor 'tower tower-main tower-usage 1 1)))
) ; module tower
