; rune -- the symbolic algebra engine (a wee CAS): exact multivariate
; polynomials over the integers, plus univariate arithmetic in Q[x]/(m)
; riding the q coin. pure love, no nifs; the gate is test/host/rune.l,
; whose corpus verifies the 2026 jacobian-conjecture disproof whole
; (det J symbolically, the collision certificates in exact arithmetic).
;
; a POLY is a list of monomials, each (c e0 e1 .. ) -- an integer
; coefficient then one exponent per variable -- keys lex-descending, no
; zero coefficients, all polys in one expression sharing an arity. the
; zero polynomial is (): the empty sum IS nothing. (coefficients stay
; integers: ! cannot test a coefficient for zero -- a red coefficient
; nets nothing -- so padd drops on (c = 0), which coins don't answer.)
;
; a K-ELEMENT of Q[x]/(m), deg m = d, is an ascending list of d q coins.
; the field is given not by m but by XD -- x^d rewritten as an element --
; so reduction folds top powers down with no division anywhere.

; --- the polynomial ring ---------------------------------------------------
(: (mco m) (cap m)
   (mkey m) (cup m)
   (keylt a b) (? (0 = tally a) 0
                  ((cap a) < (cap b)) 1
                  ((cap b) < (cap a)) 0
                  (keylt (cup a) (cup b)))
   (padd p1 p2) (? (0 = tally p1) p2
                   (0 = tally p2) p1
                   (: mp (cap p1) mq (cap p2)
                      (? ((mkey mp) = (mkey mq))
                         (: c ((mco mp) + (mco mq)) r (padd (cup p1) (cup p2))
                            (? (c = 0) r (link (link c (mkey mp)) r)))
                         (keylt (mkey mq) (mkey mp))
                         (link mp (padd (cup p1) p2))
                         (link mq (padd p1 (cup p2))))))
   (pneg p) (map (\ mm (link (0 - (mco mm)) (mkey mm))) p)
   (psub p1 p2) (padd p1 (pneg p2))
   (zadd a b) (? (0 = tally a) () (link ((cap a) + (cap b)) (zadd (cup a) (cup b))))
   (mmul a b) (link ((mco a) * (mco b)) (zadd (mkey a) (mkey b)))
   (mrow a p2) (? (0 = tally p2) () (link (mmul a (cap p2)) (mrow a (cup p2))))
   (pmul p1 p2) (? (0 = tally p1) () (padd (mrow (cap p1) p2) (pmul (cup p1) p2)))
   (nth l n) (? (n = 0) (cap l) (nth (cup l) (n - 1)))
   (setn l n x) (? (n = 0) (link x (cup l)) (link (cap l) (setn (cup l) (n - 1) x)))
   (deln l n) (? (n = 0) (cup l) (link (cap l) (deln (cup l) (n - 1))))
   (zeros n) (? (n = 0) () (link 0 (zeros (n - 1))))
   (pconst n c) (? (c = 0) () `((link c (zeros n))))
   (pvar n k) `((link 1 (setn (zeros n) k 1))))

; --- the derivative and the determinant ------------------------------------
; pd differentiates monomial by monomial (padd of singletons keeps the
; canonical order); pdet expands along the first row, minors by deln.
(: (pd p v) (? (0 = tally p) ()
               (: mm (cap p) e (nth (mkey mm) v) r (pd (cup p) v)
                  (? (e = 0) r
                     (padd `((link ((mco mm) * e) (setn (mkey mm) v (e - 1)))) r))))
   (pdet rows) (? (1 = tally rows) (cap (cap rows))
                  (: (go r0 j sg)
                     (? (0 = tally r0) ()
                        (: t (pmul (cap r0) (pdet (map (\ r (deln r j)) (cup rows))))
                           (padd (? (sg = 1) t (pneg t)) (go (cup r0) (j + 1) (0 - sg)))))
                     (go (cap rows) 0 1))))

; --- the poly coin: polynomials first-class under the generic ops ----------
; strike a CANONICAL monomial list (the engine's own output) and the surface
; arrives whole: + - * run padd/psub/pmul through the die (slots 1/5/2), =
; compares canonical payloads, and net-mode 1 (slot 6) nets a poly by its
; MONOMIAL COUNT -- so ! reads "is the zero polynomial" even when the
; coefficients sum red (the raw-list layer needs (0 = tally p) for that). the
; ZERO polynomial is the coin over () -- never bare (), which rides + and * as
; the do-nothing unit and would dodge annihilation. a method owns its domain:
; a star operand lifts to the other side's arity; against the zero poly the
; arity is unknowable, so + and - answer () there, but * needs no lift at all
; (c times the zero poly IS the zero poly); anything else answers (). slot 7
; declares polys STARS, so a numeral powers a poly through its own * -- ipow's
; squaring over coins, seeded at 1, lands on the zero-mul face. pd/pdet work
; the raw layer: (load p) to reach it, (poly ..) to come back.
(: polyd #(0 'poly 6 1 7 1)
   (polyish? v) (? (nil? v) 1 (two? v) (two? (cap v)) 0)
   (arity v) (tally (mkey (cap v)))
   (pok? v w) (? (polyish? v) 1 (star? v) (? (polyish? w) (tally w) ()) ())
   (plift v w) (? (polyish? v) v (pconst (arity w) v))
   (pmeth f) (\ a b (: x (load a) y (load b)
                       (? (&& (pok? x y) (pok? y x))
                          (coin polyd (f (plift x y) (plift y x)))
                          ())))
   (zface v w) (? (star? v) (? (polyish? w) (0 = tally w) 0) 0)
   mulm (pmeth pmul)
   _ (pin polyd 1 (pmeth padd))
   _ (pin polyd 2 (\ a b (: x (load a) y (load b)
                            (? (zface x y) (coin polyd ())
                               (zface y x) (coin polyd ())
                               (mulm a b)))))
   _ (pin polyd 5 (pmeth psub))
   (poly p) (? (polyish? p) (coin polyd p) ()))

; --- the eval bridge: a poly compiles to a live closure ---------------------
; pemit renders a poly (raw or coin) as core source over the given variable
; symbols, one per key position. the emission is folded DYADIC + and * only --
; never (+ a b c), which is application, and never (e x) numeral power, which
; COMPOSES a non-numeric operand -- powers ride as repeated *, so the closure
; computes over ANYTHING the generic ops carry: integers, bignums, gems, q
; coins. pfn wraps the emission in \ and hands it to ev: a real curried
; closure, glaze-eligible; args arrive in syms order.
(: (reps s e acc) (? (e = 0) acc (reps s (e - 1) (link s acc)))
   (mulfold l) (? (1 = tally l) (cap l) `('* (cap l) (mulfold (cup l))))
   (mfacts key syms) (? (0 = tally key) ()
                        (reps (cap syms) (cap key) (mfacts (cup key) (cup syms))))
   (mterm m syms) (: fs (mfacts (mkey m) syms) c (mco m)
                     (? (0 = tally fs) c
                        (c = 1) (mulfold fs)
                        (mulfold (link c fs))))
   (psum pp syms) (? (0 = tally pp) 0
                     (1 = tally pp) (mterm (cap pp) syms)
                     `('+ (mterm (cap pp) syms) (psum (cup pp) syms)))
   (pemit p syms) (psum (load p) syms)
   (snocl l x) (? (0 = tally l) (link x ()) (link (cap l) (snocl (cup l) x)))
   (pfn p syms) (ev (link '\ (snocl syms (pemit p syms)))))

; --- the field Q[x]/(m) ----------------------------------------------------
(: (vmax a b) (? (a < b) b a)
   (vpad v n) (? (n = 0) ()
                 (0 = tally v) (link (q 0 1) (vpad () (n - 1)))
                 (link (cap v) (vpad (cup v) (n - 1))))
   (vzip a b) (? (0 = tally a) () (link ((cap a) + (cap b)) (vzip (cup a) (cup b))))
   (vadd a b) (: n (vmax (tally a) (tally b)) (vzip (vpad a n) (vpad b n)))
   (vscale c v) (map (* c) v)
   (vshift v n) (? (n = 0) v (link (q 0 1) (vshift v (n - 1))))
   (vmul a b) (? (0 = tally a) () (vadd (vscale (cap a) b) (vshift (vmul (cup a) b) 1)))
   (vlast v) (? (1 = tally v) (cap v) (vlast (cup v)))
   (vinit v) (? (1 = tally v) () (link (cap v) (vinit (cup v))))
   (vrem xd v) (? ((tally v) < ((tally xd) + 1)) (vpad v (tally xd))
                  (vrem xd (vadd (vinit v)
                                 (vshift (vscale (vlast v) xd) ((tally v) - ((tally xd) + 1))))))
   (kmul xd a b) (vrem xd (vmul a b))
   (knum d c) (vpad `((q c 1)) d))
