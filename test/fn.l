; functions print as value forms (read back via uq=identity): builtins -> ,name;
; lambdas -> ,(\ …) source with \-bound vars as interned d<lvl> de Bruijn LEVELS
; (a-canonical: outermost binder = d0). Interned names -> the print form round-trips
; (see roundtrip.l). a-equivalent lambdas print identically; capture = a leading binder.
(assert
 (= "\+" (show (+)))
 (= "link" (show link))
 (= "(\\ d0 d0)" (show (\ x x)))
 (= "(\\ d0 d1 (+ d0 d1))" (show (\ a b (+ a b))))
 (= (show (\ x x)) (show (\ y y)))               ; a-equivalent -> identical print
 (= "(\\ d0 (\\ d1 d1))" (show (\ x (\ x x))))      ; shadow: inner binder = d1
 (= "(\\ d0 'y)" (show (\ x 'y)))                   ; quoted datum not renamed
 (= "(+ 1)" (show (+ 1)))
 (= "((\\ d0 d1 (+ d0 d1)) 1)" (show ((\ a b (+ a b)) 1)))
 (= "((\\ d0 d1 (+ d1 d0)) 5)" (: y 5 (show (\ x (+ x y)))))  ; closure: capture is leading binder
 (string? (show map))
 (< 10 (tally (show map))))
