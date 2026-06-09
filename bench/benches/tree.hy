;; binary-trees allocation/GC stress (see bench/benches/tree.l). checksum = 2^D-1.
(import sys)
(sys.path.insert 0 "lib")
(import bench [bench])
(defn mk [d] (if (= d 0) None [(mk (- d 1)) (mk (- d 1))]))
(defn ck [t] (if (is t None) 0 (+ 1 (ck (get t 0)) (ck (get t 1)))))
(bench "tree" (fn [] (ck (mk 16))))
