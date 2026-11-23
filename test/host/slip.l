; slip.l: an app's panes: the keys, the bar dragged, the least sizes, and what is laid on a paper
(borrow '(slip quay))
(: s (slip-new ['beside 50 'a 'b] 'a) _ (slip-lay s 640 400)
   (now _) [(s 'plan) (s 'focus) (slip-cells s 'a) (slip-cells s 'b)] (k c) (: _ (slip-key s c) (now ()))
   k0 (now ()) k1 (k 119) k2 (k 109) k3 (k 120) k4 (k 43) k5 (k 61) k6 (k 107) k7 (k 109) kn (slip-key s 5)
 (test (k0 = [['beside 50 'a 'b] 'a [0 0 39 25] [40 0 40 25]]) (k1 1 = 'b) (k2 = [['stack 50 'a 'b] 'b [0 0 80 12] [0 13 80 12]])
       (k3 0 = ['stack 50 'b 'a]) (k4 0 = ['stack 55 'b 'a]) (k5 0 = ['stack 50 'b 'a]) (k6 1 = 'b) (k7 2 = [40 0 40 25]) (kn = 0)))
; a press takes hold of the bar, a drag moves it as far as the least sizes let it, and a press
; on a pane gives it the keys
(: s (slip-new ['beside 50 'a 'b] 'a) _ (slip-lay s 640 400)
   p (slip-press s 320 9) h (slip-press s (8 * 39) 9) m (slip-drag s (8 * 30) 9) b (slip-box s 'a) _ (slip-drag s 0 9) b2 (slip-box s 'a) d (slip-drop s) d2 (slip-drop s)
   m2 (slip-drag s 400 9) f (s 'focus) ov (slip-over s 0 0)
 (test (p = 'b) (f = 'b) (h = 'bar) (m = 1) (b = [0 0 240 400]) (b2 = b) (d = 1) (d2 = 0) (m2 = 0) (ov = 'a) (slip-bars s = [['down 0 30 25]])))
; laid on a paper: a picture, a rim, a pane cleared, and a terminal's face drawn when it must be
(: s (slip-new ['stack 50 'a 'b] 'a) _ (slip-lay s 160 144) P (cask (160 * 144 * 4)) (at x y) (string P (4 * (y * 160 + x)))
   _ (slip-pic (iota 100 * 0 + 7) 10 10 2 P 160 (slip-box s 'b)) q (map (xy \ at (xy 0) (xy 1)) [[0 79] [0 80] [19 99] [20 99]])
   _ (slip-rim P 160 (slip-box s 'b) 9) r [(at 0 80) (at 159 143) (at 2 82)] _ (slip-clear P 160 (slip-box s 'b)) c (at 2 82)
   sc (slip-screen s 'a) n (slip-face s 'a sc "" 0 P 160) y (slip-face s 'a sc "hi" 0 P 160)
 (test (q = [0 7 7 0]) (r = [9 9 7]) (c = 0) (n = 0) (y = 1) (any (i \ string P i != 0) ^(4 * 160 * 16))))

(test_fin ())
(puts "slip: ok\n")
