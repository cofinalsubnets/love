; test/law/sat.l -- the sat unit's gates: DPLL against combinatorics, CDCL and the flat
; engine against DPLL, the dimacs reader, drat refutations checked in-process
(borrow 'sat)

(:
 ; --- stage 1: DPLL against the model checker and combinatorics
 _ (assert
    (: f '((1 2) (-1 3) (-2 -3)) m (solve f 3)
       (m != 'unsat && sat? m f))
    (solve '((1) (-1)) 1 = 'unsat)
    (: f (cyclic 10) m (solve f 10) (m != 'unsat && sat? m f))
    (count-models (cyclic 5) 5  = lucas 5)
    (count-models (cyclic 8) 8  = lucas 8)
    (count-models (cyclic 10) 10 = lucas 10)
    (bcp () '((1) (-1)) = 'conflict)
    (lucas 10 = 123))
 _ (assert    ; --- stage 2: CDCL agrees with DPLL ---
    (: f '((1 2) (-1 3) (-2 -3)) m (cdcl f 3) (m != 'unsat && sat? m f))
    (cdcl '((1) (-1)) 1 = 'unsat)
    (cdcl '((1 2) (1 -2) (-1 2) (-1 -2)) 2 = 'unsat)
    (: f (cyclic 12) m (cdcl f 12) (m != 'unsat && sat? m f))
    (cdcl '((1 2 3) (1 2 -3) (1 -2 3) (1 -2 -3) (-1)) 3 = 'unsat)          ; forces 1=0, then UNSAT
    (fuzz 60 8 30)                                                            ; near the phase transition
    (fuzz 40 10 30)
    (fuzz 30 12 50))
 _ (assert    ; --- stage 3: VSIDS, Luby restarts, phase saving ---
    (luby 1 = 1) (luby 2 = 1) (luby 3 = 2) (luby 4 = 1) (luby 6 = 2) (luby 7 = 4) (luby 15 = 8)
    (fuzz 40 12 50)
    (fuzz 20 14 58)
    ; php(5) blows past climit 100, so learning and restarts run end to end
    (cdcl (php 5) (php-vars 5) = 'unsat)
    (: f (cyclic 80) m (cdcl f 80) (m != 'unsat && sat? m f))
    (count-cdcl (cyclic 8) 8 = lucas 8)
    (count-cdcl (cyclic 10) 10 = lucas 10))
 _ (say err "sat: Stages 1-3 ok -- CDCL (learning, backjump, VSIDS, Luby restarts, phase saving) == DPLL on 190 fuzzed + UNSAT pigeonhole + #SAT==Lucas\n"))

(:
 ; -- parse self-tests (standalone; no solver needed) --
 _ (assert
    ; comments, a 3-var header, three clauses (one 1-lit), all 0-terminated
    (: r (dimacs "c hi
c there
p cnf 3 3
1 -2 0
2 3 -1 0
-3 0
")  (>r = 3 && <r = '((1 -2) (2 3 -1) (-3))))
    ; no leading comments, a clause split across whitespace, a missing final 0 (lenient flush)
    (: r (dimacs "p cnf 4 2
1 2 -3 0
4 -1")  (>r = 4 && <r = '((1 2 -3) (4 -1))))
    ; tabs + extra blank lines + a big var number parse
    (: r (dimacs "p cnf 100 1
	42	-99	0
")  (>r = 100 && <r = '((42 -99)))))
 ; -- parse, then solve --
 _ (assert
     (: r (dimacs "p cnf 3 3
1 2 0
-1 3 0
-2 -3 0
") f <r nv >r m (cdcl f nv) (m != 'unsat && sat? m f))   ; SAT -- model checks
     (cdcl <(dimacs "p cnf 1 2
1 0
-1 0
") 1 = 'unsat))                                                             ; (x)(-x) -> UNSAT
 _ (say err "src/apps/sat/dimacs: ok -- DIMACS reader (parser combinators) + parse->solve\n"))

(:
 ; --- the gate: the flat engine answers exactly like the oracle, kernels == twins
 _ (assert
    ; tiny SAT / UNSAT
    (: f '((1 2) (-1 3) (-2 -3)) m (fcdcl f 3) (m != 'unsat && sat? m f))
    (fcdcl '((1) (-1)) 1 = 'unsat)
    (fcdcl '((1 2) (1 -2) (-1 2) (-1 -2)) 2 = 'unsat)
    (fcdcl '((1 2 3) (1 2 -3) (1 -2 3) (1 -2 -3) (-1)) 3 = 'unsat)
    ; cyclic: SAT, the model checks, and #SAT == Lucas (solver-independent)
    (: f (cyclic 12) m (fcdcl f 12) (m != 'unsat && sat? m f))
    (count-fcdcl (cyclic 8) 8 = lucas 8)
    (count-fcdcl (cyclic 10) 10 = lucas 10)
    ; differential fuzz vs the DPLL oracle, mixed SAT/UNSAT near the phase transition
    (ffuzz 60 8 30)
    (ffuzz 40 10 30)
    (ffuzz 30 12 50)
    (ffuzz 20 14 58)
    ; native kernels == interpreted twins, verdict for verdict (a no-op switch where they can't build)
    (fboth (cyclic 14) 14)
    (fboth (php 4) (php-vars 4))
    (fboth (php 5) (php-vars 5))
    ; ..and the BVA transform agrees, not just its verdict (cyclic factors nothing)
    (fbvaboth (php 4) (php-vars 4))
    (fbvaboth (php 5) (php-vars 5))
    (fbvaboth (cyclic 14) 14)
    ; pigeonhole php(5): UNSAT + resolution-hard (learning, restarts, arena growth end to end)
    (fcdcl (php 5) (php-vars 5) = 'unsat)
    ; drat: an UNSAT proof re-checks against the original formula -- rup on the tiny ones,
    ; BVA's rat lines on php(4), `d` lines under a tiny learnt cap
    (: f '((1) (-1)) j (jug 0) _ (pin fdrat0 () j) r (fcdcl f 1) _ (pin fdrat0 () 0)
       (r = 'unsat && 1 = fd-check f (fd-parse (slurp j))))
    (: f '((1 2) (1 -2) (-1 2) (-1 -2)) j (jug 0) _ (pin fdrat0 () j) r (fcdcl f 2) _ (pin fdrat0 () 0)
       (r = 'unsat && 1 = fd-check f (fd-parse (slurp j))))
    (: f (php 4) j (jug 0) _ (pin fdrat0 () j) r (fcdcl f (php-vars 4)) _ (pin fdrat0 () 0)
       ps (fd-parse (slurp j))
       bad (map (st \ (0 = <st && 2 = #>st ?        ; negate a literal in every
                         (0 . -<>st . >>st) st))      ; 2-lit add line:
            ps)                                                        ; the checker must refuse
       (r = 'unsat && 1 = fd-check f ps && 0 = fd-check f bad))
    (: keep (peep fmaxl0 () 0) _ (pin fmaxl0 () 24)
       f (php 4) j (jug 0) _ (pin fdrat0 () j) r (fcdcl f (php-vars 4))
       (pin fdrat0 () 0, pin fmaxl0 () keep,
        r = 'unsat && 1 = fd-check f (fd-parse (slurp j))))
    ; force the learnt-db reduction path hard (a tiny cap -> reduction every few restarts)
    ; and re-run the differential battery through it, both engines
    (: keep (peep fmaxl0 () 0) _ (pin fmaxl0 () 24)
       ok (fcdcl (php 5) (php-vars 5) = 'unsat &&
           ffuzz 30 12 50 && fboth (php 4) (php-vars 4))
       (pin fmaxl0 () keep, ok))
    ; force fcompact at every level-0 restart (tiny threshold, no multiple): its cid
    ; remapping and level-0 UNSAT are reachable only here
    (: keep (peep fcmp0 () 0) kk (peep fcmpk () 2) _ (pin fcmp0 () 64) _ (pin fcmpk () 0)
       ok (fcdcl (php 5) (php-vars 5) = 'unsat &&
           ffuzz 30 12 50 && count-fcdcl (cyclic 10) 10 = lucas 10)
       (pin fcmp0 () keep, pin fcmpk () kk, ok))
    ; ..and the mark: at fcmpk 2, php(5) compacts, but fewer times than at fcmpk 0
    (: keep (peep fcmp0 () 0) kk (peep fcmpk () 2) ku (peep fru0 () 400)
       _ (pin fcmp0 () 64) _ (pin fru0 () 8)
       (n k) (: _ (pin fcmpk () k) _ (pin fcmpn () 0) v (fcdcl (php 5) (php-vars 5)) [v (peep fcmpn () 0)])
       every (n 0) marked (n 2)
       (pin fcmp0 () keep, pin fcmpk () kk, pin fru0 () ku,
        <every = 'unsat && <marked = 'unsat && 0 < <>marked < <>every)))
 _ (say err ("src/apps/sat/flat: ok -- flat-arena CDCL == DPLL on 150 fuzzed + PHP(5) + #SAT==Lucas"
             + (two? (fbcpk 8) ? " (native bcp+conf+dec+bvag kernels live)\n" " (interpreted twins)\n"))))
