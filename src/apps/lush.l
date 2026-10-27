; lush 🐚, assembled: the shell state + job control, the lexer, the grammar, the
; glob, the word expander, the engine, the repl loops, then the entry + seat --
; each part a (module 'lush form in cat order, so a later part reads an earlier
; one. no brackets in any of them: the runtime supplies the layer.

; --- lush 🐚 job control -- the shell state + the jobs ---
; the shell ignores the tty's job signals, so ^C/^Z reach only the foreground. a stop
; comes back from `wait` as 256+sig and parks in sh-jobs: n -> (pids state cmd).
; signal numbers are linux's.

(module 'lush
(borrow 'hashes)
; posix doors taken by value: lush's entries run from a foreign chain, where a global
; name reads the live book. spawn, wait, fork, pipe, dup .. stay global: inle shadows them.
(: chdir (cite 'posix 'chdir)      chmod (cite 'posix 'chmod)
   close (cite 'posix 'close)      cwd (cite 'posix 'cwd)
   mkdir (cite 'posix 'mkdir)      open (cite 'posix 'open)
   openfd (cite 'posix 'openfd)    readdir (cite 'posix 'readdir)
   readlink (cite 'posix 'readlink) rmdir (cite 'posix 'rmdir)
   selfpath (cite 'posix 'selfpath) stat (cite 'posix 'stat)
   sigclear (cite 'posix 'sigclear) sigfd (cite 'posix 'sigfd)
   childign (cite 'posix 'childign)
   umask (cite 'posix 'umask)     rusage (cite 'posix 'rusage)
   rlimit (cite 'posix 'rlimit)   setrlimit (cite 'posix 'setrlimit)
   sigign? (cite 'posix 'sigign?)  sigtake (cite 'posix 'sigtake)

   sig-int 2 sig-quit 3 sig-tstp 20 sig-cont 18 sig-ttou 22 sig-ttin 21
   ; the state of one shell: every cell an instance owns, made fresh, and copied whole for a
   ; subshell -- threaded through, never global, so shells and their subshells part
   (sh-new _)
    {'sh-jobs (tablet 0)
     'sh-njob 0
     'sh-tty 0                                   ; 1 = interactive: jobs get their own pgrp + the tty
     'sh-inread 0                                ; 1 = the shell has read its own stdin, so a buffer may hold read-ahead
     'sh-login 0                                 ; 1 = a login shell (--login, or a -argv0 seat): profiles read
     'sh-jc 1
     'sh-status 0                                ; $?: the last foreground status
     'sh-substat 0                               ; the last $( )'s status -- state, not an answer, because
                                                 ; expansion sits between sh-cmdsub and the reader
     'sh-curline 0                               ; the source line under eval (job display)
     'sh-vars {}                                 ; shell variables (name -> value; export promotes)
     'sh-rovars {}                               ; the readonly names
     'sh-aliases {}                              ; alias name -> its text
     'sh-hashc {}                                ; word -> (PATH . the path it won), hash's memory
     'sh-forkc {}                                ; word -> 1 | 0, decided once per PATH
     'sh-verdpath {}                             ; the PATH the word verdicts were taken under
     'sh-funcs {}                                ; functions (name -> the PLANNED body)
     'sh-traps {}
     'sh-trapped 0
     'sh-sigport 0                               ; the signalfd port, or 0
     'sh-igno 0
     'sh-pos 0                                   ; the positionals, a list of strings
     'sh-arg0 0                                  ; $0 (the script path, or the shell)
     'sh-eflag 0 'sh-uflag 0 'sh-xflag 0         ; set -e / -u / -x
                                                 ; sh-mflag, absent until sh-main pins it: the mode, 0 autonomous,
                                                 ; 1 gregarious, 2 precarious
     'sh-lastbg 0                                ; $!: the last background pid
     'sh-noe 0                                   ; errexit guard depth (conds, && || arms): state, not a
                                                 ; plan parameter, which would have to cross word expansion
     'sh-subfds 0                                ; the forkless $( ) captures we are inside, innermost first,
                                                 ; each (read-end . drainer); a fork drops them (sh-dropcaps)
     'sh-online 0                                ; nesting depth of sh-oneline: a line run here for a
                                                 ; caller in this image, so `exit` ends the line not us
     'sh-subrds 'no                              ; inside a forkless subshell, the fds its bare `exec` laid,
                                                 ; each (fd . the saved dup), put back when it ends; else 'no
     'sh-retf 0                                  ; a top-level `return` landed: sh-lines stops its file (dot-return)
                                                 ; arerr, absent or 1: a said complaint, so the top stays quiet
                                                 ; arlive, absent or 1, but 0 inside a branch && || ?: did not take
     'sh-optind 1                                ; getopts: where the last call left off
     'sh-optk 0                                  ; ..and how far into a clustered word
     'sh-imgc {}}                                ; word -> (1 fn whole?) | 0, decided once
   (sh-tdup t) (foldl (\ u k (pin u k (peep t k ()))) {} (keys t))
   (sh-copy S) (sh-tdup S @ c (each (keys c) (k \ (? (tablet? (c k)) (pin c k (sh-tdup (c k))) 0)), c))
   ; job control does not nest: a forked child running shell code clears sh-jc, so the
   ; shell above sees one job. kept apart from sh-tty, which a subshell does not change.
   (sh-jc? S _) (? (S 'sh-tty) (S 'sh-jc) 0)
   ; interactive spawns lead a fresh pgrp (0) and take the terminal (fg 1): a stop to an
   ; orphaned group is discarded. otherwise the shell's own pgrp (-1).
   (sh-pgm S _) (sh-jc? S 0 ? 0 -1)
   (sh-fgm S _) (sh-jc? S 0 ? 1 0)
   (sh-tclear t) (each (keys t) (k \ pull t k 0))
   ; --- trap: sh-traps holds condition -> action text. sh-runtrap is the evaluator,
   ; pinned once the engine exists; sh-trapped keeps an `exit` in the exit action from
   ; running it twice
   sh-runtrap {0}
   ; --- signals: sigfd blocks the trapped ones and queues them to an fd, armed only
   ; while a signal trap exists; drained after each foreground command, as POSIX says
   sh-signums (cite 'kore 'usignames)          ; kore's table: one spelling of the signals
   (sh-signum nm)
    ((: (g l) (l @- 0 (e . u) (<e = nm ? <>e (g u)))) sh-signums)
   (sh-signame n)
    ((: (g l) (two? l ?  (: e <l (<>e = n ? <e (g >l)))))
     sh-signums)
   ; every trapped condition that is a signal -- exit leaves by its own door
   (sh-sigconds S _) (filter (!= "EXIT") (keys (S 'sh-traps)))
   ; the ones trapped with '': ignored, and kept so in a subshell and what the shell starts
   (sh-igntraps S _) (filter (c \ 0 = #(peep (S 'sh-traps) c "")) (sh-sigconds S 0))
   (sh-ignsigs S _) (filter (!= 0) (map sh-signum (sh-igntraps S 0)))
   ; a signal ignored on entry cannot be trapped (POSIX). snapshot before the
   ; interactive entry sets ignores of its own
   (sh-snapign S _)
    (pin S 'sh-igno (filter (nm \ sh-signum nm @ n (n && sigign? n)) (map cap sh-signums)))
   (sh-ignored? S nm) ((S 'sh-igno) @ l (two? l && any (= nm) l))
   ; clear, then arm: sigfd's sigprocmask is a SIG_BLOCK and accumulates, and closing
   ; the fd does not unblock -- so empty the mask first and re-block the live set.
   (sh-rearm S _)
     (: cs (sh-sigconds S 0)
        ns (filter (!= 0) (map sh-signum cs))
        (childign (sh-ignsigs S 0),
         (S 'sh-sigport) && close (S 'sh-sigport),
         pin S 'sh-sigport 0,
         sigclear 0,
         two? ns ? (sigfd ns @ p (hot? p ? (pin S 'sh-sigport p) 0)),
         0))
   (sh-disarm S _)                               ; a forked child inherits neither
     ((S 'sh-sigport) && close (S 'sh-sigport),
      pin S 'sh-sigport 0, sigclear 0, 0)
   ; read every queued signal and run what each one traps. the action's own status
   ; does not become $? -- the command's does, exactly as at the exit door.
   (sh-fire-sig S n)
     (: nm (sh-signame n)
        a (? (string? nm) (peep (S 'sh-traps) nm "") "")
        (? #a
           (: st (S 'sh-status) _ (sh-runtrap () S a) _ (pin S 'sh-status st) 0)
           0))
   (sh-sigdrain S _) ((S 'sh-sigport) @ p
    (? !p 0 ((: (g _) (: ev (sigtake p) (atom? ev ? 0 (sh-fire-sig S <ev, g 0)))) 0)))
   ; POSIX: the exit action runs with $? as it stood and the shell still exits on
   ; that; only an explicit `exit` inside the action changes it, through sh-leave.
   (sh-fire-exit S _)
     (: a (peep (S 'sh-traps) "EXIT" "")
        (? (0 = (S 'sh-trapped) && #a)
           (: st (S 'sh-status)
              (pin S 'sh-trapped 1, (sh-runtrap ()) S a, pin S 'sh-status st, 0))
           0))
   sh-nofn (mint 0)                            ; that plan is a closure, so peep names its absence
   ; `exit`, errexit and set -u end the innermost of: a $( ) capture (a pair), an
   ; sh-oneline (a scare: set -u fires mid-expansion), else the process
   (sh-leave S st)
    (? (S 'sh-subfds) ('xit . st)
       (0 < (S 'sh-online)) (scare 'sh-exit st)
       (sh-fire-exit S 0, quit st))

   ; one line, bytes until \n; 'eof at immediate EOF
   (sh-getline port) (see port @ c (? (c < 0) 'eof (c = 10) "" (string c + sh-rest port)))
   (sh-rest port)    (see port @ c (? (c < 0) ""   (c = 10) "" (string c + sh-rest port)))

   (sh-unwords ws) (foldl (\ a w (? #a ((a + " ") + w) w)) "" ws)
   (sh-addjob S pids state cmd)
    (1 + (S 'sh-njob) @ n (pin S 'sh-njob n, pin (S 'sh-jobs) n [pids state cmd], n))
   ; wake a job: its group (a subshell's children are on no list of ours), then each
   ; known pid, for a job that leads no group. a stray cont is harmless
   (sh-cont pids) (still (0 - <pids) sig-cont, each pids (\ p (still p sig-cont)))
   (sh-jobline n j)
    ("[" + show n + "] " + show (j 1) + "  " + j 2 + "\n")
   (sh-stopped? sts) (foldl (\ a x (? a a (charm? x && 255 < x))) 0 sts)
   ; wait a foreground job; a stop registers + reports it instead of hanging the prompt
   (sh-waitfg S pids cmd)
     (: sts (map wait pids)
        _   (sh-sigdrain S 0)                            ; POSIX: after the command, not during
        _   (? (sh-jc? S 0) (ttyfg 0) 0)                 ; the shell takes the terminal back
        _   (pin S 'sh-status                          ; $?: the last stage; a stop folds to 128+sig
             (: st (last sts) (? (charm? st && 255 < st) (st - 128) (charm? st) st 127)))
        (? (sh-stopped? sts)
           (: n (sh-addjob S pids 'stopped cmd)
              _ (puts (sh-jobline n ((S 'sh-jobs) n))) 0)
           0))
   ; background bookkeeping: drain glean at each prompt; a reaped pid leaves its job,
   ; an emptied job prints done and goes
   (sh-unpid l p) (? !l () (? (<l = p) >l (<l . sh-unpid >l p)))
   (sh-bgnote S pid)
     (each (keys (S 'sh-jobs))
       (\ n (: j ((S 'sh-jobs) n)
             (? !j 0
                (: ps (sh-unpid (j 0) pid)
                   (? (ps = (j 0)) 0
                      !ps ((? (S 'sh-tty)          ; notices are the tty's; scripts stay quiet
                              (puts ("[" + ((show n) + ("] done  " + ((j 2) + "\n"))))) 0),
                           pull (S 'sh-jobs) n 0)
                      (pin (S 'sh-jobs) n [ps (j 1) (j 2)])))))))
   (sh-reapbg S _)
     (glean 0 @ r (two? r ? (sh-bgnote S <r, (sh-reapbg S) 0) 0))
   ; string membership: elem tests identity (uninterned strings never hit)
   (sh-smem? x l) (? (atom? l) 0 (x = <l ? 1 (sh-smem? x >l)))
   (sh-int s) (sh-intl s 0 0)
   (sh-intl s i a) (? (i = #s) a (sh-intl s (i + 1) ((a * 10) + ((s i) - 48))))
   (sh-lastjob S _) (foldl (a \ k \ a < k ? k a) 0 (keys (S 'sh-jobs)))
   ; a jobspec: %N, and %% or %+ the newest, %- the one before it; a bare N is N
   (sh-jobspec S w)
     (? !(0 < #w && w 0 = 37) (sh-int w)
        (: b (snip w 1 #w) l (sh-lastjob S 0)
           (? (b = "" || b = "%" || b = "+") l
              (b = "-") (foldl (a \ k \ (k < l && a < k) ? k a) 0 (keys (S 'sh-jobs)))
              (sh-int b))))
   (sh-jobn S argv) (? >argv (sh-jobspec S <>argv) (sh-lastjob S 0))
   (sh-fg S n)
     (: j ((S 'sh-jobs) n)
        (? !j (puts "fg: no such job\n", 0)
           (: pids (j 0) cmd (j 2)
              (pull (S 'sh-jobs) n 0,
               (? (sh-jc? S 0) (ttyfg <pids) 0),         ; the job's group gets the terminal first
               sh-cont pids,
               (sh-waitfg S) pids cmd))))
   (sh-bg S n)
     (: j ((S 'sh-jobs) n)
        (? !j (puts "bg: no such job\n", 0)
           (sh-cont (j 0),
            pin (S 'sh-jobs) n [(j 0) 'running (j 2)],
            puts (sh-jobline n ((S 'sh-jobs) n)),
            0))))
) ; module 'lush

; --- lush 🐚 the lexer -- one line (or a joined continuation) to tokens ---
;
; (sh-lex s) -> (1 . tokens) | ('more . why): 'more asks for another line (PS2), and the
; joined buffer is lexed again. tokens:
;   ('w . segs)        segs: ('lit . s) ('sq . s) ('dq . segs) ('var . name)
;                      ('vop . (name op text)) ('sub . text) ('ari . text) ('lov . text)
;   ('op . o)          | || & && ; ;; ( ) and "nl"
;   ('rd . (ion . o))  ion () or (n). a heredoc is op "<h", its target word the body:
;                      ('sq . body) for a quoted delimiter, else dollarized ('dq . segs)
; $0-9 take one digit (POSIX); \<newline> vanishes; "" keeps \ for $ ` " \ only.

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
   ; a (payload . j) answer is read by kind (two?), never by truth: an empty payload
   ; nets zero, so `!r` would call a finished parse unfinished and ask PS2 for a line.
   ; the scanners step over a ${( .. )} and never through one -- inside it ' is a sigil
   ; and not a quote, so a shell-quoting walk finds the closer in the wrong place.
   (sh-love3? s n i) (i + 2 < n && s i = 36 && s (i + 1) = 123 && s (i + 2) = 40)
   ; $( body ): balanced parens, blind to quoted ones -> j past ) | ()
   ; a per-byte loop: no helper closures, for the reason spelled out on `lx` below
   (sh-subp S s n i depth q pe)
     (? (i = n) ()
        pe (sh-subp S s n (i + 1) depth q 0)
        (: b (s i)
           (? (q = 39) (sh-subp S s n (i + 1) depth (b @ 39 0 39) 0)
              (b = 92) (sh-subp S s n (i + 1) depth q 1)
              (sh-love3? s n i)
                (: r (sh-lovep S s n (i + 2))
                   (sh-subp S s n (two? r ? >r (i + 1)) depth q 0))
              (q = 34) (sh-subp S s n (i + 1) depth (b @ 34 0 34) 0)
              (b @ 39 (sh-subp S s n (i + 1) depth 39 0)
                   34 (sh-subp S s n (i + 1) depth 34 0)
                   40 (sh-subp S s n (i + 1) (depth + 1) 0 0)
                   41 (depth = 1 ? (i + 1) (sh-subp S s n (i + 1) (depth - 1) 0 0))
                      (sh-subp S s n (i + 1) depth 0 0)))))
   ; $(( .. )), i past the two ( -> end index | (). a miss is not an error but the
   ; other reading: `$((cd a) && b)` is a $( ) opening a subshell
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
   ; ${(FORM)}, i at the ( : love's reader finds the extent, as no shell scan can.
   ; -> (text . j past the }) | 'torn unfinished | () no } in place
   (sh-lovews s n k) (k < n && lx-ws? (s k) ? (sh-lovews s n (k + 1)) k)
   (sh-lovep S s n i)
    (sound (snip s i n) @
     (_ . rest)
      (: k (n - #rest)                  ; past the datum, in s's own index
         j (sh-lovews s n k)
         (? (n <= j) 'torn
            (s j = 125) (snip s i k . j + 1)))
     'torn)                                   ; 'torn, and a bodyless () with it
   ; ${ ... }: to the matching }, blind to quoted braces -> j past } | ()
   (sh-brace S s n i depth q) (i != n ? (: b (s i) (?
    (q = 39) (sh-brace S s n (i + 1) depth (b @ 39 0 39))
    (sh-love3? s n i)
      (: r (sh-lovep S s n (i + 2))
         (sh-brace S s n (two? r ? >r (i + 1)) depth q))
    (q = 34) (sh-brace S s n (i + 1) depth (b @ 34 0 34))
    (b @ 39  (sh-brace S s n (i + 1) depth 39)
         34  (sh-brace S s n (i + 1) depth 34)
         123 (sh-brace S s n (i + 1) (depth + 1) 0)
         125 (depth = 1 ? (i + 1) (sh-brace S s n (i + 1) (depth - 1) 0))
             (sh-brace S s n (i + 1) depth 0)))))
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
   (sh-dol S s n i)
     (? (i = n) ('dollar . i)
        (: b (s i)
           (spec nm) (('var . nm) . i + 1)    ; the one-byte specials, $? $@ ..
           (b @ 63 (spec "?") 64 (spec "@") 42 (spec "*")
                35 (spec "#") 36 (spec "$") 33 (spec "!")
                40 (: ar (i + 1 < n && s (i + 1) = 40 ? (sh-arip s n (i + 2) 0))
                    (charm? ar ? (('ari . snip s (i + 2) ar) . ar + 2)
                       (: e (sh-subp S s n (i + 1) 1 0 0)
                          (? !e 'unterm (('sub . snip s (i + 1) (e - 1)) . e)))))
                ; ${( -- the reader's extent, never sh-brace's: a } in a love "" fools it
                123 (i + 1 < n && s (i + 1) = 40 ?
                     (: r (sh-lovep S s n (i + 1))
                        (atom? r ? 'unterm (('lov . <r) . >r)))
                     (: e (sh-brace S s n (i + 1) 1 0)
                        (? !e 'unterm
                           (: sg (sh-vopp (snip s (i + 1) (e - 1)))
                              (? !sg 'unterm (sg . e))))))
                (? (sh-digit? b) (spec (string b))   ; $0-9, one digit (the POSIX law)
                   (sh-name1? b)
                     (: (go j) (j < n && sh-name? (s j) ? (go (j + 1)) j)
                        e (go i) (('var . snip s i e) . e))
                   ('dollar . i)))))
   ; a live $ or ` at i -> k's next step past it: a segment, else a literal char.
   ; 'dollar first: a bare $ answers ('dollar . i), which a plain pair pattern
   ; would take for a segment and splice as one
   (sh-live S s n i cur segs k)
     (: lit (#cur ? (('lit . cur) . segs) segs)
        (s i = 36 ? (sh-dol S s n (i + 1) @
                      ('dollar . j) (k j (cur + "$") segs)
                      (sg . j)      (k j "" (sg . lit))
                                    (k (i + 1) (cur + "$") segs))
                    (sh-bt s n (i + 1) "" @
                      (t . j) (k j "" (('sub . t) . lit))
                              (k (i + 1) (cur + "`") segs))))
   ; a bare text (heredoc body, vop word) -> segs, $ and ` live, \ escapes $ ` \
   (sh-dollarize S s)
     (: n #s
        (addl cur segs) (#cur ? (('lit . cur) . segs) segs)
        (go i cur segs)
          (? (i = n) (rev (addl cur segs))
           (: b (s i)
              (? (b = 92 && i + 1 < n && sh-btesc? (s (i + 1)))
                   (go (i + 2) (cur + string (s (i + 1))) segs)
                 (b = 36 || b = 96) (sh-live S s n i cur segs go)
                 (go (i + 1) (cur + string b) segs))))
        (go 0 "" ()))
   ; vop word text -> segs, quote-aware, so a quoted glob char is inert in ${v#pat};
   ; an unterminated quote is a literal char
   (sh-wordize S s)
     (: n #s
        (addl cur segs) (#cur ? (('lit . cur) . segs) segs)
        ; ".." inner: $ ` live, \ escapes $ ` \ ", " closes -> (segs . j) | ()
        (dq i cur segs)
         (i != n ? (: b (s i) (b @
          34 (rev (addl cur segs) . i + 1)
          (92 && i + 1 < n && (sh-btesc? (s (i + 1)) || s (i + 1) = 34))
           (dq (i + 2) (cur + string (s (i + 1))) segs)
          (36 || 96) (sh-live S s n i cur segs dq)
          (dq (i + 1) (cur + string b) segs))))
        (go i cur segs)
          (? (i = n) (rev (addl cur segs))
             (: b (s i) (b @
              39 (:- (cl (i + 1) "")
                  (cl j acc) (? (j = n)    (go (i + 1) (cur + string b) segs)
                                (s j = 39) (go (j + 1) "" (('sq . acc) . addl cur segs))
                                           (cl (j + 1) (acc + string (s j)))))
              34 (dq (i + 1) "" () @
                  (inner . j) (go j "" (('dq . inner) . addl cur segs))
                              (go (i + 1) (cur + string b) segs))
              (92 && i + 1 < n) (go (i + 2) (cur + string (s (i + 1))) segs)
              (36 || 96) (sh-live S s n i cur segs go)
              (go (i + 1) (cur + string b) segs))))
        (go 0 "" ()))

   ; --- heredoc collection ------------------------------------------------------
   ; the delimiter word -> (quoted? . delim . j) | (): any quote or \ in it quotes the body
   (sh-hddelim s n i)
     (: (bare? x) !(lx-ws? x || elem x '(10 124 38 59 60 62 40 41))
        (qt j b acc) (? (j = n) ()
                        (s j = b) (go (j + 1) acc 1)
                        (qt (j + 1) b (acc + string (s j))))
        (go j acc q)
         (? (j < n && (s j = 39 || s j = 34)) (qt (j + 1) (s j) acc)
            (j + 1 < n && s j = 92) (go (j + 2) (acc + string (s (j + 1))) 1)
            (j < n && bare? (s j)) (go (j + 1) (acc + string (s j)) q)
            (0 < #acc || q) (q . acc . j)
            ())
        (go i "" 0))
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

   (sh-lex S s)
   (: n #s
      (addl cur segs) (#cur ? (('lit . cur) . segs) segs)
      (fw cur started segs toks)                    ; flush the word in progress
        (: sg (addl cur segs)
           (started || two? sg ? (('w . rev sg) . toks) toks))
      ; substitute each heredoc placeholder word with its collected body
      (fixw t bods)
        (<t = 'w && two? >t && <<>t = 'hd ?
         (: e (sh-alook bods ><>t)
          ('w . (<e ? [('sq . >e)] [('dq . (sh-dollarize S) >e)])))
         t)
      (fin toks hq bods)
        (two? hq ? ('more . 'heredoc)
                   (1 . map (t \ fixw t bods) (rev toks)))
      ; '...' -> index of the closing quote | ()
      (sq j) (? (j = n) () (s j = 39) j (sq (j + 1)))
      (esc? b) (elem b '(34 36 92 96))
      (peek? i b) (i + 1 < n && s (i + 1) = b)
      ; ".." -> (segs . j-past) | () unfinished
      (dq i cur segs) (i != n ?
       (s i @ 34 (rev (addl cur segs) . i + 1)
              (92 && peek? i 10) (dq (i + 2) cur segs)
              (92 && i + 1 < n && esc? (s (i + 1)))
               (dq (i + 2) (cur + string (s (i + 1))) segs)
              36 (sh-dol S s n (i + 1) @ ('dollar . j) (dq j (cur + "$") segs)
                                       (sg . j) (dq j "" (sg . addl cur segs)))
              96 (sh-bt s n (i + 1) "" @ (t . j) (dq j "" (('sub . t) . addl cur segs)))
              b (dq (i + 1) (cur + string b) segs)))
      ; hq/bods/k are the heredoc state. no per-step helper closures here or in sh-subp /
      ; sh-brace: each runs once per byte, so the state rides in the parameters
      (op2 i cur started segs toks hq bods k o adv)  ; flush + emit an operator
        (lx (i + adv) "" 0 () (('op . o) . fw cur started segs toks) hq bods k)
      (lx i cur started segs toks hq bods k)
        (i = n ? (fin (fw cur started segs toks) hq bods)
         (s i @ (b && lx-ws? b) (lx (i + 1) "" 0 () (fw cur started segs toks) hq bods k)
               10 (: tks (('op . "nl") . fw cur started segs toks)
                   (? (atom? hq) (lx (i + 1) "" 0 () tks hq bods k)
                      (: (coll j q bs)                 ; owed bodies, in arrival order
                           (q @ (h . rest)
                              (sh-hdlines s n j (h 1) (h 3) @ (body . j2)
                                 (coll j2 rest ((h 0 . (h 2 . body)) . bs)))
                              (j . bs))
                         (coll (i + 1) (rev hq) bods @
                          (j . bs) (lx j "" 0 () tks () bs k)
                                    ('more . 'heredoc)))))
               ; a comment ends at its line, not the buffer; the nl still lexes
               (35 && !started)
                 (: (sk j) ((j < n && s j != 10) ? (sk (j + 1)) j)
                    (lx (sk (i + 1)) "" 0 () toks hq bods k))
               39 (: j (sq (i + 1))
                   (? !j ('more . 'quote)
                    (lx (j + 1) "" 1 (('sq . snip s (i + 1) j) . addl cur segs) toks hq bods k)))
               34 (dq (i + 1) "" () @
                   (inner . j) (lx j "" 1 (('dq . inner) . addl cur segs) toks hq bods k)
                   ('more . 'quote))
               36 (sh-dol S s n (i + 1) @
                   ('dollar . j) (lx j (cur + "$") 1 segs toks hq bods k)
                   (sg . j) (lx j "" 1 (sg . addl cur segs) toks hq bods k)
                   ('more . 'sub))
               96 (sh-bt s n (i + 1) "" @
                   (t . j) (lx j "" 1 (('sub . t) . addl cur segs) toks hq bods k)
                   ('more . 'sub))
               92 (? (i + 1 = n) ('more . 'cont)
                     (s (i + 1) = 10) (lx (i + 2) cur started segs toks hq bods k)
                     ; \c quotes c: a one-byte '..', so \* never globs
                     (lx (i + 2) "" 1 (('sq . string (s (i + 1))) . addl cur segs) toks hq bods k))
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
                                  . ('rd . ion . "<h") . tks)
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
;
; (sh-parse tokens) -> ('ok . ast) | ('more . why) | ('err . msg). the AST:
;   ('cmd words redirs)     words segment lists; redirs (ion op target)
;   ('pipe cmds) ('and a b) ('or a b) ('seq a b) ('bg a) ('not a)
;   ('if ((cond . body)..) else) ('while cond body) ('until cond body)
;   ('for name words body) ('case word ((patterns . body)..))
;   ('group body) ('subsh body) ('fun name body) ('rdr ast redirs)
; reserved words count only at command position: a closer answers ('stop . ts), ending
; the list, and each compound parser expects its own.

(module 'lush
(: (tk-op? t o) (<t = 'op && >t = o)
   (tk-w? t) (<t = 'w)
   (tk-rd? t) (<t = 'rd)
   (tk-nl? t) (tk-op? t "nl")
   (skipnl ts) (ts && tk-nl? <ts ? (skipnl >ts) ts)   ; the answer is a list: not a truth value
   (skipsep ts) (two? ts && (tk-op? <ts ";" || tk-nl? <ts) ?  (skipsep >ts) ts)
   (bad? r) (atom? <r)
   ; the bare text of a plain unquoted one-segment word, "" otherwise
   (litw t) (two? t && tk-w? t && two? >t && !>>t && <<>t = 'lit ? ("" + ><>t) "")
   (rw? t w) (#(litw t) && w = litw t)
   stopw '("then" "else" "elif" "fi" "do" "done" "esac" "}")
   ; the whole reserved set, for `type` and `command -v`
   sh-resw ('("!" "{" "case" "for" "if" "in" "until" "while") + stopw)

   (sh-parse ts)
     (: ts2 (skipnl ts)
        (!ts2 ? ['ok]
           (: r (plist ts2)
              (? (<r = 'stop)
                   (: t <>r w (litw t)
                      ('err . ("unexpected " + (? #w w ("" + >t)))))
                 (bad? r) r
                 >r ('err . "trailing tokens")
                 ('ok . <r)))))

   ; list: & backgrounds only its own and_or; seq folds right by recursion
   (plist ts) (: r (pao ts) (? (bad? r) r (plrest <r >r)))
   (plrest a ts)
     (atom? ts ? [a]
      (: t <ts
         (? (tk-op? t "&") (plnext ['bg a] >ts)
            (tk-op? t ";" || tk-nl? t) (plnext a >ts)
            (a . ts))))
   (plnext a ts)
    (: ts2 (skipnl ts)
     (atom? ts2 ? [a]
      (: r (plist ts2)
       (? (<r = 'stop) (a . >r)                ; a closer: the list ends here
          (bad? r) r
          ['seq a <r . >r]))))

   ; and_or: && / ||, left-assoc; newlines after the op continue the line
   (pao ts) (: r (ppipe ts) (? (bad? r) r (paomore <r >r)))
   (paomore a ts)
     (atom? ts ? [a]
      (: t <ts
       (? (tk-op? t "&&") (paorhs 'and a >ts)
          (tk-op? t "||") (paorhs 'or a >ts)
          (a . ts))))
   (paorhs k a ts)
     (skipnl ts @ ts2
      (atom? ts2 ? ('more . 'op)
       (ppipe ts2 @ r (bad? r ? r (paomore [k a <r] >r)))))

   ; pipeline: a leading bare ! word negates the whole thing
   (ppipe ts)
     (rw? <ts "!" ? (ppipe1 >ts @ r (bad? r ? r ['not <r . >r])) (ppipe1 ts))
   (ppipe1 ts) (pcomm ts @ r (bad? r ? r (ppmore [<r] >r)))
   (ppmore cmds ts)
     (? (ts && tk-op? <ts "|")
        (: ts2 (skipnl >ts)
           (atom? ts2 ? ('more . 'op)
            (: r (pcomm ts2) (bad? r ? r (ppmore (<r . cmds) >r)))))
        ((? >cmds ['pipe (rev cmds)] <cmds) . ts))

   ; command: a compound by its reserved word, a function def, else simple
   (pcomm ts)
     (? (atom? ts) ('more . 'compound)
        (: t <ts w (litw t)
           (? (sh-smem? w stopw) ('stop . ts)
              ; a `)` or `;;` on its own line stops the list too
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
   (fundef? ts) (#(litw <ts) && two? >ts && tk-op? <>ts "("
                              && two? >>ts && tk-op? <>>ts ")")

   ; expect the closer w (separators skipped) -> (1 . rest) | 'more | 'err
   (expw ts w msg)
     (: ts2 (skipsep ts)
        (? (atom? ts2) ('more . 'compound)
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
        (? (two? rs) ['rdr ast (rev rs) . ts] (ast . ts)))

   (pif ts)
     (: c (plist (skipnl ts))
        (? (<c = 'stop) ('err . "if: empty condition")
           (bad? c) c
           (: t1 (expw >c "then" "if wants `then`")
              (? !(charm? <t1) t1
                 (: b (plist (skipnl >t1))
                    (? (<b = 'stop) ('err . "if: empty body")
                       (bad? b) b
                       (pifrest [(<c . <b)] >b)))))))
   (pifrest clauses ts)
     (: ts2 (skipsep ts)
        (? (atom? ts2) ('more . 'compound)
           (: w (litw <ts2)
              (w @- ('err . "if wants `fi`")
               "fi" (predir ['if (rev clauses) ()] >ts2)
               "elif"
                 (: c (plist (skipnl >ts2))
                    (? (bad? c) c
                       (: t1 (expw >c "then" "elif wants `then`")
                          (? !(charm? <t1) t1
                             (: b (plist (skipnl >t1))
                                (? (bad? b) b
                                   (pifrest ((<c . <b) . clauses) >b)))))))
               "else"
                 (: b (plist (skipnl >ts2))
                    (? (bad? b) b
                       (: f (expw >b "fi" "else wants `fi`")
                          (? !(charm? <f) f
                             (predir ['if (rev clauses) <b] >f)))))))))
   (ploop k ts)
     (: c (plist (skipnl ts))
        (? (<c = 'stop) ('err . "loop: empty condition")
           (bad? c) c
           (: d (expw >c "do" "loop wants `do`")
              (? !(charm? <d) d
                 (: b (plist (skipnl >d))
                    (? (bad? b) b
                       (: e (expw >b "done" "loop wants `done`")
                          (? !(charm? <e) e
                             (predir [k <c <b] >e)))))))))
   (pfor ts)
     (? (atom? ts) ('more . 'compound)
        (: nm (litw <ts)
           (? !#nm ('err . "for wants a name")
              (: ts2 (skipsep >ts)
                 (? (atom? ts2) ('more . 'compound)
                    (rw? <ts2 "in")
                      (: (go t acc) (? (two? t && tk-w? <t)
                                       (go >t (><t . acc))
                                       (rev acc . t))
                         r (go >ts2 ())
                         (pfordo nm <r >r))
                    (pfordo nm [[('dq . [('var . "@")])]] ts2))))))   ; bare: "$@"
   (pfordo nm ws ts)
     (: d (expw ts "do" "for wants `do`")
        (? !(charm? <d) d
           (: b (plist (skipnl >d))
              (? (bad? b) b
                 (: e (expw >b "done" "for wants `done`")
                    (? !(charm? <e) e (predir ['for nm ws <b] >e)))))))
   (pcase ts)
     (? (atom? ts) ('more . 'compound)
        (: wt <ts
           (? !(tk-w? wt) ('err . "case wants a word")
              (: i (expw >ts "in" "case wants `in`")
                 (? !(charm? <i) i (pcitems >wt () >i))))))
   (pcitems w items ts)
     (: ts2 (skipnl ts)
        (? (atom? ts2) ('more . 'compound)
           (rw? <ts2 "esac") (predir ['case w (rev items)] >ts2)
           (: ts3 (? (tk-op? <ts2 "(") >ts2 ts2)
              (go t acc)                          ; patterns: word (| word)*
                (? (atom? t) ('more . 'compound)
                   !(tk-w? <t) ('err . "case wants a pattern")
                   (: acc2 (><t . acc) t2 >t
                      (? (two? t2 && tk-op? <t2 "|") (go >t2 acc2)
                         (two? t2 && tk-op? <t2 ")") (rev acc2 . >t2)
                         (atom? t2) ('more . 'compound)
                         ('err . "case pattern wants `)`"))))
              r (go ts3 ())
              (? (atom? <r) r
                 (pcbody w <r >r items)))))
   (pcbody w pats ts items)
     (: ts2 (skipnl ts)
      (? (atom? ts2) ('more . 'compound)
         (tk-op? <ts2 ";;") (pcitems w ((pats . ()) . items) >ts2)
         (rw? <ts2 "esac") (pcitems w ((pats . ()) . items) ts2)
         (: b (plist ts2)
          (bad? b ? b
           (: ts3 (skipnl >b)
            (? (atom? ts3) ('more . 'compound)
               (tk-op? <ts3 ";;")
                 (pcitems w ((pats . <b) . items) >ts3)
               (rw? <ts3 "esac")
                 (pcitems w ((pats . <b) . items) ts3)
               ('err . "case wants `;;` or `esac`")))))))
   (pgroup ts)
     (: b (plist (skipnl ts))
      (? (<b = 'stop) (pgend () >b)              ; { } empty? no: the closer ends it
         (bad? b) b
         (pgend <b >b)))
   (pgend body ts)
     (: e (expw ts "}" "{ wants `}`")
      (? !(charm? <e) e (predir ['group body] >e)))
   (psubsh ts)
     (: b (plist (skipnl ts))
        (? (bad? b) b
           (: ts2 (skipnl >b)
              (? (atom? ts2) ('more . 'compound)
                 (tk-op? <ts2 ")") (predir ['subsh <b] >ts2)
                 ('err . "( wants `)`")))))
   (pfun ts)                                     ; NAME ( ) [nl] command
     (: nm (litw <ts)
        ts3 (skipnl >>>ts)
      (atom? ts3 ? ('more . 'compound)
         (: b (pcomm ts3)
            (? (bad? b) b ['fun nm <b . >b]))))

   ; simple command: words + redirects, any order; a redirect eats its target
   (pcmd ts) (pcm ts () ())
   (pcm ts ws rs)
     (? (atom? ts) (pcfin ts ws rs)
        (: t <ts
           (? (tk-w? t) (pcm >ts (>t . ws) rs)
              (tk-rd? t)
                (: ts2 >ts
                   (? (two? ts2 && tk-w? <ts2)
                      (pcm >ts2 ws [<>t >>t ><ts2 . rs])
                      (atom? ts2) ('err . "redirect wants a target")
                      ('err . "redirect wants a word")))
              (tk-op? t "(") ('err . "unexpected parenthesis")
              (pcfin ts ws rs))))
   (pcfin ts ws rs)
     (!ws && !rs ? ('err . "expected a command")
        ['cmd (rev ws) (rev rs) . ts]))
) ; module 'lush

; --- lush 🐚 the glob -- pathname expansion over readdir + stat ---
; a pattern is (text . mask), the mask a parallel string, '1' where a char came in
; unquoted (glob-live), '0' where a quote shielded it. the matcher is the 'glob module's.

(module 'lush
(: sh-anyglob (cite 'glob 'anyglob)   ; the sh- names stay: other modules
   sh-fmatch (cite 'glob 'fmatch)     ; cite them through 'lush
   sh-match (cite 'glob 'match)
   sh-ones (cite 'glob 'ones)
   (sh-globby? t m)
     (:- (go 0) n #t
      (go i) (i = n ? 0 (t i @ b (m i = 49 && (b @ (42 || 63 || 91) 1) ? 1 (go (i + 1))))))

   ; pattern -> components split on / (every /, quoted or not, is a path break)
   (sh-psplit t m)
     (:- (go 0 0 ()) n #t (go i st acc)
      (? (i = n)    (rev ((snip t st i . snip m st i) . acc))
         (t i = 47) (go (i + 1) (i + 1) ((snip t st i . snip m st i) . acc))
         (go (i + 1) st acc)))
   (sh-glob t m)
     (: comps (sh-psplit t m)
        abs (two? comps && !#<<comps)
        cs (? abs >comps comps)
      (cs && sort (gwalk (abs ? ["/"] [""]) cs)))
   ; walk: prefixes are "" (cwd) / "x/" (always /-tailed); a live component
   ; scans its directory, a dead one appends + stats (the path must EXIST)
   ; presence by two?, never !: ("") is a real prefix list netting 0
   (gwalk pfxs cs)
     (two? pfxs ?
      (: c <cs ct <c cm >c rest >cs
         nxt (? (sh-globby? ct cm)
                (catmap (d \ gmatches d ct cm) pfxs)
                (catmap (d \ d + ct @ p (two? (stat p) && [p])) pfxs))
         (atom? rest ? nxt (gwalk (map (p \ p + "/") nxt) rest))))
   ; sorted (POSIX); a leading . matches only a pattern that spells it
   (gmatches d ct cm)
     (: names (readdir (? #d d "."))
        dot (#ct && ct 0 = 46)
        (map (+ d)
         (sort (filter (nm \ (dot || nm 0 != 46) && sh-fmatch ct cm nm) names)))))
) ; module 'lush

; --- lush 🐚 the word -- expansion: segments to fields ---
;
; (sh-fields segs) -> fields, POSIX order: tilde, substitutions, IFS splitting (of
; expansion output only), glob; quotes never enter the text. a field grows as runs
; ((text . live?)..) so quoting reaches the glob mask; `seen` keeps an empty "" a field.
; ('sub . text) runs through the box sh-subeval, pinned once the engine exists.

(module 'lush
(: sh-subeval {0}
   ; IFS: unset is space, tab and newline; "" splits nothing. its white space runs
   ; together, and any other byte of it is a delimiter on its own
   (sh-ifs S _) (sh-vget S "IFS" @ (_ . v) v " \t\n")
   (sh-ifin f c) (:- (go 0) (go k) (k < #f && (f k = c || go (k + 1))))
   (sh-ifw? f c) ((c = 32 || c = 9 || c = 10) && sh-ifin f c)
   (sh-ifn? f c) (!(c = 32 || c = 9 || c = 10) && sh-ifin f c)
   (sh-chomp t)
     (:- (go #t) (go k) (0 < k && t (k - 1) = 10 ? (go (k - 1)) (snip t 0 k)))
   (sh-runsub S x) (sh-chomp ("" + sh-subeval () S x))

   ; --- love forms, evaluated in this image: (sh-loveval src) -> (1 . value) |
   ; ('err . (name . value)). several data fold to one application, so infix reads.
   ; under a trap, but a `quit` still ends the process
   (sh-loveval S src)
     ; [] is the empty chain, exactly; a `()` arm would fit anything (pat.l)
     (trap (\ _ (sounds src @ 'torn ('err . ('unfinished-form . src))
                              [] (1 . ())
                              ds (1 . (ev 'ev (two? >ds ? ds <ds)))))
           ()
           (\ a b ('err . (a . b))))
   (sh-lovesay c)                                 ; a love condition, on err, status 1
     (say err "lush: love: ", print err <c, say err " ",
        print err >c, put err 10, flush err, 1)
   ; a love value as shell text: a string is its bytes, else love notation
   (sh-lovetext v) (string? v ? v (show v))
   ; ${(FORM)}: the text, or "" and a complaint on err
   (sh-lovseg S src)
     (sh-loveval S src @ ('err . c) (sh-lovesay c, "")
                       (_ . v)     (sh-lovetext v)
                       _            "")

   ; --- parameters: shell vars over env; specials; presence out of band --------
   ; (sh-vget nm) -> () unset | (1 . value) -- a tablet hit is a string (maybe
   ; ""), the miss the (); string? tells them apart where net cannot
   (sh-vget S nm)
     (nm @ "?" (1 . show (S 'sh-status))
         "#" (1 . show #(S 'sh-pos))
         "$" (1 . show (getpid 0))
         "!" (1 . show (S 'sh-lastbg))
         "0" (1 . ("" + (S 'sh-arg0)))
        ("@" || "*") (1 . sh-unwords (S 'sh-pos))
        (_ && sh-digits? nm)
          (: (go (a . u) k) (k @ 1 (1 . a) (go u (k - 1)))
             (go (S 'sh-pos) (sh-int nm)))
        (: v ((S 'sh-vars) nm)
           (string? v ? (1 . v) (getenv nm @ e (string? e ? (1 . e))))))
   (sh-vval S nm)
    (sh-vget S nm @ (_ . u) u
      ((S 'sh-uflag) ?
        (say err ("lush: " + (nm + ": unbound\n")),
         (S 'sh-tty) || (sh-leave S) 2),
       ""))
   (sh-ro? S nm) (peep (S 'sh-rovars) nm 0)
   (sh-rosay S nm)                                ; a readonly assignment: an error, fatal to a script
     (say err ("lush: " + nm + ": readonly variable\n"), pin S 'sh-status 1,
      (? (S 'sh-tty) 1 (sh-leave S 2)))
   (sh-setvar S nm v)                             ; an exported name stays exported
    (? (sh-ro? S nm) (sh-rosay S nm)
       (string? (getenv nm)) (setenv nm v)
       (pin (S 'sh-vars) nm v))

   ; --- $(( .. )): C's integer operators by precedence climbing. each step answers
   ; (value . index past) or (). a name's value is arithmetic text (`x=1+1` makes
   ; $((x*2)) four), hence the depth cap. values are tested against 0, never by ?
   (ar-bad S msg) (pin S 'arerr 1,
                 peep S 'arlive 1 && say err ("lush: arithmetic: " + msg + "\n"),
                 ())
   ; a runtime complaint, silent in a branch not taken: `x != 0 && 100 / x`
   (ar-rt S msg) (peep S 'arlive 1 ? (ar-bad S msg) 0)
   (ar-dead S th) (: old (peep S 'arlive 1) v (pin S 'arlive 0, th ()) (pin S 'arlive old, v))
   (ar-ws s n i) (i < n && (s i = 32 || s i = 9 || s i = 10) ? (ar-ws s n (1 + i)) i)
   (ar-at s n i t) (: m #t (i + m <= n && snip s i (i + m) = t))
   (ar-has? l t) (any (= t) l)
   ; --- numbers: 0x hex, leading-0 octal, else decimal
   (ar-hexv b) (? (sh-digit? b) (b - 48)
                  (97 <= b < 103) (b - 87)
                  (65 <= b < 71) (b - 55))
   (ar-dig? b base) (: v (ar-hexv b) (charm? v && v < base))
   (ar-digs s n i base acc any?)
     (? (i < n && ar-dig? (s i) base)
        (ar-digs s n (1 + i) base (acc * base + ar-hexv (s i)) 1)
        (any? ? (acc . i)))
   (ar-num s n i)
     (? (1 + i < n && s i = 48 && (s (1 + i) = 120 || s (1 + i) = 88))
          (ar-digs s n (2 + i) 16 0 0)
        (s i = 48 && 1 + i < n && ar-dig? (s (1 + i)) 8)
          (ar-digs s n (1 + i) 8 0 0)
        (ar-digs s n i 10 0 0))
   (ar-name s n i)
     (? (i < n && sh-name1? (s i))
        (: (go j) (j < n && sh-name? (s j) ? (go (1 + j)) j)
           e (go i) ((snip s i e) . e))
        ())
   ; a name's value as a number; unset or empty is 0
   (ar-vval S nm d)
     (: g (sh-vget S nm) t (? (two? g) >g "")
        (? (0 = #t) 0 (d = 0) (ar-bad S "name nesting too deep") (ar-eval S t (d - 1))))
   (ar-store S nm v) (sh-setvar S nm (show v), v)
   ; --- the operators. love truncates // toward zero, which is C's division; >>
   ; is C's arithmetic shift and wants the floor, so it is spelled out.
   (ar-fdiv a b) (: q (a // b) (q * b = a ? q (a < 0 ? (q - 1) q)))
   (ar-apply S o a b)
     (o @ "+"  (a + b)   "-" (a - b)   "*" (a * b)
          "/"  (b = 0 ? (ar-rt S "division by zero") (a // b))
          "%"  (b = 0 ? (ar-rt S "division by zero") (a - b * (a // b)))
          "<<" (b < 0 ? (ar-rt S "negative shift") (a * b 2))
          ">>" (b < 0 ? (ar-rt S "negative shift") (ar-fdiv a (b 2)))
          "<"  (a < b ? 1 0)     "<=" (a <= b ? 1 0)
          ">"  (a > b ? 1 0)     ">=" (a >= b ? 1 0)
          "==" (a = b ? 1 0)    "!=" (a = b ? 0 1)
          "&"  (a & b) "^" (a ^ b) "|" (a | b)
          "**" (b < 0 ? (ar-rt S "negative exponent") (b a))
          (ar-bad S ("unknown operator " + o)))
   ; loosest first. ** associates right and is not POSIX
   arlv '(("||") ("&&") ("|") ("^") ("&") ("==" "!=") ("<=" ">=" "<" ">")
          ("<<" ">>") ("+" "-") ("*" "/" "%") ("**"))
   ; the operator at i, off its first byte or two: every rung asks it, so no list walk
   (ar-op s n i) (n > i ?
    (: b2 (1 + i < n && s (1 + i))
     (s i @ 42 (b2 @ 42 "**" "*")
            60 (b2 @ 60 "<<" 61 "<=" "<")
            62 (b2 @ 62 ">>"  61 ">=" ">")
            61 (b2 @ 61 "==")
            33 (b2 @ 61 "!=")
            38 (b2 @ 38 "&&" "&")
            124 (b2 @ 124 "||" "|")
            43 "+" 45 "-" 47 "/" 37 "%" 94 "^")))
   ; the assignment operators: <<= >>= and the <op>= family, then a lone = when
   ; the next byte is not one, or `a == b` would assign.
   (ar-asnop s n i)
     (? (n > i)
      (: b (s i) b2 (1 + i < n ? (s (1 + i)) 0) b3 (2 + i < n ? (s (2 + i)) 0)
       (? (b = 61) (b2 @ 61 () ("=" . 1 + i))
          ((b = 60 || b = 62) && b2 = b && b3 = 61) (snip s i (3 + i) . 3 + i)
          (b2 = 61 && (elem b '(42 47 37 43 45 38 94 124))) (snip s i (2 + i) . 2 + i))))
   ; --- the walk
   (ar-expr S s n i d)
     (: i0 (ar-ws s n i)
        nv (ar-name s n i0)
        (? (atom? nv) (ar-cond S s n i0 d)
           (: j (ar-ws s n >nv)
              op (ar-asnop s n j)
              (? (atom? op) (ar-cond S s n i0 d)
               (: r (ar-expr S s n >op d)
                (? (atom? r) ()
                   (<op = "=") ((ar-store S <nv <r) . >r)
                   (: cur (ar-vval S <nv d)
                      (? !(charm? cur) ()
                         (: v (ar-apply S (snip <op 0 (#<op - 1)) cur <r)
                            (charm? v ? ((ar-store S <nv v) . >r) ()))))))))))
   (ar-cond S s n i d)
     (: r (ar-bin S s n i 0 d)
        (two? r ?
           (: j (ar-ws s n >r)
              (? !(j < n && s j = 63) r
                 (: c !(<r = 0)
                    a (c ? (ar-expr S s n (1 + j) d) (ar-dead S (_ \ (ar-expr S) s n (1 + j) d)))
                    (two? a ?
                       (: j2 (ar-ws s n >a)
                          (? !(j2 < n && s j2 = 58) (ar-bad S "? without :")
                             (: b (c ? (ar-dead S (_ \ (ar-cond S) s n (1 + j2) d))
                                       (ar-cond S s n (1 + j2) d))
                                (two? b ? ((c ? <a <b) . >b)))))))))))
   (ar-bin S s n i k d)
     (? (k >= #arlv) (ar-un S s n i d)
        (: r (ar-bin S s n i (1 + k) d) (? (atom? r) () (ar-more S s n r k d))))
   ; one more operator at this rung, left-associating. && and || do not evaluate
   ; the side they do not need -- `x = 0 || 1 / x` is the whole reason.
   (ar-more S s n r k d)
     (: j (ar-ws s n >r)
        o (ar-op s n j)
        (? !(string? o) r
           !(ar-has? (arlv k) o) r
           (: j2 (j + #o)
              sc (o = "&&" || o = "||")
              rt? (o = "**")                    ; the one right-associating rung
              dead? (sc && (o = "&&" ? (<r = 0) (<r != 0)))
              nk (rt? ? k (1 + k))
              rr (dead? ? (ar-dead S (\ _ (ar-bin S s n j2 nk d)))
                          (ar-bin S s n j2 nk d))
              (? (atom? rr) ()
                 (: v (? !sc (ar-apply S o <r <rr)
                         dead? (o = "&&" ? 0 1)
                         (<rr = 0 ? 0 1))
                    (? !(charm? v) ()
                       rt? (v . >rr)           ; the RHS already took the whole tail
                       (ar-more S s n (v . >rr) k d)))))))
   (ar-un S s n i d)
     (: i2 (ar-ws s n i)
        (? (n <= i2) ()
           (ar-at s n i2 "++") (ar-step S s n (2 + i2) 1 d)
           (ar-at s n i2 "--") (ar-step S s n (2 + i2) (0 - 1) d)
           (: b (s i2)
              neg (f \ (ar-un S) s n (1 + i2) d @ (a . u) (f a . u))
              (b @ 45 (neg (v \ -v))
                   43 (ar-un S s n (1 + i2) d)
                   33 (neg (= 0))
                   126 (neg (v \ -v - 1))
                   (ar-prim S s n i2 d)))))
   ; ++name / --name: the new value. the postfix pair is in ar-prim, and answers
   ; the old one -- the only difference between them.
   (ar-step S s n i by d)
     (: nv (ar-name s n (ar-ws s n i))
        (atom? nv ? (ar-bad S "++ wants a name")
         (: cur (ar-vval S <nv d)
          (charm? cur ? (ar-store S <nv (cur + by) . >nv)))))
   (ar-prim S s n i d)
     (: i2 (ar-ws s n i)
        (? (n <= i2) (ar-bad S "expression ends early")
           (s i2 = 40)
             (ar-expr S s n (1 + i2) d @ (a . u)
              (ar-ws s n u @ j
               (j < n && s j = 41 ? (a . 1 + j) (ar-bad S "( without )"))))
           (sh-digit? (s i2)) (: r (ar-num s n i2) (two? r ? r (ar-bad S "bad number")))
           (sh-name1? (s i2))
             (: nv (ar-name s n i2)
                j (ar-ws s n >nv)
                (? (ar-at s n j "++") (ar-post S <nv 1 d (2 + j))
                   (ar-at s n j "--") (ar-post S <nv (0 - 1) d (2 + j))
                   (: v (ar-vval S <nv d) (charm? v ? (v . >nv)))))
           (ar-bad S ("unexpected " + string (s i2)))))
   (ar-post S nm by d j)
    (: cur (ar-vval S nm d)
     (charm? cur ? (ar-store S nm (cur + by), cur . j)))
   ; the whole text, and nothing left over
   (ar-eval S src d)
     (: n #src
        r (ar-expr S src n 0 d)
        (two? r ? (: j (ar-ws src n >r) (j < n ? (ar-bad S "trailing text") <r))))
   ; ('ari . text) -> shell text, "" when bad (0 would be quietly wrong). the text
   ; expands first (POSIX); a bare name survives that and reaches ar-vval
   (sh-arith S src)
     (: _ (pin S 'arerr 0) _ (pin S 'arlive 1)
        v (ar-eval S (sh-voptext S src) 24)
        (charm? v ? (show v)
           (peep S 'arerr 0 ? 0
            (say err ("lush: arithmetic: " + src + ": syntax error\n")),
            "")))

   ; --- ${name<op>text}: the word text re-enters through sh-wordize ------------
   (sh-textof S segs)                      ; segs -> one string; recurses, so not point-free
   (foldl (\ a sg (: k <sg (a + (k @ 'lit >sg 'sq >sg 'dq (sh-textof S >sg) 'var (sh-vval S >sg)
                                     'vop (sh-vopseg S sg) 'sub (sh-runsub S >sg)
                                     'ari (sh-arith S >sg) 'lov (sh-lovseg S >sg) "")))) "" segs)
   (sh-voptext S text) (sh-textof S (sh-wordize S text))
   (sh-vopseg S sg) (: p >sg (sh-vop S (p 0) (p 1) (p 2)))
   (sh-vop S nm op text)
     (op @ "len" (show #(sh-vval S nm))
      (: g (sh-vget S nm)
         set? (two? g)
         v (? set? >g "")
         colon (#op && op 0 = 58)
         use? (? colon (set? && #v) set?)
         o (? colon (snip op 1 #op) op)
         (o @- (sh-vstrip S v o text)
          "-" (? use? v (sh-voptext S text))
          "=" (? use? v (: t (sh-voptext S text) _ (sh-setvar S nm t) t))
          "?" (? use? v (say err ("lush: " + (nm + (": " + (? #text text "parameter not set")))),
                         put err 10,
                         (S 'sh-tty) ? "" (sh-leave S 2)))
          "+" (? use? (sh-voptext S text) ""))))
   ; ${v#pat} ${v##pat} ${v%pat} ${v%%pat}: short/longest prefix/suffix strip
   (sh-patmask S segs)                     ; segs -> (text . mask), quotes inert
     (foldl (\ a sg (: k <sg
                       t (k @ 'lit >sg 'sq >sg 'dq (sh-textof S >sg) 'var (sh-vval S >sg)
                             'vop (sh-vopseg S sg) 'sub (sh-runsub S >sg) 'ari (sh-arith S >sg)
                             'lov (sh-lovseg S >sg) "")
                       live (k @ ('sq || 'dq || 'lov) "0" "1")
                       (<a + t . >a + sh-mrep #t live)))
            ("" . "") segs)
   (sh-vstrip S v o text) (: pw (sh-patmask S (sh-wordize S text)) pt <pw pm >pw n #v (o @
    "#"  (:- (go 0) (go i) (n < i ? v (sh-fmatch pt pm (snip v 0 i) ? (snip v i n) (go (i + 1)))))
    "##" (:- (go n) (go i) (i < 0 ? v (sh-fmatch pt pm (snip v 0 i) ? (snip v i n) (go (i - 1)))))
    "%"  (:- (go 0) (go k) (n < k ? v (sh-fmatch pt pm (snip v (n - k) n) ? (snip v 0 (n - k)) (go (k + 1)))))
    "%%" (:- (go n) (go k) (k < 0 ? v (sh-fmatch pt pm (snip v (n - k) n) ? (snip v 0 (n - k)) (go (k - 1)))))
    v))

   ; --- the field machinery -----------------------------------------------------
   ; field state: (done runs seen) -- done finished fields (rev), runs the
   ; field in progress (rev run list), seen "this field exists"
   (addrun runs t a) (? #t ((t . a) . runs) runs)
   (closef done runs seen) (? seen (runs . done) done)
   (skifs f t i n) (i < n && sh-ifw? f (t i) ? (skifs f t (i + 1) n) i)
   (chunk f t i n) (i < n && !(sh-ifin f (t i)) ? (chunk f t (i + 1) n) i)
   ; past a delimiter -- IFS white space around at most one other IFS byte -- at j: (k . hard?),
   ; hard when that other byte is there, which ends a field even an empty one
   (delim f t j n) (: k (skifs f t j n)
                    (? (k < n && sh-ifn? f (t k)) (skifs f t (k + 1) n . 1) (k . 0)))
   ; split expansion output on IFS: chunks join the field, a delimiter closes it
   (spl f t i n done runs seen)
     (? (i = n) [done runs seen]
        (sh-ifin f (t i))
          (: d (delim f t i n) (spl f t <d n (closef done runs (seen || >d)) () 0))
        (: j (chunk f t i n)
           (spl f t j n done (addrun runs (snip t i j) 1) 1)))
   (split S t d r sn) (spl (sh-ifs S ()) t 0 #t d r sn)
   ; bare $@ and $*: each positional splits on its own, and a field ends between two
   (splitpos S ps d r sn) (? (atom? ps) [d r sn]
                           (: st (split S <ps d r sn)
                              (? (two? >ps) (splitpos S >ps (closef (st 0) (st 1) (st 2)) () 0) st)))

   ; ".." with the $@ law: each positional its own field, edges glue
   (dqat S inner st)
     (? (atom? inner) st
        (: sg <inner k <sg
           d (st 0) r (st 1)
           (? (k = 'var && >sg = "@")
              (: ps (S 'sh-pos)
                 st2 (? (atom? ps) st
                        (foldl (\ a p (: dd (a 0) rr (a 1) sn2 (a 2)
                                         (? sn2 [(rr . dd) (addrun () p 0) 1]
                                            [dd (addrun () p 0) 1])))
                               [d (addrun r (two? ps ? <ps "") 0) 1]
                               >ps))
                 (dqat S >inner st2))
              (dqat S >inner
                    [d (addrun r (k @ 'lit >sg
                                      'var (sh-vval S >sg)
                                      'vop (sh-vopseg S sg)
                                      'sub (sh-runsub S >sg)
                                      'ari (sh-arith S >sg)
                                      'lov (sh-lovseg S >sg)
                                      "")
                                 0)
                       1]))))
   (wseg S sg st)
     (: d (st 0) r (st 1) sn (st 2)
        k <sg v >sg
        (k @ 'lit [d (addrun r v 1) 1]
             'sq  [d (addrun r v 0) 1]
           ; ${(..)} is one field: never split, never globbed
             'lov [d (addrun r (sh-lovseg S v) 0) 1]
           ; "": a real (seen) field even empty -- except a lone "$@" over zero
           ; positionals, which contributes nothing (dqat's glue lane sets seen)
             'dq  (dqat S v [d r (two? v ? sn 1)])
             'var (? (v = "@" || v = "*") (splitpos S (S 'sh-pos) d r sn) (split S (sh-vval S v) d r sn))
             'vop (split S (sh-vopseg S sg) d r sn)
             'sub (split S (sh-runsub S v) d r sn)
             'ari (split S (sh-arith S v) d r sn)
             st))
   (wsegs S segs st) (? !segs st (wsegs S >segs (wseg S <segs st)))

   ; ~ / ~/rest at the word's head -> $HOME, shielded (never split, never glob);
   ; the rest of the run stays live so ~/*.l still globs
   (sh-tilde segs) (?- segs
    (two? segs && <<segs = 'lit && #><segs && ><segs 0 = 126)
     (: t ><segs h ("" + getenv "HOME")
      (?- segs
       (t = "~") (('sq . h) . >segs)
       (t 1 = 47) (('sq . h) . ('lit . snip t 1 #t) . >segs))))

   ; a finished field: join the runs; a live glob char sends it to sh-glob,
   ; no match keeps the word (the POSIX default)
   (sh-mrep k c) (k < 1 ? "" (sh-mrep (k - 1) c + c))
   (sh-field1 runs)
     (: rs (rev runs)
        t (foldl (a \ r \ a + <r) "" rs)
        gb (foldl (\ a r (? a a (>r && sh-anyglob <r))) 0 rs)
        (? gb
           (: m (foldl (\ a r (a + (sh-mrep #<r (? >r "1" "0")))) "" rs)
              g (sh-glob t m)
              (? g g [t]))
           [t]))
   (sh-fields S segs)
     (: st (wsegs S (sh-tilde segs) [() () 0])
        fs (rev (closef (st 0) (st 1) (st 2)))
        (catmap sh-field1 fs)))
) ; module 'lush

; --- lush 🐚 the evaluator -- AST to processes ---
;
; (sh-line src) -> ('more . why) | status. redirects become an fdmap ((childfd . srcfd)..)
; laid in order (POSIX). the AST is planned into closures once (sh-plan), then run.
; control flow rides out as pairs: ('brk . n) ('cnt . n) ('ret . st).

(module 'lush
(:
   ; export NAME=VAL -> setenv; export NAME promotes the shell var
   (sh-eqpos s i) (#s @ ^i () (s i @ 61 i (sh-eqpos s (i + 1))))
   (sh-export S w)
     (w @ ((n && 0 < #n) + "=" + v) (? (sh-ro? S n) (sh-rosay S n) (setenv n v))
        (setenv w (sh-vval S w)))

   (cmderr S msg) (say err ("lush: " + (msg + "\n")), pin S 'sh-status 1, 1)
   ; a child that cannot exec only exits 127, so "not found" is said here
   (sh-saynf w) (say err ("lush: " + (w + ": not found\n")))
   ; ..through the line's redirects, so `cmd 2>/dev/null` swallows it
   (sh-nfsay S w fm)
     (? (atom? fm) (sh-saynf w)
        (: saves (map (\ e (<e . dup <e)) fm)
           _ (each fm (\ e (? (charm? >e) (dup2 >e <e) (two? >e) 0 (close <e))))
           _ (sh-saynf w)
           _ (flush err)
           (each saves (\ e (? (nom? >e) (close <e) (dup2 >e <e, close >e))))))

   ; --- redirects -> the fdmap ------------------------------------------------
   ; (sh-rdmap redirs) -> (1 fdmap opens writes) | ('err . msg). writes ((wfd . body)..)
   ; are heredoc feeds the parent pours after the spawn. sh-rdmapx defers a fifo to the
   ; child as (path mode msg): its open blocks until the other end, which we may open
   (dfd S ion d) (ion @ (i . _) i d)
   (rderr opens msg) (each opens close, ('err . msg))
   (sh-rdmap S rs) (rdm S rs () () () 0)
   (sh-rdmapx S rs) (rdm S rs () () () 1)
   (sh-fifo? t) (: s (stat t) (two? s && s 2 & 61440 = 4096))
   (rdo S rs t m d fdmap opens writes dx)
     (? (dx && sh-fifo? t)
        (rdm S >rs ((d . [t m ("lush: " + t + ": cannot open\n")]) . fdmap) opens writes dx)
        (: fd (openfd t m)
           (? (nom? fd) (rderr opens (t + ": cannot open"))
              (rdm S >rs ((d . fd) . fdmap) (fd . opens) writes dx))))
   (rdm S rs fdmap opens writes dx)
     (? !rs [1 (rev fdmap) opens writes]
        (: r <rs ion (r 0) op (r 1)
           (? (op = "<h")
              (: pp (pipe 0)
                 (? (nom? pp) (rderr opens "cannot pipe")
                    (rdm S >rs
                         ((dfd S ion 0 . <pp) . fdmap)
                         (<pp . opens)
                         ((>pp . (sh-textof S) (r 2)) . writes)
                         dx)))
              (: tf (sh-fields S (r 2))
                 (? (atom? tf || two? >tf) (rderr opens "ambiguous redirect")
                    (: t <tf
                       (op @ "<" (rdo S rs t 0 (dfd S ion 0) fdmap opens writes dx)
                          (">" || ">>") (rdo S rs t (? (op = ">") 1 2) (dfd S ion 1) fdmap opens writes dx)
                          (">&" || "<&")
                            (: d (dfd S ion (? (op = "<&") 0 1))
                               (? (t = "-") (rdm S >rs ((d . ()) . fdmap) opens writes dx)
                                  (sh-digits? t) (rdm S >rs ((d . sh-int t) . fdmap) opens writes dx)
                                  (rderr opens (t + ": bad fd"))))
                          (rderr opens (op + ": unsupported")))))))))
   (sh-hwrite wrs)
     (each wrs (\ e (: p (fdopen <e) (say p >e, close p))))

   ; --- assignments: NAME=value words at the head -------------------------------
   (sh-asnname? s)
     (: n #s
        (? !n 0 !(sh-name1? (s 0)) 0
           (: (go i) (? (i = n) 1 (? (sh-name? (s i)) (go (i + 1)) 0)) (go 1))))
   (sh-asn? segs)
     (two? segs ?
      (: h <segs
       (<h = 'lit ?
        (>h @ ((n && 0 < #n && sh-asnname? n) + "=" + rest)
           (n . (? #rest (('lit . rest) . >segs) >segs))
           ()))))
   (sh-peel ws acc)
     (two? ws ?
        (: a (sh-asn? <ws)
         (two? a ? (sh-peel >ws (a . acc)) (rev acc . ws)))
        (rev acc . ws))
   (sh-doasn S a) (sh-setvar S <a (sh-textof S >a))
   (sh-tmpset S a)                                ; temporary env around one command
     (: nm <a old (getenv nm)
      (? (sh-ro? S nm) (sh-rosay S nm) (setenv nm (sh-textof S >a)),
       nm . old))
   (sh-tmprestore e) (setenv <e >e)             ; () old unsets -- the absence lane

   ; PATH, or libc's default when it is unset (android's where /system/bin stands without
   ; /usr/bin) -- never the cwd alone
   (sh-path _)
    (: p (getenv "PATH")
       (? (string? p) p
          (two? (stat "/usr/bin") || !(two? (stat "/system/bin"))) "/usr/local/bin:/usr/bin:/bin"
          "/system/bin:/system/xbin:/vendor/bin"))
   (sh-pathdirs _)
    (:- (go 0 0 ())
     p (sh-path ()) n #p
     (go from k acc) (? (n <= k) (rev (snip p from k . acc))
                        (p k = 58) (go (k + 1) (k + 1) (snip p from k . acc))
                        (go from (k + 1) acc)))
   (sh-slashed? w) (:- (go 0) n #w (go k) (? (n <= k) 0 (w k = 47) 1 (go (k + 1))))
   ; this binary's path, or () in the kernel. asked at the call: a top-level bind
   ; would bake in the baking binary's path
   (sh-seat _) (lit? (cite 'posix 'selfpath) ? (selfpath 0))
   (sh-self? p) (stat p @ a (two? a && a = stat (sh-seat ())))
   ; hash's memory: a win is kept under the PATH that gave it, and read back only
   ; while PATH is that string and the file is still there
   (sh-hashget S w) (peep (S 'sh-hashc) w () @ (ps . p) (? (ps = (sh-path ()) && two? (stat p)) p ()) ())
   (sh-hashput S w p) (pin (S 'sh-hashc) w ((sh-path ()) . p))
   (sh-whichp S w)                                ; PATH's winner for w -> (1 path), or ()
     (? (sh-slashed? w) (two? (stat w) ? [1 w])
        (: c (sh-hashget S w)
           (? (string? c) [1 c]
              (: (go l) (two? l ?
                         (: d (? #<l <l ".") p (d + ("/" + w))
                          (two? (stat p) ? (sh-hashput S w p, [1 p]) (go >l))))
                 (go (sh-pathdirs ()))))))
   (sh-onpath? w)                               ; is PATH's winner for w this binary
     (: (go l) (two? l ?
                (: d (? #<l <l ".") p (d + ("/" + w))
                 (two? (stat p) ? (sh-self? p) (go >l))))
        (go (sh-pathdirs ())))
   ; does this binary carry the word as a verb? the registry's own answer, PATH aside
   (sh-verbw? w) (cite 'verbs 'word @ f (lit? f ? !!(f w) 0))
   ; --- the mode: where our verbs stand to PATH. 0 autonomous: before it; 1 gregarious:
   ; after it; 2 precarious: only when PATH's winner is this binary. the entry pins
   ; sh-mflag; another caller in this image reads LUSHFLAGS at each ask
   (sh-envflag S _) (: s ("" + (getenv "LUSHFLAGS")) (foldl (\ v k (s k @ 97 0 103 1 112 2 _ v)) 1 ^#s))
   (sh-mode S _) (peep S 'sh-mflag 'no @ 'no (sh-envflag S 0) v v) ; peep: a pinned 0 is a verdict, not an absence
   sh-modes {"--autonomous" 0 "--gregarious" 1 "--precarious" 2}
   ; a new mode asks each word again: the in-image and fork verdicts were the old one's
   (sh-setmode S m) (pin S 'sh-mflag m, sh-tclear (S 'sh-imgc), sh-tclear (S 'sh-forkc), 0)
   ; is the verb word ours by the mode alone, PATH's winner aside
   (sh-verbours? S w) (? !(sh-verbw? w) 0
                       (sh-mode S 0 @ 0 1 1 (atom? (sh-whichp S w)) 0))
   ; would spawning this word land on the binary we are already running?
   (sh-ours? S w) (? (sh-slashed? w) (sh-self? w)
                   (sh-verbours? S w) 1
                   (sh-onpath? w))
   ; can the word run at all? with no binary to exec (the kernel), spawn takes a verb
   ; word, a spelled path, or the path PATH found, so all three are asked
   (sh-known? S w) (? !(sh-seat ())
                      (? (sh-slashed? w || sh-dotl? w) (two? (stat w))
                         (sh-verbw? w || two? (sh-whichp S w)))
                    (sh-verbours? S w) 1
                    (two? (sh-whichp S w)))
   ; the argv a spawn execs: a verb ours by the mode runs as this binary under its word;
   ; a foreign bare word goes as (path . word), PATH already searched. in the kernel a
   ; verb word goes bare to the registry
   (sh-spawnv S argv) (: w <argv exe (sh-seat ())
                       (? (!(string? exe))
                            (? (sh-slashed? w || sh-verbw? w) argv
                               (sh-whichp S w @ r (two? r ? ((<>r . w) . >argv) argv)))
                          (sh-slashed? w) (sh-asverb S w >argv @ v (two? v ? v argv))
                          (!(sh-dotl? w) && (sh-verbours? S) w) (exe . argv)
                          (: r (sh-whichp S w)
                             (? (two? r) (sh-asverb S <>r >argv @ v (two? v ? v ((<>r . w) . >argv))) argv))))
   ; a file's #! line as words, or () -- bounded, since an elf has no first line
   (sh-iline S p)
     (: h (open p "r")
        (? !(hot? h) ()
           (: (go k acc) (see h @ c (? (c < 0 || c = 10 || 255 < k) acc (go (k + 1) (acc + string c))))
              a (see h)
              ln (? (a = 35 && see h = 33) (go 0 "") ())
              _ (close h)
              (? (string? ln) (filter (w \ 0 < #w) (cite 'kore 'usplit 32 ln)) ()))))
   ; under -a a script's interpreter is a word: #!/bin/sh, #!/usr/bin/env sh and #!/usr/bin/awk -f
   ; run as our verb when the basename is one, as the bare word would -> that argv, or ()
   (sh-asverb S p rest)
     (? !(sh-mode S 0 = 0) ()
        (: ws (sh-iline S p)
           (base x) ((: (g i) (i < 0 ? x (x i = 47 ? (snip x (i + 1) #x) (g (i - 1))))) (#x - 1))
           env? (two? ws && base <ws = "env")
           iv (? env? (? (two? >ws && <>ws = "-S") >>ws >ws) ws)
           (? (two? iv && !(sh-dotl? p) && sh-verbw? (base <iv))
              ((sh-seat ()) . (base <iv) . (>iv + (p . rest)))
              ())))
   ; --- what would run, for `command -v`, `which` and `type`, in sh-simple2's order:
   ; ('resw) ('alias text) ('fn) ('bi) ('verb path) ('path path), or ()
   (sh-vseat? S w) ((sh-seat () ? (sh-verbours? S) sh-verbw?) w)
   (sh-vpath w) (sh-seat () @ s (string? s ? s w))
   (sh-verdict S w)
     (? (sh-smem? w sh-resw) ['resw]
        (string? ((S 'sh-aliases) w)) ['alias ((S 'sh-aliases) w)]
        (sh-fn? S w) ['fn]
        (sh-bi? w) ['bi]
        (sh-slashed? w) (two? (stat w) ? ['path w])
        (sh-vseat? S w) ['verb (sh-vpath w)]
        (: p (sh-whichp S w) (two? p ? ['path <>p])))
   (sh-vname w v) (<v @ ('path || 'verb) <>v 'alias ("alias " + w + "='" + <>v + "'") w)   ; `command -v`'s line
   (sh-whichall w)                              ; every PATH hit for w, in order
     (: (go l acc)
         (? (atom? l) (rev acc)
            (: d (? #<l <l ".") p (d + ("/" + w))
               (go >l (two? (stat p) ? (p . acc) acc))))
        (go (sh-pathdirs ()) ()))

   ; the self lane: a word runs in this process when its verb has the 'self trait and
   ; the word is ours by the mode
   (sh-imgask S w)
     (: V (cite 'verbs) k (name w)
        (? (!(sh-slashed? w) && lit? (V 'get k) && !(0 = (V 'trait k 'self)) && (sh-ours? S) w)
           [1 (V 'call k) 0]
           0))
   (sh-imgfn S w) (sh-pathfresh S 0, peep (S 'sh-imgc) w 'no @ 'no (sh-imgask S w @ f (pin (S 'sh-imgc) w f, f)) v v)
   (sh-dotl? w) (: n #w (2 < n && snip w (n - 2) n = ".l"))
   ; inle and wasm have no fork: a process there is a task
   (sh-forkseat? _) (? (elem 'love-os (names ())) !(elem (ev 'love-os) '(inle wasm)) 1)
   ; a .l script's #! line -> the argv it starts under, or () when that is not this
   ; binary (env's love by PATH, a spelled path by stat)
   (sh-shebang S p)
     (: h (open p "r")
        (? !(hot? h) ()
           (: ln (sh-getline h) _ (close h)
              (? !(string? ln && 1 < #ln && ln 0 = 35 && ln 1 = 33) ()
                 (: ws (filter (w \ 0 < #w) (cite 'kore 'usplit 32 (snip ln 2 #ln)))
                    env? (two? ws && (: n #<ws (3 < n && snip <ws (n - 4) n = "/env")))
                    iv (? env? (? (two? >ws && <>ws = "-S") >>ws >ws) ws)
                    (? !(two? iv) ()
                       (? env? (<iv = "love" && sh-onpath? "love") (sh-self? <iv))
                         ((sh-seat ()) . >iv)
                       ()))))))
   ; may this word fork the warm heap instead of exec?
   (sh-forkask S w) (? !(sh-forkseat? 0) 0
                     (sh-dotl? w) (: r (sh-whichp S w) (? (two? r) (two? (sh-shebang S (r 1))) 0))
                     (sh-ours? S w) 1
                     0)
   ; the line a forked child hands cli-line: a script behind its #! line, else as spelled
   (sh-forkv S argv)
     (: w <argv
        (? !(sh-dotl? w) argv
           (: r (sh-whichp S w)
              iv (? (two? r) (sh-shebang S (r 1)) ())
              (? (two? iv) (iv + ((r 1) . >argv)) argv))))
   (sh-forkfn S w) (: _ (sh-pathfresh S 0) v (peep (S 'sh-forkc) w 'no)
                  (v != 'no ? v (: f (sh-forkask S w) (pin (S 'sh-forkc) w f, f))))
   ; a forked shell's inherited verdicts may be another mode's
   (sh-forget S _) (sh-tclear (S 'sh-imgc), sh-tclear (S 'sh-forkc), sh-tclear (S 'sh-hashc))
   ; a verdict outside autonomous mode is PATH's, so a new PATH asks each word again
   (sh-pathfresh S _) (: p (sh-path ())
                       (? (p = peep (S 'sh-verdpath) () 0) 0
                          (sh-tclear (S 'sh-imgc), sh-tclear (S 'sh-forkc), pin (S 'sh-verdpath) () p, 0)))
   (sh-fd0? fdmap) (? (atom? fdmap) 0 (<<fdmap = 0) 1 (sh-fd0? >fdmap))
   ; --- three lanes, nested: self implies fork implies exec.
   ; self: in this process; no quit, no state left behind, no reading our stdin. simple
   ;   commands only. a verb whose answer turns on its args is asked of the call.
   ; fork: the warm heap. the child must not read a stdin we have buffered from: a pipe
   ;   or file buffer duplicates across fork, a tty or an unread stdin does not.
   ; exec: a fresh image, the only lane for a foreign word.
   (sh-selfok? S w) (two? (sh-imgfn S w))
   (sh-selfcall? S av) (sh-selfok? S <av && sh-bootsame? 0 && cite 'verbs 'holds (name <av) 'self >av)
   ; this heap answers only for a child that would boot it: a knob read once at boot or
   ; wake (main.c's boot-env, each as this process saw it) set otherwise for the child --
   ; a prefix assignment, an export -- wants a fresh image, so the self and fork lanes pass
   (sh-bootsame? _) (? !(elem 'boot-env (names ())) 1
                       (foldl (\ a kv (a && (getenv <kv @ v (string? v && 0 < #v ? v ())) = <>kv)) 1 (ev 'boot-env)))
   (sh-selfplain? S w) (sh-selfok? S w && sh-bootsame? 0 && 1 = cite 'verbs 'trait (name w) 'self)
   ; a verb that wants a fresh process says so ('exec, verbs' traits), asked of this call
   ; under the name its word runs as -- a path to this binary is `love`
   (sh-exec? av) (: V (cite 'verbs) (V 'holds (name (V 'bn <av)) 'exec >av))
   (sh-forkok? S av fdmap)
     (? (sh-exec? av) 0
        !(sh-bootsame? 0) 0
        (S 'sh-tty) 1                         ; our stdin is the terminal: nothing to duplicate
        !(S 'sh-inread) 1                     ; we never read our stdin: nothing buffered to duplicate
        (sh-fd0? fdmap) 1                     ; the child's stdin is its own
        (sh-selfcall? S av) 1                   ; run in our own process, so ours to fork
        0)
   ; a forked child's process group, set on both sides so nothing races it; pg < 0
   ; keeps ours. the child's half runs while TTOU is still ignored, so it can take the tty
   (sh-pgkid pg fg) (pg < 0 ? 0 (setpg 0 pg, (? fg (ttyfg 0) 0)))
   (sh-pgdad p pg) (pg < 0 ? 0 (setpg p (? pg pg p)))
   ; such a child is the job: tty signals back to default, no job control of its own.
   ; after sh-pgkid, never before
   (sh-subjc S _) (pin S 'sh-jc 0,
                 each [sig-int sig-quit sig-tstp sig-ttou sig-ttin] (flip signal 0))
   ; one fdmap entry laid on a child's own fds; a deferred (path mode msg) opens here
   (sh-lay1 e)
     (: s >e
        (? (charm? s) (dup2 s <e)
           (two? s) (: fd (openfd (s 0) (s 1))
                       (? (nom? fd) (say err (s 2), flush err, quit 1)
                          (fd = <e) 0
                          (dup2 fd <e, close fd)))
           (close <e)))
   ; fork a warm child for argv -> the pid in the parent; the child never returns
   (sh-fork1 S argv fdmap allclose pg fg)
     (: p (fork 0)
        (?- (sh-pgdad p pg, p) (p = 0)
         (: r (wear (),
               (sh-dropcaps S) (),        ; ...and it is inside no capture of ours
            sh-pgkid pg fg,           ; the group, while the shell's TTOU ignore still holds
            ; the shell's tty ignores, shed by hand: there is no exec to reset them
            signal sig-int 0, signal sig-quit 0, signal sig-tstp 0,
            signal sig-ttou 0, signal sig-ttin 0,
            ; any scare is the child's death, never a second shell:
            ; 'leave carries the tool's status, the rest die at 1
            hear (\ a b (a @ 'leave (quit b)
                         (say err ";; ", print err a,
                          say err " ", print err b,
                          put err 10, quit 1))),
            each fdmap sh-lay1,
            (? (sh-fd0? fdmap) (chug in) 0),     ; a new stdin: our read-ahead is not its
            each allclose (fd \ 2 < fd ? (close fd) 0),
            ; a tty stdin is the child's, so a bare `love` there is the repl
            cite 'cli 'cli-line (sh-forkv S argv) (two? (tty 0) ? 1 0))
            (quit (charm? r ? (r & 255) 0)))))

   ; --- builtins: a charm status, a control pair (brk/cnt/ret), or 'nope --------
   sh-binames '("exit" "cd" "export" "pwd" "jobs" "fg" "bg" ":" "true" "false" "command"
                "read" "set" "shift" "unset" "eval" "." "wait" "local" "exec"
                "break" "continue" "return" "ev" "trap" "which" "where" "type"
                "kill" "umask" "getopts" "readonly" "alias" "unalias" "times" "hash" "ulimit")
   ; ..and the verbs that say they are builtins (echo, test ..): every mode, ahead of PATH
   (sh-verbbi? nm) (0 < cite 'verbs 'trait (name nm) 'builtin)
   (sh-bi? nm) (sh-smem? nm sh-binames || sh-verbbi? nm)
   (sh-readb S args)
     (: args2 (? (two? args && <args = "-r") >args args)
        nms (? (two? args2) args2 ["REPLY"])
        ; off a tty read byte-exact, leaving no read-ahead; a refusal means some exists
        sn (? (S 'sh-tty) 0 (snug in 1))
        _ (? sn 0 (pin S 'sh-inread 1))
        ln (sh-getline in)
        _ (? sn (snug in 0) 0)
        (? (ln = 'eof) 1 (sh-readset S (sh-ifs S ()) nms ln 0 #ln, 0)))
   ; each name but the last takes a field; the last takes the rest, less trailing IFS white space
   (sh-readset S f nms ln i n)
     (: i2 (skifs f ln i n)
        (? (atom? >nms) (sh-setvar S <nms (sh-rtrim f (snip ln i2 n)))
           (: j (chunk f ln i2 n)
              _ (sh-setvar S <nms (snip ln i2 j))
              (sh-readset S f >nms ln (? (j < n) <(delim f ln j n) j) n))))
   (sh-rtrim f s) (:- (go #s) (go k)
    (0 < k && sh-ifw? f (s (k - 1)) ? (go (k - 1)) (snip s 0 k)))
   (sh-setb S args)
     (atom? args ? 0
      (: a <args
         (? (a = "--") (pin S 'sh-pos >args, 0)
            (charm? (sh-modes a)) (sh-setmode S (sh-modes a), (sh-setb S) >args)
            (1 < #a && (a 0 = 45 || a 0 = 43))
              (:- (go 1) on (a 0 = 45 ? 1 0) (go i)
               (i = #a ? (sh-setb S >args)
                (a i @ 101 (pin S 'sh-eflag on)
                       117 (pin S 'sh-uflag on)
                       120 (pin S 'sh-xflag on),
                 go (i + 1))))
            (pin S 'sh-pos args, 0))))
   (sh-dotb S args)
     (? (atom? args) (cmderr S ". wants a file")
        (: f <args
           (? (two? (stat f))
              (: _ (pin S 'sh-retf 0)            ; a stale interactive `return` must not clip the file
                 p (open f "r") _ (sh-lines S p "") _ (close p) (S 'sh-status))
              (cmderr S (f + ": not found")))))
   ; trap [action] condition..: `-` removes the entry, '' keeps it with nothing to run, which
   ; ignores the signal here and in what the shell starts; `trap INT` is `trap - INT`
   (sh-cond w)
     (: u (sh-upper w)
        v (u @ ("SIG" + (s && 0 < #s)) s u)
        (? (v = "0") "EXIT" v))
   (sh-upper s)                                 ; an index walk: foldl does not take a string
     ((: (g i acc)
         (? (i = tally s) acc
            (: b (s i) (g (1 + i) (acc + string (97 <= b < 123 ? (b - 32) b))))))
      0 "")
   (sh-cond? w) (any (= (sh-cond w)) '("EXIT" "INT" "TERM" "HUP" "QUIT" "USR1" "USR2"
                                       "ALRM" "PIPE" "CHLD" "TSTP" "CONT" "ABRT"))
   ; every lane ends at sh-rearm: a signalfd's set is fixed when it is made
   (sh-trapb S args) (sh-trapb2 S args @ r (sh-rearm S 0, r))
   (sh-trapb2 S args)
     (? (atom? args)
        (each (keys (S 'sh-traps))
              (k \ puts ("trap -- '" + peep (S 'sh-traps) k "" + "' " + k + "\n")),
         0)
        (: a2 (? (<args = "--") >args args)
           (? (atom? a2) 0
              (sh-cond? <a2) (each a2 (w \ pull (S 'sh-traps) (sh-cond w) 0), 0)
              (<a2 = "-") (each >a2 (w \ pull (S 'sh-traps) (sh-cond w) 0), 0)
              (: act <a2
                 conds >a2
                 bad (filter (nil? * sh-cond?) conds)
                 (? (two? bad)
                    (say err ("lush: trap: " + <bad + ": bad condition\n"), 1)
                    ; a condition ignored on entry is skipped, silently (POSIX)
                    (each conds
                          (\ w (: c (sh-cond w)
                                  (? (sh-ignored? S c) 0 (pin (S 'sh-traps) c act)))),
                     0))))))
   ; which/where: a builtin, since PATH alone cannot see functions or the mode
   (sh-whichb S args)
     (: all (two? args && <args = "-a")
        (sh-which2 S "which" "which [-a] name.." all (? all >args args)))
   (sh-whereb S args) (sh-which2 S "where" "where name.." 1 args)
   (sh-which2 S nm borrow all ws)
     (: pre ("lush: " + nm + ": ")
        (? (atom? ws) (cmderr S (nm + ": usage: " + borrow))
           (foldl (\ st w
                     (: v (sh-verdict S w)
                        (? (atom? v)
                           (say err (pre + w + ": not found\n"), 1)
                           (puts (sh-vname w v + "\n"),
                            (? all (sh-whichrest w v) 0),
                            st))))
                  0 ws)))
   (sh-whichrest w v)                           ; the PATH hits the verdict did not name
     (each (sh-whichall w)
           (\ p (? (<v = 'path && p = v 1) 0 (puts (p + "\n")))))
   (sh-typeb S args)
     (? (atom? args) (cmderr S "type: usage: type name..")
        (foldl (\ st w
                  (: v (sh-verdict S w)
                     (? (atom? v)
                        (say err ("lush: type: " + w + ": not found\n"), 1)
                        (puts (w + sh-typesay v + "\n"), st))))
               0 args))
   (sh-typesay v)
     (<v @ 'resw " is a shell reserved word"
           'alias (" is an alias for " + v 1)
           'fn   " is a shell function"
           'bi   " is a shell builtin"
           'verb (" is a verb of " + v 1)
                 (" is " + v 1))
   (sh-localb S args)
     (each args (\ w (w @ ((nm && 0 < #nm) + "=" + v) (? (sh-ro? S nm) (sh-rosay S nm) (pin (S 'sh-vars) nm v))
                        (? (sh-ro? S w) (sh-rosay S w) (pin (S 'sh-vars) w "")))),
      0)
   (sh-waitb S args)                              ; wait [pid..] -> the last one's status
     (? (two? args)
        (foldl (\ a p (: st (wait (sh-int p))
                         _ (sh-bgnote S (sh-int p))
                         (charm? st ? st 127)))
               0 args)
        (each (keys (S 'sh-jobs))
              (\ nn (: j ((S 'sh-jobs) nn)
                       (? !j 0 (each (j 0) wait,
                                pull (S 'sh-jobs) nn 0)))),
         0))
   ; `ev EXPR..`: one love form in this image, its truth the status. not named `love`,
   ; which would shadow the binary
   (sh-loveb S args)
     (: q (two? args && <args = "-n")
        src (sh-unwords (? q >args args))
        (? !#src 0
           (: r (sh-loveval S src)
              (? (<r = 'err) (sh-lovesay >r)
                 (: v >r
                    _ (? q 0 (puts (sh-lovetext v + "\n")))
                    (? v 0 1))))))
   (sh-sigof s)                                 ; TERM, SIGTERM or 15 -> 15; () for none
     (: b (s @ ("SIG" + (n && 0 < #n)) n s)
        (sh-digits? b ? (sh-int b) (sh-signum b @ 0 () n n)))
   ; kill: a job is its group when it leads one, else each pid. a signal sent to
   ; ourselves is drained here, or the next rearm's sigclear delivers it unhandled
   (sh-killb S args)
     (:- (go args 15)
      (fail m) (say err ("lush: kill: " + m + "\n"), 1)
      (targets w)                              ; the pids a word names, or ()
        (? (0 < #w && w 0 = 37)
           (: j ((S 'sh-jobs) (sh-jobspec S w)) (? !j () (sh-jc? S 0) [-<(j 0)] (j 0)))
           (sh-digits? w) [(sh-int w)]
           (1 < #w && w 0 = 45 && sh-digits? (snip w 1 #w)) [-(sh-int (snip w 1 #w))]
           ())
      (one w sig ok)
        (: ts (targets w)
           (? !(two? ts) (fail (w + ": no such job or pid"))
              (foldl (a \ p \ (? !(still p sig) a (fail ("cannot kill " + w)))) ok ts)))
      (send ws sig) (: r (foldl (a \ w \ one w sig a) 0 ws) _ (sh-sigdrain S 0) r)
      (named a sig) (? (charm? sig) (go >a sig) (fail (<a + ": invalid signal")))
      (go a sig)
        (? !(two? a) (fail "usage: kill [-s SIG | -SIG] PID|%JOB..")
           (<a = "-l") (puts (sh-unwords (map cap sh-signums) + "\n"), 0)
           (<a = "-s") (? (two? >a) (named >a (sh-sigof <>a)) (fail "-s wants a signal"))
           (<a = "--") (send >a sig)
           (1 < #<a && <a 0 = 45) (named a (sh-sigof (snip <a 1 #<a)))
           (send a sig)))
   (sh-octal? s) (: (go k) (? (#s <= k) (0 < #s) (48 <= s k <= 55) (go (k + 1)) 0) (go 0))
   (sh-oct s) (: (go k a) (? (#s <= k) a (go (k + 1) (a * 8 + (s k - 48)))) (go 0 0))
   (sh-umaskb S args)
     (: s? (two? args && <args = "-S")
        a (? s? >args args)
        cur (: m (umask 0) _ (umask m) m)
        (oct n) (: (go k i s) (? (i < 1) s (go (k // 8) (i - 1) (string (48 + (k % 8)) + s)))
                   (go n 4 ""))
        (tri v) ((v & 4 ? "r" "") + (v & 2 ? "w" "") + (v & 1 ? "x" ""))
        (sym n) (: p (511 - (n & 511))
                   ("u=" + tri (p // 64) + ",g=" + tri ((p // 8) % 8) + ",o=" + tri (p % 8)))
        (? !(two? a) (puts ((? s? (sym cur) (oct cur)) + "\n"), 0)
           (sh-octal? <a) (umask (sh-oct <a), 0)
           (cmderr S ("umask: " + <a + ": octal mode wanted"))))
   ; getopts: the place inside a clustered word is ours, dropped when OPTIND moves
   (sh-getoptsb S args)
     (? !(two? >args) (cmderr S "getopts: usage: getopts OPTSTRING NAME [ARG..]")
        (: os <args nm <>args
           quiet (0 < #os && os 0 = 58)
           spec (? quiet (snip os 1 #os) os)
           ws (? (two? >>args) >>args (S 'sh-pos))
           ind (sh-vget S "OPTIND" @ (_ . v) (? (sh-digits? v) (sh-int v) 1) 1)
           k (? (ind = (S 'sh-optind)) (S 'sh-optk) 0)
           (at i) (? (0 < i <= #ws) (ws (i - 1)) ())
           (leave i j) (pin S 'sh-optind i, pin S 'sh-optk j, (sh-setvar S) "OPTIND" (show i))
           (noarg _) (pull (S 'sh-vars) "OPTARG" 0, setenv "OPTARG" ())
           (done _) (leave ind 0, (sh-setvar S) nm "?", noarg 0, 1)
           (moan m c) (? quiet (sh-setvar S "OPTARG" (string c))
                         (noarg 0, say err ("lush: getopts: " + m + " -- " + string c + "\n")))
           w (at ind)
           (? !(string? w) (done 0)
              (k = 0 && w = "--") (leave (ind + 1) 0, (sh-setvar S) nm "?", noarg 0, 1)
              (k = 0 && (#w < 2 || w 0 != 45)) (done 0)
              (: k1 (? k k 1)
                 c (w k1)
                 pos (: (go i) (? (#spec <= i) () (spec i = c && c != 58) i (go (i + 1))) (go 0))
                 more? (k1 + 1 < #w)                 ; letters left in this word
                 (step _) (? more? (leave ind (k1 + 1)) (leave (ind + 1) 0))
                 (? !(charm? pos) (sh-setvar S nm "?", moan "illegal option" c, step 0, 0)
                    (pos + 1 < #spec && spec (pos + 1) = 58)      ; the letter takes an argument
                      (? more? (sh-setvar S "OPTARG" (snip w (k1 + 1) #w), (sh-setvar S) nm (string c), leave (ind + 1) 0, 0)
                         (string? (at (ind + 1))) (sh-setvar S "OPTARG" (at (ind + 1)), (sh-setvar S) nm (string c), leave (ind + 2) 0, 0)
                         (? quiet (sh-setvar S nm ":", (sh-setvar S) "OPTARG" (string c))
                            (sh-setvar S nm "?", moan "option requires an argument" c),
                          leave (ind + 1) 0, 0))
                    (sh-setvar S nm (string c), noarg 0, step 0, 0))))))
   (sh-readonlyb S args)
     (? (!(two? args) || <args = "-p")
        (each (sort (keys (S 'sh-rovars)))
              (nm \ puts ("readonly " + nm + (sh-vget S nm @ (_ . v) ("='" + v + "'") "") + "\n")), 0)
        (foldl (a \ w \ (: nm (w @ ((n && 0 < #n) + "=" + v) (sh-setvar S n v, n) w)
                          _ (pin (S 'sh-rovars) nm 1)
                          a))
               0 args))
   ; alias text is lexed at each use as words alone, so an operator is refused here
   (sh-aliassay S ws) (each ws (w \ puts ("alias " + w + "='" + (S 'sh-aliases) w + "'\n")))
   (sh-aliasb S args)
     (? !(two? args) (sh-aliassay S (sort (keys (S 'sh-aliases))), 0)
        (foldl (a \ w \ (w @ ((n && 0 < #n) + "=" + v)
                          (? (two? (sh-aliasws S v)) (pin (S 'sh-aliases) n v, a)
                             (say err ("lush: alias: " + n + ": words only, no operators\n"), 1))
                          (? (string? ((S 'sh-aliases) w)) (sh-aliassay S [w], a)
                             (say err ("lush: alias: " + w + ": not found\n"), 1))))
               0 args))
   (sh-unaliasb S args)
     (? (two? args && <args = "-a") (sh-tclear (S 'sh-aliases), 0)
        !(two? args) (cmderr S "unalias: usage: unalias [-a] NAME..")
        (foldl (a \ w \ (? (string? ((S 'sh-aliases) w)) (pull (S 'sh-aliases) w 0, a)
                           (say err ("lush: unalias: " + w + ": not found\n"), 1)))
               0 args))
   (sh-timesb S _)
     (: (pad3 n) (: t (show n) ((snip "000" 0 (3 - #t)) + t))
        (fmt us) (: ms (us // 1000) s (ms // 1000)
                    (show (s // 60) + "m" + show (s % 60) + "." + pad3 (ms % 1000) + "s"))
        (line r) (? (two? r) (puts (fmt <r + " " + fmt <>r + "\n")) (puts "0m0.000s 0m0.000s\n"))
        _ (line (rusage 0)) _ (line (rusage -1))
        0)
   (sh-hashb S args)
     (? (two? args && <args = "-r") (sh-tclear (S 'sh-hashc), 0)
        !(two? args) (each (sort (keys (S 'sh-hashc))) (w \ puts (w + "=" + >((S 'sh-hashc) w) + "\n")), 0)
        (foldl (a \ w \ two? (sh-whichp S w) ? a (say err ("lush: hash: " + w + ": not found\n"), 1))
               0 args))
   ; ulimit rows: letter, label, unit, rlimit resource, unit bytes
   sh-ulims '((99 "core file size" "blocks" 4 512) (100 "data seg size" "kbytes" 2 1024)
              (102 "file size" "blocks" 1 512) (110 "open files" "" 6 1)
              (115 "stack size" "kbytes" 3 1024) (116 "cpu time" "seconds" 0 1)
              (117 "max user processes" "" 5 1) (118 "virtual memory" "kbytes" 7 1024))
   (sh-ulimitb S args)
     (: t (tablet 0)
        (fl a lim) (? !(two? a) lim
                      (1 < #<a && <a 0 = 45) (: (cl k) (? (#<a <= k) (fl >a lim) (pin t (<a k) 1, cl (k + 1))) (cl 1))
                      (fl >a <a))
        lim (fl args ())
        hard? (t 72) soft? (t 83)
        (row c) (: (go l) (? !(two? l) () (<<l = c) <l (go >l)) (go sh-ulims))
        bad (filter (c \ !(elem c '(97 72 83)) && !(row c)) (keys t))
        (pad w s) (#s < w ? (pad w (s + " ")) s)
        (val r) (: v (rlimit (r 3) (? hard? 1 0)) (? (!(charm? v) || v < 0) "unlimited" (show (v // r 4))))
        (showrow r) (puts (pad 32 (r 1 + (? #(r 2) (" (" + r 2 + ", -" + string <r + ")") (" (-" + string <r + ")"))) + val r + "\n"))
        ls (filter t (map cap sh-ulims))        ; the letters asked, in table order
        (? (two? bad) (cmderr S ("ulimit: unknown option -" + string <bad))
           (t 97) (each sh-ulims showrow, 0)
           (: r (row (? (two? ls) <ls 102))               ; -f is the default
              (? !(string? lim) (puts (val r + "\n"), 0)
                 (: n (? (lim = "unlimited") -1 (sh-digits? lim) (sh-int lim * (r 4)) ())
                    (? !(charm? n) (cmderr S ("ulimit: " + lim + ": invalid limit"))
                       (: e (setrlimit (r 3) (? (hard? && !soft?) () n) (? (soft? && !hard?) () n))
                          (? e (cmderr S ("ulimit: cannot set " + (r 1))) 0))))))))
   ; the working directory, or $PWD once it is removed under us (cwd answers an error)
   (sh-pwd S) (: w (cwd 0) (? (string? w) w (sh-vget S "PWD" @ (_ . v) v "")))
   (sh-pwdinit S _) (: w (cwd 0) (? (string? w) (sh-setvar S "PWD" w) 0))   ; never a parent's stale $PWD
   ; cd: -L and -P alike, since chdir resolves one way
   (sh-cdopts a) (? (two? a && (<a = "-L" || <a = "-P")) (sh-cdopts >a) (two? a && <a = "--") >a a)
   (sh-cdb S args)
     (: a (sh-cdopts args)
        dash (two? a && <a = "-")
        vt (? dash (sh-vget S "OLDPWD") (two? a) (1 . <a) (sh-vget S "HOME"))
        t (? (two? vt) >vt "")
        old (sh-pwd S)
        (? !#t (say err ("lush: cd: " + (dash ? "OLDPWD" "HOME") + " not set\n"), 1)
           (chdir t) (say err ("lush: cd: " + t + "\n"), 1)
           (sh-setvar S "OLDPWD" old, (sh-setvar S) "PWD" (cwd 0),
            (? dash (puts (cwd 0 + "\n")) 0),
            0)))
   (sh-builtin S argv)
     (<argv @- (? (sh-verbbi? <argv) (cite 'verbs 'call (name <argv) >argv) 'nope)
      "exit"   (: st (? >argv (sh-int <>argv) (S 'sh-status)) (sh-leave S st))
      "cd"     (sh-cdb S >argv)
      "trap"   (sh-trapb S >argv)
      "export" (each >argv (sh-export S), 0)
      ; `command -v W`: quiet on a miss (POSIX)
      "command"
               (: a >argv
                  (? (two? a && <a = "-v")
                     (: w (two? >a ? <>a "")
                        (? (w = "") 1
                           (: v (sh-verdict S w)
                              (? (atom? v) 1 (puts ((sh-vname w v) + "\n"), 0)))))
                     (atom? a) 1
                     (sh-simple2 S a ())))         ; `command W ..` -- run W, no function lookup
      "pwd"    (puts (sh-pwd S + "\n"), 0)
      "jobs"   (each (sort (keys (S 'sh-jobs))) (n \ puts (sh-jobline n ((S 'sh-jobs) n))), 0)
      "fg"     (sh-fg S (sh-jobn S argv), (S 'sh-status))
      "bg"     (sh-bg S (sh-jobn S argv))
      ":"      0
      "true"   0
      "false"  1
      "read"   (sh-readb S >argv)
      "set"    (sh-setb S >argv)
      "shift"  (: n (? >argv (sh-int <>argv) 1)
                  (pin S 'sh-pos (drop n (S 'sh-pos)), 0))
      "unset"  (foldl (a \ nm \ (? (sh-ro? S nm) (sh-rosay S nm) (pull (S 'sh-vars) nm 0, setenv nm (), a))) 0 >argv)
      "eval"   (: c (sh-unwords >argv)
                  (? #c (: r (sh-line S c) (? (two? r) (cmderr S "eval: unexpected eof") r))
                     0))
      "ev"     (sh-loveb S >argv)
      "which"  (sh-whichb S >argv)
      "where"  (sh-whereb S >argv)
      "type"   (sh-typeb S >argv)
      "."      (sh-dotb S >argv)
      "local"  (sh-localb S >argv)
      "wait"   (sh-waitb S >argv)
      "kill"   (sh-killb S >argv)
      "umask"  (sh-umaskb S >argv)
      "getopts" (sh-getoptsb S >argv)
      "readonly" (sh-readonlyb S >argv)
      "alias"  (sh-aliasb S >argv)
      "unalias" (sh-unaliasb S >argv)
      "times"  (sh-timesb S >argv)
      "hash"   (sh-hashb S >argv)
      "ulimit" (sh-ulimitb S >argv)
      "break"    ('brk . (? >argv (sh-int <>argv) 1))
      "continue" ('cnt . (? >argv (sh-int <>argv) 1))
      "return"   ('ret . (? >argv (sh-int <>argv) (S 'sh-status))))

   ; --- the function book -------------------------------------------------------
   ; a body is a closure, so a miss is named by a mint no stored value can be
   (sh-fnof S nm) (peep (S 'sh-funcs) nm sh-nofn)
   (sh-fn? S nm) !(sh-nofn = (sh-fnof S) nm)

   ; --- stage expansion + the spawn engines ------------------------------------
   (sh-makepipes n) (? (n < 1) () (pipe 0 . sh-makepipes (n - 1)))
   (sh-flat ps) (? !ps () (<<ps . (><ps . sh-flat >ps)))
   ; a stage: ('x argv fdmap opens writes) spawns; ('a ast () () ()) forks and
   ; re-expands in the child, so its env sees its own assignments
   (sh-stagex S cmds acc)
     (? !cmds [1 (rev acc)]
        (: c <cmds
           (? !(<c = 'cmd)
              (sh-stagex S >cmds ['a c () () () . acc])
              (: pk (sh-peel (c 1) ())
                 argv (catmap (sh-fields S) >pk)
                 (? (two? <pk || atom? argv || sh-bi? <argv || (sh-fn? S) <argv || string? ((S 'sh-aliases) <argv))
                    (sh-stagex S >cmds ['a c () () () . acc])
                    (: rm (sh-rdmapx S (c 2))
                       (? (<rm = 'err) (stclean acc, rm)
                          (sh-stagex S >cmds
                                     ['x argv (rm 1) (rm 2) (rm 3) . acc]))))))))
   (stclean acc) (each acc (st \ each (st 3) close))
   ; spawn one stage. flush first: a child writes the fd straight, so what we still
   ; hold would land out of order
   (sh-spawn1 S st base allclose pg fgi)
     (flush out, flush err,
      (? (st 0 = 'x)
         (: w <(st 1)
            fm (base + (st 2))
            fk (? (sh-forkok? S (st 1) fm) (sh-forkfn S w) 0)
            (? fk
               ; ours: fork the warm heap, no exec
               (sh-fork1 S (st 1) fm allclose pg fgi)
               ((? (sh-known? S w) 0 (sh-nfsay S w fm)),
                spawnmap (sh-spawnv S (st 1)) fm allclose pg fgi)))
         ; no fork: the stage runs as a task on a copy of our state
         !(sh-forkseat? 0)
          (spawnmap ['thunk (_ \ sh-eval (sh-subtask S) (st 1) @ s (? (charm? s) s (<s @ 'ret >s 0)))]
                    base allclose pg fgi)
         (: p (fork 0)
            (? (p = 0)
               (: _ (wear (),                   ; a child wears the console: its fds are the dup2 below, and a jug is not one
                       (sh-dropcaps S) (),           ; ...and it is inside no capture of ours
                       sh-pgkid pg fgi,          ; and joins the pipeline's group
                       (sh-subjc S) (),              ; ..and runs no job control of its own
                       each base (e \ dup2 >e <e),
                       (? (sh-fd0? base) (chug in) 0),   ; a new stdin drops our read-ahead
                       each allclose (\ fd (2 < fd ? (close fd) 0)))
                  s (sh-eval S (st 1))
                  (quit (? (charm? s) s (<s @ 'ret >s 0))))
               (sh-pgdad p pg, p)))))
   ; stage 0 may lead a pgrp and take the tty, the rest join; a stage's own redirects
   ; land after the pipe wiring. lastout >= 0 takes the last stage's stdout
   (sh-spawnst S sts pipes allclose lastout i last pg fg pids)
     (? !sts (rev pids)
        (: st <sts
           base ((0 < i ? [(0 . <(pipes (i - 1)))] ())
                 + (i < last ? [(1 . >(pipes i))] (lastout < 0 ? () [(1 . lastout)])))
           pid (sh-spawn1 S st base allclose pg (? (i = 0) fg 0))
           (sh-spawnst S >sts pipes allclose lastout (i + 1) last
                       (? (pg < 0) pg (i = 0 ? pid pg)) fg (pid . pids))))
   (sh-echk S st)
     (? (charm? st && st != 0 && (S 'sh-eflag) && (S 'sh-noe) = 0 && !(S 'sh-tty))
        (sh-leave S st) st)
   ; a background job's line, with its & when the line does not end in one
   (sh-bgline S _) (: s (sh-rtrim " \t\n" (S 'sh-curline))
                    (? (0 < #s && s (#s - 1) = 38) s (s + " &")))
   (sh-pipeline S cmds bg)
     (: sx (sh-stagex S cmds ())
        (? (<sx = 'err) (cmderr S >sx)
           (: sts (sx 1)
              n (#sts - 1)
              pipes (sh-makepipes n)
              pfds (sh-flat pipes)
              ofds (catmap (st \ st 3) sts)
              wrs (catmap (st \ st 4) sts)
              allclose (pfds + ofds + map cap wrs)
              pids (sh-spawnst S sts pipes allclose (0 - 1) 0 n
                               (sh-pgm S 0) (? bg 0 (sh-fgm S 0)) ())
              (each (pfds + ofds) close,
               sh-hwrite wrs,
               (? bg
                  (: jn (sh-addjob S pids 'running (sh-bgline S 0))
                     (pin S 'sh-lastbg (last pids),      ; $!
                      (? (S 'sh-tty) (puts ("[" + show jn + "] " + sh-unwords (map show pids) + "\n")) 0),
                      0))
                  (sh-waitfg S pids (S 'sh-curline), (sh-echk S) (S 'sh-status)))))))
   ; an alias's text as a command's words (segment lists, the w tag off), or ()
   (sh-aliasws S v) (sh-lex S v @ (1 . ts) (? (all (t \ <t = 'w) ts) (map cup ts) ()) ())
   ; expand a leading alias, again on the result, until none or a repeat; () if none
   (sh-unalias S ws seen)
     (: w (two? ws ? (sh-barelit <ws) ())
        (? !(string? w) ()
           !(string? ((S 'sh-aliases) w)) ()
           (elem w seen) ()
           (: e (sh-aliasws S ((S 'sh-aliases) w) + >ws)
              r (sh-unalias S e (w . seen))
              (? (two? r) r e))))
   ; one simple command; pk is (assignments . words). an alias's own assignments are
   ; peeled again, after the line's
   (sh-simple S pk rs)
     (: e (sh-unalias S >pk ())
        (? !(two? e) (sh-simple1 S pk rs)
           (: q (sh-peel e ()) (sh-simple1 S (<pk + <q . >q) rs))))
   (sh-simple1 S pk rs)
     (: asns <pk
        _ (pin S 'sh-substat 0)          ; ahead of both expansions -- see below
        argv (catmap (sh-fields S) >pk)
        (? (atom? argv)
           ; no command name: the status is the last $( ) performed (POSIX)
           (: _ (each asns (sh-doasn S))
              st (S 'sh-substat)
              _ (pin S 'sh-status st)
              (sh-echk S st))
           (: saves (map (sh-tmpset S) asns)
              r (sh-simple2 S argv rs)
              _ (each saves sh-tmprestore)
              r)))
   ; `out` and `err` are ports that need not write fd 1 and 2, so a map moving either
   ; wears a port over the moved fd for the thunk's length
   (sh-outrs S fdmap th)
     (: ks (map cap fdmap)
        (? !(elem 1 ks || elem 2 ks) (th S)
           (: w0 (worn ())
              (port k) (elem k ks ? (dup k @ fd (nom? fd ? () [(fdopen fd)])) ())
              (keep n) (two? w0 ? (w0 n) ())
              po (port 1) pe (port 2)
              _ (wear [(keep 0) (two? po ? <po (keep 1)) (two? pe ? <pe (keep 2))])
              (mind th S (\ _ (flush out, flush err, wear w0,
                                each [po pe] (p \ two? p ? (close <p) 0)))))))
   ; run a thunk with redirects laid over our own fds, swapped back after
   (sh-withrs S rs th)
     (? (atom? rs) (th S)
        (: rm (sh-rdmap S rs)
           (? (<rm = 'err) (cmderr S >rm)
              (: fdmap (rm 1) opens (rm 2) wrs (rm 3)
                 _ (sh-hwrite wrs)
                 saves (map (e \ <e . dup <e) fdmap)
                 _ (each fdmap (e \ charm? >e ? (dup2 >e <e) (close <e)))
                 _ (each opens close)
                 s (sh-outrs S fdmap th)
                 (flush out, flush err,
                  each saves (e \ nom? >e ? (close <e) (dup2 >e <e, close >e)),
                  s)))))
   ; exec: the one builtin whose redirects stay
   (sh-execb S argv rs)
     (: rm (sh-rdmap S rs)
        (? (<rm = 'err) (cmderr S >rm)
           (: fdmap (rm 1) opens (rm 2) wrs (rm 3)
              _ (sh-hwrite wrs)
              _ (flush out) _ (flush err)          ; what we still hold is the OLD fd's
              _ (sh-keeprds S fdmap)
              _ (each fdmap (e \ charm? >e ? (dup2 >e <e) (close <e)))
              _ (each opens close)
              _ (? (sh-fd0? fdmap) (chug in) 0)       ; the old stdin's read-ahead goes with it
              (? (atom? argv) (pin S 'sh-status 0, 0)
                 ((S 'sh-subfds) || (0 < (S 'sh-online))) (sh-execkid S argv)
                 (sh-execgo S argv)))))
   ; a forkless subshell's redirects outlive the exec only to its end: each fd's first
   ; save is kept for sh-subback
   (sh-keeprds S fdmap)
     (: rs (S 'sh-subrds)
        (? (rs = 'no) 0
           (pin S 'sh-subrds
              (foldl (\ a e (? (sh-smem? <e (map cap a)) a ((<e . dup <e) . a))) rs fdmap))))
   ; a forkless subshell -- a $( ) body, an sh-oneline -- has no process of its own to
   ; replace: argv runs as a child, and its status ends the subshell
   (sh-execkid S argv)
     (: _ (flush out) _ (flush err)
        pid (? (sh-known? S <argv) (spawnmap (sh-spawnv S argv) () () (sh-pgm S 0) (sh-fgm S 0)) ())
        st (? (charm? pid) (sh-waitfg S [pid] (sh-unwords argv), S 'sh-status)
              (say err ("lush: exec: " + <argv + ": not found\n"), 127))
        (pin S 'sh-status st, sh-leave S st))
   ; an ignore survives exec: shed the shell's tty ignores, restored if exec fails
   (sh-exectty S on)
     (? (S 'sh-tty) (each [sig-int sig-quit sig-tstp sig-ttou sig-ttin] (flip signal on)) 0)
   (sh-execgo S argv)
     (: w <argv
        _ (sh-disarm S 0)                            ; the mask outlives an exec too
        _ (sh-exectty S 0)
        ig (sh-ignsigs S 0)
        _ (each ig (n \ signal n 1))                 ; trap '' rides the exec, as an ignore
        e (exec (sh-spawnv S argv))                  ; answers only when it did not happen
        _ (each ig (n \ signal n 0))
        _ (sh-exectty S 1)
        _ (sh-rearm S 0)
        st (e @ 'enoent 127 126)
        msg (st @ 127 ": not found" ": cannot exec")
        _ (say err ("lush: exec: " + w + msg + "\n"))
        _ (pin S 'sh-status st)
        (? (S 'sh-tty) st (sh-leave S st)))          ; POSIX: a script dies on it
   (sh-simple2 S argv rs)
     (: _ (? (S 'sh-xflag) (say err ("+ " + sh-unwords argv + "\n")) 0)
        fn (sh-fnof S <argv)
        (? !(sh-nofn = fn) (sh-withrs S rs (_ \ (sh-fncall S) fn argv))
           (<argv = "exec") (sh-execb S >argv rs)
           (sh-bi? <argv)
             (: b (sh-withrs S rs (_ \ (sh-builtin S) argv))
                (? (two? b) b                            ; brk/cnt/ret ride out
                   (charm? b) (pin S 'sh-status b, (sh-echk S) b)
                   b))
           (sh-selfcall? S argv)                           ; the self lane
             (: g (sh-imgfn S <argv)
                f (g 1)
                s (sh-withrs S rs (_ \ f (g 2 ? argv >argv)))
                st (? (charm? s) s 0)
                _ (pin S 'sh-status st)
                (sh-echk S st))
           (: rm (sh-rdmapx S rs)
              (? (<rm = 'err) (cmderr S >rm)
                 (: opens (rm 2) wrs (rm 3)
                    ac (opens + (map cap wrs))
                    _ (flush out) _ (flush err)      ; see sh-spawn1: the child writes the fd straight
                    ; ours, but not safe in this process: fork the warm heap
                    fk (? (sh-forkok? S argv (rm 1)) (sh-forkfn S <argv) 0)
                    ; said through the map: `nope 2> f` puts it in f
                    _ (? (fk || (sh-known? S) <argv) 0 (sh-nfsay S <argv (rm 1)))
                    pid (? fk (sh-fork1 S argv (rm 1) ac (sh-pgm S 0) (sh-fgm S 0))
                           (sh-known? S <argv) (spawnmap (sh-spawnv S argv) (rm 1) ac (sh-pgm S 0) (sh-fgm S 0))
                           ())
                    (each opens close,
                     sh-hwrite wrs,
                     (? (nom? pid) (cmderr S (<argv + ": cannot spawn"))
                        !(charm? pid) (pin S 'sh-status 127, (sh-echk S) 127)
                        (sh-waitfg S [pid] (sh-unwords argv), (sh-echk S) (S 'sh-status)))))))))
   (sh-fncall S body argv)
     (: op (S 'sh-pos)
        _ (pin S 'sh-pos >argv)
        s (body S)
        _ (pin S 'sh-pos op)
        (? (two? s && (<s = 'ret))
           (: st >s _ (pin S 'sh-status st) st)
           s))

   ; --- (sh-plan S ast) -> a plan, fired with the state it runs in, not its planner's.
   ; a plan answers its control pair rather than jumping, so fd restores all run
   (sh-zero S _) (pin S 'sh-status 0, 0)
   (sh-eval S a) (sh-plan S a S)          ; the raw-AST door: a forked stage, a line
   ; a condition (or an && || arm, or a ! body) runs with errexit off
   (sh-guarded S p)
     (: _ (pin S 'sh-noe (1 + (S 'sh-noe)))
        s (p S)
        _ (pin S 'sh-noe ((S 'sh-noe) - 1))
        s)
   (sh-plan S a)
     (? !a (S \ (S 'sh-status))
        (<a @- (S \ (cmderr S) "unknown form")
         'seq  (: p (sh-plan S (a 1)) q (sh-plan S (a 2))
                  (\ S (: s (p S) (? (two? s) s (q S)))))
         'and  (: p (sh-plan S (a 1)) q (sh-plan S (a 2))
                  (\ S (: s (sh-guarded S p) (? (two? s) s (s = 0) (q S) s))))
         'or   (: p (sh-plan S (a 1)) q (sh-plan S (a 2))
                  (\ S (: s (sh-guarded S p) (? (two? s) s (s = 0) s (q S)))))
         'not  (: p (sh-plan S (a 1))
                  (\ S (: s (sh-guarded S p)
                          (? (two? s) s
                             (: ns (s @ 0 1 0) (pin S 'sh-status ns, ns))))))
         'bg   (: b (a 1)                       ; a lone command backgrounds as a pipeline of one
                  cmds (? (<b = 'pipe) (b 1) [b])
                  (S \ (sh-pipeline S) cmds 1))
         'pipe (: cmds (a 1) (S \ (sh-pipeline S) cmds 0))
         'cmd  (: pk (sh-peel (a 1) ()) rs (a 2)
                  (\ S (sh-simple S pk rs)))
         'if   (: cls (map (c \ (sh-plan S) <c . (sh-plan S) >c) (a 1))
                  els (? (two? (a 2)) (sh-plan S (a 2)) (\ S (sh-zero S 0)))
                  (S \ (sh-if S) cls els))
         'while (: c (sh-plan S (a 1)) b (sh-plan S (a 2))
                   (S \ (sh-wloop S) 0 c b 0))
         'until (: c (sh-plan S (a 1)) b (sh-plan S (a 2))
                   (S \ (sh-wloop S) 1 c b 0))
         'for  (: nm (a 1) ws (a 2) b (sh-plan S (a 3))   ; the words re-expand each run
                  (S \ (sh-floop S) nm (catmap (sh-fields S) ws) b 0))
         ; a bodyless arm gets its zero plan here: a plan's absence cannot be tested
         'case (: w (a 1)
                  its (map (it \ <it . (? (two? >it) (sh-plan S >it) (\ S (sh-zero S 0)))) (a 2))
                  (S \ (sh-citems S) (sh-textof S w) its))
         'group (sh-plan S (a 1))
         'subsh (: b (sh-plan S (a 1)) (S \ (sh-subsh S) b))
         'fun  (: nm (a 1) b (sh-plan S (a 2))
                  (S \ (pin (S 'sh-funcs) nm b, 0)))
         'rdr  (: b (sh-plan S (a 1)) rs (a 2)
                  (S \ (sh-rdr S) b rs))))
   (sh-if S clauses els)
     (? (atom? clauses) (els S)
        (: c <clauses
           s (sh-guarded S <c)
           (? (two? s) s
              (s = 0) (>c S)
              (sh-if S >clauses els))))
   (sh-wloop S inv cond body last)
     (: s (sh-guarded S cond)
      (? (two? s) s
       (: go? (? inv (s != 0) (s = 0))
        (? !go? (pin S 'sh-status last, last)
         (: b (body S)
          (atom? b ? (sh-wloop S inv cond body b)
           (: kk <b nn >b
              (kk @- b 'brk (1 < nn ? ('brk . nn - 1) (sh-zero S ()))
                       'cnt (1 < nn ? ('cnt . nn - 1) (sh-wloop S inv cond body last))))))))))
   (sh-floop S nm fs body last)
     (? (atom? fs) (pin S 'sh-status last, last)
        (: _ (sh-setvar S nm <fs)
           b (body S)
           (two? b ?
            (: kk <b nn >b
               (kk @- b 'brk (1 < nn ? ('brk . nn - 1) (sh-zero S ()))
                        'cnt (1 < nn ? ('cnt . nn - 1) (sh-floop S nm >fs body last))))
              (sh-floop S nm >fs body b))))
   (sh-anymatch S t pats)
     (? (atom? pats) 0
        (: pm (sh-patmask S <pats)
           (? (sh-fmatch <pm >pm t) 1 (sh-anymatch S t >pats))))
   (sh-citems S t items)
     (? (atom? items) (sh-zero S ())
        (: it <items
           (? (sh-anymatch S t <it) (>it S)
              (sh-citems S t >items))))
   ; under a forkless capture a `( )` does not fork: the child would stall on the drainer
   (sh-subsh S b)
     (? ((S 'sh-subfds) || !(sh-forkseat? 0)) (sh-subhere S b)
        (: _ (flush out) _ (flush err)
           pg (sh-pgm S 0) fg (sh-fgm S 0)
           p (fork 0)
           (? (p = 0) (: _ (wear ())         ; the child's stdio is its fds, never a jug this task wears
                         _ (sh-dropcaps S ())  ; ...and it is inside no capture of ours
                         _ (sh-pgkid pg fg)  ; a ( ) is one job of the shell above: its own group
                         _ (sh-subjc S ())     ; ..and the commands in it are not jobs of anyone
                         s (b S)
                         (quit (? (charm? s) s (<s @ 'ret >s 0))))
              (nom? p) (cmderr S "cannot fork")
              (sh-pgdad p pg,
               (sh-waitfg S) [p] (S 'sh-curline), (sh-echk S) (S 'sh-status)))))
   ; minded, so a scare cannot leak the body's cwd, vars, funcs and flags into us
   (sh-subhere S b)                            ; a subshell in our own process
     (: snap (sh-subsave S ())
        s (mind b S (\ _ (sh-subback S snap)))
        st (sh-capstat s)                    ; brk/cnt do not cross a subshell either
        _ (pin S 'sh-status st)
        (sh-echk S st))
   ; a compound's trailing redirect, in-process: a `done < file` loop keeps its variables
   (sh-rdr S b rs)
     (: rm (sh-rdmap S rs)
        (? (<rm = 'err) (cmderr S >rm)
           (: fdmap (rm 1) opens (rm 2) wrs (rm 3)
              _ (sh-hwrite wrs)                       ; a heredoc body fits the pipe
              saves (map (e \ <e . dup <e) fdmap)
              _ (each fdmap (e \ charm? >e ? (dup2 >e <e) (close <e)))
              _ (each opens close)
              s (sh-outrs S fdmap b)
              _ (each saves (e \ nom? >e ? (close <e) (dup2 >e <e, close >e)))
              s)))

   ; --- command substitution. an all-external pipeline spawns onto our pipe
   (sh-capsimple S a wfd)                        ; -> pids, unwaited
     (: cmds (<a @ 'pipe (a 1) [a])
        sx (sh-stagex S cmds ())
        (<sx @ 'err (cmderr S >sx, ())
         (: sts (sx 1)
            n (#sts - 1)
            pipes (sh-makepipes n)
            pfds (sh-flat pipes)
            ofds (catmap (st \ st 3) sts)
            wrs (catmap (st \ st 4) sts)
            allclose (wfd . pfds + ofds + map cap wrs)
            pids (sh-spawnst S sts pipes allclose wfd 0 n (0 - 1) 0 ())
            (each (pfds + ofds) close, sh-hwrite wrs, pids))))
   (sh-capst sts)                              ; the last stage's status, a signal folded down
     (? (atom? sts) 1
        (last sts @ st (charm? st && 255 < st ? (st - 128) st)))
   ; --- a body's lane: 'jug a builtin into a jug, which holds only what `out` is told;
   ; 'ext all plain externals (sh-capsimple); 'sub the rest (sh-capsub). decided from
   ; syntax, before anything expands: an expansion may run a $( ) only once
   sh-purebi '("pwd" ":" "true" "false" "which" "where" "type")
   (sh-barelit w)                              ; a word that is already its own text, or ()
     (atom? w || two? >w ? ()
      (: h <w (<h @ 'lit (: t >h (!#t || t 0 = 126 || sh-anyglob t ? () t)))))
   (sh-cmdname a)                              ; a 'cmd's bare name, or () if it has none to read
     (: pk (sh-peel (a 1) ())
        (? (two? <pk) ()                       ; assignments want a subshell
           (atom? >pk) ()
           (sh-barelit <>pk)))
   (sh-extcmd? S c)                              ; a stage sh-stagex would spawn as it stands
     (<c @ 'cmd (: nm (sh-cmdname c) (? !nm () (!(sh-bi? nm) && !(sh-fn? S nm)))))
   (sh-lane S a)
     (? (<a = 'pipe) (all (sh-extcmd? S) (a 1) ? 'ext 'sub)
        (<a != 'cmd) 'sub
        (: nm (sh-cmdname a)
           (? !nm 'sub
              (sh-fn? S nm) 'sub
              (string? ((S 'sh-aliases) nm)) 'sub
              (sh-verbbi? nm || !(sh-bi? nm) && (sh-selfplain? S) nm) (atom? (a 2) ? 'jug 'sub)   ; ours to run in here
              (!(sh-bi? nm) && (sh-selfok? S) nm) 'sub      ; maybe ours, asked of the expanded call
              !(sh-bi? nm) 'ext
              (atom? (a 2) && sh-smem? nm sh-purebi) 'jug   ; a redirect wants an fd
              'sub)))
   ; wear o as stdout alone: `wear` replaces the whole triple
   (sh-wearout o)
     (: w (worn ())
        (wear [(two? w ? <w ())
                 o
                 (? (two? w && two? >w && two? >>w) <>>w ())]))
   (sh-capstat st)                             ; a plan's answer read as a $( ) status
     (? (charm? st) st
        (two? st && (<st = 'ret || <st = 'xit)) >st
        0)
   ; minded, or a scare leaves this task wearing the jug
   (sh-capjug S a)
     (: j (jug 0)
        w (worn ())
        _ (sh-wearout j)
        st (mind (_ \ (sh-guarded S) (_ \ (sh-eval S) a))   ; the body's status is the value,
                 () (_ \ wear w))                     ; ..never our errexit
        _ (pin S 'sh-substat (sh-capstat st))
        (slurp j))

   ; --- the forkless capture: the body runs here, stdout on a pipe a task drains.
   ; sh-subsave/sh-subback restore cwd, vars, funcs, positionals, $0, e/u/x and the env;
   ; jobs, fds, umask and handlers are not restored. a fork under a body closes each
   ; inherited read end and joins its drainer: unjoined, it wakes on a reused fd
   (sh-dropcaps S _)
     (each (S 'sh-subfds) (\ e (close <e, catch >e, 0)),
      pin S 'sh-subfds (),
      pin S 'sh-online 0,                      ; nor inside a line: its `exit` ends the child
      pin S 'sh-subrds 'no,                    ; ..and its exec's redirects are its own for good
      ; no parent traps but the ignored (POSIX), and a mask of those alone, or ^C could not reach it
      each (keys (S 'sh-traps)) (k \ (? (elem k (sh-igntraps S 0)) 0 (pull (S 'sh-traps) k 0))),
      (sh-disarm S) 0, (two? (sh-igntraps S 0) ? (sh-rearm S 0) 0), 0)
   ; with no fork, a subshell task's state: a copy, cleared as a fork child clears its
   ; own; the fds, signal port and dispositions stay shared
   (sh-subtask S)
     (sh-copy S @ c (pins c 'sh-subfds () 'sh-online 0 'sh-jc 0 'sh-sigport 0
                          'sh-traps (foldl (\ t k (pin t k "")) {} (sh-igntraps S 0))))
   (sh-tabsnap t) (map (k \ k . t k) (keys t))
   (sh-tabback t sn)
     (each (keys t) (k \ pull t k 0),
      each sn (e \ pin t <e >e),
      0)
   (sh-envback old)                            ; unset what appeared, then re-lay the old
     (: now (environ 0)
        (? (now = old) 0
           (each now (\ e (? (sh-smem? e old) 0
                             (: p (sh-eqpos e 0)
                                (setenv (? !p e (snip e 0 p)) ())))),
            each old (\ e (e @ ((n && 0 < #n) + "=" + v) (setenv n v) 0)),
            0)))
   (sh-subsave S _)
     (: s [(cwd 0) (sh-tabsnap (S 'sh-vars)) (sh-tabsnap (S 'sh-funcs)) (S 'sh-pos) (S 'sh-arg0)
             [(S 'sh-eflag) (S 'sh-uflag) (S 'sh-xflag)] (environ 0) (S 'sh-subrds)]
        (pin S 'sh-subrds (), s))
   (sh-subback S s)
     (: _ (chdir (s 0), sh-tabback (S 'sh-vars) (s 1), sh-tabback (S 'sh-funcs) (s 2),
              pin S 'sh-pos (s 3), pin S 'sh-arg0 (s 4))
        _ (flush out, flush err,
           each (S 'sh-subrds) (e \ nom? >e ? (close <e) (dup2 >e <e, close >e)),
           pin S 'sh-subrds (s 7))
        f (s 5)
        (pin S 'sh-eflag (f 0), pin S 'sh-uflag (f 1), pin S 'sh-xflag (f 2),
         sh-envback (s 6), 0))

   ; --- one line run as a subshell would, for a caller in this image instead of a
   ; spawned sh; sh-subsave's state is restored. -> (1 status), or () for flags not served
   (sh-oneflags fl)                            ; ("-ec") -> (1 e u x m) | () not ours; m () with no a g p
     (:- (go fl 0 0 0 ())
     (go l e u x m)
       (atom? l ? [1 e u x m]
        (: w <l n #w
         (n >= 2 && w 0 = 45 ?
          (:- (ch 1 e u x m)
           (ch k e2 u2 x2 m2)
            (n <= k ? (go >l e2 u2 x2 m2)
             (w k @ 99 (ch (k + 1) e2 u2 x2 m2)      ; c, the command marker
                   101 (ch (k + 1) 1 u2 x2 m2)
                   117 (ch (k + 1) e2 1 x2 m2)
                   120 (ch (k + 1) e2 u2 1 m2)
                   97 (ch (k + 1) e2 u2 x2 0)         ; a g p, the mode
                   103 (ch (k + 1) e2 u2 x2 1)
                   112 (ch (k + 1) e2 u2 x2 2))))))))
   ; f under mode m, sh-mflag and the word verdicts put back after; a () m or the
   ; mode already standing calls f as it is
   (sh-inmode S m f)
     (? (!(charm? m) || m = (sh-mode S) 0) (f 0)
        (: was (peep S 'sh-mflag 'no)
           _ (sh-setmode S m)
           (mind (_ \ f 0) ()
                 (\ _ (? (was = 'no) (pull S 'sh-mflag 0) (pin S 'sh-mflag was),
                       sh-tclear (S 'sh-imgc), sh-tclear (S 'sh-forkc))))))
   (sh-oneline S fl src)
     (: fs (sh-oneflags fl)
        (? (atom? fs) ()
           (: sv (sh-subsave S ())
              _ (pin S 'sh-online (1 + (S 'sh-online)), pin S 'sh-eflag (fs 1),
                 pin S 'sh-uflag (fs 2), pin S 'sh-xflag (fs 3))
              ; trap turns sh-leave's scare into the status; any other is said and fails
              r (trap (\ _ (mind (_ \ (sh-inmode S) (fs 4) (_ \ (sh-line S) src)) ()
                                 (\ _ (pin S 'sh-online ((S 'sh-online) - 1),
                                        flush out, flush err,
                                        (sh-subback S) sv))))
                      ()
                      (\ a b (a @ 'sh-exit (charm? b ? b 1)
                                (say err ";; ", print err a, say err " ",
                                   print err b, put err 10, flush err, 1))))
              [1 (? (two? r) (<r @ 'more
                                   (say err "lush: unexpected eof in a recipe line\n", 2)
                                   (charm? >r ? >r 1))
                      (charm? r) r
                      0)])))
   (sh-capsub S a)
     (: pp (pipe 0)
        (? (nom? pp) (cmderr S "cannot pipe", "")
           (: rfd <pp wfd >pp
              d (twirl (\ _ (: p (fdopen rfd) t (slurp p) (close p, t))) 0)
              _ (flush out)                    ; the bytes already in hand are the caller's
              sv (dup 1)
              _ (dup2 wfd 1)
              ; the body writes through a port, whose write parks: a raw write would
              ; block on a reader that is a task of this process
              po (fdopen (dup wfd))
              w0 (worn ())
              _ (sh-wearout po)
              caps (S 'sh-subfds)
              _ (pin S 'sh-subfds ((rfd . d) . caps))
              snap (sh-subsave S ())
              ; minded: sv and wfd are raw fds only we close. the join lands in `got`:
              ; a second catch would answer the zero point
              got (tablet 0)
              st (mind (_ \ (sh-guarded S) (_ \ (sh-eval S) a)) ()
                       (\ _ (flush out,             ; the body's bytes, before the ends go:
                               wear w0,             ; a flush parks until the drain has them
                               close po,
                               (sh-subback S) snap,
                               pin S 'sh-subfds caps,
                               ; fd 1 is a write end too: put back before eof
                               dup2 sv 1, close sv,
                               close wfd,           ; the last write end: now eof
                               pin got 0 (catch d),
                               0)))
              _ (pin S 'sh-substat (sh-capstat st))
              (got 0))))

   ; every lane leaves the body's status in sh-substat; 1 stands if it scares
   (sh-cmdsub S text)
     (: _ (pin S 'sh-substat 1)
        lx (sh-lex S text)
        (? (<lx = 'more) (cmderr S "unterminated $( ) body", "")
           (: pr (sh-parse >lx)
              (? (<pr != 'ok) (cmderr S "bad $( ) body", "")
                 !>pr (pin S 'sh-substat 0, "")           ; $( ) is a clean nothing
                 (: a >pr ln (sh-lane S a)
                    (ln @ 'jug (sh-capjug S a) 'sub (sh-capsub S a)
                     (: pp (pipe 0)
                        (? (nom? pp) ""
                           (: rfd <pp wfd >pp
                              ; guarded: the status is not an errexit trigger
                              (sh-guarded S
                                (\ _ (: pids (sh-capsimple S a wfd)
                                        _ (close wfd)
                                        o (slurp (fdopen rfd))   ; drain, then reap
                                        _ (pin S 'sh-substat
                                             (sh-capst (map wait pids)))
                                        o))))))))))))
   _ (pin sh-subeval () sh-cmdsub)
   ; sh-oneline with its stdout captured as sh-capsub does -> (status . text) | ()
   (sh-onecap S fl src)
     (? (atom? (sh-oneflags fl)) ()
        (: pp (pipe 0)
           (? (nom? pp) ()
              (: rfd <pp wfd >pp
                 d (twirl (\ _ (: p (fdopen rfd) t (slurp p) (close p, t))) 0)
                 _ (flush out)
                 sv (dup 1)
                 _ (dup2 wfd 1)
                 po (fdopen (dup wfd))
                 w0 (worn ())
                 _ (sh-wearout po)
                 caps (S 'sh-subfds)
                 _ (pin S 'sh-subfds ((rfd . d) . caps))
                 r (mind (_ \ (sh-oneline S) fl src) ()
                         (\ _ (flush out, wear w0, close po, pin S 'sh-subfds caps,
                                dup2 sv 1, close sv, close wfd, 0)))
                 (r 1 . catch d)))))

   ; --- the script lane + the line entries --------------------------------------
   (sh-lines S port buf)
     (: line (sh-getline port)
        (? (line = 'eof)
           (? #buf
              (say err "lush: unexpected eof\n", pin S 'sh-status 2, 0)
              0)
           (: full (? #buf (buf + ("\n" + line)) line)
              r (sh-line S full)
              ; a signal that came with no child up is read at the line boundary
              _ (sh-sigdrain S 0)
              (? (two? r) (sh-lines S port full)
                 (S 'sh-retf) (pin S 'sh-retf 0, 0)   ; dot-return: stop this file
                 (sh-lines S port "")))))
   (sh-parse-line S src)
     (: lx (sh-lex S src)
        (<lx @ 'more lx (sh-parse >lx)))
   (sh-eval-top S src a)
     (: _ (pin S 'sh-curline src)
        s (sh-eval S a)
        (? (charm? s) s
           ; a top-level `return` stops the file being read; a stray brk/cnt is dropped
           (two? s && (<s = 'ret))
             (pin S 'sh-retf 1, pin S 'sh-status >s, >s)
           0))
   (sh-line S src)
     (: pr (sh-parse-line S src)
        (<pr @ 'more pr
               'err (say err ("lush: " + (>pr + "\n")), pin S 'sh-status 2, 2)
               (sh-eval-top S src >pr))))
) ; module 'lush

; --- lush 🐚 the line -- prompt, history, completion, the repl loops ---
;
; line editing is bao's edlnc. ~/.lush_history appends on Enter, so a crash loses nothing.

(module 'lush
(: ; the interactive floor: a scare drops to cooked, says it, and re-prompts
   (lush-help a b)
     (raw 0, puts ";; ", putx a, puts " ", putx b, putc 10, welp a b)

   ; --- the prompt --------------------------------------------------------------
   (sh-rfind s b) (:- (go (#s - 1)) (go k)
    (? (k < 0) -1 (s k = b) k (go (k - 1))))
   (sh-vis s)                                   ; control bytes as ^X, so a name cannot talk to the terminal
     (: n #s
        (go i acc) (? (n <= i) acc
                      (: b (s i) (go (i + 1) (acc + (? (b = 127) "^?" (b < 32) ("^" + string (b + 64)) (string b))))))
        (go 0 ""))
   (sh-homely d)                                ; /home/me/x -> ~/x
     (: h ("" + (getenv "HOME")) hn #h
        (hn && hn <= #d && h = snip d 0 hn ?
         ("~" + (snip d hn #d))
         d))
   (sh-gitup d)                                 ; a .git anywhere up the walk?
     (two? (stat (d + "/.git")) ? 1
        (: k (sh-rfind d 47)
           (? (k < 1) 0 (sh-gitup (snip d 0 k)))))
   (sh-gitbr S _)
     (? (sh-gitup ("" + cwd 0))
        (: r (hark ["git" "symbolic-ref" "--short" "-q" "HEAD"])
           (<r @ 0 (sh-chomp >r) ""))
        (sh-sbhead S ("" + cwd 0)))
   ; an sb nest up the walk: its head's psid, which is the sha256 of the head file's text
   (sh-sbhead S d)
     (? (two? (stat (d + "/.sb")))
        (: f (d + "/.sb/head") g (? (two? (stat f)) f (d + "/.sb/tips")) q (open g "r")
           (? (hot? q) (: t (slurp q) _ (close q) ("sb " + snip (sha256 ("" + t)) 0 12)) ""))
        (: k (sh-rfind d 47)
           (? (k < 1) "" (sh-sbhead S (snip d 0 k)))))
   ; prompt colours, unguarded: sh-loop runs only on a tty
   sh-pen-st  "\e[31m"
   sh-pen-cwd "\e[38;5;117m"
   sh-pen-br  "\e[2m"
   sh-pen-off "\e[0m"
   (sh-prompt S _)
     (: st (S 'sh-status)
        br (sh-gitbr S 0)
        pst (st @ 0 "" (sh-pen-st + show st + " " + sh-pen-off))
        pbr (#br ? (sh-pen-br + " (" + br + ")" + sh-pen-off) "")
        (pst + sh-pen-cwd + sh-vis (sh-homely ("" + sh-pwd S)) + sh-pen-off + pbr
             + (getuid 0 @ 0 " # " " $ ")))

   ; --- history: ~/.lush_history, oldest first on disk, newest first in hand
   (sh-expl s)                                  ; string -> charlist
     (: n #s
        (go i) (i @ ^n () (s i . go (i + 1)))
        (go 0))
   (sh-histpath _) (("" + (getenv "HOME")) + "/.lush_history")
   (sh-histload S _)
     (: p (sh-histpath 0)
        (? (two? (stat p))
           (: prt (open p "r")
              (go acc)
                (: ln (sh-getline prt)
                   (? (ln = 'eof) acc
                      #ln (go (sh-expl ln . acc))
                      (go acc)))
              r (go ())
              _ (close prt)
              (take 100 r))
           ()))
   (sh-histput S ln)                              ; a new history is laid 0600: it holds secrets
     (: hp (sh-histpath 0)
        _ (? (atom? (stat hp)) (: fd (openfd hp 3) (? (charm? fd) (close fd) 0)) 0)
        o (open hp "a")
        (? (hot? o) (say o (ln + "\n"), flush o, close o) 0))

   ; --- completion: (insert . candidates) off the text left of the cursor ------
   (sh-prefix? p s) (: n #p ((n <= #s) && (p = (snip s 0 n))))
   (sh-comm2 a s)                               ; longest common prefix of two
     (: n (? (#a < #s) #a #s)
        (go i) (? ((i < n) && ((a i) = (s i))) (go (i + 1)) i)
        (snip a 0 (go 0)))
   (sh-common l) (? (atom? l) "" (foldl sh-comm2 <l >l))
   (sh-uniq l)
     (? (atom? l) l
        (? (two? >l && (<l = <>l)) (sh-uniq >l)
           (<l . sh-uniq >l)))
   (sh-verbnames _) (map string (keys (cite 'verbs 'tab)))
   (sh-cmds S w)                                  ; command candidates for prefix w
     (sh-uniq (sort (filter (sh-prefix? w) sh-binames +   ; the dispatch table itself, so none is missed
                     (? (2 = (sh-mode S) 0) () (filter (sh-prefix? w) (sh-verbnames 0))) +
                     (catmap (filter (sh-prefix? w) * readdir) (sh-pathdirs ())))))
   (sh-dirp q) (: st (stat q) (two? st && (16384 = (61440 & (st 2)))))
   (sh-unfold w)                                ; ~/x -> $HOME/x (stat wants the real path)
     (? (#w && w 0 = 126) ("" + getenv "HOME" + snip w 1 #w) w)
   (sh-fileca w)                                ; pathname candidates: glob w*, ~ refolded
     (: h ("" + (getenv "HOME"))
        w2 (sh-unfold w)
        g (sh-glob (w2 + "*") (sh-ones (#w2 + 1)))
        (? (w = w2) g
           (map (\ p ("~" + (snip p #h #p))) g)))
   (sh-wdst s)                                  ; where the word under the cursor starts
    (:- (go (#s - 1)) (go k)
     (k < 0 ? 0 (s k @- (go (k - 1)) (32 || 9 || 124 || 38 || 59 || 60 || 62) (k + 1))))
   (sh-cmdpos? s st)                            ; only spaces / a separator before it?
    (:- (go (st - 1)) (go k) (k < 0 ? 1 (s k @- 0 (32 || 9) (go (k - 1)) (124 || 38 || 59) 1)))
   (sh-complete S left)
     (: s (slurp (tap left))
        st (sh-wdst s)
        w (snip s st #s)
        (? !#w '(())
           (: cmdp (sh-cmdpos? s st && sh-rfind w 47 < 0 && w 0 != 126)
              cands (? cmdp (sh-cmds S w) (sh-fileca w))
              (? (atom? cands) '(())
                 (: com (sh-common cands)
                    ins (? (sh-prefix? w com) (snip com #w #com) "")
                    one (atom? >cands)
                    sfx (? !one ""
                           (? (!cmdp && sh-dirp (sh-unfold <cands)) "/" " "))
                    (sh-expl (ins + sfx) . cands))))))

   ; --- the loops ---------------------------------------------------------------
   (sh-cooked S buf)
     (: _ (? #buf 0 (sh-reapbg S 0))
        _ (say out (? #buf "> " (sh-pwd S + "$ ")))  _ (flush out)
        _ (pin S 'sh-inread 1)
        line (sh-getline in)
        (? (line = 'eof)
           (#buf && say err "lush: unexpected eof\n", puts "\n")
           (: full (? #buf (buf + ("\n" + line)) line)
              pr (sh-parse-line S full)
              (<pr @ 'more (sh-cooked S full)
                     'err (say err ("lush: " + (>pr + "\n")), pin S 'sh-status 2, (sh-cooked S) "")
                          (sh-eval-top S full >pr, (sh-cooked S) "")))))
   ; interactive: raw for the prompt, cooked around each command
   (sh-loop S buf hist)
     (: _ (? #buf 0 (sh-reapbg S 0))
        r (edlnc in (? #buf "> " (sh-prompt S 0)) hist (sh-complete S))
        (r @ 'eof (raw 0, puts "\n")                 ; cooked, newline, end
         (: line (slurp (tap <r)) nhist >r
            _ (? #line (sh-histput S line) 0)
            full (? #buf (buf + ("\n" + line)) line)
            pr (sh-parse-line S full)
            (<pr @ 'more (sh-loop S full nhist)
                   'err (raw 0,
                         say err ("lush: " + >pr + "\n"),
                         pin S 'sh-status 2,
                         raw 1,
                         (sh-loop S) "" nhist)
               (raw 0,                                          ; cooked for the command
                (sh-eval-top S) full >pr,
                puts "\e[?1l\e>",                             ; cursor keys and keypad normal: a child may leave them set
                raw 1,
                (sh-loop S) "" nhist))))))                    ; re-raw for the next prompt
) ; module 'lush

; --- lush 🐚 -- the entries: script, -c, flags, the interactive shell ---

(module 'lush
(: ; source a file through the line machinery, quietly absent (the rc/profile floor)
   (sh-src S path)
     (atom? (stat path) ? 0 (: p (open path "r") (sh-lines S p "", close p, 0)))
   ; a login shell reads /etc/profile then ~/.profile
   (sh-profiles S _)
     (sh-armtrap S 0,
      !(S 'sh-login) ? 0
       (sh-src S "/etc/profile", (sh-src S) ("" + getenv "HOME" + "/.profile")))
   ; sh-runtrap is a box: the exit door is written before sh-line exists
   (sh-armtrap S _) (pin sh-runtrap () sh-line)
   (sh-file S path args)
     (? (two? (stat path))
        (: _ (pin S 'sh-arg0 path, pin S 'sh-pos args, (sh-profiles S) 0)
           p (open path "r")
           (sh-lines S p "", close p, (sh-fire-exit S) 0, quit (S 'sh-status)))
        (say err ("lush: " + path + ": not found\n"), quit 127))
   (sh-c S cmd rest)                              ; -c CMD [name [args..]], POSIX
     (: _ (pin S 'sh-arg0 (two? rest ? <rest "lush"),
           pin S 'sh-pos >rest,
           (sh-profiles S) 0)
        r (sh-line S cmd)
        ((two? r ? (say err "lush: unexpected eof\n", pin S 'sh-status 2) 0),
         (sh-fire-exit S) 0, quit (S 'sh-status)))
   ; a flag word, bundled (`sh -ec CMD`, as make writes) -> (1 c? rest) | ()
   (sh-flagw S a rest)
     (:- (go 1 0) n #a (go k c?)
      (n <= k ? [1 c? rest]
       (a k @
          99 (go (k + 1) 1)
          97 (pin S 'sh-mflag 0, go (k + 1) c?)    ; -a autonomous
          103 (pin S 'sh-mflag 1, go (k + 1) c?)   ; -g gregarious
          112 (pin S 'sh-mflag 2, go (k + 1) c?)   ; -p precarious
          101 (pin S 'sh-eflag 1, go (k + 1) c?)
          117 (pin S 'sh-uflag 1, go (k + 1) c?)
          120 (pin S 'sh-xflag 1, go (k + 1) c?))))
   sh-usage "usage: sh [-aegpuxc] [--login] [-c CMD [NAME [ARG..]]] [FILE [ARG..]]
  -c CMD            run CMD
  -e                leave on a failing command
  -u                an unset name is an error
  -x                trace what runs
  -a, --autonomous  our verbs before PATH
  -g, --gregarious  our verbs after PATH (the default)
  -p, --precarious  PATH alone, ours never inserted
  --login           a login shell: the profiles are read
with no mode flag, LUSHFLAGS' last a, g or p sets the mode; `set --autonomous` (and
--gregarious, --precarious) changes it in a running shell
no file and no -c is a shell: a repl on a tty, cooked script off stdin otherwise"
   (sh-main1 S args)
     (sh-snapign S 0,                           ; first: what our caller had turned off
      sh-pwdinit S 0,
      pin S 'sh-mflag (sh-envflag S 0),    ; the mode: LUSHFLAGS' now, a flag word's below
      sh-args S args)
   (sh-args S args)                              ; the argv walk
     (? !args (sh1 S 0)
        (: a <args
           (a @- (sh-file S a >args)
            "--login" (pin S 'sh-login 1, (sh-args S) >args)
              (a && charm? (sh-modes a)) (pin S 'sh-mflag (sh-modes a), (sh-args S) >args)
              ; the long forms only: -h is `set -h` in every shell, and -v is `set -v`
              "--help" (puts (sh-usage + "\n"), flush out, quit 0)
              "--version"
               (puts (uvers "lush" + "\n"), flush out, quit 0)
              ; -- names a file that starts with a dash
              "--" (two? >args ? (sh-file S <>args >>args) (sh1 S 0))
              (a && 1 < #a && a 0 = 45)
               (sh-flagw S a >args @ fw (?- (sh-args S (fw 2))
                (atom? fw) (say err ("lush: " + a + ": invalid option\n"), flush err, quit 2)
                (fw 1) (fw 2 @ r (r ? (sh-c S <r >r) (say err "lush: -c needs a command\n", quit 2))))))))
   ; the outside entries, each a fresh shell
   (sh-main args) (sh-main1 (sh-new 0) args)
   (sh _) (: S (sh-new 0) (sh-pwdinit S 0, sh1 S 0))
   ; the interactive entry: ignore the tty's job signals; (raw 1) answers () on a tty,
   ; else cooked. the floor is heard first, so a broken rc scares back to the prompt
   (sh1 S _) (: ok (each [sig-int sig-quit sig-tstp sig-ttou sig-ttin] (flip signal 1), raw 1)
             (? !ok
                (: _ (heard () ? () (hear lush-help))
                   _ (pin S 'sh-tty 1)
                   erc ("" + getenv "ENV")
                   rc (erc || "" + getenv "HOME" + "/.lushrc")
                   _ (raw 0) _ (sh-profiles S 0) _ (sh-src S rc) _ (raw 1)
                   (sh-loop S "" (sh-histload S 0)))
                (sh-profiles S 0, (sh-cooked S) ""))))

; --- run only when this file is the program. "sh.l" is not a fire name, so a
; `-l sh.l -e "(sh 0)"` load stays quiet. a dash-led name (login(1)'s mark) is a login shell
(: _ (cite 'verbs 'enlist 'sh sh-main ['login], cite 'verbs 'enlist 'lush sh-main ['login])
   bn (cite 'path 'pbase)
   s (cite 'verbs 'fire ["lush" "lush.l" "sh"])
   (two? s ? (: w (bn <s)
              (sh-main (#w && w 0 = 45 ? ("--login" . >s) >s)))))
) ; module 'lush
