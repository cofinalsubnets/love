; test/law/reach.l -- the live units of a link, from its roots through what each names
(borrow 'holo)
(: (live units roots) (reach units roots @ t (sort (keys t)))
   none ()
   u '((a b c) (b d) (c) (d b) (e f) (f e) (g))
   _ (test ((live u '(a)) = '(a b c d)))                    ; through a cycle, each once
   _ (test ((live u '(e)) = '(e f)))                        ; a cycle nothing else names is its own
   _ (test ((live u none) = none))                            ; no root, nothing
   _ (test ((live u '(g zz)) = '(g)))                       ; a root no unit carries is passed over
   _ (test ((live '((a zz)) '(a)) = '(a)))                  ; and so is such a reference
   _ (test ((map cap (reach-keep u (reach u '(d g a)))) = '(a b c d g))) ; the units' order, not the roots'
   _ (test ((live '((a a)) '(a)) = '(a)))                   ; a unit naming itself
   (test_fin (), say err "test/law/reach: roots, cycles, order, strangers ok", put err 10, 0))
