; auto -- the transparent auto-hook: rebind `ev` so a QUALIFYING closure compiles to
; NATIVE automatically. No user-facing verb -- you call `ev` (or eval a closure) as
; always; qualifying ones are just faster, and =/show-IDENTICAL to their source.
; Everything else falls through to the base interpreter unchanged.
;
; Shapes that qualify (the emitter's grammar; E := var | int | (OP E E) | (? E E E),
; OP in + - * // % & | ^ < <= > >= =):
;   LEAF1 (\ x E)            -- E over x
;   LEAFN (\ p0 .. p_{n-1} E) -- E over the params, any arity n>=2 (currying via lvm_cur; natn)
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
   (qual lam) (&& (two? lam) (= (cap lam) '\) (two? (cup lam)) (symp (caup lam))                ; (\ v E), v any symbol
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
                      (all symp ps) (< 1 (tally ps)) (distinctp ps)                     ; >=2 distinct symbol params
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
       ok (&& (two? lam) (= (cap lam) '\) (symp (caup lam))                  ; (\ N ..)
              (two? (cup (cup lam))) !(two? (cup (cup (cup lam))))           ; one body
              (two? M) (= z1 0) !(two? (cup (cup (cup M))))                  ; (S 0 a0)
              (two? S) (= (cap S) ':) (symp GO) (symp I) (symp A) !(= I A)   ; (: (go i a) IF)
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
       ok (&& (two? lam) (= (cap lam) '\) (symp (caup lam)) (two? (cup (cup lam))) !(two? (cup (cup (cup lam))))
              (two? BODY) (two? S) (= (cap S) ':) (two? (cup S)) !(two? (cup (cup (cup S))))   ; (: G IF)
              (two? G) (symp GO) (two? vars) (all symp vars) (distinctp vars) !(member? GO vars)
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
                  (&& (two? lam) (= (cap lam) '\) (two? (cup lam)) (symp p)
                      (two? (cup (cup lam))) !(two? (cup (cup (cup lam))))               ; (\ p INNER), one body
                      (two? inner) (= (cap inner) '\) (two? (cup inner)) (symp (caup inner)) !(= p (caup inner))
                      (two? (cup (cup inner))) !(two? (cup (cup (cup inner))))            ; INNER = (\ q E), q != p
                      (exprn `(p (caup inner)) (caup (cup inner)))))
   (flatc lam) (: inner (caup (cup lam)) `('\ (caup lam) (caup inner) (caup (cup inner))))  ; (\ p (\ q E)) -> (\ p q E)
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
                             (&& (two? gnf) (symp (cap gnf)) (< 1 (tally gnf)) (all symp (cup gnf)) (distinctp (cup gnf))
                                 (two? (cup (cup nl))) !(two? (cup (cup (cup nl))))               ; (: (g q..) GBODY), body-less (one binding)
                                 (= (tally (cup e)) (tally (cup gnf))))))))                       ; inits arity == g's arity
   (lift-pair p)                                                                                  ; (nameform . body) -> (rewritten-pair newdefs)
    (: nf (cap p) pbody (cup p)
       (? (! (&& (two? nf) (symp (cap nf)) (< 1 (tally nf)) (named-let? pbody))) (L p ())
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
       (: form (lift form0)                                                                  ; lambda-lift named-let bodies first (primes' loops -> flat group fns)
          parsed (anat-defs (cup form)) pairs (cap parsed)
          fns (afilter (\ p (: nf (cap p) (&& (two? nf) (< 1 (tally nf)) (< (tally nf) 6) (all symp (cup nf)) (distinctp (cup nf))))) pairs)   ; (name p..), 1..4 distinct sym params
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
       (&& (15 = (a5 10)) ('(6 7 8) = (map a5 '(1 2 3))) (= a5 ((\ n (\ x (+ x n))) 5)))))
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
    ; a fn that calls OUT of the fragment (into `link`) drops the whole group -> form unchanged, interpreted
    (: ro '(: (build n) (? (< n 1) () (link n (build (- n 1)))) (build 3))
       (&& (id? (autogroup ro) ro) ('(3 2 1) = (ev ro)))))   ; left interpreted; base () -> a clean ()-terminated (3 2 1)
 _ (say err "ai/glaze/auto: ev auto-natives qualifying closures + counted loops + D-dim float grids + mutually-recursive arith groups (transparent)\n"))
