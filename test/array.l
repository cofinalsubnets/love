; step 5a: typed multi-rank arrays.
; - (arr type shape) zero-fills; (arrl type shape vals) fills row-major
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
 (= 2 (arank (arr i64 '(2 3))))
 (= 0 (arank (arr i64 '())))          ; empty shape -> rank-0 scalar
 (= 6 (alen (arr i64 '(2 3))))
 (= 1 (alen (arr f64 '())))           ; rank-0 has one element
 (= i64 (atype (arr i64 '(2 3))))
 (= f32 (atype (arr f32 '(4))))
 (= '(2 3) (ashape (arr i64 '(2 3))))
 (= 0 (ashape (arr i64 '())))         ; rank-0 shape is the empty list (nil)
 (nilp (arank 5))                     ; non-tuple -> nil
 (nilp (atype "x"))

 ; --- get: rank-1 fixnum index ---
 (= 10 (peek (arrl i64 '(3) '(10 20 30)) 0 -1))
 (= 20 (peek (arrl i64 '(3) '(10 20 30)) 1 -1))
 (= 30 (peek (arrl i64 '(3) '(10 20 30)) 2 -1))
 (= -1 (peek (arrl i64 '(3) '(10 20 30)) 3 -1))   ; out of bounds -> default
 (= -1 (peek (arrl i64 '(3) '(10 20 30)) -1 -1))  ; negative -> default

 ; --- get: rank-N shape-list index, row-major ---
 (= 1 (peek (arrl i64 '(2 2) '(1 2 3 4)) '(0 0) -1))
 (= 2 (peek (arrl i64 '(2 2) '(1 2 3 4)) '(0 1) -1))
 (= 3 (peek (arrl i64 '(2 2) '(1 2 3 4)) '(1 0) -1))
 (= 4 (peek (arrl i64 '(2 2) '(1 2 3 4)) '(1 1) -1))
 (= -1 (peek (arrl i64 '(2 2) '(1 2 3 4)) '(2 0) -1))  ; oob -> default
 (= -1 (peek (arr i64 '(2 2)) 0 -1))                   ; wrong-rank key -> default
 (= -1 (peek (arr i64 '(2 2)) '(0) -1))                ; too-few indices -> default

 ; --- rank-0 deref: empty/nil key yields the lone scalar ---
 (= 2.5 (peek 2.5 '() -9))

 ; --- float element read boxes an f64 ---
 (= 1.5 (peek (arrl f64 '(2) '(1.5 2.5)) 0 -1))
 (flop (peek (arrl f64 '(2) '(1.5 2.5)) 0 -1))

 ; --- scalar broadcast: array (op) scalar ---
 (aall (= (arrl i64 '(3) '(11 21 31)) (+ (arrl i64 '(3) '(10 20 30)) 1)))
 (aall (= (arrl i64 '(3) '(9 19 29)) (- (arrl i64 '(3) '(10 20 30)) 1)))
 (aall (= (arrl i64 '(2) '(4 6)) (* (arrl i64 '(2) '(2 3)) 2)))
 (aall (= (arrl i64 '(2) '(3 5)) (// (arrl i64 '(2) '(7 11)) 2)))   ; `//` floor division, stays i64
 (= f64 (atype (/ (arrl i64 '(2) '(7 11)) 2)))                     ; `/` promotes (7/2 inexact) -> f64
 (aall (= (arrl f64 '(2) '(3.5 5.5)) (/ (arrl i64 '(2) '(7 11)) 2)))
 (aall (= (arrl i64 '(2) '(4 6)) (/ (arrl i64 '(2) '(8 12)) 2)))   ; `/` stays i64 when every element divides evenly
 (aall (= (arrl i64 '(2) '(1 1)) (mod (arrl i64 '(2) '(7 11)) 2)))
 (aall (= (arrl i64 '(3) '(2 4 6)) (+ 1 (arrl i64 '(3) '(1 3 5)))))  ; scalar on the left

 ; --- array (op) array, same shape ---
 (aall (= (arrl i64 '(3) '(11 22 33))
          (+ (arrl i64 '(3) '(10 20 30)) (arrl i64 '(3) '(1 2 3)))))
 (aall (= (arrl i64 '(3) '(9 18 27))
          (- (arrl i64 '(3) '(10 20 30)) (arrl i64 '(3) '(1 2 3)))))

 ; --- numpy broadcasting: outer sum of a column and a row ---
 (aall (= (arrl i64 '(3 3) '(11 21 31 12 22 32 13 23 33))
          (+ (arrl i64 '(3 1) '(1 2 3)) (arrl i64 '(1 3) '(10 20 30)))))
 ; size-1 axis stretches
 (aall (= (arrl i64 '(2 2) '(11 21 12 22))
          (+ (arrl i64 '(2 2) '(1 1 2 2)) (arrl i64 '(1 2) '(10 20)))))

 ; --- mixed element-type promotes to the widest ---
 (= f64 (atype (+ (arr i32 '(2)) 1.5)))            ; i32 array + f64 scalar -> f64
 (aall (= (arrl f64 '(2) '(1.5 1.5)) (+ (arr i32 '(2)) 1.5)))
 (= i32 (atype (+ (arr i8 '(2)) (arr i32 '(2)))))  ; i8 + i32 -> i32
 (= i8 (atype (+ (arr i8 '(2)) 1)))                ; scalar int never widens the array

 ; --- comparison -> 0/1 bool array ---
 (aall (< (arrl i64 '(3) '(1 2 3)) 10))
 !(aall (< (arrl i64 '(3) '(1 2 30)) 10))
 (hash (< (arrl i64 '(3) '(1 20 30)) 10))
 !(hash (< (arrl i64 '(3) '(10 20 30)) 5))
 (aall (= (arrl i8 '(3) '(1 0 1)) (< (arrl i64 '(3) '(1 5 2)) 3)))
 (= i8 (atype (< (arr i64 '(3)) 1)))               ; bool array is i8
 ; whole-array equality is (aall (= a b))
 (aall (= (arrl i64 '(2) '(5 6)) (arrl i64 '(2) '(5 6))))
 !(aall (= (arrl i64 '(2) '(5 6)) (arrl i64 '(2) '(5 7))))

 ; --- reductions ---
 (= 60 (asum (arrl i64 '(3) '(10 20 30))))
 (= 6000 (aprod (arrl i64 '(3) '(10 20 30))))
 (= 30 (amax (arrl i64 '(3) '(10 30 20))))
 (= 10 (amin (arrl i64 '(3) '(20 10 30))))
 (= 6.0 (asum (arrl f64 '(3) '(1.0 2.0 3.0))))
 (= 21 (asum (arrl i64 '(2 3) '(1 2 3 4 5 6))))    ; reduces over all axes
 (aall (arrl i64 '(3) '(1 2 3)))                   ; no zero element
 !(aall (arrl i64 '(3) '(1 0 3)))               ; a zero element
 (hash (arrl i64 '(3) '(0 0 3)))
 !(hash (arr i64 '(3)))                         ; all zero

 ; --- reductions are the identity on a scalar (rank-agnostic idiom) ---
 (= 5 (asum 5))
 (= 5 (amax 5))
 (= 1 (aall 1))
 (= 0 (aall 0))
 (aall (< 1 2))                                    ; scalar: (< 1 2) = 1, (aall 1) = 1
 !(aall (< 2 1))
 (aall (< (arrl i64 '(2) '(1 2)) (arrl i64 '(2) '(3 4))))  ; array: same expression

 ; --- truthiness is zero-magnitude (L2 norm): a value is false iff |x| == 0 ---
 (nilp (arr i64 '(3)))                  ; zero array -> false
 (nilp (arr f64 '(2 2)))                ; zero float array -> false
 (nilp (arr i64 '(0)))                  ; empty array -> vacuously false
 (nilp 0.0)                             ; boxed 0.0 -> false (was a truthy wart)
 !(nilp 2.5)                         ; positive float -> true
 (nilp -5)                           ; a negative real is now FALSE (<= 0)
 !(nilp (+ (arr i64 '(2)) 1))        ; nonzero array -> true
 !(nilp @(-3 -4))                    ; a NEGATIVE array stays true (norm, sign squares away)
 (= 1 (? (arr i64 '(3)) 0 1))         ; zero array takes the false arm
 (= 0 (? (+ (arr i64 '(3)) 1) 0 1))    ; nonzero array takes the true arm
 ; a single non-zero component makes the norm non-zero (truthy), per the tower:
 !(nilp @(0 0 5))                    ; one non-zero element -> true
 (nilp @(0.0 0.0))                      ; all-zero float tuple -> false
 (nilp ~(0 0))                         ; complex 0+0i (|z|=0) -> false
 !(nilp ~(0 1))                     ; 0+1i (|z|=1) -> true
 !(nilp i)                           ; the imaginary unit is truthy

 ; --- elementwise transcendentals over an array ---
 (aall (= (arrl f64 '(2) '(2.0 3.0)) ((/ 1 2) (arrl f64 '(2) '(4.0 9.0)))))
 (= f64 (atype ((/ 1 2) (arr i64 '(3)))))  ; result is a float array

 ; --- print as constructor forms ---
 ; rank-1 numeric -> the @(…) sugar (@ reader splices into (tuple …)); rank>=2 ->
 ; an explicit (arrl <type> '(shape) '(vals)) call
 (= "@(10 20 30)" (inspect (arrl i64 '(3) '(10 20 30))))
 (= "(arrl i64 '(2 2) '(1 2 3 4))" (inspect (arrl i64 '(2 2) '(1 2 3 4))))
 (= "@(1.5 2.5)" (inspect (arrl f64 '(2) '(1.5 2.5))))
 (= "@(1 2 3)" (inspect (arrl i8 '(3) '(1 2 3))))   ; i8 aliases the word-int kind -> terse @
 ; @(…) reads back to an equal array; the explicit form is a plain constructor call
 (aall (= (arrl i64 '(3) '(10 20 30)) @(10 20 30)))
 (aall (= (arrl f64 '(2) '(1.5 2.5)) @(1.5 2.5)))
 (aall (= (arrl i64 '(2 2) '(1 2 3 4)) (arrl i64 '(2 2) '(1 2 3 4))))
 ; the printed form reads back to an equal array
 (aall (= (arrl i64 '(3) '(10 20 30)) (tuple 10 20 30)))
 (aall (= (arrl i64 '(2 2) '(1 2 3 4)) (arrl i64 '(2 2) '(1 2 3 4))))
 (aall (= (arrl f64 '(2) '(1.5 2.5)) (tuple 1.5 2.5)))

 ; --- non-conforming / non-numeric -> nil ---
 (nilp (+ (arr i64 '(3)) (arr i64 '(4))))   ; shapes [3] and [4] don't conform
 (nilp (+ (arr i64 '(3)) "x"))              ; non-numeric operand
 (nilp (arr i64 '(3)))                      ; (sanity) zero array is falsy
 (nilp (arr 99 '(3))))                      ; bad type code -> nil
