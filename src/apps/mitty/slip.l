; src/apps/mitty/slip.l -- an app's own panes: a wharf plan on a screen or a window, which
; pane has the keys, and what every app with panes does to them. a cell is 8 by 16 pixels.
;   (slip-new plan id)      the panes of plan, id with the keys
;   (slip-lay s W H)        laid on W by H pixels
;   (slip-key s k)          ctrl-w's next key: w the next pane, h j k l the pane that way, m
;                           mirrored (over and under to side by side, and back), x the halves
;                           traded, + - more or less for the pane with the keys, = even;
;                           1 where k is one. a change that would leave a pane under
;                           'mc by 'mr cells is let be
;   (slip-press s x y)      a press at a pixel: 'bar, taken hold of; else the pane, which has
;                           the keys; () on neither
;   (slip-drag s x y)       the bar held moved there, 1; 0 with none held
;   (slip-drop s)           ..and let go, 1 where one was
;   (slip-plan s p)         the plan p instead, the keys left where they are if p has that pane
;   (slip-bars s)           its bars, as wharf-bars has them
;   (slip-box s id)         a pane's [x y w h] in pixels, (slip-cells s id) its [x y w h] in cells
;   (slip-over s x y)       the pane under a pixel, or ()
;   (slip-rim P W b ink)    a pixel's line round the box b on the paper P, W across
;   (slip-clear P W b)      ..and the box black
;   (slip-face s id scr fr dirty P W)   a terminal's frame fr scribed onto scr and laid in pane
;                           id, where there is any or dirty; 1 where it was
;   (slip-pic f w h k P W b)  a picture's pens f, w by h, each k by k, laid in the box b
(module '(slip slip-new slip-lay slip-key slip-press slip-drag slip-drop slip-box slip-cells slip-over slip-rim slip-clear slip-face slip-pic slip-screen slip-bars slip-plan)
(borrow 'wharf)
(borrow '(quay lore))
(:
 (slip-new p id) {'plan p 'focus id 'W 0 'H 0 'rows 0 'cols 0 'lay () 'held () 'mc 16 'mr 3}
 (relay s) (pin s 'lay (wharf-lay (s 'plan) (s 'rows) (s 'cols)))
 (slip-lay s W H) (relay (pins s 'W W 'H H 'rows (H // 16) 'cols (W // 8)))
 (slip-plan s p) (: ps (wharf-panes p) _ (pin s 'plan p) _ (elem (s 'focus) ps ? 0 (pin s 'focus <ps)) (relay s))
 (slip-bars s) (wharf-bars (s 'plan) (s 'rows) (s 'cols))
 ; ..the plan p, unless it makes a pane too small that was not
 (small s) (filter (b \ wharf-cols b < s 'mc || wharf-rows b < s 'mr) (s 'lay))
 (try s p) (: was (s 'plan) n (#(small s)) _ (relay (pin s 'plan p)) (n < #(small s) ? (relay (pin s 'plan was), 0) 1))
 (slip-key s k) (wharf-wm (s 'plan) (s 'lay) (s 'focus) k @ () 0 q (: _ (pin s 'focus (q 1)) _ (try s (q 0)) 1))
 (slip-cells s id) (filter (b \ wharf-id b = id) (s 'lay) @ () [0 0 0 0] (b . _) [(wharf-col b) (wharf-row b) (wharf-cols b) (wharf-rows b)])
 (slip-box s id) (slip-cells s id @ b [(8 * b 0) (16 * b 1) (8 * b 2) (16 * b 3)])
 (slip-over s x y) (wharf-at (s 'lay) (y // 16) (x // 8))
 ; ..the bar's [row col dir] under a cell
 (bar s r c) (filter (v \ (<v = 'across ? (v 1 = r && v 2 <= c && c < v 2 + v 3) (v 2 = c && v 1 <= r && r < v 1 + v 3)))
                     (slip-bars s) @ () () (v . _) [r c <v])
 (slip-press s x y) (: id (slip-over s x y) b (id = () ? (bar s (y // 16) (x // 8)) ())
   (? (two? b) (pin s 'held b, 'bar) (id = ()) () (pin s 'focus id, id)))
 (slip-drag s x y) (s 'held @ [r c d] (: to (max 0 (d = 'across ? (y // 16) (x // 8))) at (d = 'across ? r c)
                        (? (to = at) 1
                           (try s (wharf-drag (s 'plan) (s 'rows) (s 'cols) r c to))
                             (: n (foldl (\ a v (: q (d = 'across ? (v 1) (v 2)) (<v = d && (a = () || abs (q - to) < abs (a - to)) ? q a))) () (slip-bars s))
                                (pin s 'held (d = 'across ? [n c d] [r n d]), 1))
                           1))
                     _ 0)
 (slip-drop s) (: h (s 'held) _ (pin s 'held ()) (two? h ? 1 0))
 (slip-screen s id) (slip-cells s id @ b (screen (cask (screen () (max 1 (b 3)) (max 1 (b 2)))) (max 1 (b 3)) (max 1 (b 2))))
 (slip-rim P W b ink) (: x (b 0) y (b 1) w (b 2) h (b 3) T (cask (4 * max 1 w)) _ (frame-paint (iota w * 0 + ink) w 1 T w)
   (row j) (pour P (4 * ((y + j) * W + x)) T 0 (4 * w))
   (side j) (: o (4 * ((y + j) * W + x)) (pour P o T 0 4, pour P (o + 4 * (w - 1)) T 0 4))
   (? (w < 2 || h < 2) 0 (: _ (row 0) _ (row (h - 1)) (each (drop 1 ^(h - 1)) side))))
 (slip-clear P W b) (: n (4 * b 2) Z (cask (max 4 n)) (each ^(b 3) (j \ pour P (4 * ((b 1 + j) * W + b 0)) Z 0 n)))
 (slip-face s id scr fr dirty P W) (: b (slip-box s id) c (slip-cells s id) cols (c 2) rows (c 3) tw (b 2)
   (? (0 = #fr && !dirty || cols < 1 || rows < 1) 0
      (: _ (scribe scr fr) tb (cask (tw * rows * 16 * 4)) cur (gaze scr 0)
         _ (each ^rows (r \ dye scr tb tw r (cur >= 0 && cur // cols = r ? cur -1) ()))
         _ (each ^(rows * 16) (y \ pour P (4 * ((b 1 + y) * W + b 0)) tb (4 * y * tw) (4 * tw)))
         1)))
 (slip-pic f w h k P W b) (: pw (k * w) T (cask (4 * pw * k * h)) n (4 * min pw (b 2))
   _ (frame-paint f w k T pw)
   (each ^(min (k * h) (b 3)) (j \ pour P (4 * ((b 1 + j) * W + b 0)) T (4 * j * pw) n)))
)) ; module slip
