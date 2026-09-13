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
(module (rove tower-run tower-main dat open? dput delve fov clear? paint steer
         crawl-new crawl-turn crawl-frame crawl-bar note mob-new mob-at mob-set roll stock
         mend ascend fill fit circle? circle-new circle-stride circle-frame
         circle-r circle-wall on-ring? reveal? done? tokens floors due?
         themes plan tile-face strewn pink-ramp grass-ramp pink-front skin-pen
         flavour mutter underfoot sign-box sign-over
         songs tower-bars tower-tune song-vol song-new song-feed drain-keys
         garden-bars middle-bars sky-bars heart-bars heart-rate tune?)
; posix is optional -- the page's seat (i/wasm) links none of it and this file runs
; there, so ask before splicing: an absent module is a scare.
(? (cite 'posix) (borrow 'posix) ())
; and ink, which the last floor paints with: the shader the walk runs, stopped
(borrow 'ink)
(:
 ; --- the floor: tiles in a cask, (x y) indexed; 0 rock, 1 floor, 2 the stair ---
 (dat d x y) (0 <= x < d 'w && 0 <= y < d 'h ? (peep (d 't) (x + (d 'w) * y) 0) 0)
 (open? d x y) (0 < dat d x y)
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
   (d . peep sb () 0))

 ; --- the lantern: line-of-sight fov over bresenham strides ---
 ; a stride is clear when every cell strictly between the ends is open; the
 ; endpoint itself may be rock -- that is how a wall catches the light.
 (clear? d x0 y0 x1 y1) (:
   dx |(x1 - x0) dy (0 - |(y1 - y0))
   sx (? (x0 < x1) 1 -1) sy (? (y0 < y1) 1 -1)
   (go x y e) (? ((x = x1) && (y = y1)) 1
               (: e2 (2 * e)
                  mx (dy <= e2) my (e2 <= dx)
                  nx (? mx (x + sx) x) ny (? my (y + sy) y)
                  ne (e + (mx ? dy) + (my ? dx))
                  (? (nx = x1 && ny = y1) 1
                     (open? d nx ny) (go nx ny ne)
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
 (dice x y s k) ((mix ((y * 374761393) + (x * 668265263) + (s * 2654435761) + 1)) % k)

 ; --- the make of each floor: rock, the ground, what is strewn over it, and the plan
 ; its rooms are cut to -- the only place a tier's look is written. a face is
 ; (glyph lit dim), and a strewing carries a fourth number: cells in a hundred.
 th-garden '((38 28 22) (46 143 58)                     ; hedge and earth
             ((44 71 65 26 "tuft") (34 34 22 12 "grass") (42 212 89 6 "aster")
              (42 220 136 5 "marigold") (126 38 24 3 "runnel"))
             (3 5 2 3 18))                              ; small beds, a great many
 th-middle '((35 246 238) (46 245 239)                  ; stone and flagstone
             ((44 241 237 16 "rubble") (58 240 236 10 "gravel")
              (37 187 95 6 "bones") (42 251 244 4 "quartz"))
             (4 7 3 4 24))                              ; rooms, the middling sort
 th-heaven '((35 255 249) (46 252 245)                  ; marble and paving
             ((58 250 244 20 "cobbles") (43 226 136 7 "lamp") (61 180 94 5 "bench")
              (111 45 24 4 "fountain") (42 231 145 5 "star"))
             (8 9 4 5 40))                              ; blocks, and streets between
 themes [th-garden th-middle th-heaven]
 (plan lvl) ((peep themes (lvl - 1) th-heaven) 3)
 stair-face '(60 220 136)                               ; < the stair, gold on every floor
 (loot-face _) '(36 172)                                ; pennies: $ in copper

 ; a cell's face: the stair, the rock, or the ground with whatever it was strewn with
 (make d) (peep d 'th th-middle)                        ; a floor nobody dressed is stone
 (wear r lit) [<r (lit ? (r 1) (r 2))]
 (strewn th x y s) (: (go l h) (? !(two? l) ()
                                  (: r <l w (r 3) (? (h < w) r (go >l (h - w)))))
                      (go (th 2) (dice x y s 100)))
 (tile-face th t lit x y s)
  (t @ 2 (wear stair-face lit)
       0 (wear <th lit)
         (: r (strewn th x y s) (wear (two? r ? r (th 1)) lit)))
 (paint j d vis loot ents msg bar) (:
   w (d 'w) h (d 'h) sn (d 'seen)
   th (make d) sd (peep d 'sd 0)
   spot (foldl (\ t e (pin t (e 'x + w * e 'y) e)) {} ents)
   ; the note row through `fit`: a message may carry the token's braces, and an
   ; escape is no width, so the cut is made in what a reader sees
   _ (say j $ "\e[H\e[0m" + (fit msg w) + "\e[K\r\n")
   (cell i lit) (: e (lit ? (spot i))
                   it (lit ? (loot i))
                   (? e [(e 'gl) (e 'hue)]
                      it (loot-face it)
                      (peep sn i 0)
                       (tile-face th (peep (d 't) i 0) lit (i % w) (i // w) sd)
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

 ; --- the words: every line the climb says. a ~ takes the next value and {braces} are
 ; the token's pen; nothing below is built, so this block is the whole of the text.
 w-open   "the tower stands over you. get the {token}"
 w-floor  "this is ~. get the {token}"
 w-strike "you strike the ~ (~)"
 w-kill   "the ~ is done for"
 w-bite   "the ~ bites you (~)"
 w-dead   "you are done for"
 w-wall   "~ holds"
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
             "climb    <          while you stand on a stair"
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
 ; a frame with the box centred over its rows a .. a+n, for a screen w wide
 (sign-over f ttl ls a n w) (:- (go 0 "")
   rs (split "\r\n" f)
   box (sign-box ttl ls)
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
 (mend g) (: p (g 'p) h ((p 'hp) + regen) (pin p 'hp (h < p 'mx ? h (p 'mx))))
 (mob-row k) (peep mob-book k <mob-book)
 (mob-name k) <(mob-row k)
 (mob-new k x y) (: r (mob-row k)
                   {'x x 'y y 'gl (peep r 1 114) 'hue (peep r 2 137)
                    'hp (peep r 3 3) 'dm (peep r 4 1) 'pc (peep r 5 1) 'nm <r})

 ; stock a fresh floor: mobs and pennies in every room but the climber's own. the
 ; token is not on any floor -- it is what the circle turns out to have been.
 last-floor 3
 (stock g) (:
   d (g 'd) sb (g 'sb) lvl (g 'lvl) loot {} ks (mob-set lvl)
   (drop-at rm) [(peep rm 0 0 + roll sb (peep rm 2 1)) (peep rm 1 0 + roll sb (peep rm 3 1))]
   (mobs rm n acc) (? (0 < n)
                    (: xy (drop-at rm) x <xy y <>xy
                       (? (dat d x y = 1 &&
                           !(loot (x + d 'w * y)) &&
                           !(any ({'x ^x 'y ^y} \ 1) acc))
                        (mobs rm (n - 1) (mob-new (peep ks (roll sb #ks) 0) x y . acc))
                        (mobs rm (n - 1) acc)))
                    acc)
   ; every room has pennies, which are the point of the place. the tile is read through
   ; `dat`: a cask does not answer to being applied, so (d 't i) is () for every cell
   (treasure rm n) (? (0 < n)
                    (: xy (drop-at rm) x <xy y <>xy
                       _ (? (1 = dat d x y)
                            (pin loot (x + (d 'w) * y) ['penny (3 + roll sb 12)]))
                       (treasure rm (n - 1))))
   ms (foldl (\ acc rm (treasure rm (2 + roll sb 2), mobs rm (roll sb (2 + lvl)) acc))
             () (init (d 'rooms)))
   (pins g 'ms ms 'loot loot))

 ; a floor wears its tier: the make it is built of, and the salt its litter is dealt
 ; from -- one draw, so the same seed strews the same floor
 (dress d lvl sb) (pins d 'th (peep themes (lvl - 1) th-heaven) 'sd (roll sb 1000000))

 ; a fresh climb: the garden delved from the seed state, the climber at 'in
 (crawl-new w h st) (:
   p0 (delve w h st (plan 1)) d <p0
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
                         (: r (strewn (make d) x y sd)
                            (two? r ? (mutter k (r 4)) ""))))
 (tread g x y) (: s (underfoot g x y) (s ? (note g s)))

 (stride g mv) (: p (g 'p) nx (p 'x + <mv) ny (p 'y + <>mv)
                  m (mob-at g nx ny)
                  (? m (strike g m)
                     !(open? (g 'd) nx ny) (note g (fill w-wall [(here g)]))
                     (: _ (pin p 'x nx, pin p 'y ny)
                        i (nx + (g 'd 'w) * ny)
                        it (g 'loot i)
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
              (: p0 (delve (g 'd 'w) (g 'd 'h) (peep (g 'sb) () 0) (plan (1 + g 'lvl)))
                 d <p0
                 _ (pin (g 'sb) () >p0)
                 _ (pins g 'd d 'lvl (1 + g 'lvl))
                 _ (dress d (g 'lvl) (g 'sb))
                 _ (pins (g 'p) 'x <(d 'in) 'y <>(d 'in))
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
                   _ (pins g 'lvl (1 + last-floor) 'cx cx 'cy cy 'st 0 'ms () 'loot {}
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
   _ (? (sg || g 'over || k = 46) ()
        (circle? g) (two? k ? (circle-stride g k))
        (two? k) (stride g k, mend g)
        (k = 60) (: _ (dat (g 'd) (g 'p 'x) (g 'p 'y) @ 2 (ascend g) (note g w-stair))
                    (mend g)))
   _ ((sg || (g 'over || circle? g)) ? ()
      (each (g 'ms) (m \ !(g 'over) && due? g m && stir g m)))
   (circle? g ? g (pin g 'vis (fov (g 'd) (g 'p 'x) (g 'p 'y) 8))))

 ; the bar, and on a stair the one thing worth saying there
 (crawl-bar g) (: p (g 'p)
                  up (!(circle? g) && 2 = dat (g 'd) (p 'x) (p 'y))
                  (fill (up ? w-bar-up w-bar)
                        [(here g) (p 'hp) (p 'mx) (p 'penny)]))
 (crawl-frame g) (: f (circle? g ? (circle-frame g)
                      (:- (slurp j) j
                       (paint (jug 0) (g 'd) (g 'vis) (g 'loot)
                        (g 'p . g 'ms) (g 'msg) (crawl-bar g))))
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
 (song-tier s g) (pins s 'lvl (g 'lvl) 'rad (circle? g ? (circle-r g) 0))
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
