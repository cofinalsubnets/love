; lush 🐚, assembled: the shell state + job control, the lexer, the grammar, the
; glob, the word expander, the engine, the repl loops, then the entry + seat --
; each part a (module 'lush form in cat order, so a later part reads an earlier
; one. no brackets in any of them: the runtime supplies the layer.

; --- lush 🐚 job control -- the shell state + the v3 job machinery ---
; the shell ignores the tty's job signals ((sh _) installs that; spawn's child side
; puts them back), so ^C/^Z reach only the foreground command. a ^Z stop comes back
; from `wait` as 256+sig, above every exit status, and the job parks in `sh-jobs`:
; n -> (pids state cmd), state 'stopped | 'running. a trailing & runs the pipeline
; unwaited as a 'running job. the signal numbers are Linux's, the repo's home ABI.
; also here: the shared floor (sh-int sh-unwords) and the shell state.

(module 'lush
; the syscall doors this shell drives, taken off the module by value: a splice would
; not survive the trip, since lush's entries are called from a foreign chain and a
; global name reads the live book, so what is in scope at the call decides. the seat
; doors (spawn, wait, fork, pipe, dup, still, ttyfg, environ ..) are absent because a
; seat shadows those on the book.
(: chdir (cite 'posix 'chdir)      chmod (cite 'posix 'chmod)
   close (cite 'posix 'close)      cwd (cite 'posix 'cwd)
   mkdir (cite 'posix 'mkdir)      open (cite 'posix 'open)
   openfd (cite 'posix 'openfd)    readdir (cite 'posix 'readdir)
   readlink (cite 'posix 'readlink) rmdir (cite 'posix 'rmdir)
   selfpath (cite 'posix 'selfpath) stat (cite 'posix 'stat)
   sigclear (cite 'posix 'sigclear) sigfd (cite 'posix 'sigfd)
   sigign? (cite 'posix 'sigign?)  sigtake (cite 'posix 'sigtake)

   sig-int 2 sig-quit 3 sig-tstp 20 sig-cont 18 sig-ttou 22 sig-ttin 21
   sh-jobs (tablet 0)
   sh-njob {0}
   sh-tty {0}                                  ; 1 = interactive: jobs get their own pgrp + the tty
   sh-login {0}                                ; 1 = a login shell (--login, or a -argv0 seat): profiles read
   ; interactive spawns lead a fresh process group (pg 0) and the first stage takes the
   ; terminal (fg 1) -- a stop to an orphaned group is discarded, so ^Z wants its own
   ; group. the cooked/non-tty lane keeps the in-shell pgrp (-1).
   (sh-pgm _) (sh-tty () ? 0 -1)
   (sh-fgm _) (sh-tty () ? 1 0)
   sh-status {0}                               ; $?: the last foreground status
   sh-substat {0}                              ; the last $( )'s status -- ambient because
                                               ; expansion sits between sh-cmdsub and the reader
   sh-curline {0}                              ; the source line under eval (job display)
   sh-vars (tablet 0)                          ; shell variables (name -> value; export promotes)
   sh-funcs (tablet 0)                         ; functions (name -> the PLANNED body)
   ; --- trap: the action for a condition, and the door it leaves through -------
   ; sh-traps holds condition -> action text; sh-runtrap is the evaluator, pinned at
   ; load (the action is shell source only the engine can read). sh-trapped guards the
   ; exit action against an `exit` inside it, which would re-enter sh-leave and run the
   ; cleanup twice. exit leaves here; a signal condition rides the sigfd lane below.
   sh-traps (tablet 0)
   sh-runtrap {0}
   sh-trapped {0}
   ; --- the signal lane: a trapped condition, delivered ------------------------
   ; sigfd blocks what it watches and queues it to an fd, so a caught INT becomes a
   ; datum; armed only while a signal trap exists. drained, never parked on: `wait` is a
   ; 1ms yielding poll, so a non-blocking sigtake between polls sees the signal and
   ; POSIX's rule -- the action runs when the foreground command completes -- is free.
   ; the numbers are Linux's; USR1 USR2 CHLD TSTP want an ISA/OS table on a BSD.
   sh-sigport {0}                              ; the signalfd port, or 0
   sh-signums '(("HUP" 1) ("INT" 2) ("QUIT" 3) ("ABRT" 6) ("USR1" 10) ("USR2" 12)
                ("PIPE" 13) ("ALRM" 14) ("TERM" 15) ("CHLD" 17) ("CONT" 18) ("TSTP" 20))
   (sh-signum nm)
    ((: (g l) (l @- 0 (e . u) (<e = nm ? <>e (g u)))) sh-signums)
   (sh-signame n)
    ((: (g l) (two? l ?  (: e <l (<>e = n ? <e (g >l)))))
     sh-signums)
   ; every trapped condition that is a signal -- exit leaves by its own door
   (sh-sigconds _) (filter (!= "EXIT") (keys sh-traps))
   ; a signal ignored on entry cannot be trapped (POSIX), and no error is owed for
   ; trying. snapshotted at sh-main, before the interactive entry sets ignores of its
   ; own, or the shell reads its own hand as the caller's.
   sh-igno {0}
   (sh-snapign _)
    (pin sh-igno () (filter (nm \ sh-signum nm @ n (n && sigign? n)) (map cap sh-signums)))
   (sh-ignored? nm) (sh-igno () @ l (two? l && any (= nm) l))
   ; clear, then arm: sigfd's sigprocmask is a SIG_BLOCK and accumulates, and closing
   ; the fd does not unblock -- so empty the mask first and re-block the live set.
   (sh-rearm _)
     (: cs (sh-sigconds 0)
        ns (filter (!= 0) (map sh-signum cs))
        (sh-sigport () && close (sh-sigport ()),
         pin sh-sigport () 0,
         sigclear 0,
         two? ns ? (: p (sigfd ns) (? (hot? p) (pin sh-sigport () p) 0)),
         0))
   (sh-disarm _)                               ; a forked child inherits neither
     (sh-sigport () && close (sh-sigport ()),
      pin sh-sigport () 0, sigclear 0, 0)
   ; read every queued signal and run what each one traps. the action's own status
   ; does not become $? -- the command's does, exactly as at the exit door.
   (sh-fire-sig n)
     (: nm (sh-signame n)
        a (? (string? nm) (peep sh-traps nm "") "")
        (? #a
           (: st (sh-status ()) _ ((sh-runtrap ()) a) _ (pin sh-status () st) 0)
           0))
   (sh-sigdrain _) (sh-sigport () @ p
    (? !p 0 ((: (g _) (: ev (sigtake p) (one? ev ? 0 (sh-fire-sig <ev, g 0)))) 0)))
   ; POSIX: the exit action runs with $? as it stood and the shell still exits on
   ; that; only an explicit `exit` inside the action changes it, through sh-leave.
   (sh-fire-exit _)
     (: a (peep sh-traps "EXIT" "")
        (? ((0 = (sh-trapped ())) && #a)
           (: st (sh-status ())
              (pin sh-trapped () 1, (sh-runtrap ()) a, pin sh-status () st, 0))
           0))
   sh-nofn (mint 0)                            ; that plan is a closure, so peep names its absence
   sh-pos {0}                                  ; the positionals, a list of strings
   sh-arg0 {0}                                 ; $0 (the script path, or the shell)
   sh-eflag {0} sh-uflag {0} sh-xflag {0}      ; set -e / -u / -x
   sh-gflag (tablet 0)                         ; -g: gregarious, PATH decides (1), or autonomous (0); empty until sh-main pins it
   sh-lastbg {0}                               ; $!: the last background pid
   ; ambient on purpose, never a parameter: the guard is a dynamic extent every
   ; re-entry reads, and a plan parameter would have to cross the word expansion.
   sh-noe {0}                                  ; errexit guard depth (conds, && || arms)
   ; ambient for the same reason: the forkless $( ) captures this shell is inside,
   ; innermost first, each a (read-end . drainer) pair -- and that emptiness is the
   ; question `exit` asks (inside one it folds to ('xit . st)). a fork inherits the
   ; drainer and would eat its parent's bytes, so it drops them first (sh-dropcaps).
   sh-subfds {0}
   sh-online {0}                               ; nesting depth of sh-oneline: a line run here for a
                                               ; caller in this image, so `exit` ends the line not us
   ; the three exit doors -- `exit`, errexit (sh-echk), set -u on an unset name -- end
   ; the shell, innermost first: under a $( ) capture the capture (a pair the plan
   ; machinery rides out), under an sh-oneline the line (by scare, since set -u fires
   ; from a word expansion with no pair to hand back), otherwise the process.
   (sh-leave st)
    (? (sh-subfds ()) ('xit . st)
       (0 < (sh-online ())) (scare 'sh-exit st)
       (sh-fire-exit 0, quit st))
   sh-retf {0}                                 ; a top-level `return` landed: sh-lines stops its file (dot-return)

   ; --- read one line (cooked): bytes until \n; 'eof at immediate EOF. here on
   ; the shared floor: eval's `.`/read builtins and the loops all drink from it
   (sh-getline port) (see port @ c (? (c < 0) 'eof (c = 10) "" (string c + sh-rest port)))
   (sh-rest port)    (see port @ c (? (c < 0) ""   (c = 10) "" (string c + sh-rest port)))

   (sh-unwords ws) (foldl (\ a w (? #a ((a + " ") + w) w)) "" ws)
   (sh-addjob pids state cmd)
    (1 + sh-njob () @ n (pin sh-njob () n, pin sh-jobs n [pids state cmd], n))
   (sh-jobline n j)
    ("[" + show n + "] " + show (j 1) + "  " + j 2 + "\n")
   (sh-stopped? sts) (foldl (\ a x (? a a (charm? x && 255 < x))) 0 sts)
   ; wait a foreground job; a stop registers + reports it instead of hanging the prompt
   (sh-waitfg pids cmd)
     (: sts (map wait pids)
        _   (sh-sigdrain 0)                            ; POSIX: after the command, not during
        _   (? (sh-tty ()) (ttyfg 0) 0)                ; the shell takes the terminal back
        _   (pin sh-status ()                          ; $?: the last stage; a stop folds to 128+sig
             (: st (last sts) (? (charm? st && 255 < st) (st - 128) (charm? st) st 127)))
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
     (glean 0 @ r (two? r ? (sh-bgnote <r, sh-reapbg 0) 0))
   ; job addressing: "fg 2" by number, bare "fg" the latest
   ; string membership: elem tests identity (uninterned strings never hit)
   (sh-smem? x l) (? (one? l) 0 (x = <l ? 1 (sh-smem? x >l)))
   (sh-int s) (sh-intl s 0 0)
   (sh-intl s i a) (? (i = #s) a (sh-intl s (i + 1) ((a * 10) + ((s i) - 48))))
   (sh-lastjob _) (foldl (a \ k \ a < k ? k a) 0 (keys sh-jobs))
   (sh-jobn argv) (? >argv (sh-int <>argv) (sh-lastjob 0))
   (sh-fg n)
     (: j (sh-jobs n)
        (? !j (puts "fg: no such job\n", 0)
           (: pids (j 0) cmd (j 2)
              (pull sh-jobs n 0,
               (? (sh-tty ()) (ttyfg <pids) 0),        ; the job's group gets the terminal first
               each pids (p \ still p sig-cont),
               sh-waitfg pids cmd))))
   (sh-bg n)
     (: j (sh-jobs n)
        (? !j (puts "bg: no such job\n", 0)
           (each (j 0) (\ p (still p sig-cont)),
            pin sh-jobs n [(j 0) 'running (j 2)],
            puts (sh-jobline n (sh-jobs n)),
            0))))
) ; module 'lush

; --- lush 🐚 the lexer -- one line (or a joined continuation) to tokens ---
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
;     ('lov . text)        ${( form )}: a love form evaluated in this image at
;                          expansion; text is the reader's own extent (sh-lovep).
;                          one field always -- never IFS-split, never globbed
;   ('op . o)            | || & && ; ;; ( ) and "nl" (a newline is a separator,
;                        not whitespace)
;   ('rd . (ion . o))    a redirect: < > >> >& <& glued or spaced; ion is the
;                        io-number out of band -- () default, (n) attached.
;                        a heredoc lexes as op "<h" whose target word is the
;                        body: << collects lines to the delimiter and rewrites --
;                        'EOF' lands ('sq . body), a bare EOF ('dq . (sh-dollarize
;                        body)) so $ expands and nothing splits; <<- strips tabs.
;                        eval feeds the target through a pipe (rdmap's "<h" lane).
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
   ; a (payload . j) answer is read by kind (two?), never by truth: an empty payload
   ; nets zero, so `!r` would call a finished parse unfinished and ask PS2 for a line.
   ; the scanners step over a ${( .. )} and never through one -- inside it ' is a sigil
   ; and not a quote, so a shell-quoting walk finds the closer in the wrong place.
   (sh-love3? s n i) (i + 2 < n && s i = 36 && s (i + 1) = 123 && s (i + 2) = 40)
   ; $( body ): balanced parens, blind to quoted ones -> j past ) | ()
   ; a per-byte loop: no helper closures, for the reason spelled out on `lx` below
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
   ; $(( .. )): the arithmetic extent, i past the two ( -- scan to the ) closing the
   ; inner one, then demand a ) after it. a failed match is not an error but the other
   ; reading: `$((cd a) && b)` is a command substitution whose first word opens a
   ; subshell. -> (text . j past the second )) | ()
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
   ; ${(FORM)}: the love arm, i at the ( -- the reader is the scanner. `sound` speaks
   ; love's lexical law, which no shell scanner does, and what it leaves unread
   ; measures the extent, so the form's end is the reader's own answer.
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
                ; ${( -- the extent comes off the reader, never off sh-brace, which
                ; counts a } inside a love "" or after a ; and cuts in the wrong place
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
          (? (i = n) (rev (addl cur segs))
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
   ; vop word text -> segs, quote-aware: ${x:-"a b"} carries its quotes as 'sq/'dq
   ; segments, so a quoted glob char masks inert in ${v#pat}. heredoc bodies stay on
   ; sh-dollarize (no quote removal); an unterminated quote falls to a literal char.
   (sh-wordize s)
     (: n #s
        (addl cur segs) (#cur ? (('lit . cur) . segs) segs)
        ; ".." inner: $ ` live, \ escapes $ ` \ ", " closes -> (segs . j) | ()
        (dq i cur segs)
         (i != n ? (: b (s i) (b @
          34 (rev (addl cur segs) . i + 1)
          (92 && i + 1 < n && (sh-btesc? (s (i + 1)) || s (i + 1) = 34))
           (dq (i + 2) (cur + string (s (i + 1))) segs)
          36 (sh-dol s n (i + 1) @
              ('dollar . j) (dq j (cur + "$") segs)
              (sg . j)      (dq j "" (sg . addl cur segs))
                            (dq (i + 1) (cur + "$") segs))
          96 (sh-bt s n (i + 1) "" @
              (t . j) (dq j "" (('sub . t) . addl cur segs))
                      (dq (i + 1) (cur + string b) segs))
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
              36 (sh-dol s n (i + 1) @
                  ('dollar . j) (go j (cur + "$") segs)
                  (sg . j)      (go j "" (sg . addl cur segs))
                                (go (i + 1) (cur + "$") segs))
              96 (sh-bt s n (i + 1) "" @
                  (t . j) (go j "" (('sub . t) . addl cur segs))
                          (go (i + 1) (cur + string b) segs))
              (go (i + 1) (cur + string b) segs))))
        (go 0 "" ()))

   ; --- heredoc collection ------------------------------------------------------
   ; the delimiter, right after << : 'EOF' / "EOF" (quoted: body literal) or a
   ; bare run -> (quoted delim . j) | ()
   (sh-hddelim s n i)
     (i != n ?
      (s i @
       (b @ (39 || 34))
        (:- (go (i + 1) "")
         (go j acc) (? (j = n) ()
                       (s j = b) (1 . acc . j + 1)
                       (go (j + 1) (acc + string (s j)))))
        (: (bare? x) !(lx-ws? x || elem x '(10 124 38 59 60 62 40 41))
           (go j acc) (j < n && bare? (s j) ? (go (j + 1) (acc + string (s j))) (acc . j))
           r (go i "")
         (#<r ? (0 . r)))))
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
           (started || two? sg ? (('w . rev sg) . toks) toks))
      ; substitute each heredoc placeholder word with its collected body
      (fixw t bods)
        (<t = 'w && two? >t && <<>t = 'hd ?
         (: e (sh-alook bods ><>t)
          ('w . (<e ? [('sq . >e)] [('dq . sh-dollarize >e)])))
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
              36 (sh-dol s n (i + 1) @ ('dollar . j) (dq j (cur + "$") segs)
                                       (sg . j) (dq j "" (sg . addl cur segs)))
              96 (sh-bt s n (i + 1) "" @ (t . j) (dq j "" (('sub . t) . addl cur segs)))
              b (dq (i + 1) (cur + string b) segs)))
      ; hq/bods/k are the heredoc state, and only the << arms move them.
      ; no per-step helper closures here or in sh-subp / sh-brace: each runs once per
      ; byte, and four `:`-bound lambdas measured +57% instructions over a whole lex.
      ; the state rides in the parameters, which is why `op2` takes nine of them.
      (op2 i cur started segs toks hq bods k o adv)  ; flush + emit an operator
        (lx (i + adv) "" 0 () (('op . o) . fw cur started segs toks) hq bods k)
      (lx i cur started segs toks hq bods k)
        (i = n ? (fin (fw cur started segs toks) hq bods)
         (s i @ (b && lx-ws? b) (lx (i + 1) "" 0 () (fw cur started segs toks) hq bods k)
               10 (: tks (('op . "nl") . fw cur started segs toks)
                   (? (one? hq) (lx (i + 1) "" 0 () tks hq bods k)
                      (: (coll j q bs)                 ; owed bodies, in arrival order
                           (q @ (h . rest)
                              (sh-hdlines s n j (h 1) (h 3) @ (body . j2)
                                 (coll j2 rest ((h 0 . (h 2 . body)) . bs)))
                              (j . bs))
                         (coll (i + 1) (rev hq) bods @
                          (j . bs) (lx j "" 0 () tks () bs k)
                                    ('more . 'heredoc)))))
               ; a comment runs to the end of its line, never the end of the
               ; input -- the buffer is multi-line whenever PS2/'more gathered
               ; (the nl itself still lexes, so heredoc bodies keep collecting)
               (35 && !started)
                 (: (sk j) ((j < n && s j != 10) ? (sk (j + 1)) j)
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
;
; (sh-parse tokens) -> ('ok . ast) | ('more . why) | ('err . msg) -- 'more is the
; parse-level PS2 protocol: a dangling && || |, or a compound still open. the AST:
;   ('cmd words redirs)     words each a segment list; redirs (ion op target)
;   ('pipe cmds)            two or more stages (any command kind)
;   ('and a b) ('or a b) ('seq a b) ('bg a) ('not a)
;   ('if clauses else)      clauses ((cond . body)..); else () when absent
;   ('while cond body) ('until cond body)
;   ('for name words body)  words absent -> the one word $@
;   ('case word items)      items ((patterns . body)..), patterns word-segs
;   ('group body) ('subsh body) ('fun name body) ('rdr ast redirs)
; reserved words live only at command position: pcomm answers ('stop . ts) for a
; closer (then/fi/do/done/esac/else/elif/}) and the list machinery ends the list
; there; each compound parser then expects its own closer. an empty rest is 'more.

(module 'lush
(: (tk-op? t o) (<t = 'op && >t = o)
   (tk-w? t) (<t = 'w)
   (tk-rd? t) (<t = 'rd)
   (tk-nl? t) (tk-op? t "nl")
   (skipnl ts) (ts && tk-nl? <ts ? (skipnl >ts) ts)   ; the answer is a list: not a truth value
   (skipsep ts) (two? ts && (tk-op? <ts ";" || tk-nl? <ts) ?  (skipsep >ts) ts)
   (bad? r) (one? <r)
   ; the bare text of a plain unquoted one-segment word, "" otherwise
   (litw t) (two? t && tk-w? t && two? >t && !>>t && <<>t = 'lit ? ("" + ><>t) "")
   (rw? t w) (#(litw t) && w = litw t)
   stopw '("then" "else" "elif" "fi" "do" "done" "esac" "}")
   ; the whole reserved set: stopw's closers plus the openers pcomm spells below.
   ; `type` and `command -v` read it, and POSIX has them name a reserved word.
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
     (one? ts ? [a]
      (: t <ts
         (? (tk-op? t "&") (plnext ['bg a] >ts)
            (tk-op? t ";" || tk-nl? t) (plnext a >ts)
            (a . ts))))
   (plnext a ts)
    (: ts2 (skipnl ts)
     (one? ts2 ? [a]
      (: r (plist ts2)
       (? (<r = 'stop) (a . >r)                ; a closer: the list ends here
          (bad? r) r
          ['seq a <r . >r]))))

   ; and_or: && / ||, left-assoc; newlines after the op continue the line
   (pao ts) (: r (ppipe ts) (? (bad? r) r (paomore <r >r)))
   (paomore a ts)
     (one? ts ? [a]
      (: t <ts
       (? (tk-op? t "&&") (paorhs 'and a >ts)
          (tk-op? t "||") (paorhs 'or a >ts)
          (a . ts))))
   (paorhs k a ts)
     (skipnl ts @ ts2
      (one? ts2 ? ('more . 'op)
       (ppipe ts2 @ r (bad? r ? r (paomore [k a <r] >r)))))

   ; pipeline: a leading bare ! word negates the whole thing
   (ppipe ts)
     (rw? <ts "!" ? (ppipe1 >ts @ r (bad? r ? r ['not <r . >r])) (ppipe1 ts))
   (ppipe1 ts) (pcomm ts @ r (bad? r ? r (ppmore [<r] >r)))
   (ppmore cmds ts)
     (? (ts && tk-op? <ts "|")
        (: ts2 (skipnl >ts)
           (one? ts2 ? ('more . 'op)
            (: r (pcomm ts2) (bad? r ? r (ppmore (<r . cmds) >r)))))
        ((? >cmds ['pipe (rev cmds)] <cmds) . ts))

   ; command: a compound by its reserved word, a function def, else simple
   (pcomm ts)
     (? (one? ts) ('more . 'compound)
        (: t <ts w (litw t)
           (? (sh-smem? w stopw) ('stop . ts)
              ; a closer op at command position stops the list too: a multi-line
              ; subshell's `)` (or a case item's `;;`) lands on its own line
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
        (? (one? ts2) ('more . 'compound)
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
        (? (one? ts2) ('more . 'compound)
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
     (? (one? ts) ('more . 'compound)
        (: nm (litw <ts)
           (? !#nm ('err . "for wants a name")
              (: ts2 (skipsep >ts)
                 (? (one? ts2) ('more . 'compound)
                    (rw? <ts2 "in")
                      (: (go t acc) (? (two? t && tk-w? <t)
                                       (go >t (><t . acc))
                                       (rev acc . t))
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
     (? (one? ts) ('more . 'compound)
        (: wt <ts
           (? !(tk-w? wt) ('err . "case wants a word")
              (: i (expw >ts "in" "case wants `in`")
                 (? !(charm? <i) i (pcitems >wt () >i))))))
   (pcitems w items ts)
     (: ts2 (skipnl ts)
        (? (one? ts2) ('more . 'compound)
           (rw? <ts2 "esac") (predir ['case w (rev items)] >ts2)
           (: ts3 (? (tk-op? <ts2 "(") >ts2 ts2)
              (go t acc)                          ; patterns: word (| word)*
                (? (one? t) ('more . 'compound)
                   !(tk-w? <t) ('err . "case wants a pattern")
                   (: acc2 (><t . acc) t2 >t
                      (? (two? t2 && tk-op? <t2 "|") (go >t2 acc2)
                         (two? t2 && tk-op? <t2 ")") (rev acc2 . >t2)
                         (one? t2) ('more . 'compound)
                         ('err . "case pattern wants `)`"))))
              r (go ts3 ())
              (? (one? <r) r
                 (pcbody w <r >r items)))))
   (pcbody w pats ts items)
     (: ts2 (skipnl ts)
      (? (one? ts2) ('more . 'compound)
         (tk-op? <ts2 ";;") (pcitems w ((pats . ()) . items) >ts2)
         (rw? <ts2 "esac") (pcitems w ((pats . ()) . items) ts2)
         (: b (plist ts2)
          (bad? b ? b
           (: ts3 (skipnl >b)
            (? (one? ts3) ('more . 'compound)
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
              (? (one? ts2) ('more . 'compound)
                 (tk-op? <ts2 ")") (predir ['subsh <b] >ts2)
                 ('err . "( wants `)`")))))
   (pfun ts)                                     ; NAME ( ) [nl] command
     (: nm (litw <ts)
        ts3 (skipnl >>>ts)
      (one? ts3 ? ('more . 'compound)
         (: b (pcomm ts3)
            (? (bad? b) b ['fun nm <b . >b]))))

   ; simple command: words + redirects, any order; a redirect eats its target
   (pcmd ts) (pcm ts () ())
   (pcm ts ws rs)
     (? (one? ts) (pcfin ts ws rs)
        (: t <ts
           (? (tk-w? t) (pcm >ts (>t . ws) rs)
              (tk-rd? t)
                (: ts2 >ts
                   (? (two? ts2 && tk-w? <ts2)
                      (pcm >ts2 ws [<>t >>t ><ts2 . rs])
                      (one? ts2) ('err . "redirect wants a target")
                      ('err . "redirect wants a word")))
              (tk-op? t "(") ('err . "unexpected parenthesis")
              (pcfin ts ws rs))))
   (pcfin ts ws rs)
     (!ws && !rs ? ('err . "expected a command")
        ['cmd (rev ws) (rev rs) . ts]))
) ; module 'lush

; --- lush 🐚 the glob -- fnmatch + pathname expansion, pure love ---
; no libc glob anywhere: readdir + stat are the whole substrate. patterns travel as
; (text . mask), the mask a parallel string of '1'/'0' bytes, '1' where the char came
; in unquoted (glob-live), '0' where a quote shielded it ('*' matches a literal star)
; -- the quoting law made byte-addressable. the matcher itself is love/boot/post.l's
; fmatch / match / anyglob / ones, bound back to their sh- names below.
;   (sh-globby? t m)       -> any live * ? [ under the mask
;   (sh-glob t m)          -> sorted matching paths | () (caller keeps the word)
; the dotfile law lives at the directory scan: a leading . matches only a pattern
; that spells the . itself.

(module 'lush
(: sh-anyglob (cite 'glob 'anyglob)   ; the sh- names stay: the expander, the engine,
   sh-fmatch (cite 'glob 'fmatch)     ; the repl, cook and kore's find all read them,
   sh-match (cite 'glob 'match)       ; some through (cite 'lush ..)
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
         (one? rest ? nxt (gwalk (map (p \ p + "/") nxt) rest))))
   ; sorted, POSIX's law for expansion -- readdir's raw order is the filesystem's,
   ; so an unsorted glob leaks the disk into anything built over it.
   (gmatches d ct cm)
     (: names (readdir (? #d d "."))
        dot (#ct && ct 0 = 46)
        (map (+ d)
         (sort (filter (nm \ (dot || nm 0 != 46) && sh-fmatch ct cm nm) names)))))
) ; module 'lush

; --- lush 🐚 the word -- expansion: segments to fields ---
;
; (sh-fields segs) -> the fields a word becomes, POSIX order: tilde, then
; parameter/command substitution, then IFS field splitting -- only over expansion
; output, never literal text -- then glob, then quote removal (free: quotes never
; entered the text). a field grows as a run list ((text . live?)..) so quoting
; survives to the glob's mask law; `seen` carries the empty-word law out of band.
; shell vars (sh-vars) sit over the environment, the positionals and specials
; ($@ $* $# $? $$ $0-9) live here, and "$@" in quotes fields one positional each.
; ${x:-y} and kin ride ('vop . (name op text)), text re-entering through sh-wordize
; at use; ('sub . text) runs through the box sh-subeval, pinned at load.

(module 'lush
(: sh-subeval {0}
   (sh-ifs? (32 || 9 || 10)) 1
   (sh-chomp t)
     (:- (go #t) (go k) (0 < k && t (k - 1) = 10 ? (go (k - 1)) (snip t 0 k)))
   (sh-runsub x) (sh-chomp ("" + sh-subeval () x))

   ; --- the love lane: a form's answer, and that answer as shell text -----------
   ; the evaluator is aboard, so nothing is spawned. (sh-loveval src) -> (1 . value) |
   ; ('err . (name . value)), cli.l's -e law: every top-level datum off the string, many
   ; folding to one application so infix reads; 'torn is an unfinished shape. the run
   ; sits under a trap, but a form calling `quit` still ends the process.
   (sh-loveval src)
     (: m (nom 0)                                 ; a fresh nom: 'torn, ==-safe
        (rdl x acc) (sound x @ 'torn       m
                               (d . rest) (rdl rest (d . acc))
                               _           (rev acc))
        ; ^m, the pin: a bare `m` in a pattern would bind and take every answer.
        ; the nom is read from outside and the arm asks for that value alone.
        ; [] is the empty chain, exactly; a `()` arm would fit anything (pat.l)
        (trap (\ _ (rdl src () @ ^m ('err . ('unfinished-form . src))
                                 [] (1 . ())
                                 ds (1 . (ev 'ev (two? >ds ? ds <ds)))))
              ()
              (\ a b ('err . (a . b)))))
   (sh-lovesay c)                                 ; a love condition, on err, status 1
     (say err "lush: love: ", print err <c, say err " ",
        print err >c, put err 10, flush err, 1)
   ; a love value as shell text: a string is its bytes, anything else prints in
   ; love notation -- so a string round-trips usable and a list reads back sayable
   (sh-lovetext v) (string? v ? v (show v))
   ; ${(FORM)} at expansion: the text, or "" and a word on err. a bad form is an empty
   ; expansion, never a torn word -- the seg is lexed already, so there is no line to fail
   (sh-lovseg src)
     (sh-loveval src @ ('err . c) (sh-lovesay c, "")
                       (_ . v)     (sh-lovetext v)
                       _            "")

   ; --- parameters: shell vars over env; specials; presence out of band --------
   ; (sh-vget nm) -> () unset | (1 . value) -- a tablet hit is a string (maybe
   ; ""), the miss the (); string? tells them apart where net cannot
   (sh-vget nm)
     (nm @ "?" (1 . show (sh-status ()))
         "#" (1 . show #(sh-pos ()))
         "$" (1 . show (getpid 0))
         "!" (1 . show (sh-lastbg ()))
         "0" (1 . ("" + (sh-arg0 ())))
        ("@" || "*") (1 . sh-unwords (sh-pos ()))
        (_ && sh-digits? nm)
          (: (go (a . u) k) (k @ 1 (1 . a) (go u (k - 1)))
             (go (sh-pos ()) (sh-int nm)))
        (: v (sh-vars nm)
           (string? v ? (1 . v) (getenv nm @ e (string? e ? (1 . e))))))
   (sh-vval nm)
    (sh-vget nm @ (_ . u) u
      (sh-uflag () ?
        (say err ("lush: " + (nm + ": unbound\n")),
         sh-tty () || sh-leave 2),
       ""))
   (sh-setvar nm v)                             ; an exported name stays exported
    (string? (getenv nm) ? (setenv nm v) (pin sh-vars nm v))

   ; --- $(( .. )): POSIX shell arithmetic --------------------------------------
   ; signed integer expressions over shell variables, C's operators and precedence, by
   ; one precedence-climbing walk. every step answers (value . index past) or () for
   ; "not that", so a bad expression unwinds without a raise. a name's value is
   ; arithmetic text, not a number -- `x=1+1` makes $((x*2)) four -- which is what the
   ; depth cap is for. nothing here asks ? of a value: every test is against `= 0`.
   arerr {}                             ; a said complaint: the top stays quiet
   arlive {}                            ; 0 inside a branch && || ?: did not take
   (ar-bad msg) (pin arerr 0 1,
                 peep arlive 0 1 && say err ("lush: arithmetic: " + msg + "\n"),
                 ())
   ; a runtime complaint -- a value only this evaluation could know is wrong. in a
   ; branch that did not take there is none: `x != 0 && 100 / x` must not divide.
   (ar-rt msg) (peep arlive 0 1 ? (ar-bad msg) 0)
   (ar-dead th) (: old (peep arlive 0 1) v (pin arlive 0 0, th ()) (pin arlive 0 old, v))
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
   ; a name's value, as a number. unset or empty is 0 -- which is what makes the
   ; `n=$((n + 1))` tally work on its first pass.
   (ar-vval nm d)
     (: g (sh-vget nm) t (? (two? g) >g "")
        (? (0 = #t) 0 (d = 0) (ar-bad "name nesting too deep") (ar-eval t (d - 1))))
   (ar-store nm v) (: _ (sh-setvar nm (show v)) v)
   ; --- the operators. love truncates // toward zero, which is C's division; >>
   ; is C's arithmetic shift and wants the floor, so it is spelled out.
   (ar-fdiv a b) (: q (a // b) (q * b = a ? q (a < 0 ? (q - 1) q)))
   (ar-apply o a b)
     (o @ "+"  (a + b)   "-" (a - b)   "*" (a * b)
          "/"  (b = 0 ? (ar-rt "division by zero") (a // b))
          "%"  (b = 0 ? (ar-rt "division by zero") (a - b * (a // b)))
          "<<" (b < 0 ? (ar-rt "negative shift") (a * b 2))
          ">>" (b < 0 ? (ar-rt "negative shift") (ar-fdiv a (b 2)))
          "<"  (a < b ? 1 0)     "<=" (a <= b ? 1 0)
          ">"  (a > b ? 1 0)     ">=" (a >= b ? 1 0)
          "==" (a = b ? 1 0)    "!=" (a = b ? 0 1)
          "&"  (a & b) "^" (a ^ b) "|" (a | b)
          "**" (b < 0 ? (ar-rt "negative exponent") (b a))
          (ar-bad ("unknown operator " + o)))
   ; tightest last, and the master list is longest-first so `<<` is never read as a
   ; `<` at the comparison rung. ** is the one rung that associates right (2**3**2 is
   ; 512, not 64), and the only non-POSIX operator here.
   arlv '(("||") ("&&") ("|") ("^") ("&") ("==" "!=") ("<=" ">=" "<" ">")
          ("<<" ">>") ("+" "-") ("*" "/" "%") ("**"))
   ; the operator at i, read off its first byte or two: every rung asks this of every
   ; primary, so a walk over the operator list with a snip per try is most of the cost
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
   (ar-expr s n i d)
     (: i0 (ar-ws s n i)
        nv (ar-name s n i0)
        (? (one? nv) (ar-cond s n i0 d)
           (: j (ar-ws s n >nv)
              op (ar-asnop s n j)
              (? (one? op) (ar-cond s n i0 d)
               (: r (ar-expr s n >op d)
                (? (one? r) ()
                   (<op = "=") ((ar-store <nv <r) . >r)
                   (: cur (ar-vval <nv d)
                      (? !(charm? cur) ()
                         (: v (ar-apply (snip <op 0 (#<op - 1)) cur <r)
                            (charm? v ? ((ar-store <nv v) . >r) ()))))))))))
   (ar-cond s n i d)
     (: r (ar-bin s n i 0 d)
        (two? r ?
           (: j (ar-ws s n >r)
              (? !(j < n && s j = 63) r
                 (: c !(<r = 0)
                    a (c ? (ar-expr s n (1 + j) d) (ar-dead (_ \ ar-expr s n (1 + j) d)))
                    (two? a ?
                       (: j2 (ar-ws s n >a)
                          (? !(j2 < n && s j2 = 58) (ar-bad "? without :")
                             (: b (c ? (ar-dead (_ \ ar-cond s n (1 + j2) d))
                                       (ar-cond s n (1 + j2) d))
                                (two? b ? ((c ? <a <b) . >b)))))))))))
   (ar-bin s n i k d)
     (? (k >= #arlv) (ar-un s n i d)
        (: r (ar-bin s n i (1 + k) d) (? (one? r) () (ar-more s n r k d))))
   ; one more operator at this rung, left-associating. && and || do not evaluate
   ; the side they do not need -- `x = 0 || 1 / x` is the whole reason.
   (ar-more s n r k d)
     (: j (ar-ws s n >r)
        o (ar-op s n j)
        (? !(string? o) r
           !(ar-has? (arlv k) o) r
           (: j2 (j + #o)
              sc (o = "&&" || o = "||")
              rt? (o = "**")                    ; the one right-associating rung
              dead? (sc && (o = "&&" ? (<r = 0) (<r != 0)))
              nk (rt? ? k (1 + k))
              rr (dead? ? (ar-dead (\ _ (ar-bin s n j2 nk d)))
                          (ar-bin s n j2 nk d))
              (? (one? rr) ()
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
              neg (f \ ar-un s n (1 + i2) d @ (a . u) (f a . u))
              (b @ 45 (neg (v \ -v))
                   43 (ar-un s n (1 + i2) d)
                   33 (neg (= 0))
                   126 (neg (v \ -v - 1))
                   (ar-prim s n i2 d)))))
   ; ++name / --name: the new value. the postfix pair is in ar-prim, and answers
   ; the old one -- the only difference between them.
   (ar-step s n i by d)
     (: nv (ar-name s n (ar-ws s n i))
        (one? nv ? (ar-bad "++ wants a name")
         (: cur (ar-vval <nv d)
          (charm? cur ? (ar-store <nv (cur + by) . >nv)))))
   (ar-prim s n i d)
     (: i2 (ar-ws s n i)
        (? (n <= i2) (ar-bad "expression ends early")
           (s i2 = 40)
             (ar-expr s n (1 + i2) d @ (a . u)
              (ar-ws s n u @ j
               (j < n && s j = 41 ? (a . 1 + j) (ar-bad "( without )"))))
           (sh-digit? (s i2)) (: r (ar-num s n i2) (two? r ? r (ar-bad "bad number")))
           (sh-name1? (s i2))
             (: nv (ar-name s n i2)
                j (ar-ws s n >nv)
                (? (ar-at s n j "++") (ar-post <nv 1 d (2 + j))
                   (ar-at s n j "--") (ar-post <nv (0 - 1) d (2 + j))
                   (: v (ar-vval <nv d) (charm? v ? (v . >nv)))))
           (ar-bad ("unexpected " + string (s i2)))))
   (ar-post nm by d j)
    (: cur (ar-vval nm d)
     (charm? cur ? (ar-store nm (cur + by), cur . j)))
   ; the whole text, and nothing left over
   (ar-eval src d)
     (: n #src
        r (ar-expr src n 0 d)
        (two? r ? (: j (ar-ws src n >r) (j < n ? (ar-bad "trailing text") <r))))
   ; ('ari . text) -> the value as shell text. a bad expression stands for "" rather
   ; than 0, which would be wrong quietly. the text expands first (POSIX): parameter
   ; and command substitution run before an operator is read, so `$(( $(wc -c < f) %
   ; 512 ))` is one expression; a bare name survives that pass and reaches ar-vval.
   (sh-arith src)
     (: _ (pin arerr 0 0) _ (pin arlive 0 1)
        v (ar-eval (sh-voptext src) 24)
        (charm? v ? (show v)
           (peep arerr 0 0 ? 0
            (say err ("lush: arithmetic: " + src + ": syntax error\n")),
            "")))

   ; --- ${name<op>text}: the word text re-enters through sh-wordize ------------
   (sh-textof segs)                      ; segs -> one string; recurses, so not point-free
   (foldl (\ a sg (: k <sg (a + (k @ 'lit >sg 'sq >sg 'dq (sh-textof >sg) 'var (sh-vval >sg)
                                     'vop (sh-vopseg sg) 'sub (sh-runsub >sg)
                                     'ari (sh-arith >sg) 'lov (sh-lovseg >sg) "")))) "" segs)
   (sh-voptext text) (sh-textof (sh-wordize text))
   (sh-vopseg sg) (: p >sg (sh-vop (p 0) (p 1) (p 2)))
   (sh-vop nm op text)
     (op @ "len" (show #(sh-vval nm))
      (: g (sh-vget nm)
         set? (two? g)
         v (? set? >g "")
         colon (#op && op 0 = 58)
         use? (? colon (set? && #v) set?)
         o (? colon (snip op 1 #op) op)
         (o @- (sh-vstrip v o text)
          "-" (? use? v (sh-voptext text))
          "=" (? use? v (: t (sh-voptext text) _ (sh-setvar nm t) t))
          "?" (? use? v (say err ("lush: " + (nm + (": " + (? #text text "parameter not set")))),
                         put err 10,
                         sh-tty () ? "" (sh-leave 2)))
          "+" (? use? (sh-voptext text) ""))))
   ; ${v#pat} ${v##pat} ${v%pat} ${v%%pat}: short/longest prefix/suffix strip
   (sh-patmask segs)                     ; segs -> (text . mask), quotes inert
     (foldl (\ a sg (: k <sg
                       t (k @ 'lit >sg 'sq >sg 'dq (sh-textof >sg) 'var (sh-vval >sg)
                             'vop (sh-vopseg sg) 'sub (sh-runsub >sg) 'ari (sh-arith >sg)
                             'lov (sh-lovseg >sg) "")
                       live (k @ ('sq || 'dq || 'lov) "0" "1")
                       (<a + t . >a + sh-mrep #t live)))
            ("" . "") segs)
   (sh-vstrip v o text) (: pw (sh-patmask (sh-wordize text)) pt <pw pm >pw n #v (o @
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
   (skifs t i n) (i < n && sh-ifs? (t i) ? (skifs t (i + 1) n) i)
   (chunk t i n) (i < n && !(sh-ifs? (t i)) ? (chunk t (i + 1) n) i)
   ; split expansion output on IFS: chunks join the field, runs of IFS close it
   (spl t i n done runs seen)
     (? (i = n) [done runs seen]
        (? (sh-ifs? (t i))
           (spl t (skifs t i n) n (closef done runs seen) () 0)
           (: j (chunk t i n)
              (spl t j n done (addrun runs (snip t i j) 1) 1))))

   ; ".." with the $@ law: each positional its own field, edges glue
   (dqat inner st)
     (? (one? inner) st
        (: sg <inner k <sg
           d (st 0) r (st 1)
           (? (k = 'var && >sg = "@")
              (: ps (sh-pos ())
                 st2 (? (one? ps) st
                        (foldl (\ a p (: dd (a 0) rr (a 1) sn2 (a 2)
                                         (? sn2 [(rr . dd) (addrun () p 0) 1]
                                            [dd (addrun () p 0) 1])))
                               [d (addrun r (two? ps ? <ps "") 0) 1]
                               >ps))
                 (dqat >inner st2))
              (dqat >inner
                    [d (addrun r (k @ 'lit >sg
                                      'var (sh-vval >sg)
                                      'vop (sh-vopseg sg)
                                      'sub (sh-runsub >sg)
                                      'ari (sh-arith >sg)
                                      'lov (sh-lovseg >sg)
                                      "")
                                 0)
                       1]))))
   (wseg sg st)
     (: d (st 0) r (st 1) sn (st 2)
        k <sg v >sg
        (k @ 'lit [d (addrun r v 1) 1]
             'sq  [d (addrun r v 0) 1]
           ; ${(..)} is one field, quiet like "${x}": a love answer is a value, not a
           ; chomped byte stream, so nothing here splits it on IFS or globs it
             'lov [d (addrun r (sh-lovseg v) 0) 1]
           ; "": a real (seen) field even empty -- except a lone "$@" over zero
           ; positionals, which contributes nothing (dqat's glue lane sets seen)
             'dq  (dqat v [d r (two? v ? sn 1)])
             'var (sh-vval v @ t (spl t 0 #t d r sn))
             'vop (sh-vopseg sg @ t (spl t 0 #t d r sn))
             'sub (sh-runsub v @ t (spl t 0 #t d r sn))
             'ari (sh-arith v @ t (spl t 0 #t d r sn))
             st))
   (wsegs segs st) (? !segs st (wsegs >segs (wseg <segs st)))

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
   (sh-fields segs)
     (: st (wsegs (sh-tilde segs) [() () 0])
        fs (rev (closef (st 0) (st 1) (st 2)))
        (catmap sh-field1 fs)))
) ; module 'lush

; --- lush 🐚 the evaluator -- AST to processes ---
;
; (sh-line src) -> ('more . why) | status. redirects become a spawnmap fdmap
; ((childfd . srcfd)..) applied in order in the child -- POSIX's left-to-right law;
; a heredoc ("<h") is a pipe whose body pours in after the spawn (the child drains as
; we write, so size never deadlocks). the AST is planned into closures once (sh-plan)
; and the plan is what runs, so a loop body, a function and a case arm pay their kind
; tests and their assignment peel once. pipeline stages spawn; a compound, builtin,
; function or assignment-bearing stage forks instead (POSIX puts it in a subshell
; anyway), the child laying the pipe map with dup2 on itself. control flow threads
; out of band as pairs -- ('brk n) ('cnt n) ('ret st) -- loops catching brk/cnt, a
; function call ret, everything else passing them up.
; set -e rides sh-eflag with sh-noe guarding conditions and && || arms.

(module 'lush
(: ; export NAME=VAL -> setenv; export NAME promotes the shell var
   (sh-eqpos s i) (#s @ ^i () (s i @ 61 i (sh-eqpos s (i + 1))))
   (sh-export w)
     (: p (sh-eqpos w 0)
        (? !p (setenv w (sh-vval w))
           (setenv (snip w 0 p) (snip w (p + 1) #w))))

   (cmderr msg) (: _ (say err ("lush: " + (msg + "\n"))) _ (pin sh-status () 1) 1)
   ; a child that cannot exec has no voice -- only _exit(127) -- so an unfindable
   ; word is answered here, before the fork, where there is still a shell to say it
   (sh-saynf w) (say err ("lush: " + (w + ": not found\n")))
   ; the word is ours to say but the line's redirections are the child's, so
   ; `cmd 2>/dev/null` has to swallow it: the map goes over our own fds for the length
   ; of one message, as sh-withrs lays one for a builtin.
   (sh-nfsay w fm)
     (? (one? fm) (sh-saynf w)
        (: saves (map (\ e (<e . dup <e)) fm)
           _ (each fm (\ e (? (charm? >e) (dup2 >e <e) (close <e))))
           _ (sh-saynf w)
           _ (flush err)
           (each saves (\ e (? (nom? >e) (close <e) (dup2 >e <e, close >e))))))

   ; --- redirects -> the fdmap ------------------------------------------------
   ; (sh-rdmap redirs) -> (1 fdmap opens writes) | ('err . msg). opens close in the
   ; child and in the parent after spawn; writes ((wfd . body)..) are heredoc feeds,
   ; poured and closed by the parent after the spawn.
   (dfd ion d) (? (two? ion) <ion d)
   (rderr opens msg) (: _ (each opens close) ('err . msg))
   (sh-rdmap rs) (rdm rs () () ())
   (rdm rs fdmap opens writes)
     (? !rs [1 (rev fdmap) opens writes]
        (: r <rs ion (r 0) op (r 1)
           (? (op = "<h")
              (: pp (pipe 0)
                 (? (nom? pp) (rderr opens "cannot pipe")
                    (rdm >rs
                         ((dfd ion 0 . <pp) . fdmap)
                         (<pp . opens)
                         ((>pp . sh-textof (r 2)) . writes))))
              (: tf (sh-fields (r 2))
                 (? (one? tf || two? >tf) (rderr opens "ambiguous redirect")
                    (: t <tf
                       (op @ "<"
                            (: fd (openfd t 0)
                               (? (nom? fd) (rderr opens (t + ": cannot open"))
                                  (rdm >rs ((dfd ion 0 . fd) . fdmap) (fd . opens) writes)))
                          (">" || ">>")
                            (: fd (openfd t (? (op = ">") 1 2))
                               (? (nom? fd) (rderr opens (t + ": cannot open"))
                                  (rdm >rs ((dfd ion 1 . fd) . fdmap) (fd . opens) writes)))
                          (">&" || "<&")
                            (: d (dfd ion (? (op = "<&") 0 1))
                               (? (t = "-") (rdm >rs ((d . ()) . fdmap) opens writes)
                                  (sh-digits? t) (rdm >rs ((d . sh-int t) . fdmap) opens writes)
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
        (: t >h p (sh-eqpos t 0)
         (? !p ()
            !(sh-asnname? (snip t 0 p)) ()
            (snip t 0 p .  (: rest (snip t (p + 1) #t)
                            (? #rest (('lit . rest) . >segs) >segs))))))))
   (sh-peel ws acc)
     (two? ws ?
        (: a (sh-asn? <ws)
         (two? a ? (sh-peel >ws (a . acc)) (rev acc . ws)))
        (rev acc . ws))
   (sh-doasn a) (sh-setvar <a (sh-textof >a))
   (sh-tmpset a)                                ; temporary env around one command
     (: nm <a old (getenv nm)
      (setenv nm (sh-textof >a),
       nm . old))
   (sh-tmprestore e) (setenv <e >e)             ; () old unsets -- the absence lane

   sh-imgc {}                           ; word -> (1 fn whole?) | 0, decided once
   sh-imgok '("mooncc" "cc"
              "test" "[" "true" "false" "echo" "printf" "uname" "pwd"
              "basename" "dirname" "readlink" "seq" "ls" "dir" "cmp" "diff"
              "mkdir" "rmdir" "rm" "ln" "touch" "chmod" "mv" "cp" "install"
              "objcopy" "cksum" "md5sum" "sha256sum"
              ; the toolchain's other half: each needs its operands (as wants three,
              ; the rest a file), so none can sit on stdin
              "nm" "ar" "ld" "as"
              ; ..and the crew tools that answer a status instead of quitting: each is
              ; bounded by the archive or image it names, holds nothing, reads no stdin
              "tar" "libra" "fat" "mkfs.vfat" "mkdosfs")
   ; the words whose main is not spelled <word>-main. kore-main wants the whole argv
   ; (it reads its own program seat); the rest take the args after the name.
   sh-imgalias '(("mooncc" "moon-run" "moon") ("cc" "moon-run" "moon") ("kore" "kore-main")
                 ("[" "bracket-main") ("dir" "ls-main") ("objcopy" "objcopy" "holo")
                 ; the crew tools live in their own modules, not the applets' home
                 ("tar" "tar-main" "tarcmd") ("libra" "libra-main" "libra")
                 ("fat" "fat-main" "fatcmd")
                 ("mkfs.vfat" "mkfsv-main" "fatcmd") ("mkdosfs" "mkfsv-main" "fatcmd"))
   (sh-pathdirs _)
    (:- (go 0 0 ())
     p ("" + (getenv "PATH")) n #p
     (go from k acc) (? (n <= k) (rev (snip p from k . acc))
                        (p k = 58) (go (k + 1) (k + 1) (snip p from k . acc))
                        (go from (k + 1) acc)))
   (sh-slashed? w) (:- (go 0) n #w (go k) (? (n <= k) 0 (w k = 47) 1 (go (k + 1))))
   ; asked at the call: the kernel bakes this file and carries no host nif, where a
   ; top-level bind would fold the baking love's own seat in and call every tool ours.
   (sh-seat _) (lit? (cite 'posix 'selfpath) ? (selfpath 0))
   (sh-self? p) (: a (stat p) ((two? a) && (a = (stat (sh-seat ())))))
   (sh-whichp w)                                ; PATH's winner for w -> (1 path), or ()
     (? (sh-slashed? w) (two? (stat w) ? [1 w])
        (: (go l) (two? l ?
                   (: d (? #<l <l ".") p (d + ("/" + w))
                    (two? (stat p) ? [1 p] (go >l))))
           (go (sh-pathdirs ()))))
   (sh-onpath? w)                               ; is PATH's winner for w this binary
     (: (go l) (two? l ?
                (: d (? #<l <l ".") p (d + ("/" + w))
                 (two? (stat p) ? (sh-self? p) (go >l))))
        (go (sh-pathdirs ())))
   ; does this binary carry the word as a verb? the registry's own answer, PATH aside
   (sh-verbw? w) (cite 'verbs 'word @ f (lit? f ? !!(f w) 0))
   ; --- the mode: autonomous or gregarious ---------------------------------
   ; autonomous (-a, the default): a bare word naming a verb this binary carries is
   ; ours whatever PATH holds. gregarious (-g): ours only when PATH's winner stats as
   ; this binary, what a bootstrap through ambient tools wants. the flag word wins, else
   ; LUSHFLAGS' last a or g. the entry pins the box once; an unseated caller (cook, a -e)
   ; reads the environment at the ask and pins nothing, which would bake in its answer.
   (sh-envflag _) (: s ("" + (getenv "LUSHFLAGS")) n #s
                     (go k v) (n <= k ? v (go (k + 1) (s k @ 97 0 103 1 _ v)))
                     (go 0 0))
   (sh-greg? _) (peep sh-gflag () 'no @ 'no (sh-envflag 0) v v) ; peep: a pinned 0 is a verdict, not an absence
   ; would spawning this word land on the binary we are already running? the one
   ; policy question behind every in-image lane -- lush's own, and cook's.
   (sh-ours? w) (? (sh-slashed? w) (sh-self? w)
                   (sh-greg? 0) (sh-onpath? w)
                   (sh-verbw? w) 1
                   (sh-onpath? w))
   ; can this seat run the word at all? PATH answers wherever there is a seat to exec.
   ; a seat with none never execs: the kernel's spawn hands a bare word to the verb
   ; registry and a spelled path to the file at it, so both are asked here -- either
   ; alone would call half the words on such a machine missing.
   (sh-known? w) (? !(sh-seat ())
                      (? (sh-slashed? w || sh-dotl? w) (two? (stat w)) (sh-verbw? w))
                    (!(sh-greg? 0) && sh-verbw? w) 1
                    (two? (sh-whichp w)))
   ; the argv a spawn execs: autonomous mode spawns this binary under a bare verb
   ; word, so PATH decides nothing there either; anything else runs as spelled
   (sh-spawnv argv) (: w <argv exe (sh-seat ())
                       (? (!(sh-greg? 0) && string? exe && !(sh-slashed? w)
                           && !(sh-dotl? w) && sh-verbw? w)
                          (exe . argv)
                          argv))
   ; --- what would run: the answer `command -v`, `which` and `type` share -------
   ; the verdict walks sh-simple2's own ladder, so what it names is what would run:
   ; ('resw) ('fn) ('bi) ('verb path) ('path path), or () for a word nothing answers.
   ; autonomous mode's verb spawns this binary (sh-spawnv), so the seat is the path
   ; to name; a seat with none (the kernel) has only the registry, sh-known?'s reading.
   (sh-vseat? w) (sh-verbw? w && (!(sh-greg? 0) || !(sh-seat ())))
   (sh-vpath w) (sh-seat () @ s (string? s ? s w))
   (sh-verdict w)
     (? (sh-smem? w sh-resw) ['resw]
        (sh-fn? w) ['fn]
        (sh-bi? w) ['bi]
        (sh-slashed? w) (two? (stat w) ? ['path w])
        (sh-vseat? w) ['verb (sh-vpath w)]
        (: p (sh-whichp w) (two? p ? ['path <>p])))
   (sh-vname w v) (<v @ ('path || 'verb) <>v w)   ; `command -v`'s line
   (sh-whichall w)                              ; every PATH hit for w, in order
     (: (go l acc)
         (? (one? l) (rev acc)
            (: d (? #<l <l ".") p (d + ("/" + w))
               (go >l (two? (stat p) ? (p . acc) acc))))
        (go (sh-pathdirs ()) ()))

   (sh-imgask w)
     (: al (sh-assoc w sh-imgalias)
        mn (two? al ? <>al (w + "-main"))
        md (two? al && two? >>al ? (cite (nom <>>al)))   ; the row's module, or ()
        nm (intern mn)
        f0 (? (tablet? md) (md nm)                    ; the alias row named the module
              (elem nm (names ())) (ev nm)         ; a bare global
              (cite 'kore nm))                        ; else the applets' home module
        (? (sh-smem? w sh-imgok && !(sh-slashed? w) && !!f0 && sh-ours? w)
           [1 (sh-imgwrap f0 mn) (mn = "kore-main")]
           0))
   (sh-imgwrap f mn) (: ur (cite 'kore 'urun)
                        (? (mn = "moon-run" || !ur) f (ur f)))
   (sh-assoc w l) (? (one? l) 0 (w = <<l) <l (sh-assoc w >l))
   (sh-imgfn w) (peep sh-imgc w 'no @ 'no (sh-imgask w @ f (pin sh-imgc w f, f)) v v)
   sh-forkc {}                          ; word -> 1 | 0, decided once
   (sh-dotl? w) (: n #w (2 < n && snip w (n - 2) n = ".l"))
   (sh-cliline _) (? (elem 'cli-line (names ())) (ev 'cli-line) ())   ; a bare global, read at the call
   ; a seat with no fork: inle runs a process as a task (kmain's shim, the spawnmap
   ; lane below), and the fork it pins is a no-op -- so no word forks there
   (sh-forkseat? _) (? (elem 'love-os (names ())) !(elem (ev 'love-os) '(inle wasm)) 1)
   (sh-forkask w) (? (sh-slashed? w || sh-dotl? w) 0
                     !(sh-forkseat? 0) 0
                     (sh-cliline () && sh-ours? w) 1
                     0)
   (sh-forkfn w) (: v (peep sh-forkc w 'no)
                  (v != 'no ? v (: f (sh-forkask w) (pin sh-forkc w f, f))))
   ; a shell starting on a forked heap inherits its parent's verdicts, and its own
   ; mode may differ: sh-main drops them, and each word is asked again
   (sh-forget _) (: (clear t) (each (keys t) (k \ pull t k 0))
                    (clear sh-imgc, clear sh-forkc))
   (sh-fd0? fdmap) (? (one? fdmap) 0 (<<fdmap = 0) 1 (sh-fd0? >fdmap))
   (sh-forkok? av fdmap)
     (: a >av                                    ; cap is total, so a bare word reads () here
        (? (<a = "bake" || <a = "wake") 0
           (0 < #(getenv "LOVE_NO_IMAGE") && elem 'love-image (names ())) 0
           (two? a) 1
           (sh-fd0? fdmap) 1
           0))
   ; the fork child itself, shared by the pipeline stage and the simple foreground
   ; command: answers the pid in the parent (or fork's own nom), never in the child.
   ; every line of it is child hygiene -- copy the whole thing, not parts.
   (sh-fork1 argv fdmap allclose)
     (: p (fork 0)
        (?- p (p = 0)
         (: r (wear (),
               sh-dropcaps (),        ; ...and it is inside no capture of ours
            ; the five tty ignores are the shell's: a spawned child sheds them through
            ; exec, this one by hand -- or a forked `sleep` shrugs off its own ^C
            signal sig-int 0, signal sig-quit 0, signal sig-tstp 0,
            signal sig-ttou 0, signal sig-ttin 0,
            ; any scare is the child's death, never a second shell:
            ; 'leave carries the tool's status, the rest die at 1
            hear (\ a b (a @ 'leave (quit b)
                         (say err ";; ", print err a,
                          say err " ", print err b,
                          put err 10, quit 1))),
            each fdmap (e \ dup2 >e <e),
            each allclose (fd \ 2 < fd ? (close fd) 0),
            ; 0: a child has a shell already. cli-line answers the line's status, a
            ; charm, and the process answers with it; anything else is 0
            sh-cliline () argv 0)
            (quit (charm? r ? (r & 255) 0)))))

   ; --- builtins: a charm status, a control pair (brk/cnt/ret), or 'nope --------
   sh-binames '("exit" "cd" "export" "pwd" "jobs" "fg" "bg" ":" "true" "false" "command"
                "read" "set" "shift" "unset" "eval" "." "wait" "local" "exec"
                "break" "continue" "return" "ev" "trap" "which" "where" "type")
   (sh-bi? nm) (sh-smem? nm sh-binames)
   (sh-readb args)
     (: args2 (? (two? args && (<args = "-r")) >args args)
        nms (? (two? args2) args2 ["REPLY"])
        ln (sh-getline in)
        (? (ln = 'eof) 1 (: _ (sh-readset nms ln 0 #ln) 0)))
   (sh-readset nms ln i n)
     (: i2 (skifs ln i n)
        (? (one? >nms) (sh-setvar <nms (sh-rtrim (snip ln i2 n)))
           (: j (chunk ln i2 n)
              _ (sh-setvar <nms (snip ln i2 j))
              (sh-readset >nms ln j n))))
   (sh-rtrim s) (:- (go #s) (go k)
    (0 < k && sh-ifs? (s (k - 1)) ? (go (k - 1)) (snip s 0 k)))
   (sh-setb args)
     (one? args ? 0
      (: a <args
         (? (a = "--") (pin sh-pos () >args, 0)
            (1 < #a && (a 0 = 45 || a 0 = 43))
              (:- (go 1) on (a 0 = 45 ? 1 0) (go i)
               (i = #a ? (sh-setb >args)
                (a i @ 101 (pin sh-eflag () on)
                       117 (pin sh-uflag () on)
                       120 (pin sh-xflag () on),
                 go (i + 1))))
            (pin sh-pos () args, 0))))
   (sh-dotb args)
     (? (one? args) (cmderr ". wants a file")
        (: f <args
           (? (two? (stat f))
              (: _ (pin sh-retf () 0)            ; a stale interactive `return` must not clip the file
                 p (open f "r") _ (sh-lines p "") _ (close p) (sh-status ()))
              (cmderr (f + ": not found")))))
   ; trap [action] condition.. -- POSIX. no operands lists what is set, in a form that
   ; reads back in. `-` restores the default and '' ignores, both by removing the entry
   ; (nothing here delivers a signal, so the two behave alike). a condition alone is the
   ; reset form: `trap INT` is `trap - INT`. sh-cond normalises before anything is stored.
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
     (? (one? args)
        (: _ (each (keys sh-traps)
                   (\ k (puts ("trap -- '" + (peep sh-traps k "") + "' " + k + "\n"))))
           0)
        (: a2 (? (<args = "--") >args args)
           (? (one? a2) 0
              (sh-cond? <a2) (: _ (each a2 (\ w (pull sh-traps (sh-cond w) 0))) 0)
              (<a2 = "-") (: _ (each >a2 (\ w (pull sh-traps (sh-cond w) 0))) 0)
              (: act <a2
                 conds >a2
                 bad (filter (\ w !(sh-cond? w)) conds)
                 (? (two? bad)
                    (: _ (say err ("lush: trap: " + <bad + ": bad condition\n")) 1)
                    ; a condition ignored on entry is skipped, silently (POSIX). the
                    ; reset lanes are not filtered: `trap - INT` on one is a no-op
                    (: _ (each conds
                               (\ w (: c (sh-cond w)
                                       (? (sh-ignored? c) 0
                                          #act (pin sh-traps c act)
                                          (pull sh-traps c 0)))))
                       0))))))
   ; `which [-a] W ..` -- the path a spawn would land on, one line a word, spelled as
   ; `command -v` spells it. a builtin because the answer is the shell's: PATH cannot see
   ; a function, and autonomous mode does not let it decide. -a adds every other PATH
   ; hit; `where` is the same walk with the flag already on.
   (sh-whichb args)
     (: all ((two? args) && (<args = "-a"))
        (sh-which2 "which" "which [-a] name.." all (? all >args args)))
   (sh-whereb args) (sh-which2 "where" "where name.." 1 args)
   (sh-which2 nm borrow all ws)
     (: pre ("lush: " + (nm + ": "))
        (? (one? ws) (cmderr (nm + (": usage: " + borrow)))
           (foldl (\ st w
                     (: v (sh-verdict w)
                        (? (one? v)
                           (: _ (say err (pre + (w + ": not found\n"))) 1)
                           (: _ (puts ((sh-vname w v) + "\n"))
                              _ (? all (sh-whichrest w v) 0)
                              st))))
                  0 ws)))
   (sh-whichrest w v)                           ; the PATH hits the verdict did not name
     (each (sh-whichall w)
           (\ p (? ((<v = 'path) && p = (v 1)) 0 (puts (p + "\n")))))
   ; `type W ..` -- POSIX's classification, a sentence a word. the verb line names the
   ; binary the word runs in rather than a path: autonomous mode is not PATH's verdict
   (sh-typeb args)
     (? (one? args) (cmderr "type: usage: type name..")
        (foldl (\ st w
                  (: v (sh-verdict w)
                     (? (one? v)
                        (: _ (say err ("lush: type: " + (w + ": not found\n"))) 1)
                        (: _ (puts (w + ((sh-typesay v) + "\n"))) st))))
               0 args))
   (sh-typesay v)
     (<v @ 'resw " is a shell reserved word"
           'fn   " is a shell function"
           'bi   " is a shell builtin"
           'verb (" is a verb of " + (v 1))
                 (" is " + (v 1)))
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
   ; `ev EXPR..` -- the arguments join as one love form, its answer says on out and its
   ; truth bit is the status; -n answers the status alone, and the form runs in this
   ; image, so a binding it makes is there next line. not spelled `love`: a builtin
   ; would shadow its PATH twin, which wants its own process.
   (sh-loveb args)
     (: q ((two? args) && (<args = "-n"))
        src (sh-unwords (? q >args args))
        (? !#src 0
           (: r (sh-loveval src)
              (? (<r = 'err) (sh-lovesay >r)
                 (: v >r
                    _ (? q 0 (puts ((sh-lovetext v) + "\n")))
                    (? v 0 1))))))
   (sh-builtin argv)
     (<argv @- 'nope                             ; a word no builtin answers to
      "exit"   (: st (? >argv (sh-int <>argv) (sh-status ())) (sh-leave st))
      "cd"     (: t (? >argv <>argv ("" + (getenv "HOME")))
                  r (chdir t)
                  (? !r 0 (say err ("lush: cd: " + (t + "\n")), 1)))
      "trap"   (sh-trapb >argv)
      "export" (each >argv sh-export, 0)
      ; `command -v W` -- the probe every configure-shaped script opens with.
      ; sh-verdict answers, so it sees what the ladder sees; quiet on a miss (POSIX)
      "command"
               (: a >argv
                  (? ((two? a) && (<a = "-v"))
                     (: w (? (two? >a) <>a "")
                        (? (w = "") 1
                           (: v (sh-verdict w)
                              (? (one? v) 1 (puts ((sh-vname w v) + "\n"), 0)))))
                     (one? a) 1
                     (sh-simple2 a ())))         ; `command W ..` -- run W, no function lookup
      "pwd"    (puts ((cwd 0) + "\n"), 0)
      "jobs"   (each (sort (keys sh-jobs)) (n \ puts (sh-jobline n (sh-jobs n))), 0)
      "fg"     (sh-fg (sh-jobn argv), sh-status ())
      "bg"     (sh-bg (sh-jobn argv))
      ":"      0
      "true"   0
      "false"  1
      "read"   (sh-readb >argv)
      "set"    (sh-setb >argv)
      "shift"  (: n (? >argv (sh-int <>argv) 1)
                  (pin sh-pos () (drop n (sh-pos ())), 0))
      "unset"  (each >argv (nm \ (pull sh-vars nm 0, setenv nm ())), 0)
      "eval"   (: c (sh-unwords >argv)
                  (? #c (: r (sh-line c) (? (two? r) (cmderr "eval: unexpected eof") r))
                     0))
      "ev"     (sh-loveb >argv)
      "which"  (sh-whichb >argv)
      "where"  (sh-whereb >argv)
      "type"   (sh-typeb >argv)
      "."      (sh-dotb >argv)
      "local"  (sh-localb >argv)
      "wait"   (sh-waitb >argv)
      "break"    ('brk . (? >argv (sh-int <>argv) 1))
      "continue" ('cnt . (? >argv (sh-int <>argv) 1))
      "return"   ('ret . (? >argv (sh-int <>argv) (sh-status ()))))

   ; --- the function book -------------------------------------------------------
   ; a body is a plan (a closure), so two? cannot tell one from absence -- peep
   ; names the miss with a mint no stored value can pose as (spec.l's total test)
   (sh-fnof nm) (peep sh-funcs nm sh-nofn)
   (sh-fn? nm) !(sh-nofn = sh-fnof nm)

   ; --- stage expansion + the spawn engines ------------------------------------
   (sh-makepipes n) (? (n < 1) () (pipe 0 . sh-makepipes (n - 1)))
   (sh-flat ps) (? !ps () (<<ps . (><ps . sh-flat >ps)))
   ; a stage: ('x argv fdmap opens writes) spawns; ('a ast () () ()) forks --
   ; compounds, builtins, functions and assignment-bearing commands (the child
   ; re-expands, so its env sees its own assignments)
   (sh-stagex cmds acc)
     (? !cmds [1 (rev acc)]
        (: c <cmds
           (? !(<c = 'cmd)
              (sh-stagex >cmds ['a c () () () . acc])
              (: pk (sh-peel (c 1) ())
                 argv (catmap sh-fields >pk)
                 (? (two? <pk || one? argv || sh-bi? <argv || sh-fn? <argv)
                    (sh-stagex >cmds ['a c () () () . acc])
                    (: rm (sh-rdmap (c 2))
                       (? (<rm = 'err) (: _ (stclean acc) rm)
                          (sh-stagex >cmds
                                     ['x argv (rm 1) (rm 2) (rm 3) . acc]))))))))
   (stclean acc) (each acc (\ st (each (st 3) close)))
   ; spawn one stage: external -> spawnmap; anything else -> fork, the child laying
   ; the pipe map on itself (dup2), closing the plumbing, evaluating, quitting.
   ; flush first, both lanes: a builtin buffers through `out` and a child writes the
   ; fd straight, so on a shared fd what we still hold would land out of order.
   (sh-spawn1 st base allclose pg fgi)
     (: _ (flush out) _ (flush err)
        (? (st 0 = 'x)
           (: w <(st 1)
              fm (base + (st 2))
              fk (? (sh-forkok? (st 1) fm) (sh-forkfn w) 0)
              (? fk
                 ; ours: fork, no exec -- the child runs the line through cli-line on
                 ; this warm heap and quits with its status, a real pid. pg/fg are not
                 ; taken: the child stays in the shell's group, which keeps the tty.
                 (sh-fork1 (st 1) fm allclose)
                 ; foreign, or an explicit path: spawned as ever -- its 127 is the
                 ; child's own, and only the word is ours to say
                 (: _ (? (sh-known? w) 0 (sh-nfsay w fm))
                    (spawnmap (sh-spawnv (st 1)) fm allclose pg fgi))))
           (: p (fork 0)
              (? (p = 0)
                 (: _ (wear (),                   ; a child wears the console: its fds are the dup2 below, and a jug is not one
                         sh-dropcaps (),           ; ...and it is inside no capture of ours
                         each base (\ e (dup2 >e <e)),
                         each allclose (\ fd (? (2 < fd) (close fd) 0)))
                    s (sh-eval (st 1))
                    (quit (? (charm? s) s (? (<s = 'ret) >s 0))))
                 p))))
   ; stage 0 may lead a pgrp + take the tty, the rest join; base map = pipe
   ; wiring, a stage's own redirects land after. lastout >= 0 sends the last
   ; stage's stdout there (the cmdsub lane).
   (sh-spawnst sts pipes allclose lastout i last pg fg pids)
     (? !sts (rev pids)
        (: st <sts
           base (+ (? (0 < i) [(0 . <(pipes (i - 1)))] ())
                   (? (i < last) [(1 . >(pipes i))]
                      (? (lastout < 0) () [(1 . lastout)])))
           pid (sh-spawn1 st base allclose pg (? (i = 0) fg 0))
           (sh-spawnst >sts pipes allclose lastout (i + 1) last
                       (? (pg < 0) pg (? (i = 0) pid pg)) fg (pid . pids))))
   (sh-echk st)
     (? (charm? st && st != 0 && sh-eflag () && sh-noe () = 0 && !(sh-tty ()))
        (sh-leave st) st)
   (sh-pipeline cmds bg)
     (: sx (sh-stagex cmds ())
        (? (<sx = 'err) (cmderr >sx)
           (: sts (sx 1)
              n (#sts - 1)
              pipes (sh-makepipes n)
              pfds (sh-flat pipes)
              ofds (catmap (\ st (st 3)) sts)
              wrs (catmap (\ st (st 4)) sts)
              allclose (pfds + (ofds + (map cap wrs)))
              pids (sh-spawnst sts pipes allclose (0 - 1) 0 n
                               (sh-pgm 0) (? bg 0 (sh-fgm 0)) ())
              (each (pfds + ofds) close,
               sh-hwrite wrs,
               (? bg
                  (: jn (sh-addjob pids 'running ((sh-curline ()) + " &"))
                     (pin sh-lastbg () (last pids),      ; $!
                      (? (sh-tty ()) (puts ("[" + show jn + "] " + sh-unwords (map show pids) + "\n")) 0),
                      0))
                  (sh-waitfg pids (sh-curline ()), sh-echk (sh-status ())))))))
   ; one simple foreground command: assignments, function, builtin, or a spawn.
   ; pk is the peel -- (assignments . words) -- split at plan time, it is syntax
   (sh-simple pk rs)
     (: asns <pk
        _ (pin sh-substat () 0)          ; ahead of both expansions -- see below
        argv (catmap sh-fields >pk)
        (? (one? argv)
           ; no command name: POSIX says the status is the last $( ) performed, and the
           ; words expand before the assignments -- `v=$(exit 2) $(exit 3)` is 2
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
     (? (one? rs) (th ())
        (: rm (sh-rdmap rs)
           (? (<rm = 'err) (cmderr >rm)
              (: fdmap (rm 1) opens (rm 2) wrs (rm 3)
                 _ (sh-hwrite wrs)
                 saves (map (\ e (<e . dup <e)) fdmap)
                 _ (each fdmap (\ e (? (charm? >e) (dup2 >e <e)
                                       (close <e))))
                 _ (each opens close)
                 s (th ())
                 (flush out, flush err,
                  each saves (\ e (? (nom? >e) (close <e) (dup2 >e <e, close >e))),
                  s)))))
   ; `exec [CMD [ARG..]]` -- the one builtin whose redirects are not swapped back: with
   ; no CMD they become the shell's own, with one there is no shell left to swap for.
   (sh-execb argv rs)
     (: rm (sh-rdmap rs)
        (? (<rm = 'err) (cmderr >rm)
           (: fdmap (rm 1) opens (rm 2) wrs (rm 3)
              _ (sh-hwrite wrs)
              _ (flush out) _ (flush err)          ; what we still hold is the OLD fd's
              _ (each fdmap (\ e (? (charm? >e) (dup2 >e <e) (close <e))))
              _ (each opens close)
              (? (one? argv) (: _ (pin sh-status () 0) 0)
                 (sh-execgo argv)))))
   ; the five tty ignores are the shell's and an ignore survives exec: the hand
   ; hygiene sh-fork1 does for a fork, undone again if the exec did not happen
   (sh-exectty on)
     (? (sh-tty ()) (each [sig-int sig-quit sig-tstp sig-ttou sig-ttin] (flip signal on)) 0)
   (sh-execgo argv)
     (: w <argv
        _ (sh-disarm 0)                            ; the mask outlives an exec too
        _ (sh-exectty 0)
        e (exec (sh-spawnv argv))                  ; answers only when it did not happen
        _ (sh-exectty 1)
        _ (sh-rearm 0)
        st (? (e = 'enoent) 127 126)
        msg (? (st = 127) ": not found" ": cannot exec")
        _ (say err ("lush: exec: " + w + msg + "\n"))
        _ (pin sh-status () st)
        (? (sh-tty ()) st (sh-leave st)))          ; POSIX: a script dies on it
   (sh-simple2 argv rs)
     (: _ (? (sh-xflag ()) (say err ("+ " + ((sh-unwords argv) + "\n"))) 0)
        fn (sh-fnof <argv)
        (? !(sh-nofn = fn) (sh-withrs rs (\ _ (sh-fncall fn argv)))
           (<argv = "exec") (sh-execb >argv rs)
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
              (? (<rm = 'err) (cmderr >rm)
                 (: opens (rm 2) wrs (rm 3)
                    ac (opens + (map cap wrs))
                    _ (flush out) _ (flush err)      ; see sh-spawn1: the child writes the fd straight
                    ; ours, but not safe to run in this process: fork the warm heap
                    ; rather than exec a second wake -- a quit is then the child's exit
                    ; and kept state a copy. pg/fg not taken, as for a pipeline stage.
                    fk (? (sh-forkok? argv (rm 1)) (sh-forkfn <argv) 0)
                    ; said here and not at the status below: the opens close first, and
                    ; the word goes through the map -- `nope 2> f` puts it in f
                    _ (? (fk || sh-known? <argv) 0 (sh-nfsay <argv (rm 1)))
                    pid (? fk (sh-fork1 argv (rm 1) ac)
                           (sh-known? <argv) (spawnmap (sh-spawnv argv) (rm 1) ac (sh-pgm 0) (sh-fgm 0))
                           ())
                    (each opens close,
                     sh-hwrite wrs,
                     (? (nom? pid) (cmderr (<argv + ": cannot spawn"))
                        !(charm? pid) (: _ (pin sh-status () 127) (sh-echk 127))
                        (sh-waitfg [pid] (sh-unwords argv), sh-echk (sh-status ())))))))))
   (sh-fncall body argv)
     (: op (sh-pos ())
        _ (pin sh-pos () >argv)
        s (body ())
        _ (pin sh-pos () op)
        (? (two? s && (<s = 'ret))
           (: st >s _ (pin sh-status () st) st)
           s))

   ; --- the AST walk: plan once, then run ---------------------------------------
   ; (sh-plan ast) -> a plan, a thunk fired with the unit: every kind test, descent and
   ; assignment peel happens here, once instead of once per run. a plan answers its
   ; control pair rather than jumping, so the fd restores under a `break` all run.
   (sh-zero _) (: _ (pin sh-status () 0) 0)
   (sh-eval a) ((sh-plan a) ())          ; the raw-AST door: a forked stage, a line
   ; a condition (or an && || arm, or a ! body) runs with errexit off
   (sh-guarded p)
     (: _ (pin sh-noe () (1 + (sh-noe ())))
        s (p ())
        _ (pin sh-noe () ((sh-noe ()) - 1))
        s)
   ; the tag alone picks the arm; the fields stay reads, since a form's arity is its
   ; own (a 'group carries one, a 'for three) and a pattern would fix them all at once
   (sh-plan a)
     (? !a (\ _ (sh-status ()))
        (<a @- (\ _ (cmderr "unknown form"))
         'seq  (: p (sh-plan (a 1)) q (sh-plan (a 2))
                  (\ _ (: s (p ()) (? (two? s) s (q ())))))
         'and  (: p (sh-plan (a 1)) q (sh-plan (a 2))
                  (\ _ (: s (sh-guarded p) (? (two? s) s (s = 0) (q ()) s))))
         'or   (: p (sh-plan (a 1)) q (sh-plan (a 2))
                  (\ _ (: s (sh-guarded p) (? (two? s) s (s = 0) s (q ())))))
         'not  (: p (sh-plan (a 1))
                  (\ _ (: s (sh-guarded p)
                          (? (two? s) s
                             (: ns (? (s = 0) 1 0) (pin sh-status () ns, ns))))))
         'bg   (: b (a 1)                       ; a lone command backgrounds as a pipeline of one
                  cmds (? (<b = 'pipe) (b 1) [b])
                  (\ _ (sh-pipeline cmds 1)))
         'pipe (: cmds (a 1) (\ _ (sh-pipeline cmds 0)))
         'cmd  (: pk (sh-peel (a 1) ()) rs (a 2)
                  (\ _ (sh-simple pk rs)))
         'if   (: cls (map (c \ sh-plan <c . sh-plan >c) (a 1))
                  els (? (two? (a 2)) (sh-plan (a 2)) sh-zero)
                  (\ _ (sh-if cls els)))
         'while (: c (sh-plan (a 1)) b (sh-plan (a 2))
                   (\ _ (sh-wloop 0 c b 0)))
         'until (: c (sh-plan (a 1)) b (sh-plan (a 2))
                   (\ _ (sh-wloop 1 c b 0)))
         'for  (: nm (a 1) ws (a 2) b (sh-plan (a 3))   ; the words re-expand each run
                  (\ _ (sh-floop nm (catmap sh-fields ws) b 0)))
         ; a bodyless arm takes its zero at plan time: an AST tells its own absence
         ; by two?, a plan cannot
         'case (: w (a 1)
                  its (map (it \ <it . (? (two? >it) (sh-plan >it) sh-zero)) (a 2))
                  (\ _ (sh-citems (sh-textof w) its)))
         'group (sh-plan (a 1))
         'subsh (: b (sh-plan (a 1)) (\ _ (sh-subsh b)))
         'fun  (: nm (a 1) b (sh-plan (a 2))
                  (\ _ (pin sh-funcs nm b, 0)))
         'rdr  (: b (sh-plan (a 1)) rs (a 2)
                  (\ _ (sh-rdr b rs)))))
   (sh-if clauses els)
     (? (one? clauses) (els ())
        (: c <clauses
           s (sh-guarded <c)
           (? (two? s) s
              (s = 0) (>c ())
              (sh-if >clauses els))))
   (sh-wloop inv cond body last)
     (: s (sh-guarded cond)
      (? (two? s) s
       (: go? (? inv (s != 0) (s = 0))
        (? !go? (pin sh-status () last, last)
         (: b (body ())
          (one? b ? (sh-wloop inv cond body b)
           (: kk <b nn >b
              (kk @- b 'brk (1 < nn ? ('brk . (nn - 1)) (sh-zero ()))
                       'cnt (1 < nn ? ('cnt . (nn - 1)) (sh-wloop inv cond body last))))))))))
   (sh-floop nm fs body last)
     (? (one? fs) (: _ (pin sh-status () last) last)
        (: _ (sh-setvar nm <fs)
           b (body ())
           (two? b ?
            (: kk <b nn >b
               (kk @- b 'brk (1 < nn ? ('brk . (nn - 1)) (sh-zero ()))
                        'cnt (1 < nn ? ('cnt . (nn - 1)) (sh-floop nm >fs body last))))
              (sh-floop nm >fs body b))))
   (sh-anymatch t pats)
     (? (one? pats) 0
        (: pm (sh-patmask <pats)
           (? (sh-fmatch <pm >pm t) 1 (sh-anymatch t >pats))))
   (sh-citems t items)
     (? (one? items) (sh-zero ())
        (: it <items
           (? (sh-anymatch t <it) (>it ())
              (sh-citems t >items))))
   ; under a forkless capture a `( )` does not fork: the child would inherit the
   ; drainer and stall on it. outside one the fork stands and isolates fds and jobs.
   (sh-subsh b)
     (? (sh-subfds ()) (sh-subhere b)
        (: _ (flush out) _ (flush err)
           p (fork 0)
           (? (p = 0) (: _ (wear ())         ; the child's stdio is its fds, never a jug this task wears
                         _ (sh-dropcaps ())  ; ...and it is inside no capture of ours
                         s (b ())
                         (quit (? (charm? s) s (? (<s = 'ret) >s 0))))
              (nom? p) (cmderr "cannot fork")
              (: _ (sh-waitfg [p] (sh-curline ())) (sh-echk (sh-status ()))))))
   ; the roster sh-subback puts back is the subshell's contract and rides the raised
   ; way out too, or a scare leaks the body's cwd, vars, funcs and flags into us.
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
        (? (<rm = 'err) (cmderr >rm)
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

   ; --- command substitution (the expander's box) -------------------------------------
   ; an all-external pipeline spawns with the last stdout on our pipe; drain
   ; through fdopen, then reap -- any body size flows, and nothing forks.
   (sh-capsimple a wfd)                        ; -> pids, unwaited
     (: cmds (? (<a = 'pipe) (a 1) [a])
        sx (sh-stagex cmds ())
        (? (<sx = 'err) (: _ (cmderr >sx) ())
           (: sts (sx 1)
              n (#sts - 1)
              pipes (sh-makepipes n)
              pfds (sh-flat pipes)
              ofds (catmap (\ st (st 3)) sts)
              wrs (catmap (\ st (st 4)) sts)
              allclose (wfd . (pfds + (ofds + (map cap wrs))))
              pids (sh-spawnst sts pipes allclose wfd 0 n (0 - 1) 0 ())
              (each (pfds + ofds) close, sh-hwrite wrs, pids))))
   (sh-capst sts)                              ; the last stage's status, a signal folded down
     (? (one? sts) 1
        (: st (last sts) (? (charm? st && 255 < st) (st - 128) st)))
   ; --- which lane takes this body ----------------------------------------------
   ;  'jug -- a no-effect builtin: no pipe, no fd, no child. a jug holds what `out` is
   ;          told and nothing a process writes, so anything that could spawn is out.
   ;  'ext -- every stage a plain external: sh-capsimple spawns those onto the pipe,
   ;          forkless, with nothing to put back.
   ;  'sub -- everything else, in-process down a pipe a task drains (sh-capsub).
   ; the test is syntax, asked before any word expands -- an expansion runs $( ) of its
   ; own, which may happen once and only once -- hence the bare literal: no ~, no glob,
   ; the name already its own text. an unreadable name is 'sub.
   sh-purebi '("pwd" ":" "true" "false" "which" "where" "type")
   (sh-barelit w)                              ; a word that is already its own text, or ()
     (? ((one? w) || two? >w) ()
        (: h <w
           (? !(<h = 'lit) ()
              (: t >h
                 (? (!#t || t 0 = 126 || sh-anyglob t) () t)))))
   (sh-cmdname a)                              ; a 'cmd's bare name, or () if it has none to read
     (: pk (sh-peel (a 1) ())
        (? (two? <pk) ()                       ; assignments want a subshell
           (one? >pk) ()
           (sh-barelit <>pk)))
   (sh-extcmd? c)                              ; a stage sh-stagex would spawn as it stands
     (<c @ 'cmd (: nm (sh-cmdname c) (? !nm () (&& !(sh-bi? nm) !(sh-fn? nm)))))
   (sh-lane a)
     (? (<a = 'pipe) (? (all sh-extcmd? (a 1)) 'ext 'sub)
        (<a != 'cmd) 'sub
        (: nm (sh-cmdname a)
           (? !nm 'sub
              (sh-fn? nm) 'sub
              !(sh-bi? nm) 'ext
              (&& (one? (a 2)) (sh-smem? nm sh-purebi)) 'jug   ; a redirect wants an fd
              'sub)))
   ; re-seat STDOUT alone -- `wear` replaces the whole triple, so an in or err this
   ; task already wears has to ride along by name
   (sh-wearout o)
     (: w (worn ())
        (wear [(? (two? w) <w ())
                 o
                 (? (two? w && two? >w && two? >>w) <>>w ())]))
   (sh-capstat st)                             ; a plan's answer read as a $( ) status
     (? (charm? st) st
        ((two? st) && ((<st = 'ret) || (<st = 'xit))) >st
        0)
   ; the re-seat is minded: a scare under the body leaves this task wearing a jug
   ; nobody drains, and every later word lands in it instead of the terminal.
   (sh-capjug a)
     (: j (jug 0)
        w (worn ())
        _ (sh-wearout j)
        st (mind (_ \ sh-guarded (_ \ sh-eval a))   ; the body's status is the value,
                 () (_ \ wear w))                     ; ..never our errexit
        _ (pin sh-substat () (sh-capstat st))
        (slurp j))

   ; --- the forkless capture: the body runs here, down a pipe a task drains -----
   ; a child needs an fd, so this is a real pipe with our stdout dup2'd onto it; the
   ; drainer makes that safe -- a task parks on the read end and empties it as the body
   ; fills it, and every wait in this tree parks its task, not the process. a background
   ; child inside holds the write end, so the drain sees no eof until it dies.
   ; POSIX runs $( ) in a subshell and forkless there is nobody to copy the state, so
   ; sh-subsave/sh-subback do it by hand -- the roster is the contract: cwd, variables,
   ; functions, positionals, $0, the e/u/x flags, the environment. what a fork would
   ; take and this does not: a job started here stays the shell's, an fd opened here
   ; stays open, umask and the handlers stand. a fork under a body takes the drainer by
   ; copy, so shut each inherited one down first -- close the read end, then join the
   ; task; closing without joining frees the fd number for the body to reopen, and the
   ; drainer wakes onto whatever landed there.
   (sh-dropcaps _)
     (: _ (each (sh-subfds ()) (\ e (close <e, catch >e, 0)))
        _ (pin sh-subfds () ())
        ; and no trap of its parent's: POSIX resets a caught condition in a subshell.
        ; sh-disarm drops the parent's signalfd and empties the mask with it -- an
        ; inherited block would be a subshell ^C cannot reach.
        (each (keys sh-traps) (k \ pull sh-traps k 0), sh-disarm 0, 0))
   (sh-tabsnap t) (map (k \ k . t k) (keys t))
   (sh-tabback t sn)
     (: _ (each (keys t) (k \ pull t k 0))
        _ (each sn (e \ pin t <e >e))
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
     (: _ (chdir (s 0), sh-tabback sh-vars (s 1), sh-tabback sh-funcs (s 2),
              pin sh-pos () (s 3), pin sh-arg0 () (s 4))
        f (s 5)
        (pin sh-eflag () (f 0), pin sh-uflag () (f 1), pin sh-xflag () (f 2),
         sh-envback (s 6), 0))

   ; --- one line, run the way a subshell would: the door a caller in this image uses
   ; instead of spawning a shell (cook's recipe lines, where a `cd` must not reach the
   ; next) -- the forkless capture's contract with the capture taken off, so sh-capsub's
   ; roster and its holes both stand. `exit` ends the line. answers (1 status) when it
   ; ran here, () when the flags ask for something this door does not serve.
   (sh-oneflags fl)                            ; ("-ec") -> (1 e u x) | () not ours
     (:- (go fl 0 0 0)
     (go l e u x)
       (one? l ? [1 e u x]
        (: w <l n #w
         (n >= 2 && w 0 = 45 ?
          (:- (ch 1 e u x)
           (ch k e2 u2 x2)
            (n <= k ? (go >l e2 u2 x2)
             (w k @ 99 (ch (k + 1) e2 u2 x2)      ; c, the command marker
                   101 (ch (k + 1) 1 u2 x2)
                   117 (ch (k + 1) e2 1 x2)
                   120 (ch (k + 1) e2 u2 1))))))))
   (sh-oneline fl src)
     (: fs (sh-oneflags fl)
        (? (one? fs) ()
           (: sv (sh-subsave ())
              _ (pin sh-online () (1 + sh-online ()), pin sh-eflag () (fs 1),
                 pin sh-uflag () (fs 2), pin sh-xflag () (fs 3))
              ; mind puts the shell back either way, trap turns sh-leave's scare into
              ; the line's status; any other condition is a real fault, said and failed
              r (trap (\ _ (mind (_ \ sh-line src) ()
                                 (\ _ (pin sh-online () (sh-online () - 1),
                                        flush out, flush err,
                                        sh-subback sv))))
                      ()
                      (\ a b (a @ 'sh-exit (charm? b ? b 1)
                                (say err ";; ", print err a, say err " ",
                                   print err b, put err 10, flush err, 1))))
              [1 (? (two? r) (<r @ 'more
                                   (say err "lush: unexpected eof in a recipe line\n", 2)
                                   (charm? >r ? >r 1))
                      (charm? r) r
                      0)])))
   (sh-capsub a)
     (: pp (pipe 0)
        (? (nom? pp) (cmderr "cannot pipe", "")
           (: rfd <pp wfd >pp
              d (twirl (\ _ (: p (fdopen rfd) t (slurp p) (close p, t))) 0)
              _ (flush out)                    ; the bytes already in hand are the caller's
              sv (dup 1)
              _ (dup2 wfd 1)
              caps (sh-subfds ())
              _ (pin sh-subfds () ((rfd . d) . caps))
              snap (sh-subsave ())
              ; the whole seat is minded: sv and wfd are raw fds no port owns, so our
              ; own close is the only reclaim, and a scare under the body leaves the
              ; shell talking into a pipe nobody empties. the join lands in `got`
              ; because a second catch answers the zero point, so it has to happen
              ; once, in the teardown both ways out share.
              got (tablet 0)
              st (mind (_ \ sh-guarded (_ \ sh-eval a)) ()
                       (\ _ (flush out,             ; the body's bytes, before the ends go
                               sh-subback snap,
                               pin sh-subfds () caps,
                               ; fd 1 is a write end too (the dup2 above), so it has to be
                               ; put back before the drain can ever read eof
                               dup2 sv 1, close sv,
                               close wfd,           ; the last write end: now eof
                               pin got 0 (catch d),
                               0)))
              _ (pin sh-substat () (sh-capstat st))
              (got 0))))

   ; every lane leaves sh-substat holding this body's status: an assignment with no
   ; command name answers the last one performed (POSIX), and sh-fields sits between
   ; here and the reader. 1 up front is the floor the three scaring lanes keep.
   (sh-cmdsub text)
     (: _ (pin sh-substat () 1)
        lx (sh-lex text)
        (? (<lx = 'more) (: _ (cmderr "unterminated $( ) body") "")
           (: pr (sh-parse >lx)
              (? (<pr != 'ok) (cmderr "bad $( ) body", "")
                 !>pr (pin sh-substat () 0, "")           ; $( ) is a clean nothing
                 (: a >pr ln (sh-lane a)
                    (ln @ 'jug (sh-capjug a) 'sub (sh-capsub a)
                     (: pp (pipe 0)
                        (? (nom? pp) ""
                           (: rfd <pp wfd >pp
                              ; guarded: the body's status is this
                              ; substitution's value, not an errexit trigger
                              (sh-guarded
                                (\ _ (: pids (sh-capsimple a wfd)
                                        _ (close wfd)
                                        o (slurp (fdopen rfd))   ; drain, then reap
                                        _ (pin sh-substat ()
                                             (sh-capst (map wait pids)))
                                        o))))))))))))
   _ (pin sh-subeval () sh-cmdsub)

   ; --- the script lane + the line entries --------------------------------------
   (sh-lines port buf)
     (: line (sh-getline port)
        (? (line = 'eof)
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
        (<lx @ 'more lx (sh-parse >lx)))
   (sh-eval-top src a)
     (: _ (pin sh-curline () src)
        s (sh-eval a)
        (? (charm? s) s
           ; a `return` that reached the top: flag it so the reading loop stops its
           ; file (POSIX dot-return; sh-lines clears the flag). a stray brk/cnt swallows
           (two? s && (<s = 'ret))
             (pin sh-retf () 1, pin sh-status () >s, >s)
           0))
   (sh-line src)
     (: pr (sh-parse-line src)
        (<pr @ 'more pr
               'err (say err ("lush: " + (>pr + "\n")), pin sh-status () 2, 2)
               (sh-eval-top src >pr))))
) ; module 'lush

; --- lush 🐚 the line -- prompt, history, completion, the repl loops ---
;
; line editing is bao's `edlnc` (edln + Tab). sh-complete takes the text left of the
; cursor and answers (insert . candidates): commands in command position (builtins +
; a PATH readdir scan), pathnames elsewhere; a lone candidate lands its "/" or " "
; too. ~/.lush_history appends on Enter, so a crash loses nothing, and its last 100
; lines seed edln's recall. lush-help is the interactive floor: a scare drops to
; cooked, says `;; a b`, welps to the zero point and re-prompts ((sh _) installs it).

(module 'lush
(: ; --- the floor: bao's shell-help shape, cooked first so the print lands clean
   (lush-help a b)
     (raw 0, puts ";; ", putx a, puts " ", putx b, putc 10, welp a b)

   ; --- the prompt --------------------------------------------------------------
   (sh-rfind s b) (:- (go (#s - 1)) (go k)
    (? (k < 0) -1 (s k = b) k (go (k - 1))))
   (sh-homely d)                                ; /home/me/x -> ~/x
     (: h ("" + (getenv "HOME")) hn #h
        (hn && hn <= #d && h = snip d 0 hn ?
         ("~" + (snip d hn #d))
         d))
   (sh-gitup d)                                 ; a .git anywhere up the walk?
     (two? (stat (d + "/.git")) ? 1
        (: k (sh-rfind d 47)
           (? (k < 1) 0 (sh-gitup (snip d 0 k)))))
   (sh-gitbr _)
     (? (sh-gitup ("" + cwd 0))
        (: r (hark ["git" "symbolic-ref" "--short" "-q" "HEAD"])
           (<r @ 0 (sh-chomp >r) ""))
        "")
   ; the prompt's pens: a failing status red, the cwd the crew's cyan, the branch dim.
   ; no tty test guards them -- sh-loop is reached only when (raw 1) answered (), so the
   ; prompt is on a terminal. edlnc measures with edwide, so the escapes cost no column.
   sh-pen-st  "\e[31m"
   sh-pen-cwd "\e[38;5;117m"
   sh-pen-br  "\e[2m"
   sh-pen-off "\e[0m"
   (sh-prompt _)
     (: st (sh-status ())
        br (sh-gitbr 0)
        pst (st @ 0 "" (sh-pen-st + show st + " " + sh-pen-off))
        pbr (#br ? (sh-pen-br + " (" + br + ")" + sh-pen-off) "")
        (pst + sh-pen-cwd + sh-homely ("" + cwd 0) + sh-pen-off + pbr
             + (getuid 0 @ 0 " # " " $ ")))

   ; --- history: ~/.lush_history, oldest first on disk, newest first in hand
   (sh-expl s)                                  ; string -> charlist
     (: n #s
        (go i) (i @ ^n () (s i . go (i + 1)))
        (go 0))
   (sh-histpath _) (("" + (getenv "HOME")) + "/.lush_history")
   (sh-histload _)
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
   (sh-histput ln)
     (: o (open (sh-histpath 0) "a")
        (? (hot? o) (: _ (say o (ln + "\n")) _ (flush o) (close o)) 0))

   ; --- completion: (insert . candidates) off the text left of the cursor ------
   sh-builtins '("cd" "exit" "exec" "export" "pwd" "jobs" "fg" "bg" "which" "where" "type")
   (sh-prefix? p s) (: n #p ((n <= #s) && (p = (snip s 0 n))))
   (sh-comm2 a s)                               ; longest common prefix of two
     (: n (? (#a < #s) #a #s)
        (go i) (? ((i < n) && ((a i) = (s i))) (go (i + 1)) i)
        (snip a 0 (go 0)))
   (sh-common l) (? (one? l) "" (foldl sh-comm2 <l >l))
   (sh-uniq l)
     (? (one? l) l
        (? (two? >l && (<l = <>l)) (sh-uniq >l)
           (<l . sh-uniq >l)))
   (sh-pathdirs s)                              ; "a:b:c" -> ("a" "b" "c")
     (:- (go 0 0 ()) n #s (go i st acc)
      (i @ ^n (rev (snip s st i . acc))
       (s i @ 58 (go (i + 1) (i + 1) (snip s st i . acc))
        (go (i + 1) st acc))))
   (sh-verbnames _) (map string (keys (cite 'verbs 'tab)))
   (sh-cmds w)                                  ; command candidates for prefix w
     (sh-uniq (sort (filter (sh-prefix? w) sh-builtins +
                     (? (sh-greg? 0) () (filter (sh-prefix? w) (sh-verbnames 0))) +
                     (catmap (filter (sh-prefix? w) * readdir) (sh-pathdirs ("" + getenv "PATH"))))))
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
   (sh-complete left)
     (: s (slurp (tap left))
        st (sh-wdst s)
        w (snip s st #s)
        (? !#w '(())
           (: cmdp (sh-cmdpos? s st && sh-rfind w 47 < 0 && w 0 != 126)
              cands (? cmdp (sh-cmds w) (sh-fileca w))
              (? (one? cands) '(())
                 (: com (sh-common cands)
                    ins (? (sh-prefix? w com) (snip com #w #com) "")
                    one (one? >cands)
                    sfx (? !one ""
                           (? (!cmdp && sh-dirp (sh-unfold <cands)) "/" " "))
                    (sh-expl (ins + sfx) . cands))))))

   ; --- the loops ---------------------------------------------------------------
   (sh-cooked buf)
     (: _ (? #buf 0 (sh-reapbg 0))
        _ (say out (? #buf "> " ((cwd 0) + "$ ")))  _ (flush out)
        line (sh-getline in)
        (? (line = 'eof)
           (#buf && say err "lush: unexpected eof\n", puts "\n")
           (: full (? #buf (buf + ("\n" + line)) line)
              pr (sh-parse-line full)
              (<pr @ 'more (sh-cooked full)
                     'err (say err ("lush: " + (>pr + "\n")), pin sh-status () 2, sh-cooked "")
                          (sh-eval-top full >pr, sh-cooked "")))))
   ; interactive: edlnc owns echo, so raw the tty for the prompt and drop to cooked
   ; around each command. edlnc answers (line . nhist) or 'eof; nhist threads back.
   (sh-loop buf hist)
     (: _ (? #buf 0 (sh-reapbg 0))
        r (edlnc in (? #buf "> " (sh-prompt 0)) hist sh-complete)
        (r @ 'eof (raw 0, puts "\n")                 ; cooked, newline, end
         (: line (slurp (tap <r)) nhist >r
            _ (? #line (sh-histput line) 0)
            full (? #buf (buf + ("\n" + line)) line)
            pr (sh-parse-line full)
            (<pr @ 'more (sh-loop full nhist)
                   'err (raw 0,
                         say err ("lush: " + >pr + "\n"),
                         pin sh-status () 2,
                         raw 1,
                         sh-loop "" nhist)
               (raw 0,                                          ; cooked for the command
                sh-eval-top full >pr,
                raw 1,
                sh-loop "" nhist))))))                    ; re-raw for the next prompt
) ; module 'lush

; --- lush 🐚 -- the love shell ---
; a real unix command shell in love: a line in, real programs out through spawn +
; wait, stdio inherited -- so output is live and the command owns the terminal,
; unlike `run`. it is also what init execs on the distro console (the Makefile cats
; this file to /lib/sh.l), which is the pid1 story end to end. it rides inle/posix.c's
; job-control nifs (spawn/spawnmap/wait/chdir/cwd), getenv, fdopen, and bao's edln.
; run it:
;   out/lush                    ; interactive (or cooked when stdin is a pipe)
;   out/lush -c "echo hi"       ; one command (multi-line strings fine)
;   out/lush -g ..              ; gregarious: a verb word is ours only when PATH says so
;   out/lush -a ..              ; autonomous, the default: our verbs run here whatever PATH holds
;   out/lush script.sh          ; a script file, continuations gathered
;   out/lush --login ..         ; a login shell: /etc/profile + ~/.profile first
;   out/love -l apps/lush.l ..   ; the module road to the same seat
; the gate: test/host/sh.l reads the file bare and asserts on the sh-* names; the
; interactive loop is probed live under script(1).

(module 'lush
(: ; source a file through the line machinery, quietly absent (the rc/profile floor)
   (sh-src path)
     (one? (stat path) ? 0 (: p (open path "r") (sh-lines p "", close p, 0)))
   ; a login shell (--login, or a dash-led seat name) reads /etc/profile then
   ; ~/.profile; interactive shells layer $ENV (else ~/.lushrc) on top, in (sh _).
   (sh-profiles _)
     (sh-armtrap 0,
      !(sh-login ()) ? 0
       (sh-src "/etc/profile", sh-src ("" + getenv "HOME" + "/.profile")))
   ; the exit door runs the exit action but stands too early to know what a shell line
   ; is, so sh-runtrap is a box. pinned here rather than where sh-line is written:
   ; reading a name builds it, and sh-line and sh-eval-top call each other.
   (sh-armtrap _) (pin sh-runtrap () sh-line)
   ; the script lane rides sh-lines ('more gathers continuations, `exit` quits
   ; from inside); $0 and the positionals land before the run
   (sh-file path args)
     (? (two? (stat path))
        (: _ (pin sh-arg0 () path, pin sh-pos () args, sh-profiles 0)
           p (open path "r")
           (sh-lines p "", close p, sh-fire-exit 0, quit (sh-status ())))
        (say err ("lush: " + path + ": not found\n"), quit 127))
   (sh-c cmd rest)                              ; -c CMD [name [args..]], POSIX
     (: _ (pin sh-arg0 () (two? rest ? <rest "lush"),
           pin sh-pos () >rest,
           sh-profiles 0)
        r (sh-line cmd)
        ((two? r ? (say err "lush: unexpected eof\n", pin sh-status () 2) 0),
         sh-fire-exit 0, quit (sh-status ())))
   ; the flag word: a c e g u x, bundled or apart -- `sh -ec CMD` is what a Makefile's
   ; .SHELLFLAGS writes, so without the bundle lush cannot be the SHELL of a make.
   ; answers (1 c? rest) with e/u/x pinned, or () when a letter is not ours.
   (sh-flagw a rest)
     (:- (go 1 0) n #a (go k c?)
      (n <= k ? [1 c? rest]
       (a k @
          99 (go (k + 1) 1)
          97 (pin sh-gflag () 0, go (k + 1) c?)    ; -a autonomous
          103 (pin sh-gflag () 1, go (k + 1) c?)   ; -g gregarious
          101 (pin sh-eflag () 1, go (k + 1) c?)
          117 (pin sh-uflag () 1, go (k + 1) c?)
          120 (pin sh-xflag () 1, go (k + 1) c?))))
   sh-usage "usage: sh [-aeguxc] [--login] [-c CMD [NAME [ARG..]]] [FILE [ARG..]]
  -c CMD   run CMD              -e  leave on a failing command
  -a       autonomous: our verbs before PATH (the default)
  -g       gregarious: PATH decides; LUSHFLAGS' last a or g sets either
  -u       an unset name is an error    -x  trace what runs
  --login  a login shell: the profiles are read
no file and no -c is a shell: a repl on a tty, cooked script off stdin otherwise"
   (sh-main args)
     (sh-snapign 0,                             ; first: what our caller had turned off
      pin sh-gflag () (sh-envflag 0),            ; the mode: LUSHFLAGS' now, a flag word's below
      sh-forget 0,                               ; a forked shell drops its parent's word verdicts
      ; a task on inle shares this module with every other shell aboard: a child of a
      ; login shell is not one, and a recipe's shell owns no tty
      pin sh-login () 0, pin sh-tty () 0,
      sh-args args)
   (sh-args args)                              ; the argv walk, once the seat is set up
     (? !args (sh 0)
        (: a <args
           (a @- (sh-file a >args)
            "--login" (pin sh-login () 1, sh-args >args)
              ; the long forms only: -h is `set -h` in every shell, and -v is `set -v`
              "--help" (puts (sh-usage + "\n"), flush out, quit 0)
              "--version"
               (puts $ "lush (love " + love-version + ")\n", flush out, quit 0)
              ; -- ends the options, which is the only way to name a file that starts
              ; with a dash: every other dash word is a flag word, ours or a mistake
              "--" (two? >args ? (sh-file <>args >>args) (sh 0))
              (a && 1 < #a && a 0 = 45)
               (sh-flagw a >args @ fw (?- (sh-args (fw 2))
                (one? fw) (say err ("lush: " + a + ": invalid option\n"), flush err, quit 2)
                (fw 1) (fw 2 @ r (r ? (sh-c <r >r) (say err "lush: -c needs a command\n", quit 2))))))))
   ; the interactive entry: ignore the tty's job signals (children reset them), then
   ; probe with (raw 1) -- () = a tty, an errno = the cooked fallback. the floor is
   ; heard first, so a broken rc scares back to the prompt and not the shell.
   (sh _) (: ok (each [sig-int sig-quit sig-tstp sig-ttou sig-ttin] (flip signal 1), raw 1)
             (? !ok
                (: _ (heard () ? () (hear lush-help))
                   _ (pin sh-tty () 1)
                   erc ("" + getenv "ENV")
                   rc (erc || "" + getenv "HOME" + "/.lushrc")
                   _ (raw 0) _ (sh-profiles 0) _ (sh-src rc) _ (raw 1)
                   (sh-loop "" (sh-histload 0)))
                (sh-profiles 0, sh-cooked ""))))

; --- the seat (kiosko's): fire only when this file is the program -- the catted bin
; (`lush ..`), an sh-named symlink to it, or a -l load of the assembly. "sh.l" is
; deliberately not a me? name, so apps/init/boot.l's `-l /lib/sh.l -e "(sh 0)"` stays
; quiet here and fires through its -e instead. a dash-led basename (-lush, -sh:
; login(1)'s mark) seats us and makes a login shell, so the scan hands the raw word
; back and not just the match.
(: _ (pins (cite 'verbs 'tab) 'sh sh-main 'lush sh-main)
   (bn p) (:- (go 0 0) n #p (go k r) (k < n ? (go (k + 1) (p k @ 47 (k + 1) r)) (snip p r n))
             )
   s (cite 'verbs 'fire ["lush" "lush.l" "sh"])
   (two? s ? (: w (bn <s)
              (sh-main (#w && w 0 = 45 ? ("--login" . >s) >s)))))
) ; module 'lush
