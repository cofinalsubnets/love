; swatch -- a texture from a recipe: layers painted in order over a w by h picture, mid grey
; at first; x from the left, y down, in texels. a layer is one of `usage` below, a bare paint a fill.
; ranges take from and leave out to; stripes lean slant columns per row down; checker leaves the
; corner cell; bevel paints top/left LIGHT, bottom/right DARK; patches cover is 0 to 1; cracks wander
; their grid's lines by noise; poly fills inside its corners, even-odd.
; paints: (rgb r g b), (grey g) or a number, 0 to 1; (shade k) and (tint rgb) multiply what is
; there, (mix rgb t) goes t of the way to a colour, (noise size [sy] amount) multiplies by 1 less
; up to amount, smooth over size texels. hole leaves the texel undrawn; a later colour fills it, shading keeps it a hole.
; (swatch-fault l) is () or [Q USAGE]; (swatch-texel l) is (\ x y colour-or-()).
(module (swatch swatch swatch-fault swatch-texel swatch-plan)
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
       (: sx (f (q 1)) sy (f (#q @ 4 (q 2) (q 1))) a (f (q (#q - 1)))
          (on (\ c x y (c* (1.0 - a + a * vn (x / sx) (y / sy) s) c))))))
 ; ..what each layer takes, said back when one is not understood
 usage {'fill "(fill PAINT)" 'rows "(rows from to PAINT)" 'cols "(cols from to PAINT)"
        'rect "(rect x0 y0 x1 y1 PAINT)" 'disc "(disc x y r PAINT)" 'grid "(grid dx dy w PAINT)"
        'checker "(checker dx dy PAINT)" 'stripes "(stripes every w slant PAINT)" 'dots "(dots dx dy r PAINT)"
        'bevel "(bevel dx dy w LIGHT DARK)" 'patches "(patches size cover PAINT)" 'poly "(poly x y x y x y .. PAINT)"
        'cracks "(cracks dx dy w wander PAINT)" 'within "(within x0 y0 x1 y1 LAYER ..)"}
 (hint q) (two? q && usage <q != () ? (usage <q)
           "a layer is one of fill rows cols rect disc grid checker stripes dots bevel patches cracks poly within")
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
      (k = 'patches) (\ x y (vn (x / n 0) (y / n 0) s > 1.0 - n 1))
      ; ..a grid whose lines wander by noise, up to wander texels either side
      (k = 'cracks) (\ x y (: d (n 3 * (2.0 * vn (x / n 0) (y / n 1) s - 1.0)) e (n 3 * (2.0 * vn (x / n 0) (y / n 1) (s + 1) - 1.0))
                            (fmod (x + d) (n 0) < n 2 || fmod (y + e) (n 1) < n 2)))))
 ; ..a polygon's inside, its corners x y in turn: a texel's middle crossed by its edges an
 ; odd number of times to its right
 (poly-in ps) (: n (#ps // 2) es (map (i \ (: j ((i + 1) % n) [(ps (2 * i)) (ps (2 * i + 1)) (ps (2 * j)) (ps (2 * j + 1))])) ^n)
   (\ x y (: px (x + 0.5) py (y + 0.5)
            (foldl (\ a e ((e 1 > py) != (e 3 > py) && px < e 0 + (e 2 - e 0) * (py - e 1) / (e 3 - e 1) ? (1 - a) a)) 0 es = 1))))
 ; ..the numbers each layer takes before its paint
 takes {'fill 0 'rows 2 'cols 2 'rect 4 'disc 3 'grid 3 'checker 2 'stripes 3 'dots 3 'bevel 3 'patches 2 'cracks 4}
 ; ..a within's inner layers, when its box is numbers
 (inner q) (two? q && <q = 'within && #q >= 6 && all num? (take 4 >q) ? (drop 5 q))
 ; ..a layer: [(\ c x y c')], or () where it is not one; s its noise's seed
 (layer q s) (? (two? (paint q s)) (paint q s)
   (!(two? q)) ()
   (inner q != ()) (: ls (layers (inner q) s) r (shape 'rect (map f (take 4 >q)) s)
                     (two? ls ? [(\ c x y (r x y ? (run ls c x y) c))]))
   (<q = 'poly) (: a >q n (#a - 1) p (n > 0 ? (paint (a n) s) ())
     (? (n < 6 || n % 2 = 1 || !(all num? (take n a)) || atom? p) ()
        (: in? (poly-in (map f (take n a))) [(\ c x y (in? x y ? (<p c x y) c))])))
   (: k <q t (peep takes k -1) a >q
      (? (t < 0 || #a != t + (k @ 'bevel 2 1) || !(all num? (take t a))) ()
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
   (: q <l (inner q @ () [q (hint q)] (swatch-fault (inner q) @ () [q (hint q)] e e))))
 (swatch-texel l) (: ls (layers l 211) g [0.5 0.5 0.5] (\ x y (run ls g (f x) (f y))))
 ; ..the same recipe as data for swatch-pic (src/love/swatch.c): each layer [boxes kind nums
 ; seed paint paint], a within's box laid on each of its layers; a paint [tag a b c d]
 shapes {'fill 0 'rows 1 'cols 2 'rect 3 'disc 4 'grid 5 'checker 6 'stripes 7 'dots 8 'patches 9 'cracks 12}
 (paint-plan q s) (: z 0.0
   (? (q = 'hole) [0 z z z z]
      (colour q != ()) (: k (colour q) [1 (k 0) (k 1) (k 2) z])
      (<q = 'shade) [2 (f (q 1)) z z z]
      (<q = 'tint) (: k (colour (q 1)) [3 (k 0) (k 1) (k 2) z])
      (<q = 'mix) (: k (colour (q 1)) [4 (k 0) (k 1) (k 2) (f (q 2))])
      (: sx (f (q 1)) sy (f (#q @ 4 (q 2) (q 1))) [5 sx sy (f (q (#q - 1))) (f s)])))
 (plan q s bx) (? (two? (paint q s)) [[bx 0 [0.0 0.0 0.0 0.0] s (paint-plan q s) ()]]
   (inner q != ()) (: is (inner q) b (bx + map f (take 4 >q)) (catmap (i \ plan (is i) (s + 7 * i) b) ^#is))
   (<q = 'poly) (: a >q n (#a - 1) [[bx 11 (map f (take n a)) s (paint-plan (a n) s) ()]])
   (<q = 'bevel) (: a >q [[bx 10 (map f (take 3 a)) s (paint-plan (a 3) s) (paint-plan (a 4) (s + 1))]])
   (: k <q a >q t (takes k) [[bx (shapes k) (map f (take t a) + map (_ \ 0.0) ^(4 - t)) s (paint-plan (a t) s) ()]]))
 (swatch-plan l) (? (two? (layers l 211)) (catmap (i \ plan (l i) (211 + 7 * i) ()) ^#l))
 (swatch w h l) (swatch-pic w h (swatch-plan l)))
) ; module swatch
