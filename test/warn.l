; compile-time kind warnings: `warn-kinds` (prel) flags ops whose operand KINDS
; guarantee a nil result. PURE -- tested directly here (no flag toggling, no I/O).
; feel prints these to err when the `warns` box is on (default OFF, so the corpus
; compiles silently). SOUND: an unknown kind reads `top`, which never warns.
(assert
 ; --- clean: no warning (and no false positives on unknowns) ---
 (nil? (warn-kinds '(+ 1 2)))
 (nil? (warn-kinds '(: n 5 (- n 3))))            ; n inferred numeric
 (nil? (warn-kinds '(\ x (- x 1))))              ; param x unknown -> top -> silent
 (nil? (warn-kinds '(- a b)))                    ; free vars -> top -> silent
 ; --- flagged: the operand kinds force nil ---
 (= '((- "ab" 1)) (warn-kinds '(- "ab" 1)))                   ; subtract a string literal
 (= '((- s 3)) (warn-kinds '(: s "hi" (- s 3))))              ; binding-flow: s inferred str
 (= '((* "a" "b")) (warn-kinds '(* "a" "b")))                 ; str*str -> nil
 (= '((- (+ "a" "b") 5)) (warn-kinds '(- (+ "a" "b") 5)))     ; nested: (+ str str)=str, so (- str 5) flagged
 ; --- list ops + named-symbol arithmetic: numeric-only ops on a non-number ---
 (= '((- '(1 2) 3)) (warn-kinds '(- '(1 2) 3)))               ; subtract a list literal
 (= '((// '(1 2) 2)) (warn-kinds '(// '(1 2) 2)))             ; quotient of a list
 (= '((- 'foo 3)) (warn-kinds '(- 'foo 3)))                   ; subtract a named symbol
 (= '((% xs 2)) (warn-kinds '(: xs '(1 2) (% xs 2))))         ; binding-flow: xs inferred list
 (nil? (warn-kinds '(+ '(1 2) '(3 4))))                       ; list+list = cat -- clean
 (nil? (warn-kinds '(* '(1 2) '(3 4))))                       ; list*list = cartesian -- clean
 (nil? (warn-kinds '(- (f x) 3)))                             ; computed (unquoted) list -> top -- clean (sound)
 ; --- the tunable box defaults OFF ---
 (= 0 (peep warns 0 0)))
