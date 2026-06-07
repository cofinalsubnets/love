(: ; self evaluator test
 evr '(: ; expression for the evaluator
  (meta_eval x) (?
   (symp x) (\ l (l x))
   (not (twop x)) (const x)
   (: x0 (A x) a (B x)
    (? (= x0 'do) (foldl (\ a b l (do (a l) (b l))) 0 (map meta_eval a))
       (= x0 '\) (? (atomp (B a)) (const (A a)) ; one operand: quote
                  (foldr (\ a f l x (f (\ y (? (= y a) x (l y)))))
                         (meta_eval (last a))
                         (init a)))
       (= x0 '?) (cond_loop a id)
       (= x0 ':) (let_loop a id)
       (: y (map meta_eval x)
        (\ l (foldl id id (map (\ x (x l)) y)))))))

  (cond_loop a f) (?
   (nilp a) (cond_loop (X 0 0) f)
   (nilp (B a)) (f (meta_eval (A a)))
   (: ant (meta_eval (A a)) con (meta_eval (AB a))
    (cond_loop (BB a) (\ alt (f (\ l (? (ant l) (con l) (alt l))))))))

  (let_loop a b m) (?
   (nilp a) (let_loop (X 0 0) b m)
   (nilp (B a)) (meta_eval (A a) (b m))
   (desugar (A a) (AB a) (\ k v
    (: t (hashn 0) (Get k) (get 0 k t) (Put v) (put 0 v t)
     (let_loop (BB a) (\ l (do (Put (meta_eval v (b l))) l))
                        (\ x (? (= x k) (Get 0) (m x))))))))

  (desugar k v c)
   (? (twop k) (desugar (A k) (X '\ (cat (B k) (X v 0))) c)
               (c k v))
  ;return
  meta_eval)
 meta_eval (ev evr)
 expr '((\ a b (: c (+ a 9) d (+ c b) (* c d))) 4 5)
 G ev
 (assert
 (= 234 (ev expr))
    (= 234 (meta_eval expr G))
    (= 234 (meta_eval evr G expr G))
    (= 234 (meta_eval evr G evr G expr G))))
