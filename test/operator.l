; the operator table -- ONE table, `operators`: sigil symbol -> arity (the symbol
; names itself) | (name . arity) (an alias), arity 1-7. the reader is structural
; (a sigil -- a maximal all-punct token -- reads as one plain symbol); code factors
; sigils against the table at COMPILE time (the opfix pass), so a pin in one form
; governs the next form -- the test runner reads and compiles one form at a time.
(: op-tbl operators)             ; leak to global scope for this file
(assert (book? op-tbl)
 ((link 'saturate 1) = (op-tbl '$)) ((link 'nil? 1) = (op-tbl '!)) ((link 'dot 1) = (op-tbl '.))
 (2 = (op-tbl '+)) (2 = (op-tbl '-)) (2 = (op-tbl '%)) (3 = (op-tbl '?))
 ((link 'pin 3) = (op-tbl '<-)) ((link 'peep 3) = (op-tbl '->)))

; reading is structural: a sigil from a port is just the symbol, no table consulted
(assert ('^ = (sound (tap '(94)) 99)) ('+ = (sound (tap '(43)) 99)))

; wire ^^ as a temporary alias at two (list); restored below. ^ itself stays the
; xor nif throughout -- the factorization law is greedy longest-prefix, so the
; two-char key wins while pinned (^ alone could never chain: a non-last factor
; must be arity one and ^ is at two).
(pin op-tbl '^^ (link 'list 2))
(assert
 ('(1 2) = (1 ^^ 2))                            ; infix: captures the left operand
 ('(1 (2 3)) = (1 ^^ 2 ^^ 3))                   ; nests RIGHT-associatively
 ('(5 (1 2)) = `(5 (1 ^^ 2)))                  ; works inside lists
 ('("a" 7) = ("a" ^^ (tally "seven!!"))))      ; composes with the count word

; rebind: an alias at three, then at one
(pin op-tbl '^^ (link 'L 3))
(assert ('(1 2 3) = (1 ^^ 2 3)) ('((1 2 3) 4 5) = ((1 ^^ 2 3) ^^ 4 5)))
(pin op-tbl '^^ (link 'up 1))
(: up (+ 1)                                     ; a local 1-ary global to alias ^^ to
 (assert (6 = ^^5) (7 = ^^^^5)                  ; at one: prefix; chains factor greedily
         (0 = !^^5)))                           ; mixed chain: (nil? (up 5))

; restore: unpinned, ^^ no longer factors (^ is at two, can't lead a chain),
; so it reads as a plain symbol again
(pull op-tbl '^^ 0)
(assert !(op-tbl '^^) (nom? '^^) ("(^^ 5)" = (show (opfix '(^^ 5))))
        (-2 = (^ 1 -1)) (6 = (^ 5 3)))          ; ^ was the xor nif all along

; --- the comma: the clause layer, loosest of all -----------------------------
; a lone one-char datum off the reader (never fuses, either side); within any
; list the datums split into clauses at commas, each clause factored on its
; own, the whole the `,` sequencing macro -- (a, b c) -> (, (a) (b c)) ->
; (: _ a (b c)): effects in source order, the last clause answers. empty
; clauses drop: a doubled interior comma composes to one, a leading or
; trailing comma to nothing. head position is the macro itself.
(assert
 (2 = (1 , 2))                                  ; spaced
 (3 = (1, 2, 3))                                ; glued left (C typography)
 (3 = (1,2,3))                                  ; fully glued
 (3 = (1 ,2 ,3))                                ; glued right (no mono lane)
 (7 = ((+ 1 2), (+ 3 4)))                       ; parenthesized phrases
 (7 = (+ 1 2, + 3 4))                           ; bare phrases: comma outranks infix
 (16 = (2 3 + 1, 2 4))                          ; ... and application: (2 (+ 3 1)), then (2 4)
 (3 = (1 ,, 3))                                 ; interior empties compose to one comma
 (5 = (5 ,))                                    ; a trailing comma is ignored
 (5 = (, 5))                                    ; leading comma: the sequencing macro,
 (2 = (, 1 2))                                  ; ... explicit head-position form
 ("(, (1) (2 3))" = (show (opfix '(1 , 2 3))))) ; the emission, reparsable
; effects run in source order and the last clause is the value
(: cq (tablet 0)
   (cnote v) (: _ (pin cq (tally cq) v) v)
   (: r ((cnote 'a), (cnote 'b), (cnote 'c))
      (assert ('c = r) ('a = (cq 0)) ('b = (cq 1)) ('c = (cq 2)) (3 = $cq))))
; quote interiors are data: the comma stays a plain symbol, and reading is
; structural -- a lone comma off a port is just the datum
(assert (3 = (tally '(1 , 2))) (', = (caup '(1 , 2)))
        (nom? ',) ("," = (string ',)) (', = (sound (tap '(44)) 99)))
; clauses nest per list, and chain with the infix aliases
(assert (6 = (: t #(0 1) _ ((t <- 0 2), (t <- 1 3)) ((t 0) * (t 1)))))
