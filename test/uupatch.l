; test/uupatch.l -- the PATCH GROUPOID's named-slot AND positional slices as uu
; proof TERMS: the generated leg of the patch arc. test/patch.l's first two
; forms state the laws as executable asserts; proof/rocq/patch.v hand-proved
; them as scaffolding and PROMISED this file (its provenance note): the laws
; re-proven inside uu's own kernel, then emitted to Rocq AND Lean by
; tools/uu2coq.l + tools/uu2lean.l -- two independent kernels re-certifying the
; same terms, the de Bruijn criterion the rest of the proof corpus already
; rides. Substrate: test/uu.l + test/uulay.l's list vocabulary (this file
; loads after both by sort order).
;
; the model mirrors the .l's first form name for name: a tree is a total map
; (key -> value, nats -- the .v's closure of "a missing slot reads 0"), a patch
; (chg k a b) one slot-change carrying its context, commute the partial swap.
; where patch.v case-split on Nat.eqb with tactics, the terms here case on
; isdeceqnat -- decidable equality as a COPROD, so every branch carries the
; path evidence a bool would have dropped; refusal is the unit summand. all
; equality of trees is pointwise (no funext anywhere), exactly the .v's rule.

; --- the model: patch, tree, apply, validity, inverse, commute ---
(assert
 (defn 'patch 'UU '(total2 k nat (total2 a nat nat)))
 (defn 'chg '(pi k nat (pi a nat (pi b nat patch)))
   '(lam k (lam a (lam b (tpair k (tpair a b))))))
 (defn 'pk '(pi p patch nat) '(lam p (pr1 p)))
 (defn 'pa '(pi p patch nat) '(lam p (pr1 (pr2 p))))
 (defn 'pb '(pi p patch nat) '(lam p (pr2 (pr2 p))))
 (defn 'tree 'UU '(pi k nat nat))
 (defn 'apon '(pi t tree (pi p patch tree))
   '(lam t (lam p (lam q (coprod_rect (lam c nat)
                           (lam e (pb p))
                           (lam ne (t q))
                           (isdeceqnat q (pk p)))))))
 (defn 'valid '(pi t tree (pi p patch bool))
   '(lam t (lam p (coprod_rect (lam c bool)
                    (lam e true)
                    (lam ne false)
                    (isdeceqnat (t (pk p)) (pa p))))))
 (defn 'invert '(pi p patch patch)
   '(lam p (chg (pk p) (pb p) (pa p))))
 (defn 'ppair 'UU '(total2 x patch patch))
 (defn 'commute '(pi p patch (pi q patch (coprod ppair unit)))
   '(lam p (lam q (coprod_rect (lam c (coprod ppair unit))
                    (lam e (ii2 tt))
                    (lam ne (ii1 (tpair q p)))
                    (isdeceqnat (pk p) (pk q))))))
 ; the model COMPUTES: apply writes its slot and only its slot; invert is its
 ; own inverse; independent keys swap, a shared key refuses
 (9 = (vof 0 '(apon (lam k 7) (chg 3 7 9) 3)))
 (7 = (vof 0 '(apon (lam k 7) (chg 3 7 9) 5)))
 ((vof 0 '(chg 3 7 9)) = (vof 0 '(invert (invert (chg 3 7 9)))))
 (id? (vof 0 'true)  (vof 0 '(valid (lam k 5) (chg 3 5 9))))
 (id? (vof 0 'false) (vof 0 '(valid (lam k 5) (chg 3 4 9))))
 ((vof 0 '(commute (chg 3 0 1) (chg 5 0 2)))
  = (vof 0 '(ii1 (tpair (chg 5 0 2) (chg 3 0 1)))))
 ((vof 0 '(commute (chg 3 0 1) (chg 3 1 2))) = (vof 0 '(ii2 tt))))

; --- (L1) commute is INVOLUTIVE. cmside is the coprod no-confusion family (a
; --- recorded refusal is never a success); the ii1 lane rides maponpaths of
; --- "re-commute the carried pair", so the involution IS the algebra: commute
; --- q p computes straight to ii1 (p,q) once the keys are known distinct ---
(assert
 (defn 'cmside '(pi c (coprod ppair unit) UU)
   '(lam c (coprod_rect (lam x UU) (lam x empty) (lam x unit) c)))
 (defq 'commute-involutive
   '(pi p patch (pi q patch (pi q2 patch (pi p2 patch
      (pi h (paths (coprod ppair unit) (commute p q) (ii1 (tpair q2 p2)))
        (paths (coprod ppair unit) (commute q2 p2) (ii1 (tpair p q))))))))
   '(lam p (lam q (lam q2 (lam p2
      ((coprod_rect
         (lam c (pi h (paths (coprod ppair unit)
                        (coprod_rect (lam c2 (coprod ppair unit))
                          (lam e2 (ii2 tt))
                          (lam ne2 (ii1 (tpair q p)))
                          c)
                        (ii1 (tpair q2 p2)))
                  (paths (coprod ppair unit) (commute q2 p2) (ii1 (tpair p q)))))
         (lam e (lam h (fromempty
            (paths (coprod ppair unit) (commute q2 p2) (ii1 (tpair p q)))
            (transportf (coprod ppair unit) cmside (ii2 tt) (ii1 (tpair q2 p2)) h tt))))
         (lam ne (lam h
            (pathscomp0 (coprod ppair unit)
              (commute q2 p2) (commute q p) (ii1 (tpair p q))
              (pathsinv0 (coprod ppair unit) (commute q p) (commute q2 p2)
                (maponpaths (coprod ppair unit) (coprod ppair unit)
                  (lam c (coprod_rect (lam x (coprod ppair unit))
                           (lam z (commute (pr1 z) (pr2 z)))
                           (lam u (ii2 tt))
                           c))
                  (ii1 (tpair q p)) (ii1 (tpair q2 p2)) h))
              ((coprod_rect
                 (lam c (paths (coprod ppair unit)
                          (coprod_rect (lam c2 (coprod ppair unit))
                            (lam e2 (ii2 tt))
                            (lam ne2 (ii1 (tpair p q)))
                            c)
                          (ii1 (tpair p q))))
                 (lam e2 (fromempty
                    (paths (coprod ppair unit) (ii2 tt) (ii1 (tpair p q)))
                    (ne (pathsinv0 nat (pk q) (pk p) e2))))
                 ; the ascriptions pin tpair's implicit family and the reduced
                 ; refl type: Lean's elaborator won't iota-reduce the stuck rec
                 ; in the expected type while a metavariable is live (the
                 ; based-J seam, uu2lean's note); Rocq needed nothing
                 (lam ne2 (the (paths (coprod ppair unit)
                                 (ii1 (tpair p q)) (ii1 (tpair p q)))
                               (idpath (ii1 (the ppair (tpair p q))))))
                 (isdeceqnat (pk q) (pk p)))))))
         (isdeceqnat (pk p) (pk q))))))))))

; --- (L2) the INVERSE round-trips IN CONTEXT: where the patch is valid, apply
; --- then unpull restores every slot -- pointwise, quantifying the key like
; --- the .v does; validity opened by ONE convoy on its own decision, the main
; --- case abstracting BOTH apon layers' shared scrutinee at once ---
(assert
 (defq 'invert-roundtrip
   '(pi t tree (pi p patch (pi hv (paths bool (valid t p) true)
      (pi q nat (paths nat (apon (apon t p) (invert p) q) (t q))))))
   '(lam t (lam p
      ((coprod_rect
         (lam c (pi hv (paths bool
                         (coprod_rect (lam c2 bool) (lam e2 true) (lam ne2 false) c)
                         true)
                  (pi q nat (paths nat (apon (apon t p) (invert p) q) (t q)))))
         (lam e (lam hv (lam q
           ((coprod_rect
              (lam c (paths nat
                       (coprod_rect (lam c2 nat)
                         (lam e2 (pa p))
                         (lam ne2 (coprod_rect (lam c3 nat)
                                    (lam e3 (pb p))
                                    (lam ne3 (t q))
                                    c))
                         c)
                       (t q)))
              (lam e1 (pathscomp0 nat (pa p) (t (pk p)) (t q)
                        (pathsinv0 nat (t (pk p)) (pa p) e)
                        (maponpaths nat nat t (pk p) q (pathsinv0 nat q (pk p) e1))))
              (lam ne1 (idpath (t q)))
              (isdeceqnat q (pk p)))))))
         (lam ne (lam hv (fromempty
            (pi q nat (paths nat (apon (apon t p) (invert p) q) (t q)))
            (nopathsfalsetotrue hv))))
         (isdeceqnat (t (pk p)) (pa p)))))))
 ; and it computes: apply then unpull reads the old value back
 (7 = (vof 0 '(apon (apon (lam k 7) (chg 3 7 9)) (invert (chg 3 7 9)) 3))))

; --- (L3a) independent patches are ORDER-FREE (the semantic heart -- what makes
; --- merge and cherry-pick sound). apon-comm is the raw form off the key
; --- disequality; commute-sound ties it to the primitive: a successful commute
; --- WITNESSES order-freedom. the double convoy cases each decision once,
; --- abstracting all its occurrences on both sides ---
(assert
 (defq 'apon-comm
   '(pi p patch (pi q patch (pi ne (pi e (paths nat (pk p) (pk q)) empty)
      (pi t tree (pi r nat
        (paths nat (apon (apon t p) q r) (apon (apon t q) p r)))))))
   '(lam p (lam q (lam ne (lam t (lam r
      ((coprod_rect
         (lam c (paths nat
                  (coprod_rect (lam c2 nat)
                    (lam e2 (pb q))
                    (lam ne2 (coprod_rect (lam c3 nat)
                               (lam e3 (pb p))
                               (lam ne3 (t r))
                               (isdeceqnat r (pk p))))
                    c)
                  (coprod_rect (lam c2 nat)
                    (lam e2 (pb p))
                    (lam ne2 (coprod_rect (lam c3 nat)
                               (lam e3 (pb q))
                               (lam ne3 (t r))
                               c))
                    (isdeceqnat r (pk p)))))
         (lam e1
           ((coprod_rect
              (lam c (paths nat (pb q)
                       (coprod_rect (lam c2 nat)
                         (lam e2 (pb p))
                         (lam ne2 (pb q))
                         c)))
              (lam e2 (fromempty (paths nat (pb q) (pb p))
                        (ne (pathscomp0 nat (pk p) r (pk q)
                              (pathsinv0 nat r (pk p) e2)
                              e1))))
              (lam ne2 (idpath (pb q)))
              (isdeceqnat r (pk p)))))
         (lam ne1
           ((coprod_rect
              (lam c (paths nat
                       (coprod_rect (lam c2 nat) (lam e2 (pb p)) (lam ne2 (t r)) c)
                       (coprod_rect (lam c2 nat) (lam e2 (pb p)) (lam ne2 (t r)) c)))
              (lam e2 (idpath (pb p)))
              (lam ne2 (idpath (t r)))
              (isdeceqnat r (pk p)))))
         (isdeceqnat r (pk q))))))))))
 (defq 'commute-sound
   '(pi p patch (pi q patch
      (pi h (paths (coprod ppair unit) (commute p q) (ii1 (tpair q p)))
        (pi t tree (pi r nat
          (paths nat (apon (apon t p) q r) (apon (apon t q) p r)))))))
   '(lam p (lam q
      ((coprod_rect
         (lam c (pi h (paths (coprod ppair unit)
                        (coprod_rect (lam c2 (coprod ppair unit))
                          (lam e2 (ii2 tt))
                          (lam ne2 (ii1 (tpair q p)))
                          c)
                        (ii1 (tpair q p)))
                  (pi t tree (pi r nat
                    (paths nat (apon (apon t p) q r) (apon (apon t q) p r))))))
         (lam e (lam h (fromempty
            (pi t tree (pi r nat
              (paths nat (apon (apon t p) q r) (apon (apon t q) p r))))
            (transportf (coprod ppair unit) cmside (ii2 tt) (ii1 (tpair q p)) h tt))))
         (lam ne (lam h (apon-comm p q ne)))
         (isdeceqnat (pk p) (pk q)))))))
 ; both pull orders land the same tree, at the touched keys and elsewhere
 (1 = (vof 0 '(apon (apon (lam k 0) (chg 3 0 1)) (chg 5 0 2) 3)))
 (1 = (vof 0 '(apon (apon (lam k 0) (chg 5 0 2)) (chg 3 0 1) 3)))
 (2 = (vof 0 '(apon (apon (lam k 0) (chg 3 0 1)) (chg 5 0 2) 5)))
 (2 = (vof 0 '(apon (apon (lam k 0) (chg 5 0 2)) (chg 3 0 1) 5))))

; --- (L3b) a FRONTIER is stable under an adjacent swap of independent patches.
; --- patch lists are UniMath-style vectors at patch (a plist's length is pr1,
; --- like nlist); applall is the .l's left fold. the lift is two congruence
; --- lemmas (one apon, then the whole fold -- patch.v's apon_ext /
; --- fold_apon_ext) and one induction down the prefix; the swap at the head is
; --- exactly apon-comm under the fold. meaning is order-free, so the
; --- (unordered) patch set is a sound version identity -- the reproducibility
; --- tie, now machine-checked in three kernels ---
(assert
 (defn 'pvec '(pi n nat UU)
   '(lam n (nat_rect (lam q UU) unit (lam k (lam r (total2 h patch r))) n)))
 (defn 'plist 'UU '(total2 n nat (pvec n)))
 (defn 'pnil 'plist '(tpair 0 tt))
 (defn 'pcons '(pi x patch (pi l plist plist))
   '(lam x (lam l (tpair (succ (pr1 l)) (tpair x (pr2 l))))))
 (defn 'papp '(pi a plist (pi b plist plist))
   '(lam a (lam b ((nat_rect (lam q (pi v (pvec q) plist))
                     (lam v b)
                     (lam k (lam IH (lam v (pcons (pr1 v) (IH (pr2 v))))))
                     (pr1 a))
                   (pr2 a)))))
 (defn 'applall '(pi l plist (pi t tree tree))
   '(lam l (lam t ((nat_rect (lam q (pi v (pvec q) (pi t2 tree tree)))
                     (lam v (lam t2 t2))
                     (lam k (lam IH (lam v (lam t2 (IH (pr2 v) (apon t2 (pr1 v)))))))
                     (pr1 l))
                   (pr2 l) t))))
 (defq 'apon-ext
   '(pi t1 tree (pi t2 tree (pi p patch
      (pi hp (pi k nat (paths nat (t1 k) (t2 k)))
        (pi r nat (paths nat (apon t1 p r) (apon t2 p r)))))))
   '(lam t1 (lam t2 (lam p (lam hp (lam r
      ((coprod_rect
         (lam c (paths nat
                  (coprod_rect (lam c2 nat) (lam e2 (pb p)) (lam ne2 (t1 r)) c)
                  (coprod_rect (lam c2 nat) (lam e2 (pb p)) (lam ne2 (t2 r)) c)))
         (lam e (idpath (pb p)))
         (lam ne (hp r))
         (isdeceqnat r (pk p))))))))))
 (defq 'applall-ext
   '(pi l plist (pi t1 tree (pi t2 tree
      (pi hp (pi k nat (paths nat (t1 k) (t2 k)))
        (pi r nat (paths nat (applall l t1 r) (applall l t2 r)))))))
   '(lam l ((nat_rect
       (lam q (pi v (pvec q) (pi t1 tree (pi t2 tree
                (pi hp (pi k nat (paths nat (t1 k) (t2 k)))
                  (pi r nat (paths nat (applall (tpair q v) t1 r)
                                       (applall (tpair q v) t2 r))))))))
       (lam v (lam t1 (lam t2 (lam hp (lam r (hp r))))))
       (lam k (lam IH (lam v (lam t1 (lam t2 (lam hp
         (IH (pr2 v) (apon t1 (pr1 v)) (apon t2 (pr1 v))
             (apon-ext t1 t2 (pr1 v) hp))))))))
       (pr1 l))
     (pr2 l))))
 (defq 'applall-swap
   '(pi p patch (pi q patch (pi ne (pi e (paths nat (pk p) (pk q)) empty)
      (pi pre plist (pi post plist (pi t tree (pi r nat
        (paths nat
          (applall (papp pre (pcons p (pcons q post))) t r)
          (applall (papp pre (pcons q (pcons p post))) t r)))))))))
   '(lam p (lam q (lam ne (lam pre (lam post
      ((nat_rect
         (lam n (pi v (pvec n) (pi t tree (pi r nat
           (paths nat
             (applall (papp (tpair n v) (pcons p (pcons q post))) t r)
             (applall (papp (tpair n v) (pcons q (pcons p post))) t r))))))
         (lam v (lam t (applall-ext post
                  (apon (apon t p) q)
                  (apon (apon t q) p)
                  (apon-comm p q ne t))))
         (lam k (lam IH (lam v (lam t
           (IH (pr2 v) (apon t (pr1 v)))))))
         (pr1 pre))
       (pr2 pre))))))))
 ; the fold COMPUTES, and the frontier agrees either order
 (2 = (vof 0 '(applall (pcons (chg 3 0 1) (pcons (chg 5 0 2) pnil)) (lam k 0) 5)))
 ((vof 0 '(applall (pcons (chg 3 0 1) (pcons (chg 5 0 2) pnil)) (lam k 0) 3))
  = (vof 0 '(applall (pcons (chg 5 0 2) (pcons (chg 3 0 1) pnil)) (lam k 0) 3))))

; ============================================================================
; the POSITIONAL slice: hunks over a SEQUENCE, where commute genuinely
; RE-AIMS -- test/patch.l second form, patch.v hunk slice, migrated. the
; kit: plus-cancellation as bool/nat EQUATIONS (succ-succ steps are
; definitional), the take/drop/append fusion laws, then the model and the
; four laws, each intermediate SEALED as its own defq (a path-valued let
; poisons every later check in its scope -- the eager-NbE let law).
; ============================================================================
; --- the POSITIONAL slice needs an index algebra (plus-cancellation through
; --- the order and the truncated minus) and a take/drop/append fusion kit.
; --- every succ-succ step of natgtb and natminus is DEFINITIONAL, so the
; --- cancellation laws are one induction each, steps landing on their IH ---
(assert
 (defq 'natlehnplusnm
   '(pi a nat (pi b nat (paths bool (natgtb a (add a b)) false)))
   '(lam a (lam b (nat_rect (lam q (paths bool (natgtb q (add q b)) false))
      (idpath false)
      (lam k (lam IH IH))
      a))))
 (defq 'natlehmplusnm
   '(pi a nat (pi b nat (paths bool (natgtb a (add b a)) false)))
   '(lam a (lam b (nat_rect (lam q (paths bool (natgtb a (add q a)) false))
      (isreflnatleh a)
      (lam k (lam IH (natlehsucc a (add k a) IH)))
      b))))
 (defq 'natgtbplusl
   '(pi c nat (pi a nat (pi b nat (paths bool (natgtb (add c a) (add c b)) (natgtb a b)))))
   '(lam c (lam a (lam b (nat_rect (lam q (paths bool (natgtb (add q a) (add q b)) (natgtb a b)))
      (idpath (natgtb a b))
      (lam k (lam IH IH))
      c)))))
 (defq 'natgtbplusr
   '(pi a nat (pi b nat (pi c nat (paths bool (natgtb (add a c) (add b c)) (natgtb a b)))))
   '(lam a (lam b (lam c
      (pathscomp0 bool (natgtb (add a c) (add b c)) (natgtb (add c a) (add c b)) (natgtb a b)
        (pathscomp0 bool (natgtb (add a c) (add b c)) (natgtb (add c a) (add b c)) (natgtb (add c a) (add c b))
          (maponpaths nat bool (lam w (natgtb w (add b c))) (add a c) (add c a) (natpluscomm a c))
          (maponpaths nat bool (lam w (natgtb (add c a) w)) (add b c) (add c b) (natpluscomm b c)))
        (natgtbplusl c a b))))))
 (defq 'natpluscancelminus
   '(pi a nat (pi b nat (paths nat (natminus (add a b) b) a)))
   '(lam a (lam b (nat_rect (lam q (paths nat (natminus (add a q) q) a))
      (pathscomp0 nat (natminus (add a 0) 0) (add a 0) a (natminusn0 (add a 0)) (natplusr0 a))
      (lam k (lam IH
        (pathscomp0 nat (natminus (add a (succ k)) (succ k)) (natminus (add (succ a) k) (succ k)) a
          (maponpaths nat nat (lam w (natminus w (succ k))) (add a (succ k)) (add (succ a) k) (natplusnsm a k))
          IH)))
      b))))
 (defq 'natpluslcancelminus
   '(pi c nat (pi x nat (paths nat (natminus (add c x) c) x)))
   '(lam c (lam x
      (pathscomp0 nat (natminus (add c x) c) (natminus (add x c) c) x
        (maponpaths nat nat (lam w (natminus w c)) (add c x) (add x c) (natpluscomm c x))
        (natpluscancelminus x c)))))
 (defq 'natplusswap
   '(pi a nat (pi b nat (pi c nat (paths nat (add (add a b) c) (add (add a c) b)))))
   '(lam a (lam b (lam c
      (pathscomp0 nat (add (add a b) c) (add a (add b c)) (add (add a c) b)
        (natplusassoc a b c)
        (pathscomp0 nat (add a (add b c)) (add a (add c b)) (add (add a c) b)
          (maponpaths nat nat (lam w (add a w)) (add b c) (add c b) (natpluscomm b c))
          (pathsinv0 nat (add (add a c) b) (add a (add c b)) (natplusassoc a c b))))))))
 ; the computed face
 (id? (vof 0 'false) (vof 0 '(natgtb 4 (add 4 3))))
 (id? (vof 0 '5) (vof 0 '(natminus (add 5 3) 3))))

; --- the list kit: how take, drop and append fuse. all at nlist, uulay.l's
; --- vocabulary (ltake/ldrop/lapp/lapptakedrop/ldroplen/lnil0 load before
; --- this file by sort order); every induction walks the vector like uulay's ---
(assert
 (defq 'ldropnil
   '(pi k nat (paths nlist (ldrop k nnil) nnil))
   '(lam k (nat_rect (lam q (paths nlist (ldrop q nnil) nnil))
      (idpath nnil)
      (lam j (lam IH (idpath nnil)))
      k)))
 (defq 'lapplen
   '(pi a nlist (pi b nlist (paths nat (nlen (lapp a b)) (add (nlen a) (nlen b)))))
   '(lam a (lam b ((nat_rect
      (lam q (pi v (nvec q) (paths nat (nlen (lapp (tpair q v) b)) (add q (nlen b)))))
      (lam v (idpath (nlen b)))
      (lam k (lam IH (lam v
        (maponpaths nat nat (lam w (succ w))
          (nlen (lapp (tpair k (pr2 v)) b)) (add k (nlen b)) (IH (pr2 v))))))
      (pr1 a))
     (pr2 a)))))
 (defq 'lappassoc
   '(pi a nlist (pi b nlist (pi c nlist (paths nlist (lapp (lapp a b) c) (lapp a (lapp b c))))))
   '(lam a (lam b (lam c ((nat_rect
      (lam q (pi v (nvec q) (paths nlist (lapp (lapp (tpair q v) b) c) (lapp (tpair q v) (lapp b c)))))
      (lam v (idpath (lapp b c)))
      (lam k (lam IH (lam v
        (maponpaths nlist nlist (lam t (ncons (pr1 v) t))
          (lapp (lapp (tpair k (pr2 v)) b) c) (lapp (tpair k (pr2 v)) (lapp b c)) (IH (pr2 v))))))
      (pr1 a))
     (pr2 a))))))
 (defq 'ltakelenapp
   '(pi a nlist (pi b nlist (paths nlist (ltake (nlen a) (lapp a b)) a)))
   '(lam a (lam b ((nat_rect
      (lam q (pi v (nvec q) (paths nlist (ltake q (lapp (tpair q v) b)) (tpair q v))))
      (lam v (pathsinv0 nlist (tpair 0 v) nnil (lnil0 v)))
      (lam k (lam IH (lam v
        (maponpaths nlist nlist (lam t (ncons (pr1 v) t))
          (ltake k (lapp (tpair k (pr2 v)) b)) (tpair k (pr2 v)) (IH (pr2 v))))))
      (pr1 a))
     (pr2 a)))))
 (defq 'ldroplenapp
   '(pi a nlist (pi b nlist (paths nlist (ldrop (nlen a) (lapp a b)) b)))
   '(lam a (lam b ((nat_rect
      (lam q (pi v (nvec q) (paths nlist (ldrop q (lapp (tpair q v) b)) b)))
      (lam v (idpath b))
      (lam k (lam IH (lam v (IH (pr2 v)))))
      (pr1 a))
     (pr2 a)))))
 (defq 'ldropplusapp
   '(pi a nlist (pi m nat (pi b nlist (paths nlist (ldrop (add (nlen a) m) (lapp a b)) (ldrop m b)))))
   '(lam a (lam m (lam b ((nat_rect
      (lam q (pi v (nvec q) (paths nlist (ldrop (add q m) (lapp (tpair q v) b)) (ldrop m b))))
      (lam v (idpath (ldrop m b)))
      (lam k (lam IH (lam v (IH (pr2 v)))))
      (pr1 a))
     (pr2 a))))))
 (defq 'ltakeplusapp
   '(pi a nlist (pi m nat (pi b nlist (paths nlist (ltake (add (nlen a) m) (lapp a b)) (lapp a (ltake m b))))))
   '(lam a (lam m (lam b ((nat_rect
      (lam q (pi v (nvec q) (paths nlist (ltake (add q m) (lapp (tpair q v) b)) (lapp (tpair q v) (ltake m b)))))
      (lam v (idpath (ltake m b)))
      (lam k (lam IH (lam v
        (maponpaths nlist nlist (lam t (ncons (pr1 v) t))
          (ltake (add k m) (lapp (tpair k (pr2 v)) b)) (lapp (tpair k (pr2 v)) (ltake m b)) (IH (pr2 v))))))
      (pr1 a))
     (pr2 a))))))
 (defq 'ltakeprefix
   '(pi j nat (pi a nlist (pi b nlist (pi h (paths bool (natgtb j (nlen a)) false)
      (paths nlist (ltake j (lapp a b)) (ltake j a))))))
   '(lam j ((nat_rect
      (lam q (pi a nlist (pi b nlist (pi h (paths bool (natgtb q (nlen a)) false)
               (paths nlist (ltake q (lapp a b)) (ltake q a))))))
      (lam a (lam b (lam h (idpath nnil))))
      (lam j2 (lam IH
        (lam a (lam b ((nat_rect
           (lam r (pi v (nvec r) (pi h (paths bool (natgtb (succ j2) r) false)
                    (paths nlist (ltake (succ j2) (lapp (tpair r v) b)) (ltake (succ j2) (tpair r v))))))
           (lam v (lam h (fromempty
              (paths nlist (ltake (succ j2) (lapp (tpair 0 v) b)) (ltake (succ j2) (tpair 0 v)))
              (nopathstruetofalse h))))
           (lam k (lam u (lam v (lam h
              (maponpaths nlist nlist (lam t (ncons (pr1 v) t))
                (ltake j2 (lapp (tpair k (pr2 v)) b)) (ltake j2 (tpair k (pr2 v)))
                (IH (tpair k (pr2 v)) b h))))))
           (pr1 a))
          (pr2 a))))))
      j))))
 (defq 'ldropprefix
   '(pi j nat (pi a nlist (pi b nlist (pi h (paths bool (natgtb j (nlen a)) false)
      (paths nlist (ldrop j (lapp a b)) (lapp (ldrop j a) b))))))
   '(lam j ((nat_rect
      (lam q (pi a nlist (pi b nlist (pi h (paths bool (natgtb q (nlen a)) false)
               (paths nlist (ldrop q (lapp a b)) (lapp (ldrop q a) b))))))
      (lam a (lam b (lam h (idpath (lapp a b)))))
      (lam j2 (lam IH
        (lam a (lam b ((nat_rect
           (lam r (pi v (nvec r) (pi h (paths bool (natgtb (succ j2) r) false)
                    (paths nlist (ldrop (succ j2) (lapp (tpair r v) b)) (lapp (ldrop (succ j2) (tpair r v)) b)))))
           (lam v (lam h (fromempty
              (paths nlist (ldrop (succ j2) (lapp (tpair 0 v) b)) (lapp (ldrop (succ j2) (tpair 0 v)) b))
              (nopathstruetofalse h))))
           (lam k (lam u (lam v (lam h
              (IH (tpair k (pr2 v)) b h)))))
           (pr1 a))
          (pr2 a))))))
      j))))
 (defq 'ldropdrop
   '(pi i nat (pi c nat (pi s nlist (paths nlist (ldrop c (ldrop i s)) (ldrop (add i c) s)))))
   '(lam i (lam c ((nat_rect
      (lam q (pi s nlist (paths nlist (ldrop c (ldrop q s)) (ldrop (add q c) s))))
      (lam s (idpath (ldrop c s)))
      (lam i2 (lam IH
        (lam s ((nat_rect
           (lam r (pi v (nvec r) (paths nlist (ldrop c (ldrop (succ i2) (tpair r v))) (ldrop (succ (add i2 c)) (tpair r v)))))
           (lam v (ldropnil c))
           (lam k (lam u (lam v (IH (tpair k (pr2 v))))))
           (pr1 s))
          (pr2 s)))))
      i)))))
 (defq 'ltakelen
   '(pi i nat (pi s nlist (pi h (paths bool (natgtb i (nlen s)) false)
      (paths nat (nlen (ltake i s)) i))))
   '(lam i ((nat_rect
      (lam q (pi s nlist (pi h (paths bool (natgtb q (nlen s)) false)
               (paths nat (nlen (ltake q s)) q))))
      (lam s (lam h (idpath 0)))
      (lam i2 (lam IH
        (lam s ((nat_rect
           (lam r (pi v (nvec r) (pi h (paths bool (natgtb (succ i2) r) false)
                    (paths nat (nlen (ltake (succ i2) (tpair r v))) (succ i2)))))
           (lam v (lam h (fromempty
              (paths nat (nlen (ltake (succ i2) (tpair 0 v))) (succ i2))
              (nopathstruetofalse h))))
           (lam k (lam u (lam v (lam h
              (maponpaths nat nat (lam w (succ w))
                (nlen (ltake i2 (tpair k (pr2 v)))) i2
                (IH (tpair k (pr2 v)) h))))))
           (pr1 s))
          (pr2 s)))))
      i))))
 ; the fused faces compute
 ((vof 0 '(ncons 7 (ncons 9 nnil)))
  = (vof 0 '(ltake (nlen (ncons 7 (ncons 9 nnil))) (lapp (ncons 7 (ncons 9 nnil)) (ncons 4 nnil)))))
 ((vof 0 '(ncons 4 nnil))
  = (vof 0 '(ldrop 2 (lapp (ncons 7 (ncons 9 nnil)) (ncons 4 nnil))))))

; --- the POSITIONAL model: a state is an nlist, a hunk (mkh i o n) aims o->n
; --- at index i; splice is take/append/drop, so hap's first layer is
; --- DEFINITIONAL over the seams. commute's tests ride natgthorleh -- the
; --- dichotomy carries the bool-path evidence into every branch, the same
; --- convoy the named-slot slice built on isdeceqnat. refusal (overlap OR
; --- touch: strict, the darcs seam) is the unit summand ---
(assert
 (defn 'hunk 'UU '(total2 i nat (total2 o nlist nlist)))
 (defn 'mkh '(pi i nat (pi o nlist (pi n nlist hunk)))
   '(lam i (lam o (lam n (tpair i (tpair o n))))))
 (defn 'hi '(pi p hunk nat) '(lam p (pr1 p)))
 (defn 'ho '(pi p hunk nlist) '(lam p (pr1 (pr2 p))))
 (defn 'hn '(pi p hunk nlist) '(lam p (pr2 (pr2 p))))
 (defn 'splice '(pi s nlist (pi i nat (pi c nat (pi n nlist nlist))))
   '(lam s (lam i (lam c (lam n (lapp (ltake i s) (lapp n (ldrop (add i c) s))))))))
 (defn 'hap '(pi s nlist (pi p hunk nlist))
   '(lam s (lam p (splice s (hi p) (nlen (ho p)) (hn p)))))
 (defn 'hinv '(pi p hunk hunk)
   '(lam p (mkh (hi p) (hn p) (ho p))))
 (defn 'hpair 'UU '(total2 x hunk hunk))
 (defn 'hcommute '(pi p hunk (pi q hunk (coprod hpair unit)))
   '(lam p (lam q
      (coprod_rect (lam c (coprod hpair unit))
        (lam g (ii1 (tpair (mkh (natminus (add (hi q) (nlen (ho p))) (nlen (hn p))) (ho q) (hn q)) p)))
        (lam g (coprod_rect (lam c2 (coprod hpair unit))
                 (lam g2 (ii1 (tpair q (mkh (natminus (add (hi p) (nlen (hn q))) (nlen (ho q))) (ho p) (hn p)))))
                 (lam g2 (ii2 tt))
                 (natgthorleh (hi p) (add (hi q) (nlen (ho q))))))
        (natgthorleh (hi q) (add (hi p) (nlen (hn p))))))))
 ; the model COMPUTES: splice replaces the middle, hap lays a hunk, commute
 ; re-aims past unequal lengths and refuses a touching seam
 ((vof 0 '(ncons 1 (ncons 7 (ncons 8 (ncons 3 nnil)))))
  = (vof 0 '(splice (ncons 1 (ncons 2 (ncons 3 nnil))) 1 1 (ncons 7 (ncons 8 nnil)))))
 ((vof 0 '(ncons 7 (ncons 8 (ncons 2 (ncons 3 nnil)))))
  = (vof 0 '(hap (ncons 1 (ncons 2 (ncons 3 nnil))) (mkh 0 (ncons 1 nnil) (ncons 7 (ncons 8 nnil))))))
 ((vof 0 '(hcommute (mkh 0 (ncons 1 nnil) (ncons 7 (ncons 8 nnil))) (mkh 3 (ncons 4 nnil) nnil)))
  = (vof 0 '(ii1 (tpair (mkh 2 (ncons 4 nnil) nnil) (mkh 0 (ncons 1 nnil) (ncons 7 (ncons 8 nnil)))))))
 ((vof 0 '(hcommute (mkh 0 (ncons 1 nnil) (ncons 7 (ncons 8 nnil))) (mkh 2 (ncons 3 nnil) nnil)))
  = (vof 0 '(ii2 tt))))

; --- (L1) hcommute is INVOLUTIVE, with the genuine index re-aim: the slid
; --- index slides home. the carried pair rides the same maponpaths trick as
; --- the named-slot slice; the arithmetic is the natgtbplusr cancellation
; --- through natminusplusnmm's recomposition, once per branch ---
(assert
 (defn 'hcmside '(pi c (coprod hpair unit) UU)
   '(lam c (coprod_rect (lam x UU) (lam x empty) (lam x unit) c)))
 (defq 'hcommute-involutive
   '(pi p hunk (pi q hunk (pi q2 hunk (pi p2 hunk
      (pi h (paths (coprod hpair unit) (hcommute p q) (ii1 (tpair q2 p2)))
        (paths (coprod hpair unit) (hcommute q2 p2) (ii1 (tpair p q))))))))
   '(lam p (lam q (lam q2 (lam p2
      (coprod_rect
        (lam c (pi h (paths (coprod hpair unit)
                 (coprod_rect (lam cc (coprod hpair unit))
                   (lam g9 (ii1 (tpair (mkh (natminus (add (hi q) (nlen (ho p))) (nlen (hn p))) (ho q) (hn q)) p)))
                   (lam g9 (coprod_rect (lam cd (coprod hpair unit))
                            (lam g8 (ii1 (tpair q (mkh (natminus (add (hi p) (nlen (hn q))) (nlen (ho q))) (ho p) (hn p)))))
                            (lam g8 (ii2 tt))
                            (natgthorleh (hi p) (add (hi q) (nlen (ho q))))))
                   c)
                 (ii1 (tpair q2 p2)))
               (paths (coprod hpair unit) (hcommute q2 p2) (ii1 (tpair p q)))))
        (lam g (lam h
          (let j2 (natminus (add (hi q) (nlen (ho p))) (nlen (hn p)))
          (let rr (natminusplusnmm (add (hi q) (nlen (ho p))) (nlen (hn p))
                    (istransnatleh (nlen (hn p)) (add (hi p) (nlen (hn p))) (add (hi q) (nlen (ho p)))
                      (natlehmplusnm (nlen (hn p)) (hi p))
                      (istransnatleh (add (hi p) (nlen (hn p))) (hi q) (add (hi q) (nlen (ho p)))
                        (natlthtoleh (add (hi p) (nlen (hn p))) (hi q) g)
                        (natlehnplusnm (hi q) (nlen (ho p))))))
          (let bfact (pathscomp0 bool
                       (natgtb j2 (add (hi p) (nlen (ho p))))
                       (natgtb (add j2 (nlen (hn p))) (add (add (hi p) (nlen (ho p))) (nlen (hn p))))
                       true
                       (pathsinv0 bool
                         (natgtb (add j2 (nlen (hn p))) (add (add (hi p) (nlen (ho p))) (nlen (hn p))))
                         (natgtb j2 (add (hi p) (nlen (ho p))))
                         (natgtbplusr j2 (add (hi p) (nlen (ho p))) (nlen (hn p))))
                       (pathscomp0 bool
                         (natgtb (add j2 (nlen (hn p))) (add (add (hi p) (nlen (ho p))) (nlen (hn p))))
                         (natgtb (add j2 (nlen (hn p))) (add (add (hi p) (nlen (hn p))) (nlen (ho p))))
                         true
                         (maponpaths nat bool (lam w (natgtb (add j2 (nlen (hn p))) w))
                           (add (add (hi p) (nlen (ho p))) (nlen (hn p))) (add (add (hi p) (nlen (hn p))) (nlen (ho p)))
                           (natplusswap (hi p) (nlen (ho p)) (nlen (hn p))))
                         (pathscomp0 bool
                           (natgtb (add j2 (nlen (hn p))) (add (add (hi p) (nlen (hn p))) (nlen (ho p))))
                           (natgtb (add (hi q) (nlen (ho p))) (add (add (hi p) (nlen (hn p))) (nlen (ho p))))
                           true
                           (maponpaths nat bool (lam w (natgtb w (add (add (hi p) (nlen (hn p))) (nlen (ho p)))))
                             (add j2 (nlen (hn p))) (add (hi q) (nlen (ho p))) rr)
                           (pathscomp0 bool
                             (natgtb (add (hi q) (nlen (ho p))) (add (add (hi p) (nlen (hn p))) (nlen (ho p))))
                             (natgtb (hi q) (add (hi p) (nlen (hn p))))
                             true
                             (natgtbplusr (hi q) (add (hi p) (nlen (hn p))) (nlen (ho p)))
                             g))))
          (let afact (istransnatleh (hi p) j2 (add j2 (nlen (hn q)))
                       (istransnatleh (hi p) (add (hi p) (nlen (ho p))) j2
                         (natlehnplusnm (hi p) (nlen (ho p)))
                         (natlthtoleh (add (hi p) (nlen (ho p))) j2 bfact))
                       (natlehnplusnm j2 (nlen (hn q))))
          (let cfact (pathscomp0 nat
                       (natminus (add j2 (nlen (hn p))) (nlen (ho p)))
                       (natminus (add (hi q) (nlen (ho p))) (nlen (ho p)))
                       (hi q)
                       (maponpaths nat nat (lam w (natminus w (nlen (ho p))))
                         (add j2 (nlen (hn p))) (add (hi q) (nlen (ho p))) rr)
                       (natpluscancelminus (hi q) (nlen (ho p))))
          (pathscomp0 (coprod hpair unit)
            (hcommute q2 p2)
            (hcommute (mkh j2 (ho q) (hn q)) p)
            (ii1 (tpair p q))
            (pathsinv0 (coprod hpair unit)
              (hcommute (mkh j2 (ho q) (hn q)) p)
              (hcommute q2 p2)
              (maponpaths (coprod hpair unit) (coprod hpair unit)
                (lam cz (coprod_rect (lam cy (coprod hpair unit)) (lam z (hcommute (pr1 z) (pr2 z))) (lam uz (ii2 tt)) cz))
                (ii1 (tpair (mkh j2 (ho q) (hn q)) p)) (ii1 (tpair q2 p2)) h))
            (coprod_rect
              (lam c3 (paths (coprod hpair unit)
                        (coprod_rect (lam cc (coprod hpair unit))
                          (lam g7 (ii1 (tpair (mkh (natminus (add (hi p) (nlen (ho q))) (nlen (hn q))) (ho p) (hn p)) (mkh j2 (ho q) (hn q)))))
                          (lam g7 (coprod_rect (lam c4 (coprod hpair unit))
                                   (lam g6 (ii1 (tpair p (mkh (natminus (add j2 (nlen (hn p))) (nlen (ho p))) (ho q) (hn q)))))
                                   (lam g6 (ii2 tt))
                                   (natgthorleh j2 (add (hi p) (nlen (ho p))))))
                          c3)
                        (ii1 (tpair p q))))
              (lam g7 (fromempty
                (paths (coprod hpair unit)
                  (ii1 (tpair (mkh (natminus (add (hi p) (nlen (ho q))) (nlen (hn q))) (ho p) (hn p)) (mkh j2 (ho q) (hn q))))
                  (ii1 (tpair p q)))
                (natlehtonegnatgth (hi p) (add j2 (nlen (hn q))) afact g7)))
              (lam g7
                (coprod_rect
                  (lam c4 (paths (coprod hpair unit)
                            (coprod_rect (lam cc (coprod hpair unit))
                              (lam g6 (ii1 (tpair p (mkh (natminus (add j2 (nlen (hn p))) (nlen (ho p))) (ho q) (hn q)))))
                              (lam g6 (ii2 tt))
                              c4)
                            (ii1 (tpair p q))))
                  (lam g6 (maponpaths nat (coprod hpair unit)
                            (lam w (ii1 (tpair p (mkh w (ho q) (hn q)))))
                            (natminus (add j2 (nlen (hn p))) (nlen (ho p))) (hi q) cfact))
                  (lam g6 (fromempty
                    (paths (coprod hpair unit) (ii2 tt) (ii1 (tpair p q)))
                    (natlehtonegnatgth j2 (add (hi p) (nlen (ho p))) g6 bfact)))
                  (natgthorleh j2 (add (hi p) (nlen (ho p))))))
              (natgthorleh (hi p) (add j2 (nlen (hn q)))))))))))))
        (lam g (lam h
          ((coprod_rect
             (lam c2 (pi h2 (paths (coprod hpair unit)
                       (coprod_rect (lam cc (coprod hpair unit))
                         (lam g8 (ii1 (tpair q (mkh (natminus (add (hi p) (nlen (hn q))) (nlen (ho q))) (ho p) (hn p)))))
                         (lam g8 (ii2 tt))
                         c2)
                       (ii1 (tpair q2 p2)))
                     (paths (coprod hpair unit) (hcommute q2 p2) (ii1 (tpair p q)))))
             (lam g2 (lam h2
               (let i2 (natminus (add (hi p) (nlen (hn q))) (nlen (ho q)))
               (let rr2 (natminusplusnmm (add (hi p) (nlen (hn q))) (nlen (ho q))
                          (istransnatleh (nlen (ho q)) (add (hi q) (nlen (ho q))) (add (hi p) (nlen (hn q)))
                            (natlehmplusnm (nlen (ho q)) (hi q))
                            (istransnatleh (add (hi q) (nlen (ho q))) (hi p) (add (hi p) (nlen (hn q)))
                              (natlthtoleh (add (hi q) (nlen (ho q))) (hi p) g2)
                              (natlehnplusnm (hi p) (nlen (hn q))))))
               (let b2fact (pathscomp0 bool
                             (natgtb i2 (add (hi q) (nlen (hn q))))
                             (natgtb (add i2 (nlen (ho q))) (add (add (hi q) (nlen (hn q))) (nlen (ho q))))
                             true
                             (pathsinv0 bool
                               (natgtb (add i2 (nlen (ho q))) (add (add (hi q) (nlen (hn q))) (nlen (ho q))))
                               (natgtb i2 (add (hi q) (nlen (hn q))))
                               (natgtbplusr i2 (add (hi q) (nlen (hn q))) (nlen (ho q))))
                             (pathscomp0 bool
                               (natgtb (add i2 (nlen (ho q))) (add (add (hi q) (nlen (hn q))) (nlen (ho q))))
                               (natgtb (add i2 (nlen (ho q))) (add (add (hi q) (nlen (ho q))) (nlen (hn q))))
                               true
                               (maponpaths nat bool (lam w (natgtb (add i2 (nlen (ho q))) w))
                                 (add (add (hi q) (nlen (hn q))) (nlen (ho q))) (add (add (hi q) (nlen (ho q))) (nlen (hn q)))
                                 (natplusswap (hi q) (nlen (hn q)) (nlen (ho q))))
                               (pathscomp0 bool
                                 (natgtb (add i2 (nlen (ho q))) (add (add (hi q) (nlen (ho q))) (nlen (hn q))))
                                 (natgtb (add (hi p) (nlen (hn q))) (add (add (hi q) (nlen (ho q))) (nlen (hn q))))
                                 true
                                 (maponpaths nat bool (lam w (natgtb w (add (add (hi q) (nlen (ho q))) (nlen (hn q)))))
                                   (add i2 (nlen (ho q))) (add (hi p) (nlen (hn q))) rr2)
                                 (pathscomp0 bool
                                   (natgtb (add (hi p) (nlen (hn q))) (add (add (hi q) (nlen (ho q))) (nlen (hn q))))
                                   (natgtb (hi p) (add (hi q) (nlen (ho q))))
                                   true
                                   (natgtbplusr (hi p) (add (hi q) (nlen (ho q))) (nlen (hn q)))
                                   g2))))
               (let c2fact (pathscomp0 nat
                             (natminus (add i2 (nlen (ho q))) (nlen (hn q)))
                             (natminus (add (hi p) (nlen (hn q))) (nlen (hn q)))
                             (hi p)
                             (maponpaths nat nat (lam w (natminus w (nlen (hn q))))
                               (add i2 (nlen (ho q))) (add (hi p) (nlen (hn q))) rr2)
                             (natpluscancelminus (hi p) (nlen (hn q))))
               (pathscomp0 (coprod hpair unit)
                 (hcommute q2 p2)
                 (hcommute q (mkh i2 (ho p) (hn p)))
                 (ii1 (tpair p q))
                 (pathsinv0 (coprod hpair unit)
                   (hcommute q (mkh i2 (ho p) (hn p)))
                   (hcommute q2 p2)
                   (maponpaths (coprod hpair unit) (coprod hpair unit)
                     (lam cz (coprod_rect (lam cy (coprod hpair unit)) (lam z (hcommute (pr1 z) (pr2 z))) (lam uz (ii2 tt)) cz))
                     (ii1 (tpair q (mkh i2 (ho p) (hn p)))) (ii1 (tpair q2 p2)) h2))
                 (coprod_rect
                   (lam c3 (paths (coprod hpair unit)
                             (coprod_rect (lam cc (coprod hpair unit))
                               (lam g7 (ii1 (tpair (mkh (natminus (add i2 (nlen (ho q))) (nlen (hn q))) (ho p) (hn p)) q)))
                               (lam g7 (coprod_rect (lam c4 (coprod hpair unit))
                                        (lam g6 (ii1 (tpair (mkh i2 (ho p) (hn p)) (mkh (natminus (add (hi q) (nlen (hn p))) (nlen (ho p))) (ho q) (hn q)))))
                                        (lam g6 (ii2 tt))
                                        (natgthorleh (hi q) (add i2 (nlen (ho p))))))
                               c3)
                             (ii1 (tpair p q))))
                   (lam g7 (maponpaths nat (coprod hpair unit)
                             (lam w (ii1 (tpair (mkh w (ho p) (hn p)) q)))
                             (natminus (add i2 (nlen (ho q))) (nlen (hn q))) (hi p) c2fact))
                   (lam g7 (fromempty
                     (paths (coprod hpair unit)
                       (coprod_rect (lam cc (coprod hpair unit))
                         (lam g6 (ii1 (tpair (mkh i2 (ho p) (hn p)) (mkh (natminus (add (hi q) (nlen (hn p))) (nlen (ho p))) (ho q) (hn q)))))
                         (lam g6 (ii2 tt))
                         (natgthorleh (hi q) (add i2 (nlen (ho p)))))
                       (ii1 (tpair p q)))
                     (natlehtonegnatgth i2 (add (hi q) (nlen (hn q))) g7 b2fact)))
                   (natgthorleh i2 (add (hi q) (nlen (hn q))))))))))))
             (lam g2 (lam h2 (fromempty
               (paths (coprod hpair unit) (hcommute q2 p2) (ii1 (tpair p q)))
               (transportf (coprod hpair unit) hcmside (ii2 tt) (ii1 (tpair q2 p2)) h2 tt))))
             (natgthorleh (hi p) (add (hi q) (nlen (ho q)))))
           h)))
        (natgthorleh (hi q) (add (hi p) (nlen (hn p)))))))))))

; --- (L2) the INVERSE round-trips IN CONTEXT: in range (the bound is what
; --- keeps an out-of-range insert honest -- its inverse would aim past the
; --- end) and matching, apply-then-unpull is the identity. splice is
; --- DEFINITIONALLY take/append/drop, so the whole proof is the seams
; --- decomposition s = A ++ o ++ W laid twice through the fusion kit ---
(assert
 (defq 'hinv-roundtrip
   '(pi s nlist (pi p hunk
      (pi hb (paths bool (natgtb (add (hi p) (nlen (ho p))) (nlen s)) false)
        (pi hc (paths nlist (ltake (nlen (ho p)) (ldrop (hi p) s)) (ho p))
          (paths nlist (hap (hap s p) (hinv p)) s)))))
   '(lam s (lam p (lam hb (lam hc
      (let A (ltake (hi p) s)
      (let W (ldrop (add (hi p) (nlen (ho p))) s)
      (let HA (ltakelen (hi p) s
                (istransnatleh (hi p) (add (hi p) (nlen (ho p))) (nlen s)
                  (natlehnplusnm (hi p) (nlen (ho p))) hb))
      (let Hs (pathscomp0 nlist s (lapp A (ldrop (hi p) s)) (lapp A (lapp (ho p) W))
                (pathsinv0 nlist (lapp A (ldrop (hi p) s)) s (lapptakedrop (hi p) s))
                (maponpaths nlist nlist (lam t (lapp A t)) (ldrop (hi p) s) (lapp (ho p) W)
                  (pathscomp0 nlist (ldrop (hi p) s)
                    (lapp (ltake (nlen (ho p)) (ldrop (hi p) s)) (ldrop (nlen (ho p)) (ldrop (hi p) s)))
                    (lapp (ho p) W)
                    (pathsinv0 nlist
                      (lapp (ltake (nlen (ho p)) (ldrop (hi p) s)) (ldrop (nlen (ho p)) (ldrop (hi p) s)))
                      (ldrop (hi p) s)
                      (lapptakedrop (nlen (ho p)) (ldrop (hi p) s)))
                    (pathscomp0 nlist
                      (lapp (ltake (nlen (ho p)) (ldrop (hi p) s)) (ldrop (nlen (ho p)) (ldrop (hi p) s)))
                      (lapp (ho p) (ldrop (nlen (ho p)) (ldrop (hi p) s)))
                      (lapp (ho p) W)
                      (maponpaths nlist nlist (lam t (lapp t (ldrop (nlen (ho p)) (ldrop (hi p) s))))
                        (ltake (nlen (ho p)) (ldrop (hi p) s)) (ho p) hc)
                      (maponpaths nlist nlist (lam t (lapp (ho p) t))
                        (ldrop (nlen (ho p)) (ldrop (hi p) s)) W (ldropdrop (hi p) (nlen (ho p)) s))))))
      (let T1 (pathscomp0 nlist
                (ltake (hi p) (lapp A (lapp (hn p) W)))
                (ltake (nlen A) (lapp A (lapp (hn p) W)))
                A
                (maponpaths nat nlist (lam w (ltake w (lapp A (lapp (hn p) W))))
                  (hi p) (nlen A) (pathsinv0 nat (nlen A) (hi p) HA))
                (ltakelenapp A (lapp (hn p) W)))
      (let T2 (pathscomp0 nlist
                (ldrop (add (hi p) (nlen (hn p))) (lapp A (lapp (hn p) W)))
                (ldrop (add (nlen A) (nlen (hn p))) (lapp A (lapp (hn p) W)))
                W
                (maponpaths nat nlist (lam w (ldrop (add w (nlen (hn p))) (lapp A (lapp (hn p) W))))
                  (hi p) (nlen A) (pathsinv0 nat (nlen A) (hi p) HA))
                (pathscomp0 nlist
                  (ldrop (add (nlen A) (nlen (hn p))) (lapp A (lapp (hn p) W)))
                  (ldrop (nlen (hn p)) (lapp (hn p) W))
                  W
                  (ldropplusapp A (nlen (hn p)) (lapp (hn p) W))
                  (ldroplenapp (hn p) W)))
      (pathscomp0 nlist
        (hap (hap s p) (hinv p))
        (lapp A (lapp (ho p) W))
        s
        (pathscomp0 nlist
          (lapp (ltake (hi p) (lapp A (lapp (hn p) W)))
                (lapp (ho p) (ldrop (add (hi p) (nlen (hn p))) (lapp A (lapp (hn p) W)))))
          (lapp A (lapp (ho p) (ldrop (add (hi p) (nlen (hn p))) (lapp A (lapp (hn p) W)))))
          (lapp A (lapp (ho p) W))
          (maponpaths nlist nlist
            (lam t (lapp t (lapp (ho p) (ldrop (add (hi p) (nlen (hn p))) (lapp A (lapp (hn p) W))))))
            (ltake (hi p) (lapp A (lapp (hn p) W))) A T1)
          (maponpaths nlist nlist (lam t (lapp A (lapp (ho p) t)))
            (ldrop (add (hi p) (nlen (hn p))) (lapp A (lapp (hn p) W))) W T2))
        (pathsinv0 nlist s (lapp A (lapp (ho p) W)) Hs)))))))))))))
 ; and it computes: lay a hunk, unpull it, the state is home
 ((vof 0 '(ncons 1 (ncons 2 (ncons 3 nnil))))
  = (vof 0 '(hap (hap (ncons 1 (ncons 2 (ncons 3 nnil))) (mkh 1 (ncons 2 nnil) (ncons 7 (ncons 8 nnil))))
                 (hinv (mkh 1 (ncons 2 nnil) (ncons 7 (ncons 8 nnil))))))))

; --- (L3a) the machinery, SEALED RUNG BY RUNG: a path-valued let poisons every
; --- later check in its scope (the eager NbE re-walks it superadditively --
; --- exactly why defq seals), so each intermediate path is its OWN defq and
; --- every use is a stuck neutral. seams is the one decomposition law all the
; --- slices lean on: a valid (i, o) window splits s as A ++ o ++ W ---
(assert
 (defq 'seams
   '(pi s nlist (pi i nat (pi o nlist
      (pi hb (paths bool (natgtb (add i (nlen o)) (nlen s)) false)
      (pi hc (paths nlist (ltake (nlen o) (ldrop i s)) o)
        (paths nlist s (lapp (ltake i s) (lapp o (ldrop (add i (nlen o)) s)))))))))
   '(lam s (lam i (lam o (lam hb (lam hc
      (pathscomp0 nlist s (lapp (ltake i s) (ldrop i s)) (lapp (ltake i s) (lapp o (ldrop (add i (nlen o)) s)))
        (pathsinv0 nlist (lapp (ltake i s) (ldrop i s)) s (lapptakedrop i s))
        (maponpaths nlist nlist (lam t (lapp (ltake i s) t)) (ldrop i s) (lapp o (ldrop (add i (nlen o)) s))
          (pathscomp0 nlist (ldrop i s)
            (lapp (ltake (nlen o) (ldrop i s)) (ldrop (nlen o) (ldrop i s)))
            (lapp o (ldrop (add i (nlen o)) s))
            (pathsinv0 nlist
              (lapp (ltake (nlen o) (ldrop i s)) (ldrop (nlen o) (ldrop i s)))
              (ldrop i s)
              (lapptakedrop (nlen o) (ldrop i s)))
            (pathscomp0 nlist
              (lapp (ltake (nlen o) (ldrop i s)) (ldrop (nlen o) (ldrop i s)))
              (lapp o (ldrop (nlen o) (ldrop i s)))
              (lapp o (ldrop (add i (nlen o)) s))
              (maponpaths nlist nlist (lam t (lapp t (ldrop (nlen o) (ldrop i s))))
                (ltake (nlen o) (ldrop i s)) o hc)
              (maponpaths nlist nlist (lam t (lapp o t))
                (ldrop (nlen o) (ldrop i s)) (ldrop (add i (nlen o)) s) (ldropdrop i (nlen o) s))))))))))))
 ; the AFTER branch's index ledger: with i + |n1| < j and the window in range,
 ; j sits |A| + (|n1| + kk) in from the patched state's seams (kk the gap)
 (defq 'after-j
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat
      (pi g (paths bool (natgtb j (add i (nlen n1))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
        (paths nat j (add (nlen (ltake i s)) (add (nlen n1) (natminus j (add i (nlen n1)))))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam g (lam hb1
      (let A (ltake i s)
      (let kk (natminus j (add i (nlen n1)))
      (pathscomp0 nat j (add i (add (nlen n1) kk)) (add (nlen A) (add (nlen n1) kk))
        (pathsinv0 nat (add i (add (nlen n1) kk)) j
          (pathscomp0 nat (add i (add (nlen n1) kk)) (add (add i (nlen n1)) kk) j
            (pathsinv0 nat (add (add i (nlen n1)) kk) (add i (add (nlen n1) kk))
              (natplusassoc i (nlen n1) kk))
            (pathscomp0 nat (add (add i (nlen n1)) kk) (add kk (add i (nlen n1))) j
              (natpluscomm (add i (nlen n1)) kk)
              (natminusplusnmm j (add i (nlen n1)) (natlthtoleh (add i (nlen n1)) j g)))))
        (maponpaths nat nat (lam w (add w (add (nlen n1) kk))) i (nlen A)
          (pathsinv0 nat (nlen A) i
            (ltakelen i s
              (istransnatleh i (add i (nlen o1)) (nlen s) (natlehnplusnm i (nlen o1)) hb1)))))))))))))))
 ; dropping j off the patched state is dropping the gap off W
 (defq 'after-drop
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat
      (pi g (paths bool (natgtb j (add i (nlen n1))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
        (paths nlist
          (ldrop j (lapp (ltake i s) (lapp n1 (ldrop (add i (nlen o1)) s))))
          (ldrop (natminus j (add i (nlen n1))) (ldrop (add i (nlen o1)) s))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam g (lam hb1
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (let kk (natminus j (add i (nlen n1)))
      (pathscomp0 nlist
        (ldrop j (lapp A (lapp n1 W)))
        (ldrop (add (nlen A) (add (nlen n1) kk)) (lapp A (lapp n1 W)))
        (ldrop kk W)
        (maponpaths nat nlist (lam w (ldrop w (lapp A (lapp n1 W))))
          j (add (nlen A) (add (nlen n1) kk)) (after-j s i o1 n1 j g hb1))
        (pathscomp0 nlist
          (ldrop (add (nlen A) (add (nlen n1) kk)) (lapp A (lapp n1 W)))
          (ldrop (add (nlen n1) kk) (lapp n1 W))
          (ldrop kk W)
          (ldropplusapp A (add (nlen n1) kk) (lapp n1 W))
          (ldropplusapp n1 kk W))))))))))))))
 ; q's context, re-read at the gap
 (defq 'after-c2
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat (pi o2 nlist
      (pi g (paths bool (natgtb j (add i (nlen n1))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
      (pi hc2 (paths nlist (ltake (nlen o2) (ldrop j (splice s i (nlen o1) n1))) o2)
        (paths nlist
          (ltake (nlen o2) (ldrop (natminus j (add i (nlen n1))) (ldrop (add i (nlen o1)) s)))
          o2))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam o2 (lam g (lam hb1 (lam hc2
      (pathscomp0 nlist
        (ltake (nlen o2) (ldrop (natminus j (add i (nlen n1))) (ldrop (add i (nlen o1)) s)))
        (ltake (nlen o2) (ldrop j (lapp (ltake i s) (lapp n1 (ldrop (add i (nlen o1)) s)))))
        o2
        (maponpaths nlist nlist (lam t (ltake (nlen o2) t))
          (ldrop (natminus j (add i (nlen n1))) (ldrop (add i (nlen o1)) s))
          (ldrop j (lapp (ltake i s) (lapp n1 (ldrop (add i (nlen o1)) s))))
          (pathsinv0 nlist
            (ldrop j (lapp (ltake i s) (lapp n1 (ldrop (add i (nlen o1)) s))))
            (ldrop (natminus j (add i (nlen n1))) (ldrop (add i (nlen o1)) s))
            (after-drop s i o1 n1 j g hb1)))
        hc2)))))))))))
 ; q's window, in range past the gap
 (defq 'after-bk
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat (pi o2 nlist
      (pi g (paths bool (natgtb j (add i (nlen n1))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
      (pi hb2 (paths bool (natgtb (add j (nlen o2)) (nlen (splice s i (nlen o1) n1))) false)
        (paths bool
          (natgtb (add (natminus j (add i (nlen n1))) (nlen o2)) (nlen (ldrop (add i (nlen o1)) s)))
          false))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam o2 (lam g (lam hb1 (lam hb2
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (let kk (natminus j (add i (nlen n1)))
      (let HA (ltakelen i s
                (istransnatleh i (add i (nlen o1)) (nlen s) (natlehnplusnm i (nlen o1)) hb1))
      (pathscomp0 bool
        (natgtb (add kk (nlen o2)) (nlen W))
        (natgtb (add (add i (nlen n1)) (add kk (nlen o2))) (add (add i (nlen n1)) (nlen W)))
        false
        (pathsinv0 bool
          (natgtb (add (add i (nlen n1)) (add kk (nlen o2))) (add (add i (nlen n1)) (nlen W)))
          (natgtb (add kk (nlen o2)) (nlen W))
          (natgtbplusl (add i (nlen n1)) (add kk (nlen o2)) (nlen W)))
        (pathscomp0 bool
          (natgtb (add (add i (nlen n1)) (add kk (nlen o2))) (add (add i (nlen n1)) (nlen W)))
          (natgtb (add j (nlen o2)) (add (add i (nlen n1)) (nlen W)))
          false
          (maponpaths nat bool (lam w (natgtb w (add (add i (nlen n1)) (nlen W))))
            (add (add i (nlen n1)) (add kk (nlen o2))) (add j (nlen o2))
            (pathscomp0 nat
              (add (add i (nlen n1)) (add kk (nlen o2)))
              (add (add (add i (nlen n1)) kk) (nlen o2))
              (add j (nlen o2))
              (pathsinv0 nat
                (add (add (add i (nlen n1)) kk) (nlen o2))
                (add (add i (nlen n1)) (add kk (nlen o2)))
                (natplusassoc (add i (nlen n1)) kk (nlen o2)))
              (maponpaths nat nat (lam w (add w (nlen o2)))
                (add (add i (nlen n1)) kk) j
                (pathscomp0 nat (add (add i (nlen n1)) kk) (add kk (add i (nlen n1))) j
                  (natpluscomm (add i (nlen n1)) kk)
                  (natminusplusnmm j (add i (nlen n1)) (natlthtoleh (add i (nlen n1)) j g))))))
          (pathscomp0 bool
            (natgtb (add j (nlen o2)) (add (add i (nlen n1)) (nlen W)))
            (natgtb (add j (nlen o2)) (nlen (lapp A (lapp n1 W))))
            false
            (maponpaths nat bool (lam w (natgtb (add j (nlen o2)) w))
              (add (add i (nlen n1)) (nlen W)) (nlen (lapp A (lapp n1 W)))
              (pathscomp0 nat
                (add (add i (nlen n1)) (nlen W))
                (add i (add (nlen n1) (nlen W)))
                (nlen (lapp A (lapp n1 W)))
                (natplusassoc i (nlen n1) (nlen W))
                (pathscomp0 nat
                  (add i (add (nlen n1) (nlen W)))
                  (add (nlen A) (add (nlen n1) (nlen W)))
                  (nlen (lapp A (lapp n1 W)))
                  (maponpaths nat nat (lam w (add w (add (nlen n1) (nlen W)))) i (nlen A)
                    (pathsinv0 nat (nlen A) i HA))
                  (pathsinv0 nat (nlen (lapp A (lapp n1 W))) (add (nlen A) (add (nlen n1) (nlen W)))
                    (pathscomp0 nat
                      (nlen (lapp A (lapp n1 W)))
                      (add (nlen A) (nlen (lapp n1 W)))
                      (add (nlen A) (add (nlen n1) (nlen W)))
                      (lapplen A (lapp n1 W))
                      (maponpaths nat nat (lam w (add (nlen A) w))
                        (nlen (lapp n1 W)) (add (nlen n1) (nlen W)) (lapplen n1 W)))))))
            hb2))))))))))))))))))

; --- the re-aimed index, located on the seams; then the four take/drop reads
; --- (the ORIGINAL order's two, the RE-AIMED order's two), the re-aimed
; --- state's normal form, and the assembly ---
(assert
 (defq 'after-j2v
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat
      (pi g (paths bool (natgtb j (add i (nlen n1))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
        (paths nat
          (natminus (add j (nlen o1)) (nlen n1))
          (add (nlen (ltake i s)) (add (nlen o1) (natminus j (add i (nlen n1)))))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam g (lam hb1
      (let A (ltake i s)
      (let kk (natminus j (add i (nlen n1)))
      (pathscomp0 nat
        (natminus (add j (nlen o1)) (nlen n1))
        (natminus (add (add (nlen A) (add (nlen o1) kk)) (nlen n1)) (nlen n1))
        (add (nlen A) (add (nlen o1) kk))
        (maponpaths nat nat (lam w (natminus w (nlen n1)))
          (add j (nlen o1)) (add (add (nlen A) (add (nlen o1) kk)) (nlen n1))
          (pathsinv0 nat (add (add (nlen A) (add (nlen o1) kk)) (nlen n1)) (add j (nlen o1))
            (pathscomp0 nat
              (add (add (nlen A) (add (nlen o1) kk)) (nlen n1))
              (add (add (add (nlen A) (nlen o1)) kk) (nlen n1))
              (add j (nlen o1))
              (maponpaths nat nat (lam w (add w (nlen n1)))
                (add (nlen A) (add (nlen o1) kk)) (add (add (nlen A) (nlen o1)) kk)
                (pathsinv0 nat (add (add (nlen A) (nlen o1)) kk) (add (nlen A) (add (nlen o1) kk))
                  (natplusassoc (nlen A) (nlen o1) kk)))
              (pathscomp0 nat
                (add (add (add (nlen A) (nlen o1)) kk) (nlen n1))
                (add (add (add (nlen A) (nlen o1)) (nlen n1)) kk)
                (add j (nlen o1))
                (natplusswap (add (nlen A) (nlen o1)) kk (nlen n1))
                (pathscomp0 nat
                  (add (add (add (nlen A) (nlen o1)) (nlen n1)) kk)
                  (add (add (add (nlen A) (nlen n1)) (nlen o1)) kk)
                  (add j (nlen o1))
                  (maponpaths nat nat (lam w (add w kk))
                    (add (add (nlen A) (nlen o1)) (nlen n1)) (add (add (nlen A) (nlen n1)) (nlen o1))
                    (natplusswap (nlen A) (nlen o1) (nlen n1)))
                  (pathscomp0 nat
                    (add (add (add (nlen A) (nlen n1)) (nlen o1)) kk)
                    (add (add (add (nlen A) (nlen n1)) kk) (nlen o1))
                    (add j (nlen o1))
                    (natplusswap (add (nlen A) (nlen n1)) (nlen o1) kk)
                    (pathscomp0 nat
                      (add (add (add (nlen A) (nlen n1)) kk) (nlen o1))
                      (add (add (nlen A) (add (nlen n1) kk)) (nlen o1))
                      (add j (nlen o1))
                      (maponpaths nat nat (lam w (add w (nlen o1)))
                        (add (add (nlen A) (nlen n1)) kk) (add (nlen A) (add (nlen n1) kk))
                        (natplusassoc (nlen A) (nlen n1) kk))
                      (maponpaths nat nat (lam w (add w (nlen o1)))
                        (add (nlen A) (add (nlen n1) kk)) j
                        (pathsinv0 nat j (add (nlen A) (add (nlen n1) kk))
                          (after-j s i o1 n1 j g hb1))))))))))
        (natpluscancelminus (add (nlen A) (add (nlen o1) kk)) (nlen n1)))))))))))))
 (defq 'after-u1
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat (pi o2 nlist
      (pi g (paths bool (natgtb j (add i (nlen n1))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
      (pi hc1 (paths nlist (ltake (nlen o1) (ldrop i s)) o1)
      (pi hb2 (paths bool (natgtb (add j (nlen o2)) (nlen (splice s i (nlen o1) n1))) false)
      (pi hc2 (paths nlist (ltake (nlen o2) (ldrop j (splice s i (nlen o1) n1))) o2)
        (paths nlist
          (ltake (natminus (add j (nlen o1)) (nlen n1)) s)
          (lapp (ltake i s) (lapp o1 (ltake (natminus j (add i (nlen n1))) (ldrop (add i (nlen o1)) s))))))))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam o2 (lam g (lam hb1 (lam hc1 (lam hb2 (lam hc2
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (let kk (natminus j (add i (nlen n1)))
      (let M (ltake kk W)
      (let Z (ldrop (add kk (nlen o2)) W)
      (pathscomp0 nlist
        (ltake (natminus (add j (nlen o1)) (nlen n1)) s)
        (ltake (add (nlen A) (add (nlen o1) kk)) s)
        (lapp A (lapp o1 M))
        (maponpaths nat nlist (lam w (ltake w s))
          (natminus (add j (nlen o1)) (nlen n1)) (add (nlen A) (add (nlen o1) kk))
          (after-j2v s i o1 n1 j g hb1))
        (pathscomp0 nlist
          (ltake (add (nlen A) (add (nlen o1) kk)) s)
          (ltake (add (nlen A) (add (nlen o1) kk)) (lapp A (lapp o1 (lapp M (lapp o2 Z)))))
          (lapp A (lapp o1 M))
          (maponpaths nlist nlist (lam t (ltake (add (nlen A) (add (nlen o1) kk)) t))
            s (lapp A (lapp o1 (lapp M (lapp o2 Z))))
            (pathscomp0 nlist s (lapp A (lapp o1 W)) (lapp A (lapp o1 (lapp M (lapp o2 Z))))
              (seams s i o1 hb1 hc1)
              (maponpaths nlist nlist (lam t (lapp A (lapp o1 t))) W (lapp M (lapp o2 Z))
                (seams W kk o2
                  (after-bk s i o1 n1 j o2 g hb1 hb2)
                  (after-c2 s i o1 n1 j o2 g hb1 hc2)))))
          (pathscomp0 nlist
            (ltake (add (nlen A) (add (nlen o1) kk)) (lapp A (lapp o1 (lapp M (lapp o2 Z)))))
            (lapp A (ltake (add (nlen o1) kk) (lapp o1 (lapp M (lapp o2 Z)))))
            (lapp A (lapp o1 M))
            (ltakeplusapp A (add (nlen o1) kk) (lapp o1 (lapp M (lapp o2 Z))))
            (pathscomp0 nlist
              (lapp A (ltake (add (nlen o1) kk) (lapp o1 (lapp M (lapp o2 Z)))))
              (lapp A (lapp o1 (ltake kk (lapp M (lapp o2 Z)))))
              (lapp A (lapp o1 M))
              (maponpaths nlist nlist (lam t (lapp A t))
                (ltake (add (nlen o1) kk) (lapp o1 (lapp M (lapp o2 Z))))
                (lapp o1 (ltake kk (lapp M (lapp o2 Z))))
                (ltakeplusapp o1 kk (lapp M (lapp o2 Z))))
              (pathscomp0 nlist
                (lapp A (lapp o1 (ltake kk (lapp M (lapp o2 Z)))))
                (lapp A (lapp o1 (ltake (nlen M) (lapp M (lapp o2 Z)))))
                (lapp A (lapp o1 M))
                (maponpaths nat nlist (lam w (lapp A (lapp o1 (ltake w (lapp M (lapp o2 Z))))))
                  kk (nlen M)
                  (pathsinv0 nat (nlen M) kk
                    (ltakelen kk W
                      (istransnatleh kk (add kk (nlen o2)) (nlen W) (natlehnplusnm kk (nlen o2))
                        (after-bk s i o1 n1 j o2 g hb1 hb2)))))
                (maponpaths nlist nlist (lam t (lapp A (lapp o1 t)))
                  (ltake (nlen M) (lapp M (lapp o2 Z))) M
                  (ltakelenapp M (lapp o2 Z)))))))))))))))))))))))))
 (defq 'after-u2
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat (pi o2 nlist
      (pi g (paths bool (natgtb j (add i (nlen n1))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
      (pi hc1 (paths nlist (ltake (nlen o1) (ldrop i s)) o1)
      (pi hb2 (paths bool (natgtb (add j (nlen o2)) (nlen (splice s i (nlen o1) n1))) false)
      (pi hc2 (paths nlist (ltake (nlen o2) (ldrop j (splice s i (nlen o1) n1))) o2)
        (paths nlist
          (ldrop (add (natminus (add j (nlen o1)) (nlen n1)) (nlen o2)) s)
          (ldrop (add (natminus j (add i (nlen n1))) (nlen o2)) (ldrop (add i (nlen o1)) s))))))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam o2 (lam g (lam hb1 (lam hc1 (lam hb2 (lam hc2
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (let kk (natminus j (add i (nlen n1)))
      (let M (ltake kk W)
      (let Z (ldrop (add kk (nlen o2)) W)
      (pathscomp0 nlist
        (ldrop (add (natminus (add j (nlen o1)) (nlen n1)) (nlen o2)) s)
        (ldrop (add (nlen A) (add (nlen o1) (add kk (nlen o2)))) s)
        Z
        (maponpaths nat nlist (lam w (ldrop w s))
          (add (natminus (add j (nlen o1)) (nlen n1)) (nlen o2))
          (add (nlen A) (add (nlen o1) (add kk (nlen o2))))
          (pathscomp0 nat
            (add (natminus (add j (nlen o1)) (nlen n1)) (nlen o2))
            (add (add (nlen A) (add (nlen o1) kk)) (nlen o2))
            (add (nlen A) (add (nlen o1) (add kk (nlen o2))))
            (maponpaths nat nat (lam w (add w (nlen o2)))
              (natminus (add j (nlen o1)) (nlen n1)) (add (nlen A) (add (nlen o1) kk))
              (after-j2v s i o1 n1 j g hb1))
            (pathscomp0 nat
              (add (add (nlen A) (add (nlen o1) kk)) (nlen o2))
              (add (nlen A) (add (add (nlen o1) kk) (nlen o2)))
              (add (nlen A) (add (nlen o1) (add kk (nlen o2))))
              (natplusassoc (nlen A) (add (nlen o1) kk) (nlen o2))
              (maponpaths nat nat (lam w (add (nlen A) w))
                (add (add (nlen o1) kk) (nlen o2)) (add (nlen o1) (add kk (nlen o2)))
                (natplusassoc (nlen o1) kk (nlen o2))))))
        (pathscomp0 nlist
          (ldrop (add (nlen A) (add (nlen o1) (add kk (nlen o2)))) s)
          (ldrop (add (nlen A) (add (nlen o1) (add kk (nlen o2)))) (lapp A (lapp o1 (lapp M (lapp o2 Z)))))
          Z
          (maponpaths nlist nlist (lam t (ldrop (add (nlen A) (add (nlen o1) (add kk (nlen o2)))) t))
            s (lapp A (lapp o1 (lapp M (lapp o2 Z))))
            (pathscomp0 nlist s (lapp A (lapp o1 W)) (lapp A (lapp o1 (lapp M (lapp o2 Z))))
              (seams s i o1 hb1 hc1)
              (maponpaths nlist nlist (lam t (lapp A (lapp o1 t))) W (lapp M (lapp o2 Z))
                (seams W kk o2
                  (after-bk s i o1 n1 j o2 g hb1 hb2)
                  (after-c2 s i o1 n1 j o2 g hb1 hc2)))))
          (pathscomp0 nlist
            (ldrop (add (nlen A) (add (nlen o1) (add kk (nlen o2)))) (lapp A (lapp o1 (lapp M (lapp o2 Z)))))
            (ldrop (add (nlen o1) (add kk (nlen o2))) (lapp o1 (lapp M (lapp o2 Z))))
            Z
            (ldropplusapp A (add (nlen o1) (add kk (nlen o2))) (lapp o1 (lapp M (lapp o2 Z))))
            (pathscomp0 nlist
              (ldrop (add (nlen o1) (add kk (nlen o2))) (lapp o1 (lapp M (lapp o2 Z))))
              (ldrop (add kk (nlen o2)) (lapp M (lapp o2 Z)))
              Z
              (ldropplusapp o1 (add kk (nlen o2)) (lapp M (lapp o2 Z)))
              (pathscomp0 nlist
                (ldrop (add kk (nlen o2)) (lapp M (lapp o2 Z)))
                (ldrop (add (nlen M) (nlen o2)) (lapp M (lapp o2 Z)))
                Z
                (maponpaths nat nlist (lam w (ldrop (add w (nlen o2)) (lapp M (lapp o2 Z))))
                  kk (nlen M)
                  (pathsinv0 nat (nlen M) kk
                    (ltakelen kk W
                      (istransnatleh kk (add kk (nlen o2)) (nlen W) (natlehnplusnm kk (nlen o2))
                        (after-bk s i o1 n1 j o2 g hb1 hb2)))))
                (pathscomp0 nlist
                  (ldrop (add (nlen M) (nlen o2)) (lapp M (lapp o2 Z)))
                  (ldrop (nlen o2) (lapp o2 Z))
                  Z
                  (ldropplusapp M (nlen o2) (lapp o2 Z))
                  (ldroplenapp o2 Z))))))))))))))))))))))))
 (defq 'after-l1p
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat
      (pi g (paths bool (natgtb j (add i (nlen n1))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
        (paths nlist
          (ltake j (lapp (ltake i s) (lapp n1 (ldrop (add i (nlen o1)) s))))
          (lapp (ltake i s) (lapp n1 (ltake (natminus j (add i (nlen n1))) (ldrop (add i (nlen o1)) s))))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam g (lam hb1
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (let kk (natminus j (add i (nlen n1)))
      (pathscomp0 nlist
        (ltake j (lapp A (lapp n1 W)))
        (ltake (add (nlen A) (add (nlen n1) kk)) (lapp A (lapp n1 W)))
        (lapp A (lapp n1 (ltake kk W)))
        (maponpaths nat nlist (lam w (ltake w (lapp A (lapp n1 W))))
          j (add (nlen A) (add (nlen n1) kk)) (after-j s i o1 n1 j g hb1))
        (pathscomp0 nlist
          (ltake (add (nlen A) (add (nlen n1) kk)) (lapp A (lapp n1 W)))
          (lapp A (ltake (add (nlen n1) kk) (lapp n1 W)))
          (lapp A (lapp n1 (ltake kk W)))
          (ltakeplusapp A (add (nlen n1) kk) (lapp n1 W))
          (maponpaths nlist nlist (lam t (lapp A t))
            (ltake (add (nlen n1) kk) (lapp n1 W)) (lapp n1 (ltake kk W))
            (ltakeplusapp n1 kk W)))))))))))))))
 (defq 'after-l2p
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat (pi o2 nlist
      (pi g (paths bool (natgtb j (add i (nlen n1))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
        (paths nlist
          (ldrop (add j (nlen o2)) (lapp (ltake i s) (lapp n1 (ldrop (add i (nlen o1)) s))))
          (ldrop (add (natminus j (add i (nlen n1))) (nlen o2)) (ldrop (add i (nlen o1)) s)))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam o2 (lam g (lam hb1
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (let kk (natminus j (add i (nlen n1)))
      (pathscomp0 nlist
        (ldrop (add j (nlen o2)) (lapp A (lapp n1 W)))
        (ldrop (add (nlen A) (add (nlen n1) (add kk (nlen o2)))) (lapp A (lapp n1 W)))
        (ldrop (add kk (nlen o2)) W)
        (maponpaths nat nlist (lam w (ldrop w (lapp A (lapp n1 W))))
          (add j (nlen o2))
          (add (nlen A) (add (nlen n1) (add kk (nlen o2))))
          (pathscomp0 nat
            (add j (nlen o2))
            (add (add (nlen A) (add (nlen n1) kk)) (nlen o2))
            (add (nlen A) (add (nlen n1) (add kk (nlen o2))))
            (maponpaths nat nat (lam w (add w (nlen o2)))
              j (add (nlen A) (add (nlen n1) kk)) (after-j s i o1 n1 j g hb1))
            (pathscomp0 nat
              (add (add (nlen A) (add (nlen n1) kk)) (nlen o2))
              (add (nlen A) (add (add (nlen n1) kk) (nlen o2)))
              (add (nlen A) (add (nlen n1) (add kk (nlen o2))))
              (natplusassoc (nlen A) (add (nlen n1) kk) (nlen o2))
              (maponpaths nat nat (lam w (add (nlen A) w))
                (add (add (nlen n1) kk) (nlen o2)) (add (nlen n1) (add kk (nlen o2)))
                (natplusassoc (nlen n1) kk (nlen o2))))))
        (pathscomp0 nlist
          (ldrop (add (nlen A) (add (nlen n1) (add kk (nlen o2)))) (lapp A (lapp n1 W)))
          (ldrop (add (nlen n1) (add kk (nlen o2))) (lapp n1 W))
          (ldrop (add kk (nlen o2)) W)
          (ldropplusapp A (add (nlen n1) (add kk (nlen o2))) (lapp n1 W))
          (ldropplusapp n1 (add kk (nlen o2)) W))))))))))))))))

; --- the re-aimed state's normal form, its two reads at p's window, and the
; --- assembly: both orders land A ++ n1 ++ M ++ n2 ++ Z ---
(assert
 (defq 'after-nf2
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat (pi o2 nlist (pi n2 nlist
      (pi g (paths bool (natgtb j (add i (nlen n1))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
      (pi hc1 (paths nlist (ltake (nlen o1) (ldrop i s)) o1)
      (pi hb2 (paths bool (natgtb (add j (nlen o2)) (nlen (splice s i (nlen o1) n1))) false)
      (pi hc2 (paths nlist (ltake (nlen o2) (ldrop j (splice s i (nlen o1) n1))) o2)
        (paths nlist
          (splice s (natminus (add j (nlen o1)) (nlen n1)) (nlen o2) n2)
          (lapp (ltake i s)
                (lapp o1 (lapp (ltake (natminus j (add i (nlen n1))) (ldrop (add i (nlen o1)) s))
                              (lapp n2 (ldrop (add (natminus j (add i (nlen n1))) (nlen o2)) (ldrop (add i (nlen o1)) s)))))))))))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam o2 (lam n2 (lam g (lam hb1 (lam hc1 (lam hb2 (lam hc2
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (let kk (natminus j (add i (nlen n1)))
      (let M (ltake kk W)
      (let Z (ldrop (add kk (nlen o2)) W)
      (let j2 (natminus (add j (nlen o1)) (nlen n1))
      (pathscomp0 nlist
        (splice s j2 (nlen o2) n2)
        (lapp (lapp A (lapp o1 M)) (lapp n2 Z))
        (lapp A (lapp o1 (lapp M (lapp n2 Z))))
        (pathscomp0 nlist
          (lapp (ltake j2 s) (lapp n2 (ldrop (add j2 (nlen o2)) s)))
          (lapp (lapp A (lapp o1 M)) (lapp n2 (ldrop (add j2 (nlen o2)) s)))
          (lapp (lapp A (lapp o1 M)) (lapp n2 Z))
          (maponpaths nlist nlist (lam t (lapp t (lapp n2 (ldrop (add j2 (nlen o2)) s))))
            (ltake j2 s) (lapp A (lapp o1 M))
            (after-u1 s i o1 n1 j o2 g hb1 hc1 hb2 hc2))
          (maponpaths nlist nlist (lam t (lapp (lapp A (lapp o1 M)) (lapp n2 t)))
            (ldrop (add j2 (nlen o2)) s) Z
            (after-u2 s i o1 n1 j o2 g hb1 hc1 hb2 hc2)))
        (pathscomp0 nlist
          (lapp (lapp A (lapp o1 M)) (lapp n2 Z))
          (lapp A (lapp (lapp o1 M) (lapp n2 Z)))
          (lapp A (lapp o1 (lapp M (lapp n2 Z))))
          (lappassoc A (lapp o1 M) (lapp n2 Z))
          (maponpaths nlist nlist (lam t (lapp A t))
            (lapp (lapp o1 M) (lapp n2 Z)) (lapp o1 (lapp M (lapp n2 Z)))
            (lappassoc o1 M (lapp n2 Z))))))))))))))))))))))))
 (defq 'after-v1
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat (pi o2 nlist (pi n2 nlist
      (pi g (paths bool (natgtb j (add i (nlen n1))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
      (pi hc1 (paths nlist (ltake (nlen o1) (ldrop i s)) o1)
      (pi hb2 (paths bool (natgtb (add j (nlen o2)) (nlen (splice s i (nlen o1) n1))) false)
      (pi hc2 (paths nlist (ltake (nlen o2) (ldrop j (splice s i (nlen o1) n1))) o2)
        (paths nlist
          (ltake i (splice s (natminus (add j (nlen o1)) (nlen n1)) (nlen o2) n2))
          (ltake i s))))))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam o2 (lam n2 (lam g (lam hb1 (lam hc1 (lam hb2 (lam hc2
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (let kk (natminus j (add i (nlen n1)))
      (let M (ltake kk W)
      (let Z (ldrop (add kk (nlen o2)) W)
      (let j2 (natminus (add j (nlen o1)) (nlen n1))
      (pathscomp0 nlist
        (ltake i (splice s j2 (nlen o2) n2))
        (ltake (nlen A) (splice s j2 (nlen o2) n2))
        A
        (maponpaths nat nlist (lam w (ltake w (splice s j2 (nlen o2) n2)))
          i (nlen A)
          (pathsinv0 nat (nlen A) i
            (ltakelen i s
              (istransnatleh i (add i (nlen o1)) (nlen s) (natlehnplusnm i (nlen o1)) hb1))))
        (pathscomp0 nlist
          (ltake (nlen A) (splice s j2 (nlen o2) n2))
          (ltake (nlen A) (lapp A (lapp o1 (lapp M (lapp n2 Z)))))
          A
          (maponpaths nlist nlist (lam t (ltake (nlen A) t))
            (splice s j2 (nlen o2) n2) (lapp A (lapp o1 (lapp M (lapp n2 Z))))
            (after-nf2 s i o1 n1 j o2 n2 g hb1 hc1 hb2 hc2))
          (ltakelenapp A (lapp o1 (lapp M (lapp n2 Z)))))))))))))))))))))))))
 (defq 'after-v2
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat (pi o2 nlist (pi n2 nlist
      (pi g (paths bool (natgtb j (add i (nlen n1))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
      (pi hc1 (paths nlist (ltake (nlen o1) (ldrop i s)) o1)
      (pi hb2 (paths bool (natgtb (add j (nlen o2)) (nlen (splice s i (nlen o1) n1))) false)
      (pi hc2 (paths nlist (ltake (nlen o2) (ldrop j (splice s i (nlen o1) n1))) o2)
        (paths nlist
          (ldrop (add i (nlen o1)) (splice s (natminus (add j (nlen o1)) (nlen n1)) (nlen o2) n2))
          (lapp (ltake (natminus j (add i (nlen n1))) (ldrop (add i (nlen o1)) s))
                (lapp n2 (ldrop (add (natminus j (add i (nlen n1))) (nlen o2)) (ldrop (add i (nlen o1)) s)))))))))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam o2 (lam n2 (lam g (lam hb1 (lam hc1 (lam hb2 (lam hc2
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (let kk (natminus j (add i (nlen n1)))
      (let M (ltake kk W)
      (let Z (ldrop (add kk (nlen o2)) W)
      (let j2 (natminus (add j (nlen o1)) (nlen n1))
      (pathscomp0 nlist
        (ldrop (add i (nlen o1)) (splice s j2 (nlen o2) n2))
        (ldrop (add (nlen A) (nlen o1)) (splice s j2 (nlen o2) n2))
        (lapp M (lapp n2 Z))
        (maponpaths nat nlist (lam w (ldrop (add w (nlen o1)) (splice s j2 (nlen o2) n2)))
          i (nlen A)
          (pathsinv0 nat (nlen A) i
            (ltakelen i s
              (istransnatleh i (add i (nlen o1)) (nlen s) (natlehnplusnm i (nlen o1)) hb1))))
        (pathscomp0 nlist
          (ldrop (add (nlen A) (nlen o1)) (splice s j2 (nlen o2) n2))
          (ldrop (add (nlen A) (nlen o1)) (lapp A (lapp o1 (lapp M (lapp n2 Z)))))
          (lapp M (lapp n2 Z))
          (maponpaths nlist nlist (lam t (ldrop (add (nlen A) (nlen o1)) t))
            (splice s j2 (nlen o2) n2) (lapp A (lapp o1 (lapp M (lapp n2 Z))))
            (after-nf2 s i o1 n1 j o2 n2 g hb1 hc1 hb2 hc2))
          (pathscomp0 nlist
            (ldrop (add (nlen A) (nlen o1)) (lapp A (lapp o1 (lapp M (lapp n2 Z)))))
            (ldrop (nlen o1) (lapp o1 (lapp M (lapp n2 Z))))
            (lapp M (lapp n2 Z))
            (ldropplusapp A (nlen o1) (lapp o1 (lapp M (lapp n2 Z))))
            (ldroplenapp o1 (lapp M (lapp n2 Z)))))))))))))))))))))))))
 (defq 'splice-after-comm
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat (pi o2 nlist (pi n2 nlist
      (pi g (paths bool (natgtb j (add i (nlen n1))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
      (pi hc1 (paths nlist (ltake (nlen o1) (ldrop i s)) o1)
      (pi hb2 (paths bool (natgtb (add j (nlen o2)) (nlen (splice s i (nlen o1) n1))) false)
      (pi hc2 (paths nlist (ltake (nlen o2) (ldrop j (splice s i (nlen o1) n1))) o2)
        (paths nlist
          (splice (splice s i (nlen o1) n1) j (nlen o2) n2)
          (splice (splice s (natminus (add j (nlen o1)) (nlen n1)) (nlen o2) n2) i (nlen o1) n1))))))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam o2 (lam n2 (lam g (lam hb1 (lam hc1 (lam hb2 (lam hc2
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (let kk (natminus j (add i (nlen n1)))
      (let M (ltake kk W)
      (let Z (ldrop (add kk (nlen o2)) W)
      (let j2 (natminus (add j (nlen o1)) (nlen n1))
      (pathscomp0 nlist
        (splice (splice s i (nlen o1) n1) j (nlen o2) n2)
        (lapp A (lapp n1 (lapp M (lapp n2 Z))))
        (splice (splice s j2 (nlen o2) n2) i (nlen o1) n1)
        (pathscomp0 nlist
          (splice (splice s i (nlen o1) n1) j (nlen o2) n2)
          (lapp (lapp A (lapp n1 M)) (lapp n2 Z))
          (lapp A (lapp n1 (lapp M (lapp n2 Z))))
          (pathscomp0 nlist
            (lapp (ltake j (lapp A (lapp n1 W))) (lapp n2 (ldrop (add j (nlen o2)) (lapp A (lapp n1 W)))))
            (lapp (lapp A (lapp n1 M)) (lapp n2 (ldrop (add j (nlen o2)) (lapp A (lapp n1 W)))))
            (lapp (lapp A (lapp n1 M)) (lapp n2 Z))
            (maponpaths nlist nlist
              (lam t (lapp t (lapp n2 (ldrop (add j (nlen o2)) (lapp A (lapp n1 W))))))
              (ltake j (lapp A (lapp n1 W))) (lapp A (lapp n1 M))
              (after-l1p s i o1 n1 j g hb1))
            (maponpaths nlist nlist (lam t (lapp (lapp A (lapp n1 M)) (lapp n2 t)))
              (ldrop (add j (nlen o2)) (lapp A (lapp n1 W))) Z
              (after-l2p s i o1 n1 j o2 g hb1)))
          (pathscomp0 nlist
            (lapp (lapp A (lapp n1 M)) (lapp n2 Z))
            (lapp A (lapp (lapp n1 M) (lapp n2 Z)))
            (lapp A (lapp n1 (lapp M (lapp n2 Z))))
            (lappassoc A (lapp n1 M) (lapp n2 Z))
            (maponpaths nlist nlist (lam t (lapp A t))
              (lapp (lapp n1 M) (lapp n2 Z)) (lapp n1 (lapp M (lapp n2 Z)))
              (lappassoc n1 M (lapp n2 Z)))))
        (pathsinv0 nlist
          (splice (splice s j2 (nlen o2) n2) i (nlen o1) n1)
          (lapp A (lapp n1 (lapp M (lapp n2 Z))))
          (pathscomp0 nlist
            (lapp (ltake i (splice s j2 (nlen o2) n2)) (lapp n1 (ldrop (add i (nlen o1)) (splice s j2 (nlen o2) n2))))
            (lapp A (lapp n1 (ldrop (add i (nlen o1)) (splice s j2 (nlen o2) n2))))
            (lapp A (lapp n1 (lapp M (lapp n2 Z))))
            (maponpaths nlist nlist
              (lam t (lapp t (lapp n1 (ldrop (add i (nlen o1)) (splice s j2 (nlen o2) n2)))))
              (ltake i (splice s j2 (nlen o2) n2)) A
              (after-v1 s i o1 n1 j o2 n2 g hb1 hc1 hb2 hc2))
            (maponpaths nlist nlist (lam t (lapp A (lapp n1 t)))
              (ldrop (add i (nlen o1)) (splice s j2 (nlen o2) n2)) (lapp M (lapp n2 Z))
              (after-v2 s i o1 n1 j o2 n2 g hb1 hc1 hb2 hc2)))))))))))))))))))))))))

; --- the BEFORE branch: q aims strictly ahead of p, so p slides FORWARD by
; --- q's delta. the state decomposes B ++ o2 ++ C ++ o1 ++ W; the same sealed
; --- ladder, with A's own seams carrying the front half ---
(assert
 (defq 'before-leh-ja
   '(pi s nlist (pi i nat (pi o1 nlist (pi j nat (pi o2 nlist
      (pi g2 (paths bool (natgtb i (add j (nlen o2))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
        (paths bool (natgtb j (nlen (ltake i s))) false))))))))
   '(lam s (lam i (lam o1 (lam j (lam o2 (lam g2 (lam hb1
      (pathscomp0 bool
        (natgtb j (nlen (ltake i s)))
        (natgtb j i)
        false
        (maponpaths nat bool (lam w (natgtb j w)) (nlen (ltake i s)) i
          (ltakelen i s
            (istransnatleh i (add i (nlen o1)) (nlen s) (natlehnplusnm i (nlen o1)) hb1)))
        (istransnatleh j (add j (nlen o2)) i
          (natlehnplusnm j (nlen o2))
          (natlthtoleh (add j (nlen o2)) i g2)))))))))))
 (defq 'before-leh-jo
   '(pi s nlist (pi i nat (pi o1 nlist (pi j nat (pi o2 nlist
      (pi g2 (paths bool (natgtb i (add j (nlen o2))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
        (paths bool (natgtb (add j (nlen o2)) (nlen (ltake i s))) false))))))))
   '(lam s (lam i (lam o1 (lam j (lam o2 (lam g2 (lam hb1
      (pathscomp0 bool
        (natgtb (add j (nlen o2)) (nlen (ltake i s)))
        (natgtb (add j (nlen o2)) i)
        false
        (maponpaths nat bool (lam w (natgtb (add j (nlen o2)) w)) (nlen (ltake i s)) i
          (ltakelen i s
            (istransnatleh i (add i (nlen o1)) (nlen s) (natlehnplusnm i (nlen o1)) hb1)))
        (natlthtoleh (add j (nlen o2)) i g2))))))))))
 ; q's context re-read on A's front: peel the appended tail twice
 (defq 'before-hca
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat (pi o2 nlist
      (pi g2 (paths bool (natgtb i (add j (nlen o2))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
      (pi hc2 (paths nlist (ltake (nlen o2) (ldrop j (splice s i (nlen o1) n1))) o2)
        (paths nlist (ltake (nlen o2) (ldrop j (ltake i s))) o2))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam o2 (lam g2 (lam hb1 (lam hc2
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (pathscomp0 nlist
        (ltake (nlen o2) (ldrop j A))
        (ltake (nlen o2) (lapp (ldrop j A) (lapp n1 W)))
        o2
        (pathsinv0 nlist
          (ltake (nlen o2) (lapp (ldrop j A) (lapp n1 W)))
          (ltake (nlen o2) (ldrop j A))
          (ltakeprefix (nlen o2) (ldrop j A) (lapp n1 W)
            (pathscomp0 bool
              (natgtb (nlen o2) (nlen (ldrop j A)))
              (natgtb (nlen o2) (natminus i j))
              false
              (maponpaths nat bool (lam w (natgtb (nlen o2) w))
                (nlen (ldrop j A)) (natminus i j)
                (pathscomp0 nat (nlen (ldrop j A)) (natminus (nlen A) j) (natminus i j)
                  (ldroplen j A)
                  (maponpaths nat nat (lam w (natminus w j)) (nlen A) i
                    (ltakelen i s
                      (istransnatleh i (add i (nlen o1)) (nlen s) (natlehnplusnm i (nlen o1)) hb1)))))
              (pathscomp0 bool
                (natgtb (nlen o2) (natminus i j))
                (natgtb (natminus (add j (nlen o2)) j) (natminus i j))
                false
                (maponpaths nat bool (lam w (natgtb w (natminus i j)))
                  (nlen o2) (natminus (add j (nlen o2)) j)
                  (pathsinv0 nat (natminus (add j (nlen o2)) j) (nlen o2)
                    (natpluslcancelminus j (nlen o2))))
                (natlehandminusl (add j (nlen o2)) i j
                  (natlthtoleh (add j (nlen o2)) i g2))))))
        (pathscomp0 nlist
          (ltake (nlen o2) (lapp (ldrop j A) (lapp n1 W)))
          (ltake (nlen o2) (ldrop j (lapp A (lapp n1 W))))
          o2
          (maponpaths nlist nlist (lam t (ltake (nlen o2) t))
            (lapp (ldrop j A) (lapp n1 W))
            (ldrop j (lapp A (lapp n1 W)))
            (pathsinv0 nlist
              (ldrop j (lapp A (lapp n1 W)))
              (lapp (ldrop j A) (lapp n1 W))
              (ldropprefix j A (lapp n1 W)
                (before-leh-ja s i o1 j o2 g2 hb1))))
          hc2))))))))))))))
)

; --- the slid index, ALL NAT (tower lengths named by the guards' arithmetic,
; --- so conv never re-walks a take/drop tower); then the re-aimed state's
; --- normal form, its two reads, and the assembly ---
(assert
 (defq 'before-i2v
   '(pi i nat (pi j nat (pi o2 nlist (pi n2 nlist
      (pi g2 (paths bool (natgtb i (add j (nlen o2))) true)
        (paths nat
          (natminus (add i (nlen n2)) (nlen o2))
          (add j (add (nlen n2) (natminus i (add j (nlen o2)))))))))))
   '(lam i (lam j (lam o2 (lam n2 (lam g2
      (let cc (natminus i (add j (nlen o2)))
      (pathscomp0 nat
        (natminus (add i (nlen n2)) (nlen o2))
        (natminus (add (add j (add (nlen n2) cc)) (nlen o2)) (nlen o2))
        (add j (add (nlen n2) cc))
        (maponpaths nat nat (lam w (natminus w (nlen o2)))
          (add i (nlen n2)) (add (add j (add (nlen n2) cc)) (nlen o2))
          (pathsinv0 nat (add (add j (add (nlen n2) cc)) (nlen o2)) (add i (nlen n2))
            (pathscomp0 nat
              (add (add j (add (nlen n2) cc)) (nlen o2))
              (add (add (add j (nlen n2)) cc) (nlen o2))
              (add i (nlen n2))
              (maponpaths nat nat (lam w (add w (nlen o2)))
                (add j (add (nlen n2) cc)) (add (add j (nlen n2)) cc)
                (pathsinv0 nat (add (add j (nlen n2)) cc) (add j (add (nlen n2) cc))
                  (natplusassoc j (nlen n2) cc)))
              (pathscomp0 nat
                (add (add (add j (nlen n2)) cc) (nlen o2))
                (add (add (add j (nlen n2)) (nlen o2)) cc)
                (add i (nlen n2))
                (natplusswap (add j (nlen n2)) cc (nlen o2))
                (pathscomp0 nat
                  (add (add (add j (nlen n2)) (nlen o2)) cc)
                  (add (add (add j (nlen o2)) (nlen n2)) cc)
                  (add i (nlen n2))
                  (maponpaths nat nat (lam w (add w cc))
                    (add (add j (nlen n2)) (nlen o2)) (add (add j (nlen o2)) (nlen n2))
                    (natplusswap j (nlen n2) (nlen o2)))
                  (pathscomp0 nat
                    (add (add (add j (nlen o2)) (nlen n2)) cc)
                    (add (add (add j (nlen o2)) cc) (nlen n2))
                    (add i (nlen n2))
                    (natplusswap (add j (nlen o2)) (nlen n2) cc)
                    (maponpaths nat nat (lam w (add w (nlen n2)))
                      (add (add j (nlen o2)) cc) i
                      (pathscomp0 nat (add (add j (nlen o2)) cc) (add cc (add j (nlen o2))) i
                        (natpluscomm (add j (nlen o2)) cc)
                        (natminusplusnmm i (add j (nlen o2))
                          (natlthtoleh (add j (nlen o2)) i g2))))))))))
        (natpluscancelminus (add j (add (nlen n2) cc)) (nlen o2))))))))))
 (defq 'before-nfs2
   '(pi s nlist (pi i nat (pi o1 nlist (pi j nat (pi o2 nlist (pi n2 nlist
      (pi g2 (paths bool (natgtb i (add j (nlen o2))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
      (pi hc1 (paths nlist (ltake (nlen o1) (ldrop i s)) o1)
        (paths nlist
          (splice s j (nlen o2) n2)
          (lapp (ltake j (ltake i s))
                (lapp n2 (lapp (ldrop (add j (nlen o2)) (ltake i s))
                              (lapp o1 (ldrop (add i (nlen o1)) s)))))))))))))))
   '(lam s (lam i (lam o1 (lam j (lam o2 (lam n2 (lam g2 (lam hb1 (lam hc1
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (let B (ltake j A)
      (let C (ldrop (add j (nlen o2)) A)
      (pathscomp0 nlist
        (lapp (ltake j s) (lapp n2 (ldrop (add j (nlen o2)) s)))
        (lapp B (lapp n2 (ldrop (add j (nlen o2)) s)))
        (lapp B (lapp n2 (lapp C (lapp o1 W))))
        (maponpaths nlist nlist (lam t (lapp t (lapp n2 (ldrop (add j (nlen o2)) s))))
          (ltake j s) B
          (pathscomp0 nlist (ltake j s) (ltake j (lapp A (lapp o1 W))) B
            (maponpaths nlist nlist (lam t (ltake j t)) s (lapp A (lapp o1 W))
              (seams s i o1 hb1 hc1))
            (ltakeprefix j A (lapp o1 W)
              (before-leh-ja s i o1 j o2 g2 hb1))))
        (maponpaths nlist nlist (lam t (lapp B (lapp n2 t)))
          (ldrop (add j (nlen o2)) s) (lapp C (lapp o1 W))
          (pathscomp0 nlist
            (ldrop (add j (nlen o2)) s)
            (ldrop (add j (nlen o2)) (lapp A (lapp o1 W)))
            (lapp C (lapp o1 W))
            (maponpaths nlist nlist (lam t (ldrop (add j (nlen o2)) t)) s (lapp A (lapp o1 W))
              (seams s i o1 hb1 hc1))
            (ldropprefix (add j (nlen o2)) A (lapp o1 W)
              (before-leh-jo s i o1 j o2 g2 hb1)))))))))))))))))))
 (defq 'before-clen
   '(pi s nlist (pi i nat (pi o1 nlist (pi j nat (pi o2 nlist
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
        (paths nat
          (nlen (ldrop (add j (nlen o2)) (ltake i s)))
          (natminus i (add j (nlen o2))))))))))
   '(lam s (lam i (lam o1 (lam j (lam o2 (lam hb1
      (pathscomp0 nat
        (nlen (ldrop (add j (nlen o2)) (ltake i s)))
        (natminus (nlen (ltake i s)) (add j (nlen o2)))
        (natminus i (add j (nlen o2)))
        (ldroplen (add j (nlen o2)) (ltake i s))
        (maponpaths nat nat (lam w (natminus w (add j (nlen o2)))) (nlen (ltake i s)) i
          (ltakelen i s
            (istransnatleh i (add i (nlen o1)) (nlen s) (natlehnplusnm i (nlen o1)) hb1)))))))))))
 (defq 'before-v1
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat (pi o2 nlist (pi n2 nlist
      (pi g2 (paths bool (natgtb i (add j (nlen o2))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
      (pi hc1 (paths nlist (ltake (nlen o1) (ldrop i s)) o1)
      (pi hc2 (paths nlist (ltake (nlen o2) (ldrop j (splice s i (nlen o1) n1))) o2)
        (paths nlist
          (ltake (natminus (add i (nlen n2)) (nlen o2)) (splice s j (nlen o2) n2))
          (lapp (ltake j (ltake i s))
                (lapp n2 (ldrop (add j (nlen o2)) (ltake i s))))))))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam o2 (lam n2 (lam g2 (lam hb1 (lam hc1 (lam hc2
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (let B (ltake j A)
      (let C (ldrop (add j (nlen o2)) A)
      (let cc (natminus i (add j (nlen o2)))
      (pathscomp0 nlist
        (ltake (natminus (add i (nlen n2)) (nlen o2)) (splice s j (nlen o2) n2))
        (ltake (add j (add (nlen n2) cc)) (splice s j (nlen o2) n2))
        (lapp B (lapp n2 C))
        (maponpaths nat nlist (lam w (ltake w (splice s j (nlen o2) n2)))
          (natminus (add i (nlen n2)) (nlen o2)) (add j (add (nlen n2) cc))
          (before-i2v i j o2 n2 g2))
        (pathscomp0 nlist
          (ltake (add j (add (nlen n2) cc)) (splice s j (nlen o2) n2))
          (ltake (add (nlen B) (add (nlen n2) (nlen C))) (splice s j (nlen o2) n2))
          (lapp B (lapp n2 C))
          (pathscomp0 nlist
            (ltake (add j (add (nlen n2) cc)) (splice s j (nlen o2) n2))
            (ltake (add (nlen B) (add (nlen n2) cc)) (splice s j (nlen o2) n2))
            (ltake (add (nlen B) (add (nlen n2) (nlen C))) (splice s j (nlen o2) n2))
            (maponpaths nat nlist (lam w (ltake (add w (add (nlen n2) cc)) (splice s j (nlen o2) n2)))
              j (nlen B)
              (pathsinv0 nat (nlen B) j
                (ltakelen j A (before-leh-ja s i o1 j o2 g2 hb1))))
            (maponpaths nat nlist (lam w (ltake (add (nlen B) (add (nlen n2) w)) (splice s j (nlen o2) n2)))
              cc (nlen C)
              (pathsinv0 nat (nlen C) cc
                (before-clen s i o1 j o2 hb1))))
          (pathscomp0 nlist
            (ltake (add (nlen B) (add (nlen n2) (nlen C))) (splice s j (nlen o2) n2))
            (ltake (add (nlen B) (add (nlen n2) (nlen C))) (lapp B (lapp n2 (lapp C (lapp o1 W)))))
            (lapp B (lapp n2 C))
            (maponpaths nlist nlist (lam t (ltake (add (nlen B) (add (nlen n2) (nlen C))) t))
              (splice s j (nlen o2) n2) (lapp B (lapp n2 (lapp C (lapp o1 W))))
              (before-nfs2 s i o1 j o2 n2 g2 hb1 hc1))
            (pathscomp0 nlist
              (ltake (add (nlen B) (add (nlen n2) (nlen C))) (lapp B (lapp n2 (lapp C (lapp o1 W)))))
              (lapp B (ltake (add (nlen n2) (nlen C)) (lapp n2 (lapp C (lapp o1 W)))))
              (lapp B (lapp n2 C))
              (ltakeplusapp B (add (nlen n2) (nlen C)) (lapp n2 (lapp C (lapp o1 W))))
              (pathscomp0 nlist
                (lapp B (ltake (add (nlen n2) (nlen C)) (lapp n2 (lapp C (lapp o1 W)))))
                (lapp B (lapp n2 (ltake (nlen C) (lapp C (lapp o1 W)))))
                (lapp B (lapp n2 C))
                (maponpaths nlist nlist (lam t (lapp B t))
                  (ltake (add (nlen n2) (nlen C)) (lapp n2 (lapp C (lapp o1 W))))
                  (lapp n2 (ltake (nlen C) (lapp C (lapp o1 W))))
                  (ltakeplusapp n2 (nlen C) (lapp C (lapp o1 W))))
                (maponpaths nlist nlist (lam t (lapp B (lapp n2 t)))
                  (ltake (nlen C) (lapp C (lapp o1 W))) C
                  (ltakelenapp C (lapp o1 W)))))))))))))))))))))))))
 (defq 'before-v2
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat (pi o2 nlist (pi n2 nlist
      (pi g2 (paths bool (natgtb i (add j (nlen o2))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
      (pi hc1 (paths nlist (ltake (nlen o1) (ldrop i s)) o1)
      (pi hc2 (paths nlist (ltake (nlen o2) (ldrop j (splice s i (nlen o1) n1))) o2)
        (paths nlist
          (ldrop (add (natminus (add i (nlen n2)) (nlen o2)) (nlen o1)) (splice s j (nlen o2) n2))
          (ldrop (add i (nlen o1)) s)))))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam o2 (lam n2 (lam g2 (lam hb1 (lam hc1 (lam hc2
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (let B (ltake j A)
      (let C (ldrop (add j (nlen o2)) A)
      (let cc (natminus i (add j (nlen o2)))
      (pathscomp0 nlist
        (ldrop (add (natminus (add i (nlen n2)) (nlen o2)) (nlen o1)) (splice s j (nlen o2) n2))
        (ldrop (add (nlen B) (add (nlen n2) (add (nlen C) (nlen o1)))) (splice s j (nlen o2) n2))
        W
        (maponpaths nat nlist (lam w (ldrop w (splice s j (nlen o2) n2)))
          (add (natminus (add i (nlen n2)) (nlen o2)) (nlen o1))
          (add (nlen B) (add (nlen n2) (add (nlen C) (nlen o1))))
          (pathscomp0 nat
            (add (natminus (add i (nlen n2)) (nlen o2)) (nlen o1))
            (add (add j (add (nlen n2) cc)) (nlen o1))
            (add (nlen B) (add (nlen n2) (add (nlen C) (nlen o1))))
            (maponpaths nat nat (lam w (add w (nlen o1)))
              (natminus (add i (nlen n2)) (nlen o2)) (add j (add (nlen n2) cc))
              (before-i2v i j o2 n2 g2))
            (pathscomp0 nat
              (add (add j (add (nlen n2) cc)) (nlen o1))
              (add j (add (add (nlen n2) cc) (nlen o1)))
              (add (nlen B) (add (nlen n2) (add (nlen C) (nlen o1))))
              (natplusassoc j (add (nlen n2) cc) (nlen o1))
              (pathscomp0 nat
                (add j (add (add (nlen n2) cc) (nlen o1)))
                (add j (add (nlen n2) (add cc (nlen o1))))
                (add (nlen B) (add (nlen n2) (add (nlen C) (nlen o1))))
                (maponpaths nat nat (lam w (add j w))
                  (add (add (nlen n2) cc) (nlen o1)) (add (nlen n2) (add cc (nlen o1)))
                  (natplusassoc (nlen n2) cc (nlen o1)))
                (pathscomp0 nat
                  (add j (add (nlen n2) (add cc (nlen o1))))
                  (add (nlen B) (add (nlen n2) (add cc (nlen o1))))
                  (add (nlen B) (add (nlen n2) (add (nlen C) (nlen o1))))
                  (maponpaths nat nat (lam w (add w (add (nlen n2) (add cc (nlen o1)))))
                    j (nlen B)
                    (pathsinv0 nat (nlen B) j
                      (ltakelen j A (before-leh-ja s i o1 j o2 g2 hb1))))
                  (maponpaths nat nat (lam w (add (nlen B) (add (nlen n2) (add w (nlen o1)))))
                    cc (nlen C)
                    (pathsinv0 nat (nlen C) cc
                      (before-clen s i o1 j o2 hb1))))))))
        (pathscomp0 nlist
          (ldrop (add (nlen B) (add (nlen n2) (add (nlen C) (nlen o1)))) (splice s j (nlen o2) n2))
          (ldrop (add (nlen B) (add (nlen n2) (add (nlen C) (nlen o1)))) (lapp B (lapp n2 (lapp C (lapp o1 W)))))
          W
          (maponpaths nlist nlist (lam t (ldrop (add (nlen B) (add (nlen n2) (add (nlen C) (nlen o1)))) t))
            (splice s j (nlen o2) n2) (lapp B (lapp n2 (lapp C (lapp o1 W))))
            (before-nfs2 s i o1 j o2 n2 g2 hb1 hc1))
          (pathscomp0 nlist
            (ldrop (add (nlen B) (add (nlen n2) (add (nlen C) (nlen o1)))) (lapp B (lapp n2 (lapp C (lapp o1 W)))))
            (ldrop (add (nlen n2) (add (nlen C) (nlen o1))) (lapp n2 (lapp C (lapp o1 W))))
            W
            (ldropplusapp B (add (nlen n2) (add (nlen C) (nlen o1))) (lapp n2 (lapp C (lapp o1 W))))
            (pathscomp0 nlist
              (ldrop (add (nlen n2) (add (nlen C) (nlen o1))) (lapp n2 (lapp C (lapp o1 W))))
              (ldrop (add (nlen C) (nlen o1)) (lapp C (lapp o1 W)))
              W
              (ldropplusapp n2 (add (nlen C) (nlen o1)) (lapp C (lapp o1 W)))
              (pathscomp0 nlist
                (ldrop (add (nlen C) (nlen o1)) (lapp C (lapp o1 W)))
                (ldrop (nlen o1) (lapp o1 W))
                W
                (ldropplusapp C (nlen o1) (lapp o1 W))
                (ldroplenapp o1 W)))))))))))))))))))))))
 (defq 'splice-before-comm
   '(pi s nlist (pi i nat (pi o1 nlist (pi n1 nlist (pi j nat (pi o2 nlist (pi n2 nlist
      (pi g2 (paths bool (natgtb i (add j (nlen o2))) true)
      (pi hb1 (paths bool (natgtb (add i (nlen o1)) (nlen s)) false)
      (pi hc1 (paths nlist (ltake (nlen o1) (ldrop i s)) o1)
      (pi hc2 (paths nlist (ltake (nlen o2) (ldrop j (splice s i (nlen o1) n1))) o2)
        (paths nlist
          (splice (splice s i (nlen o1) n1) j (nlen o2) n2)
          (splice (splice s j (nlen o2) n2) (natminus (add i (nlen n2)) (nlen o2)) (nlen o1) n1)))))))))))))
   '(lam s (lam i (lam o1 (lam n1 (lam j (lam o2 (lam n2 (lam g2 (lam hb1 (lam hc1 (lam hc2
      (let A (ltake i s)
      (let W (ldrop (add i (nlen o1)) s)
      (let B (ltake j A)
      (let C (ldrop (add j (nlen o2)) A)
      (pathscomp0 nlist
        (splice (splice s i (nlen o1) n1) j (nlen o2) n2)
        (lapp B (lapp n2 (lapp C (lapp n1 W))))
        (splice (splice s j (nlen o2) n2) (natminus (add i (nlen n2)) (nlen o2)) (nlen o1) n1)
        (pathscomp0 nlist
          (lapp (ltake j (lapp A (lapp n1 W))) (lapp n2 (ldrop (add j (nlen o2)) (lapp A (lapp n1 W)))))
          (lapp B (lapp n2 (ldrop (add j (nlen o2)) (lapp A (lapp n1 W)))))
          (lapp B (lapp n2 (lapp C (lapp n1 W))))
          (maponpaths nlist nlist
            (lam t (lapp t (lapp n2 (ldrop (add j (nlen o2)) (lapp A (lapp n1 W))))))
            (ltake j (lapp A (lapp n1 W))) B
            (ltakeprefix j A (lapp n1 W)
              (before-leh-ja s i o1 j o2 g2 hb1)))
          (maponpaths nlist nlist (lam t (lapp B (lapp n2 t)))
            (ldrop (add j (nlen o2)) (lapp A (lapp n1 W))) (lapp C (lapp n1 W))
            (ldropprefix (add j (nlen o2)) A (lapp n1 W)
              (before-leh-jo s i o1 j o2 g2 hb1))))
        (pathsinv0 nlist
          (splice (splice s j (nlen o2) n2) (natminus (add i (nlen n2)) (nlen o2)) (nlen o1) n1)
          (lapp B (lapp n2 (lapp C (lapp n1 W))))
          (pathscomp0 nlist
            (splice (splice s j (nlen o2) n2) (natminus (add i (nlen n2)) (nlen o2)) (nlen o1) n1)
            (lapp (lapp B (lapp n2 C)) (lapp n1 W))
            (lapp B (lapp n2 (lapp C (lapp n1 W))))
            (pathscomp0 nlist
              (lapp (ltake (natminus (add i (nlen n2)) (nlen o2)) (splice s j (nlen o2) n2))
                    (lapp n1 (ldrop (add (natminus (add i (nlen n2)) (nlen o2)) (nlen o1)) (splice s j (nlen o2) n2))))
              (lapp (lapp B (lapp n2 C))
                    (lapp n1 (ldrop (add (natminus (add i (nlen n2)) (nlen o2)) (nlen o1)) (splice s j (nlen o2) n2))))
              (lapp (lapp B (lapp n2 C)) (lapp n1 W))
              (maponpaths nlist nlist
                (lam t (lapp t (lapp n1 (ldrop (add (natminus (add i (nlen n2)) (nlen o2)) (nlen o1)) (splice s j (nlen o2) n2)))))
                (ltake (natminus (add i (nlen n2)) (nlen o2)) (splice s j (nlen o2) n2))
                (lapp B (lapp n2 C))
                (before-v1 s i o1 n1 j o2 n2 g2 hb1 hc1 hc2))
              (maponpaths nlist nlist (lam t (lapp (lapp B (lapp n2 C)) (lapp n1 t)))
                (ldrop (add (natminus (add i (nlen n2)) (nlen o2)) (nlen o1)) (splice s j (nlen o2) n2))
                W
                (before-v2 s i o1 n1 j o2 n2 g2 hb1 hc1 hc2)))
            (pathscomp0 nlist
              (lapp (lapp B (lapp n2 C)) (lapp n1 W))
              (lapp B (lapp (lapp n2 C) (lapp n1 W)))
              (lapp B (lapp n2 (lapp C (lapp n1 W))))
              (lappassoc B (lapp n2 C) (lapp n1 W))
              (maponpaths nlist nlist (lam t (lapp B t))
                (lapp (lapp n2 C) (lapp n1 W)) (lapp n2 (lapp C (lapp n1 W)))
                (lappassoc n2 C (lapp n1 W))))))))))))))))))))))))

; --- (L3a) tied to the primitive: a successful hcommute WITNESSES order-
; --- freedom, in the honest contexts (p belongs on s, q belongs after p).
; --- the convoy reads the branch off natgthorleh's evidence and hands the
; --- carried pair through the same maponpaths as L1; each branch closes by
; --- its splice lemma. then (L3b): states are DATA, so the frontier is one
; --- maponpaths -- the fold's tail rides the two-patch agreement ---
(assert
 (defn 'hvec '(pi n nat UU)
   '(lam n (nat_rect (lam q UU) unit (lam k (lam r (total2 x hunk r))) n)))
 (defn 'hlist 'UU '(total2 n nat (hvec n)))
 (defn 'hnil 'hlist '(tpair 0 tt))
 (defn 'hcons '(pi x hunk (pi l hlist hlist))
   '(lam x (lam l (tpair (succ (pr1 l)) (tpair x (pr2 l))))))
 (defn 'happl '(pi l hlist (pi s nlist nlist))
   '(lam l (lam s ((nat_rect (lam q (pi v (hvec q) (pi s2 nlist nlist)))
                     (lam v (lam s2 s2))
                     (lam k (lam IH (lam v (lam s2 (IH (pr2 v) (hap s2 (pr1 v)))))))
                     (pr1 l))
                   (pr2 l) s))))
 ; the fold COMPUTES: two hunks land left to right
 ((vof 0 '(happl (hcons (mkh 0 (ncons 1 nnil) (ncons 7 (ncons 8 nnil)))
                        (hcons (mkh 3 (ncons 3 nnil) (ncons 9 nnil)) hnil))
                 (ncons 1 (ncons 2 (ncons 3 (ncons 4 nnil))))))
  = (vof 0 '(ncons 7 (ncons 8 (ncons 2 (ncons 9 (ncons 4 nnil))))))))
(assert
 (defq 'hcommute-sound
   '(pi
     p
     hunk
     (pi
       q
       hunk
       (pi
         q2
         hunk
         (pi
           p2
           hunk
           (pi
             s
             nlist
             (pi
               h
               (paths (coprod hpair unit) (hcommute p q) (ii1 (tpair q2 p2)))
               (pi
                 hb1
                 (paths bool (natgtb (add (hi p) (nlen (ho p))) (nlen s)) false)
                 (pi
                   hc1
                   (paths nlist (ltake (nlen (ho p)) (ldrop (hi p) s)) (ho p))
                   (pi
                     hb2
                     (paths bool (natgtb (add (hi q) (nlen (ho q))) (nlen (hap s p))) false)
                     (pi
                       hc2
                       (paths nlist (ltake (nlen (ho q)) (ldrop (hi q) (hap s p))) (ho q))
                       (paths nlist (hap (hap s p) q) (hap (hap s q2) p2))))))))))))
   '(lam
     p
     (lam
       q
       (lam
         q2
         (lam
           p2
           (lam
             s
             (coprod_rect
               (lam
                 c
                 (pi
                   h
                   (paths
                     (coprod hpair unit)
                     (coprod_rect
                       (lam cc (coprod hpair unit))
                       (lam
                         g9
                         (ii1
                           (tpair
                             (mkh (natminus (add (hi q) (nlen (ho p))) (nlen (hn p))) (ho q) (hn q))
                             p)))
                       (lam
                         g9
                         (coprod_rect
                           (lam cc (coprod hpair unit))
                           (lam
                             g8
                             (ii1
                               (tpair
                                 q
                                 (mkh
                                   (natminus (add (hi p) (nlen (hn q))) (nlen (ho q)))
                                   (ho p)
                                   (hn p)))))
                           (lam g8 (ii2 tt))
                           (natgthorleh (hi p) (add (hi q) (nlen (ho q))))))
                       c)
                     (ii1 (tpair q2 p2)))
                   (pi
                     hb1
                     (paths bool (natgtb (add (hi p) (nlen (ho p))) (nlen s)) false)
                     (pi
                       hc1
                       (paths nlist (ltake (nlen (ho p)) (ldrop (hi p) s)) (ho p))
                       (pi
                         hb2
                         (paths bool (natgtb (add (hi q) (nlen (ho q))) (nlen (hap s p))) false)
                         (pi
                           hc2
                           (paths nlist (ltake (nlen (ho q)) (ldrop (hi q) (hap s p))) (ho q))
                           (paths nlist (hap (hap s p) q) (hap (hap s q2) p2))))))))
               (lam
                 g
                 (lam
                   h
                   (lam
                     hb1
                     (lam
                       hc1
                       (lam
                         hb2
                         (lam
                           hc2
                           (pathscomp0
                             nlist
                             (hap (hap s p) q)
                             (hap
                               (hap
                                 s
                                 (mkh
                                   (natminus (add (hi q) (nlen (ho p))) (nlen (hn p)))
                                   (ho q)
                                   (hn q)))
                               p)
                             (hap (hap s q2) p2)
                             (splice-after-comm
                               s
                               (hi p)
                               (ho p)
                               (hn p)
                               (hi q)
                               (ho q)
                               (hn q)
                               g
                               hb1
                               hc1
                               hb2
                               hc2)
                             (maponpaths
                               (coprod hpair unit)
                               nlist
                               (lam
                                 cz
                                 (coprod_rect
                                   (lam cy nlist)
                                   (lam z (hap (hap s (pr1 z)) (pr2 z)))
                                   (lam uz nnil)
                                   cz))
                               (ii1
                                 (tpair
                                   (mkh
                                     (natminus (add (hi q) (nlen (ho p))) (nlen (hn p)))
                                     (ho q)
                                     (hn q))
                                   p))
                               (ii1 (tpair q2 p2))
                               h))))))))
               (lam
                 g
                 (lam
                   h
                   ((coprod_rect
                       (lam
                         c2
                         (pi
                           h2
                           (paths
                             (coprod hpair unit)
                             (coprod_rect
                               (lam cc (coprod hpair unit))
                               (lam
                                 g8
                                 (ii1
                                   (tpair
                                     q
                                     (mkh
                                       (natminus (add (hi p) (nlen (hn q))) (nlen (ho q)))
                                       (ho p)
                                       (hn p)))))
                               (lam g8 (ii2 tt))
                               c2)
                             (ii1 (tpair q2 p2)))
                           (pi
                             hb1
                             (paths bool (natgtb (add (hi p) (nlen (ho p))) (nlen s)) false)
                             (pi
                               hc1
                               (paths nlist (ltake (nlen (ho p)) (ldrop (hi p) s)) (ho p))
                               (pi
                                 hb2
                                 (paths
                                   bool
                                   (natgtb (add (hi q) (nlen (ho q))) (nlen (hap s p)))
                                   false)
                                 (pi
                                   hc2
                                   (paths
                                     nlist
                                     (ltake (nlen (ho q)) (ldrop (hi q) (hap s p)))
                                     (ho q))
                                   (paths nlist (hap (hap s p) q) (hap (hap s q2) p2))))))))
                       (lam
                         g2
                         (lam
                           h2
                           (lam
                             hb1
                             (lam
                               hc1
                               (lam
                                 hb2
                                 (lam
                                   hc2
                                   (pathscomp0
                                     nlist
                                     (hap (hap s p) q)
                                     (hap
                                       (hap s q)
                                       (mkh
                                         (natminus (add (hi p) (nlen (hn q))) (nlen (ho q)))
                                         (ho p)
                                         (hn p)))
                                     (hap (hap s q2) p2)
                                     (splice-before-comm
                                       s
                                       (hi p)
                                       (ho p)
                                       (hn p)
                                       (hi q)
                                       (ho q)
                                       (hn q)
                                       g2
                                       hb1
                                       hc1
                                       hc2)
                                     (maponpaths
                                       (coprod hpair unit)
                                       nlist
                                       (lam
                                         cz
                                         (coprod_rect
                                           (lam cy nlist)
                                           (lam z (hap (hap s (pr1 z)) (pr2 z)))
                                           (lam uz nnil)
                                           cz))
                                       (ii1
                                         (tpair
                                           q
                                           (mkh
                                             (natminus (add (hi p) (nlen (hn q))) (nlen (ho q)))
                                             (ho p)
                                             (hn p))))
                                       (ii1 (tpair q2 p2))
                                       h2))))))))
                       (lam
                         g2
                         (lam
                           h2
                           (fromempty
                             (pi
                               hb1
                               (paths bool (natgtb (add (hi p) (nlen (ho p))) (nlen s)) false)
                               (pi
                                 hc1
                                 (paths nlist (ltake (nlen (ho p)) (ldrop (hi p) s)) (ho p))
                                 (pi
                                   hb2
                                   (paths
                                     bool
                                     (natgtb (add (hi q) (nlen (ho q))) (nlen (hap s p)))
                                     false)
                                   (pi
                                     hc2
                                     (paths
                                       nlist
                                       (ltake (nlen (ho q)) (ldrop (hi q) (hap s p)))
                                       (ho q))
                                     (paths nlist (hap (hap s p) q) (hap (hap s q2) p2))))))
                             (transportf
                               (coprod hpair unit)
                               hcmside
                               (ii2 tt)
                               (ii1 (tpair q2 p2))
                               h2
                               tt))))
                       (natgthorleh (hi p) (add (hi q) (nlen (ho q)))))
                     h)))
               (natgthorleh (hi q) (add (hi p) (nlen (hn p))))))))))))
(assert
 (defq 'hfold-swap
   '(pi p hunk (pi q hunk (pi q2 hunk (pi p2 hunk (pi s nlist (pi post hlist
      (pi h (paths (coprod hpair unit) (hcommute p q) (ii1 (tpair q2 p2)))
      (pi hb1 (paths bool (natgtb (add (hi p) (nlen (ho p))) (nlen s)) false)
      (pi hc1 (paths nlist (ltake (nlen (ho p)) (ldrop (hi p) s)) (ho p))
      (pi hb2 (paths bool (natgtb (add (hi q) (nlen (ho q))) (nlen (hap s p))) false)
      (pi hc2 (paths nlist (ltake (nlen (ho q)) (ldrop (hi q) (hap s p))) (ho q))
        (paths nlist
          (happl (hcons p (hcons q post)) s)
          (happl (hcons q2 (hcons p2 post)) s)))))))))))))
   '(lam p (lam q (lam q2 (lam p2 (lam s (lam post (lam h (lam hb1 (lam hc1 (lam hb2 (lam hc2
      (maponpaths nlist nlist (lam t (happl post t))
        (hap (hap s p) q) (hap (hap s q2) p2)
        (hcommute-sound p q q2 p2 s h hb1 hc1 hb2 hc2)))))))))))))))
(:
 ; --- the L3a witness COMPUTES: the after-pair agrees in both orders ---
 (heq a b) (? (&& (atom? a) (atom? b)) (id? a b)
              (|| (atom? a) (atom? b)) 0
              (&& (heq (cap a) (cap b)) (heq (cup a) (cup b))))
 s0 '(ncons 1 (ncons 2 (ncons 3 (ncons 4 nnil))))
 p0 '(mkh 0 (ncons 1 nnil) (ncons 7 (ncons 8 nnil)))
 q0 '(mkh 3 (ncons 3 nnil) (ncons 9 nnil))
 q0p '(mkh 2 (ncons 3 nnil) (ncons 9 nnil))
 _ (assert
    ((vof 0 (L 'hap (L 'hap s0 p0) q0)) = (vof 0 (L 'hap (L 'hap s0 q0p) p0)))
    ((vof 0 (L 'hcommute p0 q0)) = (vof 0 (L 'ii1 (L 'tpair q0p p0)))))
 0)

; ============================================================================
; the ELEMENT TREE: every nat IS a rose tree. labels are nats and kid lists
; are finite, so trees are counted by the cantor pairing -- a node is
; (npair label kids-code), a kid list codes by folding npair under succ, and
; the ZERO-labelled leaf is 0 itself. etree = nat buys the whole nat kit at
; tree grain for free (isdeceq, isaset, natgtb order for canonical forms),
; kids come back as a plain nlist (the list kit rides), and the swal/clash/
; metavariable slices get their element grain. the door: doc/proto/patch.l's
; rose-tree walks, queued behind this type.
; ============================================================================
; --- the cantor pairing. npair climbs the triangle; unpair WALKS the
; --- diagonal (a duo-valued nat_rect: at (0 b) jump to (succ b, 0), else
; --- step (npred a, succ b) -- una/unb the two step components, niszero/
; --- npred the case machinery, so every branch is definitional). ---
(assert
 (defn 'tri
   '(pi n nat nat)
   '(lam n (nat_rect (lam q nat) 0 (lam k (lam r (add (succ k) r))) n)))
 (defn 'npair
   '(pi a nat (pi b nat nat))
   '(lam a (lam b (add (tri (add a b)) b))))
 (defn 'duo
   'UU
   '(total2 a nat nat))
 (defn 'una
   '(pi x nat (pi y nat nat))
   '(lam x (lam y (bool_rect (lam c nat) (succ y) (npred x) (niszero x)))))
 (defn 'unb
   '(pi x nat (pi y nat nat))
   '(lam x (lam y (bool_rect (lam c nat) 0 (succ y) (niszero x)))))
 (defn 'unpair
   '(pi n nat duo)
   '(lam n
      (nat_rect (lam q duo) (tpair 0 0)
        (lam k (lam u (tpair (una (pr1 u) (pr2 u)) (unb (pr1 u) (pr2 u)))))
        n)))
 (defn 'upa
   '(pi n nat nat)
   '(lam n (pr1 (unpair n))))
 (defn 'upb
   '(pi n nat nat)
   '(lam n (pr2 (unpair n))))
 ; the pairing computes: the diagonal walk inverts the triangle climb
 (id? (vof 0 '0) (vof 0 '(npair 0 0)))
 (id? (vof 0 '1) (vof 0 '(npair 1 0)))
 (id? (vof 0 '2) (vof 0 '(npair 0 1)))
 (id? (vof 0 '4) (vof 0 '(upa (npair 4 2))))
 (id? (vof 0 '2) (vof 0 '(upb (npair 4 2)))))

; --- the walk inverts the climb, one diagonal step at a time. npairhead:
; --- the (0 b) corner jumps to the next diagonal's head. npairdiag: an
; --- interior step slides down it. npairstep fuses them through una/unb
; --- (each branch definitional), npairunpair closes by one induction. ---
(assert
 (defq 'npairhead
   '(pi b nat (paths nat (npair (succ b) 0) (succ (npair 0 b))))
   '(lam b
      (maponpaths nat nat (lam w (succ w)) (add (add (add b 0) (tri (add b 0))) 0)
        (add (tri b) b)
        (pathscomp0 nat (add (add (add b 0) (tri (add b 0))) 0) (add (add b 0) (tri (add b 0)))
          (add (tri b) b)
          (natplusr0 (add (add b 0) (tri (add b 0))))
          (pathscomp0 nat (add (add b 0) (tri (add b 0))) (add b (tri b)) (add (tri b) b)
            (maponpaths nat nat (lam w (add w (tri w))) (add b 0) b (natplusr0 b))
            (natpluscomm b (tri b)))))))
 (defq 'npairdiag
   '(pi a nat (pi b nat (paths nat (npair a (succ b)) (succ (npair (succ a) b)))))
   '(lam a
      (lam b
        (pathscomp0 nat (npair a (succ b)) (add (tri (add (succ a) b)) (succ b))
          (succ (npair (succ a) b))
          (maponpaths nat nat (lam w (add (tri w) (succ b))) (add a (succ b)) (add (succ a) b)
            (natplusnsm a b))
          (maponpaths nat nat (lam w (succ w)) (add (add (add a b) (tri (add a b))) (succ b))
            (add (succ (add (add a b) (tri (add a b)))) b)
            (natplusnsm (add (add a b) (tri (add a b))) b))))))
 (defq 'npairstep
   '(pi x nat (pi y nat (paths nat (npair (una x y) (unb x y)) (succ (npair x y)))))
   '(lam x
      (lam y
        (nat_rect (lam q (paths nat (npair (una q y) (unb q y)) (succ (npair q y))))
          (npairhead y)
          (lam k (lam IH (npairdiag k y)))
          x))))
 (defq 'npairunpair
   '(pi n nat (paths nat (npair (upa n) (upb n)) n))
   '(lam n
      (nat_rect (lam q (paths nat (npair (upa q) (upb q)) q)) (idpath 0)
        (lam k
          (lam IH
            (pathscomp0 nat (npair (una (upa k) (upb k)) (unb (upa k) (upb k)))
              (succ (npair (upa k) (upb k)))
              (succ k)
              (npairstep (upa k) (upb k))
              (maponpaths nat nat (lam w (succ w)) (npair (upa k) (upb k)) k IH))))
        n)))
 ; the round trip computes both ways on closed nats
 (id? (vof 0 '9) (vof 0 '(npair (upa 9) (upb 9)))))

; --- the beta ladder: unpair undoes npair. the head/diag steps re-read the
; --- walk one rung down through the una/unb components (each close is
; --- definitional -- una 0 y is succ y, una (succ a) y is a); unpairbeta
; --- rides the double induction (diagonal d outside, the walk down it
; --- inside), the equation convoys carrying a+b = d exactly like
; --- isdeceqnat's; both projections travel together in one total2. ---
(assert
 (defq 'unpbheadu
   '(pi d nat
      (pi ha (paths nat (upa (npair 0 d)) 0)
        (pi hb (paths nat (upb (npair 0 d)) d) (paths nat (upa (npair (succ d) 0)) (succ d)))))
   '(lam d
      (lam ha
        (lam hb
          (pathscomp0 nat (upa (npair (succ d) 0)) (upa (succ (npair 0 d))) (succ d)
            (maponpaths nat nat (lam w (upa w)) (npair (succ d) 0) (succ (npair 0 d))
              (npairhead d))
            (pathscomp0 nat (una (upa (npair 0 d)) (upb (npair 0 d))) (una 0 (upb (npair 0 d)))
              (succ d)
              (maponpaths nat nat (lam w (una w (upb (npair 0 d)))) (upa (npair 0 d)) 0 ha)
              (maponpaths nat nat (lam w (una 0 w)) (upb (npair 0 d)) d hb)))))))
 (defq 'unpbheadb
   '(pi d nat (pi ha (paths nat (upa (npair 0 d)) 0) (paths nat (upb (npair (succ d) 0)) 0)))
   '(lam d
      (lam ha
        (pathscomp0 nat (upb (npair (succ d) 0)) (upb (succ (npair 0 d))) 0
          (maponpaths nat nat (lam w (upb w)) (npair (succ d) 0) (succ (npair 0 d))
            (npairhead d))
          (maponpaths nat nat (lam w (unb w (upb (npair 0 d)))) (upa (npair 0 d)) 0 ha)))))
 (defq 'unpbdiagu
   '(pi a nat
      (pi b nat
        (pi ha (paths nat (upa (npair (succ a) b)) (succ a))
          (paths nat (upa (npair a (succ b))) a))))
   '(lam a
      (lam b
        (lam ha
          (pathscomp0 nat (upa (npair a (succ b))) (upa (succ (npair (succ a) b))) a
            (maponpaths nat nat (lam w (upa w)) (npair a (succ b)) (succ (npair (succ a) b))
              (npairdiag a b))
            (maponpaths nat nat (lam w (una w (upb (npair (succ a) b))))
              (upa (npair (succ a) b))
              (succ a)
              ha))))))
 (defq 'unpbdiagb
   '(pi a nat
      (pi b nat
        (pi ha (paths nat (upa (npair (succ a) b)) (succ a))
          (pi hb (paths nat (upb (npair (succ a) b)) b)
            (paths nat (upb (npair a (succ b))) (succ b))))))
   '(lam a
      (lam b
        (lam ha
          (lam hb
            (pathscomp0 nat (upb (npair a (succ b))) (upb (succ (npair (succ a) b))) (succ b)
              (maponpaths nat nat (lam w (upb w)) (npair a (succ b)) (succ (npair (succ a) b))
                (npairdiag a b))
              (pathscomp0 nat (unb (upa (npair (succ a) b)) (upb (npair (succ a) b)))
                (succ (upb (npair (succ a) b)))
                (succ b)
                (maponpaths nat nat (lam w (unb w (upb (npair (succ a) b))))
                  (upa (npair (succ a) b))
                  (succ a)
                  ha)
                (maponpaths nat nat (lam w (succ w)) (upb (npair (succ a) b)) b hb))))))))
 (defq 'unpairbeta
   '(pi d nat
      (pi a nat
        (pi b nat
          (pi e (paths nat (add a b) d)
            (total2 zz (paths nat (upa (npair a b)) a) (paths nat (upb (npair a b)) b))))))
   '(lam d
      (nat_rect
        (lam dq
          (pi a nat
            (pi b nat
              (pi e (paths nat (add a b) dq)
                (total2 zz (paths nat (upa (npair a b)) a) (paths nat (upb (npair a b)) b))))))
        (lam a
          (nat_rect
            (lam aq
              (pi b nat
                (pi e (paths nat (add aq b) 0)
                  (total2 zz (paths nat (upa (npair aq b)) aq) (paths nat (upb (npair aq b)) b)))))
            (lam b
              (lam e
                (transportf nat
                  (lam w
                    (total2 zz (paths nat (upa (npair 0 w)) 0) (paths nat (upb (npair 0 w)) w)))
                  0
                  b
                  (pathsinv0 nat b 0 e)
                  (tpair (idpath 0) (idpath 0)))))
            (lam k
              (lam IH
                (lam b
                  (lam e
                    (fromempty
                      (total2 zz (paths nat (upa (npair (succ k) b)) (succ k))
                        (paths nat (upb (npair (succ k) b)) b))
                      (negpathssx0 (add k b) e))))))
            a))
        (lam d2
          (lam IHd
            (lam a
              (lam b
                (lam e
                  ((nat_rect
                     (lam bq
                       (pi a2 nat
                         (pi e2 (paths nat (add a2 bq) (succ d2))
                           (total2 zz (paths nat (upa (npair a2 bq)) a2)
                             (paths nat (upb (npair a2 bq)) bq)))))
                     (lam a2
                       (lam e2
                         (transportf nat
                           (lam w
                             (total2 zz (paths nat (upa (npair w 0)) w)
                               (paths nat (upb (npair w 0)) 0)))
                           (succ d2)
                           a2
                           (pathsinv0 nat a2 (succ d2)
                             (pathscomp0 nat a2 (add a2 0) (succ d2)
                               (pathsinv0 nat (add a2 0) a2 (natplusr0 a2))
                               e2))
                           (tpair
                             (unpbheadu d2 (pr1 (IHd 0 d2 (idpath d2)))
                               (pr2 (IHd 0 d2 (idpath d2))))
                             (unpbheadb d2 (pr1 (IHd 0 d2 (idpath d2))))))))
                     (lam b2
                       (lam IHW
                         (lam a2
                           (lam e2
                             (tpair
                               (unpbdiagu a2 b2
                                 (pr1
                                   (IHW (succ a2)
                                     (pathscomp0 nat (add (succ a2) b2) (add a2 (succ b2))
                                       (succ d2)
                                       (pathsinv0 nat (add a2 (succ b2)) (add (succ a2) b2)
                                         (natplusnsm a2 b2))
                                       e2))))
                               (unpbdiagb a2 b2
                                 (pr1
                                   (IHW (succ a2)
                                     (pathscomp0 nat (add (succ a2) b2) (add a2 (succ b2))
                                       (succ d2)
                                       (pathsinv0 nat (add a2 (succ b2)) (add (succ a2) b2)
                                         (natplusnsm a2 b2))
                                       e2)))
                                 (pr2
                                   (IHW (succ a2)
                                     (pathscomp0 nat (add (succ a2) b2) (add a2 (succ b2))
                                       (succ d2)
                                       (pathsinv0 nat (add a2 (succ b2)) (add (succ a2) b2)
                                         (natplusnsm a2 b2))
                                       e2)))))))))
                     b)
                    a
                    e))))))
        d)))
 (defq 'upabeta
   '(pi a nat (pi b nat (paths nat (upa (npair a b)) a)))
   '(lam a (lam b (pr1 (unpairbeta (add a b) a b (idpath (add a b)))))))
 (defq 'upbbeta
   '(pi a nat (pi b nat (paths nat (upb (npair a b)) b)))
   '(lam a (lam b (pr2 (unpairbeta (add a b) a b (idpath (add a b)))))))
 (defq 'npairgeb
   '(pi a nat (pi b nat (paths bool (natgtb b (npair a b)) false)))
   '(lam a (lam b (natlehmplusnm b (tri (add a b))))))
 (defq 'upble
   '(pi n nat (paths bool (natgtb (upb n) n) false))
   '(lam n
      (transportf nat (lam w (paths bool (natgtb (upb n) w) false)) (npair (upa n) (upb n)) n
        (npairunpair n)
        (npairgeb (upa n) (upb n))))))

; --- a kid list as one nat: nil is 0, cons is succ of the pair, and ldec
; --- walks it back on FUEL -- the code bounds its own decode (a kid's code
; --- rides inside the pair, so upb never grows: upble + istransnatleh feed
; --- the guard convoys), the house fuel pattern at nateqb's one-call-per-
; --- level shape. round trips sealed both ways. ---
(assert
 (defn 'lcode
   '(pi l nlist nat)
   '(lam l
      ((nat_rect (lam q (pi v (nvec q) nat)) (lam v 0)
         (lam k (lam IH (lam v (succ (npair (pr1 v) (IH (pr2 v)))))))
         (pr1 l))
        (pr2 l))))
 (defn 'ldec
   '(pi f nat (pi m nat nlist))
   '(lam f
      (nat_rect (lam q (pi m nat nlist)) (lam m nnil)
        (lam f2
          (lam IH
            (lam m
              (bool_rect (lam c nlist) nnil (ncons (upa (npred m)) (IH (upb (npred m))))
                (niszero m)))))
        f)))
 (defq 'ldeccode
   '(pi l nlist
      (pi f nat
        (pi h (paths bool (natgtb (lcode l) f) false) (paths nlist (ldec f (lcode l)) l))))
   '(lam l
      ((nat_rect
         (lam q
           (pi v (nvec q)
             (pi f nat
               (pi h (paths bool (natgtb (lcode (tpair q v)) f) false)
                 (paths nlist (ldec f (lcode (tpair q v))) (tpair q v))))))
         (lam v
           (lam f
             (nat_rect
               (lam fq
                 (pi h (paths bool (natgtb (lcode (tpair 0 v)) fq) false)
                   (paths nlist (ldec fq (lcode (tpair 0 v))) (tpair 0 v))))
               (lam h (pathsinv0 nlist (tpair 0 v) nnil (lnil0 v)))
               (lam f2 (lam IHf (lam h (pathsinv0 nlist (tpair 0 v) nnil (lnil0 v)))))
               f)))
         (lam k
           (lam IH
             (lam v
               (lam f
                 (nat_rect
                   (lam fq
                     (pi h (paths bool (natgtb (lcode (tpair (succ k) v)) fq) false)
                       (paths nlist (ldec fq (lcode (tpair (succ k) v))) (tpair (succ k) v))))
                   (lam h
                     (fromempty
                       (paths nlist (ldec 0 (lcode (tpair (succ k) v))) (tpair (succ k) v))
                       (nopathstruetofalse h)))
                   (lam f2
                     (lam IHf
                       (lam h
                         (pathscomp0 nlist
                           (ncons (upa (npair (pr1 v) (lcode (tpair k (pr2 v)))))
                             (ldec f2 (upb (npair (pr1 v) (lcode (tpair k (pr2 v)))))))
                           (ncons (pr1 v)
                             (ldec f2 (upb (npair (pr1 v) (lcode (tpair k (pr2 v)))))))
                           (tpair (succ k) v)
                           (maponpaths nat nlist
                             (lam w
                               (ncons w
                                 (ldec f2 (upb (npair (pr1 v) (lcode (tpair k (pr2 v))))))))
                             (upa (npair (pr1 v) (lcode (tpair k (pr2 v)))))
                             (pr1 v)
                             (upabeta (pr1 v) (lcode (tpair k (pr2 v)))))
                           (pathscomp0 nlist
                             (ncons (pr1 v)
                               (ldec f2 (upb (npair (pr1 v) (lcode (tpair k (pr2 v)))))))
                             (ncons (pr1 v) (ldec f2 (lcode (tpair k (pr2 v)))))
                             (tpair (succ k) v)
                             (maponpaths nat nlist (lam w (ncons (pr1 v) (ldec f2 w)))
                               (upb (npair (pr1 v) (lcode (tpair k (pr2 v)))))
                               (lcode (tpair k (pr2 v)))
                               (upbbeta (pr1 v) (lcode (tpair k (pr2 v)))))
                             (maponpaths nlist nlist (lam w (ncons (pr1 v) w))
                               (ldec f2 (lcode (tpair k (pr2 v))))
                               (tpair k (pr2 v))
                               (IH (pr2 v) f2
                                 (istransnatleh (lcode (tpair k (pr2 v)))
                                   (npair (pr1 v) (lcode (tpair k (pr2 v))))
                                   f2
                                   (npairgeb (pr1 v) (lcode (tpair k (pr2 v))))
                                   h))))))))
                   f)))))
         (pr1 l))
        (pr2 l))))
 (defq 'lcodedec
   '(pi f nat (pi m nat (pi h (paths bool (natgtb m f) false) (paths nat (lcode (ldec f m)) m))))
   '(lam f
      (nat_rect
        (lam fq
          (pi m nat (pi h (paths bool (natgtb m fq) false) (paths nat (lcode (ldec fq m)) m))))
        (lam m
          (nat_rect
            (lam mq (pi h (paths bool (natgtb mq 0) false) (paths nat (lcode (ldec 0 mq)) mq)))
            (lam h (idpath 0))
            (lam m2
              (lam IHm
                (lam h
                  (fromempty (paths nat (lcode (ldec 0 (succ m2))) (succ m2))
                    (nopathstruetofalse h)))))
            m))
        (lam f2
          (lam IHf
            (lam m
              (nat_rect
                (lam mq
                  (pi h (paths bool (natgtb mq (succ f2)) false)
                    (paths nat (lcode (ldec (succ f2) mq)) mq)))
                (lam h (idpath 0))
                (lam m2
                  (lam IHm
                    (lam h
                      (maponpaths nat nat (lam w (succ w))
                        (npair (upa m2) (lcode (ldec f2 (upb m2))))
                        m2
                        (pathscomp0 nat (npair (upa m2) (lcode (ldec f2 (upb m2))))
                          (npair (upa m2) (upb m2))
                          m2
                          (maponpaths nat nat (lam w (npair (upa m2) w))
                            (lcode (ldec f2 (upb m2)))
                            (upb m2)
                            (IHf (upb m2) (istransnatleh (upb m2) m2 f2 (upble m2) h)))
                          (npairunpair m2))))))
                m))))
        f)))
 ; the code and its walk agree on a closed list
 (id? (vof 0 '(lcode (ncons 1 (ncons 2 nnil)))) (vof 0 '20))
 ((vof 0 '(ncons 1 (ncons 2 nnil))) = (vof 0 '(ldec 20 20))))

; --- the tree itself. enode pairs a label with its kids' code; elabel and
; --- ekids read a node back (ekids fuelled by the code it decodes). beta
; --- both ways and eta close from the two round trips, and nat's decidable
; --- equality IS the tree's -- the swal guards' Aeq, for free. ---
(assert
 (defn 'etree
   'UU
   'nat)
 (defn 'enode
   '(pi l nat (pi ks nlist etree))
   '(lam l (lam ks (npair l (lcode ks)))))
 (defn 'elabel
   '(pi t etree nat)
   '(lam t (upa t)))
 (defn 'ekids
   '(pi t etree nlist)
   '(lam t (ldec (upb t) (upb t))))
 (defq 'elabelbeta
   '(pi l nat (pi ks nlist (paths nat (elabel (enode l ks)) l)))
   '(lam l (lam ks (upabeta l (lcode ks)))))
 (defq 'ekidsbeta
   '(pi l nat (pi ks nlist (paths nlist (ekids (enode l ks)) ks)))
   '(lam l
      (lam ks
        (pathscomp0 nlist (ldec (upb (npair l (lcode ks))) (upb (npair l (lcode ks))))
          (ldec (lcode ks) (lcode ks))
          ks
          (maponpaths nat nlist (lam w (ldec w w)) (upb (npair l (lcode ks))) (lcode ks)
            (upbbeta l (lcode ks)))
          (ldeccode ks (lcode ks) (isreflnatleh (lcode ks)))))))
 (defq 'etreeeta
   '(pi t etree (paths etree (enode (elabel t) (ekids t)) t))
   '(lam t
      (pathscomp0 nat (npair (upa t) (lcode (ldec (upb t) (upb t)))) (npair (upa t) (upb t)) t
        (maponpaths nat nat (lam w (npair (upa t) w)) (lcode (ldec (upb t) (upb t))) (upb t)
          (lcodedec (upb t) (upb t) (isreflnatleh (upb t))))
        (npairunpair t))))
 (defn 'isdeceqetree
   '(pi x etree (pi y etree (coprod (paths etree x y) (pi e (paths etree x y) empty))))
   'isdeceqnat)
 ; the tree computes: a leaf is its label's triangle, the zero leaf IS 0,
 ; and eta reads ANY nat as a node -- 5 is (enode 0 (ncons 1 nnil))
 (id? (vof 0 '28) (vof 0 '(enode 7 nnil)))
 (id? (vof 0 '0) (vof 0 '(enode 0 nnil)))
 (id? (vof 0 '2) (vof 0 '(enode 0 (ncons (enode 0 nnil) nnil))))
 (id? (vof 0 '5) (vof 0 '(elabel (enode 5 (ncons 1 (ncons 2 nnil))))))
 ((vof 0 '(ncons 1 (ncons 2 nnil))) = (vof 0 '(ekids (enode 5 (ncons 1 (ncons 2 nnil))))))
 (id? (vof 0 '0) (vof 0 '(elabel 5)))
 ((vof 0 '(ncons 1 nnil)) = (vof 0 '(ekids 5)))
 (id? (vof 0 '5) (vof 0 '(enode (elabel 5) (ekids 5)))))

