; complex: the widest tier, sticky (never demotes to a real), ordered by (re, im),
; and `=` bridges to reals

(: (near? a b eps) (((a < b ? (b - a) (a - b)) - 0) < eps)
   (near a b)       (near? a b 1e-12)
   (cnear z w)      (near (re z) (re w) ? (near (im z) (im w)) 0)
   B100 (100 2))

(test
 ; --- printer: parenthesized so it reads back ---
 ("(2.0 ~ 3.0)" = show (2 ~ 3))
 ("(2.0 ~ -3.0)" = show (2 ~ -3))
 ("(-1.0 ~ -2.0)" = show (-1 ~ -2))

 ((2 ~ 0) = 2.0)
 ((2 + (3 * i)) = (2 ~ 3))

 ; --- sticky ---
 (twin? (2 ~ 0))
 (twin? i)
 !(twin? 5.0)

 (((1 ~ 2) + (3 ~ 4)) = (4 ~ 6))
 (((1 ~ 2) - (3 ~ 4)) = (-2 ~ -2))
 (cnear ((1 ~ 2) / (3 ~ 4)) (0.44 ~ 0.08))
 (((0 ~ 2) * i) = -2)

 (3.0 = im (2 ~ 3))
 (7 = re 7)
 !(im 7)
 (5 = conj 5)

 ; --- glued ~x is conj (lifting a real to (r, 0)), spaced it is twin ---
 ((5 ~ 0) = ~5)
 ((-3.5 ~ 0) = ~-3.5)
 ((2 ~ -3) = ~(2 ~ 3))   (i = ~(0 ~ -1))

 ; --- twin binds tightest of all: a compound part owes parens ---
 ((9.0 ~ 12.0) = (1 + 2 ~ 3 * 4))               ; (2~3) first, then * 4, then 1 +
 ((1 ~ 2) = (1 ~ 2))   !((1 ~ 2) < (1 ~ 2))

 ; --- abs: complex -> float magnitude; a real stays in its tier ---
 (13.0 = abs (-5 ~ 12))
 (5 = abs 5)
 (5.5 = abs -5.5)
 (B100 = abs (0 - B100))
 (B100 = abs B100)

 ; --- arg: a real -> 0 (>=0) or pi (<0) ---
 (near (pi / 2) (arg i))
 (near 0 (arg (1 ~ 0)))
 (near pi (arg -1))
 (near 0 (arg 5))

 ; --- a real r orders as (r, 0): so i < 1 ---
 !(i > 1)   (i <= 1)   !(i >= 1)
 ((1 ~ 1) < (2 ~ 2))   ((1 ~ 1) <= (2 ~ 2))
 ((2 ~ 1) < (2 ~ 5))   !((2 ~ 5) < (2 ~ 1))

 ; --- % undefined, sine real-domain only, sqrt via power; twin rejects a complex part ---
 !(i % 2)
 !(sine i)   (near 0.7071067811865476 (re ((1 / 2) i)))   !(twin 1 i)
 ; w^z = exp(z Log w): i^2 = -1, i^i = e^(-pi/2)
 (near -1 (re (2 i)))   (word ? (near 0 (im (2 i))) 1)   ; f32 powf's residue exceeds near's tol
 (near 0.20787957635076193 (re (i i)))   (near 0 (im (i i)))

 ; --- complex meets bignum: the bignum narrows to double ---
 (twin? (i + B100))
 (1.0 = im (i + B100))
 (1e29 < re (i + B100))

 ; --- as keys, distinct from the equal real ---
 ('hit = peep (pin {} (2 ~ 0) 'hit) (2 ~ 0) 'miss)
 ('miss = peep (pin {} (2 ~ 0) 'hit) 2 'miss)
 ('iv = peep (pin {} i 'iv) i 'miss))

; --- complex arrays, two floats per element ---
; body-less `:`, so ca-* stay global: roundtrip.l reads them
(: ca-z (twin-tray '(3) 0)                             ; zero-filled
   ca-v (twin-tray '(2) [(1 ~ 2) (3 ~ 4)])
   ca-a (array 3 (1 ~ 1) (2 ~ 2) (3 ~ 3))     ; `array` infers the tier
   ca-r @((1 ~ 0) (0 ~ 1))                     ; `@` too
   ca-m (array '(2 2) (1 ~ 0) (0 ~ 1) (2 ~ 0) (0 ~ 2)))

(test
 (twin-tray = tier ca-v)   (twin-tray = tier ca-z)   (twin-tray = tier ca-a)
 (twin-tray = tier ca-r)   (twin-tray = tier ca-m)
 (1 = rank ca-v)   (2 = #ca-v)
 (2 = rank ca-m)   (4 = #ca-m)

 ((1 ~ 2) = peep ca-v 0 0)   ((3 ~ 4) = peep ca-v 1 0)   (twin? (peep ca-v 0 0))
 ((0 ~ 2) = peep ca-m [1 1] 0)
 ((0 ~ 0) = peep ca-z 0 0)   ((2 ~ 2) = peep ca-a 1 0)

 ((2 ~ 4) = peep (ca-v + ca-v) 0 0)
 (aall (ca-v = (ca-v + twin-tray '(2) 0)))
 ((-5 ~ 10) = peep (twin-tray '(2) [(1 ~ 1) (1 ~ 2)] * ca-v) 1 0)
 ((1 ~ 2) = peep ((ca-v * ca-v) / ca-v) 0 0)

 ; --- a complex scalar broadcasts, both orders ---
 ((11 ~ 2) = peep ((10 ~ 0) + ca-v) 0 0)
 ((13 ~ 4) = peep (ca-v + (10 ~ 0)) 1 0)
 ((2 ~ 4) = peep ((2 ~ 0) * ca-v) 0 0)
 ((0 ~ 1) = peep (i * ca-r) 0 0)

 ; --- real array meets complex: the real promotes to (v, 0) ---
 ((11 ~ 2) = peep (@(10 20) + ca-v) 0 0)
 ((23 ~ 4) = peep (ca-v + @(10 20)) 1 0)

 ; --- accessors elementwise: re/im/arg go real, conj stays complex ---
 (@(1.0 3.0) = re ca-v)   (@(2.0 4.0) = im ca-v)
 (aall (ca-v = conj (conj ca-v)))
 ((1 ~ -2) = peep (conj ca-v) 0 0)   ((3 ~ -4) = peep (conj ca-v) 1 0)
 (twin-tray = tier (conj ca-v))
 (near (pi / 2) (peep (arg (twin-tray '(1) [(0 ~ 1)])) 0 0))
 (@(1.0 2.0) = conj @(1.0 2.0))

 ; --- comparisons answer a mask ---
 (ca-v = ca-v)
 !(aall (ca-v = twin-tray '(2) [(9 ~ 9) (3 ~ 4)]))
 (aany (ca-v = twin-tray '(2) [(9 ~ 9) (3 ~ 4)]))
 (aall (ca-v = ca-v))
 (aall (@(1 0) = (ca-v < twin-tray '(2) [(1 ~ 5) (0 ~ 0)])))    ; re tie -> im 2<5 ; 3>0
 (aall (@(0 1) = (ca-v > twin-tray '(2) [(1 ~ 5) (0 ~ 0)])))
 (aall (ca-v <= ca-v))   (aall (ca-v >= ca-v))
 (aall (@(1 0) = (ca-v < (2 ~ 0))))             ; a complex scalar broadcasts
 !(ca-v % ca-v)   !(ca-v // ca-v)

 ; --- reductions; max/min answer () ---
 (4 ~ 6 = +ca-v)
 (-5 ~ 10 = *ca-v)
 (6 ~ 6 = +ca-a)   (0 ~ 0 = +ca-z)
 !(amax ca-v)   !(amin ca-v)

 ; --- an element is true by its real part ---
 (aall ca-v)
 !(aall (twin-tray '(2) [(0 ~ 0) (1 ~ 1)]))
 !(aall (twin-tray '(2) [(0 ~ 1) (1 ~ 1)]))        ; i has no real part
 !(aall (twin-tray '(1) [(-1 ~ 5)]))
 $(twin-tray '(2) [(0 ~ 0) (1 ~ 1)])                ; the element sum (1 ~ 1) sorts positive
 !$ca-z

 ; --- abs of a complex array is the L2 norm over every (re, im) ---
 (5.0 = abs (twin-tray '(1) [(3 ~ 4)]))
 (near ((1 / 2) 30) (abs ca-v))

 ; --- !x iff (sat x) is 0 ---
 (0 = sat ca-z)   !ca-z
 !!ca-v   (4 = sat ca-v)                          ; the sum (4 ~ 6) clamps by its real part: ceil 4
 ((!ca-v ? 1 0) = (0 = sat ca-v ? 1 0))
 ((!ca-z ? 1 0) = (0 = sat ca-z ? 1 0))

 ; --- printer: rank 1 as @(..), rank 2+ as (array ..) ---
 ("@((1.0 ~ 2.0) (3.0 ~ 4.0))" = show ca-v)
 ("(array '(2 2) (1.0 ~ 0.0) (0.0 ~ 1.0) (2.0 ~ 0.0) (0.0 ~ 2.0))" = show ca-m))
