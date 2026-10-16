; src/apps/png.l -- png decoding: every colour type and depth, palettes, transparency, adam7,
; apng's frames; and encoding.
; `(borrow 'png)`, then:
;
;   (png-decode s)              -> (w h rgba) | a string saying why not
;   (png-frames s most)         -> (w h ((rgba ms) ..)), up to most frames composed on the
;                                  canvas; a still png one frame of 0 ms | why not
;   (png-encode w h rgba)       -> the png's bytes: a palette to 256 colours, else rgba
;   (png-walk c o rows n bpp)   -> the unfilter in love, in place in a cask, which the
;                                  nif (png-unfilter s o rows n bpp) answers to
;
; rgba is w*h*4 bytes, 8 bits a sample: a 16-bit sample rounds to its nearest 8-bit one,
; a low-depth grey scales to the full range. ancillary chunks past tRNS are skipped, so
; gamma and colour space are the viewer's to ignore.
(module (png png-decode png-frames png-encode png-walk png-unfilter)
(borrow 'bytes)
(borrow 'gz)
(:
   png-sig (string 137 + "PNG\r\n" + string 26 + "\n")
   png-adam7 [[0 0 8 8] [4 0 8 8] [0 4 4 8] [2 0 4 4] [0 2 2 4] [1 0 2 2] [0 1 1 2]]

   ; --- chunks ---------------------------------------------------------------------------
   ; IHDR, PLTE, tRNS and acTL land in t, the IDATs pour into one jug. each fcTL heads t's
   ; 'fr, latest first, as [fcTL before-any-IDAT jug], its fdATs poured into the jug -> 0 | why not
   (png-chunks s p t)
    (#s < p + 12 ? "truncated"
       (: n (rdbe s p 4) ty (snip s (p + 4) (p + 8))
          (#s < p + 12 + n ? "truncated"
             (snip s (p + 8) (p + 8 + n) @ body
                (? !(gz-crc32 (ty + body) = rdbe s (p + 8 + n) 4) ("bad crc in " + ty)
                   (p = 8 && ty != "IHDR") "no IHDR"
                   (ty = "IEND") 0
                   ((ty @ "IHDR" (pin t 'ihdr body) "PLTE" (pin t 'plte body)
                         "tRNS" (pin t 'trns body) "acTL" (pin t 'actl body)
                         "IDAT" (say (t 'idat) body, pin t 'seen 1)
                         "fcTL" (pin t 'fr ([body !(t 'seen) (jug 0)] . peep t 'fr ()))
                         "fdAT" (t 'fr @ fr (fr != () && 4 <= #body ? (say (<fr 2) (snip body 4 #body)) 0))
                         0),
                    (!(elem ty ["IHDR" "PLTE" "tRNS" "IDAT"]) && ty 0 < 97
                     ? ("unknown critical chunk " + ty)
                       (png-chunks s (p + 12 + n) t))))))))

   ; --- filters --------------------------------------------------------------------------
   (png-paeth a b c)
    (: p (a + b - c) pa (abs (p - a)) pb (abs (p - b)) pc (abs (p - c))
       (? (pa <= pb && pa <= pc) a (pb <= pc) b c))
   ; one row in place: d its data, u the row above's, first when there is none
   (png-recon c f d u n bpp first)
    (: (a i) (i < bpp ? 0 (peep c (d + i - bpp) 0))
       (b i) (first ? 0 (peep c (u + i) 0))
       (ul i) (first || i < bpp ? 0 (peep c (u + i - bpp) 0))
       (go i fn) (i = n ? 0 (pin c (d + i) (peep c (d + i) 0 + fn i), go (i + 1) fn))
       (f @ 1 (go 0 a)
            2 (go 0 b)
            3 (go 0 (i \ a i + b i >> 1))
            4 (go 0 (i \ png-paeth (a i) (b i) (ul i)))
            0))
   ; rows of one pass from offset o, in place -> the offset past them | why not
   (png-walk c o rows n bpp)
    (: (row k o)
        (k = rows ? o
           (: f (peep c o 0) d (o + 1)
              (4 < f ? "bad filter"
                 (png-recon c f d (d - n - 1) n bpp (k = 0), row (k + 1) (d + n)))))
       (row 0 o))
   ; src/love/picture/png.c's nif; the walk above is the oracle test/host/png.l holds it to
   ; -> [rows first-row-offset row-stride] | why not
   (png-rows c o rows n bpp)
    (png-unfilter c o rows n bpp @ r (string? r ? [r 0 n] "bad filter"))

   ; --- samples --------------------------------------------------------------------------
   ; the j'th sample of the row at d, at its own depth
   (png-sample c d j dep)
    (? (dep = 8) (peep c (d + j) 0)
       (dep = 16) (peep c (d + 2 * j) 0 << 8 | peep c (d + 2 * j + 1) 0)
       (: k (j * dep) by (peep c (d + (k >> 3)) 0)
          (by >> 8 - dep - (k & 7) & (1 << dep) - 1)))
   (png-scale v dep)
    (? (dep = 8) v (dep = 16) ((v * 255 + 32767) // 65535) (v * 255 // ((1 << dep) - 1)))

   ; one pixel of the row at d -> r g b a pinned at o in out
   (png-pixel c d x hd out o)
    (: ty (hd 'ty) dep (hd 'dep) chs (hd 'chs) trns (hd 'trns)
       (sm k) (png-sample c d (x * chs + k) dep)
       (sc v) (png-scale v dep)
       (put r g b a) (pin out o r, pin out (o + 1) g, pin out (o + 2) b, pin out (o + 3) a)
       (key k) (rdbe trns (2 * k) 2)
       (ty @ 0 (: v (sm 0) g (sc v)
                  (put g g g (#trns = 2 && v = key 0 ? 0 255)))
            2 (: r (sm 0) g (sm 1) b (sm 2)
                 (put (sc r) (sc g) (sc b)
                      (#trns = 6 && r = key 0 && g = key 1 && b = key 2 ? 0 255)))
            3 (: i (sm 0) pl (hd 'plte)
                 (put (peep pl (3 * i) 0) (peep pl (3 * i + 1) 0) (peep pl (3 * i + 2) 0)
                      (i < #trns ? (trns i) 255)))
            4 (sc (sm 0) @ g (put g g g (sc (sm 1))))
            (put (sc (sm 0)) (sc (sm 1)) (sc (sm 2)) (sc (sm 3)))))

   ; a row of 8-bit samples with no colour key, the common case, a pixel at a time
   (png-row8 c d pw hd out o step)
    (: ty (hd 'ty) chs (hd 'chs) pl (hd 'plte) trns (hd 'trns)
       (px d o)
        (ty @ 0 (peep c d 0 @ g (pins out o g (o + 1) g (o + 2) g (o + 3) 255))
             2 (pins out o (peep c d 0) (o + 1) (peep c (d + 1) 0) (o + 2) (peep c (d + 2) 0) (o + 3) 255)
             3 (: i (peep c d 0) j (3 * i)
                  (pins out o (peep pl j 0) (o + 1) (peep pl (j + 1) 0) (o + 2) (peep pl (j + 2) 0)
                        (o + 3) (i < #trns ? (trns i) 255)))
             4 (peep c d 0 @ g (pins out o g (o + 1) g (o + 2) g (o + 3) (peep c (d + 1) 0)))
             (pins out o (peep c d 0) (o + 1) (peep c (d + 1) 0) (o + 2) (peep c (d + 2) 0)
                   (o + 3) (peep c (d + 3) 0)))
       (go x d o) (x = pw ? 0 (px d o, go (x + 1) (d + chs) (o + step)))
       (go 0 d o))

   ; --- the image ------------------------------------------------------------------------
   (png-header ih)
    (: w (rdbe ih 0 4) h (rdbe ih 4 4) dep (ih 8) ty (ih 9)
       chs (ty @ 0 1 2 3 3 1 4 2 6 4 0)
       ok (ty @ 0 (elem dep [1 2 4 8 16]) 3 (elem dep [1 2 4 8]) (elem dep [8 16]))
       (? (#ih != 13) "bad IHDR"
          (!chs || !ok) "bad colour type or depth"
          (w < 1 || h < 1) "empty image"
          (16777216 < w * h) "too big"
          (ih 10 != 0 || ih 11 != 0 || ih 12 > 1) "bad IHDR methods"
          {'w w 'h h 'dep dep 'ty ty 'chs chs 'lace (ih 12)
           'bpp (chs * dep // 8 @ b (b < 1 ? 1 b))}))

   ; the filtered bytes the passes take, rows of a filter byte and their samples
   (png-need hd)
    (: w (hd 'w) h (hd 'h) bits (hd 'chs * hd 'dep)
       (need ps) (: pw ((w - ps 0 + ps 2 - 1) // ps 2) ph ((h - ps 1 + ps 3 - 1) // ps 3)
                    (pw < 1 || ph < 1 ? 0 (ph * (1 + (pw * bits + 7) // 8))))
       +(map need (hd 'lace ? png-adam7 [[0 0 1 1]])))

   ; one pass: unfilter its rows, scatter its pixels -> the offset past it | why not
   (png-pass c o hd out ps)
    (: w (hd 'w) h (hd 'h) x0 (ps 0) y0 (ps 1) dx (ps 2) dy (ps 3)
       pw ((w - x0 + dx - 1) // dx) ph ((h - y0 + dy - 1) // dy)
       n ((pw * hd 'chs * hd 'dep + 7) // 8)
       fast (hd 'dep = 8 && (hd 'ty > 2 || #(hd 'trns) = 0))
       (? (pw < 1 || ph < 1) o
          (#c < o + ph * (n + 1)) "short image data"
          (png-rows c o ph n (hd 'bpp) @ r
             (string? r ? r
                (: src (r 0) d0 (r 1) st (r 2)
                   (row y) (y = ph ? (o + ph * (n + 1))
                              (: d (d0 + y * st) at (4 * ((y0 + y * dy) * w + x0))
                                 (col x) (x = pw ? 0 (png-pixel src d x hd out (at + 4 * x * dx), col (x + 1)))
                                 ((fast ? (png-row8 src d pw hd out at (4 * dx)) (col 0)), row (y + 1))))
                   (row 0))))))

   ; --- encoding -------------------------------------------------------------------------
   (png-chunk ty body) (wrbe #body 4 + ty + body + wrbe (gz-crc32 (ty + body)) 4)
   ; zlib's checksum, the sums held under 2^32 by taking the modulus every 5552 bytes
   (png-adler s)
    (: n #s
       (run i e a b) (i = e ? [a b] (a + s i @ a2 (run (i + 1) e a2 (b + a2))))
       (go i a b) (n <= i ? (b << 16 | a)
                     (: e (min n (i + 5552)) r (run i e a b)
                        (go e (r 0 % 65521) (r 1 % 65521))))
       (go 0 1 0))
   ; a pixel's rgba as one number
   (png-key px i) (((px i << 8 | px (i + 1)) << 8 | px (i + 2)) << 8 | px (i + 3))
   ; the row y as bytes, st of them
   (png-row px st y) (snip px (y * st) ((y + 1) * st))
   ; the colours while there are at most 256 -> [keys index-of] | (), first seen first. a
   ; row that repeats the one above is not walked again
   (png-census w h px)
    (: t {} st (4 * w)
       (go y i ks m)
        (? (256 < m) ()
           (y = h) [(rev ks) t]
           (i = st) (go (y + 1) 0 ks m)
           (i = 0 && 0 < y && png-row px st y = png-row px st (y - 1)) (go (y + 1) 0 ks m)
           (png-key px (y * st + i) @ k
              (0 <= peep t k -1 ? (go y (i + 4) ks m)
                 (pin t k m, go y (i + 4) (k . ks) (m + 1)))))
       (go 0 0 () 0))
   ; filtered rows: a row that repeats the one above is up, all zero; else sub over bpp
   ; byte samples, or none when bpp is 0 (a palette's, where sub buys nothing)
   (png-filter rows n bpp)
    (: o (jug 0) zero (string (cask n))
       (sub r) (: c (cask n) _ (pour c 0 r 0 (min n bpp))
                  (go i) (n <= i ? (string c) (pin c i (r i - r (i - bpp) & 255), go (i + 1)))
                  (go bpp))
       (go rs prev)
        (atom? rs ? (slurp o)
           (<rs @ r
              ((? (r = prev) (say o (string 2 + zero))
                  (0 < bpp) (say o (string 1 + sub r))
                  (say o (string 0 + r))),
               go >rs r)))
       (go rows ()))
   (png-file w h dep ty extra z)
    (png-sig + png-chunk "IHDR" (wrbe w 4 + wrbe h 4 + string dep + string ty + string 0 + string 0 + string 0)
     + extra
     + png-chunk "IDAT" (string 120 + string 1 + gz-deflate z + wrbe (png-adler z) 4)
     + png-chunk "IEND" "")
   ; 8-bit rgba -> a png: a palette of 1 to 8 bits a pixel where there are at most 256
   ; colours, else rgba
   (png-encode w h px)
    (: st (4 * w) pal (png-census w h px)
       (pal = () ?
           (png-file w h 8 6 "" (png-filter (map (y \ png-row px st y) ^h) st 4))
          (: ks (pal 0) ix (pal 1) m #ks
             dep (? (m <= 2) 1 (m <= 4) 2 (m <= 16) 4 8) n ((w * dep + 7) // 8)
             (row y) (: r (png-row px st y) c (cask n)
                        (map (x \ (: b (x * dep) v (ix (png-key r (4 * x)))
                                     (pin c (b >> 3) (peep c (b >> 3) 0 | v << 8 - dep - (b & 7)))))
                             ^w,
                         string c))
             ; a repeated row is packed again only to be seen equal
             (rows y prev pr acc) (y = h ? (rev acc)
                                     (: r (png-row px st y)
                                        p (0 < y && r = prev ? pr (row y))
                                        (rows (y + 1) r p (p . acc))))
             plte (cats (map (k \ string (k >> 24 & 255) + string (k >> 16 & 255) + string (k >> 8 & 255)) ks))
             al (map (k \ k & 255) ks)
             trns (foldl (a \ v \ a && v = 255) 1 al ? "" (png-chunk "tRNS" (cats (map string al))))
             (png-file w h dep 3 (png-chunk "PLTE" plte + trns) (png-filter (rows 0 "" "" ()) n 0)))))

   ; the chunks read and the header laid -> t, the header its 'hd | why not
   (png-parse s)
    (pin {} 'idat (jug 0) @ t
       (#s < 8 || snip s 0 8 != png-sig ? "not a png"
          (png-chunks s 8 t @ e
             (? (string? e) e
                !(t 'ihdr) "no IHDR"
                (png-head t (t 'ihdr) @ hd
                   (? (string? hd) hd
                      (hd 'ty = 3 && #(hd 'plte) = 0) "no palette"
                      (pin t 'hd hd)))))))
   (png-head t ih)
    (png-header ih @ hd (string? hd ? hd (pin (pin hd 'trns (peep t 'trns "")) 'plte (peep t 'plte ""))))

   ; the zlib stream z of the image hd heads -> [w h rgba] | why not
   (png-pixels hd z)
    (? (#z < 2 || (z 0 * 256 + z 1) % 31 != 0 || z 0 & 15 != 8 || z 1 & 32) "bad zlib header"
       (: need (png-need hd)
          r (gz-inflate (snip z 2 #z) need)
          (? (atom? r) "bad deflate stream"
             (#<>r < need) "short image data"
             (: c <>r
                w (hd 'w) h (hd 'h) out (cask (4 * w * h))
                passes (hd 'lace ? png-adam7 [[0 0 1 1]])
                (go ps o) (!ps ? 0
                             (png-pass c o hd out <ps @ e
                                (string? e ? e (go >ps e))))
                e (go passes 0)
                (string? e ? e [w h (string out)])))))

   (png-decode s) (png-parse s @ t (string? t ? t (png-pixels (t 'hd) (slurp (t 'idat)))))

   ; --- apng -----------------------------------------------------------------------------
   ; a frame's fcTL: sequence, w h x y, the delay's numerator and denominator, dispose (0
   ; none, 1 cleared, 2 the canvas before it) and blend (0 overwrite, 1 over). the canvas
   ; starts clear; a first frame disposing to the one before is cleared. a later frame that
   ; fails ends the walk with the frames so far
   (png-frames s most)
    (png-parse s @ t
       (? (string? t) t
          (: hd (t 'hd) w (hd 'w) h (hd 'h) ih (t 'ihdr)
             frs (rev (peep t 'fr ()))
             (fail why acc) (acc = () ? why [w h (rev acc)])
             (go fs c n acc)
              (? (fs = () || most <= n) [w h (rev acc)]
                 (: f <fs fc (f 0)
                    (? (#fc < 26 || 2 < fc 24 || 1 < fc 25) (fail "a bad fcTL" acc)
                       (: fw (rdbe fc 4 4) fh (rdbe fc 8 4) x (rdbe fc 12 4) y (rdbe fc 16 4)
                          dd (rdbe fc 22 2) ms ((rdbe fc 20 2 * 1000 + (dd = 0 ? 100 dd) // 2) // (dd = 0 ? 100 dd))
                          sub (png-head t (wrbe fw 4 + wrbe fh 4 + snip ih 8 13))
                          r (string? sub ? sub (png-pixels sub (slurp (f 1 ? (t 'idat) (f 2)))))
                          out (string? r ? () (png-lay c w (r 2) fw x y (fc 25)))
                          (? (string? r) (fail r acc)
                             (out = ()) (fail "a frame past the canvas" acc)
                             (go >fs (? (fc 24 = 1 || fc 24 = 2 && acc = ()) (png-lay out w (string (cask (4 * fw * fh))) fw x y 0)
                                        (fc 24 = 2) c
                                        out)
                                 (n + 1) ([out ms] . acc)))))))
             (? (!(t 'actl) || frs = ())
                 (png-pixels hd (slurp (t 'idat)) @ r (string? r ? r [w h [[(r 2) 0]]]))
                (go frs (string (cask (4 * w * h))) 0 ()))))))
) ; module png
