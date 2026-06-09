;;; mandelbrot escape counts over a 64x64 grid (see bench/benches/float.l).
;;; double-float literals (d0) so the arithmetic matches the other languages.
(load "lib/bench.lisp")
(defun mand (cx cy)
  (let ((zx 0.0d0) (zy 0.0d0) (it 0))
    (loop while (and (< it 100) (<= (+ (* zx zx) (* zy zy)) 4.0d0)) do
      (let ((nzx (+ (- (* zx zx) (* zy zy)) cx))
            (nzy (+ (* (* 2.0d0 zx) zy) cy)))
        (setf zx nzx zy nzy it (+ it 1))))
    it))
(defun work ()
  (let ((s 0))
    (dotimes (px 64)
      (dotimes (py 64)
        (incf s (mand (+ -2.0d0 (* px 0.046875d0)) (+ -1.5d0 (* py 0.046875d0))))))
    s))
(bench "float" (lambda () (work)))
