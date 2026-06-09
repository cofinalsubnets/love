;;; closure / higher-order stress (see bench/benches/closure.l). checksum = sum 3i.
(load "lib/bench.lisp")
(defparameter *n* 100000)
(defun twice (f) (lambda (x) (funcall f (funcall f x))))
(defun adder (i) (lambda (x) (+ x i)))
(bench "closure"
  (lambda ()
    (let ((s 0))
      (dotimes (i *n*) (incf s (funcall (twice (adder i)) i)))
      s)))
