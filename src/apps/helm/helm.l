#!/usr/bin/env -S love -l
; src/apps/helm/helm.l -- the driver: helm's command line, and helm's own boot as pid 1.
; src/apps/helm/sample.l shows the whole config language. run from the tree:
;   love -l src/apps/helm/unit.l -l src/apps/helm/sup.l -l src/apps/helm/moor.l \
;        -l src/apps/helm/helm.l -e '(helm-main ["-c" "src/apps/helm/sample.l"])'
(module 'helm
(borrow 'tar)

(borrow 'path)
(borrow 'posix)
(: helm-usage "helm -- a service supervisor, and a love shell over its socket
usage: helm [-c CONF] [-s SOCK] [-q]     supervise (pid 1 lays the machine first)
       helm check [-c CONF]              read the config and report on it
       helm ctl [WORDS ..]               one command, or a session, over the socket
  -c, --config PATH   the unit file (default /etc/helm.l)
  -s, --socket PATH   the control socket (default $XDG_RUNTIME_DIR/helm.sock, or /run)
  -q, --quiet         keep the journal, but do not narrate to stderr
"
   (hdie c m) (udie c ("helm: " + m))

   ; --- helm ctl: the client --------------------------------------------------
   ; a pipe, not a protocol: the words go up as one line, whatever comes back is written out.
   ; a session is the same pipe, a reader task parked on the socket, a writer on the terminal
   (hdown c)  (see c @ ch (ch == -1 ? 0 (putc ch, flush out, hdown c)))
   (hup c)    (see in @ ch (ch == -1 ? (seal c 1)
                              (put c ch, ch == 10 ? (flush c) 0, hup c)))
   (helm-ctl sock as)
    (connect ['unix sock] @ c
       (? !(lit? c) (say err ("helm: no moor at " + sock + "\n"), 1)
          (two? as)
            (say c (hargv-line as + "\n"), flush c, seal c 1, hdown c, close c, 0)
          (twirl (_ \ (hdown c)) 0 @ t
             (hup c, catch t, close c, 0))))

   ; --- helm check ------------------------------------------------------------
   (helm-check conf)
    (: r  (hconf conf)
       _  (each <r (u \ puts (hunit-line u + "\n")))
       _  (flush out)
       gs <>r
       (each gs (g \ say err ("helm: " + g + "\n")),
        flush err,
        two? gs ? 1 0))

   ; --- pid 1's own bringup ---------------------------------------------------
   ; only as pid 1, root in our own namespace; elsewhere helm touches nothing
   (hmount1 src tgt typ)
    (mkdir tgt 493,
     mount src tgt typ @ r
       (hnote ("mount " + typ + " on " + tgt + (r ? (" -> errno " + show r) " -> ok"))))
   ; --- the underlay: /usr/bin, laid from the verb table ----------------------
   ; this binary answers to every verb through argv[0], so a directory of links onto selfpath
   ; is the userland of a diskless machine. names come from the registry, never a roster.
   ; inle wants none: k-prog reads the registry itself
   ; one link, laid over whatever stands there: a second boot meets its own last pass
   (hlink1 exe dir nm)
    (dir + "/" + string nm @ p
       (unlink p, nom? (symlink exe p) ? 0 1))
   (hunderlay dir)
    (selfpath 0 @ exe
       (? !(string? exe) (hnote "underlay: this seat cannot say where it lives", 0)
          (umkdirs dir 493,
           (: r  (mount "tmpfs" dir "tmpfs")
             _  (hnote ("underlay " + dir + (nom? r ? (" -> " + string r + ", laid in place")
                                                      " -> tmpfs")))
             ; `love` is no verb, it is the seat every name wears
             ws (sort ("love" . map string (keys (cite 'verbs 'tab))))
             n  (net (map (w \ hlink1 exe dir w) ws))
             (hnote ("underlay " + show n + " names on " + exe),
              n)))))
   ; --- the scatter: the carried tree, inflated into RAM -----------------------
   ; inle's ramfs is this tree (k_untar); a hosted pid 1 lays it too. paths re-home below the
   ; tar's top, as a checkout reads; a love linked without its source carries none
   ; the tar's top dropped: the top entry has no slash and re-homes to nothing
   (hbelow nom)
    (nom @ (_ + "/" + b) b "")
   (hscatter root)
    (tree-tar 0 @ a
       (? !(string? a) (hnote "scatter: this love carries no source", 0)
          (tar-unpack a @ t
             (atom? t ? (hnote "scatter: the carried tree is torn", 0)
                (: es (filter (e \ (0 < #(tar-get e 'nom "")))
                              (map (e \ pin e 'nom (hbelow (tar-get e 'nom ""))) <>t))
                   _  (umkdirs root 493)
                   w  (tar-scatter root es)
                   (atom? w ? (hnote ("scatter: can't write " + root), 0)
                      (hnote ("scatter " + show <>w + " files under " + root),
                       <>w)))))))
   (helm-pid1 _)
    (getpid 0 @ me
       (me != 1 ? 0
          (hnote "pid 1 -- the early filesystems",
           hmount1 "proc"     "/proc" "proc",
           hmount1 "sysfs"    "/sys"  "sysfs",
           hmount1 "devtmpfs" "/dev"  "devtmpfs",
           hmount1 "tmpfs"    "/tmp"  "tmpfs",
           hunderlay "/usr/bin",
           hscatter "/",
           1)))

   ; --- helm run --------------------------------------------------------------
   ; the splice first: the moor evaluates in the session's book, so helm's vocabulary
   ; must be that book for (status 0) to mean anything at a prompt
   (helm-run conf sock quiet)
    (cite 'helm ? (borrow 'helm), hput 'conf conf, hput 'quiet quiet, helm-pid1 0,
     (: r  (hconf conf)
       us  <r
       _   (each <>r (g \ hnote ("config: " + g)))
       _   (helm-reset us)
       sig (sigfd [sig-chld sig-term sig-int sig-hup])
       ((!(lit? sig) ? (udie 1 "helm: no signal source -- cannot supervise")),
        hput 'sig sig,
        string? sock ? (twirl (_ \ (helm-moor sock)) 0) 0,
        hnote ("up with " + show #us + " units"),
        hboot-all 0,
        hloop sig,
        0)))

   ; --- the command line ------------------------------------------------------
   ; the flags in ws into t, answering the words behind them; walked ahead of the verb and
   ; behind it (`helm check -c CONF`), one tablet for both
   ; the walk stops at the first non-flag, so `helm --nosuch` arrives here
   (hbad w) (hdie 2 ((1 < #w && w 0 = 45 ? "unknown option " "not a command: ") + w))
   (hopts t ws)
    (: o (uopt ws t '(99 115) () {"config" 99 "socket" 115 "quiet" 113})
       _ (two? o ? 0 (hdie 2 (last ws + " needs an argument")))
       un (uoptun t '(99 115 113))
       (!un ? 0 (hdie 2 ("unknown option -" + string un)),
        <>>o))
   (helm-main as)
    (cite 'helm ? (borrow 'helm),
     (: t {}
       r (hopts t as)
       w (two? r ? <r "")
       _ (w = "" || w = "run" || w = "check" || w = "ctl" ? 0 (hbad w))
       verb (? (w = "check") 'check (w = "ctl") 'ctl 'run)
       ; ctl is where our flags end: the words behind it are the remote command's
       words (verb = 'ctl ? >r (hopts t >r))
       _ (? (verb = 'ctl) 0 (two? words) (hbad <words) 0)
       conf (uoptv t 99 @ v (!v ? "/etc/helm.l" v))
       sock (uoptv t 115 @ v (!v ? (helm-sock 0) v))
       (? (verb == 'check) (helm-check conf)
          (verb == 'ctl)   (helm-ctl sock words)
          (helm-run conf sock (peep t 113 0))))))

; the seat, its own form so the binder above stays body-less: fire helm-main iff `helm`
; is the program word. the file name is not a seat word, or -l helm.l would supervise
; mid-load
(: door (udoor 'helm (urun helm-main) helm-usage 1 1)
   _ (cite 'verbs 'enlist 'helm door ())
   s (cite 'verbs 'fire ["helm"])
   (two? s ? (quit (door >s)))))
