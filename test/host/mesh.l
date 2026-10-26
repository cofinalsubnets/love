; test/host/mesh.l -- src/apps/lore/mesh.l: camera, faces, textures, sun, sky, lamps, and the
; frame as half blocks and as kitty pixels read back off a quay screen.
; not in the corpus: a crew module. run: cat test/00-init.l test/host/mesh.l | out/love
(borrow 'mesh)
(borrow 'view)     ; pi
(borrow 'sky)
(borrow 'json)
(: W 40 H 24 white [1.0 1.0 1.0]
   (mh-cat l) (foldr (+) () l)
   (mh-q v) (int (min 1.0 (max 0.0 v) * 255.0 + 0.5))
   (mh-word c) ((mh-q (c 0) << 16) | (mh-q (c 1) << 8) | mh-q (c 2))
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
   wx (sky-weather 0) noon (1.0 * 1790812800 + 12.0 * 3600.0)
   sl (sky-light (sky-sun noon 0.0 0.65) wx noon)
   ; the sky where the box leaves the screen bare, and the same sky asked alone
   v0 (vw [0.0 0.0 0.0] 0.0 0.0)
   skf (mesh-sky (sky-stars noon 0.0 0.65) sl wx [0.0 0.0 0.0] noon 0.0 1 ())
   sk (skf v0 (iota (W * H)))
   fs (mesh-frame v0 (lit bx) () [0 0 0 0.0 0.0] 8 0.0 skf)
   ; by night, looking up: the stars change at most one pixel each
   night (1.0 * 1790812800 + 1.0 * 3600.0) nl (sky-light (sky-sun night 0.0 0.65) wx night) ns (sky-stars night 0.0 0.65)
   vu (mesh-view W H [0.0 0.0 0.0] 0.0 1.5 1.4 0.1 100.0)
   zen (mesh-frame vu (lit bx) () [0 0 0 0.0 0.0] 8 0.0 (mesh-sky ns nl wx [0.0 0.0 0.0] night 0.0 1 ()))
   bare (mesh-frame vu (lit bx) () [0 0 0 0.0 0.0] 8 0.0
                    (\ v S (: d (mesh-dirs v S) (mh-word (sky-tone nl (sky-colour-at nl wx (mesh-step v 1) (d 0) (d 1) (d 2) 0.0 0.0 night))))))
   seen (net (-1 < mesh-spot vu (ns 'x) (ns 'y) (ns 'z)))
   ; ..of them on the open sky, the rest under a cloud's breath of the clear sky
   open (net ((-1 < mesh-spot vu (ns 'x) (ns 'y) (ns 'z)) * (sky-cloud wx (ns 'x) (ns 'y) (ns 'z) 0.0 0.0 night < 0.5)))
   lit-m (zen != bare) hot (iota lit-m)
   ; the sky asked every 4 pixels and shaded between: near the sky asked at each, the box
   ; the same; by night still a pixel per star in view
   fg (mesh-frame v0 (lit bx) () [0 0 0 0.0 0.0] 8 0.0 (mesh-sky (sky-stars noon 0.0 0.65) sl wx [0.0 0.0 0.0] noon 0.0 4 ()))
   (gap a b) (: p (mesh-flat a) q (mesh-flat b) (+(map (k \ net (max (p k - q k) (q k - p k))) ^3) / (3.0 * #a)))
   ; a box over a sheet, the sun overhead: the sheet shadowed under the box by the sun's
   ; view, lit away from it; without the view, lit throughout
   shs (mesh-bake-sun (mesh-pack sheet) lt mesh-open 1.0)
   cb (mesh-bake-sun (mesh-pack (mesh-box [0.0 0.0 0.0] [0.5 0.5 0.5] 0.0 -1 white 1.0)) lt mesh-open 1.0)
   sv (mesh-sun-view lt [0.0 0.0 0.0] 5.0 5.0) mp (mesh-sun-map sv cb 64)
   vd (mesh-view W H [0.0 5.0 0.0] 0.0 -1.5 1.4 0.1 100.0)
   fsh (mesh-frame vd [(shs 0) (shs 1) [sv mp 0.02]] () [0 0 0 0.0 0.0] 0 0.0 7)
   fno (mesh-frame vd [(shs 0) (shs 1) ()] () [0 0 0 0.0 0.0] 0 0.0 7)
   gk (mesh-sky ns nl wx [0.0 0.0 0.0] night 0.0 4 ())
   gk0 (mesh-sky (pins ns 'y (ns 'y * 0.0 - 1.0)) nl wx [0.0 0.0 0.0] night 0.0 4 ())
   hot4 (iota (mesh-frame vu (lit bx) () [0 0 0 0.0 0.0] 8 0.0 gk != mesh-frame vu (lit bx) () [0 0 0 0.0 0.0] 8 0.0 gk0))
   ; ..and by day none: the sky shaded between as it is, under a partly cloudy sky
   wp (sky-weather 1) lp (sky-light (sky-sun noon 0.0 0.65) wp noon)
   (dk s) (mesh-frame vu (lit bx) () [0 0 0 0.0 0.0] 8 0.0 (mesh-sky s lp wp [0.0 0.0 0.0] noon 0.0 4 ()))
   ds (sky-stars noon 0.0 0.65) ds0 (: u (sky-stars noon 0.0 0.65) (pins u 'y (u 'y * 0.0 - 1.0)))
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
       (at fs mid cen = at f0 mid cen) (at fs 0 0 = peep sk 0 0) (at fs (W - 1) 0 = peep sk (W - 1) 0)
       (0 < open) (0.9 * open <= #hot) (#hot <= seen)
       (at fg mid cen = at f0 mid cen) (two? gk) (gap fg fs < 0.01) (0.9 * open <= #hot4) (#hot4 <= seen)
       (0 < net (-1 < mesh-spot vu (ds 'x) (ds 'y) (ds 'z))) (net (dk ds != dk ds0) = 0)
       (shape mp = [64 64]) (at fsh mid cen < at fno mid cen) (at fsh (mid + 6) cen = at fno (mid + 6) cen)))
; --- a picture's texture: levels halved down to a side of one; from rgba bytes, each texel the
; mean under it, a hole where mostly clear
(: white [1.0 1.0 1.0]
   pc (mesh-pic 8 4 (\ x y (x < 4 ? [1.0 0.0 0.0] [0.0 0.0 1.0])))
   px "\xff\x00\x00\xff\x00\xff\x00\xff\x00\x00\xff\xff\x00\x00\x00\x00"
   r2 (mesh-rgba 2 2 px 2 2) r1 (mesh-rgba 2 2 px 1 1)
   ; ..a sheet faces where it is told, either way its sides are given
   (up? m) (all (v \ v 6 > 0.99) (m 0))
   sa (mesh-sheet [0.0 0.0 0.0] [1.0 0.0 0.0] [0.0 0.0 1.0] 2 2 [0.0 1.0 0.0] (p \ [0.0 0.0]) -1 white)
   sb (mesh-sheet [0.0 0.0 0.0] [0.0 0.0 1.0] [1.0 0.0 0.0] 2 2 [0.0 1.0 0.0] (p \ [0.0 0.0]) -1 white)
   ; ..lamps over a 4 by 4 floor: brightest under, none past reach, facing away, or kept from
   fl (mesh-pack (mesh-sheet [-2.0 0.0 -2.0] [4.0 0.0 0.0] [0.0 0.0 4.0] 4 4 [0.0 1.0 0.0] (p \ [0.0 0.0]) -1 white))
   mid 12                             ; the vertex at the middle, under the lamp
   lp {'at [[0.0 1.0 0.0]] 'c [1.0 1.0 1.0] 'r 2.5}
   ch (mesh-lamp fl lp)
   away (mesh-lamp fl {'at [[0.0 1.0 0.0]] 'c [1.0 1.0 1.0] 'r 2.5 'n [0.0 1.0 0.0]})
   short (mesh-lamp fl {'at [[0.0 1.0 0.0]] 'c [1.0 1.0 1.0] 'r 1.2})
   kept (mesh-lamp fl {'at [[0.0 1.0 0.0]] 'c [1.0 1.0 1.0] 'r 2.5 'keep [-9.0 -9.0 9.0 0.5]})
   ; ..lights summed onto a base, light by light; a lamp out of reach adds the numbers 0.0
   far (mesh-lamp fl {'at [[9.0 1.0 9.0]] 'c [1.0 1.0 1.0] 'r 2.5})
   both (lamp-lights (fl 'cols) [1.0 1.0 1.0] [[(mesh-lamp-row lp)] [(mesh-lamp-row lp) (mesh-lamp-row {'at [[9.0 1.0 9.0]] 'c [1.0 1.0 1.0] 'r 2.5})]])
   (texs t) (peep t (iota (#t // 4) * 4 + 3) 0)
   ; ..lit by them, per channel; what shines its colour alone
   lm (mesh-lamps fl [0.0 0.0 0.0] [ch] [2.0] 1.0)
   sh (mesh-shine fl 0.5)
   gl (mesh-glow sh)
   ; ..relit in place: one buffer, colours the latest
   b1 (mesh-lamps! fl [0.0 0.0 0.0] [ch] [1.0] 1.0) c1 (peep (b1 0) (mid * 8 + 5) 0.0)
   b2 (mesh-lamps! fl [0.0 0.0 0.0] [ch] [3.0] 1.0)
 (test (map shape pc = [[4 8] [2 4] [1 2]]) (peep (pc 1) [0 0] 0 = 16711680) (peep (pc 1) [0 3] 0 = 255)
       (map shape r2 = [[2 2] [1 1]]) (peep (r2 0) [1 1] 0 = -1) (peep (r2 0) [0 1] 0 = 65280) (peep (r1 0) [0 0] 0 = 5592405)
       (up? sa) (up? sb)
       (amax (ch 0) = peep (ch 0) mid 0.0) (0.9 < peep (ch 0) mid 0.0) (peep (ch 0) 0 1.0 = 0.0)
       (amax (away 0) = 0.0) (peep (short 0) 6 1.0 = 0.0) (0.0 < peep (ch 0) 6 0.0)
       (peep (kept 0) 14 1.0 = 0.0) (0.0 < peep (ch 0) 14 0.0) (peep (kept 0) mid 0.0 = peep (ch 0) mid 0.0)
       (far = [0.0 0.0 0.0]) (aall (both 1 = 1.0 + ch 1 + ch 1))
       (peep (lm 0) (mid * 8 + 5) 0.0 = 2.0 * peep (ch 0) mid 0.0) (peep (lm 0) (mid * 8) 1.0 = 0.0)
       (amin (peep (sh 0) (iota 25 * 8 + 6) 0.0) = 0.5)
       (amax (texs (sh 1)) = -1) (amax (texs (gl 1)) = -2) (gl 0 = sh 0)
       (c1 = peep (lm 0) (mid * 8 + 5) 0.0 / 2.0) (peep (b2 0) (mid * 8 + 5) 0.0 = 3.0 * c1)
       (b2 0 = b1 0) (lm 0 = mesh-lamps fl [0.0 0.0 0.0] [ch] [2.0] 1.0 0)))
; --- batches: each starts with no texture, whatever the batch before it last used
(: W 40 H 24 white [1.0 1.0 1.0]
   v (mesh-view W H [0.0 0.0 0.0] 0.0 0.0 1.4 0.1 100.0)
   grey (mesh-tex 4 (\ x y [0.25 0.25 0.25]))
   far (mesh-bake (mesh-pack (mesh-box [0.0 0.0 9.0] [4.0 4.0 0.1] 0.0 0 white 1.0)) {'sun [0.0 1.0 0.0] 'amb [1.0 1.0 1.0] 'sunk 0.0 'sunc [0.0 0.0 0.0]} mesh-open 1.0)
   near (mesh-shine (mesh-pack (mesh-box [0.0 0.0 5.0] [0.5 0.5 0.1] 0.0 -1 white 1.0)) 1.0)
   f (mesh-frame v [[(far 0) (near 0)] [(far 1) (near 1)]] [grey] [0 0 0 0.0 0.0] 0 0.0 7)
 (test (peep f (12 * W + 20) 0 = 16777215) (peep f (2 * W + 2) 0 != 16777215)))
; a mesh as a .glb and back: the same triangles, its corners, normals and colours within a
; float's reach; a node's place laid on, its x the other way; a text that is no glb is nothing
(: gm (mesh-box [0.5 1.0 2.0] [0.5 0.25 1.0] 0.3 -1 [0.9 0.2 0.1] 1.0)
   g (mesh-glb-of gm "box") gb (mesh-glb g)
   (le v) (string [(v & 255) (v >> 8 & 255) (v >> 16 & 255) (v >> 24 & 255)])
   (u32 s i) (s i | s (i + 1) << 8 | s (i + 2) << 16 | s (i + 3) << 24)
   jl (u32 g 12) j (json-read (snip g 20 (20 + jl)) 1)
   _ (pins (j "nodes" 0) "translation" [1.0 2.0 3.0] "scale" [2.0 2.0 2.0])
   j2 (json-show j) jp (j2 + string (map (_ \ 32) ^((4 - #j2 % 4) % 4))) bin (snip g (20 + jl) #g)
   gt (mesh-glb ("glTF" + le 2 + le (20 + #jp + #bin) + le #jp + "JSON" + jp + bin))
   (gd a b) (foldl max 0.0 (map (k \ abs (a k - b k)) [0 1 2 5 6 7 8 9 10]))
   (moved a b) (abs (b 0 - (2.0 * a 0 - 1.0)) < 1e-5 && abs (b 1 - (2.0 * a 1 + 2.0)) < 1e-5 && abs (b 2 - (2.0 * a 2 + 3.0)) < 1e-5)
 (test (#(gm 0) = #(gb 0)) (gb 1 = gm 1) (foldl max 0.0 (map (i \ gd (gm 0 i) (gb 0 i)) ^#(gm 0)) < 1e-6)
       (all (i \ moved (gm 0 i) (gt 0 i)) ^#(gm 0)) (gt 1 = gm 1)
       (mesh-glb "glTF" = ()) (mesh-glb (snip g 0 100) = ())
       ; ..its corners in two bytes each, and one triangle's six padded to a word
       (j "accessors" 3 "componentType" = 5123) (: m1 [(gm 0) [(gm 1 0)]] g1 (mesh-glb-of m1 "one") (#g1 % 4 = 0 && mesh-glb g1 1 = m1 1))))
;; the sky asked every 4 pixels is fixed to the sky: looking up and turned, each direction
;; seen both ways shows the same, but for where the pixels fall
(: wq (sky-weather 1) nq (1.0 * 1790812800 + 12.0 * 3600.0) lq (sky-light (sky-sun nq 0.0 0.65) wq nq)
   (sky v) (mesh-frame v [[] []] () [0 0 0 0.0 0.0] 8 0.0 (mesh-sky (sky-stars nq 0.0 0.65) lq wq [0.0 0.0 0.0] nq 0.0 4 ()))
   va (mesh-view 160 100 [0.0 0.0 0.0] 0.0 0.7 1.5 0.1 100.0) vb (mesh-view 160 100 [0.0 0.0 0.0] 0.35 0.7 1.5 0.1 100.0)
   fa (sky va) fb (sky vb) ix (iota (160 * 100)) d (mesh-dirs va ix) sp (mesh-spot vb (d 0) (d 1) (d 2))
   both (iota (sp >= 0)) a (peep fa (peep ix both 0) 0) b (peep fb (peep sp both 0) 0)
   gap (+(map (k \ net (abs ((a >> k & 255) - (b >> k & 255)))) [0 8 16]) / (3.0 * #both))
 (test (#both > 8000) (gap < 0.025)))
;; ..and seen only through glass, the sky still drawn behind it: a clear pane all round the
;; eye leaves no pixel bare, each the sky's through it
(: nr (1.0 * 1790812800 + 12.0 * 3600.0) wr (sky-weather 1) lr (sky-light (sky-sun nr 0.0 0.65) wr nr)
   wh [1.0 1.0 1.0] pn (mesh-bake (mesh-pack (mesh-lathe [[6.0 -6.0] [6.0 6.0]] 16 -3 wh 1.0)) {'sun [0.0 1.0 0.0] 'amb [0.2 0.2 0.2] 'sunk 1.0 'sunc wh 'expo 1.0} mesh-open 1.0)
   (gl k) (mesh-frame (mesh-view 40 24 [0.0 0.0 0.0] 0.0 0.0 1.4 0.1 100.0) pn [(mesh-tex 4 (\ x y wh))] [0 0 0 0.0 0.0] 8 0.0 (mesh-sky (sky-stars nr 0.0 0.65) lr wr [0.0 0.0 0.0] nr 0.0 k ()))
   g1 (gl 1) g4 (gl 4)
 (test (0 <= amin g1) (0 <= amin g4) (+(map (k \ net (abs ((g1 >> k & 255) - (g4 >> k & 255)))) [0 8 16]) / (3.0 * #g1) < 8.0)))
;; under a light with 'turn the sky is all round: by deep night each way below the eye's
;; horizon shows as its mirror above, but where a cloud is; a star under it is lit
(: nt (1.0 * 1790812800 + 1.0 * 3600.0) wt (sky-weather 0) ltf (sky-light (sky-sun nt 0.0 0.65) wt nt)
   ltt (pin (sky-light (sky-sun nt 0.0 0.65) wt nt) 'turn [[1.0 0.0 0.0] [0.0 1.0 0.0] [0.0 0.0 1.0]])
   n 2000 i (iota n) y (0.1 + 0.8 * (i + 0.5) / n) r (sqrt (1.0 - y * y)) dx (r * cos (i * 2.39996)) dz (r * sin (i * 2.39996))
   (col lt dy) (sky-colour-of lt wt dx dy dz 0.0 0.0 nt)
   (d2 p q) ((p - q) * (p - q)) (same a b) (net (d2 (a 0) (b 0) + d2 (a 1) (b 1) + d2 (a 2) (b 2) < 1e-12) / (1.0 * n))
   ss {'x @(0.6) 'y @(-0.6) 'z @(0.53) 'b @(1.0) 'ph @(0.0) 'tint [1.0 1.0 1.0]}
   (lit lt) (sky-stars! ss [@(0.0) @(0.0) @(0.0)] lt wt 0.0 0.0 nt 0.0 @(0) @ c (c 0 0))
 (test (0.9 < same (col ltt y) (col ltt (0.0 - y))) (same (col ltf y) (col ltf (0.0 - y)) < 0.1)
       (0.5 < lit ltt)))
(test_fin ())
(puts "mesh: ok\n")
