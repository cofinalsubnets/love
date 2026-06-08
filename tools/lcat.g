; lcat: serialize a gwen source file to a C string literal for #include (the lcat
; lib headers the final gl is assembled from). Each top-level form is re-printed
; via inspect (canonical), the forms are joined into one string, and that string is
; MINIFIED -- a space is dropped wherever removing it does not change how the reader
; tokenizes. The boundary test is empirical, not a hardcoded delimiter set: the two
; bytes flanking the space are concatenated with and without it and re-parsed; if
; both spellings yield the same number of complete datums the space was redundant
; (e.g. `o(` reads the same as `o (`, but `-5` and `- 5` do not). Spaces inside a
; string literal are data and never touched. Surviving bytes are then C-escaped.

(: (s2cl s) ((: (g i) (? (< i (len s)) (X (get 0 i s) (g (+ 1 i))))) 0)  ; string -> charlist
   ; count complete datums readable from s (stop on the eof sentinel or an
   ; incomplete form, which fread signals by returning the port itself).
   (nforms s) ((: (g p e n) (: r (fread p e) (? (| (= e r) (= p r)) n (g p e (+ 1 n)))))
               (strin (s2cl s)) (gensym 0) 0)
   ; bytes a then b: is the space between them redundant? (same datum count joined vs spaced)
   (redundant? a b) (= (nforms (string (L a b))) (nforms (string (L a 32 b))))
   ; emit one byte to out, C-escaped for the string literal.
   (eb c) (? (= c 10) (fputs out "\\n")
              (| (= c 92) (= c 34)) (: _ (fputc out 92) (fputc out c))
              (fputc out c)))

(: p (open (A (B argv)) "r")
   _ (? p 0 (: _ (fputs err "lcat: cannot open input") (exit 1)))
   ; gather every canonical form into one space-joined string
   acc ((: (g acc e p first)
          (: r (fread p e)
             (? (= e r) acc
                (g (? first (inspect r) (scat (scat acc " ") (inspect r))) e p 0))))
        "" (gensym 0) p 1)
   _ (fputc out 34)                                      ; opening "
   ; walk acc: drop redundant spaces (outside string literals), C-escape the rest.
   ; pc = previous emitted byte; instr = inside a "..." literal (where \ escapes).
   _ ((: (g i pc instr)
        (? (< i (len acc))
           (: c (get 0 i acc)
              (? instr
                 (? (= c 92) (: _ (eb c) _ (eb (get 0 (+ i 1) acc)) (g (+ i 2) 0 1))
                    (: _ (eb c) (g (+ i 1) c (? (= c 34) 0 1))))
                 (? (= c 32)
                    (? (redundant? pc (get 0 (+ i 1) acc))
                       (g (+ i 1) pc 0)                   ; drop the space
                       (: _ (eb c) (g (+ i 1) c 0)))      ; keep it
                    (: _ (eb c) (g (+ i 1) c (= c 34))))))
           0))
      0 0 0)
   _ (fputc out 34)                                      ; closing "
   (fputc out 10))
