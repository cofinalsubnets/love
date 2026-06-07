; t/infix.g — infix surface language as a test-only experiment.
; Defines a shunting-yard transformer that rewrites a flat infix
; token list to prefix s-exprs per a user-configurable fixity table,
; plus two macros:
;   (deffix sym kind prec assoc)   register a fixity entry at compile time
;   (infix EXPR...)                rewrite EXPR... to prefix at compile time
;
; Fixity entry shape: (sym kind prec assoc)
;   kind  ∈ {monadic dyadic}
;   assoc ∈ {left right}   (ignored when kind=monadic)
; A symbol may appear at most once per kind; monadic and dyadic
; entries for the same symbol coexist as separate list elements.
;
; Sub-token escapes (see rewrite_tok):
;   'X              quoted data is opaque; list literals pass through
;   (prefix X...)   strip the tag and splice the body — escape back to
;                   prefix notation, e.g. `(infix 1 + (prefix L 2 3))`
;                   → `(+ 1 (L 2 3))`
;   (infix X...)    nested infix; the body is rewritten in the current
;                   fixity table and spliced in

; ----- transformer helpers (top-level let pairs → globals) -----
(: (fixity sym kind table) (?
    (twop table) (: e (A table)
     (? (&& (= (A e) sym) (= (AB e) kind))
      e
      (fixity sym kind (B table))))
    0)
   (op_monadic sym table) (fixity sym 'monadic table)
   (op_dyadic  sym table) (fixity sym 'dyadic  table)
   (in_table sym table) (|| (op_monadic sym table) (op_dyadic sym table))
   (prec e)  (ABB e)
   (assoc e) (A (BBB e))

   ; Atoms pass through; a singleton list `(sym)` unwraps (operator-
   ; as-value escape); a quoted datum `'X` = `(` X)` is opaque so list
   ; literals survive intact; `(prefix X...)` is an escape hatch back
   ; to prefix notation — strip the tag and splice the body in as-is;
   ; `(infix X...)` recurses through this transformer so a nested
   ; infix subexpression is rewritten in the same table; everything
   ; else recurses as an infix expression.
   (rewrite_tok tok table) (?
    (atomp tok)            tok
    (nilp (B tok))       (A tok)
    (&& (= (A tok) '\) (atomp (BB tok))) tok ; one-operand \ is quote: pass through
    (= (A tok) 'prefix)  (B tok)
    (= (A tok) 'infix)   (infix_rewrite (B tok) table)
                           (infix_rewrite tok table))

   ; Greedy left-assoc juxtaposition: consume consecutive operand-ish
   ; tokens into a curried application chain. Stops at any symbol with
   ; a fixity entry. Returns (chain . remaining-tokens).
   (juxt chain tokens table) (?
    (nilp tokens) (X chain tokens)
    (: tok (A tokens)
     (? (&& (symp tok) (in_table tok table))
      (X chain tokens)
      (juxt (L chain (rewrite_tok tok table)) (B tokens) table))))

   ; Pop predicate:
   ;   monadic on top  → always pop (binds tighter than any binary push)
   ;   left-assoc binary  → pop on prec >=
   ;   right-assoc binary → pop on prec >
   (should_pop top new) (?
    (= 'monadic (AB top)) -1
    (: tp (prec top) np (prec new)
     (? (= 'left (assoc top)) (>= tp np) (> tp np))))

   ; Pop ops while pred holds. Top of out is the right operand for
   ; binary ops. Returns (new-out . new-ops).
   (apply_pops out ops pred) (?
    (&& (twop ops) (pred (A ops)))
    (: op (A ops)
       new_out (? (= 'monadic (AB op))
                (X (L (A op) (A out)) (B out))
                (X (L (A op) (AB out) (A out)) (BB out)))
     (apply_pops new_out (B ops) pred))
    (X out ops))

   (drain out ops)          (apply_pops out ops (\ _ -1))
   (pop_higher out ops new) (apply_pops out ops (\ top (should_pop top new)))

   ; Shunting-yard step. state ∈ {operand operator}.
   (sy tokens out ops state table) (?
    (nilp tokens) (A (A (drain out ops)))
    (: tok (A tokens) rest (B tokens)
     (? (= state 'operand)
      (? (&& (symp tok) (op_monadic tok table))
       (sy rest out (X (op_monadic tok table) ops) 'operand table)
       (: first (rewrite_tok tok table)
          jc    (juxt first rest table)
        (sy (B jc) (X (A jc) out) ops 'operator table)))
      (: new_op (op_dyadic tok table)
         ph    (pop_higher out ops new_op)
       (sy rest (A ph) (X new_op (B ph)) 'operand table)))))

   (infix_rewrite tokens table) (sy tokens 0 0 'operand table))

; ----- global mutable fixity registry -----
(: op_fixity 0)

; ----- deffix and (infix ...) macros -----
; Gwen's analyzer bakes known globals into compiled code as literals
; (see avb in boot.g), so the macros read op_fixity via (get 0 ... globals)
; to force a dynamic lookup each invocation rather than capturing 0 once.
(:: 'deffix (\ args
 (: _ (put 'op_fixity (X args (get 0 'op_fixity globals)) globals) 0)))
(:: 'infix (\ body (infix_rewrite body (get 0 'op_fixity globals))))

; ----- default canonical fixities -----
; Order doesn't matter — deffix prepends; lookup resolves by (sym, kind).
; Monadic - is included for structural completeness; gwen has no native
; monadic minus, so runtime use of monadic - requires the user to define
; an arity-1 negation function and re-deffix.
(deffix ^ dyadic  8 right)
(deffix / dyadic  7 left)
(deffix * dyadic  7 left)
(deffix - dyadic  6 left)
(deffix + dyadic  6 left)
(deffix - monadic 9 left)

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
  (= '((foldl 0) +)       (infix_rewrite '(foldl 0 (+)) table))
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
;     registered above ---
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
 (= 10 (: l (L 1 2 3 4) (infix foldl (+) 0 l)))
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
