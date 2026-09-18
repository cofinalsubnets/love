; chez scheme benchmark harness -- mirrors bench/bench.l.
; (bench name work) auto-scales the repetition count (doubling until the run
; clears min-ms), then times that count ONCE MORE and reports the second run --
; the scaling runs pay the fixed per-process costs (JIT warm-up, the heap's first
; growth), which otherwise ride on whichever power of two the doubling landed on.
; one line per bench, matching the other harnesses:
;     <name> <lang> <reps> <ms> <checksum>
; work is a nullary thunk returning a deterministic checksum. the language label
; comes from BENCH_LANG (so chez and petite can share these files), default "chez".
(define bench-min-ms 200)
(define bench-lang (or (getenv "BENCH_LANG") "chez"))

(define (bench-run work reps)            ; -> (values ms chk)
  (let* ((t0 (real-time))
         (chk (let rep ((i 0) (c #f)) (if (< i reps) (rep (+ i 1) (work)) c))))
    (values (- (real-time) t0) chk)))

(define (bench name work)
  (let loop ((reps 1))
    (let-values (((ms chk) (bench-run work reps)))
      (if (>= ms bench-min-ms)
          (let-values (((ms chk) (bench-run work reps)))    ; warm
            (printf "~a ~a ~a ~a ~a\n" name bench-lang reps ms chk)
            (flush-output-port))
          (loop (* 2 reps))))))
