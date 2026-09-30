; test/gate/ink.l -- the console's text across a re-made grid, counted on this side.
; two boots of test/kernel/ink.l print the same line onto the same paper; the second re-makes
; the grid at SCALE under that text (/proc/vt/scale). quay draws a glyph pixel as a
; scale-by-scale square and nothing else is on the paper, so the second picture is the first
; with every pixel repeated: exactly scale*scale the ink. a console that dropped its text on
; the re-make answers a bare cursor block instead, which is no multiple of the first.
; usage: love test/gate/ink.l SCALE PLAIN.ppm SCALED.ppm
(borrow 'kore)
(: as >argv
   k (uatoi <as)
   (past s i n) (3 <= n ? i (past s (i + 1) (n + (s i = 10))))  ; P6, the size, the depth
   (ink p) (uread p @ r (two? r ? (<>r @ s (net (snip s (past s 0 0) #s))) 0))
   a (ink <>as)
   b (ink <>>as)
   want (k * k * a)
   bad (? (a < 1) (<>as + ": no ink at all")
          (b != want) ("the re-made grid holds " + show b + " ink, wanted " + show want)
          ())
   (puts (0 < #bad ? ("FAIL ink: " + bad + "\n")
                            ("  ink: ok -- " + show a + " on the paper, and the same text at " + show want + " once the grid was re-made\n")),
    quit (0 < #bad ? 1 0)))
