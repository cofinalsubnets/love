; mesh -- levels drawn in triangles: meshes built from shapes, lit by sun or lamps, packed
; for facets; a camera; textures; the frame out as half blocks, kitty's pixels, or a window.
; the world is lore's: x right, y up, z ahead when 'th is 0, 'th turning toward x.
(module (mesh mesh mesh-join mesh-move mesh-quad mesh-box mesh-grid mesh-lathe mesh-sheet mesh-rod mesh-dots mesh-normals
         mesh-keep mesh-keep-all mesh-pack mesh-bake mesh-bake-sun mesh-sun-view mesh-sun-map mesh-open
         mesh-lamp mesh-lamp-row mesh-lamps mesh-lamps! mesh-shine mesh-glow mesh-pic mesh-tex mesh-rgba
         mesh-view mesh-eye mesh-dirs mesh-spot mesh-sky mesh-haze mesh-frame mesh-flat
         mesh-cells mesh-kitty mesh-kitty? mesh-kitty-del mesh-mode mesh-size mesh-dims mesh-show mesh-win mesh-gone)
(borrow 'view)
(borrow 'window)
(borrow 'vec)
(borrow 'sky)
(:
 ; a mesh: [vs ts], each vertex [x y z u v nx ny nz r g b], each triangle [a b c tex], tex -1 none
 (mesh vs ts) [vs ts]
 (mesh-join ms) (: (go ms k vs ts) (atom? ms ? (mesh (cats (rev vs)) (cats (rev ts)))
                   (: m <ms (go >ms (k + #(m 0)) (m 0 . vs) (map (t \ [(t 0 + k) (t 1 + k) (t 2 + k) (t 3)]) (m 1) . ts))))
                   (go ms 0 () ()))
 ; turned by yaw about y (toward x as 'th turns), then moved by d
 (mesh-move m d yaw) (: c (cos yaw) s (sin yaw)
   (rot x z) [(x * c + z * s) (z * c - x * s)]
   (mesh (map (v \ (: p (rot (v 0) (v 2)) q (rot (v 5) (v 7))
                     [(p 0 + d 0) (v 1 + d 1) (p 1 + d 2) (v 3) (v 4) (q 0) (v 6) (q 1) (v 8) (v 9) (v 10)]))
              (m 0))
         (m 1)))
 ; four corners, their texels, a texture and a colour: two triangles, front where they turn anticlockwise
 (mesh-quad ps uvs tex col) (: n (unit (cross (c- (ps 3) (ps 0)) (c- (ps 1) (ps 0))))
   (mesh (map (i \ ps i + uvs i + n + col) ^4) [[0 1 2 tex] [0 2 3 tex]]))
 ; a box about c, half sizes h, turned by yaw; its texels k a unit
 (mesh-box c h yaw tex col k)
  (: (p sx sy sz) [(sx * h 0) (sy * h 1) (sz * h 2)]
     (face a b d e w v) (mesh-quad [a b d e] [[0.0 (k * v)] [(k * w) (k * v)] [(k * w) 0.0] [0.0 0.0]] tex col)
     W (2.0 * h 0) H (2.0 * h 1) D (2.0 * h 2)
     m (mesh-join [(face (p -1 -1 -1) (p 1 -1 -1) (p 1 1 -1) (p -1 1 -1) W H)
                   (face (p 1 -1 1) (p -1 -1 1) (p -1 1 1) (p 1 1 1) W H)
                   (face (p -1 -1 1) (p -1 -1 -1) (p -1 1 -1) (p -1 1 1) D H)
                   (face (p 1 -1 -1) (p 1 -1 1) (p 1 1 1) (p 1 1 -1) D H)
                   (face (p -1 1 -1) (p 1 1 -1) (p 1 1 1) (p -1 1 1) W D)
                   (face (p -1 -1 1) (p 1 -1 1) (p 1 -1 -1) (p -1 -1 -1) W D)])
     (mesh-move m c yaw))
 ; a sheet of nu by nv cells, (f i j) placing each corner [x y z u v]; its normals smooth
 (mesh-grid nu nv f tex col)
  (: vs (cats (map (i \ map (j \ f i j + [0.0 0.0 0.0] + col) ^(nv + 1)) ^(nu + 1)))
     (at i j) (i * (nv + 1) + j)
     ts (cats (map (k \ (: i (k // nv) j (k % nv) a (at i j) b (at (i + 1) j) c (at (i + 1) (j + 1)) d (at i (j + 1))
                        [[a b c tex] [a c d tex]]))
                  ^(nu * nv)))
     (mesh-normals (mesh vs ts)))
 ; a profile of [r y] turned n times round the y axis, its texels k a unit
 (mesh-lathe prof n tex col k)
  (: (len i) (: (go j s) (j < i ? (go (j + 1) (s + sqrt (sq (prof (j + 1) 0 - prof j 0) + sq (prof (j + 1) 1 - prof j 1)))) s) (go 0 0.0))
     (mesh-grid n (#prof - 1)
       (\ i j (: a (tau * i / n) r (prof j 0)
                  [(r * sin a) (prof j 1) (r * cos a) (k * a * prof 0 0) (k * len j)]))
       tex col))
 ; a flat sheet from o along U and V, nu by nv cells, front toward n, (uv p) the texels at p
 (mesh-sheet o U V nu nv n uv tex col)
  (: fl (dot (cross V U) n < 0.0) A (fl ? V U) B (fl ? U V) a (fl ? nv nu) b (fl ? nu nv)
     (mesh-grid a b (\ i j (: p (c+ o (c+ (c* (1.0 * i / a) A) (c* (1.0 * j / b) B))) (p + uv p))) tex col))
 ; an open tube from a to b, radius r, n sides, ts metres a texel
 (mesh-rod a b r col n tex ts) (: ax (c- b a) u (unit ax) p1 (side u) p2 (cross u p1) L (sqrt (dot ax ax))
   (ring c k) (map (j \ (: an (tau * j / n) o (c+ (c* (cos an) p1) (c* (sin an) p2))
                          (c+ c (c* r o) + [(r * an / ts) (k * L / ts)] + o + col))) ^(n + 1))
   (mesh (cat (ring a 0.0) (ring b 1.0))
         (cats (map (j \ (: m (n + 1 + j) [[j (j + 1) (m + 1) tex] [j (m + 1) m tex]])) ^n))))
 ; n triangles by the tray for facets: ps three corners [x y z] of n-trays, sky and sun their
 ; [r g b] light, tex -1 none, -2 a glow. [verts tris], 11 a vertex
 (mesh-dots ps sky sun tex) (: n #(ps 0 0) i (iota n)
   (vtx q) [(ps q 0) (ps q 1) (ps q 2) 0.0 0.0 (sky 0) (sky 1) (sky 2) (sun 0) (sun 1) (sun 2)]
   [(lace (cats (map vtx ^3))) (int (lace [(i * 3) (i * 3 + 1) (i * 3 + 2) tex]))])
 ; the vertices' first m parts as trays, and their places [x y z], indexable; a triangle t's corners
 (columns vs m) (: n #vs (map (k \ gem-tray [n] (map (v \ 1.0 * v k) vs)) ^m))
 (places vs) (columns vs 3)
 (at3 P i) [(peep (P 0) i 0.0) (peep (P 1) i 0.0) (peep (P 2) i 0.0)]
 (corners P t) [(at3 P (t 0)) (at3 P (t 1)) (at3 P (t 2))]
 ; ..each with its index, in order
 (indexed l) (rev (<>(foldl (\ st v [(<st + 1) ([v <st] . <>st)]) [0 ()] l)))
 ; only the triangles whose middles (keep? x y z)
 (mesh-keep m keep?) (: P (places (m 0))
   (mesh (m 0) (filter (t \ (corners P t @ [a b c]
                             (keep? ((a 0 + b 0 + c 0) / 3.0) ((a 1 + b 1 + c 1) / 3.0) ((a 2 + b 2 + c 2) / 3.0))))
                       (m 1))))
 ; ..or only those whose corners all (keep? x y z)
 (mesh-keep-all m keep?) (: P (places (m 0))
   (ok i) (at3 P i @ v (keep? (v 0) (v 1) (v 2)))
   (mesh (m 0) (filter (t \ ok (t 0) && ok (t 1) && ok (t 2)) (m 1))))
 ; each vertex's normal the sum of its faces', weighed by their size
 (mesh-normals m) (: vs (m 0) P (places vs) acc {}
   (add i n) (pin acc i (peep acc i [0.0 0.0 0.0] @ o [(o 0 + n 0) (o 1 + n 1) (o 2 + n 2)]))
   _ (each (m 1) (t \ (corners P t @ [a b c]
                        (cross (c- c a) (c- b a) @ n (add (t 0) n, add (t 1) n, add (t 2) n)))))
   (mesh (map (q \ (: v <q n (unit (peep acc <>q [0.0 1.0 0.0])) (take 5 v + n + drop 8 v))) (indexed vs)) (m 1)))
 ; a mesh packed for drawing: its vertices as 11 column trays, its triangles as facets' tray
 (mesh-pack m) (: vs (m 0) n #vs ft (cats (m 1))
   {'n n 'cols (columns vs 11) 'tris (star-tray [#ft] ft)})
 ; ..lit by sun and ambient: (light cols) gives each vertex's [sun sky glow] shares, glow ()
 ; or an [r g b]; the scene [verts tris] mesh-frame draws
 (mesh-bake pk lt light gain) (: c (pk 'cols) n (pk 'n) s (lt 'sun) amb (lt 'amb) sc (lt 'sunc)
   L (light c)
   sun (max 0.0 (c 5 * s 0 + c 6 * s 1 + c 7 * s 2) * (L 0) * lt 'sunk)
   (lit k) (gain * c (8 + k) * ((L 1) * amb k + sun * sc k + (two? (L 2) ? (L 2 k) 0.0)))
   [(lace [(c 0) (c 1) (c 2) (c 3) (c 4) (lit 0) (lit 1) (lit 2)]) (pk 'tris)])
 ; ..or the sun's light apart, for a frame shaded by the sun's view: 11 a vertex
 (mesh-bake-sun pk lt light gain) (: c (pk 'cols) n (pk 'n) s (lt 'sun) amb (lt 'amb) sc (lt 'sunc)
   L (light c)
   sun (max 0.0 (c 5 * s 0 + c 6 * s 1 + c 7 * s 2) * (L 0) * lt 'sunk)
   (sky k) (gain * c (8 + k) * ((L 1) * amb k + (two? (L 2) ? (L 2 k) 0.0)))
   (lit k) (gain * c (8 + k) * sun * sc k)
   [(lace [(c 0) (c 1) (c 2) (c 3) (c 4) (sky 0) (sky 1) (sky 2) (lit 0) (lit 1) (lit 2)]) (pk 'tris)])
 ; the sun's view matrix round c: half metres either side, deep along the light
 (mesh-sun-view lt c half deep) (: s (lt 'sun)
   r (unit (mag (s 1) < 0.99 ? (cross [0.0 1.0 0.0] s) [1.0 0.0 0.0])) u (cross s r)
   (row a k) [(a 0 / k) (a 1 / k) (a 2 / k) (0.0 - dot a c / k)]
   (gem-tray [16] (row r half + row u half + row (c- [0.0 0.0 0.0] s) deep + [0.0 0.0 0.0 1.0])))
 ; ..and its n by n depth tray of a sun-apart scene, for mesh-frame's sun
 (mesh-sun-map sv sc n)
   (facets n n -1 sv (sc 0) (sc 1) () [(gem-tray [6] [0.0 0.0 0.0 0.0 0.0 16.0]) () ()])
 ; ..the light for a level with nothing to cast a shadow
 (mesh-open c) [1.0 (0.6 + 0.4 * c 6) ()]
 ; --- lamps: {'at points 'c [r g b] 'r reach}, optional 'n a facing, 'soft, 'wrap, and
 ;     'keep a plan box [x0 z0 x1 z1]. c at a metre, shared among the points, falls off by
 ;     the square to none at the reach; 'wrap rounds it onto what it grazes. no shadows:
 ;     it lights only what stands in its box ---
 ; a lamp as lamp-light takes it (src/love/lamp.c)
 (mesh-lamp-row lp) [(lp 'at) (lp 'r) (lp 'c) (peep lp 'n ()) (sq (peep lp 'soft 0.1)) (peep lp 'wrap 0.0) (peep lp 'keep ())]
 ; ..its light on each vertex of a packed mesh: [r g b] trays, before the surface's colour
 (mesh-lamp pk lp) (lamp-light (pk 'cols) [(mesh-lamp-row lp)])
 ; ..and the mesh lit by amb [r g b] plus each lamp's chs times its ks: [verts tris] 8 a vertex
 (mesh-lamps pk amb chs ks gain) (: c (pk 'cols) n (pk 'n) z (c 0 * 0.0)
   (lit j) (gain * c (8 + j) * foldl (\ a i (a + ks i * chs i j)) (z + amb j) ^#chs)
   [(lace [(c 0) (c 1) (c 2) (c 3) (c 4) (lit 0) (lit 1) (lit 2)]) (pk 'tris)])
 ; ..the same into one buffer the packed mesh keeps, only colours rewritten: each call
 ; overwrites the last answer, so once a frame. amb, chs and gain are the first call's, and
 ; after it only the vertices a lamp reaches change, only when ks does
 (mesh-lamps! pk amb chs ks gain)
  (: (lit c8 base chs j) (gain * c8 j * foldl (\ a i (a + ks i * chs i j)) (base j) ^#chs)
     (pins3 v ix l) (foldl (\ v k (pin v (ix + 5 + k) (l k))) v ^3)
     (peep pk 'buf () @
      () (: c (pk 'cols) n (pk 'n) z (c 0 * 0.0) i (iota n * 8)
           base (map (j \ z + amb j) ^3) c8 (map (j \ c (8 + j)) ^3)
           v (pins3 (foldl (\ v k (pin v (i + k) (c k))) (iota (8 * n) * 0.0) ^5) i (lit c8 base chs))
           on (iota (foldl (\ a ch (a + ch 0 + ch 1 + ch 2)) z chs > 0.0)) (g t) (peep t on 0.0)
           _ (pins pk 'buf v 'live {'ix (on * 8) 'c8 (map g c8) 'base (map g base) 'chs (map (ch \ map g ch) chs)})
           [v (pk 'tris)])
      ; ..and nothing written while the lamps stand where they stood
      b (: lv (pk 'live) [(#(lv 'ix) = 0 || peep lv 'ks () = ks ? b (: _ (pin lv 'ks ks) (pins3 b (lv 'ix) (lit (lv 'c8) (lv 'base) (lv 'chs)))))
                          (pk 'tris)])))
 ; ..a mesh that is its own light, its colour times k and nothing on it
 (mesh-shine pk k) (mesh-lamps pk [k k k] () () 1.0)
 ; ..a copy of a scene with its triangles made glows
 (mesh-glow sc) (: ts (sc 1 + 0) [(sc 0) (pin ts (iota (#ts // 4) * 4 + 3) -2)])
 ; --- textures: w by h, (f x y) a colour [r g b] 0 to 1 or () a hole; each level halves,
 ;     a texel the mean of four, a hole where two or more were ---
 (q v) (int (sat v * 255.0 + 0.5))
 (word c) ((q (c 0) << 16) | (q (c 1) << 8) | q (c 2))
 (mesh-pic w h f)
  (: l0 (map (i \ f (i % w) (i // w)) ^(w * h))
     ; ..a level's texels by place, read in a step
     (down m n l0) (: l (foldl (\ t x (pin t #t x)) {} l0) a (m // 2) b (n // 2)
       (map (i \ (: x (2 * (i % a)) y (2 * (i // a))
                    q (filter two? [(l (y * m + x)) (l (y * m + x + 1)) (l ((y + 1) * m + x)) (l ((y + 1) * m + x + 1))])
                    (#q < 3 ? () (c* (1.0 / #q) (foldl c+ [0.0 0.0 0.0] q)))))
            ^(a * b)))
     (lay m n l) (star-tray [n m] (map (c \ two? c ? (word c) -1) l))
     (go m n l) (lay m n l . (m < 2 || n < 2 ? () (go (m // 2) (n // 2) (down m n l))))
     (go w h l0))
 (mesh-tex n f) (mesh-pic n n f)
 ; ..from rgba bytes sw by sh (png-decode's), a hole where mostly clear
 (mesh-rgba sw sh b w h)
  (mesh-pic w h (\ x y (: x0 (x * sw // w) x1 (max2 (x0 + 1) ((x + 1) * sw // w))
                          y0 (y * sh // h) y1 (max2 (y0 + 1) ((y + 1) * sh // h))
                          os (cats (map (j \ map (i \ 4 * (j * sw + i)) (map (+ x0) ^(x1 - x0))) (map (+ y0) ^(y1 - y0))))
                          (px k) (foldl (\ a o (a + b (o + k))) 0 os / (255.0 * #os))
                          (px 3 < 0.5 ? () [(px 0 / px 3) (px 1 / px 3) (px 2 / px 3)]))))
 ; --- the view: w by h, the eye at e facing th tilted up by ph, fov across; 'cam the
 ;     matrix facets takes, gl clip space ---
 (mesh-view w h e th ph fov near far) (mesh-eye w h e th ph 0.0 fov near far)
 ; ..and rolled ro toward the right
 (mesh-eye w h e th ph ro fov near far)
  (: st (sin th) ct (cos th) sp (sin ph) cp (cos ph) cr (cos ro) sr (sin ro)
     r0 [ct 0.0 (0.0 - st)] u0 [(0.0 - st * sp) cp (0.0 - ct * sp)] f [(st * cp) sp (ct * cp)]
     r (c+ (c* cr r0) (c* (0.0 - sr) u0)) u (c+ (c* cr u0) (c* sr r0))
     fx (1.0 / tan (fov / 2.0)) fy (fx * w / h)
     za ((far + near) / (far - near)) zb (-2.0 * far * near / (far - near))
     (row k a) [(k * a 0) (k * a 1) (k * a 2) (0.0 - k * dot a e)]
     z (row za f)
     {'w w 'h h 'e e 'th th 'ph ph 'fov fov 'r r 'u u 'f f
      'cam (gem-tray [16] (row fx r + row fy u + [(z 0) (z 1) (z 2) (z 3 + zb)] + row 1.0 f))})
 ; the directions through pixels ix of the view, unit [x y z] trays
 (mesh-dirs v ix) (: w (v 'w) (rays v (ix % w + 0.5) (ix // w + 0.5)))
 ; ..and through the points px py of the screen, in pixels from its top left
 (rays v px py) (: w (v 'w) h (v 'h) foc (w / 2.0 / tan (v 'fov / 2.0))
   U ((px - w / 2.0) / foc) V ((h / 2.0 - py) / foc) r (v 'r) u (v 'u) f (v 'f)
   x (f 0 + U * r 0 + V * u 0) y (f 1 + U * r 1 + V * u 1) z (f 2 + U * r 2 + V * u 2)
   l (sqrt (x * x + y * y + z * z))
   [(x / l) (y / l) (z / l)])
 ; ..and the pixels directions X Y Z (trays) fall on, -1 behind the eye or off the screen
 (mesh-spot v X Y Z) (: w (v 'w) h (v 'h) foc (w / 2.0 / tan (v 'fov / 2.0))
   r (v 'r) u (v 'u) f (v 'f)
   zc (X * f 0 + Y * f 1 + Z * f 2) zs (max zc 0.01)
   cx (floor (w / 2.0 + foc * (X * r 0 + Y * r 1 + Z * r 2) / zs))
   cy (floor (h / 2.0 - foc * (X * u 0 + Y * u 1 + Z * u 2) / zs))
   (over -1 ((0.05 < zc) * (0 <= cx) * (cx < w) * (0 <= cy) * (cy < h)) (cy * w + cx)))
 ; lore's sky for mesh-frame's bare: k 1 asks every bare pixel, stars ss a pixel each; k past
 ; 1 asks k by k corners and shades between by facets, stars put on by night
 (mesh-sky ss lt wx e sim t0 k)
  (: X (ss 'x) Y (ss 'y) Z (ss 'z)
     (shine c ix) (word (sky-tone lt (sky-stars! ss c lt wx (e 0) (e 2) sim t0 ix)))
     (k <= 1
      ? (\ v S (: at (pin (iota (v 'w * v 'h) * 0 - 1) S (iota #S)) d (mesh-dirs v S)
                  (shine (sky-colour-of lt wx (d 0) (d 1) (d 2) (e 0) (e 2) sim) (peep at (mesh-spot v X Y Z) -1))))
        [(v \ -1)
         (\ v f B (: g (sky-grid v lt wx e sim k f) sp (mesh-spot v X Y Z) ix (over -1 (peep f sp 0 = -1) (iota #X))
                     (1.0 <= lt 'day * 3.0 ? g (pin g (over -1 (0 <= ix) sp) (shine (sky-colour-of lt wx X Y Z (e 0) (e 2) sim) ix)))))]))
 ; the sky over f's bare pixels, asked every k pixels, a flat tray
 (sky-grid v lt wx e sim k f)
  (: w (v 'w) h (v 'h) gw (w // k + 2) gh (h // k + 2) G (iota (gw * gh)) gi (G % gw) gj (G // gw)
     d (rays v (1.0 * k * gi) (1.0 * k * gj))
     c (sky-colour-of lt wx (d 0) (d 1) (d 2) (e 0) (e 2) sim)
     z (G * 0.0)
     cols [(2.0 * k * gi / w - 1.0) (1.0 - 2.0 * k * gj / h) z z z (c 0) (c 1) (c 2)]
     vs (lace cols)
     C (iota ((gw - 1) * (gh - 1))) q (C // (gw - 1) * gw + C % (gw - 1))
     cs [q (q + 1) (q + gw + 1) (q * 0 - 1) q (q + gw + 1) (q + gw) (q * 0 - 1)]
     ts (lace cs)
     one (gem-tray [16] [1.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 1.0])
     (facets w h f one vs ts () (gem-tray [7] [0.0 0.0 0.0 0.0 0.0 96.0 (1.5 * lt 'expo)])))
 ; the sky low ahead before the gain, 0 to 255: the colour a far thing fades to
 (mesh-haze v lt wx sim) (: th (v 'th) e (v 'e)
   c (sky-near lt wx (gem-tray [1] [(sin th)]) (gem-tray [1] [0.02]) (gem-tray [1] [(cos th)]) (e 0) (e 2) sim)
   [(255.0 * peep (c 0) 0 0.0) (255.0 * peep (c 1) 0 0.0) (255.0 * peep (c 2) 0 0.0)])
 ; a frame, a flat w*h colour tray: sc [verts tris] or [verts tris sun], sun () or [view
 ; depths bias]; fog [r g b near far] 0 to 255; gain sky-tone's, 0 none; bare a colour,
 ; (\ v S ..) for bare pixels S, or [base over]: (base v) drawn under, (over v f B) finishes
 (mesh-frame v sc texs fog flags gain bare) (: B (two? bare ? (<bare v) -1)
   sun (#sc < 3 ? () (sc 2)) bias (two? sun ? (sun 2) 0.0)
   o (gem-tray [8] [(1.0 * fog 0) (1.0 * fog 1) (1.0 * fog 2) (1.0 * fog 3) (1.0 * fog 4) (1.0 * (flags | 64)) (1.0 * gain) bias])
   f (facets (v 'w) (v 'h) B (v 'cam) (sc 0) (sc 1) texs (#sc < 3 ? o [o (two? sun ? (sun 0) ()) (two? sun ? (sun 1) ())]))
   (? (two? bare) (<>bare v f B)
      (: S (iota (f = -1)) (#S = 0 ? f (pin f S (charm? bare ? bare (bare v S)))))))
 ; a frame's colours as [r g b] trays, 0 to 1
 (mesh-flat f) [((f >> 16 & 255) / 255.0) ((f >> 8 & 255) / 255.0) ((f & 255) / 255.0)]
 ; ..as half-block cells: 24-bit, or the 256 cube dithered by bay
 (mesh-cells f w h deep bay bands) (: c (mesh-flat f)
   (deep ? (view-deep-frame w h (view-deep-pens c) bands)
      (view-cube-pens c bay @ px (view-frame w h (y \ peep px (iota w + w * y) 0) bands))))
 ; ..or as kitty image id over cols by rows cells from the cursor, which stays
 (mesh-kitty f w h cols rows id) (: b (frame-bytes f 2 1) n #b o (jug 0)
   (go i) (: j (min n (i + 4096))
             (say o (esc + "_G" + (i = 0 ? ("a=T,f=24,q=2,C=1,z=-1,i=" + show id + ",s=" + show w + ",v=" + show h
                                            + ",c=" + show cols + ",r=" + show rows + ",") "")
                     + "m=" + (j < n ? "1" "0") + ";" + snip b i j + esc + "\\"),
              j < n ? (go j) (slurp o)))
   (go 0))
 ; ..a terminal that shows kitty's pixels, by its environment
 (mesh-kitty? _) (: (has e s) (has? (getenv e) s)
   (? (0 < #(getenv "MITTY")) 1 (has "TERM" "kitty") 1 (0 < #(getenv "KITTY_WINDOW_ID")) 1
      (has "TERM_PROGRAM" "ghostty") 1 (has "TERM_PROGRAM" "WezTerm") 1 0))
 ; ..and a picture taken down
 (mesh-kitty-del id) "\(esc)_Ga=d,d=I,i=\(id),q=2\(esc)\\"
 ; --- a level's screen: 'kitty 1 kitty's pixels, 'win a window, else half blocks ---
 (mesh-mode md) (md @ 'kitty 1 'cells 0 'window 0 (mesh-kitty? ()))
 ; ..w cells by r rows, two pixels a row; 'kp pixels a column: kitty aims at kitty-w across.
 ; a window's picture is 'pic-w by 'pic-h, the window over 'scale (1 2 4 or 8, else 2): each
 ; of its pixels 'scale of the window's each way
 kitty-w 640
 (mesh-scale st) (peep st 'scale 2 @ s (elem s [1 2 4 8] ? s 2))
 (mesh-size st w r) (: h (2 * r) s (mesh-scale st) win (peep st 'win ())
   wh (tablet? win ? (window-size win) [(8 * w) (16 * r)]) pw (max2 1 ((tablet? win ? (wh 0) kitty-w) // s)) ph (max2 1 (pw * wh 1 // max2 1 (wh 0)))
   (pins (view! st w h r) 'bay (view-bayer w h) 'pic-w pw 'pic-h ph
         'kp (? (tablet? win) (max2 1 (pw // 160)) (st 'kitty) (max2 1 (kitty-w // w // s)) 1)))
 ; ..the picture a frame is: in a window 'pic-w by 'pic-h, else 'kp pixels a cell
 (mesh-dims st) (: k (peep st 'kp 1) (tablet? (peep st 'win ()) ? [(st 'pic-w) (st 'pic-h)] [(k * st 'w) (k * st 'h)]))
 ; ..a frame f: kitty alternates ids 7 and 8 in one synchronised update, the old taken down
 ; once the new is over it (one id reused blanks first); or the cells, bands over them
 (mesh-show st f text bands) (: w (st 'w) h (st 'h) k (peep st 'kp 1)
   (? (peep st 'win ()) (mesh-win st f bands)
      (st 'kitty)
      (: n (peep st 'kn 0) _ (pin st 'kn (1 - n))
         (esc + "[?2026h" + mesh-kitty f (k * w) (k * h) w (h // 2) (7 + n) + mesh-kitty-del (8 - n)
          + text + esc + "[?2026l"))
      (esc + "[?2026h" + mesh-cells f w h (st 'deep) (st 'deep ? 0 (st 'bay)) bands + esc + "[?2026l")))
 ; ..or to a window: the picture sent for the server to enlarge, else painted onto the
 ; paper as often as fits; bands then 'over in 8 by 16 cells, only their rows shown when
 ; the server enlarged the rest; answers ""
 (mesh-win st f bands) (: win (st 'win) d (mesh-dims st) w <d h (d 1)
   wh (window-size win) W <wh H (wh 1) P (window-paper win)
   Q (peep st 'pic-n 0 = w * h ? (st 'pic) (: q (cask (w * h * 4)) _ (pins st 'pic q 'pic-n (w * h)) q))
   _ (frame-paint f w 1 Q w)
   up (window-blit win Q w h)
   ov (peep st 'over {}) rs (sort (keys bands + keys ov))
   _ (up ? (each rs (r \ mesh-under f w h P W H r)) (frame-paint f w (max2 1 (min2 (W // w) (H // h))) P W))
   _ (each (sort (keys bands)) (r \ mesh-band st P W H r (bands r)))
   _ (each (sort (keys ov)) (r \ mesh-band st P W H r (ov r)))
   _ (? up (each rs (r \ window-show win (16 * r) (16 * r + 16))) (window-show win 0 H))
   "")
 ; ..the paper's cell row r laid from the picture f w by h, enlarged to the window W by H
 (mesh-under f w h P W H r) (: y0 (16 * r) n (min2 16 (H - y0))
   (? (0 < n) (: I (iota (W * n)) X (I % W) Y (I // W + y0) g (peep f (Y * h // H * w + X * w // W) 0) T (cask (W * n * 4))
              _ (frame-paint g W 1 T W) (pour P (y0 * W * 4) T 0 (W * n * 4)))
      0))
 ; ..a band [x0 cells fg bg] on cell row r: pens six bits a channel, or the 256
 (mesh-band st P W H r bd) (: x0 (bd 0) cs (bd 1) n #cs
   (pen p bg) (? !(st 'deep) (esc + "[" + (bg ? "48" "38") + ";5;" + show p + "m")
                 (: (ch k) (show ((p >> k & 63) * 255 // 63))
                    (esc + "[" + (bg ? "48" "38") + ";2;" + ch 12 + ";" + ch 6 + ";" + ch 0 + "m")))
   sc (screen (cask (screen () 1 n)) 1 n)
   _ (scribe sc (pen (bd 2) 0 + pen (bd 3) 1 + foldl (+) "" cs))
   bw (n * 8) t (cask (bw * 64))
   _ (dye sc t bw 0 -1 ())
   cw (4 * max 0 (min bw (W - x0 * 8)))
   (0 < cw ? (each ^(min 16 (H - r * 16)) (j \ pour P (((r * 16 + j) * W + x0 * 8) * 4) t (j * bw * 4) cw))))
 ; ..and both taken down when the level is left
 mesh-gone (mesh-kitty-del 7 + mesh-kitty-del 8))
) ; module mesh
