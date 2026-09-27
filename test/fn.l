; functions print as value forms that reconstruct under eval: builtins -> the bare
; name; lambdas -> (\ …) source with \-bound vars as interned shortlex letters by de Bruijn
; level -- a b .. z aa ab .. -- skipping any letter spelled free in the source, since a name
; kept as written is one a rename would capture. Interned names -> the print form round-trips
; (see roundtrip.l). a-equivalent lambdas print identically. a captured value renders as a
; leading binder -- but that rendering is intensional and free to vary (cprop may inline a
; constant capture), so show of a capture is asserted extensionally: show -> read -> eval rebuilds
; a function of the same behavior (rt below; the dedicated suite is roundtrip.l).
; `=` compares functions by what they compiled to: two lambdas are equal when their threads are,
; and a param is a stack slot there, so lambdas that differ only in their names are equal. a
; partial-app is its base and its captures: equal to another partial of an equal base holding equal
; captures, never to a lambda it would reduce to (`=` reduces nothing).
(: (rt x) (ev <(sound (show x)))
 (test
  ("\+" = show (+))
  ("." = show (.))
  ("(\\ a a)" = show (\ x x))
  ("(\\ a b (+ a b))" = show (\ a b (a + b))) ; already canonical: prints as written
  (show (\ x x) = show (\ y y))               ; a-equivalent -> identical print
  ("(\\ a (\\ b b))" = show (\ x (\ x x)))    ; shadow: inner binder = b
  ("(\\ a 'y)" = show (\ x 'y))               ; quoted datum not renamed
  ; a letter spelled free in the source is skipped, or the rename would capture it
  ("(\\ a b c d f (+ e a))" = show (\ p q r s t (e + p)))     ; e free -> binder 4 is f
  (= "(\\ a b c d f g h j k (+ e (+ i k)))"
     (show (\ p q r s t u v w x (e + (i + x)))))                ; e and i both skipped
  (= "(\\ a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab (+ aa ab))"
     (show (\ q1 q2 q3 q4 q5 q6 q7 q8 q9 q10 q11 q12 q13 q14 q15 q16 q17 q18 q19 q20
              q21 q22 q23 q24 q25 q26 q27 q28 (q27 + q28)))) ; past z, shortlex rolls to aa
  ("(+ 1)" = show (+ 1))                                     ; partial app of a builtin: stable form
  (3 = ((rt ((\ a b (a + b)) 1)) 2))                         ; partial-applied lambda round-trips (capture rendering free to vary)
  (9 = (: y (2 + 3) ((rt (\ x (x + y))) 4)))                 ; closure with a captured var round-trips to a working fn
  ; --- functions compare by their threads ---
  ((\ p q (p + q)) = (\ a b (a + b)))                   ; names never reach the thread
  (! ((\ a b (a + b)) = (\ a b (a - b))))              ; a different body is different code
  (((\ a b (a + b)) 1) = ((\ x y (x + y)) 1))           ; partials: equal bases, equal captures
  (! (((\ a b (a + b)) 1) = ((\ a b (a + b)) 2)))      ; ..a different capture stays distinct
  (! (((\ a b (a + b)) 1) = (\ b (1 + b))))            ; a partial is not the lambda it would reduce to
  ((\ i (\ x (x + i))) = (\ i x (x + i)))               ; nested and multi-param spellings are the same function -- opfix (op-flat-ol) flattens both compilers (c0 + feel), so this holds under love0 too
  ((\ x (\ x x)) = (\ x (\ x x)))                       ; shadowing stays nested (not flattened to the ambiguous (\ x x x)); still self-equal
  (! ((\ x (. x)) = (.)))                               ; eta is not reduced either
  ((+ 1) = (+ 1)) (! ((+ 1) = (+ 2)))                   ; a builtin base: base and captures, pairwise
  (9 = peep {((\ a b (a + b)) 5) 9} ((\ x y (x + y)) 5) 0)   ; hash consistency: a map keyed on a partial, found by an equal one
  ; worklist safety: a closure with a chain capture nested in a compared structure -- equal closures
  ; but a differing tail must stay not equal (a capture's pairs must not clobber the pending ones)
  (! ((. ((\ v x (x + v)) '(1 2)) (. 5 6)) = (. ((\ v x (x + v)) '(1 2)) (. 5 7))))
  ((. ((\ v x (x + v)) '(1 2)) (. 5 6)) = (. ((\ v x (x + v)) '(1 2)) (. 5 6)))
  ; the same safety on the no-capture path: a quoted datum in the thread is a value the
  ; worklist compares above the pending pairs, so the differing tail still tells
  (! ((. (\ a (\ 5)) (. 5 6)) = (. (\ b (\ 5)) (. 5 7))))
  ((. (\ a (\ 5)) (. 5 6)) = (. (\ b (\ 5)) (. 5 6)))
  (string? (show map))
  (10 < tally (show map))))
