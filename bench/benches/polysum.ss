; map/filter/fold list pipeline: sum the squares of the odd numbers in [0, N).
; the range + intermediate lists are built INSIDE the timed work (the allocation
; ai's deforestation fuses away). checksum = 1333333330000.
(load "lib/bench.ss")
(define (sq x) (* x x))
(bench "polysum" (lambda ()
  (fold-left + 0 (map sq (filter odd?
    (let loop ((i 19999) (a '())) (if (< i 0) a (loop (- i 1) (cons i a)))))))))
