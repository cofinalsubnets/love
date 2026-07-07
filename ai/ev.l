; iop/apx: unforgeable tag markers (uninterned) shared by feel -- which emits (iop op . args)
; and (apx nary head . args) nodes -- and ana, which dispatches on them. Top-level globals,
; NOT ev-block locals, so feel's per-global aps and ana resolve them by name. That keeps
; them out of ev's captured frame (and off every ap's import list: a ap closing over
; a sibling that captured iop/apx would otherwise drag both in dead -- see .feels).
(: iop (nom 'iop)
   apx (nom 'apx))

; gone: avb's not-in-book sentinel (the `(peep book x gone)` default). A TOP-LEVEL GLOBAL
; for the SAME reason as iop/apx -- it is folded into avb as a kim constant at compile time
; (it lives in the book when avb compiles), then mopped. As a :- block LOCAL it failed
; capture in the 2-sat egg (ev1 mis-resolved the ref -> ev2's avb did `lvm_index gone`,
; missing the book at runtime -> () degrade: a global genuinely bound to () then mis-analyzed
; as a free import). A global resolves identically in every bootstrap generation.
(: gone (nom 'gone))

; gv: the LAYERED global read -- (books ()) is the live chain of books (the abyss;
; one link today, orth), walked head-first with `gone` as the per-layer miss
; sentinel (a stored () SHADOWS, never falls through), answering d on total miss.
; Every book read in this file routes here, so a later layer can shadow orth
; without touching the compiler again. The C twin is ai.c's bookget; keep in step.
(: (gv k d) ((: (go c) (? (atom? c) d
                          (: v (peep (cap c) k gone)
                             (? (id? v gone) (go (cup c)) v))))
             (books ())))

; feels: value->ap memo for global fns, built once by scanning every global. A ap
; folds an application to a value when its args are constant (pure fns only), else emits an
; (iop op . args) node iap inlines (any nif of matching arity), else leaves it. A nif is found
; by text shape (lvm_ret0 terminator); fold eligibility from the curated `names`. It lives
; as a global -- feel's fold reaches it by name -- so this ~126-entry table is NOT baked into
; ev's value; `.ev` then prints as just the ana+feel logic, and the table prints under `.feels`.
;
; `names`/`pureset` are LIFTED to the top level (out of feels' body) so feel's INLINER (cprop, below)
; shares the same effect-free set its purity gates read -- a broad table (arith, comparisons, the c[ad]r
; family, type predicates, the transcendentals), not just the dyadic fold ops. pureset is keyed by VALUE.
(: pureset (: names (cat `('+ '- '* '/ '% '& '| '< '<= '= '>= '>)
          '(// << >> ^
            id? gcd modpow abs
            link cap cup caap caup cuap cuup
            dig lidx assoc member? last rev cat
            charm? nom? two? book? lit? string? nil? gem? twin? atom?
            snip string
            re im conj arg gem twin
            sine cosine log power))
   (foldl (\ t s (: v (gv s ()) (? v (pin t v 1) t))) (tablet 0) names)))
(: feels (:
   lvm_cur  (peek 0 (+))
   lvm_ret0 (peek 1 cap)
   (bake v) (? (charm? v) v (list '\ v))           ; value -> source: fixnum bare else quote
   ; (op . arity) iff v is a nif. `id?` (identity) not `=`: a non-nif global may peep to
   ; a word that looks like a heap pointer, which `=`/eql would deref and crash on.
   (opof v) (? (id? lvm_ret0 (peek 1 v)) (link (peek 0 v) 1)
               (&& (id? lvm_cur (peek 0 v)) (id? lvm_ret0 (peek 3 v))) (link (peek 2 v) (peek 1 v))
               0)
   (hgen v op ar pure x) (: as (cup x) n (tally as)
    (go hv a) (? (atom? a) (bake hv)             ; all args constant -> fold to a value
     (: cv (kconst (cap a))
      (? (&& pure (cap cv)) (go (hv (cup cv)) (cup a))         ; static arg: fold it into the partial
         (&& op (= n ar)) (link iop (link op as))              ; matching-arity nif -> inline (the hot path, keep)
         (id? hv v)                                            ; no static prefix folded -> the original apply
          (? (&& (< 1 ar) (= n ar)) (link apx (link 1 x))      ;   multi-arg fn -> n-ary apply
             (link apx (link 0 x)))                            ;   generic l2r apply
         (link apx (link 0 (link (bake hv) a))))))             ; static prefix folded -> apply the partial to the rest
    (go v as))
   ; the operator symbols are quoted one by one -- bare mid-list they would
   ; capture their left neighbor when this file compiles (the opfix pass).
   (add t s) (: v (gv s ())
    (? (charm? v) t
     (: o (opof v) p (pureset v)
      (? (|| o p)
       (: op (? o (cap o) 0)
          ar (? o (cup o) (id? lvm_cur (peek 0 v)) (peek 1 v) 0)   ; nif/multi-arg-fn arity
          (pin t v (\ x (hgen v op ar p x))))
       t))))
   (foldl add (tablet 0) (catmap keys (books ())))))

(:- (\ x (:
 c (sco 0 (list 0) 0)
 y (feel c (opfix x))    ; opfix first: ev = the deserialized-data lane, opfix factors its sigil surface
 (ana c y (k0 c) 0 0)))
  lvm_cur (peek 0 (+))
  (sco p a i) (pin (pin (pin (tablet 0) 'arg a) 'imp i) 'par p)
  (rootc c) (? (c 'par) (rootc (c 'par)) c)        ; top scope: where feel stashes 'src
  ; --- THE EMISSION INTERFACE (the codegen seam) --------------------------------------
  ; ana walks the analyzed form and emits code through these primitives. an EMITTER is a
  ; curried (\ k n ..): k = the continuation emitter, n = the current cell index (the
  ; thread builds BACKWARD, poke -1 prepending). `compose` (prel: (compose f g x) = (f (g x)))
  ; sequences emitters -- (compose A B) emits A, then B, then k. the leaf emitters:
  ;   kim x    -- a quote / constant            karg i  -- an arg ref at frame index i
  ;   em1 op   -- a 1-word inline vm op          em2 op x -- a 2-word op (op + operand)
  ;   kap n    -- an n-ary apply (peeps the continuation for lvm_ret -> a tail call)
  ;   aco      -- a cond (below);  k0/k0s -- thread terminators (start a thread)
  ; fuse/spa/spq are THIS backend's peepholes (fuse an operand into a following ap/tap;
  ; zero-operand opcodes for the hot arg/quote values). ava/avb resolve a variable to one
  ; of karg (a local, at its [imps args] frame slot) / kim (a global constant) / em2 lvm_index.
  ; This is the THREADED (bytecode) backend -- the portable default that every target runs
  ; (host, kernel, wasm, aarch64, and the little ones: playdate, teensy). A NATIVE backend
  ; (ai/glaze/emit.l, x86-64, opt-in) implements the SAME leaf interface over a byte buffer
  ; instead of cells -- kim -> movabs, karg -> mov [rcx+8i] + a fixnum guard, em1 -> the
  ; op's machine code, aco -> cmp+jcc -- today via the ala creation hook (book['natjit])
  ; for leaf bodies, with the unhandled ops (kap = a call) DEOPTing into this thread.
  ; Pulling the rest of the interface through (kap as a native call) is the open work.
  (p2 i x k) (poke -1 i (poke -1 x k))
  (em1 x k n) (poke -1 x (k (+ 1 n)))
  (em2 i x k n) (poke -1 i (poke -1 x (k (+ 2 n))))
  ; karg/kim: emit an arg ref / a quote, fusing with an immediately-following
  ; 1-ary apply (lvm_ap) or tail-call (lvm_tap) that kap already wrote into the
  ; continuation head. The same emit works for both: overwrite that op cell with
  ; the operand (seek 1 keeps what follows -- the rest for ap, the frame-size for
  ; tap) and prepend the fused op; only the ap differs. kap over-reserves a
  ; word, so the reclaimed cell becomes -1 slack (spin memsets it; GC-safe).
  ; operand-value specialization: a zero-operand opcode for the hottest arg indices
  ; / quote constants, emitted in the plain (non-ap/tap) path -- covers arg/quote
  ; consumed by inlined ops, e.g. n in (- n 1). 1-word op, no operand fetch; the
  ; reclaimed operand cell is -1 slack (spin memsets it; GC-safe).
  ; index/value -> specialized-op. A compare chain beats a `peep`-hash here: `peep`
  ; is a heavyweight polymorphic nif (type-dispatch + hash + eql), costing far more
  ; than a few fixnum compares that short-circuit on the common small values
  ; (measured: a hash made boot +13% vs +5% for this chain; frequency-reordering
  ; the chain was a wash). The charm? guard keeps spq from ever hashing a heap value.
  (spa i) (? (= i 0) lvm_arg0 (= i 1) lvm_arg1 (= i 2) lvm_arg2 (= i 3) lvm_arg3 0)
  (spq v) (? (charm? v) (? (= v 0) lvm_quo0 (= v 1) lvm_quo1 (= v 2) lvm_quo2
                         (= v 3) lvm_quo3 (= v -1) lvm_quom1 (= v -2) lvm_quom2 0) 0)
  (fuse a o t sp x k n)                          ; a=ap-op o=tap-op(0=none) t=plain-op sp=specializer
   (: tail (k (+ 2 n)) h (peek 0 tail)
    (? (id? h lvm_ap)         (p2 a x (seek 1 tail))
       (&& o (id? h lvm_tap)) (p2 o x (seek 1 tail))
       (: s (sp x) (? s (poke -1 s tail) (p2 t x tail)))))
  ; arg fuses both ap and tap; quote only ap. quote;tap (a constant arg to a tail
  ; call, e.g. (loop 0)) is left unfused: overwriting the shared tap cell in some
  ; emit contexts corrupts a branch's jump target -- safe for arg (a fixnum index)
  ; but not for quote. The rarest of the four cases; deferred.
  (karg x k n) (fuse lvm_argap   lvm_argtap lvm_arg   spa x k n)
  (kim  x k n) (fuse lvm_quoteap 0           lvm_quote spq x k n)
  (k0 c n) (poke -1 lvm_ret (poke (+ 1 n) (ary c) (spin (+ 2 n))))
  ; k0s: like k0 but reserves one extra LEADING cell (so the text is shifted up
  ; by one) for ala to stash the lambda's source \-expr at value[-1], where the
  ; printer (gzput_fn) finds it. entry = cell 1, src = cell 0.
  (k0s c n) (poke -1 lvm_ret (poke (+ 2 n) (ary c) (spin (+ 3 n))))
  (ary c) (+ (tally (c 'arg)) (tally (c 'imp)))
  (pro f) (? (charm? f) f (: a (peek 0 f) (?- f
   (id? a lvm_unc) (pro (seek -2 (peek 2 f)))
   (id? a lvm_cur) (?- f (id? lvm_unc (peek 2 f))
                          (pro (seek -2 (peek 4 f)))))))
  ; feel: source->source pre-pass before `ana` -- expands macros, constant-folds, and marks
  ; applies with their n-ary-vs-l2r strategy. Tail position is NOT tracked here -- kap detects
  ; tail by peeking the continuation for lvm_ret at analysis time.
  (feel c x) (:
   (wx x bnd) (?
    (atom? x) x
    (: h (cap x) (?
     (id? h '\) (? (atom? (cuup x)) x                          ; quote
                (: r (lp x)                                     ; opfix (op-flat-ol) already flattened nested lambdas at the source, shared with c0
                   lam (link '\ (cat (cap r) (list (wx (cup r) (cat (cap r) bnd)))))
                   _ (push c 'src (link (cup lam) x))         ; tagged-body -> surface src for ala
                   lam))
     (id? h ':) (? (atom? (cup x)) ':                      ; (:) = the head read -- (f)==f at zero operands, a missing name (c0 agrees)
                 (atom? (cuup x)) (link ': (list (wx (caup x) bnd)))
                 (link ': (wxl (boxfix (cup x)) bnd)))   ; boxfix = letrec* capture-by-location source rewrite, post-macroexpand
     (id? h '?) (? (atom? (cup x)) '?                      ; (?) likewise: the empty form is the head's value
                 (link '? (wxc (cup x) bnd)))
     (: m (? (nom? h) (macros h) 0)                     ; macro head? expand, then re-walk
      (? m (wx (m (cup x)) bnd)
         (fold (map (\ e (wx e bnd)) x) bnd))))))
   (wxl bs bnd) (wxb bs (cat (ln bs) bnd))        ; a let's names all shadow throughout
   (wxb bs bnd) (?
    (atom? bs) bs
    (atom? (cup bs)) (list (wx (cap bs) bnd))
    (: nd (dsug (cap bs) (caup bs))               ; desugar (f a..) so wx's \ adds params to bnd
     (link (cap nd) (link (wx (cup nd) bnd) (wxb (cuup bs) bnd)))))
   ; cflip: the nil?-flip peephole on a cond clause list. since the cond tests g_false == nil?,
   ; (? (nil? e) c [el]) and (? e [el] c) are equal -- flipping the branches drops the nil? wrapper
   ; (and lets cst then fold a now-bare constant test). fires ONLY on an EXACT (nil? e) test in a
   ; 2- or 3-form clause; a longer clause list keeps its tail unflipped. a DIRECT structural rewrite
   ; (the old unify-table version -- firstr over a cflip-rules global -- broke the egg's self-compile).
   (cflip bs) (? (&& (two? (cup bs)) (two? (cap bs)) (id? (caap bs) 'nil?) (atom? (cuup (cap bs))))
    (: e (caup (cap bs)) c (caup bs) rest (cuup bs)
     (? (atom? rest)       `(e () c)                ; (nil? e) c    -> (e () c)
        (atom? (cup rest)) `(e (cap rest) c)        ; (nil? e) c el -> (e el c)
        bs))
    bs)
   ; cst: a post-wx test that is a compile-time CONSTANT -> (1 . falsy?), else 0. mirrors feels'
   ; cval (a non-symbol atom, or a (\ v) quote of one); the cond tests g_false == nil?, so the
   ; constant's truth is exactly nil? of its value -- a folded test prunes its dead branch.
   ; cst: re-read the shared `kconst` (const? . value, prel) as (const? . falsy?) -- the constant's truth
   ; is exactly nil? of its value, so a folded test prunes its dead branch. One recognizer (kconst) across
   ; scopes that can't otherwise share (feels' cval was the same logic; cprop's propk? is the const? bit).
   (cst t) (: c (kconst t)
              (? (cap c) (link 1 (nil? (cup c)))       ; kconst knows it (atom / quote literal)
                 (&& (atom? (cup t)) (atom? (cap t)) (nil? (nom? (cap t)))) (link 1 (nil? (cap t)))  ; PLUS (c) == c: a folded monadic (opfix wraps (! e) -> ((nil? e)), so a folded test lands wrapped)
                 0))
   (wxc bs bnd) (: fb (? (member? 'nil? bnd) bs (cflip bs))
    (? (atom? fb) (list ())                           ; clauses ran out: implicit () else (nil-ontology)
       (atom? (cup fb)) (list (wx (cap fb) bnd))      ; the lone else
       (: t (wx (cap fb) bnd) k (cst t)               ; walk the test; is it a static constant?
        (? (atom? k) (link t (link (wx (caup fb) bnd) (wxc (cuup fb) bnd)))   ; unknown -> keep the clause
           (cup k)   (wxc (cuup fb) bnd)               ; statically FALSE -> drop this clause, try the rest
                     (list (wx (caup fb) bnd))))))     ; statically TRUE  -> this result IS the cond, drop rest
   ; napof: v is a non-nif multi-arg fn whose arity matches the n>1 call args -> n-ary apply.
   ; `id?`-safe peeps (a non-fn value never matches lvm_cur); mirrors app's old `fa`/`na`.
   (napof v args) (? (charm? v) 0
    (? (id? lvm_cur (peek 0 v)) (: ar (peek 1 v) (&& (< 1 ar) (= (tally args) ar))) 0))
   ; fold: un-shadowed global head -> ap (fold/iop/apx); else mark the call as an apx
   ; node (apx nary head . args) carrying the n-ary-vs-l2r strategy (1 = n-ary, 0 = l2r).
   (fold x bnd) (: h (cap x)
    (? (atom? (cup x)) x                          ; (f) single element -> ana's (atom? b) handles
       (|| (nil? (nom? h)) (member? h bnd)) (link apx (link 0 x))   ; local/computed head
       (: v (gv h ()) hd (feels v)
        (? hd (hd x)
           (napof v (cup x)) (link apx (link 1 x))
           (link apx (link 0 x))))))
   ; cprop: the partial-evaluation pre-pass. it threads a static VALUE env `se` (name . const-form)
   ; and (1) propagates a constant-bound var to its value, (2) FOLDS a pure-op call on constant args
   ; via the op's first-class nif (foldc -- NOT via (book op): these ops are compiler-inlined, not
   ; runtime book keys, so (book '+) is not the nif). it does NOT prune conds (wxc does that,
   ; correctly, downstream) and it does NOT unfold recursion: the in-compiler bounded-unfold proved
   ; near-inert on this VM (cheap calls -> no measurable win; see doc/proto/interp-spec.l). true
   ; interpreter specialization -- the 1st Futamura projection, ~8x on that yardstick -- lives in the
   ; OFFLINE partial evaluator, doc/proto/mix.l, where static DATA folds too. cprop runs before wx
   ; (pre-boxfix, pre-expansion); only an already-constant RHS propagates (a forward ref / cell read
   ; never is -- letrec-safe); a non-constant rebind or a lambda param KILLS the name.
   (propk? v) (cap (kconst v))   ; a constant FORM? -- the const? bit of the shared kconst recognizer (prel; cf. cst, the falsy projection)
   (assq k se) (? (atom? se) 0 (id? k (caap se)) (cap se) (assq k (cup se)))
   (rmq k se) (? (atom? se) () (id? k (caap se)) (rmq k (cup se)) (link (cap se) (rmq k (cup se))))
   (strip ps se) (? (atom? ps) se (strip (cup ps) (rmq (cap ps) se)))                 ; kill all params
   (cnul? l) (! (two? l))                                                             ; end-of-spine (NOT net)
   (cbake v) (? (charm? v) v (L '\ v))                                                ; folded value -> source
   (kval v) (? (atom? v) v (caup v))                                                  ; a const FORM -> its value
   (allk as) (? (cnul? as) 1 (? (propk? (cap as)) (allk (cup as)) 0))                 ; all args constant?
   opval (L (L '+ (+)) (L '- (-)) (L '* (*)) (L '// (//)) (L '% (%))                   ; pure ops -> first-class nif
            (L '= (=)) (L '< (<)) (L '<= (<=)) (L '> (>)) (L '>= (>=))
            (L '! (nil?)) (L 'nil? (nil?)))
   (inop k s) (? (cnul? s) 0 (id? k (caap s)) 1 (inop k (cup s)))                     ; is k a key of the op table?
   (opget h) (: e (assq h opval) (? (atom? e) 0 (caup e)))
   (foldc h as) (cbake (foldl (\ g a (g a)) (opget h) (map kval as)))                 ; apply the nif to the consts
   ; --- the known-lambda INLINER (cprop's beta-reduction lane) ----------------------------
   ; beta-reduce an application whose (resolved) head is a statically-known lambda. SOUND by
   ; three gates: the lambda is INLINABLE (non-recursive, body is bsub-safe `simple?`, and
   ; CLOSED -- every free var a global, so it means the same at the call site), the args are
   ; PURE (`allp` -- so duplicating/dropping them is unobservable), and a FUEL bound caps the
   ; reduction cascade (omega-style self-application would otherwise loop). The cascade runs
   ; through cprop's normal recursion: (adder i) reduces to a lambda VALUE, which becomes
   ; (twice ..)'s arg, whose body's f-applications then reduce -- collapsing curried HOFs to
   ; first-order arithmetic the back end (and the glaze) can take native. See doc/proto/inl.l.
   ; SOUNDNESS, the subtle part: beta IS NOT bridged by `=` on closures (the spec), so a
   ; beta-PRODUCED closure must never ESCAPE to where =/id?/show could observe it. So we
   ; thread an operator-position flag `op`: a beta result that is itself a lambda is committed
   ; only when CONSUMED (op=1, an enclosing application's head); at a VALUE position (op=0) we
   ; REVERT to the un-inlined source, preserving the capturing closure. ((twice (adder i)) i)
   ; collapses to 3i (a value -> fine); ((\ n ..) 5) stays a capturing closure (it escapes).
   (pure-head? h) (! (! (peep pureset (gv h ()) 0)))                                    ; h's global value is a KNOWN PURE fn (the lifted ~50-fn set)
   (allp as se) (? (cnul? as) 1 (? (purep (cap as) se) (allp (cup as) se) 0))          ; all args effect-free?
   (purep a se) (?                                                                     ; effect-free -> duplicable/droppable
    (atom? a) 1                                                                         ; nom / number / string
    (id? (cap a) '\) 1                                                                  ; a lambda value (pure to build)
    (id? (cap a) '?) (allp (cup a) se)                                                  ; cond: pure iff every limb is
    (nom? (cap a)) (: e (assq (cap a) se)                                               ; a known pure lambda OR a pure fn, applied to pure args
       (? (&& (two? e) (lambp (caup e))) (allp (cup a) se) (pure-head? (cap a)) (allp (cup a) se) 0))
    0)
   (smpl? x) (?                                                                        ; bsub-safe body: no : / macro head
    (atom? x) 1
    (id? (cap x) ':) 0
    (id? (cap x) '\) (? (atom? (cuup x)) 1 (smpl? (last x)))
    (nom? (cap x)) (? (macros (cap x)) 0 (all smpl? x))
    (all smpl? x))
   (fvs x bs) (?                                                                       ; free vars of a simple term
    (nom? x) (? (|| (id? x ()) (member? x bs)) () (list x))
    (atom? x) ()
    (id? (cap x) '\) (? (atom? (cuup x)) () (: r (lp x) (fvs (last x) (cat (cap r) bs))))
    (foldl (\ a e (cat a (fvs e bs))) () x))
   (closedl? lam) (all (\ v (! (! (gv v ())))) (fvs lam ()))                            ; every free var a global (means the same elsewhere)
   (pbody? x bnd) (?                                                                   ; body is PURE: every call head a pure fn or a param
    (atom? x) 1
    (id? (cap x) '?) (all (\ e (pbody? e bnd)) (cup x))
    (id? (cap x) '\) (? (atom? (cuup x)) 1 (: r (lp x) (pbody? (last x) (cat (cap r) bnd))))
    (nom? (cap x)) (&& (|| (pure-head? (cap x)) (member? (cap x) bnd)) (all (\ e (pbody? e bnd)) (cup x)))
    (all (\ e (pbody? e bnd)) x))
   (inlinable? nm lam) (&& (lambp lam) (smpl? lam) (closedl? lam) (pbody? lam ()) (! (w nm lam 0 0 0)))
   (rmkeys ps env) (filter (\ p (! (member? (cap p) ps))) env)                         ; drop shadowed substitutions
   (bsub env x) (?                                                                     ; capture-avoiding substitution
    (nom? x) (: p (assoc x env) (? (two? p) (cup p) x))
    (atom? x) x
    (id? (cap x) '\) (? (atom? (cuup x)) x
       (: r (lp x) ps (cap r) ren (map (\ p (link p (nom 0))) ps)                      ; rename binders to fresh -> no capture
          (link '\ (cat (map cup ren) (list (bsub (cat ren (rmkeys ps env)) (last x)))))))
    (map (\ e (bsub env e)) x))
   (beta lam as) (: r (lp lam) ps (cap r) np (tally ps)                               ; apply a lambda to args (curried)
    (? (< (tally as) np) (link lam as)                                                 ; under-saturated -> leave a partial
       (: bd2 (bsub (zip ps (take np as)) (last lam)) rest (drop np as)
          (? (two? rest) (link bd2 rest) bd2))))
   (cplam x se fl op) (? (atom? (cuup x)) x                                           ; (\ v) quote -> leave
    (: r (lp x) ps (cap r) (link '\ (cat ps (list (cprop (cup r) (strip ps se) fl 0)))))) ; the body is a value -> op 0
   (cpbinds bs se fl op) (?
    (atom? bs) bs
    (atom? (cup bs)) (list (cprop (cap bs) se fl op))                                  ; the let's BODY inherits the let's op
    (: nd (dsug (cap bs) (caup bs)) nm (cap nd) v1 (cprop (cup nd) se fl 0)           ; a binding value is a value -> op 0
       se2 (? (|| (propk? v1) (inlinable? nm v1))                                      ; a const OR a known pure lambda enters se
              (link (list nm v1) (rmq nm se)) (rmq nm se))
       (link nm (link v1 (cpbinds (cuup bs) se2 fl op)))))
   (cprop x se fl op) (?
    (atom? x) (? (nom? x) (: e (assq x se) (? (atom? e) x (caup e))) x)               ; const/known-lambda var -> value
    (id? (cap x) '\) (cplam x se fl op)
    (id? (cap x) ':) (link ': (cpbinds (cup x) se fl op))
    (id? (cap x) '?) (link '? (map (\ e (cprop e se fl op)) (cup x)))                  ; no prune here -- wxc does it
    (: h (cap x) m (? (nom? h) (macros h) 0)                                          ; macro head? expand on RAW args -- a structural
       (? m (cprop (m (cup x)) se fl op)                                               ; macro (assert's quoted msg, a two?/cap probe) must
          (: as (map (\ e (cprop e se fl 0)) (cup x))                                  ; ARGS are values -> op 0 (escape mode)
             hr (? (nom? h) (: e (assq h se) (? (atom? e) h (caup e))) (cprop h se fl 1)) ; HEAD is consumed -> op 1
             (? (&& (< 0 fl) (lambp hr) (allp as se))
                  (: red (cprop (beta hr as) se (- fl 1) op)                           ; KNOWN LAMBDA -> beta, re-cprop (fuel-bounded)
                     (? (|| op (! (lambp red))) red (link h as)))                      ; escaping lambda result -> REVERT (keep the closure)
                (&& (nom? h) (inop h opval) (allk as)) (foldc h as)                    ; pure-op on consts -> fold (as before)
                (link h as))))))                                                       ; else rebuild with the RAW head (source unchanged)
   (wx (cprop x () 64 0) 0))
  ; a bare symbol is a variable reference -- EXCEPT the zero point, which reads as a
  ; nom? literal (the `()` a (\ _ ()) / failed parse / `('x) tail evaluates to).
  ; routing it to ava treats it as a free var and captures it as a SPURIOUS import:
  ; it inflates a closure's arity by one with no matching value applied at the ref
  ; site -> an under-saturated partial (silently wrong). it is a constant. the test is
  ; id?-the-zero-point, NOT nil?: boxfix's cell names are FRESH nameless mints (also
  ; nil?) bound and referenced as real variables, so they must still reach ava.
  (ana c x) (? (&& (nom? x) (! (id? x ())))  (ava c x)
                   (atom? x) (kim x)
                   (: a (cap x) b (cup x) (?
                    (atom? b) (ana c a)
                    (id? a '? ) (aco c b)
                    (id? a '\ ) (? (atom? (cup b)) (kim (cap b)) (ana c (ala c 0 b)))
                    (id? a ': ) (ale c (cap b) (cup b))
                    (id? a iop) (iap c b)
                    (id? a apx) (apxh c b)
                    (: m (macros a)
                     (? m (ana c (m b)) (app c a b))))))
  (push c k x) (: _ (pin c k (link x (c k))) x)
  (pop c k) (: x (c k) _ (pin c k (cup x)) (cap x))
  (iap c b) (: op (cap b) as (cup b)                       ; (iop op . args) -> inline the vm op
   (? (atom? (cup as)) (compose (ana c (cap as)) (em1 op))      ; one arg
      (: s (c 'stk) k (apr2l c as) _ (pin c 'stk s) (compose k (em1 op))))) ; n-ary, r2l args
  ; falook: walk the scope chain for head's fixed arity, recorded by ale in each
  ; enclosing let's 'far map. > 0 = a multi-arg lambda sibling of that arity; 0 = a
  ; binding of that name that is NOT an n-ary-callable fixed-arity lambda (a value, a
  ; single-arg lambda, or a rebind) -- it SHADOWS outer fars, so stop; -1 = not bound
  ; in this scope, keep walking. So a saturated call to a letrec lambda sibling can take
  ; the one-shot n-ary apply (apn/tapn) instead of currying, the same as a book global.
  (falook c h) (?- 0 c
   (: far (c 'far) a (? (book? far) (peep far h -1) -1)
    (? (< 0 a) a (= -1 a) (falook (c 'par) h) 0)))
  ; apxh: (apx nary head . args) -> apply. nary -> r2l arg eval + a single n-ary apply;
  ; else l2r 1-ary chain. kap detects tail vs non-tail by peeking the continuation.
  ; n-ary fires for a book-global multi-arg fn (fold/napof set nary) OR a saturated call
  ; to a letrec lambda sibling of matching arity (falook -- locals fold can't see).
  (apxh c b) (: nary (cap b) head (caup b) args (cuup b)
              n2 (? nary 1 (&& (nom? head) (: a (falook c head) (&& (< 1 a) (= (tally args) a)))))
              f (ana c head) s (c 'stk) _ (push c 'stk 0)
              g (? n2 (compose (apr2l c args) (kap (tally args))) (apl2r c args))
              _ (pin c 'stk s)
            (compose f g))
  (app c a b) (: f (ana c a)
               s (c 'stk) _ (push c 'stk 0)
               g (apl2r c b) _ (pin c 'stk s)
             (compose f g))
 (apl2r c b) (?- id (two? b) (: f (ana c (cap b)) g (apl2r c (cup b))
                    (compose f (compose (kap 1) g))))
 (apr2l c b) (?- id (two? b) (: g (apr2l c (cup b)) f (ana c (cap b)) _ (push c 'stk 0) (compose g f)))
 (kap n k m)
  (: j (k (+ 2 m))
   t (id? (peek 0 j) lvm_ret)                              ; peep the continuation for ret -> tail
   (? t (? (> n 1) (poke -1 lvm_tapn (poke 0 n j)) (poke 0 lvm_tap j))
        (? (> n 1) (p2 lvm_apn n j) (poke -1 lvm_ap j))))

  ; aco -- compile a cond (? test result .. else). standard jump-threaded shape: each
  ; test, on false, branches (lvm_cond) to the next clause; on true, runs its result and
  ; JUMPS to the join (the cond's continuation k). the wrapper records k on the 'join
  ; stack for the duration; tojoin reads it (and inlines a ret/tap join over a dead jump).
  ; a constant test (pro folds it to a quote) picks its branch outright, no code.
  (aco c b) (:- (: f (clauses b) (\ k n (: k2 (f (compose (push c 'join) k) n) _ (pop c 'join) k2)))
   ; tojoin: after a result, jump to the join (top of 'join) -- but fuse a ret/tap/tapn
   ; join INLINE rather than emit a jump straight to a return.
   (tojoin k n) (:
    j (k (+ 3 n))
    a (cap (c 'join))
    i (peek 0 a)
    (? (| (id? lvm_ret i) (id? lvm_tap i)) (p2 i (peek 1 a) j)
       (id? lvm_tapn i)                   (p2 i (peek 1 a) (poke -1 (peek 2 a) j))
                                         (p2 lvm_jump a j)))
   ; clauses: test/result pairs then a trailing else. a constant test folds to one
   ; branch; else emit lvm_cond -- true runs `then` + jumps to join, false falls to `rest`.
   (clauses b) (?
    (atom? b)       (kim ())                                ; no else (feel usually supplies one)
    (atom? (cup b)) (compose (ana c (cap b)) tojoin)            ; trailing else: result, then join
    (: test (ana c (cap b))
       then (ana c (caup b))
       rest (clauses (cuup b))
       (? (= kim (pro test)) (? (peek 3 test) then rest)   ; constant test -> pick a branch
        (\ x (test (\ n
         (: k (compose (push c 'alt) (rest x))                  ; k = the false branch (the rest)
            j (then (tojoin k) (+ 2 n))                    ; true: then, jump to join, into k
            (p2 lvm_cond (pop c 'alt) j)))))))))

  ; recursive-fn ref: bake `quote code` if the closure is built, else `quote 0`
  ; + a backpatch site `(lfd . cell)` on the scope for wire to resolve.
  (qsite site k n) (: cell (poke -1 0 (k (+ 2 n)))
                      _ (poke 2 cell site)
                    (poke -1 lvm_quote cell))
  ; a closure CELL is a box (tablet 0) holding the closure chain (entry . imports).
  ; mkc makes one, cof reads it, cput stores into it -- the letrec* capture fixpoint and
  ; the recursive-ref backpatch mutate THROUGH the box (pin/peep), so the shared mutable
  ; cell is a proper heap object, not a chain tail poked in place (no raw set-tail).
  (mkc v) (pin (tablet 0) 0 v)
  (cof e) (peep (cup e) 0 0)
  (cput e v) (: _ (pin (cup e) 0 v) v)
  (lz c lfd scope)(: code (cap (cof lfd))
                   p (? code (em2 lvm_quote code)
                        (: site (link lfd 0)
                           _ (pin scope 'sites (link site (scope 'sites)))
                         (qsite site)))
                   _ (push c 'stk 0)
                   q (apl2r c (cup (cof lfd)))
                   _ (pop c 'stk)
                 (compose p q))
  ; variable expression analyzer
  (ava c x)
   (: lfd (assoc x (c 'lam))
    (? (two? lfd) (lz c lfd c)
       (: s (c 'stk)
          (stki d) (lidx x (cat (d 'imp) (d 'arg)))
          (q i j m) (karg (+ i (stki c)) j m)
        (?- (avb c (c 'par) x)
         (member? x s) (karg (lidx x s))
         (>= (stki c) 0) (q (tally (c 'stk)))))))

  (avb c d x)
   (? (nil? d) ; outside all lexical scopes?
       (: y (gv x gone) ; check global scope (the layered walk)
        (? !(id? y gone) (kim y) ; if it's there use that
         (: _ (? (c 'par) (push c 'imp x))
          (em2 lvm_index x))))
    (: lfd (assoc x (d 'lam))
     (? (two? lfd) (lz c lfd d)
        ; the shadow guard: d's let BINDS x ('far keys every binding name and is
        ; pinned before the closures phase) but x is neither in 'lam yet (a
        ; later/self lambda sibling, pre-weave) nor a slot on the let's own
        ; stack (they live on (d 'par)) -- the nom is THIS let's, so the walk
        ; must not escape to an enclosing binding of the same spelling. import
        ; it, as the book-miss would; the weave re-analysis resolves it through
        ; 'lam. escaping here applied a same-named outer sibling's imports
        ; MID-weave, past the fixcaps fixpoint, so every self-site of the
        ; enclosing lambda under-applied -- the recursion answered a truthy
        ; partial, silently.
        (: far (d 'far)
         (? (&& (book? far) (<= 0 (peep far x -1)) (nil? (member? x ((d 'par) 'stk))))
            (: _ (? (c 'par) (push c 'imp x)) (em2 lvm_index x))
            (: s (d 'stk)
               (stki d) (lidx x (cat (d 'imp) (d 'arg)))
               (q i j m) (karg (+ i (stki c)) j m)
             (?- (avb c (d 'par) x)
              (member? x s) (: _ (? (c 'par) (push c 'imp x))
                             (q (tally (c 'stk))))
              (>= (stki d) 0) (: _ (? (c 'par) (push c 'imp x))
                               (q (tally (c 'stk)))))))))))
  ; lambda analyzer
  (ala c imp exp) (:
   d (sco c (init exp) imp)
   k (ana d (last exp) (k0s d))
   a (ary d)
   e ((? (= a 1) k (em2 lvm_cur a k)) 0)           ; entry = cell 1 (cell 0 is the spare src slot)
   ; source \-expr for the printer. take the SURFACE body feel stashed for this node
   ; (keyed by the tagged exp) so iop/apx tags don't leak into the printed source;
   ; fall back to exp if unrecorded. prepend the captured imports as leading params
   ; (frame is [imps args]) so a closure prints as ,((\ y x …) capturedvals) and
   ; round-trips through read+eval.
   os (assoc exp ((rootc c) 'src))
   s (link '\ (cat (d 'imp) (? (two? os) (cuup os) exp)))
   _ (poke -1 s e)                                  ; value[-1] = source \-expr
   _ (trim (seek -1 e))                             ; tag head spans [src .. body]; value stays e
   ; native-creation hook (dormant unless book['natjit] is installed -- opt-in, x86-64):
   ; given the bytecode entry e, its source \-expr s (= (\ imps.. args.. body), so the
   ; frame [imps args] and surface body are right there) and arity a, it may return a
   ; native-backed entry that DEOPTS into e on overflow. transparent (value[-1]=s kept),
   ; id?-distinct (fresh per ala call), macro-safe (s is the surface, pre-tag). dormant
   ; -> peep gives 0 -> e unchanged, so the egg/bootstrap is untouched.
   hk (gv 'natjit 0)
   (link (? hk (hk e s a) e) (d 'imp)))

  ; --- let analyzer (the hard one) -- letrec* over (: name def .. body). three phases:
  ;   collect  -- the bindings into source-order (name . def) chains, and the body form
  ;   closures -- analyze each lambda def to a closure, then PROPAGATE captures among
  ;               mutually-recursive closures to a fixpoint (a sibling's captures flow in)
  ;   wire     -- emit each binding, backpatch recursive refs, apply the body
  ; boxing (the letrec* capture-by-location rewrite) already happened in feel (boxfix), so
  ; the defs compile directly. q = a child scope holding the let's lambdas + backpatch sites.
  ; the phases run IN SEQUENCE (the :- body, last): collect the chains (pure), pin the
  ; sibling arity map, build+propagate the closures, then wire (emit + backpatch + body).
  (ale c a b) (?
   (atom? b) (ana c a)
   (:- (wire (cap cb) (caup cb) (cuup cb) (closures (cap cb)))
    q (sco c (c 'arg) (c 'imp))
    ; collect: gather (name . def) chains in source order -> (prs body . even). the body is
    ; the trailing odd form; even = a body-LESS let (last value is result, names defglob).
    (collect prs n d rest) (: nd (dsug n d)
     (? (atom? rest)       (link (rev (link nd prs)) (link (cap nd)   1))   ; body-less: last NAME is the body
        (atom? (cup rest)) (link (rev (link nd prs)) (link (cap rest) 0))   ; a trailing body form
                           (collect (link nd prs) (cap rest) (caup rest) (cuup rest))))
    cb (collect 0 a (cap b) (cup b))
    ; far: {name -> arity} for the lambda siblings, SYNTACTIC (binder count off the \-expr),
    ; stable through the backpatch rebuild that zeroes closure cells. only fixed-arity
    ; multi-arg lambdas (arity > 1) carry one; a value binding, single-arg lambda, or a
    ; rebound name (sequence law) pins 0 -> the call stays l2r. Pinned BEFORE the closures
    ; analyze their bodies (and weave's re-analysis, also under q), so falook sees it.
    (farof ps t) (?- t (two? ps)
     (: pr (cap ps) k (cap pr) d (cup pr)
        a (? (&& (= -1 (peep t k -1)) (lambp d)) (- (tally (cup d)) 1) 0)
      (farof (cup ps) (pin t k (? (< 1 a) a 0)))))
    _ (pin q 'far (farof (cap cb) (tablet 0)))
    ; closures: each lambda def -> a closure via ala (a non-lambda -> just a stack slot),
    ; building [names..] on the stack; then PROPAGATE captures among mutually-recursive
    ; closures to a fixpoint, and return the lambdas with the let's OWN names dropped from
    ; each capture set (those are locals, resolved by wire, not imports).
    (closures prs) (:- (fixcaps l)
     s (c 'stk)
     _ (push c 'stk 0)
     (split a ps) (?
      (atom? ps) a
      (nil? (lambp (cuap ps)))
       (: _ (push c 'stk (caap ps))
        (split a (cup ps)))
      (: k (caap ps)
         v (ala q 0 (cuuap ps))
         a2 (link (link k (mkc v)) a)
       _ (push c 'stk k)
       (split a2 (cup ps))))
     l (split 0 prs)
     _ (pin c 'stk s)
     ; capture propagation: if k1 references sibling k2, k2 must ALSO capture k1's imports (mutual
     ; recursion). `pass1` sweeps all ordered pairs ONCE, pouring k1's vars into k2 IN PLACE (cput);
     ; `monofix` (prel, the shared harness) repeats the pass until `capsize` (total imports, ascending)
     ; stops growing -- the pass mutates the cells and returns the SAME list, so monofix's snapshot-BEFORE
     ; size catches each pass's growth. Then drop the let's own names (locals, resolved by wire not import).
     (pour e1 e2) (each (cup (cof e1))                         ; pour e1's imports into e2 (skip dups; prepend)
        (\ var (? (member? var (cup (cof e2))) 0 (cput e2 (link (cap (cof e2)) (link var (cup (cof e2))))))))
     (pass1 lst k1 k2) (? (atom? k1) lst                       ; one full sweep over ordered pairs k1 x k2
        (atom? k2) (pass1 lst (cup k1) lst)                    ; k2 done -> next k1, reset k2
        (&& !(= k1 k2) (member? (caap k1) (cup (cof (cap k2)))))   ; k2 references k1
         (: _ (pour (cap k1) (cap k2)) (pass1 lst k1 (cup k2)))
        (pass1 lst k1 (cup k2)))
     (capsize lst) (foldl (\ a e (+ a (tally (cup (cof e))))) 0 lst)   ; total imports across closures (the measure)
     (fixcaps lst) (: done (monofix lst (\ st (pass1 st st st)) capsize)
                      j (map cap done)
                      (dropj x) (link (cap x) (mkc (link (cap (cof x)) (foldl (flip ldel) (cup (cof x)) j))))
                      (map dropj done)))

   (wire prs body even lams) (:
    ; weave: emit the binding defs left-to-right. a lambda def is RE-analyzed with its
    ; final import set (and backpatched in); a top-level body-less let's name is defglob'd.
    (weave nds) (? (atom? nds) id
     (: nd (cap nds) n (cap nd) d (cup nd)
        d (?- d (lambp d) (: cls (assoc (cap nd) lams)
                             x (ala q (cup (cof cls)) (cup d))
                             ; the import row is FROZEN here: every ref site that
                             ; already compiled (self-sites inside x, sites in
                             ; earlier-woven siblings) applied (cup (cof cls)).
                             ; growth means those sites under-apply -- scare,
                             ; never miscompile.
                             _ (? (= (tally (cup x)) (tally (cup (cof cls)))) ()
                                  (scare 'imports-grew n))
                           (cput cls x)))
        f (ana c d)
        g (?- id (&& even (nil? (c 'par)) !(id? n '_)) (em2 lvm_defglob n))  ; `_` binds locally, never to the book
        _ (push c 'stk n)
        h (weave (cup nds))
        (\ x (f (g (h x))))))
    _ (pin q 'lam lams)
    s (c 'stk)
    _ (push c 'stk 0)
    ; clear stale first-build closures so a ref hit during the rebuild defers to a
    ; backpatch site; the import sets are kept.
    _ (each lams (\ e (cput e (link 0 (cup (cof e))))))
    g (weave prs)
    ; closures final -> backpatch each recorded recursive-fn ref with its text.
    _ (each (q 'sites) (\ s (poke 0 (cap (cof (cap s))) (cup s))))
    _ (pin q 'sites 0)
    _ (pin c 'stk s)
    ; body-lambda analyzed AFTER inits (it takes the bindings as args; never makes sites)
    f (ana c (link '\ (cat (rev (map cap prs)) (list body))))
    h (kap (tally prs))
    _ (pin c 'stk s)
    (\ x (f (g (h x))))))))
