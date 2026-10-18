; corridor -- an indoor level in first person, its rooms read from a level file and read
; again whenever the file changes, so a level can be edited beside the running game.
; a level is a love file in scenery.l's words, its last form (level NAME PART ..); a texture
; is made from its recipe (swatch.l), and a surface no texture names is a grid.
; nothing outside: every light is a lamp (mesh.l), baked once into a channel and summed each
; frame by how bright it is just then. corridor-read, -new, -step, -move and -frame are pure;
; corridor-watch reads the disk, and only corridor-walk and corridor-run touch the tty.
(module (corridor corridor-run corridor-walk corridor-main corridor-new corridor-size corridor-step corridor-binds
         corridor-move corridor-frame corridor-pens corridor-opts corridor-read corridor-load
         corridor-watch corridor-free? corridor-ks corridor-sound fps eye-h body-r)
(borrow 'rove)                          ; pad, for the bottom row
(borrow 'posix)                         ; open, close and stat, for the level and its pictures
(borrow 'view)                          ; the screen, the pens, the hash, the loop
(borrow 'vec)                           ; triples
(borrow 'mesh)                          ; the triangles, the lamps, the frame
(borrow 'neon)                          ; the signs, and the poster's letters
(borrow 'brush)                         ; the world, carved and filled
(borrow 'swatch)                        ; the textures, from their recipes
(borrow 'flicker)                       ; how the lights stammer, buzz and breathe
(borrow 'walk)                          ; the keys, and a step slid along a wall
(borrow 'mixer)                         ; the sounds, mixed into the horn
(:
 fps 20
 eye-h 1.6 body-r 0.25
 walk-v 1.8 turn-v 1.6 tilt-v 1.2         ; metres, and radians, a second
 door-v 1.4 door-near 2.4 door-t 0.03     ; the doors: their pace, how near opens one, half their thickness
 car-t 0.08 car-wait 0.6 car-hold 1.5 car-acc 1.2  ; a car: its walls' thickness, the seconds before its door
                                                  ; opens and after it shuts, how fast it gathers speed
 chunk-m 8.0 cell 0.25 cell-top 2.0                   ; how fine the surfaces are cut near a lamp, for the
                                          ; light, and how coarse far from every one
 watch-every 10                           ; frames between looks at the files
 the-level "src/apps/lore/levels/hall.l"
 ; --- the level, read: (corridor-read s) runs a level file's text into a tablet {'name 'start
 ;     'rooms 'doors 'strips 'bulbs 'posters 'signs 'brushes 'textures}, or a string saying why not ---
 (skin-name sk c) (foldl (\ a e (e 0 = c ? (e 1) a)) c sk)
 ; ..a brush with no inside: a box flat in some direction, a prism no height
 (empty? r) (: sh (r 'shape)
   (sh 'box @ () (: p (sh 'prism) (p 1 - p 0 < 1e-6)) b (any (k \ b 1 k - b 0 k < 1e-6) ^3)))
 ; ..a scare raised by a word given what it does not take says what it takes; any other is
 ; love's own
 (corridor-read s) (: r (trap (_ \ (sounds s @ 'torn ['torn]
                                       ds (foldl (\ a d (ev 'ev d)) (ev 'ev '(borrow 'scenery)) ds)))
                             () (\ a b ['scare a b]))
   (? (tablet? r) (r 'kind = 'level ? (check r) "the file's last form should be (level NAME PART ..)")
      (two? r && <r = 'scare) (r 1 = 'level ? (r 2) ";; \(r 1) \(r 2)")
      (two? r && <r = 'torn) "a form is not finished: a ( without its )"
      "the file's last form should be (level NAME PART ..)"))
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
 ; ..a room's box as a mask of places, a little past its walls: what its lamps reach
 (inside r) (\ X Y Z ((r 0 - 0.11 < X) * (X < r 2 + 0.11) * (r 1 - 0.11 < Z) * (Z < r 3 + 0.11)))
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
   (pin (foldl (\ b c (brush-cut b (c 0) (c 1) (c 2))) b0 (r 'cuts)) 'skin (r 'skin)))
 (doorway d) (: ax (d 'ax) p (P ax (d 'c - 0.5 * d 'w) (d 'y) (d 'a - 0.02)) q (P ax (d 'c + 0.5 * d 'w) (d 'y + d 'h) (d 'b + 0.02))
   (brush-box 1 [(min2 (p 0) (q 0)) (d 'y) (min2 (p 2) (q 2))] [(max2 (p 0) (q 0)) (d 'y + d 'h) (max2 (p 2) (q 2))]))
 (brushes-of lv) (map brush-of (lv 'brushes) + map doorway (lv 'doors))
 ; ..the texture on a face of brush b facing n, by its skin, and its texels at p: tt the
 ; textures, each [name w h metres]; a floor's and ceiling's laid from x 0 z 0, a wall's
 ; along it and its foot on the brush's
 (tix tt nm) (foldl (\ a i (tt i 0 = nm ? i a)) 0 ^#tt)
 (look tt) (\ n p b (: c (? (0.7 < n 1) 'floor (n 1 < -0.7) 'ceiling 'wall)
                       i (tix tt (skin-name (peep b 'skin ()) c)) t (tt i) k (t 1 / t 3)
                       (? (c = 'wall) (: d (unit [(0.0 - n 2) 0.0 (n 0)]) [i (k * dot p d) (t 2 - k * (p 1 - b 'lo 1))])
                          [i (k * p 0) (k * p 2)])))
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
 ; ..a glow round p, r across: three discs crossed, bright in the middle and gone at the
 ; edge, each seen from both sides
 (halo-ball p r col) (: n 12 z [0.0 0.0 0.0]
   (vx q k) [(q 0) (q 1) (q 2) 0.0 0.0 0.0 0.0 0.0 (k 0) (k 1) (k 2)]
   (disc u v) (: rim (map (i \ (: a (tau * i / n) (vx (c+ p (c+ (c* (r * cos a) u) (c* (r * sin a) v))) z))) ^n)
     (mesh (vx p col . rim) (cats (map (i \ (: a (1 + i) b (1 + (i + 1) % n) [[0 a b -1] [0 b a -1]])) ^n))))
   (mesh-join [(disc [1.0 0.0 0.0] [0.0 1.0 0.0]) (disc [0.0 1.0 0.0] [0.0 0.0 1.0]) (disc [1.0 0.0 0.0] [0.0 0.0 1.0])]))
 (sign-light lv s) (: a (s 'at) hg (hang lv (a 0) (a 1)) n (hg 1) rt (hg 2) h (a 3)
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
                 + map (sign-light lv) (lv 'signs)
                 + cats (map (i \ door-lights lv i (lv 'doors i)) ^#(lv 'doors)))
 ; ..how bright a light is at mt seconds, the doors open by ds: steady; a strip failing,
 ; mostly on and now and then stammering off; a tube's buzz; a bulb breathing; a door's
 ; lamp by its door. sd keeps two failing lights out of step
 (bright how mt sd ds) ((two? how ? <how 'steady) @
  'stammer (flicker-stammer mt sd)
  'buzz (flicker-buzz mt)
  'breathe (flicker-pulse mt 0.7 0.3 1.7 sd)
  (a . u) (peep ds <u 0.0 @ d (a @ 'shut (d < 0.02 ? 1.0 0.0) (d < 0.02 ? 0.0 1.0)))
  1.0)
 (corridor-ks sc mt ds) (map (i \ bright (sc 'lights i 'how) mt i ds) ^#(sc 'lights))
 amb [0.025 0.025 0.03]
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
 (coarse? lps) (\ ps c (: lo (map (k \ foldl (\ a p (min2 a (p k))) 1e9 ps) ^3) hi (map (k \ foldl (\ a p (max2 a (p k))) -1e9 ps) ^3)
   (d p) (sqrt (net (map (k \ sq (max2 0.0 (max2 (lo k - p k) (p k - hi k)))) ^3)))
   (any (lp \ any (p \ (: dd (d p) (dd < lp 'r && 6.0 * c > dd + 0.5))) (lp 'at)) lps)))
 ; ..a pane: a sheet each way across the middle of its thin side, glass of its texture, the
 ; light on it its sheen
 (pane-mesh p tt) (: lo (p 'lo) hi (p 'hi) ax ((hi 0 - lo 0) < (hi 2 - lo 2) ? 0 2) al (2 - ax) m (0.5 * (lo ax + hi ax))
   i (tix tt (p 'tex)) t (tt i) W (hi al - lo al) H (hi 1 - lo 1) g [0.14 0.15 0.15]
   (pt a y) (ax = 0 ? [m y a] [a y m]) e (map (k \ k = al ? 1.0 0.0) ^3) n (map (k \ k = ax ? 1.0 0.0) ^3)
   (uv q) [(t 1 / W * (q al - lo al)) (t 2 / H * (hi 1 - q 1))]
   (mesh-join [(sheets (pt (lo al) (lo 1)) [0.0 H 0.0] (c* W e) n uv (-3 - i) g)
               (sheets (pt (lo al) (lo 1)) [0.0 H 0.0] (c* W e) (c* -1.0 n) uv (-3 - i) g)]))
 ; ..a decal's sheet, its texture tex tw by th
 (decal-mesh d tt) (: a (d 'at) n (unit (c+ (d 'np) (c* -1.0 a))) u (unit (c+ (d 'up) (c* -1.0 a))) r (cross u n)
   w (d 'w) h (d 'h) i (tix tt (d 'tex)) t (tt i) o (c+ a (c+ (c* (-0.5 * w) r) (c* (-0.5 * h) u)))
   (sheets o (c* h u) (c* w r) n (q \ (: e (c+ q (c* -1.0 o)) [(t 1 / w * dot e r) (t 2 / h * (h - dot e u))])) i white))
 (file-of dir p) (p 'file @ () () f (f 0 @ 47 f (dir + f)))
 ; --- the scene, built from a level: the meshes packed and each light's channel baked;
 ;     dir the level's folder, for its pictures ---
 (scene lv dir) (: ps (lv 'posters) ls (lights-of lv)
   txs (textures lv) tt (map (t \ [(t 'name) (t 'w) (t 'h) (t 'm)]) txs)
   ptex (map (p \ poster-tex (file-of dir p) (p 'at 3) (p 'at 4)) ps)
   pm (map (i \ poster-mesh lv (ps i) (#tt + i) (shape (ptex i 0) 1) (shape (ptex i 0) 0)) ^#ps)
   bs (brushes-of lv)
   ; ..the world in chunks chunk-m square, so a frame draws only those in view, nearest first
   cks (map mesh-pack (brush-chunks bs [cell-top cell (coarse? (cats (map (l \ l 'lamps) ls)))] (look tt) chunk-m
                       + pm + map (d \ decal-mesh d tt) (peep lv 'decals ())))
   drs (map (d \ mesh-pack (door-mesh d tt)) (lv 'doors))
   ; ..each light's channel; the steady ones summed once with the ambient, so a frame adds
   ; only the lights that change
   dyn (filter (i \ two? (ls i 'how)) ^#ls) still (filter (i \ atom? (ls i 'how)) ^#ls)
   (ch pk l) (foldl (a \ c+ a * mesh-lamp pk) [0.0 0.0 0.0] (l 'lamps))
   (lit pk) {'base (foldl (a \ c+ a * ch pk * ls) (c+ amb (c* 0.0 (pk 'cols 0 @ z [z z z]))) still)
             'chs (map (ch pk * ls) dyn)}
   ; ..a car lit where it stands, and by its own lamp, which goes with it
   (clit lp pk) (: l (lit pk) (pin l 'base (c+ (l 'base) (mesh-lamp pk lp))))
   cars (map (c \ (: b (mesh-pack (car-mesh c tt)) d (mesh-pack (car-door c tt)) lp (car-lamp c)
                     {'body b 'body-lit (clit lp b) 'door d 'door-lit (clit lp d) 'bar (mesh-pack (car-bar c))}))
             (peep lv 'cars ()))
   {'panes (map (p \ (: pk (mesh-pack (pane-mesh p tt)) {'pk pk 'lit (lit pk)})) (peep lv 'panes ()))
    'chunks (map (pk \ {'pk pk 'lit (lit pk) 'lo (map (k \ amin (pk 'cols k)) ^3) 'hi (map (k \ amax (pk 'cols k)) ^3)}) cks)
    'doors drs 'doors-lit (map lit drs) 'cars cars 'lights ls 'dyn dyn 'brushes bs
    'texs (map (t \ swatch (t 'w) (t 'h) (t 'layers)) txs + ptex)})
 ; --- the frame: the rooms and doors lit by the lights as bright as they are now, then
 ;     what shines, then the glows; out as half blocks or kitty's pixels ---
 fov 1.5
 gain 2.0
 (corridor-pens st) (: k (peep st 'kp 1) w (k * st 'w) h (k * st 'h) sc (st 'sc) lv (st 'lvl)
   ds (st 'doors) ks (corridor-ks sc (st 'mt) ds)
   e [(st 'px) (st 'py) (st 'pz)]
   v (mesh-eye w h e (st 'th) (st 'ph) 0.0 fov 0.05 60.0)
   dk (map (i \ ks i) (sc 'dyn))
   (relit pk l) (mesh-lamps! pk (l 'base) (l 'chs) dk 1.0)
   ; ..the chunks some corner of whose box is inside each plane of the view, nearest first
   cam (v 'cam) (row i p) (peep cam (4 * i) 0.0 * p 0 + peep cam (4 * i + 1) 0.0 * p 1 + peep cam (4 * i + 2) 0.0 * p 2 + peep cam (4 * i + 3) 0.0)
   (seen? c) (: lo (c 'lo) hi (c 'hi)
     qs (map (j \ (: p [(j % 2 ? (hi 0) (lo 0)) (j // 2 % 2 ? (hi 1) (lo 1)) (j // 4 ? (hi 2) (lo 2))] [(row 0 p) (row 1 p) (row 2 p) (row 3 p)])) ^8)
     !(any (out \ !(any (q \ !(out q)) qs)) [(q \ q 0 < 0.0 - q 3) (q \ q 0 > q 3) (q \ q 1 < 0.0 - q 3) (q \ q 1 > q 3) (q \ q 2 < 0.0 - q 3) (q \ q 2 > q 3)]))
   (far c) (net (map (k \ sq (0.5 * (c 'lo k + c 'hi k) - e k)) ^3))
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
   (by key) (cats (map (i \ cats (map (q \ ((q 1 * ks i) @ 0.0 () b [(mesh-shine (q 0) b)])) (sc 'lights i key))) ^#ks))
   ; ..the cars and doors first, as near as anything is, so less behind them is lit for nothing
   glass (map (c \ relit (c 'pk) (c 'lit)) (sc 'panes))
   all (cars + doors + hall + by 'shine + glass + map mesh-glow (by 'glow))
   (mesh-frame v [(map (b \ b 0) all) (map (b \ b 1) all)] (sc 'texs) [0.0 0.0 0.0 30.0 60.0] 8 gain 0))
 ; ..a frame, and under it the bottom row's word: what a reload found wrong, or for a few
 ; seconds that it read the level again
 (corridor-frame st) (: w (st 'w) h (st 'h) f (corridor-pens st) r (h // 2)
   ; ..or, with p pressed, where the player stands and faces, as a level says it
   m (? (st 'err || !(peep st 'pos 0)) (st 'msg) (where st))
   say? (string? m && (st 'err || peep st 'pos 0 || st 'mt < st 'msg-t + 3.0))
   text (say? ? (snip (pad (" " + m) w " ") 0 w) "")
   (mesh-show st f (say? ? (esc + "[" + show r + ";1H" + esc + (st 'err ? "[1;37;41m" "[0;37;40m") + text + esc + "[0m") "")
              (say? ? (band st text r) {})))
 (where st) (: (r v) (show (int (v * 100.0 + (v < 0.0 ? -0.5 0.5)) / 100.0))
   deg (st 'th * 180.0 / pi @ d (d < 0.0 ? (d + 360.0) d))
   "(start [\(r (st 'px)) \(r (st 'py - eye-h)) \(r (st 'pz))] \(r deg) \(r (st 'ph * 180.0 / pi)))")
 ; ..as one of view's bands on row r: its cells, a character each, and its pens
 (band st s r) (: deep (st 'deep)
   (pen v) (deep ? (: (q x) ((x * 63 + 127) // 255) (q (v 0) * 4096 + q (v 1) * 64 + q (v 2))) (v 3))
   (cells s) (: (go i) (i < #s ? (: j (cite 'text 'cpnext s i) (snip s i j . go j)) ()) (go 0))
   {(r - 1) [0 (cells s) (pen [240 240 240 255]) (pen (st 'err ? [150 20 20 124] [20 20 20 233]))]})
 ; --- the state: the screen as view lays it, the level and its scene, where the player
 ;     stands and looks, the clock, the doors ---
 (corridor-new w h lv dir) (: s (lv 'start)
   (corridor-size {'px (s 'at 0) 'pz (s 'at 1) 'py (s 'y + eye-h) 'th (s 'deg * pi / 180.0) 'ph (s 'pitch * pi / 180.0) 't 0 'mt 0.0
                   'lvl lv 'sc (scene lv dir) 'dir dir 'doors (map (_ \ 0.0) (lv 'doors)) 'cars (cars-new lv) 'deep 0 'kitty 0 'kp 1
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
 (put! st x z) (walk-slide st x z corridor-free?)
 ; ..the corridor's own keys, over view's
 corridor-binds {112 'where}
 ; ..each action as far as the time since the last frame, 'dt, carries it
 (corridor-step st a) (: dt (peep st 'dt (1.0 / fps))
   (walk-key st a {'turn (turn-v * dt) 'walk (walk-v * dt) 'tilt (tilt-v * dt) 'up 1.3 'down -1.2} put!
    @ () (a = 'where ? (pin st 'pos (1 - peep st 'pos 0)) st)
      s s))
 ; a frame's motion: the clock, each door toward open while the player is near it, and the cars
 (corridor-move st) (: dt (peep st 'dt (1.0 / fps)) lv (st 'lvl) x (st 'px) z (st 'pz)
   (go i) (: d (lv 'doors i) o (st 'doors i) p (P (d 'ax) (d 'c) 0.0 (0.5 * (d 'a + d 'b)))
             want (sq (p 0 - x) + sq (p 2 - z) < sq door-near ? 1.0 0.0)
             (want < o ? (max2 want (o - door-v * dt)) (min2 want (o + door-v * dt))))
   _ (pins st 'mt (st 'mt + dt) 'doors (map go ^#(lv 'doors)))
   (foldl (\ st i (car-step st (lv 'cars i) (st 'cars i) dt)) st ^#(peep lv 'cars ())))
 ; ..a car's next moment: the door opens as the level starts and stays open while the player
 ; is anywhere in its track; once they are out it shuts, opening again if they come back
 ; before it is home; held shut a moment, the car gathers speed along its track and is gone
 ; once it is leave along. each change cries its sound from the doorway
 (car-at c o) (: p (P (c 'ax) (c 'dc + o) 0.0 (c 'side)) [(p 0) (p 2)])
 (car-step st c s dt) (: in (car-track? c (st 'px) (st 'pz)) t (s 't + dt) dr (s 'door) at (car-at c (s 'o))
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
               (seen! (pins st 'lvl lv 'sc (scene lv (st 'dir)) 'doors ds 'cars cs 'msg ("read " + st 'path + " again")
                               'err 0 'msg-t (st 'mt))))))))
 (dir-of p) (: (go i) (i < 0 ? "" (p i = 47 ? (snip p 0 (i + 1)) (go (i - 1)))) (go (#p - 1)))
 ; --- the walk, on view's loop; corridor-run raises the stage ---
 (corridor-walk o lv)
   (view-walk {'new (w \ h \ (: p (o 'level)
                               st (pins (corridor-new w h lv (dir-of p)) 'deep (o 'md = 'window || view-deep? ()) 'kitty (mesh-mode (o 'md))
                                        'win (peep o 'win ()) 'path p 'scale (peep o 'scale 2))
                               (corridor-watch (corridor-size st w (h // 2)))))
               'size corridor-size 'frame corridor-frame 'key corridor-step
               'binds (view-bind view-binds corridor-binds) 'listed (view-listed ['where 'finer 'coarser])
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
 corridor-usage "usage: love lore corridor [--level FILE] [--kitty|--cells|--window] [--scale 1|2|4|8]   (h l turn, k j step, u n look, p where you stand; ? the keys; q or esc leaves; the level is read again when it changes)"
 ; the words, as a tablet for corridor-run, or () where one is wrong or said twice
 (corridor-opts as) (view-words as [(view-flag "--kitty" 'md 'kitty) (view-flag "--cells" 'md 'cells) (view-flag "--window" 'md 'window) view-scale
                                    (view-arg "--level" 'level (w \ w))])
 (corridor-main as) (view-main "corridor" corridor-usage corridor-opts corridor-run as)
 _ (cite 'lore 'lore-enlist 'corridor (udoor 'corridor corridor-main corridor-usage 1 1)))
) ; module corridor
