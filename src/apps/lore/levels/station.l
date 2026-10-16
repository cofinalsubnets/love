; `love lore corridor --level src/apps/lore/levels/station.l`
(borrow 'scenery)

; the textures, their layers listed at the top of src/apps/lore/swatch.l. the walls: pale
; panels 1.3 wide, darker under a rail a metre up, a dark skirting and seams
(: wall (texture 64 128 1.3
         '((fill (rgb 0.66 0.7 0.68))
           (rows 80 128 (rgb 0.5 0.54 0.52))
           (rows 78 81 (rgb 0.42 0.45 0.44))
           (noise 9 7 0.06)
           (rows 124 128 0.16)
           (cols 0 1 0.22) (cols 63 64 0.22))))
; ..tiles half a metre, every other a shade darker, in dark grout
(: tiles (texture 64 64 1
          '((fill (rgb 0.34 0.34 0.36))
            (checker 32 32 (rgb 0.3 0.31 0.33))
            (noise 5 0.1)
            (grid 32 32 1 0.12))))
; ..pale panels 0.6 across
(: panels (texture 64 64 1.2
           '((fill 0.81) (noise 6 0.04)
             (grid 32 32 1 0.3))))
; ..and the door: brushed steel in plates, a seam down the middle, a hazard band at its foot
(: steel (texture 64 128 1
          '((fill (rgb 0.5 0.52 0.56))
            (noise 30 0.77 0.08)
            (cols 30 34 0.2)
            (grid 0 32 1 0.25)
            (within 0 112 64 128
              (fill 0.08)
              (stripes 16 8 -1 (rgb 0.85 0.65 0.08))))))

; ..the platform's floor: a grate of steel bars over the dark
(: grate (texture 64 64 1
          '((fill (rgb 0.03 0.03 0.04))
            (grid 16 16 4 (rgb 0.46 0.47 0.5))
            (grid 64 64 2 (rgb 0.3 0.31 0.33))
            (noise 6 0.2))))
; ..the car: pale steel, a dark band of windows, a red line under them
(: carbody (texture 64 64 2.3
            '((fill (rgb 0.72 0.74 0.76))
              (noise 20 0.6 0.06)
              (rows 14 30 (rgb 0.06 0.07 0.09))
              (rows 33 36 (rgb 0.6 0.08 0.06))
              (cols 0 1 0.35))))

(level "the station"
  (textures {'wall wall 'floor tiles 'ceiling panels 'door steel 'train carbody})
  ; the start inside the car, facing its door
  (start [0 0 -5.9] 0 0)
  ; the hall, 38 metres across, five high and 16 long
  (room [-19 0 0] [19 5 16])
  ; the platform, its floor a grate, and the track beside it running on into the tunnels
  (skin {'floor grate} (room [-24 0 -4.52] [24 3.5 0]))
  (room [-24 0 -7.6] [24 3.5 -4.52])
  (room [-70 0 -7.6] [70 3 -4.52])
  ; solid blocks standing in from the side walls, mirrored about x 0; the hallway between
  ; them opens onto the platform, and each wing's chamber south looks onto it over a railing
  (mirror-x 0
   [(solid (box [-19 0 0] [-11 5 4]))
    (solid (box [-7 0 0] [-3 5 4]))
    (solid (box [-15 0 8] [-11 5 10]))
    (solid (box [-7 0 8] [-3 5 10]))
    (solid (box [-19 0 16] [-3 5 10]))
    (repeat 2 [4 0 0] [(across (strip-light [-13 5 6]))])
    ; ..the chamber's railing: a plinth, two posts and a rail, open over it to the platform's ceiling
    (solid (box [-11 0 -0.1] [-7 0.4 0.1]))
    (repeat 2 [1.33 0 0] [(solid (box [-9.7 0.4 -0.03] [-9.64 1.0 0.03]))])
    (solid (box [-11 1.0 -0.04] [-7 1.06 0.04]))])
  ; the car at the platform, its door on the hallway; it leaves west
  (train [-9 0 -7.2] [9 2.3 -4.6] (door [0 0 -4.6] 1.4 2.0) -55)
  (repeat 7 [6 0 0] [(across (strip-light [-18 3.5 -2.4]))])
  ; the way out north: a door, and a corridor beyond
  ;(room [-1.2 0 32.2] [1.2 2.6 40])
  ;(door [0 0 32.1] 1.2 2.2)
  ; the light: strips across the ceiling, one failing at the north end; a sign on the
  ; north wall
  (repeat 5 [2 0 0] [(across (strip-light [0 5 4]))])
  (stammer (across (strip-light [0 5 12])))
  (buzz (sign [0 3.2 15.9] 0.45 "EXIT" (rgb 0.2 1 0.35)))
  (poster [-4.7 1.2 6.4] 0.7 1.0 ()))
