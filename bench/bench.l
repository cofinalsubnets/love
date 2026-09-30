; love benchmark harness -- shared timing, reporting and list helpers. bench/Makefile cats it ahead
; of each bench/benches/*.l, so these bindings are globals; every bench file ends in (bench name work).
; `bench` doubles the rep count until the wall time clears bench-min-ms, then times that count once
; more and reports the warm run, so ms/it does not ride the per-process startup costs.
; one line per bench, the same contract as lib/bench.*:  <name> <lang> <reps> <ms> <checksum>
; the lang label (BENCH_LANG, default "love") must equal the column key in bench/Makefile's lang
; lists or report.awk drops the column. work is called as (work ()) and answers a checksum the
; other languages reproduce.
(: (iota1 n) (map (+ 1) (jot n))                                     ; 1..n
   bench-lang (getenv "BENCH_LANG" || "love")
   bench-min-ms 200                                                   ; timing floor
   (bench-run work reps)                                              ; -> (ms . chk)
    (: t0  (clock 0)
       chk ((: (go i a) (i < reps ? (go (i + 1) (work ())) a)) 0 0)
     (clock 0 - t0 . chk))
   (bench-loop work reps)                                             ; double until >= floor, then time it warm
    (: r (bench-run work reps)
       (<r < bench-min-ms ? (bench-loop work (2 * reps)) (reps . bench-run work reps)))
   (bench name work)
    (: r    (bench-loop work 1)
       reps <r ms (caup r) chk (cuup r)
     (: _ (puts name)       _ (putc 32)
        _ (puts bench-lang) _ (putc 32)
        _ (putx reps)   _ (putc 32)
        _ (putx ms)     _ (putc 32)
        _ (putx chk)    _ (putc 10) 0)))
