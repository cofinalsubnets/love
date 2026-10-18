; src/inle/seat.l -- what this machine is that a host is not. kmain.c runs it after the prel
; and module layers, so its bindings shadow the hosted ones (getenv reads envt here)

; which kernel this is; kore's uname respells it through os-uname
(: love-os 'inle)

; the environment: pairs on envt's slot 0 under the host's names -- getenv the value or (),
; setenv () or 'badarg (a non-string value unsets), environ "NAME=value" strings. it starts
; from the C environment sys.c lays, plus HOME, so the shell keeps a plain prompt
(: envt {}
   _ (pin envt 0 (("HOME" . "/home") . map (s \ s @ (k + "=" + v) (k . v)) (environ 0)))
   (envget l n) (two? l ? (n = <<l ? ><l (envget >l n)))
   (envcut l n) (two? l ? (n = <<l ? (envcut >l n) (<l . envcut >l n)))
   (getenv n) (string? n ? (envget (envt 0) n))
   (setenv n v) (string? n ? (envcut (envt 0) n @ c (pin envt 0 (string? v ? ((n . v) . c) c), ()))
                   'badarg)
   (environ u) (map (e \ <e + ("=" + >e)) (envt 0)))

; bootargv: the boot line's words, quote-aware. cmdline stays seatless: lush sits mid-cat,
; so a member's seat firing as it is read would miss kore's applets
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

; a process here is a task. k-prog maps argv onto a love main: a registry verb, a tool's
; <name>-main, or a .l path evaled form by form in the session. the fs doors are taken by
; value: a splice would sit above the kernel's own shadows a host-written crew relies on
(: open (cite 'posix 'open) close (cite 'posix 'close) stat (cite 'posix 'stat)
   unlink (cite 'posix 'unlink)
   (k-bn p) (: n #p
              (go i r) (i < n ? (go (i + 1) (p i = 47 ? (i + 1) r)) (snip p r n))
              (go 0 0))
   (k-slurp p) (open p "r" @ q (port? q ? (slurp q @ t (close q, t))))
   (k-run-text t) (as \ ((: (go cl) (sound cl @ r (two? r ? (ev <r, go >r) 0))) t))
   (k-tool nm as) (elem nm (names ()) ? (ev nm . as))
   ; the crew load reads the roster's files off /love; it hangs off the registry's miss, since
   ; lush answers "not found" from its own lookup. `source` says the load is done
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
   ; the registry is the PATH; `word` makes a slashed word or a .l name a file, never a verb.
   ; a head (path . word) is a shell's PATH search already made, and the path runs
   (k-prog argv) (k-proga (two? <argv ? (<<argv . >argv) argv) 1)
   ; a script's reader: `#!` and its words, then this path and the args; the reader taken by
   ; basename (/bin/sh is sh), one hop
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
                               (two? (stat a0)) (k-progf a0 as h)
                               ; a path the seat lacks is looked for under /love, so `love test/kernel/all.l` runs anywhere
                               (!(47 = peep a0 0 0) && two? (stat ("/love/" + a0)))
                                 (k-progf ("/love/" + a0) as h)
                               ()))))
   ; a wasm module or an ELF runs as a process by its path
   (k-code? t) (string? t && 3 < #t && (snip t 0 4 @ m (m = (string 0) + "asm" || m = (string 127) + "ELF")))
   (k-progf a0 as h) (: t (k-slurp a0)
                        g (0 < h ? (k-bangv t a0 as))
                        (? (two? g) (k-proga g (h - 1))
                           (k-code? t) ((v \ k-procrun ((elem 47 a0 ? a0 ("./" + a0)) . v)) . as)
                           (string? t) (k-run-text t . as)
                           ()))
   (k-slot w n) (task-slot w n)
   ; a task is a process (src/inle/tasks.l), the group's leader on the terminal. argv may be
   ; ['thunk f]: a shell's own stage, run as (f ()), for lush on this forkless seat
   (k-spawn1 argv f0 f1 f2 pg fg)
     (task-run (? (<argv = 'thunk) [<>argv] (k-prog argv)) argv f0 f1 f2 pg fg ttyfg)
   (still p sig) (task-still p sig)
   (k-fdw x) (task-fdw x)
   (spawn argv) (k-spawn1 argv -1 -1 -1 -1 0)
   ; exec: this task becomes the program and never comes back
   (exec argv) (k-prog argv @ pr
                 (two? pr ? (<pr >pr @ r (quit (charm? r ? r 0)))
                    (say err (<argv + ": not found"), put err 10, quit 127)))
   (spawnio argv i o e cl pg fg) (k-spawn1 argv (k-fdw i) (k-fdw o) (k-fdw e) pg fg)
   (spawnmap argv fdm cl pg fg) (task-map fdm (\ a b c (k-spawn1 argv a b c pg fg)))
   (wait p) (task-wait p)
   ; a child on a pty of its own, leading its own group; a watcher stills whichever group
   ; holds the terminal on a key's signal, and a closed master hangs up. -> (pid . master port)
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
   ; hark and herald with no fork: the capture is a scratch file worn as stdout, herald's relay
   ; a dump at the end; stderr stays on the console
   hark-n {}
   ; an unknown word answers (), never a line on the console: `$(shell command -v cc)` asks
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

; processes: programs in memory of their own (src/inle/sys.c). the starting task stands in
; for one and answers its status once the kernel's pipe reads to its end; under kpump the
; waiting tasks hand out their turns
(: k-nul (string 0)
   (k-words l) (foldl (\ s w (s + (w + k-nul))) "" l)
   (k-pump q) (cue? q ? () (kpump 0 @ 0 () 2 (rest 0, k-pump q) _ (rest 10, k-pump q)))
   (k-procrun argv)
     (kproc (k-words argv) (k-words (environ 0)) @ r
        (!(two? r) ? (say err (<argv + ": " + show r), put err 10, 126)
           (: q (fdopen >r) _ (k-pump q) _ (slurp q) _ (close q)
              (kreap <r @ s (charm? s ? s 1)))))
   ; `proc PROG ARGS ..`: love's PROG as a process, woken from the machine's own image
   (proc-main args) (k-procrun args)
   _ (pins (cite 'verbs 'tab) 'proc proc-main))

; a window is the whole screen: (kpaper 1) takes the framebuffer, answers (w h); kshow lays
; rows; (kpaper 0) gives it back. kwin-events answers records as lux/wire.l's x-events
; does: a key by its set-1 code, the pointer in pixels, a new size, the console's text
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
