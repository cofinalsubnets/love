; src/apps/jpeg.l -- jpeg decoding, over src/love/picture/jpeg.c's nif (jpeg-pixels s).
; `(borrow 'jpeg)`, then:
;
;   (jpeg-size s)    -> (w h) as shown, off the frame header | a string saying why not
;   (jpeg-decode s)  -> (w h rgba) | a string saying why not
;   (jpeg-orient s)  -> exif's orientation, 1..8, 1 where there is none
;
; rgba is w*h*4 bytes, alpha all 255. baseline and progressive, grey, ycbcr and cmyk; where the
; artifact carries no nif, every jpeg is "no decoder here". a picture is laid upright by its
; exif orientation, as a viewer shows it: 5 to 8 turn it on its side, swapping w and h.
(module (jpeg jpeg-size jpeg-decode jpeg-encode jpeg-pixels jpeg-orient)
(borrow 'bytes)
(:
   jpeg-why ["" "not a jpeg" "cut short" "a kind of jpeg this can't read" "a bad table or scan"
             "too big"]

   ; the markers from the top, fill and restarts passed over: (f m p go) at each other
   ; marker m at p, go walking on from a later p; short when fewer than k bytes are left
   (jpeg-marks s k bad short f)
    (: (go p)
        (? (#s < p + k) short
           (s p != 255) (go (p + 1))
           (s (p + 1) @ m
              (? (m = 255) (go (p + 1))
                 (m = 0 || m = 1 || 208 <= m <= 216) (go (p + 2))
                 (f m p go))))
       (#s < 4 || s 0 != 255 || s 1 != 216 ? bad (go 2)))
   (jpeg-sof? m) (192 <= m <= 207 && !(elem m [196 200 204]))

   ; the frame header's (w h)
   (jpeg-frame s)
    (jpeg-marks s 9 "not a jpeg" "cut short"
       (m \ p \ go \ (? (jpeg-sof? m) [(rdbe s (p + 7) 2) (rdbe s (p + 5) 2)]
                         (m = 217) "no frame"
                         (go (p + 2 + rdbe s (p + 2) 2)))))

   ; app1's exif: a tiff header, ii or mm, whose first directory may hold tag 274. the
   ; markers are walked to the first frame or scan header, past which no app1 counts
   (jpeg-orient s)
    (: (tiff t e)
        (: (rd k n) (e < k + n ? 0 (s t = 73 ? (rdle s k n) (rdbe s k n)))
           ifd (t + rd (t + 4) 4)
           (tag i) (: q (ifd + 2 + 12 * i)
                      (? (rd ifd 2 <= i || e < q + 12) 1
                         (rd q 2 = 274 && rd (q + 2) 2 = 3) (rd (q + 8) 2 @ v (1 <= v <= 8 ? v 1))
                         (tag (i + 1))))
           (? (e < t + 8 || !(elem (s t) [73 77]) || rd (t + 2) 2 != 42) 1 (tag 0)))
       (jpeg-marks s 4 1 1
          (m \ p \ go \ (? (jpeg-sof? m || m = 217 || m = 218) 1
                            (: e (min #s (p + 2 + rdbe s (p + 2) 2))
                               (m = 225 && p + 10 <= e && snip s (p + 4) (p + 10) = "Exif\0\0" ?
                                  (tiff (p + 10) e)
                                  (go e)))))))

   (jpeg-size s)
    (jpeg-frame s @ d (string? d || jpeg-orient s < 5 ? d [(d 1) (d 0)]))


   (jpeg-decode s)
    (jpeg-size s @ d
       (? (string? d) d
          (jpeg-pixels s (jpeg-orient s) @ r
             (? (string? r) [(d 0) (d 1) r] (charm? r) (jpeg-why r) "not a jpeg"))))))
