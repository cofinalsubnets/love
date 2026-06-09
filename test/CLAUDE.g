;;; hi claude, gwen here, welcome back to gwen lisp. this code file is a
;;; language specification that you maintain that is also part of the test suite,
;;; so please modify it accordingly. it also forms the contents of your CLAUDE.md
;;; file.  keep this file golden, it should never go stale; when in doubt, refer
;;; here, and flag any observed deviation from the specification in this file.
;;; whenever you read this, rewrite everything below the next line. thank you! :)

; gwen lisp -- a small lisp where EVERY value is a monadic, auto-curried function.
; Portable C runtime (gwen.c + gwen.h) + a self-hosting compiler in gwen
; (gwen/{prelude,ev,repl}.g). Source files are .g; the host binary is `gl`. Read README.md.
; SOURCE OF TRUTH for CLAUDE.md: a real test in the corpus that, wrapped in a gwen code
; fence, IS CLAUDE.md -- rewrite this, then regenerate the doc by hand (wrap this file).
; STYLE: prefer the sigils `!` over `nilp` and `#` over `pin`, in code and prose.

; --- build/test --- ($ make -> out/host/gl; make repl; make test runs test/*.g through
; gl AND gl0; make test_all + js/tools diffs; make catav pre-commit). one file:
; out/host/gl test/CLAUDE.g. tests CONCATENATE into one global scope -- keep helpers
; LOCAL (body-ful `:`). FOOTGUN: edit gwen.h -> `make clean` or gl0 HANGS (no header dep).
; --- instrument --- make vmret (TCO: every g_vm_* tail-jumps, never ret) / valg / perf.
(assert (strp (inspect @(1 2 3)))               ; (inspect x) -> printed string
        (fixp (clock 0)))                       ; (clock t) ms since t; (vminfo 0) VM stat

; === THREE special forms: `:` (letrec*/seq) `?` (cond) `\` (lambda/quote) ===
(assert
 (= 3 (: a 1 b 2 (+ a b)))                      ; `:` binds in source order, body = result
 (= 7 ((\ x y (+ x y)) 3 4))                    ; `\ a.. body` = lambda, auto-curried
 (= '(1 2) (\ (1 2)))                           ; ONE-operand `\` = QUOTE (so 'x == (\ x))
 (= 'big (? 0 'a (< 1 2) 'big 'else)))          ; `?` = test expr .. else
; `:` sequences (bind `_` for effect); (f x) head sugar == define; a body-less top-level
; `:` leaks bindings to global scope (how test files share helpers); a binding sees siblings.
(: (twice f x) (f (f x)) (assert (= 12 (twice inc 10))))

; === every value is a function: (f x y) == ((f x) y), (f) == f ===
; numbers are Church numerals; a numeric list is an exponential tower; data self-applies/indexes.
(assert
 (= 8 (3 2)) (= 7625597484987 (3 3 3))          ; (n x) NUMBER -> x**n ; so (3 3 3)==(27 3)
 (= 262144 (2 3 4))                             ; the tower: (2 3 4)==4**(3**2)==4**9
 (= 0.5 (-1 2)) (= 0.2 (-1 5)) (= 3.0 ((/ 1 2) 9))  ; negative n -> reciprocal ((-1 x)=(/ 1 x)); (1/2 x)=sqrt
 (= 12 (3 (+ 1) 9)) (= 5 (1 5)) (= 1 (0 5))     ; (n f) FN -> compose n; 1=id, 0=const-1
 (= '(2 3 4) (map (+ 1) '(1 2 3)))              ; partial application is just currying
 (= 8 (3 2.0)) (= 12 ((2.5 (+ 1)) 10))          ; tower numeral: |n| floors a fn count
 (= 1 ((bufnew 4) 'x)))                         ; opaque handles (buf/port) act as 0

; === truthiness (`?`/`!`): FALSE == NEGATIVE-OR-ZERO or empty; POSITIVE is true. An ordered
; scalar (real/complex/box/bignum) is false iff it sorts <= 0 by the total order (complex: re
; then im, so ~(-3 4) and -i are false but ~(3 -4) and i are true); a container is false iff
; empty; an array is false iff its L2 norm is 0 -- a negative element keeps it true (an array
; has no single sign). `!` is the C oracle (short-circuits, no `#` walk). invariant
; !x==(= 0 #x), so # clamps any non-positive scalar to 0 (#-5=0). ===
(assert
 !0 !"" !%() !@0 !() !0.0 !~(0 0)
 !-5 !-3.9 !(- 0 (100 2)) !~(-3 4) !~(0 -1)     ; <= 0 by total order -> false
 !!"x" !!'a !!A !!5 !!i !!~(3 -4)               ; positive / nonempty -> true (!! = "is truthy")
 !!@(-3 -4)                                     ; a NEGATIVE array stays true (norm, sign squares away)
 (= !"" (= 0 #"")) (= !-5 (= 0 #-5)))

; === types: fixnum (tagged odd word); else a heap object whose 1st word dispatches.
; predicates end in `p`. numeric TOWER (nump): fix -> bignum on overflow; float/complex/
; rank-N array are all one heap type TUPLE (tupp), refined by flop/comp/arrp. `i`==~(0 1).
(assert
 (fixp 5) (twop '(1 2)) (strp "hi") (symp 'x) (lamp A) (mapp %(1 2))
 (bigp (100 2)) (boxp (62 2)) (flop 1.5) (comp i) (arrp @(1 2 3)) (tupp 1.5)
 (nump 1.5) (intp (62 2)) (atomp 'x) !(atomp '(1))
 (= (64 2) (* 2 (63 2)))                        ; overflow -> exact bignum (numeral power (k b)==b**k)
 (= 5.0 (abs ~(3 4))) (= ~(2.0 3.0) (+ 2 (* 3 i))))  ; mixed arith -> wider type
; SYMBOLS: interned 'x, named-uninterned $x (nom 'x), anonymous (nom 0). STRINGS
; index bytes: ("abc" 0)->97. opaque: buf/port/thread. #x = a SATURATING NON-NEGATIVE size:
; container count | symbol name length | ceil magnitude, a non-positive scalar clamped to 0
; (#-3.9=0); an array = ceil(L2 norm). abs is the raw magnitude, so they DIVERGE: (abs -5)=5.
(assert (= 97 ("abc" 0)) (= 3 #"abc") (= 4 #3.9) (= 0 #-3.9) (= 5 #@(3 4)) (= 5 (abs -5)))  ; #@(3 4)=ceil(L2 norm)

; === arithmetic + - * / // mod : fixnum fast path; fixp/flop promotes to float; int
; overflow -> wide-int box -> bignum; non-num -> nil. `/` is TRUE division -- an inexact
; integer quotient PROMOTES to a float ((/ 1 2)=0.5; (/ 4 2)=2 exact stays int), /0 -> IEEE
; inf/nan; `//` truncates toward zero (integer division, the pair of `mod`).
; ORDERED compare < <= > >= : a TOTAL ORDER over ALL values -- cross-kind by the
; enum q type lattice the matrix DIAGONAL encodes (number < string < symbol < pair
; < lambda, fixnum low), within a kind by value/lexicographic (complex by (re,im),
; lambda by α-invariant repr hash; array operand -> elementwise 0/1 mask). `> >=` reverse `< <=`.
; `=` is eqv (promotes across tower; FUNCTIONS by α-equivalence + captured values), `same` is eq (identity). bitwise << >> & | ^
; (int; complement is (^ x -1)). logical negation is `!` (= the `nilp` nif); != is gone (use !(= ..)).
(assert
 (= 3 (+ 1 2)) (= 6 (* 2 3)) (= 2.5 (/ 5 2)) (= 2 (// 5 2)) (= 0.5 (/ 1 2)) (= 1 (mod 5 2)) (= 3.5 (+ 1 2.5))
 (= 2 (/ 4 2)) (fixp (/ 4 2)) (= -2 (// -5 2))   ; / exact->int, // truncates toward zero
 !(fixp (* 2 2305843009213693952)) (flop (/ 1 0)) (< 1e308 (/ 1 0)) !(= (/ 0 0) (/ 0 0))
 (= 3 3.0) !(= 3 4) (< 1 1.5) (>= 3.0 3) !(= 3 4) (same 'a 'a) !(same '(1) '(1))
 (= -2 (^ 1 -1)) (= 15 (| 8 (| 4 (| 2 1)))) (= 16 (>> 64 2)) (= 16 (<< 2 3))
 (< 1 "a") (< "a" 'x) (< 'x '(0)) !(< "a" 1))   ; total order: number < string < sym < pair
; === FUNCTION equality: `=` on two functions is α + structural -- their source \-exprs are
; compared α-equivalently (a \ form's leading binders, imports then params, match by POSITION
; not name; free vars by name) AND their captured values pairwise; `same` stays identity and
; `<` agrees (the repr hash is α-invariant). η ((\ x (f x)) = f) and β are NOT bridged: a
; lambda vs its operator / normal form is a representation-crossing edge -- a closure is `lamp`
; while its operator may be a fixnum -- that stays false (the Wall-2 incompleteness boundary). ===
(assert
 (= (\ x x) (\ y y)) (= (\ a b (+ a b)) (\ x y (+ x y)))            ; α: bound vars by position
 (= (\ x (+ x 1)) (\ x (+ x 1))) !(same (\ x (+ x 1)) (\ x (+ x 1)))  ; structural -- but distinct objects
 !(= (\ x x) (\ y z)) !(= (\ x (+ x 1)) (\ x (+ x 2)))              ; free != bound ; different body
 (: g (\ a (\ b (+ a b))) (&& (= (g 1) (g 1)) !(= (g 1) (g 2))))    ; closures: equal iff captures match
 (= (+ 1) (+ 1))                                                    ; partial applications too
 !(< (\ x x) (\ y y)) !(< (\ y y) (\ x x))                          ; order agrees with = (α-invariant hash)
 !(= (\ x (A x)) A))                                                ; η NOT bridged: lambda vs nif (Wall-2)
; `+` GENERIC (order-preserving): num add; str/sym concat (num=1 byte; text tower
; str<usym<isym lifts a num, mixing demotes); list append. `-` numeric only (nil).
(assert
 (= "abcd" (+ "ab" "cd")) (= "xB" (+ "x" 66)) (= 'efef (+ 'ef 'ef)) (strp (+ "ab" 'ef))
 (= '(1 2 3 4) (+ '(1 2) '(3 4))) (= '(5 1 2) (+ 5 '(1 2))) !(- "a" "b"))
; `*` = repeated `+`: seq * count (int(abs c)) -> copies joined; seq*seq/array-count -> nil.
(assert
 (= "ababab" (* "ab" 3)) (= "ababab" (* 3 "ab")) (= 'xyxy (* 'xy 2))
 (= '(1 2 1 2) (* '(1 2) 2)) !(* "ab" "cd"))

; === numeric fns: abs/int type-aware; constants e pi i; gcd/modpow. The IRREDUCIBLE
; transcendental nifs are pow sin cos log (float; bignums widen, arrays elementwise).
; EVERYTHING else is a numeral/complex DERIVATION, NOT a nif (no sqrt/exp/tan/atan/atan2):
;   power (k b)==b**k     sqrt ((/ 1 2) x)     exp (x e)     root n of x: ((/ 1 n) x)
;   tan (/ (sin x) (cos x))     atan (arg ~(1 x))     atan2 (arg ~(x y))
; arg/com broadcast over arrays, so the derived forms stay elementwise (see arrays/complex).
(assert
 (= 5 (abs -5)) (fixp (abs -5)) (= 5.0 (abs ~(3 4))) (= 2 (int 2.9))
 (= 1024 (10 2)) (fixp (10 2)) (= 21 (gcd 1071 462)) (= 976371285 (modpow 2 100 1000000007))
 (= 2.0 ((/ 1 2) 4)) (= 1024.0 (pow 2 10)) (= 1 (0 e)) (= e (1 e)) (= 2.718281828459045 e)
 (= 0.0 (arg ~(1 0))) (= 0.0 (/ (sin 0) (cos 0))) (flop (sin 0)))

; === complex: rank-0 scalar (comp), widest tier (complex>float>int). the `~` reader sigil
; before `(` splices into (com re im) (3+ operands curry: ~(a b c)=(~(a b) c)); a BARE ~x is
; the monadic op clift: ~r lifts a real to ~(r 0), ~z conjugates (~~(r i)=~(r -i)), ~0=~(0 0).
; i=~(0 1). com/comp are the constructor/predicate nifs. + - * / promote a real; sticky (no demote);
; ORDERED lexicographically by (re,im) -- a real is (r,0) -- and `=` bridges reals. com and
; arg BROADCAST over arrays (a real operand -> a packed `c` array / a real-array result), so
; the derived (arg ~(1 x)) = atan etc. stay elementwise. rank-N complex packs (re,im) into a
; `c` array (atype c): arr/arrl/array/@ build it, get -> a ~(..) box, + - * / broadcast (numpy)
; and `=` -> a mask, asum/aprod fold complex.
(assert
 (= (* i i) -1) (= ~(2 0) 2) (= (* ~(1 2) ~(3 4)) ~(-5 10)) (comp ~(2 0)) !(comp 5)
 (= ~(5 0) ~5) (comp ~5) (= ~(0 0) ~0) (= (conj ~(2 3)) ~~(2 3))  ; ~r lifts a real; ~z conjugates
 (= 2.0 (re ~(2 3))) (= (conj ~(2 3)) ~(2 -3)) (< i 1) !(< 1 i) (= "~(0.0 1.0)" (inspect i))
 (= 0.0 (get 0 1 (arg ~(1 @(1 0)))))            ; com/arg broadcast: (arg ~(1 x)) = atan, per element
 (: v (array 2 ~(1 2) ~(3 4)) (&& (= c (atype v)) (= ~(1 2) (get 0 0 v)) (= ~(4 6) (asum v))
    (= ~(2 4) (get 0 0 (+ v v))) (= ~(2 4) (get 0 0 (* ~(2 0) v))) !(< v v)
    (= "@(~(1.0 2.0) ~(3.0 4.0))" (inspect v)))))

; === pairs & lists: X=cons, A=car, B=cdr; AA AB .. BBB = the c[ad]+r compounds. NATIVE
; names are X/A/B + the AB-compound; cons/car/cdr/caar/cadr/.. are prelude compat ALIASES
; (the prelude/compiler standardize on X/A/B). HOFs from the prelude.
(assert
 (= 1 (A '(1 2 3))) (= '(2 3) (B '(1 2 3))) (= 3 (AB '(2 3 4))) (= '(1 2) (X 1 (X 2 0)))
 (= 1 (car '(1 2 3))) (= 3 (cadr '(2 3 4)))     ; cons/car/cdr/c[ad]+r aliases still resolve
 (= '(2 3 4) (map inc '(1 2 3))) (= 24 (foldl * 1 '(1 2 3 4))) (= 6 (foldr + 0 '(1 2 3)))
 (= '(1 3) (filter (\ x (mod x 2)) '(1 2 3 4))) (= '(1 2 3) (sort < '(3 1 2)))
 (= '(1 2 3 4) (cat '(1 2) '(3 4))) (= '(3 2 1) (rev '(1 2 3))) (= '(1 2) (map A (zip '(1 2) '(3 4))))
 (= 20 (AB (assq 2 (list (L 1 10) (L 2 20))))) (= '(1 2) (take 2 '(1 2 3 4))) (= '(3 4) (drop 2 '(1 2 3 4)))
 (= 3 (last '(1 2 3))) (= '(1 2) (init '(1 2 3))) (memq 3 '(1 2 3)) !(memq 9 '(1 2 3))
 (all (\ x (< 0 x)) '(1 2 3)) (any (\ x (< 2 x)) '(1 2 3)) (= 3 #'(a b c)))

; === strings & symbols: # /get index; ssub (half-open) ; scat (lenient, "" identity);
; (str k) indexes a byte (oob/non-num -> 1); string coerces; intern/nom ; \n escapes.
(assert
 (= 4 #"slen") (= "bidden" (ssub "forbidden planet" 3 9)) (= "abcd" (scat "ab" "cd"))
 (= 104 ("hi" 0)) (= 1 ("hi" 9)) (= 'asdf (intern "asdf")) !(= (nom 0) (nom 0))
 (= "asdf" (string 'asdf)) (= "\"a\\nb\"" (inspect "a\nb")) (= "$x" (inspect (nom "x"))))

; === arrays: (arr type shape) zero ; (arrl type shape vals) ; (array shape elem…) infers
; type+curries ; @(…) rank-1 literal. arank/alen/ashape/atype ; get (oob->default).
; + - * // < = broadcast (numpy, widest type, compare->i8); `/` promotes the whole result
; to f64 the moment an element divides inexactly (else stays integer); reduce asum aprod
; amax amin aall (conjunction; identity on a scalar; the disjunction "any nonzero" is just
; `#`, truthy iff not all-zero) ; zero-norm falsy ; sin/cos/log/pow (+ derived) map elementwise.
(assert
 (= 6 (alen (arr i64 '(2 3)))) (= 2 (arank (arr i64 '(2 3)))) (= '(2 3) (ashape (arr i64 '(2 3))))
 (= i64 (atype (arr i64 '(2 3)))) (= 20 (get -1 1 @(10 20 30))) (= -1 (get -1 9 @(10 20 30)))
 (= 3 (get -1 '(1 0) (arrl i64 '(2 2) '(1 2 3 4)))) (= @(11 22 33) (+ @(1 2 3) @(10 20 30)))
 (= @(2 4 6) (* @(1 2 3) 2)) (= f64 (atype (+ (arr i32 '(2)) 1.5))) (= i8 (atype (< (arr i64 '(3)) 1)))
 (= 60 (asum @(10 20 30))) (= 30 (amax @(10 30 20))) (= 5 (asum 5)) (aall (< 1 2))
 (aall (= @(2.0 3.0) ((/ 1 2) @(4.0 9.0)))) (= @(3.5 5.5) (/ @(7 11) 2)) (= @(3 5) (// @(7 11) 2))
 (= @(4 6) (/ @(8 12) 2)) !(arr i64 '(3)) (= "@(10 20 30)" (inspect @(10 20 30)))
 (aall (= @(10 20 30) (array 3 10 20 30))) !(+ @(1 2 3) @(1 2)) !(arr 99 '(3)))

; === maps: %(k v..)/(hasht ..) build, %()/(hashn 0) empty, mutable. get/put/hashd
; (default key | key val | default table key), hashk, hash, #=keycount. (t k)==(get 0 k t).
(assert
 (: t %(1 10 2 20) (&& (= 20 (get 0 2 t)) (= 20 (t 2)) (= 99 (get 99 9 t))))
 (= 50 (get 0 5 (put 5 50 %()))) (: t %(1 10 2 20) _ (hashd 0 t 1) (= 1 #t))
 (= 2 #(hashk %(1 10 2 20))) (= (hash 'k) (hash 'k)) (mapp %()) !(mapp 5))

; === bufs: (bufnew n) mutable zeroed bytes ; # /get/put (byte 0..255) ; bcopy ; eq by id.
(assert
 (: b (bufnew 3) _ (put 0 65 b) (= 65 (get 0 0 b))) (= 4 #(bufnew 4))
 (: b (bufnew 1) _ (put 0 257 b) (= 1 (get 0 0 b))) (: b (bufnew 4) _ (bcopy b 0 "ABCD" 0 4) (= 68 (get 0 3 b)))
 !(= (bufnew 2) (bufnew 2)))

; === reader sigils: ; line comment, #! pinbang (NO block comments). 8 are monadic
; (sigil/name/->call): # pin (len), ' quote (=1-arg \), ! bang (nilp), . dot, ~ wave
; (clift), $ nom (gensym), @ tup (array), % map. QUASIQUOTE sigils (NOT monadic operators):
; ` quasiquote , unquote ,@ splice. ~(re im)->(com re im) splice; bare ~x->(clift x) lift/conj; .x->(dot x), see I/O.
(assert
 (= '(1 (\ x) 3) `(1 'x 3)) (= '(1 2 3 4) (: xs '(2 3) `(1 ,@xs 4)))
 (= 5 #"hello") (= 42 #42) (symp $x) (= 1 !0) (= 0 !5) !!5
 (= i ~(0 1)) (= ~(2 3) (com 2 3)) (= '~x '(clift x))  ; ~(re im) splices; bare ~x->(clift x)
 (= '(dot x) '.x) (lamp dot))                   ; .x->(dot x): the `.` sigil wraps `dot`

; === macros (arg-list -> code, install via `::`): prelude do/let/if/cond/quote && || L/list
; tuple hasht array, body-first :- ?- , pipes >>= <=< .
(:: 'unless (\ a `(? ,(A a) 0 ,(AB a))))
(assert
 (= 'ok (unless 0 'ok)) (= 0 (unless 1 'ok)) (= 3 (&& 1 2 3)) !(&& 1 0 3)
 (= 2 (|| 0 2 3)) (= '(1 2 3) (L 1 2 3)) (= 6 (do 1 2 6)) (= 3 (let a 1 b 2 (+ a b)))
 (= 3 (:- (+ a b) a 1 b 2)) (= 'big (?- 'else (< 1 2) 'big)) (= 9 ((<=< inc (\ x (* x 2))) 4)))

; === control: ev (compile+run) ; call_cc (one-shot escape) ; tasks spawn/wait/yield/sleep/
; done?/kill/key? ; RNG xoshiro256++ (global rand/randf + pure rand-next/randf-next + state).
(assert
 (= 3 (ev '(+ 1 2))) (lamp ev) (= 41 (call_cc (\ k (k 41)))) (= 42 (+ 1 (call_cc (\ k 41))))
 (= 42 (: p (spawn (\ x (do (yield 0) (+ x 1))) 41) (wait p))) (= 0 (wait 99999)) (done? 99999)
 !(sleep 0) (= 4 (alen (rng-seed 1))) (< (rand 10) 10) (flop (randf 0))
 (: st (rng-seed 7) (= (A (rand-next st)) (A (rand-next st)))))

; === I/O & ports: in/out back prelude getc/read putc/puts/putn/putx ; per-port f-nifs
; fgetc fungetc feof fputc fputs fputn fputx fflush fread ; open/close (host) ; strin/strout
; /slurp/outstr/inspect ; fread = one datum/call (sentinel on EOF, the port on incomplete).
; `dot` (sigil `.`) prints x to `out` -- raw bytes if a string (puts discipline) else the
; inspect form (putx discipline) -- and RETURNS x, so `.x` taps a value mid-expression.
(assert
 (strp (inspect out)) (= "hi" (slurp (strin '(104 105)))) (: o (strout 0) _ (fputx o 42) (= "42" (outstr o)))
 (= 1 (fread (strin '(49)) 99)) (= 'eof (fread (strin 0) 'eof)) (: p (strin '(40)) (= p (fread p 99))))

; === eval bootstrapping (reflective install): the C runtime is minimal; key semantics are
; gwen closures in prelude.g installed via setter nifs, shared by both compilers:
;  * numap (set-numap): fixnum/number application -> gwen num-ap (x**n / compose); numfn
;    builds the n-fold thread via lam/poke (no re-entry to ev).
;  * +/* of functions (set-scomb/set-bcomb): `+`=Church add, `*`=compose, so numerals agree.
;  * boxfix: letrec* "capture by location" rewrite. c0 (gwen.c) calls `boxfix` like a macro;
;    ev.g calls `boxfix-core`. single source of truth.
;  * wev (ev.g only, not c0): source->source pre-pass before `ana` -- macro-expand, constant-
;    fold pure globals, mark apply strategy, and flip `(? !e a b)` -> `(? e b a)`, dropping a
;    `!`/nilp that just wraps a `?` test (the cond tests g_false(e), which IS `!e`).
;  * maps: %(k v..)/hasht expand to nested (put k v (hashn 0)); a map IS a lookup-lambda.
; THE EGG (gwen/egg.g, G_EGG_PRE/POST in gwen.h): compile the compiler with c0, recompile
; the whole prelude+ev corpus through ITSELF, install as `ev` -- at C compile time, no alloc.
(assert (lamp ev) (fixp (get 0 'boot_ms globals)))   ; boot ms lands in globals

; === architecture ===
; runtime gwen.c (+ gwen.h): one cell = one word; low bit tags fixnums; a heap object's
; 1st word is a g_vm_t* handler. tail-threaded VM (handlers tail-jump, never ret -- `make
; vmret`). GC Cheney two-space; out-of-pool consts immortal.
;
; GENERIC OPS dispatch on a value KIND (enum q) whose ORDER is a type lattice on the
; matrix diagonal: arith lane [fix, box, big, array tower arrZ/R/C/O] | seq lane [string,
; sym, pair] | lambda last. each lane is contiguous so `max` is the within-lane promotion
; join; pair caps seq just under lambda (it's its own Church eliminator). g_typ = storage
; kind (coarse; from a data-sentinel section slot, one array sentinel); g_kind = arith kind
; (refines a rank>=1 tuple to arrZ..arrO). a DYADIC op is an NxN handler matrix indexed
; [g_kind a][g_kind b]; a MONADIC op is its diagonal. three: g_add_mx (+), g_mul_mx (*),
; g_apply_mx (apply). one indexed jump picks the lane; the table encodes precedence
; (lambda>pair>text>number) and undefined cells (-> nil). FAST-PATH CHAINING, two levels:
; (1) the public nif inlines both-fixnum (__builtin_*_overflow, no matrix touch), falling
; through to Ap(mx[..][..]); (2) a lane handler (g_vm_addn) fall-throughs by REPRESENTATION
; hottest-first, tail-jumping to a specialized engine: array->g_vm_vbin, complex->cplx_bin,
; non-num->nil, float->box f64, in-range int->EMIT_INT, else->g_big_binop. matrix -> lane in
; one jump; the chain widens only as needed.
;
; gwen/ = .g layers (prelude ev repl cli egg) baked into every frontend. glue: main.c
; (host -> out/host/gl); kmain.c + arch/<arch> (freestanding -> out/free: x86_64 aarch64
; riscv64 loongarch64 playdate rp2040); wasm/. build codegen (gen_data vmret) is
; gwen in tools/; tools/py/ are frozen golden refs (update on output change). CLAUDE.md is
; hand-maintained (wrap this file); there is no generator.
; STYLE: terse, dense; short names; comments only for non-obvious invariants. C freestanding,
; -Wall -Wextra -Werror.
