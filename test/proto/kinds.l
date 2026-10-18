; abstract kind inference over `:` bindings by a seminaive fixpoint, the kinds-lattice the domain;
; the payoff is devirt: a +/* site with statically numeric operands skips the generic dispatch.
; a fixpoint, not a tree walk: `:` is letrec*, so kinds flow through (even cyclic) bindings. the
; lattice has finite height and the transfers are monotone, so the join-update terminates.

(:
 ; --- the domain: the tier spine N<Z<R<C, str/list incomparable, joining up to top; bot = unknown
 (rank k) (? (= k 'bot) 0 (= k 'charm) 1 (= k 'whole) 2 (= k 'real) 3 (= k 'cplx) 4 (= k 'top) 5 -1)
 (num? k) (: r (rank k) (&& (< 0 r) (< r 5)))
 (join a b) (? (= a 'bot) b (= b 'bot) a (= a b) a
              (&& (num? a) (num? b)) (? (< (rank a) (rank b)) b a)   ; the higher tier wins
              'top)                                          ; mixed branches -> top

 ; --- transfer functions: a kind for an op given its operands' kinds ---
 (tnum a b) (? (a = 'bot || b = 'bot) 'bot                 ; an operand not yet known stays bot
              (num? a && num? b) (: j (join a b) (j = 'charm ? 'whole j))  ; +/* may overflow charm
              'top)                                          ; non-numeric +/*: give up

 ; --- env: an assoc (name . kind); a missing name reads bot ---
 (look env x) (? (atom? env) 'bot (: p <env (x = <p ? >p (look >env x))))
 (joininto env x k) ((x . join (look env x) k) . env)      ; monotone shadow-update (look finds newest)

 ; --- kindof: abstract-evaluate an expression under env ---
 (kindof env e) (?
   (charm? e) 'charm
   (string? e) 'str
   (nom? e) (look env e)
   (atom? e) 'top
   (: h <e a <>e b <>>e
     (? (h = '+ || h = '*) (tnum (kindof env a) (kindof env b))
        (h = '?) (join (kindof env b) (kindof env <>>>e))   ; join the branches
        'top)))                                              ; lambda / unknown form

 ; --- the seminaive FIXPOINT over the flat (n1 e1 n2 e2 ..) binding list ---
 (pairs bs) (? (atom? bs) () (atom? >bs) () ((<bs . <>bs) . pairs >>bs))
 (alle a b) (? (atom? a) 1 (: p <a (>p = look b <p && alle >a b)))
 (enveq a b) (alle a b && alle b a)                          ; a fixpoint: same name->kind both ways
 (step ps env) (foldl (env \ p \ joininto env <p (kindof env >p)) env ps)
 (fix ps env) (: e2 (step ps env) (enveq env e2 ? env (fix ps e2)))
 (infer bs) (fix (pairs bs) 0)

 ; --- devirt: collect +/* sites whose operands are statically numeric ---
 (sites env e) (? (atom? e) 0
   (: h <e sub (catmap (s \ sites env s) >e)
      ((h = '+ || h = '*) && num? (kindof env <>e) && num? (kindof env <>>e) ? (e . sub) sub)))

 ; --- report ---
 (showenv bs) (: env (infer bs)
   (each (pairs bs) (p \ (puts "    ", dot (string <p), puts " : ", dot (string (look env <p)), putc 10)),
    (: ss (catmap (p \ sites env >p) (pairs bs))
       (puts "    devirt (numeric, skip dispatch): ", dot (show ss), putc 10))))

 _ (puts ";; A. linear chain  (: x 5 y (+ x 1) z (* y y))\n", showenv '(x 5 y (+ x 1) z (* y y)))
 _ (puts ";; B. fixpoint join (: x (? cnd 5 x))  -- x is 5-or-itself -> charm\n", showenv '(x (? cnd 5 x)))
 _ (puts ";; C. widening      (: n 100 m (+ n n) p (* m m))  -- overflow climbs charm->whole\n", showenv '(n 100 m (+ n n) p (* m m)))
 _ (puts ";; D. non-numeric   (: s \"hi\" t (+ s s))  -- + on str -> top, NOT devirt\n", showenv '(s "hi" t (+ s s)))
 0)
