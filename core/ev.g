(:- (\ x (: c (sco 0 (list 0) 0) (ana c x (k0 c) 0 0)))
  g_vm_cur (peek 0 +)
  g_vm_ret0 (peek 1 car)
  (sco p a i) (put 'par p (put 'imp i (put 'arg a (new 0))))
  (p2 i x k) (poke -1 i (poke -1 x k))
  (em1 x k n) (poke -1 x (k (+ 1 n)))
  (em2 i x k n) (poke -1 i (poke -1 x (k (+ 2 n))))
  (k0 c n) (poke -1 g_vm_ret (poke (+ 1 n) (ary c) (thd (+ 2 n))))
  (ary c) (+ (len (get 0 'arg c)) (len (get 0 'imp c)))
  (pro f) (? (nump f) f (: a (peek 0 f) (?- f
   (= a g_vm_unc) (pro (seek -2 (peek 2 f)))
   (= a g_vm_cur) (?- f (= g_vm_unc (peek 2 f))
                          (pro (seek -2 (peek 4 f)))))))
  (kim x k n) (poke -1 g_vm_quote (poke -1 x (k (+ 2 n))))
  (ana c x) (:- (? (symp x)  (ava x)
                   (atomp x) (kim x)
                   (: a (car x) b (cdr x) (?
                    (atomp b) (ana c a)
                    (= a '. ) (kim (car b))
                    (= a '? ) (aco b)
                    (= a '\ ) (ana c (? (atomp (cdr b)) (car b) (ala c 0 b)))
                    (= a ': ) (ale (car b) (cdr b))
                    (: m (get 0 a macros)
                     (? m (ana c (m b)) (app a b))))))
  (push k x) (: _ (put k (cons x (get 0 k c)) c) x)
  (pop k) (: x (get 0 k c) _ (put k (cdr x) c) (car x))
  (app a b) (: f (ana c a) ; analyze function expression
               ca (len b)                                  ; call arity
               i (? (= kim (pro f)) (peek 3 f))
               i (? (nump i) 0 i)
               fa (? (nump i) 1 (!= g_vm_cur (peek 0 i)) 1 (peek 1 i)) ; function arity
               ub (&& i (= 1 ca) (= g_vm_ret0 (peek 1 i))) ; unary bif?
               na (&& (< 1 ca) (= ca fa))                  ; n-ary ap?
               nb (&& na (= g_vm_ret0 (peek 3 i)))         ; n-ary bif?
               s (get 0 'stk c)                            ; get original stack
               (? ub (co (ana c (A b)) (em1 (peek 0 i)))   ; unary bif
                  nb (: k (apr2l b) _ (put 'stk s c)
                      (co k (em1 (peek 2 i))))             ; n-ary bif
                (: _ (push 'stk 0)                         ; stack rep of analyzed function f
                   g (? na (co (apr2l b) (kap ca)) (apl2r b)) ; r2l or l2r?
                   _ (put 'stk s c)                        ; put original stack
                 (co f g))))
 (apl2r b) (?- id (twop b) (: f (ana c (car b)) g (apl2r (cdr b)) (co f (co (kap 1) g))))
 (apr2l b) (?- id (twop b) (: g (apr2l (cdr b)) f (ana c (car b)) _ (push 'stk 0) (co g f)))
 (kap n k m)
  (: j (k (+ 2 m))
   (? (= (peek 0 j) g_vm_ret)
    (? (> n 1) (poke -1 g_vm_tapn (poke 0 n j)) (poke 0 g_vm_tap j))
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
  (lz lfd)(: p (em2 g_vm_lazyb lfd)
               _ (push 'stk 0)
               q (apl2r (cddr lfd))
               _ (pop 'stk)
             (co p q))
  ; variable expression analyzer
  (ava x)
   (: lfd (assq x (get 0 'lam c))
     (? lfd (lz lfd)
        (: s (get 0 'stk c)
           (stki d) (lidx x (cat (get 0 'imp d) (get 0 'arg d)))
           (q i j m) (: k (j (+ 2 m)) (p2 g_vm_arg (+ i (stki c)) k))
         (?- (avb (get 0 'par c) x)
          (memq x s) (em2 g_vm_arg (lidx x s))
          (>= (stki c) 0) (q (len (get 0 'stk c)))))))

  (avb d x)
   (? (nilp d) ; outside all lexical scopes?
       (: y (get Z x globals) ; check global scope
        (? (!= y Z) (kim y) ; if it's there use that
         (: _ (? (get 0 'par c) (push 'imp x))
          (em2 g_vm_freev x))))
    (: lfd (assq x (get 0 'lam d))
     (? lfd (lz lfd)
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
   k (ana d (last exp) (k0 d))
   a (ary d)
   k (trim ((? (= a 1) k (em2 g_vm_cur a k)) 0))
   (cons k (get 0 'imp d)))

  ; let expression analyzer (the most complicated one)
  (ale a b) (?
   (atomp b) (ana c a)
   (:- (l1 0 0 a (car b) (cdr b))
    q (sco c (get 0 'arg c) (get 0 'imp c))
    (set_cdr p x) (: _ (poke 2 x p) x) ; :[ weh

    ;; l1 collects bindings and passes them with the body expression to l2x
   (l1 ns ds n d rest) (:
     nd (dsug n d) ns (cons (car nd) ns) ds (cons (cdr nd) ds)
    (? (atomp rest)       (l2x ns ds (car nd)   1)
       (atomp (cdr rest)) (l2x ns ds (car rest) 0)
                          (l1 ns ds (car rest) (cadr rest) (cddr rest))))
   ; l2x delegates recursive-value boxing to the shared prelude `boxfix` (the
   ; same rewrite c0 runs -- single source of truth). It flattens the collected
   ; bindings + body back into a `:`-style list, boxes, then re-splits for l2.
   ; even (global, body-less) lets are never boxed, so they skip the round-trip.
   (l2x ns ds exp even) (?
    even (l2 ns ds exp even)
    (: fs (boxfix (cat (catmap (\ p (list (car p) (cdr p)))
                               (zip (rev ns) (rev ds)))
                       (list exp)))
       (splt l) (? (atomp (cdr l)) (cons 0 (car l))
                   (: r (splt (cddr l))
                      (cons (cons (cons (car l) (cadr l)) (car r)) (cdr r))))
       pb (splt fs)
     (l2 (rev (map car (car pb))) (rev (map cdr (car pb))) (cdr pb) even)))

   (l2 ns ds exp even) (:- (cl 0 l l l)
    ns (rev ns) ds (rev ds)
    s (get 0 'stk c)
    _ (push 'stk 0)
    (jj a n d) (?
     (atomp n) a
     (nilp (lambp (car d)))
      (:
      _ (push 'stk (car n))
      (jj a (cdr n) (cdr d)))
     (: k (car n)
        v (ala q 0 (cdar d))
        a (cons (cons k v) a)
      _ (push 'stk k)
      (jj a (cdr n) (cdr d))))
    l (jj 0 ns ds)
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
     (l3 ns ds exp even
      (: j (map car l)
         (q x) (cons (car x) (cons (cadr x) (foldl (flip ldel) (cddr x) j)))
       (map q l)))))

   (l3 ns ds exp even lams) (:
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
    f (ana c (cons '\ (cat (rev ns) (list exp))))
    _ (push 'stk 0)
    g (ll (zip ns ds))
    h (kap (len ns))
    _ (put 'stk s c)
    (\ x (f (g (h x)))))))))
