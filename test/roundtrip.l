; Closed-loop round trip: feed the printer's OUTPUT back through the reader (and
; evaluator), rather than checking print-string and read-literal separately.
;   rd: value -> inspect (print) -> read         (datum round-trip)
;   rt: value -> inspect (print) -> read -> eval  (value round-trip)
; Datums (symbols, lists, atoms) print as their literal form, so they re-READ
; equal but would re-EVAL as code -- those use rd. Self-evaluating atoms and the
; `,`-prefixed value forms (tuple/arr/hash/functions, read back via uq=identity)
; and the complex form ~(re im)
; reconstruct the value under eval -- those use rt.
; s2cl turns a string into a charlist of byte codes (get is generic over strings).
(: (s2cl s) ((: (g i) (? (< i (hash s)) (X (peek s i 0) (g (+ 1 i))))) 0)
   (rdr s) (fread (strin (s2cl s)) (nom 0))
   (rd x) (rdr (inspect x))
   (rt x) (ev (rdr (inspect x))))
(assert
 ; --- datum round-trip (print -> read): the printed form re-reads equal ---
 (= 42 (rd 42))
 (= -7 (rd -7))
 (= 'foo (rd 'foo))
 (= "hi\n" (rd "hi\n"))
 (= '(a (b c) d) (rd '(a (b c) d)))
 (= ''x (rd ''x))                                   ; quote sugar 'x survives the loop
 ; --- value round-trip (print -> read -> eval) ---
 ; self-evaluating atoms
 (= 42 (rt 42))
 (= "hi\n" (rt "hi\n"))
 ; ,-prefixed constructor forms reconstruct an equal value
 (aall (= (tuple 1 2 3) (rt (tuple 1 2 3))))
 (aall (= (arrl i8 '(2 2) '(1 2 3 4)) (rt (arrl i8 '(2 2) '(1 2 3 4)))))
 (aall (= (arrl f64 '(2) '(1.5 2.5)) (rt (arrl f64 '(2) '(1.5 2.5)))))
 (= ~(2 -3) (rt ~(2 -3)))
 ; complex arrays round-trip: rank-1 via @((C…)…)->tuple, rank>=2 via (array…) (ca-* from complex.l)
 (aall (= ca-v (rt ca-v)))
 (aall (= ca-m (rt ca-m)))
 (= 100 (peek (rt (map 1 100 2 200)) 1 0))
 (= 200 (peek (rt (map 1 100 2 200)) 2 0))
 ; functions reconstruct a working function
 (= 3 ((rt +) 1 2))                                 ; builtin
 (= 5 ((rt (\ x (+ x 1))) 4))                       ; lambda
 (= 7 ((rt (+ 3)) 4))                               ; partial application of a builtin
 (= 3 ((rt ((\ a b (+ a b)) 1)) 2))                 ; partial app of a lambda (no capture)
 ; a closure (captures free var y) round-trips: the captured value is printed as a
 ; leading param, so re-applying the reconstructed base to it rebinds correctly.
 (= 9 (: y 5 ((rt (\ x (+ x y))) 4)))               ; (rt closure) is base needing x; apply 4
 (= 30 (: a 10 b 20 ((rt (\ z (+ z (+ a b)))) 0)))  ; two captured vars
 ; the lambda's source survives the loop (idempotent inspect)
 (= (inspect (\ a b (+ a b))) (inspect (rt (\ a b (+ a b))))))
