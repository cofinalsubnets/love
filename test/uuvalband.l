; test/uuvalband.l -- love's `+` and `*` over test/uuval.l's values: (), a number, a link,
; each one of mx.l's kinds; the laws spec.v proves of gval, over veq and over paths
(test (elem 'vof (names ())) (two? (peep GLOB 'vlink 0)))

; --- zsucc and zpred are inverse; the sign crosses at zpred (ii1 0) and zsucc (ii2 0) ---
(test
 (defq uv-zsucc-pred (pi z zed (paths zed (zsucc (zpred z)) z))
   (lam z (coprod_rect (lam w (paths zed (zsucc (zpred w)) w))
             (lam n (nat_rect (lam q (paths zed (zsucc (zpred (ii1 q))) (ii1 q)))
                       (idpath (ii1 0))
                       (lam k (lam r (idpath (ii1 (succ k)))))
                       n))
             (lam n (idpath (ii2 n)))
             z)))
 (defq uv-zpred-succ (pi z zed (paths zed (zpred (zsucc z)) z))
   (lam z (coprod_rect (lam w (paths zed (zpred (zsucc w)) w))
             (lam n (idpath (ii1 n)))
             (lam n (nat_rect (lam q (paths zed (zpred (zsucc (ii2 q))) (ii2 q)))
                       (idpath (ii2 0))
                       (lam k (lam r (idpath (ii2 (succ k)))))
                       n))
             z))))

; --- a step on +'s right argument comes out front, by definitional equations alone ---
(test
 (defq uv-zadd-succ
   (pi a zed (pi b zed (paths zed (zadd a (zsucc b)) (zsucc (zadd a b)))))
   (lam a (lam b
      (coprod_rect (lam w (paths zed (zadd a (zsucc w)) (zsucc (zadd a w))))
         (lam n (idpath (zsucc (zadd a (ii1 n)))))
         (lam n (nat_rect (lam q (paths zed (zadd a (zsucc (ii2 q))) (zsucc (zadd a (ii2 q)))))
                   (pathsinv0 zed (zsucc (zpred a)) a (uv-zsucc-pred a))
                   (lam k (lam r (pathsinv0 zed (zsucc (zpred (zadd a (ii2 k))))
                                                (zadd a (ii2 k))
                                    (uv-zsucc-pred (zadd a (ii2 k))))))
                   n))
         b))))
 (defq uv-zadd-pred
   (pi a zed (pi b zed (paths zed (zadd a (zpred b)) (zpred (zadd a b)))))
   (lam a (lam b
      (coprod_rect (lam w (paths zed (zadd a (zpred w)) (zpred (zadd a w))))
         (lam n (nat_rect (lam q (paths zed (zadd a (zpred (ii1 q))) (zpred (zadd a (ii1 q)))))
                   (idpath (zpred a))
                   (lam k (lam r (pathsinv0 zed (zpred (zsucc (zadd a (ii1 k))))
                                                (zadd a (ii1 k))
                                    (uv-zpred-succ (zadd a (ii1 k))))))
                   n))
         (lam n (idpath (zpred (zadd a (ii2 n)))))
         b)))))

; --- ..and so + associates, by induction on the right argument alone ---
(test
 (defq uv-zadd-assoc
   (pi a zed (pi b zed (pi c zed (paths zed (zadd (zadd a b) c) (zadd a (zadd b c))))))
   (lam a (lam b (lam c
      (coprod_rect (lam w (paths zed (zadd (zadd a b) w) (zadd a (zadd b w))))
         (lam n (nat_rect
                   (lam q (paths zed (zadd (zadd a b) (ii1 q)) (zadd a (zadd b (ii1 q)))))
                   (idpath (zadd a b))
                   (lam k (lam IH (pathscomp0 zed
                             (zsucc (zadd (zadd a b) (ii1 k)))
                             (zsucc (zadd a (zadd b (ii1 k))))
                             (zadd a (zsucc (zadd b (ii1 k))))
                             (maponpaths zed zed (lam x (zsucc x))
                                (zadd (zadd a b) (ii1 k)) (zadd a (zadd b (ii1 k))) IH)
                             (pathsinv0 zed (zadd a (zsucc (zadd b (ii1 k))))
                                            (zsucc (zadd a (zadd b (ii1 k))))
                                (uv-zadd-succ a (zadd b (ii1 k)))))))
                   n))
         (lam n (nat_rect
                   (lam q (paths zed (zadd (zadd a b) (ii2 q)) (zadd a (zadd b (ii2 q)))))
                   (pathsinv0 zed (zadd a (zpred b)) (zpred (zadd a b)) (uv-zadd-pred a b))
                   (lam k (lam IH (pathscomp0 zed
                             (zpred (zadd (zadd a b) (ii2 k)))
                             (zpred (zadd a (zadd b (ii2 k))))
                             (zadd a (zpred (zadd b (ii2 k))))
                             (maponpaths zed zed (lam x (zpred x))
                                (zadd (zadd a b) (ii2 k)) (zadd a (zadd b (ii2 k))) IH)
                             (pathsinv0 zed (zadd a (zpred (zadd b (ii2 k))))
                                            (zpred (zadd a (zadd b (ii2 k))))
                                (uv-zadd-pred a (zadd b (ii2 k)))))))
                   n))
         c)))))
 ; ..and 0 is its unit on both sides; the left takes the associativity's induction
 (defq uv-zadd-runit (pi a zed (paths zed (zadd a zzero) a)) (lam a (idpath a)))
 (defq uv-zadd-lunit (pi b zed (paths zed (zadd zzero b) b))
   (lam b (coprod_rect (lam w (paths zed (zadd zzero w) w))
             (lam n (nat_rect (lam q (paths zed (zadd zzero (ii1 q)) (ii1 q)))
                       (idpath (ii1 0))
                       (lam k (lam IH (maponpaths zed zed (lam x (zsucc x))
                                         (zadd zzero (ii1 k)) (ii1 k) IH)))
                       n))
             (lam n (nat_rect (lam q (paths zed (zadd zzero (ii2 q)) (ii2 q)))
                       (idpath (ii2 0))
                       (lam k (lam IH (maponpaths zed zed (lam x (zpred x))
                                         (zadd zzero (ii2 k)) (ii2 k) IH)))
                       n))
             b))))

; --- a step on the left argument comes out front too: the half bit's carry needs it ---
(test
 (defq uv-zadd-lsucc
   (pi a zed (pi b zed (paths zed (zadd (zsucc a) b) (zsucc (zadd a b)))))
   (lam a (lam b
      (coprod_rect (lam w (paths zed (zadd (zsucc a) w) (zsucc (zadd a w))))
         (lam n (nat_rect (lam q (paths zed (zadd (zsucc a) (ii1 q)) (zsucc (zadd a (ii1 q)))))
                   (idpath (zsucc a))
                   (lam k (lam IH (maponpaths zed zed (lam x (zsucc x))
                                     (zadd (zsucc a) (ii1 k)) (zsucc (zadd a (ii1 k))) IH)))
                   n))
         (lam n (nat_rect (lam q (paths zed (zadd (zsucc a) (ii2 q)) (zsucc (zadd a (ii2 q)))))
                   (pathscomp0 zed (zpred (zsucc a)) a (zsucc (zpred a))
                      (uv-zpred-succ a)
                      (pathsinv0 zed (zsucc (zpred a)) a (uv-zsucc-pred a)))
                   (lam k (lam IH
                      (pathscomp0 zed
                         (zpred (zadd (zsucc a) (ii2 k)))
                         (zadd a (ii2 k))
                         (zsucc (zpred (zadd a (ii2 k))))
                         (pathscomp0 zed
                            (zpred (zadd (zsucc a) (ii2 k)))
                            (zpred (zsucc (zadd a (ii2 k))))
                            (zadd a (ii2 k))
                            (maponpaths zed zed (lam x (zpred x))
                               (zadd (zsucc a) (ii2 k)) (zsucc (zadd a (ii2 k))) IH)
                            (uv-zpred-succ (zadd a (ii2 k))))
                         (pathsinv0 zed (zsucc (zpred (zadd a (ii2 k)))) (zadd a (ii2 k))
                            (uv-zsucc-pred (zadd a (ii2 k)))))))
                   n))
         b)))))

; --- the three integer shapes the carry asks for, named once ---
(test
 (defq uv-zsl
   (pi p zed (pi q zed (pi r zed
      (paths zed (zsucc (zadd (zadd p q) r)) (zadd p (zsucc (zadd q r)))))))
   (lam p (lam q (lam r
      (pathscomp0 zed
         (zsucc (zadd (zadd p q) r))
         (zsucc (zadd p (zadd q r)))
         (zadd p (zsucc (zadd q r)))
         (maponpaths zed zed (lam x (zsucc x))
            (zadd (zadd p q) r) (zadd p (zadd q r)) (uv-zadd-assoc p q r))
         (pathsinv0 zed (zadd p (zsucc (zadd q r))) (zsucc (zadd p (zadd q r)))
            (uv-zadd-succ p (zadd q r))))))))
 (defq uv-zls
   (pi p zed (pi q zed (pi r zed
      (paths zed (zadd (zsucc (zadd p q)) r) (zsucc (zadd p (zadd q r)))))))
   (lam p (lam q (lam r
      (pathscomp0 zed
         (zadd (zsucc (zadd p q)) r)
         (zsucc (zadd (zadd p q) r))
         (zsucc (zadd p (zadd q r)))
         (uv-zadd-lsucc (zadd p q) r)
         (maponpaths zed zed (lam x (zsucc x))
            (zadd (zadd p q) r) (zadd p (zadd q r)) (uv-zadd-assoc p q r)))))))
 (defq uv-zlr
   (pi p zed (pi q zed (pi r zed
      (paths zed (zadd (zsucc (zadd p q)) r) (zadd p (zsucc (zadd q r)))))))
   (lam p (lam q (lam r
      (pathscomp0 zed
         (zadd (zsucc (zadd p q)) r)
         (zsucc (zadd p (zadd q r)))
         (zadd p (zsucc (zadd q r)))
         (uv-zls p q r)
         (pathsinv0 zed (zadd p (zsucc (zadd q r))) (zsucc (zadd p (zadd q r)))
            (uv-zadd-succ p (zadd q r)))))))))

; --- ..and the half-integers associate: eight cases on the three half bits ---
(test
 (defn uv-rac (pi p zed (pi x bool (pi q zed (pi y bool (pi r zed (pi z bool UU))))))
   (lam p (lam x (lam q (lam y (lam r (lam z
      (paths rea (radd (radd (rmk p x) (rmk q y)) (rmk r z))
                 (radd (rmk p x) (radd (rmk q y) (rmk r z)))))))))))
 (defq uv-radd-assoc-c
   (pi p zed (pi x bool (pi q zed (pi y bool (pi r zed (pi z bool (uv-rac p x q y r z)))))))
   (lam p (lam x (lam q (lam y (lam r (lam z
      (bool_rect (lam X (uv-rac p X q y r z))
         ; x = true
         (bool_rect (lam Y (uv-rac p true q Y r z))
            ; x,y = true,true -- the carry has already fired on the left
            (bool_rect (lam Z (uv-rac p true q true r Z))
               (uv-pairpath zed bool (zadd (zsucc (zadd p q)) r) (zadd p (zsucc (zadd q r)))
                  true true (uv-zlr p q r) (idpath true))
               (uv-pairpath zed bool (zadd (zsucc (zadd p q)) r) (zsucc (zadd p (zadd q r)))
                  false false (uv-zls p q r) (idpath false))
               z)
            (bool_rect (lam Z (uv-rac p true q false r Z))
               (uv-pairpath zed bool (zsucc (zadd (zadd p q) r)) (zsucc (zadd p (zadd q r)))
                  false false
                  (maponpaths zed zed (lam w (zsucc w))
                     (zadd (zadd p q) r) (zadd p (zadd q r)) (uv-zadd-assoc p q r))
                  (idpath false))
               (uv-pairpath zed bool (zadd (zadd p q) r) (zadd p (zadd q r))
                  true true (uv-zadd-assoc p q r) (idpath true))
               z)
            y)
         ; x = false
         (bool_rect (lam Y (uv-rac p false q Y r z))
            (bool_rect (lam Z (uv-rac p false q true r Z))
               (uv-pairpath zed bool (zsucc (zadd (zadd p q) r)) (zadd p (zsucc (zadd q r)))
                  false false (uv-zsl p q r) (idpath false))
               (uv-pairpath zed bool (zadd (zadd p q) r) (zadd p (zadd q r))
                  true true (uv-zadd-assoc p q r) (idpath true))
               z)
            (bool_rect (lam Z (uv-rac p false q false r Z))
               (uv-pairpath zed bool (zadd (zadd p q) r) (zadd p (zadd q r))
                  true true (uv-zadd-assoc p q r) (idpath true))
               (uv-pairpath zed bool (zadd (zadd p q) r) (zadd p (zadd q r))
                  false false (uv-zadd-assoc p q r) (idpath false))
               z)
            y)
         x))))))))
 (defq uv-radd-assoc
   (pi a rea (pi b rea (pi c rea (paths rea (radd (radd a b) c) (radd a (radd b c))))))
   (lam a (lam b (lam c
      (uv-radd-assoc-c (pr1 a) (pr2 a) (pr1 b) (pr2 b) (pr1 c) (pr2 c))))))
 ; ..and so do the measures, component by component
 (defq uv-madd-assoc
   (pi a msr (pi b msr (pi c msr (paths msr (madd (madd a b) c) (madd a (madd b c))))))
   (lam a (lam b (lam c
      (uv-pairpath rea rea
         (radd (radd (pr1 a) (pr1 b)) (pr1 c)) (radd (pr1 a) (radd (pr1 b) (pr1 c)))
         (radd (radd (pr2 a) (pr2 b)) (pr2 c)) (radd (pr2 a) (radd (pr2 b) (pr2 c)))
         (uv-radd-assoc (pr1 a) (pr1 b) (pr1 c))
         (uv-radd-assoc (pr2 a) (pr2 b) (pr2 c)))))))
 ; ..and 0 a unit on both sides of both; the case is for the half bit: (orb h false) is
 ; stuck on a neutral h where (orb false h) is not
 (defq uv-radd-runit (pi a rea (paths rea (radd a rzero) a))
   (lam a (bool_rect (lam X (paths rea (radd (rmk (pr1 a) X) rzero) (rmk (pr1 a) X)))
             (idpath (rmk (pr1 a) true)) (idpath (rmk (pr1 a) false)) (pr2 a))))
 (defq uv-radd-lunit (pi a rea (paths rea (radd rzero a) a))
   (lam a (uv-pairpath zed bool (zadd zzero (pr1 a)) (pr1 a) (pr2 a) (pr2 a)
             (uv-zadd-lunit (pr1 a)) (idpath (pr2 a)))))
 (defq uv-madd-runit (pi a msr (paths msr (madd a mzero) a))
   (lam a (uv-pairpath rea rea (radd (pr1 a) rzero) (pr1 a) (radd (pr2 a) rzero) (pr2 a)
             (uv-radd-runit (pr1 a)) (uv-radd-runit (pr2 a)))))
 (defq uv-madd-lunit (pi a msr (paths msr (madd mzero a) a))
   (lam a (uv-pairpath rea rea (radd rzero (pr1 a)) (pr1 a) (radd rzero (pr2 a)) (pr2 a)
             (uv-radd-lunit (pr1 a)) (uv-radd-lunit (pr2 a))))))

; --- the band: the three shapes the model carries, codes named against src/love/mx.l's
; --- own so they cannot drift. () the mint band, a number the numeric, a link the chain ---
(test
 (defn bUnit nat 0)
 (defn bNum  nat 1)
 (defn bSeq  nat 2)
 (defn aband (pi a atm nat)
   (lam a (coprod_rect (lam w nat) (lam u bUnit) (lam m bNum) a)))
 (defn vband (pi v val nat)
   (lam v (bool_rect (lam x nat) bSeq (aband (vleaf v)) (vtwo v))))
 (vof 0 '0 = vof 0 '(vband vnilv))
 (vof 0 '1 = vof 0 '(vband (nval 3)))
 (vof 0 '2 = vof 0 '(vband (vlink (nval 1) (nval 2)))))

; --- + cell for cell as love answers. a mixed band degenerates (the chain answers whole),
; --- buying associativity with no side conditions; append replaces the left spine's tail ---
(test
 (defn vappd (pi d nat (pi t (vtre d) (pi w val val)))
   (lam d (nat_rect (lam q (pi t (vtre q) (pi w val val)))
             (lam t (lam w w))
             (lam k (lam IH (lam t (lam w
                (coprod_rect (lam z val)
                   (lam m w)
                   (lam p (vlink (tpair k (vfst k p)) (IH (vsnd k p) w)))
                   t)))))
             d)))
 (defn vapp (pi u val (pi w val val)) (lam u (lam w (vappd (pr1 u) (pr2 u) w))))
 ; the lane a pair of bands takes, in mx.l's own vocabulary
 (defn vlane (pi i nat (pi j nat nat))
   (lam i (lam j (bool_rect (lam x nat)
                    mxLbin_unit
                    (bool_rect (lam y nat)
                       mxLbin_unit
                       (bool_rect (lam z nat)
                          (bool_rect (lam w nat) mxLaddn mxLbin_a (nateqb i bNum))
                          (bool_rect (lam w nat) mxLbin_b mxLadd_seq (nateqb i bNum))
                          (nateqb j bNum))
                       (nateqb j bUnit))
                    (nateqb i bUnit)))))
 (defn vadd (pi u val (pi w val val))
   (lam u (lam w (bool_rect (lam x val)
                    w
                    (bool_rect (lam y val)
                       u
                       (bool_rect (lam z val)
                          (bool_rect (lam q val)
                             (vnum (madd (vnet u) (vnet w)))       ; num + num
                             u                                     ; seq + num degenerates
                             (nateqb (vband u) bNum))
                          (bool_rect (lam q val)
                             w                                     ; num + seq degenerates
                             (vapp u w)                            ; seq + seq appends
                             (nateqb (vband u) bNum))
                          (nateqb (vband w) bNum))
                       (nateqb (vband w) bUnit))
                    (nateqb (vband u) bUnit)))))
 ; the corpus love answers, answered here
 (vof 0 'true = vof 0 '(veq (vadd vnilv (nval 3)) (nval 3)))
 (vof 0 'true = vof 0 '(veq (vadd (nval 3) vnilv) (nval 3)))
 (vof 0 'true = vof 0 '(veq (vadd (nval 2) (nval 3)) (nval 5)))
 (vof 0 'true = vof 0 '(veq (vadd (nval 5) (vlink (nval 1) (nval 2)))
                            (vlink (nval 1) (nval 2))))
 (vof 0 'true = vof 0 '(veq (vadd (vlink (nval 1) (nval 2)) (nval 5))
                            (vlink (nval 1) (nval 2))))
 ; '(1) + '(2) = '(1 2): the left spine ends in (), and the right takes its place
 (vof 0 'true = vof 0 '(veq (vadd (vlink (nval 1) vnilv) (vlink (nval 2) vnilv))
                            (vlink (nval 1) (vlink (nval 2) vnilv))))
 ; ..and a dotted tail is replaced, not kept, as love answers
 (vof 0 'true = vof 0 '(veq (vadd (vlink (nval 1) (nval 2)) (vlink (nval 3) vnilv))
                            (vlink (nval 1) (vlink (nval 3) vnilv)))))

; --- append associates, modulo veq: appending on the left pads what appending on the right
; --- does not; the pad is invisible to append, and veq's transitivity composes the three ---
(test
 (defq uv-vapp-padl
   (pi a nat (pi b nat (pi t (vtre a) (pi w val
      (paths bool (veq (vappd (mx2 a b) (padl a b t) w) (vappd a t w)) true)))))
   (lam a (nat_rect
             (lam q (pi b nat (pi t (vtre q) (pi w val
                       (paths bool (veq (vappd (mx2 q b) (padl q b t) w)
                                        (vappd q t w)) true)))))
             (lam b (lam t (lam w
                (nat_rect (lam r (paths bool
                             (veq (vappd (mx2 0 r) (padl 0 r t) w) (vappd 0 t w)) true))
                   (uv-veq-refl w)
                   (lam k (lam sk (uv-veq-refl w)))
                   b))))
             (lam j (lam IH (lam b
                (nat_rect (lam r (pi t (vtre (succ j)) (pi w val
                             (paths bool (veq (vappd (mx2 (succ j) r) (padl (succ j) r t) w)
                                              (vappd (succ j) t w)) true))))
                   (lam t (lam w (uv-veq-refl (vappd (succ j) t w))))
                   (lam k (lam sk (lam t (lam w
                      (coprod_rect (lam z (paths bool
                                     (veq (vappd (succ (mx2 j k)) (padl (succ j) (succ k) z) w)
                                          (vappd (succ j) z w)) true))
                         (lam m (uv-veq-refl w))
                         (lam pp (uv-veq-link
                                    (tpair (mx2 j k) (padl j k (vfst j pp)))
                                    (vappd (mx2 j k) (padl j k (vsnd j pp)) w)
                                    (tpair j (vfst j pp))
                                    (vappd j (vsnd j pp) w)
                                    (uv-padl-bwd j k (vfst j pp))
                                    (IH k (vsnd j pp) w)))
                         t)))))
                   b))))
             a)))
 (defq uv-vapp-padr
   (pi a nat (pi b nat (pi t (vtre b) (pi w val
      (paths bool (veq (vappd (mx2 a b) (padr a b t) w) (vappd b t w)) true)))))
   (lam a (nat_rect
             (lam q (pi b nat (pi t (vtre b) (pi w val
                       (paths bool (veq (vappd (mx2 q b) (padr q b t) w)
                                        (vappd b t w)) true)))))
             (lam b (lam t (lam w (uv-veq-refl (vappd b t w)))))
             (lam j (lam IH (lam b
                (nat_rect (lam r (pi t (vtre r) (pi w val
                             (paths bool (veq (vappd (mx2 (succ j) r) (padr (succ j) r t) w)
                                              (vappd r t w)) true))))
                   (lam t (lam w (uv-veq-refl w)))
                   (lam k (lam sk (lam t (lam w
                      (coprod_rect (lam z (paths bool
                                     (veq (vappd (succ (mx2 j k)) (padr (succ j) (succ k) z) w)
                                          (vappd (succ k) z w)) true))
                         (lam m (uv-veq-refl w))
                         (lam pp (uv-veq-link
                                    (tpair (mx2 j k) (padr j k (vfst k pp)))
                                    (vappd (mx2 j k) (padr j k (vsnd k pp)) w)
                                    (tpair k (vfst k pp))
                                    (vappd k (vsnd k pp) w)
                                    (uv-padr-bwd j k (vfst k pp))
                                    (IH k (vsnd k pp) w)))
                         t)))))
                   b))))
             a)))
 ; ..and so append associates: the bracketings differ only in the middle result's height
 (defq uv-vapp-assoc
   (pi d nat (pi t (vtre d) (pi v val (pi w val
      (paths bool (veq (vapp (vappd d t v) w) (vappd d t (vapp v w))) true)))))
   (lam d (nat_rect
             (lam q (pi t (vtre q) (pi v val (pi w val
                       (paths bool (veq (vapp (vappd q t v) w)
                                        (vappd q t (vapp v w))) true)))))
             (lam t (lam v (lam w (uv-veq-refl (vapp v w)))))
             (lam k (lam IH (lam t
                (coprod_rect (lam z (pi v val (pi w val
                               (paths bool (veq (vapp (vappd (succ k) z v) w)
                                                (vappd (succ k) z (vapp v w))) true))))
                   (lam m (lam v (lam w (uv-veq-refl (vapp v w)))))
                   (lam p (lam v (lam w
                      (uv-veq-link
                         (tpair (mx2 k (pr1 (vappd k (vsnd k p) v)))
                                (padl k (pr1 (vappd k (vsnd k p) v)) (vfst k p)))
                         (vappd (mx2 k (pr1 (vappd k (vsnd k p) v)))
                                (padr k (pr1 (vappd k (vsnd k p) v))
                                      (pr2 (vappd k (vsnd k p) v))) w)
                         (tpair k (vfst k p))
                         (vappd k (vsnd k p) (vapp v w))
                         (uv-padl-bwd k (pr1 (vappd k (vsnd k p) v)) (vfst k p))
                         (uv-veq-trans
                            (vappd (mx2 k (pr1 (vappd k (vsnd k p) v)))
                                   (padr k (pr1 (vappd k (vsnd k p) v))
                                         (pr2 (vappd k (vsnd k p) v))) w)
                            (vapp (vappd k (vsnd k p) v) w)
                            (vappd k (vsnd k p) (vapp v w))
                            (uv-vapp-padr k (pr1 (vappd k (vsnd k p) v))
                                            (pr2 (vappd k (vsnd k p) v)) w)
                            (IH (vsnd k p) v w))))))
                   t))))
             d))))

; --- the bridge: vadd's cell is the lane mx.l's `+` matrix dispatches to, all nine pairs,
; --- so a dispatch edit moving a lane under this model fails a proof ---
(test
 (defn mxkof (pi i nat nat)
   (lam i (bool_rect (lam x nat) mxKMint
             (bool_rect (lam y nat) mxKCharm mxKChain (nateqb i bNum))
             (nateqb i bUnit))))
 (defq uv-band-is-mx
   (paths bool
     (mxall 3 (lam i (mxall 3 (lam j (nateqb (mxadd (mxkof i) (mxkof j)) (vlane i j))))))
     true)
   (idpath true))
 ; the model's number is a numeric kind, the band test/uukindlaw.l ranks within
 (defq uv-bnum-is-numeric (paths nat (mxband (mxkof bNum)) (mxband mxKGem))
   (idpath (mxband mxKGem)))
 ; ..and the three kinds are distinct kinds, so the nine pairs are nine cells
 (defq uv-bands-apart
   (paths bool (andb (negb (nateqb (mxkof bUnit) (mxkof bNum)))
                     (andb (negb (nateqb (mxkof bNum) (mxkof bSeq)))
                           (negb (nateqb (mxkof bUnit) (mxkof bSeq)))))
     true)
   (idpath true)))

; --- the laws + owes, each stated over its cell's shape, not a band code: a neutral code
; --- tells conv nothing, a tree with a head reduces the dispatch ---
(test
 (defq uv-vadd-lunit (pi v val (paths val (vadd vnilv v) v)) (lam v (idpath v)))
 ; the right unit is a veq law: () + () answers the right's (), at height 0 where the left may not be
 (defq uv-vadd-runit (pi v val (paths bool (veq (vadd v vnilv) v) true))
   (lam v ((nat_rect
              (lam d (pi t (vtre d) (paths bool (veq (vadd (tpair d t) vnilv) (tpair d t))
                                                true)))
              (lam t (coprod_rect
                        (lam w (paths bool (veq (vadd (tpair 0 w) vnilv) (tpair 0 w)) true))
                        (lam u (unit_rect
                                  (lam y (paths bool (veq (vadd (tpair 0 (ii1 y)) vnilv)
                                                          (tpair 0 (ii1 y))) true))
                                  (uv-veq-refl vnilv) u))
                        (lam m (uv-veq-refl (tpair 0 (ii2 m))))
                        t))
              (lam k (lam IH (lam t
                 (coprod_rect
                    (lam w (paths bool (veq (vadd (tpair (succ k) w) vnilv)
                                            (tpair (succ k) w)) true))
                    (lam a (coprod_rect
                              (lam y (paths bool (veq (vadd (tpair (succ k) (ii1 y)) vnilv)
                                                      (tpair (succ k) (ii1 y))) true))
                              (lam u (unit_rect
                                        (lam y (paths bool
                                                  (veq (vadd (tpair (succ k) (ii1 (ii1 y)))
                                                             vnilv)
                                                       (tpair (succ k) (ii1 (ii1 y)))) true))
                                        (idpath true) u))
                              (lam m (uv-veq-refl (tpair (succ k) (ii1 (ii2 m)))))
                              a))
                    (lam p (uv-veq-refl (tpair (succ k) (ii2 p))))
                    t))))
              (pr1 v)) (pr2 v))))
 ; numbers add, by the measure's own monoid
 (defq uv-vadd-num (pi a msr (pi b msr (paths val (vadd (vnum a) (vnum b)) (vnum (madd a b)))))
   (lam a (lam b (idpath (vnum (madd a b))))))
 (defq uv-vadd-num-assoc
   (pi a msr (pi b msr (pi c msr
      (paths val (vadd (vadd (vnum a) (vnum b)) (vnum c))
                 (vadd (vnum a) (vadd (vnum b) (vnum c)))))))
   (lam a (lam b (lam c
      (maponpaths msr val (lam w (vnum w))
         (madd (madd a b) c) (madd a (madd b c)) (uv-madd-assoc a b c))))))
 ; a mixed band degenerates: the chain answers whole and the number is gone
 (defq uv-vadd-degen-l
   (pi m msr (pi a val (pi b val (paths val (vadd (vnum m) (vlink a b)) (vlink a b)))))
   (lam m (lam a (lam b (idpath (vlink a b))))))
 (defq uv-vadd-degen-r
   (pi m msr (pi a val (pi b val (paths val (vadd (vlink a b) (vnum m)) (vlink a b)))))
   (lam m (lam a (lam b (idpath (vlink a b))))))
 ; ..and the net sees it go: why + associates with no side conditions, and is not a hom
 (defq uv-vadd-degen-net
   (pi m msr (pi a val (pi b val
      (paths msr (vnet (vadd (vnum m) (vlink a b))) (vnet (vlink a b))))))
   (lam m (lam a (lam b (idpath (vnet (vlink a b)))))))
 ; chains append
 (defq uv-vadd-seq
   (pi a val (pi b val (pi c val (pi d val
      (paths val (vadd (vlink a b) (vlink c d)) (vapp (vlink a b) (vlink c d)))))))
   (lam a (lam b (lam c (lam d (idpath (vapp (vlink a b) (vlink c d)))))))))

; --- + associates over all twenty-seven cells, standing in for spec.v's destruct x, y, z;
; --- all but the numeric and chain cells are one reflexivity, bought by the degeneration ---
(test
 (defn uv-aa (pi u val (pi v val (pi w val UU)))
   (lam u (lam v (lam w
      (paths bool (veq (vadd (vadd u v) w) (vadd u (vadd v w))) true)))))
 (defq uv-aa-uuu
   (uv-aa vnilv vnilv vnilv)
   (uv-veq-refl vnilv))
 (defq uv-aa-uun
   (pi c msr (uv-aa vnilv vnilv (vnum c)))
   (lam c (uv-veq-refl (vnum c))))
 (defq uv-aa-uus
   (pi e val (pi f val (uv-aa vnilv vnilv (vlink e f))))
   (lam e (lam f (uv-veq-refl (vlink e f)))))
 (defq uv-aa-unu
   (pi b msr (uv-aa vnilv (vnum b) vnilv))
   (lam b (uv-veq-refl (vnum b))))
 (defq uv-aa-unn
   (pi b msr (pi c msr (uv-aa vnilv (vnum b) (vnum c))))
   (lam b (lam c (uv-veq-refl (vnum (madd b c))))))
 (defq uv-aa-uns
   (pi b msr (pi e val (pi f val (uv-aa vnilv (vnum b) (vlink e f)))))
   (lam b (lam e (lam f (uv-veq-refl (vlink e f))))))
 (defq uv-aa-usu
   (pi c val (pi d val (uv-aa vnilv (vlink c d) vnilv)))
   (lam c (lam d (uv-veq-refl (vlink c d)))))
 (defq uv-aa-usn
   (pi c val (pi d val (pi e msr (uv-aa vnilv (vlink c d) (vnum e)))))
   (lam c (lam d (lam e (uv-veq-refl (vlink c d))))))
 (defq uv-aa-uss
   (pi c val (pi d val (pi e val (pi f val (uv-aa vnilv (vlink c d) (vlink e f))))))
   (lam c (lam d (lam e (lam f (uv-veq-refl (vapp (vlink c d) (vlink e f))))))))
 (defq uv-aa-nuu
   (pi a msr (uv-aa (vnum a) vnilv vnilv))
   (lam a (uv-veq-refl (vnum a))))
 (defq uv-aa-nun
   (pi a msr (pi c msr (uv-aa (vnum a) vnilv (vnum c))))
   (lam a (lam c (uv-veq-refl (vnum (madd a c))))))
 (defq uv-aa-nus
   (pi a msr (pi e val (pi f val (uv-aa (vnum a) vnilv (vlink e f)))))
   (lam a (lam e (lam f (uv-veq-refl (vlink e f))))))
 (defq uv-aa-nnu
   (pi a msr (pi b msr (uv-aa (vnum a) (vnum b) vnilv)))
   (lam a (lam b (uv-veq-refl (vnum (madd a b))))))
 (defq uv-aa-nnn
   (pi a msr (pi b msr (pi c msr (uv-aa (vnum a) (vnum b) (vnum c)))))
   (lam a (lam b (lam c
      (uv-veq-of (vnum (madd (madd a b) c)) (vnum (madd a (madd b c)))
         (maponpaths msr val (lam x (vnum x))
            (madd (madd a b) c) (madd a (madd b c)) (uv-madd-assoc a b c)))))))
 (defq uv-aa-nns
   (pi a msr (pi b msr (pi e val (pi f val (uv-aa (vnum a) (vnum b) (vlink e f))))))
   (lam a (lam b (lam e (lam f (uv-veq-refl (vlink e f)))))))
 (defq uv-aa-nsu
   (pi a msr (pi c val (pi d val (uv-aa (vnum a) (vlink c d) vnilv))))
   (lam a (lam c (lam d (uv-veq-refl (vlink c d))))))
 (defq uv-aa-nsn
   (pi a msr (pi c val (pi d val (pi e msr (uv-aa (vnum a) (vlink c d) (vnum e))))))
   (lam a (lam c (lam d (lam e (uv-veq-refl (vlink c d)))))))
 (defq uv-aa-nss
   (pi a msr (pi c val (pi d val (pi e val (pi f val (uv-aa (vnum a) (vlink c d) (vlink e f)))))))
   (lam a (lam c (lam d (lam e (lam f (uv-veq-refl (vapp (vlink c d) (vlink e f)))))))))
 (defq uv-aa-suu
   (pi a val (pi b val (uv-aa (vlink a b) vnilv vnilv)))
   (lam a (lam b (uv-veq-refl (vlink a b)))))
 (defq uv-aa-sun
   (pi a val (pi b val (pi e msr (uv-aa (vlink a b) vnilv (vnum e)))))
   (lam a (lam b (lam e (uv-veq-refl (vlink a b))))))
 (defq uv-aa-sus
   (pi a val (pi b val (pi e val (pi f val (uv-aa (vlink a b) vnilv (vlink e f))))))
   (lam a (lam b (lam e (lam f (uv-veq-refl (vapp (vlink a b) (vlink e f))))))))
 (defq uv-aa-snu
   (pi a val (pi b val (pi c msr (uv-aa (vlink a b) (vnum c) vnilv))))
   (lam a (lam b (lam c (uv-veq-refl (vlink a b))))))
 (defq uv-aa-snn
   (pi a val (pi b val (pi c msr (pi e msr (uv-aa (vlink a b) (vnum c) (vnum e))))))
   (lam a (lam b (lam c (lam e (uv-veq-refl (vlink a b)))))))
 (defq uv-aa-sns
   (pi a val (pi b val (pi c msr (pi e val (pi f val (uv-aa (vlink a b) (vnum c) (vlink e f)))))))
   (lam a (lam b (lam c (lam e (lam f (uv-veq-refl (vapp (vlink a b) (vlink e f)))))))))
 (defq uv-aa-ssu
   (pi a val (pi b val (pi c val (pi d val (uv-aa (vlink a b) (vlink c d) vnilv)))))
   (lam a (lam b (lam c (lam d (uv-veq-refl (vapp (vlink a b) (vlink c d))))))))
 (defq uv-aa-ssn
   (pi a val (pi b val (pi c val (pi d val (pi e msr (uv-aa (vlink a b) (vlink c d) (vnum e)))))))
   (lam a (lam b (lam c (lam d (lam e (uv-veq-refl (vapp (vlink a b) (vlink c d)))))))))
 (defq uv-aa-sss
   (pi a val (pi b val (pi c val (pi d val (pi e val (pi f val (uv-aa (vlink a b) (vlink c d) (vlink e f))))))))
   (lam a (lam b (lam c (lam d (lam e (lam f
      (uv-vapp-assoc (pr1 (vlink a b)) (pr2 (vlink a b)) (vlink c d) (vlink e f))))))))))

; --- and over paths, each cell crossing the bridge at its own shape: a generic crossing over
; --- three neutrals carries the whole unreduced dispatch, and conv pays for it twice ---
(test
 (defn uv-paa (pi u val (pi v val (pi w val UU)))
   (lam u (lam v (lam w
      (paths pval (pin (vadd (vadd u v) w)) (pin (vadd u (vadd v w))))))))
 (defq uv-paa-uuu
   (uv-paa vnilv vnilv vnilv)
   (uv-veq-paths (vadd (vadd vnilv vnilv) vnilv) (vadd vnilv (vadd vnilv vnilv))
      uv-aa-uuu))
 (defq uv-paa-uun
   (pi c msr (uv-paa vnilv vnilv (vnum c)))
   (lam c (uv-veq-paths (vadd (vadd vnilv vnilv) (vnum c)) (vadd vnilv (vadd vnilv (vnum c)))
      (uv-aa-uun c))))
 (defq uv-paa-uus
   (pi e val (pi f val (uv-paa vnilv vnilv (vlink e f))))
   (lam e (lam f (uv-veq-paths (vadd (vadd vnilv vnilv) (vlink e f)) (vadd vnilv (vadd vnilv (vlink e f)))
      (uv-aa-uus e f)))))
 (defq uv-paa-unu
   (pi b msr (uv-paa vnilv (vnum b) vnilv))
   (lam b (uv-veq-paths (vadd (vadd vnilv (vnum b)) vnilv) (vadd vnilv (vadd (vnum b) vnilv))
      (uv-aa-unu b))))
 (defq uv-paa-unn
   (pi b msr (pi c msr (uv-paa vnilv (vnum b) (vnum c))))
   (lam b (lam c (uv-veq-paths (vadd (vadd vnilv (vnum b)) (vnum c)) (vadd vnilv (vadd (vnum b) (vnum c)))
      (uv-aa-unn b c)))))
 (defq uv-paa-uns
   (pi b msr (pi e val (pi f val (uv-paa vnilv (vnum b) (vlink e f)))))
   (lam b (lam e (lam f (uv-veq-paths (vadd (vadd vnilv (vnum b)) (vlink e f)) (vadd vnilv (vadd (vnum b) (vlink e f)))
      (uv-aa-uns b e f))))))
 (defq uv-paa-usu
   (pi c val (pi d val (uv-paa vnilv (vlink c d) vnilv)))
   (lam c (lam d (uv-veq-paths (vadd (vadd vnilv (vlink c d)) vnilv) (vadd vnilv (vadd (vlink c d) vnilv))
      (uv-aa-usu c d)))))
 (defq uv-paa-usn
   (pi c val (pi d val (pi e msr (uv-paa vnilv (vlink c d) (vnum e)))))
   (lam c (lam d (lam e (uv-veq-paths (vadd (vadd vnilv (vlink c d)) (vnum e)) (vadd vnilv (vadd (vlink c d) (vnum e)))
      (uv-aa-usn c d e))))))
 (defq uv-paa-uss
   (pi c val (pi d val (pi e val (pi f val (uv-paa vnilv (vlink c d) (vlink e f))))))
   (lam c (lam d (lam e (lam f (uv-veq-paths (vadd (vadd vnilv (vlink c d)) (vlink e f)) (vadd vnilv (vadd (vlink c d) (vlink e f)))
      (uv-aa-uss c d e f)))))))
 (defq uv-paa-nuu
   (pi a msr (uv-paa (vnum a) vnilv vnilv))
   (lam a (uv-veq-paths (vadd (vadd (vnum a) vnilv) vnilv) (vadd (vnum a) (vadd vnilv vnilv))
      (uv-aa-nuu a))))
 (defq uv-paa-nun
   (pi a msr (pi c msr (uv-paa (vnum a) vnilv (vnum c))))
   (lam a (lam c (uv-veq-paths (vadd (vadd (vnum a) vnilv) (vnum c)) (vadd (vnum a) (vadd vnilv (vnum c)))
      (uv-aa-nun a c)))))
 (defq uv-paa-nus
   (pi a msr (pi e val (pi f val (uv-paa (vnum a) vnilv (vlink e f)))))
   (lam a (lam e (lam f (uv-veq-paths (vadd (vadd (vnum a) vnilv) (vlink e f)) (vadd (vnum a) (vadd vnilv (vlink e f)))
      (uv-aa-nus a e f))))))
 (defq uv-paa-nnu
   (pi a msr (pi b msr (uv-paa (vnum a) (vnum b) vnilv)))
   (lam a (lam b (uv-veq-paths (vadd (vadd (vnum a) (vnum b)) vnilv) (vadd (vnum a) (vadd (vnum b) vnilv))
      (uv-aa-nnu a b)))))
 (defq uv-paa-nnn
   (pi a msr (pi b msr (pi c msr (uv-paa (vnum a) (vnum b) (vnum c)))))
   (lam a (lam b (lam c (uv-veq-paths (vadd (vadd (vnum a) (vnum b)) (vnum c)) (vadd (vnum a) (vadd (vnum b) (vnum c)))
      (uv-aa-nnn a b c))))))
 (defq uv-paa-nns
   (pi a msr (pi b msr (pi e val (pi f val (uv-paa (vnum a) (vnum b) (vlink e f))))))
   (lam a (lam b (lam e (lam f (uv-veq-paths (vadd (vadd (vnum a) (vnum b)) (vlink e f)) (vadd (vnum a) (vadd (vnum b) (vlink e f)))
      (uv-aa-nns a b e f)))))))
 (defq uv-paa-nsu
   (pi a msr (pi c val (pi d val (uv-paa (vnum a) (vlink c d) vnilv))))
   (lam a (lam c (lam d (uv-veq-paths (vadd (vadd (vnum a) (vlink c d)) vnilv) (vadd (vnum a) (vadd (vlink c d) vnilv))
      (uv-aa-nsu a c d))))))
 (defq uv-paa-nsn
   (pi a msr (pi c val (pi d val (pi e msr (uv-paa (vnum a) (vlink c d) (vnum e))))))
   (lam a (lam c (lam d (lam e (uv-veq-paths (vadd (vadd (vnum a) (vlink c d)) (vnum e)) (vadd (vnum a) (vadd (vlink c d) (vnum e)))
      (uv-aa-nsn a c d e)))))))
 (defq uv-paa-nss
   (pi a msr (pi c val (pi d val (pi e val (pi f val (uv-paa (vnum a) (vlink c d) (vlink e f)))))))
   (lam a (lam c (lam d (lam e (lam f (uv-veq-paths (vadd (vadd (vnum a) (vlink c d)) (vlink e f)) (vadd (vnum a) (vadd (vlink c d) (vlink e f)))
      (uv-aa-nss a c d e f))))))))
 (defq uv-paa-suu
   (pi a val (pi b val (uv-paa (vlink a b) vnilv vnilv)))
   (lam a (lam b (uv-veq-paths (vadd (vadd (vlink a b) vnilv) vnilv) (vadd (vlink a b) (vadd vnilv vnilv))
      (uv-aa-suu a b)))))
 (defq uv-paa-sun
   (pi a val (pi b val (pi e msr (uv-paa (vlink a b) vnilv (vnum e)))))
   (lam a (lam b (lam e (uv-veq-paths (vadd (vadd (vlink a b) vnilv) (vnum e)) (vadd (vlink a b) (vadd vnilv (vnum e)))
      (uv-aa-sun a b e))))))
 (defq uv-paa-sus
   (pi a val (pi b val (pi e val (pi f val (uv-paa (vlink a b) vnilv (vlink e f))))))
   (lam a (lam b (lam e (lam f (uv-veq-paths (vadd (vadd (vlink a b) vnilv) (vlink e f)) (vadd (vlink a b) (vadd vnilv (vlink e f)))
      (uv-aa-sus a b e f)))))))
 (defq uv-paa-snu
   (pi a val (pi b val (pi c msr (uv-paa (vlink a b) (vnum c) vnilv))))
   (lam a (lam b (lam c (uv-veq-paths (vadd (vadd (vlink a b) (vnum c)) vnilv) (vadd (vlink a b) (vadd (vnum c) vnilv))
      (uv-aa-snu a b c))))))
 (defq uv-paa-snn
   (pi a val (pi b val (pi c msr (pi e msr (uv-paa (vlink a b) (vnum c) (vnum e))))))
   (lam a (lam b (lam c (lam e (uv-veq-paths (vadd (vadd (vlink a b) (vnum c)) (vnum e)) (vadd (vlink a b) (vadd (vnum c) (vnum e)))
      (uv-aa-snn a b c e)))))))
 (defq uv-paa-sns
   (pi a val (pi b val (pi c msr (pi e val (pi f val (uv-paa (vlink a b) (vnum c) (vlink e f)))))))
   (lam a (lam b (lam c (lam e (lam f (uv-veq-paths (vadd (vadd (vlink a b) (vnum c)) (vlink e f)) (vadd (vlink a b) (vadd (vnum c) (vlink e f)))
      (uv-aa-sns a b c e f))))))))
 (defq uv-paa-ssu
   (pi a val (pi b val (pi c val (pi d val (uv-paa (vlink a b) (vlink c d) vnilv)))))
   (lam a (lam b (lam c (lam d (uv-veq-paths (vadd (vadd (vlink a b) (vlink c d)) vnilv) (vadd (vlink a b) (vadd (vlink c d) vnilv))
      (uv-aa-ssu a b c d)))))))
 (defq uv-paa-ssn
   (pi a val (pi b val (pi c val (pi d val (pi e msr (uv-paa (vlink a b) (vlink c d) (vnum e)))))))
   (lam a (lam b (lam c (lam d (lam e (uv-veq-paths (vadd (vadd (vlink a b) (vlink c d)) (vnum e)) (vadd (vlink a b) (vadd (vlink c d) (vnum e)))
      (uv-aa-ssn a b c d e))))))))
 (defq uv-paa-sss
   (pi a val (pi b val (pi c val (pi d val (pi e val (pi f val (uv-paa (vlink a b) (vlink c d) (vlink e f))))))))
   (lam a (lam b (lam c (lam d (lam e (lam f (uv-veq-paths (vadd (vadd (vlink a b) (vlink c d)) (vlink e f)) (vadd (vlink a b) (vadd (vlink c d) (vlink e f)))
      (uv-aa-sss a b c d e f)))))))))
 ; the right unit and append's law cross the same way; over paths both () spellings pin to
 ; pnilv, so the right unit's veq caveat is gone
 (defq uv-pvadd-runit (pi v val (paths pval (pin (vadd v vnilv)) (pin v)))
   (lam v (uv-veq-paths (vadd v vnilv) v (uv-vadd-runit v))))
 (defq uv-pvapp-assoc
   (pi d nat (pi t (vtre d) (pi v val (pi w val
      (paths pval (pin (vapp (vappd d t v) w)) (pin (vappd d t (vapp v w))))))))
   (lam d (lam t (lam v (lam w (uv-veq-paths (vapp (vappd d t v) w)
                                             (vappd d t (vapp v w))
                                  (uv-vapp-assoc d t v w))))))))

; --- * over the same carrier, at the integer rung: the halves are not closed under *, so
; --- off a whole measure `*` leaves the carrier and the model does not follow ---
(test
 (defn znegof (pi n nat zed)
   (lam n (nat_rect (lam q zed) (ii1 0) (lam k (lam r (ii2 k))) n)))
 (defn zabs (pi z zed nat)
   (lam z (coprod_rect (lam w nat) (lam n n) (lam n (succ n)) z)))
 (defn zmul (pi a zed (pi b zed zed))
   (lam a (lam b (coprod_rect (lam w zed)
      (lam p (coprod_rect (lam w zed)
                (lam q (ii1 (mul p q)))
                (lam q (znegof (mul p (succ q))))
                b))
      (lam p (coprod_rect (lam w zed)
                (lam q (znegof (mul (succ p) q)))
                (lam q (ii1 (mul (succ p) (succ q))))
                b))
      a))))
 (defn mzed (pi m msr zed) (lam m (pr1 (pr1 m))))          ; the integer rung of the real part
 (defn mmulz (pi a msr (pi b msr msr))
   (lam a (lam b (rmsr (zrea (zmul (mzed a) (mzed b)))))))
 (defn vcount (pi v val nat) (lam v (zabs (mzed (vnet v)))))  ; |count| -- love repeats by it
 (vof 0 '(ii1 6) = vof 0 '(zmul (ii1 2) (ii1 3)))
 (vof 0 '(ii2 5) = vof 0 '(zmul (ii2 1) (ii1 3))) ; -2 * 3 = -6
 (vof 0 '(ii1 6) = vof 0 '(zmul (ii2 1) (ii2 2))) ; -2 * -3 = 6
 (vof 0 '(ii1 0) = vof 0 '(zmul (ii1 0) (ii2 2)))
 (vof 0 '2 = vof 0 '(vcount (zval (ii2 1)))))   ; |-2| = 2

; --- a number repeats a chain |count| times; two chains take the cartesian, each pair a
; --- 2-list -- why the carrier nests, and this lane is a semiring ---
(test
 (defn vrep (pi n nat (pi c val val))
   (lam n (lam c (nat_rect (lam q val) vnilv (lam k (lam r (vapp c r))) n))))
 (defn vrowd (pi d nat (pi t (vtre d) (pi x val val)))
   (lam d (nat_rect (lam q (pi t (vtre q) (pi x val val)))
             (lam t (lam x vnilv))
             (lam k (lam IH (lam t (lam x
                (coprod_rect (lam z val)
                   (lam m vnilv)
                   (lam p (vlink (vlink x (vlink (tpair k (vfst k p)) vnilv))
                                 (IH (vsnd k p) x)))
                   t)))))
             d)))
 (defn vrow (pi b val (pi x val val)) (lam b (lam x (vrowd (pr1 b) (pr2 b) x))))
 (defn vcartd (pi d nat (pi t (vtre d) (pi b val val)))
   (lam d (nat_rect (lam q (pi t (vtre q) (pi b val val)))
             (lam t (lam b vnilv))
             (lam k (lam IH (lam t (lam b
                (coprod_rect (lam z val)
                   (lam m vnilv)
                   (lam p (vapp (vrow b (tpair k (vfst k p))) (IH (vsnd k p) b)))
                   t)))))
             d)))
 (defn vcart (pi u val (pi w val val)) (lam u (lam w (vcartd (pr1 u) (pr2 u) w))))
 (defn vmul (pi u val (pi w val val))
   (lam u (lam w (bool_rect (lam x val)
                    vnilv                                    ; () * x = ()
                    (bool_rect (lam y val)
                       vnilv                                 ; x * () = ()
                       (bool_rect (lam z val)
                          (bool_rect (lam q val)
                             (vnum (mmulz (vnet u) (vnet w))) ; num * num
                             (vrep (vcount w) u)              ; seq * num repeats
                             (nateqb (vband u) bNum))
                          (bool_rect (lam q val)
                             (vrep (vcount u) w)              ; num * seq repeats
                             (vcart u w)                      ; seq * seq: the cartesian
                             (nateqb (vband u) bNum))
                          (nateqb (vband w) bNum))
                       (nateqb (vband w) bUnit))
                    (nateqb (vband u) bUnit))))))

; --- the laws * owes. the zero annihilates either side, with no case on the shape ---
(test
 (defq uv-vmul-lzero (pi v val (paths val (vmul vnilv v) vnilv)) (lam v (idpath vnilv)))
 (defq uv-vmul-rzero (pi v val (paths val (vmul v vnilv) vnilv))
   (lam v (bool_rect (lam X (paths val (bool_rect (lam x val) vnilv vnilv X) vnilv))
             (idpath vnilv) (idpath vnilv) (nateqb (vband v) bUnit))))
 (defq uv-vmul-num
   (pi a msr (pi b msr (paths val (vmul (vnum a) (vnum b)) (vnum (mmulz a b)))))
   (lam a (lam b (idpath (vnum (mmulz a b))))))
 (defq uv-vmul-rep-l
   (pi m msr (pi a val (pi b val
      (paths val (vmul (vnum m) (vlink a b)) (vrep (vcount (vnum m)) (vlink a b))))))
   (lam m (lam a (lam b (idpath (vrep (vcount (vnum m)) (vlink a b)))))))
 (defq uv-vmul-rep-r
   (pi m msr (pi a val (pi b val
      (paths val (vmul (vlink a b) (vnum m)) (vrep (vcount (vnum m)) (vlink a b))))))
   (lam m (lam a (lam b (idpath (vrep (vcount (vnum m)) (vlink a b)))))))
 (defq uv-vmul-cart
   (pi a val (pi b val (pi c val (pi d val
      (paths val (vmul (vlink a b) (vlink c d)) (vcart (vlink a b) (vlink c d)))))))
   (lam a (lam b (lam c (lam d (idpath (vcart (vlink a b) (vlink c d))))))))
 ; 0 copies is (): the number zero annihilates a chain too, yet () and 0 stay apart
 (defq uv-vmul-zero-count
   (pi a val (pi b val (paths val (vmul (nval 0) (vlink a b)) vnilv)))
   (lam a (lam b (idpath vnilv)))))

; --- the demos: * computes, and the cartesian is the shape love answers ---
(test
 (vof 0 'true = vof 0 '(veq (vmul (nval 2) (nval 3)) (nval 6)))
 (vof 0 'true = vof 0 '(veq (vmul (zval (ii2 1)) (nval 3)) (zval (ii2 5))))
 (vof 0 'true = vof 0 '(veq (vmul vnilv (vlink (nval 1) vnilv)) vnilv))
 (vof 0 'true = vof 0 '(veq (vmul (nval 0) (vlink (nval 1) vnilv)) vnilv))
 ; 2 * '(1) = '(1 1)
 (vof 0 'true = vof 0 '(veq (vmul (nval 2) (vlink (nval 1) vnilv))
                            (vlink (nval 1) (vlink (nval 1) vnilv))))
 ; ..and |count| is the absolute value: -2 repeats twice, as love does
 (vof 0 'true = vof 0 '(veq (vmul (zval (ii2 1)) (vlink (nval 1) vnilv))
                            (vlink (nval 1) (vlink (nval 1) vnilv))))
 ; '(1) * '(2 3) = ((1 2) (1 3))
 (vof 0 'true =
    vof 0 '(veq (vmul (vlink (nval 1) vnilv) (vlink (nval 2) (vlink (nval 3) vnilv)))
                (vlink (vlink (nval 1) (vlink (nval 2) vnilv))
                       (vlink (vlink (nval 1) (vlink (nval 3) vnilv)) vnilv))))
 ; and * discriminates, so none of the above is a constant
 (vof 0 'false = vof 0 '(veq (vmul (nval 2) (nval 3)) (nval 5)))
 (vof 0 'false = vof 0 '(veq (vmul (nval 2) (vlink (nval 1) vnilv))
                             (vlink (nval 1) vnilv))))

; --- + associating, computed: append's bracketings build one chain at different heights ---
(test
 (vof 0 'true =
    vof 0 '(veq (vadd (vadd (vlink (nval 1) vnilv) (vlink (nval 2) vnilv))
                      (vlink (nval 3) vnilv))
                (vadd (vlink (nval 1) vnilv)
                      (vadd (vlink (nval 2) vnilv) (vlink (nval 3) vnilv)))))
 ; ..and the two bracketings really do differ as trees: veq sees past the height
 (vof 0 'false =
    vof 0 '(veq (vadd (vadd (vlink (nval 1) vnilv) (vlink (nval 2) vnilv))
                      (vlink (nval 3) vnilv))
                (vlink (nval 1) vnilv)))
 ; append is not commutative, so the associativity above is not a constant
 (vof 0 'false =
    vof 0 '(veq (vapp (vlink (nval 1) vnilv) (vlink (nval 2) vnilv))
                (vapp (vlink (nval 2) vnilv) (vlink (nval 1) vnilv))))
 ; the mixed cells associate by degeneration: both sides answer the chain
 (vof 0 'true =
    vof 0 '(veq (vadd (vadd (nval 5) (vlink (nval 1) vnilv)) (nval 7))
                (vadd (nval 5) (vadd (vlink (nval 1) vnilv) (nval 7)))))
 (vof 0 'true =
    vof 0 '(veq (vadd (vadd (nval 5) (vlink (nval 1) vnilv)) (nval 7))
                (vlink (nval 1) vnilv))))

; --- not proved here: * associating -- its numeric cell sits at the integer rung, and the
; --- cartesian associates only up to reassociation, an order veq is too coarse to see ---

; --- planted faults: each load-bearing claim's false twin must be refused; every negative
; --- takes its positive ---
(hear (p \ e \ peep HELPC () 0 @ h (h ? (h p e) 0)))
(test
 ; the integers really do associate -- and zsucc really does travel
 ('accepted = (rejects (z \ defq uv-ok-zsucc
   (pi a zed (paths zed (zadd a (zsucc zzero)) (zsucc a)))
   (lam a (idpath (zsucc a))))))
 ('rejected = (rejects (z \ defq uv-bad-zsucc (pi a zed (paths zed (zadd a (zsucc zzero)) a)) (lam a (idpath a)))))
 ; the degeneration drops the number; it does not keep it
 ('accepted = (rejects (z \ defq uv-ok-degen
   (pi m msr (pi a val (pi b val (paths val (vadd (vnum m) (vlink a b)) (vlink a b)))))
   (lam m (lam a (lam b (idpath (vlink a b))))))))
 ('rejected = (rejects (z \ defq uv-bad-degen
   (pi m msr (pi a val (pi b val (paths val (vadd (vnum m) (vlink a b)) (vnum m)))))
   (lam m (lam a (lam b (idpath (vnum m))))))))
 ; () is the unit of + and the zero of *, not the unit of both
 ('rejected = (rejects (z \ defq uv-bad-mulunit (pi v val (paths val (vmul vnilv v) v)) (lam v (idpath v)))))
 ; the sign of a product is not the sign of its magnitude
 ('accepted = (rejects (z \ defn uv-ok-zmul (paths zed (zmul (ii2 1) (ii1 3)) (ii2 5)) (idpath (ii2 5)))))
 ('rejected = (rejects (z \ defn uv-bad-zmul (paths zed (zmul (ii2 1) (ii1 3)) (ii1 6)) (idpath (ii1 6)))))
 ; ..and the bridge names mx.l's lane: chain against number keeps the chain, bin_a
 ('accepted = (rejects (z \ defn uv-ok-lane (paths nat (mxadd mxKChain mxKCharm) mxLbin_a) (idpath mxLbin_a))))
 ('rejected = (rejects (z \ defn uv-bad-lane (paths nat (mxadd mxKChain mxKCharm) mxLbin_b) (idpath mxLbin_b))))
 ; append associates and does not commute
 ('rejected = (rejects (z \ defq uv-bad-app-comm
   (pi d nat (pi t (vtre d) (pi v val
      (paths bool (veq (vappd d t v) (vapp v (tpair d t))) true))))
   (lam d (lam t (lam v (uv-veq-refl (vappd d t v))))))))
 ; ..and the pad is invisible to it: append onto a padded spine is append onto the spine
 ('accepted = (rejects (z \ defq uv-ok-app-pad
   (pi a nat (pi b nat (pi t (vtre a) (pi w val
      (paths bool (veq (vappd (mx2 a b) (padl a b t) w) (vappd a t w)) true)))))
   uv-vapp-padl))))
(hear test-strict)
