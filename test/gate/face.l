; test/gate/face.l -- a loaded face's glyphs, counted on this side. two boots of
; test/kernel/face.l print 世 and Ā onto the same paper, the first with both solid in the
; face, the second with both empty; nothing else differs. so the first picture holds
; exactly 16x16 + 8x16 more lit pixels, each the console's white (765 a pixel, the three
; channels summed). a painter that drew a wide glyph one cell wide, or took the ■ over the
; face, answers another count.
; usage: love test/gate/face.l FULL.ppm EMPTY.ppm
(borrow 'kore)
(: as >argv
   (past s i n) (? (3 <= n) i (past s (i + 1) (n + (s i = 10))))  ; P6, the size, the depth
   (ink p) (: r (uread p) (? (two? r) (: s <>r (net (snip s (past s 0 0) (tally s)))) 0))
   a (ink (cap as))
   b (ink (cap >as))
   want (765 * (256 + 128))
   bad (? (a < 1) ((cap as) + ": no ink at all")
          ((a - b) != want) ("the face's glyphs lit " + (show (a - b)) + ", wanted " + (show want))
          ())
   _ (puts (0 < (tally bad) ? ("FAIL face: " + bad + "\n")
                              "  face: ok -- 世 two cells wide and Ā one, both off the loaded face\n"))
   (quit (0 < (tally bad) ? 1 0)))
