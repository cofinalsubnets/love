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
; fz-find returns (cons -1 0) on success or (cons 0 counterexample) on failure;
; to debug a red property interactively, eval (inspect (cdr (fz-find n seed g p)))
; to see the offending input.
(:
 ; --- generator monad: pure / map / bind over the functional RNG ---
 (fz-pure v) (\ st (cons v st))                          ; ignores the stream
 (fz-map f g) (\ st (: r (g st) (cons (f (car r)) (cdr r))))
 (fz-bind g k) (\ st (: r (g st) ((k (car r)) (cdr r)))) ; feed value into next gen
 ; --- primitive draws (every range below keeps hi > lo so randint never %0) ---
 (fz-nat n) (\ st (randint st n))                        ; [0, n)
 (fz-int lo hi) (fz-map (+ lo) (fz-nat (- hi lo)))       ; [lo, hi)
 (fz-elt l) (\ st (: r (randint st (len l)) (cons (car (drop (car r) l)) (cdr r))))
 (fz-oneof gs) (fz-bind (fz-nat (len gs)) (\ k (car (drop k gs))))  ; pick a generator
 ; --- structured draws: fixed repetition, bounded-length list, tuples ---
 (fz-rep n g) (? (< n 1) (fz-pure 0)
    (\ st (: a (g st) b ((fz-rep (- n 1) g) (cdr a)) (cons (cons (car a) (car b)) (cdr b)))))
 (fz-list mx g) (\ st (: r (randint st (+ 1 mx)) ((fz-rep (car r) g) (cdr r))))  ; len in [0,mx]
 (fz-pair2 ga gb) (\ st (: a (ga st) b (gb (cdr a)) (cons (L (car a) (car b)) (cdr b))))
 (fz-trip ga gb gc)
   (\ st (: a (ga st) b (gb (cdr a)) c (gc (cdr b)) (cons (L (car a) (car b) (car c)) (cdr c))))
 ; --- the driver: N trials from `seed`, first counterexample wins ---
 (fz-find n seed g p)
   (: (go n st) (? (< n 1) (cons -1 0)
        (: r (g st) (? (p (car r)) (go (- n 1) (cdr r)) (cons 0 (car r)))))
      (go n (rng-seed seed)))
 (fz-ok n seed g p) (car (fz-find n seed g p)))

; --- concrete value generators over the numeric tower ---
(: fz-fix    (fz-int -1000 1000)                         ; fixnums straddling 0
   fz-fix-nz (fz-map (\ x (? (= x 0) 1 x)) fz-fix)       ; nonzero fixnum (safe divisor)
   ; s * 2^e with e up to 160 forces the box / bignum tiers and both signs
   fz-bignum (fz-bind (fz-int 58 160) (\ e (fz-map (\ s (* s (** 2 e))) (fz-elt '(-3 -1 1 3 5)))))
   fz-num    (fz-oneof (L fz-fix fz-bignum))             ; mixed-tier value
   fz-num-nz (fz-map (\ x (? (= x 0) 1 x)) fz-num)       ; nonzero mixed-tier (divisor)
   fz-elem   (fz-int -20 20)                             ; small list/array element
   fz-l      (fz-list 8 fz-elem))                        ; list of small ints, len 0..8

; ---- numeric-tower algebra: laws that hold across fixnum / box / bignum ----
(assert
 ; commutativity of + and *
 (fz-ok 400 1 (fz-pair2 fz-num fz-num) (\ v (= (+ (car v) (cadr v)) (+ (cadr v) (car v)))))
 (fz-ok 400 2 (fz-pair2 fz-num fz-num) (\ v (= (* (car v) (cadr v)) (* (cadr v) (car v)))))
 ; associativity of + and *
 (fz-ok 300 3 (fz-trip fz-num fz-num fz-num)
   (\ v (= (+ (+ (car v) (cadr v)) (caddr v)) (+ (car v) (+ (cadr v) (caddr v))))))
 (fz-ok 300 4 (fz-trip fz-num fz-num fz-num)
   (\ v (= (* (* (car v) (cadr v)) (caddr v)) (* (car v) (* (cadr v) (caddr v))))))
 ; left distributivity: a*(b+c) = a*b + a*c
 (fz-ok 300 5 (fz-trip fz-num fz-num fz-num)
   (\ v (= (* (car v) (+ (cadr v) (caddr v)))
           (+ (* (car v) (cadr v)) (* (car v) (caddr v))))))
 ; negation is involutive; subtraction anti-commutes
 (fz-ok 400 6 fz-num (\ a (= a (- 0 (- 0 a)))))
 (fz-ok 300 7 (fz-pair2 fz-num fz-num) (\ v (= (- (car v) (cadr v)) (- 0 (- (cadr v) (car v))))))
 ; multiplying by zero / one
 (fz-ok 300 8 fz-num (\ a (= 0 (* a 0))))
 (fz-ok 300 9 fz-num (\ a (= a (* a 1))))
 ; divmod identity: a = (a/b)*b + a%b, and the remainder is smaller in magnitude
 (fz-ok 400 10 (fz-pair2 fz-num fz-num-nz)
   (\ v (= (car v) (+ (* (/ (car v) (cadr v)) (cadr v)) (mod (car v) (cadr v))))))
 ; remainder sign follows the dividend (truncated division)
 (fz-ok 400 11 (fz-pair2 fz-fix fz-fix-nz)
   (\ v (: r (mod (car v) (cadr v)) (|| (= r 0) (= (< r 0) (< (car v) 0))))))
 ; exact-power recurrence and the float-free modpow against ** then %
 (fz-ok 300 12 (fz-pair2 (fz-int -6 7) (fz-nat 14))
   (\ v (= (** (car v) (+ 1 (cadr v))) (* (car v) (** (car v) (cadr v))))))
 (fz-ok 250 13 (fz-trip (fz-nat 30) (fz-nat 14) (fz-int 2 500))
   (\ v (= (modpow (car v) (cadr v) (caddr v)) (mod (** (car v) (cadr v)) (caddr v)))))
 ; gcd divides both arguments
 (fz-ok 300 14 (fz-pair2 fz-fix-nz fz-fix-nz)
   (\ v (: g (gcd (car v) (cadr v)) (&& (= 0 (mod (car v) g)) (= 0 (mod (cadr v) g)))))))

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
   (\ v (= (** (cadr v) (car v)) ((car v) (cadr v)))))
 ; function operand: ((n (+ k)) x) == x + n*k  (composition depth n bounded to <= 6)
 (fz-ok 300 16 (fz-trip fz-op (fz-int -3 4) (fz-int -10 10))
   (\ v (= (+ (* (car v) (cadr v)) (caddr v)) ((car v) (+ (cadr v)) (caddr v))))))

; ---- list-combinator identities ----
(assert
 (fz-ok 300 20 fz-l (\ l (= l (rev (rev l)))))                          ; rev is involutive
 (fz-ok 300 21 fz-l (\ l (= l (map id l))))                            ; map id = id
 (fz-ok 300 22 fz-l (\ l (= l (foldr cons 0 l))))                      ; foldr cons nil = id
 (fz-ok 300 23 (fz-pair2 fz-l fz-l)
   (\ v (= (len (cat (car v) (cadr v))) (+ (len (car v)) (len (cadr v))))))   ; cat length
 (fz-ok 300 24 (fz-pair2 fz-l fz-l)
   (\ v (= (rev (cat (car v) (cadr v))) (cat (rev (cadr v)) (rev (car v))))))  ; rev of cat
 (fz-ok 300 25 fz-l (\ l (= (len (map (+ 1) l)) (len l))))             ; map preserves length
 ; take n ++ drop n = identity, for n drawn within [0, len]
 (fz-ok 300 26 (fz-bind fz-l (\ l (fz-map (\ n (L l n)) (fz-int 0 (+ 1 (len l))))))
   (\ v (= (car v) (cat (take (cadr v) (car v)) (drop (cadr v) (car v))))))
 ; filter keeps only matching elements and never grows the list
 (fz-ok 300 27 fz-l
   (\ l (: p (\ x (= 0 (mod x 2))) (&& (all p (filter p l)) (<= (len (filter p l)) (len l))))))
 ; an element consed on is found by memq
 (fz-ok 300 28 (fz-pair2 fz-elem fz-l) (\ v (memq (car v) (cons (car v) (cadr v))))))

; ---- print -> read round trip on random s-expressions ----
; reuses the io.c reader: serialize via inspect, re-read the bytes, expect equality.
(: (fz-s2cl s) ((: (g i) (? (< i (len s)) (cons (get 0 i s) (g (+ 1 i))))) 0)
   (fz-rd x) (fread (strin (fz-s2cl (inspect x))) (gensym 0))
   fz-syms '(a b c d foo bar baz qux)
   fz-leaf (fz-oneof (L (fz-elt fz-syms) (fz-int -500 500)))
   (fz-sexp d) (? (< d 1) fz-leaf
      (\ st (: r (randint st 3)            ; 1/3 leaf, 2/3 a bounded list of sub-exprs
          (? (= (car r) 0) (fz-leaf (cdr r))
             ((fz-list 4 (fz-sexp (- d 1))) (cdr r)))))))
(assert
 (fz-ok 200 30 fz-leaf (\ x (= x (fz-rd x))))            ; leaves: ints + symbols
 (fz-ok 200 31 (fz-sexp 3) (\ x (= x (fz-rd x))))        ; nested structure round-trips
 (fz-ok 150 32 (fz-sexp 4) (\ x (= x (fz-rd x)))))

; ---- array broadcasting / reduction laws (i64 elementwise) ----
; fz-arrpair draws two i64 vectors of the same random length so elementwise ops line up.
(: fz-arrpair (fz-bind (fz-int 1 6) (\ n (\ st
    (: a ((fz-rep n fz-elem) st) b ((fz-rep n fz-elem) (cdr a))
       (cons (L (arrl i64 (L n) (car a)) (arrl i64 (L n) (car b))) (cdr b)))))))
(assert
 (fz-ok 250 40 fz-arrpair (\ v (aall (= (+ (car v) (cadr v)) (+ (cadr v) (car v))))))  ; + commutes
 (fz-ok 250 41 fz-arrpair (\ v (aall (= (* (car v) (cadr v)) (* (cadr v) (car v))))))  ; * commutes
 ; sum is linear: sum(a+b) = sum(a) + sum(b)
 (fz-ok 250 42 fz-arrpair
   (\ v (= (asum (+ (car v) (cadr v))) (+ (asum (car v)) (asum (cadr v)))))))

; ---- string operations: scat / ssub / string / get / print->read ----
; fz-str draws a random byte string (length 0..mx, any byte 0..255 -- inspect's
; \xHH escaping round-trips them all). ssub returns nil for an empty slice
; (i==j), which scat and len treat as "" but `=` does not, so any comparison
; that can land on an empty slice routes through fz-norm (scat x "" coerces a
; nil/string to a string). fz-s2cl / fz-rd are the helpers from the round-trip
; section above (string->charlist, print->read).
(: fz-byte (fz-int 0 256)                                  ; any byte 0..255
   (fz-cl->str cl) (? (twop cl) (string cl) "")            ; charlist -> string ("" for nil)
   (fz-norm x) (scat x "")                                 ; nil|string -> string
   (fz-str mx) (fz-map fz-cl->str (fz-list mx fz-byte))    ; string, len 0..mx
   fz-s    (fz-str 12)
   fz-s2   (fz-pair2 fz-s fz-s)
   fz-s3   (fz-trip fz-s fz-s fz-s)
   fz-cl1  (fz-bind (fz-int 1 12) (\ n (fz-rep n fz-byte))) ; nonempty charlist
   ; a string paired with a split point i in [0, len]
   fz-s-i  (fz-bind fz-s (\ s (fz-map (\ i (cons s i)) (fz-int 0 (+ 1 (len s))))))
   ; a string with 0 <= i <= j <= len, as (L s i j)
   fz-s-ij (fz-bind fz-s (\ s (fz-bind (fz-int 0 (+ 1 (len s)))
              (\ i (fz-map (\ j (L s i j)) (fz-int i (+ 1 (len s)))))))))
(assert
 ; scat: length adds, is associative, and "" is a two-sided identity
 (fz-ok 300 50 fz-s2 (\ v (= (len (scat (car v) (cadr v))) (+ (len (car v)) (len (cadr v))))))
 (fz-ok 250 51 fz-s3 (\ v (= (scat (scat (car v) (cadr v)) (caddr v))
                             (scat (car v) (scat (cadr v) (caddr v))))))
 (fz-ok 300 52 fz-s (\ s (= s (scat "" s))))
 (fz-ok 300 53 fz-s (\ s (= s (scat s ""))))
 ; ssub: any split reconcatenates to the original; the full slice is the string
 (fz-ok 300 54 fz-s-i (\ v (= (car v) (fz-norm (scat (ssub (car v) 0 (cdr v))
                                            (ssub (car v) (cdr v) (len (car v))))))))
 (fz-ok 300 55 fz-s (\ s (= s (fz-norm (ssub s 0 (len s))))))
 ; the slice length is j-i, and out-of-range indices clamp to [0, len]
 (fz-ok 300 56 fz-s-ij (\ v (= (- (caddr v) (cadr v)) (len (ssub (car v) (cadr v) (caddr v))))))
 (fz-ok 300 57 fz-s (\ s (= (fz-norm (ssub s 0 (len s))) (fz-norm (ssub s -9 (+ 99 (len s)))))))
 ; ssub recovers the two operands of a scat
 (fz-ok 250 58 fz-s2 (\ v (= (car v) (fz-norm (ssub (scat (car v) (cadr v)) 0 (len (car v)))))))
 (fz-ok 250 59 fz-s2 (\ v (= (cadr v) (fz-norm (ssub (scat (car v) (cadr v))
                              (len (car v)) (+ (len (car v)) (len (cadr v))))))))
 ; string is identity on strings; charlist->string round-trips by bytes and length
 (fz-ok 300 60 fz-s (\ s (= s (string s))))
 (fz-ok 250 61 fz-cl1 (\ cl (= cl (fz-s2cl (string cl)))))
 (fz-ok 250 62 fz-cl1 (\ cl (= (len cl) (len (string cl)))))
 ; get yields the default outside [0, len)
 (fz-ok 300 63 fz-s (\ s (&& (= 'oob (get 'oob (len s) s)) (= 'oob (get 'oob -1 s)))))
 ; print -> read round trip over arbitrary byte strings
 (fz-ok 250 64 fz-s (\ s (= s (fz-rd s)))))
