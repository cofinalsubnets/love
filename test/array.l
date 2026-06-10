; step 5a: typed multi-rank arrays.
; - (arr type shape 0) zero-fills; (arr type shape vals) fills row-major
; - get: fixnum index (rank 1), shape-list index (rank N), oob -> default
; - arank / alen / ashape / atype accessors
; - elementwise + - * / over arrays + scalar broadcast + numpy broadcasting
; - mixed element-type promotes to the widest type
; - < <= > >= = elementwise -> 0/1 bool array
; - reductions asum aprod amax amin aall aany; identity on scalars
; - vector falsiness: a tuple is false iff every element is 0
; - elementwise transcendentals (sqrt) over an array
; - print round-trip; non-conforming / non-numeric -> nil

(assert
 ; --- constructor + accessors ---
 (= 2 (arank (arr z '(2 3) 0)))
 (= 0 (arank (arr z 0 0)))            ; empty shape (nil) -> rank-0 scalar
 (= 6 (alen (arr z '(2 3) 0)))
 (= 1 (alen (arr r 0 0)))             ; rank-0 has one element
 (= z (atype (arr z '(2 3) 0)))
 (= r (atype (arr r '(4) 0)))
 (= '(2 3) (ashape (arr z '(2 3) 0)))
 (= 0 (ashape (arr z 0 0)))           ; rank-0 shape is the empty list (nil)
 (nilp (arank 5))                     ; non-tuple -> nil
 (nilp (atype "x"))

 ; --- get: rank-1 fixnum index ---
 (= 10 (peep (arr z '(3) '(10 20 30)) 0 -1))
 (= 20 (peep (arr z '(3) '(10 20 30)) 1 -1))
 (= 30 (peep (arr z '(3) '(10 20 30)) 2 -1))
 (= -1 (peep (arr z '(3) '(10 20 30)) 3 -1))   ; out of bounds -> default
 (= -1 (peep (arr z '(3) '(10 20 30)) -1 -1))  ; negative -> default

 ; --- get: rank-N shape-list index, row-major ---
 (= 1 (peep (arr z '(2 2) '(1 2 3 4)) '(0 0) -1))
 (= 2 (peep (arr z '(2 2) '(1 2 3 4)) '(0 1) -1))
 (= 3 (peep (arr z '(2 2) '(1 2 3 4)) '(1 0) -1))
 (= 4 (peep (arr z '(2 2) '(1 2 3 4)) '(1 1) -1))
 (= -1 (peep (arr z '(2 2) '(1 2 3 4)) '(2 0) -1))  ; oob -> default
 (= -1 (peep (arr z '(2 2) 0) 0 -1))                   ; wrong-rank key -> default
 (= -1 (peep (arr z '(2 2) 0) '(0) -1))                ; too-few indices -> default

 ; --- rank-0 deref: empty/nil key yields the lone scalar ---
 (= 2.5 (peep 2.5 0 -9))

 ; --- float element read boxes an r ---
 (= 1.5 (peep (arr r '(2) '(1.5 2.5)) 0 -1))
 (flop (peep (arr r '(2) '(1.5 2.5)) 0 -1))

 ; --- scalar broadcast: array (op) scalar ---
 (aall (= (arr z '(3) '(11 21 31)) (+ (arr z '(3) '(10 20 30)) 1)))
 (aall (= (arr z '(3) '(9 19 29)) (- (arr z '(3) '(10 20 30)) 1)))
 (aall (= (arr z '(2) '(4 6)) (* (arr z '(2) '(2 3)) 2)))
 (aall (= (arr z '(2) '(3 5)) (// (arr z '(2) '(7 11)) 2)))   ; `//` floor division, stays z
 (= r (atype (/ (arr z '(2) '(7 11)) 2)))                     ; `/` promotes (7/2 inexact) -> r
 (aall (= (arr r '(2) '(3.5 5.5)) (/ (arr z '(2) '(7 11)) 2)))
 (aall (= (arr z '(2) '(4 6)) (/ (arr z '(2) '(8 12)) 2)))   ; `/` stays z when every element divides evenly
 (aall (= (arr z '(2) '(1 1)) (mod (arr z '(2) '(7 11)) 2)))
 (aall (= (arr z '(3) '(2 4 6)) (+ 1 (arr z '(3) '(1 3 5)))))  ; scalar on the left

 ; --- array (op) array, same shape ---
 (aall (= (arr z '(3) '(11 22 33))
          (+ (arr z '(3) '(10 20 30)) (arr z '(3) '(1 2 3)))))
 (aall (= (arr z '(3) '(9 18 27))
          (- (arr z '(3) '(10 20 30)) (arr z '(3) '(1 2 3)))))

 ; --- numpy broadcasting: outer sum of a column and a row ---
 (aall (= (arr z '(3 3) '(11 21 31 12 22 32 13 23 33))
          (+ (arr z '(3 1) '(1 2 3)) (arr z '(1 3) '(10 20 30)))))
 ; size-1 axis stretches
 (aall (= (arr z '(2 2) '(11 21 12 22))
          (+ (arr z '(2 2) '(1 1 2 2)) (arr z '(1 2) '(10 20)))))

 ; --- mixed element-type promotes to the widest ---
 (= r (atype (+ (arr z '(2) 0) 1.5)))            ; z array + r scalar -> r
 (aall (= (arr r '(2) '(1.5 1.5)) (+ (arr z '(2) 0) 1.5)))
 (= z (atype (+ (arr z '(2) 0) (arr z '(2) 0))))  ; z + z -> z
 (= z (atype (+ (arr z '(2) 0) 1)))                ; scalar int never widens the array

 ; --- comparison -> 0/1 bool array ---
 (aall (< (arr z '(3) '(1 2 3)) 10))
 !(aall (< (arr z '(3) '(1 2 30)) 10))
 (sat (< (arr z '(3) '(1 20 30)) 10))
 !(sat (< (arr z '(3) '(10 20 30)) 5))
 (aall (= (arr z '(3) '(1 0 1)) (< (arr z '(3) '(1 5 2)) 3)))
 (= z (atype (< (arr z '(3) 0) 1)))               ; bool array is z
 ; whole-array equality is (aall (= a b))
 (aall (= (arr z '(2) '(5 6)) (arr z '(2) '(5 6))))
 !(aall (= (arr z '(2) '(5 6)) (arr z '(2) '(5 7))))

 ; --- reductions ---
 (= 60 (asum (arr z '(3) '(10 20 30))))
 (= 6000 (aprod (arr z '(3) '(10 20 30))))
 (= 30 (amax (arr z '(3) '(10 30 20))))
 (= 10 (amin (arr z '(3) '(20 10 30))))
 (= 6.0 (asum (arr r '(3) '(1.0 2.0 3.0))))
 (= 21 (asum (arr z '(2 3) '(1 2 3 4 5 6))))    ; reduces over all axes
 (aall (arr z '(3) '(1 2 3)))                   ; no zero element
 !(aall (arr z '(3) '(1 0 3)))               ; a zero element
 (sat (arr z '(3) '(0 0 3)))
 !(sat (arr z '(3) 0))                         ; all zero

 ; --- reductions are the identity on a scalar (rank-agnostic idiom) ---
 (= 5 (asum 5))
 (= 5 (amax 5))
 (= 1 (aall 1))
 (= 0 (aall 0))
 (aall (< 1 2))                                    ; scalar: (< 1 2) = 1, (aall 1) = 1
 !(aall (< 2 1))
 (aall (< (arr z '(2) '(1 2)) (arr z '(2) '(3 4))))  ; array: same expression

 ; --- truthiness is zero-magnitude (L2 norm): a value is false iff |x| == 0 ---
 (nilp (arr z '(3) 0))                  ; zero array -> false
 (nilp (arr r '(2 2) 0))                ; zero float array -> false
 (nilp (arr z '(0) 0))                  ; empty array -> vacuously false
 (nilp 0.0)                             ; boxed 0.0 -> false (was a truthy wart)
 !(nilp 2.5)                         ; positive float -> true
 (nilp -5)                           ; a negative real is now FALSE (<= 0)
 !(nilp (+ (arr z '(2) 0) 1))        ; nonzero array -> true
 !(nilp @(-3 -4))                    ; a NEGATIVE array stays true (norm, sign squares away)
 (= 1 (? (arr z '(3) 0) 0 1))         ; zero array takes the false arm
 (= 0 (? (+ (arr z '(3) 0) 1) 0 1))    ; nonzero array takes the true arm
 ; a single non-zero component makes the norm non-zero (truthy), per the tower:
 !(nilp @(0 0 5))                    ; one non-zero element -> true
 (nilp @(0.0 0.0))                      ; all-zero float tuple -> false
 (nilp ~(0 0))                         ; complex 0+0i (|z|=0) -> false
 !(nilp ~(0 1))                     ; 0+1i (|z|=1) -> true
 !(nilp i)                           ; the imaginary unit is truthy

 ; --- elementwise transcendentals over an array ---
 (aall (= (arr r '(2) '(2.0 3.0)) ((/ 1 2) (arr r '(2) '(4.0 9.0)))))
 (= r (atype ((/ 1 2) (arr z '(3) 0))))  ; result is a float array

 ; --- print as constructor forms ---
 ; rank-1 -> the @(…) sugar (@ reader splices into (tuple …)); rank>=2 ->
 ; (array '(shape) elem …) -- always a surface form, the type re-inferred
 (= "@(10 20 30)" (show (arr z '(3) '(10 20 30))))
 (= "(array '(2 2) 1 2 3 4)" (show (arr z '(2 2) '(1 2 3 4))))
 (= "@(1.5 2.5)" (show (arr r '(2) '(1.5 2.5))))
 (= "@(1 2 3)" (show (arr z '(3) '(1 2 3))))   ; z aliases the word-int kind -> terse @
 ; @(…) reads back to an equal array; the explicit form is a plain constructor call
 (aall (= (arr z '(3) '(10 20 30)) @(10 20 30)))
 (aall (= (arr r '(2) '(1.5 2.5)) @(1.5 2.5)))
 (aall (= (arr z '(2 2) '(1 2 3 4)) (arr z '(2 2) '(1 2 3 4))))
 ; the printed form reads back to an equal array
 (aall (= (arr z '(3) '(10 20 30)) (tuple 10 20 30)))
 (aall (= (arr z '(2 2) '(1 2 3 4)) (arr z '(2 2) '(1 2 3 4))))
 (aall (= (arr r '(2) '(1.5 2.5)) (tuple 1.5 2.5)))

 ; --- non-conforming / non-numeric -> nil ---
 (nilp (+ (arr z '(3) 0) (arr z '(4) 0)))   ; shapes [3] and [4] don't conform
 (nilp (+ (arr z '(3) 0) "x"))              ; non-numeric operand
 (nilp (arr z '(3) 0))                      ; (sanity) zero array is falsy
 (nilp (arr 99 '(3) 0)))                      ; bad type code -> nil
