; host CLI driver: with file args, load each (after stripping -l flags);
; otherwise read-eval stdin to EOF. Loaded by main.c when argv is non-empty.
(: (load1 p)
   (: q (open p "r")
      (? q ((: (g e q) (: r (fread q e) (? (= e r) 0 (: _ (ev 'ev r) (g e q))))) (gensym 0) q)
           (: _ (fputs err (scat "gl: cannot open " p)) (exit 1)))))
(: (strip-l a)
   (? (& (twop a) (= (A a) "-l"))
      (: _ (load1 (A (B a))) (strip-l (B (B a))))
      a))
(: argv (strip-l argv))
(? (twop argv) (load1 (A argv))
   ((: (g e) (: r (fread in e) (? (= e r) 0 (: _ (ev 'ev r) (g e))))) (gensym 0)))
