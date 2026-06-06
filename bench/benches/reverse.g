; reverse a 20000-element list each iteration (rev = foldl of flip cons).
; checksum = head of the reversed list = 19999.
(: data (iota 20000)
 (bench "reverse" (\ _ (car (rev data)))))
