; host CLI driver: with file args, load each (after stripping -l flags);
; otherwise read-eval stdin to EOF. Loaded by main.c when argv is non-empty.
(: (load1 p)
   (: q (open p "r")
      (? q ((: (g e q) (: r (read q e) (? (= e r) 0 (: _ (ev 'ev r) (g e q))))) (mint 0) q)
           (: _ (fputs err (+ "love: cannot open " p)) (exit 1)))))
(: (strip-l a)
   (? (& (twop a) (= (cap a) "-l"))
      (: _ (load1 (cap (cbp a))) (strip-l (cbp (cbp a))))
      a))
(: argv (strip-l (cbp argv)))   ; drop the program-name head: main.c now passes the whole argv (cmdline keeps it)
(? (twop argv) (load1 (cap argv))
   ((: (g e) (: r (read in e) (? (= e r) 0 (: _ (ev 'ev r) (g e))))) (mint 0)))
