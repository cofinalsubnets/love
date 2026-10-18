; coins: user-defined kinds whose +/* run the kind's methods over the payloads.
; () stays the identity; net, =, < and show default to the payload

(: ; Z/5Z
   z5 (coin 'z5 (z \ {'+ (lift z (x \ y \ (x + y) % 5))
                     '* (lift z (x \ y \ (x * y) % 5))}))
   a  (z5 3)
   b  (z5 4)
   ; a plus but no times
   sm (coin 'sm (z \ {'+ (lift z (x \ y \ x + y))}))
   smp (sm 2)
   smq (sm 3)
   ; nets by tally, not content
   cnt (coin 'cnt {'net (c \ #(load c))})
   (tail-from k l) (? (atom? l) () (<l = k) l (tail-from k >l))
   (test
    ; --- what a coin is ---
    (coin? a)
    !(coin? 5)
    !(coin? "s")
    !(coin? (x \ x))         ; it shares the hot row
    !(coin? sin)
    (3 = load a)
    (7 = load 7)           ; a non-coin loads itself
    (kind a = kind (z5 3))
    !(kinds (kind 5))      ; a built-in kind has no table

    ; --- kind: the name a value dispatches as ---
    ('z5 = kind a)
    ('coin = kind (strike {} 5))   ; an unnamed table is a coin, not the row's lambda
    ('charm = kind 5)  ('mint = kind ())  ('mint = kind (nom 0))  ('nom = kind 'a)
    ('string = kind "s")  ('chain = kind [1 2])  ('tablet = kind {})
    ('lambda = kind (x \ x))  ('port = kind out)  ('cask = kind (cask 4))
    ; --- the registry: a kind's table by name, names in registration order ---
    ('lambda = kind ((kinds 'z5) '+))
    (tail-from 'z5 (kinds ()) @ l ('(z5 sm) = [<l <>l]))
    ([(z5 1) (sm 1)] = sort [(sm 1) (z5 1)])   ; distinct kinds order by registration

    ; --- equality: same kind, eqv payloads ---
    (a = z5 3)
    !(a = z5 4)
    !(a = sm 3) ; different kind, equal payload

    ; --- + and * run the kind's methods over the payloads ---
    (z5 2 = a + b)
    (z5 2 = a * b)
    (z5 0 = z5 2 + z5 3)

    ; --- the () laws, inherited free ---
    (a = () + a)
    (a = a + ())
    (() = () * a)                ; *'s zero
    (() = a * ())

    ; --- a kind with a +, but no * ---
    (sm 5 = smp + smq)
    !(smp * smq)             ; no times slot -> ()

    ; --- net defaults to the payload: $, truth, sort ---
    !$(z5 0)
    (3 = $a)
    (5 = $(sm 5))
    !(z5 0)
    !!a
    ([(z5 1) (z5 2) (z5 3)] = (sort [(z5 3) (z5 1) (z5 2)]))

    ; --- show: (name payload), reparsable when the name is a bound constructor ---
    ("(z5 3)" = show a)
    ("(sm 5)" = show (sm 5))

    ; --- net is additive through a net-preserving monoid (sm: plus = +) ---
    ($(sm 3 + sm 4) = $($(sm 3) + $(sm 4)))
    (6 = +[(sm 1) (sm 2) (sm 3)])
    (6 = $[(sm 1) (sm 2) (sm 3)])

    ; --- distinct kinds have no canonical +/* -> () ---
    !(a + sm 3)
    !(a * sm 3)
    (sm 5 = sm 2 + sm 3)

    ; --- tally delegates to the payload ---
    (3 = #(sm [7 8 9]))

    ; --- a 'net method: truth reads "has any", never "sums green" ---
    (2 = $(cnt [1 -5]))
    !!(cnt [-3])
    !(cnt ())
    (0 = $(cnt ()))
    (3 = +[(cnt [1]) (cnt [1 1])])
    (-4 = +(sm [1 -5]))      ; no 'net: the payload hom, signed

    ; --- rationals (///): a multi-field coin, the one coin that is a number;
    ; a whole rational is the integer
    (5 /// 6 = 1 /// 2 + 1 /// 3)
    (1 = 1 /// 2 + 1 /// 2)
    (charm? (4 /// 2))               ; a whole quotient, at the strike
    (3 = 6 /// 2)
    (2 = int (5 /// 2))     (3 = ceil (5 /// 2))     (3 = $(5 /// 2))
    (-2 = int (-5 /// 2))   (-2 = ceil (-5 /// 2))   (0 = $(-5 /// 2))
    (3 /// 2 = max 1 (3 /// 2))   (1 = min 1 (3 /// 2))   (1 /// 2 = min (3 /// 2) (1 /// 2))
    (1 /// 2 = 2 /// 3 * 3 /// 4)
    (1 /// 2 = 2 /// 4)                ; reduced on construction
    (1 /// 2 = (/// [1 2]))             ; the 2-list form show reads back
    (1 /// 6 = (1 /// 3) /// 2)  (2 = (4 /// 3) /// (2 /// 3))   ; a rational operand divides exactly
    !(1 /// 0)  !(/// [1 0])  !((1 /// 3) /// 0)  !((1 /// 3) /// (1 /// 0))   ; by zero -> ()
    !("ab" /// 2)  !(2 /// "ab")  !([1 2] /// 3)
    ; a float has no gcd: a rational meeting one answers the float, the inexact winning
    (gem? (0.5 + 1 /// 3))  (0.5 + 1 /// 3 = 0.5 + 1 / 3)  (gem? ((1 /// 3) + 0.5))
    (gem? (0.5 * 1 /// 3))  (gem? (0.5 - 1 /// 3))  (gem? ((1 /// 3) / 0.5))  ((1 /// 2) * 0.5 = 0.25)
    (gem? (2.5 /// 1))  (2.5 = 2.5 /// 1)  (2.0 = 1 /// 0.5)  (0.25 = (1 /// 2) /// 2.0)  !(1.0 /// 0)
    ; show is reduced and reparsable
    ("(1 /// 2)" = show (2 /// 4))
    (1 /// 2 = ev <(sound (show (2 /// 4))))

    ; --- a rational promotes across the tower ---
    ; `=` agrees with the order
    (: a (4 /// 2) b 2  ((a <= b && a >= b) = (a = b)))
    (1 /// 1 = 1)   (1 = 1 /// 1)   (4 /// 2 = 2)   (0 /// 1 = 0)
    (7 /// 2 = 3.5) (3.5 = 7 /// 2) (1 /// 2 = 0.5)
    !(1 /// 2 = 1)  !(1 /// 1 = 2)
    (elem (1 /// 1) [1 2 3])  (nelem (9 /// 1) [1 2 3])
    ([0 (1 /// 1) 2] = sort [2 (1 /// 1) 0])
    ; exact, never through a double, which would round these together
    (2 3 40 @ h (!(1 /// h = 1 /// (h + 1)) && !((h + 1) /// h = 1.0)))
    ; an ordinary newtype stays opaque
    (coin 'metre (z \ {}) @ m (!(m 5 = 5) && !(5 = m 5) && (m 5 = m 5)))

    ; --- `-` rides slot 5 ---
    (1 /// 6 = 1 /// 2 - 1 /// 3)
    (-1 /// 1 = 1 /// 2 - 3 /// 2)
    (1 /// 2 = 3 /// 2 - 1)          ; an integer rides cap/mint, either side
    (1 /// 2 = 1 - 1 /// 2)
    !(1 /// 2 - ()) ; () is absent to -
    !(() - 1 /// 2)
    !(a - z5 1)
    !(a - sm 3)

    ; --- `/` rides slot 8; zero has no reciprocal ---
    (3 /// 2 = 1 /// 2 / 1 /// 3)
    (1 /// 4 = 1 /// 2 / 2)         ; an integer rides either side
    (2 /// 1 = 1 / 1 /// 2)
    (-3 /// 2 = 1 /// 2 / -1 /// 3) ; the sign lands on the numerator
    !(1 /// 2 / 0 /// 1)            ; Q holds no inf
    !(1 /// 2 / 0)
    !(1 /// 2 / ())
    !(() / 1 /// 2)
    !(a / z5 2)
    !(a / sm 3)

    ; --- a method owns its domain: off it, () ---
    !(1 /// 2 + [(1 /// 3) (1 /// 3)])    ; a chain of coins is not an (n d)
    !(1 /// 2 * ['x])
    !(1 /// 2 - "s")
    (1 /// 1 = 1 /// 2 + [1 2])           ; a bare (n d) of stars reads as n/d

    ; --- an open star (slot 7): a numeral powers the coin through its own * ---
    (1 /// 4 = 2 (1 /// 2))
    (8 /// 27 = 3 (2 /// 3))
    (1 /// 4 = 1 /// 2 ** 2)         ; the apply operator rides the same law
    (1 /// 2 = 1 (1 /// 2))
    (1 = 0 (5 /// 7))                  ; x**0 = 1
    (1 /// 2 = -1 (2 /// 1))           ; a reciprocal power rides slot 8
    (9 /// 4 = -2 (2 /// 3))           ; ipow, then invert
    (9 /// 4 = 2 /// 3 ** -2)
    !((1 / 2) (4 /// 3))           ; a non-whole exponent: ()
    ('lambda = kind (2 (sm 3)))  ; an unflagged coin still composes

    ; --- a rational's truth is its value's sign, exactly ---
    !(-1 /// 2)
    !!(1 /// 2)
    !(0 /// 5)
    (1 = $(1 /// 2))                ; $ ceils the magnitude
    (2 = $(3 /// 2))
    (0 = $(-7 /// 2))               ; and clamps red to the floor
    !!(1 /// 2 - 1 /// 3)
    !(1 /// 3 - 1 /// 2)
    !!(/// 1 (1000 10))      ; a 10^1000 denominator underflows the double;
    !(/// -1 (1000 10))            ; the sign survives it

    ; --- a rational orders by value, through its own '< ---
    (/// 1 3 < 1 /// 2)                ; not payload order
    !(/// 1 2 < 1 /// 3)
    !(/// 1 2 < 2 /// 4)         ; equal values tie
    !(/// 2 4 < 1 /// 2)
    (/// 1 2 < 1)                      ; interleaved with the closed tower
    (0 < 1 /// 2)
    (/// -1 2 < 0)
    (1 < 3 /// 2)
    (/// 3 2 >= 1)
    (/// 1 2 <= 2 /// 4)
    (1 < 9007199254740993 /// 9007199254740992)   ; a double would tie at 1.0
    ([(-1 /// 2) (1 /// 3) (1 /// 2) 1 (3 /// 2) 2] =
     (sort [2 (1 /// 2) 1 (3 /// 2) (1 /// 3) (-1 /// 2)]))
    (/// 9 1 < cnt [1])             ; a coin without '< keeps the coin band, above the numbers

    ; --- a declared star self-nets ---
    (1 /// 2 = +(1 /// 2))          ; net answers the coin itself
    (star? (1 /// 2))                    ; star? holds with no coin branch of its own
    !(star? a)                   ; an undeclared coin nets its payload
    !(star? (sm 3))
    (5 /// 6 = +[(1 /// 2) (1 /// 3)])    ; exact rational sum

    ; --- a coin is data, never lit? ---
    !(lit? (1 /// 2))
    !(lit? a)
    !(lit? (sm 5))
    !(lit? (coin 'd () 5))
    !(lit? (coin 'h {'hot 1} 5))      ; 'hot is no slot: a kind table's other keys are its own
    ))
