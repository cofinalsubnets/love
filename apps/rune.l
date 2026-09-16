; rune -- the symbolic algebra engine (a wee CAS): exact multivariate polynomials over the
; integers, plus univariate arithmetic in Q[x]/(m) riding the rational coin. pure love, no
; nifs; the gate is test/host/rune.l, whose corpus verifies the 2026 jacobian-conjecture
; disproof whole (det J symbolically, the collision certificates in exact arithmetic).
;
; a poly is a list of monomials, each (c e0 e1 ..) -- a coefficient (a star: an integer or a
; ratio coin, so the ring is Q[x..] with Z[x..] sitting inside it structurally) then one
; exponent per variable. keys lex-descending, no zero coefficients, all polys in one
; expression sharing an arity; the zero polynomial is (), the empty sum being nothing.
;
; no brackets here: the runtime supplies the layer. `(borrow "apps/rune.l")` loads this path
; as one fresh layer and the splice serves the bare names; `(borrow 'rune)` rides a baked
; registration; `(cite 'rune 'deriv)` takes one member through the accessor.

; --- the polynomial ring ---------------------------------------------------
(: (mco m) <m
   (mkey m) >m
   ; an integer-valued coin demotes to its numerator, so = stays structural across Z and Q
   ; and the zero-drop is the plain (c = 0). never ! a coefficient: a red one nets nothing
   (cnorm c) (!(coin? c) ? c (: p (load c) (1 = <>p ? <p c)))
   (keylt a b) (? (0 = #a) 0 (<a < <b) 1 (<b < <a) 0 (keylt >a >b))   ; the lex key order
   (padd p1 p2) (? (0 = #p1) p2
                   (0 = #p2) p1
                   (: mp <p1 mq <p2
                      (? (mkey mp = mkey mq)
                         (: c (cnorm (mco mp + mco mq)) r (padd >p1 >p2)
                            (c = 0 ? r ((c . mkey mp) . r)))
                         (keylt (mkey mq) (mkey mp))
                         (mp . padd >p1 p2)
                         (mq . padd p1 >p2))))
   (pneg p) (map (mm \ -(mco mm) . mkey mm) p)
   (psub p1 p2) (padd p1 (pneg p2))
   (zadd a b) (#a ? (<a + <b . zadd >a >b))
   (mmul a b) (cnorm (mco a * mco b) . zadd (mkey a) (mkey b))
   (mrow a p2) (#p2 ? (mmul a <p2 . mrow a >p2))
   (pmul p1 p2) (#p1 @ 0 () (padd (mrow <p1 p2) (pmul >p1 p2)))
   (setn l n x) (n @ 0 (x . >l) (<l . setn >l (n - 1) x))
   (deln l n) (n @ 0 >l (<l . deln >l (n - 1)))
   (zeros n) (n @ 0 () (0 . zeros (n - 1)))
   (pconst n c) (: k (cnorm c) (? (k = 0) () [(k . zeros n)]))
   (pvar n k) [(1 . setn (zeros n) k 1)])

; --- the derivative and the determinant ------------------------------------
; pd goes monomial by monomial: padd of singletons keeps the key order, so no re-sort
(: (pd p v) (#p ?  (: mm <p e (mkey mm v) r (pd >p v)
                    (e = 0 ? r (padd [(cnorm (mco mm * e) . setn (mkey mm) v (e - 1))] r))))
   (pdet rows) (#rows @ 1 <<rows (:- (go <rows 0 1)   ; along the first row, minors by deln
                (go r0 j sg) (#r0 ?  (: t (pmul <r0 (pdet (map (r \ deln r j) >rows)))
                                      (padd (sg = 1 ? t (pneg t)) (go >r0 (j + 1) -sg)))))))

; --- gcd & squarefree factorization: euclid in Q[x], answers monic ----------
; univariate, arity-1 keys. pgcd and psff load, so raw monomial lists and poly coins alike
; arrive; answers are raw.
(: (cinv c) (coin? c ? (-1 c) (1 /// c))     ; the exact reciprocal of a coefficient star
   (pdeg p) <(mkey <p)
   (pmonic p) (#p @ 0 () (cinv (mco <p) @ v (map (m \ cnorm (v * mco m) . mkey m) p)))
   ; the lead quotient monomial: riding pmul/psub makes the cancellation the ring's own, exact
   (pquo a b) [(cnorm (mco <a * cinv (mco <b)) . [(pdeg a - pdeg b)])]
   (pmod a b) (? (0 = #a) ()
                 (pdeg a < pdeg b) a
                 (pmod (psub a (pmul (pquo a b) b)) b))
   (pquot a b) (? (0 = #a) ()
                  (pdeg a < pdeg b) ()
                  (: t (pquo a b)
                     (padd t (pquot (psub a (pmul t b)) b))))
   (pgcd a b) (: x (load a) y (load b)       ; monic is unique in Q[x]: the units divide out
               (0 = #y ? (pmonic x) (pgcd y (pmod x y))))
   ; yun: the ascending (a1 a2 ..) with monic p = a1^1 * a2^2 * .., empty slots holding the
   ; 1 poly. a constant has no factors
   (psff p) (: f (pmonic (load p))
               (go w y) (0 != pdeg w ?
                         (: z (psub y (pd w 0))
                            a (pgcd w z)
                          (a . go (pquot w a) (pquot z a))))
               (? (0 = #f || 0 = pdeg f) ()
                (: g (pgcd f (pd f 0))
                 (go (pquot f g) (pquot (pd f 0) g))))))

; --- multivariate gcd: Q[x..] as (Q[y..])[x], the primitive prs -------------
; mgcd recurses on arity, one variable fewer each level, pgcd the arity-1 floor. lex-descending
; keys make the lead monomial's e1 the x-degree free. mgcd loads either face, answers raw.
(: (ksub a b) (#a ? (<a - <b . ksub >a >b))
   (mcof p k) (map (m \ mco m . >(mkey m))   ; the x-coefficients, e1 dropped
                   (filter (m \ k = <(mkey m)) p))
   (mlift c k) (map (m \ mco m . k . mkey m) c)
   (me1s p) (#p @ 0 () (: e <(mkey <p) (e . me1s (filter (m \ e != <(mkey m)) >p))))
   ; exact lex division: how the content splits off
   (mdiv f d) (#f @ 0 ()
               (: t [(. (cnorm (mco <f * cinv (mco <d)))
                           (ksub (mkey <f) (mkey <d)))]
                (padd t (mdiv (psub f (pmul t d)) d))))
   ; the pseudo-remainder cross-multiplies the lead coefficients, so the top term cancels
   ; exactly with no coefficient division
   (mprem f g) (? (0 = #f) ()
                  (pdeg f < pdeg g) f
                  (: lg (mlift (mcof g (pdeg g)) 0)
                     lf (mlift (mcof f (pdeg f)) (pdeg f - pdeg g))
                     (mprem (psub (pmul lg f) (pmul lf g)) g)))
   (mcont p) (: es (me1s p)
                (go r acc) (#r @ 0 acc (go >r (mgcd acc (mcof p <r))))
                (go >es (mcof p <es)))
   (mpp p) (mdiv p (mlift (mcont p) 0))   ; the primitive half
   (mgcd a b) (: x (load a) y (load b)
                 (go f g) (: r (mprem f g)
                             (? (0 = #r) g
                                (0 = pdeg r) (pconst #(mkey <g) 1)   ; coprime in x
                                (go g (mpp r))))
                 (? (0 = #x) (pmonic y)
                    (0 = #y) (pmonic x)
                    (1 = #(mkey <x)) (pgcd x y)
                    (: c (mgcd (mcont x) (mcont y))
                       (pmonic (pmul (mlift c 0) (go (mpp x) (mpp y))))))))   ; content-gcd times primitive-gcd

; --- rational roots: factorization's first rung ------------------------------
; the rational root theorem over the squarefree split. a rootless remainder of degree 2 or 3
; is thereby irreducible over Q -- a factor would be linear; degree 4 up it merely has no
; rational roots, and says so honestly.
(: (pden c) (coin? c ? <>(load c) 1)
   (pint f) (: cs (filter (m \ coin? (mco m)) f)   ; clears denominators: roots are scale-blind
             (#cs @ 0 f (pint (pmul [(pden (mco <cs) . '(0))] f))))
   (divs n) (: m (n < 0 ? -n n)
               (go i acc) (? (i * i > m) acc
                             (0 = m % i)
                             (go (i + 1) (i . (cnorm (m /// i) . acc)))
                             (go (i + 1) acc))
               (go 1 ()))
   (flat ls) (#ls ? (<ls + flat >ls))
   (peval f r) (#f @ 0 0 (cnorm ((mco <f * ((<(mkey <f)) r)) + peval >f r)))   ; powers by application
   (plast f) (0 = #>f ? <f (plast >f))
   (plin r) (r = 0 ? [(1 . '(1))] [(1 . '(1)) (cnorm -r . '(0))])
   ; candidates are +-n/d, n dividing the constant and d the lead; the part is squarefree,
   ; so every hit is simple and divides out once
   (rroots f) (: g (pint f)
                 (? (0 = #g || 0 = pdeg g) ()
                    (0 < <(mkey (plast g))) (0 . rroots (pquot g [(1 . '(1))]))
                    (: cds (: ns (divs (mco (plast g)))
                              ds (divs (mco <g))
                              rs (flat (map (nn \ map (dd \ cnorm (nn /// dd)) ds) ns))
                              (rs + map (r \ cnorm -r) rs))
                       (go cs h acc)
                       (? (0 = #cs) acc
                          (0 < pdeg h && 0 = peval h <cs)
                          (go >cs (pquot h (plin <cs)) (<cs . acc))
                          (go >cs h acc))
                       (sort (go cds g ())))))
   (proots p) (: fs (psff (load p))   ; ascending, with multiplicity: psff carries it
                 (go i r) (#r ?  (flat (map (x \ i (. x) ()) (rroots <r)) + go (i + 1) >r))
               (sort (go 1 fs))))

; --- zassenhaus: factorization whole -----------------------------------------
; a rootless remainder of degree 4 up factors into irreducibles the classical way. the monic
; reduction carries the weight -- F(y) = L^(n-1) f(y/L) is monic over Z and its factors map
; back by y -> Lx and pmonic -- so every stage below is monic.
;
; the vector kit: fv* are dense ascending integer vectors mod m, the modulus leading wherever
; one is needed; iv* the same over Z, unreduced; tovec/topoly cross to the monomial lists.
(: (zmod m x) (x % m @ r (r < 0 ? (r + m) r))
   (zcen m x) (zmod m x @ r (m < (r + r) ? (r - m) r))   ; centered: recombination divides over Z
   (vtrim v) (#v ? (: r (vtrim >v) (0 = #r && 0 = <v ? () (<v . r))))
   (vpadn n v) (v + (n - #v) (. 0) ())
   (fvshift k v) (k (. 0) v)
   (fvadd m a b) (vtrim (: (go a b) (? (0 = #a) b
                                       (0 = #b) a
                                       (zmod m (<a + <b) . go >a >b))
                           (go a b)))
   (fvneg m a) (map (x \ zmod m -x) a)
   (fvsub m a b) (fvadd m a (fvneg m b))
   (fvscale m c v) (vtrim (map (x \ zmod m (c * x)) v))
   (fvmul m a b) (#a ? (fvadd m (fvscale m <a b) (fvshift 1 (fvmul m >a b))))
   (fvprod m l) (1 = #l ? <l (fvmul m <l (fvprod m >l)))
   (fvlead v) (0 = #>v ? <v (fvlead >v))
   (fvdeg v) (#v - 1)
   (finv m c) (zmod m ((m - 2) (zmod m c)))   ; fermat, m prime
   (fvdm m a b) (: (go u qq)
                   (? (0 = #u || fvdeg u < fvdeg b) [qq u]
                      (: c (zmod m (fvlead u * finv m (fvlead b)))
                         k (fvdeg u - fvdeg b)
                         (go (fvsub m u (fvscale m c (fvshift k b)))
                             (fvadd m qq (fvshift k [c])))))
                   (go a ()))
   (fvquo m a b) <(fvdm m a b)
   (fvrem m a b) <>(fvdm m a b)
   (fvgcd m a b) (#b @ 0 (fvscale m (finv m (fvlead a)) a) (fvgcd m b (fvrem m a b)))
   (fvegcd m a b) (#b @ 0 (: c (finv m (fvlead a)) [(fvscale m c a) [c] ()])   ; bezout, for the lift
                   (: dm (fvdm m a b)
                      e3 (fvegcd m b <>dm)
                    [<e3 <>>e3 (fvsub m <>e3 (fvmul m <dm <>>e3))]))
   (fder m v) (vtrim (: (go l i) (#l ? (zmod m (<l * i) . go >l (i + 1)))   ; the squarefree test's derivative
                      (go >v 1)))
   (ivadd a b) (? (0 = #a) b (0 = #b) a (<a + <b . ivadd >a >b))
   (ivneg a) (map negate a)
   (ivsub a b) (vtrim (ivadd a (ivneg b)))
   (ivscale c v) (map (* c) v)
   (ivmul a b) (#a && ivadd (ivscale <a b) (fvshift 1 (ivmul >a b)))
   (rng a b) (a <= b ? (a . rng (a + 1) b))
   (tovec f) (: n (pdeg f)
                (co i) (filter (m2 \ i = <(mkey m2)) f @ () 0 (m . _) (mco m))
                (map co (rng 0 n)))
   (topoly v) (: (go l i acc)
                  (0 = #l ? acc
                   (go >l (i + 1) (0 = <l ? acc ((<l . [i]) . acc))))
               (go v 0 ()))
   ; berlekamp's linear algebra: the nullspace of q^t - I, by row reduction
   (mflip rs) (#<rs @ 0 () (map cap rs . mflip (map cup rs)))
   (msubI m rs) (: (dec r i) (: (go l k) (#l @ 0 () ((k = i ? (zmod m (<l - 1)) <l) .  go >l (k + 1))) (go r 0))
                   (go2 l i) (#l @ 0 () (dec <l i . go2 >l (i + 1)))
                   (go2 rs 0))
   (rref m n rows) (: (rowsc c r) (map (x \ zmod m (c * x)) r)
                      (rowsub a b) (:- (go a b) (go a b) (#a @ 0 () (zmod m (<a - <b) . go >a >b)))
                      (go col rs done pivs)
                      (col = n ? [done pivs]
                       (filter (r \ 0 != r col) rs @
                        () (go (col + 1) rs done pivs)
                        (pv . _)
                         (: rest (:- (d1 rs) (d1 l) (#l ?  (<l = pv ? >l (<l . d1 >l))))
                            pvn (rowsc (finv m (pv col)) pv)
                            (relim r) (r col @ 0 r c (rowsub r (rowsc c pvn)))
                            (go (col + 1) (map relim rest)
                                (map relim done + [pvn])
                                (pivs + [col])))))
                      (go 0 rows () ()))
   (nullsp m n R pivs) (: (pfind pv rr i j)
                           (#pv @ 0 0 (<pv = i ? (zmod m (0 - <rr j)) (pfind >pv >rr i j)))
                          (mk j) (map (i \ i = j ? 1 (pfind pivs R i j))
                                      (rng 0 (n - 1)))
                          (map mk (filter (j \ !(elem j pivs)) (rng 0 (n - 1)))))
   ; split by gcd with v - s over every s < p, until r factors stand
   (bsplit p r vs fs)
   (? (#fs = r) fs
      (0 = #vs) fs
      (: (go s fs2)
         (? (#fs2 = r) fs2
            (s = p) fs2
            (go (s + 1)
                (flat (map (u \ (? (fvdeg u < 2) [u]
                                   (: g (fvgcd p u (fvsub p <vs (vtrim [(zmod p s)])))
                                      (0 = fvdeg g || fvdeg g = fvdeg u ? [u]
                                       [g (fvquo p u g)]))))
                          fs2))))
         (bsplit p r >vs (go 0 fs))))
   ; berlekamp proper: the x^(ip) rows, r = the nullspace dimension = the factor count
   (bk p f) (: n (fvdeg f)
               (pw e) (? (e = 0) '(1)
                         (0 = e % 2) (pw (cnorm (e /// 2)) @ h (fvrem p (fvmul p h h) f))
                         (fvrem p (fvmul p '(0 1) (pw (e - 1))) f))
               xp (pw p)
               (rows i r acc) (i = n ? acc
                               (rows (i + 1) (fvrem p (fvmul p r xp) f) (acc + [(vpadn n r)])))
               rp (rref p n (msubI p (mflip (rows 0 '(1) ()))))
               vs (nullsp p n <rp <>rp)
               (#vs @ 1 [f] t (bsplit p t (map vtrim vs) [f])))
   (ltake n l) (n @ 0 () (<l . ltake (n - 1) >l))
   (ldrop n l) (n @ 0 l (ldrop (n - 1) >l))
   ; linear hensel on one pair, p up to P
   (hl2 P p f g h) (: gp (vtrim (map (zmod p) g))
                      hp (vtrim (map (zmod p) h))
                      e3 (fvegcd p gp hp)
                      s <>e3
                      t <>>e3
                      (go pk gg hh)
                      (? (P <= pk) [gg hh]
                         (: ep (vtrim (map (c \ zmod p (cnorm (c /// pk)))
                                           (ivsub f (ivmul gg hh))))
                            dm (fvdm p (fvmul p t ep) gp)
                            w (fvadd p (fvmul p s ep) (fvmul p hp <dm))
                            (go (pk * p)
                                (ivadd gg (ivscale pk <>dm))
                                (ivadd hh (ivscale pk w)))))
                      (go p (vtrim g) (vtrim h)))
   ; ... and pairwise up a tree, for the whole list
   (hliftn P p f gs)
   (#gs @ 1 [(vtrim (map (c \ zmod P c) f))] t
    (: hn (cnorm ((t - (t % 2)) /// 2))
       ga (ltake hn gs)
       gb (ldrop hn gs)
       gh (hl2 P p f (fvprod p ga) (fvprod p gb))
     (hliftn P p <gh ga + hliftn P p <>gh gb)))
   (combs s l) (? (s = 0) '(())
                  (0 = #l) ()
                  (map (. <l) (combs (s - 1) >l) + combs s >l))
   (drop1 x l) (#l @ 0 () (<l = x ? >l (<l . drop1 x >l)))
   (lminus l xs) (#xs @ 0 l (lminus (drop1 <xs l) >xs))
   ; recombination: subset products mod P, centered, tested by true division over Z. a hit
   ; divides out and the search restarts; what stands when the subsets run out is irreducible
   (zrec s P F ls acc)
    (s + s > #ls ? (pdeg F @ 0 acc (F . acc))
     (: (try cs) (#cs ?
                  (: cand (topoly (map (zcen P) (fvprod P <cs)))
                   (#(pmod F cand) @ 0 [cand <cs] (try >cs))))
        h (try (combs s ls))
        (#h @ 0 (zrec (s + 1) P F ls acc)
         (zrec 1 P (pquot F <h) (lminus ls <>h) (<h . acc)))))
   primes '(3 5 7 11 13 17 19 23 29 31 37 41 43 47 53 59)
   ; an odd prime keeping F squarefree mod p -- monic F makes every p coprime to the lead
   (pickp F ps) (#ps @ 0 ()
                 (: pp <ps
                    fp (vtrim (map (zmod pp) (tovec F)))
                    fd (fder pp fp)
                  (0 != #fd && fvdeg fp = pdeg F && 0 = fvdeg (fvgcd pp fp fd) ? pp (pickp F >ps))))
   (habs v) (:- (go v 0) (go l m2) (#l @ 0 m2 (: a (<l < 0 ? -<l <l) (go >l (m2 < a ? a m2)))))
   (zfac F) (: n (pdeg F)
               p (pickp F primes)
               (? !p [F]
                  (: bfs (bk p (vtrim (map (zmod p) (tovec F))))
                     (#bfs @ 1 [F]
                      (: fv (tovec F)
                         B ((n + 1) * n 2 * habs fv)   ; a generous mignotte bound: bignums make the overshoot free
                         P (:- (go p) (go pk) (B + B < pk ? pk (go (pk * p))))   ; lift until p^K > 2B
                       (zrec 1 P F (hliftn P p fv bfs) ()))))))
   ; the monic reduction and back: msub1 lays F, msub2 maps a factor home
   (pdeep f) (? (pdeg f < 4) [f]
                (: g (pint f)
                   L (mco <g)
                   n (pdeg g)
                   (map (G \ pmonic (msub2 G L))
                        (zfac (msub1 g L n)))))
   (msub1 g L n) (map (m2 \ (: e <(mkey m2)
                               (. (? (e = n) 1 (mco m2 * ((n - 1 - e) L)))
                                     (mkey m2))))
                      g)
   (msub2 G L) (map (m2 \ cnorm (mco m2 * <(mkey m2) L) . mkey m2) G)
   (ufac x) (: c (mco <x)
               (dstrip g rs) (#rs @ 0 g (dstrip (pquot g (plin <rs)) >rs))
               (go i r) (#r @ 0 ()
                         (: rs (rroots <r)
                            rem (dstrip <r rs)
                            one (map plin rs + (pdeg rem @ 0 () (pdeep rem)))
                            (flat (map (z \ i (. z) ()) one)
                             + go (i + 1) >r)))
               (c @ 1 (go 1 (psff x)) (pconst 1 c . go 1 (psff x)))))

; --- bivariate factorization: monic in x, hensel in y ------------------------
; zfac2 mirrors zassenhaus with the prime replaced by the point: shift y -> y+a to seat the
; good point at the origin, and mod y^K falls out as monomial filtering, evaluation as the
; e_y = 0 slice, the lift arithmetic as padd/pmul whole. f monic in x carries no y-content,
; so yun's split rides mgcd/mdiv verbatim (msff).
(: (mdegy f) (:- (go f 0) (go l m2) (#l @ 0 m2 (: e <>(mkey <l) (go >l (m2 < e ? e m2)))))
   (ytrunc K f) (filter (m2 \ <>(mkey m2) < K) f)   ; mod y^K, the shift having earned it
   (a2to1 f) (map (m2 \ mco m2 . [<(mkey m2)]) f)
   (a1to2 k g) (map (m2 \ mco m2 . [<(mkey m2) k]) g)
   (xco2 f k) (map (m2 \ mco m2 . [<(mkey m2)])
                   (filter (m2 \ k = <>(mkey m2)) f))
   (yevat f aa) (#f @ 0 ()   ; evaluate at y = aa
                 (: c (cnorm (mco <f * ((<>(mkey <f)) aa)))
                    r (yevat >f aa)
                  (c @ 0 r (padd [(c . [<(mkey <f)])] r))))
   (a1y2 g) (map (m2 \ mco m2 . [0 <(mkey m2)]) g)
   (a2y1 f) (map (m2 \ mco m2 . [<>(mkey m2)]) f)
   (lpow k L) (k (pmul L) [(1 . '(0))])
   (ysub f aa) (aa @ 0 f
                (: yp [(1 . '(0 1)) (aa . '(0 0))]
                   one [(1 . '(0 0))]
                   (go l) (#l @ 0 ()
                           (padd (pmul [(mco <l . [<(mkey <l) 0])]
                                       ((<>(mkey <l)) (pmul yp) one))
                                 (go >l)))
                   (go f)))
   ; exact division by a monic-in-x divisor
   (m2dm f d) (: (go u qq)
                 (? (0 = #u) [qq ()]
                    (pdeg u < pdeg d) [qq u]
                    (: t2 (mlift (mcof u (pdeg u)) (pdeg u - pdeg d))
                       (go (psub u (pmul t2 d)) (padd t2 qq))))
                 (go f ()))
   ; bezout over Q[x], once: the same u/w identity as the integer lift
   (pegcd a b) (#b @ 0 (: c (cinv (mco <a)) [(pmonic a) [(c . '(0))] ()])
                (: qq (pquot a b)
                   e3 (pegcd b (pmod a b))
                 [<e3 <>(>e3) (psub <>e3 (pmul qq <>(>e3)))]))
   (msff f) (: (go w y) (pdeg w @ 0 ()
                         (: z (psub y (pd w 0))
                            a2 (mgcd w z)
                          (a2 . go (mdiv w a2) (mdiv z a2))))
               (? (0 = #f || 0 = pdeg f) ()
                (: g (mgcd f (pd f 0))
                   (go (mdiv f g) (mdiv (pd f 0) g)))))
   ; the lift, pairwise in powers of y
   (hl22 K g G H) (: e3 (pegcd G H)
                     s <>e3
                     t <>>e3
                     (go k gg hh)
                     (K <= k ? [gg hh]
                        (: e0 (xco2 (psub g (pmul gg hh)) k)
                           te (pmul t e0)
                           u (pmod te G)
                           w (padd (pmul s e0) (pmul H (pquot te G)))
                           (go (k + 1)
                               (padd gg (a1to2 k u))
                               (padd hh (a1to2 k w)))))
                     (go 1 (a1to2 0 G) (a1to2 0 H)))
   (hliftn2 K g us) (#us @ 1 [(ytrunc K g)]
                     (: t2 #us
                        hn (cnorm ((t2 - (t2 % 2)) /// 2))
                        ua (ltake hn us)
                        ub (ldrop hn us)
                        (prodl l) (#l @ 1 <l (pmul <l (prodl >l)))
                        gh (hl22 K g (prodl ua) (prodl ub))
                        (hliftn2 K <gh ua + hliftn2 K <>gh ub)))
   ; subset products truncated at K = deg_y + 1. a true factor equals its own truncation,
   ; so no centering: a candidate divides or dies
   (zrec2 s K g ls acc)
   (? (s + s > #ls) (pdeg g @ 0 acc (g . acc))
      (: (prod2 l) (#l @ 1 <l (ytrunc K (pmul <l (prod2 >l))))
         (try cs) (#cs ?
                   (: cand (ytrunc K (prod2 <cs))
                      dm (m2dm g cand)
                    (#<>dm @ 0 [cand <cs <dm] (try >cs))))
         h (try (combs s ls))
         (#h @ 0 (zrec2 (s + 1) K g ls acc)
          (zrec2 1 K <>(>h) (lminus ls <>h) (<h . acc)))))
   (zfac2 f) (? (0 = mdegy f)
                (map (a1to2 0) (pfac (a2to1 f)))
                (: (pick as) (#as @ 0 ()
                              (: f0 (yevat f <as)
                               (pdeg (pgcd f0 (pd f0 0)) @ 0 [<as] (pick >as))))
                   aw (pick '(0 1 -1 2 -2 3 -3 4 -4 5 -5 6 -6))
                   (? (0 = #aw) [f]
                      (: a <aw
                         g (ysub f a)
                         us (pfac (a2to1 (ytrunc 1 g)))
                         (? (1 = #us) [f]
                            (: K (mdegy f + 1)
                               fs (zrec2 1 K g (hliftn2 K g us) ())
                               (map (z \ ysub z -a) fs)))))))   ; shift back, y -> y-a
   (zfac2g f) (: L (mcof f (pdeg f))
                 (? (L = [(1 . '(0))]) (zfac2 f)
                    (: n (pdeg f)
                       (bsub es) (#es @ 0 ()
                                  (padd (mlift (<es @ ^n [(1 . '(0))]
                                                (pmul (mcof f <es) (lpow (n - 1 - <es) L)))
                                               <es)
                                        (bsub >es)))
                       (bunsub G) (:- (go (me1s G)) (go es) (#es @ 0 ()
                                   (padd (mlift (pmul (mcof G <es) (lpow <es L)) <es) (go >es))))
                       (map (G \ (: gb (bunsub G)
                                    (pmonic (mdiv gb (mlift (mcont gb) 0)))))
                            (zfac2 (bsub (me1s f)))))))
   (lcs fs) (0 = #fs ? 1 (cnorm (mco <(<fs) * lcs >fs)))
   (bfac2 x) (: cy (mcont x)
                pp (mdiv x (mlift cy 0))
                yfs (map a1y2 (filter (g \ !(0 = pdeg g)) (pfac cy)))
                (go i r) (#r ? (: fs (pdeg <r @ 0 () (zfac2g <r))
                                (flat (map (z \ i (. z) ()) fs) + go (i + 1) >r)))
                all (yfs + go 1 (msff pp))
                cst (cnorm (mco <x * cinv (lcs all)))
                (? (cst = 1) all (pconst 2 cst . all)))
; --- n variables: kronecker packs onto the bivariate engine ------------------
; vpack folds the last variable into the one before it, D past that variable's degree: a ring
; homomorphism whose exponent map e*D + e' is injective below D and order-preserving on lex
; keys, so the packed poly is canonical as it stands. n variables pack down to two and the
; bivariate engine factors the image whole. this trades eez's staged lifting for degree growth
; in the image -- exact and complete either way, the honest choice at this scale.
   (mrg D k) (0 = #>>k ? [((<k * D) + <>k)] (<k . mrg D >k))
   (vpack x D) (map (m2 \ mco m2 . mrg D (mkey m2)) x)
   (vunpk g D) (map (m2 \ (: (go l) (0 = #>l ?
                                     [(cnorm ((<l - (<l % D)) /// D)) (<l % D)]
                                     (<l . go >l))
                           (mco m2 . go (mkey m2)))) g)
   (lastk k) (? (0 = #>k) <k (lastk >k))
   (mdeglast x) (:- (go x 0) (go l m2) (#l @ 0 m2 (: e (lastk (mkey <l)) (go >l (m2 < e ? e m2)))))
   (kz1? x) (1 = #x && 0 = +(mkey <x))
   (kge a b) (? (0 = #a) 1 (<a < <b) () (kge >a >b))
   ; lex division with remainder, safe on any divisor
   (mdm f d) (: (go u qq rr)
                (? (0 = #u) [qq rr]
                   (kge (mkey <u) (mkey <d))
                   (: t2 [(. (cnorm (mco <u * cinv (mco <d)))
                                (ksub (mkey <u) (mkey <d)))]
                      (go (psub u (pmul t2 d)) (padd t2 qq) rr))
                   (go >u qq (padd [(mco <u . mkey <u)] rr)))
                (go f () ()))
   (mprod l) (1 = #l ? <l (pmul <l (mprod >l)))
   ; the pack round-trip guards each candidate: a true factor's product never carries past
   ; D, so a carry accident reads as a clean miss rather than a wrong factor
   (nrec s D x ls acc)
   (? (s + s > #ls) (kz1? x ? acc (pmonic x . acc))
      (: (try cs) (#cs ? (: pp (mprod <cs) cand (vunpk pp D)
                          (vpack cand D != pp ? (try >cs)
                           (: dm (mdm x cand)
                            (0 = #<>dm ? [cand <cs <dm] (try >cs))))))
         h (try (combs s ls))
         (? (0 = #h) (nrec (s + 1) D x ls acc)
            (nrec 1 D <>(>h) (lminus ls <>h) (<h . acc)))))
   (mfacn x) (: D (mdeglast x + 1)
                fs (pfac (vpack x D))
                out (nrec 1 D x (filter (g \ !(kz1? g)) fs) ())
                cst (cnorm (mco <x * cinv (lcs out)))
                (? (cst = 1) out
                   (pconst #(mkey <x) cst . out)))
   (pfac p2) (: x (load p2)   ; dispatch on arity; anything it cannot split it keeps whole
                (? (0 = #x) ()
                   (1 = #(mkey <x)) (0 = pdeg x ? [x] (ufac x))
                   (2 != #(mkey <x)) (kz1? x ? [x] (mfacn x))
                   (0 = pdeg x && 0 = mdegy x) [x]
                   (0 = pdeg x) (map a1y2 (pfac (a2y1 x)))
                   (bfac2 x))))

; --- the poly coin: polynomials first-class under the generic ops ----------
; strike a canonical monomial list and the surface arrives whole: + - * run padd/psub/pmul
; through the die (slots 1/5/2), = compares canonical payloads, net-mode 1 (slot 6) nets a poly
; by its monomial count -- so ! reads "is the zero polynomial" even when the coefficients sum
; red, where the raw-list layer needs (0 = tally p) -- and slot 7 declares polys stars, so a
; numeral powers one through its own * (ipow's squaring, seeded at 1, lands on the zero-mul
; face). pd/pdet work the raw layer: (load p) down, (poly ..) back.
;
; the zero polynomial is the coin over () -- never bare (), which rides + and * as the
; do-nothing unit and would dodge annihilation.

; a red star is a coefficient, not nothing: test the zero point by identity and value,
; never by net -- !(-1) is true, and such a gate reads -1 as the zero poly
(: (polyish? v) (v @ () 1 0 1 ((_ . _) . _) 1)
   (arity v) #(mkey <v)
   (pok? v w) (? (polyish? v) 1 (star? v) (polyish? w ? #w))
   (plift v w) (polyish? v ? v (pconst (arity w) v))   ; a star lifts to the other side's arity
   ; a method owns its domain: against the zero poly the arity is unknowable, so + and -
   ; answer () there, as does anything else it cannot type
   (pmeth z f) (\ a b (: x (load a) y (load b)
                       (? (pok? x y && pok? y x) (z (f (plift x y) (plift y x))))))
   (zface v w) (? (star? v) (? (polyish? w) (0 = #w) 0) 0)   ; c times the zero poly is the zero poly: * needs no lift
   mk (coin 'poly (z \ {'net 'tally 'star 1
                          '+ (pmeth z padd)
                          '* (: mulm (pmeth z pmul)
                               (\ a b (: x (load a) y (load b)
                                        (? (zface x y) (z ())
                                           (zface y x) (z ())
                                           (mulm a b)))))
                          '- (pmeth z psub)}))
   (poly p) (? (polyish? p) (mk p) ()))

; --- the eval bridge: a poly compiles to a live closure ---------------------
; pemit renders a poly (raw or coin) as core source over the given variable symbols, one per
; key position; pfn wraps that in \ and hands it to ev -- a real curried closure,
; glaze-eligible, args arriving in syms order.
(: (mulfold l) (1 = #l ? <l ['* <l (mulfold >l)])   ; dyadic: (+ a b c) would be application
   (mfacts key syms) (? (0 = #key) ()
                        (0 = <key) (mfacts >key >syms)
                        (1 = <key) (<syms . mfacts >key >syms)
                        ; ('** s e), never (e x): a numeral power composes a non-numeric operand. ** is the
                        ; bound base-first power, exact through every star operand
                        (['** <syms <key] . mfacts >key >syms))
   (mterm m syms) (: fs (mfacts (mkey m) syms) c (mco m)
                     (? (0 = #fs) c
                        (c = 1) (mulfold fs)
                        (mulfold (c . fs))))
   (psum pp syms) (? (0 = #pp) 0
                     (1 = #pp) (mterm <pp syms)
                     ['+ (mterm <pp syms) (psum >pp syms)])
   (pemit p syms) (psum (load p) syms)
   (snocl l x) (0 = #l ? [x] (<l . snocl >l x))
   (pfn p syms) (ev ('\ . snocl syms (pemit p syms))))

; --- the matcher: rules over terms, riding the kanren unifier ---------------
; a term is core source -- a star, a symbol, or a folded dyadic form ('+ a b), exactly what
; pemit renders and ev compiles, so the rewrite layer and the eval bridge share one term
; language. a pattern is a term with kanren logic vars at the open positions, matched by
; `unify`: one var shared across two positions is a nonlinear pattern -- (- a a) matches only
; when both sides agree, structurally, coins by value -- at no extra cost.
(: sew (cite 'kanren 'subst)
   mnil (cite 'kanren 'empty_dict)
   ; () on a miss. a var-less hit is the empty binding, whose truth is blue, so test a miss
   ; against (), never with ! alone
   (match p x) (: r (unify mnil p x) (ufail? r ? () r))
   (vlook v ps) (? (0 = #ps) ()
                   (<<ps = v) ><ps
                   (vlook v >ps))
   ; a named symbol is a (name . mint) chain, the same shape as a var, so noms are atoms
   ; here and in rewrite -- never walked into
   (mark ps t) (? (nom? t) (vlook t ps || t)
                  (two? t) (mark ps <t . mark ps >t)
                  t)
   ; each named symbol in vs becomes one var shared across both halves; the guard is a
   ; closure over the bound values, vs order, and must answer green for the rewrite to fire
   (grule vs pat tpl g) (: ps (map (s \ s . var s) vs)
                         [(mark ps pat) (mark ps tpl) g (map cup ps)])
   (rule vs pat tpl) (grule vs pat tpl 0)
   (gpass? rl r) (rl 2 @ 0 1 g (ap g (map (sew r) (rl 3))))
   (rw1 rs x) (? (0 = #rs) x   ; the rules once, at the root, guards included
                 (: rl <rs r (unify mnil <rl x)
                    (? (ufail? r) (rw1 >rs x)
                       (gpass? rl r) (sew r <>rl)
                       (rw1 >rs x))))
   (rewrite rs x) (: y (? (nom? x) x (two? x) (map (rewrite rs) x) x)   ; bottom-up to a fixpoint: termination is the rule set's burden
                     z (rw1 rs y)
                     (? (z = y) y (rewrite rs z))))

; --- laws + fold: the shipped simplifier -------------------------------------
; every rule here shrinks or keeps size once, so the fixpoint lands. the conditional laws ride
; guards over the two certifiers, each taking an assumptions context c -- a list of fact terms
; like ((pos x) (nz n)) -- as its first argument. laws = ulaws + (glaws ()), so bare simp
; certifies only the manifest and x/x stays, while the c-family carries declared facts through
; every driver: (simpc c t), spelled assume, and (expandc c t), (derivc c t v). the plain
; simp/expand/deriv are their empty-context faces -- (assume '((nz x)) '(/ x x)) is 1.

; nonzero, by the square-sat test: $(t*t) > 0 forces t /= 0 -- sound for red stars and
; blind only toward blue, which is the safe direction
(: (nzc c t) (? (nom? t) (? (t = 'pi || t = 'e) 1
                             (elem ['nz t] c) 1
                             (elem ['pos t] c) 1
                             (elem ['neg t] c) 1)
                 (star? t) (0 != $(t * t))
                 (two? t) (<t @ 'exp 1
                                '** (nzc c <>t)
                                'sqrt (nzc c <>t)
                                '* (nzc c <>t && nzc c <>(>t))))
   (nz? t) (nzc () t)   ; the empty-context face
   (posc c t) (? (nom? t) (t = 'pi || t = 'e || elem ['pos t] c)   ; positive: ground, pi/e, exp, roots and sums of positives, even powers of nonzeros
                 (star? t) (0 < t)
                 (two? t) (<t @ 'exp 1
                                'sqrt (posc c <>t)
                                '** (posc c <>t || whole? <>>t && 0 = <>>t % 2 && nzc c <>t)
                                '* (posc c <>t && posc c <>>t)
                                '+ (posc c <>t && posc c <>>t)))
   (glaws c) [(grule '(a) '(/ a a) 1 (nzc c))   ; the conditional laws, over a context
              (grule '(a) '(/ 0 a) 0 (nzc c))
              (grule '(a b) '(/ (* a b) b) 'a (\ a b (nzc c b)))
              (grule '(a b) '(/ (* b a) b) 'a (\ a b (nzc c b)))
              (grule '(a) '(sqrt (** a 2)) 'a (posc c))]
   ulaws [(rule '(a) '(+ a 0) 'a)
          (rule '(a) '(+ 0 a) 'a)
          (rule '(a) '(* a 1) 'a)
          (rule '(a) '(* 1 a) 'a)
          (rule '(a) '(* a 0) 0)
          (rule '(a) '(* 0 a) 0)
          (rule '(a) '(- a 0) 'a)
          (rule '(a) '(- a a) 0)
          (rule '(a) '(/ a 1) 'a)
          (rule '(a) '(** a 1) 'a)
          (rule '(a) '(** a 0) 1)
          (rule '(a) '(** 1 a) 1)
          (rule '(a) '(- 0 (- 0 a)) 'a)
          (rule '(a) '(+ a a) '(* 2 a))
          (rule '(a) '(log (exp a)) 'a)
          (rule '(a) '(exp (log a)) 'a)
          (rule () '(exp 0) 1)
          (rule () '(log 1) 0)
          (rule () '(log e) 1)
          (rule () '(exp 1) 'e)
          (rule '(a) '(** e a) '(exp a))
          (rule () '(sin 0) 0)
          (rule () '(cos 0) 1)
          (rule () '(tan 0) 0)
          (rule () '(atan 0) 0)
          (rule () '(asin 0) 0)
          (rule () '(acos 1) 0)
          (rule () '(sin pi) 0)
          (rule () '(cos pi) -1)
          (rule () '(tan pi) 0)
          (rule () '(sin (* 2 pi)) 0)
          (rule () '(cos (* 2 pi)) 1)
          (rule () ['sin ['* (1 /// 2) 'pi]] 1)
          (rule () ['cos ['* (1 /// 2) 'pi]] 0)
          (rule () ['sin ['* (1 /// 4) 'pi]] ['* (1 /// 2) '(sqrt 2)])
          (rule () ['cos ['* (1 /// 4) 'pi]] ['* (1 /// 2) '(sqrt 2)])
          (rule () ['sin ['* (1 /// 6) 'pi]] (1 /// 2))
          (rule () ['cos ['* (1 /// 6) 'pi]] ['* (1 /// 2) '(sqrt 3)])
          (rule () ['sin ['* (1 /// 3) 'pi]] ['* (1 /// 2) '(sqrt 3)])
          (rule () ['cos ['* (1 /// 3) 'pi]] (1 /// 2))
          (rule () '(asin 1) ['* (1 /// 2) 'pi])
          (rule () '(acos 0) ['* (1 /// 2) 'pi])
          (rule () '(acos -1) 'pi)
          (rule () '(atan 1) ['* (1 /// 4) 'pi])
          (rule () '(sqrt 0) 0)
          (rule () '(sqrt 1) 1)
          (rule '(a) '(** (sqrt a) 2) 'a)
          (rule '(a) '(sin (- 0 a)) '(- 0 (sin a)))
          (rule '(a) '(cos (- 0 a)) '(cos a))
          (rule '(a) '(tan (- 0 a)) '(- 0 (tan a)))
          (rule '(a) '(atan (- 0 a)) '(- 0 (atan a)))
          (rule '(a) '(asin (- 0 a)) '(- 0 (asin a)))
          (rule '(a) '(/ (sin a) (cos a)) '(tan a))
          (rule '(a) '(tan (atan a)) 'a)
          (rule '(a) '(sin (asin a)) 'a)
          (rule '(a) '(cos (acos a)) 'a)
          (rule '(a) '(+ (* (sin a) (sin a)) (* (cos a) (cos a))) 1)
          (rule '(a) '(+ (** (sin a) 2) (** (cos a) 2)) 1)
          (rule '(a) '(+ (** (cos a) 2) (** (sin a) 2)) 1)]
   laws (ulaws + glaws ())
   grows [(rule '(a b c) '(* a (+ b c)) '(+ (* a b) (* a c)))   ; distribution and the log/exp splits: these grow
          (rule '(a b c) '(* (+ a b) c) '(+ (* a c) (* b c)))
          (rule '(a b c) '(* a (- b c)) '(- (* a b) (* a c)))
          (rule '(a b c) '(* (- a b) c) '(- (* a c) (* b c)))
          (rule '(a b) '(log (* a b)) '(+ (log a) (log b)))
          (rule '(a b) '(log (/ a b)) '(- (log a) (log b)))
          (rule '(a b) '(log (** a b)) '(* b (log a)))
          (rule '(a b) '(exp (+ a b)) '(* (exp a) (exp b)))
          (rule '(a b) '(exp (- a b)) '(/ (exp a) (exp b)))
          (rule '(a b) '(sin (+ a b))
                '(+ (* (sin a) (cos b)) (* (cos a) (sin b))))
          (rule '(a b) '(sin (- a b))
                '(- (* (sin a) (cos b)) (* (cos a) (sin b))))
          (rule '(a b) '(cos (+ a b))
                '(- (* (cos a) (cos b)) (* (sin a) (sin b))))
          (rule '(a b) '(cos (- a b))
                '(+ (* (cos a) (cos b)) (* (sin a) (sin b))))]
   (xlawsc c) ((ulaws + glaws c) + grows)   ; simp never expands; expand adds these and collects on the way
   xlaws (xlawsc ())
   ; a ground node folds to its value, cnormed: + - * ** / over two stars -- integers, gems,
   ; rational coins and poly coins alike. a zero divisor or base, or a slot-less die, keeps
   ; its term
   (fold1 t) (? (nom? t) t
                (one? t) t
                (3 != #t) t
                !(elem <t '(+ - * ** /)) t
                (: a <>t b <>(>t)
                   (? !(star? a && star? b) t
                      (<t = '**)
                      (? !(whole? b) t   ; a power folds by application: (b a) is a**b
                         (: v (? (0 <= b) (b a)
                                 !(nz? a) ()
                                 (whole? a) (/// 1 (-b a))
                                 (b a))
                            (star? v ? (cnorm v) t)))
                      (<t = '/)
                      ; Q is the codomain: (/ 1 2) and (** 2 -1) both land (1 /// 2) and (/ 6 3) demotes to 2,
                      ; never a gem
                      (? !(nz? b) t
                         (: v (? (whole? a && whole? b) (/// a b) (a / b))
                            (? (star? v) (cnorm v) t)))
                      (cnorm (<t @ '+ (a + b) '- (a - b) (a * b))))))
   (simpw rs t) (: y (? (nom? t) t (two? t) (map (simpw rs) t) t)   ; rules + fold, bottom-up to a fixpoint, as rewrite
                   z (fold1 (rw1 rs y))
                   (? (z = y) y (simpw rs z)))
   (simp t) (simpw laws t)
   (simpc c t) (simpw (ulaws + glaws c) t)
   assume simpc)

; --- collect: the commutative collect -----------------------------------------
; + and * are commutative and associative and - is + wearing a sign, so collect canonicalizes
; each +/-/* spine bottom-up: flatten, split every element into (c u) -- ground coefficient and
; core -- sort, merge equal cores summing coefficients exactly, and refold. the orders are
; structural and deterministic, so the binomial expand lands x^2 + 2xy + y^2 in that order and
; (x+y)(x-y) cancels to x^2 - y^2. expand runs it; simp stays order-preserving.
(: (spine o t) (? (nom? t) [t]
                  (two? t && 3 = #t && o = <t) (spine o <>t + spine o <>(>t))
                  [t])
   (tkey t) (nom? t ? ("0" + show t) ("1" + show t))   ; noms first: variables precede function forms
   (tins lt x ys) (? (0 = #ys) [x]
                     (lt x <ys) (x . ys)
                     (<ys . tins lt x >ys))
   (tsort lt xs) (#xs ? (tins lt <xs (tsort lt >xs)))
   (csplit t) (? (nom? t) [1 t]
                 (star? t) [t 1]
                 (two? t && 3 = tally t && '* = <t && star? <>t) [<>t <>(>t)]
                 [1 t])
   (sone s t) (: p (csplit t) [(cnorm (s * <p)) <>p])
   ; carries the sign through every -, so subtraction is a signed addend
   (sflat s t) (? (nom? t) [(sone s t)]
                  (two? t && 3 = #t && '+ = <t) (sflat s <>t + sflat s <>>t)
                  (two? t && 3 = #t && '- = <t) (sflat s <>t + sflat -s <>>t)
                  [(sone s t)])
   (cmerge ps) (? (0 = #ps) ()
                  (0 = #>ps) ps
                  (: p <ps r <>ps
                     (<>p = <>r ? (cmerge ([(cnorm (<p + <r)) <>p] . >>ps))
                                  (p . cmerge >ps))))
   (cone p) (: c <p u <>p (? (u = 1) c (c = 1) u ['* c u]))
   (refold o xs) (1 = #xs ? <xs [o <xs (refold o >xs)])
   ; a core's factors, powers weighted: the degree a sum sorts by, descending
   (vks t) (? (nom? t) [(show t)]
              (two? t && 3 = #t && '* = <t)
               (vks <>t + vks <>(>t))
              (two? t && 3 = #t && '** = <t && whole? <>>t && 0 < <>>t)
               (<>(>t) (+ (vks <>t)) ())
              [(show t)])
   (tcat l) (0 = #l ? "" (<l + tcat >l))
   (vkey t) (tcat (tsort (<) (vks t)))
   (slt p r) (: da #(vks <>p) db #(vks <>r)
                (? (db < da) 1 (da < db) 0 (vkey <>p < vkey <>r)))
   ; refold green first with the constant last, then each red subtracted in order, so the
   ; sign returns to the surface as -. a lone ground red stays the signed star and a pure
   ; negation stays (- 0 u)
   (tsum t) (: ps (cmerge (tsort slt (sflat 1 t)))
               ks (filter (p \ <p != 0) ps)
               gs (filter (p \ <p >= 0) ks)
               ns (filter (p \ <p < 0) ks)
               (clast l) (filter (p \ <>p != 1) l + filter (p \ <>p = 1) l)
               xs (map cone (clast gs))
               ys (map cone (map (p \ [(cnorm -<p) <>p]) (clast ns)))
               (dsub a l) (0 = #l ? a (dsub ['- a <l] >l))
               (? (0 = #ks) 0
                  (0 = #ns) (refold '+ xs)
                  (0 = #xs + #(filter (p \ <>p != 1) ns)) <<ns
                  (dsub (? (0 = #xs) 0 (refold '+ xs)) ys)))
   (tmul xs) (0 = #xs ? 1 (cnorm (<xs * tmul >xs)))
   ; a product power-collects too: repeated factors merge into (** u n), exponents whole and
   ; >= 1 only -- x * x**-1 never folds, x might be 0
   (esplit f) (? (nom? f) [1 f]
                 (two? f && 3 = tally f && '** = <f && whole? <>>f && 0 < <>>f) [<>>f <>f]
                 [1 f])
   (eone p) (: n <p u <>p (? (n = 1) u ['** u n]))
   (unneg f) (? (nom? f) [1 f]
                (two? f && 3 = tally f && '- = <f && 0 = <>f) [-1 <>>f]
                [1 f])
   (tprod t) (: ps (map unneg (spine '* t))
                gs (map caup ps)
                c (cnorm (tmul (map cap ps) * tmul (filter star? gs)))
                us (map eone (cmerge (tsort (\ p r (tkey <>p < tkey <>r))
                                            (map esplit
                                                 (filter (f \ !(star? f)) gs)))))
                (femit k) (k = 1 ? (refold '* us) (refold '* (k . us)))
                (? (0 = #us) c
                   (c = 0) 0
                   (c < 0) ['- 0 (femit (cnorm -c))]
                   (femit c)))
   (collect t) (? (nom? t) t
                  (one? t) t
                  (map collect t @ u
                   (3 != #u ? u (<u @ ('+ || '-) (tsum u) '* (tprod u) u))))
   (expandc c t) (simpc c (collect (simpw (xlawsc c) t)))
   (expand t) (expandc () t))

; --- symbolic d: the derivative as a rule set --------------------------------
; the term head `d` -- (d t v) -- reduces by dlaws. a head with no rule keeps its (d ..) term:
; a derivative rune cannot take stays symbolic, which is the honest answer.
(: (free? t v) (? (t = v) 0
                  (nom? t) 1
                  (two? t) (? (free? <t v && free? >t v) 1 0)
                  1)
   dlaws [(grule '(a v) '(d a v) 0 free?)   ; the base case: 0 exactly when a is free of v
          (rule '(a) '(d a a) 1)   ; the nonlinear pattern earns this one
          (rule '(a b v) '(d (+ a b) v) '(+ (d a v) (d b v)))
          (rule '(a b v) '(d (- a b) v) '(- (d a v) (d b v)))
          (rule '(a b v) '(d (* a b) v) '(+ (* (d a v) b) (* a (d b v))))
          (rule '(a b v) '(d (/ a b) v) '(/ (- (* (d a v) b) (* a (d b v))) (* b b)))
          (grule '(a n v) '(d (** a n) v) '(* n (* (** a (- n 1)) (d a v)))
                 (\ a n v (free? n v)))   ; a symbolic exponent needs the log bridge, and stays
          (rule '(a v) '(d (sin a) v) '(* (cos a) (d a v)))
          (rule '(a v) '(d (cos a) v) '(- 0 (* (sin a) (d a v))))
          (rule '(a v) '(d (tan a) v) '(/ (d a v) (** (cos a) 2)))
          (rule '(a v) '(d (atan a) v) '(/ (d a v) (+ 1 (** a 2))))
          (rule '(a v) '(d (sqrt a) v) '(/ (d a v) (* 2 (sqrt a))))
          (rule '(a v) '(d (asin a) v) '(/ (d a v) (sqrt (- 1 (** a 2)))))
          (rule '(a v) '(d (acos a) v) '(- 0 (/ (d a v) (sqrt (- 1 (** a 2))))))
          (rule '(a v) '(d (exp a) v) '(* (exp a) (d a v)))
          (rule '(a v) '(d (log a) v) '(/ (d a v) a))]
   (derivc c t v) (simpc c (collect (simpc c (rewrite dlaws ['d (simpc c t) v]))))   ; so d(x*x)/dx is (* 2 x)
   (deriv t v) (derivc () t v))

; --- unfix: terms back to the infix surface ----------------------------------
; the inverse of opfix, as a form: unfix renders a core term as low-paren infix source -- a
; value, not text; show prints it, ev runs it, and (opfix (unfix t)) = t is the round-trip law
; the gate holds over a corpus. the grammar, probed: bands are C-like (* / above + -, ** above
; both), arithmetic folds left within its band, ** folds right, application binds tightest.

; (band . hand), 1 = left. operators is mopped post-egg, so rune carries its own; an op
; off the table stays prefix, which reads back unchanged
(: uband '((+ 1 1) (- 1 1) (* 2 1) (/ 2 1) (** 3 0))
   (glook o gs) (? (0 = #gs) ()
                   (<<gs = o) <><gs
                   (glook o >gs))
   (hlook o gs) (? (0 = #gs) 0
                   (<<gs = o) <>><gs
                   (hlook o >gs))
   (ophead? x) (nom? <x && glook <x uband)
   (infix3? t) (#t @ 3 (ophead? t) 0)
   (uxw x) (? (nom? x) x (two? x) (unfix x) x)   ; an application splices bare; its arguments wrap whenever compound
   ; the wrap rule follows the hand: the child on the folding side wraps only strictly below
   ; its parent's band, the fold already nesting that way, and the other wraps at the band
   ; and below. so (- (- 10 4) 3) renders 10 - 4 - 3 while (- 10 (- 4 3)) keeps its parens
   (uxs x g) (? (nom? x) [x]
                (one? x) [x]
                (infix3? x) (? (glook <x uband < g) [(unfix x)] (unfix x))
                (ophead? x) [(unfix x)]
                (unfix x))
   (unfix t) (? (nom? t) t
                (one? t) t
                (infix3? t) (: g (glook <t uband) h (hlook <t uband)
                             (uxs <>t (? h g (g + 1)) + [<t] + uxs <>(>t) (? h (g + 1) g)))
                (uxw <t . map uxw >t)))

; --- the field Q[x]/(m) ----------------------------------------------------
; an element, deg m = d, is an ascending list of d rational coins. the field is given not by m
; but by xd -- x^d rewritten as an element -- so reduction folds top powers down with no
; division anywhere.
(: (vmax a b) (? (a < b) b a)
   (vpad v n) (? (n = 0) ()
                 (0 = #v) (0 /// 1 . vpad () (n - 1))
                 (<v . vpad >v (n - 1)))
   (vzip a b) (? (0 = #a) () ((<a + <b) . vzip >a >b))
   (vadd a b) (: n (vmax #a #b) (vzip (vpad a n) (vpad b n)))
   (vscale c v) (map (* c) v)
   (vshift v n) (n @ 0 v (0 /// 1 . vshift v (n - 1)))
   (vmul a b) (#a @ 0 () (vadd (vscale <a b) (vshift (vmul >a b) 1)))
   (vlast v) (#v @ 1 <v (vlast >v))
   (vinit v) (#v @ 1 () (<v . vinit >v))
   (vrem xd v) (#v < #xd + 1 ? (vpad v #xd)   ; the fold: one top power at a time
                (vrem xd (vadd (vinit v) (vshift (vscale (vlast v) xd) (#v - (#xd + 1))))))
   (kmul xd a b) (vrem xd (vmul a b))
   (knum d c) (vpad [(c /// 1)] d))
