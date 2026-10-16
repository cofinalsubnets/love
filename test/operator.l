; the operator table is opfix's own and private, keyed by arity (0 glued, 2 spaced, -1 unbounded),
; so its laws read through behaviour; the reader is structural

; reading is structural: a sigil from a port is just the symbol, no table consulted
(test ('^ = <(sound '(94))) ('+ = <(sound '(43))))

; ^^ has no entry and a spaced sigil never splits; ^ is xor
(test (nom? '^^) ("(^^ 5)" = show (opfix '(^^ 5))) (-2 = 1 ^ -1) (6 = 5 ^ 3))

; --- the comma, loosest of all: (a, b c) -> (, (a) (b c)), effects in order, the last answers.
; it never fuses, and empty clauses drop
(test
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
 ("(, (1) (2 3))" = show (opfix '(1 , 2 3)))) ; the emission, reparsable
; effects run in source order and the last clause is the value
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
      (a = b) !(a == b)                      ; equal, not the same
      !(a != b) (a !== b)
      (a == a) !(a !== a)                    ; the same is both
      (1 != 2) (1 !== 2)                     ; two charms differ both ways
      (1 == 1) !(1 !== 1)                    ; ..and an equal charm IS the same one
      ((a != b) = 0) ((a !== b) = 1)))       ; both answer the exact booleans
; elem and eleq walk under = and ==
(: r 1.0
   (test
      (elem r '(1 2 3)) !(eleq r '(1 2 3))    ; 1.0 IS 1 by value, and is not the same word
      (elem 1 [r 2]) !(eleq 1 [r 2])
      (elem 'b '(a b)) (eleq 'b '(a b))       ; a nom is its own equality either way
      !(elem 'z '(a b)) !(eleq 'z '(a b))
      (elem '(1 2) '((1 2))) !(eleq '(1 2) '((1 2))))) ; two chains built apart
; elem walks a text by byte, so its elements are charms; eleq walks chains only
(test
   (elem 98 "abc") (elem 97 "abc") (elem 99 "abc")   ; every byte, first last and middle
   !(elem 100 "abc")
   !(elem "b" "abc")                                 ; a text is no element of a text
   !(elem 98 "")                                     ; nothing is in the empty text
   (elem 10 "a\nb") (elem 0 (string 0))              ; a newline and a NUL are bytes like any
   !(elem 353 "abc") !(elem -1 "abc")                ; out of a byte's range, never in it
   !(elem 'b "abc") !(elem '(98) "abc")              ; a nom and a chain are not bytes either
   !(eleq 98 "abc")                                  ; eleq stays the chain walk
   ("abc" 1 = 98) (elem ("abc" 1) "abc"))            ; what indexing answers, elem finds
; assoc reads keys with `=`, assq with `==`
(: rows [[1.0 'float] '(b two)]
   (test
      (assoc 1 rows = [1.0 'float])         ; 1 IS 1.0 by value
      !(assq 1 rows)                             ; ..and is not the same word
      (assoc 'b rows = '(b two)) (assq 'b rows = '(b two))
      !(assoc 'z rows) !(assq 'z rows)))
