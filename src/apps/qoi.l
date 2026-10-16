; src/apps/qoi.l -- the quite ok image format, read and written, over src/love/picture/qoi.c.
; `(borrow 'qoi)`, then:
;
;   (qoi-size s)           -> (w h) off the header | a string saying why not
;   (qoi-decode s)         -> (w h rgba) | a string saying why not
;   (qoi-encode w h rgba)  -> the qoi's bytes, as the reference encoder writes them | ()
;
; rgba is w*h*4 bytes; a 3-channel file's alpha is 255.
(module (qoi qoi-size qoi-decode qoi-encode qoi-pixels)
(borrow 'bytes)
(:
   qoi-why ["" "not a qoi" "cut short" "" "" "too big"]
   (qoi-size s)
    (? (#s < 14 || snip s 0 4 != "qoif" || !(elem (s 12) [3 4]) || 1 < s 13) "not a qoi"
       (: w (rdbe s 4 4) h (rdbe s 8 4)
          (? (w < 1 || h < 1) "not a qoi" (16777216 < w * h) "too big" [w h])))
   (qoi-decode s)
    (qoi-size s @ d
       (? (string? d) d
          (qoi-pixels s @ r
             (? (string? r) [(d 0) (d 1) r] (charm? r) (qoi-why r) "not a qoi"))))
))
