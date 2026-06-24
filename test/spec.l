; ai spec -- the executable semantic spec: every claim assert-backed, on every target.
; the prose narrative, working notes, and runnable demonstrations live in CLAUDE.md; this
; is the TEST half. it runs in the corpus SECOND (common.mk, right after test/00-init.l sets
; up the assert harness), so keep it green -- `make test` (host + ai0, which must print the
; zz-fin summary twice). when in doubt, PROBE THE BINARY: never trust a prior over a one-line
; experiment. the section order and headers mirror CLAUDE.md, where each law is explained.

; --- everything is a function --- (f x y) == ((f x) y), (f) == f; numbers are church
; numerals; data self-applies. asserts read INFIX, folding right-associatively (sound by (f) == f).
(assert
 (1 = (0 5)) (5 = (1 5))                         ; 0 is const-1, 1 is the identity
 (1 = (0 0)) (7 = (0 0 7))                       ; const of const is the identity: (0 0 x) = ((0 0) x) = (1 x) = x
 (8 = (3 2)) (262144 = (2 3 4))                  ; (n x) = x**n; the tower (2 3 4) = 4**(3**2)
 (12 = (3 (+ 1) 9)) ('(2 3 4) = (map (+ 1) '(1 2 3)))  ; (n f) composes f ($ n) times; currying *is* partial application
 (10 = (-3 (+ 1) 10)) (13 = (2.5 (+ 1) 10))      ; the count SATURATES, true to !!$: (-3 f) = (0 f) = 1; a float ceils
 (0.5 = (-1 2)) (3.0 = ((/ 1 2) 9)))             ; ... but exponents don't: (-1 x) = 1/x; (1/2 x) = sqrt x

; --- three special forms --- `:` letrec*/sequence, `?` cond, `\` lambda (one operand: quote).
; a body-having `:` is ONE SCOPE; an empty special form reads its head (the zero point).
(assert
 (3 = (: a 1 b 2 (a + b)))                       ; `:` binds in source order; the last form is the result
 (7 = ((\ x y (x + y)) 3 4))                     ; `\ args.. body` -- a lambda, auto-curried
 ('(1 2) = (\ (1 2)))                            ; one operand: `\` is quote, so 'x is just (\ x)
 ('big = (? 0 'a (1 < 2) 'big 'else)))           ; `?` -- test/result pairs, then a final else
(: (twice f x) (f (f x)) (assert (12 = (twice (+ 1) 10))))
(assert
 (id? (:) (?)) (id? (?) (\)) !(:) !(nom? (:))     ; the empty form is the head read, both lanes: the zero point (absence, NOT a nom)
 (id? (:) (? 0 'a)) (id? (:) (map (+ 1) ()))     ; a no-match `?` (and `map` of nothing) falls to the zero point () (= the empty form (:)), NOT fixnum 0
 (id? (:) (: a b b 2 a)) (2 = (: a b b 2 b))     ; one scope: forward read = the condition, the point helpless
 (2 = (: x 1 x (x + 1) x)))                      ; ... the sequence law is untouched

; --- true and false --- false is *nothing*: whatever NETS <= 0 (a complex-valued measure --
; numbers their value, text its charm sum, lists the sum of element nets). `!` (nil?) reads
; the net's sign in the total order; `$` (sat) is one saturating clamp, max(0, ceil); !x == (0 = $x).
(assert
 !0 !"" !(tablet 0) !@0 !() !0.0 !~(0 0)         ; zero / empty -> false
 !-5 !-3.9 !~(-3 4) !~(0 -1)                     ; <= 0 in the total order -> false (complex by re then im)
 !!5 !!"x" !!'a !!cap !!i !!~(3 -4)              ; positive / nonempty -> true
 !'(() ()) !'(0 0) !'((0) (())) (0 = $'(() () ()))  ; a chain of nothings is nothing, recursively
 !'(-5) !@(-3 -4) !'(-2 1) !!'(0 1)              ; negatives net <= 0 at every rank; -2+1 < 0 < 0+1
 (3 = $'(1 () 2)) (6 = $'(1 2 3)) (7 = $@(3 4))  ; $ sums the nets, then clamps once
 (1 = $(link 1 2)) !(link 0 2)                   ; the SPINE carries the measure: a dotted tail is not an element
 (8 = $`(~(3 4) ~(-3 4))) !`(~(0 5) -1)        ; phases sum as vectors; the order signs the TOTAL, once
 (1 = $#0) !!#0                                  ; ... but a box stays truthy: maps count keys
 (1 = $'(1)) (0 = $'(0)) (0 = $0) (-1 = +'(-2 1))  ; the COLORS by net-sign: '(1) green, '(0)/0 blue, '(-2 1) red
 (1 = !!$5) (0 = !!$0) (0 = !!$-3)               ; !!$ is the truth bit (1 true, 0 false)
 (0 = !5) (1 = !0) (id? zero? nil?) (1 = (nil? 0))  ; ! negates it; non is nil?
 (star? 5) (star? -3.5) (star? ~(2 3)) (star? (62 2))         ; a STAR is a self-netting SCALAR: charm, float, complex, wide
 !(star? @(1 2 3)) (star? (net @(1 2 3)))                   ; a SET is NOT a star -- it nets DOWN to a scalar star (net is a fresh sum)
 !(star? "x") !(star? 'a) !(star? '(1 2))                    ; text/symbol/list are not stars -- they net to something else
 (? (charm? 5) (star? 5) 1)                                  ; a CHARM is a star, by spec (net = self)
 (charm? 5) !(charm? 3.5) !(charm? @(1 2 3)) !(charm? 'a) (? (charm? 5) (star? 5) 1)   ; a CHARM (charm?) is the word-sized star: a fixnum, and every charm is a star
 (tray? @(1 2 3)) (tray? @("a" "b"))                      ; a SET is an array of ANY element kind (numbers or objects)
 (galaxy? @(1 2 3)) !(galaxy? @("a" "b"))                   ; a GALAXY is a NUMERIC set (a set of stars); a set of strings is not
 (galaxy? (array '(2) (200 2) (200 2)))                    ; a set of BIGS is a galaxy -- bignum cells are stars (keyed on cells, not the O code)
 !(star? @(1 2 3)) !(galaxy? 5) !(galaxy? '(1 2))            ; star?/galaxy? are DISJOINT; a scalar / a list is neither a galaxy nor a set
 (!"" = 0 = $"") (!-5 = 0 = $-5))                ; the invariant !x == (0 = $x), as an = chain

; --- types & predicates --- storage: charm? big? full? gem? twin? set? string? nom? name? two? book?;
; derived constellation? whole? atom?; lit? = a top-region reference (map/fn/hot, ai_kind>=KMap); hot? the opaque cask/port subset.
(assert
 (charm? 5) (two? '(1 2)) (string? "hi") (nom? 'x) (lit? cap) (book? #(1 2))
 (big? (100 2)) ((? wint full? big?) (62 2)) (gem? 1.5) (twin? i) (tray? @(1 2 3))
 (constellation? 1.5) (constellation? i) (constellation? (62 2)) (whole? (62 2)) (atom? 'x) !(atom? '(1))
 (hot? (cask 4)) (hot? out) (hot? (tap '(104)))   ; the hot zoo, named
 !(hot? #()) !(hot? cap) !(hot? 5) !(hot? "s")   ; maps/functions/data are not hots
 (lit? (cask 4)) (lit? cap) (lit? #()) !(lit? '(1)) !(lit? "s") !(lit? 5) !(lit? ()) ; lit? = the top region (map/fn/hot); not data leaves (chains/text/numbers) nor the floor
 (1 = $cap) (1 = $out) (1 = $(tap 0))            ; tops and ports net 1: present, drained or not
 (charm? (: p (spin (\ x x) 0) _ (catch p) p))  ; a task id is a number, not a handle
 ((64 2) = 2 * (63 2))                           ; fixnum overflow -> exact bignum ((k b) = b**k)
 (5.0 = (abs ~(3 4))) (~(2.0 3.0) = 2 + 3 * i))  ; mixed arithmetic widens to the higher tier

; --- arithmetic --- + - * / // % infix; fixnum fast path, overflow grows fix->wide->bignum;
; `/` is true division (inexact int quotient -> float); 0/0 = 0; bitwise << >> & | ^; monadics
; ride the valence law (-(f x) negate, /4 reciprocal, ...) while sections ((- 0), (/ 1)) stay words.
(assert
 (3 = 1 + 2) (2.5 = 5 / 2) (2 = (// 5 2)) (0.5 = 1 / 2) (1 = 5 % 2) (3.5 = 1 + 2.5)
 (2 = 4 / 2) (charm? (4 / 2)) (-2 = (// -5 2))
 (-5 = ((- 0) 5)) (0.25 = ((/ 1) 4)) (~(-1 -2) = ((- 0) ~(1 2)))   ; the sections are the monadics
 !(charm? (2 * 2305843009213693952)) (gem? (1 / 0)) (? wint (1e308 < 1 / 0) 1) (0 = (/ 0 0))
 (ieee-inf = 1 / 0) ("ieee-inf" = (show (1 / 0))) ("-ieee-inf" = (show (-1 / 0)))
 ((/ 0 0) = (/ 0 0)) !(/ 0 0) (0 = $(/ 0 0)) (nom? 'inf) (nom? 'nan) (nom? 'ieee-nan)
 (-2 = (^ 1 -1)) (15 = 8 | 4 | 2 | 1) (16 = (>> 64 2)) (16 = (<< 2 3)))

; --- order & equality --- < <= > >= total over all values (across kinds by the lattice,
; within by value/lex order); `=` bridges the numeric tower; `id?` is identity; `!=` is gone.
(assert
 (3 = 3.0) !(3 = 4) (1 < 1.5) (3.0 >= 3) (id? 'a 'a) !(id? '(1) '(1))
 ('x < "a") ("a" < 1) (1 < '(0)) !(1 < "a")          ; true-blue order: mint < string < number < chain
 ('(0) < #(1 10)) (#(1 10) < cap) !(cap < #(1 10))    ; the map rung: chain < map < hot
 ("abc" < "abd") ("ab" < "abc") ('(1 2) < '(1 3))     ; within a band: text and chains order lexicographically
 ; a GALAXY folds into the number band by its net (probe via sort/show -- infix < on an array broadcasts to a mask).
 ("(@(1 1) 5 @(2 4))" = (show (sort `(@(2 4) 5 @(1 1)))))  ; nets 2 < 5 < 6, galaxies interleaving with the star
 ("(3 @(1 2))" = (show (sort `(@(1 2) 3))))          ; net tie -> a star seats below a galaxy
 ("((7 8) @('a 'b))" = (show (sort `(@('a 'b) '(7 8)))))   ; a tray (object array) stays ABOVE link
 (@(5) = 5))                                          ; a one-cell array still demotes to its scalar

; --- comparing functions --- `=` on functions is alpha + structural (binders by position,
; free vars by name, captures pairwise); eta/beta not bridged; 1 = (\ x x), 0 = (\ _ 1).
(assert
 ((\ x x) = (\ y y)) ((\ a b (+ a b)) = (\ x y (+ x y)))           ; alpha: bound vars by position
 ((\ x (+ x 1)) = (\ x (+ x 1))) !(id? (\ x (+ x 1)) (\ x (+ x 1)))  ; equal, yet distinct objects
 !((\ x x) = (\ y z)) !((\ x (+ x 1)) = (\ x (+ x 2)))             ; free /= bound; different body
 (: g (\ a (\ b (+ a b))) (&& ((g 1) = (g 1)) !((g 1) = (g 2))))   ; closures: equal iff captures match
 ((+ 1) = (+ 1)) !((\ x x) < (\ y y)) !((\ x (cap x)) = cap)           ; partial apps too; eta not bridged
 ((+ 1.5) = (+ 1.5)) !((+ 1.5) = (+ 2.5)) ('(1.5) = '(1.5)) !('(1.5) = '(2.5))  ; nested float boxes compare by value (eqv KFlo)
 (1 = (\ x x)) ((\ y y) = 1) !(id? 1 (\ x x))                      ; 1 = identity, either side
 (0 = (\ _ 1)) ((\ q 1) = 0) !(0 = (\ _ 2)) !(0 = (\ _ _))        ; 0 = const-1 (and only that)
 !!(\ _ 1) (1 = $(\ _ 1)))     ; the bridge crosses the measure: =-equal to 0, yet present (a top nets 1)

; --- reduction --- `=` stops at alpha (above); `ev` goes further -- it REDUCES. these are the
; binary twins of rocq/spec.v's reduction layer (step/subst): the proof says "valid by the
; calculus", the line here says "the binary computes exactly this". beta on the identity and
; const-1, a nested redex reduced all the way, and eta still unbridged (its de Bruijn reduct shifts).
(assert
 (5 = ((\ x x) 5))                               ; beta_id: (\ x x) a ~> a
 (1 = ((\ _ 1) 9))                               ; beta_const: (\ _ 1) a ~> 1 (drops its arg)
 (5 = ((\ x x) ((\ x x) 5)))                     ; beta_nested: (\ x x) ((\ x x) a) ~>* a
 !((\ x (cap x)) = cap))                         ; eta_redex_shifts' twin: eta stays unbridged

; --- + and * are generic --- `+` adds numbers, concatenates strings, appends lists; `-` numeric
; only. the BYTE LAW: a string + an exact integer 0..255 is one byte. a symbol inherits the string
; lane (acts as its spelling, re-interns; demotes on a string operand). `*` is repeated `+`: a sequence
; times a count repeats it, and the count SATURATES.
(assert
 ("abcd" = "ab" + "cd") ("xB" = "x" + 66) ('efef = 'ef + 'ef) ("abef" = "ab" + 'ef)
 ("xB" = "x" + 66.0) !("x" + 1.5) !("x" + -66) !("x" + 256)   ; the byte law: exact 0..255 or nil
 ('(1 2 3 4) = '(1 2) + '(3 4)) ('(5 1 2) = 5 + '(1 2)) !("a" - "b")
 ('(3) = '(3) + ()) ('(3) = () + '(3)) ('(1 2) = '(1 2) + (mint 0))   ; a bare mint -- the zero point () too -- is +'s
 ("ab" = "ab" + ()) ("ab" = () + "ab") (5 = 5 + ()) (5 = () + 5)      ; IDENTITY in every lane, not just on lists:
 (~(1 2) = () + ~(1 2)) ("@(1 2 3)" = show (() + @(1 2 3))) (() = () + ())  ; string/number/complex/array pass through
 (('ef + '(1 2)) = '(ef 1 2)) ((intern (+ "ef" 5)) = 'ef + 5)  ; a NAMED symbol still ADJOINS to a list (foo stays foo); + a number rides the byte law, re-interned
 ((\ x x) = () + (\ x x)) (2 = (((\ x x) + (\ x x)) (\ n (+ n 1)) 0))   ; the TOP lane too: () + hot = hot, and
 ("ababab" = "ab" * 3) ('xyxy = 'xy * 2) ('(1 2 1 2) = '(1 2) * 2) !("ab" * "cd")   ; sym * count re-interns; + on two hots IS church add (id+id acts as 2)
 !("ab" * -3) ("ababab" = "ab" * 2.5) !('(1 2) * 0)         ; the count saturates; the NUMBER 0 empties
 (5 = () * 5) (5 = 5 * ()) ("ab" = "ab" * ()) ("ab" = () * "ab")   ; () is *'s IDENTITY too -- the multiplicative-
 ('(1 2) = '(1 2) * (mint 0)) (() = () * ()) ("@(1 2 3)" = show (() * @(1 2 3)))   ; identity FACE (1) of the unit,
 ("" = "ab" * 0) ((\ x x) = () * (\ x x)))                  ; mirroring its + face (0); 0 stays the number; () * hot = hot too

; --- list * list is the CARTESIAN PRODUCT --- the semiring product whose `+` is cat: each
; pair a proper 2-list (ai bj), so `tally` is the homomorphism (tally(a*b)=ta*tb). infix `*`
; is right-associative, so a*b*c nests right. RIGHT-distributivity ((a+b)*c=a*c+b*c) holds on
; the nose (the outer loop ranges the LEFT operand); LEFT-distributivity holds only up to a
; permutation (intrinsic to ordered pairs -- same multiset, different order). `net` is NOT the
; `*` measure (it's not multiplicative); `tally` is. () stays the * UNIT (identity), not the
; cartesian annihilator -- the unit law preempts the empty-operand lane.
(assert
 (('(1 2) * '(3 4)) = '((1 3) (1 4) (2 3) (2 4)))                ; the product: every ordered pairing
 (('(1 2) * '(3 4) * '(5 6)) = '((1 (3 5)) (1 (3 6)) (1 (4 5)) (1 (4 6)) (2 (3 5)) (2 (3 6)) (2 (4 5)) (2 (4 6))))  ; right-assoc nests right
 (6 = tally ('(1 2) * '(3 4 5))) ((tally ('(1 2) * '(3 4 5))) = (tally '(1 2)) * (tally '(3 4 5)))   ; tally is the homomorphism
 ((('(1 2) + '(8 9)) * '(3 4)) = (('(1 2) * '(3 4)) + ('(8 9) * '(3 4))))    ; right-distributive on the nose
 (!(('(1 2) * ('(3 4) + '(5 6))) = (('(1 2) * '(3 4)) + ('(1 2) * '(5 6)))))  ; left-distrib FAILS as ordered lists ...
 ((sort ('(1 2) * ('(3 4) + '(5 6)))) = (sort (('(1 2) * '(3 4)) + ('(1 2) * '(5 6)))))  ; ... but holds up to permutation
 ('(1 3) = cap ('(1 2) * '(3 4)))                               ; pairs are real 2-lists -- reversible via cap/cup
 (('(1 2) * ()) = '(1 2)) (() * '(3 4) = '(3 4))                ; () is the * UNIT (identity), not the annihilator
 !("ab" * '(1 2)) !('(1 2) * "ab"))                            ; only chain*chain -- string*chain stays nil

; --- numeric functions --- abs int (type-aware); constants e pi i; gcd modpow; the only
; transcendental nifs are power sine cosine log; power/sqrt/exp/nth-root/tan/atan derived from
; numerals + complex (sqrt is total: ((/ 1 2) -1) = i).
(assert
 (5 = (abs -5)) (charm? (abs -5)) (5.0 = (abs ~(3 4))) (2 = (int 2.9))
 (1024 = (10 2)) (21 = (gcd 1071 462)) (976371285 = (modpow 2 100 1000000007))
 (2.0 = ((/ 1 2) 4)) (1024 = (10 2)) (1 = (0 e)) (2.718281828459045 = e))

; --- a few identities --- tetration is the tower with one base; i*i = -1; euler holds in the
; EXACT direction ((log -1) = i * pi -- `=` is exact, so e^(i*pi) does not hold forward); power's
; principal root is exact, ((/ 1 2) -1) = i on the nose. (only bit-exact claims on every target.)
(assert
 (27 = (3 3)) (7625597484987 = (3 3 3)) (16 = (2 2 2)) (65536 = (2 2 2 2))   ; tetration
 (-1 = i * i) (-1 = (2 i)) (1 = ((i * 0) e))                                 ; i^2 = -1; e^(i*0) = 1
 ((log -1) = i * pi) ((log i) = i * pi / 2)                                  ; euler, in the exact direction
 (twin? (log -1)) (gem? (log 2)) (twin? (log ~(2 3)))                          ; log widens only when it must
 (i = ((/ 1 2) -1)) (~(0 2) = ((/ 1 2) -4))                                  ; sqrt of a negative: principal, exact
 (-8 = (3 -2)) (twin? ((/ 1 3) -8))                                       ; integer powers stay real; odd roots go principal
 (0.0 = (sine 0) / (cosine 0)) (gem? (sine 0)))                                   ; tan 0 = 0

; --- complex --- a scalar at tier C; the `~` sigil: ~(re im) builds (twin re im), a bare ~x
; lifts a real or conjugates (an involution); i = ~(0 1). a rank-N complex array packs (re,im)
; into a `c`-typed array; the net is the complex SUM of the cells, $v = $(net v).
(assert
 ((* i i) = -1) (~(2 0) = 2) (~(-5 10) = ~(1 2) * ~(3 4)) (twin? ~5) !(twin? 5)
 (~(0 0) = ~0) ((conj ~(2 3)) = ~~(2 3)) ((conj ~(2 3)) = ~(2 -3)) (~(2 3) = ~~~(2 3))
 ((conj (~(2 3) + ~(4 5))) = (conj ~(2 3)) + (conj ~(4 5)))      ; conj is additive
 ((conj (~(2 3) * ~(4 5))) = (conj ~(2 3)) * (conj ~(4 5)))      ; ... and multiplicative
 (~8 = ~3 + ~5) (~(0 0) < i) ((conj ~(2 3)) < ~(2 3))           ; reals embed; (re,im) order: 0<i, conj below
 (2.0 = (re ~(2 3))) (i < 1) !(1 < i) ("~(0.0 1.0)" = (show i))
 (0.0 = (peep (arg ~(1 @(1 0))) 1 0)))           ; arg broadcasts -- (arg ~(1 x)) = atan, elementwise
(assert
 (: v (array 2 ~(1 2) ~(3 4)) (&& (twin-tray = (tier v)) (~(1 2) = (peep v 0 0)) (~(4 6) = (net v))
    (~(2 4) = (peep (v + v) 0 0)) (~(2 4) = (peep (~(2 0) * v) 0 0)) !(v < v)
    ($v = $(net v)) ("@(~(1.0 2.0) ~(3.0 4.0))" = (show v))))
 (8 = $(array 2 ~(3 4) ~(-3 4))) (8 = $`(~(3 4) ~(-3 4))))

; --- arrays --- (star-tray shape vals) typed ctor (vals 0 zero-fills; gem-/twin-/top-tray for r/c/o); (array shape elem..)
; infers; @(..) rank-1 literal; (iota n) the z-array 0..n-1. + - * // < = broadcast numpy-style;
; reduce net/prod/max/min/aall; contract inner (+.x) / outer (o.x); empty reductions = units.
(assert
 (6 = (tally (star-tray '(2 3) 0))) (2 = (rank (star-tray '(2 3) 0))) ('(2 3) = (shape (star-tray '(2 3) 0)))
 (star-tray = (tier (star-tray '(2 3) 0))) (20 = (peep @(10 20 30) 1 -1)) (-1 = (peep @(10 20 30) 9 -1))
 (3 = (peep (star-tray '(2 2) '(1 2 3 4)) '(1 0) -1)) (@(11 22 33) = @(1 2 3) + @(10 20 30))
 (@(2 4 6) = @(1 2 3) * 2) (gem-tray = (tier ((star-tray '(2) 0) + 1.5))) (star-tray = (tier ((star-tray '(3) 0) < 1)))
 (60 = (net @(10 20 30))) (30 = (max @(10 30 20))) (5 = (net 5)) (aall (1 < 2))
 (@(0 1 2) = (iota 3)) (star-tray = (tier (iota 3))) !(iota 0) !(iota -1) (4950 = (net (iota 100)))   ; iota: jot's range as a z-array
 (aall (@(2.0 3.0) = ((/ 1 2) @(4.0 9.0)))) (@(3.5 5.5) = @(7 11) / 2) (@(3 5) = (// @(7 11) 2))
 (@(4 6) = @(8 12) / 2) !(star-tray '(3) 0) ("@(10 20 30)" = (show @(10 20 30)))
 (aall (@(10 20 30) = (array 3 10 20 30))) !(@(1 2 3) + @(1 2))
 (0 = (net (star-tray '(0) 0))) (1 = (prod (star-tray '(0) 0))) (aall (star-tray '(0) 0))
 ("@()" = (show (star-tray '(0) 0))) (0 = (tally ((star-tray '(0) 0) + 1)))
 (32 = (inner @(1 2 3) @(4 5 6))) (star-tray = (tier (outer @(1 2) @(3 4))))   ; +.x dot ; o.x outer
 (: M (inner (star-tray '(2 3) '(1 2 3 4 5 6)) (star-tray '(3 2) '(7 8 9 10 11 12)))  ; 2x2 matmul
    (&& ('(2 2) = (shape M)) (154 = (peep M '(1 1) 0)))) !(inner @(1 2 3) @(1 2)))

; --- chains & lists --- link builds the chain; cap/cup the two projections (caap..cuuup
; the compounds); sort/sortby by the total order; (jot n) the first n charms; the higher-order
; functions live in the prel.
(assert
 (1 = (cap '(1 2 3))) ('(2 3) = (cup '(1 2 3))) (3 = (caup '(2 3 4))) ('(1 2) = (link 1 (link 2 ())))
 !(cap 0) ("x" = (string 'x)) !(two? 'x)          ; no cap at the end of the list; a symbol is NOT a chain -- its name comes via `string`
 ('(0 1 2) = (jot 3)) !(jot 0) (3 = $(jot 3)) ; jot: the first n charms; the empty count is nothing
 ('(2 3 4) = (map (+ 1) '(1 2 3))) (24 = (foldl (*) 1 '(1 2 3 4))) (6 = (foldr (+) 0 '(1 2 3)))
 ('(1 3) = (filter (\ x (x % 2)) '(1 2 3 4))) ('(1 2 3) = (sort '(3 1 2))) ('(3 2 1) = (sortby (>) '(1 2 3)))
 ('(1 2 3 4) = (cat '(1 2) '(3 4))) ('(3 2 1) = (rev '(1 2 3))) ('(1 2) = (map cap (zip '(1 2) '(3 4))))
 (20 = (caup (assoc 2 (list `(1 10) `(2 20))))) ('(1 2) = (take 2 '(1 2 3 4))) ('(3 4) = (drop 2 '(1 2 3 4)))
 (3 = (last '(1 2 3))) ('(1 2) = (init '(1 2 3))) (member? 3 '(1 2 3)) !(member? 9 '(1 2 3))
 (all (\ x (0 < x)) '(1 2 3)) (any (\ x (2 < x)) '(1 2 3))
 (294 = $'(a b c)) (3 = (tally '(a b c))))  ; net sums spellings; tally counts the spine

; --- strings, symbols & mints --- a symbol is interned; (mint 0) adjoins a fresh nameless POINT
; (materially empty, applies const-1); a NOM is a named point (its own kind); () IS THE CORE -- the one
; true nothing (serial-0 mint, printed ()), DISTINCT from 0 and "" though all net 0;
; absence reads it; `$` clamps the net measure, `tally` counts; snip/+/string.
(assert
 (() = (:)) !(nom? ()) !(name? ()) !(0 = ()) !(id? 0 '()) (() = (intern "")) (0 = $()) !() !!$'x
 ("()" = (show ()))
 (: z zz-never-pinned (&& !(nom? z) !z (id? z (:)) ("()" = (show z))))   ; absence: the zero point, wearing () -- NOT a nom (anonymous and empty)
 (nom? (mint 0)) !(name? (mint 0)) (0 = $(mint 0)) !(mint 0)   ; the fresh point: nom? (a real point) but NOT name? (anonymous), materially empty
 (1 = ((mint 0) 5)) (1 = ('xyz 1))               ; units apply const-1; the name index is gone
 !((mint 0) = (mint 0)) (: m (mint 0) (&& (m = m) (id? m m)))  ; distinct always; itself only
 (nom? (nom 'x)) (name? (nom 'x)) (name? 'x) !(two? (nom 'x)) ("x" = (string (nom 'x)))  ; a nom is a NAMED point (nom? AND name?, an ATOM, NOT a chain); its name comes via `string`
 (: a (nom 'x) b (nom 'x) (&& (a < b) !(b < a) !(a = b)))   ; same-name noms order by serial (distinct points)
 ((mint 0) < (nom 'x))                           ; within the mint band: a bare mint below a named symbol
 ((mint 0) < 0)                                  ; the blue floor: every point sits BELOW the numbers (true-blue)
 (: a (nom 'k) b (nom 'k) t (tablet 0) _ (pin t a 1) _ (pin t b 2)
    (&& (1 = (t a)) (2 = (t b)) (2 = $t)))      ; same-name noms are distinct map keys
 (97 = ("abc" 0)) (294 = $"abc") (3 = (tally "abc")) (4 = $3.9) (0 = $-3.9) (7 = $@(3 4)) (5 = (abs -5)) (5.0 = (abs @(3 4)))
 !(string 0) !!(string 1)                        ; a NUL nets nothing: the chain of nothings reaches the bytes
 !(snip (+ "a" 0) 1 2) (97 = $(+ "a" 0))        ; ... an all-NUL text IS nothing, and the NUL byte appends for free
 ("bidden" = (snip "forbidden planet" 3 9)) ("abcd" = (+ "ab" "cd")) (1 = ("hi" 9))
 ('asdf = (intern "asdf")) !((nom 0) = (nom 0)) ("asdf" = (string 'asdf))
 ("\"a\\nb\"" = (show "a\nb")) ("(mint " = (snip (show (mint 0)) 0 6)))   ; a mint prints (mint <serial>) (diagnostic, not an exact reparse)

; --- hashes --- #(k v ..)/(hash ..) build, (tablet 0) the empty hash; #() = the EMPTY
; MAP (the reader emits (tablet 0); () is the zero-point, distinct from 0); #x boxes a datum;
; accessors collection-first peep/pin/pull; (t k) == (peep t k 0); `missing` the conditioned read.
(assert
 (: b #0 (&& (book? b) (1 = $b) (0 = (peep b 0 9)) (: _ (pin b 0 7) (7 = (b 0)))))
 (book? #()) (0 = $#()) !#()                      ; #() is the empty map: 0 keys, falsy
 (: t #(1 10 2 20) (&& (20 = (peep t 2 0)) (20 = (t 2)) (99 = (peep t 9 99))))
 (10 = (missing #(1 10) 1)) (id? (:) (missing (tablet 0) 'k)) (0 = (missing #(1 0) 1))   ; missing: the conditioned read; presence beats value
 (50 = (peep (pin (tablet 0) 5 50) 5 0)) (: t #(1 10 2 20) _ (pull t 1 0) (1 = $t))
 (: t #(1 10 2 20) v (pull t 2 0) (&& (20 = v) (1 = $t) (99 = (peep t 2 99)) (-1 = (pull t 9 -1))))  ; pull: value or default, removes the key
 ('(1 2) = (sort (keys #(1 10 2 20)))) ((dig 'k) = (dig 'k)) (book? (tablet 0)) !(book? 5)
 !(#(1 10) = #(1 10)) (: t #(1 10) (t = t))      ; mutable -> identity =
 (40 = (: t #(1 10) _ (t <- 4 40) (t -> 4 0))))  ; the infix accessors

; --- the EMPTY SPELLINGS (the nothing surface) --- each kind's empty by its sigil: () the
; chain (the zero-point, DISTINCT from the number 0), "" the string, @() the array, #() the
; map, ~(0 0) the zero complex, (cask 0) the buffer -- all net 0 -> blue -> false. spelled via
; 0/() too: @()/#() are the EMPTIES (the reader emits (iota 0)/(tablet 0)); @0/#0 wrap the
; VALUE 0 (a 1-cell -> the scalar 0, a box). every nothing is a MASK; () the bare-ish floor.
(assert
 !() !0 !"" !@() !#() !~(0 0) !(cask 0)           ; every empty is false (blue)
 (nil? ()) (nil? 0) !(= () 0) !(id? () 0)        ; () (zero-point) and 0 (number) are DISTINCT, both nothing
 ("@()" = (show @())) (1 = (rank @())) (0 = (tally @())) (star-tray = (tier @()))  ; @() the empty array, round-trips
 (book? #()) (0 = $#()) ("(tablet 0)" = (show #()))   ; #() the empty map
 (0 = @0) (nil? (rank @0))                      ; @0 wraps the VALUE 0 -> the scalar 0 (a 1-cell demotes)
 (book? #0) (1 = $#0) !!#0)                       ; #0 wraps the VALUE 0 -> a box (present)

; --- buffers --- (cask n) mutable zeroed bytes; peep/pin a byte 0..255; `$` nets the charms
; (a zeroed cask is nothing); pour; identity equality.
(assert
 (: b (cask 3) _ (pin b 0 65) (65 = (peep b 0 0))) (0 = $(cask 4)) (4 = (tally (cask 4)))
 !(cask 3) (65 = (: b (cask 1) _ (pin b 0 65) $b))  ; zeroed -> nothing; bytes are charms (lockstep at bufs)
 (: b (cask 1) _ (pin b 0 257) (1 = (peep b 0 0))) (: b (cask 4) _ (pour b 0 "ABCD" 0 4) (68 = (peep b 3 0)))
 !((cask 2) = (cask 2)))

; --- reader operators --- structural, environment-free reading; sigils factored at COMPILE
; time by opfix against the `operators` table. the VALENCE LAW: glued is monadic, spaced is
; dyadic; head position never fuses. the FACTORIZATION/CURRY laws (see CLAUDE.md) govern the rest.
(assert
 ('(1 (\ x) 3) = `(1 ''x 3)) ('(1 2 3 4) = (: xs '(2 3) ('(1) + xs + '(4))))
 (532 = $"hello") (5 = (tally "hello")) (42 = $42) (1 = !0) (0 = !5) !!5
 (i = ~(0 1)) (~(2 3) = (twin 2 3)) ('~x = '(conj x)) (lit? dot)
 ("((dot x))" = (show (opfix '(. x)))) ('! = (caup '(a ! b)))   ; opfix factors (cmp via show: opfix's internal forms stay 0-tailed); quotes stay data
 (6 = ((\ x' (x' + 1)) 5)) (nom? 'ab') (7 = (: n' 7 n'))   ; the prime: x' is a name (binder, symbol, let); leading ' is still quote
 (3 = 1 + 2) (7 = 1 + 2 * 3) ('b = 0 ? 'a 'b) ('big = (1 < 2) ? 'big 'small)
 (1 = (3 != 4)) (0 = (3 != 3))                   ; the factorization law: != = ! of =
 (197 = ($"ab" + 2))                             ; one binds tightest: (+ ($ "ab") 2)
 (3 = ((1 +) 2))                                 ; the curry law: (1 +) folds to (+ 1)
 (1 = <'(1 2 3)) (2 = <>'(1 2 3)) ('(3) = >>'(1 2 3))   ; glued runs are MONADIC
 (6 = +'(1 2 3)) (-1 = +'(-2 1)) (24 = *'(1 2 3 4))     ; +/ and */ -- the net, unclamped
 (5 = |-5) (-3 = -(1 + 2)) (0.25 = /4) (1 = ?7) (0 = ?"")
 (3 = (+ 1 2)) (1 = ((< 5) 9))                   ; head position never fuses: call and section
 ('(mono (< x)) = (caup (sound (tap '(40 102 32 60 120 41)) 99)))  ; the emission, data-lane
 ('cap = (monadics '<)) ('net = (monadics '+))
 (20 = (#(1 10 2 20) -> 2 0)) (7 = (((tablet 0) <- 'k 7) 'k)) (9 = ((tablet 0) -> 'k 9))
 (12 = (foldl (+) 0 '(3 4 5)))
 (: t operators
    (&& (book? t) (2 = (t '+)) (3 = (t '?)) (2 = (t '%))
        ((link 'saturate 1) = (t '$)) ((link 'nil? 1) = (t '!))
        ((link 'pin 3) = (t '<-)) ((link 'peep 3) = (t '->)))))

; --- macros --- a macro maps an arg list to code; install with `::`. the prel ships
; do/let/if/cond/quote, && and || (short-circuiting), L/list, tuple/map/array, :- and ?-, >>= <=<.
(:: 'unless (\ a `('? (cap a) 0 (caup a))))
(assert
 ('ok = (unless 0 'ok)) (0 = (unless 1 'ok)) (3 = (&& 1 2 3)) !(&& 1 0 3)
 (2 = (|| 0 2 3)) ('(1 2 3) = `(1 2 3)) (6 = (do 1 2 6)) (3 = (let a 1 b 2 (a + b)))
 (3 = (:- (a + b) a 1 b 2)) ('big = (?- 'else (1 < 2) 'big)) (9 = ((<=< (+ 1) (\ x (x * 2))) 4)))

; --- control --- ev compiles+runs; call-cc a one-shot escape; tasks hatch/wait/yield/sleep/done?;
; the RNG is xoshiro256++; a global `help` takes every raise (scare/more bits); a missing name
; raises (scare 'missing nom); numeral counts are CAPPED by the `apcap` box.
(assert
 (3 = (ev '(+ 1 2))) (lit? ev) (41 = (call-cc (\ k (k 41)))) (42 = 1 + (call-cc (\ k 41)))
 (42 = (: p (spin (\ x (do (rest 0) (x + 1))) 41) (catch p))) (0 = (catch 99999)) (back? 99999)
 !(rest 0) (4 = (tally (rng-seed 1))) ((rand 10) < 10) (gem? (randf 0))
 (scare? 1) !(scare? 3) (eof? 3) !(eof? 2) (more? 2) !(more? 3) (lit? scare)
 (book? apcap) (1048576 = (apcap 0))              ; the count ceiling, a tunable box
 (id? (:) not-in-the-book) !not-in-the-book      ; a missing name reads the zero point: a nom not in the book
 (: st (rng-seed 7) ((cap (rand-next st)) = (cap (rand-next st)))))

; --- i/o & ports --- in/out are the default ports; getc + putc/puts/putn/putx, per-port
; get/put/.../read, open/close/sip/pad/slurp; `read` is port-first, one datum per call;
; `dot` (the `.` operator, .x) prints x to out and returns it.
(assert
 (string? (show out)) ("hi" = (slurp (tap '(104 105)))) (: o (jug 0) _ (print o 42) ("42" = (slurp o)))
 (1 = (sound (tap '(49)) 99)) ('eof = (sound (tap 0) 'eof)) (: p (tap '(40)) (p = (sound p 99))))

; --- bootstrapping --- the key semantics are l closures shared by both compilers (numap,
; add/mul, opfix, boxfix, feel, maps); the egg is WARMED and the evaluator sits on it twice;
; `born` records the hatch (unbound pre-egg); just before birth the egg mops up runtime names.
(assert (lit? ev) (? born (charm? born) 1)
        (? born !macros 1) (? born !poke 1)     ; post-birth the names are gone
        (? born !boxfix 1) (? born !lvm_ret 1) ; (pre-egg they still exist,
        (? born !twirl 1) (? born !book 1))      ;  hence the born guards)

; --- odds & ends --- show renders a value as its reparsable printed form; (clock t) is ms since
; t and (gauge 0) reports a VM stat; an opaque handle acts as a constant function.
(assert (string? (show @(1 2 3))) (charm? (clock 0)) (1 = ((cask 4) 'x)))
