; apps/jpeg.l -- jpeg decoding, over love/lib/jpeg.c's nif (jpeg-pixels s).
; `(borrow 'jpeg)`, then:
;
;   (jpeg-size s)    -> (w h) from the frame header | a string saying why not
;   (jpeg-decode s)  -> (w h rgba) | a string saying why not
;
; rgba is w*h*4 bytes, alpha all 255. baseline and progressive, grey and ycbcr; where the
; artifact carries no nif, every jpeg is "no decoder here".
(module (jpeg jpeg-size jpeg-decode)
(:
   jpeg-why ["" "not a jpeg" "cut short" "a kind of jpeg this can't read" "a bad table or scan"
             "too big"]
   (jpeg-be16 s i) (s i * 256 + s (i + 1))

   ; the markers from the top to the frame header, its length word at p
   (jpeg-size s)
    (: (go p)
        (? (#s < (p + 9)) "cut short"
           (s p != 255) (go (p + 1))
           (: m (s (p + 1))
              (? (m = 255) (go (p + 1))
                 ((m = 0) || (m = 1) || (208 <= m <= 216)) (go (p + 2))
                 ((192 <= m <= 207) && !(elem m [196 200 204]))
                  [(jpeg-be16 s (p + 7)) (jpeg-be16 s (p + 5))]
                 (m = 217) "no frame"
                 (go (p + 2 + jpeg-be16 s (p + 2))))))
       (? ((#s < 4) || (s 0 != 255) || (s 1 != 216)) "not a jpeg" (go 2)))

   ; the door: the nif where the artifact carries it, asked at first call, never at load
   jpeg-door (tablet 0)
   (jpeg-nif? _)
    (: v (peep jpeg-door 0 ())
       (? (charm? v) v
          (: w (trap (\ _ (: _ (jpeg-pixels "") 1)) () (\ a b 0)) _ (pin jpeg-door 0 w) w)))

   (jpeg-decode s)
    (: d (jpeg-size s)
       (? (string? d) d
          !(jpeg-nif? 0) "no decoder here"
          (: r (jpeg-pixels s)
             (? (string? r) [(d 0) (d 1) r] (charm? r) (jpeg-why r) "not a jpeg"))))))
