; zev: charms -> hom -- the reverse shell of the compiler, the lane every
; shell feeds into; ev is the data-level shell over the same core. a charm
; is a sat (a non-negative fixnum), a charms is a charlist. zev reads one
; form structurally and compiles it through opfix/wev/ana/cata, so the
; whole hull -- characters to hom -- closes in lisp.
(: (zs s) ((: (g i) (? (< i $s) (cons (s i) (g (+ 1 i))))) 0)   ; string -> charms
 (assert
  (3 = (zev (zs "(+ 1 2)")))                  ; the plain lane
  (3 = (zev (zs "(1 + 2)")))                  ; infix factors through the charm lane
  (7 = (zev (zs "(1 + 2 * 3)")))              ; right-assoc, same as ev
  (4 = (zev (zs "($\"ab\" + 2)")))            ; one binds tightest, same as ev
  (1 = (zev (zs "(!0)")))                     ; sigils factor mid-form; a BARE "!0" is
                                              ; two datums -- wrapping a whole line is a
                                              ; shell's move (the repl's), not zev's
  ('x = (zev (zs "'x")))                      ; quote is the reader's
  ('! = (cabp (zev (zs "'(a ! b)"))))         ; quoted operators stay data
  (homp (zev (zs "(\\ x (x + 1))")))          ; zev is the source of homs
  (5 = ((zev (zs "(\\ x (x + 2))")) 3))       ; ... which apply
  (9 = (zev (zs "(: q (\\ x (x * x)) (q 3))")))
  !(zev (zs ""))                              ; nothing readable is nothing
  !(zev (zs "(+ 1"))                          ; an unfinished shape is nothing
  (1 = (zev (zs "1")))))
