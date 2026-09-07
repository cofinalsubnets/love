; sortby -- the higher-order sort: N (key . idx) records ordered by a USER comparator on a
; derived key (key % 4096, then key), checksum the rolling hash of the idx sequence. `sort` is the
; universal fixnum case any runtime may fast-path; this one has to call back per comparison.
(: (lcg x)       (% (* 16807 x) 2147483647)
   (genr x i n)  (? (< i n) (: nx (lcg x) ((nx . i) . (genr nx (+ i 1) n))) 0)
   (less a b)    (: ka (cap a) kb (cap b) ma (% ka 4096) mb (% kb 4096)
                    (? (< ma mb) 1 (= ma mb) (< ka kb) 0))
   (hsh acc l)   (? (atom? l) acc (hsh (% (+ (* acc 31) (cup (cap l))) 1000000007) (cup l)))
   (sortby-run n) (hsh 0 (sortby less (genr 1 0 n)))
 (bench "sortby" (\ _ (sortby-run 5000))))
