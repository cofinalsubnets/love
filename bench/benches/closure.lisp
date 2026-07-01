(load "lib/bench.lisp")
;; closures escape into an array, then applied through it (non-inlinable). checksum = sum 3i.
(defparameter *n* 100000)
(defun twice (f) (lambda (x) (funcall f (funcall f x))))
(defun adder (i) (lambda (x) (+ x i)))
(bench "closure"
  (lambda ()
    (let ((fns (make-array *n*)))
      (dotimes (i *n*) (setf (aref fns i) (twice (adder i))))
      (let ((s 0))
        (dotimes (i *n*) (incf s (funcall (aref fns i) i)))
        s))))
