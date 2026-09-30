; test/gate/lit.l -- two pictures of the console that differ only in what one test lit,
; counted on this side. the second boot prints the same thing unlit (an empty glyph, a black
; picture), so the first holds exactly WANT more lit pixels, each the console's white (765 a
; pixel, the three channels summed). a painter that drew the wrong width, took the wrong
; source, or dropped the thing, answers another count.
; usage: love test/gate/lit.l NAME WANT LIT.ppm UNLIT.ppm
(borrow 'kore)
(: as >argv
   name <as
   want (765 * uatoi <>as)
   (past s i n) (3 <= n ? i (past s (i + 1) (n + (s i = 10))))  ; P6, the size, the depth
   (ink p) (uread p @ r (two? r ? (<>r @ s (net (snip s (past s 0 0) #s))) 0))
   a (ink <>>as)
   b (ink <>>>as)
   bad (? (a < 1) (<>>as + ": no ink at all")
          (a - b != want) ("lit " + show (a - b) + ", wanted " + show want)
          ())
   (puts (0 < #bad ? ("FAIL " + name + ": " + bad + "\n")
                            ("  " + name + ": ok -- " + show (want // 765) + " pixels lit, exactly\n")),
    quit (0 < #bad ? 1 0)))
