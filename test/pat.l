(: t 1) ; (evil implicit test) this checks for an obscure variable scope bug triggered by ff in pat2x ; TODO real test here
(: (pat2pred p)
 (? (symp p) (const true)
    (atomp p) (= p)
    (&& (= '\ (A p)) (atomp (BB p))) (= (AB p)) ; one-operand \ is quote: literal match
  (: p1 (pat2pred (A p))
     p2 (pat2pred (B p))
   (\ x (? (twop x) (? (p1 (A x)) (p2 (B x)))))))
 (pat2x p b) (:
  t (mapn 0)

  (ff q p) (?
   (symp p) (pin t p q)
   (twop p) (: _ (ff (co A q) (A p))
                (ff (co B q) (B p))))
  _ (ff id p)
  ks (mapk t)

  lam (X '\ (cat ks (list b)))
  y (nom 0)
  (ev (list '\ y (X lam (mapf (\ k (list (peek t k 0) y)) ks)))))

 (pmatch x1 x2 f) (:
 p (pat2pred x1)
 x (pat2x x1 x2)
 (\ y ((? (p y) x f) y)))

 (assert
 (pat2pred 1 1)
 (pat2pred '(1) '(1))
 !(pat2pred 1 2)
 !(pat2pred '(1 2) '(1 0))
 (pat2pred '(this) '(1))
 !(pat2pred '(this has five symbols though) '(1 2 3 4 5 6))
 (pat2pred ''hi 'hi)
 !(pat2pred ''hi 'hey)
 (= 7 (pmatch '(a b) '(+ a b) id '(3 4)))
 (= 8 (pmatch '(a b) '(+ a b) (const 8) 3))
 (= 93 (pmatch '(a (b c)) '(+ c (* b a)) id '(3 (30 3))))
 (= 72 (pmatch '('sum a b) '(+ a b) (pmatch '('product a b) '(* a b) id) '(sum 32 40)))
 (= 72 (pmatch '('sum a b) '(+ a b) (pmatch '('product a b) '(* a b) id) '(product 6 12)))
 ))
