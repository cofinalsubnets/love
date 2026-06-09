; hasht constructor (nested `put`) + %(…) printer/reader form
(: t (hasht 1 100 2 200 3 300))
(assert
 ; the constructor builds a working hash
 (mapp t) (nilp (mapp 5)) (nilp (mapp '(1 2)))   ; mapp: only maps, not fixnums/lists
 (lamp t) (lamp A) (nilp (lamp 5)) (nilp (lamp 0))  ; lamp: any heap object, not a fixnum/nil
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
 (fixp (hash 'k))
 (= (hash 'k) (hash 'k))
 (= (hash '(1 2)) (hash '(1 2))))

; %(…) reader macro: splices a list operand into (hasht …), wraps an atom as (hasht x),
; and %() builds a fresh empty hash. Hashes print as %(…), round-tripping via %.
(: ht %(1 100 2 200 3 300))
(assert
 (mapp ht)
 (= 100 (get 0 1 ht))
 (= 300 (get 0 3 ht))
 (mapp %())                                     ; %() -> empty hash
 (= 50 (get 0 5 (put 5 50 %())))                ; the empty hash is mutable
 (= 3 (foldl (\ n _ (+ 1 n)) 0 (hashk %(1 10 2 20 3 30))))   ; splice builds all entries
 (= "%0" (inspect %()))
 (= "%(1 \"hi\")" (inspect %(1 "hi"))))

; # reader macro wraps its operand in (pin …): #x -> (pin x)
(assert
 (= 3 #'(1 2 3))                                 ; #quoted-list -> pair count
 (= 5 #"hello")                                  ; #string -> byte length
 (= 42 #42)                                      ; #positive number -> ceil magnitude
 (= 0 #-7)                                        ; #negative number -> 0 (<= 0 is falsy)
 (= 2 #(hasht 1 10 2 20))                        ; #map-expr -> key count
 (= 8 #@(3 4 5)))                                ; #array -> ceil(L2 norm) = ceil(sqrt 50)

; pin/# is a SATURATING NON-NEGATIVE size: a non-positive scalar clamps to 0 (so it is
; falsy), a positive real/complex gives its ceil'd magnitude, an array its ceil(L2 norm)
; (sign squares away, so negatives stay truthy), a count on list/string/buf, a name length
; on symbols, FIX_MAX on a positive bignum. abs is the plain magnitude -- the two DIVERGE on
; negatives: (abs -5) = 5 but #-5 = 0.
(assert
 (= 4 (pin 3.9)) (= 0 (pin -3.9))               ; positive float -> ceil; negative -> 0
 (= 5 (abs -5)) (= 0 (pin -5))                  ; abs is magnitude; # clamps a non-positive scalar to 0
 (= 5 (pin ~(3 4)))                            ; complex re>0 -> ceil|z| (modulus): exact 5
 (= 5 (pin ~(3 -4)))                           ; re>0 sorts above 0 -> ceil|z|
 (= 0 (pin ~(-3 4)))                           ; re<0 sorts below 0 -> 0 (falsy)
 (= 0 (pin ~(0 -1)))                           ; -i: re=0, im<0 -> 0 (falsy)
 (= 1 (pin i))                                  ; i = ~(0 1): re=0, im>0 sorts above 0 -> ceil 1
 (= 5 (pin @(3 4)))                             ; array -> ceil(L2 norm): the 3-4-5 triangle
 (= 5 (pin @(-3 -4)))                           ; array norm is sign-independent -> negatives stay truthy
 (= 0 (pin (arr i64 '(2 3))))                   ; all-zero array -> norm 0
 (= 1 (pin @(0.3 0.4)))                         ; ceil makes any nonzero magnitude -> >=1
 (= 1 (pin ~(0.001 0)))                        ; re>0 -> ceil(0.001) = 1; pin=0 iff sorts <= 0
 (= 1 (pin $x)) (= 1 (pin (nom 0)))          ; symbol name length; anon nom present -> floored to 1 (truthy)
 (= 0 (pin (nom "")))                        ; THE empty symbol (nom "") -> 0 (falsy, prints as ())
 (= 2 (pin (hasht 1 10 2 20)))                  ; table -> key count
 (= 2 (int (abs (hasht 1 10 2 20))))            ; abs of a table is its key count too
 (= (pin (100 2)) (pin (200 2)))          ; any positive bignum saturates to FIX_MAX
 (= 0 (pin (- 0 (100 2)))) (nilp (- 0 (100 2)))  ; negative bignum -> 0, falsy
 (= 0 (pin (- 0 (62 2))))                 ; negative wide-int box -> 0
 (= 0 (pin -7)) (nilp -7))                      ; ordinary negative fixnum -> 0, falsy

; the defining invariant: (nilp x) == (= 0 (pin x)) for every value. empty
; containers and exact zeros are false; every present value (incl. functions,
; ports, symbols, anonymous gensyms, bignums) is truthy with pin >= 1.
(: same? (\ x (= (? (nilp x) 1 0) (? (= 0 (pin x)) 1 0)))
(assert
 (nilp "") (nilp %()) (nilp (bufnew 0)) (nilp @0) (nilp 0) (nilp ())  ; empties/zeros are false
 !!"x" !!%(1 2) !!(nom 0)                                        ; present values are true
 !!A !!out !!(\ x x)                                                ; functions/ports too
 (same? "") (same? %()) (same? (bufnew 0)) (same? @0) (same? 0)
 (same? "x") (same? %(1 2)) (same? (nom 0)) (same? A) (same? out)
 (same? ~(0 0)) (same? ~(0.3 0.4)) (same? @(0 0)) (same? @(0.1 0))
 (same? (100 2)) (same? 'abc) (same? '(1 2))))
