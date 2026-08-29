#!/usr/bin/env -S love -l
; src/apps/helm/moor.l -- the moor: a love shell over a unix socket.
;
; the socket IS the interface. there is no control protocol, no query language
; and no second implementation of anything: a client sends love FORMS and reads
; love VALUES back, one line each. so the control surface and the introspection
; surface are one surface, and it is the whole vocabulary the supervisor has --
; (status 0) is a verb, and so is (peep (hstat 'sshd) 'since 0) when that is
; what you need to know, and (hstart1 (hby (hunits-now 0) 'sshd)) when the
; supervisor itself is what is misbehaving.
;
; that is a root shell, and it is a root shell on purpose. the guard is the
; socket: a unix socket refuses connect without write permission on the file, so
; the mode of $XDG_RUNTIME_DIR (0700) or /run is the whole access story. helm
; adds no authentication of its own and should not pretend to.
;
;   nc -U /run/helm.sock                 an interactive session
;   echo '(status 0)' | nc -U /run/helm.sock
;   helm ctl status                      the same thing, no netcat
;
; a session is its own task: `await` parks the accept loop on the listener,
; `see` parks a session on its client, and a session that raises takes only
; itself down -- the supervisor it is a window into keeps running.
(module 'helm
(: (hrundir _) (: r (getenv "XDG_RUNTIME_DIR") ((string? r) && (1 < tally r) ? r "/run"))
   (helm-sock _) (hrundir 0 + "/helm.sock")

   ; --- one session -----------------------------------------------------------
   ; read LINES and sound the TEXT: a socket running dry mid-form cannot strand
   ; the vm in a C parse, and a torn form carries to the next line as the residue
   ; the reader hands back. a string answer goes out as itself -- a report is
   ; written to be read -- and everything else is shown.
   (hsession c)
    (: (rdline acc) (: ch (see c)
                       (? (ch == -1)  ()
                          (ch == 10)  (rev (10 . acc))
                          (rdline (ch . acc))))
       ; a report already ends in a newline and must not gain a blank line: one
       ; value, one trailing newline, so a client can read a reply as a line.
       (reply v) (: t (string? v ? v (show v))
                    n (tally t)
                    s ((0 < n) && ((t (n - 1)) == 10) ? t (t + "\n"))
                    _ (say c s)
                    (flush c))
       (go pend)
        (: cl (rdline ())
           (? !(two? cl) 0
              ((: (h x) (: r (sound x)
                           (? (two? r)
                                (: v (trap (\ _ (ev 'ev <r)) 0 (\ a b ['scare a b]))
                                   _ (reply v)
                                   (h >r))
                              (id? r 'torn) (go x)
                              (go ()))))
               (pend + cl))))
       (go ()))

   ; --- the moor --------------------------------------------------------------
   ; finished sessions are collected here rather than left on the run ring, which
   ; the scheduler walks at every switch. `scoop` hands back one that ended, or
   ; () -- so the drain costs what actually finished and helm keeps no roster.
   (hscoop _) (two? (scoop 0) ? (hscoop 0) 0)
   (helm-moor path)
    (: l (shore path)
       (? !(lit? l) (hnote ("no moor at " + path), 0)
          (: _ (hnote ("moored at " + path))
             (go _) (: _ (await l)
                       c (accept l)
                       _ (hscoop 0)
                       _ (lit? c ? (twirl (\ _ (hsession c, close c)) 0) 0)
                       (go 0))
             (go 0))))

   ; --- the vocabulary --------------------------------------------------------
   ; short names, because they are typed at a prompt. they answer strings where a
   ; person is reading and love values where a program is.
   (hlines l)  (foldl (\ a s (a + s + "\n")) "" l)
   (status x)  (hlines (map hstatus-line ((name? x) ? [x] (hnames (hunits-now 0)))))
   (units x)   (map (\ u [(peep u 'name ()) (peep u 'kind ())
                          (hstate (peep u 'name ())) (peep u 'exec [])])
                    (hunits-now 0))
   (start nm)  (hensure nm [])
   (stop nm)   (hstop1 nm)
   (bounce nm) (hbounce nm)
   (logs n)    (hlines (htake (hcell 'events []) ((charm? n) && (0 < n) ? n 20)))
   (reload x)  (hreload 0)
   ; halt signals US, so the answer goes out before anything stops and the
   ; shutdown itself runs where every other shutdown runs -- hloop's TERM arm.
   (halt x)    (: _ (still (getpid 0) sig-term) "halting")
   (helm-help x)
    ("helm -- the moor answers love forms.\n"
     + "  (status 0)      every unit; (status 'name) just one\n"
     + "  (units 0)       the units as data\n"
     + "  (start 'name)   bring it up, its `after` first\n"
     + "  (stop 'name)    TERM its process group, then KILL\n"
     + "  (bounce 'name)  stop, clear the restart count, start\n"
     + "  (logs 20)       the last N events, newest first\n"
     + "  (reload 0)      re-read the config; restarts nothing\n"
     + "  (halt 0)        stop every unit and exit\n"
     + "anything else is evaluated: (hcell 'conf 0), (peep (hstat 'x) 'since 0).\n")))
