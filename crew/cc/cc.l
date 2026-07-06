; crew/cc/cc.l -- the C compiler's driver (rung 3 stage 0): `au cc IN OUT`
; reads C, rides lex -> parse -> gen -> the holo book -> elf64, and lays a
; runnable static ELF at OUT (chmod 755). errors speak on err and exit 1;
; usage exits 2. loads after crew/holo/elf.l in the au cat (elf64 leaked
; there) and after crew/cc/{lex,parse,gen}.l; rides the u-floor (uread udie).
(:
   (cc-main as)
    (? (! (two? (cup as))) (udie 2 "usage: cc IN OUT")
       (: src (cap as) dst (caup as)
          r (uread src)
          _ (? (two? r) () (udie 1 (+ "cc: cannot open " src)))
          lx (clex (caup r))
          _ (? (two? lx) () (udie 1 (+ "cc: lex error in " src)))
          ps (cparse (caup lx))
          _ (? (two? ps) () (udie 1 (+ "cc: parse error in " src)))
          ir (cgen (caup ps))
          _ (? (two? ir) () (udie 1 (+ "cc: codegen error in " src)))
          res (elf64 'x64 (\ _ (caup ir)) ())
          _ (write-bytes dst (peep res 'bytes 0))
          _ (chmod dst 493)
          (nap 0))))
