; t/infix.g — tests for the infix surface language defined in g/infix.g.
; The transformer, op_fixity, deffix, infix, and the canonical fixities
; for ^ / * - + are already in place by the time this runs.

; --- transformer in isolation, against an explicit mock table ---
; These exercise the structural rewriter without touching op_fixity.
(: table (L
   (L '+ 'dyadic  6 'left)
   (L '- 'monadic 9 'left)
   (L '- 'dyadic  6 'left)
   (L '* 'dyadic  7 'left)
   (L '/ 'dyadic  7 'left)
   (L '^ 'dyadic  8 'right))
 (assert
  (= 5                    (infix_rewrite '(5) table))
  (= 'x                   (infix_rewrite '(x) table))
  (= '(+ 2 3)             (infix_rewrite '(2 + 3) table))
  (= '(* 2 3)             (infix_rewrite '(2 * 3) table))
  (= '(+ 2 (* 3 4))       (infix_rewrite '(2 + 3 * 4) table))
  (= '(+ (* 2 3) 4)       (infix_rewrite '(2 * 3 + 4) table))
  (= '(- (- 10 3) 2)      (infix_rewrite '(10 - 3 - 2) table))
  (= '(+ (+ 1 2) 3)       (infix_rewrite '(1 + 2 + 3) table))
  (= '(^ 2 (^ 3 4))       (infix_rewrite '(2 ^ 3 ^ 4) table))
  (= '(- 5)               (infix_rewrite '(- 5) table))
  (= '(+ (- 5) 3)         (infix_rewrite '(- 5 + 3) table))
  (= '(- (- 5))           (infix_rewrite '(- - 5) table))
  (= '(+ (+ 2 (- 3)) 4)   (infix_rewrite '(2 + - 3 + 4) table))
  (= '(* (+ 1 2) 3)       (infix_rewrite '((1 + 2) * 3) table))
  (= '(* 3 (+ 1 2))       (infix_rewrite '(3 * (1 + 2)) table))
  (= '(f x)               (infix_rewrite '(f x) table))
  (= '((f x) y)           (infix_rewrite '(f x y) table))
  (= '(+ (f x) (g y))     (infix_rewrite '(f x + g y) table))
  (= '(* ((f x) y) z)     (infix_rewrite '(f x y * z) table))
  (= '((map +) xs)        (infix_rewrite '(map (+) xs) table))
  (= '((foldl +) 0)       (infix_rewrite '(foldl (+) 0) table))
  (= '(+ ((map +) xs) 1)  (infix_rewrite '((map (+) xs) + 1) table))
  ; quoted data is opaque — the inner list is not reshuffled
  (= ''(1 2 3)            (infix_rewrite '('(1 2 3)) table))
  (= '(len '(1 2 3))      (infix_rewrite '(len '(1 2 3)) table))
  ; (prefix X...) escapes back to prefix notation; the tag is stripped
  (= '(L 1 2 3)           (infix_rewrite '((prefix L 1 2 3)) table))
  (= '(+ 1 (L 2 3))       (infix_rewrite '(1 + (prefix L 2 3)) table))
  (= '(f x y)             (infix_rewrite '((prefix f x y)) table))
  ; (infix X...) recursively rewrites its body in the same fixity table
  (= '(* 2 3)             (infix_rewrite '((infix 2 * 3)) table))
  (= '(+ 1 (* 2 3))       (infix_rewrite '(1 + (infix 2 * 3)) table))
  (= '(+ (* 2 3) 1)       (infix_rewrite '((infix 2 * 3) + 1) table))))

; --- runtime tests through (infix ...), using the canonical fixities
;     that g/infix.g already registered ---
(assert
 (= 5  (infix 2 + 3))
 (= 6  (infix 2 * 3))
 (= 14 (infix 2 + 3 * 4))
 (= 10 (infix 2 * 3 + 4))
 (= 5  (infix 10 - 3 - 2))
 (= 15 (: x 10 (infix x + 5)))
 (= 50 (: x 5 y 10 (infix x * y)))
 (= 9  (infix (1 + 2) * 3))
 (= 7  (infix 3 * (1 + 2) - 2))
 (= 5  (infix (+) 2 3))
 (= 25 (: f (* 5) (infix f 4 + 5)))
 (= 10 (: l (L 1 2 3 4) (infix foldl 0 (+) l)))
 (= 3  (infix len '(1 2 3)))
 (= 3  (infix len (prefix L 1 2 3)))
 (= 7  (infix 1 + (infix 2 * 3)))
 (= 7  (infix (infix 2 * 3) + 1)))

; --- user-level deffix: register | (bitwise or) with low prec ---
(deffix | dyadic 4 left)
(assert
 (= 7 (infix 5 | 2))             ; 5 bor 2 = 7
 (= 7 (infix 5 | 2 + 1))         ; | (4) lower than + (6) → (| 5 (+ 2 1))
 (= 6 (infix 5 + 1 | 2)))        ; (| (+ 5 1) 2) = (| 6 2) = 6
