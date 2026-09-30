; cdcl -- the CDCL solver (src/apps/sat/sat.l, prepended by run.sh) on four UNSAT pigeonhole instances
; PHP(2..5), plus #SAT model-counting of the cyclic n=8 CNF (47 = Lucas(8)). checksum = 100*14 + 47 =
; 1447, a solver-independent fact, so it holds across heuristic changes. love-only.
(: (sat-work _)
    (: u (foldl (\ a h (a + (cdcl (php h) (php-vars h) == 'unsat ? h 0))) 0 [2 3 4 5])     ; 2+3+4+5 = 14 (all UNSAT)
       c (count-cdcl (cyclic 8) 8)                                                          ; 47 = Lucas(8)
       (100 * u + c))
   (bench "cdcl" sat-work))
