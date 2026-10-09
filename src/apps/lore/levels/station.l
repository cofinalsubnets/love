; a subway station, for the brushes: a long vaulted hall, its walls ribbed with pilasters
; that flare into sloped buttresses under the ceiling, a corridor off its north end
; through a door. `love lore corridor --level src/apps/lore/levels/station.l`
(level "the station"
  (start (0 0 2) 0)
  ; the hall, ten metres across, five high and thirty-two long
  (room (-19 0 0) (19 5 16))
  ; the pilasters, ten a side: each a column 0.6 wide standing 0.3 out from the wall, and
  ; over it from 3.2 up a buttress whose underside slopes out to 0.9 at the ceiling
  (mirror x 0
   (solid (box (-19 0 0) (-11 5 4)))
   (solid (box (-7 0 0) (-3 5 4)))
   (solid (box (-15 0 8) (-11 5 10)))
   (solid (box (-7 0 8) (-3 5 10)))
   (solid (box (-19 0 16) (-3 5 10)))
   (repeat 2 (4 0 0) (strip (-13 5 6) across)))
  ; the way out north: a door, and a corridor beyond
  ;(room (-1.2 0 32.2) (1.2 2.6 40))
  ;(door (0 0 32.1) 1.2 2.2)
  ; the light: strips across the ceiling between the buttresses, one failing; a bulb at
  ; the corridor's end; a sign over the way out
  (repeat 5 (2 0 0)
    (strip (0 5 4) across))
  (strip (0 5 22.4) across stammer)
  (strip (0 2.6 36))
  (bulb (0 2.1 39.85) (rgb 1.4 1.1 0.7))
  (sign (0 3.2 32) 0.45 "EXIT" (rgb 0.2 1 0.35) buzz)
  (poster (-4.7 1.2 6.4) 0.7 1.0)
  ; the textures, their layers listed at the top of src/apps/lore/swatch.l. the walls: pale
  ; panels 1.3 wide, darker under a rail a metre up, a dark skirting and seams
  (texture wall 64 128 1.3
    (fill (rgb 0.66 0.7 0.68))
    (rows 80 128 (rgb 0.5 0.54 0.52))
    (rows 78 81 (rgb 0.42 0.45 0.44))
    (noise 9 7 0.06)
    (rows 124 128 0.16)
    (cols 0 1 0.22) (cols 63 64 0.22))
  ; ..tiles half a metre, every other a shade darker, in dark grout
  (texture floor 64 64 1
    (fill (rgb 0.34 0.34 0.36))
    (checker 32 32 (rgb 0.3 0.31 0.33))
    (noise 5 0.1)
    (grid 32 32 1 0.12))
  ; ..pale panels 0.6 across
  (texture ceiling 64 64 1.2
    (fill 0.81) (noise 6 0.04)
    (grid 32 32 1 0.3))
  ; ..and the door: brushed steel in plates, a seam down the middle, a hazard band at its foot
  (texture door 64 128 1
    (fill (rgb 0.5 0.52 0.56))
    (noise 30 0.77 0.08)
    (cols 30 34 0.2)
    (grid 0 32 1 0.25)
    (within 0 112 64 128
      (fill 0.08)
      (stripes 16 8 -1 (rgb 0.85 0.65 0.08)))))
