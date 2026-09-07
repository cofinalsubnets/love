; tools/mkfont.l -- the web faces from the quay bitmaps. a C array of 256 glyph rows
; becomes a TrueType font whose outlines are pixel rectangles, one contour per lit run,
; wrapped as WOFF with each table a zlib stream over gz-deflate. a cell's codepoint
; rides its row's comment, // [X] (n), so cp437 -> unicode needs no table of its own.
;   love tools/mkfont.l SRC.c BASELINE OUT.woff FAMILY
; BASELINE is the pixel row the glyphs sit on: 12 on the 8x16 face, 6 on the 8x8.
(use 'gz)
(: upem 1024
   (be16 n) (: v (n < 0 ? (n + 65536) n) [((v >> 8) & 255) (v & 255)])
   (be32 n) (: v (n < 0 ? (n + 4294967296) n) [((v >> 24) & 255) ((v >> 16) & 255) ((v >> 8) & 255) (v & 255)])
   (bytes s) (map (i \ s i) ^#s)
   (u16 s) (foldl (\ a c (a + [0 c])) () (bytes s))              ; ascii -> utf-16be
   (zeros n) (map (\ _ 0) ^n)
   (pad4 bs) (: r (#bs % 4) (r ? (bs + zeros (4 - r)) bs))
   (cat l) (foldl (\ a x (a + x)) () l)
   (hexd c) (? (c <= 57) (c - 48) (c <= 70) (c - 55) (c - 87))
   (hexv s) (foldl (\ a i (a * 16 + hexd (s i))) 0 (drop 2 ^#s))   ; "0x7e" -> 126
   (utf8 s) (: b (s 0)                                              ; the first char's codepoint
             (? (b < 128) b
                (b < 224) (((b & 31) << 6) | (s 1 & 63))
                (b < 240) (((b & 15) << 12) | ((s 1 & 63) << 6) | (s 2 & 63))
                (((b & 7) << 18) | ((s 1 & 63) << 12) | ((s 2 & 63) << 6) | (s 3 & 63))))
   (lo l) (foldl (\ a x (x < a ? x a)) 999999 l)
   (hi l) (foldl (\ a x (a < x ? x a)) -999999 l)
   (sum32 bs) (: (go l a) (? (two? l) (go (drop 4 l) ((a + ((l 0) << 24) + ((l 1) << 16) + ((l 2) << 8) + l 3) & 4294967295)) a)
                 (go (pad4 bs) 0))
   (adler bs) (: r (foldl (\ st x (: a ((<st + x) % 65521) [a ((<>st + a) % 65521)])) [1 0] bs) ((<>r << 16) | <r))
   (zlib bs) ([120 156] + bytes (gz-deflate (string (cask bs))) + be32 (adler bs))
   ; --- the source: one [codepoint rows] per cell, in cell order ---------------------
   (cell line) (: ps (split "{" line)
                  (? ((! (two? >ps)) || (! (two? >(split "// [" line)))) ()
                     (: rows (map (p \ hexv <(words p)) (split "," <(split "}" (ps 1))))
                        cs (<(split "] (" ((split "// [" line) 1)))
                        [(utf8 cs) rows])))
   (cells src) (filter two? (map cell (lines src)))
   ; --- outlines: a row's lit runs as [c0 c1), a run as a clockwise rectangle -------
   (runs w) (: (go c st acc)
               (? (c = 8) (st < 0 ? acc (acc + [[st 8]]))
                  (: lit ((w >> (7 - c)) & 1)
                     (? (lit && (st < 0)) (go (c + 1) c acc)
                        ((! lit) && (0 <= st)) (go (c + 1) -1 (acc + [[st c]]))
                        (go (c + 1) st acc))))
               (go 0 -1 ()))
   (rects rows b px) (: (go r l acc)
                        (? (two? l) (go (r + 1) >l (acc + map (u \ [(<u * px) ((b - r - 1) * px) (<>u * px) ((b - r) * px)]) (runs <l)))
                           acc)
                        (go 0 rows ()))
   (deltas l) (<>(foldl (\ st x [x (<>st + be16 (x - <st))]) [0 ()] l))
   (glyph rs) (? (! (two? rs)) ()
                 (: pts (cat (map (r \ [[<r <>r] [<r (r 3)] [(r 2) (r 3)] [(r 2) <>r]]) rs))
                    xs (map cap pts)  ys (map (p \ <>p) pts)
                    (pad4 (be16 #rs + be16 (lo xs) + be16 (lo ys) + be16 (hi xs) + be16 (hi ys)
                           + cat (map (i \ be16 (i * 4 + 3)) ^#rs) + be16 0
                           + map (\ _ 1) pts + deltas xs + deltas ys))))
   ; --- the tables ---------------------------------------------------------------------
   stamp (be32 0 + be32 3849984000)                                  ; created/modified: 2026, a fixed date so the bytes are reproducible
   (font cs b fam) (: rows #(<>(<cs))  px (upem // rows)  adv (8 * px)
                      asc (b * px)  desc ((rows - b) * px)
                      gs (() . map (c \ glyph (rects <>c b px)) cs)          ; glyph 0 is .notdef, empty
                      ng #gs
                      glyf (cat gs)
                      loca ((<>(foldl (\ st g [(<st + #g) (<>st + be32 <st)]) [0 ()] gs)) + be32 #glyf)
                      hmtx (cat (map (g \ be16 adv + be16 (two? g ? (((g 12) << 8) | (g 13)) 0)) gs))   ; lsb = xMin, at glyph byte 2
                      npts (hi (map (g \ two? g ? (2 * (((g 0) << 8) | (g 1))) 0) gs))   ; contours*2 = points/2, so 4x contours
                      maps (: mp (foldl (\ a i (: c (cs i) cp (i = 255 ? 160 <c) (? (i = 0) a (a + [[cp (i + 1)]])))) () ^#cs)
                              (sort mp))
                      cmap (: n (#maps + 1)  p ((: (go p) (? ((p * 2) <= n) (go (p * 2)) p)) 1)
                              es ((: (go p k) (? (p < 2) k (go (p // 2) (k + 1)))) p 0)
                              sr (2 * p)  rs ((2 * n) - sr)
                              ends ((cat (map (mp \ be16 <mp) maps)) + be16 65535)
                              starts ((cat (map (mp \ be16 <mp) maps)) + be16 65535)
                              dl ((cat (map (mp \ be16 (<>mp - <mp)) maps)) + be16 1)
                              sub (be16 4 + be16 (16 + (8 * n)) + be16 0 + be16 (2 * n) + be16 sr + be16 es + be16 rs
                                   + ends + be16 0 + starts + dl + zeros (2 * n))
                              (be16 0 + be16 2 + be16 0 + be16 3 + be32 20 + be16 3 + be16 1 + be32 20 + sub))
                      head (be32 65536 + be32 65536 + be32 0 + be32 1594834165 + be16 11 + be16 upem + stamp + stamp
                            + be16 0 + be16 (0 - desc) + be16 adv + be16 asc + be16 0 + be16 rows + be16 2 + be16 1 + be16 0)
                      hhea (be32 65536 + be16 asc + be16 (0 - desc) + be16 0 + be16 adv + be16 0 + be16 0 + be16 adv
                            + be16 1 + be16 0 + be16 0 + zeros 8 + be16 0 + be16 ng)
                      maxp (be32 65536 + be16 ng + be16 (2 * npts) + be16 (npts // 2) + be16 0 + be16 0 + be16 2 + zeros 16)
                      os2 (be16 4 + be16 adv + be16 400 + be16 5 + be16 0
                           + be16 (5 * px) + be16 (5 * px) + be16 0 + be16 (2 * px) + be16 (5 * px) + be16 (5 * px) + be16 0 + be16 (6 * px)
                           + be16 px + be16 (4 * px) + be16 0 + [2 0 5 9 0 0 0 0 0 0] + be32 3 + be32 0 + be32 0 + be32 0
                           + bytes "love" + be16 192 + be16 (lo (map cap maps)) + be16 (hi (map cap maps))
                           + be16 asc + be16 (0 - desc) + be16 0 + be16 asc + be16 desc + be32 2147483649 + be32 0
                           + be16 (5 * px) + be16 (7 * px) + be16 0 + be16 32 + be16 0)
                      ps (foldl (\ a c (c = 32 ? a (a + string (cask [c])))) "" (bytes fam))   ; the postscript name: no spaces
                      ns [[0 "generated from core/quay by tools/mkfont.l"] [1 fam] [2 "Regular"] [3 (fam + " 1.0")] [4 fam] [5 "Version 1.0"] [6 ps]]
                      name (: strs (map (r \ u16 <>r) ns)
                              recs (<>(foldl (\ st s [(<st + #s) (<>st + [<st #s])]) [0 ()] strs))   ; [offset len] per string
                              (be16 0 + be16 #ns + be16 (6 + (12 * #ns))
                               + cat (map (i \ be16 3 + be16 1 + be16 1033 + be16 <(ns i) + be16 <>(recs i) + be16 <(recs i)) ^#ns)
                               + cat strs))
                      post (be32 196608 + be32 0 + be16 (0 - px) + be16 px + be32 1 + zeros 16)
                      [["OS/2" os2] ["cmap" cmap] ["glyf" glyf] ["head" head] ["hhea" hhea]
                       ["hmtx" hmtx] ["loca" loca] ["maxp" maxp] ["name" name] ["post" post]])
   ; --- the containers: checksums over the sfnt, then the woff wrap -------------------
   (woff tabs) (: nt #tabs
                  sums (map (t \ sum32 <>t) tabs)
                  offs (<>(foldl (\ st t [(<st + #(pad4 <>t)) (<>st + [<st])]) [(12 + (16 * nt)) ()] tabs))
                  dir (cat (map (i \ bytes <(tabs i) + be32 (sums i) + be32 (offs i) + be32 #<>(tabs i)) ^nt))
                  sfnt (be32 65536 + be16 nt + be16 128 + be16 3 + be16 32 + dir + cat (map (t \ pad4 <>t) tabs))
                  adj ((2981146554 - sum32 sfnt) & 4294967295)
                  fixed (map (t \ (<t = "head") ? [<t (take 8 <>t + be32 adj + drop 12 <>t)] t) tabs)
                  comps (map (t \ (: z (zlib <>t) (#z < #<>t ? z <>t))) fixed)
                  woffs (<>(foldl (\ st c [(<st + #(pad4 c)) (<>st + [<st])]) [(44 + (20 * nt)) ()] comps))
                  total (foldl (\ a c (a + #(pad4 c))) (44 + (20 * nt)) comps)
                  sfntsz (foldl (\ a t (a + #(pad4 <>t))) (12 + (16 * nt)) tabs)
                  (bytes "wOFF" + be32 65536 + be32 total + be16 nt + be16 0 + be32 sfntsz + be16 1 + be16 0 + zeros 20
                   + cat (map (i \ bytes <(tabs i) + be32 (woffs i) + be32 #(comps i) + be32 #<>(tabs i) + be32 (sums i)) ^nt)
                   + cat (map pad4 comps)))
   (main args) (: src (: q (open (args 0) "r") s (slurp q) _ (close q) s)
                  b (foldl (\ a c (a * 10 + c - 48)) 0 (bytes (args 1)))
                  out (woff (font (cells src) b (args 3)))
                  q (open (args 2) "w")
                  (? q (: _ (say q (cask out)) _ (close q) (say err ("mkfont: " + args 2 + " " + show #out + " bytes\n")))
                     (: _ (say err ("mkfont: cannot open " + args 2 + "\n")) (quit 1))))
   (main >argv))
