; crew/cc/gen.l -- the code generator (rung 3 stage 0). AST -> (1 ir-forms) |
; (). holo's neutral IR (crew/holo/holo.l), chibicc-plain: every expression
; computes into r0. the program wears its own crt0: the entry stub calls main
; and hands r0 to the exit syscall -- a runnable static ELF end to end, no
; libc, no linker (the .o + ld seam arrives with globals at stage 3).
; the SysV story so far: r0 is the return register (holo r0 = rax on x64).
(:
   (cgexpr e)                                       ; expr -> forms leaving r0
    (? (= (cap e) 'num) (L (L 'li 'r0 (caup e)))
       ())
   (cgstmt s)                                       ; stmt -> forms | ()
    (? (= (cap s) 'ret)
       (: e (cgexpr (caup s))
          (? (two? e) (cat e (L (L 'ret))) ()))
       ())
   (cgfn f)                                         ; ('fn name stmts) -> forms | ()
    (: (body ss acc)
        (? (! (two? ss)) (L 1 acc)
           (: r (cgstmt (cap ss))
              (? (two? r) (body (cup ss) (cat acc r)) ())))
       b (body (cauup f) ())
       (? (two? b) (L 1 (link (L 'label (intern (caup f))) (caup b))) ()))
   (cgen ast)                                       ; ('prog fns) -> (1 forms) | ()
    (: crt0 (L (L 'call 'main) (L 'mov 'r6 'r0) (L 'li 'r0 60) (L 'sys))
       (gfns fs acc saw)
        (? (! (two? fs))
           (? saw (L 1 (cat crt0 acc)) ())          ; no main, no program
           (: f (cap fs)
              r (cgfn f)
              (? (two? r)
                 (gfns (cup fs) (cat acc (caup r)) (|| saw (= (caup f) "main")))
                 ())))
       (gfns (caup ast) () ())))
