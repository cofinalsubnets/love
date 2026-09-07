```love
; love is a self reproducing software artifact that combines
; several tools in a single binary.
;
; - love: a programming language
; - moon: a C compiler and toolchain
; - kore: a userland and coreutils
; - inle: a bare metal somewhat-unix-like love runtime
;
; the love language is a curried lisp dialect with syntactic
; sugar for infix and prefix notation and pattern matching.
; it uses many fewer parens than traditional lisp and resembles a mix
; of scheme, haskell, and apl.
;
; mooncc builds statically linked executables that currently run on
; linux, freebsd and netbsd, using a built in custom libc, for x64,
; a64, and thumb32, with rv64 currently in development.
;
; kore includes sh, make, vi, as, nc, gzip/gunzip, and lots of other
; utilities.
;
; inle currently runs on x64, a64 and rv64 and includes a virtual console,
; filesystem, and doom port.
;
; the love artifact includes all these components in a single binary together
; with a compressed copy of its own source code, which it can use to identically
; reproduce itself, either by bootstrapping through another C compiler, or
; entirely with moon and kore.

; guidelines for working in this tree:
; - keep comments short, calm lowercase, inline when possible, no paragraphs
; - comments should not log history, cite fixed bugs, or refer outside the present code
; - C code may not use mutable globals/statics or directly call malloc/free (with rare exceptions)
; - makefiles must be compatible with our make (cook)
; - shell scripts must be compatible with our shell (lush)
; - `make test` is the fast gate to check if something works (<1m)
; - `make test_slow` is the slow gate, before committing (<10m)
; - `make test_extra` is the really slow gate, before merging (qemu boots, cross-arch, boards)
; - use libra `out/love apps/libra/libra.l <file>` to check paren balance
; - don't trust comments without reading the code they're talking about
; - just because something was done on purpose doesn't mean it was for a good reason

; love artifact and build information:
; - love and inle are not separate builds. moon builds both with the same flags and
;   links them together, and they share one copy of almost everything. a given instance
;   of the love artifact is linked for hosted or freestanding use, but the translation
;   is bidirectional and mechanical, and either image can generate the other.
; - mooncc compiles the artifact. the ambient cc is used to build love0, the bootstrap build of
;   love, which runs moon, which builds the finished product. 
; - moon's libc is nolibc (apps/moon/lib/nolibc), statically linked. not glibc, not musl.
;   if you are about to reach for a libc function, check that we have it
; - __STDC_HOSTED__ is 1 nearly everywhere -- mooncc predefines it. the seven port/
;   board lanes pass -D __STDC_HOSTED__=0 and are the only freestanding compiles; the
;   kernel and wasm are both hosted
; - which artifacts compile a file is a question for the build, not for a comment or a
;   symbol name: `find out -name '<file>.o'`. objects under out/ go stale, so check an
;   mtime before reading one as evidence


;;; love language examples

1 = 0 5                      ; 0 is const-1, 1 is the identity
8 = 3 2                      ; n x = x ** n
262144 = 2 3 4               ; the tower 4 ** (3 ** 2)
3.0 = (1 / 2) 9              ; (1 / 2) x = sqrt x
i = 0.5 -1                   ; complex numbers
i = (0 ~ 1)                  ; a ~ b = (twin a b), the complex builder
[1 2 3] = sort [3 1 2]       ; [x y z] = (list x y z)
{'a 1 'b 2}                  ; {k v ..} = (hash k v ..), a tablet
[2 3 4] = map (+ 1) [1 2 3]
12 = +[3 4 5]                ; +x = (net x)
3 = #[3 1 2]                 ; #x = (tally x)
60 = *[[3 2] [2 [5]]]        ; *x = (prod x)
1 < 2 <= 3                   ; comparison chaining

; triangular number sequence
[1 3 6 10 15] = map (net * jot * (+ 2)) ^5 ; ^n = (jot n)

; infix notation
(tally "hello" = 3 + 2 ? 'ok 'whoa) = (? (= (tally "hello") (+ 3 2)) 'ok 'whoa)

; an infix lambda (params \ body) applied on the spot, its answer matched by @
(([a b c] \ [(a * b + c) (b * c + a) (c * a + b)]) [3 2 5] @
 [1 3 7] 'this-does-not-match
 ("this" || "alternation") 'does-not-match-either
 [11 13 17] "this matches exactly"
 (l && two? l) 'this-guard-matches
 (11 . 13 . 17 . _) 'this-prefix-matches)

; language advisories
; - (x) = x: singleton lists are no-ops
; - glued and spaced are different operators: <a is (cap a), (< a) is a partial of <;
;   $x and ($ x) likewise part company for everything but a plain number
; - (+ 2 3 4) = ((+ 2 3) 4) = (5 4) = 1024: no varargs, binary ops are binary
; - u + M u = (+ u (M u)): application binds tighter than infix -- and applying a
;   number is the tower (3 2 = 8), so write (u + M) u
; - (1 +) = (+ 1): no sections
; - (map < l) is (< map l): an infix operator by value is parenthesised, (<). the
;   accessor is cap -- and love orders across kinds, so the misread answers 0 in silence
; - 3 / 2 = 1.5 && 3 // 2 = 1: / returns a float, use // for int
; - (-17 % 8) = -1: % and // truncate toward zero; hand-roll floor-mod
; - (: a b  b 5 ..) is ";; missing b": a value binding sees only EARLIER siblings, a
;   lambda body sees later ones too. same split when a module file bakes -- `name value`
;   runs at bake, `(name args)` defers
; - a mid-letrec assert must bind: `_ (assert ..)`. bare `(assert ..)` is define-sugar,
;   so a false one never runs and passes in silence

; the working vocabulary (verified in-tree)
; - (show x) prints-to-string; puts/putc write; putx prints a form
; - sort orders numbers, symbols, strings, and lists; rev, tally (#), member?, map
; - tablets: {} makes, (pin t k v) mutates AND answers t (so foldl builds one),
;   (peep t k d) reads with default, t k = peep t k () ; (keys t) is UNSORTED -- sort before
;   walking or answers drift
; - strings and lists index by application: "abc" 0 = 97, [1 2 3] 1 = 2
; - charm? is number predicate; (show 'sym) spells a symbol
; - cap/cup are total: <() = >() = (); (= a b) across types answers 0, never dies

; booleans
; the exact boolean values are {0,1}. however any value can be
; considered boolean if it occurs as a ? predicate. a value is
; true in this situation iff the real part of its net is positive,
; where net is a built in function that reduces any value to a
; complex number. there are lots of ways to state this in love
; here are some equations for all x:
(x \ ?x = bit x = re (net x) > 0)
; where the basic operation net is a complex sum defined for all love types.
(? 1 2 3)  ; 2 ; this predicate succeeds
(? 0 2 3)  ; 3 ; this predicate fails
(-1 ? 2 3) ; 3 ; infix ? is idiomatic ternary syntax
; compound data are summed over their parts and the truth value is the sign.
(? '(1 -0.5) 'yea 'nae) ; yea
(? '(1 -1.5) 'yea 'nae) ; nae
