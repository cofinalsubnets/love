; lcat: serialize a l source file to a C string literal for #include (the lcat
; lib headers the final l is assembled from). Each top-level form is re-printed
; via show (canonical), the forms are joined into one string, and that string is
; MINIFIED -- a space is dropped wherever removing it does not change how the reader
; tokenizes. The boundary test is empirical, not a hardcoded delimiter set: the
; bytes since the last HARD boundary (whitespace, a delimiter, or a value-surface
; char -- chars that end a token under every lexer law) plus the byte after the
; space are concatenated with and without it and re-parsed; if both spellings
; yield the same number of complete datums the space was redundant (e.g. `o(`
; reads the same as `o (`, but `-5` and `- 5` do not, and `sing? s` must keep
; its space -- `sing?s` is ONE name token, since a name absorbs ? ! etc). The
; probe needs the whole left token, not one byte: flanking bytes alone said
; `?`+`s` splits, blind to the name `sing?` continuing through both. Spaces
; inside a string literal are data and never touched. Surviving bytes are then
; C-escaped.

(: (s2cl s) ((: (g i) (? (< i (sat s)) (cons (peep s i 0) (g (+ 1 i))))) 0)  ; string -> charlist
   ; count complete datums readable from s (stop on the eof sentinel or an
   ; incomplete form, which read signals by returning the port itself).
   (nforms s) ((: (g p e n) (: r (read p e) (? (| (= e r) (= p r)) n (g p e (+ 1 n)))))
               (sip (s2cl s)) (nom 0) 0)
   ; a HARD token boundary: whitespace, delimiters, string quote, comment, and
   ; the value-surface chars. tokens never span these under any lexer law, so
   ; the redundancy probe's left context resets there.
   (hardb c) (? (= c 32) 1 (= c 10) 1 (= c 9) 1
                (= c 40) 1 (= c 41) 1 (= c 91) 1 (= c 93) 1 (= c 123) 1 (= c 125) 1
                (= c 34) 1 (= c 59) 1 (= c 39) 1 (= c 96) 1 (= c 44) 1
                (= c 64) 1 (= c 126) 1 (= c 35) 1
                0)
   ; ctx = the bytes since the last hard boundary, reversed. is the space
   ; between them and byte b redundant? (same datum count joined vs spaced)
   (redundant? ctx b) (= (nforms (string (rev (cons b ctx))))
                         (nforms (string (rev (cons b (cons 32 ctx))))))
   ; emit one byte to out, C-escaped for the string literal.
   (eb c) (? (= c 10) (fputs out "\\n")
              (| (= c 92) (= c 34)) (: _ (fputc out 92) (fputc out c))
              (fputc out c)))

(: p (open (cap (cbp argv)) "r")
   _ (? p 0 (: _ (fputs err "lcat: cannot open input") (exit 1)))
   ; gather every canonical form into one space-joined string
   acc ((: (g acc e p first)
          (: r (read p e)
             (? (= e r) acc
                (g (? first (show r) (+ (+ acc " ") (show r))) e p 0))))
        "" (nom 0) p 1)
   _ (fputc out 34)                                      ; opening "
   ; walk acc: drop redundant spaces (outside string literals), C-escape the rest.
   ; ctx = bytes since the last hard boundary (reversed); instr = inside a "..."
   ; literal (where \ escapes).
   _ ((: (g i ctx instr)
        (? (< i (sat acc))
           (: c (peep acc i 0)
              (? instr
                 (? (= c 92) (: _ (eb c) _ (eb (peep acc (+ i 1) 0)) (g (+ i 2) 0 1))
                    (: _ (eb c) (g (+ i 1) 0 (? (= c 34) 0 1))))
                 (? (= c 32)
                    (? (redundant? ctx (peep acc (+ i 1) 0))
                       (g (+ i 1) ctx 0)                  ; drop the space; ctx keeps accruing
                       (: _ (eb c) (g (+ i 1) 0 0)))      ; keep it: a real boundary
                    (: _ (eb c)
                       (g (+ i 1) (? (hardb c) 0 (cons c ctx)) (= c 34))))))))
        0 0 0)
   _ (fputc out 34)                                      ; closing "
   (fputc out 10))