; newtypes -- a STAMP coins COINS: user-defined kinds that ride the generic +/*.
; a coin is a typed hot (stamp + payload) reading KHot, so every +/* combination
; routes to the KHot lane where the coin is intercepted and the stamp's plus/times
; run over the loaded payloads. () stays the +/* identity for free (the mint hoist
; sits above the matrix); net/=/</show default over the payload in the C core.
; `coin`/`load`/`coin?` are the raw primitives; `ring`/`monoid` the builders.

(: ; Z/5Z -- a ring: add and multiply the residues mod 5
   z5 (ring 'z5 (\ x y (% (+ x y) 5)) (\ x y (% (* x y) 5)))
   a  (z5 3)
   b  (z5 4)
   ; a SUM monoid -- a plus but no times (a monoid has no product)
   sm (monoid 'sm (\ x y (+ x y)))
   smp (sm 2)
   smq (sm 3)
   (assert
    ; --- what a coin IS ---
    (coin? a)                      ; a is a coin
    (nil? (coin? 5))               ; a plain value is not
    (nil? (coin? "s"))
    (= 3 (load a))                 ; load reads the payload
    (= 7 (load 7))                 ; load of a non-coin is itself

    ; --- value equality: same stamp + eqv payloads ---
    (= a (z5 3))                   ; by value, not identity
    (nil? (= a (z5 4)))            ; different payload
    (nil? (= a (sm 3)))            ; different stamp (even with equal payload)
    (id? a a)                      ; id? stays identity-sharp
    (nil? (id? a (z5 3)))          ; ... distinct objects

    ; --- + and * run the stamp's methods over the payloads ---
    (= (z5 2) (+ a b))             ; (3+4) mod 5 = 2
    (= (z5 2) (* a b))             ; (3*4) mod 5 = 2
    (= (z5 0) (+ (z5 2) (z5 3)))   ; wraps to 0

    ; --- the ()-identity, inherited FREE (both faces) ---
    (= a (+ () a))                 ; () is +'s identity
    (= a (+ a ()))                 ; ... either side
    (= a (* () a))                 ; () is *'s identity too
    (= a (* a ()))

    ; --- a monoid has a +, but no * ---
    (= (sm 5) (+ smp smq))         ; 2 + 3 = 5
    (nil? (* smp smq))             ; no times slot -> nil, like an undefined matrix cell

    ; --- net defaults over the payload: $, truth, sort ---
    (nil? (sat (z5 0)))            ; payload 0 nets nothing -> false
    (= 3 (sat a))                  ; payload 3
    (= 5 (sat (sm 5)))
    (nil? (z5 0))                  ; a zero-payload coin is false
    (nil? (nil? a))                ; a positive-payload coin is true
    (= (L (z5 1) (z5 2) (z5 3)) (sort (L (z5 3) (z5 1) (z5 2))))  ; ordered by payload

    ; --- show: (name payload), reparsable when the name is a bound constructor ---
    (= "(z5 3)" (show a))
    (= "(sm 5)" (show (sm 5)))

    ; --- the measure law: net is additive through a net-preserving monoid (sm: plus = +) ---
    (= (sat (+ (sm 3) (sm 4))) (sat (+ (sat (sm 3)) (sat (sm 4)))))   ; $(a+b) = $($a + $b) = 7
    (= 6 (net (L (sm 1) (sm 2) (sm 3))))   ; net flows through a list of coins: 1+2+3
    (= 6 (sat (L (sm 1) (sm 2) (sm 3))))   ; ... and $ saturates the same sum

    ; --- two DISTINCT newtypes have no canonical +/* -> nil (like string*string) ---
    (nil? (+ a (sm 3)))            ; z5 coin + sm coin
    (nil? (* a (sm 3)))
    (= (sm 5) (+ (sm 2) (sm 3)))   ; ... but same-stamp still combines

    ; --- tally delegates to the payload ---
    (= 3 (tally (sm (L 7 8 9))))   ; a coin over a 3-list tallies its payload

    ; --- rationals (q): a multi-field coin with an explicit cached net ---
    (= (q 5 6) (+ (q 1 2) (q 1 3)))    ; 1/2 + 1/3 = 5/6
    (= (q 1 2) (* (q 2 3) (q 3 4)))    ; 2/3 * 3/4 = 1/2
    (= (q 1 2) (q 2 4))                ; reduced on construction
    (= (q 1 2) (q (L 1 2)))            ; the 2-list form (what show reads back)
    (nil? (q 0 1))                     ; 0 is false -- the cached net is 0/1 = 0
    (nil? (q -3 2))                    ; a negative rational is RED (net -3/2 < 0) -> false
    (nil? (nil? (q 1 2)))              ; a positive rational is true
    (= 1 (sat (q 1 2)))               ; $ = ceil(1/2) = 1
    (= "(q (1 2))" (show (q 2 4)))     ; show is reduced + reparsable (q accepts the 2-list)
    (= (L (q 1 2) (q 2 3) (q 3 4)) (sort (L (q 3 4) (q 1 2) (q 2 3))))  ; ordered BY VALUE (cached net)
    ))
