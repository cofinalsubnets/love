;;; sortby: N (key . idx) records ordered by a user comparator on a derived key (key%4096, then key);
;;; checksum = rolling hash of the idx sequence.
(load "lib/bench.lisp")
(defparameter *n* 5000)
(defun gen (n)
  (let ((x 1) (acc '()))
    (dotimes (i n) (setf x (mod (* 16807 x) 2147483647)) (push (cons x i) acc))
    (nreverse acc)))
(defun less (a b)
  (let ((ma (mod (car a) 4096)) (mb (mod (car b) 4096)))
    (or (< ma mb) (and (= ma mb) (< (car a) (car b))))))
(defun hsh (l)
  (let ((h 0)) (dolist (r l) (setf h (mod (+ (* h 31) (cdr r)) 1000000007))) h))
(bench "sortby" (lambda () (hsh (sort (gen *n*) #'less))))
