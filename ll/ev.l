; iop/apx: unforgeable tag markers (uninterned) shared by wev -- which emits (iop op . args)
; and (apx nary head . args) nodes -- and ana, which dispatches on them. Top-level globals,
; NOT ev-block locals, so wev's per-global handlers and ana resolve them by name. That keeps
; them out of ev's captured frame (and off every handler's import list: a handler closing over
; a sibling that captured iop/apx would otherwise drag both in dead -- see .wevs).
(: iop (nom 'iop)
   apx (nom 'apx))

; wevs: value->handler memo for global fns, built once by scanning every global. A handler
; folds an application to a value when its args are constant (pure fns only), else emits an
; (iop op . args) node iap inlines (any nif of matching arity), else leaves it. A nif is found
; by thread shape (g_vm_ret0 terminator); fold eligibility from the curated `names`. It lives
; as a global -- wev's fold reaches it by name -- so this ~126-entry table is NOT baked into
; ev's value; `.ev` then prints as just the ana+wev logic, and the table prints under `.wevs`.
(: wevs (:
   g_vm_cur  (peek 0 +)
   g_vm_ret0 (peek 1 A)
   (cval e) (? (symp e) (X 0 0)               ; (const? . value): 1 head iff a literal
               (atomp e) (X 1 e)
               (&& (= (A e) '\) (atomp (BB e))) (X 1 (AB e))
               (X 0 0))
   (bake v) (? (fixp v) v (list '\ v))           ; value -> source: fixnum bare else quote
   ; (op . arity) iff v is a nif. `same` (identity) not `=`: a non-nif global may peek to
   ; a word that looks like a heap pointer, which `=`/eql would deref and crash on.
   (opof v) (? (same g_vm_ret0 (peek 1 v)) (X (peek 0 v) 1)
               (&& (same g_vm_cur (peek 0 v)) (same g_vm_ret0 (peek 3 v))) (X (peek 2 v) (peek 1 v))
               0)
   (hgen v op ar pure x) (: as (B x) n (pin as)
    (go hv a) (? (atomp a) (bake hv)             ; all args constant -> fold
     (: cv (cval (A a))
      (? (&& pure (A cv)) (go (hv (B cv)) (B a))
         (? (&& op (= n ar)) (X iop (X op as))           ; matching-arity nif -> inline
            (&& (< 1 ar) (= n ar)) (X apx (X 1 x))       ; multi-arg fn -> n-ary apply
            (X apx (X 0 x))))))                          ; generic l2r apply
    (go v as))
   names '(+ - * / // mod << >> & | ^
           < <= = >= > same gcd modpow inc dec abs
           X A B AA AB BA BB
           pin lidx assq memq last rev cat
           fixp symp twop mapp lamp strp nilp flop comp atomp
           ssub scat string
           re im conj arg flo com
           sin cos log pow)
   pureset (foldl (\ t s (: v (globals s) (? v (put v 1 t) t))) (hashn 0) names)
   (add t s) (: v (globals s)
    (? (fixp v) t
     (: o (opof v) p (pureset v)
      (? (|| o p)
       (: op (? o (A o) 0)
          ar (? o (B o) (same g_vm_cur (peek 0 v)) (peek 1 v) 0)   ; nif/multi-arg-fn arity
          (put v (\ x (hgen v op ar p x)) t))
       t))))
   (foldl add (hashn 0) (hashk globals))))

(:- (\ x (:
 c (sco 0 (list 0) 0)
 x (wev c x)
 (ana c x (k0 c) 0 0)))
  g_vm_cur (peek 0 +)
  (sco p a i) (put 'par p (put 'imp i (put 'arg a (hashn 0))))
  (rootc c) (? (c 'par) (rootc (c 'par)) c)        ; top scope: where wev stashes 'src
  (p2 i x k) (poke -1 i (poke -1 x k))
  (em1 x k n) (poke -1 x (k (+ 1 n)))
  (em2 i x k n) (poke -1 i (poke -1 x (k (+ 2 n))))
  ; karg/kim: emit an arg ref / a quote, fusing with an immediately-following
  ; 1-ary apply (g_vm_ap) or tail-call (g_vm_tap) that kap already wrote into the
  ; continuation head. The same emit works for both: overwrite that op cell with
  ; the operand (seek 1 keeps what follows -- the rest for ap, the frame-size for
  ; tap) and prepend the fused op; only the handler differs. kap over-reserves a
  ; word, so the reclaimed cell becomes -1 slack (lam memsets it; GC-safe).
  ; operand-value specialization: a zero-operand opcode for the hottest arg indices
  ; / quote constants, emitted in the plain (non-ap/tap) path -- covers arg/quote
  ; consumed by inlined ops, e.g. n in (- n 1). 1-word op, no operand fetch; the
  ; reclaimed operand cell is -1 slack (lam memsets it; GC-safe).
  ; index/value -> specialized-op. A compare chain beats a `get`-hash here: `get`
  ; is a heavyweight polymorphic nif (type-dispatch + hash + eql), costing far more
  ; than a few fixnum compares that short-circuit on the common small values
  ; (measured: a hash made boot +13% vs +5% for this chain; frequency-reordering
  ; the chain was a wash). The fixp guard keeps spq from ever hashing a heap value.
  (spa i) (? (= i 0) g_vm_arg0 (= i 1) g_vm_arg1 (= i 2) g_vm_arg2 (= i 3) g_vm_arg3 0)
  (spq v) (? (fixp v) (? (= v 0) g_vm_quo0 (= v 1) g_vm_quo1 (= v 2) g_vm_quo2
                         (= v 3) g_vm_quo3 (= v -1) g_vm_quom1 (= v -2) g_vm_quom2 0) 0)
  (fuse a o t sp x k n)                          ; a=ap-op o=tap-op(0=none) t=plain-op sp=specializer
   (: tail (k (+ 2 n)) h (peek 0 tail)
    (? (= h g_vm_ap)         (p2 a x (seek 1 tail))
       (&& o (= h g_vm_tap)) (p2 o x (seek 1 tail))
       (: s (sp x) (? s (poke -1 s tail) (p2 t x tail)))))
  ; arg fuses both ap and tap; quote only ap. quote;tap (a constant arg to a tail
  ; call, e.g. (loop 0)) is left unfused: overwriting the shared tap cell in some
  ; emit contexts corrupts a branch's jump target -- safe for arg (a fixnum index)
  ; but not for quote. The rarest of the four cases; deferred.
  (karg x k n) (fuse g_vm_argap   g_vm_argtap g_vm_arg   spa x k n)
  (kim  x k n) (fuse g_vm_quoteap 0           g_vm_quote spq x k n)
  (k0 c n) (poke -1 g_vm_ret (poke (+ 1 n) (ary c) (lam (+ 2 n))))
  ; k0s: like k0 but reserves one extra LEADING cell (so the thread is shifted up
  ; by one) for ala to stash the lambda's source \-expr at value[-1], where the
  ; printer (gzput_fn) finds it. entry = cell 1, src = cell 0.
  (k0s c n) (poke -1 g_vm_ret (poke (+ 2 n) (ary c) (lam (+ 3 n))))
  (ary c) (+ (pin (c 'arg)) (pin (c 'imp)))
  (pro f) (? (fixp f) f (: a (peek 0 f) (?- f
   (= a g_vm_unc) (pro (seek -2 (peek 2 f)))
   (= a g_vm_cur) (?- f (= g_vm_unc (peek 2 f))
                          (pro (seek -2 (peek 4 f)))))))
  ; wev: source->source pre-pass before `ana` -- expands macros, constant-folds, and marks
  ; applies with their n-ary-vs-l2r strategy. Tail position is NOT tracked here -- kap detects
  ; tail by peeking the continuation for g_vm_ret at analysis time.
  (wev c x) (:
   (wx x bnd) (?
    (atomp x) x
    (: h (A x) (?
     (= h '\) (? (atomp (BB x)) x                          ; quote
                (: r (lp x)
                   lam (X '\ (cat (A r) (list (wx (B r) (cat (A r) bnd)))))
                   _ (push c 'src (X (B lam) x))         ; tagged-body -> surface src for ala
                   lam))
     (= h ':) (? (atomp (BB x)) (X ': (list (wx (AB x) bnd)))
                 (X ': (wxl (boxfix (B x)) bnd)))   ; boxfix = letrec* capture-by-location source rewrite, post-macroexpand
     (= h '?) (X '? (wxc (B x) bnd))
     (: m (? (symp h) (macros h) 0)                     ; macro head? expand, then re-walk
      (? m (wx (m (B x)) bnd)
         (fold (map (\ e (wx e bnd)) x) bnd))))))
   (wxl bs bnd) (wxb bs (cat (ln bs) bnd))        ; a let's names all shadow throughout
   (wxb bs bnd) (?
    (atomp bs) bs
    (atomp (B bs)) (list (wx (A bs) bnd))
    (: nd (dsug (A bs) (AB bs))               ; desugar (f a..) so wx's \ adds params to bnd
     (X (A nd) (X (wx (B nd) bnd) (wxb (BB bs) bnd)))))
   (wxc bs bnd) (?                                ; cond clauses (ant con ant con ... else)
    (atomp bs) (list 0)                           ; clauses ran out: supply the implicit 0 else
    (atomp (B bs)) (list (wx (A bs) bnd))
    ; peephole: a FINAL (nilp e) test flips its branches, dropping the wrapper --
    ; (.. (nilp e) con else) == (.. e else con), since the cond tests g_false(e), == nilp(e).
    (&& (twop (BB bs)) (atomp (B (BB bs)))                  ; bs is exactly (ant con else)
        (twop (A bs)) (= (A (A bs)) 'nilp)
        (twop (B (A bs))) (atomp (BB (A bs))) (nilp (memq (A (A bs)) bnd)))
     (X (wx (AB (A bs)) bnd) (X (wx (A (BB bs)) bnd) (list (wx (AB bs) bnd))))
    (X (wx (A bs) bnd) (X (wx (AB bs) bnd) (wxc (BB bs) bnd))))
   ; napof: v is a non-nif multi-arg fn whose arity matches the n>1 call args -> n-ary apply.
   ; `same`-safe peeks (a non-fn value never matches g_vm_cur); mirrors app's old `fa`/`na`.
   (napof v args) (? (fixp v) 0
    (? (same g_vm_cur (peek 0 v)) (: ar (peek 1 v) (&& (< 1 ar) (= (pin args) ar))) 0))
   ; fold: un-shadowed global head -> handler (fold/iop/apx); else mark the call as an apx
   ; node (apx nary head . args) carrying the n-ary-vs-l2r strategy (1 = n-ary, 0 = l2r).
   (fold x bnd) (: h (A x)
    (? (atomp (B x)) x                          ; (f) single element -> ana's (atomp b) handles
       (|| (nilp (symp h)) (memq h bnd)) (X apx (X 0 x))   ; local/computed head
       (: v (globals h) hd (wevs v)
        (? hd (hd x)
           (napof v (B x)) (X apx (X 1 x))
           (X apx (X 0 x))))))
   (wx x 0))
  (ana c x) (? (symp x)  (ava c x)
                   (atomp x) (kim x)
                   (: a (A x) b (B x) (?
                    (atomp b) (ana c a)
                    (= a '? ) (aco c b)
                    (= a '\ ) (? (atomp (B b)) (kim (A b)) (ana c (ala c 0 b)))
                    (= a ': ) (ale c (A b) (B b))
                    (= a iop) (iap c b)
                    (= a apx) (apxh c b)
                    (: m (macros a)
                     (? m (ana c (m b)) (app c a b))))))
  (push c k x) (: _ (put k (X x (c k)) c) x)
  (pop c k) (: x (c k) _ (put k (B x) c) (A x))
  (iap c b) (: op (A b) as (B b)                       ; (iop op . args) -> inline the vm op
   (? (atomp (B as)) (co (ana c (A as)) (em1 op))      ; monadic
      (: s (c 'stk) k (apr2l c as) _ (put 'stk s c) (co k (em1 op))))) ; n-ary, r2l args
  ; apxh: (apx nary head . args) -> apply. nary -> r2l arg eval + a single n-ary apply;
  ; else l2r 1-ary chain. kap detects tail vs non-tail by peeking the continuation.
  (apxh c b) (: nary (A b) head (AB b) args (BB b)
              f (ana c head) s (c 'stk) _ (push c 'stk 0)
              g (? nary (co (apr2l c args) (kap (pin args))) (apl2r c args))
              _ (put 'stk s c)
            (co f g))
  (app c a b) (: f (ana c a)
               s (c 'stk) _ (push c 'stk 0)
               g (apl2r c b) _ (put 'stk s c)
             (co f g))
 (apl2r c b) (?- id (twop b) (: f (ana c (A b)) g (apl2r c (B b))
                    (co f (co (kap 1) g))))
 (apr2l c b) (?- id (twop b) (: g (apr2l c (B b)) f (ana c (A b)) _ (push c 'stk 0) (co g f)))
 (kap n k m)
  (: j (k (+ 2 m))
   t (= (peek 0 j) g_vm_ret)                              ; peek the continuation for ret -> tail
   (? t (? (> n 1) (poke -1 g_vm_tapn (poke 0 n j)) (poke 0 g_vm_tap j))
        (? (> n 1) (p2 g_vm_apn n j) (poke -1 g_vm_ap j))))

  ;aco is a bit complicated
  (aco c b) (:- (: f (acr b) (\ k n (: k (f (co (push c 'end) k) n) _ (pop c 'end) k)))
   (acx k n) (: ; jump out
    j (k (+ 3 n))
    a (A (c 'end))
    i (peek 0 a)
    (? (| (= g_vm_ret i) (= g_vm_tap i)) (p2 i (peek 1 a) j)
       (= g_vm_tapn i)                   (p2 i (peek 1 a) (poke -1 (peek 2 a) j))
                                         (p2 g_vm_jump a j)))
   (acr b) (?
    (atomp b)       (kim 0)
    (atomp (B b)) (co (ana c (A b)) acx)
    (: f (ana c (A b))
       g (ana c (AB b))
       h (acr (BB b))
       (? (= kim (pro f)) (? (peek 3 f) g h)
        (\ x (f (\ n
         (: k (co (push c 'alt) (h x))
            j (g (acx k) (+ 2 n))
            (p2 g_vm_cond (pop c 'alt) j)))))))))

  Z (nom 'Z)
  ; recursive-fn ref: bake `quote code` if the closure is built, else `quote 0`
  ; + a backpatch site `(lfd . cell)` on the scope for l3 to resolve.
  (qsite site k n) (: cell (poke -1 0 (k (+ 2 n)))
                      _ (poke 2 cell site)
                    (poke -1 g_vm_quote cell))
  (lz c lfd scope)(: code (AB lfd)
                   p (? code (em2 g_vm_quote code)
                        (: site (X lfd 0)
                           _ (put 'sites (X site (scope 'sites)) scope)
                         (qsite site)))
                   _ (push c 'stk 0)
                   q (apl2r c (BB lfd))
                   _ (pop c 'stk)
                 (co p q))
  ; variable expression analyzer
  (ava c x)
   (: lfd (assq x (c 'lam))
    (? lfd (lz c lfd c)
       (: s (c 'stk)
          (stki d) (lidx x (cat (d 'imp) (d 'arg)))
          (q i j m) (karg (+ i (stki c)) j m)
        (?- (avb c (c 'par) x)
         (memq x s) (karg (lidx x s))
         (>= (stki c) 0) (q (pin (c 'stk)))))))

  (avb c d x)
   (? (nilp d) ; outside all lexical scopes?
       (: y (get Z x globals) ; check global scope
        (? !(= y Z) (kim y) ; if it's there use that
         (: _ (? (c 'par) (push c 'imp x))
          (em2 g_vm_freev x))))
    (: lfd (assq x (d 'lam))
     (? lfd (lz c lfd d)
        (: s (d 'stk)
           (stki d) (lidx x (cat (d 'imp) (d 'arg)))
           (q i j m) (karg (+ i (stki c)) j m)
         (?- (avb c (d 'par) x)
          (memq x s) (: _ (? (c 'par) (push c 'imp x))
                         (q (pin (c 'stk))))
          (>= (stki d) 0) (: _ (? (c 'par) (push c 'imp x))
                           (q (pin (c 'stk)))))))))
  ; lambda analyzer
  (ala c imp exp) (:
   d (sco c (init exp) imp)
   k (ana d (last exp) (k0s d))
   a (ary d)
   e ((? (= a 1) k (em2 g_vm_cur a k)) 0)           ; entry = cell 1 (cell 0 is the spare src slot)
   ; source \-expr for the printer. take the SURFACE body wev stashed for this node
   ; (keyed by the tagged exp) so iop/apx tags don't leak into the printed source;
   ; fall back to exp if unrecorded. prepend the captured imports as leading params
   ; (frame is [imps args]) so a closure prints as ,((\ y x …) capturedvals) and
   ; round-trips through read+eval.
   os (assq exp ((rootc c) 'src))
   s (X '\ (cat (d 'imp) (? os (BB os) exp)))
   _ (poke -1 s e)                                  ; value[-1] = source \-expr
   _ (trim (seek -1 e))                             ; tag head spans [src .. body]; value stays e
   (X e (d 'imp)))

  ; let expression analyzer (the most complicated one)
  (ale c a b) (?
   (atomp b) (ana c a)
   (:- (l1 0 a (A b) (B b))
    q (sco c (c 'arg) (c 'imp))
    (set_cdr p x) (: _ (poke 2 x p) x) ; :[ weh

   ; l1 collects bindings into a source-order (name . def) pair-list; boxing already
   ; happened in wev (boxfix), so l2 compiles the bindings directly.
   (l1 prs n d rest) (:
     nd (dsug n d)
    (? (atomp rest)       (l2 (rev (X nd prs)) (A nd)   1)
       (atomp (B rest)) (l2 (rev (X nd prs)) (A rest) 0)
                          (l1 (X nd prs) (A rest) (AB rest) (BB rest))))

   (l2 prs body even) (:- (cl 0 l l l)
    s (c 'stk)
    _ (push c 'stk 0)
    (jj a ps) (?
     (atomp ps) a
     (nilp (lambp (BA ps)))
      (:
      _ (push c 'stk (AA ps))
      (jj a (B ps)))
     (: k (AA ps)
        v (ala q 0 (BBA ps))
        a (X (X k v) a)
      _ (push c 'stk k)
      (jj a (B ps))))
    l (jj 0 prs)
    _ (put 'stk s c)
    (cl n l k1 k2) (?
     (&& k1 k2 !(= k1 k2) (memq (AA k1) (BBA k2)))
      (>>= n (BBA k1) (: (kk n v)
       (? (nilp v) (cl n l k1 (B k2))
        (: var (A v)
           vars (BBA k2)
           n (? (memq var vars) n
              (: _ (set_cdr (BA k2) (X var vars))
               (+ 1 n)))
           (kk n (B v))))))
     k2 (cl n l k1 (B k2))
     k1 (cl n l (B k1) l)
     n (cl 0 l l l)
     (l3 prs body even
      (: j (map A l)
         (q x) (X (A x) (X (AB x) (foldl (flip ldel) (BB x) j)))
       (map q l)))))

   (l3 prs body even lams) (:
    (ll nds) (? (nilp nds) id
     (: nd (A nds) n (A nd) d (B nd)
        d (?- d (lambp d) (: qa (assq (A nd) lams)
                             x (ala q (BB qa) (B d))
                           (set_cdr qa x)))
        f (ana c d)
        g (?- id (&& even (nilp (c 'par))) (em2 g_vm_defglob n))
        _ (push c 'stk n)
        h (ll (B nds))
        (\ x (f (g (h x))))))
    _ (put 'lam lams q)
    s (c 'stk)
    _ (push c 'stk 0)
    ; clear stale first-build closures so a ref hit during the rebuild defers to a
    ; backpatch site; the import sets (BB) are kept.
    _ (each lams (\ e (poke 1 0 (B e))))
    g (ll prs)
    ; closures final -> backpatch each recorded recursive-fn ref with its thread.
    _ (each (q 'sites) (\ s (poke 0 (AB (A s)) (B s))))
    _ (put 'sites 0 q)
    _ (put 'stk s c)
    ; body-lambda analyzed AFTER inits (it takes bindings as args; never makes sites)
    f (ana c (X '\ (cat (rev (map A prs)) (list body))))
    h (kap (pin prs))
    _ (put 'stk s c)
    (\ x (f (g (h x))))))))
