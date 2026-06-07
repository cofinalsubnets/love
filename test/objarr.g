; object arrays (type code `o` = g_O): rank-N containers of live gwen *values*.
; the numeric tuple types (i8..f64) fold to a flat word/float payload the GC moves
; by memcpy; an o-array instead holds tagged words, so it can carry bignums,
; strings, symbols and nested arrays -- and is the one tuple type the collector
; traces element-by-element. rank-0 is rejected (a boxed scalar is just a value).

(: (oa-list n acc) (? (< n 1) acc (oa-list (- n 1) (X n acc)))   ; build (1 .. n)
   (oa-churn n)    (? (< n 1) 0 (: g (oa-list 300) (oa-churn (- n 1)))) ; alloc + discard
   oa-B     (** 2 100)                          ; a bignum (past fixnum/box range)
   oa-vals  (L oa-B (* oa-B oa-B) (+ oa-B 7) "hi" 'sym)
   oa-a     (arrl o '(5) oa-vals)
   oa-z     (arr o '(3))                         ; nil-filled
   oa-nest  (arrl o '(2) (L (arrl o '(2) '(1 2)) (arrl o '(2) '(3 4)))))

(assert
 ; --- construction / accessors ---
 (= 3 o)   (= o (atype oa-a))                    ; type code 3
 (= 1 (arank oa-a))   (= 5 (alen oa-a))
 (= 5 (A (ashape oa-a)))
 (nilp (arr o '()))                              ; rank-0 object rejected
 (nilp (arrl o '() '(1)))
 (nilp (arr o '(2 2 2 2 2 2 2 2 2)))             ; over-rank rejected

 ; --- holds arbitrary values verbatim (no boxing/coercion) ---
 (= oa-B (get 0 0 oa-a))
 (= (* oa-B oa-B) (get 0 1 oa-a))
 (= (+ oa-B 7) (get 0 2 oa-a))
 (= "hi" (get 0 3 oa-a))
 (= 'sym (get 0 4 oa-a))
 (nilp (get 0 0 oa-z))                           ; (arr o ...) fills with nil

 ; --- nested object arrays + index into the inner one ---
 (= 4 (get 0 1 (get 0 1 oa-nest)))

 ; --- falsiness: an all-nil o-array is falsy; any truthy element flips it ---
 (? oa-z 0 1)                                    ; oa-z all nil -> falsy -> 1
 (? oa-a 1 0)                                     ; oa-a has truthy elems -> 1

 ; --- print round-trip: an object array prints as a bare (arrl o …) call whose
 ;     shape/vals are quoted, so it re-evaluates to an equal array ---
 (= "(arrl o '(3) '(10 20 30))" (inspect (arrl o '(3) '(10 20 30))))

 ; --- GC stress: oa-a stays live (global root) across many collections; the
 ;     bignum element pointers must be forwarded, not dropped or truncated ---
 (= 0 (oa-churn 80))
 (= oa-B (get 0 0 oa-a))
 (= (* oa-B oa-B) (get 0 1 oa-a))
 (= 'sym (get 0 4 oa-a)))

; --- elementwise arithmetic: transparent bignums, full broadcasting ----------
; the whole point of g_O: ops route through the promoting scalar dispatch, so a
; bignum array adds/multiplies EXACTLY where an i64 array would wrap.
(: oa-x   (arrl o '(3) (L (** 2 100) 2 3))
   oa-y   (arrl o '(3) (L 1 (** 2 100) 4))
   oa-sum (+ oa-x oa-y)
   oa-prd (* oa-x oa-y)
   oa-w   (** 2 40)                              ; 2^40 fits i64; 2^40 * 2^40 = 2^80 overflows it
   oa-zar (arrl i64 '(2) (L oa-w oa-w))          ; typed int array -> wraps
   oa-oar (arrl o   '(2) (L oa-w oa-w)))         ; object array   -> exact

(assert
 ; result of an op on a g_O array is itself g_O
 (= o (atype oa-sum))
 ; exact elementwise results (no wrap, no float rounding)
 (= (+ (** 2 100) 1) (get 0 0 oa-sum))
 (= (* 2 (** 2 100)) (get 0 1 oa-prd))
 (= 12 (get 0 2 oa-prd))

 ; transparency vs the typed lane: 2^40*2^40 = 2^80; i64 wraps to 0, o stays exact
 (= (** 2 80) (get 0 0 (* oa-oar oa-oar)))
 (nilp (= (** 2 80) (get 0 0 (* oa-zar oa-zar))))

 ; broadcasting: object array (+) scalar bignum
 (= (* 2 (** 2 100)) (get 0 0 (+ oa-x (** 2 100))))   ; (2^100)+(2^100)
 (= (+ 3 (** 2 100)) (get 0 2 (+ (** 2 100) oa-x)))   ; scalar on the left; oa-x elem 2 = 3

 ; mixed: object array (+) typed int array -> widens the int array, stays exact
 (= (* 2 oa-w) (get 0 0 (+ oa-oar oa-zar)))

 ; comparison over object arrays -> 0/1 element
 (= 1 (get 0 0 (< (arrl o '(2) '(1 5)) (arrl o '(2) '(3 2)))))
 (= 0 (get 0 1 (< (arrl o '(2) '(1 5)) (arrl o '(2) '(3 2)))))

 ; --- reductions fold exactly through the same dispatch ---
 (= (+ (** 2 100) 5) (asum oa-x))
 (= (* 6 (** 2 100)) (aprod oa-x))
 (= (** 2 100) (amax (arrl o '(3) (L 5 (** 2 100) 7))))
 (= -3 (amin (arrl o '(3) (L 5 -3 7))))
 (aall (arrl o '(2) '(1 2)))
 (nilp (aall (arrl o '(2) '(1 0))))
 (aany (arrl o '(2) '(0 5)))
 (nilp (aany (arrl o '(2) '(0 0))))

 ; --- arithmetic under GC pressure: bignum products survive collection ---
 (= 0 (oa-churn 40))
 (= (* 2 (** 2 80)) (asum (* oa-oar oa-oar))))    ; [2^80 2^80] summed = 2^81

; --- the `array` constructor: ergonomic front-end over arr/arrl --------------
; no type code (inferred as the highest of i64<f64<o present), shape may be a
; number (rank-1 of length |n|) or a list, and the elements are trailing args
; (the shape fixes the count, so it curries them one at a time). bignum/complex/
; non-number data lifts the whole array to o automatically -> exact, never lossy.
(: oa-q (array 2 'hello 'world)                  ; symbols -> object array
   oa-bn (array 2 (** 2 100) 5)                  ; bignum -> o, stored exactly
   oa-m  (array (L 2 2) 1 2 3 4))                ; rank-2 from a shape list
(assert
 ; type inference: pure ints -> i64, any float -> f64, anything past the real
 ; 64-bit tower (bignum/symbol/...) -> o
 (= i64 (atype (array 3 1 2 3)))
 (= f64 (atype (array 3 1 2.0 3)))
 (= o   (atype oa-q))
 (= o   (atype oa-bn))
 ; numeric shape -> rank-1 vector of length |n| (negative shape uses |n|)
 (= 1 (arank (array 4 1 2 3 4)))
 (= 3 (alen (array -3 7 8 9)))
 ; shape list -> rank-N
 (= 2 (arank oa-m))   (= 4 (get 0 (L 1 1) oa-m))
 ; elements stored verbatim, in order
 (= 'world (get 0 1 oa-q))
 (= (** 2 100) (get 0 0 oa-bn))                  ; full bignum, not truncated to i64
 ; currying: a partial collector is a function; completing it builds the array
 (= "(arrl o '(2) '(a b))" (inspect ((array 2) 'a 'b)))
 ; (array 0) -> empty rank-1 array, no elements to collect
 (= "@0" (inspect (array 0)))
 ; round-trips: numeric array result prints as the terse @(…) sugar
 (= "@(1 2 3)" (inspect (array 3 1 2 3)))
 ; L2-norm shape coercion: a float / complex / vector dimension -> (int (abs d))
 (= 2 (alen (array 2.9 7 8)))                     ; |2.9| -> 2 : rank-1 length 2
 (= 5 (alen (array (C 3 4) 0 0 0 0 0)))           ; |(C 3 4)| = 5
 (= 6 (alen (array (L 2.0 3.5) 1 2 3 4 5 6)))     ; dims (2 3) -> 6 elems
 ; @ reader macro: @(e …) is sugar for a rank-1 array, type inferred
 (= o (atype @((** 2 100) 1)))                    ; bignum element -> object array
 (aall (= @(1 2 3) (array 3 1 2 3))))
