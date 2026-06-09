;;; chicken benchmark harness -- mirrors bench/bench.l.
;;; (current-process-milliseconds) is integer ms. csi has no srfi-1/hashtables
;;; without eggs, so this provides `keep` (filter) and benches memoize via
;;; vectors. one line out: <name> <lang> <reps> <ms> <checksum>.
(import (chicken time) (chicken process-context))
(define bench-min-ms 200)
(define bench-lang "chicken")
(define (sum-list l) (let lp ((l l) (a 0)) (if (null? l) a (lp (cdr l) (+ a (car l))))))
(define (keep p l)
  (cond ((null? l) '()) ((p (car l)) (cons (car l) (keep p (cdr l)))) (else (keep p (cdr l)))))
(define (bench name work)
  (let loop ((reps 1))
    (let* ((t0 (current-process-milliseconds))
           (chk (let rep ((i 0) (c #f)) (if (< i reps) (rep (+ i 1) (work)) c)))
           (ms (- (current-process-milliseconds) t0)))
      (if (>= ms bench-min-ms)
          (begin (display name) (display " ") (display bench-lang) (display " ")
                 (display reps) (display " ") (display ms) (display " ")
                 (display chk) (newline))
          (loop (* 2 reps))))))
