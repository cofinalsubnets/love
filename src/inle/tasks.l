; src/inle/tasks.l -- a task as a process: the shell's own stages run in its heap, each a
; twirled task with its own stdio, group and status. the kernel's processes are these, and a
; process on inle runs the shell's compound stages the same way. src/tools/lcat.l lays it as
; one literal; src/inle/kmain.c runs it on the egg lane, src/love/main.c bakes it.
(: task-grp {} task-ends {} task-died {} task-held {}
   task-close (cite 'posix 'close)
   (task-slot w n) (? !(two? w) () (n = 0) <w (task-slot >w (n - 1)))
   ; a console-numbered fd is the parent's view of it, so 2>&1 follows what the parent wears;
   ; anything higher is duped, the port owning the copy from there
   (task-port w n f) (? !(charm? f) (task-slot w n) (f < 0) (task-slot w n) (f < 3) (task-slot w f)
                        (fdopen (dup f)))
   (task-own fs ps) (? !(two? fs) ()
                       (charm? <fs && 2 < <fs) (<ps . task-own >fs >ps)
                       (task-own >fs >ps))
   ; pr is (f . args), or () for a word nothing answers. the child's stdio is seated in the
   ; parent, twirl not switching, so it is laid before the child's first read; the parent takes
   ; its own back on the next line. a group is the pid of the task that leads it; fgf hands it
   ; the terminal when fg says so.
   (task-run pr argv f0 f1 f2 pg fg fgf)
     (: w (worn ())
        kw [(task-port w 0 f0) (task-port w 1 f1) (task-port w 2 f2)]
        own (task-own [f0 f1 f2] kw)              ; the ends duped for it, which a stop closes
        _ (wear kw)
        ; the help is the exit door too: a kore main leaves deep by scaring 'leave with its
        ; status, and a plain scare would flatten every usage code to 1
        p (twirl (_ \ (: _ (hear (a \ b \ (a == 'leave ? (quit b)
                                             (say err ";; ", print err a, say err " ", print err b,
                                              put err 10, quit 1))))
                         r (two? pr ? (<pr >pr) (say err (<argv + ": not found"), put err 10, 127))
                         (quit (charm? r ? r 0))))
                 0)
        (wear w, task-seat p own pg fg fgf, p))
   (task-seat p own pg fg fgf)
     ((? !(charm? pg) () (pg < 0) () (pg = 0) p pg) @ gp
        (pin task-ends p own,
         (charm? gp ? (pin task-grp p gp) 0),
         (charm? gp && charm? fg && 0 < fg ? (fgf gp) 0)))
   ; a task this door started and nobody has waited for yet
   (task? p) (charm? p && (!(charm? (peep task-ends p 0)) || charm? (task-died p) || charm? (task-held p)))
   ; a child's fd map under the stdio the running task wears: its ports first, as 0 1 2, so
   ; a source under 3 later in the map reads them too
   (task-worn m) (: w (worn ())
                    (go i l) (? !(two? l) m (port? <l) ((i . <l) . go (i + 1) >l) (go (i + 1) >l))
                    (two? w ? (go 0 w) m))
   (task-members gp) (task-mem gp (keys task-grp))
   (task-mem gp ks) (? !(two? ks) ()
                       (gp = task-grp <ks && !(landed? <ks)) (<ks . task-mem gp >ks)
                       (task-mem gp >ks))
   ; kill at task granularity: a stop holds the task (pause), wait answering 256+sig for it; a
   ; cont lets it go on (resume); any other signal ends it where it stands, closing the ends it
   ; was handed, wait answering 128+sig. each status is laid before the task moves, since the
   ; waiter wakes the moment the task is held or gone -- and an end closes before it is gone, so
   ; a waiter that reads it next finds the end, however the closes yield
   (task-stop t sig)
     (? (sig = 18) (pull task-held t 0, resume t)
        (19 <= sig <= 22) (pin task-held t (256 + sig), pause t)
        (pin task-died t (128 + sig), pull task-held t 0, each (task-ends t) task-close,
         pull task-ends t 0, freeze t))
   ; -> the tasks a pid names: a group's live members, or the one task
   (task-named p) (? (p < 0) (task-members -p) (landed? p) () [p])
   (task-still p sig)
     (!(charm? p) || !(charm? sig) ? (nom 'badarg)
        (task-named p @ ts
           (? !(two? ts) (nom 'esrch)
              (sig = 0) 0
              (each ts (t \ task-stop t sig), 0))))
   (task-wait p) (: r (catch p) h (task-held p)
                   (charm? h ? h
                      (task-died p @ d (pull task-died p 0, pull task-grp p 0, pull task-ends p 0,
                                         (charm? d ? d r)))))
   ; a spawnmap's (child-fd . source-fd) pairs onto the three slots, the parent's worn view
   ; for a console-numbered source; -1 leaves a slot as the parent wears it
   (task-map fdm k)
     ((: (go m a b c)
          (atom? m ? (k a b c)
             (: e <m cf <e sf >e
                v (charm? sf ? (0 <= sf < 3 ? ((? (sf = 0) a (sf = 1) b c) @ w (w < 0 ? sf w)) sf) -2)
                (? (cf = 0) (go >m v b c)
                   (cf = 1) (go >m a v c)
                   (cf = 2) (go >m a b v)
                   (go >m a b c))))
        go)
      fdm -1 -1 -1)
   (task-fdw x) (charm? x ? (x < 0 ? -1 x) -1))
