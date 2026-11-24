; swatch -- a texture from a recipe: layers painted in order over a w by h picture, mid grey
; at first; x from the left, y down, in texels. a layer is one of `usage` below, a bare paint a fill.
; ranges take from and leave out to; stripes lean slant columns per row down; checker leaves the
; corner cell; bevel paints top/left LIGHT, bottom/right DARK; patches cover is 0 to 1; cracks wander
; their grid's lines by noise; poly fills inside its corners, even-odd; grain is rows every
; apart and w thick, wandering warp texels up and down by noise size texels across; cells
; are the borders of cells size texels across, each round a point thrown in it, w how wide.
; oval is rx by ry round its middle, turned deg; ball takes no paint, it shades what is under
; such an oval as a globe lit from lx ly, up to shine bright where it faces the light.
; fbm is octaves of noise, the first size texels a cell, each after twice as fine and half as
; strong, wrapped at the picture's edges so it tiles; relief shades its slopes as lit from the
; top left, depth deep; stain lays its paint where fbm passes 1 less cover, soft its edge.
; (seed n) throws the noise of the layers after it anew, n a whole number under a million.
; paints: (rgb r g b), (grey g) or a number, 0 to 1; (shade k) and (tint rgb) multiply what is
; there, (mix rgb t) goes t of the way to a colour, (noise size [sy] amount) multiplies by 1 less
; up to amount, smooth over size texels, (fbm size octaves amount) as much by fbm. hole leaves the texel undrawn; a later colour fills it, shading keeps it a hole.
; (swatch-fine k l) is l for a picture k times as wide and high, () where it has art.
; (swatch-fault l) is () or [Q USAGE]; (swatch-texel w h l) is (\ x y colour-or-()).
(module (swatch swatch swatch-fault swatch-fine swatch-texel swatch-plan)
(borrow 'vec)                           ; vn, cmix, c*
(borrow 'mesh)                          ; mesh-pic
(borrow 'view)                          ; throw
(borrow 'lore)                          ; swatch-pic, in C
(borrow 'posix)                         ; getpid, art's seed for the run
(:
 (num? v) (charm? v || gem? v)
 (f v) (1.0 * v)
 (fmod a m) (a - m * floor (a / m))
 ; ..value noise wrapped every pu by pv cells, as vec's vn; and its octaves over a picture z
 (vnw x y pu pv s) (: ix (floor x) iy (floor y) ux (x - ix) uy (y - iy)
   ex (2 ux * (3.0 - 2.0 * ux)) ey (2 uy * (3.0 - 2.0 * uy))
   (h i k) (throw (((i % pu) + pu) % pu) (((k % pv) + pv) % pv) s 1024 / 1023.0)
   p (h ix iy) q (h (ix + 1) iy) r (h ix (iy + 1)) t (h (ix + 1) (iy + 1))
   lo (p + ex * (q - p)) hi (r + ex * (t - r)) (lo + ey * (hi - lo)))
 (cells n size) (max 1 (int (n / size + 0.5)))
 (fbm x y size n z s) (: (go k pu pv a sum wt) (? (k >= n) (sum / wt)
                          (go (k + 1) (2 * pu) (2 * pv) (0.5 * a) (sum + a * vnw (x * pu / z 0) (y * pv / z 1) pu pv (s + k)) (wt + a)))
   (go 0 (cells (z 0) size) (cells (z 1) size) 1.0 0.0 0.0))
 (octs? a) (num? (a 0) && num? (a 1) && a 0 > 0 && 1 <= a 1 <= 12)
 (rgb? q) (two? q && <q = 'rgb && #q = 4 && all num? >q)
 (colour q) (? (num? q) [(f q) (f q) (f q)]
               (two? q && <q = 'grey && #q = 2 && num? (q 1)) (: g (f (q 1)) [g g g])
               (rgb? q) (map f >q))
 ; ..a paint: [(\ c x y c')], or () where it is not one; c () is a hole, left one
 (paint q s z) (: (on g) [(\ c x y (two? c ? (g c x y) c))]
   (? (q = 'hole) [(\ c x y ())]
      (colour q != ()) (: k (colour q) [(\ c x y k)])
      (!(two? q)) ()
      (<q = 'shade && #q = 2 && num? (q 1)) (: k (f (q 1)) (on (\ c x y (c* k c))))
      (<q = 'tint && #q = 2 && rgb? (q 1)) (: k (colour (q 1)) (on (\ c x y [(c 0 * k 0) (c 1 * k 1) (c 2 * k 2)])))
      (<q = 'mix && #q = 3 && colour (q 1) != () && num? (q 2)) (: k (colour (q 1)) t (f (q 2)) (on (\ c x y (cmix c k t))))
      (<q = 'noise && (#q = 3 || #q = 4) && all num? >q)
       (: sx (f (q 1)) sy (f (#q @ 4 (q 2) (q 1))) a (f (q (#q - 1)))
          (on (\ c x y (c* (1.0 - a + a * vn (x / sx) (y / sy) s) c))))
      (<q = 'fbm && #q = 4 && all num? >q && octs? >q)
       (: sz (f (q 1)) n (int (q 2)) a (f (q 3)) (on (\ c x y (c* (1.0 - a + a * fbm x y sz n z s) c))))))
 ; ..what each layer takes, said back when one is not understood
 usage {'fill "(fill PAINT)" 'rows "(rows from to PAINT)" 'cols "(cols from to PAINT)"
        'rect "(rect x0 y0 x1 y1 PAINT)" 'disc "(disc x y r PAINT)" 'grid "(grid dx dy w PAINT)"
        'checker "(checker dx dy PAINT)" 'stripes "(stripes every w slant PAINT)" 'dots "(dots dx dy r PAINT)"
        'bevel "(bevel dx dy w LIGHT DARK)" 'patches "(patches size cover PAINT)" 'poly "(poly x y x y x y .. PAINT)"
        'cracks "(cracks dx dy w wander PAINT)" 'grain "(grain every w warp size PAINT)"
        'cells "(cells size w PAINT)" 'oval "(oval x y rx ry deg PAINT)" 'ball "(ball x y rx ry deg lx ly shine)" 'within "(within x0 y0 x1 y1 LAYER ..)" 'seed "(seed n)"
        'relief "(relief size octaves depth)" 'stain "(stain size octaves cover soft PAINT)"}
 (hint q) (two? q && usage <q != () ? (usage <q)
           "a layer is one of fill rows cols rect disc grid checker stripes dots bevel patches cracks grain cells oval ball relief stain poly within seed")
 ; ..the shapes: (in? x y), x y a texel's corner; s a seed
 ; ..a texel in an oval's own axes, a unit circle: nums x y rx ry cos sin
 (oval-uv m x y) (: dx (x + 0.5 - m 0) dy (y + 0.5 - m 1) [((dx * m 4 + dy * m 5) / m 2) ((dy * m 4 - dx * m 5) / m 3)])
 (turned a) (take 4 (map f a) + [(cos (f (a 4) * pi / 180.0)) (sin (f (a 4) * pi / 180.0))])
 ; ..and a ball's light: lz keeps lx ly lz whole, nums cos sin then lx ly lz shine
 (ball-nums a) (: lx (f (a 5)) ly (f (a 6)) (turned a + [lx ly (sqrt (max 0.0 (1.0 - lx * lx - ly * ly))) (f (a 7))]))
 (ball-on m c x y) (: e (oval-uv m x y) u (e 0) v (e 1) q (u * u + v * v)
   (? (atom? c || q >= 1.0) c
      (: nz (sqrt (1.0 - q)) nx (u * m 4 - v * m 5) ny (u * m 5 + v * m 4)
         d (max 0.0 (nx * m 6 + ny * m 7 + nz * m 8)) k ((0.38 + 0.8 * d) * (0.66 + 0.34 * nz))
         d2 (d * d) d4 (d2 * d2) d8 (d4 * d4) sp (m 9 * (d8 * d8))
         [(c 0 * k + sp) (c 1 * k + sp) (c 2 * k + sp)])))
 (shape k a s) (: (n i) (f (a i))
   (? (k = 'fill) (\ x y 1)
      (k = 'oval) (: m (turned a) (\ x y (: e (oval-uv m x y) (e 0 * e 0 + e 1 * e 1 < 1.0))))
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
                            (fmod (x + d) (n 0) < n 2 || fmod (y + e) (n 1) < n 2)))
      (k = 'grain) (\ x y (fmod (y + n 2 * (2.0 * vn (x / n 3) (y / n 3) s - 1.0)) (n 0) < n 1))
      ; ..the two points nearest, of the nine cells round, by their squares
      (k = 'cells) (\ x y (: u (x / n 0) v (y / n 0) i (floor u) j (floor v)
                            (d q) (: ci (i + q % 3 - 1) cj (j + q // 3 - 1)
                                    px (ci + throw ci cj s 1024 / 1023.0) py (cj + throw cj ci (s + 1) 1024 / 1023.0)
                                    ((px - u) * (px - u) + (py - v) * (py - v)))
                            e (foldl (\ m q (d q @ t (t < m 0 ? [t (m 0)] (t < m 1 ? [(m 0) t] m)))) [1e9 1e9] ^9)
                            (e 1 - e 0 < n 1)))))
 ; ..a polygon's inside, its corners x y in turn: a texel's middle crossed by its edges an
 ; odd number of times to its right
 (poly-in ps) (: n (#ps // 2) es (map (i \ (: j ((i + 1) % n) [(ps (2 * i)) (ps (2 * i + 1)) (ps (2 * j)) (ps (2 * j + 1))])) ^n)
   (\ x y (: px (x + 0.5) py (y + 0.5)
            (foldl (\ a e ((e 1 > py) != (e 3 > py) && px < e 0 + (e 2 - e 0) * (py - e 1) / (e 3 - e 1) ? (1 - a) a)) 0 es = 1))))
 ; ..the numbers each layer takes before its paint
 takes {'fill 0 'rows 2 'cols 2 'rect 4 'disc 3 'grid 3 'checker 2 'stripes 3 'dots 3 'bevel 3 'patches 2 'cracks 4 'grain 4 'cells 2 'oval 5}
 ; ..a within's inner layers, when its box is numbers
 (inner q) (two? q && <q = 'within && #q >= 6 && all num? (take 4 >q) ? (drop 5 q))
 ; ..a layer: [(\ c x y c')], or () where it is not one; s its noise's seed
 (layer q s z) (? (two? (paint q s z)) (paint q s z)
   (!(two? q)) ()
   (inner q != ()) (: ls (layers (inner q) s z) r (shape 'rect (map f (take 4 >q)) s)
                     (two? ls ? [(\ c x y (r x y ? (run ls c x y) c))]))
   (<q = 'poly) (: a >q n (#a - 1) p (n > 0 ? (paint (a n) s z) ())
     (? (n < 6 || n % 2 = 1 || !(all num? (take n a)) || atom? p) ()
        (: in? (poly-in (map f (take n a))) [(\ c x y (in? x y ? (<p c x y) c))])))
   (<q = 'ball) (: a >q (#a = 8 && all num? a ? (: m (ball-nums a) [(\ c x y (ball-on m c x y))])))
   ; ..a slope toward the top left lighter, away darker
   (<q = 'relief) (: a >q (#a = 3 && octs? a && num? (a 2) ?
     (: sz (f (a 0)) n (int (a 1)) d (f (a 2)) (e x y) (fbm x y sz n z s)
        [(\ c x y (atom? c ? c (c* (1.0 + d * sz * 0.5 * ((e (x + 1.0) y - e (x - 1.0) y) + (e x (y + 1.0) - e x (y - 1.0)))) c)))])))
   ; ..the paint mixed in by how far fbm is past its edge; a hole goes all or nothing
   (<q = 'stain) (: a >q p (#a = 5 ? (paint (a 4) s z) ())
     (? (atom? p || !(octs? a) || !(num? (a 2)) || !(num? (a 3)) || a 3 <= 0) ()
        (: sz (f (a 0)) n (int (a 1)) cv (f (a 2)) sf (f (a 3))
           [(\ c x y (: t (fbm x y sz n z s) w (min 1.0 (max 0.0 ((t - (1.0 - cv)) / sf))) d (<p c x y)
                       (? (atom? c || atom? d) (w >= 0.5 ? d c) (cmix c d w))))])))
   (: k <q t (peep takes k -1) a >q
      (? (t < 0 || #a != t + (k @ 'bevel 2 1) || !(all num? (take t a))) ()
         (: in? (shape k (take t a) s) p (paint (a t) s z)
            (? (atom? p) ()
               (k = 'bevel) (: d (paint (a (t + 1)) (s + 1) z) w (f (a 2)) dx (f (a 0)) dy (f (a 1))
                              (two? d ? [(\ c x y (: u (fmod x dx) v (fmod y dy)
                                                     (? (u >= dx - w || v >= dy - w) (<d c x y)
                                                        (u < w || v < w) (<p c x y)
                                                        c)))]))
               [(\ c x y (in? x y ? (<p c x y) c))])))))
 ; ..each layer and its seed: s on 7 a layer, a (seed n) moving those after it
 (seed? q) (two? q && <q = 'seed && #q = 2 && charm? (q 1) && 0 <= q 1 < 1000000)
 (seeded l s) (: (go l i k acc) (? (atom? l) (rev acc) (seed? <l) (go >l i (k + 1009 * (<l 1)) acc)
                                   (go >l (i + 1) k ([<l (s + 7 * i + k)] . acc)))
                (go l 0 0 ()))
 (layers l s z) (: ls (map (p \ layer (p 0) (p 1) z) (seeded l s)) (all two? ls ? (map cap ls)))
 (run ls c x y) (foldl (\ c g (g c x y)) c ls)
 ; ..the first layer not understood, a within's inner ones searched, and what it takes
 ; ..art from a template: (art KIND n) the layers of a picture of that kind, thrown anew each
 ; run under its pid and n, KIND one of arts or any for one of them
 arts ['drip 'fields 'grid 'discs]
 (art? q) (two? q && <q = 'art)
 (art-ok? q) (#q = 3 && (elem (q 1) arts || q 1 = 'any) && charm? (q 2))
 (unart l w h) (catmap (q \ art? q ? (art-layers (q 1) (q 2) w h) [q]) l)
 (art-layers k n w h) (: s (throw n 7 (getpid 0) 1000003)
   (rn i) (throw i n s 1000003 / 1000003.0) (ri i a b) (a + int (rn i * (b - a + 1))) (one l i) (l (int (rn i * #l)))
   (c3 v) ['rgb (v 0) (v 1) (v 2)] (mixc a b t) (map (j \ a j + t * (b j - a j)) ^3) (sd i) ['seed (ri i 1 999999)]
   vivid [[0.86 0.44 0.13] [0.72 0.2 0.15] [0.3 0.35 0.6] [0.85 0.72 0.3] [0.2 0.42 0.35] [0.52 0.15 0.33] [0.1 0.1 0.12] [0.9 0.88 0.82]]
   ((k = 'any ? (arts (ri 99 0 (#arts - 1))) k) @
    'drip (: gr (one [[0.82 0.77 0.66] [0.18 0.18 0.2] [0.9 0.88 0.84] [0.5 0.46 0.4]] 1)
            pal [[0.08 0.08 0.08] [0.95 0.95 0.93] [0.78 0.58 0.22] [0.45 0.47 0.5] [0.7 0.24 0.12] [0.2 0.3 0.45]]
            ([['fill (c3 gr)] '(noise 1 0.05) '(fbm 24 3 0.06)]
             + catmap (j \ [(sd (10 + j)) ['cracks (ri (20 + j) 12 24) (ri (30 + j) 12 24) (ri (40 + j) 1 2) (ri (50 + j) 8 16) (c3 (one pal (60 + j)))]]) ^(ri 2 3 5)
             + catmap (j \ [(sd (70 + j)) ['patches (ri (80 + j) 1 2) (0.008 + 0.02 * rn (90 + j)) (c3 (one pal (95 + j)))]]) ^2))
    ; ..fields of colour stacked on a darker ground, each over a band halfway to it, soft
    'fields (: gr (c* (0.3 + 0.25 * rn 1) (one vivid 2)) nb (ri 3 2 3) m (max 2 (w // 12)) gp (max 2 (h // 16))
              ws (map (j \ 0.5 + rn (10 + j)) ^nb) tw (foldl (+) 0.0 ws) av (h - 2 * m - (nb - 1) * gp)
              hs (map (x \ max 3 (int (av * x / tw))) ws) (y0 j) (m + j * gp + foldl (+) 0 (take j hs))
              ([['fill (c3 gr)] '(fbm 16 3 0.08)]
               + catmap (j \ (: c (one vivid (20 + j)) a (y0 j) b (a + hs j)
                               [['rect (m - 1) (a - 1) (w - m + 1) (b + 1) (c3 (mixc c gr 0.5))] ['rect m a (w - m) b (c3 c)]])) ^nb
               + [(sd 30) '(fbm 12 4 0.16) '(stain 8 3 0.2 0.6 (shade 1.08)) '(noise 1 0.04)]))
    ; ..a grid of black lines across a pale ground, a few of its cells filled with primaries
    'grid (: t (max 1 (w // 40)) nx (ri 3 2 4) ny (ri 4 2 4)
            xs (sort (map (j \ ri (10 + j) (w // 8) (w - w // 8)) ^nx)) ys (sort (map (j \ ri (20 + j) (h // 8) (h - h // 8)) ^ny))
            bx ([0] + xs + [w]) by ([0] + ys + [h]) prim [[0.8 0.12 0.1] [0.1 0.2 0.6] [0.95 0.8 0.15] [0.1 0.1 0.1]]
            ([['fill (c3 [0.93 0.92 0.88])] '(noise 1 0.03)]
             + map (j \ (: i (ri (30 + j) 0 nx) k (ri (40 + j) 0 ny) ['rect (bx i) (by k) (bx (i + 1)) (by (k + 1)) (c3 (one prim (50 + j)))])) ^(ri 5 3 5)
             + map (x \ ['cols x (x + t) (c3 [0.06 0.06 0.06])]) xs + map (y \ ['rows y (y + t) (c3 [0.06 0.06 0.06])]) ys))
    ; ..discs and rings over a pale ground, lines flung across them
    'discs (: gr (one [[0.9 0.86 0.76] [0.85 0.82 0.7] [0.2 0.22 0.3]] 1) lo (max 2 (h // 14)) hi (max 4 (h // 4))
             ([['fill (c3 gr)] '(fbm 24 3 0.07)]
              + catmap (j \ (: x (ri (10 + j) 0 w) y (ri (20 + j) 0 h) r (ri (30 + j) lo hi)
                              [['disc x y r (c3 (one vivid (40 + j)))] (rn (50 + j) < 0.4 ? ['disc x y (r * 0.6) (c3 (one vivid (60 + j)))] '(noise 1 0.0))]))
                       ^(ri 4 5 8)
              + map (j \ (: x0 (1.0 * ri (70 + j) 0 w) y0 (1.0 * ri (75 + j) 0 h) x1 (1.0 * ri (80 + j) 0 w) y1 (1.0 * ri (85 + j) 0 h)
                            dx (x1 - x0) dy (y1 - y0) l (max 1.0 (sqrt (dx * dx + dy * dy))) ox (0.0 - dy / l) oy (dx / l)
                            ['poly x0 y0 x1 y1 (x1 + ox) (y1 + oy) (x0 + ox) (y0 + oy) (c3 [0.08 0.08 0.1])]))
                    ^3))))
 ; ..a recipe k times finer: every length in it k times as long, no ratio, angle or count
 lengths {'rows 2 'cols 2 'rect 4 'disc 3 'grid 3 'checker 2 'stripes 2 'dots 3 'bevel 3 'patches 1
          'cracks 4 'grain 4 'cells 1 'oval 4 'ball 4 'relief 1 'stain 1 'fbm 1 'within 4}
 (fine-of k q) (? (!(two? q) || <q = 'seed) q
   (: n (<q @ 'poly (#q - 2) 'noise (#q - 2) h (peep lengths h 0))
      (<q . map (i \ (: a (q (i + 1)) (i < n ? (k * a) two? a ? (fine-of k a) a))) ^(#q - 1))))
 (swatch-fine k l) (any art? l ? () (map (fine-of k) l))
 (swatch-fault l) (? (atom? l) ()
   (art? <l) (art-ok? <l ? (swatch-fault >l) [<l "(art KIND n), KIND drip fields grid discs or any"])
   (seed? <l || two? (layer <l 0 [1 1])) (swatch-fault >l)
   (: q <l (inner q @ () [q (hint q)] (swatch-fault (inner q) @ () [q (hint q)] e e))))
 (swatch-texel w h l) (: ls (layers (unart l w h) 211 [w h]) g [0.5 0.5 0.5] (\ x y (run ls g (f x) (f y))))
 ; ..the same recipe as data for swatch-pic (src/love/swatch.c): each layer [boxes kind nums
 ; seed paint paint], a within's box laid on each of its layers; a paint [tag a b c d]
 shapes {'fill 0 'rows 1 'cols 2 'rect 3 'disc 4 'grid 5 'checker 6 'stripes 7 'dots 8 'patches 9 'cracks 12 'grain 13 'cells 14 'oval 15
         'relief 17 'stain 18}
 (paint-plan q s) (: z 0.0
   (? (q = 'hole) [0 z z z z]
      (colour q != ()) (: k (colour q) [1 (k 0) (k 1) (k 2) z])
      (<q = 'shade) [2 (f (q 1)) z z z]
      (<q = 'tint) (: k (colour (q 1)) [3 (k 0) (k 1) (k 2) z])
      (<q = 'mix) (: k (colour (q 1)) [4 (k 0) (k 1) (k 2) (f (q 2))])
      (<q = 'fbm) [6 (f (q 1)) (f (q 2)) (f (q 3)) (f s)]
      (: sx (f (q 1)) sy (f (#q @ 4 (q 2) (q 1))) [5 sx sy (f (q (#q - 1))) (f s)])))
 (plan q s bx) (? (two? (paint q s [1 1])) [[bx 0 [0.0 0.0 0.0 0.0] s (paint-plan q s) ()]]
   (inner q != ()) (: b (bx + map f (take 4 >q)) (catmap (p \ plan (p 0) (p 1) b) (seeded (inner q) s)))
   (<q = 'poly) (: a >q n (#a - 1) [[bx 11 (map f (take n a)) s (paint-plan (a n) s) ()]])
   (<q = 'bevel) (: a >q [[bx 10 (map f (take 3 a)) s (paint-plan (a 3) s) (paint-plan (a 4) (s + 1))]])
   (<q = 'oval) (: a >q [[bx 15 (turned a) s (paint-plan (a 5) s) ()]])
   (<q = 'ball) [[bx 16 (ball-nums >q) s (paint-plan '(shade 1) s) ()]]
   (<q = 'relief) (: a >q [[bx 17 (map f a + [0.0]) s (paint-plan '(shade 1) s) ()]])
   (<q = 'stain) (: a >q [[bx 18 (map f (take 4 a)) s (paint-plan (a 4) s) ()]])
   (: k <q a >q t (takes k) [[bx (shapes k) (map f (take t a) + map (_ \ 0.0) ^(4 - t)) s (paint-plan (a t) s) ()]]))
 (swatch-plan l) (? (two? (layers l 211 [1 1])) (catmap (p \ plan (p 0) (p 1) ()) (seeded l 211)))
 (swatch w h l) (swatch-pic w h (swatch-plan (unart l w h))))
) ; module swatch
