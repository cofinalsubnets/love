; g/infix.g — infix surface language. Loaded after boot.g, before
; repl.g. Defines a shunting-yard transformer that rewrites a flat
; infix token list to prefix s-exprs per a user-configurable fixity
; table, plus two macros:
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

   ; Atoms pass through; a singleton list `(sym)` unwraps (operator-
   ; as-value escape); a quoted datum `'X` = `(` X)` is opaque so list
   ; literals survive intact; `(prefix X...)` is an escape hatch back
   ; to prefix notation — strip the tag and splice the body in as-is;
   ; `(infix X...)` recurses through this transformer so a nested
   ; infix subexpression is rewritten in the same table; everything
   ; else recurses as an infix expression.
   (rewrite_tok tok table) (?
    (atomp tok)            tok
    (nilp (cdr tok))       (car tok)
    (= (car tok) '`)       tok
    (= (car tok) 'prefix)  (cdr tok)
    (= (car tok) 'infix)   (infix_rewrite (cdr tok) table)
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

   ; Pop predicate:
   ;   monadic on top  → always pop (binds tighter than any binary push)
   ;   left-assoc binary  → pop on prec >=
   ;   right-assoc binary → pop on prec >
   (should_pop top new) (?
    (= 'monadic (cadr top)) -1
    (: tp (prec top) np (prec new)
     (? (= 'left (assoc top)) (>= tp np) (> tp np))))

   ; Pop ops while pred holds. Top of out is the right operand for
   ; binary ops. Returns (new-out . new-ops).
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
; unary minus, so runtime use of monadic - requires the user to define
; an arity-1 negation function and re-deffix.
(deffix ^ dyadic  8 right)
(deffix / dyadic  7 left)
(deffix * dyadic  7 left)
(deffix - dyadic  6 left)
(deffix + dyadic  6 left)
(deffix - monadic 9 left)
