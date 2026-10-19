; iop/apx/letc: tag markers feel emits ((iop op . args), (apx nary head . args),
; (letc rows . binds)) and ana dispatches on. globals, so they stay out of ev's captured frame.
(: iop (mint 0)
   apx (mint 0)
   letc (mint 0))

; gone: avw's not-in-book sentinel. a global because it folds into avw as a kim constant, and
; only a global resolves identically in every bootstrap generation.
(: gone (mint 0))

; gv: the layered global read -- (stack ()) walked head-first, `gone` the per-layer miss (a
; stored () shadows), d on total miss. the twin of tablet.c's stacklook: keep in step. the
; test is `==`, never the pin `^gone`, which compiles to `=` and walks what the layer stored.
(: (gv k d) ((: (go c) (c @ (a . u) (: v (peep a k gone) (v == gone ? (go u) v)) d))
             (stack ())))

; feels: value->ap memo for global fns, built once by scanning every global. an ap folds an
; application to a value when its args are constant (pure fns only), else emits an (iop op . args)
; node iap inlines (any nif of matching arity), else leaves it. a nif is found by text shape
; (lvm_ret0 terminator), fold eligibility from `pureset`. a global, so the table stays out of ev's
; value. pureset is keyed by value, and shared with cprop's inliner and the purity gates.
(: pureset (: names ('(+ - * / % & | < <= = >= >) +
          '(// << >> ^
            == gcd modpow abs
            . cap cup caap caup cuap cuup
            dig lidx assoc elem last rev cat
            charm? nom? two? tablet? lit? string? nil? gem? twin? atom?
            snip string
            re im conj arg gem twin
            sin cos tan atan atan2 exp sqrt log fpow))
   (foldl (\ t s (: v (gv s ()) (v ? (pin t v 1) t))) {} names)))
; the container doors, pure or not by what they are handed, so not in pureset: on a tablet peep
; reads mutable state and pin writes it; on text or a chain pin answers a fresh container
(: readset (: names '(peep pin)
   (foldl (\ t s (: v (gv s ()) (v ? (pin t v 1) t))) {} names)))
(: feels (:
   lvm_cur  (pick 0 (+))
   lvm_ret0 (pick 1 cap)
   (bake v) (charm? v ? v ['\ v])           ; value -> source: fixnum bare else quote
   ; (op . arity) iff v is a nif: [op ret0], or [cur arity op ret0]. `pick` reads the
   ; instruction cells and `peek` the arity; a value cell answers () through pick.
   (opof v) (? (lvm_ret0 == pick 1 v) (pick 0 v . 1)
               (lvm_cur == pick 0 v && lvm_ret0 == pick 3 v) (pick 2 v . peek 1 v))
   ; a mint, name or tablet compares by address, so a constant operand of those kinds licenses
   ; lvm_same at lvm_eq's site. eqop rides sameop so a book carrying only one keeps lvm_eq.
   sameop <(opof (gv '== ()))
   eqop (sameop && <(opof (gv '= ())))
   ; () is a mint nom? declines, and the only one, so it compares by address too
   (byaddr? v) (nom? v || tablet? v || v == ())
   (addreq? as) (any (a \ (: k (kconst a) (<k && byaddr? >k))) as)
   (hgen v op ar pure x) (: as >x n #as
    (go hv a) (atom? a ? (bake hv)             ; all args constant -> fold to a value
     (: cv (kconst <a)
      (? (pure && <cv) (go (hv >cv) >a)         ; static arg: fold it into the partial
         (op && n = ar) (iop . (op == eqop && addreq? as ? sameop op) . as)   ; matching-arity nif -> inline
         (hv == v)                                            ; no static prefix folded -> the original apply
          (apx . (? (1 < ar && ar <= n) ar     ;   multi-arg fn the args saturate -> n-ary apply
                    (ar = 1) 1 0) . x)           ;   one-arg -> the l2r chain, else the optimistic apply
         (apx . 0 . bake hv . a))))             ; static prefix folded -> apply the partial to the rest
    (go v as))
   (add t s) (: v (gv s ())
    (charm? v ? t
     (: o (opof v) p (pureset v)
      (o || p ?
       (: op (o ? <o 0)
          ar (? o >o (lvm_cur == pick 0 v) (peek 1 v) 0)   ; nif/multi-arg-fn arity
          (pin t v (hgen v op ar p)))
       t))))
   (foldl add {} (catmap keys (stack ())))))

; opfixed: the tag a caller that already factored its form puts at the head, so ev skips
; opfix. a global: a top-level let holding ev would keep the egg's first-generation closure
; alive in the image.
(: opfixed (mint 0))

; ev = opfix (factor sigils), feel (desugar), ana
(:- (x \ (:
 c (sco 0 [()] ())
 y (feel c (two? x && <x == opfixed ? >x (opfix x)))
 k (ana c y (k0 c) 0 0)
 _ (each (rev (peep c 'defer ())) (t \ t 0))   ; the glaze's compiles that waited on a sibling
 k))
  lvm_cur (pick 0 (+))
  lvm_ret0 (pick 1 cap)
  ; the nil? nif for cflip's head test: opfix's glued lane splices the value, so `!e` reaches
  ; the peephole unnamed
  nilv (gv 'nil? ())
  (sco p a i) {'arg a 'imp i 'par p 'sn 0 'st {}}
  (rootc c) (: p (c 'par) (!p ? c (rootc p)))   ; top scope: where feel stashes 'src
  ; --- the emission interface (the codegen seam) ---
  ; ana emits through curried emitters (\ k n ..): k = the continuation emitter, n = the current
  ; cell index; the thread builds backward, poke -1 prepending. `compose` sequences them. the
  ; leaves: kim x a quote, karg i an arg ref at frame index i, em1/em2 a 1- or 2-word vm op,
  ; kap n an n-ary apply (peeps the continuation for lvm_ret -> a tail call), aco a cond, k0 the
  ; thread terminator. fuse/spa/spq are the peepholes; ava (avw, the scope walker) resolves a
  ; variable to karg (a local), kim (a global constant) or em2 lvm_index. glaze.l implements
  ; the same leaf interface natively, via the ala creation hook (natjit).
  ; `place` writes the op cells, `poke` the operand cells: a cell's kind is its position, so
  ; neither door ever holds a code address.
  (p2 i x) (place -1 i * poke -1 x)
  (em1 x k) (place -1 x * k * (+ 1))
  (em2 i x k) (place -1 i * poke -1 x * k * (+ 2))
  ; karg/kim: emit an arg ref / a quote, fusing with an immediately-following 1-ary apply (lvm_ap)
  ; or tail-call (lvm_tap) kap already wrote into the continuation head -- overwrite that op cell
  ; with the operand (seek 1 keeps what follows) and prepend the fused op. kap over-reserves a
  ; word, so the reclaimed cell becomes -1 slack (spin memsets it; GC-safe).
  ; spa/spq: a zero-operand opcode for the hottest arg indices / quote constants. a compare
  ; chain, not a `peep`, which costs boot more; spq's charm? guard keeps heap values out.
  (spa i) (i @ 0 lvm_arg0 1 lvm_arg1 2 lvm_arg2 3 lvm_arg3 0)
  (spq v) (charm? v ? (v @ 0 lvm_quo0 1 lvm_quo1 2 lvm_quo2
                           3 lvm_quo3 -1 lvm_quom1 -2 lvm_quom2 0) 0)
  ; --- run fusion: the peephole's second axis --------------------------------------
  ; one op for two consecutive loads (lvm_aa/aq/qa/qq, and aap/aqp/qap/qqp when the second
  ; load carries the apply). code builds backward, so a load's successor is already at
  ; `tail`. growing is the ap-fusion move, which leaves the successor's own operands where
  ; they sat, backpatch sites (qsite) included. an operand-specialized successor has no
  ; operand cell, so its implicit value is written out first, spending the second reserved
  ; word. an op that is not a growable load is absent from `rsh`, so a pair never grows
  ; into a triple and nothing grows onto a tap.
  rsh {lvm_arg 1 lvm_arg0 1 lvm_arg1 1 lvm_arg2 1 lvm_arg3 1 lvm_quote 2 lvm_quo0 2 lvm_quo1 2 lvm_quo2 2 lvm_quo3 2 lvm_quom1 2 lvm_quom2 2 lvm_argap 3 lvm_quoteap 4}
  ; the specialized loads and the operand each implies; absent = wide, an explicit operand cell
  rimm {lvm_arg0 0 lvm_arg1 1 lvm_arg2 2 lvm_arg3 3 lvm_quo0 0 lvm_quo1 1 lvm_quo2 2 lvm_quo3 3 lvm_quom1 -1 lvm_quom2 -2}
  ; the shape code names a 1-load run: 1 a, 2 q, 3 argap, 4 quoteap. gop grows one by a
  ; leading load (gs: 1 arg, 2 quote) into a pair, where it stops
  (gop c gs) (gs @ 1 (c @ 1 lvm_aa 2 lvm_aq 3 lvm_aap lvm_aqp)
                     (c @ 1 lvm_qa 2 lvm_qq 3 lvm_qap lvm_qqp))
  ; --- the other axis: fuse a load with the op that consumes it -----------------
  ; the same move, sound because all four consumers keep whatever followed them where it
  ; was, `?`'s else-address included. arg only: a quote consumed by one of these folds at
  ; compile time. the consumer ops are nif bodies, not names in the book, so read them off
  ; the nif value ((pick 0 f) is a 1-arg nif's code slot); lvm_cond resolves by name.
  lvm_cup_ (pick 0 cup) lvm_cap_ (pick 0 cap) lvm_two_ (pick 0 two?)
  ; () when the head is not a known consumer
  (cfuse h) (? (h == lvm_cup_) lvm_argcup (h == lvm_cap_) lvm_argcap
               (h == lvm_two_) lvm_argtwo (h == lvm_cond) lvm_argcond)
  ; load + predicate + cond in one op. h2 is the cell after the predicate's op, always
  ; readable since a thread ends in its terminator. the triple costs no new word: op at
  ; tail, index over the cond, else-address left at tail+2. overwriting the cond cell is
  ; safe because nothing jumps to a cond, only falls into it. only two?: cap/cup before a
  ; cond are rare.
  (cfuse2 h h2) (h2 == lvm_cond && h == lvm_two_ ? lvm_argtwocond ())   ; the () miss is the guard's, so spell it
  ;                                       a=ap-op o=tap-op(0=none) t=plain-op sp=specializer
  ; pc/tc are the shape codes to memoize for the ap-fused and the plain op; gs is our
  ; letter (1=arg, 2=quote)
  (fuse a o t sp pc tc gs x k n)
   (: tail (k (2 + n)) h (pick 0 tail)
      cf (gs = 1 ? (cfuse h))
      c2 (gs = 1 ? (cfuse2 h (pick 1 tail)))
    ; cfuse/cfuse2 miss with (), which no op index spells, so the guard is `!== ()`
    (? (h == lvm_ap)       (p2 a x (seek 1 tail))
       (o && h == lvm_tap) (p2 o x (seek 1 tail))
       (c2 !== ())         (poke 1 x tail, place 0 c2 tail)
       (cf !== ())         (p2 cf x (seek 1 tail))
       (: c (rsh h)
        (c ? (p2 (gop c gs) x (rimm h @ () (seek 1 tail) i (poke -1 i (seek 1 tail))))
           (: s (sp x) (s ? (place -1 s tail)
                            (p2 t x tail)))))))
  ; arg fuses both ap and tap; quote only ap. quote;tap (a constant arg to a tail call) is left
  ; unfused: overwriting the shared tap cell in some emit contexts corrupts a branch's jump target.
  (karg x k n) (fuse lvm_argap   lvm_argtap lvm_arg   spa 3 1 1 x k n)
  (kim  x k n) (fuse lvm_quoteap 0           lvm_quote spq 4 2 2 x k n)
  (k0 c n) (place -1 lvm_ret (poke (1 + n) (ary c) (spin (2 + n))))
  (ary c) (#(c 'arg) + #(c 'imp))
  (pro f) (charm? f ? f (: a (pick 0 f) (?- f
   (a == lvm_unc) (pro (seek -2 (peek 2 f)))
   (a == lvm_cur) (?- f (lvm_unc == pick 2 f)
                          (pro (seek -2 (peek 4 f)))))))
  ; feel: source->source pre-pass before `ana` -- expands macros, constant-folds, and marks applies
  ; with their n-ary-vs-l2r strategy. tail position is untracked; kap detects it at analysis.
  (feel c x) (:
   (wx x bnd)
    (: h <x (h @
     ^x x
     '\ (atom? >>x ? x (wxl1 c x (lp x) bnd))
     '? (atom? >x ? '? (keep x (wxc >x bnd) '?))
     ': (? (atom? >x) ':
           (atom? >>x) (keep x (keep1 >x (wx <>x bnd)) ':)
           (: cr (census (lflat >x) bnd) bs <cr rows >cr    ; boxfix rides the census
              ns (ln bs)
              (letc . rows . wxb bs (ns + bnd) [rows #bnd #ns])))   ; a let's names all shadow throughout
     ; no macro lane: cprop's output is macro-free
     (fold (mapi (e \ wx e bnd) x) bnd)))
   ; lflat: (: a b (: c d e)) -> (: a b c d e). three gates: both lets carry a body (a body-less
   ; inner would hand the outer's names its defglob lane), the names are disjoint, and no inner
   ; name is read by an outer def, since merging widens every outer def's scope.
   (lend bs) (? (atom? bs) ()
                (atom? >bs) bs
                (lend >>bs))             ; the body's one-cell tail, 0 = body-less
   (lsub? (': . u)) (two? (lend u))                 ; a spliceable inner let?
   (lup bs) (atom? >bs ? ><bs (<bs . lup >bs))               ; the body's list, in its place
   ; lrd/lrdl: does x read any name in ms?
   (lrd ms x bnd) (?
    (nom? x) (elem x ms && nil? (elem x bnd))
    (atom? x) 0
    (<x == '\) (atom? >>x ? 0 (: r (lp x) (lrd ms >r (<r + bnd))))
    (<x == ':) (lrdl ms >x (ln >x + bnd))
    (any (e \ lrd ms e bnd) x))
   (lrdl ms bs bnd) (? (atom? bs) 0
    (atom? >bs) 0                                                    ; the trailing body is not a def
    (: nd (dsug <bs <>bs) (lrd ms >nd bnd || lrdl ms >>bs bnd)))
   (lflat bs) (: t (lend bs)
    (!(two? t && lsub? <t) ? bs
     (: b <t ns (ln bs) ms (ln >b)
      (? (any (m \ elem m ns) ms) bs                            ; a name collision
         (lrdl ms bs ns) bs                                          ; an outer def reads an inner name
         (lflat (lup bs))))))
   ; census: one walk of the defs answers boxfix's read graph and, per lambda sibling, the names
   ; it captures, resolved as ana will. an enclosing let's lambda sibling, seen from inside one of
   ; that let's lambda defs, is rebuilt at each reference from its imports, so its row reads there
   ; in its place; the let's own lambda siblings pour and drop; a boxed name is its cell; every
   ; other binder is an import. the rows ride the form to ale as the closures' import rows, so a
   ; letrec builds each lambda once. a nom in head position reads like any other.
   ; c 'fr is the enclosing lets' frames [rows base n], base and n placing a let's names in bnd
   ; from its end, pushed while its lambda defs walk (wxd): the innermost binder of a name decides.
   ; answers (the boxfixed binding list . rows).
   (census bs bnd) (: ns (ln bs) vis (ns + bnd) n #vis frs (c 'fr)
    ; the lists below, as tablets of their first members: a name's place, a key's entry
    (at l i t) (atom? l ? t (at >l (i + 1) (peep t <l -1 < 0 ? (pin t <l i) t)))
    (firsts l t) (atom? l ? t (firsts >l (two? (t <<l) ? t (pin t <<l <l))))
    vt (at vis 0 {})
    ; rd: every read of a covered name, (x u . sh): u 1 under a \, sh the binders over the read
    (rd x sh u acc) (?
     (nom? x) (x != () && 0 <= peep vt x -1 && !(elem x sh) ? ((x . u . sh) . acc) acc)
     (atom? x) acc
     (<x == '\) (atom? >>x ? acc (: r (lp x) (rd >r (<r + sh) 1 acc)))
     (<x == ':) (rdl >x (ln >x + sh) u acc)
     (foldl (a \ e \ rd e sh u a) acc x))
    (rdl bs sh u acc) (? (atom? bs) acc
     (atom? >bs) (rd <bs sh u acc)
     (: nd (dsug <bs <>bs) (rdl >>bs sh u (rd >nd sh u acc))))
    (pairs bs) (atom? >bs ? () (dsug <bs <>bs . pairs >>bs))
    ds (pairs bs)
    rs (map (p \ <p . rd >p () 0 ()) ds)                                            ; per def, its reads
    (own? x) (0 <= peep vt x -1 < #ns)                                              ; one of this let's names
    es (map (r \ <r . foldl (a \ e \ (own? <e ? ((<e . <>e) . a) a)) () >r) rs)  ; the sibling reads, for boxfix
    bf (boxfix-es bs es) cs >bf ct (firsts cs {})
    (cell v) (: p (ct v) (two? p ? <>p v))
    (add y sh acc) (elem y sh || elem y acc ? acc (y . acc))
    ; res: a read into (row . seen). a name resolves the same at every read but one an outer
    ; row reads for, whose names answer to the binders over that read, so only those stay unseen
    (res x sh b) (elem x >b ? b
     (: i (peep vt x -1)
      (i < #ns ? (add (cell x) sh <b . x . >b) (frame x (n - 1 - i) frs sh b))))
    (frame x e fs sh b) (fs @
     ([rows base m] . u) (? (base + m <= e) (add x sh <b . x . >b)             ; bound nearer than this let
                            (base <= e) (: p (assoc x rows) (two? p ? (foldl (a \ y \ add y sh a) <b >p . >b) (add x sh <b . x . >b)))
                            (frame x e u sh b))
     (add x sh <b . x . >b))
    rt (firsts rs {})
    rows (foldl (a \ p \ (lambp >p && !(two? (ct <p)) ? ((<p . <(foldl (b \ e \ res <e >>e b) (() . ()) (rev >(rt <p)))) . a) a)) () (rev ds))   ; reads in source order: the row's slot order
    wt (firsts rows {})
    (grow s) (: s2 (foldl (a \ m \ (two? (wt m) ? (foldl (b \ v \ (elem v b ? b (v . b))) a >(wt m)) a)) s s)
                (#s2 = #s ? s (grow s2)))
    (<bf . map (r \ <r . filter (v \ !(two? (wt v))) (grow >r)) rows))
   ; --- the identity kit: unchanged -> the original, no copy --------------------------------
   ; a `:`-bound non-tail call allocates where an arg/tail-position call is free, so a walk
   ; result rides to its comparison as a sibling-call argument, never a fresh binding.
   (keep x r h) (r == >x ? x (h . r))                        ; the walked tail vs the original
   (keep2 x h r) (h == <x && r == >x ? x (h . r))           ; walked head and tail vs the original
   (keep1 b e) (e == <b ? b [e])
   (keep3 b p q r) (p == <b && q == <>b && r == >>b ? b (p . q . r))
   (mapi f x) (atom? x ? x (mapi2 x (f <x) (mapi f >x)))
   (mapi2 x e r) (e == <x && r == >x ? x (e . r))
   (relam x r b) (b == >r ? x ('\ . <r + [b]))              ; r = (lp x), b the walked body
   (wxl1 c x r bnd) (wxl2 c x (relam x r (wx >r (<r + bnd))))
   (wxl2 c x lam) (push c 'src (>lam . x), lam)            ; surface src for ala, stashed even on identity to keep the assoc order
   (wxb bs bnd fr) (?
    (atom? bs) bs
    (atom? >bs) (keep1 bs (wx <bs bnd))
    (: nd (dsug <bs <>bs)               ; desugar (f a..) so wx's \ adds params to bnd
     (keep3 bs <nd (wxd >nd bnd fr) (wxb >>bs bnd fr))))
   (wxd d bnd fr) (!(lambp d) ? (wx d bnd)                        ; a lambda def walks under its let's frame
                     (push c 'fr fr, (: w (wx d bnd) (pop c 'fr, w))))
   ; cflip: (? (nil? e) c [el]) is (? e [el] c), so drop the nil? wrapper of an exact (nil? e)
   ; test in a 2- or 3-form clause. the head answers to the value as well as the name, and only
   ; the name defers to sh, the shadow: a spliced value has no binder to hide it.
   (cflip bs sh) (: r (cflip1 bs sh) (r == bs ? bs (cflip r sh)))
   (cflip1 bs sh) (two? >bs && two? <bs && atom? >><bs
                   && (<<bs == nilv || (!sh && <<bs == 'nil?)) ?
    (: e <><bs c <>bs rest >>bs
     (? (atom? rest)       [e () c]                ; (nil? e) c    -> (e () c)
        (atom? >rest) [e <rest c]        ; (nil? e) c el -> (e el c)
        bs))
    bs)
   ; cst: kconst re-read as (const? . falsy?), so a folded test prunes its dead branch
   (cst t) (: c (kconst t)
              (? <c (1 . !>c)
                 (atom? >t && atom? <t && !(nom? <t)) (1 . !<t)  ; (c) == c: a folded test lands wrapped
                 0))
   (wxc bs bnd) (: fb (cflip bs (elem 'nil? bnd))
    (? (atom? fb) [()]                           ; clauses ran out: implicit () else
       (atom? >fb) (keep1 fb (wx <fb bnd))      ; the lone else
       (: t (wx <fb bnd) k (cst t)
        (? (atom? k) (keep3 fb t (wx <>fb bnd) (wxc >>fb bnd))   ; unknown -> keep the clause
           >k   (wxc >>fb bnd)               ; statically false -> drop this clause, try the rest
                     [(wx <>fb bnd)]))))     ; statically true  -> this result is the cond, drop rest
   ; napof: v is a non-nif multi-arg fn the n>1 call args saturate -> its arity, the width of the
   ; leading n-ary apply; a surplus arg curries onto that answer, not the head. 1 = a value that
   ; is no cur, which takes its args one at a time; 0 = unknown (not yet bound, or a cur the args
   ; leave short), the optimistic apply. the peeps are `==`-safe: a non-fn value never matches lvm_cur.
   (napof v args) (? (charm? v) 1
                     (lvm_cur !== pick 0 v) (v == () ? 0 1)
                     (: ar (peek 1 v) (1 < ar && ar <= #args ? ar 0)))
   ; fold: un-shadowed global head -> ap (fold/iop/apx); else an apx node (apx n head . args)
   ; carrying the strategy: n > 1 = the leading n-ary apply's width, 0 = the l2r chain.
   (fold x bnd) (: h <x
    (? (atom? >x) x                          ; (f): ana's (atom? b) handles it
       ; a value head (opfix's glued lane, a macro splice): no binding reaches a value, so it
       ; takes feels' lane
       !(nom? h) (: hd (charm? h || two? h ? 0 (feels h))
                          (hd ? (hd x) (apx . 0 . x)))
       (: v (gv h ())
        (? (v == () && !(feels v)) (apx . 0 . x)    ; no global to shadow: the local lane either way
           (elem h bnd) (apx . 0 . x)                ; a shadowed name: local head
           (: hd (feels v) jf (nom? v ? () (jotfuse v)) n (two? jf ? (jotn x jf bnd) ())
            (? (two? n) (apx . napof v >x . ['\ (jf 2)] . jotsub >x <jf <n)   ; a walker over jot: its twin
               hd (hd x)
               (apx . napof v >x . x)))))))
   ; the walked operand of a walker call is (jot N), as fold leaves it: (apx 0 jot N), the head
   ; book's jot by name or by value -> [N], else ()
   (jotn x jf bnd) (: a (two? jf && jf 1 = #>x && >x <jf) j (jotfuse 'jot)
    (two? a && <a == apx && 4 = #a && <>a == 0
     && (: h <>>a (h == j || h == 'jot && !(elem 'jot bnd) && gv 'jot () == j)) ? [<>>>a] ()))
   (jotsub as k n) (k = 0 ? (n . >as) (<as . jotsub >as (k - 1) n))
   ; jotin: a walker over (jot N) whose step is a lambda literal -> a counted loop with the step's
   ; body inline, the twin kept for a list N. the loop's own names are fresh and its ops spliced
   ; as values, so the body captures nothing. a fold's Z and N trade places only when one of them
   ; is plain
   (jotin x bnd) (? (atom? x) x
                    (<x == '\) (atom? >>x ? x (: r (lp x) (relam x r (jotin >r (jsyms <r + bnd)))))
                    (<x == ':) (atom? >x ? x (keep x (jotinb >x (ln >x + bnd)) ':))
                    (jotx (mapi (e \ jotin e bnd) x) bnd))
   (jotinb bs bnd) (? (atom? bs) bs
                      (atom? >bs) (keep1 bs (jotin <bs bnd))
                      (keep3 bs <bs (jotin <>bs (two? <bs ? (jsyms <bs + bnd) bnd)) (jotinb >>bs bnd)))
   (jsyms p) (? (nom? p) [p] (atom? p) () (jsyms <p + jsyms >p))
   (jplain? e) (atom? e || <e == '\ && atom? >>e)
   ; the step's params when it is (\ p.. B) with np distinct plain names, else ()
   (jstep s np) (two? s && <s == '\ && #s = np + 2 && (: ps (init >s)
                  (all (p \ nom? p && p != ()) ps && #ps = #(foldl (a \ p \ (elem p a ? a (p . a))) () ps))) ? (init >s) ())
   (jotx y bnd) (: h <y ops (jotfuse 'ops)
                   jf (nom? h && two? ops ? (gv h () @ v (nom? v || elem h bnd ? () (jotfuse v))) ())   ; a shadowed head has none
                   (? (two? jf && (jf 1) = #>y) (jotk y jf (jsrc (>y <jf) bnd) ops bnd) y))
   ; the source operand (jot N), the book's jot by name or by value -> [N], else ()
   (jsrc L bnd) (two? L && 2 = #L && (: j (jotfuse 'jot) h <L (h == j || h == 'jot && !(elem 'jot bnd) && gv 'jot () == j)) ? [<>L] ())
   (jotk y jf n ops bnd) (: as >y k <jf
                        (? !(two? n) y
                           (: kind (? (jf == jotfuse 'foldl) 0 (jf == jotfuse 'foldr) 1 (jf == jotfuse 'each) 2 3)
                              F (as (k = 0 ? 1 0))
                              ps (jstep F (kind < 2 ? 2 1))
                              (? !(two? ps) y
                                 (kind < 2 && !(jplain? <n || jplain? (as 1))) y
                                 (jotloop kind F ps (last F) <n (as 1) ['\ (jf 2)] ops (jnum? <n bnd ops))))))
   ; N is a number for certain -- a numeric literal, or a book tally -- so no list can reach the loop
   (jnum? N bnd ops) (charm? N || two? N && 2 = #N && (: T (ops 6) h <N (h == T || h == 'tally && !(elem 'tally bnd) && gv 'tally () == T)))
   (jotloop kind F ps B N Z tw ops num) (jotloop1 kind F ps B N Z tw ops @ [b n f l] (num ? (b + [l]) (b + [['? [<ops n] f l]])))
   ; -> [(: n N z Z) awaiting its body, n, the twin's call, the loop]
   (jotloop1 kind F ps B N Z tw ops)
    (: t2 <ops sat <>ops lt <>>ops pl (ops 3) cons (ops 4) rv (ops 5)
       n (nom 0) z (nom 0) go (nom 0) m (nom 0) e (nom 0) a (nom 0) I (kind = 1 ? <ps (ps (#ps - 1))) A <ps
       (? (kind = 0) [[': n N z Z] n [tw F z n] [': m [sat n] [go I A] ['? [lt I m] [go [pl I 1] B] A] [go 0 z]]]
          (kind = 1) [[': n N z Z] n [tw F z n] [': m [sat n] [go I] ['? [lt I m] [': (ps 1) [go [pl I 1]] B] z] [go 0]]]
          (kind = 2) [[': n N] n [tw n F] [': m [sat n] [go I] ['? [lt I m] [': e B [go [pl I 1]]]] [go 0]]]
          [[': n N] n [tw F n] [': m [sat n] [go I a] ['? [lt I m] [go [pl I 1] [cons B a]] [rv a]] [go 0 ()]]]))
   ; cprop: the partial-evaluation pre-pass, before wx and boxfix. it propagates a constant-bound
   ; var and folds a pure-fn call on constant args; pureset is the fold license and a
   ; bnd-shadowed head never folds (the alpha law). it prunes no conds (wxc does) and unfolds no
   ; recursion. only an already-constant RHS propagates, so it is letrec-safe, and a
   ; non-constant rebind or a lambda param kills the name.
   (propk? v) <(kconst v)
   ; se, the static value env: a scope per binder, (tablet . parent). a name maps to its
   ; (name value) entry, or to segone where the binder hides an outer one; a miss asks the parent
   segone (mint 0)
   (seget x se) (? (atom? se) () (: v (peep <se x 0) (? (v == segone) () (two? v) v (seget x >se))))
   (sehide ns se) (foldl (\ t n (pin t n segone)) {} ns . se)   ; a binder's scope, its names hidden
   (cbake v) (v == () || !(nom? v || two? v) ? v ['\ v])                       ; folded value -> source
   (kval v) (atom? v ? v <>v)                                                  ; a const form -> its value
   allk (all propk?)
   ; apply the fn to the consts. a partial of a pure fn is pure at every arity, so this applies
   ; without re-asking; but over-application can make a church numeral, so a step that grows
   ; residualizes the rest, as cpap does.
   (foldc o as) (atom? as ? (cbake o)
                 (: r (o (kval <as))
                  (cpgrew? o r ? (cbake o . as)
                                 (foldc r >as))))
   ; cpap: fold a head's known prefix, one operand at a time, while the value in hand still
   ; applies purely: ("ab" "cd" x) leaves ("abcd" x), (3 2 x) leaves (8 x). a numeric head is
   ; held to a charm-sized answer, since church application can answer an unboundedly large
   ; value from a tiny form. `star?` drops the containers, whose magnitude says nothing of size.
   (cpgrew? v r) (constellation? v && !(star? r && abs r <= max-charm))
   ; a nif the args saturate inlines as an iop in feels' lane, so its prefix stays an operand
   (nifsat? v as) (!(charm? v) && lvm_cur == pick 0 v && lvm_ret0 == pick 3 v && peek 1 v = #as)
   (cpap v as) (: k (two? as ? (kconst <as))
    (? (atom? as) (cbake v)                                              ; every operand consumed -> the value
       !(<k && pure-ap? v >k) (cbake v . as)                      ; unknown operand or an impure apply -> stop
       (: r (v >k) (cpgrew? v r ? (cbake v . as)                      ; ... or a numeral that left the charm band
                       (cpap r >as)))))
   ; --- the known-lambda inliner (cprop's beta-reduction lane) ----------------------------
   ; beta-reduce an application whose resolved head is a statically-known lambda. three gates: the
   ; lambda is inlinable (non-recursive, body bsub-safe, and closed, so it means the same at the
   ; call site), the args are pure (allp), and a fuel bound caps the cascade. an under-saturated
   ; call substitutes the given args and answers a \ of the rest.
   ; `=` does not bridge beta, so a beta-produced closure must never escape where =/==/show could
   ; observe it: one is committed only when consumed (op=1, an enclosing application's head), and
   ; at a value position (op=0) the un-inlined source stays.
   ; the purity oracle: applying v to this known first operand is effect-free. readset is pure
   ; only on an immutable container, which is why k is a parameter.
   (pure-fn? v k) (pureset v || readset v && (string? k || two? k))
   ; two operands, always: under-applied this answers a closure, which is truthy, and every
   ; purity gate below silently opens. `as` is the arg forms: a non-constant denies readset.
   (pure-hv? v as) (pure-fn? v (: k (two? as ? (kconst <as)) (<k ? >k)))
   (pure-head? h as) (pure-hv? (gv h ()) as)
   ; pure-ap?: the same question for cpap's walk, widened by the data lanes, which never run what
   ; they are handed. a partial of a pure fn is not itself in pureset, so the walk stops at one:
   ; ((+) 1 2 x) folds ((+) 1) and no further. () is named apart: nom? declines it.
   (pure-ap? v k) (string? v || two? v || nom? v || v == () || constellation? v || pure-fn? v k)
   (allp as se) (all (a \ purep a se) as)
   (purep a se) (: h <a (?                                                                     ; effect-free -> duplicable/droppable
    (h = '\ || atom? a) 1
    (h = '?) (allp >a se)
    (nom? h) (: e (seget h se)                                              ; a known pure lambda or a pure fn, applied to pure args
     (? (two? e && lambp <>e) (allp >a se) (pure-head? h >a) (allp >a se)))))
   (smpl? x) (?                                                                        ; bsub-safe body: no : / macro head
    (atom? x) 1
    (<x == ':) 0
    (<x == '\) (atom? >>x || smpl? <>x)
    (nom? <x) (!(macros <x) && all smpl? x)
    (all smpl? x))
   (fvs x bs) (?                                                                       ; free vars of a simple term
    (nom? x) (x == () || elem x bs ? () [x])
    (atom? x) ()
    (<x == '\) (two? >>x ? (: r (lp x) (fvs (last x) (<r + bs))))
    (foldl (a \ e \ a + fvs e bs) () x))
   (closedl? lam) (all (v \ gv v ()) (fvs lam ()))                            ; every free var a global (means the same elsewhere)
   (pbody? x bnd) (?                                                                   ; body is pure: every call head a pure fn or a param
    (atom? x) 1
    (<x == '?) (all (e \ pbody? e bnd) >x)
    (<x == '\) (atom? >>x ? 1 (: r (lp x) (pbody? (last x) (<r + bnd))))
    (nom? <x) ((pure-head? <x >x || elem <x bnd) && all (e \ pbody? e bnd) >x)
    (all (e \ pbody? e bnd) x))
   (inlinable? nm lam) (lambp lam && smpl? lam && closedl? lam && pbody? lam () && !(w nm lam 0 0 0))
   (rmkeys ps env) (filter (p \ !(elem <p ps)) env)                         ; drop shadowed substitutions
   (colnms bs) (atom? >bs ? ()                                                  ; a :'s binder noms
                (: n <bs (nom? n ? (n . colnms >>bs) (colnms >>bs))))
   (bsub env x) (?                                                                     ; capture-avoiding substitution
    (nom? x) (assq x env @ (_ . x) x x)
    (atom? x) x
    (<x == '\) (atom? >>x ? x
       (: r (lp x) ps <r ren (map (p \ p . nom 0) ps)                      ; rename binders fresh -> no capture
          ('\ . (map cup ren + [(bsub (ren + rmkeys ps env) (last x))]))))
    (<x == ':) (: nms (colnms >x) ren (map (p \ p . nom 0) nms)       ; whole-form, so an entangled : never reaches here (entg?)
       (map (e \ bsub (ren + rmkeys nms env) e) x))
    (map (e \ bsub env e) x))
   (beta lam as) (: r (lp lam) ps <r np #ps                               ; apply a lambda to args (curried)
    (#as < np ?                                                             ; under-saturated -> substitute the given,
       (bsub (zip ps as) ('\ . drop #as ps + [(last lam)]))             ;   answer a \ of the rest
       (: bd2 (bsub (zip ps (take np as)) (last lam)) rest (drop np as)
          (two? rest ? (bd2 . rest) bd2))))
   ; --- the binding splice (laws: test/uuspllaw.l) --------------
   ; a saturated known-lambda call with an impure arg. pure args substitute; the last effectful
   ; arg substitutes too when its param is read exactly once, unconditionally, and the body is
   ; otherwise pure. every other effectful arg binds once to a fresh nom, in call order, ahead
   ; of the body. a read-many effectful form is never substituted.
   ; rdn: reads of param v in x. an occurrence under \ or ? counts double (it can run zero or
   ; many times), a shadowing binder zeroes its subtree, a quote is data.
   (rdn v x) (?
    (nom? x) (x == v)
    (atom? x) 0
    (<x == '\) (atom? >>x ? 0 (: r (lp x) (elem v <r ? 0 (2 * rdn v (last x)))))
    (<x == '?) (2 * foldl (a \ e \ a + rdn v e) 0 >x)
    (<x == ':) (elem v (colnms >x) ? 0 (foldl (a \ e \ a + rdn v e) 0 >x))
    (foldl (a \ e \ a + rdn v e) 0 x))
   (lasti ps as se) (atom? ps ? -1                                             ; index of the last effectful arg, -1 = none
    (: k (lasti >ps >as se)
     (0 <= k ? (1 + k) (purep <as se) -1 0)))
   (spl ps as se i si bd) (atom? ps ? '(())                               ; (binds . env), call order; si = the substitutable index
    (: r (spl >ps >as se (i + 1) si bd) p <ps a <as
     (? (purep a se) (<r . ((p . a) . >r))
        (i = si && 1 = rdn p bd) (<r . ((p . a) . >r))                  ; the licensed effectful substitution
        (: n (nom 0) ((n . a . <r) . ((p . n) . >r))))))
   (bspl x h h2 hr as se fl op bnd pb) (: r (lp hr) np #<r
    (#as < np ? (keep2 x h2 as)                                           ; under-saturated -> decline: a partial's effects fire at build time
     (: bd0 (last hr)
        ; a nom head resolved through se already passed pbody? at admission
        bok (nom? h || pbody? hr ())
        sp (spl <r (take np as) se 0 (bok ? (lasti <r (take np as) se) -1) bd0)
        bd (bsub >sp bd0)
        rest (drop np as)
      (op || two? rest || !(lambp bd) ?
         (: f2 (atom? <sp ? bd (': . (<sp + [bd])))                          ; no binding left -> no let: the call is gone
            (cprop (two? rest ? (f2 . rest) f2) se (burn fl) op bnd pb))
         (keep2 x h2 as)))))                                                     ; a lambda body escaping at a value position -> decline (the escape law)
   ; a param that shadows an enclosing lambda param or let name renames to a fresh mint (with its
   ; like-named inners: one cluster, so a pre-pin read still sees the outer) -- ana's letrec loads
   ; a sibling's captures by name at each reference site, and a shadow would hand it its own value.
   (cplam x se fl op bnd pb) (atom? >>x ? x                                       ; (\ v) quote -> leave
    (: r (lp x)
     (any (p \ p != '_ && elem p pb) <r ?
        (cplam (foldl (\ z p (p != '_ && elem p pb ? (sub1 z p (nom 0)) z)) x <r) se fl op bnd pb)
        (relam x r (cprop >r (sehide <r se) fl 0 (<r + bnd) (<r + pb))))))          ; the body is a value -> op 0
   ; eager reads see let*, closures letrec*: bsub renames a :'s binders over the whole form, but
   ; a bare read before its name's pin reads the outer binding, and the rename would capture it.
   ; so a body with such an entangled : declines beta and the splice. over-approximate: any
   ; not-yet-pinned sibling name in a def flags.
   (occn v e) (? (e == v) 1 (atom? e) 0 (occn v <e || occn v >e))
   (entg? x) (?
    (atom? x) 0
    (<x == '\) (atom? >>x ? 0 (entg? (last x)))
    (<x == ':) (: nms (colnms >x)
       (walk bs pn) (?
        (atom? bs) 0
        (atom? >bs) (entg? <bs)
        (? (any (v \ !(elem v pn) && occn v <>bs) nms) 1
           (entg? <>bs) 1
           (walk >>bs (<bs . pn))))
       (walk >x ()))
    (any entg? x))
   ; se is the let's own scope, its names hidden on the way in: each binding pins its name as it
   ; goes, so a value sees the bindings before it and the body sees them all
   (cpbinds bs se fl op bnd pb) (?
    (atom? bs) bs
    (atom? >bs) (keep1 bs (cprop <bs se fl op bnd pb))                              ; the let's body inherits the let's op
    (: nd (dsug <bs <>bs) nm <nd v1 (cprop >nd se fl 0 bnd pb)       ; a binding value is a value -> op 0
       _ (pin <se nm (propk? v1 || inlinable? nm v1 ? [nm v1] segone))         ; a const or a known pure lambda enters se
       (keep3 bs nm v1 (cpbinds >>bs se fl op bnd pb))))
   ; bnd: the lexical binder set (\ params + : names): a local is never a macro head, and se can't
   ; stand in, since absence from se doesn't tell local from global.
   ; the atom test stays out of the @ chain: as the pin ^x it would compile to a deep `=`
   (cprop x se fl op bnd pb) (atom? x ?
    (nom? x ? (seget x se @ (_ . e . _) e x) x)              ; const/known-lambda var -> value
    (<x @
    '\ (cplam x se fl op bnd pb)
    ': (ln >x @ ns (keep x (cpbinds >x (sehide ns se) fl op (ns + bnd) (ns + pb)) ':))
    '? (keep x (mapi (e \ cprop e se fl op bnd pb) >x) '?)              ; no prune here -- wxc does it
    h (: m (nom? h ? (macros h) 0)                                          ; an unshadowed macro head expands on raw args
       (m && !(elem h bnd) ? (cprop (opfix-past (m >x) (filter two? >x)) se fl op bnd pb)     ; the expansion is source: opfix lowers its binders' patterns
          (: as (mapi (e \ cprop e se fl 0 bnd pb) >x)
             hr (nom? h ? (: e (seget h se) (atom? e ? h <>e)) (cprop h se fl 1 bnd pb)) ; head is consumed -> op 1
             h2 (nom? h ? (propk? hr && (kind hr) != 'lambda ? hr h) hr)       ; a const-bound nom emits its value; a closure stays a nom
             hk (kconst hr)
             (? (lambp hr && two? as && fuel? fl hr)
                 (? (entg? (last hr))                   ; an entangled : in the body -> no bsub lane is sound
                     (keep2 x h2 as)
                    (allp as se)
                     (: red (cprop (beta hr as) se (burn fl) op bnd pb)                         ; known lambda -> beta, re-cprop (fuel-bounded)
                      (op || !(lambp red) ? red (keep2 x h2 as)))                    ; escaping lambda result -> keep the closure
                    (bspl x h h2 hr as se fl op bnd pb))
                (nom? h && allk as && pure-head? h as && !(elem h bnd))            ; pure-fn on consts -> fold; a binder
                  (foldc (gv h ()) as)                                                ;   spelled like an op still shadows
                ; the same fold for a value head, a macro splice: no name to shadow, so no bnd
                ; guard. ahead of cpap: cpap's licence stops at the first partial, and its
                ; residual reads as a two? head that feels' lane then declines.
                (<hk && atom? >hk && allk as && pure-hv? >hk as)
                  (foldc >hk as)
                (two? as && propk? <as && <hk && pure-ap? >hk (kval <as) && !(nifsat? >hk as))   ; fold the known prefix; an unknown tail
                  (cpap >hk as)                                                       ;   keeps the value as its head
                (keep2 x h2 as)))))))
   (sub1 x p m) (? (x == p) m  (atom? x) x  (<x == '\ && atom? >>x) x
                   (mapi2 x (sub1 <x p m) (sub1 >x p m)))
   ; the fuel: (depth . box), the betas left on this path and the nodes the whole form may
   ; still copy. depth alone bounds a chain, not a tree, where each level can double. a form
   ; copies at most 256 plus 16 per node of its own. the box holds [form] until the first beta
   ; asks, so a form that inlines nothing is never measured
   (left fl) (: b >fl v (peep b 0 0) (? (two? v) (: n (256 + 16 * nsz <v) _ (pin b 0 n) n) v))
   (fuel? fl lam) (: n (nsz (last lam)) _ (pin >fl 'z n) (0 < <fl && n <= left fl))   ; z: the size asked, for burn
   (burn fl) (: b >fl _ (pin b 0 (left fl - peep b 'z 0)) ((<fl - 1) . b))
   (nsz y) (? (two? y) (nsz <y + nsz >y) 1)
   (wx (jotin (cprop x () (64 . {0 [x]}) 0 () ()) ()) ()))   ; bnd seeds (), not 0: `list + 0` would carry 0 into every binder set
  ; a bare symbol is a variable reference, except (), a literal: as a variable it would become a
  ; spurious import. the test is `!= ()`, not nil?: boxfix's cell names are nameless mints, also
  ; nil?, and must still reach ava.
  ; iop/apx stay `=` tests, not ^-pins in an @ chain: a pin reads the name at compile, and these
  ; are letrec siblings not yet built, so the lane would go missing.
  (ana c x) (? (nom? x && x != ())  (ava c x)
               (atom? x) (kim x)
               (: a <x b >x (?
                (atom? b) (ana c a)
                (a = '? ) (aco c b)
                (a = '\ ) (atom? >b ? (kim <b) (ana c (ala c () b 0 1)))
                (a = ': ) (ale c <b >b ())               ; the singleton (: x); feel tags every other let
                (a = letc) (ale c <>b >>b <b)
                (a = iop) (iap c b)
                (a = apx) (apxh c b)
                (app c a b))))     ; never a macro: feel expanded them all
  (push c k x) (pin c k (x . c k), x)
  (pop c k) (c k @ (a . u) (pin c k u, a))
  ; the stack: 'sn slots deep; 'st has each depth's name (a charm key) and each name's depths,
  ; newest first. a restore only lowers 'sn, so a name's depth holds while 'st has it there
  (sput c n) (: k (c 'sn) t (c 'st)
               (pin t k n, charm? n || pin t n (k . t n), pin c 'sn (k + 1), n))
  ; sat: the depth of x's topmost slot, or -1; the stale depths ahead of it go
  (sat c x) (!c ? -1 (: t (c 'st) n (c 'sn)
              (live l) (two? l && !(<l < n && t <l == x) ? (live >l) l)
              l (t x) l2 (live l)
             (l2 == l || pin t x l2, two? l2 ? <l2 -1)))
  (sidx c x) (c 'sn - 1 - sat c x)   ; x's slot counted from the top, as karg takes it
  (iap c b) (: op <b as >b                       ; (iop op . args) -> inline the vm op
   (atom? >as ? (ana c <as * em1 op)      ; one arg
      (: s (c 'sn) k (apr2l c as) (pin c 'sn s, k * em1 op)))) ; n-ary, r2l args
  ; falook: walk the scope chain for head's fixed arity, recorded by ale in each enclosing let's
  ; 'far map. > 0 = a lambda sibling of that arity; 0 = a binding of that name that is
  ; not one -- it shadows outer fars, so stop; -1 = not bound in this scope, keep walking, unless
  ; the name is this scope's own arg or stack local, which shadows the same way.
  (falook c h) (?- 0 c
   (: far (c 'far) a (tablet? far ? (peep far h -1) -1)
    (? (0 < a) a
       (-1 = a && !(elem h (c 'arg) || 0 <= sat c h)) (falook (c 'par) h)
       0)))
  ; apxh: (apx n head . args) -> apply. n > 1 -> r2l eval of the leading n args and one n-ary
  ; apply, surplus args curried onto the answer l2r; n = 1 -> the plain 1-ary chain; n = 0 ->
  ; unknown, the optimistic apply. n comes from fold/napof (a book global); falook (a letrec
  ; lambda sibling) refines an unknown one.
  (apxh c b) (: nary <b head <>b args >>b
              ; lvm_apn enters the callee at cell+2, past the lvm_cur prologue, so `apn n` is sound
              ; only where n is the callee's arity: napof reads it off the value itself, and falook
              ; reads a name out of a compile-time far map, which can answer an enclosing binding
              ; where an inner scope rebinds the name -- so apn takes its guess only exactly
              ; saturated, where a wrong one scares. any other width, or none at all, rides apo,
              ; which checks the callee and lays the l2r chain when it misses.
              fa (nary || !(nom? head) ? 0 (falook c head))
              ex (1 < nary || (1 < fa && fa = #args))         ; a width apn has always taken
              n2 (? (1 < nary) nary
                    (1 = nary || 1 = fa || atom? >args) 0      ; a one-arg head, or one arg: the chain
                    (1 < fa && fa <= #args) fa
                    #args)
              f (ana c head) s (c 'sn) _ (sput c 0) s2 (c 'sn)
              g (n2 ? (napn c args n2 s2 (ex ? 0 1)) (apl2r c args))
              (pin c 'sn s, f * g))
  ; napn: the n-ary apply, then the surplus. the pin puts the compile-time stack back at the head
  ; slot -- apn consumes its arg slots and leaves the answer there, which is where l2r addresses from.
  ; o: the apo lane, the width a guess apo checks
  (napn c args n s o) (: r (drop n args)
                       g (apr2l c (take n args) * (o ? kapo kap) n)
                     (pin c 'sn s,
                      atom? r ? g (g * apl2r c r)))
  (app c a b) (: f (ana c a)
                 s (c 'sn)
                 g (sput c 0,
                    apimp c b)
               (pin c 'sn s, f * g))
 (apl2r c b) (?- id (two? b) (: f (ana c <b) g (apl2r c >b) (f * kap 1 * g)))
 ; apimp: a closure's entry applied to its imports, which are loads and leave it short -- two
 ; or more lay one partial, an uncn cell, where the chain lays one a name
 (apimp c b) (? (atom? b || atom? >b || !(all nom? b)) (apl2r c b)
                (: s (c 'sn) g (apr2l c b * kpart #b) (pin c 'sn s, g)))
 (apr2l c b) (?- id (two? b) (: g (apr2l c >b) f (ana c <b) (sput c 0, g * f)))
 (kap n k m) (kapv lvm_apn lvm_tapn n k m)
 (kapo n k m) (kapv lvm_apo lvm_tapo n k m)
 (kpart n k m) (kapv lvm_part lvm_tpart n k m)
 (kapv a t n k m)
  (:- (p j)
    j (k (2 + m))
    p (pick 0 j == lvm_ret ?                              ; peep the continuation for ret -> tail
       (n > 1 ? (place -1 t * poke 0 n) (place 0 lvm_tap))
       (n > 1 ? (p2 a n) (place -1 lvm_ap))))

  ; aco -- compile a cond (? test result .. else). jump-threaded: a test branches (lvm_cond) to the
  ; next clause on false, else runs its result and jumps to the join, the cond's continuation k,
  ; recorded on the 'join stack for the duration. a constant test picks its branch outright.
  (aco c b) (:- (: f (clauses b) (\ k n (: k2 (f (push c 'join * k) n) (pop c 'join, k2))))
   ; tojoin: after a result, jump to the join (top of 'join), or copy a ret/tap/tapn join inline
   (tojoin k n) (:
    j (k $ 3 + n)
    a <(c 'join)
    i (pick 0 a)
    (? (lvm_ret == i || lvm_tap == i) (p2 i (peek 1 a) j)
       (lvm_tapn == i || lvm_tapo == i) (p2 i (peek 1 a) (poke -1 (peek 2 a) j))
                                      (p2 lvm_jump a j)))
   ; clauses: t/result pairs then a trailing else. a constant test folds to one branch; else emit
   ; lvm_cond -- true runs `then` + jumps to join, false falls to `rest`.
   (clauses b) (?
    (atom? b) (kim ())                                ; no else
    (atom? >b) (ana c <b * tojoin)            ; trailing else: result, then join
    (: test (ana c <b)
       then (ana c <>b)
       rest (clauses >>b)
       (kim = pro test ? (peek 3 test ? then rest)   ; constant test -> pick a branch
        (x \ (test (n \
         (: k (push c 'alt * rest x)                  ; k = the false branch (the rest)
            j (then (tojoin k) $ 2 + n)                    ; true: then, jump to join, into k
            (p2 lvm_cond (pop c 'alt) j)))))))))

  ; recursive-fn ref: a built closure is a constant like any other, through kim's fusion, else
  ; `quote 0` + a backpatch site (lfd . box-of-cell) on the scope for wire to resolve. the cell
  ; rides a box (pin, barriered): a raw poke into tenured data escapes the precise barrier.
  (qsite site k n) (: cell (poke -1 0 * k $ 2 + n)
                      _ (pin >site 0 cell)
                    (place -1 lvm_quote cell))
  ; a closure cell is a box holding (entry . imports): mkc makes, cof reads, cput stores
  (mkc v) {0 v}
  (cof e) (peep >e 0 0)
  (cput e v) (pin >e 0 v, v)
  (lz c lfd scope)(: code <(cof lfd)
                   p (code ? (kim code)
                        (: site (lfd . {})
                         (pin scope 'sites (site . scope 'sites),
                          qsite site)))
                   q (sput c 0,
                      apimp c >(cof lfd))
                 (pin c 'sn (c 'sn - 1),
                  p * q))
  (ava c x) (avw c c x)
  (shadowed? c d x) (: far (d 'far)
   (tablet? far && 0 <= peep far x -1 && sat (d 'par) x < 0))
  (avw c d x)
   (!d ?
    (: y (gv x gone) (y == gone ? (em2 lvm_index x) (kim y)))   ; ==, not the pin: see gv
    (: lfd (assq x (d 'lam)) home (d == c)
     (? (two? lfd) (lz c lfd d)
        (!home && shadowed? c d x)
         (c 'par ? (push c 'imp x), em2 lvm_index x)
        (: (stki d2) (lidx x (d2 'imp + d2 'arg))
           (q i j m) (karg (i + stki c) j m)
         (?- (avw c (d 'par) x)
          (0 <= sat d x) (home ? (karg (sidx c x))
                         (c 'par ? (push c 'imp x), q (c 'sn)))
          (stki d >= 0) (home ? (q (c 'sn))
                         (c 'par ? (push c 'imp x), q (c 'sn))))))))
  ; lambda analyzer
  (ala c imp exp nm hq) (:
   d (sco c (init exp) imp)
   ic (pin (tablet 0) 'l ())                       ; this lambda's inner-closure record, filled by the alas under it
   _ (pin d 'inl ic)
   k (ana d (last exp) (k0 d))
   a (ary d)
   e ((a = 1 ? k (em2 lvm_cur a k)) 0)
   os (assq exp (rootc c 'src))
   ; the surface (\ imps.. params.. body), for the hook to compile from
   s ('\ . (d 'imp + (two? os ? >>os exp)))
   hk (gv 'natjit 0)
   r ((!hk ? e (hq ? (hk e s a gv (farq c) (lamsup c) nm iop apx (ic 'l) (rootc c)) e)) . d 'imp)
   ; the record (exp src-tail (entry . imports)) rides up to the nearest enclosing lambda's,
   ; ahead of its subtree's, so a hook finds an inner lambda site under its body by identity
   up (lamsco c)
   _ (up == 0 ? 0
        (pin up 'l ((hq && nm == 0 ? ([exp (two? os ? >>os 0) r] . ic 'l) (ic 'l)) + up 'l)))
   r)
  (lamsco c) (!c ? 0 (: t (peep c 'inl 0) (t == 0 ? (lamsco (c 'par)) t)))
  ; every enclosing letrec's lambda siblings, the nearest first: an outer sibling is called as a
  ; near one is, off its cell and the imports the caller carries
  (lamsup c) (!c ? () (: l (peep c 'lam ()) r (lamsup (c 'par)) (two? l ? (l + r) r)))
  (farq k x) (!k ? 0
               (: f (k 'far)
                  (tablet? f && 0 <= peep f x -1 ? 1 (farq (k 'par) x))))

  (ale c a b rows) (?                          ; rows: feel's census, (name . imports) per lambda sibling
   (atom? b) (ana c a)
   (:- (wire <cb <>cb >>cb (closures <cb))
    q (sco c (c 'arg) (c 'imp))
    ; collect: (name . def) pairs in source order -> (prs body . even). even = a body-less let,
    ; whose last value is the result and whose names defglob
    (collect prs n d rest) (: nd (dsug n d)
     (? (atom? rest)       (rev (nd . prs) . <nd . 1)   ; body-less: the last name is the body
        (atom? >rest)      (rev (nd . prs) . <rest . 0)   ; a trailing body form
                           (collect (nd . prs) <rest <>rest >>rest)))
    cb (collect 0 a <b >b)
    ; far: {name -> arity} for the lambda siblings, syntactic (binder count off the \-expr); a
    ; value binding or rebound name pins 0, an unknown the optimistic apply. pinned before the
    ; closures analyze their bodies, so falook sees it.
    (farof ps t) (?- t (two? ps)
     (: pr <ps k <pr d >pr
        a (-1 = peep t k -1 && lambp d ? (#>d - 1) 0)
      (farof >ps (pin t k (0 < a ? a 0)))))
    _ (pin q 'far (farof <cb {}))
    ; closures: a cell per lambda sibling, (0 . imports) off its census row, so no closure is
    ; built to learn its captures
    (closures prs) (foldl (a \ pr \ (lambp >pr ? ((<pr . mkc (0 . >(assoc <pr rows))) . a) a)) () prs)

   (wire prs body even lams) (:
    ; weave: emit the binding defs left-to-right; a top-level body-less let's name is defglob'd
    (weave nds) (atom? nds ? id
     (: nd <nds n <nd d >nd
        d (?- d (lambp d) (: cls (assoc n lams)
                             x (ala q >(cof cls) >d n 1)
                             ; the import row is frozen: every compiled ref site applied
                             ; (cup (cof cls)), so growth would under-apply them
                           (#>x != #>(cof cls) ? (scare 'imports-grew n),
                            cput cls x)))
        f (ana c d)
        g (?- id (even && !(c 'par) && !(mint? n)) (em2 lvm_defglob n))  ; a `_` row (opfix's fresh nom) never reaches the book
        h (sput c n,
           weave >nds)
        (f * g * h)))
    s (pin q 'lam lams,
       c 'sn)
    g (sput c 0,
       weave prs)
    ; closures final -> backpatch each recorded recursive-fn ref
    f (each (q 'sites) (s \ poke 0 <(cof <s) (peep >s 0 0)),
       pin q 'sites 0,
       pin c 'sn s,
       ; body-lambda analyzed after inits (it takes the bindings as args; never makes sites)
       ana c ('\ . revcat (map cap prs) [body]))
    h (kap #prs)
    (pin c 'sn s,
     f * g * h)))))
