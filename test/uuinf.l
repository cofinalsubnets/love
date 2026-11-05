; test/uuinf.l -- inflate's bounds, stated of a model of inflate.h and prefix.h. the first batch: one
; obligation of each class, to price them. C subtraction wraps and natminus truncates, so a
; subtraction owes its no-wrap beside its bound

; --- the order, as inflate's checks read it ---
(test
 (defn inf-le (pi a nat (pi b nat UU)) (lam a (lam b (paths bool (natgtb a b) false))))
 (defn inf-lt (pi a nat (pi b nat UU)) (lam a (lam b (paths bool (natgtb b a) true))))
 (defq inf-lelts (pi a nat (pi b nat (pi g (inf-le a b) (inf-lt a (succ b)))))
   (lam a (nat_rect (lam q (pi b nat (pi g (inf-le q b) (inf-lt q (succ b)))))
     (lam b (lam g (idpath true)))
     (lam k (lam IH (lam b (nat_rect (lam r (pi g (inf-le (succ k) r) (inf-lt (succ k) (succ r))))
       (lam g (fromempty (inf-lt (succ k) 1) (nopathstruetofalse g)))
       (lam j (lam u (lam g (IH j g))))
       b))))
     a)))
 (defq inf-ltsle (pi a nat (pi b nat (pi g (inf-lt a (succ b)) (inf-le a b))))
   (lam a (nat_rect (lam q (pi b nat (pi g (inf-lt q (succ b)) (inf-le q b))))
     (lam b (lam g (idpath false)))
     (lam k (lam IH (lam b (nat_rect (lam r (pi g (inf-lt (succ k) (succ r)) (inf-le (succ k) r)))
       (lam g (fromempty (inf-le (succ k) 0) (nopathsfalsetotrue g)))
       (lam j (lam u (lam g (IH j g))))
       b))))
     a)))
 (defq inf-ltsu (pi a nat (pi b nat (pi g (inf-lt a b) (inf-le (succ a) b))))
   (lam a (nat_rect (lam q (pi b nat (pi g (inf-lt q b) (inf-le (succ q) b))))
     (lam b (nat_rect (lam r (pi g (inf-lt 0 r) (inf-le 1 r)))
       (lam g (fromempty (inf-le 1 0) (nopathsfalsetotrue g)))
       (lam j (lam u (lam g (idpath false))))
       b))
     (lam k (lam IH (lam b (nat_rect (lam r (pi g (inf-lt (succ k) r) (inf-le (succ (succ k)) r)))
       (lam g (fromempty (inf-le (succ (succ k)) 0) (nopathsfalsetotrue g)))
       (lam j (lam u (lam g (IH j g))))
       b))))
     a)))
 (defq inf-ltle (pi a nat (pi b nat (pi g (inf-lt a b) (inf-le a b))))
   (lam a (lam b (lam g (natlthtoleh a b g)))))
 (defq inf-lttrans (pi a nat (pi b nat (pi c nat (pi g (inf-lt a b) (pi h (inf-le b c) (inf-lt a c))))))
   (lam a (lam b (lam c (lam g (lam h
     (inf-lelts (succ a) c (istransnatleh (succ a) b c (inf-ltsu a b g) h))))))))
 (defq inf-letr (pi a nat (pi b nat (pi c nat (pi e (paths nat a b) (pi g (inf-le a c) (inf-le b c))))))
   (lam a (lam b (lam c (lam e (lam g (transportf nat (lam x (inf-le x c)) a b e g)))))))
 (defq inf-letl (pi a nat (pi b nat (pi c nat (pi e (paths nat b c) (pi g (inf-le a b) (inf-le a c))))))
   (lam a (lam b (lam c (lam e (lam g (transportf nat (lam x (inf-le a x)) b c e g)))))))
 (defq inf-lttr (pi a nat (pi b nat (pi c nat (pi e (paths nat a b) (pi g (inf-lt a c) (inf-lt b c))))))
   (lam a (lam b (lam c (lam e (lam g (transportf nat (lam x (inf-lt x c)) a b e g)))))))
 ; a branch on a bool, its answer in hand
 (defn inf-case (pi b bool (pi P (pi x bool UU)
     (pi t (pi e (paths bool b true) (P true)) (pi f (pi e (paths bool b false) (P false)) (P b)))))
   (lam b (lam P (lam t (lam f
     ((bool_rect (lam x (pi e (paths bool b x) (P x))) t f b) (idpath b))))))))

; --- sums: monotone both ways, strictly when strictly ---
(test
 (defq inf-addl (pi c nat (pi a nat (pi b nat (pi g (inf-le a b) (inf-le (add c a) (add c b))))))
   (lam c (lam a (lam b (lam g (nat_rect (lam q (inf-le (add q a) (add q b))) g (lam k (lam IH IH)) c))))))
 (defq inf-leaddl (pi c nat (pi b nat (inf-le c (add b c))))
   (lam c (lam b (nat_rect (lam q (inf-le c (add q c)))
     (isreflnatleh c)
     (lam k (lam IH (natlehsucc c (add k c) IH)))
     b))))
 (defq inf-leaddr (pi a nat (pi b nat (inf-le a (add a b))))
   (lam a (lam b (nat_rect (lam q (inf-le q (add q b))) (idpath false) (lam k (lam IH IH)) a))))
 (defq inf-addr (pi a nat (pi b nat (pi c nat (pi g (inf-le a b) (inf-le (add a c) (add b c))))))
   (lam a (nat_rect (lam q (pi b nat (pi c nat (pi g (inf-le q b) (inf-le (add q c) (add b c))))))
     (lam b (lam c (lam g (inf-leaddl c b))))
     (lam k (lam IH (lam b (nat_rect
       (lam r (pi c nat (pi g (inf-le (succ k) r) (inf-le (add (succ k) c) (add r c)))))
       (lam c (lam g (fromempty (inf-le (add (succ k) c) c) (nopathstruetofalse g))))
       (lam j (lam u (lam c (lam g (IH j c g)))))
       b))))
     a)))
 (defq inf-add2 (pi a nat (pi b nat (pi c nat (pi d nat (pi g (inf-le a b) (pi h (inf-le c d)
     (inf-le (add a c) (add b d))))))))
   (lam a (lam b (lam c (lam d (lam g (lam h
     (istransnatleh (add a c) (add b c) (add b d) (inf-addr a b c g) (inf-addl b c d h)))))))))
 (defq inf-ltaddl (pi c nat (pi a nat (pi b nat (pi g (inf-lt a b) (inf-lt (add c a) (add c b))))))
   (lam c (lam a (lam b (lam g (nat_rect (lam q (inf-lt (add q a) (add q b))) g (lam k (lam IH IH)) c))))))
 (defq inf-ltaddr (pi a nat (pi b nat (pi c nat (pi g (inf-lt a b) (inf-lt (add a c) (add b c))))))
   (lam a (lam b (lam c (lam g
     (inf-lelts (succ (add a c)) (add b c) (inf-addr (succ a) b c (inf-ltsu a b g))))))))
 (defq inf-dbl (pi a nat (pi b nat (pi g (inf-le a b) (inf-le (add a a) (add b b)))))
   (lam a (lam b (lam g (inf-add2 a b a b g g))))))

; --- differences ---
(test
 (defq inf-suble (pi a nat (pi b nat (inf-le (natminus a b) a)))
   (lam a (nat_rect (lam q (pi b nat (inf-le (natminus q b) q)))
     (lam b (idpath false))
     (lam k (lam IH (lam b (nat_rect (lam r (inf-le (natminus (succ k) r) (succ k)))
       (isreflnatleh (succ k))
       (lam j (lam u (natlehsucc (natminus k j) k (IH j))))
       b))))
     a)))
 (defq inf-submono (pi a nat (pi b nat (pi c nat (pi g (inf-le a b) (inf-le (natminus a c) (natminus b c))))))
   (lam a (nat_rect (lam q (pi b nat (pi c nat (pi g (inf-le q b) (inf-le (natminus q c) (natminus b c))))))
     (lam b (lam c (lam g (idpath false))))
     (lam k (lam IH (lam b (nat_rect
       (lam r (pi c nat (pi g (inf-le (succ k) r) (inf-le (natminus (succ k) c) (natminus r c)))))
       (lam c (lam g (fromempty (inf-le (natminus (succ k) c) (natminus 0 c)) (nopathstruetofalse g))))
       (lam j (lam u (lam c (nat_rect
         (lam s (pi g (inf-le (succ k) (succ j)) (inf-le (natminus (succ k) s) (natminus (succ j) s))))
         (lam g g)
         (lam m (lam v (lam g (IH j m g))))
         c))))
       b))))
     a)))
 ; a reach back lands below where it started, so long as it reaches at all
 (defq inf-subdec (pi a nat (pi d nat (pi p (inf-lt 0 d) (pi g (inf-le d a) (inf-lt (natminus a d) a)))))
   (lam a (lam d (nat_rect (lam r (pi p (inf-lt 0 r) (pi g (inf-le r a) (inf-lt (natminus a r) a))))
     (lam p (lam g (fromempty (inf-lt (natminus a 0) a) (nopathsfalsetotrue p))))
     (lam e (lam u (lam p (nat_rect
       (lam q (pi g (inf-le (succ e) q) (inf-lt (natminus q (succ e)) q)))
       (lam g (fromempty (inf-lt (natminus 0 (succ e)) 0) (nopathstruetofalse g)))
       (lam o (lam w (lam g (inf-lelts (natminus o e) o (inf-suble o e)))))
       a))))
     d))))
 (defq inf-addsub (pi b nat (pi a nat (pi g (inf-le b a) (paths nat (add b (natminus a b)) a))))
   (lam b (nat_rect (lam q (pi a nat (pi g (inf-le q a) (paths nat (add q (natminus a q)) a))))
     (lam a (lam g (natminusn0 a)))
     (lam k (lam IH (lam a (nat_rect
       (lam r (pi g (inf-le (succ k) r) (paths nat (add (succ k) (natminus r (succ k))) r)))
       (lam g (fromempty (paths nat (add (succ k) (natminus 0 (succ k))) 0) (nopathstruetofalse g)))
       (lam j (lam u (lam g (maponpaths nat nat (lam w (succ w)) (add k (natminus j k)) j (IH j g)))))
       a))))
     b)))
 ; the walk's step: c past f and short of f + n stands short of n
 (defq inf-subshort (pi f nat (pi c nat (pi n nat (pi g (inf-le f c) (pi h (inf-lt c (add f n))
     (inf-lt (natminus c f) n))))))
   (lam f (nat_rect (lam q (pi c nat (pi n nat (pi g (inf-le q c) (pi h (inf-lt c (add q n))
       (inf-lt (natminus c q) n))))))
     (lam c (lam n (lam g (lam h
       (inf-lttr c (natminus c 0) n (pathsinv0 nat (natminus c 0) c (natminusn0 c)) h)))))
     (lam k (lam IH (lam c (nat_rect
       (lam r (pi n nat (pi g (inf-le (succ k) r) (pi h (inf-lt r (add (succ k) n))
         (inf-lt (natminus r (succ k)) n)))))
       (lam n (lam g (lam h (fromempty (inf-lt (natminus 0 (succ k)) n) (nopathstruetofalse g)))))
       (lam j (lam u (lam n (lam g (lam h (IH j n g h))))))
       c))))
     f))))

; --- class 1: an index a check guards. inflate.h 184-190 ---
(test
 (defq inf-lidx-nowrap (pi sy nat (pi g (inf-lt 256 sy) (inf-le 257 sy)))
   (lam sy (lam g (inf-ltsu 256 sy g))))
 (defq inf-lidx (pi sy nat (pi g (inf-le sy 285) (inf-lt (natminus sy 257) 29)))
   (lam sy (lam g (inf-lelts (natminus sy 257) 28 (inf-submono sy 285 257 g)))))
 (defq inf-didx (pi sy nat (pi g (inf-le sy 29) (inf-lt sy 30)))
   (lam sy (lam g (inf-lelts sy 29 g)))))

; --- class 2: an index a mask bounds. bb & ((1 << k) - 1) is bb mod 2^k, which is what the model
; --- says: the generator owes the spelling
(test
 (defn inf-mod (pi m nat (pi x nat nat))
   (lam m (lam x (nat_rect (lam q nat) 0
     (lam k (lam r (bool_rect (lam b nat) (succ r) 0 (natgtb m (succ r)))))
     x))))
 (5 = vof 0 '(inf-mod 8 21))
 (15 = vof 0 '(inf-mod 16 15))
 (defq inf-modlt (pi p nat (pi x nat (inf-lt (inf-mod (succ p) x) (succ p))))
   (lam p (lam x (nat_rect (lam q (inf-lt (inf-mod (succ p) q) (succ p)))
     (idpath true)
     (lam k (lam IH (inf-case (natgtb (succ p) (succ (inf-mod (succ p) k)))
       (lam b (inf-lt (bool_rect (lam c nat) (succ (inf-mod (succ p) k)) 0 b) (succ p)))
       (lam e e)
       (lam e (idpath true)))))
     x))))
 ; the three roots, the tab[] indices at LROOT, DROOT, CROOT
 (defq inf-ltab (pi bb nat (inf-lt (inf-mod 4096 bb) 4096)) (lam bb (inf-modlt 4095 bb)))
 (defq inf-dtab (pi bb nat (inf-lt (inf-mod 512 bb) 512)) (lam bb (inf-modlt 511 bb)))
 (defq inf-ctab (pi bb nat (inf-lt (inf-mod 128 bb) 128)) (lam bb (inf-modlt 127 bb)))
 ; hlit, hdist, hclen: 5, 5, 4 bits and an offset. lsym, lens + hlit, gz_clord
 (defq inf-hlit (pi b nat (inf-le (add 257 (inf-mod 32 b)) 288))
   (lam b (inf-addl 257 (inf-mod 32 b) 31 (inf-ltsle (inf-mod 32 b) 31 (inf-modlt 31 b)))))
 (defq inf-hdist (pi b nat (inf-le (add 1 (inf-mod 32 b)) 32))
   (lam b (inf-addl 1 (inf-mod 32 b) 31 (inf-ltsle (inf-mod 32 b) 31 (inf-modlt 31 b)))))
 (defq inf-hclen (pi b nat (inf-le (add 4 (inf-mod 16 b)) 19))
   (lam b (inf-addl 4 (inf-mod 16 b) 15 (inf-ltsle (inf-mod 16 b) 15 (inf-modlt 15 b)))))
 (defq inf-lenscap (pi a nat (pi b nat
     (inf-le (add (add 257 (inf-mod 32 a)) (add 1 (inf-mod 32 b))) 320)))
   (lam a (lam b (inf-add2 (add 257 (inf-mod 32 a)) 288 (add 1 (inf-mod 32 b)) 32 (inf-hlit a) (inf-hdist b))))))

; --- class 3: a match copy. inflate.h 191-205, past its two checks ---
(test
 ; d <= op: dp[k] and sp[k]
 (defq inf-cw (pi op nat (pi k nat (pi l nat (pi cap nat (pi g (inf-lt k l) (pi h (inf-le (add op l) cap)
     (inf-lt (add op k) cap)))))))
   (lam op (lam k (lam l (lam cap (lam g (lam h
     (inf-lttrans (add op k) (add op l) cap (inf-ltaddl op k l g) h))))))))
 (defq inf-cr (pi op nat (pi d nat (pi k nat (pi p (inf-lt 0 d) (pi g (inf-le d op)
     (inf-lt (add (natminus op d) k) (add op k)))))))
   (lam op (lam d (lam k (lam p (lam g
     (inf-ltaddr (natminus op d) op k (inf-subdec op d p g))))))))
 ; d > op: h = min (d - op) l comes from the dictionary, the rest from the output
 (defn inf-h (pi d nat (pi op nat (pi l nat nat)))
   (lam d (lam op (lam l (bool_rect (lam b nat) (natminus d op) l (natgtb l (natminus d op)))))))
 (defq inf-hle (pi d nat (pi op nat (pi l nat (inf-le (inf-h d op l) (natminus d op)))))
   (lam d (lam op (lam l (inf-case (natgtb l (natminus d op))
     (lam b (inf-le (bool_rect (lam c nat) (natminus d op) l b) (natminus d op)))
     (lam e (isreflnatleh (natminus d op)))
     (lam e e))))))
 (defq inf-hlel (pi d nat (pi op nat (pi l nat (inf-le (inf-h d op l) l))))
   (lam d (lam op (lam l (inf-case (natgtb l (natminus d op))
     (lam b (inf-le (bool_rect (lam c nat) (natminus d op) l b) l))
     (lam e (inf-ltle (natminus d op) l e))
     (lam e (isreflnatleh l)))))))
 ; memcpy (out + op, ..): the write's end
 (defq inf-dw (pi d nat (pi op nat (pi l nat (pi cap nat (pi h (inf-le (add op l) cap)
     (inf-le (add op (inf-h d op l)) cap))))))
   (lam d (lam op (lam l (lam cap (lam h
     (istransnatleh (add op (inf-h d op l)) (add op l) cap
       (inf-addl op (inf-h d op l) l (inf-hlel d op l)) h)))))))
 ; memcpy (.., dic + nd - (d - op), h): start no wrap, end within nd
 (defq inf-cancel (pi a nat (pi b nat (paths nat (natminus (add a b) a) b)))
   (lam a (lam b (nat_rect (lam q (paths nat (natminus (add q b) q) b))
     (natminusn0 b)
     (lam k (lam IH IH))
     a))))
 (defq inf-dnowrap (pi d nat (pi op nat (pi nd nat (pi g (inf-le d (add op nd)) (inf-le (natminus d op) nd)))))
   (lam d (lam op (lam nd (lam g
     (inf-letl (natminus d op) (natminus (add op nd) op) nd (inf-cancel op nd)
       (inf-submono d (add op nd) op g)))))))
 (defq inf-dr (pi d nat (pi op nat (pi l nat (pi nd nat (pi g (inf-le d (add op nd))
     (inf-le (add (natminus nd (natminus d op)) (inf-h d op l)) nd))))))
   (lam d (lam op (lam l (lam nd (lam g
     (inf-letl (add (natminus nd (natminus d op)) (inf-h d op l))
       (add (natminus nd (natminus d op)) (natminus d op)) nd
       (pathscomp0 nat (add (natminus nd (natminus d op)) (natminus d op))
         (add (natminus d op) (natminus nd (natminus d op))) nd
         (natpluscomm (natminus nd (natminus d op)) (natminus d op))
         (inf-addsub (natminus d op) nd (inf-dnowrap d op nd g)))
       (inf-addl (natminus nd (natminus d op)) (inf-h d op l) (natminus d op) (inf-hle d op l)))))))))
 ; out[op + k - d] past the dictionary: k past h has left it, so the reach no longer wraps
 (defq inf-dknowrap (pi d nat (pi op nat (pi l nat (pi k nat (pi g (inf-le op d)
     (pi x (inf-le (inf-h d op l) k) (pi y (inf-lt k l) (inf-le d (add op k)))))))))
   (lam d (lam op (lam l (lam k (lam g
     (inf-case (natgtb l (natminus d op))
       (lam b (pi x (inf-le (bool_rect (lam c nat) (natminus d op) l b) k)
         (pi y (inf-lt k l) (inf-le d (add op k)))))
       (lam e (lam x (lam y
         (inf-letr (add op (natminus d op)) d (add op k) (inf-addsub op d g)
           (inf-addl op (natminus d op) k x)))))
       (lam e (lam x (lam y
         (fromempty (inf-le d (add op k)) (natlehtonegnatgth l k x y))))))))))))
 (defq inf-dkr (pi d nat (pi op nat (pi l nat (pi k nat (pi p (inf-lt 0 d) (pi g (inf-le op d)
     (pi x (inf-le (inf-h d op l) k) (pi y (inf-lt k l)
       (inf-lt (natminus (add op k) d) (add op k))))))))))
   (lam d (lam op (lam l (lam k (lam p (lam g (lam x (lam y
     (inf-subdec (add op k) d p (inf-dknowrap d op l k g x y))))))))))))

; --- class 4: a loop's invariant. inf_walk, prefix.h 32-40: first <= code on entry, whatever the
; --- counts say, and index + the counts to come within nsym, so sym[index + code - first] is in
(test
 (defn inf-sum (pi cnt (pi l nat nat) (pi f nat (pi l nat nat)))
   (lam cnt (lam f (nat_rect (lam q (pi l nat nat))
     (lam l 0)
     (lam k (lam IH (lam l (add (cnt l) (IH (succ l))))))
     f))))
 (defn inf-walk (pi cnt (pi l nat nat) (pi bit (pi l nat nat) (pi f nat
     (pi l nat (pi code nat (pi first nat (pi index nat (coprod nat unit))))))))
   (lam cnt (lam bit (lam f (nat_rect
     (lam q (pi l nat (pi code nat (pi first nat (pi index nat (coprod nat unit))))))
     (lam l (lam code (lam first (lam index (ii2 tt)))))
     (lam k (lam IH (lam l (lam code (lam first (lam index
       (bool_rect (lam b (coprod nat unit))
         (ii1 (add index (natminus (add code (bit l)) first)))
         (IH (succ l) (add (add code (bit l)) (add code (bit l)))
             (add (add first (cnt l)) (add first (cnt l))) (add index (cnt l)))
         (natgtb (add first (cnt l)) (add code (bit l)))))))))) 
     f)))))
 (defn inf-ok (pi n nat (pi r (coprod nat unit) UU))
   (lam n (lam r (coprod_rect (lam x UU) (lam i (inf-lt i n)) (lam u unit) r))))
 (defq inf-walkok (pi cnt (pi l nat nat) (pi bit (pi l nat nat) (pi n nat (pi f nat
     (pi l nat (pi code nat (pi first nat (pi index nat (pi g (inf-le first code)
       (pi h (inf-le (add index (inf-sum cnt f l)) n)
         (inf-ok n (inf-walk cnt bit f l code first index))))))))))))
   (lam cnt (lam bit (lam n (lam f (nat_rect
     (lam q (pi l nat (pi code nat (pi first nat (pi index nat (pi g (inf-le first code)
       (pi h (inf-le (add index (inf-sum cnt q l)) n)
         (inf-ok n (inf-walk cnt bit q l code first index)))))))))
     (lam l (lam code (lam first (lam index (lam g (lam h tt))))))
     (lam k (lam IH (lam l (lam code (lam first (lam index (lam g (lam h
       (inf-case (natgtb (add first (cnt l)) (add code (bit l)))
         (lam b (inf-ok n (bool_rect (lam z (coprod nat unit))
           (ii1 (add index (natminus (add code (bit l)) first)))
           (inf-walk cnt bit k (succ l) (add (add code (bit l)) (add code (bit l)))
             (add (add first (cnt l)) (add first (cnt l))) (add index (cnt l)))
           b)))
         (lam e (inf-lttrans (add index (natminus (add code (bit l)) first)) (add index (cnt l)) n
           (inf-ltaddl index (natminus (add code (bit l)) first) (cnt l)
             (inf-subshort first (add code (bit l)) (cnt l)
               (istransnatleh first code (add code (bit l)) g (inf-leaddr code (bit l))) e))
           (istransnatleh (add index (cnt l)) (add index (inf-sum cnt (succ k) l)) n
             (inf-addl index (cnt l) (inf-sum cnt (succ k) l) (inf-leaddr (cnt l) (inf-sum cnt k (succ l))))
             h)))
         (lam e (IH (succ l) (add (add code (bit l)) (add code (bit l)))
             (add (add first (cnt l)) (add first (cnt l))) (add index (cnt l))
           (inf-dbl (add first (cnt l)) (add code (bit l)) e)
           (inf-letr (add index (add (cnt l) (inf-sum cnt k (succ l))))
             (add (add index (cnt l)) (inf-sum cnt k (succ l))) n
             (pathsinv0 nat (add (add index (cnt l)) (inf-sum cnt k (succ l)))
               (add index (add (cnt l) (inf-sum cnt k (succ l))))
               (natplusassoc index (cnt l) (inf-sum cnt k (succ l))))
             h))))))))))))
     f))))))
 ; inf_walk's entry, all three at zero; fifteen lengths or any number
 (defq inf-walkidx (pi cnt (pi l nat nat) (pi bit (pi l nat nat) (pi n nat (pi f nat
     (pi h (inf-le (inf-sum cnt f 1) n) (inf-ok n (inf-walk cnt bit f 1 0 0 0)))))))
   (lam cnt (lam bit (lam n (lam f (lam h (inf-walkok cnt bit n f 1 0 0 0 (idpath false) h)))))))
 ; one code of length 1 and two of length 2: 0 is the first symbol, 1 0 the second, 1 1 the third,
 ; so the model decodes and its theorem is not empty
 (defn inf-cnt3 (pi l nat nat)
   (lam l (nat_rect (lam q nat) 0
     (lam k (lam u (nat_rect (lam q nat) 1 (lam j (lam w (nat_rect (lam q nat) 2 (lam i (lam x 0)) j))) k)))
     l)))
 (defn inf-bits (pi a nat (pi b nat (pi l nat nat)))
   (lam a (lam b (lam l (nat_rect (lam q nat) 0
     (lam k (lam u (nat_rect (lam q nat) a (lam j (lam w b)) k)))
     l)))))
 (['i1 0] = vof 0 '(inf-walk inf-cnt3 (inf-bits 0 1) 3 1 0 0 0))
 (['i1 1] = vof 0 '(inf-walk inf-cnt3 (inf-bits 1 0) 3 1 0 0 0))
 (['i1 2] = vof 0 '(inf-walk inf-cnt3 (inf-bits 1 1) 3 1 0 0 0)))

; --- class 5: what a loop left in an array. inf_build, prefix.h 16-20: ofs[v] after i symbols is what
; --- came before v plus the v's so far, so sym[ofs[lens[i]]++] stays under nsym on any lengths at all
(test
 (defn inf-eqb (pi n nat (pi m nat bool))
   (lam n (nat_rect (lam q (pi m nat bool))
     (lam m (nat_rect (lam r bool) true (lam j (lam u false)) m))
     (lam k (lam IH (lam m (nat_rect (lam r bool) false (lam j (lam u (IH j))) m))))
     n)))
 (defq inf-eqp (pi a nat (pi b nat (pi e (paths bool (inf-eqb a b) true) (paths nat a b))))
   (lam a (nat_rect (lam q (pi b nat (pi e (paths bool (inf-eqb q b) true) (paths nat q b))))
     (lam b (nat_rect (lam r (pi e (paths bool (inf-eqb 0 r) true) (paths nat 0 r)))
       (lam e (idpath 0))
       (lam j (lam u (lam e (fromempty (paths nat 0 (succ j)) (nopathsfalsetotrue e)))))
       b))
     (lam k (lam IH (lam b (nat_rect (lam r (pi e (paths bool (inf-eqb (succ k) r) true) (paths nat (succ k) r)))
       (lam e (fromempty (paths nat (succ k) 0) (nopathsfalsetotrue e)))
       (lam j (lam u (lam e (maponpaths nat nat (lam w (succ w)) k j (IH j e)))))
       b))))
     a)))
 (defq inf-gtne (pi x nat (pi l nat (pi g (inf-lt x l) (paths bool (inf-eqb x l) false))))
   (lam x (nat_rect (lam q (pi l nat (pi g (inf-lt q l) (paths bool (inf-eqb q l) false))))
     (lam l (nat_rect (lam r (pi g (inf-lt 0 r) (paths bool (inf-eqb 0 r) false)))
       (lam g (fromempty (paths bool (inf-eqb 0 0) false) (nopathsfalsetotrue g)))
       (lam j (lam u (lam g (idpath false))))
       l))
     (lam k (lam IH (lam l (nat_rect (lam r (pi g (inf-lt (succ k) r) (paths bool (inf-eqb (succ k) r) false)))
       (lam g (idpath false))
       (lam j (lam u (lam g (IH j g))))
       l))))
     x)))
 (defq inf-eq0ne (pi x nat (pi o nat (pi e (paths bool (inf-eqb x 0) true) (paths bool (inf-eqb x (succ o)) false))))
   (lam x (lam o (nat_rect (lam q (pi e (paths bool (inf-eqb q 0) true) (paths bool (inf-eqb q (succ o)) false)))
     (lam e (idpath false))
     (lam k (lam u (lam e (fromempty (paths bool (inf-eqb (succ k) (succ o)) false) (nopathsfalsetotrue e)))))
     x))))
 (defn inf-d (pi x nat (pi v nat nat)) (lam x (lam v (bool_rect (lam b nat) 1 0 (inf-eqb x v)))))
 (defn inf-count (pi L (pi i nat nat) (pi v nat (pi n nat nat)))
   (lam L (lam v (lam n (nat_rect (lam q nat) 0 (lam k (lam r (add (inf-d (L k) v) r))) n)))))

 ; a sum over lengths splits, and a snoc is what the C's ofs[l + 1] = ofs[l] + cnt[l] walks
 (defq inf-lswap (pi b nat (pi c nat (pi d nat (paths nat (add b (add c d)) (add c (add b d))))))
   (lam b (lam c (lam d (nat_rect (lam q (paths nat (add q (add c d)) (add c (add q d))))
     (idpath (add c d))
     (lam k (lam IH (pathscomp0 nat (succ (add k (add c d))) (succ (add c (add k d))) (add c (succ (add k d)))
       (maponpaths nat nat (lam w (succ w)) (add k (add c d)) (add c (add k d)) IH)
       (pathsinv0 nat (add c (succ (add k d))) (succ (add c (add k d))) (natplusnsm c (add k d))))))
     b)))))
 (defq inf-swap4 (pi a nat (pi b nat (pi c nat (pi d nat
     (paths nat (add (add a b) (add c d)) (add (add a c) (add b d)))))))
   (lam a (lam b (lam c (lam d (nat_rect (lam q (paths nat (add (add q b) (add c d)) (add (add q c) (add b d))))
     (inf-lswap b c d)
     (lam k (lam IH (maponpaths nat nat (lam w (succ w))
       (add (add k b) (add c d)) (add (add k c) (add b d)) IH)))
     a))))))
 (defq inf-sumadd (pi f (pi v nat nat) (pi g (pi v nat nat) (pi o nat (pi l nat
     (paths nat (inf-sum (lam v (add (f v) (g v))) o l) (add (inf-sum f o l) (inf-sum g o l)))))))
   (lam f (lam g (lam o (nat_rect
     (lam q (pi l nat (paths nat (inf-sum (lam v (add (f v) (g v))) q l) (add (inf-sum f q l) (inf-sum g q l)))))
     (lam l (idpath 0))
     (lam k (lam IH (lam l
       (pathscomp0 nat (add (add (f l) (g l)) (inf-sum (lam v (add (f v) (g v))) k (succ l)))
         (add (add (f l) (g l)) (add (inf-sum f k (succ l)) (inf-sum g k (succ l))))
         (add (add (f l) (inf-sum f k (succ l))) (add (g l) (inf-sum g k (succ l))))
         (maponpaths nat nat (lam w (add (add (f l) (g l)) w))
           (inf-sum (lam v (add (f v) (g v))) k (succ l))
           (add (inf-sum f k (succ l)) (inf-sum g k (succ l))) (IH (succ l)))
         (inf-swap4 (f l) (g l) (inf-sum f k (succ l)) (inf-sum g k (succ l)))))))
     o)))))
 (defq inf-snoc (pi f (pi v nat nat) (pi o nat (pi l nat
     (paths nat (inf-sum f (succ o) l) (add (inf-sum f o l) (f (add l o)))))))
   (lam f (lam o (nat_rect
     (lam q (pi l nat (paths nat (inf-sum f (succ q) l) (add (inf-sum f q l) (f (add l q))))))
     (lam l (pathscomp0 nat (add (f l) 0) (f l) (f (add l 0))
       (natplusr0 (f l))
       (maponpaths nat nat f l (add l 0) (pathsinv0 nat (add l 0) l (natplusr0 l)))))
     (lam k (lam IH (lam l
       (pathscomp0 nat (add (f l) (inf-sum f (succ k) (succ l)))
         (add (f l) (add (inf-sum f k (succ l)) (f (add (succ l) k))))
         (add (add (f l) (inf-sum f k (succ l))) (f (add l (succ k))))
         (maponpaths nat nat (lam w (add (f l) w)) (inf-sum f (succ k) (succ l))
           (add (inf-sum f k (succ l)) (f (add (succ l) k))) (IH (succ l)))
         (pathscomp0 nat (add (f l) (add (inf-sum f k (succ l)) (f (add (succ l) k))))
           (add (add (f l) (inf-sum f k (succ l))) (f (add (succ l) k)))
           (add (add (f l) (inf-sum f k (succ l))) (f (add l (succ k))))
           (pathsinv0 nat (add (add (f l) (inf-sum f k (succ l))) (f (add (succ l) k)))
             (add (f l) (add (inf-sum f k (succ l)) (f (add (succ l) k))))
             (natplusassoc (f l) (inf-sum f k (succ l)) (f (add (succ l) k))))
           (maponpaths nat nat (lam w (add (add (f l) (inf-sum f k (succ l))) (f w)))
             (add (succ l) k) (add l (succ k)) (pathsinv0 nat (add l (succ k)) (add (succ l) k) (natplusnsm l k))))))))
     o))))

 ; one symbol has one length, so over the lengths it counts at most once
 (defq inf-dzero (pi x nat (pi o nat (pi l nat (pi g (inf-lt x l) (paths nat (inf-sum (inf-d x) o l) 0)))))
   (lam x (lam o (nat_rect (lam q (pi l nat (pi g (inf-lt x l) (paths nat (inf-sum (inf-d x) q l) 0))))
     (lam l (lam g (idpath 0)))
     (lam k (lam IH (lam l (lam g
       (inf-case (inf-eqb x l)
         (lam b (paths nat (add (bool_rect (lam c nat) 1 0 b) (inf-sum (inf-d x) k (succ l))) 0))
         (lam e (fromempty (paths nat (succ (inf-sum (inf-d x) k (succ l))) 0)
           (nopathstruetofalse (pathscomp0 bool true (inf-eqb x l) false
             (pathsinv0 bool (inf-eqb x l) true e) (inf-gtne x l g)))))
         (lam e (IH (succ l) (inf-lelts x l (inf-ltle x l g)))))))))
     o))))
 (defq inf-done (pi x nat (pi o nat (pi l nat (inf-le (inf-sum (inf-d x) o l) 1))))
   (lam x (lam o (nat_rect (lam q (pi l nat (inf-le (inf-sum (inf-d x) q l) 1)))
     (lam l (idpath false))
     (lam k (lam IH (lam l
       (inf-case (inf-eqb x l)
         (lam b (inf-le (add (bool_rect (lam c nat) 1 0 b) (inf-sum (inf-d x) k (succ l))) 1))
         (lam e (inf-letr 0 (inf-sum (inf-d x) k (succ l)) 0
           (pathsinv0 nat (inf-sum (inf-d x) k (succ l)) 0
             (inf-dzero x k (succ l)
               (inf-lelts x l (inf-letl x x l (inf-eqp x l e) (isreflnatleh x)))))
           (idpath false)))
         (lam e (IH (succ l)))))))
     o))))
 (defq inf-sum0 (pi o nat (pi l nat (paths nat (inf-sum (lam v 0) o l) 0)))
   (lam o (nat_rect (lam q (pi l nat (paths nat (inf-sum (lam v 0) q l) 0)))
     (lam l (idpath 0))
     (lam k (lam IH (lam l (IH (succ l)))))
     o)))
 ; so all the counts together are at most the symbols: cnt[1] + .. + cnt[15] <= nsym
 (defq inf-sumcount (pi L (pi i nat nat) (pi o nat (pi l nat (pi n nat
     (inf-le (inf-sum (lam v (inf-count L v n)) o l) n)))))
   (lam L (lam o (lam l (lam n (nat_rect (lam q (inf-le (inf-sum (lam v (inf-count L v q)) o l) q))
     (inf-letr 0 (inf-sum (lam v 0) o l) 0 (pathsinv0 nat (inf-sum (lam v 0) o l) 0 (inf-sum0 o l)) (idpath false))
     (lam k (lam IH
       (inf-letr (add (inf-sum (inf-d (L k)) o l) (inf-sum (lam v (inf-count L v k)) o l))
         (inf-sum (lam v (add (inf-d (L k) v) (inf-count L v k))) o l) (succ k)
         (pathsinv0 nat (inf-sum (lam v (add (inf-d (L k) v) (inf-count L v k))) o l)
           (add (inf-sum (inf-d (L k)) o l) (inf-sum (lam v (inf-count L v k)) o l))
           (inf-sumadd (inf-d (L k)) (lam v (inf-count L v k)) o l))
         (inf-add2 (inf-sum (inf-d (L k)) o l) 1 (inf-sum (lam v (inf-count L v k)) o l) k
           (inf-done (L k) o l) IH))))
     n))))))
 ; the walk's hypothesis, discharged: inf_walk's index is in for any lengths
 (defq inf-walkbuilt (pi L (pi i nat nat) (pi bit (pi l nat nat) (pi n nat
     (pi f nat (inf-ok n (inf-walk (lam v (inf-count L v n)) bit f 1 0 0 0))))))
   (lam L (lam bit (lam n (lam f
     (inf-walkidx (lam v (inf-count L v n)) bit n f (inf-sumcount L f 1 n)))))))

 ; a later symbol of the same length sees this one counted
 (defq inf-countmono (pi L (pi i nat nat) (pi v nat (pi i nat (pi m nat
     (inf-le (inf-count L v i) (inf-count L v (add m i)))))))
   (lam L (lam v (lam i (lam m (nat_rect (lam q (inf-le (inf-count L v i) (inf-count L v (add q i))))
     (isreflnatleh (inf-count L v i))
     (lam k (lam IH
       (istransnatleh (inf-count L v i) (inf-count L v (add k i)) (inf-count L v (succ (add k i))) IH
         (inf-leaddl (inf-count L v (add k i)) (inf-d (L (add k i)) v)))))
     m))))))
 (defq inf-counthit (pi L (pi i nat nat) (pi v nat (pi i nat (pi N nat (pi g (inf-lt i N)
     (pi e (paths bool (inf-eqb (L i) v) true) (inf-lt (inf-count L v i) (inf-count L v N))))))))
   (lam L (lam v (lam i (lam N (lam g (lam e
     (inf-lelts (succ (inf-count L v i)) (inf-count L v N)
       (inf-letr (inf-count L v (succ i)) (succ (inf-count L v i)) (inf-count L v N)
         (maponpaths bool nat (lam b (add (bool_rect (lam c nat) 1 0 b) (inf-count L v i))) (inf-eqb (L i) v) true e)
         (inf-letl (inf-count L v (succ i)) (inf-count L v (add (natminus N (succ i)) (succ i))) (inf-count L v N)
           (maponpaths nat nat (lam w (inf-count L v w)) (add (natminus N (succ i)) (succ i)) N
             (pathscomp0 nat (add (natminus N (succ i)) (succ i)) (add (succ i) (natminus N (succ i))) N
               (natpluscomm (natminus N (succ i)) (succ i))
               (inf-addsub (succ i) N (inf-ltsu i N g))))
           (inf-countmono L v (succ i) (natminus N (succ i)))))))))))))
 (defq inf-symclosed (pi L (pi i nat nat) (pi N nat (pi i nat (pi o nat (pi g (inf-lt i N)
     (pi e (paths bool (inf-eqb (L i) (succ o)) true)
       (inf-lt (add (inf-sum (lam v (inf-count L v N)) o 1) (inf-count L (succ o) i)) N)))))))
   (lam L (lam N (lam i (lam o (lam g (lam e
     (inf-lttrans (add (inf-sum (lam v (inf-count L v N)) o 1) (inf-count L (succ o) i))
       (add (inf-sum (lam v (inf-count L v N)) o 1) (inf-count L (succ o) N)) N
       (inf-ltaddl (inf-sum (lam v (inf-count L v N)) o 1) (inf-count L (succ o) i) (inf-count L (succ o) N)
         (inf-counthit L (succ o) i N g e))
       (inf-letr (inf-sum (lam v (inf-count L v N)) (succ o) 1)
         (add (inf-sum (lam v (inf-count L v N)) o 1) (inf-count L (succ o) N)) N
         (inf-snoc (lam v (inf-count L v N)) o 1)
         (inf-sumcount L (succ o) 1 N))))))))))

 ; the C loop itself: ofs as an array, one write per nonzero length
 (defn inf-upd (pi f (pi j nat nat) (pi k nat (pi v nat (pi j nat nat))))
   (lam f (lam k (lam v (lam j (bool_rect (lam b nat) v (f j) (inf-eqb k j)))))))
 (defn inf-ofs0 (pi cnt (pi v nat nat) (pi v nat nat))
   (lam cnt (lam v (nat_rect (lam q nat) 0 (lam o (lam u (inf-sum cnt o 1))) v))))
 (defn inf-run (pi L (pi i nat nat) (pi cnt (pi v nat nat) (pi i nat (pi v nat nat))))
   (lam L (lam cnt (lam i (nat_rect (lam q (pi v nat nat))
     (inf-ofs0 cnt)
     (lam k (lam r (bool_rect (lam b (pi v nat nat))
       r
       (inf-upd r (L k) (succ (r (L k))))
       (inf-eqb (L k) 0))))
     i)))))
 (defq inf-runclosed (pi L (pi i nat nat) (pi cnt (pi v nat nat) (pi o nat (pi i nat
     (paths nat (inf-run L cnt i (succ o)) (add (inf-sum cnt o 1) (inf-count L (succ o) i)))))))
   (lam L (lam cnt (lam o (lam i (nat_rect
     (lam q (paths nat (inf-run L cnt q (succ o)) (add (inf-sum cnt o 1) (inf-count L (succ o) q))))
     (pathsinv0 nat (add (inf-sum cnt o 1) 0) (inf-sum cnt o 1) (natplusr0 (inf-sum cnt o 1)))
     (lam k (lam IH
       (inf-case (inf-eqb (L k) 0)
         (lam b (paths nat
           ((bool_rect (lam z (pi v nat nat)) (inf-run L cnt k)
              (inf-upd (inf-run L cnt k) (L k) (succ (inf-run L cnt k (L k)))) b) (succ o))
           (add (inf-sum cnt o 1) (add (inf-d (L k) (succ o)) (inf-count L (succ o) k)))))
         (lam e (pathscomp0 nat (inf-run L cnt k (succ o))
           (add (inf-sum cnt o 1) (inf-count L (succ o) k))
           (add (inf-sum cnt o 1) (add (inf-d (L k) (succ o)) (inf-count L (succ o) k)))
           IH
           (maponpaths bool nat
             (lam b (add (inf-sum cnt o 1) (add (bool_rect (lam c nat) 1 0 b) (inf-count L (succ o) k))))
             false (inf-eqb (L k) (succ o))
             (pathsinv0 bool (inf-eqb (L k) (succ o)) false (inf-eq0ne (L k) o e)))))
         (lam e (inf-case (inf-eqb (L k) (succ o))
           (lam b (paths nat
             (bool_rect (lam c nat) (succ (inf-run L cnt k (L k))) (inf-run L cnt k (succ o)) b)
             (add (inf-sum cnt o 1) (add (bool_rect (lam c nat) 1 0 b) (inf-count L (succ o) k)))))
           (lam f (pathscomp0 nat (succ (inf-run L cnt k (L k)))
             (succ (add (inf-sum cnt o 1) (inf-count L (succ o) k)))
             (add (inf-sum cnt o 1) (succ (inf-count L (succ o) k)))
             (maponpaths nat nat (lam w (succ w)) (inf-run L cnt k (L k))
               (add (inf-sum cnt o 1) (inf-count L (succ o) k))
               (pathscomp0 nat (inf-run L cnt k (L k)) (inf-run L cnt k (succ o))
                 (add (inf-sum cnt o 1) (inf-count L (succ o) k))
                 (maponpaths nat nat (inf-run L cnt k) (L k) (succ o) (inf-eqp (L k) (succ o) f))
                 IH))
             (pathsinv0 nat (add (inf-sum cnt o 1) (succ (inf-count L (succ o) k)))
               (succ (add (inf-sum cnt o 1) (inf-count L (succ o) k)))
               (natplusnsm (inf-sum cnt o 1) (inf-count L (succ o) k)))))
           (lam f IH))))))
     i))))))
 ; the write: sym[ofs[lens[i]]], for any lengths, over-subscribed or not
 (defq inf-symw (pi L (pi i nat nat) (pi N nat (pi i nat (pi o nat (pi g (inf-lt i N)
     (pi e (paths bool (inf-eqb (L i) (succ o)) true)
       (inf-lt (inf-run L (lam v (inf-count L v N)) i (succ o)) N)))))))
   (lam L (lam N (lam i (lam o (lam g (lam e
     (inf-lttr (add (inf-sum (lam v (inf-count L v N)) o 1) (inf-count L (succ o) i))
       (inf-run L (lam v (inf-count L v N)) i (succ o)) N
       (pathsinv0 nat (inf-run L (lam v (inf-count L v N)) i (succ o))
         (add (inf-sum (lam v (inf-count L v N)) o 1) (inf-count L (succ o) i))
         (inf-runclosed L (lam v (inf-count L v N)) o i))
       (inf-symclosed L N i o g e))))))))))
