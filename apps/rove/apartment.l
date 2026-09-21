; apartment -- the level after the river: you come to inside a glass cube on a grassy
; plain, one of eight standing in an octagon, a flat side up, yours the left of the top
; pair; each has a path in to the octagon's middle, where the road runs off the map to
; the west, and no way out. someone is in every other cube, wandering. a stranger stands
; outside against your glass, named in blocks and greeting you in blocks, and you talk
; through the pane. when the talk is done the stranger is gone, the pane shatters to a
; drum, the others are bones where they stood, and the grass past the glass goes over
; to desert -- the grass inside stays -- and the plain is yours to walk.
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
; screen, and apartment-run raises one. no music yet: the song is the tower's shape with
; no bars in it, carrying the sound effects, and apartment-bars is where a tune goes.
;
; run: love apartment    h j k l or the arrows walk, y u b n slant; q or esc leaves
(module (apartment apartment-run apartment-walk apartment-main apartment-new apartment-turn
         apartment-frame apartment-bar apartment-lay apartment-face apartment-stride
         apartment-stir chat chat-key chat-node chat-end chat-book blocks blocks-name
         cube-w cube-h road-h inside? oct-pt apartment-song-new apartment-song-feed
         apartment-sfx apartment-tune apartment-bars song-chunk npc-glyph bones-glyph)
; posix is optional -- the page's seat (inle/wasm) links none of it and this file runs
; there, so ask before splicing: an absent module is a scare.
(? (cite 'posix) (borrow 'posix) ())
(borrow 'rove)
(borrow 'ink)                           ; the shimmer, one frame of it held still, for the ground's grain
(borrow 'play)                          ; the voices, the mix; harp is cited, never borrowed
(:
 esc (string 27)
 ; --- the plain: tiles in a cask, (x y) indexed. 1 grass, 2 sand, 3 a path, 4 the road,
 ; 6 glass -- looked through and never entered -- and 7 shards, where glass was
 cube-w 9                               ; a cube on a grid whose cells are twice as tall as wide
 cube-h 5
 road-h 1                               ; the road is a row: the octagon's west pair leave it one
 ; the ground is solid blocks, each in a pen off its ramp by one still frame of the
 ; walk's shimmer (ink-drift), so the colour runs in smooth bands and not a mottle. the
 ; ramps run pale to deep; span is the band of the field they cover, its four sines
 ; seldom leaving +-3
 ground-glyph "█"
 grass-ramp [118 112 76 70 40 34 28 22]
 sand-ramp [187 180 179 178 172 136 137 101]
 road-ramp [137 95 94 94 58 58 52 52]
 path-ramp [180 137 137 95 94 94 58 58]
 ramp-span 3.0
 glass-face '("▒" 117)
 shard-glyph "░"                        ; ..on the road's brown: glass on the ground
 glass-pen 117
 npc-glyph "Ψ"
 npc-pen 213
 me-pen 228
 mob-pens '(250 245 252)                ; the others, greys
 bones-glyph 37                         ; % as the middle's bones are
 bones-pen 187
 blocks ["█" "▓" "▒" "░"]               ; the solid and shaded block elements a name is spelled in

 ; --- the words: every line the level says; a ~ takes the next value ---
 w-glass   "the glass holds"
 w-edge    "the plain goes on and on"
 w-shatter "the pane bursts into a thousand pieces, and the grass beyond it goes to sand"
 w-bar     "~  turn ~"
 open-ttl  "apartment"
 open-lines '("you come to inside a glass cube on a plain.  someone is standing outside."
              ""
              "move     h j k l    or the arrow keys"
              "         y u b n    for diagonals"
              "leave    q          or esc"
              ""
              "-- any key --")
 ; what the stranger says: a node is its lines and its choices, a choice a key, its
 ; words and the node it leads to; a node with no choices closes, and closing is the
 ; end. a ~ is the stranger's name; the greeting goes in front of the first node
 chat-book '((start ("The stranger presses a hand to the glass.")
                    ((1 "Who are you?" who)
                     (2 "Where is this?" here)
                     (3 "..." bye)))
             (who ("\"~.\"")
                  ((1 "Ok." start)))
             (here ("\"Home.\"  ~ taps the pane.")
                   ((1 "Oh." start)))
             (bye ("~ turns away.")
                  ()))
 chat-foot "-- ~ --"

 ; --- laying the plain: grass end to end, eight cubes in an octagon about the middle,
 ; a path from each in to the hub, and the road west from the hub off the map ---
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
   d {'w w 'h h 't (cask (w * h)) 'seen (cask (w * h)) 'rooms () 'rows h 'cols w 'solid '(6)}
   _ (each ^(w * h) (i \ pin (d 't) i 1))
   cx (w // 2) cy (h // 2)
   rx (cx - cube-w // 2 - 2) ry (cy - cube-h // 2 - 1)
   _ (each ^(cx + 1) (x \ each ^road-h (j \ dput d x (cy + j) 4)))
   (cube x0 y0) (each ^cube-h (j \ each ^cube-w (i \ dput d (x0 + i) (y0 + j)
                  (j = 0 || j = cube-h - 1 || i = 0 || i = cube-w - 1 ? 6 1))))
   ; the cells from one point to another, a step at a time along the longer axis
   (line x0 y0 x1 y1) (: n (max |(x1 - x0) |(y1 - y0))
                         (part dv i) (: v (dv * i) ((v + (0 < v ? n // 2 (0 - n // 2))) // n))
                         (at i) [(x0 + part (x1 - x0) i) (y0 + part (y1 - y0) i)]
                         (0 < n ? (map at ^(n + 1)) [[x0 y0]]))
   ; a cube at its point, and its path: the line from its middle to the hub leaves
   ; through one cell of its glass, the pane, and is dirt from there in, over grass alone
   (lay k) (: pt (oct-pt cx cy rx ry ((k + 7) % 8))
              mx <pt my <>pt x0 (mx - cube-w // 2) y0 (my - cube-h // 2)
              _ (cube x0 y0)
              ln (line mx my cx cy)
              pane <(filter (q \ 6 = dat d <q <>q) ln)
              _ (each ln (q \ (? (1 = dat d <q <>q && !(x0 <= <q < x0 + cube-w && y0 <= <>q < y0 + cube-h))
                                  (dput d <q <>q 3))))
              [x0 y0 cube-w cube-h pane])
   cubes (map lay ^8)
   c <cubes
   (pins d 'cubes cubes 'cube c 'hub [cx cy] 'sd (roll sb 1000000)
           'skin (ink-drift h w (roll sb 1000 / 10.0) 0.0)   ; where in the drift it stopped
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
   nm (blocks-name sb 3 6) gr (blocks-name sb 5 10)
   p {'x <(d 'in) 'y <>(d 'in) 'gl 64 'hue me-pen}
   npc {'x (<pane + toward <pane <hub) 'y (<>pane + toward <>pane <>hub)
        'gl npc-glyph 'hue npc-pen 'nm nm 'greet gr}
   (mob cb) {'x (cb 0 + cube-w // 2) 'y (cb 1 + cube-h // 2) 'gl 64
             'hue (mob-pens (roll sb #mob-pens)) 'cube cb}
   g {'d d 'sb sb 'p p 'npc npc 'ms (map mob >(d 'cubes)) 'pane (<pane + w * <>pane)
      'msg "" 'tn 0 'over 0 'sign () 'talk () 'sfx () 'desert 0}
   _ (pin g 'sign (open-ttl . open-lines))
   g)

 ; --- the talk: the tree's node as a sign, a key as its answer -----------------------
 (chat-node k) (: (go (e . u)) (<e @ ^k e (go u)) (go chat-book))
 (joins-with sp l) (? (one? l) "" (one? >l) <l (<l + sp + joins-with sp >l))
 ; a choice's line is marked off between the bytes 1 and 2, which fit paints as a button
 (choice-line c) (string 1 + " " + show <c + "  " + c 1 + " " + string 2)
 (chat g k) (: nd (chat-node k) nm (g 'npc 'nm)
               txt (map (l \ fill l [nm]) (nd 1)) chs (nd 2)
               head (k = 'start ? [("\"" + g 'npc 'greet + "\"")] ())
               ks (map (show * cap) chs)
               lines (head + txt + (two? chs ? [""] ()) + map choice-line chs
                      + ["" (fill chat-foot [(two? chs ? (joins-with ", " ks) "any key")])])
               (pins g 'talk k 'sign (nm . lines)))
 ; a digit picks its choice, anything else at a node with choices shows it again, and a
 ; node without them closes -- and that is the end of the talk
 (chat-key g k) (: nd (chat-node (g 'talk)) chs (nd 2)
                   (one? chs ? (chat-end g)
                    (: c (filter (c \ 48 + <c = k) chs)
                       (chat g (two? c ? (<c 2) (g 'talk))))))
 ; the end: the stranger gone, the pane to shards, a drum, the others bones where they
 ; stood, and every blade of grass past your cube's glass to sand
 (chat-end g) (: d (g 'd) w (d 'w) c (d 'cube)
                 _ (pins g 'talk () 'sign () 'npc () 'desert 1 'sfx ('drum . g 'sfx))
                 _ (each (g 'ms) (m \ pins m 'gl bones-glyph 'hue bones-pen 'bones 1))
                 _ (pin (d 't) (g 'pane) 7)
                 _ (each ^(w * d 'h) (j \ (? (1 = peep (d 't) j 0 && !(inside? c (j % w) (j // w)))
                                             (pin (d 't) j 2))))
                 (note g w-shatter))

 ; --- a turn: a sign standing takes the key, else a step ------------------------------
 ; bumping the pane the stranger stands at opens the talk; any other glass holds, and
 ; the plain's edge does too
 (apartment-stride g mv) (: p (g 'p) d (g 'd) nx (p 'x + <mv) ny (p 'y + <>mv)
                            i (nx + d 'w * ny) t (dat d nx ny) npc (g 'npc)
   (? (npc && nx = npc 'x && ny = npc 'y) (chat g 'start)
      (t = 6) (npc && i = g 'pane ? (chat g 'start) (note g w-glass))
      !(open? d nx ny) (note g w-edge)
      (pins p 'x nx 'y ny)))
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
 ; the sand it turns to share one grain and the road runs through the same bands
 (ramp-pen rp v) (: m (#rp - 1)
                    n (int (((v + ramp-span) * #rp) / (2.0 * ramp-span)))
                    (rp (? (n < 0) 0 (m < n) m n)))
 (apartment-face g) (: d (g 'd) w (d 'w) sk (d 'skin)
   ents (filter tablet? ((g 'p) . (g 'npc) . g 'ms))
   spot (foldl (\ t e (pin t (e 'x + w * e 'y) e)) {} ents)
   (ramp-of t) (t @ 1 grass-ramp 2 sand-ramp 3 path-ramp 4 road-ramp ())
   (ground-pen rp x y) (ramp-pen rp (peep sk [y x] 0.0))
   ; a mob on a block wears the block's colour under it, its own over -- or its inverse
   ; where the two would not tell apart; on glass it stands on nothing
   (\ i (: e (spot i) x (i % w) y (i // w) t (peep (d 't) i 0) rp (ramp-of t)
           (? (e && rp) (: bg (ground-pen rp x y) [(e 'gl) [(legible (e 'hue) bg) bg]])
              e [(e 'gl) (e 'hue)]
              rp [ground-glyph (ground-pen rp x y)]
              (t = 7) [shard-glyph [glass-pen (ground-pen road-ramp x y)]]
              (t @ 6 glass-face '(32 0))))))
 (apartment-bar g) (fill w-bar [(g 'desert ? "the desert" "the plain") (g 'tn)])
 (apartment-frame g) (: d (g 'd) rows (d 'rows) cols (d 'cols)
   f (:- (slurp j) j (paint (jug 0) d (apartment-face g) (g 'msg) (apartment-bar g)))
   sg (g 'sign)
   _ (pin d 'box (two? sg ? (sign-rect <sg >sg 1 rows cols) ()))
   (two? sg ? (sign-over f <sg >sg 1 rows cols) f))

 ; --- the song: the tower's shape, a chunk out the card at a time, with no bars in it
 ; yet -- apartment-bars is where the tune goes: a list of bars sounded together, each
 ; slots across one cycle, a slot a voice tablet or () for silence. the sound effects
 ; ride the same feed, put in at the write head so they sound in the next chunk
 song-cps 0.5
 song-chunk (song-rate // 30)
 song-gain 5200.0
 (apartment-bars c) ()
 (apartment-tune c) (: hush (cite 'harp 'hush) pure (cite 'harp 'pure)
                       fastcat (cite 'harp 'fastcat) stack (cite 'harp 'stack)
                       (bar sl) (fastcat (map (v \ (tablet? v ? (pure v) hush)) sl))
                       bars (apartment-bars c)
                       (two? bars ? (stack (map bar bars)) hush))
 (apartment-song-new h) {'h h 'fpos 0 'cyc 0 'next 0 'vs ()}
 ; the drum: a kick and a snare together, and the snare's crack again a beat behind
 (apartment-sfx s g) (: fx (g 'sfx)
                        (at k v) (mkvoice (s 'fpos + int (k * song-rate)) v song-rate)
                        (drum _) [(at 0.0 {'s "bd" 'gain 0.9}) (at 0.0 {'s "sn" 'gain 0.6})
                                  (at 0.12 {'s "sn" 'gain 0.3 'speed 1.4})]
                        vs (foldl (\ acc f (f @ 'drum (cat acc (drum ())) acc)) () fx)
                        _ (pin g 'sfx ())
                        (pin s 'vs (s 'vs + filter two? vs)))
 (apartment-song-feed s) (:
   spc (int (song-rate / song-cps))
   (ahead _) (? (s 'next <= s 'fpos + song-chunk)
                (: p (apartment-tune (s 'cyc))
                   _ (pin s 'vs (cat (s 'vs) (cyc-voices p (s 'cyc) 0 spc song-rate)))
                   _ (pins s 'cyc (s 'cyc + 1) 'next (s 'next + spc))
                   (ahead ())))
   _ (ahead ())
   base (s 'fpos)
   live (filter (v \ v 0 >= base) (s 'vs))
   _ (pins s 'vs live 'fpos (base + song-chunk))
   (say (s 'h) (pack (mixdown live base song-chunk) song-chunk song-gain)))

 ; --- the walk: on a stage already raised, the tower's way -- the wait is the song ---
 (apartment-walk _) (: ws (tty 1)
   r (two? ws && 7 < <ws ? (<ws - 2) 22)
   c (two? ws && 19 < <>ws ? <>ws 80)
   g (apartment-new (c < 100 ? c 100) r (wheel (clock 0)))
   ; the card, if this seat has one: no harp or no horn and the level is quiet
   hn (? (tablet? (cite 'harp)) (: q (horn song-rate 2) (? (nom? q) () q)) ())
   sng (? hn (apartment-song-new hn) ())
   pace (pacer ())
   (feed! _) (? (horn-lag hn < song-lead-of (pace! pace)) (apartment-song-feed sng) (rest 5))
   (idle _) (? sng (feed! ()) (rest 30))
   ; escape at a standing sign takes the sign down and nothing else; the talk is left,
   ; not ended, and a bump opens it again
   (turn k) (? (k = 27 && g 'sign) (pins g 'sign () 'talk ())
               (k @ (113 || 27 || -7) (pin g 'over 'fled)
                (apartment-turn g (steer k))))
   (loop last t0) (? (g 'over) ()
                     (: _ (say out (apartment-frame g), flush out)
                        k (key-wait t0 last (g 'sign ? sign-gap repeat-gap) idle)
                        _ (turn k)
                        _ (? sng (apartment-sfx sng g) (pin g 'sfx ()))
                        (loop k (clock 0))))
   _ (say out (esc + "[2J"))
   _ (loop 0 0)
   _ (? hn (flush hn, close hn))
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
