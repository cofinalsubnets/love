(:- (\ x (:
 c (sco 0 (list 0) 0)
 x (wev c x)
 (ana c x (k0 c) 0 0)))
  g_vm_cur (peek 0 +)
  g_vm_ret0 (peek 1 car)
  (sco p a i) (put 'par p (put 'imp i (put 'arg a (new 0))))
  (p2 i x k) (poke -1 i (poke -1 x k))
  (em1 x k n) (poke -1 x (k (+ 1 n)))
  (em2 i x k n) (poke -1 i (poke -1 x (k (+ 2 n))))
  (k0 c n) (poke -1 g_vm_ret (poke (+ 1 n) (ary c) (thd (+ 2 n))))
  ; k0s: like k0 but reserves one extra LEADING cell (so the thread is shifted up
  ; by one) for ala to stash the lambda's source \-expr at value[-1], where the
  ; printer (gzput_fn) finds it. entry = cell 1, src = cell 0.
  (k0s c n) (poke -1 g_vm_ret (poke (+ 2 n) (ary c) (thd (+ 3 n))))
  (ary c) (+ (len (get 0 'arg c)) (len (get 0 'imp c)))
  (pro f) (? (nump f) f (: a (peek 0 f) (?- f
   (= a g_vm_unc) (pro (seek -2 (peek 2 f)))
   (= a g_vm_cur) (?- f (= g_vm_unc (peek 2 f))
                          (pro (seek -2 (peek 4 f)))))))
  (kim x k n) (poke -1 g_vm_quote (poke -1 x (k (+ 2 n))))
  iop (sym 0)   ; inline-op marker: (iop op . args), emitted by wev, compiled by iap
  apx (sym 0)   ; apply marker: (apx tail nary head . args), emitted by wev, compiled by apxh
  auto (sym 0)  ; kap tail sentinel: detect tail by peeking (ana-internal applies that bypass wev)
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
   (hgen v op ar pure x tail) (: as (cdr x) n (len as)
    (go hv a) (? (atomp a) (bake hv)             ; all args constant -> fold
     (: cv (cval (car a))
      (? (&& pure (car cv)) (go (hv (cdr cv)) (cdr a))
         (? (&& op (= n ar)) (cons iop (cons op as))                  ; matching-arity bif -> inline
            (&& (< 1 ar) (= n ar)) (cons apx (cons tail (cons -1 x))) ; multi-arg fn -> n-ary apply
            (cons apx (cons tail (cons 0 x)))))))                     ; generic l2r apply
    (go v as))
   names (list '+ '- '* '/ '% '~ '<< '>> '& '| '^
               '< '<= '= '>= '> 'same '** 'gcd 'modpow 'inc 'dec 'abs
               'cons 'car 'cdr 'X 'A 'B 'caar 'cadr 'cdar 'cddr
               'len 'lidx 'assq 'memq 'last 'rev 'cat
               'nump 'symp 'twop 'tblp 'strp 'nilp 'flop 'cplxp 'atomp
               'ssub 'scat 'str 'nom
               're 'im 'conj 'arg 'flo 'cplx
               'sin 'cos 'tan 'atan 'sqrt 'exp 'log 'atan2 'pow)
   pureset (foldl (\ t s (: v (get 0 s globals) (? v (put v -1 t) t))) (new 0) names)
   (add t s) (: v (get 0 s globals)
    (? (nump v) t
     (: o (opof v) p (get 0 v pureset)
      (? (|| o p)
       (: op (? o (car o) 0)
          ar (? o (cdr o) (same g_vm_cur (peek 0 v)) (peek 1 v) 0)   ; bif/multi-arg-fn arity
          (put v (\ x tail (hgen v op ar p x tail)) t))
       t))))
   (foldl add (new 0) (tkeys globals)))
  ; wev: source->source pre-pass before `ana` -- expands macros, constant-folds, and marks
  ; applies with their strategy + tail position (threaded as `tail`, -1 = tail). `\`/`:`/`?`
  ; set tail for sub-exprs; quotes are left as-is. ana reads tail off the emitted apx nodes.
  (wev c x) (:
   (wx x bnd tail) (?
    (atomp x) x
    (: h (car x) (?
     (= h '\) (? (atomp (cddr x)) x                          ; quote
                (: r (lp x) (cons '\ (cat (car r) (list (wx (cdr r) (cat (car r) bnd) -1)))))) ; body is tail
     (= h ':) (? (atomp (cddr x)) (cons ': (list (wx (cadr x) bnd tail))) ; (: a) no frame -> inherits
                 (cons ': (wxl (cdr x) bnd)))                 ; framed let: body is a body-lambda body
     (= h '?) (cons '? (wxc (cdr x) bnd tail))                ; cond: branches inherit tail
     (: m (? (symp h) (get 0 h macros) 0)                     ; macro head? expand, then re-walk
      (? m (wx (m (cdr x)) bnd tail)
         (fold (map (\ e (wx e bnd 0)) x) bnd tail))))))      ; args non-tail; the call inherits tail
   (wxl bs bnd) (wxb bs (cat (ln bs) bnd))        ; a let's names all shadow throughout
   (wxb bs bnd) (?
    (atomp bs) bs
    (atomp (cdr bs)) (list (wx (car bs) bnd -1))  ; lone body -> body-lambda body -> tail
    (: nd (dsug (car bs) (cadr bs))               ; desugar (f a..) so wx's \ adds params to bnd
     (cons (car nd) (cons (wx (cdr nd) bnd 0) (wxb (cddr bs) bnd)))))  ; binding value -> non-tail
   (wxc bs bnd tail) (?                           ; cond clauses (ant con ant con ... else)
    (atomp bs) bs
    (atomp (cdr bs)) (list (wx (car bs) bnd tail))                    ; lone else -> tail
    (cons (wx (car bs) bnd 0) (cons (wx (cadr bs) bnd tail) (wxc (cddr bs) bnd tail))))
   ; napof: v is a non-bif multi-arg fn whose arity matches the n>1 call args -> n-ary apply.
   ; `same`-safe peeks (a non-fn value never matches g_vm_cur); mirrors app's old `fa`/`na`.
   (napof v args) (? (nump v) 0
    (? (same g_vm_cur (peek 0 v)) (: ar (peek 1 v) (&& (< 1 ar) (= (len args) ar))) 0))
   ; fold: un-shadowed global head -> handler (fold/iop/apx); else mark the call as an apx
   ; node (apx tail nary head . args) carrying tail position + n-ary-vs-l2r strategy.
   (fold x bnd tail) (: h (car x)
    (? (atomp (cdr x)) x                          ; (f) single element -> ana's (atomp b) handles
       (|| (nilp (symp h)) (memq h bnd)) (cons apx (cons tail (cons 0 x)))   ; local/computed head
       (: v (get 0 h globals) hd (get 0 v wevs)
        (? hd (hd x tail)
           (napof v (cdr x)) (cons apx (cons tail (cons -1 x)))
           (cons apx (cons tail (cons 0 x)))))))
   (wx x 0 -1))
  (ana c x) (:- (? (symp x)  (ava x)
                   (atomp x) (kim x)
                   (: a (car x) b (cdr x) (?
                    (atomp b) (ana c a)
                    (= a '? ) (aco b)
                    (= a '\ ) (? (atomp (cdr b)) (kim (car b)) (ana c (ala c 0 b)))
                    (= a ': ) (ale (car b) (cdr b))
                    (= a iop) (iap b)
                    (= a apx) (apxh b)
                    (: m (get 0 a macros)
                     (? m (ana c (m b)) (app a b))))))
  (push k x) (: _ (put k (cons x (get 0 k c)) c) x)
  (pop k) (: x (get 0 k c) _ (put k (cdr x) c) (car x))
  (iap b) (: op (car b) as (cdr b)                         ; (iop op . args) -> inline the vm op
   (? (atomp (cdr as)) (co (ana c (car as)) (em1 op))      ; unary
      (: s (get 0 'stk c) k (apr2l as) _ (put 'stk s c) (co k (em1 op))))) ; n-ary, r2l args
  ; apxh: (apx tail nary head . args) -> apply. nary -> r2l arg eval + a single n-ary apply;
  ; else l2r 1-ary chain. tail (from wev) drives tap/tapn vs ap/apn in kap.
  (apxh b) (: tl (car b) nary (cadr b) head (caddr b) args (cdddr b)
              f (ana c head) s (get 0 'stk c) _ (push 'stk 0)
              g (? nary (co (apr2l args) (kap tl (len args))) (apl2r tl args))
              _ (put 'stk s c)
            (co f g))
  (app a b) (: f (ana c a)                                 ; bare apply (ana-internal): tail auto-detect
               s (get 0 'stk c) _ (push 'stk 0)
               g (apl2r auto b) _ (put 'stk s c)
             (co f g))
 (apl2r tail b) (?- id (twop b) (: f (ana c (car b)) g (apl2r tail (cdr b))
                    (co f (co (kap (? (nilp (cdr b)) tail 0) 1) g))))  ; only the last apply is tail
 (apr2l b) (?- id (twop b) (: g (apr2l (cdr b)) f (ana c (car b)) _ (push 'stk 0) (co g f)))
 (kap tail n k m)
  (: j (k (+ 2 m))
   t (? (same tail auto) (= (peek 0 j) g_vm_ret) tail)    ; auto -> peek the continuation for ret
   (? t (? (> n 1) (poke -1 g_vm_tapn (poke 0 n j)) (poke 0 g_vm_tap j))
        (? (> n 1) (p2 g_vm_apn n j) (poke -1 g_vm_ap j))))

  ;aco is a bit complicated
  (aco b) (:- (: f (acr b) (\ k n (: k (f (co (push 'end) k) n) _ (pop 'end) k)))
   (acx k n) (: ; jump out
    j (k (+ 3 n))
    a (car (get 0 'end c))
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
         (: k (co (push 'alt) (h x))
            j (g (acx k) (+ 2 n))
            (p2 g_vm_cond (pop 'alt) j)))))))))

  Z (sym 0)
  ; recursive-fn ref: bake `quote code` if the closure is built, else `quote 0`
  ; + a backpatch site `(lfd . cell)` on the scope for l3 to resolve.
  (qsite site k n) (: cell (poke -1 0 (k (+ 2 n)))
                      _ (poke 2 cell site)
                    (poke -1 g_vm_quote cell))
  (lz lfd scope)(: code (cadr lfd)
                   p (? code (em2 g_vm_quote code)
                        (: site (cons lfd 0)
                           _ (put 'sites (cons site (get 0 'sites scope)) scope)
                         (qsite site)))
                   _ (push 'stk 0)
                   q (apl2r auto (cddr lfd))
                   _ (pop 'stk)
                 (co p q))
  ; variable expression analyzer
  ; boxof: walk scopes for a boxed name -> its cell sym (the 'box map l2x sets).
  (boxof x s) (? s
   (? (|| (memq x (get 0 'arg s)) (memq x (get 0 'stk s))) 0 ; shadowed by a closer binding
    (: p (assq x (get 0 'box s)) (? p (cdr p) (boxof x (get 0 'par s))))))
  (ava x)
   (: cell (boxof x c)
    (? cell (ana c (list 'car cell)) ; boxed value ref -> (car cell), at analysis
     (: lfd (assq x (get 0 'lam c))
     (? lfd (lz lfd c)
        (: s (get 0 'stk c)
           (stki d) (lidx x (cat (get 0 'imp d) (get 0 'arg d)))
           (q i j m) (: k (j (+ 2 m)) (p2 g_vm_arg (+ i (stki c)) k))
         (?- (avb (get 0 'par c) x)
          (memq x s) (em2 g_vm_arg (lidx x s))
          (>= (stki c) 0) (q (len (get 0 'stk c)))))))))

  (avb d x)
   (? (nilp d) ; outside all lexical scopes?
       (: y (get Z x globals) ; check global scope
        (? (!= y Z) (kim y) ; if it's there use that
         (: _ (? (get 0 'par c) (push 'imp x))
          (em2 g_vm_freev x))))
    (: lfd (assq x (get 0 'lam d))
     (? lfd (lz lfd d)
        (: s (get 0 'stk d)
           (stki d) (lidx x (cat (get 0 'imp d) (get 0 'arg d)))
           (q i j m) (: k (j (+ 2 m)) (p2 g_vm_arg (+ i (stki c)) k))
         (?- (avb (get 0 'par d) x)
          (memq x s) (: _ (? (get 0 'par c) (push 'imp x))
                         (q (len (get 0 'stk c))))
          (>= (stki d) 0) (: _ (? (get 0 'par c) (push 'imp x))
                           (q (len (get 0 'stk c)))))))))
  ; lambda analyzer
  (ala c imp exp) (:
   d (sco c (init exp) imp)
   s (cons '\ exp)                                  ; source \-expr (built before GC-y thread alloc)
   k (ana d (last exp) (k0s d))
   a (ary d)
   e ((? (= a 1) k (em2 g_vm_cur a k)) 0)           ; entry = cell 1 (cell 0 is the spare src slot)
   _ (poke -1 s e)                                  ; value[-1] = source \-expr
   _ (trim (seek -1 e))                             ; tag head spans [src .. body]; value stays e
   (cons e (get 0 'imp d)))

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
  (ale a b) (?
   (atomp b) (ana c a)
   (:- (l1 0 a (car b) (cdr b))
    q (sco c (get 0 'arg c) (get 0 'imp c))
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
       old (get 0 'box c)
       _ (? r (put 'box (cat (cdr r) old) c))
       k (l2 pp body even)
       _ (put 'box old c)
     k)

   (l2 prs body even) (:- (cl 0 l l l)
    s (get 0 'stk c)
    _ (push 'stk 0)
    (jj a ps) (?
     (atomp ps) a
     (nilp (lambp (cdar ps)))
      (:
      _ (push 'stk (caar ps))
      (jj a (cdr ps)))
     (: k (caar ps)
        v (ala q 0 (cddar ps))
        a (cons (cons k v) a)
      _ (push 'stk k)
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
        g (?- id (&& even (nilp (get 0 'par c))) (em2 g_vm_defglob n))
        _ (push 'stk n)
        h (ll (cdr nds))
        (\ x (f (g (h x))))))
    _ (put 'lam lams q)
    s (get 0 'stk c)
    _ (push 'stk 0)
    ; clear stale first-build closures so a ref hit during the rebuild defers to a
    ; backpatch site; the import sets (cddr) are kept.
    _ (each lams (\ e (poke 1 0 (cdr e))))
    g (ll prs)
    ; closures final -> backpatch each recorded recursive-fn ref with its thread.
    _ (each (get 0 'sites q) (\ s (poke 0 (cadr (car s)) (cdr s))))
    _ (put 'sites 0 q)
    _ (put 'stk s c)
    ; body-lambda analyzed AFTER inits (it takes bindings as args; never makes sites)
    f (ana c (cons '\ (cat (rev (map car prs)) (list body))))
    h (kap auto (len prs))
    _ (put 'stk s c)
    (\ x (f (g (h x)))))))))
