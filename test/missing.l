; missing -- a nom not in the book (the global table). reading one is a
; CALL FOR HELP: with a global help installed the read raises
; (help 1 'missing nom) and the help's result becomes the value at the site;
; helpless it reads the ZERO POINT -- the mint at serial 0: nameless, false,
; and a unit (absence absorbs application). the read happens where the code says it does: a closure
; captures its free globals at creation, so a missing read in a lambda body fires
; the condition at the define, not the call.

(assert
 (id? (:) an-never-defined)                      ; the default: the zero point
 !an-never-defined                               ; ... so a missing name is false
 (nom? an-never-defined))                        ; ... a nameless point, not a number

; a name BOUND to 0 is in the book -- not missing, no condition: under an
; armed help the read still answers its own 0 (presence beats value; the
; value no longer tells bound from missing apart -- the condition lane does)
(: an-zero 0)
(: help (\ s a b 'BOOM))
(assert (0 = an-zero) !(id? 'BOOM an-zero) !(id? (:) an-zero))
(: help 0)

; the help hears (help s 'missing nom) and its result is the value at the site
(: help (\ s a b (? (&& (scare? s) (id? a 'missing)) (L 'missing-was b) 0)))
(assert (: r an-ghost
           (&& (two? r) (id? 'missing-was (cap r)) (id? 'an-ghost (caup r)))))
(: help 0)

; the read of a lambda's free global happens at closure creation (the runtime
; compiler captures it) or as a live site in the body (the bootstrap lane);
; with the help installed across both moments, both lanes answer the help.
; NOTE the discipline: ai0 runs this corpus TWICE in one scope, so a name
; asserted missing must NEVER be defined later -- the second pass would fold it.
(: help (\ s a b (? (&& (scare? s) (id? a 'missing)) 42 0)))
(: (an-g _) an-phantom)
(assert (42 = (an-g 0)))
(: help 0)

; ONE SCOPE -- a `:` binds every name over the whole form. reading a binding
; before its value is pinned is the SAME condition, with the binding site's
; nom (name . mint) as payload: a call for help, the zero point helpless. the two old silent
; lanes -- a direct forward read escaping to the book, a boxed pre-fill read
; of 0 -- are gone: one law at every depth, local or book.
(: an-outer 99)
(assert
 (id? (:) (: a an-outer an-outer 2 a))            ; no silent capture of the book's an-outer
 (id? (:) (: a an-local an-local 2 a))            ; ... nor of nothing: the point helpless
 (2 = (: a an-local an-local 2 an-local))        ; the body reads the local, post-pin
 (id? (:) (: f (\ _ an-cell) v (f 0) an-cell 5 v))  ; the boxed lane reads the same point
 (5 = (: f (\ _ an-cell) v (f 0) an-cell 5 (f 0)))) ; ... and the cell, once pinned

; the help hears the cell miss too; the payload is the binding-site nom
(: help (\ s a b (? (&& (scare? s) (id? a 'missing) (nom? b) ("an-fwd" = (cap b))) 'cell-nom 0)))
(assert (id? 'cell-nom (: q an-fwd an-fwd 2 q)))
(: help 0)

; the empty special forms are their head reads -- the same missing reads under a help
(: help (\ s a b (? (&& (scare? s) (id? a 'missing)) (L 'empty-form b) 0)))
(assert (: r (:) (&& (two? r) (id? ': (caup r))))
        (: r (?) (&& (two? r) (id? '? (caup r)))))
(: help 0)

; (missing t k) -- the book read as a value: k present in tablet t answers the
; value, a miss is the missing condition with k as payload. a tablet is a little
; book; `the` book is just the outermost one.
(assert (10 = (missing #(1 10) 1)) (id? (:) (missing (tablet 0) 'k)) (id? (:) (missing 5 'k))
        (0 = (missing #(1 0) 1)))                   ; presence beats value: a pinned 0 answers 0
(: help (\ s a b (? (&& (scare? s) (id? a 'missing) (id? b 'an-missing)) 'heard 0)))
(assert (id? 'heard (missing (tablet 0) 'an-missing)))
(: help 0)
