; newtypes -- a DIE strikes COINS: user-defined kinds that ride the generic +/*.
; a coin is a typed hot (die + payload) reading KHot, so every +/* combination
; routes to the KHot lane where the coin is intercepted and the die's plus/times
; run over the loaded payloads. () stays the +/* identity for free (the mint hoist
; sits above the matrix); net/=/</show default over the payload in the C core.
; `coin`/`load`/`coin?`/`die-of` are the raw primitives; `ring`/`monoid` the builders.

(: ; Z/5Z -- a ring: add and multiply the residues mod 5
   z5 (ring 'z5 (\ x y (% (+ x y) 5)) (\ x y (% (* x y) 5)))
   a  (z5 3)
   b  (z5 4)
   ; a SUM monoid -- a plus but no times (a monoid has no product)
   sm (monoid 'sm (\ x y (+ x y)))
   smp (sm 2)
   smq (sm 3)
   ; a COUNTED kind -- net-mode 1 (slot 6): nets by tally, not by content
   cntd #(0 'cnt 6 1)
   (cnt p) (coin cntd p)
   (assert
    ; --- what a coin IS ---
    (coin? a)                      ; a is a coin
    (nil? (coin? 5))               ; a plain value is not
    (nil? (coin? "s"))
    (= 3 (load a))                 ; load reads the payload
    (= 7 (load 7))                 ; load of a non-coin is itself
    (id? (die-of a) (die-of (z5 3)))   ; every z5 coin shares one die
    (nil? (die-of 5))              ; a non-coin has no die

    ; --- value equality: same die + eqv payloads ---
    (= a (z5 3))                   ; by value, not identity
    (nil? (= a (z5 4)))            ; different payload
    (nil? (= a (sm 3)))            ; different die (even with equal payload)
    (id? a a)                      ; id? stays identity-sharp
    (nil? (id? a (z5 3)))          ; ... distinct objects

    ; --- + and * run the die's methods over the payloads ---
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
    (= (sm 5) (+ (sm 2) (sm 3)))   ; ... but same-die still combines

    ; --- tally delegates to the payload ---
    (= 3 (tally (sm (L 7 8 9))))   ; a coin over a 3-list tallies its payload

    ; --- net-mode 1 (slot 6): net by TALLY -- truth reads "has any", never "sums green" ---
    (= 2 (sat (cnt (L 1 -5))))     ; content sums -4; the COUNT is 2
    (nil? (nil? (cnt (L -3))))     ; red content, still true: one element is SOMETHING
    (nil? (cnt ()))                ; an empty payload counts 0 -> nothing
    (= 0 (sat (cnt ())))
    (= 3 (net (L (cnt (L 1)) (cnt (L 1 1)))))   ; counts flow through the list sum: 1+2
    (= -4 (net (sm (L 1 -5))))     ; mode absent: the payload hom, signed, as ever

    ; --- rationals (q): a multi-field coin; +/*/=/show all work. (a coin nets its
    ;     payload, so q's truth/sort go by representation, not value -- not asserted.) ---
    (= (q 5 6) (+ (q 1 2) (q 1 3)))    ; 1/2 + 1/3 = 5/6
    (= (q 1 2) (* (q 2 3) (q 3 4)))    ; 2/3 * 3/4 = 1/2
    (= (q 1 2) (q 2 4))                ; reduced on construction
    (= (q 1 2) (q (L 1 2)))            ; the 2-list form (what show reads back)
    (= "(q (1 2))" (show (q 2 4)))     ; show is reduced + reparsable

    ; --- `-` rides slot 5: q pins it (cross-multiply, reduce); the unit still rides ---
    (= (q 1 6) (- (q 1 2) (q 1 3)))    ; 1/2 - 1/3 = 1/6
    (= (q -1 1) (- (q 1 2) (q 3 2)))   ; goes red exactly
    (= (q 1 2) (- (q 3 2) 1))          ; an integer rides cap/mint, either side
    (= (q 1 2) (- 1 (q 1 2)))
    (= (q 1 2) (- (q 1 2) ()))         ; () is the do-nothing operand for - too
    (= (q 1 2) (- () (q 1 2)))         ; ... either side (the op never happens)
    (nil? (- a (z5 1)))                ; a die without slot 5 -> nil, like a monoid's *
    (nil? (- a (sm 3)))                ; distinct dies never combine

    ; --- a method OWNS its domain: off it (no star / (n d)-of-stars face), () ---
    (nil? (+ (q 1 2) (L (q 1 1) (q 0 1))))   ; a chain of coins is not an (n d)
    (nil? (* (q 1 2) (L 'x)))                ; nor a chain of symbols
    (nil? (- (q 1 2) "s"))                   ; nor text
    (= (q 1 1) (+ (q 1 2) (L 1 2)))          ; ... but a bare (n d) of stars reads as n/d

    ; --- an OPEN star (slot 7): q declares its coins numeric, so a numeral
    ;     POWERS them through their own * (exact squaring) instead of composing ---
    (= (q 1 4) (2 (q 1 2)))            ; (n x) = x**n, through the die
    (= (q 8 27) (3 (q 2 3)))
    (= (q 1 4) ((q 1 2) ** 2))         ; the apply operator rides the same law
    (= (q 1 2) (1 (q 1 2)))            ; the identity numeral
    (= 1 (0 (q 5 7)))                  ; the zero numeral: x**0 = 1
    (nil? (-1 (q 2 1)))                ; a reciprocal power needs coin / -- absent, ()
    (nil? ((/ 1 2) (q 4 1)))           ; a non-whole exponent off the tower: ()
    (nil? (coin? (2 (sm 3))))          ; an UNflagged coin still composes (a closure)

    ; --- a coin's lit?-ness is its die's call: fresh DATA by default ---
    (nil? (lit? (q 1 2)))          ; a rational is DATA -- a value, not a reference (like a number)
    (nil? (lit? a))                ; a mod-n residue too
    (nil? (lit? (sm 5)))
    (nil? (lit? (coin #(0 'd) 5))) ; a plain die -> data
    (lit? (coin #(0 'h 4 1) 5))    ; ... but a die with DIE_HOT (slot 4) strikes lit coins
    ))
