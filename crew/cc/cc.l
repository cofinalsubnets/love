; crew/cc/cc.l -- the C compiler's driver (rung 3): `au cc [-c] IN OUT`
; reads C, rides lex -> cpp -> parse -> gen -> the holo book. WITHOUT -c it lays
; a runnable static ELF at OUT (chmod 755, _start + text + data one segment);
; WITH -c it lays a relocatable ELF object (crew/holo/obj.l -- separate sections,
; a symbol table, and relocations) the system linker binds against host/*.o +
; libc (stage 7a). errors speak on err and exit 1; usage exits 2. loads after
; crew/holo/{elf,obj}.l in the au cat and after crew/cc/{lex,cpp,parse,gen}.l;
; rides the u-floor (uread udie).
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
   (el l i) (? (< i 1) (cap l) (el (cup l) (- i 1)))
   ; the shared front end: source path -> (1 ast stag sigs) | a fatal exit
   (cc-parse src)
    (: r (uread src)
       _ (? (two? r) () (udie 1 (+ "cc: cannot open " src)))
       lx (clex (caup r))
       _ (? (two? lx) () (udie 1 (+ "cc: lex error in " src)))
       pp (cpp (caup lx) (\ name sys? (incload (cdir src) name sys?)))
       _ (? (two? pp) () (udie 1 (+ "cc: preprocessor error in " src)))
       ps (cparse (caup pp))
       _ (? (two? ps) () (udie 1 (+ "cc: parse error in " src)))
       ps)
   ; a standalone static executable (the default): _start + text + data, chmod +x
   (cc-exe src dst)
    (: ps (cc-parse src)
       ir (cgen (caup ps) (cauup ps) (caup (cuup ps)))
       _ (? (two? ir) () (udie 1 (+ "cc: codegen error in " src)))
       res (elf64 'x64 (\ _ (caup ir)) ())
       _ (write-bytes dst (peep res 'bytes 0))
       _ (chmod dst 493)
       (quit 0))
   ; a relocatable object (`-c`): text/data sections + symbols + relocations, for
   ; the system linker to bind against host/*.o + libc (stage 7a).
   (cc-obj src dst)
    (: ps (cc-parse src)
       ob (cgen-obj (caup ps) (cauup ps) (caup (cuup ps)))
       _ (? (two? ob) () (udie 1 (+ "cc: codegen error in " src)))
       bytes (objelf 'x64 (el ob 1) (el ob 2) (el ob 3) (el ob 4))
       _ (write-bytes dst bytes)
       (quit 0))
   (cc-main as)
    (? (&& (two? as) (= (cap as) "-c"))
        (: r (cup as) (? (two? (cup r)) (cc-obj (cap r) (caup r)) (udie 2 "usage: cc -c IN OUT")))
       (! (two? (cup as))) (udie 2 "usage: cc [-c] IN OUT")
       (cc-exe (cap as) (caup as))))
