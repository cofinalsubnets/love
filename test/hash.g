; hasht constructor (nested `put`) + %(…) printer/reader form
(: t (hasht 1 100 2 200 3 300))
(assert
 ; the constructor builds a working hash
 (hashp t)
 (= 100 (get 0 1 t))
 (= 200 (get 0 2 t))
 (= 300 (get 0 3 t))
 (= 0 (get 0 9 t))                              ; missing key -> default
 (= 3 (foldl (\ n _ (+ 1 n)) 0 (hashk t)))      ; three entries
 ; empty + single-entry printer forms are deterministic (no bucket-order dependence)
 (= "%0" (inspect (hashn 0)))
 (= "%(1 100)" (inspect (hasht 1 100)))
 (= "%(1 \"hi\")" (inspect (hasht 1 "hi")))
 (strp (inspect t))                             ; multi-entry: just exercise the path
 ; (hash x) exposes the runtime hashing method: a fixnum, equal for eql keys
 (nump (hash 'k))
 (= (hash 'k) (hash 'k))
 (= (hash '(1 2)) (hash '(1 2))))

; %(…) reader macro: splices a list operand into (hasht …), wraps an atom as (hasht x),
; and %() builds a fresh empty hash. Hashes print as %(…), round-tripping via %.
(: ht %(1 100 2 200 3 300))
(assert
 (hashp ht)
 (= 100 (get 0 1 ht))
 (= 300 (get 0 3 ht))
 (hashp %())                                     ; %() -> empty hash
 (= 50 (get 0 5 (put 5 50 %())))                ; the empty hash is mutable
 (= 3 (foldl (\ n _ (+ 1 n)) 0 (hashk %(1 10 2 20 3 30))))   ; splice builds all entries
 (= "%0" (inspect %()))
 (= "%(1 \"hi\")" (inspect %(1 "hi"))))

; # reader macro wraps its operand in (len …): #x -> (len x)
(assert
 (= 3 #'(1 2 3))                                 ; #quoted-list -> pair count
 (= 5 #"hello")                                  ; #string -> byte length
 (= 42 #42)                                      ; #number -> |x| (floored magnitude)
 (= 7 #-7)                                        ; negative fixnum -> |x|
 (= 2 #(hasht 1 10 2 20))                        ; #map-expr -> key count
 (= 8 #@(3 4 5)))                                ; #array -> ceil(L2 norm) = ceil(sqrt 50)

; len is total: a ceil'd magnitude on numbers and arrays (0 iff exactly zero), a
; count on list/string/buf containers, the name length on symbols, sat'd bignum.
(assert
 (= 4 (len 3.9)) (= 4 (len -3.9))               ; boxed float -> ceil|x|
 (= 5 (len (C 3 4)))                            ; complex -> ceil|z| (modulus): exact 5
 (= 5 (len @(3 4)))                             ; array -> ceil(L2 norm): the 3-4-5 triangle
 (= 0 (len (arr i64 '(2 3))))                   ; all-zero array -> norm 0
 (= 1 (len @(0.3 0.4)))                         ; ceil makes any nonzero magnitude -> >=1
 (= 1 (len (C 0.001 0)))                        ; ceil(0.001) = 1, so len=0 iff exactly zero
 (= 1 (len $x)) (= 1 (len (gensym 0)))          ; symbol name length; anon gensym floored to 1 (truthy)
 (= 2 (len (hasht 1 10 2 20)))                  ; table -> key count
 (= 2 (int (abs (hasht 1 10 2 20))))            ; abs of a table is its key count too
 (= (len (** 2 100)) (len (** 2 200)))          ; any bignum saturates to FIX_MAX
 (= (len (** 2 100)) (len (- 0 (** 2 100))))    ; sign-independent: |x|, never negative
 (< 0 (len (- 0 (** 2 100))))                   ; negative bignum still gives a positive len
 (= (len (** 2 100)) (len (- 0 (** 2 62))))     ; the FIX_MIN fixnum edge saturates too, no overflow
 (< 0 (len -7)) (= 7 (len -7)))                 ; ordinary negatives are just |x|

; the defining invariant: (nilp x) == (= 0 (len x)) for every value. empty
; containers and exact zeros are false; every present value (incl. functions,
; ports, symbols, anonymous gensyms, bignums) is truthy with len >= 1.
(: same? (\ x (= (? (nilp x) 1 0) (? (= 0 (len x)) 1 0)))
(assert
 (nilp "") (nilp %()) (nilp (bufnew 0)) (nilp @0) (nilp 0) (nilp ())  ; empties/zeros are false
 (not (nilp "x")) (not (nilp %(1 2))) (not (nilp (gensym 0)))         ; present values are true
 (not (nilp car)) (not (nilp out)) (not (nilp (\ x x)))               ; functions/ports too
 (same? "") (same? %()) (same? (bufnew 0)) (same? @0) (same? 0)
 (same? "x") (same? %(1 2)) (same? (gensym 0)) (same? car) (same? out)
 (same? (C 0 0)) (same? (C 0.3 0.4)) (same? @(0 0)) (same? @(0.1 0))
 (same? (** 2 100)) (same? 'abc) (same? '(1 2))))
