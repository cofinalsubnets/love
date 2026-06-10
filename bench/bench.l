; l benchmark harness -- shared timing, reporting and list helpers.
; concatenated ahead of each bench/benches/*.g file by bench/Makefile, so the
; bindings below leak into global scope (a top-level `:` with no trailing body
; defines globals). every bench file ends in one (bench name work) call.
;
; `bench` auto-scales the repetition count: it runs `work` an increasing power
; of two times until the wall time clears bench-min-ms, then reports the chosen
; reps and the total ms so a per-iteration time is reps-independent. one line is
; printed per bench, matching the python/ruby harnesses:
;     <name> l <reps> <ms> <checksum>
; work is a unary thunk (called as (work 0), since l has no nullary calls)
; and must return a deterministic checksum the other languages reproduce.
(: (iota n)  ((: (go i) (? (< i n) (cons i (go (+ i 1))))) 0)         ; 0..n-1
   (iota1 n) ((: (go i) (? (< i n) (cons (+ i 1) (go (+ i 1))))) 0)   ; 1..n
   bench-min-ms 200                                                   ; timing floor
   (bench-run work reps)                                              ; -> (ms . chk)
    (: t0  (clock 0)
       chk ((: (go i a) (? (< i reps) (go (+ i 1) (work 0)) a)) 0 0)
     (cons (- (clock 0) t0) chk))
   (bench-loop work reps)                                             ; double until >= floor
    (: r (bench-run work reps)
       (? (< (cap r) bench-min-ms) (bench-loop work (* 2 reps)) (cons reps r)))
   (bench name work)
    (: r    (bench-loop work 1)
       reps (cap r) ms (cabp r) chk (cbbp r)
     (: _ (puts name)   _ (putc 32)
        _ (puts "l") _ (putc 32)
        _ (putx reps)   _ (putc 32)
        _ (putx ms)     _ (putc 32)
        _ (putx chk)    _ (putc 10) 0)))
