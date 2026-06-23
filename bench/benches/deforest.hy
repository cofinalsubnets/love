;; map/filter/fold list pipeline: sum the squares of the odd numbers in [0, N).
;; the lazy range + map/filter iterators run INSIDE the timed work. checksum = 1333333330000.
(import sys)
(sys.path.insert 0 "lib")
(import bench [bench])
(defn work [] (sum (map (fn [x] (* x x)) (filter (fn [x] (= (% x 2) 1)) (range 20000)))))
(bench "deforest" work)
