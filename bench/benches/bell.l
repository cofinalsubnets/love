; bell numbers in base 36, one per line while a line stays <= 280 chars (a port of test/bell.l):
;     B(n) = sum_{k<n} C(n-1,k) B(k),  C(n,k) = n!/(k!(n-k)!)
; a bignum stress: the values pass 64 bits almost at once. fresh memo tablets per rep, so every
; rep recomputes. checksum = total characters across all lines.
(: (bell-run limit)
    (: miss (nom 0)  facts {}  bells {}
       digits "0123456789abcdefghijklmnopqrstuvwxyz"  base #digits
       (factloop n acc) (n < 2 ? acc (factloop (n - 1) (acc * n)))
       (fact n)  (: v (peep facts n miss) (v = miss ? (: r (factloop n 1) _ (pin facts n r) r) v))
       (choose n k) (fact n / (fact k * fact (n - k)))
       (bellsum n k acc) (k < n ? (bellsum n (k + 1) (acc + choose (n - 1) k * bell k)) acc)
       (bell n) (: v (peep bells n miss) (v = miss ? (: r (n < 2 ? 1 (bellsum n 0 0)) _ (pin bells n r) r) v))
       (showloop n acc) (n < 1 ? acc (showloop (n // base) (snip digits (n % base) (1 + n % base) + acc)))
       (show n) (showloop n "")
       (gen i acc) (: b (show (bell i)) (#b <= limit ? (gen (i + 1) (acc + #b)) acc))
     (gen 0 0))
 (bench "bell" (_ \ bell-run 280)))
