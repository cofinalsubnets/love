; a micro kanren like logic dsl with church encoded streams
(:
 (dict_has d k) (:
  (loop k ks vs) (? ks
   (? (= k (cap ks)) vs (loop k (cup ks) (cup vs))))
  (loop k (cap d) (cup d)))
 (dict_get d k) (: x (dict_has d k) (? (two? x) (cap x)))
 (dict_set d k v) (link (link k (cap d)) (link v (cup d)))
 (mintp x) (&& (nom? x) (nom? (string x)))   ; string of a named sym is its name; of a mint, itself
 (var? x) (&& (two? x) (mintp (cup x)))
 (var x) (link x (nom 0))
 empty_dict '(0)
 has_s dict_has
 ext_s dict_set
 (unord_eq a b) (&&
  (= (sat a) (sat b))
  (all (flip member? a) b))
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
  (? (nil? i) s
   (s (\ _ s)
      (stake i)
      (\ x s (link x (stake (+ -1 i) s)))))
 (smap f s)
  (s (\ _ s)
     (\ s _ m _ (m (smap f s)))
     (\ x s (sX (f x) (smap f s))))
 (sfold f z s)
  (s (\ _ z)
     (sfold f z)
     (\ x s (f x (sfold f z s))))
 slist (sfold link 0)
 (est u v s) (:
  (walk u s) (? (nil? (var? u)) u
              (: t (has_s s u)
               (? (two? t) (walk (cap t) s) u)))
  x (walk u s) y (walk v s)
  (? (= x y) (sun s)
     (var? x) (sun (ext_s s x y))
     (var? y) (sun (ext_s s y x))
     (&& (two? x) (two? y)) (et (est (cap x) (cap y)) (est (cup x) (cup y)) s)
     sno))   ; a mismatch is the EMPTY stream (sno), not 0 -- so it fails cleanly as the
             ; FIRST conjunct too (s_star sno = sno); 0 only worked as a disjunct (s_plus)
 (Run n ks g) (:
  (walk_star u s) (?
   (var? u) (: t (has_s s u) (? (two? t) (walk_star (cap t) s) u))
   (two? u) (link (walk_star (cap u) s) (walk_star (cup u) s))
   u)
  (reify st) (flip catmap ks (\ k
   (: it (has_s (link (map cap (cap st)) (cup st)) k)
    (? (two? it) `(k (walk_star (cap it) st))))))
  (map reify ((? n (stake n) slist) (g empty_dict)))))

(:: 'zz (\ x (: s (nom 0) n (nom 0) m (nom 0) y (nom 0) x2 (cap x)
 `('\ s n m y `(m `(x2 s))))))
(:: 'et (\ xs (: x (cap xs) r (cup xs)
 (foldl (\ a b `((\ a b s (s_star (a s) b)) a b)) x r))))
(:: 'vel (\ xs (: x (cap xs) r (cup xs)
 (foldl (\ a b `((\ a b s (s_plus (a s) (b s))) a b)) x r))))
(:: '\\ (\ a (link (link '\ a) (map (\ a `(var `('\ a))) (init a)))))

; --- kanren as a RING -- a goal-coin where + is disjunction, * is conjunction ---
; a goal is (\ s stream); the die's + interleaves the two goals' streams (s_plus,
; disj), its * binds the first goal's stream through the second (s_star, conj). so
; relations compose with the generic operators: (g1 + g2) is OR, (g1 * g2) is AND.
; the goal-coin is DATA (no DIE_HOT), and `load` unwraps it back to a bare goal for Run.
(: g-die (: d #(0 'goal)
            _ (pin d 1 (\ A B (coin d (\ s (s_plus ((load A) s) ((load B) s))))))   ; + = disj
            _ (pin d 2 (\ A B (coin d (\ s (s_star ((load A) s) (load B))))))         ; * = conj
            d)
   (rel goal) (coin g-die goal))                                                     ; wrap a goal

(assert
 (unord_eq '(1 2 3) '(2 1 3))
 (unord_eq '(2 1 3) (stake 3 (sX 1 (sX 2 (sX 3 sno)))))
 (unord_eq '(6 4 2) (slist (smap (* 2) (sX 1 (sX 2 (sX 3 sno))))))
 (: s1 (sX 1 (sX 2 (sX 3 sno)))
    s2 (smap (+ 3) s1)
  (unord_eq '(1 2 3 4 5 6) (slist (s_plus s1 s2))))
 (= '((a 1)) (Run 0 '(a) (\\ a (est a 1))))
 (id? () (Run 0 '(a) (\\ a (et (est a 1) (est a 2)))))
 (= '((a (1 2 (3 (4))) b (3 (4)) c 4))
    (Run 0 '(a b c) (\\ a b c (et (est a `(1 2 b))
                                  (est b `(3 `(c)))
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
 ; the ring: + is OR, * is AND over goal-coins (load unwraps the coin for Run)
 (unord_eq '((a 1) (a 2))
  (Run 0 '(a) (\\ a (load (+ (rel (est a 1)) (rel (est a 2)))))))      ; a=1 OR a=2
 (= '((a 1 b 2))
  (Run 0 '(a b) (\\ a b (load (* (rel (est a 1)) (rel (est b 2)))))))  ; a=1 AND b=2
)

; --- DEMO: relations read as algebra. `one` ties two terms (unify); + is OR, * is AND.
; so a relation is a polynomial in unifications -- facts SUM, sub-relations MULTIPLY. ---
(: one (\ u v (rel (est u v)))                          ; one u with v -- the archaic verb: unite
   ; a family db -- parent is a SUM of (a-is-X * b-is-Y) facts:
   (parent a b) (((one a 'tom) * (one b 'bob))
               + ((one a 'bob) * (one b 'cyd))
               + ((one a 'bob) * (one b 'deb)))
   (grandparent a c) (rel (\\ b (load ((parent a b) * (parent b c)))))   ; = parent * parent
   (boolean x) ((one x 0) + (one x 1))
   (assert
    (unord_eq '((k cyd) (k deb)) (Run 0 '(k) (\\ k (load (parent 'bob k)))))         ; bob's kids (OR)
    (unord_eq '((g cyd) (g deb)) (Run 0 '(g) (\\ g (load (grandparent 'tom g)))))    ; tom's grandkids
    ; SAT: a CNF formula (x|y)&(!x|z) is literally a PRODUCT of SUMS of literals
    (: sat (Run 0 '(x y z) (\\ x y z (load
              ((boolean x) * (boolean y) * (boolean z)
                * ((one x 1) + (one y 1))
                * ((one x 0) + (one z 1))))))
       _ (member? '(x 0 y 1 z 1) sat)        ; a model
       (nil? (member? '(x 0 y 0 z 1) sat)))))  ; x=0,y=0 violates (x|y) -> not a model
