; a micro kanren like logic dsl with church encoded streams
(:
 (dict_has d k) (:
  (loop k ks vs) (? ks
   (? (= k (cap ks)) vs (loop k (cbp ks) (cbp vs))))
  (loop k (cap d) (cbp d)))
 (dict_get d k) (: x (dict_has d k) (? (twop x) (cap x)))
 (dict_set d k v) (cons (cons k (cap d)) (cons v (cbp d)))
 (anon? x) (&& (symp x) (symp (string x)))   ; string of a named sym is its name; of an anon sym, itself
 (var? x) (&& (twop x) (anon? (cbp x)))
 (var x) (cons x (nom 0))
 empty_dict '(0)
 has_s dict_has
 ext_s dict_set
 (unord_eq a b) (&&
  (= (sat a) (sat b))
  (all (flip memq a) b))
 (sX x s n m y) (y x s)
 (sno n m y) (n sno)
 (sun x) (sX x sno)
 (s_plus s t) (s (\ _ t)
             (\ s _ m _ (m (s_plus t s)))
             (\ x s (sX x (s_plus s t))))
 (s_star s g) (s (\ _ s)
             (\ s _ m _ (m (s_star s g)))
             (\ x s (s_plus (g x) (s_star s g))))
 (stake i s)
  (? (nilp i) s
   (s (\ _ s)
      (stake i)
      (\ x s (cons x (stake (+ -1 i) s)))))
 (smap f s)
  (s (\ _ s)
     (\ s _ m _ (m (smap f s)))
     (\ x s (sX (f x) (smap f s))))
 (sfold f z s)
  (s (\ _ z)
     (sfold f z)
     (\ x s (f x (sfold f z s))))
 slist (sfold cons 0)
 (est u v s) (:
  (walk u s) (? (nilp (var? u)) u
              (: t (has_s s u)
               (? (twop t) (walk (cap t) s) u)))
  x (walk u s) y (walk v s)
  (? (= x y) (sun s)
     (var? x) (sun (ext_s s x y))
     (var? y) (sun (ext_s s y x))
     (&& (twop x) (twop y)
     (et (est (cap x) (cap y)) (est (cbp x) (cbp y)) s))))
 (Run n ks g) (:
  (walk_star u s) (?
   (var? u) (: t (has_s s u) (? (twop t) (walk_star (cap t) s) u))
   (twop u) (cons (walk_star (cap u) s) (walk_star (cbp u) s))
   u)
  (reify st) (flip catmap ks (\ k
   (: it (has_s (cons (map cap (cap st)) (cbp st)) k)
    (? (twop it) (L k (walk_star (cap it) st))))))
  (map reify ((? n (stake n) slist) (g empty_dict)))))

(:: 'zz (\ x (: s (nom 0) n (nom 0) m (nom 0) y (nom 0) x2 (cap x)
 (L '\ s n m y (L m (L x2 s))))))
(:: 'et (\ xs (: x (cap xs) r (cbp xs)
 (foldl (\ a b (L (\ a b s (s_star (a s) b)) a b)) x r))))
(:: 'vel (\ xs (: x (cap xs) r (cbp xs)
 (foldl (\ a b (L (\ a b s (s_plus (a s) (b s))) a b)) x r))))
(:: '\\ (\ a (cons (cons '\ a) (map (\ a (L var (L '\ a))) (init a)))))

(assert
 (unord_eq '(1 2 3) '(2 1 3))
 (unord_eq '(2 1 3) (stake 3 (sX 1 (sX 2 (sX 3 sno)))))
 (unord_eq '(6 4 2) (slist (smap (* 2) (sX 1 (sX 2 (sX 3 sno))))))
 (: s1 (sX 1 (sX 2 (sX 3 sno)))
    s2 (smap (+ 3) s1)
  (unord_eq '(1 2 3 4 5 6) (slist (s_plus s1 s2))))
 (= '((a 1)) (Run 0 '(a) (\\ a (est a 1))))
 (= 0 (Run 0 '(a) (\\ a (et (est a 1) (est a 2)))))
 (= '((a (1 2 (3 (4))) b (3 (4)) c 4))
    (Run 0 '(a b c) (\\ a b c (et (est a (L 1 2 b))
                                  (est b (L 3 (L c)))
                                  (est c 4)))))
 (unord_eq '((a 7 b 8 c 9) (a 4 b 5 c 6) (a 1 b 2 c 3))
  (Run 0 '(a b c) (\\ a b c (vel (et (est a 1) (est b 2) (est c 3))
                                 (et (est a 4) (est b 5) (est c 6))
                                 (et (est a 7) (est b 8) (est c 9))))))
 (unord_eq '((a 0) (a 1) (a 2) (a 3) (a 4) (a 5) (a 6) (a 7) (a 8) (a 9))
  (Run 10 '(a) (\\ a
   (: (never s) ((vel (\ _ sno) (zz never)) s)
      (at_least n) (vel (est a n) (zz (at_least (+ n 1))))
    (vel never (est a 0) (at_least 1))))))
)
