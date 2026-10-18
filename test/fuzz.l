; property fuzzer over the functional rng: a generator is st -> (value . st').
; fz-find runs one n times from a fixed seed, answering (1 0) or (0 counterexample)
(:
 ; --- generator monad over the functional rng ---
 fz-pure (.)
 (fz-map f g) (st \ g st @ r (f <r . >r))
 (fz-bind g k) (st \ g st @ r (k <r >r))
 ; --- primitive draws: every range keeps hi > lo so random never mods by 0 ---
 (fz-nat n) (st \ random st n)                     ; [0, n)
 (fz-int lo hi) (fz-map (+ lo) (fz-nat (hi - lo))) ; [lo, hi)
 (fz-elt l) (st \ random st #l @ r (<(drop <r l) . >r))
 (fz-oneof gs) (fz-bind (fz-nat #gs) (k \ <(drop k gs)))
 (fz-rep n g) (n < 1 ? (fz-pure ())
    (st \ (: a (g st) b (fz-rep (n - 1) g >a) ((<a . <b) . >b))))
 (fz-list mx g) (st \ random st (1 + mx) @ r (fz-rep <r g >r))        ; length in [0,mx]
 (fz-pair2 ga gb) (st \ (: a (ga st) b (gb >a) ([<a <b] . >b)))
 (fz-trip ga gb gc)
   (st \ (: a (ga st) b (gb >a) c (gc >b) ([<a <b <c] . >c)))
 ; --- the driver: n trials from seed sd, first counterexample wins ---
 (fz-find n sd g p)
   (: (go n st) (n < 1 ? (1 . 0)
        (g st @ r (p <r ? (go (n - 1) >r) (0 . <r))))
      (go n (wheel sd)))
 (fz-ok n sd g p) <(fz-find n sd g p))

; --- value generators over the numeric tower ---
(: fz-fix    (fz-int -1000 1000)
   fz-fix-nz (fz-map (x \ x = 0 ? 1 x) fz-fix)           ; a safe divisor
   ; s * 2^e, e up to 160: the box and bignum tiers, both signs
   fz-bignum (fz-bind (fz-int 58 160) (e \ fz-map (s \ s * e 2) (fz-elt '(-3 -1 1 3 5))))
   fz-num    (fz-oneof [fz-fix fz-bignum])
   fz-num-nz (fz-map (x \ x = 0 ? 1 x) fz-num)
   fz-elem   (fz-int -20 20)
   fz-l      (fz-list 8 fz-elem))                        ; length 0..8

; ---- numeric-tower algebra across fixnum / box / bignum ----
(test
 (fz-ok 400 1 (fz-pair2 fz-num fz-num) (v \ <v + <>v = <>v + <v))
 (fz-ok 400 2 (fz-pair2 fz-num fz-num) (v \ <v * <>v = <>v * <v))
 (fz-ok 300 3 (fz-trip fz-num fz-num fz-num)
   (v \ (<v + <>v) + <>>v = <v + (<>v + <>>v)))
 (fz-ok 300 4 (fz-trip fz-num fz-num fz-num)
   (v \ (<v * <>v) * <>>v = <v * (<>v * <>>v)))
 (fz-ok 300 5 (fz-trip fz-num fz-num fz-num)
   (v \ <v * (<>v + <>>v) = <v * <>v + <v * <>>v))
 (fz-ok 400 6 fz-num (a \ a = 0 - (0 - a)))
 (fz-ok 300 7 (fz-pair2 fz-num fz-num) (v \ <v - <>v = 0 - (<>v - <v)))
 (fz-ok 300 8 fz-num (a \ 0 = a * 0))
 (fz-ok 300 9 fz-num (a \ a = a * 1))
 ; divmod: a = (a//b)*b + a%b
 (fz-ok 400 10 (fz-pair2 fz-num fz-num-nz)
   (v \ <v = <v // <>v * <>v + (<v % <>v)))
 ; the remainder wears the dividend's sign (truncated division)
 (fz-ok 400 11 (fz-pair2 fz-fix fz-fix-nz)
   (v \ (<v % <>v) @ r (r = 0 || (r < 0) = (<v < 0))))
 ; the power recurrence, and modpow against ** then %
 (fz-ok 300 12 (fz-pair2 (fz-int -6 7) (fz-nat 14))
   (v \ (1 + <>v) <v = (<v * <>v <v)))
 (fz-ok 250 13 (fz-trip (fz-nat 30) (fz-nat 14) (fz-int 2 500))
   (v \ modpow <v <>v <>>v = <>v <v % <>>v))
 (fz-ok 300 14 (fz-pair2 fz-fix-nz fz-fix-nz)
   (v \ gcd <v <>v @ g (0 = <v % g && 0 = <>v % g))))

; ---- church numerals: the operator stays 0..6 so no exponent or depth runs away ----
(: fz-op (fz-int 0 7))
(test
 ; (n m) == m ** n
 (fz-ok 300 15 (fz-pair2 fz-op (fz-int -4 5))
   (v \ <v <>v = <v <>v))
 ; ((n (+ k)) x) == x + n*k
 (fz-ok 300 16 (fz-trip fz-op (fz-int -3 4) (fz-int -10 10))
   (v \ <v * <>v + <>>v = (<v (+ <>v) <>>v))))

; ---- list-combinator identities ----
(test
 (fz-ok 300 20 fz-l (l \ l = rev (rev l)))
 (fz-ok 300 21 fz-l (l \ l = map id l))
 (fz-ok 300 22 fz-l (l \ l = foldr (.) () l))
 ; $ of a cat is the saturated sum of both element sums
 (fz-ok 300 23 (fz-pair2 fz-l fz-l)
   (v \ (: (sum x) (foldl (+) 0 x)
           a <v b <>v
           (#(a + b) = #a + #b && $(a + b) = $(sum a + sum b)))))
 (fz-ok 300 24 (fz-pair2 fz-l fz-l)
   (v \ rev (<v + <>v) = rev <>v + rev <v))
 (fz-ok 300 25 fz-l (l \ #(map (+ 1) l) = #l))
 ; take n ++ drop n, n within [0, length]
 (fz-ok 300 26 (fz-bind fz-l (l \ fz-map (n \ [l n]) (fz-int 0 (1 + #l))))
   (v \ <v = take <>v <v + drop <>v <v))
 ; filter never grows the spine (the clamped $ may grow)
 (fz-ok 300 27 fz-l
   (l \ (: p (x \ 0 = x % 2)
           (all p (filter p l) && #(filter p l) <= #l))))
 (fz-ok 300 28 (fz-pair2 fz-elem fz-l) (v \ elem <v (<v . <>v))))

; ---- print -> read round trip on random s-expressions ----
(: (fz-s2cl s) ((: (g i) (? (i < #s) (peep s i 0 . g (1 + i)))) 0)
   (fz-rd x) (rd-test (fz-s2cl (show x)) @ r (two? r ? <r r))
   fz-syms '(a b c d foo bar baz qux)
   fz-leaf (fz-oneof [(fz-elt fz-syms) (fz-int -500 500)])
   (fz-sexp d) (d < 1 ? fz-leaf
      (st \ random st 3 @ r               ; 1/3 leaf, 2/3 a bounded list
            (<r = 0 ? (fz-leaf >r)
               (fz-list 4 (fz-sexp (d - 1)) >r)))))
(test
 (fz-ok 200 30 fz-leaf (x \ x = fz-rd x))
 (fz-ok 200 31 (fz-sexp 3) (x \ x = fz-rd x))
 (fz-ok 150 32 (fz-sexp 4) (x \ x = fz-rd x)))

; ---- array broadcasting and reduction ----
; same random length, so elementwise ops line up
(: fz-arrpair (fz-bind (fz-int 1 6) (n \ (st \
                                               (: a (fz-rep n fz-elem st) b (fz-rep n fz-elem >a)
                                                  ([(star-tray [n] <a) (star-tray [n] <b)] . >b))))))
(test
 (fz-ok 250 40 fz-arrpair (v \ aall (<v + <>v = <>v + <v)))
 (fz-ok 250 41 fz-arrpair (v \ aall (<v * <>v = <>v * <v)))
 (fz-ok 250 42 fz-arrpair (v \ +(<v + <>v) = +<v + +<>v)))

; ---- strings ----
; an empty snip may be nil, which `=` tells from "", so such a comparison goes through fz-norm
(: fz-byte (fz-int 0 256)
   (fz-cl->str cl) (two? cl ? (string cl) "")
   (fz-norm x) (x ? x "")
   (fz-str mx) (fz-map fz-cl->str (fz-list mx fz-byte))    ; length 0..mx
   fz-s    (fz-str 12)
   fz-s2   (fz-pair2 fz-s fz-s)
   fz-s3   (fz-trip fz-s fz-s fz-s)
   fz-cl1  (fz-bind (fz-int 1 12) (n \ fz-rep n fz-byte))
   ; a string and a split point i in [0, length]
   fz-s-i  (fz-bind fz-s (s \ fz-map (. s) (fz-int 0 (1 + #s))))
   ; a string with 0 <= i <= j <= length
   fz-s-ij (fz-bind fz-s (s \ fz-bind (fz-int 0 (1 + #s))
             (i \ fz-map (j \ [s i j]) (fz-int i (1 + #s))))))
(test
 ; +: length adds, associative, "" a two-sided identity
 (fz-ok 300 50 fz-s2 (v \ $(<v + <>v) = $<v + $<>v))
 (fz-ok 250 51 fz-s3 (v \ (<v + <>v) + <>>v = <v + (<>v + <>>v)))
 (fz-ok 300 52 fz-s (s \ s = "" + s))
 (fz-ok 300 53 fz-s (s \ s = s + ""))
 ; snip: any split reconcatenates. 64-bit words only: elsewhere the rng stream diverges
 ; into inputs that fail
 (word ? (fz-ok 300 54 fz-s-i (v \ <v = fz-norm (fz-norm (snip <v 0 >v) +
                                                 fz-norm (snip <v >v #<v)))) 1)
 (word ? (fz-ok 300 55 fz-s (s \ s = fz-norm (snip s 0 #s))) 1)
 ; the snip length is j-i, and out-of-range indices clamp to [0, length]
 (fz-ok 300 56 fz-s-ij (v \ <>>v - <>v = #(snip <v <>v <>>v)))
 (fz-ok 300 57 fz-s (s \ fz-norm (snip s 0 #s) = fz-norm (snip s -9 (99 + #s))))
 (fz-ok 250 58 fz-s2 (v \ <v = fz-norm (snip (<v + <>v) 0 #<v)))
 (fz-ok 250 59 fz-s2 (v \ <>v = fz-norm (snip (<v + <>v) #<v (#<v + #<>v))))
 ; charlist->string round-trips by bytes and length
 (fz-ok 300 60 fz-s (s \ s = string s))
 (fz-ok 250 61 fz-cl1 (cl \ cl = fz-s2cl (string cl)))
 (fz-ok 250 62 fz-cl1 (cl \ (: (ln x) (foldl (n \ _ \ 1 + n) 0 x) (ln cl = #(string cl)))))
 ; peep yields the default outside [0, length)
 (fz-ok 300 63 fz-s (s \ 'oob = peep s #s 'oob && 'oob = peep s -1 'oob))
 (fz-ok 250 64 fz-s (s \ s = fz-rd s)))

; ---- mixed-band + and *: associativity across the bands ----
; `*` on chains (the cartesian product) associates only up to reassociation: fz-mul-skip
; leaves those shapes out
(: fz-nomv (fz-elt '(sym alpha b))
   ; * against a chain repeats it, so the count stays small
   fz-small (fz-int -4 5)
   fz-mix  (fz-oneof [fz-small fz-s fz-nomv fz-l])
   fz-mix3 (fz-trip fz-mix fz-mix fz-mix)
   (fz-txt? v) ((string? v || (v = () ? 0 (nom? v))) ? 1 0)
   (fz-ch? v)  (two? v ? 1 0)
   (fz-mul-skip a b c) (fz-ch? a && (fz-ch? b || fz-ch? c) && !(fz-txt? b) && !(fz-txt? c))
   (fz-add-assoc v)
    (v @ (a b c) (a + b + c = a + (b + c)))
   (fz-mul-assoc v)
    (v @ (a b c) (fz-mul-skip a b c ? 1 (a * b * c = a * (b * c))))
   fz-rows
    [['add-assoc-mixed 400 70 fz-mix3 fz-add-assoc]
     ['mul-assoc-mixed 400 71 fz-mix3 fz-mul-assoc]]
   (fz-row r)
    (r @ (nom n sd g p)
       (fz-find n sd g p @ res
        (<res ? 1 (puts ("fuzz FAILED: " + string nom + "   at " + show >res + "\n"), 0))))
   (fz-all rs) (atom? rs ? 1 (fz-row <rs && fz-all >rs)))
(test (fz-all fz-rows))
