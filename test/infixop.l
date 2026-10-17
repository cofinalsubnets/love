; infix: with a left operand the sigil captures it and one more datum, right-associatively;
; with none it is the plain symbol. opfix factors at compile time, reading is structural
(test
 ; basics, every seeded operator
 (-1 = (1 - 2)) (6 = (2 * 3)) (2.5 = (5 / 2))
 (1 = (3 = 3.0)) (0 = (3 = 4))
 (1 = (1 < 2)) (1 = (1 <= 1)) (1 = (2 > 1)) (1 = (2 >= 2)) (0 = (2 < 1))
 (15 = (8 | 4 | 2 | 1)) (0 = (5 & 2)) (7 = (5 | 2))
 (1 = (5 % 2)) ('% = <>'(5 % 2))               ; quotes stay data

 ; right-associativity; parens override
 (7 = (1 + 2 * 3))                              ; (+ 1 (* 2 3))
 (9 = ((1 + 2) * 3))
 (10 = (1 + 2 + 3 + 4))
 (1 = (5 = 2 + 3))                              ; (= 5 (+ 2 3))

 ; infix ? is the one-armed cond, its loose band deciding what the condition is
 ('a = (1 ? 'a)) (() = (0 ? 'a))
 ('big = ((1 < 2) ? 'big))
 ('big = (1 < 2 ? 'big))                        ; (1 < 2) binds first -> (? (< 1 2) 'big)
 ; an else arm is the prefix cond, which is n-ary
 ('small = (? (2 < 1) 'big 'small)) ('c = (? 0 'a 0 'b 'c))

 ; application binds tighter than infix: (1 + 2 3) is (+ 1 (2 3))
 ('(3 3) = [(1 + 2) 3])                         ; two elements: (+ 1 2) and 3
 ('(3 9) = [(1 + 2) (4 + 5)])
 ("(+ 1 (2 3))" = show (opfix '(1 + 2 3)))  ; 2 3 is one operand, the whole to the right of +
 ("(= (a b) (c d))" = show (opfix '(a b = c d)))

 ; operators as values and quoted operators are untouched
 ('(1 2 3) = sort '(3 1 2))
 (nom? '+) (7 = (+) 3 4))

; an unclosed list is torn; a trailing operator is not, "1 +" being two datums
(test ('torn = sound '(40 49 32 43)))              ; "(1 +" -> torn
(: r (sound '(49 32 43))                                 ; "1 +"  -> 1, then +
   (test (1 = <r) ('+ = <(sound >r))))

; a fresh dyadic operator needs no table: define, then use
(: ** (b \ n \ n b)
 (test (8.0 = (2 ** 3)) (512.0 = (2 ** 3 ** 2))))  ; right-assoc: 2^(3^2)

; any all-punct symbol is dyadic infix by default; the table holds only the exceptions
(: . (a \ b \ [a b])                            ; a fresh punct op, never registered
 (test
  ('(3 5) = (3 . 5))                             ; infix: captures the left operand
  ('(7 (3 5)) = (7 . 3 . 5))                    ; nests right-associatively
  ('(9 (3 5)) = [9 (3 . 5)])                    ; works inside a list
  (nom? '.) (= . (.))                          ; no left operand / escaped: the plain symbol
  ("(. 3 5)" = (show (opfix '(3 . 5))))))      ; a folded infix form splices up, no wrapper

; opfix keeps a binding form's binders verbatim and factors only values and body.
; compared through show, since opfix ends spines with 0 and the reader with ()
(test
 ((show '(: . (\ a b [a b]) (. 3 5))) = (show (opfix '(: . (\ a b [a b]) (3 . 5)))))      ; explicit binder kept
 ((show '(: (. a b) [a b] (. 3 5))) = (show (opfix '(: (. a b) [a b] (3 . 5)))))          ; sugar header kept
 ((show '(\ a b (+ a b))) = (show (opfix '(\ a b (a + b)))))                                  ; \ args verbatim, body factored
 ((show '(: a 1 b 2 (+ a b))) = (show (opfix '(: a 1 b 2 (a + b)))))                          ; : values/body factored, names kept
 (2 = (: x 1 x (x + 1) x)))                                                                     ; the sequence law, intact

; --- the binders infix: `\` dyadic, `:` n-ary at the loosest band, `:=` its alias.
; each is the same form as the prefix one, and a `:` chain is spliced flat into one scope
(test
 (show '(\ a b c)           = show (opfix '(a \ b \ c)))             ; the chain flattens: one closure, not two
 (show '(\ x (+ x 1))       = show (opfix '(x \ x + 1)))             ; the body extends right, under every tighter op
 (show '(\ x (? c a b))     = show (opfix '(x \ c ? a b)))           ; ..a clause form included
 (show '(: a b c)           = show (opfix '(a : b c)))               ; n-ary: every operand stays one
 (show '(: a b)             = show (opfix '(a : b)))                 ; ..and at two it is the body-less form, which pins
 (show '(: (f x) (+ x 1))   = show (opfix '(f x : x + 1)))           ; define-sugar: the leading span is the binder
 (show '(: a 1 b 2 (+ a b)) = show (opfix '(a : 1 b : 2 (a + b))))   ; the chain is one scope -- the prefix form exactly
 (show '(: a b c d)         = show (opfix '(a : b c : d)))           ; ..so a chain of bare definitions is one body-less :
 (show '(: f (\ x (+ x 1))) = show (opfix '(f : x \ x + 1)))         ; \ grips tighter than :, so a lambda is one value
 (show (opfix '(a : b c))   = show (opfix '(a := b c)))              ; := names `:` and inherits the whole fold
 (show (opfix '(a : 1 b : 2 (a + b))) = show (opfix '(a : 1 b := 2 (a + b))))   ; ..either spelling, same chain
 (3 = (x \ x + 1) 2) (7 = (x \ y \ x + y) 3 4)
 (9 = (a : 4 b : 5 (a + b))))                                            ; a body-having : is one scope and pins nothing

; a top-level infix definition pins to the global book, so the names are prefixed
(ifx-sq x := x * x)
(ifx-hyp a b : (ifx-sq a + ifx-sq b))
(ifx-fst [a b] := a)                                    ; a define-sugar param is a pattern here too
(test (9 = ifx-sq 3) (25 = ifx-hyp 3 4) (5 = ifx-fst '(5 7))
        (7 = (ifx-z : 7)))                            ; ..and the form answers what it bound

; a non-nom param is a pattern wherever it sits; checked by behaviour, since each lowering mints a fresh nom
(test
 (7 = (\ x [a b] (x + a + b)) 0 '(3 4))                                ; prefix
 (7 = (x \ [a b] \ x + a + b) 0 '(3 4))                                ; ..infix
 (7 = (\ x (\ [a b] (x + a + b))) 0 '(3 4))                            ; ..and merged up out of a nested lambda
 (2 = (\ [a b] (\ a a)) '(1 2) 2))                                     ; the shadow still refuses to merge
