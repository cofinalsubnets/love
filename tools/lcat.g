(: (cesc s)
   ((: (loop i n)
       (? (< i n)
          (: c (get 0 i s)
             _ (? (= c 10) (fputs out "\\n")
                  (? (| (= c 92) (= c 34)) (: _ (fputc out 92) (fputc out c))
                     (fputc out c)))
             (loop (+ i 1) n))
          0))
    0 (len s)))

(: p (open (A (B argv)) "r")
   _ (? p 0 (: _ (fputs err "lcat: cannot open input") (exit 1)))
   _ (fputc out 34)                  ; opening "
   _ ((: (g first e p)               ; print each form, space-separated
         (: r (fread p e)
            (? (= e r) 0
               (: _ (? first (fputs out " ") 0)
                  _ (cesc (inspect r))
                  (g -1 e p)))))
      0 (gensym 0) p)
   _ (fputc out 34)                  ; closing "
   (fputc out 10))
