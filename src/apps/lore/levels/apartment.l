; `love play src/apps/lore/levels/apartment.l`: a glass cube on an island in the middle of a
; river across a plain. through the glass the plain is grass and the river runs; out under
; the sky it is sand, and the river's bed is dry. far to the west a living room open
; to the plain, its back yard under glass, a burnt tree in it whose shadow falls through to
; the station
(borrow 'scenery)

; the textures: what is there, sand, and mud for the yard's banked sides
(: sand (feel 'sand (texture 64 64 3
         '((fill (rgb 0.8 0.68 0.48)) (noise 1 0.07) (fbm 16 4 0.12) (stain 16 3 0.42 0.35 (shade 0.9))
           (stain 8 3 0.38 0.35 (mix (rgb 0.88 0.78 0.6) 0.6)) (relief 1.5 2 0.08)))))
(: mud (texture 64 64 4.4
        '((fill (rgb 0.69 0.53 0.37)) (fbm 16 4 0.15) (stain 16 3 0.42 0.35 (shade 0.88)) (relief 1.5 2 0.1)
          (cracks 16 16 1.2 3 (rgb 0.53 0.37 0.12)))))
; ..what the glass shows: grass, and water drifting down the river
(: grass (feel 'grass (texture 64 64 2
          '((fill (rgb 0.3 0.52 0.2)) (noise 1 0.2) (fbm 8 4 0.22) (stain 16 3 0.45 0.35 (shade 0.82))
            (stain 8 3 0.4 0.35 (mix (rgb 0.5 0.66 0.26) 0.7))))))
(: water (texture 64 64 4
          '((fill (rgb 0.16 0.36 0.5)) (fbm 16 4 0.25) (stain 16 3 0.42 0.35 (mix (rgb 0.4 0.6 0.72) 0.6)) (noise 1 0.03))))
; ..the cubes' glass, faintly green and smeared
(: pane (texture 64 64 2 '((fill (rgb 0.6 0.74 0.7)) (fbm 32 3 0.08) (stain 32 3 0.3 0.5 (shade 1.06)))))
; ..the stone in the yard's corner
(: granite (feel 'hard (texture 32 32 0.4 '((fill (grey 0.58)) (noise 1 0.08) (fbm 8 3 0.12) (stain 8 3 0.4 0.3 (mix (rgb 0.5 0.56 0.36) 0.8)) (relief 1.5 2 0.1)))))
; ..the yard's: its iron, its fence's boards, and the tree's bark burnt black
(: iron (feel 'hard (texture 16 16 1 '((fill (grey 0.16)) (noise 1 0.05) (fbm 8 3 0.12)))))
(: palings (feel 'wood (texture 32 64 1.0 '((fill (rgb 0.6 0.45 0.3)) (noise 1 12 0.12) (fbm 16 3 0.14) (stain 16 3 0.42 0.35 (shade 0.86))))))
(: charred (feel 'wood (texture 32 64 0.5 '((fill (grey 0.08)) (noise 1 0.08) (noise 1 14 0.15) (fbm 8 3 0.15) (stripes 11 1 0 (shade 1.4))
            (cracks 8 24 1 5 (rgb 0.3 0.12 0.05))))))
; ..the house's: clapboard and a tarred roof outside, plaster, floorboards, a rug and a sofa's
; cloth within, its door's wooden frame and clear glass
(: siding (texture 32 32 0.3 '((fill (rgb 0.78 0.8 0.76)) (fbm 8 3 0.06) (stain 16 3 0.25 0.4 (shade 0.94)) (rows 0 2 (shade 0.72)))))
(: tar (feel 'hard (texture 32 32 1.0 '((fill (grey 0.24)) (noise 1 0.08) (fbm 8 3 0.12) (relief 1.5 2 0.08)))))
(: plaster (texture 32 32 1.5 '((fill (rgb 0.86 0.83 0.76)) (fbm 16 3 0.05) (stain 16 3 0.25 0.5 (shade 0.96)))))
(: boards (feel 'wood (texture 64 64 1.2 '((fill (rgb 0.5 0.34 0.2)) (noise 1 12 0.1) (fbm 16 3 0.1) (stripes 8 1 0 (shade 0.6))))))
(: rug (feel 'soft (texture 32 32 0.8 '((fill (rgb 0.55 0.2 0.18)) (checker 8 8 (shade 0.85)) (noise 1 0.05) (fbm 8 3 0.08)))))
(: cloth (feel 'soft (texture 32 32 0.5 '((fill (rgb 0.35 0.42 0.5)) (noise 1 0.08) (fbm 8 3 0.06)))))
(: walnut (material 'wood 6 {'colour (rgb 0.3 0.16 0.08) 'grain 0.05 'knots 0.0 'rings 9 'warp 1.5}))
(: lacquer (feel 'wood (texture 16 16 0.5 '((fill (grey 0.07)) (noise 2 0.06) (rows 0 1 (grey 0.12))))))
(: oak (feel 'wood (texture 32 64 1.0 '((fill (rgb 0.45 0.3 0.18)) (noise 1 10 0.1) (fbm 16 3 0.08)))))
(: clear (texture 64 64 2 '((fill (rgb 0.82 0.88 0.88)) (fbm 32 3 0.05))))
; ..the kitchen's: a sink's brushed steel and a hob's black
(: steel (feel 'hard (texture 16 16 0.5 '((fill (rgb 0.66 0.68 0.7)) (noise 1 0.03) (rows 0 1 (shade 0.96))))))
(: hob (feel 'hard (texture 16 16 0.5 '((fill (grey 0.05)) (noise 1 0.04)))))
; ..the tv's: the yard's picture, seen through a glass with nothing on it; dark grey static
; till the first frame
(: clean [(texture 192 112 7 '((fill hole)))])
(: static (texture 192 112 7 '((fill (rgb 0.16 0.18 0.2)) (noise 1 0.3))))

; ..and the paintings, each thrown anew every game from the templates, the tall one's bands of colour
(: wide-art (texture 96 64 1.0 '((art any 1))))
(: tall-art (texture 64 96 1.0 '((art fields 2))))

; the river: wandering across the plain along x, more the further from the cube. by the cube
; it parts in two channels sep x either side of its line, the island between
(: (meander x) ((2.0 + 3.0 * ease (abs x) 18.0 45.0) * (sin (x / 9.0 + 1.0) + 0.45 * sin (x / 4.3 + 2.0))))
(: bed-d 0.6)                            ; how deep the bed lies
(: bank-w 1.5)                           ; how far its banks run off the shore
(: reach 2.9)                            ; its shore off a channel's line
(: river-y -0.35)                        ; the water's face, seen only through glass
(: lift 0.04)                            ; how far the grass lies over the sand
(: sep-w 7.0)                            ; how far a channel runs off the line beside the cube
(: (sep x) (sep-w * (1.0 - ease (abs x) 4.0 16.0)))

; the cube, on the river's line in the middle of the island
(: home [0.0 (meander 0.0)])
(: spots [home])
; the house far west and its yard, the yard's glass's east side over the house's back, the
; floors' top, and how far a point is from them in plan
(: sx0 -133.6 sx1 -104.0 sz0 12.6 sz1 31.4 se -114.6 hy 0.06)
(: (off-site x z) (: a (max 0.0 (max (sx0 - x) (x - sx1))) b (max 0.0 (max (sz0 - z) (z - sz1))) (sqrt (2 a + 2 b))))
; ..and the land sunk well under the yard's floor and the house's, below the shadow's slots,
; and not at all past their walls
(: (sink x z) (: (in a0 a1 b0 b1) (min (min (x - a0) (a1 - x)) (min (z - b0) (b1 - z)))
   (0.5 * ease (max (in sx0 se sz0 sz1) (in -116.2 sx1 16.0 28.0)) 1.0 3.0)))

; the dunes: two long swells crossing and a short one on them, none near the river, on the
; island or under the cube
(: (dune x z) (3.2 * (0.5 + 0.5 * sin (x / 6.2 + z / 8.5 + 0.3)) * (0.5 + 0.5 * sin (z / 5.4 - x / 11.0 + 1.1))
               + 0.7 * (0.5 + 0.5 * sin (x / 3.3 - z / 4.1))))
(: (flat x z) (foldl (\ a p (a * ease (sqrt (2 (x - p 0) + 2 (z - p 1))) 5.6 10.0)) (ease (off-site x z) 3.0 14.0) spots))

; the land laid along the river: a column every two metres, closer at the island's round ends,
; its rows close at the water and over the island, wider out to the edge
(: ends [9.0 9.5 9.75 10.25 10.5 10.65 10.8 11.0])
(: xs (sort (map (i \ 2.0 * i - 150.0) ^108 + ends + map (x \ 0.0 - x) ends)))
(: out (map (i \ 0.75 * (i + 1)) ^16 + map (i \ 13.0 + i) ^9 + [23.0 26.0 30.0 34.0 40.0 46.0 52.0 58.0 64.0]))
; rows, each an offset off the line at x: the land's over the island, each channel's bed, the
; mud on the same points, then out to the edge, the channel's shift easing off by it
; the island's half-width, rounded at its ends by a nose nose-r across; where it closes, by
; bisection; and near either end its middle run straight on along x off the bending line,
; so the nose comes round square to the river
(: nose-r 2.5)
(: (isle-e x) (sep x - reach @ h (h > 0.0 ? (sqrt (h * (h + 2.0 * nose-r))) 0.0)))
(: (halve f a b n) ((a + b) / 2.0 @ c (n = 0 ? c (f c > 0.0 ? (halve f c b (n - 1)) (halve f a c (n - 1))))))
(: tip (halve (x \ sep x - reach) 4.0 16.0 30))
(: (slope x) ((meander (x + 0.05) - meander (x - 0.05)) / 0.1))
(: (isle-d x) (abs x >= tip ? 0.0 ((x < 0.0 ? (0.0 - tip) tip) @ t (0.0 - slope t * (x - t) * (1.0 - ease (abs (x - t)) 1.0 4.0)))))
; ..the island's rows v of its half-width off its middle, and a bed's on side g, u of the way
; from the island's edge out to the bank
(: (isle-at v x) (isle-d x + v * isle-e x))
(: (bed-at g u x) (isle-d x + g * isle-e x @ e (e + u * (g * (sep x + reach) - e))))
; ..the shore, one line for the dry bed and the water: the bed's first and last rows above.
; how far a point lies outside it, the bed negative; the land meets the water's face on it
(: (off-shore x z) (: d (z - meander x) m (d - isle-d x) out (abs d - (sep x + reach))
   (max out (abs x < tip ? (isle-e x - abs m) (0.0 - sqrt (2 (abs x - tip) + 2 m))))))
(: shore-y (river-y - lift))
(: (bed-y w) (w > 0.0 ? (shore-y * (1.0 - ease w 0.0 bank-w)) (shore-y - (bed-d + shore-y) * ease (0.0 - w) 0.0 1.0)))
(: (ground x z) (: d (z - meander x) (bed-y (off-shore x z) + dune x z * ease (abs d - sep x) 4.5 14.0 * flat x z - sink x z)))
; ..the sand a shade darker over the bed, easing back to the plain's across its banks
(: (shaded rs) (map (map (p \ p + [(1.0 - 0.25 * (1.0 - ease (off-shore (p 0) (p 2)) -0.5 (bank-w + 1.0)))])) rs))
(: (rows-by xs fs dy) (map (f \ map (x \ (: z (meander x + f x) [x (ground x z + dy) z])) xs) fs))
(: (rows-on xs ts dy) (rows-by xs (flats ts) dy))
(: (far-at o x) (o + sep x * (1.0 - ease o 8.0 40.0)))
(: (mirror fs) (rev (map (f \ x \ 0.0 - f x) fs)))
; the water's face, past the shore on both sides and under the island, the land cutting it
(: (level-on xs ts y) (map (t \ map (x \ [x y (meander x + t * (sep x + reach + 0.5))]) xs) ts))
(: hi-bed (map (i \ bed-at 1.0 (i / 8.0)) ^9) lo-bed (rev (map (i \ bed-at -1.0 (i / 8.0)) ^9))
   far (map far-at (filter (o \ o > 3.0) out)) isle (map isle-at [-0.75 -0.5 -0.25 0.0 0.25 0.5 0.75])
   lts (mirror far + lo-bed + isle + hi-bed + far))
; ..and past the walls out to the haze, for the eye alone: columns six metres apart, rows
; wider out, four strips round the land
(: xw (map (i \ -240.0 + 6.0 * i) ^15) xe (map (i \ 66.0 + 6.0 * i) ^15))
(: xa (xw + xs + xe) tn [64.0 72.0 82.0 95.0 110.0 128.0 150.0] tso (rev (map (t \ 0.0 - t) tn)))
(: (flats ts) (map (t \ x \ t) ts))
(: (around f) [(f xa (flats tso)) (f (xw + [-150.0]) lts) (f ([64.0] + xe) lts) (f xa (flats tn))])
(: sides [(xw + [-150.0]) ([64.0] + xe)])

; a cube with its middle at x z, all glass: four walls and a roof round a grass floor, the
; plain seen through the glass's inner face, and the walls nothing to a body
(: (cube x z) (: a 2.0 h 3.4 t 0.04
   (glass lo hi) (lens [x 1.5 z] (window lo hi pane))
   (wall lo hi) (mirage (glass lo hi))
   [(drape grass [[[(x - a) 0.02 (z - a)] [(x + a) 0.02 (z - a)]] [[(x - a) 0.02 (z + a)] [(x + a) 0.02 (z + a)]]])
    (wall [(x - a) 0 (z - a)] [(x + a) h (z - a + t)])
    (wall [(x - a) 0 (z + a - t)] [(x + a) h (z + a)])
    (wall [(x - a) 0 (z - a)] [(x - a + t) h (z + a)])
    (wall [(x + a - t) 0 (z - a)] [(x + a) h (z + a)])
    (glass [(x - a) (h - t) (z - a)] [(x + a) h (z + a)])
    (mattress [x 0.02 (z - 0.6)] 0)]))

; the yard: glass bays between iron posts round a grass floor and a glass roof, its east side
; over the house's back; a wooden fence round it inside the glass from the house's two sides,
; and a headstone in the corner far from the house, on the left coming out, facing the tree
(: yx0 sx0 yx1 -116.2 ye se yz0 sz0 yz1 sz1 yh 5.0)
(: yxs (map (i \ yx0 + 3.8 * i) ^6) yzs (map (i \ yz0 + 4.7 * i) ^5) yard-mid [-124.1 2.5 22.0])
(: (yard-pane lo hi) (lens yard-mid (window lo hi pane)))
; ..the east side's glass alone, cutting nothing: beside the house its sheet 5 mm in from the
; yard's edge, a centimetre on into the house's walls, its foot down into the yard's floor;
; over the house 1 cm past that edge, down into the house's top and on past the sides' glass.
; so it meets the house with no gap, and on no plane another face is
(: (yard-glass lo hi) (yard-pane lo hi @ q (q 1)))
(: (post x z) (skin {'all iron} (solid (box [(x - 0.07) 0 (z - 0.07)] [(x + 0.07) (yh + 0.1) (z + 0.07)]))))
(: (bays bs f) (map (i \ f (bs i) (bs (i + 1))) ^(#bs - 1)))
(: yard
   [(map (b \ skin {'floor grass 'walls mud} (solid (box (b 0) (b 1))))
         [[[yx0 -0.6 yz0] [yx1 hy yz1]] [[yx1 -0.6 yz0] [ye hy 16.0]] [[yx1 -0.6 28.0] [ye hy yz1]]])
    (map (b \ skin {'floor grass 'walls siding} (street (b 0) (b 1)))
         [[[yx0 hy yz0] [yx1 yh yz1]] [[yx1 hy yz0] [ye yh 16.0]] [[yx1 hy 28.0] [ye yh yz1]]])
    (bays yxs (\ a b (yard-pane [a hy yz0] [b yh (yz0 + 0.06)])))
    (bays yxs (\ a b (yard-pane [a hy (yz1 - 0.06)] [b yh yz1])))
    (bays yzs (\ a b (yard-pane [yx0 hy a] [(yx0 + 0.06) yh b])))
    (yard-glass [(ye - 0.035) (hy - 0.1) yz0] [(ye + 0.025) yh 16.01]) (yard-glass [(ye - 0.035) (hy - 0.1) 27.99] [(ye + 0.025) yh yz1])
    (yard-glass [(ye - 0.02) 3.19 15.98] [(ye + 0.04) yh 28.02])
    (yard-pane [yx0 (yh - 0.06) yz0] [(ye + 0.03) yh yz1])
    (map (x \ [(post x (yz0 - 0.07)) (post x (yz1 + 0.07))]) yxs)
    (map (z \ [(post (yx0 - 0.07) z) (post (ye + 0.07) z)]) [yz0 yz1])
    (headstone [-131.0 hy 15.2] 45 granite)
    (wooden (fence [[-115.2 -0.2 16.0] [-115.2 0.0 13.0] [-133.2 0.0 13.0] [-133.2 0.0 31.0] [-115.2 0.0 31.0] [-115.2 -0.2 28.0]] 1.3 palings))])

; the house: one room, open to the plain on the east, a sliding glass door in its back wall
; onto the yard; a bulb overhead. by the door a tv on a sideboard, a sofa and an easy chair
; turned to it, a table with a red plush mouse on it between them on a rug; a painting on the
; far wall, bookshelves along it further on, and a coat rack; across the room a dining table
; and its six chairs, a larger painting over them; in the corner by the back wall a kitchen,
; a fridge, a counter, a sink under a window onto the yard and a hob
; ..the kitchen along the back wall from the south corner, its user facing the wall: a fridge,
; a counter, the sink, a cabinet under a steel basin with a tap, under a window onto the yard,
; and a counter with a hob's four rings; the window's reveal plastered
(: kitchen (: y (hy + 0.72) t (hy + 0.9) (steel-box lo hi) (skin {'all steel} (solid (box lo hi)))
   [(furnish 'cabinet [-115.65 hy 16.6] 270 {'w 0.8 'd 0.7 'h 1.9 'doors 2 'drawers 0})
    (furnish 'counter [-115.7 hy 17.5] 270 {'w 1.0 'over 0.0 'doors 2})
    (furnish 'cabinet [-115.7 hy 18.5] 270 {'w 1.0 'h 0.72 'doors 2 'drawers 0 'skin {'body oak 'frame steel}})
    (steel-box [-116.0 y 18.0] [-115.9 t 19.0]) (steel-box [-115.5 y 18.0] [-115.4 t 19.0])
    (steel-box [-115.9 y 18.0] [-115.5 t 18.15]) (steel-box [-115.9 y 18.85] [-115.5 t 19.0])
    (steel-box [-115.9 y 18.15] [-115.5 (y + 0.02) 18.85])
    (steel-box [-115.97 t 18.48] [-115.93 (t + 0.3) 18.52]) (steel-box [-115.93 (t + 0.26) 18.48] [-115.74 (t + 0.3) 18.52])
    (furnish 'counter [-115.7 hy 19.6] 270 {'w 1.2 'over 0.0 'doors 2})
    (map (q \ skin {'all hob} (solid (box [(q 0 - 0.1) t (q 1 - 0.1)] [(q 0 + 0.1) (t + 0.01) (q 1 + 0.1)]))) [[-115.84 19.3] [-115.56 19.3] [-115.84 19.9] [-115.56 19.9]])
    (window [-116.22 (hy + 1.05) 17.9] [-115.98 (hy + 2.1) 19.1] clear @ (a p) [(skin {'all plaster} a) p])]))
(: house
   [(skin {'walls siding 'floor tar 'ceiling plaster} (solid (box [-116.2 -0.6 16.0] [-104.0 3.2 28.0])))
    (skin {'floor boards 'walls plaster 'ceiling plaster} (room [-116.0 hy 16.2] [-103.8 3.0 27.8]))
    (glazed clear (door [-116.1 hy 22.0] 1.8 2.2))
    (furnish 'rug [-112.8 hy 25.1] 0 {'w 4.4 'd 4.6 'skin {'soft rug}})
    (furnish 'sideboard [-115.76 hy 25.3] 270 {'skin {'body oak 'top oak 'frame oak}})
    (furnish 'tv [-115.7 (hy + 0.8) 25.3] 270 {})
    ; ..its screen, a tap turning it on: the yard seen from high in its far corner, on the tree;
    ; once the mouse is down the tree's shadow, the table it lay on
    (switched (missing [-114.7 1.5 25.3] 90 -36 (camera [-130.6 3.6 27.6] 144 -17 (feed clean (ad [-115.663 (hy + 1.21) 25.3] [1 0 0] [0 1 0] 1.05 0.61 static)))))
    (furnish 'sofa [-111.6 hy 25.3] 270 {'w 2.6 'skin {'soft cloth}})
    (furnish 'table [-113.2 hy 25.3] 90 {'w 1.6 'd 0.8 'h 0.42 'apron 0.05 'skin {'top oak 'frame oak}})
    (plush [-113.2 0.42 25.3] 270 'mouse)
    (furnish 'painting [-111.2 hy 27.78] 0 {'w 1.8 'h 1.2 'low 1.0 'skin {'picture wide-art 'frame (material 'wood 2 {'colour (rgb 0.12 0.1 0.09)})}})
    (furnish 'armchair [-113.2 hy 27.0] 236 {'skin {'soft (material 'cloth 3 {'colour (rgb 0.45 0.32 0.2)})}})
    (map (q \ furnish 'shelf [(q 0) hy 27.64] 0 {'h 2.0 'shelves 5 'fill 'books 'seed (q 1) 'skin {'frame oak}}) [[-108.0 17] [-107.05 18]])
    kitchen
    (furnish 'table [-110.0 hy 19.4] 0 {'w 1.8 'd 0.95 'skin {'top walnut 'frame walnut}})
    (map (q \ furnish 'chair [(q 0) hy (q 1)] (q 2) {'seed (q 3) 'skin {'frame lacquer 'soft lacquer}})
         [[-110.5 18.55 0 1] [-109.5 18.55 0 2] [-110.5 20.25 180 3] [-109.5 20.25 180 4] [-111.2 19.4 90 5] [-108.8 19.4 270 6]])
    (furnish 'painting [-110.0 hy 16.22] 180 {'w 1.6 'h 2.3 'low 0.55 'skin {'picture tall-art 'frame (material 'wood 4 {'colour (rgb 0.16 0.12 0.1)})}})
    (furnish 'coatrack [-115.5 hy 23.5] 0 {'fill 'coats 'skin {'soft (material 'cloth 5 {'colour (rgb 0.3 0.28 0.25)})}})
    (bulb [-110.0 2.8 22.0] (rgb 1.0 0.85 0.62))])

(level "the apartment"
  (textures {'wall sand 'floor sand 'ceiling sand 'door oak})
  (start [(home 0) 0 (home 1 - 1.2)] 280 -4) winded
  (sky 15.5 'partly) (skylight (rgb 0.12 0.11 0.09))
  (ambient (rgb 0.32 0.32 0.3))
  ; the plain, open to the sky, walled by nothing to see; the land on it, dunes and the river's
  ; dry bed in its two channels about the island, a shade darker
  (void [-146 -2 -60] [60 40 60])
  (land sand (shaded (rows-by xs lts 0.0)))
  ; ..heard out on it, the wind and now and then a bell; in the burnt tree's yard, a throb
  (hum 'wind [-146 -2 -60] [60 40 60]) (hum 'bells [-146 -2 -60] [60 40 60])
  (hum 'throb [yx0 -1 yz0] [ye yh yz1])
  ; ..and what the glass shows over it all: grass, and the river running
  (beyond (drape grass (rows-by xs lts lift)))
  (beyond (flow [0.7 0] (drape water (level-on xs [-1.0 -0.5 0.0 0.5 1.0] river-y))))
  ; the land going on past the walls, its river and what the glass shows of them
  (map (drape sand) (around (\ xs fs (shaded (rows-by xs fs 0.0)))))
  (map (beyond * drape grass) (around (\ xs fs (rows-by xs fs lift))))
  (map (q \ beyond (flow [0.7 0] (drape water (level-on q [-1.0 -0.5 0.0 0.5 1.0] river-y)))) sides)
  ; the cube woken in
  (cube (home 0) (home 1))
  ; the house and its yard, the tree in it short and stout and sheared through, its shadow a
  ; hole the player falls down, to wake at the station
  house yard
  (shadow-hole (sheared [-126.5 2.86 21.5] [-123.5 1.81 21.5] [-126.5 3.31 24.5] (sized 0.333 1.4 (tree [-126.5 hy 21.5] 7 charred))))
  (fall -40 "earth.l" ()))
