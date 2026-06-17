; hash constructor (nested `put`) + #(…) printer/reader form
(: t (hash 1 100 2 200 3 300))
(assert
 ; the constructor builds a working hash
 (tabp t) (nilp (tabp 5)) (nilp (tabp '(1 2)))   ; tabp: only maps, not fixnums/lists
 (lamp t) (lamp cap) (nilp (lamp 5)) (nilp (lamp 0))  ; lamp: any heap object, not a fixnum/nil
 (= 100 (peep t 1 0))
 (= 200 (peep t 2 0))
 (= 300 (peep t 3 0))
 (= 0 (peep t 9 0))                              ; missing key -> default
 (= 3 (foldl (\ n _ (+ 1 n)) 0 (keys t)))      ; three entries
 ; empty + single-entry printer forms are deterministic (no bucket-order dependence)
 (= "(tablet 0)" (show (tablet 0)))
 (= "#(1 100)" (show (hash 1 100)))
 (= "#(1 \"hi\")" (show (hash 1 "hi")))
 (strp (show t))                             ; multi-entry: just exercise the path
 ; (dig x) exposes the runtime hashing method: a fixnum, equal for eql keys
 (fixp (dig 'k))
 (= (dig 'k) (dig 'k))
 (= (dig '(1 2)) (dig '(1 2))))

; #(…) reader macro: splices a list operand into (hash …), wraps an atom as (hash x) --
; a BOX. #() reads to the EMPTY MAP directly: the reader emits (tablet 0) -- () is the
; zero-point, distinct from 0. hashes print as #(…), the empty map as (tablet 0).
(: ht #(1 100 2 200 3 300))
(assert
 (tabp ht)
 (= 100 (peep ht 1 0))
 (= 300 (peep ht 3 0))
 (tabp (tablet 0))                              ; the empty hash
 !(tablet 0) !#()                               ; both the empty map (falsy); #() reads to (tablet 0)
 (= 50 (peep (pin (tablet 0) 5 50) 5 0))                ; the empty hash is mutable
 (= 3 (foldl (\ n _ (+ 1 n)) 0 (keys #(1 10 2 20 3 30))))   ; splice builds all entries
 (= "(tablet 0)" (show #()))                    ; #() is the empty map
 (= "#(1 \"hi\")" (show #(1 "hi"))))

; # on a NON-LIST datum boxes it: #x = #(0 x), a fresh mutable hash pinning x
; at 0 (the number) -- distinct from #() the empty map, since () (the zero-point)
; is NOT 0. the reader emits (tablet 0) for #() directly (the # empty exception).
(: bx #0)
(assert
 (tabp #0) !!#0 (= 1 $#0)                       ; a box is a nonempty 1-entry hash
 (= 0 (peep bx 0 9))                            ; the boxed value sits at key 0 (the number, not the empty)
 (= 9 (: _ (pin bx 0 9) (peep bx 0 0)))         ; ... and is mutable in place
 (= 5 (peep #5 0 0)) (= "s" (peep #"s" 0 0))    ; any scalar boxes (at key 0)
 (= 'a (peep (hash 'a) 0 0))                   ; (NB #'a SPLICES -- a quote form is a chain)
 (= "#(0 5)" (show #5))                      ; a box prints as #(0 v), reads back
 (= 7 (peep #(1 2 7) 0 0))                      ; an odd trailing operand lands in the box slot (key 0)
 (= 2 (peep #(1 2 7) 1 0)))

; # reader macro wraps its operand in (pin …): #x -> (pin x)
(assert
 (= 6 $'(1 2 3))                                 ; #quoted-list -> the elements' net sum
 (= 532 $"hello")                                ; $string -> the charm sum (tally counts)
 (= 42 $42)                                      ; #positive number -> ceil magnitude
 (= 0 $-7)                                        ; #negative number -> 0 (<= 0 is falsy)
 (= 2 $(hash 1 10 2 20))                        ; #map-expr -> key count
 (= 12 $@(3 4 5)))                               ; #array -> the elements' net sum

; sat/$ is ONE SATURATING CLAMP over the NET, max(0, ceil(net)): a number nets its own
; signed value (complex: |z| signed by the total order), text its length, a map its key
; count, a list or array the SUM of its elements' nets -- so negatives push an aggregate
; toward nothing, per the law: positive to positive, zero-or-negative to zero, at every
; rank. abs is the plain magnitude -- the two DIVERGE on negatives: (abs -5) = 5, $-5 = 0.
(assert
 (= 4 (sat 3.9)) (= 0 (sat -3.9))               ; positive float -> ceil; negative -> 0
 (= 5 (abs -5)) (= 0 (sat -5))                  ; abs is magnitude; $ clamps a non-positive scalar to 0
 (= 5 (sat ~(3 4)))                            ; complex re>0 -> ceil|z| (modulus): exact 5
 (= 5 (sat ~(3 -4)))                           ; re>0 sorts above 0 -> ceil|z|
 (= 0 (sat ~(-3 4)))                           ; re<0 sorts below 0 -> 0 (falsy)
 (= 0 (sat ~(0 -1)))                           ; -i: re=0, im<0 -> 0 (falsy)
 (= 1 (sat i))                                  ; i = ~(0 1): re=0, im>0 sorts above 0 -> ceil 1
 (= 7 (sat @(3 4)))                             ; array -> element sum
 (= 0 (sat @(-3 -4)))                           ; a list or array of negatives nets <= 0 -> nothing
 (= 0 (sat '(-2 1))) !'(-2 1)                   ; negatives cancel positives -- net -1 -> 0, falsy
 (= 0 (sat (arr 0 '(2 3) 0)))                   ; all-zero array -> net 0
 (= 1 (sat @(0.3 0.4)))                         ; ceil makes any positive net -> >=1
 (= 1 (sat ~(0.001 0)))                        ; re>0 -> ceil(0.001) = 1; sat=0 iff sorts <= 0
 (= 120 (sat (nom 'x)))                      ; a nom nets its spelling's charms + the mint's 0
 (= 0 (sat (mint 0))) !(mint 0)              ; the mint is materially EMPTY: a distinct nothing
 (= 0 (sat (intern "")))                     ; THE empty symbol -> 0 (falsy, prints as ())
 (= 2 (sat (hash 1 10 2 20)))                  ; table -> key count
 (= 2 (int (abs (hash 1 10 2 20))))            ; abs of a table is its key count too
 (= (sat (100 2)) (sat (200 2)))          ; any positive bignum saturates to FIX_MAX
 (= 0 (sat (- 0 (100 2)))) (nilp (- 0 (100 2)))  ; negative bignum -> 0, falsy
 (= 0 (sat (- 0 (62 2))))                 ; negative wide int -> 0
 (= 0 (sat -7)) (nilp -7))                      ; ordinary negative fixnum -> 0, falsy

; the defining invariant: (nilp x) == (= 0 (pin x)) for every value. empty
; containers and exact zeros are false; every present value (incl. functions,
; ports, symbols, bignums) is truthy with pin >= 1. (a MINT is the exception
; by design: the fresh point is materially empty -- a distinct NOTHING.)
(: same? (\ x (= (? (nilp x) 1 0) (? (= 0 (sat x)) 1 0)))
(assert
 (nilp "") (nilp (tablet 0)) (nilp (buf 0)) (nilp @0) (nilp 0) (nilp ())  ; empties/zeros are false
 !!"x" !!#(1 2) !(mint 0)                                        ; present values are true; the mint is nothing
 !!cap !!out !!(\ x x)                                                ; functions/ports too
 (same? "") (same? (tablet 0)) (same? (buf 0)) (same? @0) (same? 0)
 (same? "x") (same? #(1 2)) (same? (mint 0)) (same? cap) (same? out)
 (same? ~(0 0)) (same? ~(0.3 0.4)) (same? @(0 0)) (same? @(0.1 0))
 (same? (100 2)) (same? 'abc) (same? '(1 2))))
