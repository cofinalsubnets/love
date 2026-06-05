; tbl constructor (nested `put`) + ,(tbl …) printer form
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
 (= ",(tbl)" (inspect (new 0)))
 (= ",(tbl 1 100)" (inspect (tbl 1 100)))
 (= ",(tbl 1 \"hi\")" (inspect (tbl 1 "hi")))
 (strp (inspect t)))                            ; multi-entry: just exercise the path
