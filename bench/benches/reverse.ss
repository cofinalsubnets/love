; reverse a 20000-element list each iteration; checksum = new head = 19999.
(load "lib/bench.ss")
(define data (let loop ((i 19999) (a '())) (if (< i 0) a (loop (- i 1) (cons i a)))))
(bench "reverse" (lambda () (car (reverse data))))
