; `love play src/apps/lore/levels/apartment.l`: eight glass cubes in a ring on a plain, a
; river across the middle. through the glass the plain is grass and the river runs; out
; under the sky it is sand, and the river's bed is dry
(borrow 'scenery)

; the textures: what is there, sand and the bed's mud, cracked as it dried
(: sand (feel 'soft (texture 64 64 3
         '((fill (rgb 0.8 0.68 0.48)) (noise 1 0.12) (noise 9 0.08) (patches 6 0.25 (shade 0.9))
           (patches 4 0.12 (rgb 0.88 0.78 0.6))))))
(: mud (texture 64 64 4.4
        '((fill (rgb 0.69 0.53 0.37)) (noise 2 0.08) (patches 6 0.2 (shade 0.92))
          (cracks 16 16 1.2 3 (rgb 0.53 0.37 0.12)))))
(: stone (feel 'hard (texture 32 32 1.2 '((fill (grey 0.5)) (noise 2 0.15) (patches 4 0.2 (shade 0.8))))))
; ..what the glass shows: grass, and water drifting down the river
(: grass (feel 'soft (texture 64 64 2
          '((fill (rgb 0.3 0.52 0.2)) (noise 1 0.25) (noise 8 0.12) (patches 6 0.25 (shade 0.82))
            (patches 5 0.12 (rgb 0.5 0.66 0.26))))))
(: water (texture 64 64 4
          '((fill (rgb 0.16 0.36 0.5)) (noise 24 4 0.18) (patches 8 0.15 (rgb 0.4 0.6 0.72)) (noise 1 0.06))))
; ..the cubes' glass, faintly green and smeared
(: pane (texture 64 64 2 '((fill (rgb 0.6 0.74 0.7)) (noise 24 8 0.12) (patches 10 0.2 (shade 1.08)))))

; the river: wandering across the plain along x, more the further from the cubes; its bed
; sunk bed-d, bed-w either side flat and its banks bank-w more, rising easy
(: (ease v a b) (: k (min 1.0 (max 0.0 ((v - a) / (b - a)))) (k * k * (3.0 - 2.0 * k))))
(: (meander x) ((2.0 + 3.0 * ease (abs x) 18.0 45.0) * (sin (x / 9.0 + 1.0) + 0.45 * sin (x / 4.3 + 2.0))))
(: bed-d 0.6)                            ; how deep the bed lies
(: bed-w 1.5)                            ; half its floor's width
(: bank-w 2.5)                           ; how far its banks run
(: (bed-y t) (: a (abs t) (0.0 - bed-d * (1.0 - ease a bed-w (bed-w + bank-w)))))
(: river-y -0.35)                        ; the water's face, seen only through glass
(: lift 0.04)                            ; how far the grass lies over the sand

; the cubes in a ring, each as far from the river as the ring would put it
(: cube-r 18.5)
(: (spot k) (: a ((22.5 + 45 * k) * 3.14159265 / 180) x (cube-r * cos a) [x (cube-r * sin a + meander x)]))
(: spots (map spot ^8))
(: home (spot 2))

; the dunes: two long swells crossing and a short one on them, none near the river or under
; a cube
(: (dune x z) (3.2 * (0.5 + 0.5 * sin (x / 6.2 + z / 8.5 + 0.3)) * (0.5 + 0.5 * sin (z / 5.4 - x / 11.0 + 1.1))
               + 0.7 * (0.5 + 0.5 * sin (x / 3.3 - z / 4.1))))
(: (flat x z) (foldl (\ a p (a * ease (sqrt ((x - p 0) * (x - p 0) + (z - p 1) * (z - p 1))) 5.6 10.0)) 1.0 spots))
(: (ground x z) (: t (z - meander x) (bed-y t + dune x z * ease (abs t) 4.5 14.0 * flat x z)))

; the land laid along the river: a column every two metres, its rows close at the water and
; through the ring, wider out to the edge
(: xs (map (i \ 2.0 * i - 64.0) ^65))
(: out ([0.75 1.5 2.2 2.9 3.6 4.3] + map (i \ 5.0 + i) ^17 + [23.0 26.0 30.0 34.0 40.0 46.0 52.0 58.0 64.0]))
(: ts (rev (map (t \ 0.0 - t) out) + [0.0] + out))
(: (rows-on xs ts dy) (map (t \ map (x \ (: z (meander x + t) [x (ground x z + dy) z])) xs) ts))
(: (rows ts dy) (rows-on xs ts dy))
(: (level-on xs ts y) (map (t \ map (x \ [x y (meander x + t)]) xs) ts))
(: bedts [-2.9 -2.2 -1.5 -0.75 0.0 0.75 1.5 2.2 2.9])
; ..and past the walls out to the haze, for the eye alone: columns six metres apart, rows
; wider out, four strips round the land
(: xw (map (i \ -150.0 + 6.0 * i) ^15) xe (rev (map (x \ 0.0 - x) xw)))
(: xa (xw + xs + xe) tn [64.0 72.0 82.0 95.0 110.0 128.0 150.0] tso (rev (map (t \ 0.0 - t) tn)))
(: (around f) [(f xa tso) (f (xw + [-64.0]) ts) (f ([64.0] + xe) ts) (f xa tn)])
(: sides [(xw + [-64.0]) ([64.0] + xe)])

; a cube with its middle at x z, all glass: four walls and a roof round a grass floor, sealed,
; the plain seen through the glass's inner face; in the one woken in the pane toward the river
; breaks to a tap
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

(level "the apartment"
  (textures {'wall sand 'floor sand 'ceiling sand})
  (start [(home 0) 0 (home 1 - 1.2)] 110 -4)
  (sky 15.5 'clear) (skylight (rgb 0.12 0.11 0.09))
  (ambient (rgb 0.32 0.32 0.3))
  ; the plain, open to the sky, walled by nothing to see; the land on it, dunes and the river's
  ; dry bed, its mud cracked, a stone left in it
  (void [-60 -2 -60] [60 40 60])
  (land sand (rows ts 0.0))
  (drape mud (rows bedts 0.02))
  (: z (meander 4.0) (skin {'all stone} (cut [3 -0.2 (z + 0.4)] [5 -0.3 (z - 0.6)] [4 -0.15 (z + 0.8)] (solid (box [3 -0.7 (z - 0.8)] [5.2 -0.2 (z + 0.7)])))))
  ; ..and what the glass shows over it all: grass, and the river running
  (beyond (drape grass (rows ts lift)))
  (beyond (flow [0.7 0] (drape water (level-on xs [-2.7 -1.3 0.0 1.3 2.7] river-y))))
  ; the land going on past the walls, its river and what the glass shows of them
  (map (r \ drape sand r) (around (\ xs ts (rows-on xs ts 0.0))))
  (map (q \ drape mud (rows-on q bedts 0.02)) sides)
  (map (r \ beyond (drape grass r)) (around (\ xs ts (rows-on xs ts lift))))
  (map (q \ beyond (flow [0.7 0] (drape water (level-on q [-2.7 -1.3 0.0 1.3 2.7] river-y)))) sides)
  ; the cubes, and the one woken in
  (map (k \ cube (spots k 0) (spots k 1) (k = 2)) ^8))
