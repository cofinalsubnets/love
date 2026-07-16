; hook -- install the native-creation hook: book['natjit], read by ev.l's `ala` on
; EVERY closure built, top-level AND embedded in a fn/let body (the reach the ev-rebind
; in ai/glaze/auto.l never had -- it only saw the form handed to `ev`). A qualifying leaf (the
; emit grammar over its frame [imps args]) is native-backed AT CREATION and DEOPTS into
; the closure's own bytecode `e` on overflow -- so native is never wrong, just faster.
;
; Why this is safe where the source-rewrite jit-walk wasn't:
;  * transparent -- the native cell keeps value[-1]=s (the surface src), so =/show see
;    the source; the enclosing closure's src is never rewritten.
;  * id?-distinct -- a fresh native cell per `ala` call (no compile cache), exactly like
;    bytecode closures: !(id? (\ x E) (\ x E)) holds.
;  * macro-safe -- compiles the SURFACE body `(last (cup s))` (post-opfix, pre-tag), so
;    iop/apx tags never reach codegen; a macro/non-arith body simply fails the grammar
;    and stays bytecode.
;  * no double-compile -- the deopt target is `e` itself (the bytecode closure ala built),
;    passed as nat/natn's `interp`; no separate (ev lam) pass.
; Loops are NOT caught here (their body isn't leaf-grammar) -- they stay bytecode, or use
; ai/glaze/auto.l's counted-loop path. Rides the BAKED glaze through the module books
; (the binds just below). x86-64 only.
(: assemble (holo 'assemble)                                                 ; through the module books (crew/holo/export.l,
   emit (glaze 'emit)  coreir (glaze 'coreir)  deoptir (glaze 'deoptir)     ;   ai/glaze/export.l) -- this stream cat-loads
   loopinfo (glaze 'loopinfo)  njit-loop (glaze 'njit-loop)                 ;   post-boot, so nothing folded for it. loop lane
   loopinfo-n (glaze 'loopinfo-n)  njit-loop-n (glaze 'njit-loop-n)         ;   (unify with auto-ev): the counted + N-VAR back-edges
   calloutinfo (glaze 'calloutinfo)  jitcalloutx (glaze 'jitcalloutx)       ;   + the CALL-OUT loop: a counted sum whose body calls a global closure (the stackless bridge)
   qualfr (glaze 'qualfr)  jitfrx (glaze 'jitfrx)                           ;   plus the float-RESULT leaf, all owned natively at
   anat-defs (glaze 'anat-defs)  jgir-ok? (glaze 'jgir-ok?)  jitgroupirx (glaze 'jitgroupirx)  ; creation. + the (always-on) GROUP
   ; lane: parse defs (anat-defs), op-cover (jgir-ok?), compile PURE (jitgroupirx, e deopt). The pre-analysis
   ; LOWERING hook (book['welow], church + HOF) now lives PRE-EGG in ai/ev.l -- the sole welow, no shadow here.
   (exprn ps e) (? (member? e ps) 1  (whole? e) 1                          ; var in frame | int literal
                   (two? e) (: op (cap e)
                               (? (member? op (cat '(+ - * // % & | ^ < <= > >= =) (? (getenv "AI_PARTIAL_GLAZE") '(<< >>) ()))) (&& (exprn ps (caup e)) (exprn ps (caup (cup e))))
                                  (= op '?) (&& (two? (cup (cup (cup e)))) !(two? (cup (cup (cup (cup e)))))
                                               (exprn ps (caup e)) (exprn ps (caup (cup e))) (exprn ps (caup (cup (cup e)))))
                                  0))
                   0)
   ; opnd-ok? -- every OPERAND-position leaf symbol in e is a frame param. heads are op-checked by
   ; jgir-ok?; in FIRST-ORDER group code a group name only ever appears as a HEAD, so a bare-symbol
   ; operand that isn't a frame var is a FREE capture -> reject (jgir compiles a body over the frame
   ; params only; it has no slot to bind an outer var). the synthetic-__outer tail guard.
   (opnd-ok? ps e) (? (two? e) (all (\ x (opnd-ok? ps x)) (cup e))  (name? e) (member? e ps)  1)
   ; gdefs-ok? -- the SAME free-capture guard, per group DEF body: jgir binds a def over ITS OWN frame
   ; params only, so an operand leaf a def reads that isn't one of that def's params is an outer capture
   ; with no slot. opnd-ok? only ever guarded the TAIL; a trailing-call named-let `(\ n (: (go i a) (- n 3)
   ; (go 0 0)))` slips a free `n` into go's body, which the group lane then compiled reading go's LAST arg
   ; slot (n=0 -> -3). Guard every def body too -> a free-reading body DEOPTS to bytecode (sound), never
   ; miscompiles. gd = ((name p..) . body): (cup (cap gd)) = the def's frame params, (cup gd) = its body.
   (gdefs-ok? gds) (all (\ gd (opnd-ok? (cup (cap gd)) (cup gd))) gds)
   fires #0                                          ; a probe: how many closures the hook native-backed
   ; natjit e s a gv -- e = the bytecode entry (deopt target), s = (\ frame.. body) the
   ; surface src, a = arity, gv = ala's global resolver (this hook is post-egg; `book`/`gv`
   ; are mopped here, so ala hands its folded gv down for the call-out lane to resolve a free
   ; global). ps = (init (cup s)) = the frame [imps args]; body = the surface body. compile
   ; body over ps; deopt -> e. non-qualifying -> e unchanged.
   (natjit e s a gv)
    (: ps (init (cup s))  body (last (cup s))
       (? (&& (two? s) (two? (cup (cup s))) (exprn ps body))         ; >=1 param, a body, leaf grammar
          (: _ (pin fires () (+ 1 (peep fires () 0)))                  ; compile via the neutral-IR lane (coreir); deopt target = e
             (nif (emit (peep (assemble 'x64 (coreir 'x64 ps body (deoptir 'x64 (? (= a 1) 0 1)))) 'bytes 0)) e s a))
          ; FLOAT-RESULT leaf -- (\ x <fexpr>) that BOXES a gem (auto-ev's qualfr/jitfr lane).
          ; one param only (qualfr's shape), so a captured float leaf falls through for now. deopt -> e,
          ; not (ev s): jitfr bakes (ev lam), which under the hook would re-enter ala -> so jitfrx takes e.
          (qualfr s)
            (: _ (pin fires () (+ 1 (peep fires () 0))) (jitfrx s 'x64 e))
          ; NOT a leaf -- try the counted-loop lane, then the general N-VAR loop lane (auto-ev's
          ; njit-loop / njit-loop-n, but deopting to `e`, the bytecode ala already built, NOT
          ; (base-ev s): re-interpreting s here would re-enter ala -> natjit -> ... So natjit passes
          ; e; owning the loop's back-edge is the big win over the leaf. The N-VAR lane's post-overflow
          ; deopt is cf-deopt's matrix-power closure (C-finite) OR e -- both bytecode under the hook.
          (: li (loopinfo s)
             (? li (: _ (pin fires () (+ 1 (peep fires () 0)))
                      (njit-loop s (cap li) (caup li) (caup (cup li)) (caup (cup (cup li))) e))
                (: ln (loopinfo-n s)
                   (? ln (: _ (pin fires () (+ 1 (peep fires () 0)))
                            (njit-loop-n s (cap ln) (caup ln) (caup (cup ln)) (caup (cup (cup ln))) (caup (cup (cup (cup ln)))) e))
                    ; CALL-OUT loop lane: a counted sum `(\ n (sum_{i<n} (F i)))` whose per-step term calls a
                    ; RESOLVABLE GLOBAL closure F -- glazed as the STACKLESS callout bridge (emit.l jitcalloutx),
                    ; F's value baked into value[1] as (F . twin), the two soundness gates guarding the result.
                    ; F is resolved via `gv` (ala's folded resolver; the hook can't reach the book). Single-param
                    ; (no imps) => F is free => a global; a captured / multi-arg callout is future (needs a frame-
                    ; based callee reading F from the [imps args] frame). Redefinition-stale like any baked global.
                    (: ci (calloutinfo s)  fv (? ci (gv ci 0) 0)
                       (? (&& ci (lit? fv))
                          (: _ (pin fires () (+ 1 (peep fires () 0))) (jitcalloutx fv s))
                      ; GROUP lane (always-on) -- a reusable closure
                      ; (\ frame.. <first-order mutually-recursive arith group>) whose tail calls the group.
                      ; auto-ev can't reach this (never gets the closure body as a callable-later unit); natjit
                      ; does, at ala-build. PURE path: parse the defs (anat-defs), op-cover (jgir-ok?), compile
                      ; with jitgroupirx and `e` as deopt -- NO ev/base-ev/autogroup (all re-enter ala mid-build
                      ; -> crash). Scope: a FIRST-ORDER group (no church/hof lifting); the tail is a flat call
                      ; (entry frame..) OR any arith over group calls (routed through a synthetic __outer entry).
                      ; at ala the body is post-feel: define-sugar `(fib n) B` is DESUGARED to `fib (\ n B)`,
                      ; so anat-defs yields dds = ((name . (\ p.. B))..). Convert to jitgroupir's ((name p..) . B).
                      ; TWO shapes: a FLAT tail (entry frame..) -- the outer closure IS the group entry, no
                      ; indirection; or a GENERAL tail (any arith over group calls -- (+ 1 (fib m)), a reordered
                      ; /computed-arg call, tree recursion) -- synthesize an entry ((__outer . frame) . tail) and
                      ; make IT the group entry, so the outer closure evaluates the tail then dispatches. opnd-ok?
                      ; rejects a tail that reads a captured var (jgir binds only the frame); jgir-ok? gates ops.
                      (: pd (? (&& (two? body) (id? (cap body) ':)) (anat-defs (cup body)) ())
                         dds (? pd (cap pd) ())  tail (? pd (caup pd) ())
                         okshape (&& pd (two? tail) (all (\ dd (&& (two? dd) (name? (cap dd)) (two? (cup dd)) (id? (cap (cup dd)) '\) (two? (cup (cup dd))))) dds))   ; every def is name (\ p.. B)
                         gdefs (? okshape (map (\ dd (: lam (cup dd) (link (cat (L (cap dd)) (init (cup lam))) (last (cup lam))))) dds) ())   ; ((name p..) . B)
                         gnames (map (\ d (cap (cap d))) gdefs)
                         flat? (&& okshape (member? (cap tail) gnames) (= (cup tail) ps))       ; tail IS (entry frame..)
                         osym '__outer  agdefs (? okshape (cat gdefs (L (link (link osym ps) tail))) ())   ; group + synthetic ((__outer . frame) . tail)
                         (? (&& flat? (jgir-ok? gdefs) (gdefs-ok? gdefs))                         ; FLAT: entry direct, zero indirection
                            (: _ (pin fires () (+ 1 (peep fires () 0))) (jitgroupirx gdefs (cap tail) 'x64 e s))   ; stamp the OUTER src s -> =/show transparent vs the bytecode twin
                            (&& okshape (! (member? osym gnames)) (opnd-ok? ps tail) (jgir-ok? agdefs) (gdefs-ok? gdefs))   ; GENERAL tail via the synthetic entry
                            (: _ (pin fires () (+ 1 (peep fires () 0))) (jitgroupirx agdefs osym 'x64 e s))
                            e))))))))))
   (fired? n) (< n (peep fires () 0))                 ; did the hook fire since count n?
 _ (assert
    ; --- embedded leaves get native-backed at creation, and compute correctly ---
    (: n (peep fires () 0)
       (&& (31 = (ev '(: f (\ x (+ (* x 3) 1)) (f 10))))            ; leaf in a let body
           (fired? n)))                                             ; ... the hook fired on it
    (9000000000000000000 = (ev '((\ x (* x x)) 3000000000)))        ; embedded leaf, applied inline -> deopt -> bignum
    (3 = (ev '(: g (\ x (cap x)) (g '(3 4)))))                      ; non-arith body -> stays bytecode, still right
    ; --- an embedded FLOAT-RESULT leaf: native gem box at creation, == interp, deopts on a non-float arg ---
    (: n (peep fires () 0)  fr (ev '(: f (\ x (+ (* x 1.5) 2.0)) f))   ; f built by ala -> the float lane fires
       (&& (gem? (fr 4)) (8.0 = (fr 4)) (= (fr 4) ((\ x (+ (* x 1.5) 2.0)) 4))   ; boxes a gem, == the interpreter
           (fired? n) (= (fr 'nope) ((\ x (+ (* x 1.5) 2.0)) 'nope))))   ; ... the hook fired, and a non-float arg deopts == interp
    ; --- an embedded N-VAR loop (iterative fib i,a,b): native back-edge at creation, == interp ---
    (: n (peep fires () 0)  fib (ev '(: f (\ m ((: (go i a b) (? (< i m) (go (+ i 1) b (+ a b)) a)) 0 0 1)) f))
       (&& (55 = (fib 10)) (fired? n)                                       ; the hook owned the loop; fib(10)=55
           (= (fib 20) ((\ m ((: (go i a b) (? (< i m) (go (+ i 1) b (+ a b)) a)) 0 0 1)) 20))   ; == the interpreter
           (= (fib 100) ((\ m ((: (go i a b) (? (< i m) (go (+ i 1) b (+ a b)) a)) 0 0 1)) 100))))  ; ... and past fixnum: cf-deopt's bignum matrix path == interp
    ; --- an embedded CAPTURING closure: native captured closure, transparent ---
    (: mk (ev '(\ y (\ x (+ x y))))  a5 (mk 5)                      ; inner (\ x (+ x y)) is the embedded one
       (&& (15 = (a5 10)) ('(6 7 8) = (map a5 '(1 2 3)))            ; native captured closure, composes
           (= a5 ((\ y (\ x (+ x y))) 5))))                         ; ... and = the interpreter's instance
    ; --- id? + transparency on an embedded CAPTURING leaf pulled out as a value ---
    ; (the leaf must CAPTURE (z) -- a closed leaf like (\ x (+ x 0)) hoists to a shared
    ; constant, so (id 9) twice is one object; a capturing one is allocated per call.
    (: id (ev '(\ z (\ x (+ x z))))  f (id 9)  g (id 9)            ; inner CAPTURES z -> a fresh native cell per call
       (&& (19 = (f 10)) (= f ((\ z (\ x (+ x z))) 9)) !(id? f g))) ; computes right, = the interp instance, yet distinct
   ))  ; NOTE: baked as a boot module now -> SILENT on load (no puts banner; it polluted tool stdout, e.g. spec2coq -> gen.v). asserts stay (silent unless they fail).
