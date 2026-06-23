; iop/apx: unforgeable tag markers (uninterned) shared by feel -- which emits (iop op . args)
; and (apx nary head . args) nodes -- and ana, which dispatches on them. Top-level globals,
; NOT ev-block locals, so feel's per-global aps and ana resolve them by name. That keeps
; them out of ev's captured frame (and off every ap's import list: a ap closing over
; a sibling that captured iop/apx would otherwise drag both in dead -- see .feels).
(: iop (nom 'iop)
   apx (nom 'apx))

; feels: value->ap memo for global fns, built once by scanning every global. A ap
; folds an application to a value when its args are constant (pure fns only), else emits an
; (iop op . args) node iap inlines (any nif of matching arity), else leaves it. A nif is found
; by text shape (lvm_ret0 terminator); fold eligibility from the curated `names`. It lives
; as a global -- feel's fold reaches it by name -- so this ~126-entry table is NOT baked into
; ev's value; `.ev` then prints as just the ana+feel logic, and the table prints under `.feels`.
(: feels (:
   lvm_cur  (peek 0 (+))
   lvm_ret0 (peek 1 cap)
   (cval e) (? (nom? e) (link 0 0)               ; (const? . value): 1 head iff a literal
               (atom? e) (link 1 e)
               (&& (id? (cap e) '\) (atom? (cuup e))) (link 1 (caup e))
               (link 0 0))
   (bake v) (? (charm? v) v (list '\ v))           ; value -> source: fixnum bare else quote
   ; (op . arity) iff v is a nif. `id?` (identity) not `=`: a non-nif global may peep to
   ; a word that looks like a heap pointer, which `=`/eql would deref and crash on.
   (opof v) (? (id? lvm_ret0 (peek 1 v)) (link (peek 0 v) 1)
               (&& (id? lvm_cur (peek 0 v)) (id? lvm_ret0 (peek 3 v))) (link (peek 2 v) (peek 1 v))
               0)
   (hgen v op ar pure x) (: as (cup x) n (tally as)
    (go hv a) (? (atom? a) (bake hv)             ; all args constant -> fold to a value
     (: cv (cval (cap a))
      (? (&& pure (cap cv)) (go (hv (cup cv)) (cup a))         ; static arg: fold it into the partial
         (&& op (= n ar)) (link iop (link op as))              ; matching-arity nif -> inline (the hot path, keep)
         (id? hv v)                                            ; no static prefix folded -> the original apply
          (? (&& (< 1 ar) (= n ar)) (link apx (link 1 x))      ;   multi-arg fn -> n-ary apply
             (link apx (link 0 x)))                            ;   generic l2r apply
         (link apx (link 0 (link (bake hv) a))))))             ; static prefix folded -> apply the partial to the rest
    (go v as))
   ; the operator symbols are quoted one by one -- bare mid-list they would
   ; capture their left neighbor when this file compiles (the opfix pass).
   names (cat `('+ '- '* '/ '% '& '| '< '<= '= '>= '>)
          '(// << >> ^
            id? gcd modpow abs
            link cap cup caap caup cuap cuup
            dig lidx assoc member? last rev cat
            charm? nom? two? book? lit? string? nil? gem? twin? atom?
            snip string
            re im conj arg gem twin
            sine cosine log power))
   pureset (foldl (\ t s (: v (book s) (? v (pin t v 1) t))) (tablet 0) names)
   (add t s) (: v (book s)
    (? (charm? v) t
     (: o (opof v) p (pureset v)
      (? (|| o p)
       (: op (? o (cap o) 0)
          ar (? o (cup o) (id? lvm_cur (peek 0 v)) (peek 1 v) 0)   ; nif/multi-arg-fn arity
          (pin t v (\ x (hgen v op ar p x))))
       t))))
   (foldl add (tablet 0) (keys book))))

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
  ; word, so the reclaimed cell becomes -1 slack (twirl memsets it; GC-safe).
  ; operand-value specialization: a zero-operand opcode for the hottest arg indices
  ; / quote constants, emitted in the plain (non-ap/tap) path -- covers arg/quote
  ; consumed by inlined ops, e.g. n in (- n 1). 1-word op, no operand fetch; the
  ; reclaimed operand cell is -1 slack (twirl memsets it; GC-safe).
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
  (k0 c n) (poke -1 lvm_ret (poke (+ 1 n) (ary c) (twirl (+ 2 n))))
  ; k0s: like k0 but reserves one extra LEADING cell (so the text is shifted up
  ; by one) for ala to stash the lambda's source \-expr at value[-1], where the
  ; printer (gzput_fn) finds it. entry = cell 1, src = cell 0.
  (k0s c n) (poke -1 lvm_ret (poke (+ 2 n) (ary c) (twirl (+ 3 n))))
  (ary c) (+ (tally (c 'arg)) (tally (c 'imp)))
  (pro f) (? (charm? f) f (: a (peek 0 f) (?- f
   (id? a lvm_unc) (pro (seek -2 (peek 2 f)))
   (id? a lvm_cur) (?- f (id? lvm_unc (peek 2 f))
                          (pro (seek -2 (peek 4 f)))))))
  ; compile-time kind WARNINGS: the analysis is `warn-kinds` (prel, pure, returns
  ; the offending subforms -- sound by construction, an unknown kind is `top` which
  ; never warns); feel prints them to err only when the `warns` box is on (default
  ; off, so the bootstrap stays silent). eputs/ewarn are the err-side here.
  (eputs s) ((: (go i) (? (< i (tally s)) (: _ (put err (s i)) (go (+ i 1))) 0)) 0)
  (ewarn e) (eputs (+ (+ ";; warn: nil-by-kind " (show e)) "\n"))
  ; feel: source->source pre-pass before `ana` -- expands macros, constant-folds, and marks
  ; applies with their n-ary-vs-l2r strategy. Tail position is NOT tracked here -- kap detects
  ; tail by peeking the continuation for lvm_ret at analysis time.
  (feel c x) (:
   _ (? (peep warns 0 0) (each (warn-kinds x) ewarn) 0)        ; lint when the `warns` box is on (default off)
   (wx x bnd) (?
    (atom? x) x
    (: h (cap x) (?
     (id? h '\) (? (atom? (cuup x)) x                          ; quote
                (: r (lp x)
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
   ; cond-clause rewrite RULES (pat . tpl), tried in order by `firstr` (the prel unifier
   ; inside the compiler). the nil?-flip family: a (nil? e) test flips its branches and
   ; drops the wrapper, since the cond tests g_false(e) == nil?(e). `unify` enforces each
   ; EXACT shape on its own (proper-list tails must match), so a rule fires only on its
   ; arity; the lone side-condition left is nil? being unshadowed. rule 1 (3-clause) is
   ; byte-identical to the old hand-written peephole; rule 2 (2-clause, no else) is a NEW
   ; sound win the old guard never caught -- the table makes it nearly free.
   ve (var 'e)  vc (var 'con)  vl (var 'else)
   cflip-rules (L (link (L (L 'nil? ve) vc vl) (L ve vl vc))   ; ((nil? ?e) ?c ?el) -> (?e ?el ?c)
                  (link (L (L 'nil? ve) vc)    (L ve () vc)))   ; ((nil? ?e) ?c)     -> (?e () ?c)
   (firstr rules x) (? (atom? rules) x                ; first matching rule wins; else x
    (: r (rewrite (caap rules) (cuap rules) x) (? (id? r x) (firstr (cup rules) x) r)))
   ; cst: a post-wx test that is a compile-time CONSTANT -> (1 . falsy?), else 0. mirrors feels'
   ; cval (a non-symbol atom, or a (\ v) quote of one); the cond tests g_false == nil?, so the
   ; constant's truth is exactly nil? of its value -- a folded test prunes its dead branch.
   (cst t) (? (nom? t) 0                              ; a variable (or the () zero point): unknown
              (atom? t) (link 1 (nil? t))             ; number/string literal: known by its net
              (&& (id? (cap t) '\) (atom? (cuup t))) (link 1 (nil? (caup t)))   ; a quote (\ v)
              (&& (atom? (cup t)) (atom? (cap t)) (nil? (nom? (cap t)))) (link 1 (nil? (cap t)))  ; (c) == c: a folded monadic (opfix wraps (! e) -> ((nil? e)), so a folded test lands wrapped)
              0)
   (wxc bs bnd) (: fb (? (member? 'nil? bnd) bs (firstr cflip-rules bs))
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
       (: v (book h) hd (feels v)
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
   (propk? v) (? (nom? v) 0 (atom? v) 1 (&& (id? (cap v) '\) (atom? (cuup v))) 1 0)   ; a constant FORM?
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
   (cplam x se) (? (atom? (cuup x)) x                                                 ; (\ v) quote -> leave
    (: r (lp x) ps (cap r) (link '\ (cat ps (list (cprop (cup r) (strip ps se)))))))  ; params shadow
   (cpbinds bs se) (?
    (atom? bs) bs
    (atom? (cup bs)) (list (cprop (cap bs) se))                                       ; the lone body
    (: nd (dsug (cap bs) (caup bs)) nm (cap nd) v1 (cprop (cup nd) se)                ; desugar like wxb
       se2 (? (propk? v1) (link (list nm v1) (rmq nm se)) (rmq nm se))               ; extend or shadow se (consts)
       (link nm (link v1 (cpbinds (cuup bs) se2)))))
   (cprop x se) (?
    (atom? x) (? (nom? x) (: e (assq x se) (? (atom? e) x (caup e))) x)               ; const-bound var -> value
    (id? (cap x) '\) (cplam x se)
    (id? (cap x) ':) (link ': (cpbinds (cup x) se))
    (id? (cap x) '?) (link '? (map (\ e (cprop e se)) (cup x)))                       ; no prune here -- wxc does it
    (: h (cap x) m (? (nom? h) (macros h) 0)                                          ; macro head? expand on RAW args -- a structural
       (? m (cprop (m (cup x)) se)                                                    ; macro (assert's quoted msg, a two?/cap probe) must
          (: as (map (\ e (cprop e se)) (cup x))                                      ; see SOURCE, not a pre-folded constant; then cprop
             (? (&& (nom? h) (inop h opval) (allk as)) (foldc h as)                   ; the expansion (so do/let/&& fold exactly as before)
                (link h as))))))
   (wx (cprop x ()) 0))
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

  gone (nom 'gone)
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
       (: y (peep book x gone) ; check global scope
        (? !(id? y gone) (kim y) ; if it's there use that
         (: _ (? (c 'par) (push c 'imp x))
          (em2 lvm_index x))))
    (: lfd (assoc x (d 'lam))
     (? (two? lfd) (lz c lfd d)
        (: s (d 'stk)
           (stki d) (lidx x (cat (d 'imp) (d 'arg)))
           (q i j m) (karg (+ i (stki c)) j m)
         (?- (avb c (d 'par) x)
          (member? x s) (: _ (? (c 'par) (push c 'imp x))
                         (q (tally (c 'stk))))
          (>= (stki d) 0) (: _ (? (c 'par) (push c 'imp x))
                           (q (tally (c 'stk)))))))))
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
   hk (peep book 'natjit 0)
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
    (closures prs) (:- (propagate 0 l l l)
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
     ; propagate: if k1 references sibling k2, k2 must ALSO capture k1's imports (mutual
     ; recursion). sweep all ordered pairs, pour k1's vars into k2 (addv); a sweep that adds
     ; any var (n > 0) repeats until a full pass is stable -- then drop the let's own names.
     (propagate n l k1 k2) (?
      (&& k1 k2 !(= k1 k2) (member? (caap k1) (cup (cof (cap k2)))))
       (>>= n (cup (cof (cap k1))) (: (addv n v)
        (? (nil? v) (propagate n l k1 (cup k2))
         (: var (cap v)
            vars (cup (cof (cap k2)))
            n2 (? (member? var vars) n
               (: _ (cput (cap k2) (link (cap (cof (cap k2))) (link var vars)))
                (+ 1 n)))
            (addv n2 (cup v))))))
      k2 (propagate n l k1 (cup k2))
      k1 (propagate n l (cup k1) l)
      n (propagate 0 l l l)                                    ; a pass added vars -> sweep again
      (: j (map cap l)                                         ; stable: drop the let's own names
         (dropj x) (link (cap x) (mkc (link (cap (cof x)) (foldl (flip ldel) (cup (cof x)) j))))
       (map dropj l))))

   (wire prs body even lams) (:
    ; weave: emit the binding defs left-to-right. a lambda def is RE-analyzed with its
    ; final import set (and backpatched in); a top-level body-less let's name is defglob'd.
    (weave nds) (? (atom? nds) id
     (: nd (cap nds) n (cap nd) d (cup nd)
        d (?- d (lambp d) (: cls (assoc (cap nd) lams)
                             x (ala q (cup (cof cls)) (cup d))
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
