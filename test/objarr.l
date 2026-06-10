; object arrays (type code `o` = g_O): rank-N containers of live ll *values*.
; the numeric tuple types (z..r) fold to a flat word/float payload the GC moves
; by memcpy; an o-array instead holds tagged words, so it can carry bignums,
; strings, symbols and nested arrays -- and is the one tuple type the collector
; traces element-by-element. rank-0 is rejected (a boxed scalar is just a value).

(: (oa-list n acc) (? (< n 1) acc (oa-list (- n 1) (X n acc)))   ; build (1 .. n)
   (oa-churn n)    (? (< n 1) 0 (: g (oa-list 300) (oa-churn (- n 1)))) ; alloc + discard
   oa-B     (100 2)                          ; a bignum (past fixnum/box range)
   oa-vals  (L oa-B (* oa-B oa-B) (+ oa-B 7) "hi" 'sym)
   oa-a     (arr o '(5) oa-vals)
   oa-z     (arr o '(3) 0)                         ; nil-filled
   oa-nest  (arr o '(2) (L (arr o '(2) '(1 2)) (arr o '(2) '(3 4)))))

(assert
 ; --- construction / accessors ---
 (= 3 o)   (= o (atype oa-a))                    ; type code 3
 (= 1 (arank oa-a))   (= 5 (alen oa-a))
 (= 5 (A (ashape oa-a)))
 (nilp (arr o 0 0))                                ; rank-0 object rejected
 (nilp (arr o 0 '(1)))
 (nilp (arr o '(2 2 2 2 2 2 2 2 2) 0))             ; over-rank rejected

 ; --- holds arbitrary values verbatim (no boxing/coercion) ---
 (= oa-B (peek oa-a 0 0))
 (= (* oa-B oa-B) (peek oa-a 1 0))
 (= (+ oa-B 7) (peek oa-a 2 0))
 (= "hi" (peek oa-a 3 0))
 (= 'sym (peek oa-a 4 0))
 (nilp (peek oa-z 0 0))                           ; (arr o ... 0) fills with nil

 ; --- nested object arrays + index into the inner one ---
 (= 4 (peek (peek oa-nest 1 0) 1 0))

 ; --- falsiness: an all-nil o-array is falsy; any truthy element flips it ---
 (? oa-z 0 1)                                    ; oa-z all nil -> falsy -> 1
 (? oa-a 1 0)                                     ; oa-a has truthy elems -> 1

 ; --- print: an object array prints as the @(…)/(array …) surface form like any
 ;     other; the type is re-INFERRED on read-back, so an o array of plain
 ;     numbers re-reads at its natural tier (z) -- inferred, not pinned ---
 (= "@(10 20 30)" (show (arr o '(3) '(10 20 30))))

 ; --- GC stress: oa-a stays live (global root) across many collections; the
 ;     bignum element pointers must be forwarded, not dropped or truncated ---
 (= 0 (oa-churn 80))
 (= oa-B (peek oa-a 0 0))
 (= (* oa-B oa-B) (peek oa-a 1 0))
 (= 'sym (peek oa-a 4 0)))

; --- elementwise arithmetic: transparent bignums, full broadcasting ----------
; the whole point of g_O: ops route through the promoting scalar dispatch, so a
; bignum array adds/multiplies EXACTLY where an z array would wrap.
(: oa-x   (arr o '(3) (L (100 2) 2 3))
   oa-y   (arr o '(3) (L 1 (100 2) 4))
   oa-sum (+ oa-x oa-y)
   oa-prd (* oa-x oa-y)
   oa-w   (40 2)                              ; 2^40 fits z; 2^40 * 2^40 = 2^80 overflows it
   oa-zar (arr z '(2) (L oa-w oa-w))          ; typed int array -> wraps
   oa-oar (arr o   '(2) (L oa-w oa-w)))         ; object array   -> exact

(assert
 ; result of an op on a g_O array is itself g_O
 (= o (atype oa-sum))
 ; exact elementwise results (no wrap, no float rounding)
 (= (+ (100 2) 1) (peek oa-sum 0 0))
 (= (* 2 (100 2)) (peek oa-prd 1 0))
 (= 12 (peek oa-prd 2 0))

 ; transparency vs the typed lane: 2^40*2^40 = 2^80; z wraps to 0, o stays exact
 (= (80 2) (peek (* oa-oar oa-oar) 0 0))
 (nilp (= (80 2) (peek (* oa-zar oa-zar) 0 0)))

 ; broadcasting: object array (+) scalar bignum
 (= (* 2 (100 2)) (peek (+ oa-x (100 2)) 0 0))   ; (2^100)+(2^100)
 (= (+ 3 (100 2)) (peek (+ (100 2) oa-x) 2 0))   ; scalar on the left; oa-x elem 2 = 3

 ; mixed: object array (+) typed int array -> widens the int array, stays exact
 (= (* 2 oa-w) (peek (+ oa-oar oa-zar) 0 0))

 ; comparison over object arrays -> 0/1 element
 (= 1 (peek (< (arr o '(2) '(1 5)) (arr o '(2) '(3 2))) 0 0))
 (= 0 (peek (< (arr o '(2) '(1 5)) (arr o '(2) '(3 2))) 1 0))

 ; --- reductions fold exactly through the same dispatch ---
 (= (+ (100 2) 5) (asum oa-x))
 (= (* 6 (100 2)) (aprod oa-x))
 (= (100 2) (amax (arr o '(3) (L 5 (100 2) 7))))
 (= -3 (amin (arr o '(3) (L 5 -3 7))))
 (aall (arr o '(2) '(1 2)))
 (nilp (aall (arr o '(2) '(1 0))))
 (sat (arr o '(2) '(0 5)))
 (nilp (sat (arr o '(2) '(0 0))))

 ; --- arithmetic under GC pressure: bignum products survive collection ---
 (= 0 (oa-churn 40))
 (= (* 2 (80 2)) (asum (* oa-oar oa-oar))))    ; [2^80 2^80] summed = 2^81

; --- the `array` constructor: ergonomic front-end over arr/arr --------------
; no type code (inferred as the highest of z<r<o present), shape may be a
; number (rank-1 of length |n|) or a list, and the elements are trailing args
; (the shape fixes the count, so it curries them one at a time). bignum/complex/
; non-number data lifts the whole array to o automatically -> exact, never lossy.
(: oa-q (array 2 'hello 'world)                  ; symbols -> object array
   oa-bn (array 2 (100 2) 5)                  ; bignum -> o, stored exactly
   oa-m  (array (L 2 2) 1 2 3 4))                ; rank-2 from a shape list
(assert
 ; type inference: pure ints -> z, any float -> r, anything past the real
 ; 64-bit tower (bignum/symbol/...) -> o
 (= z (atype (array 3 1 2 3)))
 (= r (atype (array 3 1 2.0 3)))
 (= o   (atype oa-q))
 (= o   (atype oa-bn))
 ; numeric shape -> rank-1 vector of length ($ n); a non-positive shape is empty
 (= 1 (arank (array 4 1 2 3 4)))
 (= 0 (alen (array -3))) (= "@0" (show (array -3)))
 ; shape list -> rank-N
 (= 2 (arank oa-m))   (= 4 (peek oa-m (L 1 1) 0))
 ; elements stored verbatim, in order
 (= 'world (peek oa-q 1 0))
 (= (100 2) (peek oa-bn 0 0))                  ; full bignum, not truncated to z
 ; currying: a partial collector is a function; completing it builds the array
 (= "@('a 'b)" (show ((array 2) 'a 'b)))
 ; (array 0) -> empty rank-1 array, no elements to collect
 (= "@0" (show (array 0)))
 ; round-trips: numeric array result prints as the terse @(…) sugar
 (= "@(1 2 3)" (show (array 3 1 2 3)))
 ; saturating shape coercion: a float / complex / vector dimension -> ($ d)
 (= 3 (alen (array 2.9 7 8 9)))                   ; ($ 2.9) = 3 : rank-1 length 3
 (= 5 (alen (array ~(3 4) 0 0 0 0 0)))           ; ($ ~(3 4)) = 5
 (= 8 (alen (array (L 2.0 3.5) 1 2 3 4 5 6 7 8)))  ; dims (2 4) -> 8 elems
 ; @ reader macro: @(e …) is sugar for a rank-1 array, type inferred
 (= o (atype @((100 2) 1)))                    ; bignum element -> object array
 (aall (= @(1 2 3) (array 3 1 2 3))))

; --- pin / truthiness: (nilp x) == (= 0 (pin x)) holds across tuple types, via
; g_len recursing into each element's own magnitude (so an all-zero array is pin 0,
; not the garbage that a raw word-bits L2 norm would give). A bignum element forces
; an o array; a complex element packs into a c array (both keep the invariant).
(: oa-z2 (array 2 ~(0 0) ~(0 0))               ; two zero complexes -> packed c array
   oa-c2 (array 2 ~(0 0) ~(3 4))               ; |0|²+|3+4i|² = 25 -> ceil 5
   oa-b2 (array 2 (100 2) 0))                 ; bignum element saturates pin, forces o
(assert
 (= c (atype oa-z2)) (= c (atype oa-c2)) (= o (atype oa-b2))
 (= 0 (sat oa-z2)) (nilp oa-z2)                   ; all-zero object array -> falsy, pin 0
 (= 5 (sat oa-c2)) !!oa-c2                         ; one nonzero element -> truthy, ceil(5)
 !!oa-b2                                          ; a bignum element is truthy
 (= 0 (sat (arr o '(2 2) 0)))                       ; all-nil object array -> pin 0
 !!(array 2 'a 'b)                                ; symbol elements -> truthy
 ; the defining invariant (nilp x) == (= 0 (pin x)) on each:
 (= (? (nilp oa-z2) 1 0) (? (= 0 (sat oa-z2)) 1 0))
 (= (? (nilp oa-c2) 1 0) (? (= 0 (sat oa-c2)) 1 0))
 (= (? (nilp oa-b2) 1 0) (? (= 0 (sat oa-b2)) 1 0)))
