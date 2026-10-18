; object trays: rank-N containers of any values, traced cell by cell; one cell demotes to its value

(: (oa-list n acc) (n < 1 ? acc (oa-list (n - 1) (. n acc)))
   (oa-churn n)    (n < 1 ? 0 (oa-list 300 @ g (oa-churn (n - 1))))     ; alloc + discard
   oa-big     (100 2)                                                   ; a bignum
   oa-vals  [oa-big (oa-big * oa-big) (oa-big + 7) "hi" 'sym]
   oa-a     (top-tray '(5) oa-vals)
   oa-z     (top-tray '(3) 0)
   oa-nest  (top-tray '(2) [(top-tray '(2) '(1 2)) (top-tray '(2) '(3 4))]))

(test
 ; --- construction / accessors
 (top-tray = tier oa-a)
 (1 = rank oa-a)   (5 = tally oa-a)
 (5 = cap (shape oa-a))
 !(top-tray 0 0)                    ; rank-0 demotes to its lone cell -- nil-filled here
 (1 = top-tray 0 '(1))              ; ... or the value: a one-cell array is that value
 !(top-tray '(2 2 2 2 2 2 2 2 2) 0)

 ; --- holds arbitrary values verbatim
 (oa-big = peep oa-a 0 0)
 (oa-big * oa-big = peep oa-a 1 0)
 (oa-big + 7 = peep oa-a 2 0)
 ("hi" = peep oa-a 3 0)
 ('sym = peep oa-a 4 0)
 !(peep oa-z 0 0)

 ; --- nested object arrays
 (4 = peep (peep oa-nest 1 0) 1 0)

 ; --- falsiness: all-nil is falsy; any truthy element flips it
 (oa-z ? 0 1)
 (oa-a ? 1 0)

 ; --- print: the tier is inferred again on read-back
 ("@(10 20 30)" = show (top-tray '(3) '(10 20 30)))

 ; --- gc stress: the bignum cells are forwarded across collections ---
 (0 = oa-churn 80)
 (oa-big = peep oa-a 0 0)
 (oa-big * oa-big = peep oa-a 1 0)
 ('sym = peep oa-a 4 0))

; --- elementwise arithmetic through the promoting scalar ops: exact where an int tray wraps
(: oa-x   (top-tray '(3) [(100 2) 2 3])
   oa-y   (top-tray '(3) [1 (100 2) 4])
   oa-sum (oa-x + oa-y)
   oa-prd (oa-x * oa-y)
   oa-w   (40 2)                              ; 2^40 fits z; 2^40 * 2^40 = 2^80 overflows it
   oa-zar (star-tray '(2) [oa-w oa-w])
   oa-oar (top-tray   '(2) [oa-w oa-w]))

(test
 (top-tray = tier oa-sum)
 (((100 2) + 1) = peep oa-sum 0 0)
 ((2 * (100 2)) = peep oa-prd 1 0)
 (12 = peep oa-prd 2 0)

 ; 2^40*2^40 = 2^80: z wraps to 0, o stays exact
 ((80 2) = peep (oa-oar * oa-oar) 0 0)
 !((80 2) = peep (oa-zar * oa-zar) 0 0)

 ; broadcasting: object array (+) scalar bignum
 (2 * 100 2 = peep (oa-x + 100 2) 0 0)
 (3 + 100 2 = peep (100 2 + oa-x) 2 0)

 ; mixed: object array (+) typed int array -> widens the int array, stays exact
 (word ? ((2 * oa-w) = peep (oa-oar + oa-zar) 0 0) 1)   ; 2^40 wraps differently in a 32-bit z-array

 ; comparison answers a 0/1 element
 (1 = peep (top-tray '(2) '(1 5) < top-tray '(2) '(3 2)) 0 0)
 (0 = peep (top-tray '(2) '(1 5) < top-tray '(2) '(3 2)) 1 0)

 ; --- reductions fold exactly
 (100 2 + 5 = +oa-x)
 (6 * 100 2 = *oa-x)
 (100 2 = amax (top-tray '(3) [5 (100 2) 7]))
 (-3 = amin (top-tray '(3) [5 -3 7]))
 (aall (top-tray '(2) '(1 2)))
 !(aall (top-tray '(2) '(1 0)))
 $(top-tray '(2) '(0 5))
 !$(top-tray '(2) '(0 0))

 ; --- arithmetic under GC pressure
 (0 = oa-churn 40)
 (2 * 80 2 = +(oa-oar * oa-oar))     ; 2^81
 ; a numeric operand widens first, and may collect: the fresh object one beside it moves
 (@(1 2) + (top-tray '(2) '(10 20)) @ s (11 = peep s 0 0 && 22 = peep s 1 0))
 ((top-tray '(2) '(10 20)) + @(1 2) @ s (11 = peep s 0 0 && 22 = peep s 1 0)))

; --- `array`: the tier inferred, a number or list shape, the elements curried in after it ---
(: oa-q (array 2 'hello 'world)
   oa-bn (array 2 (100 2) 5)                  ; bignum -> o, stored exactly
   oa-m  (array [2 2] 1 2 3 4))
(test
 ; ints -> z, any float -> r, past the 64-bit tower -> o
 (star-tray = tier (array 3 1 2 3))
 (gem-tray = tier (array 3 1 2.0 3))
 (top-tray = tier oa-q)
 (top-tray = tier oa-bn)
 ; numeric shape -> rank-1 vector of length ($ n); a non-positive shape is empty
 (1 = rank (array 4 1 2 3 4))
 (0 = #(array -3)) ("@()" = show (array -3))
 (2 = rank oa-m)   (4 = peep oa-m [1 1] 0)
 ('world = peep oa-q 1 0)
 ((100 2) = peep oa-bn 0 0)                  ; full bignum, not truncated
 ; currying: a partial collector is a function; completing it builds the array
 ("@('a 'b)" = show (array 2 'a 'b))
 ; (array 0) -> empty rank-1 array, no elements to collect; it prints @()
 ("@()" = show (array 0))
 ; a numeric array result prints as @(..)
 ("@(1 2 3)" = show (array 3 1 2 3))
 ; saturating shape coercion: a float / complex / vector dimension -> ($ d)
 (3 = #(array 2.9 7 8 9))
 (3 = #(array (3 ~ 4) 0 0 0))             ; ($ (3 ~ 4)) = 3, the real part
 (8 = #(array [2.0 3.5] 1 2 3 4 5 6 7 8))
 ; @ reader macro: @(e …) is sugar for a rank-1 array, type inferred
 (top-tray = tier @((100 2) 1))
 (aall (@(1 2 3) = array 3 1 2 3)))

; --- the measure recurses into each element, so an all-zero tray nets 0 ---
(: oa-z2 (array 2 (0 ~ 0) (0 ~ 0))
   oa-c2 (array 2 (0 ~ 0) (3 ~ 4))               ; re 3 -> ceil 3
   oa-b2 (array 2 (100 2) 0))                 ; bignum element saturates pin, forces o
(test
 (twin-tray = tier oa-z2) (twin-tray = tier oa-c2) (top-tray = tier oa-b2)
 (0 = $oa-z2) !oa-z2
 (3 = $oa-c2) !!oa-c2
 !!oa-b2                       ; a bignum element is truthy
 (0 = $(top-tray '(2 2) 0))
 !!(array 2 'a 'b))

; --- `=` reads through a cell to its value, so the hash does too, never the pointers
(: oa-k1 @(("a" + "b") [1 2] 'sym)
   oa-k2 @(("a" + "b") [1 2] 'sym)
   oa-t (pin (pin {} oa-k1 1) oa-k2 2))
(test
 (aall (oa-k1 = oa-k2)) (dig oa-k1 = dig oa-k2)
 (2 = peep oa-t oa-k1 0)            ; one key, pinned twice
 (1 = #(keys oa-t))
 !(aall (oa-k1 = @("ab" [1 3] 'sym)))   ; a cell apart is a key apart: the mask has a 0
 !(dig oa-k1 = dig @("ab" [1 3] 'sym))
 (0 = (oa-k1 = @("ab" [1 2])))      ; ..and so is a shape apart: no mask, a 0
 (aall (array [2 2] "a" "b" "c" "d" = array [2 2] ("" + "a") "b" "c" "d"))   ; rank-N alike, cell by cell
 (dig (array [2 2] "a" "b" "c" "d") = dig (array [2 2] ("" + "a") "b" "c" "d"))
 ; the cells move and the key stays findable
 (0 = oa-churn 80) (2 = peep oa-t oa-k1 0) (dig oa-k1 = dig oa-k2))

; --- a cell that is a tray, a ratio or a text takes the whole op, all the way down
(: oa-tt   @(@(1 2) @(3 4))
   oa-deep @(@(@(1 2) @(3 4)) @(@(5 6) @(7 8))))
(test
 (aall ((oa-tt + 1) = @(@(2 3) @(4 5))))
 (aall ((oa-tt + oa-tt) = @(@(2 4) @(6 8))))
 (aall ((2 * oa-tt) = @(@(2 4) @(6 8))))
 (aall ((oa-tt * @(10 100)) = @(@(10 20) @(300 400))))   ; cell by cell: @(1 2) * 10, @(3 4) * 100
 (aall ((oa-tt < 3) = @(@(1 1) @(0 0))))                 ; a comparison answers a mask per cell
 (aall ((oa-deep + 1) = @(@(@(2 3) @(4 5)) @(@(6 7) @(8 9)))))
 (2 = peep (@(1 (1 /// 3)) + 1) 0 0)                     ; a ratio cell takes its own +
 ((4 /// 3) = peep (@(1 (1 /// 3)) + 1) 1 0)
 ("ac" = peep (@("a" 'b) + @("c" "d")) 0 0)              ; ..and a text cell its own
 (0 = (oa-tt + @(1 2 3)))                                ; shapes apart: no answer, a 0
 ; `/` answers per cell as the scalar does, whatever sits beside it: exact where it divides
 ((100 2) / 2 = peep (@((100 2) 3) / 2) 0 0)
 (1.5 = peep (@((100 2) 3) / 2) 1 0)
 (1.5 = peep (@((1 /// 3) 3) / 2) 1 0)
 (1 / 0 = peep (@((100 2) 1) / 0) 1 0)
 ; by 0, as the scalar: // an infinity, % the numerator, a big as a small
 (7 // 0 = peep (@((100 2) 7) // 0) 0 0)
 (7 // 0 = peep (@((100 2) 7) // 0) 1 0)
 (aall ((@((100 2) 7) % 0) = @((100 2) 7)))
 (7 // 0 = peep (@(1 7) // 0) 1 0)                       ; an int tray goes float for it
 (-7 // 0 = peep (@(1 -7) // @(2 0)) 1 0)
 (aall ((@(7 9) // @(2 3)) = @(3 3)))                    ; ..and stays int when no divisor is 0
 (!(gem? (peep (@(7 9) // 2) 0 0))))

; ordering object trays leaves them as they were, and answers one order both ways round
(: oa-o1 (top-tray '(2) ["a" "b"]) oa-o2 (top-tray '(2) ["c" "d"])
   oa-os (sort [oa-o2 oa-o1 oa-o2 oa-o1]))
(test
 (4 = #oa-os) (two? (sort [oa-o1 oa-o1]))
 (([oa-o1] < [oa-o2]) = !([oa-o2] < [oa-o1])) !([oa-o1] < [oa-o1])
 ((max [oa-o1] [oa-o2]) = (max [oa-o2] [oa-o1]))
 ("a" = peep oa-o1 0 ()) ("b" = peep oa-o1 1 ()) ("c" = peep oa-o2 0 ()) ("d" = peep oa-o2 1 ()))
