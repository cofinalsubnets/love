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
  (test_fin (), puts "glazehot: ok\n"))
