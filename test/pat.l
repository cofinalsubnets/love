(: (pat2pred p)
 (? (nomp p) (const true)
    (atomp p) (= p)
    (&& (= '\ (cap p)) (atomp (cuup p))) (= (caup p)) ; one-operand \ is quote: literal match
  (: p1 (pat2pred (cap p))
     p2 (pat2pred (cup p))
   (\ x (? (chainp x) (? (p1 (cap x)) (p2 (cup x)))))))
 (pat2x p b) (:
  t (tablet 0)

  (ff q p) (?
   (nomp p) (pin t p q)
   (chainp p) (: _ (ff (co cap q) (cap p))
                (ff (co cup q) (cup p))))
  _ (ff id p)
  ks (keys t)

  lam (link '\ (cat ks (list b)))
  y (nom 0)
  (ev (list '\ y (link lam (map (\ k (list (peep t k 0) y)) ks)))))

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
