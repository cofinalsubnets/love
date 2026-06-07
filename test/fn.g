; printing functions: like tuple/hash, a function is a `,`-prefixed value form
; (reads back via uq=identity). builtins -> ,name; compiled lambdas -> ,(\ …)
; source; partial applications/closures -> ,(base captured-args…).
(assert
 ; builtins print by name
 (= "\+" (inspect +))
 (= "\X" (inspect X))              ; prelude `X` is the bif `X`
 ; a compiled lambda prints as its source \-expr
 (= "(\\ x x)" (inspect (\ x x)))
 (= "(\\ a b (+ a b))" (inspect (\ a b (+ a b))))
 ; a one-arg lambda body that is itself quote still round-trips structurally
 (= "(\\ x 'y)" (inspect (\ x 'y)))
 ; partial application of a builtin
 (= "(+ 1)" (inspect (+ 1)))
 ; partial app of a lambda: only the OUTER form gets the comma, not the base
 (= "((\\ a b (+ a b)) 1)" (inspect ((\ a b (+ a b)) 1)))
 ; a closure (captures a free var) prints as a partial application over its base
 ; lambda; the captured var is shown as a LEADING param (frame layout [imps args]),
 ; so the form round-trips: applying the base to the captures reconstructs it.
 (= "((\\ y x (+ x y)) 5)" (: y 5 (inspect (\ x (+ x y)))))
 ; a prelude function prints its (non-trivial) source
 (strp (inspect map))
 (< 10 (len (inspect map))))
