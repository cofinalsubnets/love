; test/bell.l -- Bell numbers in base 36, one per line, while the rendering stays <= 280
; chars, built from memoized binomials:
;     B(n) = sum_{k<n} C(n-1,k) * B(k)      (B(0)=B(1)=1)
;     C(n,k) = n! / (k! (n-k)!)
; it leans on the bignum tower: the last lines are 280-digit base-36 numbers. the 291 lines
; are held as one sha256 per block of 32, so a red names the block that drifted.

(borrow 'hashes)
(: facts {} bells {} digits "0123456789abcdefghijklmnopqrstuvwxyz"
   (digit d) (snip digits d (d + 1))
   (choose n k) (fact n / (fact k * fact (n - k)))
   (fact n) (:
    (f n x) (n < 2 ? x (f (n - 1) (x * n)))
    v (facts n)
    (v ? v (f n 1 @ v (pin facts n v, v))))
   (bell n) (:
    (f n k x) (k >= n ? x (f n (k + 1) (x + (choose (n - 1) k * bell k))))
    v (bells n)
    (v ? v ((n < 2 ? 1 (f n 0 0)) @ v (pin bells n v, v))))
   (showloop acc n) (n < 1 ? acc (showloop (digit (n % tally digits) + acc)(n // tally digits) ))
   show (showloop "")
   (gen i limit) (show (bell i) @ b (#b <= limit ? (b . gen (i + 1) limit)))
   out (gen 0 280)
   (bell-skip l n) (n < 1 || atom? l ? l (bell-skip >l (n - 1)))
   (bell-h j) (sha256 (join "\n" (take 32 (bell-skip out (32 * j)))))
 (test
  ; the Bell numbers themselves, decimal, as oeis a000110 has them
  (1 = bell 0) (1 = bell 1) (2 = bell 2) (5 = bell 3) (15 = bell 4) (52 = bell 5)
  (203 = bell 6) (877 = bell 7) (4140 = bell 8) (21147 = bell 9) (115975 = bell 10)
  (678570 = bell 11) (4213597 = bell 12) (27644437 = bell 13) (190899322 = bell 14)
  (1382958545 = bell 15) (10480142147 = bell 16) (82864869804 = bell 17)
  (682076806159 = bell 18) (5832742205057 = bell 19) (51724158235372 = bell 20)
  (474869816156751 = bell 21) (4506715738447323 = bell 22) (44152005855084346 = bell 23)
  (445958869294805289 = bell 24) (4638590332229999353 = bell 25)
  ; base-36 rendering of known values
  ("" = show 0) ("1" = show 1) ("f" = show 15) ("z" = show 35)
  ("10" = show 36) ("zz" = show 1295)
  ; all 291 lines, B(0..290) in base 36, a block of 32 at a time
  (291 = tally out)
  (bell-h 0 = "d6902ac68bd1300e6318c4d25cd57aa39843293cf195a699864d9962ffc17d50")
  (bell-h 1 = "697774a0fb1735700637b304e9df485adc3444f97c877344977082966c3c89c6")
  (bell-h 2 = "0e2fa78bd8d449c7486bda4d83dbd6599a56e43f72173779efa6e63de6306e17")
  (bell-h 3 = "259f06d7e6a115e98cf88d29a7afff626a6d9bcbf60951084e67a09d89f63e15")
  (bell-h 4 = "46b8c37c85f7172aa8bb60a512199ba5815223da09d75c717b64de4da89449fa")
  (bell-h 5 = "6146ad88121eddc686062ff61d60e765ef38bf10b97eb2b232f71d8dd56ba866")
  (bell-h 6 = "5bb64950c6f60316cb67ad067f3a2fa0786905b81471953044364112157f8ccf")
  (bell-h 7 = "ee0495fc95f5a77a5cfe458d7836d9b38d340dd845444d04234a44983495ba00")
  (bell-h 8 = "74132e14055de9e2e480f3c8710b610548173f1f45ae3763c6e80c38ca528763")
  (bell-h 9 = "e0539f5374482e4dea19695e581ebf372ded8e97ec8c7c1e7a7802653a6b4778")))
