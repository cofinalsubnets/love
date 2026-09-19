; test/kernel/ink.l -- the console's text across a re-made grid, left on the paper for the
; seat outside to count. the cursor goes first: a blinking cell is ink and its phase is the
; clock's, so the count would be a coin flip. then a known line, then -- where the line
; names a glyph scale -- a new grid under that same text, through /proc/vt/scale (kmain's
; k_vt_rescale). the same glyphs at twice the scale are four times the ink, which is
; the law test/gate/ink.l reads back. the rest outlives one dump (cpu.mjs, once a second).
(: (fin l) (? (two? >l) (fin >l) <l)      ; the last word: the two seats spell argv differently
   s (fin argv)
   scale (? (0 < #s && 47 < (s 0) && (s 0) < 58) s ())
   _ (puts $ (string 27) + "[?25l" + "ink carries over\n")
   _ (? scale
        (: q (open "/proc/vt/scale" "w")
           (? (hot? q) (say q scale, close q) (puts "ink: no /proc/vt/scale\n")))
        ())
   (rest 2000))
