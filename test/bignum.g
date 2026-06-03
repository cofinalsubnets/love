; step 6: arbitrary-precision integers (bignums).
; - the numeric tower closes: fixnum -> wide-int box -> bignum
; - + - * overflow promotes to an exact bignum; / % are truncated division
; - canonical demotion: any result that fits a smaller tier shrinks back to it
;   (so = / eqv / table keys stay well defined across tiers)
; - reader parses oversized decimal literals exactly; printer is base-10
; - mixed fixnum/box/bignum/float arithmetic, comparison, equality

(: (bfact n) (? (< n 2) 1 (* n (bfact (- n 1))))
   (bpow2 n) (? (< n 1) 1 (* 2 (bpow2 (- n 1))))
   B100 (bpow2 100)
   F25 (bfact 25)
   F24 (bfact 24))

(assert
 ; --- overflow promotion + exact value, read round-trip against a literal ---
 (= F25 15511210043330985984000000)
 (= B100 1267650600228229401496703205376)
 (= (* 1000000000000 1000000000000) 1000000000000000000000000)
 (= (+ F25 1) 15511210043330985984000001)
 (= (- F25 1) 15511210043330985983999999)
 (= (bpow2 200) (* B100 B100))            ; identity instead of a transcribed literal
 (= (bpow2 64) 18446744073709551616)

 ; --- a bignum is its own tier: not a fixnum, truthy, not falsy, not a pair ---
 (nilp (nump B100))                       ; (nump bignum) is false
 (? B100 -1 0)                            ; a bignum is truthy
 (nilp (nilp B100))                       ; ...hence not falsy
 (atomp B100)

 ; --- canonical demotion: shrinking results fall back to the smallest tier ---
 (= 0 (- F25 F25))
 (nump (- F25 F25))                       ; demoted all the way to a fixnum
 (= 25 (/ F25 F24))
 (nump (/ F25 F24))
 (= F24 (/ F25 25))
 (= 1 (/ B100 B100))
 (nump (/ B100 B100))

 ; --- divmod identities: a == (a/b)*b + a%b ---
 (= B100 (+ (* (/ B100 1000000007) 1000000007) (% B100 1000000007)))
 (= B100 (+ (* (/ B100 (bpow2 40)) (bpow2 40)) (% B100 (bpow2 40))))   ; multi-limb divisor
 (= F25 (+ (* (/ F25 F24) F24) (% F25 F24)))
 (= 2 (% B100 7))                         ; 2^100 mod 7

 ; --- signs: truncate toward zero, remainder follows the dividend ---
 (= -25 (/ (- 0 F25) F24))
 (= 25 (/ (- 0 F25) (- 0 F24)))
 (= -25 (/ F25 (- 0 F24)))
 (= -2 (% (- 0 B100) 7))
 (= 2 (% B100 (- 0 7)))
 (= -2 (% (- 0 B100) (- 0 7)))
 (= (- 0 B100) (* -1 B100))
 (= B100 (- 0 (- 0 B100)))
 (= (- 0 B100) -1267650600228229401496703205376)

 ; --- the lone INT_MIN/-1 case: -2^63 / -1 is the exact 2^63, %-1 is 0 ---
 (= (bpow2 63) (/ (- 0 (bpow2 63)) -1))
 (= 0 (% (- 0 (bpow2 63)) -1))

 ; --- mixed-tier comparison (fixnum / box / bignum) ---
 (< F24 F25)
 (> F25 F24)
 (<= F25 F25)
 (>= F25 F25)
 (< 5 B100)
 (< (- 0 B100) 5)
 (< (- 0 B100) B100)
 (= F25 (bfact 25))                       ; two independent computations are equal
 (!= F25 B100)
 (!= B100 (+ B100 1))
 (< B100 (+ B100 1))

 ; --- mixed with floats: a float operand widens the bignum to double ---
 (flop (+ B100 0.5))
 (flop (* B100 1.0))
 (< B100 1e40)
 (> B100 1e20)
 (= 0 (* B100 0))                         ; * fixnum 0 -> exact 0
 (nump (* B100 0))

 ; --- printer round-trip (base 10, with sign) ---
 (= "1267650600228229401496703205376" (inspect B100))
 (= "-1267650600228229401496703205376" (inspect (- 0 B100)))
 (= "9223372036854775808" (inspect (bpow2 63)))
 (= "15511210043330985984000000" (inspect F25))

 ; --- bignums as table keys (eqv over slen+limbs) ---
 (= 'hit (get 'miss B100 (put B100 'hit (put F25 'fk (new 0)))))
 (= 'fk (get 'miss F25 (put B100 'hit (put F25 'fk (new 0)))))
 (= 'miss (get 'miss (+ B100 1) (put B100 'hit (new 0)))))
