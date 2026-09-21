; garage -- the level after the plain: the dry riverbed runs in through the east wall of
; a mall's parking garage and out through the west. concrete all round, thickened into
; pilasters along the walls, and the floor laid out as a garage is: a lane round the
; outside, islands of bays back to back with lanes between them, the bays in sections a
; few wide with a lane between the sections, so a car could drive round; yellow lines
; between the bays and a column on the middle line of each section; wrecked cars in
; some of the bays, drawn in blocks. the middle, where the bed runs, is left bare. rats have the place; they wander, they are not hostile, and there is no
; fighting -- bumping one is rat-interaction, which for now reports the rat hawking a
; bauble at you. the way on is west, off the map along the bed.
;
; a roguelike floor on rove: laid, not delved, the size of the screen, lit end to end;
; the painter is rove's and the keys the tower's. the game is pure love -- garage-new,
; garage-turn and garage-frame are state in and state out, the song feeds any port --
; gated headless by test/host/garage.l. garage-walk takes a stage already raised, which
; is how the apartment hands over on the same screen, and garage-run raises one. no
; music yet: the song is silence with the shape the rest have, for the effects and a
; tune to go into.
;
; run: love garage    h j k l or the arrows walk, y u b n slant; q or esc leaves
(module (garage garage-run garage-walk garage-main garage-new garage-turn garage-frame
         garage-bar garage-lay garage-face garage-stride garage-stir rat-interaction
         car-cells bay-w bay-d bed-h rat-glyph garage-song-new garage-song-feed song-chunk)
; posix is optional -- the page's seat (inle/wasm) links none of it and this file runs
; there, so ask before splicing: an absent module is a scare.
(? (cite 'posix) (borrow 'posix) ())
(borrow 'rove)
(borrow 'ink)                           ; the shimmer, one frame of it held still, for the floor's stains
(borrow 'play)                          ; the voices, the mix
(:
 esc (string 27)
 ; --- the garage: tiles in a cask, (x y) indexed. 0 concrete wall, 1 the floor, 2 a
 ; column, 3 a pilaster -- the wall thickened along its inner face -- 4 a painted line,
 ; 5 the dry riverbed, and 6 a wreck's cell
 bed-h 3
 bay-w 5                                ; a bay: four cells of car and a line
 bay-d 2                                ; ..two rows deep, a car's height
 lane-w 2                               ; a lane between two islands, in rows
 edge-rows 2                            ; the lane inside the top and bottom walls, in rows -- a car's height
 edge-cols 7                            ; ..and inside the east and west walls, in cells -- more than a car's width
 section-bays 4                         ; bays to a section..
 section-lane 7                         ; ..and the cells of lane between two sections, wider than a bay
 zone-margin 2                          ; rows either side of the bed's reach left bare
 pilaster-x 6                           ; the pilasters' spacing along the walls
 pilaster-y 4
 ground-glyph "█"
 floor-ramp [240 239 238 237 236 235 234 233]   ; concrete, stained in bands
 bed-ramp [180 179 137 136 95 94 58 58]        ; the bed: silt, browns
 wall-pen 246
 pilaster-pen 248
 column-pen 252
 line-glyph "│"
 line-pen 226                           ; the bays' yellow
 car-pens '(160 124 24 25 66 130 244 94 172)    ; reds, blues, a green, rust, greys
 car-shape '(("▄" "█" "█" "▄") ("█" "▀" "▀" "█"))
 wreck-glyph "▒"                        ; a crumpled cell
 wreck-pen 239
 rat-glyph 114
 rat-pen 137
 me-pen 228
 rats-least 6
 rats-more 5

 ; --- the words: every line the level says; a ~ takes the next value ---
 w-concrete "concrete"
 w-wreck    "a wreck, and nothing in it"
 w-east     "the bed runs back east, to the plain"
 w-rat      "the rat hawks a bauble at you"
 w-bar      "~  turn ~"
 open-ttl   "the garage"
 open-lines '("the dry riverbed runs in under a low concrete ceiling, between the columns of a parking garage.  something is scuttling in the bays."
              ""
              "move     h j k l    or the arrow keys"
              "         y u b n    for diagonals"
              "leave    q          or esc"
              ""
              "-- any key --")
 ; a rat, bumped: the die is threaded through for what a rat may come to say or do
 (rat-interaction sb r) w-rat

 ; --- laying the garage ---------------------------------------------------------------
 (garage-lay w h sb) (:
   d {'w w 'h h 't (cask (w * h)) 'seen (cask (w * h)) 'rooms () 'rows h 'cols w 'solid '(0 2 3 6)}
   _ (each ^(w * h) (i \ pin (d 't) i 1))
   ; the walls, and the pilasters along their inner faces
   _ (each ^w (x \ (dput d x 0 0, dput d x (h - 1) 0)))
   _ (each ^h (y \ (dput d 0 y 0, dput d (w - 1) y 0)))
   _ (each ^(w // pilaster-x) (k \ (: x (pilaster-x // 2 + k * pilaster-x)
                                      (? (0 < x < w - 1) (dput d x 1 3, dput d x (h - 2) 3)))))
   _ (each ^(h // pilaster-y) (k \ (: y (pilaster-y // 2 + k * pilaster-y)
                                      (? (0 < y < h - 1) (dput d 1 y 3, dput d (w - 2) y 3)))))
   ; the plan: the river's zone through the middle, bare; above it and below, from the
   ; wall in, a lane, then two bands of bays back to back and a lane, as far as they
   ; fit, and one band alone where two will not -- the zone or the wall's lane is the
   ; lane it faces
   cy (h // 2)
   zt (cy - zone-margin) zb (cy + bed-h + zone-margin)
   (bands-down a b) (:- (go (a + edge-rows) ()) (go y acc)
     (? (y + 2 * bay-d <= b) (go (y + 2 * bay-d + lane-w) (acc + [y (y + bay-d)]))
        (y + bay-d <= b) (acc + [y])
        acc))
   (bands-up a b) (:- (go (b - edge-rows) ()) (go y acc)
     (? (a <= y - 2 * bay-d) (go (y - 2 * bay-d - lane-w) (acc + [(y - bay-d) (y - 2 * bay-d)]))
        (a <= y - bay-d) (acc + [(y - bay-d)])
        acc))
   bands (bands-down 2 zt + bands-up zb (h - 2))
   ; a band across: between the lanes inside the west wall and the east, as many whole
   ; sections as fit with a lane between each two, the lot centred -- or one section of
   ; fewer bays where a whole one will not fit, or none at all on a screen too narrow. a
   ; line at each bay's start and one closing the section, the middle line of a section
   ; a column. the bays are noted for the cars
   left (1 + edge-cols) right (w - 1 - edge-cols)
   span (right - left)
   sec-w (section-bays * bay-w + 1)
   nsec ((span + section-lane) // (sec-w + section-lane))
   nb (0 < nsec ? section-bays ((span - 1) // bay-w))
   n (? (0 < nsec) nsec (0 < nb) 1 0)
   width (n * (nb * bay-w + 1) + (n - 1) * section-lane)
   x0 (left + (span - width) // 2)
   bays {()}
   (mark x y0 t) (each ^bay-d (j \ (? (1 = dat d x (y0 + j)) (dput d x (y0 + j) t))))
   (band y0) (each ^n (si \ (: sx (x0 + si * (nb * bay-w + 1 + section-lane))
                              _ (each ^nb (k \ (: x (sx + k * bay-w)
                                                  _ (mark x y0 (k = nb // 2 ? 2 4))
                                                  (pin bays () ([(x + 1) y0] . bays ())))))
                              (mark (sx + nb * bay-w) y0 4))))
   _ (each bands band)
   ; the bed: through the east wall and out through the west, so many rows deep,
   ; wandering on two sines, over everything in its way
   bed (map (x \ (cy + int (1.5 * sin (x * 0.11) + 1.0 * sin (x * 0.037)))) ^w)
   _ (each ^w (x \ each ^bed-h (j \ dput d x (bed x + j) 5)))
   ; the cars: in the bays the die fills, never over the bed; each its place, its pen
   ; and the cells of it that are crumpled
   (bay-free? x y) (all (i \ all (j \ 1 = dat d (x + i) (y + j)) ^bay-d) ^(bay-w - 1))
   (car x y) {'x x 'y y 'hue (car-pens (roll sb #car-pens)) 'dents (map (i \ roll sb (bay-d * (bay-w - 1))) ^(1 + roll sb 2))}
   cars (foldl (\ acc b (: x <b y0 <>b
                           (? (bay-free? x y0 && roll sb 3 < 2)
                              (: c (car x y0)
                                 _ (each ^bay-d (j \ each ^(bay-w - 1) (i \ dput d (x + i) (y0 + j) 6)))
                                 (c . acc))
                              acc)))
               () (rev (bays ())))
   (pins d 'cars cars 'bed bed 'zone [zt zb] 'sd (roll sb 1000000)
           'skin (ink-drift h w (roll sb 1000 / 10.0) 0.0)
           'in [(w - 1) (bed (w - 1))]))
 ; the cells a car takes: [i glyph hue] each, the dents crumpled
 (car-cells c w) (: x (c 'x) y (c 'y) hue (c 'hue) ds (c 'dents)
                    (map (k \ (: i (k % (bay-w - 1)) j (k // (bay-w - 1))
                                 [(x + i + w * (y + j))
                                  (elem k ds ? wreck-glyph ((car-shape j) i))
                                  (elem k ds ? wreck-pen hue)]))
                         ^(bay-d * (bay-w - 1))))

 ; a fresh level: the garage laid from the seed, you on the bed at the east wall, and
 ; the rats wherever the floor is bare
 (garage-new w h st) (:
   sb {st}
   d (garage-lay w h sb)
   p {'x <(d 'in) 'y <>(d 'in) 'gl 64 'hue me-pen}
   (taken? ms x y) (any (m \ m 'x = x && m 'y = y) ms)
   (rat ms n) (? (0 < n) (: x (roll sb w) y (roll sb h)
                            (? (open? d x y && !(taken? ms x y) && !(x = p 'x && y = p 'y))
                               ({'x x 'y y 'gl rat-glyph 'hue rat-pen 'nm "rat"} . ms)
                               (rat ms (n - 1))))
                 ms)
   ms (foldl (\ acc i (rat acc 40)) () ^(rats-least + roll sb rats-more))
   g {'d d 'sb sb 'p p 'ms ms 'msg "" 'tn 0 'over 0 'sign ()}
   _ (pin g 'sign (open-ttl . open-lines))
   g)

 ; --- a turn: a sign standing takes the key, else a step ------------------------------
 ; a rat bumped is rat-interaction; concrete and a wreck hold; the west edge along the
 ; bed is the way out, and the east edge is where you came in
 (garage-stride g mv) (: p (g 'p) d (g 'd) w (d 'w) nx (p 'x + <mv) ny (p 'y + <>mv)
                         t (dat d nx ny) r (mob-at g nx ny)
   (? r (note g (rat-interaction (g 'sb) r))
      (nx < 0 && 5 = dat d 0 ny) (pin g 'over 'west)
      (w <= nx && 5 = dat d (w - 1) ny) (note g w-east)
      (t = 6) (note g w-wreck)
      !(open? d nx ny) (note g w-concrete)
      (pins p 'x nx 'y ny)))
 ; ..and the rats wander, a step a turn to a bare cell beside them
 (garage-stir g) (: d (g 'd) sb (g 'sb) p (g 'p)
   (taken? x y) (x = p 'x && y = p 'y || any (m \ m 'x = x && m 'y = y) (g 'ms))
   (stir m) (: nx (m 'x + roll sb 3 - 1) ny (m 'y + roll sb 3 - 1)
               (? (open? d nx ny && !(taken? nx ny)) (pins m 'x nx 'y ny)))
   (each (g 'ms) stir))
 (garage-turn g k) (:
   _ (pins g 'msg "" 'tn (1 + g 'tn))
   sg (g 'sign)
   _ (? sg (pin g 'sign ())
        (g 'over) ()
        (two? k) (garage-stride g k, garage-stir g)
        ())
   g)

 ; --- the frame: concrete, the floor's stains, the lines, the wrecks, the rats ------
 (ramp-pen rp v) (: m (#rp - 1)
                    n (int (((v + 3.0) * #rp) / 6.0))
                    (rp (? (n < 0) 0 (m < n) m n)))
 (garage-face g) (: d (g 'd) w (d 'w) sk (d 'skin)
   ents ((g 'p) . g 'ms)
   spot (foldl (\ t e (pin t (e 'x + w * e 'y) e)) {} ents)
   wrecks (foldl (\ t c (foldl (\ t2 cl (pin t2 <cl [(cl 1) (cl 2)])) t (car-cells c w))) {} (d 'cars))
   (ground-pen rp x y) (ramp-pen rp (peep sk [y x] 0.0))
   ; what a mob stands on, and a line and a wreck lie on: the floor, or the bed
   (under t x y) (t = 5 ? (ground-pen bed-ramp x y) (ground-pen floor-ramp x y))
   (\ i (: e (spot i) x (i % w) y (i // w) t (peep (d 't) i 0)
           (? e (: bg (under t x y) [(e 'gl) [(legible (e 'hue) bg) bg]])
              (t @ 0 [ground-glyph wall-pen]
                   2 [ground-glyph column-pen]
                   3 [ground-glyph pilaster-pen]
                   1 [ground-glyph (ground-pen floor-ramp x y)]
                   4 [line-glyph [line-pen (ground-pen floor-ramp x y)]]
                   5 [ground-glyph (ground-pen bed-ramp x y)]
                   6 (: c (wrecks i) [<c [<>c (ground-pen floor-ramp x y)]])
                   '(32 0))))))
 (garage-bar g) (fill w-bar ["the garage" (g 'tn)])
 (garage-frame g) (: d (g 'd) rows (d 'rows) cols (d 'cols)
   f (:- (slurp j) j (paint (jug 0) d (garage-face g) (g 'msg) (garage-bar g)))
   sg (g 'sign)
   _ (pin d 'box (two? sg ? (sign-rect <sg >sg 1 rows cols) ()))
   (two? sg ? (sign-over f <sg >sg 1 rows cols) f))

 ; --- the song: silence, in the shape the others have, a chunk out the card at a time ---
 song-chunk (song-rate // 30)
 song-gain 5200.0
 (garage-song-new h st) {'h h 'fpos 0 'vs () 'sb {st}}
 (garage-song-feed s) (: base (s 'fpos)
                         live (filter (v \ v 0 >= base) (s 'vs))
                         _ (pins s 'vs live 'fpos (base + song-chunk))
                         (say (s 'h) (pack (mixdown live base song-chunk) song-chunk song-gain)))

 ; --- the walk: on a stage already raised, the tower's way -- the wait is the song ---
 (garage-walk _) (: ws (tty 1)
   r (two? ws && 7 < <ws ? (<ws - 2) 22)
   c (two? ws && 19 < <>ws ? <>ws 80)
   g (garage-new (c < 100 ? c 100) r (wheel (clock 0)))
   hn (? (tablet? (cite 'harp)) (: q (horn song-rate 2) (? (nom? q) () q)) ())
   sng (? hn (garage-song-new hn (wheel (clock 0))) ())
   pace (pacer ())
   (feed! _) (? (horn-lag hn < song-lead-of (pace! pace)) (garage-song-feed sng) (rest 5))
   (idle _) (? sng (feed! ()) (rest 30))
   (turn k) (? (k = 27 && g 'sign) (pin g 'sign ())
               (k @ (113 || 27 || -7) (pin g 'over 'fled)
                (garage-turn g (steer k))))
   (loop last t0) (? (g 'over) ()
                     (: _ (say out (garage-frame g), flush out)
                        k (key-wait t0 last (g 'sign ? sign-gap repeat-gap) idle)
                        _ (turn k)
                        (loop k (clock 0))))
   _ (say out (esc + "[2J"))
   _ (loop 0 0)
   _ (? hn (flush hn, close hn))
   g)
 ; ..and the verb around it: the screen raised here and put back here
 (garage-run _) (: _ (raw 1)
   _ (say out (esc + "[?1049h" + esc + "[?25l"))
   g (garage-walk ())
   _ (say out (esc + "[0m" + esc + "[?25h" + esc + "[?1049l"), flush out)
   _ (drain-keys ())
   _ (raw 0)
   0)
 garage-usage "usage: love garage   (h j k l or the arrows walk, y u b n slant; q or esc leaves)"
 (garage-main as) (as @ () (garage-run ())
                        (say err ("garage: " + garage-usage + "\n"), flush err, 2))
 _ (pins (cite 'verbs 'tab) 'garage (udoor 'garage garage-main garage-usage 1 1)))
) ; module garage
