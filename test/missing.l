; reading a nom not in the book calls (help 'missing nom), whose answer is the value at the site;
; with nothing heard it stops the run. welp answers it with the zero point, quietly
(hear welp)
(test
 ((:) = an-never-defined)                      ; the floor handler
 !an-never-defined
 !(nom? an-never-defined))                       ; the zero point is not a nom
(hear 0)

; a name bound to 0 is in the book: an armed help never hears it
(: an-zero 0)
(hear (a \ b \ 'BOOM))
(test (0 = an-zero) !('BOOM = an-zero) !((:) = an-zero))
(hear 0)

; the help hears (help 'missing nom) and its result is the value at the site
(hear (a \ b \ a = 'missing ? ['missing-was b] 0))
(test (an-ghost @ r
       (two? r && 'missing-was = <r && 'an-ghost = <>r)))
(hear 0)

; a lambda's free global is read at creation or in the body; both answer the help.
; a name asserted missing must never be defined later: the corpus may run twice in one scope
(hear (a \ b \ a = 'missing ? 42 0))
(: (an-g _) an-phantom)
(test (42 = (an-g 0)))
(hear 0)

; eager reads see let*, closures letrec*: a bare pre-pin read is the outer binding, a closure's the cell
(hear welp)
(: an-outer 99)
(test
 (99 = (: a an-outer an-outer 2 a))              ; the bare pre-pin read is the book's an-outer
 ((:) = (: a an-local an-local 2 a))            ; ... and of nothing, the zero point
 (2 = (: a an-local an-local 2 an-local))
 ((:) = (: f (_ \ an-cell) v (f 0) an-cell 5 v))  ; the closure's read is the cell: the point pre-pin
 (5 = (: f (_ \ an-cell) v (f 0) an-cell 5 (f 0)))) ; ... and the value, once pinned
; nested and shadowed: the outer answers only eager pre-pin reads, never a closure's
(: an-outer2 42)
(test
 (43 = (1 @ q (: an-outer2 (an-outer2 + 1) an-outer2)))      ; shadowed constant, nested: the outer 42 + 1
 (43 = ((p \ (: p (p + 1) p)) 42))                           ; ..and a shadowed lambda param, alike
 ((:) = (99 @ an-o3 (: f (_ \ an-o3) r (f 0) an-o3 42 r))) ; ..the closure's read is the cell, outer in scope
 (2 = (: b 1 b (b + 1) b))                                   ; a rebind within one chain still
 (43 = (: c 42 d (c + 1) d)))                                ;   reads the previous value, and folds
(hear 0)

; the help hears the cell miss too; the payload is the binding-site nom
(hear (a \ b \ a = 'missing && nom? b && "an-fwd" = (string b) ? 'cell-nom 0))
(test ('cell-nom = (: g (_ \ an-fwd) q (g 0) an-fwd 2 q)))
(hear 0)

(hear (a \ b \ a = 'missing ? 'fired 0))
(test ((:) = ()) ((?) = ()) ((\) = ()))
(hear 0)

; presence in a tablet: peep with a fresh (mint 0) default, which no stored value can pose as
(test (: t {1 0} s (mint 0)
           (!(s = peep t 1 s)           ; a pinned 0 is present, not absent
               && s = peep t 9 s         ; an absent key is absent
               && (:) = (peep t 9 ())))) ; ... and the caller may still name absence ()

(hear test-strict)   ; the empty slot is this file's subject; the corpus resumes strict
