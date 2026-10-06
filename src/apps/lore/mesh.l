; mesh -- what a level drawn in triangles rides: meshes as lists, built from a few shapes
; and joined, lit once by the sky's sun, packed into trays for facets (src/love/raster.c);
; a camera; textures and their levels; and the frame out to the terminal, as half blocks
; or as kitty's pixels.
; the world is lore's: x right, y up, z ahead when 'th is 0, 'th turning toward x.
(module (mesh mesh mesh-join mesh-move mesh-quad mesh-box mesh-grid mesh-lathe mesh-normals
         mesh-keep mesh-pack mesh-bake mesh-open mesh-tex mesh-view mesh-dirs mesh-sky mesh-haze mesh-frame mesh-flat
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
 ; only the triangles whose middles (keep? x y z)
 (mesh-keep m keep?) (: vs (m 0)
   (mesh vs (filter (t \ (: a (vs (t 0)) b (vs (t 1)) c (vs (t 2))
                          (keep? ((a 0 + b 0 + c 0) / 3.0) ((a 1 + b 1 + c 1) / 3.0) ((a 2 + b 2 + c 2) / 3.0))))
                    (m 1))))
 ; each vertex's normal the sum of its faces', weighed by their size
 (mesh-normals m) (: vs (m 0) acc {}
   (add i n) (pin acc i (peep acc i [0.0 0.0 0.0] @ o [(o 0 + n 0) (o 1 + n 1) (o 2 + n 2)]))
   _ (each (m 1) (t \ (: a (vs (t 0)) b (vs (t 1)) c (vs (t 2))
                        n (cross (sub c a) (sub b a))
                        (add (t 0) n, add (t 1) n, add (t 2) n))))
   (mesh (map (i \ (: v (vs i) n (unit (peep acc i [0.0 1.0 0.0])) (take 5 v + n + drop 8 v))) ^#vs) (m 1)))
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
 (mesh-view w h e th ph fov near far)
  (: st (sin th) ct (cos th) sp (sin ph) cp (cos ph)
     r [ct 0.0 (0.0 - st)] u [(0.0 - st * sp) cp (0.0 - ct * sp)] f [(st * cp) sp (ct * cp)]
     fx (1.0 / tan (fov / 2.0)) fy (fx * w / h)
     za ((far + near) / (far - near)) zb (-2.0 * far * near / (far - near))
     (row k a) [(k * a 0) (k * a 1) (k * a 2) (0.0 - k * dot a e)]
     z (row za f)
     {'w w 'h h 'e e 'th th 'ph ph 'fov fov
      'cam (gem-tray [16] (row fx r + row fy u + [(z 0) (z 1) (z 2) (z 3 + zb)] + row 1.0 f))})
 ; the directions through pixels ix of the view, unit [x y z] trays
 (mesh-dirs v ix) (: w (v 'w) h (v 'h) foc (w / 2.0 / tan (v 'fov / 2.0))
   U ((ix % w + 0.5 - w / 2.0) / foc) V ((h / 2.0 - ix // w - 0.5) / foc)
   th (v 'th) ph (v 'ph) st (sin th) ct (cos th) sp (sin ph) cp (cos ph)
   x (st * cp + U * ct - V * st * sp) y (sp + V * cp) z (ct * cp - U * st - V * ct * sp)
   l (sqrt (x * x + y * y + z * z))
   [(x / l) (y / l) (z / l)])
 ; lore's sky through the eye's gain, as the bare pixels' colours for mesh-frame; sf its
 ; stars' share
 (mesh-sky lt wx e sim t0 sf) (d \ word (sky-tone lt (sky-colour-of lt wx (d 0) (d 1) (d 2) (e 0) (e 2) sim t0 sf)))
 ; the sky low ahead before the gain, 0 to 255: the colour a far thing fades to
 (mesh-haze v lt wx sim) (: th (v 'th) e (v 'e)
   c (sky-near lt wx (gem-tray [1] [(sin th)]) (gem-tray [1] [0.02]) (gem-tray [1] [(cos th)]) (e 0) (e 2) sim)
   [(255.0 * peep (c 0) 0 0.0) (255.0 * peep (c 1) 0 0.0) (255.0 * peep (c 2) 0 0.0)])
 ; a frame, a flat tray of colours w*h long: the scene [verts tris], each a tray or a
 ; list of batches, with its textures, fog [r g b near far] 0 to 255, facets's flags and
 ; the eye's gain (sky-tone's, 0 for none); and where it left the screen bare, bare: a
 ; colour, or (d \ ..) the colours for directions d
 (mesh-frame v sc texs fog flags gain bare) (: n (v 'w * v 'h)
   f (peep (facets (v 'w) (v 'h) -1 (v 'cam) (sc 0) (sc 1) texs
                   (gem-tray [7] [(1.0 * fog 0) (1.0 * fog 1) (1.0 * fog 2) (1.0 * fog 3) (1.0 * fog 4) (1.0 * flags) (1.0 * gain)]))
           (iota n) 0)
   S (iota (f = -1))
   (#S = 0 ? f (pin f S (charm? bare ? bare (bare (mesh-dirs v S))))))
 ; a frame's colours as [r g b] trays, 0 to 1
 (mesh-flat f) [((f >> 16 & 255) / 255.0) ((f >> 8 & 255) / 255.0) ((f & 255) / 255.0)]
 ; ..and as half-block cells: 24-bit, or the 256 cube dithered by bay; bands view's words
 (mesh-cells f w h deep bay bands) (: c (mesh-flat f)
   (deep ? (view-deep-frame w h (view-deep-pens c) bands)
      (view-cube-pens c bay @ px (view-frame w h (y \ peep px (iota w + w * y) 0) bands))))
 ; ..or as kitty's pixels over cols by rows cells from the cursor, which stays: image id,
 ; the rgb in base64 4096 bytes a chunk
 (mesh-kitty f w h cols rows id) (: b (frame-bytes f 2 1) n #b o (jug 0)
   (go i) (: j (min n (i + 4096))
             (say o (esc + "_G" + (i = 0 ? ("a=T,f=24,q=2,C=1,i=" + show id + ",s=" + show w + ",v=" + show h
                                            + ",c=" + show cols + ",r=" + show rows + ",") "")
                     + "m=" + (j < n ? "1" "0") + ";" + snip b i j + esc + "\\"),
              j < n ? (go j) (slurp o)))
   (go 0)))
) ; module mesh
