; src/apps/bmp.l -- windows' pictures: bmp and the ico and cur that hold them, read.
;
;   (bmp-size s)    -> (w h) off the header | a string saying why not
;   (bmp-decode s)  -> (w h rgba) | a string saying why not
;   (ico-size s)    -> (w h) of the icon it would show | why not
;   (ico-decode s)  -> (w h rgba) of its largest, deepest picture | why not
;
; rgba is w*h*4 bytes. under rle a pixel no run reaches is colour 0; alpha is the mask's
; where there is one, else 255. an icon's bmp is twice as tall for the and-mask under it,
; except at 32 bits, where its own alpha says what is clear.
(module (bmp bmp-size bmp-decode ico-size ico-decode)
(borrow 'bytes)
(:
   (bmp-s32 s i) (rdle s i 4 @ v (v < 2147483648 ? v (v - 4294967296)))
   ; a mask -> [shift top], top its largest value; [0 0] for none
   (bmp-mask m)
    (: (lo k) (? (32 <= k || ((m >> k) & 1) = 1) k (lo (k + 1)))
       sh (lo 0)
       (m = 0 ? [0 0] [sh (m >> sh)]))
   (bmp-chan v mk) (mk 1 = 0 ? 255 (((v >> mk 0) & mk 1) * 255 // mk 1))

   ; the dib whose header sits at a -> [w h bpp comp masks pal data top] | why not. at:
   ; where the pixels start when no file header names them; tall halves the height
   (bmp-head s a at tall)
    (: hs (#s < a + 16 ? 0 (rdle s a 4))
       core (hs = 12)
       (? (#s < a + hs || !(elem hs [12 40 52 56 64 108 124])) "a kind of bmp this can't read"
          (: w (core ? (rdle s (a + 4) 2) (bmp-s32 s (a + 4)))
             h0 (core ? (rdle s (a + 6) 2) (bmp-s32 s (a + 8)))
             bpp (rdle s (a + (core ? 10 14)) 2)
             comp (core ? 0 (rdle s (a + 16) 4))
             used (core || hs < 40 ? 0 (rdle s (a + 32) 4))
             top (h0 < 0)
             h ((top ? (0 - h0) h0) // (tall ? 2 1))
             fields (elem comp [3 6])
             ; masks in a header of 52 or more, else just past an info header's 40
             mo (a + (hs < 52 ? hs 40))
             extra (hs = 40 && fields ? (comp = 6 ? 16 12) 0)
             (m k) (#s < mo + 4 * k + 4 ? 0 (rdle s (mo + 4 * k) 4))
             masks (? fields [(bmp-mask (m 0)) (bmp-mask (m 1)) (bmp-mask (m 2))
                              (bmp-mask (comp = 6 || 56 <= hs ? (m 3) 0))]
                      (bpp = 16) [(bmp-mask 31744) (bmp-mask 992) (bmp-mask 31) [0 0]]
                      [(bmp-mask 16711680) (bmp-mask 65280) (bmp-mask 255) [0 0]])
             pn (bpp <= 8 ? (0 < used ? (min used (1 << bpp)) (1 << bpp)) 0)
             po (a + hs + extra) pe (core ? 3 4)
             pal (map (i \ (: q (po + pe * i) [(peep s (q + 2) 0) (peep s (q + 1) 0) (peep s q 0)])) (jot pn))
             data (at = () ? (po + pe * pn) at)
             (? (w < 1 || h < 1) "no pixels"
                (16777216 < w * h) "too big"
                !(elem bpp [1 4 8 16 24 32]) "a depth this can't read"
                (? (comp = 1) (bpp != 8 || top) (comp = 2) (bpp != 4 || top)
                   fields !(elem bpp [16 32]) (comp != 0)) "a compression this can't read"
                [w h bpp comp masks pal data top]))))

   ; the run-length pixels of rle8 or rle4 -> a cask of w*h palette indices, top row first
   (bmp-rle s hd)
    (: w (hd 0) h (hd 1) four (hd 3 = 2) c (cask (w * h))
       (put x y v) (? (x < w && y < h) (pin c ((h - 1 - y) * w + x) v) 0)
       (go p x y)
        (? (#s < p + 2 || h <= y) c
           (: n (s p) b (s (p + 1))
              (? (0 < n)                               ; a run: n pixels of b (two nibbles alternating)
                  (: (run k) (? (k = n) 0 (put (x + k) y (four ? (k & 1 = 0 ? (b >> 4) (b & 15)) b), run (k + 1)))
                     (run 0, go (p + 2) (x + n) y))
                 (b = 0) (go (p + 2) 0 (y + 1))
                 (b = 1) c
                 (b = 2) (#s < p + 4 ? c (go (p + 4) (x + s (p + 2)) (y + s (p + 3))))
                 ; b literal pixels, padded to a word
                 (: nb (four ? ((b + 1) // 2) b)
                    (lit k) (? (k = b) 0
                               (: v (four ? (peep s (p + 2 + k // 2) 0 @ q (k & 1 = 0 ? (q >> 4) (q & 15)))
                                           (peep s (p + 2 + k) 0))
                                  (put (x + k) y v, lit (k + 1))))
                    (lit 0, go (p + 2 + nb + (nb & 1)) (x + b) y)))))
       (go (hd 6) 0 0))

   ; -> [w h rgba] | why not
   (bmp-pixels s hd)
    (: w (hd 0) h (hd 1) bpp (hd 2) comp (hd 3) mk (hd 4) pal (hd 5) at (hd 6) top (hd 7)
       stride ((w * bpp + 31) // 32 * 4)
       rle (elem comp [1 2] ? (bmp-rle s hd) ())
       pn #pal
       short (rle = () && #s < at + stride * h)
       pc (cask (4 * max 1 pn))
       _ (each (jot pn) (i \ (: e (pal i) (pin pc (4 * i) (e 0), pin pc (4 * i + 1) (e 1), pin pc (4 * i + 2) (e 2)))))
       o (short ? "" (cask (4 * w * h)))
       ; the start of the y-th row shown
       (row y) (at + stride * (top ? y (h - 1 - y)))
       ; a palette depth's index at x of the row from r
       (ix x y r) (? (rle != ()) (peep rle (y * w + x) 0)
                     (bpp = 8) (s (r + x))
                     (bpp = 4) ((s (r + (x >> 1))) @ q (x & 1 = 0 ? (q >> 4) (q & 15)))
                     ((s (r + (x >> 3)) >> (7 - (x & 7))) & 1))
       (lay i r g b a) (pin o i r, pin o (i + 1) g, pin o (i + 2) b, pin o (i + 3) a)
       (one x y r i)
        (? (bpp <= 8) (: k (ix x y r) q (4 * (k < pn ? k 0))
                         (lay i (peep pc q 0) (peep pc (q + 1) 0) (peep pc (q + 2) 0) 255))
           (bpp = 24) (: q (r + 3 * x) (lay i (s (q + 2)) (s (q + 1)) (s q) 255))
           (: v (rdle s (r + (bpp >> 3) * x) (bpp >> 3))
              (lay i (bmp-chan v (mk 0)) (bmp-chan v (mk 1)) (bmp-chan v (mk 2)) (bmp-chan v (mk 3)))))
       (go x y r)
        (? (y = h) [w h (string o)]
           (x = w) (go 0 (y + 1) (row (y + 1)))
           (one x y r (4 * (y * w + x)), go (x + 1) y r))
       (short ? "cut short" (go 0 0 (row 0))))

   (bmp-file s)
    (? (#s < 26 || snip s 0 2 != "BM") "not a bmp"
       (bmp-head s 14 (rdle s 10 4) 0))
   (bmp-size s) (bmp-file s @ hd (string? hd ? hd [(hd 0) (hd 1)]))
   (bmp-decode s) (bmp-file s @ hd (string? hd ? hd (bmp-pixels s hd)))

   ; --- icons ------------------------------------------------------------------------------
   ; the directory's best entry -> [w h bpp size at] | why not: most pixels, then deepest
   (ico-entry s)
    (: n (#s < 6 ? 0 (rdle s 4 2))
       (ent i) (: e (6 + 16 * i)
                  [(s e = 0 ? 256 (s e)) (s (e + 1) = 0 ? 256 (s (e + 1))) (rdle s (e + 6) 2)
                   (rdle s (e + 8) 4) (rdle s (e + 12) 4)])
       (? (#s < 6 || rdle s 0 2 != 0 || !(elem (rdle s 2 2) [1 2]) || n < 1) "not an icon"
          (#s < 6 + 16 * n) "cut short"
          (foldl (b \ e \ (e 0 * e 1 > b 0 * b 1 || e 0 * e 1 = b 0 * b 1 && e 2 > b 2 ? e b))
                 (ent 0) (map ent (jot n)))))
   (ico-png? s at) (snip s at (at + 8) = "\x89PNG\r\n\x1a\n")
   (ico-size s)
    (ico-entry s @ e
       (? (string? e) e
          (#s < e 4 + 8) "cut short"
          (ico-png? s (e 4)) (#s < e 4 + 24 ? "cut short" [(rdbe s (e 4 + 16) 4) (rdbe s (e 4 + 20) 4)])
          (bmp-head s (e 4) () 1 @ hd (string? hd ? hd [(hd 0) (hd 1)]))))
   (ico-decode s)
    (ico-entry s @ e
       (? (string? e) e
          (#s < e 4 + 8) "cut short"
          (ico-png? s (e 4)) (cite 'png 'png-decode (snip s (e 4) (e 4 + e 3)))
          (bmp-head s (e 4) () 1 @ hd
             (? (string? hd) hd
                (bmp-pixels s hd @ r
                   (? (string? r) r
                      (: w (hd 0) h (hd 1) bpp (hd 2) top (hd 7)
                         px (cask (4 * w * h)) _ (pour px 0 (r 2) 0 (4 * w * h))
                         ; 32 bits carry their own alpha, the 4th byte
                         xs ((w * bpp + 31) // 32 * 4)
                         ms ((w + 31) // 32 * 4) mo (hd 6 + xs * h)
                         (al i) (? (bpp = 32) (s (hd 6 + xs * (top ? (i // w) (h - 1 - i // w)) + 4 * (i % w) + 3))
                                   (: y (i // w) x (i % w) b (peep s (mo + ms * (h - 1 - y) + (x >> 3)) 0)
                                      (((b >> (7 - (x & 7))) & 1) = 1 ? 0 255)))
                         (go i) (? (i = w * h) [w h (string px)] (pin px (4 * i + 3) (al i), go (i + 1)))
                         (? (bpp != 32 && #s < mo + ms * h) "cut short" (go 0)))))))))
))
