; crew/cc/cc.l -- the C compiler's driver (rung 3 stage 0): `au cc IN OUT`
; reads C, rides lex -> cpp -> parse -> gen -> the holo book -> elf64, and lays
; a runnable static ELF at OUT (chmod 755). errors speak on err and exit 1;
; usage exits 2. loads after crew/holo/elf.l in the au cat (elf64 leaked
; there) and after crew/cc/{lex,cpp,parse,gen}.l; rides the u-floor (uread udie).
(:
   ; the directory portion of a path (up to and including the last '/'), or ""
   (cdir path) (: n (tally path)
                  (go i last) (? (<= n i) last (= (path i) 47) (go (+ i 1) (+ i 1)) (go (+ i 1) last))
                  d (go 0 0)
                  (? (< 0 d) (snip path 0 d) ""))
   ; #include resolver bound to a source dir: search "" relative first (the src
   ; dir, then cwd), <> the system dirs. -> (1 text) | ().
   (incload srcdir name sys?)
    (: dirs (? sys? (L "crew/cc/include/" "/usr/include/")     ; our own headers (stdarg.h ..) win for <>
                (L srcdir "" "crew/cc/include/" "/usr/include/"))
       (go ds) (? (! (two? ds)) ()
                  (: r (uread (+ (cap ds) name))
                     (? (two? r) r (go (cup ds)))))
       (go dirs))
   (cc-main as)
    (? (! (two? (cup as))) (udie 2 "usage: cc IN OUT")
       (: src (cap as) dst (caup as)
          r (uread src)
          _ (? (two? r) () (udie 1 (+ "cc: cannot open " src)))
          lx (clex (caup r))
          _ (? (two? lx) () (udie 1 (+ "cc: lex error in " src)))
          pp (cpp (caup lx) (\ name sys? (incload (cdir src) name sys?)))
          _ (? (two? pp) () (udie 1 (+ "cc: preprocessor error in " src)))
          ps (cparse (caup pp))
          _ (? (two? ps) () (udie 1 (+ "cc: parse error in " src)))
          ir (cgen (caup ps) (cauup ps) (caup (cuup ps)))
          _ (? (two? ir) () (udie 1 (+ "cc: codegen error in " src)))
          res (elf64 'x64 (\ _ (caup ir)) ())
          _ (write-bytes dst (peep res 'bytes 0))
          _ (chmod dst 493)
          (nap 0))))
