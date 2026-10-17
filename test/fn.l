; functions print as forms that eval back to an `=` function: a lambda's binders are
; shortlex letters by depth, skipping any spelled free. `=` compares compiled threads
; two globals bound as one letrec: fn-al calls its sibling
(: (fn-dg c) (? (c < 1) 0 (fn-dg (c - 1)))  (fn-al c) (fn-dg c || c > 90))
(: (rt x) (ev <(sound (show x)))
   (rt= f) (f = rt f)
   (fnfree s x) (: f (trap (_ \ ev x) () (a \ b \ 0)) (f ? (s = show f) 1))
 (test
  ("\+" = show (+))
  ("." = show (.))
  ("(\\ a a)" = show (x \ x))
  ("(\\ a b (+ a b))" = show (a \ b \ a + b))
  (show (x \ x) = show (y \ y))               ; a-equivalent -> identical print
  ("(\\ a ((\\ b b)))" = show (x \ (x \ x)))  ; a lambda body sits in a singleton: bare, the reader would merge the params
  ("(\\ a 'y)" = show (x \ 'y))               ; quoted datum not renamed
  ; a free letter is skipped, or the rename would capture it; ev's, since c0 refuses a missing name
  (fnfree "(\\ a b d e f (+ c a))" '(\ p q r s t (c + p)))           ; c free -> binder 2 is d
  (fnfree "(\\ a b d e f h i j k (+ c (+ g k)))"
          '(\ p q r s t u v w x (c + (g + x))))                       ; c and g both skipped
  ("(\\ a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab (+ aa ab))"
     = show (\ q1 q2 q3 q4 q5 q6 q7 q8 q9 q10 q11 q12 q13 q14 q15 q16 q17 q18 q19 q20
              q21 q22 q23 q24 q25 q26 q27 q28 (q27 + q28))) ; past z, shortlex rolls to aa
  ("(+ 1)" = show (+ 1))                                     ; partial app of a builtin: stable form
  (3 = (rt ((a \ b \ a + b) 1) 2))                           ; partial-applied lambda round-trips (capture rendering free to vary)
  (9 = (: y (2 + 3) (rt (x \ x + y) 4)))                     ; closure with a captured var round-trips to a working fn
  ; --- the read-back is the thread: show -> read -> eval compiles to the same words ---
  (rt= (x \ (? x 1 2)))
  (rt= (x \ 1 + (? (two? x) <x 7)))                            ; a cond joined in the middle of a call
  (rt= (x \ (? x 1 (two? x) 2 3)))                             ; clauses
  (rt= (x \ (: y (x + 1) (y * x))))                            ; a let over a capture
  (rt= (x \ (: y (x + 1) z (y * 2) (y * z * x))))              ; a sibling reads an earlier one
  (rt= (x \ (: (f n) (? n (f (n - 1)) x) (f (x + 3)))))        ; letrec, a capture
  (rt= (x \ (: (f n) (? n (g (n - 1)) x) (g n) (f n) (f 3))))  ; mutual letrec
  (rt= (x \ map (y \ x + y) x))                                ; a closure over x
  (rt= (a \ b \ c \ foldl a b c 4))                            ; an n-ary apply and its surplus
  (rt= (l \ foldl (+) 0 l))                                    ; an operator as a value  (rt= (\ x (\ x x)))
  (rt= ((a \ b \ a + b) 1))
  (rt= fn-al)                                                  ; a sibling call fuses as a global's does
  (rt= (m \ x \ (: k (tally x) (m < k ? k m))))               ; an inner lambda `=` to glaze's amax is its own
  (rt= (x \ (: h (y \ y + 1) g (z \ map h z) [(g x) (map h x) (g >x)])))            ; a helper read once
  ; a big carrier a closure keeps reads as its size; ev keeps its caches so, and prints short
  (has? (show (: t (foldl (t \ i \ pin t i i) {} (jot 40)) (x \ peep t (x + 1) 0))) "{..40}")
  (has? (show (: t {'s (foldl (t \ i \ pin t i i) {} (jot 40))} (x \ peep t x 0))) "{..1}")
  (has? (show (: t {'a 1} _ (pin t 'me t) (x \ peep t x 0))) "{..2}")
  (#(show ev) < 200000)
  !(has? (show ev) "((mint ")                        ; every name it calls is bound
  ; ..and ev read back off its own show is an ev, or a miss where the mop dropped a door
  (trap (_ \ 3 = (ev <(sound (show ev))) '(+ 1 2)) ()
        (a \ b \ a = 'missing && !(cite 'guts 'place) && (nelem b (names ()))))
  ; --- functions compare by their threads ---
  ((p \ q \ p + q) = (a \ b \ a + b))                   ; names never reach the thread
  !((a \ b \ a + b) = (a \ b \ a - b))                 ; a different body is different code
  (((a \ b \ a + b) 1) = ((x \ y \ x + y) 1))           ; partials: equal bases, equal captures
  !(((a \ b \ a + b) 1) = ((a \ b \ a + b) 2))         ; ..a different capture stays distinct
  !(((a \ b \ a + b) 1) = (b \ 1 + b))                 ; a partial is not the lambda it would reduce to
  ((i \ (x \ x + i)) = (i \ x \ x + i))                 ; nested and multi-param spellings are the same function
  ((x \ (x \ x)) = (x \ (x \ x)))                       ; shadowing stays nested (not flattened to the ambiguous (\ x x x)); still self-equal
  !((x \ (. x)) = (.))                                  ; eta is not reduced either
  ((+ 1) = (+ 1)) !((+ 1) = (+ 2))                      ; a builtin base: base and captures, pairwise
  (9 = peep {((a \ b \ a + b) 5) 9} ((x \ y \ x + y) 5) 0)   ; hash consistency: a map keyed on a partial, found by an equal one
  ; worklist safety: equal closures with a chain capture, then a differing tail, stay unequal
  !((. ((v \ x \ x + v) '(1 2)) (. 5 6)) = (. ((v \ x \ x + v) '(1 2)) (. 5 7)))
  ((. ((v \ x \ x + v) '(1 2)) (. 5 6)) = (. ((v \ x \ x + v) '(1 2)) (. 5 6)))
  ; the same on the no-capture path, a quoted datum in the thread
  !((. (a \ (\ 5)) (. 5 6)) = (. (b \ (\ 5)) (. 5 7)))
  ((. (a \ (\ 5)) (. 5 6)) = (. (b \ (\ 5)) (. 5 6)))
  ; the pairs taken as equal grow with the walk: 2000 equal threads built apart, one pair each
  ((map (_ \ ev '(\ x (+ x 1))) ^2000) = (map (_ \ ev '(\ x (+ x 1))) ^2000))
  (string? (show map))
  (10 < #(show map))))

; a source application n deep compiles in its length: ((((1)))) peels at every level
(: (fnq-nest n) (n = 0 ? 1 [(fnq-nest (n - 1))])
 (test (1 = ev (fnq-nest 50)) (test-linear (n \ ev ['\ 'u (fnq-nest n)]) 1500)))

; opfix twice is opfix once: an operator symbol it makes an operand is spelled by value
(: (fnq-fix s) (opfix <(sound s) @ a (opfix a = a))
 (test (fnq-fix "(. = (.))") (fnq-fix "(c ? + -)") (fnq-fix "(a < b <= c)") (fnq-fix "(map (+) l)")
       (fnq-fix "(x @ [a b] (a + b))") (fnq-fix "(: a 1 b (a + 1) (\\ q (q * b)))")
       (1 = ev <(sound "(. = (.))"))))
; text holes nested n deep compile in their length: each macro's operands come in factored
; the text is joined once: a + per level copies the inner text, and the law would time that
(: (fnq-pile k s t) (k = 0 ? t (fnq-pile (k - 1) s (s . t)))
   (fnq-holes k) (join "" (fnq-pile k "\"a \\(" ("\"x\"" . fnq-pile k ") b\"" ())))
 (test ("a a x b b" = ev <(sound (fnq-holes 2)))
       (test-linear (n \ ev ['\ 'u <(sound (fnq-holes n))]) 250)))
