; prel.l -- love prel: data, function and macro definitions.
; prefix only down to the `operators` table: c0 compiles this before opfix and the church
; add/mul hooks exist, and an operator up here cores the egg.
; FIXME move ev support functions to ev where possible
(: id 1
   (const x _) x
   (co f x y) (f y x)
   flip co
   link? two?
   name nom intern nom mint nom
   saturate sat)
(: : () ? () \ ())
(: e 2.718281828459045
   i (twin 0 1) ;; FIXME up top

   (atom? x) (nil? (two? x))
   one? atom?
   ; a fresh layer: its macro table at key 0, the pre-enter chain and name at charm key 31337,
   ; which no name can collide with. (enter ()) is anonymous.
   (enter nm) (: F (tablet 0) _ (pin F 0 (tablet 0)) _ (pin F 31337 (. (stack ()) nm))
                 _ (setstack (. F (stack ()))) ())

   ; unwind to the pre-enter chain, register the layer under its name, answer the book.
   ; a layer never entered has no chain: leave drops the one below the head instead.
   (leave _)  (: F (cap (stack ())) s (peep F 31337 ())
                 (? (two? s)
                    (: _ (pull F 31337 0) _ (setstack (cap s))
                       _ (? (nil? (cup s)) 0 (pin (lib ()) (cup s) F)) F)
                    (setstack (. F (cuup (stack ()))))))

   (caap x) (cap (cap x)) (caup x) (cap (cup x))
   (cuap x) (cup (cap x)) (cuup x) (cup (cup x))

 (cuuup x) (cup (cuup x)))
(: (gcd a b) (? (= b 0) (? (< a 0) (- 0 a) a) (gcd b (% a b)))
   (modpow b k m) (? (< k 1) 1 (: h (modpow b (// k 2) m) h2 (% (* h h) m)
                                 (? (= 0 (% k 2)) h2 (% (* h2 b) m)))))
; `::` defines a macro in the head layer's table, the same book a plain `:` defglobs to
(: ; look a macro up across the layer chain, the twin of tablet.c's stacklook_macro: keep in
   ; step. each book holds its table at key 0; a layer without one is skipped. 0 = no macro.
   (macros k) (: (go c) (? (nil? (two? c)) 0
                           (: m (peep (cap c) 0 ())
                              (? (tablet? m) (: v (peep m k 0) (? v v (go (cup c))))
                                 (go (cup c)))))
                 (go (stack ())))
   (:: a b) (: F (cap (stack ())) m (peep F 0 ())
               (pin (? (tablet? m) m (: t (tablet 0) _ (pin F 0 t) t)) a b))

)
; numfn lays the n-fold thread with spin/place, so applying a fixnum never re-enters the
; compiler. the helpers pass th/f/n explicitly: a closure over the forward-bound th
; miscompiles under c0.
(: (nfnest f i acc) (? (< i 1) acc (nfnest f (+ -1 i) (. f (. acc ()))))
   (nfq th f i n) (? (< i n) (: _ (place (+ 1 (* 2 i)) lvm_quote th) _ (poke (+ 2 (* 2 i)) f th) (nfq th f (+ 1 i) n)) th)
   (nfa th i n) (? (< i n) (: _ (place (+ (+ 3 (* 2 n)) i) lvm_ap th) (nfa th (+ 1 i) n)) th)
   (numfn n f) (:                                  ; build (\ x (f (f ... (f x)))), n f's
     src (. '\ (. 'x (. (nfnest f n 'x) ())))  ; alloc before spin
     th (spin (+ 5 (* 3 n)))                         ; [src] n*[quote f] [arg n] n*[ap] [ret 1]
     _ (poke 0 src th) _ (nfq th f 0 n)             ; no allocation past spin: th can't move
     _ (place (+ 1 (* 2 n)) lvm_arg th) _ (poke (+ 2 (* 2 n)) n th)   ; arg n: x, under n f's
     _ (nfa th 0 n)
     _ (place (+ 3 (* 3 n)) lvm_ret th) _ (poke (+ 4 (* 3 n)) 1 th)
   (seek 1 th))
   ;; FIXME rename | -> bit-or to free | for pipe operator
   (constellation? x) (| (charm? x) (packp x))   ; the whole numeric tower, trays too
   (whole? n) (| (charm? n) (sun? n))       ; integer-valued
   ; the machine word: a charm spends one bit, so the word reaches twice as far.
   ; what fits here fits an int tray cell.
   max-word (+ (* max-charm 2) 1)
   min-word (* min-charm 2)
   ; a tunable ceiling: a numeral compose count above it scares instead of allocating O(k).
   ; retune: (pin apcap 0 n).
   apcap (pin (tablet 0) 0 1048576)              ; a raw box: the brace's hash isn't built yet
   (ipow b k) (? (< k 1) 1 (: h (ipow b (// k 2)) h2 (* h h) (? (= 0 (% k 2)) h2 (* h2 b))))
   ; each site keeps its own (scare 'apcap k) as the cond result, so a recovering help's value
   ; is the result directly, no thunk on the hot path. don't factor it out.
   (apover k) (< (peep apcap 0 0) k)
   ; powover guards the result size, not the count: only an exact base beyond +-1 can grow, so it
   ; reads the box as a word budget (the stock 2^20 allows an 8MB number).
   (powover b m) (? (apover m)
                    (? (whole? b)
                       (: a (abs b)
                          (? (< a 2) 0
                             (< (* 64 (peep apcap 0 0)) (* m (/ (log a) (log 2))))))
                       0)
                    0)
   ; x ** n across the tower: a tray exponent -> fpow elementwise, an integer -> exact squaring
   ; (a negative one the reciprocal, so (-1 x) == (/ 1 x)), else the inexact `fpow`
   (powg x n) (? (tray? n) (fpow x n)
                 (whole? n) (: m (abs n)
                             (? (powover x m) (scare 'apcap m)
                                (< n 0) (/ 1 (ipow x m)) (ipow x m)))
                 (fpow x n))
   ; church application: a numeric operand gives x ** n, a function composes n times.
   ; keep cmp2..cmp8 straight-line: a counting applier measures ~45% slower at k=2..8.
   _ (: (cmp2 f x) (f (f x))
        (cmp3 f x) (f (f (f x)))
        (cmp4 f x) (f (f (f (f x))))
        (cmp5 f x) (f (f (f (f (f x)))))
        (cmp6 f x) (f (f (f (f (f (f x))))))
        (cmp7 f x) (f (f (f (f (f (f (f x)))))))
        (cmp8 f x) (f (f (f (f (f (f (f (f x))))))))
        ; frequency-ordered, so it stays a chain: a table would only pay past k=6
        (cmp k) (? (= k 2) cmp2 (= k 3) cmp3 (= k 4) cmp4 (= k 5) cmp5 (= k 6) cmp6 (= k 7) cmp7 (= k 8) cmp8 0)
        ; past cmp8 numfn lays a straight-line thread of 3n+5 cells; past nfcap that grows
        ; too big, so nfloop composes by counting instead
        (nfloop n f x) (? (< n 1) x (nfloop (+ -1 n) f (f x)))
        nfcap 1024
        ; a coin whose kind pins star is numeric by declaration, so a numeral powers it through
        ; its own * (ipow is generic). no size to read, so this lane keeps the count cap.
        (starred? x) (? (coin? x) (: e (kreg 0 (kind x)) (? (two? e) (= 1 (cup e 'star)) 0)) 0)
        (num-ap n x) (? (constellation? x) (powg x n)
                        (starred? x)
                        (? (whole? n) (: m (abs n)
                                         (? (apover m) (scare 'apcap m)
                                            (< n 0) (/ 1 (ipow x m)) (ipow x m)))
                           ())
                        (: k (saturate n)
                           (? (< k 1) 1 (= k 1) x
                              (apover k) (scare 'apcap k)
                              (: c (cmp k) (? c (c x) (< nfcap k) (nfloop k x) (numfn k x))))))
        (pin book 'num-ap num-ap)))
; seal-hook caches num-ap into the VM, so it must follow the pin above.
(seal-hook 0 num-ap)
; the + and * of two functions: the a threaded into both of arrange's operands is what
; makes + agree with church addition
(: (arrange f g a x) (f a (g a x))                ; (+ f g)
   (compose f g x) (f (g x))                      ; (* f g)
   _ (seal-hook 1 arrange)
   _ (seal-hook 2 compose))
; map runs left to right
(: (map f l) (? (two? l) ((\ f x l (. x (map f l))) f (f (cap l)) (cup l)))
   (foldl f z l) (? (two? l) (foldl f (f z (cap l)) (cup l)) z)
   (foldr f z l) (? (two? l) (f (cap l) (foldr f z (cup l))) z)
   ; (rev l) glued onto acc in one pass
   (revcat l acc) (? (two? l) (revcat (cup l) (. (cap l) acc)) acc))
; the monadic words behind the glued sigils. a starred coin nets itself, else its kind's 'net
; measures it, else its payload. net (. a b) = net a + net b at every link.
; measure is what C's truth asks of a compound (hook 5): net, with a starred coin read by its
; 'net too -- net keeps it whole so a sum of rationals stays rational, truth wants its sign
(: (netsum a l) (? (two? l) (netsum (+ a (net (cap l))) (cup l)) (+ a (net l)))
   (ktab x) (: e (kreg 0 (kind x)) (? (two? e) (cup e) ()))
   ; an object tray (atype 3) nets its elements; peep reads a flat index at rank 1 and a
   ; row-major coordinate list above it
   (onet x) (: sh (shape x) n (prod sh)
              (dec i s) (? (two? (cup s)) (: r (prod (cup s)) (. (// i r) (dec (% i r) (cup s)))) (. i ()))
              (go i a) (? (< i n) (go (+ i 1) (+ a (net (peep x (? (two? (cup sh)) (dec i sh) i) ())))) a)
              (go 0 0))
   (net x) (? (tray? x) (? (= 3 (atype x)) (onet x) (asum x))
              (constellation? x) x
              (two? x) (netsum 0 x)
              (coin? x) (: t (ktab x) f (t 'net)
                           (? (= 1 (t 'star)) x                 ; starred: the fixpoint
                              (lit? f) (f x)                    ; the kind's own measure
                              (net (load x))))
              (saturate x))
   (measure x) (? (coin? x) (: f (ktab x 'net) (? (lit? f) (f x) (net x)))
                  (net x))
   _ (seal-hook 5 measure)
   (prod x) (? (tray? x) (aprod x)
               (two? x) (foldl (\ a e (* a (prod e))) 1 x)
               x)
   negate (- 0)
   reciprocal (/ 1)
   (fraction x) (% x 1)
   (bit x) (nil? (nil? x))
   (!== a b) (nil? (== a b))
   ; a star is the fixpoint of net. ==, not `=`: a tray's net is a fresh sum, so star? and
   ; galaxy? stay disjoint
   (star? x) (== x (net x))
)
(: (filter p l) (? (two? l) (: m (filter p (cup l)) (? (p (cap l)) (. (cap l) m) m)))
   (init l) (? (two? (cup l)) (. (cap l) (init (cup l))))
   (last l) (? (two? (cup l)) (last (cup l)) (cap l))
   (each l f) (? (two? l) (: _ (f (cap l)) (each (cup l) f)))
   (ldel x l) (? (two? l) (? (= (cap l) x) (cup l) (. (cap l) (ldel x (cup l)))))
   (all f l) (? (two? l) (? (f (cap l)) (all f (cup l)) 0) 1)   ; truth bits (0/1), not ()
   (any f l) (? (two? l) (? (f (cap l)) 1 (any f (cup l))) 0)
   ; iterate `step` until `size` stops changing. size must be strictly monotone under step until
   ; the fixpoint, and is read before the step, so a step that mutates in place is still seen.
   (monofix st step size) (: b (size st) nx (step st) (? (= (size nx) b) nx (monofix nx step size)))

   ; the one constant-form recognizer: (1 . value) or (), wrapped because a constant's value
   ; can itself be nothing. no `&&`: c0 is single-pass and it is defined later.
   (kconst e) (? (nom? e) ()
                 (atom? e) (. 1 e)
                 (== (cap e) '\) (? (atom? (cuup e)) (. 1 (caup e))))    ; (\ v), a quoted atom; a real lambda -> ()
   (cat a b) (foldr (.) b a))
; cats is the foldr of + over a list, in C when its pieces are all strings or all lists and
; this fold for the rest. so catmap concatenates lists and joins strings; () is the unit of both.
(seal-hook 7 (\ l (foldr (+) () l)))
(: (catmap f l) (cats (map f l))
   (assoc x l) (? (two? l) (? (= x (caap l)) (cap l) (assoc x (cup l))))
   ; assoc by identity, for a nom or charm key
   (assq x l) (? (two? l) (? (== x (caap l)) (cap l) (assq x (cup l))))
   (lidx x) ((: (f n l) (? (two? l) (? (= x (cap l)) n (f (+ 1 n) (cup l))) -1)) 0)
   (zip a b) (? (two? a) (? (two? b) (. (. (cap a) (cap b)) (zip (cup a) (cup b)))))
   (rev l) (revcat l ())
   ; every nom on the layer chain, deduped. noms only: a layer's keys also hold the macro
   ; table and the unwind chain
   (names _) (filter nom? (keys (foldl (\ t k (pin t k 1)) (tablet 0) (catmap keys (stack ())))))

   ; the range 0..x-1 (iota its tray twin), lifted over a list so ^^3 is (jot (jot 3))
   (jot x) (? (two? x) (map jot x) (: n (saturate x) (go i) (? (< i n) (. i (go (+ i 1)))) (go 0)))
   (drop n l) (? n (drop (- n 1) (cup l)) l)
   (take n l) (? n (? (two? l) (. (cap l) (take (- n 1) (cup l)))))   ; stops at the end of l
)

; jot's counted twins: ev's fold calls one in a walker's place when its list operand is (jot x),
; the same calls in the same order, the range never built. x as jot reads it, a list by jot itself.
; jotfuse maps a walker, by value and by name, to [k arity twin], k the list operand's place;
; 'jot -> jot, which a walker's value never is. the glaze keys the walkers it re-declares
(: jotfuse (tablet 0)
   _ (: (foldn f z x) (? (two? x) (foldl f z (jot x)) (: n (saturate x) (go i a) (? (< i n) (go (+ i 1) (f a i)) a) (go 0 z)))
        (foldrn f z x) (? (two? x) (foldr f z (jot x)) (: n (saturate x) (go i) (? (< i n) (f i (go (+ i 1))) z) (go 0)))
        (eachn x f) (? (two? x) (each (jot x) f) (: n (saturate x) (go i) (? (< i n) (: _ (f i) (go (+ i 1)))) (go 0)))
        (mapn f x) (? (two? x) (map f (jot x)) (: n (saturate x) (go i a) (? (< i n) (go (+ i 1) (. (f i) a)) (rev a)) (go 0 ())))
        (fuse w nm k ar t) (: e (. k (. ar (. t ()))) _ (pin jotfuse nm e) (pin jotfuse w e))
        _ (pin jotfuse 'jot jot)
        _ (fuse foldl 'foldl 2 3 foldn)
        _ (fuse foldr 'foldr 2 3 foldrn)
        _ (fuse each 'each 0 2 eachn)
        (fuse map 'map 1 2 mapn)))

(: l (foldr (\ a l (. (.) (. a (. l ())))) ()) (:: 'list l))
; connectives answer one of their operands: && the first falsy one, || the first truthy one,
; else the last; each operand evaluates once
(:: '&& (\ l (: (and l) (? (two? (cup l)) (: y (nom 0) (list ': y (cap l) (list '? y (and (cup l)) y))) (cap l)) (? (two? l) (and l) 1))))
(:: '|| (\ l (: (or l) (? (two? (cup l)) (: y (nom 0) (list ': y (cap l) (list '? y y (or (cup l))))) (cap l)) (? (two? l) (or l) 0))))
; end weighting: the head argument moves to the tail, so the form a long body would have
; buried is read first. the expansion is opfixed, so a destructuring head lowers as under `:`
(:: ':- (\ a (. ': (cat (cup a) (. (cap a) ())))))
(:: '?- (\ a (. '? (cat (cup a) (. (cap a) ())))))
; @ carries a subject the other two lack, so @- moves the second argument, not the
; first: (x @- dflt p v ..) is (x @ p v .. dflt), and the subject stays where it reads.
(:: '@- (\ a (. '@ (. (cap a) (cat (cuup a) (. (caup a) ()))))))

; (pins t k v ..): pin each pair onto an existing tablet; an odd trailing operand is dropped
(:: 'pins (\ l (: (go t r) (? (two? (cup r)) (go (list pin t (cap r) (caup r)) (cuup r)) t)
                  (go (cap l) (cup l)))))

(: (** a b) (? (tray? b) (fpow a b) (b a))      ; a tray applied indexes, so its power is fpow's
   $ 1 ! nil?  (!= a b) (- 1 (= a b))                 ; a bit, or a tray's mask, flipped
   ; `nil?`, not glued `!`: a glued sigil factors through mono, bound further down
   (nelem x l) (nil? (elem x l)))

; lisp compatibility synonyms
(: seqx (\ l (. ': (foldr (\ l r (. '_ (. l r))) (list (last l)) (init l))))
   ifx (. '?) letx (. ':) lamx (. '\ )
   _ (:: ', seqx) _ (:: 'do seqx) _ (:: 'begin seqx) _ (:: 'progn seqx)
   _ (:: 'let letx)
   _ (:: 'cond ifx) _ (:: 'if ifx)
   _ (:: 'quote lamx) _ (:: 'lambda lamx))

; --- module: filesystem-free definition --------------------------------------
; (module 'nm form ..): open nm's layer -- the registered tablet on a reopen, a fresh one
; otherwise -- eval each form there, leave registers; answers the tablet. (module () ..) is
; a scratch layer, registered nowhere. each form compiles at its eval, after the open, so
; bindings defglob into the module layer and a macro form serves the next form, not its own.
(: _
 (: (mopen nm) (: r (? (nil? nm) () (peep (lib ()) nm ()))
                  F (? (tablet? r) r (: t (tablet 0) _ (pin t 0 (tablet 0)) t))
                  _ (pin F 31337 (. (stack ()) nm))
                  (setstack (. F (stack ()))))
    ; a list head is (name export..): every nom the body added and did not name is pulled off
    ; the tablet; what it held at the open stays (C rows, an earlier opening's exports).
    ; quote the list head: unquoted, an operator nom in it re-associates the list under opfix
    (mrun nm fs) (: n  (? (two? nm) (cap nm) nm)
                     xs (? (two? nm) (cup nm) ())
                     _  (mopen n)
                     F  (cap (stack ()))
                     ks (keys F)
                     _  (each fs (\ f (ev 'ev f)))
                     _  (? (two? xs)
                           (each (keys F) (\ k (? (nom? k) (? (elem k xs) 0 (elem k ks) 0 (pull F k 0)) 0)))
                           0)
                     (leave ()))
    ; quote the forms list whole, one element per form. 'x reads as (\ x), so unwrap one.
    (:: 'module (\ l (: h (cap l)
                        n (? (two? h) (? (== (cap h) '\) (caup h) h) h)
                        (list mrun (list '\ n) (list '\ (cup l))))))))

; --- reader operators: the operators tablet + the opfix factor pass ---------
(: operators (pins (tablet 0)
 0 (pins (tablet 0)                                 ; --- arity 0: glued. takes nothing from the form
 '< cap '> cup '+ net '* prod '| abs '- negate '/ reciprocal
 '% fraction '? bit '$ sat '! nil? '^ jot
 '# tally '~ conj
 '0? nil? '1? atom? '2? two?)                   ; a row may spell digits: 2?<>x is (two? (cap (cup x)))
 1 (tablet 0)                                       ; --- arity 1: a right operand and no left. no walk yet
 2 (pins (tablet 0)                                 ; --- arity 2: spaced. a left operand and a right
 '~ '(twin 99)                                      ; tightest, so a complex literal binds before any operator
 '/// 99                                           ; the rational, the twin's peer
 '** 70
 '* -60 '/ -60 '% -60 '// -60                       ; a negative band is left-handed
 '+ -50 '- -50
 '<< -47 '>> -47
 '& -46 '^ -45 '| -44                               ; bitwise, C's order
 '&& 31 '|| 30
 '. 25
 '$ 5 '\ 5)                                         ; weak apply and the lambda, one band: at equal band the
                                                    ; right hand yields, (map $ a \ f a) is (map (\ a (f a)))
 -1 (pins (tablet 0)                                ; --- arity -1: spaced, no bound. a left, then all of them
 '? 10 '@ 10 '@- 10                                 ; every arm stays an operand; :- and ?- are prefix-only
 ': 3 ':= ':)                                       ; := is a bare nom, an alias of `:` and its band
 -2 (pins (tablet 0)                                ; --- arity -2: spaced, and it chains. a left and a right, but
 '= 40 '!= 40 '< 40 '<= 40 '> 40 '>= 40 '== 40 '!== 40)))          ; a same-band neighbour joins the run instead of nesting
 ; the spaced rows are noms, so a binding of the sigil is seen by the text that uses it. the
 ; glued lane holds values -- `<x` is the function `cap` -- so a local `cap` cannot re-aim it

; value -> the word the glued sigil means, and the walk that puts the words back through a
; factored form, for every reader of post-opfix source that wants noms
(: opnoms (pins (tablet 0)
   cap 'cap cup 'cup net 'net prod 'prod abs 'abs negate 'negate
   reciprocal 'reciprocal fraction 'fraction bit 'bit sat 'sat
   nil? 'nil? jot 'jot atom? 'atom? two? 'two? tally 'tally conj 'conj)
   (opnom v) (? (two? v) 0 (peep opnoms v 0))       ; a list is never a row; keep it off the hash
   (opword v) (: n (opnom v) (? n n v))             ; the word, or v untouched
   (unglue x) (? (nil? (two? x)) x
                 (. (: h (cap x) n (opnom h) (? n n (unglue h)))
                       (ungluet (cup x))))
   (ungluet l) (? (nil? (two? l)) l (. (unglue (cap l)) (ungluet (cup l))))
   _ (pin book 'opnom opnom)
   _ (pin book 'opword opword)
   (pin book 'unglue unglue))

;;; FIXME the code below is rather old and hoary and can probably be freshened up.
;;; remember we can't use operators or pattern matching yet here though.
;;; catalog all the op-* functions,
(: ; the lanes are the tablets in `operators`, not copies, so a `grip` write is seen here at once
   monadics (operators 0) dyadics (operators 2) naries (operators -1) chains (operators -2)
   (op-punc-byte c) (? (&& (<= 97 c) (<= c 122)) 0
                       (&& (<= 48 c) (<= c 57)) 0
                       (&& (<= 65 c) (<= c 90)) 0
                       (= c 95) 0
                       1)
   ; only an all-punct symbol can factor. the four ranges above run commonest-first
   (op-puncp x)
    (? (nom? x)
       (: s (string x)
          (? (string? s) ;;; FIXME string should *always* return a string, if !(string? (string x)) that's a bug
             (: n (tally s)
                (? (< 0 n)
                   ((: (go i) (? (< i n) (? (op-punc-byte (s i)) (go (+ 1 i)) 0) 1)) 0)
                   0))
             0)) ;;; FIXME dangling 0 clauses like these are bad end-weight coding and
       0) ;;; they may not even be semantically needed since ? fall-through returns ()

   ; a band is a signed charm: the magnitude is the level (higher binds tighter), the sign the
   ; hand, negative left. never 0: a tablet miss answers 0.
   (op-band? b) (&& (charm? b) (nil? (= 0 b)))   ; != is not a function yet
   (op-row nm b ar) (. nm (. (abs b) (. (? (< b 0) 1 0) ar)))       ; -> (name band hand . arity)
   ; an alias tail: (nom band) as a list, since `.` has no row yet up here; a pair reads too
   (op-tail v) (? (charm? (cup v)) (cup v) (&& (two? (cup v)) (charm? (caup v))) (caup v) 0)
   ; k's row in the spaced lane t of arity ar -> (name band hand . ar), or 0. a charm is the band;
   ; a nom is an alias, one hop, so none can cycle; a (nom band) pair is an alias with its own
   ; band, for a target that has no row to lend
   (op-lane k t ar)
    (: v (t k)
       (? (op-band? v) (op-row k v ar)
          (nom? v) (: b (t v) (? (op-band? b) (op-row v b ar) 0))
          (? (two? v) (nom? (cap v)) 0) (: b (op-tail v) (? (op-band? b) (op-row (cap v) b ar) 0))
          0))
   ; a nom in two spaced lanes reads as the first asked. arity 1 has no walk, so is never asked
   (op-ent k) (: d (op-lane k dyadics 2)
                 (? (two? d) d (: c (op-lane k chains -2) (? (two? c) c (op-lane k naries -1)))))
   (op-chain? k) (two? (op-lane k chains -2))
   ; factor nm[0..j) against the monadic table onto acc -> the word list (outermost first), or 0.
   ; right to left, longest first, so on "abc" rows `a` `bc` beat `ab` `c`; it backtracks, so a
   ; run factors iff some split exists and an unfactorable one falls through to plain application.
   ; a hit is asked out of band against the miss answer -- truth would drop a word netting nothing.
   (mono-go nm j acc)
    (? (< 0 j)
       ((: (try k)
           (? (< k 1) ()
              (: e (monadics (intern (snip nm (- j k) j)))
                 (? (== () e) (try (- k 1))
                    (: r (mono-go nm (- j k) (. e acc)) (? (two? r) r (try (- k 1))))))))
        j)
       acc)
   (monofactor s) (: nm (string s) (mono-go nm (tally nm) ()))
; the walk. a pending-operator frame is (orig name need band . got) -- source symbol, resolved
; name, operands still wanted, captured band, operands so far reversed; out/pend = (out . pend).
; need 0 is filled with the fold deferred, so a later operator can steal the last operand (that
; deferral is right-associativity); -1 is that steal spent, growing a span; -2 is n-ary, never
; fills.
   (op-fr o nm nd g gt) (. o (. nm (. nd (. g gt))))
   (op-fro f) (cap f) (op-frn f) (caup f)
   (op-frd f) (cap (cuup f)) (op-frband f) (cap (cuuup f)) (op-frg f) (cup (cuuup f))
   ; a frame is only rebuilt with a new need + got
   (op-frw f nd g) (op-fr (op-fro f) (op-frn f) nd (op-frband f) g)
   ; wrap a chain of monadic words around a datum, outermost first
   (op-fin ch x) (? (two? ch) (. (cap ch) (. (op-fin (cup ch) x) ())) x)
   ; fold a collected span (out, reversed) into one operand: a lone datum stays itself, more
   ; become an application
   (op-span out) (? (two? (cup out)) (rev out) (cap out))
   ; the binders fold back through op-core, lowering as the prefix spelling does. a `:` chain is
   ; one scope: op-steal's nesting splices flat, so (a : 1 b : 2 (a + b)) is (: a 1 b 2 (a + b))
   (op-cl-splice fs)
    (? (atom? (cup fs))
       (: b (cap fs)
          (? (&& (two? b) (== (cap b) ':)) (cup b) fs))
       (. (cap fs) (op-cl-splice (cup fs))))
   ; a chain, arity -2: (a < b <= c) is (a < b) and (b <= c), a shared compound operand bound so
   ; it evaluates once, inside the conjunction so && still short-circuits. os is (a b op c op d ..):
   ; the head operator is the frame's name, later ones inline.
   (op-chn-rest pv r)                                        ; r = (op z op z ..), or a dangling op
    (? (atom? r) 0
       (: op (cap r)
          (? (atom? (cup r)) (. op (. pv ()))              ; a trailing operator: the curry law, per link
             (: z (caup r) v (? (atom? z) z (nom 0))
                e (. op (. pv (. v ()))) t (op-chn-rest v (cuup r))
                bd (? (two? t) (. '&& (. e (. t ()))) e)
                (? (== v z) bd (. ': (. v (. z (. bd ())))))))))
   ; the whole run wears a `bit`, so a chain answers 0 or 1 whichever operand && hands back;
   ; it sits outside the binds, so the short-circuit and evaluation order hold
   (op-chn nm os)
    (: a (cap os) b (caup os) u (? (atom? a) a (nom 0)) v (? (atom? b) b (nom 0))
       e (. nm (. u (. v ()))) t (op-chn-rest v (cuup os))
       bd (? (two? t) (. '&& (. e (. t ()))) e)
       b2 (? (== v b) bd (. ': (. v (. b (. bd ())))))
       b3 (? (== u a) b2 (. ': (. u (. a (. b2 ())))))
       (. 'bit (. b3 ())))
   ; fold a frame with what it has: nothing collected gives the plain symbol, a shortfall the
   ; partial application. kind tests throughout the walk, never truth: (0) or ("") nets zero.
   ; an operator symbol as an operand is wrapped, (x), or the next pass reads it infix again
   (op-val o) (? (op-puncp o) (. o ()) o)
   (op-fold dn f) (? (atom? (op-frg f)) (op-fro f)
                  (: nm (op-frn f) os (rev (op-frg f))
                     (? (== nm '\) (op-core dn (. '\ os))
                        (== nm ':) (op-core dn (. ': (op-cl-splice os)))
                        (&& (two? (cup os)) (&& (two? (cuup os)) (op-chain? nm))) (op-chn nm os)
                        (. nm (map op-val os)))))
   ; deliver datum d -> (out' . pend'). a collecting frame takes it; a filled infix frame extends
   ; its right operand into a span: (a = b c) is (= a (b c)). need 0 = a lone datum, -1 = growing
   (op-del d out pend)
    (? (atom? pend) (. (. d out) pend)
       (: f (cap pend) nd (op-frd f)
          (? (= nd -2) (. out (. (op-frw f -2 (. d (op-frg f))) (cup pend)))  ; n-ary: a new operand, always
             (< 0 nd)  (. out (. (op-frw f (- nd 1) (. d (op-frg f))) (cup pend)))
             (: op (cap (op-frg f))                          ; the frame's right operand
                nx (? (= 0 nd) (. op (. d ()))
                      (cat op (. d ())))
                f2 (op-frw f -1 (. nx (cup (op-frg f))))
                (. out (. f2 (cup pend)))))))
   ; take a left operand for an incoming operator of band g and hand h -> (. (out' . pend')), or 0.
   ; at equal band the incomer's hand decides: right-handed steals, left-handed yields. at top
   ; level the whole leading span is taken: (a b = c) captures (a b), not just b. an n-ary frame
   ; holding only its scrutinee has none to give, which keeps (c ? a + b) reading (? c (+ a b)).
   (op-steal dn g h out pend)
    (? (two? pend)
       (: f (cap pend) nd (op-frd f)
          (? (< nd 1)
             (? (? h (<= g (op-frband f)) (< g (op-frband f)))
                (: r (op-del (op-fold dn f) out (cup pend)) (op-steal dn g h (cap r) (cup r)))
                (? (? (= nd -2) (atom? (cup (op-frg f))) 0) 0
                   (. (cap (op-frg f))
                         (. out (. (op-frw f (? (= nd -2) -2 1) (cup (op-frg f))) (cup pend))))))
             0))
       (two? out) (. (op-span out) (. () pend))
       0)
   ; fold every pending frame tighter than an incoming (g,h) -> (out . pend): op-steal's climb,
   ; split out so the chain join sees the frame it meets, as in (a < b + c < d)
   (op-climb dn g h out pend)
    (? (&& (two? pend) (&& (< (op-frd (cap pend)) 1)
                           (? h (<= g (op-frband (cap pend))) (< g (op-frband (cap pend))))))
       (: r (op-del (op-fold dn (cap pend)) out (cup pend)) (op-climb dn g h (cap r) (cup r))) (. out pend))
   ; drain at end of list: fold every pending frame innermost-out
   (op-drain dn out pend)
    (? (atom? pend) (rev out)
       (: r (op-del (op-fold dn (cap pend)) out (cup pend))
          (op-drain dn (cap r) (cup r))))
   (op-w dn l out pend)
    (? (atom? l) (op-drain dn out pend)
       (: e (cap l)
          (? (op-puncp e)
             ; an unrowed sigil takes the house band, and with no left operand still folds
             ; to the plain symbol
             (: en0 (op-ent e)
                en (? (two? en0) en0 (. e (. 95 (. 0 2))))   ; (e house right . arity 2)
                nm (cap en) gp (caup en) hd (cap (cuup en))
                ; fresh noms: this `:` is one scope, so rebinding out/pend here would make the
                ; op-climb call read its own later binding
                cl (op-climb dn gp hd out pend) ou (cap cl) pd (cup cl)
                st (op-steal dn gp hd ou pd)
                ; the join: a chainable sigil meeting a filled chainable frame at its own band
                ; pushes its nom into that frame's got and asks for one more, so the run stays
                ; flat. filled is need below 1, not need 0: (97 <= s 0 <= 122) grows a span, -1
                (? (&& (= -2 (cup (cuup en)))
                       (&& (two? pd)
                           (&& (< (op-frd (cap pd)) 1)
                               (&& (= gp (op-frband (cap pd))) (op-chain? (op-frn (cap pd)))))))
                    (op-w dn (cup l) ou (. (op-frw (cap pd) 1 (. nm (op-frg (cap pd)))) (cup pd)))
                   (two? st) (op-w dn (cup l) (caup st)
                            (. (op-fr e nm (? (= -1 (cup (cuup en))) -2 1) gp (. (cap st) ()))   ; -2 = n-ary: the row's lane, so an alias inherits it
                                  (cuup st)))
                   (: r (op-del e ou pd)     ; no left operand: the plain symbol
                      (op-w dn (cup l) (cap r) (cup r)))))
             (: r (op-del (op-core dn e) out pend)
                (op-w dn (cup l) (cap r) (cup r))))))
   ; a `:` binds, it does not apply: binders stay verbatim but for `_`, and only each pair's
   ; value and the trailing body factor. the pairing matches eval's.
   (op-colon dn fs)
    (? (atom? fs) fs
       (atom? (cup fs)) (. (op-core dn (cap fs)) ())        ; a lone form is the body
       (: r (op-dpb (cap fs))                             ; define-sugar binds a \ too: lower its patterns
          (. (cap r)
                (. (op-core dn (op-wrap (cup r) (caup fs))) ; the value: wrapped, then factored
                      (op-colon dn (cuup fs))))))
   ; a \ lambda: the args stay verbatim, only the body factors. (\ x) is quote, kept whole by op-core
   (op-lam dn fs)
    (? (atom? (cup fs)) (. (op-core dn (cap fs)) ())
       (. (cap fs) (op-lam dn (cup fs))))
   ; a param that is not a nom is a pattern: (\ [a b] x) is (\ v (@ v [a b] x)), v fresh. it
   ; emits the `@` symbol and stops; pat expands it at the reader's own compile.
   (op-wrap ws b) (? (atom? ws) b
                     (op-wrap (cup ws) (. (nom "@") (. (caap ws) (. (caup (cap ws))
                                                       (. b ()))))))
   ; a `_` binder binds nothing: it takes a fresh nom no body can spell, so a read of `_` misses
   (op-un p) (? (== p '_) (nom 0) p)
   (op-depat ol ws)
    (? (atom? (cup ol)) (. (op-wrap ws (cap ol)) ())          ; the body: wrapped outermost-last
       (: p (cap ol)
          (? (nom? p) (. (op-un p) (op-depat (cup ol) ws))
             (: v (nom 0) (. v (op-depat (cup ol) (. (. v (. p ())) ws)))))))
   ; the same over a param list with no body -> (params . wraps)
   (op-dp ol ws)
    (? (atom? ol) (. () ws)
       (: p (cap ol)
          (? (nom? p) (: r (op-dp (cup ol) ws) (. (. (op-un p) (cap r)) (cup r)))
             (: v (nom 0) r (op-dp (cup ol) (. (. v (. p ())) ws))
                (. (. v (cap r)) (cup r))))))
   ; a define-sugar binder is a lambda: (: (f [a b]) V ..) is (: (f v) (@ v [a b] V) ..).
   ; position 0 is the name, or the curried binder carrying it; every later position lowers.
   ; a curried binder's inner params come first, so its wraps go outside this level's.
   (op-dpb b)
    (? (atom? b) (. (op-un b) ())
       (: hr (op-dpb (cap b)) pr (op-dp (cup b) ())
          (. (. (cap hr) (cap pr)) (cat (cup pr) (cup hr)))))
   ; flatten a directly-nested lambda body -- (\ a (\ b B)) -> (\ a b B) -- so neither compiler
   ; builds the extra closure. shadowing stays nested: (\ x (\ x x)) must not merge.
   (op-mem? y l)      (? (atom? l) 0 (== y (cap l)) 1 (op-mem? y (cup l)))
   (op-disjoint? a b) (? (atom? b) 1 (op-mem? (cap b) a) 0 (op-disjoint? a (cup b)))
   (op-params ol)     (? (atom? (cup ol)) () (. (cap ol) (op-params (cup ol))))
   ; the inner lambda's patterns lower before the shadow check, so it compares noms:
   ; (\ [a b] (\ a x)) must not merge
   (op-flat-ol ol seen)                                      ; -> the flattened operand list, body left raw
    (? (atom? (cup ol))
       (: b (cap ol)
          (? (&& (two? b) (== (cap b) '\) (two? (cuup b)))  ; a real lambda, not quote
             (: ol2 (op-depat (cup b) ())
                (? (op-disjoint? seen (op-params ol2)) (op-flat-ol ol2 seen) ol))
             ol))
       (. (cap ol) (op-flat-ol (cup ol) (. (cap ol) seen))))
   ; the comma layer, the loosest grouping, above infix and `:`: (a, b c) -> (, a (b c)), the
   ; `,` macro; empty clauses drop. the symbol is interned, never written literally.
   (op-cm? l)   (? (atom? l) 0 (== (cap l) ',) 1 (op-cm? (cup l)))
   (op-take l)  (? (atom? l) () (== (cap l) ',) () (. (cap l) (op-take (cup l))))
   (op-drop l)  (? (atom? l) () (== (cap l) ',) (cup l) (op-drop (cup l)))
   (op-split l) (: c (op-take l) r (? (op-cm? l) (op-split (op-drop l)) ())
                   (? (two? c) (. c r) r))
   ; op-core: the factor pass. quote interiors stay verbatim, binding forms keep their binders,
   ; everything else walks. idempotent. has-top-op? gates the lone-operand splice: a bare
   ; list-of-one like ((mov r3 r12)) is data and stays wrapped.
   (has-top-op? x) (? (atom? x) 0 (op-puncp (cap x)) 1 (has-top-op? (cup x)))
   ; map in place: an unchanged list answers itself
   (op-mapi f x) (? (atom? x) x (: e (f (cap x)) r (op-mapi f (cup x)) (? (&& (== e (cap x)) (== r (cup x))) x (. e r))))
   ; dn: subtrees already factored, met by identity and kept whole
   (op-done? x dn) (? (atom? dn) 0 (== x (cap dn)) 1 (op-done? x (cup dn)))
   (op-core dn x)
    (? (atom? x) x
       (op-done? x dn) x
       (: h (cap x)
          (? (&& (== h '\) (atom? (cuup x))) x              ; (\) / (\ x): quote, verbatim
             (op-cm? (cup x))
              (: cs (op-split x)
                 (? (atom? cs) ()                            ; commas alone: nothing
                    (atom? (cup cs)) (op-core dn (cap cs))
                    (. (nom ",") (map (op-core dn) cs))))
             (== h '\) (. '\ (op-lam dn (op-flat-ol (op-depat (cup x) ()) ())))
             (== h ':) (. ': (op-colon dn (cup x)))
             ; the reader's glued run (mono (run d)): factor the run monadically around the
             ; factored datum; an unfactorable run is the plain application (run d)
             (&& (== h 'mono) (two? (cup x)) (two? (caup x)))
              (: p (caup x) r (cap p) d (op-core dn (caup p))
                 fs (? (nom? r) (monofactor r) 0)
                 (? (two? fs) (op-fin fs d) (. r (. d ()))))
             (nil? (has-top-op? x)) (op-mapi (op-core dn) x)
             (: res (op-w dn x 0 0)
                (? (&& (two? res) (atom? (cup res)) (two? (cap res))) (cap res) res))))) ; (a = b) -> (= a b), not ((= a b))
   (opfix x) (op-core () x)
   ; x factored where dn's subtrees, already factored, stand: a macro's expansion, whose
   ; operands came in factored, costs only its own cells
   (opfix-past x dn) (op-core dn x)

   ; the grip door: the one write into the operator table, and its only reach once the egg mops
   ; `operators`. (grip ar nm v) answers the row it replaced, so (grip ar nm (grip ar nm new))
   ; restores; () clears a row. a shape the lane refuses rolls back and scares; a lane with no
   ; key is refused. the glued lane accepts anything: a value there is the emitted head.
   (op-lane-ok? t ar nm) (? (= ar 0) 1 (two? (op-lane nm t ar)))
   (grip ar nm v)
    (: t (operators ar)
       (? (nil? (nom? nm)) (scare 'bad-grip nm)
          (nil? (tablet? t)) (scare 'bad-grip ar)
          (: old (peep t nm ())
             ; identity, never truth: a left-handed band is negative, and (nil? -60) is true
             (? (== () v) (: _ (pull t nm 0) old)
                (: _ (pin t nm v)
                   (? (op-lane-ok? t ar nm) old                      ; the lane's own read is the acceptor
                      (: _ (? (== () old) (pull t nm 0) (pin t nm old))
                         (scare 'bad-grip nm))))))))

   ; --- this `:` has a body, so the helpers above are local ------------------
   _ (pin book 'grip grip)
   _ (pin book 'opfix-past opfix-past)
   (pin book 'opfix opfix))
; sealed into g's hooks, so no later rebind of the name reaches the reader
(seal-hook 3 opfix)
(seal-hook 9 (\ p (opfix-past (cap p) (filter two? (cup p)))))
; the ops ev's jotin splices into a loop, as values: none a loop's body can shadow
(pin jotfuse 'ops [two? saturate (<) (+) (.) rev tally])

; --- text + sequence batteries ------------------------------------------------
; one copy of each, `sep` first so a partial application reads, and -1 for absent.
(: (fsub s sub i)                                       ; first index >= i of sub in s, or -1
    (? (string? s && string? sub) (subidx s sub i)
       (i + #sub > #s) -1 (snip s i (i + #sub) = sub) i (fsub s sub (i + 1)))

   (join sep l)    (? (atom? l) "" (atom? >l) <l                   ; one cats, not a + per piece
                      (cats (rev (foldl (a \ x \ x . sep . a) [<l] >l))))
   (split sep s)                                        ; always >= 1 piece; "" splits nowhere
    (: (go i) (: j (fsub s sep i)
                 (#sep = 0 || j < 0 ? [(snip s i #s)] (snip s i j . go (j + #sep))))
       (go 0))

)

; --- array element-type inference + shape coercion (shared by `tuple` and `array`).
; a-type answers a witness star of the highest tier present: `tray` reads the tier off a
; witness. a shape dimension may be any numeric and saturates to a nat.
(: ; the int tier is a question of magnitude, not of the numeral's box. whole? first: love
   ; orders across kinds, so a bare magnitude test would put a twin in the int tier
   (a-rank x) (? (gem? x) 1 (twin? x) 2 (whole? x && min-word <= x <= max-word) 0 3)
   (a-emax m x) (: k (a-rank x) (m < k ? k m))
   (a-type d) (: k (foldl a-emax 0 d) (? (k = 0) 0 (k = 1) 0.0 (k = 2) (twin 0 0) ()))
   (a-dim d) (two? d ? #d $d)
   (a-shape s) (two? s ? (map a-dim s) (list (a-dim s))))

;;; FIXME we new names for these. tuple isn't too bad but "hash" for the tablet constructor is wrong
; the read-back targets of the printed @(..) and {..}
(: (spread l) (tray (a-type l) (list (foldl (\ n _ (1 + n)) 0 l)) l))
(:: 'tuple (a \ (list 'spread ('list . a))))
; an odd trailing operand lands at key (): {5} is {() 5}
(: (hashtx a) (? (atom? a) '(tablet 0)
                 (atom? >a) (list 'pin (hashtx 0) () <a)
                 (list 'pin (hashtx >>a) <a <>a)))
(:: 'hash (a \ (hashtx a)))

; (array shape elem..): shape is a dimension list or a lone number, and fixes the count, so
; the elements are ordinary trailing args
(: (a-coll sh n acc) (n < 1 ? (: d (rev acc) (tray (a-type d) sh d))
                              (x \ (a-coll sh (n - 1) (x . acc))))
)

; an object tray whose cells C does not take -- a tray, a coin, a twin: op k (C's enum vop) over
; the cells C paired, each the whole op, so a cell that is itself a tray goes round again.
; the bit ops never come (C refuses them on an object tray) and `=` stays in C
(seal-hook 8 (: ops [(+) (-) (*) (/) (%) (//) 0 0 0 0 0 max min (<) (<=) (>) (>=) (=)]
                (go f a b) (two? a ? (f <a <b . go f >a >b) ())
                (\ k as bs sh (tray () sh (go (ops k) as bs)))))

; recursive-value boxing for `:`, letrec* capture by location. a reference at-or-before its own
; binding is forward and indirects through a cell keyed by the binding site's nom, so a pre-fill
; read is a map miss, the missing condition. it emits nif values, not names, so the egg's mop
; cannot break it. 0 when nothing needs boxing, else (prs' . body').
(: (lambp x) (two? x && == '\ <x && two? >>x) ; \ with a param, not quote
   (dsug n d) (atom? n ? (n . d) (dsug <n ('\ . >n + list d)))
   (lp x) (: a >x (atom? >a ? (0 . <a) (init a . last a)))
   (ln bs) (? (atom? bs) () (atom? >bs) () (<(dsug <bs 0) . ln >>bs))
   ; w/wl: does x / binding-list bs reference symbol v? \ and : shadow, one-operand \ is quote,
   ; macros expand. u tracks lambda depth; dm counts only references not under a lambda.
   (w v x bnd u dm) (?
    (nom? x) (&& (dm ? !u 1) (x == v) !(elem v bnd))
    (atom? x) 0
    (: h <x (?
      (h == '\) (atom? >>x ? 0 (: r (lp x) (w v >r (<r + bnd) 1 dm)))
      (h == ':) (wl v >x (cat (ln >x) bnd) u dm)
      (: m (nom? h ? (macros h) 0) (m && !(elem h bnd) ? (w v (m >x) bnd u dm) (any (e \ w v e bnd u dm) x))))))
   (wl v bs bnd u dm) (?
    (atom? bs) 0
    (atom? >bs) (w v <bs bnd u dm)
    (: nd (dsug <bs <>bs) (w v >nd bnd u dm ? 1 (wl v >>bs bnd u dm))))
   ; a name wants a cell when something that runs before its slot is filled can read it: a read
   ; from a binding at or before it (for a lambda name only one under no \), or, for a value
   ; name, a read from anywhere the earlier bindings reach through the let's own names
   (boxset prs es) (: nm (map cap prs)
     ; the first of each, as assoc and lidx find them: a name's position and def, a def's reads
     (firsts l i t) (atom? l ? t (firsts >l (i + 1) (peep t <l -1 < 0 ? (pin t <l i) t)))
     (first1 ps t) (atom? ps ? t (first1 >ps (two? (peep t <<ps ()) ? t (pin t <<ps (1 . ><ps)))))
     at (firsts nm 0 (tablet 0))
     df (first1 prs (tablet 0))
     rd (first1 es (tablet 0))
     (reads m) >(peep rd m ())
     (anyname m) (map cap (reads m))
     (lam? v) (lambp >(peep df v ()))
     ; the earliest binding reading each name: any read, and a read under no lambda
     (mark t x i) (peep t x -1 < 0 ? (pin t x i) t)
     (seen l i ma mb) (atom? l ? [ma mb]
                        (: rs (reads <l)
                           (seen >l (i + 1) (foldl (\ t r (mark t <r i)) ma rs)
                                            (foldl (\ t r (!>r ? (mark t <r i) t)) mb rs))))
     mm (seen nm 0 (tablet 0) (tablet 0))
     ; near: a read from a binding at or before v; a lambda name counts only the bare ones,
     ; since a call comes after the pin
     (near v) (: k (peep at v 0) (0 <= peep (mm (lam? v ? 1 0)) v -1 <= k))
     ; reach: capture, not evaluation order. an earlier closure inherits a later sibling's
     ; captures, so it wants v's slot at construction, before that slot exists. the reached
     ; set only grows along the list, so one walk keeps it, each name added once
     (add s x) (peep s x 0 ? s (foldl add (pin s x 1) (anyname x)))
     (walk l i s r) (atom? l ? r
                       (: r2 (peep at <l -1 = i ? (pin r <l (peep s <l 0)) r)
                          (walk >l (i + 1) (foldl add s (anyname <l)) r2)))
     rch (walk nm 0 (tablet 0) (tablet 0))
     (reach v) (peep rch v 0)
     (filter (v \ (? (near v) 1 (lam? v) 0 (reach v))) nm))
   ; breads: the read graph boxset takes -- per def, every sibling name it reads, tagged with
   ; whether the read sat under a \ (u). macros expand, but a head this let binds is a variable.
   ; ev.l's census hands boxfix-es the same graph off its own walk.
   (breads prs) (: nm (map cap prs)
     (bref x bnd u acc) (?
      (nom? x) (elem x nm && !(elem x bnd) ? ((x . u) . acc) acc)
      (atom? x) acc
      (: h <x (?
        (h == '\) (atom? >>x ? acc (: r (lp x) (bref >r (<r + bnd) 1 acc)))
        (h == ':) (brefl >x (ln >x + bnd) u acc)
        (: m (nom? h ? (macros h) 0)
           (m && !(elem h bnd) && !(elem h nm) ? (bref (m >x) bnd u acc)
              (foldl (a \ e \ bref e bnd u a) acc x))))))
     (brefl bs bnd u acc) (?
      (atom? bs) acc
      (atom? >bs) (bref <bs bnd u acc)
      (: nd (dsug <bs <>bs) (brefl >>bs bnd u (bref >nd bnd u acc))))
     (map (p \ <p . bref >p 0 0 ()) prs))
   (mkcs bx) (map (v \ v . mint 0 . v) bx)
   (cellbinds cs) (map (c \ <>c . list tablet 0) cs)
   ; the cell read boxfix emits. a pre-fill read scares `missing` with the binder's name, and
   ; the help's result is the value, terminal with nothing heard. `sent` is closure-private, so
   ; no cell value poses as absence.
   cellread (: sent (mint 0)
               (\ c nm (: v (peep c nm sent)
                          (v == sent ? (scare 'missing nm) v)))))

; boxfix-core: the rewrite, refs via sub/subl since c0 has no analysis-time redirect. answers
; (cells pairs.. . body), or () when nothing boxes.
; the law: eager reads see let*, closures see letrec*. a bare read before its name's pin keeps
; the plain nom -- a boxed name's own binding is renamed _, so (: s (trim s)) under a param s
; reads the param. pn is the pinned-so-far set; u is 1 under a \.
(: (boxfix-core prs body es) (: (rmc cs ns) (filter (p \ !(elem <p ns)) cs)
   ; bnd: the lexical binder set, seeded with the scope's own names, so a local is never a macro head
   (sub cs x bnd pn u) (?
    (nom? x) (: p (assoc x cs)
                (? (atom? p) x
                   (u || elem x pn) (list cellread <>p (list '\ >>p))
                   x))
    (atom? x) x
    (: h <x (?
      (h == '\) (atom? >>x ? x (: r (lp x) ('\ . <r + list (sub (rmc cs <r) >r (<r + bnd) pn 1))))
      (h == ':) (: ns (ln >x) (': . subl (rmc cs ns) >x (cat ns bnd) pn u))
      (: m (macros h) (m && !(elem h bnd) ? (sub cs (m >x) bnd pn u) (map (e \ sub cs e bnd pn u) x))))))
   (subl cs bs bnd pn u) (?
    (atom? bs) bs
    (atom? >bs) (list (sub cs <bs bnd pn u))
    (: nd (dsug <bs <>bs) (<nd . sub cs >nd bnd pn u . subl cs >>bs bnd pn u)))
   (: bx (boxset prs es)
      (() == bx ? ()
       (: cs (mkcs bx) ns0 (map cap prs)
          (one p pn) (: d (sub cs >p ns0 pn 0)
                        (elem <p bx ?
                           (: c (assoc <p cs) ('_ . list pin <>c (list '\ >>c) d))
                           (cap p . d)))
          (ones ps pn) (atom? ps ? ()
                          ((one <ps pn) . ones >ps (<<ps . pn)))
          (cs . cellbinds cs + ones prs () . sub cs body ns0 ns0 0))))))
; the flat-list adapters: a `:` binding list -> (the rewritten list . the cells laid), the input
; and () when nothing boxes. boxfix-es takes the read graph; boxfix walks for its own. ev.c
; calls "boxfix" off the book, so c0 compiles through it: it must exist before ev.l does.
(: (boxfix-es fs es) (bodyless? fs ? (fs . ())
    (: pb (bpr fs) r (boxfix-core <pb >pb es)
       (r ? ((catmap (p \ list <p >p) <>r + list >>r) . <r) (fs . ()))))
   (bodyless? l) (? (atom? l) 1 (atom? >l) 0 (bodyless? >>l))
   (bpr fs) (atom? >fs ? (0 . <fs)
               (: r (bpr >>fs) ((dsug <fs <>fs . <r) . >r)))
   (boxfix fs) (bodyless? fs ? fs <(boxfix-es fs (breads <(bpr fs)))))

; pat -- @ : pattern matching, one macro and no special form. laws in test/pat.l.
;
; (@ x pat body .. else) reads like `?` with a shape where the test goes: the first pattern
; that fits x runs its body with the pattern's noms bound, an odd trailing operand is the
; else, and no match with no else is the zero point. spaced `@` is infix at `?`'s band,
; n-ary like it: (x @ p b .. else); glued @( is the tray sigil.
; a pattern in a \ param or a define-sugar binder is opfix's (op-depat, op-dpb above).
;
; a pattern is its constructor, read backwards: the same text that builds a value matches it.
; opfix runs before macros, so the walk sees core forms. a nom binds, `_` swallows, any other
; atom matches itself, and a form's head is its destructuring tag:
;   (a b c)                an untagged form: a chain of exactly three, ('lam x b) fits (lam x b)
;   [a b]  (list a b)      a chain of exactly two
;   (a . t)  (. a t)       the cons: head a, tail t, and it chains. [a b . t] is
;                          (. (list a b) t) -- a head that is the two-chain (a b).
;   ([a b] + t)            a split: the leading run, then t over what is left. the left side
;                          must be a bracket -- its length picks the split point -- and it
;                          needs its own parens inside @'s operands, like any infix.
;   ("v" + t)              a string split, when a string literal is among the pieces (the
;   (k + "=" + v)          string split below). (s + "") fits any string
;   'a  (\ a)              the literal a, never a binding
;   {'f x}  (hash 'f x)    a map carrying key 'f -- the key an expression, the value a
;                          pattern, matched by subset
;   @(a b)  (tuple a b)    a tray of exactly two
;   (pat && g)             a guard, left to right: pat must fit and g must hold, and it
;                          chains: (c && 0 < c && c < 10)
;   (? g pat)              the guard the other way round; (&& ..) lowers to exactly this
;   (? g)                  the guard alone -- fits anything g holds for
;   (p1 || p2)             alternatives: either shape fits. the single & and | are no tags
;   (v @ pat)              the as-pattern, and the only and-pattern: both sides patterns.
;                          spaced: glued v@pat is one nom
;   ^x  (jot x)            the pin: x is read from outside and the value must equal it
;   () or []               the empty list, exactly
; a map key is read for presence, not truth: a pinned () matches, an absent key does not.
; a head naming no tag means the plain form it looks like.
;
; the guard is the one pattern read for truth, not shape, so it needs a tag: (two? x) is
; also a fine untagged pattern. g binds nothing and sees every nom the arm binds: guards run
; at the end of the conjunction, in source order, after the structural tests, so a guard's
; position does not short-circuit any earlier.
;
; a repeated nom matches non-linearly: [a a] fits a pair of equals and nothing else.
;
; the expansion is plain core: ((\ v (? test bound-body .. else)) x), each bound body a
; lambda over the pattern's noms applied to the accessor forms, read in the outer scope, so
; a pattern nom may wear the name of an accessor its own test needs.
(: gone (mint 0)                 ; absence out of band: no stored value poses as a fresh mint
   rtag (mint 0)                 ; heads a string split's run of anchors
   (lit d) ['\ d]               ; d, as the code that answers d
   ; a quoted literal is compared with `=`, nom or not: numeric across kinds, 5 matches 5.0
   (weq d v) [['= (lit d) v]]
   wnil [() () ()]
   (wts ts) [ts () ()]
   (wgd g) [() () [g]]
   (wcat x y) [(<x + <y) (<>x + <>y) (<>>x + <>>y)]

   ; `&&` is the guard, left to right: (p && g ..) is (? g .. p). a chain arrives nested,
   ; (&& p (&& a b)), and the inner `&&` is never a guard on its own: flatten it
   (gand? x) (two? x && == <x '&&)
   (gchain as) (? (atom? >as) as
                  (gand? <>as) (<as . gchain ><>as)
                  as)
   (gwrap p gs) (two? gs ? ['? <gs (gwrap p >gs)] p)   ; nested, so `arms` still distributes
   (gnorm p) (: fl (gchain >p) (gwrap <fl >fl))

   ; (pw p v) -- one walk, three answers: the tests over the access form v, the
   ; (nom access) pairs its body binds, and the guards, which are neither.
   (pw p v)
     (? (nom? p) (p = '_ ? wnil [() [[p v]] ()])
        (p == ()) (wts [['= () v]])                        ; () is the empty list, and asks for it
        (atom? p) (wts [['= p v]])
        (: h (opword <p) as >p                     ; opfix's glued heads are values; opword names them
           (? (h = '?) (? (atom? as) (wlist p v)           ; a guard: (? g1 .. gn pat), or (? g)
                          (atom? >as) (wgd <as)
                          (wq as v))
              (h = '&&) (pw (gnorm p) v)
              ; the and-pattern: both sides read the same value, so the walks concatenate,
              ; and ([a _] @ [_ a]) fits a pair of equals
              (h = '@) (foldl wcat wnil (map (q \ pw q v) as))
              ; the pin, ^x: an equality against x read from outside, one operand only
              (h = 'jot && 1 = #as) (wts [['= <as v]])
              ; alternatives, anywhere: one test, the branches ||ed, each owning its equalities
              ; and guards. a nom is read from whichever branch matched, () where none binds it
              (h = '||)
              (: ws (map (q \ pw q v) as)
                 ds (map (w \ dedup <>w ()) ws)
                 ts (map (e \ two? e && two? >e ? (: w <e d <>e (pand (<w + <d + map (bind <>d) <>>w)))) (zip ws ds))
                 bss (map caup ds)
                 uni (foldl (u \ g \ adds u (map cap g)) () bss)
                 [[('|| . ts)] (map (n \ [n (across n bss ts)]) uni) ()])
              (h = '\) (two? >as ? (wlist p v) (wts (weq <as v)))      ; (\ x b) is a lambda, a form
              (h = 'list) (wlist as v)
              (h = '.) (2 = #as ?                         ; the cons tag
                                        (wcat (wts [['two? v]])
                                              (wcat (pw <as ['cap v]) (pw <>as ['cup v])))
                                        (wlist p v))
              ; a text hole, (weave (list "x" (v) "y")), is the + chain of its pieces: a hole is a
              ; singleton round its sub-pattern. holes side by side, nothing to cut between them,
              ; are each as short as can be: all but the last of the run take ""
              (weave? p)
               (: sq (holerun (splat p))
                  ps <sq
                  (wcat (foldl wcat wnil (map (q \ pw q "") <>sq))
                        (? (atom? ps) (pw "" v)
                           (atom? >ps) (pw <ps v)
                           (pw (foldr (\ q t ['+ q t]) (last ps) (init ps)) v))))
              (h = '+) (2 != #as ? (wlist p v)      ; a split: the left run, then the rest
                          (: l <as t <>as ps (splat p)
                             (? (wstr? ps) (wstr ps v)          ; a string literal among the pieces
                                (two? l ? (<l = 'list) ()) (wrest >l t v)
                                ; `+` is left-handed: ([a b] + [c] + t) re-associates right
                                (two? l ? (<l = '+) ()) (pw ['+ <>l ['+ <>>l t]] v)
                                (wlist p v))))
              (h = 'hash) (wcat (wts [['tablet? v]]) (wkv as v))
              (h = 'tuple) (wcat (wts [['tray? v] ['= #as ['tally v]]])
                                 (widx as v 0))
              (wlist p v))))                               ; untagged: the form's own shape, exact
   (wq as v) (two? >as ? (wcat (wgd <as) (wq >as v)) (pw <as v))   ; guards, then the shape
   ; [the pieces kept, the holes that take ""]: a free piece followed by a free piece goes
   (holerun ps) (? (atom? ps) [() ()]
                   (: r (holerun >ps)
                      (two? >ps && !(anchor? <ps) && !(anchor? <>ps) ? [<r (<ps . <>r)] [(<ps . <r) <>r])))
   ; a nom's access across an alternative: the first branch that matches supplies every nom,
   ; and one it does not bind reads ()
   (across n bss ts) (atom? bss ? (lit ())
                      (: e (assoc n <bss)
                         ['? <ts (atom? e ? (lit ()) <>e) (across n >bss >ts)]))
   ; a pattern longer than its value must never reach a `cap`, so the run is claimed before it
   ; is read: `two?` on the head, then one `long?` for the rest. the head's test stays separate:
   ; the decision tree hoists it, and the tag compare must come before the arity walk.
   (warity k v) (k = 1 ? [['two? v]] [['long? k v]])
   (wrun ps v end)
     (atom? ps ? (end v)
      (: n #ps
       (wcat (wcat (wts [['two? v]]) (pw <ps ['cap v]))
             (n = 1 ? (end ['cup v])
              (wcat (wts (warity (n - 1) ['cup v])) (wskip >ps ['cup v] end))))))
   (wskip ps v end) (atom? ps ? (end v) (wcat (pw <ps ['cap v]) (wskip >ps ['cup v] end)))
   (wlist as v) (wrun as v (r \ wts [['= () r]]))
   (wrest ps t v) (wrun ps v (pw t))

   ; --- the string split -------------------------------------------------------
   ; a + chain with a string literal among its pieces cuts a string. a literal or a pin ^x is
   ; an anchor, standing exactly there; every other piece is free and takes what the anchors
   ; leave. anchors are laid from both ends first; between two free pieces the anchors are one
   ; needle, found at its first occurrence, so each free piece is as short as it can be.
   ; a text hole's pieces join the chain it sits in: (k && 0 < #k) + " \(v)" cuts at the " "
   (splat p) (? (two? p && <p = '+ && 2 = #>p) (splat <>p + splat <>>p)
                (weave? p) (catmap (q \ splat (two? q && atom? >q ? <q q)) (filter (q \ q != "") ><>p))
                [p])
   (weave? p) (two? p && <p = 'weave && 1 = #>p && two? <>p && <<>p = 'list)
   (wpin? q) (two? q ? (opword <q = 'jot ? (1 = #>q)))
   (anchor? q) (string? q || wpin? q)
   (atext q) (string? q ? q <>q)
   (alen q) (string? q ? #q ['tally <>q])
   (padd a b) (? (charm? a && charm? b) (a + b) (b == 0) a (a == 0) b ['+ a b])
   (psub a b) (? (charm? a && charm? b) (a - b) (b == 0) a ['- a b])
   (acat a b) (string? a && string? b ? (a + b) ['+ a b])
   ; the pieces, a run of anchors gathered under rtag
   (aruns ps) (? (atom? ps) ()
                 (anchor? <ps) (: r (aruns >ps)
                                  (run? <r ? ((rtag . <ps . ><r) . >r) ([rtag <ps] . r)))
                 (<ps . aruns >ps))
   (run? x) (two? x ? (<x == rtag))
   (rlen r) (foldl (\ n q (padd n (alen q))) 0 r)
   ; a run's tests, one per anchor, laid from pos forwards or back from end. a literal anchor
   ; is sits?, in place; a pin's text is read at match time, so it snips. the nif goes in as
   ; the head's value, not quoted: ev inlines a value head at its arity
   (lfwd r pos v) (atom? r ? () (: e (padd pos (alen <r))
                                   ((string? <r ? [sits? v pos <r] ['= (atext <r) ['snip v pos e]]) . lfwd >r e v)))
   (lbck r end v) (lfwd r (psub end (rlen r)) v)
   (meet? rs) (two? >rs ? (!(run? <rs) && !(run? <>rs) ? 1 (meet? >rs)))
   ; a literal among the pieces, no bracket, and no two free pieces side by side: anything
   ; else is the list split, since @ refuses no pattern
   (wstr? ps) (any string? ps && !(any (q \ two? q && (<q = 'list)) ps) && !(meet? (aruns ps)))
   (wstr ps v)
     (: rs (aruns ps)
        ; the left run, the right run, and between them free pieces and needles, alternating
        lr (run? <rs ? ><rs ())
        m0 (run? <rs ? >rs rs)
        rr (two? m0 ? (run? (last m0) ? >(last m0)))
        mid (two? rr ? (init m0) m0)
        lo (rlen lr)
        hi (psub ['tally v] (rlen rr))
        pre ([['string? v]] + map (q \ ['string? <>q]) (filter wpin? ps)
             + lfwd lr 0 v + lbck rr ['tally v] v
             + [(two? mid ? ['<= lo hi] ['= lo hi])])
        ; a free piece's text: the whole value when nothing is cut off it
        (part a b) (a == 0 ? (same? b ['tally v] ? v ['snip v a b]) ['snip v a b])
        ; each needle is sought from where the free piece before it starts
        (cut ms cur)
          (atom? >ms ? (pw <ms (part cur hi))
             (: rn ><>ms n (foldl acat "" (map atext rn))
                at [subidx v n cur] e (padd at (rlen rn))     ; v and the needle are strings by now
                (wcat (wts [['<= 0 at] ['<= e hi]])
                      (wcat (pw <ms ['snip v cur at]) (cut >>ms e)))))
        (wcat (wts pre) (two? mid ? (cut mid lo) wnil)))
   (wkv as v) (atom? >as ? wnil
               (: g ['peep v <as (lit gone)]
                (wcat (wcat (wts [['! ['= (lit gone) g]]]) (pw <>as g))
                      (wkv >>as v))))
   (widx as v i) (atom? as ? wnil (wcat (pw <as ['peep v i ()]) (widx >as v (i + 1))))

   ; the non-linear pass: a nom already sighted becomes an `=` against the access
   ; form that first bound it, and drops out of the binder list.
   (dedup bs seen)
    (atom? bs ? wnil
     (: b <bs e (assoc <b seen)
      (wcat (atom? e ? [() [b] ()] (wts [['= <>e <>b]]))
       (dedup >bs (atom? e ? (b . seen) seen)))))

   (pand ts) (? (atom? ts) 1 (atom? >ts) <ts  ('&& . ts))

   ; the wrapper is ev's to remove: its read-once refinement inlines a nom read once
   (bind bs body) (atom? bs ? body (('\ . map cap bs + [body]) . map caup bs))

   ; --- the decision dag --------------------------------------------------------
   ; a clause is [tests body guards]. the first live clause's next test is asked once and every
   ; clause hears the answer: yes drops it from those that ask it and drops those it rules out,
   ; no drops those that need it. a test is asked only where its clause's earlier tests held, so
   ; its accessors are safe; guards are never shared. a clause the test leaves alone rides both
   ; answers, so each residual takes the smaller of its dag and its flat chain, under a fuel cap.
   (same? a b) (? (two? a) (two? b ? (same? <a <b ? (same? >a >b)))
                  (two? b) ()
                  (a == b))
   ; a size in lowered nodes: each && operand past the first lowers to a let and a ?, (: b t (? b R b))
   (cost x) (atom? x ? 1 (foldl (\ n e (n + cost e)) (<x = '&& ? 4 * #>x - 3 1) x))
   (flat cs els) ('? . (catmap (c \ [(pand (<c + c 2)) <>c]) cs) + [els])
   ; exclusive answers: x = 'a, x = 'b, x = () and two? x hold at most one at a time
   (kon? c) (c == () || two? c && <c = '\ && two? >c && atom? >>c && nom? <>c)
   (eqk? t) (two? t && <t = '= && two? >t && kon? <>t && two? >>t && atom? >>>t)
   (two1? t) (two? t && <t = 'two? && two? >t && atom? >>t)
   (excl? t u) (? (eqk? t) (? (eqk? u) (same? <>>t <>>u && !(same? <>t <>u))
                               (two1? u) (same? <>>t <>u)
                               ())
                  (eqk? u) (excl? u t)
                  ())
   (dag cs els fu)
     (? (atom? cs) els
        (0 >= fu 0) (flat cs els)
        (: _ (pin fu 0 (fu 0 - 1))
           c <cs
           (? (atom? <c) (two? (c 2) ? ['? (pand (c 2)) <>c (dag >cs els fu)] <>c)
              (: t <<c
                 yes (catmap (d \ (? (any (same? t) <d) [[(filter (x \ !(same? t x)) <d) <>d (d 2)]]
                                     (any (excl? t) <d) ()
                                     [d]))
                             cs)
                 no (filter (d \ !(any (same? t) <d)) cs)
                 dg ['? t (dag yes els fu) (dag no els fu)]
                 fl (flat cs els)
                 (cost dg <= cost fl ? dg fl)))))
   (tree cs els) (dag cs els (pin {} 0 4000))
   ; --- alternatives ----------------------------------------------------------
   ; (p1 || p2), or `|`, fits when either does. a nom sits somewhere else in every branch, so one
   ; access cannot serve two shapes. two lanes, both first-branch-wins: at the top of an arm, one
   ; clause per branch sharing the body; nested, one clause, the branches `||`ed (pw above). the
   ; body binds the union, a nom this branch did not bind to (), so it cannot reach whatever wears
   ; that name outside. a guard wrapping an alternative belongs to every branch, asked once per branch.
   (arms p) (atom? p ? [[p ()]]
               (: h <p as >p
                  (? (h = '||) (catmap arms as)
                     (h = '&&) (arms (gnorm p))
                     (h = '? && 2 = #as)
                       (map (b \ [<b (<as . <>b)]) (arms <>as))
                     [[p ()]])))
   (wgds w gs) (foldl (\ x g (wcat x (wgd g))) w gs)
   (adds u ns) (u + filter (n \ !(elem n u)) ns)    ; u, then what it did not have
   _ (:: '@ (\ a
       (: v (nom 0)
          ; the clause a walk answers: its tests, its non-linear equalities, its guards, and a
          ; body bound over `uni`, whatever this branch did not bind reading ()
          (clofu w uni b)
            (: d (dedup <>w ())
               dd <>d
               mf (n \ [n (lit ())])
               ff (n \ !(assoc n dd))
               bs (dd + map mf (filter ff uni))
               gs (map (bind bs) <>>w)
               [(<w + <d) (bind bs b) gs])
          (clof w b) (clofu w () b)
          (arm p b)                                    ; the clauses one arm answers for
            (: qs (arms p)
               (? (atom? >qs) [(clof (pw p v) b)]   ; one branch: pw takes any guard itself
                  (: ws (map (q \ wgds (pw <q v) <>q) qs)
                     (? (all (atom? * caup) ws) [(clof (pw p v) b)]   ; none binds: pw's one test
                        (: uni (foldl (\ u w (adds u (map cap <>(dedup <>w ())))) () ws)
                           (map (w \ clofu w uni b) ws))))))
          (cls r) (? (atom? r) [() ()]              ; no clause and no else: the zero point
                     (atom? >r) [() <r]             ; the odd tail is the else
                     (: rest (cls >>r)
                        [(arm <r <>r + <rest) <>rest]))
          cl (cls >a)
          [['\ v (tree <cl <>cl)] <a])))
   ())
