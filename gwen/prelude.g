; prelude.g -- gwen prelude: data + function + macro definitions.
(: id 1
   (co f g x) (f (g x))
   (const x _) x
   (flip f x y) (f y x))
(: macros (get 0 0 globals))
(: pi 3.141592653589793
   true 1 false 0 not nilp
   (atomp x) (nilp (twop x))
   (!= a b) (? (= a b) 0 1)
   AA (co A A) AB (co A B)
   BA (co B A) BB (co B B))
; array element-kind codes for `arr` (enum g_tuple_type): one word per element, so
; every integer width aliases Z=0 and every float width aliases R=1 (C=2 is the
; rank-0 complex scalar, not a constructible array element).
(: i8 0 i16 0 i32 0 i64 0 f32 1 f64 1 z 0 r 1 c 2 o 3)
; the imaginary unit: complex values are written e.g. (+ 2 (* 3 i))
(: i (C 0 1))
(: (** b e) (? (< e 1) 1 (: h (** b (/ e 2)) h2 (* h h)
                           (? (= 0 (mod e 2)) h2 (* h2 b))))
   (gcd a b) (? (= b 0) (? (< a 0) (- 0 a) a) (gcd b (mod a b)))
   (modpow b e m) (? (< e 1) 1 (: h (modpow b (/ e 2) m) h2 (mod (* h h) m)
                                 (? (= 0 (mod e 2)) h2 (mod (* h2 b) m)))))
; functional bounded draw: (value . st') with value in [0,n), riding rand-next
; (full-width draw) + modulo. The global-stream analogue is the `rand` bif.
(: (randint st n) (: r (rand-next st) (cons (mod (car r) n) (cdr r))))
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
; fixnum-as-function application, installed into the VM via set-numap: applying a
; fixnum n to x is Church-numeral application -- numeric x exponentiates (x ** n), a
; function x composes n times. n<1 -> 1 (itself the identity numeral: (1 x) == x
; for every x, see below); n=1 -> x directly. numfn assembles the n-fold thread
; directly via lam/poke (no `ev`, so applying a fixnum never re-enters the compiler):
; n quote-f's then n ap's -- apl2r's [head..][arg][ap..] shape -- via the interned
; opcode globals (kernel/g.c `insts`). Cell 0 is the source \-expr at value[-1] for
; the printer's fn_src (cf. ev.c c1); entry is cell 1, handed out via (seek 1 th), and
; the src rides the thread span so GC traces it. Helpers pass th/f/n explicitly -- a
; closure over the forward-bound th miscompiles under the bootstrap c0.
(: (nfnest f i acc) (? (< i 1) acc (nfnest f (+ -1 i) (cons f (cons acc 0))))
   (nfq th f i n) (? (< i n) (: _ (poke (+ 1 (* 2 i)) g_vm_quote th) _ (poke (+ 2 (* 2 i)) f th) (nfq th f (+ 1 i) n)) th)
   (nfa th i n) (? (< i n) (: _ (poke (+ (+ 3 (* 2 n)) i) g_vm_ap th) (nfa th (+ 1 i) n)) th)
   (numfn n f) (:                                  ; build (\ x (f (f ... (f x)))), n f's
     src (cons '\ (cons 'x (cons (nfnest f n 'x) 0)))  ; alloc before lam; printer source
     th (lam (+ 5 (* 3 n)))                         ; [src] n*[quote f] [arg n] n*[ap] [ret 1]
     _ (poke 0 src th) _ (nfq th f 0 n)             ; no allocation past lam: th can't move
     _ (poke (+ 1 (* 2 n)) g_vm_arg th) _ (poke (+ 2 (* 2 n)) n th)   ; arg n: x, now under n f's
     _ (nfa th 0 n)
     _ (poke (+ 3 (* 3 n)) g_vm_ret th) _ (poke (+ 4 (* 3 n)) 1 th)
   (seek 1 th))
   (numericp x) (| (nump x) (| (tuplep x) (bigp x)))   ; whole tower: fixnum / float box / wide-int box / complex / array / bignum
   (intp n) (| (nump n) (| (boxp n) (bigp n)))       ; integer-valued numeral (exact ** exponent / composition count)
   ; x ** n across the whole tower. array exponent -> elementwise pow (broadcasts
   ; via the vmap2 engine, float result); integer exponent -> exact squaring
   ; (broadcasts over an array base, complex base via complex *); otherwise pow,
   ; which carries a complex lane (w^z = exp(z Log w)) and a real lane.
   (powg x n) (? (arrp n) (pow x n) (intp n) (** x n) (pow x n))
   ; Church-numeral application generalized across the whole tower. n is the
   ; operator (the numeral), x the operand. numeric operand -> x ** n. non-numeric
   ; operand (a function) -> compose floor(|n|) times: (int (abs n)) reduces ANY
   ; numeral to a non-negative integer count -- a float floors, a complex takes its
   ; modulus, a vector its L2 norm (all via abs, then int). k<1 -> 1 (the zero
   ; numeral, == const 1); k=1 -> identity.
   (num-ap n x) (? (numericp x) (powg x n)
                   (: k (int (abs n)) (? (< k 1) 1 (= k 1) x (numfn k x))))
   _ (set-numap num-ap))
; thread (function) combinators for + and *, installed like num-ap. a thread operand
; takes precedence over every other type, so +/* of a function build a function. these
; are the README's Church numeral arithmetic, so +/* on numerals agree with the numbers:
;   (+ f g) = Church add     ((+ f g) a x) = (f a (g a x))   -- README `add`
;   (* f g) = composition    ((* f g) x)   = (f (g x))       -- README `mul`
; the C handlers (g_vm_addl / g_vm_mull) build the 2-arg partial (scomb f g)
; / (bcomb f g); scomb's extra a-slot (threaded into both operands) is what makes + agree
; with addition rather than the S combinator's (f x (g x)).
(: (scomb f g a x) (f a (g a x))
   (bcomb f g x) (f (g x))
   _ (set-scomb scomb) _ (set-bcomb bcomb))
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
   (all f l) (? (twop l) (? (f (car l)) (all f (cdr l))) 1)
   (any f l) (? (twop l) (? (f (car l)) 1 (any f (cdr l))))
   (cat a b) (foldr cons b a))
; merge sort on lists: (sort le l) orders l by the strict less-than predicate
; le (e.g. (sort < xs)). top-down alternating split + merge; O(n log n).
(: (merge le a b) (? (atomp a) b (atomp b) a
                     (le (car a) (car b)) (cons (car a) (merge le (cdr a) b))
                     (cons (car b) (merge le a (cdr b))))
   (sortsplit l) (? (atomp l) (cons l 0) (atomp (cdr l)) (cons l 0)
                    (: r (sortsplit (cddr l)) (cons (cons (car l) (car r)) (cons (cadr l) (cdr r)))))
   (sort le l) (? (atomp l) l (atomp (cdr l)) l
                  (: s (sortsplit l) (merge le (sort le (car s)) (sort le (cdr s))))))
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
 (poke -1 (peek 0 in) (poke -1 -4 (poke -1 -1 (poke -1 0 (poke 4 cl (lam 5))))))
 (strout _)
  (poke -1 (peek 0 in) (poke -1 -2 (poke -1 -1 (poke -1 0 (poke -1 "  " (poke 5 0 (lam 6)))))))
 (outstr o) (ssub (peek 4 o) 0 (peek 5 o))
 (slurp i) (: (rl i) (: c (fgetc i) (? (!= c -1) (X c (rl i)))) (string (rl i)))
 (inspect x) (: o (strout 0) _ (fputx o x) (outstr o)))
; here are some macro definitions
(: l (foldr (\ a l (cons cons (cons a (cons l 0)))) 0) (: _ (:: 'L l) _ (:: 'list l)))
(:: '&& (\ l (: (and l) (? (cdr l) (cons '? (cons (car l) (cons (and (cdr l)) 0))) (car l)) (? l (and l) 1))))
(:: '|| (\ l (: (or l) (? l (: y (gensym 0) (list ': y (car l) (list '? y y (or (cdr l)))))) (or l))))
(:: ':- (\ a (cons ': (cat (cdr a) (cons (car a) 0)))))
(:: '?- (\ a (cons '? (cat (cdr a) (cons (car a) 0)))))
(:: '>>= (\ l (cons (last l) (init l))))
(:: '<=< (\ g (: y (gensym 0) (list '\ y (foldr (\ f x (list f x)) y g)))))
; readability / lisp-compat aliases by head-symbol substitution.
; do/begin/progn sequence side effects and return the last (identical to the
; current `,` macro -> `(: _ a _ b ... last)`); let -> the `:` let form;
; if/cond -> the `?` conditional.
(: seqx (\ l (cons ': (foldr (\ l r (cons '_ (cons l r))) (list (last l)) (init l)))))
(:: 'do seqx) (:: 'begin seqx) (:: 'progn seqx)
(:: 'let (\ a (cons ': a)))
(:: 'if (\ a (cons '? a)))
(:: 'cond (\ a (cons '? a)))
; `(quote x)` -> `(\ x)`: the CL/Scheme name for the one-arg-lambda quote (`'x` sugar).
(:: 'quote (\ a (cons '\ a)))

; quasiquote: `tmpl with ,x (unquote) and ,@xs (unquote-splice). The reader emits
; (qq tmpl), (uq x), (uqs xs). qqx/qql walk the template tracking nesting depth d:
; a nested `qq increments d, a ,/,@ decrements it, and an unquote only FIRES at d=1
; (the outermost quasiquote, R7RS) -- deeper ones are rebuilt literally. qqx returns
; CODE that reconstructs the template (cons/cat over the spliced values). uq is also
; bound to identity so a stray top-level ,x just evaluates its operand.
(: (qqx t d) (?
    (atomp t)       (list '\ t)                              ; atom: quote it
    (= (car t) 'uq) (? (= d 1) (cadr t)                      ; fire: value as-is
                       (list 'list ''uq (qqx (cadr t) (- d 1)))) ; rebuild literal uq
    (= (car t) 'qq) (list 'list ''qq (qqx (cadr t) (+ d 1))) ; nested qq: walk one in
                    (qql t d))                               ; other list
   (qql t d) (?
    (atomp t) (qqx t d)                                      ; nil / improper tail
    (&& (twop (car t)) (= (caar t) 'uqs))
     (? (= d 1) (list 'cat (cadr (car t)) (qql (cdr t) d))   ; fire splice
        (list 'cons (list 'list ''uqs (qqx (cadr (car t)) (- d 1))) (qql (cdr t) d)))
    (list 'cons (qqx (car t) d) (qql (cdr t) d))))           ; ordinary element
(:: 'qq (\ a (qqx (car a) 1)))
(: uq (\ x x))                                               ; stray ,x evaluates x

; --- array element-type inference + shape coercion (shared by `tuple` and `array`).
; a-type: the element type code, the highest of {i64=0 < f64=1 < o=2} present in
; a list of values -- a box still fits i64; only a value past the real 64-bit
; tower (bignum, complex, non-number) lifts the array to an object (o) array.
; a-dim/a-shape: a shape dimension may be any numeric -- a float, complex, or even
; a vector -- and is coerced to a non-negative integer by its L2 norm ((int (abs
; d)): abs is the modulus for a complex / the Euclidean norm for a vector). a list
; shape is coerced per-dim; a lone numeric is a rank-1 length (so (array 2.5 …) and
; (array (C 3 4) …) both mean "rank-1, length (int |n|)").
(: (a-rank x) (? (flop x) 1 (| (nump x) (boxp x)) 0 2)
   (a-emax m x) (: k (a-rank x) (? (< m k) k m))
   (a-type d) (: r (foldl a-emax 0 d) (? (= r 0) i64 (= r 1) f64 o))
   (a-dim d) (int (abs d))
   (a-shape s) (? (twop s) (map a-dim s) (L (a-dim s))))

; tuple/hash value constructors (also the read-back targets of the `@(…)` / `%(…)`
; printer-sugar forms). `tuple` builds a rank-1 array from its element args,
; inferring the element type via a-type (so it carries bignums/symbols in an o
; array, not just i64/f64); `hasht` builds a hash from alternating key/value args.
(: (ltuple l) (arrl (a-type l) (L (foldl (\ n _ (+ 1 n)) 0 l)) l))
(:: 'tuple (\ a (list 'ltuple (cons 'list a))))
(: (hashtx a) (? (twop a) (list 'put (car a) (cadr a) (hashtx (cddr a))) '(hashn 0)))
(:: 'hasht (\ a (hashtx a)))

; the `$` reader sigil wraps its operand with gensym: `$x` -> (gsym x) -> the macro
; quotes the operand, giving (gensym 'x) -- a fresh uninterned symbol named x. a
; non-name operand (e.g. the $<addr> an anonymous gensym prints as) quotes to itself
; and gensym makes it anonymous. mirrors the printer in gzput_sym.
(:: 'gsym (\ a (list 'gensym (list '\ (car a)))))

; (array shape elem…): the ergonomic N-D array constructor. `shape` is either a
; dimension *list* (rank-N) or a single number n (a rank-1 vector of length |n|),
; coerced via a-shape (L2 norm). the element type is INFERRED via a-type, so a
; bignum / complex / string / nested array forces an object array automatically --
; no explicit type code, and exactness is never silently lost. the elements are
; ordinary trailing arguments (not a list): since the shape fixes the count,
; `array` curries them one at a time and builds once it has them all -- so
; (array 2 'a 'b), (array '(2 2) 1 2 3 4) and a partial like (array 3) (a collector
; awaiting 3 elems) all fall out of gwen's auto-currying, like numap's n-ary thread.
(: (a-coll sh n acc) (? (< n 1) (: d (rev acc) (arrl (a-type d) sh d))
                        (\ x (a-coll sh (- n 1) (X x acc))))
   (array s) (: sh (a-shape s) (a-coll sh (foldl * 1 sh) 0)))

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
(: (lambp x) (? (twop x) (&& (= '\ (car x)) (twop (cddr x)))) ; \ with >=1 param (one-operand \ is quote)
   (dsug n d) (? (atomp n) (cons n d) (dsug (car n) (cons '\ (cat (cdr n) (list d)))))
   (lp x) (: a (cdr x) (? (atomp (cdr a)) (cons 0 (car a)) (cons (init a) (last a))))
   (ln bs) (? (atomp bs) 0 (atomp (cdr bs)) 0 (cons (car (dsug (car bs) 0)) (ln (cddr bs))))
   ; w/wl: is symbol v free under a lambda in x / binding-list bs? multi-operand \ and
   ; : shadow; one-operand \ is quote (data, nothing free); macro expansion (so :- ?-
   ; &&/|| are seen as the compiler sees them).
   (w v x bnd u) (?
    (symp x) (&& u (= x v) (nilp (memq v bnd)))
    (atomp x) 0
    (: h (car x) (?
      (= h '\) (? (atomp (cddr x)) 0 (: r (lp x) (w v (cdr r) (cat (car r) bnd) 1)))
      (= h ':) (wl v (cdr x) (cat (ln (cdr x)) bnd) u)
      (: m (? (symp h) (get 0 h macros) 0) (? m (w v (m (cdr x)) bnd u) (any (\ e (w v e bnd u)) x))))))
   (wl v bs bnd u) (?
    (atomp bs) 0
    (atomp (cdr bs)) (w v (car bs) bnd u)
    (: nd (dsug (car bs) (cadr bs)) (? (w v (cdr nd) bnd u) 1 (wl v (cddr bs) bnd u))))
   ; boxset: value bindings whose init closes over the name (or a no-later sibling).
   (boxset prs) (: nm (map car prs)
     (filter (\ v (&& (nilp (lambp (cdr (assq v prs))))
                      (any (\ p (w v (cdr p) 0 0)) (take (+ 1 (lidx v nm)) prs)))) nm))
   (mkcs bx) (map (\ v (cons v (gensym 0))) bx)
   (cellbinds cs) (map (\ c (cons (cdr c) (list 'cons 0 0))) cs))
; boxfix-core (c0): same prep + rewrites refs via sub/subl (c0 has no analysis-time
; redirect). Returns (prepped-prs . body') or 0.
(: (boxfix-core prs body) (:
   (rmc cs ns) (filter (\ p (nilp (memq (car p) ns))) cs)
   (sub cs x) (?
    (symp x) (: p (assq x cs) (? p (list 'car (cdr p)) x))
    (atomp x) x
    (: h (car x) (?
      (= h '\) (? (atomp (cddr x)) x (: r (lp x) (cons '\ (cat (car r) (list (sub (rmc cs (car r)) (cdr r)))))))
      (= h ':) (cons ': (subl (rmc cs (ln (cdr x))) (cdr x)))
      (: m (? (symp h) (get 0 h macros) 0) (? m (sub cs (m (cdr x))) (map (\ e (sub cs e)) x))))))
   (subl cs bs) (?
    (atomp bs) bs
    (atomp (cdr bs)) (list (sub cs (car bs)))
    (: nd (dsug (car bs) (cadr bs)) (cons (car nd) (cons (sub cs (cdr nd)) (subl cs (cddr bs))))))
   (: bx (boxset prs)
      (? (nilp bx) 0
       (: cs (mkcs bx)
          (one p) (: d (sub cs (cdr p)) (? (memq (car p) bx) (cons '_ (list 'poke 1 d (cdr (assq (car p) cs)))) (cons (car p) d)))
          (cons (cat (cellbinds cs) (map one prs)) (sub cs body)))))))
; flat-list adapter for c0 (ev.c): a `:` binding list (n1 d1 .. [body]) -> the
; rewritten list, or the input unchanged. even (body-less) lets and lets that
; need no boxing pass through verbatim.
(: (boxfix fs) (:
   (ev l) (? (atomp l) 1 (atomp (cdr l)) 0 (ev (cddr l)))
   (bpr fs) (? (atomp (cdr fs)) (cons 0 (car fs))
               (: r (bpr (cddr fs)) (cons (cons (dsug (car fs) (cadr fs)) (car r)) (cdr r))))
   (? (ev fs) fs
    (: pb (bpr fs) r (boxfix-core (car pb) (cdr pb))
       (? r (cat (catmap (\ p (list (car p) (cdr p))) (car r)) (list (cdr r))) fs)))))
