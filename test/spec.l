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
 (0.5 = (-1 2)) (3.0 = ((/ 1 2) 9))              ; ... but exponents don't: (-1 x) = 1/x; (1/2 x) = sqrt x
 (1 = (i love you)))                             ; the theorem: love is not in the book, and absence absorbs

; --- three special forms --- `:` letrec*/sequence, `?` cond, `\` lambda (one operand: quote).
; a body-having `:` is ONE SCOPE; an empty special form reads its head (the zero point).
(assert
 (3 = (: a 1 b 2 (a + b)))                       ; `:` binds in source order; the last form is the result
 (7 = ((\ x y (x + y)) 3 4))                     ; `\ args.. body` -- a lambda, auto-curried
 ('(1 2) = (\ (1 2)))                            ; one operand: `\` is quote, so 'x is just (\ x)
 ('big = (? 0 'a (1 < 2) 'big 'else)))           ; `?` -- test/result pairs, then a final else
(: (twice f x) (f (f x)) (assert (12 = (twice inc 10))))
(assert
 (idp (:) (?)) (idp (?) (\)) !(:) (symp (:))     ; the empty form is the head read, both lanes: the zero point
 (idp (:) (: a b b 2 a)) (2 = (: a b b 2 b))     ; one scope: forward read = the condition, the point helpless
 (2 = (: x 1 x (x + 1) x)))                      ; ... the sequence law is untouched

; --- true and false --- false is *nothing*: whatever NETS <= 0 (a complex-valued measure --
; numbers their value, text its charm sum, lists the sum of element nets). `!` (nilp) reads
; the net's sign in the total order; `$` (sat) is one saturating clamp, max(0, ceil); !x == (0 = $x).
(assert
 !0 !"" !(tablet 0) !@0 !() !0.0 !~(0 0)         ; zero / empty -> false
 !-5 !-3.9 !~(-3 4) !~(0 -1)                     ; <= 0 in the total order -> false (complex by re then im)
 !!5 !!"x" !!'a !!cap !!i !!~(3 -4)              ; positive / nonempty -> true
 !'(() ()) !'(0 0) !'((0) (())) (0 = $'(() () ()))  ; a product of nothings is nothing, recursively
 !'(-5) !@(-3 -4) !'(-2 1) !!'(0 1)              ; negatives net <= 0 at every rank; -2+1 < 0 < 0+1
 (3 = $'(1 () 2)) (6 = $'(1 2 3)) (7 = $@(3 4))  ; $ sums the nets, then clamps once
 (1 = $(cons 1 2)) !(cons 0 2)                   ; the SPINE carries the measure: a dotted tail is not an element
 (8 = $(L ~(3 4) ~(-3 4))) !(L ~(0 5) -1)        ; phases sum as vectors; the order signs the TOTAL, once
 (1 = $#0) !!#0                                  ; ... but a box stays truthy: maps count keys
 (1 = $'(1)) (0 = $'(0)) (0 = $0) (-1 = +'(-2 1))  ; the COLORS by net-sign: '(1) green, '(0)/0 blue, '(-2 1) red
 (1 = !!$5) (0 = !!$0) (0 = !!$-3)               ; !!$ is the truth bit (1 true, 0 false)
 (0 = !5) (1 = !0) (idp non nilp) (1 = (non 0))  ; ! negates it; non is nilp
 (!"" = 0 = $"") (!-5 = 0 = $-5))                ; the invariant !x == (0 = $x), as an = chain

; --- types & predicates --- storage: fixp bigp widep flop comp arrp strp symp twop mapp;
; derived nump intp atomp; lamp = presence (any heap value); hotp names the buf/port zoo.
(assert
 (fixp 5) (twop '(1 2)) (strp "hi") (symp 'x) (lamp cap) (mapp #(1 2))
 (bigp (100 2)) ((? w64 widep bigp) (62 2)) (flop 1.5) (comp i) (arrp @(1 2 3)) (packp 1.5)
 (nump 1.5) (nump i) (nump (62 2)) (intp (62 2)) (atomp 'x) !(atomp '(1))
 (hotp (buf 4)) (hotp out) (hotp (sip '(104)))   ; the hot zoo, named
 !(hotp #()) !(hotp cap) !(hotp 5) !(hotp "s")   ; maps/functions/data are not hots
 (lamp (buf 4)) (lamp '(1)) (lamp "s") !(lamp 5) ; the lamp-spans-bands pin: lit = any heap value
 (1 = $cap) (1 = $out) (1 = $(sip 0))            ; tops and ports net 1: present, drained or not
 (fixp (: p (spawn (\ x x) 0) _ (wait p) p))  ; a task id is a number, not a handle
 ((64 2) = 2 * (63 2))                           ; fixnum overflow -> exact bignum ((k b) = b**k)
 (5.0 = (abs ~(3 4))) (~(2.0 3.0) = 2 + 3 * i))  ; mixed arithmetic widens to the higher tier

; --- arithmetic --- + - * / // % infix; fixnum fast path, overflow grows fix->wide->bignum;
; `/` is true division (inexact int quotient -> float); 0/0 = 0; bitwise << >> & | ^; monadics
; ride the valence law (-(f x) neg, /4 recip, ...) while sections ((- 0), (/ 1)) stay words.
(assert
 (3 = 1 + 2) (2.5 = 5 / 2) (2 = (// 5 2)) (0.5 = 1 / 2) (1 = 5 % 2) (3.5 = 1 + 2.5)
 (2 = 4 / 2) (fixp (4 / 2)) (-2 = (// -5 2))
 (-5 = ((- 0) 5)) (0.25 = ((/ 1) 4)) (~(-1 -2) = ((- 0) ~(1 2)))   ; the sections are the monadics
 !(fixp (2 * 2305843009213693952)) (flop (1 / 0)) (? w64 (1e308 < 1 / 0) 1) (0 = (/ 0 0))
 (ieee-inf = 1 / 0) ("ieee-inf" = (show (1 / 0))) ("-ieee-inf" = (show (-1 / 0)))
 ((/ 0 0) = (/ 0 0)) !(/ 0 0) (0 = $(/ 0 0)) (symp 'inf) (symp 'nan) (symp 'ieee-nan)
 (-2 = (^ 1 -1)) (15 = 8 | 4 | 2 | 1) (16 = (>> 64 2)) (16 = (<< 2 3)))

; --- order & equality --- < <= > >= total over all values (across kinds by the lattice,
; within by value/lex order); `=` bridges the numeric tower; `idp` is identity; `!=` is gone.
(assert
 (3 = 3.0) !(3 = 4) (1 < 1.5) (3.0 >= 3) (idp 'a 'a) !(idp '(1) '(1))
 (1 < "a") ("a" < 'x) ('x < '(0)) !("a" < 1)
 ('(0) < #(1 10)) (#(1 10) < cap) !(cap < #(1 10)))   ; the map rung: pair < map < top

; --- comparing functions --- `=` on functions is alpha + structural (binders by position,
; free vars by name, captures pairwise); eta/beta not bridged; 1 = (\ x x), 0 = (\ _ 1).
(assert
 ((\ x x) = (\ y y)) ((\ a b (+ a b)) = (\ x y (+ x y)))           ; alpha: bound vars by position
 ((\ x (+ x 1)) = (\ x (+ x 1))) !(idp (\ x (+ x 1)) (\ x (+ x 1)))  ; equal, yet distinct objects
 !((\ x x) = (\ y z)) !((\ x (+ x 1)) = (\ x (+ x 2)))             ; free /= bound; different body
 (: g (\ a (\ b (+ a b))) (&& ((g 1) = (g 1)) !((g 1) = (g 2))))   ; closures: equal iff captures match
 ((+ 1) = (+ 1)) !((\ x x) < (\ y y)) !((\ x (cap x)) = cap)           ; partial apps too; eta not bridged
 (1 = (\ x x)) ((\ y y) = 1) !(idp 1 (\ x x))                      ; 1 = identity, either side
 (0 = (\ _ 1)) ((\ q 1) = 0) !(0 = (\ _ 2)) !(0 = (\ _ _))        ; 0 = const-1 (and only that)
 !!(\ _ 1) (1 = $(\ _ 1)))     ; the bridge crosses the measure: =-equal to 0, yet present (a top nets 1)

; --- + and * are generic --- `+` adds numbers, concatenates strings, appends lists; `-` numeric
; only. the BYTE LAW: a string + an exact integer 0..255 is one byte. symbols left the string
; algebra. `*` is repeated `+`: a sequence times a count repeats it, and the count SATURATES.
(assert
 ("abcd" = "ab" + "cd") ("xB" = "x" + 66) !('ef + 'ef) !("ab" + 'ef)
 ("xB" = "x" + 66.0) !("x" + 1.5) !("x" + -66) !("x" + 256)   ; the byte law: exact 0..255 or nil
 ('(1 2 3 4) = '(1 2) + '(3 4)) ('(5 1 2) = 5 + '(1 2)) !("a" - "b")
 ("ababab" = "ab" * 3) !('xy * 2) ('(1 2 1 2) = '(1 2) * 2) !("ab" * "cd")
 !("ab" * -3) ("ababab" = "ab" * 2.5) !('(1 2) * 0))

; --- numeric functions --- abs int (type-aware); constants e pi i; gcd modpow; the only
; transcendental nifs are pow sin cos log; power/sqrt/exp/nth-root/tan/atan derived from
; numerals + complex (sqrt is total: ((/ 1 2) -1) = i).
(assert
 (5 = (abs -5)) (fixp (abs -5)) (5.0 = (abs ~(3 4))) (2 = (int 2.9))
 (1024 = (10 2)) (21 = (gcd 1071 462)) (976371285 = (modpow 2 100 1000000007))
 (2.0 = ((/ 1 2) 4)) (1024.0 = (pow 2 10)) (1 = (0 e)) (2.718281828459045 = e))

; --- a few identities --- tetration is the tower with one base; i*i = -1; euler holds in the
; EXACT direction ((log -1) = i * pi -- `=` is exact, so e^(i*pi) does not hold forward); pow's
; principal root is exact, ((/ 1 2) -1) = i on the nose. (only bit-exact claims on every target.)
(assert
 (27 = (3 3)) (7625597484987 = (3 3 3)) (16 = (2 2 2)) (65536 = (2 2 2 2))   ; tetration
 (-1 = i * i) (-1 = (2 i)) (1 = ((i * 0) e))                                 ; i^2 = -1; e^(i*0) = 1
 ((log -1) = i * pi) ((log i) = i * pi / 2)                                  ; euler, in the exact direction
 (comp (log -1)) (flop (log 2)) (comp (log ~(2 3)))                          ; log widens only when it must
 (i = ((/ 1 2) -1)) (~(0 2) = ((/ 1 2) -4))                                  ; sqrt of a negative: principal, exact
 (-8 = (pow -2 3)) (comp ((/ 1 3) -8))                                       ; integer powers stay real; odd roots go principal
 (0.0 = (sin 0) / (cos 0)) (flop (sin 0)))                                   ; tan 0 = 0

; --- complex --- a scalar at tier C; the `~` sigil: ~(re im) builds (wave re im), a bare ~x
; lifts a real or conjugates (an involution); i = ~(0 1). a rank-N complex array packs (re,im)
; into a `c`-typed array; the net is the complex SUM of the cells, $v = $(asum v).
(assert
 ((* i i) = -1) (~(2 0) = 2) (~(-5 10) = ~(1 2) * ~(3 4)) (comp ~5) !(comp 5)
 (~(0 0) = ~0) ((conj ~(2 3)) = ~~(2 3)) ((conj ~(2 3)) = ~(2 -3))
 (2.0 = (re ~(2 3))) (i < 1) !(1 < i) ("~(0.0 1.0)" = (show i))
 (0.0 = (peep (arg ~(1 @(1 0))) 1 0)))           ; arg broadcasts -- (arg ~(1 x)) = atan, elementwise
(assert
 (: v (array 2 ~(1 2) ~(3 4)) (&& (c = (atype v)) (~(1 2) = (peep v 0 0)) (~(4 6) = (asum v))
    (~(2 4) = (peep (v + v) 0 0)) (~(2 4) = (peep (~(2 0) * v) 0 0)) !(v < v)
    ($v = $(asum v)) ("@(~(1.0 2.0) ~(3.0 4.0))" = (show v))))
 (8 = $(array 2 ~(3 4) ~(-3 4))) (8 = $(L ~(3 4) ~(-3 4))))

; --- arrays --- (arr type shape vals) typed ctor (vals 0 zero-fills); (array shape elem..)
; infers; @(..) rank-1 literal; (iota n) the z-array 0..n-1. + - * // < = broadcast numpy-style;
; reduce asum/aprod/amax/amin/aall; contract inner (+.x) / outer (o.x); empty reductions = units.
(assert
 (6 = (alen (arr z '(2 3) 0))) (2 = (arank (arr z '(2 3) 0))) ('(2 3) = (ashape (arr z '(2 3) 0)))
 (z = (atype (arr z '(2 3) 0))) (20 = (peep @(10 20 30) 1 -1)) (-1 = (peep @(10 20 30) 9 -1))
 (3 = (peep (arr z '(2 2) '(1 2 3 4)) '(1 0) -1)) (@(11 22 33) = @(1 2 3) + @(10 20 30))
 (@(2 4 6) = @(1 2 3) * 2) (r = (atype ((arr z '(2) 0) + 1.5))) (z = (atype ((arr z '(3) 0) < 1)))
 (60 = (asum @(10 20 30))) (30 = (amax @(10 30 20))) (5 = (asum 5)) (aall (1 < 2))
 (@(0 1 2) = (iota 3)) (z = (atype (iota 3))) !(iota 0) !(iota -1) (4950 = (asum (iota 100)))   ; iota: jot's range as a z-array
 (aall (@(2.0 3.0) = ((/ 1 2) @(4.0 9.0)))) (@(3.5 5.5) = @(7 11) / 2) (@(3 5) = (// @(7 11) 2))
 (@(4 6) = @(8 12) / 2) !(arr z '(3) 0) ("@(10 20 30)" = (show @(10 20 30)))
 (aall (@(10 20 30) = (array 3 10 20 30))) !(@(1 2 3) + @(1 2)) !(arr 99 '(3) 0)
 (0 = (asum (arr z '(0) 0))) (1 = (aprod (arr z '(0) 0))) (aall (arr z '(0) 0))
 ("(array '(0))" = (show (arr z '(0) 0))) (0 = (alen ((arr z '(0) 0) + 1)))
 (32 = (inner @(1 2 3) @(4 5 6))) (z = (atype (outer @(1 2) @(3 4))))   ; +.x dot ; o.x outer
 (: M (inner (arr z '(2 3) '(1 2 3 4 5 6)) (arr z '(3 2) '(7 8 9 10 11 12)))  ; 2x2 matmul
    (&& ('(2 2) = (ashape M)) (154 = (peep M '(1 1) 0)))) !(inner @(1 2 3) @(1 2)))

; --- products & lists --- cons builds the product; cap/cup the two projections (caap..cuuup
; the compounds); sort/msort by the total order; (jot n) the first n charms; the higher-order
; functions live in the prel.
(assert
 (1 = (cap '(1 2 3))) ('(2 3) = (cup '(1 2 3))) (3 = (caup '(2 3 4))) ('(1 2) = (cons 1 (cons 2 0)))
 !(cap 0) ('x = (cap 'x)) !(cup 'x)              ; no cap at the end of the list; an atom is its own cap
 ('(0 1 2) = (jot 3)) !(jot 0) (3 = $(jot 3)) ; jot: the first n charms; the empty count is nothing
 ('(2 3 4) = (map inc '(1 2 3))) (24 = (foldl (*) 1 '(1 2 3 4))) (6 = (foldr (+) 0 '(1 2 3)))
 ('(1 3) = (filter (\ x (x % 2)) '(1 2 3 4))) ('(1 2 3) = (sort '(3 1 2))) ('(3 2 1) = (msort (>) '(1 2 3)))
 ('(1 2 3 4) = (cat '(1 2) '(3 4))) ('(3 2 1) = (rev '(1 2 3))) ('(1 2) = (map cap (zip '(1 2) '(3 4))))
 (20 = (caup (assq 2 (list (L 1 10) (L 2 20))))) ('(1 2) = (take 2 '(1 2 3 4))) ('(3 4) = (drop 2 '(1 2 3 4)))
 (3 = (last '(1 2 3))) ('(1 2) = (init '(1 2 3))) (memq 3 '(1 2 3)) !(memq 9 '(1 2 3))
 (all (\ x (0 < x)) '(1 2 3)) (any (\ x (2 < x)) '(1 2 3))
 (294 = $'(a b c)) (3 = (tally '(a b c))))  ; net sums spellings; tally counts the spine

; --- strings, symbols & mints --- a symbol is interned; (mint 0) adjoins a fresh nameless POINT
; (materially empty, applies const-1); a NOM is (name . mint); () = 0; absence reads the ZERO
; POINT (serial 0, printed ()); `$` clamps the net measure, `tally` counts; slice/+/string.
(assert
 (0 = ()) !(symp ()) (0 = (intern "")) (idp 0 '()) (0 = $()) !() !!$'x
 ("0" = (show ()))
 (: z zz-never-pinned (&& (symp z) !z (idp z (:)) ("()" = (show z))))   ; absence: the zero point, wearing ()
 (symp (mint 0)) (0 = $(mint 0)) !(mint 0)       ; the fresh point: a nameless atom, materially empty
 (1 = ((mint 0) 5)) (1 = ('xyz 1))               ; units apply const-1; the name index is gone
 !((mint 0) = (mint 0)) (: m (mint 0) (&& (m = m) (idp m m)))  ; distinct always; itself only
 (twop (nom 'x)) ("x" = (cap (nom 'x)))          ; a nom is the pair; the name is its cap
 (: a (nom 'x) b (nom 'x) (&& (a < b) !(b < a) !(a = b)))   ; pair lex inherits the serial order
 ((mint 0) < (nom 'x))                           ; cross-kind: the point (symbol band) below the product
 (0 < (mint 0))                                  ; nothing is a number: every point sits above it
 (: a (nom 'k) b (nom 'k) t (tablet 0) _ (pin t a 1) _ (pin t b 2)
    (&& (1 = (t a)) (2 = (t b)) (2 = $t)))      ; same-name noms are distinct map keys
 (97 = ("abc" 0)) (294 = $"abc") (3 = (tally "abc")) (4 = $3.9) (0 = $-3.9) (7 = $@(3 4)) (5 = (abs -5)) (5.0 = (abs @(3 4)))
 !(string 0) !!(string 1)                        ; a NUL nets nothing: the product of nothings reaches the bytes
 !(slice (+ "a" 0) 1 2) (97 = $(+ "a" 0))        ; ... an all-NUL text IS nothing, and the NUL byte appends for free
 ("bidden" = (slice "forbidden planet" 3 9)) ("abcd" = (+ "ab" "cd")) (1 = ("hi" 9))
 ('asdf = (intern "asdf")) !((nom 0) = (nom 0)) ("asdf" = (string 'asdf))
 ("\"a\\nb\"" = (show "a\nb")) ("(mint 0)" = (show (mint 0))))

; --- hashes --- #(k v ..)/(hash ..) build, (tablet 0) the empty hash; #x boxes a datum
; (#() = #0, the box of nothing); accessors collection-first peep/pin/pull; (t k) == (peep t k 0);
; `missing` is the conditioned read; a hash is MUTABLE, so `=` on hashes is identity.
(assert
 (: b #0 (&& (mapp b) (1 = $b) (0 = (peep b 0 9)) (: _ (pin b 0 7) (7 = (b 0)))))
 (mapp #()) (1 = $#()) !!#()                     ; #() IS #0: the box of nothing, present
 (: t #(1 10 2 20) (&& (20 = (peep t 2 0)) (20 = (t 2)) (99 = (peep t 9 99))))
 (10 = (missing #(1 10) 1)) (idp (:) (missing (tablet 0) 'k)) (0 = (missing #(1 0) 1))   ; missing: the conditioned read; presence beats value
 (50 = (peep (pin (tablet 0) 5 50) 5 0)) (: t #(1 10 2 20) _ (pull t 1 0) (1 = $t))
 (: t #(1 10 2 20) v (pull t 2 0) (&& (20 = v) (1 = $t) (99 = (peep t 2 99)) (-1 = (pull t 9 -1))))  ; pull: value or default, removes the key
 ('(1 2) = (sort (keys #(1 10 2 20)))) ((dig 'k) = (dig 'k)) (mapp (tablet 0)) !(mapp 5)
 !(#(1 10) = #(1 10)) (: t #(1 10) (t = t))      ; mutable -> identity =
 (40 = (: t #(1 10) _ (t <- 4 40) (t -> 4 0))))  ; the infix accessors

; --- buffers --- (buf n) mutable zeroed bytes; peep/pin a byte 0..255; `$` nets the charms
; (a zeroed buf is nothing); blit; identity equality.
(assert
 (: b (buf 3) _ (pin b 0 65) (65 = (peep b 0 0))) (0 = $(buf 4)) (4 = (tally (buf 4)))
 !(buf 3) (65 = (: b (buf 1) _ (pin b 0 65) $b))  ; zeroed -> nothing; bytes are charms (lockstep at bufs)
 (: b (buf 1) _ (pin b 0 257) (1 = (peep b 0 0))) (: b (buf 4) _ (blit b 0 "ABCD" 0 4) (68 = (peep b 3 0)))
 !((buf 2) = (buf 2)))

; --- reader operators --- structural, environment-free reading; sigils factored at COMPILE
; time by opfix against the `operators` table. the VALENCE LAW: glued is monadic, spaced is
; dyadic; head position never fuses. the FACTORIZATION/CURRY laws (see CLAUDE.md) govern the rest.
(assert
 ('(1 (\ x) 3) = `(1 'x 3)) ('(1 2 3 4) = (: xs '(2 3) `(1 ,@xs 4)))
 (532 = $"hello") (5 = (tally "hello")) (42 = $42) (1 = !0) (0 = !5) !!5
 (i = ~(0 1)) (~(2 3) = (wave 2 3)) ('~x = '(conj x)) (lamp dot)
 ('((dot x)) = (opfix '(. x))) ('! = (caup '(a ! b)))   ; opfix factors; quotes stay data
 (6 = ((\ x' (x' + 1)) 5)) (symp 'ab') (7 = (: n' 7 n'))   ; the prime: x' is a name (binder, symbol, let); leading ' is still quote
 (3 = 1 + 2) (7 = 1 + 2 * 3) ('b = 0 ? 'a 'b) ('big = (1 < 2) ? 'big 'small)
 (1 = (3 != 4)) (0 = (3 != 3))                   ; the factorization law: != = ! of =
 (197 = ($"ab" + 2))                             ; one binds tightest: (+ ($ "ab") 2)
 (3 = ((1 +) 2))                                 ; the curry law: (1 +) folds to (+ 1)
 (1 = <'(1 2 3)) (2 = <>'(1 2 3)) ('(3) = >>'(1 2 3))   ; glued runs are MONADIC
 (6 = +'(1 2 3)) (-1 = +'(-2 1)) (24 = *'(1 2 3 4))     ; +/ and */ -- the net, unclamped
 (5 = |-5) (-3 = -(1 + 2)) (0.25 = /4) (1 = ?7) (0 = ?"")
 (3 = (+ 1 2)) (1 = ((< 5) 9))                   ; head position never fuses: call and section
 ('(mono (< x)) = (caup (read (sip '(40 102 32 60 120 41)) 99)))  ; the emission, data-lane
 ('cap = (monadics '<)) ('net = (monadics '+))
 (20 = (#(1 10 2 20) -> 2 0)) (7 = (((tablet 0) <- 'k 7) 'k)) (9 = ((tablet 0) -> 'k 9))
 (12 = (foldl (+) 0 '(3 4 5)))
 (: t operators
    (&& (mapp t) (2 = (t '+)) (3 = (t '?)) (2 = (t '%))
        ((cons 'sat 1) = (t '$)) ((cons 'nilp 1) = (t '!))
        ((cons 'pin 3) = (t '<-)) ((cons 'peep 3) = (t '->)))))

; --- macros --- a macro maps an arg list to code; install with `::`. the prel ships
; do/let/if/cond/quote, && and || (short-circuiting), L/list, tuple/map/array, :- and ?-, >>= <=<.
(:: 'unless (\ a `(? ,(cap a) 0 ,(caup a))))
(assert
 ('ok = (unless 0 'ok)) (0 = (unless 1 'ok)) (3 = (&& 1 2 3)) !(&& 1 0 3)
 (2 = (|| 0 2 3)) ('(1 2 3) = (L 1 2 3)) (6 = (do 1 2 6)) (3 = (let a 1 b 2 (a + b)))
 (3 = (:- (a + b) a 1 b 2)) ('big = (?- 'else (1 < 2) 'big)) (9 = ((<=< inc (\ x (x * 2))) 4)))

; --- control --- ev compiles+runs; call-cc a one-shot escape; tasks spawn/wait/yield/sleep/done?;
; the RNG is xoshiro256++; a global `help` takes every raise (scare/more bits); a missing name
; raises (scare 'missing nom); numeral counts are CAPPED by the `apcap` box.
(assert
 (3 = (ev '(+ 1 2))) (lamp ev) (41 = (call-cc (\ k (k 41)))) (42 = 1 + (call-cc (\ k 41)))
 (42 = (: p (spawn (\ x (do (yield 0) (x + 1))) 41) (wait p))) (0 = (wait 99999)) (done? 99999)
 !(sleep 0) (4 = (alen (rng-seed 1))) ((rand 10) < 10) (flop (randf 0))
 (scare? 1) !(scare? 3) (eof? 3) !(eof? 2) (more? 2) !(more? 3) (lamp scare)
 (mapp apcap) (1048576 = (apcap 0))              ; the count ceiling, a tunable box
 (idp (:) not-in-the-book) !not-in-the-book      ; a missing name reads the zero point: a nom not in the book
 (: st (rng-seed 7) ((cap (rand-next st)) = (cap (rand-next st)))))

; --- i/o & ports --- in/out are the default ports; getc + putc/puts/putn/putx, per-port
; fgetc/fputc/.../read, open/close/sip/pad/slurp; `read` is port-first, one datum per call;
; `dot` (the `.` operator, .x) prints x to out and returns it.
(assert
 (strp (show out)) ("hi" = (slurp (sip '(104 105)))) (: o (pad 0) _ (fputx o 42) ("42" = (page o)))
 (1 = (read (sip '(49)) 99)) ('eof = (read (sip 0) 'eof)) (: p (sip '(40)) (p = (read p 99))))

; --- bootstrapping --- the key semantics are l closures shared by both compilers (numap,
; add/mul, opfix, boxfix, wev, maps); the egg is WARMED and the evaluator sits on it twice;
; `born` records the hatch (unbound pre-egg); just before birth the egg mops up runtime names.
(assert (lamp ev) (? born (fixp born) 1)
        (? born !macros 1) (? born !poke 1)     ; post-birth the names are gone
        (? born !boxfix 1) (? born !lvm_ret 1) ; (pre-egg they still exist,
        (? born !lamb 1) (? born !book 1))      ;  hence the born guards)

; --- odds & ends --- show renders a value as its reparsable printed form; (clock t) is ms since
; t and (gauge 0) reports a VM stat; an opaque handle acts as a constant function.
(assert (strp (show @(1 2 3))) (fixp (clock 0)) (1 = ((buf 4) 'x)))
