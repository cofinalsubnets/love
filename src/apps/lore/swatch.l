; swatch -- a texture from a recipe: layers painted one over another on a picture w by h,
; x from the left and y down from the top, in texels. the picture starts mid grey, and each
; layer paints the texels of its shape, the later over the earlier.
;
;   layers
;   (fill PAINT)                        every texel
;   (rows from to PAINT)                rows from up to but not to; (cols from to PAINT) columns
;   (rect x0 y0 x1 y1 PAINT)            a box, x0 y0 in and x1 y1 just out
;   (disc x y r PAINT)                  a round r in radius, its middle at x y
;   (grid dx dy w PAINT)                lines w wide every dx columns and every dy rows; 0 none
;   (checker dx dy PAINT)               every other cell dx by dy, the corner's left as it was
;   (stripes every w slant PAINT)       bands w wide every so many columns, leaning slant
;                                       across for each row down: 0 upright, 1 or -1 diagonal
;   (dots dx dy r PAINT)                a round r in radius in the middle of every cell dx by
;                                       dy: rivets, holes
;   (bevel dx dy w LIGHT DARK)          every cell dx by dy a panel, its top and left w wide
;                                       painted LIGHT, its bottom and right DARK
;   (patches size cover PAINT)          blotches size across, cover 0 to 1 how much: grime
;   (within x0 y0 x1 y1 LAYER ..)       the layers, painting only inside the box
;   PAINT                               a paint alone paints every texel, as fill
;
;   paints
;   (rgb r g b) (grey g) or a number    that colour, 0 to 1
;   (shade k)                           what is there times k: darker below 1
;   (tint (rgb r g b))                  what is there times a colour
;   (mix (rgb r g b) t)                 what is there t of the way to a colour
;   (noise size amount) (noise sx sy amount)  what is there times 1 less up to amount,
;                                       varying smoothly over size texels; size 1 a grain
;   hole                                nothing: the surface not drawn there
;
;   (swatch-fault layers)               () when every layer is understood, else [Q USAGE]
;   (swatch-texel layers)               (\ x y colour), or () for a hole
;   (swatch w h layers)                 the picture, as mesh-pic makes it
(module (swatch swatch swatch-fault swatch-texel)
(borrow 'vec)                           ; vn, cmix, c*
(borrow 'mesh)                          ; mesh-pic
(:
 (num? v) (charm? v || gem? v)
 (f v) (1.0 * v)
 (fmod a m) (a - m * floor (a / m))
 (rgb? q) (two? q && <q = 'rgb && #q = 4 && all num? >q)
 (colour q) (? (num? q) [(f q) (f q) (f q)]
               (two? q && <q = 'grey && #q = 2 && num? (q 1)) (: g (f (q 1)) [g g g])
               (rgb? q) (map f >q))
 ; ..a paint: [(\ c x y c')], or () where it is not one; c () is a hole, left one
 (paint q s) (: (on g) [(\ c x y (two? c ? (g c x y) c))]
   (? (q = 'hole) [(\ c x y ())]
      (colour q != ()) (: k (colour q) [(\ c x y k)])
      (!(two? q)) ()
      (<q = 'shade && #q = 2 && num? (q 1)) (: k (f (q 1)) (on (\ c x y (c* k c))))
      (<q = 'tint && #q = 2 && rgb? (q 1)) (: k (colour (q 1)) (on (\ c x y [(c 0 * k 0) (c 1 * k 1) (c 2 * k 2)])))
      (<q = 'mix && #q = 3 && colour (q 1) != () && num? (q 2)) (: k (colour (q 1)) t (f (q 2)) (on (\ c x y (cmix c k t))))
      (<q = 'noise && (#q = 3 || #q = 4) && all num? >q)
       (: sx (f (q 1)) sy (f (#q = 4 ? (q 2) (q 1))) a (f (q (#q - 1)))
          (on (\ c x y (c* (1.0 - a + a * vn (x / sx) (y / sy) s) c))))))
 ; ..what each layer takes, said back when one is not understood
 usage {'fill "(fill PAINT)" 'rows "(rows from to PAINT)" 'cols "(cols from to PAINT)"
        'rect "(rect x0 y0 x1 y1 PAINT)" 'disc "(disc x y r PAINT)" 'grid "(grid dx dy w PAINT)"
        'checker "(checker dx dy PAINT)" 'stripes "(stripes every w slant PAINT)" 'dots "(dots dx dy r PAINT)"
        'bevel "(bevel dx dy w LIGHT DARK)" 'patches "(patches size cover PAINT)"
        'within "(within x0 y0 x1 y1 LAYER ..)"}
 (hint q) (two? q && peep usage <q () != () ? (usage <q)
           "a layer is one of fill rows cols rect disc grid checker stripes dots bevel patches within")
 ; ..the shapes: (in? x y), x y a texel's corner; s a seed
 (shape k a s) (: (n i) (f (a i))
   (? (k = 'fill) (\ x y 1)
      (k = 'rows) (\ x y (n 0 <= y < n 1))
      (k = 'cols) (\ x y (n 0 <= x < n 1))
      (k = 'rect) (\ x y (n 0 <= x < n 2 && n 1 <= y < n 3))
      (k = 'disc) (\ x y (sq (x + 0.5 - n 0) + sq (y + 0.5 - n 1) < sq (n 2)))
      (k = 'grid) (\ x y ((n 0 > 0.0 && fmod x (n 0) < n 2) || (n 1 > 0.0 && fmod y (n 1) < n 2)))
      (k = 'checker) (\ x y (((floor (x / n 0) + floor (y / n 1)) % 2) = 1))
      (k = 'stripes) (\ x y (fmod (x + n 2 * y) (n 0) < n 1))
      (k = 'dots) (\ x y (sq (fmod x (n 0) + 0.5 - 0.5 * n 0) + sq (fmod y (n 1) + 0.5 - 0.5 * n 1) < sq (n 2)))
      (k = 'patches) (\ x y (vn (x / n 0) (y / n 0) s > 1.0 - n 1))))
 ; ..the numbers each layer takes before its paint
 takes {'fill 0 'rows 2 'cols 2 'rect 4 'disc 3 'grid 3 'checker 2 'stripes 3 'dots 3 'bevel 3 'patches 2}
 ; ..a within's inner layers, when its box is numbers
 (inner q) (two? q && <q = 'within && #q >= 6 && all num? (take 4 >q) ? (drop 5 q))
 ; ..a layer: [(\ c x y c')], or () where it is not one; s its noise's seed
 (layer q s) (? (two? (paint q s)) (paint q s)
   (!(two? q)) ()
   (inner q != ()) (: ls (layers (inner q) s) r (shape 'rect (map f (take 4 >q)) s)
                     (two? ls ? [(\ c x y (r x y ? (run ls c x y) c))]))
   (: k <q t (peep takes k -1) a >q
      (? (t < 0 || #a != t + (k = 'bevel ? 2 1) || !(all num? (take t a))) ()
         (: in? (shape k (take t a) s) p (paint (a t) s)
            (? (atom? p) ()
               (k = 'bevel) (: d (paint (a (t + 1)) (s + 1)) w (f (a 2)) dx (f (a 0)) dy (f (a 1))
                              (two? d ? [(\ c x y (: u (fmod x dx) v (fmod y dy)
                                                     (? (u >= dx - w || v >= dy - w) (<d c x y)
                                                        (u < w || v < w) (<p c x y)
                                                        c)))]))
               [(\ c x y (in? x y ? (<p c x y) c))])))))
 (layers l s) (: ls (map (i \ layer (l i) (s + 7 * i)) ^#l) (all two? ls ? (map (g \ <g) ls)))
 (run ls c x y) (foldl (\ c g (g c x y)) c ls)
 ; ..the first layer not understood, a within's inner ones searched, and what it takes
 (swatch-fault l) (? (atom? l) ()
   (two? (layer <l 0)) (swatch-fault >l)
   (: q <l (inner q != () ? (swatch-fault (inner q) @ () [q (hint q)] e e) [q (hint q)])))
 (swatch-texel l) (: ls (layers l 211) g [0.5 0.5 0.5] (\ x y (run ls g (f x) (f y))))
 (swatch w h l) (mesh-pic w h (swatch-texel l)))
) ; module swatch
