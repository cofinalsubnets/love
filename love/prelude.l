; prelude.l -- love prelude: data + function + macro definitions.
(: id 1
   (co f g x) (f (g x))
   (const x _) x
   (flip f x y) (f y x))
(: macros (peep dict 0 0))
(: pi 3.141592653589793
   e 2.718281828459045                          ; Euler's number; exp is (\ x (x e))
   true 1 false 0
   non nilp                                     ; the normal name; !$x reads "non sat x"
   (atomp x) (nilp (twop x))
   caap (co cap cap) cabp (co cap cbp)
   cbap (co cbp cap) cbbp (co cbp cbp))
; array element-kind codes (enum g_tuple_type), named for the tier spine:
; z integers, r reals, c packed complex, o objects -- one word per element.
(: z 0 r 1 c 2 o 3)
; the imaginary unit: complex values are written e.g. (+ 2 (* 3 i))
(: i ~(0 1))
; the monadic ~ sigil (~x, i.e. ~ not followed by `(`): lift a real to ~(r 0),
; conjugate a complex to ~(re -im), ~0 -> ~(0 0). One formula -- plex of the real
; part and the negated imaginary part -- since (re r)=r, (im r)=0 for a real, and
; (re z)/(im z) for a complex. (The 2-operand ~(a b) splices into (plex a b).)
(: (clift x) (plex (re x) (- 0 (im x))))
; integer power (b ** k) is just numeral application: (k b) == b**k. The squaring
; algorithm lives in `ipow`, local to the num-ap block below, so there is no `**`.
(: (gcd a b) (? (= b 0) (? (< a 0) (- 0 a) a) (gcd b (% a b)))
   (modpow b k m) (? (< k 1) 1 (: h (modpow b (// k 2) m) h2 (% (* h h) m)
                                 (? (= 0 (% k 2)) h2 (% (* h2 b) m)))))
; functional bounded draw: (value . st') with value in [0,n), riding rand-next
; (full-width draw) + modulo. The global-stream analogue is the `rand` nif.
(: (randint st n) (: r (rand-next st) (cons (% (cap r) n) (cbp r))))
(: caaap (co cap caap) caabp (co cap cabp)
   cabap (co cap cbap) cabbp (co cap cbbp)
   cbaap (co cbp caap) cbabp (co cbp cabp)
   cbbap (co cbp cbap) cbbbp (co cbp cbbp))
; X cons; cap/cbp -- contents of the a/b part of the pair -- and the caap..cbbbp
; compounds above are the primitives; the classic car/cdr aliases are gone.
(: inc (+ 1) dec (+ -1) (:: a b) (pin macros a b)
   putc (fputc out)
   puts (fputs out)
   putn (fputn out)
   putx (fputx out)
   (getc _) (fgetc in))
; the accessor aliases are plain globals too, so escaping works like (+)/'+ --
; ((->) t k d) peeps. (punct names can't sit in `:` binding position -- they'd
; capture the `:` -- so pin dict directly.)
(: _ (pin dict '<- pin) (pin dict '-> peep))
; fixnum-as-function application, pinned on dict for the VM's apply path: applying a
; fixnum n to x is Church-numeral application -- numeric x exponentiates (x ** n), a
; function x composes ($ n) times. n<1 -> 1 (itself the identity numeral: (1 x) == x
; for every x, see below); n=1 -> x directly. numfn assembles the n-fold text
; directly via lamb/poke (no `ev`, so applying a fixnum never re-enters the compiler):
; n quote-f's then n ap's -- apl2r's [head..][arg][ap..] shape -- via the interned
; opcode globals (kernel/g.c `insts`). Cell 0 is the source \-expr at value[-1] for
; the printer's fn_src (cf. ev.c c1); entry is cell 1, handed out via (seek 1 th), and
; the src rides the text span so GC traces it. Helpers pass th/f/n explicitly -- a
; closure over the forward-bound th miscompiles under the bootstrap c0.
(: (nfnest f i acc) (? (< i 1) acc (nfnest f (+ -1 i) (cons f (cons acc 0))))
   (nfq th f i n) (? (< i n) (: _ (poke (+ 1 (* 2 i)) g_vm_quote th) _ (poke (+ 2 (* 2 i)) f th) (nfq th f (+ 1 i) n)) th)
   (nfa th i n) (? (< i n) (: _ (poke (+ (+ 3 (* 2 n)) i) g_vm_ap th) (nfa th (+ 1 i) n)) th)
   (numfn n f) (:                                  ; build (\ x (f (f ... (f x)))), n f's
     src (cons '\ (cons 'x (cons (nfnest f n 'x) 0)))  ; alloc before lamb; printer source
     th (lamb (+ 5 (* 3 n)))                         ; [src] n*[quote f] [arg n] n*[ap] [ret 1]
     _ (poke 0 src th) _ (nfq th f 0 n)             ; no allocation past lamb: th can't move
     _ (poke (+ 1 (* 2 n)) g_vm_arg th) _ (poke (+ 2 (* 2 n)) n th)   ; arg n: x, now under n f's
     _ (nfa th 0 n)
     _ (poke (+ 3 (* 3 n)) g_vm_ret th) _ (poke (+ 4 (* 3 n)) 1 th)
   (seek 1 th))
   (nump x) (| (fixp x) (| (tupp x) (bigp x)))   ; whole tower: fixnum / float box / wide-int box / complex / array / bignum
   (intp n) (| (fixp n) (| (boxp n) (bigp n)))       ; integer-valued numeral (exact power exponent / composition count)
   ; b ** k by exact squaring (O(log k)); k>=0. The lone home of integer power --
   ; (k b) numeral application routes here, so `**` is unneeded.
   ; the count ceiling: a PUBLIC tunable box. a numeral compose count or exact-power
   ; exponent above it raises (sing 'apcap k) instead of allocating O(k) -- so
   ; (bignum f) traps where it would oom. retune at runtime: (pin apcap () n).
   apcap (pin (table 0) () 1048576)              ; (a raw box: the # sigil's hash isn't built yet)
   (ipow b k) (? (< k 1) 1 (: h (ipow b (// k 2)) h2 (* h h) (? (= 0 (% k 2)) h2 (* h2 b))))
   ; x ** n across the whole tower. array exponent -> elementwise pow (broadcasts
   ; via the vmap2 engine, float result); integer exponent -> exact squaring, with
   ; a NEGATIVE integer giving the reciprocal power (so (-1 x) == (/ 1 x) and
   ; (sqrt x) == ((/ 1 2) x)); otherwise pow, which carries a complex lane
   ; (w^z = exp(z Log w)) and a real lane.
   (powg x n) (? (arrp n) (pow x n)
                 (intp n) (: m (? (< n 0) (- 0 n) n)
                             (? (< (peep apcap () 0) m) (sing 'apcap m)
                                (< n 0) (/ 1 (ipow x m)) (ipow x m)))
                 (pow x n))
   ; Church-numeral application generalized across the whole tower. n is the
   ; operator (the numeral), x the operand. numeric operand -> x ** n. non-numeric
   ; operand (a function) -> compose ($ n) times: saturation reduces ANY numeral to
   ; a fixnum nat, true to the !!$ truth bits -- a non-positive numeral acts as the
   ; zero numeral ((-3 f) = (0 f) = 1, the literal lambda construction), a float
   ; ceils, a complex its modulus when it sorts positive, an array its element
   ; sum -- the saturated net. k=0 -> 1 (const 1); k=1 -> x directly -- the snappy basics.
   (num-ap n x) (? (nump x) (powg x n)
                   (: k (sat n)
                      (? (< k 1) 1 (= k 1) x
                         (< (peep apcap () 0) k) (sing 'apcap k)
                         (numfn k x))))
   _ (pin dict 'num-ap num-ap))
; text (function) combinators for + and *, installed like num-ap. a text operand
; takes precedence over every other type, so +/* of a function build a function. these
; are the README's Church numeral arithmetic, so +/* on numerals agree with the numbers:
;   (+ f g) = Church add     ((+ f g) a x) = (f a (g a x))   -- README `add`
;   (* f g) = composition    ((* f g) x)   = (f (g x))       -- README `mul`
; the C aps (g_vm_addh / g_vm_mulh) build the 2-arg partial (scomb f g)
; / (bcomb f g); scomb's extra a-slot (threaded into both operands) is what makes + agree
; with addition rather than the S combinator's (f x (g x)).
(: (scomb f g a x) (f a (g a x))
   (bcomb f g x) (f (g x))
   _ (pin dict 'scomb scomb) _ (pin dict 'bcomb bcomb))
(: (map f l) (? (twop l) (cons (f (cap l)) (map f (cbp l))))
   (foldl f z l) (? (twop l) (foldl f (f z (cap l)) (cbp l)) z)
   (foldr f z l) (? (twop l) (f (cap l) (foldr f z (cbp l))) z))
(: (foldl1 f l) (foldl f (cap l) (cbp l))
   (foldr1 f l) (foldr f (last l) (init l))
   ap (foldl id)
   (filter p l) (? (twop l) (: m (filter p (cbp l)) (? (p (cap l)) (cons (cap l) m) m)))
   (init l) (? (twop (cbp l)) (cons (cap l) (init (cbp l))))
   (last l) (? (twop (cbp l)) (last (cbp l)) (cap l))
   (each l f) (? (twop l) (: _ (f (cap l)) (each (cbp l) f)))
   (ldel x l) (? (twop l) (? (= (cap l) x) (cbp l) (cons (cap l) (ldel x (cbp l)))))
   (all f l) (? (twop l) (? (f (cap l)) (all f (cbp l))) 1)
   (any f l) (? (twop l) (? (f (cap l)) 1 (any f (cbp l))))
   (cat a b) (foldr cons b a))
; sort: (sort l) orders l ascending by the total order -- the C lane (a stable
; bottom-up merge in the heap gap, one cmp3 per compare, no lisp re-entry);
; descending is (rev (sort l)). an arbitrary strict less-than predicate takes
; the lisp merge sort: (msort le l), top-down alternating split + merge.
(: (merge le a b) (? (atomp a) b (atomp b) a
                     (le (cap a) (cap b)) (cons (cap a) (merge le (cbp a) b))
                     (cons (cap b) (merge le a (cbp b))))
   (sortsplit l) (? (atomp l) (cons l 0) (atomp (cbp l)) (cons l 0)
                    (: r (sortsplit (cbbp l)) (cons (cons (cap l) (cap r)) (cons (cabp l) (cbp r)))))
   (msort le l) (? (atomp l) l (atomp (cbp l)) l
                  (: s (sortsplit l) (merge le (msort le (cap s)) (msort le (cbp s))))))
(: catmap (co (flip foldr 0) (co cat))
   (assq x l) (? (twop l) (? (= x (caap l)) (cap l) (assq x (cbp l))))
   (lidx x) ((: (f n l) (? (twop l) (? (= x (cap l)) n (f (+ 1 n) (cbp l))) -1)) 0)
   memq (co any (=))
   (zip a b) (? (twop a) (? (twop b) (cons (cons (cap a) (cap b)) (zip (cbp a) (cbp b)))))
   rev (foldl (flip cons) 0)
   (drop n l) (? n (drop (- n 1) (cbp l)) l)
   (take n l) (? n (cons (cap l) (take (- n 1) (cbp l))))
   (part p) (foldr (\ a m (? (p a) (cons (cons a (cap m)) (cbp m))
                                        (cons (cap m) (cons a (cbp m))))) '(0)))
(: (sip cl)
 (poke -1 (peek 0 in) (poke -1 -4 (poke -1 -1 (poke -1 0 (poke 4 cl (lamb 5))))))
 (pad _)
  (poke -1 (peek 0 in) (poke -1 -2 (poke -1 -1 (poke -1 0 (poke -1 "  " (poke 5 0 (lamb 6)))))))
 (page o) (slice (peek 4 o) 0 (peek 5 o))
 (slurp i) (: (rl i) (: c (fgetc i) (? !(= c -1) (cons c (rl i)))) (string (rl i)))
 (show x) (: o (pad 0) _ (fputx o x) (page o)))
; trap status readers. a global `trap` function is called as (trap s a b):
; s = the status word, two bits -- sing (1: something went wrong) and more
; (2: read control flow, more input wanted). more alone = incomplete; eof =
; more|sing (the end is the singing case of wanting more). a/b = the condition
; data (the more bit: the port and the read sentinel). the result is delivered
; per the bits: more -> to the reader's resume; a bare sing -> observed.
(: (sing? s) (= s 1)
   (more? s) (= s 2)
   (eof? s) (= s 3))
; here are some macro definitions
(: l (foldr (\ a l (cons cons (cons a (cons l 0)))) 0) (: _ (:: 'L l) _ (:: 'list l)))
(:: '&& (\ l (: (and l) (? (twop (cbp l)) (list '? (cap l) (and (cbp l)) 0) (cap l)) (? (twop l) (and l) 1))))
(:: '|| (\ l (: (or l) (? (twop l) (: y (nom 0) (list ': y (cap l) (list '? y y (or (cbp l))))) 0) (or l))))
(:: ':- (\ a (cons ': (cat (cbp a) (cons (cap a) 0)))))
(:: '?- (\ a (cons '? (cat (cbp a) (cons (cap a) 0)))))
(:: '>>= (\ l (cons (last l) (init l))))
(:: '<=< (\ g (: y (nom 0) (list '\ y (foldr (\ f x (list f x)) y g)))))
; the global RNG stream lives on dict ('rng-state) and advances by the pure
; rand-next/randf-next -- C holds no state and never draws. rng-get lazily
; clock-seeds on first use; rng-set validates and installs (the state, or nil
; if malformed). (rand n) -> fixnum in [0,n), n <= 0 (or non-fixnum) -> a
; full-width non-negative fixnum; (randf _) -> float in [0,1).
(: (rng-get _) (: st (peep dict 'rng-state 0)
                  (? (arrp st) st (: f (rng-seed (clock 0)) _ (pin dict 'rng-state f) f)))
   (rng-set st) (? (&& (arrp st) (= 1 (arank st)) (= 4 (alen st)) (= z (atype st)))
                   (: _ (pin dict 'rng-state st) st)
                   0)
   (rand n) (: r (rand-next (rng-get 0)) _ (pin dict 'rng-state (cbp r))
               (? (&& (fixp n) (< 0 n)) (% (cap r) n) (cap r)))
   (randf _) (: r (randf-next (rng-get 0)) _ (pin dict 'rng-state (cbp r)) (cap r)))
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
; CODE that reconstructs the template (X/cat over the spliced values). uq is also
; bound to identity so a stray top-level ,x just evaluates its operand.
(: (qqx t d) (?
    (atomp t)       (list '\ t)                              ; atom: quote it
    (= (cap t) 'uq) (? (= d 1) (cabp t)                      ; fire: value as-is
                       (list 'list ''uq (qqx (cabp t) (- d 1)))) ; rebuild literal uq
    (= (cap t) 'qq) (list 'list ''qq (qqx (cabp t) (+ d 1))) ; nested qq: walk one in
                    (qql t d))                               ; other list
   (qql t d) (?
    (atomp t) (qqx t d)                                      ; nil / improper tail
    (&& (twop (cap t)) (= (caap t) 'uqs))
     (? (= d 1) (list 'cat (cabp (cap t)) (qql (cbp t) d))   ; fire splice
        (list 'cons (list 'list ''uqs (qqx (cabp (cap t)) (- d 1))) (qql (cbp t) d)))
    (list 'cons (qqx (cap t) d) (qql (cbp t) d))))           ; ordinary element
(:: 'qq (\ a (qqx (cap a) 1)))
(: uq (\ x x))                                               ; stray ,x evaluates x

; --- array element-type inference + shape coercion (shared by `tuple` and `array`).
; a-type: the element type code, the highest of {z=0 < r=1 < c=2 < o=3} present
; in a list of values -- a box still fits z; a complex value lifts to a packed
; (re,im) `c` array; only a value past the real numeric tower (bignum, symbol,
; string, nested array, …) lifts the whole array to an object (o) array.
; a-dim/a-shape: a shape dimension may be any numeric -- a float, complex, or even
; a vector -- and is coerced to a nat by saturation (($ d) -- the count law:
; non-positive -> 0, a float ceils, a complex its modulus, a vector its net sum). a list
; shape is coerced per-dim; a lone numeric is a rank-1 length (so (array 2.5 …)
; means rank-1 length 3, (array ~(3 4) …) length 5).
(: (a-rank x) (? (flop x) 1 (| (fixp x) (boxp x)) 0 (comp x) 2 3)
   (a-emax m x) (: k (a-rank x) (? (< m k) k m))
   (a-type d) (: k (foldl a-emax 0 d) (? (= k 0) z (= k 1) r (= k 2) c o))
   (a-dim d) (? (twop d) (tally d) (sat d))
   (a-shape s) (? (twop s) (map a-dim s) (L (a-dim s))))

; tuple/hash value constructors (also the read-back targets of the `@(…)` / `#(…)`
; printer-sugar forms). `tuple` builds a rank-1 array from its element args,
; inferring the element type via a-type (so it carries bignums/symbols in an o
; array, not just z/r); `map` builds a map from alternating key/value args.
(: (ltuple l) (arr (a-type l) (L (foldl (\ n _ (+ 1 n)) 0 l)) l))
(:: 'tuple (\ a (list 'ltuple (cons 'list a))))
; (hash) = empty; (hash x) boxes a scalar -- a fresh mutable hash pinning x
; to the () key, so #5 = #(() 5); pairs pin as usual, and an odd trailing
; operand lands in the () box slot.
(: (hashtx a) (? (atomp a) '(table 0)
                 (atomp (cbp a)) (list 'pin (hashtx 0) '() (cap a))
                 (list 'pin (hashtx (cbbp a)) (cap a) (cabp a))))
(:: 'hash (\ a (hashtx a)))

; (gsym x) quotes its operand, giving (nom 'x) -- a fresh uninterned symbol
; named x. its `$` glyph went to sat; gsyms still PRINT as $<name>/$<addr>
; (display only, see gzput_sym) and are made by calling gsym or nom directly.
(:: 'gsym (\ a (list 'nom (list '\ (cap a)))))

; (array shape elem…): the ergonomic N-D array constructor. `shape` is either a
; dimension *list* (rank-N) or a single number n (a rank-1 vector of length |n|),
; coerced via a-shape (the saturated net). the element type is INFERRED via a-type, so a
; bignum / complex / string / nested array forces an object array automatically --
; no explicit type code, and exactness is never silently lost. the elements are
; ordinary trailing arguments (not a list): since the shape fixes the count,
; `array` curries them one at a time and builds once it has them all -- so
; (array 2 'a 'b), (array '(2 2) 1 2 3 4) and a partial like (array 3) (a collector
; awaiting 3 elems) all fall out of l's auto-currying, like numap's n-ary text.
(: (a-coll sh n acc) (? (< n 1) (: d (rev acc) (arr (a-type d) sh d))
                        (\ x (a-coll sh (- n 1) (cons x acc))))
   (array s) (: sh (a-shape s) (a-coll sh (foldl (*) 1 sh) 0)))

; recursive-value boxing for `:` (the letrec* "capture by location" fix).
; `boxfix-core` takes a source-order (name . def) pair-list `prs` and the body
; expression, and indirects every *value* binding whose init closes over the
; name being defined (or a forward/mutual sibling defined no later) through a
; heap cell: prepend `cell (cons 0 0)`, store via poke -- the nif VALUE, not its
; name, so the rewrite survives the egg pulling `poke` from dict -- read via
; `(cap cell)`. Functions (resolved lazily) and values defined before their
; users are untouched. It returns 0 when nothing needs boxing, else the rewritten
; (prs' . body'). This is the single source of truth, shared verbatim by both
; compilers: ev.l's `ale` keeps its bindings as this exact pair-list and calls
; boxfix-core directly (zero conversion); c0 (ev.c) calls the flat `boxfix`
; wrapper below, which is just bpr+flatten around the same core. `lambp`/`dsug`
; are globals so `ale` shares them (lambda detection, binding desugaring).
(: (lambp x) (? (twop x) (&& (= '\ (cap x)) (twop (cbbp x)))) ; \ with >=1 param (one-operand \ is quote)
   (dsug n d) (? (atomp n) (cons n d) (dsug (cap n) (cons '\ (cat (cbp n) (list d)))))
   (lp x) (: a (cbp x) (? (atomp (cbp a)) (cons 0 (cap a)) (cons (init a) (last a))))
   (ln bs) (? (atomp bs) 0 (atomp (cbp bs)) 0 (cons (cap (dsug (cap bs) 0)) (ln (cbbp bs))))
   ; w/wl: is symbol v free under a lambda in x / binding-list bs? multi-operand \ and
   ; : shadow; one-operand \ is quote (data, nothing free); macro expansion (so :- ?-
   ; &&/|| are seen as the compiler sees them).
   (w v x bnd u) (?
    (symp x) (&& u (= x v) (nilp (memq v bnd)))
    (atomp x) 0
    (: h (cap x) (?
      (= h '\) (? (atomp (cbbp x)) 0 (: r (lp x) (w v (cbp r) (cat (cap r) bnd) 1)))
      (= h ':) (wl v (cbp x) (cat (ln (cbp x)) bnd) u)
      (: m (? (symp h) (peep macros h 0) 0) (? m (w v (m (cbp x)) bnd u) (any (\ e (w v e bnd u)) x))))))
   (wl v bs bnd u) (?
    (atomp bs) 0
    (atomp (cbp bs)) (w v (cap bs) bnd u)
    (: nd (dsug (cap bs) (cabp bs)) (? (w v (cbp nd) bnd u) 1 (wl v (cbbp bs) bnd u))))
   ; boxset: value bindings whose init closes over the name (or a no-later sibling).
   (boxset prs) (: nm (map cap prs)
     (filter (\ v (&& (nilp (lambp (cbp (assq v prs))))
                      (any (\ p (w v (cbp p) 0 0)) (take (+ 1 (lidx v nm)) prs)))) nm))
   (mkcs bx) (map (\ v (cons v (nom 0))) bx)
   (cellbinds cs) (map (\ c (cons (cbp c) (list 'cons 0 0))) cs))
; boxfix-core (c0): same prep + rewrites refs via sub/subl (c0 has no analysis-time
; redirect). Returns (prepped-prs . body') or 0.
(: (boxfix-core prs body) (:
   (rmc cs ns) (filter (\ p (nilp (memq (cap p) ns))) cs)
   (sub cs x) (?
    (symp x) (: p (assq x cs) (? (twop p) (list 'cap (cbp p)) x))
    (atomp x) x
    (: h (cap x) (?
      (= h '\) (? (atomp (cbbp x)) x (: r (lp x) (cons '\ (cat (cap r) (list (sub (rmc cs (cap r)) (cbp r)))))))
      (= h ':) (cons ': (subl (rmc cs (ln (cbp x))) (cbp x)))
      (: m (? (symp h) (peep macros h 0) 0) (? m (sub cs (m (cbp x))) (map (\ e (sub cs e)) x))))))
   (subl cs bs) (?
    (atomp bs) bs
    (atomp (cbp bs)) (list (sub cs (cap bs)))
    (: nd (dsug (cap bs) (cabp bs)) (cons (cap nd) (cons (sub cs (cbp nd)) (subl cs (cbbp bs))))))
   (: bx (boxset prs)
      (? (nilp bx) 0
       (: cs (mkcs bx)
          (one p) (: d (sub cs (cbp p)) (? (memq (cap p) bx) (cons '_ (list poke 1 d (cbp (assq (cap p) cs)))) (cons (cap p) d)))
          (cons (cat (cellbinds cs) (map one prs)) (sub cs body)))))))
; flat-list adapter for c0 (ev.c): a `:` binding list (n1 d1 .. [body]) -> the
; rewritten list, or the input unchanged. even (body-less) lets and lets that
; need no boxing pass through verbatim.
(: (boxfix fs) (:
   (ev l) (? (atomp l) 1 (atomp (cbp l)) 0 (ev (cbbp l)))
   (bpr fs) (? (atomp (cbp fs)) (cons 0 (cap fs))
               (: r (bpr (cbbp fs)) (cons (cons (dsug (cap fs) (cabp fs)) (cap r)) (cbp r))))
   (? (ev fs) fs
    (: pb (bpr fs) r (boxfix-core (cap pb) (cbp pb))
       (? r (cat (catmap (\ p (list (cap p) (cbp p))) (cap r)) (list (cbp r))) fs)))))
