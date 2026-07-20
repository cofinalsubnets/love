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
; folded dyadic + / * with powers as repeated *, so one closure computes over
; integers and q coins alike. the flagship: F1 and F3 of the counterexample,
; COMPILED, evaluated at the published collision point -- the same -1/4 and 0
; the modular certificate proved, now through ev'd code. a mixed evaluation
; lands a coin, so zero reads (q 0 1), never the fixnum 0.
(: xyz '(x y z)
   ef1 (pfn pp1 xyz)                       ; x+y, from the COIN face
   ef2 (pfn (pd (load pp2) 0) xyz)         ; d(x-2y)/dx = 1
   ef3 (pfn (pmul (pmul rx rx) ry) xyz)    ; x^2 y: a power, repeated-*
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

(puts "rune: ok")
