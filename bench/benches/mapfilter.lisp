;;; list pipeline: square every element, keep the even results, sum them.
(load "lib/bench.lisp")
(defparameter *data* (loop for i from 0 below 10000 collect i))
(bench "mapfilter"
       (lambda () (reduce #'+ (remove-if-not #'evenp (mapcar (lambda (x) (* x x)) *data*)))))
