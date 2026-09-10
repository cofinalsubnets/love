(: fin (nom 0)
   (li k x) (? (= fin x) (k ()) (li (\ z (k (. x z)))))
   lis (li id)
   (test (= '(1 2 3 4 5) (lis 1 2 3 4 5 fin))))
