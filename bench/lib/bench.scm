;;; guile benchmark harness -- mirrors bench/bench.l.
;;; (bench name work) auto-scales the repetition count (doubling until the run
;;; clears bench-min-ms), then prints one line matching the other harnesses:
;;;     <name> <lang> <reps> <ms> <checksum>
;;; work is a nullary thunk returning a deterministic checksum. label from
;;; BENCH_LANG (default "guile").
(define bench-min-ms 200)
(define bench-lang (or (getenv "BENCH_LANG") "guile"))
(define (sum-list l) (let lp ((l l) (a 0)) (if (null? l) a (lp (cdr l) (+ a (car l))))))
(define (bench name work)
  (let loop ((reps 1))
    (let* ((t0 (get-internal-real-time))
           (chk (let rep ((i 0) (c #f)) (if (< i reps) (rep (+ i 1) (work)) c)))
           (ms (/ (* 1000.0 (- (get-internal-real-time) t0))
                  internal-time-units-per-second)))
      (if (>= ms bench-min-ms)
          (begin (simple-format #t "~a ~a ~a ~a ~a\n" name bench-lang reps ms chk)
                 (force-output))
          (loop (* 2 reps))))))
