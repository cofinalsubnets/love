; reader infix -- dict['infix] maps an (all-punct) SYMBOL -> arity. in operand
; position with a left operand available, the symbol captures it and collects
; arity-1 more datums, nesting RIGHT-associatively (a following operator takes
; the nearest operand). with no left operand it reads as the plain symbol, so
; (+ 1 2) prefix, '+ quote, and (+)-as-a-value all keep working. parenthesized
; infix double-wraps -- (1 + 2) reads as ((+ 1 2)) -- and evaluates via (f)==f.
(: in-tbl (peep dict 'infix 0))
(assert (mapp in-tbl) (= 2 (in-tbl '+)) (= 2 (in-tbl '<=)) (= 3 (in-tbl '?)))

(assert
 ; basics, every seeded operator
 (= 3 (1 + 2)) (= -1 (1 - 2)) (= 6 (2 * 3)) (= 2.5 (5 / 2))
 (= 1 (3 = 3.0)) (= 0 (3 = 4))
 (= 1 (1 < 2)) (= 1 (1 <= 1)) (= 1 (2 > 1)) (= 1 (2 >= 2)) (= 0 (2 < 1))
 (= 15 (8 | 4 | 2 | 1)) (= 0 (5 & 2)) (= 7 (5 | 2))
 (= 1 (5 % 2)) (= 'mod (cap (cap '(5 % 2))))        ; % is an alias entry: desugars to mod

 ; right-associativity; parens override
 (= 7 (1 + 2 * 3))                              ; (+ 1 (* 2 3))
 (= 9 ((1 + 2) * 3))
 (= 10 (1 + 2 + 3 + 4))
 (= 1 (5 = 2 + 3))                              ; (= 5 (+ 2 3))

 ; ternary ? -- the cond form, infix
 (= 'a (1 ? 'a 'b)) (= 'b (0 ? 'a 'b))
 (= 'big ((1 < 2) ? 'big 'small))
 (= 1 (1 < 2 ? 'big 'small))                    ; right-assoc: ? takes 2 first -- paren the test

 ; chain termination: a non-operator datum folds the pending chain
 (= '(3 3) (L 1 + 2 3))                         ; (L (+ 1 2) 3)
 (= '(3 9) (L (1 + 2) (4 + 5)))

 ; operators as values and quoted operators are untouched
 (= 12 (foldl (+) 0 '(3 4 5)))
 (= '(1 2 3) (sort '(3 1 2)))
 (symp '+) (= 7 ((+) 3 4))

 ; composes with prefix operators (# wraps eagerly, then + captures the result)
 (= 4 ($"ab" + 2)))

; incomplete: "(1 +" pends -> the port comes back
(: p (sip '(40 49 32 43)) (assert (= p (fread p 99))))

; extensible with a plain pin; cleaned up after
(: ** pow)
(pin in-tbl '** 2)
(assert (= 8.0 (2 ** 3)) (= 512.0 (2 ** 3 ** 2)))  ; right-assoc: 2^(3^2)
(pull in-tbl '** 0)
(assert !(in-tbl '**) (symp '**))

; the accessor aliases: <- is (pin . 3), -> is (peep . 3) -- collection-first,
; (t <- k v) pins (returns the collection, so it chains), (t -> k d) peeps.
(assert
 (= 20 (: t #(1 10) _ (t <- 2 20) (t -> 2 0)))   ; pin then peep, infix
 (= 7 ((#() <- 'k 7) 'k))                        ; <- returns the collection
 (= 9 (#(1 10) -> 2 9))                          ; -> falls back to the default
 (= 65 (: b (buf 1) _ (b <- 0 65) (b -> 0 0)))  ; bufs take the same accessors
 (= 'pin (cap (peep (peep dict 'infix 0) '<- 0)))  ; the table entries are (name . arity) aliases
 (= 3 (cbp (peep (peep dict 'infix 0) '-> 0)))
 (symp '<-) (= 30 ((->) #(3 30) 3 0))            ; escaped, -> is still peep-as-a-value
 (idp pin (<-)) (idp peep (->)) (= 1 ((%) 5 2)))  ; every alias is a bound global
