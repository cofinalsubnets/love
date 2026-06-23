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
