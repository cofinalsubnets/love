; t/infix.g — shunting-yard transformer for the (infix ...) surface language.
; Rewrites a flat infix token list to prefix s-exprs per a user-supplied
; fixity table; the result is ordinary gwen lisp ready for ev.

(:
 ; Fixity entry: (sym kind prec assoc)
 ;   kind  ∈ {monadic dyadic}
 ;   assoc ∈ {left right}  (ignored when kind=monadic)
 ; A symbol may appear at most once per kind; the monadic and dyadic
 ; entries for the same symbol coexist as separate list elements.
 (fixity sym kind table) (?
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

 ; Token rewrite: atoms pass through, a one-element list `(sym)` unwraps
 ; (the operator-as-value escape), longer lists are parenthesized sub-
 ; expressions and recurse.
 (rewrite_tok tok table) (?
  (atomp tok)      tok
  (nilp (cdr tok)) (car tok)
                   (infix_rewrite tok table))

 ; Greedy left-assoc juxtaposition: build a curried application chain
 ; from consecutive operand-ish tokens. Stops at any symbol that has a
 ; fixity entry. Returns (chain . remaining-tokens).
 (juxt chain tokens table) (?
  (nilp tokens) (X chain tokens)
  (: tok (car tokens)
   (? (&& (symp tok) (in_table tok table))
    (X chain tokens)
    (juxt (L chain (rewrite_tok tok table)) (cdr tokens) table))))

 ; Should we pop `top` when about to push the dyadic `new`?
 ;   monadic on top: always (binds tighter than any binary push).
 ;   left-assoc binary:  pop on prec >=.
 ;   right-assoc binary: pop on prec >.
 (should_pop top new) (?
  (= 'monadic (cadr top)) -1
  (: tp (prec top) np (prec new)
   (? (= 'left (assoc top)) (>= tp np) (> tp np))))

 ; Pop ops while pred holds, folding them into the output stack.
 ; Returns (new-out . new-ops). For dyadic ops, the top of out is the
 ; right operand; the next is the left.
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

 ; Main shunting-yard step. state ∈ {operand operator}.
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

 (infix_rewrite tokens table) (sy tokens 0 0 'operand table)

 ; --- Mock fixity table for tests ---
 ; Mirrors the canonical Haskell-ish defaults: +,- left at 6;
 ; *,/ left at 7; ^ right at 8; unary - at 9.
 table (L
  (L '+ 'dyadic  6 'left)
  (L '- 'monadic 9 'left)
  (L '- 'dyadic  6 'left)
  (L '* 'dyadic  7 'left)
  (L '/ 'dyadic  7 'left)
  (L '^ 'dyadic  8 'right))

 (assert
  ; --- single tokens (degenerate) ---
  (= 5                    (infix_rewrite '(5) table))
  (= 'x                   (infix_rewrite '(x) table))
  ; --- simple binary ---
  (= '(+ 2 3)             (infix_rewrite '(2 + 3) table))
  (= '(* 2 3)             (infix_rewrite '(2 * 3) table))
  ; --- precedence ---
  (= '(+ 2 (* 3 4))       (infix_rewrite '(2 + 3 * 4) table))
  (= '(+ (* 2 3) 4)       (infix_rewrite '(2 * 3 + 4) table))
  ; --- left-assoc chains ---
  (= '(- (- 10 3) 2)      (infix_rewrite '(10 - 3 - 2) table))
  (= '(+ (+ 1 2) 3)       (infix_rewrite '(1 + 2 + 3) table))
  ; --- right-assoc chains ---
  (= '(^ 2 (^ 3 4))       (infix_rewrite '(2 ^ 3 ^ 4) table))
  ; --- monadic prefix ---
  (= '(- 5)               (infix_rewrite '(- 5) table))
  (= '(+ (- 5) 3)         (infix_rewrite '(- 5 + 3) table))
  (= '(- (- 5))           (infix_rewrite '(- - 5) table))
  (= '(+ (+ 2 (- 3)) 4)   (infix_rewrite '(2 + - 3 + 4) table))
  ; --- parenthesized sub-expressions ---
  (= '(* (+ 1 2) 3)       (infix_rewrite '((1 + 2) * 3) table))
  (= '(* 3 (+ 1 2))       (infix_rewrite '(3 * (1 + 2)) table))
  ; --- juxtaposition = left-assoc curried application, tighter than infix ---
  (= '(f x)               (infix_rewrite '(f x) table))
  (= '((f x) y)           (infix_rewrite '(f x y) table))
  (= '(+ (f x) (g y))     (infix_rewrite '(f x + g y) table))
  (= '(* ((f x) y) z)     (infix_rewrite '(f x y * z) table))
  ; --- singleton-list escape: pass an operator symbol as a value ---
  (= '((map +) xs)        (infix_rewrite '(map (+) xs) table))
  (= '((foldl +) 0)       (infix_rewrite '(foldl (+) 0) table))
  (= '(+ ((map +) xs) 1)  (infix_rewrite '((map (+) xs) + 1) table))))
