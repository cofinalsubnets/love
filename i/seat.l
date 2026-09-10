; i/seat.l -- the laws a love-running seat checks before it trusts its image.
;
; the seats paste this in EXPRESSION position: u/lcat.l lays it as one C string
; literal (b/lib/seat.h) and each seat's main.c splices that into its driver tail.
; so it stays ONE top-level form answering a BOOLEAN -- an `assert` here would answer
; 0 and scare, where a seat wants a verdict to hand its exit nif (42 held, 1 did not).
;
; four of the five are corpus laws already (t/spec.l, t/valence.l). the fifth is
; the seat's own question: `lit? ev` asks whether the egg hatched into the self-hosted
; evaluator rather than leaving the C one standing -- which only a seat that has just
; baked, with no filesystem under it and no module read, is in a position to answer.

(&& ((3 2) = 8)                           ; application as power
 (&& ('(2 3 4) = (map (+ 1) '(1 2 3)))    ; currying through map
 (&& (6 = $'(1 2 3))                      ; $ GLUED: spaced it is the apply operator
 (&& (lit? ev)                            ; the hatched ev, not c0's nif
     ((2 3 4) = 262144)))))               ; the tower
