; `love play src/apps/lore/levels/tower.l`: an office tower that comes apart as it rises, its
; top floors drifting off into slabs and furniture hung in the air, a way up across them to
; the pink orb over it all; the higher, the lighter the pull
(borrow 'scenery)

; the textures
(: paving (texture 64 64 2
           '((fill (rgb 0.27 0.27 0.28)) (checker 32 32 (rgb 0.24 0.24 0.25)) (noise 7 0.08)
             (patches 6 0.15 (shade 0.9)) (grid 32 32 1 (rgb 0.36 0.36 0.37)))))
; ..the buildings round the plaza: concrete storeys four metres, a band of dark glass along each
(: facade (texture 64 64 4
           '((fill (rgb 0.27 0.27 0.29)) (noise 9 0.1) (patches 6 0.3 (shade 0.7))
             (within 0 18 64 44
               (fill (rgb 0.05 0.07 0.1)) (noise 5 0.1) (patches 8 0.22 (rgb 0.95 0.72 0.38))
               (patches 5 0.08 (rgb 0.35 0.85 0.95))
               (cols 0 4 (rgb 0.27 0.27 0.29)) (cols 30 34 (rgb 0.27 0.27 0.29)) (cols 62 64 (rgb 0.27 0.27 0.29)))
             (rows 44 47 (rgb 0.17 0.17 0.18)))))
(: gravel (texture 32 32 2 '((fill (grey 0.4)) (noise 1 0.35) (noise 6 0.1) (patches 4 0.2 (shade 0.85)))))
; ..the tower: pale panels outside, poured concrete where it is broken
(: cladding (texture 64 64 4 '((fill (rgb 0.66 0.67 0.69)) (noise 6 0.06) (rows 0 2 (shade 0.8)) (cols 0 2 (shade 0.85)) (cols 32 33 (shade 0.9)))))
(: concrete (texture 128 128 6
             '((fill (rgb 0.42 0.41 0.4)) (noise 6 0.05) (patches 6 0.18 (shade 0.88))
               (rows 0 1 (shade 0.88)) (rows 64 65 (shade 0.88)) (dots 42.667 16 0.8 (shade 0.6)))))
(: glass (texture 64 64 2 '((fill (rgb 0.6 0.74 0.7)) (noise 24 8 0.12) (patches 10 0.2 (shade 1.08)))))
; ..the offices: blue-grey carpet, off-white walls, ceiling tiles in a grid
(: carpet (feel 'soft (texture 64 64 2 '((fill (rgb 0.3 0.33 0.39)) (noise 1 0.25) (noise 8 0.1) (patches 5 0.2 (shade 0.9))))))
(: paint (texture 32 32 3 '((fill (rgb 0.8 0.78 0.73)) (noise 6 0.05) (rows 30 32 (shade 0.75)))))
(: ceiltile (texture 32 32 1.2 '((fill (grey 0.84)) (noise 2 0.08) (dots 4 4 0.5 (shade 0.82)) (grid 32 32 1 (grey 0.6)))))
; ..and what is in them: wood desks and doors, grey steel, black screens, dark cloth
(: wood (feel 'wood (texture 32 32 1.6 '((fill (rgb 0.56 0.39 0.23)) (noise 2 12 0.2) (rows 0 1 (shade 0.85))))))
(: steel (feel 'metal (texture 16 16 1 '((fill (rgb 0.46 0.48 0.51)) (noise 3 0.12)))))
(: drawers (feel 'metal (texture 32 64 1.3 '((fill (rgb 0.46 0.48 0.51)) (noise 3 0.12) (rows 0 1 (shade 0.6)) (rows 16 17 (shade 0.6))
                                (rows 32 33 (shade 0.6)) (rows 48 49 (shade 0.6)) (rect 12 7 20 9 (grey 0.2)) (rect 12 23 20 25 (grey 0.2))
                                (rect 12 39 20 41 (grey 0.2)) (rect 12 55 20 57 (grey 0.2))))))
(: screen (texture 16 16 0.5 '((fill (rgb 0.04 0.04 0.05)) (noise 4 0.2))))
(: cloth (feel 'soft (texture 16 16 0.5 '((fill (rgb 0.16 0.17 0.22)) (noise 1 0.3)))))
; ..the orb, a mottled pink, banded so its turning shows
(: pinkorb (texture 128 64 8 '((fill (rgb 0.96 0.46 0.7)) (patches 8 0.35 (shade 0.8)) (patches 4 0.2 (rgb 1 0.78 0.9))
                               (noise 6 0.08) (rows 30 34 (shade 0.86)))))
; ..inside, darker, and at its middle a smiling face that makes for whoever comes in
(: pinkin (texture 128 64 8 '((fill (rgb 0.72 0.24 0.5)) (patches 8 0.35 (shade 0.75)) (patches 5 0.25 (rgb 0.9 0.42 0.68))
                              (noise 6 0.1) (grid 16 16 1 (shade 0.7)))))
(: smiley (texture 64 64 1 '((fill hole) (disc 32 32 30 (rgb 1 0.86 0.2)) (disc 32 36 20 (rgb 0.2 0.12 0.08)) (disc 32 31 20 (rgb 1 0.86 0.2))
                             (disc 22 24 5 (rgb 0.2 0.12 0.08)) (disc 42 24 5 (rgb 0.2 0.12 0.08)))))

; the pieces, each standing with its top at y: a floor slab w by d, and the furniture
(: (slab x y z w d) (skin {'floor carpet 'walls concrete 'ceiling concrete}
                      (solid (box [(x - 0.5 * w) (y - 0.3) (z - 0.5 * d)] [(x + 0.5 * w) y (z + 0.5 * d)]))))
(: (desk x y z) [(skin {'all wood} (solid (box [(x - 0.8) (y - 0.04) (z - 0.4)] [(x + 0.8) y (z + 0.4)])))
                 (skin {'all wood} (solid (box [(x - 0.78) (y - 0.75) (z - 0.38)] [(x - 0.74) (y - 0.04) (z + 0.38)])))
                 (skin {'all wood} (solid (box [(x + 0.74) (y - 0.75) (z - 0.38)] [(x + 0.78) (y - 0.04) (z + 0.38)])))
                 (skin {'all wood} (solid (box [(x - 0.74) (y - 0.6) (z + 0.3)] [(x + 0.74) (y - 0.1) (z + 0.33)])))])
(: (cabinet x y z) (skin {'walls drawers 'floor steel 'ceiling steel} (solid (box [(x - 0.25) (y - 1.3) (z - 0.3)] [(x + 0.25) y (z + 0.3)]))))
(: (door x y z) (skin {'all wood} (solid (box [(x - 0.45) (y - 0.05) (z - 1.0)] [(x + 0.45) y (z + 1.0)]))))
(: (copier x y z) [(skin {'all steel} (solid (box [(x - 0.5) (y - 1.0) (z - 0.35)] [(x + 0.5) (y - 0.06) (z + 0.35)])))
                   (skin {'all screen} (solid (box [(x - 0.45) (y - 0.06) (z - 0.3)] [(x + 0.45) y (z + 0.3)])))])
(: (chair x y z) (: f (y - 0.45)
   [(skin {'all cloth} (solid (box [(x - 0.25) (y - 0.08) (z - 0.25)] [(x + 0.25) y (z + 0.25)])))
    (skin {'all cloth} (solid (box [(x - 0.25) y (z + 0.2)] [(x + 0.25) (y + 0.5) (z + 0.26)])))
    (skin {'all steel} (solid (box [(x - 0.03) (f + 0.09) (z - 0.03)] [(x + 0.03) (y - 0.08) (z + 0.03)])))
    ; ..on a cross of spokes, a caster under each end
    (skin {'all steel} (solid (box [(x - 0.28) (f + 0.06) (z - 0.02)] [(x + 0.28) (f + 0.09) (z + 0.02)])))
    (skin {'all steel} (solid (box [(x - 0.02) (f + 0.06) (z - 0.28)] [(x + 0.02) (f + 0.09) (z + 0.28)])))
    (map (c \ skin {'all screen} (solid (box [(x + c 0 - 0.025) f (z + c 1 - 0.025)] [(x + c 0 + 0.025) (f + 0.06) (z + c 1 + 0.025)])))
         [[0.26 0] [-0.26 0] [0 0.26] [0 -0.26]])]))
(: (tile x y z) (skin {'all ceiltile} (solid (box [(x - 0.3) (y - 0.02) (z - 0.3)] [(x + 0.3) y (z + 0.3)]))))
(: (monitor x y z) [(skin {'all screen} (solid (box [(x - 0.26) y (z - 0.03)] [(x + 0.26) (y + 0.34) (z + 0.03)])))
                    (skin {'all steel} (solid (box [(x - 0.1) (y - 0.02) (z - 0.1)] [(x + 0.1) y (z + 0.1)])))])
; ..a piece by its name, turned deg about its middle
(: (piece p) (: k (p 0) x (p 1) y (p 2) z (p 3)
   (turn (p 4) [x z] [(k @ 'slab (slab x y z 3.2 3.2) 'desk (desk x y z) 'cabinet (cabinet x y z) 'door (door x y z)
                          'copier (copier x y z) 'chair (chair x y z) 'tile (tile x y z) (monitor x y z))])))

; the tower's floors, four metres each, the offices between [-9.7 -9.7] and [9.7 9.7], the
; ground floor's south window parted for the door
(: (storey k) (: y (4 * k)
   [(skin {'floor carpet 'walls paint 'ceiling ceiltile} (room [-9.7 y -9.7] [9.7 (y + 3.7) 9.7]))
    (k = 0 ? [(window [-8 0.9 -10] [-2 2.9 -9.7] glass) (window [2 0.9 -10] [8 2.9 -9.7] glass)]
             (window [-8 (y + 0.9) -10] [8 (y + 2.9) -9.7] glass))
    (window [-8 (y + 0.9) 9.7] [8 (y + 2.9) 10] glass)
    (window [-10 (y + 0.9) -8] [-9.7 (y + 2.9) 8] glass) (window [9.7 (y + 0.9) -8] [10 (y + 2.9) 8] glass)
    (strip-light [-4 (y + 3.7) 0]) (strip-light [3 (y + 3.7) -5])
    (desk -6 (y + 0.75) 7.5) (chair -6 (y + 0.45) 6.6) (monitor -6 (y + 0.75) 7.7)
    (desk -2 (y + 0.75) 7.5) (chair -2 (y + 0.45) 6.6)
    (desk -6 (y + 0.75) -7.5) (cabinet -9.2 (y + 1.3) -4) (cabinet -9.2 (y + 1.3) -3.4)]))
; ..the stairs up from floor k: twenty-two steps of 4/22 m up and a quarter along, by turns
; north up the east side and south up the middle, through a hole in the floor over them; skip
; the steps left out
(: (stair k skip) (: y (4 * k) up (k % 2 = 0) x0 (up ? 6.5 3.5) x1 (up ? 9.3 6.3) rise (4.0 / 22.0)
   (z i) (up ? (-3 + 0.25 * i) (2.5 - 0.25 * i - 0.25))
   [(skin {'floor carpet 'walls paint 'ceiling ceiltile} (air (box [x0 (y + 3.6) -3] [x1 (y + 4.05) 2.5])))
    (map (i \ (skin {'floor carpet 'walls concrete} (solid (box [x0 y (z i)] [x1 (y + rise * (i + 1)) (z i + 0.25)]))))
         (filter (i \ !(elem i skip)) ^22))]))

(: route [['slab 1.84 36.75 8.81 13.58]
          ['slab -3.27 37.52 9.35 6.52]
          ['copier -6.26 38.31 6.47 52.45]
          ['copier -8.48 39.13 3.02 7.74]
          ['cabinet -8.95 39.98 -0.92 8.16]
          ['cabinet -7.66 40.86 -4.72 50.89]
          ['slab -4.13 41.77 -8.87 52.47]
          ['slab 1.24 42.73 -10.17 35.7]
          ['slab 5.84 43.73 -6.84 77.26]
          ['slab 8.77 44.77 -2.01 48.66]
          ['slab 8.6 45.83 3.71 61.38]
          ['slab 5.18 46.91 8.38 57.5]
          ['desk 0.09 48.02 9 64.09]
          ['slab -5.71 49.15 7.86 44.68]
          ['copier -8.46 50.31 3.81 28.27]
          ['door -8.86 51.51 -1.59 22.36]
          ['slab -6.92 52.73 -7.48 21.97]
          ['slab -1.41 53.99 -10.25 78.76]
          ['door 4.01 55.29 -8.14 88.22]
          ['slab 8.42 56.64 -3.57 14.85]
          ['desk 8.75 58.03 2.13 44.01]
          ['slab 7.46 59.47 9.11 6.99]
          ['copier 2.47 60.98 11.96 78.79]
          ['slab -4.31 62.55 10.39 31.52]
          ['door -9.67 64.2 6.64 41.06]
          ['slab -14.39 65.93 0.45 42.67]
          ['slab -9.99 67.78 -6.2 63.13]
          ['door -3.62 69.74 -9.82 34.72]
          ['slab 4.22 71.8 -7.95 41.55]
          ['slab 9.5 73.93 -1.8 44.43]
          ['slab 9.13 76.14 6.61 11.64]
          ['slab 1.55 78.45 10.55 82.51]
          ['door -5.88 80.85 6.81 40.43]
          ['copier -8.99 83.38 -0.49 12.32]
          ['desk -6.66 86.04 -8.98 25.06]
          ['desk 1.32 88.87 -14.04 61.45]
          ['desk 11.17 91.89 -12.61 13.58]
          ['slab 14.62 95.09 -1.97 59.27]])
(: drift [['chair 2.55 43.49 -4.56 1.47]
          ['tile -8.83 71.91 9.49 248.58]
          ['chair -10.94 80.04 -9.96 164.39]
          ['cabinet 20.57 80.36 -6.42 143.31]
          ['monitor -12.4 59.63 1.45 24.25]
          ['chair 4.69 55.16 7.64 36.86]
          ['chair -15.35 100.22 -3.6 25.31]
          ['desk -6.38 76.95 6.28 216.82]
          ['door 10.49 66.12 9.29 172.94]
          ['chair 6.74 85.48 8.6 172.3]
          ['desk -18.05 45.19 -1.86 52.78]
          ['tile 15.1 69.08 2.59 250.63]
          ['monitor -6.67 42.36 7.4 191.73]
          ['monitor -9.5 46.51 17.37 290.19]
          ['door -1.31 46.78 -20.51 128]
          ['chair 5.47 50.68 0.97 69.71]
          ['desk -9.21 89.83 13.69 343.8]
          ['desk 11.9 65.48 -18.63 287.87]
          ['monitor -3.52 97.32 -5.59 172.09]
          ['cabinet 19.9 59.29 -3.58 267.61]
          ['chair 3.58 103.49 5.56 54.41]
          ['door 7.71 40.82 -20.81 236.62]])

; where the orb hangs, and the platform with the telescope trained on it
(: orb-at [0 112 0])
(: scope-at [19 97.6 6])
(: (aim a) (: dx (orb-at 0 - scope-at 0) dz (orb-at 2 - scope-at 2) dy (orb-at 1 - scope-at 1 - 1.3)
   (a = 'deg ? (atan2 dx dz * 180 / 3.14159265) (atan2 dy (sqrt (dx * dx + dz * dz)) * 180 / 3.14159265))))

(level "the tower"
  (textures {'wall concrete 'floor carpet 'ceiling concrete})
  (start [0 0 -19] 0 8)
  (shot 4 [-21 8 -21] 40 24)
  (sky 22.5 'clear) (skylight (rgb 0.3 0.3 0.4))
  (ambient (rgb 0.14 0.14 0.15))
  ; the pull, a whole one through the offices, easing above them to a seventh at the top
  (gravity [[24 9.8] [44 5.0] [70 2.6] [100 1.4]])
  ; the void, open to the sky and walled by nothing to see; its floor the plaza, ringed by
  ; buildings roofed at twelve metres out to the void's edge
  (skin {'floor paving} (void [-30 0 -30] [30 130 30]))
  (map (b \ (skin {'walls facade 'floor gravel} (solid (box (b 0) (b 1)))))
       [[[-30 0 -30] [30 12 -24]] [[-30 0 24] [30 12 30]] [[-30 0 -24] [-24 12 24]] [[24 0 -24] [30 12 24]]])
  ; the tower, its door on the plaza, six whole floors and the stairs through them
  (skin {'walls cladding 'floor carpet 'ceiling concrete} (solid (box [-10 0 -10] [10 24 10])))
  (map storey ^6)
  (air (box [-1.5 0 -10.05] [1.5 3 -9.65]))
  (map (k \ stair k ()) ^6)
  ; ..its roof the first floor come apart: the stairs on up, columns, stubs of wall
  (stair 6 ())
  (map (c \ (skin {'all concrete} (solid (box [(c 0 - 0.25) 24 (c 1 - 0.25)] [(c 0 + 0.25) (c 2) (c 1 + 0.25)]))))
       [[7.5 7.5 27.7] [-7.5 7.5 27.7] [-7.5 -7.5 27.7] [2.5 -7.5 25.5] [-2.5 2.5 26.2]])
  (map (w \ (skin {'all cladding} (solid (box (w 0) (w 1)))))
       [[[-10 24 -10] [-4 26.2 -9.7]] [[-10 24 9.7] [-2 25.4 10]] [[9.7 24 -10] [10 27.7 -6]] [[-10 24 1] [-9.7 25 6]]])
  (desk -5 24.75 -6) (chair -4.4 24.45 -5.2) (cabinet 1 25.3 8.5)
  ; ..the next floor in three plates, its stairs with steps gone
  (slab 6.5 28 6.25 7 7.5) (slab -5.5 28 6 9 8) (slab -5.75 28 -5.25 7.5 8.5)
  (stair 7 [7 8 15])
  (desk 6 28.95 7) (chair -6 28.6 5) (tile 4 28.4 4)
  ; ..the next drifted apart, and rubble up from it
  (slab 5.8 32 -6.3 7.2 6.6) (slab -5.4 32.2 -7.35 8.8 5.7) (slab -4.75 31.8 6.6 6.5 7.2)
  (map (b \ (skin {'all concrete} (solid (box [(b 0 - 0.6) (b 2 - 0.8) (b 1 - 0.6)] [(b 0 + 0.6) (b 2) (b 1 + 0.6)]))))
       [[8 -1.8 32.85] [7.2 0.2 33.7] [8.2 2.1 34.55] [5.6 1.9 35.4]])
  ; ..and the last, a few slabs adrift
  (slab 6.5 36 6.5 6 6) (slab -6.25 36.4 1 6.5 6) (turn 12 [0 -8] [(slab 0 35.6 -8 8 4)])
  (cabinet 8 37.6 8) (monitor 5 36.2 4.5)
  ; the way up, and the furniture adrift off it
  (map piece route)
  (map piece drift)
  ; at the top the orb, turning, and on its own platform the telescope looking up at it
  (slab (scope-at 0) (scope-at 1) (scope-at 2) 4 4)
  (telescope scope-at (aim 'deg) (aim 'pitch) (rgb 0.9 0.9 0.87))
  (coarse 4 (glow (orb orb-at 6 pinkorb 0.06)))
  (coarse 4 (glow (inward (orb orb-at 5.95 pinkin 0.06))))
  (herald orb-at 1.6 5.9 smiley "ring.l" ()))
