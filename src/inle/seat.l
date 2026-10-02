; src/inle/seat.l -- the seat text: what this machine is that a host is not. kmain.c runs it
; on both lanes, after the prel and the module layers on the egg's, over the book on a woken
; image's, so its bindings shadow the hosted ones -- getenv reads envt here, not an empty
; environ. src/tools/lcat.l lays it as one C literal, out/lib/seat.h.

; which kernel this is, said outright; kore's uname respells it through the prel's os-uname
(: love-os 'inle)

; the environment: a tablet, the pairs on slot 0, closures over it wearing the host's names --
; getenv the value or (), setenv () or 'badarg (a non-string value unsets), environ the raw
; "NAME=value" strings
(: envt {}
   _ (pin envt 0 [("HOME" . "/home")])
   (envget l n) (two? l ? (n = <<l ? ><l (envget >l n)))
   (envcut l n) (two? l ? (n = <<l ? (envcut >l n) (<l . envcut >l n)))
   (getenv n) (string? n ? (envget (envt 0) n))
   (setenv n v) (string? n ? (envcut (envt 0) n @ c (pin envt 0 (string? v ? ((n . v) . c) c), ()))
                   'badarg)
   (environ u) (map (e \ <e + ("=" + >e)) (envt 0)))

; bootargv: the raw boot line's words, split quote-aware. cmdline stays seatless until the cat
; is in: a member's seat fires as its own file is read, and lush sits mid-cat, so it would take
; the machine with kore's applets unread. the foot wears the real line.
(: bootargv
     (: (kw i w s acc)
          (#bootline <= i ? (rev (#w ? (w . acc) acc))
             (bootline i @ c
                ; a char joins a string as a string of one: w + c on mixed bands is w alone
                (? s (c = s ? (kw (i + 1) w 0 acc) (kw (i + 1) (w + string c) s acc))
                   (c = 32) (kw (i + 1) "" 0 (#w ? (w . acc) acc))
                   (c = 34 || c = 39) (kw (i + 1) w c acc)
                   (kw (i + 1) (w + string c) 0 acc))))
        (kw 0 "" 0 ()))
   cmdline ["love"]
   argv cmdline)

; a process here is a task. k-prog maps argv onto a love main: a registry verb, a tool's own
; <name>-main, or a .l path off the ramfs evaled form by form (no fresh layer, so its defglobs
; land in the session). the fs doors are taken by value off their module: a splice would sit
; above the kernel's own shadows (raw, signal, setenv, environ, the no-op roster), which are
; what let this seat run a crew written for a host.
(: open (cite 'posix 'open) close (cite 'posix 'close) stat (cite 'posix 'stat)
   unlink (cite 'posix 'unlink)
   (k-bn p) (: n #p
              (go i r) (i < n ? (go (i + 1) (p i = 47 ? (i + 1) r)) (snip p r n))
              (go 0 0))
   (k-slurp p) (open p "r" @ q (port? q ? (slurp q @ t (close q, t))))
   (k-run-text t) (as \ ((: (go cl) (sound cl @ r (two? r ? (ev <r, go >r) 0))) t))
   (k-tool nm as) (elem nm (names ()) ? (ev nm . as))
   ; the crew load reads the roster's files off /proc/src, each file's own (module ..) form
   ; registering it. it hangs off the registry's miss (verbs' fills): lush answers "not found"
   ; from its own lookup, so a retry at the spawn never runs. `source` says the load is done.
   (cwords s i j acc)
     (j < #s ? (32 = peep s j 0 ? (i < j ? (cwords s (j + 1) (j + 1) (snip s i j . acc))
                                         (cwords s (j + 1) (j + 1) acc))
                                  (cwords s i (j + 1) acc))
               (i < j ? (rev (snip s i j . acc)) (rev acc)))
   (cload p) (open ("/proc/src/" + p) "r" @ q
               (port? q ? (: t (slurp q) _ (close q)
                             (go cl) (sound cl @ r (two? r ? (ev <r, go >r) 0))
                             (go t))
                          0))
   (crewload _) (cite 'source ? 0 (each (cwords crewlist 0 0 ()) cload, 0))
   ; the registry is the PATH: apps pin their names into (cite 'verbs 'tab), and `word` applies
   ; the shadow rules -- a slashed word or a .l name is a file, never a verb, which keeps the
   ; two lanes below reachable. a verb takes the args after its name.
   (k-prog argv) (k-proga argv 1)
   ; a script says who reads it: `#!`, the words after it, then this path and the args. the
   ; reader is taken by basename (usr/bin is empty, so /bin/sh is sh), one hop.
   (k-bangv t p as)
     (!(string? t && 2 < #t && "#!" = snip t 0 2) ? ()
        (: n #t
           (go i) (i < n ? (10 = peep t i 0 ? i (go (i + 1))) n)
           w (cwords (snip t 2 (go 0)) 0 0 ())
           (two? w ? (k-bn <w . (>w + (p . as))))))
   (k-proga argv h) (: a0 <argv b (k-bn a0) as >argv
                      v (cite 'verbs 'word a0)
                      (!(nil? v) ? (v . as)
                         (k-tool (intern (b + "-main")) as @ k
                            (? (two? k) k
                               ; `kore TOOL ..` where no dispatcher registered one: the test
                               ; kernel bakes the applets
                               (b = "kore" && two? as) (k-tool (intern (<as + "-main")) >as)
                               (two? (stat a0)) (k-progf a0 as h)
                               ; a path the seat has not got is looked for on the tarball, so
                               ; `love test/kernel/all.l` names the corpus from any seat
                               (!(47 = peep a0 0 0) && two? (stat ("/proc/src/" + a0)))
                                 (k-progf ("/proc/src/" + a0) as h)
                               ()))))
   (k-progf a0 as h) (: t (k-slurp a0)
                        g (0 < h ? (k-bangv t a0 as))
                        (? (two? g) (k-proga g (h - 1))
                           (string? t) (k-run-text t . as)
                           ()))
   (k-slot w n) (? !(two? w) () (n = 0) <w (k-slot >w (n - 1)))
   ; a console-numbered fd is the parent's view of it, so 2>&1 follows what the parent wears;
   ; anything higher is duped, the port owning the copy from there
   (k-port w n f) (? !(charm? f) (k-slot w n) (f < 0) (k-slot w n) (f < 3) (k-slot w f) (fdopen (dup f)))
   ; what a signal needs of a task: its group, its own ends, and the status it leaves
   k-grp {} k-ends {} k-died {} k-held {}
   ; the child's stdio is seated in the parent, twirl not switching, so it is laid before the
   ; child's first read; the parent takes its own back on the next line. a group is the pid of
   ; the task that leads it, and fg hands it the terminal on fd 0 (ttyfg).
   (k-spawn1 argv f0 f1 f2 pg fg)
     (: pr (k-prog argv)
        w (worn ())
        kw [(k-port w 0 f0) (k-port w 1 f1) (k-port w 2 f2)]
        own (k-own [f0 f1 f2] kw)              ; the ends duped for it, which a stop closes
        _ (wear kw)
        ; the help is the exit door too: a kore main leaves deep by scaring 'leave with its
        ; status, and a plain scare would flatten every usage code to 1
        p (twirl (_ \ (: _ (hear (a \ b \ (a == 'leave ? (quit b)
                                             (say err ";; ", print err a, say err " ", print err b,
                                              put err 10, quit 1))))
                         r (two? pr ? (<pr >pr) (say err (<argv + ": not found"), put err 10, 127))
                         (quit (charm? r ? r 0))))
                 0)
        (wear w, k-seat p own pg fg, p))
   (k-own fs ps) (? !(two? fs) ()
                    (charm? <fs && 2 < <fs) (<ps . k-own >fs >ps)
                    (k-own >fs >ps))
   (k-seat p own pg fg)
     ((? !(charm? pg) () (pg < 0) () (pg = 0) p pg) @ gp
        (pin k-ends p own,
         (charm? gp ? (pin k-grp p gp) 0),
         (charm? gp && charm? fg && 0 < fg ? (ttyfg gp) 0)))
   (k-members gp) (k-mem gp (keys k-grp))
   (k-mem gp ks) (? !(two? ks) ()
                    (gp = k-grp <ks && !(landed? <ks)) (<ks . k-mem gp >ks)
                    (k-mem gp >ks))
   ; kill at task granularity: a stop holds the task (pause), wait answering 256+sig for it; a
   ; cont lets it go on (resume); any other signal ends it where it stands, closing the ends it
   ; was handed, wait answering 128+sig. each status is laid before the task moves, since the
   ; waiter wakes the moment the task is held or gone -- and an end closes before it is gone, so
   ; a waiter that reads it next finds the end, however the closes yield
   (k-stop t sig)
     (? (sig = 18) (pull k-held t 0, resume t)
        (19 <= sig <= 22) (pin k-held t (256 + sig), pause t)
        (pin k-died t (128 + sig), pull k-held t 0, each (k-ends t) close, pull k-ends t 0, freeze t))
   (still p sig)
     (!(charm? p) || !(charm? sig) ? (nom 'badarg)
        ((? (p < 0) (k-members -p) (landed? p) () [p]) @ ts
           (? !(two? ts) (nom 'esrch)
              (sig = 0) 0
              (each ts (t \ k-stop t sig), 0))))
   (k-fdw x) (charm? x ? (x < 0 ? -1 x) -1)
   (spawn argv) (k-spawn1 argv -1 -1 -1 -1 0)
   ; exec at task granularity: this task becomes the program and never comes back
   (exec argv) (k-prog argv @ pr
                 (two? pr ? (<pr >pr @ r (quit (charm? r ? r 0)))
                    (say err (<argv + ": not found"), put err 10, quit 127)))
   (spawnio argv i o e cl pg fg) (k-spawn1 argv (k-fdw i) (k-fdw o) (k-fdw e) pg fg)
   (spawnmap argv fdm cl pg fg)
     ((: (go m a b c)
          (atom? m ? (k-spawn1 argv a b c pg fg)
             (: e <m cf <e sf >e
                v (charm? sf ? (0 <= sf < 3 ? ((? (sf = 0) a (sf = 1) b c) @ w (w < 0 ? sf w)) sf) -2)
                (? (cf = 0) (go >m v b c)
                   (cf = 1) (go >m a v c)
                   (cf = 2) (go >m a b v)
                   (go >m a b c))))
        go)
      fdm -1 -1 -1)
   (wait p) (: r (catch p) h (k-held p)
              (charm? h ? h
                 (k-died p @ d (pull k-died p 0, pull k-grp p 0, pull k-ends p 0, (charm? d ? d r)))))
   ; a child on a pty of its own, as the host's tether: it leads its own group, which takes the
   ; terminal, and a watcher answers a key's signal by stilling whichever group holds it then.
   ; the master closed is a hangup, to that group and to the child, and the watcher ends.
   ; -> (pid . master port)
   (tether argv) (openpty 0 @ fs
                   (!(two? fs) ? fs
                      (: m <fs sl <>fs sg <>>fs
                         w (worn ()) sp (fdopen (dup sl))
                         _ (wear [sp sp sp])
                         p (k-spawn1 argv sl sl sl 0 1)
                         (wear w, close sp, close sl, twirl (_ \ k-sigs (fdopen sg) p) 0, (p . fdopen m)))))
   ; a hangup reaches the child that holds the session as well as the group in front
   (k-sigs q p) (see q @ c
                  (c < 0 ? (close q)
                     (ttypg q @ g ((charm? g && 0 < g ? (still -g c) 0),
                                   (c = 1 && !(g = p) ? (still -p c) 0),
                                   k-sigs q p))))
   ; hark and herald on a seat with no fork: the capture is a scratch file worn as the child's
   ; stdout, and herald's relay is a dump at the end. stderr stays on the console.
   hark-n {}
   ; a word nothing answers is an answer here, never a line on the console -- what a hosted
   ; hark's errno is, and `$(shell command -v cc)` is the caller asking
   (hark1 argv tee)
     (!(two? (k-prog argv)) ? ()
        (: w (worn ())
           k (1 + peep hark-n 0 0)
           _ (pin hark-n 0 k)
           p ("/tmp/.hark" + show k)
           q (open p "w")
           (!(port? q) ? ()
              (: z (open "/dev/null" "r")         ; the child reads nothing, as a hosted hark's
                 _ (wear [(port? z ? z (k-slot w 0)) q (k-slot w 2)])
                 d (spawn argv)
                 st (charm? d && 0 <= d ? (wait d) 127)
                 _ (wear w)
                 _ (close q)
                 _ (port? z ? (close z) 0)
                 r (open p "r")
                 t (port? r ? (slurp r @ b (close r, b)) "")
                 (unlink p, (tee ? (puts t) 0), ((charm? st ? st 0) . t))))))
   (hark argv) (hark1 argv 0)
   (herald argv) (hark1 argv 1))
