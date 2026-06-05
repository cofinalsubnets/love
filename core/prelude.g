; prelude.g -- gwen prelude: data + function + macro definitions.
(: (co f g x) (f (g x))
   (id x) x
   (const x _) x
   (flip f x y) (f y x))
(: macros (get 0 0 globals))
(: pi 3.141592653589793
   true -1 false 0 not nilp
   (atomp x) (nilp (twop x))
   (!= a b) (? (= a b) 0 -1)
   AA (co A A) AB (co A B)
   BA (co B A) BB (co B B))
; array element-type codes for `arr` (core/i.h enum g_vec_type)
(: i8 0 i16 1 i32 2 i64 3 f32 4 f64 5)
; the imaginary unit: complex values are written e.g. (+ 2 (* 3 i))
(: i (cplx 0 1))
; integer math: `**` is exact exponentiation-by-squaring (distinct from the
; float `pow` bif), `gcd` is Euclid, `modpow` is modular exponentiation. these
; ride the numeric tower (* / %), so they stay exact across fixnum/box/bignum.
(: (** b e) (? (< e 1) 1 (: h (** b (/ e 2)) h2 (* h h)
                           (? (= 0 (% e 2)) h2 (* h2 b))))
   (gcd a b) (? (= b 0) (? (< a 0) (- 0 a) a) (gcd b (% a b)))
   (modpow b e m) (? (< e 1) 1 (: h (modpow b (/ e 2) m) h2 (% (* h h) m)
                                 (? (= 0 (% e 2)) h2 (% (* h2 b) m)))))
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
   putx (fputx out)
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
(: (strin cl)
 (poke -1 (peek 0 in) (poke -1 -4 (poke -1 -1 (poke -1 0 (poke 4 cl (thd 5))))))
 (strout _)
  (poke -1 (peek 0 in) (poke -1 -2 (poke -1 -1 (poke -1 0 (poke -1 "  " (poke 5 0 (thd 6)))))))
 (outstr o) (ssub (peek 4 o) 0 (peek 5 o))
 (slurp i) (: (rl i) (: c (fgetc i) (? (!= c -1) (X c (rl i)))) (str (rl i)))
 (inspect x) (: o (strout 0) _ (fputx o x) (outstr o)))
; here are some macro definitions
(: l (foldr (\ a l (cons cons (cons a (cons l 0)))) 0) (: _ (:: 'L l) _ (:: 'list l)))
(:: '&& (\ l (: (and l) (? (cdr l) (cons '? (cons (car l) (cons (and (cdr l)) 0))) (car l)) (? l (and l) -1))))
(:: '|| (\ l (: (or l) (? l (: y (sym 0) (list ': y (car l) (list '? y y (or (cdr l)))))) (or l))))
(:: ':- (\ a (cons ': (cat (cdr a) (cons (car a) 0)))))
(:: '?- (\ a (cons '? (cat (cdr a) (cons (car a) 0)))))
(:: '>>= (\ l (cons (last l) (init l))))
(:: '<=< (\ g (: y (sym 0) (list '\ y (foldr (\ f x (list f x)) y g)))))
; readability / lisp-compat aliases by head-symbol substitution.
; do/begin/progn sequence side effects and return the last (identical to the
; current `,` macro -> `(: _ a _ b ... last)`); let -> the `:` let form;
; if/cond -> the `?` conditional.
(: seqx (\ l (cons ': (foldr (\ l r (cons '_ (cons l r))) (list (last l)) (init l)))))
(:: 'do seqx) (:: 'begin seqx) (:: 'progn seqx)
(:: 'let (\ a (cons ': a)))
(:: 'if (\ a (cons '? a)))
(:: 'cond (\ a (cons '? a)))
; `(quote x)` -> `(. x)`: the CL/Scheme name for the `.` quote form (`'x` sugar).
(:: 'quote (\ a (cons '. a)))

; recursive-value boxing for `:` (the letrec* "capture by location" fix).
; `boxfix-core` takes a source-order (name . def) pair-list `prs` and the body
; expression, and indirects every *value* binding whose init closes over the
; name being defined (or a forward/mutual sibling defined no later) through a
; heap cell: prepend `cell (cons 0 0)`, store via `(poke 1 init cell)`, read via
; `(car cell)`. Functions (resolved lazily) and values defined before their
; users are untouched. It returns 0 when nothing needs boxing, else the rewritten
; (prs' . body'). This is the single source of truth, shared verbatim by both
; compilers: ev.g's `ale` keeps its bindings as this exact pair-list and calls
; boxfix-core directly (zero conversion); c0 (ev.c) calls the flat `boxfix`
; wrapper below, which is just bpr+flatten around the same core. `lambp`/`dsug`
; are globals so `ale` shares them (lambda detection, binding desugaring).
(: (lambp x) (? (twop x) (= '\ (car x)))
   (dsug n d) (? (atomp n) (cons n d) (dsug (car n) (cons '\ (cat (cdr n) (list d))))))
(: (boxfix-core prs body) (:
   (lp x) (: a (cdr x) (? (atomp (cdr a)) (cons 0 (car a)) (cons (init a) (last a))))
   (ln bs) (? (atomp bs) 0 (atomp (cdr bs)) 0 (cons (car (dsug (car bs) 0)) (ln (cddr bs))))
   ; w: is symbol v free in x and (u) under a lambda? \ / : shadowing, . quote,
   ; macro expansion (so :- ?- let &&/|| are seen as the compiler sees them).
   (w v x bnd u) (?
    (symp x) (&& u (= x v) (nilp (memq v bnd)))
    (atomp x) 0
    (: h (car x) (?
      (= h '.) 0
      (= h '\) (: r (lp x) (w v (cdr r) (cat (car r) bnd) -1))
      (= h ':) (wl v (cdr x) (cat (ln (cdr x)) bnd) u)
      (: m (? (symp h) (get 0 h macros) 0) (? m (w v (m (cdr x)) bnd u) (any (\ e (w v e bnd u)) x))))))
   (wl v bs bnd u) (?
    (atomp bs) 0
    (atomp (cdr bs)) (w v (car bs) bnd u)
    (: nd (dsug (car bs) (cadr bs)) (? (w v (cdr nd) bnd u) -1 (wl v (cddr bs) bnd u))))
   ; sub: replace free refs to a boxed name (cs = alist name->cell) with (car cell)
   (rmc cs ns) (filter (\ p (nilp (memq (car p) ns))) cs)
   (sub cs x) (?
    (symp x) (: p (assq x cs) (? p (list 'car (cdr p)) x))
    (atomp x) x
    (: h (car x) (?
      (= h '.) x
      (= h '\) (: r (lp x) (cons '\ (cat (car r) (list (sub (rmc cs (car r)) (cdr r))))))
      (= h ':) (cons ': (subl (rmc cs (ln (cdr x))) (cdr x)))
      (: m (? (symp h) (get 0 h macros) 0) (? m (sub cs (m (cdr x))) (map (\ e (sub cs e)) x))))))
   (subl cs bs) (?
    (atomp bs) bs
    (atomp (cdr bs)) (list (sub cs (car bs)))
    (: nd (dsug (car bs) (cadr bs)) (cons (car nd) (cons (sub cs (cdr nd)) (subl cs (cddr bs))))))
   (: nm (map car prs)
      bx (filter (\ v (&& (nilp (lambp (cdr (assq v prs))))
                          (any (\ p (w v (cdr p) 0 0))
                               (take (+ 1 (lidx v nm)) prs)))) nm)
      (? (nilp bx) 0
       (: cs (map (\ v (cons v (sym 0))) bx)
          (one p) (: d (sub cs (cdr p))
                     (? (memq (car p) bx)
                        (cons '_ (list 'poke 1 d (cdr (assq (car p) cs))))
                        (cons (car p) d)))
          es (map one prs)
          (cons (cat (map (\ c (cons (cdr c) (list 'cons 0 0))) cs) es)
                (sub cs body)))))))
; flat-list adapter for c0 (ev.c): a `:` binding list (n1 d1 .. [body]) -> the
; rewritten list, or the input unchanged. even (body-less) lets and lets that
; need no boxing pass through verbatim.
(: (boxfix fs) (:
   (ev l) (? (atomp l) -1 (atomp (cdr l)) 0 (ev (cddr l)))
   (bpr fs) (? (atomp (cdr fs)) (cons 0 (car fs))
               (: r (bpr (cddr fs)) (cons (cons (dsug (car fs) (cadr fs)) (car r)) (cdr r))))
   (? (ev fs) fs
    (: pb (bpr fs) r (boxfix-core (car pb) (cdr pb))
       (? r (cat (catmap (\ p (list (car p) (cdr p))) (car r)) (list (cdr r))) fs)))))
