; test/gate/lit.l -- two pictures of the console that differ only in what one test lit,
; counted on this side. the second boot prints the same thing unlit (an empty glyph, a black
; picture), so the first holds exactly WANT more lit pixels, each the console's white (765 a
; pixel, the three channels summed). a painter that drew the wrong width, took the wrong
; source, or dropped the thing, answers another count.
; usage: love test/gate/lit.l NAME WANT LIT.ppm UNLIT.ppm
(borrow 'kore)
(: as >argv
   name (cap as)
   want (765 * uatoi (cap >as))
   (past s i n) (? (3 <= n) i (past s (i + 1) (n + (s i = 10))))  ; P6, the size, the depth
   (ink p) (: r (uread p) (? (two? r) (: s <>r (net (snip s (past s 0 0) (tally s)))) 0))
   a (ink (cap >>as))
   b (ink (cap >>>as))
   bad (? (a < 1) ((cap >>as) + ": no ink at all")
          ((a - b) != want) ("lit " + (show (a - b)) + ", wanted " + (show want))
          ())
   _ (puts (0 < (tally bad) ? ("FAIL " + name + ": " + bad + "\n")
                              ("  " + name + ": ok -- " + (show (want // 765)) + " pixels lit, exactly\n")))
   (quit (0 < (tally bad) ? 1 0)))
