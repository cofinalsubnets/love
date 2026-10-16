; hash constructor (nested `put`) + {…} printer/reader form
(: t (hash 1 100 2 200 3 300))
(test
 ; the constructor builds a working hash
 (tablet? t) !(tablet? '(1 2))         ; tablet?: only maps, not lists
 (lit? t) (lit? cap) !(lit? 5) !(lit? 0)    ; lit?: any heap object, not a fixnum/nil
 (100 = peep t 1 0)
 (200 = peep t 2 0)
 (300 = peep t 3 0)
 (0 = peep t 9 0)                       ; missing key -> default
 (3 = foldl (n \ _ \ 1 + n) 0 (keys t)) ; three entries
 ; empty + single-entry printer forms are deterministic (no bucket-order dependence)
 ("{}" = show {})
 ("{1 100}" = show (hash 1 100))
 ("{1 \"hi\"}" = show (hash 1 "hi"))
 (string? (show t))                             ; multi-entry: just exercise the path
 ; (dig x) exposes the runtime hashing method: a fixnum, equal for eql keys
 (charm? (dig 'k))
 (dig '(1 2) = dig '(1 2))
 ; a quote body inside a lambda leaf must not hide the elements beside it from the digest
 !(dig [1 (a \ (\ 5)) 2] = dig [3 (a \ (\ 5)) 2]))

; {…} splices a list operand into (hash …); {} is the empty map
(: ht {1 100 2 200 3 300})
(test
 (tablet? ht)
 (100 = peep ht 1 0)
 (300 = peep ht 3 0)
 (3 = foldl (n \ _ \ 1 + n) 0 (keys {1 10 2 20 3 30})) ; splice builds all entries
 ("{1 \"hi\"}" = show {1 "hi"}))

; a brace over a non-list datum boxes it: {x} = {() x}, one entry at (), not {}
(: bx {0})
(test
 (9 = peep bx 0 9)                           ; key 0 is a miss: the box sits at ()
 (5 = peep {5} () 0) ("s" = peep {"s"} () 0) ; any scalar boxes (at the unit)
 ('a = peep {'a} () 0)                       ; a quote form is a chain, and the brace still boxes it
 ("{() 5}" = show {5})                       ; a box prints as {() v}, reads back
 (7 = peep {1 2 7} () 0)                     ; an odd trailing operand lands in the box slot (the unit key)
 (2 = peep {1 2 7} 1 0))
