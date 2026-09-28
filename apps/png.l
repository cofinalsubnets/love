; apps/png.l -- png decoding: every colour type and depth, palettes, transparency, adam7.
; `(borrow 'png)`, then:
;
;   (png-decode s)              -> (w h rgba) | a string saying why not
;   (png-walk c o rows n bpp)   -> the unfilter in love, in place in a cask, which the
;                                  nif (png-unfilter s o rows n bpp) answers to
;
; rgba is w*h*4 bytes, 8 bits a sample: a 16-bit sample rounds to its nearest 8-bit one,
; a low-depth grey scales to the full range. ancillary chunks past tRNS are skipped, so
; gamma and colour space are the viewer's to ignore.
(module (png png-decode png-walk)
(borrow 'bytes)
(borrow 'gz)
(:
   png-sig (string 137 + "PNG\r\n" + string 26 + "\n")
   png-adam7 [[0 0 8 8] [4 0 8 8] [0 4 4 8] [2 0 4 4] [0 2 2 4] [1 0 2 2] [0 1 1 2]]

   ; --- chunks ---------------------------------------------------------------------------
   ; IHDR, PLTE and tRNS land in t, the IDATs pour into one jug. -> 0 | why not
   (png-chunks s p t)
    (? (#s < (p + 12)) "truncated"
       (: n (rdbe s p 4) ty (snip s (p + 4) (p + 8))
          (? (#s < (p + 12 + n)) "truncated"
             (: body (snip s (p + 8) (p + 8 + n))
                (? !(gz-crc32 (ty + body) = rdbe s (p + 8 + n) 4) ("bad crc in " + ty)
                   ((p = 8) && (ty != "IHDR")) "no IHDR"
                   (ty = "IEND") 0
                   (: _ (ty @ "IHDR" (pin t 'ihdr body) "PLTE" (pin t 'plte body)
                             "tRNS" (pin t 'trns body) "IDAT" (say (t 'idat) body) 0)
                      (? (!(elem ty ["IHDR" "PLTE" "tRNS" "IDAT"]) && (ty 0 < 97))
                          ("unknown critical chunk " + ty)
                         (png-chunks s (p + 12 + n) t))))))))

   ; --- filters --------------------------------------------------------------------------
   (png-paeth a b c)
    (: p ((a + b) - c) pa (abs (p - a)) pb (abs (p - b)) pc (abs (p - c))
       (? ((pa <= pb) && (pa <= pc)) a (pb <= pc) b c))
   ; one row in place: d its data, u the row above's, first when there is none
   (png-recon c f d u n bpp first)
    (: (a i) (? (i < bpp) 0 (peep c (d + i - bpp) 0))
       (b i) (? first 0 (peep c (u + i) 0))
       (ul i) (? (first || (i < bpp)) 0 (peep c (u + i - bpp) 0))
       (go i fn) (? (i = n) 0 (: _ (pin c (d + i) (peep c (d + i) 0 + fn i)) (go (i + 1) fn)))
       (f @ 1 (go 0 a)
            2 (go 0 b)
            3 (go 0 (i \ ((a i) + (b i)) >> 1))
            4 (go 0 (i \ png-paeth (a i) (b i) (ul i)))
            0))
   ; rows of one pass from offset o, in place -> the offset past them | why not
   (png-walk c o rows n bpp)
    (: (row k o)
        (? (k = rows) o
           (: f (peep c o 0) d (o + 1)
              (? (4 < f) "bad filter"
                 (: _ (png-recon c f d (d - n - 1) n bpp (k = 0)) (row (k + 1) (d + n))))))
       (row 0 o))
   ; the door: love/lib/png.c's nif where the artifact carries it, else the walk. asked at
   ; first call, never at load, where the answer would be the baking love's.
   ; -> [rows first-row-offset row-stride] | why not
   png-door (tablet 0)
   png-probe (\ _ (png-unfilter "" 0 0 0 1))
   (png-nif? _)
    (: v (peep png-door 0 ())
       (? (charm? v) v (: w (trap (\ _ (: _ (png-probe 0) 1)) () (\ a b 0)) _ (pin png-door 0 w) w)))
   (png-rows c o rows n bpp)
    (? (png-nif? 0)
       (: r (png-unfilter c o rows n bpp) (? (string? r) [r 0 n] "bad filter"))
       (: e (png-walk c o rows n bpp) (? (string? e) e [c (o + 1) (n + 1)])))

   ; --- samples --------------------------------------------------------------------------
   ; the j'th sample of the row at d, at its own depth
   (png-sample c d j dep)
    (? (dep = 8) (peep c (d + j) 0)
       (dep = 16) ((peep c (d + 2 * j) 0 << 8) | peep c (d + 2 * j + 1) 0)
       (: k (j * dep) by (peep c (d + (k >> 3)) 0)
          ((by >> ((8 - dep) - (k & 7))) & ((1 << dep) - 1))))
   (png-scale v dep)
    (? (dep = 8) v (dep = 16) (((v * 255) + 32767) // 65535) ((v * 255) // ((1 << dep) - 1)))

   ; one pixel of the row at d -> r g b a pinned at o in out
   (png-pixel c d x hd out o)
    (: ty (hd 'ty) dep (hd 'dep) chs (hd 'chs) trns (hd 'trns)
       (sm k) (png-sample c d ((x * chs) + k) dep)
       (sc v) (png-scale v dep)
       (put r g b a) (: _ (pin out o r) _ (pin out (o + 1) g) _ (pin out (o + 2) b) (pin out (o + 3) a))
       (key k) (rdbe trns (2 * k) 2)
       (ty @ 0 (: v (sm 0) g (sc v)
                  (put g g g (? ((#trns = 2) && (v = key 0)) 0 255)))
            2 (: r (sm 0) g (sm 1) b (sm 2)
                 (put (sc r) (sc g) (sc b)
                      (? ((#trns = 6) && (r = key 0) && (g = key 1) && (b = key 2)) 0 255)))
            3 (: i (sm 0) pl (hd 'plte)
                 (put (peep pl (3 * i) 0) (peep pl (3 * i + 1) 0) (peep pl (3 * i + 2) 0)
                      (? (i < #trns) (trns i) 255)))
            4 (: g (sc (sm 0)) (put g g g (sc (sm 1))))
            (put (sc (sm 0)) (sc (sm 1)) (sc (sm 2)) (sc (sm 3)))))

   ; a row of 8-bit samples with no colour key, the common case, a pixel at a time
   (png-row8 c d pw hd out o step)
    (: ty (hd 'ty) chs (hd 'chs) pl (hd 'plte) trns (hd 'trns)
       (px d o)
        (ty @ 0 (: g (peep c d 0) (pins out o g (o + 1) g (o + 2) g (o + 3) 255))
             2 (pins out o (peep c d 0) (o + 1) (peep c (d + 1) 0) (o + 2) (peep c (d + 2) 0) (o + 3) 255)
             3 (: i (peep c d 0) j (3 * i)
                  (pins out o (peep pl j 0) (o + 1) (peep pl (j + 1) 0) (o + 2) (peep pl (j + 2) 0)
                        (o + 3) (? (i < #trns) (trns i) 255)))
             4 (: g (peep c d 0) (pins out o g (o + 1) g (o + 2) g (o + 3) (peep c (d + 1) 0)))
             (pins out o (peep c d 0) (o + 1) (peep c (d + 1) 0) (o + 2) (peep c (d + 2) 0)
                   (o + 3) (peep c (d + 3) 0)))
       (go x d o) (? (x = pw) 0 (: _ (px d o) (go (x + 1) (d + chs) (o + step))))
       (go 0 d o))

   ; --- the image ------------------------------------------------------------------------
   (png-header ih)
    (: w (rdbe ih 0 4) h (rdbe ih 4 4) dep (ih 8) ty (ih 9)
       chs (ty @ 0 1 2 3 3 1 4 2 6 4 0)
       ok (ty @ 0 (elem dep [1 2 4 8 16]) 3 (elem dep [1 2 4 8]) (elem dep [8 16]))
       (? (#ih != 13) "bad IHDR"
          (!chs || !ok) "bad colour type or depth"
          ((w < 1) || (h < 1)) "empty image"
          ((ih 10 != 0) || (ih 11 != 0) || (ih 12 > 1)) "bad IHDR methods"
          {'w w 'h h 'dep dep 'ty ty 'chs chs 'lace (ih 12)
           'bpp (: b ((chs * dep) // 8) (? (b < 1) 1 b))}))

   ; one pass: unfilter its rows, scatter its pixels -> the offset past it | why not
   (png-pass c o hd out ps)
    (: w (hd 'w) h (hd 'h) x0 (ps 0) y0 (ps 1) dx (ps 2) dy (ps 3)
       pw ((w - x0 + dx - 1) // dx) ph ((h - y0 + dy - 1) // dy)
       n (((pw * hd 'chs * hd 'dep) + 7) // 8)
       fast ((hd 'dep = 8) && ((hd 'ty > 2) || (#(hd 'trns) = 0)))
       (? ((pw < 1) || (ph < 1)) o
          (#c < (o + ph * (n + 1))) "short image data"
          (: r (png-rows c o ph n (hd 'bpp))
             (? (string? r) r
                (: src (r 0) d0 (r 1) st (r 2)
                   (row y) (? (y = ph) (o + ph * (n + 1))
                              (: d (d0 + y * st) at (4 * ((y0 + y * dy) * w + x0))
                                 (col x) (? (x = pw) 0
                                            (: _ (png-pixel src d x hd out (at + 4 * x * dx)) (col (x + 1))))
                                 _ (? fast (png-row8 src d pw hd out at (4 * dx)) (col 0))
                                 (row (y + 1))))
                   (row 0))))))

   (png-decode s)
    (: t (tablet 0) _ (pin t 'idat (jug 0))
       (? ((#s < 8) || (snip s 0 8 != png-sig)) "not a png"
          (: e (png-chunks s 8 t)
             (? (string? e) e
                !(t 'ihdr) "no IHDR"
                (: hd (png-header (t 'ihdr))
                   (? (string? hd) hd
                      (: _ (pin hd 'trns (peep t 'trns ""))
                         _ (pin hd 'plte (peep t 'plte ""))
                         z (slurp (t 'idat))
                         (? ((hd 'ty = 3) && (#(hd 'plte) = 0)) "no palette"
                            ((#z < 2) || (((z 0 * 256) + z 1) % 31 != 0) || ((z 0 & 15) != 8) || (z 1 & 32))
                             "bad zlib header"
                            (: r (gz-inflate (snip z 2 #z) 0)
                               (? !(two? r) "bad deflate stream"
                                  (: raw <>r
                                     ; the nif reads the string, the walk writes a cask
                                     c (? (png-nif? 0) raw (: k (cask #raw) _ (pour k 0 raw 0 #raw) k))
                                     w (hd 'w) h (hd 'h) out (cask (4 * w * h))
                                     passes (? (hd 'lace) png-adam7 [[0 0 1 1]])
                                     (go ps o) (? !ps 0
                                                  (: e (png-pass c o hd out <ps)
                                                     (? (string? e) e (go >ps e))))
                                     e (go passes 0)
                                     (? (string? e) e [w h (string out)])))))))))))))

) ; module png
