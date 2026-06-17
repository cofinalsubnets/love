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
 (= 2 (arank (arr Z '(2 3) 0)))
 (= 6 (alen (arr Z '(2 3) 0)))
 (= Z (atype (arr Z '(2 3) 0)))
 (= R (atype (arr R '(4) 0)))
 (= '(2 3) (ashape (arr Z '(2 3) 0)))
 (nilp (arank 5))                     ; non-tuple -> nil
 (nilp (atype "x"))

 ; --- a one-element array DEMOTES to its lone scalar gem (no rank-0 / singleton
 ; vec exists): an empty shape (rank 0, one cell) or a rank-1 length-1 array is
 ; just the value, so the array accessors read nil on it like any scalar ---
 (= 0 (arr Z 0 0))                    ; empty shape, zero-filled -> the fixnum 0
 (flop (arr R 0 0)) (= 0.0 (arr R 0 0))      ; -> a boxed 0.0
 (= 5 (arr Z '(1) '(5)))              ; rank-1 len-1 -> the fixnum 5
 (= 3.5 @(3.5)) (flop @(3.5))         ; @(3.5) is the scalar 3.5
 (nilp (arank (arr Z 0 0)))           ; a demoted scalar is not a tuple
 (nilp (alen (arr R 0 0)))
 (nilp (ashape (arr Z 0 0)))

 ; --- get: rank-1 fixnum index ---
 (= 10 (peep (arr Z '(3) '(10 20 30)) 0 -1))
 (= 20 (peep (arr Z '(3) '(10 20 30)) 1 -1))
 (= 30 (peep (arr Z '(3) '(10 20 30)) 2 -1))
 (= -1 (peep (arr Z '(3) '(10 20 30)) 3 -1))   ; out of bounds -> default
 (= -1 (peep (arr Z '(3) '(10 20 30)) -1 -1))  ; negative -> default

 ; --- get: rank-N shape-list index, row-major ---
 (= 1 (peep (arr Z '(2 2) '(1 2 3 4)) '(0 0) -1))
 (= 2 (peep (arr Z '(2 2) '(1 2 3 4)) '(0 1) -1))
 (= 3 (peep (arr Z '(2 2) '(1 2 3 4)) '(1 0) -1))
 (= 4 (peep (arr Z '(2 2) '(1 2 3 4)) '(1 1) -1))
 (= -1 (peep (arr Z '(2 2) '(1 2 3 4)) '(2 0) -1))  ; oob -> default
 (= -1 (peep (arr Z '(2 2) 0) 0 -1))                   ; wrong-rank key -> default
 (= -1 (peep (arr Z '(2 2) 0) '(0) -1))                ; too-few indices -> default

 ; --- rank-0 deref: empty/nil key yields the lone scalar ---
 (= 2.5 (peep 2.5 0 -9))

 ; --- float element read boxes an r ---
 (= 1.5 (peep (arr R '(2) '(1.5 2.5)) 0 -1))
 (flop (peep (arr R '(2) '(1.5 2.5)) 0 -1))

 ; --- scalar broadcast: array (op) scalar ---
 (aall (= (arr Z '(3) '(11 21 31)) (+ (arr Z '(3) '(10 20 30)) 1)))
 (aall (= (arr Z '(3) '(9 19 29)) (- (arr Z '(3) '(10 20 30)) 1)))
 (aall (= (arr Z '(2) '(4 6)) (* (arr Z '(2) '(2 3)) 2)))
 (aall (= (arr Z '(2) '(3 5)) (// (arr Z '(2) '(7 11)) 2)))   ; `//` floor division, stays z
 (= R (atype (/ (arr Z '(2) '(7 11)) 2)))                     ; `/` promotes (7/2 inexact) -> r
 (aall (= (arr R '(2) '(3.5 5.5)) (/ (arr Z '(2) '(7 11)) 2)))
 (aall (= (arr Z '(2) '(4 6)) (/ (arr Z '(2) '(8 12)) 2)))   ; `/` stays z when every element divides evenly
 (aall (= (arr Z '(2) '(1 1)) (% (arr Z '(2) '(7 11)) 2)))
 (aall (= (arr Z '(3) '(2 4 6)) (+ 1 (arr Z '(3) '(1 3 5)))))  ; scalar on the left

 ; --- array (op) array, same shape ---
 (aall (= (arr Z '(3) '(11 22 33))
          (+ (arr Z '(3) '(10 20 30)) (arr Z '(3) '(1 2 3)))))
 (aall (= (arr Z '(3) '(9 18 27))
          (- (arr Z '(3) '(10 20 30)) (arr Z '(3) '(1 2 3)))))

 ; --- numpy broadcasting: outer sum of a column and a row ---
 (aall (= (arr Z '(3 3) '(11 21 31 12 22 32 13 23 33))
          (+ (arr Z '(3 1) '(1 2 3)) (arr Z '(1 3) '(10 20 30)))))
 ; size-1 axis stretches
 (aall (= (arr Z '(2 2) '(11 21 12 22))
          (+ (arr Z '(2 2) '(1 1 2 2)) (arr Z '(1 2) '(10 20)))))

 ; --- mixed element-type promotes to the widest ---
 (= R (atype (+ (arr Z '(2) 0) 1.5)))            ; z array + r scalar -> r
 (aall (= (arr R '(2) '(1.5 1.5)) (+ (arr Z '(2) 0) 1.5)))
 (= Z (atype (+ (arr Z '(2) 0) (arr Z '(2) 0))))  ; z + z -> z
 (= Z (atype (+ (arr Z '(2) 0) 1)))                ; scalar int never widens the array

 ; --- comparison -> 0/1 bool array ---
 (aall (< (arr Z '(3) '(1 2 3)) 10))
 !(aall (< (arr Z '(3) '(1 2 30)) 10))
 (sat (< (arr Z '(3) '(1 20 30)) 10))
 !(sat (< (arr Z '(3) '(10 20 30)) 5))
 (aall (= (arr Z '(3) '(1 0 1)) (< (arr Z '(3) '(1 5 2)) 3)))
 (= Z (atype (< (arr Z '(3) 0) 1)))               ; bool array is z
 ; whole-array equality is (aall (= a b))
 (aall (= (arr Z '(2) '(5 6)) (arr Z '(2) '(5 6))))
 !(aall (= (arr Z '(2) '(5 6)) (arr Z '(2) '(5 7))))

 ; --- reductions ---
 (= 60 (asum (arr Z '(3) '(10 20 30))))
 (= 6000 (aprod (arr Z '(3) '(10 20 30))))
 (= 30 (amax (arr Z '(3) '(10 30 20))))
 (= 10 (amin (arr Z '(3) '(20 10 30))))
 (= 6.0 (asum (arr R '(3) '(1.0 2.0 3.0))))
 (= 21 (asum (arr Z '(2 3) '(1 2 3 4 5 6))))    ; reduces over all axes
 (aall (arr Z '(3) '(1 2 3)))                   ; no zero element
 !(aall (arr Z '(3) '(1 0 3)))               ; a zero element
 (sat (arr Z '(3) '(0 0 3)))
 !(sat (arr Z '(3) 0))                         ; all zero

 ; --- reductions are the identity on a scalar (rank-agnostic idiom) ---
 (= 5 (asum 5))
 (= 5 (amax 5))
 (= 1 (aall 1))
 (= 0 (aall 0))
 (aall (< 1 2))                                    ; scalar: (< 1 2) = 1, (aall 1) = 1
 !(aall (< 2 1))
 (aall (< (arr Z '(2) '(1 2)) (arr Z '(2) '(3 4))))  ; array: same expression

 ; --- truthiness is the NET: a value is false iff its element sum nets <= 0 ---
 (nilp (arr Z '(3) 0))                  ; zero array -> false
 (nilp (arr R '(2 2) 0))                ; zero float array -> false
 (nilp (arr Z '(0) 0))                  ; empty array -> vacuously false
 (nilp 0.0)                             ; boxed 0.0 -> false (was a truthy wart)
 !(nilp 2.5)                         ; positive float -> true
 (nilp -5)                           ; a negative real is FALSE (<= 0)
 !(nilp (+ (arr Z '(2) 0) 1))        ; positive array -> true
 (nilp @(-3 -4))                     ; a NEGATIVE array is false too -- the sign law at rank 1
 (nilp @(-2 1)) !(nilp @(-2 3))      ; the elements SUM: -2+1 <= 0 < -2+3
 (= 1 (? (arr Z '(3) 0) 0 1))         ; zero array takes the false arm
 (= 0 (? (+ (arr Z '(3) 0) 1) 0 1))    ; positive array takes the true arm
 ; a positive net makes the array truthy, per the tower:
 !(nilp @(0 0 5))                    ; one positive element -> true
 (nilp @(0.0 0.0))                      ; all-zero float tuple -> false
 (nilp ~(0 0))                         ; complex 0+0i -> false
 !(nilp ~(0 1))                     ; 0+1i sorts above 0 -> true
 !(nilp i)                           ; the imaginary unit is truthy

 ; --- elementwise transcendentals over an array ---
 (aall (= (arr R '(2) '(2.0 3.0)) ((/ 1 2) (arr R '(2) '(4.0 9.0)))))
 (= R (atype ((/ 1 2) (arr Z '(3) 0))))  ; result is a float array

 ; --- print as constructor forms ---
 ; rank-1 -> the @(…) sugar (@ reader splices into (tuple …)); rank>=2 ->
 ; (array '(shape) elem …) -- always a surface form, the type re-inferred
 (= "@(10 20 30)" (show (arr Z '(3) '(10 20 30))))
 (= "(array '(2 2) 1 2 3 4)" (show (arr Z '(2 2) '(1 2 3 4))))
 (= "@(1.5 2.5)" (show (arr R '(2) '(1.5 2.5))))
 (= "@(1 2 3)" (show (arr Z '(3) '(1 2 3))))   ; z aliases the word-int kind -> terse @
 ; @(…) reads back to an equal array; the explicit form is a plain constructor call
 (aall (= (arr Z '(3) '(10 20 30)) @(10 20 30)))
 (aall (= (arr R '(2) '(1.5 2.5)) @(1.5 2.5)))
 (aall (= (arr Z '(2 2) '(1 2 3 4)) (arr Z '(2 2) '(1 2 3 4))))
 ; the printed form reads back to an equal array
 (aall (= (arr Z '(3) '(10 20 30)) (tuple 10 20 30)))
 (aall (= (arr Z '(2 2) '(1 2 3 4)) (arr Z '(2 2) '(1 2 3 4))))
 (aall (= (arr R '(2) '(1.5 2.5)) (tuple 1.5 2.5)))

 ; --- non-conforming / non-numeric -> nil ---
 (nilp (+ (arr Z '(3) 0) (arr Z '(4) 0)))   ; shapes [3] and [4] don't conform
 (nilp (+ (arr Z '(3) 0) "x"))              ; non-numeric operand
 (nilp (arr Z '(3) 0))                      ; (sanity) zero array is falsy
 (nilp (arr 99 '(3) 0)))                      ; bad type code -> nil

; --- empty arrays: the first stone of the APL buildout. a shape-(0) array
; prints the (array '(shape)) surface form (@ has no empty spelling and @0
; used to collide with the one-element zero array), broadcast keeps a
; 0-axis empty (a 1-axis takes the OTHER size including 0 -- max here once
; filled one element out of an empty operand), and empty reductions answer
; their monoid UNITS: the floor appears as the values of empty reductions.
(: e (arr Z '(0) 0)
 (assert
  ("(array '(0))" = (show e)) ('(0) = (ashape e)) (1 = (arank e)) (0 = (alen e))
  (0 = (asum e)) (1 = (aprod e)) (aall e)        ; the units: empty sum 0, empty product 1, empty conjunction true
  !e (0 = $e)                                    ; an empty nets nothing
  (0 = (alen (e + e))) (0 = (alen (e * 2))) (0 = (alen (1 + e)))
  (0 = (alen (e < 1))) (0 = (alen (e = e)))      ; compare masks stay empty
  (0 = (alen (e 2)))                             ; an empty exponent array applies empty
  (0 = (alen (sin e))) (0 = (alen (pow e 2)))    ; elementwise maps stay empty
  (0 = (alen ((arr Z '(1) '(5)) + e)))           ; a 1-axis broadcasts to 0, not 1
  (-1 = (peep e 0 -1))                           ; out of bounds -> the default
  ('(0 3) = (ashape ((arr R '(0 3) 0) + 1)))     ; rank-2 empties keep their shape
  (: rt (ev '(array '(0)))                       ; the printed form reads back
     (&& (0 = (alen rt)) ('(0) = (ashape rt)) (Z = (atype rt))))))
