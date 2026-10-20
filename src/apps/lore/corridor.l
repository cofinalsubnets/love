; corridor -- an indoor level in first person, its rooms read from a level file and read
; again whenever the file changes, so a level can be edited beside the running game.
; a level is a love file in scenery.l's words, its last form (level NAME PART ..); a texture
; is made from its recipe (swatch.l), and a surface no texture names is a grid.
; nothing outside: every light is a lamp (mesh.l), baked once into a channel and summed each
; frame by how bright it is just then. corridor-read, -new, -step, -move and -frame are pure;
; corridor-watch reads the disk, and only corridor-walk and corridor-run touch the tty.
(module (corridor corridor-run corridor-walk corridor-main corridor-new corridor-size corridor-step corridor-binds corridor-pick corridor-span corridor-scene
         edit-new edit-events edit-paint edit-lay edit-main edit-outline corridor-ray
         corridor-move corridor-frame corridor-pens corridor-opts corridor-read corridor-load
         corridor-watch corridor-free? corridor-ks corridor-sound motes-at fps eye-h body-r grav-n)
(borrow 'rove)                          ; pad, for the bottom row
(borrow 'posix)                         ; open, close and stat, for the level and its pictures
(borrow 'view)                          ; the screen, the pens, the hash, the loop
(borrow 'window)                        ; the editor's own window
(borrow 'vec)                           ; triples
(borrow 'mesh)                          ; the triangles, the lamps, the frame
(borrow 'neon)                          ; the signs, and the poster's letters
(borrow 'brush)                         ; the world, carved and filled
(borrow 'swatch)                        ; the textures, from their recipes
(borrow 'flicker)                       ; how the lights stammer, buzz and breathe
(borrow 'walk)                          ; the keys, and a step slid along a wall
(borrow 'mixer)                         ; the sounds, mixed into the horn
(borrow 'sky)                           ; the sun, its light, the sky's colour
(:
 fps 30
 eye-h 1.6 body-r 0.25
 walk-v 3.4 turn-v 2.0 tilt-v 1.2         ; metres, and radians, a second
 ball-r 0.12 ball-e 0.72 ball-g 9.8 ball-kick 2.6  ; a ball: its radius, its bounce, the fall, the least kick
 door-v 1.4 door-near 2.4 door-t 0.03     ; the doors: their pace, how near opens one, half their thickness
 grav-v 1.4 grav-n 60                    ; a grav shaft: how fast it carries, its motes
 car-t 0.08 car-wait 0.6 car-hold 1.5 car-acc 1.2  ; a car: its walls' thickness, the seconds before its door
                                                  ; opens and after it shuts, how fast it gathers speed
 chunk-m 8.0 cell 0.25 cell-top 2.0                   ; how fine the surfaces are cut near a lamp, for the
                                          ; light, and how coarse far from every one
 watch-every 10                           ; frames between looks at the files
 the-level "src/apps/lore/levels/hall.l"
 ; --- the level, read: (corridor-read s) runs a level file's text into a tablet {'name 'start
 ;     'rooms 'doors 'strips 'bulbs 'posters 'signs 'brushes 'textures}, or a string saying why not ---
 ; ..a brush with no inside: a box flat in some direction, a prism no height
 (empty? r) (: sh (r 'shape)
   (sh 'box @ () (: p (sh 'prism) (p 1 - p 0 < 1e-6)) b (any (k \ b 1 k - b 0 k < 1e-6) ^3)))
 ; ..a scare raised by a word given what it does not take says what it takes; any other is
 ; love's own
 (corridor-read s) (: r (trap (_ \ (sounds s @ 'torn ['torn]
                                       ds (foldl (\ a d (ev 'ev d)) (ev 'ev '(borrow 'scenery)) (src-last ds))))
                             () (\ a b ['scare a b]))
   (? (tablet? r) (r 'kind = 'level ? (check r) "the file's last form should be (level NAME PART ..)")
      (two? r && <r = 'scare) (r 1 = 'level ? (r 2) ";; \(r 1) \(r 2)")
      (two? r && <r = 'torn) "a form is not finished: a ( without its )"
      "the file's last form should be (level NAME PART ..)"))
 ; ..the level's last form, each of its parts told its path down the source: the part's
 ; place in (level ..), and in a repeat's or mirror's list of parts the place there too
 (src-form p f) (: n (#f - 1) l (two? f ? (f n) ())
   (? (two? f && elem <f ['mirror-x 'mirror-z 'repeat] && two? l && <l = 'list)
      ['sourced ('list . p) (take n f + [('list . map (j \ src-form (p + [n j]) (l j)) (drop 1 ^#l))])]
      (two? f) ['sourced ('list . p) f]
      f))
 (src-last ds) (: r (rev ds) d (two? r ? <r ())
   (two? d && <d = 'level ? (rev ((take 2 d + map (k \ src-form [k] (d k)) (drop 2 ^#d)) . >r)) ds))
 ; ..a source path's text: [from to] in s, or () where s has no such form. the text read as
 ; the reader reads it, bracketed forms, strings and atoms, a [..]'s first part its second
 ; as (list ..)'s is
 (sx-skip s i) (? (i >= #s) i (elem (s i) [32 9 10 13]) (sx-skip s (i + 1))
                  (s i = 59) (sx-skip s (sx-eol s i)) i)
 (sx-eol s i) (? (i >= #s || s i = 10) i (sx-eol s (i + 1)))
 (sx-end s i) (: c (s i)
   (? (elem c [40 91 123]) (sx-close s (i + 1))
      (c = 34) (sx-str s (i + 1))
      (elem c [39 96 44]) (sx-end s (sx-skip s (i + 1)))
      (sx-atom s i)))
 (sx-close s i) (: j (sx-skip s i) (? (j >= #s) j (elem (s j) [41 93 125]) (j + 1) (sx-close s (sx-end s j))))
 (sx-str s i) (? (i >= #s) i (s i = 92) (sx-str s (i + 2)) (s i = 34) (i + 1) (sx-str s (i + 1)))
 (sx-atom s i) (? (i >= #s || elem (s i) [32 9 10 13 40 41 91 93 123 125 34 59]) i (sx-atom s (i + 1)))
 (sx-kids s i) (: (go j acc) (: k (sx-skip s j)
                                (? (k >= #s || elem (s k) [41 93 125]) (rev acc) (go (sx-end s k) ([k (sx-end s k)] . acc))))
   (go (i + 1) ()))
 (sx-tops s) (: (go j acc) (: k (sx-skip s j) (? (k >= #s) (rev acc) (go (sx-end s k) ([k (sx-end s k)] . acc)))) (go 0 ()))
 (corridor-span s p) (: tops (sx-tops s) lv (two? tops ? <(rev tops) ())
   (kid f k) (: ks (sx-kids s (f 0)) j (s (f 0) = 91 ? (k - 1) k) (0 <= j && j < #ks ? (ks j) ()))
   (go f l) (? (atom? l) f (atom? f) () (go (kid f <l) >l))
   (two? lv ? (go lv p) ()))
 (check lv) (: bs (lv 'brushes) hollow (filter (i \ empty? (bs i)) ^#bs)
   (? (two? hollow) "a brush with no inside: \(bs <hollow 'shape)"
      (atom? (lv 'rooms)) "a level needs a room"
      (doors-of lv @ ds (string? ds ? ds (cars-of (pin lv 'doors ds))))))
 ; ..a door's place among the rooms: the two walls it passes, on axis ax -- 'z when it
 ; spans x in a wall across z -- its middle c along them, a and b the walls' places
 (hits r x z) [(? (r 0 <= x <= r 2) (filter (w \ mag (w - z) < 0.5) [(r 1) (r 3)]) ())
               (? (r 1 <= z <= r 3) (filter (w \ mag (w - x) < 0.5) [(r 0) (r 2)]) ())]
 (doors-of lv) (: (place d) (: x (d 0) z (d 1) hs (map (r \ hits r x z) (lv 'rooms))
                                 zs (cats (map cap hs)) xs (cats (map caup hs))
                                 (? (#zs = 2) {'ax 'z 'c x 'a (min2 (zs 0) (zs 1)) 'b (max2 (zs 0) (zs 1)) 'w (d 2) 'h (d 3) 'y (d 4)}
                                    (#xs = 2) {'ax 'x 'c z 'a (min2 (xs 0) (xs 1)) 'b (max2 (xs 0) (xs 1)) 'w (d 2) 'h (d 3) 'y (d 4)}
                                    "a door must sit in the wall between two rooms: \('door . d)"))
   ps (map place (lv 'doors))
   (any string? ps ? <(filter string? ps) ps))
 ; ..a car's shape on axis ax, as a door's: its inside a0 to a1 along and c0 to c1 across, y0
 ; to y1 up; its door's wall at 'side, 'out away from the inside, the door 'dc along and
 ; sliding 'slide, toward the longer wall beside it
 (car-of c) (: lo (c 'lo) hi (c 'hi) ax ((hi 0 - lo 0) >= (hi 2 - lo 2) ? 'z 'x) d (c 'door)
   (al p) (ax = 'z ? (p 0) (p 2)) (ac p) (ax = 'z ? (p 2) (p 0))
   dal (ax = 'z ? (d 0) (d 1)) dac (ax = 'z ? (d 1) (d 0)) c0 (ac lo) c1 (ac hi) a0 (al lo) a1 (al hi)
   far1 (mag (dac - c1) < mag (dac - c0)) d0 (dal - 0.5 * d 2) d1 (dal + 0.5 * d 2)
   {'ax ax 'a0 a0 'a1 a1 'c0 c0 'c1 c1 'y0 (lo 1) 'y1 (hi 1) 'side (far1 ? c1 c0) 'out (far1 ? 1.0 -1.0)
    'dc dal 'dw (d 2) 'dh (d 3) 'slide (a1 - d1 >= d0 - a0 ? 1.0 -1.0) 'leave (c 'leave)
    'ok (mag (dac - (far1 ? c1 c0)) < 0.5 && a0 <= d0 && d1 <= a1 && max2 (a1 - d1) (d0 - a0) >= d 2 - 0.05
         && d 3 <= hi 1 - lo 1)})
 (cars-of lv) (: cs (map car-of (peep lv 'cars ())) bad (filter (i \ !(cs i 'ok)) ^#cs)
   (two? bad ? "a car's door must sit in one of its long walls, under its roof, with wall beside it to slide into" (pin lv 'cars cs)))
 ; ..from a file: the level, or why not
 (slurp-file p) (: q (open p "r") (hot? q ? (slurp q @ s (close q, s)) ()))
 (corridor-load p) (slurp-file p @ () ("cannot read " + p) s (corridor-read s))
 ; --- places: in a door's frame, along its wall, up, and across it ---
 (P ax al y ac) (ax = 'z ? [al y ac] [ac y al])
 (along ax) (ax @ 'z [1.0 0.0 0.0] [0.0 0.0 1.0])
 (across ax) (ax @ 'z [0.0 0.0 1.0] [1.0 0.0 0.0])
 ; ..the room x z is in, or nearest: of rooms one inside another, the innermost
 (room-at lv x z) (: rs (lv 'rooms)
   (gap r) (sq (max2 0.0 (max2 (r 0 - x) (x - r 2))) + sq (max2 0.0 (max2 (r 1 - z) (z - r 3))))
   (area r) ((r 2 - r 0) * (r 3 - r 1))
   (foldl (\ b r (gap r < gap b || (gap r = gap b && area r < area b) ? r b)) <rs >rs))
 ; ..a room's box in plan, a little past its walls: what its lamps reach
 (inside r) [(r 0 - 0.11) (r 1 - 0.11) (r 2 + 0.11) (r 3 + 0.11)]
 ; ..the wall of x z's room nearest it: [ax at lo hi n], n into the room
 (wall-near lv x z) (: r (room-at lv x z)
   ws [['x (r 0) (r 1) (r 3) [1.0 0.0 0.0]] ['x (r 2) (r 1) (r 3) [-1.0 0.0 0.0]]
       ['z (r 1) (r 0) (r 2) [0.0 0.0 1.0]] ['z (r 3) (r 0) (r 2) [0.0 0.0 -1.0]]]
   (d w) (mag ((w 0 = 'x ? x z) - w 1))
   (foldl (\ b w (d w < d b ? w b)) <ws >ws))
 ; ..a thing hung on that wall at x z: its foot there, the way into the room, and its
 ; right as one faces the wall
 (hang lv x z) (: w (wall-near lv x z) n (w 4) r [(0.0 - n 2) 0.0 (n 0)]
   [(w 0 = 'x ? [(w 1) 0.0 z] [x 0.0 (w 1)]) n r])
 ; --- the shapes ---
 white [1.0 1.0 1.0]
 (mag3 a) (sqrt (dot a a))
 (sheets o U V n uv tex col) (mesh-sheet o U V (max2 1 (int (mag3 U / cell + 0.5))) (max2 1 (int (mag3 V / cell + 0.5))) n uv tex col)
 (slab lo hi uv tex col) (: x0 (lo 0) y0 (lo 1) z0 (lo 2) x1 (hi 0) y1 (hi 1) z1 (hi 2)
   dx [(x1 - x0) 0.0 0.0] dy [0.0 (y1 - y0) 0.0] dz [0.0 0.0 (z1 - z0)]
   (mesh-join [(sheets lo dy dz [-1.0 0.0 0.0] uv tex col) (sheets [x1 y0 z0] dy dz [1.0 0.0 0.0] uv tex col)
               (sheets lo dx dz [0.0 -1.0 0.0] uv tex col) (sheets [x0 y1 z0] dx dz [0.0 1.0 0.0] uv tex col)
               (sheets lo dx dy [0.0 0.0 -1.0] uv tex col) (sheets [x0 y0 z1] dx dy [0.0 0.0 1.0] uv tex col)]))
 ; --- the world: the level's brushes in its order, and last each doorway carved through
 ;     its wall; the surfaces where air meets solid, textured by the way they face ---
 (brush-of r) (: sh (r 'shape)
   b0 (sh 'box @ () (: p (sh 'prism) (brush-prism (r 'air) (p 0) (p 1) (p 2))) bx (brush-box (r 'air) (bx 0) (bx 1)))
   (pins (brush-cuts b0 (r 'cuts)) 'skin (r 'skin) 'whole (peep r 'whole 0) 'open (peep r 'open 0)))
 (doorway d) (: ax (d 'ax) p (P ax (d 'c - 0.5 * d 'w) (d 'y) (d 'a - 0.02)) q (P ax (d 'c + 0.5 * d 'w) (d 'y + d 'h) (d 'b + 0.02))
   (brush-box 1 [(min2 (p 0) (q 0)) (d 'y) (min2 (p 2) (q 2))] [(max2 (p 0) (q 0)) (d 'y + d 'h) (max2 (p 2) (q 2))]))
 (brushes-of lv) (map brush-of (lv 'brushes) + map doorway (lv 'doors))
 ; ..the texture on a face of brush b facing n, by its skin, and its texels as [tex U V]: tt the
 ; textures, each [name w h metres lay]; a floor's and ceiling's laid from x 0 z 0, a wall's
 ; along it and its foot on the brush's; then turned and shifted as the skin's entry, else
 ; the texture's own, lays it, [degrees [du dv]]
 (tix tt nm) (foldl (\ a i (tt i 0 = nm ? i a)) 0 ^#tt)
 (look tt) (\ n b (: c (? (0.7 < n 1) 'floor (n 1 < -0.7) 'ceiling 'wall)
                     e (foldl (\ a e (e 0 = c ? e a)) () (peep b 'skin ()))
                     i (tix tt (two? e ? (e 1) c)) t (tt i) k (t 1 / t 3) ly (two? e ? (e 2) (t 4))
                     uv (? (c = 'wall) (: d (unit [(0.0 - n 2) 0.0 (n 0)]) [[(k * d 0) 0.0 (k * d 2) 0.0] [0.0 (0.0 - k) 0.0 (t 2 + k * b 'lo 1)]])
                           [[k 0.0 0.0 0.0] [0.0 0.0 k 0.0]])
                     (? (!(two? ly)) [i (uv 0) (uv 1)]
                        (: a (ly 0 * pi / 180.0) co (cos a) si (sin a) U (uv 0) V (uv 1)
                           (mix p q s) (map (j \ p * U j + q * V j + (j = 3 ? s 0.0)) ^4)
                           [i (mix co si (k * ly 1 0)) (mix (0.0 - si) co (k * ly 1 1))]))))
 ; ..the door itself, shut: a slab of steel in the middle of the wall, the texture once
 ; across each face
 (door-mesh d tt) (: ax (d 'ax) m (0.5 * (d 'a + d 'b)) l0 (d 'c - 0.5 * d 'w) w (d 'w) h (d 'h)
   y0 (d 'y) p (P ax l0 y0 (m - door-t)) q (P ax (l0 + w) (y0 + h) (m + door-t)) i (tix tt 'door) t (tt i)
   (slab p q (s \ [(t 1 / w * ((s $ ax @ 'z 0 2) - l0)) (t 2 / h * (y0 + h - s 1))]) i white))
 ; ..a car: its floor, roof, ends and long walls, the door's wall in three round the doorway,
 ; car-t thick outside its inside; the texture along its walls and over its floor
 (car-box c al0 y0 ac0 al1 y1 ac1 uv i) (: p (P (c 'ax) al0 y0 ac0) q (P (c 'ax) al1 y1 ac1)
   (slab [(min2 (p 0) (q 0)) (min2 (p 1) (q 1)) (min2 (p 2) (q 2))] [(max2 (p 0) (q 0)) (max2 (p 1) (q 1)) (max2 (p 2) (q 2))] uv i white))
 (car-mesh c tt) (: T car-t a0 (c 'a0) a1 (c 'a1) c0 (c 'c0) c1 (c 'c1) y0 (c 'y0) y1 (c 'y1)
   s (c 'side) w (s + c 'out * T) f (c 'out > 0.0 ? c0 c1) fw (f - c 'out * T)
   d0 (c 'dc - 0.5 * c 'dw) d1 (c 'dc + 0.5 * c 'dw) dh (y0 + c 'dh)
   i (tix tt 'train) t (tt i) k (t 1 / t 3)
   (wl q) [(k * (q 0 + q 2)) (k * (y1 - q 1))] (fl q) [(k * q 0) (k * q 2)]
   (mesh-join [(car-box c (a0 - T) (y0 - T) (c0 - T) (a1 + T) y0 (c1 + T) fl i)
               (car-box c (a0 - T) y1 (c0 - T) (a1 + T) (y1 + T) (c1 + T) fl i)
               (car-box c (a0 - T) y0 c0 a0 y1 c1 wl i) (car-box c a1 y0 c0 (a1 + T) y1 c1 wl i)
               (car-box c a0 y0 f a1 y1 fw wl i)
               (car-box c a0 y0 s d0 y1 w wl i) (car-box c d1 y0 s a1 y1 w wl i) (car-box c d0 dh s d1 y1 w wl i)]))
 ; ..its door, in the middle of its wall's thickness
 (car-door c tt) (: m (c 'side + 0.5 * c 'out * car-t) d0 (c 'dc - 0.5 * c 'dw) y0 (c 'y0) h (c 'dh) w (c 'dw)
   i (tix tt 'door) t (tt i)
   (car-box c d0 y0 (m - door-t) (d0 + w) (y0 + h) (m + door-t) (q \ (: al ((c 'ax = 'z ? (q 0) (q 2)) - d0) [(t 1 / w * al) (t 2 / h * (y0 + h - q 1))])) i))
 ; ..its strip down the roof, and the lamp it is, lighting only the car
 (car-mask c) (: p (P (c 'ax) (c 'a0) 0.0 (c 'c0)) q (P (c 'ax) (c 'a1) 0.0 (c 'c1))
   (inside [(min2 (p 0) (q 0)) (min2 (p 2) (q 2)) (max2 (p 0) (q 0)) (max2 (p 2) (q 2))]))
 (car-bar c) (: m (0.5 * (c 'c0 + c 'c1)) y (c 'y1)
   (car-box c (c 'a0 + 0.5) (y - 0.05) (m - 0.08) (c 'a1 - 0.5) y (m + 0.08) (_ \ [0.0 0.0]) -1))
 (car-lamp c) (: m (0.5 * (c 'c0 + c 'c1)) y (c 'y1 - 0.06) n 6
   {'at (map (j \ P (c 'ax) (c 'a0 + (j + 0.5) / n * (c 'a1 - c 'a0)) y m) ^n) 'n [0.0 -1.0 0.0]
    'c [2.0 2.0 2.1] 'r 4.5 'soft 0.3 'keep (car-mask c)})
 ; --- the lights: {'lamps 'how 'shine 'glow} -- lamps summed as one channel, how it
 ;     behaves, and what shines and glows by it, [packed brightness] each ---
 (light ls how sh gl) {'lamps ls 'how how 'shine sh 'glow gl}
 (nub at s col) (slab (c+ at [(0.0 - s) (0.0 - s) (0.0 - s)]) (c+ at [s s s]) (_ \ [0.0 0.0]) -1 col)
 (strip-light lv s) (: x (s 'at 0) z (s 'at 1) r (room-at lv x z) h (s 'y) fl (r 5) ac (s 'across) k (inside r)
   (spot i) (: o (0.3 * i - 0.6) (ac ? [(x + o) (h - 0.06) z] [x (h - 0.06) (z + o)]))
   bar (ac ? (slab [(x - 0.6) (h - 0.05) (z - 0.08)] [(x + 0.6) h (z + 0.08)] (_ \ [0.0 0.0]) -1 white)
            (slab [(x - 0.08) (h - 0.05) (z - 0.6)] [(x + 0.08) h (z + 0.6)] (_ \ [0.0 0.0]) -1 white))
   ; ..a fitting as strong as its ceiling is high: the light on the floor the same
   g (max2 0.5 ((h - fl) / 2.6)) g2 (g * g)
   (light [{'at (map spot ^5) 'n [0.0 -1.0 0.0] 'c (c* g2 [2.3 2.4 2.6]) 'r (7.5 * g) 'keep k}
           {'at [[x (fl + 0.02) z]] 'n [0.0 1.0 0.0] 'c (c* g2 [1.1 1.1 1.15]) 'r (6.0 * g) 'soft g 'keep k}]
          (s 'how) [[(mesh-pack bar) 3.0]] ()))
 ; ..a bulb: its glass white-hot and tinted, a glow round it, its light soft on what is near
 (bulb-light lv b) (: p (b 'at) c (b 'c) r (room-at lv (p 0) (p 2)) top (max2 0.01 (max2 (c 0) (max2 (c 1) (c 2))))
   tint (c* (1.0 / top) c)
   (light [{'at [p] 'c c 'r 6.0 'soft 0.35 'keep (inside r)}] (b 'how)
          [[(mesh-pack (nub p 0.04 (cmix tint white 0.55))) 4.0]] [[(mesh-pack (halo-ball p 0.35 tint)) 0.9]]))
 ; ..a sconce: its face white-hot, standing out from the wall, its light thrown the way it looks
 (sconce-light lv q) (: a (q 'at) n (c+ (q 'np) (c* -1.0 a)) d (c+ (q 'up) (c* -1.0 a)) l (cross n d) L (q 'len) s 0.25
   (pt kn kd kl) (c+ a (c+ (c* kn n) (c+ (c* kd d) (c* kl l))))
   p0 (pt 0.02 0.0 (-0.5 * L + 0.04)) p1 (pt (s - 0.02) 0.012 (0.5 * L - 0.04)) m (pt (0.5 * s) 0.1 0.0)
   face (slab (map (i \ min2 (p0 i) (p1 i)) ^3) (map (i \ max2 (p0 i) (p1 i)) ^3) (_ \ [0.0 0.0]) -1 white)
   (light [{'at (map (j \ pt (0.5 * s) 0.06 ((j + 0.5) / 4.0 * L - 0.5 * L)) ^4) 'n d 'c [1.9 1.8 1.6] 'r 7.5 'soft 0.3
            'keep (inside (room-at lv (m 0) (m 2)))}]
          (q 'how) [[(mesh-pack face) 3.0]] ()))
 ; ..candle flames, each a little upright tongue and a glow, one lamp among them all
 (flame-light lv q) (: ps (q 'pts) c (q 'c) k (inside (room-at lv (ps 0 0) (ps 0 2)))
   (tip p) (c+ p [0.0 0.03 0.0])
   (tongue p) (mesh-join [(slab (c+ p [-0.009 0.0 -0.009]) (c+ p [0.009 0.04 0.009]) (_ \ [0.0 0.0]) -1 (cmix c white 0.5))
                          (slab (c+ p [-0.005 0.04 -0.005]) (c+ p [0.005 0.06 0.005]) (_ \ [0.0 0.0]) -1 c)])
   (light [{'at (map tip ps) 'c c 'r 3.5 'soft 0.2 'keep k}] (q 'how)
          [[(mesh-pack (mesh-join (map tongue ps))) 3.0]] [[(mesh-pack (mesh-join (map (p \ halo-ball (tip p) 0.12 c) ps))) 0.7]]))
 ; ..a glow round p, r across: three discs crossed, bright in the middle and gone at the
 ; edge, each seen from both sides
 (halo-ball p r col) (: n 12 z [0.0 0.0 0.0]
   (vx q k) [(q 0) (q 1) (q 2) 0.0 0.0 0.0 0.0 0.0 (k 0) (k 1) (k 2)]
   (disc u v) (: rim (map (i \ (: a (tau * i / n) (vx (c+ p (c+ (c* (r * cos a) u) (c* (r * sin a) v))) z))) ^n)
     (mesh (vx p col . rim) (cats (map (i \ (: a (1 + i) b (1 + (i + 1) % n) [[0 a b -1] [0 b a -1]])) ^n))))
   (mesh-join [(disc [1.0 0.0 0.0] [0.0 1.0 0.0]) (disc [0.0 1.0 0.0] [0.0 0.0 1.0]) (disc [1.0 0.0 0.0] [0.0 0.0 1.0])]))
 (sign-light lv s) (: a (s 'at) sn (peep s 'n ())
   hg (? (atom? sn) (hang lv (a 0) (a 1)) (: n (unit sn) [[(a 0) 0.0 (a 1)] n [(0.0 - n 2) 0.0 (n 0)]]))
   n (hg 1) rt (hg 2) h (a 3)
   w (h * (neon-strokes (s 'text) 1)) o (c+ (c+ (hg 0) [0.0 (a 2) 0.0]) (c* (-0.5 * w) rt))
   sg (neon-sign (s 'text) o rt [0.0 1.0 0.0] n h (c* 0.7 (s 'c)))
   (light [(pin (sg 'lamp) 'keep (inside (room-at lv (a 0) (a 1))))] (s 'how)
          [[(sg 'tube) 1.8]] [[(sg 'halo) 0.3]]))
 ; ..each door's lamps either side of it, red while it is shut and green once it opens
 (door-lights lv i d) (: ax (d 'ax) at (d 'c + 0.5 * d 'w + 0.25)
   (side ac off) (: p (P ax at (d 'y + 1.5) (ac + off)) k (inside (room-at lv (p 0) (p 2)))
     [(light [{'at [p] 'c [0.08 0.006 0.003] 'r 1.6 'soft 0.2 'keep k}] [['shut i]]
             [[(mesh-pack (nub p 0.035 [1.0 0.1 0.05])) 2.5]] ())
      (light [{'at [p] 'c [0.006 0.07 0.015] 'r 1.6 'soft 0.2 'keep k}] [['open i]]
             [[(mesh-pack (nub p 0.035 [0.1 1.0 0.25])) 2.5]] ())])
   (side (d 'a) -0.01 + side (d 'b) 0.01))
 (lights-of lv) (map (strip-light lv) (lv 'strips) + map (bulb-light lv) (lv 'bulbs)
                 + map (sconce-light lv) (peep lv 'sconces ())
                 + map (sign-light lv) (lv 'signs) + map (flame-light lv) (peep lv 'flames ())
                 + cats (map (i \ door-lights lv i (lv 'doors i)) ^#(lv 'doors))
                 + map (grav-light lv) (peep lv 'gravs ()))
 ; ..a grav shaft's glow, up from its foot, all round from its middle and down from its head
 (grav-light lv g) (: lo (g 'lo) hi (g 'hi) x (0.5 * (lo 0 + hi 0)) z (0.5 * (lo 2 + hi 2)) k (inside (room-at lv x z)) c [0.3 0.65 1.0]
   (light [{'at [[x (lo 1 + 0.05) z]] 'n [0.0 1.0 0.0] 'c c 'r 5.0 'soft 0.4 'keep k}
           {'at [[x (0.5 * (lo 1 + hi 1 + 3.0)) z]] 'c c 'r (0.5 * (hi 1 - lo 1) + 2.5) 'soft 0.6 'keep k}
           {'at [[x (hi 1 + 2.9) z]] 'n [0.0 -1.0 0.0] 'c c 'r 5.0 'soft 0.4 'keep k}] () () ()))
 ; ..how bright a light is at mt seconds, the doors open by ds: steady; a strip failing,
 ; mostly on and now and then stammering off; a tube's buzz; a bulb breathing; a beacon, every one in time; a door's
 ; lamp by its door. sd keeps two failing lights out of step
 (bright how mt sd ds) ((two? how ? <how 'steady) @
  'stammer (flicker-stammer mt sd)
  'buzz (flicker-buzz mt)
  'breathe (flicker-pulse mt 0.7 0.3 1.7 sd)
  'blink (flicker-blink mt 1.5 0.5 0.06)
  (a . u) (peep ds <u 0.0 @ d (a @ 'shut (d < 0.02 ? 1.0 0.0) (d < 0.02 ? 0.0 1.0)))
  1.0)
 (corridor-ks sc mt ds) (map (i \ bright (sc 'lights i 'how) mt i ds) ^#(sc 'lights))
 amb [0.025 0.025 0.03]
 ; the sky's day, an equinox, and its latitude; asked every sky-k of kitty's pixels
 sky-day 20716.0
 lat (40.7 * pi / 180.0)
 sky-k 2
 ; --- the textures: the level's, then a grid for any of wall floor ceiling door it has
 ;     not, and train where it has a car, then the posters' ---
 grid-layers '((fill 0.55) (grid 16 16 1 0.47) (grid 64 64 1 0.35))
 (textures lv) (: ts (lv 'textures) have (map (t \ t 'name) ts)
   want (['wall 'floor 'ceiling 'door] + (two? (peep lv 'cars ()) ? ['train] ()))
   (ts + map (nm \ {'name nm 'w 64 'h 64 'm 1.0 'layers grid-layers}) (filter (nm \ !(elem nm have)) want)))
 ; ..a poster drawn: a navy field, a pale ring round a star of four points, a red band
 ; across, and ENLIST in the letters the neon bends; a pale edge
 (poster-art _) (: w 48 h 72 sk (neon-strokes "ENLIST") k (40.0 / sk 1)
   segs (catmap (: (go l) (two? >l ? ([<l <>l] . go >l)) go) (sk 0))
   ; ..each letter's stroke in texels, from the bottom left at 4 8 and k a cap
   (tx p) [(4.0 + k * p 0) (h - 8.0 - k * p 1)]
   ts (map (g \ [(tx (g 0)) (tx (g 1))]) segs)
   (near px py) (any (g \ (: a (g 0) b (g 1) dx (b 0 - a 0) dy (b 1 - a 1) l2 (max2 1e-9 (dx * dx + dy * dy))
                            t (sat (((px - a 0) * dx + (py - a 1) * dy) / l2)) ex (a 0 + t * dx - px) ey (a 1 + t * dy - py)
                            (ex * ex + ey * ey < 1.3))) ts)
   cream [0.9 0.85 0.7] navy [0.07 0.1 0.24] red [0.7 0.1 0.08]
   (mesh-pic w h (\ x y (: px (x + 0.5) py (y + 0.5) cx (px - 24.0) cy (py - 26.0) r (sqrt (cx * cx + cy * cy))
     star (mag cx * mag cy < 9.0 && r < 13.0)
     (? (x < 2 || 45 < x || y < 2 || 69 < y) cream
        (near px py) cream
        (15.0 < r < 17.5 || star) cream
        (mag (py - 0.5 * px - 34.0) < 3.0) red
        navy)))))
 ; ..or a png's, 80 texels a metre up to 128 a side; drawn where there is none
 (poster-tex path w h) (: b (string? path ? (slurp-file path)) r (string? b ? (cite 'png 'png-decode b))
   (two? r && charm? (r 0)
    ? (mesh-rgba (r 0) (r 1) (r 2) (min2 128 (max2 2 (int (80.0 * w)))) (min2 128 (max2 2 (int (80.0 * h)))))
      (poster-art ())))
 ; ..a poster's sheet: on the wall nearest x z, a hair off it, its texture tex tw by th
 (poster-mesh lv p tex tw th) (: a (p 'at) hg (hang lv (a 0) (a 1)) n (hg 1) rt (hg 2) w (a 3) h (a 4)
   o (c+ (c+ (hg 0) (c* 0.006 n)) (c+ [0.0 (a 2) 0.0] (c* (-0.5 * w) rt)))
   (sheets o [0.0 h 0.0] (c* w rt) n (q \ (: d (c+ q (c* -1.0 o)) [(1.0 * tw / w * dot d rt) (1.0 * th / h * (h - d 1))])) tex white))
 ; ..whether a piece of surface c across is too coarse for the lamps lps: a lamp's light
 ; changes the more across a cell the nearer it is
 ; ..the lamps' points, each [p r keep], numbered, and their places and reaches as trays
 (lamp-pts lps) (: l (cats (map (lp \ map (p \ [p (lp 'r) (peep lp 'keep ())]) (lp 'at)) lps)) n #l
   (col j) (gem-tray [n] (map (q \ 1.0 * q 0 j) l)) (tab f) (foldl (\ t q (pin t #t (f q))) {} l)
   {'n n 'at (tab (q \ q)) 'ks (tab (q \ [(q 0) (q 1) (two? (q 2) ? 1 0)])) 'mk (tab (q \ two? (q 2)))
    'P (n = 0 ? () (map col ^3))
    'R (n = 0 ? () (min (gem-tray [n] (map (q \ 1.0 * q 1) l)) (6.0 * cell-top - 0.5)))})
 ; ..the numbers of those reaching face f, all weighed at once
 (reach-ix lp f) (: flo (map (k \ foldl (\ a p (min2 a (p k))) 1e9 f) ^3) fhi (map (k \ foldl (\ a p (max2 a (p k))) -1e9 f) ^3)
   (? (lp 'n = 0) ()
      (: (out k) (: P (lp 'P k) (max 0.0 (max (flo k - P) (P - fhi k)))) dx (out 0) dy (out 1) dz (out 2) R (lp 'R)
         I (iota (dx * dx + dy * dy + dz * dz < R * R))
         (map (j \ peep I j 0) ^#I))))
 ; ..what of the lamps a face's cut hangs on, as a key: wk too where one is masked
 (reach-of all-pts ks wi)
   (\ f (: ix (reach-ix all-pts f) [(map ks ix) (any (all-pts 'mk) ix ? wi ())]))
 (coarse? lps) (: all-pts (lamp-pts lps)
  ; ..asked of a face first, so its pieces weigh only the lamps that reach it
  (\ f (: pts (map (all-pts 'at) (reach-ix all-pts f))
     (col j) (gem-tray [#pts] (map (q \ 1.0 * q 0 j) pts)) PX (col 0) PY (col 1) PZ (col 2) R (gem-tray [#pts] (map (q \ 1.0 * q 1) pts))
  (\ ps c (: lo (map (k \ foldl (\ a p (min2 a (p k))) 1e9 ps) ^3) hi (map (k \ foldl (\ a p (max2 a (p k))) -1e9 ps) ^3)
    (out k P) (max 0.0 (max (lo k - P) (P - hi k)))
    ; ..and only where the lamp's mask lets it shine on the piece somewhere
    (cl p) (map (k \ min2 (hi k) (max2 (lo k) (p k))) ^3)
    (lit? kp p) (kp @ () 1
      k (: q (cl p) (any (r \ k 0 < r 0 && r 0 < k 2 && k 1 < r 2 && r 2 < k 3)
                         [q [(lo 0) (q 1) (lo 2)] [(hi 0) (q 1) (lo 2)] [(lo 0) (q 1) (hi 2)] [(hi 0) (q 1) (hi 2)]
                          [(0.5 * (lo 0 + hi 0)) (q 1) (0.5 * (lo 2 + hi 2))]])))
    ; ..the lamps near enough, all at once, then their masks
    (? (#pts = 0 || 6.0 * c - 0.5 <= 0.0) 0
       (: dx (out 0 PX) dy (out 1 PY) dz (out 2 PZ) L (min R (6.0 * c - 0.5))
          ix (iota (dx * dx + dy * dy + dz * dz < L * L))
          (any (j \ (: i (peep ix j 0) (lit? (pts i 2) (pts i 0)))) ^#ix))))))))
 ; ..a pane: a sheet each way across the middle of its thin side, glass of its texture, the
 ; light on it its sheen
 (pane-mesh p tt) (: lo (p 'lo) hi (p 'hi) ax ((hi 0 - lo 0) < (hi 2 - lo 2) ? 0 2) al (2 - ax) m (0.5 * (lo ax + hi ax))
   i (tix tt (p 'tex)) t (tt i) W (hi al - lo al) H (hi 1 - lo 1) g [0.14 0.15 0.15]
   (pt a y) (ax = 0 ? [m y a] [a y m]) e (map (k \ k = al ? 1.0 0.0) ^3) n (map (k \ k = ax ? 1.0 0.0) ^3)
   (uv q) [(t 1 / W * (q al - lo al)) (t 2 / H * (hi 1 - q 1))]
   (mesh-join [(sheets (pt (lo al) (lo 1)) [0.0 H 0.0] (c* W e) n uv (-3 - i) g)
               (sheets (pt (lo al) (lo 1)) [0.0 H 0.0] (c* W e) (c* -1.0 n) uv (-3 - i) g)]))
 ; ..a packed mesh as its own light at brightness b, a glow when key says, kept on it while
 ; b holds
 (shine-at pk b key) (? (peep pk 'sb () = b) (pk 'sv)
                        (: v (mesh-shine pk b) w (key = 'glow ? (mesh-glow v) v) _ (pins pk 'sb b 'sv w) w))
 (mid3 vs) (c* (1.0 / #vs) (foldl (\ a v [(a 0 + v 0) (a 1 + v 1) (a 2 + v 2)]) [0.0 0.0 0.0] vs))
 ; ..a decal's sheet, its texture tex tw by th
 (decal-mesh d tt) (: a (d 'at) n (unit (c+ (d 'np) (c* -1.0 a))) u (unit (c+ (d 'up) (c* -1.0 a))) r (cross n u)
   w (d 'w) h (d 'h) i (tix tt (d 'tex)) t (tt i) o (c+ a (c+ (c* (-0.5 * w) r) (c* (-0.5 * h) u)))
   (sheets o (c* h u) (c* w r) n (q \ (: e (c+ q (c* -1.0 o)) [(t 1 / w * dot e r) (t 2 / h * (h - dot e u))])) i white))
 ; ..a drape's sheet: each cell whose four corners are there two triangles, its texels laid
 ; from the way it faces most, a floor's or a wall's; a corner's normal across its neighbours
 (drape-mesh d tt) (: rs (d 'rows) i (tix tt (d 'tex)) t (tt i) k (t 1 / t 3) R #rs C #<rs
   (at r c) ((r < 0) || (r >= R) || (c < 0) || (c >= C) ? () (rs r c))
   (or a b) (a = () ? b a)
   (nrm r c p) (: dr (c+ (or (at (r + 1) c) p) (c* -1.0 (or (at (r - 1) c) p))) dc (c+ (or (at r (c + 1)) p) (c* -1.0 (or (at r (c - 1)) p)))
                  n (cross dr dc) (dot n n < 1e-12 ? [0.0 1.0 0.0] (unit n)))
   pn (foldl (\ m q (: p (rs (q 0) (q 1)) (p = () ? m (pin m (q 0 * C + q 1) [p (nrm (q 0) (q 1) p)])))) {} (cats (map (r \ map (c \ [r c]) ^C) ^R)))
   (face ks) (: s (foldl (\ a q (c+ a (pn q 1))) [0.0 0.0 0.0] ks)
     (abs (s 1) >= max (abs (s 0)) (abs (s 2)) ? 1 (abs (s 0) > abs (s 2) ? 0 2)))
   qs (cats (map (r \ cats (map (c \ (: ks [(r * C + c) (r * C + c + 1) ((r + 1) * C + c + 1) ((r + 1) * C + c)]
                                        (all (q \ peep pn q () != ()) ks ? [[ks (face ks)]] ()))) ^(C - 1))) ^(R - 1)))
   ; ..a vertex to each corner and way it is laid
   ix (foldl (\ a q (foldl (\ a kk (: key (3 * kk + q 1) (peep (a 0) key () != () ? a [(pin (a 0) key (a 1)) (a 1 + 1) ([kk (q 1)] . a 2)])))
                           a (q 0))) [{} 0 ()] qs)
   (uv ax p) (? (ax = 1) [(k * p 0) (k * p 2)] (ax = 0) [(k * p 2) (0.0 - k * p 1)] [(k * p 0) (0.0 - k * p 1)])
   (id q j) (peep (ix 0) (3 * (q 0 j) + q 1) 0)
   (mesh (map (v \ (: e (pn (v 0)) (e 0 + uv (v 1) (e 0) + e 1 + white))) (rev (ix 2)))
         (cats (map (q \ [[(id q 0) (id q 1) (id q 2) i] [(id q 0) (id q 2) (id q 3) i]]) qs))))
 (file-of dir p) (p 'file @ () () f (f 0 @ 47 f (dir + f)))
 ; --- the advertisements: each its own light, bright, and a lamp before it in the colour
 ;     its picture comes to on the whole; a spinner four of them round a square, turning ---
 (avg-col txs nm) (: t <(filter (t \ t 'name = nm) txs) f (swatch-texel (t 'layers))
   (c* (1.0 / 64.0) (foldl (\ a i (: c (f (t 'w * (i % 8) // 8) (t 'h * (i // 8) // 8)) (c = () ? a (c+ a c)))) [0.0 0.0 0.0] ^64)))
 ad-shine 1.3
 (ad-light lv txs tt d) (: a (d 'at) n (unit (c+ (d 'np) (c* -1.0 a))) p (c+ a (c* 0.8 n))
   (light [{'at [p] 'n n 'c (c* 2.2 (avg-col txs (d 'tex))) 'r (0.9 * max2 (d 'w) (d 'h) + 6.0) 'soft 1.5 'wrap 0.3
            'keep (inside (room-at lv (p 0) (p 2)))}]
          () [[(mesh-pack (decal-mesh d tt)) ad-shine]] ()))
 (spin-light lv txs s) (: p (c+ (s 'at) [0.0 (0.5 * s 'h) 0.0])
   (light [{'at [p] 'c (c* 1.25 (c+ (avg-col txs (s 't1)) (avg-col txs (s 't2)))) 'r (s 'w + 10.0) 'soft 2.0
            'keep (inside (room-at lv (p 0) (p 2)))}]
          () () ()))
 ; ..its four faces about its middle's foot, outward, the two pictures in turn
 (spin-mesh s tt) (: w (s 'w) h (s 'h)
   (face i) (: f (i * pi / 2.0) n [(sin f) 0.0 (cos f)] a [(0.5 * w * sin f) (0.5 * h) (0.5 * w * cos f)]
     (decal-mesh {'at a 'np (c+ a n) 'up (c+ a [0.0 1.0 0.0]) 'w w 'h h 'tex (i % 2 = 0 ? (s 't1) (s 't2))} tt))
   (mesh-pack (mesh-join (map face ^4))))
 spin-v 0.35                              ; radians a second
 ; ..turned to where it has got to at mt, shining
 (spin-at s pk mt) (: c (pk 'cols) an (spin-v * mt) ca (cos an) sa (sin an) o (s 'at)
   [(mesh-shine {'n (pk 'n) 'tris (pk 'tris)
                 'cols [(o 0 + ca * c 0 + sa * c 2) (o 1 + c 1) (o 2 + ca * c 2 - sa * c 0) (c 3) (c 4)
                        (ca * c 5 + sa * c 7) (c 6) (ca * c 7 - sa * c 5) (c 8) (c 9) (c 10)]}
                ad-shine)])
 ; ..a level's sky: its time, weather, light and stars, and k what scales its light to the
 ; corridor's gain; () when it has none
 (sky-of lv) (peep lv 'sky () @ () ()
   s (: sim (sky-day * 86400.0 + 3600.0 * s 'hour) wx (pin (sky-weather (foldl (\ a i (sky-covers i = s 'cover ? i a)) 0 ^4) 'smooth) 'smog (peep s 'smog 0.0))
        lt (sky-light (sky-sun sim 0.0 lat) wx sim)
        {'sim sim 'wx wx 'lt lt 'ss (sky-stars sim 0.0 lat) 'k (0.75 * lt 'expo)}))
 ; --- the scene, built from a level: the meshes packed and each light's channel baked;
 ;     dir the level's folder, for its pictures; tk () or view-loading's tick, told as it goes ---
 (corridor-scene lv dir was) (scene lv dir was ())
 ; ..a part as a key says it: a tablet hashes as itself, so as its keys and values
 (vals x) (? (tablet? x) (map (k \ [k (vals (x k))]) (sort (keys x))) (two? x) (map vals x) x)
 (scene lv dir was tk) (: ps (lv 'posters) (tick w p) (tk @ () () f (f w p))
   ; ..what the scenes before made, kept where it would be made the same, by a key saying
   ; all it was made of; and a number for each key, never another's. kept on from scene to
   ; scene, and begun again once it holds three times what one scene makes
   old (tablet? was ? (peep was 'memo {}) {}) fresh (!(tablet? was) || peep old 'made 0 > 3 * peep old 'size 1e9)
   memo (fresh ? {'v {} 'id {} 'n (peep old 'n 0) 'made 0} old) ov (memo 'v) oi (memo 'id)
   (kept k f) (: c (peep ov k ()) (? (two? c) <c (: v (f ()) (pin ov k [v], v))))
   (idof k) (: i (peep oi k ()) (? (i = ()) (: j (memo 'n) (pins memo 'n (j + 1) 'made (memo 'made + 1), pin oi k j, j)) i))
   txs (textures lv) tt (map (t \ [(t 'name) (t 'w) (t 'h) (t 'm) (peep t 'lay ())]) txs)
   ls (lights-of lv + map (ad-light lv txs tt) (peep lv 'ads ()) + map (spin-light lv txs) (peep lv 'spins ()))
   ptex (map (p \ poster-tex (file-of dir p) (p 'at 3) (p 'at 4)) ps)
   (pm i) (poster-mesh lv (ps i) (#tt + i) (shape (ptex i 0) 1) (shape (ptex i 0) 0))
   bs (brushes-of lv)
   ; ..the world in chunks chunk-m square, so a frame draws only those in view, nearest first
   ; ..a lamp's mask is its room's or its car's, so a face a masked lamp reaches is kept by those too
   lps (cats (map (l \ l 'lamps) ls)) wk [(lv 'rooms) (vals (peep lv 'cars ()))]
   ; ..and the lamps' points as they were, so the faces an edit relit are known: those a
   ; point come or gone reaches, and all a masked one does once the masks' rooms move
   ti (idof tt) ap (lamp-pts lps) wi (idof wk) pks (foldl (\ t j (pin t j (idof (ap 'ks j)))) {} ^(ap 'n))
   pst (map (j \ [(pks j) (ap 'at j 0) (peep (ap 'R) j 0.0) (ap 'mk j)]) ^(ap 'n))
   ops (fresh || peep memo 'ti () != ti ? () (peep memo 'pts ())) owi (peep memo 'wi ())
   pin1 (foldl (\ t q (pin t (q 0) 1)) {} pst) opin (foldl (\ t q (pin t (q 0) 1)) {} ops)
   hot (map (q \ [(q 1) (q 2)]) (filter (q \ peep opin (q 0) 0 = 0 || (q 3 && wi != owi)) pst + filter (q \ peep pin1 (q 0) 0 = 0 || (q 3 && wi != owi)) ops))
   prev (fresh || peep memo 'ti () != ti ? () (peep memo 'bstate ()))
   kp {'kept kept 'id idof 'reach (reach-of ap pks wi) 'look (b \ [ti (vals (peep b 'skin ())) (b 'lo 1)])
       'bkey (b \ idof [(b 'planes) (b 'air) (peep b 'open 0) (vals (peep b 'skin ())) (peep b 'whole 0)])
       'prev prev 'hot hot 'stash (st \ pin memo 'bstate st) 'tick tk}
   (on m k) [(mid3 (m 0)) m k]
   ds (peep lv 'decals ()) dps (peep lv 'drapes ())
   (made k f) (: ky (idof [k ti]) [(kept ['mesh ky] f) ky])
   more (map (i \ (: m (made ['poster (vals (ps i)) i (shape (ptex i 0))] (_ \ pm i)) (on (m 0) (m 1)))) ^#ps
         + map (d \ (: _ (tick 'decals ()) m (made ['decal (vals d)] (_ \ decal-mesh d tt)) (on (m 0) (m 1)))) ds
         + map (d \ (: m (made ['drape (vals d)] (_ \ drape-mesh d tt)) (on (m 0) (m 1)))) dps)
   cks (map (c \ [(c 0) (kept ['pack (c 0)] (c 1))])
            (chunks-kept bs [cell-top cell (coarse? lps)] (look tt) chunk-m more kp))
   _ (pins memo 'pts pst 'wi wi 'ti ti, fresh ? (pin memo 'size (memo 'made)))
   drs (map (d \ kept ['door (vals d) tt] (_ \ mesh-pack (door-mesh d tt))) (lv 'doors))
   ; ..each light's channel; the steady ones summed once with the ambient, so a frame adds
   ; only the lights that change
   dyn (filter (i \ two? (ls i 'how)) ^#ls) still (filter (i \ atom? (ls i 'how)) ^#ls)
   ; ..the lamps whose reach touches the mesh's box, the rest none
   LR (foldl (\ t l (pin t #t (map mesh-lamp-row (l 'lamps)))) {} ls)
   (ch pk i) (lamp-light (pk 'cols) (LR i))
   ; ..the sky at the level's hour, and in its streets the sky's light and the sun's on what
   ; faces them, scaled to the gain the sky is seen through; the level's ambient off them
   sk (sky-of lv) la (peep lv 'ambient [0.0 0.0 0.0]) ob (map (b \ [(b 'lo) (b 'hi)]) (filter (b \ peep b 'open 0) bs))
   (daylit pk) (: c (pk 'cols) lt (sk 'lt) s (lt 'sun) X (c 0 + 0.05 * c 5) Y (c 1 + 0.05 * c 6) Z (c 2 + 0.05 * c 7)
     m (min 1.0 (foldl (\ a b (a + (b 0 0 < X) * (X < b 1 0) * (b 0 1 < Y) * (Y < b 1 1 + 0.1) * (b 0 2 < Z) * (Z < b 1 2))) (X * 0.0) ob))
     a (m * (0.5 + 0.5 * c 6) * sk 'k) d (m * max 0.0 (c 5 * s 0 + c 6 * s 1 + c 7 * s 2) * (lt 'sunk * sk 'k))
     (map (j \ a * lt 'amb j + d * lt 'sunc j + (1.0 - m) * la j) ^3))
   (lit pk) {'base (lamp-lights (pk 'cols) (c+ amb (tablet? sk && two? ob ? (daylit pk) (c+ la (c* 0.0 (pk 'cols 0 @ z [z z z]))))) (map LR still))
             'chs (map (ch pk) dyn)}
   ; ..a car lit where it stands, and by its own lamp, which goes with it
   ; ..a chunk's light kept by what lights it: the lights that reach its box, in their places
   ; ..a light as a key says it, its masks left to wk
   lfs (map (l \ [(map (lp \ [(lp 'at) (peep lp 'n ()) (lp 'c) (lp 'r) (peep lp 'soft ()) (peep lp 'wrap ())]) (l 'lamps)) (vals (peep l 'how ()))]) ls) gk [la ob (vals (peep lv 'sky ())) dyn still wk]
   ; ..the lights reaching a box, weighed all at once by their lamps' points
   lq (cats (map (i \ cats (map (lp \ map (p \ [p (lp 'r) i]) (lp 'at)) (ls i 'lamps))) ^#ls)) nq #lq
   (qcol f) (gem-tray [nq] (map (q \ 1.0 * f q) lq)) QP (map (k \ qcol (q \ q 0 k)) ^3) QR (qcol (q \ q 1))
   QL (foldl (\ t q (pin t #t (q 2))) {} lq) LF (foldl (\ t f (pin t #t (idof f))) {} lfs) gi (idof gk)
   (litk lo hi) (? (nq = 0) [gi]
     (: (out k) (: P (QP k) (max 0.0 (max (lo k - P) (P - hi k)))) dx (out 0) dy (out 1) dz (out 2)
        I (iota (dx * dx + dy * dy + dz * dz < QR * QR)) hit (foldl (\ t j (pin t (QL (peep I j 0)) 1)) {} ^#I)
        [gi (map LF (sort (keys hit)))]))
   (litk-of pk) (litk (map (j \ amin (pk 'cols j)) ^3) (map (j \ amax (pk 'cols j)) ^3))
   ; ..a packed mesh's light, kept by what made it, k, and what lights its box
   (lit-of k pk) (: lo (map (j \ amin (pk 'cols j)) ^3) hi (map (j \ amax (pk 'cols j)) ^3) (kept ['lit k (litk lo hi)] (_ \ lit pk)))
   (clit lp pk k) (: l (lit-of k pk) {'base (c+ (l 'base) (mesh-lamp pk lp)) 'chs (l 'chs)})
   cars (map (c \ (: _ (tick 'cars ()) ck [(vals c) tt] b (kept ['car ck] (_ \ mesh-pack (car-mesh c tt))) d (kept ['car-door ck] (_ \ mesh-pack (car-door c tt))) lp (car-lamp c)
                     {'body b 'body-lit (kept ['car-lit ck (litk-of b)] (_ \ clit lp b ['car ck]))
                      'door d 'door-lit (kept ['car-lit ck (litk-of d)] (_ \ clit lp d ['car-door ck]))
                      'bar (kept ['car-bar ck] (_ \ mesh-pack (car-bar c)))}))
             (peep lv 'cars ()))
   {'motes (map motes-of (peep lv 'gravs ()))
    'panes (map (p \ (: k ['pane (vals p) tt] pk (kept k (_ \ mesh-pack (pane-mesh p tt))) {'pk pk 'lit (lit-of k pk)})) (peep lv 'panes ()))
    'chunks (map (c \ (: _ (tick 'light ()) pk (c 1) lo (map (k \ amin (pk 'cols k)) ^3) hi (map (k \ amax (pk 'cols k)) ^3)
                          {'pk pk 'lit (kept ['lit (idof (c 0)) (litk lo hi)] (_ \ lit pk)) 'lo lo 'hi hi 'mid (map (k \ 0.5 * (lo k + hi k)) ^3)
                           'rad (0.5 * sqrt (net (map (k \ sq (hi k - lo k)) ^3)))})) cks)
    'doors drs 'doors-lit (map (i \ lit-of ['door (vals (lv 'doors i)) tt] (drs i)) ^#drs) 'cars cars 'lights ls 'dyn dyn 'brushes bs 'sky sk 'open ob
    'ball (two? (peep lv 'balls ()) ? (ball-mesh ()) ()) 'lit lit
    'spins (map (s \ spin-mesh s tt) (peep lv 'spins ()))
    'texs (map (t \ kept ['tex (t 'w) (t 'h) (t 'layers)] (_ \ swatch (t 'w) (t 'h) (t 'layers))) txs + ptex)
    'memo memo})
 ; --- a grav shaft's motes: each a speck of three crossed squares, both ways round, a glow;
 ;     its own height, speed, and turn about the middle, from its number ---
 (hash01 i) (: h (sin (i * 12.9898 + 78.233) * 43758.5453) (h - floor h))
 mote-s 0.03
 (motes-of g) (: s mote-s o 0.0 n grav-n
   cs [[(0.0 - s) (0.0 - s) o] [s (0.0 - s) o] [s s o] [(0.0 - s) s o]
       [o (0.0 - s) (0.0 - s)] [o (0.0 - s) s] [o s s] [o s (0.0 - s)]
       [(0.0 - s) o (0.0 - s)] [s o (0.0 - s)] [s o s] [(0.0 - s) o s]] I (iota n) lo (g 'lo) hi (g 'hi) R (0.4 * min2 (hi 0 - lo 0) (hi 2 - lo 2))
   (r k) (gem-tray [n] (map (i \ hash01 (i + 101 * k)) ^n))
   C (iota (12 * n)) ci (C // n)
   (cor k) (peep (gem-tray [12] (map (c \ c k) cs)) ci 0.0)
   ts (cats (map (q \ (: (v c) ((4 * q + c) * n) (cats (map (i \ [[(v 0 + i) (v 1 + i) (v 2 + i) -2] [(v 0 + i) (v 2 + i) (v 1 + i) -2]
                                                                     [(v 0 + i) (v 2 + i) (v 3 + i) -2] [(v 0 + i) (v 3 + i) (v 2 + i) -2]]) ^n)))) ^3))
   {'x (0.5 * (lo 0 + hi 0)) 'z (0.5 * (lo 2 + hi 2)) 'y0 (lo 1) 'H (hi 1 + 2.8 - lo 1) 'up (g 'dir = 'up ? 1.0 -1.0)
    'h (r 0) 'rad (R * sqrt (r 1)) 'a (tau * r 2) 'sp (0.6 + 0.8 * r 3) 'w (0.3 + 0.6 * r 4)
    'ix (C % n) 'ox (cor 0) 'oy (cor 1) 'oz (cor 2) 'tris (star-tray [(4 * #ts)] (cats ts))})
 ; ..where they have got to at mt: [verts tris], brightest midway along the shaft
 (motes-at m mt) (: u (m 'h + m 'up * m 'sp * grav-v * mt / m 'H) f (u - floor u)
   an (m 'a + m 'w * mt) X (m 'x + m 'rad * cos an) Z (m 'z + m 'rad * sin an) Y (m 'y0 + m 'H * f)
   b (0.9 * sin (pi * f)) ix (m 'ix) (g t) (peep t ix 0.0) B (g b)
   [(lace [(g X + m 'ox) (g Y + m 'oy) (g Z + m 'oz) 0.0 0.0 (0.45 * B) (0.75 * B) B]) (m 'tris)])
 ; --- the frame: the rooms and doors lit by the lights as bright as they are now, then
 ;     what shines, then the glows; out as half blocks or kitty's pixels ---
 fov 1.5
 gain 2.0
 ; ..the thing under a point x y of the screen: where the ray through it first comes out of
 ; the air, with the brush there and its source path, or ()
 (corridor-pick st x y) (: r (corridor-ray st x y)
   (brush-ray (st 'sc 'brushes) (r 0) (r 1) @ () () q (pin q 'src (peep (peep (st 'lvl 'brushes) (q 'b) {}) 'src ()))))
 ; ..the eye, the ray's way through x y, and the view they are in
 (corridor-ray st x y) (: dm (mesh-dims st) w <dm h (dm 1) e [(st 'px) (st 'py) (st 'pz)]
   v (mesh-eye w h e (st 'th) (st 'ph) 0.0 fov 0.05 60.0) [e (mesh-dirs v (y * w + x)) v])
 (corridor-pens st) (: k (peep st 'kp 1) dm (mesh-dims st) w <dm h (dm 1) sc (st 'sc) lv (st 'lvl)
   ds (st 'doors) ks (corridor-ks sc (st 'mt) ds)
   e [(st 'px) (st 'py) (st 'pz)]
   ; ..under a sky, the sky where nothing is drawn; out in a street, seen further, its haze
   ; for fog
   sk (sc 'sky) sim (tablet? sk ? (sk 'sim + st 'mt) 0.0)
   out (tablet? sk && any (b \ !(any (k \ e k <= b 0 k || b 1 k + 0.1 <= e k) ^3)) (sc 'open))
   v (mesh-eye w h e (st 'th) (st 'ph) 0.0 fov 0.05 (out ? 150.0 60.0))
   fog (out ? (: hz (mesh-haze v (sk 'lt) (sk 'wx) sim) [(sk 'k * hz 0) (sk 'k * hz 1) (sk 'k * hz 2) 50.0 150.0]) [0.0 0.0 0.0 30.0 60.0])
   sky (tablet? sk ? (mesh-sky (sk 'ss) (sk 'lt) (sk 'wx) e sim (st 'mt) (k @ 1 1 (sky-k * k))) 0)
   ; ..indoors the sky only up through an open top, and elsewhere the dark: past what is
   ; drawn, or a crack between two surfaces
   (shut S) (: d (mesh-dirs v S) up (d 1 > 1e-6) dy (max (d 1) 1e-6)
     (on b) (: t ((b 1 1 - e 1) / dy) x (e 0 + t * d 0) z (e 2 + t * d 2) (up * (b 0 0 <= x) * (x <= b 1 0) * (b 0 2 <= z) * (z <= b 1 2)))
     (iota (foldl (\ m b (max m (on b))) (up * 0) (sc 'open) = 0)))
   bare (? (out || charm? sky) sky
           (two? sky) [(sky 0) (\ v f B (: g ((sky 1) v f B) S (iota (f = -1)) (pin g (peep S (shut S) 0) 0)))]
           (\ v S (pin (sky v S) (shut S) 0)))
   dk (map (i \ ks i) (sc 'dyn))
   (relit pk l) (mesh-lamps! pk (l 'base) (l 'chs) dk 1.0)
   ; ..the chunks whose ball is on the inside of each plane of the view, nearest first
   cam (v 'cam) (row i) (map (j \ peep cam (4 * i + j) 0.0) ^4)
   pls (map (q \ (: a (row (q 0)) b (row 3) s (q 1) n (map (j \ b j + s * a j) ^4) (: s (1.0 / sqrt (sq (n 0) + sq (n 1) + sq (n 2))) (map (x \ s * x) n))))
            [[0 1.0] [0 -1.0] [1 1.0] [1 -1.0] [2 1.0] [2 -1.0]])
   (seen? c) (: m (c 'mid) r (0.0 - c 'rad) !(any (n \ n 0 * m 0 + n 1 * m 1 + n 2 * m 2 + n 3 < r) pls))
   (far c) (net (map (k \ sq (c 'mid k - e k)) ^3))
   cks (sc 'chunks)
   hall (map (q \ (: c (cks (q 1)) (relit (c 'pk) (c 'lit)))) (sort (map (i \ [(far (cks i)) i]) (filter (i \ seen? (cks i)) ^#cks))))
   ; ..each door slid open along its wall into the wall's thickness
   doors (map (i \ (: pk (sc 'doors i) b (relit pk (sc 'doors-lit i)) d (lv 'doors i)
                      ix (iota (pk 'n) * 8 + (d 'ax = 'z ? 0 2))
                      [(pin (b 0) ix (pk 'cols (d 'ax = 'z ? 0 2) + ds i * (d 'w - 0.05))) (b 1)]))
              ^#(lv 'doors))
   ; ..each car where it has got to along its track, its door slid along its wall; none once gone
   (moved b pk k o) [(pin (b 0) (iota (pk 'n) * 8 + k) (pk 'cols k + o)) (b 1)]
   cars (cats (map (i \ (: c (lv 'cars i) s (st 'cars i) cs (sc 'cars i) k (c 'ax = 'z ? 0 2) o (s 'o)
                         (s 'ph = 'gone ? ()
                            [(moved (relit (cs 'body) (cs 'body-lit)) (cs 'body) k o)
                             (moved (relit (cs 'door) (cs 'door-lit)) (cs 'door) k (o + c 'slide * s 'door * (c 'dw - 0.05)))
                             (moved (mesh-shine (cs 'bar) 3.0) (cs 'bar) k o)])))
               ^#(peep lv 'cars ())))
   ; ..what shines and glows, at each light's brightness; none where it is out
   (by key) (cats (map (i \ cats (map (q \ ((q 1 * ks i) @ 0.0 () b [(shine-at (q 0) b key)])) (sc 'lights i key))) ^#ks))
   ; ..the cars and doors first, as near as anything is, so less behind them is lit for nothing
   glass (map (c \ relit (c 'pk) (c 'lit)) (sc 'panes))
   ; ..each ball where it is, made again only once it has moved
   balls (map (b \ (: d (tablet? (b 'pk) ? (b 'pk) (: d (ball-pk sc b) (pin b 'pk d, d))) (relit (d 'pk) (d 'lit))))
              (peep st 'balls ()))
   spins (cats (map (i \ spin-at (lv 'spins i) (sc 'spins i) (st 'mt)) ^#(peep lv 'spins ())))
   all (balls + cars + doors + hall + by 'shine + spins + glass + by 'glow + map (m \ motes-at m (st 'mt)) (sc 'motes))
   (mesh-frame v [(map (b \ b 0) all) (map (b \ b 1) all)] (sc 'texs) fog 8 gain bare))
 ; ..a frame, and under it the bottom row's word: what a reload found wrong, or for a few
 ; seconds that it read the level again
 (corridor-frame st) (: w (st 'w) h (st 'h) f (corridor-pens st) r (h // 2)
   ; ..or, with p pressed, where the player stands and faces, as a level says it
   m (? (st 'err || !(peep st 'pos 0)) (st 'msg) (where st))
   say? (string? m && (st 'err || peep st 'pos 0 || st 'mt < st 'msg-t + 3.0))
   text (say? ? (snip (pad (" " + m) w " ") 0 w) "")
   (mesh-show st f (say? ? (esc + "[" + show r + ";1H" + esc + (st 'err ? "[1;37;41m" "[0;37;40m") + text + esc + "[0m") "")
              (say? ? (view-band st text r (st 'err ? [150 20 20 124] [20 20 20 233])) {})))
 (where st) (: (r v) (show (int (v * 100.0 + (v < 0.0 ? -0.5 0.5)) / 100.0))
   deg (st 'th * 180.0 / pi @ d (d < 0.0 ? (d + 360.0) d))
   "(start [\(r (st 'px)) \(r (st 'py - eye-h)) \(r (st 'pz))] \(r deg) \(r (st 'ph * 180.0 / pi)))")
 ; --- the state: the screen as view lays it, the level and its scene, where the player
 ;     stands and looks, the clock, the doors ---
 (corridor-new w h lv dir) (state-new w h lv dir ())
 ; ..ld () or (_ \ tick), a fresh tick for each time the scene is made, kept to make it again
 (loader st) (peep st 'load () @ () () f (f ()))
 (state-new w h lv dir ld) (: s (lv 'start)
   (corridor-size {'px (s 'at 0) 'pz (s 'at 1) 'py (s 'y + eye-h) 'th (s 'deg * pi / 180.0) 'ph (s 'pitch * pi / 180.0) 't 0 'mt 0.0
                   'lvl lv 'sc (scene lv dir () (ld @ () () f (f ()))) 'load ld 'dir dir 'doors (map (_ \ 0.0) (lv 'doors)) 'cars (cars-new lv) 'balls (balls-new lv) 'deep 0 'kitty 0 'kp 1
                   'done 0 'msg () 'msg-t 0.0 'err 0}
                  w (h // 2)))
 (corridor-size st w r) (mesh-size st w r)
 ; ..a car's state: 'ph waiting, its door opening, shutting, held shut, going and gone; 't the
 ; seconds in it, 'door how open, 'o how far along its track, 'v how fast
 (cars-new lv) (map (_ \ {'ph 'wait 't 0.0 'door 0.0 'o 0.0 'v 0.0}) (peep lv 'cars ()))
 ; --- moving: where the body's round, at its feet and at its head, is all air, and not
 ;     through a door that is not open. a car's track is its own: its inside while it
 ;     stands, its doorway while the door is open, and nowhere else, so the platform's edge
 ;     stops a walk once the car is gone ---
 (car-track? c x z) (: ac (c 'ax = 'z ? z x) (c 'c0 - car-t < ac && ac < c 'c1 + car-t))
 ; ..and any of the body on it, so the door waits for the whole of the player
 (car-near? c x z) (: ac (c 'ax = 'z ? z x) (c 'c0 - car-t - body-r < ac && ac < c 'c1 + car-t + body-r))
 (car-stands? s) (elem (s 'ph) ['wait 'open 'shut 'hold])
 (car-free? c s x z) (: al (c 'ax = 'z ? x z) ac (c 'ax = 'z ? z x) w (c 'side + c 'out * car-t)
   (car-stands? s && ((c 'a0 < al && al < c 'a1 && c 'c0 < ac && ac < c 'c1)
                      || (s 'door >= 0.85 && mag (al - c 'dc) < 0.5 * c 'dw
                          && min2 (c 'side) w <= ac && ac <= max2 (c 'side) w))))
 (corridor-free? st x z) (: r body-r lv (st 'lvl) bs (st 'sc 'brushes) cs (peep lv 'cars ())
   ring (map (k \ (: a (k * pi / 4.0) [(x + r * cos a) (z + r * sin a)])) ^8) pts ([x z] . ring)
   (shut? i) (: d (lv 'doors i) al (d 'ax = 'z ? x z) ac (d 'ax = 'z ? z x)
     (st 'doors i < 0.85 && mag (al - d 'c) < 0.5 * d 'w + r && d 'a - r < ac && ac < d 'b + r))
   fl (st 'py - eye-h)
   ; ..a pane stops a body, a hand either side of it, where it spans feet or head
   (pane? q) (any (p \ (: lo (p 'lo) hi (p 'hi) th 0.1
                       (lo 0 - th < q 0 && q 0 < hi 0 + th && lo 2 - th < q 1 && q 1 < hi 2 + th
                        && any (y \ lo 1 <= y && y <= hi 1) [(fl + 0.3) (fl + 1.7)])))
               (peep lv 'panes ()))
   (air q) (: on (filter (i \ car-track? (cs i) (q 0) (q 1)) ^#cs)
     (two? on ? (all (i \ car-free? (cs i) (st 'cars i) (q 0) (q 1)) on)
        (brush-medium bs [(q 0) (fl + 0.3) (q 1)] = 1 && brush-medium bs [(q 0) (fl + 1.7) (q 1)] = 1)))
   (all air pts && !(any pane? pts) && !(any shut? ^#(lv 'doors))))
 jump-v 4.4                               ; up near a metre
 mantle-h 0.6                             ; how far over the feet a ledge is hoisted onto
 (put! st x z) (walk-slide st x z corridor-free?)
 hoist-s 0.35                             ; seconds a pull up takes
 ; ..in the air against a ledge no more than mantle-h over the feet, a pull up onto it where
 ; a body fits: the ledge looked for a body's breadth on the way, and stood on as far in
 (hoist! st x z) (: fl (st 'py - eye-h) dx (x - st 'px) dz (z - st 'pz) d (max2 1e-9 (sqrt (dx * dx + dz * dz)))
   cx (x + body-r * dx / d) cz (z + body-r * dz / d) t (floor-at (st 'sc 'brushes) cx cz (fl + mantle-h)) y0 (st 'py)
   (? (!(charm? t || gem? t) || t <= fl + 0.001 || t > fl + mantle-h + 0.001) 0
      (: _ (pin st 'py (t + eye-h)) ok (corridor-free? st cx cz) _ (pin st 'py y0)
         (ok ? (: _ (pins st 'fv 0.0 'hoist {'y0 y0 'y1 (t + eye-h) 'x0 (st 'px) 'z0 (st 'pz) 'x1 cx 'z1 cz 'k 0.0}) 1) 0))))
 ; ..the pull up under way: up first, then in over the edge, eased at both ends
 (hoisting! st dt) (: h (st 'hoist) k (min2 1.0 (h 'k + dt / hoist-s)) (e a b u) (a + (b - a) * u * u * (3.0 - 2.0 * u))
   a (min2 1.0 (k / 0.7)) b (max2 0.0 ((k - 0.4) / 0.6))
   _ (pins st 'py (e (h 'y0) (h 'y1) a) 'px (e (h 'x0) (h 'x1) b) 'pz (e (h 'z0) (h 'z1) b) 'fv 0.0 'mf 0 'ms 0 'vx 0.0 'vz 0.0)
   (pin st 'hoist (k >= 1.0 ? () (pin h 'k k))))
 (hoisting? st) (tablet? (peep st 'hoist ()))
 ; ..the mouse's motion, as far as a pixel turns
 mouse-k 0.0025
 (corridor-look st dx dy) (walk-look st dx dy {'mouse mouse-k 'up 1.3 'down -1.2})
 ; ..the corridor's own keys, over view's
 corridor-binds {112 'where 119 'forward 115 'back 97 'strafe-left 100 'strafe-right 32 'jump}
 ; ..each action as far as the time since the last frame, 'dt, carries it; a step is a
 ; way to go, summed for the frame's walk
 (corridor-step st a) (: dt (peep st 'dt (1.0 / fps))
   (go f s) (pins st 'mf (peep st 'mf 0 + f) 'ms (peep st 'ms 0 + s))
   (a @ 'forward (go 1 0) 'back (go -1 0) 'strafe-left (go 0 -1) 'strafe-right (go 0 1)
      'jump (peep st 'fv 0.0 = 0.0 && peep st 'gv 0.0 = 0.0 && !(hoisting? st) ? (pin st 'fv jump-v) st)
      x (walk-key st a {'turn (turn-v * dt) 'walk (walk-v * dt) 'tilt (tilt-v * dt) 'up 1.3 'down -1.2} put!
         @ () (a = 'where ? (pin st 'pos (1 - peep st 'pos 0)) st)
           s s)))
 ; ..the frame's walk: the ways summed, no faster for two at once, and how fast it went
 (walk! st dt) (: f (peep st 'mf 0) s (peep st 'ms 0) n (sqrt (f * f + s * s)) th (st 'th) x0 (st 'px) z0 (st 'pz)
   _ (? (n > 0) (: k (walk-v * dt / max2 1.0 n) x (x0 + k * (f * sin th + s * cos th)) z (z0 + k * (f * cos th - s * sin th))
                  (peep st 'fv 0.0 != 0.0 && !(corridor-free? st x z) && hoist! st x z ? st (put! st x z))))
   (pins st 'mf 0 'ms 0 'vx ((st 'px - x0) / dt) 'vz ((st 'pz - z0) / dt)))
 ; a frame's motion: the clock, each door toward open while the player is near it, and the cars
 (corridor-move st) (: dt (peep st 'dt (1.0 / fps)) up (hoisting? st) _ (up ? (hoisting! st dt) (walk! st dt)) lv (st 'lvl) x (st 'px) z (st 'pz)
   (go i) (: d (lv 'doors i) o (st 'doors i) p (P (d 'ax) (d 'c) 0.0 (0.5 * (d 'a + d 'b)))
             want (sq (p 0 - x) + sq (p 2 - z) < sq door-near ? 1.0 0.0)
             (want < o ? (max2 want (o - door-v * dt)) (min2 want (o + door-v * dt))))
   _ (pins st 'mt (st 'mt + dt) 'doors (map go ^#(lv 'doors)))
   _ (grav-step st dt)
   _ (hoisting? st ? st (floor-step st dt))
   _ (each (peep st 'balls ()) (b \ ball-step st b dt))
   (foldl (\ st i (car-step st (lv 'cars i) (st 'cars i) dt)) st ^#(peep lv 'cars ())))
 ; ..a grav shaft carries who stands in it toward its floor, gathering speed and easing in
 (grav-step st dt) (: x (st 'px) z (st 'pz) fl (st 'py - eye-h) v (peep st 'gv 0.0)
   in (filter (g \ g 'lo 0 < x && x < g 'hi 0 && g 'lo 2 < z && z < g 'hi 2) (peep (st 'lvl) 'gravs ()))
   (two? in
    ? (: g <in d ((g 'dir = 'up ? (g 'hi 1) (g 'lo 1)) - fl)
         want ((d < 0.0 ? -1.0 1.0) * grav-v * sat (mag d / 0.8 + 0.08)) v2 (v + (want - v) * sat (3.0 * dt))
         m (v2 * dt) step (mag m > mag d ? d m)
         (pins st 'py (fl + step + eye-h) 'gv v2))
      (pin st 'gv 0.0)))
 ; ..what the feet stand on: a step up climbed, a step down or an edge fallen from to what
 ; is under, a jump flown till it comes down on something; not in a grav shaft nor on a
 ; car's track, whose floors are their own
 climb-v 2.5 fall-g 9.8
 ; ..the top of the floor within a few steps of fl, by halves to a hair, or () for none
 (floor-at bs x z fl) (: (air? y) (brush-medium bs [x y z] = 1)
   (top a b) (foldl (\ q _ (: m (0.5 * (q 0 + q 1)) (air? m ? [(q 0) m] [m (q 1)]))) [a b] ^7 @ q (q 1))
   (dn i) (? (i > 12) () (air? (fl - 0.05 * i) ? (dn (i + 1)) (top (fl - 0.05 * i) (fl - 0.05 * (i - 1)))))
   (up i) (? (i > 7) fl (air? (fl + 0.05 * i) ? (top (fl + 0.05 * (i - 1)) (fl + 0.05 * i)) (up (i + 1))))
   (air? (fl - 0.01) ? (dn 1) (up 1)))
 (floor-step st dt) (: x (st 'px) z (st 'pz) fl (st 'py - eye-h) lv (st 'lvl)
   shaft (any (g \ g 'lo 0 < x && x < g 'hi 0 && g 'lo 2 < z && z < g 'hi 2) (peep lv 'gravs ()))
   (? (shaft || any (c \ car-track? c x z) (peep lv 'cars ())) (pin st 'fv 0.0)
      (: f (floor-at (st 'sc 'brushes) x z fl) v (peep st 'fv 0.0) got (charm? f || gem? f)
         (? (got && v <= 0.0 && f > fl + 0.001) (pins st 'py (min2 f (fl + climb-v * dt) + eye-h) 'fv 0.0)
            (got && v <= 0.0 && f >= fl - 0.001) (pin st 'fv 0.0)
            (: v2 (v - fall-g * dt) n (fl + v2 * dt)
               (got && n <= f ? (pins st 'py (f + eye-h) 'fv 0.0) (pins st 'py (n + eye-h) 'fv v2)))))))
 ; ..a ball's next moment: met by the player's feet it is kicked away along the line between,
 ; the harder as they came; then it falls, bounces off what is solid a little less each
 ; time, and rolls along the ground to a stop
 (balls-new lv) (map (p \ {'p [(p 0) (p 1 + ball-r) (p 2)] 'v [0.0 0.0 0.0] 'q [1.0 0.0 0.0 0.0] 'kt -9.0 'rest 1 'pk ()})
                     (peep lv 'balls ()))
 (ball-step st b dt) (: p (b 'p) fl (st 'py - eye-h) dx (p 0 - st 'px) dz (p 2 - st 'pz) d (sqrt (dx * dx + dz * dz))
   kick (d < body-r + ball-r && p 1 - ball-r < fl + 0.5 && st 'mt - b 'kt > 0.25)
   _ (? kick (: th (st 'th) n (d > 0.001 ? [(dx / d) (dz / d)] [(sin th) (cos th)])
                k (ball-kick + 1.3 * max2 0.0 (peep st 'vx 0.0 * n 0 + peep st 'vz 0.0 * n 1))
                (pins b 'v [(k * n 0) (1.0 + 0.3 * k) (k * n 1)] 'kt (st 'mt) 'rest 0,
                 mix-cry st "bounce" [(p 0) (p 2)])))
   (b 'rest = 1 ? st (ball-fly st b dt)))
 ; ..its flight in steps short beside its size: each way on its own, back off what it would
 ; meet; among only the brushes and panes near it
 (ball-fly st b dt) (: r ball-r p0 (b 'p) lv (st 'lvl)
   bs (filter (c \ all (k \ c 'lo k - 1.0 <= p0 k && p0 k <= c 'hi k + 1.0) ^3) (st 'sc 'brushes))
   (solid? q) (brush-medium bs q != 1
               || any (w \ w 'lo 0 - 0.05 < q 0 && q 0 < w 'hi 0 + 0.05 && w 'lo 1 < q 1 && q 1 < w 'hi 1
                            && w 'lo 2 - 0.05 < q 2 && q 2 < w 'hi 2 + 0.05) (peep lv 'panes ()))
   n (max2 1 (min2 10 (int (mag3 (b 'v) * dt / (0.5 * r)) + 1))) h (dt / n)
   (set3 p k x) (map (j \ j = k ? x (p j)) ^3)
   (axis s k) (: p (s 0) v (s 1) vk (v k) q (set3 p k (p k + vk * h + (vk < 0.0 ? (0.0 - r) r)))
     (? (solid? q) (: u (0.0 - ball-e * vk) gr (k = 1 && vk < 0.0)
                      [p (set3 v k (gr && mag u < 0.5 ? 0.0 u)) (max2 (s 2) (mag vk)) (s 3 || gr)])
        [(set3 p k (p k + vk * h)) v (s 2) (s 3)]))
   (sub1 s _) (: v (s 1) (foldl axis [(s 0) [(v 0) (v 1 - ball-g * h) (v 2)] (s 2) (s 3)] ^3))
   e (foldl sub1 [p0 (b 'v) 0.0 0] ^n) p (e 0)
   ; ..on the ground it rolls, slowing, turning as far as it goes, and stops once slow
   gnd (solid? [(p 0) (p 1 - r - 0.02) (p 2)]) f (gnd ? (max2 0.0 (1.0 - 0.7 * dt)) 1.0)
   v (e 1 @ v [(f * v 0) (v 1) (f * v 2)])
   still (gnd && mag3 v < 0.06)
   _ (? gnd (pin b 'w [(v 2 / r) 0.0 (0.0 - v 0 / r)]))
   q (b 'q) w (peep b 'w [0.0 0.0 0.0])
   dq [(0.0 - dot w (drop 1 q)) 0.0 0.0 0.0]
   wq (c+ (c* (q 0) w) (cross w (drop 1 q)))
   q2 (map (j \ q j + 0.5 * dt * (j = 0 ? (dq 0) (wq (j - 1)))) ^4) ql (sqrt (net (map sq q2)))
   _ (pins b 'p p 'v (still ? [0.0 0.0 0.0] v) 'q (map (x \ x / ql) q2) 'rest (still ? 1 0) 'pk ())
   (e 2 > 1.2 ? (mix-cry st "bounce" [(p 0) (p 2)]) st))
 ; ..its mesh about its middle: orange, three seams round it standing just proud, every
 ; triangle's front outward
 (ball-mesh _) (: r ball-r nl 8 nm 16 skin [0.85 0.33 0.08] seam [0.07 0.04 0.03]
   (vx p k col) [(k * p 0) (k * p 1) (k * p 2) 0.0 0.0 (p 0) (p 1) (p 2) (col 0) (col 1) (col 2)]
   body (map (q \ (: a (pi * (q // (nm + 1) / nl - 0.5)) o (tau * (q % (nm + 1)) / nm)
                    (vx [(cos a * sin o) (sin a) (cos a * cos o)] r skin)))
             ^((nl + 1) * (nm + 1)))
   (at i j) (i * (nm + 1) + j)
   bt (cats (map (k \ (: i (k // nm) j (k % nm) a (at i j) b (at i (j + 1)) c (at (i + 1) (j + 1)) d (at (i + 1) j)
                        [[a b c -1] [a c d -1]]))
                 ^(nl * nm)))
   m 32
   (band u v w) (cats (map (j \ (: t (tau * j / m) c (c+ (c* (cos t) u) (c* (sin t) v))
                                  [(vx (unit (c+ c (c* 0.07 w))) (1.015 * r) seam) (vx (unit (c+ c (c* -0.07 w))) (1.015 * r) seam)]))
                       ^(m + 1)))
   (btris o) (cats (map (j \ (: a (o + 2 * j) [[a (a + 1) (a + 3) -1] [a (a + 3) (a + 2) -1]])) ^m))
   x [1.0 0.0 0.0] y [0.0 1.0 0.0] z [0.0 0.0 1.0] o1 #body o2 (o1 + 2 * (m + 1)) o3 (o2 + 2 * (m + 1))
   vs (body + band x z y + band y z x + band x y z)
   (out t) (: a (vs (t 0)) b (vs (t 1)) c (vs (t 2)) e (take 3 a)
     (dot (cross (c+ (take 3 c) (c* -1.0 e)) (c+ (take 3 b) (c* -1.0 e))) (c+ e (c+ (take 3 b) (take 3 c))) < 0.0
      ? [(t 0) (t 2) (t 1) (t 3)] t))
   (mesh-pack (mesh vs (map out (bt + btris o1 + btris o2 + btris o3)))))
 ; ..the ball's mesh turned and moved to where it is, lit there
 (ball-pk sc b) (: pk (sc 'ball) c (pk 'cols) p (b 'p) q (b 'q) w (q 0) x (q 1) y (q 2) z (q 3)
   R [[(1.0 - 2.0 * (y * y + z * z)) (2.0 * (x * y - w * z)) (2.0 * (x * z + w * y))]
      [(2.0 * (x * y + w * z)) (1.0 - 2.0 * (x * x + z * z)) (2.0 * (y * z - w * x))]
      [(2.0 * (x * z - w * y)) (2.0 * (y * z + w * x)) (1.0 - 2.0 * (x * x + y * y))]]
   (rot k o) (R k 0 * c o + R k 1 * c (o + 1) + R k 2 * c (o + 2))
   pk2 {'n (pk 'n) 'tris (pk 'tris)
        'cols [(rot 0 0 + p 0) (rot 1 0 + p 1) (rot 2 0 + p 2) (c 3) (c 4) (rot 0 5) (rot 1 5) (rot 2 5) (c 8) (c 9) (c 10)]}
   {'pk pk2 'lit (sc 'lit pk2)})
 ; ..a car's next moment: the door opens as the level starts and stays open while any of the
 ; player is in its track; once they are out it shuts, opening again if they come back
 ; before it is home; held shut a moment, the car gathers speed along its track and is gone
 ; once it is leave along. each change cries its sound from the doorway
 (car-at c o) (: p (P (c 'ax) (c 'dc + o) 0.0 (c 'side)) [(p 0) (p 2)])
 (car-step st c s dt) (: in (car-near? c (st 'px) (st 'pz)) t (s 't + dt) dr (s 'door) at (car-at c (s 'o))
   (s 'ph @ 'wait (t < car-wait ? (pin s 't t, st) (pins s 'ph 'open 't 0.0, mix-cry (mix-cry st "chime" at) "hiss" at))
            'open (: d (min2 1.0 (dr + door-v * dt))
                    (d = 1.0 && !in ? (pins s 'door d 'ph 'shut, mix-cry (mix-cry st "chime" at) "hiss" at) (pin s 'door d, st)))
            'shut (? in (pin s 'ph 'open, mix-cry st "hiss" at)
                     (: d (max2 0.0 (dr - door-v * dt))
                        (d = 0.0 ? (pins s 'door d 'ph 'hold 't 0.0, mix-cry st "thud" at) (pin s 'door d, st))))
            'hold (t < car-hold ? (pin s 't t, st) (pins s 'ph 'go 't 0.0, mix-cry st "motor" at))
            'go (: v (s 'v + car-acc * dt) o (s 'o + v * dt * (c 'leave < 0.0 ? -1.0 1.0))
                  (mag o >= mag (c 'leave) ? (pins s 'ph 'gone 'o (c 'leave), st) (pins s 'v v 'o o, st)))
            st))
 ; --- the sounds, made: a chime of two falling notes, the door's hiss and its thud home, and
 ;     the motor rising as the car leaves; each [samples rate] for the mixer ---
 snd-rate 11025
 (snd-t secs) (iota (int (secs * snd-rate)) / (1.0 * snd-rate))
 ; ..noise from a hash of each sample's time, about -1..1
 (snd-noise t) (: h (sin (t * 12345.678 + 0.5) * 43758.5453) (2.0 * (h - floor h) - 1.0))
 (corridor-sound nm) (nm @
   "chime" (: t (snd-t 1.0) a (t < 0.42) (tone f u) (sin (tau * f * u) * exp (-5.0 * u))
             [(0.35 * (a * tone 659.3 t + (1 - a) * tone 523.3 (t - 0.42))) snd-rate])
   "hiss" (: t (snd-t 0.7) [(0.25 * snd-noise t * exp (-4.0 * t) * min (t * 40.0) 1.0) snd-rate])
   "bounce" (: t (snd-t 0.25) [(0.6 * sin (tau * 150.0 * t) * exp (-22.0 * t) + 0.25 * snd-noise t * exp (-60.0 * t)) snd-rate])
   "thud" (: t (snd-t 0.3) [(0.8 * sin (tau * 70.0 * t) * exp (-18.0 * t) + 0.15 * snd-noise t * exp (-40.0 * t)) snd-rate])
   "motor" (: t (snd-t 6.0) f0 90.0 k 110.0 up (min (t / 1.5) 1.0) down (min ((6.0 - t) / 2.0) 1.0)
             [(up * down * (0.3 * sin (tau * (f0 * t + 0.5 * k * t * t)) + 0.12 * snd-noise t)) snd-rate])
   ())
 ; --- the files watched: the level and its pictures, each by its stat stamp. a change reads
 ;     the level again, keeping the player where they stand; one that will not read keeps the
 ;     last and says why ---
 (stamp p) (stat p @ s (two? s ? [(s 0) (s 3) (s 8)] ()))
 (files st) (: p (st 'path)
   (string? p ? (p . filter string? (map (q \ file-of (st 'dir) q) (st 'lvl 'posters))) ()))
 (seen! st) (pin st 'stamps (map (p \ [p (stamp p)]) (files st)))
 (corridor-watch st) (: was (peep st 'stamps ())
   (? (atom? was) (seen! st)
      (all (q \ stamp (q 0) = q 1) was) st
      (: lv (corridor-load (st 'path))
         (? (string? lv) (pins (seen! st) 'msg lv 'err 1 'msg-t (st 'mt))
            (: ds (#(lv 'doors) = #(st 'lvl 'doors) ? (st 'doors) (map (_ \ 0.0) (lv 'doors)))
               cs (#(peep lv 'cars ()) = #(peep st 'cars ()) ? (st 'cars) (cars-new lv))
               bl (#(peep lv 'balls ()) = #(peep st 'balls ()) ? (st 'balls) (balls-new lv))
               _ (each bl (b \ pin b 'pk ()))
               (seen! (pins st 'lvl lv 'sc (scene lv (st 'dir) (st 'sc) (loader st)) 'doors ds 'cars cs 'balls bl 'msg ("read " + st 'path + " again")
                               'err 0 'msg-t (st 'mt))))))))
 (dir-of p) (: (go i) (i < 0 ? "" (p i = 47 ? (snip p 0 (i + 1)) (go (i - 1)))) (go (#p - 1)))
 ; --- the walk, on view's loop; corridor-run raises the stage. o 'loading draws the loading
 ;     screen, as view-loading calls it; view-spin unless said ---
 (corridor-walk o lv)
   (view-walk {'new (w \ h \ (: p (o 'level) win (peep o 'win ())
                               ld (_ \ view-loading win (tablet? win ? (window-size win @ s [0 0 (s 0) (s 1)]) [0 0 w (h // 2)]) (peep o 'loading view-spin))
                               st (pins (state-new w h lv (dir-of p) ld) 'deep (o 'md = 'window || view-deep? ()) 'kitty (mesh-mode (o 'md))
                                        'win (peep o 'win ()) 'path p 'scale (peep o 'scale 2))
                               (corridor-watch (corridor-size st w (h // 2)))))
               'size corridor-size 'frame corridor-frame 'key corridor-step 'look corridor-look
               'binds (view-bind view-binds corridor-binds) 'listed (view-listed ['strafe-left 'strafe-right 'jump 'where 'finer 'coarser])
               'walking (view-walking + ['strafe-left 'strafe-right]) 'repeat [0 0]
               'tick (st \ (walk-dt st,
                            corridor-move st,
                            (st 't % watch-every = 0 ? (corridor-watch st))))
               'fps fps 'linger 0 'next ()
               'song (hn \ (hn ? (mix-new hn corridor-sound (st \ [(st 'px) (st 'pz) (st 'th)]) {'near 2.0 'far 40.0 'fps fps 'gain 12000.0}) ()))
               'win (peep o 'win ())})
 ; ..the level named, else the tree's own on disk, else the one the binary carries
 (corridor-run o) (: p (o 'level @ () (two? (stat the-level) ? the-level ("/love/" + the-level)) q q)
                     lv (corridor-load p)
   (? (string? lv) (say err ("corridor: " + p + ": " + lv + "\n"), flush err, 1)
      (view-stage (pin o 'level p) (o2 \ corridor-walk o2 lv) (_ \ (say out mesh-gone, flush out)))))
 corridor-usage "usage: love lore corridor [--level FILE] [--kitty|--cells|--window] [--scale 1|2|4|8]   (w s or k j step, a d sidestep, space jumps and pulls up onto a ledge, h l turn, u n look, walk into a ball to kick it, p where you stand; ? the keys; in a window a click looks by the mouse and esc lets it go; q or esc leaves; the level is read again when it changes)"
 ; the words, as a tablet for corridor-run, or () where one is wrong or said twice
 (corridor-opts as) (view-words as [(view-flag "--kitty" 'md 'kitty) (view-flag "--cells" 'md 'cells) (view-flag "--window" 'md 'window) view-scale
                                    (view-arg "--level" 'level (w \ w))])
 (corridor-main as) (view-main "corridor" corridor-usage corridor-opts corridor-run as)
 ; --- the editor: the level's text in vi on the right and its scene on the left, in one
 ;     window. ctrl-w w goes between them, a click on the scene puts vi on the form that made
 ;     what it hit, the right button held looks by the mouse, and coming back to the scene
 ;     reads it again from vi's text when that has changed; vi's :w writes the file ---
 edit-s 2                                ; a scene pixel, edit-s by edit-s of the window's
 (edit-lay W H) (: sw (W // 2 // edit-s * edit-s)
   {'W W 'H H 'sw sw 'pw (sw // edit-s) 'ph (H // edit-s // 2 * 2) 'cols ((W - sw) // 8) 'rows (H // 16)})
 (edit-text ls) (foldl (a \ l \ a + l + "\n") "" ls)
 ; ..the screen vi's frames are scribed onto, cols by rows
 (edit-screen ly) (screen (cask (screen () (ly 'rows) (ly 'cols))) (ly 'rows) (ly 'cols))
 ; ..the scene read again from vi's text, when it is not what the scene was read from
 (edit-sync ed) (: vi (ed 'vi) vs (ed 'vs) t (edit-text (vs 'lines)) st (ed 'st)
   (? (t = ed 'text) ed
      (: lv (corridor-read t)
         (? (string? lv) (vi 'vmsg vs ("scene: " + lv), pins ed 'text t 'dirty 1)
            (: ds (#(lv 'doors) = #(st 'lvl 'doors) ? (st 'doors) (map (_ \ 0.0) (lv 'doors)))
               _ (pins st 'lvl lv 'sc (scene lv (st 'dir) (st 'sc) (loader st)) 'doors ds 'cars (cars-new lv) 'balls (balls-new lv))
               (vi 'vmsg vs "scene read again", pins ed 'text t 'dirty 1))))))
 ; ..vi's cursor on the text's offset a, its line a third of the way down the pane
 (edit-at ed a) (: t (ed 'text) vs (ed 'vs) (bol i) (i < 0 || t i = 10 ? (i + 1) (bol (i - 1))) l0 (bol (a - 1))
   r (net (map (i \ t i = 10) ^l0))
   (pins vs 'row r 'col (a - l0) 'top (max2 0 (r - (ed 'lay 'rows) // 3)) 'tops 0, pin ed 'dirty 1, r))
 ; ..what the scene's pixel x y shows chosen, vi on the form that made it, and a drag begun
 ; from where it was hit: across the floor's level, or with shift held across the face hit,
 ; squared to its nearest axis
 (edit-pick ed x y) (: vi (ed 'vi) vs (ed 'vs) t (ed 'text) st (ed 'st) h (corridor-pick st x y)
   sp (tablet? h ? (corridor-span t (h 'src)) ())
   (? (atom? sp) (pins ed 'sel () 'drag (), vi 'vmsg vs (tablet? h ? "nothing in the text made that" "nothing there"))
      (: p (h 'p) hn (h 'n) ax (? (mag (hn 0) >= mag (hn 1) && mag (hn 0) >= mag (hn 2)) 0 (mag (hn 1) >= mag (hn 2)) 1 2)
         n (? !(ed 'shift) [0.0 1.0 0.0] (map (i \ i = ax ? 1.0 0.0) ^3))
         (pins ed 'sel (h 'src) 'drag {'p0 p 'n n 'c (dot n p) 'off [0.0 0.0 0.0]},
          vi 'vmsg vs ("line " + show (edit-at ed (sp 0) + 1))))))
 ; ..the drag to where the ray through x y meets its plane, a twentieth of a metre at a time
 (edit-drag ed x y) (: g (ed 'drag) r (corridor-ray (ed 'st) x y) e (r 0) d (r 1) n (g 'n) k (dot n d)
   t (mag k < 1e-6 ? -1.0 ((g 'c - dot n e) / k))
   (t > 0.0 ? (: q (c+ e (c* t d)) (pin g 'off (map (i \ floor (20.0 * (q i - g 'p0 i) + 0.5) / 20.0) ^3))) g))
 ; ..a number as the text says it, a twentieth at most
 (edit-num x) (: k (floor (20.0 * x + 0.5)) (k % 20 = 0 ? (show (k // 20)) (show (k / 20.0))))
 (edit-vec v) ("[" + edit-num (v 0) + " " + edit-num (v 1) + " " + edit-num (v 2) + "]")
 (edit-lines t) (: (go i j acc) (? (i >= #t) (rev (j < i ? ((snip t j i) . acc) acc)) (t i = 10) (go (i + 1) (i + 1) ((snip t j i) . acc)) (go (i + 1) j acc))
   (go 0 0 ()))
 ; ..the drag let go: the chosen form in a (move ..) by as far, or its move's by further,
 ; or none where that comes to nothing; vi's text that, undoably, and the scene read again
 (edit-drop ed) (: g (ed 'drag) off (g 'off) t (ed 'text) sp (corridor-span t (ed 'sel))
   _ (pin ed 'drag ())
   (? (all (i \ off i = 0.0) ^3 || atom? sp) ed
      (: a (sp 0) b (sp 1) ks (sx-kids t a) hd (two? ks ? (snip t (ks 0 0) (ks 0 1)) "")
         vk (#ks = 3 && t (ks 1 0) = 91 ? (sx-kids t (ks 1 0)) ())
         base (map (k \ <(sounds (snip t (k 0) (k 1))) @ n (charm? n || gem? n ? n 'no)) vk)
         mv (hd = "move" && #base = 3 && !(elem 'no base))
         to (map (i \ (mv ? (base i) 0) + off i) ^3) inner (mv ? (snip t (ks 2 0) (ks 2 1)) (snip t a b))
         f2 (all (i \ mag (to i) < 0.025) ^3 ? inner ("(move " + edit-vec to + " " + inner + ")"))
         (edit-put ed (snip t 0 a + f2 + snip t b #t) ("moved to " + edit-vec to)))))
 ; ..vi's text t, undoably, the cursor where it was, the scene read again, and m said
 (edit-put ed t m) (: vs (ed 'vs) vi (ed 'vi) row (vs 'row) col (vs 'col) top (vs 'top)
   _ (vi 'vsnap vs) _ (pins vs 'lines (edit-lines t) 'row row 'col col 'top top 'dirty 1) _ (vi 'vgen vs)
   _ (edit-sync ed)
   (vi 'vmsg vs m, ed))
 ; ..the chosen form's brushes' edges, [a b] pairs, as far on as off
 (edit-edges ed off) (: sel (ed 'sel) st (ed 'st) lb (st 'lvl 'brushes) bs (st 'sc 'brushes)
   is (atom? sel ? () (filter (i \ peep (lb i) 'src () = sel) ^#lb))
   (cats (map (i \ cats (map (ps \ (#ps >= 3 ? (map (j \ [(c+ (ps j) off) (c+ (ps ((j + 1) % #ps)) off)]) ^#ps) ())) ((bs i) 'faces))) is)))
 ; ..a line from pixel pa to pb on the w by h frame f, in ink
 edit-ink 16756784
 (edit-line f w h pa pb ink) (: (ab x) (x < 0.0 ? (0.0 - x) x)
   n (min2 3000 (floor (max2 (ab (pb 0 - pa 0)) (ab (pb 1 - pa 1)))) + 1)
   K (iota (n + 1)) X (pa 0 + (pb 0 - pa 0) * K / n) Y (pa 1 + (pb 1 - pa 1) * K / n)
   S (iota ((X >= 0.0) * (X < 1.0 * w) * (Y >= 0.0) * (Y < 1.0 * h)))
   (#S = 0 ? f (pin f (peep (floor Y * w + floor X) S 0) ink)))
 ; ..the chosen form's brushes, outlined on the frame f through whatever is before them, as
 ; far on as a drag has them
 (edit-outline ed f) (: sel (ed 'sel) st (ed 'st)
   (? (atom? sel) f
      (: r (corridor-ray st 0 0) e (r 0) v (r 2) w (v 'w) h (v 'h) rt (v 'r) up (v 'u) fw (v 'f) me (c* -1.0 e)
         foc (w / 2.0 / tan (fov / 2.0)) off (tablet? (ed 'drag) ? (ed 'drag 'off) [0.0 0.0 0.0])
         (pr p) (: d (c+ p me) z (dot d fw) [(w / 2.0 + foc * dot d rt / z) (h / 2.0 - foc * dot d up / z)])
         (cl a b za zb) (c+ a (c* ((0.1 - za) / (zb - za)) (c+ b (c* -1.0 a))))
         (seg f a b) (: za (dot (c+ a me) fw) zb (dot (c+ b me) fw)
           (? (za < 0.1 && zb < 0.1) f
              (edit-line f w h (pr (za < 0.1 ? (cl a b za zb) a)) (pr (zb < 0.1 ? (cl b a zb za) b)) edit-ink)))
         (foldl (\ f q (seg f (q 0) (q 1))) f (edit-edges ed off)))))
 ; --- the plan: the level from above, cut plan-cut over a floor 'fl and seen plan-deep down,
 ;     'k pixels a metre about 'c [x z]; the rock dark, the walls at the cut light, a grid ---
 plan-cut 1.5
 plan-deep 6.0
 plan-rock 1447452
 plan-rule 2763315
 plan-wall 14211296
 plan-me 6348896
 (plan-snap v) (floor (2.0 * v + 0.5) / 2.0)        ; a room's corners, half a metre at a time
 (plan-nudge v) (floor (4.0 * v + 0.5) / 4.0)       ; ..and a move, a quarter
 ; ..the place under pixel x y, and the pixel over the place x z
 (plan-at p w h x y) [(p 'c 0 + (x + 0.5 - w / 2.0) / p 'k) (p 'c 1 + (h / 2.0 - y - 0.5) / p 'k)]
 (plan-px p w h x z) [(w / 2.0 + (x - p 'c 0) * p 'k) (h / 2.0 - (z - p 'c 1) * p 'k)]
 ; ..the floors a plan can be cut over: the bottoms of the airs a body stands up in
 (plan-floors st) (sort (keys (foldl (\ t b (b 'air && b 'hi 1 - b 'lo 1 >= 2.0 ? (pin t (b 'lo 1) 1) t)) {} (st 'sc 'brushes))))
 ; ..the brushes the cut passes through at x z, the last carved first
 (plan-hits ed x z) (: bs (ed 'st 'sc 'brushes) P [x (ed 'plan 'fl + plan-cut) z]
   (rev (filter (i \ all (pl \ dot (pl 0) P <= pl 1 + 1e-6) (bs i 'planes)) ^#bs)))
 ; ..the mask m with brush b laid over it where the cut passes through: 1 air, 0 rock
 (plan-carve m b p w h cut) (: lo (b 'lo) hi (b 'hi) a (plan-px p w h (lo 0) (hi 2)) z (plan-px p w h (hi 0) (lo 2))
   i0 (max2 0 (floor (a 0))) i1 (min2 w (floor (z 0) + 1)) j0 (max2 0 (floor (a 1))) j1 (min2 h (floor (z 1) + 1))
   (? (cut < lo 1 || hi 1 < cut || i1 <= i0 || j1 <= j0) m
      (: nc (i1 - i0) Q (iota (nc * (j1 - j0))) S ((Q // nc + j0) * w + Q % nc + i0)
         X (p 'c 0 + (S % w + 0.5 - w / 2.0) / p 'k) Z (p 'c 1 + (h / 2.0 - S // w - 0.5) / p 'k)
         in (foldl (\ q pl (: n (pl 0) (q * (n 0 * X + n 2 * Z + n 1 * cut <= pl 1 + 1e-6)))) (S * 0 + 1) (b 'planes))
         (pin m (peep S (iota in) 0) (b 'air ? 1 0)))))
 ; ..what stays while the plan does: below the cut, the rooms flat lit straight down; at it,
 ; the rock and the walls; and the rules every metre, or further apart further out
 (plan-base ed p w h) (: st (ed 'st) sc (st 'sc) k (p 'k) c (p 'c) cut (p 'fl + plan-cut) hw (w / 2.0 / k) hh (h / 2.0 / k)
   pk (? (two? (ed 'ppk) && ed 'ppk 0 == sc) (ed 'ppk 1)
         (: l (map (q \ mesh-lamps (q 'pk) [0.9 0.9 0.9] [] [] 1.0) (sc 'chunks)) (pin ed 'ppk [sc l], l)))
   v {'w w 'h h 'cam (gem-tray [16] [(1.0 / hw) 0.0 0.0 (0.0 - c 0 / hw) 0.0 0.0 (1.0 / hh) (0.0 - c 1 / hh)
                                    0.0 (-2.0 / plan-deep) 0.0 (2.0 * cut / plan-deep - 1.0) 0.0 0.0 0.0 1.0])}
   f (mesh-frame v [(map (b \ b 0) pk) (map (b \ b 1) pk)] (sc 'texs) [0.0 0.0 0.0 0.0 0.0] 8 0 plan-rock)
   I (iota (w * h)) m (foldl (\ m b (plan-carve m b p w h cut)) (I * 0) (sc 'brushes))
   wall (m * (1 - (peep m (I - 1) 1) * (peep m (I + 1) 1) * (peep m (I - w) 1) * (peep m (I + w) 1)))
   g (? (k >= 8.0) 1.0 (k >= 2.0) 5.0 10.0)
   cx (c 0 + (iota w + 0.5 - w / 2.0) / k) cz (c 1 + (h / 2.0 - iota h - 0.5) / k)
   cr (floor (cx / g) != floor ((cx + 1.0 / k) / g)) rr (floor (cz / g) != floor ((cz - 1.0 / k) / g))
   rule ((peep cr (I % w) 0) + (peep rr (I // w) 0) > 0)
   A (iota (rule * m)) f1 (pin f A ((peep f A 0 >> 1 & 8355711) + 4737096))
   (pin (pin (pin f1 (iota (m = 0)) plan-rock) (iota (rule * (m = 0))) plan-rule) (iota wall) plan-wall))
 ; ..a plan's frame: its base, the chosen form outlined, what a drag draws, the player
 (plan-pens ed) (: st (ed 'st) p (ed 'plan) dm (mesh-dims st) w <dm h (dm 1) key (show [(p 'c) (p 'k) (p 'fl) w h]) pc (ed 'pc)
   base (? (two? pc && pc 0 == st 'sc && pc 1 = key) (pc 2) (: b (plan-base ed p w h) (pin ed 'pc [(st 'sc) key b], b)))
   (ln f a b ink) (edit-line f w h (plan-px p w h (a 0) (a 2)) (plan-px p w h (b 0) (b 2)) ink)
   (box f a b) (: q [[(a 0) 0.0 (a 1)] [(b 0) 0.0 (a 1)] [(b 0) 0.0 (b 1)] [(a 0) 0.0 (b 1)]] (foldl (\ f j (ln f (q j) (q ((j + 1) % 4)) edit-ink)) f ^4))
   g (ed 'drag) off (tablet? g && g 'kind = 'move ? (g 'off) [0.0 0.0 0.0])
   f1 (foldl (\ f q (ln f (q 0) (q 1) edit-ink)) base (edit-edges ed off))
   f2 (tablet? g && elem (g 'kind) ['rect 'edge] ? (box f1 (g 'a) (g 'b)) f1)
   e [(st 'px) 0.0 (st 'pz)] (by x z) (c+ e [x 0.0 z]) s (sin (st 'th)) o (cos (st 'th)) r (0.15 * 16.0 / p 'k + 0.1)
   (ln (ln (ln f2 (by (0.0 - r) 0.0) (by r 0.0) plan-me) (by 0.0 (0.0 - r)) (by 0.0 r) plan-me) e (by (3.0 * r * s) (3.0 * r * o)) plan-me))
 ; ..the plan's chosen form's corners, where it is a room or a box the scene has only moved:
 ; their numbers' spans 'sa 'sb, the numbers 'a 'b, the shift 'd, the brushes' 'lo and 'hi
 (plan-box ed) (: t (ed 'text) st (ed 'st) sel (ed 'sel) sp (atom? sel ? () (corridor-span t sel))
   (num q) (<(sounds (snip t (q 0) (q 1))) @ n (charm? n ? n ()))
   (form i) (: ks (sx-kids t i) hd (two? ks ? (snip t (ks 0 0) (ks 0 1)) "")
     (? (t i != 40 || atom? ks) ()
        (elem hd ["room" "box"] && #ks >= 3 && t (ks 1 0) = 91 && t (ks 2 0) = 91) [(sx-kids t (ks 1 0)) (sx-kids t (ks 2 0))]
        (form (ks (#ks - 1) 0))))
   lb (st 'lvl 'brushes) bs (st 'sc 'brushes) is (filter (i \ peep (lb i) 'src () = sel) ^#lb)
   vk (atom? sp || atom? is ? () (form (sp 0)))
   (? (atom? vk || #(vk 0) != 3 || #(vk 1) != 3) ()
      (: a (map num (vk 0)) b (map num (vk 1))
         lo (foldl (\ m i (map (k \ min2 (m k) (bs i 'lo k)) ^3)) (bs <is 'lo) is)
         hi (foldl (\ m i (map (k \ max2 (m k) (bs i 'hi k)) ^3)) (bs <is 'hi) is)
         (? !(all charm? a && all charm? b) ()
            (: d (map (k \ lo k - min2 (a k) (b k)) ^3)
               (all (k \ mag (hi k - max2 (a k) (b k) - d k) < 1e-3) ^3 ? {'sa (vk 0) 'sb (vk 1) 'a a 'b b 'd d 'lo lo 'hi hi} ()))))))
 ; ..a drag begun on an edge of the chosen box, within three pixels, that moves that wall
 (plan-edge ed x y) (: p (ed 'plan) dm (mesh-dims (ed 'st)) w <dm h (dm 1) pb (plan-box ed)
   (? !(tablet? pb) ()
      (: lo (pb 'lo) hi (pb 'hi) a (plan-px p w h (lo 0) (lo 2)) b (plan-px p w h (hi 0) (hi 2)) X (x + 0.5) Y (y + 0.5)
         inx (a 0 - 3.0 <= X && X <= b 0 + 3.0) iny (b 1 - 3.0 <= Y && Y <= a 1 + 3.0)
         e (? (iny && mag (X - a 0) <= 3.0) [0 0] (iny && mag (X - b 0) <= 3.0) [0 1]
              (inx && mag (Y - a 1) <= 3.0) [2 0] (inx && mag (Y - b 1) <= 3.0) [2 1] ())
         (two? e ? {'kind 'edge 'ax (e 0) 'hi (e 1) 'pb pb 'a [(lo 0) (lo 2)] 'b [(hi 0) (hi 2)]} ()))))
 ; ..the plan clicked: on the chosen box's edge, a drag of that wall; with shift held, a room
 ; drawn; else what the cut passes through there chosen, vi on its form, and a drag of it
 (plan-press ed b x y) (: p (ed 'plan) vi (ed 'vi) vs (ed 'vs) dm (mesh-dims (ed 'st)) w <dm h (dm 1) q (plan-at p w h x y) k (p 'k)
   (? (b = 3) (pin ed 'pan [x y])
      (elem b [4 5]) (: k2 (max2 2.0 (min2 64.0 (b = 4 ? (k * 1.25) (k / 1.25))))
                        (pins p 'k k2 'c (map (i \ q i - (q i - p 'c i) * k / k2) ^2)))
      (b != 1) ed
      (: eg (plan-edge ed x y) hs (plan-hits ed (q 0) (q 1)) bs (ed 'st 'sc 'brushes) lb (ed 'st 'lvl 'brushes)
         (src i) (peep (peep lb i {}) 'src ())
         (? (tablet? eg) (pin ed 'drag eg)
            (ed 'shift) (: r (map plan-snap q) (pin ed 'drag {'kind 'rect 'a r 'b r 'in (filter (i \ bs i 'air) hs)}))
            (: tk (filter (i \ two? (src i)) hs) sp (two? tk ? (corridor-span (ed 'text) (src <tk)) ())
               (? (atom? sp) (pins ed 'sel () 'drag (), vi 'vmsg vs "nothing there")
                  (pins ed 'sel (src <tk) 'drag {'kind 'move 'q0 q 'off [0.0 0.0 0.0]},
                   vi 'vmsg vs ("line " + show (edit-at ed (sp 0) + 1)))))))))
 ; ..the pointer moved: the plan panned, or the drag on as far as the pointer
 (plan-move ed x y) (: p (ed 'plan) g (ed 'drag) dm (mesh-dims (ed 'st)) w <dm h (dm 1) q (plan-at p w h x y) o (ed 'pan)
   (? (two? o) (pins p 'c [(p 'c 0 - (x - o 0) / p 'k) (p 'c 1 + (y - o 1) / p 'k)], pin ed 'pan [x y])
      !(tablet? g) ed
      (g 'kind = 'move) (pin g 'off [(plan-nudge (q 0 - g 'q0 0)) 0.0 (plan-nudge (q 1 - g 'q0 1))])
      (g 'kind = 'rect) (: r (map plan-snap q) a (g 'a)
                           (pin g 'b r, (ed 'vi) 'vmsg (ed 'vs) ("a room " + edit-num (mag (r 0 - a 0)) + " by " + edit-num (mag (r 1 - a 1)))))
      (: j (g 'ax = 0 ? 0 1) s (g 'hi ? 'b 'a) c (g s) v (plan-snap (q j)) (pin g s (j = 0 ? [v (c 1)] [(c 0) v])))))
 ; ..a drawn room let go: into the text after the chosen form's part, or at the end, as high
 ; as the room it was begun in, else plan-cut twice; then it chosen
 (plan-room ed g) (: a (g 'a) b (g 'b) x0 (min2 (a 0) (b 0)) x1 (max2 (a 0) (b 0)) z0 (min2 (a 1) (b 1)) z1 (max2 (a 1) (b 1))
   _ (pin ed 'drag ())
   (? (x1 - x0 < 0.5 || z1 - z0 < 0.5) ed
      (: in (g 'in) bs (ed 'st 'sc 'brushes) y0 (two? in ? (bs <in 'lo 1) (ed 'plan 'fl)) y1 (two? in ? (bs <in 'hi 1) (y0 + 2.0 * plan-cut))
         t (ed 'text) lv <(rev (sx-tops t)) ks (sx-kids t (lv 0)) sel (ed 'sel)
         j (two? sel && sel 0 < #ks ? (sel 0) (#ks - 1)) at (ks j 1)
         (bol i) (i <= 0 || t (i - 1) = 10 ? i (bol (i - 1))) ind (ks j 0 - bol (ks j 0))
         fm ("(room " + edit-vec [x0 y0 z0] + " " + edit-vec [x1 y1 z1] + ")")
         _ (edit-put ed (snip t 0 at + "\n" + foldl (\ a _ (a + " ")) "" ^ind + fm + snip t at #t) "")
         _ (pin ed 'sel [(j + 1)])
         ((ed 'vi) 'vmsg (ed 'vs) ("a room, line " + show (edit-at ed (at + 1 + ind) + 1)), ed))))
 ; ..an edge let go: the number its corner says it in rewritten, the room kept a half metre
 (plan-resize ed g) (: pb (g 'pb) k (g 'ax) j (k = 0 ? 0 1) v (g (g 'hi ? 'b 'a) j) _ (pin ed 'drag ())
   sp (? (g 'hi) (pb 'a k > pb 'b k ? 'sa 'sb) (pb 'a k <= pb 'b k ? 'sa 'sb)) q (pb sp k) t (ed 'text)
   (? (g 'b j - g 'a j < 0.5) ((ed 'vi) 'vmsg (ed 'vs) "too small", ed)
      (mag (v - (g 'hi ? (pb 'hi k) (pb 'lo k))) < 1e-6) ed
      (edit-put ed (snip t 0 (q 0) + edit-num (v - pb 'd k) + snip t (q 1) #t) ("the wall to " + edit-num v))))
 ; ..the plan shown, about the player over the floor they are on, or put away
 (edit-plan ed) (: st (ed 'st) fs (plan-floors st) y (st 'py - eye-h) lo (filter (f \ f <= y + 0.05) fs)
   (? (tablet? (ed 'plan)) (pins ed 'plan () 'drag () 'pan () 'dirty 1)
      (pins ed 'plan {'c [(st 'px) (st 'pz)] 'k 16.0 'fl (two? lo ? <(rev lo) (two? fs ? <fs y))} 'drag () 'dirty 1)))
 ; ..and cut over the next floor up, s 1, or down, s -1
 (plan-step ed s) (: p (ed 'plan) fs (filter (f \ s > 0 ? (f > p 'fl + 0.05) (f < p 'fl - 0.05)) (plan-floors (ed 'st)))
   (? (atom? fs) ed (: f (s > 0 ? <fs <(rev fs)) _ (pin p 'fl f) ((ed 'vi) 'vmsg (ed 'vs) ("the floor at " + edit-num f), ed))))
 ; ..the keys vi wants that the corridor's own keys leave out: backspace, tab, delete, home, end
 edit-set1 {14 8 15 9 339 -4 327 -5 335 -6}
 ; ..a key for vi: what it typed, else the arrows as a terminal sends them
 (edit-bytes t k) (? (0 < #t) t (k @ -1 "\e[D" -2 "\e[C" -8 "\e[A" -9 "\e[B" -4 "\e[3~" -5 "\e[H" -6 "\e[F" 27 "\e" 13 "\r" 8 "\x7f" (charm? k && 0 < k ? (string k) "")))
 (edit-feed ed s) (: key ((ed 'fc) 1) (each ^#s (i \ key (s i))), pin ed 'dirty 1)
 (edit-focus ed f) (: _ (pins ed 'focus f 'dirty 1) (f = 'scene ? (edit-sync ed) ed))
 ; ..a ctrl-w's next key: w the other pane, h the scene, l vi
 (edit-cw ed k) (: _ (pin ed 'cw 0)
   (k @ 119 (edit-focus ed (ed 'focus = 'vi ? 'scene 'vi)) 104 (edit-focus ed 'scene) 108 (edit-focus ed 'vi) _ ed))
 (edit-events ed l) (: st (ed 'st) ly (ed 'lay)
   (? (atom? l) ed
      (: e <l nx (two? >l ? <>l ()) t0 (two? nx && <nx = 'text ? (nx 1) "")
         k0 (? (0 < #t0) (t0 0) (e 1 @ c (charm? c ? (peep view-set1 c (peep edit-set1 c ())) ())))
         ; ..a letter under a held ctrl is its control character
         cl (ed 'ctrl && charm? k0 && 97 <= k0 && k0 <= 122) k (cl ? (k0 - 96) k0) t (cl ? (string k) t0)
         md (e @- () ['down c] (elem c [29 285] ? 1 ()) ['up c] (elem c [29 285] ? 0 ()))
         sh (e @- () ['down c] (elem c [42 54] ? 1 ()) ['up c] (elem c [42 54] ? 0 ()))
         _ (sh != () ? (pin ed 'shift sh))
         _ (md != () ? (pin ed 'ctrl md) (e @- ()
            ['close] (pin ed 'quit 1)
            ['size w h] (: ly2 (edit-lay w h) (pins ed 'lay ly2 'scr (edit-screen ly2) 'dirty 1, corridor-size st (ly2 'pw) (ly2 'ph // 2)))
            ['press b x y] (? (x >= ly 'sw) (edit-focus ed 'vi)
                              (tablet? (ed 'plan)) (edit-focus ed 'scene, plan-press ed b (x // edit-s) (y // edit-s))
                              (b = 3) (pins ed 'look 1 'lx x 'ly y)
                              (b = 1) (edit-focus ed 'scene, edit-pick ed (x // edit-s) (y // edit-s)))
            ['release b x y] (? (b = 3) (pins ed 'look 0 'pan ())
                                (b != 1 || !(tablet? (ed 'drag))) ed
                                (ed 'drag 'kind @ 'rect (plan-room ed (ed 'drag)) 'edge (plan-resize ed (ed 'drag)) _ (edit-drop ed)))
            ['move x y] (? (tablet? (ed 'plan)) (plan-move ed (x // edit-s) (y // edit-s))
                           (ed 'look) (corridor-look st (x - ed 'lx) (y - ed 'ly), pins ed 'lx x 'ly y)
                           (tablet? (ed 'drag) && x < ly 'sw) (edit-drag ed (x // edit-s) (y // edit-s)))
            ['up c] (pin (ed 'held) c ())
            ['down c] (? (ed 'cw) (edit-cw ed k)
                         (k = 23 && (ed 'focus = 'scene || (ed 'vs 'mode) = 'n)) (pin ed 'cw 1)
                         (ed 'focus = 'vi) (edit-feed ed (edit-bytes t k))
                         (k = 27) (pins ed 'sel () 'drag ())
                         (k = 9) (edit-plan ed)
                         (tablet? (ed 'plan) && elem k [91 93]) (plan-step ed (k = 93 ? 1 -1))
                         (charm? k) (: a ((ed 'binds) k) (pin (ed 'held) c a, nom? a && !(elem a ['quit 'help]) ? (corridor-step st a))))))
         (edit-events ed >l))))
 ; ..the scene painted on the left, vi's frame scribed and its rows laid on the right
 (edit-paint ed) (: ly (ed 'lay) W (ly 'W) H (ly 'H) win (ed 'win) P (window-paper win) st (ed 'st) scr (ed 'scr)
   cols (ly 'cols) rows (ly 'rows) tw (8 * cols) sw (ly 'sw)
   _ (frame-paint (tablet? (ed 'plan) ? (plan-pens ed) (edit-outline ed (corridor-pens st))) (ly 'pw) edit-s P W)
   fr ((ed 'fc) 0 cols rows)
   _ (? (0 < #fr || ed 'dirty)
        (: tb (cask (tw * rows * 16 * 4)) cur (gaze scr 0)
           _ (scribe scr fr)
           _ (each ^rows (r \ dye scr tb tw r (cur >= 0 && cur // cols = r ? cur -1) ()))
           _ (each ^(rows * 16) (y \ pour P (4 * (y * W + sw)) tb (4 * y * tw) (4 * tw)))
           (pin ed 'dirty 0)))
   (window-show win 0 H))
 (edit-loop ed) (: t0 (clock 0) st (ed 'st)
   _ (edit-events ed (window-events (ed 'win)))
   _ (each (keys (ed 'held)) (c \ (ed 'held) c @ a (elem a (view-walking + ['strafe-left 'strafe-right]) ? (corridor-step st a))))
   _ (walk-dt st) _ (corridor-move st) _ (pin st 't (st 't + 1))
   _ (edit-paint ed)
   (ed 'quit || (ed 'fc) 2 () ? ()
      (clock 0 - t0 @ spent (spent < 1000 // fps ? (rest (1000 // fps - spent)), edit-loop ed))))
 edit-blank "(level \"nothing yet\" (room [0 0 0] [4 3 4]) (start [2 0 2] 0 0))"
 ; ..the editor on a window, over vi's state vs; its scene's pictures from dir
 (edit-new win vs dir) (: vi (cite 'vi) fc (vi 'vi-face vs {}) wh (window-size win)
   t (edit-text (vs 'lines)) lv0 (corridor-read t) lv (string? lv0 ? (corridor-read edit-blank) lv0)
   ly (edit-lay (wh 0) (wh 1)) st (state-new (ly 'pw) (ly 'ph) lv dir (_ \ view-loading win [0 0 (ly 'sw) (ly 'H)] view-spin))
   _ (string? lv0 ? (vi 'vmsg vs ("scene: " + lv0)))
   {'vi vi 'vs vs 'fc fc 'st st 'win win 'lay ly 'scr (edit-screen ly) 'text t 'focus 'vi 'cw 0 'held {}
    'binds (view-bind view-binds corridor-binds) 'look 0 'quit 0 'dirty 1 'ctrl 0 'shift 0 'sel () 'drag () 'plan () 'pan () 'pc () 'ppk ()})
 (edit-run p) (window-open 1280 720 "lore edit" @ win
   (? !(tablet? win) (say err ("lore edit: no window (" + show win + ")\n"), flush err, 1)
      (: ed (edit-new win ((cite 'vi) 'vi-open p) (dir-of p))
         (mind (_ \ edit-loop ed) () (_ \ window-close win), 0))))
 edit-usage "usage: love lore edit FILE   (the level's text in vi beside its scene: ctrl-w w goes between them; on the scene a click puts vi on what made it and outlines it, a drag moves it across the floor or with shift across the face it was taken by, esc lets it go, the right button held looks, the corridor's keys walk; tab shows the plan from above, [ and ] a floor down or up, the wheel zooms, the right button pans, a click takes what is there and a drag moves it, a drag on its box's edge moves that wall, shift and a drag draws a room; :w writes, :q leaves)"
 (edit-main as) (? (#as = 1) (edit-run <as) (say err (edit-usage + "\n"), flush err, 2))
 _ (cite 'lore 'lore-enlist 'corridor (udoor 'corridor corridor-main corridor-usage 1 1))
 _ (cite 'lore 'lore-enlist 'edit (udoor 'edit edit-main edit-usage 1 1)))
) ; module corridor
