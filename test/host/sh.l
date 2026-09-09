; --- test/host/sh.l: lush's gate -- the lexer / grammar / expansion / glob pure
; functions, the job-control nifs (signal / wait's stop lane / sigfd's signal
; list: doc/misc/posix.md step 4, signals arriving as conditions), and the built
; shell driven end to end through out/love (never env's PATH love). the
; interactive loop needs a pty (probed live, the berth pattern); everything
; beneath it gates headless here. the one file reads bare; its seat stays
; quiet under the corpus (no lush on cmdline).
; run: cat test/00-init.l test/host/sh.l | out/love
(reads (open "apps/lush.l" "r"))
(borrow 'lush) ; the parts just registered module 'lush -- the laws below read it spliced

; the lexer: glued operators, io-numbers out of band ((), or (n) attached),
; quotes as segments, # comments, the 'more protocol on an unfinished shape.
; (the reader has no dotted-pair syntax, so expecteds are BUILT, not quoted.)
(: lw (\ s (. 'w [(. 'lit s)]))
   rdt (\ ion o (. 'rd (. ion o)))
   opt (\ o (. 'op o))
   (test
    (= [1 (lw "a") (lw "b")] (sh-lex " a  b "))
    (= [1 (. 'w [(. 'sq "x  y")])] (sh-lex "'x  y'"))
    (= [1 (. 'w [(. 'lit "a") (. 'dq [(. 'lit "b c")]) (. 'lit "d")])]
       (sh-lex "a\"b c\"d"))
    (= [1 (lw "a") (rdt () ">") (lw "b")] (sh-lex "a>b"))
    (= [1 (lw "x") (rdt [2] ">&") (lw "1")] (sh-lex "x 2>&1"))
    (= [1 (lw "a") (opt "&&") (lw "b")] (sh-lex "a&&b"))
    (= [1 (lw "a") (opt ";") (lw "b")] (sh-lex "a; b"))
    (= [1 (lw "a")] (sh-lex "a # rest dies"))
    (= [1 (. 'w [(. 'var "HOME")])] (sh-lex "$HOME"))
    (= [1 (. 'w [(. 'dq [(. 'lit "v=") (. 'var "V")])])] (sh-lex "\"v=$V\""))
    (= [1 (. 'w [(. 'sub "echo hi")])] (sh-lex "$(echo hi)"))
    (= [1 (. 'w [(. 'sub "date")])] (sh-lex "`date`"))
    ((cap (sh-lex "echo 'x")) = 'more)
    ((cap (sh-lex "echo \\")) = 'more)
    ; an empty payload is a parse, not a failure. A (payload . j) answer nets
    ; its head alone -- the improper tail is out of the sum -- so "" , `` and a
    ; heredoc owed no lines all net zero, and a truth test called each of them
    ; unfinished: `echo ""` asked PS2 for a line nobody owed. The kind says it.
    (= [1 (lw "echo") (. 'w [(. 'dq ())])] (sh-lex "echo \"\""))
    (= [1 (lw "echo") (. 'w [(. 'lit "a") (. 'dq ()) (. 'lit "b")])]
       (sh-lex "echo a\"\"b"))
    (= [1 (lw "echo") (. 'w [(. 'sub "")])] (sh-lex "echo ``"))
    (= [1 (lw "cat") (rdt () "<h") (. 'w [(. 'dq ())]) (opt "nl")]
       (sh-lex "cat <<E\nE\n"))
    ; ..and the same law inside a vop word, where the fallback was silent: the
    ; quotes stayed in the text instead of removing
    (= [(. 'dq ())] (sh-wordize "\"\""))
    (= [(. 'sub "")] (sh-wordize "``"))))

; the grammar: pipelines under && under ; -- and & backgrounds only its own
; and_or; a dangling && is parse-'more (the PS2 lane); compounds refuse politely
(: pr (sh-parse (cup (sh-lex "a | b && c ; d &")))
   a (cup pr)
   (test ((cap pr) = 'ok) ((cap a) = 'seq)
           ((cap (a 1)) = 'and)
           ((cap ((a 1) 1)) = 'pipe)
           ((cap (a 2)) = 'bg)))
(: pr (sh-parse (cup (sh-lex "a | b")))
   a (cup pr)
   (test ((cap a) = 'pipe) (= 2 (tally (a 1)))))
(: pr (sh-parse (cup (sh-lex "! false")))
   (test ((cap (cup pr)) = 'not)))
(test ((cap (sh-parse (cup (sh-lex "a &&")))) = 'more)
        ((cap (sh-parse (cup (sh-lex "( x )")))) = 'ok))

; rung 3: compounds parse (and stay 'more while open), ${..} lexes as vop,
; heredocs rewrite to <h with the body as the target word
(: pr (sh-parse (cup (sh-lex "if a; then b; fi")))
   (test ((cap pr) = 'ok) ((cap (cup pr)) = 'if)))
(: pr (sh-parse (cup (sh-lex "while a; do b; done < f")))
   (test ((cap pr) = 'ok) ((cap (cup pr)) = 'rdr)))
(: pr (sh-parse (cup (sh-lex "case x in a|b) c;; esac")))
   (test ((cap pr) = 'ok) ((cap (cup pr)) = 'case)))
(: pr (sh-parse (cup (sh-lex "f() { x; }")))
   (test ((cap pr) = 'ok) ((cap (cup pr)) = 'fun)))
(test ((cap (sh-parse (cup (sh-lex "if a; then b")))) = 'more)
        ((cap (sh-parse (cup (sh-lex "for f in")))) = 'more)
        (= '(1 (w (vop "x" ":-" "y"))) (: r (sh-lex "${x:-y}") r)))
(: lx (sh-lex "cat <<EOF\nbody\nEOF")
   t (cup lx)
   (test (= 1 (cap lx))
           ((cap (caup t)) = 'rd)                      ; (rd () . "<h")
           (= "<h" (cup (cup (caup t))))))

; rung 3, end to end through the built shell: control flow, functions,
; positionals, ${}, heredocs, subshells, set -u
(: r (hark ["out/love" "out/lush" "-c" "for f in a b; do echo f=$f; done"])
   (test (= "f=a\nf=b\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "f() { echo n=$# one=$1; return 3; }; f x y; echo rc=$?"])
   (test (= "n=2 one=x\nrc=3\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "case q.l in *.c) echo c;; *.l) echo l;; esac"])
   (test (= "l\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "p=a/b.l; echo ${p%.l} ${p#a/} ${U:-dflt} ${#p}"])
   (test (= "a/b b.l dflt 5\n" (cup r))))
(: _ (setenv "LUSH_HD" "quay")
   r (hark ["out/love" "out/lush" "-c" "cat <<EOF | tr a-z A-Z\nhd $LUSH_HD\nEOF"])
   (test (= "HD QUAY\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "( exit 5 ); echo sub=$?"])
   (test (= "sub=5\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "set -u; echo $LUSH_UNDEF_QQ; echo no"])
   (test (! (= 0 (cap r)))))

; $(( .. )): C's operators at C's precedence, the bases, and truncation toward
; zero (love's // IS C's division; only >> wanted the floor spelled out)
(: r (hark ["out/love" "out/lush" "-c"
            "n=5; echo $((n*2)) $((2+3*4)) $(((2+3)*4)) $((0x1f)) $((010)) $((-7/2)) $((7%3))"])
   (test (= "10 14 20 31 8 -3 1\n" (cup r))))
; ..the tally that a whole gate's summary line rides on; && not taking the side it
; must not (a live 100/x would be the divide by zero); and the text expanding
; before the read, so a $( ) inside is part of one expression
(: r (hark ["out/love" "out/lush" "-c"
            "i=0; i=$((i+1)); i=$((i+1)); x=0; echo $i $((x!=0 && 100/x)) $(( $(echo 6) * 7 ))"])
   (test (= "2 0 42\n" (cup r))))

; trap exit: once, at the end, and the status the shell was leaving with -- a
; `false` under a cleanup is still a 1, however well the cleanup went
(: r (hark ["out/love" "out/lush" "-c" "trap 'echo bye' EXIT; echo hi"])
   (test (= "hi\nbye\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "trap 'echo bye' EXIT; false"])
   (test (= "bye\n" (cup r)) (= 1 (cap r))))
; ..and a forked subshell runs neither: POSIX resets a caught condition there, or
; `( exit )` would take the parent's temp dir while the parent was still working
(: r (hark ["out/love" "out/lush" "-c" "trap 'echo bye' EXIT; (exit 0); echo after"])
   (test (= "after\nbye\n" (cup r))))

; a signal condition is delivered. sigfd blocks INT and queues it to an fd, the
; drain after the foreground command reads it, and the action runs -- the whole
; lane, with no race to lose, because the shell signals itself. the second line
; is the one that would catch a shell left blocked with nothing reading: after the
; trap fires the shell must still be alive and answering.
(: r (hark ["out/love" "out/lush" "-c" "trap 'echo CAUGHT' INT; kill -INT $$; echo done"])
   (test (= "CAUGHT\ndone\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "trap 'echo T' TERM; kill -TERM $$; trap; echo alive"])
   (test (= "T\ntrap -- 'echo T' TERM\nalive\n" (cup r))))
; ..but a signal ignored on entry cannot be trapped at all (POSIX), and no error
; is owed for trying. The everyday way a script gets one is its caller's `&` -- a
; shell backgrounded without job control starts with INT ignored, and the caller
; has thereby said this job does not answer ^C. Here the ignore is set on our side
; and inherited, so the child's own trap must never arm.
(: _ (signal sig-int 1)
   r (hark ["out/love" "out/lush" "-c" "trap 'echo CAUGHT' INT; kill -INT $$; echo done"])
   _ (signal sig-int 0)
   (test (= "done\n" (cup r))))

; the engine plans: (sh-plan ast) reads the AST once and answers a thunk, so
; firing it twice runs twice. the function book holds that plan -- a closure, so
; two? can never see it, and absence is the sh-nofn mint (peep's total test)
(: pr (sh-parse (cup (sh-lex "LUSH_PL=$(expr ${LUSH_PL:-0} + 1)")))
   p (sh-plan (cup pr))
   _ (p ()) _ (p ())
   (test (= '("2") (sh-fields [(. 'var "LUSH_PL")]))))
(: _ (sh-line "lush_pf() { echo x; }")
   (test (sh-fn? "lush_pf") (! (sh-fn? "lush_pq_zz"))
           (! (two? (sh-fnof "lush_pf")))))
; break/continue count their levels through the planned loops
(: r (hark ["out/love" "out/lush" "-c"
           "for a in 1 2; do for b in x y; do echo $a$b; break 2; done; done; echo end"])
   (test (= "1x\nend\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c"
           "for a in 1 2 3; do [ $a = 2 ] && continue; echo n=$a; done"])
   (test (= "n=1\nn=3\n" (cup r))))

; errexit's guard is a dynamic extent, which is why sh-noe is ambient: the
; suspension inside a condition reaches a forked pipeline stage and an `eval`,
; and outside one it reaches neither. bash agrees on all five.
(: r (hark ["out/love" "out/lush" "-c"
           "set -e; { false; echo r; } | cat; echo after"])
   (test (= "after\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c"
           "set -e; if { false; echo r; } | cat; then echo t; fi"])
   (test (= "r\nt\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c"
           "set -e; if eval \"false; echo x\"; then echo t; fi"])
   (test (= "x\nt\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c"
           "set -e; eval \"false; echo x\"; echo after"])
   (test (= 1 (cap r)) (= "" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "set -e; false && echo a; echo survived"])
   (test (= "survived\n" (cup r))))
; ... but a $( ) body is guarded, so under set -e it runs to its end and hands
; back what it wrote -- the two capture lanes (a seq reaped per step, a compound
; in one forked child) answer the same, and bash agrees with both
(: r (hark ["out/love" "out/lush" "-c"
           "set -e; v=$( { false; echo r; } ); echo v=[$v] after"])
   (test (= "v=[r] after\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c"
           "set -e; v=$(false; echo r); echo v=[$v] after"])
   (test (= "v=[r] after\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c"
           "set -e; f(){ false; echo fr; }; v=$(f); echo v=[$v] after"])
   (test (= "v=[fr] after\n" (cup r))))
; a command with no command name answers the last $( ) performed over its
; assignments, in order (POSIX) -- none ran is a clean 0, a command name of its
; own wins, and under set -e that status is a real trigger unless it is guarded
(: r (hark ["out/love" "out/lush" "-c" "v=$(exit 3); echo $?"])
   (test (= "3\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "v=1; echo $?"])
   (test (= "0\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "a=$(exit 3) b=$(exit 4); echo $?"])
   (test (= "4\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "v=$(exit 5)x$(exit 6); echo $?"])
   (test (= "6\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "v=$(false) true; echo $?"])
   (test (= "0\n" (cup r))))
; the words expand before the assignments, so a $( ) that vanishes to no field
; still counts, and still counts first
(: r (hark ["out/love" "out/lush" "-c" "v=1 $(exit 3); echo $?"])
   (test (= "3\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "v=$(exit 2) $(exit 3); echo $?"])
   (test (= "2\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "$(exit 6); echo $?"])
   (test (= "6\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "set -e; v=$(false); echo never"])
   (test (= 1 (cap r)) (= "" (cup r))))
(: r (hark ["out/love" "out/lush" "-c"
           "set -e; if v=$(false); then echo t; else echo e; fi"])
   (test (= "e\n" (cup r))))

; expansion: POSIX order -- splitting only over expansion output, quotes
; shield, an unset var alone is no field, a quoted empty is one, glob last
(: _ (setenv "LUSH_T1" "quay")
   _ (setenv "LUSH_T2" "a  b")
   v (\ nm (. 'var nm))
   (test
    (= '("pre-quay") (sh-fields [(. 'lit "pre-") (v "LUSH_T1")]))
    (= '("a" "b") (sh-fields [(v "LUSH_T2")]))
    (= '("a  b") (sh-fields [(. 'dq [(v "LUSH_T2")])]))
    (= () (sh-fields [(v "LUSH_NIL_ZZ")]))
    (= '("") (sh-fields [(. 'sq "")]))
    (= '("quay") (sh-fields [(. 'sub "echo quay")]))
    (= '("apps/lush.l") (sh-fields [(. 'lit "apps/lus*.l")]))
    (= '("apps/zz*qq") (sh-fields [(. 'lit "apps/zz*qq")]))
    (= '("apps/lush/j*.l") (sh-fields [(. 'sq "apps/lush/j*.l")]))))
(: _ (pin sh-status () 7)
   (test (= '("7") (sh-fields [(. 'var "?")]))))

; fnmatch + the glob walk: classes, ranges, negation, the mask law
(test (sh-match "*.l" "job.l") (! (sh-match "*.l" "job.c"))
        (sh-match "j??.l" "job.l") (sh-match "[a-j]ob.l" "job.l")
        (! (sh-match "[!a-j]ob.l" "job.l")) (sh-match "[!a-j]ob.l" "zob.l")
        (sh-match "[!a]bc" "zbc") (! (sh-match "[!a]bc" "abc"))     ; negation, both ways
        (sh-match "[^a]bc" "zbc") (! (sh-match "[abz]bc" "qbc"))    ; ^ is the same word
        (sh-match "a[bc" "a[bc")                                    ; unterminated [ is itself
        (= '("apps/lush.l") (sh-glob "apps/l[t-v]sh.l" (sh-ones 19))))

; completion (rung 2): (insert . candidates) -- one path candidate lands its
; tail (+ " ", a directory its "/"), the common prefix otherwise; the helpers
(: r (sh-complete (sh-expl "cat apps/lus"))
   (test (two? r) (= "h.l " (slurp (tap (cap r)))) (= '("apps/lush.l") (cup r))))
(: r (sh-complete (sh-expl "cat apps/ko"))
   (test (= "re/" (slurp (tap (cap r))))))              ; one DIR candidate: its /
(: r (sh-complete (sh-expl "cat apps/lu"))
   (test (= '("apps/lupa.l" "apps/lush.l" "apps/lux") (cup r))))   ; three ways forward, listed
(test (= "ab" (sh-common '("abc" "abd" "ab")))
        (= "~" (sh-homely (+ "" (getenv "HOME")))))

; (signal sig 1) ignores: a self-INT that would kill us just fizzles; restore after
(: me (getpid 0)
   _ (test !(signal sig-int 1))
   _ (still me sig-int)
   _ (test 1)                                     ; still here: the ignore held
   _ (test !(signal sig-int 0)))

; wait's stop lane: a sigstopped child answers 256+sig (a charm past every exit
; status -- the shell's "park it as a job" signal), then CONT + KILL ends it 137
(: p (spawn ["sleep" "5"])
   _ (still p 19)                                   ; sigstop
   (test (= (+ 256 19) (wait p))
           (: _ (still p sig-cont) _ (still p 9) (= 137 (wait p)))))

; sigfd takes a signal list now: sigusr1 blocked + queued, kill self, take the
; record -- the signal is data, (signo . pid)
(: sp (sigfd [10])
   me (getpid 0)
   _  (still me 10)
   ev (sigtake sp)
   (test (hot? sp) (two? ev) (= 10 (cap ev)) (= me (cup ev))))

; ... and a taken signal re-raised through the condition system is the doc's
; "signals arrive as conditions": scare routes it to the installed help policy
(hear (\ a b ['gotsig a b]))
(test (= ['gotsig 'sigusr1 (getpid 0)] (scare 'sigusr1 (getpid 0))))
(hear 0)

; env nifs: set, read back through environ's raw K=V, absence unsets
(test !(setenv "LOVE_SH_T5" "quay")
        (= "quay" (getenv "LOVE_SH_T5"))
        (foldl (\ a e (? a a (= e "LOVE_SH_T5=quay"))) 0 (environ 0)))
(test !(setenv "LOVE_SH_T5" ())                                   ; absence unsets
        ((getenv "LOVE_SH_T5") = ()))
; $? and export, through the shell's own line entry
(: _ (sh-line "sh -c 'exit 7'")
   (test (= 7 (sh-status ())) (= '("7") (sh-fields [(. 'var "?")]))))
(: _ (sh-line "export LOVE_SH_T6=pier")
   (test (= "pier" (getenv "LOVE_SH_T6"))))

; the built shell, end to end: pipes, lists, cmdsub, glob, 2>&1 -- driven
; through out/love so the tree's own nifs serve (env's love is the nest's)
(: r (hark ["out/love" "out/lush" "-c" "echo a b | tr a-z A-Z"])
   (test (= 0 (cap r)) (= "A B\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "false && echo no || echo yes"])
   (test (= "yes\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "echo $(echo hi | tr h H) apps/lus*.l"])
   (test (= "Hi apps/lush.l\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "sh -c 'echo e >&2' 2>&1 | tr e E"])
   (test (= "E\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "exit 9"])
   (test (= 9 (cap r))))

; rung 4: --login reads $HOME/.profile (a scratch HOME keeps the suite
; hermetic); without the flag the profile stays unread. `return` in a
; .-sourced file stops that file with its status (the POSIX dot-return).
(: home0 (+ "" (getenv "HOME"))
   d "out/.lush-t4"
   _ (mkdir d 493)
   p (open (+ d "/.profile") "w") _ (say p "LUSH_P4=prof\nexport LUSH_P4\n") _ (close p)
   p (open (+ d "/rr.sh") "w") _ (say p "echo one\nreturn 5\necho two\n") _ (close p)
   _ (setenv "HOME" d)
   r1 (hark ["out/love" "out/lush" "--login" "-c" "echo p=$LUSH_P4"])
   r2 (hark ["out/love" "out/lush" "-c" "echo p=[$LUSH_P4]"])
   _ (setenv "HOME" home0)
   r3 (hark ["out/love" "out/lush" "-c" ". out/.lush-t4/rr.sh; echo rc=$?"])
   (test (= "p=prof\n" (cup r1))
           (= "p=[]\n" (cup r2))
           (= "one\nrc=5\n" (cup r3))))
; a comment ends at its newline, never the input's end (the multi-line -c /
; buffered-script shape every /etc/profile.d file has)
(: r (hark ["out/love" "out/lush" "-c" "# lead\necho a # tail\n# mid\necho b"])
   (test (= "a\nb\n" (cup r))))
; a closer on its own line: the multi-line subshell in cmdsub, the case item's ;;
(: r (hark ["out/love" "out/lush" "-c" "v=$(\n(\necho deep\n)\n)\necho v=$v"])
   (test (= "v=deep\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "case x in\na) echo no\n;;\nx) echo yes\n;;\nesac"])
   (test (= "yes\n" (cup r))))
; ${x:-word}: word is quote-aware (sh-wordize) -- inner quotes remove, and a
; quoted pattern char in ${v#pat} is inert (the mask law through the vop)
(: r (hark ["out/love" "out/lush" "-c" "echo \"${LUSH_U4:-\"a b\"}\" ${LUSH_U4:-'c d'}"])
   (test (= "a b c d\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "v='x*y'; echo ${v#\"x*\"} ${v#x?}"])
   (test (= "y y\n" (cup r))))

; the forkless $( ), lane one: a no-effect builtin says its piece into a jug this
; task wears (love.h's hook 6) -- no pipe, no fd, no child. the answer is the one
; the pipe gave, the status included, and a function of the same name takes the
; name back (to lane two, below: a body that may spawn needs an fd)
(: r (hark ["out/love" "out/lush" "-c" "cd /; echo \"[$(pwd)][$(pwd)]\""])
   (test (= "[/][/]\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "x=$(false); echo $?; y=$(true); echo $?"])
   (test (= "1\n0\n" (cup r))))

; a failed cd must say so. chdir answers () on success and the ERRNO on failure, and
; an errno is negative -- so it is red, so a truth test reads the failure as a success:
; `cd nowhere` returned 0 with no word said, and `cd build && make` ran make wherever you
; already stood. The kind is what separates them (charm?, never !).
(: r (hark ["out/love" "out/lush" "-c" "cd /definitely-not-here; echo $?"])
   (test (= "1\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "cd /definitely-not-here && echo moved; echo done"])
   (test (= "done\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "pwd() { echo shadow; }; echo $(pwd)"])
   (test (= "shadow\n" (cup r))))

; lane two: the body runs here, down a pipe a task drains, and the state a
; subshell would have taken by copy is put back by hand (sh-subsave's roster).
(: r (hark ["out/love" "out/lush" "-c" "f() { echo a; echo b; }; x=$(f); echo \"[$x]\""])
   (test (= "[a\nb]\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "cd /tmp; echo [$(cd /; pwd)][$(pwd)]"])
   (test (= "[/][/tmp]\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "v=out; echo [$(v=in; echo $v)][$v]"])
   (test (= "[in][out]\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "export E=out; echo [$(export E=in; echo $E)][$E]"])
   (test (= "[in][out]\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "g() { echo G; }; f() { g() { echo I; }; }; echo [$(f; g)][$(g)]"])
   (test (= "[I][G]\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "set -- keep it; f() { echo $1; }; echo [$(f one)][$1 $2]"])
   (test (= "[one][keep it]\n" (cup r))))
; ..and the roster rides the raised way out too -- the one exit a driven shell
; cannot reach from here, since nothing a script can type raises a condition. a
; scare crossing the boundary used to leave the body's cwd (and its vars, funcs,
; positionals and flags with it) standing in the shell that ran it.
; the cwd is read and put back before the assert, never inside it: a failure
; here would otherwise leave every later test reading from the wrong directory.
(: start (cwd 0)
   r (trap (\ _ (sh-subhere (\ _ (: _ (chdir "/") (scare 'boom 0))))) () (\ a b a))
   here (cwd 0)
   _ (chdir start)
   (test (r = 'boom)                       ; the condition still rides outward
           (start = here)                      ; ..and the subshell's chdir did not
           !(start = "/")))                    ; ..(and the law was not vacuous)
; `exit` in a forkless body may not reach `quit` -- it folds to ('xit . st),
; which nothing catches but the capture. a fork under one puts the depth back,
; so a subshell's exit is a real one again
(: r (hark ["out/love" "out/lush" "-c" "echo [$(echo x; exit 7; echo y)]; z=$(exit 7); echo $?"])
   (test (= "[x]\n7\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "f() { exit 9; }; (f); echo after $?"])
   (test (= "after 9\n" (cup r))))
; a fork under a forkless body inherits the drainer, so it has to shut it down
; before it runs a step -- else the child reads its parent's capture and stalls
; on a pipe only its parent can end. a stage that is a function is such a fork; a
; `( )` is not, since under a capture it runs in-process instead
(: r (hark ["out/love" "out/lush" "-c" "f() { echo hi; }; echo [$(f | tr a-z A-Z)]"])
   (test (= "[HI]\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "cd /tmp; echo [$( (cd /; pwd) )][$(pwd)]"])
   (test (= "[/][/tmp]\n" (cup r))))
; the brackets are QUOTED here and nowhere else in this file: [tail] is a glob class
; over {t,a,i,l}, and the tree grew a one-letter name (l/) that it matches. the law is
; about the capture, not about globbing, so it says so.
(: r (hark ["out/love" "out/lush" "-c" "x=$( (exit 4); echo tail); echo \"[$x]\""])
   (test (= "[tail]\n" (cup r))))
; the drainer earns its keep: a body saying more than one pipe buffer (64 KiB) would
; stop forever against a reader that is us. a builtin's buffered bytes come first.
; the body cats the whole glob, not a named file: a source file's size is a moving
; target -- cutting one in half used to halve this body and quietly drop the volume
; this is here to carry.
(: r (hark ["out/love" "out/lush" "-c" "f() { pwd; cat l/*.c; cat l/*.c; }; x=$(f); echo ${#x}"])
   t (cup r)
   (test (< 800000 (sh-int (snip t 0 (- (tally t) 1))))))

; --- the love lane: no syntax yet, just the evaluator and the marshalling -----
; cli.l's -e law in-process -- every top-level datum off the string, many folding
; to one application (so infix reads) and one staying as it is. an unfinished or
; raising form is a condition handed back, never a raise the shell has to survive.
(test
 (= 3 (cup (sh-loveval "1 + 2")))
 (= 262144 (cup (sh-loveval "2 3 4")))
 (= "hi" (cup (sh-loveval "\"hi\"")))
 (= [1 2 3] (cup (sh-loveval "[1 2 3]")))
 ('err = (cap (sh-loveval "(1 +")))
 ('unfinished-form = (cap (cup (sh-loveval "(1 +"))))
 ('err = (cap (sh-loveval "nosuchname")))
 ; a string is its bytes, so a capture is usable; everything else prints sayable
 (= "hi" (sh-lovetext "hi"))
 (= "(1 2 3)" (sh-lovetext [1 2 3]))
 (= "3" (sh-lovetext 3)))

; ${(FORM)} -- the interpolation. the reader is the scanner, so the extent obeys
; love's lexical law and not the shell's: a ' is a sigil, a ; runs to the line's
; end, and a ) or a } inside a "" is text. `${` with a non-POSIX op reached
; 'unterm before this, so no script that lexed yesterday means anything new.
(: w1 (\ sg ('w . [sg]))                        ; a one-segment word token
   ew ('w . [('lit . "echo")])
   (test
    (= [1 ew (w1 ('lov . "(1 + 2)"))] (sh-lex "echo ${(1 + 2)}"))
    (= [1 ew ('w . [('lit . "x") ('lov . "(2 3 4)") ('lit . "y")])]
       (sh-lex "echo x${(2 3 4)}y"))
    (= [1 ew (w1 ('lov . "(\"}\")"))] (sh-lex "echo ${(\"}\")}"))
    (= [1 ew (w1 ('lov . "('a)"))] (sh-lex "echo ${('a)}"))
    ; the reader wants another line, and 'more is how PS2 is asked for one
    ((cap (sh-lex "echo ${(1 +")) = 'more)
    ((cap (sh-lex "echo ${(1 + 2)")) = 'more)
    ; the two nesting scanners step over the body rather than through it
    (= [1 ew (w1 ('sub . "echo ${('a)}"))] (sh-lex "echo $(echo ${('a)})"))
    (= [1 ew (w1 ('vop . ["U" ":-" "${('a)}"]))] (sh-lex "echo ${U:-${('a)}}"))
    ; the extent is the reader's, and nothing before it is: the vop lane holds
    (= [1 ew (w1 ('vop . ["v" "#" "a"]))] (sh-lex "echo ${v#a}"))))

; the value is a VALUE, not a chomped byte stream: one field, never IFS-split,
; never globbed -- quiet like "${x}". Splitting can be bought later; unsplitting
; cannot, so the quiet law is the one that keeps the door open.
(: r (hark ["out/love" "out/lush" "-c" "for w in ${(\"a b c\")}; do echo \"[$w]\"; done"])
   (test (= "[a b c]\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "echo ${(\"*\")} ${(1 + 2)}"])
   (test (= "* 3\n" (cup r))))
; all four seg-kind walks: a bare word (wseg), inside ".." (dqat), a ${x:-..}
; word (sh-textof), and a heredoc body (sh-dollarize's segs through sh-textof)
(: r (hark ["out/love" "out/lush" "-c"
            "echo ${(1 + 2)} \"[${(2 + 2)}]\" ${UNSET_LV:-${(3 + 3)}}; cat <<E\nsum ${(10 + 5)}\nE"])
   (test (= "3 [4] 6\nsum 15\n" (cup r))))
; a love form spanning lines, with a ; comment eating a } and a ) on the way
(: r (hark ["out/love" "out/lush" "-c" "echo ${(1 + 2 ; a } and a )\n)}"])
   (test (= "3\n" (cup r))))
; errors contain, and at expansion there is no line left to fail: the word is
; empty and the shell stays sayable
(: r (hark ["out/love" "out/lush" "-c" "echo [${(nosuchname)}] 2>/dev/null; echo alive"])
   (test (= "[]\nalive\n" (cup r))))

; `ev`: the answer on out, the truth bit as the status (positive is true), and
; -n for the status alone. the word `love` is not ours. a builtin shadows its
; PATH twin, and the interpreter spells its arguments differently -- `love -e X`
; would read -e as a datum and fold it in, answering 3.0 for 3. The two want
; different command lines and isolated processes, so `love` spawns.
(test !(sh-bi? "love") (sh-bi? "ev"))
(: r (hark ["out/love" "out/lush" "-c" "ev 1 + 2; ev -n 9; echo st=$?"])
   (test (= "3\nst=0\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "ev 0; echo st=$?; ev 1; echo st=$?"])
   (test (= "0\nst=1\n1\nst=0\n" (cup r))))
; a love form as a shell condition -- the one thing ${( )} cannot do, an
; expansion being a word and not a command. quoted, and both directions: the
; shell lexes first, so bare `ev 3 > 2` is `ev 3` with stdout redirected into a
; file named 2 -- which answers 0 and passes this assert for the wrong reason,
; leaving the file behind as the only sign. One arm cannot tell them apart.
; -n mutes the answer, which is what a condition wants.
(: r (hark ["out/love" "out/lush" "-c"
            "if ev -n '3 > 2'; then echo yes; else echo no; fi
             if ev -n '2 > 3'; then echo yes; else echo no; fi"])
   (test (= "yes\nno\n" (cup r))))
; errors contain: a bad form is a status and a line on err, and the shell runs on
(: r (hark ["out/love" "out/lush" "-c" "ev '(1 +' 2>/dev/null; echo st=$?; echo alive"])
   (test (= "st=1\nalive\n" (cup r))))
; the form runs in this image -- no process is spawned, so a binding it makes is
; still there on the next line
(: r (hark ["out/love" "out/lush" "-c" "ev '(: zz 7)'; ev zz"])
   (test (= "7\n7\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c" "x=$(ev '\"a b\"'); echo \"[$x]\"; echo $(ev '[1 2 3]')"])
   (test (= "[a b]\n(1 2 3)\n" (cup r))))
; ..and the binary keeps its own command line, in its own process
(: r (hark ["out/love" "out/lush" "-c" "PATH=$PWD/out:$PATH love -e '1 + 2'"])
   (test (= "3\n" (cup r))))

; the mode. autonomous (the default): a bare verb word is ours whatever PATH holds --
; the stage forks the warm heap, and a bare word that must spawn spawns this binary
; under the word (tr with no operands: its own usage, status 2). -g is PATH's rule
; again, and an empty PATH finds nothing (127). LUSHFLAGS carries the choice into a
; child shell, and a flag word on its own line overrides it.
(test !(sh-greg? 0))
(: r (hark ["out/love" "out/lush" "-c" "PATH=/nonexistent; printf abc | tr a-c A-C; echo; tr 2>/dev/null; echo st=$?"])
   (test (= "ABC\nst=2\n" (cup r))))
; (under -g even echo is PATH's, so the status crosses a variable and PATH comes back)
(: r (hark ["out/love" "out/lush" "-g" "-c" "p=$PATH; PATH=/nonexistent; tr 2>/dev/null; s=$?; PATH=$p; echo st=$s"])
   (test (= "st=127\n" (cup r))))
(: r (hark ["out/love" "out/lush" "-c"
            "export p=$PATH; PATH=/nonexistent; LUSHFLAGS=-g sh -c 'tr 2>/dev/null; s=$?; PATH=$p; echo st=$s'; LUSHFLAGS=-g sh -a -c 'tr 2>/dev/null; echo st=$?'"])
   (test (= "st=127\nst=2\n" (cup r))))

; `which` and `type` -- one verdict (sh-verdict) walks sh-simple2's own ladder, so
; what they name is what would run, and `command -v` reads the same answer. the
; classifications first: a reserved word, a builtin and a function are all things
; PATH cannot see, which is why these are builtins and not the external `which`.
(test (sh-bi? "which") (sh-bi? "where") (sh-bi? "type"))
(: r (hark ["out/love" "out/lush" "-c"
            "f() { :; }
             type if; type cd; type f
             which if; which cd; which f; command -v f"])
   (test (= "if is a shell reserved word\ncd is a shell builtin\nf is a shell function\nif\ncd\nf\nf\n"
              (cup r))))
; a miss is status 1 and a line on err for which/type, and silence for command -v
; (POSIX's way, and the probe every configure-shaped script opens with). the status
; over several operands is sticky, so one miss fails the command.
(: r (hark ["out/love" "out/lush" "-c"
            "which nosuchtool 2>/dev/null; echo st=$?
             command -v nosuchtool; echo st=$?
             type pwd nosuchtool 2>/dev/null; echo st=$?"])
   (test (= "st=1\nst=1\npwd is a shell builtin\nst=1\n" (cup r))))
; ..and the mode is in the verdict. autonomous: a verb word is ours whatever PATH
; holds, so an empty PATH still answers -- with the binary a spawn would exec
; (sh-spawnv's seat), which is the one path that is true of it. -g hands the
; question back to PATH, and an empty one finds nothing.
(: r (hark ["out/love" "out/lush" "-c"
            "PATH=/nonexistent
             a=$(which tr); b=$(ev '(selfpath 0)')
             [ \"$a\" = \"$b\" ] && echo seat || echo other
             c=$(type tr); [ \"$c\" = \"tr is a verb of $b\" ] && echo verb || echo other
             d=$(which -a tr); [ \"$d\" = \"$a\" ] && echo only || echo other
             e=$(where tr); [ \"$e\" = \"$d\" ] && echo where || echo other"])
   (test (= "seat\nverb\nonly\nwhere\n" (cup r))))
; `dir` is a second name on ls, registered beside it (kore.l) the way `more` rides
; less, so it takes the in-image lane and the verdict reads it as ours
(: r (hark ["out/love" "out/lush" "-c" "PATH=/nonexistent; dir /; type dir"])
   (: s (hark ["out/love" "out/lush" "-c" "PATH=/nonexistent; ls /"])
      (test (= (cup s) (snip (cup r) 0 #(cup s)))
              (elem 'verb (sh-verdict "dir")))))
; (under -g even echo is PATH's, so the status crosses a variable and PATH comes back)
(: r (hark ["out/love" "out/lush" "-g" "-c"
            "p=$PATH; PATH=/nonexistent; which tr 2>/dev/null; s=$?; PATH=$p; echo st=$s"])
   (test (= "st=1\n" (cup r))))
; the in-image lane, widened: the toolchain's other half plus the three crew tools
; that answer a status instead of quitting. each is claimed by name, from its own
; module where that is not the applets' home.
(test (all (\ w (two? (sh-imgfn w)))
             '("nm" "ar" "ld" "as" "tar" "libra" "fat" "mkfs.vfat" "mkdosfs")))
; ..and the stdin readers stay out: a filter with no file operand would drink the
; terminal in here, where ^C kills the shell and no pid answers `kill %1`
(test (all (\ w !(two? (sh-imgfn w))) '("gzip" "gunzip" "zcat" "cpio" "cat" "sort")))
; the door is what makes that safe. a tool that used to `quit` on its error path
; would have taken the shell with it; now every failure is one command's status and
; the line after it still runs.
(: r (hark ["out/love" "out/lush" "-c"
            "tar xzf /nonexistent.tgz . 2>/dev/null; echo t=$?
             libra /nonexistent-xyz.l 2>/dev/null; echo l=$?
             mkfs.vfat 2>/dev/null; echo m=$?
             echo alive"])
   (test (= "t=1\nl=1\nm=2\nalive\n" (cup r))))
; a capture of one takes the jug: no pipe, no fd, no child, which is the whole
; point of `cc=$(which cc)`
(: pr (sh-parse-line "which cc")
   (test (= 'jug (sh-lane >pr)) (= 'jug (sh-lane >(sh-parse-line "type cc")))))

(test_fin ())
(puts "sh: ok") (putc 10)
