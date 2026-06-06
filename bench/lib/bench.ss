; chez scheme benchmark harness -- mirrors bench/bench.g.
; (bench name work) auto-scales the repetition count (doubling until the run
; clears min-ms), then prints one line matching the other harnesses:
;     <name> chez <reps> <ms> <checksum>
; work is a nullary thunk returning a deterministic checksum.
(define bench-min-ms 200)

(define (bench name work)
  (let loop ((reps 1))
    (let* ((t0 (real-time))
           (chk (let rep ((i 0) (c #f)) (if (< i reps) (rep (+ i 1) (work)) c)))
           (ms (- (real-time) t0)))
      (if (>= ms bench-min-ms)
          (begin (printf "~a chez ~a ~a ~a\n" name reps ms chk)
                 (flush-output-port))
          (loop (* 2 reps))))))
