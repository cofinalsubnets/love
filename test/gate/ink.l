; test/gate/ink.l -- the console's text across a re-made grid, counted on this side.
; two boots of test/kernel/ink.l print the same line onto the same paper; the second re-makes
; the grid at SCALE under that text (/proc/vt/scale). quay draws a glyph pixel as a
; scale-by-scale square and nothing else is on the paper, so the second picture is the first
; with every pixel repeated: exactly scale*scale the ink. a console that dropped its text on
; the re-make answers a bare cursor block instead, which is no multiple of the first.
; usage: love test/gate/ink.l SCALE PLAIN.ppm SCALED.ppm
(borrow 'kore)
(: as >argv
   k (uatoi (cap as))
   (past s i n) (? (3 <= n) i (past s (i + 1) (n + (s i = 10))))  ; P6, the size, the depth
   (ink p) (: r (uread p) (? (two? r) (: s <>r (net (snip s (past s 0 0) (tally s)))) 0))
   a (ink (cap >as))
   b (ink (cap >>as))
   want ((k * k) * a)
   bad (? (a < 1) ((cap >as) + ": no ink at all")
          (b != want) ("the re-made grid holds " + (show b) + " ink, wanted " + (show want))
          ())
   _ (puts (0 < (tally bad) ? ("FAIL ink: " + bad + "\n")
                              ("  ink: ok -- " + (show a) + " on the paper, and the same text at " + (show want) + " once the grid was re-made\n")))
   (quit (0 < (tally bad) ? 1 0)))
