#lang racket/base
;;; racket benchmark harness -- mirrors bench/bench.l. one line out:
;;;     <name> <lang> <reps> <ms> <checksum>          label from BENCH_LANG.
(provide bench sum-list)
(define bench-min-ms 200)
(define bench-lang (or (getenv "BENCH_LANG") "racket"))
(define (sum-list l) (let lp ([l l] [a 0]) (if (null? l) a (lp (cdr l) (+ a (car l))))))
(define (bench name work)
  (let loop ([reps 1])
    (define t0 (current-inexact-milliseconds))
    (define chk (let rep ([i 0] [c #f]) (if (< i reps) (rep (+ i 1) (work)) c)))
    (define ms (- (current-inexact-milliseconds) t0))
    (if (>= ms bench-min-ms)
        (begin (printf "~a ~a ~a ~a ~a\n" name bench-lang reps ms chk) (flush-output))
        (loop (* 2 reps)))))
