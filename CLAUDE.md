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
; linux, freebsd and netbsd, using a built in custom libc, for amd64,
; arm64, and thumb32, with riscv64 currently in development.
;
; kore includes sh, make, vi, as, nc, gzip/gunzip, and lots of other
; utilities.
;
; inle currently runs on amd64 and arm64 and includes a virtual console,
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
; - use libra `out/host/love crew/libra/libra.l <file>` to check paren balance
; - don't trust comments without reading the code they're talking about
; - just because something was done on purpose doesn't mean it was for a good reason

; love artifact and build information:
; - love and inle are not separate builds. moon builds both with the same flags and
;   links them together, and they share one copy of almost everything. a given instance
;   of the love artifact is linked for hosted or freestanding use, but the translation
;   is bidirectional and mechanical, and either image can generate the other.
; - mooncc compiles the artifact. the ambient cc is used to build love0, the bootstrap build of
;   love, which runs moon, which builds the finished product. 
; - moon's libc is nolibc (crew/moon/lib/nolibc), statically linked. not glibc, not musl.
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
; immediate invoked infix lambda with pattern matching example
(([a b c] \ [(a * b + c) (b * c + a) (c * a + b)]) [3 2 5] @
 [1 3 7] 'this-will-not-match
 ("this" | "won't" | "match") 'either
 [11 13 17] "this matches strict nil tail"
 (11 13 17) "this matches lax about the tail"
 (11 >< 13 >< 17 >< _) 'this-is-fine-too)

; language traps
; - (x) = x: singleton lists are no-ops
; - $ x != $x: spaced and glued are different operators
; - (+ 2 3 4) = ((+ 2 3) 4) = (5 4) = 1024: no varargs
; - (1 +) = (+ 1): no sections
; - gem? (3 / 2) = 1: / gives a float; // for int
; - (-17 % 8) = -1: % and // truncate toward zero; hand-roll floor-mod
; - (map < l) passes a comparison partial, not car; car as a function is (x \ <x)
; - a lambda parameter sharing a name with a LATER non-lambda sibling binding
;   in the same (: ..) raises "missing X" (the forward-binding trap)
; - a mid-letrec assert binds to _, or it becomes define-sugar and never runs
; - in a catted module file `name value` builds at bake, `(name args)` defers
; - juxtaposition binds tighter than infix: `u + M u` is `(+ u (M u))`, and
;   applying a number is the tower -- write `(u + M) u`

; the working vocabulary (verified in-tree)
; - (show x) prints-to-string; puts/putc write; putx prints a form
; - sort orders numbers, symbols, strings, and lists; rev, tally (#), member?, map
; - tablets: {} makes, (pin t k v) mutates AND answers t (so foldl builds one),
;   (peep t k dflt) reads, (t k) applies; (keys t) is UNSORTED -- sort before
;   walking or answers drift
; - strings index by application: ("abc" 0) = 97; lists DON'T index that way
; - charm? is the number predicate; (show 'sym) spells a symbol
; - car/cdr are total: <() = >() = (); (= a b) across types answers 0, never dies

; booleans
; love's exact booleans are {0,1}. however any value can be
; considered boolean if it occurs as a ? predicate. the truth
; value chosen in this situation is described for all x by the
; lambda equations
(x \ ?x = (bit x) = ($x > 0))
(x \ $x = (ceil (re (net x))))
; where the basic operation net is a complex-valued structure
; respecting sum defined explicitly for all basic love data types. 
(? 1 2 3)  ; 2 ; this predicate succeeds
(? 0 2 3)  ; 3 ; this predicate fails
(-1 ? 2 3) ; 3 ; infix ? is idiomatic ternary syntax
; compound data are summed over their parts and the truth value is the sign.
(? '(1 -0.5) 'yea 'nae) ; yea
(? '(1 -1.5) 'yea 'nae) ; nae
