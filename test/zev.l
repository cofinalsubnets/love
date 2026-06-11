; zev: charms -> hom -- the reverse shell of the compiler, the lane every
; shell feeds into; ev is the data-level shell over the same core. a charm
; is a sat (a non-negative fixnum), a charms is a charlist. zev reads one
; form structurally and compiles it through opfix/wev/ana/cata, so the
; whole hull -- characters to hom -- closes in lisp.
(: (zs s) ((: (g i) (? (< i (tally s)) (cons (s i) (g (+ 1 i))))) 0)   ; string -> chars
 (assert
  (3 = (zev (zs "(+ 1 2)")))                  ; the plain lane
  (3 = (zev (zs "(1 + 2)")))                  ; infix factors through the charm lane
  (7 = (zev (zs "(1 + 2 * 3)")))              ; right-assoc, same as ev
  (197 = (zev (zs "($\"ab\" + 2)")))          ; one binds tightest, same as ev
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
  (1 = (zev (zs "1")))
  ; zevs: the stream shell -- a port is the hot charms; every form evals,
  ; the last value is the value. the host/love0/kernel runners ARE zevs.
  (42 = (zevs (sip (zs "(: zq 41) (zq + 1)"))))  ; defines land: the second form reads the first's
  !(zevs (sip (zs "")))
  (7 = (zevs (sip (zs "1 2 (3 + 4)"))))))     ; forms eval in order; the last one answers

; charms: the global construction -- the lazy colist. (cap cs) is a charm,
; ((cbp cs) ()) is charms + () (the coproduct, () the end); chars and ports
; lift canonically; consumers dispatch on kind (twop = cell, else end).
(: (zs2 s) ((: (g i) (? (< i (tally s)) (cons (s i) (g (+ 1 i))))) 0)
   cs (charms (zs2 "(+ 1 2)"))
 (assert
  (fixp (cap cs)) (homp (cbp cs))               ; a cell is charm x hom
  (40 = (cap cs))                               ; the charm is the byte
  (: r ((cbp cs) ()) (&& (twop r) (43 = (cap r))))  ; forcing with () yields the next cell
  (3 = (zev cs))                                ; zev drinks charms proper
  (idp () (charms ()))                          ; the end lifts to itself
  ('(40 43 41) = (charms->chars (zs2 "(+)")))   ; realize: charms end () -> chars end 0
  (6 = (zev (charms (sip (zs2 "(* 2 3)")))))    ; a port lifts: the hot charms
  (1 = (zev (cons 49 (\ _ ()))))))              ; a hand-built one-cell charms: "1"
