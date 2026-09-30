; apartment -- the level after the river: you come to inside a glass cube on a grassy
; plain, one of eight standing in an octagon, a flat side up, yours the left of the top
; pair; a river runs through the octagon's middle from its east edge off the map to the
; west, meandering a little, and each cube's path drops straight to it; there is no way
; out. someone is in every other cube, wandering. a stranger stands outside against your
; glass, named in blocks, and you talk through the pane. when the talk is done the
; stranger is gone, the pane shatters to a drum, the others are bones where they stood,
; the grass past the glass goes over to desert -- the grass inside stays -- and the river
; runs dry: a stone stands in its bed near the west edge, an inscription on it, and the
; way off the map is west along the bed, into the desert at sunset
; (src/apps/rove/dusk.l) where the seat carries it.
;
; a roguelike floor on rove: the plain is laid, not delved, the size of the screen and
; lit end to end; the painter is rove's and the keys the tower's. the talk is a tree the
; tower's way: a node its lines and its choices, a choice a key, its words and the node
; it leads to; a node with no choices closes on any key, and closing is the end of the
; talk. the words are placeholders and the tree is data, chat-book.
;
; the game is pure love -- apartment-new, apartment-turn and apartment-frame are state
; in and state out, the song feeds any port -- gated headless by test/host/apartment.l.
; apartment-walk takes a stage already raised, which is how wade hands over on the same
; screen, and apartment-run raises one. the music is three notes on a music box, g a c
; each a quarter tone flat, at an octave the die picks, every twenty seconds or so; the
; sound effects ride the same feed.
;
; run: love apartment    h j k l or the arrows walk, y u b n slant; q or esc leaves
(module (apartment apartment-run apartment-walk apartment-main apartment-new apartment-turn
         apartment-frame apartment-bar apartment-lay apartment-face apartment-stride
         apartment-stir chat chat-key chat-node chat-end chat-book blocks blocks-name
         cube-w cube-h river-h water-rate water-gap inside? oct-pt stone-lines apartment-song-new apartment-song-feed
         apartment-sfx phrase phrase-gap phrase-ring phrase-slow phrase-every phrase-vary phrase-first
         phrase-echoes drone-voice drone-notes song-chunk npc-glyph bones-glyph)
; posix is optional -- the page's seat (src/inle/wasm) links none of it and this file runs
; there, so ask before splicing: an absent module is a scare.
(? (cite 'posix) (borrow 'posix) ())
(borrow 'rove)
(borrow 'play)                          ; the voices, the mix; harp is cited, never borrowed
(:
 esc (string 27)
 ; --- the plain: tiles in a cask, (x y) indexed. 1 grass, 2 sand, 3 a path, 4 the river,
 ; 5 its bed once dry, 6 glass -- looked through and never entered -- 7 shards, where
 ; glass was, and 8 the stone in the bed
 cube-w 9                               ; a cube on a grid whose cells are twice as tall as wide
 cube-h 5
 river-h 3                              ; rows the river takes
 river-gap 1                            ; grass rows between a pair's pane and the river when it runs straight
 river-sway 2                           ; rows the river wanders either side of its middle
 ; the ground is half blocks, each half in a pen off its ramp by one still frame of the
 ; walk's shimmer (slop-drift), so the colour runs in smooth bands and not a mottle. the
 ; river alone reads the shimmer at the clock, so it runs while everything else stands;
 ; dry, its bed reads the still frame with the rest. the ramps run pale to deep; span is
 ; the band of the field they cover, its four sines seldom leaving +-3
 grass-ramp [118 112 76 70 40 34 28 22]
 sand-ramp [187 180 179 178 172 136 137 101]
 water-ramp [45 39 38 32 33 27 26 25]
 water-rate 0.6                         ; the river's drift, field time a second
 water-gap 100                          ; ms between frames while the river runs
 bed-ramp [180 179 137 136 95 94 58 58]        ; the bed dry: silt, browns
 road-ramp [137 95 94 94 58 58 52 52]          ; the shards lie on this
 path-ramp [180 137 137 95 94 94 58 58]
 stone-glyph "▄"                        ; the stone: a half block, grey, on the bed
 stone-pen 237
 ramp-span 3.0
 glass-face '("▒" 117)
 shard-glyph "░"                        ; ..on the road's brown: glass on the ground
 glass-pen 117
 npc-glyph "Ψ"
 npc-pen 53
 me-pen 228
 mob-pens '(250 245 252)                ; the others, greys
 bones-glyph 37                         ; % as the middle's bones are
 bones-pen 187
 blocks ["█" "▓" "▒" "░"]               ; the solid and shaded block elements a name is spelled in

 ; --- the words: every line the level says; a ~ takes the next value ---
 w-glass   "the glass holds"
 w-edge    "the desert goes on and on"
 w-east    "the river gives out to a dried up ocean"
 w-water   "the river is deep and quick"
 w-dry     "the river is flooded with dust"
 stone-ttl "a stone"
 stone-lines '("numbers etched into the stone:"
               "2016"
               "2023"
               "2026"
               ""
               "-- any key --")
 w-shatter "the pane shatters and the grass outside turns to sand."
 w-bar     "~  turn ~"
 open-ttl  "apartment"
 open-lines '("you wake up in your bedroom. someone else is here."
              ""
              "move     h j k l    or the arrow keys"
              "         y u b n    for diagonals"
              "leave    q          or esc"
              ""
              "-- any key --")
 ; what the stranger says: a node is its lines and its choices, a choice a key, its
 ; words and the node it leads to; a node with no choices closes, and closing is the
 ; end. a ~ is the stranger's name
 chat-book '((start ("~ presses a hand to the glass.")
                    ((1 "\"How long did you sleep?\"" how)
                     (2 "\"Where is this place?\"" here)
                     (3 "\"I found the river again.\"" river)
                     (4 "..." bye)))
             (how ("\"Almost seven hours.\" ~ looks confused.")
                  ((1 "\"Wait...\"" start)))
             (here ("\"Home.\"  ~ taps the side of their head.")
                   ((1 "\"Oh yeah.\"" start)))
             (river ("~ closes their eyes and smiles as if recalling a pleasant memory.")
                    ((1 "You feel the same way." start)))
             (bye ("~ turns away.")
                  ()))
 chat-foot "-- ~ --"

 ; --- laying the plain: grass end to end, eight cubes in an octagon about the middle,
 ; the river through the middle from off the map east to off the map west, and a
 ; path from each cube straight down or up to it ---
 ; a point of the octagon: k of eight, clockwise from the right of the top pair -- the
 ; octagon stands turned an eighth of a slice, a flat side up, as the vale's stones do
 ; -- and the eighth is the left of that pair. rx and ry are its reach, across and down
 (oct-pt cx cy rx ry k) (: a (k * 0.7853981633974483 - 1.1780972450961724)
                           c (cos a) s (sin a)
                           [(cx + int (rx * c + (0.0 < c ? 0.5 -0.5)))
                            (cy + int (ry * s + (0.0 < s ? 0.5 -0.5)))])
 ; a cube is [x0 y0 w h pane]: its corner, its size, and the cell of its glass the path
 ; leaves through -- the pane the stranger stands at, on yours. yours is the first, the
 ; left of the top pair; the rest follow clockwise from it
 (apartment-lay w h sb) (:
   d {'w w 'h h 't (cask (w * h)) 'seen (cask (w * h)) 'rooms () 'rows h 'cols w 'solid '(6 4)}
   _ (each ^(w * h) (i \ pin (d 't) i 1))
   cx (w // 2) cy (h // 2)
   ; the octagon's reach: down, what the plain has room for; across, twice that -- a
   ; cell is twice as tall as it is wide -- but at least enough to keep the pairs clear
   ; of each other, and no more than the plain has
   ry (cy - cube-h // 2 - 1)
   rx (min (cx - cube-w // 2 - 2) (max (2 * ry) (int ((cube-w + 2) / 0.5412 + 1))))
   (cube x0 y0) (each ^cube-h (j \ each ^cube-w (i \ dput d (x0 + i) (y0 + j)
                  (j = 0 || j = cube-h - 1 || i = 0 || i = cube-w - 1 ? 6 1))))
   ; a cube at its point: its corner, and the pane in the wall that faces the river. the
   ; pairs either side of the river stand off it by a row of grass at least, whatever
   ; the octagon says
   off (river-h // 2 + 1 + cube-h // 2 + river-gap)
   (cube-at k) (: j ((k + 7) % 8) pt (oct-pt cx cy rx ry j)
                  mx <pt my (elem j '(1 2 5 6) ? (<>pt < cy ? (cy - max off (cy - <>pt)) (cy + max off (<>pt - cy))) <>pt)
                  x0 (mx - cube-w // 2) y0 (my - cube-h // 2)
                  _ (cube x0 y0)
                  [x0 y0 cube-w cube-h (my < cy ? [mx (y0 + cube-h - 1)] [mx y0])])
   cubes (map cube-at ^8)
   c <cubes
   ; the river: through the middle, off the map east to off the map west, so many
   ; rows a column, its top row swaying a row or two on two sines the
   ; die phases -- and held a row of grass off anything that is not grass, eased there
   ; a row a column, so it runs straight past the pairs that stand beside it
   east (foldl (\ a cb (: e (cb 0 + cube-w - 1) (a < e ? e a))) 0 cubes)   ; the octagon's east edge
   n w
   mid (cy - river-h // 2)                                ; the top row when it runs straight
   p1 (roll sb 628 / 100.0) p2 (roll sb 628 / 100.0)
   f1 (0.1 + roll sb 9 / 100.0) f2 (0.035 + roll sb 26 / 1000.0)
   ; ..the sway dying away over a few columns toward any cube that stands near the river
   near (filter (cb \ cb 1 <= mid + river-h + river-sway && mid - river-sway - 1 < cb 1 + cube-h) cubes)
   (apart x cb) (: x0 (cb 0) x1 (cb 0 + cube-w - 1) (x < x0 ? (x0 - x) (x1 < x ? (x - x1) 0)))
   (ease x) (min 1.0 ((foldl (\ a cb (min a (apart x cb))) (4 * river-sway) near) / (4.0 * river-sway)))
   (sway x) (: v (ease x * river-sway * (0.65 * sin (f1 * x + p1) + 0.35 * sin (f2 * x + p2)))
               (int (v + (0.0 < v ? 0.5 -0.5))))
   ; grass from y stepping dy: how far, so far
   (run x y dy m) (:- (go 0) (go k) (: yy (y + dy * k) (k < m && 0 <= yy < h && 1 = dat d x yy ? (go (k + 1)) k)))
   lo (cask n) hi (cask n)                                ; the top row's bounds a column
   _ (each ^n (x \ (pin lo x (mid - max 0 (run x (mid - 1) -1 (river-sway + 1) - 1)),
                    pin hi x (mid + max 0 (run x (mid + river-h) 1 (river-sway + 1) - 1)))))
   _ (each ^(n - 1) (x \ (pin lo (x + 1) (max (peep lo (x + 1) mid) (peep lo x mid - 1)),
                          pin hi (x + 1) (min (peep hi (x + 1) mid) (peep hi x mid + 1)))))
   _ (each ^(n - 1) (k \ (: x (n - 2 - k)
                           (pin lo x (max (peep lo x mid) (peep lo (x + 1) mid - 1)),
                            pin hi x (min (peep hi x mid) (peep hi (x + 1) mid + 1))))))
   (river-y x) (min (peep hi x mid) (max (peep lo x mid) (mid + sway x)))
   _ (each ^n (x \ each ^river-h (j \ dput d x (river-y x + j) 4)))
   ; ..and each cube's path: straight down its middle column to the river, or up to it,
   ; from the pane -- a fibre
   _ (each cubes (cb \ (: pn (cb 4) mx <pn above (<>pn < cy)
                          ya (above ? (<>pn + 1) (river-y mx + river-h)) yb (above ? (river-y mx) <>pn)
                          (each ^(yb - ya) (j \ dput d mx (ya + j) 3)))))
   ; the stone in the bed near the west edge, midstream, under the water until it is dry
   stone [2 (river-y 2 + river-h // 2)]
   _ (dput d <stone <>stone 8)
   flow (cite 'slop 'slop-drift h w) phase (roll sb 1000 / 10.0)           ; where in the drift it stopped
   (pins d 'cubes cubes 'cube c 'hub [cx cy] 'east east 'stone stone 'sd (roll sb 1000000)
           'flow flow 'phase phase 'skin (flow phase 0.0)
           'in [(c 0 + cube-w // 2) (c 1 + cube-h // 2)]))
 ; strictly inside a cube: past its glass on every side
 (inside? c x y) (c 0 < x < c 0 + c 2 - 1 && c 1 < y < c 1 + c 3 - 1)

 ; a name: so many of the blocks, drawn one by one
 (blocks-name sb lo hi) (: n (lo + roll sb (hi - lo + 1))
                           (foldl (+) "" (map (i \ blocks (roll sb #blocks)) ^n)))

 ; a fresh level: the plain laid from the seed, you in the middle of your cube, the
 ; stranger on your path just past the pane, and someone in the middle of every other cube
 (toward a b) (a < b ? 1 (b < a ? -1 0))
 (apartment-new w h st) (:
   sb {st}
   d (apartment-lay w h sb) c (d 'cube) pane (c 4) hub (d 'hub)
   nm (blocks-name sb 3 6)
   p {'x <(d 'in) 'y <>(d 'in) 'gl 64 'hue me-pen}
   npc {'x (<pane + toward <pane <hub) 'y (<>pane + toward <>pane <>hub)
        'gl npc-glyph 'hue npc-pen 'nm nm}
   (mob cb) {'x (cb 0 + cube-w // 2) 'y (cb 1 + cube-h // 2) 'gl 64
             'hue (mob-pens (roll sb #mob-pens)) 'cube cb}
   g {'d d 'sb sb 'p p 'npc npc 'ms (map mob >(d 'cubes)) 'pane (<pane + w * <>pane)
      'msg "" 'tn 0 'over 0 'sign () 'talk () 'sfx () 'desert 0 'wt 0.0}
   _ (pin g 'sign (open-ttl . open-lines))
   g)

 ; --- the talk: the tree's node as a sign, a key as its answer -----------------------
 (chat-node k) (: (go (e . u)) (<e @ ^k e (go u)) (go chat-book))
 ; a choice's line is marked off between the bytes 1 and 2, which fit paints as a button
 (choice-line c) (string 1 + " " + show <c + "  " + c 1 + " " + string 2)
 (chat g k) (: nd (chat-node k) nm (g 'npc 'nm)
               txt (map (l \ fill l [nm]) (nd 1)) chs (nd 2)
               ks (map (show * cap) chs)
               lines (txt + (two? chs ? [""] ()) + map choice-line chs
                      + ["" (fill chat-foot [(two? chs ? (join ", " ks) "any key")])])
               (pins g 'talk k 'sign (nm . lines)))
 ; a digit picks its choice, anything else at a node with choices shows it again, and a
 ; node without them closes -- and that is the end of the talk
 (chat-key g k) (: nd (chat-node (g 'talk)) chs (nd 2)
                   (atom? chs ? (chat-end g)
                    (: c (filter (c \ 48 + <c = k) chs)
                       (chat g (two? c ? (<c 2) (g 'talk))))))
 ; the end: the stranger gone, the pane to shards, a drum, the others bones where they
 ; stood, every blade of grass past your cube's glass to sand, and the river dry
 (chat-end g) (: d (g 'd) w (d 'w) c (d 'cube)
                 _ (pins g 'talk () 'sign () 'npc () 'desert 1 'sfx ('drum . g 'sfx))
                 _ (each (g 'ms) (m \ pins m 'gl bones-glyph 'hue bones-pen 'bones 1))
                 _ (pin (d 't) (g 'pane) 7)
                 _ (each ^(w * d 'h) (j \ (: t (peep (d 't) j 0)
                                            (? (1 = t && !(inside? c (j % w) (j // w))) (pin (d 't) j 2)
                                               (4 = t) (pin (d 't) j 5)))))
                 (note g w-shatter))

 stride-msgs
 {2 '("the sand burns your feet" "a sharp wind blows dust in your eyes" "a distant hum makes you dizzy and nauseous")
  5 '("smooth stones line the riverbed" "on the bank lie bones half buried under thick silt")
  7 '("you step carefully over the fragments")}

 ; --- a turn: a sign standing takes the key, else a step ------------------------------
 ; bumping the pane the stranger stands at opens the talk; any other glass holds, the
 ; river does, and the plain's edge does too -- but for the west edge along the dry
 ; bed, which is the way out. a step onto the stone reads it
 (apartment-stride g mv) (: p (g 'p) d (g 'd) ox (p 'x) oy (p 'y)
                            nx (ox + <mv) ny (oy + <>mv)
                            i (nx + d 'w * ny) t (dat d nx ny) npc (g 'npc)
   (? (npc && nx = npc 'x && ny = npc 'y) (chat g 'start)
      (t = 6) (npc && i = g 'pane ? (chat g 'start) (note g w-glass))
      (t = 4) (note g w-water)
      (nx < 0 && 5 = dat d 0 ny) (pin g 'over 'west)
      !(open? d nx ny) (note g (dat d ox oy = 5 ? w-east w-edge))
      (: _ (pins p 'x nx 'y ny)
         _ (stride-msgs t @ () () l
            (: sb (g 'sb) (roll sb 8 @ 0 (note g (l $ roll sb #l)))))
         (? (t = 8) (pin g 'sign (stone-ttl . stone-lines))
            (t = 5 && dat d ox oy < 4) (note g w-dry)))))
 ; ..and the others wander their cubes a step a turn, over grass alone, while they can
 (apartment-stir g) (: d (g 'd) sb (g 'sb)
   (taken? x y) (any (m \ m 'x = x && m 'y = y) (g 'ms))
   (stir m) (: nx (m 'x + roll sb 3 - 1) ny (m 'y + roll sb 3 - 1)
               (? (1 = dat d nx ny && !(taken? nx ny)) (pins m 'x nx 'y ny)))
   (each (g 'ms) (m \ (m 'bones ? () (stir m)))))
 (apartment-turn g k) (:
   _ (pins g 'msg "" 'tn (1 + g 'tn))
   sg (g 'sign)
   _ (? sg (g 'talk ? (chat-key g k) (pin g 'sign ()))
        (g 'over) ()
        (two? k) (apartment-stride g k, apartment-stir g)
        ())
   g)

 ; --- the frame: the plain's faces, the note, the bar, and a sign over it all ---------
 ; a ground cell is a block in its ramp's pen at the skin's value there, so grass and
 ; the sand it turns to share one grain and the road runs through the same bands; the
 ; water reads the skin further along, by the clock (wt, seconds), until it is off
 (ramp-pen rp v) (cite 'slop 'slop-ramp-pen rp ramp-span v)
 (apartment-face g) (: d (g 'd) w (d 'w) sk (d 'skin)
   wet (g 'desert ? sk (d 'flow (d 'phase + water-rate * g 'wt) 0.0))
   ents (filter tablet? ((g 'p) . (g 'npc) . g 'ms))
   spot (foldl (\ t e (pin t (e 'x + w * e 'y) e)) {} ents)
   (ramp-of t) (t @ 1 grass-ramp 2 sand-ramp 3 path-ramp 4 water-ramp 5 bed-ramp 8 (g 'desert ? bed-ramp water-ramp) ())
   ; the ground is slop's skin as half blocks; what stands on it stands on the lower half
   (skin-of rp) (? (rp = water-ramp) wet sk)
   (ground-pen rp x y) (cite 'slop 'slop-under (skin-of rp) (ramp-pen rp) x y)
   ; a mob on a block wears the block's colour under it, its own over -- or its inverse
   ; where the two would not tell apart; on glass it stands on nothing
   (\ i (: e (spot i) x (i % w) y (i // w) t (peep (d 't) i 0) rp (ramp-of t)
           (? (e && rp) (: bg (ground-pen rp x y) [(e 'gl) [(legible (e 'hue) bg) bg]])
              e [(e 'gl) (e 'hue)]
              (t = 8 && g 'desert) [stone-glyph [stone-pen (ground-pen rp x y)]]   ; the stone, once the water is off it
              rp (cite 'slop 'slop-face (skin-of rp) (ramp-pen rp) x y ())
              (t = 7) [shard-glyph [glass-pen (ground-pen road-ramp x y)]]
              (t @ 6 glass-face '(32 0))))))
 (apartment-bar g) (fill w-bar [(g 'desert ? "the desert" "the plain") (g 'tn)])
 (apartment-frame g) (: d (g 'd) rows (d 'rows) cols (d 'cols)
   f (:- (slurp j) j (paint (jug 0) d (apartment-face g) (g 'msg) (apartment-bar g)))
   sg (g 'sign)
   _ (pin d 'box (two? sg ? (sign-rect <sg >sg 1 rows cols) ()))
   (two? sg ? (sign-over f <sg >sg 1 rows cols) f))

 ; --- the song: a chunk out the card at a time, the river's way. the tune is a phrase
 ; on a music box -- g a c, each a quarter tone flat, in semitones from middle c -- at an
 ; octave the die picks, every so many seconds give or take a few, the first soon after
 ; the start; the lower the octave the slower it goes and the longer each note rings,
 ; and each note comes back a few times, softer and later, off the plain. under it all
 ; a drone, the phrase's c and its g two octaves down, swelling and wavering slowly.
 ; the sound effects ride the same feed, put in at the write head so they sound in the
 ; next chunk
 song-chunk (song-rate // 30)
 song-gain 5200.0
 phrase [-5.5 -3.5 -12.5]
 phrase-gap 1.2                         ; seconds from one note of it to the next
 phrase-ring 3.0                        ; ..and how long a note takes to die away
 phrase-slow 1.2                        ; ..both by this much more for each octave down, less for each up
 phrase-every 17                        ; seconds between phrases..
 phrase-vary 3                          ; ..give or take up to this many
 phrase-first 2
 phrase-octaves 3                       ; the octave: one of this many, about middle c's
 phrase-echoes '((0.09 0.45) (0.21 0.28) (0.37 0.16))   ; a note's returns: seconds behind it, and how loud
 drone-notes [-24.5 -17.5]              ; the phrase's c and g, two octaves under middle c's, flat as they are
 drone-gain 2.22
 drone-swell 0.05                       ; the undulation, in cycles a second..
 drone-swell-depth 0.35                 ; ..and how much of the drone it takes away at its ebb
 drone-waver 0.3                        ; the pitch's wander, in cycles a second..
 drone-waver-depth 2.0                  ; ..and its reach, in radians of phase
 ; the drone is a voice like the box's -- a function from a tray of frame numbers to a
 ; tray of amplitudes -- with no end frame it will ever reach: the two notes summed, the
 ; phase pushed slowly to and fro for the waver, the whole scaled by the slow swell
 (drone-voice _) (: fs (map (n \ 261.6255653005986 * exp (n * ln2-12)) drone-notes)
                    (fn ix) (: t (ix * (1.0 / song-rate))
                               ph (sin (t * twopi * drone-waver) * drone-waver-depth)
                               sw (1.0 - drone-swell-depth * (0.5 + 0.5 * sin (t * twopi * drone-swell)))
                               ((foldl (\ acc f (acc + sin (t * twopi * f + ph))) (t * 0.0) fs) * (sw / #fs)))
                    [1099511627776 fn (drone-gain * 0.5) (drone-gain * 0.5)])
 (apartment-song-new h st) {'h h 'fpos 0 'vs [(drone-voice ())] 'sb {st}
                            'next (phrase-first * song-rate) 'struck 0}
 (strike! s at v) (pin s 'vs (s 'vs + [(mkvoice at v song-rate)]))
 ; a note and its echoes, each a voice of its own
 (note! s at v) (: _ (strike! s at v)
                   (each phrase-echoes (e \ strike! s (at + int (<e * song-rate)) (pin (pins {} 's (v 's) 'note (v 'note) 'legato (v 'legato)) 'gain (v 'gain * e 1)))))
 (phrase! s) (: sb (s 'sb) base (s 'fpos)
                (rr sb lr) (roll sb phrase-octaves @ ^lr (rr sb lr) nr nr)
                nr (rr sb (s 'lr))
                o (nr - phrase-octaves // 2)
                oct (12.0 * o)
                slow (-o phrase-slow)                       ; phrase-slow to the -o
                _ (each ^#phrase (i \ note! s (base + int (i * phrase-gap * slow * song-rate))
                                         {'s "box" 'note (phrase i + oct) 'gain 0.7 'legato (phrase-ring * slow)}))
                (pins s 'struck (s 'struck + 1) 'lr nr
                        'next (base + song-rate * (phrase-every - phrase-vary + roll sb (2 * phrase-vary + 1)))))
 ; the drum: a kick and a snare together, and the snare's crack again a beat behind
 (apartment-sfx s g) (: fx (g 'sfx)
                        (at k v) (mkvoice (s 'fpos + int (k * song-rate)) v song-rate)
                        (drum _) [(at 0.0 {'s "bd" 'gain 0.9}) (at 0.0 {'s "sn" 'gain 0.6})
                                  (at 0.12 {'s "sn" 'gain 0.3 'speed 1.4})]
                        vs (foldl (\ acc f (f @ 'drum (cat acc (drum ())) acc)) () fx)
                        _ (pin g 'sfx ())
                        (pin s 'vs (s 'vs + filter two? vs)))
 (apartment-song-feed s) (:
   _ (? (s 'next <= s 'fpos + song-chunk) (phrase! s))
   base (s 'fpos)
   live (filter (v \ v 0 >= base) (s 'vs))
   _ (pins s 'vs live 'fpos (base + song-chunk))
   (say (s 'h) (pack (mixdown live base song-chunk) song-chunk song-gain)))

 ; --- the walk: on a stage already raised, the tower's way -- the wait is the song ---
 (apartment-walk _) (: ws (tty 1)
   r (two? ws && 7 < <ws ? (<ws - 2) 22)
   c (two? ws && 19 < <>ws ? <>ws 80)
   g (apartment-new (c < 100 ? c 100) r (wheel (clock 0)))
   ; the card, if this seat has one: no horn and the level is quiet
   hn (: q (horn song-rate 2) (? (nom? q) () q))
   sng (? hn (apartment-song-new hn (wheel (clock 0))) ())
   pace (pacer ())
   (feed! _) (? (horn-lag hn < song-lead-of (pace! pace)) (apartment-song-feed sng) (rest 5))
   (idle _) (? sng (feed! ()) (rest 30))
   ; escape at a standing sign takes the sign down and nothing else; the talk is left,
   ; not ended, and a bump opens it again
   (turn k) (? (k = 27 && g 'sign) (pins g 'sign () 'talk ())
               (k @ (113 || 27 || -7) (pin g 'over 'fled)
                (apartment-turn g (steer k))))
   ; a key, or none when the river is due another frame
   (wait t0 last gap due) (? (cue? 0)
                             (: k (edkey in)
                                (k = last && (clock 0 - t0) < gap ? (wait t0 last gap due) k))
                             (due <= clock 0) ()
                             (idle (), wait t0 last gap due))
   t00 (clock 0)
   (loop last t0) (? (g 'over) ()
                     (: _ (pin g 'wt ((clock 0 - t00) / 1000.0))
                        _ (say out (apartment-frame g), flush out)
                        k (wait t0 last (g 'sign ? sign-gap repeat-gap) (clock 0 + water-gap))
                        _ (? (two? k || charm? k) (turn k))
                        _ (? sng (apartment-sfx sng g) (pin g 'sfx ()))
                        (loop (k ? k last) (k ? (clock 0) t0))))
   _ (say out (esc + "[2J"))
   _ (loop 0 0)
   ; ..and the card goes back before the next level asks for it
   _ (? hn (flush hn, close hn))
   ; west along the dry bed: the dusk takes the stage as it stands and gives it back
   ; here; a seat that carries no dusk ends at the edge
   next (cite 'dusk 'dusk-walk)
   _ (? (g 'over = 'west && next) (next ()))
   g)
 ; ..and the verb around it: the screen raised here and put back here
 (apartment-run _) (: _ (raw 1)
   _ (say out (esc + "[?1049h" + esc + "[?25l"))
   g (apartment-walk ())
   _ (say out (esc + "[0m" + esc + "[?25h" + esc + "[?1049l"), flush out)
   _ (drain-keys ())
   _ (raw 0)
   0)
 apartment-usage "usage: love apartment   (h j k l or the arrows walk, y u b n slant; q or esc leaves)"
 (apartment-main as) (as @ () (apartment-run ())
                           (say err ("apartment: " + apartment-usage + "\n"), flush err, 2))
 _ (pins (cite 'verbs 'tab) 'apartment (udoor 'apartment apartment-main apartment-usage 1 1)))
) ; module apartment
