; src/apps/sat/cli.l -- `love sat`: a dimacs cnf in, the sat competition's answer out, solved
; by flat.l's engine. the last file of the unit: the verb needs the module whole
(module 'sat
(: sat-usage "usage: love sat [-q] [-p PROOF] [FILE.cnf]
  solve a dimacs cnf, stdin without FILE or with -. prints s SATISFIABLE and a v line,
  or s UNSATISFIABLE, and exits 10 or 20, the sat competition's codes
  -p, --proof FILE  an unsat run's drat refutation, into FILE
  -q, --quiet       the s line alone
"
   (sat-text src)
    (src = "-" ? (slurp in + "")
       (uread src @ r (two? r ? <>r (udie 2 "sat: \(src): cannot open"))))
   (sat-main as)
    (: t {}
       o (uoptp as t '(112) () {"proof" 112 "quiet" 113})
       _ (two? o ? 0 (udie 2 "sat: -p needs a file"))
       un (uoptun t '(112 113))
       _ (un ? (udie 2 "sat: unknown option -\(string un)") 0)
       ops (o 2)
       _ (1 < #ops ? (udie 2 sat-usage) 0)
       src (<ops || "-")
       p (dimacs (sat-text src))                                     ; (formula . nvars)
       _ (charm? >p ? 0 (udie 2 "sat: \(src): not a dimacs cnf"))
       pf (uoptv t 112)
       j (pf ? (jug 0) 0)
       r (pin fdrat0 () j, fcdcl <p >p @ r (pin fdrat0 () 0, r))
       _ (pf && r = 'unsat && !(uwrite pf (slurp j)) ? (udie 2 "sat: \(pf): cannot write") 0)
       (r = 'unsat ? (say out "s UNSATISFIABLE\n", 20)
          (say out "s SATISFIABLE\n",
           t 113 ? 0 (say out (cats ("v" . map (vv \ " \(<vv * >vv)") r) + " 0\n")),
           10))))

; the seat, its own form so the binder above stays body-less: fire sat-main iff `sat` is
; the program word; a raise off /love runs it by name
(: door (udoor 'sat (urun sat-main) sat-usage 1 1)
   _ (cite 'verbs 'enlist 'sat door ())
   s (cite 'verbs 'fire ["sat"])
   (two? s ? (quit (door >s))))
) ; module sat
