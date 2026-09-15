; the operator table -- one table, `operators`, keyed by arity: the operands a sigil
; takes from the form around it. 0 is the glued lane (sigil -> the word it names), 2 is
; spaced (sigil -> band[ hand] | (name band[ hand]), an alias), -1 is spaced with no
; bound -- the clause forms ? and @ and the binder :, whose operands stay flat rather
; than spanning into one. arity 1 has a key and no walk yet. a nom lives in as many lanes
; as it has faces, and `?` is the pair -- `bit` glued, cond spaced -- so the valence law
; is the lookup. the reader is structural
; (a sigil -- a maximal all-punct token -- reads as one plain symbol); code looks
; sigils up in the table at compile time (the opfix pass). the table is opfix's
; own -- book-private since birth (the egg mops it beside pureset: a live
; pin into a compile table would poison every later compile) -- so its laws read
; through behavior: ? at its band lives in test/infixop.l, its n-ary fold in
; test/precedence.l, the nom-led alias
; shape and the band refusals in test/precedence.l's grip door, greedy longest-prefix
; factorization (the GLUED lane, arity 0) in the valence laws, and a fresh
; punct operator needs no entry at all (default dyadic; test/infixop.l's DEFAULT
; infix section).

; reading is structural: a sigil from a port is just the symbol, no table consulted
(test ('^ = (cap (sound '(94)))) ('+ = (cap (sound '(43)))))

; ^^ has no entry, and a spaced sigil never splits, so in head position it stays
; the plain symbol -- and ^ is the xor nif all along
(test (nom? '^^) ("(^^ 5)" = (show (opfix '(^^ 5))))
        (-2 = (^ 1 -1)) (6 = (^ 5 3)))

; --- the comma: the clause layer, loosest of all -----------------------------
; a lone one-char datum off the reader (never fuses, either side); within any
; list the datums split into clauses at commas, each clause factored on its
; own, the whole the `,` sequencing macro -- (a, b c) -> (, (a) (b c)) ->
; (: _ a (b c)): effects in source order, the last clause answers. empty
; clauses drop: a doubled interior comma composes to one, a leading or
; trailing comma to nothing. head position is the macro itself.
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
 ("(, (1) (2 3))" = (show (opfix '(1 , 2 3))))) ; the emission, reparsable
; effects run in source order and the last clause is the value
(: cq (tablet 0)
   (cnote v) (: _ (pin cq (tally cq) v) v)
   (: r ((cnote 'a), (cnote 'b), (cnote 'c))
      (test ('c = r) ('a = (cq 0)) ('b = (cq 1)) ('c = (cq 2)) (3 = #cq))))
; quote interiors are data: the comma stays a plain symbol, and reading is
; structural -- a lone comma off a port is just the datum
(test (3 = (tally '(1 , 2))) (', = (caup '(1 , 2)))
        (nom? ',) ("," = (string ',)) (', = (cap (sound '(44)))))
; clauses nest per list, and chain their effects in source order
(test (6 = (: t {0 1} _ ((pin t 0 2), (pin t 1 3)) ((t 0) * (t 1)))))
; the two negations, which the glaze desugars rather than calls: (!= a b) is
; (? (= a b) 0 1) and (!== a b) the same over ==. structural against identity is
; the whole of the difference, so each law needs two chains that are equal and not
; the same one.
(: a '(1 2)
   b '(1 2)
   (test
      (a = b) !(a == b)                      ; equal, not the same
      !(a != b) (a !== b)
      (a == a) !(a !== a)                    ; the same is both
      (1 != 2) (1 !== 2)                     ; two charms differ both ways
      (1 == 1) !(1 !== 1)                    ; ..and an equal charm IS the same one
      ((a != b) = 0) ((a !== b) = 1)))       ; both answer the exact booleans
; elem and eleq are the same walk under = and ==, so they part company exactly where
; those two do: a ratio coin reads in the number band, an identity compare cannot.
(: r (/// 1 1)
   (test
      (elem r '(1 2 3)) !(eleq r '(1 2 3))    ; 1/1 IS 1 by value, and is not the same word
      (elem 1 (list r 2)) !(eleq 1 (list r 2))
      (elem 'b '(a b)) (eleq 'b '(a b))       ; a nom is its own equality either way
      !(elem 'z '(a b)) !(eleq 'z '(a b))
      (elem '(1 2) '((1 2))) !(eleq '(1 2) '((1 2))))) ; two chains built apart
; elem walks a TEXT by byte, as the index lane does -- so its elements are charms, and a
; 1-byte text is not one of them. eleq is the chain walk alone and answers 0 throughout.
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
; assoc and assq are the pair-walkers of the same two questions: assoc reads keys with
; `=`, assq with `==`, so a ratio key finds a charm row only through assoc.
(: rows (list (list (/// 1 1) 'ratio) '(b two))
   (test
      (assoc 1 rows = (list (/// 1 1) 'ratio))   ; 1 IS 1/1 by value
      (nil? (assq 1 rows))                       ; ..and is not the same word
      (assoc 'b rows = '(b two)) (assq 'b rows = '(b two))
      (nil? (assoc 'z rows)) (nil? (assq 'z rows))))
