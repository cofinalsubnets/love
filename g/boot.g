(: egg '(
  ; these are all data and function definitions
  (: (co f g x) (f (g x))
     (id x) x
     (const x _) x
     (flip f x y) (f y x))
  (: pi 3.141592653589793
     true -1 false 0 not nilp
     (atomp x) (nilp (twop x))
     (!= a b) (? (= a b) 0 -1)
     AA (co A A) AB (co A B)
     BA (co B A) BB (co B B))
  (: AAA (co A AA) AAB (co A AB)
     ABA (co A BA) ABB (co A BB)
     BAA (co B AA) BAB (co B AB)
     BBA (co B BA) BBB (co B BB))
  (: cons X car A cdr B
     caar AA cadr AB cdar BA cddr BB
     caaar AAA caadr AAB
     cadar ABA caddr ABB
     cdaar BAA cdadr BAB
     cddar BBA cdddr BBB
     inc (+ 1) dec (+ -1) (:: a b) (put a b macros)
     putc (fputc out)
     puts (fputs out)
     putn (fputn out)
     (getc _) (fgetc in)
     read (fread in))
  (: (map f l) (? (twop l) (cons (f (car l)) (map f (cdr l))))
     (foldl f z l) (? (twop l) (foldl f (f z (car l)) (cdr l)) z)
     (foldr f z l) (? (twop l) (f (car l) (foldr f z (cdr l))) z))
  (: (foldl1 f l) (foldl f (car l) (cdr l))
     (foldr1 f l) (foldr f (last l) (init l))
     ap (foldl id)
     (filter p l) (? (twop l) (: m (filter p (cdr l)) (? (p (car l)) (cons (car l) m) m)))
     (init l) (? (cdr l) (cons (car l) (init (cdr l))))
     (last l) (? (cdr l) (last (cdr l)) (car l))
     (each l f) (? (twop l) (: _ (f (car l)) (each (cdr l) f)))
     (ldel x l) (? (twop l) (? (= (car l) x) (cdr l) (cons (car l) (ldel x (cdr l)))))
     (all f l) (? (twop l) (? (f (car l)) (all f (cdr l))) -1)
     (any f l) (? (twop l) (? (f (car l)) -1 (any f (cdr l))))
     (cat a b) (foldr cons b a))
  (: catmap (co (flip foldr 0) (co cat))
     (assq x l) (? l (? (= x (caar l)) (car l) (assq x (cdr l))))
     (lidx x) ((: (f n l) (? (twop l) (? (= x (car l)) n (f (+ 1 n) (cdr l))) -1)) 0)
     memq (co any =)
     (zip a b) (? (twop a) (? (twop b) (cons (cons (car a) (car b)) (zip (cdr a) (cdr b)))))
     rev (foldl (flip cons) 0)
     (drop n l) (? n (drop (- n 1) (cdr l)) l)
     (take n l) (? n (cons (car l) (take (- n 1) (cdr l))))
     (part p) (foldr (\ a m (? (p a) (cons (cons a (car m)) (cdr m))
                                          (cons (car m) (cons a (cdr m))))) '(0)))
  ; here are some macro definitions
  (: l (foldr (\ a l (cons cons (cons a (cons l 0)))) 0) (: _ (:: 'L l) _ (:: 'list l)))
  (:: '&& (\ l (: (and l) (? (cdr l) (cons '? (cons (car l) (cons (and (cdr l)) 0))) (car l)) (? l (and l) -1))))
  (:: '|| (\ l (: (or l) (? l (: y (sym 0) (list ': y (car l) (list '? y y (or (cdr l)))))) (or l))))
  (:: ':- (\ a (cons ': (cat (cdr a) (cons (car a) 0)))))
  (:: '?- (\ a (cons '? (cat (cdr a) (cons (car a) 0)))))
  (:: '>>= (\ l (cons (last l) (init l))))
  (:: ', (\ l (cons ': (foldr  (\ l r (cons '_ (cons l r)))(list (last l)) (init l)))))
  (:: '<=< (\ g (: y (sym 0) (list '\ y (foldr (\ f x (list f x)) y g)))))

  ; last is an expression for the evaluator. this is evaluated twice by different init stages.
  (:- (\ x (: c (sco 0 (list 0) 0) (ana c x (k0 c) 0 0)))
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
                      (= a '` ) (kim (car b))
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
      (set_cdr p x) (: _ (poke 3 x p) x) ; :[ weh
      (lambp x) (? (twop x) (= '\ (car x)))
      ;; l1 pass nom def and value expressions to l2
      ; l1 collects bindings and passes them with the body expression to l2
     (l1 ns ds n d rest) (:
      (dsug n d) (? (atomp n) (cons n d) (dsug (car n) (cons '\ (cat (cdr n) (list d)))))
       nd (dsug n d) ns (cons (car nd) ns) ds (cons (cdr nd) ds)
      (? (atomp rest)       (l2 ns ds (car nd)   1)
         (atomp (cdr rest)) (l2 ns ds (car rest) 0)
                            (l1 ns ds (car rest) (cadr rest) (cddr rest))))

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
      (\ x (f (g (h x))))))))))
 (go e z a) (? a (go e (e (car a)) (cdr a)) z)
 t0 (clock 0)
 e (go (go ev 0 egg) 0 egg)
 (put 'boot_ms (clock t0) (put 'ev e globals)))
