; ============================================================================
; jit/auto.l -- the AUTOMATIC ev hook. After this loads, a qualifying single-param
; (\ p <arith>) compiled by `ev` becomes native machine code with NO explicit
; (jit ...) call -- defining a lambda the normal way, or passing one to a
; higher-order function, just goes fast. Roadmap step 2, the integration half.
;
; Load AFTER jit/kernel.l (it reuses kernel.l's codegen -- arithp, jit):
;
;     make host
;     out/host/love -l jit/kernel.l jit/auto.l     # kernel ALL PASS, then auto ALL PASS
;
; x86_64 host ONLY (kernel.l emits x86 bytes), so this is a standalone demo kept
; out of the gate corpus, like jit/kernel.l + forge.l + probe.l.
;
; HOW IT WORKS, and why it's safe here but not yet baked into the compiler:
;
;  * The seam is the GLOBAL `ev`. The repl and the cli/g_evals_ loader compile
;    each form via the late-bound (ev 'ev form) -- the symbol `ev` is evaluated
;    fresh every time -- so redefining the global `ev` is picked up immediately.
;    (The self-hosted ev in love/ev.l captures `opfix` as a folded constant at
;    egg-bake, so redefining opfix would NOT reach it; redefining ev itself does.)
;  * The new ev is  (\ form (base-ev (jit-walk form))): a source->source pass
;    that rewrites every qualifying (\ p <arith>) into (\ <forged native closure>)
;    -- i.e. a QUOTE of the closure value -- then hands the result to the real
;    compiler. The forge happens once, at compile time, per lambda expression.
;  * jit-walk is CONSERVATIVE about the reader's code/data split: it leaves quote
;    ((\ d), one operand), quasiquote ((qq ..)), and macro-defs ((:: ..)) verbatim,
;    so it can never corrupt data. It DOES walk into application/:/? subforms and
;    lambda bodies, so a (\ p arith) in argument position (the HOF case) is caught.
;  * WHY NOT BAKED IN: a forged buf is a host mmap address that can NEVER be baked
;    into the egg, and the codegen is x86-only, so the production hook belongs in
;    `opfix` (which already has the exact code/data traversal) guarded by `born`
;    and target arch -- a compiler change needing a full re-gate. This runtime
;    redefinition demonstrates the behavior with zero risk to the bootstrap.
;  * KNOWN GAPS (safe -- they only miss coverage, never miscompile): lambdas inside
;    quasiquote-unquotes or unexpanded macro args aren't reached; only single-param
;    (\ p <arith>) over + - * // % < <= > >= = qualifies (see jit/kernel.l).

(: base-ev ev)                                  ; capture the interpreter compiler BEFORE we shadow it

; --- a tiny stat so the demo can PROVE the hook fired (native is otherwise
; behaviourally identical to the VM, by design). jstat 0 holds the count;
; (njit x) reads it -- a one-arg reader, since love's (f) with no operand is f. ---
(: jstat (tablet 0)
   (njit _) (peep jstat 0 0))

; --- is e exactly a single-param (\ p <arith>) we can compile? ---
(: (qual e)
   (&& (twop e) (idp (cap e) '\) (= 3 (tally e)) (symp (caup e))
       (arithp (caup (cup e)) (caup e))))       ; body is arith in the param (caup e)

; --- source -> source: qualifying lambdas become quoted native closures ---
(: (jit-walk e)
   (? !(twop e) e                                       ; atom: unchanged
      (qual e) (: _ (pin jstat 0 (+ 1 (peep jstat 0 0))) (list '\ (jit e)))  ; count + (\ p arith) -> (\ <native closure>)
      (: h (cap e)
       (? (idp h '\) (? (= 2 (tally e)) e               ; (\ d): quote = DATA, leave verbatim
                        (cons '\ (map jit-walk (cup e))))  ; other lambda: walk body, keep params
          (idp h 'qq) e                                 ; quasiquote: DATA, leave (conservative)
          (idp h '::) e                                 ; macro def: template is data, leave
          (map jit-walk e)))))                          ; application / : / ? : walk every element

; ============================================================================
; GO LIVE: redefine the global ev. From here, every form the loader/repl compiles
; via (ev 'ev form) passes through jit-walk first.
(: ev (\ form (base-ev (jit-walk form))))

; ============================================================================
; PROOF -- these forms are themselves loaded through the now-live ev, so the
; lambdas in them are jitted as a side effect of being defined the NORMAL way.
(: sq (\ x (* x x)))                            ; defined normally -> jitted, no (jit ...) call
(: f  (\ n (- (* 3 n) 7)))                      ; param n, jitted
(: hof (foldl (+) 0 (map (\ k (* k k)) (jot 5))))   ; the map lambda jitted in ARGUMENT position
(: _ (dot (+ "lambdas turned native so far: " (+ (show (njit 0)) "\n")))   ; sq, f, the map's (\ k ..) = 3
   _ (dot (+ "sq 12       = " (+ (show (sq 12)) "   (== 144)\n")))
   _ (dot (+ "f 10        = " (+ (show (f 10)) "   (== 23)\n")))
   _ (dot (+ "sq 4e9      = " (+ (show (sq 4000000000)) "   (bignum via bail)\n")))
   _ (dot (+ "map-sum jot5= " (+ (show hof) "   (== 30, 0+1+4+9+16)\n")))
   ; SAFETY: ordinary code still computes correctly through the hooked ev
   _ (dot (+ "safety foldl= " (+ (show (foldl (+) 0 (jot 100))) "   (== 4950)\n")))
   _ (dot (+ "safety sort = " (+ (show (sort '(3 1 2))) "   (== (1 2 3))\n")))
   _ (dot (+ "safety quote= " (+ (show '(\ x (* x x))) "   (DATA, NOT jitted)\n")))   ; quote stays data
   _ (dot (? (= 30 hof) (? (= 144 (sq 12)) (? (= 23 (f 10)) (? (= 4950 (foldl (+) 0 (jot 100)))
        "ALL PASS\n" "FAIL foldl") "FAIL f") "FAIL sq") "FAIL hof")))
