; `love play src/apps/lore/levels/apartment.l`: a glass cube on an island in the middle of a
; river across a plain. through the glass the plain is grass and the river runs; out under
; the sky it is sand, and the river's bed is dry. far to the west a living room open
; to the plain, its back yard under glass, a burnt tree in it whose shadow falls through to
; the station
(borrow 'scenery)

; the textures: what is there, sand and the bed's mud, cracked as it dried
(: sand (feel 'soft (texture 64 64 3
         '((fill (rgb 0.8 0.68 0.48)) (noise 1 0.12) (noise 9 0.08) (patches 6 0.25 (shade 0.9))
           (patches 4 0.12 (rgb 0.88 0.78 0.6))))))
(: mud (texture 64 64 4.4
        '((fill (rgb 0.69 0.53 0.37)) (noise 2 0.08) (patches 6 0.2 (shade 0.92))
          (cracks 16 16 1.2 3 (rgb 0.53 0.37 0.12)))))
; ..what the glass shows: grass, and water drifting down the river
(: grass (feel 'soft (texture 64 64 2
          '((fill (rgb 0.3 0.52 0.2)) (noise 1 0.25) (noise 8 0.12) (patches 6 0.25 (shade 0.82))
            (patches 5 0.12 (rgb 0.5 0.66 0.26))))))
(: water (texture 64 64 4
          '((fill (rgb 0.16 0.36 0.5)) (noise 24 4 0.18) (patches 8 0.15 (rgb 0.4 0.6 0.72)) (noise 1 0.06))))
; ..the cubes' glass, faintly green and smeared
(: pane (texture 64 64 2 '((fill (rgb 0.6 0.74 0.7)) (noise 24 8 0.12) (patches 10 0.2 (shade 1.08)))))
; ..the yard's: its iron, its fence's boards, and the tree's bark burnt black
(: iron (feel 'hard (texture 16 16 1 '((fill (grey 0.16)) (noise 2 0.1)))))
(: palings (feel 'wood (texture 32 64 1.0 '((fill (rgb 0.6 0.45 0.3)) (noise 1 12 0.2) (patches 4 0.2 (shade 0.85))))))
(: charred (feel 'wood (texture 32 64 0.5 '((fill (grey 0.08)) (noise 1 0.1) (noise 2 14 0.2) (stripes 11 1 0 (shade 1.4))
            (cracks 8 24 1 5 (rgb 0.3 0.12 0.05))))))
; ..the house's: clapboard and a tarred roof outside, plaster, floorboards, a rug and a sofa's
; cloth within, its door's wooden frame and clear glass
(: siding (texture 32 32 0.3 '((fill (rgb 0.78 0.8 0.76)) (noise 2 0.06) (rows 0 2 (shade 0.72)))))
(: tar (feel 'hard (texture 32 32 1.0 '((fill (grey 0.24)) (noise 1 0.15)))))
(: plaster (texture 32 32 1.5 '((fill (rgb 0.86 0.83 0.76)) (noise 4 0.05))))
(: boards (feel 'wood (texture 64 64 1.2 '((fill (rgb 0.5 0.34 0.2)) (noise 1 12 0.15) (stripes 8 1 0 (shade 0.6))))))
(: rug (feel 'soft (texture 32 32 0.8 '((fill (rgb 0.55 0.2 0.18)) (checker 8 8 (shade 0.85)) (noise 2 0.08)))))
(: cloth (feel 'soft (texture 32 32 0.5 '((fill (rgb 0.35 0.42 0.5)) (noise 1 0.12)))))
(: oak (feel 'wood (texture 32 64 1.0 '((fill (rgb 0.45 0.3 0.18)) (noise 1 10 0.15)))))
(: clear (texture 64 64 2 '((fill (rgb 0.82 0.88 0.88)) (noise 24 8 0.06))))

; the river: wandering across the plain along x, more the further from the cube; its bed
; sunk bed-d, bed-w either side flat and its banks bank-w more, rising easy. by the cube it
; parts in two channels sep x either side of its line, the island between
(: (ease v a b) (: k (min 1.0 (max 0.0 ((v - a) / (b - a)))) (2 k * (3.0 - 2.0 * k))))
(: (meander x) ((2.0 + 3.0 * ease (abs x) 18.0 45.0) * (sin (x / 9.0 + 1.0) + 0.45 * sin (x / 4.3 + 2.0))))
(: bed-d 0.6)                            ; how deep the bed lies
(: bed-w 1.5)                            ; half its floor's width
(: bank-w 2.5)                           ; how far its banks run
(: (bed-y t) (: a (abs t) -(bed-d * (1.0 - ease a bed-w (bed-w + bank-w)))))
(: river-y -0.35)                        ; the water's face, seen only through glass
(: lift 0.04)                            ; how far the grass lies over the sand
(: sep-w 7.0)                            ; how far a channel runs off the line beside the cube
(: (sep x) (sep-w * (1.0 - ease (abs x) 4.0 16.0)))
(: (chan x z) (: d (z - meander x) s (sep x) (min (abs (d - s)) (abs (d + s)))))   ; to the nearer channel

; the cube, on the river's line in the middle of the island
(: home [0.0 (meander 0.0)])
(: spots [home])
; the house far west and its yard, the floors' top, and how far a point is from them in plan
(: sx0 -132.2 sx1 -104.0 sz0 14.0 sz1 30.0 hy 0.06)
(: (off-site x z) (: a (max 0.0 (max (sx0 - x) (x - sx1))) b (max 0.0 (max (sz0 - z) (z - sz1))) (sqrt (2 a + 2 b))))
; ..and the land sunk well under their floors inside, below the shadow's slots
(: (sink x z) (0.5 * ease (min (min (x - sx0) (sx1 - x)) (min (z - sz0) (sz1 - z))) 1.0 3.0))

; the dunes: two long swells crossing and a short one on them, none near the river, on the
; island or under the cube
(: (dune x z) (3.2 * (0.5 + 0.5 * sin (x / 6.2 + z / 8.5 + 0.3)) * (0.5 + 0.5 * sin (z / 5.4 - x / 11.0 + 1.1))
               + 0.7 * (0.5 + 0.5 * sin (x / 3.3 - z / 4.1))))
(: (flat x z) (foldl (\ a p (a * ease (sqrt (2 (x - p 0) + 2 (z - p 1))) 5.6 10.0)) (ease (off-site x z) 3.0 14.0) spots))
(: (ground x z) (: d (z - meander x) (bed-y (chan x z) + dune x z * ease (abs d - sep x) 4.5 14.0 * flat x z - sink x z)))

; the land laid along the river: a column every two metres, its rows close at the water and
; over the island, wider out to the edge
(: xs (map (i \ 2.0 * i - 150.0) ^108))
(: out (map (i \ 0.75 * (i + 1)) ^16 + map (i \ 13.0 + i) ^9 + [23.0 26.0 30.0 34.0 40.0 46.0 52.0 58.0 64.0]))
(: ts (rev (map (t \ 0.0 - t) out) + [0.0] + out))
; rows along the line k channels over: -1 and 1 the two by the island, 0 the line itself
(: (rows-at k xs ts dy) (map (t \ map (x \ (: z (meander x + k * sep x + t) [x (ground x z + dy) z])) xs) ts))
(: (rows-on xs ts dy) (rows-at 0 xs ts dy))
(: (rows ts dy) (rows-on xs ts dy))
; the water's face, widened over both channels and the island between
(: (level-on xs ts y) (map (t \ map (x \ [x y (meander x + t * (1.0 + sep x / 2.7))]) xs) ts))
(: bedts [-2.9 -2.2 -1.5 -0.75 0.0 0.75 1.5 2.2 2.9])
; ..and past the walls out to the haze, for the eye alone: columns six metres apart, rows
; wider out, four strips round the land
(: xw (map (i \ -240.0 + 6.0 * i) ^15) xe (map (i \ 66.0 + 6.0 * i) ^15))
(: xa (xw + xs + xe) tn [64.0 72.0 82.0 95.0 110.0 128.0 150.0] tso (rev (map (t \ 0.0 - t) tn)))
(: (around f) [(f xa tso) (f (xw + [-150.0]) ts) (f ([64.0] + xe) ts) (f xa tn)])
(: sides [(xw + [-150.0]) ([64.0] + xe)])

; a cube with its middle at x z, all glass: four walls and a roof round a grass floor, sealed,
; the plain seen through the glass's inner face; in the one woken in one pane breaks to a tap
(: (cube x z home) (: a 2.0 h 3.4 t 0.04 up (z > meander x)
   (glass w) (lens [x 1.5 z] w)
   (wall lo hi river) (: w (glass (window lo hi pane)) (home && river ? (brittle w) w))
   [(drape grass [[[(x - a) 0.02 (z - a)] [(x + a) 0.02 (z - a)]] [[(x - a) 0.02 (z + a)] [(x + a) 0.02 (z + a)]]])
    (wall [(x - a) 0 (z - a)] [(x + a) h (z - a + t)] up)
    (wall [(x - a) 0 (z + a - t)] [(x + a) h (z + a)] !up)
    (wall [(x - a) 0 (z - a)] [(x - a + t) h (z + a)] 0)
    (wall [(x + a - t) 0 (z - a)] [(x + a) h (z + a)] 0)
    (wall [(x - a) (h - t) (z - a)] [(x + a) h (z + a)] 0)
    (mattress [x 0.02 (z - 0.6)] 0)]))

; the yard: glass bays between iron posts round a grass floor and a glass roof, the house
; against its east side; a wooden fence round it from the glass either side of the house
(: yx0 sx0 yx1 -116.2 yz0 sz0 yz1 sz1 yh 5.0)
(: yxs (map (i \ yx0 + 4.0 * i) ^5) yzs (map (i \ yz0 + 4.0 * i) ^5) yard-mid [-124.2 2.5 22.0])
(: (yard-pane lo hi) (lens yard-mid (window lo hi pane)))
(: (post x z) (skin {'all iron} (solid (box [(x - 0.07) 0 (z - 0.07)] [(x + 0.07) (yh + 0.1) (z + 0.07)]))))
(: (bays bs f) (map (i \ f (bs i) (bs (i + 1))) ^(#bs - 1)))
(: yard
   [(skin {'floor grass 'walls mud} (solid (box [yx0 -0.6 yz0] [yx1 hy yz1])))
    (skin {'floor grass 'walls siding} (street [yx0 hy yz0] [yx1 yh yz1]))
    (bays yxs (\ a b (yard-pane [a hy yz0] [b yh (yz0 + 0.06)])))
    (bays yxs (\ a b (yard-pane [a hy (yz1 - 0.06)] [b yh yz1])))
    (bays yzs (\ a b (yard-pane [yx0 hy a] [(yx0 + 0.06) yh b])))
    (yard-pane [(yx1 - 0.06) hy yz0] [yx1 yh 16.0]) (yard-pane [(yx1 - 0.06) hy 28.0] [yx1 yh yz1])
    (yard-pane [(yx1 - 0.06) 3.2 16.0] [yx1 yh 28.0])
    (yard-pane [yx0 (yh - 0.06) yz0] [yx1 yh yz1])
    (map (x \ [(post x (yz0 - 0.07)) (post x (yz1 + 0.07))]) yxs)
    (map (z \ [(post (yx0 - 0.07) z) (post (yx1 + 0.07) z)]) [yz0 yz1])
    (wooden (fence [[-116.4 hy 15.0] [-131.2 hy 15.0] [-131.2 hy 29.0] [-116.4 hy 29.0]] 1.3 palings))])

; the house: one room, open to the plain on the east, a sliding glass door in its back wall
; onto the yard; a sofa, a table, shelves and a rug, a bulb overhead
(: (piece t lo hi) (skin {'all t} (solid (box lo hi))))
(: house
   [(skin {'walls siding 'floor tar 'ceiling plaster} (solid (box [-116.2 -0.6 16.0] [-104.0 3.2 28.0])))
    (skin {'floor boards 'walls plaster 'ceiling plaster} (room [-116.0 hy 16.2] [-103.8 3.0 27.8]))
    (glazed clear (door [-116.1 hy 22.0] 1.8 2.2))
    (drape rug [[[-114.0 0.07 20.0] [-108.0 0.07 20.0]] [[-114.0 0.07 26.4] [-108.0 0.07 26.4]]])
    (piece cloth [-113.0 hy 26.9] [-109.4 0.48 27.75]) (piece cloth [-113.0 hy 27.52] [-109.4 0.95 27.8])
    (piece cloth [-113.25 hy 26.9] [-113.0 0.68 27.8]) (piece cloth [-109.4 hy 26.9] [-109.15 0.68 27.8])
    (piece oak [-112.0 hy 24.6] [-110.4 0.42 25.6])
    (piece oak [-113.5 hy 16.2] [-110.5 2.0 16.6])
    (bulb [-110.0 2.8 22.0] (rgb 1.0 0.85 0.62))])

(level "the apartment"
  (textures {'wall sand 'floor sand 'ceiling sand 'door oak})
  (start [(home 0) 0 (home 1 - 1.2)] 110 -4)
  (sky 15.5 'clear) (skylight (rgb 0.12 0.11 0.09))
  (ambient (rgb 0.32 0.32 0.3))
  ; the plain, open to the sky, walled by nothing to see; the land on it, dunes and the river's
  ; dry bed in its two channels about the island, its mud cracked
  (void [-146 -2 -60] [60 40 60])
  (land sand (rows ts 0.0))
  (map (k \ drape mud (rows-at k xs bedts 0.02)) [-1 1])
  ; ..heard out on it, the wind and now and then a bell; by the burnt tree, a throb
  (hum 'wind [-146 -2 -60] [60 40 60]) (hum 'bells [-146 -2 -60] [60 40 60])
  (hum 'throb [-129.5 -1 18.5] [-123.5 5 24.5])
  ; ..and what the glass shows over it all: grass, and the river running
  (beyond (drape grass (rows ts lift)))
  (beyond (flow [0.7 0] (drape water (level-on xs [-2.7 -1.3 0.0 1.3 2.7] river-y))))
  ; the land going on past the walls, its river and what the glass shows of them
  (map (drape sand) (around (\ xs ts (rows-on xs ts 0.0))))
  (map (q \ drape mud (rows-on q bedts 0.02)) sides)
  (map (beyond * drape grass) (around (\ xs ts (rows-on xs ts lift))))
  (map (q \ beyond (flow [0.7 0] (drape water (level-on q [-2.7 -1.3 0.0 1.3 2.7] river-y)))) sides)
  ; the cube woken in
  (cube (home 0) (home 1) 1)
  ; the house and its yard, the tree in it short and stout and sheared through, its shadow a
  ; hole the player falls down, to wake at the station
  house yard
  (shadow-hole (sheared [-126.5 2.86 21.5] [-123.5 1.81 21.5] [-126.5 3.31 24.5] (sized 0.333 1.4 (tree [-126.5 hy 21.5] 7 charred))))
  (fall -40 "station.l" ()))
