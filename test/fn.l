; functions print as value forms (read back via uq=identity): builtins -> ,name;
; lambdas -> ,(\ …) source with \-bound vars as interned d<lvl> de Bruijn LEVELS
; (a-canonical: outermost binder = d0). Interned names -> the print form round-trips
; (see roundtrip.l). a-equivalent lambdas print identically; capture = a leading binder.
(assert
 (= "\+" (inspect +))
 (= "\X" (inspect X))
 (= "(\\ d0 d0)" (inspect (\ x x)))
 (= "(\\ d0 d1 (+ d0 d1))" (inspect (\ a b (+ a b))))
 (= (inspect (\ x x)) (inspect (\ y y)))               ; a-equivalent -> identical print
 (= "(\\ d0 (\\ d1 d1))" (inspect (\ x (\ x x))))      ; shadow: inner binder = d1
 (= "(\\ d0 'y)" (inspect (\ x 'y)))                   ; quoted datum not renamed
 (= "(+ 1)" (inspect (+ 1)))
 (= "((\\ d0 d1 (+ d0 d1)) 1)" (inspect ((\ a b (+ a b)) 1)))
 (= "((\\ d0 d1 (+ d1 d0)) 5)" (: y 5 (inspect (\ x (+ x y)))))  ; closure: capture is leading binder
 (strp (inspect map))
 (< 10 (pin (inspect map))))
