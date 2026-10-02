; src/inle/seat.l -- the seat text: what this machine is that a host is not. kmain.c runs it
; on both lanes, after the prel and the module layers on the egg's, over the book on a woken
; image's, so its bindings shadow the hosted ones -- getenv reads envt here, not an empty
; environ. src/tools/lcat.l lays it as one C literal, out/lib/seat.h.

; which kernel this is: nothing to probe here, so it is said outright. kore's uname
; respells it through the prel's os-uname.
(: love-os 'inle)
; the environment: a tablet, the pairs on slot 0, closures over it wearing the host's names
; -- getenv the value | (), setenv () | 'badarg (a non-string value unsets), environ the
; raw "NAME=value" strings.
(: envt (tablet 0)
   _ (pin envt 0 (. (. "HOME" "/home") ()))
   (envget l n) (? (two? l) (? (= n (cap (cap l))) (cup (cap l)) (envget (cup l) n)) ())
   (envcut l n) (? (two? l) (? (= n (cap (cap l))) (envcut (cup l) n)
                              (. (cap l) (envcut (cup l) n))) ())
   (getenv n) (? (string? n) (envget (peep envt 0 ()) n) ())
   (setenv n v) (? (string? n)
                   (: c (envcut (peep envt 0 ()) n)
                      _ (pin envt 0 (? (string? v) (. (. n v) c) c)) ())
                   'badarg)
   (environ u) (map (\ e (+ (cap e) (+ "=" (cup e)))) (peep envt 0 ())))
; `bootargv` = (word..) off the raw boot line, split quote-aware. `cmdline` stays seatless
; until the cat is in: a member's seat fires as its own file is read and lush sits mid-cat,
; so it would take the machine with kore's applets unread. the foot wears the real line.
(: bootargv
     (: (kw i w s acc) (? (<= (tally bootline) i) (rev (? (tally w) (. w acc) acc))
                          (: c (bootline i)
; a char joins a string as a string of one: (+ w c) on mixed bands degenerates to w
; alone, so a bare charm would drop every word's letters.
                             (? s (? (= c s) (kw (+ i 1) w 0 acc) (kw (+ i 1) (+ w (string c)) s acc))
                                (= c 32) (kw (+ i 1) "" 0 (? (tally w) (. w acc) acc))
                                (|| (= c 34) (= c 39)) (kw (+ i 1) w c acc)
                                (kw (+ i 1) (+ w (string c)) 0 acc))))
        (kw 0 "" 0 ()))
   cmdline (. "love" ())
   argv cmdline)
; rung 4: spawn/wait as a love-side shim over the core task ops. a process here is a task:
; k-prog maps argv onto a love main -- a registry verb, a tool's own <name>-main, or a .l
; path off the ramfs evaled form by form (no fresh layer, so its defglobs land in the
; session). k-spawn1 seats the pid's stdio in the parent, twirl not switching, so the seat
; is laid before the child's first read. wait is catch; closes are ignored. a group is
; the pid of the task that leads it, and fg hands it the terminal on fd 0 (ttyfg).
; the fs doors by value, off their module: a splice would sit above the kernel's own
; shadows (raw, signal, setenv, environ, the no-op roster below), and those are why
; this seat can run a crew written for a host.
(: open (cite 'posix 'open) close (cite 'posix 'close) stat (cite 'posix 'stat)
   unlink (cite 'posix 'unlink)
   (k-bn p) (: n (tally p)
     (go i r) (? (< i n) (go (+ i 1) (? (= (p i) 47) (+ i 1) r)) (snip p r n))
     (go 0 0))
   (k-slurp p) (: q (open p "r") (? (port? q) (: t (slurp q) _ (close q) t) ()))
   (k-run-text t) (\ as
     ((: (go cl) (: r (sound cl) (? (two? r) (: _ (ev (cap r)) (go (cup r))) 0))) t))
   (k-tool nm as) (? (elem nm (names ())) (. (ev nm) as) ())
; the crew load reads the roster's files off /proc/src and each file's own (module ..)
; form registers it. it hangs off the registry's miss (verbs' fills, installed below), the
; one place every asker walks -- lush answers "not found" from its lookup, so a retry at
; the spawn never runs. `source` is the witness that the load already happened.
   (cwords s i j acc)
    (? (< j (tally s))
       (? (= 32 (peep s j 0))
          (? (< i j) (cwords s (+ j 1) (+ j 1) (. (snip s i j) acc)) (cwords s (+ j 1) (+ j 1) acc))
          (cwords s i (+ j 1) acc))
       (? (< i j) (rev (. (snip s i j) acc)) (rev acc)))
   (cload p) (: q (open (+ "/proc/src/" p) "r")
     (? (port? q)
        (: t (slurp q) _ (close q)
           (go cl) (: r (sound cl) (? (two? r) (: _ (ev (cap r)) (go (cup r))) 0))
           (go t))
        0))
   (crewload _) (? (cite 'source) 0 (: _ (each (cwords crewlist 0 0 ()) cload) 0))
; the registry is the PATH here: apps pin their names into (cite 'verbs 'tab) and `word`
; applies the shadow rules -- a slashed word or a .l name is a file and never a verb, which
; is what leaves the two lanes below reachable. a verb takes the args after its name.
   (k-prog argv) (k-proga argv 1)
; a script says who reads it: `#!`, the words after it, then this path and the args. the
; reader is taken by basename -- usr/bin is empty, so /bin/sh is sh. one hop.
   (k-bangv t p as)
    (? (! (&& (string? t) (&& (< 2 (tally t)) (= "#!" (snip t 0 2))))) ()
       (: n (tally t)
          (go i) (? (< i n) (? (= 10 (peep t i 0)) i (go (+ i 1))) n)
          w (cwords (snip t 2 (go 0)) 0 0 ())
          (? (two? w) (. (k-bn (cap w)) (+ (cup w) (. p as))) ())))
   (k-proga argv h) (: a0 (cap argv) b (k-bn a0) as (cup argv)
     v (cite 'verbs 'word a0)
     (? !(nil? v) (. v as)
        (: k (k-tool (intern (+ b "-main")) as)
           (? (two? k) k
; `kore TOOL ..` where no dispatcher registered one: the test kernel bakes the applets
              (&& (= b "kore") (two? as))
                (k-tool (intern (+ (cap as) "-main")) (cup as))
              (two? (stat a0)) (k-progf a0 as h)
; a path the seat has not got is looked for on the tarball, so `love test/kernel/all.l`
; names the corpus from any seat, off the bake's own rows and never a tree somebody edited
              (&& (! (= 47 (peep a0 0 0))) (two? (stat (+ "/proc/src/" a0))))
                (k-progf (+ "/proc/src/" a0) as h)
              ()))))
   (k-progf a0 as h) (: t (k-slurp a0)
                 g (? (< 0 h) (k-bangv t a0 as) ())
                 (? (two? g) (k-proga g (- h 1))
                    (string? t) (. (k-run-text t) as)
                    ()))
   (k-slot w n) (? (! (two? w)) () (n = 0) (cap w) (k-slot (cup w) (n - 1)))
; a console-numbered fd means the parent's view of it, so 2>&1 follows what the parent
; wears; anything higher is duped, the port owning the copy from there.
   (k-port w n f) (? (! (charm? f)) (k-slot w n) (f < 0) (k-slot w n)
                     (f < 3) (k-slot w f) (fdopen (dup f)))
; what a signal needs of a task: its group, its own ends, and the status it leaves
   k-grp {} k-ends {} k-died {} k-held {}
   (k-spawn1 argv f0 f1 f2 pg fg) (: pr (k-prog argv)
     w (worn ())
     kw [(k-port w 0 f0) (k-port w 1 f1) (k-port w 2 f2)]
; the ends duped for the child are its own, the ones a stop closes for it
     own (k-own [f0 f1 f2] kw)
; worn across the twirl, which does not switch tasks: the child inherits node[7] and
; nothing of ours runs in between, so the parent takes its own back on the next line.
     _ (wear kw)
; the help is the exit door too: a kore main leaves deep by scaring 'leave with its status
; (src/apps/kore/core.l), and a plain scare would flatten every usage code to 1.
     p (twirl (\ _ (: _ (hear (\ a b (? (== a 'leave) (quit b)
                                        (: _ (say err ";; ") _ (print err a)
                                           _ (say err " ") _ (print err b)
                                           _ (put err 10) (quit 1)))))
                     r (? (two? pr) ((cap pr) (cup pr))
                          (: _ (say err (+ (cap argv) ": not found"))
                             _ (put err 10) 127))
                     (quit (? (charm? r) r 0))))
              0)
     _ (wear w)
     _ (k-seat p own pg fg)
     p)
   (k-own fs ps) (? (! (two? fs)) ()
                    (&& (charm? (cap fs)) (< 2 (cap fs))) (. (cap ps) (k-own (cup fs) (cup ps)))
                    (k-own (cup fs) (cup ps)))
   (k-seat p own pg fg)
     (: gp (? (! (charm? pg)) () (< pg 0) () (= pg 0) p pg)
        _ (pin k-ends p own)
        _ (? (charm? gp) (pin k-grp p gp) 0)
        (? (&& (charm? gp) (&& (charm? fg) (< 0 fg))) (ttyfg gp) 0))
   (k-members gp) (k-mem gp (keys k-grp))
   (k-mem gp ks) (? (! (two? ks)) ()
                    (&& (= gp (peep k-grp (cap ks) ())) (! (landed? (cap ks))))
                      (. (cap ks) (k-mem gp (cup ks)))
                    (k-mem gp (cup ks)))
; kill at task granularity: a stop holds the task (pause) and wait answers 256+sig for it,
; cont lets it go on (resume), and every other signal ends it where it stands, closing the ends
; it was handed, wait answering 128+sig. each status is laid before the task moves: a close
; can yield, and the waiter wakes the moment the task is held or gone
   (k-stop t sig)
     (? (= sig 18) (: _ (pull k-held t 0) (resume t))
        (|| (= sig 19) (|| (= sig 20) (|| (= sig 21) (= sig 22))))
          (: _ (pin k-held t (+ 256 sig)) (pause t))
        (: _ (pin k-died t (+ 128 sig)) _ (pull k-held t 0) _ (freeze t)
           _ (each (peep k-ends t ()) close) (pull k-ends t 0)))
   (still p sig)
     (? (|| (! (charm? p)) (! (charm? sig))) (nom 'badarg)
        (: ts (? (< p 0) (k-members (- 0 p)) (landed? p) () (. p ()))
           (? (! (two? ts)) (nom 'esrch)
              (= sig 0) 0
              (: _ (each ts (\ t (k-stop t sig))) 0))))
   (k-fdw x) (? (charm? x) (? (< x 0) (- 0 1) x) (- 0 1))
   (spawn argv) (k-spawn1 argv (- 0 1) (- 0 1) (- 0 1) (- 0 1) 0)
; exec at task granularity: this task becomes the program and never comes back
   (exec argv) (: pr (k-prog argv)
     (? (two? pr) (: r ((cap pr) (cup pr)) (quit (? (charm? r) r 0)))
        (: _ (say err (+ (cap argv) ": not found")) _ (put err 10) (quit 127))))
   (spawnio argv i o e cl pg fg) (k-spawn1 argv (k-fdw i) (k-fdw o) (k-fdw e) pg fg)
   (spawnmap argv fdm cl pg fg)
     ((: (go m a b c)
          (? (atom? m) (k-spawn1 argv a b c pg fg)
             (: e (cap m) cf (cap e) sf (cup e)
                v (? (charm? sf)
                     (? (&& (<= 0 sf) (< sf 3))
                        (: w (? (= sf 0) a (= sf 1) b c) (? (< w 0) sf w))
                        sf)
                     (- 0 2))
                (? (= cf 0) (go (cup m) v b c)
                   (= cf 1) (go (cup m) a v c)
                   (= cf 2) (go (cup m) a b v)
                   (go (cup m) a b c))))
        go)
      fdm (- 0 1) (- 0 1) (- 0 1))
   (wait p) (: r (catch p) h (peep k-held p ())
     (? (charm? h) h
        (: d (peep k-died p ())
           _ (pull k-died p 0) _ (pull k-grp p 0) _ (pull k-ends p 0)
           (? (charm? d) d r))))
; a child on a pty of its own, as the host's tether: it leads its own group, which takes the
; terminal, and a watcher answers a key's signal by stilling whichever group holds it then.
; the master closed is a hangup, to that group and to the child, and the watcher ends. -> (pid . master port)
   (tether argv) (: fs (openpty 0)
     (? (! (two? fs)) fs
        (: m (cap fs) sl (cap (cup fs)) sg (cap (cup (cup fs)))
           w (worn ()) sp (fdopen (dup sl))
           _ (wear [sp sp sp])
           p (k-spawn1 argv sl sl sl 0 1)
           _ (wear w)
           _ (close sp) _ (close sl)
           _ (twirl (\ _ (k-sigs (fdopen sg) p)) 0)
           (. p (fdopen m)))))
   (k-sigs q p) (: c (see q)
     (? (< c 0) (close q)
        (: g (ttypg q) _ (? (&& (charm? g) (< 0 g)) (still (- 0 g) c) 0)
; a hangup reaches the child that holds the session as well as the group in front
           _ (? (&& (= c 1) (! (= g p))) (still (- 0 p) c) 0)
           (k-sigs q p))))
; hark and herald on a seat with no fork: the capture is a scratch file worn as the child's
; stdout and herald's relay is a dump at the end. stderr stays on the console.
   hark-n {}
; a word nothing answers is an answer here, never a line on the console -- what a hosted
; hark's errno is, and `$(shell command -v cc)` is the caller asking.
   (hark1 argv tee) (? (! (two? (k-prog argv))) ()
      (: w (worn ())
         k (+ 1 (peep hark-n 0 0))
         _ (pin hark-n 0 k)
         p (+ "/tmp/.hark" (show k))
         q (open p "w")
         (? (! (port? q)) ()
; the child reads nothing, the way a hosted hark hands its own /dev/null
            (: z (open "/dev/null" "r")
               _ (wear [(? (port? z) z (k-slot w 0)) q (k-slot w 2)])
               d (spawn argv)
               st (? (&& (charm? d) (<= 0 d)) (wait d) 127)
               _ (wear w)
               _ (close q)
               _ (? (port? z) (close z) 0)
               r (open p "r")
               t (? (port? r) (: b (slurp r) _ (close r) b) "")
               _ (unlink p)
               _ (? tee (puts t) 0)
               (. (? (charm? st) st 0) t)))))
   (hark argv) (hark1 argv 0)
   (herald argv) (hark1 argv 1))
