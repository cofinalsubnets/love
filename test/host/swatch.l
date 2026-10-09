; test/host/swatch.l -- src/apps/lore/swatch.l: a texture painted from its recipe, the
; later layer over the earlier; each shape's texels and none beside them; the paints, a hole
; left a hole; a within painting only inside its box; the layers not understood, and what
; they take; and the picture, its holes clear.
; not in the corpus: a crew module. run: cat test/00-init.l test/host/swatch.l | out/love
(borrow 'swatch)

(: (at l x y) (swatch-texel l x y)
   red [1.0 0.0 0.0] (g v) [v v v]
   (on? l x y) (at ('(fill 0.0) . l) x y = red)
   (paint1 s) (\ x y (on? [s] x y))
   rows (paint1 '(rows 2 4 (rgb 1 0 0))) grid (paint1 '(grid 8 0 2 (rgb 1 0 0)))
   chk (paint1 '(checker 4 4 (rgb 1 0 0))) str (paint1 '(stripes 8 2 -1 (rgb 1 0 0)))
   dots (paint1 '(dots 8 8 1.5 (rgb 1 0 0))) disc (paint1 '(disc 4 4 2 (rgb 1 0 0)))
   bev '((fill 0.5) (bevel 16 16 2 1.0 0.0))
   inw '((fill 0.0) (within 0 0 8 8 (fill (rgb 1 0 0)) (shade 0.5)))
   nz (map (i \ at '((fill 1.0) (noise 4 0.2)) (i % 16) (i // 16) 0) ^256)
   pic (swatch 8 4 '((fill 0.25) (cols 6 8 hole))) t0 (pic 0)
 ; ..the picture starts grey; the later layer wins; a number a grey, and grey and rgb alike
 (test (at () 0 0 = g 0.5) (at '((fill 0.2) (rows 0 1 0.7)) 3 0 = g 0.7) (at '((fill 0.2) (rows 0 1 0.7)) 3 1 = g 0.2)
       (at '((grey 0.3)) 0 0 = g 0.3) (at '((rgb 1 0 0)) 5 5 = red)
       ; ..each shape: rows from up to but not to; lines every 8 columns 2 wide; every other
       ; cell; bands leaning a column a row; rounds at each cell's middle; one round
       (rows 0 2 && rows 0 3 && !(rows 0 1) && !(rows 0 4))
       (grid 0 5 && grid 9 5 && !(grid 2 5) && grid 16 0)
       (!(chk 0 0) && chk 4 0 && chk 0 4 && !(chk 4 4))
       (str 0 0 && str 1 0 && !(str 2 0) && str 1 1 && str 2 1 && !(str 1 2))
       (dots 4 4 && dots 12 4 && !(dots 0 0) && !(dots 7 4))
       (disc 4 4 && disc 3 3 && !(disc 0 0) && !(disc 6 6))
       ; ..a bevel's light top and left, dark bottom and right, the panel between as it was
       (at bev 0 5 = g 1.0) (at bev 5 0 = g 1.0) (at bev 15 5 = g 0.0) (at bev 5 14 = g 0.0)
       (at bev 15 0 = g 0.0) (at bev 5 5 = g 0.5)
       ; ..the paints over what is there: shade, tint, mix, a hole and paint over it
       (at '((fill 0.8) (shade 0.5)) 0 0 = g 0.4) (at '((fill 0.5) (tint (rgb 1 0 0.5))) 0 0 = [0.5 0.0 0.25])
       (at '((fill 0.0) (mix (rgb 1 1 1) 0.25)) 0 0 = g 0.25)
       (at '((fill 0.5) (rows 0 1 hole)) 0 0 = ()) (at '((fill 0.5) hole (shade 0.5)) 0 0 = ())
       (at '((fill 0.5) hole (noise 2 0.5)) 0 0 = ()) (at '(hole (fill 0.3)) 0 0 = g 0.3)
       ; ..noise darkens by up to its amount, and varies
       (all (v \ 0.8 - 1e-9 <= v <= 1.0 + 1e-9) nz) (any (v \ v < 0.95) nz) (any (v \ v > 0.95) nz)
       ; ..a within paints inside its box only, its layers in order
       (at inw 7 7 = [0.5 0.0 0.0]) (at inw 8 7 = g 0.0) (at inw 3 8 = g 0.0)
       ; ..the same recipe the same texels
       (at '((patches 4 0.5 (rgb 1 0 0))) 9 9 = at '((patches 4 0.5 (rgb 1 0 0))) 9 9)
       ; ..what is not understood, and what it takes: a shape short a number, a paint not
       ; one, a word no layer has, one inside a within, a within with no layers
       (swatch-fault '((fill 1) (rows 0 4 (shade 0.5)) (within 0 0 2 2 (noise 3 0.1))) = ())
       (swatch-fault '((fill 1) (rows 1 (grey 2))) = ['(rows 1 (grey 2)) "(rows from to PAINT)"])
       (swatch-fault '((fill purple)) 1 = "(fill PAINT)")
       (has? (swatch-fault '((stripe 4 2 0 1)) 1) "stripes")
       (swatch-fault '((within 0 0 4 4 (fill 1) (disc 1 1 1))) 0 = '(disc 1 1 1))
       (swatch-fault '((within 0 0 4 4)) 0 = '(within 0 0 4 4))
       ; ..the picture, 8 by 4 with its mips, the hole's texels clear
       (shape t0 = [4 8]) (#pic = 3) (peep t0 [0 6] 0 = -1) (peep t0 [0 0] 0 != -1)))
(test_fin ())
(puts "swatch: ok\n")
