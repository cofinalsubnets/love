; property-based fuzzer built on the step-8 RNG (xoshiro256++ functional stream).
;
; a GENERATOR is a function st -> (value . st'), the exact shape of rand-next, so
; generators thread the random state purely and compose by plumbing the returned
; st onward. fz-find drives a generator N times against a predicate from a fixed
; seed (so any failure is reproducible) and reports the first counterexample;
; fz-ok is the boolean wrapper the asserts use. The properties below are
; invariants that must hold for EVERY draw -- algebraic laws of the numeric tower,
; list-combinator identities, the print->read round trip, and array broadcasting.
;
; fz-find returns (X 1 0) on success or (X 0 counterexample) on failure;
; to debug a red property interactively, eval (show (B (fz-find n seed g p)))
; to see the offending input.
(:
 ; --- generator monad: pure / map / bind over the functional RNG ---
 (fz-pure v) (\ st (cons v st))                          ; ignores the stream
 (fz-map f g) (\ st (: r (g st) (cons (f (cap r)) (cbp r))))
 (fz-bind g k) (\ st (: r (g st) ((k (cap r)) (cbp r)))) ; feed value into next gen
 ; --- primitive draws (every range below keeps hi > lo so randint never mods by 0) ---
 (fz-nat n) (\ st (randint st n))                        ; [0, n)
 (fz-int lo hi) (fz-map (+ lo) (fz-nat (- hi lo)))       ; [lo, hi)
 (fz-elt l) (\ st (: r (randint st (sat l)) (cons (cap (drop (cap r) l)) (cbp r))))
 (fz-oneof gs) (fz-bind (fz-nat (sat gs)) (\ k (cap (drop k gs))))  ; pick a generator
 ; --- structured draws: fixed repetition, bounded-length list, tuples ---
 (fz-rep n g) (? (< n 1) (fz-pure 0)
    (\ st (: a (g st) b ((fz-rep (- n 1) g) (cbp a)) (cons (cons (cap a) (cap b)) (cbp b)))))
 (fz-list mx g) (\ st (: r (randint st (+ 1 mx)) ((fz-rep (cap r) g) (cbp r))))  ; pin in [0,mx]
 (fz-pair2 ga gb) (\ st (: a (ga st) b (gb (cbp a)) (cons (L (cap a) (cap b)) (cbp b))))
 (fz-trip ga gb gc)
   (\ st (: a (ga st) b (gb (cbp a)) c (gc (cbp b)) (cons (L (cap a) (cap b) (cap c)) (cbp c))))
 ; --- the driver: N trials from `seed`, first counterexample wins ---
 (fz-find n seed g p)
   (: (go n st) (? (< n 1) (cons 1 0)
        (: r (g st) (? (p (cap r)) (go (- n 1) (cbp r)) (cons 0 (cap r)))))
      (go n (rng-seed seed)))
 (fz-ok n seed g p) (cap (fz-find n seed g p)))

; --- concrete value generators over the numeric tower ---
(: fz-fix    (fz-int -1000 1000)                         ; fixnums straddling 0
   fz-fix-nz (fz-map (\ x (? (= x 0) 1 x)) fz-fix)       ; nonzero fixnum (safe divisor)
   ; s * 2^e with e up to 160 forces the box / bignum tiers and both signs
   fz-bignum (fz-bind (fz-int 58 160) (\ e (fz-map (\ s (* s (e 2))) (fz-elt '(-3 -1 1 3 5)))))
   fz-num    (fz-oneof (L fz-fix fz-bignum))             ; mixed-tier value
   fz-num-nz (fz-map (\ x (? (= x 0) 1 x)) fz-num)       ; nonzero mixed-tier (divisor)
   fz-elem   (fz-int -20 20)                             ; small list/array element
   fz-l      (fz-list 8 fz-elem))                        ; list of small ints, pin 0..8

; ---- numeric-tower algebra: laws that hold across fixnum / box / bignum ----
(assert
 ; commutativity of + and *
 (fz-ok 400 1 (fz-pair2 fz-num fz-num) (\ v (= (+ (cap v) (cabp v)) (+ (cabp v) (cap v)))))
 (fz-ok 400 2 (fz-pair2 fz-num fz-num) (\ v (= (* (cap v) (cabp v)) (* (cabp v) (cap v)))))
 ; associativity of + and *
 (fz-ok 300 3 (fz-trip fz-num fz-num fz-num)
   (\ v (= (+ (+ (cap v) (cabp v)) (cabbp v)) (+ (cap v) (+ (cabp v) (cabbp v))))))
 (fz-ok 300 4 (fz-trip fz-num fz-num fz-num)
   (\ v (= (* (* (cap v) (cabp v)) (cabbp v)) (* (cap v) (* (cabp v) (cabbp v))))))
 ; left distributivity: a*(b+c) = a*b + a*c
 (fz-ok 300 5 (fz-trip fz-num fz-num fz-num)
   (\ v (= (* (cap v) (+ (cabp v) (cabbp v)))
           (+ (* (cap v) (cabp v)) (* (cap v) (cabbp v))))))
 ; negation is involutive; subtraction anti-commutes
 (fz-ok 400 6 fz-num (\ a (= a (- 0 (- 0 a)))))
 (fz-ok 300 7 (fz-pair2 fz-num fz-num) (\ v (= (- (cap v) (cabp v)) (- 0 (- (cabp v) (cap v))))))
 ; multiplying by zero / one
 (fz-ok 300 8 fz-num (\ a (= 0 (* a 0))))
 (fz-ok 300 9 fz-num (\ a (= a (* a 1))))
 ; divmod identity: a = (a//b)*b + a%b, and the remainder is smaller in magnitude
 (fz-ok 400 10 (fz-pair2 fz-num fz-num-nz)
   (\ v (= (cap v) (+ (* (// (cap v) (cabp v)) (cabp v)) (mod (cap v) (cabp v))))))
 ; remainder sign follows the dividend (truncated division)
 (fz-ok 400 11 (fz-pair2 fz-fix fz-fix-nz)
   (\ v (: r (mod (cap v) (cabp v)) (|| (= r 0) (= (< r 0) (< (cap v) 0))))))
 ; exact-power recurrence and the float-free modpow against ** then %
 (fz-ok 300 12 (fz-pair2 (fz-int -6 7) (fz-nat 14))
   (\ v (= ((+ 1 (cabp v)) (cap v)) (* (cap v) ((cabp v) (cap v))))))
 (fz-ok 250 13 (fz-trip (fz-nat 30) (fz-nat 14) (fz-int 2 500))
   (\ v (= (modpow (cap v) (cabp v) (cabbp v)) (mod ((cabp v) (cap v)) (cabbp v)))))
 ; gcd divides both arguments
 (fz-ok 300 14 (fz-pair2 fz-fix-nz fz-fix-nz)
   (\ v (: g (gcd (cap v) (cabp v)) (&& (= 0 (mod (cap v) g)) (= 0 (mod (cabp v) g)))))))

; ---- number-as-function application (Church numerals), deliberately bounded ----
; applying a fixnum n is Church-numeral application: a numeric operand m gives
; m ** n, a function operand g gives g composed n times. The OPERATOR is always
; drawn as a small non-negative fixnum (fz-op, 0..6) so neither the exponent nor
; the composition depth can run away -- the fuzzer must never turn a random draw
; into a 2^160-sized exponent. With fz-op bounded, every result here stays tiny
; (|m ** n| <= 4 ** 6), so these properties cannot loop or blow up the heap.
(: fz-op (fz-int 0 7))
(assert
 ; numeric operand: (n m) == m ** n  (exponent n bounded to <= 6)
 (fz-ok 300 15 (fz-pair2 fz-op (fz-int -4 5))
   (\ v (= ((cap v) (cabp v)) ((cap v) (cabp v)))))
 ; function operand: ((n (+ k)) x) == x + n*k  (composition depth n bounded to <= 6)
 (fz-ok 300 16 (fz-trip fz-op (fz-int -3 4) (fz-int -10 10))
   (\ v (= (+ (* (cap v) (cabp v)) (cabbp v)) ((cap v) (+ (cabp v)) (cabbp v))))))

; ---- list-combinator identities ----
(assert
 (fz-ok 300 20 fz-l (\ l (= l (rev (rev l)))))                          ; rev is involutive
 (fz-ok 300 21 fz-l (\ l (= l (map id l))))                            ; map id = id
 (fz-ok 300 22 fz-l (\ l (= l (foldr cons 0 l))))                      ; foldr X nil = id
 (fz-ok 300 23 (fz-pair2 fz-l fz-l)
   (\ v (= (sat (cat (cap v) (cabp v))) (+ (sat (cap v)) (sat (cabp v))))))   ; cat length
 (fz-ok 300 24 (fz-pair2 fz-l fz-l)
   (\ v (= (rev (cat (cap v) (cabp v))) (cat (rev (cabp v)) (rev (cap v))))))  ; rev of cat
 (fz-ok 300 25 fz-l (\ l (= (sat (map (+ 1) l)) (sat l))))             ; map preserves length
 ; take n ++ drop n = identity, for n drawn within [0, pin]
 (fz-ok 300 26 (fz-bind fz-l (\ l (fz-map (\ n (L l n)) (fz-int 0 (+ 1 (sat l))))))
   (\ v (= (cap v) (cat (take (cabp v) (cap v)) (drop (cabp v) (cap v))))))
 ; filter keeps only matching elements and never grows the list
 (fz-ok 300 27 fz-l
   (\ l (: p (\ x (= 0 (mod x 2))) (&& (all p (filter p l)) (<= (sat (filter p l)) (sat l))))))
 ; an element consed on is found by memq
 (fz-ok 300 28 (fz-pair2 fz-elem fz-l) (\ v (memq (cap v) (cons (cap v) (cabp v))))))

; ---- print -> read round trip on random s-expressions ----
; reuses the io.c reader: serialize via show, re-read the bytes, expect equality.
(: (fz-s2cl s) ((: (g i) (? (< i (sat s)) (cons (peep s i 0) (g (+ 1 i))))) 0)
   (fz-rd x) (fread (sip (fz-s2cl (show x))) (nom 0))
   fz-syms '(a b c d foo bar baz qux)
   fz-leaf (fz-oneof (L (fz-elt fz-syms) (fz-int -500 500)))
   (fz-sexp d) (? (< d 1) fz-leaf
      (\ st (: r (randint st 3)            ; 1/3 leaf, 2/3 a bounded list of sub-exprs
          (? (= (cap r) 0) (fz-leaf (cbp r))
             ((fz-list 4 (fz-sexp (- d 1))) (cbp r)))))))
(assert
 (fz-ok 200 30 fz-leaf (\ x (= x (fz-rd x))))            ; leaves: ints + symbols
 (fz-ok 200 31 (fz-sexp 3) (\ x (= x (fz-rd x))))        ; nested structure round-trips
 (fz-ok 150 32 (fz-sexp 4) (\ x (= x (fz-rd x)))))

; ---- array broadcasting / reduction laws (z elementwise) ----
; fz-arrpair draws two z vectors of the same random length so elementwise ops line up.
(: fz-arrpair (fz-bind (fz-int 1 6) (\ n (\ st
    (: a ((fz-rep n fz-elem) st) b ((fz-rep n fz-elem) (cbp a))
       (cons (L (arr z (L n) (cap a)) (arr z (L n) (cap b))) (cbp b)))))))
(assert
 (fz-ok 250 40 fz-arrpair (\ v (aall (= (+ (cap v) (cabp v)) (+ (cabp v) (cap v))))))  ; + commutes
 (fz-ok 250 41 fz-arrpair (\ v (aall (= (* (cap v) (cabp v)) (* (cabp v) (cap v))))))  ; * commutes
 ; sum is linear: sum(a+b) = sum(a) + sum(b)
 (fz-ok 250 42 fz-arrpair
   (\ v (= (asum (+ (cap v) (cabp v))) (+ (asum (cap v)) (asum (cabp v)))))))

; ---- string operations: scat / slice / string / get / print->read ----
; fz-str draws a random byte string (length 0..mx, any byte 0..255 -- show's
; \xHH escaping round-trips them all). slice returns nil for an empty slice
; (i==j), which scat and pin treat as "" but `=` does not, so any comparison
; that can land on an empty slice routes through fz-norm (scat x "" coerces a
; nil/string to a string). fz-s2cl / fz-rd are the helpers from the round-trip
; section above (string->charlist, print->read).
(: fz-byte (fz-int 0 256)                                  ; any byte 0..255
   (fz-cl->str cl) (? (twop cl) (string cl) "")            ; charlist -> string ("" for nil)
   (fz-norm x) (scat x "")                                 ; nil|string -> string
   (fz-str mx) (fz-map fz-cl->str (fz-list mx fz-byte))    ; string, pin 0..mx
   fz-s    (fz-str 12)
   fz-s2   (fz-pair2 fz-s fz-s)
   fz-s3   (fz-trip fz-s fz-s fz-s)
   fz-cl1  (fz-bind (fz-int 1 12) (\ n (fz-rep n fz-byte))) ; nonempty charlist
   ; a string paired with a split point i in [0, pin]
   fz-s-i  (fz-bind fz-s (\ s (fz-map (\ i (cons s i)) (fz-int 0 (+ 1 (sat s))))))
   ; a string with 0 <= i <= j <= pin, as (L s i j)
   fz-s-ij (fz-bind fz-s (\ s (fz-bind (fz-int 0 (+ 1 (sat s)))
              (\ i (fz-map (\ j (L s i j)) (fz-int i (+ 1 (sat s)))))))))
(assert
 ; scat: length adds, is associative, and "" is a two-sided identity
 (fz-ok 300 50 fz-s2 (\ v (= (sat (scat (cap v) (cabp v))) (+ (sat (cap v)) (sat (cabp v))))))
 (fz-ok 250 51 fz-s3 (\ v (= (scat (scat (cap v) (cabp v)) (cabbp v))
                             (scat (cap v) (scat (cabp v) (cabbp v))))))
 (fz-ok 300 52 fz-s (\ s (= s (scat "" s))))
 (fz-ok 300 53 fz-s (\ s (= s (scat s ""))))
 ; slice: any split reconcatenates to the original; the full slice is the string
 (fz-ok 300 54 fz-s-i (\ v (= (cap v) (fz-norm (scat (slice (cap v) 0 (cbp v))
                                            (slice (cap v) (cbp v) (sat (cap v))))))))
 (fz-ok 300 55 fz-s (\ s (= s (fz-norm (slice s 0 (sat s))))))
 ; the slice length is j-i, and out-of-range indices clamp to [0, pin]
 (fz-ok 300 56 fz-s-ij (\ v (= (- (cabbp v) (cabp v)) (sat (slice (cap v) (cabp v) (cabbp v))))))
 (fz-ok 300 57 fz-s (\ s (= (fz-norm (slice s 0 (sat s))) (fz-norm (slice s -9 (+ 99 (sat s)))))))
 ; slice recovers the two operands of a scat
 (fz-ok 250 58 fz-s2 (\ v (= (cap v) (fz-norm (slice (scat (cap v) (cabp v)) 0 (sat (cap v)))))))
 (fz-ok 250 59 fz-s2 (\ v (= (cabp v) (fz-norm (slice (scat (cap v) (cabp v))
                              (sat (cap v)) (+ (sat (cap v)) (sat (cabp v))))))))
 ; string is identity on strings; charlist->string round-trips by bytes and length
 (fz-ok 300 60 fz-s (\ s (= s (string s))))
 (fz-ok 250 61 fz-cl1 (\ cl (= cl (fz-s2cl (string cl)))))
 (fz-ok 250 62 fz-cl1 (\ cl (= (sat cl) (sat (string cl)))))
 ; get yields the default outside [0, pin)
 (fz-ok 300 63 fz-s (\ s (&& (= 'oob (peep s (sat s) 'oob)) (= 'oob (peep s -1 'oob)))))
 ; print -> read round trip over arbitrary byte strings
 (fz-ok 250 64 fz-s (\ s (= s (fz-rd s)))))
