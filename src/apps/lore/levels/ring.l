; `love play src/apps/lore/levels/ring.l`: a world laid round a ring's tube, walked all the
; way round either way. x runs round the ring and z round the tube, its outside halfway; a
; row of posts down the outside, a ring of them round the tube, a river winding
; round it, and a cairn where the walk begins, met again coming round. under the grass, round a smaller tube
; inside it, a maze of yellow rooms the whole way round, down a stair by the cairn
(borrow 'scenery)

(: lx 320.0 lz 88.0)                   ; round the ring and round the maze's floor
(: mh 3.0 top 4.5)                     ; the maze's height, and how far over its floor the grass is

; the textures: grass, stone, the cairn's red stone and the river's water; below, the rooms'
; wallpaper, carpet and ceiling tiles, and the stair's concrete
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
(: concrete (feel 'hard (texture 32 32 1.5 '((fill (grey 0.5)) (noise 1 0.12) (noise 6 0.1) (patches 5 0.15 (shade 0.85))))))

; the ground: swells that come round whole every way, the river's bed sunk along it, and
; flat round the stair; each asked of x a number or a tray of them
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
(: (ground x z) (top + bed x z * ease (max (span (x - 20.0) - 4.0) (span (z - 44.0) - 2.0)) 2.0 8.0))
(: gm 2.0 xs (map (i \ gm * i) ^(int (lx / gm) + 1)) zs (map (i \ gm * i) ^(int (lz / gm) + 1)) X (gem-tray [#xs] xs))
(: (rows f) (map (z \ (: Y (f X z) (map (i \ [(xs i) (peep Y i 0.0) z]) ^#xs))) zs))

; a post standing on the ground at x z, a cairn three stones high
(: (post x z t) (: y (ground x z) (skin {'all t} (solid (box [(x - 0.2) (y - 0.5) (z - 0.2)] [(x + 0.2) (y + 1.8) (z + 0.2)])))))
; ..the river's water, a strip down its middle a metre a row, cut where it goes round the
; tube past lz so none straddles it, each piece a row over the cut to meet the next and laid
; along from as far down the river as it starts; none in the stair's well
(: (stair? p) (: z (around (p 2 - 44.0) lz) (14.5 < p 0 && p 0 < 25.5 && span z < 3.5)))
(: (water-row x) (: z (rz x) n (sqrt (1.0 + rs * rs)) u (3.4 * rs / n) v (-3.4 / n)
   (map (k \ (: p [(x + k * u) (top - 0.45) (z + k * v)] ((stair? p) ? () p))) [-1.0 0.0 1.0])))
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
; first room to every other, then a share of the walls left knocked through, and of those
; standing a share with a doorway
(: nx 50 nz 13 cx (lx / nx) cz (lz / nz) wt 0.1)
(: (h01 a b) (: s (sin (a * 12.9898 + b * 78.233 + 0.5) * 43758.5453) (s - floor s)))
(: (cid i j) ((i + nx) % nx * nz + (j + nz) % nz))
(: dug (: seen {} open {}
   (nb c d) (: i (c // nz) j (c % nz) (d @ 0 (cid (i + 1) j) 1 (cid (i - 1) j) 2 (cid i (j + 1)) (cid i (j - 1))))
   (edge c d) (: i (c // nz) j (c % nz) (d @ 0 (cid i j) 1 (cid (i - 1) j) 2 (100000 + cid i j) (100000 + cid i (j - 1))))
   (go c) (: _ (pin seen c 1)
             (each (map (q \ q 1) (sort (map (d \ [(h01 c d) d]) ^4)))
                   (d \ (: n (nb c d) (peep seen n 0 = 0 ? (: _ (pin open (edge c d) 1) (go n)) 0)))))
   _ (go 0)
   open))
; ..room i j, and the way through its wall toward x and toward z: the whole wall, a doorway
; or none; a room open toward x reaching over into the next, and a way across where the
; world wraps cut either side of it
(: (through e) (? (peep dug e 0 = 1 || h01 e 7 <= 0.45) 'open (h01 e 11 < 0.6) 'door 'none))
(: (cell i j) (: wide (i < nx - 1 && through (cid i j) = 'open)
   (room [(cx * i + wt) 0 (cz * j + wt)] [(cx * (i + 1) + (wide ? (wt + 0.01) (0.0 - wt))) mh (cz * (j + 1) - wt)])))
(: (gap lo hi) (air (box lo hi)))
(: (ways i j) (: x0 (cx * i + wt) x1 (cx * (i + 1) - wt) z0 (cz * j + wt) z1 (cz * (j + 1) - wt) xm (0.5 * (x0 + x1)) zm (0.5 * (z0 + z1))
   (wx a b) (? (i < nx - 1) [(gap [(x1 - 0.01) 0 a] [(x1 + 2.0 * wt + 0.01) mh b])]
               [(gap [(x1 - 0.01) 0 a] [lx mh b]) (gap [0 0 a] [(wt + 0.01) mh b])])
   (wz a b) (? (j < nz - 1) [(gap [a 0 (z1 - 0.01)] [b mh (z1 + 2.0 * wt + 0.01)])]
               [(gap [a 0 (z1 - 0.01)] [b mh lz]) (gap [a 0 0] [b mh (wt + 0.01)])])
   ((through (cid i j) @ 'open (i < nx - 1 ? () (wx z0 z1)) 'door (wx (zm - 0.7) (zm + 0.7)) ())
    + (through (100000 + cid i j) @ 'open (wz x0 x1) 'door (wz (xm - 0.7) (xm + 0.7)) ()))))
; ..two troffers to a room's ceiling on its tiles' grid, every one lit by the rooms' own
; light, none where the stair's well opens it
(: (panels i j) (: x (cx * (i + 0.5)) z (0.6 * floor (cz * (j + 0.5) / 0.6 + 0.5)) (well? x) (15.5 < x && x < 24.5 && 41.5 < z && z < 46.5)
   (on x) (0.6 * floor (x / 0.6) + 0.3)
   (map (x \ unlit (troffer (strip-light [x mh z]))) (filter (x \ !(well? x)) [(on (x - 1.6)) (on (x + 1.6))]))))
; ..and the stair down by the cairn: a well open to the sky, its steps going down east
(: rise (top / 18.0) run (8.0 / 18.0))
(: (step k) (skin {'all concrete} (solid (box [(16.0 + run * k) 0 42] [(16.0 + run * (k + 1)) (top - rise * (k + 1)) 46]))))

(level "the ring"
  (surface 'torus lx lz)
  (textures {'wall paper 'floor carpet 'ceiling tiles})
  (start [10 top (lz / 2)] 90 0)
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
  (map (i \ cats (map (j \ ways i j) ^nz)) ^nx)
  (map (i \ map (j \ panels i j) ^nz) ^nx)
  (hum 'fluorescent [0 0 0] [lx mh lz])
  ; ..and the stair down to them
  (skin {'all concrete} (street [16 0 42] [24 (top + 0.05) 46]))
  (map step ^17))
