; kanren -- first-order unification + a lazy-colist search monad. overlay below reads it, so
; it registers first. `unify s u v` is pure -- a substitution or `ufail` -- with no occurs
; check: a self-referential binding is a rational tree, and reify marks the back-edge. a goal
; is (\ st stream) over a state (substitution . constraints); est/=== unify, + interleaves,
; * binds.
(module '(kanren =/= === absent apt closed? con dif empty_dict est ifte inside mintp naf nay query rel
   residual rewrite s_app scount slist smap sno sole s_plus s_star st0 stake subst sun
   sX tie ufail ufail? unify untie var var? walk)
   ; the scan asks two?, never ?: a key that nets to nothing would end it early
(: (dict_has d k) (: (loop k ks vs) (two? ks ? (k = <ks ? vs (loop k >ks >vs))) (loop k <d >d))
   (dict_set d k v) ((k . <d) . v . >d)
   empty_dict '(())
   has_s dict_has
   ext_s dict_set
   (mintp x) (mint? x)
   (var x) (x . nom 0)                         ; (label . fresh-nom) -- identity by the nom
   ; a nom anywhere but a pair's tail is data. `?`, not &&: a predicate owes a bit
   (var? x) (two? x ? (nom? >x) 0)
   (walk s u) (!(var? u) ? u (has_s s u @ t (two? t ? (walk s <t) u)))
   ufail (nom 0)
   (ufail? x) (x = ufail)
   ; a binder: the abstraction is a love lambda, so instantiation is application
   (tie f) ('tie . f)
   (tie? t) (two? t ? (<t = 'tie) 0)
   (untie t a) (>t a)                            ; open the binder at a
   (unify s u v) (: x (walk s u) y (walk s v)       ; pure: a substitution, or ufail
     (? (x = y) s                                   ; alpha-equal binders land here, for free
        (var? x) (ext_s s x y)
        (var? y) (ext_s s y x)
        (tie? x && tie? y) (nom 0 @ a (unify s (untie x a) (untie y a)))   ; one fresh nom opens both
        (two? x && two? y) (unify s <x <y @ s1 (ufail? s1 ? ufail (unify s1 >x >y)))
        ufail))
   (subst s t) (? (var? t) (walk s t @ w (var? w ? w (subst s w)))   ; instantiate a template under s
                  (tie? t) (tie (a \ (subst s (untie t a))))             ; under a binder: at its opening
                  (two? t) (subst s <t . subst s >t)
                  t)
   (rewrite pat tpl x) (unify '(()) pat x @ r (ufail? r ? x (subst r tpl)))   ; pattern -> template, or x unchanged

   ; --- the constraint store, beside the substitution: a constraint is (kind . payload),
   ; re-checked against the store after every successful unification
   st0 (empty_dict . ())
   (unify_all s p) (two? p ? (unify s <<p ><p @ r (ufail? r ? ufail (unify_all r >p))) s)
   ; the bindings r has and s does not, as a (u . v) list -- ext_s prepends, so they lead
   (residual r s) (: (go k ks vs acc) (k ? (go (k - 1) >ks >vs ((<ks . <vs) . acc)) acc)
                     (go (#<r - #<s) <r >r ()))
   ; does x occur in the (walked) term t? a tie opens at a fresh nom, never an outer atom
   (inside s x t) (? (x = t) 1
                     (var? t) 0
                     (tie? t) (inside s x (walk s (untie t (nom 0))))
                     (two? t) (inside s x (walk s <t) ? 1 (inside s x (walk s >t)))
                     0)
   (closed? s t) (? (var? t) 0
                    (tie? t) (closed? s (walk s (untie t (nom 0))))
                    (two? t) (closed? s (walk s <t) ? (closed? s (walk s >t)) 0)
                    1)
   ; one constraint against s -> 'drop (satisfied for good), ufail (violated), or itself
   (vet1 s c)
    (<c @ 'dif (: r (unify_all s >c)                    ; unify the prefix on a copy and read it three ways
                (ufail? r ? 'drop                   ;   can never hold -> nothing left to watch
                 (: q (residual r s)                ;   holds with no new binding -> violated
                  (two? q ? ('dif . q) ufail))))
          'abs (: x (walk s <>c) t (walk s >>c)         ; absento, and nominal freshness by the same door
                (? (inside s x t) ufail
                   (closed? s t) 'drop
                   ('abs . x . t)))
          'apt (: w (walk s >>c)                        ; a type constraint over any predicate
                (? (var? w) ('apt . <>c . w)
                   (<>c w) 'drop
                   ufail))
          c)
   (vet s)
    (: (go (a . u)) (vet1 s a @ ^ufail ufail r (go u @ t (t == ufail || r == 'drop ? t (r . t)))) go)
   (con st c) (vet <st c @ d (ufail? d ? ufail (<st . d)))   ; a state with c added, or ufail

   ; --- streams: () empty, (x . s) mature, a thunk immature, told apart by lit?/two?
   sno ()
   (sX x s) (x . s)
   (sun x) [x]
   (s_plus s t) (s @ (f && lit? f) (s_plus t * f)       ; interleave (disj): the swap is the fairness
                     (x . r)       (x . s_plus r t)
                     t)
   (s_star s g) (s @ (f && lit? f) (v \ s_star (f v) g)       ; bind (conj)
                     (x . r)       (s_plus (g x) (s_star r g)))
   (s_app s t)  (s @ (f && lit? f) (v \ s_app (f v) t)        ; ordered disj: no swap, the left runs
                     (x . r)       (x . s_app r t)              ; dry first -- incomplete on purpose
                     t)
   (sfire s) (lit? s ? (sfire (s ())) s)                ; force to a mature shape: () or a cons
   (stake i s) (i @ 0 () (sfire s @ (a . u) (a . stake (i - 1) u)))
   (smap f s) (s @ (g && lit? g) (v \ smap f (g v)) (x . r) (f x . smap f r) ())
   (sfold f z s) (sfire s @ m (two? m ? (f <m (sfold f z >m)) z))
   slist (sfold (.) ())
   (scount s) (: (go a s) (sfire s @ m (two? m ? (go (a + 1) >m) a)) (go 0 s))

   ; --- goals. &&& ||| and the coin's * + are conj2/disj2; `load` takes a bare or rel-wrapped goal
   (conj2 a b) (: g (load a) h (load b) (st \ (s_star (g st) h)))
   (disj2 a b) (: g (load a) h (load b) (st \ (s_plus (g st) (h st))))
   yea sun                               ; the goal that holds, once
   nay ()                                ; the goal that never does
   (est u v st) (unify <st u v @ r
                   (ufail? r ? ()
                    (vet r >st @ c (ufail? c ? () (sun (r . c))))))
   ; unify on a copy: ufail -> holds for good; no new binding -> fails; else the residual
   ; bindings are the constraint
   (dif u v st) (unify <st u v @ r
                   (ufail? r ? (sun st)
                      (residual r <st @ p
                         (two? p ? (con st (('dif . p) . >st) @ t (ufail? t ? () (sun t)))))))
   ; absento: x occurs nowhere in t, now or ever; for a nom x, alphaKanren's a # t
   (absent x t st) (con st (('abs . x . t) . >st) @ r (ufail? r ? () (sun r)))
   ; a type constraint over any predicate -- symbolo/numbero and their kin in one goal
   (apt p x st) (con st (('apt . p . x) . >st) @ r (ufail? r ? () (sun r)))
   ; --- extra-logical. `ifte` is the soft cut: if c holds at all, t runs over its answers and
   ; e is dropped. `sole` commits to the first answer. `naf` is negation as failure: "not
   ; proved", which is "false" only for a ground terminating goal.
   (ifte c t e st) (sfire (c st) @ m (two? m ? (s_star m t) (e st)))
   (sole g st) (sfire (g st) @ m (two? m ? (sun <m)))
   (naf g st) (ifte g nay yea st)

   ; --- query: run a goal, reify the answers
   (query n ks g) (:
    (walk_star s u path) (?                          ; cycle-safe: (mu label) on a back-edge
     (var? u) (has_s s u @ t
                 (? (atom? t) u
                    (elem u path) ['mu <u]
                    (walk_star s <t (u . path))))
     (tie? u) (nom 0 @ a ['tie a (walk_star s (untie u a) path)])
     (two? u) (walk_star s <u path . walk_star s >u  path)
     u)
    ; an answer's mints are renamed a1 a2 .. in first-sight order, so answers compare
    (noms t acc) (? (var? t) acc
                    (mint? t) (elem t acc ? acc (t . acc))
                    (two? t) (noms >t (noms <t acc))
                    acc)
    (renom d t) (? (var? t) t
                   (mint? t) (dict_has d t @ v (two? v ? <v t))
                   (two? t) (renom d <t . renom d >t)
                   t)
    (dename t) (rev (noms t ()) @ ns
                  (two? ns ?
                     (renom (foldl (d \ p \ dict_set d <p <>p) empty_dict
                                   (zip ns (map (i \ nom $ "a" + show (i + 1)) ^#ns)))
                            t)
                     t))
    (keyvar keys k) (atom? keys ? 0 (<keys @ kv (k = <kv ? kv (keyvar >keys k))))
    (reify1 st) (dename (flip catmap ks (k \ (keyvar <<st k @ kv (two? kv ? [k (walk_star <st kv ())])))))
    (map reify1 ((n ? (stake n) slist) (g st0))))
   rel (coin 'goal (z \ {'+ (\ A B (z (disj2 A B)))   ; the goal coin: + = disj = |||, * = conj = &&&
                         '* (\ A B (z (conj2 A B)))})))
(: (=== u v) (rel (est u v))                        ; all-punct, so infix at house band; a chain
   (=/= u v) (rel (dif u v)))                       ; of the two wants parens
; the goal macros live in kanren's own macro table, so (borrow 'kanren) carries them.
; &&& and ||| are && and ||, \\\ is \ with its params fresh logic vars.
(:: 'zz (x \ (: s (nom 0) u (nom 0) x2 <x ['\ s u [x2 s]])))   ; delay a goal: the curried tail is the thunk
(:: '&&& (xs \ (foldl (\ a b [conj2 a b]) <xs >xs)))   ; conj of goals -- the ring's *
(:: '||| (xs \ (foldl (\ a b [disj2 a b]) <xs >xs)))   ; disj of goals -- the ring's +
(:: '\\\ (a \ (('\ . a) . map (a \ [var ['\ a]]) (init a))))                         ; lambda w/ fresh logic vars

) ; module kanren

; overlay -- an optional, observe-only static-type check of a form against a kind domain
(module '(overlay ov-check)
(borrow 'kanren)                                         ; subst unify ufail ufail? var, scoped to this compile
(: ov-check
    (: (ov-sigof sigs nm) (sigs @ (((aa . ua) @ a) . u) (nm @ ^aa a (ov-sigof u nm)))
       (ov-look env x) (env @ ((ap . up) . env') (x @ ^ap up (ov-look env' x)) 'bot)
       (ov2-var? dom d) (nom? d && nelem d (dom 'dice) && nelem d (dom 'ctors))   ; a sig variable: not concrete, not a constructor
       (ov2-vars dom d acc) (atom? d ?
        (ov2-var? dom d && (nelem d acc) ? (d . acc) acc)
        (foldl (flip $ ov2-vars dom) acc d))
       (ov2-lk vm d) (? (atom? vm) d
                        (d = <<vm) ><vm
                        (ov2-lk >vm d))   ; ><vm is glued: cuap, not the cons
       (ov2-term vm d)    (atom? d ? (ov2-lk vm d) (map (ov2-term vm) d))
       (ov2-uall ps as s) (? (atom? ps || atom? as) s
                             (elem <as '(top bot)) (ov2-uall >ps >as s)   ; an unknown arg is gradual: consistent with any param, binds nothing
                             (unify s <ps <as @ s1 (ufail? s1 ? ufail (ov2-uall >ps >as s1))))
       (ov2-inst dom sg args)                                          ; sg = (name (param-dies) result): structured caller instantiation
        (: params <>sg result <>>sg
           vm (map (nm \ nm . var nm) (ov2-vars dom (params . result) ()))            ; one fresh logic var per sig variable
           s  (ov2-uall (map (ov2-term vm) params) args '(()))   ; a caller's rigid symbol is a constant here
           (? (ufail? s) 'clash                                        ; args contradict the params: the one hard verdict
              (#args != #params) 'top                        ; partial/over-application: a closure/re-application, die unknown
              (: r (subst s (ov2-term vm result)) nf (dom 'norm) (lit? nf ? (nf r) r))))   ; reify + normalize (dependent index)
       (ov-kindof dom sigs env e)
          (? (nom? e) (ov-look env e)
             (atom? e) (dom 'litdie e)
             (: h <e as (map (ov-kindof dom sigs env) >e)
                (? (elem h '(+ *)) (dom 'tr h <as <>as)
                   (h = '? && #e = 4) (dom 'join <>as <>>as)
                   (ov-sigof sigs h @ sg (atom? sg ? 'top (ov2-inst dom sg as))))))
       (ov-zip (ap . up)  (ad . ud))     ((ap . ad) . ov-zip up ud)
       (ov-clash dom sigs env e) (two? e ? (: d (ov-kindof dom sigs env e) sub (catmap (ov-clash dom sigs env) >e)
                                            (d @- sub 'clash ((e . map (ov-kindof dom sigs env) >e) . sub))))   ; a clash site = (expr . operand-dies)
                                                    ; the ternary is parenthesized: bare in a `:`
                                                    ; element list it does not factor at all
       (ov-pairs (a . b . c)) ((a . b) . ov-pairs c)
       (ov2-okr dom bd decl) (dom 'okr @ f (lit? f ? (f bd decl) (dom 'join bd decl = decl)))   ; result acceptable? domain `okr` (dependent = up to conv/norm), else structural join
       (ov-check1 dom sigs prog)
          (catmap (p @ ((nm . ps) . body) \                          ; parenthesize the `:`: it is
                     (: sg (ov-sigof sigs nm)                       ; looser than `?`, so unwrapped it
                        (two? sg ?                                  ; eats `two? sg` as a second pair
                         (: env (ov-zip ps <>sg) cl (ov-clash dom sigs env body)
                            bd (ov-kindof dom sigs env body) decl <>>sg
                          (two? cl || !(ov2-okr dom bd decl) ? [(nm . (atom? cl ? ['result bd decl] cl))])))))
                  (filter (two? * cap) (ov-pairs >prog)))
     ov-check1))                                   ; (ov-check dom sigs form) -> () clean | ((name . detail)..), the report as data
) ; module overlay
