(: ; self evaluator test
 evr '(: ; expression for the evaluator
  (meta_eval x) (?
   (symp x) (\ l (l x))
   (not (twop x)) (const x)
   (: x0 (car x) a (cdr x)
    (? (= x0 'do) (foldl (\ a b l (do (a l) (b l))) 0 (map meta_eval a))
       (= x0 '\) (? (atomp (cdr a)) (const (car a)) ; one operand: quote
                  (foldr (\ a f l x (f (\ y (? (= y a) x (l y)))))
                         (meta_eval (last a))
                         (init a)))
       (= x0 '?) (cond_loop a id)
       (= x0 ':) (let_loop a id)
       (: y (map meta_eval x)
        (\ l (foldl id id (map (\ x (x l)) y)))))))

  (cond_loop a f) (?
   (nilp a) (cond_loop (cons 0 0) f)
   (nilp (cdr a)) (f (meta_eval (car a)))
   (: ant (meta_eval (car a)) con (meta_eval (cadr a))
    (cond_loop (cddr a) (\ alt (f (\ l (? (ant l) (con l) (alt l))))))))

  (let_loop a b m) (?
   (nilp a) (let_loop (cons 0 0) b m)
   (nilp (cdr a)) (meta_eval (car a) (b m))
   (desugar (car a) (cadr a) (\ k v
    (: t (hashn 0) (Get k) (get 0 k t) (Put v) (put 0 v t)
     (let_loop (cddr a) (\ l (do (Put (meta_eval v (b l))) l))
                        (\ x (? (= x k) (Get 0) (m x))))))))

  (desugar k v c)
   (? (twop k) (desugar (car k) (cons '\ (cat (cdr k) (X v 0))) c)
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
