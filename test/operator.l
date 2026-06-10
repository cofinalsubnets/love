; the reader's operator table -- dict['operators]: char -> name | (name . arity).
; an operator char reads its next N datums and desugars to (name d1 .. dN); the 8
; builtin sigils are seeded at arity 1. entries are live immediately: the test
; runner reads one datum at a time, so a pin in one form governs the next form.
(: op-tbl (peek dict 'operators 0))             ; leak to global scope for this file
(assert (mapp op-tbl)
 (= 'hash (op-tbl ("#" 0))) (= 'tuple (op-tbl ("@" 0))) (= 'map (op-tbl ("%" 0)))
 (= 'nilp (op-tbl ("!" 0))) (= 'dot (op-tbl ("." 0))) (= 'gsym (op-tbl ("$" 0)))
 (= 'qq (op-tbl ("`" 0))) (= (A ''x) (op-tbl ("'" 0))))

; wire ^ (xor's glyph) as a temporary dyadic operator; restored below. NB the
; (name . arity) entry is a dotted pair -- built with X, since `.` in source is
; the dot operator, not pair syntax.
(pin op-tbl ("^" 0) (X 'list 2))
(assert
 (= '(1 2) ^ 1 2)                               ; ^ a b -> (list a b)
 (= '((1 2) 3) ^ ^ 1 2 3)                       ; operands are full datums: ops nest
 (= '(5 (1 2)) (L 5 ^ 1 2))                     ; works inside lists
 (= '("a" 7) ^ "a" #"seven!!"))                 ; wrapped operands compose
(: p (strin '(94 32 49)) (assert (= p (fread p 99))))  ; "^ 1": pending operand -> incomplete

; triadic, then (name . 1) pair form
(pin op-tbl ("^" 0) (X 'L 3))
(assert (= '(1 2 3) ^ 1 2 3) (= '((1 2 3) 4 5) ^ ^ 1 2 3 4 5))
(pin op-tbl ("^" 0) (X 'inc 1))
(assert (= 6 ^ 5))

; restore: ^ is the xor nif again
(pull op-tbl ("^" 0) 0)
(assert (= -2 (^ 1 -1)) (= 6 (^ 5 3)) !(op-tbl ("^" 0)))
