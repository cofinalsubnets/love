; strcat: build an N-char string by repeated single-char concatenation (O(n^2), a fresh string per
; step), then fold a polynomial rolling hash over it. the hash is mod a prime so it stays < 2^31 and
; every language, lua included, agrees on the checksum.
(: hmod 1000000007
   (strhash s) (: n #s
     (go i h) (i < n ? (go (i + 1) ((h * 31 + peep s i 0) % hmod)) h) (go 0 0))
   (strbuild n) (: (go i s) (i < n ? (go (i + 1) (s + string (48 + i % 10))) s) (go 0 ""))
   strcat-n 4000
 (bench "strcat" (_ \ strhash (strbuild strcat-n))))
