;;; bag is present in prelude
;;; definitions in this file must not use infix notation
;;; FIXME move ev support functions to ev where possible
; prel.l -- ai prel: data + function + macro definitions.
(: id 1
   (const x _) x
   (flip f x y) (f y x))
(: macros (peep bag 0 0))
(: pi 3.141592653589793
   tau (* 2 pi) ;; no infix here
   e 2.718281828459045                          ; Euler's number; exp is (\ x (x e))
   true 1 false 0
   i ~(0 1) ;; FIXME up top
   Z 0 R 1 C 2 O 3                              ; array element-kind codes (the tier spine)
   zero? nil?                                  ; zero? aliases nil? (the net-to-zero test)
   (one? x) (= x (cap x))
   (atom? x) (nil? (two? x))
   (co f g) (\ x (f (g x)))
   (names _ ) (keys bag)
   caap (co cap cap) caup (co cap cup) ;; FIXME emit pure code -- combine like operations and metaprogram a concrete thread for each definition
   cuap (co cup cap) cuup (co cup cup))
; array element-kind codes (enum g_vec_type), named for the tier spine:
; Z integers, R reals, C packed complex, O objects -- one word per element.
; the imaginary unit: complex values are written e.g. (+ 2 (* 3 i))
; the bare ~ digraph (~x, ~ not before `(`) reads as (conj x): conj LIFTS now, so
; it IS the monadic twin -- a real r -> ~(r 0), a complex z -> ~(re -im), an
; involution. the 2-operand ~(a b) splices into (twin a b), the C constructor.
; a NOM is the literal chain of a name string and a MINT (the nameless fresh
; point the mint nif adjoins; identity its only property, $mint = 0). the old
; named-uninterned atom species is gone -- McCarthy's symbol, restored as the
; chain it always was. (nom 0) (any non-text arg) is the bare mint.
(: (nom n) (? (string? n) (link n (mint 0)) ;; FIXME link
              (nom? n) (link (string n) (mint 0))
              (mint 0)))
; integer power (b ** k) is just numeral application: (k b) == b**k. The squaring
; algorithm lives in `ipow`, local to the num-ap block below, so there is no `**`.
(: (gcd a b) (? (= b 0) (? (< a 0) (- 0 a) a) (gcd b (% a b)))
   (modpow b k m) (? (< k 1) 1 (: h (modpow b (// k 2) m) h2 (% (* h h) m)
                                 (? (= 0 (% k 2)) h2 (% (* h2 b) m)))))
; functional bounded draw: (value . st') with value in [0,n), riding rand-next
; (full-width draw) + modulo. The global-stream analogue is the `rand` nif.
(: (randint st n) (: r (rand-next st) (link (% (cap r) n) (cup r)))) ;; FIXME check interface & link
(: caaap (co cap caap) caaup (co cap caup) ;; FIXME group above
   cauap (co cap cuap) cauup (co cap cuup)
   cuaap (co cup caap) cuaup (co cup caup)
   cuuap (co cup cuap) cuuup (co cup cuup))
; X link; cap/cup -- the chain's two projections, the matched pair the string diagrams bend
; (lineage: cap/cup <- cap/cbp <- car/cdr) -- and the caap..cuuup compounds above are the
; primitives; the older names are gone.
(: inc (+ 1) dec (+ -1) ;; FIXME pure code
 (:: a b) (pin macros a b) ;; FIXME needs a way better api
   putc (fputc out) ;; FIXME rename to avoid f prefix
   puts (fputs out) ;; FIXME rm f prefix
   (putn n) (fputbn out n 10) ;; FIXME rm f prefix and make preferred base user configurable
   putx (fputx out) ;; FIXME rm f prefix
   (getc _) (fgetc in)) ;; FIXME rm f prefix
; the accessor aliases are plain globals too, so escaping works like (+)/'+ --
; ((->) t k d) peeps.
(: <- pin -> peep)
; fixnum-as-function application, pinned on bag for the VM's apply path: applying a
; fixnum n to x is Church-numeral application -- numeric x exponentiates (x ** n), a
; function x composes ($ n) times. n<1 -> 1 (itself the identity numeral: (1 x) == x
; for every x, see below); n=1 -> x directly. numfn assembles the n-fold text
; directly via spin/poke (no `ev`, so applying a fixnum never re-enters the compiler):
; n quote-f's then n ap's -- apl2r's [head..][arg][ap..] shape -- via the interned
; opcode globals (kernel/g.c `insts`). Cell 0 is the source \-expr at value[-1] for
; the printer's fn_src (cf. ev.c c1); entry is cell 1, handed out via (seek 1 th), and
; the src rides the text span so GC traces it. Helpers pass th/f/n explicitly -- a
; closure over the forward-bound th miscompiles under the bootstrap c0.
(: (nfnest f i acc) (? (< i 1) acc (nfnest f (+ -1 i) (link f (link acc 0))))
   (nfq th f i n) (? (< i n) (: _ (poke (+ 1 (* 2 i)) lvm_quote th) _ (poke (+ 2 (* 2 i)) f th) (nfq th f (+ 1 i) n)) th)
   (nfa th i n) (? (< i n) (: _ (poke (+ (+ 3 (* 2 n)) i) lvm_ap th) (nfa th (+ 1 i) n)) th)
   (numfn n f) (:                                  ; build (\ x (f (f ... (f x)))), n f's
     src (link '\ (link 'x (link (nfnest f n 'x) 0)))  ; alloc before spin; printer source
     th (spin (+ 5 (* 3 n)))                         ; [src] n*[quote f] [arg n] n*[ap] [ret 1]
     _ (poke 0 src th) _ (nfq th f 0 n)             ; no allocation past spin: th can't move
     _ (poke (+ 1 (* 2 n)) lvm_arg th) _ (poke (+ 2 (* 2 n)) n th)   ; arg n: x, now under n f's
     _ (nfa th 0 n)
     _ (poke (+ 3 (* 3 n)) lvm_ret th) _ (poke (+ 4 (* 3 n)) 1 th)
   (seek 1 th))
   ;; FIXME rename | -> bit-or to free | for pipe operator
   (jewel? x) (| (fix? x) (| (packp x) (big? x)))   ; whole tower: fixnum / float / wide int / complex / array / bignum
   (whole? n) (| (fix? n) (| (full? n) (big? n)))       ; integer-valued numeral (exact power exponent / composition count)
   ; b ** k by exact squaring (O(log k)); k>=0. The lone home of integer power --
   ; (k b) numeral application routes here, so `**` is unneeded.
   ; the count ceiling: a PUBLIC tunable box. a numeral compose count or exact-power
   ; exponent above it raises (scare 'apcap k) instead of allocating O(k) -- so
   ; (bignum f) asks for help where it would oom. retune at runtime: (pin apcap 0 n).
   apcap (pin (tablet 0) 0 1048576)              ; (a raw box: the # sigil's hash isn't built yet)
   (ipow b k) (? (< k 1) 1 (: h (ipow b (// k 2)) h2 (* h h) (? (= 0 (% k 2)) h2 (* h2 b))))
   ; does the count/exponent k top the apcap box? the shared predicate. each site
   ; keeps its own (scare 'apcap k) as the cond RESULT, so a recovering help's value
   ; (e.g. (capped k)) becomes the result directly -- no thunk, no allocation on the
   ; hot num-ap path; the only duplication is the trivial, identical scare.
   (apover k) (< (peep apcap 0 0) k)
   ; x ** n across the whole tower. array exponent -> elementwise pow (broadcasts
   ; via the vmap2 engine, float result); integer exponent -> exact squaring, with
   ; a NEGATIVE integer giving the reciprocal power (so (-1 x) == (/ 1 x) and
   ; (sqrt x) == ((/ 1 2) x)); otherwise pow, which carries a complex lane
   ; (w^z = exp(z Log w)) and a real lane.
   (powg x n) (? (tray? n) (pow x n)
                 (whole? n) (: m (? (< n 0) (- 0 n) n)
                             (? (apover m) (scare 'apcap m)
                                (< n 0) (/ 1 (ipow x m)) (ipow x m)))
                 (pow x n))
   ; Church-numeral application generalized across the whole tower. n is the
   ; operator (the numeral), x the operand. numeric operand -> x ** n. non-numeric
   ; operand (a function) -> compose ($ n) times: saturation reduces ANY numeral to
   ; a fixnum nat, true to the !!$ truth bits -- a non-positive numeral acts as the
   ; zero numeral ((-3 f) = (0 f) = 1, the literal lambda construction), a float
   ; ceils, a complex its modulus when it sorts positive, an array its element
   ; sum -- the saturated net. k=0 -> 1 (const 1); k=1 -> x directly -- the snappy basics.
   (num-ap n x) (? (jewel? x) (powg x n)
                   (: k (sat n)
                      (? (< k 1) 1 (= k 1) x
                         (apover k) (scare 'apcap k)
                         (numfn k x))))
   _ (pin bag 'num-ap num-ap))
; text (function) combinators for + and *, installed like num-ap. a text operand
; takes precedence over every other type, so +/* of a function build a function. these
; are the README's Church numeral arithmetic, so +/* on numerals agree with the numbers:
;   (+ f g) = Church add     ((+ f g) a x) = (f a (g a x))   -- the `add` below
;   (* f g) = composition    ((* f g) x)   = (f (g x))       -- the `mul` below
; the C aps (lvm_addh / lvm_mulh) build the 2-arg partial (add f g)
; / (mul f g); add's extra a-slot (threaded into both operands) is what makes + agree
; with addition rather than the S combinator's (f x (g x)).
(: (add f g a x) (f a (g a x))
   (mul f g x) (f (g x))
   _ (pin bag 'add add) _ (pin bag 'mul mul))
(: (map f l) (? (two? l) (link (f (cap l)) (map f (cup l))))
   (foldl f z l) (? (two? l) (foldl f (f z (cap l)) (cup l)) z)
   (foldr f z l) (? (two? l) (f (cap l) (foldr f z (cup l))) z))
; the monadic words behind the glued sigils (the valence law; see opfix and
; bag['monadics] below). net is the CONTENT MEASURE as a value -- + turned
; inward: a number is its own net (phase intact, exact), an array sums its
; cells, a list the nets of its spine, and everything else is non-negative
; so its net IS its sat. prod is the product twin; neg/recip/frac the
; dyadics turned inward; bit the truth bit (the Iverson bracket, !!).
(: (net x) (? (tray? x) (asum x)
              (jewel? x) x
              (two? x) (foldl (\ a e (+ a (net e))) 0 x)
              (sat x))
   (prod x) (? (tray? x) (aprod x)
               (two? x) (foldl (\ a e (* a (prod e))) 1 x)
               x)
   neg (- 0)
   recip (/ 1)
   (frac x) (% x 1)
   (bit x) (nil? (nil? x))
   ; a GEM is a self-netting SCALAR (charm/wide/float/complex/big) -- the fixpoint of
   ; net (x IS its own net; id?, not `=`, since net returns a number operand unchanged
   ; while a tray's net is a fresh sum). a TRAY (tray?) is an array of any element kind;
   ; a CREST is a tray of GEMS -- a numeric tray. gem? and chart? are DISJOINT: a tray
   ; never self-nets (its net is a fresh scalar), so a crest is never a gem -- it is
   ; COMPOSED of gems, not a kind of gem. chart? keys on the CELLS, not the O code, so a
   ; Z/R/C tray qualifies outright and an object-typed tray of gem cells (e.g. bignums)
   ; still counts -- a tray of strings does not (a string is no gem).
   (gem? x) (id? x (net x))
   ; a CHARM is the word-sized gem -- a fixnum (the lisp predicate; oddp C-side).
   (star? x) (fix? x)
   (chart? x) (? (tray? x) (? (< (atype x) O) 1 (gem? (peep x 0 0))) 0))
(: (foldl1 f l) (foldl f (cap l) (cup l))
   (foldr1 f l) (foldr f (last l) (init l))
   ap (foldl id)
   (filter p l) (? (two? l) (: m (filter p (cup l)) (? (p (cap l)) (link (cap l) m) m)))
   (init l) (? (two? (cup l)) (link (cap l) (init (cup l))))
   (last l) (? (two? (cup l)) (last (cup l)) (cap l))
   (each l f) (? (two? l) (: _ (f (cap l)) (each (cup l) f)))
   (ldel x l) (? (two? l) (? (= (cap l) x) (cup l) (link (cap l) (ldel x (cup l)))))
   (all f l) (? (two? l) (? (f (cap l)) (all f (cup l))) 1)
   (any f l) (? (two? l) (? (f (cap l)) 1 (any f (cup l))))
   (cat a b) (foldr link b a))
; sort: (sort l) orders l ascending by the total order -- the C lane (a stable
; bottom-up merge in the heap gap, one cmp3 per compare, no lisp re-entry);
; descending is (rev (sort l)). an arbitrary strict less-than predicate takes
; the lisp merge sort: (msort le l), top-down alternating split + merge.
(: (merge le a b) (? (atom? a) b (atom? b) a
                     (le (cap a) (cap b)) (link (cap a) (merge le (cup a) b))
                     (link (cap b) (merge le a (cup b))))
   (sortsplit l) (? (atom? l) (link l 0) (atom? (cup l)) (link l 0)
                    (: r (sortsplit (cuup l)) (link (link (cap l) (cap r)) (link (caup l) (cup r)))))
   (msort le l) (? (atom? l) l (atom? (cup l)) l
                  (: s (sortsplit l) (merge le (msort le (cap s)) (msort le (cup s))))))
(: catmap (co (flip foldr 0) (co cat))
   (assq x l) (? (two? l) (? (= x (caap l)) (cap l) (assq x (cup l))))
   (lidx x) ((: (f n l) (? (two? l) (? (= x (cap l)) n (f (+ 1 n) (cup l))) -1)) 0)
   memq (co any (=))
   (zip a b) (? (two? a) (? (two? b) (link (link (cap a) (cap b)) (zip (cup a) (cup b)))))
   rev (foldl (flip link) 0)
   (jot n) ((: (go i) (? (< i n) (link i (go (+ i 1))))) 0)
   (drop n l) (? n (drop (- n 1) (cup l)) l)
   (take n l) (? n (link (cap l) (take (- n 1) (cup l))))
   (part p) (foldr (\ a m (? (p a) (link (link a (cap m)) (cup m))
                                        (link (cap m) (link a (cup m))))) '(0)))
(: (sip cl)
 (poke -1 (peek 0 in) (poke -1 -4 (poke -1 -1 (poke -1 0 (poke 4 cl (spin 5))))))
 (pad _)
  (poke -1 (peek 0 in) (poke -1 -2 (poke -1 -1 (poke -1 0 (poke -1 "  " (poke 5 0 (spin 6)))))))
 (page o) (snip (peek 4 o) 0 (peek 5 o))
 (slurp i) (: (rl i) (: c (fgetc i) (? (= c -1) 0 (link c (rl i)))) (string (rl i)))  ; (pre-opfix: no ! here)
 (show x) (: o (pad 0) _ (fputx o x) (page o)))
; help status readers. a global `help` function is called as (help s a b):
; s = the status word, two bits -- scare (1: something went wrong) and more
; (2: read control flow, more input wanted). more alone = incomplete; eof =
; more|scare (the end is the scary case of wanting more). a/b = the condition
; data (the more bit: the port and the read sentinel). the result is delivered
; per the bits: more -> to the reader's resume; a bare scare -> observed.
(: (scare? s) (= s 1)
   (more? s) (= s 2)
   (eof? s) (= s 3))
; here are some macro definitions
(: l (foldr (\ a l (link link (link a (link l 0)))) 0) (: _ (:: 'L l) _ (:: 'list l)))
(:: '&& (\ l (: (and l) (? (two? (cup l)) (list '? (cap l) (and (cup l)) 0) (cap l)) (? (two? l) (and l) 1))))
(:: '|| (\ l (: (or l) (? (two? l) (: y (nom 0) (list ': y (cap l) (list '? y y (or (cup l))))) 0) (or l))))
(:: ':- (\ a (link ': (cat (cup a) (link (cap a) 0)))))
(:: '?- (\ a (link '? (cat (cup a) (link (cap a) 0)))))
(:: '>>= (\ l (link (last l) (init l))))
(:: '<=< (\ g (: y (nom 0) (list '\ y (foldr (\ f x (list f x)) y g)))))

; --- reader operators: the table + the opfix factor pass --------------------
; a SIGIL is a maximal all-punct token (the reader's lexer law); the reader
; leaves it a plain symbol. code factors a sigil into a composition of
; operators against THIS table at compile time -- opfix below, the
; source->source pass hooked by both compilers (c0 probes bag['opfix] like
; boxfix; ev.l's wev runs it first) -- while data reading stays structural.
; ONE table: symbol -> arity (the symbol names itself) | (name . arity) (an
; alias). arity ONE applies to the next datum, never capturing a left
; operand. arities two..seven are infix: with a left operand available it
; captures it and collects arity-1 more, nesting RIGHT-associatively; with
; none it reads as the plain symbol ((+) is + as a value, '+ quotes it).
; extend with a plain pin. everything above this point is pre-opfix and
; must stay operator-free (the bootstrap restriction: no unquoted sigil
; before its definitions); everything after -- and every later file, the
; corpus, the repl -- reads hot.
(: operators (: t (tablet 0)
   _ (pin t '$ (link 'sat 1)) _ (pin t '! (link 'nil? 1)) _ (pin t '. (link 'dot 1))
   _ (pin t '+ 2) _ (pin t '- 2) _ (pin t '* 2) _ (pin t '/ 2) _ (pin t '% 2)
   _ (pin t '= 2) _ (pin t '< 2) _ (pin t '<= 2) _ (pin t '> 2) _ (pin t '>= 2)
   _ (pin t '| 2) _ (pin t '& 2) _ (pin t '? 3)
   _ (pin t '<- (link 'pin 3)) _ (pin t '-> (link 'peep 3))
   t))
; the VALENCE LAW's table: a glued operator run is MONADIC (the reader emits
; (mono (run datum))); spaced, the run keeps its dyadic/infix life. each entry
; maps a run-piece to its monadic word; a run factors greedily (longest
; prefix), all factors monadic, so <>x is (cap (cup x)) and !!x double-
; negates. << and >> ride the shift tokens' free monadic slots. an
; unfactorable run falls back to the plain application.
(: monadics (: t (tablet 0)
   _ (pin t '< 'cap)   _ (pin t '> 'cup)
   _ (pin t '<< 'caap) _ (pin t '>> 'cuup)
   _ (pin t '+ 'net)   _ (pin t '* 'prod)
   _ (pin t '| 'abs)   _ (pin t '- 'neg)
   _ (pin t '/ 'recip) _ (pin t '% 'frac)
   _ (pin t '? 'bit)
   _ (pin t '$ 'sat)   _ (pin t '! 'nil?) _ (pin t '. 'dot)
   t))
; the FACTORIZATION LAW: greedy longest-prefix match against the table, no
; backtracking; every factor but the last must be arity one; the last factor
; takes the positional valence. a token that doesn't factor is a plain
; symbol. so != factors to ! and = ((a != b) = (nil? (= a b))) while &&,
; >>=, :-, ?- (two-led or unmatched) stay atomic names.
(: (op-punc-byte c) (? (&& (<= 48 c) (<= c 57)) 0
                       (&& (<= 65 c) (<= c 90)) 0
                       (&& (<= 97 c) (<= c 122)) 0
                       (= c 95) 0
                       1)
   ; cheap prefilter: only an all-punct symbol can factor
   (op-puncp x)
    (? (nom? x)
       (: s (string x)
          (? (string? s)
             (: n (tally s)
                (? (< 0 n)
                   ((: (go i) (? (< i n) (? (op-punc-byte (s i)) (go (+ 1 i)) 0) 1)) 0)
                   0))
             0))
       0)
   ; normalize a table entry for key k -> (name . arity), or 0
   (op-ent k) (: v (operators k)
                 (? (fix? v) (? (&& (< 0 v) (< v 8)) (link k v) 0)
                    (two? v) (? (&& (nom? (cap v)) (fix? (cup v)) (< 0 (cup v)) (< (cup v) 8)) v 0)
                    0))
   ; longest prefix of nm[i..n) that is a table key -> (len . entry), or 0
   (op-long nm i n)
    ((: (go k) (? (< k 1) 0
                  (: e (op-ent (intern (snip nm i (+ i k))))
                     (? (two? e) (link k e) (go (- k 1))))))
     (- n i))
   ; factor symbol s -> a list of (name . arity) entries, or 0
   (opfactor s)
    (: nm (string s) n (tally nm)
       ((: (go i)
           (? (< i n)
              (: m (op-long nm i n)
                 (? (two? m) (: k (cap m) e (cup m)
                         (? (= (+ i k) n) (link e 0)         ; the last factor: any arity
                            (= (cup e) 1) (: r (go (+ i k))  ; non-last factors must be arity one
                                             (? (two? r) (link e r) 0))
                            0))
                    0))
              0))
        0))
   ; longest prefix of nm[i..n) that has a monadic meaning -> (len . word),
   ; or 0. monadics first, then an operators entry at arity ONE (the legacy
   ; prefix lane -- $ ! . and live pins alike), so the table stays dynamic.
   (mono-long nm i n)
    ((: (go k) (? (< k 1) 0
                  (: s (intern (snip nm i (+ i k)))
                     e (monadics s)
                     (? (nom? e) (link k e)
                        (: o (op-ent s)
                           (? (? (two? o) (= 1 (cup o)) 0) (link k (cap o))
                              (go (- k 1))))))))
     (- n i))
   ; factor a glued run against the monadic table -> the word list
   ; (outermost first), or 0; every factor is monadic by construction
   (monofactor s)
    (: nm (string s) n (tally nm)
       ((: (go i)
           (? (< i n)
              (: m (mono-long nm i n)
                 (? (two? m)
                    (? (= (+ i (cap m)) n) (link (cup m) 0)
                       (: r (go (+ i (cap m))) (? (two? r) (link (cup m) r) 0)))
                    0))
              0))
        0)))
; the walk. a pending-operator frame is (orig chain name need . got): orig =
; the source symbol (delivered back verbatim when no operand ever arrives --
; a bare sigil is a plain symbol), chain = the arity-one wrapper names
; (outermost first), need = operands still wanted (0 = FILLED, fold deferred
; so a following infix operator can steal the last operand -- that deferral
; IS right-associativity), got = operands so far, reversed. out/pend thread
; as one (out . pend) chain through the helpers.
(: (op-fr o ch nm nd gt) (link o (link ch (link nm (link nd gt))))
   (op-fro f) (cap f) (op-frc f) (caup f) (op-frn f) (cauup f)
   (op-frd f) (cap (cuuup f)) (op-frg f) (cup (cuuup f))
   ; wrap the chain of arity-one names around a folded form
   (op-fin ch x) (? (two? ch) (link (cap ch) (link (op-fin (cup ch) x) 0)) x)
   ; fold a frame with whatever it has: nothing collected -> the plain
   ; symbol; a shortfall folds to the partial application (curry law). a
   ; frame at arity ONE (nil name: the whole op lives in the chain) wraps its
   ; lone operand.
   ; KIND tests throughout the walk, never truth: a collected operand list
   ; like (0) or ("") NETS zero, so nil? would read it as empty and drop
   ; the operand (the round-16 discipline: kinds for structure)
   (op-fold f) (? (atom? (op-frg f)) (op-fro f)
                  (nom? (op-frn f)) (op-fin (op-frc f) (link (op-frn f) (rev (op-frg f))))
                  (op-fin (op-frc f) (cap (op-frg f))))
   ; deliver datum d -> (out' . pend'). a collecting frame takes it; a FILLED
   ; frame folds into its parent first (cascading), then d delivers. a
   ; frame at one that fills folds AT ONCE -- ones bind tightest ($"ab" + 2
   ; is (+ ($ "ab") 2)); only infix frames sit FILLED, deferring
   ; their fold so a following operator can steal the last operand (that
   ; deferral IS right-associativity).
   (op-del d out pend)
    (? (atom? pend) (link (link d out) pend)
       (: f (cap pend)
          (? (< 0 (op-frd f))
             (: f2 (op-fr (op-fro f) (op-frc f) (op-frn f)
                          (- (op-frd f) 1) (link d (op-frg f)))
                ; (nil? ..), not !: this block is pre-opfix (the bootstrap restriction)
                (? (&& (= 0 (op-frd f2)) (nil? (nom? (op-frn f2))))
                   (op-del (op-fold f2) out (cup pend))
                   (link out (link f2 (cup pend)))))
             (: r (op-del (op-fold f) out (cup pend))
                (op-del d (cap r) (cup r))))))
   ; take a left operand if one is available -> (L . (out' . pend')), or 0.
   ; a FILLED top frame re-arms (need 1) and yields its last operand -- the
   ; C reader's A(F)=1 move; at top level the last finished datum is taken.
   (op-steal out pend)
    (? (two? pend)
       (: f (cap pend)
          (? (= 0 (op-frd f))
             (link (cap (op-frg f))
                   (link out (link (op-fr (op-fro f) (op-frc f) (op-frn f)
                                          1 (cup (op-frg f)))
                                   (cup pend))))
             0))
       (two? out) (link (cap out) (link (cup out) pend))
       0)
   ; drain at end of list: fold every pending frame innermost-out
   (op-drain out pend)
    (? (atom? pend) (rev out)
       (: r (op-del (op-fold (cap pend)) out (cup pend))
          (op-drain (cap r) (cup r))))
   (op-w l out pend)
    (? (atom? l) (op-drain out pend)
       (: e (cap l)
          (? (&& (nom? e) (op-puncp e))
             (: fs (opfactor e)
                (? (atom? fs)
                   (: r (op-del e out pend) (op-w (cup l) (cap r) (cup r)))
                   (: ch (map cap (init fs)) en (last fs) nm (cap en) n (cup en)
                      (? (= n 1)                       ; arity one (or a one-chain): prefix --
                         ; nil name, the op rides the chain: marks the frame to fold on fill
                         (op-w (cup l) out (link (op-fr e (cat ch (link nm 0)) 0 1 0) pend))
                         (: st (op-steal out pend)     ; infix: capture if a left operand exists
                            (? (two? st) (op-w (cup l) (cap (cup st))
                                        (link (op-fr e ch nm (- n 1) (link (cap st) 0))
                                              (cup (cup st))))
                               (two? ch)               ; composite with no left: prefix
                               (op-w (cup l) out (link (op-fr e ch nm 1 0) pend))
                               (: r (op-del e out pend) ; bare operator: the plain symbol
                                  (op-w (cup l) (cap r) (cup r)))))))))
             (: r (op-del (op-core e) out pend)
                (op-w (cup l) (cap r) (cup r))))))
   ; quasiquote: the template is data; only unquote operands re-enter the pass.
   ; (nested quasiquote is gone -- ` is the list constructor, `` is quasiquote -- so no depth.)
   (op-qq t)
    (? (atom? t) t
       (: h (cap t)
          (? (= h 'uq)  (link 'uq  (link (op-core (caup t)) 0))
             (= h 'uqs) (link 'uqs (link (op-core (caup t)) 0))
             (map (\ e (op-qq e)) t))))
   ; op-core: the factor pass. quote interiors are DATA and stay verbatim (so a
   ; quoted list keeps its operators as plain symbols); quasiquote descends
   ; only through unquotes; everything else walks. idempotent: factored
   ; output carries operators only in head position, where they read plain.
   (op-core x)
    (? (atom? x) x
       (: h (cap x)
          (? (&& (= h '\) (atom? (cuup x))) x
             (= h 'qq) (link 'qq (link (op-qq (caup x)) 0))
             ; the reader's glued-run emission (mono (run d)): factor the run
             ; monadically around the (recursively opfixed) datum; an
             ; unfactorable run is the plain application (run d)
             (&& (= h 'mono) (two? (cup x)) (two? (caup x)))
              (: p (caup x) r (cap p) d (op-core (caup p))
                 fs (? (nom? r) (monofactor r) 0)
                 (? (two? fs) (op-fin fs d) (link r (link d 0))))
             (op-w x 0 0)))))
; opfix = op-core, the operator factor pass. (Historically opfix also ran an
; optional native-codegen hook, bag['opjit]; that JIT experiment was retracted --
; its one real win, reduction reassociation, lives in the C builtins now, and the
; trampoline finding in ai/glaze/probe.l + the eat/toast nifs.)
(: (opfix x) (op-core x))
; eat -- run a toast's native code. the ARITY is the first operand and currying
; selects the eater: (eat 1 t x) passes one machine word, (eat 2 t x y) two. eat1/
; eat2 (the raw 1-/2-arg ABI nifs) are mopped post-egg and fold in here; only a
; toast is eatable and a faulting body returns 0 (the host fault barrier).
(: (eat n) (? (= n 2) eat2 eat1))
; the global RNG stream lives on bag ('rng-state) and advances by the pure
; rand-next/randf-next -- C holds no state and never draws. rng-get lazily
; clock-seeds on first use; rng-set validates and installs (the state, or nil
; if malformed). (rand n) -> fixnum in [0,n), n <= 0 (or non-fixnum) -> a
; full-width non-negative fixnum; (randf _) -> float in [0,1).
(: (rng-get _) (: st (peep bag 'rng-state 0)
                  (? (tray? st) st (: f (rng-seed (clock 0)) _ (pin bag 'rng-state f) f)))
   ; valid state = rank-1, length 4, and the platform's own limb type -- 64-bit
   ; limbs ride a Z array on a 64-bit word but a C (8-byte) array on a 32-bit
   ; one, so compare against a fresh seed's type, never a baked-in `z`.
   (rng-set st) (? (&& (tray? st) (= 1 (arank st)) (= 4 (alen st)) (= (atype (rng-seed 0)) (atype st)))
                   (: _ (pin bag 'rng-state st) st)
                   0)
   (rand n) (: r (rand-next (rng-get 0)) _ (pin bag 'rng-state (cup r))
               (? (&& (fix? n) (< 0 n)) (% (cap r) n) (cap r)))
   (randf _) (: r (randf-next (rng-get 0)) _ (pin bag 'rng-state (cup r)) (cap r)))
; readability / lisp-compat aliases by head-symbol substitution.
; do/begin/progn sequence side effects and return the last (identical to the
; current `,` macro -> `(: _ a _ b ... last)`); let -> the `:` let form;
; if/cond -> the `?` conditional.
(: seqx (\ l (link ': (foldr (\ l r (link '_ (link l r))) (list (last l)) (init l)))))
(:: 'do seqx) (:: 'begin seqx) (:: 'progn seqx)
(:: 'let (\ a (link ': a)))
(:: 'if (\ a (link '? a)))
(:: 'cond (\ a (link '? a)))
; `(quote x)` -> `(\ x)`: the CL/Scheme name for the one-arg-lambda quote (`'x` sugar).
(:: 'quote (\ a (link '\ a)))

; quasiquote: ``tmpl with ,x (unquote) and ,@xs (unquote-splice). The reader emits
; (qq tmpl), (uq x), (uqs xs). qqx/qql walk the template; every unquote FIRES (there
; is no nesting -- ` is the element-eval list constructor now, so no depth to track).
; qqx returns CODE that reconstructs the template (link/cat over the spliced values).
; uq is also bound to identity so a stray top-level ,x just evaluates its operand.
(: (qqx t) (?
    (atom? t)       (list '\ t)                              ; atom: quote it
    (= (cap t) 'uq) (caup t)                                 ; unquote: fire the value
                    (qql t))                                 ; other list
   (qql t) (?
    (atom? t) (qqx t)                                        ; nil / improper tail
    (&& (two? (cap t)) (= (caap t) 'uqs))
     (list 'cat (caup (cap t)) (qql (cup t)))                ; splice: fire
    (list 'link (qqx (cap t)) (qql (cup t)))))               ; ordinary element
(:: 'qq (\ a (qqx (cap a))))
(: uq (\ x x))                                               ; stray ,x evaluates x

; --- array element-type inference + shape coercion (shared by `tuple` and `array`).
; a-type: a WITNESS GEM of the element tier -- the highest of {Z<R<C<O} present in a
; list of values, returned as an inhabitant (0/0.0/~(0 0)/()) for `arr` to read the
; tier off (arr takes a witness, not a code). a box still fits z; a complex value lifts
; to a packed (re,im) `c` array; only a value past the real numeric tower (bignum,
; symbol, string, nested array, …) lifts the whole array to an object (o) array.
; a-dim/a-shape: a shape dimension may be any numeric -- a float, complex, or even
; a vector -- and is coerced to a nat by saturation (($ d) -- the count law:
; non-positive -> 0, a float ceils, a complex its modulus, a vector its net sum). a list
; shape is coerced per-dim; a lone numeric is a rank-1 length (so (array 2.5 …)
; means rank-1 length 3, (array ~(3 4) …) length 5).
(: (a-rank x) (? (float? x) 1 (| (fix? x) (full? x)) 0 (twin? x) 2 3)
   (a-emax m x) (: k (a-rank x) (? (< m k) k m))
   (a-type d) (: k (foldl a-emax 0 d) (? (= k 0) 0 (= k 1) 0.0 (= k 2) ~(0 0) ()))   ; a witness gem of the tier
   (a-dim d) (? (two? d) (tally d) (sat d))
   (a-shape s) (? (two? s) (map a-dim s) (L (a-dim s))))

; tuple/hash value constructors (also the read-back targets of the `@(…)` / `#(…)`
; printer-sugar forms). `tuple` builds a rank-1 array from its element args,
; inferring the element type via a-type (so it carries bignums/symbols in an o
; array, not just z/r); `map` builds a map from alternating key/value args.
(: (ltuple l) (arr (a-type l) (L (foldl (\ n _ (+ 1 n)) 0 l)) l))
(:: 'tuple (\ a (list 'ltuple (link 'list a))))
; (hash x) boxes any non-list -- a fresh mutable hash pinning x
; at 0, so #5 = #(0 5) and #() IS #0 (() is 0); chains pin as usual, and an odd
; trailing operand lands in the 0 box slot. the empty hash is (tablet 0).
(: (hashtx a) (? (atom? a) '(tablet 0)
                 (atom? (cup a)) (list 'pin (hashtx 0) 0 (cap a))
                 (list 'pin (hashtx (cuup a)) (cap a) (caup a))))
(:: 'hash (\ a (hashtx a)))


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
                        (\ x (a-coll sh (- n 1) (link x acc))))
   (array s) (: sh (a-shape s) (a-coll sh (foldl (*) 1 sh) 0)))

; recursive-value boxing for `:` (the letrec* "capture by location" fix).
; ONE SCOPE: every name bound in a `:` resolves locally over the whole form.
; `boxfix-core` takes a source-order (name . def) chain-list `prs` and the body
; expression. a reference to a name at-or-before its own (first) binding is a
; FORWARD reference; the name is indirected through a CELL -- a box (a fresh
; map, the # adjoint of :) keyed by the binding site's nom: prepend
; `cell (tablet 0)`, store via pin, read via (missing cell 'nom) -- the nif
; VALUES, not their names, so the rewrite survives the egg pulling names and
; user bindings shadowing them. a pre-fill read is a map miss, i.e. THE MISSING
; CONDITION with the binding-site nom as payload: a call for help, the zero point helpless --
; read-before-pin is one law at every depth, local or bag. a value binding
; boxes on ANY forward reference; a lambda binding only on a DIRECT (not
; under-lambda) one -- ordinary recursion keeps the lazy lane. values defined
; before their users are untouched. It returns 0 when nothing needs boxing,
; else the rewritten (prs' . body'). This is the single source of truth,
; shared verbatim by both compilers: ev.l's wev and c0 (ev.c) both call the
; flat `boxfix` wrapper below, bpr+flatten around the same core. `lambp`/`dsug`
; are globals so `ale` shares them (lambda detection, binding desugaring).
(: (lambp x) (? (two? x) (&& (= '\ (cap x)) (two? (cuup x)))) ; \ with >=1 param (one-operand \ is quote)
   (dsug n d) (? (atom? n) (link n d) (dsug (cap n) (link '\ (cat (cup n) (list d)))))
   (lp x) (: a (cup x) (? (atom? (cup a)) (link 0 (cap a)) (link (init a) (last a))))
   (ln bs) (? (atom? bs) 0 (atom? (cup bs)) 0 (link (cap (dsug (cap bs) 0)) (ln (cuup bs))))
   ; w/wl: does x / binding-list bs reference symbol v? multi-operand \ and
   ; : shadow; one-operand \ is quote (data, nothing free); macro expansion (so :- ?-
   ; &&/|| are seen as the compiler sees them). u tracks lambda depth; dm (direct
   ; mode) counts only references NOT under a lambda.
   (w v x bnd u dm) (?
    (nom? x) (&& (? dm (nil? u) 1) (= x v) (nil? (memq v bnd)))
    (atom? x) 0
    (: h (cap x) (?
      (= h '\) (? (atom? (cuup x)) 0 (: r (lp x) (w v (cup r) (cat (cap r) bnd) 1 dm)))
      (= h ':) (wl v (cup x) (cat (ln (cup x)) bnd) u dm)
      (: m (? (nom? h) (peep macros h 0) 0) (? m (w v (m (cup x)) bnd u dm) (any (\ e (w v e bnd u dm)) x))))))
   (wl v bs bnd u dm) (?
    (atom? bs) 0
    (atom? (cup bs)) (w v (cap bs) bnd u dm)
    (: nd (dsug (cap bs) (caup bs)) (? (w v (cup nd) bnd u dm) 1 (wl v (cuup bs) bnd u dm))))
   ; boxset: ONE SCOPE -- a reference at-or-before the name's own (first) binding
   ; is a forward reference and earns a cell. a value binding boxes on ANY such
   ; reference; a lambda binding only on a DIRECT one (not under a lambda), so
   ; ordinary recursion keeps the lazy lane.
   (boxset prs) (: nm (map cap prs)
     (filter (\ v (any (\ p (w v (cup p) 0 0 (lambp (cup (assq v prs)))))
                       (take (+ 1 (lidx v nm)) prs))) nm))
   (mkcs bx) (map (\ v (link v (link (nom 0) (nom v)))) bx)
   (cellbinds cs) (map (\ c (link (caup c) (list tablet 0))) cs))
; boxfix-core (c0): same prep + rewrites refs via sub/subl (c0 has no analysis-time
; redirect). Returns (prepped-prs . body') or 0.
(: (boxfix-core prs body) (:
   (rmc cs ns) (filter (\ p (nil? (memq (cap p) ns))) cs)
   (sub cs x) (?
    (nom? x) (: p (assq x cs) (? (two? p) (list missing (caup p) (list '\ (cuup p))) x))
    (atom? x) x
    (: h (cap x) (?
      (= h '\) (? (atom? (cuup x)) x (: r (lp x) (link '\ (cat (cap r) (list (sub (rmc cs (cap r)) (cup r)))))))
      (= h ':) (link ': (subl (rmc cs (ln (cup x))) (cup x)))
      (: m (? (nom? h) (peep macros h 0) 0) (? m (sub cs (m (cup x))) (map (\ e (sub cs e)) x))))))
   (subl cs bs) (?
    (atom? bs) bs
    (atom? (cup bs)) (list (sub cs (cap bs)))
    (: nd (dsug (cap bs) (caup bs)) (link (cap nd) (link (sub cs (cup nd)) (subl cs (cuup bs))))))
   (: bx (boxset prs)
      (? (nil? bx) 0
       (: cs (mkcs bx)
          (one p) (: d (sub cs (cup p))
                     (? (memq (cap p) bx)
                        (: c (assq (cap p) cs) (link '_ (list pin (caup c) (list '\ (cuup c)) d)))
                        (link (cap p) d)))
          (link (cat (cellbinds cs) (map one prs)) (sub cs body)))))))
; flat-list adapter for c0 (ev.c): a `:` binding list (n1 d1 .. [body]) -> the
; rewritten list, or the input unchanged. even (body-less) lets and lets that
; need no boxing pass through verbatim.
(: (boxfix fs) (:
   (ev l) (? (atom? l) 1 (atom? (cup l)) 0 (ev (cuup l)))
   (bpr fs) (? (atom? (cup fs)) (link 0 (cap fs))
               (: r (bpr (cuup fs)) (link (link (dsug (cap fs) (caup fs)) (cap r)) (cup r))))
   (? (ev fs) fs
    (: pb (bpr fs) r (boxfix-core (cap pb) (cup pb))
       (? r (cat (catmap (\ p (list (cap p) (cup p))) (cap r)) (list (cup r))) fs)))))
