; the VM instrument panel -- read and write. (clock t) is ms since t; (nclock t) is its
; fine interval twin: monotonic ns minus t (ms-degraded where a frontend has no ns source,
; so monotone everywhere). (gauge 0) reads the VM stats as a list, in words.
; (please x) is a collection on demand -- () asks for a minor, a positive charm for a major --
; answering the collection count, so two asks order strictly. the worst pause of each kind
; rides gauge 14 and 15; test/host/gcpause.l reads the same list by index and proves the
; minor's cost flat in the live set.
(test (charm? (clock 0)) (0 <= nclock (nclock 0)) (16 = tally (gauge 0)))
(: c1 (please ()) c2 (please 1)                  ; the sequence law orders the two asks
 (test (c1 < c2)))

; (tune v) is gauge's write twin -- the four live GC knobs as a list, in words:
; [0] budget (total footprint cap, 2*minor + 2*major; 0 = unbounded -- appel's rule gives the
; nursery what is left after the major pool) [1] minor0 (the nursery floor) [2] major0 (the
; major pool's grow/shrink step) [3] ratio (the copy-overhead setpoint). (tune ()) reads; a
; list of four writes and answers what it replaced, so a probe restores with one call. a knob lands
; at the next collection. a wrong shape is a silent no-op answering the current knobs (pin's
; misuse convention), so a refused write is readable as "nothing moved".
(: k0 (tune ())                                  ; whatever this seat booted with
   old (tune [2097152 32768 131072 16])
   now (tune ())
   bad (tune 'nonsense)                          ; refused: not a list of four
   back (tune k0)                                ; ..and put the seat back for the rest of the corpus
 (test (4 = tally k0) (two? k0)
         (k0 = old)                              ; a write answers what it replaced
         (2097152 = peep now 0 0) (16 = peep now 3 0)
         (now = bad)                             ; a refused shape wrote nothing
         (now = back) (k0 = (tune ()))
         (now @ (2097152 . _ . _ . r . _) (16 = r) 0)       ; a list, so @ reads it
         (gauge 0 @ (_ . _ . _ . n . _) (charm? n) 0)))
