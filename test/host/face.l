; --- test/host/face.l: apps/face.l's faces, and quay's own reading of them ---
; love lays a face off .hex text; the painter reads it in C (love/quay/quay.c's cb_face_ok
; and cb_face_rows, through the `facerow` nif). the two must read every row the same, and
; C must refuse a face that is not one rather than index past it.
;
;   cat test/00-init.l test/host/face.l | out/love      ; exits 1 on fail, prints face: ok
(borrow "apps/face.l")
(: (hexrow v d) (: h (radix v 16) (zpad d h))           ; v as d hex digits
   (glyph cp d f) ((zpad 4 (radix cp 16)) + ":" + cats (map (\ r (hexrow (f r) d)) (jot 16)))
   ; A: narrow, row r holds r; 世 wide and solid; 丗 wide, row r holds r in both bytes;
   ; Ā narrow and solid; ā narrow, its leftmost pixel; U+0301 narrow, its rightmost. a comment, a blank and a short line are no glyphs
   hex (cats (map (\ l (l + "\n"))
         [(glyph 65 2 (\ r r)) (glyph 19990 4 (\ r 65535)) (glyph 19991 4 (\ r (r * 257)))
          (glyph 256 2 (\ r 255)) (glyph 257 2 (\ r 128)) (glyph 769 2 (\ r 1))
          "# not a glyph" "" "0042:00FF"]))
   f (face-hex hex)
   rows (\ cp (face-rows f cp))

; --- love's reading: a narrow glyph's row sits in the high byte ---
   _ (test
      (string? f)
      ((map (\ r (r << 8)) (jot 16)) = rows 65)
      ((map (\ r 65535) (jot 16)) = rows 19990)
      ((map (\ r (r * 257)) (jot 16)) = rows 19991)
      ((map (\ r 65280) (jot 16)) = rows 256)
      !(rows 66)                                  ; the short line laid nothing
      !(rows 67)                                  ; nor was there a C
      !(rows 1114112)                             ; past unicode
      !(face-hex "no glyphs here\n"))

; --- C's reading, row for row ---
   (same? cp) (foldl (\ a r (&& a (facerow f cp r = (rows cp) r))) 1 (jot 16))
   _ (test
      (same? 65) (same? 19990) (same? 19991) (same? 256)
      !(facerow f 66 0)                           ; a code point the face lacks
      !(facerow f 65 16))                         ; a row past the glyph

; --- C refuses what is no face: short, long, a bad magic, a page or glyph index past the
;     tables. each answers () where the whole face answered a row ---
   (poke s i v) ((snip s 0 i) + string v + (snip s (i + 1) (tally s)))
   _ (test
      !(facerow (snip f 0 (tally f - 1)) 65 0)
      !(facerow (f + "x") 65 0)
      !(facerow (poke f 0 81) 65 0)               ; "Qf1"
      !(facerow (poke f 5 8) 65 0)                ; an 8x8 cell
      !(facerow (poke f (12 + 2) 200) 65 0)       ; page 0's directory word names page 200
      !(facerow (poke f (8716 + (2 * 65)) 250) 65 0))   ; A's glyph index past the glyphs

; --- the painter lays a cluster's marks over its base: ā then 丗, each with U+0301. the
;     mark keeps its place over a narrow base and moves half a cell right over a wide one ---
   sc (screen (cask (screen () 1 4)) 1 4)
   _ (scribe sc "\u{101}\u{301}\u{4e17}\u{301}")
   px (cask (4 * 32 * 16))
   _ (dye sc px 32 0 -1 f)
   pb (snip px 0 (tally px))                   ; the pixels, as a string
   (lit y x) (: i (4 * (y * 32 + x)) (0 < (pb i + pb (i + 1) + pb (i + 2))))
   (lits y) (filter (lit y) (jot 32))
   _ (test
      ([0 7 19] = lits 0)                         ; ā, the mark, 丗's row 0 empty but for it
      ([0 7 15 19 23] = lits 1))                  ; 丗's row 1 is 0101
   _ (test_fin ())
   (puts "face: ok\n"))
