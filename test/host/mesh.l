; test/host/mesh.l -- src/apps/lore/mesh.l: the camera's sense of left and up, which faces a
; shape shows from where, a texture's levels, the sun on a face, the sky behind, and the
; frame out as half blocks and as kitty's pixels read back off a quay screen.
; not in the corpus: a crew module. run: cat test/00-init.l test/host/mesh.l | out/love
(borrow 'mesh)
(borrow 'view)     ; pi
(borrow 'sky)
(: W 40 H 24 white [1.0 1.0 1.0]
   (mh-cat l) (foldr (+) () l)
   (mh-count n s) (:- (go 0 0) (go i k) (i + #n <= #s ? (go (i + 1) (k + (n = snip s i (i + #n)))) k))
   lt {'sun [0.0 1.0 0.0] 'amb [0.2 0.2 0.2] 'sunk 1.0 'sunc [1.0 1.0 1.0] 'expo 1.0}
   (lit m) (mesh-bake (mesh-pack m) lt mesh-open 1.0)
   (vw e th ph) (mesh-view W H e th ph 1.4 0.1 100.0)
   (draw m e th ph fl) (mesh-frame (vw e th ph) (lit m) () [0 0 0 0.0 0.0] fl 0.0 7)
   (at f x y) (peep f (y * W + x) 0)
   mid (W // 2) cen (H // 2)
   ; a small box 5 ahead of the origin, and the eye stepped round it
   bx (mesh-box [0.0 0.0 5.0] [0.5 0.5 0.5] 0.0 -1 white 1.0)
   (round k) (: a (k * pi / 2.0) (at (draw bx [(0.0 - 5.0 * sin a) 0.0 (5.0 - 5.0 * cos a)] a 0.0 8) mid cen))
   ; a box off to the right of the eye lands right of the middle; looking up drops it
   rb (mesh-box [2.0 0.0 5.0] [0.3 0.3 0.3] 0.0 -1 white 1.0)
   (cols f) (filter (x \ any (y \ at f x y != 7) ^H) ^W)
   (rows f) (filter (y \ any (x \ at f x y != 7) ^W) ^H)
   right (draw rb [0.0 0.0 0.0] 0.0 0.0 8)
   up (draw rb [0.0 0.0 0.0] 0.0 0.3 8)
   ; a lathe round the eye shows its inside; a sheet below shows its top
   bowl (mesh-lathe [[6.0 -1.0] [6.0 3.0]] 16 -1 white 1.0)
   sheet (mesh-grid 4 4 (\ i j [(2.0 * i - 4.0) -1.0 (2.0 * j - 4.0) 0.0 0.0]) -1 white)
   ; the sun overhead: a top face is lit, a side is the ambient alone, unshaded or shaded
   cube (mesh-pack (mesh-box [0.0 0.0 0.0] [1.0 1.0 1.0] 0.0 -1 white 1.0))
   tops (mesh-bake cube lt mesh-open 1.0)
   shd (mesh-bake cube lt (\ c [0.0 (0.6 + 0.4 * c 6) ()]) 1.0)
   glo (mesh-bake cube lt (\ c [0.0 0.0 [0.5 0.5 0.5]]) 1.0)
   (bright sc) (amax (peep (sc 0) (iota 24 * 8 + 5) 0.0))
   ; a texture's levels: 8, 4, 2, 1 across; holes past half a cell's four
   tx (mesh-tex 8 (\ x y (x < 4 ? [1.0 0.0 0.0] [0.0 0.0 1.0])))
   hx (mesh-tex 4 (\ x y (y < 2 && x < 3 ? () white)))
   ; joined, the second's triangles count past the first's vertices
   jn (mesh-join [bx rb])
   mv (mesh-move bx [1.0 2.0 3.0] (pi / 2.0))
   ; out: half blocks, 24-bit and the cube; and kitty's, 80 by 64 over 10 by 4 cells
   f0 (draw bx [0.0 0.0 0.0] 0.0 0.0 8)
   big (mesh-frame (mesh-view 80 64 [0.0 0.0 0.0] 0.0 0.0 1.4 0.1 100.0) (lit bx) () [0 0 0 0.0 0.0] 0 0.0 1193046)
   scr (screen (cask (screen () 4 10)) 4 10)
   _ (scribe scr (mesh-kitty big 80 64 10 4 3))
   back (map (i \ (: x (i % 80) y (i // 80) (tilepx scr (y // 16 * 10 + x // 8) (x % 8) (y % 16)))) ^(80 * 64))
   wx (sky-weather 0 'smooth) noon (1.0 * 1790812800 + 12.0 * 3600.0)
   sl (sky-light (sky-sun noon 0.0 0.65) wx noon)
   ; the sky where the box leaves the screen bare, and the same sky asked alone
   v0 (vw [0.0 0.0 0.0] 0.0 0.0)
   skf (mesh-sky sl wx [0.0 0.0 0.0] noon 0.0 0.0)
   sk (skf (mesh-dirs v0 (iota (W * H))))
   fs (mesh-frame v0 (lit bx) () [0 0 0 0.0 0.0] 8 0.0 skf)
 (test (all (k \ round k != 7) ^4)
       (mid < <(cols right))
       (#(rows up) = 0 || <(rows up) > <(rows right))
       (at (draw bowl [0.0 0.0 0.0] 0.0 0.0 8) mid cen != 7)
       (at (draw bowl [0.0 0.0 0.0] 1.0 0.0 8) mid cen != 7)
       (at (draw sheet [0.0 1.0 0.0] 0.0 -0.8 8) mid cen != 7)
       (at (draw sheet [0.0 -3.0 0.0] 0.0 0.8 8) mid cen = 7)
       (1.1 < bright tops) (bright shd < 0.3) (bright glo = 0.5)
       (#((mesh-keep bx (\ x y z (x < -0.4))) 1) = 2) (#((mesh-keep bx (\ x y z 1)) 1) = 12)
       (map shape tx = [[8 8] [4 4] [2 2] [1 1]])
       (peep (tx 0) [0 0] 0 = 16711680) (peep (tx 2) [0 0] 0 = 16711680) (peep (tx 2) [0 1] 0 = 255)
       (peep (hx 0) [0 0] 0 = -1) (peep (hx 1) [0 0] 0 = -1) (peep (hx 1) [0 1] 0 = -1) (peep (hx 1) [1 0] 0 != -1)
       (#(jn 0) = 48) (#(jn 1) = 24) (jn 1 12 0 = 24) (amax (gem-tray [72] (mh-cat (map (t \ take 3 t) (jn 1)))) = 47)
       (mv 0 0 1 = bx 0 0 1 + 2.0)
       (has? (mesh-cells f0 W H 1 0 {}) "38;2;") (has? (mesh-cells f0 W H 0 (view-bayer W H) {}) "38;5;")
       (mh-count "\r\n" (mesh-cells f0 W H 1 0 {}) = H // 2 - 1)
       (back = map (i \ 4278190080 | peep big i 0) ^(80 * 64))
       (shape sk = [(W * H)]) (0 < amin sk)
       (at fs mid cen = at f0 mid cen) (at fs 0 0 = peep sk 0 0) (at fs (W - 1) 0 = peep sk (W - 1) 0)))
