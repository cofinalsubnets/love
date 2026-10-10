; the test corridor: `love lore corridor --level src/apps/lore/levels/hall.l`, read again
; whenever it is saved. metres; every place (x y z), x east, y up, z north. the forms are
; listed at the top of src/apps/lore/corridor.l.
(level "the test corridor"
  (start (0 0 1) 0)
  ; the hallway, and the room past the door; the 0.2 between them is the wall
  (room (-1.2 0 0) (1.2 2.6 12.4))
  (room (-1.2 0 12.6) (1.2 2.6 16.5))
  (door (0 0 12.5) 1.2 2.2)
  ; the lights: four strips down the hall, the third failing, and the room's bulb
  (strip (0 2.6 2))
  (strip (0 2.6 5))
  (strip (0 2.6 8) stammer)
  (strip (0 2.6 11))
  (bulb (0 2.1 16.38) (rgb 1.6 0.12 0.06) breathe)
  ; on the walls
  (poster (-1.2 1.1 4) 0.6 0.9)
  (sign (1.2 1.75 7) 0.3 "LOUNGE" (rgb 1 0.16 0.55) buzz)
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
