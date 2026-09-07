#!/usr/bin/env -S love -l
; apps/helm/helm.l -- the driver: helm's command line, and helm's own boot.
;
;   helm [-c CONF] [-s SOCK] [-q]   supervise. as pid 1 it lays the machine first
;                                   (below); anywhere else it just supervises.
;   helm check [-c CONF]            read the config, say what is wrong with it,
;                                   print the units it would run. exit 1 on a gripe.
;   helm ctl [WORDS ..]             talk to a running helm over its socket. with
;                                   words, one command and its answer; without,
;                                   a session -- stdin up, the answers down.
;
; the config defaults to /etc/helm.l and the socket to $XDG_RUNTIME_DIR/helm.sock
; when that is set, /run/helm.sock otherwise. apps/helm/sample.l is a config that
; shows the whole language; `helm check -c apps/helm/sample.l` reads it.
;
; as pid 1 it lays a machine that needs no disk: the early filesystems, then
; /usr/bin as links onto this binary (every name in the verb registry, argv[0] being
; the door), then the carried source archive inflated to a tree. that is inle's boot
; in userspace -- inle/kmain.c inflates the same blob into its own ramfs -- and
; the two differ where the kernels do: inle has no symlinks, so its k-prog reads the
; registry where execve here wants a dirent.
;
; apps/init/ is where this started: init.l models the supervisor with green tasks
; and boot.l is the initramfs /init the kernel execs. helm is the running thing --
; real processes, a config it did not have, and a socket to ask it questions. the
; two have not been joined yet: boot.l still hands the console to lush.
;
; run it out of the tree, without installing anything:
;   love -l apps/helm/unit.l -l apps/helm/sup.l -l apps/helm/moor.l \
;        -l apps/helm/helm.l -e '(helm-main ["-c" "apps/helm/sample.l"])'
(module 'helm
(use 'gz)
(use 'tar)

(: (usage _)
   (: _ (puts "helm -- a service supervisor, and a love shell over its socket
usage: helm [-c CONF] [-s SOCK] [-q]     supervise (pid 1 lays the machine first)
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
   ; --- the underlay: /usr/bin, laid from the verb table ----------------------
   ; this binary answers to every name in (from 'verbs 'tab) through argv[0] --
   ; post.l's `seat` reads the basename -- so a directory of links onto selfpath
   ; IS the userland, and a machine with no disk still has one. inle wants no such
   ; directory: k-prog reads the registry itself (inle/kmain.c). here execve
   ; resolves a path, so the kernel is owed the dirents the registry stands for.
   ;
   ; the names come from the registry and are never listed: a roster would drift
   ; from what the binary can actually do the first time a verb is added.
   (hmkdirs p)
    (: n #p
       (go i) (? (n <= i) 0
                 (p i = 47) (: _ ((0 < i) ? (mkdir (snip p 0 i) 493) 0) (go (i + 1)))
                 (go (i + 1)))
       _ (go 0)
       (mkdir p 493))
   ; one link, laid over whatever stands there: a second boot into a live tmpfs
   ; would meet its own last pass, and eexist is not a reason to have no `ls`.
   (hlink1 exe dir nm)
    (: p (dir + "/" + string nm)
       _ (unlink p)
       (nom? (symlink exe p) ? 0 1))
   (hunderlay dir)
    (: exe (selfpath 0)
       (? !(string? exe) (hnote "underlay: this seat cannot say where it lives", 0)
          (: _  (hmkdirs dir)
             r  (mount "tmpfs" dir "tmpfs")
             _  (hnote ("underlay " + dir + (nom? r ? (" -> " + string r + ", laid in place")
                                                      " -> tmpfs")))
             ; `love` is not a verb -- it is the seat every other name wears -- so
             ; it is named here rather than read off the table.
             ws (sort ("love" . map string (keys (from 'verbs 'tab))))
             n  (net (map (\ w (hlink1 exe dir w)) ws))
             _  (hnote ("underlay " + show n + " names on " + exe))
             n)))
   ; --- the scatter: the carried tree, inflated into RAM -----------------------
   ; inle's ramfs IS this archive (k_untar in inle/kmain.c): the artifact carries
   ; its own source and the machine inflates it at boot, so a disk was never what the
   ; tree was on. the same blob is here, so a hosted pid 1 lays the same tree.
   ;
   ; paths re-home below the archive's top, as k_tar_walk does it, so the tree reads
   ; from inside the way a checkout does -- /apps/helm/helm.l, not /love-0.1/apps/..
   ; a love linked without its source (the raw distro base) carries an empty blob and
   ; says so; the underlay above stands on its own and does not want this.
   ; the archive's top, dropped: the entry that IS the top has no slash and re-homes
   ; to nothing, which is how it stops being a directory at the root.
   (hbelow nom)
    (: n #nom
       (go i) (? (n <= i) "" (nom i = 47) (snip nom (i + 1) n) (go (i + 1)))
       (go 0))
   (hscatter root)
    (: gz (source-gz "x")
       (? !(string? gz) (hnote "scatter: this love carries no source", 0)
          (: u (gz-unzip gz)
             (? !(two? u) (hnote "scatter: the carried archive did not inflate", 0)
                (: t (tar-unpack <>u)
                   (? !(two? t) (hnote "scatter: the carried archive is torn", 0)
                      (: es (filter (\ e (0 < #(tar-get e 'nom "")))
                                    (map (\ e (pin e 'nom (hbelow (tar-get e 'nom "")))) <>t))
                         _  (hmkdirs root)
                         w  (tar-scatter root es)
                         (? !(two? w) (hnote ("scatter: can't write " + root), 0)
                            (hnote ("scatter " + show <>w + " files under " + root),
                             <>w)))))))))
   (helm-pid1 _)
    (: me (getpid 0)
       (? (me != 1) 0
          (: _ (hnote "pid 1 -- the early filesystems")
             _ (hmount1 "proc"     "/proc" "proc")
             _ (hmount1 "sysfs"    "/sys"  "sysfs")
             _ (hmount1 "devtmpfs" "/dev"  "devtmpfs")
             _ (hmount1 "tmpfs"    "/tmp"  "tmpfs")
             _ (hunderlay "/usr/bin")
             _ (hscatter "/")
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
; four files, and a `-l apps/helm/helm.l` that seated would start supervising in
; the middle of loading itself.
(: _ (pins (from 'verbs 'tab) 'helm helm-main)
   s (from 'verbs 'fire ["helm"])
   ((two? s) ? (helm-main >s))))
