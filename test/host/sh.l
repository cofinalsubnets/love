; lush: its pure parts, the job-control nifs, and the built shell driven end to end
; through out/love (never PATH's love); the interactive loop on a pty
; run: cat test/00-init.l test/host/sh.l | out/love
(reads (open "src/apps/lush.l" "r"))
(borrow 'lush)
(: shS (sh-new 0))
(pin shS 'sh-mflag 0) ; autonomous here

; the lexer. expecteds are built, not quoted: the reader has no dotted pairs
(: lw (\ s ('w . [('lit . s)]))
   rdt (\ ion o ('rd . ion . o))
   opt (\ o ('op . o))
   (test
    ([1 (lw "a") (lw "b")] = (sh-lex shS) " a  b ")
    ([1 ('w . [('sq . "x  y")])] = (sh-lex shS) "'x  y'")
    ([1 ('w . [('lit . "a") ('dq . [('lit . "b c")]) ('lit . "d")])]
       = (sh-lex shS) "a\"b c\"d")
    ([1 (lw "a") (rdt () ">") (lw "b")] = (sh-lex shS) "a>b")
    ([1 (lw "x") (rdt [2] ">&") (lw "1")] = (sh-lex shS) "x 2>&1")
    ([1 (lw "a") (opt "&&") (lw "b")] = (sh-lex shS) "a&&b")
    ([1 (lw "a") (opt ";") (lw "b")] = (sh-lex shS) "a; b")
    ([1 (lw "a")] = (sh-lex shS) "a # rest dies")
    ([1 ('w . [('var . "HOME")])] = (sh-lex shS) "$HOME")
    ([1 ('w . [('dq . [('lit . "v=") ('var . "V")])])] = (sh-lex shS) "\"v=$V\"")
    ([1 ('w . [('sub . "echo hi")])] = (sh-lex shS) "$(echo hi)")
    ([1 ('w . [('sub . "date")])] = (sh-lex shS) "`date`")
    (<(sh-lex shS "echo 'x") = 'more)
    (<(sh-lex shS "echo \\") = 'more)
    ; an empty payload is a parse, not 'more: it nets zero, so the kind decides
    ([1 (lw "echo") ('w . [['dq]])] = (sh-lex shS) "echo \"\"")
    ([1 (lw "echo") ('w . [('lit . "a") ['dq] ('lit . "b")])]
       = (sh-lex shS) "echo a\"\"b")
    ([1 (lw "echo") ('w . [('sub . "")])] = (sh-lex shS) "echo ``")
    ([1 (lw "cat") (rdt () "<h") ('w . [['dq]]) (opt "nl")]
       = (sh-lex shS) "cat <<E\nE\n")
    ; ..and inside a vop word
    ([['dq]] = (sh-wordize shS) "\"\"")
    ([('sub . "")] = (sh-wordize shS) "``")))

; quoting: (sh-read (sh-show ws)) = ws, sh-read a word's whole path to argv
(: (sh-read s) (: lx (sh-lex shS s)
                  (<lx != 1 ? ['lex <lx]
                   (catmap (t \ (<t != 'w ? ['tok <t] (sh-fields shS >t))) >lx)))
   bytes  (map string (map (+ 1) ^126)) ; no NUL; past 127 the utf-8 shape stands in
   buried (map (c \ "a" + c + "b") bytes)
   shapes ["" "a=b" "x=" "A_1=v" "=x" "9x=1" "--port=8080" "-" "--" "%1"
           "a'b" "'" "''" "x  y" "  " "caf\xc3\xa9" "$(echo hi)" "src/apps/lus*.l"
           "/usr/local/bin:1,2.3@x+y%z_-"]
   corpus (bytes + buried + shapes)
   (test
    ; a filter, not `all`, so a red names its words
    (() = filter (w \ (sh-read (sh-quote w)) != [w]) corpus)
    ((sh-read (sh-show corpus)) = corpus)        ; ..and all of them as one line
    ((sh-quote "") = "''")
    ((sh-quote "abc") = "abc")
    ((sh-quote "a b") = "'a b'")
    ((sh-quote "a'b") = "'a'\\''b'")             ; the one byte '..' cannot hold
    ((sh-quote "--port=8080") = "--port=8080")   ; an assignment's name is a name
    ((sh-quote "a=b") = "'a=b'")                 ; ..and this one is, in command position
    ((sh-quote "=x") = "'=x'")                   ; zsh reads a leading = as a command path
    ((sh-quote "9x=1") = "9x=1")
    ((sh-show []) = "") ((sh-show ["a"]) = "a") ((sh-show ["a" "b c"]) = "a 'b c'")
    ; a keyword at the head is quoted; a later `in` is not
    ((sh-show ["if" "x"]) = "'if' x")
    ((sh-show ["grep" "-w" "in" "f"]) = "grep -w in f")
    (<(sh-parse >(sh-lex shS (sh-show ["if" "x"]))) = 'ok)
    (<(sh-parse >(sh-lex shS "if x")) != 'ok)))

; the grammar: pipe under && under ;, & backgrounds its own and_or, a dangling && is 'more
(: pr (sh-parse >(sh-lex shS "a | b && c ; d &"))
   a >pr
   (test (<pr = 'ok) (<a = 'seq)
           (<(a 1) = 'and)
           (<(a 1 1) = 'pipe)
           (<(a 2) = 'bg)))
(: pr (sh-parse >(sh-lex shS "a | b"))
   a >pr
   (test (<a = 'pipe) (2 = #(a 1))))
(: pr (sh-parse >(sh-lex shS "! false"))
   (test (<>pr = 'not)))
(test (<(sh-parse >(sh-lex shS "a &&")) = 'more)
        (<(sh-parse >(sh-lex shS "( x )")) = 'ok))

; compounds ('more while open), ${..} as vop, a heredoc as <h with its body the target
(: pr (sh-parse >(sh-lex shS "if a; then b; fi"))
   (test (<pr = 'ok) (<>pr = 'if)))
(: pr (sh-parse >(sh-lex shS "while a; do b; done < f"))
   (test (<pr = 'ok) (<>pr = 'rdr)))
(: pr (sh-parse >(sh-lex shS "case x in a|b) c;; esac"))
   (test (<pr = 'ok) (<>pr = 'case)))
(: pr (sh-parse >(sh-lex shS "f() { x; }"))
   (test (<pr = 'ok) (<>pr = 'fun)))
(test (<(sh-parse >(sh-lex shS "if a; then b")) = 'more)
        (<(sh-parse >(sh-lex shS "for f in")) = 'more)
        ('(1 (w (vop "x" ":-" "y"))) = : r (sh-lex shS "${x:-y}") r))
(: lx (sh-lex shS "cat <<EOF\nbody\nEOF")
   t >lx
   (test (1 = <lx)
           (<(<>t) = 'rd)                         ; (rd () . "<h")
           ("<h" = >>(<>t))))

; a row [script out] or [script out status] runs `lush -c script`
(: (t-lush s) >(hark ["out/love" "out/lush" "-c" s])
   (t-lushx s) (hark ["out/love" "out/lush" "-c" s] @ r [>r <r])
   (t-lushes rows) (each rows (c \ ev ['test (two? >>c ? [['list (c 1) (c 2)] '= ['t-lushx <c]]
                                                      [(c 1) '= ['t-lush <c]])])))

(t-lushes
 [["for f in a b; do echo f=$f; done" "f=a\nf=b\n"]
  ["f() { echo n=$# one=$1; return 3; }; f x y; echo rc=$?" "n=2 one=x\nrc=3\n"]
  ["case q.l in *.c) echo c;; *.l) echo l;; esac" "l\n"]
  ["p=a/b.l; echo ${p%.l} ${p#a/} ${U:-dflt} ${#p}" "a/b b.l dflt 5\n"]
  ; IFS: "" splits nothing, white runs merge, any other byte ends a field, even an empty one
  ["IFS=:; x='a::b:'; for f in $x; do echo \"[$f]\"; done" "[a]\n[]\n[b]\n"]
  ["IFS='|'; s='a b|c'; for f in $s; do echo \"[$f]\"; done; IFS=; for f in $s; do echo \"<$f>\"; done" "[a b]\n[c]\n<a b|c>\n"]
  ["IFS=' :'; x='a : b'; for f in $x; do echo \"[$f]\"; done" "[a]\n[b]\n"]
  ["set -- 'x y' z; IFS=:; for f in $@; do echo \"[$f]\"; done; g() { for w; do echo \"<$w>\"; done; }; g 'p q' r" "[x y]\n[z]\n<p q>\n<r>\n"]
  ["IFS=,; echo 'u,v,w rest' | { read a b c; echo \"$a|$b|$c\"; }" "u|v|w rest\n"]])
(: _ (setenv "LUSH_HD" "quay")
   r (hark ["out/love" "out/lush" "-c" "cat <<EOF | tr a-z A-Z\nhd $LUSH_HD\nEOF"])
   (test ("HD QUAY\n" = >r)))
; \c quotes c: a lone \* never globs; any quote or \ in a heredoc's delimiter quotes the body
(t-lushes
 [["cd src/apps; echo \\* lus\\*.l; expr 6 \\* 2" "* lus*.l\n12\n"]
  ["X=1; cat <<\\E\n$X\nE\ncat <<E\"O\"F\n$X\nEOF\ncat <<E\n$X\nE" "$X\n$X\n1\n"]
  ["( exit 5 ); echo sub=$?" "sub=5\n"]])
(: r (hark ["out/love" "out/lush" "-c" "set -u; echo $LUSH_UNDEF_QQ; echo no"])
   (test !(0 = <r)))

; $(( .. )): C's precedence, the bases, truncation toward zero
(t-lushes
 [["n=5; echo $((n*2)) $((2+3*4)) $(((2+3)*4)) $((0x1f)) $((010)) $((-7/2)) $((7%3))" "10 14 20 31 8 -3 1\n"]
  ; && short-circuits (100/x would divide by zero); the text expands before the read
  ["i=0; i=$((i+1)); i=$((i+1)); x=0; echo $i $((x!=0 && 100/x)) $(( $(echo 6) * 7 ))" "2 0 42\n"]
  ; trap exit runs once, at the end, keeping the leaving status
  ["trap 'echo bye' EXIT; echo hi" "hi\nbye\n"]
  ["trap 'echo bye' EXIT; false" "bye\n" 1]
  ; ..and a forked subshell does not run it (POSIX resets it there)
  ["trap 'echo bye' EXIT; (exit 0); echo after" "after\nbye\n"]
  ; a trapped signal runs its action, and the shell answers after it
  ["trap 'echo CAUGHT' INT; kill -INT $$; echo done" "CAUGHT\ndone\n"]
  ["trap 'echo T' TERM; kill -TERM $$; trap; echo alive" "T\ntrap -- 'echo T' TERM\nalive\n"]])
; ..but a signal ignored on entry cannot be trapped (POSIX), silently
(: _ (signal sig-int 1)
   r (hark ["out/love" "out/lush" "-c" "trap 'echo CAUGHT' INT; kill -INT $$; echo done"])
   _ (signal sig-int 0)
   (test ("done\n" = >r)))
; trap '' is an ignore (POSIX): the shell lives through the signal, and what it starts
; or becomes ignores it too; a subshell keeps it, `trap -` ends it
(: r (hark ["out/love" "out/lush" "-c" "trap '' INT; kill -INT $$; echo alive"])
   (test ("alive\n" = >r) (0 = <r)))
(: r (hark ["out/love" "out/lush" "-c" "trap '' INT; trap"])
   (test ("trap -- '' INT\n" = >r)))
(: r (hark ["out/love" "out/lush" "-c" "trap '' INT; /bin/sh -c 'kill -INT $$; echo child'; echo parent"])
   (test ("child\nparent\n" = >r)))
(: r (hark ["out/love" "out/lush" "-c" "trap '' INT; exec /bin/sh -c 'kill -INT $$; echo kept'"])
   (test ("kept\n" = >r)))
(: r (hark ["out/love" "out/lush" "-c" "trap '' INT; (trap)"])
   (test ("trap -- '' INT\n" = >r)))
(: r (hark ["out/love" "out/lush" "-c" "trap '' INT; trap - INT; /bin/sh -c 'kill -INT $$; echo NOT'; echo after"])
   (test ("after\n" = >r)))
; completion offers every builtin the shell dispatches on
(: S ((cite 'lush 'sh-new) 0) cmds (cite 'lush 'sh-cmds)
   (test (elem "eval" (cmds S "ev")) (elem "ev" (cmds S "ev")) (elem "trap" (cmds S "tra"))))

; exec: the shell becomes the command; with none, the redirects are the shell's
(t-lushes
 [["echo one; exec echo two; echo three" "one\ntwo\n" 0]
  ["exec 3>&1; echo a >&3; echo b >&3" "a\nb\n"]
  ["exec nosuchcmd123; echo after" "" 127]   ; a missing word ends the script (POSIX)
  ["exec echo hi | cat; echo end" "hi\nend\n"] ; in a stage it replaces only the stage
  ; a trap's blocked mask does not ride the exec: its own INT kills it (130)
  ["trap 'echo T' INT; exec out/love out/lush -c 'kill -INT $$; echo NOT'" "" 130]
  ["type exec" "exec is a shell builtin\n"]
  ; in a $( ) it replaces only the subshell, its status the substitution's
  ["x=$(exec echo hi); echo \"got $x\"" "got hi\n" 0]
  ["x=$(echo a; exec sh -c 'echo b; exit 3'; echo c); echo \"$x $?\"" "a\nb 3\n"]
  ["x=$(exec nosuchcmd123 2>/dev/null); echo \"[$x] $?\"" "[] 127\n"]
  ; ..and a bare exec's redirects end with it
  ["{ x=$(exec 2>/dev/null); echo e >&2; } 2>&1" "e\n"]
  ["exec 3>&1; x=$(exec 3>/dev/null; echo in >&3); echo \"kept [$x]\" >&3" "kept []\n"]])

; a plan fires with its state, so twice runs twice; the function book holds plans
; (closures, never two?), absence the sh-nofn mint
(: pr (sh-parse >(sh-lex shS "LUSH_PL=$(expr ${LUSH_PL:-0} + 1)"))
   p (sh-plan shS >pr)
   _ (p shS) _ (p shS)
   (test ('("2") = (sh-fields shS) [('var . "LUSH_PL")])))
(sh-line shS "lush_pf() { echo x; }",
 test (sh-fn? shS "lush_pf") !(sh-fn? shS "lush_pq_zz")
           !(two? (sh-fnof shS "lush_pf")))
; break/continue count their levels through the planned loops
(t-lushes
 [["for a in 1 2; do for b in x y; do echo $a$b; break 2; done; done; echo end" "1x\nend\n"]
  ["for a in 1 2 3; do [ $a = 2 ] && continue; echo n=$a; done" "n=1\nn=3\n"]
  ; errexit's guard (sh-noe) is a dynamic extent: it reaches a forked stage and an
  ; eval inside a condition, neither outside one (as bash)
  ["set -e; { false; echo r; } | cat; echo after" "after\n"]
  ["set -e; if { false; echo r; } | cat; then echo t; fi" "r\nt\n"]
  ["set -e; if eval \"false; echo x\"; then echo t; fi" "x\nt\n"]
  ["set -e; eval \"false; echo x\"; echo after" "" 1]
  ["set -e; false && echo a; echo survived" "survived\n"]
  ; ..but a $( ) body is guarded and runs to its end, in both capture lanes (as bash)
  ["set -e; v=$( { false; echo r; } ); echo v=[$v] after" "v=[r] after\n"]
  ["set -e; v=$(false; echo r); echo v=[$v] after" "v=[r] after\n"]
  ["set -e; f(){ false; echo fr; }; v=$(f); echo v=[$v] after" "v=[fr] after\n"]
  ; no command name: the status of the last $( ) (POSIX), else 0; set -e sees it
  ["v=$(exit 3); echo $?" "3\n"]
  ["v=1; echo $?" "0\n"]
  ["a=$(exit 3) b=$(exit 4); echo $?" "4\n"]
  ["v=$(exit 5)x$(exit 6); echo $?" "6\n"]
  ["v=$(false) true; echo $?" "0\n"]
  ; the words expand first, so a $( ) yielding no field still counts
  ["v=1 $(exit 3); echo $?" "3\n"]
  ["v=$(exit 2) $(exit 3); echo $?" "2\n"]
  ["$(exit 6); echo $?" "6\n"]
  ["set -e; v=$(false); echo never" "" 1]
  ["set -e; if v=$(false); then echo t; else echo e; fi" "e\n"]])

; expansion: split only expansion output, an unset var is no field, a quoted empty is one
(: _ (setenv "LUSH_T1" "quay")
   _ (setenv "LUSH_T2" "a  b")
   v (\ nm ('var . nm))
   (test
    ('("pre-quay") = (sh-fields shS) [('lit . "pre-") (v "LUSH_T1")])
    ('("a" "b") = (sh-fields shS) [(v "LUSH_T2")])
    ('("a  b") = (sh-fields shS) [('dq . [(v "LUSH_T2")])])
    (() = (sh-fields shS) [(v "LUSH_NIL_ZZ")])
    ('("") = (sh-fields shS) [('sq . "")])
    ('("quay") = (sh-fields shS) [('sub . "echo quay")])
    ('("src/apps/lush.l") = (sh-fields shS) [('lit . "src/apps/lus*.l")])
    ('("a/zz*qq") = (sh-fields shS) [('lit . "a/zz*qq")])
    ('("src/apps/lush/j*.l") = (sh-fields shS) [('sq . "src/apps/lush/j*.l")])))
(pin shS 'sh-status 7,
 test ('("7") = (sh-fields shS) [('var . "?")]))

; fnmatch and the glob walk
(test (sh-match "*.l" "job.l") !(sh-match "*.l" "job.c")
        (sh-match "j??.l" "job.l") (sh-match "[a-j]ob.l" "job.l")
        !(sh-match "[!a-j]ob.l" "job.l") (sh-match "[!a-j]ob.l" "zob.l")
        (sh-match "[!a]bc" "zbc") !(sh-match "[!a]bc" "abc")
        (sh-match "[^a]bc" "zbc") !(sh-match "[abz]bc" "qbc")
        (sh-match "a[bc" "a[bc")                                    ; unterminated [ is itself
        ('("src/apps/lush.l") = sh-glob "src/apps/l[t-v]sh.l" (sh-ones 19)))

; completion: (insert . candidates); one candidate lands its tail and " " (a dir "/")
(: r (sh-complete shS (sh-expl "cat src/apps/lus"))
   (test (two? r) ("h.l " = slurp (tap <r)) ('("src/apps/lush.l") = >r)))
(: r (sh-complete shS (sh-expl "cat src/apps/ko"))
   (test ("re/" = slurp (tap <r))))
(: r (sh-complete shS (sh-expl "cat src/apps/lu"))
   (test ('("src/apps/lupa.l" "src/apps/lush.l" "src/apps/lux") = >r)))
(test ("ab" = sh-common '("abc" "abd" "ab"))
        ("~" = sh-homely ("" + getenv "HOME")))

; (signal sig 1) ignores: a self-INT fizzles
(: me (getpid 0)
   _ (test !(signal sig-int 1))
   _ (still me sig-int)
   _ (test !(signal sig-int 0)))

; a stopped child waits as 256+sig, past every exit status
(: p (spawn ["sleep" "5"])
   _ (still p 19)                                   ; sigstop
   (test ((256 + 19) = wait p)
           (still p sig-cont, still p 9, = 137 (wait p))))

; sigfd takes a signal list; a taken signal is (signo . pid)
(: sp (sigfd [10])
   me (getpid 0)
   _  (still me 10)
   ev (sigtake sp)
   (test (hot? sp) (two? ev) (10 = <ev) (me = >ev)))

; a signal raised as a condition reaches the installed help policy
(hear (\ a b ['gotsig a b]))
(test (['gotsig 'sigusr1 (getpid 0)] = scare 'sigusr1 (getpid 0)))
(hear 0)

; env nifs: set, read back through environ, () unsets
(test !(setenv "LOVE_SH_T5" "quay")
        ("quay" = getenv "LOVE_SH_T5")
        (foldl (\ a e (a ? a (e = "LOVE_SH_T5=quay"))) 0 (environ 0)))
(test !(setenv "LOVE_SH_T5" ())
        ((getenv "LOVE_SH_T5") = ()))
(sh-line shS "sh -c 'exit 7'",
 test (7 = (shS 'sh-status)) ('("7") = (sh-fields shS) [('var . "?")]))
(sh-line shS "export LOVE_SH_T6=pier",
 test ("pier" = getenv "LOVE_SH_T6"))

(t-lushes
 [["echo a b | tr a-z A-Z" "A B\n" 0]
  ["false && echo no || echo yes" "yes\n"]
  ["echo $(echo hi | tr h H) src/apps/lus*.l" "Hi src/apps/lush.l\n"]
  ["sh -c 'echo e >&2' 2>&1 | tr e E" "E\n"]])
(: r (hark ["out/love" "out/lush" "-c" "exit 9"])
   (test (9 = <r)))

; --login reads $HOME/.profile, a scratch HOME here; `return` ends a .-sourced file
(: home0 ("" + getenv "HOME")
   d "out/.lush-t4"
   _ (mkdir d 493)
   p (open (d + "/.profile") "w") _ (say p "LUSH_P4=prof\nexport LUSH_P4\n") _ (close p)
   p (open (d + "/rr.sh") "w") _ (say p "echo one\nreturn 5\necho two\n") _ (close p)
   _ (setenv "HOME" d)
   r1 (hark ["out/love" "out/lush" "--login" "-c" "echo p=$LUSH_P4"])
   r2 (hark ["out/love" "out/lush" "-c" "echo p=[$LUSH_P4]"])
   ; a dash-led argv[0] is a login shell, or any other verb plain
   _ (symlink "../love" (d + "/-lush"))
   _ (symlink "../love" (d + "/-echo"))
   r4 (hark [(d + "/-lush") "-c" "echo p=$LUSH_P4"])
   r5 (hark [(d + "/-echo") "hi"])
   _ (setenv "HOME" home0)
   r3 (hark ["out/love" "out/lush" "-c" ". out/.lush-t4/rr.sh; echo rc=$?"])
   (test ("p=prof\n" = >r1)
           ("p=[]\n" = >r2)
           ("one\nrc=5\n" = >r3)
           ("p=prof\n" = >r4)
           ("hi\n" = >r5)))
; a comment ends at its newline
(t-lushes
 [["# lead\necho a # tail\n# mid\necho b" "a\nb\n"]
  ; a closer on its own line
  ["v=$(\n(\necho deep\n)\n)\necho v=$v" "v=deep\n"]
  ["case x in\na) echo no\n;;\nx) echo yes\n;;\nesac" "yes\n"]
  ; ${x:-word} is quote-aware, and a quoted pattern char in ${v#pat} is inert
  ["echo \"${LUSH_U4:-\"a b\"}\" ${LUSH_U4:-'c d'}" "a b c d\n"]
  ["v='x*y'; echo ${v#\"x*\"} ${v#x?}" "y y\n"]
  ; forkless $( ), lane one: a no-effect builtin writes a worn jug; a function of the
  ; same name takes lane two
  ["cd /; echo \"[$(pwd)][$(pwd)]\"" "[/][/]\n"]
  ["x=$(false); echo $?; y=$(true); echo $?" "1\n0\n"]
  ; chdir's errno is negative, so a failed cd is told by kind (charm?), never by !
  ["cd /definitely-not-here; echo $?" "1\n"]
  ["cd /definitely-not-here && echo moved; echo done" "done\n"]
  ["pwd() { echo shadow; }; echo $(pwd)" "shadow\n"]
  ; lane two: the body runs here down a drained pipe; sh-subsave puts the state back
  ["f() { echo a; echo b; }; x=$(f); echo \"[$x]\"" "[a\nb]\n"]
  ["cd /tmp; echo [$(cd /; pwd)][$(pwd)]" "[/][/tmp]\n"]
  ["v=out; echo [$(v=in; echo $v)][$v]" "[in][out]\n"]
  ["export E=out; echo [$(export E=in; echo $E)][$E]" "[in][out]\n"]
  ["g() { echo G; }; f() { g() { echo I; }; }; echo [$(f; g)][$(g)]" "[I][G]\n"]
  ["set -- keep it; f() { echo $1; }; echo [$(f one)][$1 $2]" "[one][keep it]\n"]])
; a cwd removed under us: pwd and the cd that leaves keep its path, as $PWD has it;
; a parent's stale $PWD is never what that falls back to
(: d (cwd 0 + "/out/t-lushcwd")
   lv (cwd 0 + "/out/love") ls (cwd 0 + "/out/lush")
   _ (test (t-lush ("rm -rf " + d + "; mkdir -p " + d + "/e; cd " + d + "/e; rmdir ../e; pwd; cd ..; pwd; echo $OLDPWD")
            = (d + "/e\n" + d + "\n" + d + "/e\n")))
   _ (test (t-lush ("mkdir -p " + d + "/f; cd " + d + "/f; PWD=/stale " + lv + " " + ls + " -c 'rmdir ../f; pwd'")
            = (d + "/f\n")))
   (t-lush ("rm -rf " + d)))
; ..and on a pty the prompt keeps it
(: (pump src dst) (see src @ -1 0 ch (put dst ch, flush dst, pump src dst))
   (type m s) (: (go i) (? (#s <= i) (flush m) (put m (s i), go (i + 1))) (go 0))
   _ (t-lush "rm -rf out/t-lushcwd; mkdir -p out/t-lushcwd/p")
   r (tether ["out/love" "lush"])
   m >r
   _ (settty m 24 80)
   sink (jug 0)
   t (twirl (_ \ pump m sink) 0)
   _ (rest 600)
   _ (type m "cd out/t-lushcwd/p\n")
   _ (rest 600)
   s1 (slurp sink)
   _ (type m "rmdir ../p\n")
   _ (rest 700)
   s2 (slurp sink)
   _ (still <r 9)
   _ (landed? t ? (catch t) (freeze t))
   _ (t-lush "rm -rf out/t-lushcwd")
   (test (has? s1 "t-lushcwd/p") (has? (snip s2 #s1 #s2) "t-lushcwd/p")))
; ..on a raised exit too. the cwd is put back before the assert, so a red cannot strand
; later tests
(: start (cwd 0)
   r (trap (\ _ (sh-subhere shS (\ _ (chdir "/", scare 'boom 0)))) () (\ a b a))
   here (cwd 0)
   _ (chdir start)
   (test (r = 'boom)
           (start = here)
           !(start = "/")))                    ; not vacuous
; `exit` in a forkless body folds to ('xit . st); a fork under one exits for real
(t-lushes
 [["echo [$(echo x; exit 7; echo y)]; z=$(exit 7); echo $?" "[x]\n7\n"]
  ["f() { exit 9; }; (f); echo after $?" "after 9\n"]
  ; a fork under a forkless body shuts the inherited drainer first, or it stalls
  ["f() { echo hi; }; echo [$(f | tr a-z A-Z)]" "[HI]\n"]
  ["cd /tmp; echo [$( (cd /; pwd) )][$(pwd)]" "[/][/tmp]\n"]
  ; quoted: [tail] would glob a one-letter name in the tree
  ["x=$( (exit 4); echo tail); echo \"[$x]\"" "[tail]\n"]])
; a body past one pipe buffer must not stall against its own reader
(: r (hark ["out/love" "out/lush" "-c" "f() { pwd; cat src/love/*.c; cat src/love/*.c; }; x=$(f); echo ${#x}"])
   t >r
   (test (800000 < sh-int (snip t 0 (#t - 1)))))

; -e in-process: a bad form is a condition handed back, never a raise
(test
 (3 = >(sh-loveval shS "1 + 2"))
 (262144 = >(sh-loveval shS "2 3 4"))
 ("hi" = >(sh-loveval shS "\"hi\""))
 ([1 2 3] = >(sh-loveval shS "[1 2 3]"))
 ('err = <(sh-loveval shS "(1 +"))
 ('unfinished-form = <>(sh-loveval shS "(1 +"))
 ('err = <(sh-loveval shS "nosuchname"))
  ; a string is its bytes; everything else prints sayable
 ("hi" = sh-lovetext "hi")
 ("(1 2 3)" = sh-lovetext [1 2 3])
 ("3" = sh-lovetext 3))

; ${(FORM)}: love's reader finds the extent, so ' is a sigil, ; a comment, ) in "" text
(: w1 (\ sg ('w . [sg]))
   ew ('w . [('lit . "echo")])
   (test
    ([1 ew (w1 ('lov . "(1 + 2)"))] = (sh-lex shS) "echo ${(1 + 2)}")
    ([1 ew ('w . [('lit . "x") ('lov . "(2 3 4)") ('lit . "y")])]
       = (sh-lex shS) "echo x${(2 3 4)}y")
    ([1 ew (w1 ('lov . "(\"}\")"))] = (sh-lex shS) "echo ${(\"}\")}")
    ([1 ew (w1 ('lov . "('a)"))] = (sh-lex shS) "echo ${('a)}")
    (<(sh-lex shS "echo ${(1 +") = 'more)
    (<(sh-lex shS "echo ${(1 + 2)") = 'more)
    ; the nesting scanners step over the body
    ([1 ew (w1 ('sub . "echo ${('a)}"))] = (sh-lex shS) "echo $(echo ${('a)})")
    ([1 ew (w1 ('vop . ["U" ":-" "${('a)}"]))] = (sh-lex shS) "echo ${U:-${('a)}}")
    ([1 ew (w1 ('vop . ["v" "#" "a"]))] = (sh-lex shS) "echo ${v#a}")))

; the value is one field, never split or globbed, like "${x}"
(t-lushes
 [["for w in ${(\"a b c\")}; do echo \"[$w]\"; done" "[a b c]\n"]
  ["echo ${(\"*\")} ${(1 + 2)}" "* 3\n"]
  ; the four seg walks: wseg, dqat, sh-textof, a heredoc
  ["echo ${(1 + 2)} \"[${(2 + 2)}]\" ${UNSET_LV:-${(3 + 3)}}; cat <<E\nsum ${(10 + 5)}\nE" "3 [4] 6\nsum 15\n"]
  ["echo ${(1 + 2 ; a } and a )\n)}" "3\n"]
  ; an error leaves the word empty and the shell running
  ["echo [${(nosuchname)}] 2>/dev/null; echo alive" "[]\nalive\n"]])

; `ev`: the answer on out, its truth bit the status, -n the status alone. `love` is
; not a builtin: it spawns
(test !(sh-bi? "love") (sh-bi? "ev"))
(t-lushes
 [["ev 1 + 2; ev -n 9; echo st=$?" "3\nst=0\n"]
  ["ev 0; echo st=$?; ev 1; echo st=$?" "0\nst=1\n1\nst=0\n"]
  ; quoted, both ways: bare `ev 3 > 2` redirects to a file named 2 and passes
  ["if ev -n '3 > 2'; then echo yes; else echo no; fi
             if ev -n '2 > 3'; then echo yes; else echo no; fi" "yes\nno\n"]
  ["ev '(1 +' 2>/dev/null; echo st=$?; echo alive" "st=1\nalive\n"]
  ["ev '(: zz 7)'; ev zz" "7\n7\n"]          ; in this image: the binding stays
  ["x=$(ev '\"a b\"'); echo \"[$x]\"; echo $(ev '[1 2 3]')" "[a b]\n(1 2 3)\n"]
  ["PATH=$PWD/out:$PATH love -e '1 + 2'" "3\n"]])

; -a: a verb word is ours whatever PATH holds; -p: PATH alone (127); -g, the default:
; PATH first and ours in its gaps. LUSHFLAGS carries it to a child shell
(test (1 = (sh-envflag shS) 0))
(: r (hark ["out/love" "out/lush" "-a" "-c" "PATH=/nonexistent; printf abc | tr a-c A-C; echo; tr 2>/dev/null; echo st=$?"])
   (test ("ABC\nst=2\n" = >r)))
; under -p echo is PATH's too, so PATH comes back before it
(: r (hark ["out/love" "out/lush" "-p" "-c" "p=$PATH; PATH=/nonexistent; tr 2>/dev/null; s=$?; PATH=$p; echo st=$s"])
   (test ("st=127\n" = >r)))
(: r (hark ["out/love" "out/lush" "--precarious" "-c" "p=$PATH; PATH=/nonexistent; tr 2>/dev/null; s=$?; PATH=$p; echo st=$s"])
   (test ("st=127\n" = >r)))
(: r (hark ["out/love" "out/lush" "-c"
            "export p=$PATH; PATH=/nonexistent; LUSHFLAGS=-p sh -c 'tr 2>/dev/null; s=$?; PATH=$p; echo st=$s'; LUSHFLAGS=-p sh -a -c 'tr 2>/dev/null; echo st=$?'; LUSHFLAGS=-p sh -g -c 'tr 2>/dev/null; echo st=$?'"])
   (test ("st=127\nst=2\nst=2\n" = >r)))
; -g: a PATH that names the word wins it; -a passes it by
(: r (hark ["out/love" "out/lush" "-a" "-c"
            "export d=/tmp/lush-t-greg; mkdir -p $d; printf '#!/bin/sh\\necho theirs\\n' > $d/tr; chmod 755 $d/tr
             LUSHFLAGS=-g sh -c 'p=$PATH; PATH=/nonexistent; tr 2>/dev/null; echo st=$?; PATH=$d:$p; tr'
             PATH=$d:$PATH; tr 2>/dev/null; echo st=$?; rm -r $d"])
   (test ("st=2\ntheirs\nst=2\n" = >r)))
; `set --autonomous` and kin move a running shell
(: r (hark ["out/love" "out/lush" "-g" "-c"
            "export d=/tmp/lush-t-setm; mkdir -p $d; printf '#!/bin/sh\\necho theirs\\n' > $d/tr; chmod 755 $d/tr
             PATH=$d:$PATH; tr; set --autonomous; tr 2>/dev/null; echo st=$?; set --gregarious; tr
             set --precarious; p=$PATH; PATH=/nonexistent; tr 2>/dev/null; s=$?; PATH=$p; echo st=$s; rm -r $d"])
   (test ("theirs\nst=2\ntheirs\nst=127\n" = >r)))

; under -a a #! interpreter named as our verb runs as ours; -g and -p exec it as spelled
(: r (hark ["out/love" "out/lush" "-a" "-c"
            "d=/tmp/lush-t-bang; mkdir -p $d
             printf '#!/nonexistent/sh\\necho sh $1\\n' > $d/a; printf '#!/nonexistent/env sh\\necho env\\n' > $d/b
             printf '#!/nonexistent/awk -f\\nBEGIN { print \"awk\" }\\n' > $d/c; printf '#!/nonexistent/notaverb\\necho no\\n' > $d/e
             chmod 755 $d/a $d/b $d/c $d/e; $d/a x; $d/b; $d/c; PATH=$d:$PATH; a y; $d/e 2>/dev/null || echo st=$?
             LUSHFLAGS=-g sh -c '$d/a 2>/dev/null || echo g=$?'; LUSHFLAGS=-p sh -c '$d/a 2>/dev/null || echo p=$?'; rm -r $d"])
   (test ("sh x\nenv\nawk\nsh y\nst=127\ng=127\np=127\n" = >r)))

; `which`, `type` and `command -v` name what would run, by sh-verdict
(test (sh-bi? "which") (sh-bi? "where") (sh-bi? "type"))
(t-lushes
 [["f() { :; }
             type if; type cd; type f
             which if; which cd; which f; command -v f" "if is a shell reserved word\ncd is a shell builtin\nf is a shell function\nif\ncd\nf\nf\n"]
  ; a miss is 1 (command -v silent), and one miss among operands fails the command
  ["which nosuchtool 2>/dev/null; echo st=$?
             command -v nosuchtool; echo st=$?
             type pwd nosuchtool 2>/dev/null; echo st=$?" "st=1\nst=1\npwd is a shell builtin\nst=1\n"]])
; ..and the mode: under -a an empty PATH answers the binary sh-spawnv would exec
(: r (hark ["out/love" "out/lush" "-a" "-c"
            "PATH=/nonexistent
             a=$(which tr); b=$(ev '(selfpath 0)')
             [ \"$a\" = \"$b\" ] && echo seat || echo other
             c=$(type tr); [ \"$c\" = \"tr is a verb of $b\" ] && echo verb || echo other
             d=$(which -a tr); [ \"$d\" = \"$a\" ] && echo only || echo other
             e=$(where tr); [ \"$e\" = \"$d\" ] && echo where || echo other"])
   (test ("seat\nverb\nonly\nwhere\n" = >r)))
; `dir` is a second name on ls, so it runs in-image and reads as ours
(: r (hark ["out/love" "out/lush" "-c" "PATH=/nonexistent; dir /; type dir"])
   (: s (hark ["out/love" "out/lush" "-c" "PATH=/nonexistent; ls /"])
      (test (>s = snip >r 0 #>s)
              (elem 'verb (sh-verdict shS "dir")))))
(: r (hark ["out/love" "out/lush" "-p" "-c"
            "p=$PATH; PATH=/nonexistent; which tr 2>/dev/null; s=$?; PATH=$p; echo st=$s"])
   (test ("st=1\n" = >r)))
; ..and -g answers this binary where PATH finds nothing
(: r (hark ["out/love" "out/lush" "-g" "-c"
            "p=$PATH; PATH=/nonexistent; a=$(which tr); PATH=$p; b=$(ev '(selfpath 0)'); [ \"$a\" = \"$b\" ] && echo seat || echo other"])
   (test ("seat\n" = >r)))
; the in-image lane: tools that answer a status rather than quit
(test (all (\ w (two? (sh-imgfn shS w)))
             '("nm" "ar" "ld" "as" "readelf" "strip" "libra" "fat" "mkfs.vfat" "mkdosfs"
               "vdir" "sha1sum" "who" "chgrp" "truncate")))
; ..but not stdin readers (tar too): in here ^C would kill the shell
(test (all (\ w !(two? (sh-imgfn shS w))) '("gzip" "gunzip" "zcat" "cpio" "sort" "tar")))
; a failure is one command's status, and the line after it runs
(: r (hark ["out/love" "out/lush" "-a" "-c"
            "tar xzf /nonexistent.tgz . 2>/dev/null; echo t=$?
             libra /nonexistent-xyz.l 2>/dev/null; echo l=$?
             mkfs.vfat 2>/dev/null; echo m=$?
             echo alive"])
   (test ("t=2\nl=1\nm=2\nalive\n" = >r)))
; ..and a main's early answer too: mooncc's --version leaves, never quits
(: r (hark ["out/love" "out/lush" "-a" "-c" "mooncc --version > /dev/null; mooncc -h > /dev/null; echo alive"])
   (test ("alive\n" = >r)))
; a capture of one takes the jug: no pipe, fd or child
(: pr (sh-parse-line shS "which cc")
   (test ('jug = (sh-lane shS) >pr) ('jug = (sh-lane shS >(sh-parse-line shS "type cc")))))

; on a pty: an in-image stage forks into its own process group, so a pipeline is one
; group and fg resumes it
(: (sh-t-pump src dst) (see src @ -1 0 ch (put dst ch, flush dst, sh-t-pump src dst))
   (sh-t-type m s) (: (go i) (? (#s <= i) (flush m) (put m (s i), go (i + 1))) (go 0))
   e (string 27)
   ; the pager, the forked half, keeps the terminal
   r (tether ["out/love" "lush"])
   m >r
   _ (settty m 24 80)
   sink (jug 0)
   t (twirl (_ \ sh-t-pump m sink) 0)
   _ (rest 600)
   _ (sh-t-type m "ls | less\n")
   _ (rest 900)
   s1 (slurp sink)                      ; cumulative: a jug's slurp does not drain it
   _ (sh-t-type m "q")
   _ (rest 600)
   s2 (slurp sink)
   _ (still <r 9)
   _ (landed? t ? (catch t) (freeze t))
   ; ..and ^Z stops a forked job, fg runs it out
   r2 (tether ["out/love" "lush"])
   m2 >r2
   _ (settty m2 24 80)
   sink2 (jug 0)
   t2 (twirl (_ \ sh-t-pump m2 sink2) 0)
   _ (rest 600)
   _ (sh-t-type m2 "sleep 2\n")
   _ (rest 500)
   _ (sh-t-type m2 (string 26))         ; ^Z
   _ (rest 700)
   j1 (slurp sink2)
   _ (sh-t-type m2 "fg\n")
   _ (rest 2500)
   _ (sh-t-type m2 "echo st=$?\n")
   _ (rest 700)
   j2 (slurp sink2)
   ; ..and a ( ) is one job of the shell above
   _ (sh-t-type m2 "( sleep 2 ; echo w''oke )\n")   ; typed w''oke, printed woke
   _ (rest 500)
   _ (sh-t-type m2 (string 26))         ; ^Z
   _ (rest 700)
   _ (sh-t-type m2 "jobs\n")
   _ (rest 500)
   j3 (slurp sink2)
   _ (sh-t-type m2 "fg\n")
   _ (rest 2500)
   _ (rest 700)
   j4 (slurp sink2)
   _ (still <r2 9)
   _ (landed? t2 ? (catch t2) (freeze t2))
   (test
    (has? s1 (e + "[?1049h"))      ; the pager opened
    !(has? s1 (e + "[?1049l"))
    (has? s2 (e + "[?1049l"))      ; ..and q reached it
    (has? j1 "stopped")
    (has? j2 "st=0")
    (has? j3 "] stopped  ( sleep")
    !(has? j4 "no such job")
    (has? j4 "woke")))

; a $( ) of a roster word: the jug, or the pipe lane when it wants an fd; a spelled
; path spawns
(: (lane s) (sh-lane shS >(sh-parse >(sh-lex shS s)))
   (test ('jug = lane "date") ('sub = lane "date 2>/dev/null") ('ext = lane "/bin/date")
         ('sub = lane "cat") ('ext = lane "gzip") ('jug = lane "echo hi") ('sub = lane "cd /")
         ('jug = lane "pwd")))
(: r (hark ["out/love" "out/lush" "-c"
            "v=$(expr 1 + 2); w=$(printenv LUSH_UNSET_QQ 2>/dev/null); echo $? v=$v w=[$w]"])
   (test ("1 v=3 w=[]\n" = >r)))

; kill, umask and getopts act on this shell's tables; %N, %% and %+ name jobs for fg too
(test (1 = (sh-jobspec shS) "1") (1 = (sh-jobspec shS) "%1") (0 = (sh-jobspec shS) "%%") (0 = (sh-jobspec shS) "%+")
      (15 = sh-sigof "TERM") (15 = sh-sigof "SIGTERM") (9 = sh-sigof "9") (atom? (sh-sigof "BOGUS")))
(t-lushes
 [["sleep 5 & kill %1; wait $!; echo st=$?; sleep 5 & kill -9 %%; wait $!; echo st=$?; sleep 5 & kill -s TERM -- $!; wait $!; echo st=$?; kill %7; echo st=$?" "st=143\nst=137\nst=143\nst=1\n"]
  ["umask 022; umask; umask -S; umask 077; umask; umask 8 || echo st=$?" "0022\nu=rwx,g=rx,o=rx\n0077\nst=1\n"]
  ["set -- -ab val -c x y; while getopts ab:c o; do echo \"$o:${OPTARG-}\"; done; shift $((OPTIND-1)); echo \"[$@]\"" "a:\nb:val\nc:\n[x y]\n"]
  ["set -- -a -z -b; while getopts :ab: o; do echo \"$o:${OPTARG-}\"; done; set -- -a -- -b; OPTIND=1; getopts ab o; getopts ab o; echo \"$o st=$? $OPTIND\"" "a:\n?:z\n::b\n? st=1 3\n"]])

; the fork lane takes this binary's path or a script whose #! names it, with the same
; command line; a foreign one execs
(: seat (sh-seat ())
   (put p t) (: h (open p "w") _ (say h t) _ (close h) (cite 'posix 'chmod p 493))
   ours "/tmp/lush-t-ours.l" sh "/tmp/lush-t-sh.l"
   _ (put ours ("#!" + seat + "\n(puts (show (cup cmdline)), puts \"\\n\")\n"))
   _ (put sh "#!/bin/sh\necho sh\n")
   r (hark ["out/love" "out/lush" "-c" (ours + " a b </dev/null; " + sh + " </dev/null")])
   _ (test (1 = (sh-forkask shS) seat) (1 = (sh-forkask shS) ours) (0 = (sh-forkask shS) sh) (0 = (sh-forkask shS) "/bin/date")
           (("(\"" + ours + "\" \"a\" \"b\")\nsh\n") = >r))
   (unlink ours, unlink sh))
; a stdin reader forks only while the shell has read none of stdin (read-ahead would
; repeat), or with its own stdin redirected
(: tty0 (shS 'sh-tty) in0 (shS 'sh-inread)
   _ (pin shS 'sh-tty 0)
   _ (pin shS 'sh-inread 0)
   a (sh-forkok? shS ["cat" "f"] ())
   _ (pin shS 'sh-inread 1)
   b (sh-forkok? shS ["cat" "f"] ())
   c (sh-forkok? shS ["cat"] [(0 . 5)])
   ; ..and a foreign bare word spawns as (path . word); no #!, or it would run in-image
   fd (cwd 0 + "/out/.sh-foreign") fp (fd + "/sh-foreign")
   _ (mkdir fd 493)
   _ (: q (open fp "w") _ (say q "exit 0\n") (close q))
   _ (chmod fp 493)
   p0 (getenv "PATH")
   _ (setenv "PATH" (fd + ":" + p0))
   w (sh-whichp shS "sh-foreign")
   v (sh-spawnv shS ["sh-foreign" "--version"])
   d (two? w && <v = (<>w . "sh-foreign") && >v = ["--version"])
   _ (setenv "PATH" p0)
   _ (unlink fp) _ (rmdir fd)
   _ (pin shS 'sh-tty tty0)
   _ (pin shS 'sh-inread in0)
   (test (1 = a) (0 = b) (1 = c) (1 = d)))

; a verb whose trait says builtin is one in every mode, ahead of PATH
(: r (hark ["out/love" "out/lush" "-p" "-c" "PATH=/nonexistent; echo hi; printf '%s\\n' pf; [ a = a ] && test 1 = 1 && echo t; type echo"])
   (test ("hi\npf\nt\necho is a shell builtin\n" = >r)))
(: T (cite 'verbs 'trait)
   (test (1 = sh-verbbi? "echo") (1 = sh-verbbi? "[") (0 = sh-verbbi? "ls")
         (1 = T 'mooncc 'self) (1 = T 'fat 'self) (0 = T 'tar 'self) (lit? (T 'cat 'self))))
; a reader runs as self only when every operand is a regular file
(: f "test/00-init.l"
   (test (1 = (sh-selfcall? shS) ["wc" "-l" f f]) (1 = (sh-selfcall? shS) ["sha256sum" f])
         (0 = (sh-selfcall? shS) ["wc"]) (0 = (sh-selfcall? shS) ["wc" "-"]) (0 = (sh-selfcall? shS) ["wc" f "/nonexistent-qq"])
         (0 = (sh-selfcall? shS) ["md5sum" "/dev/zero"]) (1 = (sh-selfcall? shS) ["cat" f]) (0 = (sh-selfcall? shS) ["cat"])
         ; the filters ask their own parsers
         (1 = (sh-selfcall? shS) ["head" "-n" "5" f]) (0 = (sh-selfcall? shS) ["head" "-n" "5"])
         (1 = (sh-selfcall? shS) ["tail" "-n" "+3" f]) (0 = (sh-selfcall? shS) ["tail" "-n" "bogus" f])
         (1 = (sh-selfcall? shS) ["cut" "-d" ":" "-f" "1" f]) (0 = (sh-selfcall? shS) ["cut" "-f" "1"])
         (1 = (sh-selfcall? shS) ["grep" "x" f]) (0 = (sh-selfcall? shS) ["grep" "x"]) (1 = (sh-selfcall? shS) ["grep" "-e" "x" f])
         (0 = (sh-selfcall? shS) ["grep" f])
         (1 = (sh-selfcall? shS) ["ls" "-l"]) (0 = (sh-selfplain? shS) "wc") (1 = (sh-selfplain? shS) "ls")))
; a big in-image capture parks on a full pipe, so the drain gets its turn
(: r (hark ["out/love" "out/lush" "-a" "-c" "f() { cat src/love/*.c; cat src/love/*.c; }; x=$(f); echo ${#x}"])
   (test (0 < #(>r))))
; exec spawns (path . word): the child named as spelled, a miss 127
(: r (hark ["out/love" "out/lush" "-g" "-c" "exec cat /nonexistent-qq 2>&1"])
   (test (1 = <r) ("cat: " = snip >r 0 5)))
(: r (hark ["out/love" "out/lush" "-g" "-c" "exec nope-qq-cmd 2>/dev/null"])
   (test (127 = <r)))
; a crew main answers its status to an in-image caller, a deep failure too
(: C (cite 'verbs 'call)
   (test (1 = C 'cook ["-f" "/nonexistent-qq.mk"]) (2 = C 'sb ["no-such-verb"])
         (2 = C 'httpd ["-z"])))
; a trait may turn on the call: love's bake and wake exec, by a path to this binary too
(: H (cite 'verbs 'holds)
   (test (1 = H 'love 'exec ["bake"]) (1 = H 'love 'exec ["wake" "x"]) (0 = H 'love 'exec ["-e" "1"])
         (1 = sh-exec? ["out/love" "bake"]) (0 = sh-exec? ["out/love" "ls"])
         (0 = (sh-forkok? shS) ["out/love" "bake"] [(0 . 5)])))

; a readonly assignment is fatal to a script, from every setter
(t-lushes
 [["readonly R=1 S; readonly; R=2; echo after" "readonly R='1'\nreadonly S\n" 2]
  ["readonly R=1; unset R; echo after" "" 2]
  ["f() { local R=9; echo in; }; readonly R=1; f; echo after" "" 2]
  ; an alias expands in a capture and a stage, stops at its own name, may open with an assignment
  ["alias ll='echo L'; ll a; x=$(ll b); echo [$x]; ll p | cat; alias; alias echo='echo E'; echo x; alias e='V=7 echo'; e y; echo [$V]; unalias -a; alias bad='a | b'; echo st=$?" "L a\n[L b]\nL p\nalias ll='echo L'\nE x\ny\nE []\nst=1\n"]
  ["alias zz-qq='echo L'; type zz-qq; command -v zz-qq; unalias zz-qq; type zz-qq" "zz-qq is an alias for echo L\nalias zz-qq='echo L'\n" 1]])
; times: two POSIX lines; hash remembers and forgets PATH's winners
(: r (hark ["out/love" "out/lush" "-c" "times"])
   (test (2 = #(lines >r)) (all (\ l ("m" = snip l 1 2)) (lines >r))))
(t-lushes
 [["hash -r; hash; hash nosuch-qq; echo st=$?; hash sh; hash | sed 's/=.*//'; hash -r; hash" "st=1\nsh\n"]
  ; ulimit -n sets both bounds, -S the soft, -H reads the hard
  ["ulimit -n 1000; ulimit -n; ulimit -Sn 500; ulimit -n; ulimit -Hn; ulimit -z; echo st=$?; ulimit -n abc; echo st=$?" "1000\n500\n1000\nst=1\nst=1\n"]])

; the line editor moves and deletes a utf-8 character whole
(: (pump src dst) (see src @ -1 0 ch (put dst ch, flush dst, pump src dst))
   (type m s) (: (go i) (? (#s <= i) (flush m) (put m (s i), go (i + 1))) (go 0))
   e (string 27)
   r (tether ["out/love" "lush"])
   m >r
   _ (settty m 24 80)
   sink (jug 0)
   t (twirl (_ \ pump m sink) 0)
   _ (rest 600)
   _ (type m "printf '%s|\\n' a日本b")
   _ (type m (e + "[D" + e + "[D"))
   _ (type m (string 127))                 ; takes 日
   _ (type m "\n")
   _ (rest 700)
   s (slurp sink)
   _ (still <r 9)
   _ (landed? t ? (catch t) (freeze t))
   (test (has? s "a本b|") !(has? s "a日本b|") !(has? s "\xef\xbf\xbd")))

; an arrow in application cursor mode (ESC O A, as a remote shell leaves the terminal) walks
; the history as ESC [ A does, and a command that sets the mode finds it reset at the next
; prompt; a scratch HOME keeps the history
(: (pump src dst) (see src @ -1 0 ch (put dst ch, flush dst, pump src dst))
   (type m s) (: (go i) (? (#s <= i) (flush m) (put m (s i), go (i + 1))) (go 0))
   e (string 27)
   home0 ("" + getenv "HOME")
   d "out/.lush-t13"
   _ (hark ["out/love" "out/lush" "-c" ("mkdir -p " + d + "; rm -f " + d + "/.lush_history")])
   _ (setenv "HOME" d)
   r (tether ["out/love" "lush"])
   _ (setenv "HOME" home0)
   m >r
   _ (settty m 24 80)
   sink (jug 0)
   t (twirl (_ \ pump m sink) 0)
   _ (rest 600)
   _ (type m "echo ss3''-up\r")
   _ (rest 500)
   _ (type m (e + "OA\r"))
   _ (rest 700)
   _ (type m "printf '\\033[?1h\\033='\r")
   _ (rest 700)
   s (slurp sink)
   _ (still <r 9)
   _ (landed? t ? (catch t) (freeze t))
   n (findsub s "ss3-up")
   k (findsub s (e + "[?1h" + e + "="))
   (test (0 <= n) (has? (snip s (n + 1) #s) "ss3-up") !(has? s "OA: not found")
         (0 <= k) (has? (snip s k #s) (e + "[?1l" + e + ">"))))

; PATH unset searches the default path, never the cwd
(: r (hark ["out/love" "out/lush" "-c" "d=out/.lush-t9; mkdir -p $d; printf '#!/bin/sh\\necho planted\\n' > $d/zz-qq-plant; chmod 755 $d/zz-qq-plant; cd $d; unset PATH; zz-qq-plant; echo st=$?"])
   (test ("st=127\n" = >r)))
; the prompt shows a control byte as ^X
(test ("a^[^Gb^?" = sh-vis ("a" + string 27 + string 7 + "b" + string 127))
      ("~/x" = sh-vis "~/x"))
; a fresh history is 0600
(: home0 ("" + getenv "HOME")
   d "out/.lush-t10"
   _ (hark ["out/love" "out/lush" "-c" ("mkdir -p " + d + "; rm -f " + d + "/.lush_history")])
   _ (setenv "HOME" d)
   _ (sh-histput shS "echo zz")
   _ (sh-histput shS "echo yy")
   st (stat (d + "/.lush_history"))
   _ (setenv "HOME" home0)
   (test (two? st) (384 = (511 & (st 2)))))

; a bracketed paste runs nothing until an enter
(: (pump src dst) (see src @ -1 0 ch (put dst ch, flush dst, pump src dst))
   (type m s) (: (go i) (? (#s <= i) (flush m) (put m (s i), go (i + 1))) (go 0))
   e (string 27)
   f "out/.lush-t11"
   _ (hark ["out/love" "out/lush" "-c" ("rm -f " + f)])
   r (tether ["out/love" "lush"])
   m >r
   _ (settty m 24 80)
   sink (jug 0)
   t (twirl (_ \ pump m sink) 0)
   _ (rest 600)
   _ (type m (e + "[200~touch " + f + "\necho pasted-" + "ran\n" + e + "[201~"))
   _ (rest 700)
   early (two? (stat f))
   _ (type m "\r")
   _ (rest 700)
   late (two? (stat f))
   s (slurp sink)
   _ (still <r 9)
   _ (landed? t ? (catch t) (freeze t))
   (test !early late (has? s "pasted-ran") (has? s (e + "[?2004h"))))

; a redirect onto a fifo opens in the child, so the shell can open the other end;
; a failure hangs, hence the timeout
(: d "out/.lush-t12"
   _ (mkdir d 493)
   (fl s) (hark ["out/love" "timeout" "20" "out/love" "out/lush" "-c"
                 ("d=" + d + "; rm -f $d/f; mkfifo $d/f; " + s)])
   r1 (fl "cat < $d/f > $d/o & p=$!; exec 3> $d/f; echo hi >&3; exec 3>&-; wait $p; echo \"r $(cat $d/o)\"")
   r2 (fl "echo x > $d/s; cat $d/s > $d/f & p=$!; r=$(cat $d/f); wait $p; echo \"w $r\"")
   r3 (fl "{ cat; } < $d/f > $d/o & p=$!; echo grp > $d/f; wait $p; echo \"g $(cat $d/o)\"")
   r4 (fl "out/love cat < $d/f > $d/o & p=$!; echo warm > $d/f; wait $p; echo \"v $(cat $d/o)\"")
   r5 (fl "exec 2>&1; cat < $d/nope; echo st=$?")
   r6 (fl "exec 2>&1; chmod 0 $d/f; cat < $d/f & wait $!; echo st=$?; out/love cat < $d/f & wait $!; echo st=$?")
   no ("lush: " + d + "/f: cannot open\n")
   ; a builtin's redirect inside $( ) lands on the fd, not the capture
   r7 (fl "x=$(exec 3> $d/o; printf 'p\\n' >&3; echo e > $d/s; { echo g; } > $d/t; echo body); echo \"[$x] $(cat $d/o $d/s $d/t)\"")
   (test ("r hi\n" = >r1) ("w x\n" = >r2) ("g grp\n" = >r3) ("v warm\n" = >r4)
         (("lush: " + d + "/nope: cannot open\nst=1\n") = >r5)
         (getuid 0 = 0 || (no + "st=1\n" + no + "st=1\n") = >r6)
         ("[body] p\ne\ng\n" = >r7)))

; `read` off a pipe takes one line; a new stdin, or `exec 0<`, drops the read-ahead
(: (sh1 s) (hark ["out/love" "timeout" "20" "out/love" "out/lush" "-c" s])
   r1 (sh1 "printf '0:a\\n3:b\\n6:c|d\\n' | while IFS=: read -r v w; do echo \"$w\" | tr '|' '\\n' | while read -r x; do echo \"$v $x\"; done; done")
   r2 (sh1 "printf 'one\\ntwo\\nthree\\n' | { read a; cat; read c; echo \"a=$a c=$c\"; }")
   r3 (sh1 "printf 'p\\nq\\n' | { read a; exec 0< /dev/null; read b; echo \"a=$a b=[$b]\"; }")
   r4 (sh1 "printf 'printf \"x\\\\n\" | while read b; do echo b=$b; done\\necho end\\n' | out/love out/lush")
   (test ("0 a\n3 b\n6 c\n6 d\n" = >r1)
         ("two\nthree\na=one c=\n" = >r2)
         ("a=p b=[]\n" = >r3)
         (has? >r4 "b=x\n") !(has? >r4 "b=echo") (has? >r4 "end\n")))

; the shell's own fds sit at 10 and up; 3 to 9 are the user's
(: d "out/.lush-t12"
   p (open (d + "/fd.sh") "w")
   _ (say p "a=$(ls /proc/$$/fd); b=$(x=$(ls /proc/$$/fd); echo $x); echo $a $b\n")
   _ (close p)
   ; /bin/sh sheds the gate's own fds first
   r (hark ["/bin/sh" "-c" "exec 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&-; exec out/love timeout 20 out/love out/lush \"$0\""
            (d + "/fd.sh")])
   s (" " + snip >r 0 (#>r - 1) + " ")
   (test (has? s " 0 ") (has? s " 2 ") (all (w \ !(has? s (" " + w + " "))) ["3" "4" "5" "6" "7" "8" "9"])))

; a builtin's redirect lands in the file even while the shell wears its own `out`
(: sw-f "/tmp/lush-wear-law"
   sw-j (jug 0) sw-w (worn ())
   _ (wear [() sw-j ()])
   _ ((cite 'lush 'sh-line) ((cite 'lush 'sh-new) 0) ("echo a >" + sw-f + "; echo b"))
   _ (flush out)
   _ (wear sw-w)
   sw-q (open sw-f "r") sw-t (slurp sw-q) _ (close sw-q) _ (unlink sw-f)
   sw-o (slurp sw-j)
   (test ("a\n" = sw-t) ("b\n" = sw-o)))

(test_fin ())
(puts "sh: ok") (putc 10)
