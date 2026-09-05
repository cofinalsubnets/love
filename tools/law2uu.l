; tools/law2uu.l -- emit test/uuvallaw.l: claude.md's laws, one spelling for both
; lanes. test/law.l quantifies each law as a lambda over a corpus (refutation);
; this tool reads those rows as data and compiles the ones the measure tower can
; state into uu obligations over test/uuval.l's model (proof). Run on the host:
;
;   love tools/law2uu.l > test/uuvallaw.l        (or: make uuvallaw)
;
; so a law is written once. edit its spelling in law.l and the obligation moves
; with it -- `make test_uuvallaw` regenerates and diffs, and the proof is re-found.
;
; the lift is kind-directed by the tower itself: every expression has a level in
;   bool -- nat -- zed -- rea -- msr -- val
; and a word fixes the level of its argument (net wants a val, re wants a msr)
; and of its answer. an argument at the wrong level is coerced along the sections
; going up (nbit nzed zrea rmsr vnum, or one of the named val shortcuts nval zval
; rval bval) and the retractions going down -- so (net (net x)), whose inner net
; answers a measure where the outer wants a value, lifts to (vnet (vnum (vnet v)))
; and needs no rule of its own. that is the whole type oracle: src/apps/lux/sigs.l does
; this job for wm2uu, and here the tower is its own.
;
; the proof is searched, not transcribed. three strategies, tried in order
; against the live kernel (the tool loads test/uu.l + test/uuval.l and runs defq):
;   1. by conversion -- (lam v (idpath LHS)). the tower's round trips are
;      definitional, so most rungs land here.
;   2. by cases on the saturated measure -- nat_rect on (vsat v), both arms
;      idpath. the same translation run at v := (nval 0) and v := (nval (succ k))
;      gives the two arms and at v := (nval n) the motive; (vsat (nval n)) is n,
;      so the motive at (vsat v) converts back to the obligation.
;   3. by the lemma the model names -- `uv-<row>` in test/uuval.l, cited bare. the
;      structural laws (cap/cup/link, veq's reflexivity) need an induction over
;      the tree and are hand-proved there; the obligation still comes from law.l,
;      so a row that moves leaves its lemma behind and the tool says so.
; a row no strategy discharges is skipped and counted, never silently dropped.
;
; a guard the tower cannot read erases -- (? (coin? x) 1 e) -- the way core.l's
; ()-lane erases under wm2uu, and the obligation it makes is then stronger than
; the row, not weaker; each such row names the guard it dropped. a guard the
; tower can read (two?) stays, as the orb it always was. a `:` binds into the
; environment, which is substitution at the term level. `?` and `=` are no name
; characters downstream (uu2coq emits Coq), so they spell q and eq in an emitted
; name, the way kinds2uu writes numq for num?.
;
; love's `=` between two values is veq, not paths: the depth index is a height
; bound, so one value has many spellings and identity is finer than love's own
; equality. below val the carriers are canonical and the claim stays a path.
;
; untrusted like every translator here: a wrong lift can miss a law, never fake
; one, and each row prints its source form over its term.
;
; load the kernel and the model first, in their own form -- the next form's bare
; references resolve at its compile, which must follow this run. their asserts
; ride a jug meanwhile so the artifact stays clean.
(: j (jug 0) _ (wear [in j err])
   _ (reads (open "test/uu.l" "r"))
   _ (reads (open "test/uuval.l" "r"))
   _ (wear ()) ())

(:
   nl (string 10)
   (join l) (foldl (+) "" l)
   (pl s) (puts (s + nl))
   (idxin x l k) (? (! (two? l)) -1 (<l = x) k (idxin x >l (k + 1)))
   (look k tbl) (? (! (two? tbl)) () (= <<tbl k) <tbl (look k >tbl))
   (zero? e) (charm? e && e = 0)
   (one? e) (charm? e && e = 1)
   (same? a b) ((show a) = (show b))
   ; an operator head is matched by its spelling: the lambda sigil has no quote
   ; form to compare against, and neither `?` nor `:` reads back as a bare nom.
   (is? x s) (nom? x && (string x) = s)
   (hd? e s) (two? e && is? <e s)
   bs (intern "\\")
   (unq x) (? (two? x && (= <x bs)) (x 1) x)     ; reads shows a quote as (\ ..)

   ; --- the tower, as a type oracle: the levels, and the rung between each pair ---
   lv-order '(bool nat zed rea msr val)
   (ht l) (idxin l lv-order 0)
   up-rungs '((bool nbit nat) (nat nzed zed) (zed zrea rea) (rea rmsr msr) (msr vnum val))
   dn-rungs '((val vnet msr) (msr mre rea) (rea rceil zed) (zed zsat nat) (nat natbit bool))
   to-val   '((msr vnum) (rea rval) (zed zval) (nat nval) (bool bval))
   (co t f g)
    (? (= f g) t
       (= g 'val) [((look f to-val) 1) t]
       ((ht f) < (ht g)) (: r (look f up-rungs) (co [(r 1) t] (r 2) g))
       (: r (look f dn-rungs) (co [(r 1) t] (r 2) g)))

   ; --- the word map: each love word, the level it wants, its model name, its
   ; --- answer. love's ceil/saturate/bit/nil? read a whole value (they compose
   ; --- the rungs below them), which is why they all want a val.
   wordmap '((net val vnet msr) (re msr mre rea) (ceil val vceil zed)
             (saturate val vsat nat) (bit val vbit bool) (nil? val vnil bool)
             (cap val vcap val) (cup val vcup val) (two? val vtwo bool))
   ; the binary words: what each side wants, the model's name, what it answers
   wordmap2 '((link val val vlink val) (>< val val vlink val)
              (&& bool bool andb bool) (|| bool bool orb bool))

   ; --- tx: an expression to [1 term level], or [0 the-word-that-stopped-it] ---
   (ok t l) [1 t l]
   (bad r) [0 r]
   (won? r) (two? r && one? <r)
   (un1 a env want mk res)
    (: r (tx a env) (? (! (won? r)) r (ok (mk (co (r 1) (r 2) want)) res)))
   (un2 e env w)
    (: A (tx (e 1) env) B (tx (e 2) env)
       (? (! (won? A)) A (! (won? B)) B
          (ok [(w 3) (co (A 1) (A 2) (w 1)) (co (B 1) (B 2) (w 2))]
              (w 4))))
   ; love's `=` between two values is structural, not identity -- that is what veq
   ; is for. below val the carriers are canonical and their own eqb reads them.
   (eqof e env)
    (: A (tx (e 1) env) B (tx (e 2) env)
       (? (! (won? A)) A (! (won? B)) B
          (: la (A 2) lb (B 2) L (? ((ht la) < (ht lb)) lb la)
             ta (co (A 1) la L) tb (co (B 1) lb L)
             (? (= L 'bool) (ok ['beqb ta tb] 'bool)
                (= L 'nat)  (ok ['nateqb ta tb] 'bool)
                (ok ['veq (co ta L 'val) (co tb L 'val)] 'bool)))))
   ; a guard the tower can read stays: it becomes the implication it was
   (guard-orb e env)
    (: P (tx (e 1) env)
       (? (! (won? P)) P
          (: yes (one? (e 2))
             E (tx (? yes (e 3) (e 2)) env)
             (? (! (won? E)) E
                (: p (co (P 1) (P 2) 'bool)
                   (ok ['orb (? yes p ['negb p]) (co (E 1) (E 2) 'bool)] 'bool))))))
   ; (? (< 0 E) E 0) at the integers is the clamp -- saturate's own shape
   (clamp? e)
    (: c (e 1)
       (hd? c "<" && #c = 3 && zero? (c 1)
        && same? (c 2) (e 2) && zero? (e 3)))
   (tx e env)
    (? (charm? e) (ok e 'nat)
       (nom? e) (: p (look e env) (? (two? p) (ok (p 1) (p 2)) (bad (show e))))
       (= e ()) (ok 'vnilv 'val)                       ; the empty list is the model's ()
       (! (two? e)) (bad (show e))
       (: h <e n #e w (look h wordmap) w2 (look h wordmap2)
        (? (n = 2 && two? w) (un1 (e 1) env (w 1) (\ t [(w 2) t]) (w 3))
           (n = 3 && two? w2) (un2 e env w2)
           (n = 4 && is? h "?" && clamp? e)
            (un1 (e 2) env 'zed (\ t ['zsat t]) 'nat)
           (n = 4 && is? h "?" && (one? (e 2) || one? (e 3))) (guard-orb e env)
           ; (< 0 E) and (= 0 E) on a saturated measure: the bit and its complement
           (n = 3 && is? h "<" && zero? (e 1))
            (un1 (e 2) env 'nat (\ t ['natgtb t 0]) 'bool)
           (n = 3 && is? h "=" && zero? (e 1))
            (un1 (e 2) env 'nat (\ t ['niszero t]) 'bool)
           (n = 3 && is? h "=" && zero? (e 2))
            (un1 (e 1) env 'nat (\ t ['niszero t]) 'bool)
           (n = 3 && is? h "=") (eqof e env)
           (bad (show h)))))

   ; --- the body: peel a band guard, bind a `:` into the environment, then read
   ; --- the claim. a guard that erases is reported, never dropped in silence.
   (guard1? b) (hd? b "?" && #b = 4 && (one? (b 2) || one? (b 3)))
   ; only a guard the tower cannot read erases; one it can becomes an orb above
   (peel b env) (? (guard1? b && ! (won? (tx (b 1) env)))
                   [((peel (? (one? (b 2)) (b 3) (b 2)) env) 0) (show (b 1))]
                   [b ()])
   (letish? b) (hd? b ":" && #b = 4 && nom? (b 1))

   ; --- claim: the translated obligation body, and its left side ---
   (claim b env)
    (? (letish? b)
        (: r (tx (b 2) env)
           (? (! (won? r)) r
              (claim (b 3) ([(b 1) (r 1) (r 2)] . env))))
       (hd? b "=" && #b = 3)
        (: A (tx (b 1) env) B (tx (b 2) env)
           (? (! (won? A)) A (! (won? B)) B
              (: la (A 2) lb (B 2)
                 L (? ((ht la) < (ht lb)) lb la)
                 ta (co (A 1) la L) tb (co (B 1) lb L)
                 ; at val the claim is veq's; below it the carrier is canonical
                 (? (= L 'val) (: q ['veq ta tb] [1 ['paths 'bool q 'true] q])
                    [1 ['paths L ta tb] ta]))))
       ; anything else the tower reads as a bool is the claim "..and it is true"
       (: r (tx b env)
          (? (won? r && (= (r 2) 'bool)) [1 ['paths 'bool (r 1) 'true] (r 1)]
             (won? r) (bad ("a claim at the " + (string (r 2)) + " rung"))
             (bad (? (hd? b ":") "a (: ..) binding the tower cannot follow"
                     (two? b) (show <b)
                     (show b))))))

   ; --- a range check is not an obligation: the tower already assigns the
   ; --- codomain, so (|| (= b 0) (= b 1)) and (&& (<= 0 s) (charm? s)) have
   ; --- nothing left to say. detected by shape, answered by the type.
   (unlet b env) (? (letish? b)
                    (: r (tx (b 2) env)
                       (? (! (won? r)) ()
                          (unlet (b 3) ([(b 1) (r 1) (r 2)] . env))))
                    [b env])
   (eq0? c) (hd? c "=" && #c = 3 && zero? (c 2))
   (eq1? c) (hd? c "=" && #c = 3 && one? (c 2))
   (bool-range? e) (hd? e "||" && #e = 3 && eq0? (e 1) && eq1? (e 2))
   (nat-range? e) (hd? e "&&" && #e = 3
                   && (: c (e 1) (hd? c "<=" && zero? (c 1)))
                   && (hd? (e 2) "charm?"))
   (range? b env)
    (: c (unlet ((peel b env) 0) env)
       (? (! (two? c)) ()
          (: e (c 0) en (c 1)
             (? (! (bool-range? e) && ! (nat-range? e)) ()
                (: inner (? (bool-range? e) ((e 1) 1) ((e 1) 2))
                   r (tx inner en)
                   (? (won? r) (r 2) ()))))))

   ; --- the kernel, live: a strategy is tried, not asserted ---
   dq (uu 'defq)
   _ (hear (\ p e (: h (peep HELPC () 0) (? h (h p e) 0))))
   (checks? nm ty tm) (= 'accepted (rejects (\ z (dq nm ty tm))))

   ; --- the rows ---
   fs (forms (open "test/law.l" "r"))
   (findb l) (? (! (two? l)) () (= <l 'law-rows) (l 1) (findb >l))
   rows >(findb >(cap fs))
   (qstrip s) (: (go i) (? (i = tally s) ""
                            ((? (s i = 63) "q" (s i = 61) "eq" (string (s i))) + go (i + 1)))
                 (go 0))                                 ; ? is no name character downstream
   (surface? b) (hd? b "=" && #b = 3 && same? (b 1) (b 2))

   ; --- one row, all the way to [nm src type proof how guard], [nm 'range level]
   ; --- or [nm () reason] ---
   (row1 r0)
    (: r (unglue (opfix r0)) nm (unq (r 1)) lm (r 2)
       (? (! (two? lm) || ! (= <lm bs) || ! (nom? (lm 1))) [nm () "not a lambda"]
        (: x (lm 1) b0 (lm 2)
           g (peel b0 [[x (quote v) (quote val)]]) b (g 0)
           (? (one? b) [nm () "trivially 1"]
              (: rg (range? b0 [[x 'v 'val]])
                 (? (nom? rg) [nm 'range (string rg)]
                  (? (surface? b && (= (g 1) ())) [nm () "the sigil lane: (= e e) after opfix"]
                   (: cl (claim b [[x 'v 'val]])
                      (? (! (won? cl)) [nm () ("off the model: " + (cl 1))]
                       (: ty ['pi 'v 'val (cl 1)]
                          gnm (intern ("law-" + (qstrip (show nm))))
                          p1 ['lam 'v ['idpath (cl 2)]]
                          (? (checks? gnm ty p1) [nm r0 ty p1 (quote conv) (g 1)]
                             (: mo (claim b [[x ['nval 'n] 'val]])
                                b0v (claim b [[x ['nval 0] 'val]])
                                bkv (claim b [[x ['nval ['succ 'k]] 'val]])
                                p2 ['lam 'v ['nat_rect ['lam 'n (mo 1)]
                                                       ['idpath (b0v 2)]
                                                       ['lam 'k ['lam 'r ['idpath (bkv 2)]]]
                                                       ['vsat 'v]]]
                                p3 (intern ("uv-" + (qstrip (show nm))))
                                (? (checks? gnm ty p2)
                                   [nm r0 ty p2 (quote cases) (g 1)]
                                   (checks? gnm ty p3)
                                   [nm r0 ty p3 (quote lemma) (g 1)]
                                   [nm () "no proof found"])))))))))))))

   done (map row1 rows)
   (rng? d) (= (d 1) 'range)
   proved (filter (\ d (two? (d 1))) done)
   ranged (filter rng? done)
   missed (filter (\ d (! (two? (d 1)) && ! (rng? d))) done)
   (pad s n) (? (#s < n) (pad (s + " ") n) s)
   (srcof d) (show ((unglue (opfix (d 1))) 2))

   ; --- emit ---
   _ (pl "; test/uuvallaw.l -- generated from test/law.l by tools/law2uu.l. Do not edit;")
   _ (pl "; refresh with `make uuvallaw`. CLAUDE.md's laws, one spelling for both lanes:")
   _ (pl "; test/law.l quantifies each row over a corpus (refutation), and the rows the")
   _ (pl "; measure tower can state arrive here as uu obligations over test/uuval.l's")
   _ (pl "; model (proof). the source row prints over its term, and every proof was")
   _ (pl "; searched against the live kernel -- by conversion where the tower's round")
   _ (pl "; trips are definitional, by cases on the saturated measure where they are")
   _ (pl "; not, and otherwise by the lemma the model names for that row.")
   _ (pl "; a guard the tower cannot read erases (the model has one uniform value),")
   _ (pl "; which makes the obligation stronger than the row it came from, never")
   _ (pl "; weaker; each such row names the guard it dropped. a guard it can read")
   _ (pl "; stays, as the orb it always was. a val-rung claim is veq's -- a guarded row
; needs a decidable claim, and a path is not a bool -- and where the guard
; erased the row gets its paths twin over the pinned carrier beside it, by
; uuval.l's bridge. Substrate: test/uuval.l over test/uu.l.")
   _ (pl "")
   _ (pl "(assert (member? 'vof (names ())))")
   _ (pl "")
   _ (pl "(assert")
   ; the cases proof wears its four operands one to a line: the motive is the
   ; obligation again at (nval n), and reading them stacked is the point
   (proofof d)
    (: p (d 3)
       (? (! (= (d 4) 'cases)) ("   " + (show p) + ")")
          (: nr (p 2)
             (join ["   (lam v (nat_rect " (show (nr 1)) nl
                    "                     " (show (nr 2)) nl
                    "                     " (show (nr 3)) nl
                    "                     " (show (nr 4)) ")))"]))))
   (howof d) (? (= (d 4) 'conv)  "by conversion"
                (= (d 4) 'cases) "by cases on the saturated measure"
                "by the lemma the model names")
   ; a val-rung claim is veq's, because a guarded row needs a decidable one --
   ; an orb takes a bool and a path is not one. where the guard erased and the
   ; claim stands alone, the bridge restates it over the pinned carrier, which
   ; is mechanical: the same law, as an equality rather than a decision.
   (veqclaim? ty)
    (: c (ty 3)
       (#c = 4 && (= (c 0) 'paths) && (= (c 1) 'bool)
        && (= (c 3) 'true)
        && (: q (c 2) (two? q && #q = 3 && (= (q 0) 'veq)))))
   (twinof d)
    (? (! (veqclaim? (d 2))) 0
       (: q (((d 2) 3) 2) ta (q 1) tb (q 2)
          g (intern ("law-" + (qstrip (show (d 0)))))
          _ (pl " ; ..and the same law over the pinned carrier, by the bridge")
          _ (pl (" (defq law-" + (qstrip (show (d 0))) + "-p"))
          _ (pl ("   " + (show ['pi 'v 'val ['paths 'pval ['pin ta] ['pin tb]]])))
          (pl ("   " + (show ['lam 'v ['uv-veq-paths ta tb [g 'v]]]) + ")"))))
   _ (map (\ d (: _ (pl (join [" ; " (show (d 0)) "   " (srcof d)]))
                  _ (pl (join [" ; " (howof d)
                               (? (= (d 5) ()) "" ("; the guard " + (d 5) + " erases"))]))
                  _ (pl (" (defq law-" + (qstrip (show (d 0)))))
                  _ (pl ("   " + (show (d 2))))
                  _ (pl (proofof d))
                  (twinof d)))
          proved)
   _ (pl ")")
   _ (pl "")
   _ (pl "; --- rows whose codomain is the proof: the tower assigns the type, so the")
   _ (pl "; --- range check has nothing left to state ---")
   _ (map (\ d (pl (join [" ;   " (pad (show (d 0)) 14) "lands in " (d 2)]))) ranged)
   _ (pl "")
   _ (pl "; --- off the model, with the reason (skipped and counted, never dropped) ---")
   _ (map (\ d (pl (join [" ;   " (pad (show (d 0)) 14) (d 2)]))) missed)
   _ (pl "")
   _ (pl (join [" ; " (show #proved) " obligations / " (show #rows)
                " law rows; " (show #ranged) " carried by a type, "
                (show #missed) " off the model."]))
   (quit 0))
