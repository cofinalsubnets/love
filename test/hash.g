; hasht constructor (nested `put`) + #(…) printer/reader form
(: t (hasht 1 100 2 200 3 300))
(assert
 ; the constructor builds a working hash
 (hashp t)
 (= 100 (get 0 1 t))
 (= 200 (get 0 2 t))
 (= 300 (get 0 3 t))
 (= 0 (get 0 9 t))                              ; missing key -> default
 (= 3 (foldl (\ n _ (+ 1 n)) 0 (hashk t)))      ; three entries
 ; empty + single-entry printer forms are deterministic (no bucket-order dependence)
 (= "#()" (inspect (hashn 0)))
 (= "#(1 100)" (inspect (hasht 1 100)))
 (= "#(1 \"hi\")" (inspect (hasht 1 "hi")))
 (strp (inspect t))                             ; multi-entry: just exercise the path
 ; (hash x) exposes the runtime hashing method: a fixnum, equal for eql keys
 (nump (hash 'k))
 (= (hash 'k) (hash 'k))
 (= (hash '(1 2)) (hash '(1 2))))

; #(…) reader macro: splices a list operand into (hasht …), wraps an atom as (hasht x),
; and #() builds a fresh empty hash. Hashes print as #(…), round-tripping via #.
(: ht #(1 100 2 200 3 300))
(assert
 (hashp ht)
 (= 100 (get 0 1 ht))
 (= 300 (get 0 3 ht))
 (hashp #())                                     ; #() -> empty hash
 (= 50 (get 0 5 (put 5 50 #())))                ; the empty hash is mutable
 (= 3 (foldl (\ n _ (+ 1 n)) 0 (hashk #(1 10 2 20 3 30))))   ; splice builds all entries
 (= "#()" (inspect #()))
 (= "#(1 \"hi\")" (inspect #(1 "hi"))))
