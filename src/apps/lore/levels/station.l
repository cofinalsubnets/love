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
           '((fill (rgb 0.27 0.27 0.28))
             (checker 32 32 (rgb 0.24 0.24 0.25))
             (noise 7 0.08)
             (patches 6 0.15 (shade 0.9))
             (grid 32 32 1 (rgb 0.36 0.36 0.37)))))
; ..the buildings: concrete storeys four metres, a band of dark glass along each
(: facade (texture 64 64 4
           '((fill (rgb 0.27 0.27 0.29))
             (noise 9 0.1)
             (patches 6 0.3 (shade 0.7))
             (within 0 18 64 44
               (fill (rgb 0.05 0.07 0.1))
               (noise 5 0.1)
               (patches 8 0.22 (rgb 0.95 0.72 0.38))
               (patches 5 0.08 (rgb 0.35 0.85 0.95))
               (cols 0 4 (rgb 0.27 0.27 0.29)) (cols 30 34 (rgb 0.27 0.27 0.29)) (cols 62 64 (rgb 0.27 0.27 0.29)))
             (rows 44 47 (rgb 0.17 0.17 0.18)))))
;; the street and the recruitment office
; ..the road: steel plates, studded, in dark seams, and a crossing's pale bars
(: roadmetal (texture 64 64 2
              '((fill (rgb 0.3 0.31 0.33)) (noise 20 0.6 0.08)
                (dots 8 8 1.2 (shade 1.3))
                (patches 9 0.25 (shade 0.82))
                (grid 32 32 1 (rgb 0.1 0.1 0.11)))))
(: zebra (texture 64 16 1 '((fill hole) (stripes 16 9 0 (grey 0.85)) (noise 4 0.15))))
(: kerb (texture 32 32 1 '((fill (rgb 0.36 0.36 0.36)) (noise 4 0.1) (grid 32 0 1 0.4))))
; ..the office: board-marked concrete, its storeys four and a half metres with a band of
; narrow windows, and the buttresses bare
(: unnwall (texture 64 64 4.5
            '((fill (rgb 0.3 0.3 0.31)) (noise 11 0.08)
              (patches 7 0.3 (shade 0.75))
              (rows 0 2 (rgb 0.2 0.2 0.21))
              (within 0 22 64 46
                (fill (rgb 0.04 0.06 0.09)) (noise 5 0.12) (patches 6 0.12 (rgb 0.4 0.75 1.0))
                (cols 0 3 (rgb 0.27 0.27 0.28)) (cols 15 17 (rgb 0.27 0.27 0.28))
                (cols 31 34 (rgb 0.27 0.27 0.28)) (cols 47 49 (rgb 0.27 0.27 0.28)) (cols 62 64 (rgb 0.27 0.27 0.28))))))
(: concrete (texture 32 64 2
             '((fill (rgb 0.33 0.33 0.34)) (noise 7 0.1) (patches 5 0.35 (shade 0.8))
               (grid 0 8 1 (shade 0.88)))))
; ..its doors: two leaves of blued steel, each a raised plate with its corners cut, a dark
; seam between, blue lights in the frame, a hazard band at the foot
(: unndoor (texture 64 56 3.4
            '((fill (rgb 0.42 0.45 0.5)) (noise 20 0.6 0.06)
              (poly 7 6 25 6 29 10 29 44 25 48 7 48 3 44 3 10 (shade 1.18))
              (poly 39 6 57 6 61 10 61 44 57 48 39 48 35 44 35 10 (shade 1.18))
              (rows 26 28 (shade 0.6))
              (rows 0 2 0.12) (cols 0 2 0.12) (cols 62 64 0.12)
              (cols 31 33 0.06)
              (rect 0 18 2 36 (rgb 0.3 0.75 1)) (rect 62 18 64 36 (rgb 0.3 0.75 1))
              (within 0 50 64 56 (fill 0.1) (stripes 8 4 -1 (rgb 0.85 0.65 0.1))))))
; ..and its banner: on black, two red hands raised side by side, palms facing, fingers up,
; and over them the three stars they have let go, a triangle pointing down; UNN across
; the wrists
(: (star cx cy r c) ('poly . cats (map (k \ (: a (3.14159265 * (k / 5.0 + 0.5)) q (k % 2 = 0 ? r (0.4 * r))
                                             [(cx + q * cos a) (cy + q * sin a)]))
                                      ^10)
                         + [c]))
; ..a hand seen from its thumb's side, its wrist at x y, its palm toward s: the forearm
; upright, the hand's edge from the back of it round the fingers' tips to the palm, the
; thumb in front with its nail
(: (hand x y s c nail) (: (part k ps) ('poly . cats (map (p \ [(x + s * p 0) (y + p 1)]) ps) + [k])
                          [(part c [[-4 0] [4 0] [4.5 40] [-4.5 40]])
                           (part c [[5 0] [6.5 -12] [6.5 -24] [5 -33] [2 -38] [-1.5 -37] [-3.5 -32] [-3 -26] [-1.5 -21] [-2 -16] [-4.5 -8] [-4.5 0]])
                           (part c [[-4.5 -2] [-6 -8] [-6.8 -16] [-6.3 -24] [-4 -24.5] [-3.2 -17] [-2.5 -10]])
                           (part nail [[-3.8 -19] [-6.1 -19] [-5.9 -23.4] [-4.2 -23.7]])
                           (part '(shade 0.6) [[-1.5 -21] [2 -33] [2.8 -33] [-0.6 -21]])]))
(: red '(rgb 0.78 0.07 0.05))
(: pink '(rgb 0.95 0.45 0.4))
(: white '(grey 0.95))
(: unnbanner (texture 96 128 3.6
              (cats ['((fill (rgb 0.025 0.025 0.03)) (noise 30 0.1))
                     [(star 34 36 9 white) (star 62 36 9 white) (star 48 56 9 white)]
                     (hand 39 100 -1 red pink) (hand 57 100 1 red pink)
                     '((rect 23 100 27 114 (grey 0.95)) (rect 33 100 37 114 (grey 0.95)) (rect 23 110 37 114 (grey 0.95))
                       (rect 41 100 45 114 (grey 0.95)) (rect 51 100 55 114 (grey 0.95)) (poly 41 100 45 100 55 114 51 114 (grey 0.95))
                       (rect 59 100 63 114 (grey 0.95)) (rect 69 100 73 114 (grey 0.95)) (poly 59 100 63 100 73 114 69 114 (grey 0.95)))])))

;; the corner shop and the advertisements
; ..the shop's grimed render, its sign's dark steel
(: grime (texture 32 32 2 '((fill (rgb 0.26 0.24 0.23)) (noise 9 0.2) (patches 5 0.35 (shade 0.7)) (rows 0 1 0.12))))
(: darkmetal (texture 16 16 1 '((fill (rgb 0.08 0.08 0.09)) (noise 4 0.3))))
; ..its sign: the shop's name, its first and last two small across over and under the four
; between, down the middle; both faces the same
(: (shopsign x s) [(neon [x 19.2 21.35] [s 0 0] 0.55 "戈文" (rgb 0.3 0.85 1))
                   (neon [x 17.95 21.35] [s 0 0] 0.85 "天" (rgb 1 0.2 0.55))
                   (neon [x 16.85 21.35] [s 0 0] 0.85 "然" (rgb 1 0.2 0.55))
                   (neon [x 15.75 21.35] [s 0 0] 0.85 "食" (rgb 1 0.2 0.55))
                   (neon [x 14.65 21.35] [s 0 0] 0.85 "品" (rgb 1 0.2 0.55))
                   (neon [x 13.75 21.35] [s 0 0] 0.55 "中心" (rgb 0.3 0.85 1))])
; ..the boards, bright as their own light: red and blue, a disc and a pointer and lines of
; type; green, a bubble and type; the spinner's magenta and its yellow
(: adredblue (texture 128 64 13
              '((fill (rgb 0.95 0.08 0.12)) (poly 50 0 128 0 128 64 78 64 (rgb 0.08 0.22 1))
                (disc 28 32 20 (grey 0.97)) (disc 28 32 14 (rgb 0.08 0.22 1)) (poly 23 23 38 32 23 41 (grey 0.97))
                (rect 74 10 122 19 (grey 0.97)) (rect 80 25 118 30 (grey 0.97)) (rect 84 35 120 40 (grey 0.97))
                (rect 88 47 122 56 (rgb 1 0.85 0.2)))))
(: adgreen (texture 128 64 12
            '((fill (rgb 0.04 0.78 0.3)) (rect 0 46 128 64 (rgb 0.01 0.25 0.08))
              (disc 100 22 17 (rgb 0.75 1 0.35)) (disc 94 16 5 (grey 0.97))
              (rect 10 9 66 18 (grey 0.97)) (rect 10 24 52 30 (grey 0.97)) (rect 10 34 60 39 (grey 0.97))
              (rect 10 51 42 59 (rgb 1 1 0.5)) (rect 50 51 70 59 (rgb 1 1 0.5)))))
(: spin1 (texture 64 48 5 '((fill (rgb 0.95 0.08 0.6)) (disc 32 22 15 (rgb 0.2 0.9 1)) (disc 32 22 9 (rgb 0.95 0.08 0.6)) (rect 6 40 58 44 (grey 0.97)))))
(: spin2 (texture 64 48 5 '((fill (rgb 1 0.85 0.08)) (rect 0 0 64 6 0.05) (rect 0 42 64 48 0.05) (poly 10 34 32 10 54 34 (rgb 0.9 0.08 0.08)))))
; ..the street sweeper: yellow paint scuffed, grey steel, a dark cab, the drums' worn
; steel, and caution bars; the garage it came out of, ribbed, a bar of the same at its top
; and its foot
(: sweepyellow (texture 32 32 1.5 '((fill (rgb 0.86 0.64 0.06)) (noise 6 0.18) (patches 4 0.2 (shade 0.6)) (grid 32 0 1 (shade 0.5)))))
(: sweepgrey (texture 32 32 1.5 '((fill (rgb 0.36 0.37 0.39)) (noise 6 0.15) (grid 16 16 1 (shade 0.6)))))
(: cabglass (texture 32 32 1 '((fill (rgb 0.04 0.07 0.1)) (noise 8 0.3) (rows 0 4 (rgb 0.36 0.37 0.39)))))
(: drumsteel (texture 32 32 1 '((fill (rgb 0.22 0.22 0.23)) (noise 3 12 0.35) (cols 0 2 (shade 0.5)))))
(: grille (texture 32 8 1 '((fill (grey 0.05)) (cols 0 2 (rgb 0.86 0.64 0.06)) (cols 30 32 (rgb 0.86 0.64 0.06)) (grid 3 0 1 (grey 0.2)))))
(: hazard (texture 32 8 1 '((fill (rgb 0.95 0.72 0.04)) (stripes 12 6 1 (grey 0.04)))))
(: garage (texture 64 64 4.6
           '((fill (rgb 0.3 0.31 0.32)) (noise 9 0.2) (grid 0 5 1 (shade 0.45)) (patches 6 0.3 (shade 0.75))
             (within 0 0 64 6 (fill (rgb 0.95 0.72 0.04)) (stripes 12 6 1 (grey 0.04)))
             (within 0 58 64 64 (fill (rgb 0.95 0.72 0.04)) (stripes 12 6 1 (grey 0.04))))))
;; the memorial at the office's door
; ..wax, brown and the one purple, and a candle: its four sides and its top as pictures
(: wax (texture 8 16 0.1 '((fill (rgb 0.36 0.21 0.11)) (noise 2 6 0.2) (rows 0 1 (rgb 0.5 0.32 0.17)))))
(: purplewax (texture 8 16 0.1 '((fill (rgb 0.24 0.06 0.4)) (noise 2 6 0.2) (rows 0 1 (rgb 0.36 0.14 0.52)))))
(: (candle x y z h t) (: w 0.07 r 0.035 m (y + 0.5 * h)
   [(decal [(x + r) m z] [1 0 0] [0 1 0] w h t) (decal [(x - r) m z] [-1 0 0] [0 1 0] w h t)
    (decal [x m (z + r)] [0 0 1] [0 1 0] w h t) (decal [x m (z - r)] [0 0 -1] [0 1 0] w h t)
    (decal [x (y + h) z] [0 1 0] [0 0 1] w w t)]))
; ..a wreath: laurel round, white and red and yellow blooms on it, a black ribbon at its foot
(: wreath (texture 64 64 1
           '((fill hole) (disc 32 32 30 (rgb 0.1 0.26 0.1)) (disc 32 32 17 hole) (noise 3 0.45) (patches 3 0.35 (shade 0.55))
             (disc 54.09 31.221 4.111 (grey 0.95)) (disc 54.827 38.159 3.712 (rgb 0.82 0.07 0.1)) (disc 51.29 45.474 3.252 (rgb 1 0.86 0.25)) (disc 43.139 50.715 3.327 (grey 0.95)) (disc 36.676 56.363 3.373 (rgb 0.95 0.55 0.7)) (disc 29.145 55.839 4.527 (grey 0.95)) (disc 20.15 51.813 4.567 (rgb 0.82 0.07 0.1)) (disc 14.429 49.691 3.605 (rgb 1 0.86 0.25)) (disc 11.94 40.963 3.632 (grey 0.95)) (disc 9.821 30.596 4.014 (rgb 0.95 0.55 0.7)) (disc 10.624 23.54 3.967 (grey 0.95)) (disc 14.191 19.534 3.488 (rgb 0.82 0.07 0.1)) (disc 21.127 11.494 3.64 (rgb 1 0.86 0.25)) (disc 28.345 8.976 3.62 (grey 0.95)) (disc 37.62 8.363 3.542 (rgb 0.95 0.55 0.7)) (disc 44.103 11.739 4.425 (grey 0.95)) (disc 50.002 18.251 4.572 (rgb 0.82 0.07 0.1)) (disc 53.107 22.436 4.26 (rgb 1 0.86 0.25))
             (poly 27 46 37 46 42 64 32 57 22 64 (grey 0.03)))))
; ..bouquets, in their paper
(: posies (texture 32 32 0.5 '((fill hole) (poly 15.2 26 16.8 26 11.681 12 10.081 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 21.664 12 20.064 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 20.493 12 18.893 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 13.371 12 11.771 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 16.736 12 15.136 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 16.093 12 14.493 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 18.922 12 17.322 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 20.842 12 19.242 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 11.114 12 9.514 12 (rgb 0.16 0.42 0.12)) (disc 6.567 13.193 2.806 (grey 0.95)) (disc 19.917 6.93 3.323 (rgb 0.6 0.3 0.85)) (disc 24.905 13.916 2.243 (grey 0.95)) (disc 18.991 4.101 3.434 (rgb 0.6 0.3 0.85)) (disc 10.332 8.643 2.241 (grey 0.95)) (disc 21.274 14.331 2.974 (rgb 1 0.86 0.25)) (disc 10.617 6.407 2.843 (rgb 1 0.86 0.25)) (disc 24.53 8.578 3.483 (rgb 0.6 0.3 0.85)) (disc 8 10.923 3.213 (rgb 1 0.86 0.25)) (disc 8.418 7.66 3.21 (rgb 0.6 0.3 0.85)) (disc 16.016 14.639 2.911 (rgb 0.6 0.3 0.85)) (disc 9.797 7.126 3.563 (rgb 1 0.86 0.25)) (poly 8 18 24 18 18 32 14 32 (rgb 0.86 0.84 0.78)) (poly 8 18 24 18 23 20 9 20 (rgb 0.7 0.68 0.62)))))
(: lilies (texture 32 32 0.5 '((fill hole) (poly 15.2 26 16.8 26 23.184 12 21.584 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 23.07 12 21.47 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 10.592 12 8.992 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 10.988 12 9.388 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 21.497 12 19.897 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 20.104 12 18.504 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 19.176 12 17.576 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 14.114 12 12.514 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 18.283 12 16.683 12 (rgb 0.16 0.42 0.12)) (disc 18.136 10.393 2.422 (grey 0.9)) (disc 18.769 12.84 3.404 (rgb 1 0.95 0.7)) (disc 24.988 9.986 2.823 (grey 0.9)) (disc 24.024 13.581 2.71 (grey 0.9)) (disc 24.155 8.66 3.438 (grey 0.97)) (disc 17.21 6.597 2.233 (grey 0.9)) (disc 9.472 9.612 2.704 (rgb 1 0.95 0.7)) (disc 19.49 6 3.451 (grey 0.9)) (disc 20.688 13.973 3.268 (rgb 1 0.95 0.7)) (disc 13.076 14.791 3.547 (grey 0.97)) (disc 25.099 8.398 3.234 (rgb 1 0.95 0.7)) (disc 16.607 9.39 3.495 (rgb 1 0.95 0.7)) (poly 8 18 24 18 18 32 14 32 (rgb 0.86 0.84 0.78)) (poly 8 18 24 18 23 20 9 20 (rgb 0.7 0.68 0.62)))))
(: roses (texture 32 32 0.5 '((fill hole) (poly 15.2 26 16.8 26 13.132 12 11.532 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 17.419 12 15.819 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 14.979 12 13.379 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 18.255 12 16.655 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 18.56 12 16.96 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 10.717 12 9.117 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 9.984 12 8.384 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 21.525 12 19.925 12 (rgb 0.16 0.42 0.12)) (poly 15.2 26 16.8 26 13.431 12 11.831 12 (rgb 0.16 0.42 0.12)) (disc 10.687 14.952 2.858 (rgb 0.95 0.55 0.7)) (disc 15.527 11.03 2.411 (rgb 0.95 0.55 0.7)) (disc 9.032 14.184 2.746 (rgb 0.75 0.05 0.08)) (disc 19.428 4.704 3.262 (rgb 0.95 0.55 0.7)) (disc 6.856 12.581 3.353 (rgb 0.9 0.15 0.2)) (disc 15.455 11.907 3.43 (rgb 0.95 0.55 0.7)) (disc 21.762 8.696 3.219 (rgb 0.95 0.55 0.7)) (disc 14.892 14.291 3.43 (rgb 0.75 0.05 0.08)) (disc 6.718 9.444 2.561 (rgb 0.95 0.55 0.7)) (disc 14.723 10.893 2.621 (rgb 0.95 0.55 0.7)) (disc 22.67 10.314 2.948 (rgb 0.9 0.15 0.2)) (disc 17.685 13.946 3.155 (rgb 0.75 0.05 0.08)) (poly 8 18 24 18 18 32 14 32 (rgb 0.86 0.84 0.78)) (poly 8 18 24 18 23 20 9 20 (rgb 0.7 0.68 0.62)))))
; ..a bouquet standing: two pictures in a vee opening toward the street
(: (flowers x y z t) [(decal [x (y + 0.24) z] [0.7 0 -0.7] [0 1 0] 0.42 0.48 t) (decal [x (y + 0.24) z] [-0.7 0 -0.7] [0 1 0] 0.42 0.48 t)])
; ..a heap of them, n things strewn by seed sd: banked against a wall at z w from x a to b,
; out d toward the street, h high at the wall and spilling to nothing, the ground under
; each at (fl x z); each bouquet one picture, turned roughly to the street, and a few
; wreaths leant into it
(: (rnd i) (: v (sin (i * 12.9898 + 78.233) * 43758.5453) (v - floor v)))
(: blooms [posies lilies roses])
(: (strew x y z q f sd) (: t (rnd (sd + 0.61)) b (blooms (int (floor (2.99 * rnd (sd + 0.29)))))
   (? (t < 0.09) [(decal [x (y + 0.4) z] (q 0) (q 1) 0.95 0.95 wreath)]
      [(decal [x (y + 0.24) z] f [0 1 0] 0.42 0.48 b)])))
(: (bank a b w d h n sd fl) (cats (map (i \ (: u (rnd (sd + i)) k (rnd (sd + i + 0.37) * rnd (sd + i + 0.83))
                                          x (a + (b - a) * u) z (w - 0.12 - d * k)
                                          y (fl x z + h * (1 - k) * (0.55 + 0.45 * rnd (sd + i + 0.17)) - 0.12)
                                       (: a (rnd (sd + i + 0.53) - 0.5) (strew x y z [[0 0.45 -0.89] [0 0.89 0.45]] [a 0 -1] (sd + i)))))
                                ^n)))
; ..the same banked against a wall at x w, from z a to b, out d toward x's s side
(: (side w s a b d h n sd fl) (cats (map (i \ (: u (rnd (sd + i)) k (rnd (sd + i + 0.37) * rnd (sd + i + 0.83))
                                          z (a + (b - a) * u) x (w + s * (0.12 + d * k))
                                          y (fl x z + h * (1 - k) * (0.55 + 0.45 * rnd (sd + i + 0.17)) - 0.12)
                                       (: a (rnd (sd + i + 0.53) - 0.5) (strew x y z [[(0.45 * s) 0.45 -0.77] [0 0.89 0.45]] [(0.6 * s + a) 0 -1] (sd + i)))))
                                ^n)))
; ..the office's ground: the pavement, the steps up from it, the landing; the bays' floor
(: (stepy x z) (? (z < 28.6) 9.0 (min 9.6 (9.15 + 0.15 * floor ((z - 28.6) / 0.5)))))
(: (bayy x z) 8.85)
; ..a wreath on its easel: two dark legs and a bar
(: (easel x y z) [(decal [x (y + 1.25) z] [0 0 -1] [0 1 0] 1.15 1.15 wreath)
                  (whole (skin {'all darkmetal} (solid (box [(x - 0.42) y (z + 0.02)] [(x - 0.38) (y + 1.5) (z + 0.06)]))))
                  (whole (skin {'all darkmetal} (solid (box [(x + 0.38) y (z + 0.02)] [(x + 0.42) (y + 1.5) (z + 0.06)]))))
                  (whole (skin {'all darkmetal} (solid (box [(x - 0.42) (y + 0.6) (z + 0.02)] [(x + 0.42) (y + 0.64) (z + 0.06)]))))])
; ..an office beam level over the street, its end cut to a wedge
(: (beam x) (skin {'all concrete}
             (cut [(x + 1.3) 22.6 22.5] [(x - 1.3) 22.6 22.5] [x 21.6 21]
               (cut [(x - 1.3) 20.6 22.5] [(x + 1.3) 20.6 22.5] [x 21.6 21]
                 (solid (box [(x - 1.3) 20.6 21] [(x + 1.3) 22.6 30.5]))))))

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
  ; the street over the hall, under a smoggy dusk's broken cloud: a narrow pavement on the
  ; station's side, a narrow steel road, a crossing to the recruitment office's steps
  (sky 18.35 'mostly)
  (smog 0.9)
  (skin {'floor roadmetal 'walls facade} (street [-45 8.85 14] [45 45 47]))
  (skin {'all paving} (solid (box [-45 8.85 14] [45 9 22])))
  (skin {'all paving} (solid (box [-45 8.85 28] [45 9 33])))
  (skin {'all kerb} (solid (box [-45 8.85 21.8] [45 9 22])))
  (skin {'all kerb} (solid (box [-45 8.85 28] [45 9 28.2])))
  (decal [0 8.86 25] [0 1 0] [0 0 1] 4 5.8 zebra)
  ; ..across it from the office a great column, the third of its beams reaching over to it,
  ; and either side of the column a wing, upright at the pavement, rising, then level to
  ; meet it; the shafts come up under the west wing, a doorway north from each
  (skin {'all concrete} (solid (box [3 9 14] [6 26 19.5])))
  (skin {'all concrete} (cut [-5.5 13 19] [-5.5 13 14.5] [-2 17 14.5] (solid (box [-5.5 9 14.5] [3 17 19]))))
  (skin {'all concrete} (cut [14.5 13 14.5] [14.5 13 19] [11 17 14.5] (solid (box [6 9 14.5] [14.5 17 19]))))
  ; ..the station's sign on the wing, a room of the street's air before it to hang it on
  (room [-5.5 9 19] [3 13 19.6])
  (buzz (sign [-0.0 12.2 19] 0.5 "STATION" (rgb 0.3 0.75 1)))
  (bin [-7.5 9 20.4] 0.55 0.55 0.95 binmetal binsign)
  (bin [8.5 9 20.4] 0.55 0.55 0.95 binmetal binsign)
  ; ..and a basketball someone left out
  (ball [10 9 21])
  ; the way out north: two grav shafts behind the hall's north wall, either side of the sign;
  ; facing them, up on the right and down on the left, each a doorway at its foot and one
  ; at its head out of the wing
  (grav [0.7 0 16.3] [2.7 9 18.3] 'up)
  (grav [-2.7 0 16.3] [-0.7 9 18.3] 'down)
  (air (box [0.9 0 15.9] [2.5 2.6 16.4]))
  (air (box [-2.5 0 15.9] [-0.9 2.6 16.4]))
  (air (box [0.9 9 18.2] [2.5 11.6 19.1]))
  (air (box [-2.5 9 18.2] [-0.9 11.6 19.1]))
  ; the corner shop at the street's west end, three storeys, its floor a step below the
  ; pavement: a window onto the street, steps down from the east to its door by the corner, a sign
  ; standing out from its front, and a spinner on its roof
  (skin {'all grime} (solid (box [-45 8.85 14] [-33 22.5 20.5])))
  (room [-44.5 8 14.5] [-33.5 12 20])
  (across (strip-light [-39 12 17.2]))
  (window [-42 9.3 19.95] [-35.5 11.6 20.55] glass)
  (skin {'all concrete} (room [-33 8 18.4] [-28.4 9.2 20.2]))
  (repeat 5 [-0.6 -0.1667 0] [(skin {'all concrete} (solid (box [-29 7 18.4] [-28.4 8.833 20.2])))])
  (door [-33.25 8 19.2] 1.2 2.2)
  (skin {'all darkmetal} (solid (box [-34.4 12 20.5] [-34.1 19.8 22.2])))
  (shopsign -34.09 1)
  (shopsign -34.41 -1)
  (skin {'all darkmetal} (solid (box [-39.2 22.5 16.8] [-38.8 25 17.2])))
  (spinner [-39 25 17] 5 3.5 spin1 spin2)
  ; ..the advertisements: red and blue at the west end of the south wall, green high on the
  ; east
  (ad [-24 19 14.03] [0 0 1] [0 1 0] 13 7 adredblue)
  (ad [44.97 28 30] [-1 0 0] [0 1 0] 12 6 adgreen)
  ; ..a street sweeper out of the garage, in the middle of the road before it, nose east,
  ; headlights on: a cab-over truck's front, a grille and a raked windscreen, the cab and
  ; hood and body yellow, a steel roller under each end
  (whole (skin {'all drumsteel} (cut [-35.678 8.85 23.8] [-36 9.172 23.8] [-35.678 8.85 26.2] (cut [-36 9.628 23.8] [-35.678 9.95 23.8] [-36 9.628 26.2] (cut [-34.9 9.172 23.8] [-35.222 8.85 23.8] [-34.9 9.172 26.2] (cut [-35.222 9.95 23.8] [-34.9 9.628 23.8] [-35.222 9.95 26.2] (solid (box [-36 8.85 23.8] [-34.9 9.95 26.2]))))))))
  (whole (skin {'all drumsteel} (cut [-39.628 8.85 23.8] [-39.95 9.172 23.8] [-39.628 8.85 26.2] (cut [-39.95 9.628 23.8] [-39.628 9.95 23.8] [-39.95 9.628 26.2] (cut [-38.85 9.172 23.8] [-39.172 8.85 23.8] [-38.85 9.172 26.2] (cut [-39.172 9.95 23.8] [-38.85 9.628 23.8] [-39.172 9.95 26.2] (solid (box [-39.95 8.85 23.8] [-38.85 9.95 26.2]))))))))
  (whole (skin {'all sweepyellow} (solid (box [-40.5 9.75 23.75] [-34.6 10 26.25]))))
  (whole (skin {'all sweepyellow} (cut [-34.9 10.95 23.75] [-34.5 10.55 23.75] [-34.9 10.95 26.25] (solid (box [-36.25 9.95 23.75] [-34.5 10.95 26.25])))))
  (whole (skin {'all sweepyellow} (solid (box [-34.5 9.85 23.7] [-34.32 10.12 26.3]))))
  (decal [-34.31 9.985 25] [1 0 0] [0 1 0] 2.6 0.27 hazard)
  (decal [-34.495 10.4 25] [1 0 0] [0 1 0] 1.5 0.42 grille)
  (whole (skin {'all sweepyellow} (cut [-36.75 12.4 23.85] [-36.25 11.6 23.85] [-36.75 12.4 26.15] (solid (box [-38.1 10.95 23.85] [-36.25 12.4 26.15])))))
  (decal [-36.49 12.006 25] [0.848 0.53 0] [-0.53 0.848 0] 2.1 0.82 cabglass)
  (decal [-37.25 11.85 23.84] [0 0 -1] [0 1 0] 1.3 0.75 cabglass)
  (decal [-37.25 11.85 26.16] [0 0 1] [0 1 0] 1.3 0.75 cabglass)
  (whole (skin {'all sweepyellow} (solid (box [-37.75 12.4 24.7] [-37.15 12.52 25.3]))))
  (whole (skin {'all sweepyellow} (cut [-40.5 11.3 23.75] [-40.1 11.7 23.75] [-40.5 11.3 26.25] (solid (box [-40.5 10 23.75] [-38.1 11.7 26.25])))))
  (decal [-39.3 10.55 23.74] [0 0 -1] [0 1 0] 2.4 0.25 hazard)
  (decal [-39.3 10.55 26.26] [0 0 1] [0 1 0] 2.4 0.25 hazard)
  (bulb [-34.47 10.45 24] (rgb 1 0.95 0.82))
  (bulb [-34.47 10.45 26] (rgb 1 0.95 0.82))
  ; ..the garage it came out of, shut, a strip over it
  (decal [-44.97 10.75 25] [1 0 0] [0 1 0] 4.6 3.8 garage)
  (strip-light [-44.8 12.9 25])
  ; the UNN recruitment office across the road: five storeys of concrete, four broad
  ; buttresses sloping down from the top of the first to the pavement; from high on the
  ; second each reaches out a beam, braced steeply at its root, level over the street;
  ; between the middle two, steps up to its doors, shut, and its banner over them
  ; ..its three upper storeys over the two below, which stand back between the buttresses,
  ; the middle bay deepest and bare but for the doors and the banner
  (skin {'all concrete 'walls unnwall} (solid (box [-18 8.85 35] [18 18 47])))
  (skin {'all concrete 'walls unnwall} (solid (box [-18 18 33] [18 31.5 47])))
  (air (box [-3.2 9 34.9] [3.2 18 37]))
  (skin {'all concrete} (solid (box [-3.2 8.85 36.9] [3.2 18 37.1])))
  (repeat 4 [9 0 0]
   [(skin {'all concrete} (solid (box [-14.8 9 31.8] [-12.2 32.2 37.1])))
    (skin {'all concrete} (cut [-14.8 9 29] [-12.2 9 29] [-13.5 13.5 31.8] (solid (box [-14.8 9 29] [-12.2 13.5 31.8]))))
    (skin {'all concrete} (cut [-14.8 18.2 33] [-12.2 18.2 33] [-13.5 20.6 30.4] (solid (box [-14.8 18.2 30.4] [-12.2 22.6 33]))))])
  (beam -13.5) (beam -4.5) (beam 13.5)
  (skin {'all concrete} (solid (box [3.2 20.6 19.4] [5.8 22.6 30.5])))
  (repeat 4 [0 0.15 0.5] [(skin {'all concrete} (solid (box [-3.2 9 28.6] [3.2 9.15 37])))])
  (air (box [-1.7 9.6 36.8] [1.7 12.6 37.5]))
  (decal [0 11.1 37.49] [0 0 -1] [0 1 0] 3.4 3 unndoor)
  (decal [0 15.3 36.88] [0 0 -1] [0 1 0] 3.6 4.8 unnbanner)
  (bulb [0 12.9 36.4] (rgb 1 0.85 0.6))
  ; ..and at its door a memorial: wreaths on easels either side and one on the doors,
  ; bouquets heaped along the wall and up the steps' ends, and on the landing eight candles
  ; round, seven brown and lit, the purple one far left unlit
  (easel -2.35 9.6 36.2) (easel 2.35 9.6 36.2)
  ; ..mounds of them against the walls, deepest either side of the doors, down the stairs'
  ; sides to the pavement, and along the bays either side
  (bank -3.2 -1.5 36.9 2.2 1.1 110 100 stepy) (bank 1.5 3.2 36.9 2.2 1.1 110 300 stepy)
  (bank -1.5 1.5 36.9 1.3 0.45 70 500 stepy)
  (side -3.2 1 28.2 36.8 1.5 0.9 140 700 stepy) (side 3.2 -1 28.2 36.8 1.5 0.9 140 900 stepy)
  (bank -12.2 -5.8 35 1.6 0.8 90 1100 bayy) (bank 5.8 12.2 35 1.6 0.8 90 1300 bayy)
  (side -12.2 1 32 35 1.2 0.6 25 1500 bayy) (side -5.8 -1 32 35 1.2 0.6 25 1600 bayy)
  (side 5.8 1 32 35 1.2 0.6 25 1700 bayy) (side 12.2 -1 32 35 1.2 0.6 25 1800 bayy)
  (decal [0 11.6 37.47] [0 0 -1] [0 1 0] 0.8 0.8 wreath)
  (flowers -2.955 9.6 36.62 posies) (flowers -2.544 9.6 36.62 lilies) (flowers -2.108 9.6 36.62 roses)
  (flowers -1.853 9.6 36.62 posies) (flowers 1.851 9.6 36.62 lilies) (flowers 2.159 9.6 36.62 roses)
  (flowers 2.518 9.6 36.62 posies) (flowers 2.951 9.6 36.62 lilies) (flowers -1.287 9.6 36.55 roses)
  (flowers -0.571 9.6 36.55 posies) (flowers 0.059 9.6 36.55 lilies) (flowers 0.78 9.6 36.55 roses)
  (flowers 1.359 9.6 36.55 posies) (flowers -2.85 9.15 28.85 posies) (flowers 2.85 9.15 28.85 lilies)
  (flowers -2.85 9.3 29.35 lilies) (flowers 2.85 9.3 29.35 roses) (flowers -2.85 9.45 29.85 roses)
  (flowers 2.85 9.45 29.85 posies) (flowers -2.85 9.6 30.35 posies) (flowers 2.85 9.6 30.35 lilies)
  (candle 0.21 9.6 33.808 0.32 wax) (candle 0.508 9.6 33.51 0.26 wax)
  (candle 0.508 9.6 33.09 0.3 wax) (candle 0.21 9.6 32.792 0.22 wax)
  (candle -0.21 9.6 32.792 0.28 wax) (candle -0.508 9.6 33.09 0.34 wax)
  (candle -0.508 9.6 33.51 0.24 wax) (candle -0.21 9.6 33.808 0.3 purplewax)
  (flames (rgb 1 0.62 0.25) [[0.21 9.925 33.808] [0.508 9.865 33.51] [0.508 9.905 33.09] [0.21 9.825 32.792] [-0.21 9.885 32.792] [-0.508 9.945 33.09] [-0.508 9.845 33.51]])
  ; ..and the buildings either side of it
  (skin {'all facade} (solid (box [-45 8.85 33] [-20 33 47])))
  (skin {'all facade} (solid (box [20 8.85 33] [45 28 47])))
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
