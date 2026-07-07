; crew/cc/cc.l -- the C compiler's driver (rung 3): `aicc [-c] IN OUT`
; reads C, rides lex -> cpp -> parse -> gen -> the holo book. WITHOUT -c it lays
; a runnable static ELF at OUT (chmod 755, _start + text + data one segment);
; WITH -c it lays a relocatable ELF object (crew/holo/obj.l -- separate sections,
; a symbol table, and relocations) the system linker binds against host/*.o +
; libc (stage 7a). errors speak on err and exit 1; usage exits 2. LAST in the aicc
; cat (its own app, doc/cc.md), after crew/holo/{elf,obj}.l and crew/cc/{lex,cpp,parse,
; gen}.l; rides the u-floor (uread udie). its tail SEAT fires cc-main when aicc is the
; program on the command line.
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
        (: r (cup as) (? (two? (cup r)) (cc-obj (cap r) (caup r)) (udie 2 "usage: aicc -c IN OUT")))
       (! (two? (cup as))) (udie 2 "usage: aicc [-c] IN OUT")
       (cc-exe (cap as) (caup as))))

; the SEAT: fire cc-main iff aicc sits in the program seat of the real command line
; -- the positional program, or a `-l` preload (the installed shebang) -- taking the
; args AFTER the seat. `cmdline` is the full C argv, read the same in both load orders.
; aicc is its OWN app (its own catted shebang script, doc/cc.md): it does NOT ride the
; au multi-call cat, so a cc edit rebuilds only aicc, never au. matching aicc/cc.l here
; keeps the seat quiet under any other program name.
(: (bn p) (: n (tally p)
             (go k r) (? (< k n) (go (+ k 1) (? (= (p k) 47) (+ k 1) r)) (snip p r n))
             (go 0 0))
   (me? w) (: b (bn w) (|| (= b "aicc") (|| (= b "aicc.l") (= b "cc.l"))))
   (seat a) (? (! (two? a)) ()
               (= (cap a) "-l") (? (two? (cup a))
                                   (? (me? (caup a)) (link 1 (cuup a)) (seat (cuup a)))
                                   ())
               (me? (cap a)) (link 1 (cup a))
               ())
   s (seat (cup cmdline))
   (? (two? s) (cc-main (cup s)) ()))
