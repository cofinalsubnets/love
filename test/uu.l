; uu -- a univalent kernel: MLTT with the UniMath Preamble's seven inductives
; (empty unit bool coprod nat paths total2), bidirectional checking, NbE
; conversion (de bruijn levels as fresh vars, sigma- and pi-eta), type-in-type --
; the universe stance of the reference (UniMath/Foundations/Init.v: Unset
; Universe Checking). an axiom is a book entry with a type and no value: a
; sanctioned missing. names follow UniMath so the port reads literally.
;
; terms are quoted lists: UU nat bool unit empty zero tt true false <fixnum>
;   (pi x A B) (lam x b) (total2 x A B) (tpair a b) (pr1 w) (pr2 w) (succ n)
;   (coprod A B) (ii1 a) (ii2 b) (paths A a b) (idpath a) (the T t)
;   (nat_rect P z s n) (bool_rect P t f b) (unit_rect P u x)
;   (coprod_rect P f g v) (empty_rect P e) (paths_rect P pr e)
;   (let x a b) -- definitional: x binds the VALUE of a, transparent to conv
; and any other list is an application spine. (f) == f here too.

; --- the kernel: values, evaluation, conversion, checking ---
(: GLOB (tablet 0) HELPC (tablet 0)

   (tagv v) (? (twop v) (cap v) v)
   (e2 l) (cap (cbp l))
   (e3 l) (cap (cbp (cbp l)))
   (e4 l) (cap (cbp (cbp (cbp l))))
   (e5 l) (cap (cbp (cbp (cbp (cbp l))))))

(: (vsucc v) (? (fixp v) (v + 1) (L 'succ v))

   (capp cl v) (vof (cons (L (e3 cl) v) (e2 cl)) (e4 cl))

   (vapp f a) (? (idp (tagv f) 'lam) (capp (e2 f) a) (L 'na f a))

   (dop1 v) (? (idp (tagv v) 'pair) (e2 v) (L 'np1 v))
   (dop2 v) (? (idp (tagv v) 'pair) (e3 v) (L 'np2 v))

   (donr P z s m)
   (? (fixp m) (: (go k acc) (? (k = m) acc (go (k + 1) (vapp (vapp s k) acc)))
                  (go 0 z))
      (idp (tagv m) 'succ) (vapp (vapp s (e2 m)) (donr P z s (e2 m)))
      (L 'nnr P z s m))

   (dobr P x y v) (? (idp v 'true) x (idp v 'false) y (L 'nbr P x y v))
   (dour P x v) (? (idp v 'tt) x (L 'nur P x v))
   (docr P f g v) (? (idp (tagv v) 'i1) (vapp f (e2 v))
                     (idp (tagv v) 'i2) (vapp g (e2 v))
                     (L 'ncr P f g v))
   (doer P v) (L 'ner P v)
   (dojr P r ev) (? (idp (tagv ev) 'refl) r (L 'njr P r ev))

   (vof-sym en x)
   (: e (assq x en)
      (? e (e2 e)
         (: g (peep GLOB x 0)
            (? g (e2 g) (scare 'uu-unbound x)))))

   (vof en t)
   (? (fixp t) t
      (symp t) (? (memq t '(UU nat bool unit empty tt true false)) t
                  (idp t 'zero) 0
                  (vof-sym en t))
      (: h (cap t)
         (? (twop h) (vof-spine en (vof en h) (cbp t))
            (idp h 'lam)    (L 'lam (L 'clo en (e2 t) (e3 t)))
            (idp h 'pi)     (L 'pi  (vof en (e3 t)) (L 'clo en (e2 t) (e4 t)))
            (idp h 'total2) (L 'sig (vof en (e3 t)) (L 'clo en (e2 t) (e4 t)))
            (idp h 'tpair)  (L 'pair (vof en (e2 t)) (vof en (e3 t)))
            (idp h 'pr1)    (dop1 (vof en (e2 t)))
            (idp h 'pr2)    (dop2 (vof en (e2 t)))
            (idp h 'succ)   (vsucc (vof en (e2 t)))
            (idp h 'coprod) (L 'coprod (vof en (e2 t)) (vof en (e3 t)))
            (idp h 'ii1)    (L 'i1 (vof en (e2 t)))
            (idp h 'ii2)    (L 'i2 (vof en (e2 t)))
            (idp h 'paths)  (L 'paths (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)))
            (idp h 'idpath) (L 'refl (vof en (e2 t)))
            (idp h 'the)    (vof en (e3 t))
            (idp h 'let)    (vof (cons (L (e2 t) (vof en (e3 t))) en) (e4 t))
            (idp h 'nat_rect)    (donr (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)) (vof en (e5 t)))
            (idp h 'bool_rect)   (dobr (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)) (vof en (e5 t)))
            (idp h 'unit_rect)   (dour (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)))
            (idp h 'coprod_rect) (docr (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)) (vof en (e5 t)))
            (idp h 'empty_rect)  (doer (vof en (e2 t)) (vof en (e3 t)))
            (idp h 'paths_rect)  (dojr (vof en (e2 t)) (vof en (e3 t)) (vof en (e4 t)))
            (vof-spine en (vof en h) (cbp t)))))

   ; empty-list tests are STRUCTURAL (twop): a love list of zeros NETS zero,
   ; so !as would call (add n 0)'s final argument list (0) empty -- the net law.
   (vof-spine en f as)
   (? !(twop as) f (vof-spine en (vapp f (vof en (cap as))) (cbp as)))

   (conv d a b)
   (? (idp a b) 1                    ; the same heap object converts to itself:
      (&& (fixp a) (fixp b)) (a = b) ; O(1) across the shared neutral towers
      (&& (symp a) (symp b)) (idp a b)
      (|| (idp (tagv a) 'lam) (idp (tagv b) 'lam))
      (: fr (L 'nv d) (conv (d + 1) (vapp a fr) (vapp b fr)))
      (&& (idp (tagv a) 'pair) (twop b) !(idp (cap b) 'pair))
      (&& (conv d (e2 a) (dop1 b)) (conv d (e3 a) (dop2 b)))
      (&& (idp (tagv b) 'pair) (twop a) !(idp (cap a) 'pair))
      (&& (conv d (dop1 a) (e2 b)) (conv d (dop2 a) (e3 b)))
      (&& (idp (tagv a) 'pi) (idp (tagv b) 'pi))
      (&& (conv d (e2 a) (e2 b))
          (: fr (L 'nv d) (conv (d + 1) (capp (e3 a) fr) (capp (e3 b) fr))))
      (&& (idp (tagv a) 'sig) (idp (tagv b) 'sig))
      (&& (conv d (e2 a) (e2 b))
          (: fr (L 'nv d) (conv (d + 1) (capp (e3 a) fr) (capp (e3 b) fr))))
      (&& (twop a) (twop b) (idp (cap a) (cap b))) (conv-args d (cbp a) (cbp b))
      0)

   (conv-args d as bs)
   (? (&& !(twop as) !(twop bs)) 1
      (|| !(twop as) !(twop bs)) 0
      (&& (conv d (cap as) (cap bs)) (conv-args d (cbp as) (cbp bs))))

   (inf-sym cx x)
   (? (idp x 'UU) 'UU
      (memq x '(nat bool unit empty)) 'UU
      (idp x 'zero) 'nat
      (idp x 'tt) 'unit
      (memq x '(true false)) 'bool
      (: e (assq x cx)
         (? e (e2 e)
            (: g (peep GLOB x 0)
               (? g (cap g) (scare 'uu-unbound x))))))

   (inf-spine cx en d f as)
   (? !(twop as) f
      (idp (tagv f) 'pi)
      (: a (cap as)
         _ (chk cx en d a (e2 f))
         (inf-spine cx en d (capp (e3 f) (vof en a)) (cbp as)))
      (scare 'uu-not-a-pi as))

   (chk cx en d t T)
   (? (&& (twop t) (idp (cap t) 'lam))
      (? (idp (tagv T) 'pi)
         (: x (e2 t) fr (L 'nv d)
            (chk (cons (L x (e2 T)) cx) (cons (L x fr) en) (d + 1)
                 (e3 t) (capp (e3 T) fr)))
         (scare 'uu-lam-needs-pi t))
      (&& (twop t) (idp (cap t) 'tpair))
      (? (idp (tagv T) 'sig)
         (: _ (chk cx en d (e2 t) (e2 T))
            (chk cx en d (e3 t) (capp (e3 T) (vof en (e2 t)))))
         (scare 'uu-tpair-needs-total2 t))
      (&& (twop t) (idp (cap t) 'ii1))
      (? (idp (tagv T) 'coprod) (chk cx en d (e2 t) (e2 T)) (scare 'uu-ii1-needs-coprod t))
      (&& (twop t) (idp (cap t) 'ii2))
      (? (idp (tagv T) 'coprod) (chk cx en d (e2 t) (e3 T)) (scare 'uu-ii2-needs-coprod t))
      (&& (twop t) (idp (cap t) 'idpath))
      (? (idp (tagv T) 'paths)
         (: _ (chk cx en d (e2 t) (e2 T))
            v (vof en (e2 t))
            (? (&& (conv d v (e3 T)) (conv d v (e4 T))) 1 (scare 'uu-idpath-mismatch t)))
         (scare 'uu-idpath-needs-paths t))
      (&& (twop t) (idp (cap t) 'let))
      (: x (e2 t)
         Av (inf cx en d (e3 t))
         va (vof en (e3 t))
         (chk (cons (L x Av) cx) (cons (L x va) en) d (e4 t) T))
      (: Ti (inf cx en d t)
         (? (conv d T Ti) 1 (scare 'uu-type-mismatch t))))

   (inf cx en d t)
   (? (fixp t) 'nat
      (symp t) (inf-sym cx t)
      (: h (cap t)
         (? (twop h) (inf-spine cx en d (inf cx en d h) (cbp t))
            (idp h 'pi)
            (: x (e2 t)
               _ (chk cx en d (e3 t) 'UU)
               fr (L 'nv d)
               _ (chk (cons (L x (vof en (e3 t))) cx) (cons (L x fr) en) (d + 1) (e4 t) 'UU)
               'UU)
            (idp h 'total2)
            (: x (e2 t)
               _ (chk cx en d (e3 t) 'UU)
               fr (L 'nv d)
               _ (chk (cons (L x (vof en (e3 t))) cx) (cons (L x fr) en) (d + 1) (e4 t) 'UU)
               'UU)
            (idp h 'coprod)
            (: _ (chk cx en d (e2 t) 'UU) _ (chk cx en d (e3 t) 'UU) 'UU)
            (idp h 'paths)
            (: _ (chk cx en d (e2 t) 'UU)
               Av (vof en (e2 t))
               _ (chk cx en d (e3 t) Av)
               _ (chk cx en d (e4 t) Av)
               'UU)
            (idp h 'succ) (: _ (chk cx en d (e2 t) 'nat) 'nat)
            (idp h 'idpath)
            (: Av (inf cx en d (e2 t)) v (vof en (e2 t)) (L 'paths Av v v))
            (idp h 'pr1)
            (: S (inf cx en d (e2 t))
               (? (idp (tagv S) 'sig) (e2 S) (scare 'uu-pr1-needs-total2 t)))
            (idp h 'pr2)
            (: S (inf cx en d (e2 t))
               (? (idp (tagv S) 'sig) (capp (e3 S) (dop1 (vof en (e2 t))))
                  (scare 'uu-pr2-needs-total2 t)))
            (idp h 'the)
            (: _ (chk cx en d (e2 t) 'UU)
               Tv (vof en (e2 t))
               _ (chk cx en d (e3 t) Tv)
               Tv)
            (idp h 'let)
            (: x (e2 t)
               Av (inf cx en d (e3 t))
               va (vof en (e3 t))
               (inf (cons (L x Av) cx) (cons (L x va) en) d (e4 t)))
            (idp h 'nat_rect)
            (: P (e2 t)
               _ (chk cx en d (e5 t) 'nat)
               _ (chk cx en d P (vof 0 '(pi x nat UU)))
               Pv (vof en P)
               _ (chk cx en d (e3 t) (vapp Pv 0))
               _ (chk cx en d (e4 t)
                      (vof (L (L 'P Pv)) '(pi k nat (pi r (P k) (P (succ k))))))
               (vapp Pv (vof en (e5 t))))
            (idp h 'bool_rect)
            (: P (e2 t)
               _ (chk cx en d (e5 t) 'bool)
               _ (chk cx en d P (vof 0 '(pi x bool UU)))
               Pv (vof en P)
               _ (chk cx en d (e3 t) (vapp Pv 'true))
               _ (chk cx en d (e4 t) (vapp Pv 'false))
               (vapp Pv (vof en (e5 t))))
            (idp h 'unit_rect)
            (: P (e2 t)
               _ (chk cx en d (e4 t) 'unit)
               _ (chk cx en d P (vof 0 '(pi x unit UU)))
               Pv (vof en P)
               _ (chk cx en d (e3 t) (vapp Pv 'tt))
               (vapp Pv (vof en (e4 t))))
            (idp h 'empty_rect)
            (: P (e2 t)
               _ (chk cx en d (e3 t) 'empty)
               _ (chk cx en d P (vof 0 '(pi x empty UU)))
               (vapp (vof en P) (vof en (e3 t))))
            (idp h 'coprod_rect)
            (: S (inf cx en d (e5 t))
               (? (idp (tagv S) 'coprod)
                  (: A (e2 S) B (e3 S) P (e2 t)
                     _ (chk cx en d P
                            (vof (L (L 'A A) (L 'B B)) '(pi x (coprod A B) UU)))
                     Pv (vof en P)
                     _ (chk cx en d (e3 t)
                            (vof (L (L 'A A) (L 'P Pv)) '(pi a A (P (ii1 a)))))
                     _ (chk cx en d (e4 t)
                            (vof (L (L 'B B) (L 'P Pv)) '(pi b B (P (ii2 b)))))
                     (vapp Pv (vof en (e5 t))))
                  (scare 'uu-coprod_rect t)))
            (idp h 'paths_rect)
            (: E (inf cx en d (e4 t))
               (? (idp (tagv E) 'paths)
                  (: A (e2 E) av (e3 E) bv (e4 E) P (e2 t)
                     _ (chk cx en d P
                            (vof (L (L 'A A) (L 'a av)) '(pi b A (pi e (paths A a b) UU))))
                     Pv (vof en P)
                     _ (chk cx en d (e3 t) (vapp (vapp Pv av) (L 'refl av)))
                     (vapp (vapp Pv bv) (vof en (e4 t))))
                  (scare 'uu-paths_rect t)))
            (memq h '(lam tpair ii1 ii2)) (scare 'uu-cannot-infer t)
            (inf-spine cx en d (inf-sym cx h) (cbp t))))))

; --- drivers: a definition is checked then pinned; an axiom is a book entry
; --- with a type and no value (its value is its own neutral name); rejects
; --- runs a thunk expecting the kernel to refuse (the help cell escapes).
(: (defn nm T t)
   (: _ (chk 0 0 0 T 'UU)
      Tv (vof 0 T)
      _ (chk 0 0 0 t Tv)
      _ (pin GLOB nm (L Tv (vof 0 t)))
      nm)
   (axm nm T)
   (: _ (chk 0 0 0 T 'UU)
      _ (pin GLOB nm (L (vof 0 T) (L 'nv nm)))
      nm)
   ; the Qed driver: CHECKED like defn, then sealed -- pinned with its own
   ; neutral as value, so applying the proof never evaluates it. Coq's
   ; Qed/Defined distinction, here because strict NbE would otherwise build
   ; the proof's whole beta-normal form at every use.
   (defq nm T t)
   (: _ (chk 0 0 0 T 'UU)
      Tv (vof 0 T)
      _ (chk 0 0 0 t Tv)
      _ (pin GLOB nm (L Tv (L 'nv nm)))
      nm)
   (rejects th)
   (: r (call-cc (\ k (: _ (pin HELPC () (\ s a b (k 'rejected)))
                         v (th 0)
                         'accepted)))
      _ (pin HELPC () 0)
      r))

; --- UniMath Foundations PartA, the core slice: every name is the original.
(assert
 (defn 'idfun '(pi T UU (pi x T T)) '(lam T (lam x x)))
 (defn 'funcomp
   '(pi X UU (pi Y UU (pi Z UU (pi f (pi x X Y) (pi g (pi y Y Z) (pi x X Z))))))
   '(lam X (lam Y (lam Z (lam f (lam g (lam x (g (f x)))))))))
 (defn 'iscontr '(pi T UU UU) '(lam T (total2 c T (pi t T (paths T t c)))))
 (defn 'hfiber
   '(pi X UU (pi Y UU (pi f (pi x X Y) (pi y Y UU))))
   '(lam X (lam Y (lam f (lam y (total2 x X (paths Y (f x) y)))))))
 (defn 'isweq
   '(pi X UU (pi Y UU (pi f (pi x X Y) UU)))
   '(lam X (lam Y (lam f (pi y Y (iscontr (hfiber X Y f y)))))))
 (defn 'weq '(pi X UU (pi Y UU UU))
   '(lam X (lam Y (total2 f (pi x X Y) (isweq X Y f)))))
 (defn 'transportf
   '(pi A UU (pi P (pi x A UU) (pi a A (pi b A (pi e (paths A a b) (pi p (P a) (P b)))))))
   '(lam A (lam P (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (pi p (P a) (P bp)))) (lam p p) e)))))))
 (defn 'pathsinv0
   '(pi A UU (pi a A (pi b A (pi e (paths A a b) (paths A b a)))))
   '(lam A (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (paths A bp a))) (idpath a) e))))))
 ; pathscomp0 inducts on its FIRST argument, exactly as UniMath's @ does:
 ; (comp idpath e) computes to e, the right identity is the lemma below.
 (defn 'pathscomp0
   '(pi A UU (pi a A (pi b A (pi c A (pi e1 (paths A a b) (pi e2 (paths A b c) (paths A a c)))))))
   '(lam A (lam a (lam b (lam c (lam e1 (lam e2
      ((paths_rect (lam bp (lam ep (pi q (paths A bp c) (paths A a c))))
                   (lam q q)
                   e1)
       e2))))))))
 (defn 'maponpaths
   '(pi A UU (pi B UU (pi f (pi x A B) (pi a A (pi b A (pi e (paths A a b) (paths B (f a) (f b))))))))
   '(lam A (lam B (lam f (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (paths B (f a) (f bp)))) (idpath (f a)) e))))))))
 (defn 'uu-unitpath '(pi u unit (paths unit u tt))
   '(lam u (unit_rect (lam v (paths unit v tt)) (idpath tt) u)))
 (defn 'iscontrunit '(iscontr unit) '(tpair tt (lam t (uu-unitpath t))))
 (defn 'proofirrelevancecontr
   '(pi X UU (pi i (iscontr X) (pi x X (pi y X (paths X x y)))))
   '(lam X (lam i (lam x (lam y
      (pathscomp0 X x (pr1 i) y ((pr2 i) x) (pathsinv0 X y (pr1 i) ((pr2 i) y))))))))
 (defn 'fromempty '(pi P UU (pi e empty P)) '(lam P (lam e (empty_rect (lam x P) e))))
 (defn 'negb '(pi b bool bool) '(lam b (bool_rect (lam x bool) false true b)))
 (defn 'add '(pi n nat (pi m nat nat))
   '(lam n (lam m (nat_rect (lam x nat) m (lam k (lam r (succ r))) n)))))

; the eliminators COMPUTE: proofs by idpath are proofs by evaluation.
(assert
 (defn 'uu-two-plus-two '(paths nat (add 2 2) 4) '(idpath 4))
 (defn 'uu-negb-true '(paths bool (negb true) false) '(idpath false))
 (defn 'uu-fromsum '(pi v (coprod nat bool) nat)
   '(lam v (coprod_rect (lam x nat) (lam a a) (lam b (bool_rect (lam x nat) 1 0 b)) v)))
 (defn 'uu-fromsum-ii2 '(paths nat (uu-fromsum (ii2 true)) 1) '(idpath 1))
 (4 = (vof 0 '(add 2 2))))

; the crown: the identity is a weak equivalence (PartA idisweq -- the proof
; needs sigma-eta), the inverse falls out of contractible fibers, and
; univalence is the axiom over a checked eqweqmap, exactly UnivalenceAxiom.v.
(assert
 (defn 'idisweq '(pi T UU (isweq T T (idfun T)))
   '(lam T (lam y (tpair (tpair y (idpath y))
      (lam t (paths_rect
        (lam bp (lam ep (paths (hfiber T T (idfun T) bp)
                               (tpair (pr1 t) ep)
                               (tpair bp (idpath bp)))))
        (idpath (tpair (pr1 t) (idpath (pr1 t))))
        (pr2 t)))))))
 (defn 'idweq '(pi T UU (weq T T)) '(lam T (tpair (lam x x) (idisweq T))))
 (defn 'eqweqmap '(pi X UU (pi Y UU (pi e (paths UU X Y) (weq X Y))))
   '(lam X (lam Y (lam e (paths_rect (lam Yp (lam ep (weq X Yp))) (idweq X) e)))))
 (axm 'univalenceAxiom
   '(pi X UU (pi Y UU (isweq (paths UU X Y) (weq X Y) (eqweqmap X Y)))))
 ; (the ONE axiom: funextempty is a THEOREM now -- see the funext chain below)
 (defn 'uu-eqweqmap-idpath
   '(pi X UU (paths (weq X X) (eqweqmap X X (idpath X)) (idweq X)))
   '(lam X (idpath (idweq X))))
 (defn 'invmap
   '(pi X UU (pi Y UU (pi w (weq X Y) (pi y Y X))))
   '(lam X (lam Y (lam w (lam y (pr1 (pr1 ((pr2 w) y))))))))
 (defn 'homotweqinvweq
   '(pi X UU (pi Y UU (pi w (weq X Y) (pi y Y (paths Y ((pr1 w) (invmap X Y w y)) y)))))
   '(lam X (lam Y (lam w (lam y (pr2 (pr1 ((pr2 w) y)))))))))

; the h-level ladder grounded at iscontr by nat-recursion (PartB isofhlevel;
; the motive lands in UU -> UU), the bridges holding DEFINITIONALLY, and
; Propositions.v's impredicative truncation: no higher inductive anywhere.
(assert
 (defn 'isaprop '(pi X UU UU)
   '(lam X (pi x X (pi y X (iscontr (paths X x y))))))
 (defn 'isaset '(pi X UU UU)
   '(lam X (pi x X (pi y X (isaprop (paths X x y))))))
 (defn 'isofhlevel '(pi n nat (pi X UU UU))
   '(lam n (nat_rect (lam q (pi X UU UU))
                     iscontr
                     (lam k (lam rec (lam X (pi x X (pi y X (rec (paths X x y)))))))
                     n)))
 (defn 'uu-isaprop-is-level1
   '(pi X UU (paths UU (isaprop X) (isofhlevel 1 X)))
   '(lam X (idpath (isaprop X))))
 (defn 'uu-isaset-is-level2
   '(pi X UU (paths UU (isaset X) (isofhlevel 2 X)))
   '(lam X (idpath (isaset X))))
 (defn 'hProp 'UU '(total2 X UU (isaprop X)))
 (defn 'hSet 'UU '(total2 X UU (isaset X)))
 (defn 'ishinh_UU '(pi X UU UU)
   '(lam X (pi P hProp (pi f (pi x X (pr1 P)) (pr1 P)))))
 (defn 'hinhpr '(pi X UU (pi x X (ishinh_UU X)))
   '(lam X (lam x (lam P (lam f (f x))))))
 (defn 'hinhuniv
   '(pi X UU (pi P hProp (pi f (pi x X (pr1 P)) (pi w (ishinh_UU X) (pr1 P)))))
   '(lam X (lam P (lam f (lam w (w P f)))))))

; sigma paths (two nested J's riding sigma-eta), the retraction (invmap's
; triple closes sans adjointness), transport discriminating bool, and the
; univalence CONSEQUENCES: the axiom is one neutral name, yet univalence the
; weq, weqtopaths, and its section weqpathsweq all fall out by computation --
; UnivalenceAxiom.v's first theorems. (UniMath's neg/negf are SKIPPED: `neg`
; is the prelude's monadic word for -x, and a corpus global would shadow it
; for every test compiled after this file -- the ieee-inf lesson again.)
(assert
 (defn 'total2_paths_f
   '(pi A UU (pi P (pi x A UU)
      (pi s (total2 x A (P x)) (pi sp (total2 x A (P x))
        (pi p (paths A (pr1 s) (pr1 sp))
          (pi q (paths (P (pr1 sp)) (transportf A P (pr1 s) (pr1 sp) p (pr2 s)) (pr2 sp))
            (paths (total2 x A (P x)) s sp)))))))
   '(lam A (lam P (lam s (lam sp (lam p (lam q
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
 (defn 'homotinvweqweq
   '(pi X UU (pi Y UU (pi w (weq X Y) (pi x X
      (paths X (invmap X Y w ((pr1 w) x)) x)))))
   '(lam X (lam Y (lam w (lam x
      (pathsinv0 X x (invmap X Y w ((pr1 w) x))
        (maponpaths (hfiber X Y (pr1 w) ((pr1 w) x)) X (lam t (pr1 t))
          (tpair x (idpath ((pr1 w) x)))
          (pr1 ((pr2 w) ((pr1 w) x)))
          ((pr2 ((pr2 w) ((pr1 w) x))) (tpair x (idpath ((pr1 w) x)))))))))))
 (defn 'isweqtoempty
   '(pi X UU (pi f (pi x X empty) (isweq X empty f)))
   '(lam X (lam f (lam y (empty_rect (lam e (iscontr (hfiber X empty f e))) y)))))
 (defn 'weqtoempty
   '(pi X UU (pi f (pi x X empty) (weq X empty)))
   '(lam X (lam f (tpair f (isweqtoempty X f)))))
 (defn 'nopathstruetofalse '(pi e (paths bool true false) empty)
   '(lam e (transportf bool (lam b (bool_rect (lam x UU) unit empty b)) true false e tt)))
 (defn 'nopathsfalsetotrue '(pi e (paths bool false true) empty)
   '(lam e (transportf bool (lam b (bool_rect (lam x UU) empty unit b)) false true e tt)))
 (defn 'univalence
   '(pi X UU (pi Y UU (weq (paths UU X Y) (weq X Y))))
   '(lam X (lam Y (tpair (eqweqmap X Y) (univalenceAxiom X Y)))))
 (defn 'weqtopaths
   '(pi X UU (pi Y UU (pi w (weq X Y) (paths UU X Y))))
   '(lam X (lam Y (lam w (invmap (paths UU X Y) (weq X Y) (univalence X Y) w)))))
 (defn 'weqpathsweq
   '(pi X UU (pi Y UU (pi w (weq X Y)
      (paths (weq X Y) (eqweqmap X Y (weqtopaths X Y w)) w))))
   '(lam X (lam Y (lam w (homotweqinvweq (paths UU X Y) (weq X Y) (univalence X Y) w))))))

; the path groupoid coherences and the retraction machinery the grad lemma
; stands on -- pathscomp0rid by induction exactly as PartA does (the left
; identity is the definitional one). isapropunit is one name: the stored type
; of iscontrpathsinunit IS the unfolding of (isaprop unit), so the reference
; checks bare.
(assert
 (defn 'pathscomp0rid
   '(pi A UU (pi a A (pi b A (pi e (paths A a b)
      (paths (paths A a b) (pathscomp0 A a b b e (idpath b)) e)))))
   '(lam A (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (paths (paths A a bp)
                                    (pathscomp0 A a bp bp ep (idpath bp)) ep)))
                  (idpath (idpath a))
                  e))))))
 (defn 'pathsinv0r
   '(pi A UU (pi a A (pi b A (pi e (paths A a b)
      (paths (paths A a a) (pathscomp0 A a b a e (pathsinv0 A a b e)) (idpath a))))))
   '(lam A (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (paths (paths A a a)
                                    (pathscomp0 A a bp a ep (pathsinv0 A a bp ep))
                                    (idpath a))))
                  (idpath (idpath a))
                  e))))))
 (defn 'pathsinv0l
   '(pi A UU (pi a A (pi b A (pi e (paths A a b)
      (paths (paths A b b) (pathscomp0 A b a b (pathsinv0 A a b e) e) (idpath b))))))
   '(lam A (lam a (lam b (lam e
      (paths_rect (lam bp (lam ep (paths (paths A bp bp)
                                    (pathscomp0 A bp a bp (pathsinv0 A a bp ep) ep)
                                    (idpath bp))))
                  (idpath (idpath a))
                  e))))))
 (defn 'iscontrretract
   '(pi X UU (pi Y UU (pi p (pi x X Y) (pi s (pi y Y X)
      (pi eps (pi y Y (paths Y (p (s y)) y))
        (pi is (iscontr X) (iscontr Y)))))))
   '(lam X (lam Y (lam p (lam s (lam eps (lam is
      (tpair (p (pr1 is))
        (lam t (pathscomp0 Y t (p (s t)) (p (pr1 is))
                 (pathsinv0 Y (p (s t)) t (eps t))
                 (maponpaths X Y p (s t) (pr1 is) ((pr2 is) (s t)))))))))))))
 (defn 'hfibershomotftog
   '(pi X UU (pi Y UU (pi f (pi x X Y) (pi g (pi x X Y)
      (pi h (pi x X (paths Y (f x) (g x)))
        (pi y Y (pi t (hfiber X Y f y) (hfiber X Y g y))))))))
   '(lam X (lam Y (lam f (lam g (lam h (lam y (lam t
      (tpair (pr1 t)
        (pathscomp0 Y (g (pr1 t)) (f (pr1 t)) y
          (pathsinv0 Y (f (pr1 t)) (g (pr1 t)) (h (pr1 t)))
          (pr2 t)))))))))))
 (defn 'hfibershomotgtof
   '(pi X UU (pi Y UU (pi f (pi x X Y) (pi g (pi x X Y)
      (pi h (pi x X (paths Y (f x) (g x)))
        (pi y Y (pi t (hfiber X Y g y) (hfiber X Y f y))))))))
   '(lam X (lam Y (lam f (lam g (lam h (lam y (lam t
      (tpair (pr1 t)
        (pathscomp0 Y (f (pr1 t)) (g (pr1 t)) y
          (h (pr1 t))
          (pr2 t)))))))))))
 (defn 'iscontrpathsinunit
   '(pi x unit (pi y unit (iscontr (paths unit x y))))
   '(lam x (lam y (tpair
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
 (defn 'isapropunit '(isaprop unit) 'iscontrpathsinunit))

; THE GRAD LEMMA (UniMath isweq_iso, ne gradth): an isomorphism is a weak
; equivalence. the route is Voevodsky's: hfiber (f o g) y is contractible by
; homotopy from idisweq, and hfiber f y retracts onto it; the retraction
; equation is total2_paths_f over the cancellation !p @ (p @ q) = q, whose
; J-base is ALL definitional under left-inducting comp. the corollaries pay
; immediately: the inverse of a weq is a weq, negb is a weq, and weqtopaths
; mints a path bool = bool in the universe that is not idpath.
(assert
 (defn 'path_assoc
   '(pi A UU (pi a A (pi b A (pi c A (pi d A
      (pi e1 (paths A a b) (pi e2 (paths A b c) (pi e3 (paths A c d)
        (paths (paths A a d)
          (pathscomp0 A a b d e1 (pathscomp0 A b c d e2 e3))
          (pathscomp0 A a c d (pathscomp0 A a b c e1 e2) e3))))))))))
   '(lam A (lam a (lam b (lam c (lam d (lam e1 (lam e2 (lam e3
      ((paths_rect
         (lam bp (lam ep (pi q2 (paths A bp c) (pi q3 (paths A c d)
           (paths (paths A a d)
             (pathscomp0 A a bp d ep (pathscomp0 A bp c d q2 q3))
             (pathscomp0 A a c d (pathscomp0 A a bp c ep q2) q3))))))
         (lam q2 (lam q3 (idpath (pathscomp0 A a c d q2 q3))))
         e1)
       e2 e3))))))))))
 (defn 'uu-pathsinv0comp
   '(pi A UU (pi a A (pi b A (pi c A (pi p (paths A a b) (pi q (paths A b c)
      (paths (paths A b c)
        (pathscomp0 A b a c (pathsinv0 A a b p) (pathscomp0 A a b c p q))
        q)))))))
   '(lam A (lam a (lam b (lam c (lam p (lam q
      ((paths_rect
         (lam bp (lam ep (pi qq (paths A bp c)
           (paths (paths A bp c)
             (pathscomp0 A bp a c (pathsinv0 A a bp ep) (pathscomp0 A a bp c ep qq))
             qq))))
         (lam qq (idpath qq))
         p)
       q))))))))
 (defn 'uu-transportf-paths-Fl
   '(pi A UU (pi B UU (pi f (pi x A B) (pi b B
      (pi x1 A (pi x2 A (pi p (paths A x1 x2) (pi e (paths B (f x1) b)
        (paths (paths B (f x2) b)
          (transportf A (lam x (paths B (f x) b)) x1 x2 p e)
          (pathscomp0 B (f x2) (f x1) b
            (pathsinv0 B (f x1) (f x2) (maponpaths A B f x1 x2 p))
            e))))))))))
   '(lam A (lam B (lam f (lam b (lam x1 (lam x2 (lam p (lam e
      (paths_rect
        (lam xp (lam pp (paths (paths B (f xp) b)
          (transportf A (lam x (paths B (f x) b)) x1 xp pp e)
          (pathscomp0 B (f xp) (f x1) b
            (pathsinv0 B (f x1) (f xp) (maponpaths A B f x1 xp pp))
            e))))
        (idpath e)
        p))))))))))
 (defn 'iscontrhfiberl1
   '(pi X UU (pi Y UU (pi f (pi x X Y) (pi g (pi x X Y)
      (pi h (pi x X (paths Y (f x) (g x)))
        (pi y Y (pi is (iscontr (hfiber X Y f y)) (iscontr (hfiber X Y g y)))))))))
   '(lam X (lam Y (lam f (lam g (lam h (lam y (lam is
      (iscontrretract (hfiber X Y f y) (hfiber X Y g y)
        (hfibershomotftog X Y f g h y)
        (hfibershomotgtof X Y f g h y)
        (lam t (total2_paths_f X (lam x (paths Y (g x) y))
                 ((hfibershomotftog X Y f g h y) ((hfibershomotgtof X Y f g h y) t))
                 t
                 (idpath (pr1 t))
                 (uu-pathsinv0comp Y (f (pr1 t)) (g (pr1 t)) y (h (pr1 t)) (pr2 t))))
        is)))))))))
 (defn 'isweqhomot
   '(pi X UU (pi Y UU (pi f (pi x X Y) (pi g (pi x X Y)
      (pi h (pi x X (paths Y (f x) (g x)))
        (pi is (isweq X Y f) (isweq X Y g)))))))
   '(lam X (lam Y (lam f (lam g (lam h (lam is
      (lam y (iscontrhfiberl1 X Y f g h y (is y))))))))))
 (defn 'isweq_iso
   '(pi X UU (pi Y UU (pi f (pi x X Y) (pi g (pi y Y X)
      (pi egf (pi x X (paths X (g (f x)) x))
        (pi efg (pi y Y (paths Y (f (g y)) y))
          (isweq X Y f)))))))
   '(lam X (lam Y (lam f (lam g (lam egf (lam efg
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
 (defn 'isweqinvmap
   '(pi X UU (pi Y UU (pi w (weq X Y) (isweq Y X (lam y (invmap X Y w y))))))
   '(lam X (lam Y (lam w
      (isweq_iso Y X (lam y (invmap X Y w y)) (pr1 w)
        (homotweqinvweq X Y w)
        (homotinvweqweq X Y w))))))
 (defn 'invweq '(pi X UU (pi Y UU (pi w (weq X Y) (weq Y X))))
   '(lam X (lam Y (lam w (tpair (lam y (invmap X Y w y)) (isweqinvmap X Y w))))))
 (defn 'uu-isweqnegb '(isweq bool bool negb)
   '(isweq_iso bool bool negb negb
      (lam b (bool_rect (lam bp (paths bool (negb (negb bp)) bp))
               (idpath true) (idpath false) b))
      (lam b (bool_rect (lam bp (paths bool (negb (negb bp)) bp))
               (idpath true) (idpath false) b))))
 (defn 'uu-weqnegb '(weq bool bool) '(tpair negb uu-isweqnegb))
 (defn 'uu-boolbool '(paths UU bool bool) '(weqtopaths bool bool uu-weqnegb)))

; composition falls out of the grad lemma (twooutof3c, weqcomp -- UniMath's
; names), and boolascoprod runs every inductive eliminator inside one weq:
; bool_rect both ways, coprod_rect for the section, unit_rect through
; uu-unitpath for the corrections.
(assert
 (defn 'twooutof3c
   '(pi X UU (pi Y UU (pi Z UU (pi f (pi x X Y) (pi g (pi y Y Z)
      (pi isf (isweq X Y f) (pi isg (isweq Y Z g)
        (isweq X Z (lam x (g (f x)))))))))))
   '(lam X (lam Y (lam Z (lam f (lam g (lam isf (lam isg
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
 (defn 'weqcomp
   '(pi X UU (pi Y UU (pi Z UU (pi w1 (weq X Y) (pi w2 (weq Y Z) (weq X Z))))))
   '(lam X (lam Y (lam Z (lam w1 (lam w2
      (tpair (lam x ((pr1 w2) ((pr1 w1) x)))
             (twooutof3c X Y Z (pr1 w1) (pr1 w2) (pr2 w1) (pr2 w2)))))))))
 (defn 'boolascoprod '(weq bool (coprod unit unit))
   '(tpair (lam b (bool_rect (lam q (coprod unit unit)) (ii1 tt) (ii2 tt) b))
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

; HEDBERG: decidable equality makes a set -- funext-free, so nat and bool
; become honest hSets today. the normalizer over the decision is constant
; per case (same scrutinee both sides; fromempty discharges the impossible
; branch at the path level), the J-lemma rides pathsinv0l, and
; invproofirrelevance turns collapse into contractibility. the coconut
; (iscontrcoconusfromt) is the based path space, the first stone of the
; funext chain. every name is UniMath's.
(assert
 (defn 'coconusfromt '(pi T UU (pi t T UU))
   '(lam T (lam t (total2 tp T (paths T t tp)))))
 (defn 'iscontrcoconusfromt '(pi T UU (pi t T (iscontr (coconusfromt T t))))
   '(lam T (lam t (tpair (tpair t (idpath t))
      (lam w (paths_rect
               (lam bp (lam ep (paths (coconusfromt T t) (tpair bp ep)
                                      (tpair t (idpath t)))))
               (idpath (tpair t (idpath t)))
               (pr2 w)))))))
 (defn 'invproofirrelevance
   '(pi X UU (pi h (pi x X (pi y X (paths X x y))) (isaprop X)))
   '(lam X (lam h (lam x (lam y
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
 (defn 'negpaths0sx '(pi k nat (pi e (paths nat 0 (succ k)) empty))
   '(lam k (lam e (transportf nat
      (lam n (nat_rect (lam q UU) unit (lam m (lam r empty)) n))
      0 (succ k) e tt))))
 (defn 'negpathssx0 '(pi k nat (pi e (paths nat (succ k) 0) empty))
   '(lam k (lam e (transportf nat
      (lam n (nat_rect (lam q UU) empty (lam m (lam r unit)) n))
      (succ k) 0 e tt))))
 (defn 'isdeceqbool
   '(pi x bool (pi y bool (coprod (paths bool x y) (pi e (paths bool x y) empty))))
   '(lam x (lam y
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
 (defn 'isaproppathsfromisolated
   '(pi X UU (pi x X
      (pi is (pi y X (coprod (paths X x y) (pi e (paths X x y) empty)))
        (pi y X (isaprop (paths X x y))))))
   '(lam X (lam x (lam is (lam y
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
            ; p = !G0 @ (G p), by J
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
            ; !G0 @ (G p) = !G0 @ (G q) = q
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
 (defn 'isasetifdeceq
   '(pi X UU
      (pi dec (pi x X (pi y X (coprod (paths X x y) (pi e (paths X x y) empty))))
        (isaset X)))
   '(lam X (lam dec (lam x (lam y (isaproppathsfromisolated X x (dec x) y))))))
 (defn 'isasetbool '(isaset bool) '(isasetifdeceq bool isdeceqbool))
 (defn 'isdeceqnat
   '(pi x nat (pi y nat (coprod (paths nat x y) (pi e (paths nat x y) empty))))
   '(lam x (lam y
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
 (defn 'isasetnat '(isaset nat) '(isasetifdeceq nat isdeceqnat)))

; FUNEXT FROM UNIVALENCE -- the UAH chain of UnivalenceAxiom.v, names and
; route both Voevodsky's: any transport scheme R that fixes the identity
; equivalence IS transportb along weqtopaths (weqtransportbUAH, by J + the
; section weqpathsweq), so precomposition with a weq is a weq
; (isweqcompwithweqUAH -- the identity case is DEFINITIONAL by pi-eta), so
; precomposition cancels (eqcor0UAH); the diagonal T -> pathsspace T is a weq
; (the coconut contracts), and precomposing the two projections with it gives
; the same function definitionally -- so the projections are EQUAL
; (apathpr1toprUAH): a function path minted from the axiom. funextfun follows
; by one maponpaths, and funextempty stops being an axiom. the let form pays
; its way in weqtransportbUAH; natplusr0 + the demo mint a path
; (lam n (add n 0)) = (lam n n) that no conversion sees.
(assert
 (defn 'transportb
   '(pi A UU (pi P (pi x A UU) (pi a A (pi b A (pi e (paths A a b) (pi p (P b) (P a)))))))
   '(lam A (lam P (lam a (lam b (lam e (transportf A P b a (pathsinv0 A a b e))))))))
 (defn 'isweqtransportf
   '(pi A UU (pi P (pi x A UU) (pi a A (pi b A (pi e (paths A a b)
      (isweq (P a) (P b) (transportf A P a b e)))))))
   '(lam A (lam P (lam a (lam b (lam e
      (paths_rect
        (lam bp (lam ep (isweq (P a) (P bp) (transportf A P a bp ep))))
        (idisweq (P a))
        e)))))))
 (defn 'isweqtransportb
   '(pi A UU (pi P (pi x A UU) (pi a A (pi b A (pi e (paths A a b)
      (isweq (P b) (P a) (transportb A P a b e)))))))
   '(lam A (lam P (lam a (lam b (lam e
      (isweqtransportf A P b a (pathsinv0 A a b e))))))))
 (defn 'invmaponpathsweq
   '(pi X UU (pi Y UU (pi w (weq X Y) (pi x X (pi xp X
      (pi e (paths Y ((pr1 w) x) ((pr1 w) xp)) (paths X x xp)))))))
   '(lam X (lam Y (lam w (lam x (lam xp (lam e
      (pathscomp0 X x (invmap X Y w ((pr1 w) x)) xp
        (pathsinv0 X (invmap X Y w ((pr1 w) x)) x (homotinvweqweq X Y w x))
        (pathscomp0 X (invmap X Y w ((pr1 w) x)) (invmap X Y w ((pr1 w) xp)) xp
          (maponpaths Y X (lam y (invmap X Y w y)) ((pr1 w) x) ((pr1 w) xp) e)
          (homotinvweqweq X Y w xp))))))))))
 (defn 'iscontrweqb
   '(pi X UU (pi Y UU (pi w (weq X Y) (pi is (iscontr Y) (iscontr X)))))
   '(lam X (lam Y (lam w (lam is
      (iscontrretract Y X (lam y (invmap X Y w y)) (pr1 w)
        (homotinvweqweq X Y w) is))))))
 (defn 'weqtransportbUAH
   '(pi P (pi T UU UU)
      (pi R (pi X UU (pi Xp UU (pi w (weq X Xp) (pi p (P Xp) (P X)))))
        (pi r (pi X UU (pi p (P X) (paths (P X) (R X X (idweq X) p) p)))
          (pi X UU (pi Xp UU (pi w (weq X Xp) (pi pp (P Xp)
            (paths (P X) (R X Xp w pp)
                   (transportb UU P X Xp (weqtopaths X Xp w) pp)))))))))
   '(lam P (lam R (lam r (lam X (lam Xp (lam w (lam pp
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
 (defn 'isweqweqtransportbUAH
   '(pi P (pi T UU UU)
      (pi R (pi X UU (pi Xp UU (pi w (weq X Xp) (pi p (P Xp) (P X)))))
        (pi r (pi X UU (pi p (P X) (paths (P X) (R X X (idweq X) p) p)))
          (pi X UU (pi Xp UU (pi w (weq X Xp)
            (isweq (P Xp) (P X) (lam pp (R X Xp w pp)))))))))
   '(lam P (lam R (lam r (lam X (lam Xp (lam w
      (isweqhomot (P Xp) (P X)
        (lam pp (transportb UU P X Xp (weqtopaths X Xp w) pp))
        (lam pp (R X Xp w pp))
        (lam pp (pathsinv0 (P X)
                  (R X Xp w pp)
                  (transportb UU P X Xp (weqtopaths X Xp w) pp)
                  (weqtransportbUAH P R r X Xp w pp)))
        (isweqtransportb UU P X Xp (weqtopaths X Xp w))))))))))
 (defn 'isweqcompwithweqUAH
   '(pi X UU (pi Xp UU (pi w (weq X Xp) (pi Y UU
      (isweq (pi x Xp Y) (pi x X Y) (lam f (lam x (f ((pr1 w) x)))))))))
   '(lam X (lam Xp (lam w (lam Y
      (isweqweqtransportbUAH
        (lam T (pi t T Y))
        (lam X0 (lam X0p (lam w1 (lam f (lam x (f ((pr1 w1) x)))))))
        (lam X0 (lam f (idpath f)))
        X Xp w))))))
 (defn 'eqcor0UAH
   '(pi X UU (pi Xp UU (pi w (weq X Xp) (pi Y UU
      (pi f1 (pi x Xp Y) (pi f2 (pi x Xp Y)
        (pi ee (paths (pi x X Y) (lam x (f1 ((pr1 w) x))) (lam x (f2 ((pr1 w) x))))
          (paths (pi x Xp Y) f1 f2))))))))
   '(lam X (lam Xp (lam w (lam Y (lam f1 (lam f2 (lam ee
      (invmaponpathsweq (pi x Xp Y) (pi x X Y)
        (tpair (lam f (lam x (f ((pr1 w) x)))) (isweqcompwithweqUAH X Xp w Y))
        f1 f2 ee)))))))))
 (defn 'pathsspace '(pi T UU UU) '(lam T (total2 x T (coconusfromt T x))))
 (defn 'pathsspacetriple
   '(pi T UU (pi t1 T (pi t2 T (pi e (paths T t1 t2) (pathsspace T)))))
   '(lam T (lam t1 (lam t2 (lam e (tpair t1 (tpair t2 e)))))))
 (defn 'deltap '(pi T UU (pi t T (pathsspace T)))
   '(lam T (lam t (tpair t (tpair t (idpath t))))))
 (defn 'isweqdeltap '(pi T UU (isweq T (pathsspace T) (deltap T)))
   '(lam T (isweq_iso T (pathsspace T) (deltap T) (lam z (pr1 z))
      (lam t (idpath t))
      (lam z (total2_paths_f T (lam x (coconusfromt T x))
               (deltap T (pr1 z))
               z
               (idpath (pr1 z))
               (pathsinv0 (coconusfromt T (pr1 z))
                 (pr2 z)
                 (tpair (pr1 z) (idpath (pr1 z)))
                 ((pr2 (iscontrcoconusfromt T (pr1 z))) (pr2 z))))))))
 (defq 'apathpr1toprUAH
   '(pi T UU (paths (pi z (pathsspace T) T)
              (lam z (pr1 z))
              (lam z (pr1 (pr2 z)))))
   '(lam T (eqcor0UAH T (pathsspace T)
      (tpair (deltap T) (isweqdeltap T))
      T
      (lam z (pr1 z))
      (lam z (pr1 (pr2 z)))
      (idpath (lam t t)))))
 (defq 'funextfun
   '(pi X UU (pi Y UU (pi f1 (pi x X Y) (pi f2 (pi x X Y)
      (pi e (pi x X (paths Y (f1 x) (f2 x)))
        (paths (pi x X Y) f1 f2))))))
   '(lam X (lam Y (lam f1 (lam f2 (lam e
      (maponpaths (pi z (pathsspace Y) Y) (pi x X Y)
        (lam g (lam x (g (tpair (f1 x) (tpair (f2 x) (e x))))))
        (lam z (pr1 z))
        (lam z (pr1 (pr2 z)))
        (apathpr1toprUAH Y))))))))
 (defn 'funextempty
   '(pi X UU (pi f (pi x X empty) (pi g (pi x X empty) (paths (pi x X empty) f g))))
   '(lam X (lam f (lam g
      (funextfun X empty f g
        (lam x (fromempty (paths empty (f x) (g x)) (f x))))))))
 (defn 'natplusr0 '(pi n nat (paths nat (add n 0) n))
   '(lam n (nat_rect (lam m (paths nat (add m 0) m))
             (idpath 0)
             (lam k (lam IH (maponpaths nat nat (lam m (succ m)) (add k 0) k IH)))
             n)))
 (defq 'uu-funext-demo
   '(paths (pi n nat nat) (lam n (add n 0)) (lam n n))
   '(funextfun nat nat (lam n (add n 0)) (lam n n) natplusr0))
 (defn 'uu-let-demo '(paths nat (let two 2 (add two two)) 4) '(idpath 4)))

; FUNEXTSEC -- dependent function extensionality, the funcontr route of
; UnivalenceAxiom.v: pr1 of a pointwise-contractible total space is a weq
; (isweqpr1, by the grad lemma with the section-of-centers), postcomposition
; with it is a weq (isweqrcompwithweqUAH -- the homotopies are funextfun's,
; our PROVED one, applied as an opaque inhabitant), so the space of sections
; retracts onto the contractible fiber over the identity (funcontrUAH; the
; retraction equation is DEFINITIONAL: toforallpaths computes at idpath and
; eta closes it). funextcontr contracts the section-coconut, and funextsec
; falls out by proof irrelevance + one maponpaths -- no isweqtotaltofib
; needed. heavy proofs are Qed-sealed.
(assert
 (defn 'toforallpaths
   '(pi T UU (pi P (pi t T UU) (pi f (pi t T (P t)) (pi g (pi t T (P t))
      (pi e (paths (pi t T (P t)) f g) (pi t T (paths (P t) (f t) (g t))))))))
   '(lam T (lam P (lam f (lam g (lam e (lam t
      (maponpaths (pi tq T (P tq)) (P t) (lam h (h t)) f g e))))))))
 (defn 'coconustot '(pi T UU (pi t T UU))
   '(lam T (lam t (total2 tp T (paths T tp t)))))
 (defn 'iscontrcoconustot '(pi T UU (pi t T (iscontr (coconustot T t))))
   '(lam T (lam t (tpair (tpair t (idpath t))
      (lam w (paths_rect
               (lam bp (lam ep (paths (coconustot T bp)
                                      (tpair (pr1 w) ep)
                                      (tpair bp (idpath bp)))))
               (idpath (tpair (pr1 w) (idpath (pr1 w))))
               (pr2 w)))))))
 (defq 'isweqpr1
   '(pi X UU (pi P (pi x X UU) (pi is (pi x X (iscontr (P x)))
      (isweq (total2 x X (P x)) X (lam s (pr1 s))))))
   '(lam X (lam P (lam is
      (isweq_iso (total2 x X (P x)) X (lam s (pr1 s))
        (lam x (tpair x (pr1 (is x))))
        (lam s (total2_paths_f X P
                 (tpair (pr1 s) (pr1 (is (pr1 s))))
                 s
                 (idpath (pr1 s))
                 (pathsinv0 (P (pr1 s)) (pr2 s) (pr1 (is (pr1 s)))
                   ((pr2 (is (pr1 s))) (pr2 s)))))
        (lam x (idpath x)))))))
 (defq 'isweqcontrcontr
   '(pi X UU (pi Y UU (pi f (pi x X Y) (pi isx (iscontr X) (pi isy (iscontr Y)
      (isweq X Y f))))))
   '(lam X (lam Y (lam f (lam isx (lam isy
      (isweq_iso X Y f (lam y (pr1 isx))
        (lam x (proofirrelevancecontr X isx (pr1 isx) x))
        (lam y (proofirrelevancecontr Y isy (f (pr1 isx)) y)))))))))
 (defq 'isweqrcompwithweqUAH
   '(pi Y UU (pi Yp UU (pi w (weq Y Yp) (pi X UU
      (isweq (pi x X Y) (pi x X Yp) (lam a (lam x ((pr1 w) (a x)))))))))
   '(lam Y (lam Yp (lam w (lam X
      (isweq_iso (pi x X Y) (pi x X Yp)
        (lam a (lam x ((pr1 w) (a x))))
        (lam ap (lam x (invmap Y Yp w (ap x))))
        (lam a (funextfun X Y (lam x (invmap Y Yp w ((pr1 w) (a x)))) a
                 (lam x (homotinvweqweq Y Yp w (a x)))))
        (lam ap (funextfun X Yp (lam x ((pr1 w) (invmap Y Yp w (ap x)))) ap
                 (lam x (homotweqinvweq Y Yp w (ap x)))))))))))
 (defq 'funcontrUAH
   '(pi X UU (pi P (pi x X UU) (pi X0 (pi x X (iscontr (P x)))
      (iscontr (pi x X (P x))))))
   '(lam X (lam P (lam X0
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
 (defq 'funextcontrUAH
   '(pi T UU (pi P (pi t T UU) (pi g (pi t T (P t))
      (iscontr (total2 f (pi t T (P t)) (pi t T (paths (P t) (f t) (g t))))))))
   '(lam T (lam P (lam g
      (iscontrretract
        (pi t T (coconustot (P t) (g t)))
        (total2 f (pi t T (P t)) (pi t T (paths (P t) (f t) (g t))))
        (lam x (tpair (lam t (pr1 (x t))) (lam t (pr2 (x t)))))
        (lam y (lam t (tpair ((pr1 y) t) ((pr2 y) t))))
        (lam y (idpath y))
        (funcontrUAH T (lam t (coconustot (P t) (g t)))
          (lam t (iscontrcoconustot (P t) (g t)))))))))
 (defq 'funextsec
   '(pi T UU (pi P (pi t T UU) (pi f (pi t T (P t)) (pi g (pi t T (P t))
      (pi e (pi t T (paths (P t) (f t) (g t)))
        (paths (pi t T (P t)) f g))))))
   '(lam T (lam P (lam f (lam g (lam e
      (let CT (the UU (total2 h (pi t T (P t)) (pi t T (paths (P t) (h t) (g t)))))
        (maponpaths CT (pi t T (P t)) (lam z (pr1 z))
          (tpair f e)
          (tpair g (lam t (idpath (g t))))
          (proofirrelevancecontr CT
            (funextcontrUAH T P g)
            (tpair f e)
            (tpair g (lam t (idpath (g t)))))))))))))
 (defq 'uu-funextsec-demo
   '(paths (pi n nat nat) (lam n (add n 0)) (lam n n))
   '(funextsec nat (lam n nat) (lam n (add n 0)) (lam n n) natplusr0)))

; THE GIRARD CANARY (UniMath/Paradoxes/GirardsParadox.v, literally): under
; type-in-type the world explodes, and the kernel must CHECK it -- exactly
; the artifact the reference ships compiled. orderings with no infinite
; descent, ordered by dominated embeddings, are such an ordering; the order
; type of all order types embeds them all, so it exceeds itself, and
; irreflexivity detonates. but_seriously_the_world_explodes : empty is a
; CLOSED CHECKED TERM -- the honest price of UU : UU, paid in public.
; type formers and the nat_rect tower stay transparent (the descent proof's
; type must compute); the proofs are Qed-sealed.
(assert
 (defn 'wf '(pi Flse UU (pi T UU UU))
   '(lam Flse (lam T
      (total2 lt (pi x T (pi y T UU))
        (total2 tr (pi x T (pi y T (pi z T (pi p (lt x y) (pi q (lt y z) (lt x z))))))
          (pi h (pi n nat T)
            (pi ds (pi n nat (lt (h (succ n)) (h n)))
              Flse)))))))
 (defn 'wfs '(pi Flse UU UU)
   '(lam Flse (total2 T UU (wf Flse T))))
 (defn 'uset '(pi Flse UU (pi w (wfs Flse) UU))
   '(lam Flse (lam w (pr1 w))))
 (defn 'uord
   '(pi Flse UU (pi w (wfs Flse) (pi x (uset Flse w) (pi y (uset Flse w) UU))))
   '(lam Flse (lam w (pr1 (pr2 w)))))
 (defn 'trans
   '(pi Flse UU (pi w (wfs Flse)
      (pi x (uset Flse w) (pi y (uset Flse w) (pi z (uset Flse w)
        (pi p (uord Flse w x y) (pi q (uord Flse w y z) (uord Flse w x z))))))))
   '(lam Flse (lam w (pr1 (pr2 (pr2 w))))))
 (defn 'wfp
   '(pi Flse UU (pi w (wfs Flse)
      (pi h (pi n nat (uset Flse w))
        (pi ds (pi n nat (uord Flse w (h (succ n)) (h n)))
          Flse))))
   '(lam Flse (lam w (pr2 (pr2 (pr2 w))))))
 (defn 'wfs_wf_uord
   '(pi Flse UU (pi v (wfs Flse) (pi w (wfs Flse) UU)))
   '(lam Flse (lam v (lam w
      (total2 f (pi x (uset Flse v) (uset Flse w))
        (total2 hm (pi x (uset Flse v) (pi y (uset Flse v)
                     (pi p (uord Flse v x y) (uord Flse w (f x) (f y)))))
          (total2 y (uset Flse w)
            (pi x (uset Flse v) (uord Flse w (f x) y)))))))))
 (defn 'ufun
   '(pi Flse UU (pi v (wfs Flse) (pi w (wfs Flse)
      (pi a (wfs_wf_uord Flse v w) (pi x (uset Flse v) (uset Flse w))))))
   '(lam Flse (lam v (lam w (lam a (pr1 a))))))
 (defn 'homo
   '(pi Flse UU (pi v (wfs Flse) (pi w (wfs Flse)
      (pi a (wfs_wf_uord Flse v w)
        (pi x (uset Flse v) (pi y (uset Flse v)
          (pi p (uord Flse v x y) (uord Flse w ((pr1 a) x) ((pr1 a) y)))))))))
   '(lam Flse (lam v (lam w (lam a (pr1 (pr2 a)))))))
 (defn 'domi
   '(pi Flse UU (pi v (wfs Flse) (pi w (wfs Flse)
      (pi a (wfs_wf_uord Flse v w) (uset Flse w)))))
   '(lam Flse (lam v (lam w (lam a (pr1 (pr2 (pr2 a))))))))
 (defn 'domicom
   '(pi Flse UU (pi v (wfs Flse) (pi w (wfs Flse)
      (pi a (wfs_wf_uord Flse v w)
        (pi x (uset Flse v) (uord Flse w ((pr1 a) x) (pr1 (pr2 (pr2 a)))))))))
   '(lam Flse (lam v (lam w (lam a (pr2 (pr2 (pr2 a))))))))
 (defq 'wfs_wf_trans
   '(pi Flse UU (pi x (wfs Flse) (pi y (wfs Flse) (pi z (wfs Flse)
      (pi f (wfs_wf_uord Flse x y) (pi g (wfs_wf_uord Flse y z)
        (wfs_wf_uord Flse x z)))))))
   '(lam Flse (lam x (lam y (lam z (lam f (lam g
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
 (defn 'wfs_wf_wfp_shift
   '(pi Flse UU (pi f (pi n nat (wfs Flse))
      (pi b (pi n nat (wfs_wf_uord Flse (f (succ n)) (f n)))
        (pi n nat (pi a (uset Flse (f n)) (uset Flse (f 0)))))))
   '(lam Flse (lam f (lam b (lam n
      (nat_rect (lam m (pi a (uset Flse (f m)) (uset Flse (f 0))))
        (lam a a)
        (lam m (lam IH (lam x (IH ((pr1 (b m)) x)))))
        n))))))
 (defn 'wfs_wf_wfp_seq
   '(pi Flse UU (pi f (pi n nat (wfs Flse))
      (pi b (pi n nat (wfs_wf_uord Flse (f (succ n)) (f n)))
        (pi n nat (uset Flse (f 0))))))
   '(lam Flse (lam f (lam b (lam n
      ((wfs_wf_wfp_shift Flse f b n)
       (domi Flse (f (succ n)) (f n) (b n))))))))
 (defq 'wfs_wf_wfp_compshift
   '(pi Flse UU (pi f (pi n nat (wfs Flse))
      (pi b (pi n nat (wfs_wf_uord Flse (f (succ n)) (f n)))
        (pi n nat (pi x (uset Flse (f n)) (pi y (uset Flse (f n))
          (pi p (uord Flse (f n) x y)
            (uord Flse (f 0)
              ((wfs_wf_wfp_shift Flse f b n) x)
              ((wfs_wf_wfp_shift Flse f b n) y)))))))))
   '(lam Flse (lam f (lam b (lam n
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
 (defq 'wfs_wf_wfp_desc
   '(pi Flse UU (pi f (pi n nat (wfs Flse))
      (pi b (pi n nat (wfs_wf_uord Flse (f (succ n)) (f n)))
        (pi n nat
          (uord Flse (f 0)
            (wfs_wf_wfp_seq Flse f b (succ n))
            (wfs_wf_wfp_seq Flse f b n))))))
   '(lam Flse (lam f (lam b (lam n
      (wfs_wf_wfp_compshift Flse f b n
        ((pr1 (b n)) (domi Flse (f (succ (succ n))) (f (succ n)) (b (succ n))))
        (domi Flse (f (succ n)) (f n) (b n))
        (domicom Flse (f (succ n)) (f n) (b n)
          (domi Flse (f (succ (succ n))) (f (succ n)) (b (succ n))))))))))
 (defn 'wfs_wf '(pi Flse UU (wf Flse (wfs Flse)))
   '(lam Flse
      (tpair (wfs_wf_uord Flse)
        (tpair (wfs_wf_trans Flse)
          (lam h (lam b
            (wfp Flse (h 0)
              (wfs_wf_wfp_seq Flse h b)
              (wfs_wf_wfp_desc Flse h b))))))))
 (defn 'wfs_wf_t '(pi Flse UU (wfs Flse))
   '(lam Flse (tpair (wfs Flse) (wfs_wf Flse))))
 (defn 'maxi_fun
   '(pi Flse UU (pi w (wfs Flse) (pi x (uset Flse w) (wfs Flse))))
   '(lam Flse (lam w (lam x
      (tpair (total2 y (uset Flse w) (uord Flse w y x))
        (tpair (lam a (lam bb (uord Flse w (pr1 a) (pr1 bb))))
          (tpair (lam x0 (lam y0 (lam z0 (lam p (lam q
                   (trans Flse w (pr1 x0) (pr1 y0) (pr1 z0) p q))))))
            (lam h (lam b
              (wfp Flse w (lam n (pr1 (h n))) b))))))))))
 (defq 'maxi_homo
   '(pi Flse UU (pi w (wfs Flse) (pi x (uset Flse w) (pi y (uset Flse w)
      (pi p (uord Flse w x y)
        (wfs_wf_uord Flse (maxi_fun Flse w x) (maxi_fun Flse w y)))))))
   '(lam Flse (lam w (lam x (lam y (lam p
      (tpair (lam z (tpair (pr1 z) (trans Flse w (pr1 z) x y (pr2 z) p)))
        (tpair (lam x0 (lam y0 (lam q q)))
          (tpair (tpair x p)
            (lam x0 (pr2 x0)))))))))))
 (defq 'maxidom
   '(pi Flse UU (pi w (wfs Flse) (pi x (uset Flse w)
      (wfs_wf_uord Flse (maxi_fun Flse w x) w))))
   '(lam Flse (lam w (lam x
      (tpair (lam z (pr1 z))
        (tpair (lam x0 (lam y0 (lam p p)))
          (tpair x
            (lam x0 (pr2 x0)))))))))
 (defq 'maxi
   '(pi Flse UU (pi w (wfs Flse) (wfs_wf_uord Flse w (wfs_wf_t Flse))))
   '(lam Flse (lam w
      (tpair (maxi_fun Flse w)
        (tpair (maxi_homo Flse w)
          (tpair w (maxidom Flse w)))))))
 (defq 'whoa
   '(pi Flse UU (uord Flse (wfs_wf_t Flse) (wfs_wf_t Flse) (wfs_wf_t Flse)))
   '(lam Flse (maxi Flse (wfs_wf_t Flse))))
 (defq 'irref
   '(pi Flse UU (pi w (wfs Flse) (pi x (uset Flse w)
      (pi p (uord Flse w x x) Flse))))
   '(lam Flse (lam w (lam x (lam p
      (wfp Flse w (lam n x) (lam n p)))))))
 (defq 'the_world_explodes '(pi Flse UU Flse)
   '(lam Flse (irref Flse (wfs_wf_t Flse) (wfs_wf_t Flse) (whoa Flse))))
 (defq 'but_seriously_the_world_explodes 'empty
   '(the_world_explodes empty)))

; THE HPROP LOGIC LAYER (Propositions.v) -- what funext just unblocked.
; impred_isaprop is the engine (a product of props is a prop, one funextsec);
; isapropiscontr is the keystone (being contractible is a proposition:
; total2_paths_f + funextsec + paths-in-a-contractible-are-props), and then
; being-a-prop and being-a-weq are props. the connectives land as honest
; hProps -- conjunction by isapropdirprod, disjunction and exists through the
; truncation, implication and negation by impred -- with the intro rules and
; a squash-recursion demo. names are UniMath's; proofs Qed, formers stay
; transparent (the demos project them with pr1).
(assert
 (defq 'isapropempty '(isaprop empty)
   '(lam x (lam y (fromempty (iscontr (paths empty x y)) x))))
 (defq 'isapropifcontr '(pi X UU (pi is (iscontr X) (isaprop X)))
   '(lam X (lam is (lam x (lam y
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
 (defq 'iscontraprop1 '(pi X UU (pi ip (isaprop X) (pi x X (iscontr X))))
   '(lam X (lam ip (lam x (tpair x (lam t (pr1 (ip t x))))))))
 (defq 'impred_isaprop
   '(pi T UU (pi P (pi t T UU) (pi ip (pi t T (isaprop (P t)))
      (isaprop (pi t T (P t))))))
   '(lam T (lam P (lam ip
      (invproofirrelevance (pi t T (P t))
        (lam f (lam g
          (funextsec T P f g (lam t (pr1 (ip t (f t) (g t))))))))))))
 (defq 'isapropiscontr '(pi X UU (isaprop (iscontr X)))
   '(lam X (invproofirrelevance (iscontr X)
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
 (defq 'isapropisaprop '(pi X UU (isaprop (isaprop X)))
   '(lam X (impred_isaprop X (lam x (pi y X (iscontr (paths X x y))))
      (lam x (impred_isaprop X (lam y (iscontr (paths X x y)))
        (lam y (isapropiscontr (paths X x y))))))))
 (defq 'isapropisweq
   '(pi X UU (pi Y UU (pi f (pi x X Y) (isaprop (isweq X Y f)))))
   '(lam X (lam Y (lam f
      (impred_isaprop Y (lam y (iscontr (hfiber X Y f y)))
        (lam y (isapropiscontr (hfiber X Y f y))))))))
 (defq 'isapropdirprod
   '(pi A UU (pi B UU (pi ipa (isaprop A) (pi ipb (isaprop B)
      (isaprop (total2 q A B))))))
   '(lam A (lam B (lam ipa (lam ipb
      (invproofirrelevance (total2 q A B)
        (lam x (lam y
          (total2_paths_f A (lam q B) x y
            (pr1 (ipa (pr1 x) (pr1 y)))
            (pr1 (ipb (transportf A (lam q B) (pr1 x) (pr1 y)
                        (pr1 (ipa (pr1 x) (pr1 y))) (pr2 x))
                      (pr2 y))))))))))))
 (defq 'isapropneg '(pi X UU (isaprop (pi x X empty)))
   '(lam X (impred_isaprop X (lam x empty) (lam x isapropempty))))
 (defq 'isapropishinh '(pi X UU (isaprop (ishinh_UU X)))
   '(lam X (impred_isaprop hProp (lam P (pi f (pi x X (pr1 P)) (pr1 P)))
      (lam P (impred_isaprop (pi x X (pr1 P)) (lam f (pr1 P))
        (lam f (pr2 P)))))))
 (defn 'ishinh '(pi X UU hProp)
   '(lam X (tpair (ishinh_UU X) (isapropishinh X))))
 (defn 'htrue 'hProp '(tpair unit isapropunit))
 (defn 'hfalse 'hProp '(tpair empty isapropempty))
 (defn 'hconj '(pi P hProp (pi Q hProp hProp))
   '(lam P (lam Q (tpair (total2 q (pr1 P) (pr1 Q))
      (isapropdirprod (pr1 P) (pr1 Q) (pr2 P) (pr2 Q))))))
 (defn 'hdisj '(pi P UU (pi Q UU hProp))
   '(lam P (lam Q (ishinh (coprod P Q)))))
 (defn 'himpl '(pi P UU (pi Q hProp hProp))
   '(lam P (lam Q (tpair (pi p P (pr1 Q))
      (impred_isaprop P (lam p (pr1 Q)) (lam p (pr2 Q)))))))
 (defn 'hneg '(pi P UU hProp)
   '(lam P (tpair (pi p P empty) (isapropneg P))))
 (defn 'hexists '(pi X UU (pi P (pi x X UU) hProp))
   '(lam X (lam P (ishinh (total2 x X (P x))))))
 (defq 'hdisj_in1 '(pi P UU (pi Q UU (pi p P (pr1 (hdisj P Q)))))
   '(lam P (lam Q (lam p (hinhpr (coprod P Q) (ii1 p))))))
 (defq 'hdisj_in2 '(pi P UU (pi Q UU (pi q Q (pr1 (hdisj P Q)))))
   '(lam P (lam Q (lam q (hinhpr (coprod P Q) (ii2 q))))))
 (defq 'uu-htrue-demo '(pr1 htrue) 'tt)
 (defq 'uu-hconj-demo '(pr1 (hconj htrue htrue)) '(tpair tt tt))
 (defq 'uu-hdisj-demo '(pr1 (hdisj unit empty)) '(hdisj_in1 unit empty tt))
 (defq 'uu-squash-demo '(pr1 htrue)
   '(hinhuniv unit htrue (lam u u) (hinhpr unit tt))))

; SETQUOT (Sets.v) -- the impredicative set quotient: classes are hProp-valued
; subtypes, compared by funextsec over hPropUnivalence -- propositional
; univalence, itself a THEOREM here (weqtopaths + isweqimplimpl +
; isapropisaprop). the universal map factors through the prop-valued image
; and computes: setquotunivcomm checks BY IDPATH, exactly as in Coq. the
; demo quotients bool by the total relation and evaluates the induced map.
(assert
 (defn 'hrel '(pi X UU UU) '(lam X (pi x X (pi y X hProp))))
 (defn 'istrans '(pi X UU (pi R (hrel X) UU))
   '(lam X (lam R (pi x1 X (pi x2 X (pi x3 X
      (pi r1 (pr1 (R x1 x2)) (pi r2 (pr1 (R x2 x3)) (pr1 (R x1 x3))))))))))
 (defn 'isrefl '(pi X UU (pi R (hrel X) UU))
   '(lam X (lam R (pi x X (pr1 (R x x))))))
 (defn 'issymm '(pi X UU (pi R (hrel X) UU))
   '(lam X (lam R (pi x1 X (pi x2 X (pi r (pr1 (R x1 x2)) (pr1 (R x2 x1))))))))
 (defn 'iseqrel '(pi X UU (pi R (hrel X) UU))
   '(lam X (lam R (total2 q (istrans X R) (total2 q2 (isrefl X R) (issymm X R))))))
 (defn 'eqrel '(pi X UU UU) '(lam X (total2 R (hrel X) (iseqrel X R))))
 (defn 'eqreltrans '(pi X UU (pi E (eqrel X) (istrans X (pr1 E))))
   '(lam X (lam E (pr1 (pr2 E)))))
 (defn 'eqrelrefl '(pi X UU (pi E (eqrel X) (isrefl X (pr1 E))))
   '(lam X (lam E (pr1 (pr2 (pr2 E))))))
 (defn 'eqrelsymm '(pi X UU (pi E (eqrel X) (issymm X (pr1 E))))
   '(lam X (lam E (pr2 (pr2 (pr2 E))))))
 (defn 'hsubtype '(pi X UU UU) '(lam X (pi x X hProp)))
 (defn 'carrier '(pi X UU (pi A (hsubtype X) UU))
   '(lam X (lam A (total2 x X (pr1 (A x))))))
 (defn 'iseqclass '(pi X UU (pi R (hrel X) (pi A (hsubtype X) UU)))
   '(lam X (lam R (lam A
      (total2 q (ishinh_UU (carrier X A))
        (total2 q2
          (pi x1 X (pi x2 X (pi r (pr1 (R x1 x2)) (pi a (pr1 (A x1)) (pr1 (A x2))))))
          (pi x1 X (pi x2 X (pi a1 (pr1 (A x1)) (pi a2 (pr1 (A x2)) (pr1 (R x1 x2))))))))))))
 (defn 'eqax0
   '(pi X UU (pi R (hrel X) (pi A (hsubtype X)
      (pi is (iseqclass X R A) (ishinh_UU (carrier X A))))))
   '(lam X (lam R (lam A (lam is (pr1 is))))))
 (defn 'eqax1
   '(pi X UU (pi R (hrel X) (pi A (hsubtype X)
      (pi is (iseqclass X R A)
        (pi x1 X (pi x2 X (pi r (pr1 (R x1 x2)) (pi a (pr1 (A x1)) (pr1 (A x2))))))))))
   '(lam X (lam R (lam A (lam is (pr1 (pr2 is)))))))
 (defn 'eqax2
   '(pi X UU (pi R (hrel X) (pi A (hsubtype X)
      (pi is (iseqclass X R A)
        (pi x1 X (pi x2 X (pi a1 (pr1 (A x1)) (pi a2 (pr1 (A x2)) (pr1 (R x1 x2))))))))))
   '(lam X (lam R (lam A (lam is (pr2 (pr2 is)))))))
 (defn 'setquot '(pi X UU (pi R (hrel X) UU))
   '(lam X (lam R (total2 A (hsubtype X) (iseqclass X R A)))))
 (defn 'setquotpr '(pi X UU (pi E (eqrel X) (pi x0 X (setquot X (pr1 E)))))
   '(lam X (lam E (lam x0
      (tpair (lam x ((pr1 E) x0 x))
        (tpair (hinhpr (carrier X (lam x ((pr1 E) x0 x)))
                 (tpair x0 (eqrelrefl X E x0)))
          (tpair (lam x1 (lam x2 (lam r (lam a
                   (eqreltrans X E x0 x1 x2 a r)))))
            (lam x1 (lam x2 (lam a1 (lam a2
              (eqreltrans X E x1 x0 x2 (eqrelsymm X E x0 x1 a1) a2))))))))))))
 (defq 'isweqimplimpl
   '(pi X UU (pi Y UU (pi f (pi x X Y) (pi g (pi y Y X)
      (pi ipx (isaprop X) (pi ipy (isaprop Y) (isweq X Y f)))))))
   '(lam X (lam Y (lam f (lam g (lam ipx (lam ipy
      (isweq_iso X Y f g
        (lam x (pr1 (ipx (g (f x)) x)))
        (lam y (pr1 (ipy (f (g y)) y)))))))))))
 (defq 'hPropUnivalence
   '(pi P hProp (pi Q hProp
      (pi f (pi p (pr1 P) (pr1 Q)) (pi g (pi q (pr1 Q) (pr1 P))
        (paths hProp P Q)))))
   '(lam P (lam Q (lam f (lam g
      (let e (weqtopaths (pr1 P) (pr1 Q)
               (tpair f (isweqimplimpl (pr1 P) (pr1 Q) f g (pr2 P) (pr2 Q))))
        (total2_paths_f UU (lam Xq (isaprop Xq)) P Q
          e
          (pr1 ((isapropisaprop (pr1 Q))
                 (transportf UU (lam Xq (isaprop Xq)) (pr1 P) (pr1 Q) e (pr2 P))
                 (pr2 Q))))))))))
 (defq 'isapropiseqclass
   '(pi X UU (pi R (hrel X) (pi A (hsubtype X) (isaprop (iseqclass X R A)))))
   '(lam X (lam R (lam A
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
 (defq 'iscompsetquotpr
   '(pi X UU (pi E (eqrel X) (pi x X (pi xp X
      (pi a (pr1 ((pr1 E) x xp))
        (paths (setquot X (pr1 E)) (setquotpr X E x) (setquotpr X E xp)))))))
   '(lam X (lam E (lam x (lam xp (lam a
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
 (defn 'image '(pi X UU (pi Y UU (pi f (pi x X Y) UU)))
   '(lam X (lam Y (lam f (total2 y Y (ishinh_UU (hfiber X Y f y)))))))
 (defn 'prtoimage '(pi X UU (pi Y UU (pi f (pi x X Y) (pi x X (image X Y f)))))
   '(lam X (lam Y (lam f (lam x
      (tpair (f x) (hinhpr (hfiber X Y f (f x)) (tpair x (idpath (f x))))))))))
 (defq 'isapropsubtype
   '(pi X UU (pi A (hsubtype X)
      (pi is (pi x1 X (pi x2 X (pi a1 (pr1 (A x1)) (pi a2 (pr1 (A x2)) (paths X x1 x2)))))
        (isaprop (carrier X A)))))
   '(lam X (lam A (lam is
      (invproofirrelevance (carrier X A)
        (lam c1 (lam c2
          (total2_paths_f X (lam x (pr1 (A x))) c1 c2
            (is (pr1 c1) (pr1 c2) (pr2 c1) (pr2 c2))
            (pr1 ((pr2 (A (pr1 c2)))
                   (transportf X (lam x (pr1 (A x))) (pr1 c1) (pr1 c2)
                     (is (pr1 c1) (pr1 c2) (pr2 c1) (pr2 c2))
                     (pr2 c1))
                   (pr2 c2)))))))))))
 (defq 'isapropimeqclass
   '(pi X UU (pi R (hrel X) (pi Y hSet (pi f (pi x X (pr1 Y))
      (pi is (pi x1 X (pi x2 X (pi r (pr1 (R x1 x2)) (paths (pr1 Y) (f x1) (f x2)))))
        (pi c (setquot X R)
          (isaprop (image (carrier X (pr1 c)) (pr1 Y) (lam xc (f (pr1 xc)))))))))))
   '(lam X (lam R (lam Y (lam f (lam is (lam c
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
 (defn 'setquotuniv
   '(pi X UU (pi R (hrel X) (pi Y hSet (pi f (pi x X (pr1 Y))
      (pi is (pi x1 X (pi x2 X (pi r (pr1 (R x1 x2)) (paths (pr1 Y) (f x1) (f x2)))))
        (pi c (setquot X R) (pr1 Y)))))))
   '(lam X (lam R (lam Y (lam f (lam is (lam c
      (pr1 (hinhuniv (carrier X (pr1 c))
             (tpair (image (carrier X (pr1 c)) (pr1 Y) (lam xc (f (pr1 xc))))
                    (isapropimeqclass X R Y f is c))
             (lam xc (prtoimage (carrier X (pr1 c)) (pr1 Y) (lam xc2 (f (pr1 xc2))) xc))
             (eqax0 X R (pr1 c) (pr2 c)))))))))))
 (defq 'setquotunivcomm
   '(pi X UU (pi E (eqrel X) (pi Y hSet (pi f (pi x X (pr1 Y))
      (pi is (pi x1 X (pi x2 X (pi r (pr1 ((pr1 E) x1 x2)) (paths (pr1 Y) (f x1) (f x2)))))
        (pi x X
          (paths (pr1 Y)
            (setquotuniv X (pr1 E) Y f is (setquotpr X E x))
            (f x))))))))
   '(lam X (lam E (lam Y (lam f (lam is (lam x (idpath (f x)))))))))
 ; the demo: bool quotiented by the total relation -- one class, and the
 ; induced constant map computes through the quotient by idpath.
 (defn 'uu-trivrel '(eqrel bool)
   '(tpair (lam x (lam y htrue))
      (tpair (lam x1 (lam x2 (lam x3 (lam r1 (lam r2 tt)))))
        (tpair (lam x tt)
          (lam x1 (lam x2 (lam r tt)))))))
 (defq 'uu-setquot-demo
   '(paths (setquot bool (pr1 uu-trivrel))
           (setquotpr bool uu-trivrel true)
           (setquotpr bool uu-trivrel false))
   '(iscompsetquotpr bool uu-trivrel true false tt))
 (defq 'uu-setquotuniv-demo
   '(paths nat
      (setquotuniv bool (pr1 uu-trivrel) (tpair nat isasetnat)
        (lam b 7)
        (lam x1 (lam x2 (lam r (idpath 7))))
        (setquotpr bool uu-trivrel true))
      7)
   '(idpath 7)))

; THE QUOTIENT IS A SET. the engine is path collapse (Kraus): maps both ways
; through a prop force the path type to be a prop -- NO retraction equation
; needed, so funextsec/toforallpaths qualify without a round-trip law, and
; hPropUnivalence/maponpaths-pr1 likewise. one engine, three theorems:
; hProp is a set (its paths collapse through logical equivalence), a product
; of sets is a set (paths collapse through pointwise paths), and setquot is
; a set (paths collapse through paths of underlying subtypes, the class
; axioms discharged as props). hPropset and setquotinset close Sets.v's arc.
(assert
 (defq 'uu-pathscollapse
   '(pi X UU (pi x X (pi PF (pi y X UU)
      (pi s (pi y X (pi e (paths X x y) (PF y)))
        (pi p (pi y X (pi q (PF y) (paths X x y)))
          (pi ip (pi y X (isaprop (PF y)))
            (pi y X (isaprop (paths X x y)))))))))
   '(lam X (lam x (lam PF (lam s (lam p (lam ip (lam y
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
 (defq 'isasethProp '(isaset hProp)
   '(lam P (lam Q
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
 (defq 'impred_isaset
   '(pi T UU (pi P (pi t T UU) (pi ips (pi t T (isaset (P t)))
      (isaset (pi t T (P t))))))
   '(lam T (lam P (lam ips (lam f
      (uu-pathscollapse (pi t T (P t)) f
        (lam g (pi t T (paths (P t) (f t) (g t))))
        (lam g (lam e (toforallpaths T P f g e)))
        (lam g (lam pf (funextsec T P f g pf)))
        (lam g (impred_isaprop T (lam t (paths (P t) (f t) (g t)))
                 (lam t (ips t (f t) (g t)))))))))))
 (defq 'isasethsubtype '(pi X UU (isaset (hsubtype X)))
   '(lam X (impred_isaset X (lam x hProp) (lam x isasethProp))))
 (defq 'isasetsetquot '(pi X UU (pi R (hrel X) (isaset (setquot X R))))
   '(lam X (lam R (lam c1
      (uu-pathscollapse (setquot X R) c1
        (lam c2 (paths (hsubtype X) (pr1 c1) (pr1 c2)))
        (lam c2 (lam e (maponpaths (setquot X R) (hsubtype X) (lam z (pr1 z)) c1 c2 e)))
        (lam c2 (lam q (total2_paths_f (hsubtype X) (lam A (iseqclass X R A)) c1 c2 q
                  (pr1 ((isapropiseqclass X R (pr1 c2))
                         (transportf (hsubtype X) (lam A (iseqclass X R A))
                           (pr1 c1) (pr1 c2) q (pr2 c1))
                         (pr2 c2))))))
        (lam c2 (isasethsubtype X (pr1 c1) (pr1 c2))))))))
 (defn 'hPropset 'hSet '(tpair hProp isasethProp))
 (defn 'setquotinset '(pi X UU (pi R (hrel X) hSet))
   '(lam X (lam R (tpair (setquot X R) (isasetsetquot X R))))))

; NATURALNUMBERS (the parity lane): the additive monoid laws. natplusl0 is
; one idpath (add computes on the left); the rest are nat_rect + maponpaths
; succ, with natplusnsm's right side computing to meet the induction.
(assert
 (defq 'natplusl0 '(pi n nat (paths nat (add 0 n) n))
   '(lam n (idpath n)))
 (defq 'natplusnsm
   '(pi n nat (pi m nat (paths nat (add n (succ m)) (add (succ n) m))))
   '(lam n (lam m
      (nat_rect (lam q (paths nat (add q (succ m)) (add (succ q) m)))
        (idpath (succ m))
        (lam k (lam IH (maponpaths nat nat (lam w (succ w))
                 (add k (succ m)) (add (succ k) m) IH)))
        n))))
 (defq 'natpluscomm
   '(pi n nat (pi m nat (paths nat (add n m) (add m n))))
   '(lam n (lam m
      (nat_rect (lam q (paths nat (add q m) (add m q)))
        (pathsinv0 nat (add m 0) m (natplusr0 m))
        (lam k (lam IH
          (pathscomp0 nat (add (succ k) m) (add (succ m) k) (add m (succ k))
            (maponpaths nat nat (lam w (succ w)) (add k m) (add m k) IH)
            (pathsinv0 nat (add m (succ k)) (add (succ m) k) (natplusnsm m k)))))
        n))))
 (defq 'natplusassoc
   '(pi n nat (pi m nat (pi k nat (paths nat (add (add n m) k) (add n (add m k))))))
   '(lam n (lam m (lam k
      (nat_rect (lam q (paths nat (add (add q m) k) (add q (add m k))))
        (idpath (add m k))
        (lam j (lam IH (maponpaths nat nat (lam w (succ w))
                 (add (add j m) k) (add j (add m k)) IH)))
        n)))))
 (defn 'mul '(pi n nat (pi m nat nat))
   '(lam n (lam m (nat_rect (lam q nat) 0 (lam p (lam pm (add pm m))) n))))
 (defq 'natmult0n '(pi n nat (paths nat (mul 0 n) 0))
   '(lam n (idpath 0)))
 (defq 'natmultn0 '(pi n nat (paths nat (mul n 0) 0))
   '(lam n
      (nat_rect (lam q (paths nat (mul q 0) 0))
        (idpath 0)
        (lam p (lam IH
          (pathscomp0 nat (add (mul p 0) 0) (mul p 0) 0
            (natplusr0 (mul p 0)) IH)))
        n)))
 (defq 'hinhfun
   '(pi X UU (pi Y UU (pi f (pi x X Y) (pi w (ishinh_UU X) (ishinh_UU Y)))))
   '(lam X (lam Y (lam f (lam w (lam P (lam g (w P (lam x (g (f x)))))))))))
 (defq 'hinhand
   '(pi X UU (pi Y UU (pi w1 (ishinh_UU X) (pi w2 (ishinh_UU Y)
      (ishinh_UU (total2 q X Y))))))
   '(lam X (lam Y (lam w1 (lam w2
      (lam P (lam g (w1 P (lam x (w2 P (lam y (g (tpair x y))))))))))))))

; --- the kernel refuses: ill-typed terms scare; the help cell catches them.
; --- (install per the help law -- more/eof keep the read protocol.)
(: (help s p e) (? (more? s) p (eof? s) e
                   (: h (peep HELPC () 0) (? h (h s p e) 0))))
(assert
 (idp 'rejected (rejects (\ z (defn 'uu-bad1 '(paths nat 1 2) '(idpath 1)))))
 (idp 'rejected (rejects (\ z (defn 'uu-bad2 '(pi x nat nat) '(lam x (succ y))))))
 (idp 'rejected (rejects (\ z (defn 'uu-bad3 'nat '(lam x x)))))
 (idp 'rejected (rejects (\ z (defn 'uu-bad4 '(coprod nat bool) '(ii1 true)))))
 (idp 'rejected (rejects (\ z (defn 'uu-bad5 'nat '(let x (lam y y) x)))))
 (idp 'accepted (rejects (\ z (defn 'uu-good '(paths nat 2 2) '(idpath 2))))))
(: help 0)
