; phase-3 prototype: bounded UNFOLDING of recursion on static data, as the natural extension of
; cprop. the key insight: unfolding recursion on a COMPUTED static arg (like (- n 1)) only
; terminates if folding is interleaved -- so the signature actually shrinks 3->2->1->0. so this
; is the proto mix evaluator, but (a) on source forms (propk?/kval, not pe-value tags), (b) pulling
; functions from a LOCAL function env `fe` (a `:`-bound lambda, whose source cprop already has),
; (c) with the in-progress signature guard + fuel for termination.
;
;   se : (name const-form)   constant bindings   |   fe : (name lambda-form)   local functions
;   seen : list of (name . static-sig) in progress (the guard)   |   fuel : a tablet, the apcap bound

(:
 (nul? l) (! (two? l))
 (inset? k s) (? (nul? s) 0 (? (k = (cap s)) 1 (inset? k (cup s))))
 (assq k al) (? (nul? al) 0 (? (id? k (caap al)) (cap al) (assq k (cup al))))
 (rmq k al)  (? (nul? al) () (? (id? k (caap al)) (rmq k (cup al)) (link (cap al) (rmq k (cup al)))))
 (allk args) (? (nul? args) 1 (? (propk? (cap args)) (allk (cup args)) 0))

 (propk? v) (? (nom? v) 0 (atom? v) 1 (&& (id? (cap v) '\) (atom? (cuup v))) 1 0)   ; a constant FORM
 (lamb? v)  (&& (two? v) (id? (cap v) '\) (! (atom? (cuup v))))                      ; a (\ p.. body)
 (kval v)   (? (atom? v) v (caup v))                                                 ; value of a const form
 (bake v)   (? (charm? v) v (L '\ v))                                                ; value -> source

 ; the pure primitives we may FOLD at pe time (compute via ev on the known values)
 pure-ops (L '- '+ '* '// '% '= '< '<= '> '>= '! 'nil?)
 (foldc h args) (bake (ev (link h (map kval args))))

 ; lambda parts: params = all-but-last of (cup x), body = last
 (lpar x) (? (nul? (cup (cup x))) () (link (caup x) (lpar (cup x))))
 (lbod x) (? (nul? (cup (cup x))) (caup x) (lbod (cup x)))
 (sig args) (map (\ a (? (propk? a) (kval a) '_)) args)           ; static slots carry values, dyn -> _
 (zipb ps args) (? (nul? ps) () (link (cap ps) (link (cap args) (zipb (cup ps) (cup args)))))

 ; fuel: a one-shot bound so a huge static unfold can't hang the compiler
 fuel (tablet 0)
 (okfuel u) (: n (peep fuel 'n 0) (? (! n) 0 (: _ (pin fuel 'n (- n 1)) 1)))

 ; --- the evaluator ---
 (pe x se fe seen) (?
   (atom? x) (? (nom? x) (: e (assq x se) (? e (caup e) x)) x)        ; const-bound var -> value
   (: h (cap x) (?
     (id? h '\) (pelam x se fe seen)
     (id? h ':) (link ': (pebinds (cup x) se fe seen))
     (id? h '?) (pecond (cup x) se fe seen)
     (: args (map (\ e (pe e se fe seen)) (cup x))
        (? (&& (nom? h) (inset? h pure-ops) (allk args)) (foldc h args)   ; FOLD a pure constant call
           (: d (? (nom? h) (assq h fe) 0)
              (? d (pecall h (caup d) args se fe seen)                    ; UNFOLD a local function call
                   (link h args))))))))                                  ; otherwise: residualize the call

 ; cond: a folded-constant test keeps one branch (prune); else keep the cond with pe'd branches
 (pecond cs se fe seen) (: t (pe (cap cs) se fe seen)
   (? (propk? t) (? (! (kval t)) (pe (caup (cup cs)) se fe seen) (pe (caup cs) se fe seen))   ; static test
      (link '? (link t (map (\ e (pe e se fe seen)) (cup cs))))))

 ; unfold (f a..): rewrite to a let of the body, then pe it -- the let binds dynamic args once (no
 ; duplication), static args propagate. guard on the static signature; bottom out on fuel.
 (pecall f lam args se fe seen) (: key (link f (sig args))
   (? (inset? key seen) (link f args)                                ; same static instance in progress -> call
      (! (okfuel 0))    (link f args)                                ; fuel spent -> residual call
      (pe (link ': (cat (zipb (lpar lam) args) (L (lbod lam)))) se fe (link key seen))))

 (pelam x se fe seen) (? (nul? (cup (cup x))) x
   (: ps (lpar x) (link '\ (cat ps (L (pe (lbod x) (rmqs ps se) (rmqs ps fe) seen))))))
 (rmqs ps al) (? (nul? ps) al (rmqs (cup ps) (rmq (cap ps) al)))

 (pebinds bs se fe seen) (?
   (nul? (cup bs)) (L (pe (cap bs) se fe seen))
   (: nm (cap bs) v1 (pe (caup bs) se fe seen)
      se2 (? (propk? v1) (link (L nm v1) (rmq nm se)) (rmq nm se))
      fe2 (? (lamb? v1) (link (L nm v1) (rmq nm fe)) (rmq nm fe))
      (link nm (link v1 (pebinds (cuup bs) se2 fe2 seen)))))

 (unfold x fuel0) (: _ (pin fuel 'n fuel0) (pe x () () ()))

 ; ============================ checks ============================
 ; a LOCALLY-defined recursive pow, specialized to a static exponent, unrolls to straight-line code:
 powsrc '(: pow (\ n b (? (! n) 1 (* b (pow (- n 1) b)))) (pow 3 inp))
 _ (. "pow 3 (b dyn):   ") _ (. (show (unfold powsrc 1000))) _ (. "\n")
 _ (assert (15 = (: inp 5 (ev (unfold powsrc 1000)))) "unrolled pow(3) at inp=5 == 15")

 ; a function whose recursion is driven by a DYNAMIC value must NOT loop -- the guard residualizes:
 dnsrc '(: dn (\ b (? (! b) 0 (dn (- b 1)))) (dn inp))
 _ (. "dn (b dyn):      ") _ (. (show (unfold dnsrc 1000))) _ (. "\n")

 ; fuel bounds a huge static unfold (returns a residual call instead of hanging):
 _ (. "pow 1000 fuel 5: ") _ (. (show (unfold '(: pow (\ n b (? (! n) 1 (* b (pow (- n 1) b)))) (pow 1000 inp)) 5))) _ (. "\n")
 (. ";; phase-3 prototype: unfolding self-checks pass\n"))
