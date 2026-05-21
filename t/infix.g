; t/infix.g — shunting-yard transformer for the (infix ...) surface
; language. Defines the transformer as top-level globals so the macro
; layer can reach it, then registers `op_fixity` (the global fixity
; registry), `deffix` (registers entries at expand time), and `infix`
; (rewrites its body to prefix s-exprs at expand time).

; ----- transformer (helpers become globals via top-level let pairs) -----
; Fixity entry: (sym kind prec assoc)
;   kind  ∈ {monadic dyadic}
;   assoc ∈ {left right}   (ignored for kind=monadic)
; A symbol may appear at most once per kind; monadic and dyadic entries
; for the same symbol coexist as separate list elements.
(: (fixity sym kind table) (?
    (twop table) (: e (car table)
     (? (&& (= (car e) sym) (= (cadr e) kind))
      e
      (fixity sym kind (cdr table))))
    0)
   (op_monadic sym table) (fixity sym 'monadic table)
   (op_dyadic  sym table) (fixity sym 'dyadic  table)
   (in_table sym table) (|| (op_monadic sym table) (op_dyadic sym table))
   (prec e)  (caddr e)
   (assoc e) (car (cdddr e))

   ; Atoms pass through; a singleton list `(sym)` unwraps (the operator-
   ; as-value escape); longer lists are parenthesized sub-expressions
   ; and recurse.
   (rewrite_tok tok table) (?
    (atomp tok)      tok
    (nilp (cdr tok)) (car tok)
                     (infix_rewrite tok table))

   ; Greedy left-assoc juxtaposition: consume consecutive operand-ish
   ; tokens into a curried application chain. Stops at any symbol with
   ; a fixity entry. Returns (chain . remaining-tokens).
   (juxt chain tokens table) (?
    (nilp tokens) (X chain tokens)
    (: tok (car tokens)
     (? (&& (symp tok) (in_table tok table))
      (X chain tokens)
      (juxt (L chain (rewrite_tok tok table)) (cdr tokens) table))))

   ; Pop predicate for the operator stack:
   ;   monadic on top   → always pop (binds tighter than any binary push)
   ;   left-assoc binary → pop on prec >=
   ;   right-assoc binary → pop on prec >
   (should_pop top new) (?
    (= 'monadic (cadr top)) -1
    (: tp (prec top) np (prec new)
     (? (= 'left (assoc top)) (>= tp np) (> tp np))))

   ; Pop ops while pred holds, folding them into output. Top of out is
   ; the right operand for binary ops. Returns (new-out . new-ops).
   (apply_pops out ops pred) (?
    (&& (twop ops) (pred (car ops)))
    (: op (car ops)
       new_out (? (= 'monadic (cadr op))
                (X (L (car op) (car out)) (cdr out))
                (X (L (car op) (cadr out) (car out)) (cddr out)))
     (apply_pops new_out (cdr ops) pred))
    (X out ops))

   (drain out ops)          (apply_pops out ops (\ _ -1))
   (pop_higher out ops new) (apply_pops out ops (\ top (should_pop top new)))

   ; Shunting-yard step. state ∈ {operand operator}.
   (sy tokens out ops state table) (?
    (nilp tokens) (car (car (drain out ops)))
    (: tok (car tokens) rest (cdr tokens)
     (? (= state 'operand)
      (? (&& (symp tok) (op_monadic tok table))
       (sy rest out (X (op_monadic tok table) ops) 'operand table)
       (: first (rewrite_tok tok table)
          jc    (juxt first rest table)
        (sy (cdr jc) (X (car jc) out) ops 'operator table)))
      (: new_op (op_dyadic tok table)
         ph    (pop_higher out ops new_op)
       (sy rest (car ph) (X new_op (cdr ph)) 'operand table)))))

   (infix_rewrite tokens table) (sy tokens 0 0 'operand table))

; ----- global mutable fixity registry (flat list of entries) -----
(: op_fixity 0)

; ----- deffix: register a fixity entry at macro-expand time.
; Usage: (deffix sym kind prec assoc)
;   e.g. (deffix + dyadic 6 left)
; Args are taken literally (un-evaluated); the four-list is prepended
; to op_fixity. The form expands to 0 (a runtime no-op).
;
; Note: globals known at function-compile time get baked in as literals
; (see avb in boot.g), so we go through `get` explicitly to read the
; current op_fixity each invocation rather than capturing 0 once.
(:: 'deffix (\ args
 (: _ (put 'op_fixity (X args (get 0 'op_fixity globals)) globals) 0)))

; ----- (infix EXPR...): at expand time, shunting-yard the body to a
; prefix s-expr using the current op_fixity, then splice the result
; back as this form's expansion. So (infix 2 + 3) compiles to (+ 2 3).
(:: 'infix (\ body (infix_rewrite body (get 0 'op_fixity globals))))


; =====================================================================
; Tests
; =====================================================================

; --- transformer alone, against an explicit mock table ---
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
  (= '(+ ((map +) xs) 1)  (infix_rewrite '((map (+) xs) + 1) table))))

; --- register the canonical operators into the global op_fixity ---
; deffix prepends; precedence resolves at rewrite time, so order here
; doesn't matter. Monadic - is registered for structural completeness
; even though gwen has no native unary minus — runtime tests below use
; binary - only.
(deffix ^ dyadic  8 right)
(deffix / dyadic  7 left)
(deffix * dyadic  7 left)
(deffix - dyadic  6 left)
(deffix + dyadic  6 left)
(deffix - monadic 9 left)

; --- runtime tests through the (infix ...) macro ---
(assert
 ; basic arithmetic
 (= 5  (infix 2 + 3))
 (= 6  (infix 2 * 3))
 (= 14 (infix 2 + 3 * 4))
 (= 10 (infix 2 * 3 + 4))
 (= 5  (infix 10 - 3 - 2))
 ; lexical variables resolve normally
 (= 15 (: x 10 (infix x + 5)))
 (= 50 (: x 5 y 10 (infix x * y)))
 ; parenthesized sub-expressions
 (= 9  (infix (1 + 2) * 3))
 (= 7  (infix 3 * (1 + 2) - 2))
 ; application binds tighter than infix; singleton-list operator escape
 (= 5  (infix (+) 2 3))                          ; ((+ 2) 3) = 5
 (= 25 (: f (* 5) (infix f 4 + 5)))              ; (f 4) + 5 = 20+5
 (= 10 (: l (L 1 2 3 4) (infix foldl 0 (+) l))))

; --- deffix at the user level: register | (bitwise or) with low prec ---
(deffix | dyadic 4 left)
(assert
 (= 7 (infix 5 | 2))             ; 5 bor 2 = 7
 (= 7 (infix 5 | 2 + 1))         ; | (prec 4) lower than + (prec 6) → (| 5 (+ 2 1))
 (= 6 (infix 5 + 1 | 2)))        ; → (| (+ 5 1) 2) = (| 6 2) = 6
