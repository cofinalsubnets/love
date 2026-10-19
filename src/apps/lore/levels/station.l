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
;; ..glass, faintly green, smeared
(: glass (texture 64 64 2
          '((fill (rgb 0.6 0.74 0.7))
            (noise 24 8 0.12)
            (patches 10 0.2 (shade 1.08)))))
;; ..the bins: pale blue steel, and their sign, a figure dropping litter in a ring
(: binmetal (texture 32 64 0.6
             '((fill (rgb 0.62 0.67 0.74))
               (noise 12 0.5 0.07))))
(: binsign (texture 64 64 0.3
            '((fill hole)
              (disc 32 32 30 (grey 0.92)) (disc 32 32 26 hole)
              (disc 25 17 4 (grey 0.92))
              (rect 21 22 29 39 (grey 0.92)) (rect 28 24 38 28 (grey 0.92))
              (rect 21 39 24 51 (grey 0.92)) (rect 26 39 29 51 (grey 0.92))
              (rect 36 37 46 39 (grey 0.92)) (rect 37 39 45 51 (grey 0.92))
              (disc 39 32 2 (grey 0.92)))))
; ..the street: paving slabs a metre square, worn, in pale joints
(: paving (texture 64 64 2
           '((fill (rgb 0.5 0.49 0.46))
             (checker 32 32 (rgb 0.47 0.46 0.44))
             (noise 7 0.08)
             (patches 6 0.15 (shade 0.9))
             (grid 32 32 1 (rgb 0.62 0.6 0.56)))))
; ..the buildings: concrete storeys four metres, a band of dark glass along each
(: facade (texture 64 64 4
           '((fill (rgb 0.62 0.6 0.56))
             (noise 9 0.05)
             (within 0 18 64 44
               (fill (rgb 0.16 0.2 0.25))
               (noise 5 0.08)
               (cols 0 4 (rgb 0.62 0.6 0.56)) (cols 30 34 (rgb 0.62 0.6 0.56)) (cols 62 64 (rgb 0.62 0.6 0.56)))
             (rows 44 47 (rgb 0.45 0.44 0.41)))))
;; the street and the recruitment office
; ..the road: worn asphalt, its centre line, and a crossing's white bars
(: asphalt (texture 64 64 3
            '((fill (rgb 0.19 0.19 0.2)) (noise 3 0.15) (noise 17 0.1)
              (patches 9 0.2 (shade 0.85)))))
(: roadline (texture 8 8 1 '((fill (rgb 0.86 0.78 0.42)) (noise 2 0.15))))
(: zebra (texture 64 16 1 '((fill hole) (stripes 16 9 0 (grey 0.85)) (noise 4 0.15))))
(: kerb (texture 32 32 1 '((fill (rgb 0.6 0.59 0.56)) (noise 4 0.1) (grid 32 0 1 0.4))))
; ..the office: board-marked concrete, its storeys four and a half metres with a band of
; narrow windows, and the buttresses bare
(: unnwall (texture 64 64 4.5
            '((fill (rgb 0.55 0.54 0.52)) (noise 11 0.06)
              (rows 0 2 (rgb 0.42 0.41 0.4))
              (within 0 22 64 46
                (fill (rgb 0.09 0.11 0.14)) (noise 5 0.12)
                (cols 0 3 (rgb 0.5 0.49 0.47)) (cols 15 17 (rgb 0.5 0.49 0.47))
                (cols 31 34 (rgb 0.5 0.49 0.47)) (cols 47 49 (rgb 0.5 0.49 0.47)) (cols 62 64 (rgb 0.5 0.49 0.47))))))
(: concrete (texture 32 64 2
             '((fill (rgb 0.6 0.59 0.56)) (noise 7 0.08) (patches 5 0.25 (shade 0.92))
               (grid 0 8 1 (shade 0.88)))))
; ..its doors: two bronze leaves, dark glass in each, their handles by the seam
(: unndoor (texture 64 56 3.4
            '((fill (rgb 0.32 0.26 0.18)) (noise 8 0.1)
              (rect 5 5 29 51 (rgb 0.07 0.09 0.12)) (rect 35 5 59 51 (rgb 0.07 0.09 0.12))
              (within 5 5 59 51 (patches 6 0.2 (shade 1.6)))
              (cols 31 33 0.04)
              (rect 27 20 29 36 (rgb 0.8 0.68 0.42)) (rect 35 20 37 36 (rgb 0.8 0.68 0.42)))))
; ..and its banner: on blue in a gold edge, a triangle of three stars pointing down, two
; hands raised under it, and UNN
(: (star cx cy r c) ('poly . cats (map (k \ (: a (3.14159265 * (k / 5.0 - 0.5)) q (k % 2 = 0 ? r (0.4 * r))
                                             [(cx + q * cos a) (cy + q * sin a)]))
                                      ^10)
                         + [c]))
(: (hand cx s c) [['poly (cx - 4) 116 (cx + 4) 116 (cx + 5) 100 (cx - 5) 100 c]
                  ['poly (cx - 6) 101 (cx + 6) 101 (cx + 7) 84 (cx - 7) 84 c]
                  ['rect (cx - 7) 71 (cx - 4) 86 c] ['rect (cx - 3) 66 cx 86 c]
                  ['rect (cx + 1) 67 (cx + 4) 86 c] ['rect (cx + 5) 72 (cx + 8) 86 c]
                  ['poly (cx + s * 6) 99 (cx + s * 7) 91 (cx + s * 12) 82 (cx + s * 14) 85 (cx + s * 10) 99 c]])
(: white '(grey 0.94))
(: unnbanner (texture 96 144 4.4
              (cats ['((fill (rgb 0.1 0.2 0.45)) (noise 30 0.08))
                     [(star 36 26 9 white) (star 60 26 9 white) (star 48 46 9 white)]
                     (hand 33 1 white) (hand 63 -1 white)
                     '((rect 23 122 27 138 (grey 0.94)) (rect 33 122 37 138 (grey 0.94)) (rect 23 134 37 138 (grey 0.94))
                       (rect 41 122 45 138 (grey 0.94)) (rect 51 122 55 138 (grey 0.94)) (poly 41 122 45 122 55 138 51 138 (grey 0.94))
                       (rect 59 122 63 138 (grey 0.94)) (rect 69 122 73 138 (grey 0.94)) (poly 59 122 63 122 73 138 69 138 (grey 0.94))
                       (rows 0 3 (rgb 0.8 0.65 0.25)) (rows 141 144 (rgb 0.8 0.65 0.25))
                       (cols 0 3 (rgb 0.8 0.65 0.25)) (cols 93 96 (rgb 0.8 0.65 0.25)))])))

(level "the station"
  (textures {'wall wall 'floor tiles 'ceiling panels 'door steel 'train carbody})
  ; the start inside the car, facing its door
  (start [0 0 -5.9] 0 0)
  ; the hall, 38 metres across, five high and 16 long
  (room [-19 0 0] [19 5 16])
  ; the platform, its floor a grate, and the track a metre below it running on into the
  ; tunnels, under the car's floor
  (skin {'floor grate} (room [-24 0 -4.52] [24 3.5 0]))
  (room [-24 -1 -7.6] [24 3.5 -4.52])
  (room [-70 -1 -7.6] [70 3 -4.52])
  ; solid blocks standing in from the side walls, mirrored about x 0; the hallway between
  ; them and each wing's chamber south open onto the platform
  (mirror-x 0
   [(solid (box [-19 0 0] [-11 5 4]))
    (solid (box [-7 0 0] [-3 5 4]))
    (solid (box [-15 0 8] [-11 5 10]))
    (solid (box [-7 0 8] [-3 5 10]))
    (solid (box [-19 0 16] [-3 5 10]))
    (repeat 2 [4 0 0] [(across (strip-light [-13 5 6]))])
    ; ..the railing along the platform's edge, open across the car's door: a plinth, posts
    ; and a rail
    (solid (box [-24 0 -4.52] [-1 0.4 -4.36]))
    (repeat 16 [-1.52 0 0] [(solid (box [-1.06 0.4 -4.47] [-1 1.0 -4.41]))])
    (solid (box [-24 1.0 -4.48] [-1 1.06 -4.4]))])
  ; the car at the platform, its door on the hallway, a hand clear of the edge; it leaves west
  (train [-9 0 -7.24] [9 2.3 -4.64] (door [0 0 -4.64] 1.4 2.0) -55)
  (repeat 7 [6 0 0] [(across (strip-light [-18 3.5 -2.4]))])
  ; the way out north: two grav shafts behind the hall's north wall, either side of the sign;
  ; facing them, up on the right and down on the left, each a doorway at its foot
  (grav [0.7 0 16.3] [2.7 9 18.3] 'up)
  (grav [-2.7 0 16.3] [-0.7 9 18.3] 'down)
  (air (box [0.9 0 15.9] [2.5 2.6 16.4]))
  (air (box [-2.5 0 15.9] [-0.9 2.6 16.4]))
  ; ..and at their heads each a doorway north, straight out onto the pavement
  (air (box [0.9 9 18.2] [2.5 11.6 18.7]))
  (air (box [-2.5 9 18.2] [-0.9 11.6 18.7]))
  ; the street outside under a smoggy evening overcast: pavements either side of the road,
  ; a crossing from the shafts to the recruitment office's steps
  (sky 17.4 'overcast)
  (smog 0.75)
  (skin {'floor asphalt 'walls facade} (street [-45 8.85 18.5] [45 45 54]))
  (skin {'all paving} (solid (box [-45 8.85 18.5] [45 9 23])))
  (skin {'all paving} (solid (box [-45 8.85 33] [45 9 38])))
  (skin {'all kerb} (solid (box [-45 8.85 22.8] [45 9 23])))
  (skin {'all kerb} (solid (box [-45 8.85 33] [45 9 33.2])))
  (repeat 15 [6 0 0] [(decal [-42 8.86 28] [0 1 0] [1 0 0] 0.15 3 roadline)])
  (decal [0 8.86 28] [0 1 0] [0 0 1] 4 9.8 zebra)
  (buzz (sign [0 12.4 18.5] 0.6 "STATION" (rgb 0.3 0.75 1)))
  (bin [4.5 9 19.2] 0.55 0.55 0.95 binmetal binsign)
  (bin [-4.5 9 19.2] 0.55 0.55 0.95 binmetal binsign)
  ; ..and a basketball someone left out
  (ball [5.5 9 21])
  ; the UNN recruitment office across the road: five storeys of concrete, four buttresses
  ; sloping down from the top of the first to the pavement and from the top of the second
  ; reaching out over the street; between the middle two, steps up to its doors, shut, and
  ; its banner over them
  (skin {'all unnwall} (solid (box [-18 8.85 38] [18 31.5 54])))
  (repeat 4 [9 0 0]
   [(skin {'all concrete} (solid (box [-14.3 9 36.8] [-12.7 32.2 38.1])))
    (skin {'all concrete} (cut [-14.3 9 33.4] [-12.7 9 33.4] [-13.5 13.5 36.8] (solid (box [-14.3 9 33.4] [-12.7 13.5 36.8]))))
    (skin {'all concrete} (cut [-14.2 16.2 38] [-12.8 16.2 38] [-13.5 18.9 25] (solid (box [-14.2 16.2 25] [-12.8 19.4 38]))))])
  (repeat 4 [0 0.15 0.5] [(skin {'all concrete} (solid (box [-3.7 9 33.6] [3.7 9.15 38])))])
  (air (box [-1.7 9.6 38] [1.7 12.6 38.7]))
  (decal [0 11.1 38.69] [0 0 -1] [0 1 0] 3.4 3 unndoor)
  (decal [0 16.6 37.97] [0 0 -1] [0 1 0] 5.4 8.1 unnbanner)
  (bulb [0 12.45 38.4] (rgb 1 0.85 0.6))
  ; ..and the buildings either side of it
  (skin {'all facade} (solid (box [-45 8.85 38] [-20 33 54])))
  (skin {'all facade} (solid (box [20 8.85 38] [45 28 54])))
  ; the light: strips across the ceiling, one failing at the north end; a sign on the
  ; north wall
  (repeat 5 [2 0 0] [(across (strip-light [0 5 4]))])
  (stammer (across (strip-light [0 5 12])))
  (buzz (sign [0 3.2 15.9] 0.45 "EXIT" (rgb 0.2 1 0.35)))
  (poster [-4.7 1.2 6.4] 0.7 1.0 ())
  ; inside the easternmost block, a room no one can reach: a window in its west face onto the
  ; chamber beside it, a light, and a door in its east wall
  (room [11.3 0 0.3] [18.7 3.2 3.7])
  (window [10.95 0.9 0.6] [11.35 2.6 3.4] glass)
  (strip-light [15 3.2 2])
  (door [18.7 0 2] 1.2 2.2)
  ; the bins: against the blocks either side of the hallway on the platform, at its ends,
  ; and in each wing against the front block
  (mirror-x 0
   [(bin [-5 0 -0.4] 0.55 0.55 0.95 binmetal binsign)
    (bin [-21.5 0 -0.4] 0.55 0.55 0.95 binmetal binsign)
    (bin [-15 0 4.4] 0.55 0.55 0.95 binmetal binsign)]))
