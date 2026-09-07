; lush 🐚, assembled: the shell state + job control, the lexer, the grammar,
; the glob, the word expander, the engine, the repl loops, then the entry +
; seat -- each part a (module 'lush form in cat order, so the parts register
; the one module and a later part reads an earlier one.

; --- lush 🐚 job control -- the shell state + the v3 job machinery ---
; every part rides module 'lush (the wrap): (use 'lush) assembles them via
; apps/lush/lush.l, and the catted bin and the distro's /lib/sh.l register the same
; module in cat order (job eval line main) -- each part a body-less `:` binding
; into the module, so later parts read earlier ones. the shell story is main.l's.
;
; v3 (doc/misc/posix.md step 4): job control. the shell ignores the tty's job
; signals (installed in (sh _), main.l; spawn's child side resets them to
; default), so ^C/^Z reach only the foreground command. a ^Z stop comes back
; from `wait` as 256+sig (above every exit status) and the job parks in
; `sh-jobs`: n -> (pids state cmd), state 'stopped | 'running. builtins:
; jobs / fg / bg; a trailing & runs the pipeline unwaited as a 'running job.
; signal numbers are the Linux/x86 charms (the repo's home ABI; the BSDs
; take them through nolibc's permutation). also here: the shared floor
; (sh-rev sh-int sh-unwords) and the shell state (sh-jobs sh-status sh-tty).

(module 'lush
(: (sh-rev l) (foldl (\ a x (x . a)) () l)

   sig-int 2 sig-quit 3 sig-tstp 20 sig-cont 18 sig-ttou 22 sig-ttin 21
   sh-jobs (tablet 0)
   sh-njob {0}
   sh-tty {0}                                  ; 1 = interactive: jobs get their own pgrp + the tty
   sh-login {0}                                ; 1 = a login shell (--login, or a -argv0 seat): profiles read
   ; interactive spawns lead a fresh process group (pg 0) and the first stage takes
   ; the terminal (fg 1) -- a job in its own group is what makes ^Z real (a stop to
   ; an orphaned group is discarded, and the shell's group is orphaned under a
   ; nested session). the cooked/non-tty lane keeps the legacy in-shell pgrp (-1).
   (sh-pgm _) (? (sh-tty ()) 0 (0 - 1))
   (sh-fgm _) (? (sh-tty ()) 1 0)
   sh-status {0}                               ; $?: the last foreground status
   sh-substat {0}                              ; the last $( )'s status -- ambient for the
                                               ; same reason sh-noe is: word.l's expansion
                                               ; sits between sh-cmdsub and the reader
   sh-curline {0}                              ; the source line under eval (job display)
   sh-vars (tablet 0)                          ; shell variables (name -> value; export promotes)
   sh-funcs (tablet 0)                         ; functions (name -> the PLANNED body)
   ; --- trap: the action for a condition, and the door it leaves through -------
   ; sh-traps holds condition -> action text. sh-runtrap is the evaluator, pinned
   ; by eval.l at load the way word.l's sh-subeval is -- job compiles first, and
   ; the action is shell source that only eval can read.
   ; once. sh-trapped guards the exit action against an `exit` inside it, which
   ; would otherwise re-enter sh-leave and run the cleanup a second time.
   ; exit leaves through here; a signal condition rides the sigfd lane below.
   sh-traps (tablet 0)
   sh-runtrap {0}
   sh-trapped {0}
   ; --- the signal lane: a trapped condition, delivered ------------------------
   ; sigfd blocks the signals it watches and queues them to an fd, so a caught INT
   ; stops being a death and becomes a datum to read.
   ; armed only while a signal trap exists. With none -- every script in this
   ; tree but two -- the shell blocks nothing and this lane is one () test on the
   ; way past, so the ordinary command path is the one it always was.
   ; and drained, never parked on. `wait` is a 1ms poll that yields (read its
   ; nif), so the shell is never asleep inside a syscall and a non-blocking
   ; sigtake between polls sees the signal without a second wait set to merge.
   ; That hands us POSIX's rule for free -- the action runs when the foreground
   ; command completes -- and ^C reaches the child too, whose own mask sig_dfl_job
   ; cleared, so the wait it is inside ends on its own.
   ; the numbers are LINUX'S, like sig-int and sig-tstp above. The low ones are
   ; every kernel's; USR1 USR2 CHLD TSTP are not, and want the ISA/OS table the
   ; day this rides a BSD.
   sh-sigport {0}                              ; the signalfd port, or 0
   sh-signums '(("HUP" 1) ("INT" 2) ("QUIT" 3) ("ABRT" 6) ("USR1" 10) ("USR2" 12)
                ("PIPE" 13) ("ALRM" 14) ("TERM" 15) ("CHLD" 17) ("CONT" 18) ("TSTP" 20))
   (sh-signum nm)
     ((: (g l) (? !(two? l) 0
                  (: e <l (? (<e = nm) <>e (g >l)))))
      sh-signums)
   (sh-signame n)
     ((: (g l) (? !(two? l) ()
                  (: e <l (? (<>e = n) <e (g >l)))))
      sh-signums)
   ; every trapped condition that is a signal -- exit leaves by its own door
   (sh-sigconds _) (filter (\ k !(k = "EXIT")) (keys sh-traps))
   ; a signal ignored on entry cannot be trapped (POSIX), and no error is owed
   ; for trying. The everyday way a script gets one is the caller's `&`: a shell
   ; backgrounded without job control starts with INT and QUIT set to SIG_IGN, and
   ; a `trap .. INT` in it must stay off -- the caller has already said this job
   ; does not answer ^C. Snapshotted once at sh-main, before the interactive entry
   ; sets ignores of its own, or the shell would read its own hand as the caller's.
   sh-igno {0}
   (sh-snapign _)
     (pin sh-igno ()
          (filter (\ nm (: n (sh-signum nm) (n && (sigign? n))))
                  (map cap sh-signums)))
   (sh-ignored? nm) (: l (sh-igno ()) (? (two? l) (any (\ k (k = nm)) l) 0))
   ; clear, then arm. sigfd's sigprocmask is a SIG_BLOCK and accumulates, and
   ; closing the fd does not unblock: after `trap - INT` the signal would stay
   ; blocked with nothing left reading it, which is a shell that cannot be
   ; interrupted at all. So the mask is emptied first and the live set re-blocked.
   (sh-rearm _)
     (: cs (sh-sigconds 0)
        ns (filter (\ n !(n = 0)) (map sh-signum cs))
        _ (? (sh-sigport ()) (close (sh-sigport ())) 0)
        _ (pin sh-sigport () 0)
        _ (sigclear 0)
        _ (? (two? ns) (: p (sigfd ns) (? (hot? p) (pin sh-sigport () p) 0)) 0)
        0)
   (sh-disarm _)                               ; a forked child inherits neither
     (: _ (? (sh-sigport ()) (close (sh-sigport ())) 0)
        _ (pin sh-sigport () 0) _ (sigclear 0) 0)
   ; read every queued signal and run what each one traps. the action's own status
   ; does not become $? -- the command's does, exactly as at the exit door.
   (sh-fire-sig n)
     (: nm (sh-signame n)
        a (? (string? nm) (peep sh-traps nm "") "")
        (? #a
           (: st (sh-status ()) _ ((sh-runtrap ()) a) _ (pin sh-status () st) 0)
           0))
   (sh-sigdrain _)
     (: p (sh-sigport ())
        (? !p 0
           ((: (g _) (: ev (sigtake p)
                        (? !(two? ev) 0
                           (: _ (sh-fire-sig (cap ev)) (g 0)))))
            0)))
   ; the status is the one the SHELL was leaving with. POSIX says the action
   ; runs with $? as it stood, and the shell still exits on that -- `false` under
   ; an exit trap is still a 1, however well the cleanup went. Only an explicit
   ; `exit` inside the action changes it, and that one leaves through sh-leave.
   (sh-fire-exit _)
     (: a (peep sh-traps "EXIT" "")
        (? ((0 = (sh-trapped ())) && #a)
           (: st (sh-status ())
              _ (pin sh-trapped () 1)
              _ ((sh-runtrap ()) a)
              _ (pin sh-status () st) 0)
           0))
   sh-nofn (mint 0)                            ; that plan is a closure, so peep names its absence
   sh-pos {0}                                  ; the positionals, a list of strings
   sh-arg0 {0}                                 ; $0 (the script path, or the shell)
   sh-eflag {0} sh-uflag {0} sh-xflag {0}      ; set -e / -u / -x
   sh-gflag (tablet 0)                         ; -g: gregarious, PATH decides (1), or autonomous (0); empty until sh-main pins it
   sh-lastbg {0}                               ; $!: the last background pid
   ; ambient on purpose, never a parameter: the guard is a dynamic extent every
   ; re-entry reads -- a function body, `eval`, a dot-file, and the forks under a
   ; pipeline stage and a $( ) body (those two take it by memory copy). a plan
   ; parameter would have to cross word.l's expansion. test/host/sh.l pins it.
   sh-noe {0}                                  ; errexit guard depth (conds, && || arms)
   ; ambient for the same reason: the forkless $( ) captures this shell is
   ; inside, innermost first, each a (read-end . drainer) pair -- empty when none,
   ; and that emptiness is the question `exit` asks (inside one it may not reach
   ; `quit`: it folds to ('xit . st), which nothing catches but the capture).
   ; a fork under one inherits the drainer task, and a child draining its
   ; parent's capture eats the bytes and then blocks the whole child on a pipe
   ; only its parent can end. so a fork shuts each one down first thing
   ; (sh-dropcaps), and a `( )` under a capture does not fork at all (sh-subsh).
   sh-subfds {0}
   sh-online {0}                               ; nesting depth of sh-oneline: a line run here for a
                                               ; caller in this image, so `exit` ends the line not us
   ; the exit doors, and there are three: `exit`, errexit (sh-echk) and set -u on
   ; an unset name. all three end the SHELL -- and which shell that is depends on
   ; where we stand. innermost first: under a $( ) capture it is the capture, and the
   ; pair is what the plan machinery already rides out; under an sh-oneline it is the
   ; line, and the caller lives on in this image -- by scare, because set -u fires
   ; from a word expansion whose value is a string, with no pair to hand back.
   ; otherwise it is the process, as it always was. one rule said once, so a fourth
   ; door cannot drift away from it.
   (sh-leave st)
     (? (sh-subfds ()) ('xit . st)
        (0 < (sh-online ())) (scare 'sh-exit st)
        (: _ (sh-fire-exit 0) (quit st)))
   sh-retf {0}                                 ; a top-level `return` landed: sh-lines stops its file (dot-return)

   ; --- read one line (cooked): bytes until \n; 'eof at immediate EOF. here on
   ; the shared floor: eval's `.`/read builtins and the loops all drink from it
   (sh-getline port) (: c (see port) (? (c < 0) 'eof (c = 10) "" ((string c) + (sh-rest port))))
   (sh-rest port)    (: c (see port) (? (c < 0) ""   (c = 10) "" ((string c) + (sh-rest port))))

   (sh-unwords ws) (foldl (\ a w (? #a ((a + " ") + w) w)) "" ws)
   (sh-addjob pids state cmd)
     (: n (1 + (sh-njob ())) _ (pin sh-njob () n) _ (pin sh-jobs n [pids state cmd]) n)
   (sh-jobline n j)
     ("[" + ((show n) + ("] " + ((show (j 1)) + ("  " + ((j 2) + "\n"))))))
   (sh-stopped? sts) (foldl (\ a x (? a a (charm? x && 255 < x))) 0 sts)
   ; wait a foreground job; a stop registers + reports it instead of hanging the prompt
   (sh-waitfg pids cmd)
     (: sts (map (\ p (wait p)) pids)
        _   (sh-sigdrain 0)                            ; POSIX: after the command, not during
        _   (? (sh-tty ()) (ttyfg 0) 0)                ; the shell takes the terminal back
        _   (pin sh-status ()                          ; $?: the last stage; a stop folds to 128+sig
             (: st (last sts) (? (charm? st && (255 < st)) (st - 128) (charm? st) st 127)))
        (? (sh-stopped? sts)
           (: n (sh-addjob pids 'stopped cmd)
              _ (puts (sh-jobline n (sh-jobs n))) 0)
           0))
   ; background bookkeeping: drain glean at each prompt; a reaped pid leaves its job,
   ; an emptied job prints done and goes
   (sh-unpid l p) (? !l () (? (<l = p) >l (<l . sh-unpid >l p)))
   (sh-bgnote pid)
     (each (keys sh-jobs)
       (\ n (: j (sh-jobs n)
               (? !j 0
                  (: ps (sh-unpid (j 0) pid)
                     (? (ps = (j 0)) 0
                        !ps (: _ (? (sh-tty ())          ; notices are the tty's; scripts stay quiet
                                    (puts ("[" + ((show n) + ("] done  " + ((j 2) + "\n"))))) 0)
                               (pull sh-jobs n 0))
                        (pin sh-jobs n [ps (j 1) (j 2)])))))))
   (sh-reapbg _)
     (: r (glean 0) (? (two? r) (: _ (sh-bgnote <r) (sh-reapbg 0)) 0))
   ; job addressing: "fg 2" by number, bare "fg" the latest
   ; string membership: member? tests identity (uninterned strings never hit)
   (sh-smem? x l) (? !(two? l) 0 (? (x = <l) 1 (sh-smem? x >l)))
   (sh-int s) (sh-intl s 0 0)
   (sh-intl s i a) (? (i = #s) a (sh-intl s (i + 1) ((a * 10) + ((s i) - 48))))
   (sh-lastjob _) (foldl (\ a k (? (a < k) k a)) 0 (keys sh-jobs))
   (sh-jobn argv) (? >argv (sh-int <>argv) (sh-lastjob 0))
   (sh-fg n)
     (: j (sh-jobs n)
        (? !j (: _ (puts "fg: no such job\n") 0)
           (: pids (j 0) cmd (j 2)
              _ (pull sh-jobs n 0)
              _ (? (sh-tty ()) (ttyfg <pids) 0)        ; the job's group gets the terminal first
              _ (each pids (\ p (still p sig-cont)))
              (sh-waitfg pids cmd))))
   (sh-bg n)
     (: j (sh-jobs n)
        (? !j (: _ (puts "bg: no such job\n") 0)
           (: _ (each (j 0) (\ p (still p sig-cont)))
              _ (pin sh-jobs n [(j 0) 'running (j 2)])
              _ (puts (sh-jobline n (sh-jobs n)))
              0))))
) ; module 'lush

; --- lush 🐚 the lexer -- one line (or a joined continuation) to tokens ---
; no brackets here: the runtime supplies the layer (see job.l for the cat law).
;
; (sh-lex s) -> (1 . tokens) | ('more . why) -- 'more is the PS2 protocol: an
; unfinished shape (open quote, open $( ), trailing \, a heredoc still owed
; its body) asks the caller for another line; join with "\n" and re-lex the
; whole buffer. tokens:
;   ('w . segs)          a word as a segment list, quote structure kept:
;     ('lit . s)           unquoted run (glob chars live, $ already carved out)
;     ('sq . s)            '..' literal
;     ('dq . inner)        ".." -- inner is lit/var/sub/vop segs, splitting off
;     ('var . name)        $NAME / $? $# $@ $* $$ / $0-9 (one digit, POSIX law)
;     ('vop . (name op text))  ${name<op>text}: op ":-" ":=" ":?" ":+" (and the
;                          colonless four), "#" "##" "%" "%%", "len" (${#x});
;                          text raw, expanded at eval through sh-dollarize
;     ('sub . text)        $( text ) or `text`, run at expansion time
;     ('lov . text)        ${( form )}: a love form, evaluated at expansion time
;                          in this image. `text` is the parenthesized datum, the
;                          reader's own extent (sh-lovep). one field always --
;                          never IFS-split, never globbed, quiet like "${x}"
;   ('op . o)            | || & && ; ;; ( ) and "nl" (a newline is a separator,
;                        not whitespace)
;   ('rd . (ion . o))    a redirect: < > >> >& <& glued or spaced; ion is the
;                        io-number out of band -- () default, (n) attached.
;                        a heredoc lexes as op "<h" whose target word is the
;                        body: << collects the following lines to the delimiter
;                        and rewrites -- 'EOF' body lands ('sq . body), a bare
;                        EOF body ('dq . (sh-dollarize body)) so $ expands and
;                        nothing splits; <<- strips leading tabs. eval feeds
;                        the target through a pipe (the "<h" lane in rdmap).
; a # at a word start kills the rest of the line; \X is X literal;
; \<newline> vanishes (the join law); "" keeps \ escapes for $ ` " \ only.

(module 'lush
(: (lx-ws? b) (b = 32 || b = 9)
   (sh-digit? b) (48 <= b < 58)
   (sh-digits? s)
     (: n #s
        (go i) (? (i = n) (0 < n) (sh-digit? (s i)) (go (i + 1)) 0)
        (go 0))
   (sh-name? b) (sh-digit? b || sh-name1? b)
   (sh-name1? b) (65 <= b < 91 || 97 <= b < 123 || b = 95)
   (sh-alook al k) (al @ (e . r) (<e = k ? >e (sh-alook r k)))

   ; --- the $-machinery, top level (heredoc bodies + vop words re-enter it) ---
   ; a (payload . j) answer is read by kind (two?), never by truth. The payload
   ; may be empty -- "" , `` , a heredoc owed no lines -- and an empty one nets
   ; zero with the improper tail out of the sum, so the whole pair reads red: `!r`
   ; then calls a finished parse unfinished and asks PS2 for a line nobody owes.
   ; An index answer (sh-subp, sh-brace) is past its opener, so it cannot be 0.
   ; the two scanners below step over A ${( .. )}, they never scan through one.
   ; a love body runs on love's lexical law -- a ' is a sigil, not a quote -- so a
   ; shell-quoting walk would open a string at the sigil and take the $( ) or the
   ; ${ } to the wrong end, or to none. Handing the span to sh-lovep keeps the
   ; nesting counts honest ({ and } skipped together, ( and ) with them). Inside
   ; '..' nothing expands, so the arm sits after that guard and never fires there.
   (sh-love3? s n i) (i + 2 < n && s i = 36 && s (i + 1) = 123 && s (i + 2) = 40)
   ; $( body ): balanced parens, blind to quoted ones -> j past ) | ()
   ; a per-byte loop, so it repeats its own name rather than close over the
   ; state in a helper -- the cost note lives on `lx` at the foot of this file
   (sh-subp s n i depth q pe)
     (? (i = n) ()
        pe (sh-subp s n (i + 1) depth q 0)
        (: b (s i)
           (? (q = 39) (sh-subp s n (i + 1) depth (b @ 39 0 39) 0)
              (b = 92) (sh-subp s n (i + 1) depth q 1)
              (sh-love3? s n i)
                (: r (sh-lovep s n (i + 2))
                   (sh-subp s n (two? r ? >r (i + 1)) depth q 0))
              (q = 34) (sh-subp s n (i + 1) depth (b @ 34 0 34) 0)
              (b @ 39 (sh-subp s n (i + 1) depth 39 0)
                   34 (sh-subp s n (i + 1) depth 34 0)
                   40 (sh-subp s n (i + 1) (depth + 1) 0 0)
                   41 (depth = 1 ? (i + 1) (sh-subp s n (i + 1) (depth - 1) 0 0))
                      (sh-subp s n (i + 1) depth 0 0)))))
   ; $(( .. )): the arithmetic extent. i is past the two ( -- scan to the ) that
   ; closes the inner one, then demand a ) hard after it. the demand is the whole
   ; test: `$((cd a) && b)` is a command substitution whose first word opens a
   ; subshell, and POSIX says a real arithmetic expansion writes `$( (a) )` to say
   ; the other thing. So a failed match is not an error, it is the other reading.
   ; -> (text . j past the second )) | ()
   (sh-arip s n i depth) (i != n ?
    (s i @ 40 (sh-arip s n (i + 1) (depth + 1))
           41 (depth ? (sh-arip s n (i + 1) (depth - 1))
                       (i + 1 < n && s (i + 1) = 41 ? i))
              (sh-arip s n (i + 1) depth)))
   ; `...` -> (text . j-past) | ()
   (sh-btesc? b) (b = 96 || b = 92 || b = 36)
   (sh-bt s n i acc) (i != n ?
    (s i @ 96 (acc . (i + 1))
           (92 && i + 1 < n && sh-btesc? (s (i + 1)))
            (sh-bt s n (i + 2) (acc + string (s (i + 1))))
           b (sh-bt s n (i + 1) (acc + string b))))
   ; ${(FORM)}: the love arm. i is at the ( -- and THE READER IS THE SCANNER.
   ; `sound` speaks love's lexical law, which no shell scanner does: a ' is a
   ; sigil and not a quote, a ; runs to the line's end, a ) inside a "" is text,
   ; and { [ ] \ all read as themselves. What it leaves unread measures the
   ; extent, so the form's end is the reader's own answer rather than a second
   ; opinion about it -- and the one that evaluates the form later is this one.
   ; -> (text . j past the }) | 'torn unfinished (PS2's cue) | () no } in place
   (sh-lovews s n k) (k < n && lx-ws? (s k) ? (sh-lovews s n (k + 1)) k)
   (sh-lovep s n i)
    (sound (snip s i n) @
     (_ . rest)
      (: k (n - #rest)                  ; past the datum, in s's own index
         j (sh-lovews s n k)
         (? (n <= j) 'torn
            (s j = 125) (snip s i k . j + 1)))
     'torn)                                   ; 'torn, and a bodyless () with it
   ; ${ ... }: to the matching }, blind to quoted braces -> j past } | ()
   (sh-brace s n i depth q) (i != n ? (: b (s i) (?
    (q = 39) (sh-brace s n (i + 1) depth (b @ 39 0 39))
    (sh-love3? s n i)
      (: r (sh-lovep s n (i + 2))
         (sh-brace s n (two? r ? >r (i + 1)) depth q))
    (q = 34) (sh-brace s n (i + 1) depth (b @ 34 0 34))
    (b @ 39  (sh-brace s n (i + 1) depth 39)
         34  (sh-brace s n (i + 1) depth 34)
         123 (sh-brace s n (i + 1) (depth + 1) 0)
         125 (depth = 1 ? (i + 1) (sh-brace s n (i + 1) (depth - 1) 0))
             (sh-brace s n (i + 1) depth 0)))))
   ; the ${..} content -> a var/vop seg | () bad shape
   (sh-vspec1? b) (b @ (64 || 42 || 35 || 63 || 36) 1 (sh-digit? b))
   (sh-vopcol? b) (b @ (45 || 61 || 63 || 43) 1)      ; the four - = ? + ops
   (sh-vopp c)
     (: n #c
        (dbl? i b) (i + 1 < n && c (i + 1) = b)             ; ## or %% at i
        (? !n ()
           (c 0 = 35 && 1 < n) ('vop . [(snip c 1 n) "len" ""])            ; ${#x}
           (: nm (? (sh-vspec1? (c 0)) (string (c 0) . 1)
                    (sh-name1? (c 0))
                      (: (go i) (i < n && sh-name? (c i) ? (go (i + 1)) i)
                         j (go 1) (snip c 0 j . j))
                    ())
              (nm @ (name . i)
                 (? (i = n) ('var . name)
                    (: b (c i)
                       op (? (b = 58 && i + 1 < n && sh-vopcol? (c (i + 1)))
                              (":" + string (c (i + 1)) . i + 2)
                             (sh-vopcol? b)  (string b . i + 1)
                             (b = 35) (dbl? i 35 ? ("##" . i + 2) ("#" . i + 1))
                             (b = 37) (dbl? i 37 ? ("%%" . i + 2) ("%" . i + 1)))
                       (op @ (o . j) ('vop . [name o (snip c j n)]))))))))
   ; a $-form at i (past the $) -> (seg . j) | ('dollar . i) literal | 'unterm
   (sh-dol s n i)
     (? (i = n) ('dollar . i)
        (: b (s i)
           (spec nm) (('var . nm) . i + 1)    ; the one-byte specials, $? $@ ..
           (b @ 63 (spec "?") 64 (spec "@") 42 (spec "*")
                35 (spec "#") 36 (spec "$") 33 (spec "!")
                40 (: ar (i + 1 < n && s (i + 1) = 40 ? (sh-arip s n (i + 2) 0))
                    (charm? ar ? (('ari . snip s (i + 2) ar) . ar + 2)
                       (: e (sh-subp s n (i + 1) 1 0 0)
                          (? !e 'unterm (('sub . snip s (i + 1) (e - 1)) . e)))))
                ; ${( -- the love arm takes the extent off the READER, never off
                ; sh-brace, which counts a } inside a love "" or after a ; and would
                ; cut the form in the wrong place
                123 (i + 1 < n && s (i + 1) = 40 ?
                     (: r (sh-lovep s n (i + 1))
                        (atom? r ? 'unterm (('lov . <r) . >r)))
                     (: e (sh-brace s n (i + 1) 1 0)
                        (? !e 'unterm
                           (: sg (sh-vopp (snip s (i + 1) (e - 1)))
                              (? !sg 'unterm (sg . e))))))
                (? (sh-digit? b) (spec (string b))   ; $0-9, one digit (the POSIX law)
                   (sh-name1? b)
                     (: (go j) (j < n && sh-name? (s j) ? (go (j + 1)) j)
                        e (go i) (('var . snip s i e) . e))
                   ('dollar . i)))))
   ; a bare text (heredoc body, vop word) -> segs, $ and ` live, \ escapes $ ` \
   (sh-dollarize s)
     (: n #s
        (addl cur segs) (#cur ? (('lit . cur) . segs) segs)
        (go i cur segs)
          (? (i = n) (sh-rev (addl cur segs))
           (: b (s i)
              (? (b = 92 && (i + 1) < n && sh-btesc? (s (i + 1)))
                   (go (i + 2) (cur + string (s (i + 1))) segs)
                 ; 'dollar first: a bare $ answers ('dollar . i), which a plain
                 ; pair pattern would take for a segment and splice as one
                 (b = 36) (sh-dol s n (i + 1) @
                           ('dollar . j) (go j (cur + "$") segs)
                           (sg . j)      (go j "" (sg . addl cur segs))
                                          (go (i + 1) (cur + "$") segs))
                 (b = 96) (sh-bt s n (i + 1) "" @
                           (t . j) (go j "" (('sub . t) . addl cur segs))
                                    (go (i + 1) (cur + string b) segs))
                 (go (i + 1) (cur + string b) segs))))
        (go 0 "" ()))
   ; vop word text -> segs, quote-aware: ${x:-"a b"} carries its quotes as
   ; quotes ('sq/'dq segments), so use-time removal is free and a quoted glob
   ; char masks inert in ${v#pat}. heredoc bodies stay on sh-dollarize (no
   ; quote removal there). an unterminated quote falls back to a literal char.
   (sh-wordize s)
     (: n #s
        (addl cur segs) (#cur ? (('lit . cur) . segs) segs)
        ; ".." inner: $ ` live, \ escapes $ ` \ ", " closes -> (segs . j) | ()
        (dq i cur segs)
          (? (i = n) ()
             (: b (s i)
                (? (b = 34) (sh-rev (addl cur segs) . i + 1)
                   (b = 92 && i + 1 < n && (sh-btesc? (s (i + 1)) || s (i + 1) = 34))
                     (dq (i + 2) (cur + string (s (i + 1))) segs)
                   (b = 36) (sh-dol s n (i + 1) @
                             ('dollar . j) (dq j (cur + "$") segs)
                             (sg . j)      (dq j "" (sg . addl cur segs))
                                            (dq (i + 1) (cur + "$") segs))
                   (b = 96) (sh-bt s n (i + 1) "" @
                             (t . j) (dq j "" (('sub . t) . addl cur segs))
                                      (dq (i + 1) (cur + string b) segs))
                   (dq (i + 1) (cur + string b) segs))))
        (go i cur segs)
          (? (i = n) (sh-rev (addl cur segs))
             (: b (s i)
                (? (b = 39) (: (cl j acc) (? (j = n) (go (i + 1) (cur + string b) segs)
                                             (s j = 39) (go (j + 1) "" (('sq . acc) . addl cur segs))
                                             (cl (j + 1) (acc + string (s j))))
                              (cl (i + 1) ""))
                   (b = 34) (dq (i + 1) "" () @
                             (inner . j) (go j "" (('dq . inner) . addl cur segs))
                                          (go (i + 1) (cur + string b) segs))
                   (b = 92 && (i + 1) < n)
                     (go (i + 2) (cur + string (s (i + 1))) segs)
                   (b = 36) (sh-dol s n (i + 1) @
                             ('dollar . j) (go j (cur + "$") segs)
                             (sg . j)      (go j "" (sg . addl cur segs))
                                            (go (i + 1) (cur + "$") segs))
                   (b = 96) (sh-bt s n (i + 1) "" @
                             (t . j) (go j "" (('sub . t) . addl cur segs))
                                      (go (i + 1) (cur + string b) segs))
                   (go (i + 1) (cur + string b) segs))))
        (go 0 "" ()))

   ; --- heredoc collection ------------------------------------------------------
   ; the delimiter, right after << : 'EOF' / "EOF" (quoted: body literal) or a
   ; bare run -> (quoted delim . j) | ()
   (sh-hddelim s n i)
     (? (i = n) ()
        (: b (s i)
           (? (b = 39 || b = 34)
                (: (go j acc) (? (j = n) ()
                                 (s j = b) (1 . acc . j + 1)
                                 (go (j + 1) (acc + string (s j))))
                   (go (i + 1) ""))
              (: (bare? x) !(lx-ws? x || member? x '(10 124 38 59 60 62 40 41))
                 (go j acc) ((j < n && bare? (s j)) ? (go (j + 1) (acc + string (s j)))
                                                      (acc . j))
                 r (go i "")
                 (#<r ? (0 . r))))))
   (sh-tabstrip l) (: (go i) (i < #l && l i = 9 ? (go (i + 1)) i)
                      (snip l (go 0) #l))
   (sh-lineend s n j) (: (go i) (i = n || s i = 10 ? i (go (i + 1))) (go j))
   ; body lines from j until the delimiter line -> (body . resume-j) | ()
   (sh-hdlines s n j strip delim)
     (: (go j2 acc)
          (? (n <= j2) ()                              ; the delimiter never came
             (: e (sh-lineend s n j2)
                line (snip s j2 e)
                l2 (strip ? (sh-tabstrip line) line)
                nj (e < n ? (e + 1) e)
                (? (l2 = delim) (acc . nj)
                   (e = n) ()                          ; last line, no newline, not it
                   (go nj (acc + (l2 + "\n"))))))
        (go j ""))

   (sh-lex s)
   (: n #s
      (addl cur segs) (#cur ? (('lit . cur) . segs) segs)
      (fw cur started segs toks)                    ; flush the word in progress
        (: sg (addl cur segs)
           (started || two? sg ? (('w . sh-rev sg) . toks) toks))
      ; substitute each heredoc placeholder word with its collected body
      (fixw t bods)
        (= <t 'w && two? >t && (= <<>t 'hd) ?
         (: e (sh-alook bods ><>t)
          ('w . (<e ? [('sq . >e)] [('dq . sh-dollarize >e)])))
         t)
      (fin toks hq bods)
        (two? hq ? ('more . 'heredoc)
                   (1 . map (t \ fixw t bods) (sh-rev toks)))
      ; '...' -> index of the closing quote | ()
      (sq j) (? (j = n) () (s j = 39) j (sq (j + 1)))
      (esc? b) (member? b '(34 36 92 96))
      (peek? i b) (i + 1 < n && s (i + 1) = b)
      ; ".." -> (segs . j-past) | () unfinished
      (dq i cur segs) (i != n ?
       (s i @ 34 (sh-rev (addl cur segs) . i + 1)
              (92 && peek? i 10) (dq (i + 2) cur segs)
              (92 && i + 1 < n && esc? (s (i + 1)))
               (dq (i + 2) (cur + string (s (i + 1))) segs)
              36 (sh-dol s n (i + 1) @ ('dollar . j) (dq j (cur + "$") segs)
                                       (sg . j) (dq j "" (sg . addl cur segs)))
              96 (sh-bt s n (i + 1) "" @ (t . j) (dq j "" (('sub . t) . addl cur segs)))
              b (dq (i + 1) (cur + string b) segs)))
      ; hq/bods/k are the heredoc state, and only the << arms move them.
      ; no per-step helper closures in this loop or in sh-subp / sh-brace,
      ; however much one would shorten these call tails. Each runs once per byte,
      ; and a `:`-bound lambda in the body is built and dropped on every pass:
      ; four of them here measured +57% instructions over a whole lex. The state
      ; rides in the parameters, which is why `op2` takes nine of them.
      (op2 i cur started segs toks hq bods k o adv)  ; flush + emit an operator
        (lx (i + adv) "" 0 () (('op . o) . fw cur started segs toks) hq bods k)
      (lx i cur started segs toks hq bods k)
        (i = n ? (fin (fw cur started segs toks) hq bods)
         (s i @ (b && lx-ws? b) (lx (i + 1) "" 0 () (fw cur started segs toks) hq bods k)
               10 (: tks (('op . "nl") . fw cur started segs toks)
                   (? !(two? hq) (lx (i + 1) "" 0 () tks hq bods k)
                      (: (coll j q bs)                 ; owed bodies, in arrival order
                           (q @ (h . rest)
                              (sh-hdlines s n j (h 1) (h 3) @ (body . j2)
                                 (coll j2 rest ((h 0 . (h 2 . body)) . bs)))
                              (j . bs))
                         (coll (i + 1) (sh-rev hq) bods @
                          (j . bs) (lx j "" 0 () tks () bs k)
                                    ('more . 'heredoc)))))
               ; a comment runs to the end of its line, never the end of the
               ; input -- the buffer is multi-line whenever PS2/'more gathered
               ; (the nl itself still lexes, so heredoc bodies keep collecting)
               (35 && !started)
                 (: (sk j) ((j < n && !(s j = 10)) ? (sk (j + 1)) j)
                    (lx (sk (i + 1)) "" 0 () toks hq bods k))
               39 (: j (sq (i + 1))
                   (? !j ('more . 'quote)
                    (lx (j + 1) "" 1 (('sq . snip s (i + 1) j) . addl cur segs) toks hq bods k)))
               34 (dq (i + 1) "" () @
                   (inner . j) (lx j "" 1 (('dq . inner) . addl cur segs) toks hq bods k)
                   ('more . 'quote))
               36 (sh-dol s n (i + 1) @
                   ('dollar . j) (lx j (cur + "$") 1 segs toks hq bods k)
                   (sg . j) (lx j "" 1 (sg . addl cur segs) toks hq bods k)
                   ('more . 'sub))
               96 (sh-bt s n (i + 1) "" @
                   (t . j) (lx j "" 1 (('sub . t) . addl cur segs) toks hq bods k)
                   ('more . 'sub))
               92 (? (i + 1 = n) ('more . 'cont)
                     (s (i + 1) = 10) (lx (i + 2) cur started segs toks hq bods k)
                     (lx (i + 2) (cur + string (s (i + 1))) 1 segs toks hq bods k))
               (b @ (60 || 62))
                 (: ion (atom? segs && sh-digits? cur ? [(sh-int cur)])
                    tks (two? ion ? toks (fw cur started segs toks))
                    o (b = 62 ? (? (peek? i 62) ">>" (peek? i 38) ">&" ">")
                                (? (peek? i 60) "<<" (peek? i 38) "<&" "<"))
                    (? !(o = "<<")
                       (lx (i + #o) "" 0 () (('rd . (ion . o)) . tks) hq bods k)
                       (: strip ((i + 2) < n && s (i + 2) = 45)
                          (skip j2) ((j2 < n && lx-ws? (s j2)) ? (skip (j2 + 1)) j2)
                          j2 (skip (i + (strip ? 3 2)))
                          dl (sh-hddelim s n j2)
                          (? !dl ('more . 'heredoc)
                             (lx >>dl "" 0 ()
                                 (('w . [('hd . k)])
                                  . (('rd . (ion . "<h")) . tks))
                                 [k (strip ? 1 0) <dl <>dl . hq]
                                 bods (k + 1))))))
               ; || && ;; each double their own byte, so one peek serves all three
               (b @ (124 || 38 || 59))
                 (peek? i b ? (op2 i cur started segs toks hq bods k
                                   (string b + string b) 2)
                              (op2 i cur started segs toks hq bods k (string b) 1))
               40 (op2 i cur started segs toks hq bods k "(" 1)
               41 (op2 i cur started segs toks hq bods k ")" 1)
               b (lx (i + 1) (cur + string b) 1 segs toks hq bods k)))
      (lx 0 "" 0 () () () () 0)))
) ; module 'lush

; --- lush 🐚 the grammar -- tokens to the AST ---
; no brackets here: the runtime supplies the layer (see job.l for the cat law).
;
; (sh-parse tokens) -> ('ok . ast) | ('more . why) | ('err . msg) -- 'more is
; the parse-level PS2 protocol: a dangling && || |, or a compound still open
; (if without fi, a case mid-item) wants another line. the AST:
;   ('cmd words redirs)     words each a segment list; redirs (ion op target)
;   ('pipe cmds)            two or more stages (any command kind)
;   ('and a b) ('or a b) ('seq a b) ('bg a) ('not a)
;   ('if clauses else)      clauses ((cond . body)..); else () when absent
;   ('while cond body) ('until cond body)
;   ('for name words body)  words absent -> the one word $@
;   ('case word items)      items ((patterns . body)..), patterns word-segs
;   ('group body) ('subsh body) ('fun name body) ('rdr ast redirs)
; reserved words live only at command position: pcomm answers ('stop . ts) for
; a closer (then/fi/do/done/esac/else/elif/}), and the list machinery lifts it
; into "the list so far ends here" -- the compound parsers then expect their
; own closer by name. an empty rest where a compound needs more is 'more.

(module 'lush
(: (tk-op? t o) (= <t 'op && (>t = o))
   (tk-w? t) (= <t 'w)
   (tk-rd? t) (= <t 'rd)
   (tk-nl? t) (tk-op? t "nl")
   (skipnl ts) (? (ts && tk-nl? <ts) (skipnl >ts) ts)
   (skipsep ts) (? (two? ts && (tk-op? <ts ";" || tk-nl? <ts))
                   (skipsep >ts) ts)
   (bad? r) !(two? <r)
   ; the bare text of a plain unquoted one-segment word, "" otherwise
   (litw t) (? (&& (two? t) (tk-w? t) (two? >t) !>>t
                  (= <<>t 'lit))
               ("" + ><>t) "")
   (rw? t w) (tally (litw t) && (w = (litw t)))
   stopw '("then" "else" "elif" "fi" "do" "done" "esac" "}")

   (sh-parse ts)
     (: ts2 (skipnl ts)
        (? !ts2 ('ok . ())
           (: r (plist ts2)
              (? (= <r 'stop)
                   (: t <>r w (litw t)
                      ('err . ("unexpected " + (? #w w ("" + >t)))))
                 (bad? r) r
                 >r ('err . "trailing tokens")
                 ('ok . <r)))))

   ; list: & backgrounds only its own and_or; seq folds right by recursion
   (plist ts) (: r (pao ts) (? (bad? r) r (plrest <r >r)))
   (plrest a ts)
     (? !(two? ts) (a . ())
        (: t <ts
           (? (tk-op? t "&") (plnext ['bg a] >ts)
              (tk-op? t ";" || tk-nl? t) (plnext a >ts)
              (a . ts))))
   (plnext a ts)
     (: ts2 (skipnl ts)
        (? !(two? ts2) (a . ())
           (: r (plist ts2)
              (? (= <r 'stop) (a . >r)                ; a closer: the list ends here
                 (bad? r) r
                 ['seq a <r . >r]))))

   ; and_or: && / ||, left-assoc; newlines after the op continue the line
   (pao ts) (: r (ppipe ts) (? (bad? r) r (paomore <r >r)))
   (paomore a ts)
     (? !(two? ts) (a . ())
        (: t <ts
           (? (tk-op? t "&&") (paorhs 'and a >ts)
              (tk-op? t "||") (paorhs 'or a >ts)
              (a . ts))))
   (paorhs k a ts)
     (: ts2 (skipnl ts)
        (? !(two? ts2) ('more . 'op)
           (: r (ppipe ts2)
              (? (bad? r) r (paomore [k a <r] >r)))))

   ; pipeline: a leading bare ! word negates the whole thing
   (ppipe ts)
     (? (rw? <ts "!")
        (: r (ppipe1 >ts) (? (bad? r) r ['not <r . >r]))
        (ppipe1 ts))
   (ppipe1 ts) (: r (pcomm ts) (? (bad? r) r (ppmore [<r] >r)))
   (ppmore cmds ts)
     (? (ts && tk-op? <ts "|")
        (: ts2 (skipnl >ts)
           (? !(two? ts2) ('more . 'op)
              (: r (pcomm ts2) (? (bad? r) r (ppmore (<r . cmds) >r)))))
        ((? >cmds ['pipe (sh-rev cmds)] <cmds) . ts))

   ; command: a compound by its reserved word, a function def, else simple
   (pcomm ts)
     (? !(two? ts) ('more . 'compound)
        (: t <ts w (litw t)
           (? (sh-smem? w stopw) ('stop . ts)
              ; a closer OP at command position stops the list too -- it is how a
              ; multi-line subshell's `)` (or a case item's `;;`) lands on its own line
              (tk-op? t ")" || tk-op? t ";;") ('stop . ts)
              (w = "if") (pif >ts)
              (w = "while") (ploop 'while >ts)
              (w = "until") (ploop 'until >ts)
              (w = "for") (pfor >ts)
              (w = "case") (pcase >ts)
              (w = "{") (pgroup >ts)
              (tk-op? t "(") (psubsh >ts)
              (fundef? ts) (pfun ts)
              (pcmd ts))))
   (fundef? ts) (&& #(litw <ts)
                    (two? >ts) (tk-op? <>ts "(")
                    (two? >>ts) (tk-op? <>>ts ")"))

   ; expect the closer w (separators skipped) -> (1 . rest) | 'more | 'err
   (expw ts w msg)
     (: ts2 (skipsep ts)
        (? !(two? ts2) ('more . 'compound)
           (rw? <ts2 w) (1 . >ts2)
           ('err . msg)))
   ; trailing redirects on a compound: done < file, { .. } 2>&1
   (predir ast ts) (prd ast ts ())
   (prd ast ts rs)
     (? (two? ts && tk-rd? <ts)
        (: t <ts ts2 >ts
           (? (two? ts2 && tk-w? <ts2)
              (prd ast >ts2 [<>t >>t ><ts2 . rs])
              ('err . "redirect wants a target")))
        (? (two? rs) ['rdr ast (sh-rev rs) . ts] (ast . ts)))

   (pif ts)
     (: c (plist (skipnl ts))
        (? (= <c 'stop) ('err . "if: empty condition")
           (bad? c) c
           (: t1 (expw >c "then" "if wants `then`")
              (? !(charm? <t1) t1
                 (: b (plist (skipnl >t1))
                    (? (= <b 'stop) ('err . "if: empty body")
                       (bad? b) b
                       (pifrest [(<c . <b)] >b)))))))
   (pifrest clauses ts)
     (: ts2 (skipsep ts)
        (? !(two? ts2) ('more . 'compound)
           (: w (litw <ts2)
              (? (w = "fi") (predir ['if (sh-rev clauses) ()] >ts2)
                 (w = "elif")
                   (: c (plist (skipnl >ts2))
                      (? (bad? c) c
                         (: t1 (expw >c "then" "elif wants `then`")
                            (? !(charm? <t1) t1
                               (: b (plist (skipnl >t1))
                                  (? (bad? b) b
                                     (pifrest ((<c . <b) . clauses) >b)))))))
                 (w = "else")
                   (: b (plist (skipnl >ts2))
                      (? (bad? b) b
                         (: f (expw >b "fi" "else wants `fi`")
                            (? !(charm? <f) f
                               (predir ['if (sh-rev clauses) <b] >f)))))
                 ('err . "if wants `fi`")))))
   (ploop k ts)
     (: c (plist (skipnl ts))
        (? (= <c 'stop) ('err . "loop: empty condition")
           (bad? c) c
           (: d (expw >c "do" "loop wants `do`")
              (? !(charm? <d) d
                 (: b (plist (skipnl >d))
                    (? (bad? b) b
                       (: e (expw >b "done" "loop wants `done`")
                          (? !(charm? <e) e
                             (predir [k <c <b] >e)))))))))
   (pfor ts)
     (? !(two? ts) ('more . 'compound)
        (: nm (litw <ts)
           (? !#nm ('err . "for wants a name")
              (: ts2 (skipsep >ts)
                 (? !(two? ts2) ('more . 'compound)
                    (rw? <ts2 "in")
                      (: (go t acc) (? (two? t && tk-w? <t)
                                       (go >t (><t . acc))
                                       (sh-rev acc . t))
                         r (go >ts2 ())
                         (pfordo nm <r >r))
                    (pfordo nm [[('var . "@")]] ts2))))))
   (pfordo nm ws ts)
     (: d (expw ts "do" "for wants `do`")
        (? !(charm? <d) d
           (: b (plist (skipnl >d))
              (? (bad? b) b
                 (: e (expw >b "done" "for wants `done`")
                    (? !(charm? <e) e (predir ['for nm ws <b] >e)))))))
   (pcase ts)
     (? !(two? ts) ('more . 'compound)
        (: wt <ts
           (? !(tk-w? wt) ('err . "case wants a word")
              (: i (expw >ts "in" "case wants `in`")
                 (? !(charm? <i) i (pcitems >wt () >i))))))
   (pcitems w items ts)
     (: ts2 (skipnl ts)
        (? !(two? ts2) ('more . 'compound)
           (rw? <ts2 "esac") (predir ['case w (sh-rev items)] >ts2)
           (: ts3 (? (tk-op? <ts2 "(") >ts2 ts2)
              (go t acc)                          ; patterns: word (| word)*
                (? !(two? t) ('more . 'compound)
                   !(tk-w? <t) ('err . "case wants a pattern")
                   (: acc2 (><t . acc) t2 >t
                      (? (two? t2 && tk-op? <t2 "|") (go >t2 acc2)
                         (two? t2 && tk-op? <t2 ")") (sh-rev acc2 . >t2)
                         !(two? t2) ('more . 'compound)
                         ('err . "case pattern wants `)`"))))
              r (go ts3 ())
              (? !(two? <r) r
                 (pcbody w <r >r items)))))
   (pcbody w pats ts items)
     (: ts2 (skipnl ts)
        (? !(two? ts2) ('more . 'compound)
           (tk-op? <ts2 ";;") (pcitems w ((pats . ()) . items) >ts2)
           (rw? <ts2 "esac") (pcitems w ((pats . ()) . items) ts2)
           (: b (plist ts2)
              (? (bad? b) b
                 (: ts3 (skipnl >b)
                    (? !(two? ts3) ('more . 'compound)
                       (tk-op? <ts3 ";;")
                         (pcitems w ((pats . <b) . items) >ts3)
                       (rw? <ts3 "esac")
                         (pcitems w ((pats . <b) . items) ts3)
                       ('err . "case wants `;;` or `esac`")))))))
   (pgroup ts)
     (: b (plist (skipnl ts))
        (? (= <b 'stop) (pgend () >b)              ; { } empty? no: the closer ends it
           (bad? b) b
           (pgend <b >b)))
   (pgend body ts)
     (: e (expw ts "}" "{ wants `}`")
        (? !(charm? <e) e (predir ['group body] >e)))
   (psubsh ts)
     (: b (plist (skipnl ts))
        (? (bad? b) b
           (: ts2 (skipnl >b)
              (? !(two? ts2) ('more . 'compound)
                 (tk-op? <ts2 ")") (predir ['subsh <b] >ts2)
                 ('err . "( wants `)`")))))
   (pfun ts)                                     ; NAME ( ) [nl] command
     (: nm (litw <ts)
        ts3 (skipnl >>>ts)
        (? !(two? ts3) ('more . 'compound)
           (: b (pcomm ts3)
              (? (bad? b) b ['fun nm <b . >b]))))

   ; simple command: words + redirects, any order; a redirect eats its target
   (pcmd ts) (pcm ts () ())
   (pcm ts ws rs)
     (? !(two? ts) (pcfin ts ws rs)
        (: t <ts
           (? (tk-w? t) (pcm >ts (>t . ws) rs)
              (tk-rd? t)
                (: ts2 >ts
                   (? (two? ts2 && tk-w? <ts2)
                      (pcm >ts2 ws [<>t >>t ><ts2 . rs])
                      !(two? ts2) ('err . "redirect wants a target")
                      ('err . "redirect wants a word")))
              (tk-op? t "(") ('err . "unexpected parenthesis")
              (pcfin ts ws rs))))
   (pcfin ts ws rs)
     (? (!ws && !rs) ('err . "expected a command")
        ['cmd (sh-rev ws) (sh-rev rs) . ts]))
) ; module 'lush

; --- lush 🐚 the glob -- fnmatch + pathname expansion, pure love ---
; no brackets here: the runtime supplies the layer (see job.l for the cat law).
; no libc glob anywhere (L1/L2 won't have one): readdir + stat are the whole
; substrate. patterns travel as (text . mask) -- the mask a parallel string of
; '1'/'0' bytes, '1' where the char came in unquoted (glob-live), '0' where a
; quote shielded it ('*' matches a literal star) -- absence-of-specialness
; carried out of band, the quoting law made byte-addressable.
;   the matcher itself is core/boot/post.l -- fmatch / match / anyglob / ones,
;   bound back to their sh- names below so every reader here is unchanged.
;   (sh-globby? t m)       -> any live * ? [ under the mask
;   (sh-glob t m)          -> sorted matching paths | () (caller keeps the word)
; the dotfile law lives at the directory scan: a leading . matches only a
; pattern that spells the . itself.

(module 'lush
(: sh-anyglob (from 'glob 'anyglob)   ; the matcher moved to core/boot/post.l; every love
   sh-fmatch (from 'glob 'fmatch)     ; carries it now, this one included. the sh- names
   sh-match (from 'glob 'match)       ; stay -- word.l, eval.l, line.l, cook and kore's
   sh-ones (from 'glob 'ones)         ; find all read them, some through (from 'lush ..)
   (sh-globby? t m)
     (: n #t
        (go i) (? (i = n) 0
                  (: b (t i)
                     (? (((m i) = 49) && (|| (b = 42) (b = 63) (b = 91))) 1 (go (i + 1)))))
        (go 0))

   ; pattern -> components split on / (every /, quoted or not, is a path break)
   ; (core `rev`, not job.l's sh-rev: this part stands ALONE -- cook loads
   ; just the glob, by path, for $(wildcard))
   (sh-psplit t m)
     (: n #t
        (go i st acc)
          (? (i = n) (rev ((snip t st i . snip m st i) . acc))
             (? ((t i) = 47)
                (go (i + 1) (i + 1) ((snip t st i . snip m st i) . acc))
                (go (i + 1) st acc)))
        (go 0 0 ()))
   (sh-glob t m)
     (: comps (sh-psplit t m)
        abs (two? comps && !#<<comps)
        cs (? abs >comps comps)
        (? !cs ()                                   ; the pattern was just "/"
           (sort (gwalk (? abs ["/"] [""]) cs))))
   ; walk: prefixes are "" (cwd) / "x/" (always /-tailed); a live component
   ; scans its directory, a dead one appends + stats (the path must EXIST)
   ; presence by two?, never !: ("") is a real prefix list netting 0
   (gwalk pfxs cs)
     (? !(two? pfxs) ()
        (: c <cs ct <c cm >c rest >cs
           nxt (? (sh-globby? ct cm)
                  (catmap (\ d (gmatches d ct cm)) pfxs)
                  (catmap (\ d (: p (d + ct) (? (two? (stat p)) [p] ()))) pfxs))
           (? !(two? rest) nxt (gwalk (map (\ p (p + "/")) nxt) rest))))
   ; sorted, the posix law for expansion -- and readdir's raw order is the
   ; filesystem's (ext4 hashes, ufs appends), so an unsorted glob leaks the
   ; disk into anything built over it.
   (gmatches d ct cm)
     (: names (readdir (? #d d "."))
        dot (tally ct && ((ct 0) = 46))
        (map (\ nm (d + nm))
             (sort (filter (\ nm ((dot || !((nm 0) = 46)) && sh-fmatch ct cm nm))
                           names)))))
) ; module 'lush

; --- lush 🐚 the word -- expansion: segments to fields ---
; no brackets here: the runtime supplies the layer (see job.l for the cat law).
;
; (sh-fields segs) -> the fields a word becomes, POSIX order: tilde, then
; parameter/command substitution, then IFS field splitting -- only over
; expansion output, never literal text -- then glob, then quote removal (free:
; quotes never entered the text). a field grows as a run list ((text . live?)..)
; so quoting survives to the glob (glob.l's mask law); `seen` carries the
; empty-word law out of band. parameters resolve shell vars (sh-vars) over the
; environment; the positionals and specials ($@ $* $# $? $$ $0-9) live here,
; and "$@" in quotes fields one positional each (the passthrough law).
; ${x:-y} and kin ride ('vop . (name op text)) -- text re-enters through
; sh-wordize (quote-aware) at use. ('sub . text) runs through the box sh-subeval -- eval.l
; pins the evaluator there at load (word compiles before eval exists).

(module 'lush
(: sh-subeval {0}
   (sh-ifs? b) (|| (b = 32) (b = 9) (b = 10))
   (sh-chomp t)
     (: (go k) (? ((0 < k) && ((t (k - 1)) = 10)) (go (k - 1)) (snip t 0 k))
        (go #t))
   (sh-runsub x) (sh-chomp ("" + ((sh-subeval ()) x)))

   ; --- the love lane: a form's answer, and that answer as shell text -----------
   ; lush is love, so the evaluator is aboard and nothing is spawned.
   ; (sh-loveval src) -> (1 . value) | ('err . (name . value)), cli.l's -e law:
   ; every top-level datum off the string, many folding to one application (so
   ; infix reads) and one staying as it is; 'torn is an unfinished shape. the run
   ; sits under a trap in urun's posture, so a bad form is a condition handed back
   ; and never a dead shell -- the torn case wears one too, so both render at one
   ; door. a raise is what a trap catches: a form calling `quit` still ends the
   ; process, exactly as `exit` does.
   (sh-loveval src)
     (: m (nom 0)                                 ; a fresh nom: 'torn, id?-safe
        (rdl x acc) (sound x @ 'torn       m
                               (d . rest) (rdl rest (d . acc))
                               _           (sh-rev acc))
        ; ^m, the pin: a bare `m` in a pattern would bind and take every answer.
        ; the nom is read from outside and the arm asks for that value alone.
        ; [] is the empty chain, exactly; a `()` arm would fit anything (pat.l)
        (trap (\ _ (rdl src () @ ^m ('err . ('unfinished-form . src))
                                 [] (1 . ())
                                 ds (1 . (ev 'ev (two? >ds ? ds <ds)))))
              ()
              (\ a b ('err . (a . b)))))
   (sh-lovesay c)                                 ; a love condition, on err, status 1
     (: _ (say err "lush: love: ") _ (print err <c) _ (say err " ")
        _ (print err >c) _ (put err 10) _ (flush err) 1)
   ; a love value as shell text: a string is its bytes, anything else prints in
   ; love notation -- so a string round-trips usable and a list reads back sayable
   (sh-lovetext v) (? (string? v) v (show v))
   ; ${(FORM)} at expansion: the text, or "" and a word on err. a bad form is an
   ; empty expansion, never a torn word -- the seg is already lexed by the time we
   ; are here, so there is no line to fail and the shell has to stay sayable
   (sh-lovseg src)
     (sh-loveval src @ ('err . c) (: _ (sh-lovesay c) "")
                      (_ . v)     (sh-lovetext v)
                      _            "")

   ; --- parameters: shell vars over env; specials; presence out of band --------
   ; (sh-vget nm) -> () unset | (1 . value) -- a tablet hit is a string (maybe
   ; ""), the miss the (); string? tells them apart where net cannot
   (sh-vget nm)
     (? (nm = "?") (1 . show (sh-status ()))
        (nm = "#") (1 . show #(sh-pos ()))
        (nm = "$") (1 . show (getpid 0))
        (nm = "!") (1 . show (sh-lastbg ()))
        (nm = "0") (1 . ("" + (sh-arg0 ())))
        ((nm = "@") || (nm = "*")) (1 . sh-unwords (sh-pos ()))
        (sh-digits? nm)
          (: (go l k)
               (? !(two? l) ()
                  (k = 1) (1 . <l)
                  (go >l (k - 1)))
             (go (sh-pos ()) (sh-int nm)))
        (: v (peep sh-vars nm ())
           (? (string? v) (1 . v)
              (: e (getenv nm) (? (string? e) (1 . e) ())))))
   (sh-vval nm)
     (: g (sh-vget nm)
        (? (two? g) >g
           (: _ (? (sh-uflag ())
                   (: _ (say err ("lush: " + (nm + ": unbound\n")))
                      (? (sh-tty ()) 0 (sh-leave 2)))
                   0)
              "")))
   (sh-setvar nm v)                             ; an exported name stays exported
     (? (string? (getenv nm)) (setenv nm v) (pin sh-vars nm v))

   ; --- $(( .. )): POSIX shell arithmetic --------------------------------------
   ; signed integer expressions over shell variables, with C's operators and C's
   ; precedence. one precedence-climbing walk (ar-bin asks itself for the level
   ; above) rather than a function per rung. Every step answers (value . index
   ; past) or () for "not that", so a bad expression unwinds without a raise and
   ; exactly one message is said.
   ; A NAME'S VALUE is arithmetic TEXT, not a number: `x=1+1` makes $((x*2))
   ; four. Hence the depth cap -- `a=b; b=a` would otherwise never land.
   ; and nothing here asks ? of A VALUE. love's truth is the sign, so -1 is
   ; false and `(? b ..)` would read a negative divisor as a zero one. Every test
   ; below is written against `= 0`, and that is not a style choice.
   arerr (tablet 0)                             ; a said complaint: the top stays quiet
   arlive (tablet 0)                            ; 0 inside a branch && || ?: did not take
   (ar-bad msg) (: _ (pin arerr 0 1)
                    _ (? (peep arlive 0 1) (say err ("lush: arithmetic: " + msg + "\n")) 0)
                    ())
   ; a runtime complaint -- a value only this evaluation could know is wrong. In a
   ; branch that did not take, there is no such value: `x != 0 && 100 / x` must
   ; not divide. a syntax complaint still fires there, because bash reads both
   ; sides even where it runs one.
   (ar-rt msg) (peep arlive 0 1 ? (ar-bad msg) 0)
   (ar-dead th) (: old (peep arlive 0 1) _ (pin arlive 0 0)
                   v (th ()) _ (pin arlive 0 old) v)
   (ar-ws s n i) (i < n && (s i = 32 || s i = 9 || s i = 10) ? (ar-ws s n (1 + i)) i)
   (ar-at s n i t) (: m #t ((i + m) <= n && (snip s i (i + m)) = t))
   (ar-has? l t) (any (\ x (x = t)) l)
   ; --- numbers: 0x hex, leading-0 octal, else decimal
   (ar-hexv b) (? (sh-digit? b) (b - 48)
                  (97 <= b < 103) (b - 87)
                  (65 <= b < 71) (b - 55)
                  ())
   (ar-dig? b base) (: v (ar-hexv b) (charm? v && v < base))
   (ar-digs s n i base acc any?)
     (? (i < n && (ar-dig? (s i) base))
        (ar-digs s n (1 + i) base ((acc * base) + (ar-hexv (s i))) 1)
        (any? ? (acc . i) ()))
   (ar-num s n i)
     (? ((1 + i) < n && s i = 48 && (s (1 + i) = 120 || s (1 + i) = 88))
          (ar-digs s n (2 + i) 16 0 0)
        (s i = 48 && (1 + i) < n && (ar-dig? (s (1 + i)) 8))
          (ar-digs s n (1 + i) 8 0 0)
        (ar-digs s n i 10 0 0))
   (ar-name s n i)
     (? (i < n && sh-name1? (s i))
        (: (go j) (j < n && sh-name? (s j) ? (go (1 + j)) j)
           e (go i) ((snip s i e) . e))
        ())
   ; a name's value, as a number. unset or empty is 0 -- which is what makes the
   ; `n=$((n + 1))` tally work on its first pass.
   (ar-vval nm d)
     (: g (sh-vget nm) t (? (two? g) >g "")
        (? (0 = tally t) 0 (d = 0) (ar-bad "name nesting too deep") (ar-eval t (d - 1))))
   (ar-store nm v) (: _ (sh-setvar nm (show v)) v)
   ; --- the operators. love truncates // toward zero, which is C's division; >>
   ; is C's arithmetic shift and wants the floor, so it is spelled out.
   (ar-fdiv a b) (: q (a // b) (q * b = a ? q (a < 0 ? (q - 1) q)))
   (ar-apply o a b)
     (? (o = "+") (a + b)   (o = "-") (a - b)   (o = "*") (a * b)
        (o = "/") (b = 0 ? (ar-rt "division by zero") (a // b))
        (o = "%") (b = 0 ? (ar-rt "division by zero") (a - (b * (a // b))))
        (o = "<<") (b < 0 ? (ar-rt "negative shift") (a * (b 2)))
        (o = ">>") (b < 0 ? (ar-rt "negative shift") (ar-fdiv a (b 2)))
        (o = "<") (a < b ? 1 0)     (o = "<=") (a <= b ? 1 0)
        (o = ">") (a > b ? 1 0)     (o = ">=") (a >= b ? 1 0)
        (o = "==") (a = b ? 1 0)    (o = "!=") (a = b ? 0 1)
        (o = "&") (a & b) (o = "^") (a ^ b) (o = "|") (a | b)
        (o = "**") (b < 0 ? (ar-rt "negative exponent") (b a))
        (ar-bad ("unknown operator " + o)))
   ; tightest last, and the master list is longest-first so `<<` is never read as
   ; a `<` at the comparison rung.
   ; ** is the one rung that associates right (2**3**2 is 512, not 64), and the
   ; only non-POSIX operator here -- bash and ksh both have it, and leaving it out
   ; would make a working script a syntax error rather than a portable one.
   arlv '(("||") ("&&") ("|") ("^") ("&") ("==" "!=") ("<=" ">=" "<" ">")
          ("<<" ">>") ("+" "-") ("*" "/" "%") ("**"))
   ; the operator at i, read off its first byte or two: every rung asks this of
   ; every primary, so a walk over the operator list with a snip per try was most
   ; of what an expression cost
   (ar-op s n i)
     (? (n <= i) ()
        (: b (s i) b2 (? ((1 + i) < n) (s (1 + i)) 0)
           (? (b = 42) (? (b2 = 42) "**" "*")
              (b = 60) (? (b2 = 60) "<<" (b2 = 61) "<=" "<")
              (b = 62) (? (b2 = 62) ">>" (b2 = 61) ">=" ">")
              (b = 61) (? (b2 = 61) "==" ())
              (b = 33) (? (b2 = 61) "!=" ())
              (b = 38) (? (b2 = 38) "&&" "&")
              (b = 124) (? (b2 = 124) "||" "|")
              (b = 43) "+" (b = 45) "-" (b = 47) "/" (b = 37) "%" (b = 94) "^"
              ())))
   ; the assignment operators: <<= >>= and the <op>= family, then a lone = when
   ; the next byte is not one, or `a == b` would assign.
   (ar-asnop s n i)
     (? (n <= i) ()
        (: b (s i) b2 (? ((1 + i) < n) (s (1 + i)) 0) b3 (? ((2 + i) < n) (s (2 + i)) 0)
           (? (b = 61) (? (b2 = 61) () ("=" . (1 + i)))
              ((b = 60 || b = 62) && b2 = b && b3 = 61) ((snip s i (3 + i)) . (3 + i))
              (b2 = 61 && (member? b '(42 47 37 43 45 38 94 124))) ((snip s i (2 + i)) . (2 + i))
              ())))
   ; --- the walk
   (ar-expr s n i d)
     (: i0 (ar-ws s n i)
        nv (ar-name s n i0)
        (? !(two? nv) (ar-cond s n i0 d)
           (: j (ar-ws s n >nv)
              op (ar-asnop s n j)
              (? !(two? op) (ar-cond s n i0 d)
                 (: r (ar-expr s n >op d)
                    (? !(two? r) ()
                       (<op = "=") ((ar-store <nv <r) . >r)
                       (: cur (ar-vval <nv d)
                          (? !(charm? cur) ()
                             (: v (ar-apply (snip <op 0 (#<op - 1)) cur <r)
                                (charm? v ? ((ar-store <nv v) . >r) ()))))))))))
   (ar-cond s n i d)
     (: r (ar-bin s n i 0 d)
        (? !(two? r) ()
           (: j (ar-ws s n >r)
              (? !(j < n && s j = 63) r
                 (: c !(<r = 0)
                    a (c ? (ar-expr s n (1 + j) d) (ar-dead (\ _ (ar-expr s n (1 + j) d))))
                    (? !(two? a) ()
                       (: j2 (ar-ws s n >a)
                          (? !(j2 < n && s j2 = 58) (ar-bad "? without :")
                             (: b (c ? (ar-dead (\ _ (ar-cond s n (1 + j2) d)))
                                       (ar-cond s n (1 + j2) d))
                                (? !(two? b) () ((c ? <a <b) . >b)))))))))))
   (ar-bin s n i k d)
     (? (k >= tally arlv) (ar-un s n i d)
        (: r (ar-bin s n i (1 + k) d) (? !(two? r) () (ar-more s n r k d))))
   ; one more operator at this rung, left-associating. && and || do not evaluate
   ; the side they do not need -- `x = 0 || 1 / x` is the whole reason.
   (ar-more s n r k d)
     (: j (ar-ws s n >r)
        o (ar-op s n j)
        (? !(string? o) r
           !(ar-has? (arlv k) o) r
           (: j2 (j + tally o)
              sc (o = "&&" || o = "||")
              rt? (o = "**")                    ; the one right-associating rung
              dead? (sc && (o = "&&" ? (<r = 0) !(<r = 0)))
              nk (rt? ? k (1 + k))
              rr (dead? ? (ar-dead (\ _ (ar-bin s n j2 nk d)))
                          (ar-bin s n j2 nk d))
              (? !(two? rr) ()
                 (: v (? !sc (ar-apply o <r <rr)
                         dead? (o = "&&" ? 0 1)
                         (<rr = 0 ? 0 1))
                    (? !(charm? v) ()
                       rt? (v . >rr)           ; the RHS already took the whole tail
                       (ar-more s n (v . >rr) k d)))))))
   (ar-un s n i d)
     (: i2 (ar-ws s n i)
        (? (n <= i2) ()
           (ar-at s n i2 "++") (ar-step s n (2 + i2) 1 d)
           (ar-at s n i2 "--") (ar-step s n (2 + i2) (0 - 1) d)
           (: b (s i2)
              neg (\ f (: r (ar-un s n (1 + i2) d) (two? r ? ((f <r) . >r) ())))
              (? (b = 45) (neg (\ v (0 - v)))
                 (b = 43) (ar-un s n (1 + i2) d)
                 (b = 33) (neg (\ v (v = 0 ? 1 0)))
                 (b = 126) (neg (\ v ((0 - v) - 1)))
                 (ar-prim s n i2 d)))))
   ; ++name / --name: the new value. the postfix pair is in ar-prim, and answers
   ; the old one -- the only difference between them.
   (ar-step s n i by d)
     (: nv (ar-name s n (ar-ws s n i))
        (? !(two? nv) (ar-bad "++ wants a name")
           (: cur (ar-vval <nv d)
              (charm? cur ? ((ar-store <nv (cur + by)) . >nv) ()))))
   (ar-prim s n i d)
     (: i2 (ar-ws s n i)
        (? (n <= i2) (ar-bad "expression ends early")
           (s i2 = 40)
             (: r (ar-expr s n (1 + i2) d)
                (? !(two? r) ()
                   (: j (ar-ws s n >r)
                      (? (j < n && s j = 41) (<r . (1 + j)) (ar-bad "( without )")))))
           (sh-digit? (s i2)) (: r (ar-num s n i2) (two? r ? r (ar-bad "bad number")))
           (sh-name1? (s i2))
             (: nv (ar-name s n i2)
                j (ar-ws s n >nv)
                (? (ar-at s n j "++") (ar-post <nv 1 d (2 + j))
                   (ar-at s n j "--") (ar-post <nv (0 - 1) d (2 + j))
                   (: v (ar-vval <nv d) (charm? v ? (v . >nv) ()))))
           (ar-bad ("unexpected " + (string (s i2))))))
   (ar-post nm by d j)
     (: cur (ar-vval nm d)
        (? !(charm? cur) () (: _ (ar-store nm (cur + by)) (cur . j))))
   ; the whole text, and nothing left over
   (ar-eval src d)
     (: n #src
        r (ar-expr src n 0 d)
        (? !(two? r) () (: j (ar-ws src n >r) (j < n ? (ar-bad "trailing text") <r))))
   ; ('ari . text) -> the value as shell text. a bad expression says so and stands
   ; for nothing: "" carries the mistake into the next command, and an empty word
   ; is at least a word a `[ ]` will complain about. 0 would just be wrong quietly.
   ; the TEXT expands first (POSIX): parameter and command substitution run over
   ; it before a single operator is read, so `$(( $(wc -c < f) % 512 ))` is one
   ; expression and not a syntax error. a bare name is left alone by that pass and
   ; reaches ar-vval as itself, which is how `$((n * 2))` still means n.
   (sh-arith src)
     (: _ (pin arerr 0 0) _ (pin arlive 0 1)
        v (ar-eval (sh-voptext src) 24)
        (? (charm? v) (show v)
           (: _ (? (peep arerr 0 0) 0
                   (say err ("lush: arithmetic: " + src + ": syntax error\n")))
              "")))

   ; --- ${name<op>text}: the word text re-enters through sh-wordize ------------
   (sh-textof segs)                             ; segs -> one string (no split/glob)
     (foldl (\ a sg (: k <sg
                       (+ a (? (= k 'lit) >sg
                               (= k 'sq) >sg
                               (= k 'dq) (sh-textof >sg)
                               (= k 'var) (sh-vval >sg)
                               (= k 'vop) (sh-vopseg sg)
                               (= k 'sub) (sh-runsub >sg)
                               (= k 'ari) (sh-arith >sg)
                               (= k 'lov) (sh-lovseg >sg)
                               ""))))
            "" segs)
   (sh-voptext text) (sh-textof (sh-wordize text))
   (sh-vopseg sg) (: p >sg (sh-vop (p 0) (p 1) (p 2)))
   (sh-vop nm op text)
     (? (op = "len") (show #(sh-vval nm))
        (: g (sh-vget nm)
           set? (two? g)
           v (? set? >g "")
           colon (tally op && ((op 0) = 58))
           use? (? colon (set? && tally v) set?)
           o (? colon (snip op 1 #op) op)
           (? (o = "-") (? use? v (sh-voptext text))
              (o = "=") (? use? v (: t (sh-voptext text) _ (sh-setvar nm t) t))
              (o = "?") (? use? v
                           (: _ (say err ("lush: " + (nm + (": " + (? #text text "parameter not set")))))
                              _ (put err 10)
                              (? (sh-tty ()) "" (sh-leave 2))))
              (o = "+") (? use? (sh-voptext text) "")
              (sh-vstrip v o text))))
   ; ${v#pat} ${v##pat} ${v%pat} ${v%%pat}: shortest/longest prefix/suffix strip
   (sh-patmask segs)                            ; segs -> (text . mask), quotes inert
     (foldl (\ a sg (: k <sg
                       t (? (= k 'lit) >sg
                            (= k 'sq) >sg
                            (= k 'dq) (sh-textof >sg)
                            (= k 'var) (sh-vval >sg)
                            (= k 'vop) (sh-vopseg sg)
                            (= k 'sub) (sh-runsub >sg)
                            (= k 'ari) (sh-arith >sg)
                            (= k 'lov) (sh-lovseg >sg)
                            "")
                       live (? (= k 'sq || (= k 'dq) || (= k 'lov)) "0" "1")
                       ((<a + t) . (>a + (sh-mrep #t live)))))
            ("" . "") segs)
   (sh-vstrip v o text)
     (: pw (sh-patmask (sh-wordize text))
        pt <pw pm >pw n #v
        (? (o = "#")  (: (go i) (? (n < i) v
                                   (? (sh-fmatch pt pm (snip v 0 i)) (snip v i n) (go (i + 1))))
                         (go 0))
           (o = "##") (: (go i) (? (i < 0) v
                                   (? (sh-fmatch pt pm (snip v 0 i)) (snip v i n) (go (i - 1))))
                         (go n))
           (o = "%")  (: (go k) (? (n < k) v
                                   (? (sh-fmatch pt pm (snip v (n - k) n)) (snip v 0 (n - k)) (go (k + 1))))
                         (go 0))
           (o = "%%") (: (go k) (? (k < 0) v
                                   (? (sh-fmatch pt pm (snip v (n - k) n)) (snip v 0 (n - k)) (go (k - 1))))
                         (go n))
           v))

   ; --- the field machinery -----------------------------------------------------
   ; field state: (done runs seen) -- done finished fields (rev), runs the
   ; field in progress (rev run list), seen "this field exists"
   (addrun runs t a) (? #t ((t . a) . runs) runs)
   (closef done runs seen) (? seen (runs . done) done)
   (skifs t i n) (? ((i < n) && sh-ifs? (t i)) (skifs t (i + 1) n) i)
   (chunk t i n) (? ((i < n) && !(sh-ifs? (t i))) (chunk t (i + 1) n) i)
   ; split expansion output on IFS: chunks join the field, runs of IFS close it
   (spl t i n done runs seen)
     (? (i = n) [done runs seen]
        (? (sh-ifs? (t i))
           (spl t (skifs t i n) n (closef done runs seen) () 0)
           (: j (chunk t i n)
              (spl t j n done (addrun runs (snip t i j) 1) 1))))

   ; ".." with the $@ law: each positional its own field, edges glue
   (dqat inner st)
     (? !(two? inner) st
        (: sg <inner k <sg
           d (st 0) r (st 1)
           (? (= k 'var && (>sg = "@"))
              (: ps (sh-pos ())
                 st2 (? !(two? ps) st
                        (foldl (\ a p (: dd (a 0) rr (a 1) sn2 (a 2)
                                         (? sn2 [(rr . dd) (addrun () p 0) 1]
                                            [dd (addrun () p 0) 1])))
                               [d (addrun r (? (two? ps) <ps "") 0) 1]
                               >ps))
                 (dqat >inner st2))
              (dqat >inner
                    [d (addrun r (? (= k 'lit) >sg
                                      (= k 'var) (sh-vval >sg)
                                      (= k 'vop) (sh-vopseg sg)
                                      (= k 'sub) (sh-runsub >sg)
                                      (= k 'ari) (sh-arith >sg)
                                      (= k 'lov) (sh-lovseg >sg)
                                      "")
                                 0)
                       1]))))
   (wseg sg st)
     (: d (st 0) r (st 1) sn (st 2)
        k <sg v >sg
        (? (= k 'lit) [d (addrun r v 1) 1]
           (= k 'sq)  [d (addrun r v 0) 1]
           ; ${(..)} is one field, quiet like "${x}": a love answer is a value,
           ; not a chomped byte stream, so nothing here splits it on IFS or reads
           ; it for glob chars. splitting can be bought later; unsplitting cannot.
           (= k 'lov) [d (addrun r (sh-lovseg v) 0) 1]
           ; "": a real (seen) field even empty -- except a lone "$@" over zero
           ; positionals, which contributes nothing (dqat's glue lane sets seen)
           (= k 'dq)  (dqat v [d r (? (two? v) sn 1)])
           (= k 'var) (: t (sh-vval v) (spl t 0 #t d r sn))
           (= k 'vop) (: t (sh-vopseg sg) (spl t 0 #t d r sn))
           (= k 'sub) (: t (sh-runsub v) (spl t 0 #t d r sn))
           (= k 'ari) (: t (sh-arith v) (spl t 0 #t d r sn))
           st))
   (wsegs segs st) (? !segs st (wsegs >segs (wseg <segs st)))

   ; ~ / ~/rest at the word's head -> $HOME, shielded (never split, never glob);
   ; the rest of the run stays live so ~/*.l still globs
   (sh-tilde segs)
     (? (&& (two? segs) (= <<segs 'lit)
            #><segs ((><segs 0) = 126))
        (: t ><segs h ("" + (getenv "HOME"))
           (? (t = "~") (('sq . h) . >segs)
              ((t 1) = 47) (('sq . h) . (('lit . snip t 1 #t) . >segs))
              segs))
        segs)

   ; a finished field: join the runs; a live glob char sends it to sh-glob,
   ; no match keeps the word (the POSIX default)
   (sh-mrep k c) (? (k < 1) "" ((sh-mrep (k - 1) c) + c))
   (sh-field1 runs)
     (: rs (sh-rev runs)
        t (foldl (\ a r (a + <r)) "" rs)
        gb (foldl (\ a r (? a a (>r && sh-anyglob <r))) 0 rs)
        (? gb
           (: m (foldl (\ a r (a + (sh-mrep #<r (? >r "1" "0")))) "" rs)
              g (sh-glob t m)
              (? g g [t]))
           [t]))
   (sh-fields segs)
     (: st (wsegs (sh-tilde segs) [() () 0])
        fs (sh-rev (closef (st 0) (st 1) (st 2)))
        (catmap sh-field1 fs)))
) ; module 'lush

; --- lush 🐚 the evaluator -- AST to processes ---
; no brackets here: the runtime supplies the layer (see job.l for the cat law).
;
; (sh-line src) -> ('more . why) | status. redirects become a spawnmap fdmap
; ((childfd . srcfd)..) applied in order in the child -- POSIX's left-to-right
; law; a heredoc ("<h") is a pipe whose body pours in after the spawn (the
; child drains as we write, so size never deadlocks). the AST is planned into
; closures once (sh-plan) and the plan is what runs, so a loop body, a function
; and a case arm pay their kind tests and their assignment peel once, not per
; run. pipeline stages spawn;
; a stage that is a compound, a builtin, a function or carries assignments
; forks instead (POSIX puts it in a subshell anyway) -- the child lays the
; pipe map with dup2 on itself, evals, quits. control flow threads its
; signals out of band as pairs -- ('brk n) ('cnt n) ('ret st) -- loops catch
; brk/cnt, a function call catches ret, everything else passes them up.
; set -e rides sh-eflag with sh-noe guarding conditions and && || arms.

(module 'lush
(: ; export NAME=VAL -> setenv; export NAME promotes the shell var
   (sh-eqpos s i) (? (i = #s) () (? ((s i) = 61) i (sh-eqpos s (i + 1))))
   (sh-export w)
     (: p (sh-eqpos w 0)
        (? !p (setenv w (sh-vval w))
           (setenv (snip w 0 p) (snip w (p + 1) #w))))

   (cmderr msg) (: _ (say err ("lush: " + (msg + "\n"))) _ (pin sh-status () 1) 1)
   ; the exec is the child's, and a child that cannot exec has no voice: it can
   ; only _exit(127). so an unfindable word is answered here, before the fork, where
   ; there is still a shell to say it -- see sh-simple's spawn arm.
   (sh-saynf w) (say err ("lush: " + (w + ": not found\n")))
   (sh-nofound w) (: _ (sh-saynf w) _ (pin sh-status () 127) (sh-echk 127))

   ; --- redirects -> the fdmap ------------------------------------------------
   ; (sh-rdmap redirs) -> (1 fdmap opens writes) | ('err . msg). opens close in
   ; the child and in the parent after spawn; writes ((wfd . body)..) are
   ; heredoc feeds -- the parent pours and closes them after the spawn.
   (dfd ion d) (? (two? ion) <ion d)
   (rderr opens msg) (: _ (each opens close) ('err . msg))
   (sh-rdmap rs) (rdm rs () () ())
   (rdm rs fdmap opens writes)
     (? !rs [1 (sh-rev fdmap) opens writes]
        (: r <rs ion (r 0) op (r 1)
           (? (op = "<h")
              (: pp (pipe 0)
                 (? (nom? pp) (rderr opens "cannot pipe")
                    (rdm >rs
                         ((dfd ion 0 . <pp) . fdmap)
                         (<pp . opens)
                         ((>pp . sh-textof (r 2)) . writes))))
              (: tf (sh-fields (r 2))
                 (? (!(two? tf) || two? >tf) (rderr opens "ambiguous redirect")
                    (: t <tf
                       (? (op = "<")
                            (: fd (openfd t 0)
                               (? (nom? fd) (rderr opens (t + ": cannot open"))
                                  (rdm >rs ((dfd ion 0 . fd) . fdmap) (fd . opens) writes)))
                          ((op = ">") || (op = ">>"))
                            (: fd (openfd t (? (op = ">") 1 2))
                               (? (nom? fd) (rderr opens (t + ": cannot open"))
                                  (rdm >rs ((dfd ion 1 . fd) . fdmap) (fd . opens) writes)))
                          ((op = ">&") || (op = "<&"))
                            (: d (dfd ion (? (op = "<&") 0 1))
                               (? (t = "-") (rdm >rs ((d . ()) . fdmap) opens writes)
                                  (sh-digits? t) (rdm >rs ((d . sh-int t) . fdmap) opens writes)
                                  (rderr opens (t + ": bad fd"))))
                          (rderr opens (op + ": unsupported")))))))))
   (sh-hwrite wrs)
     (each wrs (\ e (: p (fdopen <e) _ (say p >e) (close p))))

   ; --- assignments: NAME=value words at the head -------------------------------
   (sh-asnname? s)
     (: n #s
        (? !n 0 !(sh-name1? (s 0)) 0
           (: (go i) (? (i = n) 1 (? (sh-name? (s i)) (go (i + 1)) 0)) (go 1))))
   (sh-asn? segs)
     (? !(two? segs) ()
        (: h <segs
           (? !(= <h 'lit) ()
              (: t >h p (sh-eqpos t 0)
                 (? !p ()
                    !(sh-asnname? (snip t 0 p)) ()
                    (link (snip t 0 p)
                          (: rest (snip t (p + 1) #t)
                             (? #rest (('lit . rest) . >segs) >segs))))))))
   (sh-peel ws acc)
     (? (two? ws)
        (: a (sh-asn? <ws)
           (? (two? a) (sh-peel >ws (a . acc)) (sh-rev acc . ws)))
        (sh-rev acc . ws))
   (sh-doasn a) (sh-setvar <a (sh-textof >a))
   (sh-tmpset a)                                ; temporary env around one command
     (: nm <a old (getenv nm)
        _ (setenv nm (sh-textof >a))
        (nm . old))
   (sh-tmprestore e) (setenv <e >e)             ; () old unsets -- the absence lane

   ; --- the four lanes, and what must be TRUE of a word to take each ------------
   ; a command becomes a process only when it must. cheapest first, and the one
   ; question each rung asks before it may be taken:
   ;
   ;   builtin   no process, and no binary consulted: the word is the shell's own
   ;             (sh-binames), so PATH never enters into it.
   ;   in-image  no process. "is running it HERE the same as running it THERE?"
   ;             three kinds of main answer no and each is a silent wrong answer:
   ;             one that QUITS (it would end its caller), one that KEEPS state a
   ;             single run owns, one that BLOCKS (in here ^C kills the shell and
   ;             `kill %1` has no pid to name). the roster below argues each.
   ;   fork      a process, but no exec and no second image wake. "is the thing we
   ;             would exec the thing we already hold?" -- and that is ALL it asks,
   ;             because the three above are a child's own business: its quit is an
   ;             exit status, its state is a copy, its block has a pid to name.
   ;   spawn     a process and an exec. everything else, and the only lane always
   ;             correct: a foreign binary, an explicit path, an ask that was
   ;             settled before a heap existed.
   ;
   ; `ours?` is the question the two middle rungs share -- the two that reach for a
   ; binary at all. autonomous mode (the default) answers it from the verb registry:
   ; a bare word this binary carries is ours whatever PATH holds. -g (gregarious) is strict: PATH's
   ; winner must stat as the running binary, so an installed twin of our own name is
   ; somebody else's build and spawns. a word with a `/` is a demand and spawns in
   ; either mode. asked once per word per session.
   ; ⚠ a rung is only as reachable as the SHAPE allows, and two shapes cannot see
   ; the whole ladder: a pipeline stage skips in-image (a stage has to be a process
   ; to be concurrent, so it starts at fork), and a $( ) body reaches the jug lane
   ; or the stage path and never in-image -- so `$(basename x)` forks where a plain
   ; `basename x` does not. neither is a safety verdict; both are reach.
   ;
   ; --- the in-image lane: a tool whose main rides this image -------------------
   ; a main in this image runs here -- no fork, no exec, no image wake -- and answers
   ; its status as a charm (apps/kore/u.l's urun, the door every kore tool and
   ; mooncc leave through). we take it only when the thing we would have exec'd is
   ; the thing we already hold: PATH's winner for the word must be this very binary,
   ; which stat answers through the symlink (size mode mtime-ns -- the distro's shadow
   ; lane is one artifact on PATH wearing every tool's name). an installed twin of our
   ; own name is the skew the Makefile warns about wearing a friendly face, so it
   ; spawns like anything else; so does a word with a / (an explicit path is a demand).
   ; the verdict is decided once per word and kept: the PATH walk is a session cost.
   ; these are not builtins -- sh-bi? drives sh-stagex's fork decision, and a stage
   ; that forks where it used to spawn is slower for nothing. this is the simple
   ; foreground command only, and it takes its redirects the way a builtin does.
   sh-imgc (tablet 0)                           ; word -> (1 fn whole?) | 0, decided once
   ; an allow list, and a short one on purpose -- the qualifying word is not "is
   ; its main here?" but "is running it here the same thing as running it there?".
   ; three ways that fails, and every one of them is a silent wrong answer:
   ;   * a main that quits takes its caller with it. sh-main ends in one, so an
   ;     in-image `sh -c` would end the line that called it -- everything after it
   ;     gone, status 0. cook-main too.
   ;   * a main that keeps state one run owns. cook's recipe cards are tablets, so a
   ;     recursive $(MAKE) in here would lay the child's rules over the parent's.
   ;     env-main setenvs into the process it is standing in, which would be ours.
   ;   * a main that blocks. a spawned `cat`, `yes`, `sleep`, `tee` is a child ^C
   ;     kills; in here ^C would kill the shell, and there is no pid for `kill %1`
   ;     to name. that is the job-control half, and it wants tasks before it widens.
   ; `kore` is not here either, though kore-main answers -- its own dispatcher reaches
   ; sh-main, cook-main and vi-main, so `kore sh ..` in here would walk straight into the
   ; first failure above through a side door.
   ; so the qualifying test is "cannot block, quits nothing, keeps nothing": bounded by
   ; its own arguments, waiting on no fd it did not open. That is what the list below is,
   ; and it is most of a build -- 152 of the 249 self-execs one seed-only bootstrap spent.
   ; one more class stays out and it is not in the three above: the tools that read
   ; STDIN when handed no file operand (cat head tail wc sort uniq cut tr nl rev grep
   ; sed tee xargs). they want the stdin story -- a question about ^C and a terminal
   ; rather than about anything in this file -- and nothing about the wake waits on
   ; it: a word that misses this list still takes the fork lane below, warm heap and
   ; no exec. running one in here would buy the fork and nothing else.
   ; cook asks `sh-ours? SHELL` first: autonomous mode answers yes to a bare `sh`
   ; anywhere `love make` runs, -g only where PATH's sh is us (the distro).
   ; the checksums are the one row here that reads STDIN when handed no file operand,
   ; and they are in anyway: named a file they are bounded like the rest, and the words
   ; a build spells (`sha256sum dist.tgz`, a -c over a list) always name one.
   sh-imgok '("mooncc" "cc"
              "test" "[" "true" "false" "echo" "printf" "uname" "pwd"
              "basename" "dirname" "readlink" "seq" "ls" "cmp" "diff"
              "mkdir" "rmdir" "rm" "ln" "touch" "chmod" "mv" "cp" "install"
              "objcopy" "cksum" "md5sum" "sha256sum")
   ; nm/ar/ld/as are reachable now (module 'kore exports every <word>-main) but stay
   ; off the list on the qualifying test alone: nothing measured wants them in-image.
   ; the words whose main is not spelled <word>-main. kore-main wants the whole argv
   ; (it reads its own program seat); the rest take the args after the name.
   sh-imgalias '(("mooncc" "moon-run" "moon") ("cc" "moon-run" "moon") ("kore" "kore-main")
                 ("[" "bracket-main") ("objcopy" "objcopy" "holo"))
   (sh-pathdirs _)
     (: p ("" + (getenv "PATH")) n #p
        (go from k acc) (? (n <= k) (sh-rev (snip p from k . acc))
                           ((p k) = 58) (go (k + 1) (k + 1) (snip p from k . acc))
                           (go from (k + 1) acc))
        (go 0 0 ()))
   (sh-slashed? w) (: n #w
                      (go k) (? (n <= k) 0 ((w k) = 47) 1 (go (k + 1)))
                      (go 0))
   ; asked at the call: the kernel bakes this file and carries no host nif, where a
   ; top-level bind would fold the baking love's own seat in and call every tool ours.
   (sh-seat _) (? (member? 'selfpath (names ())) (selfpath 0) ())
   (sh-self? p) (: a (stat p) ((two? a) && (a = (stat (sh-seat ())))))
   (sh-whichp w)                                ; PATH's winner for w -> (1 path), or ()
     (? (sh-slashed? w) (? (two? (stat w)) [1 w] ())
        (: (go l) (? !(two? l) ()
                     (: d (? #<l <l ".") p (d + ("/" + w))
                        (? (two? (stat p)) [1 p] (go >l))))
           (go (sh-pathdirs ()))))
   (sh-onpath? w)                               ; is PATH's winner for w this binary
     (: (go l) (? !(two? l) 0
                  (: d (? #<l <l ".") p (d + ("/" + w))
                     (? (two? (stat p)) (sh-self? p) (go >l))))
        (go (sh-pathdirs ())))
   ; does this binary carry the word as a verb? the registry's own answer, PATH aside
   (sh-verbw? w) (: f (from 'verbs 'word) (? (lit? f) !(nil? (f w)) 0))
   ; --- the mode: autonomous or gregarious ---------------------------------
   ; autonomous (the default, -a): a bare word naming a verb this binary carries is
   ; ours whatever PATH holds -- it runs in-image or on the forked warm heap, and the
   ; shapes that must spawn spawn this binary under the word. gregarious (-g):
   ; ours only when PATH's winner stats as this binary, which is what a bootstrap
   ; through ambient tools wants (`love seed` sets it). the flag word wins, else
   ; LUSHFLAGS in the environment (its last a or g), so a build's every shell reads
   ; the seed's choice. the shell's entry pins the box once (so a prefix assignment
   ; on a command line changes the CHILD's mode, not this shell's); an unseated
   ; caller -- cook, a -e -- reads the environment at the ask and pins nothing, or
   ; a bake would carry the baking process's answer into the image.
   (sh-envflag _) (: s ("" + (getenv "LUSHFLAGS")) n #s
                     (go k v) (? (n <= k) v (go (k + 1) ((s k) @ 97 0 103 1 _ v)))
                     (go 0 0))
   (sh-greg? _) (: v (peep sh-gflag () 'no)       ; peep: a pinned 0 is a verdict, not an absence
                    (? (= v 'no) (sh-envflag 0) v))
   ; would spawning this word land on the binary we are already running? the one
   ; policy question behind every in-image lane -- lush's own, and cook's.
   (sh-ours? w) (? (sh-slashed? w) (sh-self? w)
                   (sh-greg? 0) (sh-onpath? w)
                   (sh-verbw? w) 1
                   (sh-onpath? w))
   ; can this seat run the word at all? PATH answers wherever there is a seat to
   ; exec -- a hosted love resolves a word to a file. a seat with none never execs:
   ; the kernel's spawn hands the word to the verb registry, so that is the authority
   ; there, and asking PATH would call every tool it carries missing. autonomous
   ; mode knows its own verbs the same way.
   (sh-known? w) (? (nil? (sh-seat ())) (sh-verbw? w)
                    (!(sh-greg? 0) && (sh-verbw? w)) 1
                    (two? (sh-whichp w)))
   ; the argv a spawn execs: autonomous mode spawns this binary under a bare verb
   ; word, so PATH decides nothing there either; anything else runs as spelled
   (sh-spawnv argv) (: w <argv exe (sh-seat ())
                       (? (&& !(sh-greg? 0) (string? exe) !(sh-slashed? w) !(sh-dotl? w)
                              (sh-verbw? w))
                          (exe . argv)
                          argv))
   (sh-imgask w)
     (: al (sh-assoc w sh-imgalias)
        mn (? (two? al) <>al (w + "-main"))
        md (? ((two? al) && (two? >>al)) (from (intern <>>al)) ())   ; the row's module, or ()
        nm (intern mn)
        f0 (? (tablet? md) (md nm)                    ; the alias row named the module
              (member? nm (names ())) (ev nm)         ; a bare global
              (from 'kore nm))                        ; else the applets' home module
        (? (&& (sh-smem? w sh-imgok) !(sh-slashed? w) !(nil? f0) (sh-ours? w))
           [1 (sh-imgwrap f0 mn) (mn = "kore-main")]
           0))
   ; the applet is wrapped, because udie raises rather than exiting: `(scare 'leave c)`
   ; is what the verb table's own `urun` catches, and the in-image lane reaches the applet
   ; bare. Unwrapped, one `test` on a bad expression escapes as an unhandled raise and
   ; takes the whole shell down instead of failing one command. moon-run wants no wrap --
   ; it answers its status by construction, which is why it was the safe single entry.
   ; urun lives in module 'kore now; a miss absorbs to (), which keeps the no-wrap lane.
   (sh-imgwrap f mn) (: ur (from 'kore 'urun)
                        (? ((mn = "moon-run") || !ur) f (\ as (ur f as))))
   (sh-assoc w l) (? !(two? l) 0 (w = <<l) <l (sh-assoc w >l))
   (sh-imgfn w) (: v (peep sh-imgc w 'no)
                   (? !(= v 'no) v
                      (: f (sh-imgask w) _ (pin sh-imgc w f) f)))
   ; --- the fork lane: an external word whose PATH winner is this binary runs in
   ; a forked child -- the warm heap rides, no exec, no wake. it asks `ours?` and
   ; nothing else about the main, for the reason the ladder above gives.
   ; no verb table is read here and none is wanted: the child hands its line to `cli-line`,
   ; core/boot/post.l's own tail, which is the very thing the exec would have reached --
   ; argv[0] door, rail, and the registry lookup inside it. a foreign binary spawns
   ; as ever, and so does a slashed or .l word: an explicit path is a demand.
   ; decided once per word, sh-imgc's shape -- and cli-line is absent on a frontend
   ; that never evaluated cli.l (the kernel, whose seat has no selfpath either), so
   ; the lane is dormant there and the task shim keeps the spawn.
   sh-forkc (tablet 0)                          ; word -> 1 | 0, decided once
   (sh-dotl? w) (: n #w ?((2 < n) && (snip w (n - 2) n = ".l")))
   (sh-cliline _) (? (member? 'cli-line (names ())) (ev 'cli-line) ())   ; a bare global, read at the call
   ; a seat with no fork: inle runs a process as a task (kmain's shim, the spawnmap
   ; lane below), and the fork it pins is a no-op -- so no word forks there
   (sh-forkseat? _) (? (member? 'love-os (names ())) !(member? (ev 'love-os) '(inle wasm)) 1)
   (sh-forkask w) (? (|| (sh-slashed? w) (sh-dotl? w)) 0
                     !(sh-forkseat? 0) 0
                     (&& (sh-cliline ()) (sh-ours? w)) 1
                     0)
   (sh-forkfn w) (: v (peep sh-forkc w 'no)
                    (? !(= v 'no) v
                       (: f (sh-forkask w) _ (pin sh-forkc w f) f)))
   ; a shell starting on a forked heap inherits its parent's verdicts, and its own
   ; mode may differ: sh-main drops them, and each word is asked again
   (sh-forget _) (: (clear t) (each (keys t) (\ k (pull t k 0)))
                    _ (clear sh-imgc) (clear sh-forkc))
   ; ..and the shapes the word alone cannot answer for, so they are asked per
   ; command. bake, wake and LOVE_NO_IMAGE are settled before a heap exists, which
   ; is the one thing a fork can never redo: `bake` and `wake` are read in C ahead
   ; of any love (wake picks which heap there is, bake must snapshot before the
   ; session layer), and LOVE_NO_IMAGE asks for a boot this process already made
   ; the other way.
   ; the bare word is the fourth, and it is asked of the STAGE and not of the word:
   ; the fear is that a word with nothing past it reaches a repl, and the child is
   ; handed tty=0 and would drink stdin where the exec'd twin would have prompted.
   ; a pipe or a `<` laying fd 0 settles it -- that is every `| cat`, `| sort`,
   ; `| tee` there is. ⚠ the shell's OWN stdin cannot stand in for the stage's: a
   ; script is not interactive and still leaves the terminal on fd 0, so a bare word
   ; that lays nothing spawns, and lets love make its own isatty answer.
   (sh-fd0? fdmap) (? !(two? fdmap) 0 (= <<fdmap 0) 1 (sh-fd0? >fdmap))
   (sh-forkok? av fdmap)
     (: a >av                                    ; cap is total, so a bare word reads () here
        (? (|| (<a = "bake") (<a = "wake")) 0
           ((0 < tally (getenv "LOVE_NO_IMAGE")) && (member? 'love-image (names ()))) 0
           (two? a) 1
           (sh-fd0? fdmap) 1
           0))
   ; the fork child itself, shared by the pipeline stage and the simple foreground
   ; command. answers the pid in the parent (or fork's own nom) and never answers
   ; in the child. every line of it is child hygiene -- copy the whole thing, not
   ; parts, if love code is ever forked anywhere else.
   (sh-fork1 argv fdmap allclose)
     (: p (fork 0)
        (? (p = 0)
           (: _ (wear ())               ; a child wears the console: its fds are the dup2 below
              _ (sh-dropcaps ())        ; ...and it is inside no capture of ours
              ; the five tty ignores are the SHELL's (main.l): a spawned child sheds
              ; them through exec, this one by hand -- or a forked `sleep` would
              ; shrug off the very ^C that names it
              _ (signal sig-int 0) _ (signal sig-quit 0) _ (signal sig-tstp 0)
              _ (signal sig-ttou 0) _ (signal sig-ttin 0)
              ; any scare is the child's death, never a second shell:
              ; 'leave carries the tool's status, the rest die at 1
              _ (hear (\ a b (? (= a 'leave) (quit b)
                                (: _ (say err ";; ") _ (print err a)
                                   _ (say err " ") _ (print err b)
                                   _ (put err 10) (quit 1)))))
              _ (each fdmap (\ e (dup2 >e <e)))
              _ (each allclose (\ fd (? (2 < fd) (close fd) 0)))
              ; 0: a child has a shell already. cli-line ANSWERS the line's status, a
              ; charm, and the process answers with it -- as main.c does for the exec'd
              ; twin (`kore false` answers 1 and quits nothing); anything else is 0
              r ((sh-cliline ()) argv 0)
              (quit (charm? r ? (r & 255) 0)))
           p))

   ; --- builtins: a charm status, a control pair (brk/cnt/ret), or 'nope --------
   sh-binames '("exit" "cd" "export" "pwd" "jobs" "fg" "bg" ":" "true" "false" "command"
                "read" "set" "shift" "unset" "eval" "." "wait" "local"
                "break" "continue" "return" "ev" "trap")
   (sh-bi? nm) (sh-smem? nm sh-binames)
   (sh-readb args)
     (: args2 (? (two? args && (<args = "-r")) >args args)
        nms (? (two? args2) args2 ["REPLY"])
        ln (sh-getline in)
        (? (= ln 'eof) 1 (: _ (sh-readset nms ln 0 #ln) 0)))
   (sh-readset nms ln i n)
     (: i2 (skifs ln i n)
        (? !(two? >nms) (sh-setvar <nms (sh-rtrim (snip ln i2 n)))
           (: j (chunk ln i2 n)
              _ (sh-setvar <nms (snip ln i2 j))
              (sh-readset >nms ln j n))))
   (sh-rtrim s)
     (: (go k) (? ((0 < k) && sh-ifs? (s (k - 1))) (go (k - 1)) (snip s 0 k))
        (go #s))
   (sh-setb args)
     (? !(two? args) 0
        (: a <args
           (? (a = "--") (: _ (pin sh-pos () >args) 0)
              ((1 < #a) && (((a 0) = 45) || ((a 0) = 43)))
                (: on (? ((a 0) = 45) 1 0)
                   (go i) (? (i = #a) (sh-setb >args)
                             (: b (a i)
                                _ (? (b = 101) (pin sh-eflag () on)
                                     (b = 117) (pin sh-uflag () on)
                                     (b = 120) (pin sh-xflag () on)
                                     0)
                                (go (i + 1))))
                   (go 1))
              (: _ (pin sh-pos () args) 0))))
   (sh-dotb args)
     (? !(two? args) (cmderr ". wants a file")
        (: f <args
           (? (two? (stat f))
              (: _ (pin sh-retf () 0)            ; a stale interactive `return` must not clip the file
                 p (open f "r") _ (sh-lines p "") _ (close p) (sh-status ()))
              (cmderr (f + ": not found")))))
   ; trap [action] condition.. -- POSIX. No operands lists what is set, in a form
   ; that reads back in. `-` as the action restores the default, '' ignores, and
   ; both are spelled by removing the entry: nothing here delivers a signal, so an
   ; ignored one and a defaulted one behave alike (see job.l's note).
   ; a condition alone is the reset form -- `trap INT` is not "trap with an
   ; empty action", it is `trap - INT`. a first word that names a condition is
   ; therefore never an action, which is also why exit and 0 both spell the same
   ; row: sh-cond normalises before anything is stored.
   (sh-cond w)
     (: u (sh-upper w)
        v (? (#u > 3 && (snip u 0 3) = "SIG") (snip u 3 #u) u)
        (? (v = "0") "EXIT" v))
   (sh-upper s)                                 ; an index walk: foldl does not take a string
     ((: (g i acc)
         (? (i = tally s) acc
            (: b (s i) (g (1 + i) (acc + string (? (97 <= b < 123) (b - 32) b))))))
      0 "")
   (sh-cond? w) (: c (sh-cond w)
                   (any (\ k (k = c)) '("EXIT" "INT" "TERM" "HUP" "QUIT" "USR1" "USR2"
                                        "ALRM" "PIPE" "CHLD" "TSTP" "CONT" "ABRT")))
   ; every lane below ends at sh-rearm: the set of watched signals is fixed when
   ; the fd is made, so adding or dropping a condition means building a new one.
   (sh-trapb args) (: r (sh-trapb2 args) _ (sh-rearm 0) r)
   (sh-trapb2 args)
     (? !(two? args)
        (: _ (each (keys sh-traps)
                   (\ k (puts ("trap -- '" + (peep sh-traps k "") + "' " + k + "\n"))))
           0)
        (: a2 (? (<args = "--") >args args)
           (? !(two? a2) 0
              (sh-cond? <a2) (: _ (each a2 (\ w (pull sh-traps (sh-cond w) 0))) 0)
              (<a2 = "-") (: _ (each >a2 (\ w (pull sh-traps (sh-cond w) 0))) 0)
              (: act <a2
                 conds >a2
                 bad (filter (\ w !(sh-cond? w)) conds)
                 (? (two? bad)
                    (: _ (say err ("lush: trap: " + <bad + ": bad condition\n")) 1)
                    ; a condition ignored on entry is skipped, silently: POSIX says
                    ; it cannot be trapped and that no error need be reported. The
                    ; reset lanes are not filtered -- `trap - INT` on one is already
                    ; a no-op, and refusing it would be an error POSIX does not want.
                    (: _ (each conds
                               (\ w (: c (sh-cond w)
                                       (? (sh-ignored? c) 0
                                          #act (pin sh-traps c act)
                                          (pull sh-traps c 0)))))
                       0))))))
   (sh-localb args)
     (: _ (each args (\ w (: p (sh-eqpos w 0)
                             (? !p (pin sh-vars w "")
                                (pin sh-vars (snip w 0 p) (snip w (p + 1) #w))))))
        0)
   (sh-waitb args)                              ; wait [pid..] -> the last one's status
     (? (two? args)
        (foldl (\ a p (: st (wait (sh-int p))
                         _ (sh-bgnote (sh-int p))
                         (? (charm? st) st 127)))
               0 args)
        (: _ (each (keys sh-jobs)
                   (\ nn (: j (sh-jobs nn)
                            (? !j 0 (: _ (each (j 0) (\ p (wait p)))
                                       (pull sh-jobs nn 0))))))
           0))
   ; `ev EXPR..` -- the arguments join as one love form (the `eval` builtin's
   ; join), its answer says on out, and its truth bit is the status: positive is
   ; true, so `ev 1 + 2` is a calculator and `if ev '3 > 2'` is a test -- the one
   ; thing ${( )} cannot do, since an expansion is a word and not a command. -n
   ; says nothing and answers the status alone (cli.l's -e/-n pair, same letters).
   ; the form runs in this image, so a binding it makes is still there next line.
   ; not spelled `love`. a builtin shadows its PATH twin, and the interpreter
   ; and this lane spell their arguments differently -- `love -e "1 + 2"` would
   ; read `-e` as a datum and fold it into the form, answering 3.0 for 3. The two
   ; want different command lines and isolated processes, so the word `love` stays
   ; the binary's and spawns. `ev` is love's own name for the evaluator (core/boot/ev.l).
   (sh-loveb args)
     (: q ((two? args) && (<args = "-n"))
        src (sh-unwords (? q >args args))
        (? !#src 0
           (: r (sh-loveval src)
              (? (= <r 'err) (sh-lovesay >r)
                 (: v >r
                    _ (? q 0 (puts ((sh-lovetext v) + "\n")))
                    (? v 0 1))))))
   (sh-builtin argv)
     (: cmd <argv
        (? (cmd = "exit")
             (: st (? >argv (sh-int <>argv) (sh-status ()))
                (sh-leave st))
           (cmd = "cd")
             (: t (? >argv <>argv ("" + (getenv "HOME")))
                r (chdir t)
                (? !r 0 (: _ (say err ("lush: cd: " + (t + "\n"))) 1)))
           (cmd = "trap") (sh-trapb >argv)
           (cmd = "export") (: _ (each >argv sh-export) 0)
           ; `command -v W` -- the probe every configure-shaped script opens with, and a
           ; special builtin, so it was forking and answering ENOENT: 12 of them in one
           ; build, each reading as "the tool is absent". Absent is the honest answer for
           ; ccache and objdump, which is why nothing looked broken -- but a probe that is
           ; wrong by accident is wrong. a builtin answers its own name; a PATH word its path.
           (cmd = "command")
             (: a >argv
                (? ((two? a) && (<a = "-v"))
                   (: w (? (two? >a) <>a "")
                      (? (w = "") 1
                         (sh-bi? w) (: _ (puts (w + "\n")) 0)
                         (: p (sh-whichp w) (? (two? p) (: _ (puts (<>p + "\n")) 0) 1))))
                   !(two? a) 1
                   (sh-simple2 a ())))                 ; `command W ..` -- run W, no function lookup
           (cmd = "pwd")  (: _ (puts ((cwd 0) + "\n")) 0)
           (cmd = "jobs") (: _ (each (sort (keys sh-jobs))
                                     (\ n (puts (sh-jobline n (sh-jobs n))))) 0)
           (cmd = "fg")   (: _ (sh-fg (sh-jobn argv)) (sh-status ()))
           (cmd = "bg")   (sh-bg (sh-jobn argv))
           (cmd = ":")    0
           (cmd = "true") 0
           (cmd = "false") 1
           (cmd = "read") (sh-readb >argv)
           (cmd = "set")  (sh-setb >argv)
           (cmd = "shift") (: n (? >argv (sh-int <>argv) 1)
                              _ (pin sh-pos () (drop n (sh-pos ()))) 0)
           (cmd = "unset") (: _ (each >argv
                                      (\ nm (: _ (pull sh-vars nm 0) (setenv nm ())))) 0)
           (cmd = "eval") (: c (sh-unwords >argv)
                             (? #c
                                (: r (sh-line c) (? (two? r) (cmderr "eval: unexpected eof") r))
                                0))
           (cmd = "ev")   (sh-loveb >argv)
           (cmd = ".")    (sh-dotb >argv)
           (cmd = "local") (sh-localb >argv)
           (cmd = "wait") (sh-waitb >argv)
           (cmd = "break") ('brk . (? >argv (sh-int <>argv) 1))
           (cmd = "continue") ('cnt . (? >argv (sh-int <>argv) 1))
           (cmd = "return") ('ret . (? >argv (sh-int <>argv) (sh-status ())))
           'nope))

   ; --- the function book -------------------------------------------------------
   ; a body is a plan (a closure), so two? cannot tell one from absence -- peep
   ; names the miss with a mint no stored value can pose as (spec.l's total test)
   (sh-fnof nm) (peep sh-funcs nm sh-nofn)
   (sh-fn? nm) !(= sh-nofn (sh-fnof nm))

   ; --- stage expansion + the spawn engines ------------------------------------
   (sh-makepipes n) (? (n < 1) () (pipe 0 . sh-makepipes (n - 1)))
   (sh-flat ps) (? !ps () (<<ps . (><ps . sh-flat >ps)))
   ; a stage: ('x argv fdmap opens writes) spawns; ('a ast () () ()) forks --
   ; compounds, builtins, functions and assignment-bearing commands all fork
   ; (the child re-expands, so its env sees its own assignments)
   (sh-stagex cmds acc)
     (? !cmds [1 (sh-rev acc)]
        (: c <cmds
           (? !(= <c 'cmd)
              (sh-stagex >cmds ['a c () () () . acc])
              (: pk (sh-peel (c 1) ())
                 argv (catmap sh-fields >pk)
                 (? (|| (two? <pk) !(two? argv)
                        (sh-bi? <argv) (sh-fn? <argv))
                    (sh-stagex >cmds ['a c () () () . acc])
                    (: rm (sh-rdmap (c 2))
                       (? (= <rm 'err) (: _ (stclean acc) rm)
                          (sh-stagex >cmds
                                     ['x argv (rm 1) (rm 2) (rm 3) . acc]))))))))
   (stclean acc) (each acc (\ st (each (st 3) close)))
   ; spawn one stage: external -> spawnmap; anything else -> fork, the child
   ; lays the pipe map on itself (dup2), closes the plumbing, evals, quits
   ; flush first, both lanes: a builtin says through `out` and buffers, a child
   ; writes the fd straight, and when the two share one -- a pipe, a file, a $( )
   ; capture -- whatever we still hold would land after bytes it was said before.
   (sh-spawn1 st base allclose pg fgi)
     (: _ (flush out) _ (flush err)
        (? (= (st 0) 'x)
           (: w <(st 1)
              fm (base + (st 2))
              fk (? (sh-forkok? (st 1) fm) (sh-forkfn w) 0)
              (? fk
                 ; ours: fork, no exec -- the child runs the whole line through
                 ; cli-line on this warm heap and quits with its status: a real
                 ; pid, so the pipeline's bookkeeping and the job table read it
                 ; like any spawn. pg/fg are not taken (the 'a lane's stance): the child
                 ; stays in the shell's group, which keeps the tty for a
                 ; foreground job, and sheds the group's ignores in sh-fork1.
                 (sh-fork1 (st 1) fm allclose)
                 ; foreign, or an explicit path: spawned as ever -- its 127 is the
                 ; child's own and the pipeline's status bookkeeping wants a real
                 ; pid; only the word is ours to say
                 (: _ (? (sh-known? w) 0 (sh-saynf w))
                    (spawnmap (sh-spawnv (st 1)) fm allclose pg fgi))))
           (: p (fork 0)
              (? (p = 0)
                 (: _ (wear ())                   ; a child wears the console: its fds are the dup2 below, and a jug is not one
                    _ (sh-dropcaps ())            ; ...and it is inside no capture of ours
                    _ (each base (\ e (dup2 >e <e)))
                    _ (each allclose (\ fd (? (2 < fd) (close fd) 0)))
                    s (sh-eval (st 1))
                    (quit (? (charm? s) s (? (= <s 'ret) >s 0))))
                 p))))
   ; stage 0 may lead a pgrp + take the tty, the rest join; base map = pipe
   ; wiring, a stage's own redirects land after. lastout >= 0 sends the last
   ; stage's stdout there (the cmdsub lane).
   (sh-spawnst sts pipes allclose lastout i last pg fg pids)
     (? !sts (sh-rev pids)
        (: st <sts
           base (+ (? (0 < i) [(0 . <(pipes (i - 1)))] ())
                   (? (i < last) [(1 . >(pipes i))]
                      (? (lastout < 0) () [(1 . lastout)])))
           pid (sh-spawn1 st base allclose pg (? (i = 0) fg 0))
           (sh-spawnst >sts pipes allclose lastout (i + 1) last
                       (? (pg < 0) pg (? (i = 0) pid pg)) fg (pid . pids))))
   (sh-echk st)
     (? (&& (charm? st) !(st = 0) (sh-eflag ()) (0 = (sh-noe ())) !(sh-tty ()))
        (sh-leave st) st)
   (sh-pipeline cmds bg)
     (: sx (sh-stagex cmds ())
        (? (= <sx 'err) (cmderr >sx)
           (: sts (sx 1)
              n (#sts - 1)
              pipes (sh-makepipes n)
              pfds (sh-flat pipes)
              ofds (catmap (\ st (st 3)) sts)
              wrs (catmap (\ st (st 4)) sts)
              allclose (pfds + (ofds + (map cap wrs)))
              pids (sh-spawnst sts pipes allclose (0 - 1) 0 n
                               (sh-pgm 0) (? bg 0 (sh-fgm 0)) ())
              _ (each (pfds + ofds) close)
              _ (sh-hwrite wrs)
              (? bg
                 (: jn (sh-addjob pids 'running ((sh-curline ()) + " &"))
                    _ (pin sh-lastbg () (last pids))      ; $!
                    _ (? (sh-tty ()) (puts ("[" + ((show jn) + ("] " + ((sh-unwords (map show pids)) + "\n"))))) 0)
                    0)
                 (: _ (sh-waitfg pids (sh-curline ())) (sh-echk (sh-status ())))))))
   ; one simple foreground command: assignments, function, builtin, or a spawn.
   ; pk is the peel -- (assignments . words) -- split at plan time, it is syntax
   (sh-simple pk rs)
     (: asns <pk
        _ (pin sh-substat () 0)          ; ahead of both expansions -- see below
        argv (catmap sh-fields >pk)
        (? !(two? argv)
           ; no command name: POSIX says the status is the last $( ) performed,
           ; and the words expand before the assignments do -- so `v=1 $(exit 3)`
           ; is 3 and `v=$(exit 2) $(exit 3)` is 2. none ran leaves the clean 0
           (: _ (each asns sh-doasn)
              st (sh-substat ())
              _ (pin sh-status () st)
              (sh-echk st))
           (: saves (map sh-tmpset asns)
              r (sh-simple2 argv rs)
              _ (each saves sh-tmprestore)
              r)))
   ; run a thunk with redirects laid over our own fds (dup saves, dup2 swaps,
   ; swap back after) -- functions and builtins take their > < this way
   (sh-withrs rs th)
     (? !(two? rs) (th ())
        (: rm (sh-rdmap rs)
           (? (= <rm 'err) (cmderr >rm)
              (: fdmap (rm 1) opens (rm 2) wrs (rm 3)
                 _ (sh-hwrite wrs)
                 saves (map (\ e (<e . dup <e)) fdmap)
                 _ (each fdmap (\ e (? (charm? >e) (dup2 >e <e)
                                       (close <e))))
                 _ (each opens close)
                 s (th ())
                 _ (flush out) _ (flush err)
                 _ (each saves (\ e (? (nom? >e) (close <e)
                                       (: _ (dup2 >e <e) (close >e)))))
                 s))))
   (sh-simple2 argv rs)
     (: _ (? (sh-xflag ()) (say err ("+ " + ((sh-unwords argv) + "\n"))) 0)
        fn (sh-fnof <argv)
        (? !(= sh-nofn fn) (sh-withrs rs (\ _ (sh-fncall fn argv)))
           (sh-bi? <argv)
             (: b (sh-withrs rs (\ _ (sh-builtin argv)))
                (? (two? b) b                            ; brk/cnt/ret ride out
                   (charm? b) (: _ (pin sh-status () b) (sh-echk b))
                   b))
           (two? (sh-imgfn <argv))                       ; the in-image lane
             (: g (sh-imgfn <argv)
                f (g 1)
                s (sh-withrs rs (\ _ (f (? (g 2) argv >argv))))
                st (? (charm? s) s 0)
                _ (pin sh-status () st)
                (sh-echk st))
           (: rm (sh-rdmap rs)
              (? (= <rm 'err) (cmderr >rm)
                 (: opens (rm 2) wrs (rm 3)
                    ac (opens + (map cap wrs))
                    _ (flush out) _ (flush err)      ; see sh-spawn1: the child writes the fd straight
                    ; ours, but not safe to run in THIS process: fork the warm heap
                    ; rather than exec a second wake. the list above asks "is running
                    ; it here the same thing as running it there?" and a word that
                    ; fails that is still ours to fork -- a quit is the child's exit,
                    ; kept state is a copy, a block has a pid to name. same lane a
                    ; pipeline stage takes, and pg/fg are likewise not taken: the
                    ; child stays in the shell's group, which keeps it the terminal.
                    fk (? (sh-forkok? argv (rm 1)) (sh-forkfn <argv) 0)
                    ; the redirects are already open, which is where a shell answers an
                    ; unfindable word from -- `nope > f` still makes f, then says so
                    pid (? fk (sh-fork1 argv (rm 1) ac)
                           (sh-known? <argv) (spawnmap (sh-spawnv argv) (rm 1) ac (sh-pgm 0) (sh-fgm 0))
                           ())
                    _ (each opens close)
                    _ (sh-hwrite wrs)
                    (? (nom? pid) (cmderr (<argv + ": cannot spawn"))
                       !(charm? pid) (sh-nofound <argv)
                       (: _ (sh-waitfg [pid] (sh-unwords argv))
                          (sh-echk (sh-status ())))))))))
   (sh-fncall body argv)
     (: op (sh-pos ())
        _ (pin sh-pos () >argv)
        s (body ())
        _ (pin sh-pos () op)
        (? (two? s && (= <s 'ret))
           (: st >s _ (pin sh-status () st) st)
           s))

   ; --- the AST walk: plan once, then run ---------------------------------------
   ; (sh-plan ast) -> a plan, a thunk fired with the unit. every kind test, every
   ; descent and the assignment peel happen here, so a loop body, a function and a
   ; case arm pay them once instead of once per run. a plan still answers its
   ; control pair rather than jumping, so the fd restores between a `break` and
   ; its loop all run -- the reason this is not call-cc.
   (sh-zero _) (: _ (pin sh-status () 0) 0)
   (sh-eval a) ((sh-plan a) ())          ; the raw-AST door: a forked stage, a line
   ; a condition (or an && || arm, or a ! body) runs with errexit off
   (sh-guarded p)
     (: _ (pin sh-noe () (1 + (sh-noe ())))
        s (p ())
        _ (pin sh-noe () ((sh-noe ()) - 1))
        s)
   (sh-plan a)
     (? !a (\ _ (sh-status ()))
        (: k <a
           (? (= k 'seq)
                (: p (sh-plan (a 1)) q (sh-plan (a 2))
                   (\ _ (: s (p ()) (? (two? s) s (q ())))))
              (= k 'and)
                (: p (sh-plan (a 1)) q (sh-plan (a 2))
                   (\ _ (: s (sh-guarded p) (? (two? s) s (s = 0) (q ()) s))))
              (= k 'or)
                (: p (sh-plan (a 1)) q (sh-plan (a 2))
                   (\ _ (: s (sh-guarded p) (? (two? s) s (s = 0) s (q ())))))
              (= k 'not)
                (: p (sh-plan (a 1))
                   (\ _ (: s (sh-guarded p)
                           (? (two? s) s
                              (: ns (? (s = 0) 1 0) _ (pin sh-status () ns) ns)))))
              (= k 'bg)                        ; a lone command backgrounds as a
                (: b (a 1)                ; pipeline of one
                   cmds (? (= <b 'pipe) (b 1) [b])
                   (\ _ (sh-pipeline cmds 1)))
              (= k 'pipe) (: cmds (a 1) (\ _ (sh-pipeline cmds 0)))
              (= k 'cmd)  (: pk (sh-peel (a 1) ()) rs (a 2)
                               (\ _ (sh-simple pk rs)))
              (= k 'if)
                (: cls (map (\ c (sh-plan <c . sh-plan >c)) (a 1))
                   els (? (two? (a 2)) (sh-plan (a 2)) sh-zero)
                   (\ _ (sh-if cls els)))
              (= k 'while)
                (: c (sh-plan (a 1)) b (sh-plan (a 2))
                   (\ _ (sh-wloop 0 c b 0)))
              (= k 'until)
                (: c (sh-plan (a 1)) b (sh-plan (a 2))
                   (\ _ (sh-wloop 1 c b 0)))
              (= k 'for)                       ; the words re-expand each run
                (: nm (a 1) ws (a 2) b (sh-plan (a 3))
                   (\ _ (sh-floop nm (catmap sh-fields ws) b 0)))
              (= k 'case)                      ; a bodyless arm takes the zero at
                (: w (a 1)                ; plan time -- an AST tells its own
                   its (map (\ it (link <it      ; absence by two?, a plan cannot
                                        (? (two? >it) (sh-plan >it) sh-zero)))
                            (a 2))
                   (\ _ (sh-citems (sh-textof w) its)))
              (= k 'group) (sh-plan (a 1))
              (= k 'subsh) (: b (sh-plan (a 1)) (\ _ (sh-subsh b)))
              (= k 'fun)   (: nm (a 1) b (sh-plan (a 2))
                                (\ _ (: _ (pin sh-funcs nm b) 0)))
              (= k 'rdr)   (: b (sh-plan (a 1)) rs (a 2)
                                (\ _ (sh-rdr b rs)))
              (\ _ (cmderr "unknown form")))))
   (sh-if clauses els)
     (? !(two? clauses) (els ())
        (: c <clauses
           s (sh-guarded <c)
           (? (two? s) s
              (s = 0) (>c ())
              (sh-if >clauses els))))
   (sh-wloop inv cond body last)
     (: s (sh-guarded cond)
        (? (two? s) s
           (: go? (? inv !(s = 0) (s = 0))
              (? !go? (: _ (pin sh-status () last) last)
                 (: b (body ())
                    (? (two? b)
                       (: kk <b nn >b
                          (? (= kk 'brk) (? (1 < nn) ('brk . (nn - 1)) (sh-zero ()))
                             (= kk 'cnt) (? (1 < nn) ('cnt . (nn - 1))
                                              (sh-wloop inv cond body last))
                             b))
                       (sh-wloop inv cond body b)))))))
   (sh-floop nm fs body last)
     (? !(two? fs) (: _ (pin sh-status () last) last)
        (: _ (sh-setvar nm <fs)
           b (body ())
           (? (two? b)
              (: kk <b nn >b
                 (? (= kk 'brk) (? (1 < nn) ('brk . (nn - 1)) (sh-zero ()))
                    (= kk 'cnt) (? (1 < nn) ('cnt . (nn - 1)) (sh-floop nm >fs body last))
                    b))
              (sh-floop nm >fs body b))))
   (sh-anymatch t pats)
     (? !(two? pats) 0
        (: pm (sh-patmask <pats)
           (? (sh-fmatch <pm >pm t) 1 (sh-anymatch t >pats))))
   (sh-citems t items)
     (? !(two? items) (sh-zero ())
        (: it <items
           (? (sh-anymatch t <it) (>it ())
              (sh-citems t >items))))
   ; under a forkless capture a `( )` does not fork: the child would inherit
   ; the drainer and stall on it, and the roster sh-subback puts back is already
   ; the subshell's. outside one the fork stands -- it is the reference reading,
   ; and it isolates the fds and the job table this lane cannot.
   (sh-subsh b)
     (? (sh-subfds ()) (sh-subhere b)
        (: _ (flush out) _ (flush err)
           p (fork 0)
           (? (p = 0) (: _ (wear ())         ; the child's stdio is its fds, never a jug this task wears
                         _ (sh-dropcaps ())  ; ...and it is inside no capture of ours
                         s (b ())
                         (quit (? (charm? s) s (? (= <s 'ret) >s 0))))
              (nom? p) (cmderr "cannot fork")
              (: _ (sh-waitfg [p] (sh-curline ())) (sh-echk (sh-status ()))))))
   ; the roster sh-subback puts back is the subshell's contract, so it has to ride
   ; the raised way out too: a scare under the body would leak the body's cwd, vars,
   ; funcs, positionals, $0, flags and environment into the shell that ran it.
   (sh-subhere b)                            ; a subshell in our own process
     (: snap (sh-subsave ())
        s (mind b () (\ _ (sh-subback snap)))
        st (sh-capstat s)                    ; brk/cnt do not cross a subshell either
        _ (pin sh-status () st)
        (sh-echk st))
   ; a compound's trailing redirect: swap our own fds (dup saves, dup2 lays),
   ; run in-process (a `done < file` loop keeps its variables), swap back
   (sh-rdr b rs)
     (: rm (sh-rdmap rs)
        (? (= <rm 'err) (cmderr >rm)
           (: fdmap (rm 1) opens (rm 2) wrs (rm 3)
              _ (sh-hwrite wrs)                       ; a heredoc body fits the pipe
              saves (map (\ e (<e . dup <e)) fdmap)
              _ (each fdmap (\ e (? (charm? >e) (dup2 >e <e)
                                    (close <e))))
              _ (each opens close)
              s (b ())
              _ (each saves (\ e (? (nom? >e) (close <e)
                                    (: _ (dup2 >e <e) (close >e)))))
              s)))

   ; --- command substitution (word.l's box) -------------------------------------
   ; an all-external pipeline spawns with the last stdout on our pipe; drain
   ; through fdopen, then reap -- any body size flows, and nothing forks.
   (sh-capsimple a wfd)                        ; -> pids, unwaited
     (: cmds (? (= <a 'pipe) (a 1) [a])
        sx (sh-stagex cmds ())
        (? (= <sx 'err) (: _ (cmderr >sx) ())
           (: sts (sx 1)
              n (#sts - 1)
              pipes (sh-makepipes n)
              pfds (sh-flat pipes)
              ofds (catmap (\ st (st 3)) sts)
              wrs (catmap (\ st (st 4)) sts)
              allclose (wfd . (pfds + (ofds + (map cap wrs))))
              pids (sh-spawnst sts pipes allclose wfd 0 n (0 - 1) 0 ())
              _ (each (pfds + ofds) close)
              _ (sh-hwrite wrs)
              pids)))
   (sh-capst sts)                              ; the last stage's status, a signal folded down
     (? !(two? sts) 1
        (: st (last sts) (? (charm? st && (255 < st)) (st - 128) st)))
   ; --- which lane takes this body ----------------------------------------------
   ; three, and one look picks: the peel and the name are the same question for
   ; all of them, so sh-lane asks once and answers a nom.
   ;  'jug -- a no-effect builtin, so love says the whole of it: a jug takes it
   ;          with no pipe, no fd, no child. a jug is not an FD, and that is the
   ;          boundary -- it holds what `out` is told and nothing a process writes,
   ;          so a body that could spawn (a function, anything with a body) is out.
   ;  'ext -- every stage a plain external: sh-capsimple already spawns those
   ;          straight onto the pipe, forkless, and nothing needs putting back.
   ;  'sub -- everything else, in-process down a pipe a task drains (sh-capsub).
   ; the test is syntax, asked before a single word expands (an expansion runs
   ; $( ) of its own, so it may happen once and only once) -- hence the bare
   ; literal: no ~, no glob, so the name is already its own text. an unreadable
   ; name is 'sub, the lane that holds anything.
   sh-purebi '("pwd" ":" "true" "false")
   (sh-barelit w)                              ; a word that is already its own text, or ()
     (? (!(two? w) || two? >w) ()
        (: h <w
           (? !(= <h 'lit) ()
              (: t >h
                 (? (!#t || ((t 0) = 126) || sh-anyglob t) () t)))))
   (sh-cmdname a)                              ; a 'cmd's bare name, or () if it has none to read
     (: pk (sh-peel (a 1) ())
        (? (two? <pk) ()                       ; assignments want a subshell
           !(two? >pk) ()
           (sh-barelit <>pk)))
   (sh-extcmd? c)                              ; a stage sh-stagex would spawn as it stands
     (? !(= <c 'cmd) ()
        (: nm (sh-cmdname c) (? !nm () (&& !(sh-bi? nm) !(sh-fn? nm)))))
   (sh-lane a)
     (? (= <a 'pipe) (? (all sh-extcmd? (a 1)) 'ext 'sub)
        !(= <a 'cmd) 'sub
        (: nm (sh-cmdname a)
           (? !nm 'sub
              (sh-fn? nm) 'sub
              !(sh-bi? nm) 'ext
              (&& !(two? (a 2)) (sh-smem? nm sh-purebi)) 'jug   ; a redirect wants an fd
              'sub)))
   ; re-seat STDOUT alone -- `wear` replaces the whole triple, so an in or err this
   ; task already wears has to ride along by name
   (sh-wearout o)
     (: w (worn ())
        (wear [(? (two? w) <w ())
                 o
                 (? (&& (two? w) (two? >w) (two? >>w)) <>>w ())]))
   (sh-capstat st)                             ; a plan's answer read as a $( ) status
     (? (charm? st) st
        ((two? st) && ((= <st 'ret) || (= <st 'xit))) >st
        0)
   ; the re-seat is minded: a scare under the body leaves this task wearing a jug
   ; nobody drains, and every later word the shell says lands in it instead of the
   ; terminal. one capture pays the mind, not one node -- sh-guarded stays bare.
   (sh-capjug a)
     (: j (jug 0)
        w (worn ())
        _ (sh-wearout j)
        st (mind (\ _ (sh-guarded (\ _ (sh-eval a))))   ; the body's status is the value,
                 () (\ _ (wear w)))                     ; ..never our errexit
        _ (pin sh-substat () (sh-capstat st))
        (slurp j))

   ; --- the forkless capture: the body runs here, down a pipe a task drains -----
   ; a child process needs an FD, so this lane is a real pipe with our own stdout
   ; dup2'd onto it -- and the drainer is what makes that safe. a pipe holds one
   ; buffer and the only reader is the shell, which is busy running the body, so a
   ; body that says more than that would stop forever. a task parks on the read end
   ; and empties it as the body fills it; the two never both stop, because every
   ; wait in this tree parks its task and not the process (tools/waits.l).
   ; POSIX runs $( ) in a subshell, and forkless there is nobody to copy the
   ; state -- sh-subsave/sh-subback do it by hand, and that roster is the contract:
   ; cwd, variables, functions, positionals, $0, the e/u/x flags, the environment.
   ; what a fork would also have taken and this does not: a job started here stays
   ; the shell's, an fd opened here stays open, umask and the handlers stand.
   ; a background child inside holds the write end, so the drain sees no eof
   ; until it dies -- the wait `$(sleep 5 &)` has in every shell, and the same one.
   ; and a fork under one of these bodies takes the drainer by copy, so the
   ; child would read its parent's capture: shut every inherited one down before
   ; the child runs a step -- close the read end, then join the task, which now
   ; reads the end at once. closing without joining leaves the fd number free for
   ; the body to reopen, and the drainer would wake onto whatever landed there.
   (sh-dropcaps _)
     (: _ (each (sh-subfds ()) (\ e (: _ (close <e) _ (catch >e) 0)))
        _ (pin sh-subfds () ())
        ; and no trap of its parent's: POSIX resets a caught condition in a
        ; subshell, and a `( exit )` that ran the exit action would take the
        ; parent's temp dir out from under it while the parent was still working.
        ; sh-disarm drops the parent's signalfd and empties the mask with it --
        ; a subshell that inherited the block would be a subshell ^C cannot reach.
        _ (each (keys sh-traps) (\ k (pull sh-traps k 0)))
        _ (sh-disarm 0)
        0)
   (sh-tabsnap t) (map (\ k (k . (t k))) (keys t))
   (sh-tabback t sn)
     (: _ (each (keys t) (\ k (pull t k 0)))
        _ (each sn (\ e (pin t <e >e)))
        0)
   (sh-envback old)                            ; unset what appeared, then re-lay the old
     (: now (environ 0)
        (? (now = old) 0
           (: _ (each now (\ e (? (sh-smem? e old) 0
                                  (: p (sh-eqpos e 0)
                                     (setenv (? !p e (snip e 0 p)) ())))))
              _ (each old (\ e (: p (sh-eqpos e 0)
                                  (? !p 0
                                     (setenv (snip e 0 p) (snip e (p + 1) #e))))))
              0)))
   (sh-subsave _)
     [(cwd 0) (sh-tabsnap sh-vars) (sh-tabsnap sh-funcs) (sh-pos ()) (sh-arg0 ())
        [(sh-eflag ()) (sh-uflag ()) (sh-xflag ())] (environ 0)]
   (sh-subback s)
     (: _ (chdir (s 0))
        _ (sh-tabback sh-vars (s 1))
        _ (sh-tabback sh-funcs (s 2))
        _ (pin sh-pos () (s 3))
        _ (pin sh-arg0 () (s 4))
        f (s 5)
        _ (pin sh-eflag () (f 0))
        _ (pin sh-uflag () (f 1))
        _ (pin sh-xflag () (f 2))
        _ (sh-envback (s 6))
        0)

   ; --- one line, run the way a subshell would: the door a caller in this image
   ; uses instead of spawning a shell (cook's recipe lines). a make recipe line
   ; runs in its own shell, so a `cd` in one must not reach the next -- this is the
   ; forkless capture's contract with the capture taken off: the body says its piece
   ; straight onto our fds, and sh-subsave/sh-subback put back by hand what a fork
   ; would have copied (cwd, variables, functions, positionals, $0, the e/u/x flags,
   ; the environment). the same holes stand: a job started inside stays ours, an
   ; fd opened inside stays open, umask and the handlers hold. `exit` ends the line.
   ; answers (1 status) when it ran here, () when the flags ask for something this
   ; door does not serve -- the caller then spawns a shell, exactly as it always did.
   ; the restore rides `mind`, so a scare under the line still puts the shell back.
   (sh-oneflags fl)                            ; ("-ec") -> (1 e u x) | () not ours
     (: (go l e u x)
         (? !(two? l) [1 e u x]
            (: w <l n #w
               (? (|| (n < 2) !((w 0) = 45)) ()
                  (: (ch k e2 u2 x2)
                      (? (n <= k) (go >l e2 u2 x2)
                         (: c (w k)
                            (? (c = 99) (ch (k + 1) e2 u2 x2)      ; c, the command marker
                               (c = 101) (ch (k + 1) 1 u2 x2)
                               (c = 117) (ch (k + 1) e2 1 x2)
                               (c = 120) (ch (k + 1) e2 u2 1)
                               ())))                              ; anything else is not ours
                     (ch 1 e u x)))))
        (go fl 0 0 0))
   (sh-oneline fl src)
     (: fs (sh-oneflags fl)
        (? !(two? fs) ()
           (: sv (sh-subsave ())
              _ (pin sh-online () (1 + (sh-online ())))
              _ (pin sh-eflag () (fs 1))
              _ (pin sh-uflag () (fs 2))
              _ (pin sh-xflag () (fs 3))
              ; the body under both: mind puts the shell back either way (the restore
              ; is the resource's, not the catcher's), trap turns sh-leave's scare
              ; into the line's status. any other condition is a real fault -- say it
              ; and let the line fail, so a caller aborts loudly rather than silently.
              r (trap (\ _ (mind (\ _ (sh-line src)) ()
                                 (\ _ (: _ (pin sh-online () ((sh-online ()) - 1))
                                         _ (flush out) _ (flush err)
                                         (sh-subback sv)))))
                      ()
                      (\ a b (? (= a 'sh-exit) (? (charm? b) b 1)
                                (: _ (say err ";; ") _ (print err a) _ (say err " ")
                                   _ (print err b) _ (put err 10) _ (flush err) 1))))
              [1 (? (two? r) (? (= <r 'more)
                                   (: _ (say err "lush: unexpected eof in a recipe line")
                                      _ (put err 10) 2)
                                   (? (charm? >r) >r 1))
                      (charm? r) r
                      0)])))
   (sh-capsub a)
     (: pp (pipe 0)
        (? (nom? pp) (: _ (cmderr "cannot pipe") "")
           (: rfd <pp wfd >pp
              d (twirl (\ _ (: p (fdopen rfd) t (slurp p) _ (close p) t)) 0)
              _ (flush out)                    ; the bytes already in hand are the caller's
              sv (dup 1)
              _ (dup2 wfd 1)
              caps (sh-subfds ())
              _ (pin sh-subfds () ((rfd . d) . caps))
              snap (sh-subsave ())
              ; the whole seat is minded: nothing here is reclaimed by anything else.
              ; sv and wfd are raw fds -- no port owns them, so our own close is the
              ; only reclaim -- our stdout is dup2'd onto the pipe, and the
              ; drain has no other reader. a scare under the body left the shell talking
              ; into a pipe nobody empties, which at the next prompt reads as a dead shell.
              ; the join lands in `got` because it belongs to the teardown: a second catch
              ; answers the zero point, so it can happen in one place, and that place has
              ; to be the one both ways out share.
              got (tablet 0)
              st (mind (\ _ (sh-guarded (\ _ (sh-eval a)))) ()
                       (\ _ (: _ (flush out)         ; the body's bytes, before the ends go
                                _ (sh-subback snap)
                                _ (pin sh-subfds () caps)
                                ; fd 1 is a write end too (the dup2 above), so it has to be
                                ; put back before the drain can ever read eof
                                _ (dup2 sv 1) _ (close sv)
                                _ (close wfd)      ; the last write end: now eof
                                _ (pin got 0 (catch d))
                                0)))
              _ (pin sh-substat () (sh-capstat st))
              (got 0))))

   ; every lane leaves sh-substat holding this body's status: an assignment with
   ; no command name answers the last one performed (POSIX), so the pin is the
   ; only way back -- sh-fields sits between here and the reader. 1 up front is
   ; the floor the three scaring lanes keep.
   (sh-cmdsub text)
     (: _ (pin sh-substat () 1)
        lx (sh-lex text)
        (? (= <lx 'more) (: _ (cmderr "unterminated $( ) body") "")
           (: pr (sh-parse >lx)
              (? !(= <pr 'ok) (: _ (cmderr "bad $( ) body") "")
                 !>pr (: _ (pin sh-substat () 0) "")           ; $( ) is a clean nothing
                 (: a >pr ln (sh-lane a)
                    (? (= ln 'jug) (sh-capjug a)
                       (= ln 'sub) (sh-capsub a)
                       (: pp (pipe 0)
                          (? (nom? pp) ""
                             (: rfd <pp wfd >pp
                                ; guarded: the body's status is this
                                ; substitution's value, never the shell's own
                                ; errexit trigger -- aborting it would drop the
                                ; very output the caller asked for.
                                (sh-guarded
                                  (\ _ (: pids (sh-capsimple a wfd)
                                          _ (close wfd)
                                          o (slurp (fdopen rfd))   ; drain, then reap
                                          _ (pin sh-substat ()
                                               (sh-capst (map (\ p (wait p)) pids)))
                                          o))))))))))))
   _ (pin sh-subeval () sh-cmdsub)

   ; --- the script lane + the line entries --------------------------------------
   (sh-lines port buf)
     (: line (sh-getline port)
        (? (= line 'eof)
           (? #buf
              (: _ (say err "lush: unexpected eof\n") _ (pin sh-status () 2) 0)
              0)
           (: full (? #buf (buf + ("\n" + line)) line)
              r (sh-line full)
              ; a signal that arrived while no child was up has nobody to end its
              ; wait, so the line boundary is the other place it is read
              _ (sh-sigdrain 0)
              (? (two? r) (sh-lines port full)
                 (sh-retf ()) (: _ (pin sh-retf () 0) 0)   ; dot-return: stop this file
                 (sh-lines port "")))))
   (sh-parse-line src)
     (: lx (sh-lex src)
        (? (= <lx 'more) lx (sh-parse >lx)))
   (sh-eval-top src a)
     (: _ (pin sh-curline () src)
        s (sh-eval a)
        (? (charm? s) s
           ; a `return` that reached the top: flag it so the reading loop stops
           ; its file (POSIX dot-return; sh-lines clears the flag) -- $? is the
           ; return's own. a stray brk/cnt still swallows.
           (two? s && (= <s 'ret))
             (: _ (pin sh-retf () 1) _ (pin sh-status () >s) >s)
           0))
   (sh-line src)
     (: pr (sh-parse-line src)
        (? (= <pr 'more) pr
           (= <pr 'err)
             (: _ (say err ("lush: " + (>pr + "\n"))) _ (pin sh-status () 2) 2)
           (sh-eval-top src >pr))))
) ; module 'lush

; --- lush 🐚 the line -- prompt, history, completion, the repl loops ---
; no brackets here: the runtime supplies the layer (see job.l for the cat law).
;
; line editing on a real tty is bao's editor -- `edlnc`, edln + Tab completion:
; sh-complete takes the text left of the cursor, finds the word under it, and
; answers (insert . candidates) -- commands (builtins + a PATH readdir scan)
; in command position, pathnames (the glob walk, ~ unfolded and refolded)
; everywhere else; one candidate also lands its "/" or " ". the prompt is the
; grml feel: last status when nonzero, cwd with ~ shrunk, the git branch when
; a .git sits on the walk up, then $ (or # for root). history persists:
; ~/.lush_history is append-on-Enter (a crash loses nothing) and the last 100
; lines seed edln's recall at birth. the raw/cooked dance and the "> " (PS2)
; continuation ride as before; lush-help is the interactive floor -- a scare
; drops to cooked, prints ;; a b, welps to the zero point, and the loop
; re-prompts: a crash never eats the terminal (installed in (sh _), main.l).

(module 'lush
(: ; --- the floor: bao's shell-help shape, cooked first so the print lands clean
   (lush-help a b)
     (: _ (raw 0) _ (puts ";; ") _ (putx a) _ (puts " ") _ (putx b) _ (putc 10)
        (welp a b))

   ; --- the prompt --------------------------------------------------------------
   (sh-rfind s b)
     (: (go k) (? (k < 0) (0 - 1) (? ((s k) = b) k (go (k - 1))))
        (go (#s - 1)))
   (sh-homely d)                                ; /home/me/x -> ~/x
     (: h ("" + (getenv "HOME")) hn #h
        (? (&& hn (hn <= #d) (h = (snip d 0 hn)))
           ("~" + (snip d hn #d))
           d))
   (sh-gitup d)                                 ; a .git anywhere up the walk?
     (? (two? (stat (d + "/.git"))) 1
        (: k (sh-rfind d 47)
           (? (k < 1) 0 (sh-gitup (snip d 0 k)))))
   (sh-gitbr _)
     (? (sh-gitup ("" + (cwd 0)))
        (: r (hark ["git" "symbolic-ref" "--short" "-q" "HEAD"])
           (? (0 = <r) (sh-chomp >r) ""))
        "")
   (sh-prompt _)
     (: st (sh-status ())
        br (sh-gitbr 0)
        (+ (? (st = 0) "" ((show st) + " "))
           (+ (sh-homely ("" + (cwd 0)))
              (+ (? #br (" (" + (br + ")")) "")
                 (? (0 = (getuid 0)) " # " " $ ")))))

   ; --- history: ~/.lush_history, oldest first on disk, newest first in hand
   (sh-expl s)                                  ; string -> charlist
     (: n #s
        (go i) (? (i = n) () (s i . go (i + 1)))
        (go 0))
   (sh-histpath _) (("" + (getenv "HOME")) + "/.lush_history")
   (sh-histload _)
     (: p (sh-histpath 0)
        (? (two? (stat p))
           (: prt (open p "r")
              (go acc)
                (: ln (sh-getline prt)
                   (? (= ln 'eof) acc
                      #ln (go (sh-expl ln . acc))
                      (go acc)))
              r (go ())
              _ (close prt)
              (take 100 r))
           ()))
   (sh-histput ln)
     (: o (open (sh-histpath 0) "a")
        (? (hot? o) (: _ (say o (ln + "\n")) _ (flush o) (close o)) 0))

   ; --- completion: (insert . candidates) off the text left of the cursor ------
   sh-builtins '("cd" "exit" "export" "pwd" "jobs" "fg" "bg")
   (sh-prefix? p s) (: n #p ((n <= #s) && (p = (snip s 0 n))))
   (sh-comm2 a s)                               ; longest common prefix of two
     (: n (? (#a < #s) #a #s)
        (go i) (? ((i < n) && ((a i) = (s i))) (go (i + 1)) i)
        (snip a 0 (go 0)))
   (sh-common l) (? !(two? l) "" (foldl sh-comm2 <l >l))
   (sh-uniq l)
     (? !(two? l) l
        (? (two? >l && (<l = <>l)) (sh-uniq >l)
           (<l . sh-uniq >l)))
   (sh-pathdirs s)                              ; "a:b:c" -> ("a" "b" "c")
     (: n #s
        (go i st acc) (? (i = n) (sh-rev (snip s st i . acc))
                         (? ((s i) = 58) (go (i + 1) (i + 1) (snip s st i . acc))
                            (go (i + 1) st acc)))
        (go 0 0 ()))
   (sh-verbnames _) (map string (keys (from 'verbs 'tab)))
   (sh-cmds w)                                  ; command candidates for prefix w
     (sh-uniq (sort (+ (filter (sh-prefix? w) sh-builtins)
                       ; autonomous mode: our verbs are commands whatever PATH holds
                       (+ (? (sh-greg? 0) () (filter (sh-prefix? w) (sh-verbnames 0)))
                          (catmap (\ d (filter (sh-prefix? w) (readdir d)))
                                  (sh-pathdirs ("" + (getenv "PATH"))))))))
   (sh-dirp q) (: st (stat q) (two? st && (16384 = (61440 & (st 2)))))
   (sh-unfold w)                                ; ~/x -> $HOME/x (stat wants the real path)
     (? (tally w && ((w 0) = 126)) (("" + (getenv "HOME")) + (snip w 1 #w)) w)
   (sh-fileca w)                                ; pathname candidates: glob w*, ~ refolded
     (: h ("" + (getenv "HOME"))
        w2 (sh-unfold w)
        g (sh-glob (w2 + "*") (sh-ones (#w2 + 1)))
        (? (w = w2) g
           (map (\ p ("~" + (snip p #h #p))) g)))
   (sh-wdst s)                                  ; where the word under the cursor starts
     (: (go k) (? (k < 0) 0
                  (: b (s k)
                     (? (|| (b = 32) (b = 9) (b = 124) (b = 38) (b = 59) (b = 60) (b = 62))
                        (k + 1) (go (k - 1)))))
        (go (#s - 1)))
   (sh-cmdpos? s st)                            ; only spaces / a separator before it?
     (: (go k) (? (k < 0) 1
                  (: b (s k)
                     (? ((b = 32) || (b = 9)) (go (k - 1))
                        (|| (b = 124) (b = 38) (b = 59)) 1
                        0)))
        (go (st - 1)))
   (sh-complete left)
     (: s (slurp (tap left))
        st (sh-wdst s)
        w (snip s st #s)
        (? !#w (() . ())
           (: cmdp (&& (sh-cmdpos? s st) ((sh-rfind w 47) < 0) !((w 0) = 126))
              cands (? cmdp (sh-cmds w) (sh-fileca w))
              (? !(two? cands) (() . ())
                 (: com (sh-common cands)
                    ins (? (sh-prefix? w com) (snip com #w #com) "")
                    one !(two? >cands)
                    sfx (? !one ""
                           (? (!cmdp && sh-dirp (sh-unfold <cands)) "/" " "))
                    (sh-expl (ins + sfx) . cands))))))

   ; --- the loops ---------------------------------------------------------------
   (sh-cooked buf)
     (: _ (? #buf 0 (sh-reapbg 0))
        _ (say out (? #buf "> " ((cwd 0) + "$ ")))  _ (flush out)
        line (sh-getline in)
        (? (= line 'eof)
           (: _ (? #buf (say err "lush: unexpected eof\n") 0) (puts "\n"))
           (: full (? #buf (buf + ("\n" + line)) line)
              pr (sh-parse-line full)
              (? (= <pr 'more) (sh-cooked full)
                 (= <pr 'err)
                   (: _ (say err ("lush: " + (>pr + "\n")))
                      _ (pin sh-status () 2) (sh-cooked ""))
                 (: _ (sh-eval-top full >pr) (sh-cooked ""))))))
   ; interactive: edlnc owns echo, so raw the tty for the prompt and drop to
   ; cooked around each command. edlnc answers (line . nhist) or 'eof; nhist
   ; threads back so up/down recall, and the file gets each line as it lands.
   (sh-loop buf hist)
     (: _ (? #buf 0 (sh-reapbg 0))
        r (edlnc in (? #buf "> " (sh-prompt 0)) hist sh-complete)
        (? (= r 'eof) (: _ (raw 0) (puts "\n"))                 ; cooked, newline, end
           (: line (slurp (tap <r)) nhist >r
              _ (? #line (sh-histput line) 0)
              full (? #buf (buf + ("\n" + line)) line)
              pr (sh-parse-line full)
              (? (= <pr 'more) (sh-loop full nhist)
                 (= <pr 'err)
                   (: _ (raw 0)
                      _ (say err ("lush: " + (>pr + "\n")))
                      _ (pin sh-status () 2)
                      _ (raw 1) (sh-loop "" nhist))
                 (: _ (raw 0)                                     ; cooked for the command
                    _ (sh-eval-top full >pr)
                    _ (raw 1) (sh-loop "" nhist)))))))              ; re-raw for the next prompt
) ; module 'lush

; --- lush 🐚 -- the love shell ---
; a cowrie who lives on the quay among lux and the rest of the pulchritude:
; a real (Unix) command shell in love. reads a line, runs real programs via
; spawn + wait -- inherited stdio, so output is live and the command owns the
; terminal (not captured like `run`). this is also the shell init execs on the
; distro console (the Makefile cats the parts to /lib/sh.l): the pid1 story
; end to end (init -> lush -> real programs). it rides the host/posix.c
; job-control nifs (spawn/spawnmap/wait/chdir/cwd) + getenv, fdopen for its
; own pipe ends, and bao's edln for the line.
;
; the parts, in cat order: job.l (state + job control), lex.l (tokens),
; gram.l (the AST), glob.l (fnmatch + pathnames), word.l (expansion),
; eval.l (the engine), line.l (the repl loops), main.l (this file: the entry
; + the seat). run it:
;   out/lush                    ; interactive (or cooked when stdin is a pipe)
;   out/lush -c "echo hi"       ; one command (multi-line strings fine)
;   out/lush -g ..              ; gregarious: a verb word is ours only when PATH says so
;   out/lush -a ..              ; autonomous, the default: our verbs run here whatever PATH holds
;   out/lush script.sh          ; a script file, continuations gathered
;   out/lush --login ..         ; a login shell: /etc/profile + ~/.profile first
;   out/love -l apps/lush/lush.l ..   ; the module road to the same seat
; the gate: test/host/sh.l reads the parts bare (cat order) and asserts on the
; sh-* names; the interactive loop is probed live under script(1).

(module 'lush
(: ; source a file through the line machinery, quietly absent (the rc/profile floor)
   (sh-src path)
     (? (two? (stat path))
        (: p (open path "r") _ (sh-lines p "") _ (close p) 0)
        0)
   ; a login shell (--login, or a dash-led seat name) reads /etc/profile then
   ; ~/.profile, whatever mode it runs in; interactive shells layer $ENV (else
   ; ~/.lushrc) on top, in (sh _) below. the chsh story lives in doc/lush.md.
   (sh-profiles _)
     (: _ (sh-armtrap 0)
        (? (sh-login ())
           (: _ (sh-src "/etc/profile") (sh-src (("" + (getenv "HOME")) + "/.profile")))
           0))
   ; job.l's exit door runs the exit action, and it is one file too early to know
   ; what a shell line is -- the same distance word.l keeps from sh-cmdsub, and
   ; the same box answer. but not the same pin. sh-subeval takes the bare name
   ; sh-cmdsub because eval.l can read it where it stands; sh-line it cannot, since
   ; reading a name builds it and sh-line and sh-eval-top call each other. here the
   ; name is an ordinary export of a module already loaded, and reads like one.
   (sh-armtrap _) (pin sh-runtrap () (\ src (sh-line src)))
   ; the script lane rides eval.l's sh-lines ('more gathers continuations,
   ; `exit` quits from inside); $0 and the positionals land before the run
   (sh-file path args)
     (? (two? (stat path))
        (: _ (pin sh-arg0 () path)
           _ (pin sh-pos () args)
           _ (sh-profiles 0)
           p (open path "r") _ (sh-lines p "") _ (close p)
           _ (sh-fire-exit 0) (quit (sh-status ())))
        (: _ (say err (("lush: " + path) + ": not found\n")) (quit 127)))
   (sh-c cmd rest)                              ; -c CMD [name [args..]], POSIX
     (: _ (pin sh-arg0 () (? (two? rest) <rest "lush"))
        _ (pin sh-pos () (? (two? rest) >rest ()))
        _ (sh-profiles 0)
        r (sh-line cmd)
        _ (? (two? r) (: _ (say err "lush: unexpected eof\n") (pin sh-status () 2)) 0)
        _ (sh-fire-exit 0) (quit (sh-status ())))
   ; the flag word: a c e g u x, bundled or apart. `sh -ec CMD` is what a Makefile's
   ; .SHELLFLAGS writes and what every shell takes, so a bundle is not a courtesy --
   ; without it lush cannot be the SHELL of a make. answers (1 c? rest) with e/u/x
   ; already pinned, or () when a letter is not ours (then the word is not a flag).
   (sh-flagw a rest)
     (: n #a
        (go k c?) (? (n <= k) [1 c? rest]
                     (: ch (a k)
                        (? (ch = 99) (go (k + 1) 1)
                           (ch = 97) (: _ (pin sh-gflag () 0) (go (k + 1) c?))    ; -a autonomous
                           (ch = 103) (: _ (pin sh-gflag () 1) (go (k + 1) c?))   ; -g gregarious
                           (ch = 101) (: _ (pin sh-eflag () 1) (go (k + 1) c?))
                           (ch = 117) (: _ (pin sh-uflag () 1) (go (k + 1) c?))
                           (ch = 120) (: _ (pin sh-xflag () 1) (go (k + 1) c?))
                           ())))
        (go 1 0))
   (sh-main args)
     (: _ (sh-snapign 0)                        ; first: what our caller had turned off
        _ (pin sh-gflag () (sh-envflag 0))      ; the mode: LUSHFLAGS' now, a flag word's below
        _ (sh-forget 0)                         ; a forked shell drops its parent's word verdicts
        (sh-args args))
   (sh-args args)                              ; the argv walk, once the seat is set up
     (? !args (sh 0)
        (: a <args
           (? (a = "--login") (: _ (pin sh-login () 1) (sh-args >args))
              ((1 < #a) && ((a 0) = 45))
                (: fw (sh-flagw a >args)
                   (? !(two? fw) (sh-file a >args)          ; a letter not ours: a name
                      (fw 1)
                        (: r (fw 2)
                           (? r (sh-c <r >r)
                              (: _ (say err "lush: -c needs a command\n") (quit 2))))
                      (sh-args (fw 2))))            ; flags only: read on
              (sh-file a >args))))
   ; the interactive entry: ignore the tty's job signals (children reset them),
   ; then probe with (raw 1): () = a tty (interactive), an errno = not a tty
   ; (the cooked fallback). interactively: hear lush-help as the floor if no
   ; help is heard yet (the bao door), source the profiles (login only) then
   ; $ENV else ~/.lushrc cooked -- after the floor lands, so a broken rc scares
   ; back to the prompt instead of killing the shell -- and seed the recall from
   ; ~/.lush_history. ^D / `exit` ends the shell.
   (sh _) (: _ (signal sig-int 1) _ (signal sig-quit 1) _ (signal sig-tstp 1)
             _ (signal sig-ttou 1) _ (signal sig-ttin 1)
             ok (raw 1)
             (? !ok
                (: _ (? !(heard ()) (hear lush-help))
                   _ (pin sh-tty () 1)
                   erc ("" + (getenv "ENV"))
                   rc (? #erc erc (("" + (getenv "HOME")) + "/.lushrc"))
                   _ (raw 0) _ (sh-profiles 0) _ (sh-src rc) _ (raw 1)
                   (sh-loop "" (sh-histload 0)))
                (: _ (sh-profiles 0) (sh-cooked "")))))

; --- the seat (kiosko's): fire only when this file is the program -- the catted
; bin (`lush ..`), an sh-named symlink to it, or a -l load of the assembly.
; `cmdline` is the raw C argv and is never rebound, so the read is
; order-independent inside any cat; apps/init/boot.l's `-l /lib/sh.l -e "(sh 0)"`
; lane stays quiet here ("sh.l" is deliberately NOT a me? name) and fires
; through its -e instead.
; a dash-led basename (-lush, -sh: login(1)'s mark) seats us too and makes a login
; shell -- the scan strips the dash to match and hands the raw word back, which is
; the whole reason it hands one back. (the env -S shebang usually eats the dash, so
; --login is the reliable door, doc/lush.md.)
(: _ (pins (from 'verbs 'tab) 'sh sh-main 'lush sh-main)
   (bn p) (: n #p
             (go k r) (? (k < n) (go (k + 1) (? (p k = 47) (k + 1) r)) (snip p r n))
             (go 0 0))
   s ((from 'verbs 'fire) ["lush" "lush.l" "sh"])
   (? (two? s) (: w (bn <s)
                  _ (? (tally w && (w 0 = 45)) (pin sh-login () 1) 0)
                  (sh-main >s))
      ()))
) ; module 'lush
