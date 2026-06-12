; missing -- a nom not in the book (the global table). reading one is a
; CALL FOR HELP: with a global help installed the read raises
; (help 1 'missing nom) and the help's result becomes the value at the site;
; helpless it reads () -- false, like the old nil read, but the canonical
; empty point. the read happens where the code says it does: a closure
; captures its free globals at creation, so a missing read in a lambda body fires
; the condition at the define, not the call.

(assert
 (idp () an-never-defined)                       ; the default: () exactly
 !an-never-defined                               ; ... so a missing name is false
 (symp an-never-defined))                        ; ... and a symbol (THE symbol)

; a name BOUND to nil is in the book -- not missing, no condition
(: an-zero 0)
(: help (\ s a b 'BOOM))
(assert (0 = an-zero) !(idp () an-zero))
(: help 0)

; the help hears (help s 'missing nom) and its result is the value at the site
(: help (\ s a b (? (&& (scare? s) (idp a 'missing)) (L 'missing-was b) 0)))
(assert (: r an-ghost
           (&& (twop r) (idp 'missing-was (cap r)) (idp 'an-ghost (cabp r)))))
(: help 0)

; the read of a lambda's free global happens at closure creation (the runtime
; compiler captures it) or as a live site in the body (the bootstrap lane);
; with the help installed across both moments, both lanes answer the help.
; NOTE the discipline: love0 runs this corpus TWICE in one scope, so a name
; asserted missing must NEVER be defined later -- the second pass would fold it.
(: help (\ s a b (? (&& (scare? s) (idp a 'missing)) 42 0)))
(: (an-g _) an-phantom)
(assert (42 = (an-g 0)))
(: help 0)

; ONE SCOPE -- a `:` binds every name over the whole form. reading a binding
; before its value is pinned is the SAME condition, with the binding site's
; nom (name . mint) as payload: a call for help, () helpless. the two old silent
; lanes -- a direct forward read escaping to the book, a boxed pre-fill read
; of 0 -- are gone: one law at every depth, local or book.
(: an-outer 99)
(assert
 (idp () (: a an-outer an-outer 2 a))            ; no silent capture of the book's an-outer
 (idp () (: a an-local an-local 2 a))            ; ... nor of nothing: () helpless
 (2 = (: a an-local an-local 2 an-local))        ; the body reads the local, post-pin
 (idp () (: f (\ _ an-cell) v (f 0) an-cell 5 v)) ; the boxed lane reads the same ()
 (5 = (: f (\ _ an-cell) v (f 0) an-cell 5 (f 0)))) ; ... and the cell, once pinned

; the help hears the cell miss too; the payload is the binding-site nom
(: help (\ s a b (? (&& (scare? s) (idp a 'missing) (twop b) ("an-fwd" = (cap b))) 'cell-nom 0)))
(assert (idp 'cell-nom (: q an-fwd an-fwd 2 q)))
(: help 0)

; the empty special forms are their head reads -- the same missing reads under a help
(: help (\ s a b (? (&& (scare? s) (idp a 'missing)) (L 'empty-form b) 0)))
(assert (: r (:) (&& (twop r) (idp ': (cabp r))))
        (: r (?) (&& (twop r) (idp '? (cabp r)))))
(: help 0)

; (missing t k) -- the book read as a value: k present in tablet t answers the
; value, a miss is the missing condition with k as payload. a tablet is a little
; book; `the` book is just the outermost one.
(assert (10 = (missing #(1 10) 1)) (idp () (missing #() 'k)) (idp () (missing 5 'k))
        (0 = (missing #(1 0) 1)))                   ; presence beats value: a pinned 0 answers 0
(: help (\ s a b (? (&& (scare? s) (idp a 'missing) (idp b 'an-missing)) 'heard 0)))
(assert (idp 'heard (missing #() 'an-missing)))
(: help 0)
