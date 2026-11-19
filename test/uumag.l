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

; --- the borrow's step, which mag_sub takes: d = (a' + B) - (v' + c) split at B ---
(test
 (defq un-cancr (pi x nat y nat k nat e (paths nat (add x k) (add y k)) (paths nat x y))
   (lam x y k e (inf-addcan k x y
     (pathscomp0 nat (add k x) (add x k) (add k y) (natpluscomm k x)
       (pathscomp0 nat (add x k) (add y k) (add k y) e (natpluscomm y k))))))
 ; q at most 1: q + (1 - q) = 1
 (defq un-one (pi q nat h (inf-le q 1) (paths nat (add q (natminus 1 q)) 1))
   (lam q h (inf-addsub q 1 h)))
 ; u + s = a + B, its high part at most 1: u + (s mod B) = a + (1 - s div B) B
 (defq un-bdig (pi B nat h (inf-lt 0 B) a nat u nat s nat e (paths nat (add u s) (add a B)) g (inf-le (un-div B s) 1)
     (paths nat (add u (inf-mod B s)) (add a (mul (natminus 1 (un-div B s)) B))))
   (lam B h a u s e g (un-cancr (add u (inf-mod B s)) (add a (mul (natminus 1 (un-div B s)) B)) (mul (un-div B s) B)
     (pathscomp0 nat (add (add u (inf-mod B s)) (mul (un-div B s) B)) (add u (add (inf-mod B s) (mul (un-div B s) B))) (add (add a (mul (natminus 1 (un-div B s)) B)) (mul (un-div B s) B)) (natplusassoc u (inf-mod B s) (mul (un-div B s) B)) (pathscomp0 nat (add u (add (inf-mod B s) (mul (un-div B s) B))) (add u s) (add (add a (mul (natminus 1 (un-div B s)) B)) (mul (un-div B s) B)) (maponpaths nat nat (lam z (add u z)) (add (inf-mod B s) (mul (un-div B s) B)) s (pathscomp0 nat (add (inf-mod B s) (mul (un-div B s) B)) (add (mul (un-div B s) B) (inf-mod B s)) s (natpluscomm (inf-mod B s) (mul (un-div B s) B)) (pathscomp0 nat (add (mul (un-div B s) B) (inf-mod B s)) (add (mul B (un-div B s)) (inf-mod B s)) s (maponpaths nat nat (lam z (add z (inf-mod B s))) (mul (un-div B s) B) (mul B (un-div B s)) (natmultcomm (un-div B s) B)) (un-dm0 B h s)))) (pathscomp0 nat (add u s) (add a B) (add (add a (mul (natminus 1 (un-div B s)) B)) (mul (un-div B s) B)) e (pathscomp0 nat (add a B) (add a (mul (add (natminus 1 (un-div B s)) (un-div B s)) B)) (add (add a (mul (natminus 1 (un-div B s)) B)) (mul (un-div B s) B)) (pathsinv0 nat (add a (mul (add (natminus 1 (un-div B s)) (un-div B s)) B)) (add a (mul 1 B)) (maponpaths nat nat (lam z (add a (mul z B))) (add (natminus 1 (un-div B s)) (un-div B s)) 1 (pathscomp0 nat (add (natminus 1 (un-div B s)) (un-div B s)) (add (un-div B s) (natminus 1 (un-div B s))) 1 (natpluscomm (natminus 1 (un-div B s)) (un-div B s)) (un-one (un-div B s) g)))) (pathscomp0 nat (add a (mul (add (natminus 1 (un-div B s)) (un-div B s)) B)) (add a (add (mul (natminus 1 (un-div B s)) B) (mul (un-div B s) B))) (add (add a (mul (natminus 1 (un-div B s)) B)) (mul (un-div B s) B)) (pathsinv0 nat (add a (add (mul (natminus 1 (un-div B s)) B) (mul (un-div B s) B))) (add a (mul (add (natminus 1 (un-div B s)) (un-div B s)) B)) (maponpaths nat nat (lam z (add a z)) (add (mul (natminus 1 (un-div B s)) B) (mul (un-div B s) B)) (mul (add (natminus 1 (un-div B s)) (un-div B s)) B) (pathsinv0 nat (mul (add (natminus 1 (un-div B s)) (un-div B s)) B) (add (mul (natminus 1 (un-div B s)) B) (mul (un-div B s) B)) (natrdistr (natminus 1 (un-div B s)) (un-div B s) B)))) (pathsinv0 nat (add (add a (mul (natminus 1 (un-div B s)) B)) (mul (un-div B s) B)) (add a (add (mul (natminus 1 (un-div B s)) B) (mul (un-div B s) B))) (natplusassoc a (mul (natminus 1 (un-div B s)) B) (mul (un-div B s) B)))))))))))
 ; the borrow's step: r + v = a + c P and (v' + c) + d = a' + c' B gather to the next terms
 (defq un-bstep (pi P nat B nat Rv nat Vv nat Av nat c nat Vi nat d nat Ai nat c2 nat
     e (paths nat (add Rv Vv) (add Av (mul c P))) f (paths nat (add (add Vi c) d) (add Ai (mul c2 B)))
     (paths nat (add (add Rv (mul d P)) (add Vv (mul Vi P))) (add (add Av (mul Ai P)) (mul c2 (mul B P)))))
   (lam P B Rv Vv Av c Vi d Ai c2 e f
     (pathscomp0 nat (add (add Rv (mul d P)) (add Vv (mul Vi P))) (add (add Rv Vv) (mul (add d Vi) P)) (add (add Av (mul Ai P)) (mul c2 (mul B P))) (un-gather Rv d Vv Vi P) (pathscomp0 nat (add (add Rv Vv) (mul (add d Vi) P)) (add (add Av (mul c P)) (mul (add d Vi) P)) (add (add Av (mul Ai P)) (mul c2 (mul B P))) (maponpaths nat nat (lam z (add z (mul (add d Vi) P))) (add Rv Vv) (add Av (mul c P)) e) (pathscomp0 nat (add (add Av (mul c P)) (mul (add d Vi) P)) (add Av (add (mul c P) (mul (add d Vi) P))) (add (add Av (mul Ai P)) (mul c2 (mul B P))) (natplusassoc Av (mul c P) (mul (add d Vi) P)) (pathscomp0 nat (add Av (add (mul c P) (mul (add d Vi) P))) (add Av (mul (add c (add d Vi)) P)) (add (add Av (mul Ai P)) (mul c2 (mul B P))) (maponpaths nat nat (lam z (add Av z)) (add (mul c P) (mul (add d Vi) P)) (mul (add c (add d Vi)) P) (pathsinv0 nat (mul (add c (add d Vi)) P) (add (mul c P) (mul (add d Vi) P)) (natrdistr c (add d Vi) P))) (pathscomp0 nat (add Av (mul (add c (add d Vi)) P)) (add Av (mul (add Ai (mul c2 B)) P)) (add (add Av (mul Ai P)) (mul c2 (mul B P))) (maponpaths nat nat (lam z (add Av (mul z P))) (add c (add d Vi)) (add Ai (mul c2 B)) (pathscomp0 nat (add c (add d Vi)) (add (add c d) Vi) (add Ai (mul c2 B)) (pathsinv0 nat (add (add c d) Vi) (add c (add d Vi)) (natplusassoc c d Vi)) (pathscomp0 nat (add (add c d) Vi) (add Vi (add c d)) (add Ai (mul c2 B)) (natpluscomm (add c d) Vi) (pathscomp0 nat (add Vi (add c d)) (add (add Vi c) d) (add Ai (mul c2 B)) (pathsinv0 nat (add (add Vi c) d) (add Vi (add c d)) (natplusassoc Vi c d)) f)))) (pathscomp0 nat (add Av (mul (add Ai (mul c2 B)) P)) (add Av (add (mul Ai P) (mul (mul c2 B) P))) (add (add Av (mul Ai P)) (mul c2 (mul B P))) (maponpaths nat nat (lam z (add Av z)) (mul (add Ai (mul c2 B)) P) (add (mul Ai P) (mul (mul c2 B) P)) (natrdistr Ai (mul c2 B) P)) (pathscomp0 nat (add Av (add (mul Ai P) (mul (mul c2 B) P))) (add Av (add (mul Ai P) (mul c2 (mul B P)))) (add (add Av (mul Ai P)) (mul c2 (mul B P))) (maponpaths nat nat (lam z (add Av (add (mul Ai P) z))) (mul (mul c2 B) P) (mul c2 (mul B P)) (natmultassoc c2 B P)) (pathsinv0 nat (add (add Av (mul Ai P)) (mul c2 (mul B P))) (add Av (add (mul Ai P) (mul c2 (mul B P)))) (natplusassoc Av (mul Ai P) (mul c2 (mul B P)))))))))))))
 ; and past v's end
 (defq un-bstep1 (pi P nat B nat Rv nat Vv nat Av nat c nat d nat Ai nat c2 nat
     e (paths nat (add Rv Vv) (add Av (mul c P))) f (paths nat (add c d) (add Ai (mul c2 B)))
     (paths nat (add (add Rv (mul d P)) Vv) (add (add Av (mul Ai P)) (mul c2 (mul B P)))))
   (lam P B Rv Vv Av c d Ai c2 e f
     (pathscomp0 nat (add (add Rv (mul d P)) Vv) (add (add Rv Vv) (mul d P)) (add (add Av (mul Ai P)) (mul c2 (mul B P))) (pathsinv0 nat (add (add Rv Vv) (mul d P)) (add (add Rv (mul d P)) Vv) (un-swap3 Rv Vv (mul d P))) (pathscomp0 nat (add (add Rv Vv) (mul d P)) (add (add Av (mul c P)) (mul d P)) (add (add Av (mul Ai P)) (mul c2 (mul B P))) (maponpaths nat nat (lam z (add z (mul d P))) (add Rv Vv) (add Av (mul c P)) e) (pathscomp0 nat (add (add Av (mul c P)) (mul d P)) (add Av (add (mul c P) (mul d P))) (add (add Av (mul Ai P)) (mul c2 (mul B P))) (natplusassoc Av (mul c P) (mul d P)) (pathscomp0 nat (add Av (add (mul c P) (mul d P))) (add Av (mul (add c d) P)) (add (add Av (mul Ai P)) (mul c2 (mul B P))) (maponpaths nat nat (lam z (add Av z)) (add (mul c P) (mul d P)) (mul (add c d) P) (pathsinv0 nat (mul (add c d) P) (add (mul c P) (mul d P)) (natrdistr c d P))) (pathscomp0 nat (add Av (mul (add c d) P)) (add Av (mul (add Ai (mul c2 B)) P)) (add (add Av (mul Ai P)) (mul c2 (mul B P))) (maponpaths nat nat (lam z (add Av (mul z P))) (add c d) (add Ai (mul c2 B)) f) (pathscomp0 nat (add Av (mul (add Ai (mul c2 B)) P)) (add Av (add (mul Ai P) (mul (mul c2 B) P))) (add (add Av (mul Ai P)) (mul c2 (mul B P))) (maponpaths nat nat (lam z (add Av z)) (mul (add Ai (mul c2 B)) P) (add (mul Ai P) (mul (mul c2 B) P)) (natrdistr Ai (mul c2 B) P)) (pathscomp0 nat (add Av (add (mul Ai P) (mul (mul c2 B) P))) (add Av (add (mul Ai P) (mul c2 (mul B P)))) (add (add Av (mul Ai P)) (mul c2 (mul B P))) (maponpaths nat nat (lam z (add Av (add (mul Ai P) z))) (mul (mul c2 B) P) (mul c2 (mul B P)) (natmultassoc c2 B P)) (pathsinv0 nat (add (add Av (mul Ai P)) (mul c2 (mul B P))) (add Av (add (mul Ai P) (mul c2 (mul B P)))) (natplusassoc Av (mul Ai P) (mul c2 (mul B P)))))))))))))
 ; mag_sub's step: what r holds and the borrow, against what a and b hold
 (defq un-substep (pi B nat h (inf-lt 0 B) R (pi j nat nat) A (pi j nat nat) V (pi j nat nat) i nat c nat
     k (inf-le (add (V i) c) (add (A i) B)) g (inf-le (un-div B (natminus (add (A i) B) (add (V i) c))) 1)
     e (paths nat (add (un-val B R i) (un-val B V i)) (add (un-val B A i) (mul c (uu-app i B))))
     (paths nat (add (un-val B (inf-upd R i (inf-mod B (natminus (add (A i) B) (add (V i) c)))) (succ i)) (un-val B V (succ i))) (add (un-val B A (succ i)) (mul (natminus 1 (un-div B (natminus (add (A i) B) (add (V i) c)))) (uu-app (succ i) B)))))
   (lam B h R A V i c k g e
     (pathscomp0 nat (add (un-val B (inf-upd R i (inf-mod B (natminus (add (A i) B) (add (V i) c)))) (succ i)) (un-val B V (succ i))) (add (add (un-val B R i) (mul (inf-mod B (natminus (add (A i) B) (add (V i) c))) (uu-app i B))) (un-val B V (succ i)))
       (add (un-val B A (succ i)) (mul (natminus 1 (un-div B (natminus (add (A i) B) (add (V i) c)))) (uu-app (succ i) B)))
       (un-add2 (un-val B (inf-upd R i (inf-mod B (natminus (add (A i) B) (add (V i) c)))) (succ i)) (add (un-val B R i) (mul (inf-mod B (natminus (add (A i) B) (add (V i) c))) (uu-app i B))) (un-val B V (succ i)) (un-val B V (succ i))
         (un-valst B R i (inf-mod B (natminus (add (A i) B) (add (V i) c)))) (idpath (un-val B V (succ i))))
       (un-bstep (uu-app i B) B (un-val B R i) (un-val B V i) (un-val B A i) c (V i) (inf-mod B (natminus (add (A i) B) (add (V i) c))) (A i) (natminus 1 (un-div B (natminus (add (A i) B) (add (V i) c)))) e
         (un-bdig B h (A i) (add (V i) c) (natminus (add (A i) B) (add (V i) c)) (inf-addsub (add (V i) c) (add (A i) B) k) g)))))
 ; and past b's end, its value Vm
 (defq un-substep1 (pi B nat h (inf-lt 0 B) R (pi j nat nat) A (pi j nat nat) Vm nat i nat c nat
     k (inf-le c (add (A i) B)) g (inf-le (un-div B (natminus (add (A i) B) c)) 1)
     e (paths nat (add (un-val B R i) Vm) (add (un-val B A i) (mul c (uu-app i B))))
     (paths nat (add (un-val B (inf-upd R i (inf-mod B (natminus (add (A i) B) c))) (succ i)) Vm) (add (un-val B A (succ i)) (mul (natminus 1 (un-div B (natminus (add (A i) B) c))) (uu-app (succ i) B)))))
   (lam B h R A Vm i c k g e
     (pathscomp0 nat (add (un-val B (inf-upd R i (inf-mod B (natminus (add (A i) B) c))) (succ i)) Vm) (add (add (un-val B R i) (mul (inf-mod B (natminus (add (A i) B) c)) (uu-app i B))) Vm)
       (add (un-val B A (succ i)) (mul (natminus 1 (un-div B (natminus (add (A i) B) c))) (uu-app (succ i) B)))
       (un-add2 (un-val B (inf-upd R i (inf-mod B (natminus (add (A i) B) c))) (succ i)) (add (un-val B R i) (mul (inf-mod B (natminus (add (A i) B) c)) (uu-app i B))) Vm Vm (un-valst B R i (inf-mod B (natminus (add (A i) B) c))) (idpath Vm))
       (un-bstep1 (uu-app i B) B (un-val B R i) Vm (un-val B A i) c (inf-mod B (natminus (add (A i) B) c)) (A i) (natminus 1 (un-div B (natminus (add (A i) B) c))) e
         (un-bdig B h (A i) c (natminus (add (A i) B) c) (inf-addsub c (add (A i) B) k) g)))))
 ; a limb under B and a carry at most 1 sum to at most B
 (defq un-vcle (pi B nat a nat c nat ga (inf-lt a B) gc (inf-le c 1) (inf-le (add a c) B))
   (lam B a c ga gc (inf-letrans (add a c) (add a 1) B (inf-addl a c 1 gc) (inf-lt1 a B ga))))
 ; x < P and d < B: x + d P < B P
 (defq un-vbound (pi P nat x nat d nat B nat gx (inf-lt x P) gd (inf-lt d B) (inf-lt (add x (mul d P)) (mul B P)))
   (lam P x d B gx gd (inf-lttrans (add x (mul d P)) (add P (mul d P)) (mul B P)
     (inf-ltaddr x P (mul d P) gx)
     (inf-letr (add (mul d P) P) (add P (mul d P)) (mul B P) (natpluscomm (mul d P) P)
       (un-mulle2 (succ d) B P (inf-ltsu d B gd))))))
 ; a value below B^i, a limb written at i: below B^(i+1)
 (defq un-rbound (pi B nat R (pi j nat nat) i nat d nat g (inf-lt (un-val B R i) (uu-app i B)) gd (inf-lt d B)
     (inf-lt (un-val B (inf-upd R i d) (succ i)) (uu-app (succ i) B)))
   (lam B R i d g gd (inf-lttr (add (un-val B R i) (mul d (uu-app i B))) (un-val B (inf-upd R i d) (succ i)) (uu-app (succ i) B)
     (pathsinv0 nat (un-val B (inf-upd R i d) (succ i)) (add (un-val B R i) (mul d (uu-app i B))) (un-valst B R i d))
     (un-vbound (uu-app i B) (un-val B R i) d B g gd))))
 ; x < P and v <= a: x + v < P + a
 (defq un-ltadd2 (pi X nat P nat V nat A nat gx (inf-lt X P) gv (inf-le V A) (inf-lt (add X V) (add P A)))
   (lam X P V A gx gv (inf-lttrans (add X V) (add P V) (add P A) (inf-ltaddr X P V gx) (inf-addl P V A gv))))
 ; x + v = a + c P with x < P and v <= a: no borrow is left
 (defq un-bzero (pi P nat X nat V nat A nat c nat e (paths nat (add X V) (add A (mul c P))) gx (inf-lt X P) gv (inf-le V A)
     (paths nat c 0))
   (lam P X V A c e gx gv
     ((nat_rect (lam q (pi e (paths nat (add X V) (add A (mul q P))) (paths nat q 0)))
        (lam e (idpath 0))
        (lam k IH e (inf-ltnle (paths nat (succ k) 0) (add X V) (add A (mul (succ k) P))
          (inf-lttrans (add X V) (add P A) (add A (mul (succ k) P))
            (un-ltadd2 X P V A gx gv)
            (inf-letr (add A P) (add P A) (add A (mul (succ k) P)) (natpluscomm A P)
              (inf-addl A P (mul (succ k) P) (inf-leaddl P (mul k P)))))
          (inf-eqle (add A (mul (succ k) P)) (add X V) (pathsinv0 nat (add X V) (add A (mul (succ k) P)) e))))
        c) e)))
 ; so r + v = a
 (defq un-bdone (pi P nat X nat V nat A nat c nat e (paths nat (add X V) (add A (mul c P))) gx (inf-lt X P) gv (inf-le V A)
     (paths nat (add X V) A))
   (lam P X V A c e gx gv
     (pathscomp0 nat (add X V) (add A (mul c P)) A e
       (pathscomp0 nat (add A (mul c P)) (add A 0) A
         (maponpaths nat nat (lam z (add A (mul z P))) c 0 (un-bzero P X V A c e gx gv))
         (natplusr0 A)))))
 (defq un-ltne2 (pi x nat l nat g (inf-lt x l) (paths bool (inf-eqb x l) false))
   (lam x (nat_rect (lam q (pi l nat g (inf-lt q l) (paths bool (inf-eqb q l) false)))
     (lam l (nat_rect (lam r (pi g (inf-lt 0 r) (paths bool (inf-eqb 0 r) false)))
       (lam g (fromempty (paths bool (inf-eqb 0 0) false) (nopathsfalsetotrue g)))
       (lam j u g (idpath false))
       l))
     (lam k IH l (nat_rect (lam r (pi g (inf-lt (succ k) r) (paths bool (inf-eqb (succ k) r) false)))
       (lam g (idpath false))
       (lam j u g (IH j g))
       l))
     x)))
 ; a write at k below n: the value trades R k for x at B^k
 (defq un-updgt (pi A (pi j nat nat) k nat v nat q nat g (inf-lt k q) (paths nat (inf-upd A k v q) (A q)))
   (lam A k v q g (maponpaths bool nat (lam b (bool_rect (lam y nat) v (A q) b)) (inf-eqb k q) false (un-ltne2 k q g))))
 (defq un-valup (pi B nat R (pi j nat nat) k nat x nat n nat g (inf-lt k n)
     (paths nat (add (un-val B (inf-upd R k x) n) (mul (R k) (uu-app k B))) (add (un-val B R n) (mul x (uu-app k B)))))
   (lam B R k x n (nat_rect (lam q (pi g (inf-lt k q) (paths nat (add (un-val B (inf-upd R k x) q) (mul (R k) (uu-app k B))) (add (un-val B R q) (mul x (uu-app k B))))))
     (lam g (fromempty (paths nat (add (un-val B (inf-upd R k x) 0) (mul (R k) (uu-app k B))) (add (un-val B R 0) (mul x (uu-app k B)))) (nopathsfalsetotrue g)))
     (lam q IH g (inf-case (natgtb q k) (lam y (paths nat (add (un-val B (inf-upd R k x) (succ q)) (mul (R k) (uu-app k B))) (add (un-val B R (succ q)) (mul x (uu-app k B)))))
       (lam e (pathscomp0 nat (add (add (un-val B (inf-upd R k x) q) (mul ((inf-upd R k x) q) (uu-app q B))) (mul (R k) (uu-app k B))) (add (add (un-val B (inf-upd R k x) q) (mul (R k) (uu-app k B))) (mul ((inf-upd R k x) q) (uu-app q B))) (add (add (un-val B R q) (mul (R q) (uu-app q B))) (mul x (uu-app k B))) (pathsinv0 nat (add (add (un-val B (inf-upd R k x) q) (mul (R k) (uu-app k B))) (mul ((inf-upd R k x) q) (uu-app q B))) (add (add (un-val B (inf-upd R k x) q) (mul ((inf-upd R k x) q) (uu-app q B))) (mul (R k) (uu-app k B))) (un-swap3 (un-val B (inf-upd R k x) q) (mul (R k) (uu-app k B)) (mul ((inf-upd R k x) q) (uu-app q B)))) (pathscomp0 nat (add (add (un-val B (inf-upd R k x) q) (mul (R k) (uu-app k B))) (mul ((inf-upd R k x) q) (uu-app q B))) (add (add (un-val B R q) (mul x (uu-app k B))) (mul ((inf-upd R k x) q) (uu-app q B))) (add (add (un-val B R q) (mul (R q) (uu-app q B))) (mul x (uu-app k B))) (maponpaths nat nat (lam z (add z (mul ((inf-upd R k x) q) (uu-app q B)))) (add (un-val B (inf-upd R k x) q) (mul (R k) (uu-app k B))) (add (un-val B R q) (mul x (uu-app k B))) (IH e)) (pathscomp0 nat (add (add (un-val B R q) (mul x (uu-app k B))) (mul ((inf-upd R k x) q) (uu-app q B))) (add (add (un-val B R q) (mul x (uu-app k B))) (mul (R q) (uu-app q B))) (add (add (un-val B R q) (mul (R q) (uu-app q B))) (mul x (uu-app k B))) (maponpaths nat nat (lam z (add (add (un-val B R q) (mul x (uu-app k B))) (mul z (uu-app q B)))) ((inf-upd R k x) q) (R q) (un-updgt R k x q e)) (un-swap3 (un-val B R q) (mul x (uu-app k B)) (mul (R q) (uu-app q B)))))))
       (lam f (transportf nat (lam z (paths nat (add (un-val B (inf-upd R z x) (succ q)) (mul (R z) (uu-app z B))) (add (un-val B R (succ q)) (mul x (uu-app z B))))) q k (pathsinv0 nat k q (isantisymmnatleh k q (inf-ltsle k q g) f)) (pathscomp0 nat (add (add (un-val B (inf-upd R q x) q) (mul ((inf-upd R q x) q) (uu-app q B))) (mul (R q) (uu-app q B))) (add (add (un-val B R q) (mul x (uu-app q B))) (mul (R q) (uu-app q B))) (add (add (un-val B R q) (mul (R q) (uu-app q B))) (mul x (uu-app q B))) (maponpaths nat nat (lam z (add z (mul (R q) (uu-app q B)))) (add (un-val B (inf-upd R q x) q) (mul ((inf-upd R q x) q) (uu-app q B))) (add (un-val B R q) (mul x (uu-app q B))) (un-valst B R q x)) (un-swap3 (un-val B R q) (mul x (uu-app q B)) (mul (R q) (uu-app q B))))))))
     n)))
 ; mag_mul_add_small's step: a's value scaled by ml, the carry beside it, a0 the limbs it began with
 (defq un-mstep (pi B nat h (inf-lt 0 B) A (pi j nat nat) A0 (pi j nat nat) ml nat ad nat i nat c nat
     e (paths nat (add (un-val B A i) (mul c (uu-app i B))) (add (mul ml (un-val B A0 i)) ad)) q (paths nat (A i) (A0 i))
     (paths nat (add (un-val B (inf-upd A i (inf-mod B (add (mul (A i) ml) c))) (succ i)) (mul (un-div B (add (mul (A i) ml) c)) (uu-app (succ i) B))) (add (mul ml (un-val B A0 (succ i))) ad)))
   (lam B h A A0 ml ad i c e q
     (pathscomp0 nat (add (un-val B (inf-upd A i (inf-mod B (add (mul (A i) ml) c))) (succ i)) (mul (un-div B (add (mul (A i) ml) c)) (uu-app (succ i) B))) (add (add (un-val B A i) (mul (inf-mod B (add (mul (A i) ml) c)) (uu-app i B))) (mul (un-div B (add (mul (A i) ml) c)) (mul B (uu-app i B)))) (add (mul ml (add (un-val B A0 i) (mul (A0 i) (uu-app i B)))) ad) (un-add2 (un-val B (inf-upd A i (inf-mod B (add (mul (A i) ml) c))) (succ i)) (add (un-val B A i) (mul (inf-mod B (add (mul (A i) ml) c)) (uu-app i B))) (mul (un-div B (add (mul (A i) ml) c)) (uu-app (succ i) B)) (mul (un-div B (add (mul (A i) ml) c)) (mul B (uu-app i B))) (un-valst B A i (inf-mod B (add (mul (A i) ml) c))) (idpath (mul (un-div B (add (mul (A i) ml) c)) (mul B (uu-app i B))))) (pathscomp0 nat (add (add (un-val B A i) (mul (inf-mod B (add (mul (A i) ml) c)) (uu-app i B))) (mul (un-div B (add (mul (A i) ml) c)) (mul B (uu-app i B)))) (add (add (mul ml (un-val B A0 i)) ad) (mul (mul (A i) ml) (uu-app i B))) (add (mul ml (add (un-val B A0 i) (mul (A0 i) (uu-app i B)))) ad) (un-carry B h (un-val B A i) (add (mul ml (un-val B A0 i)) ad) c (mul (A i) ml) (add (mul (A i) ml) c) (uu-app i B) e (idpath (add (mul (A i) ml) c))) (pathscomp0 nat (add (add (mul ml (un-val B A0 i)) ad) (mul (mul (A i) ml) (uu-app i B))) (add (add (mul ml (un-val B A0 i)) ad) (mul (mul (A0 i) ml) (uu-app i B))) (add (mul ml (add (un-val B A0 i) (mul (A0 i) (uu-app i B)))) ad) (maponpaths nat nat (lam z (add (add (mul ml (un-val B A0 i)) ad) (mul (mul z ml) (uu-app i B)))) (A i) (A0 i) q) (pathscomp0 nat (add (add (mul ml (un-val B A0 i)) ad) (mul (mul (A0 i) ml) (uu-app i B))) (add (add (mul ml (un-val B A0 i)) (mul (mul (A0 i) ml) (uu-app i B))) ad) (add (mul ml (add (un-val B A0 i) (mul (A0 i) (uu-app i B)))) ad) (un-swap3 (mul ml (un-val B A0 i)) ad (mul (mul (A0 i) ml) (uu-app i B))) (pathscomp0 nat (add (add (mul ml (un-val B A0 i)) (mul (mul (A0 i) ml) (uu-app i B))) ad) (add (add (mul ml (un-val B A0 i)) (mul ml (mul (A0 i) (uu-app i B)))) ad) (add (mul ml (add (un-val B A0 i) (mul (A0 i) (uu-app i B)))) ad) (maponpaths nat nat (lam z (add (add (mul ml (un-val B A0 i)) z) ad)) (mul (mul (A0 i) ml) (uu-app i B)) (mul ml (mul (A0 i) (uu-app i B))) (pathscomp0 nat (mul (mul (A0 i) ml) (uu-app i B)) (mul (mul ml (A0 i)) (uu-app i B)) (mul ml (mul (A0 i) (uu-app i B))) (maponpaths nat nat (lam z (mul z (uu-app i B))) (mul (A0 i) ml) (mul ml (A0 i)) (natmultcomm (A0 i) ml)) (natmultassoc ml (A0 i) (uu-app i B)))) (maponpaths nat nat (lam z (add z ad)) (add (mul ml (un-val B A0 i)) (mul ml (mul (A0 i) (uu-app i B)))) (mul ml (add (un-val B A0 i) (mul (A0 i) (uu-app i B)))) (pathsinv0 nat (mul ml (add (un-val B A0 i) (mul (A0 i) (uu-app i B)))) (add (mul ml (un-val B A0 i)) (mul ml (mul (A0 i) (uu-app i B)))) (natldistr (un-val B A0 i) (mul (A0 i) (uu-app i B)) ml))))))))))
 ; a limb times a limb plus a limb fits two
 (defq un-mfit (pi B nat a nat x nat c nat ga (inf-lt a B) gx (inf-lt x B) gc (inf-lt c B) (inf-lt (add (mul a x) c) (mul B B)))
   (lam B a x c ga gx gc (inf-lttrans (add (mul a x) c) (add (mul a x) B) (mul B B)
     (inf-ltaddl (mul a x) c B gc)
     (inf-letrans (add (mul a x) B) (add (mul a B) B) (mul B B)
       (inf-addr (mul a x) (mul a B) B (un-mulle a x B (inf-ltle x B gx)))
       (un-mulle2 (succ a) B B (inf-ltsu a B ga))))))
 ; 2^(L+L) is B B
 (defq un-bbfit (pi L nat x nat g (inf-lt x (mul (inf-pow L) (inf-pow L))) (inf-lt x (inf-pow (add L L))))
   (lam L x g (transportf nat (lam z (inf-lt x z)) (mul (inf-pow L) (inf-pow L)) (inf-pow (add L L))
     (pathsinv0 nat (inf-pow (add L L)) (mul (inf-pow L) (inf-pow L)) (un-powadd L L)) g)))
 ; sums keep order
 (defq un-leadd2 (pi a nat b nat c nat d nat g (inf-le a b) h (inf-le c d) (inf-le (add a c) (add b d)))
   (lam a b c d g h (inf-letrans (add a c) (add b c) (add b d) (inf-addr a b c g)
     (transportf nat (lam z (inf-le (add b c) z)) (add d b) (add b d) (natpluscomm d b)
       (transportf nat (lam z (inf-le z (add d b))) (add c b) (add b c) (natpluscomm c b) (inf-addr c d b h))))))
 (defq un-leltadd (pi a nat b nat c nat d nat g (inf-le a b) h (inf-lt c d) (inf-lt (add a c) (add b d)))
   (lam a b c d g h (inf-lelt (add a c) (add b c) (add b d) (inf-addr a b c g) (inf-ltaddl b c d h))))
 ; a limb times a limb plus two limbs fits two: (B-1)^2 + 2(B-1) < B^2, said at B = P + 1
 (defq un-mfit3p (pi P nat a nat x nat r nat c nat ga (inf-lt a (succ P)) gx (inf-lt x (succ P)) gr (inf-lt r (succ P))
     gc (inf-lt c (succ P)) (inf-lt (add (add (mul a x) r) c) (mul (succ P) (succ P))))
   (lam P a x r c ga gx gr gc (un-leltadd (add (mul a x) r) (mul P (succ P)) c (succ P)
     (transportf nat (lam z (inf-le (add (mul a x) r) z)) (mul (succ P) P) (mul P (succ P)) (natmultcomm (succ P) P)
       (un-leadd2 (mul a x) (mul P P) r P
         (inf-letrans (mul a x) (mul P x) (mul P P) (un-mulle2 a P x (inf-ltsle a P ga)) (un-mulle P x P (inf-ltsle x P gx)))
         (inf-ltsle r P gr)))
     gc)))
 (defq un-mfit3 (pi B nat h (inf-lt 0 B) a nat x nat r nat c nat ga (inf-lt a B) gx (inf-lt x B) gr (inf-lt r B) gc (inf-lt c B)
     (inf-lt (add (add (mul a x) r) c) (mul B B)))
   (lam B h a x r c ga gx gr gc
     ((transportf nat (lam z (pi ga (inf-lt a z) gx (inf-lt x z) gr (inf-lt r z) gc (inf-lt c z) (inf-lt (add (add (mul a x) r) c) (mul z z))))
        (succ (natminus B 1)) B (inf-addsub 1 B (inf-ltsu 0 B h)) (un-mfit3p (natminus B 1) a x r c))
      ga gx gr gc)))
 ; B^(i+j) is B^i B^j
 (defq un-appadd (pi B nat i nat j nat (paths nat (uu-app (add i j) B) (mul (uu-app i B) (uu-app j B))))
   (lam B i j (nat_rect (lam q (paths nat (uu-app (add q j) B) (mul (uu-app q B) (uu-app j B))))
     (idpath (uu-app j B))
     (lam q IH (pathscomp0 nat (mul B (uu-app (add q j) B)) (mul B (mul (uu-app q B) (uu-app j B))) (mul (mul B (uu-app q B)) (uu-app j B))
       (maponpaths nat nat (lam z (mul B z)) (uu-app (add q j) B) (mul (uu-app q B) (uu-app j B)) IH)
       (pathsinv0 nat (mul (mul B (uu-app q B)) (uu-app j B)) (mul B (mul (uu-app q B) (uu-app j B))) (natmultassoc B (uu-app q B) (uu-app j B)))))
     i)))
 ; x + c P = t under P: the carry was 0
 (defq un-czero (pi X nat c nat P nat T nat e (paths nat (add X (mul c P)) T) g (inf-lt T P) (paths nat X T))
   (lam X c P T e g ((nat_rect (lam q (pi e (paths nat (add X (mul q P)) T) (paths nat X T)))
     (lam e (pathscomp0 nat X (add X 0) T (pathsinv0 nat (add X 0) X (natplusr0 X)) e))
     (lam k IH e (inf-ltnle (paths nat X T) T P g
       (transportf nat (lam z (inf-le P z)) (add X (add (mul k P) P)) T e
         (inf-letrans P (add (mul k P) P) (add X (add (mul k P) P)) (inf-leaddl P (mul k P)) (inf-leaddl (add (mul k P) P) X)))))
     c) e)))
 ; a + X B = Y B with a under B: X is Y, either way past it B too far
 (defq un-bdivu (pi B nat a nat X nat Y nat e (paths nat (add a (mul X B)) (mul Y B)) g (inf-lt a B) (paths nat X Y))
   (lam B a X Y e g (isantisymmnatleh X Y
     (inf-case (natgtb X Y) (lam y (paths bool y false))
       (lam f (inf-ltnle (paths bool true false) (mul Y B) (add (mul Y B) B)
         (inf-ltaddpos (mul Y B) B (inf-lelt 0 a B (idpath false) g))
         (inf-letrans (add (mul Y B) B) (mul X B) (mul Y B) (un-mulle2 (succ Y) X B (inf-ltsu Y X f))
           (transportf nat (lam z (inf-le (mul X B) z)) (add a (mul X B)) (mul Y B) e (inf-leaddl (mul X B) a)))))
       (lam f (idpath false)))
     (inf-case (natgtb Y X) (lam y (paths bool y false))
       (lam f (inf-ltnle (paths bool true false) (mul Y B) (add (mul X B) B)
         (transportf nat (lam z (inf-lt z (add (mul X B) B))) (add a (mul X B)) (mul Y B) e
           (transportf nat (lam z (inf-lt (add a (mul X B)) z)) (add B (mul X B)) (add (mul X B) B) (natpluscomm B (mul X B))
             (inf-ltaddr a B (mul X B) g)))
         (un-mulle2 (succ X) Y B (inf-ltsu X Y f))))
       (lam f (idpath false))))))
 ; a multiple of B leaves nothing under it
 (defq un-modmulB (pi B nat h (inf-lt 0 B) x nat (paths nat (inf-mod B (mul x B)) 0))
   (lam B h x
     (un-cancr (inf-mod B (mul x B)) 0 (mul x B)
       (transportf nat (lam z (paths nat (add (inf-mod B (mul x B)) (mul z B)) (mul x B))) (un-div B (mul x B)) x
         (un-bdivu B (inf-mod B (mul x B)) (un-div B (mul x B)) x
           (pathscomp0 nat (add (inf-mod B (mul x B)) (mul (un-div B (mul x B)) B)) (add (mul B (un-div B (mul x B))) (inf-mod B (mul x B))) (mul x B)
             (pathscomp0 nat (add (inf-mod B (mul x B)) (mul (un-div B (mul x B)) B)) (add (mul (un-div B (mul x B)) B) (inf-mod B (mul x B))) (add (mul B (un-div B (mul x B))) (inf-mod B (mul x B)))
               (natpluscomm (inf-mod B (mul x B)) (mul (un-div B (mul x B)) B))
               (maponpaths nat nat (lam z (add z (inf-mod B (mul x B)))) (mul (un-div B (mul x B)) B) (mul B (un-div B (mul x B))) (natmultcomm (un-div B (mul x B)) B)))
             (un-dm0 B h (mul x B)))
           (un-modlt0 B h (mul x B)))
         (pathscomp0 nat (add (inf-mod B (mul x B)) (mul (un-div B (mul x B)) B)) (add (mul B (un-div B (mul x B))) (inf-mod B (mul x B))) (mul x B)
           (pathscomp0 nat (add (inf-mod B (mul x B)) (mul (un-div B (mul x B)) B)) (add (mul (un-div B (mul x B)) B) (inf-mod B (mul x B))) (add (mul B (un-div B (mul x B))) (inf-mod B (mul x B)))
             (natpluscomm (inf-mod B (mul x B)) (mul (un-div B (mul x B)) B))
             (maponpaths nat nat (lam z (add z (inf-mod B (mul x B)))) (mul (un-div B (mul x B)) B) (mul B (un-div B (mul x B))) (natmultcomm (un-div B (mul x B)) B)))
           (un-dm0 B h (mul x B)))))))
)

(test
 ; --- comparing values from the top limb: mag_ge's lemmas ---
 (defq un-predlt (pi i nat h (inf-le 1 i) (inf-lt (natminus i 1) i))
   (lam i h (transportf nat (lam z (inf-lt (natminus i 1) z)) (succ (natminus i 1)) i (inf-addsub 1 i h)
     (un-sult (natminus i 1) (succ (natminus i 1)) (isreflnatleh (succ (natminus i 1)))))))
 ; limbs under B: the value is under B^n
 (defq un-vallt (pi B nat A (pi j nat nat) n nat g (pi j nat (inf-lt (A j) B)) (inf-lt (un-val B A n) (uu-app n B)))
   (lam B A n g (nat_rect (lam q (inf-lt (un-val B A q) (uu-app q B)))
     (idpath true)
     (lam q IH (un-vbound (uu-app q B) (un-val B A q) (A q) B IH (g q)))
     n)))
 ; a limb at least 1 at k: the value through k is at least B^k
 (defq un-valge1 (pi B nat A (pi j nat nat) k nat g (inf-lt 0 (A k)) (inf-le (uu-app k B) (un-val B A (succ k))))
   (lam B A k g (inf-letrans (uu-app k B) (mul (A k) (uu-app k B)) (un-val B A (succ k))
     (un-mulle2 1 (A k) (uu-app k B) (inf-ltsu 0 (A k) g))
     (inf-leaddl (mul (A k) (uu-app k B)) (un-val B A k)))))
 ; B^m <= B^k for m <= k
 (defq un-appmono (pi B nat h (inf-lt 0 B) m nat k nat g (inf-le m k) (inf-le (uu-app m B) (uu-app k B)))
   (lam B h m k ((nat_rect (lam q (pi m nat g (inf-le m q) (inf-le (uu-app m B) (uu-app q B))))
     (lam m g (transportf nat (lam z (inf-le (uu-app z B) 1)) 0 m (pathsinv0 nat m 0 (isantisymmnatleh m 0 g (idpath false))) (isreflnatleh 1)))
     (lam q IH m g (inf-case (natgtb m q) (lam y (inf-le (uu-app m B) (uu-app (succ q) B)))
       (lam e (transportf nat (lam z (inf-le (uu-app z B) (uu-app (succ q) B))) (succ q) m
         (pathsinv0 nat m (succ q) (isantisymmnatleh m (succ q) g (inf-ltsu q m e))) (isreflnatleh (uu-app (succ q) B))))
       (lam e (inf-letrans (uu-app m B) (uu-app q B) (uu-app (succ q) B) (IH m e)
         (un-mulle2 1 B (uu-app q B) (inf-ltsu 0 B h))))))
     k) m)))
 ; v k < a k, limbs under B: the value through k is less
 (defq un-lexlt (pi B nat A (pi j nat nat) V (pi j nat nat) k nat gV (pi j nat (inf-lt (V j) B)) g (inf-lt (V k) (A k))
     (inf-lt (un-val B V (succ k)) (un-val B A (succ k))))
   (lam B A V k gV g (inf-lttrans (un-val B V (succ k)) (add (uu-app k B) (mul (V k) (uu-app k B))) (un-val B A (succ k))
     (inf-ltaddr (un-val B V k) (uu-app k B) (mul (V k) (uu-app k B)) (un-vallt B V k gV))
     (inf-letr (add (mul (V k) (uu-app k B)) (uu-app k B)) (add (uu-app k B) (mul (V k) (uu-app k B))) (un-val B A (succ k)) (natpluscomm (mul (V k) (uu-app k B)) (uu-app k B))
       (inf-letrans (mul (succ (V k)) (uu-app k B)) (mul (A k) (uu-app k B)) (un-val B A (succ k))
         (un-mulle2 (succ (V k)) (A k) (uu-app k B) (inf-ltsu (V k) (A k) g))
         (inf-leaddl (mul (A k) (uu-app k B)) (un-val B A k)))))))
 ; x + a = y + b and a < b: y < x
 (defq un-cancle (pi X nat Y nat a nat b nat e (paths nat (add X a) (add Y b)) h (inf-lt a b) (inf-lt Y X))
   (lam X Y a b e h (inf-ltcan a Y X (inf-ltcong (add Y a) (add a Y) (add Y b) (add a X) (natpluscomm Y a)
     (pathscomp0 nat (add Y b) (add X a) (add a X) (pathsinv0 nat (add X a) (add Y b) e) (natpluscomm X a))
     (inf-ltaddl Y a b h)))))
 ; x + (a + t) = y + (b + t): x + a = y + b
 (defq un-cancmid (pi X nat a nat Y nat b nat t nat e (paths nat (add X (add a t)) (add Y (add b t))) (paths nat (add X a) (add Y b)))
   (lam X a Y b t e (un-cancr (add X a) (add Y b) t
     (pathscomp0 nat (add (add X a) t) (add X (add a t)) (add (add Y b) t) (natplusassoc X a t)
       (pathscomp0 nat (add X (add a t)) (add Y (add b t)) (add (add Y b) t) e
         (pathsinv0 nat (add (add Y b) t) (add Y (add b t)) (natplusassoc Y b t)))))))
 ; a <= b, a != b: a < b
 (defq un-lene (pi a nat b nat g (inf-le a b) n (pi e (paths nat a b) empty) (inf-lt a b))
   (lam a b g n (inf-case (natgtb b a) (lam y (paths bool y true))
     (lam e (idpath true))
     (lam e (fromempty (paths bool false true) (n (isantisymmnatleh a b g e)))))))
 (defq un-10 (pi P UU g (paths nat 1 0) P)
   (lam P g (fromempty P (nopathstruetofalse (maponpaths nat bool (lam z (natgtb z 0)) 1 0 g)))))
 (defq un-01 (pi P UU g (paths nat 0 1) P)
   (lam P g (fromempty P (nopathsfalsetotrue (maponpaths nat bool (lam z (natgtb z 0)) 0 1 g)))))
 ; the normaliser's swaps: x + (y + r) = y + (x + r), and as products
 (defq un-pswap (pi x nat y nat r nat (paths nat (add x (add y r)) (add y (add x r))))
   (lam x y r (pathscomp0 nat (add x (add y r)) (add (add x y) r) (add y (add x r))
     (pathsinv0 nat (add (add x y) r) (add x (add y r)) (natplusassoc x y r))
     (pathscomp0 nat (add (add x y) r) (add (add y x) r) (add y (add x r))
       (maponpaths nat nat (lam z (add z r)) (add x y) (add y x) (natpluscomm x y))
       (natplusassoc y x r)))))
 (defq un-mswap (pi x nat y nat r nat (paths nat (mul x (mul y r)) (mul y (mul x r))))
   (lam x y r (pathscomp0 nat (mul x (mul y r)) (mul (mul x y) r) (mul y (mul x r))
     (pathsinv0 nat (mul (mul x y) r) (mul x (mul y r)) (natmultassoc x y r))
     (pathscomp0 nat (mul (mul x y) r) (mul (mul y x) r) (mul y (mul x r))
       (maponpaths nat nat (lam z (mul z r)) (mul x y) (mul y x) (natmultcomm x y))
       (natmultassoc y x r)))))
 ; --- divstep's lemmas ---
 ; a limb written under B keeps every limb under B
 (defq un-updlt (pi B nat R (pi j nat nat) k nat x nat g (pi j nat (inf-lt (R j) B)) gx (inf-lt x B)
     (pi j nat (inf-lt (inf-upd R k x j) B)))
   (lam B R k x g gx (lam j (inf-case (inf-eqb k j) (lam y (inf-lt (bool_rect (lam b nat) x (R j) y) B))
     (lam e gx)
     (lam e (g j))))))
 ; x + q v = a + b P with x < P and b > 0: q >= 1
 (defq un-qpos (pi P nat X nat Q nat V nat A nat b nat e (paths nat (add X (mul Q V)) (add A (mul b P)))
     gx (inf-lt X P) gb (inf-lt 0 b) (inf-le 1 Q))
   (lam P X Q V A b e gx gb
     ((nat_rect (lam q (pi e (paths nat (add X (mul q V)) (add A (mul b P))) (inf-le 1 q)))
        (lam e (inf-ltnle (inf-le 1 0) X (add A (mul b P))
          (inf-lttrans X P (add A (mul b P)) gx
            (inf-letrans P (mul b P) (add A (mul b P)) (un-mulle2 1 b P (inf-ltsu 0 b gb)) (inf-leaddl (mul b P) A)))
          (inf-eqle (add A (mul b P)) X
            (pathscomp0 nat (add A (mul b P)) (add X 0) X (pathsinv0 nat (add X 0) (add A (mul b P)) e) (natplusr0 X)))))
        (lam k IH e (idpath false))
        Q) e)))
 ; a v <= x < B v: a < B
 (defq un-qlt (pi a nat V nat X nat B nat g (inf-le (mul a V) X) h (inf-lt X (mul B V)) (inf-lt a B))
   (lam a V X B g h (inf-case (natgtb B a) (lam y (paths bool y true))
     (lam e (idpath true))
     (lam e (inf-ltnle (paths bool false true) X (mul B V) h
       (inf-letrans (mul B V) (mul a V) X (un-mulle2 B a V e) g))))))
 ; limbs equal below n: values equal
 (defq un-valcong (pi B nat A (pi j nat nat) A2 (pi j nat nat) n nat e (pi j nat (paths nat (A j) (A2 j)))
     (paths nat (un-val B A n) (un-val B A2 n)))
   (lam B A A2 n e (nat_rect (lam q (paths nat (un-val B A q) (un-val B A2 q)))
     (idpath 0)
     (lam q IH (un-add2 (un-val B A q) (un-val B A2 q) (mul (A q) (uu-app q B)) (mul (A2 q) (uu-app q B)) IH
       (maponpaths nat nat (lam z (mul z (uu-app q B))) (A q) (A2 q) (e q))))
     n)))
)

; --- the reflective ring: an expression over atom indices, its normal form, and soundness ---
(test
 (defind rexl () () (rexl0 () rexl) (rexl1 (k nat t rexl) rexl))
 (defind rexp () () (rexp0 () rexp) (rexp1 (m rexl t rexp) rexp))
 (defind rex () () (rexv (k nat) rex) (rexz () rex) (rexo () rex) (rexa (a rex b rex) rex) (rexm (a rex b rex) rex))
 (defn rex-nth (pi e rexl k nat nat)
   (lam e (rexl_rect (lam q (pi k nat nat)) (lam k 0) (lam x t ih (lam k (nat_rect (lam q nat) x (lam j r (ih j)) k))) e)))
 (defn rex-mev (pi e rexl m rexl nat) (lam e m (rexl_rect (lam q nat) 1 (lam k t ih (mul (rex-nth e k) ih)) m)))
 (defn rex-pev (pi e rexl p rexp nat) (lam e p (rexp_rect (lam q nat) 0 (lam m t ih (add (rex-mev e m) ih)) p)))
 (defn rex-ev (pi e rexl x rex nat)
   (lam e x (rex_rect (lam q nat) (lam k (rex-nth e k)) 0 1 (lam a ia b ib (add ia ib)) (lam a ia b ib (mul ia ib)) x)))
 ; monomials ascend by index, a polynomial by rex-mlt, lexicographic
 (defn rex-mlt (pi a rexl b rexl bool)
   (lam a (rexl_rect (lam q (pi b rexl bool))
            (lam b (rexl_rect (lam q bool) false (lam j u iu true) b))
            (lam k t ih (lam b (rexl_rect (lam q bool) false
              (lam j u iu (bool_rect (lam q bool) true (bool_rect (lam q bool) false (ih u) (natgtb k j)) (natgtb j k))) b)))
            a)))
 (defn rex-mins (pi k nat m rexl rexl)
   (lam k m (rexl_rect (lam q rexl) (rexl1 k rexl0)
              (lam j t ih (bool_rect (lam q rexl) (rexl1 j ih) (rexl1 k (rexl1 j t)) (natgtb k j))) m)))
 (defn rex-mmul (pi a rexl b rexl rexl) (lam a b (rexl_rect (lam q rexl) b (lam k t ih (rex-mins k ih)) a)))
 (defn rex-pins (pi m rexl p rexp rexp)
   (lam m p (rexp_rect (lam q rexp) (rexp1 m rexp0)
              (lam n t ih (bool_rect (lam q rexp) (rexp1 n ih) (rexp1 m (rexp1 n t)) (rex-mlt n m))) p)))
 (defn rex-padd (pi p rexp q rexp rexp) (lam p q (rexp_rect (lam r rexp) q (lam m t ih (rex-pins m ih)) p)))
 (defn rex-psc (pi m rexl q rexp rexp)
   (lam m q (rexp_rect (lam r rexp) rexp0 (lam n t ih (rex-pins (rex-mmul m n) ih)) q)))
 (defn rex-pmul (pi p rexp q rexp rexp) (lam p q (rexp_rect (lam r rexp) rexp0 (lam m t ih (rex-padd (rex-psc m q) ih)) p)))
 (defn rex-norm (pi x rex rexp)
   (lam x (rex_rect (lam q rexp) (lam k (rexp1 (rexl1 k rexl0) rexp0)) rexp0 (rexp1 rexl0 rexp0)
            (lam a na b nb (rex-padd na nb)) (lam a na b nb (rex-pmul na nb)) x)))

 ; each insertion keeps the value, whatever the comparison answered
 (defq rex-mins-ok (pi e rexl k nat m rexl (paths nat (rex-mev e (rex-mins k m)) (mul (rex-nth e k) (rex-mev e m))))
   (lam e k m (rexl_rect (lam q (paths nat (rex-mev e (rex-mins k q)) (mul (rex-nth e k) (rex-mev e q))))
     (idpath (mul (rex-nth e k) 1))
     (lam j t ih
       (bool_rect (lam b (paths nat (rex-mev e (bool_rect (lam q rexl) (rexl1 j (rex-mins k t)) (rexl1 k (rexl1 j t)) b))
                                (mul (rex-nth e k) (mul (rex-nth e j) (rex-mev e t)))))
         (pathscomp0 nat (mul (rex-nth e j) (rex-mev e (rex-mins k t))) (mul (rex-nth e j) (mul (rex-nth e k) (rex-mev e t)))
           (mul (rex-nth e k) (mul (rex-nth e j) (rex-mev e t)))
           (maponpaths nat nat (lam z (mul (rex-nth e j) z)) (rex-mev e (rex-mins k t)) (mul (rex-nth e k) (rex-mev e t)) ih)
           (un-mswap (rex-nth e j) (rex-nth e k) (rex-mev e t)))
         (idpath (mul (rex-nth e k) (mul (rex-nth e j) (rex-mev e t))))
         (natgtb k j)))
     m)))
 (defq rex-mmul-ok (pi e rexl a rexl b rexl (paths nat (rex-mev e (rex-mmul a b)) (mul (rex-mev e a) (rex-mev e b))))
   (lam e a b (rexl_rect (lam q (paths nat (rex-mev e (rex-mmul q b)) (mul (rex-mev e q) (rex-mev e b))))
     (idpath (rex-mev e b))
     (lam k t ih
       (pathscomp0 nat (rex-mev e (rex-mins k (rex-mmul t b))) (mul (rex-nth e k) (rex-mev e (rex-mmul t b)))
         (mul (mul (rex-nth e k) (rex-mev e t)) (rex-mev e b))
         (rex-mins-ok e k (rex-mmul t b))
         (pathscomp0 nat (mul (rex-nth e k) (rex-mev e (rex-mmul t b))) (mul (rex-nth e k) (mul (rex-mev e t) (rex-mev e b)))
           (mul (mul (rex-nth e k) (rex-mev e t)) (rex-mev e b))
           (maponpaths nat nat (lam z (mul (rex-nth e k) z)) (rex-mev e (rex-mmul t b)) (mul (rex-mev e t) (rex-mev e b)) ih)
           (pathsinv0 nat (mul (mul (rex-nth e k) (rex-mev e t)) (rex-mev e b)) (mul (rex-nth e k) (mul (rex-mev e t) (rex-mev e b)))
             (natmultassoc (rex-nth e k) (rex-mev e t) (rex-mev e b))))))
     a)))
 (defq rex-pins-ok (pi e rexl m rexl p rexp (paths nat (rex-pev e (rex-pins m p)) (add (rex-mev e m) (rex-pev e p))))
   (lam e m p (rexp_rect (lam q (paths nat (rex-pev e (rex-pins m q)) (add (rex-mev e m) (rex-pev e q))))
     (idpath (add (rex-mev e m) 0))
     (lam n t ih
       (bool_rect (lam b (paths nat (rex-pev e (bool_rect (lam q rexp) (rexp1 n (rex-pins m t)) (rexp1 m (rexp1 n t)) b))
                                (add (rex-mev e m) (add (rex-mev e n) (rex-pev e t)))))
         (pathscomp0 nat (add (rex-mev e n) (rex-pev e (rex-pins m t))) (add (rex-mev e n) (add (rex-mev e m) (rex-pev e t)))
           (add (rex-mev e m) (add (rex-mev e n) (rex-pev e t)))
           (maponpaths nat nat (lam z (add (rex-mev e n) z)) (rex-pev e (rex-pins m t)) (add (rex-mev e m) (rex-pev e t)) ih)
           (un-pswap (rex-mev e n) (rex-mev e m) (rex-pev e t)))
         (idpath (add (rex-mev e m) (add (rex-mev e n) (rex-pev e t))))
         (rex-mlt n m)))
     p)))
 (defq rex-padd-ok (pi e rexl p rexp q rexp (paths nat (rex-pev e (rex-padd p q)) (add (rex-pev e p) (rex-pev e q))))
   (lam e p q (rexp_rect (lam r (paths nat (rex-pev e (rex-padd r q)) (add (rex-pev e r) (rex-pev e q))))
     (idpath (rex-pev e q))
     (lam m t ih
       (pathscomp0 nat (rex-pev e (rex-pins m (rex-padd t q))) (add (rex-mev e m) (rex-pev e (rex-padd t q)))
         (add (add (rex-mev e m) (rex-pev e t)) (rex-pev e q))
         (rex-pins-ok e m (rex-padd t q))
         (pathscomp0 nat (add (rex-mev e m) (rex-pev e (rex-padd t q))) (add (rex-mev e m) (add (rex-pev e t) (rex-pev e q)))
           (add (add (rex-mev e m) (rex-pev e t)) (rex-pev e q))
           (maponpaths nat nat (lam z (add (rex-mev e m) z)) (rex-pev e (rex-padd t q)) (add (rex-pev e t) (rex-pev e q)) ih)
           (pathsinv0 nat (add (add (rex-mev e m) (rex-pev e t)) (rex-pev e q)) (add (rex-mev e m) (add (rex-pev e t) (rex-pev e q)))
             (natplusassoc (rex-mev e m) (rex-pev e t) (rex-pev e q))))))
     p)))
 (defq rex-psc-ok (pi e rexl m rexl q rexp (paths nat (rex-pev e (rex-psc m q)) (mul (rex-mev e m) (rex-pev e q))))
   (lam e m q (rexp_rect (lam r (paths nat (rex-pev e (rex-psc m r)) (mul (rex-mev e m) (rex-pev e r))))
     (pathsinv0 nat (mul (rex-mev e m) 0) 0 (natmultn0 (rex-mev e m)))
     (lam n t ih
       (pathscomp0 nat (rex-pev e (rex-pins (rex-mmul m n) (rex-psc m t))) (add (rex-mev e (rex-mmul m n)) (rex-pev e (rex-psc m t)))
         (mul (rex-mev e m) (add (rex-mev e n) (rex-pev e t)))
         (rex-pins-ok e (rex-mmul m n) (rex-psc m t))
         (pathscomp0 nat (add (rex-mev e (rex-mmul m n)) (rex-pev e (rex-psc m t)))
           (add (mul (rex-mev e m) (rex-mev e n)) (mul (rex-mev e m) (rex-pev e t)))
           (mul (rex-mev e m) (add (rex-mev e n) (rex-pev e t)))
           (un-add2 (rex-mev e (rex-mmul m n)) (mul (rex-mev e m) (rex-mev e n))
                    (rex-pev e (rex-psc m t)) (mul (rex-mev e m) (rex-pev e t))
                    (rex-mmul-ok e m n) ih)
           (pathsinv0 nat (mul (rex-mev e m) (add (rex-mev e n) (rex-pev e t)))
             (add (mul (rex-mev e m) (rex-mev e n)) (mul (rex-mev e m) (rex-pev e t)))
             (natldistr (rex-mev e n) (rex-pev e t) (rex-mev e m))))))
     q)))
 (defq rex-pmul-ok (pi e rexl p rexp q rexp (paths nat (rex-pev e (rex-pmul p q)) (mul (rex-pev e p) (rex-pev e q))))
   (lam e p q (rexp_rect (lam r (paths nat (rex-pev e (rex-pmul r q)) (mul (rex-pev e r) (rex-pev e q))))
     (idpath 0)
     (lam m t ih
       (pathscomp0 nat (rex-pev e (rex-padd (rex-psc m q) (rex-pmul t q))) (add (rex-pev e (rex-psc m q)) (rex-pev e (rex-pmul t q)))
         (mul (add (rex-mev e m) (rex-pev e t)) (rex-pev e q))
         (rex-padd-ok e (rex-psc m q) (rex-pmul t q))
         (pathscomp0 nat (add (rex-pev e (rex-psc m q)) (rex-pev e (rex-pmul t q)))
           (add (mul (rex-mev e m) (rex-pev e q)) (mul (rex-pev e t) (rex-pev e q)))
           (mul (add (rex-mev e m) (rex-pev e t)) (rex-pev e q))
           (un-add2 (rex-pev e (rex-psc m q)) (mul (rex-mev e m) (rex-pev e q))
                    (rex-pev e (rex-pmul t q)) (mul (rex-pev e t) (rex-pev e q))
                    (rex-psc-ok e m q) ih)
           (pathsinv0 nat (mul (add (rex-mev e m) (rex-pev e t)) (rex-pev e q))
             (add (mul (rex-mev e m) (rex-pev e q)) (mul (rex-pev e t) (rex-pev e q)))
             (natrdistr (rex-mev e m) (rex-pev e t) (rex-pev e q))))))
     p)))
 ; an expression is worth its normal form
 (defq rex-sound (pi e rexl x rex (paths nat (rex-ev e x) (rex-pev e (rex-norm x))))
   (lam e x (rex_rect (lam q (paths nat (rex-ev e q) (rex-pev e (rex-norm q))))
     (lam k (pathsinv0 nat (add (mul (rex-nth e k) 1) 0) (rex-nth e k)
              (pathscomp0 nat (add (mul (rex-nth e k) 1) 0) (mul (rex-nth e k) 1) (rex-nth e k)
                (natplusr0 (mul (rex-nth e k) 1)) (natmultr1 (rex-nth e k)))))
     (idpath 0)
     (idpath 1)
     (lam a ia b ib
       (pathscomp0 nat (add (rex-ev e a) (rex-ev e b)) (add (rex-pev e (rex-norm a)) (rex-pev e (rex-norm b)))
         (rex-pev e (rex-padd (rex-norm a) (rex-norm b)))
         (un-add2 (rex-ev e a) (rex-pev e (rex-norm a)) (rex-ev e b) (rex-pev e (rex-norm b)) ia ib)
         (pathsinv0 nat (rex-pev e (rex-padd (rex-norm a) (rex-norm b))) (add (rex-pev e (rex-norm a)) (rex-pev e (rex-norm b)))
           (rex-padd-ok e (rex-norm a) (rex-norm b)))))
     (lam a ia b ib
       (pathscomp0 nat (mul (rex-ev e a) (rex-ev e b)) (mul (rex-pev e (rex-norm a)) (rex-pev e (rex-norm b)))
         (rex-pev e (rex-pmul (rex-norm a) (rex-norm b)))
         (un-mul2 (rex-ev e a) (rex-pev e (rex-norm a)) (rex-ev e b) (rex-pev e (rex-norm b)) ia ib)
         (pathsinv0 nat (rex-pev e (rex-pmul (rex-norm a) (rex-norm b))) (mul (rex-pev e (rex-norm a)) (rex-pev e (rex-norm b)))
           (rex-pmul-ok e (rex-norm a) (rex-norm b)))))
     x)))
 ; two regroupings of one sum of products are equal by their normal forms
 (defq rex-eq (pi e rexl x rex y rex h (paths rexp (rex-norm x) (rex-norm y)) (paths nat (rex-ev e x) (rex-ev e y)))
   (lam e x y h
     (pathscomp0 nat (rex-ev e x) (rex-pev e (rex-norm x)) (rex-ev e y) (rex-sound e x)
       (pathscomp0 nat (rex-pev e (rex-norm x)) (rex-pev e (rex-norm y)) (rex-ev e y)
         (maponpaths rexp nat (rex-pev e) (rex-norm x) (rex-norm y) h)
         (pathsinv0 nat (rex-ev e y) (rex-pev e (rex-norm y)) (rex-sound e y)))))))

(test
 ; a regrouping proved by its normal forms, and one that is not a regrouping refused
 (defq rex-demo (pi a nat b nat (paths nat (mul (add a b) (add b 1)) (add (add (mul b b) b) (add (mul a b) a))))
   (lam a b (rex-eq (rexl1 a (rexl1 b rexl0))
              (rexm (rexa (rexv 0) (rexv 1)) (rexa (rexv 1) rexo))
              (rexa (rexa (rexm (rexv 1) (rexv 1)) (rexv 1)) (rexa (rexm (rexv 0) (rexv 1)) (rexv 0)))
              (idpath (rex-norm (rexm (rexa (rexv 0) (rexv 1)) (rexa (rexv 1) rexo))))))))
(hear (p \ e \ peep HELPC () 0 @ h (h ? (h p e) 0)))
(test
 ('rejected = rejects (z \ defq rex-bad (pi a nat b nat (paths nat (mul (add a b) b) (add (mul b b) (mul a a))))
   (lam a b (rex-eq (rexl1 a (rexl1 b rexl0))
              (rexm (rexa (rexv 0) (rexv 1)) (rexv 1))
              (rexa (rexm (rexv 1) (rexv 1)) (rexm (rexv 0) (rexv 0)))
              (idpath (rex-norm (rexm (rexa (rexv 0) (rexv 1)) (rexv 1)))))))))
(hear test-strict)
