; `love play src/apps/lore/levels/ring.l`: a world laid round a ring's tube, walked all the
; way round either way. x runs round the ring and z round the tube, its outside halfway; a
; row of posts down the outside, a ring of them round the tube, a river winding
; round it, and a cairn. under the grass, round a smaller tube inside it, a maze of yellow
; rooms the whole way round: the walk begins in a dark closet off one of them, and in a white
; hall by the cairn a tree grows up through a well to the grass, climbed to get out. over it
; all a pink orb hangs in the ring's middle, a lift up to it from the tube's inside, and in
; it a shipping container where the hall's stereo is heard too
(borrow 'scenery)

(: lx 320.0 lz 88.0)                   ; round the ring and round the maze's floor
(: mh 3.0 top 4.5)                     ; the maze's height, and how far over its floor the grass is
(: exit-signs 1)                       ; while playtesting, the way out of the maze signed
(: tx 17.0 tz 51.0 wh 1.0)             ; the tree mid-hall, and the well over it on a square of the grass
(: nx 50 nz 13 cx (lx / nx) cz (lz / nz) wt 0.1)   ; the maze's rooms round and across, their size, its walls
(: gis [1 2 3] gjs [6 7 8] gh 4.0)     ; the hall's rooms, clear of the river, and its height
(: sx 90.0 hub ((lx - lz) / tau))      ; the lift's shaft up off the tube's inside, and how high the ring's middle is over it

; the textures: grass, stone, the cairn's red stone and the river's water; below, the rooms'
; wallpaper, carpet and ceiling tiles, and the well's concrete
(: grass (feel 'soft (texture 64 64 2
          '((fill (rgb 0.3 0.52 0.2)) (noise 1 0.25) (noise 8 0.12) (patches 6 0.25 (shade 0.82))
            (patches 5 0.12 (rgb 0.5 0.66 0.26))))))
(: stone (feel 'hard (texture 32 32 1.2 '((fill (grey 0.55)) (noise 2 0.15) (patches 4 0.2 (shade 0.8))))))
(: red (feel 'hard (texture 32 32 1.2 '((fill (rgb 0.62 0.24 0.18)) (noise 2 0.15) (patches 4 0.2 (shade 0.8))))))
(: water (texture 64 64 4
          '((fill (rgb 0.16 0.36 0.5)) (noise 24 4 0.18) (patches 8 0.15 (rgb 0.4 0.6 0.72)) (noise 1 0.06))))
(: paper (texture 64 64 1.6
          '((fill (rgb 0.8 0.73 0.44)) (stripes 8 2 0 (shade 0.95)) (noise 3 0.05) (patches 8 0.2 (shade 0.9))
            (noise 1 0.04))))
(: carpet (feel 'soft (texture 64 64 2
           '((fill (rgb 0.58 0.51 0.31)) (noise 1 0.22) (noise 5 0.1) (patches 6 0.25 (shade 0.84))))))
(: tiles (texture 64 64 1.2 '((fill (rgb 0.84 0.82 0.72)) (noise 1 0.08) (grid 32 32 1 (grey 0.6)))))
(: oak (feel 'wood (texture 32 64 0.9 '((fill (rgb 0.52 0.34 0.19)) (stripes 5 1 0 (shade 0.9)) (noise 2 0.1)
          (within 5 5 27 29 (bevel 22 24 1 (shade 1.18) (shade 0.68))) (within 5 34 27 59 (bevel 22 25 1 (shade 1.18) (shade 0.68)))))))
(: concrete (feel 'hard (texture 32 32 1.5 '((fill (grey 0.5)) (noise 1 0.12) (noise 6 0.1) (patches 5 0.15 (shade 0.85))))))

; the ground: swells that come round whole every way, the river's bed sunk along it, flat
; round the well and the lift's foot, and over the hall never lower than a slab over its
; ceiling; each asked of x a number or a tray of them
(: (ease v a b) (: k (min 1.0 (max 0.0 ((v - a) / (b - a)))) (k * k * (3.0 - 2.0 * k))))
(: (span v) (max v (0.0 - v)))
(: (swell x z) (: a (tau * x / lx) b (tau * z / lz)
   (0.9 * (0.5 + 0.5 * sin (5.0 * a + 0.3)) * (0.5 + 0.5 * sin (3.0 * b + 1.1)) + 0.3 * sin (11.0 * a - 4.0 * b))))
; ..the river: wn times round the tube for once round the ring, 0 the tube's inside all
; the way, crossing the start's x there so the walk begins across the tube from it; at x its
; middle's z, its slope, and how far a place is from it, the shorter way round
(: wn 6)
(: rs (wn * lz / lx) (rz x) (rs * (x - 10.0)))
(: (around d l) (d - l * floor (d / l + 0.5)))
(: (rd x z) (span (around (z - rz x) lz) / sqrt (1.0 + rs * rs)))
(: (bed x z) (: d (rd x z) (swell x z * ease d 2.5 7.0 - 0.7 * (1.0 - ease d 1.8 4.2))))
(: (ground x z) (: f (max (span (x - sx) - 1.0) (span (around z lz) - 1.0))
   g (top + bed x z * ease (max (span (x - tx) - wh - 1.0) (span (z - tz) - wh - 1.0)) 2.0 8.0 * ease f 1.0 5.0)
   o (max (max (cx * <gis - x) (x - cx * (<gis + 3))) (max (cz * <gjs - z) (z - cz * (<gjs + 3))))
   (g + max 0.0 (gh + 0.4 - g) * (1.0 - ease o 0.0 3.0))))
(: gm 2.0 xs (map (i \ gm * i) ^(int (lx / gm) + 1)) zs (map (i \ gm * i) ^(int (lz / gm) + 1)) X (gem-tray [#xs] xs))
(: (rows f) (map (z \ (: Y (f X z) (map (i \ [(xs i) (peep Y i 0.0) z]) ^#xs))) zs))

; a post standing on the ground at x z, a cairn three stones high
(: (post x z t) (: y (ground x z) (skin {'all t} (solid (box [(x - 0.2) (y - 0.5) (z - 0.2)] [(x + 0.2) (y + 1.8) (z + 0.2)])))))
; ..the river's water, a strip down its middle a metre a row, cut where it goes round the
; tube past lz so none straddles it, each piece a row over the cut to meet the next and laid
; along from as far down the river as it starts; none by the well
(: (well? p) (: z (around (p 2 - tz) lz) (span (p 0 - tx) < wh + 1.5 && span z < wh + 1.5)))
(: (water-row x) (: z (rz x) n (sqrt (1.0 + rs * rs)) u (3.4 * rs / n) v (-3.4 / n)
   (map (k \ (: p [(x + k * u) (top - 0.45) (z + k * v)] ((well? p) ? () p))) [-1.0 0.0 1.0])))
(: waters (: rows (map (i \ [i (water-row (1.0 * i))]) ^321) (cut r) (floor (rz (1.0 * r 0) / lz))
   S (map (i \ i * sqrt (1.0 + rs * rs)) ^321)
   (go l run out) (? (atom? l) (rev (rev run . out))
      (two? run && cut <l != cut <run) (go >l [<l] (rev (<l . run) . out))
      (go >l (<l . run) out))
   (map (piece \ (: o (lz * cut <piece) [(S (<piece 0)) (map (q \ map (p \ p = () ? () [(p 0) (p 1) (p 2 - o)]) (q 1)) piece)])) (go rows () ()))))
(: (cairn x z) (: y (ground x z)
   (map (k \ (: a (0.9 - 0.25 * k) y0 (y - 0.2 + 0.6 * k) (skin {'all red} (solid (box [(x - a) y0 (z - a)] [(x + a) (y0 + 0.6) (z + a)])))))
        ^3)))

; the maze: nx by nz rooms the whole way round, wrapping as the world does, each carved out
; of the ground with the ground left standing between them for walls. a passage dug from the
; first room to every other, through a doorway, seldom the whole wall; and of the walls not
; dug a few with a doorway, so a way round now and then
(: (h01 a b) (: s (sin (a * 12.9898 + b * 78.233 + 0.5) * 43758.5453) (s - floor s)))
(: (cid i j) ((i + nx) % nx * nz + (j + nz) % nz))
; ..the hall: three rooms by three by the cairn, one room, white and higher than the rest, its
; floor in black and white squares, a doorway in the middle of each side. and the closet:
; a dark one off the end of a room across the ring, its door opened by hand, where the
; player wakes
(: ci 27 cj 6)
(: (hall? i j) (elem i gis && elem j gjs))
(: gw (cats (map (i \ map (j \ cid i j) gjs) gis)))
(: dug (: seen {} open {}
   (nb c d) (: i (c // nz) j (c % nz) (d @ 0 (cid (i + 1) j) 1 (cid (i - 1) j) 2 (cid i (j + 1)) (cid i (j - 1))))
   (edge c d) (: i (c // nz) j (c % nz) (d @ 0 (cid i j) 1 (cid (i - 1) j) 2 (100000 + cid i j) (100000 + cid i (j - 1))))
   (go c) (: _ (pin seen c 1)
             (each (map (q \ q 1) (sort (map (d \ [(h01 c d) d]) ^4)))
                   (d \ (: n (nb c d) e (edge c d) (peep seen n 0 = 0 && e != 100000 + cid ci cj ? (: _ (pin open e 1) (go n)) 0)))))
   _ (each gw (c \ pin seen c 1))
   _ (go 0)
   open))
; ..room i j, and the way through its wall toward x and toward z: the whole wall, a doorway
; or none; a room open toward x reaching over into the next, and a way across where the
; world wraps cut either side of it. the hall's walls shut but its doorways; the closet's
; room no wider than a doorway to its sides
(: hall-doors [(cid (<gis - 1) (gjs 1)) (cid (gis 2) (gjs 1)) (100000 + cid (gis 1) (<gjs - 1)) (100000 + cid (gis 1) (gjs 2))])
(: (round-hall e) (: c (e % 100000) i (c // nz) j (c % nz)
   (? (e < 100000) (hall? i j || hall? (i + 1) j) (hall? i j || hall? i (j + 1)))))
(: (through e) (? (elem e hall-doors) 'door (round-hall e) 'none
                  (e = 100000 + cid ci cj) 'none
                  (: w (? (peep dug e 0 = 1) (h01 e 7 <= 0.15 ? 'open 'door) (h01 e 11 < 0.1 ? 'door 'none))
                     (elem e [(cid ci cj) (cid (ci - 1) cj)] && w = 'open ? 'door w))))
(: white (texture 64 64 2 '((fill (grey 0.92)) (noise 3 0.03))))
(: checks (feel 'hard (texture 64 64 1.2 '((fill (grey 0.93)) (checker 32 32 (grey 0.08)) (noise 2 0.04)))))
(: (cell i j) (: wide (i < nx - 1 && through (cid i j) = 'open) z1 (cz * (j + 1) - wt) top-z (i = ci && j = cj ? (z1 - 1.6) z1)
   ((hall? i j) ? () (room [(cx * i + wt) 0 (cz * j + wt)] [(cx * (i + 1) + (wide ? (wt + 0.01) (0.0 - wt))) mh top-z]))))
(: hall (dark (skin {'walls white 'floor checks 'ceiling white}
                    (room [(cx * <gis + wt) 0 (cz * <gjs + wt)] [(cx * (<gis + 3) - wt) gh (cz * (<gjs + 3) - wt)]))))
(: (gap lo hi) (air (box lo hi)))
(: (ways i j) (: x0 (cx * i + wt) x1 (cx * (i + 1) - wt) z0 (cz * j + wt) z1 (cz * (j + 1) - wt) xm (0.5 * (x0 + x1)) zm (0.5 * (z0 + z1))
   (wx a b) (? (i < nx - 1) [(gap [(x1 - 0.01) 0 a] [(x1 + 2.0 * wt + 0.01) mh b])]
               [(gap [(x1 - 0.01) 0 a] [lx mh b]) (gap [0 0 a] [(wt + 0.01) mh b])])
   (wz a b) (? (j < nz - 1) [(gap [a 0 (z1 - 0.01)] [b mh (z1 + 2.0 * wt + 0.01)])]
               [(gap [a 0 (z1 - 0.01)] [b mh lz]) (gap [a 0 0] [b mh (wt + 0.01)])])
   ((through (cid i j) @ 'open (i < nx - 1 ? () (wx z0 z1)) 'door (wx (zm - 0.7) (zm + 0.7)) ())
    + (through (100000 + cid i j) @ 'open (wz x0 x1) 'door (wz (xm - 0.7) (xm + 0.7)) ()))))
; ..the closet, a doorway wide and a stride and a half deep, and its door
(: (closet i j) (: xm (cx * (i + 0.5)) z1 (cz * (j + 1) - wt)
   [(dark (room [(xm - 0.7) 0 (z1 - 1.4)] [(xm + 0.7) 2.4 z1]))
    (by-hand (door [xm 0 (z1 - 1.5)] 0.9 2.1))]))
; ..two troffers to a room's ceiling on its tiles' grid, every one lit by the rooms' own
; light; one to each of the hall's, lighting it, none under the well
(: (panels i j) (: x (cx * (i + 0.5)) z (0.6 * floor (cz * (j + 0.5) / 0.6 + 0.5)) (under? x) (span (x - tx) < wh + 0.4 && span (z - tz) < wh + 0.4)
   (on x) (0.6 * floor (x / 0.6) + 0.3)
   (? (hall? i j) (under? x ? () [(troffer (strip-light [(on x) gh z]))])
      (map (x \ unlit (troffer (strip-light [x mh z]))) [(on (x - 1.6)) (on (x + 1.6))]))))
; ..in the hall the tree in a mound of dirt, and a stereo against the north wall: a cabinet,
; the amplifier on it, the tape deck on top, a tap on any of it playing the loop, a speaker
; either side
(: dirt (feel 'soft (texture 64 64 1.5 '((fill (rgb 0.34 0.25 0.17)) (noise 1 0.2) (noise 6 0.12) (patches 5 0.2 (shade 0.78))))))
(: bark (feel 'wood (texture 32 64 0.5 '((fill (rgb 0.46 0.43 0.38)) (noise 1 0.08) (noise 2 14 0.18) (stripes 11 1 0 (shade 1.12))
          (cracks 8 24 1 5 (shade 0.82)) (patches 5 0.2 (shade 0.86))))))
(: wood (feel 'wood (texture 64 64 0.8 '((fill (rgb 0.42 0.26 0.14)) (stripes 6 1 1 (shade 0.85)) (noise 2 0.12)))))
(: ash (texture 32 32 0.6 '((fill (grey 0.1)) (noise 2 0.2))))
(: alu (feel 'metal (texture 32 32 0.5 '((fill (grey 0.6)) (stripes 2 1 0 (shade 0.92))))))
(: cone (texture 32 32 0.4 '((fill (grey 0.16)) (noise 1 0.3))))
; ..the tape deck's face: two doors, a cassette behind each one's glass, the tape wound on
; its two hubs in its window, the counter and the keys beside them
(: tapeface (texture 256 64 0.8
             '((fill (grey 0.1))
               (rect 12 14 60 50 (grey 0.2)) (rect 15 17 57 47 (grey 0.04)) (rect 18 20 54 44 (grey 0.28))
               (rect 26 28 46 37 (grey 0.1)) (disc 31 32.5 5.5 (rgb 0.32 0.19 0.1)) (disc 41 32.5 4 (rgb 0.32 0.19 0.1))
               (disc 31 32.5 2.2 (grey 0.92)) (disc 41 32.5 2.2 (grey 0.92)) (disc 31 32.5 1 (grey 0.02)) (disc 41 32.5 1 (grey 0.02))
               (rect 19 21 53 28 (rgb 0.86 0.8 0.64)) (rect 19 37 53 41 (rgb 0.86 0.8 0.64)) (rect 19 28 26 37 (rgb 0.86 0.8 0.64)) (rect 46 28 53 37 (rgb 0.86 0.8 0.64))
               (rect 19 21 53 23 (rgb 0.75 0.3 0.2)) (rect 24 41 48 44 (grey 0.2))
               (rect 72 14 120 50 (grey 0.2)) (rect 75 17 117 47 (grey 0.04)) (rect 78 20 114 44 (grey 0.28))
               (rect 86 28 106 37 (grey 0.1)) (disc 91 32.5 5.5 (rgb 0.32 0.19 0.1)) (disc 101 32.5 4 (rgb 0.32 0.19 0.1))
               (disc 91 32.5 2.2 (grey 0.92)) (disc 101 32.5 2.2 (grey 0.92)) (disc 91 32.5 1 (grey 0.02)) (disc 101 32.5 1 (grey 0.02))
               (rect 79 21 113 28 (rgb 0.86 0.8 0.64)) (rect 79 37 113 41 (rgb 0.86 0.8 0.64)) (rect 79 28 86 37 (rgb 0.86 0.8 0.64)) (rect 106 28 113 37 (rgb 0.86 0.8 0.64))
               (rect 79 21 113 23 (rgb 0.75 0.3 0.2)) (rect 84 41 108 44 (grey 0.2))
               (rect 140 12 192 24 (rgb 0.2 0.8 0.6)) (rect 200 12 244 24 (grey 0.05))
               (rect 132 40 144 52 (grey 0.7)) (rect 148 40 160 52 (grey 0.7)) (rect 164 40 176 52 (grey 0.7)) (rect 180 40 192 52 (rgb 0.8 0.25 0.2)) (rect 196 40 208 52 (grey 0.7)) (rect 212 40 224 52 (grey 0.7)) (rect 228 40 240 52 (grey 0.7)))))
(: lcd (texture 32 8 0.3 '((fill (rgb 0.05 0.12 0.1)) (rect 2 2 30 6 (rgb 0.3 0.9 0.75)) (stripes 3 1 0 (shade 0.6)))))
; ..the mound round octagonally, r at its foot and rt across its top, h high
(: (mound x z r rt h) (: b (r / cos (pi / 8.0) + 0.01)
   (foldl (\ br k (: a (pi * k / 4.0 + pi / 8.0) c (cos a) s (sin a) p [(x + r * c) 0.0 (z + r * s)]
                      (cut p [(p 0 - s) 0.0 (p 2 + c)] [(x + rt * c) h (z + rt * s)] br)))
          (skin {'all dirt} (solid (box [(x - b) 0 (z - b)] [(x + b) h (z + b)]))) ^8)))
; ..a speaker's cabinet, the middle of its back's foot at x y z, facing f across the floor:
; a woofer, a midrange and a tweeter down its front, the loop heard from it
(: (block lo hi t) (skin {'all t} (solid (box lo hi))))
(: (cabinet o f) (: (p l h d) [(o 0 + l * (0.0 - f 1) + d * f 0) (o 1 + h) (o 2 + l * f 0 + d * f 1)]
   [(block (p -0.25 0.0 0.0) (p 0.25 1.05 0.42) ash)
    (rod (p 0.0 0.35 0.42) (p 0.0 0.35 0.44) 0.17 12 cone)
    (rod (p 0.0 0.68 0.42) (p 0.0 0.68 0.44) 0.08 10 cone)
    (rod (p 0.0 0.9 0.42) (p 0.0 0.9 0.435) 0.035 8 alu)
    (speaker (p 0.0 0.7 0.5))]))
; ..a pa speaker hung in a ceiling's corner c, d [dx dz] the way into the room: a square
; cabinet on a bracket tilted down into it, its grille on the front, a woofer and a tweeter
; behind it, the loop heard from it
(: grille (texture 32 32 0.25 '((fill (grey 0.1)) (disc 16 20 10.5 (grey 0.2)) (disc 16 20 9 (grey 0.13)) (disc 16 20 3.5 (grey 0.24))
                               (disc 16 6.5 3 (grey 0.26)) (disc 16 6.5 1.5 (grey 0.12)) (grid 2 2 1 (shade 0.7)) (rect 0 0 32 1 (grey 0.05)))))
(: (pa c d) (: u [(0.637 * d 0) -0.446 (0.637 * d 1)] up [(0.316 * d 0) 0.9 (0.316 * d 1)]
   m [(c 0 + 0.24 * d 0) (c 1 - 0.2) (c 2 + 0.24 * d 1)] (at k) (map (i \ m i + k * u i) ^3)
   [(rod [(c 0 + 0.03 * d 0) (c 1 - 0.02) (c 2 + 0.03 * d 1)] m 0.02 4 alu)
    (rod m (at 0.2) 0.13 4 ash)
    (decal (at 0.202) u up 0.25 0.25 grille)
    (speaker (at 0.25))]))
; ..and in the maze, here and there round the ring, one in a room's corner
(: pas (map (q \ pa [(cx * q 0 + wt) mh (cz * q 1 + wt)] [1 1]) [[4 2] [11 10] [17 4] [24 11] [32 1] [38 8] [44 3] [48 10]]))
(: (stereo x z) (: w 0.4
   ([(deck [(x - 0.9) 0 (z - 0.45)] [(x + 0.9) 0.86 z])
     (block [(x - 0.9) 0 (z - 0.45)] [(x + 0.9) 0.5 z] wood)
     (block [(x - w) 0.5 (z - 0.38)] [(x + w) 0.63 (z - 0.06)] ash)
     (block [(x - w) 0.63 (z - 0.38)] [(x + w) 0.72 (z - 0.06)] alu)
     (block [(x - w) 0.72 (z - 0.38)] [(x + w) 0.86 (z - 0.06)] ash)
     (decal [x 0.79 (z - 0.381)] [0 0 -1] [0 1 0] 0.78 0.13 tapeface)
     (rod [(x + 0.25) 0.63 (z - 0.38)] [(x + 0.25) 0.63 (z - 0.4)] 0.025 8 alu)
     (rod [(x + 0.32) 0.63 (z - 0.38)] [(x + 0.32) 0.63 (z - 0.4)] 0.018 8 alu)
     (ad [(x - 0.15) 0.565 (z - 0.381)] [0 0 -1] [0 1 0] 0.3 0.06 lcd)]
    + cabinet [(x - 1.25) 0 z] [0 -1] + cabinet [(x + 1.25) 0 z] [0 -1])))
; ..the way out: from the hall back through every way that goes through, each room's way
; on toward it, nearest first; a sign hung inside each way on from the closet, over its room
(: (goes? e) (elem (through e) ['open 'door]))
(: hops (: seen {} hop {}
   (near c) (: i (c // nz) j (c % nz)
     [[(cid (i + 1) j) (cid i j) 'xm] [(cid (i - 1) j) (cid (i - 1) j) 'xp]
      [(cid i (j + 1)) (100000 + cid i j) 'zm] [(cid i (j - 1)) (100000 + cid i (j - 1)) 'zp]])
   (reach c q) (: n (q 0) (? (peep seen n 0 = 0 && goes? (q 1)) (: _ (pin seen n 1) _ (pin hop n (q 2)) [n]) ()))
   (go fr) (? (atom? fr) hop (go (cats (map (c \ cats (map (reach c) (near c))) fr))))
   _ (each gw (c \ pin seen c 1))
   (go gw)))
(: (exit-sign c d) (: i (c // nz) j (c % nz) x0 (cx * i + wt) x1 (cx * (i + 1) - wt) z0 (cz * j + wt) z1 (cz * (j + 1) - wt)
   xm (0.5 * (x0 + x1)) zm (0.5 * (z0 + z1)) y (mh - 0.4) g (rgb 0.25 1.0 0.35)
   (d @ 'xp (unlit (neon [(x1 - 0.03) y zm] [-1 0 0] 0.2 "exit" g)) 'xm (unlit (neon [(x0 + 0.03) y zm] [1 0 0] 0.2 "exit" g))
        'zp (unlit (neon [xm y (z1 - 0.03)] [0 0 -1] 0.2 "exit" g)) (unlit (neon [xm y (z0 + 0.03)] [0 0 1] 0.2 "exit" g)))))
(: exits (: (go c out) (: d (peep hops c ()) i (c // nz) j (c % nz)
                         (? (elem c gw || d = ()) out
                            (go (d @ 'xp (cid (i + 1) j) 'xm (cid (i - 1) j) 'zp (cid i (j + 1)) (cid i (j - 1))) (exit-sign c d . out))))
   (exit-signs = 1 ? (go (cid ci cj) ()) ())))

; ..the ring's middle, flat in the world straight up off the tube's inside: the lift's
; platform climbing its tether from the grass up the axis of a pink orb turning there, in at
; its pole, to a shipping container hung in it, the orb's inside a deeper pink. the tether
; runs on up through the container to its ceiling; the container lit by strips across its
; ceiling, a bed across one end on a frame, a pa speaker up in each corner, the hatch the platform
; comes up through in the middle of its floor
(: pinkorb (texture 128 64 8 '((fill (rgb 0.96 0.46 0.7)) (patches 8 0.35 (shade 0.8)) (patches 4 0.2 (rgb 1 0.78 0.9))
                               (noise 6 0.08) (rows 30 34 (shade 0.86)))))
(: pinkin (texture 128 64 8 '((fill (rgb 0.72 0.24 0.5)) (patches 8 0.35 (shade 0.75)) (patches 5 0.25 (rgb 0.9 0.42 0.68))
                              (noise 6 0.1) (grid 16 16 1 (shade 0.7)))))
(: steel (feel 'metal (texture 64 64 1.2 '((fill (rgb 0.52 0.2 0.14)) (stripes 6 3 0 (shade 0.78)) (noise 2 0.08) (patches 6 0.2 (shade 0.86))))))
(: paint (feel 'metal (texture 64 64 1.2 '((fill (rgb 0.7 0.71 0.66)) (stripes 6 3 0 (shade 0.88)) (noise 3 0.04)))))
(: ply (feel 'wood (texture 64 64 1.6 '((fill (rgb 0.56 0.43 0.28)) (rows 0 1 (shade 0.7)) (rows 32 33 (shade 0.7)) (noise 2 0.12) (stripes 9 1 1 (shade 0.92))))))
(: cy (hub - 1.15))                     ; the container's floor
(: hang (pocket [sx 0]
   [(void [(sx - 1.6) (top - 0.5) -1.6] [(sx + 1.6) (hub - 1.29) 1.6])   ; the shaft, its floor under the grass
    (coarse 4 (glow (orb [sx hub 0] 6 pinkorb 0.06)))
    (coarse 4 (glow (inward (orb [sx hub 0] 5.95 pinkin 0.06))))
    (tether (hub + 1.21 - cy) (lift [sx (top + 0.16) 0] 1.6 (cy - top - 0.16) alu))   ; on its pad on the grass
    (void [(sx - 3.08) (hub - 1.35) -1.27] [(sx + 3.08) (hub + 1.34) 1.27])   ; a hair of air round the container, so its steel shows
    (skin {'all steel} (solid (box [(sx - 3.03) (hub - 1.3) -1.22] [(sx + 3.03) (hub + 1.29) 1.22])))
    (dark (skin {'walls paint 'floor ply 'ceiling paint} (room [(sx - 2.95) cy -1.14] [(sx + 2.95) (hub + 1.21) 1.14])))
    (skin {'all paint} (air (box [(sx - 0.78) (hub - 1.31) -0.78] [(sx + 0.78) (cy + 0.01) 0.78])))   ; the hatch, no wider than the platform's footing
    (map (x \ strip-light [(sx + x) (hub + 1.21) 0]) [-2.3 -1.25 1.25 2.3])
    (block [(sx + 1.9) cy -1.13] [(sx + 2.94) (cy + 0.2) 0.9] wood)
    (mattress [(sx + 2.42) (cy + 0.2) -1.1] 0)
    (map (q \ pa [(sx + q 0 * 2.95) (hub + 1.21) (q 1 * 1.14)] [(0 - q 0) (0 - q 1)]) [[1 1] [1 -1] [-1 1] [-1 -1]])]))

(level "the ring"
  (surface 'torus lx lz)
  (textures {'wall paper 'floor carpet 'ceiling tiles 'door oak})
  (start [(cx * (ci + 0.5)) 0 (cz * (cj + 1) - wt - 0.6)] 180 0)
  (sky 13 'clear) (skylight (rgb 0.12 0.11 0.09))
  (ambient (rgb 0.78 0.72 0.5))
  (void [-4 -3 -4] [(lx + 4) (top + 14) (lz + 4)])
  (land grass (rows ground))
  (map (w \ along (w 0) (flow [0.6 0] (drape water (w 1)))) waters)
  ; ..the cairn, the posts down the outside every sixteen metres, and round the tube every eight
  (cairn 6 (lz / 2))
  (map (x \ post x (lz / 2) stone) (filter (x \ rd x (lz / 2) > 4.5) (map (i \ 40.0 + 16.0 * i) ^17)))
  (map (z \ post 80.0 z stone) (filter (z \ rd 80.0 z > 4.5) (map (i \ 4.0 + 8.0 * i) ^11)))
  ; ..under it the rooms, carved out of the ground, the ways between them, their lights and their buzz
  (map (i \ map (j \ cell i j) ^nz) ^nx)
  hall
  (map (i \ cats (map (j \ ways i j) ^nz)) ^nx)
  (map (i \ map (j \ panels i j) ^nz) ^nx)
  (closet ci cj)
  exits
  pas
  (stereo (cx * (gis 2 + 0.5)) (cz * (<gjs + 3) - wt))
  (hum 'fluorescent [0 0 0] [lx mh lz])
  ; ..and the well up out of them, and the tree in its mound, climbed up it
  (skin {'all concrete} (street [(tx - wh) (gh - 0.05) (tz - wh)] [(tx + wh) (top + 0.05) (tz + wh)]))
  (whole (mound tx tz 2.4 0.8 0.6))
  (tree [tx 0 tz] 7 bark)
  ; ..a speaker out by the cairn, and the ring's middle
  (cabinet [9.6 (ground 9.6 46.5 - 0.1) 46.5] [-1 0])
  hang)
