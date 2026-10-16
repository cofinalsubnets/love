; --- test/c0push.l: a macro's operands held across a push that collects ---
; the compiler holds a macro's operands on the stack while the macro runs, and that push may
; collect. c0push-and expands to a fresh (&& a b), young, and has the nth push from there
; collect; for one n the collection falls on the push holding the &&'s operands, which must
; still be the operands after it
(:: 'c0push-and (\ l (: e (list '&& (cup l 0) (cup l 1)) _ ((cite 'guts 'push-gc) (cap l)) e)))
(: c0push-gc (cite 'guts 'push-gc)
   (c0push-try n) (: f (ev (list '\ 'a 'b (list 'c0push-and n 'a 'b))) _ (c0push-gc 0)
                     (f 1 1 = 1 && f 1 0 = 0 && f 0 1 = 0))
 (test (? c0push-gc (all c0push-try (map (+ 1) ^60)) 1)))
