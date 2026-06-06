;;; reverse a 20000-element list each iteration; checksum = new head = 19999.
(load "lib/bench.lisp")
(defparameter *data* (loop for i from 0 below 20000 collect i))
(bench "reverse" (lambda () (first (reverse *data*))))
