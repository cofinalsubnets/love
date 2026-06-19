; the VALENCE LAW: a glued operator run is MONADIC -- the reader emits
; (mono (run datum)) and opfix factors the run against bag['monadics]
; (then the operators table at one, so live pins keep the dynamic lane).
; spaced, a run keeps its dyadic/infix life. HEAD POSITION NEVER FUSES:
; a run right after an open delimiter is the form's operator -- the
; section/escape law, and what keeps minified source legal. the words
; behind the sigils: < cap, > cup (<< >> <> >< the compounds), + net,
; * prod, | abs, - neg, / reciprocal, % frac, ? bit; $ ! . ride the same lane.
(assert
 ; cap and cup, and the compounds by greedy monadic factorization
 (1 = <'(1 2 3)) ('(2 3) = >'(1 2 3))
 (2 = <>'(1 2 3)) ('(3) = >>'(1 2 3))
 (9 = <<'((9 8) 2)) ('(2) = ><'((1 2) 9))
 ; the content measure and its product twin, + and * turned inward
 (6 = +'(1 2 3)) (294 = +"abc") (0 = +"") (7 = +@(3 4))
 (-1 = +'(-2 1))                                ; the net, UNCLAMPED: $ would read 0
 (~(0 8) = +(L ~(3 4) ~(-3 4)))                 ; phases sum as vectors
 (24 = *'(1 2 3 4)) (7 = *7) (6 = *@(1 2 3))
 ; the dyadics turned inward
 (5 = |-5) (5.0 = |~(3 4)) (-3 = -(1 + 2)) (0.25 = /4) (0.5 = %2.5)
 ; the truth panel: the bit is the Iverson bracket
 (1 = ?7) (0 = ?0) (0 = ?"") (0 = !7) (1 = !!7)
 ; glued monadics compose with infix; spaced runs keep their dyadic life
 (15 = (5 + <'(10 20))) (197 = ($"ab" + 2))
 (3 = (1 + 2)) (2 = (5 - 3)) (8 = (5 - -3))
 ; head position: the call, the section, the curry law -- never fused
 (3 = (+ 1 2)) (3 = ((1 +) 2)) (1 = ((< 5) 9)) (6 = (foldl (+) 0 '(1 2 3)))
 ; the data lane: a glued run READS as the mono node, and round-trips
 ('(f (mono (< x))) = (read (tap '(40 102 32 60 120 41)) 99))
 ; the words are real, the sigils their spellings
 (-7 = (neg 7)) (0.5 = (reciprocal 2)) (0.25 = (frac 5.25)) (1 = (bit 9))
 (6 = (net '(1 2 3))) (24 = (prod '(2 3 4))) (id? 'cap (monadics '<)))

; COHERENCE: the new words against the old laws, pinned as one system.
; $ is the clamp of the net (the word now states the law the sigil lived);
; the bit is !! is the sign of the same measure; the monadic words ARE their
; sections; net meets net on arrays and the fold on spines; prod twins
; prod; jot counts what it jots.
(assert
 (0 = $(net '(-2 1))) (-1 = (net '(-2 1)))      ; the net unclamped, $ its one clamp
 (all (\ v ($v = $(net v))) (L 7 -5 '(1 -5) @(2 3) "ab" ~(0 2) #(1 10)))
 (all (\ v ((bit v) = !!v)) (L 7 0 -3 "" "a" '(0) ~(0 2)))
 (neg = (- 0)) (reciprocal = (/ 1))                  ; the words ARE the sections
 ((net @(1 2 3)) = (net @(1 2 3))) ((net @(1 2 3)) = (net '(1 2 3)))
 ((net '(1 2 3)) = (foldl (+) 0 '(1 2 3)))
 ((prod '(2 3 4)) = (prod @(2 3 4))) (24 = (prod '(2 3 4)))
 (5 = (tally (jot 5))) (10 = +(jot 5))          ; jot counts what it jots; gauss agrees
 ((frac 5.25) = (5.25 % 1)) ((bit 9) = !!9) (!!9 = ?9))
