; `love play src/apps/lore/levels/ring.l`: a world laid round a ring's tube, walked all the
; way round either way. x runs round the ring and z round the tube, its outside halfway; a
; row of posts down the outside, a ring of them round the tube, a river winding
; round it, and a little graveyard well round from the well. under the grass, round a smaller
; tube inside it, a maze of yellow rooms a third of the way round, some with something in
; them: the walk begins in a dark closet off one, and in a white hall a tree grows up through
; a well to the grass, climbed to get out up
; the vines the loop grows on it. over it all a pink orb hangs in the ring's middle, a lift
; up to it from the tube's inside, and in it a shipping container where the hall's stereo
; is heard too
(borrow 'scenery)

(: lx 320.0 lz 88.0)                   ; round the ring and round the maze's floor
(: mh 3.0 top 4.5)                     ; the maze's height, and how far over its floor the grass is
(: exit-signs 1)                       ; while playtesting, the way out of the maze signed
(: tx 17.0 tz 51.0 wh 1.0)             ; the tree mid-hall, and the well over it on a square of the grass
(: nx 50 nz 13 cx (lx / nx) cz (lz / nz) wt 0.1)   ; the maze's rooms round and across, their size, its walls
(: gis [1 2 3] gjs [6 7 8] gh 4.0)     ; the hall's rooms, clear of the river, and its height
(: sx 90.0 hub ((lx - lz) / tau))      ; the lift's shaft up off the tube's inside, and how high the ring's middle is over it
(: orb-r 6.0)                          ; the pink orb's radius

; the textures: grass, stone and the river's water; below, the rooms'
; wallpaper, carpet and ceiling tiles, and the well's concrete
(: grass (feel 'grass (texture 64 64 2
          '((fill (rgb 0.3 0.52 0.2)) (noise 1 0.2) (fbm 8 4 0.22) (stain 16 3 0.45 0.35 (shade 0.82))
            (stain 8 3 0.4 0.35 (mix (rgb 0.5 0.66 0.26) 0.7))))))
(: stone (feel 'hard (texture 32 32 1.2 '((fill (grey 0.55)) (noise 1 0.06) (fbm 8 4 0.18) (stain 16 3 0.42 0.35 (shade 0.84)) (relief 1.5 2 0.12)))))
(: water (texture 64 64 4
          '((fill (rgb 0.3 0.5 0.72)) (fbm 16 4 0.2) (stain 16 3 0.42 0.35 (mix (rgb 0.5 0.7 0.85) 0.6)) (noise 1 0.03))))
(: paper (texture 64 64 1.6
          '((fill (rgb 0.8 0.73 0.44)) (stripes 8 2 0 (shade 0.95)) (fbm 16 3 0.06) (stain 16 3 0.4 0.4 (shade 0.92))
            (noise 1 0.03))))
(: carpet (feel 'soft (texture 64 64 2
           '((fill (rgb 0.58 0.51 0.31)) (noise 1 0.16) (fbm 8 4 0.14) (stain 16 3 0.42 0.35 (shade 0.86))))))
(: tiles (texture 64 64 1.2 '((fill (rgb 0.84 0.82 0.72)) (noise 1 0.04) (fbm 16 3 0.06) (stain 32 3 0.38 0.4 (shade 0.94)) (grid 32 32 1 (grey 0.6)))))
(: oak (feel 'wood (texture 32 64 0.9 '((fill (rgb 0.52 0.34 0.19)) (stripes 5 1 0 (shade 0.9)) (noise 1 12 0.08) (fbm 8 3 0.08)
          (within 5 5 27 29 (bevel 22 24 1 (shade 1.18) (shade 0.68))) (within 5 34 27 59 (bevel 22 25 1 (shade 1.18) (shade 0.68)))))))
(: concrete (feel 'hard (texture 32 32 1.5 '((fill (grey 0.52)) (noise 1 0.06) (fbm 16 4 0.18) (stain 16 3 0.4 0.35 (shade 0.86)) (relief 1.5 2 0.12)))))

; the ground: swells that come round whole every way, the river's bed sunk along it, flat
; round the well and the lift's foot, and over the hall never lower than a slab over its
; ceiling; each asked of x a number or a tray of them
(: (span v) (max v -v))
; ..a die for a and b, 0 to 1
(: (h01 a b) (: s (sin (a * 12.9898 + b * 78.233 + 0.5) * 43758.5453) (s - floor s)))
(: (swell x z) (: a (tau * x / lx) b (tau * z / lz)
   (0.9 * (0.5 + 0.5 * sin (5.0 * a + 0.3)) * (0.5 + 0.5 * sin (3.0 * b + 1.1)) + 0.3 * sin (11.0 * a - 4.0 * b))))
; ..the river: wn times round the tube for once round the ring, 0 the tube's inside all
; the way, crossing the start's x there so the walk begins across the tube from it; at x its
; middle's z, its slope, and how far a place is from it, the shorter way round
(: wn 6)
(: rs (wn * lz / lx) (rz x) (rs * (x - 10.0)))
(: (around d l) (d - l * floor (d / l + 0.5)))
(: (rd x z) (span (around (z - rz x) lz) / sqrt (1.0 + 2 rs)))
(: (bed x z) (: d (rd x z) (swell x z * ease d 2.5 7.0 - 1.2 * (1.0 - ease d 1.8 4.2))))
(: (ground x z) (: f (max (span (x - sx) - 1.0) (span (around z lz) - 1.0))
   g (top + bed x z * ease (max (span (x - tx) - wh - 1.0) (span (z - tz) - wh - 1.0)) 2.0 8.0 * ease f 1.0 5.0)
   o (max (max (cx * <gis - x) (x - cx * (<gis + 3))) (max (cz * <gjs - z) (z - cz * (<gjs + 3))))
   (g + max 0.0 (gh + 0.4 - g) * (1.0 - ease o 0.0 3.0))))
(: gm 2.0 xs (map (i \ gm * i) ^(int (lx / gm) + 1)) zs (map (i \ gm * i) ^(int (lz / gm) + 1)) X (gem-tray [#xs] xs))
(: (rows f) (map (z \ (: Y (f X z) (map (i \ [(xs i) (peep Y i 0.0) z]) ^#xs))) zs))

; a post standing on the ground at x z, and a plinth of grey stone, capped
(: (post x z t) (: y (ground x z) (skin {'all t} (solid (box [(x - 0.2) (y - 0.5) (z - 0.2)] [(x + 0.2) (y + 1.8) (z + 0.2)])))))
; ..the river's water, clear, a strip down its middle a metre a row, cut where it goes round the
; tube past lz so none straddles it, each piece a row over the cut to meet the next and laid
; along from as far down the river as it starts; none by the well
(: (well? p) (: z (around (p 2 - tz) lz) (span (p 0 - tx) < wh + 1.5 && span z < wh + 1.5)))
(: (water-row x) (: z (rz x) n (sqrt (1.0 + 2 rs)) u (3.4 * rs / n) v (-3.4 / n)
   (map (k \ (: p [(x + k * u) (top - 0.45) (z + k * v)] ((well? p) ? () p))) [-1.0 0.0 1.0])))
(: waters (: rows (map (i \ [i (water-row (1.0 * i))]) ^321) (cut r) (floor (rz (1.0 * r 0) / lz))
   S (map (i \ i * sqrt (1.0 + 2 rs)) ^321)
   (go l run out) (? (atom? l) (rev (rev run . out))
      (two? run && cut <l != cut <run) (go >l [<l] (rev (<l . run) . out))
      (go >l (<l . run) out))
   (map (piece \ (: o (lz * cut <piece) [(S (<piece 0)) (map (q \ map (p \ p = () ? () [(p 0) (p 1) (p 2 - o)]) (q 1)) piece)])) (go rows () ()))))
(: (plinth x z) (: y (ground x z)
   [(skin {'all stone} (solid (box [(x - 0.4) (y - 0.2) (z - 0.4)] [(x + 0.4) (y + 0.7) (z + 0.4)])))
    (skin {'all stone} (solid (box [(x - 0.46) (y + 0.7) (z - 0.46)] [(x + 0.46) (y + 0.78) (z + 0.46)])))]))
; ..the graveyard: a low iron fence on a square down the outside, a hundred metres round from
; the well, past where the tube's curve hides it from there; its gate swinging in, facing
; the well's way round, a path from it to the plinth at the far end, and ten small headstones
; in rows either side of the path facing the gate, as a cemetery's do, the last row not yet
; full; each its name
(: iron (feel 'metal (texture 32 32 0.3 '((fill (grey 0.07)) (noise 1 0.08) (fbm 8 3 0.12) (stain 8 3 0.4 0.35 (mix (rgb 0.2 0.1 0.06) 0.8))))))
(: granite (feel 'hard (texture 32 32 0.4 '((fill (grey 0.58)) (noise 1 0.08) (fbm 8 3 0.12) (stain 8 3 0.4 0.3 (mix (rgb 0.5 0.56 0.36) 0.8)) (relief 1.5 2 0.1)))))
(: yx 237.0 yz (lz / 2) yh 4.0)         ; the yard's middle, and the fence's half side
(: mourned ["Yuki" "Bella" "Light" "Salt" "Lauren" "Bette" "Ingrid" "Chestnut" "Lentil" "Chickpea"])
(: (on-ground x z) [x (ground x z) z])
; ..n points on the ground from a toward b, a the first
(: (side a b n) (map (k \ (: s (k / (1.0 * n)) (on-ground (a 0 + s * (b 0 - a 0)) (a 1 + s * (b 1 - a 1))))) ^n))
; ..the headstones' places, rows of four across the path and a last of two
(: plots (: zs [(yz - 2.6) (yz - 1.4) (yz + 1.4) (yz + 2.6)]
   (map (z \ [(yx - 1.0) z]) zs + map (z \ [(yx + 0.6) z]) zs + [[(yx + 2.2) (yz - 1.4)] [(yx + 2.2) (yz + 1.4)]])))
(: yard (: e (yx + yh) w (yx - yh) no (yz + yh) so (yz - yh)
   [(fence (side [e (yz + 0.5)] [e no] 2 + side [e no] [w no] 4 + side [w no] [w so] 4 + side [w so] [e so] 4
            + side [e so] [e (yz - 0.5)] 2 + [(on-ground e (yz - 0.5))]) 1.0 iron)
    (gate (on-ground e (yz + 0.47)) (on-ground e (yz - 0.47)) 1.0 95 iron)
    (map (i \ (: q (plots i) (grave (on-ground (q 0) (q 1)) (90.0 + 5.0 * (h01 i 3 - 0.5)) (mourned i) granite))) ^10)]))

; the maze: rooms mn of the nx round from column m0, all nz of them round the tube and
; wrapping as the world does, each carved out of the ground with the ground left standing
; between them for walls. a passage dug from its first room to every other, through a
; doorway, seldom the whole wall; then more, so it loops, and most dead ends opened on past
(: m0 40 mn 18)
(: maze-seed 0 (roll a b) (h01 a (b + 977 * maze-seed)))   ; another seed, another maze
(: (in? i) ((i - m0 + nx) % nx < mn))
(: mcols (map (k \ (m0 + k) % nx) ^mn) mcells (catmap (i \ map (j \ i * nz + j) ^nz) mcols))
(: (cid i j) ((i + nx) % nx * nz + (j + nz) % nz))
; ..the room through room c's wall d, and that wall
(: (nb c d) (: i (c // nz) j (c % nz) (d @ 0 (cid (i + 1) j) 1 (cid (i - 1) j) 2 (cid i (j + 1)) (cid i (j - 1)))))
(: (edge c d) (: i (c // nz) j (c % nz) (d @ 0 (cid i j) 1 (cid (i - 1) j) 2 (100000 + cid i j) (100000 + cid i (j - 1)))))
; ..the hall: three rooms by three by the graveyard, one room, white and higher than the rest, its
; floor in black and white squares, a doorway in the middle of each side. and the closet:
; a dark one off the end of a room at the maze's far end, its door opened by hand, where the
; player wakes, and another off a room further round. the monitor's room, its far wall whole
(: ci 41 cj 6 zi 46 zj 1 ti 5 tj 2)
; ..and the rooms with something in them, to find and to know where you are by
(: office [47 4] store [42 1] waiting [ti tj] bedroom [7 9] flooded [49 11] files [44 10])
(: closets [[ci cj] [zi zj]] shut (map (q \ 100000 + cid (q 0) (q 1)) (closets + [[ti tj]]))
   sides (catmap (q \ [(cid (q 0) (q 1)) (cid (q 0 - 1) (q 1))]) closets))
(: (hall? i j) (elem i gis && elem j gjs))
(: gw (catmap (i \ map (cid i) gjs) gis))
(: dug (: seen {} open {}
   (go c) (: _ (pin seen c 1)
             (each (map (q \ q 1) (sort (map (d \ [(roll c d) d]) ^4)))
                   (d \ (: n (nb c d) e (edge c d) (peep seen n 0 = 0 && !(elem e shut) ? (: _ (pin open e 1) (go n)) 0)))))
   _ (each (filter (c \ !(in? (c // nz))) ^(nx * nz)) (c \ pin seen c 1))
   _ (each gw (c \ pin seen c 1))
   _ (go (cid m0 0))
   open))
; ..room i j, and the way through its wall toward x and toward z: the whole wall, a doorway
; or none; a room open toward x reaching over into the next, and a way across where the
; world wraps cut either side of it. the hall's walls shut but its doorways; the closets'
; rooms no wider than a doorway to their sides
(: hall-doors [(cid (<gis - 1) (gjs 1)) (cid (gis 2) (gjs 1)) (100000 + cid (gis 1) (<gjs - 1)) (100000 + cid (gis 1) (gjs 2))])
(: (round-hall e) (: c (e % 100000) i (c // nz) j (c % nz)
   (? (e < 100000) (hall? i j || hall? (i + 1) j) (hall? i j || hall? i (j + 1)))))
; ..a wall between two of the maze's rooms that may be opened, and each room's four
(: (inner? e) (: c (e % 100000) (in? (c // nz) && (e >= 100000 || in? (c // nz + 1)) && !(round-hall e) && !(elem e shut))))
(: (walls-of c) (: i (c // nz) j (c % nz) [(cid i j) (cid (i - 1) j) (100000 + cid i j) (100000 + cid i (j - 1))]))
; ..the loops: a fifth of the walls left opened; then a dead end, but some, opened through
; one more of its walls
(: braided (: o (foldl (\ t e (roll e 3 < 0.2 ? (pin t e 1) t)) (foldl (\ t e (pin t e 1)) {} (keys dug))
                       (filter inner? (catmap (c \ [c (100000 + c)]) mcells)))
   (way? e) (peep o e 0 = 1 || elem e hall-doors)
   (dead? c) (#(filter way? (walls-of c)) = 1)
   (more c) (: es (filter (e \ inner? e && !(way? e)) (walls-of c)) (two? es ? <(map (q \ q 1) (sort (map (e \ [(roll e 5) e]) es))) ()))
   (foldl (\ o c (? (!(hall? (c // nz) (c % nz)) && dead? c && roll c 5 < 0.75 && more c != ()) (pin o (more c) 1) o)) o mcells)))
; ..and a few of its rooms four to a hall, the walls between them gone
(: wides [[43 2] [48 7] [2 11] [5 3]])
(: wide-es (catmap (q \ (: i (q 0) j (q 1) [(cid i j) (cid i (j + 1)) (100000 + cid i j) (100000 + cid (i + 1) j)])) wides))
(: (through e) (? (elem e hall-doors) 'door (round-hall e) 'none
                  (elem e shut) 'none
                  (elem e wide-es) 'open
                  (: w (? (peep braided e 0 = 1) (roll e 7 <= 0.36 ? 'open 'door) 'none)
                     (elem e sides && w = 'open ? 'door w))))
; ..a room with nothing of its own in it; a doorway between two such as wide as it falls and
; where, every other one in the middle: [its middle off the wall's, its half width]
(: (plain? c) (: q [(c // nz) (c % nz)] (in? (q 0) && !(hall? (q 0) (q 1)) && !(elem q ([office store waiting bedroom flooded files] + closets)))))
(: (plain-e? e) (: c (e % 100000) (plain? c && plain? (nb c (e < 100000 ? 0 2)))))
; ..half a wall's thickness: wt by a room with something in it, else the first of thicks whose
; share the die is under; pr where the wall is gone, so a corner left by three or four such
; stands as a column
(: pr 0.38 thicks [[0.5 wt] [0.75 0.22] [0.9 0.34] [1.0 0.5]])
(: (half e) (? (!(plain-e? e)) wt (through e = 'open) pr (: h (roll e 41) (<(filter (q \ h < q 0) thicks) 1))))
; ..and so where room c stops: [x0 x1 z0 z1]
(: (faces c) (: i (c // nz) j (c % nz) (w d) (half (edge c d))
   [(cx * i + w 1) (cx * (i + 1) - w 0) (cz * j + w 3) (cz * (j + 1) - w 2)]))
(: (doorway e) (? (!(plain-e? e) || roll e 21 < 0.35) [0.0 0.7]
      (: h (0.7 + 1.1 * roll e 22) [((2.4 - h) * (2.0 * roll e 23 - 1.0)) h])))
(: white (texture 64 64 2 '((fill (grey 0.92)) (fbm 16 3 0.04))))
(: checks (feel 'hard (texture 64 64 1.2 '((fill (grey 0.93)) (checker 32 32 (grey 0.08)) (fbm 16 3 0.05)))))
; ..across a wall gone, what both its rooms are open to, along it; where they are the same
; toward x the one room reaches over into the next
(: (both e k) (: f (faces (e % 100000)) g (faces (nb (e % 100000) (e < 100000 ? 0 2))) [(max (f k) (g k)) (min (f (k + 1)) (g (k + 1)))]))
(: (over? i j) (: e (cid i j) (i < nx - 1 && through e = 'open && half (edge e 2) = half (edge (nb e 0) 2) && half (edge e 3) = half (edge (nb e 0) 3))))
(: (cell i j) (: wide (over? i j) f (faces (cid i j)) top-z (elem [i j] closets ? (f 3 - 1.6) (f 3))
   r (room [(f 0) 0 (f 2)] [(wide ? (cx * (i + 1) + half (cid i j) + 0.01) (f 1)) mh top-z])
   (? (hall? i j) () ([i j] = bedroom) (dark r) r)))
(: hall (dark (skin {'walls white 'floor checks 'ceiling white}
                    (room [(cx * <gis + wt) 0 (cz * <gjs + wt)] [(cx * (<gis + 3) - wt) gh (cz * (<gjs + 3) - wt)]))))
(: (gap lo hi) (air (box lo hi)))
(: (ways i j) (: c (cid i j) f (faces c) x1 (f 1) z1 (f 3) wa (half c) wb (half (100000 + c)) xm (cx * (i + 0.5)) zm (cz * (j + 0.5))
   (wx a b) (? (i < nx - 1) [(gap [(x1 - 0.01) 0 a] [(x1 + 2.0 * wa + 0.01) mh b])]
               [(gap [(x1 - 0.01) 0 a] [lx mh b]) (gap [0 0 a] [(wa + 0.01) mh b])])
   (wz a b) (? (j < nz - 1) [(gap [a 0 (z1 - 0.01)] [b mh (z1 + 2.0 * wb + 0.01)])]
               [(gap [a 0 (z1 - 0.01)] [b mh lz]) (gap [a 0 0] [b mh (wb + 0.01)])])
   ((through (cid i j) @ 'open (over? i j ? () (both c 2 @ q (wx (q 0) (q 1)))) 'door (doorway (cid i j) @ [o h] (wx (zm + o - h) (zm + o + h))) ())
    + (through (100000 + cid i j) @ 'open (both (100000 + c) 0 @ q (wz (q 0) (q 1))) 'door (doorway (100000 + cid i j) @ [o h] (wz (xm + o - h) (xm + o + h))) ()))))
; ..what breaks the rooms up, thrown for each: pillars floor to ceiling on its quarters, clear
; of its lights, and a stub of wall out from a whole one; the four rooms of a wide hall full of
; pillars
(: (pillar x z) (whole (skin {'all paper} (solid (box [(x - pr) 0 (z - pr)] [(x + pr) mh (z + pr)])))))
(: wide-cs (catmap (q \ (: i (q 0) j (q 1) [(cid i j) (cid (i + 1) j) (cid i (j + 1)) (cid (i + 1) (j + 1))])) wides))
(: (stub c) (: f (faces c) x0 (f 0) x1 (f 1) z0 (f 2) z1 (f 3)
   ds (filter (d \ through (edge c d) = 'none) ^4) l (1.5 + 0.8 * roll c 34) o ((roll c 35 < 0.5 ? -1.0 1.0) * (1.25 + 0.4 * roll c 36)) zm (cz * (c % nz + 0.5))
   xs (cx * (c // nz + 0.5) + o) zs (zm + o) t (0.12 + 0.18 * roll c 37)
   (bar lo hi) [(whole (skin {'all paper} (solid (box lo hi))))]
   (? (atom? ds) ()
      (ds (int (roll c 33 * #ds)) @ 0 (bar [(x1 - l) 0 (zs - t)] [x1 mh (zs + t)]) 1 (bar [x0 0 (zs - t)] [(x0 + l) mh (zs + t)])
                                   2 (bar [(xs - t) 0 (max (z1 - l) (zm + 0.95))] [(xs + t) mh z1]) (bar [(xs - t) 0 z0] [(xs + t) mh (min (z0 + l) (zm - 0.95))])))))
(: (pillars c) (: xm (cx * (c // nz + 0.5)) zm (cz * (c % nz + 0.5)) k (int (4.0 * roll c 31))
   qs [[-1.0 -1.0] [1.0 -1.0] [1.0 1.0] [-1.0 1.0]] (at n) (: q (qs ((k + n) % 4)) (pillar (xm + 1.55 * q 0) (zm + 1.7 * q 1))) t (roll c 32)
   (? (!(plain? c)) () (elem c wide-cs) (map at ^4)
      (t < 0.28) () (t < 0.5) [(at 0)] (t < 0.66) [(at 0) (at 2)] (t < 0.71) (map at ^4) (t < 0.8) [(at 0) (at 1)] (stub c))))
; ..the closet, a doorway wide and a stride and a half deep, and its door
(: (closet i j) (: xm (cx * (i + 0.5)) z1 (cz * (j + 1) - wt)
   [(dark (room [(xm - 0.7) 0 (z1 - 1.4)] [(xm + 0.7) 2.4 z1]))
    (by-hand (door [xm 0 (z1 - 1.5)] 0.9 2.1))]))
; ..two troffers to a room's ceiling on its tiles' grid, every one lit by the rooms' own
; light; one to each of the hall's, lighting it, none under the well
(: (panels i j) (: x (cx * (i + 0.5)) z (0.6 * floor (cz * (j + 0.5) / 0.6 + 0.5)) (under? x) (span (x - tx) < wh + 0.4 && span (z - tz) < wh + 0.4)
   (on x) (0.6 * floor (x / 0.6) + 0.3)
   (? (hall? i j) (under? x ? () [(troffer (strip-light [(on x) gh z]))]) ([i j] = bedroom) ()
      (map (x \ unlit (troffer (strip-light [x mh z]))) [(on (x - 1.6)) (on (x + 1.6))]))))
; ..in the hall the tree in a mound of dirt, and a stereo before it, its back to the tree, so
; whoever starts the loop sees the vines grow: a cabinet, the amplifier on it, its display lit
; while the loop plays, the tape deck on top, a tap on any of it playing the loop, a speaker
; either side
(: dirt (feel 'soft (texture 64 64 1.5 '((fill (rgb 0.34 0.25 0.17)) (noise 1 0.14) (fbm 8 4 0.18) (stain 16 3 0.42 0.35 (shade 0.8)) (relief 1.5 2 0.12)))))
(: bark (feel 'wood (texture 32 64 0.5 '((fill (rgb 0.46 0.43 0.38)) (noise 1 0.08) (noise 1 14 0.15) (fbm 8 3 0.08) (stripes 11 1 0 (shade 1.12))
          (cracks 8 24 1 5 (shade 0.82)) (fbm 8 3 0.1) (stain 8 3 0.4 0.35 (shade 0.88))))))
(: wood (feel 'wood (texture 64 64 0.8 '((fill (rgb 0.42 0.26 0.14)) (stripes 8 1 1 (shade 0.85)) (fbm 8 3 0.12)))))   ; its grain every 8, so it meets across the tile's edges
(: ash (texture 32 32 0.6 '((fill (grey 0.1)) (noise 1 0.08) (fbm 8 3 0.16))))
(: alu (feel 'metal (texture 32 32 0.5 '((fill (grey 0.6)) (stripes 2 1 0 (shade 0.92))))))
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
; ..the ring's own x and z to a metre at x y z: the tube bends them, and the further off it
; the more, so a box is laid true where it stands
(: (per x y z) (: R (lx / tau) r (lz / tau) [(R / (R + (r + y) * cos (z / r - pi))) (r / (r + y))]))
; ..a speaker's cabinet, the middle of its back's foot at x y z, facing f across the floor,
; k the ring's x and z to a metre there: a woofer, a midrange and a tweeter down its front,
; the loop heard from it
(: (block lo hi t) (skin {'all t} (solid (box lo hi))))
(: drivers (texture 30 64 0.5 '((fill (grey 0.1)) (noise 1 0.08) (fbm 8 3 0.16)
                                (disc 15 43 11 (grey 0.42)) (disc 15 43 9.8 (grey 0.05)) (disc 15 43 8 (grey 0.2)) (disc 15 43 3.5 (grey 0.45))
                                (disc 15 22 5.4 (grey 0.42)) (disc 15 22 4.5 (grey 0.05)) (disc 15 22 3.6 (grey 0.2)) (disc 15 22 1.6 (grey 0.45))
                                (disc 15 8 2.6 (grey 0.62)) (disc 15 8 1.3 (grey 0.36)))))
; ..as [body front]: the box, and the drivers on it with where the loop is heard from
(: (cabinet-in k o f) (: (p l h d) [(o 0 + k 0 * (l * -(f 1) + d * f 0)) (o 1 + h) (o 2 + k 1 * (l * f 0 + d * f 1))]
   w (sqrt (2 (k 0 * f 1) + 2 (k 1 * f 0)))
   [[(block (p -0.25 0.0 0.0) (p 0.25 1.05 0.42) ash)]
    [(decal (p 0.0 0.525 0.43) [(f 0) 0 (f 1)] [0 1 0] (0.47 * w) 1.0 drivers) (speaker (p 0.0 0.7 0.5))]]))
(: (cabinet o f) (: c (cabinet-in (per (o 0) (o 1) (o 2)) o f) (c 0 + c 1)))
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
(: (stereo x z) (: w 0.4
   ([(deck [(x - 0.9) 0 (z - 0.45)] [(x + 0.9) 0.86 z])
     (block [(x - 0.9) 0 (z - 0.45)] [(x + 0.9) 0.5 z] wood)
     (block [(x - w) 0.5 (z - 0.38)] [(x + w) 0.63 (z - 0.06)] ash)
     (block [(x - w) 0.63 (z - 0.38)] [(x + w) 0.72 (z - 0.06)] alu)
     (block [(x - w) 0.72 (z - 0.38)] [(x + w) 0.86 (z - 0.06)] ash)
     (decal [x 0.79 (z - 0.381)] [0 0 -1] [0 1 0] 0.78 0.13 tapeface)
     (rod [(x + 0.25) 0.63 (z - 0.38)] [(x + 0.25) 0.63 (z - 0.4)] 0.025 8 alu)
     (rod [(x + 0.32) 0.63 (z - 0.38)] [(x + 0.32) 0.63 (z - 0.4)] 0.018 8 alu)
     (playing (ad [(x - 0.15) 0.565 (z - 0.381)] [0 0 -1] [0 1 0] 0.3 0.06 lcd))]
    + cabinet [(x - 1.25) 0 z] [0 -1] + cabinet [(x + 1.25) 0 z] [0 -1])))
; ..and four round the tree, at its corners, each facing it: its box built square and
; swung, its front laid facing the tree as it is
(: round-tree (map (q \ (: x (tx + 3.0 * q 0) z (tz + 3.0 * q 1) f [(-0.7071 * q 0) (-0.7071 * q 1)]
                          ((turn (180.0 / pi * atan2 (f 0) (f 1)) [x z] (cabinet-in [1.0 1.0] [x 0 z] [0 1] 0)) + cabinet-in [1.0 1.0] [x 0 z] f 1)))
                   [[1 1] [1 -1] [-1 1] [-1 -1]]))
; ..a cable lying along the floor through the points ps [x z]: its corners eased, wandering
; either side as it goes, still at its ends; a half round r high, a drape
(: (snake ps sd r) (: st 0.15
   (len a b) (: dx (b 0 - a 0) dz (b 1 - a 1) (sqrt (2 dx + 2 dz)))
   (leg a b) (: n (max 1 (int (len a b / st + 0.5))) (map (k \ [(a 0 + k / (1.0 * n) * (b 0 - a 0)) (a 1 + k / (1.0 * n) * (b 1 - a 1))]) ^n))
   base (catmap (i \ leg (ps i) (ps (i + 1))) ^(#ps - 1) + [(ps (#ps - 1))]) n #base
   (soft q) (map (i \ (? (i = 0 || i = n - 1) (q i) (: a (q (i - 1)) b (q i) c (q (i + 1)) [((a 0 + 2.0 * b 0 + c 0) / 4.0) ((a 1 + 2.0 * b 1 + c 1) / 4.0)]))) ^n)
   sm (foldl (\ q _ (soft q)) base ^8)
   (nrm q i) (: a (q (max 0 (i - 1))) b (q (min (n - 1) (i + 1))) dx (b 0 - a 0) dz (b 1 - a 1) l (max 1e-6 (sqrt (2 dx + 2 dz))) [-(dz / l) (dx / l)])
   L (st * (n - 1))
   wig (map (i \ (: s (st * i) e (min 1.0 (min (s / 0.6) ((L - s) / 0.6))) w (e * (0.08 * sin (tau * s / 1.9 + sd) + 0.04 * sin (tau * s / 0.8 + 2.3 * sd)))
                    m (nrm sm i) [(sm i 0 + w * m 0) (sm i 1 + w * m 1)])) ^n)
   (map (i \ (: m (nrm wig i) c (wig i) (map (k \ (: a (-0.3 + k * (pi + 0.6) / 6.0) [(c 0 + r * cos a * m 0) (r + r * sin a) (c 1 + r * cos a * m 1)])) ^7))) ^n)))
; ..the stereo where it stands, the middle of its back
(: sx0 tx sz0 (tz - 4.2))
; ..their cables from under the stereo's back, each its own way to its speaker's back, those
; to the far side wide round the near ones' and the mound, none crossing another
(: cables (: z0 (sz0 - 0.05) z1 (sz0 + 0.15) z2 (sz0 + 0.55) e (tx + 3.0) w (tx - 3.0) n (tz + 3.0) s (tz - 3.0)
   (map (q \ drape ash (snake (q 1) (q 0) 0.03))
        [[0.4 [[(sx0 - 0.7) z0] [(sx0 - 0.7) z1] [(w - 0.8) z1] [(w - 0.8) (n + 1.0)] [w (n + 1.0)] [w n]]]
         [1.7 [[(sx0 + 0.7) z0] [(sx0 + 0.7) z1] [(e + 0.8) z1] [(e + 0.8) (n + 1.0)] [e (n + 1.0)] [e n]]]
         [2.9 [[(sx0 + 0.35) z0] [(sx0 + 0.35) z2] [e z2] [e s]]]
         [4.2 [[(sx0 - 0.35) z0] [(sx0 - 0.35) z2] [w z2] [w s]]]])))
; ..the way out: from the hall back through every way that goes through, each room's way
; on toward it, nearest first; a sign hung inside each way on from the closet, over its room
(: (goes? e) (elem (through e) ['open 'door]))
(: hops (: seen {} hop {}
   (near c) (: i (c // nz) j (c % nz)
     [[(cid (i + 1) j) (cid i j) 'xm] [(cid (i - 1) j) (cid (i - 1) j) 'xp]
      [(cid i (j + 1)) (100000 + cid i j) 'zm] [(cid i (j - 1)) (100000 + cid i (j - 1)) 'zp]])
   (reach c q) (: n (q 0) (? (peep seen n 0 = 0 && goes? (q 1)) (: _ (pin seen n 1) _ (pin hop n (q 2)) [n]) ()))
   (go fr) (? (atom? fr) hop (go (catmap (c \ catmap (reach c) (near c)) fr)))
   _ (each gw (c \ pin seen c 1))
   (go gw)))
(: (exit-sign c d) (: f (faces c) x0 (f 0) x1 (f 1) z0 (f 2) z1 (f 3) xm (cx * (c // nz + 0.5)) zm (cz * (c % nz + 0.5)) y (mh - 0.4) g (rgb 0.25 1.0 0.35)
   o (: e (edge c (d @ 'xp 0 'xm 1 'zp 2 3)) (through e = 'door ? (doorway e 0) 0.0))
   (d @ 'xp (unlit (neon [(x1 - 0.03) y (zm + o)] [-1 0 0] 0.2 "exit" g)) 'xm (unlit (neon [(x0 + 0.03) y (zm + o)] [1 0 0] 0.2 "exit" g))
        'zp (unlit (neon [(xm + o) y (z1 - 0.03)] [0 0 -1] 0.2 "exit" g)) (unlit (neon [(xm + o) y (z0 + 0.03)] [0 0 1] 0.2 "exit" g)))))
; ..the rooms on the way from the closet's to the hall, in order
(: way-out (: (go c out) (: d (hops c) i (c // nz) j (c % nz)
                           (? (elem c gw || d = ()) (rev out)
                              (go (d @ 'xp (cid (i + 1) j) 'xm (cid (i - 1) j) 'zp (cid i (j + 1)) (cid i (j - 1))) (c . out))))
   (go (cid ci cj) ())))
(: exits (exit-signs @ 1 (map (c \ exit-sign c (hops c)) way-out) ()))
; ..and pa speakers in the maze, one in a room's corner every third room on the way out and
; here and there all round the ring, where both its walls stand
(: (cornered? c) (: i (c // nz) j (c % nz) (in? i && !(hall? i j) && through (cid (i - 1) j) != 'open && through (100000 + cid i (j - 1)) != 'open)))
(: pas (: on (map (k \ way-out (3 * k + 1)) ^((#way-out + 1) // 3)) round (filter (c \ roll c 13 < 0.35 && !(elem c on)) mcells)
   (map (c \ pa (faces c @ f [(f 0) mh (f 2)]) [1 1]) (filter cornered? (on + round)))))

; ..the ring's middle, flat in the world straight up off the tube's inside: the lift's
; platform climbing its tether from the grass up the axis of a pink orb turning there, in at
; its pole, to a shipping container hung in it, the orb's inside a deeper pink. the tether
; runs on up through the container to its ceiling; the container lit by strips across its
; ceiling, a bed across one end on a frame, a pa speaker up in each corner, the hatch the platform
; comes up through in the middle of its floor
(: pinkorb (texture 128 64 8 '((fill (rgb 0.96 0.46 0.7)) (fbm 32 4 0.15) (stain 32 3 0.45 0.35 (shade 0.82)) (stain 16 3 0.4 0.35 (mix (rgb 1 0.78 0.9) 0.7)) (rows 30 34 (shade 0.86)))))
(: pinkin (texture 128 64 8 '((fill (rgb 0.72 0.24 0.5)) (fbm 32 4 0.18) (stain 32 3 0.45 0.35 (shade 0.78)) (stain 16 3 0.4 0.35 (mix (rgb 0.9 0.42 0.68) 0.7)) (grid 16 16 1 (shade 0.7)))))
(: steel (feel 'metal (texture 64 64 1.2 '((fill (rgb 0.52 0.2 0.14)) (stripes 6 3 0 (shade 0.78)) (fbm 8 3 0.08) (stain 16 3 0.4 0.35 (shade 0.88))))))
(: paint (feel 'metal (texture 64 64 1.2 '((fill (rgb 0.7 0.71 0.66)) (stripes 6 3 0 (shade 0.88)) (fbm 16 3 0.05)))))
(: ply (feel 'wood (texture 64 64 1.6 '((fill (rgb 0.56 0.43 0.28)) (rows 0 1 (shade 0.7)) (rows 32 33 (shade 0.7)) (noise 1 16 0.08) (fbm 16 3 0.1) (stripes 9 1 1 (shade 0.92))))))
(: cy (hub - 1.15))                     ; the container's floor
(: hang (pocket [sx 0]
   [(void [(sx - 1.6) (top - 0.5) -1.6] [(sx + 1.6) (hub - 1.29) 1.6])   ; the shaft, its floor under the grass
    (coarse 4 (glow (orb [sx hub 0] orb-r pinkorb 0.06)))
    (coarse 4 (glow (inward (orb [sx hub 0] (orb-r - 0.05) pinkin 0.06))))
    (sealed (tether (hub + 1.21 - cy) (lift [sx (top + 0.16) 0] 1.6 (cy - top - 0.16) alu)))   ; on its pad on the grass, shut till the string rings whole
    (void [(sx - 3.08) (hub - 1.35) -1.27] [(sx + 3.08) (hub + 1.34) 1.27])   ; a hair of air round the container, so its steel shows
    (skin {'all steel} (solid (box [(sx - 3.03) (hub - 1.3) -1.22] [(sx + 3.03) (hub + 1.29) 1.22])))
    (dark (skin {'walls paint 'floor ply 'ceiling paint} (room [(sx - 2.95) cy -1.14] [(sx + 2.95) (hub + 1.21) 1.14])))
    (skin {'all paint} (air (box [(sx - 0.81) (hub - 1.31) -0.81] [(sx + 0.81) (cy + 0.01) 0.81])))   ; the hatch, a hair wider than the platform, so the floor never overlaps it
    (map (x \ given 'loop-gone (dim 0) (strip-light [(sx + x) (hub + 1.21) 0])) [-2.3 -1.25 1.25 2.3])   ; out once the loop has worn away
    (block [(sx + 1.9) cy -1.13] [(sx + 2.94) (cy + 0.2) 0.9] wood)
    (sleep-bed [(sx + 2.42) (cy + 0.2) -1.1] 0 "earth.l" 'walk-in)   ; lain on, back to the station's walk-in
    (map (q \ pa [(sx + q 0 * 2.95) (hub + 1.21) (q 1 * 1.14)] [-(q 0) -(q 1)]) [[1 1] [1 -1] [-1 1] [-1 -1]])]))

; ..the resonance: a string round the ring's middle, halfway out from the pink orb to the
; grass, tied to the lift's tether, steps steps round; braziers at some steps, three across
; the tube on the outside, each on a plinth its step in roman numerals on every side; and by
; the lift's pad four wisps to set in them. a place clear of the river, the first of zs
(: steps 210 step-l (lx / steps))
(: (at-step n) (: x (sx + n * step-l) (x >= lx ? (x - lx) x)))
(: (dry x zs) (foldl (\ a z (a = () && rd x z > 3.0 ? z a)) () zs))
(: (roman n) (: (go n vs) (? (n = 0) "" (n >= vs 0 0) (vs 0 1 + go (n - vs 0 0) vs) (go n >vs))
   (go n [[100 "C"] [90 "XC"] [50 "L"] [40 "XL"] [10 "X"] [9 "IX"] [5 "V"] [4 "IV"] [1 "I"]])))
; ..a label's texture: three by five dots a letter, two texels a dot, light paint on stone
(: (glyph c) (c @ 73 "111010010010111" 86 "101101101101010" 88 "101101010101101" 76 "100100100100111" 67 "111100100100111"))
(: (label t) (: k #t x0 ((64 - 2 * (4 * k - 1)) // 2) y0 3
   dots (catmap (i \ (: f (glyph (t i)) (map (d \ [(x0 + 2 * (4 * i + d % 3)) (y0 + 2 * (d // 3))]) (filter (d \ f d = 49) ^15)))) ^k)
   (texture 64 16 0.8 ([['fill ['grey 0.5]] ['noise 1 0.06] ['fbm 8 3 0.1]] + map (q \ ['rect (q 0) (q 1) (q 0 + 2) (q 1 + 2) ['rgb 0.93 0.9 0.8]]) dots))))
(: hearths [[4 0] [10 0] [35 0] [42 0] [70 0] [105 0] [21 1] [25 1] [84 1]])
(: (hearth-at q) (: x (at-step (q 0)) z (dry x (q 1 = 1 ? [(lz / 2 - 2.0) (lz / 2 + 2.0) (lz / 2)] [2.5 (lz - 2.5) 4.0 (lz - 4.0)]))
   [x (ground x z + 0.3) z]))
(: (hearth q) (: p (hearth-at q) x (p 0) z (p 2)
   y (p 1 - 0.3) h 0.3 e 0.425 t (label (roman (q 0)))
   [(skin {'all stone} (solid (box [(x - 0.42) (y - 0.2) (z - 0.42)] [(x + 0.42) (y + h) (z + 0.42)])))
    (map (n \ decal [(x + e * n 0) (y + 0.14) (z + e * n 1)] [(n 0) 0 (n 1)] [0 1 0] 0.8 0.2 t) [[1 0] [-1 0] [0 1] [0 -1]])
    (brazier [x (y + h) z] stone)]))
; ..a place in room q, u along x and v along z from its corner, on its floor
(: (spot q u v) [(cx * q 0 + wt + u) 0 (cz * q 1 + wt + v)])
(: (spot-x q u v) (spot q u v 0) (spot-z q u v) (spot q u v 2))
; ..an office: two desks to the far wall, their chairs, a cabinet, cartons stacked by it
(: offices [(furnish 'desk (spot office 1.5 5.9) 0 {}) (furnish 'chair (spot office 1.5 5.1) 180 {})
            (furnish 'desk (spot office 4.7 5.9) 0 {}) (furnish 'chair (spot office 4.7 5.1) 180 {})
            (furnish 'cabinet (spot office 5.8 0.7) 270 {}) (furnish 'carton (spot office 0.6 0.6) 0 {})
            (furnish 'carton (spot office 1.2 0.6) 15 {}) (furnish 'carton (spot office 0.8 1.2) 40 {})])
; ..a storeroom: shelves down both sides, crates and cartons on the floor between
(: crate {'w 0.9 'd 0.7 'h 0.7})
(: stores [(furnish 'shelf (spot store 0.35 1.6) 270 {}) (furnish 'shelf (spot store 0.35 5.0) 270 {})
           (furnish 'shelf (spot store 5.85 1.6) 90 {}) (furnish 'shelf (spot store 5.85 5.0) 90 {})
           (furnish 'crate (spot store 2.2 1.4) 10 crate) (furnish 'crate (spot store 3.8 1.2) 80 crate) (furnish 'crate (spot store 2.6 5.3) 35 crate)
           (furnish 'carton (spot store 3.9 5.2) 0 {}) (furnish 'carton (spot store 4.2 4.6) 60 {})])
; ..a waiting room: two rows of chairs facing the monitor on its far wall
(: waits (catmap (r \ map (k \ furnish 'chair (spot waiting (1.6 + 1.0 * k) (1.4 + 1.3 * r)) 0 {}) ^4) ^2))
; ..a bedroom, dark: a bare mattress, a bulb over it
(: beds [(mattress (spot bedroom 3.1 4.2) 90) (bulb [(spot-x bedroom 3.1 0) 2.6 (spot-z bedroom 0 3.6)] (rgb 1.0 0.78 0.5))])
; ..a room sunk to a pool a stride in from its walls, tiled, steps down at one end, the
; water still but for a drift
(: pooltile (feel 'hard (texture 64 64 1.0 '((fill (rgb 0.8 0.86 0.87)) (noise 1 0.03) (grid 16 16 1 (grey 0.55)) (stain 32 3 0.4 0.35 (shade 0.9))))))
(: pool-d 0.9 pool-w -0.2)
(: floods (: q flooded x0 (spot-x q 0.6 0) x1 (spot-x q 5.6 0) z0 (spot-z q 0 0.6) z1 (spot-z q 0 5.97)
   [(skin {'all pooltile} (room [x0 -(pool-d) z0] [x1 0.01 z1]))
    (skin {'all pooltile} (solid (box [x0 -(pool-d) z0] [x1 -0.3 (z0 + 0.5)])))
    (skin {'all pooltile} (solid (box [x0 -(pool-d) (z0 + 0.5)] [x1 -0.6 (z0 + 1.0)])))
    (clear (flow [0.05 0.02] (drape water (map (b \ map (a \ [(x0 + (x1 - x0) * a / 5.0) pool-w (z0 + (z1 - z0) * b / 5.0)]) ^6) ^6))))]))
; ..a monitor filling a dead end's far wall, the orb on it as a camera somewhere out round
; the whole ring sees it, a new place after each card, framed as a security camera's picture is, the hour stamped in a
; pixel font three by five; now and then a burst of snow and a card, a solid colour and its
; text, the cards in turn. before the first picture, no signal
(: dots {48 "111101101101111" 49 "010110010010111" 50 "111001111100111" 51 "111001111001111" 52 "101101111001001"
         53 "111100111001111" 54 "111100111101111" 55 "111001001001001" 56 "111101111101111" 57 "111101111001111"
         65 "010101111101101" 66 "110101110101110" 67 "111100100100111" 68 "110101101101110" 69 "111100111100111"
         70 "111100111100100" 71 "111100101101111" 72 "101101111101101" 73 "111010010010111" 74 "001001001101010"
         75 "101101110101101" 76 "100100100100111" 77 "101111111101101" 78 "110101101101101" 79 "111101101101111"
         80 "111101111100100" 81 "010101101110011" 82 "110101110101101" 83 "111100111001111" 84 "111010010010010"
         85 "101101101101111" 86 "101101101101010" 87 "101101111111101" 88 "101101010101101" 89 "101101010010010"
         90 "111001010100111" 58 "000010000010000" 45 "000000111000000" 46 "000000000000010" 44 "000000000010100"})
(: (type x y s text c) (catmap (k \ (: g (peep dots (text k) "")
                                    (catmap (i \ (g i = 49 ? [['rect (x + (4 * k + i % 3) * s) (y + (i // 3) * s) (x + (4 * k + i % 3 + 1) * s) (y + (i // 3 + 1) * s) c]] ()))
                                            ^#g)))
                         ^#text))
(: camwhite '(grey 0.92))
(: (corner x y dx dy) [['rect (min x (x + 18 * dx)) (min y (y + 2 * dy)) (max x (x + 18 * dx)) (max y (y + 2 * dy)) camwhite]
                       ['rect (min x (x + 2 * dx)) (min y (y + 12 * dy)) (max x (x + 2 * dx)) (max y (y + 12 * dy)) camwhite]])
(: camover (texture 192 104 13
                  ([['fill 'hole]] + corner 6 6 1 1 + corner 186 6 -1 1 + corner 6 98 1 -1 + corner 186 98 -1 -1)))
(: camfeed [camover])
(: nosignal (texture 192 104 13 ([['fill '(rgb 0.2 0.23 0.26)] ['noise 2 0.25]] + type 60 46 2 "NO SIGNAL" '(grey 0.75))))
; ..a card: its words in capitals, as many to a line as fit in n, each line in the middle
(: (lines ws n) (foldl (\ a w (? (atom? a) [w] (#<a + 1 + #w <= n) (<a + " " + w . >a) (w . a))) () ws @ l (rev l)))
(: (card t c) (: ls (lines (words (upper t)) 22) y0 ((104 - (14 * #ls - 4)) // 2)
   (texture 192 104 13 ([['fill c]] + catmap (k \ (: l (ls k) (type ((192 - (8 * #l - 2)) // 2) (y0 + 14 * k) 2 l camwhite))) ^#ls))))
(: slates [(card "the patient operation of the overpowering rationality of conceptual harmonization" '(rgb 0.08 0.14 0.5))])
; ..the monitor across the waiting room's far wall, its chairs facing it
(: tv (: i ti j tj x (cx * (i + 0.5)) z (cz * (j + 1) - wt - 0.02)
   (stamp [112 84] 2 dots (rgb 0.92 0.92 0.92)
          (cards slates 30 5 (watch [sx hub 0] orb-r [75 95] 60 (feed camfeed (ad [x 1.45 z] [0 0 -1] [0 1 0] 5.0 2.7 nosignal)))))))
; ..a room of filing cabinets stood round a television as stones.l stands its stones round
; the altar: eight places a turn round, half a place short of +x, the fourth left empty, so
; none stands between the -z doorway and the set, each facing it; the set facing the doorway,
; its colour bars up
(: casing (texture 16 16 1.0 '((fill (grey 0.12)) (noise 1 0.04))))
(: bars (texture 70 48 13 (map (k \ ['rect (10 * k) 0 (10 * k + 10) 36 (['(grey 0.75) '(rgb 0.75 0.75 0) '(rgb 0 0.75 0.75) '(rgb 0 0.75 0)
                                                                      '(rgb 0.75 0 0.75) '(rgb 0.75 0 0) '(rgb 0 0 0.75)] k)]) ^7
                          + ['(rect 0 36 70 48 (grey 0.08))])))
(: filed (: c (spot files 3.1 3.285) x (c 0) z (c 2) r 2.2
   (one k) (: a ((k - 0.5) * pi / 4.0)
     (furnish 'cabinet [(x + r * cos a) 0 (z + r * sin a)] (90.0 - a * 180.0 / pi)
              {'h (1.1 + 0.4 * h01 k 7) 'drawers (3 + k % 3) 'seed (k + 1)}))
   (map one (filter (k \ k != 3) ^8)
    + [(furnish 'table [x 0 z] 180 {'w 0.7 'd 0.5 'h 0.55})
       (skin {'all casing} (solid (box [(x - 0.3) 0.55 (z - 0.22)] [(x + 0.3) 1.0 (z + 0.22)])))
       (ad [x 0.775 (z - 0.225)] [0 0 -1] [0 1 0] 0.48 0.33 bars)])))
; ..the wisps: one at the bottom of the maze's pool, one in the far closet, one on the
; grass just downhill of brazier IV, as if set there and rolled off, and one in the graveyard's empty plot
(: wisps (: b (hearth-at [4 0]) xm (cx * (zi + 0.5)) z1 (cz * (zj + 1) - wt)
   [(wisp [(spot-x flooded 3.1 0) -(pool-d) (spot-z flooded 0 4.0)]) (wisp [xm 0 (z1 - 0.7)])
    (wisp (on-ground (b 0 - 1.2) (b 2 + 0.7))) (wisp (on-ground (yx + 2.2) (yz + 2.6)))]))

(level "the ring"
  (surface 'torus lx lz)
  (textures {'wall paper 'floor carpet 'ceiling tiles 'door oak})
  ; ..in the closet, its door ahead
  (start [(cx * (ci + 0.5)) 0 (cz * (cj + 1) - wt - 0.6)] 180 0)
  (sky 13 'clear) (skylight (rgb 0.12 0.11 0.09))
  (ambient (rgb 0.78 0.72 0.5))
  (void [-4 -3 -4] [(lx + 4) (top + 14) (lz + 4)])
  (land grass (rows ground))
  (map (w \ along (w 0) (flow [0.6 0] (clear (drape water (w 1))))) waters)
  ; ..the graveyard and its plinth, the posts down the outside every sixteen metres, and round the tube every eight
  (plinth (yx - 3.0) yz)
  yard
  (map (x \ post x (lz / 2) stone) (filter (x \ rd x (lz / 2) > 4.5 && span (x - yx) > yh + 2.0) (map (i \ 40.0 + 16.0 * i) ^17)))
  (map (z \ post 80.0 z stone) (filter (z \ rd 80.0 z > 4.5) (map (i \ 4.0 + 8.0 * i) ^11)))
  ; ..under it the rooms, carved out of the ground, the ways between them, their lights and their buzz
  (map (i \ map (cell i) ^nz) mcols)
  hall
  (map (i \ catmap (ways i) ^nz) mcols)
  (catmap pillars mcells)
  (map (i \ map (panels i) ^nz) mcols)
  (closet ci cj)
  (closet zi zj)
  exits
  ; ..the loop down there heard down there alone, as the buzz is; but the hall's heard far, up
  ; through the well on the grass round it too
  (heard [0 0 0] [lx mh lz] pas)
  (reach 20 (heard [0 0 0] [lx gh lz] (stereo sx0 sz0)))
  (reach 20 (heard [(cx * <gis) 0 (cz * <gjs)] [(cx * (<gis + 3)) (top + 12.0) (cz * (<gjs + 3))] round-tree))
  cables
  (hum 'fluorescent [0 0 0] [lx mh lz])
  ; ..and the well up out of them, and the tree in its mound, climbed up the vines the loop grows on it
  (skin {'all concrete} (street [(tx - wh) (gh - 0.05) (tz - wh)] [(tx + wh) (top + 0.05) (tz + wh)]))
  (whole (mound tx tz 2.4 0.8 0.6))
  (vined (tree [tx 0 tz] 7 bark))
  ; ..a speaker on the plinth facing the gate, one on the grass at the side of the lift's pad facing it, both heard up here alone, and the ring's middle
  (heard [-1000 top -1000] [1000 1000 1000]
    [(cabinet [(yx - 3.21) (ground (yx - 3.0) yz + 0.78) yz] [1 0]) (cabinet [sx (ground sx (lz - 2.2)) (lz - 2.2)] [0 1])])
  hang
  ; ..the resonance, halfway from the orb's skin to the grass, its braziers, and the wisps by the lift
  (resonance [sx (hub - orb-r - 0.5 * (hub - top - orb-r)) 0] steps)
  (map hearth hearths)
  wisps
  ; ..the monitor in its room, and the rooms with something in them
  tv
  offices stores waits beds floods filed)
