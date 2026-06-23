;;; map/filter/fold list pipeline: sum the squares of the odd numbers in [0, N).
;;; the range + intermediate lists are built INSIDE the timed work. checksum = 1333333330000.
(load "lib/bench.lisp")
(bench "deforest"
       (lambda () (reduce #'+ (mapcar (lambda (x) (* x x))
                                      (remove-if-not #'oddp (loop for i from 0 below 20000 collect i))))))
