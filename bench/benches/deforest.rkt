#lang racket/base
;; map/filter/fold list pipeline: sum the squares of the odd numbers in [0, N).
;; the range + intermediate lists are built INSIDE the timed work. checksum = 1333333330000.
(require "../lib/bench.rkt")
(define (sq x) (* x x))
(bench "deforest" (lambda ()
  (sum-list (map sq (filter odd?
    (let loop ([i 19999] [a '()]) (if (< i 0) a (loop (- i 1) (cons i a)))))))))
