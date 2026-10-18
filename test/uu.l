; uu -- the UniMath corpus, checked by the uu kernel baked from post.l
; the kernel surface the corpus reads bare re-leaks here, body-less, for later files
(: GLOB (uu 'GLOB) HELPC (uu 'HELPC) vof (uu 'vof)
   capp (uu 'capp) conv (uu 'conv)
   rejects (uu 'rejects)                    ; not defn/defq/axm: a bound head hides its macro,
                                            ; and the macro is what quotes their operands
   lof (uu 'lof) bridge (uu 'bridge))
; ..so hoist the three macros here, in a form of their own: c0 compiles a whole form at once
(: _ (transcribe 'uu '(defn defq axm)))

; with `uu` missing every defn is a truthy no-op and the corpus paints fake green
(test
 (defn uu-alive (pi n nat nat) (lam n (succ n)),
  two? (peep GLOB 'uu-alive 0))
 (3 = vof 0 '(uu-alive 2)))

; --- UniMath Foundations PartA. definitions and statements from here down are ported from
; --- UniMath (https://github.com/UniMath/UniMath, Foundations/PartA.v et al), mit license,
; --- copyright (c) 2015 the UniMath Development Team. the kernel is our own ---
(test
 (defn idfun (pi T UU (pi x T T)) (lam T (lam x x)))
 (defn funcomp
   (pi X UU (pi Y UU (pi Z UU (pi f (pi x X Y) (pi g (pi y Y Z) (pi x X Z))))))
   (lam X (lam Y (lam Z (lam f (lam g (lam x (g (f x)))))))))
 (defn iscontr (pi T UU UU) (lam T (total2 c T (pi t T (paths T t c)))))
 (defn hfiber
   (pi X UU (pi Y UU (pi f (pi x X Y) (pi y Y UU))))
   (lam X (lam Y (lam f (lam y (total2 x X (paths Y (f x) y)))))))
 (defn isweq
   (pi X UU (pi Y UU (pi f (pi x X Y) UU)))
   (lam X (lam Y (lam f (pi y Y (iscontr (hfiber X Y f y)))))))
 (defn weq (pi X UU (pi Y UU UU))
   (lam X (lam Y (total2 f (pi x X Y) (isweq X Y f)))))
 (defn transportf
   (pi A UU (pi P (pi x A UU) (pi a A (pi b A (pi e (paths A a b) (pi p (P a) (P b)))))))
   (lam A (lam P (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (pi p (P a) (P bp)))) (lam p p) e)))))))
 (defn pathsinv0
   (pi A UU (pi a A (pi b A (pi e (paths A a b) (paths A b a)))))
   (lam A (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (paths A bp a))) (idpath a) e))))))
 ; pathscomp0 inducts on its first argument, as UniMath's @; the right identity is a lemma
 (defn pathscomp0
   (pi A UU (pi a A (pi b A (pi c A (pi e1 (paths A a b) (pi e2 (paths A b c) (paths A a c)))))))
   (lam A (lam a (lam b (lam c (lam e1 (lam e2
      ((paths_rect (lam bp (lam ep (pi q (paths A bp c) (paths A a c))))
                   (lam q q)
                   e1)
       e2))))))))
 (defn maponpaths
   (pi A UU (pi B UU (pi f (pi x A B) (pi a A (pi b A (pi e (paths A a b) (paths B (f a) (f b))))))))
   (lam A (lam B (lam f (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (paths B (f a) (f bp)))) (idpath (f a)) e))))))))
 (defn uu-unitpath (pi u unit (paths unit u tt))
   (lam u (unit_rect (lam v (paths unit v tt)) (idpath tt) u)))
 (defn iscontrunit (iscontr unit) (tpair tt (lam t (uu-unitpath t))))
 (defn proofirrelevancecontr
   (pi X UU (pi i (iscontr X) (pi x X (pi y X (paths X x y)))))
   (lam X (lam i (lam x (lam y
      (pathscomp0 X x (pr1 i) y ((pr2 i) x) (pathsinv0 X y (pr1 i) ((pr2 i) y))))))))
 (defn fromempty (pi P UU (pi e empty P)) (lam P (lam e (empty_rect (lam x P) e))))
 (defn negb (pi b bool bool) (lam b (bool_rect (lam x bool) false true b)))
 (defn add (pi n nat (pi m nat nat))
   (lam n (lam m (nat_rect (lam x nat) m (lam k (lam r (succ r))) n)))))

; the eliminators compute: proofs by idpath are proofs by evaluation.
(test
 (defn uu-two-plus-two (paths nat (add 2 2) 4) (idpath 4))
 (defn uu-negb-true (paths bool (negb true) false) (idpath false))
 (defn uu-fromsum (pi v (coprod nat bool) nat)
   (lam v (coprod_rect (lam x nat) (lam a a) (lam b (bool_rect (lam x nat) 1 0 b)) v)))
 (defn uu-fromsum-ii2 (paths nat (uu-fromsum (ii2 true)) 1) (idpath 1))
 (4 = (vof 0 '(add 2 2))))

; idisweq (needs sigma-eta); univalence is the axiom over a checked eqweqmap
(test
 (defn idisweq (pi T UU (isweq T T (idfun T)))
   (lam T (lam y (tpair (tpair y (idpath y))
      (lam t (paths_rect
        (lam bp (lam ep (paths (hfiber T T (idfun T) bp)
                               (tpair (pr1 t) ep)
                               (tpair bp (idpath bp)))))
        (idpath (tpair (pr1 t) (idpath (pr1 t))))
        (pr2 t)))))))
 (defn idweq (pi T UU (weq T T)) (lam T (tpair (lam x x) (idisweq T))))
 (defn eqweqmap (pi X UU (pi Y UU (pi e (paths UU X Y) (weq X Y))))
   (lam X (lam Y (lam e (paths_rect (lam Yp (lam ep (weq X Yp))) (idweq X) e)))))
 (axm univalenceAxiom
   (pi X UU (pi Y UU (isweq (paths UU X Y) (weq X Y) (eqweqmap X Y)))))
 ; the one axiom: funext is proved below
 (defn uu-eqweqmap-idpath
   (pi X UU (paths (weq X X) (eqweqmap X X (idpath X)) (idweq X)))
   (lam X (idpath (idweq X))))
 (defn invmap
   (pi X UU (pi Y UU (pi w (weq X Y) (pi y Y X))))
   (lam X (lam Y (lam w (lam y (pr1 (pr1 ((pr2 w) y))))))))
 (defn homotweqinvweq
   (pi X UU (pi Y UU (pi w (weq X Y) (pi y Y (paths Y ((pr1 w) (invmap X Y w y)) y)))))
   (lam X (lam Y (lam w (lam y (pr2 (pr1 ((pr2 w) y)))))))))

; the h-level ladder by nat-recursion from iscontr; the truncation is impredicative
(test
 (defn isaprop (pi X UU UU)
   (lam X (pi x X (pi y X (iscontr (paths X x y))))))
 (defn isaset (pi X UU UU)
   (lam X (pi x X (pi y X (isaprop (paths X x y))))))
 (defn isofhlevel (pi n nat (pi X UU UU))
   (lam n (nat_rect (lam q (pi X UU UU))
                     iscontr
                     (lam k (lam rec (lam X (pi x X (pi y X (rec (paths X x y)))))))
                     n)))
 (defn uu-isaprop-is-level1
   (pi X UU (paths UU (isaprop X) (isofhlevel 1 X)))
   (lam X (idpath (isaprop X))))
 (defn uu-isaset-is-level2
   (pi X UU (paths UU (isaset X) (isofhlevel 2 X)))
   (lam X (idpath (isaset X))))
 (defn hProp UU (total2 X UU (isaprop X)))
 (defn hSet UU (total2 X UU (isaset X)))
 (defn ishinh_UU (pi X UU UU)
   (lam X (pi P hProp (pi f (pi x X (pr1 P)) (pr1 P)))))
 (defn hinhpr (pi X UU (pi x X (ishinh_UU X)))
   (lam X (lam x (lam P (lam f (f x))))))
 (defn hinhuniv
   (pi X UU (pi P hProp (pi f (pi x X (pr1 P)) (pi w (ishinh_UU X) (pr1 P)))))
   (lam X (lam P (lam f (lam w (w P f)))))))

; sigma paths, the retraction, univalence's consequences. no neg/negf: a corpus global
; `neg` would shadow the prel's -x for every later test
(test
 (defn total2_paths_f
   (pi A UU (pi P (pi x A UU)
      (pi s (total2 x A (P x)) (pi sp (total2 x A (P x))
        (pi p (paths A (pr1 s) (pr1 sp))
          (pi q (paths (P (pr1 sp)) (transportf A P (pr1 s) (pr1 sp) p (pr2 s)) (pr2 sp))
            (paths (total2 x A (P x)) s sp)))))))
   (lam A (lam P (lam s (lam sp (lam p (lam q
      ((paths_rect
         (lam bp (lam ep
           (pi qp (P bp)
             (pi qe (paths (P bp) (transportf A P (pr1 s) bp ep (pr2 s)) qp)
               (paths (total2 x A (P x)) s (tpair bp qp))))))
         (lam qp (lam qe
           (paths_rect
             (lam qpp (lam e2 (paths (total2 x A (P x)) s (tpair (pr1 s) qpp))))
             (idpath s)
             qe)))
         p)
       (pr2 sp) q))))))))
 (defn homotinvweqweq
   (pi X UU (pi Y UU (pi w (weq X Y) (pi x X
      (paths X (invmap X Y w ((pr1 w) x)) x)))))
   (lam X (lam Y (lam w (lam x
      (pathsinv0 X x (invmap X Y w ((pr1 w) x))
        (maponpaths (hfiber X Y (pr1 w) ((pr1 w) x)) X (lam t (pr1 t))
          (tpair x (idpath ((pr1 w) x)))
          (pr1 ((pr2 w) ((pr1 w) x)))
          ((pr2 ((pr2 w) ((pr1 w) x))) (tpair x (idpath ((pr1 w) x)))))))))))
 (defn isweqtoempty
   (pi X UU (pi f (pi x X empty) (isweq X empty f)))
   (lam X (lam f (lam y (empty_rect (lam e (iscontr (hfiber X empty f e))) y)))))
 (defn weqtoempty
   (pi X UU (pi f (pi x X empty) (weq X empty)))
   (lam X (lam f (tpair f (isweqtoempty X f)))))
 (defn nopathstruetofalse (pi e (paths bool true false) empty)
   (lam e (transportf bool (lam b (bool_rect (lam x UU) unit empty b)) true false e tt)))
 (defn nopathsfalsetotrue (pi e (paths bool false true) empty)
   (lam e (transportf bool (lam b (bool_rect (lam x UU) empty unit b)) false true e tt)))
 (defn univalence
   (pi X UU (pi Y UU (weq (paths UU X Y) (weq X Y))))
   (lam X (lam Y (tpair (eqweqmap X Y) (univalenceAxiom X Y)))))
 (defn weqtopaths
   (pi X UU (pi Y UU (pi w (weq X Y) (paths UU X Y))))
   (lam X (lam Y (lam w (invmap (paths UU X Y) (weq X Y) (univalence X Y) w)))))
 (defn weqpathsweq
   (pi X UU (pi Y UU (pi w (weq X Y)
      (paths (weq X Y) (eqweqmap X Y (weqtopaths X Y w)) w))))
   (lam X (lam Y (lam w (homotweqinvweq (paths UU X Y) (weq X Y) (univalence X Y) w))))))

; the path groupoid coherences and the retraction machinery; isapropunit checks bare,
; as iscontrpathsinunit's stored type is (isaprop unit) unfolded
(test
 (defn pathscomp0rid
   (pi A UU (pi a A (pi b A (pi e (paths A a b)
      (paths (paths A a b) (pathscomp0 A a b b e (idpath b)) e)))))
   (lam A (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (paths (paths A a bp)
                                    (pathscomp0 A a bp bp ep (idpath bp)) ep)))
                  (idpath (idpath a))
                  e))))))
 (defn pathsinv0r
   (pi A UU (pi a A (pi b A (pi e (paths A a b)
      (paths (paths A a a) (pathscomp0 A a b a e (pathsinv0 A a b e)) (idpath a))))))
   (lam A (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (paths (paths A a a)
                                    (pathscomp0 A a bp a ep (pathsinv0 A a bp ep))
                                    (idpath a))))
                  (idpath (idpath a))
                  e))))))
 (defn pathsinv0l
   (pi A UU (pi a A (pi b A (pi e (paths A a b)
      (paths (paths A b b) (pathscomp0 A b a b (pathsinv0 A a b e) e) (idpath b))))))
   (lam A (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (paths (paths A bp bp)
                                    (pathscomp0 A bp a bp (pathsinv0 A a bp ep) ep)
                                    (idpath bp))))
                  (idpath (idpath a))
                  e))))))
 (defn iscontrretract
   (pi X UU (pi Y UU (pi p (pi x X Y) (pi s (pi y Y X)
      (pi eps (pi y Y (paths Y (p (s y)) y))
        (pi is (iscontr X) (iscontr Y)))))))
   (lam X (lam Y (lam p (lam s (lam eps (lam is
      (tpair (p (pr1 is))
        (lam t (pathscomp0 Y t (p (s t)) (p (pr1 is))
                 (pathsinv0 Y (p (s t)) t (eps t))
                 (maponpaths X Y p (s t) (pr1 is) ((pr2 is) (s t)))))))))))))
 (defn hfibershomotftog
   (pi X UU (pi Y UU (pi f (pi x X Y) (pi g (pi x X Y)
      (pi h (pi x X (paths Y (f x) (g x)))
        (pi y Y (pi t (hfiber X Y f y) (hfiber X Y g y))))))))
   (lam X (lam Y (lam f (lam g (lam h (lam y (lam t
      (tpair (pr1 t)
        (pathscomp0 Y (g (pr1 t)) (f (pr1 t)) y
          (pathsinv0 Y (f (pr1 t)) (g (pr1 t)) (h (pr1 t)))
          (pr2 t)))))))))))
 (defn hfibershomotgtof
   (pi X UU (pi Y UU (pi f (pi x X Y) (pi g (pi x X Y)
      (pi h (pi x X (paths Y (f x) (g x)))
        (pi y Y (pi t (hfiber X Y g y) (hfiber X Y f y))))))))
   (lam X (lam Y (lam f (lam g (lam h (lam y (lam t
      (tpair (pr1 t)
        (pathscomp0 Y (f (pr1 t)) (g (pr1 t)) y
          (h (pr1 t))
          (pr2 t)))))))))))
 (defn iscontrpathsinunit
   (pi x unit (pi y unit (iscontr (paths unit x y))))
   (lam x (lam y (tpair
      (pathscomp0 unit x tt y (uu-unitpath x) (pathsinv0 unit y tt (uu-unitpath y)))
      (lam e (paths_rect
               (lam yp (lam ep (paths (paths unit x yp) ep
                          (pathscomp0 unit x tt yp (uu-unitpath x)
                                      (pathsinv0 unit yp tt (uu-unitpath yp))))))
               (pathsinv0 (paths unit x x)
                 (pathscomp0 unit x tt x (uu-unitpath x) (pathsinv0 unit x tt (uu-unitpath x)))
                 (idpath x)
                 (pathsinv0r unit x tt (uu-unitpath x)))
               e))))))
 (defn isapropunit (isaprop unit) iscontrpathsinunit))

; the grad lemma (isweq_iso): an isomorphism is a weak equivalence, by Voevodsky's
; hfiber route; weqtopaths then mints a path bool = bool that is not idpath
(test
 (defn path_assoc
   (pi A UU (pi a A (pi b A (pi c A (pi d A
      (pi e1 (paths A a b) (pi e2 (paths A b c) (pi e3 (paths A c d)
        (paths (paths A a d)
          (pathscomp0 A a b d e1 (pathscomp0 A b c d e2 e3))
          (pathscomp0 A a c d (pathscomp0 A a b c e1 e2) e3))))))))))
   (lam A (lam a (lam b (lam c (lam d (lam e1 (lam e2 (lam e3
      ((paths_rect
         (lam bp (lam ep (pi q2 (paths A bp c) (pi q3 (paths A c d)
           (paths (paths A a d)
             (pathscomp0 A a bp d ep (pathscomp0 A bp c d q2 q3))
             (pathscomp0 A a c d (pathscomp0 A a bp c ep q2) q3))))))
         (lam q2 (lam q3 (idpath (pathscomp0 A a c d q2 q3))))
         e1)
       e2 e3))))))))))
 (defn uu-pathsinv0comp
   (pi A UU (pi a A (pi b A (pi c A (pi p (paths A a b) (pi q (paths A b c)
      (paths (paths A b c)
        (pathscomp0 A b a c (pathsinv0 A a b p) (pathscomp0 A a b c p q))
        q)))))))
   (lam A (lam a (lam b (lam c (lam p (lam q
      ((paths_rect
         (lam bp (lam ep (pi qq (paths A bp c)
           (paths (paths A bp c)
             (pathscomp0 A bp a c (pathsinv0 A a bp ep) (pathscomp0 A a bp c ep qq))
             qq))))
         (lam qq (idpath qq))
         p)
       q))))))))
 (defn uu-transportf-paths-Fl
   (pi A UU (pi B UU (pi f (pi x A B) (pi b B
      (pi x1 A (pi x2 A (pi p (paths A x1 x2) (pi e (paths B (f x1) b)
        (paths (paths B (f x2) b)
          (transportf A (lam x (paths B (f x) b)) x1 x2 p e)
          (pathscomp0 B (f x2) (f x1) b
            (pathsinv0 B (f x1) (f x2) (maponpaths A B f x1 x2 p))
            e))))))))))
   (lam A (lam B (lam f (lam b (lam x1 (lam x2 (lam p (lam e
      (paths_rect
        (lam xp (lam pp (paths (paths B (f xp) b)
          (transportf A (lam x (paths B (f x) b)) x1 xp pp e)
          (pathscomp0 B (f xp) (f x1) b
            (pathsinv0 B (f x1) (f xp) (maponpaths A B f x1 xp pp))
            e))))
        (idpath e)
        p))))))))))
 (defn iscontrhfiberl1
   (pi X UU (pi Y UU (pi f (pi x X Y) (pi g (pi x X Y)
      (pi h (pi x X (paths Y (f x) (g x)))
        (pi y Y (pi is (iscontr (hfiber X Y f y)) (iscontr (hfiber X Y g y)))))))))
   (lam X (lam Y (lam f (lam g (lam h (lam y (lam is
      (iscontrretract (hfiber X Y f y) (hfiber X Y g y)
        (hfibershomotftog X Y f g h y)
        (hfibershomotgtof X Y f g h y)
        (lam t (total2_paths_f X (lam x (paths Y (g x) y))
                 ((hfibershomotftog X Y f g h y) ((hfibershomotgtof X Y f g h y) t))
                 t
                 (idpath (pr1 t))
                 (uu-pathsinv0comp Y (f (pr1 t)) (g (pr1 t)) y (h (pr1 t)) (pr2 t))))
        is)))))))))
 (defn isweqhomot
   (pi X UU (pi Y UU (pi f (pi x X Y) (pi g (pi x X Y)
      (pi h (pi x X (paths Y (f x) (g x)))
        (pi is (isweq X Y f) (isweq X Y g)))))))
   (lam X (lam Y (lam f (lam g (lam h (lam is
      (lam y (iscontrhfiberl1 X Y f g h y (is y))))))))))
 (defn isweq_iso
   (pi X UU (pi Y UU (pi f (pi x X Y) (pi g (pi y Y X)
      (pi egf (pi x X (paths X (g (f x)) x))
        (pi efg (pi y Y (paths Y (f (g y)) y))
          (isweq X Y f)))))))
   (lam X (lam Y (lam f (lam g (lam egf (lam efg
      (lam y
        (iscontrretract
          (hfiber Y Y (lam yp (f (g yp))) y)
          (hfiber X Y f y)
          (lam t (tpair (g (pr1 t)) (pr2 t)))
          (lam t (tpair (f (pr1 t))
                   (pathscomp0 Y (f (g (f (pr1 t)))) (f (pr1 t)) y
                     (maponpaths X Y f (g (f (pr1 t))) (pr1 t) (egf (pr1 t)))
                     (pr2 t))))
          (lam t (total2_paths_f X (lam x (paths Y (f x) y))
                   (tpair (g (f (pr1 t)))
                     (pathscomp0 Y (f (g (f (pr1 t)))) (f (pr1 t)) y
                       (maponpaths X Y f (g (f (pr1 t))) (pr1 t) (egf (pr1 t)))
                       (pr2 t)))
                   t
                   (egf (pr1 t))
                   (pathscomp0 (paths Y (f (pr1 t)) y)
                     (transportf X (lam x (paths Y (f x) y)) (g (f (pr1 t))) (pr1 t) (egf (pr1 t))
                       (pathscomp0 Y (f (g (f (pr1 t)))) (f (pr1 t)) y
                         (maponpaths X Y f (g (f (pr1 t))) (pr1 t) (egf (pr1 t)))
                         (pr2 t)))
                     (pathscomp0 Y (f (pr1 t)) (f (g (f (pr1 t)))) y
                       (pathsinv0 Y (f (g (f (pr1 t)))) (f (pr1 t))
                         (maponpaths X Y f (g (f (pr1 t))) (pr1 t) (egf (pr1 t))))
                       (pathscomp0 Y (f (g (f (pr1 t)))) (f (pr1 t)) y
                         (maponpaths X Y f (g (f (pr1 t))) (pr1 t) (egf (pr1 t)))
                         (pr2 t)))
                     (pr2 t)
                     (uu-transportf-paths-Fl X Y f y (g (f (pr1 t))) (pr1 t) (egf (pr1 t))
                       (pathscomp0 Y (f (g (f (pr1 t)))) (f (pr1 t)) y
                         (maponpaths X Y f (g (f (pr1 t))) (pr1 t) (egf (pr1 t)))
                         (pr2 t)))
                     (uu-pathsinv0comp Y (f (g (f (pr1 t)))) (f (pr1 t)) y
                       (maponpaths X Y f (g (f (pr1 t))) (pr1 t) (egf (pr1 t)))
                       (pr2 t)))))
          (iscontrhfiberl1 Y Y (idfun Y) (lam yp (f (g yp)))
            (lam yp (pathsinv0 Y (f (g yp)) yp (efg yp)))
            y
            (idisweq Y y)))))))))))
 (defn isweqinvmap
   (pi X UU (pi Y UU (pi w (weq X Y) (isweq Y X (lam y (invmap X Y w y))))))
   (lam X (lam Y (lam w
      (isweq_iso Y X (lam y (invmap X Y w y)) (pr1 w)
        (homotweqinvweq X Y w)
        (homotinvweqweq X Y w))))))
 (defn invweq (pi X UU (pi Y UU (pi w (weq X Y) (weq Y X))))
   (lam X (lam Y (lam w (tpair (lam y (invmap X Y w y)) (isweqinvmap X Y w))))))
 (defn uu-isweqnegb (isweq bool bool negb)
   (isweq_iso bool bool negb negb
      (lam b (bool_rect (lam bp (paths bool (negb (negb bp)) bp))
               (idpath true) (idpath false) b))
      (lam b (bool_rect (lam bp (paths bool (negb (negb bp)) bp))
               (idpath true) (idpath false) b))))
 (defn uu-weqnegb (weq bool bool) (tpair negb uu-isweqnegb))
 (defn uu-boolbool (paths UU bool bool) (weqtopaths bool bool uu-weqnegb)))

; weq composition from the grad lemma; boolascoprod runs every eliminator inside one weq
(test
 (defn twooutof3c
   (pi X UU (pi Y UU (pi Z UU (pi f (pi x X Y) (pi g (pi y Y Z)
      (pi isf (isweq X Y f) (pi isg (isweq Y Z g)
        (isweq X Z (lam x (g (f x)))))))))))
   (lam X (lam Y (lam Z (lam f (lam g (lam isf (lam isg
      (isweq_iso X Z (lam x (g (f x)))
        (lam z (invmap X Y (tpair f isf) (invmap Y Z (tpair g isg) z)))
        (lam x (pathscomp0 X
                 (invmap X Y (tpair f isf) (invmap Y Z (tpair g isg) (g (f x))))
                 (invmap X Y (tpair f isf) (f x))
                 x
                 (maponpaths Y X (lam yy (invmap X Y (tpair f isf) yy))
                   (invmap Y Z (tpair g isg) (g (f x))) (f x)
                   (homotinvweqweq Y Z (tpair g isg) (f x)))
                 (homotinvweqweq X Y (tpair f isf) x)))
        (lam z (pathscomp0 Z
                 (g (f (invmap X Y (tpair f isf) (invmap Y Z (tpair g isg) z))))
                 (g (invmap Y Z (tpair g isg) z))
                 z
                 (maponpaths Y Z g
                   (f (invmap X Y (tpair f isf) (invmap Y Z (tpair g isg) z)))
                   (invmap Y Z (tpair g isg) z)
                   (homotweqinvweq X Y (tpair f isf) (invmap Y Z (tpair g isg) z)))
                 (homotweqinvweq Y Z (tpair g isg) z))))))))))))
 (defn weqcomp
   (pi X UU (pi Y UU (pi Z UU (pi w1 (weq X Y) (pi w2 (weq Y Z) (weq X Z))))))
   (lam X (lam Y (lam Z (lam w1 (lam w2
      (tpair (lam x ((pr1 w2) ((pr1 w1) x)))
             (twooutof3c X Y Z (pr1 w1) (pr1 w2) (pr2 w1) (pr2 w2)))))))))
 (defn boolascoprod (weq bool (coprod unit unit))
   (tpair (lam b (bool_rect (lam q (coprod unit unit)) (ii1 tt) (ii2 tt) b))
      (isweq_iso bool (coprod unit unit)
        (lam b (bool_rect (lam q (coprod unit unit)) (ii1 tt) (ii2 tt) b))
        (lam c (coprod_rect (lam q bool) (lam u true) (lam u false) c))
        (lam b (bool_rect
                 (lam bp (paths bool
                   (coprod_rect (lam q bool) (lam u true) (lam u false)
                     (bool_rect (lam q (coprod unit unit)) (ii1 tt) (ii2 tt) bp))
                   bp))
                 (idpath true) (idpath false) b))
        (lam c (coprod_rect
                 (lam cp (paths (coprod unit unit)
                   (bool_rect (lam q (coprod unit unit)) (ii1 tt) (ii2 tt)
                     (coprod_rect (lam q bool) (lam u true) (lam u false) cp))
                   cp))
                 (lam u (maponpaths unit (coprod unit unit) (lam uu (ii1 uu)) tt u
                          (pathsinv0 unit u tt (uu-unitpath u))))
                 (lam u (maponpaths unit (coprod unit unit) (lam uu (ii2 uu)) tt u
                          (pathsinv0 unit u tt (uu-unitpath u))))
                 c))))))

; hedberg: decidable equality makes a set, funext-free; the coconut starts the funext chain
(test
 (defn coconusfromt (pi T UU (pi t T UU))
   (lam T (lam t (total2 tp T (paths T t tp)))))
 (defn iscontrcoconusfromt (pi T UU (pi t T (iscontr (coconusfromt T t))))
   (lam T (lam t (tpair (tpair t (idpath t))
      (lam w (paths_rect
               (lam bp (lam ep (paths (coconusfromt T t) (tpair bp ep)
                                      (tpair t (idpath t)))))
               (idpath (tpair t (idpath t)))
               (pr2 w)))))))
 (defn invproofirrelevance
   (pi X UU (pi h (pi x X (pi y X (paths X x y))) (isaprop X)))
   (lam X (lam h (lam x (lam y
      (tpair
        (pathscomp0 X x x y (pathsinv0 X x x (h x x)) (h x y))
        (lam p (paths_rect
                 (lam yp (lam pp (paths (paths X x yp) pp
                           (pathscomp0 X x x yp (pathsinv0 X x x (h x x)) (h x yp)))))
                 (pathsinv0 (paths X x x)
                   (pathscomp0 X x x x (pathsinv0 X x x (h x x)) (h x x))
                   (idpath x)
                   (pathsinv0l X x x (h x x)))
                 p))))))))
 (defn negpaths0sx (pi k nat (pi e (paths nat 0 (succ k)) empty))
   (lam k (lam e (transportf nat
      (lam n (nat_rect (lam q UU) unit (lam m (lam r empty)) n))
      0 (succ k) e tt))))
 (defn negpathssx0 (pi k nat (pi e (paths nat (succ k) 0) empty))
   (lam k (lam e (transportf nat
      (lam n (nat_rect (lam q UU) empty (lam m (lam r unit)) n))
      (succ k) 0 e tt))))
 (defn isdeceqbool
   (pi x bool (pi y bool (coprod (paths bool x y) (pi e (paths bool x y) empty))))
   (lam x (lam y
      ((bool_rect (lam xp (pi yy bool (coprod (paths bool xp yy)
                                              (pi e (paths bool xp yy) empty))))
         (lam yy (bool_rect (lam yp (coprod (paths bool true yp)
                                            (pi e (paths bool true yp) empty)))
                   (ii1 (idpath true)) (ii2 nopathstruetofalse) yy))
         (lam yy (bool_rect (lam yp (coprod (paths bool false yp)
                                            (pi e (paths bool false yp) empty)))
                   (ii2 nopathsfalsetotrue) (ii1 (idpath false)) yy))
         x)
       y))))
 (defn isaproppathsfromisolated
   (pi X UU (pi x X
      (pi is (pi y X (coprod (paths X x y) (pi e (paths X x y) empty)))
        (pi y X (isaprop (paths X x y))))))
   (lam X (lam x (lam is (lam y
      (invproofirrelevance (paths X x y)
        (lam p (lam q
          (pathscomp0 (paths X x y)
            p
            (pathscomp0 X x x y
              (pathsinv0 X x x
                (coprod_rect (lam d (paths X x x)) (lam e e)
                  (lam f (fromempty (paths X x x) (f (idpath x)))) (is x)))
              (coprod_rect (lam d (paths X x y)) (lam e e)
                (lam f (fromempty (paths X x y) (f p))) (is y)))
            q
            ; p = !g0 @ (G p), by J
            (paths_rect
              (lam yp (lam pp (paths (paths X x yp) pp
                        (pathscomp0 X x x yp
                          (pathsinv0 X x x
                            (coprod_rect (lam d (paths X x x)) (lam e e)
                              (lam f (fromempty (paths X x x) (f (idpath x)))) (is x)))
                          (coprod_rect (lam d (paths X x yp)) (lam e e)
                            (lam f (fromempty (paths X x yp) (f pp))) (is yp))))))
              (pathsinv0 (paths X x x)
                (pathscomp0 X x x x
                  (pathsinv0 X x x
                    (coprod_rect (lam d (paths X x x)) (lam e e)
                      (lam f (fromempty (paths X x x) (f (idpath x)))) (is x)))
                  (coprod_rect (lam d (paths X x x)) (lam e e)
                    (lam f (fromempty (paths X x x) (f (idpath x)))) (is x)))
                (idpath x)
                (pathsinv0l X x x
                  (coprod_rect (lam d (paths X x x)) (lam e e)
                    (lam f (fromempty (paths X x x) (f (idpath x)))) (is x))))
              p)
            ; !g0 @ (G p) = !g0 @ (G q) = q
            (pathscomp0 (paths X x y)
              (pathscomp0 X x x y
                (pathsinv0 X x x
                  (coprod_rect (lam d (paths X x x)) (lam e e)
                    (lam f (fromempty (paths X x x) (f (idpath x)))) (is x)))
                (coprod_rect (lam d (paths X x y)) (lam e e)
                  (lam f (fromempty (paths X x y) (f p))) (is y)))
              (pathscomp0 X x x y
                (pathsinv0 X x x
                  (coprod_rect (lam d (paths X x x)) (lam e e)
                    (lam f (fromempty (paths X x x) (f (idpath x)))) (is x)))
                (coprod_rect (lam d (paths X x y)) (lam e e)
                  (lam f (fromempty (paths X x y) (f q))) (is y)))
              q
              ; ap (!G0 @ -) across (G p) = (G q): the normalizer is constant
              (maponpaths (paths X x y) (paths X x y)
                (lam r (pathscomp0 X x x y
                         (pathsinv0 X x x
                           (coprod_rect (lam d (paths X x x)) (lam e e)
                             (lam f (fromempty (paths X x x) (f (idpath x)))) (is x)))
                         r))
                (coprod_rect (lam d (paths X x y)) (lam e e)
                  (lam f (fromempty (paths X x y) (f p))) (is y))
                (coprod_rect (lam d (paths X x y)) (lam e e)
                  (lam f (fromempty (paths X x y) (f q))) (is y))
                (coprod_rect
                  (lam d (paths (paths X x y)
                           (coprod_rect (lam d2 (paths X x y)) (lam e e)
                             (lam f (fromempty (paths X x y) (f p))) d)
                           (coprod_rect (lam d2 (paths X x y)) (lam e e)
                             (lam f (fromempty (paths X x y) (f q))) d)))
                  (lam e (idpath e))
                  (lam f (fromempty
                           (paths (paths X x y)
                             (fromempty (paths X x y) (f p))
                             (fromempty (paths X x y) (f q)))
                           (f p)))
                  (is y)))
              ; and the J-lemma at q, reversed
              (pathsinv0 (paths X x y)
                q
                (pathscomp0 X x x y
                  (pathsinv0 X x x
                    (coprod_rect (lam d (paths X x x)) (lam e e)
                      (lam f (fromempty (paths X x x) (f (idpath x)))) (is x)))
                  (coprod_rect (lam d (paths X x y)) (lam e e)
                    (lam f (fromempty (paths X x y) (f q))) (is y)))
                (paths_rect
                  (lam yp (lam pp (paths (paths X x yp) pp
                            (pathscomp0 X x x yp
                              (pathsinv0 X x x
                                (coprod_rect (lam d (paths X x x)) (lam e e)
                                  (lam f (fromempty (paths X x x) (f (idpath x)))) (is x)))
                              (coprod_rect (lam d (paths X x yp)) (lam e e)
                                (lam f (fromempty (paths X x yp) (f pp))) (is yp))))))
                  (pathsinv0 (paths X x x)
                    (pathscomp0 X x x x
                      (pathsinv0 X x x
                        (coprod_rect (lam d (paths X x x)) (lam e e)
                          (lam f (fromempty (paths X x x) (f (idpath x)))) (is x)))
                      (coprod_rect (lam d (paths X x x)) (lam e e)
                        (lam f (fromempty (paths X x x) (f (idpath x)))) (is x)))
                    (idpath x)
                    (pathsinv0l X x x
                      (coprod_rect (lam d (paths X x x)) (lam e e)
                        (lam f (fromempty (paths X x x) (f (idpath x)))) (is x))))
                  q))))))))))))
 (defn isasetifdeceq
   (pi X UU
      (pi dec (pi x X (pi y X (coprod (paths X x y) (pi e (paths X x y) empty))))
        (isaset X)))
   (lam X (lam dec (lam x (lam y (isaproppathsfromisolated X x (dec x) y))))))
 (defn isasetbool (isaset bool) (isasetifdeceq bool isdeceqbool))
 (defn isdeceqnat
   (pi x nat (pi y nat (coprod (paths nat x y) (pi e (paths nat x y) empty))))
   (lam x (lam y
      ((nat_rect (lam xp (pi yy nat (coprod (paths nat xp yy)
                                            (pi e (paths nat xp yy) empty))))
         (lam yy (nat_rect (lam yp (coprod (paths nat 0 yp)
                                           (pi e (paths nat 0 yp) empty)))
                   (ii1 (idpath 0))
                   (lam m (lam r (ii2 (negpaths0sx m))))
                   yy))
         (lam k (lam IH (lam yy
           (nat_rect (lam yp (coprod (paths nat (succ k) yp)
                                     (pi e (paths nat (succ k) yp) empty)))
             (ii2 (negpathssx0 k))
             (lam m (lam r2
               (coprod_rect
                 (lam d (coprod (paths nat (succ k) (succ m))
                                (pi e (paths nat (succ k) (succ m)) empty)))
                 (lam e (ii1 (maponpaths nat nat (lam n (succ n)) k m e)))
                 (lam f (ii2 (lam e2 (f (maponpaths nat nat
                   (lam n (nat_rect (lam q nat) 0 (lam a (lam r3 a)) n))
                   (succ k) (succ m) e2)))))
                 (IH m))))
             yy))))
         x)
       y))))
 (defn isasetnat (isaset nat) (isasetifdeceq nat isdeceqnat)))

; funext from univalence, UnivalenceAxiom.v's uah chain; natplusr0 + the demo mint a path
; (lam n (add n 0)) = (lam n n) that no conversion sees
(test
 (defn transportb
   (pi A UU (pi P (pi x A UU) (pi a A (pi b A (pi e (paths A a b) (pi p (P b) (P a)))))))
   (lam A (lam P (lam a (lam b (lam e (transportf A P b a (pathsinv0 A a b e))))))))
 (defn isweqtransportf
   (pi A UU (pi P (pi x A UU) (pi a A (pi b A (pi e (paths A a b)
      (isweq (P a) (P b) (transportf A P a b e)))))))
   (lam A (lam P (lam a (lam b (lam e
      (paths_rect
        (lam bp (lam ep (isweq (P a) (P bp) (transportf A P a bp ep))))
        (idisweq (P a))
        e)))))))
 (defn isweqtransportb
   (pi A UU (pi P (pi x A UU) (pi a A (pi b A (pi e (paths A a b)
      (isweq (P b) (P a) (transportb A P a b e)))))))
   (lam A (lam P (lam a (lam b (lam e
      (isweqtransportf A P b a (pathsinv0 A a b e))))))))
 (defn invmaponpathsweq
   (pi X UU (pi Y UU (pi w (weq X Y) (pi x X (pi xp X
      (pi e (paths Y ((pr1 w) x) ((pr1 w) xp)) (paths X x xp)))))))
   (lam X (lam Y (lam w (lam x (lam xp (lam e
      (pathscomp0 X x (invmap X Y w ((pr1 w) x)) xp
        (pathsinv0 X (invmap X Y w ((pr1 w) x)) x (homotinvweqweq X Y w x))
        (pathscomp0 X (invmap X Y w ((pr1 w) x)) (invmap X Y w ((pr1 w) xp)) xp
          (maponpaths Y X (lam y (invmap X Y w y)) ((pr1 w) x) ((pr1 w) xp) e)
          (homotinvweqweq X Y w xp))))))))))
 (defn iscontrweqb
   (pi X UU (pi Y UU (pi w (weq X Y) (pi is (iscontr Y) (iscontr X)))))
   (lam X (lam Y (lam w (lam is
      (iscontrretract Y X (lam y (invmap X Y w y)) (pr1 w)
        (homotinvweqweq X Y w) is))))))
 (defn weqtransportbUAH
   (pi P (pi T UU UU)
      (pi R (pi X UU (pi Xp UU (pi w (weq X Xp) (pi p (P Xp) (P X)))))
        (pi r (pi X UU (pi p (P X) (paths (P X) (R X X (idweq X) p) p)))
          (pi X UU (pi Xp UU (pi w (weq X Xp) (pi pp (P Xp)
            (paths (P X) (R X Xp w pp)
                   (transportb UU P X Xp (weqtopaths X Xp w) pp)))))))))
   (lam P (lam R (lam r (lam X (lam Xp (lam w (lam pp
      (let uv (weqtopaths X Xp w)
        (pathscomp0 (P X)
          (R X Xp w pp)
          (R X Xp (eqweqmap X Xp uv) pp)
          (transportb UU P X Xp uv pp)
          (pathsinv0 (P X)
            (R X Xp (eqweqmap X Xp uv) pp)
            (R X Xp w pp)
            (maponpaths (weq X Xp) (P X) (lam v (R X Xp v pp))
              (eqweqmap X Xp uv) w (weqpathsweq X Xp w)))
          ((paths_rect
             (lam Xq (lam ep (pi q (P Xq)
               (paths (P X) (R X Xq (eqweqmap X Xq ep) q)
                            (transportb UU P X Xq ep q)))))
             (r X)
             uv)
           pp)))))))))))
 (defn isweqweqtransportbUAH
   (pi P (pi T UU UU)
      (pi R (pi X UU (pi Xp UU (pi w (weq X Xp) (pi p (P Xp) (P X)))))
        (pi r (pi X UU (pi p (P X) (paths (P X) (R X X (idweq X) p) p)))
          (pi X UU (pi Xp UU (pi w (weq X Xp)
            (isweq (P Xp) (P X) (lam pp (R X Xp w pp)))))))))
   (lam P (lam R (lam r (lam X (lam Xp (lam w
      (isweqhomot (P Xp) (P X)
        (lam pp (transportb UU P X Xp (weqtopaths X Xp w) pp))
        (lam pp (R X Xp w pp))
        (lam pp (pathsinv0 (P X)
                  (R X Xp w pp)
                  (transportb UU P X Xp (weqtopaths X Xp w) pp)
                  (weqtransportbUAH P R r X Xp w pp)))
        (isweqtransportb UU P X Xp (weqtopaths X Xp w))))))))))
 (defn isweqcompwithweqUAH
   (pi X UU (pi Xp UU (pi w (weq X Xp) (pi Y UU
      (isweq (pi x Xp Y) (pi x X Y) (lam f (lam x (f ((pr1 w) x)))))))))
   (lam X (lam Xp (lam w (lam Y
      (isweqweqtransportbUAH
        (lam T (pi t T Y))
        (lam X0 (lam X0p (lam w1 (lam f (lam x (f ((pr1 w1) x)))))))
        (lam X0 (lam f (idpath f)))
        X Xp w))))))
 (defn eqcor0UAH
   (pi X UU (pi Xp UU (pi w (weq X Xp) (pi Y UU
      (pi f1 (pi x Xp Y) (pi f2 (pi x Xp Y)
        (pi ee (paths (pi x X Y) (lam x (f1 ((pr1 w) x))) (lam x (f2 ((pr1 w) x))))
          (paths (pi x Xp Y) f1 f2))))))))
   (lam X (lam Xp (lam w (lam Y (lam f1 (lam f2 (lam ee
      (invmaponpathsweq (pi x Xp Y) (pi x X Y)
        (tpair (lam f (lam x (f ((pr1 w) x)))) (isweqcompwithweqUAH X Xp w Y))
        f1 f2 ee)))))))))
 (defn pathsspace (pi T UU UU) (lam T (total2 x T (coconusfromt T x))))
 (defn pathsspacetriple
   (pi T UU (pi t1 T (pi t2 T (pi e (paths T t1 t2) (pathsspace T)))))
   (lam T (lam t1 (lam t2 (lam e (tpair t1 (tpair t2 e)))))))
 (defn deltap (pi T UU (pi t T (pathsspace T)))
   (lam T (lam t (tpair t (tpair t (idpath t))))))
 (defn isweqdeltap (pi T UU (isweq T (pathsspace T) (deltap T)))
   (lam T (isweq_iso T (pathsspace T) (deltap T) (lam z (pr1 z))
      (lam t (idpath t))
      (lam z (total2_paths_f T (lam x (coconusfromt T x))
               (deltap T (pr1 z))
               z
               (idpath (pr1 z))
               (pathsinv0 (coconusfromt T (pr1 z))
                 (pr2 z)
                 (tpair (pr1 z) (idpath (pr1 z)))
                 ((pr2 (iscontrcoconusfromt T (pr1 z))) (pr2 z))))))))
 (defq apathpr1toprUAH
   (pi T UU (paths (pi z (pathsspace T) T)
              (lam z (pr1 z))
              (lam z (pr1 (pr2 z)))))
   (lam T (eqcor0UAH T (pathsspace T)
      (tpair (deltap T) (isweqdeltap T))
      T
      (lam z (pr1 z))
      (lam z (pr1 (pr2 z)))
      (idpath (lam t t)))))
 (defq funextfun
   (pi X UU (pi Y UU (pi f1 (pi x X Y) (pi f2 (pi x X Y)
      (pi e (pi x X (paths Y (f1 x) (f2 x)))
        (paths (pi x X Y) f1 f2))))))
   (lam X (lam Y (lam f1 (lam f2 (lam e
      (maponpaths (pi z (pathsspace Y) Y) (pi x X Y)
        (lam g (lam x (g (tpair (f1 x) (tpair (f2 x) (e x))))))
        (lam z (pr1 z))
        (lam z (pr1 (pr2 z)))
        (apathpr1toprUAH Y))))))))
 (defn funextempty
   (pi X UU (pi f (pi x X empty) (pi g (pi x X empty) (paths (pi x X empty) f g))))
   (lam X (lam f (lam g
      (funextfun X empty f g
        (lam x (fromempty (paths empty (f x) (g x)) (f x))))))))
 (defn natplusr0 (pi n nat (paths nat (add n 0) n))
   (lam n (nat_rect (lam m (paths nat (add m 0) m))
             (idpath 0)
             (lam k (lam IH (maponpaths nat nat (lam m (succ m)) (add k 0) k IH)))
             n)))
 (defq uu-funext-demo
   (paths (pi n nat nat) (lam n (add n 0)) (lam n n))
   (funextfun nat nat (lam n (add n 0)) (lam n n) natplusr0))
 (defn uu-let-demo (paths nat (let two 2 (add two two)) 4) (idpath 4)))

; funextsec by the funcontr route: sections retract onto a contractible fiber. proofs Qed
(test
 (defn toforallpaths
   (pi T UU (pi P (pi t T UU) (pi f (pi t T (P t)) (pi g (pi t T (P t))
      (pi e (paths (pi t T (P t)) f g) (pi t T (paths (P t) (f t) (g t))))))))
   (lam T (lam P (lam f (lam g (lam e (lam t
      (maponpaths (pi tq T (P tq)) (P t) (lam h (h t)) f g e))))))))
 (defn coconustot (pi T UU (pi t T UU))
   (lam T (lam t (total2 tp T (paths T tp t)))))
 (defn iscontrcoconustot (pi T UU (pi t T (iscontr (coconustot T t))))
   (lam T (lam t (tpair (tpair t (idpath t))
      (lam w (paths_rect
               (lam bp (lam ep (paths (coconustot T bp)
                                      (tpair (pr1 w) ep)
                                      (tpair bp (idpath bp)))))
               (idpath (tpair (pr1 w) (idpath (pr1 w))))
               (pr2 w)))))))
 (defq isweqpr1
   (pi X UU (pi P (pi x X UU) (pi is (pi x X (iscontr (P x)))
      (isweq (total2 x X (P x)) X (lam s (pr1 s))))))
   (lam X (lam P (lam is
      (isweq_iso (total2 x X (P x)) X (lam s (pr1 s))
        (lam x (tpair x (pr1 (is x))))
        (lam s (total2_paths_f X P
                 (tpair (pr1 s) (pr1 (is (pr1 s))))
                 s
                 (idpath (pr1 s))
                 (pathsinv0 (P (pr1 s)) (pr2 s) (pr1 (is (pr1 s)))
                   ((pr2 (is (pr1 s))) (pr2 s)))))
        (lam x (idpath x)))))))
 (defq isweqcontrcontr
   (pi X UU (pi Y UU (pi f (pi x X Y) (pi isx (iscontr X) (pi isy (iscontr Y)
      (isweq X Y f))))))
   (lam X (lam Y (lam f (lam isx (lam isy
      (isweq_iso X Y f (lam y (pr1 isx))
        (lam x (proofirrelevancecontr X isx (pr1 isx) x))
        (lam y (proofirrelevancecontr Y isy (f (pr1 isx)) y)))))))))
 (defq isweqrcompwithweqUAH
   (pi Y UU (pi Yp UU (pi w (weq Y Yp) (pi X UU
      (isweq (pi x X Y) (pi x X Yp) (lam a (lam x ((pr1 w) (a x)))))))))
   (lam Y (lam Yp (lam w (lam X
      (isweq_iso (pi x X Y) (pi x X Yp)
        (lam a (lam x ((pr1 w) (a x))))
        (lam ap (lam x (invmap Y Yp w (ap x))))
        (lam a (funextfun X Y (lam x (invmap Y Yp w ((pr1 w) (a x)))) a
                 (lam x (homotinvweqweq Y Yp w (a x)))))
        (lam ap (funextfun X Yp (lam x ((pr1 w) (invmap Y Yp w (ap x)))) ap
                 (lam x (homotweqinvweq Y Yp w (ap x)))))))))))
 (defq funcontrUAH
   (pi X UU (pi P (pi x X UU) (pi X0 (pi x X (iscontr (P x)))
      (iscontr (pi x X (P x))))))
   (lam X (lam P (lam X0
      (let W1 (the (weq (total2 xx X (P xx)) X)
               (tpair (lam s (pr1 s)) (isweqpr1 X P X0)))
        (iscontrretract
          (hfiber (pi x X (total2 xx X (P xx))) (pi x X X)
            (lam a (lam x ((pr1 W1) (a x))))
            (lam x x))
          (pi x X (P x))
          (lam se (lam x (transportf X P (pr1 ((pr1 se) x)) x
                    (toforallpaths X (lam q X)
                      (lam xx (pr1 ((pr1 se) xx))) (lam xx xx) (pr2 se) x)
                    (pr2 ((pr1 se) x)))))
          (lam a (tpair (lam x (tpair x (a x))) (idpath (lam x x))))
          (lam a (idpath a))
          ((isweqrcompwithweqUAH (total2 xx X (P xx)) X W1 X) (lam x x))))))))
 (defq funextcontrUAH
   (pi T UU (pi P (pi t T UU) (pi g (pi t T (P t))
      (iscontr (total2 f (pi t T (P t)) (pi t T (paths (P t) (f t) (g t))))))))
   (lam T (lam P (lam g
      (iscontrretract
        (pi t T (coconustot (P t) (g t)))
        (total2 f (pi t T (P t)) (pi t T (paths (P t) (f t) (g t))))
        (lam x (tpair (lam t (pr1 (x t))) (lam t (pr2 (x t)))))
        (lam y (lam t (tpair ((pr1 y) t) ((pr2 y) t))))
        (lam y (idpath y))
        (funcontrUAH T (lam t (coconustot (P t) (g t)))
          (lam t (iscontrcoconustot (P t) (g t)))))))))
 (defq funextsec
   (pi T UU (pi P (pi t T UU) (pi f (pi t T (P t)) (pi g (pi t T (P t))
      (pi e (pi t T (paths (P t) (f t) (g t)))
        (paths (pi t T (P t)) f g))))))
   (lam T (lam P (lam f (lam g (lam e
      (let CT (the UU (total2 h (pi t T (P t)) (pi t T (paths (P t) (h t) (g t)))))
        (maponpaths CT (pi t T (P t)) (lam z (pr1 z))
          (tpair f e)
          (tpair g (lam t (idpath (g t))))
          (proofirrelevancecontr CT
            (funextcontrUAH T P g)
            (tpair f e)
            (tpair g (lam t (idpath (g t)))))))))))))
 (defq uu-funextsec-demo
   (paths (pi n nat nat) (lam n (add n 0)) (lam n n))
   (funextsec nat (lam n nat) (lam n (add n 0)) (lam n n) natplusr0)))

; the girard canary: under type-in-type, but_seriously_the_world_explodes : empty checks.
; formers and the nat_rect tower stay transparent (descent's type must compute); proofs Qed
(test
 (defn wf (pi Flse UU (pi T UU UU))
   (lam Flse (lam T
      (total2 lt (pi x T (pi y T UU))
        (total2 tr (pi x T (pi y T (pi z T (pi p (lt x y) (pi q (lt y z) (lt x z))))))
          (pi h (pi n nat T)
            (pi ds (pi n nat (lt (h (succ n)) (h n)))
              Flse)))))))
 (defn wfs (pi Flse UU UU)
   (lam Flse (total2 T UU (wf Flse T))))
 (defn uset (pi Flse UU (pi w (wfs Flse) UU))
   (lam Flse (lam w (pr1 w))))
 (defn uord
   (pi Flse UU (pi w (wfs Flse) (pi x (uset Flse w) (pi y (uset Flse w) UU))))
   (lam Flse (lam w (pr1 (pr2 w)))))
 (defn trans
   (pi Flse UU (pi w (wfs Flse)
      (pi x (uset Flse w) (pi y (uset Flse w) (pi z (uset Flse w)
        (pi p (uord Flse w x y) (pi q (uord Flse w y z) (uord Flse w x z))))))))
   (lam Flse (lam w (pr1 (pr2 (pr2 w))))))
 (defn wfp
   (pi Flse UU (pi w (wfs Flse)
      (pi h (pi n nat (uset Flse w))
        (pi ds (pi n nat (uord Flse w (h (succ n)) (h n)))
          Flse))))
   (lam Flse (lam w (pr2 (pr2 (pr2 w))))))
 (defn wfs_wf_uord
   (pi Flse UU (pi v (wfs Flse) (pi w (wfs Flse) UU)))
   (lam Flse (lam v (lam w
      (total2 f (pi x (uset Flse v) (uset Flse w))
        (total2 hm (pi x (uset Flse v) (pi y (uset Flse v)
                     (pi p (uord Flse v x y) (uord Flse w (f x) (f y)))))
          (total2 y (uset Flse w)
            (pi x (uset Flse v) (uord Flse w (f x) y)))))))))
 (defn ufun
   (pi Flse UU (pi v (wfs Flse) (pi w (wfs Flse)
      (pi a (wfs_wf_uord Flse v w) (pi x (uset Flse v) (uset Flse w))))))
   (lam Flse (lam v (lam w (lam a (pr1 a))))))
 (defn homo
   (pi Flse UU (pi v (wfs Flse) (pi w (wfs Flse)
      (pi a (wfs_wf_uord Flse v w)
        (pi x (uset Flse v) (pi y (uset Flse v)
          (pi p (uord Flse v x y) (uord Flse w ((pr1 a) x) ((pr1 a) y)))))))))
   (lam Flse (lam v (lam w (lam a (pr1 (pr2 a)))))))
 (defn domi
   (pi Flse UU (pi v (wfs Flse) (pi w (wfs Flse)
      (pi a (wfs_wf_uord Flse v w) (uset Flse w)))))
   (lam Flse (lam v (lam w (lam a (pr1 (pr2 (pr2 a))))))))
 (defn domicom
   (pi Flse UU (pi v (wfs Flse) (pi w (wfs Flse)
      (pi a (wfs_wf_uord Flse v w)
        (pi x (uset Flse v) (uord Flse w ((pr1 a) x) (pr1 (pr2 (pr2 a)))))))))
   (lam Flse (lam v (lam w (lam a (pr2 (pr2 (pr2 a))))))))
 (defq wfs_wf_trans
   (pi Flse UU (pi x (wfs Flse) (pi y (wfs Flse) (pi z (wfs Flse)
      (pi f (wfs_wf_uord Flse x y) (pi g (wfs_wf_uord Flse y z)
        (wfs_wf_uord Flse x z)))))))
   (lam Flse (lam x (lam y (lam z (lam f (lam g
      (tpair (lam a ((pr1 g) ((pr1 f) a)))
        (tpair (lam x0 (lam y0 (lam pp
                 (homo Flse y z g ((pr1 f) x0) ((pr1 f) y0)
                   (homo Flse x y f x0 y0 pp)))))
          (tpair (domi Flse y z g)
            (lam x0
              (trans Flse z
                ((pr1 g) ((pr1 f) x0))
                ((pr1 g) (domi Flse x y f))
                (domi Flse y z g)
                (homo Flse y z g ((pr1 f) x0) (domi Flse x y f)
                  (domicom Flse x y f x0))
                (domicom Flse y z g (domi Flse x y f))))))))))))))
 (defn wfs_wf_wfp_shift
   (pi Flse UU (pi f (pi n nat (wfs Flse))
      (pi b (pi n nat (wfs_wf_uord Flse (f (succ n)) (f n)))
        (pi n nat (pi a (uset Flse (f n)) (uset Flse (f 0)))))))
   (lam Flse (lam f (lam b (lam n
      (nat_rect (lam m (pi a (uset Flse (f m)) (uset Flse (f 0))))
        (lam a a)
        (lam m (lam IH (lam x (IH ((pr1 (b m)) x)))))
        n))))))
 (defn wfs_wf_wfp_seq
   (pi Flse UU (pi f (pi n nat (wfs Flse))
      (pi b (pi n nat (wfs_wf_uord Flse (f (succ n)) (f n)))
        (pi n nat (uset Flse (f 0))))))
   (lam Flse (lam f (lam b (lam n
      ((wfs_wf_wfp_shift Flse f b n)
       (domi Flse (f (succ n)) (f n) (b n))))))))
 (defq wfs_wf_wfp_compshift
   (pi Flse UU (pi f (pi n nat (wfs Flse))
      (pi b (pi n nat (wfs_wf_uord Flse (f (succ n)) (f n)))
        (pi n nat (pi x (uset Flse (f n)) (pi y (uset Flse (f n))
          (pi p (uord Flse (f n) x y)
            (uord Flse (f 0)
              ((wfs_wf_wfp_shift Flse f b n) x)
              ((wfs_wf_wfp_shift Flse f b n) y)))))))))
   (lam Flse (lam f (lam b (lam n
      (nat_rect (lam m (pi x (uset Flse (f m)) (pi y (uset Flse (f m))
                   (pi p (uord Flse (f m) x y)
                     (uord Flse (f 0)
                       ((wfs_wf_wfp_shift Flse f b m) x)
                       ((wfs_wf_wfp_shift Flse f b m) y))))))
        (lam x (lam y (lam p p)))
        (lam m (lam IH (lam x (lam y (lam p
          (IH ((pr1 (b m)) x) ((pr1 (b m)) y)
              (homo Flse (f (succ m)) (f m) (b m) x y p)))))))
        n))))))
 (defq wfs_wf_wfp_desc
   (pi Flse UU (pi f (pi n nat (wfs Flse))
      (pi b (pi n nat (wfs_wf_uord Flse (f (succ n)) (f n)))
        (pi n nat
          (uord Flse (f 0)
            (wfs_wf_wfp_seq Flse f b (succ n))
            (wfs_wf_wfp_seq Flse f b n))))))
   (lam Flse (lam f (lam b (lam n
      (wfs_wf_wfp_compshift Flse f b n
        ((pr1 (b n)) (domi Flse (f (succ (succ n))) (f (succ n)) (b (succ n))))
        (domi Flse (f (succ n)) (f n) (b n))
        (domicom Flse (f (succ n)) (f n) (b n)
          (domi Flse (f (succ (succ n))) (f (succ n)) (b (succ n))))))))))
 (defn wfs_wf (pi Flse UU (wf Flse (wfs Flse)))
   (lam Flse
      (tpair (wfs_wf_uord Flse)
        (tpair (wfs_wf_trans Flse)
          (lam h (lam b
            (wfp Flse (h 0)
              (wfs_wf_wfp_seq Flse h b)
              (wfs_wf_wfp_desc Flse h b))))))))
 (defn wfs_wf_t (pi Flse UU (wfs Flse))
   (lam Flse (tpair (wfs Flse) (wfs_wf Flse))))
 (defn maxi_fun
   (pi Flse UU (pi w (wfs Flse) (pi x (uset Flse w) (wfs Flse))))
   (lam Flse (lam w (lam x
      (tpair (total2 y (uset Flse w) (uord Flse w y x))
        (tpair (lam a (lam bb (uord Flse w (pr1 a) (pr1 bb))))
          (tpair (lam x0 (lam y0 (lam z0 (lam p (lam q
                   (trans Flse w (pr1 x0) (pr1 y0) (pr1 z0) p q))))))
            (lam h (lam b
              (wfp Flse w (lam n (pr1 (h n))) b))))))))))
 (defq maxi_homo
   (pi Flse UU (pi w (wfs Flse) (pi x (uset Flse w) (pi y (uset Flse w)
      (pi p (uord Flse w x y)
        (wfs_wf_uord Flse (maxi_fun Flse w x) (maxi_fun Flse w y)))))))
   (lam Flse (lam w (lam x (lam y (lam p
      (tpair (lam z (tpair (pr1 z) (trans Flse w (pr1 z) x y (pr2 z) p)))
        (tpair (lam x0 (lam y0 (lam q q)))
          (tpair (tpair x p)
            (lam x0 (pr2 x0)))))))))))
 (defq maxidom
   (pi Flse UU (pi w (wfs Flse) (pi x (uset Flse w)
      (wfs_wf_uord Flse (maxi_fun Flse w x) w))))
   (lam Flse (lam w (lam x
      (tpair (lam z (pr1 z))
        (tpair (lam x0 (lam y0 (lam p p)))
          (tpair x
            (lam x0 (pr2 x0)))))))))
 (defq maxi
   (pi Flse UU (pi w (wfs Flse) (wfs_wf_uord Flse w (wfs_wf_t Flse))))
   (lam Flse (lam w
      (tpair (maxi_fun Flse w)
        (tpair (maxi_homo Flse w)
          (tpair w (maxidom Flse w)))))))
 (defq whoa
   (pi Flse UU (uord Flse (wfs_wf_t Flse) (wfs_wf_t Flse) (wfs_wf_t Flse)))
   (lam Flse (maxi Flse (wfs_wf_t Flse))))
 (defq irref
   (pi Flse UU (pi w (wfs Flse) (pi x (uset Flse w)
      (pi p (uord Flse w x x) Flse))))
   (lam Flse (lam w (lam x (lam p
      (wfp Flse w (lam n x) (lam n p)))))))
 (defq the_world_explodes (pi Flse UU Flse)
   (lam Flse (irref Flse (wfs_wf_t Flse) (wfs_wf_t Flse) (whoa Flse))))
 (defq but_seriously_the_world_explodes empty
   (the_world_explodes empty)))

; the hprop logic layer (Propositions.v): impred_isaprop the engine, isapropiscontr the
; keystone. formers stay transparent (the demos project them with pr1); proofs Qed
(test
 (defq isapropempty (isaprop empty)
   (lam x (lam y (fromempty (iscontr (paths empty x y)) x))))
 (defq isapropifcontr (pi X UU (pi is (iscontr X) (isaprop X)))
   (lam X (lam is (lam x (lam y
      (tpair
        (pathscomp0 X x (pr1 is) y ((pr2 is) x) (pathsinv0 X y (pr1 is) ((pr2 is) y)))
        (lam e (paths_rect
                 (lam yp (lam ep (paths (paths X x yp) ep
                           (pathscomp0 X x (pr1 is) yp ((pr2 is) x)
                             (pathsinv0 X yp (pr1 is) ((pr2 is) yp))))))
                 (pathsinv0 (paths X x x)
                   (pathscomp0 X x (pr1 is) x ((pr2 is) x)
                     (pathsinv0 X x (pr1 is) ((pr2 is) x)))
                   (idpath x)
                   (pathsinv0r X x (pr1 is) ((pr2 is) x)))
                 e))))))))
 (defq iscontraprop1 (pi X UU (pi ip (isaprop X) (pi x X (iscontr X))))
   (lam X (lam ip (lam x (tpair x (lam t (pr1 (ip t x))))))))
 (defq impred_isaprop
   (pi T UU (pi P (pi t T UU) (pi ip (pi t T (isaprop (P t)))
      (isaprop (pi t T (P t))))))
   (lam T (lam P (lam ip
      (invproofirrelevance (pi t T (P t))
        (lam f (lam g
          (funextsec T P f g (lam t (pr1 (ip t (f t) (g t))))))))))))
 (defq isapropiscontr (pi X UU (isaprop (iscontr X)))
   (lam X (invproofirrelevance (iscontr X)
      (lam c1 (lam c2
        (total2_paths_f X (lam c (pi t X (paths X t c)))
          c1 c2
          ((pr2 c2) (pr1 c1))
          (funextsec X (lam t (paths X t (pr1 c2)))
            (transportf X (lam c (pi t X (paths X t c))) (pr1 c1) (pr1 c2)
              ((pr2 c2) (pr1 c1)) (pr2 c1))
            (pr2 c2)
            (lam t (proofirrelevancecontr (paths X t (pr1 c2))
                     (isapropifcontr X c1 t (pr1 c2))
                     (transportf X (lam c (pi tq X (paths X tq c))) (pr1 c1) (pr1 c2)
                       ((pr2 c2) (pr1 c1)) (pr2 c1) t)
                     ((pr2 c2) t))))))))))
 (defq isapropisaprop (pi X UU (isaprop (isaprop X)))
   (lam X (impred_isaprop X (lam x (pi y X (iscontr (paths X x y))))
      (lam x (impred_isaprop X (lam y (iscontr (paths X x y)))
        (lam y (isapropiscontr (paths X x y))))))))
 (defq isapropisweq
   (pi X UU (pi Y UU (pi f (pi x X Y) (isaprop (isweq X Y f)))))
   (lam X (lam Y (lam f
      (impred_isaprop Y (lam y (iscontr (hfiber X Y f y)))
        (lam y (isapropiscontr (hfiber X Y f y))))))))
 (defq isapropdirprod
   (pi A UU (pi B UU (pi ipa (isaprop A) (pi ipb (isaprop B)
      (isaprop (total2 q A B))))))
   (lam A (lam B (lam ipa (lam ipb
      (invproofirrelevance (total2 q A B)
        (lam x (lam y
          (total2_paths_f A (lam q B) x y
            (pr1 (ipa (pr1 x) (pr1 y)))
            (pr1 (ipb (transportf A (lam q B) (pr1 x) (pr1 y)
                        (pr1 (ipa (pr1 x) (pr1 y))) (pr2 x))
                      (pr2 y))))))))))))
 (defq isapropneg (pi X UU (isaprop (pi x X empty)))
   (lam X (impred_isaprop X (lam x empty) (lam x isapropempty))))
 (defq isapropishinh (pi X UU (isaprop (ishinh_UU X)))
   (lam X (impred_isaprop hProp (lam P (pi f (pi x X (pr1 P)) (pr1 P)))
      (lam P (impred_isaprop (pi x X (pr1 P)) (lam f (pr1 P))
        (lam f (pr2 P)))))))
 (defn ishinh (pi X UU hProp)
   (lam X (tpair (ishinh_UU X) (isapropishinh X))))
 (defn htrue hProp (tpair unit isapropunit))
 (defn hfalse hProp (tpair empty isapropempty))
 (defn hconj (pi P hProp (pi Q hProp hProp))
   (lam P (lam Q (tpair (total2 q (pr1 P) (pr1 Q))
      (isapropdirprod (pr1 P) (pr1 Q) (pr2 P) (pr2 Q))))))
 (defn hdisj (pi P UU (pi Q UU hProp))
   (lam P (lam Q (ishinh (coprod P Q)))))
 (defn himpl (pi P UU (pi Q hProp hProp))
   (lam P (lam Q (tpair (pi p P (pr1 Q))
      (impred_isaprop P (lam p (pr1 Q)) (lam p (pr2 Q)))))))
 (defn hneg (pi P UU hProp)
   (lam P (tpair (pi p P empty) (isapropneg P))))
 (defn hexists (pi X UU (pi P (pi x X UU) hProp))
   (lam X (lam P (ishinh (total2 x X (P x))))))
 (defq hdisj_in1 (pi P UU (pi Q UU (pi p P (pr1 (hdisj P Q)))))
   (lam P (lam Q (lam p (hinhpr (coprod P Q) (ii1 p))))))
 (defq hdisj_in2 (pi P UU (pi Q UU (pi q Q (pr1 (hdisj P Q)))))
   (lam P (lam Q (lam q (hinhpr (coprod P Q) (ii2 q))))))
 (defq uu-htrue-demo (pr1 htrue) tt)
 (defq uu-hconj-demo (pr1 (hconj htrue htrue)) (tpair tt tt))
 (defq uu-hdisj-demo (pr1 (hdisj unit empty)) (hdisj_in1 unit empty tt))
 (defq uu-squash-demo (pr1 htrue)
   (hinhuniv unit htrue (lam u u) (hinhpr unit tt))))

; setquot (Sets.v): the impredicative set quotient; setquotunivcomm checks by idpath
(test
 (defn hrel (pi X UU UU) (lam X (pi x X (pi y X hProp))))
 (defn istrans (pi X UU (pi R (hrel X) UU))
   (lam X (lam R (pi x1 X (pi x2 X (pi x3 X
      (pi r1 (pr1 (R x1 x2)) (pi r2 (pr1 (R x2 x3)) (pr1 (R x1 x3))))))))))
 (defn isrefl (pi X UU (pi R (hrel X) UU))
   (lam X (lam R (pi x X (pr1 (R x x))))))
 (defn issymm (pi X UU (pi R (hrel X) UU))
   (lam X (lam R (pi x1 X (pi x2 X (pi r (pr1 (R x1 x2)) (pr1 (R x2 x1))))))))
 (defn iseqrel (pi X UU (pi R (hrel X) UU))
   (lam X (lam R (total2 q (istrans X R) (total2 q2 (isrefl X R) (issymm X R))))))
 (defn eqrel (pi X UU UU) (lam X (total2 R (hrel X) (iseqrel X R))))
 (defn eqreltrans (pi X UU (pi E (eqrel X) (istrans X (pr1 E))))
   (lam X (lam E (pr1 (pr2 E)))))
 (defn eqrelrefl (pi X UU (pi E (eqrel X) (isrefl X (pr1 E))))
   (lam X (lam E (pr1 (pr2 (pr2 E))))))
 (defn eqrelsymm (pi X UU (pi E (eqrel X) (issymm X (pr1 E))))
   (lam X (lam E (pr2 (pr2 (pr2 E))))))
 (defn hsubtype (pi X UU UU) (lam X (pi x X hProp)))
 (defn carrier (pi X UU (pi A (hsubtype X) UU))
   (lam X (lam A (total2 x X (pr1 (A x))))))
 (defn iseqclass (pi X UU (pi R (hrel X) (pi A (hsubtype X) UU)))
   (lam X (lam R (lam A
      (total2 q (ishinh_UU (carrier X A))
        (total2 q2
          (pi x1 X (pi x2 X (pi r (pr1 (R x1 x2)) (pi a (pr1 (A x1)) (pr1 (A x2))))))
          (pi x1 X (pi x2 X (pi a1 (pr1 (A x1)) (pi a2 (pr1 (A x2)) (pr1 (R x1 x2))))))))))))
 (defn eqax0
   (pi X UU (pi R (hrel X) (pi A (hsubtype X)
      (pi is (iseqclass X R A) (ishinh_UU (carrier X A))))))
   (lam X (lam R (lam A (lam is (pr1 is))))))
 (defn eqax1
   (pi X UU (pi R (hrel X) (pi A (hsubtype X)
      (pi is (iseqclass X R A)
        (pi x1 X (pi x2 X (pi r (pr1 (R x1 x2)) (pi a (pr1 (A x1)) (pr1 (A x2))))))))))
   (lam X (lam R (lam A (lam is (pr1 (pr2 is)))))))
 (defn eqax2
   (pi X UU (pi R (hrel X) (pi A (hsubtype X)
      (pi is (iseqclass X R A)
        (pi x1 X (pi x2 X (pi a1 (pr1 (A x1)) (pi a2 (pr1 (A x2)) (pr1 (R x1 x2))))))))))
   (lam X (lam R (lam A (lam is (pr2 (pr2 is)))))))
 (defn setquot (pi X UU (pi R (hrel X) UU))
   (lam X (lam R (total2 A (hsubtype X) (iseqclass X R A)))))
 (defn setquotpr (pi X UU (pi E (eqrel X) (pi x0 X (setquot X (pr1 E)))))
   (lam X (lam E (lam x0
      (tpair (lam x ((pr1 E) x0 x))
        (tpair (hinhpr (carrier X (lam x ((pr1 E) x0 x)))
                 (tpair x0 (eqrelrefl X E x0)))
          (tpair (lam x1 (lam x2 (lam r (lam a
                   (eqreltrans X E x0 x1 x2 a r)))))
            (lam x1 (lam x2 (lam a1 (lam a2
              (eqreltrans X E x1 x0 x2 (eqrelsymm X E x0 x1 a1) a2))))))))))))
 (defq isweqimplimpl
   (pi X UU (pi Y UU (pi f (pi x X Y) (pi g (pi y Y X)
      (pi ipx (isaprop X) (pi ipy (isaprop Y) (isweq X Y f)))))))
   (lam X (lam Y (lam f (lam g (lam ipx (lam ipy
      (isweq_iso X Y f g
        (lam x (pr1 (ipx (g (f x)) x)))
        (lam y (pr1 (ipy (f (g y)) y)))))))))))
 (defq hPropUnivalence
   (pi P hProp (pi Q hProp
      (pi f (pi p (pr1 P) (pr1 Q)) (pi g (pi q (pr1 Q) (pr1 P))
        (paths hProp P Q)))))
   (lam P (lam Q (lam f (lam g
      (let e (weqtopaths (pr1 P) (pr1 Q)
               (tpair f (isweqimplimpl (pr1 P) (pr1 Q) f g (pr2 P) (pr2 Q))))
        (total2_paths_f UU (lam Xq (isaprop Xq)) P Q
          e
          (pr1 ((isapropisaprop (pr1 Q))
                 (transportf UU (lam Xq (isaprop Xq)) (pr1 P) (pr1 Q) e (pr2 P))
                 (pr2 Q))))))))))
 (defq isapropiseqclass
   (pi X UU (pi R (hrel X) (pi A (hsubtype X) (isaprop (iseqclass X R A)))))
   (lam X (lam R (lam A
      (isapropdirprod (ishinh_UU (carrier X A))
        (total2 q2
          (pi x1 X (pi x2 X (pi r (pr1 (R x1 x2)) (pi a (pr1 (A x1)) (pr1 (A x2))))))
          (pi x1 X (pi x2 X (pi a1 (pr1 (A x1)) (pi a2 (pr1 (A x2)) (pr1 (R x1 x2)))))))
        (isapropishinh (carrier X A))
        (isapropdirprod
          (pi x1 X (pi x2 X (pi r (pr1 (R x1 x2)) (pi a (pr1 (A x1)) (pr1 (A x2))))))
          (pi x1 X (pi x2 X (pi a1 (pr1 (A x1)) (pi a2 (pr1 (A x2)) (pr1 (R x1 x2))))))
          (impred_isaprop X
            (lam x1 (pi x2 X (pi r (pr1 (R x1 x2)) (pi a (pr1 (A x1)) (pr1 (A x2))))))
            (lam x1 (impred_isaprop X
              (lam x2 (pi r (pr1 (R x1 x2)) (pi a (pr1 (A x1)) (pr1 (A x2)))))
              (lam x2 (impred_isaprop (pr1 (R x1 x2))
                (lam r (pi a (pr1 (A x1)) (pr1 (A x2))))
                (lam r (impred_isaprop (pr1 (A x1)) (lam a (pr1 (A x2)))
                  (lam a (pr2 (A x2))))))))))
          (impred_isaprop X
            (lam x1 (pi x2 X (pi a1 (pr1 (A x1)) (pi a2 (pr1 (A x2)) (pr1 (R x1 x2))))))
            (lam x1 (impred_isaprop X
              (lam x2 (pi a1 (pr1 (A x1)) (pi a2 (pr1 (A x2)) (pr1 (R x1 x2)))))
              (lam x2 (impred_isaprop (pr1 (A x1))
                (lam a1 (pi a2 (pr1 (A x2)) (pr1 (R x1 x2))))
                (lam a1 (impred_isaprop (pr1 (A x2)) (lam a2 (pr1 (R x1 x2)))
                  (lam a2 (pr2 (R x1 x2))))))))))))))))
 (defq iscompsetquotpr
   (pi X UU (pi E (eqrel X) (pi x X (pi xp X
      (pi a (pr1 ((pr1 E) x xp))
        (paths (setquot X (pr1 E)) (setquotpr X E x) (setquotpr X E xp)))))))
   (lam X (lam E (lam x (lam xp (lam a
      (let p (funextsec X (lam q hProp)
               (lam y ((pr1 E) x y))
               (lam y ((pr1 E) xp y))
               (lam y (hPropUnivalence ((pr1 E) x y) ((pr1 E) xp y)
                        (lam r (eqreltrans X E xp x y (eqrelsymm X E x xp a) r))
                        (lam r (eqreltrans X E x xp y a r)))))
        (total2_paths_f (hsubtype X) (lam A (iseqclass X (pr1 E) A))
          (setquotpr X E x) (setquotpr X E xp)
          p
          (pr1 ((isapropiseqclass X (pr1 E) (lam y ((pr1 E) xp y)))
                 (transportf (hsubtype X) (lam A (iseqclass X (pr1 E) A))
                   (lam y ((pr1 E) x y)) (lam y ((pr1 E) xp y))
                   p
                   (pr2 (setquotpr X E x)))
                 (pr2 (setquotpr X E xp))))))))))))
 (defn image (pi X UU (pi Y UU (pi f (pi x X Y) UU)))
   (lam X (lam Y (lam f (total2 y Y (ishinh_UU (hfiber X Y f y)))))))
 (defn prtoimage (pi X UU (pi Y UU (pi f (pi x X Y) (pi x X (image X Y f)))))
   (lam X (lam Y (lam f (lam x
      (tpair (f x) (hinhpr (hfiber X Y f (f x)) (tpair x (idpath (f x))))))))))
 (defq isapropsubtype
   (pi X UU (pi A (hsubtype X)
      (pi is (pi x1 X (pi x2 X (pi a1 (pr1 (A x1)) (pi a2 (pr1 (A x2)) (paths X x1 x2)))))
        (isaprop (carrier X A)))))
   (lam X (lam A (lam is
      (invproofirrelevance (carrier X A)
        (lam c1 (lam c2
          (total2_paths_f X (lam x (pr1 (A x))) c1 c2
            (is (pr1 c1) (pr1 c2) (pr2 c1) (pr2 c2))
            (pr1 ((pr2 (A (pr1 c2)))
                   (transportf X (lam x (pr1 (A x))) (pr1 c1) (pr1 c2)
                     (is (pr1 c1) (pr1 c2) (pr2 c1) (pr2 c2))
                     (pr2 c1))
                   (pr2 c2)))))))))))
 (defq isapropimeqclass
   (pi X UU (pi R (hrel X) (pi Y hSet (pi f (pi x X (pr1 Y))
      (pi is (pi x1 X (pi x2 X (pi r (pr1 (R x1 x2)) (paths (pr1 Y) (f x1) (f x2)))))
        (pi c (setquot X R)
          (isaprop (image (carrier X (pr1 c)) (pr1 Y) (lam xc (f (pr1 xc)))))))))))
   (lam X (lam R (lam Y (lam f (lam is (lam c
      (isapropsubtype (pr1 Y)
        (lam y (tpair
                 (ishinh_UU (hfiber (carrier X (pr1 c)) (pr1 Y) (lam xc (f (pr1 xc))) y))
                 (isapropishinh (hfiber (carrier X (pr1 c)) (pr1 Y) (lam xc (f (pr1 xc))) y))))
        (lam y1 (lam y2 (lam s1 (lam s2
          (hinhuniv (hfiber (carrier X (pr1 c)) (pr1 Y) (lam xc (f (pr1 xc))) y1)
            (tpair (paths (pr1 Y) y1 y2) ((pr2 Y) y1 y2))
            (lam fib1
              (hinhuniv (hfiber (carrier X (pr1 c)) (pr1 Y) (lam xc (f (pr1 xc))) y2)
                (tpair (paths (pr1 Y) y1 y2) ((pr2 Y) y1 y2))
                (lam fib2
                  (pathscomp0 (pr1 Y) y1 (f (pr1 (pr1 fib1))) y2
                    (pathsinv0 (pr1 Y) (f (pr1 (pr1 fib1))) y1 (pr2 fib1))
                    (pathscomp0 (pr1 Y) (f (pr1 (pr1 fib1))) (f (pr1 (pr1 fib2))) y2
                      (is (pr1 (pr1 fib1)) (pr1 (pr1 fib2))
                        (eqax2 X R (pr1 c) (pr2 c)
                          (pr1 (pr1 fib1)) (pr1 (pr1 fib2))
                          (pr2 (pr1 fib1)) (pr2 (pr1 fib2))))
                      (pr2 fib2))))
                s2))
            s1)))))))))))))
 (defn setquotuniv
   (pi X UU (pi R (hrel X) (pi Y hSet (pi f (pi x X (pr1 Y))
      (pi is (pi x1 X (pi x2 X (pi r (pr1 (R x1 x2)) (paths (pr1 Y) (f x1) (f x2)))))
        (pi c (setquot X R) (pr1 Y)))))))
   (lam X (lam R (lam Y (lam f (lam is (lam c
      (pr1 (hinhuniv (carrier X (pr1 c))
             (tpair (image (carrier X (pr1 c)) (pr1 Y) (lam xc (f (pr1 xc))))
                    (isapropimeqclass X R Y f is c))
             (lam xc (prtoimage (carrier X (pr1 c)) (pr1 Y) (lam xc2 (f (pr1 xc2))) xc))
             (eqax0 X R (pr1 c) (pr2 c)))))))))))
 (defq setquotunivcomm
   (pi X UU (pi E (eqrel X) (pi Y hSet (pi f (pi x X (pr1 Y))
      (pi is (pi x1 X (pi x2 X (pi r (pr1 ((pr1 E) x1 x2)) (paths (pr1 Y) (f x1) (f x2)))))
        (pi x X
          (paths (pr1 Y)
            (setquotuniv X (pr1 E) Y f is (setquotpr X E x))
            (f x))))))))
   (lam X (lam E (lam Y (lam f (lam is (lam x (idpath (f x)))))))))
 ; bool by the total relation: the induced constant map computes by idpath
 (defn uu-trivrel (eqrel bool)
   (tpair (lam x (lam y htrue))
      (tpair (lam x1 (lam x2 (lam x3 (lam r1 (lam r2 tt)))))
        (tpair (lam x tt)
          (lam x1 (lam x2 (lam r tt)))))))
 (defq uu-setquot-demo
   (paths (setquot bool (pr1 uu-trivrel))
           (setquotpr bool uu-trivrel true)
           (setquotpr bool uu-trivrel false))
   (iscompsetquotpr bool uu-trivrel true false tt))
 (defq uu-setquotuniv-demo
   (paths nat
      (setquotuniv bool (pr1 uu-trivrel) (tpair nat isasetnat)
        (lam b 7)
        (lam x1 (lam x2 (lam r (idpath 7))))
        (setquotpr bool uu-trivrel true))
      7)
   (idpath 7)))

; the quotient is a set, by path collapse (Kraus): hProp, products of sets, setquot
(test
 (defq uu-pathscollapse
   (pi X UU (pi x X (pi PF (pi y X UU)
      (pi s (pi y X (pi e (paths X x y) (PF y)))
        (pi p (pi y X (pi q (PF y) (paths X x y)))
          (pi ip (pi y X (isaprop (PF y)))
            (pi y X (isaprop (paths X x y)))))))))
   (lam X (lam x (lam PF (lam s (lam p (lam ip (lam y
      (invproofirrelevance (paths X x y)
        (lam e1 (lam e2
          (pathscomp0 (paths X x y)
            e1
            (pathscomp0 X x x y
              (pathsinv0 X x x (p x (s x (idpath x))))
              (p y (s y e1)))
            e2
            (paths_rect
              (lam yp (lam ep (paths (paths X x yp) ep
                        (pathscomp0 X x x yp
                          (pathsinv0 X x x (p x (s x (idpath x))))
                          (p yp (s yp ep))))))
              (pathsinv0 (paths X x x)
                (pathscomp0 X x x x
                  (pathsinv0 X x x (p x (s x (idpath x))))
                  (p x (s x (idpath x))))
                (idpath x)
                (pathsinv0l X x x (p x (s x (idpath x)))))
              e1)
            (pathscomp0 (paths X x y)
              (pathscomp0 X x x y
                (pathsinv0 X x x (p x (s x (idpath x))))
                (p y (s y e1)))
              (pathscomp0 X x x y
                (pathsinv0 X x x (p x (s x (idpath x))))
                (p y (s y e2)))
              e2
              (maponpaths (paths X x y) (paths X x y)
                (lam r (pathscomp0 X x x y
                         (pathsinv0 X x x (p x (s x (idpath x))))
                         r))
                (p y (s y e1))
                (p y (s y e2))
                (maponpaths (PF y) (paths X x y) (p y)
                  (s y e1) (s y e2)
                  (pr1 ((ip y) (s y e1) (s y e2)))))
              (pathsinv0 (paths X x y)
                e2
                (pathscomp0 X x x y
                  (pathsinv0 X x x (p x (s x (idpath x))))
                  (p y (s y e2)))
                (paths_rect
                  (lam yp (lam ep (paths (paths X x yp) ep
                            (pathscomp0 X x x yp
                              (pathsinv0 X x x (p x (s x (idpath x))))
                              (p yp (s yp ep))))))
                  (pathsinv0 (paths X x x)
                    (pathscomp0 X x x x
                      (pathsinv0 X x x (p x (s x (idpath x))))
                      (p x (s x (idpath x))))
                    (idpath x)
                    (pathsinv0l X x x (p x (s x (idpath x)))))
                  e2)))))))))))))))
 (defq isasethProp (isaset hProp)
   (lam P (lam Q
      (uu-pathscollapse hProp P
        (lam Qp (total2 q (pi a (pr1 P) (pr1 Qp)) (pi b (pr1 Qp) (pr1 P))))
        (lam Qp (lam e
          (paths_rect
            (lam Qpp (lam ep (total2 q (pi a (pr1 P) (pr1 Qpp)) (pi b (pr1 Qpp) (pr1 P)))))
            (tpair (lam a a) (lam b b))
            e)))
        (lam Qp (lam fg (hPropUnivalence P Qp (pr1 fg) (pr2 fg))))
        (lam Qp (isapropdirprod
                  (pi a (pr1 P) (pr1 Qp))
                  (pi b (pr1 Qp) (pr1 P))
                  (impred_isaprop (pr1 P) (lam a (pr1 Qp)) (lam a (pr2 Qp)))
                  (impred_isaprop (pr1 Qp) (lam b (pr1 P)) (lam b (pr2 P)))))
        Q))))
 (defq impred_isaset
   (pi T UU (pi P (pi t T UU) (pi ips (pi t T (isaset (P t)))
      (isaset (pi t T (P t))))))
   (lam T (lam P (lam ips (lam f
      (uu-pathscollapse (pi t T (P t)) f
        (lam g (pi t T (paths (P t) (f t) (g t))))
        (lam g (lam e (toforallpaths T P f g e)))
        (lam g (lam pf (funextsec T P f g pf)))
        (lam g (impred_isaprop T (lam t (paths (P t) (f t) (g t)))
                 (lam t (ips t (f t) (g t)))))))))))
 (defq isasethsubtype (pi X UU (isaset (hsubtype X)))
   (lam X (impred_isaset X (lam x hProp) (lam x isasethProp))))
 (defq isasetsetquot (pi X UU (pi R (hrel X) (isaset (setquot X R))))
   (lam X (lam R (lam c1
      (uu-pathscollapse (setquot X R) c1
        (lam c2 (paths (hsubtype X) (pr1 c1) (pr1 c2)))
        (lam c2 (lam e (maponpaths (setquot X R) (hsubtype X) (lam z (pr1 z)) c1 c2 e)))
        (lam c2 (lam q (total2_paths_f (hsubtype X) (lam A (iseqclass X R A)) c1 c2 q
                  (pr1 ((isapropiseqclass X R (pr1 c2))
                         (transportf (hsubtype X) (lam A (iseqclass X R A))
                           (pr1 c1) (pr1 c2) q (pr2 c1))
                         (pr2 c2))))))
        (lam c2 (isasethsubtype X (pr1 c1) (pr1 c2))))))))
 (defn hPropset hSet (tpair hProp isasethProp))
 (defn setquotinset (pi X UU (pi R (hrel X) hSet))
   (lam X (lam R (tpair (setquot X R) (isasetsetquot X R))))))

; naturalnumbers: the additive monoid laws (add computes on the left)
(test
 (defq natplusl0 (pi n nat (paths nat (add 0 n) n))
   (lam n (idpath n)))
 (defq natplusnsm
   (pi n nat (pi m nat (paths nat (add n (succ m)) (add (succ n) m))))
   (lam n (lam m
      (nat_rect (lam q (paths nat (add q (succ m)) (add (succ q) m)))
        (idpath (succ m))
        (lam k (lam IH (maponpaths nat nat (lam w (succ w))
                 (add k (succ m)) (add (succ k) m) IH)))
        n))))
 (defq natpluscomm
   (pi n nat (pi m nat (paths nat (add n m) (add m n))))
   (lam n (lam m
      (nat_rect (lam q (paths nat (add q m) (add m q)))
        (pathsinv0 nat (add m 0) m (natplusr0 m))
        (lam k (lam IH
          (pathscomp0 nat (add (succ k) m) (add (succ m) k) (add m (succ k))
            (maponpaths nat nat (lam w (succ w)) (add k m) (add m k) IH)
            (pathsinv0 nat (add m (succ k)) (add (succ m) k) (natplusnsm m k)))))
        n))))
 (defq natplusassoc
   (pi n nat (pi m nat (pi k nat (paths nat (add (add n m) k) (add n (add m k))))))
   (lam n (lam m (lam k
      (nat_rect (lam q (paths nat (add (add q m) k) (add q (add m k))))
        (idpath (add m k))
        (lam j (lam IH (maponpaths nat nat (lam w (succ w))
                 (add (add j m) k) (add j (add m k)) IH)))
        n)))))
 (defn mul (pi n nat (pi m nat nat))
   (lam n (lam m (nat_rect (lam q nat) 0 (lam p (lam pm (add pm m))) n))))
 (defq natmult0n (pi n nat (paths nat (mul 0 n) 0))
   (lam n (idpath 0)))
 (defq natmultn0 (pi n nat (paths nat (mul n 0) 0))
   (lam n
      (nat_rect (lam q (paths nat (mul q 0) 0))
        (idpath 0)
        (lam p (lam IH
          (pathscomp0 nat (add (mul p 0) 0) (mul p 0) 0
            (natplusr0 (mul p 0)) IH)))
        n)))
 (defq hinhfun
   (pi X UU (pi Y UU (pi f (pi x X Y) (pi w (ishinh_UU X) (ishinh_UU Y)))))
   (lam X (lam Y (lam f (lam w (lam P (lam g (w P (lam x (g (f x)))))))))))
 (defq hinhand
   (pi X UU (pi Y UU (pi w1 (ishinh_UU X) (pi w2 (ishinh_UU Y)
      (ishinh_UU (total2 q X Y))))))
   (lam X (lam Y (lam w1 (lam w2
      (lam P (lam g (w1 P (lam x (w2 P (lam y (g (tpair x y))))))))))))))

; the multiplicative monoid laws: mul right-appends, as UniMath's
(test
 (6 = (vof 0 '(mul 2 3)))
 (defq multsnm
   (pi n nat (pi m nat (paths nat (mul (succ n) m) (add m (mul n m)))))
   (lam n (lam m (natpluscomm (mul n m) m))))
 (defq multnsm
   (pi n nat (pi m nat (paths nat (mul n (succ m)) (add n (mul n m)))))
   (lam n (lam m
      (nat_rect (lam q (paths nat (mul q (succ m)) (add q (mul q m))))
        (idpath 0)
        (lam k (lam IH
          (pathscomp0 nat (mul (succ k) (succ m))
                          (add (add k (mul k m)) (succ m))
                          (add (succ k) (mul (succ k) m))
            (maponpaths nat nat (lam w (add w (succ m)))
              (mul k (succ m)) (add k (mul k m)) IH)
            (pathscomp0 nat (add (add k (mul k m)) (succ m))
                            (add k (add (mul k m) (succ m)))
                            (add (succ k) (mul (succ k) m))
              (natplusassoc k (mul k m) (succ m))
              (pathscomp0 nat (add k (add (mul k m) (succ m)))
                              (add k (add (succ (mul k m)) m))
                              (add (succ k) (mul (succ k) m))
                (maponpaths nat nat (lam w (add k w))
                  (add (mul k m) (succ m)) (add (succ (mul k m)) m)
                  (natplusnsm (mul k m) m))
                (natplusnsm k (add (mul k m) m)))))))
        n))))
 (defq natmultcomm
   (pi n nat (pi m nat (paths nat (mul n m) (mul m n))))
   (lam n (lam m
      (nat_rect (lam q (paths nat (mul q m) (mul m q)))
        (pathsinv0 nat (mul m 0) 0 (natmultn0 m))
        (lam k (lam IH
          (pathscomp0 nat (mul (succ k) m) (add m (mul k m)) (mul m (succ k))
            (multsnm k m)
            (pathscomp0 nat (add m (mul k m)) (add m (mul m k)) (mul m (succ k))
              (maponpaths nat nat (lam w (add m w)) (mul k m) (mul m k) IH)
              (pathsinv0 nat (mul m (succ k)) (add m (mul m k)) (multnsm m k))))))
        n))))
 (defq natrdistr
   (pi n nat (pi m nat (pi k nat
      (paths nat (mul (add n m) k) (add (mul n k) (mul m k))))))
   (lam n (lam m (lam k
      (nat_rect (lam q (paths nat (mul (add q m) k) (add (mul q k) (mul m k))))
        (idpath (mul m k))
        (lam j (lam IH
          (pathscomp0 nat (mul (add (succ j) m) k)
                          (add (add (mul j k) (mul m k)) k)
                          (add (mul (succ j) k) (mul m k))
            (maponpaths nat nat (lam w (add w k))
              (mul (add j m) k) (add (mul j k) (mul m k)) IH)
            (pathscomp0 nat (add (add (mul j k) (mul m k)) k)
                            (add (mul j k) (add (mul m k) k))
                            (add (mul (succ j) k) (mul m k))
              (natplusassoc (mul j k) (mul m k) k)
              (pathscomp0 nat (add (mul j k) (add (mul m k) k))
                              (add (mul j k) (add k (mul m k)))
                              (add (mul (succ j) k) (mul m k))
                (maponpaths nat nat (lam w (add (mul j k) w))
                  (add (mul m k) k) (add k (mul m k))
                  (natpluscomm (mul m k) k))
                (pathsinv0 nat (add (add (mul j k) k) (mul m k))
                               (add (mul j k) (add k (mul m k)))
                               (natplusassoc (mul j k) k (mul m k))))))))
        n)))))
 (defq natldistr
   (pi m nat (pi k nat (pi n nat
      (paths nat (mul n (add m k)) (add (mul n m) (mul n k))))))
   (lam m (lam k (lam n
      (nat_rect (lam q (paths nat (mul n (add q k)) (add (mul n q) (mul n k))))
        (maponpaths nat nat (lam w (add w (mul n k))) 0 (mul n 0)
          (pathsinv0 nat (mul n 0) 0 (natmultn0 n)))
        (lam j (lam IH
          (pathscomp0 nat (mul n (add (succ j) k))
                          (add n (mul n (add j k)))
                          (add (mul n (succ j)) (mul n k))
            (multnsm n (add j k))
            (pathscomp0 nat (add n (mul n (add j k)))
                            (add n (add (mul n j) (mul n k)))
                            (add (mul n (succ j)) (mul n k))
              (maponpaths nat nat (lam w (add n w))
                (mul n (add j k)) (add (mul n j) (mul n k)) IH)
              (pathscomp0 nat (add n (add (mul n j) (mul n k)))
                              (add (add n (mul n j)) (mul n k))
                              (add (mul n (succ j)) (mul n k))
                (pathsinv0 nat (add (add n (mul n j)) (mul n k))
                               (add n (add (mul n j) (mul n k)))
                               (natplusassoc n (mul n j) (mul n k)))
                (maponpaths nat nat (lam w (add w (mul n k)))
                  (add n (mul n j)) (mul n (succ j))
                  (pathsinv0 nat (mul n (succ j)) (add n (mul n j))
                    (multnsm n j))))))))
        m)))))
 (defq natmultassoc
   (pi n nat (pi m nat (pi k nat
      (paths nat (mul (mul n m) k) (mul n (mul m k))))))
   (lam n (lam m (lam k
      (nat_rect (lam q (paths nat (mul (mul q m) k) (mul q (mul m k))))
        (idpath 0)
        (lam j (lam IH
          (pathscomp0 nat (mul (mul (succ j) m) k)
                          (add (mul (mul j m) k) (mul m k))
                          (mul (succ j) (mul m k))
            (natrdistr (mul j m) m k)
            (maponpaths nat nat (lam w (add w (mul m k)))
              (mul (mul j m) k) (mul j (mul m k)) IH))))
        n)))))
 (defq natmultl1 (pi n nat (paths nat (mul 1 n) n))
   (lam n (idpath n)))
 (defq natmultr1 (pi n nat (paths nat (mul n 1) n))
   (lam n
      (pathscomp0 nat (mul n 1) (mul 1 n) n
        (natmultcomm n 1)
        (natmultl1 n)))))

; spec.v's numeral lane: uu-app n x = x^n
(test
 (defn uu-app (pi n nat (pi x nat nat))
   (lam n (lam x (nat_rect (lam q nat) 1 (lam p (lam r (mul x r))) n))))
 (defn uu-app-const1 (pi x nat (paths nat (uu-app 0 x) 1)) (lam x (idpath 1)))
 (defn uu-app-ident (pi x nat (paths nat (uu-app 1 x) x)) (lam x (natmultr1 x)))
 (defn uu-app-const-of-const (pi x nat (paths nat (uu-app (uu-app 0 0) x) x)) (lam x (natmultr1 x)))
 (defn uu-app-3-2 (paths nat (uu-app 3 2) 8) (idpath 8))
 (defn uu-app-tower (paths nat (uu-app (uu-app 2 3) 4) 262144) (idpath 262144)))

; --- predicative universes, beside the type-in-type checker, sharing vof and conv.
; --- levels: a charm, (lsuc l), (lv x); UU0 is `UU`, uu_l is ('U l); UU : UU fails ---
(: (lsuc l) (charm? l ? (l + 1) ['lsuc l])   ; fold concretes
   (lle a b)                                 ; conservative
   (? (a = b) 1
      (a = 0) 1
      (charm? a && charm? b) (a <= b)
      (two? b && <b = 'lsuc) (lle a <>b)
      0)
   (umax a b) (? (charm? a && charm? b) (a < b ? b a)
                 (lle a b) b  (lle b a) a  ['lmax a b])
   (ulvl u) (? (u = 'UU) 0 (two? u && <u = 'U) <>u 'no)   ; 'no: not a universe
   (umk l) (l @ 0 'UU ['U l])

   ; --- the solver: a level parses to (base offset), x<=y an edge of weight off(x)-off(y);
   ;     bellman-ford, a positive cycle unsat ---
   (lparse l) (? (charm? l) ['ground l]
                 (two? l && <l = 'lsuc) (lparse <>l @ p [<p (1 + <>p)])
                 (two? l && <l = 'lv) [l 0]
                 ['ground 0])
   (atomset prs) ({} @ s (map (e \ pins s <e 1 <>e 1) prs, keys s))
   (usat? cs)                                                          ; each [x y] means x <= y
   (: prs (map (c \ (: x (lparse <c) y (lparse <>c) [<x <y (<>x - <>y)])) cs)
      atoms (atomset prs) pot {} _ (map (a \ pin pot a 0) atoms)
      (relax1 z) (foldl (ch \ e \ (: uu (peep pot <e 0) w <>>e v (peep pot <>e 0)
                                     (uu + w > v ? (pin pot <>e (uu + w), 1) ch))) 0 prs)
      (spin1 k) (k < #atoms ? (relax1 (), spin1 (k + 1)) 0)
      (spin1 0,
       !(relax1 ())))                                              ; still moving: a positive cycle

   ; --- implicit inference: bare UU elaborates to a fresh level metavar ---
   MVC {}
   (freshmv z) (peep MVC 0 0 @ i (pin MVC 0 (i + 1), ['mv i]))
   (elab t) (? (t = 'UU) ['UU (freshmv ())]                       ; annotated (UU l) is left alone
              (two? t && <t = 'UU) t  (two? t) (map elab t)  t)

   (psym cx x)
   (? (x = 'UU) '(U 1)
      (elem x '(nat bool unit empty)) 'UU
      (x = 'zero) 'nat (x = 'tt) 'unit (elem x '(true false)) 'bool
      (assoc x cx @ e (e ? <>e (peep GLOB x 0 @ g (g ? <g (scare 'uu-unbound x))))))

   (sortof cx en d T) (ulvl (pinf cx en d T) @ l (l @ 'no (scare 'uu-not-a-type T) l))

   (cleq d ti t)
   (ulvl ti != 'no && ulvl t != 'no ? (usat? [[(ulvl ti) (ulvl t)]]) (conv d ti t))

   (predpi cx en d t)                                                  ; -> U_max(i,j)
   (: i (sortof cx en d <>>t) fr ['nv d]
      j (sortof (. [<>t (vof en <>>t)] cx) (. [<>t fr] en) (d + 1) <>>>t)
      (umk (umax i j)))

   (pinf-spine cx en d f as)
   (? (atom? as) f
      (<f = 'pi) (<as @ a (pchk cx en d a <>f, pinf-spine cx en d (capp <>>f (vof en a)) >as))
      (scare 'uu-not-a-pi as))

   (pinf cx en d t)
   (? (charm? t) 'nat
      (nom? t) (psym cx t)
      (<t @ h
       (? (two? h)      (pinf-spine cx en d (pinf cx en d h) >t)
          (h = 'UU)     (umk (lsuc <>t))
          (h = 'pi)     (predpi cx en d t)
          (h = 'total2) (predpi cx en d t)
          (h = 'paths)  (: l (sortof cx en d <>t) Av (vof en <>t)
                            (pchk cx en d <>>t Av, pchk cx en d <>>>t Av, umk l))
          (h = 'succ)   (pchk cx en d <>t 'nat, 'nat)
          (h = 'the)    (: l (sortof cx en d <>t) Tv (vof en <>t) (pchk cx en d <>>t Tv, Tv))
          (h = 'let)    (: x <>t Av (pinf cx en d <>>t) va (vof en <>>t) (pinf (. [x Av] cx) (. [x va] en) d <>>>t))
          (h = 'idpath) (: Av (pinf cx en d <>t) v (vof en <>t) ['paths Av v v])
          (pinf-spine cx en d (pinf cx en d h) >t))))

   (pchk cx en d t T)
   (? (two? t && <t = 'lam)
      (<T @ 'pi
       (: x <>t fr ['nv d] (pchk (. [x <>T] cx) (. [x fr] en) (d + 1) <>>t (capp <>>T fr)))
       (scare 'uu-lam-needs-pi t))
      (two? t && <t = 'idpath)
      (<T @ 'paths
       (: _ (pchk cx en d <>t <>T) v (vof en <>t) (conv d v <>>T && conv d v <>>>T ? 1 (scare 'uu-idpath-mismatch t)))
       (scare 'uu-idpath-needs-paths t))
      (two? t && <t = 'let)
       (: x <>t Av (pinf cx en d <>>t) va (vof en <>>t) (pchk (. [x Av] cx) (. [x va] en) d <>>>t T))
      (pinf cx en d t @ Ti (cleq d Ti T ? 1 (scare 'uu-type-mismatch t))))

   (pdefn nm T t) (: _ (sortof 0 0 0 T) Tv (vof 0 T) (pchk 0 0 0 t Tv, nm))    ; vof normalizes (UU l)

   (qdefn nm T t)
   (: eT (elab T) _ (sortof 0 0 0 eT) Tv (vof 0 eT) (pchk 0 0 0 (elab t) Tv, nm)))

; plain booleans, so a false one scares before the negative tests install their help
(test
 (1 = ulvl (pinf 0 0 0 'UU))                                                                  ; not UU:UU
 (0 = ulvl (pinf 0 0 0 'nat))
 (1 = sortof 0 0 0 '(pi T UU T))                                                              ; forall(T:UU),T lives in uu1
 (0 = sortof 0 0 0 '(pi x nat nat))
 ('p-const1 = pdefn 'p-const1 '(pi x nat (paths nat (uu-app 0 x) 1)) '(lam x (idpath 1)))
 ('p-ident = pdefn 'p-ident  '(pi x nat (paths nat (uu-app 1 x) x)) '(lam x (natmultr1 x)))
 !(cleq 0 (pinf 0 0 0 'UU) 'UU)                                                            ; the keystone
 (cleq 0 (pinf 0 0 0 'UU) '(U 1))
; --- universe polymorphism ---
 ('pidfun = pdefn 'pidfun '(pi T (UU (lv a)) (pi x T T)) '(lam T (lam x x)))
 ('(lsuc (lv a)) = sortof 0 0 0 '(pi T (UU (lv a)) (pi x T T)))                ; forall(T:UU_a),T->T : UU_{a+1}
 ('idf0 = pdefn 'idf0 '(pi T (UU 0) (pi x T T)) '(lam T (lam x x)))
 ('idf1 = pdefn 'idf1 '(pi T (UU 1) (pi x T T)) '(lam T (lam x x)))
 !(cleq 0 (pinf 0 0 0 '(UU (lv a))) (vof 0 '(UU (lv a))))                   ; uu_a : uu_a rejected
; --- usat?: global satisfiability, beyond the conservative lle ---
 (usat? [['(lv a) '(lv b)] ['(lv b) '(lv c)]])
 (usat? [['(lv a) '(lv b)] ['(lv b) '(lv a)]])
 !(usat? [['(lsuc (lv a)) '(lv a)]])
 !(usat? [['(lv a) '(lv b)] ['(lsuc (lv b)) '(lv a)]])                         ; a cross-site cycle no local check sees
 !(usat? [[1 0]])
; --- implicit inference: bare UU, levels inferred ---
 ('qidfun = qdefn 'qidfun '(pi T UU (pi x T T)) '(lam T (lam x x)))
 ('qfuncomp = qdefn 'qfuncomp
    '(pi X UU (pi Y UU (pi Z UU (pi f (pi x X Y) (pi g (pi y Y Z) (pi x X Z))))))
    '(lam X (lam Y (lam Z (lam f (lam g (lam x (g (f x))))))))))                 ; three independent levels

; the order: natgtb by double rect, natgth the hProp; succ-succ steps land on their IH
(test
 (defn natgtb (pi n nat (pi m nat bool))
   (lam n (nat_rect (lam q (pi m nat bool))
      (lam m false)
      (lam k (lam IH (lam m (nat_rect (lam r bool) true (lam j (lam u (IH j))) m))))
      n)))
 (vof 0 'true = vof 0 '(natgtb 5 3))
 (vof 0 'false = vof 0 '(natgtb 3 5))
 (vof 0 'false = vof 0 '(natgtb 4 4))
 (defn natgth (pi n nat (pi m nat hProp))
   (lam n (lam m (tpair (paths bool (natgtb n m) true)
                         (isasetbool (natgtb n m) true)))))
 (defq negnatgth0n
   (pi n nat (pi g (paths bool (natgtb 0 n) true) empty))
   (lam n (lam g (nopathsfalsetotrue g))))
 (defq natgthsnn (pi n nat (paths bool (natgtb (succ n) n) true))
   (lam n (nat_rect (lam q (paths bool (natgtb (succ q) q) true))
      (idpath true)
      (lam k (lam IH IH))
      n)))
 (defq natgthsn0 (pi n nat (paths bool (natgtb (succ n) 0) true))
   (lam n (idpath true)))
 (defq negnatgth0tois0
   (pi n nat (pi ng (pi g (paths bool (natgtb n 0) true) empty) (paths nat n 0)))
   (lam n (nat_rect (lam q (pi ng (pi g (paths bool (natgtb q 0) true) empty) (paths nat q 0)))
      (lam ng (idpath 0))
      (lam k (lam IH (lam ng (fromempty (paths nat (succ k) 0) (ng (natgthsn0 k))))))
      n)))
 (defq nat1gthtois0
   (pi n nat (pi g (paths bool (natgtb 1 n) true) (paths nat n 0)))
   (lam n (nat_rect (lam q (pi g (paths bool (natgtb 1 q) true) (paths nat q 0)))
      (lam g (idpath 0))
      (lam k (lam IH (lam g (fromempty (paths nat (succ k) 0) (negnatgth0n k g)))))
      n)))
 (defq istransnatgth
   (pi n nat (pi m nat (pi k nat (pi g (paths bool (natgtb n m) true)
      (pi h (paths bool (natgtb m k) true) (paths bool (natgtb n k) true))))))
   (lam n
      (nat_rect
        (lam q (pi m nat (pi k nat (pi g (paths bool (natgtb q m) true)
                 (pi h (paths bool (natgtb m k) true) (paths bool (natgtb q k) true))))))
        (lam m (lam k (lam g (lam h
          (fromempty (paths bool (natgtb 0 k) true) (negnatgth0n m g))))))
        (lam p (lam IHn
          (lam m (nat_rect
            (lam r (pi k nat (pi g (paths bool (natgtb (succ p) r) true)
                     (pi h (paths bool (natgtb r k) true)
                       (paths bool (natgtb (succ p) k) true)))))
            (lam k (lam g (lam h
              (fromempty (paths bool (natgtb (succ p) k) true) (negnatgth0n k h)))))
            (lam q (lam u
              (lam k (nat_rect
                (lam s (pi g (paths bool (natgtb (succ p) (succ q)) true)
                         (pi h (paths bool (natgtb (succ q) s) true)
                           (paths bool (natgtb (succ p) s) true))))
                (lam g (lam h (idpath true)))
                (lam j (lam v (lam g (lam h (IHn q j g h)))))
                k))))
            m))))
        n)))
 (defq isirreflnatgth
   (pi n nat (pi g (paths bool (natgtb n n) true) empty))
   (lam n (nat_rect (lam q (pi g (paths bool (natgtb q q) true) empty))
      (lam g (negnatgth0n 0 g))
      (lam k (lam IH IH))
      n)))
 (defq isasymmnatgth
   (pi n nat (pi m nat (pi g (paths bool (natgtb n m) true)
      (pi h (paths bool (natgtb m n) true) empty))))
   (lam n (lam m (lam g (lam h
      (isirreflnatgth n (istransnatgth n m n g h))))))))

; monotonicity: the strict order meets the monoids, every succ step on its own IH
(test
 (defq natgthandplusl
   (pi n nat (pi m nat (pi k nat (pi g (paths bool (natgtb n m) true)
      (paths bool (natgtb (add k n) (add k m)) true)))))
   (lam n (lam m (lam k (lam g
      (nat_rect (lam q (paths bool (natgtb (add q n) (add q m)) true))
        g
        (lam p (lam IH IH))
        k))))))
 (defq natgthandplusr
   (pi n nat (pi m nat (pi k nat (pi g (paths bool (natgtb n m) true)
      (paths bool (natgtb (add n k) (add m k)) true)))))
   (lam n (lam m (lam k (lam g
      (pathscomp0 bool (natgtb (add n k) (add m k)) (natgtb (add k n) (add k m)) true
        (pathscomp0 bool (natgtb (add n k) (add m k)) (natgtb (add k n) (add m k)) (natgtb (add k n) (add k m))
          (maponpaths nat bool (lam w (natgtb w (add m k))) (add n k) (add k n) (natpluscomm n k))
          (maponpaths nat bool (lam w (natgtb (add k n) w)) (add m k) (add k m) (natpluscomm m k)))
        (natgthandplusl n m k g)))))))
 (defq natgthandmultl
   (pi n nat (pi m nat (pi k nat (pi g (paths bool (natgtb n m) true)
      (paths bool (natgtb (mul (succ k) n) (mul (succ k) m)) true)))))
   (lam n (lam m (lam k (lam g
      (nat_rect (lam q (paths bool (natgtb (mul (succ q) n) (mul (succ q) m)) true))
        g
        (lam p (lam IH
          (istransnatgth (add (mul (succ p) n) n) (add (mul (succ p) m) n) (add (mul (succ p) m) m)
            (natgthandplusr (mul (succ p) n) (mul (succ p) m) n IH)
            (natgthandplusl n m (mul (succ p) m) g))))
        k))))))
 (vof 0 'true = vof 0 '(natgtb (add 3 5) (add 3 2)))
 (vof 0 'true = vof 0 '(natgtb (mul 2 5) (mul 2 2))))

; the order is decidable and total: natgthorleh is one bool_rect on natgtb, no induction
(test
 (defn natlth (pi n nat (pi m nat hProp))
   (lam n (lam m (natgth m n))))
 (defn natleh (pi n nat (pi m nat hProp))
   (lam n (lam m (tpair (paths bool (natgtb n m) false) (isasetbool (natgtb n m) false)))))
 (defn natgeh (pi n nat (pi m nat hProp))
   (lam n (lam m (natleh m n))))
 (defn natgthorleh
   (pi n nat (pi m nat (coprod (paths bool (natgtb n m) true) (paths bool (natgtb n m) false))))
   (lam n (lam m
      (bool_rect (lam b (coprod (paths bool b true) (paths bool b false)))
        (ii1 (idpath true))
        (ii2 (idpath false))
        (natgtb n m)))))
 ; the dichotomy computes: 5>3 lands left, 3<5 right
 (vof 0 'true = vof 0 '(coprod_rect (lam c bool) (lam l true) (lam r false) (natgthorleh 5 3)))
 (vof 0 'false = vof 0 '(coprod_rect (lam c bool) (lam l true) (lam r false) (natgthorleh 3 5))))

; natleh is a partial order on its "natgtb is false" carrier
(test
 (defq isreflnatleh (pi n nat (paths bool (natgtb n n) false))
   (lam n (nat_rect (lam q (paths bool (natgtb q q) false))
      (idpath false)
      (lam k (lam IH IH))
      n)))
 (defq istransnatleh
   (pi n nat (pi m nat (pi k nat (pi g (paths bool (natgtb n m) false)
      (pi h (paths bool (natgtb m k) false) (paths bool (natgtb n k) false))))))
   (lam n
      (nat_rect
        (lam q (pi m nat (pi k nat (pi g (paths bool (natgtb q m) false)
                 (pi h (paths bool (natgtb m k) false) (paths bool (natgtb q k) false))))))
        (lam m (lam k (lam g (lam h (idpath false)))))
        (lam p (lam IHn
          (lam m (nat_rect
            (lam r (pi k nat (pi g (paths bool (natgtb (succ p) r) false)
                     (pi h (paths bool (natgtb r k) false)
                       (paths bool (natgtb (succ p) k) false)))))
            (lam k (lam g (lam h
              (fromempty (paths bool (natgtb (succ p) k) false) (nopathstruetofalse g)))))
            (lam q (lam u
              (lam k (nat_rect
                (lam s (pi g (paths bool (natgtb (succ p) (succ q)) false)
                         (pi h (paths bool (natgtb (succ q) s) false)
                           (paths bool (natgtb (succ p) s) false))))
                (lam g (lam h (fromempty (paths bool (natgtb (succ p) 0) false) (nopathstruetofalse h))))
                (lam j (lam v (lam g (lam h (IHn q j g h)))))
                k))))
            m))))
        n)))
 (defq isantisymmnatleh
   (pi n nat (pi m nat (pi g (paths bool (natgtb n m) false)
      (pi h (paths bool (natgtb m n) false) (paths nat n m)))))
   (lam n
      (nat_rect
        (lam q (pi m nat (pi g (paths bool (natgtb q m) false)
                 (pi h (paths bool (natgtb m q) false) (paths nat q m)))))
        (lam m (nat_rect
          (lam r (pi g (paths bool (natgtb 0 r) false)
                   (pi h (paths bool (natgtb r 0) false) (paths nat 0 r))))
          (lam g (lam h (idpath 0)))
          (lam mp (lam u (lam g (lam h
            (fromempty (paths nat 0 (succ mp)) (nopathstruetofalse h))))))
          m))
        (lam p (lam IHn
          (lam m (nat_rect
            (lam r (pi g (paths bool (natgtb (succ p) r) false)
                     (pi h (paths bool (natgtb r (succ p)) false) (paths nat (succ p) r))))
            (lam g (lam h (fromempty (paths nat (succ p) 0) (nopathstruetofalse g))))
            (lam q (lam u (lam g (lam h
              (maponpaths nat nat (lam w (succ w)) p q (IHn q g h))))))
            m))))
        n))))

; natleh <-> not natgth: the bool tautology (b = false) <-> not (b = true), no induction
(test
 (defq natlehtonegnatgth
   (pi n nat (pi m nat (pi p (paths bool (natgtb n m) false)
      (pi q (paths bool (natgtb n m) true) empty))))
   (lam n (lam m (lam p (lam q
      (nopathstruetofalse
        (pathscomp0 bool true (natgtb n m) false
          (pathsinv0 bool (natgtb n m) true q) p)))))))
 (defq negnatgthtoleh
   (pi n nat (pi m nat (pi ng (pi q (paths bool (natgtb n m) true) empty)
      (paths bool (natgtb n m) false))))
   (lam n (lam m (lam ng
      ((bool_rect (lam b (pi g (pi q (paths bool b true) empty) (paths bool b false)))
         (lam g (fromempty (paths bool true false) (g (idpath true))))
         (lam g (idpath false))
         (natgtb n m)) ng)))))
 (defq natlthtoleh
   (pi n nat (pi m nat (pi g (paths bool (natgtb m n) true) (paths bool (natgtb n m) false))))
   (lam n (lam m (lam g
      (negnatgthtoleh n m (lam q (isasymmnatgth n m q g))))))))

; truncated subtraction: 0 - m and (succ k) - (succ j) are definitional
(test
 (defn natminus (pi n nat (pi m nat nat))
   (lam n (nat_rect (lam x (pi m nat nat))
      (lam m 0)
      (lam k (lam IH (lam m (nat_rect (lam y nat)
         (succ k)
         (lam j (lam u (IH j)))
         m))))
      n)))
 (defq natminus0n (pi n nat (paths nat (natminus 0 n) 0))
   (lam n (idpath 0)))
 (defq natminusn0 (pi n nat (paths nat (natminus n 0) n))
   (lam n (nat_rect (lam q (paths nat (natminus q 0) q))
      (idpath 0)
      (lam k (lam IH (idpath (succ k))))
      n)))
 (defq natminusnn (pi n nat (paths nat (natminus n n) 0))
   (lam n (nat_rect (lam q (paths nat (natminus q q) 0))
      (idpath 0)
      (lam k (lam IH IH))
      n)))
 (defq natlehsucc
   (pi a nat (pi k nat (pi g (paths bool (natgtb a k) false) (paths bool (natgtb a (succ k)) false))))
   (lam a (nat_rect
      (lam q (pi k nat (pi g (paths bool (natgtb q k) false) (paths bool (natgtb q (succ k)) false))))
      (lam k (lam g (idpath false)))
      (lam a' (lam IH
        (lam k (nat_rect
           (lam r (pi g (paths bool (natgtb (succ a') r) false) (paths bool (natgtb (succ a') (succ r)) false)))
           (lam g (fromempty (paths bool (natgtb (succ a') (succ 0)) false) (nopathstruetofalse g)))
           (lam k' (lam u (lam g (IH k' g))))
           k))))
      a)))
 (defq natminusleh
   (pi n nat (pi m nat (paths bool (natgtb (natminus n m) n) false)))
   (lam n (nat_rect (lam q (pi m nat (paths bool (natgtb (natminus q m) q) false)))
      (lam m (idpath false))
      (lam k (lam IHn
        (lam m (nat_rect (lam r (paths bool (natgtb (natminus (succ k) r) (succ k)) false))
           (isreflnatleh k)
           (lam j (lam u (natlehsucc (natminus k j) k (IHn j))))
           m))))
      n)))
 (vof 0 '2 = vof 0 '(natminus 5 3))
 (vof 0 '0 = vof 0 '(natminus 2 5)))

; natminusplusnmm: m <= n gives (n - m) + m = n, a double rect down natminus's shape
(test
 (defq natminusplusnmm
   (pi n nat (pi m nat (pi h (paths bool (natgtb m n) false) (paths nat (add (natminus n m) m) n))))
   (lam n
      (nat_rect
        (lam q (pi m nat (pi h (paths bool (natgtb m q) false) (paths nat (add (natminus q m) m) q))))
        (lam m (nat_rect
           (lam r (pi h (paths bool (natgtb r 0) false) (paths nat (add (natminus 0 r) r) 0)))
           (lam h (idpath 0))
           (lam m' (lam u (lam h
              (fromempty (paths nat (add (natminus 0 (succ m')) (succ m')) 0) (nopathstruetofalse h)))))
           m))
        (lam n' (lam IHn
          (lam m (nat_rect
             (lam r (pi h (paths bool (natgtb r (succ n')) false) (paths nat (add (natminus (succ n') r) r) (succ n'))))
             (lam h (natplusr0 (succ n')))
             (lam m' (lam u (lam h
                (pathscomp0 nat
                   (add (natminus (succ n') (succ m')) (succ m'))
                   (add (succ (natminus n' m')) m')
                   (succ n')
                   (natplusnsm (natminus n' m') m')
                   (maponpaths nat nat (lam w (succ w)) (add (natminus n' m') m') n' (IHn m' h))))))
             m))))
        n)))
 (vof 0 '7 = vof 0 '(add (natminus 7 3) 3)))   ; (7-3)+3 computes to 7

; natminus is monotone in the minuend, antitone in the subtrahend: triple rects down its shape
(test
 (defq natlehandminusl
   (pi n nat (pi m nat (pi k nat (pi h (paths bool (natgtb n m) false)
      (paths bool (natgtb (natminus n k) (natminus m k)) false)))))
   (lam n
      (nat_rect
        (lam q (pi m nat (pi k nat (pi h (paths bool (natgtb q m) false)
                 (paths bool (natgtb (natminus q k) (natminus m k)) false)))))
        (lam m (lam k (lam h (idpath false))))
        (lam n' (lam IHn
          (lam m (nat_rect
             (lam mr (pi k nat (pi h (paths bool (natgtb (succ n') mr) false)
                      (paths bool (natgtb (natminus (succ n') k) (natminus mr k)) false))))
             (lam k (lam h (fromempty (paths bool (natgtb (natminus (succ n') k) (natminus 0 k)) false) (nopathstruetofalse h))))
             (lam m' (lam um
               (lam k (nat_rect
                  (lam kr (pi h (paths bool (natgtb (succ n') (succ m')) false)
                           (paths bool (natgtb (natminus (succ n') kr) (natminus (succ m') kr)) false)))
                  (lam h h)
                  (lam k' (lam uk (lam h (IHn m' k' h))))
                  k))))
             m))))
        n)))
 (defq natlehandminusr
   (pi n nat (pi m nat (pi k nat (pi h (paths bool (natgtb k m) false)
      (paths bool (natgtb (natminus n m) (natminus n k)) false)))))
   (lam n
      (nat_rect
        (lam q (pi m nat (pi k nat (pi h (paths bool (natgtb k m) false)
                 (paths bool (natgtb (natminus q m) (natminus q k)) false)))))
        (lam m (lam k (lam h (idpath false))))
        (lam n' (lam IHn
          (lam m (nat_rect
             (lam mr (pi k nat (pi h (paths bool (natgtb k mr) false)
                      (paths bool (natgtb (natminus (succ n') mr) (natminus (succ n') k)) false))))
             (lam k (nat_rect
                (lam kr (pi h (paths bool (natgtb kr 0) false)
                         (paths bool (natgtb (natminus (succ n') 0) (natminus (succ n') kr)) false)))
                (lam h (isreflnatleh n'))
                (lam k' (lam uk (lam h (fromempty (paths bool (natgtb (natminus (succ n') 0) (natminus (succ n') (succ k'))) false) (nopathstruetofalse h)))))
                k))
             (lam m' (lam um
               (lam k (nat_rect
                  (lam kr (pi h (paths bool (natgtb kr (succ m')) false)
                           (paths bool (natgtb (natminus (succ n') (succ m')) (natminus (succ n') kr)) false)))
                  (lam h (natlehsucc (natminus n' m') n' (natminusleh n' m')))
                  (lam k' (lam uk (lam h (IHn m' k' h))))
                  k))))
             m))))
        n))))

; --- the StackSet model, lux's zipper. lists are (Σ n, vec n) at nat: a universe
; --- variable only in a body strands the Lean export on a metavariable ---
(test
 (defn nvec (pi n nat UU)
   (lam n (nat_rect (lam q UU) unit (lam k (lam r (total2 h nat r))) n)))
 (defn nlist UU (total2 n nat (nvec n)))
 (defn nnil nlist (tpair 0 tt))
 (defn ncons (pi x nat (pi l nlist nlist))
   (lam x (lam l (tpair (succ (pr1 l)) (tpair x (pr2 l))))))
 (defn nlen (pi l nlist nat) (lam l (pr1 l)))
 (defn lapp (pi a nlist (pi b nlist nlist))
   (lam a (lam b ((nat_rect (lam q (pi v (nvec q) nlist))
                     (lam v b)
                     (lam k (lam IH (lam v (ncons (pr1 v) (IH (pr2 v))))))
                     (pr1 a))
                   (pr2 a)))))
 (defn lrev (pi a nlist nlist)
   (lam a ((nat_rect (lam q (pi v (nvec q) nlist))
              (lam v nnil)
              (lam k (lam IH (lam v (lapp (IH (pr2 v)) (ncons (pr1 v) nnil)))))
              (pr1 a))
            (pr2 a)))))

; --- decidable equality and the duplicate hunt, all booleans ---
(test
 (defn orb (pi a bool (pi b bool bool))
   (lam a (lam b (bool_rect (lam x bool) true b a))))
 (defn andb (pi a bool (pi b bool bool))
   (lam a (lam b (bool_rect (lam x bool) b false a))))
 (defn npred (pi m nat nat) (lam m (nat_rect (lam q nat) 0 (lam j (lam r j)) m)))
 (defn niszero (pi m nat bool) (lam m (nat_rect (lam q bool) true (lam j (lam r false)) m)))
 ; one recursive call per level: a fold value riding the outer IH blows up under NbE
 (defn nateqb (pi n nat (pi m nat bool))
   (lam n ((nat_rect (lam q (pi m nat bool))
              (lam m (niszero m))
              (lam k (lam IH (lam m (bool_rect (lam x bool) false (IH (npred m)) (niszero m)))))
              n))))
 (defn memb (pi w nat (pi l nlist bool))
   (lam w (lam l ((nat_rect (lam q (pi v (nvec q) bool))
                     (lam v false)
                     (lam k (lam IH (lam v (orb (nateqb w (pr1 v)) (IH (pr2 v))))))
                     (pr1 l))
                   (pr2 l)))))
 (defn nodupb (pi l nlist bool)
   (lam l ((nat_rect (lam q (pi v (nvec q) bool))
              (lam v true)
              (lam k (lam IH (lam v (andb (negb (memb (pr1 v) (tpair k (pr2 v)))) (IH (pr2 v))))))
              (pr1 l))
            (pr2 l))))
 (vof 0 'true  = vof 0 '(nateqb 3 3))
 (vof 0 'false = vof 0 '(nateqb 3 4))
 (vof 0 'true  = vof 0 '(memb 9 (ncons 7 (ncons 9 nnil))))
 (vof 0 'false = vof 0 '(memb 8 (ncons 7 (ncons 9 nnil)))))

; --- the uu2l bridges are untrusted: every pin is checked vof against lof ---
(bridge 'add (n \ m \ n + m),
 bridge 'niszero (m \ m @ 0 'true 'false),
 bridge 'npred (m \ m @ 0 0 (m - 1)),
 bridge 'nateqb (n \ m \ n @ ^m 'true 'false),
 0)
(test
 ((vof 0 '(add 2 3)) = (lof '(add 2 3)))
 ((vof 0 '(add 0 7)) = (lof '(add 0 7)))
 ((vof 0 '(niszero 3)) = (lof '(niszero 3)))
 ((vof 0 '(niszero 0)) = (lof '(niszero 0)))
 ((vof 0 '(npred 4)) = (lof '(npred 4)))
 ((vof 0 '(npred 0)) = (lof '(npred 0)))
 ((vof 0 '(nateqb 3 3)) = (lof '(nateqb 3 3)))
 ((vof 0 '(nateqb 3 4)) = (lof '(nateqb 3 4)))
; constructors, eliminators, an unbridged global, currying, a defq's sealed neutral
 ((vof 0 '(tpair (add 1 1) tt)) = (lof '(tpair (add 1 1) tt)))
 ((vof 0 '(ii1 (add 2 2))) = (lof '(ii1 (add 2 2))))
 ((vof 0 '(negb (negb false))) = (lof '(negb (negb false))))
 ((vof 0 '(uu-fromsum (ii2 true))) = (lof '(uu-fromsum (ii2 true))))
 ((vof 0 '(memb 9 (ncons 7 (ncons 9 nnil)))) = (lof '(memb 9 (ncons 7 (ncons 9 nnil)))))
 ((vof 0 '(lrev (ncons 1 (ncons 2 nnil)))) = (lof '(lrev (ncons 1 (ncons 2 nnil)))))
 ((vof 0 '(idpath (add 1 2))) = (lof '(idpath (add 1 2))))
; both eliminators compile to kseq, whose operands the translator hands over swapped
 ((vof 0 '(unit_rect (lam x nat) 7 tt)) = (lof '(unit_rect (lam x nat) 7 tt)))
 ((vof 0 '(paths_rect (lam b (lam p nat)) 5 (idpath 2)))
  = (lof '(paths_rect (lam b (lam p nat)) 5 (idpath 2)))))

; --- the stack substrate: focus x up x down, nonempty by construction; the moves are
; --- generated into test/uuwm.l ---
(test
 (defn stk UU (total2 f nat (total2 u nlist nlist)))
 (defn zmk (pi f nat (pi u nlist (pi d nlist stk)))
   (lam f (lam u (lam d (tpair f (tpair u d))))))
 (defn zfoc (pi z stk nat) (lam z (pr1 z)))
 (defn zup  (pi z stk nlist) (lam z (pr1 (pr2 z))))
 (defn zdn  (pi z stk nlist) (lam z (pr2 (pr2 z))))
 (defn zcount (pi z stk nat)
   (lam z (succ (add (nlen (zup z)) (nlen (zdn z)))))))

; --- the defaulting projections, hd0/tl0: how a translated move reads a row ---
(test
 (defn hd0 (pi l nlist nat)
   (lam l ((nat_rect (lam q (pi v (nvec q) nat))
              (lam v 0)
              (lam k (lam IH (lam v (pr1 v))))
              (pr1 l))
            (pr2 l))))
 (defn tl0 (pi l nlist nlist)
   (lam l ((nat_rect (lam q (pi v (nvec q) nlist))
              (lam v nnil)
              (lam k (lam IH (lam v (tpair k (pr2 v)))))
              (pr1 l))
            (pr2 l)))))

; --- what an orb/andb/negb verdict tells of its operands, by bool_rect ---
(test
 (defq orbfalsel (pi a bool (pi b bool (pi h (paths bool (orb a b) false) (paths bool a false))))
   (lam a (bool_rect (lam a2 (pi b bool (pi h (paths bool (orb a2 b) false) (paths bool a2 false))))
       (lam b (lam h h))
       (lam b (lam h (idpath false)))
       a)))
 (defq orbfalser (pi a bool (pi b bool (pi h (paths bool (orb a b) false) (paths bool b false))))
   (lam a (bool_rect (lam a2 (pi b bool (pi h (paths bool (orb a2 b) false) (paths bool b false))))
       (lam b (lam h (fromempty (paths bool b false) (nopathstruetofalse h))))
       (lam b (lam h h))
       a)))
 (defq andbtruel (pi a bool (pi b bool (pi h (paths bool (andb a b) true) (paths bool a true))))
   (lam a (bool_rect (lam a2 (pi b bool (pi h (paths bool (andb a2 b) true) (paths bool a2 true))))
       (lam b (lam h (idpath true)))
       (lam b (lam h (fromempty (paths bool false true) (nopathstruetofalse (pathsinv0 bool false true h)))))
       a)))
 (defq andbtruer (pi a bool (pi b bool (pi h (paths bool (andb a b) true) (paths bool b true))))
   (lam a (bool_rect (lam a2 (pi b bool (pi h (paths bool (andb a2 b) true) (paths bool b true))))
       (lam b (lam h h))
       (lam b (lam h (fromempty (paths bool b true) (nopathstruetofalse (pathsinv0 bool false true h)))))
       a)))
 (defq negbtrue (pi t bool (pi h (paths bool (negb t) true) (paths bool t false)))
   (lam t (bool_rect (lam t2 (pi h (paths bool (negb t2) true) (paths bool t2 false)))
       (lam h (fromempty (paths bool true false) (nopathstruetofalse (pathsinv0 bool false true h))))
       (lam h (idpath false))
       t)))
 (defq nateqbsymm (pi n nat (pi m nat (paths bool (nateqb n m) (nateqb m n))))
   (lam n (nat_rect
      (lam q (pi m nat (paths bool (nateqb q m) (nateqb m q))))
      (lam m (nat_rect (lam j (paths bool (nateqb 0 j) (nateqb j 0)))
               (idpath true)
               (lam j (lam r (idpath false)))
               m))
      (lam k (lam IH (lam m (nat_rect (lam j (paths bool (nateqb (succ k) j) (nateqb j (succ k))))
               (idpath false)
               (lam j (lam r (IH j)))
               m))))
      n))))

; --- the middle-insert lemmas, by induction on the front list: every step a conversion ---
(test
 (defq membmid
   (pi u nat (pi w nat (pi b nlist (pi hu (paths bool (nateqb u w) false)
      (pi a nlist (pi hm (paths bool (memb u (lapp a b)) false)
       (paths bool (memb u (lapp a (ncons w b))) false)))))))
   (lam u (lam w (lam b (lam hu (lam a ((nat_rect
      (lam q (pi v (nvec q) (pi hm (paths bool (memb u (lapp (tpair q v) b)) false)
               (paths bool (memb u (lapp (tpair q v) (ncons w b))) false))))
      (lam v (lam hm (pathscomp0 bool
        (memb u (ncons w b)) (memb u b) false
        (maponpaths bool bool (lam t (orb t (memb u b))) (nateqb u w) false hu)
        hm)))
      (lam k (lam IH (lam v (lam hm
        (pathscomp0 bool
          (orb (nateqb u (pr1 v)) (memb u (lapp (tpair k (pr2 v)) (ncons w b))))
          (memb u (lapp (tpair k (pr2 v)) (ncons w b)))
          false
          (maponpaths bool bool
            (lam t (orb t (memb u (lapp (tpair k (pr2 v)) (ncons w b)))))
            (nateqb u (pr1 v)) false
            (orbfalsel (nateqb u (pr1 v)) (memb u (lapp (tpair k (pr2 v)) b)) hm))
          (IH (pr2 v)
            (orbfalser (nateqb u (pr1 v)) (memb u (lapp (tpair k (pr2 v)) b)) hm)))))))
      (pr1 a)) (pr2 a))))))))
 (defq nodupmid
   (pi w nat (pi b nlist (pi a nlist (pi hm (paths bool (memb w (lapp a b)) false)
      (pi hs (paths bool (nodupb (lapp a b)) true)
       (paths bool (nodupb (lapp a (ncons w b))) true))))))
   (lam w (lam b (lam a ((nat_rect
      (lam q (pi v (nvec q) (pi hm (paths bool (memb w (lapp (tpair q v) b)) false)
               (pi hs (paths bool (nodupb (lapp (tpair q v) b)) true)
                (paths bool (nodupb (lapp (tpair q v) (ncons w b))) true)))))
      (lam v (lam hm (lam hs (pathscomp0 bool
        (nodupb (ncons w b)) (nodupb b) true
        (maponpaths bool bool (lam t (andb (negb t) (nodupb b))) (memb w b) false hm)
        hs))))
      (lam k (lam IH (lam v (lam hm (lam hs
        (pathscomp0 bool
          (nodupb (lapp (tpair (succ k) v) (ncons w b)))
          (nodupb (lapp (tpair k (pr2 v)) (ncons w b)))
          true
          (maponpaths bool bool
            (lam t (andb (negb t) (nodupb (lapp (tpair k (pr2 v)) (ncons w b)))))
            (memb (pr1 v) (lapp (tpair k (pr2 v)) (ncons w b))) false
            (membmid (pr1 v) w b
              (pathscomp0 bool (nateqb (pr1 v) w) (nateqb w (pr1 v)) false
                (nateqbsymm (pr1 v) w)
                (orbfalsel (nateqb w (pr1 v)) (memb w (lapp (tpair k (pr2 v)) b)) hm))
              (tpair k (pr2 v))
              (negbtrue (memb (pr1 v) (lapp (tpair k (pr2 v)) b))
                (andbtruel (negb (memb (pr1 v) (lapp (tpair k (pr2 v)) b)))
                           (nodupb (lapp (tpair k (pr2 v)) b)) hs))))
          (IH (pr2 v)
            (orbfalser (nateqb w (pr1 v)) (memb w (lapp (tpair k (pr2 v)) b)) hm)
            (andbtruer (negb (memb (pr1 v) (lapp (tpair k (pr2 v)) b)))
                       (nodupb (lapp (tpair k (pr2 v)) b)) hs))))))))
      (pr1 a)) (pr2 a)))))))

; --- nfilt (the every-copy filter) and the maybe stack (ii1 empty, ii2 the survivor) ---
(test
 (defn nfilt (pi w nat (pi l nlist nlist))
   (lam w (lam l ((nat_rect (lam q (pi v (nvec q) nlist))
             (lam v nnil)
             (lam k (lam IH (lam v (bool_rect (lam x nlist)
                      (IH (pr2 v))
                      (ncons (pr1 v) (IH (pr2 v)))
                      (nateqb w (pr1 v))))))
             (pr1 l)) (pr2 l)))))
 (defn mstk UU (coprod unit stk)))

; --- the kernel refuses: ill-typed terms scare; the help cell catches them ---
(hear (p \ e \ peep HELPC () 0 @ h (h ? (h p e) 0)))
(test
 ('rejected = rejects (z \ defn uu-bad1 (paths nat 1 2) (idpath 1)))
 ('rejected = rejects (z \ defn uu-bad2 (pi x nat nat) (lam x (succ y))))
 ('rejected = rejects (z \ defn uu-bad3 nat (lam x x)))
 ('rejected = rejects (z \ defn uu-bad4 (coprod nat bool) (ii1 true)))
 ('rejected = rejects (z \ defn uu-bad5 nat (let x (lam y y) x)))
 ('rejected = rejects (z \ defn uu-bad6 (pi x nat 5) (lam x x)))
 ('accepted = rejects (z \ defn uu-good (paths nat 2 2) (idpath 2))))
; --- conv in pairs: a mixed-up env or de bruijn level would accept a bad proof
; --- silently. each negative needs its accepted twin ---
(test
 ('accepted = rejects (z \ defn uu-cv1 (pi x nat (paths nat x x))
                       (the (pi x nat (paths nat x x)) (lam x (idpath x)))))
 ('rejected = rejects (z \ defn uu-cv2 (pi x nat (paths nat x (succ x)))
                       (the (pi x nat (paths nat x x)) (lam x (idpath x)))))
; nested binders: the two shapes differ only by which fresh neutral each closure got
 ('accepted = rejects (z \ defn uu-cv3 (pi x nat (pi y nat (paths nat x x)))
                       (the (pi x nat (pi y nat (paths nat x x))) (lam x (lam y (idpath x))))))
 ('rejected = rejects (z \ defn uu-cv4 (pi x nat (pi y nat (paths nat y y)))
                       (the (pi x nat (pi y nat (paths nat x x))) (lam x (lam y (idpath x))))))
; the sigma codomain (conv's sig branch is pi's twin)
 ('accepted = rejects (z \ defn uu-cv5 (total2 x nat (paths nat x x))
                       (the (total2 x nat (paths nat x x)) (tpair 0 (idpath 0)))))
 ('rejected = rejects (z \ defn uu-cv6 (total2 x nat (paths nat x (succ x)))
                       (the (total2 x nat (paths nat x x)) (tpair 0 (idpath 0)))))
 ; a constant codomain still has to be compared
 ('rejected = rejects (z \ defn uu-cv7 (pi x nat bool) (the (pi x nat nat) (lam x x)))))
(hear test-strict)
