#!/usr/bin/env -S love -l
; src/apps/helm/moor.l -- the moor: a love shell over a unix socket.
;
; the socket IS the interface: a client sends love FORMS and reads love VALUES back, one
; line each, so control and introspection are one surface, the supervisor's whole
; vocabulary. that is a root shell on purpose: the guard is the socket file's mode
; ($XDG_RUNTIME_DIR 0700, or /run); helm adds no authentication of its own.
;   nc -U /run/helm.sock                 an interactive session
;   echo '(status 0)' | nc -U /run/helm.sock
;   helm ctl status                      the same thing, no netcat
;
; a session is its own task, and one that raises takes only itself down.
(module 'helm
(borrow 'posix)
(: (hrundir _) (getenv "XDG_RUNTIME_DIR" @ r (string? r && 1 < #r ? r "/run"))
   (helm-sock _) (hrundir 0 + "/helm.sock")

   ; --- one session -----------------------------------------------------------
   ; read LINES and sound the TEXT: a dry socket mid-form can't strand the vm in a C parse,
   ; and a torn form carries to the next line. a string answer goes out as itself, the
   ; rest shown.
   (hsession c)
    (: (rdline acc) (see c @ ch
                       (? (ch == -1)  ()
                          (ch == 10)  (rev (10 . acc))
                          (rdline (ch . acc))))
       ; one value, one trailing newline, so a client reads a reply as a line
       (reply v) (: t (string? v ? v (show v))
                    n #t
                    s (0 < n && t (n - 1) == 10 ? t (t + "\n"))
                    (say c s, flush c))
       (go pend)
        (rdline () @ cl
           (atom? cl ? 0
              ((: (h x) (sound x @ r
                           (? (two? r)
                                (trap (_ \ (ev 'ev <r)) 0 (a \ b \ ['scare a b]) @ v
                                   (reply v, h >r))
                              (r == 'torn) (go x)
                              (go ()))))
               (pend + cl))))
       (go ()))

   ; --- the moor --------------------------------------------------------------
   ; finished sessions are collected here, not left on the run ring the scheduler walks at
   ; every switch; `scoop` hands back one that ended, so helm keeps no roster.
   (hscoop _) (two? (scoop 0) ? (hscoop 0) 0)
   (helm-moor path)
    (listen ['unix path] @ l
       (? !(lit? l) (hnote ("no moor at " + path), 0)
          (hnote ("moored at " + path),
           (: (go _) (await l,
                      accept l @ c
                        (hscoop 0, lit? c ? (twirl (_ \ (hsession c, close c)) 0) 0, go 0))
              (go 0)))))

   ; --- the vocabulary --------------------------------------------------------
   ; short names, typed at a prompt: strings where a person reads, values where a program does
   (hlines l)  (foldl (a \ s \ a + s + "\n") "" l)
   (status x)  (hlines (map hstatus-line (name? x ? [x] (hnames (hunits-now 0)))))
   (units x)   (map (u \ [(u 'name) (u 'kind) (hstate (u 'name)) (peep u 'exec [])])
                    (hunits-now 0))
   (start nm)  (hensure nm [])
   (stop nm)   (hstop1 nm)
   (bounce nm) (hbounce nm)
   (logs n)    (hlines (htake (hcell 'events []) (charm? n && 0 < n ? n 20)))
   (reload x)  (hreload 0)
   ; halt signals us, so the answer goes out first and hloop's TERM arm shuts down
   (halt x)    (still (getpid 0) sig-term, "halting")
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
