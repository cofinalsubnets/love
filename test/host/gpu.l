; test/host/gpu.l -- src/apps/lore/gpu.l: a frame drawn by glhelp on the system's gpu, as facets
; draws it on the cpu, each build of the helper in turn; and gpu-facets in facets's stead, culled,
; foggy, bare where nothing drew, over a ground or a smaller frame laid first, with glows and
; glass on what drew and on what is bare, and a pane's classes behind and before a lens. a box
; with no gpu or no compiler answers a nom saying so, the frame left to facets
; host-side: a crew module. run: cat test/00-init.l test/host/gpu.l | out/love
(borrow '(gpu posix))

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
        (: up [(gpu-tex g 0 8 8 (gem-tray [64] ckl)) (gpu-buf g 1 verts tris)]
           c (gpu-frame g W H mat [1] [bg 0.0 0.0 0.0 0.0 0.0 0.0 0])
           fr (string? c ? c ((cite 'guts 'peepv) c 0 8 8 (W * H)))
           d (string? fr ? fr (worst cpu fr))
           dr (gpu-drop g 1)
           e (gpu-frame g W H mat [1] [bg 0.0 0.0 0.0 0.0 0.0 0.0 0] @ c (string? c ? c (amax (((cite 'guts 'peepv) c 0 8 8 (W * H) & 16777215) != bg))))
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
                          [(apart (facets W H B mat V T X (o fl)) (gpu-facets s W H B mat V T X (o fl) ()))
                           (apart (facets W H B mat V [ta tb tr] X (o fl)) (gpu-facets s W H B mat V [ta tb tr] X (o fl) ()))])
           ; ..and over a frame half the size, laid first: the triangle alone, nearer, so it hides
           ; the square where they cross and the square shows past it elsewhere
           (half fl) (facets (W // 2) (H // 2) -1 mat [verts] [(iota 4 * 0 + gem-tray [4] [4 5 6 -1])] [] (o fl))
           un [-1 (half 64) (half 16)] sky (iota (W * H) % 7 * 1193046)
           fs [(both -1 64) (both -1 72) (both bg 72) (both un 72) (both sky 72) (both [sky (half 64) (half 16)] 72)]
           ; ..the square's halves one behind a lens and one before it, the triangle before, and a
           ; lens over the square's corner, seen or not
           tc (iota 12 * 0 + gem-tray [12] [0 1 2 16777216  0 2 3 33554432  4 5 6 33554431])
           tl (iota 4 * 0 + gem-tray [4] [0 1 2 -16777219])
           (lens fl ks) (: X [(int (gem-tray [8 8] ckl))]
                          (apart (facets W H -1 mat [verts gv] [tc tl] X (o fl)) (gpu-facets s W H -1 mat [verts gv] [tc tl] X (o fl) ks)))
           ; ..the last its batches named by their maker, twice: the second asks no sums
           gl [(lens 64 ()) (lens 192 ()) (lens 200 ()) (lens 192 [['sq] ['ln]]) (lens 192 [['sq] ['ln]])]
           (gpu-close g, [up d dr e fs gl]))))
   ; ..no channel more than a step off, and a dropped buf draws nothing; through gpu-facets a
   ; few pixels on an edge apart at most
   (fine? r) (? (<r = 'no-gpu || <r = 'no-helper) (string? (r 1) || nom? (r 1))
                (r 0 = [() ()] && charm? (r 1) && r 1 <= 1 && r 2 = () && r 3 = 0
                 && all (f \ f 0 + f 1 <= 8) (r 4) && all (f \ f <= 4) (r 5)))
   moon (drawn "moon") cc (drawn "cc")
   (test (fine? moon) (fine? cc)))
(test_fin ())
(puts "gpu: ok\n")
