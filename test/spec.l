; love spec -- the executable language reference: each section states its laws, the asserts prove them.
; runs right after test/00-init.l's harness.

; --- everything is a function --- (f x y) == ((f x) y), (f) == f; numbers are church
; numerals; data self-applies.
(test
 (1 = 0 5) (5 = 1 5)                              ; 0 is const-1, 1 is the identity
 (1 = 0 0) (7 = 0 0 7)                            ; const of const is the identity
 (8 = 3 2) (262144 = 2 3 4)                       ; (n x) = x**n; the tower (2 3 4) = 4**(3**2)
 (12 = 3 (+ 1) 9) ('(2 3 4) = map (+ 1) '(1 2 3)) ; (n f) composes f ($ n) times; currying is partial application
 (10 = -3 (+ 1) 10) (13 = 2.5 (+ 1) 10)           ; the count saturates: (-3 f) = (0 f) = 1; a float ceils
 (0.5 = -1 2) (3.0 = (1 / 2) 9))                  ; ... but exponents don't: (-1 x) = 1/x; (1/2 x) = sqrt x

; --- three special forms --- `:` letrec*/sequence, `?` cond, `\` lambda (one operand: quote).
; a body-having `:` is one scope; an empty special form reads its head (the zero point).
(test
 (3 = (: a 1 b 2 (a + b)))                       ; `:` binds in source order; the last form is the result
 (7 = ((x \ y \ x + y) 3 4))                     ; `\ args.. body` -- a lambda, auto-curried
 ('(1 2) = (\ (1 2)))                            ; one operand: `\` is quote, so 'x is just (\ x)
 ('big = (? 0 'a (1 < 2) 'big 'else)))           ; `?` -- t/result pairs, then a final else
(: (twice f x) (f (f x)) (test (12 = (twice (+ 1) 10))))
(test
 ((:) = (?)) ((?) = (\)) !(:) !(nom? (:))          ; the empty form is the head read: the zero point, not a nom
 ((:) = (? 0 'a)) ((:) = (map (+ 1) ()))          ; a no-match `?` falls to the zero point, not charm 0
 (2 = (: x 1 x (x + 1) x)))                      ; the sequence law: a rebind reads the previous value
; one scope: a forward read raises missing; welp answers the zero point (test-strict would quit)
(hear welp)
(test ((:) = (: a b b 2 a)) (2 = (: a b b 2 b)))
(hear test-strict)

; --- true and false --- false is whatever nets <= 0 (numbers their value, text its charm sum,
; lists the sum of element nets). `!` (nil?) reads the net's sign; `$` (sat) clamps max(0, ceil);
; !x == (0 = $x). a twin is read by its real part alone, so a pure phase is false. colors by net
; sign: green nonnegative, red negative, blue the zero floor; true iff positive green. the count
; is `tally`, never $; the connective is `&&`, never `*`.
(test
 !0 !"" !@0 !() !0.0 !(0 ~ 0)                    ; zero / empty -> false
 !-5 !-3.9 !(-3 ~ 4) !(0 ~ -1)                   ; <= 0 in the total order -> false (complex by re then im)
 !!5 !!"x" !!'a !!cap !!(3 ~ 4) !!(3 ~ -4)       ; positive / nonempty -> true (a twin gem by its re)
 !!{} (1 = ${}) (2 = #{1 2 3 4})                   ; a tablet is a lookup lambda and nets 1,
 (1 = ${1 2 3 4})                     ; empty or not; tally counts the keys, $ never does
 !'(() ()) !'(0 0) !'((0) (())) (0 = $'(() () ()))               ; a chain of nothings is nothing, recursively
 !'(-5) !@(-3 -4) !'(-2 1) !!'(0 1)                              ; negatives net <= 0 at every rank; -2+1 < 0 < 0+1
 (3 = $'(1 () 2)) (6 = $'(1 2 3)) (7 = $@(3 4))                  ; $ sums the nets, then clamps once
 (word ? (: n ((53 2) + 1) m ((53 2) + 3) (n = $n && m = $m)) 1) ; $ is exact on a green charm past 2^53
 (3 = $(. 1 2)) !!(. 0 2) (6 = $(1 . 2 . 3))                     ; every link nets car + cdr, so a dotted tail counts too
 (0 = $[(3 ~ 4) (-3 ~ 4)]) ![(0 ~ 5) -1]                         ; phases sum as vectors, then gate the total once
 !i !(0 ~ 8) (0 = $i)                                  ; a pure phase is blue: truth cannot part i from -i,
 (i < 5) ((0 ~ -1) < i)                                          ; ..but the order must
 (3 = $(3 ~ 4)) (3 = $(3 ~ -4))                  ; ...so the amount is the real part, conjugate-blind
 (1 = $@(0.3 0.4)) (1 = $(0.001 ~ 0))            ; the clamp ceils, so any positive net reaches 1 at every tier
 (120 = $(nom 'x)) (2 = (int (abs {1 10 2 20})))   ; a nom nets its spelling's charms
 ($(100 2) = $(200 2)) (0 = $(0 - (100 2))) (0 = $(0 - (62 2)))  ; a positive big saturates; red is red at every width
 (1 = $'(1)) (0 = $'(0)) (0 = $0) (-1 = +'(-2 1))  ; the colors: '(1) green, '(0)/0 blue, '(-2 1) red
 (1 = !!$5) (0 = !!$0) (0 = !!$-3)               ; !!$ is the truth bit (1 true, 0 false)
 (0 = !5) (1 = !0) (zero? = nil?)                   ; ! negates it; zero? is nil?
 (star? 5) (star? -3.5) (star? (2 ~ 3)) (star? (62 2))        ; a star is a self-netting scalar
 !(star? @(1 2 3)) (star? (net @(1 2 3)))                   ; a tray is not a star; its net is
 !(star? "x") !(star? 'a) !(star? '(1 2))
 (charm? 5) !(charm? 3.5) !(charm? @(1 2 3)) !(charm? 'a) (charm? 5 ? (star? 5) 1)     ; a charm is the word-sized star
 (tray? @(1 2 3)) (tray? @("a" "b"))                      ; a tray holds any element kind
 (galaxy? @(1 2 3)) !(galaxy? @("a" "b"))                   ; a galaxy is a numeric tray
 (galaxy? (array '(2) (200 2) (200 2)))                    ; bignum cells are stars
 !(galaxy? 5) !(galaxy? '(1 2))            ; disjoint; a scalar or list is neither
 (!"" = (0 = $"")) (!-5 = (0 = $-5)))            ; the parens matter: bare, = chains

; --- types & predicates --- storage: charm? sun? gem? twin? tray? string? nom? name? mint? two? tablet?;
; derived constellation? whole? atom?; lit? a top-region value (tablet/fn/hot); hot? the cask/port subset.
; a predicate answers a bit, never the zero point: the sweep below probes every `?`-named global.
; `&&`/`||` are not predicates, they preserve values.
(test
 (two? '(1 2)) (string? "hi") (nom? 'x) (tablet? {1 2})
 (sun? (100 2)) (sun? (62 2)) (gem? 1.5) (twin? i)   ; one boxed integer tier, whatever the word
 (constellation? 1.5) (constellation? i) (constellation? (62 2)) (whole? (62 2)) (atom? 'x) !(atom? '(1))
 (hot? (cask 4)) (hot? out) (hot? (tap '(104)))   ; the hot zoo, named
 !(hot? {}) !(hot? cap) !(hot? 5) !(hot? "s")    ; maps/functions/data are not hots
 (lit? (cask 4)) (lit? cap) (lit? {}) !(lit? '(1)) !(lit? "s") !(lit? 5) !(lit? ())  ; not data leaves, nor the floor
 (1 = $cap) (1 = $out) (1 = $(tap 0))            ; tops and ports net 1: present, drained or not
 (charm? (twirl (x \ x) 0 @ p (catch p, p)))     ; a task id is a number, not a handle
 ((64 2) = 2 * (63 2))                           ; charm overflow -> exact big ((k b) = b**k)
 ((2.0 ~ 3.0) = 2 + 3 * i))  ; mixed arithmetic widens to the higher tier

(hear welp)                                      ; misses answer quietly
; the census is the core book's contract: egg lane only (love-image marks a woken image)
(: (q-nom? n) (: s (string n) t #s (0 < t ? (63 = peep s (t - 1) 0) 0))
   (q-bit? n) (: f (ev n)
                 (ok v) !(() = f v)
                 (ok 'zz && ok 0 && ok "" && ok ()))
   bad (elem 'love-image (names ()) ? ()
          (filter (n \ !(q-bit? n)) (filter (n \ q-nom? n && !!(ev n)) (names ()))))
   (two? bad ? (puts ("bit-law offenders: " + show bad + "\n"), 0) 0,
    (test (atom? bad))))
(hear test-strict)

; --- arithmetic --- + - * / // % infix; overflow grows charm->sun->big; `/` is true division;
; 0/0 is () (no value is unequal to itself). bitwise << >> & | ^ are exact two's complement over
; the whole tower, the sign extended forever: << promotes, a negative count reverses, >> floors
; where // truncates; a non-integer operand answers the zero point. the sections ((- 0), (/ 1))
; are the monadics.
(test
 (3 = 1 + 2) (2.5 = 5 / 2) (2 = 5 // 2) (0.5 = 1 / 2) (1 = 5 % 2) (3.5 = 1 + 2.5)
 (1.0 = 7.0 % 2.0) (0.0 = 7.5 % 2.5) (-1.0 = -7.0 % 2.0)   ; % rides fmod: the sign follows the dividend,
 (7 = 7 % 0) (7.0 = 7.0 % 0.0)                             ; and a zero modulus leaves the dividend whole
 ; forced: (a // 0) * 0 is () and () is +'s unit, so the remainder carries a whole (Z/0Z is Z)
 (7 = ((7 // 0) * 0) + (7 % 0)) (-7 = ((-7 // 0) * 0) + (-7 % 0))
 (7 = ((7 // 3) * 3) + (7 % 3))
 (2 = 4 / 2) (charm? (4 / 2)) (-2 = -5 // 2)
 (-5 = ((- 0) 5)) (0.25 = ((/ 1) 4)) ((-1 ~ -2) = ((- 0) (1 ~ 2))) ; the sections are the monadics
 !(charm? (2 * 2305843009213693952)) (gem? (1 / 0)) (word ? (1e308 < 1 / 0) 1) (() = 0 / 0)
 (infinity = 1 / 0) ("infinity" = show (1 / 0)) ("-infinity" = show (-1 / 0))
 (word ? ("1.7976931348623157e308" = show 1.7976931348623157e308) 1)  ; only true infinity prints as infinity
 ; shortest-roundtrip printing; these faces are the double tier's (a 32-bit flo_t's differ)
 (word ? ("0.30000000000000004" = show (0.1 + 0.2)) 1) ("0.3" = show 0.3)
 (word ? ("5e-324" = show 5e-324) 1) (word ? ("1e23" = show 1e23) 1)
 ; ..and reading is correctly rounded
 (word ? !(0.3 = 0.30000000000000004) 1) (word ? (0.5 = 0.49999999999999999999) 1)
 ; ..C99 hex floats too, exact; the subnormal floor and its tie
 (word ? (0x1p4 = 16.0) 1) (word ? (0x1.8p1 = 3.0) 1) (word ? (-0x1p-1 = -0.5) 1)
 (word ? (0x1p-1074 = 5e-324) 1) (word ? (0x1p-1075 = 0.0) 1)
 (word ? (0x1.8p-1075 = 5e-324) 1)                      ; past the tie, it rounds up
 (word ? (0x1.fffffffffffffp+1023 = 1.7976931348623157e308) 1)
 (0x10 = 16) (nom? '0x)                    ; 0x10 is the integer lane; a bare 0x a symbol
 (0 / 0 = 0 / 0) !(0 / 0) (0 = $(0 / 0))       ; reflexive, false, and nets nothing
 (nom? 'inf) (nom? 'nan)                       ; the short spellings stay free names: `infinity`
 !(nom? 'infinity) (gem? 'infinity)            ; is the one the reader spends, and it reads a value
 ; a NaN cell: peep and show give (), it nets nothing, = is reflexive
 ((@(0.0) / @(0.0)) @ t (t = t && () = peep t 0 0 && "@(())" = show t
                           && !t && t != @(0.0)))
 ; bignum // and % ride Knuth-D; show on a big divides too
 (1267650591354675262013 = 100 2 // 1000000007) (976371285 = 100 2 % 1000000007)
 (100 2 = 200 2 // 100 2) ("1267650600228229401496703205376" = show (100 2))
 (-2 = 1 ^ -1) (15 = 8 | 4 | 2 | 1) (16 = 64 >> 2) (16 = 2 << 3)
 ((3 * (200 2)) = (3 << 200)) (0 = (0 << 500))   ; the count is exact, never masked
 ((63 2) = (1 << 63)) ((64 2) = (1 << 64))       ; ..and << promotes past the sign
 (-1 = -1 >> 1) (-4 = -8 >> 1)               ; >> is arithmetic: it sign-extends
 (0 = 5 >> 64) (-1 = -5 >> 64)               ; ..past the width it lands on the sign, not the value
 (2 = 8 << -2)                                 ; a negative count turns the shift round
 (255 = (200 2 + 255) & 255)                 ; a big rides the lane, either sign
 (0 - 1 = (0 - 200 2 | 0 - 1)))

; --- order & equality --- < <= > >= are total over all values, in bands: points (() < mints <
; names), string, constellations by net (a star below a galaxy on a tie; tiers nest N < Z < R < C),
; tray < chain < map < top. text and chains are lexicographic, maps and lambdas by an alpha-invariant
; hash. an array operand broadcasts < to a mask. `=` bridges the numeric tower and compares
; structurally; not-equal is !=.
(test
 (3 = 3.0) (3 != 4) (1 < 1.5) (3.0 >= 3) ('a = 'a) ('(1) = '(1)) ('(1) != '(2))
 ('x < "a") ("a" < 1) (1 < '(0)) !(1 < "a")          ; mint < string < number < chain
 ('(0) < {1 10}) ({1 10} < cap) !(cap < {1 10})       ; the map rung: chain < map < hot
 ("abc" < "abd") ("ab" < "abc") ('(1 2) < '(1 3))     ; text and chains are lexicographic
 ; a galaxy sits in the number band by its net (probed via sort: infix < on an array is a mask)
 ("(@(1 1) 5 @(2 4))" = show (sort [@(2 4) 5 @(1 1)]))   ; nets 2 < 5 < 6, galaxies interleaving with the star
 ("(3 @(1 2))" = show (sort [@(1 2) 3]))           ; net tie -> a star seats below a galaxy
 ("(@('a 'b) (7 8))" = show (sort [@('a 'b) '(7 8)]))    ; a tray sits below a chain
 (tray? @(5)) (tray? (@(5) = 5)))                     ; a one-cell array is an array: = with its scalar is a mask

; --- comparing functions --- `=` on functions is alpha + structural (binders by position, free
; vars by name, captures pairwise); eta/beta not bridged; a number never equals a closure.
; (x \ y) holds a free y, read under welp.
(hear welp)
(test
 ((x \ x) = (y \ y))
 ((a \ b \ a + b) = (x \ y \ x + y))
 ((x \ x + 1) = (x \ x + 1))
 ((x \ y \ x) != (x \ y \ y))
 ((x \ x) != (x \ y))
 ((x \ x + 1) != (x \ x + 2))
 ((a \ b \ a + b) @ g (g 1 = g 1 && g 1 != g 2))   ; closures: equal iff captures match
 ((+ 1) = (+ 1))
 ((+ 1.5) = (+ 1.5))
 ((+ 1.5) != (+ 2.5))
 ('(1.5) = '(1.5))
 ('(1.5) != '(2.5))
 (42 = (x \ x) 42)
 ?(_ \ 1) ?(_ \ 0))
(hear test-strict)

; --- reduction --- `=` stops at alpha (above); `ev` goes further -- it reduces. eta stays
; unbridged (its de Bruijn reduct shifts).
(test
 (5 = (x \ x) 5)                               ; beta_id: (\ x x) a ~> a
 (1 = ((_ \ 1) 9))                             ; beta_const: (\ _ 1) a ~> 1 (drops its arg)
 (5 = ((x \ x) ((x \ x) 5)))                   ; beta_nested: (\ x x) ((\ x x) a) ~>* a
 (10 = ((q \ (i \ 7 @ q (i + q)) q) 3))        ; a : binder shadowing the arg does not capture it
 (8  = ((q \ (i \ 5 @ i (i + q)) q) 3))        ; a : rebinding the param shadows it
 (99 = ((tuple \ tuple 1 2 3) (a \ b \ c \ 99))) ; a binder shadows a same-spelled macro (tuple)
 (5  = ((x \ 5) @ let (let 9)))                ; likewise for a : binder named like a macro
 (43 = ((p \ (: p (p + 1) p)) 42))             ; a : value binding shadows its name only after its right side is
 (2  = (1 @ v (: v (v + 1) v))))               ; evaluated, so that side reads the outer binding, a param or an enclosing :

; --- string answers a string --- the one total coercion: a charm is its byte (not its digits), a
; nom its spelling, a charlist its bytes, a cask a copy, () empty; the rest go through `show`
; (seal-hook 4, identity before post.l). only a string comes back identical.
(: (str? x) (string? (string x))
   (test
    ("A" = string 65) (1 = #(string 10)) ("hi" = string '(104 105))   ; the four spelled kinds
    ("abc" = string 'abc) ("" = string ())                                 ; and the empty charlist
    ("1.5" = string 1.5) ("-2.5" = string -2.5)                            ; ..the rest coerce
    (str? 1.5) (str? i) (str? (100 2)) (str? @(1 2 3)) (str? {1 2}) (str? cap) (str? out)
    (str? ()) (str? 0) (str? 'x) (str? "s") (str? @(0 0))                  ; every falsy shape too
    ("x" @ s (s = string s))                                           ; a string is the only identity
    (1.5 @ g (g != string g))
    ("1.5" = 2 string 1.5)))                                        ; ..so it is idempotent

; --- + and * are generic --- + adds numbers, joins strings, appends lists; `-` is numeric only.
; mixed bands degenerate: a number meets text or a chain as that band's unit. names are points: +
; is their join (the greater stands, () the bottom) and the identity against every other band;
; absent under *. `*` is repeated `+`; the count saturates.
(test
 ("abcd" = "ab" + "cd") ("x" = "x" + 66) ('ef = 'ef + 'ef) ('ef = 'ef + 'ab) ('ef = 'ab + 'ef) ("ab" = "ab" + 'ef)
 ('ef = 'ef + ()) ('ef = () + 'ef) ('ef = mint 0 + 'ef) ('ef = 'ef + mint 0)   ; () and a bare mint sit below every name
 (('ab + 'ab) + 'ef = 'ab + ('ab + 'ef)) (('ef + 'ab) + 'ab = 'ef + ('ab + 'ab))  ; associative on every triple
 ("x" = "x" + 66.0) ("x" = "x" + 1.5) ("x" = "x" + -66) ("x" = "x" + 256)   ; a number degenerates against text
 ('(1 2 3 4) = '(1 2) + '(3 4)) ('(1 2) = 5 + '(1 2))
 ('(3) = '(3) + ()) ('(3) = () + '(3)) ('(1 2) = '(1 2) + (mint 0))            ; () and a bare mint are +'s identity in every lane
 ("ab" = "ab" + ()) ("ab" = () + "ab") (5 = 5 + ()) (5 = () + 5)
 ((1 ~ 2) = () + (1 ~ 2)) ("@(1 2 3)" = show (() + @(1 2 3))) (() = () + ())
 ('(1 2) = 'ef + '(1 2)) (5 = 'ef + 5) (5 = 65 + 'ef + -60)                    ; so is a name, either side
 ("@(1 2)" = show ('ef + @(1 2))) ("@(1 2)" = show (@(1 2) + 'ef))
 ((x \ x) = () + (x \ x)) (2 = (((x \ x) + (x \ x)) (n \ n + 1) 0))            ; + on two hots is church add
 ("ababab" = "ab" * 3) (() = 'xy * 2) ('(1 2 1 2) = '(1 2) * 2) !("ab" * "cd") ; a name is absent under *
 ("ababab" = "ab" * -3) !("ab" * 2.5) !('(1 2) * 0)                            ; an exact count acts by magnitude; an inexact one is no count
 (() = () * 5) (() = 5 * ()) (() = "ab" * ()) (() = () * "ab")                 ; () is the zero: it annihilates *
 (() = '(1 2) * mint 0) (() = () * ()) (() = () * @(1 2 3))
 ("" = "ab" * 0) (() = () * (x \ x))                                           ; but the number 0 counts: zero copies, the kind's empty
 !("ab" * (3 ~ 4))                                                             ; a complex is no count either
 ("ab" * 3 = "ab" + "ab" + "ab")                                               ; the tie: s*n is s+s+..+s in each lane
 ('(1) * 3 = '(1) + '(1) + '(1)))

; --- () is absent to every numeric lane --- - / // % & | ^ << >> answer () on it, either side,
; not 0: absence propagates and stays falsy. + and * keep their band rules; = and < stay strict.
(test
 !(5 - ()) !(() - 5) !(() - 2.5) !((64 2) - ())         ; - : both sides, every width
 !(5 / ()) !(() / 5) !(5 // ()) !(5 % ()) !(() % 5)     ; / // %
 !(5 | ()) !(() & 5) !(5 ^ ()) !(5 << ()) !(() >> 5)    ; the bitwise lanes
 !((1 ~ 2) - ()) !(@(1 2 3) - ())                       ; complex + array propagate too
 !((5 - ()) - 3) !((- 5) ())                            ; chains poison; a partial fired with () answers ()
 !('ef - 3) !("a" - "b") !(('a - 'b) - 5)               ; undefined answers (), and it survives the chain
 (5 != ()) (() < 5))                                    ; = and < stay strict: () keeps the floor

; --- list*list is the cartesian product --- each pair a proper 2-list, so tally is a homomorphism
; and net is not. `*` is left-handed: a*b*c nests ((a b) c), so it is not associative on the nose.
; right distributivity holds exactly, left only up to permutation; () annihilates.
(test
 (('(1 2) * '(3 4)) = '((1 3) (1 4) (2 3) (2 4)))                ; every ordered pairing
 (('(1 2) * '(3 4) * '(5 6)) = '(((1 3) 5) ((1 3) 6) ((1 4) 5) ((1 4) 6) ((2 3) 5) ((2 3) 6) ((2 4) 5) ((2 4) 6)))  ; the left hand nests left
 (('(1 2) * ('(3 4) * '(5 6))) = '((1 (3 5)) (1 (3 6)) (1 (4 5)) (1 (4 6)) (2 (3 5)) (2 (3 6)) (2 (4 5)) (2 (4 6))))  ; parens buy the other shape
 (6 = #('(1 2) * '(3 4 5))) (#('(1 2) * '(3 4 5)) = #'(1 2) * #'(3 4 5))   ; tally is the homomorphism
 ((('(1 2) + '(8 9)) * '(3 4)) = (('(1 2) * '(3 4)) + ('(8 9) * '(3 4))))    ; right-distributive on the nose
 (!(('(1 2) * ('(3 4) + '(5 6))) = (('(1 2) * '(3 4)) + ('(1 2) * '(5 6)))))  ; left-distributivity fails as ordered lists,
 ((sort ('(1 2) * ('(3 4) + '(5 6)))) = (sort (('(1 2) * '(3 4)) + ('(1 2) * '(5 6)))))  ; ..but holds up to permutation
 ('(1 3) = <('(1 2) * '(3 4)))                                  ; pairs are real 2-lists
 (() = '(1 2) * ()) (() = () * '(3 4))                          ; () annihilates the cartesian too
 !("ab" * '(1 2)) !('(1 2) * "ab"))                            ; only chain*chain

; --- numeric functions --- abs int; constants e pi i; gcd modpow; the transcendental nifs are
; sine cosine log (log climbs tiers to the principal value). the rest derive: power is application,
; (k b) = b**k, sqrt ((/ 1 2) x), exp (x e), atan (arg (1 ~ x)); a negative base to a non-integer
; power goes principal, so ((/ 1 2) -1) = i.
(test
 (5 = (abs -5)) (charm? (abs -5)) (5.0 = (abs (3 ~ 4))) (2 = (int 2.9))
 ((abs -9223372036854775808) = 9223372036854775808)   ; |sun min| overflows the word
 (1024 = (10 2)) (21 = (gcd 1071 462)) (976371285 = (modpow 2 100 1000000007))
 (2.0 = ((1 / 2) 4)) (1 = (0 e)) (2.718281828459045 = e))

; --- a few identities --- exact claims only: euler in the exact direction ((log -1) = i * pi),
; the principal root on the nose.
(test
 (27 = (3 3)) (7625597484987 = (3 3 3)) (16 = (2 2 2)) (65536 = (2 2 2 2)) ; tetration
 (-1 = i * i) (-1 = (2 i)) (1 = ((i * 0) e))                               ; i^2 = -1; e^(i*0) = 1
 ((log -1) = i * pi) ((log i) = i * pi / 2)                                ; euler, in the exact direction
 (twin? (log -1)) (gem? (log 2)) (twin? (log (2 ~ 3)))                     ; log widens only when it must
 (i = ((1 / 2) -1)) ((0 ~ 2) = ((1 / 2) -4))                               ; sqrt of a negative: principal, exact
 (-8 = (3 -2)) (twin? ((1 / 3) -8))                                        ; integer powers stay real; odd roots go principal
 (0.0 = (sine 0) / (cosine 0)) (gem? (sine 0)))                            ; tan 0 = 0

; --- complex --- spaced (re ~ im) builds a twin at the tightest band; glued ~x conjugates (an
; involution); i = (0 ~ 1). a complex array packs (re,im) cells; its net is the complex sum.
; re/im/arg go elementwise: a real tray is its own re, its im zeros; an object tray reads ().
(test
 (i * i = -1) ((2 ~ 0) = 2) ((-5 ~ 10) = (1 ~ 2) * (3 ~ 4)) (twin? ~5) !(twin? 5)
 ((0 ~ 0) = ~0) ((conj (2 ~ 3)) = ~(2 ~ 3)) ((conj (2 ~ 3)) = (2 ~ -3)) ((2 ~ 3) = ~~(2 ~ 3))
 ((conj ((2 ~ 3) + (4 ~ 5))) = (conj (2 ~ 3)) + (conj (4 ~ 5)))
 ((conj ((2 ~ 3) * (4 ~ 5))) = (conj (2 ~ 3)) * (conj (4 ~ 5)))  ; ... and multiplicative
 (~8 = ~3 + ~5) ((0 ~ 0) < i) ((conj (2 ~ 3)) < (2 ~ 3))        ; reals embed; (re,im) order: 0<i, conj below
 (2.0 = re (2 ~ 3)) (i < 1) !(1 < i) ("(0.0 ~ 1.0)" = show i)
 (0.0 = (peep (arg (1 ~ @(1 0))) 1 0)))          ; arg broadcasts
(test
 (array 2 (1 ~ 2) (3 ~ 4) @ v (twin-tray = tier v && (1 ~ 2) = peep v 0 0 && (4 ~ 6) = net v
  && (2 ~ 4) = peep (v + v) 0 0 && (2 ~ 4) = peep ((2 ~ 0) * v) 0 0 && !(v < v)
  && $v = $(net v) && "@((1.0 ~ 2.0) (3.0 ~ 4.0))" = show v))
 ; phases sum as vectors; $ clamps re, never |z|
 (0 = $(array 2 (3 ~ 4) (-3 ~ 4)))
 (3 = $(array 2 (3 ~ 4) (0 ~ 0))) ((0.0 ~ 8.0) = (net (array 2 (3 ~ 4) (-3 ~ 4)))))
(test
 (twin (star-tray '(2 2) '(1 2 3 4)) (star-tray '(2 2) '(5 6 7 8)) @ m
  (aall (re m = star-tray '(2 2) '(1 2 3 4)) && aall (im m = star-tray '(2 2) '(5 6 7 8))
      && aall (m = twin (re m) (im m)) && '(2 2) = shape (re m)         ; the parts rebuild the whole
      && gem-tray = tier (re m) && gem-tray = tier (im m)))
 (aall ((re @(1 2 3)) = @(1 2 3))) (star-tray = (tier (re @(1 2 3))))     ; a real tray is its own re,
 (aall ((im @(1 2 3)) = @(0 0 0))) (star-tray = (tier (im @(1.5 2.5))))   ; and its im is 0, shaped
 ("@()" = show (re (twin-tray '(0) 0))) ("@()" = show (im @()))           ; an empty tray stays a tray
 !(re (top-tray '(2) 0)) !(im (top-tray '(2) 0)))                         ; an object tray is no number

; --- arrays --- (star-tray shape vals) typed ctor (vals 0 zero-fills; gem-/twin-/top-tray for r/c/o);
; (array shape elem..) infers; @(..) rank-1 literal; (iota n) 0..n-1. an array is rank >= 1 at any
; tally, so @(5) is an array; a rank-0 point is its scalar. empties stay arrays, carrying the units.
; + - * // < = and the bitwise five broadcast numpy-style (`/` goes r on one inexact cell); `=` and
; `<` answer 0/1 masks and aall/aany ask the whole question; a shape mismatch or a non-numeric
; operand reads 0. reduce net/prod/amax/amin/aall; inner (+.x), outer (o.x).
; the width law: the representation picks the regime, not the operator. a star's + - * // % grow
; exact; a z-tray's cells are machine words, so they wrap and a big truncates in. on a tray the
; bitwise five are the word lane and refuse a gem or object tray whole. an object tray boxes its
; cells, so a galaxy of bigs stays exact; a gem-tray saturates to infinity.
(test
 (6 = #(star-tray '(2 3) 0)) (2 = rank (star-tray '(2 3) 0)) ('(2 3) = shape (star-tray '(2 3) 0))
 (star-tray = (tier (star-tray '(2 3) 0))) (20 = (peep @(10 20 30) 1 -1)) (-1 = (peep @(10 20 30) 9 -1))
 (3 = (peep (star-tray '(2 2) '(1 2 3 4)) '(1 0) -1)) (@(11 22 33) = @(1 2 3) + @(10 20 30))
 (@(2 4 6) = @(1 2 3) * 2) (gem-tray = (tier ((star-tray '(2) 0) + 1.5))) (star-tray = (tier ((star-tray '(3) 0) < 1)))
 (60 = (net @(10 20 30))) (30 = (amax @(10 30 20))) (5 = (net 5)) (aall (1 < 2))
 (@(0 1 2) = (iota 3)) (star-tray = (tier (iota 3))) !(iota 0) !(iota -1) (4950 = (net (iota 100)))   ; iota: jot's range as a z-array
 (aall (@(2.0 3.0) = ((1 / 2) @(4.0 9.0)))) (@(3.5 5.5) = @(7 11) / 2) (@(3 5) = @(7 11) // 2)
 (@(4 6) = @(8 12) / 2) !(star-tray '(3) 0) ("@(10 20 30)" = show @(10 20 30))
 (aall (@(10 20 30) = (array 3 10 20 30))) !(@(1 2 3) + @(1 2))
 (0 = (@(1 2 3) = @(1 2))) (0 = ('sym = @(1 2 3))) (0 = ("ab" = @(1 2)))   ; a shape/kind mismatch is 0
 (aall (@(1 2 3) = @(1 2 3))) !(aall (@(1 2 3) = @(1 2 9)))                ; `=` is a mask; aall asks the whole question
 (tray? (@(1 2 3) = @(1 2 9))) (aany (@(1 2 3) = @(1 2 9)))
 (@(1 2) = (gem-tray '(2) '(1.0 2.0)))                                     ; ..across tiers, like (= 5 5.0)
 (0 = (net (star-tray '(0) 0))) (1 = (prod (star-tray '(0) 0))) (aall (star-tray '(0) 0))
 ("@()" = show (star-tray '(0) 0)) (0 = #((star-tray '(0) 0) + 1))
 (32 = (inner @(1 2 3) @(4 5 6))) (star-tray = (tier (outer @(1 2) @(3 4))))   ; +.x dot; o.x outer
 ; the width law: a galaxy's cells are machine words, so its arithmetic wraps
 (@(8 9) = (@(3 4) + ((200 2) + 5)))              ; a big truncates into the cell
 (star-tray = (tier (@(3 4) + (200 2))))          ; ..and never leaves the tray band
 (sun? (3 + (200 2)))                             ; the star lane grows exact instead
 (array '(2) (200 2) (200 2) @ o                  ; ..as does an object tray
  (aall (o = ((o + (array '(2) 1 1)) - (array '(2) 1 1)))))
 (word ? ("@(infinity infinity)" = show (@(1.0e308 1.0e308) * @(10.0 10.0))) 1)    ; a gem-tray saturates, never wraps
 (word ? (@(-9223372036854775808 0) = (@(9223372036854775807 0) + @(1 0))) 1)   ; max+1 -> min
 (word ? (@(9223372036854775807 0) = (@(-9223372036854775808 0) - @(1 0))) 1)   ; ...min-1 -> max
 ; the bitwise five broadcast too -- the word lane, elementwise
 (@(240 19) = (@(255 16) ^ @(15 3))) (@(15 0) = (@(255 16) & @(15 3))) (@(12 6) = (@(8 4) | @(4 2)))
 (@(8 16 24) = (@(1 2 3) << 3)) (@(4 -4) = (@(8 -8) >> 1))       ; >> stays arithmetic per cell
 (@(240 252) = (255 ^ @(15 3))) (@(2 16) = (@(1 1) << @(1 4)))   ; a star broadcasts; counts can be per-cell
 !(@(5 6) | ())                                                  ; ..and () is absent here too
 (() = (@(1.5 2.5) ^ @(1 1)))                                    ; a gem tray is not the word lane
 (() = ((array '(2) (200 2) (200 2)) & @(255 255)))              ; ..nor an object tray
 (@(1 3 5 7 9) @ m (aall (@(0 1 1 1 0) = ((m > 2) & (m < 8)))))  ; masks combine
 (inner (star-tray '(2 3) '(1 2 3 4 5 6)) (star-tray '(3 2) '(7 8 9 10 11 12)) @ M    ; 2x2 matmul
  (('(2 2) = (shape M)) && 154 = (peep M '(1 1) 0))) !(inner @(1 2 3) @(1 2))
 ; a tray is immutable: pin answers a fresh one
 (@(1 9 3) = (pin @(1 2 3) 1 9)) (@(1 2 3) @ v (pin v 1 9, @(1 2 3) = v))
 (@(7.0 2.5) = (pin @(1.5 2.5) 0 7))                       ; the value converts to the tray's tier
 (@(1 2 3) = (pin @(1 2 3) 1 'x)) (@(1 2 3) = (pin @(1 2 3) 9 5))   ; a non-number or a miss is the no-op
 (star-tray '(2 2) '(1 2 3 4) @ m (9 = (peep (pin m '(1 0) 9) '(1 0) 0))))     ; the shape-list key writes where it reads

; --- chains & lists --- link builds; cap/cup project (caap..cuuup compound); (long? n l) asks for
; at least n links in one walk; sort/sortby by the total order; (jot n) the first n charms. applying
; a chain: a charm indexes (out of range, a negative included, is ()), a chain appends (agreeing
; with +), any other operand answers ().
(test
 (1 = (cap '(1 2 3))) ('(2 3) = (cup '(1 2 3))) (3 = (caup '(2 3 4))) ('(1 2) = (. 1 (. 2 ())))
 !(cap 0) ("x" = (string 'x)) !(two? 'x)          ; no cap at the end; a symbol is not a chain
 (long? 3 '(1 2 3)) !(long? 4 '(1 2 3)) ((long? 1 '(1 2)) = (two? '(1 2))) ((long? 1 'x) = (two? 'x))
 (long? 0 'x) !(long? 1 ()) !(long? 2 "ab") !(long? 'a '(1 2))  ; at zero nothing is claimed; a non-charm count never answers
 ('(0 1 2) = (jot 3)) !(jot 0) (3 = $(jot 3)) ; the empty count is nothing
 ('(2 3 4) = (map (+ 1) '(1 2 3))) (24 = (foldl (*) 1 '(1 2 3 4))) (6 = (foldr (+) 0 '(1 2 3)))
 ('(1 3) = (filter (x \ x % 2) '(1 2 3 4))) ('(1 2 3) = (sort '(3 1 2))) ('(3 2 1) = (sortby (>) '(1 2 3)))
 ('(1 2 3 4) = (cat '(1 2) '(3 4))) ('(3 2 1) = (rev '(1 2 3))) ('(1 2) = (map cap (zip '(1 2) '(3 4))))
 (20 = <>(assoc 2 [[1 10] [2 20]])) ('(1 2) = (take 2 '(1 2 3 4))) ('(3 4) = (drop 2 '(1 2 3 4)))
 (3 = (last '(1 2 3))) ('(1 2) = (init '(1 2 3))) (elem 3 '(1 2 3)) !(elem 9 '(1 2 3))
 (all (x \ 0 < x) '(1 2 3)) (any (x \ 2 < x) '(1 2 3))
 (7 = ('(7 8 9) 0)) (9 = ('(7 8 9) 2)) !('(7 8 9) -1) !('(7 8 9) 9)   ; a charm indexes; a negative is out of range
 !('(7 8 9) 3) !('(7 8 9) -4) !('(7 8 9) 'x) !('(7 8 9) ())        ; out of range, and every non-index operand, is ()
 ('(1 2 3 4) = ('(1 2) '(3 4))) (('(1 2) '(3 4)) = '(1 2) + '(3 4))              ; a chain juxtaposes: the append, agreeing with +
 ('(1 2 3 4 5) = ('(1 2) '(3 4) '(5)))                                           ; ..and it curries, as text does
 ('(1 X 3) = (pin '(1 2 3) 1 'X)) ('(1 2 3) @ l (pin l 1 'X, '(1 2 3) = l))      ; pin answers a fresh spine
 ('(1 2 3) = (pin '(1 2 3) 3 'X)) ('(1 2 3) = (pin '(1 2 3) -1 'X))              ; out of range is the no-op
 (pin (. 1 2) 0 'X @ p ('X = <p && 2 = >p))                                   ; an improper tail rides too
 (294 = $'(a b c)) (3 = #'(a b c)))         ; net sums spellings; tally counts the spine

; --- strings, symbols & mints --- a symbol is interned by name or anonymous, equal only to itself:
; nom? asks, name? and mint? split it by spelling. (mint 0) is a fresh anonymous one, netting 0, the
; gensym a macro expands through. () is the one true nothing: a serial-0 mint by representation but
; no symbol -- it binds nothing and nom? declines it. a string indexes by a charm (out of range is
; ()) and juxtaposes with a string: (s t) is s + t, curried. a missing read answers () under welp.
(hear welp)
(test (zz-never-pinned @ z (!(nom? z) && !z && z = (:) && "()" = show z)))     ; absence: the zero point, wearing ()
(hear test-strict)
(test
 (() = (:)) !(nom? ()) !(name? ()) !(mint? ()) (0 != ()) (() = (intern "")) (0 = $()) !() !!$'x
 ("()" = show ())
 (nom? (mint 0)) !(name? (mint 0)) (mint? (mint 0)) (0 = $(mint 0)) !(mint 0)   ; nom? but not name?, materially empty
 ; name? and mint? partition nom? (() is neither); string can't tell them apart (a mint spells "")
 (: m (mint 0) s (nom "x")
    (mint? m && !(name? m) && name? s && !(mint? s)))
 (!(mint? 'x) && !(mint? "x") && !(mint? 0) && !(mint? '(1 2)))
 ("" = string (mint 0) && "" = string ())                                   ; the anonymous ones spell empty
 (mint 0 @ m (m = m 5)) ('xyz = ('xyz 1))                                           ; a point applied answers itself
 ((mint 0) != (mint 0)) (mint 0 @ m (m = m))                                        ; distinct always; itself only
 (nom? (nom "x")) (name? (nom "x")) !(mint? (nom "x")) (name? 'x) !(two? (nom "x")) ; `nom` interns: an atom, never a chain
 ('x = (nom "x")) ('x = (nom 'x)) ('x = (2 nom "x"))                                ; an idempotent projection
 ((mint 0) < 'x)                                                                    ; an anonymous one below a spelled one
 ((mint 0) < 0)                                                                     ; every symbol sits below the numbers
 (: a (mint 0) b (mint 0) t {} (pin t a 1, pin t b 2,
                                        1 = t a && 2 = t b && 2 = #t)) ; distinct mints are distinct map keys
 (97 = ("abc" 0)) (294 = $"abc") (3 = #"abc") (4 = $3.9) (0 = $-3.9) (5.0 = (abs @(3 4)))
 !(string 0) !!(string 1) (1 = #(string 0))          ; a NUL nets nothing, but (string 0) holds one byte
 !(snip ("a" + 0) 1 2) (97 = $("a" + 0))        ; ..an all-NUL text is nothing
 ("bidden" = (snip "forbidden planet" 3 9)) !("hi" 9)
 ; an empty answer keeps its kind; only a non-text input answers 0
 ("" = (snip "abc" 1 1)) ("" = (snip "" 0 5)) (0 = (snip 0 0 5))
 ("" = "" + "") ("" = (string ())) ("" = (string ""))
 ("" = slurp (jug 0)) ("" = slurp (tap ())) ("" = slurp 42)
 ("" = (puts "")) (0 = (puts 0))                                                           ; an empty operand writes nothing, answering itself
 ("abcd" = ("ab" "cd")) ("abcdef" = ("ab" "cd" "ef")) (: a "ab" b "cd" ((a b) = (a + b)))  ; juxtaposition joins text, curried
 !("abc" -1) !("abc" -3) !("abc" 3)                                                        ; a negative index is out of range
 ("aXcd" = (pin "abcd" 1 88)) ("abcd" @ s (pin s 1 88, "abcd" = s))                        ; pin answers a fresh text
 ("abcd" = (pin "abcd" 9 88)) ("abcd" = (pin "abcd" -1 88)) ("abcd" = (pin "abcd" 1 'x))   ; out of range or a non-byte is the no-op
 ("ab" = ("ab" "")) ("ab" = ("" "ab")) ("" = ("" "")) ("abcd" = ("ab" 'cd)) !("ab" '(1 2)) ; "" is the unit; a point is text; a non-text operand is ()
 ('asdf = (intern "asdf")) !((mint 0) = (mint 0)) ("asdf" = (string 'asdf))
 ('xy = (intern (string 'xy)))                   ; intern . string is the identity on a name
 ("\"a\\nb\"" = show "a\nb"))

; --- hashes --- {k v ..}/(hash ..) build; {} the empty map; {x} boxes a datum. peep/pin/pull are
; collection-first; pull removes the key. (t k) is (peep t k ()). peep with a fresh (mint 0) default
; is the total presence test. pin writes in place where there is a cell (tablet, cask) and answers
; a fresh copy otherwise (text, chain, tray); a scalar has no cell, so pin leaves it.
(test
 (50 = (peep (pin {} 5 50) 5 0)) (99 = (peep (pin "abc" 1 99) 1 0))            ; the pin law, mutable and not
 (9 = (peep (pin '(1 2 3) 2 9) 2 0)) (9 = (peep (pin @(1 2 3) 0 9) 0 0))
 (5 = (pin 5 0 1)) (1.5 = (pin 1.5 0 1))         ; the scalar exception
 ({0} @ b (tablet? b && 1 = $b && 0 = peep b () 9 && (pin b () 7, 7 = b ())))
 (tablet? {}) (0 = #{}) (? {})                    ; {} is the empty map: 0 keys, truthy
 ({1 10 2 20} @ t (20 = peep t 2 0 && 20 = t 2 && 99 = peep t 9 99))
 (: t {1 0} s (mint 0) (!(s = peep t 1 s) && s = peep t 9 s))              ; a pinned 0 is present, an absent key is not
 ({1 10 2 20} @ t (pull t 1 0, 1 = #t))
 (: t {1 10 2 20} v (pull t 2 0) (20 = v && 1 = #t && 99 = peep t 2 99 && -1 = pull t 9 -1))   ; pull: value or default, removes the key
 ('(1 2) = (sort (keys {1 10 2 20}))) ((dig 'k) = (dig 'k)) !(tablet? 5)
 ({1 10} != {1 10}) ({1 10} @ t (t = t))         ; mutable: identity =
 (: t {} r (pins t 1 10 2 20) (r = t && 10 = t 1 && 20 = t 2 && 2 = #t))          ; pins: multi-pin onto a live tablet, answering it
 (pins {} 1 10 2 @ t (10 = t 1 && 1 = #t)))                    ; an odd trailing key is dropped

; --- the empty spellings --- () "" @() {} (0 ~ 0) (cask 0) all net 0 and are false, but {} (a
; tablet nets 1). @0/{0} wrap the value 0: present, parted from the empties by tally.
(test
 !@() !(cask 0)               ; every empty is false but {}
 (() != 0)                                       ; () and 0 are distinct
 ("@()" = show @()) (1 = rank @()) (0 = #@()) (star-tray = tier @())               ; @() round-trips
 ("{}" = show {})      ; {} round-trips
 (tray? @0) (tray? (0 = @0)) (1 = rank @0) (1 = #@0)     ; @0 is a one-cell array
 ("@(0)" = show @0) (0 = peep @0 0 -1)                  ; ...which shows and reads back as one
 (tablet? {0}) (1 = ${0}) !!{0})                       ; {0} is a box, present

; --- buffers --- (cask n) zeroed mutable bytes; (cask charlist) holds those bytes, the bulk way
; in; peep/pin a byte 0..255; `$` nets the bytes; pour; identity =.
(test
 (cask 3 @ b (pin b 0 65, 65 = peep b 0 0)) (0 = $(cask 4)) (4 = #(cask 4))
 !(cask 3) (65 = (cask 1 @ b (pin b 0 65, $b)))     ; zeroed is nothing; bytes are charms
 (cask 1 @ b (pin b 0 257, 1 = (peep b 0 0))) (cask 4 @ b (pour b 0 "ABCD" 0 4, 68 = (peep b 3 0)))
 (cask 1 @ b (pin b 0 "x", 0 = (peep b 0 -1)))       ; a byte pin takes only a charm
 (cask 1 @ b (b = pin b 0 65))                       ; a cask pins in place
 (cask '(200 65 0 255) @ b (4 = #b && 200 = peep b 0 0 && 255 = peep b 3 0))     ; high bytes and an embedded NUL ride
 (cask '(65 66) @ b ("AB" = string b))              ; ..and read back as those bytes
 ("" = (cask ())) ("" = (cask 0))                   ; no empty cask: both empties are ""
 ((cask 2) != (cask 2)))

; --- reader operators --- the reader is structural and environment-free: tokens, parens, strings,
; ' quote, ` list, @ tup. [..] is `(..), {..} the map; the closers ) ] } are one (libra catches a
; crossed pair). a constructor sigil over a form renames its wrap (@[1 2] is @(1 2)); ' and \ are
; not constructors, they quote the next datum. a name token (alnum/_) keeps - ? ! and the prime
; inside; a punctuation run is a sigil, plain when spaced, (mono (run datum)) when glued. `opfix`
; factors sigils against the `operators` table by arity: 0 glued, 2 spaced, -1 spaced unbounded; a
; miss takes the default band, right-handed. (grip ar nm v) pins a row and answers the one it
; replaced, () clears; the table is read live.
; a spaced sigil is one whole name (!= && >>= never split). juxtaposition binds tighter than
; infix; equal bands nest by hand, arithmetic left and the rest right. a glued run splits greedily
; and is monadic, a spaced one dyadic, head included; only : ? \ stay the head operator. a digit or
; . after + - starts a numeral. the monadics: < cap, > cup, + net, * prod, | abs, - negate,
; / reciprocal, % fraction, ? bit, $ sat, ! nil?, # tally, ~ conj. the curry law folds missing
; trailing operands to a partial. commas split a list into clauses run in order, the last
; answering, empties dropped.
(test
 ('(1 (\ x) 3) = [1 ''x 3]) ('(1 2 3 4) = ('(2 3) @ xs ('(1) + xs + '(4))))
 (532 = $"hello") (5 = (tally "hello")) (42 = $42)
 (i = (0 ~ 1)) ((2 ~ 3) = (twin 2 3)) ('~x = '(mono (~ x))) (~5 = (conj 5)) (5 = #"hello") (lit? dot)
 ("(# x)" = (show (opfix '(# x)))) ('! = (caup '(a ! b)))                      ; a monadic-only sigil has no row: opfix hands the plain symbol on
 (: was (grip 2 '^ -60) t (opfix '(a ^= b)) back (grip 2 '^ was)               ; a spaced sigil is one whole
    (back = -60 && t = '(^= a b)))                                             ; name: ^'s row never splits ^=
 (6 = ((x' \ x' + 1) 5)) (nom? 'ab') (7 = (7 @ n' n'))                         ; the prime: x' is a name; leading ' is still quote
 (5 = --5) (5 = ++5) (-5 = ---5) (5 @ x (-5 = -x))                             ; + and - are runs: --5 is -(-5)
 (-3 = -3) (-0.5 = -.5) (5 = (2 - -3))                                         ; ..but a digit or . after them starts a numeral
 ('(1 2 3) = [1 2 3]) ([] = (list)) (1 = ({'a 1} 'a))                           ; [ is list, { is the map
 ('((1 2) (3 4)) = [[1 2] [3 4]]) ('(mono (- (list 1 2))) = '-[1 2])                             ; ..to any depth
 ((show <(sound "{'a 1}")) = (show '(hash 'a 1)))                              ; a hash compares by identity, so the law is on the form
 (@[1 2 3] = @(1 2 3))                                       ; a constructor sigil renames the wrap
 ('(\ (list a b)) = <(sound "'[a b]"))                                         ; ..but ' quotes the form
 (7 = 1 + 2 * 3) (1 < 2 ? 'big) ('small = (2 < 1 ? 'big 'small))   ; ? is dyadic: infix takes one arm; with an else arm it is the prefix cond
 (-4 = 1 - 2 - 3) (1 = 8 / 4 / 2)                                              ; the left hand
 (: was (grip 2 '<+> -60) t (opfix '(a <+> b <+> c)) (grip 2 '<+> was,         ; the grip door,
                                                      was = () && t = '(<+> (<+> a b) c))) ; restored inside the form
 ('(1 2 3) = 1 . 2 . '(3))                                                     ; ..a right-handed band still folds right
 ((1 . 2) = (. 1 2)) ("(1 . 2)" = (show (1 . 2)))                              ; infix . is (. a b),
 ((1 . 2) @ (a . b) (a = 1 && b = 2) _ 0)                                      ; valid in a pattern too
 ((1 . 2 . 3) = (. 1 (. 2 3))) (3 = tally '(1 . 2))                              ; a quoted one is data: a 3-list
 ("(1 . 2 . 3)" = show (1 . 2 . 3)) ("(1 . 0)" = show (1 . 0))                ; prints all-dot; a 0 tail stays a tail
 ((1 . 2 . 3) = ev <(sound (show (1 . 2 . 3)))) ("(1 2 3)" = show [1 2 3])     ; ..and reads back as itself
 (3 = abs -3) (66 = (2 + 3 4))                   ; application binds tighter than infix
 (1 = (3 != 4)) (0 = (3 != 3)) (opfix '(a != b && c) @ t (t = '(&& (!= a b) c)))    ; != is a dyad at the comparison band;
 (grip 2 '! () @ was (grip 2 '! was, was = ()))       ; ! has no row, so
 ("(! x)" = (show (opfix '(! x)))) ((!) = nil?)     ; the walk hands it on as a function
 (1 = (! 0)) (0 = (! 5)) (1 = (! ""))
 (197 = ($"ab" + 2))                             ; glued binds tightest
 (3 = ((1 +) 2))                                 ; the curry law
 (1 = <'(1 2 3)) (2 = <>'(1 2 3)) ('(3) = >>'(1 2 3))   ; glued runs are monadic
 (6 = +'(1 2 3)) (24 = *'(1 2 3 4))     ; the net, unclamped
 (5 = |-5) (-3 = -(1 + 2)) (0.25 = /4) (1 = ?7) (0 = ?"")
 (3 = (1 + 2)) (1 = ((< 5) 9))                            ; spaced head = prefix call; the section
 (0 = ('(to 0) @ mr (<mr = 'lin))) (3 = (:(1 + 2)))       ; a glued head fuses; : cannot factor, so it falls back
 ('(mono (< x)) = (caup <(sound '(40 102 32 60 120 41)))) ; the emission, as data
 (7 = (+ 1 2, + 3 4)) (3 = (1 ,, 3, )) (7 = (, 6 7))      ; the comma layer
 (12 = (foldl (+) 0 '(3 4 5))))

; --- macros --- a macro maps an arg list to code; install with `::`. no quasiquote: the list
; ctor evaluates every element, so quote the literal positions. a macro expands at zero operands
; too: (list) is (), [] is (list).
(:: 'unless (a \ ['? <a 0 <>a]))
(test
 ('ok = (unless 0 'ok)) (0 = (unless 1 'ok)) (3 = (&& 1 2 3)) !(&& 1 0 3)
 ; a connective answers one of its operands: && the first falsy, || the first truthy, else the last
 ((() && 5) = ()) ((&& 1 0 3) = 0) ((() || ()) = ()) ((() || 0) = 0)
 ((-1 && 5) = -1) ((5 && -1) = -1) ((5 && 0) = 0) ((0 || -1) = -1)
 (2 = (|| 0 2 3)) ('(1 2 3) = [1 2 3]) (6 = (do 1 2 6)) (3 = (let a 1 b 2 (a + b)))
 (1 = (quote 1)) ('a = (quote a))                                  ; quote, the macro spelling of '
 (3 = (:- (a + b) a 1 b 2)) ('big = (?- 'else (1 < 2) 'big))
 ('(3 b) = (:- (go '((1 a) (3 b))) (go (e . u)) (<e @ 3 e (go u))))   ; a pattern binder under the rotation
 ('two = (2 @- 'else 2 'two)) ('else = (9 @- 'else 2 'two))   ; @- fronts the fallthrough
 (() = (list)) (tray? (tuple)) (tablet? (hash)) (() = (unless)))     ; the zero-operand macro

; --- control --- ev compiles and runs; call-cc is a one-shot escape. tasks: (twirl f x) forks to
; an id, (catch p) blocks for its result, (rest 0) yields, `scoop` collects any finished orphan as
; (pid . retval) or (); myself is the running task's id, () for the root. the RNG is xoshiro256++:
; functional seed/random and global rand/randf ((rng-set (wheel n)) pins it).
; (hear f) installs the help, which takes every raise as (help a b); `welp` answers the zero point.
; a missing name raises (scare 'missing nom), at a closure's define, not its call. (trap f x n)
; answers (f x), or (n a b) on a scare; nothing unwinds, so cleanup goes in n or `mind`: (mind f x c)
; fires c on the way out either way and lets the condition ride on. a bare (k v) skips every c.
; numeral compose counts and the power lane's result size are capped by the `apcap` box.
(test
 (3 = (ev '(+ 1 2))) (lit? ev) (41 = call-cc (k \ k 41)) (42 = 1 + call-cc (k \ 41))
 ('(boom 7) = trap (_ \ scare 'boom 7) () (a \ b \ [a b])) (3 = (trap (+ 1) 2 welp))
 (: t {} _ (pin t 0 'held)                                    ; mind: c fires, f's value answers
    v (mind (_ \ 'value) () (_ \ pin t 0 'freed))
    (v = 'value && t 0 = 'freed))
 (: t {} _ (pin t 0 'held)                                    ; ..on the raised path too,
    r (trap (_ \ mind (_ \ scare 'boom 7) () (_ \ pin t 0 'freed)) () (a \ b \ a))
    (r = 'boom && t 0 = 'freed))                              ; ..the condition riding on
 (42 = (twirl (x \ do (rest 0) (x + 1)) 41 @ p (catch p))) (0 = (catch 99999)) (landed? 99999)
 !(myself ())                                                 ; nobody twirled the root task
 (twirl (_ \ myself ()) () @ p (p = (catch p)))               ; a child knows its own id
 !(rest 0) ((rand 10) < 10) (gem? (randf 0))
 (lit? scare)
 (wheel 7 @ st (<(random st 0) = <(random st 0))))               ; the functional layer is reproducible
; a missing name reads the zero point under welp
(hear welp)
(test ((:) = not-in-the-book) !not-in-the-book)
(hear test-strict)

; --- i/o & ports --- in/b/err the default ports, per task: (wear (i o e)) re-seats them, (wear ())
; the console, (worn ()) asks; getc putc puts putn putx; see/put per port. (tap cl) reads a colist,
; (jug 0) is a growable output port; (see o) draws a unit, (flow o) a lazy charlist, (slurp o) drains.
; `sound` reads one datum from a port, string or charlist and answers (datum . rest), () at a clean
; end, or `torn` mid-shape: ask two?, never the net, since a datum may be (). the rest is a charlist,
; so a torn read resumes with more text. a buffered fd port gives one 4096-byte run per gulp, an
; unbuffered one a byte per force. a flowing port's tail is a promise: a cons is more, () the end,
; anything else a thunk to fire with the unit. (once f) runs f at most once and remembers.
; read/reads/forms ride sound; `dot` prints x and answers it.
(test
 (string? (show out)) ("hi" = slurp (tap '(104 105))) (jug 0 @ o (print o 42, "42" = slurp o))
 (: a (jug 0) b (jug 0) (say a "a", say b "b", "a" = slurp a && "b" = slurp b))                 ; two jugs are two sinks
 (1 = <(sound '(49))) !(sound ()) ('torn = sound '(40))
 (sound '(49 32 50) @ r (2 = <(sound >r)))           ; the residue reads the next datum
 (sound '(40 41) @ r (two? r && !<r))                ; ..and the datum () is still a datum
 (sound (flow (tap '(40 49 32 50 41))) @ r ('(1 2) = <r))     ; a port reads as its charlist
 (sound (tap '(40 49 32 50 41)) @ r ('(1 2) = <r))            ; ..and sound lifts one itself
 (: p (tap '(49 32 50)) r (sound p) (2 = <(sound >r)))        ; the residue carries the rest of the port
 (sound "(1 2) 3" @ r ('(1 2) = <r && 3 = <(sound >r)))              ; a string is spread at the door
 !(sound "") ('torn = sound "(1") !(sound 42)                        ; ..and reads the same three ways
 (: c {} th (once (u \ peep c 0 0 @ k (pin c 0 (k + 1), k)))
    ((th ()) = th () && 1 = peep c 0 0))            ; a promise forces once and remembers
 ('(mono (# (a))) = <(sound '(35 40 97 41))))       ; #(a) is the glued tally run

; --- bootstrapping --- `born` is the start cost in ms (hatch or wake), unbound pre-egg. ask
; presence (hatched), never born's net: a fast wake answers 0, which would read as pre-egg and pass
; every law vacuously.
(: hatched (elem 'born (names ())))
(hear welp)
(test (hatched ? (charm? born) 1))
(hear test-strict)

; --- modules --- the runtime opens a layer around each module load and the session. (borrow 'x)
; splices a registered module below the top (never shadowing the top's names), loading lib/<x>.l
; on a miss; a string is a path; 'x/y includes lib/x/y.l into the head. (cite 'name) is the
; module's tablet (a missing one answers (), so lit? is the presence test); (cite ()) lists names.
(test
  (lit? (cite 'uu)) (lit? (cite 'kanren))                      ; boot-loaded, registered
  (elem 'kanren (cite ())) (elem 'uu (cite ()))          ; listed
  !(cite 'spec-nope)                                            ; the presence guard
  (tablet? (cite 'kanren))                                      ; a module is its tablet
  (elem 'walk (keys (cite 'kanren)))                         ; so `keys` introspects it
  (8 = (cite 'kanren 'subst '(()) 8))                           ; curried member reach
  !(cite 'kanren 'spec-missing)                                 ; a member miss reads ()
  (lit? unify) (lit? rand) (lit? reads))                        ; the boot splices serve the bare names

; (module 'nm form ..) defines without a file: it opens nm's layer (the registered tablet on a
; reopen), evals each form there, registers, and answers the tablet; (module () ..) registers nowhere.
(: smv-out (elem 'smv (names ()))                     ; captured first: love0 reruns the corpus in-process
   m1 (module 'spec-mod (: smv 41 (smf x) (x + smv)))
   m2 (module 'spec-mod (: smv (smv + 1) smw 100))       ; reopen: the old member is in scope
   ma (module () (: sma 9))
 (test
  (tablet? m1) (m1 = m2) (m1 = cite 'spec-mod)           ; one tablet, registered, answered
  (42 = cite 'spec-mod 'smv) (100 = cite 'spec-mod 'smw) ; the reopen read 41 and extended
  (42 = (cite 'spec-mod 'smf 1))                         ; smf folded smv at its compile
  (smv-out = elem 'smv (names ()))                    ; no leak
  (nelem 'sma (names ()))                             ; the anonymous layer leaks nothing
  (tablet? ma)))
; borrow is its own form: a group compiles whole, so a read of smv beside it would come first
(: _ (borrow 'spec-mod))
(test (42 = smv))
; a module's forms eval one by one, never chained as an application: smt stays empty. the probe is
; its own form since smf2 compiles in the module's layer, where smt is unaddressable.
(: smt {})
((module () (: (smf2 x) (pin smt 'called 1)) (: smq2 2)) @ mq
 (test !(smt 'called)                                  ; nothing applied smf2
         (elem 'smq2 (keys mq))))                     ; ..and both forms landed

; --- odds & ends --- show renders a reparsable form; an opaque handle is a constant function.
(test (string? (show @(1 2 3))) !(cask 4 'x))
