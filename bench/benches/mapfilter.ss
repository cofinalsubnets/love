; list pipeline: square every element, keep the even results, sum them.
(load "lib/bench.ss")
(define data (let loop ((i 9999) (a '())) (if (< i 0) a (loop (- i 1) (cons i a)))))
(define (sq x) (* x x))
(bench "mapfilter" (lambda () (fold-left + 0 (filter even? (map sq data)))))
