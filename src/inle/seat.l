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
   _ (pin envt 0 [("HOME" . "/home") ("COLORTERM" . "truecolor")])   ; the console is quay, which keeps 24-bit colour
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
   ; the crew load reads the roster's files off /love, each file's own (module ..) form
   ; registering it. it hangs off the registry's miss (verbs' fills): lush answers "not found"
   ; from its own lookup, so a retry at the spawn never runs. `source` says the load is done.
   (cwords s i j acc)
     (j < #s ? (32 = peep s j 0 ? (i < j ? (cwords s (j + 1) (j + 1) (snip s i j . acc))
                                         (cwords s (j + 1) (j + 1) acc))
                                  (cwords s i (j + 1) acc))
               (i < j ? (rev (snip s i j . acc)) (rev acc)))
   (cload p) (open ("/love/" + p) "r" @ q
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
                               (!(47 = peep a0 0 0) && two? (stat ("/love/" + a0)))
                                 (k-progf ("/love/" + a0) as h)
                               ()))))
   (k-progf a0 as h) (: t (k-slurp a0)
                        g (0 < h ? (k-bangv t a0 as))
                        (? (two? g) (k-proga g (h - 1))
                           (string? t) (k-run-text t . as)
                           ()))
   (k-slot w n) (task-slot w n)
   ; a task here is a process (src/inle/tasks.l): the group's leader takes the terminal on fd 0.
   ; argv may be ['thunk f] instead: a shell's own stage, run as (f ()) -- lush's compound
   ; stages on this forkless seat
   (k-spawn1 argv f0 f1 f2 pg fg)
     (task-run (? (<argv = 'thunk) [<>argv] (k-prog argv)) argv f0 f1 f2 pg fg ttyfg)
   (still p sig) (task-still p sig)
   (k-fdw x) (task-fdw x)
   (spawn argv) (k-spawn1 argv -1 -1 -1 -1 0)
   ; exec at task granularity: this task becomes the program and never comes back
   (exec argv) (k-prog argv @ pr
                 (two? pr ? (<pr >pr @ r (quit (charm? r ? r 0)))
                    (say err (<argv + ": not found"), put err 10, quit 127)))
   (spawnio argv i o e cl pg fg) (k-spawn1 argv (k-fdw i) (k-fdw o) (k-fdw e) pg fg)
   (spawnmap argv fdm cl pg fg) (task-map fdm (\ a b c (k-spawn1 argv a b c pg fg)))
   (wait p) (task-wait p)
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

; processes: programs in memory of their own, where this machine can run one (src/inle/sys.c).
; the task that starts one stands in for it -- wait and the job table see that task -- and
; answers the process's status once the pipe the kernel ends with it reads to its end
(: k-nul (string 0)
   (k-words l) (foldl (\ s w (s + (w + k-nul))) "" l)
   (k-procrun argv)
     (kproc (k-words argv) (k-words (environ 0)) @ r
        (!(two? r) ? (say err (<argv + ": " + show r), put err 10, 126)
           (: q (fdopen >r) _ (slurp q) _ (close q)
              (kreap <r @ s (charm? s ? s 1)))))
   ; `proc PROG ARGS ..`: love's PROG as a process, woken from the machine's own image
   (proc-main args) (k-procrun args)
   _ (pins (cite 'verbs 'tab) 'proc proc-main))

; a window here is the whole screen: (kpaper 1) holds the framebuffer and answers (w h),
; (kshow paper y0 y1) lays the paper's rows on it, (kpaper 0) gives it back to the console.
; kwin-events answers what waits as a window's records, as src/apps/lux/wire.l's x-events
; does on X: a key by its set-1 code, the pointer in pixels with X's buttons, the paper's new
; size, and the text the console decoded, its escapes and controls left out
(: (kwin-btn b) (b & 227 @ v (? (v < 3) (v + 1) (v = 64) 4 (v = 65) 5 0))
   (kwin-rec e) (? (charm? e) [(e & 128 ? 'up 'down) (e & 383)]
                   (#e = 2) ['size (e 0) (e 1)]
                   (e 0 = 2) ['move (e 2) (e 3)]
                   [(e 0 = 0 ? 'press 'release) (kwin-btn (e 1)) (e 2) (e 3)])
   (kwin-text acc esc) (key 0 @ b
                          (? (b = 0) acc
                             (esc = 1) (kwin-text acc (b = 91 || b = 79 ? 2 0))   ; CSI, SS3, or a lone escape
                             (esc = 2) (kwin-text acc (64 <= b <= 126 ? 0 2))     ; a sequence ends at its final
                             (b = 27) (kwin-text acc 1)
                             (b < 32 || b = 127) (kwin-text acc 0)
                             (kwin-text (acc + string b) 0)))
   (kwin-events _)
    (: (go acc) (kscan 0 @ e (e = () ? (rev acc) (go (kwin-rec e . acc))))
       t (kwin-text "" 0)
       (go () @ l (0 < #t ? (l + [['text t]]) l))))
