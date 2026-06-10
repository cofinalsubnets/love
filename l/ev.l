; iop/apx: unforgeable tag markers (uninterned) shared by wev -- which emits (iop op . args)
; and (apx nary head . args) nodes -- and ana, which dispatches on them. Top-level globals,
; NOT ev-block locals, so wev's per-global aps and ana resolve them by name. That keeps
; them out of ev's captured frame (and off every ap's import list: a ap closing over
; a sibling that captured iop/apx would otherwise drag both in dead -- see .wevs).
(: iop (nom 'iop)
   apx (nom 'apx))

; wevs: value->ap memo for global fns, built once by scanning every global. A ap
; folds an application to a value when its args are constant (pure fns only), else emits an
; (iop op . args) node iap inlines (any nif of matching arity), else leaves it. A nif is found
; by thread shape (g_vm_ret0 terminator); fold eligibility from the curated `names`. It lives
; as a global -- wev's fold reaches it by name -- so this ~126-entry table is NOT baked into
; ev's value; `.ev` then prints as just the ana+wev logic, and the table prints under `.wevs`.
(: wevs (:
   g_vm_cur  (pick 0 (+))
   g_vm_ret0 (pick 1 cap)
   (cval e) (? (symp e) (cons 0 0)               ; (const? . value): 1 head iff a literal
               (atomp e) (cons 1 e)
               (&& (= (cap e) '\) (atomp (cbbp e))) (cons 1 (cabp e))
               (cons 0 0))
   (bake v) (? (fixp v) v (list '\ v))           ; value -> source: fixnum bare else quote
   ; (op . arity) iff v is a nif. `idp` (identity) not `=`: a non-nif global may peep to
   ; a word that looks like a heap pointer, which `=`/eql would deref and crash on.
   (opof v) (? (idp g_vm_ret0 (pick 1 v)) (cons (pick 0 v) 1)
               (&& (idp g_vm_cur (pick 0 v)) (idp g_vm_ret0 (pick 3 v))) (cons (pick 2 v) (pick 1 v))
               0)
   (hgen v op ar pure x) (: as (cbp x) n (sat as)
    (go hv a) (? (atomp a) (bake hv)             ; all args constant -> fold
     (: cv (cval (cap a))
      (? (&& pure (cap cv)) (go (hv (cbp cv)) (cbp a))
         (? (&& op (= n ar)) (cons iop (cons op as))           ; matching-arity nif -> inline
            (&& (< 1 ar) (= n ar)) (cons apx (cons 1 x))       ; multi-arg fn -> n-ary apply
            (cons apx (cons 0 x))))))                          ; generic l2r apply
    (go v as))
   ; the infix table symbols are quoted one by one -- bare mid-list they would
   ; capture their left neighbor at read time.
   names (cat (L '+ '- '* '/ '& '| '< '<= '= '>= '>)
          '(// mod << >> ^
            idp gcd modpow inc dec abs
            cons cap cbp caap cabp cbap cbbp
            digs lidx assq memq last rev cat
            fixp symp twop mapp lamp strp nilp flop comp atomp
            slice scat string
            re im conj arg real plex
            sin cos log pow))
   pureset (foldl (\ t s (: v (dict s) (? v (pin t v 1) t))) (table 0) names)
   (add t s) (: v (dict s)
    (? (fixp v) t
     (: o (opof v) p (pureset v)
      (? (|| o p)
       (: op (? o (cap o) 0)
          ar (? o (cbp o) (idp g_vm_cur (pick 0 v)) (pick 1 v) 0)   ; nif/multi-arg-fn arity
          (pin t v (\ x (hgen v op ar p x))))
       t))))
   (foldl add (table 0) (keys dict))))

(:- (\ x (:
 c (sco 0 (list 0) 0)
 x (wev c x)
 (ana c x (k0 c) 0 0)))
  g_vm_cur (pick 0 (+))
  (sco p a i) (pin (pin (pin (table 0) 'arg a) 'imp i) 'par p)
  (rootc c) (? (c 'par) (rootc (c 'par)) c)        ; top scope: where wev stashes 'src
  (p2 i x k) (knit -1 i (knit -1 x k))
  (em1 x k n) (knit -1 x (k (+ 1 n)))
  (em2 i x k n) (knit -1 i (knit -1 x (k (+ 2 n))))
  ; karg/kim: emit an arg ref / a quote, fusing with an immediately-following
  ; 1-ary apply (g_vm_ap) or tail-call (g_vm_tap) that kap already wrote into the
  ; continuation head. The same emit works for both: overwrite that op cell with
  ; the operand (slip 1 keeps what follows -- the rest for ap, the frame-size for
  ; tap) and prepend the fused op; only the ap differs. kap over-reserves a
  ; word, so the reclaimed cell becomes -1 slack (loom memsets it; GC-safe).
  ; operand-value specialization: a zero-operand opcode for the hottest arg indices
  ; / quote constants, emitted in the plain (non-ap/tap) path -- covers arg/quote
  ; consumed by inlined ops, e.g. n in (- n 1). 1-word op, no operand fetch; the
  ; reclaimed operand cell is -1 slack (loom memsets it; GC-safe).
  ; index/value -> specialized-op. A compare chain beats a `peep`-hash here: `peep`
  ; is a heavyweight polymorphic nif (type-dispatch + hash + eql), costing far more
  ; than a few fixnum compares that short-circuit on the common small values
  ; (measured: a hash made boot +13% vs +5% for this chain; frequency-reordering
  ; the chain was a wash). The fixp guard keeps spq from ever hashing a heap value.
  (spa i) (? (= i 0) g_vm_arg0 (= i 1) g_vm_arg1 (= i 2) g_vm_arg2 (= i 3) g_vm_arg3 0)
  (spq v) (? (fixp v) (? (= v 0) g_vm_quo0 (= v 1) g_vm_quo1 (= v 2) g_vm_quo2
                         (= v 3) g_vm_quo3 (= v -1) g_vm_quom1 (= v -2) g_vm_quom2 0) 0)
  (fuse a o t sp x k n)                          ; a=ap-op o=tap-op(0=none) t=plain-op sp=specializer
   (: tail (k (+ 2 n)) h (pick 0 tail)
    (? (= h g_vm_ap)         (p2 a x (slip 1 tail))
       (&& o (= h g_vm_tap)) (p2 o x (slip 1 tail))
       (: s (sp x) (? s (knit -1 s tail) (p2 t x tail)))))
  ; arg fuses both ap and tap; quote only ap. quote;tap (a constant arg to a tail
  ; call, e.g. (loop 0)) is left unfused: overwriting the shared tap cell in some
  ; emit contexts corrupts a branch's jump target -- safe for arg (a fixnum index)
  ; but not for quote. The rarest of the four cases; deferred.
  (karg x k n) (fuse g_vm_argap   g_vm_argtap g_vm_arg   spa x k n)
  (kim  x k n) (fuse g_vm_quoteap 0           g_vm_quote spq x k n)
  (k0 c n) (knit -1 g_vm_ret (knit (+ 1 n) (ary c) (loom (+ 2 n))))
  ; k0s: like k0 but reserves one extra LEADING cell (so the thread is shifted up
  ; by one) for ala to stash the lambda's source \-expr at value[-1], where the
  ; printer (gzput_fn) finds it. entry = cell 1, src = cell 0.
  (k0s c n) (knit -1 g_vm_ret (knit (+ 2 n) (ary c) (loom (+ 3 n))))
  (ary c) (+ (sat (c 'arg)) (sat (c 'imp)))
  (pro f) (? (fixp f) f (: a (pick 0 f) (?- f
   (= a g_vm_unc) (pro (slip -2 (pick 2 f)))
   (= a g_vm_cur) (?- f (= g_vm_unc (pick 2 f))
                          (pro (slip -2 (pick 4 f)))))))
  ; wev: source->source pre-pass before `ana` -- expands macros, constant-folds, and marks
  ; applies with their n-ary-vs-l2r strategy. Tail position is NOT tracked here -- kap detects
  ; tail by peeking the continuation for g_vm_ret at analysis time.
  (wev c x) (:
   (wx x bnd) (?
    (atomp x) x
    (: h (cap x) (?
     (= h '\) (? (atomp (cbbp x)) x                          ; quote
                (: r (lp x)
                   lam (cons '\ (cat (cap r) (list (wx (cbp r) (cat (cap r) bnd)))))
                   _ (push c 'src (cons (cbp lam) x))         ; tagged-body -> surface src for ala
                   lam))
     (= h ':) (? (atomp (cbbp x)) (cons ': (list (wx (cabp x) bnd)))
                 (cons ': (wxl (boxfix (cbp x)) bnd)))   ; boxfix = letrec* capture-by-location source rewrite, post-macroexpand
     (= h '?) (cons '? (wxc (cbp x) bnd))
     (: m (? (symp h) (macros h) 0)                     ; macro head? expand, then re-walk
      (? m (wx (m (cbp x)) bnd)
         (fold (map (\ e (wx e bnd)) x) bnd))))))
   (wxl bs bnd) (wxb bs (cat (ln bs) bnd))        ; a let's names all shadow throughout
   (wxb bs bnd) (?
    (atomp bs) bs
    (atomp (cbp bs)) (list (wx (cap bs) bnd))
    (: nd (dsug (cap bs) (cabp bs))               ; desugar (f a..) so wx's \ adds params to bnd
     (cons (cap nd) (cons (wx (cbp nd) bnd) (wxb (cbbp bs) bnd)))))
   (wxc bs bnd) (?                                ; cond clauses (ant con ant con ... else)
    (atomp bs) (list 0)                           ; clauses ran out: supply the implicit 0 else
    (atomp (cbp bs)) (list (wx (cap bs) bnd))
    ; peephole: a FINAL (nilp e) test flips its branches, dropping the wrapper --
    ; (.. (nilp e) con else) == (.. e else con), since the cond tests g_false(e), == nilp(e).
    (&& (twop (cbbp bs)) (atomp (cbp (cbbp bs)))                  ; bs is exactly (ant con else)
        (twop (cap bs)) (= (cap (cap bs)) 'nilp)
        (twop (cbp (cap bs))) (atomp (cbbp (cap bs))) (nilp (memq (cap (cap bs)) bnd)))
     (cons (wx (cabp (cap bs)) bnd) (cons (wx (cap (cbbp bs)) bnd) (list (wx (cabp bs) bnd))))
    (cons (wx (cap bs) bnd) (cons (wx (cabp bs) bnd) (wxc (cbbp bs) bnd))))
   ; napof: v is a non-nif multi-arg fn whose arity matches the n>1 call args -> n-ary apply.
   ; `idp`-safe peeps (a non-fn value never matches g_vm_cur); mirrors app's old `fa`/`na`.
   (napof v args) (? (fixp v) 0
    (? (idp g_vm_cur (pick 0 v)) (: ar (pick 1 v) (&& (< 1 ar) (= (sat args) ar))) 0))
   ; fold: un-shadowed global head -> ap (fold/iop/apx); else mark the call as an apx
   ; node (apx nary head . args) carrying the n-ary-vs-l2r strategy (1 = n-ary, 0 = l2r).
   (fold x bnd) (: h (cap x)
    (? (atomp (cbp x)) x                          ; (f) single element -> ana's (atomp b) handles
       (|| (nilp (symp h)) (memq h bnd)) (cons apx (cons 0 x))   ; local/computed head
       (: v (dict h) hd (wevs v)
        (? hd (hd x)
           (napof v (cbp x)) (cons apx (cons 1 x))
           (cons apx (cons 0 x))))))
   (wx x 0))
  (ana c x) (? (symp x)  (ava c x)
                   (atomp x) (kim x)
                   (: a (cap x) b (cbp x) (?
                    (atomp b) (ana c a)
                    (= a '? ) (aco c b)
                    (= a '\ ) (? (atomp (cbp b)) (kim (cap b)) (ana c (ala c 0 b)))
                    (= a ': ) (ale c (cap b) (cbp b))
                    (= a iop) (iap c b)
                    (= a apx) (apxh c b)
                    (: m (macros a)
                     (? m (ana c (m b)) (app c a b))))))
  (push c k x) (: _ (pin c k (cons x (c k))) x)
  (pop c k) (: x (c k) _ (pin c k (cbp x)) (cap x))
  (iap c b) (: op (cap b) as (cbp b)                       ; (iop op . args) -> inline the vm op
   (? (atomp (cbp as)) (co (ana c (cap as)) (em1 op))      ; monadic
      (: s (c 'stk) k (apr2l c as) _ (pin c 'stk s) (co k (em1 op))))) ; n-ary, r2l args
  ; apxh: (apx nary head . args) -> apply. nary -> r2l arg eval + a single n-ary apply;
  ; else l2r 1-ary chain. kap detects tail vs non-tail by peeking the continuation.
  (apxh c b) (: nary (cap b) head (cabp b) args (cbbp b)
              f (ana c head) s (c 'stk) _ (push c 'stk 0)
              g (? nary (co (apr2l c args) (kap (sat args))) (apl2r c args))
              _ (pin c 'stk s)
            (co f g))
  (app c a b) (: f (ana c a)
               s (c 'stk) _ (push c 'stk 0)
               g (apl2r c b) _ (pin c 'stk s)
             (co f g))
 (apl2r c b) (?- id (twop b) (: f (ana c (cap b)) g (apl2r c (cbp b))
                    (co f (co (kap 1) g))))
 (apr2l c b) (?- id (twop b) (: g (apr2l c (cbp b)) f (ana c (cap b)) _ (push c 'stk 0) (co g f)))
 (kap n k m)
  (: j (k (+ 2 m))
   t (= (pick 0 j) g_vm_ret)                              ; peep the continuation for ret -> tail
   (? t (? (> n 1) (knit -1 g_vm_tapn (knit 0 n j)) (knit 0 g_vm_tap j))
        (? (> n 1) (p2 g_vm_apn n j) (knit -1 g_vm_ap j))))

  ;aco is a bit complicated
  (aco c b) (:- (: f (acr b) (\ k n (: k (f (co (push c 'end) k) n) _ (pop c 'end) k)))
   (acx k n) (: ; jump out
    j (k (+ 3 n))
    a (cap (c 'end))
    i (pick 0 a)
    (? (| (= g_vm_ret i) (= g_vm_tap i)) (p2 i (pick 1 a) j)
       (= g_vm_tapn i)                   (p2 i (pick 1 a) (knit -1 (pick 2 a) j))
                                         (p2 g_vm_jump a j)))
   (acr b) (?
    (atomp b)       (kim 0)
    (atomp (cbp b)) (co (ana c (cap b)) acx)
    (: f (ana c (cap b))
       g (ana c (cabp b))
       h (acr (cbbp b))
       (? (= kim (pro f)) (? (pick 3 f) g h)
        (\ x (f (\ n
         (: k (co (push c 'alt) (h x))
            j (g (acx k) (+ 2 n))
            (p2 g_vm_cond (pop c 'alt) j)))))))))

  Z (nom 'Z)
  ; recursive-fn ref: bake `quote code` if the closure is built, else `quote 0`
  ; + a backpatch site `(lfd . cell)` on the scope for l3 to resolve.
  (qsite site k n) (: cell (knit -1 0 (k (+ 2 n)))
                      _ (knit 2 cell site)
                    (knit -1 g_vm_quote cell))
  (lz c lfd scope)(: code (cabp lfd)
                   p (? code (em2 g_vm_quote code)
                        (: site (cons lfd 0)
                           _ (pin scope 'sites (cons site (scope 'sites)))
                         (qsite site)))
                   _ (push c 'stk 0)
                   q (apl2r c (cbbp lfd))
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
         (>= (stki c) 0) (q (sat (c 'stk)))))))

  (avb c d x)
   (? (nilp d) ; outside all lexical scopes?
       (: y (peep dict x Z) ; check global scope
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
                         (q (sat (c 'stk))))
          (>= (stki d) 0) (: _ (? (c 'par) (push c 'imp x))
                           (q (sat (c 'stk)))))))))
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
   s (cons '\ (cat (d 'imp) (? os (cbbp os) exp)))
   _ (knit -1 s e)                                  ; value[-1] = source \-expr
   _ (trim (slip -1 e))                             ; tag head spans [src .. body]; value stays e
   (cons e (d 'imp)))

  ; let expression analyzer (the most complicated one)
  (ale c a b) (?
   (atomp b) (ana c a)
   (:- (l1 0 a (cap b) (cbp b))
    q (sco c (c 'arg) (c 'imp))
    (set_cdr p x) (: _ (knit 2 x p) x) ; :[ weh

   ; l1 collects bindings into a source-order (name . def) pair-list; boxing already
   ; happened in wev (boxfix), so l2 compiles the bindings directly.
   (l1 prs n d rest) (:
     nd (dsug n d)
    (? (atomp rest)       (l2 (rev (cons nd prs)) (cap nd)   1)
       (atomp (cbp rest)) (l2 (rev (cons nd prs)) (cap rest) 0)
                          (l1 (cons nd prs) (cap rest) (cabp rest) (cbbp rest))))

   (l2 prs body even) (:- (cl 0 l l l)
    s (c 'stk)
    _ (push c 'stk 0)
    (jj a ps) (?
     (atomp ps) a
     (nilp (lambp (cbap ps)))
      (:
      _ (push c 'stk (caap ps))
      (jj a (cbp ps)))
     (: k (caap ps)
        v (ala q 0 (cbbap ps))
        a (cons (cons k v) a)
      _ (push c 'stk k)
      (jj a (cbp ps))))
    l (jj 0 prs)
    _ (pin c 'stk s)
    (cl n l k1 k2) (?
     (&& k1 k2 !(= k1 k2) (memq (caap k1) (cbbap k2)))
      (>>= n (cbbap k1) (: (kk n v)
       (? (nilp v) (cl n l k1 (cbp k2))
        (: var (cap v)
           vars (cbbap k2)
           n (? (memq var vars) n
              (: _ (set_cdr (cbap k2) (cons var vars))
               (+ 1 n)))
           (kk n (cbp v))))))
     k2 (cl n l k1 (cbp k2))
     k1 (cl n l (cbp k1) l)
     n (cl 0 l l l)
     (l3 prs body even
      (: j (map cap l)
         (q x) (cons (cap x) (cons (cabp x) (foldl (flip ldel) (cbbp x) j)))
       (map q l)))))

   (l3 prs body even lams) (:
    (lnk nds) (? (nilp nds) id
     (: nd (cap nds) n (cap nd) d (cbp nd)
        d (?- d (lambp d) (: qa (assq (cap nd) lams)
                             x (ala q (cbbp qa) (cbp d))
                           (set_cdr qa x)))
        f (ana c d)
        g (?- id (&& even (nilp (c 'par))) (em2 g_vm_defglob n))
        _ (push c 'stk n)
        h (lnk (cbp nds))
        (\ x (f (g (h x))))))
    _ (pin q 'lam lams)
    s (c 'stk)
    _ (push c 'stk 0)
    ; clear stale first-build closures so a ref hit during the rebuild defers to a
    ; backpatch site; the import sets (BB) are kept.
    _ (each lams (\ e (knit 1 0 (cbp e))))
    g (lnk prs)
    ; closures final -> backpatch each recorded recursive-fn ref with its thread.
    _ (each (q 'sites) (\ s (knit 0 (cabp (cap s)) (cbp s))))
    _ (pin q 'sites 0)
    _ (pin c 'stk s)
    ; body-lambda analyzed AFTER inits (it takes bindings as args; never makes sites)
    f (ana c (cons '\ (cat (rev (map cap prs)) (list body))))
    h (kap (sat prs))
    _ (pin c 'stk s)
    (\ x (f (g (h x))))))))
