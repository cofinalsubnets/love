; love -- a small lisp where every value is an auto-curried function of one argument.
; a portable C runtime (love.c + love.h) plus a self-hosting compiler written in love
; (the love/{prelude,ev,repl}.l layers). source is .l; the host binary is `love`. see README.md.
;
; this file is three things at once: the SPEC, a real TEST in the corpus, and my own
; working notes -- CLAUDE.md (my context file) is exactly this file in a code fence,
; re-wrapped on every edit. keep it green; when in doubt, this file is the truth, and
; the way to settle any doubt is to PROBE THE BINARY -- never trust a prior over a
; one-line experiment. every semantic claim below is assert-backed on every target.

; --- how to work here (read this first) ---
; * `make test` is the gate: host + the self-hosted bootstrap love0, BOTH required to print
;   the zz-fin "tests pass" summary (love0 exactly twice -- a silent reader stop exits 0
;   without reaching zz-fin, so exit code alone proves nothing). `make test_all` adds the
;   qemu kernel + tool diffs; `make valg` for memory. one file at a time: `out/host/love
;   test/x.l` -- but the corpus runs CONCATENATED in one global scope, so keep helpers
;   local (give `:` a body) and remember single-file runs lack the assert harness.
; * footgun: edit love.h => `make clean` or love0 hangs; stash out/dl first (clean nukes the
;   ovmf/limine downloads).
; * C files EMBED lisp the .l sweeps cannot see: love.c (g_evals_'s driver string), main.c
;   (s2cl + runner), kmain.c (the K_TEST runner), wasm/. grep them on every rename.
; * a bare all-punct symbol mid-list captures its left operand when code compiles (the
;   opfix pass) -- escape it in parens ((+) is + as a value); quoted lists are data and
;   keep their operators plain.
; * a corpus test that spawns must (wait p) its task: an orphan stalls the kernel runner.
; * the repl reads each LINE as one expression (1 = 1 answers 1); files read forms.
; * python \b-sweeps treat - as a boundary: kebab names with capital segments mangle.

; --- the shape of it --- one cell is one word: a fixnum is a tagged odd word, anything else
; is a heap object whose first word is its hot -- a live external reference, the wire out of
; the heap to the ap that runs it. the VM is tail-threaded (aps tail-jump, never return --
; `make vmret` checks it) over a two-space copying heap. every operation is *fully generic* --
; it dispatches on a value's *kind*, and the kinds form a lattice that is literally the
; diagonal of the dispatch tables. the C core is tiny; most of the language is love closures
; installed reflectively from the prelude, then baked into a heap image (the *egg*) at
; compile time. the gritty details sit at the bottom.

; --- the type lattice --- two axes. the *tier* spine, low to high:
;   N naturals (the range of $)  <  Z integers (fixnum -> wide box -> bignum)
;     <  R reals (float)  <  C complex  <  O objects (string < symbol < product < map < hom)
; numbers nest as usual (N in Z in R in C). the *rank* axis is scalar (0) vs array (>= 1, one
; per tier: arrZ/R/C/O). the total order < flattens this lattice into BANDS: all numbers are
; ONE band ordered by value (representations interleave: 1 < 1.5 < 2 whatever the rep), then
; string < symbol < product < map < hom, each band ordered within itself (text and products
; lexicographically, maps and homs by an alpha-invariant hash). a map has its own rung
; just under the homs, though it still acts as a lookup hom for +/*/apply. the
; opaque hots (buf/port -- `hotp`) sit in the hom band: truthy when nonempty
; ($out = 1), compared by identity, and applying one acts like 0 (const-1). every
; predicate ends in `p`; they are enumerated below.

; --- everything is a function --- (f x y) == ((f x) y) and (f) == f, so application is just
; left-to-right currying. numbers are church numerals, a list of numbers is an exponential
; tower, and data self-applies (indexes). asserts here read INFIX -- (3 = 1 + 2) is
; ((= 3 (+ 1 2))), folding right-associatively, sound by (f) == f; the reader-operators
; section below has the rules. the two pillars come first:
(assert
 (1 = (0 5)) (5 = (1 5))                         ; 0 is const-1, 1 is the identity
 (8 = (3 2)) (262144 = (2 3 4))                  ; (n x) = x**n; the tower (2 3 4) = 4**(3**2)
 (12 = (3 (+ 1) 9)) ('(2 3 4) = (map (+ 1) '(1 2 3)))  ; (n f) composes f ($ n) times; currying *is* partial application
 (10 = (-3 (+ 1) 10)) (13 = (2.5 (+ 1) 10))      ; the count SATURATES, true to !!$: (-3 f) = (0 f) = 1; a float ceils
 (0.5 = (-1 2)) (3.0 = ((/ 1 2) 9)))             ; ... but exponents don't: (-1 x) = 1/x; (1/2 x) = sqrt x

; --- three special forms --- `:` is letrec*/sequence, `?` is cond, `\` is lambda (and, with a
; single operand, quote). everything else is a function call.
(assert
 (3 = (: a 1 b 2 (a + b)))                       ; `:` binds in source order; the last form is the result
 (7 = ((\ x y (x + y)) 3 4))                     ; `\ args.. body` -- a lambda, auto-curried
 ('(1 2) = (\ (1 2)))                            ; one operand: `\` is quote, so 'x is just (\ x)
 ('big = (? 0 'a (1 < 2) 'big 'else)))           ; `?` -- test/result pairs, then a final else
; `:` doubles as sequencing (bind `_` for effect); `(f x)` on the left is define-sugar; a
; body-less top-level `:` leaks its bindings to the global scope (that's how tests share helpers).
(: (twice f x) (f (f x)) (assert (12 = (twice inc 10))))

; --- true and false --- false is *nothing*: whatever NETS <= 0. every value has a signed
; net measure: a number is its own value (complex: |z| signed by the total order), text is
; its length, a list or array is the SUM of its elements' nets -- recursive and unclamped,
; so negatives cancel positives and a PRODUCT OF NOTHINGS is nothing too. the law of
; saturation holds at every rank: positive to positive, zero-or-negative to zero, so a
; list or array of negatives is nothing, exactly like a negative scalar. maps stay
; key-counted: presence is information there, and #0 must stay truthy. there is no
; "truthy"/"falsy" -- true and false are the bits 1 and 0 of the `!!$` projection.
; `$` (sat) is ONE saturating clamp over the net, max(0, ceil(net)); `!` is the falsity
; oracle (the nif `nilp`, the classical name; `non` is its normal alias, so !$x reads
; "non sat x"), with the invariant !x == (0 = $x). net is additive wherever + is total:
; $(a + b) saturates net a + net b over numbers, text, and lists alike.
(assert
 !0 !"" !#() !@0 !() !0.0 !~(0 0)                ; zero / empty -> false
 !-5 !-3.9 !~(-3 4) !~(0 -1)                     ; <= 0 in the total order -> false (complex by re then im)
 !!5 !!"x" !!'a !!cap !!i !!~(3 -4)              ; positive / nonempty -> true
 !'(() ()) !'(0 0) !'((0) (())) (0 = $'(() () ()))  ; a product of nothings is nothing, recursively
 !'(-5) !@(-3 -4) !'(-2 1) !!'(0 1)              ; negatives net <= 0 at every rank; -2+1 < 0 < 0+1
 (3 = $'(1 () 2)) (6 = $'(1 2 3)) (7 = $@(3 4))  ; $ sums the nets, then clamps once
 (1 = $#0) !!#0                                  ; ... but a box stays truthy: maps count keys
 (1 = !!$5) (0 = !!$0) (0 = !!$-3)               ; !!$ is the truth bit (1 true, 0 false)
 (0 = !5) (1 = !0) (idp non nilp) (1 = (non 0))  ; ! negates it; non is nilp
 (!"" = 0 = $"") (!-5 = 0 = $-5))                ; the invariant !x == (0 = $x), as an = chain

; --- types & predicates --- a fixnum is a tagged word; everything else is a heap object whose
; first word dispatches. the storage predicates:
;   fixp bigp boxp  -- the integer reps (fixnum, bignum, wide-int box)
;   flop comp arrp  -- float, complex scalar, array; all three share one heap type, `tupp`
;   strp symp twop mapp  -- string, symbol, product, map
; derived: `nump` (any number: fix/box/big/float/complex/array), `intp` (any integer), `atomp`
; (anything but a product). `i` is ~(0 1). `homp` is PRESENCE, not a band: every heap
; value answers it (anything with a hot -- everything but a fixnum), pairs and strings
; included. the opaque hots (buf/port) answer `hotp`, the refinement that names the
; zoo; a task is referenced by a fixnum id, not a handle object. `!` (nilp) and
; `done?` are truth/task tests, not type tests.
(assert
 (fixp 5) (twop '(1 2)) (strp "hi") (symp 'x) (homp cap) (mapp #(1 2))
 (bigp (100 2)) (boxp (62 2)) (flop 1.5) (comp i) (arrp @(1 2 3)) (tupp 1.5)
 (nump 1.5) (nump i) (nump (62 2)) (intp (62 2)) (atomp 'x) !(atomp '(1))
 (hotp (buf 4)) (hotp out) (hotp (sip '(104)))   ; the hot zoo, named
 !(hotp #()) !(hotp cap) !(hotp 5) !(hotp "s")   ; maps/functions/data are not hots
 (homp (buf 4)) (homp '(1)) (homp "s") !(homp 5) ; homp is presence: any heap value
 (fixp (: p (spawn (\ x x) 0) _ (wait p) p))  ; a task id is a number, not a handle
 ((64 2) = 2 * (63 2))                           ; fixnum overflow -> exact bignum ((k b) = b**k)
 (5.0 = (abs ~(3 4))) (~(2.0 3.0) = 2 + 3 * i))  ; mixed arithmetic widens to the higher tier

; --- arithmetic --- + - * / // % (infix, like the rest). fixnum fast path; a float makes it
; float; integer
; overflow grows fixnum -> wide box -> bignum; a non-number gives nil. `/` is *true* division --
; an inexact integer quotient promotes to float ((/ 1 2) is 0.5) but an exact one stays integer
; ((/ 4 2) is 2); /0 gives IEEE inf/nan. `//` truncates toward zero (the partner of `%`).
; bitwise << >> & | ^ on integers (complement is (^ x -1)).
(assert
 (3 = 1 + 2) (2.5 = 5 / 2) (2 = (// 5 2)) (0.5 = 1 / 2) (1 = 5 % 2) (3.5 = 1 + 2.5)
 (2 = 4 / 2) (fixp (4 / 2)) (-2 = (// -5 2))
 !(fixp (2 * 2305843009213693952)) (flop (1 / 0)) (1e308 < 1 / 0) !((/ 0 0) = (/ 0 0))
 (-2 = (^ 1 -1)) (15 = 8 | 4 | 2 | 1) (16 = (>> 64 2)) (16 = (<< 2 3)))

; --- order & equality --- < <= > >= is a *total order over all values*: across kinds by the
; lattice (number < string < symbol < product < map < hom), within a kind by value/
; lexicographic order (complex by (re,im); maps and lambdas by an alpha-invariant hash; an
; array operand broadcasts to a 0/1 mask). `=` is value equality and bridges the whole
; numeric tower; `idp` is identity; `!=` is gone -- write `!(a = b)`.
(assert
 (3 = 3.0) !(3 = 4) (1 < 1.5) (3.0 >= 3) (idp 'a 'a) !(idp '(1) '(1))
 (1 < "a") ("a" < 'x) ('x < '(0)) !("a" < 1)
 ('(0) < #(1 10)) (#(1 10) < cap) !(cap < #(1 10)))   ; the map rung: pair < map < hom

; --- comparing functions --- `=` on two functions is alpha + structural: their source \-exprs
; match up to renaming of bound variables (binders by position, free vars by name) and their
; captured values match pairwise. `<` agrees (the hash is alpha-invariant); `idp` stays
; identity. eta ((\ x (f x)) = f) and beta are *not* bridged -- a closure versus its operator is
; a representation-crossing edge that stays false. two exceptions cross into the numerals:
; 1 = (\ x x) (the identity) and 0 = (\ _ 1) (const-1), each up to alpha.
(assert
 ((\ x x) = (\ y y)) ((\ a b (+ a b)) = (\ x y (+ x y)))           ; alpha: bound vars by position
 ((\ x (+ x 1)) = (\ x (+ x 1))) !(idp (\ x (+ x 1)) (\ x (+ x 1)))  ; equal, yet distinct objects
 !((\ x x) = (\ y z)) !((\ x (+ x 1)) = (\ x (+ x 2)))             ; free /= bound; different body
 (: g (\ a (\ b (+ a b))) (&& ((g 1) = (g 1)) !((g 1) = (g 2))))   ; closures: equal iff captures match
 ((+ 1) = (+ 1)) !((\ x x) < (\ y y)) !((\ x (cap x)) = cap)           ; partial apps too; eta not bridged
 (1 = (\ x x)) ((\ y y) = 1) !(idp 1 (\ x x))                      ; 1 = identity, either side
 (0 = (\ _ 1)) ((\ q 1) = 0) !(0 = (\ _ 2)) !(0 = (\ _ _)))        ; 0 = const-1 (and only that)

; --- + and * are generic --- `+` adds numbers, concatenates strings/symbols, and appends
; lists; `-` is numeric only. the BYTE LAW: text + number is one byte, strictly -- the value
; must be an exact integer 0..255 (rep-blind, like `=`: 66.0 is 66); anything else is nil,
; like `-` on strings. `*` is repeated `+`: a sequence times a count repeats it, and the
; count SATURATES (($ c), the count law shared with numeral-apply and array shapes): a
; non-positive count gives the empty sequence, a float ceils.
(assert
 ("abcd" = "ab" + "cd") ("xB" = "x" + 66) ('efef = 'ef + 'ef) (strp ("ab" + 'ef))
 ("xB" = "x" + 66.0) !("x" + 1.5) !("x" + -66) !("x" + 256)   ; the byte law: exact 0..255 or nil
 ('(1 2 3 4) = '(1 2) + '(3 4)) ('(5 1 2) = 5 + '(1 2)) !("a" - "b")
 ("ababab" = "ab" * 3) ('xyxy = 'xy * 2) ('(1 2 1 2) = '(1 2) * 2) !("ab" * "cd")
 !("ab" * -3) ("ababab" = "ab" * 2.5) !('(1 2) * 0))

; --- numeric functions --- abs and int are type-aware; the constants are e pi i; also gcd and
; modpow. the only irreducible transcendental nifs are pow sin cos log (float; bignums widen,
; arrays map elementwise; log and pow climb tiers -- log of a negative/complex argument gives
; the complex principal value ~((log |z|) (arg z)), and a finite negative base to a non-integer
; power gives its principal root, the angle pi*e factored exactly (sinpi/cospi), so the derived
; sqrt is total: ((/ 1 2) -1) = i). everything else is *derived* from numerals
; and complex -- no nif:
;   power (k b) = b**k    sqrt ((/ 1 2) x)    exp (x e)    nth root ((/ 1 n) x)
;   tan (/ (sin x) (cos x))    atan (arg ~(1 x))    atan2 (arg ~(x y))
(assert
 (5 = (abs -5)) (fixp (abs -5)) (5.0 = (abs ~(3 4))) (2 = (int 2.9))
 (1024 = (10 2)) (21 = (gcd 1071 462)) (976371285 = (modpow 2 100 1000000007))
 (2.0 = ((/ 1 2) 4)) (1024.0 = (pow 2 10)) (1 = (0 e)) (2.718281828459045 = e))
; --- a few identities --- tetration is just the tower with one base: (3 3) = 3^3, (3 3 3) =
; 3^(3^3), (2 2 2 2) = 2^2^2^2. i*i = -1 -- the algebraic heart of euler's e^(i*pi) = -1 -- and
; e^(i*0) = 1. the textbook (-1 = i * pi e) does *not* hold forward: `=` is exact and e^(i*pi)
; carries a ~1e-16 imaginary residue, the honest price of an irrational pi in floats. read it
; backwards instead -- the principal log IS exact: atan2(0 -1) is pi by IEEE fiat and i moves
; it with exact 0/1 products, so ((log -1) = i * pi) bit-exactly. pow climbs the same way: a
; finite negative base to a non-integer power is its principal root, the angle pi*e factored
; exactly (sinpi/cospi), so ((/ 1 2) -1) = i on the nose. (i only assert what's bit-exact on
; every target: the freestanding math lib is coarser than glibc, so nothing else that pits a
; transcendental against a literal or a differently-computed transcendental.)
(assert
 (27 = (3 3)) (7625597484987 = (3 3 3)) (16 = (2 2 2)) (65536 = (2 2 2 2))   ; tetration
 (-1 = i * i) (-1 = (2 i)) (1 = ((i * 0) e))                                 ; i^2 = -1; e^(i*0) = 1
 ((log -1) = i * pi) ((log i) = i * pi / 2)                                  ; euler, in the exact direction
 (comp (log -1)) (flop (log 2)) (comp (log ~(2 3)))                          ; log widens only when it must
 (i = ((/ 1 2) -1)) (~(0 2) = ((/ 1 2) -4))                                  ; sqrt of a negative: principal, exact
 (-8 = (pow -2 3)) (comp ((/ 1 3) -8))                                       ; integer powers stay real; odd roots go principal
 (0.0 = (sin 0) / (cos 0)) (flop (sin 0)))                                   ; tan 0 = 0

; --- complex --- a discrete scalar at the top numeric tier (comp). the `~` reader sigil:
; ~(re im) builds (plex re im) (3+ operands curry); a bare ~x lifts a real (~r = ~(r 0)) or
; conjugates a complex (~~(r i) = ~(r -i)), so `~` is conjugation and an involution. i = ~(0 1).
; + - * / promote a real and stick (no demotion); order is lexicographic by (re,im) and `=`
; bridges reals. `plex` and `arg` broadcast over arrays, so the derived forms stay elementwise.
(assert
 ((* i i) = -1) (~(2 0) = 2) (~(-5 10) = ~(1 2) * ~(3 4)) (comp ~5) !(comp 5)
 (~(0 0) = ~0) ((conj ~(2 3)) = ~~(2 3)) ((conj ~(2 3)) = ~(2 -3))
 (2.0 = (re ~(2 3))) (i < 1) !(1 < i) ("~(0.0 1.0)" = (show i))
 (0.0 = (peep (arg ~(1 @(1 0))) 1 0)))           ; arg broadcasts -- (arg ~(1 x)) = atan, elementwise
; a rank-N complex array packs (re,im) into a `c`-typed array: peep yields a ~(..) box,
; + - * / broadcast numpy-style, `=` gives a mask, and asum/aprod fold complex.
(assert
 (: v (array 2 ~(1 2) ~(3 4)) (&& (c = (atype v)) (~(1 2) = (peep v 0 0)) (~(4 6) = (asum v))
    (~(2 4) = (peep (v + v) 0 0)) (~(2 4) = (peep (~(2 0) * v) 0 0)) !(v < v)
    ("@(~(1.0 2.0) ~(3.0 4.0))" = (show v)))))

; --- arrays --- (arr type shape vals) is THE typed constructor: vals 0 zero-fills, a list
; fills row-major; (array shape elem..) infers the type and curries; @(..) is a rank-1
; literal. arank/alen/ashape/atype; peep (out of bounds -> the default). + - * // < =
; broadcast numpy-style to the widest type
; (compare -> a z mask); `/` promotes the whole result to r the moment any element divides
; inexactly. reduce with asum aprod amax amin aall (a conjunction). an array nets the SUM of
; its elements ($ = max(0, ceil(asum)), like a list), so an all-zero or net-negative array
; is false. sin/cos/log/pow and the derived forms map elementwise. a 0-axis is real:
; broadcast keeps it empty (a 1-axis takes the OTHER size, 0 included), an empty
; rank-1 prints (array '(0)) (@ has no empty spelling), and EMPTY REDUCTIONS ANSWER
; THEIR MONOID UNITS -- (asum e) = 0, (aprod e) = 1, (aall e) true: the floor
; appears as the values of empty reductions.
(assert
 (6 = (alen (arr z '(2 3) 0))) (2 = (arank (arr z '(2 3) 0))) ('(2 3) = (ashape (arr z '(2 3) 0)))
 (z = (atype (arr z '(2 3) 0))) (20 = (peep @(10 20 30) 1 -1)) (-1 = (peep @(10 20 30) 9 -1))
 (3 = (peep (arr z '(2 2) '(1 2 3 4)) '(1 0) -1)) (@(11 22 33) = @(1 2 3) + @(10 20 30))
 (@(2 4 6) = @(1 2 3) * 2) (r = (atype ((arr z '(2) 0) + 1.5))) (z = (atype ((arr z '(3) 0) < 1)))
 (60 = (asum @(10 20 30))) (30 = (amax @(10 30 20))) (5 = (asum 5)) (aall (1 < 2))
 (aall (@(2.0 3.0) = ((/ 1 2) @(4.0 9.0)))) (@(3.5 5.5) = @(7 11) / 2) (@(3 5) = (// @(7 11) 2))
 (@(4 6) = @(8 12) / 2) !(arr z '(3) 0) ("@(10 20 30)" = (show @(10 20 30)))
 (aall (@(10 20 30) = (array 3 10 20 30))) !(@(1 2 3) + @(1 2)) !(arr 99 '(3) 0)
 (0 = (asum (arr z '(0) 0))) (1 = (aprod (arr z '(0) 0))) (aall (arr z '(0) 0))
 ("(array '(0))" = (show (arr z '(0) 0))) (0 = (alen ((arr z '(0) 0) + 1))))

; --- products & lists --- cons builds the product (the cartesian kind, classically the
; pair); cap and cbp take the Contents of the A/B Part of the product (no cap: you have
; reached the end of the list); caap cabp .. cbbbp are the compounds, read right to left
; like their classic c[ad]+r ancestors (which are gone, as is the X alias).
; (sort l) orders by the total order, in C (descending = rev); (msort le l)
; takes a predicate. the other higher-order functions live in the prelude.
(assert
 (1 = (cap '(1 2 3))) ('(2 3) = (cbp '(1 2 3))) (3 = (cabp '(2 3 4))) ('(1 2) = (cons 1 (cons 2 0)))
 !(cap 0) ('x = (cap 'x)) !(cbp 'x)              ; no cap at the end of the list; an atom is its own cap
 ('(2 3 4) = (map inc '(1 2 3))) (24 = (foldl (*) 1 '(1 2 3 4))) (6 = (foldr (+) 0 '(1 2 3)))
 ('(1 3) = (filter (\ x (x % 2)) '(1 2 3 4))) ('(1 2 3) = (sort '(3 1 2))) ('(3 2 1) = (msort (>) '(1 2 3)))
 ('(1 2 3 4) = (cat '(1 2) '(3 4))) ('(3 2 1) = (rev '(1 2 3))) ('(1 2) = (map cap (zip '(1 2) '(3 4))))
 (20 = (cabp (assq 2 (list (L 1 10) (L 2 20))))) ('(1 2) = (take 2 '(1 2 3 4))) ('(3 4) = (drop 2 '(1 2 3 4)))
 (3 = (last '(1 2 3))) ('(1 2) = (init '(1 2 3))) (memq 3 '(1 2 3)) !(memq 9 '(1 2 3))
 (all (\ x (0 < x)) '(1 2 3)) (any (\ x (2 < x)) '(1 2 3)) (3 = $'(a b c)))

; --- strings & symbols --- a symbol is interned ('x), named-uninterned ($x = (nom 'x)), or
; anonymous ((nom 0)). `()` is THE empty symbol -- one canonical value, (intern ""), the
; `+`-identity on symbols, self-evaluating, false by !!$ -- but a symbol, NOT the number 0.
; every nom draws a MINT SERIAL from the one mint stream (task pids draw from it too):
; symbols order by name first (the nameless below every named), then the interned one
; (the canonical point precedes the fresh), then by serial -- creation order -- so the
; total order is TOTAL over symbols, GC-stable; the serial is also the nom's hash, so
; same-name noms key a map apart.
; a string indexes its bytes ("abc" 0 -> 97). $ (sat) clamps the net measure once,
; max(0, ceil(net)): a string's byte count, a symbol's name length, a number's own value
; ($-3.9 = 0), a list's or array's element sum -- so $ and abs diverge ((abs -5) = 5 but
; $-5 = 0, and $@(3 4) = 7 where (abs @(3 4)) is the norm 5).
; slice takes a half-open slice; + concatenates ("" is the identity; scat is gone); string
; coerces; \n escapes.
(assert
 (symp ()) !(() = 0) (idp () (intern "")) (idp () '()) (0 = $()) !() !!$'x
 ('x = () + 'x) ("()" = (show ()))
 (: a (nom 'x) b (nom 'x) (&& (a < b) !(b < a) !(a = b)))   ; the serial: creation order, trichotomy holds
 ('x < (nom 'x)) (() < (nom 0))                  ; interned first on a name tie; the floor below the fresh
 (: a (nom 'k) b (nom 'k) t #() _ (pin t a 1) _ (pin t b 2)
    (&& (1 = (t a)) (2 = (t b)) (2 = $t)))      ; same-name noms are distinct map keys
 (97 = ("abc" 0)) (3 = $"abc") (4 = $3.9) (0 = $-3.9) (7 = $@(3 4)) (5 = (abs -5)) (5.0 = (abs @(3 4)))
 ("bidden" = (slice "forbidden planet" 3 9)) ("abcd" = (+ "ab" "cd")) (1 = ("hi" 9))
 ('asdf = (intern "asdf")) !((nom 0) = (nom 0)) ("asdf" = (string 'asdf))
 ("\"a\\nb\"" = (show "a\nb")) ("$x" = (show (nom "x"))))

; --- hashes --- #(k v ..) or (hash ..) build; #() is the empty hash -- ONLY #(); mutable.
; # on a scalar BOXES it: #x = #(() x), a fresh mutable hash pinning x to the () key (a 1-entry
; box, truthy -- the dead () = 0 identity used to conflate #0 with empty). the accessors are
; collection-first: (peep coll k default) reads, (pin coll k v) sets, (pull coll k default) removes-
; and-returns. peep and pull share the default-if-absent fallback; only pull mutates a key away.
; also keys (the key list), $ is the key count. (t k) == (peep t k 0) -- a map is a lookup
; function. (dig k) digests any key to a fixnum. a hash is MUTABLE, so `=` on hashes is
; identity (like buffers); infix, the accessors are (t <- k v) and (t -> k d).
(assert
 (: b #0 (&& (mapp b) (1 = $b) (0 = (peep b () 9)) (: _ (pin b () 7) (7 = (b ())))))
 (: t #(1 10 2 20) (&& (20 = (peep t 2 0)) (20 = (t 2)) (99 = (peep t 9 99))))
 (50 = (peep (pin #() 5 50) 5 0)) (: t #(1 10 2 20) _ (pull t 1 0) (1 = $t))
 (: t #(1 10 2 20) v (pull t 2 0) (&& (20 = v) (1 = $t) (99 = (peep t 2 99)) (-1 = (pull t 9 -1))))  ; pull: value or default, removes the key
 ('(1 2) = (sort (keys #(1 10 2 20)))) ((dig 'k) = (dig 'k)) (mapp #()) !(mapp 5)
 !(#(1 10) = #(1 10)) (: t #(1 10) (t = t))      ; mutable -> identity =
 (40 = (: t #(1 10) _ (t <- 4 40) (t -> 4 0))))  ; the infix accessors

; --- buffers --- (buf n) gives n mutable zeroed bytes; $/peep/pin a byte (0..255); blit;
; identity equality.
(assert
 (: b (buf 3) _ (pin b 0 65) (65 = (peep b 0 0))) (4 = $(buf 4))
 (: b (buf 1) _ (pin b 0 257) (1 = (peep b 0 0))) (: b (buf 4) _ (blit b 0 "ABCD" 0 4) (68 = (peep b 3 0)))
 !((buf 2) = (buf 2)))

; --- reader operators --- `;` line comment, `#!` pinbang (no block comments). reading is
; STRUCTURAL and environment-free: the reader knows tokens, parens, strings, and the value
; surface -- ' quote (= one-operand \), ` quasiquote, , unquote, ,@ splice, # hash, @ tup
; (array), ~ wave (complex/conjugate: ~(re im) splices to (plex re im), a bare ~x is
; (clift x)) -- and NO operator tables, so the same reader serves data (read) and code.
; the LEXER LAW splits tokens by leading char: a name token (alnum/_) keeps - ? ! etc
; inside (kebab law unchanged), while a punctuation-led token is a SIGIL -- a maximal run
; of operator chars, read as ONE PLAIN SYMBOL (value-surface chars and delimiters break
; the run). code then factors sigils against the ONE `operators` table at COMPILE time:
; `opfix`, a source->source prepass hooked by both compilers (c0 probes dict['opfix] like
; boxfix; ev runs it before wev -- ev is opfix after read, so the two input lanes, data
; and characters, meet at one core). the table: symbol -> arity (the symbol names itself)
; | (name . arity) (an alias), arity 1-7, extended with a plain pin -- live for the next
; form, since opfix probes at compile time (see test/operator.l, test/infixop.l).
; the FACTORIZATION LAW: greedy longest-prefix, no backtracking; every factor but the
; last must be arity ONE (a prefix on the next datum, never capturing left); the
; last factor takes the positional valence -- with a left operand it captures it and
; collects arity-1 more, nesting RIGHT-associatively; with none it reads plain, so
; (+ 1 2), '+, and (+)-as-a-value still work. a token that doesn't factor is a plain
; symbol (&&, >>=, :-, ?- stay atomic); != factors to ! and =, !! double-negates. a
; sigil at one binds TIGHTEST (folds the moment its operand lands), so $"ab" + 2 is
; (+ ($ "ab") 2); only infix defers, which is what makes it right-associative. the
; CURRY LAW: operands missing at the end of a list fold to the partial application.
; quote interiors are DATA -- operators inside ' stay plain symbols; quasiquote descends
; only through unquotes. shipped at one: $ sat, ! nilp, . dot; at two: + - * / %
; = < <= > >= | &; ? at three -- the cond form infix, (t ? a b); aliases: <- pin and
; -> peep, collection-first -- (t <- k v) pins (giving back t, so it chains), (t -> k d)
; peeps. (1 + 2) factors to ((+ 1 2)) and evaluates via (f) == f.
(assert
 ('(1 (\ x) 3) = `(1 'x 3)) ('(1 2 3 4) = (: xs '(2 3) `(1 ,@xs 4)))
 (5 = $"hello") (42 = $42) (symp (gsym x)) (1 = !0) (0 = !5) !!5
 (i = ~(0 1)) (~(2 3) = (plex 2 3)) ('~x = '(clift x)) (homp dot)
 ('((dot x)) = (opfix '(. x))) ('! = (cabp '(a ! b)))   ; opfix factors; quotes stay data
 (3 = 1 + 2) (7 = 1 + 2 * 3) ('b = 0 ? 'a 'b) ('big = (1 < 2) ? 'big 'small)
 (1 = (3 != 4)) (0 = (3 != 3))                   ; the factorization law: != = ! of =
 (4 = ($"ab" + 2))                               ; one binds tightest: (+ ($ "ab") 2)
 (3 = ((1 +) 2))                                 ; the curry law: (1 +) folds to (+ 1)
 (20 = (#(1 10 2 20) -> 2 0)) (7 = ((#() <- 'k 7) 'k)) (9 = (#() -> 'k 9))
 (12 = (foldl (+) 0 '(3 4 5)))
 (: t operators
    (&& (mapp t) (2 = (t '+)) (3 = (t '?)) (2 = (t '%))
        ((cons 'sat 1) = (t '$)) ((cons 'nilp 1) = (t '!))
        ((cons 'pin 3) = (t '<-)) ((cons 'peep 3) = (t '->)))))

; --- macros --- a macro maps an argument list to code; install with `::`. the prelude ships
; do/let/if/cond/quote, && and || (short-circuiting), L/list, tuple/map/array, the body-first
; :- and ?-, and the pipes >>= <=<.
(:: 'unless (\ a `(? ,(cap a) 0 ,(cabp a))))
(assert
 ('ok = (unless 0 'ok)) (0 = (unless 1 'ok)) (3 = (&& 1 2 3)) !(&& 1 0 3)
 (2 = (|| 0 2 3)) ('(1 2 3) = (L 1 2 3)) (6 = (do 1 2 6)) (3 = (let a 1 b 2 (a + b)))
 (3 = (:- (a + b) a 1 b 2)) ('big = (?- 'else (1 < 2) 'big)) (9 = ((<=< inc (\ x (x * 2))) 4)))

; --- control --- ev compiles and runs; call-cc is a one-shot escape; tasks are
; spawn/wait/yield/sleep/done?/kill/key?; the RNG is xoshiro256++: C ships only rng-seed and
; the pure rand-next/randf-next over explicit state -- the global rand/randf stream is
; prelude lisp over hidden rng state. a global `trap` function receives every
; throw as (trap s a b) -- s = the status word, two bits: scare (1, something wrong) and
; more (2, read control flow); more alone = incomplete, eof = more|scare. a/b = the
; condition data; the result is delivered per the bits (the more bit: to the reader's
; resume; a bare scare: observed). scare?/more?/eof? read s. (scare a b) raises
; deliberately -- the scare bit set unconditionally, and the trap's result comes back
; as its value (no trap installed -> terminal). see test/trap.l. numeral counts are
; CAPPED: a compose count or exact-power exponent above the `apcap` box (a public
; runtime tunable, default 2^20) raises (scare 'apcap k) instead of allocating O(k) --
; (bignum f) traps where it would oom. retune with (pin apcap () n); see test/apcap.l.
(assert
 (3 = (ev '(+ 1 2))) (homp ev) (41 = (call-cc (\ k (k 41)))) (42 = 1 + (call-cc (\ k 41)))
 (42 = (: p (spawn (\ x (do (yield 0) (x + 1))) 41) (wait p))) (0 = (wait 99999)) (done? 99999)
 !(sleep 0) (4 = (alen (rng-seed 1))) ((rand 10) < 10) (flop (randf 0))
 (scare? 1) !(scare? 3) (eof? 3) !(eof? 2) (more? 2) !(more? 3) (homp scare)
 (mapp apcap) (1048576 = (apcap ()))             ; the count ceiling, a tunable box
 (: st (rng-seed 7) ((cap (rand-next st)) = (cap (rand-next st)))))

; --- i/o & ports --- `in`/`out` are the default ports; the prelude wraps getc and
; putc/puts/putn/putx, with per-port fgetc/fputc/.../read plus open/close/sip/pad/slurp.
; `read` (the renamed fread) is port-first -- (read in x) -- and reads one datum per
; call; its end conditions route through the trap continuation via
; the status more bit, and the default trap delivers a sentinel at EOF, the port back when
; incomplete (a global `trap` function takes over that dispatch). `dot` (the `.` operator)
; prints x to `out` -- raw bytes for a string, else the show form -- and returns
; x, so .x taps a value mid-expression.
(assert
 (strp (show out)) ("hi" = (slurp (sip '(104 105)))) (: o (pad 0) _ (fputx o 42) ("42" = (page o)))
 (1 = (read (sip '(49)) 99)) ('eof = (read (sip 0) 'eof)) (: p (sip '(40)) (p = (read p 99))))

; --- bootstrapping --- the C core is minimal; the key semantics are l closures installed
; from the prelude and shared by both compilers:
;   numap -- fixnum/number application (x**n, or compose ($ n) times), an n-fold text.
;   scomb/bcomb -- `+` and `*` of functions are church add and compose, so numerals agree.
;   opfix -- the operator factor pass (see reader operators above): sigil surface -> core
;     source, run FIRST, one source of truth shared with the C bootstrap compiler.
;   boxfix -- the letrec* "capture by location" rewrite; now a wev source pass run after
;     macroexpansion, one source of truth shared with the C bootstrap compiler.
;   wev -- the source->source pre-pass before analysis: expand macros, apply boxfix, fold pure
;     globals, mark apply strategy, and flip (? !e a b) to (? e b a).
;   maps -- #(..)/map expand to nested pins; a map is a lookup function.
; the *egg* (love/egg.l): the evaluator SITS on the egg (the quoted prelude+ev corpus) twice --
; compile the compiler with the C bootstrap, recompile the whole corpus through itself -- and
; the hatchling installs as `ev`, baked into the image at C compile time, no allocation;
; `born` records the hatch time (unbound pre-egg: love0's first corpus pass runs PRE-egg,
; and an absent global reads as nil). before it is born the egg PULLS every runtime-
; internal name: the raw cell nifs (peek poke seek lamb -- (lamb 2 3) is a segfault, big
; scare; lamb is still there for real, it's ultimate), tally (the spine length of a list,
; blind to its elements -- the compiler's frame arithmetic runs on it; $ sums the
; elements' nets, so post-birth code wanting a structural length folds), the compiler's machinery
; (boxfix, wev, the num-ap and array-ctor helpers, the macro expanders -- the macro TABLE
; lives on inside the compiler's closures), the repl sentinels, every hot lvm_* pointer,
; and finally `dict` itself. compiled references were folded, so only the names die.
; names the printer or an expander EMITS (uq ltuple cons pin table ..) stay, as do the
; C-resolved hooks (num-ap scomb bcomb trap) and the repl's test-driven editor surface.
(assert (homp ev) (? born (fixp born) 1)
        (? born !macros 1) (? born !poke 1)     ; post-birth the names are gone
        (? born !boxfix 1) (? born !lvm_ret 1) ; (pre-egg they still exist,
        (? born !lamb 1) (? born !dict 1))      ;  hence the born guards)

; --- under the hood --- a generic op dispatches on a value's kind (an enum whose order is the
; lattice above). an op at two is an NxN table indexed by the two kinds; an op at one is its
; diagonal; the three core tables are + , * , and apply. a both-fixnum fast path skips the
; table; otherwise one indexed jump picks a lane that widens only as far as the operands need
; (array, complex, bignum, float, ...). the VM is tail-threaded over a two-space copying
; collector; out-of-pool constants are immortal. the love/ layer (prelude ev repl cli egg) bakes
; into every frontend: the host (out/host/love), the freestanding kernel (x86_64/aarch64),
; and wasm. build codegen lives in love under tools/; the C is
; freestanding, -Wall -Wextra -Werror.

; --- odds & ends --- show renders a value as its reparsable printed form; (clock t) is
; milliseconds since t and (gauge 0) reports a VM stat. an opaque handle acts as a constant
; function -- applying it ignores the argument.
(assert (strp (show @(1 2 3))) (fixp (clock 0)) (1 = ((buf 4) 'x)))
