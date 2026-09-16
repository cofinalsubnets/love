; prel.l -- love prel: data + function + macro definitions.
; prefix only down to the `operators` table: c0 compiles this before opfix and before the church
; add/mul hooks exist. an operator up here cores the egg.
; FIXME move ev support functions to ev where possible
(: id 1
   (const x _) x
   (co f x y) (f y x)                ; the argument-transpose
   flip co
   link? two?
   name nom intern nom mint nom
   saturate sat)                    ; the infix cons is `.` alone: (a . b) is (. a b); glued ><x stays the cup-cap accessor (valence)
(: : () ? () \ ())
(: e 2.718281828459045
   i (twin 0 1) ;; FIXME up top

   (one? x) (nil? (two? x))
   atom? one?
   ; a fresh layer: its own macro table at key 0, the pre-enter chain and name at charm key 31337.
   ; a charm key cannot collide with a name. (enter ()) is anonymous.
   (enter nm) (: F (tablet 0) _ (pin F 0 (tablet 0)) _ (pin F 31337 (. (stack ()) nm))
                 _ (setstack (. F (stack ()))) ())

   ; unwind to the pre-enter chain, register the layer under its name, answer the book.
   ; a bare leave -- never entered, so no charm -- pops whatever sits below the head instead.
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
; `::` defines a macro in the head layer's table -- the same book a plain `:` defglobs to, so
; prel's macros land in orth during boot, a script's in the session layer, a module's in the module.
(: ; look a macro up across the layer chain -- the twin of love.c's stacklook_macro, kept in step with
   ; it. each book holds its table at the nil key; a layer without one is skipped. 0 = no macro.
   (macros k) (: (go c) (? (nil? (two? c)) 0
                           (: m (peep (cap c) 0 ())
                              (? (tablet? m) (: v (peep m k 0) (? v v (go (cup c))))
                                 (go (cup c)))))
                 (go (stack ())))
   (:: a b) (: F (cap (stack ())) m (peep F 0 ())
               (pin (? (tablet? m) m (: t (tablet 0) _ (pin F 0 t) t)) a b))

)
; numfn lays the n-fold thread with spin/place, so applying a fixnum never re-enters the compiler:
; n quote-f's then n ap's, cell 0 the printer's source, entry at cell 1.
; the helpers pass th/f/n explicitly: a closure over the forward-bound th miscompiles under c0.
(: (nfnest f i acc) (? (< i 1) acc (nfnest f (+ -1 i) (. f (. acc ()))))
   (nfq th f i n) (? (< i n) (: _ (place (+ 1 (* 2 i)) lvm_quote th) _ (poke (+ 2 (* 2 i)) f th) (nfq th f (+ 1 i) n)) th)
   (nfa th i n) (? (< i n) (: _ (place (+ (+ 3 (* 2 n)) i) lvm_ap th) (nfa th (+ 1 i) n)) th)
   (numfn n f) (:                                  ; build (\ x (f (f ... (f x)))), n f's
     src (. '\ (. 'x (. (nfnest f n 'x) ())))  ; alloc before spin; printer source
     th (spin (+ 5 (* 3 n)))                         ; [src] n*[quote f] [arg n] n*[ap] [ret 1]
     _ (poke 0 src th) _ (nfq th f 0 n)             ; no allocation past spin: th can't move
     _ (place (+ 1 (* 2 n)) lvm_arg th) _ (poke (+ 2 (* 2 n)) n th)   ; arg n: x, now under n f's
     _ (nfa th 0 n)
     _ (place (+ 3 (* 3 n)) lvm_ret th) _ (poke (+ 4 (* 3 n)) 1 th)
   (seek 1 th))
   ;; FIXME rename | -> bit-or to free | for pipe operator
   (constellation? x) (| (charm? x) (packp x))   ; whole tower: fixnum / float / boxed int / complex / array
   (whole? n) (| (charm? n) (sun? n))       ; integer-valued numeral (exact power exponent / composition count)
   ; this build's machine word, off the fixnum bound C publishes: a charm spends one bit,
   ; so the word reaches exactly twice as far. what fits here fits an int tray cell.
   max-word (+ (* max-charm 2) 1)
   min-word (* min-charm 2)
   ; apcap: a public tunable ceiling. a numeral compose count above it scares instead of
   ; allocating O(k), so (bignum f) asks for help where it would oom. retune: (pin apcap 0 n).
   apcap (pin (tablet 0) 0 1048576)              ; (a raw box: the brace's hash isn't built yet)
   (ipow b k) (? (< k 1) 1 (: h (ipow b (// k 2)) h2 (* h h) (? (= 0 (% k 2)) h2 (* h2 b))))
   ; each site keeps its own (scare 'apcap k) as the cond result, so a recovering help's value
   ; lands as the result directly -- no thunk on the hot path. don't factor it out.
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
   ; x ** n across the whole tower: array exponent -> elementwise, integer -> exact squaring
   ; (a NEGATIVE one gives the reciprocal power, so (-1 x) == (/ 1 x)), else `fpow` -- the
   ; inexact leaf this tower stands on, and the name `power` spells the tower.
   (powg x n) (? (tray? n) (fpow x n)
                 (whole? n) (: m (abs n)
                             (? (powover x m) (scare 'apcap m)
                                (< n 0) (/ 1 (ipow x m)) (ipow x m)))
                 (fpow x n))
   ; church application across the tower: a numeric operand gives x ** n, a function composes
   ; ($ n) times. cmp2..cmp8 are cached combinators; past them numfn assembles the thread.
   ; keep the straight-line bodies -- a counting applier measures ~45% slower at k=2..8.
   _ (: (cmp2 f x) (f (f x))
        (cmp3 f x) (f (f (f x)))
        (cmp4 f x) (f (f (f (f x))))
        (cmp5 f x) (f (f (f (f (f x)))))
        (cmp6 f x) (f (f (f (f (f (f x))))))
        (cmp7 f x) (f (f (f (f (f (f (f x)))))))
        (cmp8 f x) (f (f (f (f (f (f (f (f x))))))))
        ; frequency-ordered, so it stays a chain: k=2/3 costs one or two compares. a table would
        ; only pay past k=6.
        (cmp k) (? (= k 2) cmp2 (= k 3) cmp3 (= k 4) cmp4 (= k 5) cmp5 (= k 6) cmp6 (= k 7) cmp7 (= k 8) cmp8 0)
        ; past cmp8 numfn lays the thread -- straight-line, the fast shape -- but its 3n+5 cells
        ; grow without bound (n=100000 is ~72MB, and apcap admits 2^20), so past nfcap nfloop
        ; composes by counting instead: one closure, O(1) cells, the same function.
        (nfloop n f x) (? (< n 1) x (nfloop (+ -1 n) f (f x)))
        nfcap 1024
        ; an open star: a coin whose kind pins star is numeric by declaration, so a numeral powers
        ; it through its own * (ipow is generic). no size to read, so this lane keeps the count cap.
        (starred? x) (? (coin? x) (: e (kreg 0 (kind x)) (? (two? e) (= 1 ((cup e) 'star)) 0)) 0)
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
(seal-hook 1 num-ap)
; the + and * of two functions, which is all church arithmetic is: the extra a-slot threaded into
; both of arrange's operands is what makes + agree with addition. lvm_addh/lvm_mulh read by slot.
(: (arrange f g a x) (f a (g a x))                ; (+ f g)
   (compose f g x) (f (g x))                      ; (* f g)
   _ (seal-hook 2 arrange)
   _ (seal-hook 3 compose))
; map runs left to right
(: (map f l) (? (two? l) ((\ f x l (. x (map f l))) f (f (cap l)) (cup l)))
   (foldl f z l) (? (two? l) (foldl f (f z (cap l)) (cup l)) z)
   (foldr f z l) (? (two? l) (f (cap l) (foldr f z (cup l))) z)
   ; (rev l) glued onto acc in one pass. a cat per step re-copies the whole accumulation;
   ; link plus one revcat keeps it linear.
   (revcat l acc) (? (two? l) (revcat (cup l) (. (cap l) acc)) acc))   ; no `!` here: not bound yet
; the monadic words behind the glued sigils. a coin's lane is by declaration: a starred kind
; nets itself, else its tally under net-mode tally, else its payload signed. one walk over the
; spine's cars then the tail, so net(. a b) = net a + net b at every link.
(: (netsum a l) (? (two? l) (netsum (+ a (net (cap l))) (cup l)) (+ a (net l)))
   (net x) (? (tray? x) (asum x)
              (constellation? x) x
              (two? x) (netsum 0 x)
              (coin? x) (: p (load x) e (kreg 0 (kind x)) t (? (two? e) (cup e) ())
                           (? (= 1 (t 'star)) x                 ; starred: the fixpoint
                              (= 'tally (t 'net)) (tally x)
                              (= p x) (saturate x)              ; a native loads as itself
                              (net p)))
              (saturate x))
   (prod x) (? (tray? x) (aprod x)
               (two? x) (foldl (\ a e (* a (prod e))) 1 x)
               x)
   negate (- 0)
   reciprocal (/ 1)
   (fraction x) (% x 1)
   (bit x) (nil? (nil? x))
   (!== a b) (nil? (== a b))
   ; a star is the fixpoint of net. ==, not `=`: a number comes back unchanged where a tray's
   ; net is a fresh sum, so star? and galaxy? stay disjoint.
   (star? x) (== x (net x))
)
(: (filter p l) (? (two? l) (: m (filter p (cup l)) (? (p (cap l)) (. (cap l) m) m)))
   (init l) (? (two? (cup l)) (. (cap l) (init (cup l))))
   (last l) (? (two? (cup l)) (last (cup l)) (cap l))
   (each l f) (? (two? l) (: _ (f (cap l)) (each (cup l) f)))
   (ldel x l) (? (two? l) (? (= (cap l) x) (cup l) (. (cap l) (ldel x (cup l)))))
   (all f l) (? (two? l) (? (f (cap l)) (all f (cup l)) 0) 1)   ; truth bits (0/1, like =/</!), not ()
   (any f l) (? (two? l) (? (f (cap l)) 1 (any f (cup l))) 0)   ; -- a predicate's false is 0, the green floor
   ; iterate `step` until `size` stops changing. size must be strictly monotone under step until
   ; the fixpoint, and is read before the step, so a step that mutates in place is still seen.
   (monofix st step size) (: b (size st) nx (step st) (? (= (size nx) b) nx (monofix nx step size)))

   ; the one constant-form recognizer. the answer is wrapped -- (1 . value) or () -- because a
   ; constant's value can itself be nothing. no `&&`: c0 is single-pass and it is defined later.
   (kconst e) (? (nom? e) ()                                                    ; a variable -> no fact
                 (one? e) (. 1 e)                                           ; a literal -> (1 . itself)
                 (== (cap e) '\) (? (one? (cuup e)) (. 1 (caup e))))    ; (\ v) quote of an atom -> (1 . v); a real lambda -> no fact
   (cat a b) (foldr (.) b a))
; (sort l) is the C lane -- a stable bottom-up merge by the total order, no lisp re-entry;
; descending is (rev (sort l)). an arbitrary predicate takes this lisp merge sort instead.
(: (sortsplit l) (? (one? l) (. l ()) (one? (cup l)) (. l ())
                    (: r (sortsplit (cuup l)) (. (. (cap l) (cap r)) (. (caup l) (cup r)))))
)
; catmap folds with + rather than cat, so it is band-general: mapping to lists concatenates
; them, mapping to strings joins them. () is the seed and the do-nothing unit of both.
(: catmap (compose (flip foldr ()) (compose (+)))
   (assoc x l) (? (two? l) (? (= x (caap l)) (cap l) (assoc x (cup l))))
   ; assoc's identity twin, as eleq is elem's: a key that is a nom or a charm wants no
   ; structural walk, and `==` says so in one word.
   (assq x l) (? (two? l) (? (== x (caap l)) (cap l) (assq x (cup l))))
   (lidx x) ((: (f n l) (? (two? l) (? (= x (cap l)) n (f (+ 1 n) (cup l))) -1)) 0)
   (zip a b) (? (two? a) (? (two? b) (. (. (cap a) (cap b)) (zip (cup a) (cup b)))))
   rev (foldl (flip (.)) ())
   ; every nom on the layer chain, deduped through a tablet. noms only -- a layer's keys also hold
   ; the macro table and the unwind chain. it sits down here so catmap/foldl are already bound.
   (names _) (filter nom? (keys (foldl (\ t k (pin t k 1)) (tablet 0) (catmap keys (stack ())))))

   ; the range 0..x-1 (iota its array twin), lifted over a list so the glued run composes:
   ; ^^3 is (jot (jot 3)). no glued sigil in here -- this sits above the operators table,
   ; where infix is not yet live, so a `$x` would stay a bare nom.
   (jot x) (? (two? x) (map jot x) (: n (saturate x) (go i) (? (< i n) (. i (go (+ i 1)))) (go 0)))
   (drop n l) (? n (drop (- n 1) (cup l)) l)
   (take n l) (? n (? (two? l) (. (cap l) (take (- n 1) (cup l)))))   ; stop at end-of-list (else it pads past it)
)

(: l (foldr (\ a l (. (.) (. a (. l ())))) ()) (:: 'list l))
; both are connectives: they answer one of their operands, never an invented value -- && the
; first falsy one, || the first truthy one, either falling through to the last; a form operand
; is bound so it evaluates once. a caller wanting a particular miss value must spell it.
(:: '&& (\ l (: (and l) (? (two? (cup l)) (: y (nom 0) (list ': y (cap l) (list '? y (and (cup l)) y))) (cap l)) (? (two? l) (and l) 1))))
(:: '|| (\ l (: (or l) (? (two? (cup l)) (: y (nom 0) (list ': y (cap l) (list '? y y (or (cup l))))) (cap l)) (? (two? l) (or l) 0))))
; end weighting: the head argument moves to the tail, so the form a long body would have
; buried is read first. the `:` these build is source: both macro lanes opfix an expansion,
; so a destructuring binding head lowers there as it would under a read `:`.
(:: ':- (\ a (. ': (cat (cup a) (. (cap a) ())))))
(:: '?- (\ a (. '? (cat (cup a) (. (cap a) ())))))
; @ carries a subject the other two lack, so @- moves the second argument, not the
; first: (x @- dflt p v ..) is (x @ p v .. dflt), and the subject stays where it reads.
(:: '@- (\ a (. '@ (. (cap a) (cat (cuup a) (. (caup a) ()))))))

; (pins t k v ..): pin each pair onto an existing tablet -- the mutable-accumulator twin of {..},
; which mints a fresh one. an odd trailing operand is dropped (no lone key).
(:: 'pins (\ l (: (go t r) (? (two? (cup r)) (go (list pin t (cap r) (caup r)) (cuup r)) t)
                  (go (cap l) (cup l)))))

(: (** a b) (b a)  
   $ 1 ! nil?  (!= a b) (nil? (= a b))
   ; elem is the nif (love/arr.c); this is its negation. spelled `nil?`, not glued `!`: a
   ; glued sigil factors through monofactor's (mono ..), and mono is bound further down.
   (nelem x l) (nil? (elem x l)))                         ; the exponent answers to all three spellings

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
    ; a list head is (name export..): the body defglobs as ever, then every nom not named
    ; is pulled off the tablet. the charm keys (0 the macros, 31337 the parent chain) are
    ; not noms and so survive. quote the list head -- unquoted it rides the opfix pass, and
    ; one operator nom in it re-associates the whole list and the module leaves empty.
    (mrun nm fs) (: n  (? (two? nm) (cap nm) nm)
                     xs (? (two? nm) (cup nm) ())
                     _  (mopen n)
                     _  (each fs (\ f (ev 'ev f)))
                     F  (cap (stack ()))
                     _  (? (two? xs)
                           (each (keys F) (\ k (? (nom? k) (? (elem k xs) 0 (pull F k 0)) 0)))
                           0)
                     (leave ()))
    ; the quote takes the forms list whole -- (\ (f ..)), one element per form; an extra
    ; (. .. ()) here makes the body one application chain. 'x reads as (\ x), so unwrap one.
    (:: 'module (\ l (: h (cap l)
                        n (? (two? h) (? (== (cap h) '\) (caup h) h) h)
                        (list mrun (list '\ n) (list '\ (cup l))))))))

; --- reader operators: the operators tablet + the opfix factor pass ---------
(: operators (pins (tablet 0)
 0 (pins (tablet 0)                                 ; --- arity 0: glued. takes nothing from the form
 '< cap '> cup '+ net '* prod '| abs '- negate '/ reciprocal
 '% fraction '? bit '$ sat '! nil? '^ jot
 '# tally '~ conj                              ; the count, and the twin's flip
 '0? nil? '1? one? '2? two?)                   ; the arity predicates: a row is a word, so it may
                                               ; spell digits -- 2?<>x is (two? (cap (cup x))).
                                               ; ^ also rides arity 2 as xor: the lane is the key
 1 (tablet 0)                                       ; --- arity 1: a right operand and no left. no walk yet
 2 (pins (tablet 0)                                 ; --- arity 2: spaced. a left operand and a right
 '~ '(twin 99)                                      ; the twin, tightest -- above house, so a complex
                                                    ; literal binds before any operator, coined ones too
 '/// 99                                           ; the rational, the twin's peer: a literal too
 '** 70
 '* -60 '/ -60 '% -60 '// -60                       ; multiplicative, left -- the minus is the hand
 '+ -50 '- -50                                      ; additive
 '<< -47 '>> -47                                    ; shifts
 '& -46 '^ -45 '| -44                               ; bitwise, C's order
 '&& 31 '|| 30                                      ; logical, below comparison; also pat.l's guard and alternative
 '. 25                                              ; cons -- the loosest builder
 '$ 5 '\ 5)                                         ; weak apply (a $ b = (a b), haskell $; glued $x stays saturate) and
                                                    ; the lambda, one band. an infix lambda's body runs to the
                                                    ; end of the form, but at equal band the right hand yields:
                                                    ; (map $ a \ f a) is (map (\ a (f a))), not ($ map a).
 -1 (pins (tablet 0)                                ; --- arity -1: spaced, no bound. a left, then all of them
 '? 10 '@ 10 '@- 10                                 ; the clause forms: cond, and match -- every arm stays an operand
                                                    ; (@- rides @'s band so it reads infix; :- and ?- are prefix-only)
 ': 3 ':= ':)                                       ; the binder, loosest of all; := is a bare nom, so it names
                                                    ; `:` and takes its band -- an alias cannot drift from it
 -2 (pins (tablet 0)                                ; --- arity -2: spaced, and it chains. a left and a right, but
 '= 40 '!= 40 '< 40 '<= 40 '> 40 '>= 40 '== 40 '!== 40)))          ; a same-band neighbour joins the run instead of nesting
 ; the spaced rows are noms: the sigil is the name there, so a binding of it is visible in the
 ; text that uses it. the glued lane holds values instead -- `<x` is the function `cap` -- so a
 ; local `cap` cannot re-aim it; the price is spellability, which `opnom` buys back.

; value -> the word the glued sigil means, and the walk that puts the words back through a
; factored form. every reader of post-opfix source wants noms; this is the one place with the map.
(: opnoms (pins (tablet 0)
   cap 'cap cup 'cup net 'net prod 'prod abs 'abs negate 'negate
   reciprocal 'reciprocal fraction 'fraction bit 'bit sat 'sat
   nil? 'nil? jot 'jot one? 'one? two? 'two? tally 'tally conj 'conj)
   (opnom v) (? (two? v) 0 (peep opnoms v 0))       ; a list is never a row; keep it off the hash
   (opword v) (: n (opnom v) (? n n v))             ; ..and the total one: the word, or v untouched
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
(: ; the lanes, by their arity key. local: the tablets are the ones in `operators`, not copies,
   ; so a `grip` write through the door is seen here at once and there is nothing beside it.
   monadics (operators 0) dyadics (operators 2) naries (operators -1) chains (operators -2)
   (op-punc-byte c) (? (&& (<= 97 c) (<= c 122)) 0
                       (&& (<= 48 c) (<= c 57)) 0
                       (&& (<= 65 c) (<= c 90)) 0
                       (= c 95) 0
                       1)
   ; cheap prefilter: only an all-punct symbol can factor. the four ranges above are disjoint and
   ; run commonest-first, so don't reorder them.
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

   ; a band is a signed charm: the magnitude is the level (higher binds tighter) and the sign is
   ; the hand -- positive right, negative left. zero can never be a band: a tablet miss answers
   ; 0, and a 0 band would read that miss as a live row at the loosest level there is.
   (op-band? b) (&& (charm? b) (nil? (= 0 b)))   ; prefix-only region: != is not a function yet
   (op-row nm b ar) (. nm (. (abs b) (. (? (< b 0) 1 0) ar)))       ; -> (name band hand . arity)
   ; an alias tail. this table is compiled before `.` has its row, so up here source can only
   ; spell the list form -- a written (pin . 20) is the three-element list. a pair built with . reads too.
   (op-tail v) (? (charm? (cup v)) (cup v) (&& (two? (cup v)) (charm? (caup v))) (caup v) 0)
   ; k's row in the spaced lane t of arity ar -> (name band hand . ar), or 0. read by kind, three
   ; shapes and no positions: a charm is the band and the sigil names itself; a nom is an alias,
   ; one hop, so none can drift or cycle; a (nom band) pair is an alias carrying a band of its
   ; own, for a target that has no row to lend (`pin` and its kind).
   (op-lane k t ar)
    (: v (t k)
       (? (op-band? v) (op-row k v ar)
          (nom? v) (: b (t v) (? (op-band? b) (op-row v b ar) 0))
          (? (two? v) (nom? (cap v)) 0) (: b (op-tail v) (? (op-band? b) (op-row (cap v) b ar) 0))
          0))
   ; the spaced lanes, tightest first -- so a nom sitting in two reads as the earliest. arity 1
   ; has no walk, so it is never asked and a row there stays inert.
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
   ; a frame is only ever rebuilt with a new need + got -- orig, name and band are fixed the
   ; moment the operator is read.
   (op-frw f nd g) (op-fr (op-fro f) (op-frn f) nd (op-frband f) g)
   ; wrap a chain of monadic words around a datum, outermost first
   (op-fin ch x) (? (two? ch) (. (cap ch) (. (op-fin (cup ch) x) ())) x)
   ; fold a collected span (out, reversed) into one operand: a lone datum stays itself, two-or-more
   ; become the application (juxtaposition binds tighter than any infix operator).
   (op-span out) (? (two? (cup out)) (rev out) (cap out))
   ; the two binders fold back through op-core, so an infix spelling lowers exactly as the prefix
   ; one does. a `:` chain is one scope: the nesting op-steal builds is spliced flat here, so
   ; (a : 1 b : 2 (a + b)) and (: a 1 b 2 (a + b)) are the same form. the body position splices.
   (op-cl-splice fs)
    (? (one? (cup fs))
       (: b (cap fs)
          (? (&& (two? b) (== (cap b) ':)) (cup b) fs))
       (. (cap fs) (op-cl-splice (cup fs))))
   ; a chain, arity -2: (a < b <= c) is (a < b) and (b <= c), the shared operand bound so it is
   ; evaluated once, inside the conjunction so && still short-circuits. the operators may differ
   ; per link. os is (a b op c op d ..): the head operator is the frame's name, later ones inline.
   ; only a compound operand is bound -- an atom costs nothing twice and a fresh nom is unspellable.
   (op-chn-rest pv r)                                        ; r = (op z op z ..), or a dangling op
    (? (one? r) 0
       (: op (cap r)
          (? (one? (cup r)) (. op (. pv ()))              ; a trailing operator: the curry law, per link
             (: z (caup r) v (? (one? z) z (nom 0))
                e (. op (. pv (. v ()))) t (op-chn-rest v (cuup r))
                bd (? (two? t) (. '&& (. e (. t ()))) e)
                (? (== v z) bd (. ': (. v (. z (. bd ())))))))))
   ; the whole run wears a `bit`: `&&` hands back () for a false left and the failing operand
   ; otherwise, so a bare chain would answer three different faces for one predicate. the clamp
   ; is outside the binds, so nothing about the short-circuit or the evaluation order moves.
   (op-chn nm os)
    (: a (cap os) b (caup os) u (? (one? a) a (nom 0)) v (? (one? b) b (nom 0))
       e (. nm (. u (. v ()))) t (op-chn-rest v (cuup os))
       bd (? (two? t) (. '&& (. e (. t ()))) e)
       b2 (? (== v b) bd (. ': (. v (. b (. bd ())))))
       b3 (? (== u a) b2 (. ': (. u (. a (. b2 ())))))
       (. 'bit (. b3 ())))
   ; fold a frame with what it has: nothing collected gives the plain symbol, a shortfall the
   ; partial application. kind tests throughout the walk, never truth -- an operand list like
   ; (0) or ("") nets zero. a chain shows as the interleaved operators the join left in `got`.
   (op-fold f) (? (atom? (op-frg f)) (op-fro f)
                  (: nm (op-frn f) os (rev (op-frg f))
                     (? (== nm '\) (op-core (. '\ os))
                        (== nm ':) (op-core (. ': (op-cl-splice os)))
                        (&& (two? (cup os)) (&& (two? (cuup os)) (op-chain? nm))) (op-chn nm os)
                        (. nm os))))
   ; deliver datum d -> (out' . pend'). a collecting frame takes it; a filled infix frame extends
   ; its right operand into a span, since juxtaposition binds tighter: (a = b c) is (= a (b c)).
   ; the span state rides `need`: 0 = a lone datum, -1 = growing.
   (op-del d out pend)
    (? (one? pend) (. (. d out) pend)
       (: f (cap pend) nd (op-frd f)
          (? (= nd -2) (. out (. (op-frw f -2 (. d (op-frg f))) (cup pend)))  ; n-ary: a new operand, always
             (< 0 nd)  (. out (. (op-frw f (- nd 1) (. d (op-frg f))) (cup pend)))
             (: op (cap (op-frg f))                          ; the frame's last (right) operand
                nx (? (= 0 nd) (. op (. d ()))         ; lone -> wrap into (op d)
                      (cat op (. d ())))                  ; span -> append d
                f2 (op-frw f -1 (. nx (cup (op-frg f))))
                (. out (. f2 (cup pend)))))))
   ; take a left operand for an incoming operator of band g and hand h -> (. (out' . pend')), or 0.
   ; at equal band the incomer's hand decides: right-handed steals, left-handed yields. at top
   ; level the whole leading span is taken: (a b = c) captures (a b), not just b. an n-ary frame
   ; holding only its scrutinee has none to give, which keeps (c ? a + b) reading (? c (+ a b)).
   (op-steal g h out pend)
    (? (two? pend)
       (: f (cap pend) nd (op-frd f)
          (? (< nd 1)
             (? (? h (<= g (op-frband f)) (< g (op-frband f)))
                (: r (op-del (op-fold f) out (cup pend)) (op-steal g h (cap r) (cup r)))
                (? (? (= nd -2) (one? (cup (op-frg f))) 0) 0
                   (. (cap (op-frg f))
                         (. out (. (op-frw f (? (= nd -2) -2 1) (cup (op-frg f))) (cup pend))))))
             0))
       (two? out) (. (op-span out) (. () pend))
       0)
   ; fold every pending frame tighter than an incoming (g,h) and answer (out . pend) -- op-steal's
   ; own climb, split out so the chain join can see the frame it will meet: (a < b + c < d) reaches
   ; the second `<` with the additive frame on top, and without this the join never fires.
   (op-climb g h out pend)
    (? (&& (two? pend) (&& (< (op-frd (cap pend)) 1)
                           (? h (<= g (op-frband (cap pend))) (< g (op-frband (cap pend))))))
       (: r (op-del (op-fold (cap pend)) out (cup pend)) (op-climb g h (cap r) (cup r))) (. out pend))
   ; drain at end of list: fold every pending frame innermost-out
   (op-drain out pend)
    (? (one? pend) (rev out)
       (: r (op-del (op-fold (cap pend)) out (cup pend))
          (op-drain (cap r) (cup r))))
   (op-w l out pend)
    (? (atom? l) (op-drain out pend)
       (: e (cap l)
          (? (op-puncp e)
             ; a spaced sigil is one name -- an unrowed one takes the house band, and with no
             ; left operand the infix frame still folds to the plain symbol (op-fold's bare case)
             (: en0 (op-ent e)
                en (? (two? en0) en0 (. e (. 95 (. 0 2))))   ; fresh punct: (e house right . arity 2)
                nm (cap en) gp (caup en) hd (cap (cuup en))
                ; fresh noms: this `:` is one scope, so rebinding out/pend here would make the
                ; op-climb call read its own later binding and raise `missing out`.
                cl (op-climb gp hd out pend) ou (cap cl) pd (cup cl)   ; fold what is tighter, then look
                st (op-steal gp hd ou pd)   ; capture a left operand if one exists (at this band + hand)
                ; the join: a chainable sigil meeting a filled chainable frame at its own band
                ; pushes its own nom into that frame's got and asks for one more, so the run
                ; stays flat. filled is op-steal's test (need below 1), not need 0: a right
                ; operand grown into a span rides -1, and (97 <= s 0 <= 122) is that.
                (? (&& (= -2 (cup (cuup en)))
                       (&& (two? pd)
                           (&& (< (op-frd (cap pd)) 1)
                               (&& (= gp (op-frband (cap pd))) (op-chain? (op-frn (cap pd)))))))
                    (op-w (cup l) ou (. (op-frw (cap pd) 1 (. nm (op-frg (cap pd)))) (cup pd)))
                   (two? st) (op-w (cup l) (caup st)
                            (. (op-fr e nm (? (= -1 (cup (cuup en))) -2 1) gp (. (cap st) ()))   ; -2 = n-ary: the row's lane, so an alias inherits it
                                  (cuup st)))
                   (: r (op-del e ou pd)     ; no left operand: the plain symbol
                      (op-w (cup l) (cap r) (cup r)))))
             (: r (op-del (op-core e) out pend)
                (op-w (cup l) (cap r) (cup r))))))
   ; a `:` binds, it does not apply, so opfix must not rearrange it. binders stay verbatim and only
   ; each pair's value and the trailing body factor. the pairing matches eval's exactly.
   (op-colon fs)
    (? (one? fs) fs
       (one? (cup fs)) (. (op-core (cap fs)) ())        ; a lone form is the body
       (: r (op-dpb (cap fs))                             ; define-sugar binds a \ too: lower its patterns
          (. (cap r)                                     ; the name: verbatim, its params lowered
                (. (op-core (op-wrap (cup r) (caup fs))) ; the value: wrapped where they were, then factored
                      (op-colon (cuup fs))))))              ; the rest: pairs on
   ; a \ lambda is a binder too: the args stay verbatim, only the body factors.
   ; (\ x) -- one operand -- is quote, kept whole by op-core's first clause.
   (op-lam fs)
    (? (one? (cup fs)) (. (op-core (cap fs)) ())        ; the last operand is the body
       (. (cap fs) (op-lam (cup fs))))                    ; an arg: verbatim, recurse
   ; a param that is not a nom is a pattern, and the body takes it apart: (\ [a b] x) is
   ; (\ v (@ v [a b] x)), v fresh. it emits the `@` symbol and stops -- pat expands it at the
   ; reader's own compile. it runs before the nested-lambda flatten, so that pass only ever sees
   ; noms and its shadow check stays a comparison of names: (\ [a b] (\ a x)) must not merge.
   (op-wrap ws b) (? (one? ws) b
                     (op-wrap (cup ws) (. (nom "@") (. (caap ws) (. (caup (cap ws))
                                                       (. b ()))))))
   (op-depat ol ws)
    (? (one? (cup ol)) (. (op-wrap ws (cap ol)) ())          ; the body: wrapped outermost-last
       (: p (cap ol)
          (? (nom? p) (. p (op-depat (cup ol) ws))
             (: v (nom 0) (. v (op-depat (cup ol) (. (. v (. p ())) ws)))))))
   ; the same over a param list with no body -- answers (params . wraps), for the binder below.
   (op-dp ol ws)
    (? (one? ol) (. () ws)
       (: p (cap ol)
          (? (nom? p) (: r (op-dp (cup ol) ws) (. (. p (cap r)) (cup r)))
             (: v (nom 0) r (op-dp (cup ol) (. (. v (. p ())) ws))
                (. (. v (cap r)) (cup r))))))
   ; a define-sugar binder is a lambda: (: (f [a b]) V ..) is (: (f v) (@ v [a b] V) ..).
   ; position 0 is never a pattern -- it is the name, or (curried) the binder that carries it --
   ; so every later position at every level is a param and lowers. a curried binder's inner params
   ; are the earlier arguments, so its wraps go outside this level's. ws is innermost-first.
   (op-dpb b)
    (? (one? b) (. b ())
       (: hr (op-dpb (cap b)) pr (op-dp (cup b) ())
          (. (. (cap hr) (cap pr)) (cat (cup pr) (cup hr)))))
   ; flatten a directly-nested lambda body -- (\ a (\ b B)) -> (\ a b B) -- so neither compiler
   ; builds the extra closure. shadowing stays nested: (\ x (\ x x)) must not merge.
   (op-mem? y l)      (? (one? l) 0 (== y (cap l)) 1 (op-mem? y (cup l)))
   (op-disjoint? a b) (? (one? b) 1 (op-mem? (cap b) a) 0 (op-disjoint? a (cup b)))
   (op-params ol)     (? (one? (cup ol)) () (. (cap ol) (op-params (cup ol))))
   ; the inner lambda lowers before the shadow check, never after the merge: a pattern carried up
   ; as a param binds nothing, and the check compares noms -- (\ [a b] (\ a x)) must not merge.
   (op-flat-ol ol seen)                                      ; -> the flattened operand list, body left raw (op-lam factors it after)
    (? (one? (cup ol))
       (: b (cap ol)
          (? (&& (two? b) (== (cap b) '\) (two? (cuup b)))  ; (two? (cuup b)) = a real lambda, not quote
             (: ol2 (op-depat (cup b) ())
                (? (op-disjoint? seen (op-params ol2)) (op-flat-ol ol2 seen) ol))   ; disjoint inner lambda -> merge its operands up
             ol))                                             ; else the body stays raw
       (. (cap ol) (op-flat-ol (cup ol) (. (cap ol) seen))))   ; a param: keep + accumulate for the shadow check
   ; the comma layer, the loosest grouping, above infix. datums split at top-level commas and the
   ; whole becomes the `,` macro: (a, b c) -> (: _ a (b c)); empty clauses drop. the comma outranks
   ; `:`, so a binder spine splits like any list. the symbol is interned, never written literally.
   (op-cm? l)   (? (one? l) 0 (== (cap l) ',) 1 (op-cm? (cup l)))
   (op-take l)  (? (one? l) () (== (cap l) ',) () (. (cap l) (op-take (cup l))))
   (op-drop l)  (? (one? l) () (== (cap l) ',) (cup l) (op-drop (cup l)))
   (op-split l) (: c (op-take l) r (? (op-cm? l) (op-split (op-drop l)) ())
                   (? (two? c) (. c r) r))
   ; op-core: the factor pass. quote interiors stay verbatim, binding forms keep their binders,
   ; everything else walks. idempotent. has-top-op? gates the lone-operand splice: a bare
   ; list-of-one like ((mov r3 r12)) is data and stays wrapped.
   (has-top-op? x) (? (one? x) 0 (op-puncp (cap x)) 1 (has-top-op? (cup x)))
   ; a list with no operator at its top is its elements factored, in place: the walk below
   ; would rebuild it element by element and answer the same list
   (op-mapi f x) (? (one? x) x (: e (f (cap x)) r (op-mapi f (cup x)) (? (&& (== e (cap x)) (== r (cup x))) x (. e r))))
   (op-core x)
    (? (one? x) x
       (: h (cap x)
          (? (&& (== h '\) (one? (cuup x))) x              ; (\) / (\ x): quote, verbatim
             (op-cm? (cup x))                                ; the comma layer (helpers above)
              (: cs (op-split x)
                 (? (one? cs) ()                            ; commas alone: nothing
                    (one? (cup cs)) (op-core (cap cs))      ; one clause: the commas composed away
                    (. (nom ",") (map op-core cs))))
             (== h '\) (. '\ (op-lam (op-flat-ol (op-depat (cup x) ()) ())))   ; (\ a.. body): patterns to noms, flatten nested lambdas, factor the body
             (== h ':) (. ': (op-colon (cup x)))         ; (: n v ..): binders verbatim
             ; the reader's glued-run emission (mono (run d)): factor the run monadically around
             ; the (recursively opfixed) datum; an unfactorable run is the plain application (run d)
             (&& (== h 'mono) (two? (cup x)) (two? (caup x)))
              (: p (caup x) r (cap p) d (op-core (caup p))
                 fs (? (nom? r) (monofactor r) 0)
                 (? (two? fs) (op-fin fs d) (. r (. d ()))))
             (nil? (has-top-op? x)) (op-mapi op-core x)
             (: res (op-w x 0 0)                        ; an operator at the top: walk, and splice a lone folded operand up
                (? (&& (two? res) (one? (cup res)) (two? (cap res))) (cap res) res))))) ; (a = b) -> (= a b), not ((= a b))
   (opfix x) (op-core x)

   ; the grip door: the one sanctioned write into the compile table, and the only reach to
   ; `operators` once birth mops the nom. (grip ar nm v) answers the row it replaced in the shape
   ; it takes, so (grip ar nm (grip ar nm new)) restores exactly; () clears a row. a shape the lane
   ; refuses rolls back and scares, and a lane with no key is refused rather than minted. the
   ; glued lane accepts anything: a value there is the emitted head, so opfix's output for that
   ; sigil stops being spellable.
   (op-lane-ok? t ar nm) (? (= ar 0) 1 (two? (op-lane nm t ar)))
   (grip ar nm v)
    (: t (operators ar)
       (? (nil? (nom? nm)) (scare 'bad-grip nm)
          (nil? (tablet? t)) (scare 'bad-grip ar)
          (: old (peep t nm ())
             ; identity, never truth: a left-handed band is a negative charm, which nets red --
             ; (nil? -60) is true, and this door would read every left-handed row as a clear.
             (? (== () v) (: _ (pull t nm 0) old)                   ; () clears the row
                (: _ (pin t nm v)
                   (? (op-lane-ok? t ar nm) old                      ; the lane's own read is the acceptor
                      (: _ (? (== () old) (pull t nm 0) (pin t nm old))
                         (scare 'bad-grip nm))))))))

   ; --- this `:` has a body, so the helpers above are local ------------------
   ; opfix and grip are the door. `operators` and `pureset` stay global-and-mopped instead:
   ; ev.l holds them, and a cross-file capture has only the book to go through.
   _ (pin book 'grip grip)
   (pin book 'opfix opfix))
; the last seal: opfix joins the other four in the g->hot_* fields, so no later rebind can reach it.
(seal-hook 4 opfix)

; --- text + sequence batteries ------------------------------------------------
; one copy of each, `sep` first so a partial application reads, and -1 for absent.
(: (fsub s sub i)                                       ; first index >= i of sub in s, or -1
    (? (i + #sub > #s) -1 (snip s i (i + #sub) = sub) i (fsub s sub (i + 1)))

   (join sep l)    (two? l ? (foldl (a \ x \ a + sep + x) <l >l) "")
   (split sep s)                                        ; always >= 1 piece; "" splits nowhere
    (: (go i) (: j (fsub s sep i)
                 (? (#sep = 0 || j < 0) [(snip s i #s)] (snip s i j . go (j + #sep))))
       (go 0))

)    ; (a + 1 a) would read as a + (1 a)

; --- array element-type inference + shape coercion (shared by `tuple` and `array`).
; a-type answers a witness star of the highest tier present, since the generic `tray` ctor
; reads the tier off a witness. a shape dimension may be any numeric and saturates to a nat.
(: ; the int tier takes a cell one machine word wide, so what belongs in it is a question
   ; of magnitude, not of which box the numeral came in. whole? first: love orders across kinds,
   ; so a bare magnitude test would seat a twin in the int tier and say nothing about it.
   (a-rank x) (? (gem? x) 1 (twin? x) 2 (whole? x && (min-word <= x <= max-word)) 0 3)
   (a-emax m x) (: k (a-rank x) (m < k ? k m))
   (a-type d) (: k (foldl a-emax 0 d) (? (k = 0) 0 (k = 1) 0.0 (k = 2) (twin 0 0) ()))   ; a witness star of the tier
   (a-dim d) (two? d ? #d $d)
   (a-shape s) (two? s ? (map a-dim s) (list (a-dim s))))

;;; FIXME we new names for these. tuple isn't too bad but "hash" for the tablet constructor is wrong
; tuple/hash value constructors -- also the read-back targets of the printed @(…) / {…}
(: (spread l) (tray (a-type l) (list (foldl (\ n _ (1 + n)) 0 l)) l))
(:: 'tuple (\ a (list 'spread ('list . a))))
; (hash x) boxes any non-list: a fresh tablet pinning x at 0, so {5} = {0 5} and {} is {0}.
; an odd trailing operand lands in that 0 slot.
(: (hashtx a) (? (one? a) '(tablet 0)
                 (one? >a) (list 'pin (hashtx 0) () <a)
                 (list 'pin (hashtx >>a) <a <>a)))
(:: 'hash (\ a (hashtx a)))

; (array shape elem…): the N-D constructor. shape is a dimension list or a lone number; the
; element type is inferred. the shape fixes the count, so elements are ordinary trailing args.
(: (a-coll sh n acc) (n < 1 ? (: d (rev acc) (tray (a-type d) sh d))
                              (\ x (a-coll sh (n - 1) (x . acc))))
)

; recursive-value boxing for `:` -- the letrec* "capture by location" fix. a reference at-or-before
; its own binding is forward, and indirects through a cell keyed by the binding site's nom, so a
; pre-fill read is a map miss = the missing condition. it emits nif values, not names, so the
; egg's mop cannot break it. 0 when nothing needs boxing, else (prs' . body').
(: (lambp x) (two? x && == '\ <x && two? >>x) ; \ with >=1 param (one-operand \ is quote)
   (dsug n d) (? (one? n) (n . d) (dsug <n ('\ . >n + list d)))
   (lp x) (: a >x (one? >a ? (0 . <a) (init a . last a)))
   (ln bs) (? (one? bs) 0 (one? >bs) 0 (<(dsug <bs 0) . ln >>bs))
   ; w/wl: does x / binding-list bs reference symbol v? \ and : shadow, one-operand \ is quote,
   ; macros expand. u tracks lambda depth; dm counts only references not under a lambda.
   (w v x bnd u dm) (?
    (nom? x) (&& (? dm !u 1) (== x v) !(elem v bnd))
    (one? x) 0
    (: h <x (?
      (== h '\) (? (one? >>x) 0 (: r (lp x) (w v >r (<r + bnd) 1 dm)))
      (== h ':) (wl v >x (cat (ln >x) bnd) u dm)
      (: m (nom? h ? (macros h) 0) (m && !(elem h bnd) ? (w v (m >x) bnd u dm) (any (e \ w v e bnd u dm) x))))))
   (wl v bs bnd u dm) (?
    (one? bs) 0
    (one? >bs) (w v <bs bnd u dm)
    (: nd (dsug <bs <>bs) (? (w v >nd bnd u dm) 1 (wl v >>bs bnd u dm))))
   ; a name wants a cell when something that runs before its slot is filled can read it. two
   ; doors: a direct read from a binding at or before it (for a lambda name, only one not
   ; shielded by a \ -- a call comes after the pin), and, for a value name, a read from anywhere
   ; the earlier bindings reach through the let's own names -- capture, not evaluation order.
   (boxset prs es) (: nm (map cap prs)
     (reads m) >(assoc m es)
     (anyname m) (map cap (reads m))                           ; read anywhere
     (barename m) (map cap (filter (nil? * cup) (reads m)))   ; read not under a \
     (grow s) (: s2 (foldl (a \ m \ a + filter (\ k !(elem k a)) (anyname m)) s s)
                  (#s2 = #s ? s (grow s2)))
     ; near: a read from a binding at or before v. a lambda name takes only the bare ones --
     ; a call comes after the pin -- a value name every one.
     (near v) (: d (lambp >(assoc v prs))
                 (any (m \ elem v (? d (barename m) (anyname m)))
                      (take (1 + lidx v nm) nm)))
     ; reach: v is read from anywhere the bindings before it get to through the let's own
     ; names -- capture, not evaluation order. an earlier closure inherits a later sibling's
     ; captures, so it wants v's slot at construction, before that slot exists.
     (reach v) (elem v (grow (catmap anyname (take (lidx v nm) nm))))
     (filter (\ v (? (near v) 1 (lambp >(assoc v prs)) 0 (reach v))) nm))
   ; breads: the read graph boxset takes -- per def, every sibling name it reads, tagged with
   ; whether the read sat under a \ (u). \ and : bind, a one-operand \ is quote, macros expand,
   ; except a head this let binds, which is a variable and never a macro. c0's door builds it here;
   ; ev.l's census hands boxfix-es the same graph off its own walk.
   (breads prs) (: nm (map cap prs)
     (bref x bnd u acc) (?
      (nom? x) (elem x nm && !(elem x bnd) ? ((x . u) . acc) acc)
      (one? x) acc
      (: h <x (?
        (== h '\) (one? >>x ? acc (: r (lp x) (bref >r (<r + bnd) 1 acc)))
        (== h ':) (brefl >x (ln >x + bnd) u acc)
        (: m (? (nom? h) (macros h) 0)
           (? (m && !(elem h bnd) && !(elem h nm)) (bref (m >x) bnd u acc)
              (foldl (a \ e \ bref e bnd u a) acc x))))))
     (brefl bs bnd u acc) (?
      (one? bs) acc
      (one? >bs) (bref <bs bnd u acc)
      (: nd (dsug <bs <>bs) (brefl >>bs bnd u (bref >nd bnd u acc))))
     (map (p \ <p . bref >p 0 0 ()) prs))
   (mkcs bx) (map (v \ v . mint 0 . v) bx)
   (cellbinds cs) (map (c \ <>c . list tablet 0) cs)
   ; the cell read boxfix emits. a filled cell answers its value; a pre-fill read is a map miss, so
   ; the missing condition carries the binder's own name and the help's result is the value there.
   ; that name reaches the emitted read quoted, so it is a datum there and never a forward ref.
   ; `sent` is minted once and closure-private, so nothing a cell holds poses as absence.
   cellread (: sent (mint 0)
               (\ c nm (: v (peep c nm sent)
                          (? !(== v sent) v
                             !(heard ()) ()
                             (scare 'missing nm))))))

; boxfix-core: the rewrite, refs via sub/subl since c0 has no analysis-time redirect. answers
; (cells pairs.. . body), or () when nothing boxes.
; the law: eager reads see let*, closures see letrec*. a bare read before its name's pin keeps
; the plain nom -- a boxed name's own binding is renamed _, so (: s (trim s)) under a param s
; reads the param. pn is the pinned-so-far set; u is 1 under a \.
(: (boxfix-core prs body es) (: (rmc cs ns) (filter (\ p !(elem <p ns)) cs)
   ; bnd: the lexical binder set, seeded with the scope's own names, so a locally-bound name is
   ; an ordinary variable and never a macro head.
   (sub cs x bnd pn u) (?
    (nom? x) (: p (assoc x cs)
                (? (one? p) x
                   (|| u (elem x pn)) (list cellread <>p (list '\ >>p))
                   x))
    (atom? x) x
    (: h (cap x) (?
      (== h '\) (one? >>x ? x (: r (lp x) ('\ . <r + list (sub (rmc cs <r) >r (<r + bnd) pn 1))))
      (== h ':) (: ns (ln >x) (': . subl (rmc cs ns) >x (cat ns bnd) pn u))
      (: m (macros h) (? (&& m !(elem h bnd)) (sub cs (m >x) bnd pn u) (map (e \ sub cs e bnd pn u) x))))))
   (subl cs bs bnd pn u) (?
    (one? bs) bs
    (one? >bs) (list (sub cs <bs bnd pn u))
    (: nd (dsug <bs <>bs) (<nd . sub cs >nd bnd pn u . subl cs >>bs bnd pn u)))
   (: bx (boxset prs es)
      (? (== () bx) ()
       (: cs (mkcs bx) ns0 (map cap prs)
          (one p pn) (: d (sub cs >p ns0 pn 0)
                        (? (elem <p bx)
                           (: c (assoc <p cs) ('_ . list pin <>c (list '\ >>c) d))
                           (cap p . d)))
          (ones ps pn) (? (one? ps) ()
                          ((one <ps pn) . ones >ps (<<ps . pn)))
          (cs . cellbinds cs + ones prs () . sub cs body ns0 ns0 0))))))
; the flat-list adapters: a `:` binding list -> (the rewritten list . the cells laid), the input
; and () when nothing boxes. boxfix-es takes the read graph (ev.l's census has one); boxfix
; walks for its own. love.c interns "boxfix" and calls it off the book, so c0 compiles prel
; through this. it must exist before ev.l does, and both compilers share the one pass.
(: (boxfix-es fs es) (? (bodyless? fs) (fs . ())
    (: pb (bpr fs) r (boxfix-core <pb >pb es)
       (? r ((catmap (p \ list <p >p) <>r + list >>r) . <r) (fs . ()))))
   (bodyless? l) (? (one? l) 1 (one? >l) 0 (bodyless? >>l))
   (bpr fs) (? (one? >fs) (0 . <fs)
               (: r (bpr >>fs) ((dsug <fs <>fs . <r) . >r)))
   (boxfix fs) (bodyless? fs ? fs <(boxfix-es fs (breads <(bpr fs)))))

; --- scheme and common lisp spellings ---------------------------------------
; every row here is the same function under another name; where the lisp semantics differ
; from love's it is a definition and not an alias, and says so.
(: (assq x l)   (? (two? l) (? (== x (caap l)) (cap l) (assq x (cup l))))
)
; pat -- @ : pattern matching, one macro and no special form. a post-egg layer, not part of
; the language: each frontend includes the layers it wants. its `borrow` must precede every
; reader's compile -- a macro is only in the chain once its layer is spliced, and a consumer
; folds its refs at its own compile. the module exports no names: the macro is the surface,
; and it rides the splice in this layer's macro slot. laws in test/pat.l.
;
; (@ x pat body .. else) reads like `?` with a shape where the test goes: the first pattern
; that fits x runs its body with the pattern's noms bound, an odd trailing operand is the
; else, and no match with no else is the zero point. the reader hands `@` over spaced; glued
; it is still the tray sigil, so @(1 2) never changed hands. it is infix at `?`'s own band,
; n-ary like it: (x @ p b .. else) is the same form with the scrutinee on the left.
;
; a pattern also goes in a \ param, and that half is opfix's: a param that is not a nom
; becomes a fresh one and the body takes it apart, so (\ [a b] x) is (\ v (@ v [a b] x)).
; a define-sugar binder is a \ too, at every level -- op-depat / op-dpb above.
;
; a pattern is its constructor, read backwards: the same text that builds a value matches it.
; it is ordinary surface, already factored -- opfix runs before macros, so the walk below sees
; core forms and never re-parses. a nom binds, `_` swallows, any other atom matches itself,
; and a form's head is its destructuring tag:
;   (a b c)                a form: a chain of three or longer, lax on the tail. the untagged
;                          case, and the common one -- ('lam x b) fits (lam x b ..).
;   [a b]  (list a b)      a chain of exactly two        <- a bracket is its wrap
;   (a . t)  (. a t)       the cons: head a, tail t, and it chains. [a b . t] is
;                          (. (list a b) t) -- a head that is the two-chain (a b).
;   ([a b] + t)            a split: the leading run, then t over what is left. the left side
;                          must be a bracket -- its length picks the split point -- and it
;                          needs its own parens inside @'s operands, like any infix.
;   'a  (\ a)              the literal a, never a binding
;   {'f x}  (hash 'f x)    a map carrying key 'f -- the key an expression, the value a
;                          pattern, matched by subset (the one place a pattern is looser)
;   @(a b)  (tuple a b)    a tray of exactly two
;   (pat & g)              a guard, left to right: pat must fit and g must hold, and it
;                          chains: (c & 0 < c & c < 10). `&&` is the same tag.
;   (? g pat)              the guard the other way round; (& ..) lowers to exactly this
;   (? g)                  the guard alone -- fits anything g holds for
;   (p1 | p2)              alternatives: either shape fits. `||` is the same tag
;   (v @ pat)              the as-pattern, haskell's v@pat, and the only and-pattern: both
;                          sides patterns, neither privileged. spaced -- glued v@pat is one
;                          nom, and glued @( is the tray above.
;   ^x  (jot x)            the pin, elixir's ^x: x is read from outside and the value must
;                          equal it -- the one way a pattern spends a nom without binding it.
;   ()                     the form at zero length: asks nothing, so it fits anything
;   []                     the list at zero length: the empty chain, exactly
; a map key is read for presence, not truth: a pinned () matches, an absent key does not.
;
; parens are the form, brackets are the list: [a b c] fits a chain of exactly three, (a b c)
; one of three or longer -- lax on the tail because a term wears annotations there. `+` stays
; for a tail you want to name; parens only drop the `_`. a head naming no tag is not a
; rejected program: it means the plain thing it looks like.
;
; the guard is the one pattern that is not a constructor -- its operand is read for truth
; where every other is read for shape -- which is why it needs a tag at all: (two? x) is a
; fine untagged pattern as well as a fine call, and nothing but the tag can pick. g binds
; nothing and sees every nom the whole arm binds, because guards do not run where they are
; written: like the non-linear `=` tests they ride at the end of the conjunction, in source
; order, once the structural tests have earned every accessor. so a positional guard is a
; placement for the reader and does not short-circuit any earlier.
;
; a repeated nom matches non-linearly: the second sighting is an `=` against the first's
; access form, not a second binding, so [a a] fits a pair of equals and nothing else.
;
; the expansion is plain core: ((\ v (? test bound-body .. else)) x), each bound body a
; lambda over the pattern's noms applied to the accessor forms. the arguments are read in the
; outer scope, so a pattern nom may wear the name of an accessor its own test needs. cprop
; beta-reduces the wrapper away when the scrutinee is already a value.
(: gone (mint 0)                 ; absence out of band: no stored value poses as a fresh mint
   (lit d) ['\ d]               ; d, as the code that answers d
   ; a literal is compared with `=` -- except a nom, which is interned, so == is the same
   ; answer off one pointer. noms and nothing else: = on a charm is numeric across the band
   ; (5 matches the gem 5.0), and == would quietly narrow that to one representation.
   (weq d v) [['= (lit d) v]]
   wnil [() () ()]
   (wts ts) [ts () ()]
   (wgd g) [() () [g]]
   (wcat x y) [(<x + <y) (<>x + <>y) (<>>x + <>>y)]

   ; `&&` is the guard, left to right: (p && g ..) is (? g .. p). it is right-handed, so a
   ; chain arrives nested -- (p && a && b) is (&& p (&& a b)) -- and that inner `&&` is the
   ; chain, never a guard on its own. flatten it.
   (gand? x) (two? x && == <x '&&)
   (gchain as) (? (one? >as) as
                  (gand? <>as) (<as . gchain ><>as)
                  as)
   (gwrap p gs) (two? gs ? ['? <gs (gwrap p >gs)] p)   ; nested, so `arms` still distributes
   (gnorm p) (: fl (gchain >p) (gwrap <fl >fl))

   ; (pw p v) -- one walk, three answers: the tests over the access form v, the
   ; (nom access) pairs its body binds, and the guards, which are neither.
   (pw p v)
     (? (nom? p) (p = '_ ? wnil [() [[p v]] ()])
        (== p ()) (wts [['= () v]])                        ; () is the empty list, and asks for it
        (one? p) (wts [['= p v]])
        (: h (opword <p) as >p                     ; opfix's glued heads are values; opword names them
           (? (= h '?) (? (one? as) (wlist p v)           ; a guard: (? g1 .. gn pat), or (? g)
                          (one? >as) (wgd <as)           ; ..one operand is the lone guard
                          (wq as v))                         ; ..else every one but the last guards
              ; the guard, in the spelling a hand reaches for: (c && 0 < c) is (? (0 < c) c).
              (h = '&&) (pw (gnorm p) v)
              ; the and-pattern, haskell's v@pat: both shapes must fit and the walks simply
              ; concatenate, since both sides read the same value. a nom in both is the ordinary
              ; non-linear nom, so ([a _] @ [_ a]) fits a pair of equals for free.
              (h = '@) (foldl wcat wnil (map (q \ pw q v) as))
              ; the pin (elixir's ^x, glued to jot by the operators table): not a binding but
              ; an equality against x read from outside -- the same shape a bare literal takes
              ; above, which is what a pin is. one operand only; anything else is a plain form.
              (h = 'jot && 1 = #as) (wts [['= <as v]])
              ; alternatives, anywhere: one test, the branches ||ed. each branch owns its own
              ; equalities and guards. a nom lives at a different place in each branch, so it is
              ; read from whichever matched, and () where none binds it -- a conditional that
              ; re-asks the branch tests, which a branch binding nothing never pays.
              (h = '||)
              (: ws (map (q \ pw q v) as)
                 ds (map (w \ dedup <>w ()) ws)
                 ts (map (e \ two? e && two? >e ? (: w <e d <>e (pand (<w + <d + map (bind <>d) <>>w)))) (zip ws ds))
                 bss (map caup ds)
                 uni (foldl (u \ g \ adds u (map cap g)) () bss)
                 [[('|| . ts)] (map (\ n [n (across n bss ts)]) uni) ()])
              (h = '\) (two? >as ? (wlist p v) (wts (weq <as v)))      ; (\ x b) is a lambda, a form
              (h = 'list) (wlist as v)
              (h = '.) (? (2 = #as)                         ; the cons tag; prefix
                                                                   ; `link` is the function, not a tag
                                        (wcat (wts [['two? v]])
                                              (wcat (pw <as ['cap v]) (pw <>as ['cup v])))
                                        (wlist p v))
              (h = '+) (? (2 != #as) (wlist p v)      ; a split: the left run, then the rest
                          (: l <as t <>as
                             (? (? (two? l) (= <l 'list) ()) (wrest >l t v)
                                ; `+` is left-handed, so ([a b] + [c] + t) arrives as a + whose
                                ; left is a +. cat is associative and so is the split: re-associate
                                ; right and the ordinary rule reads it. this is the multi-split.
                                (? (two? l) (= <l '+) ()) (pw ['+ <>l ['+ <>>l t]] v)
                                (wlist p v))))
              (h = 'hash) (wcat (wts [['tablet? v]]) (wkv as v))
              (h = 'tuple) (wcat (wts [['tray? v] ['= #as ['tally v]]])
                                 (widx as v 0))
              (wlist p v))))                               ; untagged: the form's own shape, exact
   (wq as v) (two? >as ? (wcat (wgd <as) (wq >as v)) (pw <as v))   ; guards, then the shape
   ; a nom's access across an alternative. the first branch that matches wins and supplies
   ; every nom -- one it does not bind reads (), it does not fall through to a later branch.
   (across n bss ts) (one? bss ? (lit ())
                      (: e (assoc n <bss)
                         ['? <ts (one? e ? (lit ()) <>e) (across n >bss >ts)]))
   ; a pattern longer than its value must never reach a `cap`, so the whole run is claimed
   ; before any of it is read: `two?` on the head, then one `long?` for the rest of the depth.
   ; the head's test stays first and separate, not folded into the long?: it is what the
   ; decision tree hoists, and the tag compare must be reachable before the arity walk.
   (warity k v) (? (k = 1) [['two? v]] [['long? k v]])   ; at one, two? is the same answer and fuses
   (wrun ps v end)
     (one? ps ? (end v)
      (: n #ps
       (wcat (wcat (wts [['two? v]]) (pw <ps ['cap v]))
             (n = 1 ? (end ['cup v])
              (wcat (wts (warity (n - 1) ['cup v])) (wskip >ps ['cup v] end))))))
   (wskip ps v end) (one? ps ? (end v) (wcat (pw <ps ['cap v]) (wskip >ps ['cup v] end)))
   (wlist as v) (wrun as v (r \ wts [['= () r]]))
   (wrest ps t v) (wrun ps v (pw t))
   (wkv as v) (one? >as ? wnil
               (: g ['peep v <as (lit gone)]
                (wcat (wcat (wts [['! ['= (lit gone) g]]]) (pw <>as g))
                      (wkv >>as v))))
   (widx as v i) (one? as ? wnil (wcat (pw <as ['peep v i ()]) (widx >as v (i + 1))))

   ; the non-linear pass: a nom already sighted becomes an `=` against the access
   ; form that first bound it, and drops out of the binder list.
   (dedup bs seen)
    (? (one? bs) wnil
     (: b <bs e (assoc <b seen)
      (wcat (one? e ? [() [b] ()] (wts [['= <>e <>b]]))
       (dedup >bs (one? e ? (b . seen) seen)))))

   (pand ts) (? (one? ts) 1 (one? >ts) <ts  ('&& . ts))

   ; the wrapper is ev's to remove, not ours: ev.l's read-once refinement already inlines a
   ; nom read once. a second copy in this macro measured 3.5 M on a 32.5 G corpus -- noise.
   (bind bs body) (one? bs ? body (('\ . map cap bs + [body]) . map caup bs))

   ; --- the decision tree -------------------------------------------------------
   ; a clause is [tests body]. compiled flat, every clause re-runs the tests it shares with
   ; its neighbours, so the common prefix is factored: asked once outside the chain and
   ; dropped from each clause. the else is then reached two ways and written twice, which is
   ; why this only fires for a small else, and it is one level, never recursive.
   (same? a b) (? (two? a) (? (two? b) (? (same? <a <b) (same? >a >b)))
                  (two? b) ()
                  (== a b))
   ; --- factoring, and its one safe shape --------------------------------------
   ; a full decision tree writes the fallthrough twice per level -- 21 distinct tags is 2^21
   ; nodes -- so factoring pays only where the fallthrough does not branch: the prefix every
   ; clause shares, whose failure fails the whole match, so one level and one extra copy.
   (cpx cs)                                         ; the test-prefix common to every clause
     (? (one? cs) ()
        (one? <<cs) ()                        ; a clause with no tests left: stop
        (: t <<<cs
           (? (all (c \ two? <c && same? <<c t) cs)
              (t . cpx (map (c \ [><c <>c]) cs)))))
   (nodes x) (one? x ? 1 (foldl (\ n e (n + (nodes e))) 1 x))
   (flat cs els) ('? . (catmap (\ c [(pand <c) <>c]) cs) + [els])
   ; two clauses or more, or there is nothing to discriminate: at one clause cpx eats all of
   ; its tests, so factoring would read (? p (? 1 body els) els) -- vacuous, and the else twice.
   (tree cs els)
     (: p (cpx cs)
        (? (two? >cs && two? p && nodes els < 40)   ; >=2 clauses, a prefix, a small else
           ['? (pand p) (flat (map (\ c [(drop #p <c) <>c]) cs) els) els]
           (flat cs els)))
   ; --- alternatives, and why they split two ways ------------------------------
   ; (p1 || p2) fits when either does -- `|` too. a nom sits somewhere else in every branch,
   ; so one access cannot serve two shapes. two lanes, both first-branch-wins:
   ;   at the top of an arm -> one clause per branch, sharing the body, written once per branch
   ;   nested -> one clause, the branches `||`ed, each nom read from the winner (pw above)
   ; the body binds the union, and a nom this branch did not bind is bound to () -- which is
   ; what stops it reaching whatever wears that name outside. the arm is normalised first: a
   ; guard wrapping an alternative belongs to every branch, asked once per branch.
   (arms p) (? (one? p) [[p ()]]
               (: h <p as >p
                  (? (h = '||) (catmap arms as)
                     (h = '&&) (arms (gnorm p))                 ; the guard, normalised first
                     (h = '? && 2 = #as)
                       (map (b \ [<b (<as . <>b)]) (arms <>as))
                     [[p ()]])))
   (wgds w gs) (foldl (\ x g (wcat x (wgd g))) w gs)
   (adds u ns) (u + filter (\ n !(elem n u)) ns)    ; u, then what it did not have
   _ (:: '@ (\ a
       (: v (nom 0)
          ; the clause a walk answers: its tests, then its non-linear equalities, then its
          ; guards -- and a body bound over `uni`, whatever this branch did not bind reading ().
          (clofu w uni b)
            (: d (dedup <>w ())
               dd <>d
               mf (n \ [n (lit ())])
               ff (n \ !(assoc n dd))
               bs (dd + map mf (filter ff uni))
               gs (map (bind bs) <>>w)
               [(<w + <d + gs) (bind bs b)])
          (clof w b) (clofu w () b)
          (arm p b)                                    ; the clauses one arm answers for
            (: qs (arms p)
               (? (one? >qs) [(clof (pw p v) b)]   ; one branch: pw takes any guard itself
                  (: ws (map (q \ wgds (pw <q v) <>q) qs)
                     (? (all (one? * caup) ws) [(clof (pw p v) b)]   ; none binds: pw's one test
                        (: uni (foldl (\ u w (adds u (map cap <>(dedup <>w ())))) () ws)
                           (map (w \ clofu w uni b) ws))))))
          (cls r) (? (one? r) [() ()]              ; no clause and no else: the zero point
                     (one? >r) [() <r]             ; the odd tail is the else
                     (: rest (cls >>r)
                        [(arm <r <>r + <rest) <>rest]))
          cl (cls >a)
          [['\ v (tree <cl <>cl)] <a])))
   ())
