;; Bell numbers in base 36 (see bench/benches/bell.l) -- a bignum-tower stress.
(import sys)
(sys.path.insert 0 "lib")
(import bench [bench])
(setv DIGITS "0123456789abcdefghijklmnopqrstuvwxyz")
(setv BASE (len DIGITS))
(defn bell-run [limit]
  (setv facts {} bells {})
  (defn fact [n]
    (when (in n facts) (return (get facts n)))
    (setv x 1 m n)
    (while (> m 1) (setv x (* x m)) (setv m (- m 1)))
    (setv (get facts n) x)
    x)
  (defn choose [n k] (// (fact n) (* (fact k) (fact (- n k)))))
  (defn bell [n]
    (when (in n bells) (return (get bells n)))
    (setv r (if (< n 2) 1 (sum (lfor k (range n) (* (choose (- n 1) k) (bell k))))))
    (setv (get bells n) r)
    r)
  (defn show [n]
    (setv s "")
    (while (> n 0)
      (setv s (+ (get DIGITS (% n BASE)) s))
      (setv n (// n BASE)))
    s)
  (setv total 0 i 0)
  (while True
    (setv b (show (bell i)))
    (when (> (len b) limit) (return total))
    (setv total (+ total (len b)))
    (setv i (+ i 1))))
(bench "bell" (fn [] (bell-run 280)))
