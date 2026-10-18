; init: a service supervisor sketch -- deps, restart policy, checkpoint
;   (demos 0) models services as green tasks, a crash a scare welped to (); then (real 0)
;   (real 0) runs OS processes: (spawn argv) forks+execs, (glean _) reaps
; run: out/love -l src/apps/init/init.l -e "(demos 0)"

(borrow 'posix)
(: (note s) (puts s, puts "\n")

   ; a unit is (name kind cmd restart deps): kind 'oneshot (an argv for hark) or 'service
   ; (a thunk); restart 'no | 'on-fail | 'always; deps must be up before it starts
   (unit name kind cmd restart deps) [name kind cmd restart deps]
   (u-name u) (u 0)   (u-kind u) (u 1)   (u-cmd u) (u 2)
   (u-restart u) (u 3) (u-deps u) (u 4)
   (find units name) (!units ? ()                    ; the unit with this name, or ()
                        (u-name <units = name ? <units (find >units name)))
   (rev l) (foldl (a \ x \ (. x a)) () l)

   ; the registry: a book name -> 'up | 'done | 'failed, absent 'down
   (up? reg name) (peep reg name 'down @ s (s = 'up ? 1 (s = 'done)))

   ; the watchdog: a faulting thunk welps to (), so catch is falsey; restart per policy,
   ; counting in cnt, up to tries-cap
   tries-cap 3
   (supervise name thunk policy cnt)
     (: p (twirl thunk 0)
        r (catch p)
        (r ? 1
           (1 + peep cnt name 0 @ n (pin cnt name n,
                                     (? (policy = 'no ? 0 (n < tries-cap))
                                        (note ("    " + show name + " crashed -> restart #" + show n),
                                         supervise name thunk policy cnt)
                                        (note ("    " + show name + " gave up"), ()))))))

   ; a oneshot is a real child, its exit deciding done/failed; a service is supervised
   (start1 reg cnt u)
     (u-name u @ name
        (u-kind u = 'oneshot ?
             (: res  (hark (u-cmd u))
                code <res  text >res                   ; (exit . stdout)
                (note ("  [oneshot] " + show name + " -> \"" + text + "\" (exit " + show code + ")"),
                 pin reg name (code = 0 ? 'done 'failed)))
           (supervise name (u-cmd u) (u-restart u) cnt @ ok
              (note ("  [service] " + show name + (ok ? " up" " FAILED")),
               pin reg name (ok ? 'up 'failed)))))

   ; deps first, depth first; up? dedups a shared dep. no cycle check
   (ensure reg cnt units name)
     (up? reg name ? reg
        (: u    (find units name)
           reg' (foldl (r \ d \ ensure r cnt units d) reg (u-deps u))  ; deps first (a fresh
           (start1 reg' cnt u)))                                       ; name: a self-rebind reads missing)
   (boot units) ({} @ cnt
                   (foldl (reg \ u \ ensure reg cnt units (u-name u)) {} units))

   ; shutdown: reverse start order, modeled as a status flip
   (stop1 reg name) (note ("  stop " + show name), pin reg name 'down)
   (shutdown reg names) (foldl stop1 reg names)

   ; checkpoint: a book does not round-trip through show/read; this list does
   (snap reg names) (map (n \ [n (peep reg n 'down)]) names))

; the watchdog as the global help: a service's fault becomes () for its catch
(hear welp)

; the real supervisor over OS processes: spawn each unit, poll glean, map each dead pid
; back to its unit and restart a nonzero exit per policy. pids: pid->name, tries: restarts
(: (rstart pids u)                                    ; spawn one unit, record pid->name
     (spawn (u-cmd u) @ pid
        (pin pids pid (u-name u),
         note ("  spawn " + show (u-name u) + " pid=" + show pid),
         pid))
   ; until every service settles (live 0) or steps run out; a nonzero exit under
   ; on-fail within the cap respawns, live unchanged
   (rloop units pids tries live steps)
     (? (live < 1 ? 1 (steps < 1)) 0
        (glean 0 @ ev
           (two? ev ?                                 ; (pid . status)
                (: nm (peep pids <ev 0)  st >ev
                   u  (find units nm)
                   n  (1 + peep tries nm 0)  (pin tries nm n,
                                              note ("  exit " + show nm + " status=" + show st),
                                              (? (st = 0 ? 0 (u-restart u = 'on-fail ? (n < tries-cap) 0))
                                                   (note ("    restart " + show nm + " #" + show n),
                                                    rstart pids u,
                                                    rloop units pids tries live (steps - 1))
                                                   (rloop units pids tries (live - 1) (steps - 1)))))
              (rest 2, rloop units pids tries live (steps - 1)))))            ; nothing yet: wait
   (real _)
     (: pids {} tries {}
        units [
         (unit 'worker 'service ["sh" "-c" "exit 0"] 'on-fail ())       ; exits 0 -> settles
         (unit 'flaky  'service ["sh" "-c" "exit 1"] 'on-fail ())]      ; exits 1 -> restart, then give up
        (note "-- REAL processes: spawn each, then poll glean (the SIGCHLD core) --",
         each units (u \ rstart pids u),
         rloop units pids tries #units 500,
         note "-- all real children reaped --")))

; perceive: park on a signalfd (await), merged with a heartbeat's timer in one wait;
; SIGCHLD drains glean, a queued SIGTERM ends the loop. linux numbers: CHLD 17, TERM 15
(: sig-chld 17  sig-term 15
   (heart n ms) (n < 1 ? 0 (rest ms, note "  . beat", heart (n - 1) ms))

   ; SIGCHLD coalesces, so glean until it drains; answers the new live count
   (harvest units pids tries live)
     (glean 0 @ ev
        (atom? ev ? live
           (: nm (peep pids <ev 0)  st >ev
              u  (find units nm)
              n  (1 + peep tries nm 0)  (pin tries nm n,
                                         note ("  glean " + show nm + " status=" + show st),
                                         (? (st = 0 ? 0 (u-restart u = 'on-fail ? (n < tries-cap) 0))
                                              (note ("    restart " + show nm), rstart pids u,
                                               harvest units pids tries live)
                                              (harvest units pids tries (live - 1)))))))

   (watch sig units pids tries live)
     (live < 1 ? (note "  all services settled")
        (: _  (await sig)                                ; cooperative; merges with the heartbeat
           ev (sigtake sig)
           (? (<ev = sig-term) (note "  SIGTERM: a queued EVENT, not a kill -> shut down")
              (<ev = sig-chld) (watch sig units pids tries (harvest units pids tries live))
              (watch sig units pids tries live))))

   (perceive _)
     (sigfd 0 @ sig
        (? !(hot? sig) (note "  perceive: no signal source here")
           (: pids {} tries {}
              units [(unit 'slow 'service ["sh" "-c" "sleep 0.15; exit 0"] 'on-fail ())
                     (unit 'flap 'service ["sh" "-c" "exit 1"]             'on-fail ())]
              _ (note "-- PERCEIVE: park on a signalfd; a heartbeat task ticks alongside (the merge) --")
              hb (twirl (_ \ (heart 5 40)) 0)             ; parks on the clock
              (each units (u \ rstart pids u),
               watch sig units pids tries #units,
               catch hb,                                 ; the orphan law
               0)))))

; pid1 bringup: mount early filesystems, place a process in a cgroup. unprivileged via
; (newns 0): tmpfs mounts, proc needs a pid-ns too; a cgroup-v2 placement is a pid written
; to cgroup.procs
(: (cg-write path s)                                     ; write s to a cgroup control file
     (open path "w" @ p (hot? p ? (say p s, flush p, close p, 'ok) 'denied))
   (try-mount src tgt typ)
     (: _ (mkdir tgt 493)
        r (mount src tgt typ)                            ; () success, else an error
        (note ("  mount " + typ + " on " + tgt
               + (r < 0 ? (" -> EPERM (errno " + show (0 - r) + ", needs root/pid-ns)") " -> ok"))))
   (boot-system _)
     (newns 0 @ e
        (note (e < 0 ? "-- pid1 bringup: (no unpriv userns here; a real pid1 is root) --"
                       "-- pid1 bringup: private user+mount ns (root-in-ns) --"),
         try-mount "tmpfs" "/tmp/love-run"  "tmpfs",
         try-mount "proc"  "/tmp/love-proc" "proc",        ; needs a pid-ns too
         note "-- cgroup-v2: mkdir a group, write a pid to cgroup.procs --",
         (: d "/sys/fs/cgroup/love.demo"
            _ (mkdir d 493)
            r (cg-write (d + "/cgroup.procs") (show (getpid 0) + "\n"))
            (note ("  place self in " + d + (r = 'ok ? " -> ok" " -> needs root / a delegated subtree")))),
         0)))

; boot as pid 1 (`make init-container`): getpid is 1, proc mounts, and glean (waitpid(-1))
; reaps reparented orphans love never spawned. (perceive 0) is the live supervisor
(: (mount1 src tgt typ)
     (: _ (mkdir tgt 493) r (mount src tgt typ)          ; () success, else an error
        (note ("  mount " + typ + " on " + tgt + (r ? (" -> errno " + show r) " -> ok"))))

   ; glean until target children are collected or steps run out; a pid absent from pids
   ; is a reparented orphan; a non-pair glean just paces the loop
   (glean-tour pids got target steps)
     (? (steps < 1 ? 1 (got >= target)) got
        (glean 0 @ ev
           (two? ev ?
                (: pid <ev st >ev nm (peep pids pid ())
                   (note ((nm ? ("  glean " + show nm + " (a service we started)")
                                "  glean an ORPHAN (reparented to us -- pid 1's duty)")
                          + " pid=" + show pid + " status=" + show st),
                    glean-tour pids (got + 1) target (steps - 1)))
              (rest 5, glean-tour pids got target (steps - 1)))))

   (pid1 _)
     (: me (getpid 0)
        _ (note ("-- love as PID " + show me
                 + (me = 1 ? " -- a real init --" " (NOT pid 1: use `make init-container`) --")))
        _ (note "-- mount the early filesystems (root in a pid-ns -> proc mounts) --")
        _ (mount1 "tmpfs" "/tmp/love-run"  "tmpfs")
        _ (mount1 "proc"  "/tmp/love-proc" "proc")
        pids {}
        _ (note "-- spawn a child that orphans a grandchild, then glean (pid 1's duty) --")
        p (spawn ["sh" "-c" "(sleep 0.2; exit 7) & exit 0"])      ; grandchild orphaned
        _ (pin pids p 'orphan-parent)
        n (glean-tour pids 0 2 800)
        (note ("-- reaped " + show n + " children, one a reparented orphan -- love supervised pid 1 --"),
         0)))

; --- the demos ---
(: (demos _)
   (: cr {}
      ; crashes until its k-th start, then runs clean
      svc    (name \ k \ (_ \ (1 + peep cr name 0 @ n (pin cr name n,
                                                       n < k ? (scare 'crash name) 'ok))))
      ok-svc (_ \ 'ok)
      units [
       (unit 'netd    'service ok-svc            'on-fail ())
       (unit 'logd    'service ok-svc            'on-fail ())
       (unit 'dbusd   'service ok-svc            'on-fail ['logd])
       (unit 'app     'service (svc 'app 3)      'on-fail ['netd 'dbusd])       ; crashes twice, then up
       (unit 'brittle 'service (svc 'brittle 9)  'no      ())                   ; Restart=no -> failed
       (unit 'hello   'oneshot ["echo" "-n" "init: a real child says hi"]
                                                 'no      ['app])]
      _   (note "-- love-init: bring up the unit graph (deps first; services modeled, oneshot real) --")
      reg (boot units)
      (note "-- final state (the checkpoint -- a show/read-able value) --",
       each (snap reg (map u-name units))
            (pr \ note ("  " + show <pr + " = " + show (caup pr))),
       note "-- graceful shutdown (reverse start order) --",
       shutdown reg (rev (map u-name units)),
       note "",
       real 0)))
