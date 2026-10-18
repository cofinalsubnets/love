; test/host/rune.l -- src/apps/rune.l's ring and field laws, then a jacobian conjecture
; counterexample in exact arithmetic: A det J F = -2; B three points over (1 -5 3); C a rational collision
; not in the corpus: it fails love0's second run. run: cat test/00-init.l test/host/rune.l | out/love

(borrow "src/apps/rune.l")

; --- the module seam
(test
 (elem 'rune (cite ()))
 (elem 'deriv (keys (cite 'rune)))
 (1 = cite 'rune 'cnorm (3 /// 3))
 (lit? (cite 'rune))
 !(cite 'ruin))                        ; a missing module answers ()

; --- the ring; the zero polynomial is ()
(: rx (pvar 3 0) ry (pvar 3 1) rz (pvar 3 2)
   (psq p) (pmul p p))
(test
 (padd rx ry = padd ry rx)
 (pmul rx (pmul ry rz) = pmul (pmul rx ry) rz)
 (pmul rx (padd ry rz) = padd (pmul rx ry) (pmul rx rz))
 (psq (padd rx ry) = padd (psq rx) (padd (pmul (pconst 3 2) (pmul rx ry)) (psq ry)))
 (0 = tally (psub rx rx))
 (pmul rx () = ()))

; --- the derivative: linear, and the product rule
(: dp (padd (psq rx) (pmul ry rz))
   dq (padd rx (pconst 3 5)))
(test
 (pd (padd dp dq) 0 = padd (pd dp 0) (pd dq 0))
 (pd (pmul dp dq) 0 = padd (pmul dp (pd dq 0)) (pmul (pd dp 0) dq))
 (pd (pconst 3 7) 1 = ()))

; --- the determinant: multilinear, alternating
(: drow [rx ry rz]
   drow3 [(pconst 3 1) () ()]
   done [(pconst 3 2)]
   dd1 [rx () ()]
   dd2 [() ry ()]
   dd3 [() () rz])
(test
 (pdet [done] = pconst 3 2)
 (pdet [drow drow drow3] = ())                 ; equal rows kill it
 (pdet [dd1 dd2 dd3] = pmul rx (pmul ry rz)))

; --- gcd: euclid in Q[x], monic; reproves B's gcd(m, m') = 1
(: gx (pvar 1 0)
   (gc c) (pconst 1 c)
   g1 (padd gx (gc 1))
   g2 (padd gx (gc 2))
   g3 (padd gx (gc 3))
   gn (padd gx (gc -1))
   gm (padd (pmul (gc 129) (pmul gx (pmul gx gx))) (padd (pmul (gc 49) gx) (gc -6))))
(test
 (pgcd (pmul g1 g2) (pmul g1 g3) = g1)
 (pgcd (pmul (gc 2) g1) (pmul (gc 4) g1) = g1) ; units divide out
 (pgcd (pmul (gc (1 /// 2)) g1) g1 = g1)         ; ... ratio units too
 (pgcd g1 g2 = gc 1)
 (pgcd (pmul g1 g1) (pmul g1 g2) = g1)
 (pgcd (pmul g1 gn) (pmul gn gn) = gn)         ; a red constant rides: x - 1
 (pgcd (pmul gm g2) (pmul gm g3) = pmonic gm)
 (pgcd g1 () = g1)                             ; the zero poly absorbs, either side
 (pgcd () g1 = g1)
 (pgcd () () = ())
 (pgcd (poly (pmul g1 g2)) (poly (pmul g1 g3)) = g1)   ; the coin faces load
 (pgcd gm (pd gm 0) = gc 1))                 ; m is squarefree: gcd(m, m') = 1

; --- squarefree factorization: yun's algorithm over the gcd
; (psff p) = (a1 a2 ..), each monic squarefree, with monic p = a1^1 * a2^2 * ..
(: (rebuild fs) (: (go i r) (0 = tally r ? (gc 1) (pmul (load (i (poly <r))) (go (i + 1) >r)))
                   (go 1 fs)))
(test
 (psff (pmul g1 g2) = [(pmul g1 g2)])
 (psff (pmul g1 (pmul g1 g2)) = [g2 g1])       ; (x+1)^2 (x+2): (x+2)^1 (x+1)^2
 (psff (pmul (gc 3) (pmul g1 g1)) = [(gc 1) g1])    ; the unit drops, slot 1 empty
 (psff (pmul g1 (pmul g1 (pmul g1 g2)))
  = [g2 (gc 1) g1])                              ; a cube: the middle slot is 1
 (psff gm = [(pmonic gm)])
 (psff (gc 5) = ())
 (psff () = ())
 (psff (poly (pmul g1 g1)) = [(gc 1) g1])
 (rebuild (psff (pmul gm (pmul gm g2)))
  = pmonic (pmul gm (pmul gm g2))))            ; reconstruction, degree 7

; --- multivariate gcd: content times primitive part, by pseudo-remainder; lex-lead 1
(: u1 (padd rx ry)
   u2 (padd rx rz)
   u3 (padd ry rz))
(test
 (mgcd (pmul u1 u2) (pmul u1 u3) = u1)
 (mgcd (pmul u1 (pmul u1 u2)) (pmul u1 (pmul u1 u3))
  = pmul u1 u1)
 (mgcd u1 u2 = pconst 3 1)
 (mgcd (pconst 3 5) u1 = pconst 3 1)         ; a constant is a unit
 (mgcd (pmul (pconst 3 2) u1) (pmul (pconst 3 4) u1) = u1)   ; units divide out
 (mgcd (pmul (pconst 3 (1 /// 2)) u1) u1 = u1)   ; ... ratio units too
 (mgcd (pmul rx ry) (pmul rx rz) = rx)
 (mgcd (pmul ry rz) (pmul ry ry) = ry)         ; a gcd free of x: the content path
 (mgcd (psub (pmul rx rx) (pmul ry ry)) (pmul u1 u1) = u1)
 (mgcd u1 () = u1)                             ; the zero poly absorbs, either side
 (mgcd () u1 = u1)
 (mgcd (poly (pmul u1 u2)) (poly (pmul u1 u3)) = u1)
 (mgcd (pmul g1 g2) (pmul g1 g3) = g1))        ; arity 1 rides pgcd, same answer

; --- rational roots: proots with multiplicity, ascending; pfac's product is p. a rootless
; degree 2 or 3 is irreducible over Q, so m makes Q[x]/(m) a field
(: (refac fs) (0 = tally fs ? (gc 1) (pmul <fs (refac >fs))))
(test
 (proots (pmul g1 g2) = [-2 -1])
 (proots (pmul g1 g1) = [-1 -1])               ; multiplicity rides psff
 (proots (pmul gx g1) = [-1 0])
 (proots (padd (pmul (gc 2) gx) (gc 1)) = [(-1 /// 2)])    ; a coin root, exact
 (proots (padd (pmul (gc 6) (pmul gx gx)) (padd (pmul (gc 5) gx) (gc 1)))
  = [(-1 /// 2) (-1 /// 3)])
 (proots (pmul (gc 3) (pmul g1 g2)) = [-2 -1]) ; roots are unit-blind
 (proots (padd (pmul gx gx) (gc -2)) = ())
 (proots gm = ())                              ; m is a rootless cubic: irreducible
 (proots () = ())
 (pfac (pmul g1 g2) = [g2 g1])
 (pfac (pmul (gc 6) (pmul g1 g2))
  = [(gc 6) g2 g1])                              ; the lead rides as a constant factor
 (pfac (padd (pmul gx gx) (gc -2))
  = [(padd (pmul gx gx) (gc -2))])               ; an irreducible quadratic keeps whole
 (pfac gm = [(gc 129) (pmonic gm)])
 (pfac (poly (pmul g1 g1)) = [g1 g1])
 (pmul (gc 6) (pmul gm (pmul g1 (pmul g1 g2))) @ big
    (refac (pfac big) = big)))

; --- zassenhaus: degree 4 up by berlekamp mod p, hensel to p^K, recombination; through the
; monic reduction, so every candidate divides or dies over Z
(: q1 (padd (pmul gx gx) (gc 1))                 ; x^2+1
   q2 (padd (pmul gx gx) (gc 2))                 ; x^2+2
   q3 (padd (pmul gx gx) (padd gx (gc 1)))       ; x^2+x+1
   q4 (padd (pmul gx gx) (padd (pmul (gc -1) gx) (gc 1)))   ; x^2-x+1
   x6 (padd (pmul gx (pmul gx (pmul gx (pmul gx (pmul gx gx))))) (gc -1))
   phi5 (padd (pmul gx (pmul gx (pmul gx gx)))
              (padd (pmul gx (pmul gx gx)) (padd (pmul gx gx) (padd gx (gc 1))))))
(test
 (pfac (pmul q1 q2) = [q2 q1])                 ; two quadratics, invisible to rational roots
 (pfac (pmul q3 q4) = [q4 q3])                 ; x^4+x^2+1, no rational roots at all
 (pfac x6 = [g1 gn q4 q3])
 (refac (pfac x6) = x6)
 (pfac (pmul q1 q1) = [q1 q1])
 (pfac phi5 = [phi5])                          ; the fifth cyclotomic: irreducible
 (pfac (padd (pmul gx (pmul gx (pmul gx gx))) (padd gx (gc 1)))
  = [(padd (pmul gx (pmul gx (pmul gx gx))) (padd gx (gc 1)))])
 (pfac (padd (pmul (gc 2) (pmul gx gx)) gx)
  = [(gc 2) gx (padd gx (gc (1 /// 2)))])          ; the zero root keeps x canonical
 (pmul (gc 6) (pmul q1 (pmul q3 g1)) @ bigz
    (refac (pfac bigz) = bigz)))

; --- pdeep's monic reduction: G(y) = L^(n-1) g(y/L) scales x^e by L^(n-1-e). it bites only
; on a rootless degree-4 primitive part with lc /= +-1: (2x^2+3)(3x^2+2), lc 6
(: lc1 (padd (pmul (gc 2) (pmul gx gx)) (gc 3))   ; 2x^2 + 3, irreducible over Q
   lc2 (padd (pmul (gc 3) (pmul gx gx)) (gc 2)))  ; 3x^2 + 2, ditto
(test
 (6 = (mco <(pmul lc1 lc2)))
 (4 = pdeg (pmul lc1 lc2))                     ; ... and degree 4, so pdeep runs
 (proots (pmul lc1 lc2) = ())                  ; no rational roots: nothing strips before pdeep
 (pfac (pmul lc1 lc2)
  = [(gc 6) (padd (pmul gx gx) (gc (3 /// 2))) (padd (pmul gx gx) (gc (2 /// 3)))])
 (refac (pfac (pmul lc1 lc2)) = pmul lc1 lc2))  ; a wrong L power rebuilds to something else

; --- bivariate: evaluate at a good point, factor the image, hensel-lift in powers of y; a
; polynomial lead rides the monic reduction a level up, the x-content factors in Q[y]
(: bx (pvar 2 0)
   by (pvar 2 1)
   (bc c) (pconst 2 c)
   b1 (padd bx by)                               ; x+y
   b2 (padd bx (bc 1))                           ; x+1
   b3 (padd bx (pmul by by))                     ; x+y^2
   bq (padd (pmul bx bx) (padd by (bc 1)))       ; x^2+y+1
   (refac2 fs) (0 = tally fs ? (bc 1) (pmul <fs (refac2 >fs))))
(test
 (pfac (psub (pmul bx bx) (pmul by by))
  = [(psub bx by) b1])
 (pfac (pmul b1 b2) = [b2 b1])
 (pfac (pmul b1 b3) = [b1 b3])
 (pfac (pmul b1 b1) = [b1 b1])                 ; multiplicity via msff, no 1 fillers
 (pfac bq = [bq])
 (pfac (pmul bq b1) = [bq b1])
 (pfac (padd (pmul bx bx) (pmul by by))
  = [(padd (pmul bx bx) (pmul by by))])
 (refac2 (pfac (pmul bq (pmul b1 (pmul b1 b3))))
  = pmul bq (pmul b1 (pmul b1 b3)))
 (padd (pmul by bx) (bc 1) @ byx1              ; yx+1: the polynomial lead
    (pfac (pmul byx1 b1) = [byx1 b1]))         ; the y lead lands on its own factor
 (padd (pmul by bx) (bc 1) @ byx1
    (pfac (pmul byx1 byx1) = [byx1 byx1]))
 (pfac (padd (pmul by bx) (bc 1))
  = [(padd (pmul by bx) (bc 1))])
 (pfac (pmul by bx) = [by bx])                 ; the x-content splits off: xy = y * x
 (pfac (pmul by b2) = [by b2])
 (pfac (psub (pmul by by) (bc 1))
  = [(padd by (bc 1)) (psub by (bc 1))])         ; a pure-y poly routes univariate
 (pfac (pmul (bc 2) (pmul (padd (pmul (bc 2) bx) by) b2))
  = [(bc 4) b2 (padd bx (pmul (bc (1 /// 2)) by))])    ; a constant lead normalizes monic
 (pmul by (pmul (padd (pmul by bx) (bc 1)) (pmul b1 b1)) @ bigl
    (refac2 (pfac bigl) = bigl)))

; --- n variables: kronecker packs the last variable into the one before (injective below D,
; lex order kept) down to two; recombined products certified by exact division
(: tcx (pvar 3 0)
   tcy (pvar 3 1)
   tcz (pvar 3 2)
   (tcc c) (pconst 3 c)
   t1 (padd tcx (padd tcy tcz))                  ; x+y+z
   t2 (padd tcx (pmul tcy tcz))                  ; x+yz
   (refac3 fs) (0 = tally fs ? (tcc 1) (pmul <fs (refac3 >fs))))
(test
 (pfac (pmul t1 t2) = [t1 t2])
 (refac3 (pfac (pmul t1 t2)) = pmul t1 t2)
 (pfac (pmul t1 t1) = [t1 t1])                 ; multiplicity across the pack
 (pfac (padd (pmul tcx tcx) (padd (pmul tcy tcy) (pmul tcz tcz)))
  = [(padd (pmul tcx tcx) (padd (pmul tcy tcy) (pmul tcz tcz)))])
 (pfac (psub (pmul tcx tcx) (pmul tcz tcz))
  = [(padd tcx tcz) (psub tcx tcz)])
 (pfac (pmul tcy (pmul tcz t1))
  = [tcy t1 tcz])                                ; monomial content splits off
 (refac3 (pfac (pmul (tcc 3) (pmul t2 (pmul t1 t1))))
  = pmul (tcc 3) (pmul t2 (pmul t1 t1)))
 (: dx (pvar 4 0) dy (pvar 4 1) dz (pvar 4 2) dw (pvar 4 3)
    (pfac (pmul (padd dx dw) (padd dx (padd dy dz)))
     = [(padd dx dw) (padd dx (padd dy dz))])))   ; four variables: the pack recurses

; --- Q[x y z]: coefficients are integers or ratio coins; cnorm demotes an integer-valued coin
(: qh (pconst 3 (1 /// 2))
   qp (padd (pmul qh rx) ry)
   qd1 [(pconst 2 (1 /// 2)) ()]
   qd2 [() (pconst 2 2)])
(test
 (padd qh qh = pconst 3 1)                   ; 1/2 + 1/2 demotes to the integer 1
 (padd qp qp = padd rx (pmul (pconst 3 2) ry))
 (0 = tally (psub qp qp))
 (pmul qh (pconst 3 (2 /// 3)) = pconst 3 (1 /// 3))
 (pmul (pconst 3 2) qh = pconst 3 1)
 (pd (pmul qh (psq rx)) 0 = rx)                ; d/dx x^2/2 = x: the 2 cancels the half
 (pconst 3 (0 /// 1) = ())                       ; a value-zero coin is no constant
 (pconst 3 (4 /// 2) = pconst 3 2)             ; an integer-valued coin enters demoted
 (pdet [qd1 qd2] = pconst 2 1)
 (poly qp - poly qp = poly ())
 (3 /// 2 = pfn qp '(x y z) 1 1 0)
 (4 /// 1 = pfn qp '(x y z) 2 3 0))            ; a mixed evaluation lands a coin: (4 /// 1), not 4

; --- the poly coin: first-class under + - * and !; the zero polynomial is the coin over (),
; and ! means "is zero" even when the coefficients sum red
(: zp (poly ())
   pp1 (poly (padd rx ry))
   pp2 (poly (psub rx (pmul (pconst 3 2) ry))))    ; x - 2y: content sums red
(test
 (coin? pp1)
 (pp1 + pp1 = poly (pmul (pconst 3 2) (padd rx ry)))
 (poly rx * poly ry = poly (pmul rx ry))
 (pp1 - pp1 = zp)
 (pp1 * zp = zp)                     ; annihilation: the zero poly, not ()
 (3 * poly rx = poly (pmul (pconst 3 3) rx))   ; a star lifts to the poly's arity
 (poly rx + 1 = poly (padd rx (pconst 3 1)))
 (poly rx - 1 = poly (psub rx (pconst 3 1)))
 (poly rx + -1 = poly rx - 1)  ; a red star is a coefficient, not the zero poly
 (poly rx * -2 = poly (pmul (pconst 3 -2) rx))
 (poly rx + 0 = poly rx)         ; ... while the zero star still rides as zero
 !zp
 !!pp2
 (2 = sat pp2)                       ; $ counts monomials
 !(pp1 + 1 /// 2)                ; distinct dies never combine
 !(pp1 * "s")
 (5 * zp = zp)                       ; no arity needed
 (zp * 5 = zp)
 !(5 + zp)                       ; ... but + there stays (): the arity is unknowable
 (2 (poly rx) = poly (pmul rx rx)) ; polys are stars (slot 7): a numeral squares through *
 (((poly rx) ** 3) = poly (pmul rx (pmul rx rx)))
 (3 zp = zp)
 (1 = 0 (poly rx))
 (star? pp1)                           ; a declared star self-nets: the vocabulary follows
 (star? zp)
 (net [pp1 pp1] = pp1 + pp1))

; --- the field: Q[x]/(x^2 - 2), where root-two squares to two
(: sq2xd [(2 /// 1) (0 /// 1)]                      ; x^2 == 2
   sq2 [(0 /// 1) (1 /// 1)])
(test
 (kmul sq2xd sq2 sq2 = knum 2 2)
 (kmul sq2xd (vadd sq2 (knum 2 1)) (vadd sq2 (vscale (-1 /// 1) (knum 2 1)))
  = knum 2 1))                                ; (1+r2)(r2-1) = 1

; --- the disproof, part A: det J F = -2
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
   jrows (map (f \ (map (pd f) '(0 1 2))) [pf1 pf2 pf3]))
(test (pdet jrows = pconst 3 -2))

; --- part B: three distinct points over (1 -5 3)
; m squarefree (disc /= 0) and F(P(x)) == (1 -5 3) in Q[x]/(m): each root a distinct preimage
(: jxd [(6 /// 129) (-49 /// 129) (0 /// 1)]          ; x^3 == (6 - 49x)/129
   jdisc (0 - 4 * 129 * (49 * 49 * 49) - 27 * (129 * 129 * 36))
   kx [(0 /// 1) (1 /// 1) (0 /// 1)]
   ky [(-2533 /// 386) (387 /// 386) (-6192 /// 386)]
   kz [(-2172963 /// 1544) (-336303 /// 772) (-5446251 /// 1544)]
   kxy (kmul jxd kx ky)
   ku (vadd (knum 3 1) kxy)
   ku2 (kmul jxd ku ku)
   ku3 (kmul jxd ku2 ku)
   ky2 (kmul jxd ky ky)
   kx2 (kmul jxd kx kx)
   kw (vadd (knum 3 4) (vscale (3 /// 1) kxy))
   kg1 (vadd (kmul jxd ku3 kz) (kmul jxd (kmul jxd ky2 ku) kw))
   kg2 (vadd (vadd (vpad ky 3) (vscale (3 /// 1) (kmul jxd (kmul jxd kx ku2) kz)))
             (vscale (3 /// 1) (kmul jxd (kmul jxd kx ky2) kw)))
   kg3 (vadd (vadd (vscale (2 /// 1) kx) (vscale (-3 /// 1) (kmul jxd kx2 ky)))
             (vscale (-1 /// 1) (kmul jxd (kmul jxd kx2 kx) kz))))
(test
 !(jdisc = 0)
 (kg1 = knum 3 1)
 (kg2 = knum 3 -5)
 (kg3 = knum 3 3))

; --- part C: the rational collision
(: (feval xx yy zz)
   (: uu (1 + xx * yy)
      ww (4 + 3 * (xx * yy))
      us (uu * uu)
      ys (yy * yy)
      xs (xx * xx)
      [(us * uu * zz + ys * uu * ww)
       (yy + (3 * (xx * us * zz) + 3 * (xx * ys * ww)))
       (2 * xx + (-3 * (xs * yy) + -1 * (xs * xx * zz)))])
   cin1 [(0 /// 1) (0 /// 1) (-1 /// 4)]
   cin2 [(1 /// 1) (-3 /// 2) (13 /// 2)]
   cin3 [(-1 /// 1) (3 /// 2) (13 /// 2)]
   cimg [(-1 /// 4) (0 /// 1) (0 /// 1)])
(test
 !(cin1 = cin2) !(cin2 = cin3) !(cin1 = cin3)
 (feval (0 /// 1) (0 /// 1) (-1 /// 4) = cimg)
 (feval (1 /// 1) (-3 /// 2) (13 /// 2) = cimg)
 (feval (-1 /// 1) (3 /// 2) (13 /// 2) = cimg))

; --- the eval bridge: polys compile to closures over integers and coins alike; f1 and f3 at
; C's collision point. a mixed evaluation lands a coin, so zero reads (0 /// 1)
(: xyz '(x y z)
   ef1 (pfn pp1 xyz)                       ; x+y, from the coin face
   ef2 (pfn (pd (load pp2) 0) xyz)         ; d(x-2y)/dx = 1
   ef3 (pfn (pmul (pmul rx rx) ry) xyz)    ; x^2 y: a power, ('** x 2)
   efd (pfn (pdet jrows) xyz)              ; det J F compiles to const -2
   efz (pfn (poly ()) xyz)                 ; the zero poly compiles to 0
   eF1 (pfn pf1 xyz)
   eF3 (pfn pf3 xyz))
(test
 (5 = ef1 2 3 0)
 (5 /// 6 = ef1 (1 /// 2) (1 /// 3) 0)       ; rationals ride the same closure
 (1 = ef2 9 9 9)
 (12 = ef3 2 3 0)
 (3 /// 4 = ef3 (1 /// 2) 3 0)             ; a power over a coin stays total
 (-2 = efd 5 7 11)
 (0 = efz 1 2 3)
 (-1 /// 4 = eF1 1 (-3 /// 2) (13 /// 2))
 (0 /// 1 = eF3 1 (-3 /// 2) (13 /// 2)))

; --- the matcher: rules rewritten to a fixpoint; a shared var is a nonlinear pattern, a coin
; literal matches by value, and terms are pemit's language
(: srules [(rule '(a) '(+ a 0) 'a)
         (rule '(a) '(+ 0 a) 'a)
         (rule '(a) '(* a 1) 'a)
         (rule '(a) '(* 1 a) 'a)
         (rule '(a) '(* a 0) 0)
         (rule '(a) '(* 0 a) 0)
         (rule '(a) '(- a a) 0)
         (rule '(a) '(+ (* (sin a) (sin a)) (* (cos a) (cos a))) 1)]
   dbl (rule '(a) '(+ a a) '(* 2 a))
   hlf (rule '(a) ['* 'a (1 /// 2)] ['/ 'a 2]))
(test
 (rewrite srules '(+ x 0) = 'x)
 (rewrite srules '(* (+ x 0) 1) = 'x)
 (rewrite srules '(+ (* x 0) (* 1 y)) = 'y)
 (rewrite srules '(sin (* x 0)) = '(sin 0))              ; rewrites under any head
 (rewrite srules '(- (+ x y) (+ x y)) = 0)               ; nonlinear: one var, two positions
 (rewrite srules '(- (+ x y) (+ x z)) = '(- (+ x y) (+ x z)))   ; ... agree, or no match
 (rewrite srules '(+ (* (sin t) (sin t)) (* (cos t) (cos t))) = 1)
 (match '(+ 1 2) '(+ 1 3) = ())                        ; a miss is ()
 (rw1 [dbl] '(+ (sin u) (sin u)) = '(* 2 (sin u)))
 (rw1 [hlf] ['* 'z (2 /// 4)] = '(/ z 2))                ; a coin literal matches by value
 (rw1 [(rule '(a b) '(+ a b) '(+ b a))] (pemit (padd rx ry) '(x y z))
  = '(+ y x)))

; --- the simplifier: `laws` plus ground folding, bottom-up to a fixpoint
(test
 (6 = simp '(+ (* 2 3) (* x 0)))
 (0 = simp '(- (* 3 4) (* 4 3)))
 (simp ['+ 'x ['* 2 (1 /// 2)]] = '(+ x 1))           ; a coin folds and demotes to its integer
 (0 = simp '(* (+ 1 2) (- x x)))
 (simp '(sin (+ 0 x)) = '(sin x))
 (simp '(/ x 1) = 'x)
 (simp '(/ 1 2) = 1 /// 2)                          ; a ground quotient folds into Q
 (2 = simp '(/ 6 3))
 (simp '(/ -1 4) = -1 /// 4)                        ; the sign lands on the numerator
 (simp '(/ 1 0) = '(/ 1 0))                         ; a zero divisor keeps its term
 (1.5 = simp '(/ 3.0 2))                            ; a gem quotient stays in its band
 (1 = simp '(+ (* (sin (+ y 0)) (sin y)) (* (cos y) (cos y))))  ; inner fix opens the root
 (simp '(log (exp x)) = 'x)
 (simp '(exp (log x)) = 'x)
 (1 = simp '(exp 0))
 (0 = simp '(log 1))
 (simp '(* x (+ y z)) = '(* x (+ y z)))             ; simp never grows -- expand does
 (8 = simp '(** 2 3))
 (simp ['** (1 /// 2) 2] = 1 /// 4)
 (simp '(** x 1) = 'x)
 (1 = simp '(** x 0))
 (1 = simp '(** 1 x))
 (simp '(** x 2) = '(** x 2))
 (simp '(** 2 -1) = 1 /// 2)
 (simp '(** 2 -3) = 1 /// 8)
 (simp ['** (2 /// 3) -2] = 9 /// 4)
 (simp '(** 0 -2) = '(** 0 -2))                     ; zero has no reciprocal: the term stays
 (simp '(/ (sin x) (cos x)) = '(tan x))
 (simp '(tan (atan x)) = 'x)
 (0 = simp '(sin 0))
 (1 = simp '(cos 0))
 (0 = simp '(tan 0))
 (simp '(sin (- 0 x)) = '(- 0 (sin x)))
 (simp '(cos (- 0 x)) = '(cos x))
 (1 = simp '(+ (** (sin y) 2) (** (cos y) 2)))
 (1 = simp '(+ (** (cos u) 2) (** (sin u) 2)))
 (0 = simp '(sqrt 0))
 (1 = simp '(sqrt 1))
 (simp '(** (sqrt x) 2) = 'x)                       ; sound on sqrt's own domain
 (simp '(sin (asin x)) = 'x)
 (simp '(cos (acos x)) = 'x)
 (simp '(asin (- 0 x)) = '(- 0 (asin x)))
 (1 = simp '(/ (sqrt (exp y)) (sqrt (exp y))))      ; nz? climbs sqrt to exp
 (0 = simp '(sin pi))
 (-1 = simp '(cos pi))
 (0 = simp '(sin (* 2 pi)))
 (1 = simp ['sin ['* (1 /// 2) 'pi]])                 ; angles spelled coefficient-first
 (0 = simp ['cos ['* (1 /// 2) 'pi]])
 (simp ['sin ['* (1 /// 4) 'pi]] = ['* (1 /// 2) '(sqrt 2)])
 (simp ['sin ['* (1 /// 6) 'pi]] = 1 /// 2)
 (simp ['cos ['* (1 /// 3) 'pi]] = 1 /// 2)
 (simp '(asin 1) = ['* (1 /// 2) 'pi])
 (simp '(acos -1) = 'pi)
 (simp '(atan 1) = ['* (1 /// 4) 'pi])
 (0 = simp '(asin 0))
 (0 = simp '(acos 1))
 (1 = simp '(sin (asin 1)))
 (1 = simp '(/ pi pi))
 (1 = expand ['sin ['* 'pi (1 /// 2)]])               ; a backwards spelling, through collect
 (1 = simp '(log e))
 (simp '(exp 1) = 'e)
 (simp '(** e x) = '(exp x))
 (simp '(** e 2) = '(exp 2))                        ; exact, never a gem
 (simp '(log (** e x)) = 'x)
 (1 = simp '(/ e e)))

; --- expand: distribution and the log/exp splits, folded and collected on the way
(test
 (expand '(* x (+ y z)) = '(+ (* x y) (* x z)))
 (expand '(* (+ x y) z) = '(+ (* x z) (* y z)))
 (expand '(* (+ x y) (+ x y))
  = '(+ (** x 2) (+ (* 2 (* x y)) (** y 2))))         ; the binomial, degree-ordered
 (expand '(* (+ x 1) (+ x 1))
  = '(+ (** x 2) (+ (* 2 x) 1)))                      ; the constant last
 (expand '(* (+ x y) (- x y)) = '(- (** x 2) (** y 2)))
 (expand '(* (- x y) (+ x y)) = '(- (** x 2) (** y 2)))  ; the cross terms cancel
 (expand '(* (+ x 1) (- x 1)) = '(- (** x 2) 1))
 (expand '(* (- x y) (- x y))
  = '(- (+ (** x 2) (** y 2)) (* 2 (* x y))))         ; (x-y)^2: the red term subtracted last
 (expand '(exp (- x y)) = '(/ (exp x) (exp y)))
 (expand '(sin (+ x y))
  = '(+ (* (cos x) (sin y)) (* (cos y) (sin x))))
 (expand '(cos (+ x y))
  = '(- (* (cos x) (cos y)) (* (sin x) (sin y))))
 (expand '(sin (- x y))
  = '(- (* (cos y) (sin x)) (* (cos x) (sin y))))
 (expand '(cos (- x y))
  = '(+ (* (cos x) (cos y)) (* (sin x) (sin y))))
 (deriv (expand '(sin (+ x y))) 'x
  = expand '(cos (+ x y)))                          ; expand then differentiate, either order
 (deriv (expand '(cos (+ x y))) 'x
  = expand '(- 0 (sin (+ x y))))
 (49 = expand '(* (+ 3 4) (+ 3 4)))                 ; ground folds before it distributes
 (expand '(log (* x y)) = '(+ (log x) (log y)))
 (expand '(log (/ (* x y) z)) = '(- (+ (log x) (log y)) (log z)))
 (expand '(exp (+ x y)) = '(* (exp x) (exp y)))     ; an exp splits a sum
 (expand '(log (** x y)) = '(* y (log x)))
 (expand '(log (* x x)) = '(* 2 (log x)))
 (expand '(log (exp (+ x y))) = '(+ x y)))

; --- collect: +/-/* spines flatten (- as a sign), sort, merge equal cores, refold; repeated
; factors power up, sums order by degree descending; / is left alone
(test
 (collect '(* x x) = '(** x 2))
 (collect '(* x (* x x)) = '(** x 3))
 (collect '(* x (** x 2)) = '(** x 3))
 (collect '(* (** x 2) (** x 3)) = '(** x 5))
 (collect '(* (exp y) (exp y)) = '(** (exp y) 2))
 (collect '(* x (** x -1)) = '(* x (** x -1)))      ; a red exponent never merges: x might be 0
 (collect '(* y (* x x)) = '(* (** x 2) y))
 (collect '(+ y x) = '(+ x y))
 (collect '(* y x) = '(* x y))
 (collect '(+ (* y x) (* x y)) = '(* 2 (* x y)))
 (collect '(+ x (+ y x)) = '(+ (* 2 x) y))
 (collect '(+ (+ x 1) (+ x 2)) = '(+ (* 2 x) 3))    ; constants merge, and sit last
 (collect '(+ (* 2 x) (* 3 x)) = '(* 5 x))
 (collect '(+ (* 2 x) (* -2 x)) = 0)
 (collect ['+ ['+ 'x (1 /// 2)] ['+ 'x (1 /// 2)]]
  = '(+ (* 2 x) 1))
 (collect '(* 3 (* x 2)) = '(* 6 x))                ; ground factors gather up front
 (collect '(* x (* 2 (* y (* 3 z)))) = '(* 6 (* x (* y z))))
 (collect '(- (+ y x) z) = '(- (+ x y) z))          ; - rides the flatten as a sign
 (collect '(- x (- x y)) = 'y)
 (collect '(+ (- 0 y) 3) = '(- 3 y))
 (collect '(- 0 y) = '(- 0 y))
 (collect '(- 2 5) = -3)                            ; a lone ground red is the signed star
 (collect '(- (+ x y) (+ y x)) = 0)
 (collect '(* (- 0 x) y) = '(- 0 (* x y)))          ; a negated factor is a sign
 (collect '(* (- 0 x) (- 0 y)) = '(* x y))
 (collect '(+ (* (- 0 x) y) (* x y)) = 0)
 (collect 'x = 'x))

; --- conditional laws: division identities fire only on nz?, a manifestly-nonzero certificate
(test
 (1 = simp '(/ 3 3))
 (1 = simp '(/ -5 -5))                              ; a red star certifies (the square test)
 (simp '(/ x x) = '(/ x x))                         ; symbolic: x might be 0 -- stays
 (simp '(/ 0 0) = '(/ 0 0))                         ; 0/0 is (): never 1, never 0
 (1 = simp '(/ (exp x) (exp x)))                    ; exp is never 0: a structural certificate
 (0 = simp '(/ 0 (exp y)))
 (simp '(/ 0 x) = '(/ 0 x))                         ; ... but 0/x stays
 (simp '(/ (* x (exp y)) (exp y)) = 'x)
 (simp '(/ (* (exp y) x) (exp y)) = 'x)
 (simp '(/ (* x y) y) = '(/ (* x y) y))
 (1 = simp ['/ (1 /// 2) (2 /// 4)])                    ; a coin pair matches by value
 (simp '(/ (* x (** (exp z) 2)) (** (exp z) 2)) = 'x))  ; nz? climbs the power

; --- assume: (assume c t) simps t with facts (pos x), (neg x), (nz x) in force
(test
 (1 = assume '((nz x)) '(/ x x))
 (1 = assume '((pos x)) '(/ x x))
 (1 = assume '((neg x)) '(/ x x))
 (assume '((nz y)) '(/ x x) = '(/ x x))             ; a fact about y says nothing of x
 (assume '((nz x)) '(/ (* y x) x) = 'y)
 (assume '((pos x) (pos y)) '(/ (* z (* x y)) (* x y))
  = 'z)
 (0 = assume '((nz x)) '(/ 0 (* x (exp y))))
 (assume '((pos x)) '(sqrt (** x 2)) = 'x)          ; |x| collapses under positivity
 (assume '((neg x)) '(sqrt (** x 2))
  = '(sqrt (** x 2)))                                 ; ... but not under negativity
 (simp '(sqrt (** x 2)) = '(sqrt (** x 2)))         ; bare: x may be red -- stays
 (simp '(sqrt (** (exp y) 2)) = '(exp y))           ; manifest positivity needs no fact
 (simp '(sqrt (** pi 2)) = 'pi)
 (assume () '(/ x x) = '(/ x x))
 (expandc '((nz x)) '(* (+ a b) (/ x x))
  = '(+ a b))                                         ; the cancellation fires before distribution
 (expand '(* (+ a b) (/ x x))
  = '(+ (* a (/ x x)) (* b (/ x x))))
 (expandc '((pos y)) '(* (sqrt (** y 2)) (+ y 1))
  = '(+ (** y 2) y))
 (1 = derivc '((nz x)) '(/ (* v x) x) 'v)
 (deriv '(/ (* v x) x) 'v
  = '(/ (** x 2) (** x 2)))                           ; ... bare deriv cannot know x is nonzero
 (1 = derivc '((pos u)) '(sqrt (** u 2)) 'u))

; --- symbolic d: a rule set, the base case a guarded rule (free? of v); answers land
; canonical through simp and collect
(test
 (0 = deriv 'y 'x)                              ; free of x: the guarded base
 (0 = deriv 5 'x)
 (1 = deriv 'x 'x)
 (2 = deriv '(* 2 x) 'x)
 (deriv '(* x x) 'x = '(* 2 x))
 (deriv '(+ (* x x) (* 3 x)) 'x = '(+ (* 2 x) 3))
 (deriv '(sin x) 'x = '(cos x))
 (deriv '(cos x) 'x = '(- 0 (sin x)))
 (deriv '(sin (* 2 x)) 'x = '(* 2 (cos (* 2 x))))   ; the chain rule, coefficient first
 (deriv '(/ 1 x) 'x = '(/ -1 (** x 2)))
 (deriv '(/ x 2) 'x = 1 /// 2)
 (deriv '(exp x) 'x = '(exp x))
 (deriv '(exp (* 2 x)) 'x = '(* 2 (exp (* 2 x))))
 (deriv '(log x) 'x = '(/ 1 x))
 (deriv '(** x 3) 'x = '(* 3 (** x 2)))
 (deriv '(** (sin x) 2) 'x = '(* 2 (* (cos x) (sin x))))
 (deriv '(* (- x 1) (+ x 1)) 'x = '(* 2 x))
 (deriv '(tan x) 'x = '(/ 1 (** (cos x) 2)))
 (deriv '(tan (* 2 x)) 'x = '(/ 2 (** (cos (* 2 x)) 2)))
 (deriv '(atan x) 'x = '(/ 1 (+ (** x 2) 1)))
 (deriv '(sqrt x) 'x = '(/ 1 (* 2 (sqrt x))))
 (deriv '(asin x) 'x = '(/ 1 (sqrt (- 1 (** x 2)))))
 (deriv '(acos x) 'x = '(- 0 (/ 1 (sqrt (- 1 (** x 2))))))
 (collect ['+ (deriv '(asin x) 'x) (deriv '(acos x) 'x)]
  = 0)                                            ; asin + acos is constant
 (deriv '(asin (* 2 x)) 'x
  = '(/ 2 (sqrt (- 1 (** (* 2 x) 2)))))
 (1 = deriv '(** (sqrt x) 2) 'x)                ; the input simps first...
 (deriv '(/ (sin x) (cos x)) 'x
  = '(/ 1 (** (cos x) 2)))                        ; ... so sin/cos derives as tan
 (0 = deriv 'pi 'x)
 (deriv '(* pi x) 'x = 'pi)
 (deriv '(** e x) 'x = '(exp x))
 (deriv '(** e (* 2 x)) 'x = '(* 2 (exp (* 2 x))))
 (deriv '(** x x) 'x = '(d (** x x) x))         ; a symbolic exponent fails the guard and stays
 (deriv '(f x) 'x = '(d (f x) x))               ; an unknown derivative stays symbolic
 (deriv ['+ ['sin 'x] ['* 'x (1 /// 2)]] 'x = ['+ '(cos x) (1 /// 2)])
 (simp '(+ z z) = '(* 2 z))
 (deriv (pemit (psq rx) '(x y z)) 'x
  = pemit (pd (psq rx) 0) '(x y z)))            ; d agrees with pd through the bridge

; --- unfix: terms back to infix love source; (opfix (unfix t)) = t over the corpus
(: tcorp ['(+ (* 2 x) 1) '(* 2 (+ x 1)) '(- (- 10 4) 3) '(- 10 (- 4 3))
          '(+ (sin x) 1) '(* 2 (sin (+ x 1))) '(f (+ x 1) y) '(+ (f x y) 1)
          '(* (** 2 x) (+ y 1)) ['+ 'x (1 /// 2)] '(f (g x) y) '(* (+ a b) (+ c d))
          '(+ (log x) (* 2 (exp x)))
          (pemit (padd (pmul rx rx) ry) '(x y z))])
(test
 (unfix '(+ (* 2 x) 1) = '(2 * x + 1))
 (unfix '(* 2 (+ x 1)) = '(2 * (x + 1)))            ; a looser right child wraps
 (unfix '(- (- 10 4) 3) = '(10 - 4 - 3))            ; the additive band folds left
 (unfix '(- 10 (- 4 3)) = '(10 - (4 - 3)))
 (unfix '(+ (sin x) 1) = '(sin x + 1))              ; application binds tightest
 (unfix '(f (+ x 1) y) = '(f (x + 1) y))
 (unfix (pemit (padd (pmul rx rx) ry) '(x y z)) = '(x ** 2 + y))
 (unfix 'x = 'x)
 (all (t \ (opfix (unfix t) = t)) tcorp)
 (7 = ev (unfix '(+ (* 2 3) 1))))

(test_fin ())
(puts "rune: ok")
