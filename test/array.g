; step 5a: typed multi-rank arrays.
; - (arr type shape) zero-fills; (arrl type shape vals) fills row-major
; - get: fixnum index (rank 1), shape-list index (rank N), oob -> default
; - arank / alen / ashape / atype accessors
; - elementwise + - * / over arrays + scalar broadcast + numpy broadcasting
; - mixed element-type promotes to the widest type
; - < <= > >= = elementwise -> 0/-1 bool array
; - reductions asum aprod amax amin aall aany; identity on scalars
; - vector falsiness: a vec is false iff every element is 0
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
 (nilp (arank 5))                     ; non-vec -> nil
 (nilp (atype "x"))

 ; --- get: rank-1 fixnum index ---
 (= 10 (get -1 0 (arrl i64 '(3) '(10 20 30))))
 (= 20 (get -1 1 (arrl i64 '(3) '(10 20 30))))
 (= 30 (get -1 2 (arrl i64 '(3) '(10 20 30))))
 (= -1 (get -1 3 (arrl i64 '(3) '(10 20 30))))   ; out of bounds -> default
 (= -1 (get -1 -1 (arrl i64 '(3) '(10 20 30))))  ; negative -> default

 ; --- get: rank-N shape-list index, row-major ---
 (= 1 (get -1 '(0 0) (arrl i64 '(2 2) '(1 2 3 4))))
 (= 2 (get -1 '(0 1) (arrl i64 '(2 2) '(1 2 3 4))))
 (= 3 (get -1 '(1 0) (arrl i64 '(2 2) '(1 2 3 4))))
 (= 4 (get -1 '(1 1) (arrl i64 '(2 2) '(1 2 3 4))))
 (= -1 (get -1 '(2 0) (arrl i64 '(2 2) '(1 2 3 4))))  ; oob -> default
 (= -1 (get -1 0 (arr i64 '(2 2))))                   ; wrong-rank key -> default
 (= -1 (get -1 '(0) (arr i64 '(2 2))))                ; too-few indices -> default

 ; --- rank-0 deref: empty/nil key yields the lone scalar ---
 (= 2.5 (get -9 '() 2.5))

 ; --- float element read boxes an f64 ---
 (= 1.5 (get -1 0 (arrl f64 '(2) '(1.5 2.5))))
 (flop (get -1 0 (arrl f64 '(2) '(1.5 2.5))))

 ; --- scalar broadcast: array (op) scalar ---
 (aall (= (arrl i64 '(3) '(11 21 31)) (+ (arrl i64 '(3) '(10 20 30)) 1)))
 (aall (= (arrl i64 '(3) '(9 19 29)) (- (arrl i64 '(3) '(10 20 30)) 1)))
 (aall (= (arrl i64 '(2) '(4 6)) (* (arrl i64 '(2) '(2 3)) 2)))
 (aall (= (arrl i64 '(2) '(3 5)) (/ (arrl i64 '(2) '(7 11)) 2)))   ; integer division
 (aall (= (arrl i64 '(2) '(1 1)) (% (arrl i64 '(2) '(7 11)) 2)))
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

 ; --- comparison -> 0/-1 bool array ---
 (aall (< (arrl i64 '(3) '(1 2 3)) 10))
 (~ (aall (< (arrl i64 '(3) '(1 2 30)) 10)))
 (aany (< (arrl i64 '(3) '(1 20 30)) 10))
 (~ (aany (< (arrl i64 '(3) '(10 20 30)) 5)))
 (aall (= (arrl i8 '(3) '(-1 0 -1)) (< (arrl i64 '(3) '(1 5 2)) 3)))
 (= i8 (atype (< (arr i64 '(3)) 1)))               ; bool array is i8
 ; whole-array equality is (aall (= a b))
 (aall (= (arrl i64 '(2) '(5 6)) (arrl i64 '(2) '(5 6))))
 (~ (aall (= (arrl i64 '(2) '(5 6)) (arrl i64 '(2) '(5 7)))))

 ; --- reductions ---
 (= 60 (asum (arrl i64 '(3) '(10 20 30))))
 (= 6000 (aprod (arrl i64 '(3) '(10 20 30))))
 (= 30 (amax (arrl i64 '(3) '(10 30 20))))
 (= 10 (amin (arrl i64 '(3) '(20 10 30))))
 (= 6.0 (asum (arrl f64 '(3) '(1.0 2.0 3.0))))
 (= 21 (asum (arrl i64 '(2 3) '(1 2 3 4 5 6))))    ; reduces over all axes
 (aall (arrl i64 '(3) '(1 2 3)))                   ; no zero element
 (~ (aall (arrl i64 '(3) '(1 0 3))))               ; a zero element
 (aany (arrl i64 '(3) '(0 0 3)))
 (~ (aany (arr i64 '(3))))                         ; all zero

 ; --- reductions are the identity on a scalar (rank-agnostic idiom) ---
 (= 5 (asum 5))
 (= 5 (amax 5))
 (= -1 (aall -1))
 (= 0 (aall 0))
 (aall (< 1 2))                                    ; scalar: (< 1 2) = -1, (aall -1) = -1
 (~ (aall (< 2 1)))
 (aall (< (arrl i64 '(2) '(1 2)) (arrl i64 '(2) '(3 4))))  ; array: same expression

 ; --- vector falsiness: a vec is false iff every element is 0 ---
 (nilp (arr i64 '(3)))                  ; zero array -> false
 (nilp (arr f64 '(2 2)))                ; zero float array -> false
 (nilp (arr i64 '(0)))                  ; empty array -> vacuously false
 (nilp 0.0)                             ; boxed 0.0 -> false (was a truthy wart)
 (~ (nilp 2.5))                         ; nonzero float -> true
 (~ (nilp -5))                          ; negatives are true
 (~ (nilp (+ (arr i64 '(2)) 1)))        ; nonzero array -> true
 (= -1 (? (arr i64 '(3)) 0 -1))         ; zero array takes the false arm
 (= 0 (? (+ (arr i64 '(3)) 1) 0 -1))    ; nonzero array takes the true arm

 ; --- elementwise transcendentals over an array ---
 (aall (= (arrl f64 '(2) '(2.0 3.0)) (sqrt (arrl f64 '(2) '(4.0 9.0)))))
 (= f64 (atype (sqrt (arr i64 '(3)))))  ; result is a float array

 ; --- print as `,`-prefixed constructor forms ---
 ; rank-1 i64/f64 -> ,(vec …); other rank/type -> ,(arrl <type> '(shape) '(vals))
 (= ",(vec 10 20 30)" (inspect (arrl i64 '(3) '(10 20 30))))
 (= ",(arrl i64 '(2 2) '(1 2 3 4))" (inspect (arrl i64 '(2 2) '(1 2 3 4))))
 (= ",(vec 1.5 2.5)" (inspect (arrl f64 '(2) '(1.5 2.5))))
 (= ",(arrl i8 '(3) '(1 2 3))" (inspect (arrl i8 '(3) '(1 2 3))))
 ; the printed form reads back to an equal array (`,` = uq = identity)
 (aall (= (arrl i64 '(3) '(10 20 30)) (vec 10 20 30)))
 (aall (= (arrl i64 '(2 2) '(1 2 3 4)) (arrl i64 '(2 2) '(1 2 3 4))))
 (aall (= (arrl f64 '(2) '(1.5 2.5)) (vec 1.5 2.5)))

 ; --- non-conforming / non-numeric -> nil ---
 (nilp (+ (arr i64 '(3)) (arr i64 '(4))))   ; shapes [3] and [4] don't conform
 (nilp (+ (arr i64 '(3)) "x"))              ; non-numeric operand
 (nilp (arr i64 '(3)))                      ; (sanity) zero array is falsy
 (nilp (arr 99 '(3))))                      ; bad type code -> nil
