; Mutable hash-table throughput. Into a fresh table, insert N integer keys
; (sparse: stride 97, so they hash instead of hitting any int/array fast path),
; then a sum-lookup pass, a read-modify-write update pass, and a second
; sum-lookup. checksum = N*N (sum of i, then sum of i+1, over 0..N-1). ported to
; every dialect with mutable hash tables; the purely functional ones (owl,
; elixir) and chicken (no hashtable egg) simply have no file and drop out.
(: (hash-run n)
    (: h (hashn 0)
       (ins i)      (? (< i n) (: _ (put (+ 1 (* 97 i)) i h) (ins (+ i 1))) h)
       (scan i acc) (? (< i n) (scan (+ i 1) (+ acc (get 0 (+ 1 (* 97 i)) h))) acc)
       (bump i)     (? (< i n) (: k (+ 1 (* 97 i)) _ (put k (+ 1 (get 0 k h)) h) (bump (+ i 1))) h)
       _  (ins 0)
       a  (scan 0 0)
       __ (bump 0)
     (+ a (scan 0 0)))
 (bench "hash" (\ _ (hash-run 10000))))
