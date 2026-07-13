; crew/cc/cc.l -- the C compiler's driver:
;   aicc [-c] [-I dir] [-D name[=val]] [-o out] in.c|in.o ..
; reads C, rides lex -> cpp -> parse -> gen -> the holo book. one .c WITHOUT -c
; lays a runnable static ELF directly (chmod 755, _start + text + data one
; segment); WITH -c it lays relocatable ELF objects (crew/holo/obj.l --
; separate sections, a symbol table, and relocations), several .c inputs each
; landing in the cwd as x.o (gcc-shaped); a .o input or SEVERAL inputs without
; -c is a LINK -- our own static linker (crew/holo/link.l, rung 3) binds them
; (compiling any .c on the way) into -o's exe, `a.out` bare. the old positional
; pair `aicc [-c] IN OUT` still reads (two bare args, no .c and -- linking --
; no .o). -I dirs search before the system pair on both include forms; a -D
; rides in as a synthesized #define line, so token bodies and function-like
; -DF(x)=.. take the one macro path. errors speak on err and exit 1; usage
; exits 2. LAST in the aicc cat (its own app, doc/cc.md), after
; crew/holo/{elf,obj,link}.l and crew/cc/{lex,cpp,parse,gen}.l; rides the
; u-floor (uread udie). its tail SEAT fires cc-main when aicc is the program.
(:
   ; the directory portion of a path (up to and including the last '/'), or ""
   (cdir path) (: n (tally path)
                  (go i last) (? (<= n i) last (= (path i) 47) (go (+ i 1) (+ i 1)) (go (+ i 1) last))
                  d (go 0 0)
                  (? (< 0 d) (snip path 0 d) ""))
   ; #include resolver bound to a source dir + the -I list: "" searches relative
   ; first (the src dir, then cwd) then the -I dirs; <> the -I dirs straight off;
   ; both fall to the system pair, our own headers before /usr. answers
   ; (1 text child) -- the child hook resolves the hit file's OWN quote
   ; includes beside it (gcc's rule; cpp.l threads it). -> that | ().
   (incload is srcdir name sys?)
    (: dirs (? sys? (cat is (L "crew/cc/include/" "/usr/include/"))   ; our headers (stdarg.h ..) win for <>
                (cat (L srcdir "") (cat is (L "crew/cc/include/" "/usr/include/"))))
       (go ds) (? (! (two? ds)) ()
                  (: r (uread (+ (cap ds) name))
                     (? (two? r)
                        (: hd (cdir (+ (cap ds) name))
                           (L 1 (caup r) (\ n2 s2 (incload is hd n2 s2))))
                        (go (cup ds)))))
       (go dirs))
   (el l i) (? (< i 1) (cap l) (el (cup l) (- i 1)))
   ; a -D definition as #define text: the first = becomes the space, so
   ; -DX -> "X" (defined 1 below), -DX=v -> "X v", -DF(x)=x -> "F(x) x"
   ; (the glued ( survives the lex, so it stays function-like).
   (eqsp d) (: n (tally d)
               (go i) (? (<= n i) (+ d " 1")
                         (= (d i) 61) (+ (snip d 0 i) (+ " " (snip d (+ i 1) n)))
                         (go (+ i 1)))
               (go 0))
   (deftext ds) (foldl (\ a d (+ a (+ "#define " (+ (eqsp d) "\n")))) "" ds)
   ; the shared front end: source path (+ -I dirs, -D defines) -> (1 ast stag
   ; sigs ..) | a fatal exit. the -D lines PREPEND to the source text before the
   ; one lex, so the line numbering stays whole (tokens carry lines and a define
   ; body runs to its line's end -- a separately-lexed stream would restart at 1
   ; and the last -D would swallow the file's first line); diagnostics under -D
   ; skew by the define count, the price of the shared stream.
   (cc-parse src is ds)
    (: r (uread src)
       _ (? (two? r) () (udie 1 (+ "cc: cannot open " src)))
       lx (clex (+ (deftext ds) (caup r)))
       _ (? (two? lx) () (udie 1 (+ "cc: lex error in " src)))
       pp (cpp (caup lx) (\ name sys? (incload is (cdir src) name sys?)))
       _ (? (two? pp) () (udie 1 (+ "cc: preprocessor error in " src)))
       ps (cparse (caup pp))
       _ (? (two? ps) () (udie 1 (+ "cc: parse error in " src)))
       ps)
   ; the parser's static/section trio, threaded to the gen as one list
   (pxtra ps) (L (el ps 5) (el ps 6) (el ps 7))
   ; a standalone static executable (the default): _start + text + data, chmod +x
   (cc-exe src dst is ds)
    (: ps (cc-parse src is ds)
       ir (cgen (caup ps) (cauup ps) (caup (cuup ps)) (el ps 4) (pxtra ps))
       _ (? (two? ir) () (udie 1 (+ "cc: codegen error in " src)))
       res (elf64 'x64 (\ _ (caup ir)) ())
       _ (write-bytes dst (peep res 'bytes 0))
       (chmod dst 493))
   ; a relocatable object: text/data/ai_nifs sections + symbols + relocations
   ; -- the bytes (`-c` writes them; the link path feeds them to ldlink).
   (cc-objbytes src is ds)
    (: ps (cc-parse src is ds)
       ob (cgen-obj (caup ps) (cauup ps) (caup (cuup ps)) (el ps 4) (pxtra ps))
       _ (? (two? ob) () (udie 1 (+ "cc: codegen error in " src)))
       (objelf 'x64 (el ob 1) (el ob 2) (el ob 3) (el ob 4) (el ps 4) (el ob 5)))
   (cc-obj src dst is ds) (write-bytes dst (cc-objbytes src is ds))
   ; the LINK path (rung 3, crew/holo/link.l): every input lands as object
   ; bytes (a .c compiled here, a .o read off disk), crt0 rides FIRST (its
   ; text is the entry), and ldlink binds the static exe -- no system linker.
   ; the entry hands the OS stack pointer (argc sits at [rsp]) to __ai_start
   ; and exits with its answer if it ever returns. __ai_start is defined here
   ; WEAK -- the bare call-main tail every small link gets (the push 16-aligns
   ; the call) -- so a libc object (crew/cc/lib/nolibc.c, rung 4) can override
   ; it strong and unpack argv/envp/auxv before main. no conditional anywhere:
   ; the weak machinery is the whole switch.
   crt0 (L (L 'mov 'r6 'sp)
           (L 'call '__ai_start)
           (L 'mov 'r6 'r0) (L 'li 'r0 60) (L 'sys)
           (L 'label '__ai_start)
           (L 'push 'r6)
           (L 'call 'main)
           (L 'mov 'r6 'r0) (L 'li 'r0 60) (L 'sys))
   (cc-link ins dst is ds)
    (: srcs (map (\ f (? (dotc? f) (L f (string (cc-objbytes f is ds)))
                         (doto? f) (: r (uread f)
                                      (? (two? r) (L f (caup r))
                                         (udie 1 (+ "cc: cannot open " f))))
                         (udie 2 (+ "cc: not a .c/.o input: " f))))
                 ins)
       ps (ldlink 'x64 (link (L "crt0" (string (objelf 'x64 crt0 () (L "__ai_start") () (L "__ai_start") ()))) srcs))
       _ (ld-write dst ps)
       (chmod dst 493))
   usage "usage: aicc [-c] [-I dir] [-D name[=val]] [-o out] in.c|in.o .."
   ; the flag scan: -c, -I dir / -Idir, -D def / -Ddef, -o out; every other
   ; bare arg is an input, any other dash arg refuses. -> (c idirs defs out ins).
   (glu? a ch) (&& (< 2 (tally a)) (&& (= (a 0) 45) (= (a 1) ch)))
   (dirn d) (: n (tally d) (? (= n 0) d (= (d (- n 1)) 47) d (+ d "/")))
   (dotc? p) (: n (tally p) (&& (< 2 n) (&& (= (p (- n 2)) 46) (= (p (- n 1)) 99))))
   (doto? p) (: n (tally p) (&& (< 2 n) (&& (= (p (- n 2)) 46) (= (p (- n 1)) 111))))
   ; a LINK-shaped input list: any .o in it, or several inputs at once
   (lnky? ins) (|| (two? (cup ins)) (foldl (\ a x (|| a (doto? x))) () ins))
   (obase p) (: n (tally p)                        ; dir/x.c -> x.o (in the cwd, gcc-shaped)
                (go k r) (? (< k n) (go (+ k 1) (? (= (p k) 47) (+ k 1) r)) (snip p r (- n 1)))
                (+ (go 0 0) "o"))
   (flags as c is ds o ins)
    (? (! (two? as)) (L c (rev is) (rev ds) o (rev ins))
       (: a (cap as) r (cup as)
          (? (= a "-c") (flags r 1 is ds o ins)
             (= a "-I") (? (two? r) (flags (cup r) c (link (cap r) is) ds o ins) (udie 2 usage))
             (= a "-D") (? (two? r) (flags (cup r) c is (link (cap r) ds) o ins) (udie 2 usage))
             (= a "-o") (? (two? r) (flags (cup r) c is ds (cap r) ins) (udie 2 usage))
             (glu? a 73) (flags r c (link (snip a 2 (tally a)) is) ds o ins)
             (glu? a 68) (flags r c is (link (snip a 2 (tally a)) ds) o ins)
             (&& (< 0 (tally a)) (= (a 0) 45)) (udie 2 usage)
             (flags r c is ds o (link a ins)))))
   (cc-main as)
    (: f (flags as () () () () ())
       c (el f 0) is (map dirn (el f 1)) ds (el f 2) o (el f 3) ins (el f 4)
       (? (! (two? ins)) (udie 2 usage)
          o (? c (? (two? (cup ins)) (udie 2 "cc: -o takes one input")
                    (: _ (cc-obj (cap ins) o is ds) (quit 0)))
               (lnky? ins) (: _ (cc-link ins o is ds) (quit 0))
               (: _ (cc-exe (cap ins) o is ds) (quit 0)))
          ; the legacy pair: exactly two bare args, the second no .c -- IN OUT
          ; (a .c/.o mix is a LINK, never a pair; -c keeps its .o OUT)
          (&& (two? (cup ins))
              (&& (! (two? (cuup ins)))
                  (&& (! (dotc? (caup ins)))
                      (|| c (&& (! (doto? (cap ins))) (! (doto? (caup ins))))))))
           (: _ (? c (cc-obj (cap ins) (caup ins) is ds) (cc-exe (cap ins) (caup ins) is ds)) (quit 0))
          c (: (go l) (? (! (two? l)) (quit 0)
                         (! (dotc? (cap l))) (udie 2 (+ "cc: not a .c input: " (cap l)))
                         (: _ (cc-obj (cap l) (obase (cap l)) is ds) (go (cup l))))
               (go ins))
          (lnky? ins) (: _ (cc-link ins "a.out" is ds) (quit 0))
          (udie 2 usage))))

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
