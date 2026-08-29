#!/usr/bin/env -S love -l
; src/apps/helm/helm.l -- the driver: helm's command line, and helm's own boot.
;
;   helm [-c CONF] [-s SOCK] [-q]   supervise. as pid 1 it mounts /proc, /sys and
;                                   /dev first; anywhere else it just supervises.
;   helm check [-c CONF]            read the config, say what is wrong with it,
;                                   print the units it would run. exit 1 on a gripe.
;   helm ctl [WORDS ..]             talk to a running helm over its socket. with
;                                   words, one command and its answer; without,
;                                   a session -- stdin up, the answers down.
;
; the config defaults to /etc/helm.l and the socket to $XDG_RUNTIME_DIR/helm.sock
; when that is set, /run/helm.sock otherwise. src/apps/helm/sample.l is a config that
; shows the whole language; `helm check -c src/apps/helm/sample.l` reads it.
;
; src/apps/init/ is where this started: init.l models the supervisor with green tasks
; and boot.l is the initramfs /init the kernel execs. helm is the running thing --
; real processes, a config it did not have, and a socket to ask it questions. the
; two have not been joined yet: boot.l still hands the console to lush.
;
; run it out of the tree, without installing anything:
;   love -l src/apps/helm/unit.l -l src/apps/helm/sup.l -l src/apps/helm/moor.l \
;        -l src/apps/helm/helm.l -e '(helm-main ["-c" "src/apps/helm/sample.l"])'
(module 'helm
(: (usage _)
   (: _ (puts "helm -- a service supervisor, and a love shell over its socket
usage: helm [-c CONF] [-s SOCK] [-q]     supervise (pid 1 mounts first)
       helm check [-c CONF]              read the config and report on it
       helm ctl [WORDS ..]               one command, or a session, over the socket
  -c, --config PATH   the unit file (default /etc/helm.l)
  -s, --socket PATH   the control socket (default $XDG_RUNTIME_DIR/helm.sock, or /run)
  -q, --quiet         keep the journal, but do not narrate to stderr
")
      (quit 0))
   (need h r) ((atom? r) ? (say err ("helm: " + h + " needs an argument\n"), quit 2))

   ; --- helm ctl: the client --------------------------------------------------
   ; a PIPE, not a protocol: the words go up as one line and whatever comes back
   ; is written out. a session is the same pipe with two tasks on it, the reader
   ; parked on the socket while the writer is parked on the terminal.
   (hdown c)  (: ch (see c)  (? (ch == -1) 0 (putc ch, flush out, hdown c)))
   (hup c)    (: ch (see in) (? (ch == -1) (seal c 1)
                                (put c ch, (ch == 10 ? (flush c) 0), hup c)))
   (helm-ctl sock as)
    (: c (connectu sock)
       (? !(lit? c) (say err ("helm: no moor at " + sock + "\n"), 1)
          (two? as)
            (: _ (say c (hargv-line as + "\n")) _ (flush c) _ (seal c 1)
               _ (hdown c) _ (close c) 0)
          (: t (twirl (\ _ (hdown c)) 0)
             _ (hup c)
             _ (catch t)
             _ (close c)
             0)))

   ; --- helm check ------------------------------------------------------------
   (helm-check conf)
    (: r  (hconf conf)
       _  (each <r (\ u (puts (hunit-line u + "\n"))))
       _  (flush out)
       gs <>r
       _  (each gs (\ g (say err ("helm: " + g + "\n"))))
       _  (flush err)
       ((two? gs) ? 1 0))

   ; --- pid 1's own bringup ---------------------------------------------------
   ; only as pid 1, where we are root in our own namespace and these mounts are
   ; ours to make. anywhere else helm is a plain supervisor and touches nothing.
   (hmount1 src tgt typ)
    (: _ (mkdir tgt 493)
       r (mount src tgt typ)
       (hnote ("mount " + typ + " on " + tgt + (r ? (" -> errno " + show r) " -> ok"))))
   (helm-pid1 _)
    (: me (getpid 0)
       (? (me != 1) 0
          (: _ (hnote "pid 1 -- the early filesystems")
             _ (hmount1 "proc"     "/proc" "proc")
             _ (hmount1 "sysfs"    "/sys"  "sysfs")
             _ (hmount1 "devtmpfs" "/dev"  "devtmpfs")
             1)))

   ; --- helm run --------------------------------------------------------------
   ; the splice first: the moor evaluates in the session's book, so helm's own
   ; vocabulary has to BE that book for (status 0) to mean anything at a prompt.
   (helm-run conf sock quiet)
    (: _   (!(nil? (from 'helm)) ? (use 'helm))
       _   (hput 'conf conf)
       _   (hput 'quiet quiet)
       _   (helm-pid1 0)
       r   (hconf conf)
       us  <r
       _   (each <>r (\ g (hnote ("config: " + g))))
       _   (helm-reset us)
       sig (sigfd [sig-chld sig-term sig-int sig-hup])
       _   (!(lit? sig) ? (say err "helm: no signal source -- cannot supervise\n", quit 1))
       _   (hput 'sig sig)
       _   ((string? sock) ? (twirl (\ _ (helm-moor sock)) 0) 0)
       _   (hnote ("up with " + show (tally us) + " units"))
       _   (hboot-all 0)
       _   (hloop sig)
       0)

   ; --- the command line ------------------------------------------------------
   (helm-main as)
    (: _ (!(nil? (from 'helm)) ? (use 'helm))
       box {'conf "/etc/helm.l" 'sock (helm-sock 0) 'verb 'run 'words ()}
       (loop (w . r))
        (w @ ("-c" || "--config") (need w r, pin box 'conf <r, loop >r)
             ("-s" || "--socket") (need w r, pin box 'sock <r, loop >r)
             ("-q" || "--quiet")  (pin box 'quiet 1, loop r)
             ("-h" || "--help")   (usage 0)
             "run"                (pin box 'verb 'run, loop r)
             "check"              (pin box 'verb 'check, loop r)
             "ctl"                (pin box 'verb 'ctl, pin box 'words r, ())
             (pin box 'words (happend (peep box 'words []) [w]), loop r))
       _ (loop as)
       v (peep box 'verb 'run)
       (? (v == 'check) (helm-check (peep box 'conf ""))
          (v == 'ctl)   (helm-ctl (peep box 'sock "") (peep box 'words []))
          (helm-run (peep box 'conf "") (peep box 'sock "") (peep box 'quiet 0)))))

; the seat, its own form so the binder above stays body-less and defglobs: fire
; helm-main iff the installed `helm` script sits in the program seat of the real
; command line. the bare file name is deliberately NOT a seat word -- helm is
; four files, and a `-l src/apps/helm/helm.l` that seated would start supervising in
; the middle of loading itself.
(: _ (pins (from 'verbs 'tab) 'helm helm-main)
   s (from 'verbs 'fire ["helm"])
   ((two? s) ? (helm-main >s))))
