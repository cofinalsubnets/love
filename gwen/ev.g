(:- (\ x (:
 c (sco 0 (list 0) 0)
 x (wev c x)
 (ana c x (k0 c) 0 0)))
  g_vm_cur (peek 0 +)
  g_vm_ret0 (peek 1 car)
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
  ; is a heavyweight polymorphic bif (type-dispatch + hash + eql), costing far more
  ; than a few fixnum compares that short-circuit on the common small values
  ; (measured: a hash made boot +13% vs +5% for this chain; frequency-reordering
  ; the chain was a wash). The nump guard keeps spq from ever hashing a heap value.
  (spa i) (? (= i 0) g_vm_arg0 (= i 1) g_vm_arg1 (= i 2) g_vm_arg2 (= i 3) g_vm_arg3 0)
  (spq v) (? (nump v) (? (= v 0) g_vm_quo0 (= v 1) g_vm_quo1 (= v 2) g_vm_quo2
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
  (ary c) (+ (len (c 'arg)) (len (c 'imp)))
  (pro f) (? (nump f) f (: a (peek 0 f) (?- f
   (= a g_vm_unc) (pro (seek -2 (peek 2 f)))
   (= a g_vm_cur) (?- f (= g_vm_unc (peek 2 f))
                          (pro (seek -2 (peek 4 f)))))))
  iop (gensym 'iop)   ; inline-op marker: (iop op . args), emitted by wev, compiled by iap
  apx (gensym 'apx)   ; apply marker: (apx nary head . args), emitted by wev, compiled by apxh
  ; wevs: value->handler for global fns. A handler folds an application to a value when
  ; its args are constant (pure fns only), else emits an (iop op . args) node iap inlines
  ; (any bif of matching arity), else leaves it. Built by scanning every global: a bif is
  ; found by thread shape (g_vm_ret0 terminator); fold eligibility from curated `names`.
  wevs (:
   (cval e) (? (symp e) (cons 0 0)               ; (const? . value): -1 head iff a literal
               (atomp e) (cons -1 e)
               (&& (= (car e) '\) (atomp (cddr e))) (cons -1 (cadr e))
               (cons 0 0))
   (bake v) (? (nump v) v (list '\ v))           ; value -> source: fixnum bare else quote
   ; (op . arity) iff v is a bif. `same` (identity) not `=`: a non-bif global may peek to
   ; a word that looks like a heap pointer, which `=`/eql would deref and crash on.
   (opof v) (? (same g_vm_ret0 (peek 1 v)) (cons (peek 0 v) 1)
               (&& (same g_vm_cur (peek 0 v)) (same g_vm_ret0 (peek 3 v))) (cons (peek 2 v) (peek 1 v))
               0)
   (hgen v op ar pure x) (: as (cdr x) n (len as)
    (go hv a) (? (atomp a) (bake hv)             ; all args constant -> fold
     (: cv (cval (car a))
      (? (&& pure (car cv)) (go (hv (cdr cv)) (cdr a))
         (? (&& op (= n ar)) (cons iop (cons op as))           ; matching-arity bif -> inline
            (&& (< 1 ar) (= n ar)) (cons apx (cons -1 x))      ; multi-arg fn -> n-ary apply
            (cons apx (cons 0 x))))))                          ; generic l2r apply
    (go v as))
   names (list '+ '- '* '/ 'mod '~ '<< '>> '& '| '^
               '< '<= '= '>= '> 'same '** 'gcd 'modpow 'inc 'dec 'abs
               'cons 'car 'cdr 'X 'A 'B 'caar 'cadr 'cdar 'cddr
               'len 'lidx 'assq 'memq 'last 'rev 'cat
               'nump 'symp 'twop 'hashp 'strp 'nilp 'flop 'cplxp 'atomp
               'ssub 'scat 'string
               're 'im 'conj 'arg 'flo 'C
               'sin 'cos 'tan 'atan 'sqrt 'exp 'log 'atan2 'pow)
   pureset (foldl (\ t s (: v (globals s) (? v (put v -1 t) t))) (hashn 0) names)
   (add t s) (: v (globals s)
    (? (nump v) t
     (: o (opof v) p (pureset v)
      (? (|| o p)
       (: op (? o (car o) 0)
          ar (? o (cdr o) (same g_vm_cur (peek 0 v)) (peek 1 v) 0)   ; bif/multi-arg-fn arity
          (put v (\ x (hgen v op ar p x)) t))
       t))))
   (foldl add (hashn 0) (hashk globals)))
  ; wev: source->source pre-pass before `ana` -- expands macros, constant-folds, and marks
  ; applies with their n-ary-vs-l2r strategy. Tail position is NOT tracked here -- kap detects
  ; tail by peeking the continuation for g_vm_ret at analysis time.
  (wev c x) (:
   (wx x bnd) (?
    (atomp x) x
    (: h (car x) (?
     (= h '\) (? (atomp (cddr x)) x                          ; quote
                (: r (lp x)
                   lam (cons '\ (cat (car r) (list (wx (cdr r) (cat (car r) bnd)))))
                   _ (push c 'src (cons (cdr lam) x))         ; tagged-body -> surface src for ala
                   lam))
     (= h ':) (? (atomp (cddr x)) (cons ': (list (wx (cadr x) bnd)))
                 (cons ': (wxl (cdr x) bnd)))
     (= h '?) (cons '? (wxc (cdr x) bnd))
     (: m (? (symp h) (macros h) 0)                     ; macro head? expand, then re-walk
      (? m (wx (m (cdr x)) bnd)
         (fold (map (\ e (wx e bnd)) x) bnd))))))
   (wxl bs bnd) (wxb bs (cat (ln bs) bnd))        ; a let's names all shadow throughout
   (wxb bs bnd) (?
    (atomp bs) bs
    (atomp (cdr bs)) (list (wx (car bs) bnd))
    (: nd (dsug (car bs) (cadr bs))               ; desugar (f a..) so wx's \ adds params to bnd
     (cons (car nd) (cons (wx (cdr nd) bnd) (wxb (cddr bs) bnd)))))
   (wxc bs bnd) (?                                ; cond clauses (ant con ant con ... else)
    (atomp bs) bs
    (atomp (cdr bs)) (list (wx (car bs) bnd))
    (cons (wx (car bs) bnd) (cons (wx (cadr bs) bnd) (wxc (cddr bs) bnd))))
   ; napof: v is a non-bif multi-arg fn whose arity matches the n>1 call args -> n-ary apply.
   ; `same`-safe peeks (a non-fn value never matches g_vm_cur); mirrors app's old `fa`/`na`.
   (napof v args) (? (nump v) 0
    (? (same g_vm_cur (peek 0 v)) (: ar (peek 1 v) (&& (< 1 ar) (= (len args) ar))) 0))
   ; fold: un-shadowed global head -> handler (fold/iop/apx); else mark the call as an apx
   ; node (apx nary head . args) carrying the n-ary-vs-l2r strategy (-1 = n-ary, 0 = l2r).
   (fold x bnd) (: h (car x)
    (? (atomp (cdr x)) x                          ; (f) single element -> ana's (atomp b) handles
       (|| (nilp (symp h)) (memq h bnd)) (cons apx (cons 0 x))   ; local/computed head
       (: v (globals h) hd (wevs v)
        (? hd (hd x)
           (napof v (cdr x)) (cons apx (cons -1 x))
           (cons apx (cons 0 x))))))
   (wx x 0))
  (ana c x) (? (symp x)  (ava c x)
                   (atomp x) (kim x)
                   (: a (car x) b (cdr x) (?
                    (atomp b) (ana c a)
                    (= a '? ) (aco c b)
                    (= a '\ ) (? (atomp (cdr b)) (kim (car b)) (ana c (ala c 0 b)))
                    (= a ': ) (ale c (car b) (cdr b))
                    (= a iop) (iap c b)
                    (= a apx) (apxh c b)
                    (: m (macros a)
                     (? m (ana c (m b)) (app c a b))))))
  (push c k x) (: _ (put k (cons x (c k)) c) x)
  (pop c k) (: x (c k) _ (put k (cdr x) c) (car x))
  (iap c b) (: op (car b) as (cdr b)                       ; (iop op . args) -> inline the vm op
   (? (atomp (cdr as)) (co (ana c (car as)) (em1 op))      ; unary
      (: s (c 'stk) k (apr2l c as) _ (put 'stk s c) (co k (em1 op))))) ; n-ary, r2l args
  ; apxh: (apx nary head . args) -> apply. nary -> r2l arg eval + a single n-ary apply;
  ; else l2r 1-ary chain. kap detects tail vs non-tail by peeking the continuation.
  (apxh c b) (: nary (car b) head (cadr b) args (cddr b)
              f (ana c head) s (c 'stk) _ (push c 'stk 0)
              g (? nary (co (apr2l c args) (kap (len args))) (apl2r c args))
              _ (put 'stk s c)
            (co f g))
  (app c a b) (: f (ana c a)
               s (c 'stk) _ (push c 'stk 0)
               g (apl2r c b) _ (put 'stk s c)
             (co f g))
 (apl2r c b) (?- id (twop b) (: f (ana c (car b)) g (apl2r c (cdr b))
                    (co f (co (kap 1) g))))
 (apr2l c b) (?- id (twop b) (: g (apr2l c (cdr b)) f (ana c (car b)) _ (push c 'stk 0) (co g f)))
 (kap n k m)
  (: j (k (+ 2 m))
   t (= (peek 0 j) g_vm_ret)                              ; peek the continuation for ret -> tail
   (? t (? (> n 1) (poke -1 g_vm_tapn (poke 0 n j)) (poke 0 g_vm_tap j))
        (? (> n 1) (p2 g_vm_apn n j) (poke -1 g_vm_ap j))))

  ;aco is a bit complicated
  (aco c b) (:- (: f (acr b) (\ k n (: k (f (co (push c 'end) k) n) _ (pop c 'end) k)))
   (acx k n) (: ; jump out
    j (k (+ 3 n))
    a (car (c 'end))
    i (peek 0 a)
    (? (| (= g_vm_ret i) (= g_vm_tap i)) (p2 i (peek 1 a) j)
       (= g_vm_tapn i)                   (p2 i (peek 1 a) (poke -1 (peek 2 a) j))
                                         (p2 g_vm_jump a j)))
   (acr b) (?
    (atomp b)       (kim 0)
    (atomp (cdr b)) (co (ana c (car b)) acx)
    (: f (ana c (car b))
       g (ana c (cadr b))
       h (acr (cddr b))
       (? (= kim (pro f)) (? (peek 3 f) g h)
        (\ x (f (\ n
         (: k (co (push c 'alt) (h x))
            j (g (acx k) (+ 2 n))
            (p2 g_vm_cond (pop c 'alt) j)))))))))

  Z (gensym 'Z)
  ; recursive-fn ref: bake `quote code` if the closure is built, else `quote 0`
  ; + a backpatch site `(lfd . cell)` on the scope for l3 to resolve.
  (qsite site k n) (: cell (poke -1 0 (k (+ 2 n)))
                      _ (poke 2 cell site)
                    (poke -1 g_vm_quote cell))
  (lz c lfd scope)(: code (cadr lfd)
                   p (? code (em2 g_vm_quote code)
                        (: site (cons lfd 0)
                           _ (put 'sites (cons site (scope 'sites)) scope)
                         (qsite site)))
                   _ (push c 'stk 0)
                   q (apl2r c (cddr lfd))
                   _ (pop c 'stk)
                 (co p q))
  ; variable expression analyzer
  ; boxof: walk scopes for a boxed name -> its cell sym (the 'box map l2x sets).
  (boxof x s) (? s
   (? (|| (memq x (s 'arg)) (memq x (s 'stk))) 0 ; shadowed by a closer binding
    (: p (assq x (s 'box)) (? p (cdr p) (boxof x (s 'par))))))
  (ava c x)
   (: cell (boxof x c)
    (? cell (ana c (list 'car cell)) ; boxed value ref -> (car cell), at analysis
     (: lfd (assq x (c 'lam))
     (? lfd (lz c lfd c)
        (: s (c 'stk)
           (stki d) (lidx x (cat (d 'imp) (d 'arg)))
           (q i j m) (karg (+ i (stki c)) j m)
         (?- (avb c (c 'par) x)
          (memq x s) (karg (lidx x s))
          (>= (stki c) 0) (q (len (c 'stk)))))))))

  (avb c d x)
   (? (nilp d) ; outside all lexical scopes?
       (: y (get Z x globals) ; check global scope
        (? (!= y Z) (kim y) ; if it's there use that
         (: _ (? (c 'par) (push c 'imp x))
          (em2 g_vm_freev x))))
    (: lfd (assq x (d 'lam))
     (? lfd (lz c lfd d)
        (: s (d 'stk)
           (stki d) (lidx x (cat (d 'imp) (d 'arg)))
           (q i j m) (karg (+ i (stki c)) j m)
         (?- (avb c (d 'par) x)
          (memq x s) (: _ (? (c 'par) (push c 'imp x))
                         (q (len (c 'stk))))
          (>= (stki d) 0) (: _ (? (c 'par) (push c 'imp x))
                           (q (len (c 'stk)))))))))
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
   s (cons '\ (cat (d 'imp) (? os (cddr os) exp)))
   _ (poke -1 s e)                                  ; value[-1] = source \-expr
   _ (trim (seek -1 e))                             ; tag head spans [src .. body]; value stays e
   (cons e (d 'imp)))

  ; bxp: recursive-value boxing for one let's bindings (was prelude `boxprep`),
  ; called by l2x. Prepend a cell per recursively-captured value, rewrite each boxed
  ; (v . init) to (_ . (poke 1 init cell)); the cs name->cell map (cdr) lands on the
  ; scope 'box so `ava` redirects boxed refs to (car cell). Returns (prepped-prs . cs),
  ; or 0 when nothing is boxed. (Being subsumed by `wev` as the design progresses.)
  (bxp prs) (: bx (boxset prs)
   (? (nilp bx) 0
    (: cs (mkcs bx)
       (one p) (? (memq (car p) bx) (cons '_ (list 'poke 1 (cdr p) (cdr (assq (car p) cs)))) p)
     (cons (cat (cellbinds cs) (map one prs)) cs))))

  ; let expression analyzer (the most complicated one)
  (ale c a b) (?
   (atomp b) (ana c a)
   (:- (l1 0 a (car b) (cdr b))
    q (sco c (c 'arg) (c 'imp))
    (set_cdr p x) (: _ (poke 2 x p) x) ; :[ weh

   ; l1 collects bindings into a source-order (name . def) pair-list for l2x.
   (l1 prs n d rest) (:
     nd (dsug n d)
    (? (atomp rest)       (l2x (rev (cons nd prs)) (car nd)   1)
       (atomp (cdr rest)) (l2x (rev (cons nd prs)) (car rest) 0)
                          (l1 (cons nd prs) (car rest) (cadr rest) (cddr rest))))
   ; l2x: native recursive-value boxing. wev returns (cells-prepended-prs . cs)
   ; or 0; the cs name->cell map goes on the scope 'box so ava redirects boxed refs
   ; to (car cell) at analysis (no source rewrite). Body-less lets aren't boxed.
   (l2x prs body even)
    (: r (? even 0 (bxp prs))
       pp (? r (car r) prs)
       old (c 'box)
       _ (? r (put 'box (cat (cdr r) old) c))
       k (l2 pp body even)
       _ (put 'box old c)
     k)

   (l2 prs body even) (:- (cl 0 l l l)
    s (c 'stk)
    _ (push c 'stk 0)
    (jj a ps) (?
     (atomp ps) a
     (nilp (lambp (cdar ps)))
      (:
      _ (push c 'stk (caar ps))
      (jj a (cdr ps)))
     (: k (caar ps)
        v (ala q 0 (cddar ps))
        a (cons (cons k v) a)
      _ (push c 'stk k)
      (jj a (cdr ps))))
    l (jj 0 prs)
    _ (put 'stk s c)
    (cl n l k1 k2) (?
     (&& k1 k2 (!= k1 k2) (memq (caar k1) (cddar k2)))
      (>>= n (cddar k1) (: (kk n v)
       (? (nilp v) (cl n l k1 (cdr k2))
        (: var (car v)
           vars (cddar k2)
           n (? (memq var vars) n
              (: _ (set_cdr (cdar k2) (cons var vars))
               (+ 1 n)))
           (kk n (cdr v))))))
     k2 (cl n l k1 (cdr k2))
     k1 (cl n l (cdr k1) l)
     n (cl 0 l l l)
     (l3 prs body even
      (: j (map car l)
         (q x) (cons (car x) (cons (cadr x) (foldl (flip ldel) (cddr x) j)))
       (map q l)))))

   (l3 prs body even lams) (:
    (ll nds) (? (nilp nds) id
     (: nd (car nds) n (car nd) d (cdr nd)
        d (?- d (lambp d) (: qa (assq (car nd) lams)
                             x (ala q (cddr qa) (cdr d))
                           (set_cdr qa x)))
        f (ana c d)
        g (?- id (&& even (nilp (c 'par))) (em2 g_vm_defglob n))
        _ (push c 'stk n)
        h (ll (cdr nds))
        (\ x (f (g (h x))))))
    _ (put 'lam lams q)
    s (c 'stk)
    _ (push c 'stk 0)
    ; clear stale first-build closures so a ref hit during the rebuild defers to a
    ; backpatch site; the import sets (cddr) are kept.
    _ (each lams (\ e (poke 1 0 (cdr e))))
    g (ll prs)
    ; closures final -> backpatch each recorded recursive-fn ref with its thread.
    _ (each (q 'sites) (\ s (poke 0 (cadr (car s)) (cdr s))))
    _ (put 'sites 0 q)
    _ (put 'stk s c)
    ; body-lambda analyzed AFTER inits (it takes bindings as args; never makes sites)
    f (ana c (cons '\ (cat (rev (map car prs)) (list body))))
    h (kap (len prs))
    _ (put 'stk s c)
    (\ x (f (g (h x))))))))
