;; binary-trees allocation/GC stress (see bench/benches/tree.l). checksum = 2^D-1.
(set package.path (.. "lib/?.lua;" package.path))
(local bench (require :bench))
(fn mk [d] (if (= d 0) nil [(mk (- d 1)) (mk (- d 1))]))
(fn ck [t] (if (= t nil) 0 (+ 1 (ck (. t 1)) (ck (. t 2)))))
(bench "tree" (fn [] (ck (mk 16))))
