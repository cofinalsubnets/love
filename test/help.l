; the help calling convention: (hear f) installs f, which receives (help a b), the
; condition data and nothing else. uninstalled at the end of this file
(: help-log {})

; a counting ap, keyed by the tag it hears
(hear (p \ e \ (pin help-log p (1 + peep help-log p 0), 0)))

; (scare a b) is the deliberate raise; the help's result is its value
(test (0 = scare 'deliberate 'data))
(test (1 = peep help-log 'deliberate 0)) ; observed exactly once

; the help function owns the protocol: deliver a constant instead
(hear (p \ e \ 'gotcha))
(test ('gotcha = scare 'any 'thing))

; uninstall: a non-lit? value defers to the raw default
(hear 0)
(test !(heard ()) !(lit? (heard ())))

; help is present by its net: "" is no help; (\ a b 1) nets 1 and answers every scare,
; a missing read included
(hear "")
(test !(heard ()) !(lit? (heard ())))
(hear (a \ b \ 1))
(test (1 = (scare 'k 'v)) (1 = one-nothing-unpinned-2))   ; net-1 help: the miss fires it
(hear 0)

; the help is per task. every twirl is caught: an orphan stalls the kernel runner
(test (: pa (twirl (_ \ (hear (a \ b \ 'A), rest 0, scare 'x 0)) ())
           pb (twirl (_ \ (hear (a \ b \ 'B), rest 0, scare 'x 0)) ())
           ra (catch pa) rb (catch pb)
           (ra = 'A && rb = 'B)))
; a child starts under its parent's help, and its own install stays its own
(hear (a \ b \ ['parent a]))
(test (: pc (twirl (_ \ (rest 0, scare 'from-c 0)) ())        ; installs none
           rc (catch pc)
           pd (twirl (_ \ (hear (a \ b \ 'child), rest 0, scare 'x 0)) ())
           rd (catch pd)
           mine (scare 'mine 0)
           (two? rc && 'from-c = <>rc                 ; inherited the parent's
            && rd = 'child                            ; ..its own install took
            && two? mine && 'mine = <>mine)))         ; ..and the parent's survived it
(hear 0)

; trap: (trap f x n) answers (f x) clean, or (n a b) when a scare lands here.
; nothing unwinds, so a cleanup belongs in n
(test (3 = (trap (+ 1) 2 (a \ b \ 'no)))
        ((:) = (trap (_ \ ()) () (a \ b \ 'no)))
        ('(boom 7) = (trap (_ \ scare 'boom 7) () (a \ b \ [a b])))
        ((:) = (trap (_ \ scare 'x 0) () welp))             ; the floor handler is an n
        (3 = (trap (foldl (a \ x \ x = 3 ? (scare 'hit x) a) 0)     ; caught from depth,
                   '(1 2 3 4) (a \ b \ b)))
        ('(outer in) = (trap (_ \ trap (_ \ scare 'in 0) () (a \ b \ scare 'outer a))
                             () (a \ b \ [a b])))             ; n may re-raise: the outer help hears it
        ; one trap per task, all open at once: each catches its own
        (: (sess i) (twirl (_ \ (rest 0, trap (_ \ scare 'boom i) () (a \ b \ b))) ())
           ('(1 2 3) = (map catch (map sess '(1 2 3))))))
; n fires with the displaced help back, so a raise in it goes to the trap outside
(hear (a \ b \ 'floor))
(test ('(outer-saw from-n) = (trap (_ \ trap (_ \ scare 'x 0) () (a \ b \ scare 'from-n a))
                                     () (a \ b \ ['outer-saw a])))
        (trap (_ \ scare 'x 0) () (a \ b \ 0), 'floor = scare 'y 0))
(hear 0)

; mind: (mind f x c) answers (f x) and fires c once on the way out, clean or raised;
; a condition rides on outward to its trap
(: mlog {}
   (note s) (pin mlog 0 (mlog 0 + [s]))
   (fresh _) (pin mlog 0 ())
   (test
    ; the clean path: c fires after f, and f's own value is the form's
    (: _ (fresh ())
       v (mind (_ \ (note 'body, 'value)) () (_ \ note 'freed))
       (v = 'value && '(body freed) = mlog 0))
    ; the raised path: c fires, and the condition goes on to the catcher outside
    (: _ (fresh ())
       r (trap (_ \ mind (_ \ (note 'body, scare 'boom 7)) () (_ \ note 'freed))
               () (a \ b \ [a b]))
       ('(boom 7) = r && '(body freed) = mlog 0))
    ; one raise fires every c between it and the catcher, innermost first
    (: _ (fresh ())
       r (trap (_ \ mind (_ \ mind (_ \ scare 'deep 0) () (_ \ note 'inner))
                         () (_ \ note 'outer))
               () (a \ b \ a))
       (r = 'deep && '(inner outer) = mlog 0))
    ; c runs with the displaced help back, so its own raise belongs to the trap outside
    ('from-c = (trap (_ \ mind (_ \ 'v) () (_ \ scare 'from-c 0)) () (a \ b \ a)))
    ; exactly once under a help that answers rather than escapes, the repl's ordinary path
    (: _ (fresh ()) prev (heard ())
       _ (hear (a \ b \ 'answered))
       r (mind (_ \ scare 'boom 0) () (_ \ note 'freed))
       (hear prev,
        r = 'answered && '(freed) = mlog 0))
    (: _ (fresh ()) prev (heard ())
       _ (hear welp)
       r (mind (_ \ scare 'boom 0) () (_ \ note 'freed))
       (hear prev,
        !r && '(freed) = mlog 0))
    ; raises only: a k captured outside jumps clean past every c
    (: _ (fresh ())
       v (call-cc (k \ mind (_ \ k 'jumped) () (_ \ note 'never)))
       (v = 'jumped && !(mlog 0)))))

; a trap's escape is its task's: a child raising under an inherited trap meets the
; help it would have met with no trap in sight, never a jump into its parent's stack
(: prev (heard ())
   _ (hear (a \ b \ 'delegated))
   log {}
   (note s) (pin log 0 (log 0 + [s]))
   ; the child's raise is answered in the child, and both tasks run to their ends
   r (trap (_ \ twirl (_ \ scare 'child-boom 0 @ v (note 'child-lived, v)) () @ p
                (catch p, note 'parent-lived, 'clean))
           () (a \ b \ 'trapped))
   (hear prev,
    (test (r = 'clean) ('(child-lived parent-lived) = (log 0))
            ; ..and a trap the child installs itself still escapes: home is its own task
            (twirl (_ \ trap (_ \ scare 'mine 7) () (a \ b \ [a b])) () @ q
             ('(mine 7) = (catch q))))))

; welp, the floor handler: any raise to the zero point. a plain function a policy
; out of cases delegates to
(test ((:) = (welp 'x 'y))
        !(welp 'x 'y))                         ; ..which nets nothing

; --- the arity is the protocol: a 3-arg help would answer a truthy partial in silence,
; so both doors refuse a non-binary handler. one-sided: a shape binary? can't read passes
(hear welp)
(test
 (binary? (a \ b \ a)) (binary? welp)
 !(binary? (a \ b \ c \ a)) !(binary? (a \ a)) !(binary? 0) ; over, under, and not a handler at all
 (binary? cap) (binary? (+ 1))                            ; unreadable shapes pass (one-sided)
 ; a bad handler raises rather than being installed / run
 ('help-arity = (trap (_ \ hear (a \ b \ c \ 1)) () (a \ b \ a)))
 ('help-arity = (trap (_ \ trap (_ \ 1) () (a \ a)) () (a \ b \ a)))
 ; ... and every nothing still uninstalls
 (: _ (hear ()) r !(heard ()) (hear welp, r)))
(hear 0)

(hear test-strict)   ; the empty slot is this file's subject; the corpus resumes strict
