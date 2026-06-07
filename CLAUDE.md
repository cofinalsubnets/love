```gwen
;;; hi claude, gwen here. this is my language, gwen lisp. this code file
;;; should be a language specification that is also part of the test suite,
;;; so please modify it accordingly. it's also used to generate your CLAUDE.md
;;; file, so please keep it current with your mental model of gwen lisp as well
;;; as a current, complete language specification. always fix this file before
;;; you commit, but don't use it as a history log. rewrite below this line. thank you! :)

; gwen lisp -- a small lisp where EVERY value is a unary, auto-curried function.
; Portable C runtime (gwen.c + gwen.h) + a self-hosting compiler written in gwen
; (gwen/{prelude,ev,repl}.g). Source files are .g; the host binary is `gl`.
; Read README.md before touching language semantics.
;
; THIS FILE IS THE SOURCE OF TRUTH FOR CLAUDE.md: it is a real test in the corpus
; (its asserts run under `make test`) AND, wrapped in a ```gwen fence by
; tools/gen_claudemd.g, it *is* CLAUDE.md. Regenerate with `make CLAUDE.md` (or
; `make claudemd` for the clean-built, gl+gl0-checked regen the pre-commit hook
; runs, which fails the commit if CLAUDE.md is stale). Keep every example runnable.

; ------------------------------------------------------------------- build / test
; $ make            build host -> out/host/gl     $ make repl   build + REPL
; $ make test       run every test/*.g through gl (host) AND gl0 (bootstrap interp)
; $ make test_all   + js + tools golden-ref diffs    $ make catav  thorough pre-commit
; run one file:  cat test/CLAUDE.g | out/host/gl    (or:  out/host/gl test/CLAUDE.g)
; tests are CONCATENATED in sorted order into one stream sharing a global scope.
; FOOTGUN: gwen.h has no Makefile dep -> after editing it `make clean` or the
; bootstrap HANGS (stale gl0). .c / .g edits are incremental-safe.

; ------------------------------------------------------------------- instrument
; $ make vmret  TCO discipline: flags any g_vm_* handler that `ret`s vs tail-jumps
; $ make valg   tests under valgrind      $ make perf / flame   profiling
; $ make disasm rizin    $ make gdb    in-language: (inspect x), (clock t), globals
(assert (strp (inspect @(1 2 3)))               ; (inspect x): value -> its printed string
        (nump (clock 0)))                       ; (clock t): ms since t

; ============================================================ THREE special forms
; only `:` (letrec*/seq), `?` (cond), `\` (lambda/quote). everything else is a fn.
(assert
 (= 3 (: a 1 b 2 (+ a b)))                      ; `:` binds in source order, body = result
 (= 7 ((\ x y (+ x y)) 3 4))                    ; `\ a.. body` = lambda; auto-curried
 (= '(1 2) (\ (1 2)))                           ; ONE-operand `\` = QUOTE (so 'x == (\ x))
 (= 'big (? 0 'a (< 1 2) 'big 'else)))          ; `?` = cond: test expr .. else
; `:` is also sequencing -- bind `_` for effect; the (f x) head sugar == f (\ x ..),
; like scheme `define`. a body-LESS top-level `:` leaks its bindings to global scope
; (how concatenated .g test files share helpers).
(: (twice f x) (f (f x))
   (assert (= 12 (twice inc 10))))

; ===================================================== every value is a function
; application modulo eval order:  (f x y z) == (((f x) y) z),  so (f) == f.
; numbers are Church numerals; data self-applies or indexes (see types below).
(assert
 (= 8 (3 2))                                    ; (n x) on a NUMBER x  -> x ** n
 (= 7625597484987 (3 3 3))                      ; ... so (3 3 3) == (27 3)
 (= 12 (3 (+ 1) 9))                             ; (n f) on a FUNCTION  -> compose n times
 (= 5 (1 5)) (= 1 (0 5))                        ; 1 = identity, 0 = const-1 (zero numeral)
 (= 6 ((+ 1) 5)) (= '(2 3 4) (map (+ 1) '(1 2 3))))  ; partial application is just currying

; ============================================================ truthiness (`?`/nilp)
; FALSE == "zero or empty": nil/0, an all-zero number/array/complex, and the empty
; string / map / buf. EVERY other present value is true. Invariant: (nilp x)==(= 0 #x).
(assert
 (nilp 0) (nilp "") (nilp %()) (nilp @0) (nilp ())    ; zeros & empty containers are false
 (not (nilp "x")) (not (nilp 'sym)) (not (nilp car))  ; present values (incl. fns) are true
 (= (nilp "") (= 0 #"")))                             ; #x == (len x); 0 iff empty/zero

; ================================================================= TYPE hierarchy
; fixnum (tagged int, odd machine word). everything else is a heap object whose
; first word is a VM handler dispatched on application. predicates end in `p`.
(assert
 (nump 5)            (twop '(1 2))   (strp "hi")   (symp 'x)         ; core scalars/cells
 (bigp (** 2 100))   (flop 1.5)      (cplxp (C 0 1))   (arrp @(1 2 3))  ; numeric tower extensions
 (tuplep 1.5) (tuplep @(1 2 3))  (hashp %(1 2))         ; box/complex/array ARE tuples; maps
 (numericp 1.5) (numericp (** 2 99)) (atomp 'x) (nilp (atomp '(1))))
; NUMERIC TOWER (numericp): fixnum -> auto-bignum on overflow. every boxed member --
; float (flop), complex (cplxp), rank-N array (arrp) -- is one heap type, the TUPLE
; (tuplep); those p's refine it. `i` == (C 0 1); @(…) is the rank-1 array literal.
(assert
 (= (** 2 64) (* 2 (** 2 63)))                  ; overflow promotes to an exact bignum
 (= 5.0 (abs (C 3 4)))                          ; complex modulus; arg/re/im/conj also exist
 (= (C 2.0 3.0) (+ 2 (* 3 i))))                 ; mixed arithmetic promotes to the wider type
; SYMBOLS: interned ('x), uninterned/named ($x == (gensym 'x)), anonymous ((gensym 0)).
; STRINGS index their bytes: ('abc 0) and ("abc" 0) -> 97. opaque: buf (mutable bytes),
; port, thread/lambda/bif (compiled code). #x (len) is total: count | floored magnitude.
(assert (= 97 ("abc" 0)) (= 3 #"abc") (= 4 #3.9) (= 5 #@(3 4)))  ; #@(3 4) = ceil(L2 norm)

; ============================================================== reader & sigils
; comments: `;` runs to end of line; `#!` shebang line. there are NO block comments.
; '  quote (== one-arg \)     `  quasiquote    ,  unquote   ,@ unquote-splice
; @  array  (@(1 2 3), @0)    %  map (%(k v..), %0)    #  len    $  gensym
(assert
 (= '(1 (\ x) 3) `(1 'x 3))                     ; quasiquote builds templates
 (= '(1 2 3 4) (: xs '(2 3) `(1 ,@xs 4))))      ; ,@ splices a list

; ================================================ collections: lists/arrays/maps
(assert
 (= '(1 2 3) (sort < '(3 1 2)))                 ; prelude: map foldl filter sort ..
 (= 6 (foldl + 0 '(1 2 3)))
 (= @(11 22 33) (+ @(1 2 3) @(10 20 30)))       ; arrays broadcast elementwise
 (= @(2 4 6) (* @(1 2 3) 2)) (= 6 (asum @(1 2 3)))  ; scalar broadcast; reductions a*
 (= 6 (alen (arr i64 '(2 3))))                  ; (arr type shape) zero-filled, alen = count
 (: t %(1 10 2 20)                              ; maps: %(k v ..); mutable
    (= 20 (get 0 2 t)) (= 20 (t 2))             ; (t k) == (get 0 k t)
    (= 99 (get 99 9 t)) (= 50 (get 0 5 (put 5 50 t)))))  ; missing -> default; (put k v t)

; ======================================================= macros (head-symbol fns)
; a macro is a function from the call's arg-LIST to replacement code; install with
; `::`. prelude defines do/let/if/cond/quote, && || , L/list, tuple/hasht/array.
(:: 'unless (\ a `(? ,(car a) 0 ,(cadr a))))    ; (:: 'name (\ args body))
(assert (= 'ok (unless 0 'ok)) (= 0 (unless 1 'ok)))

; ============================================ eval bootstrapping (reflective install)
; The C runtime is minimal; several semantics are DEFINED in gwen (prelude.g) and
; installed back into the VM via setter bifs -- the runtime then calls these gwen
; closures. This keeps tricky behavior in one readable place, shared by both compilers.
;
;  * numap   (set-numap num-ap): applying a fixnum/number calls the gwen `num-ap`.
;            numeric operand -> x**n ; function operand -> compose (int (abs n)) times.
;            `numfn` builds the n-fold thread directly via lam/poke (no re-entry to ev).
;  * +/* of functions (set-scomb/set-bcomb): make `+`==Church add, `*`==composition,
;            so numeral arithmetic agrees with the integers ((3 3 3) law).
;  * boxfix  the letrec* "capture by location" rewrite (boxes a value binding whose
;            init closes over a not-yet-bound sibling). Written in gwen as the single
;            source of truth: the C bootstrap compiler c0 (in gwen.c) calls `boxfix`
;            like a macro; the self-hosted ev.g calls `boxfix-core` directly.
;  * maps    `%(k v..)`/`hasht` expand to nested (put k v (hashn 0)); a map IS a
;            lookup-lambda thread, which is why (t k) just works as application.
;
; THE EGG / double-bake (gwen/egg.g, driven by G_EGG_PRE/POST C macros in gwen.h):
; a frontend juxtaposes the prelude+ev source literals as a quoted corpus and applies
; the egg driver -- ((\ egg (: e (go (go ev 0 egg) 0 egg) ..)) '(<corpus>)): compile
; the compiler with c0, recompile the whole corpus through ITSELF (exercising wev),
; install the result as `ev`. No runtime alloc -- adjacent string literals, built at
; C compile time (freestanding-safe). Boot time lands in (get 0 'boot_ms globals).
(assert (lamp ev) (nump (get 0 'boot_ms globals)))

; ------------------------------------------------------------------- architecture
; runtime: gwen.c (+ gwen.h). one cell = one machine word; low bit tags fixnums;
; heap objects dispatch on their first word (a g_vm_t* handler). tail-threaded VM:
; handlers end in a tail-jump (Continue()), NEVER a plain return -- `make vmret`
; enforces this. GC is Cheney two-space; out-of-pool (const) pointers are immortal.
; gwen/ = .g layers compiled into every frontend. frontends add OS glue + main:
;   host/ (POSIX CLI), free/ (bare-metal kernel), playdate/ rp2040/ wasm/ js/.
; build codegen (gen_data, elf2efi, vmret, gen_claudemd) is gwen in tools/;
; tools/py/ are frozen golden refs -- change a .g tool's output, update the .py too.
;
; STYLE: terse and dense. short names (f, n, p, Sp). comments only for non-obvious
; invariants (GC hazards, TCO contract, bootstrap order) -- not narration. keep line
; count low; match surrounding density. C is freestanding: -Wall -Wextra -Werror.
```
