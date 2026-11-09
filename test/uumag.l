; test/uumag.l -- the arithmetic under num.c's magnitudes (test/uumagvc.l): division by a named
; base, never written out, and a limb array's value as a sum. uu.l's mul and uuinf.l's order beneath

; --- division by m: x div m counts the times x mod m wraps ---
(test
 (defn un-div (pi m nat x nat nat)
   (lam m x (nat_rect (lam q nat) 0
     (lam k d (bool_rect (lam b nat) d (succ d) (natgtb m (succ (inf-mod m k)))))
     x)))
 (4 = vof 0 '(un-div 5 21))
 (0 = vof 0 '(un-div 5 4))
 ; the two steps: the remainder grows, or wraps to 0 as the quotient grows
 (defq un-dmup (pi p nat d nat r nat k nat e (paths nat (add (mul (succ p) d) r) k)
     (paths nat (add (mul (succ p) d) (succ r)) (succ k)))
   (lam p d r k e (pathscomp0 nat (add (mul (succ p) d) (succ r)) (succ (add (mul (succ p) d) r)) (succ k)
     (natplusnsm (mul (succ p) d) r)
     (maponpaths nat nat (lam z (succ z)) (add (mul (succ p) d) r) k e))))
 (defq un-dmwrap (pi p nat d nat r nat e (paths bool (natgtb (succ p) (succ r)) false) h (inf-lt r (succ p))
     (paths nat (add (mul (succ p) (succ d)) 0) (add (mul (succ p) d) (succ r))))
   (lam p d r e h
     (pathscomp0 nat (add (mul (succ p) (succ d)) 0) (mul (succ p) (succ d)) (add (mul (succ p) d) (succ r))
       (natplusr0 (mul (succ p) (succ d)))
       (pathscomp0 nat (mul (succ p) (succ d)) (add (succ p) (mul (succ p) d)) (add (mul (succ p) d) (succ r))
         (multnsm (succ p) d)
         (pathscomp0 nat (add (succ p) (mul (succ p) d)) (add (mul (succ p) d) (succ p)) (add (mul (succ p) d) (succ r))
           (natpluscomm (succ p) (mul (succ p) d))
           (maponpaths nat nat (lam z (add (mul (succ p) d) z)) (succ p) (succ r)
             (isantisymmnatleh (succ p) (succ r) e (inf-ltsu r (succ p) h))))))))
 ; m (x div m) + x mod m = x, for m past 0
 (defq un-dm (pi p nat x nat (paths nat (add (mul (succ p) (un-div (succ p) x)) (inf-mod (succ p) x)) x))
   (lam p x (nat_rect
     (lam q (paths nat (add (mul (succ p) (un-div (succ p) q)) (inf-mod (succ p) q)) q))
     (pathscomp0 nat (add (mul (succ p) 0) 0) (mul (succ p) 0) 0 (natplusr0 (mul (succ p) 0)) (natmultn0 (succ p)))
     (lam k IH (inf-case (natgtb (succ p) (succ (inf-mod (succ p) k)))
       (lam b (paths nat (add (mul (succ p) (bool_rect (lam c nat) (un-div (succ p) k) (succ (un-div (succ p) k)) b))
                             (bool_rect (lam c nat) (succ (inf-mod (succ p) k)) 0 b))
                        (succ k)))
       (lam e (un-dmup p (un-div (succ p) k) (inf-mod (succ p) k) k IH))
       (lam e (pathscomp0 nat (add (mul (succ p) (succ (un-div (succ p) k))) 0) (add (mul (succ p) (un-div (succ p) k)) (succ (inf-mod (succ p) k))) (succ k)
         (un-dmwrap p (un-div (succ p) k) (inf-mod (succ p) k) e (inf-modlt p k))
         (un-dmup p (un-div (succ p) k) (inf-mod (succ p) k) k IH)))))
     x)))
)

; --- the same for any m past 0, and what bounds a quotient ---
(test
 (defq un-dm0 (pi m nat h (inf-lt 0 m) x nat (paths nat (add (mul m (un-div m x)) (inf-mod m x)) x))
   (lam m (nat_rect (lam q (pi h (inf-lt 0 q) x nat (paths nat (add (mul q (un-div q x)) (inf-mod q x)) x)))
     (lam h x (fromempty (paths nat (add (mul 0 (un-div 0 x)) (inf-mod 0 x)) x) (nopathsfalsetotrue h)))
     (lam p u h x (un-dm p x))
     m)))
 (defq un-modlt0 (pi m nat h (inf-lt 0 m) x nat (inf-lt (inf-mod m x) m))
   (lam m (nat_rect (lam q (pi h (inf-lt 0 q) x nat (inf-lt (inf-mod q x) q)))
     (lam h x (fromempty (inf-lt (inf-mod 0 x) 0) (nopathsfalsetotrue h)))
     (lam p u h x (inf-modlt p x))
     m)))
 ; a product grows with either side
 (defq un-mulle (pi m nat a nat b nat g (inf-le a b) (inf-le (mul m a) (mul m b)))
   (lam m a b g (nat_rect (lam q (inf-le (mul q a) (mul q b)))
     (idpath false)
     (lam k IH (inf-add2 (mul k a) (mul k b) a b IH g))
     m)))
 (defq un-mulle2 (pi a nat b nat m nat g (inf-le a b) (inf-le (mul a m) (mul b m)))
   (lam a b m g (inf-letr (mul m a) (mul a m) (mul b m) (natmultcomm m a)
     (inf-letl (mul m a) (mul m b) (mul b m) (natmultcomm m b) (un-mulle m a b g)))))
 ; x below m k: its quotient below k
 (defq un-divlt (pi m nat h (inf-lt 0 m) x nat k nat g (inf-lt x (mul m k)) (inf-lt (un-div m x) k))
   (lam m h x k g (inf-case (natgtb k (un-div m x)) (lam b (paths bool b true))
     (lam e (idpath true))
     (lam e (fromempty (paths bool false true)
       (nopathstruetofalse
         (pathscomp0 bool true (natgtb x x) false
           (pathsinv0 bool (natgtb x x) true
             (inf-lttrans x (mul m k) x g
               (istransnatleh (mul m k) (mul m (un-div m x)) x (un-mulle m k (un-div m x) e)
                 (inf-letl (mul m (un-div m x)) (add (mul m (un-div m x)) (inf-mod m x)) x (un-dm0 m h x)
                   (inf-leaddr (mul m (un-div m x)) (inf-mod m x))))))
           (isreflnatleh x))))))))
)

; --- equality's small tools, and the update's two faces ---
(test
 (defq un-add2 (pi a nat a2 nat b nat b2 nat e (paths nat a a2) f (paths nat b b2) (paths nat (add a b) (add a2 b2)))
   (lam a a2 b b2 e f (pathscomp0 nat (add a b) (add a2 b) (add a2 b2)
     (maponpaths nat nat (lam z (add z b)) a a2 e) (maponpaths nat nat (lam z (add a2 z)) b b2 f))))
 (defq un-mul2 (pi a nat a2 nat b nat b2 nat e (paths nat a a2) f (paths nat b b2) (paths nat (mul a b) (mul a2 b2)))
   (lam a a2 b b2 e f (pathscomp0 nat (mul a b) (mul a2 b) (mul a2 b2)
     (maponpaths nat nat (lam z (mul z b)) a a2 e) (maponpaths nat nat (lam z (mul a2 z)) b b2 f))))
 (defq un-eqrefl (pi k nat (paths bool (inf-eqb k k) true))
   (lam k (nat_rect (lam q (paths bool (inf-eqb q q) true)) (idpath true) (lam j IH IH) k)))
 (defq un-ltne (pi x nat l nat g (inf-lt x l) (paths bool (inf-eqb l x) false))
   (lam x (nat_rect (lam q (pi l nat g (inf-lt q l) (paths bool (inf-eqb l q) false)))
     (lam l (nat_rect (lam r (pi g (inf-lt 0 r) (paths bool (inf-eqb r 0) false)))
       (lam g (fromempty (paths bool (inf-eqb 0 0) false) (nopathsfalsetotrue g)))
       (lam j u g (idpath false))
       l))
     (lam k IH l (nat_rect (lam r (pi g (inf-lt (succ k) r) (paths bool (inf-eqb r (succ k)) false)))
       (lam g (idpath false))
       (lam j u g (IH j g))
       l))
     x)))
 (defq un-sult (pi a nat b nat g (inf-le (succ a) b) (inf-lt a b))
   (lam a b g (inf-lttrans a (succ a) b (inf-lelts a a (isreflnatleh a)) g)))
 (defq un-lesu (pi a nat (inf-le a (succ a))) (lam a (natlehsucc a a (isreflnatleh a))))
 (defq un-updne (pi A (pi j nat nat) k nat v nat q nat g (inf-lt q k) (paths nat (inf-upd A k v q) (A q)))
   (lam A k v q g (maponpaths bool nat (lam b (bool_rect (lam c nat) v (A q) b)) (inf-eqb k q) false (un-ltne q k g))))
 (defq un-updeq (pi A (pi j nat nat) k nat v nat (paths nat (inf-upd A k v k) v))
   (lam A k v (maponpaths bool nat (lam b (bool_rect (lam c nat) v (A k) b)) (inf-eqb k k) true (un-eqrefl k)))))

; --- a limb array's value: the sum of A j B^j below n ---
(test
 (defn un-val (pi B nat A (pi j nat nat) n nat nat)
   (lam B A n (nat_rect (lam q nat) 0 (lam k v (add v (mul (A k) (uu-app k B)))) n)))
 (321 = vof 0 '(un-val 10 (lam j (succ j)) 3))
 ; a write at k leaves the value below k
 (defq un-valfr (pi B nat A (pi j nat nat) k nat v nat n nat g (inf-le n k)
     (paths nat (un-val B (inf-upd A k v) n) (un-val B A n)))
   (lam B A k v n (nat_rect (lam q (pi g (inf-le q k) (paths nat (un-val B (inf-upd A k v) q) (un-val B A q))))
     (lam g (idpath 0))
     (lam q IH g (un-add2 (un-val B (inf-upd A k v) q) (un-val B A q)
       (mul (inf-upd A k v q) (uu-app q B)) (mul (A q) (uu-app q B))
       (IH (istransnatleh q (succ q) k (un-lesu q) g))
       (maponpaths nat nat (lam z (mul z (uu-app q B))) (inf-upd A k v q) (A q) (un-updne A k v q (un-sult q k g)))))
     n)))
 ; and the write at k is the next term
 (defq un-valst (pi B nat A (pi j nat nat) k nat v nat
     (paths nat (un-val B (inf-upd A k v) (succ k)) (add (un-val B A k) (mul v (uu-app k B)))))
   (lam B A k v (un-add2 (un-val B (inf-upd A k v) k) (un-val B A k)
     (mul (inf-upd A k v k) (uu-app k B)) (mul v (uu-app k B))
     (un-valfr B A k v k (isreflnatleh k))
     (maponpaths nat nat (lam z (mul z (uu-app k B))) (inf-upd A k v k) v (un-updeq A k v))))))

; --- the carry's step, which every linear loop takes: s = t + c split at B, its low part the
; --- limb at P = B^i and its high part the carry at B P ---
(test
 ; (a + u) + (b + v) = (a + b) + (u + v)
 (defq un-swap4 (pi a nat u nat b nat v nat (paths nat (add (add a u) (add b v)) (add (add a b) (add u v))))
   (lam a u b v
     (pathscomp0 nat (add (add a u) (add b v)) (add a (add u (add b v))) (add (add a b) (add u v))
       (natplusassoc a u (add b v))
       (pathscomp0 nat (add a (add u (add b v))) (add a (add b (add u v))) (add (add a b) (add u v))
         (maponpaths nat nat (lam z (add a z)) (add u (add b v)) (add b (add u v))
           (pathscomp0 nat (add u (add b v)) (add (add u b) v) (add b (add u v))
             (pathsinv0 nat (add (add u b) v) (add u (add b v)) (natplusassoc u b v))
             (pathscomp0 nat (add (add u b) v) (add (add b u) v) (add b (add u v))
               (maponpaths nat nat (lam z (add z v)) (add u b) (add b u) (natpluscomm u b))
               (natplusassoc b u v))))
         (pathsinv0 nat (add (add a b) (add u v)) (add a (add b (add u v))) (natplusassoc a b (add u v)))))))
 ; the limb and the carry, back together: m P + q (B P) = s P
 (defq un-join (pi B nat h (inf-lt 0 B) s nat P nat
     (paths nat (add (mul (inf-mod B s) P) (mul (un-div B s) (mul B P))) (mul s P)))
   (lam B h s P
     (pathscomp0 nat (add (mul (inf-mod B s) P) (mul (un-div B s) (mul B P)))
                     (add (mul (inf-mod B s) P) (mul (mul B (un-div B s)) P)) (mul s P)
       (maponpaths nat nat (lam z (add (mul (inf-mod B s) P) z)) (mul (un-div B s) (mul B P)) (mul (mul B (un-div B s)) P)
         (pathscomp0 nat (mul (un-div B s) (mul B P)) (mul (mul (un-div B s) B) P) (mul (mul B (un-div B s)) P)
           (pathsinv0 nat (mul (mul (un-div B s) B) P) (mul (un-div B s) (mul B P)) (natmultassoc (un-div B s) B P))
           (maponpaths nat nat (lam z (mul z P)) (mul (un-div B s) B) (mul B (un-div B s)) (natmultcomm (un-div B s) B))))
       (pathscomp0 nat (add (mul (inf-mod B s) P) (mul (mul B (un-div B s)) P)) (mul (add (inf-mod B s) (mul B (un-div B s))) P) (mul s P)
         (pathsinv0 nat (mul (add (inf-mod B s) (mul B (un-div B s))) P) (add (mul (inf-mod B s) P) (mul (mul B (un-div B s)) P))
           (natrdistr (inf-mod B s) (mul B (un-div B s)) P))
         (maponpaths nat nat (lam z (mul z P)) (add (inf-mod B s) (mul B (un-div B s))) s
           (pathscomp0 nat (add (inf-mod B s) (mul B (un-div B s))) (add (mul B (un-div B s)) (inf-mod B s)) s
             (natpluscomm (inf-mod B s) (mul B (un-div B s)))
             (un-dm0 B h s)))))))
 ; X + c P = Y and s = t + c: X + (s mod B) P + (s div B) B P = Y + t P
 (defq un-carry (pi B nat h (inf-lt 0 B) X nat Y nat c nat t nat s nat P nat
     e (paths nat (add X (mul c P)) Y) f (paths nat s (add t c))
     (paths nat (add (add X (mul (inf-mod B s) P)) (mul (un-div B s) (mul B P))) (add Y (mul t P))))
   (lam B h X Y c t s P e f
     (pathscomp0 nat (add (add X (mul (inf-mod B s) P)) (mul (un-div B s) (mul B P)))
                     (add X (mul s P)) (add Y (mul t P))
       (pathscomp0 nat (add (add X (mul (inf-mod B s) P)) (mul (un-div B s) (mul B P)))
                       (add X (add (mul (inf-mod B s) P) (mul (un-div B s) (mul B P)))) (add X (mul s P))
         (natplusassoc X (mul (inf-mod B s) P) (mul (un-div B s) (mul B P)))
         (maponpaths nat nat (lam z (add X z)) (add (mul (inf-mod B s) P) (mul (un-div B s) (mul B P))) (mul s P)
           (un-join B h s P)))
       (pathscomp0 nat (add X (mul s P)) (add X (add (mul c P) (mul t P))) (add Y (mul t P))
         (maponpaths nat nat (lam z (add X z)) (mul s P) (add (mul c P) (mul t P))
           (pathscomp0 nat (mul s P) (mul (add t c) P) (add (mul c P) (mul t P))
             (maponpaths nat nat (lam z (mul z P)) s (add t c) f)
             (pathscomp0 nat (mul (add t c) P) (add (mul t P) (mul c P)) (add (mul c P) (mul t P))
               (natrdistr t c P) (natpluscomm (mul t P) (mul c P)))))
         (pathscomp0 nat (add X (add (mul c P) (mul t P))) (add (add X (mul c P)) (mul t P)) (add Y (mul t P))
           (pathsinv0 nat (add (add X (mul c P)) (mul t P)) (add X (add (mul c P) (mul t P))) (natplusassoc X (mul c P) (mul t P)))
           (maponpaths nat nat (lam z (add z (mul t P))) (add X (mul c P)) Y e))))))
 ; two arrays' next terms, gathered: (a + x P) + (b + y P) = (a + b) + (x + y) P
 (defq un-gather (pi a nat x nat b nat y nat P nat
     (paths nat (add (add a (mul x P)) (add b (mul y P))) (add (add a b) (mul (add x y) P))))
   (lam a x b y P
     (pathscomp0 nat (add (add a (mul x P)) (add b (mul y P))) (add (add a b) (add (mul x P) (mul y P))) (add (add a b) (mul (add x y) P))
       (un-swap4 a (mul x P) b (mul y P))
       (maponpaths nat nat (lam z (add (add a b) z)) (add (mul x P) (mul y P)) (mul (add x y) P)
         (pathsinv0 nat (mul (add x y) P) (add (mul x P) (mul y P)) (natrdistr x y P)))))))

; --- mag_add's step: what r holds and the carry, against what a and b hold ---
(test
 (defq un-addstep (pi B nat h (inf-lt 0 B) R (pi j nat nat) A (pi j nat nat) V (pi j nat nat) i nat c nat
     e (paths nat (add (un-val B R i) (mul c (uu-app i B))) (add (un-val B A i) (un-val B V i)))
     (paths nat (add (un-val B (inf-upd R i (inf-mod B (add (add (A i) (V i)) c))) (succ i)) (mul (un-div B (add (add (A i) (V i)) c)) (uu-app (succ i) B))) (add (un-val B A (succ i)) (un-val B V (succ i)))))
   (lam B h R A V i c e
     (pathscomp0 nat (add (un-val B (inf-upd R i (inf-mod B (add (add (A i) (V i)) c))) (succ i)) (mul (un-div B (add (add (A i) (V i)) c)) (uu-app (succ i) B))) (add (add (un-val B R i) (mul (inf-mod B (add (add (A i) (V i)) c)) (uu-app i B))) (mul (un-div B (add (add (A i) (V i)) c)) (mul B (uu-app i B)))) (add (un-val B A (succ i)) (un-val B V (succ i)))
       (un-add2 (un-val B (inf-upd R i (inf-mod B (add (add (A i) (V i)) c))) (succ i)) (add (un-val B R i) (mul (inf-mod B (add (add (A i) (V i)) c)) (uu-app i B)))
         (mul (un-div B (add (add (A i) (V i)) c)) (uu-app (succ i) B)) (mul (un-div B (add (add (A i) (V i)) c)) (mul B (uu-app i B)))
         (un-valst B R i (inf-mod B (add (add (A i) (V i)) c))) (idpath (mul (un-div B (add (add (A i) (V i)) c)) (mul B (uu-app i B)))))
       (pathscomp0 nat (add (add (un-val B R i) (mul (inf-mod B (add (add (A i) (V i)) c)) (uu-app i B))) (mul (un-div B (add (add (A i) (V i)) c)) (mul B (uu-app i B)))) (add (add (un-val B A i) (un-val B V i)) (mul (add (A i) (V i)) (uu-app i B))) (add (un-val B A (succ i)) (un-val B V (succ i)))
         (un-carry B h (un-val B R i) (add (un-val B A i) (un-val B V i)) c (add (A i) (V i)) (add (add (A i) (V i)) c) (uu-app i B) e (idpath (add (add (A i) (V i)) c)))
         (pathsinv0 nat (add (add (un-val B A i) (mul (A i) (uu-app i B))) (add (un-val B V i) (mul (V i) (uu-app i B)))) (add (add (un-val B A i) (un-val B V i)) (mul (add (A i) (V i)) (uu-app i B))) (un-gather (un-val B A i) (A i) (un-val B V i) (V i) (uu-app i B))))))))

; --- the bounds: a carry stays at most 1, and a limb sum fits two limbs ---
(test
 (defq un-add1 (pi b nat (paths nat (add b 1) (succ b)))
   (lam b (pathscomp0 nat (add b 1) (add (succ b) 0) (succ b) (natplusnsm b 0) (natplusr0 (succ b)))))
 (defq un-B2 (pi B nat (paths nat (mul B 2) (add B B)))
   (lam B (pathscomp0 nat (mul B 2) (add B (mul B 1)) (add B B) (multnsm B 1)
     (maponpaths nat nat (lam z (add B z)) (mul B 1) B (natmultr1 B)))))
 ; a + b + c below 2B, for limbs a, b and a carry c
 (defq un-sum3lt (pi B nat a nat b nat c nat ga (inf-lt a B) gb (inf-lt b B) gc (inf-le c 1)
     (inf-lt (add (add a b) c) (add B B)))
   (lam B a b c ga gb gc
     (inf-lttr (add a (add b c)) (add (add a b) c) (add B B)
       (pathsinv0 nat (add (add a b) c) (add a (add b c)) (natplusassoc a b c))
       (inf-lttrans (add a (add b c)) (add B (add b c)) (add B B)
         (inf-ltaddr a B (add b c) ga)
         (inf-addl B (add b c) B
           (inf-letrans (add b c) (add b 1) B (inf-addl b c 1 gc)
             (inf-letr (succ b) (add b 1) B (pathsinv0 nat (add b 1) (succ b) (un-add1 b)) (inf-ltsu b B gb))))))))
 ; below 2B: its quotient by B at most 1
 (defq un-carry1 (pi B nat h (inf-lt 0 B) s nat g (inf-lt s (add B B)) (inf-le (un-div B s) 1))
   (lam B h s g (inf-ltsle (un-div B s) 1
     (un-divlt B h s 2 (inf-lttrans s (add B B) (mul B 2) g
       (inf-letl (add B B) (add B B) (mul B 2) (pathsinv0 nat (mul B 2) (add B B) (un-B2 B)) (isreflnatleh (add B B))))))))
 ; two widths are their product
 (defq un-powadd (pi a nat b nat (paths nat (inf-pow (add a b)) (mul (inf-pow a) (inf-pow b))))
   (lam a b (nat_rect (lam q (paths nat (inf-pow (add q b)) (mul (inf-pow q) (inf-pow b))))
     (pathsinv0 nat (mul 1 (inf-pow b)) (inf-pow b) (natmultl1 (inf-pow b)))
     (lam k IH (pathscomp0 nat (inf-pow (succ (add k b))) (add (mul (inf-pow k) (inf-pow b)) (mul (inf-pow k) (inf-pow b)))
                  (mul (inf-pow (succ k)) (inf-pow b))
       (un-add2 (inf-pow (add k b)) (mul (inf-pow k) (inf-pow b)) (inf-pow (add k b)) (mul (inf-pow k) (inf-pow b)) IH IH)
       (pathsinv0 nat (mul (add (inf-pow k) (inf-pow k)) (inf-pow b)) (add (mul (inf-pow k) (inf-pow b)) (mul (inf-pow k) (inf-pow b)))
         (natrdistr (inf-pow k) (inf-pow k) (inf-pow b)))))
     a)))
 ; 2B fits two limbs, for a limb of a bit or more
 (defq un-pow2 (pi L nat g (inf-le 1 L) (inf-le 2 (inf-pow L)))
   (lam L (nat_rect (lam q (pi g (inf-le 1 q) (inf-le 2 (inf-pow q))))
     (lam g (fromempty (inf-le 2 1) (nopathstruetofalse g)))
     (lam k u g (inf-dbl 1 (inf-pow k) (inf-ltsu 0 (inf-pow k) (inf-powpos k))))
     L)))
 (defq un-2fit (pi L nat g (inf-le 1 L) (inf-le (add (inf-pow L) (inf-pow L)) (inf-pow (add L L))))
   (lam L g (inf-letl (add (inf-pow L) (inf-pow L)) (mul (inf-pow L) (inf-pow L)) (inf-pow (add L L))
     (pathsinv0 nat (inf-pow (add L L)) (mul (inf-pow L) (inf-pow L)) (un-powadd L L))
     (inf-letr (mul (inf-pow L) 2) (add (inf-pow L) (inf-pow L)) (mul (inf-pow L) (inf-pow L)) (un-B2 (inf-pow L))
       (un-mulle (inf-pow L) 2 (inf-pow L) (un-pow2 L g)))))))

; --- the same with b spent: Vm what b held, whole ---
(test
 ; (a + v) + x = (a + x) + v
 (defq un-swap3 (pi a nat v nat x nat (paths nat (add (add a v) x) (add (add a x) v)))
   (lam a v x (pathscomp0 nat (add (add a v) x) (add a (add v x)) (add (add a x) v)
     (natplusassoc a v x)
     (pathscomp0 nat (add a (add v x)) (add a (add x v)) (add (add a x) v)
       (maponpaths nat nat (lam z (add a z)) (add v x) (add x v) (natpluscomm v x))
       (pathsinv0 nat (add (add a x) v) (add a (add x v)) (natplusassoc a x v))))))
 (defq un-addstep1 (pi B nat h (inf-lt 0 B) R (pi j nat nat) A (pi j nat nat) Vm nat i nat c nat
     e (paths nat (add (un-val B R i) (mul c (uu-app i B))) (add (un-val B A i) Vm))
     (paths nat (add (un-val B (inf-upd R i (inf-mod B (add (A i) c))) (succ i)) (mul (un-div B (add (A i) c)) (uu-app (succ i) B))) (add (un-val B A (succ i)) Vm)))
   (lam B h R A Vm i c e
     (pathscomp0 nat (add (un-val B (inf-upd R i (inf-mod B (add (A i) c))) (succ i)) (mul (un-div B (add (A i) c)) (uu-app (succ i) B))) (add (add (un-val B R i) (mul (inf-mod B (add (A i) c)) (uu-app i B))) (mul (un-div B (add (A i) c)) (mul B (uu-app i B)))) (add (un-val B A (succ i)) Vm)
       (un-add2 (un-val B (inf-upd R i (inf-mod B (add (A i) c))) (succ i)) (add (un-val B R i) (mul (inf-mod B (add (A i) c)) (uu-app i B)))
         (mul (un-div B (add (A i) c)) (uu-app (succ i) B)) (mul (un-div B (add (A i) c)) (mul B (uu-app i B)))
         (un-valst B R i (inf-mod B (add (A i) c))) (idpath (mul (un-div B (add (A i) c)) (mul B (uu-app i B)))))
       (pathscomp0 nat (add (add (un-val B R i) (mul (inf-mod B (add (A i) c)) (uu-app i B))) (mul (un-div B (add (A i) c)) (mul B (uu-app i B)))) (add (add (un-val B A i) Vm) (mul (A i) (uu-app i B))) (add (un-val B A (succ i)) Vm)
         (un-carry B h (un-val B R i) (add (un-val B A i) Vm) c (A i) (add (A i) c) (uu-app i B) e (idpath (add (A i) c)))
         (un-swap3 (un-val B A i) Vm (mul (A i) (uu-app i B)))))))
)

; --- what the loops' obligations cite ---
(test
 (defq un-ltp1 (pi n nat (inf-lt n (add n 1)))
   (lam n (inf-lttrans n (succ n) (add n 1) (inf-lelts n n (isreflnatleh n))
     (inf-letl (succ n) (succ n) (add n 1) (pathsinv0 nat (add n 1) (succ n) (un-add1 n)) (isreflnatleh (succ n))))))
 (defq un-1ltB (pi L nat g (inf-le 1 L) (inf-lt 1 (inf-pow L)))
   (lam L g (inf-lttrans 1 2 (inf-pow L) (idpath true) (un-pow2 L g))))
 ; under 2B: under a dlimb's width
 (defq un-dfit (pi L nat g (inf-le 1 L) x nat h (inf-lt x (add (inf-pow L) (inf-pow L))) (inf-lt x (inf-pow (add L L))))
   (lam L g x h (inf-lttrans x (add (inf-pow L) (inf-pow L)) (inf-pow (add L L)) h (un-2fit L g))))
 ; a limb and a carry, under 2B
 (defq un-sum2lt (pi B nat h (inf-lt 0 B) a nat c nat ga (inf-lt a B) gc (inf-le c 1) (inf-lt (add a c) (add B B)))
   (lam B h a c ga gc (inf-lttrans (add a c) (add B c) (add B B) (inf-ltaddr a B c ga)
     (inf-addl B c B (inf-letrans c 1 B gc (inf-ltsu 0 B h))))))
 (defq un-sum2llt (pi B nat a nat b nat ga (inf-lt a B) gb (inf-lt b B) (inf-lt (add a b) (add B B)))
   (lam B a b ga gb (inf-lttrans (add a b) (add B b) (add B B) (inf-ltaddr a B b ga) (inf-addl B b B (inf-ltle b B gb)))))
 ; a carry under a dlimb's width
 (defq un-cfit (pi L nat g (inf-le 1 L) q nat h (inf-le q 1) (inf-lt q (inf-pow (add L L))))
   (lam L g q h (inf-lelt q 1 (inf-pow (add L L)) h (un-1ltB (add L L) (inf-letrans 1 L (add L L) g (inf-leaddr L L))))))
)

; --- cancelling a sum, for the borrow's step ---
(test
 (defq un-cancr (pi x nat y nat k nat e (paths nat (add x k) (add y k)) (paths nat x y))
   (lam x y k e (inf-addcan k x y
     (pathscomp0 nat (add k x) (add x k) (add k y) (natpluscomm k x)
       (pathscomp0 nat (add x k) (add y k) (add k y) e (natpluscomm y k))))))
 ; q at most 1: q + (1 - q) = 1
 (defq un-one (pi q nat h (inf-le q 1) (paths nat (add q (natminus 1 q)) 1))
   (lam q h (inf-addsub q 1 h)))
)
