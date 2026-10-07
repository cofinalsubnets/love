; mesh -- what a level drawn in triangles rides: meshes as lists, built from a few shapes
; and joined, lit once by the sky's sun, packed into trays for facets (src/love/raster.c);
; a camera; textures and their levels; and the frame out to the terminal, as half blocks
; or as kitty's pixels.
; the world is lore's: x right, y up, z ahead when 'th is 0, 'th turning toward x.
(module (mesh mesh mesh-join mesh-move mesh-quad mesh-box mesh-grid mesh-lathe mesh-normals
         mesh-keep mesh-pack mesh-bake mesh-bake-sun mesh-sun-view mesh-sun-map mesh-open mesh-tex mesh-view mesh-eye mesh-dirs mesh-spot mesh-sky mesh-haze mesh-frame mesh-flat
         mesh-cells mesh-kitty)
(borrow 'view)
(borrow 'vec)
(borrow 'sky)
(:
 ; a mesh: [vs ts], each vertex [x y z u v nx ny nz r g b] -- place, texels, normal, the
 ; surface's own colour -- and each triangle [a b c tex], tex -1 for none
 (mesh vs ts) [vs ts]
 (sub a b) [(a 0 - b 0) (a 1 - b 1) (a 2 - b 2)]
 (cat l) (foldr (+) () l)
 (mesh-join ms) (: (go ms k vs ts) (atom? ms ? (mesh (cat (rev vs)) (cat (rev ts)))
                   (: m <ms (go >ms (k + #(m 0)) (m 0 . vs) (map (t \ [(t 0 + k) (t 1 + k) (t 2 + k) (t 3)]) (m 1) . ts))))
                   (go ms 0 () ()))
 ; turned by yaw about y (toward x as 'th turns), then moved by d
 (mesh-move m d yaw) (: c (cos yaw) s (sin yaw)
   (rot x z) [(x * c + z * s) (z * c - x * s)]
   (mesh (map (v \ (: p (rot (v 0) (v 2)) q (rot (v 5) (v 7))
                     [(p 0 + d 0) (v 1 + d 1) (p 1 + d 2) (v 3) (v 4) (q 0) (v 6) (q 1) (v 8) (v 9) (v 10)]))
              (m 0))
         (m 1)))
 ; four corners going round, their texels, a texture and a colour: two triangles, the
 ; front the side the corners turn anticlockwise from
 (mesh-quad ps uvs tex col) (: n (unit (cross (sub (ps 3) (ps 0)) (sub (ps 1) (ps 0))))
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
  (: vs (cat (map (i \ map (j \ f i j + [0.0 0.0 0.0] + col) ^(nv + 1)) ^(nu + 1)))
     (at i j) (i * (nv + 1) + j)
     ts (cat (map (k \ (: i (k // nv) j (k % nv) a (at i j) b (at (i + 1) j) c (at (i + 1) (j + 1)) d (at i (j + 1))
                        [[a b c tex] [a c d tex]]))
                  ^(nu * nv)))
     (mesh-normals (mesh vs ts)))
 ; a profile of [r y] turned n times round the y axis, its texels k a unit
 (mesh-lathe prof n tex col k)
  (: (len i) (: (go j s) (j < i ? (go (j + 1) (s + sqrt (sq (prof (j + 1) 0 - prof j 0) + sq (prof (j + 1) 1 - prof j 1)))) s) (go 0 0.0))
     (mesh-grid n (#prof - 1)
       (\ i j (: a (2.0 * pi * i / n) r (prof j 0)
                  [(r * sin a) (prof j 1) (r * cos a) (k * a * prof 0 0) (k * len j)]))
       tex col))
 ; the vertices' places as trays [x y z], read by index in one step where a list walks
 (places vs) (: n #vs (map (k \ gem-tray [n] (map (v \ 1.0 * v k) vs)) ^3))
 (at3 P i) [(peep (P 0) i 0.0) (peep (P 1) i 0.0) (peep (P 2) i 0.0)]
 ; ..each with its index, in order
 (indexed l) (rev (<>(foldl (\ st v [(<st + 1) ([v <st] . <>st)]) [0 ()] l)))
 ; only the triangles whose middles (keep? x y z)
 (mesh-keep m keep?) (: P (places (m 0))
   (mesh (m 0) (filter (t \ (: a (at3 P (t 0)) b (at3 P (t 1)) c (at3 P (t 2))
                             (keep? ((a 0 + b 0 + c 0) / 3.0) ((a 1 + b 1 + c 1) / 3.0) ((a 2 + b 2 + c 2) / 3.0))))
                       (m 1))))
 ; each vertex's normal the sum of its faces', weighed by their size
 (mesh-normals m) (: vs (m 0) P (places vs) acc {}
   (add i n) (pin acc i (peep acc i [0.0 0.0 0.0] @ o [(o 0 + n 0) (o 1 + n 1) (o 2 + n 2)]))
   _ (each (m 1) (t \ (: a (at3 P (t 0)) b (at3 P (t 1)) c (at3 P (t 2))
                        n (cross (sub c a) (sub b a))
                        (add (t 0) n, add (t 1) n, add (t 2) n))))
   (mesh (map (q \ (: v <q n (unit (peep acc <>q [0.0 1.0 0.0])) (take 5 v + n + drop 8 v))) (indexed vs)) (m 1)))
 ; a mesh packed for drawing: its vertices as columns, trays [x y z u v nx ny nz r g b],
 ; and its triangles as the tray facets takes
 (mesh-pack m) (: vs (m 0) n #vs ft (cat (m 1))
   {'n n 'cols (map (k \ gem-tray [n] (map (v \ 1.0 * v k) vs)) ^11) 'tris (star-tray [#ft] ft)})
 ; ..lit by the sky's sun and its ambient: (light cols) says each vertex's [sun sky glow]
 ; -- its share of the sun past what stands between, of the sky's light, and () or the
 ; [r g b] it takes besides -- trays or numbers; the colour the light on it times its own,
 ; gain over all. the scene [verts tris] mesh-frame draws
 (mesh-bake pk lt light gain) (: c (pk 'cols) n (pk 'n) s (lt 'sun) amb (lt 'amb) sc (lt 'sunc)
   L (light c)
   sun (max 0.0 (c 5 * s 0 + c 6 * s 1 + c 7 * s 2) * (L 0) * lt 'sunk)
   (lit k) (gain * c (8 + k) * ((L 1) * amb k + sun * sc k + (two? (L 2) ? (L 2 k) 0.0)))
   cols [(c 0) (c 1) (c 2) (c 3) (c 4) (lit 0) (lit 1) (lit 2)]
   i (iota n * 8)
   [(foldl (\ v k (pin v (i + k) (cols k))) (iota (8 * n) * 0.0) ^8) (pk 'tris)])
 ; ..or the sun's light apart, for a frame that shades by the sun's view: 11 a vertex, the
 ; light from the sky and round about, then the sun's
 (mesh-bake-sun pk lt light gain) (: c (pk 'cols) n (pk 'n) s (lt 'sun) amb (lt 'amb) sc (lt 'sunc)
   L (light c)
   sun (max 0.0 (c 5 * s 0 + c 6 * s 1 + c 7 * s 2) * (L 0) * lt 'sunk)
   (sky k) (gain * c (8 + k) * ((L 1) * amb k + (two? (L 2) ? (L 2 k) 0.0)))
   (lit k) (gain * c (8 + k) * sun * sc k)
   cols [(c 0) (c 1) (c 2) (c 3) (c 4) (sky 0) (sky 1) (sky 2) (lit 0) (lit 1) (lit 2)]
   i (iota n * 11)
   [(foldl (\ v k (pin v (i + k) (cols k))) (iota (11 * n) * 0.0) ^11) (pk 'tris)])
 ; the sun's view of a place round c: along its light, half metres either side and deep
 ; along it, its matrix for facets
 (mesh-sun-view lt c half deep) (: s (lt 'sun)
   r (unit (mag (s 1) < 0.99 ? (cross [0.0 1.0 0.0] s) [1.0 0.0 0.0])) u (cross s r)
   (row a k) [(a 0 / k) (a 1 / k) (a 2 / k) (0.0 - dot a c / k)]
   (gem-tray [16] (row r half + row u half + row (sub [0.0 0.0 0.0] s) deep + [0.0 0.0 0.0 1.0])))
 ; ..and what it sees there of the scene [verts tris], baked with the sun apart: an n by n
 ; tray of depths, for mesh-frame's sun
 (mesh-sun-map sv sc n)
   (facets n n -1 sv (sc 0) (sc 1) () [(gem-tray [6] [0.0 0.0 0.0 0.0 0.0 16.0]) () ()])
 ; ..the open sky's light alone, the sun on everything: what a level with nothing to cast
 ; a shadow lights by
 (mesh-open c) [1.0 (0.6 + 0.4 * c 6) ()]
 ; --- textures: n by n, (f x y) a colour [r g b] 0 to 1 or () for a hole; each level
 ;     half the last, a texel the mean of four, a hole where two or more were ---
 (q v) (int (sat v * 255.0 + 0.5))
 (word c) ((q (c 0) << 16) | (q (c 1) << 8) | q (c 2))
 (mesh-tex n f)
  (: l0 (map (i \ f (i % n) (i // n)) ^(n * n))
     (down m l) (: h (m // 2)
       (map (i \ (: x (2 * (i % h)) y (2 * (i // h))
                    q (filter two? [(l (y * m + x)) (l (y * m + x + 1)) (l ((y + 1) * m + x)) (l ((y + 1) * m + x + 1))])
                    (#q < 3 ? () (c* (1.0 / #q) (foldl c+ [0.0 0.0 0.0] q)))))
            ^(h * h)))
     (lay m l) (star-tray [m m] (map (c \ two? c ? (word c) -1) l))
     (go m l) (lay m l . (m < 2 ? () (go (m // 2) (down m l))))
     (go n l0))
 ; --- the view: a screen w by h, the eye at e facing th and tilted up by ph, fov wide
 ;     across, nothing nearer than near nor past far; 'cam the matrix facets takes, clip
 ;     space gl's with z ahead ---
 (mesh-view w h e th ph fov near far) (mesh-eye w h e th ph 0.0 fov near far)
 ; ..and the head tilted ro toward its right shoulder as well
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
 ; lore's sky through the eye's gain, for mesh-frame's bare: k 1 the colours of the pixels
 ; S of the view v left bare, the sky's stars a pixel each among them; k past 1 the sky
 ; asked at the corners of k by k squares and shaded across each by facets, under the
 ; scene, and the stars put on after where the scene left them showing
 (mesh-sky lt wx e sim t0 k)
  (: X (sky-stars 'x) Y (sky-stars 'y) Z (sky-stars 'z)
     (shine c ix) (word (sky-tone lt (sky-stars! c lt wx (e 0) (e 2) sim t0 ix)))
     (k <= 1
      ? (\ v S (: at (pin (iota (v 'w * v 'h) * 0 - 1) S (iota #S)) d (mesh-dirs v S)
                  (shine (sky-colour-of lt wx (d 0) (d 1) (d 2) (e 0) (e 2) sim) (peep at (mesh-spot v X Y Z) -1))))
        [(v \ sky-grid v lt wx e sim k)
         (\ v f B (: sp (mesh-spot v X Y Z) ix (over -1 (peep f sp -2 = peep B sp -3) (iota #X))
                     (pin f (over -1 (0 <= ix) sp) (shine (sky-colour-of lt wx X Y Z (e 0) (e 2) sim) ix))))]))
 ; the sky over the whole view, asked every k pixels across and down, a flat tray
 (sky-grid v lt wx e sim k)
  (: w (v 'w) h (v 'h) gw (w // k + 2) gh (h // k + 2) G (iota (gw * gh)) gi (G % gw) gj (G // gw)
     d (rays v (1.0 * k * gi) (1.0 * k * gj))
     c (sky-colour-of lt wx (d 0) (d 1) (d 2) (e 0) (e 2) sim)
     z (G * 0.0) nv (gw * gh)
     cols [(2.0 * k * gi / w - 1.0) (1.0 - 2.0 * k * gj / h) z z z (c 0) (c 1) (c 2)]
     vs (foldl (\ t i (pin t (iota nv * 8 + i) (cols i))) (iota (8 * nv) * 0.0) ^8)
     C (iota ((gw - 1) * (gh - 1))) q (C // (gw - 1) * gw + C % (gw - 1))
     cs [q (q + 1) (q + gw + 1) (q * 0 - 1) q (q + gw + 1) (q + gw) (q * 0 - 1)]
     ts (foldl (\ t i (pin t (C * 8 + i) (cs i))) (iota (8 * #C) * 0) ^8)
     one (gem-tray [16] [1.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 0.0 1.0])
     (peep (facets w h 0 one vs ts () (gem-tray [7] [0.0 0.0 0.0 0.0 0.0 0.0 (1.5 * lt 'expo)])) (iota (w * h)) 0))
 ; the sky low ahead before the gain, 0 to 255: the colour a far thing fades to
 (mesh-haze v lt wx sim) (: th (v 'th) e (v 'e)
   c (sky-near lt wx (gem-tray [1] [(sin th)]) (gem-tray [1] [0.02]) (gem-tray [1] [(cos th)]) (e 0) (e 2) sim)
   [(255.0 * peep (c 0) 0 0.0) (255.0 * peep (c 1) 0 0.0) (255.0 * peep (c 2) 0 0.0)])
 ; a frame, a flat tray of colours w*h long: the scene [verts tris], each a tray or a
 ; list of batches, or [verts tris sun] baked with the sun apart and sun () or [view depths
 ; bias] its view (mesh-sun-view and -map) and its slack, with its textures, fog [r g b near far] 0 to 255, facets's flags and
 ; the eye's gain (sky-tone's, 0 for none); and where it left the screen bare, bare: a
 ; colour, (\ v S ..) the colours of pixels S of the view, or [base over]: (base v) the
 ; ground drawn over, and (over v f B) the frame f finished
 (mesh-frame v sc texs fog flags gain bare) (: n (v 'w * v 'h) B (two? bare ? (<bare v) -1)
   sun (#sc < 3 ? () (sc 2)) bias (two? sun ? (sun 2) 0.0)
   o (gem-tray [8] [(1.0 * fog 0) (1.0 * fog 1) (1.0 * fog 2) (1.0 * fog 3) (1.0 * fog 4) (1.0 * flags) (1.0 * gain) bias])
   f (peep (facets (v 'w) (v 'h) B (v 'cam) (sc 0) (sc 1) texs
                   (#sc < 3 ? o [o (two? sun ? (sun 0) ()) (two? sun ? (sun 1) ())]))
           (iota n) 0)
   (? (two? bare) (<>bare v f B)
      (: S (iota (f = -1)) (#S = 0 ? f (pin f S (charm? bare ? bare (bare v S)))))))
 ; a frame's colours as [r g b] trays, 0 to 1
 (mesh-flat f) [((f >> 16 & 255) / 255.0) ((f >> 8 & 255) / 255.0) ((f & 255) / 255.0)]
 ; ..and as half-block cells: 24-bit, or the 256 cube dithered by bay; bands view's words
 (mesh-cells f w h deep bay bands) (: c (mesh-flat f)
   (deep ? (view-deep-frame w h (view-deep-pens c) bands)
      (view-cube-pens c bay @ px (view-frame w h (y \ peep px (iota w + w * y) 0) bands))))
 ; ..or as kitty's pixels over cols by rows cells from the cursor, which stays, under any
 ; text put over them: image id,
 ; the rgb in base64 4096 bytes a chunk
 (mesh-kitty f w h cols rows id) (: b (frame-bytes f 2 1) n #b o (jug 0)
   (go i) (: j (min n (i + 4096))
             (say o (esc + "_G" + (i = 0 ? ("a=T,f=24,q=2,C=1,z=-1,i=" + show id + ",s=" + show w + ",v=" + show h
                                            + ",c=" + show cols + ",r=" + show rows + ",") "")
                     + "m=" + (j < n ? "1" "0") + ";" + snip b i j + esc + "\\"),
              j < n ? (go j) (slurp o)))
   (go 0)))
) ; module mesh
