; the vm instrument panel: clock (ms), nclock (monotonic ns), gauge (stats in words),
; and please, a collection on demand (() minor, a charm major) answering the count
(test (charm? (clock 0)) (0 <= nclock (nclock 0)) (16 = tally (gauge 0)))
(: c1 (please ()) c2 (please 1)                  ; the sequence law orders the two asks
 (test (c1 < c2)))

; tune, gauge's write twin: [budget minor0 major0 ratio] in words. a write answers what it
; replaced; a wrong shape writes nothing and answers the current knobs
(: k0 (tune ())                                  ; whatever this run booted with
   old (tune [2097152 32768 131072 16])
   now (tune ())
   bad (tune 'nonsense)                          ; refused: not a list of four
   back (tune k0)                                ; ..put back for the rest of the corpus
 (test (4 = tally k0) (two? k0)
         (k0 = old)                              ; a write answers what it replaced
         (2097152 = peep now 0 0) (16 = peep now 3 0)
         (now = bad)                             ; a refused shape wrote nothing
         (now = back) (k0 = (tune ()))
         (now @ (2097152 . _ . _ . r . _) (16 = r) 0)       ; a list, so @ reads it
         (gauge 0 @ (_ . _ . _ . n . _) (charm? n) 0)))
