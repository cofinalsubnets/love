; infix -- an entry at two or more in the `operators` table. in operand position with a
; left operand available, the sigil captures it and collects arity-1 more datums,
; nesting RIGHT-associatively (a following operator steals the nearest operand).
; with no left operand it reads as the plain symbol, so (+ 1 2) prefix, '+ quote,
; and (+)-as-a-value all keep working. parenthesized infix double-wraps -- (1 + 2)
; factors to ((+ 1 2)) -- and evaluates via (f)==f. the factoring happens at
; COMPILE time (opfix); reading is structural.
(: in-tbl operators)
(assert (mapp in-tbl) (2 = (in-tbl '+)) (2 = (in-tbl '<=)) (3 = (in-tbl '?)))

(assert
 ; basics, every seeded operator
 (3 = (1 + 2)) (-1 = (1 - 2)) (6 = (2 * 3)) (2.5 = (5 / 2))
 (1 = (3 = 3.0)) (0 = (3 = 4))
 (1 = (1 < 2)) (1 = (1 <= 1)) (1 = (2 > 1)) (1 = (2 >= 2)) (0 = (2 < 1))
 (15 = (8 | 4 | 2 | 1)) (0 = (5 & 2)) (7 = (5 | 2))
 (1 = (5 % 2)) ('% = (cabp '(5 % 2)))               ; % is plain infix at two (mod is gone); quotes stay data

 ; right-associativity; parens override
 (7 = (1 + 2 * 3))                              ; (+ 1 (* 2 3))
 (9 = ((1 + 2) * 3))
 (10 = (1 + 2 + 3 + 4))
 (1 = (5 = 2 + 3))                              ; (= 5 (+ 2 3))

 ; ? at three -- the cond form, infix
 ('a = (1 ? 'a 'b)) ('b = (0 ? 'a 'b))
 ('big = ((1 < 2) ? 'big 'small))
 (1 = (1 < 2 ? 'big 'small))                    ; right-assoc: ? takes 2 first -- paren the test

 ; chain termination: a non-operator datum folds the pending chain
 ('(3 3) = (L 1 + 2 3))                         ; (L (+ 1 2) 3)
 ('(3 9) = (L (1 + 2) (4 + 5)))

 ; operators as values and quoted operators are untouched
 (12 = (foldl (+) 0 '(3 4 5)))
 ('(1 2 3) = (sort '(3 1 2)))
 (symp '+) (7 = ((+) 3 4))

 ; composes with sigils at one ($ folds eagerly -- binds tightest -- then + steals it)
 (197 = ($"ab" + 2))

 ; the curry law: operands missing at the end of a list fold to the partial
 ; application -- for a special form like ? that is just the shorter form
 (3 = ((1 +) 2)) ('a = (1 ? 'a)))

; structural incompleteness still pends: an unclosed list comes back as the port.
; a trailing operator does NOT pend -- "1 +" is two complete datums whose factor
; folds to the partial (+ 1) at compile time, not a reader state.
(: p (sip '(40 49 32 43)) (assert (p = (read p 99))))   ; "(1 +" -> the port
(: p (sip '(49 32 43)) (assert (1 = (read p 99)) ('+ = (read p 99))))  ; "1 +" -> 1, +

; extensible with a plain pin; cleaned up after
(: ** pow)
(pin in-tbl '** 2)
(assert (8.0 = (2 ** 3)) (512.0 = (2 ** 3 ** 2)))  ; right-assoc: 2^(3^2)
(pull in-tbl '** 0)
(assert !(in-tbl '**) (symp '**))

; the accessor aliases: <- is (pin . 3), -> is (peep . 3) -- collection-first,
; (t <- k v) pins (returns the collection, so it chains), (t -> k d) peeps.
(assert
 (20 = (: t #(1 10) _ (t <- 2 20) (t -> 2 0)))   ; pin then peep, infix
 (7 = ((#() <- 'k 7) 'k))                        ; <- returns the collection
 (9 = (#(1 10) -> 2 9))                          ; -> falls back to the default
 (65 = (: b (buf 1) _ (b <- 0 65) (b -> 0 0)))  ; bufs take the same accessors
 ('pin = (cap (peep operators '<- 0)))  ; the table entries are (name . arity) aliases
 (3 = (cbp (peep operators '-> 0)))
 (symp '<-) (30 = ((->) #(3 30) 3 0))            ; escaped, -> is still peep-as-a-value
 (idp pin (<-)) (idp peep (->)) (1 = ((%) 5 2)))  ; every alias is a bound global
