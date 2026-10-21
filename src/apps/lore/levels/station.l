; `love play src/apps/lore/levels/station.l`, and `love play edit` the same
(borrow 'scenery)

; the textures, their layers listed at the top of src/apps/lore/swatch.l. (tiles n m a b
; grout): square tiles, two a side in n texels m metres across, a and b by turns, in grout
(: (tiles n m a b grout) (: h (n // 2) (texture n n m [['fill a] ['checker h h b] ['noise 5 0.1] ['grid h h 1 grout]])))
; ..(octagons n m a b grout): octagons of a, one in n texels m metres across, and between
; their corners small squares of b, in grout
(: (octagons n m a b grout) (: N (1.0 * n) c (0.29 * N) g 1.0 d (c - 1.5)
     (texture n n m [['fill grout]
                     ['poly 0 0 d 0 0 d b] ['poly N 0 N d (N - d) 0 b] ['poly 0 N 0 (N - d) d N b] ['poly N N (N - d) N N (N - d) b]
                     ['poly c g (N - c) g (N - g) c (N - g) (N - c) (N - c) (N - g) c (N - g) g (N - c) g c a]
                     ['noise 5 0.1]])))
; ..the floor: light octagons half a metre across, dark squares between
(: hallfloor (octagons 32 0.5 '(rgb 0.34 0.34 0.36) '(rgb 0.3 0.31 0.33) 0.12))
; ..and the door: brushed steel in plates, a seam down the middle, a hazard band at its foot
(: steel (texture 64 128 1
          '((fill (rgb 0.5 0.52 0.56))
            (noise 30 0.77 0.08)
            (cols 30 34 0.2)
            (grid 0 32 1 0.25)
            (within 0 112 64 128
              (fill 0.08)
              (stripes 16 8 -1 (rgb 0.85 0.65 0.08))))))

;; ..the track: two rails on sleepers over ballast, along x, either side of the car's middle
; at z -5.94, the tile 4 m across z
(: rails (texture 32 128 1
           '((fill (rgb 0.2 0.19 0.18)) (noise 2 0.45)
             (within 0 26 32 106 (cols 4 12 (rgb 0.24 0.18 0.13)) (cols 20 28 (rgb 0.24 0.18 0.13)) (noise 3 1 0.3))
             (rows 41 45 (rgb 0.32 0.33 0.35)) (rows 87 91 (rgb 0.32 0.33 0.35))
             (rows 42 44 (rgb 0.62 0.63 0.66)) (rows 88 90 (rgb 0.62 0.63 0.66)))))
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
; ..the road: steel plates, studded, in dark seams
(: roadmetal (texture 64 64 2
              '((fill (rgb 0.3 0.31 0.33)) (noise 20 0.6 0.08)
                (dots 8 8 1.2 (shade 1.3))
                (patches 9 0.25 (shade 0.82))
                (grid 32 32 1 (rgb 0.1 0.1 0.11)))))
(: kerb (texture 32 32 1 '((fill (rgb 0.36 0.36 0.36)) (noise 4 0.1) (grid 32 0 1 0.4))))
; ..the office: poured concrete, its storeys four and a half metres with a band of
; narrow windows, and the buttresses bare
(: unnwall (texture 64 64 4.5
            '((fill (rgb 0.34 0.33 0.32)) (noise 3 0.05) (patches 3 0.18 (shade 0.88))
              (rows 0 2 (rgb 0.2 0.2 0.21))
              (within 0 22 64 46
                (fill (rgb 0.04 0.06 0.09)) (noise 5 0.12) (patches 6 0.12 (rgb 0.4 0.75 1.0))
                (cols 0 3 (rgb 0.27 0.27 0.28)) (cols 15 17 (rgb 0.27 0.27 0.28))
                (cols 31 34 (rgb 0.27 0.27 0.28)) (cols 47 49 (rgb 0.27 0.27 0.28)) (cols 62 64 (rgb 0.27 0.27 0.28))))))
; ..poured concrete, smooth, stained broadly, a pour's line every three metres and the
; form ties' holes in rows between
(: concrete (texture 128 128 6
             '((fill (rgb 0.34 0.33 0.32)) (noise 6 0.05) (patches 6 0.18 (shade 0.88))
               (rows 0 1 (shade 0.88)) (rows 64 65 (shade 0.88)) (dots 42.667 16 0.8 (shade 0.6)))))
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
; ..the street sweeper: yellow paint scuffed, a dark cab, the drums' worn
; steel, and caution bars; the garage it came out of, ribbed, a bar of the same at its top
; and its foot
(: sweepyellow (texture 32 32 1.5 '((fill (rgb 0.86 0.64 0.06)) (noise 6 0.18) (patches 4 0.2 (shade 0.6)) (grid 32 0 1 (shade 0.5)))))
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
;; ..heaped flowers, drifted like snow, the blooms close as a carpet
(: heapwarm (texture 64 64 0.9
           '((fill (rgb 0.1 0.24 0.08)) (noise 3 0.4) (dots 4 5 1.5 (rgb 0.16 0.38 0.12))
             (disc 8.6 54.2 3.2 (rgb 0.82 0.07 0.1)) (disc 7.5 48.7 2.8 (rgb 0.95 0.55 0.7)) (disc 50.5 6.0 2.0 (rgb 0.95 0.55 0.7)) (disc 27.7 48.8 2.0 (rgb 0.95 0.55 0.7)) (disc 17.0 51.3 2.9 (grey 0.95)) (disc 57.7 2.0 2.0 (rgb 1 0.86 0.25)) (disc 57.7 66.0 2.0 (rgb 1 0.86 0.25)) (disc 0.6 56.4 3.1 (rgb 0.95 0.55 0.7)) (disc 64.6 56.4 3.1 (rgb 0.95 0.55 0.7)) (disc 46.5 33.8 3.2 (rgb 0.95 0.55 0.7)) (disc 35.4 22.1 3.1 (rgb 0.95 0.55 0.7)) (disc 60.9 59.3 2.7 (rgb 1 0.86 0.25)) (disc 59.0 6.4 3.0 (rgb 0.82 0.07 0.1)) (disc 7.7 21.3 3.2 (rgb 1 0.86 0.25)) (disc 59.9 27.0 3.3 (rgb 0.82 0.07 0.1)) (disc 19.4 37.6 3.4 (rgb 1 0.86 0.25)) (disc 25.2 54.6 2.8 (rgb 0.95 0.55 0.7)) (disc 26.5 11.1 2.9 (rgb 0.55 0.03 0.06)) (disc 5.5 42.5 2.2 (rgb 1 0.95 0.75)) (disc 33.3 25.2 2.8 (grey 0.95)) (disc 30.0 19.7 3.4 (rgb 1 0.55 0.15)) (disc 38.0 25.2 2.3 (rgb 1 0.86 0.25)) (disc 14.5 0.8 2.3 (rgb 1 0.86 0.25)) (disc 14.5 64.8 2.3 (rgb 1 0.86 0.25)) (disc 14.9 32.9 3.5 (rgb 1 0.55 0.15)) (disc 22.6 58.2 3.1 (rgb 1 0.55 0.15)) (disc -2.7 0.4 3.3 (rgb 1 0.86 0.25)) (disc -2.7 64.4 3.3 (rgb 1 0.86 0.25)) (disc 61.3 0.4 3.3 (rgb 1 0.86 0.25)) (disc 61.3 64.4 3.3 (rgb 1 0.86 0.25)) (disc 51.8 33.2 2.9 (rgb 0.95 0.55 0.7)) (disc 60.8 30.8 2.6 (rgb 1 0.86 0.25)) (disc 22.8 22.1 2.9 (rgb 1 0.55 0.15)) (disc 50.3 21.2 3.0 (rgb 0.82 0.07 0.1)) (disc 40.7 35.2 2.3 (grey 0.95)) (disc 51.1 51.0 3.3 (rgb 0.82 0.07 0.1)) (disc 2.1 60.4 2.1 (grey 0.95)) (disc 66.1 60.4 2.1 (grey 0.95)) (disc 18.6 10.7 2.4 (rgb 1 0.95 0.75)) (disc 42.0 41.5 2.5 (rgb 0.55 0.03 0.06)) (disc 31.8 7.3 2.5 (rgb 0.55 0.03 0.06)) (disc 57.6 32.6 2.3 (rgb 1 0.55 0.15)) (disc 27.6 -1.6 2.4 (rgb 0.95 0.55 0.7)) (disc 27.6 62.4 2.4 (rgb 0.95 0.55 0.7)) (disc 9.4 46.0 2.3 (rgb 1 0.86 0.25)) (disc -1.6 51.1 2.8 (rgb 0.82 0.07 0.1)) (disc 62.4 51.1 2.8 (rgb 0.82 0.07 0.1)) (disc 33.5 2.0 3.1 (rgb 0.55 0.03 0.06)) (disc 33.5 66.0 3.1 (rgb 0.55 0.03 0.06)) (disc 42.2 27.3 3.2 (rgb 1 0.95 0.75)) (disc 54.9 19.9 3.5 (rgb 1 0.95 0.75)) (disc 26.6 16.2 2.0 (grey 0.95)) (disc 37.8 13.9 3.4 (rgb 0.95 0.55 0.7)) (disc 22.2 13.2 3.1 (rgb 0.95 0.55 0.7)) (disc 37.9 31.5 3.5 (rgb 0.95 0.55 0.7)) (disc 18.9 32.0 2.5 (rgb 0.95 0.55 0.7)) (disc 21.0 -0.8 3.3 (rgb 0.55 0.03 0.06)) (disc 21.0 63.2 3.3 (rgb 0.55 0.03 0.06)) (disc 24.3 35.0 3.5 (rgb 1 0.86 0.25)) (disc 31.0 -0.9 2.4 (grey 0.95)) (disc 31.0 63.1 2.4 (grey 0.95)) (disc 5.4 10.9 3.5 (rgb 0.82 0.07 0.1)) (disc 17.2 21.3 2.8 (rgb 0.82 0.07 0.1)) (disc 55.5 38.7 3.5 (rgb 0.95 0.55 0.7)) (disc 8.7 35.3 2.2 (grey 0.95)) (disc 9.4 8.0 2.2 (rgb 1 0.55 0.15)) (disc 14.3 5.2 2.4 (rgb 0.82 0.07 0.1)) (disc 36.1 59.2 2.7 (rgb 0.82 0.07 0.1)) (disc 6.9 2.9 2.5 (rgb 1 0.55 0.15)) (disc 42.9 5.9 2.2 (grey 0.95)) (disc 12.0 50.3 2.9 (rgb 1 0.95 0.75)) (disc 18.8 16.2 2.8 (grey 0.95)) (disc 13.3 20.3 2.0 (rgb 0.82 0.07 0.1)) (disc 46.5 20.5 2.6 (rgb 0.95 0.55 0.7)) (disc 39.5 -1.3 2.9 (rgb 0.95 0.55 0.7)) (disc 39.5 62.7 2.9 (rgb 0.95 0.55 0.7)) (disc 42.4 16.6 2.9 (rgb 0.82 0.07 0.1)) (disc 50.7 37.1 3.5 (rgb 0.82 0.07 0.1)) (disc 55.2 9.9 2.8 (rgb 0.55 0.03 0.06)) (disc 4.9 60.8 2.3 (rgb 1 0.95 0.75)) (disc 18.8 57.2 2.2 (grey 0.95)) (disc -0.8 13.1 2.5 (rgb 1 0.86 0.25)) (disc 63.2 13.1 2.5 (rgb 1 0.86 0.25)) (disc 54.5 29.0 2.6 (rgb 0.55 0.03 0.06)) (disc 11.0 31.1 3.3 (rgb 0.95 0.55 0.7)) (disc 37.1 38.0 2.2 (rgb 0.82 0.07 0.1)) (disc 25.5 25.7 3.0 (rgb 0.82 0.07 0.1)) (disc 31.1 11.4 2.5 (rgb 0.95 0.55 0.7)) (disc 59.5 40.9 2.4 (rgb 0.55 0.03 0.06)) (disc 31.7 30.6 2.4 (rgb 0.95 0.55 0.7)) (disc 59.0 48.8 3.0 (rgb 0.55 0.03 0.06)) (disc 20.0 44.3 3.4 (rgb 0.55 0.03 0.06)) (disc 5.8 16.3 2.2 (grey 0.95)) (disc 58.2 61.4 2.2 (rgb 1 0.55 0.15)) (disc 26.9 7.8 2.3 (rgb 0.95 0.55 0.7)) (disc 1.5 36.4 2.0 (rgb 0.82 0.07 0.1)) (disc 65.5 36.4 2.0 (rgb 0.82 0.07 0.1)) (disc 50.1 43.7 2.8 (rgb 0.95 0.55 0.7)) (disc 40.7 46.2 3.2 (rgb 1 0.86 0.25)) (disc 12.7 59.1 3.0 (rgb 1 0.86 0.25)) (disc 47.7 41.0 3.0 (grey 0.95)) (disc 26.0 40.3 3.0 (rgb 0.95 0.55 0.7)) (disc 34.8 9.7 3.3 (rgb 0.95 0.55 0.7)) (disc 6.3 37.8 2.1 (grey 0.95)) (disc 42.0 1.3 2.8 (rgb 1 0.95 0.75)) (disc 42.0 65.3 2.8 (rgb 1 0.95 0.75)) (disc 32.7 47.2 2.3 (rgb 1 0.86 0.25)) (disc -2.3 45.2 3.4 (grey 0.95)) (disc 61.7 45.2 3.4 (grey 0.95)) (disc 54.5 55.6 2.6 (rgb 0.95 0.55 0.7)) (disc 59.7 15.9 2.4 (grey 0.95)) (disc 28.4 58.4 3.2 (rgb 1 0.55 0.15)) (disc 49.8 57.2 2.7 (rgb 0.82 0.07 0.1)) (disc 48.1 15.4 3.1 (rgb 0.82 0.07 0.1)) (disc 51.8 1.5 3.2 (grey 0.95)) (disc 51.8 65.5 3.2 (grey 0.95)) (disc 14.2 14.9 2.7 (rgb 1 0.95 0.75)) (disc 50.0 27.7 2.3 (rgb 0.95 0.55 0.7)) (disc 54.1 42.4 2.6 (rgb 0.82 0.07 0.1)) (disc 58.8 54.7 3.4 (grey 0.95)) (disc 40.8 58.4 2.8 (rgb 1 0.86 0.25)) (disc 34.0 28.4 2.2 (rgb 0.95 0.55 0.7)) (disc 16.7 24.3 2.2 (rgb 0.82 0.07 0.1)) (disc 35.8 54.0 2.9 (rgb 1 0.86 0.25)) (disc 41.7 20.1 2.5 (rgb 0.55 0.03 0.06)) (disc 0.6 7.8 2.5 (rgb 0.55 0.03 0.06)) (disc 64.6 7.8 2.5 (rgb 0.55 0.03 0.06)) (disc 47.5 24.4 3.4 (grey 0.95)) (disc 33.5 36.8 3.6 (rgb 0.82 0.07 0.1)) (disc 45.0 47.8 2.6 (rgb 0.55 0.03 0.06)) (disc 25.8 29.7 3.6 (rgb 1 0.86 0.25)) (disc 14.2 8.5 2.2 (rgb 0.95 0.55 0.7)) (disc 13.9 53.6 2.8 (rgb 0.95 0.55 0.7)) (disc 1.4 23.6 3.4 (rgb 0.82 0.07 0.1)) (disc 65.4 23.6 3.4 (rgb 0.82 0.07 0.1)) (disc -0.4 18.1 2.7 (rgb 1 0.86 0.25)) (disc 63.6 18.1 2.7 (rgb 1 0.86 0.25)) (disc 35.2 -1.5 2.3 (grey 0.95)) (disc 35.2 62.5 2.3 (grey 0.95)) (disc 29.7 50.9 2.6 (rgb 0.95 0.55 0.7)) (disc 46.7 6.6 2.2 (grey 0.95)) (disc 32.5 57.9 2.2 (rgb 0.95 0.55 0.7)) (disc 48.6 53.9 2.4 (rgb 0.82 0.07 0.1)) (disc 48.7 -0.7 2.3 (rgb 1 0.55 0.15)) (disc 48.7 63.3 2.3 (rgb 1 0.55 0.15)) (disc 9.0 16.4 2.1 (rgb 1 0.86 0.25)) (disc 14.1 47.6 2.4 (rgb 0.55 0.03 0.06)) (disc 22.2 5.9 3.6 (rgb 0.82 0.07 0.1)) (disc 3.5 32.5 2.3 (rgb 0.82 0.07 0.1)) (disc 43.3 52.9 2.8 (rgb 0.55 0.03 0.06)) (disc 23.4 18.7 2.2 (rgb 0.95 0.55 0.7)) (disc 47.8 60.3 2.2 (grey 0.95)) (disc 45.1 0.0 2.1 (grey 0.95)) (disc 45.1 64.0 2.1 (grey 0.95))
             (noise 2 0.25) (patches 5 0.25 (shade 0.75)))))
(: heappale (texture 64 64 0.9
           '((fill (rgb 0.1 0.24 0.08)) (noise 3 0.4) (dots 4 5 1.5 (rgb 0.16 0.38 0.12))
             (disc 61.2 60.7 2.1 (grey 0.95)) (disc 23.1 10.8 3.3 (rgb 1 0.86 0.25)) (disc 16.1 13.6 2.1 (grey 0.95)) (disc -0.0 40.9 3.3 (rgb 0.95 0.55 0.7)) (disc 64.0 40.9 3.3 (rgb 0.95 0.55 0.7)) (disc 60.8 34.8 2.7 (rgb 1 0.86 0.25)) (disc 57.7 55.7 2.6 (rgb 1 0.86 0.25)) (disc 58.1 27.1 3.4 (grey 0.95)) (disc 35.9 15.1 2.0 (rgb 1 0.86 0.25)) (disc 11.1 32.7 2.6 (rgb 0.95 0.55 0.7)) (disc 43.2 11.6 3.4 (rgb 0.6 0.3 0.85)) (disc 47.0 58.0 3.2 (rgb 0.82 0.07 0.1)) (disc 22.6 -1.2 3.5 (grey 0.95)) (disc 22.6 62.8 3.5 (grey 0.95)) (disc 41.9 16.0 2.4 (rgb 0.6 0.3 0.85)) (disc 32.1 53.2 2.6 (rgb 0.6 0.3 0.85)) (disc 58.9 46.3 2.8 (rgb 1 0.95 0.75)) (disc 60.2 52.1 3.3 (rgb 0.82 0.07 0.1)) (disc 17.2 58.3 2.5 (rgb 0.95 0.55 0.7)) (disc 36.0 32.5 3.0 (rgb 0.6 0.3 0.85)) (disc 20.0 13.3 2.8 (rgb 0.82 0.07 0.1)) (disc 56.5 50.2 2.5 (grey 0.95)) (disc 58.1 12.2 3.2 (grey 0.95)) (disc 36.8 3.1 2.9 (grey 0.95)) (disc 48.3 8.7 2.4 (rgb 1 0.95 0.75)) (disc 60.4 3.9 3.4 (grey 0.95)) (disc 3.6 23.1 2.4 (grey 0.95)) (disc 5.3 61.1 2.0 (grey 0.95)) (disc 47.0 33.5 2.0 (rgb 0.82 0.07 0.1)) (disc 2.8 -0.6 2.2 (grey 0.95)) (disc 2.8 63.4 2.2 (grey 0.95)) (disc 47.9 18.3 2.8 (rgb 1 0.86 0.25)) (disc 28.7 49.0 3.2 (rgb 1 0.86 0.25)) (disc 30.3 14.4 3.1 (rgb 1 0.86 0.25)) (disc 53.7 1.5 3.3 (grey 0.95)) (disc 53.7 65.5 3.3 (grey 0.95)) (disc 33.2 50.0 2.8 (rgb 1 0.86 0.25)) (disc 9.2 61.4 2.4 (rgb 0.82 0.07 0.1)) (disc 8.4 10.9 2.7 (rgb 1 0.95 0.75)) (disc 32.5 -1.1 3.5 (rgb 1 0.95 0.75)) (disc 32.5 62.9 3.5 (rgb 1 0.95 0.75)) (disc 14.9 28.5 2.4 (rgb 0.82 0.07 0.1)) (disc 14.6 50.7 3.0 (rgb 1 0.86 0.25)) (disc 0.3 2.3 2.7 (grey 0.95)) (disc 0.3 66.3 2.7 (grey 0.95)) (disc 64.3 2.3 2.7 (grey 0.95)) (disc 64.3 66.3 2.7 (grey 0.95)) (disc 32.8 5.6 2.2 (grey 0.95)) (disc 11.6 14.8 2.3 (rgb 0.95 0.55 0.7)) (disc 42.8 29.0 2.9 (rgb 0.6 0.3 0.85)) (disc 46.7 27.8 2.8 (rgb 0.82 0.07 0.1)) (disc 37.8 56.4 3.5 (rgb 0.82 0.07 0.1)) (disc 11.6 6.0 3.3 (rgb 1 0.86 0.25)) (disc 23.5 44.2 3.5 (rgb 1 0.86 0.25)) (disc 19.6 53.8 3.1 (grey 0.95)) (disc 29.7 56.9 3.0 (grey 0.95)) (disc 18.2 23.9 3.5 (grey 0.95)) (disc 14.0 31.4 2.2 (rgb 1 0.86 0.25)) (disc 25.1 29.6 3.2 (rgb 0.6 0.3 0.85)) (disc 56.8 16.3 2.2 (rgb 0.82 0.07 0.1)) (disc 54.4 41.0 3.5 (grey 0.95)) (disc 51.5 59.7 3.3 (rgb 1 0.86 0.25)) (disc 35.1 44.5 3.1 (grey 0.95)) (disc 37.5 52.3 2.2 (rgb 1 0.86 0.25)) (disc 43.6 51.8 2.1 (rgb 1 0.86 0.25)) (disc 27.1 21.0 2.4 (rgb 0.95 0.55 0.7)) (disc 50.1 36.7 2.2 (rgb 0.6 0.3 0.85)) (disc 26.4 41.5 2.6 (rgb 0.95 0.55 0.7)) (disc 21.2 47.7 3.1 (rgb 1 0.95 0.75)) (disc 34.1 12.0 3.3 (rgb 0.6 0.3 0.85)) (disc 52.2 49.1 2.3 (rgb 0.82 0.07 0.1)) (disc -1.8 48.7 2.6 (rgb 0.6 0.3 0.85)) (disc 62.2 48.7 2.6 (rgb 0.6 0.3 0.85)) (disc 16.3 40.0 3.3 (grey 0.95)) (disc 3.5 32.0 3.6 (rgb 1 0.86 0.25)) (disc 67.5 32.0 3.6 (rgb 1 0.86 0.25)) (disc 10.0 18.1 2.7 (grey 0.95)) (disc 23.5 34.4 2.6 (rgb 0.6 0.3 0.85)) (disc 13.1 43.3 2.8 (grey 0.95)) (disc 31.0 34.5 3.5 (grey 0.95)) (disc 16.5 20.0 2.5 (rgb 1 0.86 0.25)) (disc 41.8 25.1 3.3 (grey 0.95)) (disc 54.3 9.6 2.8 (grey 0.95)) (disc 7.2 52.4 2.6 (rgb 1 0.86 0.25)) (disc 13.7 22.8 2.5 (rgb 1 0.86 0.25)) (disc 10.7 28.3 2.5 (grey 0.95)) (disc 59.5 20.9 2.2 (rgb 1 0.95 0.75)) (disc 17.2 35.2 2.6 (rgb 1 0.86 0.25)) (disc 40.5 -2.0 3.1 (rgb 0.95 0.55 0.7)) (disc 40.5 62.0 3.1 (rgb 0.95 0.55 0.7)) (disc 39.8 42.9 2.6 (rgb 0.6 0.3 0.85)) (disc 28.2 5.6 3.5 (rgb 1 0.86 0.25)) (disc 61.5 8.1 2.0 (rgb 1 0.86 0.25)) (disc 46.9 41.7 2.0 (rgb 1 0.86 0.25)) (disc 20.2 59.3 2.2 (grey 0.95)) (disc 50.2 21.2 2.2 (rgb 1 0.86 0.25)) (disc 54.1 21.6 3.2 (rgb 0.82 0.07 0.1)) (disc 61.3 14.6 2.1 (rgb 0.6 0.3 0.85)) (disc 39.8 5.8 2.8 (rgb 0.6 0.3 0.85)) (disc 26.4 33.6 2.1 (grey 0.95)) (disc 28.9 37.8 2.2 (rgb 0.95 0.55 0.7)) (disc 12.8 58.8 3.3 (rgb 0.95 0.55 0.7)) (disc 20.1 19.2 2.2 (grey 0.95)) (disc 47.5 45.0 2.8 (grey 0.95)) (disc 44.0 55.6 3.0 (rgb 1 0.95 0.75)) (disc 54.4 33.2 2.1 (rgb 0.6 0.3 0.85)) (disc 42.7 2.2 2.5 (grey 0.95)) (disc 42.7 66.2 2.5 (grey 0.95)) (disc 40.7 47.0 3.5 (grey 0.95)) (disc 50.3 28.7 2.7 (rgb 1 0.86 0.25)) (disc 37.2 28.5 3.2 (rgb 0.82 0.07 0.1)) (disc 21.6 4.5 2.6 (rgb 0.6 0.3 0.85)) (disc 0.8 55.7 2.3 (rgb 1 0.86 0.25)) (disc 64.8 55.7 2.3 (rgb 1 0.86 0.25)) (disc 30.1 45.5 2.5 (rgb 0.82 0.07 0.1)) (disc 58.5 41.3 2.8 (rgb 1 0.95 0.75)) (disc 4.0 42.6 2.2 (rgb 0.82 0.07 0.1)) (disc 46.9 52.8 2.2 (rgb 0.6 0.3 0.85)) (disc 52.3 5.8 3.5 (grey 0.95)) (disc 6.5 35.7 2.1 (grey 0.95)) (disc 22.7 21.8 3.5 (rgb 0.82 0.07 0.1)) (disc 23.0 39.0 2.6 (rgb 1 0.86 0.25)) (disc 25.8 58.2 2.2 (rgb 0.82 0.07 0.1)) (disc 6.6 44.3 2.1 (rgb 1 0.86 0.25)) (disc -0.2 58.9 2.7 (grey 0.95)) (disc 63.8 58.9 2.7 (grey 0.95)) (disc 52.6 55.6 2.7 (rgb 0.6 0.3 0.85)) (disc 40.8 36.5 2.4 (rgb 0.6 0.3 0.85)) (disc 33.4 39.6 3.5 (rgb 1 0.95 0.75)) (disc 38.3 40.0 2.7 (rgb 0.6 0.3 0.85)) (disc 45.7 -1.9 2.4 (rgb 1 0.86 0.25)) (disc 45.7 62.1 2.4 (rgb 1 0.86 0.25)) (disc 11.4 53.3 2.5 (grey 0.95)) (disc 41.7 39.3 2.0 (rgb 0.6 0.3 0.85)) (disc 39.2 10.6 2.5 (rgb 0.6 0.3 0.85)) (disc 46.2 14.4 2.9 (rgb 1 0.95 0.75)) (disc 25.5 17.0 2.3 (grey 0.95)) (disc 23.0 7.4 2.1 (rgb 1 0.86 0.25)) (disc 29.1 61.5 2.1 (grey 0.95)) (disc 5.0 58.3 2.3 (rgb 1 0.86 0.25)) (disc 19.2 27.3 2.0 (rgb 0.6 0.3 0.85)) (disc 0.1 6.1 2.1 (rgb 0.6 0.3 0.85)) (disc 64.1 6.1 2.1 (rgb 0.6 0.3 0.85)) (disc 17.0 16.4 2.4 (rgb 0.95 0.55 0.7)) (disc 17.8 -2.2 2.6 (grey 0.95)) (disc 17.8 61.8 2.6 (grey 0.95)) (disc 57.5 35.0 2.5 (grey 0.95))
             (noise 2 0.25) (patches 5 0.25 (shade 0.75)))))
; ..a drift of them: a sheet over x a to b and z c to d, a point every e, (hf x z) above the
; ground (fl x z h), and none past where hf has sunk well under it
(: (drift t a b c d e hf fl)
   (: nx (int (floor ((b - a) / e + 0.5))) nz (int (floor ((d - c) / e + 0.5)))
      (pt x z) (: h (hf x z) (h < -0.2 ? () [x (fl x z h + h - 0.06) z]))
      (drape t (map (j \ (: z (c + (d - c) * j / nz) (map (i \ pt (a + (b - a) * i / nx) z) ^(nx + 1)))) ^(nz + 1)))))
(: (sm v) (: u (max 0.0 (min 1.0 v)) (u * u * (3.0 - 2.0 * u))))
; ..a heap h high against a wall, out d from it reaching r, and sinking under past r
(: (heap h r d) (: s (max 0.0 d / r) (h * (1.0 - s ** 1.6) - 0.25 * s)))
; ..the higher of two heaps, rounded where they meet as a drift fills a corner
(: (smax a b) (0.5 * (a + b + sqrt ((a - b) * (a - b) + 0.5))))
; ..lumps on a heap, more the deeper it is
(: (lumpy h x z) (h + sm (h / 0.5) * (0.2 * sin (3.1 * x + 1.7 * z) * sin (2.3 * z - 1.3 * x + 0.7)
                                      + 0.1 * sin (7.3 * x + 0.4) * sin (6.1 * z + 1.9))))
; ..bouquets and wreaths stood in a drift, n tried by seed sd over its x a to b and z c to
; d; each bouquet a picture turned roughly to the street, leaning by s, each wreath leant
; back into the heap
(: (rnd i) (: v (sin (i * 12.9898 + 78.233) * 43758.5453) (v - floor v)))
(: blooms [posies lilies roses])
(: (strew x y z s sd) (: t (rnd (sd + 0.61)) b (blooms (int (floor (2.99 * rnd (sd + 0.29)))))
   (? (t < 0.12) [(decal [x (y + 0.4) z] [0 0.45 -0.89] [0 0.89 0.45] 0.95 0.95 wreath)]
      [(decal [x (y + 0.24) z] [(rnd (sd + 0.53) - 0.5 + s) 0 -1] [0 1 0] 0.42 0.48 b)])))
(: (plant n sd a b c d hf fl)
   (cats (map (i \ (: x (a + (b - a) * rnd (sd + i)) z (c + (d - c) * rnd (sd + i + 0.37)) h (hf x z)
                      (h < 0.15 ? () (strew x (fl x z h + h - 0.22) z (0.0 - 0.15 * x) (sd + i))))) ^n)))
; ..the office's ground: the pavement, the steps up from it, the landing, and over the
; steps under a deep drift their nosings' slope; the bays' floor, its sunken foot
(: (stepy x z) (? (z < 28.6) 9.0 (min 9.6 (9.15 + 0.15 * floor ((z - 28.6) / 0.5)))))
(: (stairg x z h) (: g (stepy x z) r (min 9.6 (max 9.0 (9.0 + 0.3 * (z - 28.1)))) (g + sm (h / 0.3) * (r - g))))
(: (bayg x z h) (z < 33 ? 9.0 8.85))
; ..the heaps: either side of the doors high on the wall, less before them, up the steps'
; sides, and none round the candles; in a bay against its back and its buttresses; in an
; outer bay the same, gone toward its open end at x o
(: (stairh x z) (: ax (abs x) k (sm ((ax - 1.3) / 0.6))
   wall (heap (1.4 + 1.2 * k) (2.2 + 1.2 * k) (36.9 - z)) side (heap (2.0 * sm ((z - 29.0) / 2.2)) 1.9 (3.2 - ax))
   cl (sm ((sqrt (x * x + (z - 33.3) * (z - 33.3)) - 0.95) / 0.75))
   (lumpy ((smax wall side + 0.25) * cl - 0.25) x z)))
(: (bayh a b) (\ x z (lumpy (smax (heap 2.4 3.4 (35.0 - z)) (heap (1.8 * sm ((z - 29.4) / 2.4)) 1.8 (min (x - a) (b - x)))) x z)))
(: (outh w o) (\ x z (: h (smax (heap 2.2 3.0 (35.0 - z)) (heap (1.6 * sm ((z - 29.4) / 2.4)) 1.6 (abs (x - w))))
                       (lumpy ((h + 0.25) * sm ((abs (o - w) - abs (x - w) + 0.2) / 1.2) - 0.25) x z))))
; ..a wreath on its easel: two dark legs and a bar
(: (easel x y z) [(decal [x (y + 1.25) z] [0 0 -1] [0 1 0] 1.15 1.15 wreath)
                  (whole (skin {'all darkmetal} (solid (box [(x - 0.42) y (z + 0.02)] [(x - 0.38) (y + 1.5) (z + 0.06)]))))
                  (whole (skin {'all darkmetal} (solid (box [(x + 0.38) y (z + 0.02)] [(x + 0.42) (y + 1.5) (z + 0.06)]))))
                  (whole (skin {'all darkmetal} (solid (box [(x - 0.42) (y + 0.6) (z + 0.02)] [(x + 0.42) (y + 0.64) (z + 0.06)]))))])
;; the block across from the shop: its windows' dark glass
(: darkpane (texture 16 16 1.6 '((fill (rgb 0.02 0.025 0.035)) (noise 4 0.35) (cols 0 1 (grey 0.1)) (rows 0 1 (grey 0.1)))))
; ..a window 1.6 wide and 1.8 tall sunk half a metre into its south face at x, or its east
; face at z, its sill at y
(: (slot c y ax) (? (ax = 'z) [(skin {'all concrete} (air (box [(c - 1.9) y 32.9] [(c + 1.9) (y + 2) 34])))
                               (decal [c (y + 1) 33.99] [0 0 -1] [0 1 0] 3.8 2 darkpane)]
                    [(skin {'all concrete} (air (box [-34 y (c - 1.9)] [-32.9 (y + 2) (c + 1.9)])))
                     (decal [-33.99 (y + 1) c] [1 0 0] [0 1 0] 3.8 2 darkpane)]))
;; ..the grav shafts: walls of dark cabling bound in clamps, a plate floor and ceiling,
; and on each a steel ring round a triangle of three glowing blue lamps
(: cabling (texture 64 64 1.2
            '((fill (rgb 0.04 0.04 0.05))
              (cols 2 7 (rgb 0.1 0.1 0.12)) (cols 9 12 (rgb 0.07 0.08 0.1)) (cols 14 20 (rgb 0.12 0.12 0.13))
              (cols 23 26 (rgb 0.05 0.08 0.13)) (cols 28 34 (rgb 0.1 0.1 0.11)) (cols 37 40 (rgb 0.13 0.06 0.05))
              (cols 42 48 (rgb 0.11 0.11 0.12)) (cols 51 54 (rgb 0.08 0.08 0.1)) (cols 56 62 (rgb 0.12 0.12 0.14))
              (cols 4 5 (shade 1.6)) (cols 16 17 (shade 1.6)) (cols 30 31 (shade 1.6)) (cols 44 45 (shade 1.6)) (cols 58 59 (shade 1.6))
              (noise 2 12 0.3)
              (rows 28 34 (rgb 0.2 0.2 0.22)) (rows 28 29 (rgb 0.3 0.3 0.33)) (rows 33 34 0.08))))
(: shaftplate (texture 32 32 1 '((fill (rgb 0.15 0.16 0.18)) (noise 4 0.2) (grid 32 32 1 0.07))))
(: gravring (texture 64 64 1.6 '((fill hole) (disc 32 32 31 (rgb 0.55 0.58 0.63)) (disc 32 32 27 (rgb 0.3 0.32 0.36)) (noise 6 0.15))))
(: gravlamps (texture 64 64 1.6
              '((fill hole)
                (disc 32 18 8 (rgb 0.25 0.6 1)) (disc 20 39 8 (rgb 0.25 0.6 1)) (disc 44 39 8 (rgb 0.25 0.6 1))
                (disc 32 18 4 (rgb 0.75 0.95 1)) (disc 20 39 4 (rgb 0.75 0.95 1)) (disc 44 39 4 (rgb 0.75 0.95 1)))))
(: (shaft x) [(skin {'walls cabling 'floor shaftplate 'ceiling shaftplate} (room [(x - 1) -5 16.3] [(x + 1) 12 18.3]))
              (decal [x -4.99 17.3] [0 1 0] [0 0 1] 1.6 1.6 gravring) (ad [x -4.98 17.3] [0 1 0] [0 0 1] 1.6 1.6 gravlamps)
              (decal [x 11.99 17.3] [0 -1 0] [0 0 1] 1.6 1.6 gravring) (ad [x 11.98 17.3] [0 -1 0] [0 0 1] 1.6 1.6 gravlamps)
              (window [(x - 0.8) -0.9 15.9] [(x + 0.8) 0.8 16.4] glass)])
; ..the station's lamps: steel fittings, three-sided, on the walls
(: sconcemetal (texture 16 16 0.5 '((fill (rgb 0.42 0.43 0.45)) (noise 4 0.15))))
(: (lamp at n d) (sconce at n d 1.4 sconcemetal))
; ..the sweeper's roller about x, r round, an octagon across the road's way
(: (roller x r) (: a (x - r) b (x + r) y0 8.85 y1 (8.85 + 2.0 * r) k (0.586 * r) p 23.2 q 26.8
   (whole (skin {'all drumsteel}
           (cut [(a + k) y0 p] [a (y0 + k) p] [(a + k) y0 q] (cut [a (y1 - k) p] [(a + k) y1 p] [a (y1 - k) q]
            (cut [b (y0 + k) p] [(b - k) y0 p] [b (y0 + k) q] (cut [(b - k) y1 p] [b (y1 - k) p] [(b - k) y1 q]
             (solid (box [a y0 p] [b y1 q]))))))))))
; ..an office beam level over the street, its end cut to a wedge
(: (beam x) (skin {'all concrete}
             (cut [(x + 1.3) 22.6 22.5] [(x - 1.3) 22.6 22.5] [x 21.6 21]
               (cut [(x - 1.3) 20.6 22.5] [(x + 1.3) 20.6 22.5] [x 21.6 21]
                 (solid (box [(x - 1.3) 20.6 21] [(x + 1.3) 22.6 30.5]))))))

; ..a block between two corners, its upright edges at each corner [x z] in cs cut 0.3 off
(: (block lo hi cs) (: mx (0.5 * (lo 0 + hi 0)) mz (0.5 * (lo 2 + hi 2)) c 0.3
     (foldl (\ b q (: x (q 0) z (q 1) sx (mx > x ? 1.0 -1.0) sz (mz > z ? 1.0 -1.0)
                    (cut [(x + sx * c) (lo 1) z] [x (lo 1) (z + sz * c)] [(x + sx * c) (hi 1) z] b)))
            (solid (box lo hi)) cs)))

(level "the station"
  (textures {'wall concrete 'floor hallfloor 'ceiling concrete 'door steel 'train carbody})
  ; the start inside the car, facing its door
  (start [0 -5 -5.9] 0 0)
  ; a dim light everywhere, the lamps' thrown back off the concrete
  (ambient (rgb 0.15 0.15 0.16))
  ; the hall, 38 metres across, ten high and 16 long
  (room [-19 -5 0] [19 5 16])
  ; the platform, its floor a grate, its ends in line with the hallways' outer walls, and
  ; the track a metre below it running on into the tunnels, under the car's floor, cabling
  ; on the walls up to the platform
  (skin {'floor grate} (room [-11 -5 -4.52] [11 2 0]))
  (skin {'walls cabling 'floor rails} (room [-70 -6 -7.6] [70 -5 -4.52]))
  (room [-11 -5 -7.6] [11 2 -4.52])
  (room [-70 -5 -7.6] [70 -2 -4.52])
  ; solid blocks standing in from the side walls, mirrored about x 0, their corners out in
  ; the air chamfered; the hallway between them and each wing's chamber south open onto
  ; the platform
  (mirror-x 0
   [(block [-19 -5 0] [-11 5 4] [[-11 4]])
    (block [-7 -5 0] [-3 5 4] [[-7 0] [-3 0] [-7 4] [-3 4]])
    (block [-15 -5 8] [-11 5 10] [[-15 8] [-11 8]])
    (block [-7 -5 8] [-3 5 10] [[-7 8] [-3 8]])
    (solid (box [-19 -5 16] [-3 5 10]))
    ; ..the lamps, each looking along its wall, some across, some up or down it
    (lamp [-3 -2.2 2] [1 0 0] [0 0 1])
    (lamp [-3 -2.2 9] [1 0 0] [0 0 -1])
    (lamp [-11 -2.2 2] [1 0 0] [0 0 1])
    (lamp [-19 0.5 7] [1 0 0] [0 1 0])
    (lamp [-3 1.5 13] [1 0 0] [0 -1 0])
    (lamp [-11 -2.5 -2.3] [1 0 0] [0 0 1])
    (lamp [-5 -2.5 0] [0 0 -1] [-1 0 0])
    ; ..the railing along the platform's edge, open across the car's door: a plinth, posts
    ; and a rail
    (solid (box [-11 -5 -4.52] [-1 -4.6 -4.36]))
    (repeat 8 [-1.41 0 0] [(solid (box [-1.06 -4.6 -4.47] [-1 -4.0 -4.41]))])
    (solid (box [-11 -4.0 -4.48] [-1 -3.94 -4.4]))])
  ; the car at the platform, its door on the hallway, a hand clear of the edge; it leaves west
  (train [-9 -5 -7.24] [9 -2.7 -4.64] (door [0 -5 -4.64] 1.4 2.0) -55)
  ; the street over the hall, under a smoggy dusk's broken cloud: a narrow pavement on the
  ; station's side, a narrow steel road, and off it north by the shop a short street that
  ; ends at a blank wall
  (sky 18.35 'mostly)
  (smog 0.9)
  (skin {'floor roadmetal 'walls facade} (street [-45 8.85 14] [45 45 47]))
  (skin {'all paving} (solid (box [-45 8.85 14] [45 9 22])))
  (skin {'all paving} (solid (box [-45 8.85 28] [-31 9 33])))
  (skin {'all paving} (solid (box [-33 8.85 33] [-31 9 47])))
  (skin {'all paving} (solid (box [-20 8.85 28] [45 9 33])))
  (skin {'all paving} (solid (box [-20 8.85 33] [-18 9 47])))
  (skin {'all concrete} (solid (box [-33 8.85 46.6] [-18 33 47])))
  (skin {'all kerb} (solid (box [-45 8.85 21.8] [45 9 22])))
  (skin {'all kerb} (solid (box [-45 8.85 28] [-31 9 28.2])))
  (skin {'all kerb} (solid (box [-20 8.85 28] [45 9 28.2])))
  (skin {'all kerb} (solid (box [-31.2 8.85 28.2] [-31 9 47])))
  (skin {'all kerb} (solid (box [-20 8.85 28.2] [-19.8 9 47])))
  ; ..across it from the office a great column, the third of its beams reaching over to it,
  ; and either side of the column a wing, upright at the pavement, rising, then level to
  ; meet it, the pavement going on round behind them; the shafts come up in the west wing,
  ; a doorway north from each, its top chamfered; the east an arch to walk under, its leg
  ; near eye high to pull up onto, a slope up from it to walk, and a level top
  (skin {'all concrete} (solid (box [3 9 15.8] [6 26 19.5])))
  (skin {'all concrete} (cut [-5.5 12.4 19] [-5.5 12.4 15.8] [-4.7 13.2 15.8] (solid (box [-5.5 9 15.8] [3 13.2 19]))))
  (skin {'all concrete} (cut [12 10.4 16] [12 10.4 19.3] [8 13.2 16] (cut [11 9 16] [11 9 19.3] [6 12.3 16] (solid (box [6 9 16] [12 13.2 19.3])))))
  ; ..the station's sign on the wing, a room of the street's air before it to hang it on
  (skin {'all concrete} (room [-5.5 9 19] [3 13 19.6]))
  (buzz (sign [-0.0 12.2 19] 0.5 "STATION" (rgb 0.3 0.75 1)))
  (bin [-7.5 9 20.4] 0.55 0.55 0.95 binmetal binsign)
  (bin [8.5 9 20.4] 0.55 0.55 0.95 binmetal binsign)
  ; ..and a basketball someone left out on top of the arch
  (ball [7 13.2 17.65])
  ; the way out north: two grav shafts behind the hall's north wall; facing them, up on the
  ; right and down on the left, each a doorway at its foot and one at its head out of the
  ; wing, a window a metre and a half over each doorway into its glow
  (grav [0.7 -5 16.3] [2.7 9 18.3] 'up)
  (grav [-2.7 -5 16.3] [-0.7 9 18.3] 'down)
  (shaft 1.7) (shaft -1.7)
  (air (box [0.9 -5 15.9] [2.5 -2.4 16.4]))
  (air (box [-2.5 -5 15.9] [-0.9 -2.4 16.4]))
  (skin {'all concrete} (air (box [0.9 9 18.2] [2.5 11.6 19.1])))
  (skin {'all concrete} (air (box [-2.5 9 18.2] [-0.9 11.6 19.1])))
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
  ; headlights on: a big four-by-four's body, its hood sloping to the nose, a raked
  ; windscreen and a cabin narrowing to its roof, all yellow, on a steel roller each end
  (roller -35.5 0.75) (roller -39.2 0.75)
  (whole (skin {'all sweepyellow}
          (cut [-34.4 11 23.275] [-35.6 11.3 23.275] [-34.4 11 26.725]
           (cut [-40.2 11 23.275] [-40.2 11 26.725] [-39.9 11.3 23.275]
            (cut [-34.4 9 23.725] [-34.75 9 23.275] [-34.4 12 23.725]
             (cut [-34.75 9 26.725] [-34.4 9 26.275] [-34.75 12 26.725]
              (solid (box [-40.2 9.9 23.275] [-34.4 11.3 26.725]))))))))
  (whole (skin {'all sweepyellow}
          (cut [-35.55 11.3 23.5] [-36.35 12.4 23.5] [-35.55 11.3 26.5]
           (cut [-40.1 11.3 23.5] [-40.1 11.3 26.5] [-39.8 12.4 23.5]
            (cut [-36 11.3 23.425] [-40 11.3 23.425] [-36 12.4 23.675]
             (cut [-36 11.3 26.575] [-40 11.3 26.575] [-36 12.4 26.325]
              (solid (box [-40.1 11.25 23.425] [-35.5 12.4 26.575]))))))))
  (whole (skin {'all sweepyellow} (solid (box [-34.4 9.95 23.2] [-34.22 10.25 26.8]))))
  (whole (skin {'all sweepyellow} (solid (box [-38.2 12.4 24.775] [-37.8 12.55 25.225]))))
  (decal [-34.21 10.1 25] [1 0 0] [0 1 0] 3.6 0.27 hazard)
  (decal [-34.39 10.48 25] [1 0 0] [0 1 0] 1.95 0.45 grille)
  (decal [-35.94 11.857 25] [0.809 0.588 0] [-0.588 0.809 0] 2.6 1.05 cabglass)
  (decal [-39.948 11.903 25] [-0.965 0.263 0] [0.263 0.965 0] 2.3 0.7 cabglass)
  (decal [-37.03 11.853 23.538] [0 0.222 -0.975] [0 0.975 0.222] 0.85 0.7 cabglass)
  (decal [-38.7 11.853 23.538] [0 0.222 -0.975] [0 0.975 0.222] 2 0.7 cabglass)
  (decal [-37.03 11.853 26.462] [0 0.222 0.975] [0 0.975 -0.222] 0.85 0.7 cabglass)
  (decal [-38.7 11.853 26.462] [0 0.222 0.975] [0 0.975 -0.222] 2 0.7 cabglass)
  (decal [-37.3 10.6 23.265] [0 0 -1] [0 1 0] 5 0.22 hazard)
  (decal [-37.3 10.6 26.735] [0 0 1] [0 1 0] 5 0.22 hazard)
  (bulb [-34.37 10.75 23.875] (rgb 1 0.95 0.82))
  (bulb [-34.37 10.75 26.125] (rgb 1 0.95 0.82))
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
    (skin {'all concrete} (cut [-14.8 9 29] [-12.2 9 29] [-13.5 13.5 31.8] (solid (box [-14.8 9 29] [-12.2 13.5 33]))))
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
  (easel -2.1 9.6 34.4) (easel 2.1 9.6 34.4)
  ; ..drifts of them against the walls, deepest either side of the doors, down the stairs'
  ; sides to the pavement, and in the bays either side
  (drift heapwarm -3.25 3.25 28.2 36.95 0.25 stairh stairg)
  (plant 420 100 -3.2 3.2 28.4 36.9 stairh stairg)
  (drift heappale -12.25 -5.75 28.4 35.05 0.25 (bayh -12.2 -5.8) bayg)
  (drift heappale 5.75 12.25 28.4 35.05 0.25 (bayh 5.8 12.2) bayg)
  (drift heapwarm -18.0 -14.75 28.4 35.05 0.25 (outh -14.8 -18.0) bayg)
  (drift heapwarm 14.75 18.0 28.4 35.05 0.25 (outh 14.8 18.0) bayg)
  (plant 260 1100 -12.2 -5.8 28.6 35 (bayh -12.2 -5.8) bayg) (plant 260 1300 5.8 12.2 28.6 35 (bayh 5.8 12.2) bayg)
  (plant 130 1500 -18.0 -14.8 28.6 35 (outh -14.8 -18.0) bayg) (plant 130 1600 14.8 18.0 28.6 35 (outh 14.8 18.0) bayg)
  (decal [0 11.6 37.47] [0 0 -1] [0 1 0] 0.8 0.8 wreath)
  (candle 0.21 9.6 33.808 0.32 wax) (candle 0.508 9.6 33.51 0.26 wax)
  (candle 0.508 9.6 33.09 0.3 wax) (candle 0.21 9.6 32.792 0.22 wax)
  (candle -0.21 9.6 32.792 0.28 wax) (candle -0.508 9.6 33.09 0.34 wax)
  (candle -0.508 9.6 33.51 0.24 wax) (candle -0.21 9.6 33.808 0.3 purplewax)
  (flames (rgb 1 0.62 0.25) [[0.21 9.925 33.808] [0.508 9.865 33.51] [0.508 9.905 33.09] [0.21 9.825 32.792] [-0.21 9.885 32.792] [-0.508 9.945 33.09] [-0.508 9.845 33.51]])
  ; ..across from the shop, on the far corner of the short street, a block of bare
  ; poured concrete, a storey over it: blind below, its top two storeys each a pair
  ; of broad dark panes sunk deep in each face, a heavy lip round its roof
  (skin {'all concrete} (solid (box [-45 8.85 33] [-33 26 47])))
  (skin {'all concrete} (solid (box [-45 24.4 32.3] [-32.3 26.6 47])))
  (map (q \ slot (q 0) (q 1) 'z) (cats (map (y \ map (x \ [x y]) [-42.4 -38]) [16.9 20.5])))
  (map (q \ slot (q 0) (q 1) 'x) (cats (map (y \ map (z \ [z y]) [38.5 43.5]) [16.9 20.5])))
  ; ..and a steel girder from its corner near the shop's roof, out to the office's first
  ; beam, along through the points of all four and through the one on the column, and back
  ; the same way to the building east; a red beacon flashing under it at each free point
  (mirror-x 0 [(whole (skin {'all darkmetal} (solid (prism 0.8 [[-33.855 21.2 34.418] [-14.361 21.2 21.314] [-15.142 21.2 20.152] [-34.636 21.2 33.256]]))))])
  (whole (skin {'all darkmetal} (solid (box [-15.2 21.2 20.2] [15.2 22 21.6]))))
  (map (x \ blink (bulb [x 21.08 20.9] (rgb 1 0.06 0.03))) [-13.5 -4.5 13.5])
  (skin {'all facade} (solid (box [20 8.85 33] [45 28 47])))
  (poster [-4.7 -3.8 6.4] 0.7 1.0 ())
  ; inside the easternmost block, a room no one can reach: a window in its west face onto the
  ; chamber beside it, a lamp, and a door in its east wall
  (room [11.3 -5 0.3] [18.7 -1.8 3.7])
  (window [10.95 -4.1 0.6] [11.35 -2.4 3.4] glass)
  (lamp [13 -3.4 0.3] [0 0 1] [1 0 0])
  (door [18.7 -5 2] 1.2 2.2)
  ; the bins: on the platform against the blocks either side of the hallway and at its
  ; ends, and in each wing against the front block
  (mirror-x 0
   [(bin [-5 -5 -0.4] 0.55 0.55 0.95 binmetal binsign)
    (bin [-10.5 -5 -1.0] 0.55 0.55 0.95 binmetal binsign)
    (bin [-15 -5 4.4] 0.55 0.55 0.95 binmetal binsign)]))
