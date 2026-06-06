; tbl constructor (nested `put`) + #(…) printer/reader form
(: t (tbl 1 100 2 200 3 300))
(assert
 ; the constructor builds a working table
 (tblp t)
 (= 100 (get 0 1 t))
 (= 200 (get 0 2 t))
 (= 300 (get 0 3 t))
 (= 0 (get 0 9 t))                              ; missing key -> default
 (= 3 (foldl (\ n _ (+ 1 n)) 0 (tkeys t)))      ; three entries
 ; empty + single-entry printer forms are deterministic (no bucket-order dependence)
 (= "#()" (inspect (new 0)))
 (= "#(1 100)" (inspect (tbl 1 100)))
 (= "#(1 \"hi\")" (inspect (tbl 1 "hi")))
 (strp (inspect t)))                            ; multi-entry: just exercise the path

; #(…) reader macro: splices a list operand into (tbl …), wraps an atom as (tbl x),
; and #() builds a fresh empty table. Tables print as #(…), round-tripping via #.
(: ht #(1 100 2 200 3 300))
(assert
 (tblp ht)
 (= 100 (get 0 1 ht))
 (= 300 (get 0 3 ht))
 (tblp #())                                     ; #() -> empty table
 (= 50 (get 0 5 (put 5 50 #())))                ; the empty table is mutable
 (= 3 (foldl (\ n _ (+ 1 n)) 0 (tkeys #(1 10 2 20 3 30))))   ; splice builds all entries
 (= "#()" (inspect #()))
 (= "#(1 \"hi\")" (inspect #(1 "hi"))))
