; closure / higher-order stress (see bench/benches/closure.l): closures escape into a vector,
; then applied through it (non-inlinable). checksum = sum 3i.
(load "lib/bench.ss")
(define N 100000)
(define (twice f) (lambda (x) (f (f x))))
(define (adder i) (lambda (x) (+ x i)))
(bench "closure"
  (lambda ()
    (let ((fns (make-vector N)))
      (let loop ((i 0)) (when (< i N) (vector-set! fns i (twice (adder i))) (loop (+ i 1))))
      (let loop ((i 0) (s 0))
        (if (< i N) (loop (+ i 1) (+ s ((vector-ref fns i) i))) s)))))
