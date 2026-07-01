; post -- the POST-EGG layer: user-level defs that drip into the image AFTER the egg hatches, once.
; The egg (ai/egg.l) bakes prel+ev and the evaluator sits on it TWICE (c0 then self-hosted), so
; anything in prel is compiled+run twice and bloats the baked heap image. prel earns that: it IS the
; language. But user-level libraries do not -- they pay the double-bootstrap for no benefit. So they
; live HERE: host/main.c evals post.l once, right after warming the egg and just before bao (the shell
; core), so every frontend and every -l'd app sees these globals without re-deriving them. DEFINE-ONLY
; (no self-test / no print -- it runs on every boot); exercised by the apps that use it (cook, sat).
;
; First tenant: gw.js-style PARSER COMBINATORS. A parser is (\ s y n) over a string s, with a SUCCESS
; continuation y = (\ rest payload) and a FAILURE continuation n = (\ rest); payloads are lists that
; `seq` concatenates. The leaves are `lit` (a literal prefix), `one` (one char by predicate) and `span`
; (a maximal run) -- ai has no regex. cook/cook.l grew this set (kept private to dodge the old "leak
; collides with egg globals" worry -- now only `sat`/$ actually collide, and none of these do); it and
; sat/dimacs.l now share THIS copy. `parse` requires the whole input consumed; `runp` is the lenient
; twin (keeps the payload, ignores trailing slack).
(: eps (\ s y n (y s 0))
   (lit l) (\ s y n
      (? (&& (<= (tally l) (tally s)) (= l (snip s 0 (tally l))))
         (y (snip s (tally l) (tally s)) `(l)) (n s)))
   (one p) (\ s y n
      (? (&& (< 0 (tally s)) (p (s 0)))
         (y (snip s 1 (tally s)) `((s 0))) (n s)))
   (span p) (\ s y n
      (: i ((: (g j) (? (&& (< j (tally s)) (p (s j))) (g (+ 1 j)) j)) 0)
         (y (snip s i (tally s)) `((snip s 0 i)))))
   (alt a b) (\ s y n (a s y (\ _ (b s y n))))
   (seq a b) (\ s y n (a s (\ s1 p1 (b s1 (\ s2 p2 (y s2 (cat p1 p2))) n)) n))
   (seqs l)  (foldr seq eps l)
   (opt a)   (\ s y n (a s y (\ _ (y s 0))))
   (skip a)  (\ s y n (a s (\ s1 _ (y s1 0)) n))
   (pmap f a) (\ s y n (a s (\ s1 x (y s1 (f x))) n))
   (many a)  (\ s y n
      (a s (\ s1 p1 (many a s1 (\ s2 p2 (y s2 (cat p1 p2))) (\ _ (y s1 p1))))
           (\ _ (y s 0))))
   (parse p s) (p s (\ r x (? (= 0 (tally r)) x ())) (\ _ ()))     ; STRICT: whole input must parse
   (runp p s)  (p s (\ r x x) (\ _ ())))                           ; LENIENT: keep the payload, ignore trailing slack

; --- OVERLAY: an OPTIONAL, observe-only static-type overlay hooked at the ev seam (spike:
;     doc/proto/overlay.l; design: memory pluggable-types). Install a user DOMAIN + SIG-TABLE with
;     (overlay-set DOM SIGS); `ev` then REPORTS a type clash for each top-level `:` def and runs the form
;     UNCHANGED (observe-only -- never alters eval). (overlay-off ()) uninstalls; uninstalled, `ev` is
;     transparent (one peep per top-level form). ERASABLE by construction. Engine internals stay private
;     inside `ov-eng`; only ov-*/overlay-*/the ev rebind leak. See overlay.l for the domain shape (a map
;     #('join J 'tr T 'litdie L 'dice D)) and sigs ((name (param-dies..) result-die)..).
(: ov-eng
    (: (ov-nthl l n)     (? (= n 0) (cap l) (ov-nthl (cup l) (- n 1)))   ; nth (nthl is glaze-layer, absent in post.l)
       (ov-sigof sigs nm) (? (atom? sigs) () (id? nm (caap sigs)) (cap sigs) (ov-sigof (cup sigs) nm))
       (ov-look env x)    (? (atom? env) 'bot (: p (cap env) (? (id? x (cap p)) (cup p) (ov-look (cup env) x))))
       (ov2-var? dom d)   (&& (nom? d) (! (member? d (dom 'dice))) (! (member? d (dom 'ctors))))   ; a sig variable: not concrete, not a constructor
       (ov2-vars dom d acc) (? (atom? d) (? (&& (ov2-var? dom d) (! (member? d acc))) (link d acc) acc) (foldl (\ a s (ov2-vars dom s a)) acc d))
       (ov2-lk vm d)      (? (atom? vm) d (id? d (cap (cap vm))) (cup (cap vm)) (ov2-lk (cup vm) d))
       (ov2-term vm d)    (? (atom? d) (ov2-lk vm d) (map (\ s (ov2-term vm s)) d))
       (ov2-uall ps as s) (? (atom? ps) s (: s1 (unify s (cap ps) (cap as)) (? (ufail? s1) ufail (ov2-uall (cup ps) (cup as) s1))))
       (ov2-inst dom sg args)                                          ; sg = (name (param-dies) result): structured caller instantiation
        (: params (caup sg) result (ov-nthl sg 2)
           vm (map (\ nm (link nm (var nm))) (ov2-vars dom (link params result) ()))            ; one fresh logic var per sig variable
           s  (ov2-uall (map (\ p (ov2-term vm p)) params) args '(()))   ; unify param patterns (fresh vars) vs arg dies AS-IS (a caller's rigid symbol is a constant here -- no capture)
           (? (ufail? s) 'clash (: r (subst s (ov2-term vm result)) nf (dom 'norm) (? (lit? nf) (nf r) r))))   ; reify + normalize (dependent index)
       (ov-kindof dom sigs env e)
          (? (nom? e) (ov-look env e)
             (atom? e) ((dom 'litdie) e)
             (: h (cap e) as (map (\ s (ov-kindof dom sigs env s)) (cup e))
                (? (member? h '(+ *)) ((dom 'tr) h (cap as) (cap (cup as)))
                   (&& (id? h '?) (= 4 (tally e))) ((dom 'join) (cap (cup as)) (cap (cup (cup as))))
                   (: sg (ov-sigof sigs h) (? (two? sg) (ov2-inst dom sg as) 'top)))))
       (ov-zip ps ds)     (? (atom? ps) 0 (link (link (cap ps) (cap ds)) (ov-zip (cup ps) (cup ds))))
       (ov-clash dom sigs env e) (? (atom? e) 0 (: d (ov-kindof dom sigs env e) sub (catmap (\ s (ov-clash dom sigs env s)) (cup e)) (? (id? d 'clash) (link e sub) sub)))
       (ov-pairs bs)      (? (atom? bs) 0 (atom? (cup bs)) 0 (link (link (cap bs) (cap (cup bs))) (ov-pairs (cup (cup bs)))))
       (ov-check1 dom sigs prog)
          (catmap (\ p (: nm (caap p) ps (cuap p) body (cup p) sg (ov-sigof sigs nm)
                         (? (! (two? sg)) 0
                            (: env (ov-zip ps (caup sg)) cl (ov-clash dom sigs env body)
                               bd (ov-kindof dom sigs env body) decl (ov-nthl sg 2)
                               (? (&& (atom? cl) (= ((dom 'join) bd decl) decl)) 0 (L (link nm (? (atom? cl) (L 'result bd decl) cl))))))))   ; = : structural (structured dies)
                  (filter (\ p (! (atom? (cap p)))) (ov-pairs (cup prog))))
       (ov-run dom sigs form) (? (&& (two? form) (id? (cap form) ':))
                                 (: r (ov-check1 dom sigs form) (? (two? r) (: _ (puts ";; overlay: type clash in ") _ (puts (show (map cap r))) (putc 10)) 0))
                                 0)
     ov-run)                                       ; ov-eng IS the run entry (internals private)
   ov-slot     (tablet 0)                          ; install slot: peep 0 -> (DOM SIGS) or ()
   overlay-set (\ dom sigs (pin ov-slot 0 (L dom sigs)))
   overlay-off (\ _ (pin ov-slot 0 ()))
   ov-ev0      ev                                  ; the baked (glaze) ev, captured before the rebind
   ev (\ e (: v (peep ov-slot 0 ()) (? (two? v) (: _ (ov-eng (cap v) (caup v) e) (ov-ev0 e)) (ov-ev0 e)))))
