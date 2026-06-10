; ll -- a small lisp where every value is a monadic, auto-curried function.
; a portable C runtime (ll.c + ll.h) plus a self-hosting compiler written in ll
; (the ll/{prelude,ev,repl}.l layers). source is .l; the host binary is `ll`. see README.md.
; this file is the spec *and* a real test -- CLAUDE.md is just it wrapped in a code fence, so
; i rewrite here and re-wrap by hand. keep it green; when in doubt, this is the truth.

; --- the shape of it --- one cell is one word: a fixnum is a tagged odd word, anything else
; is a heap object whose first word is its handler. the VM is tail-threaded (handlers
; tail-jump, never return -- `make vmret` checks it) over a two-space copying heap. every
; operation is *fully generic* -- it dispatches on a value's *kind*, and the kinds form a
; lattice (next) that is literally the diagonal of the dispatch tables. the C core is tiny;
; most of the language is ll closures installed reflectively from the prelude, then baked
; into a heap image (the *egg*) at compile time. the gritty details sit at the bottom.

; --- the type lattice --- two axes. the *tier* spine, low to high:
;   N naturals (the range of #)  <  Z integers (fixnum -> wide box -> bignum)
;     <  R reals (float)  <  C complex  <  O objects (string < symbol < pair < map < lambda)
; numbers nest as usual (N in Z in R in C). the *rank* axis is scalar (0) vs array (>= 1, one
; per tier: arrZ/R/C/O). the total order < is this lattice flattened: fixnum < box < bignum <
; float < complex < string < symbol < pair < map < lambda. opaque handles (buf/port/thread)
; live off the lattice -- false, compared by identity, and they act like functions. every
; predicate ends in `p`; they are enumerated below.

; --- everything is a function --- (f x y) == ((f x) y) and (f) == f, so application is just
; left-to-right currying. numbers are church numerals, a list of numbers is an exponential
; tower, and data self-applies (indexes). the two pillars come first:
(assert
 (= 1 (0 5)) (= 5 (1 5))                         ; 0 is const-1, 1 is the identity
 (= 8 (3 2)) (= 262144 (2 3 4))                  ; (n x) = x**n; the tower (2 3 4) = 4**(3**2)
 (= 12 (3 (+ 1) 9)) (= '(2 3 4) (map (+ 1) '(1 2 3)))  ; (n f) composes f n times; currying *is* partial application
 (= 0.5 (-1 2)) (= 3.0 ((/ 1 2) 9)))            ; (-1 x) = 1/x; (1/2 x) = sqrt x

; --- build & test --- `make test` is the default task and the commit gate: it builds
; out/host/ll and runs test/*.l through both `ll` and the self-hosted `ll0`. `make repl` for a
; prompt; `make test_all` adds the kernel and tool diffs; `make catav` before committing. one
; file at a time: `out/host/ll test/CLAUDE.l`. tests concatenate into one global scope, so keep
; helpers local (give `:` a body). footgun: edit ll.h and you must `make clean` or ll0 hangs.

; --- three special forms --- `:` is letrec*/sequence, `?` is cond, `\` is lambda (and, with a
; single operand, quote). everything else is a function call.
(assert
 (= 3 (: a 1 b 2 (+ a b)))                       ; `:` binds in source order; the last form is the result
 (= 7 ((\ x y (+ x y)) 3 4))                     ; `\ args.. body` -- a lambda, auto-curried
 (= '(1 2) (\ (1 2)))                            ; one operand: `\` is quote, so 'x is just (\ x)
 (= 'big (? 0 'a (< 1 2) 'big 'else)))           ; `?` -- test/result pairs, then a final else
; `:` doubles as sequencing (bind `_` for effect); `(f x)` on the left is define-sugar; a
; body-less top-level `:` leaks its bindings to the global scope (that's how tests share helpers).
(: (twice f x) (f (f x)) (assert (= 12 (twice inc 10))))

; --- true and false --- false is *nothing*: a scalar that sorts <= 0 in the total order, an
; empty container, or an array of zero norm. everything positive/nonempty is true. there is no
; "truthy"/"falsy" -- true and false are the bits 1 and 0 of the `!!$` projection. `$` (sat) measures
; a value (its size/magnitude, 0 when empty or <= 0); `!` is the falsity oracle, with the
; invariant !x == (= 0 $x). so `!!$x` is x's truth bit and `!` negates it.
(assert
 !0 !"" !#() !@0 !() !0.0 !~(0 0)                ; zero / empty -> false
 !-5 !-3.9 !~(-3 4) !~(0 -1)                     ; <= 0 in the total order -> false (complex by re then im)
 !!5 !!"x" !!'a !!A !!i !!~(3 -4) !!@(-3 -4)     ; positive / nonempty / nonzero-norm -> true
 (= 1 !!$5) (= 0 !!$0) (= 0 !!$-3)               ; !!$ is the truth bit (1 true, 0 false)
 (= 0 !5) (= 1 !0)                               ; ! negates it
 (= !"" (= 0 $"")) (= !-5 (= 0 $-5)))            ; the invariant !x == (= 0 $x)

; --- types & predicates --- a fixnum is a tagged word; everything else is a heap object whose
; first word dispatches. the storage predicates:
;   fixp bigp boxp  -- the integer reps (fixnum, bignum, wide-int box)
;   flop comp arrp  -- float, complex scalar, array; all three share one heap type, `tupp`
;   strp symp twop mapp lamp  -- string, symbol, pair, map, lambda
; derived: `nump` (any number: fix/box/big/float/complex/array), `intp` (any integer), `atomp`
; (anything but a pair). `i` is ~(0 1). one real gap: opaque handles (buf/port/thread) have no
; predicate of their own and answer `lamp` (they act as functions). `!` (nilp) and `done?` are
; truth/task tests, not type tests.
(assert
 (fixp 5) (twop '(1 2)) (strp "hi") (symp 'x) (lamp A) (mapp #(1 2))
 (bigp (100 2)) (boxp (62 2)) (flop 1.5) (comp i) (arrp @(1 2 3)) (tupp 1.5)
 (nump 1.5) (nump i) (nump (62 2)) (intp (62 2)) (atomp 'x) !(atomp '(1))
 (lamp (bufnew 4))                               ; an opaque handle answers lamp -- the predicate gap
 (= (64 2) (* 2 (63 2)))                         ; fixnum overflow -> exact bignum ((k b) = b**k)
 (= 5.0 (abs ~(3 4))) (= ~(2.0 3.0) (+ 2 (* 3 i))))  ; mixed arithmetic widens to the higher tier

; --- arithmetic --- + - * / // mod. fixnum fast path; a float makes it float; integer overflow
; grows fixnum -> wide box -> bignum; a non-number gives nil. `/` is *true* division -- an
; inexact integer quotient promotes to float ((/ 1 2) is 0.5) but an exact one stays integer
; ((/ 4 2) is 2); /0 gives IEEE inf/nan. `//` truncates toward zero (the partner of `mod`).
; bitwise << >> & | ^ on integers (complement is (^ x -1)).
(assert
 (= 3 (+ 1 2)) (= 2.5 (/ 5 2)) (= 2 (// 5 2)) (= 0.5 (/ 1 2)) (= 1 (mod 5 2)) (= 3.5 (+ 1 2.5))
 (= 2 (/ 4 2)) (fixp (/ 4 2)) (= -2 (// -5 2))
 !(fixp (* 2 2305843009213693952)) (flop (/ 1 0)) (< 1e308 (/ 1 0)) !(= (/ 0 0) (/ 0 0))
 (= -2 (^ 1 -1)) (= 15 (| 8 (| 4 (| 2 1)))) (= 16 (>> 64 2)) (= 16 (<< 2 3)))

; --- order & equality --- < <= > >= is a *total order over all values*: across kinds by the
; lattice (number < string < symbol < pair < lambda), within a kind by value/lexicographic
; order (complex by (re,im); lambdas by an alpha-invariant hash; an array operand broadcasts to
; a 0/1 mask). `=` is value equality and bridges the whole numeric tower; `idp` is identity;
; `!=` is gone -- write `!(= ..)`.
(assert
 (= 3 3.0) !(= 3 4) (< 1 1.5) (>= 3.0 3) (idp 'a 'a) !(idp '(1) '(1))
 (< 1 "a") (< "a" 'x) (< 'x '(0)) !(< "a" 1))

; --- comparing functions --- `=` on two functions is alpha + structural: their source \-exprs
; match up to renaming of bound variables (binders by position, free vars by name) and their
; captured values match pairwise. `<` agrees (the hash is alpha-invariant); `idp` stays
; identity. eta ((\ x (f x)) = f) and beta are *not* bridged -- a closure versus its operator is
; a representation-crossing edge that stays false. two exceptions cross into the numerals:
; 1 = (\ x x) (the identity) and 0 = (\ _ 1) (const-1), each up to alpha.
(assert
 (= (\ x x) (\ y y)) (= (\ a b (+ a b)) (\ x y (+ x y)))           ; alpha: bound vars by position
 (= (\ x (+ x 1)) (\ x (+ x 1))) !(idp (\ x (+ x 1)) (\ x (+ x 1)))  ; equal, yet distinct objects
 !(= (\ x x) (\ y z)) !(= (\ x (+ x 1)) (\ x (+ x 2)))             ; free /= bound; different body
 (: g (\ a (\ b (+ a b))) (&& (= (g 1) (g 1)) !(= (g 1) (g 2))))   ; closures: equal iff captures match
 (= (+ 1) (+ 1)) !(< (\ x x) (\ y y)) !(= (\ x (A x)) A)           ; partial apps too; eta not bridged
 (= 1 (\ x x)) (= (\ y y) 1) !(idp 1 (\ x x))                      ; 1 = identity, either side
 (= 0 (\ _ 1)) (= (\ q 1) 0) !(= 0 (\ _ 2)) !(= 0 (\ _ _)))        ; 0 = const-1 (and only that)

; --- + and * are generic --- `+` adds numbers, concatenates strings/symbols (a number is one
; byte), and appends lists; `-` is numeric only. `*` is repeated `+`: a sequence times a count
; repeats it.
(assert
 (= "abcd" (+ "ab" "cd")) (= "xB" (+ "x" 66)) (= 'efef (+ 'ef 'ef)) (strp (+ "ab" 'ef))
 (= '(1 2 3 4) (+ '(1 2) '(3 4))) (= '(5 1 2) (+ 5 '(1 2))) !(- "a" "b")
 (= "ababab" (* "ab" 3)) (= 'xyxy (* 'xy 2)) (= '(1 2 1 2) (* '(1 2) 2)) !(* "ab" "cd"))

; --- numeric functions --- abs and int are type-aware; the constants are e pi i; also gcd and
; modpow. the only irreducible transcendental nifs are pow sin cos log (float; bignums widen,
; arrays map elementwise). everything else is *derived* from numerals and complex -- no nif:
;   power (k b) = b**k    sqrt ((/ 1 2) x)    exp (x e)    nth root ((/ 1 n) x)
;   tan (/ (sin x) (cos x))    atan (arg ~(1 x))    atan2 (arg ~(x y))
(assert
 (= 5 (abs -5)) (fixp (abs -5)) (= 5.0 (abs ~(3 4))) (= 2 (int 2.9))
 (= 1024 (10 2)) (= 21 (gcd 1071 462)) (= 976371285 (modpow 2 100 1000000007))
 (= 2.0 ((/ 1 2) 4)) (= 1024.0 (pow 2 10)) (= 1 (0 e)) (= 2.718281828459045 e))
; --- a few identities --- tetration is just the tower with one base: (3 3) = 3^3, (3 3 3) =
; 3^(3^3), (2 2 2 2) = 2^2^2^2. i*i = -1 -- the algebraic heart of euler's e^(i*pi) = -1 -- and
; e^(i*0) = 1. the textbook (= -1 (* i pi e)) does *not* hold: `=` is exact and e^(i*pi) carries
; a ~1e-16 imaginary residue, the honest price of an irrational pi in floats. (i only assert
; what's bit-exact on every target: the freestanding math lib is coarser than glibc, so nothing
; that pits a transcendental against a literal or a differently-computed transcendental.)
(assert
 (= 27 (3 3)) (= 7625597484987 (3 3 3)) (= 16 (2 2 2)) (= 65536 (2 2 2 2))   ; tetration
 (= -1 (* i i)) (= -1 (2 i)) (= 1 ((* i 0) e))                               ; i^2 = -1; e^(i*0) = 1
 (= 0.0 (/ (sin 0) (cos 0))) (flop (sin 0)))                                 ; tan 0 = 0

; --- complex --- a discrete scalar at the top numeric tier (comp). the `~` reader sigil:
; ~(re im) builds (com re im) (3+ operands curry); a bare ~x lifts a real (~r = ~(r 0)) or
; conjugates a complex (~~(r i) = ~(r -i)), so `~` is conjugation and an involution. i = ~(0 1).
; + - * / promote a real and stick (no demotion); order is lexicographic by (re,im) and `=`
; bridges reals. `com` and `arg` broadcast over arrays, so the derived forms stay elementwise.
(assert
 (= (* i i) -1) (= ~(2 0) 2) (= (* ~(1 2) ~(3 4)) ~(-5 10)) (comp ~5) !(comp 5)
 (= ~(0 0) ~0) (= (conj ~(2 3)) ~~(2 3)) (= (conj ~(2 3)) ~(2 -3))
 (= 2.0 (re ~(2 3))) (< i 1) !(< 1 i) (= "~(0.0 1.0)" (inspect i))
 (= 0.0 (peek (arg ~(1 @(1 0))) 1 0)))            ; arg broadcasts -- (arg ~(1 x)) = atan, elementwise
; a rank-N complex array packs (re,im) into a `c`-typed array: peek yields a ~(..) box,
; + - * / broadcast numpy-style, `=` gives a mask, and asum/aprod fold complex.
(assert
 (: v (array 2 ~(1 2) ~(3 4)) (&& (= c (atype v)) (= ~(1 2) (peek v 0 0)) (= ~(4 6) (asum v))
    (= ~(2 4) (peek (+ v v) 0 0)) (= ~(2 4) (peek (* ~(2 0) v) 0 0)) !(< v v)
    (= "@(~(1.0 2.0) ~(3.0 4.0))" (inspect v)))))

; --- arrays --- (arr type shape) zeros; (arrl type shape vals) fills; (array shape elem..)
; infers the type and curries; @(..) is a rank-1 literal. arank/alen/ashape/atype; peek
; (out of bounds -> the default). + - * // < = broadcast numpy-style to the widest type
; (compare -> an i8 mask); `/` promotes the whole result to f64 the moment any element divides
; inexactly. reduce with asum aprod amax amin aall (a conjunction; "any nonzero" is just `#`).
; a zero-norm array is false. sin/cos/log/pow and the derived forms map elementwise.
(assert
 (= 6 (alen (arr i64 '(2 3)))) (= 2 (arank (arr i64 '(2 3)))) (= '(2 3) (ashape (arr i64 '(2 3))))
 (= i64 (atype (arr i64 '(2 3)))) (= 20 (peek @(10 20 30) 1 -1)) (= -1 (peek @(10 20 30) 9 -1))
 (= 3 (peek (arrl i64 '(2 2) '(1 2 3 4)) '(1 0) -1)) (= @(11 22 33) (+ @(1 2 3) @(10 20 30)))
 (= @(2 4 6) (* @(1 2 3) 2)) (= f64 (atype (+ (arr i32 '(2)) 1.5))) (= i8 (atype (< (arr i64 '(3)) 1)))
 (= 60 (asum @(10 20 30))) (= 30 (amax @(10 30 20))) (= 5 (asum 5)) (aall (< 1 2))
 (aall (= @(2.0 3.0) ((/ 1 2) @(4.0 9.0)))) (= @(3.5 5.5) (/ @(7 11) 2)) (= @(3 5) (// @(7 11) 2))
 (= @(4 6) (/ @(8 12) 2)) !(arr i64 '(3)) (= "@(10 20 30)" (inspect @(10 20 30)))
 (aall (= @(10 20 30) (array 3 10 20 30))) !(+ @(1 2 3) @(1 2)) !(arr 99 '(3)))

; --- pairs & lists --- X is cons, A is car, B is cdr; AA AB .. BBB are the compounds.
; cons/car/cdr/cadr.. are prelude aliases. the higher-order functions live in the prelude.
(assert
 (= 1 (A '(1 2 3))) (= '(2 3) (B '(1 2 3))) (= 3 (AB '(2 3 4))) (= '(1 2) (X 1 (X 2 0)))
 (= 1 (car '(1 2 3))) (= 3 (cadr '(2 3 4)))
 (= '(2 3 4) (map inc '(1 2 3))) (= 24 (foldl (*) 1 '(1 2 3 4))) (= 6 (foldr (+) 0 '(1 2 3)))
 (= '(1 3) (filter (\ x (mod x 2)) '(1 2 3 4))) (= '(1 2 3) (sort (<) '(3 1 2)))
 (= '(1 2 3 4) (cat '(1 2) '(3 4))) (= '(3 2 1) (rev '(1 2 3))) (= '(1 2) (map A (zip '(1 2) '(3 4))))
 (= 20 (AB (assq 2 (list (L 1 10) (L 2 20))))) (= '(1 2) (take 2 '(1 2 3 4))) (= '(3 4) (drop 2 '(1 2 3 4)))
 (= 3 (last '(1 2 3))) (= '(1 2) (init '(1 2 3))) (memq 3 '(1 2 3)) !(memq 9 '(1 2 3))
 (all (\ x (< 0 x)) '(1 2 3)) (any (\ x (< 2 x)) '(1 2 3)) (= 3 $'(a b c)))

; --- strings & symbols --- a symbol is interned ('x), named-uninterned ($x = (nom 'x)), or
; anonymous ((nom 0)). `()` is THE empty symbol -- one canonical value, (intern ""), the
; `+`-identity on symbols, self-evaluating, false by !!$ -- but a symbol, NOT the number 0.
; a string indexes its bytes ("abc" 0 -> 97). $ (sat) is a *saturating* size:
; a container's count, a symbol's name length, a number's ceil-magnitude clamped to >= 0
; ($-3.9 = 0), or an array's ceil L2 norm -- so # and abs diverge ((abs -5) = 5 but $-5 = 0).
; ssub takes a half-open slice; scat concatenates ("" is the identity); string coerces; \n escapes.
(assert
 (symp ()) !(= () 0) (idp () (intern "")) (idp () '()) (= 0 $()) !() !!$'x
 (= 'x (+ () 'x)) (= "()" (inspect ()))
 (= 97 ("abc" 0)) (= 3 $"abc") (= 4 $3.9) (= 0 $-3.9) (= 5 $@(3 4)) (= 5 (abs -5))
 (= "bidden" (ssub "forbidden planet" 3 9)) (= "abcd" (scat "ab" "cd")) (= 1 ("hi" 9))
 (= 'asdf (intern "asdf")) !(= (nom 0) (nom 0)) (= "asdf" (string 'asdf))
 (= "\"a\\nb\"" (inspect "a\nb")) (= "$x" (inspect (nom "x"))))

; --- hashes --- #(k v ..) or (hasht ..) build; #() or (hashn 0) is empty -- ONLY #(); mutable.
; # on a scalar BOXES it: #x = #(() x), a fresh mutable hash pinning x to the () key (a 1-entry
; box, truthy -- the dead () = 0 identity used to conflate #0 with empty). the accessors are
; collection-first: (peek coll k default) reads, (pin coll k v) sets, (pull coll k default) removes-
; and-returns. peek and pull share the default-if-absent fallback; only pull mutates a key away.
; also hashd, hashk (the keys), $ is the key count. (t k) == (peek t k 0) -- a map is a lookup
; function. (hash k) hashes a key.
(assert
 (: b #0 (&& (mapp b) (= 1 $b) (= 0 (peek b () 9)) (: _ (pin b () 7) (= 7 (b ())))))
 (: t #(1 10 2 20) (&& (= 20 (peek t 2 0)) (= 20 (t 2)) (= 99 (peek t 9 99))))
 (= 50 (peek (pin #() 5 50) 5 0)) (: t #(1 10 2 20) _ (hashd 0 t 1) (= 1 $t))
 (: t #(1 10 2 20) v (pull t 2 0) (&& (= 20 v) (= 1 $t) (= 99 (peek t 2 99)) (= -1 (pull t 9 -1))))  ; pull: value or default, removes the key
 (= 2 $(hashk #(1 10 2 20))) (= (hash 'k) (hash 'k)) (mapp #()) !(mapp 5))

; --- buffers --- (bufnew n) gives n mutable zeroed bytes; # /peek/pin a byte (0..255); bcopy;
; identity equality.
(assert
 (: b (bufnew 3) _ (pin b 0 65) (= 65 (peek b 0 0))) (= 4 $(bufnew 4))
 (: b (bufnew 1) _ (pin b 0 257) (= 1 (peek b 0 0))) (: b (bufnew 4) _ (bcopy b 0 "ABCD" 0 4) (= 68 (peek b 3 0)))
 !(= (bufnew 2) (bufnew 2)))

; --- reader operators --- `;` line comment, `#!` pinbang (no block comments). a PREFIX
; operator char reads its next N datums and desugars to (name d1 .. dN); the table is
; dict['operators] (char -> name | (name . arity), arity 1-7) -- extensible with a plain
; pin (see test/operator.l). seven ship at arity 1 (glyph / name): $ sat (saturation), # hasht (hash table),
; ' quote (= one-operand \), ! bang (negation), . dot (print), @ tup
; (array), ` quasiquote. % is infix mod. , unquote, ,@ splice, and ~ wave (complex/conjugate)
; stay reader digraphs. ~(re im) splices to (com re im); a bare ~x is (clift x).
; INFIX operators are all-punct symbols in dict['infix] (symbol -> arity): with a left
; operand available the symbol captures it and collects arity-1 more, nesting RIGHT-
; associatively; with no left operand it reads as the plain symbol, so (+ 1 2), '+, and
; (+)-as-a-value still work. + - * / = < <= > >= | & ship dyadic and ? ternary -- the
; cond form infix, (t ? a b). (1 + 2) reads ((+ 1 2)) and evaluates via (f) == f.
; see test/infixop.l.
(assert
 (= '(1 (\ x) 3) `(1 'x 3)) (= '(1 2 3 4) (: xs '(2 3) `(1 ,@xs 4)))
 (= 5 $"hello") (= 42 $42) (symp (gsym x)) (= 1 !0) (= 0 !5) !!5
 (= i ~(0 1)) (= ~(2 3) (com 2 3)) (= '~x '(clift x)) (= '(dot x) '.x) (lamp dot)
 (= 3 (1 + 2)) (= 7 (1 + 2 * 3)) (= 'b (0 ? 'a 'b)) (= 'big ((1 < 2) ? 'big 'small))
 (= 12 (foldl (+) 0 '(3 4 5)))
 (: t (peek dict 'operators 0) (&& (mapp t) (= 'sat (t ("$" 0))) (= 'hasht (t ("#" 0))))))

; --- macros --- a macro maps an argument list to code; install with `::`. the prelude ships
; do/let/if/cond/quote, && and || (short-circuiting), L/list, tuple/map/array, the body-first
; :- and ?-, and the pipes >>= <=<.
(:: 'unless (\ a `(? ,(A a) 0 ,(AB a))))
(assert
 (= 'ok (unless 0 'ok)) (= 0 (unless 1 'ok)) (= 3 (&& 1 2 3)) !(&& 1 0 3)
 (= 2 (|| 0 2 3)) (= '(1 2 3) (L 1 2 3)) (= 6 (do 1 2 6)) (= 3 (let a 1 b 2 (+ a b)))
 (= 3 (:- (+ a b) a 1 b 2)) (= 'big (?- 'else (< 1 2) 'big)) (= 9 ((<=< inc (\ x (* x 2))) 4)))

; --- control --- ev compiles and runs; call-cc is a one-shot escape; tasks are
; spawn/wait/yield/sleep/done?/kill/key?; the RNG is xoshiro256++: C ships only rng-seed and
; the pure rand-next/randf-next over explicit state -- the global rand/randf stream is
; prelude lisp over dict['rng-state]. a global `trap` function receives every
; throw as (trap s a b) -- s = the status word, two bits: scare (1, something wrong) and
; more (2, read control flow); more alone = incomplete, eof = more|scare. a/b = the
; condition data; the result is delivered per the bits (the more bit: to the reader's
; resume; a bare scare: observed). scare?/more?/eof? read s. see test/trap.l.
(assert
 (= 3 (ev '(+ 1 2))) (lamp ev) (= 41 (call-cc (\ k (k 41)))) (= 42 (+ 1 (call-cc (\ k 41))))
 (= 42 (: p (spawn (\ x (do (yield 0) (+ x 1))) 41) (wait p))) (= 0 (wait 99999)) (done? 99999)
 !(sleep 0) (= 4 (alen (rng-seed 1))) (< (rand 10) 10) (flop (randf 0))
 (scare? 1) !(scare? 3) (eof? 3) !(eof? 2) (more? 2) !(more? 3)
 (: st (rng-seed 7) (= (A (rand-next st)) (A (rand-next st)))))

; --- i/o & ports --- `in`/`out` are the default ports; the prelude wraps getc/read and
; putc/puts/putn/putx, with per-port fgetc/fputc/.../fread plus open/close/strin/strout/slurp.
; fread reads one datum per call; its end conditions route through the trap continuation via
; the status more bit, and the default trap delivers a sentinel at EOF, the port back when
; incomplete (a global `trap` function takes over that dispatch). `dot` (the `.` operator)
; prints x to `out` -- raw bytes for a string, else the inspect form -- and returns
; x, so .x taps a value mid-expression.
(assert
 (strp (inspect out)) (= "hi" (slurp (strin '(104 105)))) (: o (strout 0) _ (fputx o 42) (= "42" (outstr o)))
 (= 1 (fread (strin '(49)) 99)) (= 'eof (fread (strin 0) 'eof)) (: p (strin '(40)) (= p (fread p 99))))

; --- bootstrapping --- the C core is minimal; the key semantics are ll closures installed
; from the prelude and shared by both compilers:
;   numap -- fixnum/number application (x**n, or compose), built as an n-fold thread.
;   scomb/bcomb -- `+` and `*` of functions are church add and compose, so numerals agree.
;   boxfix -- the letrec* "capture by location" rewrite; now a wev source pass run after
;     macroexpansion, one source of truth shared with the C bootstrap compiler.
;   wev -- the source->source pre-pass before analysis: expand macros, apply boxfix, fold pure
;     globals, mark apply strategy, and flip (? !e a b) to (? e b a).
;   maps -- #(..)/map expand to nested pins; a map is a lookup function.
; the *egg* (ll/egg.l): compile the compiler with the C bootstrap, recompile the whole
; prelude+ev corpus through itself, and install it as `ev` -- baked into the image at C compile
; time, no allocation.
(assert (lamp ev) (fixp (peek dict 'boot-ticks 0)))

; --- under the hood --- a generic op dispatches on a value's kind (an enum whose order is the
; lattice above). a dyadic op is an NxN table indexed by the two kinds; a monadic op is its
; diagonal; the three core tables are + , * , and apply. a both-fixnum fast path skips the
; table; otherwise one indexed jump picks a lane that widens only as far as the operands need
; (array, complex, bignum, float, ...). the VM is tail-threaded over a two-space copying
; collector; out-of-pool constants are immortal. the ll/ layer (prelude ev repl cli egg) bakes
; into every frontend: the host (out/host/ll), the freestanding kernel (x86_64/aarch64),
; and wasm. build codegen lives in ll under tools/; the C is
; freestanding, -Wall -Wextra -Werror.

; --- odds & ends --- inspect renders a value as its reparsable printed form; (clock t) is
; milliseconds since t and (vminfo 0) reports a VM stat. an opaque handle acts as a constant
; function -- applying it ignores the argument.
(assert (strp (inspect @(1 2 3))) (fixp (clock 0)) (= 1 ((bufnew 4) 'x)))
