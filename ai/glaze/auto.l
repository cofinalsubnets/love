; auto -- the transparent auto-hook: rebind `ev` so a QUALIFYING closure compiles to
; NATIVE automatically. No user-facing verb -- you call `ev` (or eval a closure) as
; always; qualifying ones are just faster, and =/show-IDENTICAL to their source.
; Everything else falls through to the base interpreter unchanged.
;
; Shapes that qualify (the emitter's grammar; E := var | int | (OP E E) | (? E E E),
; OP in + - * // % & | ^ < <= > >= =):
;   LEAF1 (\ x E)            -- E over x
;   LEAFN (\ p0 .. p_{n-1} E) -- E over the params, any arity n>=2 (currying via lvm_cur; natn)
;   FLEAF (\ x F)            -- F a FLOAT body (cgf's +-*/ over a fixnum param + consts); the
;         RESULT is a heap-boxed gem (jitfr). Sound ONLY when the param is floated at first use
;         (allsafe) -- else the interpreter keeps an int subexpr exact and native rounds early.
;   LOOP  (\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a B)) a)) 0 0))  -- a native counted
;         loop summing B(i) for i<n; B in the same grammar over i. Owning the LOOP is
;         where the big win is (cf. the leaf's ~6%): the back-edge stays native.
;
; ev is 1-arg, so the loader's `(ev 'ev r)` = `((ev 'ev) r)` still works after the
; rebind; njit/njit-loop call the captured base-ev -> no jit<->ev re-entry. Load AFTER
; ai/glaze/emit.l (uses emit/cgv/ld-x/ld-i/epilogue/loopcode/nat). ⚠ x86-64.
(: base-ev ev
   ; the emitter's expression grammar over var v: var | int | arith | cmp | (? t a b)
   (exprp e v) (? (= e v)   1
                  (whole? e)  1
                  (two? e)  (: op (cap e)
                               (? (member? op '(+ - * // % & | ^ < <= > >= =)) (&& (exprp (caup e) v) (exprp (caup (cup e)) v))
                                  (= op '?) (&& (two? (cup (cup (cup e)))) !(two? (cup (cup (cup (cup e)))))   ; exactly 3 operands
                                               (exprp (caup e) v) (exprp (caup (cup e)) v) (exprp (caup (cup (cup e))) v))
                                  0))
                  0)
   ; --- leaf: (\ x E) ---
   (qual lam) (&& (two? lam) (= (cap lam) '\) (two? (cup lam)) (name? (caup lam))                ; (\ v E), v any symbol
                  (two? (cup (cup lam))) !(two? (cup (cup (cup lam)))) (exprp (caup (cup lam)) (caup lam)))
   ; --- arity-N leaf: (\ p0 .. p_{n-1} E), E over the params (any distinct symbols) ---
   (exprn ps e) (? (member? e ps) 1  (whole? e) 1
                   (two? e) (: op (cap e)
                               (? (member? op '(+ - * // % & | ^ < <= > >= =)) (&& (exprn ps (caup e)) (exprn ps (caup (cup e))))
                                  (= op '?) (&& (two? (cup (cup (cup e)))) !(two? (cup (cup (cup (cup e)))))
                                               (exprn ps (caup e)) (exprn ps (caup (cup e))) (exprn ps (caup (cup (cup e)))))
                                  0))
                   0)
   (distinctp l) (? !(two? l) 1  (member? (cap l) (cup l)) 0  (distinctp (cup l)))        ; no repeated param
   (qualn lam) (: ps (? (two? (cup lam)) (init (cup lam)) 0)  body (? (two? (cup lam)) (last (cup lam)) 0)
                  (&& (two? lam) (= (cap lam) '\) (two? (cup lam))
                      (all name? ps) (< 1 (tally ps)) (distinctp ps)                     ; >=2 distinct symbol params
                      (exprn ps body)))
   (njit lam) (: v (caup lam) (nif (emit (+ (cgv v (\ d (fxv 0 d)) (caup (cup lam)) 0) epilogue)) (base-ev lam) lam 1))  ; v any param name, fixnum-guarded
   ; --- loop: match the tail-recursive counted-sum skeleton, extract (B counter) ---
   (loopinfo lam)
    (: M    (caup (cup lam))                                ; lambda body
       S    (cap M)   z1 (caup M)   z2 (caup (cup M))       ; M = (S 0 0)
       G    (caup S)  IF (caup (cup S))                     ; S = (: (go i a) IF)
       GO   (cap G)   I (caup G)    A (caup (cup G))        ; (go i a)
       T    (caup IF) THEN (caup (cup IF)) ELS (caup (cup (cup IF)))   ; (? T THEN ELS)
       STEP (caup THEN) ACC (caup (cup THEN))               ; THEN = (go STEP ACC)
       B    (caup (cup ACC))                                ; ACC = (op a B)
       op   (? (two? ACC) (cap ACC) 0)  cmp (? (two? T) (cap T) 0)   ; the fold op + the loop-test comparison
       ok (&& (two? lam) (= (cap lam) '\) (name? (caup lam))                  ; (\ N ..)
              (two? (cup (cup lam))) !(two? (cup (cup (cup lam))))           ; one body
              (two? M) (= z1 0) !(two? (cup (cup (cup M))))                  ; (S 0 a0)
              (two? S) (= (cap S) ':) (name? GO) (name? I) (name? A) !(= I A)   ; (: (go i a) IF)
              (two? IF) (= (cap IF) '?) (= ELS A)                            ; (? .. .. a)
              (two? T) (member? cmp '(< <= > >= =)) (= (caup T) I) (= (caup (cup T)) (caup lam))  ; (cmp i n)
              (= (cap THEN) GO)                                              ; (go ..)
              (two? STEP) (= (cap STEP) '+) (= (caup STEP) I) (= (caup (cup STEP)) 1)  ; (+ i 1)
              (two? ACC) (member? op '(+ *)) (= (caup ACC) A) (exprp B I)       ; (op a B), op in {+,*}, B over i
              (= z2 (foldinit op)))                                          ; a0 matches the op's identity (0 / 1)
       (? ok `(B I op cmp) 0))
   (njit-loop lam B cv op cmp) (nif (emit (loopcode B cv op cmp)) (base-ev lam) lam 1)
   ; --- general N-VARIABLE loop: (\ n ((: (go v0..vk) (? T (go U..) R)) I0..Ik)),
   ; up to 3 loop vars + arbitrary update exprs -- this is the shape iterative fib/tak
   ; take (i,a,b with updates b and a+b), not just the fold skeleton above.
   (loopinfo-n lam)
    (: BODY (? (two? (cup lam)) (caup (cup lam)) 0)
       S    (? (two? BODY) (cap BODY) 0)  inits (? (two? BODY) (cup BODY) 0)
       G    (? (two? S) (caup S) 0)
       IF   (? (&& (two? S) (two? (cup S))) (caup (cup S)) 0)
       GO   (? (two? G) (cap G) 0)  vars (? (two? G) (cup G) 0)
       T    (? (two? IF) (caup IF) 0)
       THEN (? (&& (two? IF) (two? (cup IF))) (caup (cup IF)) 0)
       R    (? (&& (two? IF) (two? (cup (cup IF)))) (caup (cup (cup IF))) 0)
       updates (? (two? THEN) (cup THEN) 0)
       fr   (link (caup lam) vars)                                  ; cgl frame: {n, v0..vk}
       ok (&& (two? lam) (= (cap lam) '\) (name? (caup lam)) (two? (cup (cup lam))) !(two? (cup (cup (cup lam))))
              (two? BODY) (two? S) (= (cap S) ':) (two? (cup S)) !(two? (cup (cup (cup S))))   ; (: G IF)
              (two? G) (name? GO) (two? vars) (all name? vars) (distinctp vars) !(member? GO vars)
              (< (tally vars) 4)                                    ; <= 3 loop vars (register limit)
              (two? IF) (= (cap IF) '?) (two? THEN) (= (cap THEN) GO)   ; (? T (go U..) R)
              (= (tally updates) (tally vars)) (= (tally inits) (tally vars))
              (two? T) (member? (cap T) '(< <= > >= =)) (exprn fr T)   ; TEST a comparison over {n,vars}
              (all (\ u (exprn fr u)) updates) (exprn fr R)         ; updates + RESULT exprs over {n,vars}
              (all whole? inits))                                     ; inits are fixnum consts
       (? ok `(vars updates T R inits) 0))
   (njit-loop-n lam vars updates test result inits)
    (nif (emit (loopcode-n (caup lam) vars updates test result inits)) (base-ev lam) lam 1)
   ; --- captured-closure CONSTRUCTOR (\ p (\ q E)): a nest of 1-arg lambdas, E over
   ; {p,q}. Compiled as the flat 2-param native (\ p q E); applying it to p yields a
   ; native CAPTURED closure -- fully transparent (= the interpreter's ((2param) p)
   ; partial form: native captures via partial-apply are =/show-identical to interp).
   ; The constructor itself normalizes to the flat 2-param (a curry-equivalent form).
   (qualc lam) (: p (caup lam)  inner (? (two? (cup lam)) (caup (cup lam)) 0)
                  (&& (two? lam) (= (cap lam) '\) (two? (cup lam)) (name? p)
                      (two? (cup (cup lam))) !(two? (cup (cup (cup lam))))               ; (\ p INNER), one body
                      (two? inner) (= (cap inner) '\) (two? (cup inner)) (name? (caup inner)) !(= p (caup inner))
                      (two? (cup (cup inner))) !(two? (cup (cup (cup inner))))            ; INNER = (\ q E), q != p
                      (exprn `(p (caup inner)) (caup (cup inner)))))
   (flatc lam) (: inner (caup (cup lam)) `('\ (caup lam) (caup inner) (caup (cup inner))))  ; (\ p (\ q E)) -> (\ p q E)
   ; --- FLOAT-RESULT leaf (\ x <fexpr>) -> jitfr (emit.l): a body that BOXES a gem, over cgf's +-*/
   ;     grammar (a fixnum param + float/int consts). SOUNDNESS vs the interpreter turns on WHEN the
   ;     param is floated: the native lane cvtsi2sd's it at EVERY use, but the interpreter keeps an
   ;     INTEGER subexpression exact (a bignum, even) until a float forces promotion -- so (+ (* x 3) 1.5)
   ;     DIVERGES at x=2^53+1 (native rounds the param early). `fty` types each node F / I / 0(reject);
   ;     `allsafe` demands the param NEVER sit inside an I-typed COMPOUND (it must meet a float at first
   ;     contact), so native's per-use flotation lands on the interpreter's promotion point exactly.
   (fty e v) (? (= e v) 'I  (gem? e) 'F  (whole? e) 'I                                           ; param/int = I, float const = F
                (&& (two? e) (= 3 (tally e)) (member? (cap e) '(+ - * /)))                       ; a binary +-*/ form
                  (: op (cap e) ta (fty (caup e) v) tb (fty (caup (cup e)) v)
                     (? (|| (id? ta 0) (id? tb 0)) 0                                             ; an operand rejected -> reject
                        (member? op '(+ - *)) (? (|| (id? ta 'F) (id? tb 'F)) 'F 'I)            ; +-*: float iff an operand is float
                        (|| (id? ta 'F) (id? tb 'F)) 'F  0))                                     ; /: float-division ok; int/int is value-dependent -> reject
                0)
   (allsafe e v) (? (! (occurs? v e)) 1  (! (two? e)) 1  (id? (fty e v) 'I) 0                    ; an I-typed COMPOUND holding the param -> late promotion -> reject
                    (&& (allsafe (caup e) v) (allsafe (caup (cup e)) v)))
   (qualfr lam) (&& (two? lam) (= (cap lam) '\) (two? (cup lam)) (name? (caup lam))
                    (two? (cup (cup lam))) !(two? (cup (cup (cup lam))))                         ; (\ v BODY), one param + one body
                    (: v (caup lam) body (caup (cup lam))
                       (&& (id? (fty body v) 'F) (allsafe body v))))                             ; BODY is a float RESULT, param floated everywhere
   ; --- the GRID NEST (general, D-dimensional): a letrec of D counted-loop functions wrapping a
   ; FLOAT RECURRENCE -- the inner def self-recurses with an (&& (< it LIM) (cmp TEST BOUND)) escape
   ; test; each loop def is (? (< cnt N) (self ..outer.. (+ cnt 1) ..(+ acc INNERCALL)..) acc), the
   ; outermost driven by the trailing (driver 0 ..). autonat reads this STRAIGHT FROM SOURCE, walks
   ; the loop chain to recover D bounds + counters, classifies the recurrence into M invariants /
   ; N float-vars / their updates, and builds the whole-grid native via jitfgridn (emit.l). Then it
   ; rewrites the OUTERMOST loop's body to call the native. The mandelbrot 64x64 grid is the D=2,
   ; M=2, N=2 instance; any D>=1 and M+N<=6 within the xmm budget glaze. Returns the form UNCHANGED
   ; if it doesn't fit, so every other form passes through untouched. ⚠ x86-64 (-> jitfgridn).
   (anat-defs bs) (? (atom? (cup bs)) (L () (cap bs))            ; a : binding list -> (pairs body); pairs = ((nameform . body)..)
                     (: r (anat-defs (cuup bs))
                        (L (link (link (cap bs) (caup bs)) (cap r)) (caup r))))
   (anat-cond? e) (&& (two? e) (id? (cap e) '?))                 ; a (? ..) form?
   (afind pred l) (? (atom? l) () (pred (cap l)) (cap l) (afind pred (cup l)))
   (afilter pred l) (? (atom? l) () (pred (cap l)) (link (cap l) (afilter pred (cup l))) (afilter pred (cup l)))
   ; the recurrence pair: a (? (&& ..) (SELF ..) ..) whose then-branch self-calls (head = its own name)
   (anat-rec? p) (: nm (cap (cap p)) body (cup p)
                    (&& (anat-cond? body) (two? (cup (cup body)))
                        (: cond (opd body 0) then (opd body 1)
                           (&& (two? cond) (id? (cap cond) '&&) (two? then) (id? (cap then) nm)))))
   ; anat-callee: the next-inner function a loop def calls -- INNERCALL's head in (? (< cnt N)
   ; (self .. (+ acc INNERCALL)) acc) -- or () if the pair doesn't match the loop shape. The OUTERMOST
   ; loop is the one no other loop names (the driver reaches it -- maybe wrapped, e.g. (bench .. (g 0 0))).
   (anat-callee q) (: body (cup q)
      (? (! (&& (anat-cond? body) (< 1 (tally (cup (cup body)))))) ()
         (: then (opd body 1)
            (? (! (two? then)) ()
               (: accarg (last (cup then))
                  (? (! (&& (two? accarg) (id? (cap accarg) '+) (two? (cup (cup accarg))))) ()
                     (: ic (caup (cup accarg)) (? (two? ic) (cap ic) ()))))))))
   ; loopchain: walk loopnm's pair -- (? (< cnt N) (self ..(+ acc INNERCALL)..) acc) -- record
   ; (cnt N rec-args), recursing on INNERCALL's head until it reaches the recurrence recnm. The list
   ; runs OUTER->INNER; () on any structural mismatch (so autonat bails to the unchanged form).
   (loopchain loopnm pairs recnm)
    (: p (afind (\ q (id? (cap (cap q)) loopnm)) pairs)
       (? (! (two? p)) ()
          (: body (cup p)
             (? (! (&& (anat-cond? body) (< 1 (tally (cup (cup body)))))) ()
                (: cond (opd body 0) then (opd body 1)
                   (? (! (&& (two? cond) (id? (cap cond) '<) (two? then))) ()
                      (: cnt (opd cond 0) bnd (opd cond 1) accarg (last (cup then))
                         (? (! (&& (two? accarg) (id? (cap accarg) '+) (two? (cup (cup accarg))))) ()
                            (: ic (caup (cup accarg))
                               (? (! (two? ic)) ()
                                  (id? (cap ic) recnm) (L (L cnt bnd (cup ic)))             ; innermost: the recurrence call's args
                                  (: rest (loopchain (cap ic) pairs recnm)                  ; else recurse on the next loop
                                     (? (two? rest) (link (L cnt bnd ()) rest) ()))))))))))))
   ; rebind: rebuild a : binding list, replacing the outermost loop's body with (native 0)
   (anat-rebind bs outernm ng)
    (? (atom? (cup bs)) bs
       (: nm (cap bs) bd (caup bs)
          (link nm (link (? (&& (two? nm) (id? (cap nm) outernm)) (L ng 0) bd) (anat-rebind (cuup bs) outernm ng)))))
   ; --- a GROUP of mutually-recursive ARITHMETIC functions in a `:` -- each (name p..) BODY with BODY
   ; in the integer fragment `groupok?` accepts: param | int | (op E E) | (cmp E E) | (? E E E) | (g E..)
   ; where g is ANY function OF THE GROUP (self OR sibling) of matching arity. autogroup finds the
   ; maximal CLOSED such subset (a fixpoint: a fn that calls OUT of the fragment -- into link/cap, a float
   ; const, or an interpreted helper -- drops out, taking its callers with it), then rewrites EACH group
   ; binding to its OWN native (jitgroup, emit.l), so every reference -- from the `:` body OR an
   ; interpreted sibling -- resolves to native, while the calls AMONG the group stay native inside the
   ; buffer. fib/tak are SINGLETON groups; even?/odd? a 2-fn group. `groupok?` is the standalone fragment
   ; predicate (the futamura `mix` pass can reuse it as its "residual is ground arithmetic" stop oracle).
   ; Returns the form UNCHANGED if nothing fits (lists/floats/other recursion pass through). ⚠ x86-64.
   ; --- LAMBDA-LIFTING: fold a NAMED-LET in a fn body into a flat group fn, so a fn whose body is a
   ;     local recursive loop joins the call graph. A body (NL inits..) where NL = (: (g q..) GBODY) is a
   ;     local fn g (its own letrec) applied to inits. Lift g to a top-level fn g'(FV.. q..) where FV =
   ;     the ENCLOSING fn's params that occur free in GBODY -- threading FV through g's self-calls -- and
   ;     replace the body with (g' FV.. inits..). primes' `prime?` and `count` are each such a named-let
   ;     loop, so after lifting the whole trial-division graph (prime? count prime?_go count_go) is a flat
   ;     mutually-recursive group autogroup+jitgroup glaze. ONE level (whole-body named-let; GBODY flat);
   ;     a non-named-let body passes through untouched, so fib/tak/even-odd are unaffected.
   (occurs? s e) (? (two? e) (foldl (\ a x (|| a (occurs? s x))) 0 e) (id? e s))                  ; s occurs (syntactically) in e?
   (subst-call g gn fv e) (? (two? e) (? (id? (cap e) g) (link gn (cat fv (map (\ x (subst-call g gn fv x)) (cup e))))   ; (g A..) -> (gn fv.. A'..)
                                          (map (\ x (subst-call g gn fv x)) e)) e)
   (named-let? e) (&& (two? e) (: nl (cap e)                                                      ; e = ((: (g q..) GBODY) inits..) ?
                      (&& (two? nl) (id? (cap nl) ':) (two? (cup nl))
                          (: gnf (caup nl)
                             (&& (two? gnf) (name? (cap gnf)) (< 1 (tally gnf)) (all name? (cup gnf)) (distinctp (cup gnf))
                                 (two? (cup (cup nl))) !(two? (cup (cup (cup nl))))               ; (: (g q..) GBODY), body-less (one binding)
                                 (= (tally (cup e)) (tally (cup gnf))))))))                       ; inits arity == g's arity
   (subst-sym nm val e) (? (id? e nm) val (two? e) (map (\ x (subst-sym nm val x)) e) e)            ; symbol nm -> val in e
   ; norm-let: a fn body (: aux.. (g q..) GBODY (g inits..)) -- a let with VALUE aux bindings + ONE local
   ; fn + a CALL result -- normalizes to the named-let ((: (g q..) GBODY[aux inlined]) inits..) lift handles.
   ; strscan's strhash (: n (tally s) (go i h) .. (go 0 0)) is exactly this (n=(tally s) inlined into go).
   (norm-let body)
    (? (! (&& (two? body) (id? (cap body) ':) (! (atom? (cup body))))) body
       (: parsed (anat-defs (cup body)) pairs (cap parsed) result (caup parsed)
          fnps (afilter (\ pr (two? (cap pr))) pairs) auxps (afilter (\ pr (! (two? (cap pr)))) pairs)
          (? (! (&& (= 1 (tally fnps)) (two? result))) body                                         ; need exactly one local fn + a call result
             (: g (cap (cap (cap fnps))) q (cup (cap (cap fnps))) gbody (cup (cap fnps))
                (? (! (&& (id? (cap result) g) (= (tally (cup result)) (tally q)))) body            ; result must be (g inits..) matching arity
                   (: inl (\ x (foldl (\ b ap (subst-sym (cap ap) (cup ap) b)) x auxps))            ; inline every aux name -> its value
                      (link (link ': (link (link g q) (link (inl gbody) ()))) (map inl (cup result)))))))))
   (lift-pair p)                                                                                  ; (nameform . body) -> (rewritten-pair newdefs)
    (: nf (cap p) pbody (norm-let (cup p))
       (? (! (&& (two? nf) (name? (cap nf)) (< 1 (tally nf)) (named-let? pbody))) (L p ())
          (: F (cap nf) P (cup nf)  nl (cap pbody) inits (cup pbody)
             gnf (caup nl) g (cap gnf) q (cup gnf) GBODY (caup (cup nl))
             gn (intern (+ (string F) (+ "_" (string g))))                                        ; lifted name F_g (unique per enclosing fn)
             fv (gfilt (\ pp (&& (occurs? pp GBODY) (! (member? pp q)))) P)                        ; enclosing params free in GBODY
             (L (link nf (link gn (cat fv inits)))                                                ; F's body -> (gn fv.. inits..)
                (L (link (link gn (cat fv q)) (subst-call g gn fv GBODY)))))))                     ; new def: (gn fv.. q..) . GBODY'
   (unpair ps body) (? (atom? ps) (L body) (: pr (cap ps) (link (cap pr) (link (cup pr) (unpair (cup ps) body)))))   ; pairs + body -> a : binding list
   (lift form)                                                                                    ; lambda-lift every named-let fn body in a `:`
    (? (! (&& (two? form) (id? (cap form) ':) (! (atom? (cup form))))) form
       (: parsed (anat-defs (cup form)) pairs (cap parsed) body (caup parsed)
          results (map lift-pair pairs)
          allpairs (cat (map cap results) (foldl (\ a r (cat a (caup r))) () results))            ; rewritten originals ++ all the lifted defs
          (link ': (unpair allpairs body))))
   ; fold-consts: inline a top-level `:`'s WHOLE-constant value bindings (e.g. strscan's `hmod 1000000007`)
   ; into every body and drop them -- so a folded constant doesn't read as an un-glazeable free symbol.
   (fold-consts form)
    (? (! (&& (two? form) (id? (cap form) ':) (! (atom? (cup form))))) form
       (: parsed (anat-defs (cup form)) pairs (cap parsed) body (caup parsed)
          consts (afilter (\ pr (&& (name? (cap pr)) (whole? (cup pr)))) pairs)
          (? (atom? consts) form
             (: sub (\ e (foldl (\ b pr (subst-sym (cap pr) (cup pr) b)) e consts))
                keep (afilter (\ pr (! (&& (name? (cap pr)) (whole? (cup pr))))) pairs)
                (link ': (unpair (map (\ pr (link (cap pr) (sub (cup pr)))) keep) (sub body)))))))
   ; --- LOCAL LET (delet): inline a fn body that is a PURE value-let -- (: n1 v1 .. result), every binding
   ;     a plain symbol (no local fn -> that is norm-let/lift's job), names distinct -- into ONE fragment
   ;     expression by ordered substitution, so a fn that names its intermediates joins the group. The
   ;     fragment is pure (arithmetic + pure sibling calls), so substitution is value-preserving (== the
   ;     interpreter's once-evaluated shared binding); the ONLY divergence is recomputation, so a binding
   ;     holding a CALL may inline only when used <=1 time -- a call-free (dup-cheap) value inlines freely,
   ;     a multi-use call BAILS to the unchanged `:` body (which groupok? rejects -> interp, sound, no perf
   ;     cliff). A non-let body / a body with a local fn passes through (fib/tak/strscan untouched). delet
   ;     runs BEFORE lift: a value-let may WRAP a named-let loop, whose free vars it must fix up first.
   (dcount s e) (? (id? e s) 1 (two? e) (foldl (\ a x (+ a (dcount s x))) 0 e) 0)            ; syntactic occurrences of s in e
   (dcheap? e) (? (atom? e) 1  (dquote? e) 0                                                  ; dup-cheap: arith/cmp/bit/peep/tally, NO call
                  (: h (cap e) (? (|| (id? h '?) (member? h '(+ - * // % & | ^ < <= > >= = peep tally))) (all dcheap? (cup e)) 0)))
   (delet-go pairs result orig)
    (? (atom? pairs) result
       (: pr (cap pairs) nm (cap pr) val (cup pr) rest (cup pairs)
          uses (foldl (\ a e (+ a (dcount nm e))) 0 (cat (map cup rest) (L result)))         ; uses in subsequent values + body
          (? (&& (! (dcheap? val)) (< 1 uses)) orig                                          ; would duplicate a call -> bail to interp
             (delet-go (map (\ p (link (cap p) (subst-sym nm val (cup p)))) rest) (subst-sym nm val result) orig))))
   (delet-body body)
    (? (! (&& (two? body) (id? (cap body) ':) (! (atom? (cup body))))) body
       (: parsed (anat-defs (cup body)) pairs (cap parsed) result (caup parsed) names (map cap pairs)
          (? (! (&& (all name? names) (distinctp names))) body                                ; named (non-define-sugar) distinct bindings only -- a (g q..) local fn defers to norm-let/lift
             (delet-go pairs result body))))
   (delet form)                                                                              ; inline value-lets in every fn body of a `:`
    (? (! (&& (two? form) (id? (cap form) ':) (! (atom? (cup form))))) form
       (: parsed (anat-defs (cup form)) pairs (cap parsed) body (caup parsed)
          (link ': (unpair (map (\ pr (link (cap pr) (? (two? (cap pr)) (delet-body (cup pr)) (cup pr)))) pairs) body))))
   ; --- BOOLEANS & CLAMPS (debool): lower &&/||/abs to the `?`-fragment the glaze already compiles --
   ;     exact, value-preserving rewrites (verified): (&& a b)=(? a b 0), (|| a b)=(? a a (? b b 0)),
   ;     (abs x)=(? (< x 0) (- 0 x) x). The &&/|| forms bake in the floor-clamp semantics (a false `&&`
   ;     nets 0, like all/any's bits) -- which is exactly why they equal these `?` forms, not the looser
   ;     (? a b a). && never duplicates an operand; ||/abs do, so they reuse delet's `dcheap?` guard -- a
   ;     form that would duplicate a CALL is LEFT un-lowered (groupok? then rejects the head -> interp,
   ;     sound). Bottom-up (operands lowered first), so nested compounds collapse. A no-op on any form
   ;     with none of these heads, and runs INSIDE autogroup -- so autonat (which matches the float-grid
   ;     escape test `(&& (< it L) ..)` on the RAW form, before autogroup) is unaffected. (NOTE: `min`/
   ;     `max` are array REDUCERS, not binary scalar ops -- `(min 7 3)` is `((min 7) 3)` = `(7 3)` = 3^7,
   ;     NOT 3 -- so a binary `(min a b)` is no language feature and is deliberately NOT lowered here.)
   (dband as) (? (atom? as) 1  (atom? (cup as)) (cap as)  (L '? (cap as) (dband (cup as)) 0))   ; (&& a R..) = (? a (&& R..) 0)
   (dbor as)  (? (atom? as) 0  (! (dcheap? (cap as))) (link '|| as)                             ; (|| a R..) = (? a a (|| R..)); a dup'd, so guard
                 (L '? (cap as) (cap as) (dbor (cup as))))
   (dbabs x) (? (! (dcheap? x)) (L 'abs x) (L '? (L '< x 0) (L '- 0 x) x))                       ; (abs x) = (? (< x 0) (- 0 x) x)
   (debool e)                                                                                   ; recursively lower &&/||/abs to ?
    (? (atom? e) e  (dquote? e) e
       (: y (map debool e) h (cap y) as (cup y)                                                 ; lower operands first (bottom-up)
          (? (id? h '&&) (dband as)  (id? h '||) (dbor as)
             (&& (id? h 'abs) (= 1 (tally as))) (dbabs (cap as))  y)))
   ; --- SPECIALIZATION (autospec): mix (doc/proto/mix.l, the offline partial evaluator) wired in as a
   ;     glaze recognizer -- the 1st Futamura projection COMPOSED with the native lane. an interpreter
   ;     applied to a STATIC program (a const-bound quoted AST) and a DYNAMIC input specializes: the
   ;     dispatch + AST navigation fold away to the program's straight-line arithmetic, which defoliate/
   ;     lift/autogroup then native -- so an interpreter-over-static-data loop runs as COMPILED code,
   ;     capturing the interpretation-overhead prize (interp-spec.l measured ~6.5x) the in-compiler
   ;     unfold missed. `spe` is the proto engine with `defs` (the form's fn defs) threaded as a param,
   ;     not a hardcoded table; a STATIC-driven recursion unrolls (the seen-set bounds re-entry of the
   ;     same signature, sfuel bounds a runaway), a DYNAMIC-driven one residualizes clean. autospec is a
   ;     NO-OP (id-identical) on any form with no defined-fn call over a static-data binding.
   (sstat v) (L 's v)  (sdyn c) (L 'r c)  (sstat? p) (id? (cap p) 's)  (spval p) (caup p)
   (sqv v) (L '\ v)                                                                ; quote a static datum -> seen as DATA
   (sreify p) (: v (caup p) (? (&& (sstat? p) (! (constellation? v))) (sqv v) v))  ; non-number static -> quoted
   (sstatval? p v) (&& (sstat? p) (= v (spval p)))
   (ssig apv) (map (\ p (? (sstat? p) (spval p) '_)) apv)                          ; static signature (dyn slots -> _)
   (szipenv ps apv) (? (atom? ps) () (link (L (cap ps) (cap apv)) (szipenv (cup ps) (cup apv))))
   (slook env k) (? (atom? env) (sdyn k) (id? k (caap env)) (caup (cap env)) (slook (cup env) k))  ; unbound -> dynamic
   (sdeflook nm defs) (? (atom? defs) () (id? nm (caap defs)) (cap defs) (sdeflook nm (cup defs)))
   (sprim? h) (member? h '(* - + ! cap cup caap caup cuap cuup id?))               ; arith + static AST navigation
   (ssimp1 h a b)
    (? (&& (id? h '*) (sstatval? a 1)) b   (&& (id? h '*) (sstatval? b 1)) a       ; drop the * and + units on a residual
       (&& (id? h '+) (sstatval? a 0)) b   (&& (id? h '+) (sstatval? b 0)) a
       (sdyn (L h (sreify a) (sreify b))))
   (speprim h apv)
    (? (all sstat? apv) (sstat (base-ev (link h (map sqv (map spval apv)))))       ; all static -> FOLD over quoted data
       (= 2 (tally apv)) (ssimp1 h (cap apv) (caup apv))                           ; binary -> residualize, drop units
       (sdyn (link h (map sreify apv))))
   (spcondm cs env seen defs)
    (? (atom? (cup cs)) (spe (cap cs) env seen defs)                              ; lone else
       (: cv (spe (cap cs) env seen defs)
          (? (! (sstat? cv)) (sdyn (link '? (sresidcl cv (caup cs) (cuup cs) env seen defs)))  ; dynamic test -> residual tail
             (! (spval cv)) (spcondm (cuup cs) env seen defs)                     ; static false -> drop clause
             (spe (caup cs) env seen defs))))                                     ; static true  -> take result
   (sresidcl cv then rest env seen defs)
    (link (sreify cv) (link (sreify (spe then env seen defs)) (sresidtl rest env seen defs)))
   (sresidtl cs env seen defs)
    (? (atom? (cup cs)) (L (sreify (spe (cap cs) env seen defs)))
       (: cv (spe (cap cs) env seen defs)
          (? (! (sstat? cv)) (sresidcl cv (caup cs) (cuup cs) env seen defs)
             (! (spval cv)) (sresidtl (cuup cs) env seen defs)
             (L (sreify (spe (caup cs) env seen defs))))))
   sfuel (tablet 0)
   (specall def apv seen defs)                                                    ; unfold a defined-fn call, unless in progress / out of fuel
    (: nm (cap def) ps (caup def) bd (caup (cup def)) key (link nm (ssig apv)) n (peep sfuel 'n 0)
       (? (member? key seen) (sdyn (link nm (map sreify apv)))                    ; signature in progress -> residual call
          (! n) (sdyn (link nm (map sreify apv)))                                 ; fuel out -> bail to a residual call (still correct)
          (: _ (pin sfuel 'n (- n 1)) (spe bd (szipenv ps apv) (link key seen) defs))))
   (spe x env seen defs)                                                          ; the partial evaluator
    (? (constellation? x) (sstat x)
       (nom? x) (slook env x)
       (atom? x) (sstat x)
       (: h (cap x) a (cup x)
          (? (&& (id? h '\) (atom? (cup a))) (sstat (cap a))                      ; (\ datum) quote -> a static datum
             (id? h '?) (spcondm a env seen defs)
             (sprim? h) (speprim h (map (\ e (spe e env seen defs)) a))
             (: d (sdeflook h defs)
                (? d (specall d (map (\ e (spe e env seen defs)) a) seen defs)
                     (sdyn (link h (map sreify (map (\ e (spe e env seen defs)) a)))))))))
   (smix call statenv defs) (: _ (pin sfuel 'n 100000) (sreify (spe call statenv () defs)))   ; specialize one call -> residual source
   ; autospec proper: build defs (fn bindings) + statenv (names bound to a quoted datum), then replace
   ; every call to a defined fn that mentions a static name with its specialized residual (in place).
   (sconst? v) (&& (two? v) (id? (cap v) '\) (= 2 (tally v)))                      ; a quoted-constant binding value (\ datum)
   (sment? e statn) (? (name? e) (member? e statn)  (two? e) (srefany? e statn)  0)
   (srefany? args statn) (? (atom? args) 0 (|| (sment? (cap args) statn) (srefany? (cup args) statn)))
   (specall? e defn statn) (&& (two? e) (member? (cap e) defn) (srefany? (cup e) statn))   ; defined-fn call mentioning a static name
   (swalk e statenv defs defn statn)
    (? (atom? e) e
       (dquote? e) e                                                              ; never descend into a quoted datum
       (specall? e defn statn) (smix e statenv defs)                              ; specialize this call in place
       (map (\ x (swalk x statenv defs defn statn)) e))                           ; walk EVERY element (a list head holds the loop body)
   (autospec form)
    (? (! (&& (two? form) (id? (cap form) ':) (! (atom? (cup form))))) form
       (: parsed (anat-defs (cup form)) pairs (cap parsed)
          fnps (afilter (\ pr (two? (cap pr))) pairs)
          defs (map (\ pr (link (caap pr) (link (cup (cap pr)) (link (cup pr) ())))) fnps)   ; (name (p..) body)
          statps (afilter (\ pr (&& (name? (cap pr)) (sconst? (cup pr)))) pairs)
          statenv (map (\ pr (L (cap pr) (sstat (caup (cup pr))))) statps)        ; name -> (stat datum)
          (? (! (&& (two? defs) (two? statenv))) form                            ; need a defined fn AND a static-data binding
             (swalk form statenv defs (map cap defs) (map cap statenv)))))
   ; --- DEFORESTATION: fuse a map/filter pipeline under a CONSUMER into ONE pass, then lower it over
   ;     (jot N) to the named-let LOOP `lift` already glazes -- so a combinator pipeline compiles to
   ;     native. The rewrite-level companion to the codegen recognizers; the standalone spec lives in
   ;     doc/proto/forest.l. Consumers glazed: foldl/foldr (a reduction -> a counted loop, UP for foldl,
   ;     DOWN for foldr) and all/any (a short-circuit predicate -> an early-exit loop returning the truth
   ;     BITS 0/1). all/any glaze transparently ONLY because their false value is now the fixnum 0 (the
   ;     green floor) like =/</!, not the zero point `()` -- the integer compiler returns 0, so it matches
   ;     (see ai/prel.l: all/any return truth bits). `each` is NOT here: its body is an EFFECT, outside
   ;     the arithmetic fragment. Transducer view of shortcut fusion -- map f: elem|->(f elem); filter p:
   ;     step|->(? (p elem) step skip). `dsimp` then beta-inlines the unary stage lambdas + flattens
   ;     curried operator heads to a FIRST-ORDER step. Step binders are fresh gensym noms (hygienic).
   ;     `defoliate` is a NO-OP (id-identical) on any form with no pipeline -- so non-pipeline forms are byte-unchanged.
   (dsub old new B) (? (id? B old) new (two? B) (link (dsub old new (cap B)) (dsub old new (cup B))) B)
   (dquote? x) (&& (two? x) (id? (cap x) '\) (= 2 (tally x)))                  ; (\ datum) -> a quote, never descend
   (dmap? P)   (&& (two? P) (id? (cap P) 'map))
   (dfilt? P)  (&& (two? P) (id? (cap P) 'filter))
   (dprod? P)  (|| (dmap? P) (dfilt? P))
   (dsfn P)    (caup P)  (dssrc P) (caup (cup P))                              ; (map f P') -> f / P'
   (dpeel B e felse P)                                                        ; thread step body B over (elem e, filter-skip felse) through the chain
    (? (dmap? P)  (dpeel (dsub e (L (dforest (dsfn P)) e) B) e felse (dssrc P))   ; e := (f e)
       (dfilt? P) (dpeel (L '? (L (dforest (dsfn P)) e) B felse) e felse (dssrc P)) ; (? (p e) B skip)
       (L B (dforest P)))                                                     ; base list (forest nested pipelines)
   (dfold? x) (&& (member? (cap x) '(foldl foldr)) (= 4 (tally x)) (: P (caup (cuup x)) (|| (dprod? P) (djot? P))))   ; (foldl/foldr c z P)
   (dpred? x) (&& (member? (cap x) '(all any)) (= 3 (tally x)) (: P (cap (cuup x)) (|| (dprod? P) (djot? P))))         ; (all/any q P)
   (dforest x)
    (? (atom? x)   x
       (dquote? x) x
       (dfold? x)  (: tag (cap x) c (caup x) z (cap (cuup x)) P (caup (cuup x)) e (nom 'e) a (nom 'a)
                      B0 (? (id? tag 'foldl) (L c a e) (L c e a))             ; foldl step (c a e); foldr step (c e a)
                      r (dpeel B0 e a P)                                      ; filter-skip = the acc (unchanged)
                      hd (? (id? tag 'foldl) (L '\ a e (cap r)) (L '\ e a (cap r)))
                      (L tag hd (dforest z) (caup r)))
       (dpred? x)  (: tag (cap x) q (caup x) P (cap (cuup x)) e (nom 'e) unit (? (id? tag 'all) 1 0)   ; filter-skip = the short-circuit unit
                      r (dpeel (L q e) e unit P)
                      (L tag (L '\ e (cap r)) (caup r)))
       (link (cap x) (map dforest (cup x))))
   (dspecial? h) (|| (id? h '?) (|| (id? h '\) (id? h ':)))
   (dsimp x)                                                                  ; reduce to first-order: beta unary lambdas, flatten curried heads
    (? (atom? x)   x
       (dquote? x) x
       (: y (link (dsimp (cap x)) (map dsimp (cup x))) h (cap y) as (cup y)
          (? (atom? h) y
             (&& (id? (cap h) '\) (&& (= 3 (tally h)) (= 1 (tally as)))) (dsimp (dsub (caup h) (cap as) (cap (cuup h))))
             (&& (atom? (cap h)) (! (dspecial? (cap h))))                 (dsimp (link (cap h) (cat (cup h) as)))
             y)))
   ; (jot N) is the LIST source -- the materialized chain (0 .. N-1) foldl/map iterate; the loop never
   ; builds it. (NOT iota -- that is the ARRAY @(0..N-1), which foldl/map (chain ops) do NOT iterate,
   ; so a foldl over iota interprets to z; lowering THAT would be unsound. jot only.)
   (djot? s) (&& (two? s) (id? (cap s) 'jot) (= 2 (tally s)))                 ; (jot N)
   (dstep? f)  (&& (two? f) (id? (cap f) '\) (= 4 (tally f)))                 ; (\ A E BODY)  -- a 2-param fold step
   (dstep1? f) (&& (two? f) (id? (cap f) '\) (= 3 (tally f)))                 ; (\ E BODY)    -- a 1-param predicate
   (dlowerfold x)                                                            ; (foldl/foldr STEP Z (jot N)) -> counted loop (up / down)
    (: tag (cap x) STEP (caup x) Z (cap (cuup x)) SRC (caup (cuup x))
       (? (! (&& (dstep? STEP) (djot? SRC))) x
          (: P1 (caup STEP) P2 (cap (cuup STEP)) BODY (caup (cuup STEP)) N (caup SRC) go (nom 'go)
             (? (id? tag 'foldl)                                            ; STEP=(\ a e B): P1=a P2=e ; count e UP 0..N-1
                (L (L ': (L go P2 P1) (L '? (L '< P2 N) (L go (L '+ P2 1) BODY) P1)) 0 Z)
                (L (L ': (L go P1 P2) (L '? (L '< P1 0) P2 (L go (L '- P1 1) BODY))) (L '- N 1) Z)))))   ; STEP=(\ e a B): count e DOWN N-1..0
   (dlowerpred x)                                                            ; (all/any PRED (jot N)) -> short-circuit loop over one index
    (: tag (cap x) PRED (caup x) SRC (cap (cuup x))
       (? (! (&& (dstep1? PRED) (djot? SRC))) x
          (: E (caup PRED) BODY (cap (cuup PRED)) N (caup SRC) go (nom 'go)
             (? (id? tag 'all)                                              ; all: a false body returns 0 early; run-off returns 1
                (L (L ': (L go E) (L '? (L '< E N) (L '? BODY (L go (L '+ E 1)) 0) 1)) 0)
                (L (L ': (L go E) (L '? (L '< E N) (L '? BODY 1 (L go (L '+ E 1))) 0)) 0)))))   ; any: a true body returns 1 early; run-off 0
   (dlower x)
    (? (atom? x) x (dquote? x) x
       (&& (member? (cap x) '(foldl foldr)) (= 4 (tally x))) (dlowerfold (link (cap x) (map dlower (cup x))))
       (&& (member? (cap x) '(all any)) (= 3 (tally x)))     (dlowerpred (link (cap x) (map dlower (cup x))))
       (link (cap x) (map dlower (cup x))))
   (has-pipe? x) (? (atom? x) 0  (dquote? x) 0  (dprod? x) 1  (dfold? x) 1  (dpred? x) 1  (any has-pipe? (cup x)))
   (defol-body b) (? (has-pipe? b) (dlower (dsimp (dforest b))) b)            ; fuse+lower a pipeline body, else leave it
   (defol-bs bl) (? (atom? (cup bl)) (L (defol-body (cap bl)))                ; trailing body
                    (link (cap bl) (link (defol-body (caup bl)) (defol-bs (cuup bl)))))   ; (name value ..) -> transform each value
   (defoliate form)
    (? (! (has-pipe? form)) form                                             ; NO pipeline anywhere -> byte-identical (every legacy form)
       (! (&& (two? form) (id? (cap form) ':) (! (atom? (cup form))))) (dlower (dsimp (dforest form)))
       (link ': (defol-bs (cup form))))
   (clook2 nm al) (? (atom? al) -1 (id? nm (caap al)) (caup (cap al)) (clook2 nm (cup al)))   ; (name arity) alist -> arity (-1 absent)
   (groupok? cands ps e)                                                                      ; is e in the fragment over cands (a (name arity) list)?
    (? (member? e ps) 1  (whole? e) 1
       (two? e) (: op (cap e) ar (clook2 op cands)
          (? (< -1 ar)                                  (&& (= (tally (cup e)) ar) (foldl (\ a x (&& a (groupok? cands ps x))) 1 (cup e)))   ; call to a group fn: arity ok, args ok
             (member? op '(+ - * // % & | ^ < <= > >= =)) (&& (= 3 (tally e)) (groupok? cands ps (caup e)) (groupok? cands ps (caup (cup e))))
             (id? op '?)                                  (&& (= 4 (tally e)) (groupok? cands ps (caup e)) (groupok? cands ps (caup (cup e))) (groupok? cands ps (caup (cup (cup e)))))
             (id? op 'tally)                              (&& (= 2 (tally e)) (member? (caup e) ps))                                          ; (tally STR): STR a param (string lane)
             (id? op 'peep)                               (&& (= 4 (tally e)) (member? (caup e) ps) (groupok? cands ps (caup (cup e))) (whole? (caup (cup (cup e)))))   ; (peep STR i d): STR param, i ok, d const
             0))
       0)
   (grpok-1 fns c cands) (: p (afind (\ q (id? (cap (cap q)) (cap c))) fns) (groupok? cands (cup (cap p)) (cup p)))   ; candidate c's body ok over cands?
   (grpfix fns cands) (: keep (afilter (\ c (grpok-1 fns c cands)) cands)                     ; drop fns that fail; iterate to a fixpoint
                         (? (= (tally keep) (tally cands)) keep (grpfix fns keep)))
   (rewrite-bindings bl gnames gdefs) (? (atom? (cup bl)) bl                                  ; the trailing body form -> keep
      (: nf (cap bl) val (caup bl)  hit (&& (two? nf) (member? (cap nf) gnames))
         (link (? hit (cap nf) nf)                                                            ; drop the (name p..) define-sugar -> a PLAIN binding
               (link (? hit (jitgroup gdefs (cap nf)) val)                                    ; ... name <native>, so it isn't re-wrapped in (\ p ..)
                     (rewrite-bindings (cuup bl) gnames gdefs)))))
   (autogroup form0)
    (? (! (two? form0)) form0
       (! (id? (cap form0) ':)) form0
       (atom? (cup form0)) form0
       (: form (lift (delet (defoliate (autospec (debool (fold-consts form0))))))   ; lower &&/||/min/max/abs to ?, specialize interp-over-static-data, deforest pipelines -> loops, inline value-lets in fn bodies, THEN lambda-lift named-let bodies -> flat group fns
          parsed (anat-defs (cup form)) pairs (cap parsed)
          fns (afilter (\ p (: nf (cap p) (&& (two? nf) (< 1 (tally nf)) (< (tally nf) 6) (all name? (cup nf)) (distinctp (cup nf))))) pairs)   ; (name p..), 1..4 distinct sym params
          (? (! (two? fns)) form0                                                            ; no candidate functions -> original
             (: armap (map (\ p (L (cap (cap p)) (- (tally (cap p)) 1))) fns)                 ; (name arity) candidates
                grp (grpfix fns armap)                                                        ; the closed glazeable subset
                (? (atom? grp) form0                                                          ; nothing survives the fixpoint -> original (un-lifted)
                   (: gnames (map cap grp)
                      gdefs (afilter (\ p (member? (cap (cap p)) gnames)) fns)                ; the (nameform . body) defs of the group
                      (link ': (rewrite-bindings (cup form) gnames gdefs))))))))              ; each binding of the LIFTED form -> its native
   (autonat form)
    (? (! (two? form)) form
       (! (id? (cap form) ':)) form
       (atom? (cup form)) form
       (: parsed (anat-defs (cup form)) pairs (cap parsed)
          (? (! (< 1 (tally pairs))) form                        ; need a recurrence + >=1 loop
             (: recp (afind anat-rec? pairs)
                (? (! (two? recp)) form                          ; no float recurrence found
                   (: recnm (cap (cap recp)) recps (cup (cap recp)) recbody (cup recp)
                      cond (opd recbody 0) then (opd recbody 1)
                      itcmp (opd cond 0) c2 (opd cond 1)
                      (? (! (&& (two? itcmp) (id? (cap itcmp) '<) (two? c2))) form     ; cond = (&& (< it LIM) (cmp T B))
                         (: lim (opd itcmp 1) cmpop (cap c2) testexpr (opd c2 0) bound (opd c2 1)
                            cl (classify recps (cup then)) fvars (cap cl) updates (caup cl) invs (nthl cl 2)
                            looppairs (afilter (\ q (! (id? q recp))) pairs)             ; the loop defs
                            callees (map anat-callee looppairs)
                            outerp (afind (\ q (! (member? (cap (cap q)) callees))) looppairs)   ; the loop no loop calls
                            (? (! (two? outerp)) form
                               (: chain (loopchain (cap (cap outerp)) pairs recnm)       ; outermost -> recurrence
                                  D (tally chain) M (tally invs) N (tally fvars)
                                  (? (! (&& (two? chain) (member? cmpop '(< <= > >=)) (< 0 N) (< (+ M N) 7) (< D 7))) form
                                     (: cnames (map cap chain) dims (map caup chain)
                                        margs (nthl (last chain) 2)
                                        invd (map (\ iv (nthl margs (posof iv recps 0))) invs)
                                        glam (L '\ '_ form)       ; faithful interp nest (deopt fallback / =-show)
                                        ng (jitfgridn glam cnames dims invs invd fvars updates testexpr cmpop bound lim)
                                        (? (lit? ng) (link ': (anat-rebind (cup form) (cap (cap outerp)) ng)) form)))))))))))))
   ; COMPILE CACHE: each source \-expr compiles ONCE (no re-mmap on repeated ev).
   ; Keyed by source -- structurally-equal closures share the same native (sound:
   ; they are =). The transparent form of a hot-trigger: an execution-count trigger
   ; would need a counting wrapper, but a wrapper is not =/show its source; so the
   ; trigger is "compile on first request, cached after". Loops stay eager (their
   ; one application is internally hot). ⚠ pins natives (+ W^X arenas) for the run.
   cache (tablet 0)
   (memo e mk) (: g (peep cache e 0) (? g g (: h (mk e) _ (pin cache e h) h)))
   ; auto-ev: a WHOLE-FORM lambda -> native (cached), else the base interpreter. (The
   ; creation hook -- rewriting embedded lambdas via a jit-walk -- was tried and pulled:
   ; it's pre-macroexpansion so it can disturb a macro's data args, AND the
   ; compile cache makes structurally-equal closures id?-IDENTICAL, breaking love's
   ; equal-but-distinct closure semantics (!(id? (\ x E) (\ x E))). A safe creation hook
   ; needs the POST-macro opfix seam + a CODE cache (distinct cells per instance). Future.)
   (auto-ev e) (? (qual e)  (memo e njit)
                  (qualn e) (memo e jitn)
                  (qualc e) (memo e (\ l (jitn (flatc l))))
                  (qualfr e) (memo e jitfr)                       ; float-RESULT leaf -> heap-boxed gem (sound: param floated at first use)
                  (: li (loopinfo e)
                     (? li (memo e (\ l (njit-loop l (cap li) (caup li) (caup (cup li)) (caup (cup (cup li))))))
                        (: ln (loopinfo-n e)
                           (? ln (memo e (\ l (njit-loop-n l (cap ln) (caup ln) (caup (cup ln)) (caup (cup (cup ln))) (caup (cup (cup (cup ln)))))))
                              (base-ev (autogroup (autonat e))))))))    ; fall-through: glaze a float-grid nest / a mutually-recursive arith group if either fits, else interpret
   ev auto-ev                                                  ; rebind the global: ev is now auto-native
 _ (assert
    ((\ x (+ (* x 2) 3)) = (ev '(\ x (+ (* x 2) 3))))          ; leaf: native, =-identical
    (23 = ((ev '(\ x (+ (* x 2) 3))) 10))
    (((base-ev '(\ x (+ (* x 9) 4))) 11) = ((ev '(\ x (+ (* x 9) 4))) 11))      ; native leaf == interp (catches njit codegen regressions)
    (: ny (ev '(\ y (+ y 1))) (&& (6 = (ny 5)) ((\ y (+ y 1)) = ny)))   ; arity-1 leaf, non-x param, auto-natived
    (3 = ((ev '(\ x (cap x))) '(3 4)))                         ; non-qualifying -> interpreter
    ((base-ev '(+ 1 2 3)) = (ev '(+ 1 2 3)))                   ; non-lambda forms unaffected (ev == base-ev; curried + nets 27, not 6)
    (9000000000000000000 = ((ev '(\ x (* x x))) 3000000000))   ; overflow deopts -> bignum
    (: ab (ev '(\ x (? (< x 0) (- 0 x) x))) (&& (7 = (ab -7)) (7 = (ab 7))))   ; conditional leaf auto-natived
    ; LOOP auto-detected -> native counted loop, =-identical + correct
    (: L1 '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (* i 7))) a)) 0 0))
       f  (ev L1)
       (&& (= f (ev L1)) (3496500 = (f 1000)) (two? (loopinfo L1))))
    ; LOOP with a conditional body (sum i for i<50, capped) auto-detected
    (: L2 '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (+ a (? (< i 50) i 0))) a)) 0 0))
       h  (ev L2)  c ((: (go i a) (? (< i 1000) (go (+ i 1) (+ a (? (< i 50) i 0))) a)) 0 0)
       (&& (two? (loopinfo L2)) (= c (h 1000))))
    ; GENERALIZED loop -- a PRODUCT fold (op=*, init 1): n! = prod_{i<n}(i+1)
    (: P '(\ n ((: (go i a) (? (< i n) (go (+ i 1) (* a (+ i 1))) a)) 0 1))
       f (ev P)  fi ((: (go i a) (? (< i 10) (go (+ i 1) (* a (+ i 1))) a)) 0 1)
       (&& (two? (loopinfo P)) (3628800 = (f 10)) (= fi (f 10)) (= (ev P) (ev P))
           (15511210043330985984000000 = (f 25))))             ; overflow -> deopt -> bignum (transparent)
    ; GENERALIZED loop -- a <= comparison: sum_{i<=n} i
    (: Q '(\ n ((: (go i a) (? (<= i n) (go (+ i 1) (+ a i)) a)) 0 0))
       g (ev Q)  (&& (two? (loopinfo Q)) (55 = (g 10))))        ; 0+1+..+10 = 55
    ; N-VARIABLE loop auto-detected: iterative fib (i,a,b -- updates b and a+b)
    (: F '(\ n ((: (go i a b) (? (< i n) (go (+ i 1) b (+ a b)) a)) 0 0 1))
       nf (ev F)  (&& (two? (loopinfo-n F)) (832040 = (nf 30)) (= (ev F) (ev F))   ; fib(30)=832040, native+transparent
                      (4660046610375530309 = (nf 91))))                            ; fib(91) -> deopt -> bignum
    (id? (ev L1) (ev L1))                                       ; CACHE: same source -> same native (compiled once)
    (id? (ev '(\ x (+ x 1))) (ev '(\ x (+ x 1))))
    (: ad (ev '(\ x y (+ (* x x) y))) (&& (13 = (ad 3 4)) (13 = ((ad 3) 4)) ((\ x y (+ (* x x) y)) = ad)))  ; 2-arg leaf auto-natived
    (: a3 (ev '(\ x y z (+ (+ x y) (* z 3))))                                                  ; 3-arg leaf auto-natived, currying at any split
       (&& (13 = (a3 1 3 3)) (13 = ((a3 1 3) 3)) (13 = ((a3 1) 3 3)) ((\ x y z (+ (+ x y) (* z 3))) = a3)))
    ; captured-closure constructor auto-natived: captures transparent (= interp)
    (: adder (ev '(\ n (\ x (+ x n))))  a5 (adder 5)
       (&& (15 = (a5 10)) ('(6 7 8) = (map a5 '(1 2 3))) (= a5 ((\ n (\ x (+ x n))) 5))))
    ; FLOAT-RESULT leaf auto-natived -> a heap-boxed gem, == interp, transparent
    (: fr (ev '(\ x (+ (* x 1.5) 2.0)))
       (&& (gem? (fr 4)) (8.0 = (fr 4)) (= ((base-ev '(\ x (+ (* x 1.5) 2.0))) 7) (fr 7))
           ((\ x (+ (* x 1.5) 2.0)) = fr)))                     ; =-identical to source
    (qualfr '(\ x (/ (+ x 1.0) 2.0)))                          ; float-division leaf: param floated at first use -> SOUND
    !(qualfr '(\ x (+ (* x 3) 1.5)))                           ; param inside an INT subexpr (* x 3) -> late promotion diverges -> rejected
    !(qualfr '(\ x (/ x 2)))                                   ; int/int division: result type value-dependent -> rejected
    !(qualfr '(\ x (+ (* x 2) 3)))                             ; an all-INTEGER leaf is no float result (qual handles it)
    (: ii (ev '(\ x (+ (* x 2) 3))) (&& (7 = (ii 2)) !(gem? (ii 2)))))   ; ... and stays a fixnum (qualfr did not steal it)
 _ (assert    ; D-DIMENSIONAL float-recurrence GRIDS auto-glazed from SOURCE -> native whole-grid kernel, bit-exact (== interp)
    ; D=2 -- the mandelbrot 64x64 grid (M=2 invariants, N=2 fvars), the canonical instance -> checksum 87130
    (: g2 '(: (mand cx cy zx zy it)
               (? (&& (< it 100) (<= (+ (* zx zx) (* zy zy)) 4.0))
                  (mand cx cy (+ (- (* zx zx) (* zy zy)) cx) (+ (* (* 2.0 zx) zy) cy) (+ it 1)) it)
              (col px py acc) (? (< py 64) (col px (+ py 1) (+ acc (mand (+ -2.0 (* px 0.046875)) (+ -1.5 (* py 0.046875)) 0.0 0.0 0))) acc)
              (grid px acc) (? (< px 64) (grid (+ px 1) (+ acc (col px 0 0))) acc)
            (grid 0 0))
       (&& !(id? (autonat g2) g2) (= 87130 (ev g2)) (= (base-ev g2) (ev g2))))      ; autonat rewrote it -> native == interp
    ; D=1 -- a single row of escape counts (cy a constant 0.0) -> native == interp
    (: g1 '(: (mand cx cy zx zy it) (? (&& (< it 100) (<= (+ (* zx zx) (* zy zy)) 4.0)) (mand cx cy (+ (- (* zx zx) (* zy zy)) cx) (+ (* (* 2.0 zx) zy) cy) (+ it 1)) it)
              (row px acc) (? (< px 64) (row (+ px 1) (+ acc (mand (- (* px 0.046875) 2.0) 0.0 0.0 0.0 0))) acc)
            (row 0 0))
       (&& !(id? (autonat g1) g1) (= (base-ev g1) (ev g1))))
    ; D=3 -- an 8x8x8 nest, M=3 invariants (cx cy cz), cz=pz*0.01 shifting zy -> native == interp (exercises r12 push/pop)
    (: g3 '(: (mand cx cy cz zx zy it) (? (&& (< it 50) (<= (+ (* zx zx) (* zy zy)) 4.0)) (mand cx cy cz (+ (- (* zx zx) (* zy zy)) cx) (+ (+ (* (* 2.0 zx) zy) cy) cz) (+ it 1)) it)
              (lz px py pz acc) (? (< pz 8) (lz px py (+ pz 1) (+ acc (mand (- (* px 0.046875) 2.0) (- (* py 0.046875) 1.5) (* pz 0.01) 0.0 0.0 0))) acc)
              (ly px py acc) (? (< py 8) (ly px (+ py 1) (+ acc (lz px py 0 0))) acc)
              (lx px acc) (? (< px 8) (lx (+ px 1) (+ acc (ly px 0 0))) acc)
            (lx 0 0))
       (&& !(id? (autonat g3) g3) (= (base-ev g3) (ev g3))))
    ; RECURSIVE ARITHMETIC: naive fib auto-glazed to a native call tree -- native == interp, and an
    ; int64-overflowing recursion (pow2) deopts to the interp fallback -> the exact bignum (sound)
    (: rf '(: (fib n) (? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))) (fib 25))
       (&& !(id? (autogroup rf) rf) (= 75025 (ev rf)) (= (base-ev rf) (ev rf))))
    (: rp '(: (p2 n) (? (< n 1) 1 (* 2 (p2 (- n 1)))) (p2 70))
       (= (base-ev rp) (ev rp)))                               ; 2^70 overflows int64 in H -> OVF deopt -> bignum
    ; MULTI-ARG recursion: tak (3 args, nested self-calls -- args survive on the machine stack) == interp
    (: rt '(: (tak x y z) (? (< y x) (tak (tak (- x 1) y z) (tak (- y 1) z x) (tak (- z 1) x y)) z) (tak 18 12 6))
       (&& !(id? (autogroup rt) rt) (= 7 (ev rt)) (= (base-ev rt) (ev rt))))
    ; MUTUAL recursion: evn/odn cross-call -- BOTH bindings glazed, sibling calls native inside one
    ; buffer; the `:` body drives both. The systematic win over the old per-fn autorec: a closed call
    ; GRAPH, not just self-recursion.
    (: rm '(: (evn n) (? (= n 0) 1 (odn (- n 1))) (odn n) (? (= n 0) 0 (evn (- n 1))) (L (evn 100) (odn 100) (evn 7)))
       (&& !(id? (autogroup rm) rm) ('(1 0 0) = (ev rm)) (= (base-ev rm) (ev rm))))
    ; LAMBDA-LIFTING: primes' prime?/count are each a named-let LOOP -- lifted to flat group fns
    ; (prime?_go count_go), so the WHOLE trial-division graph glazes (prime? count prime?_go count_go,
    ; sibling calls native, the % trial division in the H). count(2 30) = 10 primes below 30.
    (: rpr '(: (prime? n) ((: (go d) (? (< n (* d d)) 1 (? (= 0 (% n d)) 0 (go (+ d 1))))) 2)
               (count lo hi) ((: (go n c) (? (< n hi) (go (+ n 1) (? (prime? n) (+ c 1) c)) c)) lo 0)
               (count 2 30))
       (&& !(id? (autogroup rpr) rpr) (10 = (ev rpr)) (= (base-ev rpr) (ev rpr))))
    ; STRING LANE: a recursive (peep s i) byte processor glazes from SOURCE -- s a STRING param (passed
    ; raw, no sar; the native reads the plain ai_str's bytes at s+16), (tally s) -> the len at s+8.
    (: rsl '(: data (string (L 72 105 90 33 65))
               (bsum s i) (? (< i 0) 0 (+ (peep s i 0) (bsum s (- i 1))))
               (bsum data 4))
       (&& !(id? (autogroup rsl) rsl) (365 = (ev rsl)) (= (base-ev rsl) (ev rsl))))
    ; FULL STRING LANE (strscan): fold-consts inlines hmod, norm-let normalizes (: n (tally s) (go ..)
    ; (go 0 0)) into a named-let, lift lifts go, interprocedural inference types s (it flows strhash ->
    ; strhash_go's peep), and the native rolling hash == interp. This is the strscan bench, glazed from source.
    (: rss '(: hmod 1000000007
               (strhash s) (: n (tally s) (go i h) (? (< i n) (go (+ i 1) (% (+ (* h 31) (peep s i 0)) hmod)) h) (go 0 0))
               data (string (L 72 105 90 33 65))
               (strhash data))
       (&& !(id? (autogroup rss) rss) (69709145 = (ev rss)) (= (base-ev rss) (ev rss))))
    ; DEFORESTATION: a map/filter/fold pipeline over (jot N) -- defoliate FUSES the producers into the
    ; foldl step (one pass, no intermediate lists) and LOWERS foldl-over-jot to the named-let LOOP `lift`
    ; already glazes, so the whole combinator pipeline compiles to a native counted loop. == interp.
    (: dq '(: (sumsq n) (foldl (+) 0 (map (\ x (* x x)) (jot n))) (sumsq 100))
       (&& !(id? (autogroup dq) dq) (328350 = (ev dq)) (= (base-ev dq) (ev dq))))      ; sum i^2 for i<100
    ; map after FILTER: the filter guards the fused step; map-after-map composes the element subs
    (: dpf '(: (f n) (foldl (+) 0 (map (+ 1) (filter (\ x (> x 2)) (jot n)))) (f 10))
       (&& !(id? (autogroup dpf) dpf) (49 = (ev dpf)) (= (base-ev dpf) (ev dpf))))      ; keep>2, +1, sum = 49
    (: dmm '(: (sm n) (foldl (+) 0 (map (* 2) (map (+ 1) (jot n)))) (sm 5))
       (&& !(id? (autogroup dmm) dmm) (30 = (ev dmm)) (= (base-ev dmm) (ev dmm))))      ; (*2).(+1) over 0..4 = 30
    ; a BARE foldl over jot (no producers) lowers straight to the loop
    (: dj '(: (s n) (foldl (+) 0 (jot n)) (s 100))
       (&& !(id? (autogroup dj) dj) (4950 = (ev dj)) (= (base-ev dj) (ev dj))))         ; sum 0..99 = 4950
    ; SOUNDNESS: a foldl over (iota N) is the ARRAY -- foldl/map (chain ops) don't iterate it, so it is
    ; degenerate (=z); fusion preserves that (both sides z) and it is NOT lowered (djot? only) -> == interp
    (: di '(: (h n) (foldl (+) 0 (map (\ x (* x x)) (iota n))) (h 100))
       (= (base-ev di) (ev di)))                                                         ; iota: degenerate to 0, transparent
    ; a foldl over a list PARAM can't lower (no jot) -> interpreted, value still correct (defoliate no-op)
    (: dl '(: (g l) (foldl (+) 0 l) (g (jot 5)))
       (= (base-ev dl) (ev dl)))                                                         ; 0+1+2+3+4 = 10
    ; foldr: a DOWN-counting reduction -- the fused down-loop lambda-lifts to a group fn and natives (the
    ; operator consumer flattens to a first-order step). == interp, value exact.
    (: dr '(: (f n) (foldr (+) 0 (map (\ x (* x x)) (jot n))) (f 100))
       (&& !(id? (autogroup dr) dr) (328350 = (ev dr)) (= (base-ev dr) (ev dr))))        ; foldr +.map sq, sum i^2 for i<100
    (: drf '(: (f n) (foldr (+) 0 (filter (\ x (= 1 (% x 2))) (jot n))) (f 20))
       (&& !(id? (autogroup drf) drf) (100 = (ev drf)) (= (base-ev drf) (ev drf))))      ; foldr +.filter odd, 1+3+..+19 = 100
    ; all/any: a short-circuit predicate -> an early-exit loop returning the truth BITS 0/1 (== interp, which
    ; now returns bits too). a clean run-off and an early short-circuit both glaze, with or without a producer.
    (: dall '(: (f n) (all (\ x (< x n)) (jot n)) (f 10))
       (&& !(id? (autogroup dall) dall) (1 = (ev dall)) (= (base-ev dall) (ev dall))))   ; every i<n -> run off -> 1
    (: dalf '(: (f n) (all (\ x (< x 5)) (jot n)) (f 10))
       (&& !(id? (autogroup dalf) dalf) (0 = (ev dalf)) (= (base-ev dalf) (ev dalf))))   ; i=5 fails -> early 0
    (: dany '(: (f n) (any (\ x (> x 7)) (jot n)) (f 10))
       (&& !(id? (autogroup dany) dany) (1 = (ev dany)) (= (base-ev dany) (ev dany))))   ; i=8 hits -> early 1
    (: danf '(: (f n) (any (\ x (> x 100)) (jot n)) (f 10))
       (&& !(id? (autogroup danf) danf) (0 = (ev danf)) (= (base-ev danf) (ev danf))))   ; none -> run off -> 0
    (: dap '(: (f n) (all (\ x (> x 0)) (map (+ 1) (jot n))) (f 10))
       (&& !(id? (autogroup dap) dap) (1 = (ev dap)) (= (base-ev dap) (ev dap))))        ; all (+1 i)>0 -> producer fuses into the guard
    ; a fn that calls OUT of the fragment (into `link`) drops the whole group -> form unchanged, interpreted
    (: ro '(: (build n) (? (< n 1) () (link n (build (- n 1)))) (build 3))
       (&& (id? (autogroup ro) ro) ('(3 2 1) = (ev ro))))   ; left interpreted; base () -> a clean ()-terminated (3 2 1)
    ; SPECIALIZATION (autospec/mix): a recursive interpreter ev1 applied to a STATIC program P (a const-
    ; bound quoted AST) + a DYNAMIC loop var specializes -- the dispatch + AST navigation fold away to P's
    ; straight-line arithmetic (the Horner residual), so the loop natives. == an interpreted ev1 loop (the
    ; 1st Futamura projection composed with the glaze; the dispatch overhead interp-spec.l clocks at ~6.5x).
    (: sp '(: (ev1 nd x) (? (id? (cap nd) 'lit) (caup nd)  (id? (cap nd) 'var) x
                            (id? (cap nd) 'add) (+ (ev1 (caup nd) x) (ev1 (cap (cuup nd)) x))
                            (id? (cap nd) 'mul) (* (ev1 (caup nd) x) (ev1 (cap (cuup nd)) x))  0)
               P '(add (mul (add (mul (add (mul (lit 2) (var)) (lit 3)) (var)) (lit 5)) (var)) (lit 7))
               (run n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (ev1 P i))) a)) 0 0)  (run 1000))
       (&& !(id? (autogroup sp) sp) (500001505000 = (ev sp)) (= (base-ev sp) (ev sp))))   ; sum P(i) i<1000, native == interp
    ; a DIFFERENT static program (a mul of two sub-exprs) specializes to its OWN residual -- == interp (soundness breadth)
    (: sp2 '(: (ev1 nd x) (? (id? (cap nd) 'lit) (caup nd)  (id? (cap nd) 'var) x
                             (id? (cap nd) 'add) (+ (ev1 (caup nd) x) (ev1 (cap (cuup nd)) x))
                             (id? (cap nd) 'mul) (* (ev1 (caup nd) x) (ev1 (cap (cuup nd)) x))  0)
                Q '(mul (add (var) (lit 1)) (add (var) (lit 2)))
                (run n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (ev1 Q i))) a)) 0 0)  (run 50))
       (&& !(id? (autogroup sp2) sp2) (= (base-ev sp2) (ev sp2))))   ; sum (i+1)(i+2) i<50, native == interp
    ; autospec is a NO-OP without BOTH a defined fn and a static-data binding -> a plain fib group is byte-unchanged
    (: nf '(: (fib n) (? (< n 2) n (+ (fib (- n 1)) (fib (- n 2)))) (fib 10))
       (id? (autospec nf) nf))
    ; LOCAL LET (delet): a fn body that NAMES intermediates -- a pure value-let -- inlines to one fragment
    ; expression, so the fn joins the group. == interp, value exact.
    (: lb '(: (f x) (: q (* x x) (+ q q)) (f 5))
       (&& !(id? (autogroup lb) lb) (50 = (ev lb)) (= (base-ev lb) (ev lb))))                ; q=x*x, 2q = 50
    ; a CHAIN of bindings, the first used TWICE -- but call-free (dup-cheap), so it inlines freely
    (: lc '(: (f x) (: a (+ x 1) b (* a 2) (+ a b)) (f 5))
       (&& !(id? (autogroup lc) lc) (18 = (ev lc)) (= (base-ev lc) (ev lc))))                ; a=6,b=12 -> 18
    ; a binding holding a recursive sibling CALL, used ONCE -> inlines; the fn glazes and calls native g
    (: ls '(: (g n) (? (< n 1) 0 (+ n (g (- n 1)))) (f n) (: h (g n) (* h 2)) (f 5))
       (&& !(id? (autogroup ls) ls) (30 = (ev ls)) (= (base-ev ls) (ev ls))))                ; g(5)=15, h*2 = 30
    ; a value-let WRAPPING a named-let loop: delet inlines k into the loop, lift then glazes it
    (: lw '(: (f n) (: k (* n 1) ((: (go i a) (? (< i k) (go (+ i 1) (+ a i)) a)) 0 0)) (f 10))
       (&& !(id? (autogroup lw) lw) (45 = (ev lw)) (= (base-ev lw) (ev lw))))                ; sum 0..9 = 45
    ; BAIL: a binding holding a CALL used TWICE would duplicate the recursion -> NOT inlined -> f interprets
    ; (sound, value exact; the sibling g still glazes, so the form is rewritten but f stays interpreted)
    (: lbail '(: (g n) (? (< n 1) 1 (* n (g (- n 1)))) (f n) (: a (g n) (+ a a)) (f 5))
       (= (base-ev lbail) (ev lbail)))                                                        ; g(5)=120, a+a = 240, interpreted
    ; BOOLEANS & CLAMPS (debool): &&/||/min/max/abs lower to the ?-fragment -> the fn glazes. == interp.
    (: band '(: (f x n) (? (&& (< x n) (> x 0)) 1 0) (f 5 9))
       (&& !(id? (autogroup band) band) (1 = (ev band)) (= (base-ev band) (ev band))))        ; 5<9 && 5>0 -> 1
    (: bor '(: (f x) (? (|| (< x 0) (> x 9)) 1 0) (f 5))
       (&& !(id? (autogroup bor) bor) (0 = (ev bor)) (= (base-ev bor) (ev bor))))             ; neither -> 0
    (: babs '(: (f x) (+ (abs x) 1) (f -5))
       (&& !(id? (autogroup babs) babs) (6 = (ev babs)) (= (base-ev babs) (ev babs))))        ; |-5|+1 -> 6
    ; abs inside a hot loop: |i-50| summed for i<100 -> the running clamp natives
    (: babl '(: (f n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (abs (- i 50)))) a)) 0 0) (f 100))
       (&& !(id? (autogroup babl) babl) (2500 = (ev babl)) (= (base-ev babl) (ev babl))))      ; sum|i-50| = 2*(1+..+50) = 2550-50 = 2500
    ; nested compound: && of a cmp and an ||, guarding an abs -- all collapse to ?
    (: bnest '(: (f x) (? (&& (> x 0) (|| (< x 5) (> x 10))) (abs x) 0) (f 3))
       (&& !(id? (autogroup bnest) bnest) (3 = (ev bnest)) (= (base-ev bnest) (ev bnest))))    ; 3>0 && 3<5 -> abs 3 = 3
    ; BAIL: || whose first operand is a recursive CALL would duplicate it -> left un-lowered -> f interprets (sound)
    (: bbail '(: (g n) (? (< n 1) 0 (+ n (g (- n 1)))) (f n) (? (|| (g n) (< n 0)) 1 0) (f 5))
       (= (base-ev bbail) (ev bbail)))                                                        ; (|| g(5)=15 ..) truthy -> 1, interpreted (g still glazes)
    ; || AND abs nested in a loop accumulator -- the deep ?-nesting the perf demo exercises
    (: bdeep '(: (f n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (? (|| (< i 100) (> i 900)) (abs (- i 500)) 0))) a)) 0 0) (f 1000))
       (&& !(id? (autogroup bdeep) bdeep) (= (base-ev bdeep) (ev bdeep))))                     ; native == interp on the nested ||/abs loop
    ; a debool'd HELPER called by a loop SIBLING -- clamp (||/abs) glazes as a group fn, run_go calls it native
    (: bclamp '(: (clamp i) (? (|| (< i 100) (> i 900)) (abs (- i 500)) 0)
                  (run n) ((: (go i a) (? (< i n) (go (+ i 1) (+ a (clamp i))) a)) 0 0) (run 1000))
       (&& !(id? (autogroup bclamp) bclamp) (= (base-ev bclamp) (ev bclamp)))))                ; native == interp; clamp a glazed sibling
 _ (say err "ai/glaze/auto: ev auto-natives qualifying closures + counted loops + D-dim float grids + mutually-recursive arith groups (transparent)\n"))
