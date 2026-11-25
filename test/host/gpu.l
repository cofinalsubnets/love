; test/host/gpu.l -- src/apps/lore/gpu.l: a frame drawn by glhelp on the system's gpu, as facets
; draws it on the cpu, each build of the helper in turn; and gpu-facets in facets's stead, culled,
; foggy, bare where nothing drew, over a ground or a smaller frame laid first, with glows and
; glass on what drew and on what is bare, and a pane's classes behind and before a lens. a box
; with no gpu or no compiler answers a nom saying so, the frame left to facets
; host-side: a crew module. run: cat test/00-init.l test/host/gpu.l | out/love
(borrow '(gpu posix lore sky mesh))

(: W 96 H 64
   ; a checker, one texel a hole, on a square leaning back; a vertex-coloured triangle before it
   ckl (map (i \ i = 9 ? -1 (((i % 8) + (i // 8)) % 2 ? 16752680 2045128)) ^64)
   verts (gem-tray [56] [-0.8 -0.8 0.5  0.0 0.0  1.0 1.0 1.0
                          0.8 -0.8 0.5  32.0 0.0  1.0 1.0 1.0
                          0.8  0.8 0.9  32.0 32.0  0.5 1.0 1.0
                         -0.8  0.8 0.9  0.0 32.0  1.0 1.0 1.0
                         -0.5 -0.5 0.2  0.0 0.0  0.9 0.1 0.1
                          0.5 -0.5 0.2  0.0 0.0  0.1 0.9 0.1
                          0.0  0.6 0.2  0.0 0.0  0.1 0.1 0.9])
   tris (iota 12 * 0 + gem-tray [12] [0 1 2 0  0 2 3 0  4 5 6 -1])
   mat (gem-tray [16] [1.0 0.0 0.0 0.0  0.0 1.0 0.0 0.0  0.0 0.0 1.0 0.0  0.0 0.0 0.0 1.0])
   bg 1056816
   cpu (facets W H bg mat verts tris [(int (gem-tray [8 8] ckl))] (gem-tray [8] [0.0 0.0 0.0 0.0 0.0 64.0 0.0 0.0]))
   (ch v k) (v >> k & 255)
   (off a b) (max (max (abs1 (ch a 16 - ch b 16)) (abs1 (ch a 8 - ch b 8))) (abs1 (ch a 0 - ch b 0)))
   (worst a b) (amax (off a b))
   (abs1 x) (max x (0 - x))
   ; ..the frame through one build: () where it matched, its words where it did not, or the nom
   (drawn how) (: _ (setenv "LOVE_GPU_CC" how) g (gpu-open ())
     (? (two? g) g
        (: up [(gpu-tex g 0 8 8 (gem-tray [64] ckl)) (gpu-buf g 1 verts tris 8)]
           c (gpu-frame g W H mat [1] [bg 0.0 0.0 0.0 0.0 0.0 0.0 0])
           fr c
           d (string? fr ? fr (worst cpu fr))
           dr (gpu-drop g 1)
           e (gpu-frame g W H mat [1] [bg 0.0 0.0 0.0 0.0 0.0 0.0 0] @ c (string? c ? c (amax ((c & 16777215) != bg))))
           s (gpu-state g)
           ; ..the square's twin turned away, and the triangle wound the other way: culled
           ta (iota 8 * 0 + gem-tray [8] [0 1 2 0  0 2 3 0]) tb (iota 8 * 0 + gem-tray [8] [0 2 1 0  4 6 5 -1])
           (o fl) (gem-tray [8] [40.0 60.0 80.0 0.3 0.9 (1.0 * fl) 1.5 0.0])
           ; ..a glass of the checker, then a glow, across the square and past it onto the bare; and
           ; the other way about
           gv (gem-tray [32] [-0.3 -0.9 0.1  0.0 0.0  0.2 0.1 0.0
                              0.95 -0.9 0.1  16.0 0.0  0.2 0.1 0.0
                              0.95  0.9 0.1  16.0 16.0  0.0 0.1 0.2
                             -0.3  0.9 0.1  0.0 16.0  0.0 0.1 0.2])
           tg (iota 8 * 0 + gem-tray [8] [0 1 2 -3  0 2 3 -2]) tr (iota 8 * 0 + gem-tray [8] [0 2 3 -2  0 1 2 -3])
           ; ..each word's kind, drawn 0, bare 1, a glow kept 2, a glass kept 3, and what it holds
           (kind v) ((v = -1) + 2 * (v < -1) * (v > -33554432) + 3 * (v <= -33554432))
           (held v) ((v >= 0) * v + (v < -1) * (v > -33554432) * (-1 - v) + (v <= -33554432) * (-33554432 - v))
           (apart c q) (: a (held c) b (held q)
                         (net ((kind c != kind q) + (off a b > 1) + (abs1 ((a >> 24 & 255) - (b >> 24 & 255)) > 1) > 0)))
           (both B fl) (: V [verts verts gv] T [ta tb tg] X [(int (gem-tray [8 8] ckl))]
                          [(apart (facets W H B mat V T X (o fl)) (gpu-facets s W H B mat V T X (o fl) () () ()))
                           (apart (facets W H B mat V [ta tb tr] X (o fl)) (gpu-facets s W H B mat V [ta tb tr] X (o fl) () () ()))])
           ; ..and over a frame half the size, laid first: the triangle alone, nearer, so it hides
           ; the square where they cross and the square shows past it elsewhere
           (half fl) (facets (W // 2) (H // 2) -1 mat [verts] [(iota 4 * 0 + gem-tray [4] [4 5 6 -1])] [] (o fl))
           un [-1 (half 64) (half 16)] sky (iota (W * H) % 7 * 1193046)
           ; ..and with no fog, which at that depth leaves a glass clear: two panes crossed in one
           ; run, on the bare and over a ground
           gw (gem-tray [64] (map (i \ gv (i % 32) @ v (32 <= i && i % 8 = 0 ? -v (32 <= i && i % 8 = 6 ? 0.3 v))) ^64))
           gi (iota 16 * 0 + gem-tray [16] [0 1 2 -3  0 2 3 -3  4 5 6 -3  4 6 7 -3])
           (clear B) (: o (gem-tray [8] [0.0 0.0 0.0 0.0 0.0 64.0 0.0 0.0]) V [verts gw] T [ta gi] X [(int (gem-tray [8 8] ckl))]
                        c (facets W H B mat V T X o) g (gpu-facets s W H B mat V T X o () () ()) (? (tray? g) (apart c g) 9999))
           ; ..and a glow turned to the eye, its right and up slanted, half sunk in the square it fades by;
           ; not where it lay flat
           gq (gem-tray [32] (map (i \ [0.1 0.0 0.55 (elem (i // 8) [1 2] ? 0.5 -0.5) (i // 8 < 2 ? -0.4 0.4) 0.3 0.2 0.1] (i % 8)) ^32))
           eo (gem-tray [18] [0.0 0.0 0.0 0.0 0.0 64.0 0.0 0.0  0.9 0.2 0.0  -0.2 0.9 0.0  0.1 10.0 0.01 0.05]) e8 (iota 8 * 0.0 + gem-tray [8] (map (i \ eo i) ^8))
           (eyed o f) (f W H -1 mat [verts gq] [ta (iota 8 * 0 + gem-tray [8] [0 1 2 -2  0 2 3 -2])] [(int (gem-tray [8 8] ckl))] o)
           ge (: c (eyed eo facets) [(apart c (gpu-facets s W H -1 mat [verts gq] [ta (iota 8 * 0 + gem-tray [8] [0 1 2 -2  0 2 3 -2])] [(int (gem-tray [8 8] ckl))] eo () () ()))
                                     (apart c (eyed e8 facets))])
           gc [(clear -1) (clear bg) (clear sky)]
           fs [(both -1 64) (both -1 72) (both bg 72) (both un 72) (both sky 72) (both [sky (half 64) (half 16)] 72)]
           ; ..the square's halves one behind a lens and one before it, the triangle before, and a
           ; lens over the square's corner, seen or not
           tc (iota 12 * 0 + gem-tray [12] [0 1 2 16777216  0 2 3 33554432  4 5 6 33554431])
           tl (iota 4 * 0 + gem-tray [4] [0 1 2 -16777219])
           (lens fl ks) (: X [(int (gem-tray [8 8] ckl))]
                          (apart (facets W H -1 mat [verts gv] [tc tl] X (o fl)) (gpu-facets s W H -1 mat [verts gv] [tc tl] X (o fl) ks () ())))
           ; ..the last its batches named by their maker, twice: the second asks no sums
           gl [(lens 64 ()) (lens 192 ()) (lens 200 ()) (lens 192 [['sq] ['ln]]) (lens 192 [['sq] ['ln]])]
           ; ..piped: the first frame itself, then it again, then each the one before, its own c
           ; with it; a frame declined stops it, and the next starts again
           X [(int (gem-tray [8 8] ckl))] (cf fl) (facets W H -1 mat [verts gv] [tc tl] X (o fl))
           (pp fl c) (gpu-facets s W H -1 mat [verts gv] [tc tl] X (o fl) () () c)
           pi (: _ (pin s 'pipe 1) a (pp 64 'a) b (pp 192 'b) d (pp 200 'c) e (pp 192 'd)
                 n (gpu-facets s W H -1 mat [verts] [ta] [] (o 65) () () 'n) z (pp 64 'z) _ (pin s 'pipe 0)
                 [[(a 1) (b 1) (d 1) (e 1) n (z 1)] (apart (a 0) (cf 64)) (apart (b 0) (cf 64)) (apart (d 0) (cf 192))
                  (apart (e 0) (cf 200)) (apart (z 0) (cf 64))])
           ; ..and kept, on a ground with nothing bare: each a picture or 'kept, a kept one never shown again
           ; while the next draws over it. the first answers the frame left above, and a step in size drops c
           (kq w h c) (gpu-facets s w h 4210752 mat [verts gv] [tc tl] X (o 64) () () c)
           pk (: _ (pins s 'pipe 1 'keep 1) a (kq W H 'a) b (kq W H 'b) c (kq W H 'c) d (kq (W // 2) (H // 2) 'd)
                 e (kq (W // 2) (H // 2) 'e) _ (pins s 'pipe 0 'keep 0) r [a b c d e]
                 [(map (q \ q 1) r) (all (q \ two? q && (tray? (q 0) || q 0 = 'kept)) r) (any (q \ q 0 = 'kept) r)])
           ; ..the sun: half its view near enough to shade the square but not the triangle, the
           ; view wider than the screen, so the square's edges fall past it, lit; and the sun down
           sv (gem-tray [16] [1.5 0.0 0.0 0.0  0.0 1.5 0.0 0.0  0.0 0.0 1.0 0.0  0.0 0.0 0.0 1.0])
           sd (gem-tray [8 8] (map (i \ i % 8 < 4 ? 2.0 (i // 8 < 5 ? 0.3 0.7)) ^64))
           sv11 (gem-tray [77] (foldl cat [] (map (k \ (: q (map (j \ verts (8 * k + j)) ^8)
                                                   (cat (map q ^5) (cat (map (j \ 0.3 * q (5 + j)) ^3) (map (j \ 0.7 * q (5 + j)) ^3))))) ^7)))
           (so fl) (gem-tray [8] [40.0 60.0 80.0 10.0 20.0 (1.0 * fl) 1.5 0.01])
           (lit fl sun) (apart (facets W H -1 mat [sv11] [tris] X [(so fl) (sun 0) (sun 1)]) (gpu-facets s W H -1 mat [sv11] [tris] X [(so fl) (sun 0) (sun 1)] () () ()))
           su [(lit 64 [sv sd]) (lit 192 [sv sd]) (lit 64 [() ()]) (lit 64 [sv sd])]
           ; ..a sky under what is bare, as a sky after the scene: onto the glow kept there, through
           ; the glass, and where the frame was bare alone, 2^32 more; a cloud's edge down its middle
           skv (gem-tray [44] [-1.0 -1.0 0.95  -2.0 0.0  0.2 0.4 0.9  0.6 0.5 0.0   1.0 -1.0 0.95  2.0 0.0  0.3 0.5 0.8  0.6 0.5 0.0
                                1.0  1.0 0.95  2.0 0.0  0.6 0.7 0.9  0.3 0.2 0.0  -1.0  1.0 0.95  -2.0 0.0  0.1 0.2 0.5  0.3 0.2 0.0])
           skt (iota 8 * 0 + gem-tray [8] [0 1 2 -1  0 2 3 -1])
           (under T) (: sc (facets W H -1 mat [verts gv] T X (o 64))
                      gf (gpu-facets s W H -1 mat [verts gv] T X (o 64) () [skv skt 1.5] ())
                      [(apart (facets W H sc mat [skv] [skt] [] [(gem-tray [7] [0.0 0.0 0.0 0.0 0.0 352.0 1.5])]) gf)
                       (net (gf >> 32 = 1) != net (sc = -1)) (net (sc = -1))])
           sk [(under [ta tg]) (under [ta tr])]
           ; ..and the same sky laid from an eye, its places less the eye's, drawn where it was
           ex [0.3 -0.2 0.1] skr (skv - foldl (\ a q (pin a (q 0) (q 1))) (skv * 0.0) (catmap (v \ map (k \ [(11 * v + k) (ex k)]) ^3) ^4))
           se (apart (gpu-facets s W H -1 mat [verts gv] [ta tg] X (o 64) () [skv skt 1.5] ())
                     (gpu-facets s W H -1 mat [verts gv] [ta tg] X (o 64) () [skr skt 1.5 () ex] ()))
           ; ..a batch lit by its lamps' slots, lamp 2 as strong as ks says, as the cpu draws its
           ; colours lit so, unfogged; then at another strength, the slots laid once
           lc (iota 168 % 24 @ m ((m = 0) * 0.3 + (m = 1) * 0.2 + (m = 2) * 0.1))
           vh (foldl (\ a j (: ix (iota 7 * 8 + 5 + j) (pin a ix (0.5 * verts ix)))) verts ^3)
           (lk k) (vh + foldl (\ a j (pin a (iota 7 * 8 + 5 + j) (k * [0.3 0.2 0.1] j))) (verts * 0.0) ^3)
           nf (gem-tray [8] [40.0 60.0 80.0 0.0 0.0 64.0 1.5 0.0])
           (lamped k) (apart (facets W H -1 mat [(lk k)] [tris] X nf)
                             (gpu-facets s W H -1 mat [vh] [tris] X nf () () [{'lamps [[lc [2 0 0 0 0 0 0 0]]] 'dks [0.0 0.0 k]}]))
           la [(lamped 0.7) (lamped 0.2)]
           ; ..the batch kept as a scene, drawn where its group's mark lies, its colours its light's
           ; strength times its weight; under another strength; and not at all, its mark down
           (sn k m) {'key 1 'make (_ \ [[vh tris ['sn 1] () [0.0 0.0 0.5 2.0] 0 2.0 0 3]]) 'at [0 0] 'vis [1.0 1.0 1.0 m] 'kb [k]}
           (dim k) (foldl (\ a j (: ix (iota 7 * 8 + 5 + j) (pin a ix (k * vh ix)))) vh ^3)
           (kept k m) (apart (facets W H -1 mat (m ? [(dim (2.0 * k))] []) (m ? [tris] []) X nf)
                             (gpu-facets s W H -1 mat [] [] X nf () () [{'scene (sn k m)}]))
           ke [(kept 0.25 1.0) (kept 0.4 1.0) (kept 0.25 0.0)]
           ; ..a batch drawn moved by its offset as the cpu draws it moved so, at two offsets
           (shove x y) (foldl (\ a j (: ix (iota 7 * 8 + j) (pin a ix (verts ix + [x y 0.0] j)))) verts ^2)
           (budge x y) (apart (facets W H -1 mat [(shove x y)] [tris] X nf)
                            (gpu-facets s W H -1 mat [verts] [tris] X nf ['mv] () [{'offs [[x y 0.0]]}]))
           ; ..and its texels by its drift
           (slid u w) (foldl (\ a j (: ix (iota 7 * 8 + 3 + j) (pin a ix (verts ix + [u w] j)))) verts ^2)
           (flows u w) (apart (facets W H -1 mat [(slid u w)] [tris] X nf)
                              (gpu-facets s W H -1 mat [verts] [tris] X nf ['mv] () [{'offs [[0.0 0.0 0.0 u w]]}]))
           mv [(budge 0.1 0.0) (budge -0.2 0.15) (flows 3.0 0.0) (flows 1.5 6.25)]
           ; ..the sky asked a pixel at a time, as the cpu asks it at each: partly cloudy from an
           ; eye off the middle, overcast under smog low down, and mostly cloudy dyed
           (q8 x) (int (min 1.0 (max 0.0 x) * 255.0 + 0.5))
           (px wx th ph) (: sim (1.0 * 1790812800 + 12.0 * 3600.0) lt (sky-light (sky-sun sim 0.0 0.65) wx sim)
                           e [30.0 2.0 -50.0] v (mesh-view W H e th ph 1.4 0.1 100.0)
                           m (mesh-sky (sky-stars sim 0.0 0.65) lt wx e sim 0.0 4 {} 2 0 v)
                           gf (gpu-facets s W H -1 (v 'cam) [] [] [] nf () [() () (m 2) () e (m 5)] ())
                           d (mesh-dirs v (iota (W * H)))
                           c (sky-tone lt (sky-colour-at lt wx (mesh-step v 1) (d 0) (d 1) (d 2) (e 0) (e 2) sim))
                           [(net (gf >> 32 != 1)) (off (gf & 16777215) ((q8 (c 0) << 16) | (q8 (c 1) << 8) | q8 (c 2)) @ f [(amax f) (net (f > 0))])])
           ps [(px (sky-weather 1) 2.0 0.3) (px (pins (sky-weather 3) 'smog 0.6 'smog-hue [0.4 0.9 0.5]) 0.0 0.05) (px (pins (sky-weather 2) 'dye [0.9 0.3 0.6] 'smog 0.3 'sky [[0.9 0.6 0.4] [0.3 0.5 0.9]]) 1.0 0.4)]
           ; ..and kept, unread, under it, where every bare pixel is the sky's, mesh-frame's c with
           ; its spots; with no sky, read
           kx (: sim (1.0 * 1790812800 + 12.0 * 3600.0) wx (sky-weather 1) lt (sky-light (sky-sun sim 0.0 0.65) wx sim)
                 e [0.0 0.0 0.0] v (mesh-view W H e 2.0 0.3 1.4 0.1 100.0)
                 m (mesh-sky (sky-stars sim 0.0 0.65) lt wx e sim 0.0 4 {} 2 0 v) _ (pin s 'keep 1)
                 c [{} -1 [0 0 [0 0 0]] 1] (sh sk) (gpu-facets s W H -1 mat [verts] [ta] [] nf () sk c)
                 a (sh [() () (m 2) () e (m 5)]) b (sh ()) _ (pin s 'keep 0)
                 [a (tray? b)])
           ; ..and the clouds' shade on a batch's sun: no cloud and the light it was made with over, none
           ; taken but that light's own; a full one's shade, as the colours are with it taken; and where the
           ; numbers say no shade, or a batch has no sun, none
           sh (: vs (lk 0.35) sim (1.0 * 1790812800 + 12.0 * 3600.0) wx (sky-weather 1) lt (sky-light (sky-sun sim 0.0 0.65) wx sim)
                 e [0.0 0.0 0.0] v (mesh-view W H e 2.0 0.3 1.4 0.1 100.0)
                 m (mesh-sky (sky-stars sim 0.0 0.65) lt wx e sim 0.0 4 {} 2 0 v) q (m 5) sc (iota 21 % 3 @ j (0.1 * (j = 0) + 0.07 * (j = 1) + 0.05 * (j = 2)))
                 (ask ed base) [() () (m 2) () e [(map (i \ i = 2 ? ed (i = 50 ? base (q 0 i))) ^51) (q 1) (q 2)]]
                 (add k) (foldl (\ a j (: ix (iota 7 * 8 + 5 + j) (pin a ix (vs ix + k * [0.1 0.07 0.05] j)))) vs ^3)
                 (fr V sun sk) (gpu-facets s W H -1 mat [V] [tris] X nf () sk [{'lamps [(sun ? [() () sc] ())]}])
                 (dif x y) (: d ((x & 255) - (y & 255)) (max (amax d) -(amin d)))
                 (t ed base k) (: sk (ask ed base) (dif (fr vs 1 sk) (fr (add k) 0 sk)))
                 [(t 9.0 0.8 0.25) (t -9.0 0.8 -0.9375) (t 9.0 0.0 0.0) (t -9.0 0.8 0.0) (: sk (ask -9.0 0.8) (dif (fr vs 0 sk) (fr vs 0 sk)))])
           ; ..a batch moved every frame, a buf of its own each: those not drawn for a while dropped
           sw (: _ (each ^300 (i \ gpu-facets s W H -1 mat [(shove (0.001 * i) 0.0)] [tris] X nf () () ())) #(keys (s 'bufs)))
           ; ..a batch named [m x], laid again under a new x: its verts alone, in the buf it had
           (rl x V) (apart (facets W H -1 mat [V gv] [tc tl] X (o 64)) (gpu-facets s W H -1 mat [V gv] [tc tl] X (o 64) [['sq x] ['ln 0]] () ()))
           rv (: a (rl 1 verts) n (s 'n) b (rl 2 (verts * 0.5)) c (rl 2 (verts * 0.5)) [a b c (s 'n - n)])
           ; ..a smaller frame laid first on a wide one, drawn on its right alone: every texel found
           ; past 32767 / its width, where a 16-bit int's index would wrap
           un (: cs ((iota 80 >= 60) * 65281 - 1) ds (gem-tray [1 80] (map (x \ x >= 60 ? 0.0 2.0) ^80))
                 u (gpu-under g cs ds) f (gpu-frame g 640 8 mat [] [-1 0.0 0.0 0.0 0.0 0.0 0.0 0])
                 (u = () && tray? f ? [(net (f < 0)) (net ((f >= 0) * ((f & 16777215) = 65280)))] f))
           (gpu-close g, [up d dr e fs gl pi su sk rv pk un se la ke mv ps kx sw sh gc ge]))))
   ; ..no channel more than a step off, and a dropped buf draws nothing; through gpu-facets a
   ; few pixels on an edge apart at most; the sky a pixel at a time all bare, a step off at most,
   ; and kept under it; a moving batch's old bufs dropped
   (fine? r) (near? 8 r)
   (near? gk r) (? (<r = 'no-gpu || <r = 'no-helper) (string? (r 1) || nom? (r 1))
                (r 0 = [() ()] && charm? (r 1) && r 1 <= 1 && r 2 = () && r 3 = 0
                 && all (f \ f 0 + f 1 <= 8) (r 4) && all (f \ f <= 4) (r 5)
                 && r 6 0 = '(a a b c () z) && all (f \ f <= 4) >(r 6) && all (f \ f <= 4) (r 7)
                 && all (f \ f 0 <= 4 && f 1 = 0 && 0 < f 2) (r 8)
                 && r 9 0 <= 4 && r 9 1 <= 4 && r 9 2 <= 4 && r 9 3 = 0
                 && r 10 = ['(z a b d e) 1 1] && r 11 = [3840 1280] && r 12 <= 4 && all (f \ f <= 4) (r 13) && all (f \ f <= 4) (r 14) && all (f \ f <= 4) (r 15)
                 && all (f \ f 0 = 0 && f 1 0 <= 1 && f 1 1 <= 16) (r 16) && r 17 = ['kept 1] && r 18 < 200
                 && r 19 0 <= 1 && r 19 1 <= 1 && r 19 2 <= 1 && 8 < r 19 3 && r 19 4 = 0 && all (f \ f <= gk) (r 20) && r 21 0 <= 1 && 8 < r 21 1))
   moon (drawn "moon") cc (drawn "cc")
   ; ..and where the driver blends with one colour alone, glass in two, rounded at each
   _ (setenv "LOVE_GPU_DUAL" "0") one (drawn "moon")
   ; ..or in one draw by fetching the colour there, as mesa's software driver can
   _ (setenv "LIBGL_ALWAYS_SOFTWARE" "1") ftc (drawn "moon") _ (setenv "LIBGL_ALWAYS_SOFTWARE" "") _ (setenv "LOVE_GPU_DUAL" "")
   ; ..a helper that dies lets go, its words kept, and the frame is the cpu's
   die (: g (gpu-open ()) (? (two? g) 'none
     (: s (gpu-state g) f (_ \ gpu-facets s W H -1 mat [verts] [tris] [(int (gem-tray [8 8] ckl))] (gem-tray [8] [40.0 60.0 80.0 0.3 0.9 64.0 1.5 0.0]) () () ())
        a (f ()) _ (hark ["kill" "-9" (show (g 'pid))]) _ (rest 100) b (f ()) [(tray? a) b (s 'g) (string? (s 'fail))])))
   ; ..what is posted answers at the frame: a bad one's words, then none; and more than the file
   ; holds at once, each as laid
   po (: g (gpu-open ()) (? (two? g) 'none
     (: f (_ \ gpu-frame g W H mat [1] [bg 0.0 0.0 0.0 0.0 0.0 0.0 0]) _ (gpu-buf g 1 verts tris 8) _ (gpu-tex g 0 8 8 (gem-tray [64] ckl)) a (f ())
        _ (gpu-buf g 2 verts (tris * 0 + 99) 8) b (f ()) c (f ())
        _ (each ^1200 (i \ (gpu-place g [[1 [(0.001 * i) 0.0 0.0]]]))) _ (gpu-place g [[1 [0.0 0.0 0.0]]])
        _ (each ^9 (i \ (gpu-tex g (10 + i) 512 512 (iota (512 * 512) * 0 + i)))) d (f ()) _ (gpu-close g)
        [(tray? a) (string? b) (tray? c && amax (a != c) = 0) (tray? d && amax (a != d) = 0)])))
   (test (fine? moon) (fine? cc) (near? 60 one) (near? 60 ftc) (elem die ['none [1 () () 1]]) (elem po ['none [1 1 1 1]])))
; a frame's numbers laid as 4-byte floats, whatever the machine's word
(: fw-n (cwd 0 + "/out/.gpu-frame-" + show (getpid 0)) _ (close (open fw-n "w")) fw-l (open (fw-n + ".l") "w")
   _ (gpu-send {'w (openfd fw-n 1) 'room 0 'to fw-l} 2 2 (1.5 * iota 16) [7 -9] [-1 0.5 0.0 0.0 0.0 0.0 0.0 0]) _ (close fw-l)
   (all n) (: q (open n "r") t (slurp q) (close q, unlink n, t))
   fw-b (all fw-n) fw-s (all (fw-n + ".l")) (wd i) (map (k \ fw-b (4 * i + k)) ^4))
; a face that is refused: no gpu, from the baked image alone
(: gf ("/tmp/gpu-refused-" + show (getpid 0) + ".l") _ (uwrite gf "(puts (show ((cite 'mesh 'mesh-gpu) {})))") _ (setenv "LOVE_GPU_FACE" "/tmp/gpu-no-such-face")
   r (hark ["out/love" gf]) _ (setenv "LOVE_GPU_FACE" ()) _ (unlink gf)
 (test (<r = 0) (>r = "off")))
(test (fw-s = "frame 2 2 0 26 0\n") (104 <= #fw-b) (wd 1 = [0 0 0 63]) (wd 23 = [0 0 180 65]) (wd 24 = [0 0 224 64]) (wd 25 = [0 0 16 193]))
(test_fin ())
(puts "gpu: ok\n")
