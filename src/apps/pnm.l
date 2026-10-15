; src/apps/pnm.l -- netpbm's pictures: pbm, pgm, ppm and pam, read in all seven kinds and
; written as ppm or pam.
; `(borrow 'pnm)`, then:
;
;   (pnm-size s)          -> (w h) off the header | a string saying why not
;   (pnm-decode s)        -> (w h rgba) | a string saying why not
;   (pnm-encode w h rgba) -> a ppm (P6) of the colours, alpha dropped
;   (pam-encode w h rgba) -> a pam (P7, RGB_ALPHA) of all four
;
; rgba is w*h*4 bytes. P1..P3 are text, P4..P6 the same as bytes, P7 a pam of depth 1 to 4
; (grey, grey and alpha, rgb, rgb and alpha). a sample past maxval 255 is two bytes, high
; first, and every maxval scales to 8 bits, rounded. in a bitmap 1 is black.
(module (pnm pnm-size pnm-decode pnm-encode pam-encode)
(:
   (pnm-ws? c) (c = 32 || 9 <= c <= 13)
   (pnm-dig? c) (48 <= c <= 57)
   ; past blanks and # comments from i -> the index of the next word
   (pnm-skip s i)
    (? (#s <= i) i
       (pnm-ws? (s i)) (pnm-skip s (i + 1))
       (s i = 35) ((: (eol j) (? (#s <= j || s j = 10 || s j = 13) j (eol (j + 1)))) i @ j (pnm-skip s j))
       i)
   ; the number at the next word from i -> [v j], j just past its digits | ()
   (pnm-num s i)
    (: j (pnm-skip s i)
       (dig k v) (? (k < #s && pnm-dig? (s k)) (dig (k + 1) (v * 10 + s k - 48)) [v k])
       (j < #s && pnm-dig? (s j) ? (dig j 0) ()))

   ; pam's header lines, from i to ENDHDR -> the tablet of its words | why not
   (pnm-pamhead s i)
    (: (line j t)
        (: k (pnm-skip s j)
           (word a) (? (a < #s && !(pnm-ws? (s a))) (word (a + 1)) a)
           e (word k) w (snip s k e)
           (? (#s <= k) "cut short"
              (w = "ENDHDR") (pin t 'at ((: (eol a) (? (#s <= a || s a = 10) (a + 1) (eol (a + 1)))) e))
              (w = "TUPLTYPE") ((: (eol a) (? (#s <= a || s a = 10) a (eol (a + 1)))) e @ a (line a t))
              (pnm-num s e @ r
                 (two? r ? (line (r 1) (pin t w (r 0))) ("a bad pam header at " + w)))))
       (line i {}))

   ; -> [kind w h maxval depth at], at where the raster starts (the first sample's word, for
   ; the text kinds) | why not
   (pnm-head s)
    (: k (2 <= #s && s 0 = 80 ? (s 1 - 48) 0)
       (nums i n acc) (? (n = 0) [(rev acc) i]
                         (pnm-num s i @ r (two? r ? (nums (r 1) (n - 1) (r 0 . acc)) ())))
       (? (k < 1 || 7 < k) "not a pnm"
          (k = 7)
           (pnm-pamhead s 2 @ t
              (? (string? t) t
                 [7 (peep t "WIDTH" 0) (peep t "HEIGHT" 0) (peep t "MAXVAL" 0) (peep t "DEPTH" 0) (t 'at)]))
          (: bit (elem k [1 4])
             (nums 2 (bit ? 2 3) () @ r
                (? (atom? r) "cut short"
                   (: v (r 0) at (r 1)
                      [k (v 0) (v 1) (bit ? 1 (v 2)) (elem k [3 6] ? 3 1) (k < 4 ? at (at + 1))]))))))

   (pnm-check s hd)
    (? (string? hd) hd
       (: k (hd 0) w (hd 1) h (hd 2) mx (hd 3) d (hd 4) at (hd 5)
          bs (mx < 256 ? 1 2)
          ; a text sample takes a digit and a blank, a text bitmap's just its digit
          need (? (k = 4) (h * ((w + 7) // 8)) (k = 1) (w * h) (k < 4) (2 * w * h * d - 1) (w * h * d * bs))
          (? (w < 1 || h < 1) "no pixels"
             (16777216 < w * h) "too big"
             (mx < 1 || 65535 < mx) "a bad maxval"
             (d < 1 || 4 < d) "a bad depth"
             (#s < at + need) "cut short"
             hd)))

   (pnm-size s)
    (pnm-check s (pnm-head s) @ hd (string? hd ? hd [(hd 1) (hd 2)]))

   ; the samples, n = w*h*depth of them, as a cask of 8-bit values | why not
   (pnm-samples s hd)
    (: k (hd 0) w (hd 1) h (hd 2) mx (hd 3) at (hd 5) n (w * h * hd 4)
       c (cask n)
       (sc v) ((v * 255 + mx // 2) // mx)
       (? (k = 4)
           (: rb ((w + 7) // 8)
              (go i) (? (i = n) c
                        (: y (i // w) x (i % w)
                           (pin c i (((s (at + y * rb + (x >> 3)) >> (7 - (x & 7))) & 1) = 1 ? 0 255),
                            go (i + 1))))
              (go 0))
          (k = 1)
           (: (go i j) (? (i = n) c
                          (: j2 (pnm-skip s j)
                             (? (#s <= j2) "cut short"
                                (s j2 @ 48 (pin c i 255, go (i + 1) (j2 + 1))
                                        49 (pin c i 0, go (i + 1) (j2 + 1))
                                        "a bad bitmap digit"))))
              (go 0 at))
          (k < 4)
           (: (go i j) (? (i = n) c
                          (pnm-num s j @ r
                             (? (atom? r) "cut short"
                                (mx < r 0) "a sample past maxval"
                                (pin c i (sc (r 0)), go (i + 1) (r 1)))))
              (go 0 at))
          (mx < 256)
           (: (go i) (? (i = n) c (pin c i (sc (s (at + i))), go (i + 1)))
              (mx = 255 ? (pour c 0 s at n, c) (go 0)))
          (: (go i) (? (i = n) c
                       (: p (at + 2 * i) (pin c i (sc (min mx (s p * 256 + s (p + 1)))), go (i + 1))))
             (go 0))))

   (pnm-decode s)
    (pnm-check s (pnm-head s) @ hd
       (? (string? hd) hd
          (pnm-samples s hd @ c
             (? (string? c) c
                (: w (hd 1) h (hd 2) d (hd 4) n (w * h) o (cask (4 * n))
                   (go i) (? (i = n) [w h (string o)]
                             (: p (d * i) q (4 * i)
                                (? (d < 3)
                                    (: g (peep c p 0) (pin o q g, pin o (q + 1) g, pin o (q + 2) g,
                                                       pin o (q + 3) (d = 2 ? (peep c (p + 1) 0) 255)))
                                   (pin o q (peep c p 0), pin o (q + 1) (peep c (p + 1) 0),
                                    pin o (q + 2) (peep c (p + 2) 0), pin o (q + 3) (d = 4 ? (peep c (p + 3) 0) 255))),
                                go (i + 1)))
                   (go 0))))))

   (pnm-encode w h px)
    (: n (w * h) c (cask (3 * n))
       (go i) (? (i = n) 0 (: p (4 * i) q (3 * i)
                              (pin c q (px p), pin c (q + 1) (px (p + 1)), pin c (q + 2) (px (p + 2)),
                               go (i + 1))))
       (go 0, "P6\n\(w) \(h)\n255\n" + string c))

   (pam-encode w h px)
    ("P7\nWIDTH \(w)\nHEIGHT \(h)\nDEPTH 4\nMAXVAL 255\nTUPLTYPE RGB_ALPHA\nENDHDR\n" + px)
))
