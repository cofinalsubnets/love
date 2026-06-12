; anom -- a nom not in the book (the global table). reading one is a
; TRAPPABLE CONDITION: with a global trap installed the read raises
; (trap 1 'anom nom) and the trap's result becomes the value at the site;
; untrapped it reads () -- false, like the old nil read, but the canonical
; empty point. the read happens where the code says it does: a closure
; captures its free globals at creation, so an anom in a lambda body fires
; the condition at the define, not the call.

(assert
 (idp () an-never-defined)                       ; the default: () exactly
 !an-never-defined                               ; ... so an anom is false
 (symp an-never-defined))                        ; ... and a symbol (THE symbol)

; a name BOUND to nil is in the book -- not an anom, no condition
(: an-zero 0)
(: trap (\ s a b 'BOOM))
(assert (0 = an-zero) !(idp () an-zero))
(: trap 0)

; the trap hears (trap s 'anom nom) and its result is the value at the site
(: trap (\ s a b (? (&& (scare? s) (idp a 'anom)) (L 'anom-was b) 0)))
(assert (: r an-ghost
           (&& (twop r) (idp 'anom-was (cap r)) (idp 'an-ghost (cabp r)))))
(: trap 0)

; the read of a lambda's free global happens at closure creation (the runtime
; compiler captures it) or as a live site in the body (the bootstrap lane);
; with the trap installed across both moments, both lanes answer the trap.
; NOTE the discipline: love0 runs this corpus TWICE in one scope, so a name
; asserted anom must NEVER be defined later -- the second pass would fold it.
(: trap (\ s a b (? (&& (scare? s) (idp a 'anom)) 42 0)))
(: (an-g _) an-phantom)
(assert (42 = (an-g 0)))
(: trap 0)

; ONE SCOPE -- a `:` binds every name over the whole form. reading a binding
; before its value is pinned is the SAME condition, with the binding site's
; nom (name . mint) as payload: trappable, () untrapped. the two old silent
; lanes -- a direct forward read escaping to the book, a boxed pre-fill read
; of 0 -- are gone: one law at every depth, local or book.
(: an-outer 99)
(assert
 (idp () (: a an-outer an-outer 2 a))            ; no silent capture of the book's an-outer
 (idp () (: a an-local an-local 2 a))            ; ... nor of nothing: () untrapped
 (2 = (: a an-local an-local 2 an-local))        ; the body reads the local, post-pin
 (idp () (: f (\ _ an-cell) v (f 0) an-cell 5 v)) ; the boxed lane reads the same ()
 (5 = (: f (\ _ an-cell) v (f 0) an-cell 5 (f 0)))) ; ... and the cell, once pinned

; the trap hears the cell miss too; the payload is the binding-site nom
(: trap (\ s a b (? (&& (scare? s) (idp a 'anom) (twop b) ("an-fwd" = (cap b))) 'cell-nom 0)))
(assert (idp 'cell-nom (: q an-fwd an-fwd 2 q)))
(: trap 0)

; the empty special forms are their head reads -- the same anoms under a trap
(: trap (\ s a b (? (&& (scare? s) (idp a 'anom)) (L 'empty-form b) 0)))
(assert (: r (:) (&& (twop r) (idp ': (cabp r))))
        (: r (?) (&& (twop r) (idp '? (cabp r)))))
(: trap 0)

; (anom t k) -- the book read as a value: k present in tablet t answers the
; value, a miss is the anom condition with k as payload. a tablet is a little
; book; `the` book is just the outermost one.
(assert (10 = (anom #(1 10) 1)) (idp () (anom #() 'k)) (idp () (anom 5 'k))
        (0 = (anom #(1 0) 1)))                   ; presence beats value: a pinned 0 answers 0
(: trap (\ s a b (? (&& (scare? s) (idp a 'anom) (idp b 'an-missing)) 'heard 0)))
(assert (idp 'heard (anom #() 'an-missing)))
(: trap 0)
