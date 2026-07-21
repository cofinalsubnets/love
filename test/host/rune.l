; --- test/host/rune.l: the rune engine, exactly ---
; NOT in the test/*.l corpus (it loads a crew file and leaks its helpers).
; after the ring/field laws, the corpus is a real disproof: the 19 july 2026
; counterexample to the jacobian conjecture (alpoge, found working with fable),
; verified whole in exact arithmetic --
;   A: det J F = -2, a nonzero constant, symbolically;
;   B: the fiber over (1 -5 3) is THREE distinct points, certified in
;      Q[x]/(m) for m = 129x^3 + 49x - 6 (squarefree: disc /= 0);
;   C: the published rational collision
;      F(0 0 -1/4) = F(1 -3/2 13/2) = F(-1 3/2 13/2) = (-1/4 0 0).
; A with either of B/C contradicts the conjecture's conclusion for F.
;
;   cat test/00-init.l test/host/rune.l | out/host/love

(reads (open "crew/rune/rune.l" "r"))
(reads (open "crew/rune/seal.l" "r"))
(use 'rune)

; --- the module seam: rune registered, the splice + accessor both reach ----
(assert
 (member? 'rune (from ()))                ; the registry lists it
 (member? 'deriv (from 'rune 'keys))      ; 'keys introspects the layer
 (1 = ((from 'rune 'cnorm) (q 3 3)))      ; the opaque accessor reaches a member
 (lit? (from 'rune))                      ; presence: the accessor is a closure
 (! (from 'ruin)))                        ; a missing module answers ()

; --- the ring: canonical forms make the identities structural --------------
; commutative/associative/distributive, (x+y)^2, and the zero polynomial IS
; (): x - x vanishes to nothing, the empty sum.
(: rx (pvar 3 0) ry (pvar 3 1) rz (pvar 3 2)
   (psq p) (pmul p p))
(assert
 ((padd rx ry) = (padd ry rx))
 ((pmul rx (pmul ry rz)) = (pmul (pmul rx ry) rz))
 ((pmul rx (padd ry rz)) = (padd (pmul rx ry) (pmul rx rz)))
 ((psq (padd rx ry)) = (padd (psq rx) (padd (pmul (pconst 3 2) (pmul rx ry)) (psq ry))))
 (0 = tally (psub rx rx))
 ((pmul rx ()) = ()))

; --- the derivative: linear, and the product rule ---------------------------
(: dp (padd (psq rx) (pmul ry rz))
   dq (padd rx (pconst 3 5)))
(assert
 ((pd (padd dp dq) 0) = (padd (pd dp 0) (pd dq 0)))
 ((pd (pmul dp dq) 0) = (padd (pmul dp (pd dq 0)) (pmul (pd dp 0) dq)))
 ((pd (pconst 3 7) 1) = ()))

; --- the determinant: multilinear, alternating -----------------------------
(: drow `(rx ry rz)
   drow3 `((pconst 3 1) () ())
   done `((pconst 3 2))
   dd1 `(rx () ())
   dd2 `(() ry ())
   dd3 `(() () rz))
(assert
 ((pdet `(done)) = (pconst 3 2))
 ((pdet `(drow drow drow3)) = ())                ; equal rows kill it
 ((pdet `(dd1 dd2 dd3)) = (pmul rx (pmul ry rz))))

; --- gcd: euclid in Q[x], monic ----------------------------------------------
; pmod/pgcd ride the ring's own exact arithmetic; the flagship reproves the
; disproof's squarefreeness fact -- m = 129x^3 + 49x - 6 has gcd(m, m') = 1,
; the disc /= 0 certificate by euclid this time.
(: gx (pvar 1 0)
   (gc c) (pconst 1 c)
   g1 (padd gx (gc 1))
   g2 (padd gx (gc 2))
   g3 (padd gx (gc 3))
   gn (padd gx (gc -1))
   gm (padd (pmul (gc 129) (pmul gx (pmul gx gx))) (padd (pmul (gc 49) gx) (gc -6))))
(assert
 ((pgcd (pmul g1 g2) (pmul g1 g3)) = g1)         ; the common factor, monic
 ((pgcd (pmul (gc 2) g1) (pmul (gc 4) g1)) = g1) ; units divide out
 ((pgcd (pmul (gc (q 1 2)) g1) g1) = g1)         ; ... ratio units too
 ((pgcd g1 g2) = (gc 1))                         ; coprime -> the 1 poly
 ((pgcd (pmul g1 g1) (pmul g1 g2)) = g1)         ; a square shares one factor
 ((pgcd (pmul g1 gn) (pmul gn gn)) = gn)         ; a red constant rides: x - 1
 ((pgcd (pmul gm g2) (pmul gm g3)) = (pmonic gm)); a cubic common factor
 ((pgcd g1 ()) = g1)                             ; the zero poly absorbs...
 ((pgcd () g1) = g1)                             ; ... either side
 ((pgcd () ()) = ())
 ((pgcd (poly (pmul g1 g2)) (poly (pmul g1 g3))) = g1)   ; the coin faces load
 ((pgcd gm (pd gm 0)) = (gc 1)))                 ; m is SQUAREFREE: gcd(m, m') = 1

; --- Q[x y z]: coefficients are stars -- integers or ratio coins ------------
; cnorm keeps them canonical: an integer-VALUED coin demotes to its integer,
; so Z[x..] sits inside Q[x..] structurally -- halves that sum whole land
; integer coefficients, = crosses Z and Q, and the zero-drop stays (c = 0).
(: qh (pconst 3 (q 1 2))
   qp (padd (pmul qh rx) ry)                     ; x/2 + y
   qd1 `((pconst 2 (q 1 2)) ())
   qd2 `(() (pconst 2 2)))
(assert
 ((padd qh qh) = (pconst 3 1))                   ; 1/2 + 1/2 DEMOTES to the integer 1
 ((padd qp qp) = (padd rx (pmul (pconst 3 2) ry)))   ; doubles to x + 2y, all integer
 (0 = tally (psub qp qp))                        ; q coefficients vanish exactly
 ((pmul qh (pconst 3 (q 2 3))) = (pconst 3 (q 1 3)))  ; 1/2 * 2/3 = 1/3, reduced
 ((pmul (pconst 3 2) qh) = (pconst 3 1))         ; ... and demotes through mmul too
 ((pd (pmul qh (psq rx)) 0) = rx)                ; d/dx x^2/2 = x: the 2 cancels the half
 ((pconst 3 (q 0 1)) = ())                       ; a value-zero coin is NO constant
 ((pconst 3 (q 4 2)) = (pconst 3 2))             ; an integer-valued coin enters demoted
 ((pdet `(qd1 qd2)) = (pconst 2 1))              ; det diag(1/2 2) = 1: q entries, integer det
 ((- (poly qp) (poly qp)) = (poly ()))           ; the coin face rides the same ring
 ((q 3 2) = ((pfn qp '(x y z)) 1 1 0))           ; compiled: 1/2 + 1 = 3/2
 ((q 4 1) = ((pfn qp '(x y z)) 2 3 0)))          ; a mixed evaluation LANDS a coin: (q 4 1), not 4

; --- the poly coin: polynomials first-class under + - * and ! ---------------
; the zero polynomial is the coin over (); ! reads "is the zero polynomial"
; even when the coefficients sum red -- the trap the raw layer carries
; ((0 = tally p) there), closed by net-mode 1 on the die.
(: zp (poly ())
   pp1 (poly (padd rx ry))
   pp2 (poly (psub rx (pmul (pconst 3 2) ry))))    ; x - 2y: content sums RED
(assert
 (coin? pp1)
 ((+ pp1 pp1) = (poly (pmul (pconst 3 2) (padd rx ry))))
 ((* (poly rx) (poly ry)) = (poly (pmul rx ry)))
 ((- pp1 pp1) = zp)                    ; subtraction lands the zero COIN
 ((* pp1 zp) = zp)                     ; annihilation -- the zero poly, not the () unit ride
 ((* 3 (poly rx)) = (poly (pmul (pconst 3 3) rx)))   ; a star lifts to the poly's arity
 ((+ (poly rx) 1) = (poly (padd rx (pconst 3 1))))   ; ... either side, + too
 ((- (poly rx) 1) = (poly (psub rx (pconst 3 1))))
 (! zp)                                ; the zero polynomial IS nothing
 (nil? (! pp2))                        ; red content, still SOMETHING -- the !p law, closed
 (2 = (sat pp2))                       ; $ counts monomials
 (nil? (+ pp1 (q 1 2)))                ; distinct dies never combine
 (nil? (* pp1 "s"))                    ; a method owns its domain
 ((* 5 zp) = zp)                       ; star times the zero poly IS the zero poly (no arity needed)
 ((* zp 5) = zp)
 (nil? (+ 5 zp))                       ; ... but + there stays (): the arity is unknowable
 ((2 (poly rx)) = (poly (pmul rx rx))) ; polys are STARS (slot 7): a numeral squares through *
 (((poly rx) ** 3) = (poly (pmul rx (pmul rx rx))))
 ((3 zp) = zp)                         ; the zero poly powers to itself
 (1 = (0 (poly rx)))                   ; the zero numeral: p**0 = 1
 (star? pp1)                           ; a declared star self-nets: the vocabulary follows
 (star? zp)                            ; the zero poly is a star, like 0
 ((net (L pp1 pp1)) = (+ pp1 pp1)))    ; net of a list of polys is their SUM -- the hom in the ring

; --- the field: Q[x]/(x^2 - 2), where root-two squares to two --------------
(: sq2xd `((q 2 1) (q 0 1))                     ; x^2 == 2
   sq2 `((q 0 1) (q 1 1)))
(assert
 ((kmul sq2xd sq2 sq2) = (knum 2 2))
 ((kmul sq2xd (vadd sq2 (knum 2 1)) (vadd sq2 (vscale (q -1 1) (knum 2 1))))
  = (knum 2 1)))                                ; (1+r2)(r2-1) = 1

; --- the disproof, part A: det J F = -2 ------------------------------------
; F = ((1+xy)^3 z + y^2 (1+xy)(4+3xy),
;      y + 3x(1+xy)^2 z + 3xy^2 (4+3xy),
;      2x - 3x^2 y - x^3 z)
(: pu (padd (pconst 3 1) (pmul rx ry))
   pw (padd (pconst 3 4) (pmul (pconst 3 3) (pmul rx ry)))
   pu3 (pmul (psq pu) pu)
   pf1 (padd (pmul pu3 rz) (pmul (pmul (psq ry) pu) pw))
   pf2 (padd ry (padd (pmul (pconst 3 3) (pmul (pmul rx (psq pu)) rz))
                      (pmul (pconst 3 3) (pmul (pmul rx (psq ry)) pw))))
   pf3 (psub (psub (pmul (pconst 3 2) rx) (pmul (pconst 3 3) (pmul (psq rx) ry)))
             (pmul (pmul (psq rx) rx) rz))
   jrows (map (\ f (map (pd f) '(0 1 2))) `(pf1 pf2 pf3)))
(assert ((pdet jrows) = (pconst 3 -2)))

; --- part B: three distinct points over (1 -5 3) ---------------------------
; m = 129x^3 + 49x - 6 is squarefree (disc = -76881936), so it has three
; distinct roots; P(x) = (x, y(x), z(x)) below satisfies F(P(x)) == (1 -5 3)
; identically in Q[x]/(m), so each root is a distinct preimage.
(: jxd `((q 6 129) (q -49 129) (q 0 1))         ; x^3 == (6 - 49x)/129
   jdisc ((0 - ((4 * 129) * ((49 * 49) * 49))) - (27 * ((129 * 129) * 36)))
   kx `((q 0 1) (q 1 1) (q 0 1))
   ky `((q -2533 386) (q 387 386) (q -6192 386))
   kz `((q -2172963 1544) (q -336303 772) (q -5446251 1544))
   kxy (kmul jxd kx ky)
   ku (vadd (knum 3 1) kxy)
   ku2 (kmul jxd ku ku)
   ku3 (kmul jxd ku2 ku)
   ky2 (kmul jxd ky ky)
   kx2 (kmul jxd kx kx)
   kw (vadd (knum 3 4) (vscale (q 3 1) kxy))
   kg1 (vadd (kmul jxd ku3 kz) (kmul jxd (kmul jxd ky2 ku) kw))
   kg2 (vadd (vadd (vpad ky 3) (vscale (q 3 1) (kmul jxd (kmul jxd kx ku2) kz)))
             (vscale (q 3 1) (kmul jxd (kmul jxd kx ky2) kw)))
   kg3 (vadd (vadd (vscale (q 2 1) kx) (vscale (q -3 1) (kmul jxd kx2 ky)))
             (vscale (q -1 1) (kmul jxd (kmul jxd kx2 kx) kz))))
(assert
 (! (jdisc = 0))
 (kg1 = (knum 3 1))
 (kg2 = (knum 3 -5))
 (kg3 = (knum 3 3)))

; --- part C: the published rational collision ------------------------------
; three distinct rational points, one image, by plain q-coin evaluation of F.
(: (feval xx yy zz)
   (: uu (+ 1 (* xx yy))
      ww (+ 4 (* 3 (* xx yy)))
      us (* uu uu)
      ys (* yy yy)
      xs (* xx xx)
      `((+ (* (* us uu) zz) (* (* ys uu) ww))
        (+ yy (+ (* 3 (* (* xx us) zz)) (* 3 (* (* xx ys) ww))))
        (+ (* 2 xx) (+ (* -3 (* xs yy)) (* -1 (* (* xs xx) zz))))))
   cin1 `((q 0 1) (q 0 1) (q -1 4))
   cin2 `((q 1 1) (q -3 2) (q 13 2))
   cin3 `((q -1 1) (q 3 2) (q 13 2))
   cimg `((q -1 4) (q 0 1) (q 0 1)))
(assert
 (! (cin1 = cin2)) (! (cin2 = cin3)) (! (cin1 = cin3))
 ((feval (q 0 1) (q 0 1) (q -1 4)) = cimg)
 ((feval (q 1 1) (q -3 2) (q 13 2)) = cimg)
 ((feval (q -1 1) (q 3 2) (q 13 2)) = cimg))

; --- the eval bridge: polys compile to live closures ------------------------
; folded dyadic + * ** (the bound base-first power, exact through DIE_STAR),
; so one closure computes over integers and q coins alike. the flagship: F1 and F3 of the counterexample,
; COMPILED, evaluated at the published collision point -- the same -1/4 and 0
; the modular certificate proved, now through ev'd code. a mixed evaluation
; lands a coin, so zero reads (q 0 1), never the fixnum 0.
(: xyz '(x y z)
   ef1 (pfn pp1 xyz)                       ; x+y, from the COIN face
   ef2 (pfn (pd (load pp2) 0) xyz)         ; d(x-2y)/dx = 1
   ef3 (pfn (pmul (pmul rx rx) ry) xyz)    ; x^2 y: a power, ('** x 2)
   efd (pfn (pdet jrows) xyz)              ; det J F compiles to const -2
   efz (pfn (poly ()) xyz)                 ; the zero poly compiles to 0
   eF1 (pfn pf1 xyz)
   eF3 (pfn pf3 xyz))
(assert
 (5 = (ef1 2 3 0))
 ((q 5 6) = (ef1 (q 1 2) (q 1 3) 0))       ; rationals ride the SAME closure
 (1 = (ef2 9 9 9))
 (12 = (ef3 2 3 0))                        ; 4*3
 ((q 3 4) = (ef3 (q 1 2) 3 0))             ; a power over a coin stays total
 (-2 = (efd 5 7 11))
 (0 = (efz 1 2 3))
 ((q -1 4) = (eF1 1 (q -3 2) (q 13 2)))    ; compiled F1 at the collision point
 ((q 0 1) = (eF3 1 (q -3 2) (q 13 2))))    ; compiled F3 there: exactly zero

; --- the matcher: laws as data, rewritten to a fixpoint ----------------------
; patterns are terms with kanren vars; unify matches, so a var shared across
; positions is a nonlinear pattern, and a coin literal matches by VALUE. the
; term language is pemit's own, so rules rewrite compiled-poly source too.
(: srules `((rule '(a) '(+ a 0) 'a)
          (rule '(a) '(+ 0 a) 'a)
          (rule '(a) '(* a 1) 'a)
          (rule '(a) '(* 1 a) 'a)
          (rule '(a) '(* a 0) 0)
          (rule '(a) '(* 0 a) 0)
          (rule '(a) '(- a a) 0)
          (rule '(a) '(+ (* (sin a) (sin a)) (* (cos a) (cos a))) 1))
   dbl (rule '(a) '(+ a a) '(* 2 a))
   hlf (rule '(a) `('* 'a (q 1 2)) `('/ 'a 2)))
(assert
 ((rewrite srules '(+ x 0)) = 'x)
 ((rewrite srules '(* (+ x 0) 1)) = 'x)                    ; inner rewrite feeds the root
 ((rewrite srules '(+ (* x 0) (* 1 y))) = 'y)              ; two rules meet at the root
 ((rewrite srules '(sin (* x 0))) = '(sin 0))              ; rewrites under ANY head
 ((rewrite srules '(- (+ x y) (+ x y))) = 0)               ; NONLINEAR: one var, two positions
 ((rewrite srules '(- (+ x y) (+ x z))) = '(- (+ x y) (+ x z)))   ; ... agree, or no match
 ((rewrite srules '(+ (* (sin t) (sin t)) (* (cos t) (cos t)))) = 1)  ; pythagoras, structurally
 ((match '(+ 1 2) '(+ 1 3)) = ())                        ; a miss is ()
 ((rw1 `(dbl) '(+ (sin u) (sin u))) = '(* 2 (sin u)))    ; the bound var fills the template
 ((rw1 `(hlf) `('* 'z (q 2 4))) = '(/ z 2))              ; a coin literal matches by VALUE
 ((rw1 `((rule '(a b) '(+ a b) '(+ b a))) (pemit (padd rx ry) '(x y z)))
  = '(+ y x)))                                           ; terms ARE pemit's language

; --- the simplifier: laws + ground folding, bottom-up to a fixpoint ----------
; the shipped `laws` table plus fold1 (a ground + - * node computes, cnormed);
; division never folds -- exactness is kept symbolic.
(assert
 (6 = (simp '(+ (* 2 3) (* x 0))))                    ; fold meets annihilation
 (0 = (simp '(- (* 3 4) (* 4 3))))                    ; folds, then x - x
 ((simp `('+ 'x `('* 2 (q 1 2)))) = '(+ x 1))         ; a coin folds and DEMOTES to its integer
 (0 = (simp '(* (+ 1 2) (- x x))))
 ((simp '(sin (+ 0 x))) = '(sin x))                   ; simplifies under any head
 ((simp '(/ x 1)) = 'x)                               ; division simplifies by law...
 ((simp '(/ 1 2)) = (q 1 2))                          ; ... and a ground quotient folds
                                                      ; EXACTLY: Q the codomain, never a gem
 (2 = (simp '(/ 6 3)))                                ; a whole quotient demotes
 ((simp '(/ -1 4)) = (q -1 4))                        ; the sign lands on the numerator
 ((simp '(/ 1 0)) = '(/ 1 0))                         ; a zero divisor keeps its term
 (1.5 = (simp '(/ 3.0 2)))                            ; a gem quotient stays in its band
 (1 = (simp '(+ (* (sin (+ y 0)) (sin y)) (* (cos y) (cos y)))))  ; the inner fix
                                                      ; opens pythagoras at the root
 ((simp '(log (exp x))) = 'x)                         ; the log/exp cancellations...
 ((simp '(exp (log x))) = 'x)
 (1 = (simp '(exp 0)))                                ; ... and their ground points
 (0 = (simp '(log 1)))
 ((simp '(* x (+ y z))) = '(* x (+ y z)))             ; simp never grows -- expand does
 (8 = (simp '(** 2 3)))                               ; a ground power folds by application...
 ((simp `('** (q 1 2) 2)) = (q 1 4))                  ; ... exactly, through the die
 ((simp '(** x 1)) = 'x)                              ; the power units
 (1 = (simp '(** x 0)))
 (1 = (simp '(** 1 x)))
 ((simp '(** x 2)) = '(** x 2))                       ; a symbolic base stays
 ((simp '(** 2 -1)) = (q 1 2))                        ; a negative exponent folds into Q too
 ((simp '(** 2 -3)) = (q 1 8))
 ((simp `('** (q 2 3) -2)) = (q 9 4))                 ; ... the die's own reciprocal power
 ((simp '(** 0 -2)) = '(** 0 -2)))                    ; zero has no reciprocal: the term stays

; --- expand: the growing laws -- distribution and the log/exp splits ---------
; xlaws rides the same driver on top of laws, so every expansion is folded
; and collected on the way.
(assert
 ((expand '(* x (+ y z))) = '(+ (* x y) (* x z)))     ; a * pushes inside a +
 ((expand '(* (+ x y) z)) = '(+ (* x z) (* y z)))     ; ... either side
 ((expand '(* (+ x y) (+ x y)))
  = '(+ (** x 2) (+ (* 2 (* x y)) (** y 2))))         ; THE binomial: x^2 + 2xy + y^2 --
                                                      ; collected, powered, degree-ordered
 ((expand '(* (+ x 1) (+ x 1)))
  = '(+ (** x 2) (+ (* 2 x) 1)))                      ; ... x^2 + 2x + 1, the constant last
 ((expand '(* (+ x y) (- x y))) = '(- (** x 2) (** y 2)))  ; the difference of squares:
 ((expand '(* (- x y) (+ x y))) = '(- (** x 2) (** y 2)))  ; ... the cross terms cancel
 ((expand '(* (+ x 1) (- x 1))) = '(- (** x 2) 1))
 ((expand '(* (- x y) (- x y)))
  = '(- (+ (** x 2) (** y 2)) (* 2 (* x y))))         ; (x-y)^2: the red term subtracted last
 ((expand '(exp (- x y))) = '(/ (exp x) (exp y)))     ; an exp splits a difference
 (49 = (expand '(* (+ 3 4) (+ 3 4))))                 ; ground folds before it distributes
 ((expand '(log (* x y))) = '(+ (log x) (log y)))     ; a log splits a product
 ((expand '(log (/ (* x y) z))) = '(- (+ (log x) (log y)) (log z)))
 ((expand '(exp (+ x y))) = '(* (exp x) (exp y)))     ; an exp splits a sum
 ((expand '(log (** x y))) = '(* y (log x)))          ; ... and drops a power
 ((expand '(log (* x x))) = '(* 2 (log x)))           ; split, then collect
 ((expand '(log (exp (+ x y)))) = '(+ x y)))          ; the splits meet the cancellations

; --- collect: the commutative collect ----------------------------------------
; +/-/* spines canonicalize: flatten (- carries its sign through, so
; subtraction is a signed addend), sort, merge equal cores summing
; coefficients exactly, refold -- red terms return to the surface as -,
; repeated factors POWER-COLLECT into (** u n), and sums order by degree
; descending. structural order, so equal terms MEET whatever their
; spelling; / is left alone.
(assert
 ((collect '(* x x)) = '(** x 2))                     ; repeated factors power up...
 ((collect '(* x (* x x))) = '(** x 3))               ; ... across the assoc nesting
 ((collect '(* x (** x 2))) = '(** x 3))              ; a factor joins its power
 ((collect '(* (** x 2) (** x 3))) = '(** x 5))       ; powers merge, exponents add
 ((collect '(* (exp y) (exp y))) = '(** (exp y) 2))   ; any base powers up
 ((collect '(* x (** x -1))) = '(* x (** x -1)))      ; a red exponent NEVER merges:
                                                      ; x might be 0, and 0**0 is no 1
 ((collect '(* y (* x x))) = '(* (** x 2) y))         ; powers ride the base's sort seat
 ((collect '(+ y x)) = '(+ x y))                      ; a sum sorts...
 ((collect '(* y x)) = '(* x y))                      ; ... a product too
 ((collect '(+ (* y x) (* x y))) = '(* 2 (* x y)))    ; (* y x) meets (* x y)
 ((collect '(+ x (+ y x))) = '(+ (* 2 x) y))          ; ... across the assoc nesting
 ((collect '(+ (+ x 1) (+ x 2))) = '(+ (* 2 x) 3))    ; constants merge, and sit last
 ((collect '(+ (* 2 x) (* 3 x))) = '(* 5 x))          ; coefficients add
 ((collect '(+ (* 2 x) (* -2 x))) = 0)                ; ... and cancel to the empty sum
 ((collect `('+ `('+ 'x (q 1 2)) `('+ 'x (q 1 2))))
  = '(+ (* 2 x) 1))                                   ; exact halves merge whole
 ((collect '(* 3 (* x 2))) = '(* 6 x))                ; ground factors gather up front
 ((collect '(* x (* 2 (* y (* 3 z))))) = '(* 6 (* x (* y z))))
 ((collect '(- (+ y x) z)) = '(- (+ x y) z))          ; - rides the flatten as a sign
 ((collect '(- x (- x y))) = 'y)                      ; ... and cancels through nesting
 ((collect '(+ (- 0 y) 3)) = '(- 3 y))                ; a red term crosses the sum
 ((collect '(- 0 y)) = '(- 0 y))                      ; pure negation round-trips
 ((collect '(- 2 5)) = -3)                            ; a lone ground red is the signed star
 ((collect '(- (+ x y) (+ y x))) = 0)                 ; all of it cancels
 ((collect 'x) = 'x))

; --- conditional laws: the guard door, open ----------------------------------
; the division identities need x /= 0, so they fire on nz? -- the "manifestly
; nonzero" certificate: a value-nonzero ground star (the square-sat test, so
; a red star certifies), an exp form, a power of one. no certificate, no
; rewrite: a/a simplifies by PROOF, never by assumption.
(assert
 (1 = (simp '(/ 3 3)))                                ; ground nonzero: fires
 (1 = (simp '(/ -5 -5)))                              ; a red star certifies (the square test)
 ((simp '(/ x x)) = '(/ x x))                         ; symbolic: x might be 0 -- stays
 ((simp '(/ 0 0)) = '(/ 0 0))                         ; 0/0 is (): never 1, never 0
 (1 = (simp '(/ (exp x) (exp x))))                    ; exp is never 0: a structural certificate
 (0 = (simp '(/ 0 (exp y))))
 ((simp '(/ 0 x)) = '(/ 0 x))                         ; ... but 0/x stays
 ((simp '(/ (* x (exp y)) (exp y))) = 'x)             ; cancellation, certified
 ((simp '(/ (* (exp y) x) (exp y))) = 'x)             ; ... either side
 ((simp '(/ (* x y) y)) = '(/ (* x y) y))             ; uncertified: stays
 (1 = (simp `('/ (q 1 2) (q 2 4))))                   ; a coin pair matches by VALUE, nonzero
 ((simp '(/ (* x (** (exp z) 2)) (** (exp z) 2))) = 'x))  ; nz? climbs the power

; --- symbolic d: the derivative as a rule set, the guard doing the base case --
; (d a v) -> 0 rides the matcher's GUARDED rule (fires only when a is free? of
; v); (d a a) -> 1 the nonlinear pattern; sum/product/quotient/chain plain
; patterns. deriv drives the result through simp AND collect, so answers
; land canonical: coefficient first, powers powered, degree order.
(assert
 (0 = (deriv 'y 'x))                              ; free of x: the guarded base
 (0 = (deriv 5 'x))
 (1 = (deriv 'x 'x))                              ; d x/dx: the nonlinear rule
 (2 = (deriv '(* 2 x) 'x))
 ((deriv '(* x x) 'x) = '(* 2 x))                 ; the product rule, collected
 ((deriv '(+ (* x x) (* 3 x)) 'x) = '(+ (* 2 x) 3))
 ((deriv '(sin x) 'x) = '(cos x))
 ((deriv '(cos x) 'x) = '(- 0 (sin x)))
 ((deriv '(sin (* 2 x)) 'x) = '(* 2 (cos (* 2 x))))   ; the chain rule, coefficient first
 ((deriv '(/ 1 x) 'x) = '(/ -1 (** x 2)))         ; the quotient rule, folded red
 ((deriv '(/ x 2) 'x) = (q 1 2))                  ; ... and a ground answer lands in Q
 ((deriv '(exp x) 'x) = '(exp x))                 ; exp is its own derivative
 ((deriv '(exp (* 2 x)) 'x) = '(* 2 (exp (* 2 x))))
 ((deriv '(log x) 'x) = '(/ 1 x))
 ((deriv '(** x 3) 'x) = '(* 3 (** x 2)))         ; the power rule
 ((deriv '(** (sin x) 2) 'x) = '(* 2 (* (cos x) (sin x))))   ; ... with the chain
 ((deriv '(* (- x 1) (+ x 1)) 'x) = '(* 2 x))     ; product rule + collect: the whole road
 ((deriv '(** x x) 'x) = '(d (** x x) x))         ; a symbolic exponent fails the
                                                  ; guard and stays, honestly
 ((deriv '(f x) 'x) = '(d (f x) x))               ; an unknown derivative stays symbolic
 ((deriv `('+ `('sin 'x) `('* 'x (q 1 2))) 'x) = `('+ '(cos x) (q 1 2)))  ; exact halves ride
 ((simp '(+ z z)) = '(* 2 z))                     ; the collect law that tidies d
 ((deriv (pemit (psq rx) '(x y z)) 'x)
  = (pemit (pd (psq rx) 0) '(x y z))))            ; d agrees with pd through the bridge

; --- unfix: terms back to the infix surface, as FORMS ------------------------
; low-paren infix source values: show prints them, ev runs them, and
; (opfix (unfix t)) = t is the round-trip law, over the corpus below.
(: tcorp `('(+ (* 2 x) 1) '(* 2 (+ x 1)) '(- (- 10 4) 3) '(- 10 (- 4 3))
           '(+ (sin x) 1) '(* 2 (sin (+ x 1))) '(f (+ x 1) y) '(+ (f x y) 1)
           '(* (** 2 x) (+ y 1)) `('+ 'x (q 1 2)) '(f (g x) y) '(* (+ a b) (+ c d))
           '(+ (log x) (* 2 (exp x)))
           (pemit (padd (pmul rx rx) ry) '(x y z))))
(assert
 ((unfix '(+ (* 2 x) 1)) = '(2 * x + 1))
 ((unfix '(* 2 (+ x 1))) = '(2 * (x + 1)))            ; a looser right child wraps
 ((unfix '(- (- 10 4) 3)) = '((10 - 4) - 3))          ; a left child wraps at its own band
 ((unfix '(- 10 (- 4 3))) = '(10 - 4 - 3))            ; ... the right rides the fold bare
 ((unfix '(+ (sin x) 1)) = '(sin x + 1))              ; application binds tightest
 ((unfix '(f (+ x 1) y)) = '(f (x + 1) y))            ; compound arguments wrap
 ((unfix (pemit (padd (pmul rx rx) ry) '(x y z))) = '(x ** 2 + y))  ; a poly, rendered
 ((unfix 'x) = 'x)
 (all (\ t ((opfix (unfix t)) = t)) tcorp)            ; THE round-trip law
 (7 = (ev (unfix '(+ (* 2 3) 1)))))                   ; the rendered form is love source: it runs

(puts "rune: ok")
