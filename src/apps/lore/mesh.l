; mesh -- levels drawn in triangles: meshes built from shapes, lit by sun or lamps, packed
; for facets; a camera; textures; the frame out as half blocks, kitty's pixels, or a window.
; the world is lore's: x right, y up, z ahead when 'th is 0, 'th turning toward x.
(module (mesh mesh mesh-join mesh-move mesh-quad mesh-box mesh-grid mesh-lathe mesh-sheet mesh-rod mesh-dots mesh-normals
         mesh-keep mesh-keep-all mesh-pack mesh-bake mesh-bake-sun mesh-sun-view mesh-sun-map mesh-open
         mesh-lamp mesh-lamp-row mesh-lamps mesh-lamps! mesh-shine mesh-glow mesh-pic mesh-tex mesh-rgba
         mesh-view mesh-eye mesh-aim mesh-dirs mesh-spot mesh-step mesh-sky mesh-sky-memo mesh-haze mesh-frame mesh-coarse mesh-flat
         mesh-cells mesh-kitty mesh-kitty? mesh-kitty-del mesh-mode mesh-size mesh-dims mesh-show mesh-win mesh-gone
         mesh-glb mesh-glb-of)
(borrow 'view)
(borrow 'window)
(borrow 'vec)
(borrow 'sky)
(borrow 'json)
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
 ;     'keep a plan box [x0 z0 x1 z1], or [x0 z0 x1 z1 y0 y1] between two heights too. c
 ;     at a metre, shared among the points, falls off by the square to none at the reach;
 ;     'wrap rounds it onto what it grazes. no shadows: it lights only what stands in its box ---
 ; a lamp as lamp-light takes it (src/love/lamp.c)
 (mesh-lamp-row lp) [(lp 'at) (lp 'r) (lp 'c) (peep lp 'n ()) (sq (peep lp 'soft 0.1)) (peep lp 'wrap 0.0) (peep lp 'keep ())]
 ; ..its light on each vertex of a packed mesh: [r g b] trays, before the surface's colour
 (mesh-lamp pk lp) (lamp-light (pk 'cols) [(mesh-lamp-row lp)])
 ; ..and the mesh lit by amb [r g b] plus each lamp's chs times its ks: [verts tris] 8 a vertex
 (mesh-lamps pk amb chs ks gain) (: c (pk 'cols) n (pk 'n) z (c 0 * 0.0)
   (lit j) (gain * c (8 + j) * foldl (\ a i (a + ks i * chs i j)) (z + amb j) ^#chs)
   [(lace [(c 0) (c 1) (c 2) (c 3) (c 4) (lit 0) (lit 1) (lit 2)]) (pk 'tris)])
 ; ..the same kept on the packed mesh, only colours rewritten: amb, chs and gain are the
 ; first call's, and after it only the vertices a lamp reaches change, only when ks does
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
      b (: lv (pk 'live) [(#(lv 'ix) = 0 || peep lv 'ks () = ks ? b
                           (: _ (pin lv 'ks ks) v (pins3 b (lv 'ix) (lit (lv 'c8) (lv 'base) (lv 'chs))) (pin pk 'buf v, v)))
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
     (pins (mesh-aim w h e r u f fov near far) 'th th 'ph ph))
 ; ..or with its right, up and ahead given, unit and square
 (mesh-aim w h e r u f fov near far)
  (: fx (1.0 / tan (fov / 2.0)) fy (fx * w / h)
     za ((far + near) / (far - near)) zb (-2.0 * far * near / (far - near))
     (row k a) [(k * a 0) (k * a 1) (k * a 2) (0.0 - k * dot a e)]
     z (row za f)
     {'w w 'h h 'e e 'fov fov 'near near 'far far 'r r 'u u 'f f
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
 ; 1 asks about every k pixels on directions fixed to the sky and shades between by facets,
 ; stars put on by night; nothing asked where no pixel is bare
 (mesh-sky ss lt wx e sim t0 k sm)
  (: X (ss 'x) Y (ss 'y) Z (ss 'z)
     (shine c ix) (word (sky-tone lt (sky-stars! ss c lt wx (e 0) (e 2) sim t0 ix)))
     (k <= 1
      ? (\ v S (: at (pin (iota (v 'w * v 'h) * 0 - 1) S (iota #S)) d (mesh-dirs v S)
                  (shine (sky-colour-at lt wx (mesh-step v 1) (d 0) (d 1) (d 2) (e 0) (e 2) sim) (peep at (mesh-spot v X Y Z) -1))))
        [(v \ -1)
         (\ v f B (? (!(aany (f = -1))) f
                     (: g (sky-grid v lt wx e sim k f sm) sp (mesh-spot v X Y Z) ix (over -1 (peep f sp 0 = -1) (iota #X))
                        (1.0 <= lt 'day * 3.0 ? g (pin g (over -1 (0 <= ix) sp) (shine (sky-colour-at lt wx (mesh-step v 1) X Y Z (e 0) (e 2) sim) ix))))))]))
 ; ..a state's sky kept between frames, sm for mesh-sky: made the first time it is asked
 (mesh-sky-memo st) (peep st 'sky-memo () @ () (: t {} (pin st 'sky-memo t, t)) t t)
 ; ..the radians between rays k pixels apart at the middle of v
 (mesh-step v k) (1.0 * k * tan (v 'fov / 2.0) / (v 'w / 2.0))
 ; the sky over f's bare pixels, about every k pixels, a flat tray: asked on a cube of
 ; directions n a face, fixed to the sky and drawn through the eye, so no turn or tilt moves
 ; an ask across it. the faces in blocks of 4 by 4 quads, only the blocks in view drawn.
 ; with sm a tablet, each ask kept there and asked again a frame in sky-turn, or once
 ; sky-age of sim old; all of them again for a new grid, weather or light, or once the eye
 ; moves, so no two asks side by side are of different moments
 sky-turn 4 sky-age 1.0
 (sky-keep sm n mm e lt wx sim) (: q (peep sm 'e e) ds (sim - peep sm 'sim sim) l (peep sm 'lt [(lt 'sun) (lt 'expo)])
   ok (peep sm 'n 0 = n && peep sm 'wx () == wx && all (k \ e k = q k) ^3 && l 0 = lt 'sun && l 1 = lt 'expo && ds * ds < 3600.0)
   z (iota (6 * mm) * 0.0)
   _ (? !ok (pins sm 'n n 'wx wx 'r z 'g z 'b z 'at (z - 1e9) 'k 0))
   (pins sm 'e e 'lt [(lt 'sun) (lt 'expo)] 'sim sim 'k (sm 'k + 1)))
 (sky-grid v lt wx e sim k f sm)
  (: w (v 'w) h (v 'h) qa (pi / 2.0) nb (int (qa / mesh-step v k / 4.0) + 1) n (4 * nb) m (n + 1) mm (m * m)
     ; ..a point a b across face fc, -1 to 1 by equal angles, unit: on axis fc // 2, its side
     ; by fc's parity
     (dirs fc a b) (: A0 (fc // 2 = 0) A1 (fc // 2 = 1) A2 (fc // 2 = 2) sg (2.0 * (fc % 2) - 1.0)
                     s (tan (qa / 2.0 * a)) t (tan (qa / 2.0 * b))
                     x (A0 * sg + (1 - A0) * s) y (A1 * sg + A0 * s + A2 * t) z (A2 * sg + (1 - A2) * t)
                     L (sqrt (x * x + y * y + z * z)) [(x / L) (y / L) (z / L)])
     ; ..a block in view: inside each side of the view but for half a block's diagonal
     tx (tan (v 'fov / 2.0)) ty (tx * h / w) r (v 'r) u (v 'u) fw (v 'f)
     (side a k) (: l (sqrt (1.0 + k * k)) (map (j \ (a j - k * fw j) / l) ^3))
     sides [(side r tx) (side (map (j \ 0.0 - r j) ^3) tx) (side u ty) (side (map (j \ 0.0 - u j) ^3) ty)]
     K (iota (6 * nb * nb)) bd (dirs (K // (nb * nb)) (2.0 * (K % nb + 0.5) / nb - 1.0) (2.0 * (K // nb % nb + 0.5) / nb - 1.0))
     out (foldl (\ a p (max a (bd 0 * p 0 + bd 1 * p 1 + bd 2 * p 2))) (bd 0 * 0.0 - 1.0) sides)
     vb (iota ((out < 1.15 * qa / nb) * (bd 0 * fw 0 + bd 1 * fw 1 + bd 2 * fw 2 > 0.0)))
     ; ..the blocks' corners, each asked once
     (corner E c) (: bk (peep vb (E // (c * c)) 0) o (E % (c * c))
                    (bk // (nb * nb) * mm + (bk // nb % nb * 4 + o // c) * m + bk % nb * 4 + o % c))
     N (iota (pin (iota (6 * mm) * 0) (corner (iota (#vb * 25)) 5) 1 > 0))
     (dir N) (dirs (N // mm) (2.0 * (N % m) / n - 1.0) (2.0 * (N // m % m) / n - 1.0))
     d (dir N)
     ; ..each ask's clouds no finer than the asks beside it; kept ones as they were
     (ask N d) (sky-colour-at lt wx (qa / n) (d 0) (d 1) (d 2) (e 0) (e 2) sim)
     c (? (!(tablet? sm)) (ask N d)
          (: _ (sky-keep sm n mm e lt wx sim)
             A (iota (((N + sm 'k) % sky-turn = 0) + (sim - peep (sm 'at) N 0.0 > sky-age) > 0)) NA (peep N A 0)
             cA (#A = 0 ? () (ask NA (dir NA)))
             _ (#A = 0 ? () (pins sm 'r (pin (sm 'r) NA (cA 0)) 'g (pin (sm 'g) NA (cA 1)) 'b (pin (sm 'b) NA (cA 2)) 'at (pin (sm 'at) NA (NA * 0.0 + sim))))
             [(peep (sm 'r) N 0.0) (peep (sm 'g) N 0.0) (peep (sm 'b) N 0.0)]))
     zs (N * 0.0) cols [(e 0 + d 0) (e 1 + d 1) (e 2 + d 2) zs zs (c 0) (c 1) (c 2)]
     ix (pin (iota (6 * mm) * 0 - 1) N (iota #N)) qs (corner (iota (#vb * 16)) 4)
     (q j) (peep ix (qs + j) 0) zq (qs * 0 - 1)
     ts (lace [(q 0) (q 1) (q (m + 1)) zq (q 0) (q (m + 1)) (q m) zq])
     (#N = 0 ? f (facets w h f (v 'cam) (lace cols) ts () (gem-tray [7] [0.0 0.0 0.0 0.0 0.0 96.0 (1.5 * lt 'expo)]))))
 ; the sky low ahead before the gain, 0 to 255: the colour a far thing fades to
 (mesh-haze v lt wx sim) (: th (v 'th) e (v 'e)
   c (sky-near lt wx (gem-tray [1] [(sin th)]) (gem-tray [1] [0.02]) (gem-tray [1] [(cos th)]) (e 0) (e 2) sim)
   [(255.0 * peep (c 0) 0 0.0) (255.0 * peep (c 1) 0 0.0) (255.0 * peep (c 2) 0 0.0)])
 ; a frame, a flat w*h colour tray: sc [verts tris] or [verts tris sun], sun () or [view
 ; depths bias]; fog [r g b near far] 0 to 255; gain sky-tone's, 0 none; bare a colour,
 ; (\ v S ..) for bare pixels S, or [base over]: (base v) drawn under, (over v f B) finishes; a
 ; bare pixel below -1 keeps a glow, -1 less its colour, put on what fills it, and one at or
 ; below -2^25 a glass's tint and sheen, -2^25 less tint + 2^24 sheen / 4, what fills it seen
 ; through them
 ; v 'under a coarser frame of mesh-coarse's, laid first where it drew
 (mesh-frame v sc texs fog flags gain bare) (: B0 (two? bare ? (<bare v) -1) B (peep v 'under () @ () B0 u [B0 (u 0) (u 1)])
   sun (#sc < 3 ? () (sc 2)) bias (two? sun ? (sun 2) 0.0)
   o (gem-tray [8] [(1.0 * fog 0) (1.0 * fog 1) (1.0 * fog 2) (1.0 * fog 3) (1.0 * fog 4) (1.0 * (flags | 64)) (1.0 * gain) bias])
   f (facets (v 'w) (v 'h) B (v 'cam) (sc 0) (sc 1) texs (#sc < 3 ? o [o (two? sun ? (sun 0) ()) (two? sun ? (sun 1) ())]))
   (? (two? bare) (<>bare v f B0)
      (: S (iota (f < 0)) (#S = 0 ? f (pin f S (glowed (charm? bare ? (S * 0 + bare) (bare v S)) (-1 - peep f S 0)))))))
 ; ..colours s with the glows g kept on their bare pixels added, or through the tints kept
 (glowed s g) (: t (g >= 33554431) v (g - 33554431)
   (ch k) (t * min ((s >> k & 255) * (v >> k & 255) // 255 + 4 * (v >> 24)) 255 + (1 - t) * min ((s >> k & 255) + (g >> k & 255)) 255)
   ((ch 16 << 16) | (ch 8 << 8) | ch 0))
 ; ..sc drawn k times coarser, through v's camera: its colours and its depths, for v 'under
 (mesh-coarse v sc texs fog flags gain k) (: W (max2 1 (v 'w // k)) H (max2 1 (v 'h // k))
   (o fl) (gem-tray [8] [(1.0 * fog 0) (1.0 * fog 1) (1.0 * fog 2) (1.0 * fog 3) (1.0 * fog 4) (1.0 * fl) (1.0 * gain) 0.0])
   [(facets W H -1 (v 'cam) (sc 0) (sc 1) texs (o (flags | 64))) (facets W H -1 (v 'cam) (sc 0) (sc 1) texs (o (flags | 16)))])
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
   ov (peep st 'over {}) rs (sort (keys bands + keys ov))
   up (window-blit win Q w h (map (r \ [(16 * r) (16 * r + 16)]) rs))
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
 mesh-gone (mesh-kitty-del 7 + mesh-kitty-del 8)

 ; --- glb, glTF 2.0 in one file, for a modeller: a mesh written out and read back. glTF is
 ;     right-handed, so x runs the other way there and a front turns the same; its colours
 ;     are linear light, ours as seen ---
 (glb-u32 s i) (s i | s (i + 1) << 8 | s (i + 2) << 16 | s (i + 3) << 24)
 (glb-u16 s i) (s i | s (i + 1) << 8)
 (glb-le v) [(v & 255) (v >> 8 & 255) (v >> 16 & 255) (v >> 24 & 255)]
 ; ..a binary32's bits as a float, and a float's; the infinities and nans read as nothing
 (glb-f32 b) (: e (b >> 23 & 255) m (b & 8388607)
   v (? (e = 0) (m * (2.0 ** -149)) (e = 255) 0.0 ((1.0 + m / 8388608.0) * (2.0 ** (e - 127))))
   (b >> 31 = 1 ? (0.0 - v) v))
 (glb-bits x) (? (x = 0.0) 0
   (: a (x < 0.0 ? (0.0 - x) x) s (x < 0.0 ? 2147483648 0) e0 (floor (log a / log 2.0))
      e (? (2.0 ** (e0 + 1) <= a) (e0 + 1) (a < 2.0 ** e0) (e0 - 1) e0)
      (? (e < -126) (s | int (a / (2.0 ** -149) + 0.5))
         (e > 127) (s | 2139095040)
         (: m (int ((a / (2.0 ** e) - 1.0) * 8388608.0 + 0.5))
            (m = 8388608 ? (s | (e + 128) << 23) (s | (e + 127) << 23 | m))))))
 (glb-lin c) (: k (max2 0.0 (min2 1.0 c)) (k <= 0.04045 ? (k / 12.92) (((k + 0.055) / 1.055) ** 2.4)))
 (glb-srgb c) (: k (max2 0.0 (min2 1.0 c)) (k <= 0.0031308 ? (12.92 * k) (1.055 * (k ** (1.0 / 2.4)) - 0.055)))
 ; ..m as a .glb named name: one node, one primitive, its positions, normals, colours and
 ; triangles, under a plain white matte; a triangle's texture is left behind
 (mesh-glb-of m name) (: vs (m 0) ts (m 1) n #vs
   ps (map (v \ map (x \ glb-f32 (glb-bits x)) [(0.0 - v 0) (v 1) (v 2)]) vs) ns (map (v \ [(0.0 - v 5) (v 6) (v 7)]) vs)
   cs (map (v \ map (k \ glb-lin (v k)) [8 9 10]) vs)
   (fl l) (cats (map (p \ cats (map (x \ glb-le (glb-bits x)) p)) l))
   pb (fl ps) nb (fl ns) cb (fl cs) ib (cats (map (t \ cats (map (k \ glb-le (t k)) ^3)) ts))
   (ext f) (map (k \ foldl (\ a p (f a (p k))) (ps 0 k) ps) ^3)
   (view o l g) {"buffer" 0 "byteOffset" o "byteLength" l "target" g}
   (acc v ty c ct) {"bufferView" v "componentType" ct "count" c "type" ty}
   j (json-show {"asset" {"version" "2.0" "generator" "lore"} "scene" 0 "scenes" [{"nodes" [0]}]
                 "nodes" [{"mesh" 0 "name" name}]
                 "meshes" [{"name" name "primitives" [{"attributes" {"POSITION" 0 "NORMAL" 1 "COLOR_0" 2} "indices" 3 "mode" 4 "material" 0}]}]
                 "materials" [{"name" name "pbrMetallicRoughness" {"baseColorFactor" [1.0 1.0 1.0 1.0] "metallicFactor" 0.0 "roughnessFactor" 1.0}}]
                 "accessors" [(pins (acc 0 "VEC3" n 5126) "min" (ext min2) "max" (ext max2))
                              (acc 1 "VEC3" n 5126) (acc 2 "VEC3" n 5126) (acc 3 "SCALAR" (3 * #ts) 5125)]
                 "bufferViews" [(view 0 #pb 34962) (view #pb #nb 34962) (view (#pb + #nb) #cb 34962) (view (#pb + #nb + #cb) #ib 34963)]
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
         (: g (r 1) avs (peep g "accessors" ()) bvs (peep g "bufferViews" ())
            (wide ct) (ct @ 5126 4 5125 4 5123 2 5122 2 1)
            (comp ct o nm) (? (ct = 5126) (glb-f32 (glb-u32 s o)) (ct = 5125) (glb-u32 s o)
                              (ct = 5123) (glb-u16 s o @ v (nm ? (v / 65535.0) v))
                              (ct = 5122) (glb-u16 s o @ v (: w (v < 32768 ? v (v - 65536)) (nm ? (max2 -1.0 (w / 32767.0)) w)))
                              (ct = 5121) (s o @ v (nm ? (v / 255.0) v))
                              (s o @ v (: w (v < 128 ? v (v - 256)) (nm ? (max2 -1.0 (w / 127.0)) w))))
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
                            R [[(1.0 - 2.0 * (y * y + qz * qz)) (2.0 * (x * y - w * qz)) (2.0 * (x * qz + w * y))]
                               [(2.0 * (x * y + w * qz)) (1.0 - 2.0 * (x * x + qz * qz)) (2.0 * (y * qz - w * x))]
                               [(2.0 * (x * qz - w * y)) (2.0 * (y * qz + w * x)) (1.0 - 2.0 * (x * x + y * y))]]
                            [(map (r \ map (c \ R r c * z c) ^3) ^3) t]))
            (mul A B) [(map (r \ map (c \ net (map (k \ A 0 r k * B 0 k c) ^3)) ^3) ^3)
                       (map (r \ A 1 r + net (map (k \ A 0 r k * B 1 k) ^3)) ^3)]
            (on M p) (map (r \ M 1 r + net (map (k \ M 0 r k * p k) ^3)) ^3)
            ; ..a normal's way: the cofactors, the inverse's transpose but for its size and sign
            (cof M) (: m (M 0) (rc r c) (: a (m ((r + 1) % 3)) b (m ((r + 2) % 3)) (a ((c + 1) % 3) * b ((c + 2) % 3) - a ((c + 2) % 3) * b ((c + 1) % 3)))
                      (map (r \ map (c \ rc r c) ^3) ^3))
            (det M) (: m (M 0) (net (map (c \ m 0 c * (m 1 ((c + 1) % 3) * m 2 ((c + 2) % 3) - m 1 ((c + 2) % 3) * m 2 ((c + 1) % 3))) ^3)))
            (prim M p) (: at (p "attributes") P (acc (at "POSITION")) n #P C (cof M) sg (det M < 0.0 ? -1.0 1.0)
                          N (elem "NORMAL" (keys at) ? (acc (at "NORMAL")) ())
                          K (elem "COLOR_0" (keys at) ? (acc (at "COLOR_0")) ())
                          mt (peep p "material" () @ () {} i (peep (peep g "materials" ()) i {}))
                          f (peep (peep mt "pbrMetallicRoughness" {}) "baseColorFactor" [1.0 1.0 1.0 1.0])
                          I (elem "indices" (keys p) ? (map cap (acc (p "indices"))) ^n)
                          vs (map (i \ (: q (on M (P i)) w (two? N ? (unit (map (r \ sg * net (map (c \ C r c * N i c) ^3)) ^3)) [0.0 1.0 0.0])
                                          k (two? K ? (K i) [1.0 1.0 1.0])
                                          [(0.0 - q 0) (q 1) (q 2) 0.0 0.0 (0.0 - w 0) (w 1) (w 2)
                                           (glb-srgb (k 0 * f 0)) (glb-srgb (k 1 * f 1)) (glb-srgb (k 2 * f 2))]))
                                  ^n)
                          ts (map (k \ (: a (I (3 * k)) b (I (3 * k + 1)) c (I (3 * k + 2)) (sg < 0.0 ? [a c b -1] [a b c -1]))) ^(#I // 3))
                          (two? N ? (mesh vs ts) (mesh-normals (mesh vs ts))))
            (walk i M) (: n (peep g "nodes" () i) M2 (mul M (place n))
                          here (elem "mesh" (keys n) ? (map (p \ prim M2 p) (filter (p \ peep p "mode" 4 = 4) (peep g "meshes" () (n "mesh") "primitives")))
                                 ())
                          (here + cats (map (c \ walk c M2) (peep n "children" ()))))
            sc (peep (peep g "scenes" ()) (peep g "scene" 0) {})
            ms (cats (map (i \ walk i [[[1.0 0.0 0.0] [0.0 1.0 0.0] [0.0 0.0 1.0]] [0.0 0.0 0.0]]) (peep sc "nodes" ())))
            (two? ms ? (mesh-join ms) ()))))))
) ; module mesh
