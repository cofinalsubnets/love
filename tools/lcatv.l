; lcatv: bake a source file to a C string literal VERBATIM -- byte-for-byte, no
; form parsing, no show-reprint, no minification. lcat/lcat2 re-print each form
; through show; that round-trip subtly diverges for the test corpus when it is
; read back incrementally through a sip port (the reader loops instead of hitting
; EOF), so the baked kernel test corpus (out/lib/ktests.h, read via sip at boot)
; must be verbatim. Non-printable / high bytes -> \ooo octal so clang accepts the
; literal (-Winvalid-source-encoding rejects a raw byte like the たらい symbol in
; functions.l); C decodes the escape back to the original byte. argv = (this file).
(: (eb c) (? (= c 10) (fputs out "\\n")
              (| (= c 92) (= c 34)) (: _ (fputc out 92) (fputc out c))
              (| (< c 32) (> c 126)) (: _ (fputc out 92)
                 _ (fputc out (+ 48 (% (// c 64) 8)))
                 _ (fputc out (+ 48 (% (// c 8) 8)))
                 (fputc out (+ 48 (% c 8))))
              (fputc out c))
   p (open (cap (cbp argv)) "r")
   _ (? p 0 (: _ (fputs err "lcatv: cannot open input") (exit 1)))
   s (slurp p)
   _ (fputc out 34)
   _ ((: (g i) (? (< i (tally s)) (: _ (eb (peep s i 0)) (g (+ 1 i))))) 0)
   _ (fputc out 34)
   (fputc out 10))
