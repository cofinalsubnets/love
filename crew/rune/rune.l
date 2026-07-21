; rune -- the symbolic algebra engine (a wee CAS): exact multivariate
; polynomials over the integers, plus univariate arithmetic in Q[x]/(m)
; riding the q coin. pure love, no nifs; the gate is test/host/rune.l,
; whose corpus verifies the 2026 jacobian-conjecture disproof whole
; (det J symbolically, the collision certificates in exact arithmetic).
;
; a POLY is a list of monomials, each (c e0 e1 .. ) -- a coefficient (a
; STAR: an integer or a ratio coin, so the ring is Q[x..] with Z[x..]
; sitting inside it structurally) then one exponent per variable -- keys
; lex-descending, no zero coefficients, all polys in one expression
; sharing an arity. the zero polynomial is (): the empty sum IS nothing.
; cnorm keeps coefficients CANONICAL: an integer-valued coin ((q n 1))
; demotes to its integer numerator, so halves that sum whole land an
; integer, = stays structural across Z and Q, and the zero-drop is the
; plain (c = 0) -- a value-zero coin demotes to the fixnum 0 first.
; (! can never test a coefficient: a red one nets nothing.)
;
; a K-ELEMENT of Q[x]/(m), deg m = d, is an ascending list of d q coins.
; the field is given not by m but by XD -- x^d rewritten as an element --
; so reduction folds top powers down with no division anywhere.

; the module scope opens here: every binding below lands in this layer,
; mutually visible by bare name; crew/rune/seal.l closes it, which REGISTERS
; it as the module `rune` -- a consumer either (use 'rune) and reads bare,
; or reaches one member through the accessor: (from 'rune 'deriv).
(enter 'rune)

; --- the polynomial ring ---------------------------------------------------
(: (mco m) <m
   (mkey m) >m
   (cnorm c) (coin? c ? (: p (load c) (1 = <>p ? <p c)) c)
   (keylt a b) (? (0 = tally a) 0
                  (<a < <b) 1
                  (<b < <a) 0
                  (keylt >a >b))
   (padd p1 p2) (? (0 = tally p1) p2
                   (0 = tally p2) p1
                   (: mp <p1 mq <p2
                      (? (mkey mp = mkey mq)
                         (: c (cnorm (mco mp + mco mq)) r (padd >p1 >p2)
                            (c = 0 ? r (link (link c (mkey mp)) r)))
                         (keylt (mkey mq) (mkey mp))
                         (link mp (padd >p1 p2))
                         (link mq (padd p1 >p2)))))
   (pneg p) (map (\ mm (link (0 - mco mm) (mkey mm))) p)
   (psub p1 p2) (padd p1 (pneg p2))
   (zadd a b) (0 = tally a ? () (link (<a + <b) (zadd >a >b)))
   (mmul a b) (link (cnorm (mco a * mco b)) (zadd (mkey a) (mkey b)))
   (mrow a p2) (0 = tally p2 ? () (link (mmul a <p2) (mrow a >p2)))
   (pmul p1 p2) (0 = tally p1 ? () (padd (mrow <p1 p2) (pmul >p1 p2)))
   (nth l n) (n = 0 ? <l (nth >l (n - 1)))
   (setn l n x) (n = 0 ? (link x >l) (link <l (setn >l (n - 1) x)))
   (deln l n) (n = 0 ? >l (link <l (deln >l (n - 1))))
   (zeros n) (n = 0 ? () (link 0 (zeros (n - 1))))
   (pconst n c) (: k (cnorm c) (k = 0 ? () `((link k (zeros n)))))
   (pvar n k) `((link 1 (setn (zeros n) k 1))))

; --- the derivative and the determinant ------------------------------------
; pd differentiates monomial by monomial (padd of singletons keeps the
; canonical order); pdet expands along the first row, minors by deln.
(: (pd p v) (? (0 = tally p) ()
               (: mm <p e (nth (mkey mm) v) r (pd >p v)
                  (e = 0 ? r
                     (padd `((link (cnorm (mco mm * e)) (setn (mkey mm) v (e - 1)))) r))))
   (pdet rows) (1 = tally rows ? <(<rows)
                  (: (go r0 j sg)
                     (0 = tally r0 ? ()
                        (: t (pmul <r0 (pdet (map (\ r (deln r j)) >rows)))
                           (padd (sg = 1 ? t (pneg t)) (go >r0 (j + 1) (0 - sg)))))
                     (go <rows 0 1))))

; --- gcd: euclid in Q[x], answers monic -------------------------------------
; UNIVARIATE (arity-1 keys): pmod is long division's remainder -- the lead
; quotient monomial (pquo) rides pmul/psub, so cancellation is the ring's
; own, exact -- and pgcd euclids until the zero poly, then normalizes monic
; (unique in Q[x]; units divide out). cinv is the exact reciprocal of a
; coefficient star: a coin through its die, an integer through the q ctor.
; both faces load: raw monomial lists and poly coins alike; answers are raw.
(: (cinv c) (coin? c ? (-1 c) (q 1 c))
   (pdeg p) <(mkey <p)
   (pmonic p) (? (0 = tally p) ()
                 (: v (cinv (mco <p))
                    (map (\ m (link (cnorm (v * mco m)) (mkey m))) p)))
   (pquo a b) `((link (cnorm (mco <a * cinv (mco <b))) `((pdeg a - pdeg b))))
   (pmod a b) (? (0 = tally a) ()
                 ((pdeg a) < (pdeg b)) a
                 (pmod (psub a (pmul (pquo a b) b)) b))
   (pgcd a b) (: x (load a) y (load b)
                 (? (0 = tally y) (pmonic x) (pgcd y (pmod x y)))))

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
   (polyish? v) (? !v 1 (two? v) (two? <v) 0)
   (arity v) (tally (mkey <v))
   (pok? v w) (? (polyish? v) 1 (star? v) (polyish? w ? (tally w) ()) ())
   (plift v w) (polyish? v ? v (pconst (arity w) v))
   (pmeth f) (\ a b (: x (load a) y (load b)
                       ((&& (pok? x y) (pok? y x)) ?
                        (coin polyd (f (plift x y) (plift y x)))
                        ())))
   (zface v w) (star? v ? (polyish? w ? (0 = tally w) 0) 0)
   mulm (pmeth pmul)
   _ (pin polyd 1 (pmeth padd))
   _ (pin polyd 2 (\ a b (: x (load a) y (load b)
                            (? (zface x y) (coin polyd ())
                               (zface y x) (coin polyd ())
                               (mulm a b)))))
   _ (pin polyd 5 (pmeth psub))
   (poly p) (polyish? p ? (coin polyd p) ()))

; --- the eval bridge: a poly compiles to a live closure ---------------------
; pemit renders a poly (raw or coin) as core source over the given variable
; symbols, one per key position. the emission is folded DYADIC + * ** only --
; never (+ a b c), which is application, and never (e x) numeral power, which
; COMPOSES a non-numeric operand -- a power rides ('** s e): ** is the bound
; base-first power, exact through every DIE_STAR operand (integers, bignums,
; gems, q coins). pfn wraps the emission in \ and hands it to ev: a real
; curried closure, glaze-eligible; args arrive in syms order.
(: (mulfold l) (1 = tally l ? <l `('* <l (mulfold >l)))
   (mfacts key syms) (? (0 = tally key) ()
                        (0 = <key) (mfacts >key >syms)
                        (1 = <key) (link <syms (mfacts >key >syms))
                        (link `('** <syms <key) (mfacts >key >syms)))
   (mterm m syms) (: fs (mfacts (mkey m) syms) c (mco m)
                     (? (0 = tally fs) c
                        (c = 1) (mulfold fs)
                        (mulfold (link c fs))))
   (psum pp syms) (? (0 = tally pp) 0
                     (1 = tally pp) (mterm <pp syms)
                     `('+ (mterm <pp syms) (psum >pp syms)))
   (pemit p syms) (psum (load p) syms)
   (snocl l x) (0 = tally l ? `(x) (link <l (snocl >l x)))
   (pfn p syms) (ev (link '\ (snocl syms (pemit p syms)))))

; --- the matcher: rules over terms, riding the kanren unifier ---------------
; a TERM is core source -- a star, a symbol, or a folded dyadic form ('+ a b),
; exactly what pemit renders and ev compiles -- so the rewrite layer and the
; eval bridge share one term language. a PATTERN is a term with kanren logic
; vars at the open positions, and `unify` (the compiler-grade core; the
; relational rewrite layer it was kept public for) does the matching: one var
; shared across two positions is a NONLINEAR pattern -- (- a a) matches only
; when both sides agree, structurally, coins by value -- at no extra cost.
; `rule` compiles the readable (vars pat tpl) triple: each named symbol in vs
; becomes ONE var shared across both halves; `grule` adds a GUARD -- a closure
; over the bound values, vs order -- that must answer green for the rewrite to
; fire (how (d a v) -> 0 says "only when a is free of v"). `match` answers the
; binding, or () on a miss -- a var-less hit is the EMPTY binding, whose truth
; is blue, so test a miss against (), never with ! alone. `sew` fills a
; template under a binding. `rewrite` drives a rule list bottom-up to a
; fixpoint (rw1 tries the rules once, at the root, guards included);
; termination is the rule set's burden. a named symbol is a (name . mint)
; chain -- the SAME shape as a var -- so mark and rewrite treat noms as
; atoms, never walking into them.
(: sew (kanren 'subst)
   mnil (kanren 'empty_dict)
   (match p x) (: r (unify mnil p x) (ufail? r ? () r))
   (vlook v ps) (? (0 = tally ps) ()
                   (<(<ps) = v) >(<ps)
                   (vlook v >ps))
   (mark ps t) (? (nom? t) (: w (vlook t ps) (!w ? t w))
                  (two? t) (link (mark ps <t) (mark ps >t))
                  t)
   (grule vs pat tpl g) (: ps (map (\ s (link s (var s))) vs)
                           `((mark ps pat) (mark ps tpl) g (map (\ pr >pr) ps)))
   (rule vs pat tpl) (grule vs pat tpl 0)
   (gpass? rl r) (: g (nth rl 2)
                    (g = 0 ? 1 (ap g (map (sew r) (nth rl 3)))))
   (rw1 rs x) (? (0 = tally rs) x
                 (: rl <rs r (unify mnil <rl x)
                    (? (ufail? r) (rw1 >rs x)
                       (gpass? rl r) (sew r <>rl)
                       (rw1 >rs x))))
   (rewrite rs x) (: y (? (nom? x) x (two? x) (map (rewrite rs) x) x)
                     z (rw1 rs y)
                     (z = y ? y (rewrite rs z))))

; --- laws + fold: the shipped simplifier -------------------------------------
; `laws` is the core identity table -- units, annihilators, inverses, the
; doubling collect, the log/exp cancellations, and the pythagorean identity --
; every rule shrinking or size-keeping-once, so the fixpoint lands. the
; CONDITIONAL division laws (a/a, 0/a, cancellation) ride guards: nz? is the
; "manifestly nonzero" certificate -- a value-nonzero ground star (the
; square-sat test: $(t*t) > 0 forces t /= 0, sound for red stars and blind
; only toward blue, the safe direction), an exp form (never zero), or a power
; of one -- so a/a needs a CERTIFICATE, never an assumption: x/x stays. `xlaws`
; adds the GROWING rules on top: distribution and the log/exp splits. simp
; never expands; `expand` does (each pass pushes a * inside a +, or a log/exp
; through its operand, so that fixpoint lands too -- collected on the way).
; fold1 computes a GROUND node: (op a b) for op in + - * ** / with both
; operands stars (the open star: integers, gems, q coins, poly coins alike)
; folds to its value, cnormed so an integer-valued coin lands the integer.
; a power folds by APPLICATION -- (b a) is a**b -- on a whole exponent.
; Q IS THE FOLD CODOMAIN: a ground quotient or negative power folds EXACTLY
; through the q coin ((/ 1 2) and (** 2 -1) both land (q 1 2), (/ 6 3) demotes
; to 2) -- never to a gem. a zero divisor/base (nz? again) or a slot-less die
; keeps its term. `simpw` drives a rule table + fold bottom-up to a
; fixpoint, the same shape as rewrite (noms are atoms, never walked into);
; simp is its laws face, expand its xlaws face -- through collect (below).
(: (nz? t) (? (nom? t) ()
              (star? t) !(0 = (sat (t * t)))
              (two? t) (? (<t = 'exp) 1 (<t = '**) (nz? <>t) ())
              ())
   laws `((rule '(a) '(+ a 0) 'a)
          (rule '(a) '(+ 0 a) 'a)
          (rule '(a) '(* a 1) 'a)
          (rule '(a) '(* 1 a) 'a)
          (rule '(a) '(* a 0) 0)
          (rule '(a) '(* 0 a) 0)
          (rule '(a) '(- a 0) 'a)
          (rule '(a) '(- a a) 0)
          (rule '(a) '(/ a 1) 'a)
          (grule '(a) '(/ a a) 1 nz?)
          (grule '(a) '(/ 0 a) 0 nz?)
          (grule '(a b) '(/ (* a b) b) 'a (\ a b (nz? b)))
          (grule '(a b) '(/ (* b a) b) 'a (\ a b (nz? b)))
          (rule '(a) '(** a 1) 'a)
          (rule '(a) '(** a 0) 1)
          (rule '(a) '(** 1 a) 1)
          (rule '(a) '(- 0 (- 0 a)) 'a)
          (rule '(a) '(+ a a) '(* 2 a))
          (rule '(a) '(log (exp a)) 'a)
          (rule '(a) '(exp (log a)) 'a)
          (rule () '(exp 0) 1)
          (rule () '(log 1) 0)
          (rule '(a) '(+ (* (sin a) (sin a)) (* (cos a) (cos a))) 1))
   xlaws (laws + `((rule '(a b c) '(* a (+ b c)) '(+ (* a b) (* a c)))
                   (rule '(a b c) '(* (+ a b) c) '(+ (* a c) (* b c)))
                   (rule '(a b c) '(* a (- b c)) '(- (* a b) (* a c)))
                   (rule '(a b c) '(* (- a b) c) '(- (* a c) (* b c)))
                   (rule '(a b) '(log (* a b)) '(+ (log a) (log b)))
                   (rule '(a b) '(log (/ a b)) '(- (log a) (log b)))
                   (rule '(a b) '(log (** a b)) '(* b (log a)))
                   (rule '(a b) '(exp (+ a b)) '(* (exp a) (exp b)))
                   (rule '(a b) '(exp (- a b)) '(/ (exp a) (exp b)))))
   (fold1 t) (? (nom? t) t
                !(two? t) t
                !(3 = tally t) t
                !(member? <t '(+ - * ** /)) t
                (: a <>t b <>(>t)
                   (? !(&& (star? a) (star? b)) t
                      (<t = '**)
                      (? !(whole? b) t
                         (: v (? (0 <= b) (b a)
                                 !(nz? a) ()
                                 (whole? a) (q 1 ((0 - b) a))
                                 (b a))
                            ((star? v) ? (cnorm v) t)))
                      (<t = '/)
                      (? !(nz? b) t
                         (: v (? (&& (whole? a) (whole? b)) (q a b) (a / b))
                            ((star? v) ? (cnorm v) t)))
                      (cnorm (? (<t = '+) (a + b) (<t = '-) (a - b) (a * b))))))
   (simpw rs t) (: y (? (nom? t) t (two? t) (map (simpw rs) t) t)
                   z (fold1 (rw1 rs y))
                   (z = y ? y (simpw rs z)))
   (simp t) (simpw laws t))

; --- collect: the commutative collect -----------------------------------------
; + and * are commutative and associative, and - is + wearing a sign, so
; collect canonicalizes each +/-/* spine, bottom-up: flatten (sflat carries
; the sign through every -, so subtraction IS a signed addend), split every
; element into (c u) -- ground coefficient and core -- sort, merge equal
; cores summing coefficients exactly, and refold: green terms first
; (constant last), then each red term SUBTRACTED in order, so the sign
; returns to the surface as - ; a lone ground red stays the signed star, a
; pure negation stays (- 0 u). a product also POWER-COLLECTS: repeated
; factors merge into (** u n), exponents whole and >= 1 only (x * x**-1
; never folds -- x might be 0), summed through the same pair merge. the
; orders are structural and deterministic: a product sorts bases noms-first
; (variables precede function forms); a sum sorts by DEGREE descending (vks
; counts a core's factors, powers weighted) then the sorted factor-string,
; so the binomial expand lands x^2 + 2xy + y^2 in that order, and (x+y)(x-y)
; cancels to x^2 - y^2. expand runs it; simp stays order-preserving.
(: (spine o t) (? (nom? t) `(t)
                  (&& (two? t) (3 = tally t) (o = <t))
                  ((spine o <>t) + (spine o <>(>t)))
                  `(t))
   (tkey t) ((nom? t) ? ("0" + show t) ("1" + show t))
   (tins lt x ys) (? (0 = tally ys) `(x)
                     (lt x <ys) (link x ys)
                     (link <ys (tins lt x >ys)))
   (tsort lt xs) (? (0 = tally xs) () (tins lt <xs (tsort lt >xs)))
   (csplit t) (? (nom? t) `(1 t)
                 (star? t) `(t 1)
                 (&& (two? t) (3 = tally t) ('* = <t) (star? <>t)) `(<>t <>(>t))
                 `(1 t))
   (sone s t) (: p (csplit t) `((cnorm (s * <p)) <>p))
   (sflat s t) (? (nom? t) `((sone s t))
                  (&& (two? t) (3 = tally t) ('+ = <t))
                  ((sflat s <>t) + (sflat s <>(>t)))
                  (&& (two? t) (3 = tally t) ('- = <t))
                  ((sflat s <>t) + (sflat (0 - s) <>(>t)))
                  `((sone s t)))
   (cmerge ps) (? (0 = tally ps) ()
                  (0 = tally >ps) ps
                  (: p <ps r <(>ps)
                     ((<>p = <>r) ? (cmerge (link `((cnorm (<p + <r)) <>p) >(>ps)))
                                    (link p (cmerge >ps)))))
   (cone p) (: c <p u <>p
               (? (u = 1) c (c = 1) u `('* c u)))
   (refold o xs) ((1 = tally xs) ? <xs `(o <xs (refold o >xs)))
   (vks t) (? (nom? t) `((show t))
              (&& (two? t) (3 = tally t) ('* = <t))
              ((vks <>t) + (vks <>(>t)))
              (&& (two? t) (3 = tally t) ('** = <t)
                  (whole? <>(>t)) (0 < <>(>t)))
              (<>(>t) (+ (vks <>t)) ())
              `((show t)))
   (tcat l) (? (0 = tally l) "" (<l + (tcat >l)))
   (vkey t) (tcat (tsort (\ a b (a < b)) (vks t)))
   (slt p r) (: da (tally (vks <>p)) db (tally (vks <>r))
                (? (db < da) 1 (da < db) 0 ((vkey <>p) < (vkey <>r))))
   (tsum t) (: ps (cmerge (tsort slt (sflat 1 t)))
               ks (filter (\ p !(<p = 0)) ps)
               gs (filter (\ p !(<p < 0)) ks)
               ns (filter (\ p (<p < 0)) ks)
               (clast l) ((filter (\ p !(<>p = 1)) l) + (filter (\ p (<>p = 1)) l))
               xs (map cone (clast gs))
               ys (map cone (map (\ p `((cnorm (0 - <p)) <>p)) (clast ns)))
               (dsub a l) ((0 = tally l) ? a (dsub `('- a <l) >l))
               (? (0 = tally ks) 0
                  (0 = tally ns) (refold '+ xs)
                  (&& (0 = tally xs)
                      (0 = tally (filter (\ p !(<>p = 1)) ns))) <(<ns)
                  (dsub ((0 = tally xs) ? 0 (refold '+ xs)) ys)))
   (tmul xs) (? (0 = tally xs) 1 (cnorm (<xs * (tmul >xs))))
   (esplit f) (? (nom? f) `(1 f)
                 (&& (two? f) (3 = tally f) ('** = <f)
                     (whole? <>(>f)) (0 < <>(>f)))
                 `(<>(>f) <>f)
                 `(1 f))
   (eone p) (: n <p u <>p ((n = 1) ? u `('** u n)))
   (tprod t) (: fs (spine '* t)
                c (tmul (filter star? fs))
                us (map eone (cmerge (tsort (\ p r ((tkey <>p) < (tkey <>r)))
                                            (map esplit
                                                 (filter (\ f !(star? f)) fs)))))
                (? (0 = tally us) c
                   (c = 0) 0
                   (c = 1) (refold '* us)
                   (refold '* (link c us))))
   (collect t) (? (nom? t) t
                  !(two? t) t
                  (: u (map collect t)
                     (? !(3 = tally u) u
                        ('+ = <u) (tsum u)
                        ('- = <u) (tsum u)
                        ('* = <u) (tprod u)
                        u)))
   (expand t) (simp (collect (simpw xlaws t))))

; --- symbolic d: the derivative as a rule set --------------------------------
; the term head `d` -- (d t v) -- reduces by dlaws: sum/product/quotient rules
; are plain patterns, (d a a) -> 1 rides the nonlinear pattern, sin/cos and
; exp/log carry the chain rule, the power rule guards on a CONSTANT exponent
; (free? n v -- a symbolic exponent needs the log bridge and stays), and the
; base case is the GUARDED rule: (d a v) -> 0 exactly when a is free? of v
; -- the guard the matcher grew for it. a head with no
; rule keeps its (d ..) term: a derivative rune cannot take stays symbolic,
; the honest answer. deriv drives dlaws to a fixpoint and simps the result,
; so d(x*x)/dx lands (* 2 x), not (+ (* 1 x) (* x 1)).
(: (free? t v) (? (t = v) 0
                  (nom? t) 1
                  (two? t) ((&& (free? <t v) (free? >t v)) ? 1 0)
                  1)
   dlaws `((grule '(a v) '(d a v) 0 free?)
           (rule '(a) '(d a a) 1)
           (rule '(a b v) '(d (+ a b) v) '(+ (d a v) (d b v)))
           (rule '(a b v) '(d (- a b) v) '(- (d a v) (d b v)))
           (rule '(a b v) '(d (* a b) v) '(+ (* (d a v) b) (* a (d b v))))
           (rule '(a b v) '(d (/ a b) v) '(/ (- (* (d a v) b) (* a (d b v))) (* b b)))
           (grule '(a n v) '(d (** a n) v) '(* n (* (** a (- n 1)) (d a v)))
                  (\ a n v (free? n v)))
           (rule '(a v) '(d (sin a) v) '(* (cos a) (d a v)))
           (rule '(a v) '(d (cos a) v) '(- 0 (* (sin a) (d a v))))
           (rule '(a v) '(d (exp a) v) '(* (exp a) (d a v)))
           (rule '(a v) '(d (log a) v) '(/ (d a v) a)))
   (deriv t v) (simp (collect (simp (rewrite dlaws `('d t v))))))

; --- unfix: terms back to the infix surface ----------------------------------
; the inverse of opfix, as a FORM: unfix renders a core term as low-paren
; infix source -- a value, not text; show prints it, ev runs it, and
; (opfix (unfix t)) = t is the round-trip law the gate asserts over a corpus.
; the grammar, probed: bands are C-like (* / above + -, ** above both), the
; fold within a band is right-associative, application binds tightest. so a
; LEFT child wraps at its parent's band and below ((- (- 10 4) 3) renders
; ((10 - 4) - 3)), a RIGHT child wraps only strictly below it (the fold IS
; right-associative), an application splices bare unless its head is an
; operator, and application arguments wrap whenever compound. `operators` is
; mopped post-egg, so ugrip carries the bands rune renders; an op off the
; table stays prefix, which reads back unchanged.
(: ugrip '((+ 1) (- 1) (* 2) (/ 2) (** 3))
   (glook o gs) (? (0 = tally gs) ()
                   (<(<gs) = o) <>(<gs)
                   (glook o >gs))
   (ophead? x) (nom? <x ? (glook <x ugrip ? 1 0) 0)
   (infix3? t) (3 = tally t ? (ophead? t) 0)
   (uxw x) (? (nom? x) x (two? x) (unfix x) x)
   (uxs x g) (? (nom? x) `(x)
                !(two? x) `(x)
                (infix3? x) (glook <x ugrip < g ? `((unfix x)) (unfix x))
                (ophead? x) `((unfix x))
                (unfix x))
   (unfix t) (? (nom? t) t
                !(two? t) t
                (infix3? t) (: g (glook <t ugrip)
                               (uxs <>t (g + 1) + `(<t) + uxs <>(>t) g))
                (link (uxw <t) (map uxw >t))))

; --- the field Q[x]/(m) ----------------------------------------------------
(: (vmax a b) (a < b ? b a)
   (vpad v n) (? (n = 0) ()
                 (0 = tally v) (link (q 0 1) (vpad () (n - 1)))
                 (link <v (vpad >v (n - 1))))
   (vzip a b) (0 = tally a ? () (link (<a + <b) (vzip >a >b)))
   (vadd a b) (: n (vmax (tally a) (tally b)) (vzip (vpad a n) (vpad b n)))
   (vscale c v) (map (* c) v)
   (vshift v n) (n = 0 ? v (link (q 0 1) (vshift v (n - 1))))
   (vmul a b) (0 = tally a ? () (vadd (vscale <a b) (vshift (vmul >a b) 1)))
   (vlast v) (1 = tally v ? <v (vlast >v))
   (vinit v) (1 = tally v ? () (link <v (vinit >v)))
   (vrem xd v) (tally v < tally xd + 1 ? (vpad v (tally xd))
                  (vrem xd (vadd (vinit v)
                                 (vshift (vscale (vlast v) xd) (tally v - (tally xd + 1))))))
   (kmul xd a b) (vrem xd (vmul a b))
   (knum d c) (vpad `((q c 1)) d))
