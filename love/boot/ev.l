; iop/apx/letc: uninterned tag markers feel emits ((iop op . args), (apx nary head . args),
; (letc rows . binds)) and ana dispatches on. top-level globals, not ev-block locals, so they
; stay out of ev's captured frame.
(: iop (mint 0)
   apx (mint 0)
   letc (mint 0))

; gone: avw's not-in-book sentinel. a top-level global like iop/apx, and because it folds into
; avw as a kim constant -- only a global resolves identically in every bootstrap generation.
(: gone (mint 0))

; gv: the layered global read -- (stack ()) walked head-first with `gone` as the per-layer miss
; sentinel (a stored () shadows, never falls through), d on total miss. the C twin is love.c's
; stacklook; keep in step. the sentinel test is `==`, never the pin `^gone`: a pin compiles to
; `=`, which walks whatever the layer stored.
(: (gv k d) ((: (go c) (c @ (a . u) (: v (peep a k gone) (v == gone ? (go u) v)) d))
             (stack ())))

; feels: value->ap memo for global fns, built once by scanning every global. an ap folds an
; application to a value when its args are constant (pure fns only), else emits an (iop op . args)
; node iap inlines (any nif of matching arity), else leaves it. a nif is found by text shape
; (lvm_ret0 terminator), fold eligibility from the curated `names`. a global, not an ev local, so
; feel's fold reaches it by name and the table stays out of ev's value.
; `names`/`pureset` sit at the top level so cprop's inliner shares the effect-free set the purity
; gates read. pureset is keyed by value.
(: pureset (: names ('(+ - * / % & | < <= = >= >) +
          '(// << >> ^
            == gcd modpow abs
            . cap cup caap caup cuap cuup
            dig lidx assoc elem last rev cat
            charm? nom? two? tablet? lit? string? nil? gem? twin? atom?
            snip string
            re im conj arg gem twin
            sin cos tan atan atan2 exp sqrt log fpow))
   (foldl (\ t s (: v (gv s ()) (? v (pin t v 1) t))) {} names)))
; the container doors -- pure or not depending on what they are handed, which is why they cannot
; sit in pureset: on a tablet peep reads mutable state and pin writes it; on text or a chain pin
; has no cell, so it answers a fresh container and the call is a value. keyed by value.
(: readset (: names '(peep pin)
   (foldl (\ t s (: v (gv s ()) (? v (pin t v 1) t))) {} names)))
(: feels (:
   lvm_cur  (pick 0 (+))
   lvm_ret0 (pick 1 cap)
   (bake v) (charm? v ? v ['\ v])           ; value -> source: fixnum bare else quote
   ; (op . arity) iff v is a nif. cells 0/2/3 hold instructions, cell 1 the arity, so `pick`
   ; reads the first three and `peek` the last -- a value cell answers () through pick.
   (opof v) (? (lvm_ret0 == pick 1 v) (pick 0 v . 1)
               (lvm_cur == pick 0 v && lvm_ret0 == pick 3 v) (pick 2 v . peek 1 v))
   ; a mint, name or tablet compares by address, so `=` on one is identity, the cheaper op. a
   ; constant operand of those kinds licenses lvm_same at lvm_eq's site -- the other side may be
   ; any value. eqop rides sameop so a book carrying one and not the other keeps lvm_eq.
   sameop <(opof (gv '== ()))
   eqop (sameop && <(opof (gv '= ())))
   ; nom? is name? and mint? together; () is the serial-0 mint both decline, and there is only
   ; ever the one, so it compares by address like any other point
   (byaddr? v) (nom? v || tablet? v || == v ())
   (addreq? as) (any (a \ (: k (kconst a) (<k && byaddr? >k))) as)
   (hgen v op ar pure x) (: as >x n (tally as)
    (go hv a) (atom? a ? (bake hv)             ; all args constant -> fold to a value
     (: cv (kconst <a)
      (? (pure && <cv) (go (hv >cv) >a)         ; static arg: fold it into the partial
         (op && n = ar) (iop . (op == eqop && addreq? as ? sameop op) . as)   ; matching-arity nif -> inline (the hot path, keep)
         (== hv v)                                            ; no static prefix folded -> the original apply
          (1 < ar && ar <= n ? (apx . ar . x)   ;   multi-arg fn the args saturate -> n-ary apply
                               (apx . 0 . x))   ;   generic l2r apply
         (apx . 0 . bake hv . a))))             ; static prefix folded -> apply the partial to the rest
    (go v as))
   ; the operator symbols are quoted one by one -- bare mid-list they capture their left
   ; neighbor at opfix.
   (add t s) (: v (gv s ())
    (? (charm? v) t
     (: o (opof v) p (pureset v)
      (? (o || p)
       (: op (? o <o 0)
          ar (? o >o (== lvm_cur (pick 0 v)) (peek 1 v) 0)   ; nif/multi-arg-fn arity
          (pin t v (hgen v op ar p)))
       t))))
   (foldl add {} (catmap keys (stack ())))))

; opfixed: the tag a caller that already factored its form puts at the head (the glaze's
; auto-ev), so ev skips opfix. a global like iop, mopped by egg.l; a top-level let holding ev
; itself would keep the egg's first-generation closure alive in the image.
(: opfixed (mint 0))

; ev = opfix (factor sigils), feel (desugar), ana -- the deserialized-data lane
(:- (\ x (:
 c (sco 0 [()] ())
 y (feel c (two? x && <x == opfixed ? >x (opfix x)))
 (ana c y (k0 c) 0 0)))
  lvm_cur (pick 0 (+))
  ; the nil? nif for cflip's head test: opfix's glued lane splices the value, never the name,
  ; so `!e` reaches the peephole unnamed. read once, like lvm_cur.
  nilv (gv 'nil? ())
  (sco p a i) {'arg a 'imp i 'par p}
  (rootc c) (: p (c 'par) (nil? p ? c (rootc p)))   ; top scope: where feel stashes 'src
  ; --- the emission interface (the codegen seam) ---
  ; ana emits through curried emitters (\ k n ..): k = the continuation emitter, n = the current
  ; cell index; the thread builds backward, poke -1 prepending. `compose` sequences them. the
  ; leaves: kim x a quote, karg i an arg ref at frame index i, em1/em2 a 1- or 2-word vm op,
  ; kap n an n-ary apply (peeps the continuation for lvm_ret -> a tail call), aco a cond, k0/k0s
  ; thread terminators. fuse/spa/spq are the peepholes; ava (avw, the scope walker) resolves a
  ; variable to karg (a local, at its [imps args] frame slot), kim (a global constant) or
  ; em2 lvm_index. love/boot/glaze.l implements the same leaf interface natively, over a byte
  ; buffer, via the ala creation hook (book['natjit]).
  ; `place` writes the op cells, `poke` the operand cells -- a thread cell's kind is its
  ; position, so the emitters carry it and neither door ever holds a code address.
  (p2 i x) (place -1 i * poke -1 x)
  (em1 x k) (place -1 x * k * (+ 1))
  (em2 i x k) (place -1 i * poke -1 x * k * (+ 2))
  ; karg/kim: emit an arg ref / a quote, fusing with an immediately-following 1-ary apply (lvm_ap)
  ; or tail-call (lvm_tap) kap already wrote into the continuation head -- overwrite that op cell
  ; with the operand (seek 1 keeps what follows) and prepend the fused op. kap over-reserves a
  ; word, so the reclaimed cell becomes -1 slack (spin memsets it; GC-safe).
  ; spa/spq: a zero-operand opcode for the hottest arg indices / quote constants. a compare chain,
  ; not a `peep` -- a hash made boot +13% against +5% for this chain, and spq's charm? guard keeps
  ; a heap value out of the chain.
  (spa i) (i @ 0 lvm_arg0 1 lvm_arg1 2 lvm_arg2 3 lvm_arg3 0)
  (spq v) (charm? v ? (v @ 0 lvm_quo0 1 lvm_quo1 2 lvm_quo2
                           3 lvm_quo3 -1 lvm_quom1 -2 lvm_quom2 0) 0)
  ; --- run fusion: the peephole's second axis --------------------------------------
  ; spa/spq specialize on an operand's value; these on the shape of a run -- one op for
  ; two consecutive loads (lvm_aa/aq/qa/qq, and aap/aqp/qap/qqp when the second load
  ; carries the apply). no lookahead: code builds backward, so a load's successor is
  ; already in place at `tail`. growing is the ap-fusion move -- overwrite the
  ; successor's op cell with our operand and prepend the fused op, which leaves the
  ; successor's own operands exactly where they sat, backpatch sites (qsite) included.
  ; a successor that was operand-specialized carries no operand cell, so its implicit
  ; value is written out first; the only case spending the second reserved word.
  ; the shape of an instruction is a function of its op word alone, so each question is
  ; a plain lookup on `h`. an op that is not a growable load is absent from `rsh` --
  ; every ap-fused, run-fused and consumer-fused op -- so a pair never grows into a
  ; triple and nothing grows onto a tap, with no bookkeeping to say so.
  rsh {lvm_arg 1 lvm_arg0 1 lvm_arg1 1 lvm_arg2 1 lvm_arg3 1 lvm_quote 2 lvm_quo0 2 lvm_quo1 2 lvm_quo2 2 lvm_quo3 2 lvm_quom1 2 lvm_quom2 2 lvm_argap 3 lvm_quoteap 4}
  ; the specialized loads and the operand each implies. absent = wide: the op carries an
  ; explicit operand cell instead, so arg0/quo0 sit here at 0 rather than being left out.
  rimm {lvm_arg0 0 lvm_arg1 1 lvm_arg2 2 lvm_arg3 3 lvm_quo0 0 lvm_quo1 1 lvm_quo2 2 lvm_quo3 3 lvm_quom1 -1 lvm_quom2 -2}
  ; the shape code names a 1-load run: 1 a, 2 q, 3 argap, 4 quoteap. gop grows one by a
  ; leading load (gs: 1 arg, 2 quote), and a pair is where it stops -- a longer run
  ; chunks into pairs.
  (gop c gs) (gs @ 1 (c @ 1 lvm_aa 2 lvm_aq 3 lvm_aap lvm_aqp)
                     (c @ 1 lvm_qa 2 lvm_qq 3 lvm_qap lvm_qqp))
  ;                                       a=ap-op o=tap-op(0=none) t=plain-op sp=specializer
  ; pc/tc are the shape codes to memoize for the ap-fused and the plain op; gs is our
  ; letter (1=arg, 2=quote), read against a memoized head.
  ; --- the other axis: fuse a load with the op that consumes it -----------------
  ; `cfuse` answers the fused op for a consumer we know, 0 otherwise; the emit is the
  ; same move (overwrite the consumer's op cell with our index, prepend the fused op),
  ; sound because all four consumers keep whatever followed them exactly where it was --
  ; `?`'s else-address included. arg only: a quote consumed by one of these folds at
  ; compile time anyway. the consumer ops are nif bodies, not `insts` entries, so they
  ; are not names in the book -- read them off the nif value the way opof does
  ; ((pick 0 f) is a 1-arg nif's code slot). lvm_cond is an inst and resolves by name.
  lvm_cup_ (pick 0 cup) lvm_cap_ (pick 0 cap) lvm_two_ (pick 0 two?)
  ; () when the head is not a known consumer.
  (cfuse h) (? (h == lvm_cup_) lvm_argcup (h == lvm_cap_) lvm_argcap
               (h == lvm_two_) lvm_argtwo (h == lvm_cond) lvm_argcond)
  ; the rung above: load + predicate + cond in one op. h2 is the cell after the predicate's
  ; op -- always readable, since a thread always has its terminator past the last
  ; instruction. the triple consumes the predicate's op cell and the cond's, so it costs
  ; no new word: op at tail, index over the cond, else-address left where it already sat
  ; at tail+2. overwriting the cond cell is safe because nothing jumps to a cond, only
  ; falls into it (aco's targets are the alt = rest's head, and the join).
  ; only two?: at emit time cap/cup sit before a cond in 8 sites out of 2497.
  (cfuse2 h h2) (h2 == lvm_cond && h == lvm_two_ ? lvm_argtwocond ())   ; the () miss is the guard's, so spell it
  (fuse a o t sp pc tc gs x k n)
   (: tail (k (2 + n)) h (pick 0 tail)
      cf (gs = 1 ? (cfuse h))              ; arg only; () when the head is not a known consumer
      c2 (gs = 1 ? (cfuse2 h (pick 1 tail)))   ; ... and the load+predicate+cond triple
    ; cfuse/cfuse2 miss with (), which no op index spells, so the guard is `!== ()`.
    (? (h == lvm_ap)       (p2 a x (seek 1 tail))
       (o && h == lvm_tap) (p2 o x (seek 1 tail))
       (c2 !== ())         (poke 1 x tail, place 0 c2 tail)
       (cf !== ())         (p2 cf x (seek 1 tail))
       (: c (rsh h)
        (? c (p2 (gop c gs) x (rimm h @ () (seek 1 tail) i (poke -1 i (seek 1 tail))))
           (: s (sp x) (? s (place -1 s tail)
                            (p2 t x tail)))))))
  ; arg fuses both ap and tap; quote only ap. quote;tap (a constant arg to a tail call) is left
  ; unfused: overwriting the shared tap cell in some emit contexts corrupts a branch's jump target.
  (karg x k n) (fuse lvm_argap   lvm_argtap lvm_arg   spa 3 1 1 x k n)
  (kim  x k n) (fuse lvm_quoteap 0           lvm_quote spq 4 2 2 x k n)
  (k0 c n) (place -1 lvm_ret (poke (1 + n) (ary c) (spin (2 + n))))
  ; k0s: like k0 but reserves one extra leading cell for ala to stash the lambda's source \-expr at
  ; value[-1], where the printer (gzput_fn) finds it. entry = cell 1, src = cell 0.
  (k0s c n) (place -1 lvm_ret (poke (2 + n) (ary c) (spin (3 + n))))
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
           (: bs (boxfix (lflat >x))                    ; boxfix = the capture-by-location source rewrite, post-macroexpand
              ns (ln bs) rows (census bs ns bnd)
              (letc . rows . wxb bs (ns + bnd) [rows #bnd #ns])))   ; a let's names all shadow throughout
     ; no macro lane: cprop's output is macro-free -- it expands every nom-headed call under the
     ; same shadow guard.
     (fold (mapi (e \ wx e bnd) x) bnd)))
   ; lflat: (: a b (: c d e)) -> (: a b c d e). three gates: both lets carry a body (a body-less
   ; inner would hand the outer's names its defglob lane), the names are disjoint, and no inner
   ; name is read by an outer def -- merging widens every outer def's scope over the inner names.
   (lend bs) (? (atom? bs) ()
                (atom? >bs) bs
                (lend >>bs))             ; the body's one-cell tail, 0 = body-less
   (lsub? (': . u)) (two? (lend u))                 ; a spliceable inner let?
   (lup bs) (atom? >bs ? ><bs (<bs . lup >bs))               ; the body's list, in its place
   ; lrd/lrdl: does x read any name in ms? the whole row in one walk; no macro lane, cprop's
   ; output having none.
   (lrd ms x bnd) (?
    (nom? x) (elem x ms && nil? (elem x bnd))
    (atom? x) 0
    (<x == '\) (atom? >>x ? 0 (: r (lp x) (lrd ms >r (<r + bnd))))
    (<x == ':) (lrdl ms >x (ln >x + bnd))
    (any (\ e (lrd ms e bnd)) x))
   (lrdl ms bs bnd) (? (atom? bs) 0
    (atom? >bs) 0                                                    ; the trailing body is not a def
    (: nd (dsug <bs <>bs) (lrd ms >nd bnd || lrdl ms >>bs bnd)))
   (lflat bs) (: t (lend bs)
    (? !(two? t && lsub? <t) bs
     (: b <t ns (ln bs) ms (ln >b)
      (? (any (\ m (elem m ns)) ms) bs                            ; a name collision
         (lrdl ms bs ns) bs                                          ; an outer def reads an inner name
         (lflat (lup bs))))))
   ; census: per lambda sibling, the names it reads that a binder covers, resolved as ana will. an
   ; enclosing let's lambda sibling, seen from inside one of that let's lambda defs, is rebuilt at
   ; each reference from its imports, so its row reads there in its place; the let's own lambda
   ; siblings pour and drop; every other binder is an import. the rows ride the form to ale as the
   ; closures' import rows, so a letrec builds each lambda once. quote and the binders read as in
   ; lrd; a nom in head position reads like any other, which is how ana resolves it. c 'fr is the
   ; enclosing lets' frames [rows base n], base and n placing a let's names in bnd from its end,
   ; pushed while its lambda defs walk (wxd): the innermost binder of a name decides.
   (census bs ns bnd) (: vis (ns + bnd) n #vis frs (c 'fr)
    (add y sh acc) (elem y sh || elem y acc ? acc (y . acc))
    (res x sh acc) (: i (lidx x vis) (i < #ns ? (add x sh acc) (frame x (n - 1 - i) frs sh acc)))
    (frame x e fs sh acc) (fs @
     ([rows base m] . u) (? (base + m <= e) (add x sh acc)                   ; bound nearer than this let
                            (base <= e) (: p (assoc x rows) (two? p ? (foldl (a \ y \ add y sh a) acc >p) (add x sh acc)))
                            (frame x e u sh acc))
     (add x sh acc))
    (fv x sh acc) (?
     (nom? x) (x != () && elem x vis && !(elem x sh) ? (res x sh acc) acc)
     (atom? x) acc
     (<x == '\) (atom? >>x ? acc (: r (lp x) (fv >r (<r + sh) acc)))
     (<x == ':) (fvl >x (ln >x + sh) acc)
     (foldl (a \ e \ fv e sh a) acc x))
    (fvl bs sh acc) (? (atom? bs) acc
     (atom? >bs) (fv <bs sh acc)
     (: nd (dsug <bs <>bs) (fvl >>bs sh (fv >nd sh acc))))
    (lrows bs) (? (atom? >bs) ()
     (: nd (dsug <bs <>bs) r (lrows >>bs)
        (lambp >nd ? ((<nd . fv >nd () ()) . r) r)))
    rows (lrows bs) ls (map cap rows)
    (grow s) (: s2 (foldl (a \ m \ (elem m ls ? (foldl (b \ v \ (elem v b ? b (v . b))) a >(assoc m rows)) a)) s s)
                (#s2 = #s ? s (grow s2)))
    (map (r \ <r . filter (v \ !(elem v ls)) (grow >r)) rows))
   ; --- the identity kit: unchanged -> the original, no copy --------------------------------
   ; cprop/wx hand back the input tree wherever nothing rewrote. a `:`-bound non-tail call pays
   ; ~112b where an arg/tail-position call is free, so a walk result rides to its comparison as a
   ; sibling-call argument, never a fresh binding.
   (keep x r h) (r == >x ? x (h . r))                        ; the walked tail vs the original
   (keep2 x h r) (h == <x && r == >x ? x (h . r))           ; walked head and tail vs the original
   (keep1 b e) (e == <b ? b [e])                             ; the one-element list
   (keep3 b p q r) (p == <b && q == <>b && r == >>b ? b (p . q . r))   ; the three-slot spine
   (mapi f x) (atom? x ? x (mapi2 x (f <x) (mapi f >x)))      ; the identity-preserving map
   (mapi2 x e r) (e == <x && r == >x ? x (e . r))
   (relam x r b) (b == >r ? x ('\ . <r + [b]))              ; \ rebuild; r = (lp x), b the walked body (lp's body is (last x))
   (wxl1 c x r bnd) (wxl2 c x (relam x r (wx >r (<r + bnd))))   ; wx's \ lane, framed for arg-position walks
   (wxl2 c x lam) (: _ (push c 'src (>lam . x)) lam)            ; tagged-body -> surface src for ala (stash even on identity: keeps the assoc order)
   (wxb bs bnd fr) (?
    (atom? bs) bs
    (atom? >bs) (keep1 bs (wx <bs bnd))
    (: nd (dsug <bs <>bs)               ; desugar (f a..) so wx's \ adds params to bnd
     (keep3 bs <nd (wxd >nd bnd fr) (wxb >>bs bnd fr))))
   (wxd d bnd fr) (? !(lambp d) (wx d bnd)                        ; a lambda def walks under its let's frame
                     (push c 'fr fr, (: w (wx d bnd) (pop c 'fr, w))))
   ; cflip: the nil?-flip peephole on a cond clause list. the cond tests g_false == nil?, so
   ; (? (nil? e) c [el]) and (? e [el] c) are equal -- flipping drops the nil? wrapper. fires only
   ; on an exact (nil? e) test in a 2- or 3-form clause. the head answers to the value as well as
   ; the name (opfix's glued lane splices the nif, so `!e` arrives unnamed), and only the name arm
   ; defers to sh, the shadow: a spliced value has no binder to hide it.
   (cflip bs sh) (: r (cflip1 bs sh) (r == bs ? bs (cflip r sh)))
   (cflip1 bs sh) (two? >bs && two? <bs && atom? >><bs
                   && (== <<bs nilv || (!sh && == <<bs 'nil?)) ?
    (: e <><bs c <>bs rest >>bs
     (? (atom? rest)       [e () c]                ; (nil? e) c    -> (e () c)
        (atom? >rest) [e <rest c]        ; (nil? e) c el -> (e el c)
        bs))
    bs)
   ; cst: re-read the shared `kconst` (const? . value, prel) as (const? . falsy?) -- a constant's
   ; truth is exactly nil? of its value, so a folded test prunes its dead branch.
   (cst t) (: c (kconst t)
              (? <c (1 . !>c)       ; kconst knows it (atom / quote literal)
                 (atom? >t && atom? <t && !(nom? <t)) (1 . !<t)  ; plus (c) == c: a folded monadic (opfix wraps (! e) -> ((nil? e)), so a folded test lands wrapped)
                 0))
   (wxc bs bnd) (: fb (cflip bs (elem 'nil? bnd))
    (? (atom? fb) [()]                           ; clauses ran out: implicit () else (nil-ontology)
       (atom? >fb) (keep1 fb (wx <fb bnd))      ; the lone else
       (: t (wx <fb bnd) k (cst t)               ; walk the test; is it a static constant?
        (? (atom? k) (keep3 fb t (wx <>fb bnd) (wxc >>fb bnd))   ; unknown -> keep the clause
           >k   (wxc >>fb bnd)               ; statically false -> drop this clause, try the rest
                     [(wx <>fb bnd)]))))     ; statically true  -> this result is the cond, drop rest
   ; napof: v is a non-nif multi-arg fn the n>1 call args saturate -> its arity, the width of the
   ; leading n-ary apply; 0 = no n-ary lane. a surplus arg curries onto that answer, not the head.
   ; the peeps are `==`-safe: a non-fn value never matches lvm_cur.
   (napof v args) (charm? v || !(== lvm_cur (pick 0 v)) ? 0
    (: ar (peek 1 v) (1 < ar && ar <= #args ? ar 0)))
   ; fold: un-shadowed global head -> ap (fold/iop/apx); else an apx node (apx n head . args)
   ; carrying the strategy: n > 1 = the leading n-ary apply's width, 0 = the l2r chain.
   (fold x bnd) (: h <x
    (? (atom? >x) x                          ; (f) single element -> ana's (atom? b) handles
       ; a value head -- opfix's glued lane emits one, and a macro splice can too. no binding
       ; reaches a value, so it is a resolved global by construction and takes feels' lane.
       (nil? (nom? h)) (: hd (charm? h || two? h ? 0 (feels h))
                          (? hd (hd x) (apx . 0 . x)))
       (elem h bnd) (apx . 0 . x)                    ; a shadowed name: local head
       (: v (gv h ()) hd (feels v)
        (? hd (hd x) (apx . napof v >x . x)))))
   ; cprop: the partial-evaluation pre-pass. threads a static value env `se` (name . const-form),
   ; propagating a constant-bound var and folding a pure-fn call on constant args; pureset is the
   ; fold license and a bnd-shadowed head never folds (the alpha law). it prunes no conds (wxc
   ; does) and unfolds no recursion. it runs before wx (pre-boxfix, pre-expansion); only an
   ; already-constant RHS propagates (a forward ref / cell read never is -- letrec-safe), and a
   ; non-constant rebind or a lambda param kills the name.
   (propk? v) <(kconst v)   ; a constant form? -- the const? bit of the shared kconst recognizer (prel; cf. cst, the falsy projection)
   (rmq k (a . u)) (<a @ ^k (rmq k u) (a . rmq k u))
   (cbake v) (v == () || !(nom? v || two? v) ? v ['\ v])                       ; folded value -> source
   (kval v) (atom? v ? v <>v)                                                  ; a const form -> its value
   allk (all propk?)                                                       ; all args constant?
   ; apply the fn to the consts. pure-head?'s licence covers the whole saturated call -- a partial
   ; of a pure fn is pure at every arity -- so this keeps applying without re-asking. it still owes
   ; cpgrew?: over-application turns the answer into a church numeral, the one unbounded lane, so a
   ; step that grows residualizes the rest, exactly as cpap does.
   (foldc o as) (atom? as ? (cbake o)
                 (: r (o (kval <as))
                  (cpgrew? o r ? (cbake o . as)
                                 (foldc r >as))))
   ; cpap: fold a head's known prefix, one operand at a time, for as long as the value in hand
   ; still applies purely -- ("ab" "cd" x) leaves ("abcd" x), (3 2 x) leaves (8 x). the predicate
   ; is re-read every step, so a value that stops being foldable ends the walk and bakes as the
   ; residual head. a numeric head is held to a charm-sized answer: church application is the one
   ; lane where a tiny source form answers an unboundedly large value, and folding bakes it into
   ; the image. `star?` is doing size work, not order work -- it drops the containers, whose
   ; magnitude says nothing about how many cells they are.
   (cpgrew? v r) (constellation? v && nil? (star? r && abs r <= max-charm))
   (cpap v as) (: k (two? as ? (kconst <as))
    (? (atom? as) (cbake v)                                              ; every operand consumed -> the value
       (nil? (<k && pure-ap? v >k)) (cbake v . as)                      ; unknown operand or an impure apply -> stop
       (: r (v >k) (? (cpgrew? v r) (cbake v . as)                      ; ... or a numeral that left the charm band
                       (cpap r >as)))))                                  ; else take the step and walk on
   ; --- the known-lambda inliner (cprop's beta-reduction lane) ----------------------------
   ; beta-reduce an application whose resolved head is a statically-known lambda. three gates: the
   ; lambda is inlinable (non-recursive, body bsub-safe, and closed -- every free var a global, so
   ; it means the same at the call site), the args are pure (allp, so duplicating or dropping them
   ; is unobservable), and a fuel bound caps the cascade. an under-saturated call substitutes the
   ; given args and answers a \ of the rest -- currying, statically.
   ; beta is not bridged by `=` on closures, so a beta-produced closure must never escape to where
   ; =/==/show could observe it: the operator-position flag `op` is the guard -- a beta result that
   ; is itself a lambda is committed only when consumed (op=1, an enclosing application's head),
   ; and at a value position (op=0) we revert to the un-inlined source.
   ; the purity oracle: applying this function value to this known first operand is effect-free.
   ; pureset is pure at every operand, so it ignores k; readset is pure only on an immutable
   ; container, which is the whole reason k is a parameter.
   (pure-fn? v k) (pureset v || (readset v && (string? k || two? k)))
   ; two operands, and the arity is the protocol: under-applied this answers a closure, which is
   ; truthy, and every purity gate below silently opens. `as` is the arg forms, not values --
   ; kconst declines a non-constant, so a site that cannot know its operand denies readset.
   (pure-hv? v as) (pure-fn? v (: k (two? as ? (kconst <as)) (? <k >k)))
   (pure-head? h as) (pure-hv? (gv h ()) as)
   ; pure-ap?: the same question for cpap's walk, widened by the data lanes -- which never run
   ; what they are handed: a sequence indexes or joins, a point answers const-1, a numeric or
   ; array composes. a partial of a pure fn is not itself in pureset, so the walk stops at one:
   ; ((+) 1 2 x) folds ((+) 1) and no further. the zero point is named separately: it applies
   ; like a mint, but name? and mint? partition nom?, and () is in neither.
   (pure-ap? v k) (string? v || two? v || nom? v || v == () || constellation? v || pure-fn? v k)
   (allp as se) (all (a \ purep a se) as)                                  ; all args effect-free?
   (purep a se) (: h <a (?                                                                     ; effect-free -> duplicable/droppable
    (h = '\ || h = a) 1                                                                         ; nom / number / string
    (h = '?) (allp >a se)                                                  ; cond: pure iff every limb is
    (nom? h) (: e (assq h se)                                               ; a known pure lambda or a pure fn, applied to pure args
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
    (== <x '\) (two? >>x ? (: r (lp x) (fvs (last x) (<r + bs))))
    (foldl (a \ e \ a + fvs e bs) () x))
   (closedl? lam) (all (v \ gv v ()) (fvs lam ()))                            ; every free var a global (means the same elsewhere)
   (pbody? x bnd) (?                                                                   ; body is pure: every call head a pure fn or a param
    (atom? x) 1
    (<x == '?) (all (e \ pbody? e bnd) >x)
    (<x == '\) (? (atom? >>x) 1 (: r (lp x) (pbody? (last x) (<r + bnd))))
    (nom? <x) ((pure-head? <x >x || elem <x bnd) && all (e \ pbody? e bnd) >x)
    (all (e \ pbody? e bnd) x))
   (inlinable? nm lam) (lambp lam && smpl? lam && closedl? lam && pbody? lam () && !(w nm lam 0 0 0))
   (rmkeys ps env) (filter (\ p !(elem <p ps)) env)                         ; drop shadowed substitutions
   (colnms bs) (atom? >bs ? ()                                                  ; the : letrec's binder noms (sugar already lowered to \ by cpbinds)
                (: n <bs (nom? n ? (n . colnms >>bs) (colnms >>bs))))
   (bsub env x) (?                                                                     ; capture-avoiding substitution
    (nom? x) (assq x env @ (_ . x) x x)
    (atom? x) x
    (== <x '\) (atom? >>x ? x
       (: r (lp x) ps <r ren (map (p \ p . nom 0) ps)                      ; rename binders to fresh -> no capture
          ('\ . (map cup ren + [(bsub (ren + rmkeys ps env) (last x))]))))
    (== <x ':) (: nms (colnms >x) ren (map (p \ p . nom 0) nms)       ; rename the :'s binders fresh so a subst can't be captured -- whole-form, which is
                                                                             ;   why an entangled : (a bare pre-pin sibling read) never reaches bsub (entg?)
       (map (\ e (bsub (ren + rmkeys nms env) e)) x))
    (map (\ e (bsub env e)) x))
   (beta lam as) (: r (lp lam) ps <r np #ps                               ; apply a lambda to args (curried)
    (? (#as < np)                                                             ; under-saturated -> substitute the given,
       (bsub (zip ps as) ('\ . drop #as ps + [(last lam)]))             ;   answer a \ of the rest (bsub's \ case
                                                                                   ;   renames the rest fresh -> capture-free)
       (: bd2 (bsub (zip ps (take np as)) (last lam)) rest (drop np as)
          (two? rest ? (bd2 . rest) bd2))))
   ; --- the binding splice (laws: test/uuspllaw.l) --------------
   ; a saturated known-lambda call with an impure arg. pure args substitute (sl-sub); the last
   ; effectful arg substitutes too when its param is read exactly once, unconditionally, and the
   ; body is otherwise pure (sl-sub-1). every other effectful arg binds once to a fresh nom, in
   ; call order, ahead of the body -- `:` binds in source order, the call's own effect order
   ; (sl-ord) -- and the body reads the nom at every use site. a read-many effectful form is
   ; never substituted (sl-flip: value equal, trace doubled).
   ; rdn: reads of param v in x. an occurrence under \ or ? counts double (a site that can
   ; run zero or many times is never "exactly once"), a shadowing binder zeroes its subtree,
   ; a quote is data. cprop already desugared any `:` in x, so colnms reads its binders.
   (rdn v x) (?
    (nom? x) (x == v)
    (atom? x) 0
    (<x == '\) (atom? >>x ? 0 (: r (lp x) (elem v <r ? 0 (2 * (rdn v (last x))))))
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
    (#as < np ? (keep2 x h2 as)                                           ; under-saturated -> decline (a partial's effects fire at build time; the pure lane's curry bet is not licensed here)
     (: bd0 (last hr)
        ; a nom head resolved through se already passed pbody? at admission -- only a
        ; literal lambda head pays the walk here.
        bok (nom? h || pbody? hr ())
        sp (spl <r (take np as) se 0 (? bok (lasti <r (take np as) se) -1) bd0)
        bd (bsub >sp bd0)
        rest (drop np as)
      (op || two? rest || !(lambp bd) ?
         (: f2 (atom? <sp ? bd (': . (<sp + [bd])))                          ; no binding left -> no let: the call is gone
            (cprop (two? rest ? (f2 . rest) f2) se (fl - 1) op bnd pb))
         (keep2 x h2 as)))))                                                     ; a lambda body escaping at a value position -> decline (the escape law)
   ; a param that shadows an enclosing lambda param renames to a fresh mint (with its like-named
   ; inners: one cluster, so a pre-pin read still sees the outer) -- ana's letrec loads a
   ; sibling's captures by name at each reference site, and a shadow would hand it its own value.
   (cplam x se fl op bnd pb) (atom? >>x ? x                                       ; (\ v) quote -> leave
    (: r (lp x)
     (? (any (p \ p != '_ && elem p pb) <r)
        (cplam (foldl (\ z p (? (p != '_ && elem p pb) (sub1 z p (nom 0)) z)) x <r) se fl op bnd pb)
        (relam x r (cprop >r (rmkeys <r se) fl 0 (<r + bnd) (<r + pb))))))          ; the body is a value -> op 0
   ; the new-law guard (eager reads see let*, closures see letrec*): bsub renames a :'s binders
   ; over the whole form, letrec-wise, but a bare read before its name's pin reads the outer
   ; binding and that rename would capture it -- so a body carrying such an entangled : declines
   ; beta and the splice. over-approximate: any not-yet-pinned sibling name in a def flags.
   (occn v e) (? (== e v) 1 (atom? e) 0 (|| (occn v <e) (occn v >e)))
   (entg? x) (?
    (atom? x) 0
    (== <x '\) (? (atom? >>x) 0 (entg? (last x)))
    (== <x ':) (: nms (colnms >x)
       (walk bs pn) (?
        (atom? bs) 0
        (atom? >bs) (entg? <bs)
        (? (any (\ v (nil? (elem v pn) && occn v <>bs)) nms) 1
           (entg? <>bs) 1
           (walk >>bs (<bs . pn))))
       (walk >x ()))
    (any entg? x))
   (cpbinds bs se fl op bnd pb) (?
    (atom? bs) bs
    (atom? >bs) (keep1 bs (cprop <bs se fl op bnd pb))                              ; the let's body inherits the let's op
    (: nd (dsug <bs <>bs) nm <nd v1 (cprop >nd se fl 0 bnd pb)       ; a binding value is a value -> op 0
       se2 (propk? v1 || inlinable? nm v1 ?                                      ; a const or a known pure lambda enters se
              ([nm v1] . rmq nm se) (rmq nm se))
       (keep3 bs nm v1 (cpbinds >>bs se2 fl op bnd pb))))
   ; bnd: the lexical binder set (\ params + : names), one-scope. its one reader is the macro lane:
   ; a locally-bound name is an ordinary variable, never a macro head (the shadow law; se can't
   ; stand in -- absence from se doesn't distinguish local from global).
   ; the atom test stays out of the @ chain: as a pattern it would be the pin ^x, and a pin
   ; compiles to `=` -- a deep structural walk where this is one cheap test per node.
   (cprop x se fl op bnd pb) (<x = x ?
    (nom? x ? (assq x se @ (_ . e . _) e x) x)               ; const/known-lambda var -> value
    (<x @
    '\ (cplam x se fl op bnd pb)
    ': (ln >x @ ns (keep x (cpbinds >x (rmkeys ns se) fl op (ns + bnd) pb) ':))
    '? (keep x (mapi (e \ cprop e se fl op bnd pb) >x) '?)              ; no prune here -- wxc does it
    h (: m (? (nom? h) (macros h) 0)                                          ; macro head, not shadowed? expand on raw args -- a
       (? (m && !(elem h bnd)) (cprop (opfix (m >x)) se fl op bnd pb)     ; the expansion is source: opfix lowers its binders' patterns                  ; structural macro (a two?/cap probe) must see them
          (: as (mapi (e \ cprop e se fl 0 bnd pb) >x)
             hr (nom? h ? (: e (assq h se) (atom? e ? h <>e)) (cprop h se fl 1 bnd pb)) ; head is consumed -> op 1
             h2 (nom? h ? (propk? hr && (kind hr) != 'lambda ? hr h) hr)       ; the emitted head: a const-bound nom is its value -- a closure stays a nom (the frame imports the name and the glaze reads it)
             hk (kconst hr)                                                       ; the head's own value, when it has one
             (? (0 < fl && lambp hr && two? as)
                 (? (entg? (last hr))                   ; an entangled : in the body -> no bsub lane is sound;
                     (keep2 x h2 as)                                                     ;   keep the call (boxfix's runtime law answers it)
                    (allp as se)                        ; two? as: (f) is f -- nothing to substitute
                     (: red (cprop (beta hr as) se (fl - 1) op bnd pb)                       ; known lambda -> beta, re-cprop (fuel-bounded)
                      (op || !(lambp red) ? red (keep2 x h2 as)))                    ; escaping lambda result -> revert (keep the closure)
                    (bspl x h h2 hr as se fl op bnd pb))                                     ;    foldc/cpap are dead for a lambda head, so its decline keeps the call)
                (nom? h && allk as && !(elem h bnd) && pure-head? h as)            ; pure-fn on consts -> fold. bnd-guarded: a binder
                  (foldc (gv h ()) as)                                                ;   spelled like an op still shadows (the alpha law)
                ; the same fold for a head that arrived as a value -- a macro splice. the purity
                ; tables are keyed by value, and a value has no name to shadow, hence no bnd guard.
                ; ahead of cpap on purpose: cpap's licence stops at the first partial, and the
                ; residual it bakes reads as a two? head that feels' sticky lane then declines.
                (<hk && one? >hk && allk as && pure-hv? >hk as)
                  (foldc >hk as)
                (two? as && propk? <as && <hk && pure-ap? >hk (kval <as))             ; a pure-applying head with a known operand: fold the whole
                  (cpap >hk as)                                                       ;   known prefix, an unknown tail keeps the value as its head
                (keep2 x h2 as)))))))                                                ; nothing rewrote -> the original call
   (sub1 x p m) (? (== x p) m  (atom? x) x  (<x == '\ && atom? >>x) x
                   (mapi2 x (sub1 <x p m) (sub1 >x p m)))
   (wx (cprop x () 64 0 () ()) ()))   ; bnd seeds (): a 0 seed rode `list + 0` into every binder set
  ; a bare symbol is a variable reference -- except the zero point, which reads as a nom? literal;
  ; routing it to ava captures it as a spurious import, an under-saturated partial. the test is
  ; ==-the-zero-point, not nil?: boxfix's cell names are fresh nameless mints (also nil?) bound
  ; and referenced as real variables, so they must still reach ava.
  ; iop/apx stay `=` tests, not ^-pins in an @ chain: a pin reads the name to match against, and
  ; these two are letrec siblings this form is compiled before -- the read finds the cell empty
  ; and the whole lane goes missing.
  (ana c x) (? (nom? x && x != ())  (ava c x)
               (atom? x) (kim x)
               (: a <x b >x (?
                (atom? b) (ana c a)
                (a = '? ) (aco c b)
                (a = '\ ) (? (atom? >b) (kim <b) (ana c (ala c () b 0 1)))
                (a = ': ) (ale c <b >b ())               ; the singleton (: x); feel tags every other let
                (a = letc) (ale c <>b >>b <b)
                (a = iop) (iap c b)
                (a = apx) (apxh c b)
                (app c a b))))     ; a value head: ala's (entry . imports) -- apply the built
                                  ; closure to its imports. never a macro (feel expanded them all).
  (push c k x) (pin c k (x . c k), x)
  (pop c k) (c k @ (a . u) (pin c k u, a))
  (iap c b) (: op <b as >b                       ; (iop op . args) -> inline the vm op
   (atom? >as ? (ana c <as * em1 op)      ; one arg
      (: s (c 'stk) k (apr2l c as) (pin c 'stk s, k * em1 op)))) ; n-ary, r2l args
  ; falook: walk the scope chain for head's fixed arity, recorded by ale in each enclosing let's
  ; 'far map. > 0 = a multi-arg lambda sibling of that arity; 0 = a binding of that name that is
  ; not one -- it shadows outer fars, so stop; -1 = not bound in this scope, keep walking.
  (falook c h) (?- 0 c
   (: far (c 'far) a (tablet? far ? (peep far h -1) -1)
    (? (0 < a) a (-1 = a) (falook (c 'par) h) 0)))
  ; apxh: (apx n head . args) -> apply. n > 1 -> r2l eval of the leading n args and one n-ary
  ; apply, surplus args curried onto the answer l2r; n = 0 -> the plain 1-ary chain. the width
  ; comes from fold/napof (a book global) or falook (a letrec lambda sibling the args saturate).
  (apxh c b) (: nary <b head <>b args >>b
              ; the surplus lane is napof's alone. lvm_apn enters the callee at cell+2, past the
              ; lvm_cur prologue, so `apn n` is sound only where n is the callee's arity -- napof
              ; reads that off the value itself, but falook reads a name out of a compile-time far
              ; map and can answer an enclosing binding's arity where an inner scope rebinds the
              ; name. exact saturation is the most a guess can carry.
              n2 (? nary nary (nom? head && (: a (falook c head) (1 < a && a = #args && a))))
              f (ana c head) s (c 'stk) _ (push c 'stk 0) s2 (c 'stk)
              g (? n2 (napn c args n2 s2) (apl2r c args))
              (pin c 'stk s, f * g))
  ; napn: the n-ary apply, then the surplus. the pin puts the compile-time stack back at the head
  ; slot -- apn consumes its arg slots and leaves the answer there, which is where l2r addresses from.
  (napn c args n s) (: r (drop n args)
                       g (apr2l c (take n args) * kap n)
                     (pin c 'stk s,
                      atom? r ? g (g * apl2r c r)))
  (app c a b) (: f (ana c a)
                 s (c 'stk)
                 g (push c 'stk 0,
                    apl2r c b)
               (pin c 'stk s, f * g))
 (apl2r c b) (?- id (two? b) (: f (ana c <b) g (apl2r c >b) (f * kap 1 * g)))
 (apr2l c b) (?- id (two? b) (: g (apr2l c >b) f (ana c <b) (push c 'stk 0, g * f)))
 (kap n k m)
  (:- (p j)
    j (k (2 + m))
    p (pick 0 j == lvm_ret ?                              ; peep the continuation for ret -> tail
       (n > 1 ? (place -1 lvm_tapn * poke 0 n) (place 0 lvm_tap))
       (n > 1 ? (p2 lvm_apn n) (place -1 lvm_ap))))

  ; aco -- compile a cond (? test result .. else). jump-threaded: a test branches (lvm_cond) to the
  ; next clause on false, else runs its result and jumps to the join, the cond's continuation k,
  ; recorded on the 'join stack for the duration. a constant test picks its branch outright.
  (aco c b) (:- (: f (clauses b) (\ k n (: k2 (f (push c 'join * k) n) (pop c 'join, k2))))
   ; tojoin: after a result, jump to the join (top of 'join) -- but fuse a ret/tap/tapn join inline
   ; rather than emit a jump straight to a return.
   (tojoin k n) (:
    j (k $ 3 + n)
    a <(c 'join)
    i (pick 0 a)
    (? (lvm_ret == i || lvm_tap == i) (p2 i (peek 1 a) j)
       (lvm_tapn == i)                (p2 i (peek 1 a) (poke -1 (peek 2 a) j))
                                      (p2 lvm_jump a j)))
   ; clauses: t/result pairs then a trailing else. a constant test folds to one branch; else emit
   ; lvm_cond -- true runs `then` + jumps to join, false falls to `rest`.
   (clauses b) (?
    (atom? b) (kim ())                                ; no else (feel usually supplies one)
    (atom? >b) (ana c <b * tojoin)            ; trailing else: result, then join
    (: test (ana c <b)
       then (ana c <>b)
       rest (clauses >>b)
       (? (kim = pro test) (? (peek 3 test) then rest)   ; constant test -> pick a branch
        (\ x (test (\ n
         (: k (push c 'alt * rest x)                  ; k = the false branch (the rest)
            j (then (tojoin k) $ 2 + n)                    ; true: then, jump to join, into k
            (p2 lvm_cond (pop c 'alt) j)))))))))

  ; recursive-fn ref: bake `quote code` if the closure is built, else `quote 0` + a backpatch site
  ; (lfd . box-of-cell) on the scope for wire to resolve. the cell rides a box (pin, barriered) --
  ; a raw poke into tenured data is the one write the precise barrier can't cover.
  (qsite site k n) (: cell (poke -1 0 * k $ 2 + n)
                      _ (pin >site 0 cell)
                    (place -1 lvm_quote cell))
  ; a closure cell is a box (tablet 0) holding (entry . imports): mkc makes, cof reads, cput
  ; stores. the letrec* capture fixpoint and the recursive-ref backpatch mutate through the box.
  (mkc v) {0 v}
  (cof e) (peep >e 0 0)
  (cput e v) (pin >e 0 v, v)
  (lz c lfd scope)(: code <(cof lfd)
                   p (? code (em2 lvm_quote code)
                        (: site (lfd . {})
                         (pin scope 'sites (site . scope 'sites),
                          qsite site)))
                   q (push c 'stk 0,
                      apl2r c >(cof lfd))
                 (pop c 'stk,
                  p * q))
  (ava c x) (avw c c x)
  (shadowed? c d x) (: far (d 'far)
   (tablet? far && 0 <= peep far x -1 && !(elem x (d 'par 'stk))))
  (avw c d x)
   (? !d ; outside all lexical scopes?
    (: y (gv x gone) (y == gone ? (em2 lvm_index x) (kim y)))   ; ==, not the pin: see gv
    (: lfd (assq x (d 'lam)) home (d == c)
     (? (two? lfd) (lz c lfd d)
        (!home && shadowed? c d x)
         (c 'par ? (push c 'imp x), em2 lvm_index x)
        (: s (d 'stk)
           (stki d2) (lidx x (d2 'imp + d2 'arg))
           (q i j m) (karg (i + stki c) j m)
         (?- (avw c (d 'par) x)
          (elem x s) (? home (karg (lidx x s))
                         (c 'par ? (push c 'imp x), q #(c 'stk)))
          (stki d >= 0) (? home (q #(c 'stk))
                         (c 'par ? (push c 'imp x), q #(c 'stk))))))))
  ; lambda analyzer
  (ala c imp exp nm hq) (:
   d (sco c (init exp) imp)
   ic (pin (tablet 0) 'l ())                       ; this lambda's inner-closure record, filled by the alas under it
   _ (pin d 'inl ic)
   k (ana d (last exp) (k0s d))
   a (ary d)
   e ((a = 1 ? k (em2 lvm_cur a k)) 0)           ; entry = cell 1 (cell 0 is the spare src slot)
   os (assq exp (rootc c 'src))
   s ('\ . (d 'imp + (? (two? os) >>os exp)))
   ; value[-1] = source \-expr, for a lambda the text spelled. one an expansion made has no
   ; surface entry and keeps none -- a third of an image. the hook still reads s either way
   hk (poke -1 (two? os ? s 0) e,
       trim (seek -1 e),                             ; tag head spans [src .. body]; value stays e
       gv 'natjit 0)
   r ((!hk ? e (hq ? (hk e s a gv (farq c) (c 'lam) nm iop apx (ic 'l)) e)) . d 'imp)
   ; the record -- (exp src-tail (entry . imports)), keyed by the node itself -- rides up to the
   ; nearest enclosing lambda's, this closure's entry ahead of its subtree's, so a hook finds an
   ; inner lambda site under its body by identity.
   up (lamsco c)
   _ (? (== up 0) 0
        (pin up 'l ((? (hq && nm == 0) ([exp (? (two? os) >>os 0) r] . ic 'l) (ic 'l)) + up 'l)))
   r)
  (lamsco c) (? !c 0 (: t (peep c 'inl 0) (? (== t 0) (lamsco (c 'par)) t)))
  (farq k x) (? !k 0
               (: f (k 'far)
                  (? (tablet? f && 0 <= peep f x -1) 1 (farq (k 'par) x))))

  (ale c a b rows) (?                          ; rows: feel's census, (name . imports) per lambda sibling
   (atom? b) (ana c a)
   (:- (wire <cb <>cb >>cb (closures <cb))
    q (sco c (c 'arg) (c 'imp))
    ; collect: gather (name . def) chains in source order -> (prs body . even). the body is the
    ; trailing odd form; even = a body-less let (last value is result, names defglob).
    (collect prs n d rest) (: nd (dsug n d)
     (? (atom? rest)       (rev (nd . prs) . <nd . 1)   ; body-less: the last name is the body
        (atom? >rest)      (rev (nd . prs) . <rest . 0)   ; a trailing body form
                           (collect (nd . prs) <rest <>rest >>rest)))
    cb (collect 0 a <b >b)
    ; far: {name -> arity} for the lambda siblings, syntactic (binder count off the \-expr). only
    ; fixed-arity multi-arg lambdas carry one; a value binding, single-arg lambda or rebound name
    ; pins 0 -> the call stays l2r. pinned before the closures analyze their bodies, so falook
    ; sees it.
    (farof ps t) (?- t (two? ps)
     (: pr <ps k <pr d >pr
        a (? (-1 = peep t k -1 && lambp d) (#>d - 1) 0)
      (farof >ps (pin t k (1 < a ? a 0)))))
    _ (pin q 'far (farof <cb {}))
    ; closures: a cell per lambda sibling, (0 . imports) off its census row -- feel's walk over the
    ; boxfixed defs, so no closure is built to learn its captures. weave builds each on its row.
    (closures prs) (foldl (a \ pr \ (lambp >pr ? ((<pr . mkc (0 . >(assoc <pr rows))) . a) a)) () prs)

   (wire prs body even lams) (:
    ; weave: emit the binding defs left-to-right. a lambda def is re-analyzed with its final import
    ; set (and backpatched in); a top-level body-less let's name is defglob'd.
    (weave nds) (? (atom? nds) id
     (: nd <nds n <nd d >nd
        d (?- d (lambp d) (: cls (assoc n lams)
                             x (ala q >(cof cls) >d n 1)
                             ; the import row is frozen here: every ref site that already
                             ; compiled applied (cup (cof cls)), so growth under-applies them.
                           (#>x != #>(cof cls) ? (scare 'imports-grew n),
                            cput cls x)))
        f (ana c d)
        g (?- id (even && !(c 'par) && !(== n '_)) (em2 lvm_defglob n))  ; `_` binds locally, never to the book
        h (push c 'stk n,
           weave >nds)
        (f * g * h)))
    s (pin q 'lam lams,
       c 'stk)
    g (push c 'stk 0,
       weave prs)
    ; closures final -> backpatch each recorded recursive-fn ref with its text.
    f (each (q 'sites) (s \ poke 0 <(cof <s) (peep >s 0 0)),
       pin q 'sites 0,
       pin c 'stk s,
       ; body-lambda analyzed after inits (it takes the bindings as args; never makes sites)
       ana c ('\ . revcat (map cap prs) [body]))
    h (kap (tally prs))
    (pin c 'stk s,
     f * g * h)))))
