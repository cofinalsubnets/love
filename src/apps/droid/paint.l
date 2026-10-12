; src/apps/droid/paint.l -- a finger-painting toy, the face's smallest program:
;   love apk -L LOVE src/apps/droid/paint.l
(borrow 'droid)
(: s (face-open 0)
   win (face-next s)
   ; the frame keeps the window's aspect at 180 wide, and the window scales it up
   w 180 h (win 3 * 180 // win 2)
   fb (cask (w * h * 4))
   (px x y v) (0 <= x < w && 0 <= y < h ?
                (: i (4 * (y * w + x)) (pin fb i (v & 255), pin fb (i + 1) (v >> 8 & 255), pin fb (i + 2) (v >> 16 & 255))))
   _ (each ^h (y \ each ^w (x \ px x y ((x * 255 // w) << 16 | (y * 255 // h) << 8 | 64))))
   (dab x y) (each ^5 (j \ each ^5 (i \ px (x + i - 2) (y + j - 2) 16777215)))
   ; a touch dabs; a frame goes once the records in hand are spent
   (go _) (face-next s @ r (? (atom? r) 0
                              ((? (r 0 = 84) (dab (r 2) (r 3)) 0),
                               (cue? s ? (go 0) (face-frame s w h fb, go 0)))))
   (face-frame s w h fb, go 0))
