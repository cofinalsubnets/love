; src/apps/font.l -- a bitmap font for quay's painter, laid from unifont's .hex.
;
;   (font-hex s)        the font a .hex text makes, as the bytes src/love/quay/quay.h's
;                       struct cb_font reads; () when s holds no glyph
;   (font-rows f cp)    cp's glyph in font f: its 16 rows, each a 16-bit word with the
;                       leftmost pixel high, or () when the font lacks it
;
; a .hex line is `XXXX:bits`: the code point, then 32 hex digits for an 8x16 glyph or 64
; for a 16x16 one, a row at a time. unifont ships its whole plane this way; the file is not
; in the image. on inle the console takes a font written to /proc/vt/font. a glyph index is
; a u16, so a font holds at most 65535 glyphs: unifont's plane 0 fits, not with its upper.
;
; the bytes, little-endian, all u16 unless said:
;   "qf1\0"  magic;  w h (bytes: the half-width cell, 8 16);  npages;  nglyphs (u32)
;   dir[4352]            code point >> 8 -> its page, 0xffff for none
;   pages[npages][256]   code point & 255 -> glyph + 1, 0 for none
;   glyphs[nglyphs][16]  the rows, a narrow glyph in each word's high byte
(module '(font font-hex font-rows)
(:
   (le16 v) (string (v & 255) + string (v >> 8 & 255))
   (le32 v) (le16 (v & 65535) + le16 (v >> 16 & 65535))
   (rd16 f i) (f i | f (i + 1) << 8)
   (hexn s a b) (foldl (n \ i \ n * 16 + hexv (s i)) 0 (map (+ a) ^(b - a)))

   ; one line: (cp rows) or () -- rows the 16 words; a narrow glyph's byte shifts high
   (font-line l)
    (: k (findsub l ":")
       n (#l - k - 1)
       (k < 1 || !(n = 32 || n = 64) ? ()
          (: cp (hexn l 0 k)
             d (n // 16)                                  ; hex digits a row: 2 or 4
             rows (map (r \ (: a (k + 1 + r * d)
                              v (hexn l a (a + d))
                              (d = 2 ? (v << 8) v)))
                       ^16)
             [cp rows])))

   (font-hex s)
    (sort (filter two? (map font-line (lines s))) @ gs ; by code point
       (!(two? gs) ? ()
          (: pages (uniq (map (g \ <g >> 8) gs))
             slot {}
             _ (foldl (i \ p \ (pin slot p i, i + 1)) 0 pages)
             idx {}
             _ (foldl (i \ g \ (pin idx <g i, i + 1)) 1 gs)
             dir (cats (map (p \ le16 (peep slot p 65535)) ^4352))
             pgs (cats (map (p \ cats (map (lo \ le16 (peep idx (p << 8 | lo) 0)) ^256))
                            pages))
             bits (cats (map (g \ cats (map le16 <>g)) gs))
             ("qf1" + string 0 + string 8 + string 16 + le16 #pages + le32 #gs
              + dir + pgs + bits))))

   (font-rows f cp)
    (: np (rd16 f 6)
       pg (cp < 1114112 ? (rd16 f (12 + 2 * (cp >> 8))) 65535)
       (pg @ 65535 ()
        (rd16 f (8716 + pg * 512 + 2 * (cp & 255)) @ 0 ()
         gi (8716 + np * 512 + (gi - 1) * 32 @ at
             (map (r \ rd16 f (at + 2 * r)) ^16)))))
)
) ; module font
