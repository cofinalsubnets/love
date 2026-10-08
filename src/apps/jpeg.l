; src/apps/jpeg.l -- jpeg decoding, over src/love/lib/jpeg.c's nif (jpeg-pixels s).
; `(borrow 'jpeg)`, then:
;
;   (jpeg-size s)    -> (w h) from the frame header | a string saying why not
;   (jpeg-decode s)  -> (w h rgba) | a string saying why not
;
; rgba is w*h*4 bytes, alpha all 255. baseline and progressive, grey and ycbcr; where the
; artifact carries no nif, every jpeg is "no decoder here".
(module (jpeg jpeg-size jpeg-decode jpeg-encode jpeg-pixels)
(borrow 'bytes)
(:
   jpeg-why ["" "not a jpeg" "cut short" "a kind of jpeg this can't read" "a bad table or scan"
             "too big"]

   ; the markers from the top to the frame header, its length word at p
   (jpeg-size s)
    (: (go p)
        (? (#s < p + 9) "cut short"
           (s p != 255) (go (p + 1))
           (s (p + 1) @ m
              (? (m = 255) (go (p + 1))
                 (m = 0 || m = 1 || 208 <= m <= 216) (go (p + 2))
                 (192 <= m <= 207 && !(elem m [196 200 204]))
                  [(rdbe s (p + 7) 2) (rdbe s (p + 5) 2)]
                 (m = 217) "no frame"
                 (go (p + 2 + rdbe s (p + 2) 2)))))
       (#s < 4 || s 0 != 255 || s 1 != 216 ? "not a jpeg" (go 2)))


   (jpeg-decode s)
    (jpeg-size s @ d
       (? (string? d) d
          (jpeg-pixels s @ r
             (? (string? r) [(d 0) (d 1) r] (charm? r) (jpeg-why r) "not a jpeg"))))))
