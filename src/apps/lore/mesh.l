; mesh -- levels drawn in triangles: meshes built from shapes, lit by sun or lamps, packed
; for facets; a camera; textures; the frame out as half blocks, kitty's pixels, or a window.
; the world is lore's: x right, y up, z ahead when 'th is 0, 'th turning toward x.
(module (mesh mesh mesh-join mesh-move mesh-quad mesh-box mesh-grid mesh-lathe mesh-sheet mesh-rod mesh-dots mesh-halo mesh-normals
         mesh-keep mesh-keep-all mesh-pack mesh-bake mesh-bake-sun mesh-sun-view mesh-sun-map mesh-open
         mesh-lamp mesh-lamp-row mesh-lamps mesh-lamps! mesh-lit-ks mesh-lamp-slots mesh-sun-slots mesh-shine mesh-glow mesh-pic mesh-tex mesh-rgba
         mesh-view mesh-eye mesh-aim mesh-dirs mesh-spot mesh-step mesh-sky mesh-sky-memo mesh-haze mesh-frame mesh-gpu mesh-coarse mesh-flat
         mesh-cells mesh-kitty mesh-kitty? mesh-kitty-del mesh-mode mesh-size mesh-dims mesh-sway mesh-show mesh-win mesh-paint mesh-gone
         mesh-glb mesh-glb-of)
(borrow '(view window vec sky json gpu quay))
(borrow 'lore)                          ; lamp-light, facets, lace and the frame's layouts, in C
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
  (: vs (catmap (i \ map (j \ f i j + [0.0 0.0 0.0] + col) ^(nv + 1)) ^(nu + 1))
     (at i j) (i * (nv + 1) + j)
     ts (catmap (k \ (: i (k // nv) j (k % nv) a (at i j) b (at (i + 1) j) c (at (i + 1) (j + 1)) d (at i (j + 1))
                        [[a b c tex] [a c d tex]]))
                  ^(nu * nv))
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
         (catmap (j \ (: m (n + 1 + j) [[j (j + 1) (m + 1) tex] [j (m + 1) m tex]])) ^n)))
 ; n triangles by the tray for facets: ps three corners [x y z] of n-trays, sky and sun their
 ; [r g b] light, tex -1 none, -2 a glow. [verts tris], 11 a vertex
 (mesh-dots ps sky sun tex) (: n #(ps 0 0) i (iota n)
   (vtx q) [(ps q 0) (ps q 1) (ps q 2) 0.0 0.0 (sky 0) (sky 1) (sky 2) (sun 0) (sun 1) (sun 2)]
   [(lace (catmap vtx ^3)) (int (lace [(i * 3) (i * 3 + 1) (i * 3 + 2) tex]))])
 ; a glow round each of ps, r across, its colour col: a disc each, turned by facets to face the
 ; eye by its u v, bright in the middle and falling as a bell to none at its rim
 (mesh-halo ps r col) (: n 12 rs [0.3 0.6 1.0] m (#rs - 1) k (1 + #rs * n)
   (bell a) ((exp (-6.0 * a * a) - exp -6.0) / (1.0 - exp -6.0))
   ring ([0.0 0.0 1.0] . catmap (a \ map (i \ [(a * r * cos (tau * i / n)) (a * r * sin (tau * i / n)) (bell a)]) ^n) rs)
   (at j i) (1 + j * n + i % n)
   ts (map (i \ [0 (at 0 i) (at 0 (i + 1)) -1]) ^n
       + catmap (j \ catmap (i \ (: a (at j i) b (at j (i + 1)) c (at (j + 1) i) d (at (j + 1) (i + 1))
                                  [[a d b -1] [a c d -1]])) ^n) ^m)
   (mesh (catmap (p \ map (q \ [(p 0) (p 1) (p 2) (q 0) (q 1) 0.0 0.0 0.0 (q 2 * col 0) (q 2 * col 1) (q 2 * col 2)]) ring) ps)
         (catmap (o \ map (t \ [(t 0 + o) (t 1 + o) (t 2 + o) -1]) ts) (map (j \ j * k) ^#ps))))
 ; the vertices' first m parts as trays, and their places [x y z], indexable; a triangle t's corners
 (columns vs m) (: n #vs (map (k \ gem-tray [n] (map (v \ 1.0 * v k) vs)) ^m))
 (places vs) (columns vs 3)
 (at3 P i) [(P 0 i) (P 1 i) (P 2 i)]
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
   (row a k) [(a 0 / k) (a 1 / k) (a 2 / k) -(dot a c / k)]
   (gem-tray [16] (row r half + row u half + row (c- [0.0 0.0 0.0] s) deep + [0.0 0.0 0.0 1.0])))
 ; ..and its n by n depth tray of a sun-apart scene, for mesh-frame's sun
 (mesh-sun-map sv sc n)
   (facets n n -1 sv (sc 0) (sc 1) () [(gem-tray [6] [0.0 0.0 0.0 0.0 0.0 16.0]) () ()])
 ; ..the light for a level with nothing to cast a shadow
 (mesh-open c) [1.0 (0.6 + 0.4 * c 6) ()]
 ; --- lamps: {'at points 'c [r g b] 'r reach}, optional 'n a facing, 'soft, 'wrap, and
 ;     'keep a plan box [x0 z0 x1 z1], or [x0 z0 x1 z1 y0 y1] between two heights too. c
 ;     at a metre, shared among the points, falls off by the square to none at the reach;
 ;     'wrap rounds it onto what it grazes. no shadows: it lights only what stands in its box ---
 ; a lamp as lamp-light takes it (src/love/lamp.c)
 (mesh-lamp-row lp) [(lp 'at) (lp 'r) (lp 'c) (lp 'n) (sq (peep lp 'soft 0.1)) (peep lp 'wrap 0.0) (lp 'keep)]
 ; ..its light on each vertex of a packed mesh: [r g b] trays, before the surface's colour
 (mesh-lamp pk lp) (lamp-light (pk 'cols) [(mesh-lamp-row lp)])
 ; ..and the mesh lit by amb [r g b] plus each lamp's chs times its ks: [verts tris] 8 a vertex
 (mesh-lamps pk amb chs ks gain) (: c (pk 'cols) n (pk 'n) z (c 0 * 0.0)
   (lit j) (gain * c (8 + j) * foldl (\ a i (a + ks i * chs i j)) (z + amb j) ^#chs)
   [(lace [(c 0) (c 1) (c 2) (c 3) (c 4) (lit 0) (lit 1) (lit 2)]) (pk 'tris)])
 ; ..the same kept on the packed mesh, only colours rewritten: amb, chs and gain are the
 ; first call's, and after it only the vertices a lamp reaches change, only when the ks of
 ; the lamps that reach it do
 (mesh-lamps! pk amb chs ks gain)
  (: (lit c8 base chs j) (gain * c8 j * foldl (\ a i (a + ks i * chs i j)) (base j) ^#chs)
     (pins3 v ix l) (foldl (\ v k (pin v (ix + 5 + k) (l k))) v ^3)
     (pk 'buf @
      () (: c (pk 'cols) n (pk 'n) z (c 0 * 0.0) i (iota n * 8)
           base (map (j \ z + amb j) ^3) c8 (map (j \ c (8 + j)) ^3)
           v (pins3 (foldl (\ v k (pin v (i + k) (c k))) (iota (8 * n) * 0.0) ^5) i (lit c8 base chs))
           on (iota (foldl (\ a ch (a + ch 0 + ch 1 + ch 2)) z chs > 0.0)) (g t) (peep t on 0.0)
           r (filter (i \ net (chs i 0 + chs i 1 + chs i 2) > 0.0) ^#chs)
           _ (pins pk 'buf v 'live {'ix (on * 8) 'c8 (map g c8) 'base (map g base) 'chs (map (map g) chs) 'r r 'ks (map ks r)})
           [v (pk 'tris)])
      ; ..and nothing written while the lamps stand where they stood
      b (: lv (pk 'live) kr (map ks (lv 'r)) [(#(lv 'ix) = 0 || lv 'ks = kr ? b
                           (: _ (pin lv 'ks kr) v (pins3 b (lv 'ix) (lit (lv 'c8) (lv 'base) (lv 'chs))) (pin pk 'buf v, v)))
                          (pk 'tris)])))
 ; ..the ks of the lamps that reach a mesh mesh-lamps! keeps, all of them before it has
 (mesh-lit-ks pk ks) (pk 'live @ () ks lv (map ks (lv 'r)))
 ; ..a mesh mesh-lamps! keeps, for a gpu to light: [verts li cols], its verts lit with the lamps
 ; that reach it out, li those lamps, 8 at most, and cols 24 numbers a vertex, slot k lamp li
 ; k's light there at full strength; () where none or more than 8 reach it. made once, kept
 (mesh-lamp-slots pk) (: lv (peep pk 'live ()) r (tablet? lv ? (lv 'r) ())
   (? (!(two? r) || #r > 8) ()
      (pk 'slots @ ()
         (: ix (lv 'ix) on (ix // 8) n (pk 'n) c8 (lv 'c8)
            v (foldl (\ v j (pin v (ix + 5 + j) (c8 j * lv 'base j))) (pk 'buf) ^3)
            cs (foldl (\ a k (foldl (\ a j (pin a (on * 24 + 3 * k + j) (c8 j * lv 'chs (r k) j))) a ^3)) (iota (24 * n) * 0.0) ^#r)
            q [v (r + map (_ \ 0) ^(8 - #r)) cs]
            (pin pk 'slots q, q))
         q q)))
 ; ..a mesh's sun su [r g b] trays, its own colour's, for a gpu to shade: 3 numbers a vertex, kept
 (mesh-sun-slots pk su gain) (pk 'sunned @ () (: c (pk 'cols) q (lace (map (j \ gain * c (8 + j) * su j) ^3)) (pin pk 'sunned q, q)) q q)
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
  (mesh-pic w h (\ x y (: x0 (x * sw // w) x1 (max (x0 + 1) ((x + 1) * sw // w))
                          y0 (y * sh // h) y1 (max (y0 + 1) ((y + 1) * sh // h))
                          os (catmap (j \ map (i \ 4 * (j * sw + i)) (map (+ x0) ^(x1 - x0))) (map (+ y0) ^(y1 - y0)))
                          (px k) (foldl (\ a o (a + b (o + k))) 0 os / (255.0 * #os))
                          (px 3 < 0.5 ? () [(px 0 / px 3) (px 1 / px 3) (px 2 / px 3)]))))
 ; --- the view: w by h, the eye at e facing th tilted up by ph, fov across; 'cam the
 ;     matrix facets takes, gl clip space ---
 (mesh-view w h e th ph fov near far) (mesh-eye w h e th ph 0.0 fov near far)
 ; ..and rolled ro toward the right
 (mesh-eye w h e th ph ro fov near far)
  (: st (sin th) ct (cos th) sp (sin ph) cp (cos ph) cr (cos ro) sr (sin ro)
     r0 [ct 0.0 -st] u0 [-(st * sp) cp -(ct * sp)] f [(st * cp) sp (ct * cp)]
     r (c+ (c* cr r0) (c* -sr u0)) u (c+ (c* cr u0) (c* sr r0))
     (pins (mesh-aim w h e r u f fov near far) 'th th 'ph ph))
 ; ..or with its right, up and ahead given, unit and square
 (mesh-aim w h e r u f fov near far)
  (: fx (1.0 / tan (fov / 2.0)) fy (fx * w / h)
     za ((far + near) / (far - near)) zb (-2.0 * far * near / (far - near))
     (row k a) [(k * a 0) (k * a 1) (k * a 2) -(k * dot a e)]
     z (row za f)
     {'w w 'h h 'e e 'fov fov 'near near 'far far 'r r 'u u 'f f
      'cam (gem-tray [16] (row fx r + row fy u + [(z 0) (z 1) (z 2) (z 3 + zb)] + row 1.0 f))})
 ; the directions through pixels ix of the view, unit [x y z] trays
 (mesh-dirs v ix) (: w (v 'w) (rays v (ix % w + 0.5) (ix // w + 0.5)))
 ; ..and through the points px py of the screen, in pixels from its top left
 (rays v px py) (: w (v 'w) h (v 'h) foc (w / 2.0 / tan (v 'fov / 2.0))
   U ((px - w / 2.0) / foc) V ((h / 2.0 - py) / foc) r (v 'r) u (v 'u) f (v 'f)
   x (f 0 + U * r 0 + V * u 0) y (f 1 + U * r 1 + V * u 1) z (f 2 + U * r 2 + V * u 2)
   l (sqrt (2 x + 2 y + 2 z))
   [(x / l) (y / l) (z / l)])
 ; ..and the pixels directions X Y Z (trays) fall on, -1 behind the eye or off the screen
 (mesh-spot v X Y Z) (: w (v 'w) h (v 'h) foc (w / 2.0 / tan (v 'fov / 2.0))
   r (v 'r) u (v 'u) f (v 'f)
   zc (X * f 0 + Y * f 1 + Z * f 2) zs (max zc 0.01)
   cx (floor (w / 2.0 + foc * (X * r 0 + Y * r 1 + Z * r 2) / zs))
   cy (floor (h / 2.0 - foc * (X * u 0 + Y * u 1 + Z * u 2) / zs))
   (over -1 ((0.05 < zc) * (0 <= cx) * (cx < w) * (0 <= cy) * (cy < h)) (cy * w + cx)))
 ; lore's sky for mesh-frame's bare: k 1 asks every bare pixel, stars ss a pixel each; k past
 ; 1 asks about every k pixels on directions fixed to the sky and shades between by facets,
 ; stars put on by night; nothing asked where no pixel is bare. past 1, a third part for a gpu:
 ; the grid's mesh and the spots it lays, [verts tris tone [S C] e] or (), what lays the disc or
 ; the stars after, and their spots for a frame the gpu kept, [S C] or (). a sky with no 'turn
 ; the gpu asks a pixel at a time instead, [() () tone [S C] e [nums map air]]: sky-gpu's, then the
 ; view's right, up, ahead, focal length, step, width, height and
 ; the sun's share its light was made with, 0 for no shadows of the clouds; LORE_SKY_PX 0 keeps the grid
 (mesh-sky ss lt wx e sim t0 k sm)
  (: X (ss 'x) Y (ss 'y) Z (ss 'z)
     (shine c ix) (word (sky-tone lt (sky-stars! ss c lt wx (e 0) (e 2) sim t0 ix)))
     ; ..by day the bare pixels about the sun asked one each, clouds as coarse as the grid's: its corners too few to round the disc
     (disc v ok) (: s (lt 'sun) w (v 'w) h (v 'h) zc (dot s (v 'f))
       (zc < 0.1 ? ()
          (: foc (w / 2.0 / tan (v 'fov / 2.0)) ca (cos (sun-r + 2.0 * mesh-step v k)) R (int (foc * tan (sun-r + 2.0 * mesh-step v k) / zc) + 2)
             cx (int (floor (w / 2.0 + foc * dot s (v 'r) / zc))) cy (int (floor (h / 2.0 - foc * dot s (v 'u) / zc)))
             ; ..the box about it cut to the frame first, so a disc off it asks nothing
             x0 (max 0 (cx - R)) x1 (min (w - 1) (cx + R)) y0 (max 0 (cy - R)) y1 (min (h - 1) (cy + R))
             (x1 < x0 || y1 < y0 ? ()
                (: bw (x1 - x0 + 1) J (iota (bw * (y1 - y0 + 1))) S0 ((y0 + J // bw) * w + x0 + J % bw)
                   S1 (S0 (iota (ok S0))) d (#S1 @ 0 () (mesh-dirs v S1))
                   I (#S1 @ 0 S1 (iota (d 0 * s 0 + d 1 * s 1 + d 2 * s 2 > ca)))
                   (#I = 0 ? () [(S1 I) (shine (sky-colour-at lt wx (mesh-step v k) (d 0 I) (d 1 I) (d 2 I) (e 0) (e 2) sim) ())]))))))
     sun-r 0.0316                       ; the disc's radius, acos 0.9995 as sky.l draws it
     ; ..the disc while it is up, the stars by night, on the pixels ok holds of: [S C] their indices,
     ; -1 for none, and their colours, or ()
     (spots v ok) (? (1.0 <= lt 'day * 3.0) (disc v ok)
                     (: sp (mesh-spot v X Y Z) ix (over -1 (ok sp) (iota #X))
                        st [(over -1 (0 <= ix) sp) (shine (sky-colour-at lt wx (mesh-step v 1) X Y Z (e 0) (e 2) sim) ix)]
                        (lt 'hi < (two? (lt 'turn) ? -0.4 -0.06) ? st (disc v ok @ () st d (map (k \ glued (st k) (d k)) ^2)))))
     (glued a b) (: n #a i (iota (n + #b)) (over (peep b (i - n) 0) (i < n) (peep a i 0)))
     ; ..laid on g where f was bare, as b? tells: through a glass's tint or onto a glow kept there
     (lay v f g b?) (spots v (S \ b? (peep f S 0)) @ () g q (pin g (q 0) (glowed (q 1) (peep f (q 0) 0 @ F ((F < 0) * (-1 - F))))))
     (k <= 1
      ? (\ v S (: at (pin (iota (v 'w * v 'h) * 0 - 1) S (iota #S)) d (mesh-dirs v S)
                  (shine (sky-colour-at lt wx (mesh-step v 1) (d 0) (d 1) (d 2) (e 0) (e 2) sim) (peep at (mesh-spot v X Y Z) -1))))
        [(v \ -1)
         (\ v f B (? (!(aany (f < 0))) f (lay v f (sky-grid v lt wx e sim k f sm) (x \ x < 0))))
         [(v \ (: q (getenv "LORE_SKY_PX" != "0" ? (sky-gpu lt wx (e 0) (e 2) sim) ())
                  (? (two? q) [() () (1.5 * lt 'expo) (spots v (S \ S >= 0)) e
                               [(q 0 + map (x \ 1.0 * x) (v 'r + v 'u + v 'f + [(v 'w / 2.0 / tan (v 'fov / 2.0)) (mesh-step v 1) (v 'w) (v 'h) (0.02 < lt 'sun 1 && 0.0 < lt 'bare ? (lt 'disc / lt 'bare) 0.0)])) (q 1) (q 2)]]
                     (sky-mesh v lt wx e sim k sm @ () () m (m + [(spots v (S \ S >= 0)) e])))))
          (\ v g (lay v g g (x \ x >> 32 = 1))) (v \ spots v (S \ S >= 0))]]))
 ; ..a state's sky kept between frames, sm for mesh-sky: made the first time it is asked
 (mesh-sky-memo st) (st 'sky-memo @ () (: t {} (pin st 'sky-memo t, t)) t t)
 ; ..the radians between rays k pixels apart at the middle of v
 (mesh-step v k) (1.0 * k * tan (v 'fov / 2.0) / (v 'w / 2.0))
 ; the sky over f's bare pixels, about every k pixels, a flat tray: asked on a cube of
 ; directions n a face, fixed to the sky and drawn through the eye, so no turn or tilt moves
 ; an ask across it. the faces in blocks of 4 by 4 quads, only the blocks in view drawn.
 ; with sm a tablet, each ask kept there: one never asked asked at once, and all in view
 ; again together each sky-age of sim, so the mesh through them is made once in that; all of
 ; them again once the eye has gone sky-move metres, the deck so far over it that less moves
 ; nothing a pixel, and for a new grid, weather or light
 sky-age 1.0 sky-cut 2 sky-move 4.0 sky-lead 0.25
 (sky-keep sm n p mm e lt wx sim) (: q (peep sm 'e e) ds (sim - peep sm 'sim sim) l (peep sm 'lt [(lt 'sun) (lt 'expo)])
   ok (peep sm 'n 0 = n && peep sm 'p 0.0 = p && peep sm 'wx () == wx && l 0 = lt 'sun && l 1 = lt 'expo && 2 ds < 3600.0)
   z (iota (6 * mm) * 0.0)
   _ (? !ok (pins sm 'n n 'p p 'wx wx 'cs (map (_ \ z) ^7) 'at (z - 1e9) 'all -1e9 'e e)
        (2 (e 0 - q 0) + 2 (e 2 - q 2) > 2 sky-move) (pins sm 'all -1e9 'e e))
   (pins sm 'lt [(lt 'sun) (lt 'expo)] 'sim sim))
 (sky-grid v lt wx e sim k f sm) (sky-mesh v lt wx e sim k sm @ () f m
   (: J (iota (#(m 0) // 11) * 11) at (foldl (\ a k (pin a (J + k) (e k))) (m 0 * 0.0) ^3)
     (facets (v 'w) (v 'h) f (v 'cam) (m 0 + at) (m 1) () [(gem-tray [7] [0.0 0.0 0.0 0.0 0.0 352.0 (m 2)])])))
 ; ..its mesh, facets's verts and tris and the tone, the places from the eye, or () where no
 ; block is in view
 (sky-mesh v lt wx e sim k sm)
  (: w (v 'w) h (v 'h) qa (pi / 2.0) nb (int (qa / mesh-step v k / 4.0) + 1) n (4 * nb) m (n + 1) mm (2 m)
     ; ..a point a b across face fc, -1 to 1 by equal angles, unit: on axis fc // 2, its side
     ; by fc's parity
     (dirs fc a b) (: A0 (fc // 2 = 0) A1 (fc // 2 = 1) A2 (fc // 2 = 2) sg (2.0 * (fc % 2) - 1.0)
                     s (tan (qa / 2.0 * a)) t (tan (qa / 2.0 * b))
                     x (A0 * sg + (1 - A0) * s) y (A1 * sg + A0 * s + A2 * t) z (A2 * sg + (1 - A2) * t)
                     L (sqrt (2 x + 2 y + 2 z)) [(x / L) (y / L) (z / L)])
     (dir N) (dirs (N // mm) (2.0 * (N % m) / n - 1.0) (2.0 * (N // m % m) / n - 1.0))
     ; ..a block in view: inside each side of the view but for half a block's diagonal, and
     ; those kept sky-lead radians wider, while the view stays within them; the blocks' middles
     ; kept for the grid
     bm (? (tablet? sm && peep sm 'bk () = nb) (sm 'bm)
           (: K (iota (6 * nb * nb)) m (dirs (K // (2 nb)) (2.0 * (K % nb + 0.5) / nb - 1.0) (2.0 * (K // nb % nb + 0.5) / nb - 1.0))
              (? (tablet? sm) (pins sm 'bk nb 'bm m) 0, m)))
     tx (tan (v 'fov / 2.0)) ty (tx * h / w) fw (v 'f)
     (side a k) (: l (sqrt (1.0 + 2 k)) (map (j \ (a j - k * fw j) / l) ^3))
     sides [(side (v 'r) tx) (side (map (j \ 0.0 - v 'r j) ^3) tx) (side (v 'u) ty) (side (map (j \ 0.0 - v 'u j) ^3) ty)]
     out (foldl (\ a p (max a (bm 0 * p 0 + bm 1 * p 1 + bm 2 * p 2))) (bm 0 * 0.0 - 1.0) sides)
     ah (bm 0 * fw 0 + bm 1 * fw 1 + bm 2 * fw 2) need ((out < 1.15 * qa / nb) * (ah > 0.0)) vm (tablet? sm ? (peep sm 'vm ()) ())
     vb (iota (? (two? vm && <vm = nb && net (need * (1 - vm 1)) = 0) (vm 1)
                 (: m ((out < 1.15 * qa / nb + sky-lead) * (ah > 0.0 - sky-lead)) (? (tablet? sm) (pin sm 'vm [nb m]) 0, m))))
     ; ..the corners of the blocks in view, their directions and the triangles through them:
     ; kept in sm while the same blocks are in view, the grid being the sky's and not the eye's
     key [nb w h (show vb)]
     gd (? (tablet? sm && peep sm 'gk () = key) (sm 'gd)
           (: ; ..the blocks' corners, each asked once, and a ring round each within its face
              ; for the curves through them
              (cl x) (max 0 (min n x))
              (corner E c) (: bk (vb (E // (2 c))) o (E % (2 c))
                             (bk // (2 nb) * mm + (bk // nb % nb * 4 + o // c) * m + bk % nb * 4 + o % c))
              (ring E) (: bk (vb (E // 49)) o (E % 49)
                         (bk // (2 nb) * mm + cl (bk // nb % nb * 4 + o // 7 - 1) * m + cl (bk % nb * 4 + o % 7 - 1)))
              N (iota (pin (iota (6 * mm) * 0) (ring (iota (#vb * 49))) 1 > 0))
              ix (pin (iota (6 * mm) * 0 - 1) N (iota #N)) qs (corner (iota (#vb * 16)) 4)
              (q j) (ix (qs + j))
              ; ..each quad's corners; one quad cut sky-cut by sky-cut, its points' weights on
              ; the corners and its triangles; and one fanned from its middle to its sides'
              ; points, the fan's triangles [middle a b] along each side cut and along it whole
              c sky-cut S (c + 1) J (iota (S * S)) ua (J % S / (1.0 * c)) ub (J // S / (1.0 * c))
              K (iota (2 c)) at (K // c * S + K % c) zk (K * 0 - 1)
              (wts a b) [((1.0 - a) * (1.0 - b)) (a * (1.0 - b)) (a * b) ((1.0 - a) * b)]
              ; ..and on the 4 by 4 corners about the quad, a catmull-rom curve each way, the
              ; face's edge corners standing in past it
              (cr t) [(0.5 * t * (t * (2.0 - t) - 1.0)) (0.5 * (t * t * (3.0 * t - 5.0) + 2.0))
                      (0.5 * t * (t * (4.0 - 3.0 * t) + 1.0)) (0.5 * t * t * (t - 1.0))]
              (bic a b) (: x (cr a) y (cr b) (map (k \ x (k % 4) * y (k // 4)) ^16))
              nr (4 * c) R (iota nr) sd (R // c) t (R % c / (1.0 * c))
              mid (gem-tray [1] [0.5])
              fa (abut [((sd = 0) * t + (sd = 1) + (sd = 2) * (1.0 - t)) mid])
              fb (abut [((sd = 1) * t + (sd = 2) + (sd = 3) * (1.0 - t)) mid])
              g [N (dir N) [(q 0) (q 1) (q (m + 1)) (q m)] (wts ua ub)
                 (lace [at (at + 1) (at + S + 1) zk at (at + S + 1) (at + S) zk])
                 (wts fa fb) [sd R ((R + 1) % nr) ((R % c = 0) * sd * c + (R % c > 0) * nr) ((R % c = 0) * ((sd + 1) * c % nr) + (R % c > 0) * nr)]
                 ; ..each quad's sides that lie on its face's edge
                 (: x (qs % m) y (qs // m % m) [(y = 0) (x + 1 = n) (y + 1 = n) (x = 0)])
                 (map (k \ ix (qs // mm * mm + cl (qs // m % m + k // 4 - 1) * m + cl (qs % m + k % 4 - 1))) ^16)
                 (bic ua ub) (bic fa fb)]
              (? (tablet? sm) (pins sm 'gk key 'gd g) 0, g)))
     N (gd 0) d (gd 1)
     ; ..each ask's clouds as fine as a grid half as coarse, their edges a pixel's: its two
     ; colours and its edge, seven trays; kept ones as they were
     p (mesh-step v 1)
     (ask N d) (sky-ends lt wx (qa / n / 2.0) p (d 0) (d 1) (d 2) (e 0) (e 2) sim @ [c0 dc x] (c0 + dc + [x]))
     c (? (!(tablet? sm)) (ask N d)
          (: _ (sky-keep sm n p mm e lt wx sim)
             old (sim - sm 'all > sky-age) _ (old ? (pin sm 'all sim) 0)
             A (old ? (iota #N) (iota (sm 'at N < -1e8))) NA (N A)
             cA (#A @ 0 () (ask NA (dir NA)))
             _ (#A @ 0 () (pins sm 'cs (map (j \ pin (sm 'cs j) NA (cA j)) ^7) 'at (pin (sm 'at) NA (NA * 0.0 + sim)) 'ver (peep sm 'ver 0 + 1)))
             (map (j \ sm 'cs j N) ^7)))
     ; ..the mesh about the eye. a quad an edge crosses cut, clear at a corner and cloud at
     ; another, its corners' asks eased between, so the edge bends within it, but on a face's
     ; edge; one all soft eased whole; a side cut where both its corners are a cut quad's, so
     ; no side is cut on one face of it and whole on the other, and none on a face's edge, whose
     ; corners the next face numbers apart; a quad with a side cut fanned; the rest two triangles
     (build _)
      (: Q (gd 2) W (gd 3) T (gd 4) Wf (gd 5) Tf (gd 6) bd (gd 7) St (gd 8) (at k) (c 6 (Q k))
        lo (min (min (at 0) (at 1)) (min (at 2) (at 3))) hi (max (max (at 0) (at 1)) (max (at 2) (at 3)))
        ce ((lo < 0.5) * (hi > -0.5) * (hi - lo > 1.0))
        cq (ce * (bd 0 + bd 1 + bd 2 + bd 3 = 0))
        E (iota cq) hit (foldl (\ h k (pin h (Q k E) 1)) (N * 0) ^4) (hc k) (hit (Q k))
        cs [(hc 0 * hc 1 * (1 - bd 0)) (hc 1 * hc 2 * (1 - bd 1)) (hc 2 * hc 3 * (1 - bd 2)) (hc 3 * hc 0 * (1 - bd 3))]
        ns (cs 0 + cs 1 + cs 2 + cs 3) B (iota ((1 - cq) * (ns > 0))) F (iota ((1 - cq) * (ns = 0)))
        nE (#E * #(W 0)) nf (#(Wf 0))
        zf (F * 0 - 1) Jt (iota (#E * #T))
        ; ..a fan's sides cut or whole, each of its triangles the one or the other
        Jf (iota (#B * #(Tf 0))) qf (Jf // #(Tf 0)) lf (Jf % #(Tf 0))
        sf (Tf 0 lf) bq (B qf) fc ((sf = 0) * cs 0 bq + (sf = 1) * cs 1 bq + (sf = 2) * cs 2 bq + (sf = 3) * cs 3 bq)
        o (#N + nE + qf * nf) zb (Jf * 0 - 1)
        fan (lace [(o + nf - 1) (o + Tf 3 lf + fc * (Tf 1 lf - Tf 3 lf)) (o + Tf 4 lf + fc * (Tf 2 lf - Tf 4 lf)) zb])
        tris (abut [(lace [(Q 0 F) (Q 1 F) (Q 2 F) zf (Q 0 F) (Q 2 F) (Q 3 F) zf])
                    (T (Jt % #T) + (Jt % 4 != 3) * (#N + Jt // #T * #(W 0))) fan])
        ; ..each column the asks' own, then the cuts' and the fans' points: a place or a colour
        ; eased straight from the corners, so a side's points lie on it and meet the next quad's,
        ; and the edge along the curves through the 4 by 4 about them
        (by x C V0 V1) (abut [x (mix-quads x C V0 E) (mix-quads x C V1 B)])
        (lin x) (by x Q W Wf)
        [(lace [(lin (d 0)) (lin (d 1)) (lin (d 2)) (by (c 6) St (gd 9) (gd 10)) 0.0
                (lin (c 0)) (lin (c 1)) (lin (c 2)) (lin (c 3)) (lin (c 4)) (lin (c 5))]) tris])
     ; ..kept while no ask is new and the view has not turned, its places from the eye, so a
     ; gpu keeps it as the eye moves
     mk [key (tablet? sm ? (peep sm 'ver 0) ())]
     mv (? (tablet? sm && peep sm 'mk () = mk) (sm 'mv) (: m (build ()) (? (tablet? sm) (pins sm 'mk mk 'mv m) 0, m)))
     (#N @ 0 () [(mv 0) (mv 1) (1.5 * lt 'expo)]))
 ; the sky low ahead before the gain, 0 to 255: the colour a far thing fades to
 ; ..the horizon's colour toward th: a ring of headings fixed in the world, each easing out
 ; 60 degrees off th, so a turn carries no sample across a cloud's edge. the ring is the costly
 ; part and the sky slow, so wx keeps it for ten seconds and 40 metres
 (mesh-haze v lt wx sim) (: th (v 'th) e (v 'e) as (iota 24 * (pi / 12.0))
   key [(int (sim / 10.0)) (int (e 0 / 40.0)) (int (e 2 / 40.0))] kept (peep wx 'haze-ring ())
   c (two? kept && <kept = key ? (kept 1)
        (: r (sky-near lt wx (sin as) (as * 0.0) (cos as) (e 0) (e 2) sim) (pin wx 'haze-ring [key r], r)))
   q (cos (th - as) - 0.5) w ((q > 0.0) * q * q) s (net w)
   (ch k) (255.0 * net (w * c k) / s)
   [(ch 0) (ch 1) (ch 2)])
 ; a glow faces the eye, u v its offsets along the eye's right and up, and fades over glow-soft
 ; metres as what is behind it comes within glow-lead of it
 glow-lead 0.1 glow-soft 0.25
 ; a frame, a flat w*h colour tray: sc [verts tris] or [verts tris sun], sun () or [view
 ; depths bias]; fog [r g b near far] 0 to 255; gain sky-tone's, 0 none; bare a colour,
 ; (\ v S ..) for bare pixels S, or [base over]: (base v) drawn under, (over v f B) finishes; a
 ; bare pixel below -1 keeps a glow, -1 less its colour, put on what fills it, and one at or
 ; below -2^25 a glass's tint and sheen, -2^25 less tint + 2^24 sheen / 4, what fills it seen
 ; through them
 ; v 'under a coarser frame of mesh-coarse's, laid first where it drew; v 'gpu a gpu-state, which
 ; draws it where it can, v 'keys each batch's name for it or (), and a sky's mesh under it where
 ; bare has one; with its pipe the frame before is answered, finished as that frame's own v and
 ; bare ask; or ['kept spots], where the gpu that shows on the window kept a frame none of
 ; whose pixels were bare, the sky's spots to lay over its sky
 (mesh-frame v sc texs fog flags gain bare) (: B0 (two? bare ? (<bare v) -1) B (v 'under @ () B0 u [B0 (u 0) (u 1)])
   sun (#sc < 3 ? () (sc 2)) bias (two? sun ? (sun 2) 0.0)
   er (v 'r) eu (v 'u)
   o (gem-tray [18] [(1.0 * fog 0) (1.0 * fog 1) (1.0 * fog 2) (1.0 * fog 3) (1.0 * fog 4) (1.0 * (flags | 64)) (1.0 * gain) bias
                     (er 0) (er 1) (er 2) (eu 0) (eu 1) (eu 2) (v 'near) (v 'far) glow-lead glow-soft])
   os (#sc < 3 ? o [o (two? sun ? (sun 0) ()) (two? sun ? (sun 1) ())])
   gp (peep v 'gpu ()) sk (tablet? gp && two? bare && #bare = 3 ? (bare 2 0 v) ())
   c [v B0 bare (two? sk)] q (tablet? gp ? (gpu-facets gp (v 'w) (v 'h) B (v 'cam) (sc 0) (sc 1) texs os (peep v 'keys ()) sk c) ())
   r (? (tray? q || nom? q) [q c] (two? q) q [(facets (v 'w) (v 'h) B (v 'cam) (sc 0) (sc 1) texs os) [v B0 bare 0]])
   (? (nom? (r 0)) [(r 0) (r 1 3 ? (r 1 2 2 2 (r 1 0)) ())] (r 1 3) (r 1 2 2 1 (r 1 0) (r 0)) (mesh-bare (r 0) (r 1 0) (r 1 1) (r 1 2))))
 ; ..the gpu that draws st's frames, opened at the first: on a window or under android's bridge
 ; (LOVE_GPU_FACE) but with LORE_GPU=0, and otherwise only with LORE_GPU=1, else 'off. each is
 ; shown a frame late, drawn while the next is made, but with LORE_GPU_PIPE=0; on an X window,
 ; or an app's under android's bridge, it shows them there itself, but with LORE_GPU_WIN=0
 (mesh-gpu st) (st 'gpu @ () (: w (st 'win) on (getenv "LORE_GPU_WIN" != "0") x (tablet? w && w 'how = 'x && on)
                                  dr (tablet? w && w 'how = 'droid && on)
                                  (open g) (: s (pin (gpu-state g) 'pipe (getenv "LORE_GPU_PIPE" != "0"))
                                              (? (x && gpu-win g (w 'xw) = ()) (pin s 'win 1) (dr && peep g 'face 0) (pin s 'win 1) s))
                                  ge (getenv "LORE_GPU") on? (ge = "1" || ge != "0" && (x || dr || string? (getenv "LOVE_GPU_FACE")))
                                  s (on? ? (gpu-open x @ g (tablet? g ? (open g) 'off)) 'off)
                                (pin st 'gpu s, s))
                          s s)
 ; ..f's bare pixels filled as bare asks, through v, B0 the ground: again, none is left to fill
 (mesh-bare f v B0 bare)
  (? (two? bare) (<>bare v f B0)
     (: S (iota (f < 0)) (#S @ 0 f (pin f S (glowed (charm? bare ? (S * 0 + bare) (bare v S)) (-1 - f S))))))
 ; ..colours s with the glows g kept on their bare pixels added, or through the tints kept
 (glowed s g) (: t (g >= 33554431) v (g - 33554431)
   (ch k) (t * min ((s >> k & 255) * (v >> k & 255) // 255 + 4 * (v >> 24)) 255 + (1 - t) * min ((s >> k & 255) + (g >> k & 255)) 255)
   ((ch 16 << 16) | (ch 8 << 8) | ch 0))
 ; ..sc drawn k times coarser, through v's camera: its colours and its depths, for v 'under
 (mesh-coarse v sc texs fog flags gain k) (: W (max 1 (v 'w // k)) H (max 1 (v 'h // k))
   (o fl) (gem-tray [8] [(1.0 * fog 0) (1.0 * fog 1) (1.0 * fog 2) (1.0 * fog 3) (1.0 * fog 4) (1.0 * fl) (1.0 * gain) 0.0])
   [(facets W H -1 (v 'cam) (sc 0) (sc 1) texs (o (flags | 64))) (facets W H -1 (v 'cam) (sc 0) (sc 1) texs (o (flags | 16)))])
 ; a frame's colours as [r g b] trays, 0 to 1
 (mesh-flat f) [((f >> 16 & 255) / 255.0) ((f >> 8 & 255) / 255.0) ((f & 255) / 255.0)]
 ; ..as half-block cells: 24-bit, or the 256 cube dithered by bay
 (mesh-cells f w h deep bay bands) (: c (mesh-flat f)
   (deep ? (view-deep-frame w h (view-deep-pens c) bands)
      (view-cube-pens c bay @ px (view-frame w h (y \ px (iota w + w * y)) bands))))
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
   (? (0 < #(getenv "MITTY") + #(getenv "PIER")) 1 (has "TERM" "kitty") 1 (0 < #(getenv "KITTY_WINDOW_ID")) 1
      (has "TERM_PROGRAM" "ghostty") 1 (has "TERM_PROGRAM" "WezTerm") 1 0))
 ; ..and a picture taken down
 (mesh-kitty-del id) "\(esc)_Ga=d,d=I,i=\(id),q=2\(esc)\\"
 ; --- a level's screen: 'kitty 1 kitty's pixels, 'win a window, else half blocks ---
 (mesh-mode md) (md @ 'kitty 1 'cells 0 'window 0 (mesh-kitty? ()))
 ; ..w cells by r rows, two pixels a row; 'kp pixels a column: kitty's fits kitty-w each way.
 ; a window's picture is 'pic-w by 'pic-h, the window over 'scale (1 2 4 or 8, else 2): each
 ; of its pixels 'scale of the window's each way
 kitty-w 640
 (mesh-scale st) (peep st 'scale 2 @ s (elem s [1 2 4 8] ? s 2))
 ; ..a window's share that is the picture's, where the console has the rest: 'pane its box in pixels
 (mesh-pane st) (: wh (window-size (st 'win)) (peep st 'pane () @ () wh q [(max 1 (q 2)) (max 1 (q 3))]))
 (mesh-size st w r) (: h (2 * r) s (mesh-scale st) win (st 'win)
   wh (tablet? win ? (mesh-pane st) [(8 * w) (16 * r)]) pw (max 1 ((tablet? win ? (wh 0) kitty-w) // s)) ph (max 1 (pw * wh 1 // max 1 (wh 0)))
   (pins (view! st w h r) 'bay (view-bayer w h) 'pic-w pw 'pic-h ph
         'kp (? (tablet? win) (max 1 (pw // 160)) (st 'kitty) (max 1 (kitty-w // max w h // s)) 1)))
 ; ..the picture a frame is: in a window 'pic-w by 'pic-h, else 'kp pixels a cell
 (mesh-dims st) (: k (peep st 'kp 1) (tablet? (st 'win) ? [(st 'pic-w) (st 'pic-h)] [(k * st 'w) (k * st 'h)]))
 ; ..a body's sway b [up right pitch roll] for the eye. a window's coarsest pixels would make it
 ; hop, so there the server's enlarging slides the picture instead, by its own pixels; a body
 ; two metres from what it sees, and the eye stays still
 (mesh-sway st b fov w) (: s (mesh-scale st) win (st 'win)
   (? (8 <= s && tablet? win && window-slides? win)
      (: foc (s * w / 2.0 / tan (fov / 2.0))
         (pin st 'slide [(int (foc * b 1 / 2.0)) (int (0.0 - foc * (b 2 + b 0 / 2.0)))], [0.0 0.0 0.0 0.0]))
      (pin st 'slide [0 0], b)))
 ; ..a frame f: kitty alternates ids 7 and 8 in one synchronised update, the old taken down
 ; once the new is over it (one id reused blanks first); or the cells, bands over them
 (mesh-show st f text bands) (: w (st 'w) h (st 'h) k (peep st 'kp 1)
   (? (st 'win) (mesh-win st f bands)
      (st 'kitty)
      (: n (peep st 'kn 0) _ (pin st 'kn (1 - n))
         (esc + "[?2026h" + mesh-kitty f (k * w) (k * h) w (h // 2) (7 + n) + mesh-kitty-del (8 - n)
          + text + esc + "[?2026l"))
      (esc + "[?2026h" + mesh-cells f w h (st 'deep) (st 'deep ? 0 (st 'bay)) bands + esc + "[?2026l")))
 ; ..or to a window: by the gpu that shows on it, its kept frame or f, else the picture sent
 ; for the server to enlarge, else painted onto the paper as often as fits; bands then 'over
 ; in 8 by 16 cells, only their rows shown when the server enlarged the rest, their cells
 ; when the gpu did; answers ""
 (mesh-win st f bands) (: win (st 'win) d (mesh-dims st) w <d h (d 1)
   wh (window-size win) W <wh H (wh 1) P (window-paper win) gp (st 'gpu)
   (? (two? (peep st 'pane ())) (mesh-split st f bands w h W H P)
      (tablet? gp && peep gp 'win 0 && tablet? (gp 'g) ? (mesh-gpu-win st gp f w h W H P bands) (mesh-blit st f bands w h W H P))))
 ; ..beside the console the picture painted into its pane, the gpu keeping none of its frames
 (mesh-split st f bands w h W H P) (: b (st 'pane) pw (b 2) ph (b 3) gp (st 'gpu) ov (peep st 'over {}) _ (tablet? gp ? (pin gp 'keep 0))
   T (cask (4 * max 1 (pw * ph)))
   _ (tray? f && #f = w * h && 0 < pw && 0 < ph ? (: _ (mesh-paint f w h T pw ph)
                                    _ (each (sort (keys bands)) (r \ mesh-band st T pw ph r (bands r)))
                                    (each ^(min ph (H - b 1)) (j \ pour P (4 * ((b 1 + j) * W + b 0)) T (4 * j * pw) (4 * min pw (W - b 0))))) 0)
   _ (each (sort (keys ov)) (r \ mesh-band st P W H r (ov r)))
   (window-show (st 'win) 0 H, ""))
 ; ..its frames kept by the gpu from the next on
 (mesh-gpu-win st gp f w h W H P bands) (: ov (peep st 'over {})
   _ (each (sort (keys bands)) (r \ mesh-band st P W H r (bands r)))
   _ (each (sort (keys ov)) (r \ mesh-band st P W H r (ov r)))
   (cells t) (map (r \ (t r) @ bd [(8 * bd 0) (16 * r) (min W (8 * (bd 0 + #(bd 1)))) (min H (16 * r + 16))]) (sort (keys t)))
   rs (filter (q \ q 0 < q 2 && q 1 < q 3) (cells bands + cells ov))
   (pin gp 'keep 1, gpu-show (gp 'g) f w h W H (peep st 'slide [0 0]) rs P, ""))
 (mesh-blit st f bands w h W H P) (: win (st 'win)
   Q (peep st 'pic-n 0 = w * h ? (st 'pic) (: q (cask (w * h * 4)) _ (pins st 'pic q 'pic-n (w * h)) q))
   _ (frame-paint f w 1 Q w)
   ov (peep st 'over {}) rs (sort (keys bands + keys ov))
   up (window-blit win Q w h (map (r \ [(16 * r) (16 * r + 16)]) rs) (peep st 'slide [0 0]))
   _ (up ? (each rs (mesh-under f w h P W H)) (mesh-paint f w h P W H))
   _ (each (sort (keys bands)) (r \ mesh-band st P W H r (bands r)))
   _ (each (sort (keys ov)) (r \ mesh-band st P W H r (ov r)))
   _ (? up (each rs (r \ window-show win (16 * r) (16 * r + 16))) (window-show win 0 H))
   "")
 ; ..the picture f w by h on the paper P, W by H, at the largest whole scale that fits; the
 ; paper past it black, so nothing laid there before stays
 (mesh-paint f w h P W H) (: s (max 1 (min (W // w) (H // h))) cw (min W (w * s)) ch (min H (h * s)) Z (cask (4 * W))
   _ (frame-paint f w s P W)
   _ (cw < W ? (each ^ch (y \ pour P (4 * (y * W + cw)) Z 0 (4 * (W - cw)))) 0)
   (each (map (+ ch) ^(H - ch)) (y \ pour P (4 * y * W) Z 0 (4 * W)), P))
 ; ..the paper's cell row r laid from the picture f w by h, enlarged to the window W by H
 (mesh-under f w h P W H r) (: y0 (16 * r) n (min 16 (H - y0))
   (? (0 < n) (: I (iota (W * n)) X (I % W) Y (I // W + y0) g (f (Y * h // H * w + X * w // W)) T (cask (W * n * 4))
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
 mesh-gone (mesh-kitty-del 7 + mesh-kitty-del 8)

 ; --- glb, glTF 2.0 in one file, for a modeller: a mesh written out and read back. glTF is
 ;     right-handed, so x runs the other way there and a front turns the same; its colours
 ;     are linear light, ours as seen ---
 (glb-u32 s i) (s i | s (i + 1) << 8 | s (i + 2) << 16 | s (i + 3) << 24)
 (glb-u16 s i) (s i | s (i + 1) << 8)
 (glb-le v) [(v & 255) (v >> 8 & 255) (v >> 16 & 255) (v >> 24 & 255)]
 ; ..a binary32's bits as a float, and a float's; the infinities and nans read as nothing
 (glb-f32 b) (: e (b >> 23 & 255) m (b & 8388607)
   v (e @ 0 (m * (2.0 ** -149)) 255 0.0 ((1.0 + m / 8388608.0) * (2.0 ** (e - 127))))
   (b >> 31 @ 1 -v v))
 (glb-bits x) (? (x = 0.0) 0
   (: a (x < 0.0 ? -x x) s (x < 0.0 ? 2147483648 0) e0 (floor (log a / log 2.0))
      e (? (2.0 ** (e0 + 1) <= a) (e0 + 1) (a < 2.0 ** e0) (e0 - 1) e0)
      (? (e < -126) (s | int (a / (2.0 ** -149) + 0.5))
         (e > 127) (s | 2139095040)
         (: m (int ((a / (2.0 ** e) - 1.0) * 8388608.0 + 0.5))
            (m @ 8388608 (s | (e + 128) << 23) (s | (e + 127) << 23 | m))))))
 (glb-lin c) (: k (max 0.0 (min 1.0 c)) (k <= 0.04045 ? (k / 12.92) (((k + 0.055) / 1.055) ** 2.4)))
 (glb-srgb c) (: k (max 0.0 (min 1.0 c)) (k <= 0.0031308 ? (12.92 * k) (1.055 * (k ** (1.0 / 2.4)) - 0.055)))
 ; ..m as a .glb named name: one node, one primitive, its positions, normals, colours and
 ; triangles, under a plain white matte; a triangle's texture is left behind
 (mesh-glb-of m name) (: vs (m 0) ts (m 1) n #vs
   ps (map (v \ map (glb-f32 * glb-bits) [-(v 0) (v 1) (v 2)]) vs) ns (map (v \ [-(v 5) (v 6) (v 7)]) vs)
   cs (map (v \ map (glb-lin * v) [8 9 10]) vs)
   (fl l) (catmap (p \ catmap (glb-le * glb-bits) p) l)
   ; ..the triangles' corners in two bytes each where that holds them, padded to a word
   sh (n <= 65536) (le k) (sh ? [(k & 255) (k >> 8 & 255)] (glb-le k))
   pb (fl ps) nb (fl ns) cb (fl cs) il (#ts * 3 * (sh ? 2 4)) ib (catmap (t \ catmap (le * t) ^3) ts + map (_ \ 0) ^((4 - il % 4) % 4))
   (ext f) (map (k \ foldl (\ a p (f a (p k))) (ps 0 k) ps) ^3)
   (view o l g) {"buffer" 0 "byteOffset" o "byteLength" l "target" g}
   (acc v ty c ct) {"bufferView" v "componentType" ct "count" c "type" ty}
   j (json-show {"asset" {"version" "2.0" "generator" "lore"} "scene" 0 "scenes" [{"nodes" [0]}]
                 "nodes" [{"mesh" 0 "name" name}]
                 "meshes" [{"name" name "primitives" [{"attributes" {"POSITION" 0 "NORMAL" 1 "COLOR_0" 2} "indices" 3 "mode" 4 "material" 0}]}]
                 "materials" [{"name" name "pbrMetallicRoughness" {"baseColorFactor" [1.0 1.0 1.0 1.0] "metallicFactor" 0.0 "roughnessFactor" 1.0}}]
                 "accessors" [(pins (acc 0 "VEC3" n 5126) "min" (ext min) "max" (ext max))
                              (acc 1 "VEC3" n 5126) (acc 2 "VEC3" n 5126) (acc 3 "SCALAR" (3 * #ts) (sh ? 5123 5125))]
                 "bufferViews" [(view 0 #pb 34962) (view #pb #nb 34962) (view (#pb + #nb) #cb 34962) (view (#pb + #nb + #cb) il 34963)]
                 "buffers" [{"byteLength" (#pb + #nb + #cb + #ib)}]})
   jp (j + string (map (_ \ 32) ^((4 - #j % 4) % 4))) bl (#pb + #nb + #cb + #ib)
   (string (glb-le 1179937895 + glb-le 2 + glb-le (28 + #jp + bl) + glb-le #jp) + "JSON" + jp
    + string (glb-le bl + [66 73 78 0]) + string pb + string nb + string cb + string ib))
 ; ..a .glb's text as a mesh, or () where it is none: every mesh under the scene's nodes,
 ; each node's place laid on; a primitive's colour its vertices' times its material's, white
 ; for none; normals made where it has none; triangles only
 (mesh-glb s) (? (#s < 28 || glb-u32 s 0 != 1179937895 || glb-u32 s 4 != 2 || glb-u32 s 16 != 1313821514) ()
   (: jl (glb-u32 s 12) r (json-read (snip s 20 (20 + jl))) b0 (28 + jl)
      (? (atom? r || !(tablet? (r 1))) ()
         (: g (r 1) avs (g "accessors") bvs (g "bufferViews")
            (wide ct) (ct @ 5126 4 5125 4 5123 2 5122 2 1)
            (comp ct o nm) (? (ct = 5126) (glb-f32 (glb-u32 s o)) (ct = 5125) (glb-u32 s o)
                              (ct = 5123) (glb-u16 s o @ v (nm ? (v / 65535.0) v))
                              (ct = 5122) (glb-u16 s o @ v (: w (v < 32768 ? v (v - 65536)) (nm ? (max -1.0 (w / 32767.0)) w)))
                              (ct = 5121) (s o @ v (nm ? (v / 255.0) v))
                              (s o @ v (: w (v < 128 ? v (v - 256)) (nm ? (max -1.0 (w / 127.0)) w))))
            (acc i) (: a (avs i) bv (bvs (a "bufferView")) ct (a "componentType")
                       nc (peep {"SCALAR" 1 "VEC2" 2 "VEC3" 3 "VEC4" 4} (a "type") 1) cw (wide ct)
                       st (peep bv "byteStride" (nc * cw)) o (b0 + peep bv "byteOffset" 0 + peep a "byteOffset" 0)
                       nm (peep a "normalized" json-false = json-true)
                       (map (i \ map (k \ comp ct (o + i * st + k * cw) nm) ^nc) ^(a "count")))
            ; ..a node's place: its matrix, else its turn, size and shift; [rows of 3, shift]
            (place n) (? (elem "matrix" (keys n))
                         (: q (n "matrix") [(map (r \ map (c \ q (4 * c + r)) ^3) ^3) [(q 12) (q 13) (q 14)]])
                         (: t (peep n "translation" [0.0 0.0 0.0]) q (peep n "rotation" [0.0 0.0 0.0 1.0]) z (peep n "scale" [1.0 1.0 1.0])
                            x (q 0) y (q 1) w (q 3) qz (q 2)
                            R [[(1.0 - 2.0 * (2 y + 2 qz)) (2.0 * (x * y - w * qz)) (2.0 * (x * qz + w * y))]
                               [(2.0 * (x * y + w * qz)) (1.0 - 2.0 * (2 x + 2 qz)) (2.0 * (y * qz - w * x))]
                               [(2.0 * (x * qz - w * y)) (2.0 * (y * qz + w * x)) (1.0 - 2.0 * (2 x + 2 y))]]
                            [(map (r \ map (c \ R r c * z c) ^3) ^3) t]))
            (mul A B) [(map (r \ map (c \ net (map (k \ A 0 r k * B 0 k c) ^3)) ^3) ^3)
                       (map (r \ A 1 r + net (map (k \ A 0 r k * B 1 k) ^3)) ^3)]
            (on M p) (map (r \ M 1 r + net (map (k \ M 0 r k * p k) ^3)) ^3)
            ; ..a normal's way: the cofactors, the inverse's transpose but for its size and sign
            (cof M) (: m (M 0) (rc r c) (: a (m ((r + 1) % 3)) b (m ((r + 2) % 3)) (a ((c + 1) % 3) * b ((c + 2) % 3) - a ((c + 2) % 3) * b ((c + 1) % 3)))
                      (map (r \ map (rc r) ^3) ^3))
            (det M) (: m (M 0) (net (map (c \ m 0 c * (m 1 ((c + 1) % 3) * m 2 ((c + 2) % 3) - m 1 ((c + 2) % 3) * m 2 ((c + 1) % 3))) ^3)))
            (prim M p) (: at (p "attributes") P (acc (at "POSITION")) n #P C (cof M) sg (det M < 0.0 ? -1.0 1.0)
                          N (elem "NORMAL" (keys at) ? (acc (at "NORMAL")) ())
                          K (elem "COLOR_0" (keys at) ? (acc (at "COLOR_0")) ())
                          mt (p "material" @ () {} i (peep (g "materials") i {}))
                          f (peep (peep mt "pbrMetallicRoughness" {}) "baseColorFactor" [1.0 1.0 1.0 1.0])
                          I (elem "indices" (keys p) ? (map cap (acc (p "indices"))) ^n)
                          vs (map (i \ (: q (on M (P i)) w (two? N ? (unit (map (r \ sg * net (map (c \ C r c * N i c) ^3)) ^3)) [0.0 1.0 0.0])
                                          k (two? K ? (K i) [1.0 1.0 1.0])
                                          [-(q 0) (q 1) (q 2) 0.0 0.0 -(w 0) (w 1) (w 2)
                                           (glb-srgb (k 0 * f 0)) (glb-srgb (k 1 * f 1)) (glb-srgb (k 2 * f 2))]))
                                  ^n)
                          ts (map (k \ (: a (I (3 * k)) b (I (3 * k + 1)) c (I (3 * k + 2)) (sg < 0.0 ? [a c b -1] [a b c -1]))) ^(#I // 3))
                          (two? N ? (mesh vs ts) (mesh-normals (mesh vs ts))))
            (walk i M) (: n (peep g "nodes" () i) M2 (mul M (place n))
                          here (elem "mesh" (keys n) ? (map (prim M2) (filter (p \ peep p "mode" 4 = 4) (peep g "meshes" () (n "mesh") "primitives")))
                                 ())
                          (here + catmap (c \ walk c M2) (n "children")))
            sc (peep (g "scenes") (peep g "scene" 0) {})
            ms (catmap (i \ walk i [[[1.0 0.0 0.0] [0.0 1.0 0.0] [0.0 0.0 1.0]] [0.0 0.0 0.0]]) (sc "nodes"))
            (two? ms ? (mesh-join ms) ()))))))
) ; module mesh
