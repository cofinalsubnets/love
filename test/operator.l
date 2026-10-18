; opfix's operator table is private, keyed by arity (0 glued, 2 spaced, -1 unbounded),
; so its laws read through behaviour

; reading is structural: a sigil from a port is just the symbol
(test ('^ = <(sound '(94))) ('+ = <(sound '(43))))

; ^^ has no entry and a spaced sigil never splits; ^ is xor
(test (nom? '^^) ("(^^ 5)" = show (opfix '(^^ 5))) (-2 = 1 ^ -1) (6 = 5 ^ 3))

; --- the comma, loosest of all: (a, b c) -> (, (a) (b c)), the last answers.
; it never fuses, and empty clauses drop
(test
 (2 = (1 , 2))
 (3 = (1, 2, 3))
 (3 = (1,2,3))
 (3 = (1 ,2 ,3))
 (7 = ((+ 1 2), (+ 3 4)))
 (7 = (+ 1 2, + 3 4))                           ; bare phrases: comma outranks infix
 (16 = (2 3 + 1, 2 4))                          ; (2 (+ 3 1)), then (2 4)
 (3 = (1 ,, 3))                                 ; interior empties compose to one comma
 (5 = (5 ,))                                    ; a trailing comma is ignored
 (5 = (, 5))                                    ; leading comma: the sequencing macro
 (2 = (, 1 2))
 ("(, (1) (2 3))" = show (opfix '(1 , 2 3)))) ; reparsable
(: cq (tablet 0)
   (cnote v) (pin cq #cq v, v)
   (: r ((cnote 'a), (cnote 'b), (cnote 'c))
      (test ('c = r) ('a = cq 0) ('b = cq 1) ('c = cq 2) (3 = #cq))))
; in a quote the comma is a plain symbol
(test (3 = #'(1 , 2)) (', = <>'(1 , 2))
        (nom? ',) ("," = string ',) (', = <(sound '(44))))
; clauses nest per list, and chain their effects in source order
(test (6 = (: t {0 1} _ ((pin t 0 2), (pin t 1 3)) (t 0 * t 1))))
; != and !== negate = and ==, so each law wants two chains equal and not the same
(: a '(1 2)
   b '(1 2)
   (test
      (a = b) !(a == b)
      !(a != b) (a !== b)
      (a == a) !(a !== a)
      (1 != 2) (1 !== 2)
      (1 == 1) !(1 !== 1)
      ((a != b) = 0) ((a !== b) = 1)))
; elem and eleq walk under = and ==
(: r 1.0
   (test
      (elem r '(1 2 3)) !(eleq r '(1 2 3))    ; 1.0 IS 1 by value, not the same word
      (elem 1 [r 2]) !(eleq 1 [r 2])
      (elem 'b '(a b)) (eleq 'b '(a b))
      !(elem 'z '(a b)) !(eleq 'z '(a b))
      (elem '(1 2) '((1 2))) !(eleq '(1 2) '((1 2))))) ; two chains built apart
; elem walks a text by byte, so its elements are charms; eleq walks chains only
(test
   (elem 98 "abc") (elem 97 "abc") (elem 99 "abc")
   !(elem 100 "abc")
   !(elem "b" "abc")                                 ; a text is no element of a text
   !(elem 98 "")
   (elem 10 "a\nb") (elem 0 (string 0))
   !(elem 353 "abc") !(elem -1 "abc")
   !(elem 'b "abc") !(elem '(98) "abc")
   !(eleq 98 "abc")
   ("abc" 1 = 98) (elem ("abc" 1) "abc"))
; assoc reads keys with `=`, assq with `==`
(: rows [[1.0 'float] '(b two)]
   (test
      (assoc 1 rows = [1.0 'float])
      !(assq 1 rows)
      (assoc 'b rows = '(b two)) (assq 'b rows = '(b two))
      !(assoc 'z rows) !(assq 'z rows)))
