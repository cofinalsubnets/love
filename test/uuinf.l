; test/uuinf.l -- inflate's bounds, stated of a model of inflate.h and prefix.h. the first batch: one
; obligation of each class, to price them. C subtraction wraps and natminus truncates, so a
; subtraction owes its no-wrap beside its bound

; --- the order, as inflate's checks read it ---
(test
 (defn inf-le (pi a nat b nat UU) (lam a b (paths bool (natgtb a b) false)))
 (defn inf-lt (pi a nat b nat UU) (lam a b (paths bool (natgtb b a) true)))
 (defq inf-lelts (pi a nat b nat g (inf-le a b) (inf-lt a (succ b)))
   (lam a (nat_rect (lam q (pi b nat g (inf-le q b) (inf-lt q (succ b))))
     (lam b g (idpath true))
     (lam k IH b (nat_rect (lam r (pi g (inf-le (succ k) r) (inf-lt (succ k) (succ r))))
       (lam g (fromempty (inf-lt (succ k) 1) (nopathstruetofalse g)))
       (lam j u g (IH j g))
       b))
     a)))
 (defq inf-ltsle (pi a nat b nat g (inf-lt a (succ b)) (inf-le a b))
   (lam a (nat_rect (lam q (pi b nat g (inf-lt q (succ b)) (inf-le q b)))
     (lam b g (idpath false))
     (lam k IH b (nat_rect (lam r (pi g (inf-lt (succ k) (succ r)) (inf-le (succ k) r)))
       (lam g (fromempty (inf-le (succ k) 0) (nopathsfalsetotrue g)))
       (lam j u g (IH j g))
       b))
     a)))
 (defq inf-ltsu (pi a nat b nat g (inf-lt a b) (inf-le (succ a) b))
   (lam a (nat_rect (lam q (pi b nat g (inf-lt q b) (inf-le (succ q) b)))
     (lam b (nat_rect (lam r (pi g (inf-lt 0 r) (inf-le 1 r)))
       (lam g (fromempty (inf-le 1 0) (nopathsfalsetotrue g)))
       (lam j u g (idpath false))
       b))
     (lam k IH b (nat_rect (lam r (pi g (inf-lt (succ k) r) (inf-le (succ (succ k)) r)))
       (lam g (fromempty (inf-le (succ (succ k)) 0) (nopathsfalsetotrue g)))
       (lam j u g (IH j g))
       b))
     a)))
 (defq inf-ltle (pi a nat b nat g (inf-lt a b) (inf-le a b))
   (lam a b g (natlthtoleh a b g)))
 (defq inf-lttrans (pi a nat b nat c nat g (inf-lt a b) h (inf-le b c) (inf-lt a c))
   (lam a b c g h
     (inf-lelts (succ a) c (istransnatleh (succ a) b c (inf-ltsu a b g) h))))
 (defq inf-letr (pi a nat b nat c nat e (paths nat a b) g (inf-le a c) (inf-le b c))
   (lam a b c e g (transportf nat (lam x (inf-le x c)) a b e g)))
 (defq inf-letl (pi a nat b nat c nat e (paths nat b c) g (inf-le a b) (inf-le a c))
   (lam a b c e g (transportf nat (lam x (inf-le a x)) b c e g)))
 (defq inf-lttr (pi a nat b nat c nat e (paths nat a b) g (inf-lt a c) (inf-lt b c))
   (lam a b c e g (transportf nat (lam x (inf-lt x c)) a b e g)))
 ; a branch on a bool, its answer in hand
 (defn inf-case (pi b bool P (pi x bool UU)
     t (pi e (paths bool b true) (P true)) f (pi e (paths bool b false) (P false)) (P b))
   (lam b P t f
     ((bool_rect (lam x (pi e (paths bool b x) (P x))) t f b) (idpath b)))))

; --- sums: monotone both ways, strictly when strictly ---
(test
 (defq inf-addl (pi c nat a nat b nat g (inf-le a b) (inf-le (add c a) (add c b)))
   (lam c a b g (nat_rect (lam q (inf-le (add q a) (add q b))) g (lam k IH IH) c)))
 (defq inf-leaddl (pi c nat b nat (inf-le c (add b c)))
   (lam c b (nat_rect (lam q (inf-le c (add q c)))
     (isreflnatleh c)
     (lam k IH (natlehsucc c (add k c) IH))
     b)))
 (defq inf-leaddr (pi a nat b nat (inf-le a (add a b)))
   (lam a b (nat_rect (lam q (inf-le q (add q b))) (idpath false) (lam k IH IH) a)))
 (defq inf-addr (pi a nat b nat c nat g (inf-le a b) (inf-le (add a c) (add b c)))
   (lam a (nat_rect (lam q (pi b nat c nat g (inf-le q b) (inf-le (add q c) (add b c))))
     (lam b c g (inf-leaddl c b))
     (lam k IH b (nat_rect
       (lam r (pi c nat g (inf-le (succ k) r) (inf-le (add (succ k) c) (add r c))))
       (lam c g (fromempty (inf-le (add (succ k) c) c) (nopathstruetofalse g)))
       (lam j u c g (IH j c g))
       b))
     a)))
 (defq inf-add2 (pi a nat b nat c nat d nat g (inf-le a b) h (inf-le c d)
     (inf-le (add a c) (add b d)))
   (lam a b c d g h
     (istransnatleh (add a c) (add b c) (add b d) (inf-addr a b c g) (inf-addl b c d h))))
 (defq inf-ltaddl (pi c nat a nat b nat g (inf-lt a b) (inf-lt (add c a) (add c b)))
   (lam c a b g (nat_rect (lam q (inf-lt (add q a) (add q b))) g (lam k IH IH) c)))
 (defq inf-ltaddr (pi a nat b nat c nat g (inf-lt a b) (inf-lt (add a c) (add b c)))
   (lam a b c g
     (inf-lelts (succ (add a c)) (add b c) (inf-addr (succ a) b c (inf-ltsu a b g)))))
 (defq inf-dbl (pi a nat b nat g (inf-le a b) (inf-le (add a a) (add b b)))
   (lam a b g (inf-add2 a b a b g g))))

; --- differences ---
(test
 (defq inf-suble (pi a nat b nat (inf-le (natminus a b) a))
   (lam a (nat_rect (lam q (pi b nat (inf-le (natminus q b) q)))
     (lam b (idpath false))
     (lam k IH b (nat_rect (lam r (inf-le (natminus (succ k) r) (succ k)))
       (isreflnatleh (succ k))
       (lam j u (natlehsucc (natminus k j) k (IH j)))
       b))
     a)))
 (defq inf-submono (pi a nat b nat c nat g (inf-le a b) (inf-le (natminus a c) (natminus b c)))
   (lam a (nat_rect (lam q (pi b nat c nat g (inf-le q b) (inf-le (natminus q c) (natminus b c))))
     (lam b c g (idpath false))
     (lam k IH b (nat_rect
       (lam r (pi c nat g (inf-le (succ k) r) (inf-le (natminus (succ k) c) (natminus r c))))
       (lam c g (fromempty (inf-le (natminus (succ k) c) (natminus 0 c)) (nopathstruetofalse g)))
       (lam j u c (nat_rect
         (lam s (pi g (inf-le (succ k) (succ j)) (inf-le (natminus (succ k) s) (natminus (succ j) s))))
         (lam g g)
         (lam m v g (IH j m g))
         c))
       b))
     a)))
 ; a reach back lands below where it started, so long as it reaches at all
 (defq inf-subdec (pi a nat d nat p (inf-lt 0 d) g (inf-le d a) (inf-lt (natminus a d) a))
   (lam a d (nat_rect (lam r (pi p (inf-lt 0 r) g (inf-le r a) (inf-lt (natminus a r) a)))
     (lam p g (fromempty (inf-lt (natminus a 0) a) (nopathsfalsetotrue p)))
     (lam e u p (nat_rect
       (lam q (pi g (inf-le (succ e) q) (inf-lt (natminus q (succ e)) q)))
       (lam g (fromempty (inf-lt (natminus 0 (succ e)) 0) (nopathstruetofalse g)))
       (lam o w g (inf-lelts (natminus o e) o (inf-suble o e)))
       a))
     d)))
 (defq inf-addsub (pi b nat a nat g (inf-le b a) (paths nat (add b (natminus a b)) a))
   (lam b (nat_rect (lam q (pi a nat g (inf-le q a) (paths nat (add q (natminus a q)) a)))
     (lam a g (natminusn0 a))
     (lam k IH a (nat_rect
       (lam r (pi g (inf-le (succ k) r) (paths nat (add (succ k) (natminus r (succ k))) r)))
       (lam g (fromempty (paths nat (add (succ k) (natminus 0 (succ k))) 0) (nopathstruetofalse g)))
       (lam j u g (maponpaths nat nat (lam w (succ w)) (add k (natminus j k)) j (IH j g)))
       a))
     b)))
 ; the walk's step: c past f and short of f + n stands short of n
 (defq inf-subshort (pi f nat c nat n nat g (inf-le f c) h (inf-lt c (add f n))
     (inf-lt (natminus c f) n))
   (lam f (nat_rect (lam q (pi c nat n nat g (inf-le q c) h (inf-lt c (add q n))
       (inf-lt (natminus c q) n)))
     (lam c n g h
       (inf-lttr c (natminus c 0) n (pathsinv0 nat (natminus c 0) c (natminusn0 c)) h))
     (lam k IH c (nat_rect
       (lam r (pi n nat g (inf-le (succ k) r) h (inf-lt r (add (succ k) n))
         (inf-lt (natminus r (succ k)) n)))
       (lam n g h (fromempty (inf-lt (natminus 0 (succ k)) n) (nopathstruetofalse g)))
       (lam j u n g h (IH j n g h))
       c))
     f))))

; --- class 1: an index a check guards. inflate.h 184-190 ---
(test
 (defq inf-lidx-nowrap (pi sy nat g (inf-lt 256 sy) (inf-le 257 sy))
   (lam sy g (inf-ltsu 256 sy g)))
 (defq inf-lidx (pi sy nat g (inf-le sy 285) (inf-lt (natminus sy 257) 29))
   (lam sy g (inf-lelts (natminus sy 257) 28 (inf-submono sy 285 257 g))))
 (defq inf-didx (pi sy nat g (inf-le sy 29) (inf-lt sy 30))
   (lam sy g (inf-lelts sy 29 g))))

; --- class 2: an index a mask bounds. bb & ((1 << k) - 1) is bb mod 2^k, which is what the model
; --- says: the generator owes the spelling
(test
 (defn inf-mod (pi m nat x nat nat)
   (lam m x (nat_rect (lam q nat) 0
     (lam k r (bool_rect (lam b nat) (succ r) 0 (natgtb m (succ r))))
     x)))
 (5 = vof 0 '(inf-mod 8 21))
 (15 = vof 0 '(inf-mod 16 15))
 (defq inf-modlt (pi p nat x nat (inf-lt (inf-mod (succ p) x) (succ p)))
   (lam p x (nat_rect (lam q (inf-lt (inf-mod (succ p) q) (succ p)))
     (idpath true)
     (lam k IH (inf-case (natgtb (succ p) (succ (inf-mod (succ p) k)))
       (lam b (inf-lt (bool_rect (lam c nat) (succ (inf-mod (succ p) k)) 0 b) (succ p)))
       (lam e e)
       (lam e (idpath true))))
     x)))
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
 (defq inf-lenscap (pi a nat b nat
     (inf-le (add (add 257 (inf-mod 32 a)) (add 1 (inf-mod 32 b))) 320))
   (lam a b (inf-add2 (add 257 (inf-mod 32 a)) 288 (add 1 (inf-mod 32 b)) 32 (inf-hlit a) (inf-hdist b)))))

; --- class 3: a match copy. inflate.h 191-205, past its two checks ---
(test
 ; d <= op: dp[k] and sp[k]
 (defq inf-cw (pi op nat k nat l nat cap nat g (inf-lt k l) h (inf-le (add op l) cap)
     (inf-lt (add op k) cap))
   (lam op k l cap g h
     (inf-lttrans (add op k) (add op l) cap (inf-ltaddl op k l g) h)))
 (defq inf-cr (pi op nat d nat k nat p (inf-lt 0 d) g (inf-le d op)
     (inf-lt (add (natminus op d) k) (add op k)))
   (lam op d k p g
     (inf-ltaddr (natminus op d) op k (inf-subdec op d p g))))
 ; d > op: h = min (d - op) l comes from the dictionary, the rest from the output
 (defn inf-h (pi d nat op nat l nat nat)
   (lam d op l (bool_rect (lam b nat) (natminus d op) l (natgtb l (natminus d op)))))
 (defq inf-hle (pi d nat op nat l nat (inf-le (inf-h d op l) (natminus d op)))
   (lam d op l (inf-case (natgtb l (natminus d op))
     (lam b (inf-le (bool_rect (lam c nat) (natminus d op) l b) (natminus d op)))
     (lam e (isreflnatleh (natminus d op)))
     (lam e e))))
 (defq inf-hlel (pi d nat op nat l nat (inf-le (inf-h d op l) l))
   (lam d op l (inf-case (natgtb l (natminus d op))
     (lam b (inf-le (bool_rect (lam c nat) (natminus d op) l b) l))
     (lam e (inf-ltle (natminus d op) l e))
     (lam e (isreflnatleh l)))))
 ; memcpy (out + op, ..): the write's end
 (defq inf-dw (pi d nat op nat l nat cap nat h (inf-le (add op l) cap)
     (inf-le (add op (inf-h d op l)) cap))
   (lam d op l cap h
     (istransnatleh (add op (inf-h d op l)) (add op l) cap
       (inf-addl op (inf-h d op l) l (inf-hlel d op l)) h)))
 ; memcpy (.., dic + nd - (d - op), h): start no wrap, end within nd
 (defq inf-cancel (pi a nat b nat (paths nat (natminus (add a b) a) b))
   (lam a b (nat_rect (lam q (paths nat (natminus (add q b) q) b))
     (natminusn0 b)
     (lam k IH IH)
     a)))
 (defq inf-dnowrap (pi d nat op nat nd nat g (inf-le d (add op nd)) (inf-le (natminus d op) nd))
   (lam d op nd g
     (inf-letl (natminus d op) (natminus (add op nd) op) nd (inf-cancel op nd)
       (inf-submono d (add op nd) op g))))
 (defq inf-dr (pi d nat op nat l nat nd nat g (inf-le d (add op nd))
     (inf-le (add (natminus nd (natminus d op)) (inf-h d op l)) nd))
   (lam d op l nd g
     (inf-letl (add (natminus nd (natminus d op)) (inf-h d op l))
       (add (natminus nd (natminus d op)) (natminus d op)) nd
       (pathscomp0 nat (add (natminus nd (natminus d op)) (natminus d op))
         (add (natminus d op) (natminus nd (natminus d op))) nd
         (natpluscomm (natminus nd (natminus d op)) (natminus d op))
         (inf-addsub (natminus d op) nd (inf-dnowrap d op nd g)))
       (inf-addl (natminus nd (natminus d op)) (inf-h d op l) (natminus d op) (inf-hle d op l)))))
 ; out[op + k - d] past the dictionary: k past h has left it, so the reach no longer wraps
 (defq inf-dknowrap (pi d nat op nat l nat k nat g (inf-le op d)
     x (inf-le (inf-h d op l) k) y (inf-lt k l) (inf-le d (add op k)))
   (lam d op l k g
     (inf-case (natgtb l (natminus d op))
       (lam b (pi x (inf-le (bool_rect (lam c nat) (natminus d op) l b) k)
         y (inf-lt k l) (inf-le d (add op k))))
       (lam e x y
         (inf-letr (add op (natminus d op)) d (add op k) (inf-addsub op d g)
           (inf-addl op (natminus d op) k x)))
       (lam e x y
         (fromempty (inf-le d (add op k)) (natlehtonegnatgth l k x y))))))
 (defq inf-dkr (pi d nat op nat l nat k nat p (inf-lt 0 d) g (inf-le op d)
     x (inf-le (inf-h d op l) k) y (inf-lt k l)
       (inf-lt (natminus (add op k) d) (add op k)))
   (lam d op l k p g x y
     (inf-subdec (add op k) d p (inf-dknowrap d op l k g x y)))))

; --- class 4: a loop's invariant. inf_walk, prefix.h 32-40: first <= code on entry, whatever the
; --- counts say, and index + the counts to come within nsym, so sym[index + code - first] is in
(test
 (defn inf-sum (pi cnt (pi l nat nat) f nat l nat nat)
   (lam cnt f (nat_rect (lam q (pi l nat nat))
     (lam l 0)
     (lam k IH l (add (cnt l) (IH (succ l))))
     f)))
 (defn inf-walk (pi cnt (pi l nat nat) bit (pi l nat nat) f nat
     l nat code nat first nat index nat (coprod nat unit))
   (lam cnt bit f (nat_rect
     (lam q (pi l nat code nat first nat index nat (coprod nat unit)))
     (lam l code first index (ii2 tt))
     (lam k IH l code first index
       (bool_rect (lam b (coprod nat unit))
         (ii1 (add index (natminus (add code (bit l)) first)))
         (IH (succ l) (add (add code (bit l)) (add code (bit l)))
             (add (add first (cnt l)) (add first (cnt l))) (add index (cnt l)))
         (natgtb (add first (cnt l)) (add code (bit l))))) 
     f)))
 (defn inf-ok (pi n nat r (coprod nat unit) UU)
   (lam n r (coprod_rect (lam x UU) (lam i (inf-lt i n)) (lam u unit) r)))
 (defq inf-walkok (pi cnt (pi l nat nat) bit (pi l nat nat) n nat f nat
     l nat code nat first nat index nat g (inf-le first code)
       h (inf-le (add index (inf-sum cnt f l)) n)
         (inf-ok n (inf-walk cnt bit f l code first index)))
   (lam cnt bit n f (nat_rect
     (lam q (pi l nat code nat first nat index nat g (inf-le first code)
       h (inf-le (add index (inf-sum cnt q l)) n)
         (inf-ok n (inf-walk cnt bit q l code first index))))
     (lam l code first index g h tt)
     (lam k IH l code first index g h
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
             h)))))
     f)))
 ; inf_walk's entry, all three at zero; fifteen lengths or any number
 (defq inf-walkidx (pi cnt (pi l nat nat) bit (pi l nat nat) n nat f nat
     h (inf-le (inf-sum cnt f 1) n) (inf-ok n (inf-walk cnt bit f 1 0 0 0)))
   (lam cnt bit n f h (inf-walkok cnt bit n f 1 0 0 0 (idpath false) h)))
 ; one code of length 1 and two of length 2: 0 is the first symbol, 1 0 the second, 1 1 the third,
 ; so the model decodes and its theorem is not empty
 (defn inf-cnt3 (pi l nat nat)
   (lam l (nat_rect (lam q nat) 0
     (lam k u (nat_rect (lam q nat) 1 (lam j w (nat_rect (lam q nat) 2 (lam i x 0) j)) k))
     l)))
 (defn inf-bits (pi a nat b nat l nat nat)
   (lam a b l (nat_rect (lam q nat) 0
     (lam k u (nat_rect (lam q nat) a (lam j w b) k))
     l)))
 (['i1 0] = vof 0 '(inf-walk inf-cnt3 (inf-bits 0 1) 3 1 0 0 0))
 (['i1 1] = vof 0 '(inf-walk inf-cnt3 (inf-bits 1 0) 3 1 0 0 0))
 (['i1 2] = vof 0 '(inf-walk inf-cnt3 (inf-bits 1 1) 3 1 0 0 0)))

; --- class 5: what a loop left in an array. inf_build, prefix.h 16-20: ofs[v] after i symbols is what
; --- came before v plus the v's so far, so sym[ofs[lens[i]]++] stays under nsym on any lengths at all
(test
 (defn inf-eqb (pi n nat m nat bool)
   (lam n (nat_rect (lam q (pi m nat bool))
     (lam m (nat_rect (lam r bool) true (lam j u false) m))
     (lam k IH m (nat_rect (lam r bool) false (lam j u (IH j)) m))
     n)))
 (defq inf-eqp (pi a nat b nat e (paths bool (inf-eqb a b) true) (paths nat a b))
   (lam a (nat_rect (lam q (pi b nat e (paths bool (inf-eqb q b) true) (paths nat q b)))
     (lam b (nat_rect (lam r (pi e (paths bool (inf-eqb 0 r) true) (paths nat 0 r)))
       (lam e (idpath 0))
       (lam j u e (fromempty (paths nat 0 (succ j)) (nopathsfalsetotrue e)))
       b))
     (lam k IH b (nat_rect (lam r (pi e (paths bool (inf-eqb (succ k) r) true) (paths nat (succ k) r)))
       (lam e (fromempty (paths nat (succ k) 0) (nopathsfalsetotrue e)))
       (lam j u e (maponpaths nat nat (lam w (succ w)) k j (IH j e)))
       b))
     a)))
 (defq inf-gtne (pi x nat l nat g (inf-lt x l) (paths bool (inf-eqb x l) false))
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
 (defq inf-eq0ne (pi x nat o nat e (paths bool (inf-eqb x 0) true) (paths bool (inf-eqb x (succ o)) false))
   (lam x o (nat_rect (lam q (pi e (paths bool (inf-eqb q 0) true) (paths bool (inf-eqb q (succ o)) false)))
     (lam e (idpath false))
     (lam k u e (fromempty (paths bool (inf-eqb (succ k) (succ o)) false) (nopathsfalsetotrue e)))
     x)))
 (defn inf-d (pi x nat v nat nat) (lam x v (bool_rect (lam b nat) 1 0 (inf-eqb x v))))
 (defn inf-count (pi L (pi i nat nat) v nat n nat nat)
   (lam L v n (nat_rect (lam q nat) 0 (lam k r (add (inf-d (L k) v) r)) n)))

 ; a sum over lengths splits, and a snoc is what the C's ofs[l + 1] = ofs[l] + cnt[l] walks
 (defq inf-lswap (pi b nat c nat d nat (paths nat (add b (add c d)) (add c (add b d))))
   (lam b c d (nat_rect (lam q (paths nat (add q (add c d)) (add c (add q d))))
     (idpath (add c d))
     (lam k IH (pathscomp0 nat (succ (add k (add c d))) (succ (add c (add k d))) (add c (succ (add k d)))
       (maponpaths nat nat (lam w (succ w)) (add k (add c d)) (add c (add k d)) IH)
       (pathsinv0 nat (add c (succ (add k d))) (succ (add c (add k d))) (natplusnsm c (add k d)))))
     b)))
 (defq inf-swap4 (pi a nat b nat c nat d nat
     (paths nat (add (add a b) (add c d)) (add (add a c) (add b d))))
   (lam a b c d (nat_rect (lam q (paths nat (add (add q b) (add c d)) (add (add q c) (add b d))))
     (inf-lswap b c d)
     (lam k IH (maponpaths nat nat (lam w (succ w))
       (add (add k b) (add c d)) (add (add k c) (add b d)) IH))
     a)))
 (defq inf-sumadd (pi f (pi v nat nat) g (pi v nat nat) o nat l nat
     (paths nat (inf-sum (lam v (add (f v) (g v))) o l) (add (inf-sum f o l) (inf-sum g o l))))
   (lam f g o (nat_rect
     (lam q (pi l nat (paths nat (inf-sum (lam v (add (f v) (g v))) q l) (add (inf-sum f q l) (inf-sum g q l)))))
     (lam l (idpath 0))
     (lam k IH l
       (pathscomp0 nat (add (add (f l) (g l)) (inf-sum (lam v (add (f v) (g v))) k (succ l)))
         (add (add (f l) (g l)) (add (inf-sum f k (succ l)) (inf-sum g k (succ l))))
         (add (add (f l) (inf-sum f k (succ l))) (add (g l) (inf-sum g k (succ l))))
         (maponpaths nat nat (lam w (add (add (f l) (g l)) w))
           (inf-sum (lam v (add (f v) (g v))) k (succ l))
           (add (inf-sum f k (succ l)) (inf-sum g k (succ l))) (IH (succ l)))
         (inf-swap4 (f l) (g l) (inf-sum f k (succ l)) (inf-sum g k (succ l)))))
     o)))
 (defq inf-snoc (pi f (pi v nat nat) o nat l nat
     (paths nat (inf-sum f (succ o) l) (add (inf-sum f o l) (f (add l o)))))
   (lam f o (nat_rect
     (lam q (pi l nat (paths nat (inf-sum f (succ q) l) (add (inf-sum f q l) (f (add l q))))))
     (lam l (pathscomp0 nat (add (f l) 0) (f l) (f (add l 0))
       (natplusr0 (f l))
       (maponpaths nat nat f l (add l 0) (pathsinv0 nat (add l 0) l (natplusr0 l)))))
     (lam k IH l
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
             (add (succ l) k) (add l (succ k)) (pathsinv0 nat (add l (succ k)) (add (succ l) k) (natplusnsm l k))))))
     o)))

 ; one symbol has one length, so over the lengths it counts at most once
 (defq inf-dzero (pi x nat o nat l nat g (inf-lt x l) (paths nat (inf-sum (inf-d x) o l) 0))
   (lam x o (nat_rect (lam q (pi l nat g (inf-lt x l) (paths nat (inf-sum (inf-d x) q l) 0)))
     (lam l g (idpath 0))
     (lam k IH l g
       (inf-case (inf-eqb x l)
         (lam b (paths nat (add (bool_rect (lam c nat) 1 0 b) (inf-sum (inf-d x) k (succ l))) 0))
         (lam e (fromempty (paths nat (succ (inf-sum (inf-d x) k (succ l))) 0)
           (nopathstruetofalse (pathscomp0 bool true (inf-eqb x l) false
             (pathsinv0 bool (inf-eqb x l) true e) (inf-gtne x l g)))))
         (lam e (IH (succ l) (inf-lelts x l (inf-ltle x l g))))))
     o)))
 (defq inf-done (pi x nat o nat l nat (inf-le (inf-sum (inf-d x) o l) 1))
   (lam x o (nat_rect (lam q (pi l nat (inf-le (inf-sum (inf-d x) q l) 1)))
     (lam l (idpath false))
     (lam k IH l
       (inf-case (inf-eqb x l)
         (lam b (inf-le (add (bool_rect (lam c nat) 1 0 b) (inf-sum (inf-d x) k (succ l))) 1))
         (lam e (inf-letr 0 (inf-sum (inf-d x) k (succ l)) 0
           (pathsinv0 nat (inf-sum (inf-d x) k (succ l)) 0
             (inf-dzero x k (succ l)
               (inf-lelts x l (inf-letl x x l (inf-eqp x l e) (isreflnatleh x)))))
           (idpath false)))
         (lam e (IH (succ l)))))
     o)))
 (defq inf-sum0 (pi o nat l nat (paths nat (inf-sum (lam v 0) o l) 0))
   (lam o (nat_rect (lam q (pi l nat (paths nat (inf-sum (lam v 0) q l) 0)))
     (lam l (idpath 0))
     (lam k IH l (IH (succ l)))
     o)))
 ; so all the counts together are at most the symbols: cnt[1] + .. + cnt[15] <= nsym
 (defq inf-sumcount (pi L (pi i nat nat) o nat l nat n nat
     (inf-le (inf-sum (lam v (inf-count L v n)) o l) n))
   (lam L o l n (nat_rect (lam q (inf-le (inf-sum (lam v (inf-count L v q)) o l) q))
     (inf-letr 0 (inf-sum (lam v 0) o l) 0 (pathsinv0 nat (inf-sum (lam v 0) o l) 0 (inf-sum0 o l)) (idpath false))
     (lam k IH
       (inf-letr (add (inf-sum (inf-d (L k)) o l) (inf-sum (lam v (inf-count L v k)) o l))
         (inf-sum (lam v (add (inf-d (L k) v) (inf-count L v k))) o l) (succ k)
         (pathsinv0 nat (inf-sum (lam v (add (inf-d (L k) v) (inf-count L v k))) o l)
           (add (inf-sum (inf-d (L k)) o l) (inf-sum (lam v (inf-count L v k)) o l))
           (inf-sumadd (inf-d (L k)) (lam v (inf-count L v k)) o l))
         (inf-add2 (inf-sum (inf-d (L k)) o l) 1 (inf-sum (lam v (inf-count L v k)) o l) k
           (inf-done (L k) o l) IH)))
     n)))
 ; the walk's hypothesis, discharged: inf_walk's index is in for any lengths
 (defq inf-walkbuilt (pi L (pi i nat nat) bit (pi l nat nat) n nat
     f nat (inf-ok n (inf-walk (lam v (inf-count L v n)) bit f 1 0 0 0)))
   (lam L bit n f
     (inf-walkidx (lam v (inf-count L v n)) bit n f (inf-sumcount L f 1 n))))

 ; a later symbol of the same length sees this one counted
 (defq inf-countmono (pi L (pi i nat nat) v nat i nat m nat
     (inf-le (inf-count L v i) (inf-count L v (add m i))))
   (lam L v i m (nat_rect (lam q (inf-le (inf-count L v i) (inf-count L v (add q i))))
     (isreflnatleh (inf-count L v i))
     (lam k IH
       (istransnatleh (inf-count L v i) (inf-count L v (add k i)) (inf-count L v (succ (add k i))) IH
         (inf-leaddl (inf-count L v (add k i)) (inf-d (L (add k i)) v))))
     m)))
 (defq inf-counthit (pi L (pi i nat nat) v nat i nat N nat g (inf-lt i N)
     e (paths bool (inf-eqb (L i) v) true) (inf-lt (inf-count L v i) (inf-count L v N)))
   (lam L v i N g e
     (inf-lelts (succ (inf-count L v i)) (inf-count L v N)
       (inf-letr (inf-count L v (succ i)) (succ (inf-count L v i)) (inf-count L v N)
         (maponpaths bool nat (lam b (add (bool_rect (lam c nat) 1 0 b) (inf-count L v i))) (inf-eqb (L i) v) true e)
         (inf-letl (inf-count L v (succ i)) (inf-count L v (add (natminus N (succ i)) (succ i))) (inf-count L v N)
           (maponpaths nat nat (lam w (inf-count L v w)) (add (natminus N (succ i)) (succ i)) N
             (pathscomp0 nat (add (natminus N (succ i)) (succ i)) (add (succ i) (natminus N (succ i))) N
               (natpluscomm (natminus N (succ i)) (succ i))
               (inf-addsub (succ i) N (inf-ltsu i N g))))
           (inf-countmono L v (succ i) (natminus N (succ i))))))))
 (defq inf-symclosed (pi L (pi i nat nat) N nat i nat o nat g (inf-lt i N)
     e (paths bool (inf-eqb (L i) (succ o)) true)
       (inf-lt (add (inf-sum (lam v (inf-count L v N)) o 1) (inf-count L (succ o) i)) N))
   (lam L N i o g e
     (inf-lttrans (add (inf-sum (lam v (inf-count L v N)) o 1) (inf-count L (succ o) i))
       (add (inf-sum (lam v (inf-count L v N)) o 1) (inf-count L (succ o) N)) N
       (inf-ltaddl (inf-sum (lam v (inf-count L v N)) o 1) (inf-count L (succ o) i) (inf-count L (succ o) N)
         (inf-counthit L (succ o) i N g e))
       (inf-letr (inf-sum (lam v (inf-count L v N)) (succ o) 1)
         (add (inf-sum (lam v (inf-count L v N)) o 1) (inf-count L (succ o) N)) N
         (inf-snoc (lam v (inf-count L v N)) o 1)
         (inf-sumcount L (succ o) 1 N)))))

 ; the C loop itself: ofs as an array, one write per nonzero length
 (defn inf-upd (pi f (pi j nat nat) k nat v nat j nat nat)
   (lam f k v j (bool_rect (lam b nat) v (f j) (inf-eqb k j))))
 (defn inf-ofs0 (pi cnt (pi v nat nat) v nat nat)
   (lam cnt v (nat_rect (lam q nat) 0 (lam o u (inf-sum cnt o 1)) v)))
 (defn inf-run (pi L (pi i nat nat) cnt (pi v nat nat) i nat v nat nat)
   (lam L cnt i (nat_rect (lam q (pi v nat nat))
     (inf-ofs0 cnt)
     (lam k r (bool_rect (lam b (pi v nat nat))
       r
       (inf-upd r (L k) (succ (r (L k))))
       (inf-eqb (L k) 0)))
     i)))
 (defq inf-runclosed (pi L (pi i nat nat) cnt (pi v nat nat) o nat i nat
     (paths nat (inf-run L cnt i (succ o)) (add (inf-sum cnt o 1) (inf-count L (succ o) i))))
   (lam L cnt o i (nat_rect
     (lam q (paths nat (inf-run L cnt q (succ o)) (add (inf-sum cnt o 1) (inf-count L (succ o) q))))
     (pathsinv0 nat (add (inf-sum cnt o 1) 0) (inf-sum cnt o 1) (natplusr0 (inf-sum cnt o 1)))
     (lam k IH
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
           (lam f IH)))))
     i)))
 ; the write: sym[ofs[lens[i]]], for any lengths, over-subscribed or not
 (defq inf-symw (pi L (pi i nat nat) N nat i nat o nat g (inf-lt i N)
     e (paths bool (inf-eqb (L i) (succ o)) true)
       (inf-lt (inf-run L (lam v (inf-count L v N)) i (succ o)) N))
   (lam L N i o g e
     (inf-lttr (add (inf-sum (lam v (inf-count L v N)) o 1) (inf-count L (succ o) i))
       (inf-run L (lam v (inf-count L v N)) i (succ o)) N
       (pathsinv0 nat (inf-run L (lam v (inf-count L v N)) i (succ o))
         (add (inf-sum (lam v (inf-count L v N)) o 1) (inf-count L (succ o) i))
         (inf-runclosed L (lam v (inf-count L v N)) o i))
       (inf-symclosed L N i o g e)))))

; --- class 6: the bit buffer. inflate.h's FILL and TAKE. what is consumed plus what is buffered is
; --- what was read, which is the no-wrap, the shift range and the termination measure at once
(test
 (defn inf-by8 (pi x nat nat)
   (lam x (nat_rect (lam q nat) 0
     (lam k r (succ (succ (succ (succ (succ (succ (succ (succ r)))))))))
     x)))
 (defq inf-by8add (pi a nat b nat (paths nat (inf-by8 (add a b)) (add (inf-by8 a) (inf-by8 b))))
   (lam a b (nat_rect (lam q (paths nat (inf-by8 (add q b)) (add (inf-by8 q) (inf-by8 b))))
     (idpath (inf-by8 b))
     (lam k IH (maponpaths nat nat (lam w (add 8 w))
       (inf-by8 (add k b)) (add (inf-by8 k) (inf-by8 b)) IH))
     a)))
 (defq inf-by8refl (pi a nat b nat g (inf-le (inf-by8 a) (inf-by8 b)) (inf-le a b))
   (lam a (nat_rect (lam q (pi b nat g (inf-le (inf-by8 q) (inf-by8 b)) (inf-le q b)))
     (lam b g (idpath false))
     (lam k IH b (nat_rect
       (lam r (pi g (inf-le (inf-by8 (succ k)) (inf-by8 r)) (inf-le (succ k) r)))
       (lam g g)
       (lam j u g (IH j g))
       b))
     a)))
 (defq inf-by8mono (pi a nat b nat g (inf-le a b) (inf-le (inf-by8 a) (inf-by8 b)))
   (lam a (nat_rect (lam q (pi b nat g (inf-le q b) (inf-le (inf-by8 q) (inf-by8 b))))
     (lam b g (idpath false))
     (lam k IH b (nat_rect
       (lam r (pi g (inf-le (succ k) r) (inf-le (inf-by8 (succ k)) (inf-by8 r))))
       (lam g (fromempty (inf-le (inf-by8 (succ k)) 0) (nopathstruetofalse g)))
       (lam j u g (IH j g))
       b))
     a)))
 ; bc >> 3 and bc & 7
 (defn inf-div8 (pi x nat nat)
   (lam x (nat_rect (lam q nat) 0
     (lam k r (bool_rect (lam b nat) r (succ r) (natgtb 8 (succ (inf-mod 8 k)))))
     x)))
 (defq inf-divmod (pi x nat (paths nat (add (inf-by8 (inf-div8 x)) (inf-mod 8 x)) x))
   (lam x (nat_rect (lam q (paths nat (add (inf-by8 (inf-div8 q)) (inf-mod 8 q)) q))
     (idpath 0)
     (lam k IH (inf-case (natgtb 8 (succ (inf-mod 8 k)))
       (lam b (paths nat
         (add (inf-by8 (bool_rect (lam c nat) (inf-div8 k) (succ (inf-div8 k)) b))
              (bool_rect (lam c nat) (succ (inf-mod 8 k)) 0 b))
         (succ k)))
       (lam e (pathscomp0 nat (add (inf-by8 (inf-div8 k)) (succ (inf-mod 8 k)))
         (succ (add (inf-by8 (inf-div8 k)) (inf-mod 8 k))) (succ k)
         (natplusnsm (inf-by8 (inf-div8 k)) (inf-mod 8 k))
         (maponpaths nat nat (lam w (succ w)) (add (inf-by8 (inf-div8 k)) (inf-mod 8 k)) k IH)))
       ; a carry: the low three bits stood at 7, so 8 more is one more of the high part
       (lam e (pathscomp0 nat (add (inf-by8 (succ (inf-div8 k))) 0)
         (inf-by8 (succ (inf-div8 k))) (succ k)
         (natplusr0 (inf-by8 (succ (inf-div8 k))))
         (pathscomp0 nat (add 8 (inf-by8 (inf-div8 k)))
           (succ (add (inf-by8 (inf-div8 k)) 7)) (succ k)
           (pathscomp0 nat (add 8 (inf-by8 (inf-div8 k))) (add (inf-by8 (inf-div8 k)) 8)
             (succ (add (inf-by8 (inf-div8 k)) 7))
             (natpluscomm 8 (inf-by8 (inf-div8 k)))
             (natplusnsm (inf-by8 (inf-div8 k)) 7))
           (maponpaths nat nat (lam w (succ w)) (add (inf-by8 (inf-div8 k)) 7) k
             (pathscomp0 nat (add (inf-by8 (inf-div8 k)) 7)
               (add (inf-by8 (inf-div8 k)) (inf-mod 8 k)) k
               (maponpaths nat nat (lam w (add (inf-by8 (inf-div8 k)) w)) 7 (inf-mod 8 k)
                 (isantisymmnatleh 7 (inf-mod 8 k)
                   e (inf-ltsle (inf-mod 8 k) 7 (inf-modlt 7 k))))
               IH)))))))
     x)))
 (defq inf-div8le (pi x nat g (inf-le x 63) (inf-le (inf-div8 x) 7))
   (lam x g
     (coprod_rect (lam c (inf-le (inf-div8 x) 7))
       (lam e (fromempty (inf-le (inf-div8 x) 7) (nopathstruetofalse
         (istransnatleh 64 (inf-by8 (inf-div8 x)) 63
           (inf-by8mono 8 (inf-div8 x) (inf-ltsu 7 (inf-div8 x) e))
           (istransnatleh (inf-by8 (inf-div8 x)) x 63
             (inf-letl (inf-by8 (inf-div8 x)) (add (inf-by8 (inf-div8 x)) (inf-mod 8 x)) x
               (inf-divmod x) (inf-leaddr (inf-by8 (inf-div8 x)) (inf-mod 8 x)))
             g)))))
       (lam e e)
       (natgthorleh (inf-div8 x) 7))))
 (defq inf-swap3 (pi a nat b nat c nat (paths nat (add (add a b) c) (add (add a c) b)))
   (lam a b c (pathscomp0 nat (add (add a b) c) (add a (add b c)) (add (add a c) b)
     (natplusassoc a b c)
     (pathscomp0 nat (add a (add b c)) (add a (add c b)) (add (add a c) b)
       (maponpaths nat nat (lam w (add a w)) (add b c) (add c b) (natpluscomm b c))
       (pathsinv0 nat (add (add a c) b) (add a (add c b)) (natplusassoc a c b))))))
 ; the invariant is carry + (by8 ip) = cons + bc: what came before these bytes, read, consumed,
 ; buffered. a stream read at one go carries 0
 (defn inf-bits-inv (pi carry nat ip nat cons nat bc nat UU)
   (lam carry ip cons bc (paths nat (add carry (inf-by8 ip)) (add cons bc))))
 (defq inf-carry (pi b nat x nat y nat c nat i (paths nat (add b x) c) (paths nat (add b (add x y)) (add c y)))
   (lam b x y c i
     (pathscomp0 nat (add b (add x y)) (add (add b x) y) (add c y)
       (pathsinv0 nat (add (add b x) y) (add b (add x y)) (natplusassoc b x y))
       (maponpaths nat nat (lam z (add z y)) (add b x) c i))))
 ; TAKE
 (defq inf-take (pi carry nat ip nat cons nat bc nat k nat g (inf-le k bc) i (inf-bits-inv carry ip cons bc)
     (inf-bits-inv carry ip (add cons k) (natminus bc k)))
   (lam carry ip cons bc k g i
     (pathscomp0 nat (add carry (inf-by8 ip)) (add cons bc) (add (add cons k) (natminus bc k))
       i
       (pathscomp0 nat (add cons bc) (add cons (add k (natminus bc k))) (add (add cons k) (natminus bc k))
         (maponpaths nat nat (lam w (add cons w)) bc (add k (natminus bc k))
           (pathsinv0 nat (add k (natminus bc k)) bc (inf-addsub k bc g)))
         (pathsinv0 nat (add (add cons k) (natminus bc k)) (add cons (add k (natminus bc k)))
           (natplusassoc cons k (natminus bc k)))))))
 ; bc + 8 * (7 - (bc >> 3)) is 56 + (bc & 7), which is bc | 56
 (defq inf-fillw56 (pi bc nat g (inf-le bc 63)
     (paths nat (add bc (inf-by8 (natminus 7 (inf-div8 bc)))) (add 56 (inf-mod 8 bc))))
   (lam bc g
     (pathscomp0 nat (add bc (inf-by8 (natminus 7 (inf-div8 bc))))
       (add (add (inf-by8 (inf-div8 bc)) (inf-mod 8 bc)) (inf-by8 (natminus 7 (inf-div8 bc))))
       (add 56 (inf-mod 8 bc))
       (maponpaths nat nat (lam w (add w (inf-by8 (natminus 7 (inf-div8 bc))))) bc
         (add (inf-by8 (inf-div8 bc)) (inf-mod 8 bc))
         (pathsinv0 nat (add (inf-by8 (inf-div8 bc)) (inf-mod 8 bc)) bc (inf-divmod bc)))
       (pathscomp0 nat (add (add (inf-by8 (inf-div8 bc)) (inf-mod 8 bc)) (inf-by8 (natminus 7 (inf-div8 bc))))
         (add (add (inf-by8 (inf-div8 bc)) (inf-by8 (natminus 7 (inf-div8 bc)))) (inf-mod 8 bc))
         (add 56 (inf-mod 8 bc))
         (inf-swap3 (inf-by8 (inf-div8 bc)) (inf-mod 8 bc) (inf-by8 (natminus 7 (inf-div8 bc))))
         (maponpaths nat nat (lam w (add w (inf-mod 8 bc)))
           (add (inf-by8 (inf-div8 bc)) (inf-by8 (natminus 7 (inf-div8 bc)))) 56
           (pathscomp0 nat (add (inf-by8 (inf-div8 bc)) (inf-by8 (natminus 7 (inf-div8 bc))))
             (inf-by8 (add (inf-div8 bc) (natminus 7 (inf-div8 bc)))) 56
             (pathsinv0 nat (inf-by8 (add (inf-div8 bc) (natminus 7 (inf-div8 bc))))
               (add (inf-by8 (inf-div8 bc)) (inf-by8 (natminus 7 (inf-div8 bc))))
               (inf-by8add (inf-div8 bc) (natminus 7 (inf-div8 bc))))
             (maponpaths nat nat inf-by8 (add (inf-div8 bc) (natminus 7 (inf-div8 bc))) 7
               (inf-addsub (inf-div8 bc) 7 (inf-div8le bc g)))))))))
 ; FILL's wide path: ip += 7 - (bc >> 3), bc |= 56, and what spilled is read again
 (defq inf-fillw (pi carry nat ip nat cons nat bc nat g (inf-le bc 63) i (inf-bits-inv carry ip cons bc)
     (inf-bits-inv carry (add ip (natminus 7 (inf-div8 bc))) cons (add 56 (inf-mod 8 bc))))
   (lam carry ip cons bc g i
     (pathscomp0 nat (add carry (inf-by8 (add ip (natminus 7 (inf-div8 bc)))))
       (add carry (add (inf-by8 ip) (inf-by8 (natminus 7 (inf-div8 bc)))))
       (add cons (add 56 (inf-mod 8 bc)))
       (maponpaths nat nat (lam z (add carry z)) (inf-by8 (add ip (natminus 7 (inf-div8 bc))))
         (add (inf-by8 ip) (inf-by8 (natminus 7 (inf-div8 bc)))) (inf-by8add ip (natminus 7 (inf-div8 bc))))
       (pathscomp0 nat (add carry (add (inf-by8 ip) (inf-by8 (natminus 7 (inf-div8 bc)))))
         (add (add cons bc) (inf-by8 (natminus 7 (inf-div8 bc))))
         (add cons (add 56 (inf-mod 8 bc)))
         (inf-carry carry (inf-by8 ip) (inf-by8 (natminus 7 (inf-div8 bc))) (add cons bc) i)
         (pathscomp0 nat (add (add cons bc) (inf-by8 (natminus 7 (inf-div8 bc))))
           (add cons (add bc (inf-by8 (natminus 7 (inf-div8 bc)))))
           (add cons (add 56 (inf-mod 8 bc)))
           (natplusassoc cons bc (inf-by8 (natminus 7 (inf-div8 bc))))
           (maponpaths nat nat (lam w (add cons w)) (add bc (inf-by8 (natminus 7 (inf-div8 bc))))
             (add 56 (inf-mod 8 bc)) (inf-fillw56 bc g)))))))
 ; a wide fill leaves bc | 56, and a take only lowers bc: a shift by bc stays under the word
 (defq inf-or56 (pi bc nat (inf-le (add 56 (inf-mod 8 bc)) 63))
   (lam bc (inf-addl 56 (inf-mod 8 bc) 7 (inf-ltsle (inf-mod 8 bc) 7 (inf-modlt 7 bc)))))
 (defq inf-sub63 (pi bc nat k nat s (inf-le bc 63) (inf-le (natminus bc k) 63))
   (lam bc k s (istransnatleh (natminus bc k) bc 63 (inf-suble bc k) s)))
 ; a stored block's pos = ip - (bc >> 3), bc whole bytes by then: it does not wrap
 (defq inf-pos (pi ip nat cons nat q nat i (inf-bits-inv 0 ip cons (inf-by8 q)) (inf-le q ip))
   (lam ip cons q i
     (inf-by8refl q ip
       (inf-letl (inf-by8 q) (add cons (inf-by8 q)) (inf-by8 ip)
         (pathsinv0 nat (inf-by8 ip) (add cons (inf-by8 q)) i)
         (inf-leaddl (inf-by8 q) cons)))))

 ; termination, any machine: a step that lowers a measure runs out before its fuel does
 (defn inf-dec (pi S UU R UU m (pi s S nat) s S r (coprod S R) UU)
   (lam S R m s r
     (coprod_rect (lam x UU) (lam t (inf-lt (m t) (m s))) (lam u unit) r)))
 (defn inf-go (pi S UU R UU step (pi s S (coprod S R)) f nat s S (coprod R unit))
   (lam S R step f (nat_rect (lam q (pi s S (coprod R unit)))
     (lam s (ii2 tt))
     (lam k IH s
       (coprod_rect (lam c (coprod R unit)) (lam t (IH t)) (lam r (ii1 r)) (step s)))
     f)))
 (defn inf-done2 (pi R UU r (coprod R unit) UU)
   (lam R r (coprod_rect (lam x UU) (lam a unit) (lam u empty) r)))
 (defq inf-halts (pi S UU R UU step (pi s S (coprod S R)) m (pi s S nat)
     h (pi s S (inf-dec S R m s (step s)))
       f nat s S g (inf-lt (m s) f) (inf-done2 R (inf-go S R step f s)))
   (lam S R step m h f (nat_rect
     (lam q (pi s S g (inf-lt (m s) q) (inf-done2 R (inf-go S R step q s))))
     (lam s g (fromempty (inf-done2 R (ii2 tt)) (nopathsfalsetotrue g)))
     (lam k IH s g
       ((coprod_rect
          (lam c (pi d (inf-dec S R m s c)
            (inf-done2 R (coprod_rect (lam x (coprod R unit)) (lam t (inf-go S R step k t)) (lam r (ii1 r)) c))))
          (lam t d (IH t (inf-lttrans (m t) (m s) k d (inf-ltsle (m s) k g))))
          (lam r d tt)
          (step s))
        (h s)))
     f)))
 ; the symbol loop's measure: bits unread plus bits buffered. a code of u >= 1 bits lowers it, FILL leaves it
 (defq inf-symdec (pi r nat bc nat u nat p (inf-lt 0 u) g (inf-le u bc)
     (inf-lt (add r (natminus bc u)) (add r bc)))
   (lam r bc u p g
     (inf-ltaddl r (natminus bc u) bc (inf-subdec bc u p g))))
 (defq inf-fillsame (pi r nat bc nat (paths nat (add (inf-by8 r) (add 8 bc)) (add (inf-by8 (succ r)) bc)))
   (lam r bc (pathscomp0 nat (add (inf-by8 r) (add 8 bc)) (add 8 (add (inf-by8 r) bc)) (add (inf-by8 (succ r)) bc)
     (inf-lswap (inf-by8 r) 8 bc)
     (idpath (add 8 (add (inf-by8 r) bc))))))
 )

; --- class 7: widths. nat has none, so each law says a value stays under a power, named and never
; --- evaluated: 2^31 as a literal would be unary in rocq and an endless fold here
(test
 (defn inf-pow (pi k nat nat) (lam k (nat_rect (lam q nat) 1 (lam j p (add p p)) k)))
 (defq inf-powpos (pi k nat (inf-lt 0 (inf-pow k)))
   (lam k (nat_rect (lam q (inf-lt 0 (inf-pow q)))
     (idpath true)
     (lam j IH (inf-lttrans 0 (inf-pow j) (add (inf-pow j) (inf-pow j)) IH (inf-leaddr (inf-pow j) (inf-pow j))))
     k)))
 (defq inf-powle (pi a nat b nat g (inf-le a b) (inf-le (inf-pow a) (inf-pow b)))
   (lam a (nat_rect (lam q (pi b nat g (inf-le q b) (inf-le (inf-pow q) (inf-pow b))))
     (lam b g (inf-ltsu 0 (inf-pow b) (inf-powpos b)))
     (lam k IH b (nat_rect (lam r (pi g (inf-le (succ k) r) (inf-le (inf-pow (succ k)) (inf-pow r))))
       (lam g (fromempty (inf-le (inf-pow (succ k)) (inf-pow 0)) (nopathstruetofalse g)))
       (lam j u g (inf-dbl (inf-pow k) (inf-pow j) (IH j g)))
       b))
     a)))
 (defq inf-lelt (pi a nat b nat c nat g (inf-le a b) h (inf-lt b c) (inf-lt a c))
   (lam a b c g h
     (inf-lttrans a (succ b) c (inf-lelts a b g) (inf-ltsu b c h))))
 (defq inf-lt2 (pi a nat (inf-lt a (add a 2)))
   (lam a (nat_rect (lam q (inf-lt q (add q 2))) (idpath true) (lam k IH IH) a)))
 ; code's two steps: the or, then the shift. code + 2 <= 2^l, the room the or and the shift take up
 (defq inf-wor (pi a nat b nat p nat h (inf-le b 1) g (inf-le (add a 2) p) (inf-lt (add a b) p))
   (lam a b p h g
     (inf-lelt (add a b) (add a 1) p (inf-addl a b 1 h)
       (inf-lttrans (add a 1) (add a 2) p (inf-ltaddl a 1 2 (idpath true)) g))))
 (defq inf-two (pi y nat (paths nat (add (add y 1) (add y 1)) (add (add y y) 2)))
   (lam y (pathscomp0 nat (add (add y 1) (add y 1)) (add y (succ (add y 1))) (add (add y y) 2)
     (natplusassoc y 1 (add y 1))
     (pathscomp0 nat (add y (succ (add y 1))) (add y (add y 2)) (add (add y y) 2)
       (maponpaths nat nat (lam w (add y w)) (succ (add y 1)) (add y 2)
         (pathsinv0 nat (add y 2) (succ (add y 1)) (natplusnsm y 1)))
       (pathsinv0 nat (add (add y y) 2) (add y (add y 2)) (natplusassoc y y 2))))))
 (defq inf-wsh (pi a nat b nat p nat h (inf-le b 1) g (inf-le (add a 2) p)
     (inf-le (add (add (add a b) (add a b)) 2) (add p p)))
   (lam a b p h g
     (inf-letr (add (add (add a b) 1) (add (add a b) 1)) (add (add (add a b) (add a b)) 2) (add p p)
       (inf-two (add a b))
       (inf-dbl (add (add a b) 1) p
         (istransnatleh (add (add a b) 1) (add a 2) p
           (inf-letr (add a (add b 1)) (add (add a b) 1) (add a 2)
             (pathsinv0 nat (add (add a b) 1) (add a (add b 1)) (natplusassoc a b 1))
             (inf-addl a (add b 1) 2 (inf-addr b 1 1 h)))
           g)))))
 ; the last code the walk reaches, and the walk's own recursion: code < 2^(f + l), counts or no
 (defn inf-wtop (pi cnt (pi l nat nat) bit (pi l nat nat) f nat l nat code nat first nat nat)
   (lam cnt bit f (nat_rect (lam q (pi l nat code nat first nat nat))
     (lam l code first code)
     (lam k IH l code first
       (bool_rect (lam b nat)
         (add code (bit l))
         (IH (succ l) (add (add code (bit l)) (add code (bit l))) (add (add first (cnt l)) (add first (cnt l))))
         (natgtb (add first (cnt l)) (add code (bit l)))))
     f)))
 (defq inf-wtopfit (pi cnt (pi l nat nat) bit (pi l nat nat) b1 (pi l nat (inf-le (bit l) 1))
     f nat l nat code nat first nat g (inf-le (add code 2) (inf-pow l))
       (inf-lt (inf-wtop cnt bit f l code first) (inf-pow (add f l))))
   (lam cnt bit b1 f (nat_rect
     (lam q (pi l nat code nat first nat g (inf-le (add code 2) (inf-pow l))
       (inf-lt (inf-wtop cnt bit q l code first) (inf-pow (add q l)))))
     (lam l code first g (inf-lttrans code (add code 2) (inf-pow l) (inf-lt2 code) g))
     (lam k IH l code first g
       (inf-case (natgtb (add first (cnt l)) (add code (bit l)))
         (lam b (inf-lt (bool_rect (lam z nat)
             (add code (bit l))
             (inf-wtop cnt bit k (succ l) (add (add code (bit l)) (add code (bit l)))
               (add (add first (cnt l)) (add first (cnt l))))
             b)
           (inf-pow (succ (add k l)))))
         (lam e (inf-lttrans (add code (bit l)) (inf-pow l) (inf-pow (succ (add k l)))
           (inf-wor code (bit l) (inf-pow l) (b1 l) g)
           (inf-powle l (succ (add k l)) (natlehsucc l (add k l) (inf-leaddl l k)))))
         (lam e (transportf nat
           (lam x (inf-lt (inf-wtop cnt bit k (succ l) (add (add code (bit l)) (add code (bit l)))
               (add (add first (cnt l)) (add first (cnt l)))) (inf-pow x)))
           (add k (succ l)) (succ (add k l)) (natplusnsm k l)
           (IH (succ l) (add (add code (bit l)) (add code (bit l)))
             (add (add first (cnt l)) (add first (cnt l)))
             (inf-wsh code (bit l) (inf-pow l) (b1 l) g))))))
     f)))
 ; inf_walk's fifteen lengths: code fits any int of 16 bits or more, and first <= code stays under it
 (defq inf-walkfit (pi cnt (pi l nat nat) bit (pi l nat nat) b1 (pi l nat (inf-le (bit l) 1))
     f nat w nat gf (inf-le f 15) gw (inf-le 16 w)
       (inf-lt (inf-wtop cnt bit f 1 0 0) (inf-pow w)))
   (lam cnt bit b1 f w gf gw
     (inf-lttrans (inf-wtop cnt bit f 1 0 0) (inf-pow (add f 1)) (inf-pow w)
       (inf-wtopfit cnt bit b1 f 1 0 0 (idpath false))
       (inf-powle (add f 1) w (istransnatleh (add f 1) 16 w (inf-addr f 15 1 gf) gw)))))
 ; inf_build's cnt[lens[i]]++: each count is at most the symbols, so uint16_t holds it
 (defq inf-dle (pi x nat v nat (inf-le (inf-d x v) 1))
   (lam x v (inf-case (inf-eqb x v) (lam b (inf-le (bool_rect (lam z nat) 1 0 b) 1))
     (lam e (idpath false)) (lam e (idpath false)))))
 (defq inf-cntle (pi L (pi i nat nat) v nat n nat (inf-le (inf-count L v n) n))
   (lam L v n (nat_rect (lam q (inf-le (inf-count L v q) q))
     (idpath false)
     (lam k IH (inf-add2 (inf-d (L k) v) 1 (inf-count L v k) k (inf-dle (L k) v) IH))
     n)))
 ; a tab entry, (s << 4) | l, in uint16_t: s under 4096 and l under 16
 (defn inf-by16 (pi x nat nat) (lam x (nat_rect (lam q nat) 0 (lam k r (add 16 r)) x)))
 (defq inf-by16mono (pi a nat b nat g (inf-le a b) (inf-le (inf-by16 a) (inf-by16 b)))
   (lam a (nat_rect (lam q (pi b nat g (inf-le q b) (inf-le (inf-by16 q) (inf-by16 b))))
     (lam b g (idpath false))
     (lam k IH b (nat_rect (lam r (pi g (inf-le (succ k) r) (inf-le (inf-by16 (succ k)) (inf-by16 r))))
       (lam g (fromempty (inf-le (inf-by16 (succ k)) (inf-by16 0)) (nopathstruetofalse g)))
       (lam j u g (IH j g))
       b))
     a)))
 (defq inf-entry (pi s nat l nat p nat g (inf-lt s p) h (inf-lt l 16)
     (inf-lt (add (inf-by16 s) l) (inf-by16 p)))
   (lam s l p g h
     (inf-lttrans (add (inf-by16 s) l) (inf-by16 (succ s)) (inf-by16 p)
       (transportf nat (lam x (inf-lt (add (inf-by16 s) l) x))
         (add (inf-by16 s) 16) (add 16 (inf-by16 s)) (natpluscomm (inf-by16 s) 16)
         (inf-ltaddl (inf-by16 s) l 16 h))
       (inf-by16mono (succ s) p (inf-ltsu s p g)))))
 ; p at 4096 is 2^16, so uint16_t holds it
 (65536 = vof 0 '(inf-by16 4096))
 ; j += 1u << l, for j under the table and l at most its root: the sum stays under twice the table
 (defq inf-tabstep (pi j nat l nat r nat g (inf-lt j (inf-pow r)) h (inf-le l r)
     (inf-lt (add j (inf-pow l)) (inf-pow (succ r))))
   (lam j l r g h
     (inf-lttrans (add j (inf-pow l)) (add (inf-pow r) (inf-pow l)) (add (inf-pow r) (inf-pow r))
       (inf-ltaddr j (inf-pow r) (inf-pow l) g)
       (inf-addl (inf-pow r) (inf-pow l) (inf-pow r) (inf-powle l r h)))))
 ; the reversal's shift, l - 1 - b, is a shift under 15 for l at most 15
 (defq inf-revsh (pi l nat b nat g (inf-le l 15) (inf-le (natminus (natminus l 1) b) 14))
   (lam l b g
     (istransnatleh (natminus (natminus l 1) b) (natminus l 1) 14
       (inf-suble (natminus l 1) b)
       (inf-submono l 15 1 g))))
 ; sym[idx++], the fill's read: idx and the counts to come stay within nsym
 (defq inf-bidx (pi cnt (pi l nat nat) n nat k nat l nat idx nat i nat
     g (inf-le (add idx (inf-sum cnt (succ k) l)) n) h (inf-lt i (cnt l)) (inf-lt (add idx i) n))
   (lam cnt n k l idx i g h
     (inf-lttrans (add idx i) (add idx (cnt l)) n
       (inf-ltaddl idx i (cnt l) h)
       (istransnatleh (add idx (cnt l)) (add idx (inf-sum cnt (succ k) l)) n
         (inf-addl idx (cnt l) (inf-sum cnt (succ k) l) (inf-leaddr (cnt l) (inf-sum cnt k (succ l))))
         g))))
 (defq inf-bstep (pi cnt (pi l nat nat) n nat k nat l nat idx nat
     g (inf-le (add idx (inf-sum cnt (succ k) l)) n)
       (inf-le (add (add idx (cnt l)) (inf-sum cnt k (succ l))) n))
   (lam cnt n k l idx g
     (inf-letr (add idx (add (cnt l) (inf-sum cnt k (succ l))))
       (add (add idx (cnt l)) (inf-sum cnt k (succ l))) n
       (pathsinv0 nat (add (add idx (cnt l)) (inf-sum cnt k (succ l)))
         (add idx (add (cnt l) (inf-sum cnt k (succ l))))
         (natplusassoc idx (cnt l) (inf-sum cnt k (succ l))))
       g)))
 ; a code length is at most 15, so cnt[lens[i]] and ofs[lens[i]] are in. inflate.h 161-167: v is sy
 ; under 16, or prev, or 0
 (defn inf-clv (pi sy nat prev nat nat)
   (lam sy prev (bool_rect (lam b nat)
     sy
     (bool_rect (lam b nat) prev 0 (inf-eqb sy 16))
     (natgtb 16 sy))))
 (defq inf-clvle (pi sy nat prev nat g (inf-le prev 15) (inf-le (inf-clv sy prev) 15))
   (lam sy prev g
     (inf-case (natgtb 16 sy)
       (lam b (inf-le (bool_rect (lam z nat) sy (bool_rect (lam z nat) prev 0 (inf-eqb sy 16)) b) 15))
       (lam e (inf-ltsle sy 15 e))
       (lam e (inf-case (inf-eqb sy 16)
         (lam c (inf-le (bool_rect (lam z nat) prev 0 c) 15))
         (lam d g)
         (lam d (idpath false)))))))
 (defq inf-updle (pi f (pi j nat nat) k nat v nat B nat g (pi j nat (inf-le (f j) B)) h (inf-le v B)
     j nat (inf-le (inf-upd f k v j) B))
   (lam f k v B g h j
     (inf-case (inf-eqb k j)
       (lam b (inf-le (bool_rect (lam z nat) v (f j) b) B))
       (lam e h)
       (lam e (g j)))))
 ; the fast lane's word copy: from 266 bytes of room a word starting before op + l ends within cap
 (defq inf-fastw (pi op nat l nat dp nat cap nat g (inf-lt dp (add op l)) h (inf-le l 258)
     r (inf-le (add op 266) cap) (inf-le (add dp 8) cap))
   (lam op l dp cap g h r
     (istransnatleh (add dp 8) (add op 266) cap
       (inf-ltle (add dp 8) (add op 266)
         (inf-lttrans (add dp 8) (add (add op l) 8) (add op 266)
           (inf-ltaddr dp (add op l) 8 g)
           (inf-letr (add op (add l 8)) (add (add op l) 8) (add op 266)
             (pathsinv0 nat (add (add op l) 8) (add op (add l 8)) (natplusassoc op l 8))
             (inf-addl op (add l 8) 266 (inf-addr l 258 8 h)))))
       r)))
 ; and its budget for a pair, topped up to 48: 15 + 5 + 15 + 13 bits leave bc no wrap
 (defq inf-fastbits (pi a nat b nat c nat d nat bc nat
     ga (inf-le a 15) gb (inf-le b 5) gc (inf-le c 15) gd (inf-le d 13) g (inf-le 48 bc)
       (inf-le (add a (add b (add c d))) bc))
   (lam a b c d bc ga gb gc gd g
     (istransnatleh (add a (add b (add c d))) 48 bc
       (inf-add2 a 15 (add b (add c d)) 33 ga
         (inf-add2 b 5 (add c d) 28 gb (inf-add2 c 15 d 13 gc gd)))
       g)))
 )

; --- what the generated inf_walk owes, test/uuinfvc.l asks for these ---
(test
 (defq inf-powfit (pi x nat l nat w nat g (inf-lt x (inf-pow l)) h (inf-le l w)
     (inf-lt x (inf-pow w)))
   (lam x l w g h
     (inf-lttrans x (inf-pow l) (inf-pow w) g (inf-powle l w h))))
 (defq inf-lew (pi l nat w nat g (inf-lt l 16) h (inf-le 31 w) (inf-le l w))
   (lam l w g h
     (istransnatleh l 16 w (inf-ltle l 16 g) (istransnatleh 16 31 w (idpath false) h))))
 (defq inf-subsucc (pi n nat l nat g (inf-lt l n)
     (paths nat (natminus n l) (succ (natminus n (succ l)))))
   (lam n (nat_rect (lam q (pi l nat g (inf-lt l q) (paths nat (natminus q l) (succ (natminus q (succ l))))))
     (lam l g (fromempty (paths nat (natminus 0 l) (succ (natminus 0 (succ l)))) (nopathsfalsetotrue g)))
     (lam m IH l (nat_rect
       (lam r (pi g (inf-lt r (succ m)) (paths nat (natminus (succ m) r) (succ (natminus (succ m) (succ r))))))
       (lam g (maponpaths nat nat (lam x (succ x)) m (natminus m 0) (pathsinv0 nat (natminus m 0) m (natminusn0 m))))
       (lam j u g (IH j g))
       l))
     n)))
 (defq inf-subfall (pi n nat l nat g (inf-lt l n) (inf-lt (natminus n (succ l)) (natminus n l)))
   (lam n l g
     (transportf nat (lam y (inf-lt (natminus n (succ l)) y))
       (succ (natminus n (succ l))) (natminus n l)
       (pathsinv0 nat (natminus n l) (succ (natminus n (succ l))) (inf-subsucc n l g))
       (inf-lelts (natminus n (succ l)) (natminus n (succ l)) (isreflnatleh (natminus n (succ l)))))))
 ; the counts to come, one length on: the walk's index and the fill's idx both step so
 (defq inf-sumnext (pi cnt (pi l nat nat) n nat l nat idx nat m nat g (inf-lt l n)
     h (inf-le (add idx (inf-sum cnt (natminus n l) l)) m)
       (inf-le (add (add idx (cnt l)) (inf-sum cnt (natminus n (succ l)) (succ l))) m))
   (lam cnt n l idx m g h
     (inf-bstep cnt m (natminus n (succ l)) l idx
       (transportf nat (lam y (inf-le (add idx (inf-sum cnt y l)) m))
         (natminus n l) (succ (natminus n (succ l))) (inf-subsucc n l g) h))))
 (defq inf-sumhead (pi cnt (pi l nat nat) n nat l nat idx nat m nat g (inf-lt l n)
     h (inf-le (add idx (inf-sum cnt (natminus n l) l)) m)
       (inf-le (add idx (cnt l)) m))
   (lam cnt n l idx m g h
     (istransnatleh (add idx (cnt l))
       (add (add idx (cnt l)) (inf-sum cnt (natminus n (succ l)) (succ l))) m
       (inf-leaddr (add idx (cnt l)) (inf-sum cnt (natminus n (succ l)) (succ l)))
       (inf-sumnext cnt n l idx m g h))))
 ; a multiple of p + 1 and j more leaves j, and p + 1 more is a multiple again
 (defq inf-modbump (pi p nat x nat e (paths nat (inf-mod (succ p) x) 0) j nat g (inf-le j p)
     (paths nat (inf-mod (succ p) (add j x)) j))
   (lam p x e j (nat_rect
     (lam q (pi g (inf-le q p) (paths nat (inf-mod (succ p) (add q x)) q)))
     (lam g e)
     (lam k IH g
       (transportf nat
         (lam r (paths nat (bool_rect (lam b nat) (succ r) 0 (natgtb (succ p) (succ r))) (succ k)))
         k (inf-mod (succ p) (add k x))
         (pathsinv0 nat (inf-mod (succ p) (add k x)) k
           (IH (istransnatleh k (succ k) p (natlehsucc k k (isreflnatleh k)) g)))
         (transportf bool (lam b (paths nat (bool_rect (lam c nat) (succ k) 0 b) (succ k)))
           true (natgtb (succ p) (succ k))
           (pathsinv0 bool (natgtb (succ p) (succ k)) true (inf-lelts (succ k) p g))
           (idpath (succ k)))))
     j)))
 (defq inf-modtop (pi p nat x nat e (paths nat (inf-mod (succ p) x) 0)
     (paths nat (inf-mod (succ p) (add (succ p) x)) 0))
   (lam p x e
     (transportf nat
       (lam r (paths nat (bool_rect (lam b nat) (succ r) 0 (natgtb (succ p) (succ r))) 0))
       p (inf-mod (succ p) (add p x))
       (pathsinv0 nat (inf-mod (succ p) (add p x)) p (inf-modbump p x e p (isreflnatleh p)))
       (transportf bool (lam b (paths nat (bool_rect (lam c nat) (succ p) 0 b) 0))
         false (natgtb (succ p) (succ p))
         (pathsinv0 bool (natgtb (succ p) (succ p)) false (isreflnatleh p))
         (idpath 0)))))
 (defq inf-moddbl (pi x nat (paths nat (inf-mod 2 (add x x)) 0))
   (lam x (nat_rect (lam q (paths nat (inf-mod 2 (add q q)) 0))
     (idpath 0)
     (lam k IH
       (transportf nat (lam y (paths nat (inf-mod 2 (succ y)) 0))
         (succ (add k k)) (add k (succ k))
         (pathsinv0 nat (add k (succ k)) (succ (add k k)) (natplusnsm k k))
         (inf-modtop 1 (add k k) IH)))
     x)))
 ; of any modulus, or the kernel unfolds inf-mod sixteen levels over a stuck term, 2^16 nodes
 (defn inf-times (pi p nat s nat nat)
   (lam p s (nat_rect (lam q nat) 0 (lam k r (add (succ p) r)) s)))
 (defq inf-timeslow (pi p nat s nat (paths nat (inf-mod (succ p) (inf-times p s)) 0))
   (lam p s (nat_rect (lam q (paths nat (inf-mod (succ p) (inf-times p q)) 0))
     (idpath 0)
     (lam k IH (inf-modtop p (inf-times p k) IH))
     s)))
 (defq inf-by16low (pi s nat (paths nat (inf-mod 16 (inf-by16 s)) 0))
   (lam s (inf-timeslow 15 s)))
 (defq inf-by16add (pi a nat b nat (paths nat (inf-by16 (add a b)) (add (inf-by16 a) (inf-by16 b))))
   (lam a b (nat_rect (lam q (paths nat (inf-by16 (add q b)) (add (inf-by16 q) (inf-by16 b))))
     (idpath (inf-by16 b))
     (lam k IH
       (pathscomp0 nat (add 16 (inf-by16 (add k b))) (add 16 (add (inf-by16 k) (inf-by16 b)))
         (add (add 16 (inf-by16 k)) (inf-by16 b))
         (maponpaths nat nat (lam x (add 16 x)) (inf-by16 (add k b)) (add (inf-by16 k) (inf-by16 b)) IH)
         (pathsinv0 nat (add (add 16 (inf-by16 k)) (inf-by16 b)) (add 16 (add (inf-by16 k) (inf-by16 b)))
           (natplusassoc 16 (inf-by16 k) (inf-by16 b)))))
     a)))
 (defq inf-by16pow (pi k nat (paths nat (inf-by16 (inf-pow k)) (inf-pow (add 4 k))))
   (lam k (nat_rect (lam q (paths nat (inf-by16 (inf-pow q)) (inf-pow (add 4 q))))
     (idpath 16)
     (lam j IH
       (pathscomp0 nat (inf-by16 (add (inf-pow j) (inf-pow j)))
         (add (inf-by16 (inf-pow j)) (inf-by16 (inf-pow j)))
         (add (inf-pow (add 4 j)) (inf-pow (add 4 j)))
         (inf-by16add (inf-pow j) (inf-pow j))
         (transportf nat
           (lam y (paths nat (add (inf-by16 (inf-pow j)) (inf-by16 (inf-pow j))) (add y y)))
           (inf-by16 (inf-pow j)) (inf-pow (add 4 j)) IH
           (idpath (add (inf-by16 (inf-pow j)) (inf-by16 (inf-pow j)))))))
     k)))
 ; (s << 4) | l for s of h bits, h at most 16: it fits any int of 31 bits or more
 (defq inf-by16or (pi x nat b nat h nat w nat g (inf-lt x (inf-pow h)) i (inf-lt b 16)
     j (inf-le h 16) k (inf-le 31 w) (inf-lt (add (inf-by16 x) b) (inf-pow w)))
   (lam x b h w g i j k
     (inf-lttrans (add (inf-by16 x) b) (inf-pow (add 4 h)) (inf-pow w)
       (transportf nat (lam y (inf-lt (add (inf-by16 x) b) y))
         (inf-by16 (inf-pow h)) (inf-pow (add 4 h)) (inf-by16pow h)
         (inf-entry x b (inf-pow h) g i))
       (inf-powle (add 4 h) w
         (istransnatleh (add 4 h) 20 w (inf-addl 4 h 16 j) (istransnatleh 20 31 w (idpath false) k))))))
 )

; --- what the generated inf_build owes, test/uuinfvc.l asks for these ---
(test
 ; x << k, and bit b of x, of which only that it is under 2 is asked
 (defn inf-zero (pi k nat nat) (lam k 0))
 (defn inf-dk (pi x nat k nat nat) (lam x k (nat_rect (lam q nat) x (lam j r (add r r)) k)))
 (defn inf-half (pi x nat nat) (lam x (nat_rect (lam q nat) 0 (lam k r (add r (inf-mod 2 k))) x)))
 (defn inf-shr (pi x nat b nat nat) (lam x b (nat_rect (lam q nat) x (lam k r (inf-half r)) b)))
 (defn inf-sb (pi x nat b nat nat) (lam x b (inf-mod 2 (inf-shr x b))))
 (defq inf-add1 (pi x nat (paths nat (add x 1) (succ x)))
   (lam x (nat_rect (lam q (paths nat (add q 1) (succ q))) (idpath 1)
     (lam k IH (maponpaths nat nat (lam z (succ z)) (add k 1) (succ k) IH)) x)))
 (defq inf-refl (pi x nat (inf-le x x))
   (lam x (nat_rect (lam q (inf-le q q)) (idpath false) (lam k IH IH) x)))
 (defq inf-letrans (pi a nat b nat c nat g (inf-le a b) h (inf-le b c) (inf-le a c))
   (lam a b c g h (istransnatleh a b c g h)))
 (defq inf-ltself (pi x nat (inf-lt x (succ x))) (lam x (inf-lelts x x (inf-refl x))))
 (defq inf-lt1 (pi x nat n nat g (inf-lt x n) (inf-le (add x 1) n))
   (lam x n g (inf-letr (succ x) (add x 1) n (pathsinv0 nat (add x 1) (succ x) (inf-add1 x)) (inf-ltsu x n g))))
 (defq inf-lesl (pi a nat b nat g (inf-le (succ a) b) (inf-lt a b))
   (lam a b g (inf-lttrans a (succ a) b (inf-ltself a) g)))
 (defq inf-addcong (pi a nat b nat c nat d nat e (paths nat a b) f (paths nat c d) (paths nat (add a c) (add b d)))
   (lam a b c d e f
     (pathscomp0 nat (add a c) (add b c) (add b d)
       (maponpaths nat nat (lam z (add z c)) a b e)
       (maponpaths nat nat (lam z (add b z)) c d f))))
 (defq inf-ant (pi a nat b nat g (inf-le a b) h (inf-le b a) (paths nat a b))
   (lam a (nat_rect (lam q (pi b nat g (inf-le q b) h (inf-le b q) (paths nat q b)))
     (lam b (nat_rect (lam z (pi g (inf-le 0 z) h (inf-le z 0) (paths nat 0 z)))
       (lam g h (idpath 0))
       (lam m u g h (fromempty (paths nat 0 (succ m)) (nopathstruetofalse h)))
       b))
     (lam k IH b (nat_rect (lam z (pi g (inf-le (succ k) z) h (inf-le z (succ k)) (paths nat (succ k) z)))
       (lam g h (fromempty (paths nat (succ k) 0) (nopathstruetofalse g)))
       (lam m u g h (maponpaths nat nat (lam z (succ z)) k m (IH m g h)))
       b))
     a)))
 (defq inf-le1 (pi k nat g (inf-le 1 k) (inf-lt 0 k))
   (lam k (nat_rect (lam q (pi g (inf-le 1 q) (inf-lt 0 q)))
     (lam g (fromempty (inf-lt 0 0) (nopathstruetofalse g)))
     (lam m u g (idpath true))
     k)))
 ; double what is under p and it stays under double p
 (defq inf-ltdbl (pi p nat g (inf-lt 0 p) (inf-lt p (add p p)))
   (lam p (nat_rect (lam q (pi g (inf-lt 0 q) (inf-lt q (add q q))))
     (lam g g)
     (lam k u g (inf-lttr (add (succ k) 0) (succ k) (add (succ k) (succ k)) (natplusr0 (succ k))
       (inf-ltaddl (succ k) 0 (succ k) (idpath true))))
     p)))
 (defq inf-ltpow (pi x nat (inf-lt x (inf-pow x)))
   (lam x (nat_rect (lam q (inf-lt q (inf-pow q)))
     (idpath true)
     (lam k IH (inf-lelt (succ k) (inf-pow k) (add (inf-pow k) (inf-pow k)) (inf-ltsu k (inf-pow k) IH)
       (inf-ltdbl (inf-pow k) (inf-powpos k))))
     x)))
 (defq inf-powlt (pi a nat b nat g (inf-lt a b) (inf-lt (inf-pow a) (inf-pow b)))
   (lam a b g (inf-lttrans (inf-pow a) (add (inf-pow a) (inf-pow a)) (inf-pow b)
     (inf-ltdbl (inf-pow a) (inf-powpos a)) (inf-powle (succ a) b (inf-ltsu a b g)))))
 (defq inf-small (pi x nat w nat h (inf-le x w) (inf-lt x (inf-pow w)))
   (lam x w h (inf-powfit x x w (inf-ltpow x) h)))
 (defq inf-two2 (pi a nat p nat g (inf-lt a p) (inf-le (add (add a a) 2) (add p p)))
   (lam a p g (inf-letr (add (add a 1) (add a 1)) (add (add a a) 2) (add p p) (inf-two a)
     (inf-dbl (add a 1) p (inf-lt1 a p g)))))
 (defq inf-dblfit (pi a nat p nat g (inf-lt a p) (inf-lt (add a a) (add p p)))
   (lam a p g (inf-lttrans (add a a) (add (add a a) 2) (add p p) (inf-lt2 (add a a)) (inf-two2 a p g))))
 (defq inf-revstep (pi a nat p nat b nat g (inf-lt a p) h (inf-lt b 2) (inf-lt (add (add a a) b) (add p p)))
   (lam a p b g h (inf-wor (add a a) b (add p p) (inf-ltsle b 1 h) (inf-two2 a p g))))
 ; the first of a run of lengths
 (defq inf-o1 (pi f (pi l nat nat) o nat g (inf-lt o 1) (paths nat 0 (inf-sum f o 1)))
   (lam f o (nat_rect (lam q (pi g (inf-lt q 1) (paths nat 0 (inf-sum f q 1))))
     (lam g (idpath 0))
     (lam k u g (fromempty (paths nat 0 (inf-sum f (succ k) 1)) (nopathsfalsetotrue g)))
     o)))
 ; cnt[lens[i]]++ is the count one symbol on
 (defq inf-cntstep (pi L (pi i nat nat) Cn (pi k nat nat) i nat a2 (pi k nat (paths nat (Cn k) (inf-count L k i))) k nat
     (paths nat (inf-upd Cn (L i) (add (Cn (L i)) 1) k) (inf-count L k (succ i))))
   (lam L Cn i a2 k (inf-case (inf-eqb (L i) k)
     (lam b (paths nat (bool_rect (lam z nat) (add (Cn (L i)) 1) (Cn k) b)
                       (add (bool_rect (lam z nat) 1 0 b) (inf-count L k i))))
     (lam e (pathscomp0 nat (add (Cn (L i)) 1) (succ (Cn (L i))) (succ (inf-count L k i)) (inf-add1 (Cn (L i)))
       (maponpaths nat nat (lam z (succ z)) (Cn (L i)) (inf-count L k i)
         (pathscomp0 nat (Cn (L i)) (inf-count L (L i) i) (inf-count L k i) (a2 (L i))
           (maponpaths nat nat (lam z (inf-count L z i)) (L i) k (inf-eqp (L i) k e))))))
     (lam e (a2 k)))))
 ; counts past length 0, once the loop has seen every symbol
 (defq inf-hk (pi Cn (pi k nat nat) L (pi i nat nat) i nat n nat a1 (inf-le i n) ni (inf-le n i)
     a2 (pi k nat (paths nat (Cn k) (inf-count L k i))) k nat g (inf-le 1 k)
     (paths nat (inf-upd Cn 0 0 k) (inf-count L k n)))
   (lam Cn L i n a1 ni a2 k g
     (pathscomp0 nat (inf-upd Cn 0 0 k) (Cn k) (inf-count L k n)
       (maponpaths bool nat (lam b (bool_rect (lam z nat) 0 (Cn k) b)) (inf-eqb 0 k) false (inf-gtne 0 k (inf-le1 k g)))
       (pathscomp0 nat (Cn k) (inf-count L k i) (inf-count L k n) (a2 k)
         (maponpaths nat nat (lam z (inf-count L k z)) i n (inf-ant i n a1 ni))))))
 (defq inf-sumcong (pi f (pi k nat nat) g (pi k nat nat) h (pi k nat p (inf-le 1 k) (paths nat (f k) (g k))) o nat l nat p (inf-le 1 l)
     (paths nat (inf-sum f o l) (inf-sum g o l)))
   (lam f g h o (nat_rect (lam q (pi l nat p (inf-le 1 l) (paths nat (inf-sum f q l) (inf-sum g q l))))
     (lam l p (idpath 0))
     (lam k IH l p (inf-addcong (f l) (g l) (inf-sum f k (succ l)) (inf-sum g k (succ l)) (h l p) (IH (succ l) (idpath false))))
     o)))
 ; ofs[l] + cnt[l] is the sum through l, which the offsets hold
 (defq inf-sumlast (pi C (pi k nat nat) Of (pi k nat nat) l nat b1 (inf-le 1 l)
     b3 (pi o nat g (inf-lt o l) (paths nat (Of (succ o)) (inf-sum C o 1)))
     (paths nat (add (Of l) (C l)) (inf-sum C l 1)))
   (lam C Of l (nat_rect (lam q (pi b1 (inf-le 1 q) b3 (pi o nat g (inf-lt o q) (paths nat (Of (succ o)) (inf-sum C o 1)))
                                  (paths nat (add (Of q) (C q)) (inf-sum C q 1))))
     (lam b1 b3 (fromempty (paths nat (add (Of 0) (C 0)) 0) (nopathstruetofalse b1)))
     (lam m u b1 b3 (pathscomp0 nat (add (Of (succ m)) (C (succ m))) (add (inf-sum C m 1) (C (succ m))) (inf-sum C (succ m) 1)
       (maponpaths nat nat (lam z (add z (C (succ m)))) (Of (succ m)) (inf-sum C m 1) (b3 m (inf-ltself m)))
       (pathsinv0 nat (inf-sum C (succ m) 1) (add (inf-sum C m 1) (C (succ m))) (inf-snoc C m 1))))
     l)))
 (defq inf-ltne (pi o nat l nat g (inf-le o l) e (paths bool (inf-eqb l o) false) (inf-lt o l))
   (lam o (nat_rect (lam q (pi l nat g (inf-le q l) e (paths bool (inf-eqb l q) false) (inf-lt q l)))
     (lam l (nat_rect (lam z (pi g (inf-le 0 z) e (paths bool (inf-eqb z 0) false) (inf-lt 0 z)))
       (lam g e (fromempty (inf-lt 0 0) (nopathstruetofalse e)))
       (lam m u g e (idpath true))
       l))
     (lam k IH l (nat_rect (lam z (pi g (inf-le (succ k) z) e (paths bool (inf-eqb z (succ k)) false) (inf-lt (succ k) z)))
       (lam g e (fromempty (inf-lt (succ k) 0) (nopathstruetofalse g)))
       (lam m u g e (IH m g e))
       l))
     o)))
 ; ofs[l + 1] = ofs[l] + cnt[l], one offset further
 (defq inf-ofstep (pi C (pi k nat nat) Of (pi k nat nat) l nat b1 (inf-le 1 l)
     b3 (pi o nat g (inf-lt o l) (paths nat (Of (succ o)) (inf-sum C o 1))) o nat g (inf-lt o (succ l))
     (paths nat (inf-upd Of (add l 1) (add (Of l) (C l)) (succ o)) (inf-sum C o 1)))
   (lam C Of l b1 b3 o g (inf-case (inf-eqb (add l 1) (succ o))
     (lam b (paths nat (bool_rect (lam z nat) (add (Of l) (C l)) (Of (succ o)) b) (inf-sum C o 1)))
     (lam e (pathscomp0 nat (add (Of l) (C l)) (inf-sum C l 1) (inf-sum C o 1) (inf-sumlast C Of l b1 b3)
       (maponpaths nat nat (lam z (inf-sum C z 1)) l o
         (maponpaths nat nat (lam z (nat_rect (lam q nat) 0 (lam k r k) z)) (succ l) (succ o)
           (pathscomp0 nat (succ l) (add l 1) (succ o) (pathsinv0 nat (add l 1) (succ l) (inf-add1 l)) (inf-eqp (add l 1) (succ o) e))))))
     (lam e (b3 o (inf-ltne o l (inf-ltsle o l g)
       (pathscomp0 bool (inf-eqb l o) (inf-eqb (add l 1) (succ o)) false
         (pathsinv0 bool (inf-eqb (add l 1) (succ o)) (inf-eqb (succ l) (succ o))
           (maponpaths nat bool (lam z (inf-eqb z (succ o))) (add l 1) (succ l) (inf-add1 l)))
         e)))))))
 (defq inf-eqself (pi x nat (paths bool (inf-eqb x x) true))
   (lam x (nat_rect (lam q (paths bool (inf-eqb q q) true)) (idpath true) (lam k IH IH) x)))
 ; sym[ofs[lens[i]]] is in, the closed form of the offsets carrying inf-symclosed over
 (defq inf-ofs (pi L (pi i nat nat) C (pi k nat nat) Of (pi k nat nat) n nat i nat w (inf-lt i n)
     e2 (pi o nat g (inf-lt o 15) (paths nat (Of (succ o)) (add (inf-sum C o 1) (inf-count L (succ o) i))))
     hs (pi o nat (paths nat (inf-sum C o 1) (inf-sum (lam v (inf-count L v n)) o 1)))
     x nat ex (paths nat (L i) x) p (inf-lt 0 x) h (inf-le x 15) (inf-lt (Of x) n))
   (lam L C Of n i w e2 hs x (nat_rect (lam q (pi ex (paths nat (L i) q) p (inf-lt 0 q) h (inf-le q 15) (inf-lt (Of q) n)))
     (lam ex p h (fromempty (inf-lt (Of 0) n) (nopathsfalsetotrue p)))
     (lam o u ex p h
       (inf-lttr (add (inf-sum (lam v (inf-count L v n)) o 1) (inf-count L (succ o) i)) (Of (succ o)) n
         (pathsinv0 nat (Of (succ o)) (add (inf-sum (lam v (inf-count L v n)) o 1) (inf-count L (succ o) i))
           (pathscomp0 nat (Of (succ o)) (add (inf-sum C o 1) (inf-count L (succ o) i))
             (add (inf-sum (lam v (inf-count L v n)) o 1) (inf-count L (succ o) i))
             (e2 o (inf-lesl o 15 h))
             (maponpaths nat nat (lam z (add z (inf-count L (succ o) i))) (inf-sum C o 1) (inf-sum (lam v (inf-count L v n)) o 1) (hs o))))
         (inf-symclosed L n i o w
           (transportf nat (lam z (paths bool (inf-eqb z (succ o)) true)) (succ o) (L i)
             (pathsinv0 nat (L i) (succ o) ex) (inf-eqself (succ o))))))
     x)))
 ; the fill's step: this length's offset takes the symbol
 (defq inf-fillstep (pi Of (pi k nat nat) L (pi i nat nat) i nat z0 nat o nat e (paths nat (Of (succ o)) (add z0 (inf-count L (succ o) i)))
     (paths nat (inf-upd Of (L i) (add (Of (L i)) 1) (succ o)) (add z0 (inf-count L (succ o) (succ i)))))
   (lam Of L i z0 o e (inf-case (inf-eqb (L i) (succ o))
     (lam b (paths nat (bool_rect (lam z nat) (add (Of (L i)) 1) (Of (succ o)) b)
                       (add z0 (add (bool_rect (lam z nat) 1 0 b) (inf-count L (succ o) i)))))
     (lam h (pathscomp0 nat (add (Of (L i)) 1) (add (add z0 (inf-count L (succ o) i)) 1) (add z0 (add 1 (inf-count L (succ o) i)))
       (maponpaths nat nat (lam z (add z 1)) (Of (L i)) (add z0 (inf-count L (succ o) i))
         (pathscomp0 nat (Of (L i)) (Of (succ o)) (add z0 (inf-count L (succ o) i))
           (maponpaths nat nat Of (L i) (succ o) (inf-eqp (L i) (succ o) h)) e))
       (pathscomp0 nat (add (add z0 (inf-count L (succ o) i)) 1) (succ (add z0 (inf-count L (succ o) i))) (add z0 (succ (inf-count L (succ o) i)))
         (inf-add1 (add z0 (inf-count L (succ o) i)))
         (nat_rect (lam q (paths nat (succ (add q (inf-count L (succ o) i))) (add q (succ (inf-count L (succ o) i)))))
           (idpath (succ (inf-count L (succ o) i)))
           (lam k IH (maponpaths nat nat (lam z (succ z)) (succ (add k (inf-count L (succ o) i))) (add k (succ (inf-count L (succ o) i))) IH))
           z0))))
     (lam h e))))
 ; a length of 0 counts for none
 (defq inf-fillzero (pi L (pi i nat nat) i nat o nat e (paths nat (L i) 0)
     (paths nat (inf-count L (succ o) (succ i)) (inf-count L (succ o) i)))
   (lam L i o e (maponpaths bool nat (lam b (add (bool_rect (lam z nat) 1 0 b) (inf-count L (succ o) i)))
     (inf-eqb (L i) (succ o)) false
     (maponpaths nat bool (lam z (inf-eqb z (succ o))) (L i) 0 e))))
 (defq inf-uplt (pi f (pi j nat nat) k nat v nat B nat g (pi j nat (inf-lt (f j) B)) h (inf-lt v B)
     j nat (inf-lt (inf-upd f k v j) B))
   (lam f k v B g h j
     (inf-case (inf-eqb k j)
       (lam b (inf-lt (bool_rect (lam z nat) v (f j) b) B))
       (lam e h)
       (lam e (g j)))))
 ; a stride under the table falls: what is left past j + d is under what is left past j
 (defq inf-subpos2 (pi P nat d nat g (inf-lt 0 P) p (inf-lt 0 d) (inf-lt (natminus P d) P))
   (lam P (nat_rect (lam q (pi d nat g (inf-lt 0 q) p (inf-lt 0 d) (inf-lt (natminus q d) q)))
     (lam d g p (fromempty (inf-lt (natminus 0 d) 0) (nopathsfalsetotrue g)))
     (lam m u d (nat_rect (lam z (pi g (inf-lt 0 (succ m)) p (inf-lt 0 z) (inf-lt (natminus (succ m) z) (succ m))))
       (lam g p (fromempty (inf-lt (natminus (succ m) 0) (succ m)) (nopathsfalsetotrue p)))
       (lam e v g p (inf-lelts (natminus m e) m (inf-suble m e)))
       d))
     P)))
 (defq inf-subby (pi j nat P nat d nat g (inf-lt j P) p (inf-lt 0 d) (inf-lt (natminus P (add j d)) (natminus P j)))
   (lam j (nat_rect (lam q (pi P nat d nat g (inf-lt q P) p (inf-lt 0 d) (inf-lt (natminus P (add q d)) (natminus P q))))
     (lam P d g p (inf-lttrans (natminus P d) P (natminus P 0) (inf-subpos2 P d g p)
       (inf-letr P P (natminus P 0) (idpath P) (inf-letl P P (natminus P 0) (pathsinv0 nat (natminus P 0) P (natminusn0 P)) (inf-refl P)))))
     (lam k IH P (nat_rect (lam z (pi d nat g (inf-lt (succ k) z) p (inf-lt 0 d)
                                    (inf-lt (natminus z (add (succ k) d)) (natminus z (succ k)))))
       (lam d g p (fromempty (inf-lt (natminus 0 (add (succ k) d)) (natminus 0 (succ k))) (nopathsfalsetotrue g)))
       (lam m u d g p (IH m d g p))
       P))
     j)))
 ; the code: twice it stays under the index shifted by the length, so it fits through length 15
 (defq inf-ltaddpos (pi x nat y nat p (inf-lt 0 y) (inf-lt x (add x y)))
   (lam x y p (inf-lttr (add x 0) x (add x y) (natplusr0 x) (inf-ltaddl x 0 y p))))
 (defq inf-dkmono (pi a nat b nat k nat g (inf-le a b) (inf-le (inf-dk a k) (inf-dk b k)))
   (lam a b k g (nat_rect (lam q (inf-le (inf-dk a q) (inf-dk b q))) g
     (lam j IH (inf-dbl (inf-dk a j) (inf-dk b j) IH)) k)))
 (defq inf-dkinc (pi x nat k nat (inf-lt (inf-dk x k) (inf-dk (add x 1) k)))
   (lam x k (nat_rect (lam q (inf-lt (inf-dk x q) (inf-dk (add x 1) q)))
     (inf-ltaddpos x 1 (idpath true))
     (lam j IH (inf-dblfit (inf-dk x j) (inf-dk (add x 1) j) IH)) k)))
 (defq inf-code2 (pi c nat x nat l nat h1 (inf-le 1 l) h (inf-le (add c c) (inf-dk x l))
     (inf-le (add (add c 1) (add c 1)) (inf-dk (add x 1) l)))
   (lam c x l (nat_rect (lam q (pi h1 (inf-le 1 q) h (inf-le (add c c) (inf-dk x q))
                                 (inf-le (add (add c 1) (add c 1)) (inf-dk (add x 1) q))))
     (lam h1 h (fromempty (inf-le (add (add c 1) (add c 1)) (add x 1)) (nopathstruetofalse h1)))
     (lam m u h1 h (inf-letr (add (add c c) 2) (add (add c 1) (add c 1)) (inf-dk (add x 1) (succ m))
       (pathsinv0 nat (add (add c 1) (add c 1)) (add (add c c) 2) (inf-two c))
       (inf-letrans (add (add c c) 2) (add (add (inf-dk x m) (inf-dk x m)) 2) (inf-dk (add x 1) (succ m))
         (inf-addr (add c c) (add (inf-dk x m) (inf-dk x m)) 2 h)
         (inf-two2 (inf-dk x m) (inf-dk (add x 1) m) (inf-dkinc x m)))))
     l)))
 ; the walk of the counts through a loop
 (defq inf-subpos (pi c nat i nat g (inf-lt i c) (inf-lt 0 (natminus c i)))
   (lam c i g (transportf nat (lam z (inf-lt 0 z)) (succ (natminus c (succ i))) (natminus c i)
     (pathsinv0 nat (natminus c i) (succ (natminus c (succ i))) (inf-subsucc c i g)) (idpath true))))
 (defq inf-idxin (pi idx nat c nat i nat r nat n nat g (inf-lt i c) h (inf-le (add (add idx (natminus c i)) r) n) (inf-lt idx n))
   (lam idx c i r n g h (inf-lttrans idx (add idx (natminus c i)) n (inf-ltaddpos idx (natminus c i) (inf-subpos c i g))
     (inf-letrans (add idx (natminus c i)) (add (add idx (natminus c i)) r) n (inf-leaddr (add idx (natminus c i)) r) h))))
 (defq inf-idxstep (pi idx nat c nat i nat r nat n nat g (inf-lt i c) h (inf-le (add (add idx (natminus c i)) r) n)
     (inf-le (add (add (add idx 1) (natminus c (succ i))) r) n))
   (lam idx c i r n g h (inf-letr (add (add idx (natminus c i)) r) (add (add (add idx 1) (natminus c (succ i))) r) n
     (maponpaths nat nat (lam z (add z r)) (add idx (natminus c i)) (add (add idx 1) (natminus c (succ i)))
       (pathscomp0 nat (add idx (natminus c i)) (add idx (succ (natminus c (succ i)))) (add (add idx 1) (natminus c (succ i)))
         (maponpaths nat nat (lam z (add idx z)) (natminus c i) (succ (natminus c (succ i))) (inf-subsucc c i g))
         (pathscomp0 nat (add idx (succ (natminus c (succ i)))) (add (succ idx) (natminus c (succ i))) (add (add idx 1) (natminus c (succ i)))
           (natplusnsm idx (natminus c (succ i)))
           (maponpaths nat nat (lam z (add z (natminus c (succ i)))) (succ idx) (add idx 1) (pathsinv0 nat (add idx 1) (succ idx) (inf-add1 idx))))))
     h)))
 (defq inf-idxout (pi idx nat y nat r nat n nat h (inf-le (add (add idx y) r) n) (inf-le (add idx r) n))
   (lam idx y r n h (inf-letrans (add idx r) (add (add idx y) r) n (inf-addr idx (add idx y) r (inf-leaddr idx y)) h)))
 (defq inf-idxenter (pi C (pi k nat nat) l nat idx nat m nat g (inf-lt l 16)
     h (inf-le (add idx (inf-sum C (natminus 16 l) l)) m)
     (inf-le (add (add idx (natminus (C l) 0)) (inf-sum C (natminus 16 (succ l)) (succ l))) m))
   (lam C l idx m g h (inf-letr (add (add idx (C l)) (inf-sum C (natminus 16 (succ l)) (succ l)))
       (add (add idx (natminus (C l) 0)) (inf-sum C (natminus 16 (succ l)) (succ l))) m
     (maponpaths nat nat (lam z (add (add idx z) (inf-sum C (natminus 16 (succ l)) (succ l)))) (C l) (natminus (C l) 0)
       (pathsinv0 nat (natminus (C l) 0) (C l) (natminusn0 (C l))))
     (inf-sumnext C 16 l idx m g h))))
 (defq inf-leby16 (pi q nat (inf-le q (inf-by16 q)))
   (lam q (nat_rect (lam z (inf-le z (inf-by16 z)))
     (idpath false)
     (lam k IH (inf-letrans k (inf-by16 k) (add 15 (inf-by16 k)) IH (inf-leaddl (inf-by16 k) 15)))
     q)))
)

; --- what the generated bit reader owes ---
(test
 (defq inf-wlit (pi x nat w nat gw (inf-le 32 w) g (inf-le x 63) (inf-lt x (inf-pow w)))
   (lam x w gw g (inf-lelt x 63 (inf-pow w) g
     (inf-lttrans 63 128 (inf-pow w) (idpath true) (inf-powle 7 w (inf-letrans 7 32 w (idpath false) gw))))))
 (defq inf-modpos (pi p nat x nat g (inf-lt 0 p) (inf-lt (inf-mod p x) p))
   (lam p x (nat_rect (lam q (pi g (inf-lt 0 q) (inf-lt (inf-mod q x) q)))
     (lam g (fromempty (inf-lt (inf-mod 0 x) 0) (nopathsfalsetotrue g)))
     (lam j IH g (inf-modlt j x))
     p)))
 (defq inf-masklt (pi x nat k nat (inf-lt (inf-mod (inf-pow k) x) (inf-pow k)))
   (lam x k (inf-modpos (inf-pow k) x (inf-powpos k))))
 (defq inf-fill1b (pi carry nat ip nat cons nat bc nat i (inf-bits-inv carry ip cons bc)
     (inf-bits-inv carry (add ip 1) cons (add bc 8)))
   (lam carry ip cons bc i
     (pathscomp0 nat (add carry (inf-by8 (add ip 1))) (add carry (add (inf-by8 ip) 8)) (add cons (add bc 8))
       (maponpaths nat nat (lam z (add carry z)) (inf-by8 (add ip 1)) (add (inf-by8 ip) 8) (inf-by8add ip 1))
       (pathscomp0 nat (add carry (add (inf-by8 ip) 8)) (add (add cons bc) 8) (add cons (add bc 8))
         (inf-carry carry (inf-by8 ip) 8 (add cons bc) i)
         (natplusassoc cons bc 8)))))
 (defq inf-subfall1 (pi n nat l nat g (inf-lt l n) (inf-lt (natminus n (add l 1)) (natminus n l)))
   (lam n l g
     (inf-lttr (natminus n (succ l)) (natminus n (add l 1)) (natminus n l)
       (maponpaths nat nat (lam z (natminus n z)) (succ l) (add l 1) (pathsinv0 nat (add l 1) (succ l) (inf-add1 l)))
       (inf-subfall n l g))))
 (defq inf-nfit (pi a nat k nat n nat w nat g (inf-le a n) h (inf-le k 8) f (inf-lt (add n 8) (inf-pow w))
     (inf-lt (add a k) (inf-pow w)))
   (lam a k n w g h f (inf-lelt (add a k) (add n 8) (inf-pow w) (inf-add2 a n k 8 g h) f)))
 (defq inf-roomle (pi a nat c nat l nat g (inf-le l (natminus c a)) h (inf-le a c) (inf-le (add a l) c))
   (lam a c l g h (inf-letl (add a l) (add a (natminus c a)) c (inf-addsub a c h) (inf-addl a l (natminus c a) g))))
 ; dropping to a byte: what stays is whole bytes, so its >> 3 reads back exactly
 (defq inf-modle8 (pi x nat (inf-le (inf-mod 8 x) x))
   (lam x (inf-letl (inf-mod 8 x) (add (inf-by8 (inf-div8 x)) (inf-mod 8 x)) x (inf-divmod x)
     (inf-leaddl (inf-mod 8 x) (inf-by8 (inf-div8 x))))))
 (defq inf-by8low (pi q nat (paths nat (inf-mod 8 (inf-by8 q)) 0)) (lam q (inf-timeslow 7 q)))
 (defq inf-bytes (pi x nat (paths nat (natminus x (inf-mod 8 x)) (inf-by8 (inf-div8 x))))
   (lam x (pathscomp0 nat (natminus x (inf-mod 8 x))
       (natminus (add (inf-mod 8 x) (inf-by8 (inf-div8 x))) (inf-mod 8 x)) (inf-by8 (inf-div8 x))
     (maponpaths nat nat (lam z (natminus z (inf-mod 8 x))) x (add (inf-mod 8 x) (inf-by8 (inf-div8 x)))
       (pathscomp0 nat x (add (inf-by8 (inf-div8 x)) (inf-mod 8 x)) (add (inf-mod 8 x) (inf-by8 (inf-div8 x)))
         (pathsinv0 nat (add (inf-by8 (inf-div8 x)) (inf-mod 8 x)) x (inf-divmod x))
         (natpluscomm (inf-by8 (inf-div8 x)) (inf-mod 8 x))))
     (inf-cancel (inf-mod 8 x) (inf-by8 (inf-div8 x))))))
 (defq inf-whole8 (pi x nat e (paths nat (inf-mod 8 x) 0) (paths nat (inf-by8 (inf-div8 x)) x))
   (lam x e (pathscomp0 nat (inf-by8 (inf-div8 x)) (add (inf-by8 (inf-div8 x)) 0) x
     (pathsinv0 nat (add (inf-by8 (inf-div8 x)) 0) (inf-by8 (inf-div8 x)) (natplusr0 (inf-by8 (inf-div8 x))))
     (pathscomp0 nat (add (inf-by8 (inf-div8 x)) 0) (add (inf-by8 (inf-div8 x)) (inf-mod 8 x)) x
       (maponpaths nat nat (lam z (add (inf-by8 (inf-div8 x)) z)) 0 (inf-mod 8 x) (pathsinv0 nat (inf-mod 8 x) 0 e))
       (inf-divmod x)))))
 (defq inf-dropwhole (pi x nat (paths nat (inf-by8 (inf-div8 (natminus x (inf-mod 8 x)))) (natminus x (inf-mod 8 x))))
   (lam x (inf-whole8 (natminus x (inf-mod 8 x))
     (pathscomp0 nat (inf-mod 8 (natminus x (inf-mod 8 x))) (inf-mod 8 (inf-by8 (inf-div8 x))) 0
       (maponpaths nat nat (inf-mod 8) (natminus x (inf-mod 8 x)) (inf-by8 (inf-div8 x)) (inf-bytes x))
       (inf-by8low (inf-div8 x))))))
 (defq inf-dropinv (pi ip nat cons nat bc nat i (inf-bits-inv 0 ip cons bc)
     (inf-bits-inv 0 ip (add cons (inf-mod 8 bc)) (inf-by8 (inf-div8 (natminus bc (inf-mod 8 bc))))))
   (lam ip cons bc i
     (pathscomp0 nat (inf-by8 ip) (add (add cons (inf-mod 8 bc)) (natminus bc (inf-mod 8 bc)))
       (add (add cons (inf-mod 8 bc)) (inf-by8 (inf-div8 (natminus bc (inf-mod 8 bc)))))
       (inf-take 0 ip cons bc (inf-mod 8 bc) (inf-modle8 bc) i)
       (maponpaths nat nat (lam z (add (add cons (inf-mod 8 bc)) z))
         (natminus bc (inf-mod 8 bc)) (inf-by8 (inf-div8 (natminus bc (inf-mod 8 bc))))
         (pathsinv0 nat (inf-by8 (inf-div8 (natminus bc (inf-mod 8 bc)))) (natminus bc (inf-mod 8 bc))
           (inf-dropwhole bc))))))
 ; pos = ip - q reads no bit consumed: byte pos, in bits, is what was consumed
 (defq inf-posb (pi ip nat cons nat q nat i (inf-bits-inv 0 ip cons (inf-by8 q))
     (paths nat (inf-by8 (natminus ip q)) cons))
   (lam ip cons q i
     (pathscomp0 nat (inf-by8 (natminus ip q))
       (natminus (add (inf-by8 q) (inf-by8 (natminus ip q))) (inf-by8 q)) cons
       (pathsinv0 nat (natminus (add (inf-by8 q) (inf-by8 (natminus ip q))) (inf-by8 q)) (inf-by8 (natminus ip q))
         (inf-cancel (inf-by8 q) (inf-by8 (natminus ip q))))
       (pathscomp0 nat (natminus (add (inf-by8 q) (inf-by8 (natminus ip q))) (inf-by8 q))
         (natminus (add (inf-by8 q) cons) (inf-by8 q)) cons
         (maponpaths nat nat (lam z (natminus z (inf-by8 q)))
           (add (inf-by8 q) (inf-by8 (natminus ip q))) (add (inf-by8 q) cons)
           (pathscomp0 nat (add (inf-by8 q) (inf-by8 (natminus ip q)))
             (inf-by8 (add q (natminus ip q))) (add (inf-by8 q) cons)
             (pathsinv0 nat (inf-by8 (add q (natminus ip q))) (add (inf-by8 q) (inf-by8 (natminus ip q)))
               (inf-by8add q (natminus ip q)))
             (pathscomp0 nat (inf-by8 (add q (natminus ip q))) (inf-by8 ip) (add (inf-by8 q) cons)
               (maponpaths nat nat inf-by8 (add q (natminus ip q)) ip (inf-addsub q ip (inf-pos ip cons q i)))
               (pathscomp0 nat (inf-by8 ip) (add cons (inf-by8 q)) (add (inf-by8 q) cons)
                 i (natpluscomm cons (inf-by8 q))))))
         (inf-cancel (inf-by8 q) cons)))))
 ; a stored block ends past pos, and consumption grows
 (defq inf-storedc (pi ip nat cons nat m nat q nat k nat l nat i (inf-bits-inv 0 ip (add cons m) (inf-by8 q))
     (inf-le cons (inf-by8 (add (add (natminus ip q) k) l))))
   (lam ip cons m q k l i
     (inf-letrans cons (add cons m) (inf-by8 (add (add (natminus ip q) k) l))
       (inf-leaddr cons m)
       (inf-letr (inf-by8 (natminus ip q)) (add cons m) (inf-by8 (add (add (natminus ip q) k) l))
         (inf-posb ip (add cons m) q i)
         (inf-by8mono (natminus ip q) (add (add (natminus ip q) k) l)
           (inf-letrans (natminus ip q) (add (natminus ip q) k) (add (add (natminus ip q) k) l)
             (inf-leaddr (natminus ip q) k) (inf-leaddr (add (natminus ip q) k) l)))))))
 ; min (d - op) l, as the copy takes it
 (defq inf-htt (pi d nat op nat l nat g (inf-lt (natminus d op) l) (paths nat (natminus d op) (inf-h d op l)))
   (lam d op l g (inf-case (natgtb l (natminus d op))
     (lam b (pi e (paths bool b true) (paths nat (natminus d op) (bool_rect (lam c nat) (natminus d op) l b))))
     (lam e h (idpath (natminus d op)))
     (lam e h (fromempty (paths nat (natminus d op) l) (nopathsfalsetotrue h)))
     g)))
 (defq inf-hff (pi d nat op nat l nat g (inf-le l (natminus d op)) (paths nat l (inf-h d op l)))
   (lam d op l g (inf-case (natgtb l (natminus d op))
     (lam b (pi e (paths bool b false) (paths nat l (bool_rect (lam c nat) (natminus d op) l b))))
     (lam e h (fromempty (paths nat l (natminus d op)) (nopathstruetofalse h)))
     (lam e h (idpath l))
     g)))
 ; a built code's counts: each is at most the symbols, the zero's the build sets
 (defq inf-cphi (pi C (pi k nat nat) L (pi i nat nat) n nat u nat
     hk (pi k nat g (inf-le 1 k) (paths nat (C k) (inf-count L k n)))
     h0 (inf-lt (C 0) u) gm (inf-lt n u) i nat (inf-lt (C i) u))
   (lam C L n u hk h0 gm i
     (nat_rect (lam q (inf-lt (C q) u))
       h0
       (lam j IH (inf-lelt (C (succ j)) n u
         (inf-letr (inf-count L (succ j) n) (C (succ j)) n
           (pathsinv0 nat (C (succ j)) (inf-count L (succ j) n) (hk (succ j) (idpath false)))
           (inf-cntle L (succ j) n))
         gm))
       i)))
 (defq inf-wfit288 (pi w nat gw (inf-le 32 w) (inf-lt 288 (inf-pow w)))
   (lam w gw (inf-lttrans 288 512 (inf-pow w) (idpath true) (inf-powle 9 w (inf-letrans 9 32 w (idpath false) gw)))))
 (defq inf-wnine (pi w nat gw (inf-le 32 w) (inf-lt 512 (inf-pow w)))
   (lam w gw (inf-lttrans 512 1024 (inf-pow w) (idpath true) (inf-powle 10 w (inf-letrans 10 32 w (idpath false) gw)))))
 (defq inf-pos3 (pi x nat y nat p (inf-lt 0 y) (inf-lt 0 (add x y)))
   (lam x y p (inf-lelt 0 x (add x y) (idpath false) (inf-ltaddpos x y p))))
 (defn inf-shift (pi f (pi k nat nat) a nat k nat nat) (lam f a k (f (add a k))))
 (defq inf-bitsub (pi a nat b nat c nat g (inf-le (add a b) c) (inf-le b (natminus c a)))
   (lam a b c g (inf-letr (natminus (add a b) a) b (natminus c a) (inf-cancel a b) (inf-submono (add a b) c a g))))
 ; the pair's bits, each out of what the last left
 (defq inf-fastb1 (pi a nat b nat bc nat ga (inf-le a 15) gb (inf-le b 5) g (inf-le 48 bc) (inf-le b (natminus bc a)))
   (lam a b bc ga gb g
     (inf-bitsub a b bc (inf-letrans (add a b) 48 bc (inf-letrans (add a b) 20 48 (inf-add2 a 15 b 5 ga gb) (idpath false)) g))))
 (defq inf-fastb2 (pi a nat b nat c nat bc nat ga (inf-le a 15) gb (inf-le b 5) gc (inf-le c 15) g (inf-le 48 bc)
     (inf-le c (natminus (natminus bc a) b)))
   (lam a b c bc ga gb gc g
     (inf-bitsub b c (natminus bc a) (inf-bitsub a (add b c) bc
       (inf-letrans (add a (add b c)) 48 bc (inf-letrans (add a (add b c)) 35 48 (inf-add2 a 15 (add b c) 20 ga (inf-add2 b 5 c 15 gb gc)) (idpath false)) g)))))
 (defq inf-fastb3 (pi a nat b nat c nat d nat bc nat ga (inf-le a 15) gb (inf-le b 5) gc (inf-le c 15) gd (inf-le d 13) g (inf-le 48 bc)
     (inf-le d (natminus (natminus (natminus bc a) b) c)))
   (lam a b c d bc ga gb gc gd g
     (inf-bitsub c d (natminus (natminus bc a) b) (inf-bitsub b (add c d) (natminus bc a) (inf-bitsub a (add b (add c d)) bc
       (inf-fastbits a b c d bc ga gb gc gd g))))))
 ; a table's base and its extra bits stay under what base + 2^bits does
 (defq inf-baseadd (pi a nat x nat m nat T nat g (inf-le (add a (inf-pow x)) T) (inf-lt (add a (inf-mod (inf-pow x) m)) T))
   (lam a x m T g (inf-lttrans (add a (inf-mod (inf-pow x) m)) (add a (inf-pow x)) T (inf-ltaddl a (inf-mod (inf-pow x) m) (inf-pow x) (inf-masklt m x)) g)))
 (defq inf-step8 (pi k nat l nat g (inf-lt k l) (inf-le (add k 8) (add l 7)))
   (lam k l g (inf-letr (add (add k 1) 7) (add k 8) (add l 7) (natplusassoc k 1 7) (inf-addr (add k 1) l 7 (inf-lt1 k l g)))))
 (defq inf-basele (pi a nat x nat m nat T nat h (inf-lt m (inf-pow x)) g (inf-le (add a (inf-pow x)) T) (inf-lt (add a m) T))
   (lam a x m T h g (inf-lttrans (add a m) (add a (inf-pow x)) T (inf-ltaddl a m (inf-pow x) h) g)))
 ; less taken leaves more
 (defq inf-subanti (pi a nat b nat c nat g (inf-le a b) (inf-le (natminus c b) (natminus c a)))
   (lam a (nat_rect (lam q (pi b nat c nat g (inf-le q b) (inf-le (natminus c b) (natminus c q))))
     (lam b c g (inf-letl (natminus c b) c (natminus c 0) (pathsinv0 nat (natminus c 0) c (natminusn0 c)) (inf-suble c b)))
     (lam k IH b (nat_rect (lam z (pi c nat g (inf-le (succ k) z) (inf-le (natminus c z) (natminus c (succ k)))))
       (lam c g (fromempty (inf-le (natminus c 0) (natminus c (succ k))) (nopathstruetofalse g)))
       (lam m u c (nat_rect (lam y (pi g (inf-le (succ k) (succ m)) (inf-le (natminus y (succ m)) (natminus y (succ k)))))
         (lam g (idpath false))
         (lam y v g (IH m y g))
         c))
       b))
     a)))
 (defq inf-subfrom (pi a nat b nat c nat d nat h (inf-le a b) g (inf-lt b c) p (inf-lt 0 d)
     (inf-lt (natminus c (add b d)) (natminus c a)))
   (lam a b c d h g p (inf-lttrans (natminus c (add b d)) (natminus c b) (natminus c a) (inf-subby b c d g p) (inf-subanti a b c h))))
 ; what is consumed stays within the input, so taking more always lowers what is left
 (defq inf-substrict (pi a nat b nat c nat h (inf-lt a b) g (inf-le b c) (inf-lt (natminus c b) (natminus c a)))
   (lam a b c h g (inf-lelt (natminus c b) (natminus c (succ a)) (natminus c a)
     (inf-subanti (succ a) b c (inf-ltsu a b h)) (inf-subfall c a (inf-lttrans a b c h g)))))
 (defq inf-consfall (pi carry nat ip nat c nat bc nat n nat a nat i (inf-bits-inv carry ip c bc) g (inf-le ip n) h (inf-lt a c)
     (inf-lt (natminus (add carry (inf-by8 n)) c) (natminus (add carry (inf-by8 n)) a)))
   (lam carry ip c bc n a i g h (inf-substrict a c (add carry (inf-by8 n)) h
     (inf-letrans c (add c bc) (add carry (inf-by8 n)) (inf-leaddr c bc)
       (inf-letr (add carry (inf-by8 ip)) (add c bc) (add carry (inf-by8 n)) i (inf-addl carry (inf-by8 ip) (inf-by8 n) (inf-by8mono ip n g)))))))
 ; a stored run skips the buffer: k bytes read, 8k bits consumed
 (defq inf-advb (pi carry nat ip nat cons nat bc nat k nat i (inf-bits-inv carry ip cons bc)
     (inf-bits-inv carry (add ip k) (add cons (inf-by8 k)) bc))
   (lam carry ip cons bc k i
     (pathscomp0 nat (add carry (inf-by8 (add ip k))) (add carry (add (inf-by8 ip) (inf-by8 k))) (add (add cons (inf-by8 k)) bc)
       (maponpaths nat nat (lam z (add carry z)) (inf-by8 (add ip k)) (add (inf-by8 ip) (inf-by8 k)) (inf-by8add ip k))
       (pathscomp0 nat (add carry (add (inf-by8 ip) (inf-by8 k))) (add (add cons bc) (inf-by8 k)) (add (add cons (inf-by8 k)) bc)
         (inf-carry carry (inf-by8 ip) (inf-by8 k) (add cons bc) i)
         (inf-swap3 cons bc (inf-by8 k))))))
 (defq inf-dec1 (pi n nat g (inf-lt 0 n) (inf-lt (natminus n 1) n))
   (lam n g (transportf nat (lam x (inf-lt (natminus n 1) x)) (natminus n 0) n (natminusn0 n) (inf-subfall n 0 g))))
 ; a table's fact, over its whole domain: none of them answers true, which the kernel can run
 (defn inf-anyb (pi P (pi k nat bool) n nat bool)
   (lam P n (nat_rect (lam q bool) false (lam k r (bool_rect (lam b bool) true r (P k))) n)))
 (defq inf-orl (pi a bool r bool e (paths bool (bool_rect (lam b bool) true r a) false) (paths bool a false))
   (lam a (bool_rect (lam x (pi r bool e (paths bool (bool_rect (lam b bool) true r x) false) (paths bool x false)))
     (lam r e (fromempty (paths bool true false) (nopathstruetofalse e)))
     (lam r e (idpath false))
     a)))
 (defq inf-orr (pi a bool r bool e (paths bool (bool_rect (lam b bool) true r a) false) (paths bool r false))
   (lam a (bool_rect (lam x (pi r bool e (paths bool (bool_rect (lam b bool) true r x) false) (paths bool r false)))
     (lam r e (fromempty (paths bool r false) (nopathstruetofalse e)))
     (lam r e e)
     a)))
 (defq inf-anyno (pi P (pi k nat bool) n nat e (paths bool (inf-anyb P n) false) k nat g (inf-lt k n) (paths bool (P k) false))
   (lam P n (nat_rect (lam q (pi e (paths bool (inf-anyb P q) false) k nat g (inf-lt k q) (paths bool (P k) false)))
     (lam e k g (fromempty (paths bool (P k) false) (nopathsfalsetotrue g)))
     (lam m IH e k g
       (inf-case (inf-eqb m k) (lam x (paths bool (P k) false))
         (lam e1 (transportf nat (lam x (paths bool (P x) false)) m k (inf-eqp m k e1) (inf-orl (P m) (inf-anyb P m) e)))
         (lam e1 (IH (inf-orr (P m) (inf-anyb P m) e) k (inf-ltne k m (inf-ltsle k m g) e1)))))
     n)))
 ; one entry of a table, zero off it
 (defn inf-tv (pi i nat v nat k nat nat) (lam i v k (bool_rect (lam b nat) v 0 (inf-eqb i k))))
 ; the code's scale: a symbol times 16 fits its table entry, and doubling through length 15 fits w
 (defq inf-dkpow (pi a nat k nat (paths nat (inf-dk (inf-pow a) k) (inf-pow (add k a))))
   (lam a k (nat_rect (lam q (paths nat (inf-dk (inf-pow a) q) (inf-pow (add q a))))
     (idpath (inf-pow a))
     (lam j IH (maponpaths nat nat (lam z (add z z)) (inf-dk (inf-pow a) j) (inf-pow (add j a)) IH))
     k)))
 (defq inf-topk (pi w nat gw (inf-le 32 w) k nat g (inf-le k 15) (inf-lt (inf-dk (inf-pow 12) k) (inf-pow w)))
   (lam w gw k g
     (inf-lttr (inf-pow (add k 12)) (inf-dk (inf-pow 12) k) (inf-pow w)
       (pathsinv0 nat (inf-dk (inf-pow 12) k) (inf-pow (add k 12)) (inf-dkpow 12 k))
       (inf-lttrans (inf-pow (add k 12)) (add (inf-pow (add k 12)) (inf-pow (add k 12))) (inf-pow w)
         (inf-ltaddpos (inf-pow (add k 12)) (inf-pow (add k 12)) (inf-powpos (add k 12)))
         (inf-powle (succ (add k 12)) w
           (inf-ltsu (add k 12) w (inf-lelt (add k 12) 27 w (inf-addr k 15 12 g) (inf-lttrans 27 32 w (idpath true) gw))))))))
 ; what a feed's bounds fit: powers under a word, and what two of them sum to
 (defq inf-wpow (pi w nat k nat gw (inf-le 32 w) g (inf-lt k 32) (inf-lt (inf-pow k) (inf-pow w)))
   (lam w k gw g (inf-powlt k w (inf-lttrans k 32 w g gw))))
 (defq inf-powdbl (pi k nat a nat b nat g (inf-le a (inf-pow k)) h (inf-le b (inf-pow k)) (inf-le (add a b) (inf-pow (succ k))))
   (lam k a b g h (inf-add2 a (inf-pow k) b (inf-pow k) g h)))
 (defq inf-fitlim (pi w nat l nat a nat b nat gw (inf-le 32 w) m (inf-lt l 31) g (inf-le a (inf-pow l)) h (inf-le b (inf-pow l)) (inf-lt (add a b) (inf-pow w)))
   (lam w l a b gw m g h (inf-lelt (add a b) (inf-pow (succ l)) (inf-pow w) (inf-powdbl l a b g h)
     (inf-wpow w (succ l) gw (inf-lelts (succ l) 31 (inf-ltsu l 31 m))))))
 ; a feed's first guess, four times its input and a little: stated for any k, so no power is ever computed
 (defq inf-four (pi k nat l nat a nat g (inf-le a (inf-pow k)) h (inf-le (succ (succ (succ k))) l)
                  (inf-le (add (add a a) (add a a)) (inf-pow l)))
   (lam k l a g h (inf-letrans (add (add a a) (add a a)) (inf-pow (succ (succ k))) (inf-pow l)
     (inf-powdbl (succ k) (add a a) (add a a) (inf-powdbl k a a g g) (inf-powdbl k a a g g))
     (inf-powle (succ (succ k)) l (inf-letrans (succ (succ k)) (succ (succ (succ k))) l (natlehsucc (succ (succ k)) (succ (succ k)) (inf-refl (succ (succ k)))) h)))))
 (defq inf-fourp (pi k nat l nat a nat p nat g (inf-le a (inf-pow k)) i (inf-le p (inf-pow k)) h (inf-le (succ (succ (succ k))) l)
                   (inf-le (add (add (add a a) (add a a)) p) (inf-pow l)))
   (lam k l a p g i h (inf-letrans (add (add (add a a) (add a a)) p) (inf-pow (succ (succ (succ k)))) (inf-pow l)
     (inf-powdbl (succ (succ k)) (add (add a a) (add a a)) p
       (inf-powdbl (succ k) (add a a) (add a a) (inf-powdbl k a a g g) (inf-powdbl k a a g g))
       (inf-letrans p (inf-pow k) (inf-pow (succ (succ k))) i (inf-powle k (succ (succ k)) (natlehsucc k (succ k) (natlehsucc k k (inf-refl k))))))
     (inf-powle (succ (succ (succ k))) l h))))
 (defq inf-subfit (pi a nat b nat g (inf-le b a) (inf-le (add (natminus a b) b) a))
   (lam a b g (inf-letl (add (natminus a b) b) (add b (natminus a b)) a (inf-addsub b a g)
     (inf-letr (add b (natminus a b)) (add (natminus a b) b) (add b (natminus a b)) (natpluscomm b (natminus a b)) (inf-refl (add b (natminus a b)))))))
 (defq inf-subdown (pi P nat a nat b nat g (inf-lt a b) h (inf-le b P) (inf-lt (natminus P b) (natminus P a)))
   (lam P a b g h (inf-lttr (natminus P (add a (natminus b a))) (natminus P b) (natminus P a)
     (maponpaths nat nat (lam q (natminus P q)) (add a (natminus b a)) b (inf-addsub a b (inf-ltle a b g)))
     (inf-subby a P (natminus b a) (inf-lttrans a b P g h) (inf-subpos b a g)))))
 (defq inf-topq (inf-le (inf-by16 (inf-pow 12)) (inf-pow 16))
   (inf-letr (inf-pow (add 4 12)) (inf-by16 (inf-pow 12)) (inf-pow 16)
     (pathsinv0 nat (inf-by16 (inf-pow 12)) (inf-pow (add 4 12)) (inf-by16pow 12))
     (inf-refl (inf-pow 16)))))

; --- a byte's value: what inf_copy writes, for any bytes ---
(test
 (defn inf-blk (pi f (pi j nat nat) i nat g (pi j nat nat) s nat n nat x nat nat)
   (lam f i g s n x
     (bool_rect (lam b nat) (f x)
       (bool_rect (lam b nat) (g (add s (natminus x i))) (f x) (natgtb (add i n) x))
       (natgtb i x))))
 (defq inf-blklo (pi f (pi j nat nat) i nat g (pi j nat nat) s nat n nat x nat h (inf-lt x i)
     (paths nat (inf-blk f i g s n x) (f x)))
   (lam f i g s n x h
     (maponpaths bool nat (lam b (bool_rect (lam c nat) (f x)
         (bool_rect (lam c nat) (g (add s (natminus x i))) (f x) (natgtb (add i n) x)) b))
       (natgtb i x) true h)))
 (defq inf-blkin (pi f (pi j nat nat) i nat g (pi j nat nat) s nat n nat x nat a (inf-le i x) h (inf-lt x (add i n))
     (paths nat (inf-blk f i g s n x) (g (add s (natminus x i)))))
   (lam f i g s n x a h
     (pathscomp0 nat (inf-blk f i g s n x)
       (bool_rect (lam c nat) (g (add s (natminus x i))) (f x) (natgtb (add i n) x))
       (g (add s (natminus x i)))
       (maponpaths bool nat (lam b (bool_rect (lam c nat) (f x)
           (bool_rect (lam c nat) (g (add s (natminus x i))) (f x) (natgtb (add i n) x)) b))
         (natgtb i x) false a)
       (maponpaths bool nat (lam b (bool_rect (lam c nat) (g (add s (natminus x i))) (f x) b))
         (natgtb (add i n) x) true h))))
 (defq inf-blkhi (pi f (pi j nat nat) i nat g (pi j nat nat) s nat n nat x nat h (inf-le (add i n) x)
     (paths nat (inf-blk f i g s n x) (f x)))
   (lam f i g s n x h
     (pathscomp0 nat (inf-blk f i g s n x)
       (bool_rect (lam c nat) (g (add s (natminus x i))) (f x) (natgtb (add i n) x))
       (f x)
       (maponpaths bool nat (lam b (bool_rect (lam c nat) (f x)
           (bool_rect (lam c nat) (g (add s (natminus x i))) (f x) (natgtb (add i n) x)) b))
         (natgtb i x) false (inf-letrans i (add i n) x (inf-leaddr i n) h))
       (maponpaths bool nat (lam b (bool_rect (lam c nat) (g (add s (natminus x i))) (f x) b))
         (natgtb (add i n) x) false h))))
 ; the order's two sides
 (defq inf-ltcan (pi c nat a nat b nat h (inf-lt (add c a) (add c b)) (inf-lt a b))
   (lam c (nat_rect (lam q (pi a nat b nat h (inf-lt (add q a) (add q b)) (inf-lt a b)))
     (lam a b h h)
     (lam k IH a b h (IH a b h))
     c)))
 (defq inf-addcan (pi c nat a nat b nat e (paths nat (add c a) (add c b)) (paths nat a b))
   (lam c (nat_rect (lam q (pi a nat b nat e (paths nat (add q a) (add q b)) (paths nat a b)))
     (lam a b e e)
     (lam k IH a b e (IH a b (maponpaths nat nat (lam z (nat_rect (lam y nat) 0 (lam p u p) z))
       (succ (add k a)) (succ (add k b)) e)))
     c)))
 (defq inf-ltcong (pi a nat b nat c nat d nat e (paths nat a b) f (paths nat c d) h (inf-lt a c) (inf-lt b d))
   (lam a b c d e f h
     (transportf nat (lam z (inf-lt b z)) c d f
       (transportf nat (lam z (inf-lt z c)) a b e h))))
 (defq inf-lecong (pi a nat b nat c nat d nat e (paths nat a b) f (paths nat c d) h (inf-le a c) (inf-le b d))
   (lam a b c d e f h
     (transportf nat (lam z (inf-le b z)) c d f
       (transportf nat (lam z (inf-le z c)) a b e h))))
 (defq inf-subadd (pi a nat b nat (paths nat (natminus (add a b) a) b))
   (lam a b (inf-addcan a (natminus (add a b) a) b (inf-addsub a (add a b) (inf-leaddr a b)))))
 ; (a - c) + (b - a) = b - c
 (defq inf-subsum (pi a nat b nat c nat g (inf-le c a) h (inf-le a b)
     (paths nat (add (natminus a c) (natminus b a)) (natminus b c)))
   (lam a b c g h
     (inf-addcan c (add (natminus a c) (natminus b a)) (natminus b c)
       (pathscomp0 nat (add c (add (natminus a c) (natminus b a))) (add (add c (natminus a c)) (natminus b a)) (add c (natminus b c))
         (pathsinv0 nat (add (add c (natminus a c)) (natminus b a)) (add c (add (natminus a c) (natminus b a))) (natplusassoc c (natminus a c) (natminus b a)))
         (pathscomp0 nat (add (add c (natminus a c)) (natminus b a)) b (add c (natminus b c))
           (pathscomp0 nat (add (add c (natminus a c)) (natminus b a)) (add a (natminus b a)) b
             (maponpaths nat nat (lam z (add z (natminus b a))) (add c (natminus a c)) a (inf-addsub c a g))
             (inf-addsub a b h))
           (pathsinv0 nat (add c (natminus b c)) b (inf-addsub c b (inf-letrans c a b g h))))))))
 ; x - d < y when x < y + d
 (defq inf-subltr (pi x nat y nat d nat g (inf-le d x) h (inf-lt x (add y d)) (inf-lt (natminus x d) y))
   (lam x y d g h
     (inf-ltcan d (natminus x d) y
       (inf-ltcong x (add d (natminus x d)) (add y d) (add d y)
         (pathsinv0 nat (add d (natminus x d)) x (inf-addsub d x g))
         (natpluscomm y d) h))))
 (defq inf-ltnle (pi P UU a nat b nat h (inf-lt a b) g (inf-le b a) P)
   (lam P a b h g (fromempty P (nopathstruetofalse
     (pathscomp0 bool true (natgtb b a) false (pathsinv0 bool (natgtb b a) true h) g)))))
 (defq inf-addassoc (pi a nat b nat c nat (paths nat (add a (add b c)) (add (add a b) c)))
   (lam a b c (pathsinv0 nat (add (add a b) c) (add a (add b c)) (natplusassoc a b c))))
 ; one write of n bytes from n back, n no more than d: the copy so far stays a copy
 (defq inf-lzself (pi f (pi j nat nat) op nat k nat d nat n nat t nat
     gd (inf-le d (add op k)) gn (inf-le n d) gt (inf-lt t (add k n)) g1 (inf-le d (add op t))
     IH (pi u nat a (inf-lt u k) b (inf-le d (add op u)) (paths nat (f (add op u)) (f (natminus (add op u) d))))
     (paths nat (inf-blk f (add op k) f (natminus (add op k) d) n (add op t))
                (inf-blk f (add op k) f (natminus (add op k) d) n (natminus (add op t) d))))
   (lam f op k d n t gd gn gt g1 IH
     (inf-case (natgtb k t)
       (lam b (paths nat (inf-blk f (add op k) f (natminus (add op k) d) n (add op t))
                         (inf-blk f (add op k) f (natminus (add op k) d) n (natminus (add op t) d))))
       (lam e (pathscomp0 nat (inf-blk f (add op k) f (natminus (add op k) d) n (add op t)) (f (add op t))
                (inf-blk f (add op k) f (natminus (add op k) d) n (natminus (add op t) d))
                (inf-blklo f (add op k) f (natminus (add op k) d) n (add op t) (inf-ltaddl op t k e))
                (pathscomp0 nat (f (add op t)) (f (natminus (add op t) d))
                  (inf-blk f (add op k) f (natminus (add op k) d) n (natminus (add op t) d))
                  (IH t e g1)
                  (pathsinv0 nat (inf-blk f (add op k) f (natminus (add op k) d) n (natminus (add op t) d)) (f (natminus (add op t) d))
                    (inf-blklo f (add op k) f (natminus (add op k) d) n (natminus (add op t) d)
                      (inf-lelt (natminus (add op t) d) (add op t) (add op k) (inf-suble (add op t) d) (inf-ltaddl op t k e)))))))
       (lam e (pathscomp0 nat (inf-blk f (add op k) f (natminus (add op k) d) n (add op t))
                (f (natminus (add op t) d))
                (inf-blk f (add op k) f (natminus (add op k) d) n (natminus (add op t) d))
                (pathscomp0 nat (inf-blk f (add op k) f (natminus (add op k) d) n (add op t))
                  (f (add (natminus (add op k) d) (natminus (add op t) (add op k))))
                  (f (natminus (add op t) d))
                  (inf-blkin f (add op k) f (natminus (add op k) d) n (add op t) (inf-addl op k t e)
                    (inf-ltcong (add op t) (add op t) (add op (add k n)) (add (add op k) n)
                      (idpath (add op t)) (inf-addassoc op k n) (inf-ltaddl op t (add k n) gt)))
                  (maponpaths nat nat f (add (natminus (add op k) d) (natminus (add op t) (add op k))) (natminus (add op t) d)
                    (inf-subsum (add op k) (add op t) d gd (inf-addl op k t e))))
                (pathsinv0 nat (inf-blk f (add op k) f (natminus (add op k) d) n (natminus (add op t) d)) (f (natminus (add op t) d))
                  (inf-blklo f (add op k) f (natminus (add op k) d) n (natminus (add op t) d)
                    (inf-subltr (add op t) (add op k) d g1
                      (inf-lttrans (add op t) (add (add op k) n) (add (add op k) d)
                        (inf-ltcong (add op t) (add op t) (add op (add k n)) (add (add op k) n)
                          (idpath (add op t)) (inf-addassoc op k n)
                          (inf-ltaddl op t (add k n) gt))
                        (inf-addl (add op k) n d gn))))))))))
 ; an index in the write's reach, for the loop's other invariants
 (defq inf-lzlo (pi f (pi j nat nat) O (pi j nat nat) op nat k nat g (pi j nat nat) s nat n nat x nat
     h (inf-lt x op) IH (paths nat (f x) (O x))
     (paths nat (inf-blk f (add op k) g s n x) (O x)))
   (lam f O op k g s n x h IH
     (pathscomp0 nat (inf-blk f (add op k) g s n x) (f x) (O x)
       (inf-blklo f (add op k) g s n x (inf-lttrans x op (add op k) h (inf-leaddr op k)))
       IH)))
 (defq inf-lzhi (pi f (pi j nat nat) O (pi j nat nat) op nat k nat g (pi j nat nat) s nat n nat x nat
     h (inf-le (add op (add k n)) x) IH (pi z (inf-le (add op k) x) (paths nat (f x) (O x)))
     (paths nat (inf-blk f (add op k) g s n x) (O x)))
   (lam f O op k g s n x h IH
     (pathscomp0 nat (inf-blk f (add op k) g s n x) (f x) (O x)
       (inf-blkhi f (add op k) g s n x
         (inf-letr (add op (add k n)) (add (add op k) n) x (inf-addassoc op k n) h))
       (IH (inf-letrans (add op k) (add op (add k n)) x (inf-addl op k (add k n) (inf-leaddr k n)) h)))))
 ; d > op: the first bytes are the dictionary's
 (defq inf-lzdict (pi f (pi j nat nat) op nat D (pi j nat nat) S nat m nat t nat h (inf-lt t m)
     (paths nat (inf-blk f op D S m (add op t)) (D (add S t))))
   (lam f op D S m t h
     (pathscomp0 nat (inf-blk f op D S m (add op t)) (D (add S (natminus (add op t) op))) (D (add S t))
       (inf-blkin f op D S m (add op t) (inf-leaddr op t) (inf-ltaddl op t m h))
       (maponpaths nat nat (lam z (D (add S z))) (natminus (add op t) op) t (inf-subadd op t)))))
 ; a position past d is past the dictionary's part
 (defq inf-lzpast (pi d nat op nat m nat t nat g (inf-le m (natminus d op)) o (inf-lt op d) h (inf-lt t m)
     (inf-lt (add op t) d))
   (lam d op m t g o h
     (inf-ltcong (add op t) (add op t) (add op (natminus d op)) d (idpath (add op t))
       (inf-addsub op d (inf-ltle op d o))
       (inf-ltaddl op t (natminus d op) (inf-lttrans t m (natminus d op) h g)))))
 ; t short of l and of d - op is short of the dictionary's part
 (defq inf-hgt (pi d nat op nat l nat t nat g (inf-lt t l) h (inf-lt (add op t) d) (inf-lt t (inf-h d op l)))
   (lam d op l t g h (inf-case (natgtb l (natminus d op))
     (lam b (inf-lt t (bool_rect (lam c nat) (natminus d op) l b)))
     (lam e (inf-ltcan op t (natminus d op)
       (inf-ltcong (add op t) (add op t) d (add op (natminus d op)) (idpath (add op t))
         (pathsinv0 nat (add op (natminus d op)) d
           (inf-addsub op d (inf-letrans op (add op t) d (inf-leaddr op t) (inf-ltle (add op t) d h))))
         h)))
     (lam e g))))
 ; the claim is not empty: at op 1, d 2, the third byte copied is the dictionary's, two bytes back
 (defq inf-lzeg (pi Ot (pi j nat nat) D (pi j nat nat) S nat
     e1 (pi t nat a (inf-lt t 4) b (inf-le 2 (add 1 t)) (paths nat (Ot (add 1 t)) (Ot (natminus (add 1 t) 2))))
     e2 (pi t nat a (inf-lt t 4) b (inf-lt (add 1 t) 2) (paths nat (Ot (add 1 t)) (D (add S t))))
     (paths nat (Ot 3) (D (add S 0))))
   (lam Ot D S e1 e2
     (pathscomp0 nat (Ot 3) (Ot 1) (D (add S 0)) (e1 2 (idpath true) (idpath false)) (e2 0 (idpath true) (idpath true)))))
 )
