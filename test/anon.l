; anon -- a nom not in the book (the global table). reading one is a
; TRAPPABLE CONDITION: with a global trap installed the read raises
; (trap 1 'anon nom) and the trap's result becomes the value at the site;
; untrapped it reads () -- false, like the old nil read, but the canonical
; empty point. the read happens where the code says it does: a closure
; captures its free globals at creation, so an anon in a lambda body fires
; the condition at the define, not the call.

(assert
 (idp () an-never-defined)                       ; the default: () exactly
 !an-never-defined                               ; ... so an anon is false
 (symp an-never-defined))                        ; ... and a symbol (THE symbol)

; a name BOUND to nil is in the book -- not an anon, no condition
(: an-zero 0)
(: trap (\ s a b 'BOOM))
(assert (0 = an-zero) !(idp () an-zero))
(: trap 0)

; the trap hears (trap s 'anon nom) and its result is the value at the site
(: trap (\ s a b (? (&& (scare? s) (idp a 'anon)) (L 'anon-was b) 0)))
(assert (: r an-ghost
           (&& (twop r) (idp 'anon-was (cap r)) (idp 'an-ghost (cabp r)))))
(: trap 0)

; the read of a lambda's free global happens at closure creation (the runtime
; compiler captures it) or as a live site in the body (the bootstrap lane);
; with the trap installed across both moments, both lanes answer the trap.
; NOTE the discipline: love0 runs this corpus TWICE in one scope, so a name
; asserted anon must NEVER be defined later -- the second pass would fold it.
(: trap (\ s a b (? (&& (scare? s) (idp a 'anon)) 42 0)))
(: (an-g _) an-phantom)
(assert (42 = (an-g 0)))
(: trap 0)
