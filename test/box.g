; wide-integer box (Phase 2): integer ops past the 62-bit fixnum tag promote
; to a boxed i64 instead of a float, and demote back to a fixnum once the
; value fits the tag again. 2^61 (2305843009213693952) is the largest power of
; two still a fixnum; 2^62 is the smallest power of two that must be boxed.
;
; NB: a literal >= 2^62 can't round-trip through the reader (the tag overflows
; / strtol clamps), so the box is never written directly — it is always built
; by arithmetic, and checks either fold it back into fixnum range or compare
; two identically-built boxes.

(assert
 ; --- promotion / demotion boundary ---
 (~ (nump (<< 1 62)))                 ; 2^62 is boxed, not a fixnum
 (~ (flop (<< 1 62)))                 ; ...integer, not float
 (nump (>> (<< 1 62) 1))              ; 2^62 >> 1 = 2^61 demotes to a fixnum
 (= 2305843009213693952 (>> (<< 1 62) 1))
 (nump (- (<< 1 62) (<< 1 62)))       ; box - box = 0, a fixnum
 (= 0 (- (<< 1 62) (<< 1 62)))
 ; -2^62 is exactly FIX_MIN, so it stays a fixnum (the tagged range is
 ; asymmetric: [-2^62, 2^62-1]); one less overflows into a box
 (nump (- 0 (<< 1 62)))
 (~ (nump (- (- 0 (<< 1 62)) 1)))

 ; --- two equal boxes compare = (rides eqv's vec arm); a box never = a fixnum
 (= (<< 1 62) (<< 1 62))
 (= (* 2200000000 2200000000) (* 2200000000 2200000000))
 (~ (= (<< 1 62) 0))

 ; --- bitwise identities reduce a box back to a small fixnum ---
 (= 0  (^ (<< 1 62) (<< 1 62)))       ; X ^ X = 0
 (= -1 (| (~ (<< 1 62)) (<< 1 62)))   ; ~X | X = -1
 (= 0  (& (~ (<< 1 62)) (<< 1 62)))   ; ~X & X = 0
 (= -1 (^ (~ (<< 1 62)) (<< 1 62)))   ; ~X ^ X = -1

 ; --- masked shift-right byte extraction with bit 63 set (the rd64 idiom:
 ; the mask discards the arithmetic-vs-logical shift difference) ---
 (~ (nump (<< 171 56)))                       ; 0xAB << 56 sets bit 63 -> box
 (= 171 (& (>> (<< 171 56) 56) 255))          ; top byte reads back as 0xAB
 (= 205 (& (>> (| (<< 171 56) (<< 205 48)) 48) 255))  ; byte 6 of 0xABCD... = 0xCD
 (= 171 (& (>> (| (<< 171 56) (<< 205 48)) 56) 255))  ; byte 7 = 0xAB

 ; --- multiply stays exact within i64, then divides back down ---
 (= 2200000000 (/ (* 2200000000 2200000000) 2200000000))
 (= 0 (mod (* 2 2305843009213693952) 2))
 (= 1 (mod (+ 1 (* 2 2305843009213693952)) 2))

 ; --- ordered comparison across the box / fixnum / float boundary ---
 (< 2305843009213693952 (<< 1 62))                ; 2^61 < 2^62 (fixnum < box)
 (< (<< 1 62) (* 3 2305843009213693952))          ; box < box
 (<= (<< 1 62) (<< 1 62))
 (> (* 3 2305843009213693952) (<< 1 62))
 (~ (< (<< 1 62) 2305843009213693952))
 (< 1e18 (<< 1 62))                                ; float < box
 (< (<< 1 62) 1e19)                                ; box < float

 ; --- 2^63 = i64 INT_MIN: still a (negative) box, compares and prints right ---
 (~ (nump (<< 1 63)))
 (< (<< 1 63) (- 0 (<< 1 62)))         ; INT_MIN < -2^62

 ; --- a box prints as a plain decimal integer (same as a fixnum) ---
 (= "4611686018427387904" (inspect (<< 1 62)))
 (= "-4611686018427387905" (inspect (~ (<< 1 62))))
 (= "-9223372036854775808" (inspect (<< 1 63))))
