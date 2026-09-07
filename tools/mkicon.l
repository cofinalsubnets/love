; tools/mkicon.l -- the favicon from a quay bitmap: one 8x8 glyph, each pixel a square,
; centred on a transparent canvas, as a PNG (one IDAT, a zlib stream over gz-deflate).
;   love tools/mkicon.l SRC.c GLYPH SIZE OUT.png
; GLYPH is the cell's index (cp437: 3 is the heart), SIZE the canvas in pixels; the
; scale is the largest whole number of pixels per glyph pixel that fits, so the glyph
; lands crisp. the ink is config.l's tokyo-night `red`, the colour the front page wears.
(use "apps/vi/config.l")
(use 'gz)

(: (be32 n) [((n >> 24) & 255) ((n >> 16) & 255) ((n >> 8) & 255) (n & 255)]
   (bytes s) (map (i \ s i) ^#s)
   (cat l)   (foldl (+) () l)
   (num s)   (foldl (\ a c (a * 10 + c - 48)) 0 (bytes s))
   (hexd c)  (? (c <= 57) (c - 48) (c <= 70) (c - 55) (c - 87))
   (hexv s)  (foldl (\ a i (a * 16 + hexd (s i))) 0 (drop 2 ^#s))    ; "0x7e" -> 126
   ; --- the source: one row list per cell, in cell order (mkfont.l's reading) ------
   (cell line) (: ps (split "{" line)
                  (? ((! (two? >ps)) || (! (two? >(split "// [" line)))) ()
                     (map (p \ hexv <(words p)) (split "," <(split "}" (ps 1))))))
   (cells src) (filter two? (map cell (lines src)))
   ; --- the ink: the palette's red, "#rrggbb" -> (r g b) ----------------------------
   (row nm l) (? (atom? l) () (= <<l nm) <l (row nm >l))
   ink (: pal (row 'tokyo-night (from 'vi 'hue-page))
          hex (? (two? pal) (<>(row 'red (pal 1))) "")
          (? (= #hex 7) (map (i \ hexv ("0x" + snip hex (1 + 2 * i) (3 + 2 * i))) ^3)
             (: _ (say err "mkicon: no tokyo-night red in config.l\n") (quit 1))))
   ; --- the raster: lit? asks the glyph, the canvas asks lit? through scale and margin
   (lit? rows y x) ((0 <= y) && (y < 8) && (0 <= x) && (x < 8) && (((rows y) >> (7 - x)) & 1))
   (bbox rows) (: ps (filter (p \ lit? rows <p <>p) (cat (map (y \ map (x \ [y x]) ^8) ^8)))
                  (? !(two? ps) (: _ (say err "mkicon: an empty glyph\n") (quit 1))
                     (: ys (map (p \ <p) ps) xs (map (p \ <>p) ps)
                        (lo l) (foldl (\ a b (a < b ? a b)) <l l) (hi l) (foldl (\ a b (a < b ? b a)) <l l)
                        [(lo ys) (lo xs) (1 + hi ys) (1 + hi xs)])))            ; [y0 x0 y1 x1)
   (raster rows sz)
   (: b (bbox rows)
      h ((b 2) - (b 0)) w ((b 3) - (b 1))
      s (sz // (h < w ? w h))                                           ; pixels per glyph pixel
      my ((sz - h * s) // 2) mx ((sz - w * s) // 2)
      (px y x) (lit? rows ((y - my) // s + (b 0)) ((x - mx) // s + (b 1)) ? (ink + [255]) [0 0 0 0])
      ; each scanline led by its filter byte, 0: none
      (cat (map (y \ 0 . (? ((y < my) || (y >= my + h * s)) (cat (map (_ \ [0 0 0 0]) ^sz))
                             (cat (map (x \ (? ((x < mx) || (x >= mx + w * s)) [0 0 0 0] (px y x))) ^sz))))
                ^sz)))
   ; --- the file ---------------------------------------------------------------------
   (chunk ty d) (: body (bytes ty + d) (be32 #d + body + be32 (gz-crc32 (string (cask body)))))
   (adler bs) (: r (foldl (\ st x (: a ((<st + x) % 65521) [a ((<>st + a) % 65521)])) [1 0] bs) ((<>r << 16) | <r))
   (zlib bs)  ([120 156] + bytes (gz-deflate (string (cask bs))) + be32 (adler bs))
   (png sz pix) ([137 80 78 71 13 10 26 10]
                 + chunk "IHDR" (be32 sz + be32 sz + [8 6 0 0 0])
                 + chunk "IDAT" (zlib pix)
                 + chunk "IEND" ())
   (main args) (: src (: q (open (args 0) "r") s (slurp q) _ (close q) s)
                  rows ((cells src) (num (args 1)))
                  sz (num (args 2))
                  out (png sz (raster rows sz))
                  q (open (args 3) "w")
                  (? (hot? q) (: _ (say q (cask out)) _ (close q) (say err ("mkicon: " + args 3 + " " + show #out + " bytes\n")))
                     (: _ (say err ("mkicon: cannot open " + args 3 + "\n")) (quit 1))))
   (main >argv))
