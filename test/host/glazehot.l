; test/host/glazehot.l -- a closure made past the bake keeps its twin until its call past glaze.l's
; hot-calls (1024), then compiles (tablet.c's hotcell); LOVE_GLAZE_HOT=eager compiles it when made.
; the answers are the same either way
;   cat test/00-init.l test/host/glazehot.l | out/love
(: glh-q "((: (f x) (x * x + 1)), (: a0 (peep fires () 0) s (net (map f ^1024)) a1 (peep fires () 0) v (f 3) a2 (peep fires () 0) (putx [(a1 - a0) (a2 - a1) s v])), (quit 0))"
   glh-d (hark ["env" "LOVE_GLAZE_HOT=" "out/love" "-e" glh-q])
   glh-e (hark ["env" "LOVE_GLAZE_HOT=eager" "out/love" "-e" glh-q])
   _ (test (two? glh-d) (<glh-d = 0) (>glh-d = "(0 1 357390848 10)")
           (two? glh-e) (<glh-e = 0) (>glh-e = "(0 0 357390848 10)"))
   ; canon reads the globals before anything compiles: an egg boot past every threshold still
   ; spells a spliced op value as its word, or autogroup's lowering misses
   glh-c (hark ["env" "LOVE_GLAZE_HOT=1000000000" "LOVE_NO_IMAGE=1" "out/love" "-e"
                "((putx [(nom? <((cite 'glaze 'canon) [tally 's])) (peep fires () 0)]), (quit 0))"])
   _ (test (two? glh-c) (<glh-c = 0) (>glh-c = "(1 0)"))
   ; a late compile reads the names as the twin folded them, and no lane takes a rebound word
   glb "book (6 8 15 24 9 8 8) (6 9 15 24 9 9 9)\nword (1000 1000 (mine 7) (1 mine 7))\n"
   (glr v) (hark ["env" v "out/love" "test/host/glazebook.l"])
   _ (test (all (v \ (glr v @ r (two? r && <r = 0 && >r = glb)))
                '("LOVE_NO_GLAZE=1" "LOVE_GLAZE_HOT=" "LOVE_GLAZE_HOT=2" "LOVE_GLAZE_HOT=eager" "LOVE_LAZY_GLAZE=1")))
   ; a hot cell in a saved image keeps its names past a rebinding in the woken session
   glm (show (getpid 0))  gli ("out/.glazehot-" + glm + ".image")  gls ("out/.glazehot-" + glm + ".l")
   (glw x) (open gls "w" @ p (say p x, close p))
   _ (glw ("(: (zork a b) (a 0 * b 0))(: (f a b) (zork (a 0) b - a 1))" +
           "(: (spin i) (i = 0 ? 0 (f [[2 3] 4] [5 6], spin (i - 1))))(spin 500)(cite 'image 'bake \"" + gli + "\")(quit 0)"))
   gl1 (hark ["env" "LOVE_GLAZE_HOT=" "out/love" gls])
   _ (glw ("(: (zork a b) 99)(: (spin2 i) (i = 0 ? 0 (f [[2 3] 4] [5 6], spin2 (i - 1))))" +
           "(spin2 2000)(putn (f [[2 3] 4] [5 6]))(quit 0)"))
   gl2 (hark ["env" "LOVE_GLAZE_HOT=" "out/love" "wake" gli gls])
   _ (unlink gli)  _ (unlink gls)
   _ (test (two? gl1) (<gl1 = 0) (two? gl2) (<gl2 = 0) (>gl2 = "6"))
  (test_fin (), puts "glazehot: ok\n"))
