; mutable hash-table throughput. into a fresh table insert N integer keys (stride 97, so they hash
; rather than hit an int/array fast path), then a sum-lookup pass, a read-modify-write pass, and a
; second sum-lookup. checksum = N*N. dialects without mutable hash tables have no file.
(: (hash-run n)
    (: h {}
       (ins i)      (i < n ? (pin h (1 + 97 * i) i, ins (i + 1)) h)
       (scan i acc) (i < n ? (scan (i + 1) (acc + peep h (1 + 97 * i) 0)) acc)
       (bump i)     (i < n ? (: k (1 + 97 * i) _ (pin h k (1 + peep h k 0)) (bump (i + 1))) h)
       _  (ins 0)
       a  (scan 0 0)
       __ (bump 0)
     (a + scan 0 0))
 (bench "hash" (_ \ hash-run 10000)))
