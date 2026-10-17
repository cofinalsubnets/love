; the wide-int box: past the 62-bit fixnum tag ints box, and demote once they fit.
; boxes are built by arithmetic, never written as literals. 64-bit words only
(word ? (test
 ; --- promotion / demotion boundary ---
 !(charm? (1 << 62))                 ; 2^62 is boxed, not a fixnum
 !(gem? (1 << 62))                 ; ...integer, not float
 (charm? ((1 << 62) >> 1))              ; 2^62 >> 1 = 2^61 demotes to a fixnum
 (2305843009213693952 = ((1 << 62) >> 1))
 (charm? ((1 << 62) - (1 << 62)))       ; box - box = 0, a fixnum
 (0 = ((1 << 62) - (1 << 62)))
 ; the tagged range is [-2^62, 2^62-1]: -2^62 stays a fixnum, one less boxes
 (charm? (0 - (1 << 62)))
 !(charm? ((0 - (1 << 62)) - 1))

 ; --- two equal boxes compare =; a box never = a fixnum
 ((1 << 62) = (1 << 62))
 (2200000000 * 2200000000 = 2200000000 * 2200000000)
 !((1 << 62) = 0)

 ; --- bitwise identities reduce a box back to a small fixnum ---
 (0 = ((1 << 62) ^ (1 << 62)))         ; X ^ X = 0
 (-1 = (((1 << 62) ^ -1) | (1 << 62))) ; ~X | X = -1
 (0 = (((1 << 62) ^ -1) & (1 << 62)))  ; ~X & X = 0
 (-1 = (((1 << 62) ^ -1) ^ (1 << 62))) ; ~X ^ X = -1

 ; --- masked byte extraction with bit 63 set: the mask hides the shift's sign fill ---
 !(charm? (171 << 56))                               ; 0xab << 56 sets bit 63 -> box
 (171 = (((171 << 56) >> 56) & 255))                 ; top byte reads back as 0xab
 (205 = ((((171 << 56) | (205 << 48)) >> 48) & 255)) ; byte 6 of 0xabcd... = 0xcd
 (171 = ((((171 << 56) | (205 << 48)) >> 56) & 255)) ; byte 7 = 0xab

 ; --- multiply stays exact within z, then divides back down ---
 (2200000000 = (2200000000 * 2200000000 / 2200000000))
 (0 = ((2 * 2305843009213693952) % 2))
 (1 = ((1 + 2 * 2305843009213693952) % 2))

 ; --- ordered comparison across the box / fixnum / float boundary ---
 (2305843009213693952 < (1 << 62))       ; 2^61 < 2^62 (fixnum < box)
 ((1 << 62) < 3 * 2305843009213693952) ; box < box
 ((1 << 62) <= (1 << 62))
 (3 * 2305843009213693952 > (1 << 62))
 !((1 << 62) < 2305843009213693952)
 (1e18 < (1 << 62)) ; float < box
 ((1 << 62) < 1e19) ; box < float

 ; --- -2^63 = INT_MIN is a box; built by negation, since (1 << 63) is a big ---
 !(charm? (0 - (63 2)))
 ((0 - 63 2) < (0 - (1 << 62)))      ; INT_MIN < -2^62

 ; --- a box prints as a plain decimal integer (same as a fixnum) ---
 ("4611686018427387904" = show (1 << 62))
 ("-4611686018427387905" = show ((1 << 62) ^ -1))
 ("-9223372036854775808" = show (0 - 63 2))) 0)
