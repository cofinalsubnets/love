(: fin (sym ())
   (li k x) (? (= fin x) (k ()) (li (\ z (k (cons x z)))))
   lis (li id)
   (assert (= '(1 2 3 4 5) (lis 1 2 3 4 5 fin))))
