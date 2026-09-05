; overlay -- an optional, observe-only static-type overlay hooked at the ev seam
(module '(overlay ov-check ov-eng overlay-off overlay-set ov-hook ov-slot)
(use 'kanren)                                         ; subst unify ufail ufail? var, scoped to this compile
(: ov-both
    (: (ov-sigof sigs nm) (sigs @ (((aa . ua) @ a) . u) (nm @ ^aa a (ov-sigof u nm)))
       (ov-look env x) (env @ ((ap . up) . env') (x @ ^ap up (ov-look env' x)) 'bot)
       (ov2-var? dom d) (nom? d && !(member? d (dom 'dice)) && !(member? d (dom 'ctors)))   ; a sig variable: not concrete, not a constructor
       (ov2-vars dom d acc) (one? d ?
        (ov2-var? dom d && !(member? d acc) ? (d . acc) acc)
        (foldl (flip $ ov2-vars dom) acc d))
       (ov2-lk vm d) (? (one? vm) d
                        (d = <<vm) ><vm
                        (ov2-lk >vm d))   ; ><vm is glued: cuap, not the cons
       (ov2-term vm d)    (one? d ? (ov2-lk vm d) (map (ov2-term vm) d))
       (ov2-uall ps as s) (? (one? ps || one? as) s
                             (member? <as '(top bot)) (ov2-uall >ps >as s)   ; an unknown arg is gradual: consistent with any param, binds nothing
                             (: s1 (unify s <ps <as) (ufail? s1 ? ufail (ov2-uall >ps >as s1))))
       (ov2-inst dom sg args)                                          ; sg = (name (param-dies) result): structured caller instantiation
        (: params <>sg result <>>sg
           vm (map (nm \ nm . var nm) (ov2-vars dom (params . result) ()))            ; one fresh logic var per sig variable
           s  (ov2-uall (map (ov2-term vm) params) args '(()))   ; unify param patterns (fresh vars) vs arg dies as-is (a caller's rigid symbol is a constant here -- no capture)
           (? (ufail? s) 'clash                                        ; args contradict the params: the one hard verdict
              (#args != #params) 'top                        ; partial/over-application: a closure/re-application, die unknown
              (: r (subst s (ov2-term vm result)) nf (dom 'norm) (lit? nf ? (nf r) r))))   ; reify + normalize (dependent index)
       (ov-kindof dom sigs env e)
          (? (nom? e) (ov-look env e)
             (one? e) (dom 'litdie e)
             (: h <e as (map (ov-kindof dom sigs env) >e)
                (? (member? h '(+ *)) (dom 'tr h <as <>as)
                   (h = '? && #e = 4) (dom 'join <>as <>>as)
                   (: sg (ov-sigof sigs h) (one? sg ? 'top (ov2-inst dom sg as))))))
       (ov-zip (ap . up)  (ad . ud))     ((ap . ad) . ov-zip up ud)
       (ov-clash dom sigs env e) (two? e ? (: d (ov-kindof dom sigs env e) sub (catmap (ov-clash dom sigs env) >e)
                                            (d @- sub 'clash ((e . map (ov-kindof dom sigs env) >e) . sub))))   ; a clash site = (expr . operand-dies)
                                                    ; the ternary is parenthesized: bare in a `:`
                                                    ; element list it does not factor at all
       (ov-pairs (a . b . c)) ((a . b) . ov-pairs c)
       (ov2-okr dom bd decl) (: f (dom 'okr) (lit? f ? (f bd decl) (dom 'join bd decl = decl)))   ; result acceptable? domain `okr` (dependent = up to conv/norm), else structural join
       (ov-check1 dom sigs prog)
          (catmap (p @ ((nm . ps) . body) \                          ; parenthesize the `:`: it is
                     (: sg (ov-sigof sigs nm)                       ; looser than `?`, so unwrapped it
                        (two? sg ?                                  ; eats `two? sg` as a second pair
                         (: env (ov-zip ps <>sg) cl (ov-clash dom sigs env body)
                            bd (ov-kindof dom sigs env body) decl <>>sg
                          (two? cl || !(ov2-okr dom bd decl) ? [(nm . (one? cl ? ['result bd decl] cl))])))))
                  (filter (two? * cap) (ov-pairs >prog)))
       (ov-djoin dies) (? (one? dies) "?" (one? >dies) (show <dies) (show <dies + " vs " + ov-djoin >dies))
       (ov-report nm detail) (detail @ ; detail = (result BD DECL) | ((expr . opdies) ..)
        ['result bd decl]
         (puts $ ";; overlay: " + string nm + " -- returns " + show bd + ", declared " + show decl + "\n")
        ((expr . opdies) . _)
         (puts $ ";; overlay: " + string nm + " -- clash in " + show expr + "  (" + ov-djoin opdies + ")\n"))
       (ov-reps ((aa . ua) . u)) (ov-report aa ua, ov-reps u)
       (ov-run dom sigs form)
        (form @ (': . _) (ov-check1 dom sigs form @ (r @ (_ . _)) (ov-reps r)))
     [ov-run ov-check1])                           ; the run entry + the pure checker (internals private)
   ov-eng      <ov-both
   ov-check    <>ov-both                           ; (ov-check dom sigs form) -> () clean | ((name . detail)..) -- the report as data (a gate's leg)
   ov-slot     {}                          ; install slot: peep 0 -> (DOM SIGS) or ()
   (overlay-set dom sigs) (pin ov-slot 0 [dom sigs])
   (overlay-off _) (pin ov-slot 0 ())

   (ov-hook e0 e)
     (: v (ov-slot 0) (two? v ? (ov-eng <v <>v e, e0 e) (e0 e))))
) ; module overlay
