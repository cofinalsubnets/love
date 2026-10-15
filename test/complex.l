; complex arithmetic: the widest numeric tier, sticky (never demotes to a real),
; ordered by (re, im), and `=` bridges to reals

(: (near? a b eps) (((a < b ? (b - a) (a - b)) - 0) < eps)
   (near a b)       (near? a b 1e-12)
   (cnear z w)      (near (re z) (re w) ? (near (im z) (im w)) 0)
   B100 (100 2))

(test
 ; --- printer: (re ~ im) form, parenthesized so it reads back by re-evaluation ---
 ("(2.0 ~ 3.0)" = show (2 ~ 3))
 ("(2.0 ~ -3.0)" = show (2 ~ -3))
 ("(-1.0 ~ -2.0)" = show (-1 ~ -2))

 ; --- the defining identity, and that `=` bridges complex to a real ---
 ((2 ~ 0) = 2.0)                       ; cross-real equality (im 0)
 ((2 + (3 * i)) = (2 ~ 3))             ; 2+3i built through the arith lanes

 ; --- sticky: a real-valued complex stays complex (distinct from the real) ---
 (twin? (2 ~ 0))
 (twin? i)
 !(twin? 5.0)

 ; --- componentwise add / sub; Gaussian mul; div by conjugate ---
 (((1 ~ 2) + (3 ~ 4)) = (4 ~ 6))
 (((1 ~ 2) - (3 ~ 4)) = (-2 ~ -2))
 (cnear ((1 ~ 2) / (3 ~ 4)) (0.44 ~ 0.08))
 (((0 ~ 2) * i) = -2)                  ; 2i * i = -2 (real), via cross-real =

 ; --- accessors ---
 (3.0 = im (2 ~ 3))
 (7 = re 7)                                ; re of a real is itself
 !(im 7)                                   ; im of a real is 0
 (5 = conj 5)                              ; conj lifts a real to (r ~ 0) = r (the tower bridges)

 ; --- glued ~x is conj (lifting a real to (r, 0)), spaced it is twin ---
 ((5 ~ 0) = ~5)                              ; ~r lifts a real to (r, 0) -- a true complex
 ((-3.5 ~ 0) = ~-3.5)                       ; lift works on a negative real
 ((2 ~ -3) = ~(2 ~ 3))   (i = ~(0 ~ -1))     ; ~(r ~ i) = (r ~ -i)

 ; --- twin binds tightest of all: a compound part owes parens ---
 ((9.0 ~ 12.0) = (1 + 2 ~ 3 * 4))               ; (2~3) first, then * 4, then 1 +
 ((1 ~ 2) = (1 ~ 2))   !((1 ~ 2) < (1 ~ 2))

 ; --- abs: type-aware. complex -> float magnitude; real stays in its tier ---
 (13.0 = abs (-5 ~ 12))
 (5 = abs 5)                               ; fixnum abs stays a fixnum
 (5.5 = abs -5.5)                          ; float abs stays a float
 (B100 = abs (0 - B100))                   ; bignum abs flips the sign, stays a bignum
 (B100 = abs B100)

 ; --- arg: phase. complex via atan2; real -> 0 (>=0) or pi (<0) ---
 (near (pi / 2) (arg i))
 (near 0 (arg (1 ~ 0)))
 (near pi (arg -1))
 (near 0 (arg 5))

 ; --- ordered by (re, im), a real r as (r, 0): so i < 1 ---
 !(i > 1)   (i <= 1)   !(i >= 1)
 ((1 ~ 1) < (2 ~ 2))   ((1 ~ 1) <= (2 ~ 2))
 ((2 ~ 1) < (2 ~ 5))   !((2 ~ 5) < (2 ~ 1))

 ; --- % undefined, sine real-domain only, sqrt via power; twin rejects a complex part ---
 !(i % 2)
 !(sine i)   (near 0.7071067811865476 (re ((1 / 2) i)))   !(twin 1 i)
 ; power is defined on complex: w^z = exp(z Log w). i^2 = -1, i^i = e^(-pi/2) (real)
 (near -1 (re (2 i)))   (word ? (near 0 (im (2 i))) 1)   ; im residue exceeds near's tol under f32 powf
 (near 0.20787957635076193 (re (i i)))   (near 0 (im (i i)))

 ; --- complex meets bignum: the bignum narrows to double (floating domain) ---
 (twin? (i + B100))
 (1.0 = im (i + B100))                     ; imaginary part untouched
 (1e29 < re (i + B100))                    ; real part ~ 2^100

 ; --- complex as hash keys: eql-distinct from the equal real (sticky) ---
 ('hit = peep (pin {} (2 ~ 0) 'hit) (2 ~ 0) 'miss)
 ('miss = peep (pin {} (2 ~ 0) 'hit) 2 'miss)            ; 2 and 2+0i are different keys
 ('iv = peep (pin {} i 'iv) i 'miss))

; --- complex arrays, two floats per element ---
; body-less `:`, so ca-* stay global: roundtrip.l reads them
(: ca-z (twin-tray '(3) 0)                             ; zero-filled: three 0+0i
   ca-v (twin-tray '(2) [(1 ~ 2) (3 ~ 4)])       ; explicit packed chain
   ca-a (array 3 (1 ~ 1) (2 ~ 2) (3 ~ 3))     ; `array` infers c from its args
   ca-r @((1 ~ 0) (0 ~ 1))                     ; `@` reader infers c too
   ca-m (array '(2 2) (1 ~ 0) (0 ~ 1) (2 ~ 0) (0 ~ 2)))  ; rank-2 complex

(test
 ; --- construction / type / shape ---
 (twin-tray = tier ca-v)   (twin-tray = tier ca-z)   (twin-tray = tier ca-a)
 (twin-tray = tier ca-r)   (twin-tray = tier ca-m)
 (1 = rank ca-v)   (2 = #ca-v)
 (2 = rank ca-m)   (4 = #ca-m)

 ; --- get returns a complex box; rank-N indexing; zero element ---
 ((1 ~ 2) = peep ca-v 0 0)   ((3 ~ 4) = peep ca-v 1 0)   (twin? (peep ca-v 0 0))
 ((0 ~ 2) = peep ca-m [1 1] 0)                  ; row-major (1,1)
 ((0 ~ 0) = peep ca-z 0 0)   ((2 ~ 2) = peep ca-a 1 0)

 ; --- elementwise broadcast: array (op) array ---
 ((2 ~ 4) = peep (ca-v + ca-v) 0 0)              ; (1+2i)+(1+2i) elementwise
 (aall (ca-v = (ca-v + twin-tray '(2) 0)))             ; + the zero array is identity
 ((-5 ~ 10) = peep (twin-tray '(2) [(1 ~ 1) (1 ~ 2)] * ca-v) 1 0)       ; (1+2i)(3+4i)
 ((1 ~ 2) = peep ((ca-v * ca-v) / ca-v) 0 0)     ; (z*z)/z = z

 ; --- scalar broadcast: complex scalar (op) array, both orders ---
 ((11 ~ 2) = peep ((10 ~ 0) + ca-v) 0 0)
 ((13 ~ 4) = peep (ca-v + (10 ~ 0)) 1 0)
 ((2 ~ 4) = peep ((2 ~ 0) * ca-v) 0 0)          ; scale by 2
 ((0 ~ 1) = peep (i * ca-r) 0 0)                 ; i*(1+0i) = i

 ; --- real array meets complex: the real promotes to (v, 0) ---
 ((11 ~ 2) = peep (@(10 20) + ca-v) 0 0)         ; z @(10 20) lifts to (10,0)/(20,0)
 ((23 ~ 4) = peep (ca-v + @(10 20)) 1 0)

 ; --- accessors elementwise: re/im/arg go real, conj stays complex ---
 (@(1.0 3.0) = re ca-v)   (@(2.0 4.0) = im ca-v)
 (aall (ca-v = conj (conj ca-v)))                ; conj is an involution on the array too
 ((1 ~ -2) = peep (conj ca-v) 0 0)   ((3 ~ -4) = peep (conj ca-v) 1 0)
 (twin-tray = tier (conj ca-v))                   ; the tier is kept
 (near (pi / 2) (peep (arg (twin-tray '(1) [(0 ~ 1)])) 0 0))
 (@(1.0 2.0) = conj @(1.0 2.0))                   ; a real array conjugates to itself

 ; --- `=` over complex arrays -> a boolean (whole-array); the orderings -> a mask ---
 (ca-v = ca-v)
 !(aall (ca-v = twin-tray '(2) [(9 ~ 9) (3 ~ 4)]))   ; one cell differs: the mask has a 0, and aall says so
 (aany (ca-v = twin-tray '(2) [(9 ~ 9) (3 ~ 4)]))
 (aall (ca-v = ca-v))                           ; aall is the identity on the boolean
 ; a complex tray orders as its cells do, by (re, im)
 (aall (@(1 0) = (ca-v < twin-tray '(2) [(1 ~ 5) (0 ~ 0)])))    ; re tie -> im 2<5 ; 3>0
 (aall (@(0 1) = (ca-v > twin-tray '(2) [(1 ~ 5) (0 ~ 0)])))
 (aall (ca-v <= ca-v))   (aall (ca-v >= ca-v))
 (aall (@(1 0) = (ca-v < (2 ~ 0))))             ; a complex scalar broadcasts
 !(ca-v % ca-v)   !(ca-v // ca-v)               ; % and // stay undefined on complex

 ; --- reductions: complex sum / product; max/min unordered -> nil ---
 (4 ~ 6 = +ca-v)                               ; (1+2i)+(3+4i)
 (-5 ~ 10 = *ca-v)                             ; (1+2i)*(3+4i)
 (6 ~ 6 = +ca-a)   (0 ~ 0 = +ca-z)
 !(amax ca-v)   !(amin ca-v)

 ; --- aall lifts the truth law: an element is true by its real part ---
 (aall ca-v)
 !(aall (twin-tray '(2) [(0 ~ 0) (1 ~ 1)]))        ; a 0+0i element fails aall
 !(aall (twin-tray '(2) [(0 ~ 1) (1 ~ 1)]))        ; ..and so does i: no real part, as (? i) says
 !(aall (twin-tray '(1) [(-1 ~ 5)]))
 $(twin-tray '(2) [(0 ~ 0) (1 ~ 1)])                ; the element sum (1 ~ 1) sorts positive
 !$ca-z

 ; --- abs of a complex array = the flat L2 norm over every (re, im) ---
 (5.0 = abs (twin-tray '(1) [(3 ~ 4)]))            ; |3+4i| = 5
 (near ((1 / 2) 30) (abs ca-v))                     ; sqrt(1+4+9+16)

 ; --- pin / nil?: the invariant (nil? x) == (= 0 (pin x)) holds here too ---
 (0 = sat ca-z)   !ca-z
 !!ca-v   (4 = sat ca-v)                          ; the sum (4 ~ 6) clamps by its real part: ceil 4
 ((!ca-v ? 1 0) = (0 = sat ca-v ? 1 0))
 ((!ca-z ? 1 0) = (0 = sat ca-z ? 1 0))

 ; --- printer: rank-1 terse @((C…)…); rank>=2 (array '(…) (C…)…) ---
 ("@((1.0 ~ 2.0) (3.0 ~ 4.0))" = show ca-v)
 ("(array '(2 2) (1.0 ~ 0.0) (0.0 ~ 1.0) (2.0 ~ 0.0) (0.0 ~ 2.0))" = show ca-m))
