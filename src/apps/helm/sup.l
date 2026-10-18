#!/usr/bin/env -S love -l
; src/apps/helm/sup.l -- the supervisor: units become processes, and stay processes.
;
; perceive is a park on a signalfd, never a poll: SIGCHLD and SIGTERM queue to an fd,
; so TERM is a graceful event, and the scheduler folds that fd into one wait with the
; moor's accept loop. neither spins.
;
; every child leads its own process group, so one signal to -pid stops its whole tree.
;
; all live state is one book, `helm-cell` (one supervisor per process):
;   'units   the config's units, in file order
;   'conf    the path they were read from
;   'st      name -> a status tablet (state pid tries code since)
;   'pids    pid -> name, the reverse the reaper needs
;   'order   the names that came up, newest first
;   'events  recent event lines, newest first: helm's journal
(module 'helm
(borrow 'posix)
(: helm-cell {}
   (hcell k d) (peep helm-cell k d)
   (hput k v)  (pin helm-cell k v)

   sig-hup 1  sig-int 2  sig-kill 9  sig-term 15  sig-chld 17
   hpatience 3000    ; ms a TERM'd child gets before the KILL
   hsteady   2000    ; ms of life that clears a service's restart count

   ; --- the live state ---
   (helm-reset us)
    (hput 'units us, hput 'st {}, hput 'pids {}, hput 'order [], us)
   (hunits-now _) (hcell 'units [])
   (hpids _)      (hcell 'pids () @ t (tablet? t ? t ({} @ n (hput 'pids n, n))))
   (hstat nm)
    (: t (hcell 'st ())
       b (tablet? t ? t ({} @ n (hput 'st n, n)))
       s (b nm)
       (s ? s
          ((pins {} 'name nm 'state 'down 'pid 0 'tries 0 'code () 'since (clock 0)) @ n
             (pin b nm n, n))))
   (hstate nm)    (peep (hstat nm) 'state 'down)
   (hmark nm k v) (pin (hstat nm) k v)
   (hup? nm)      (hstate nm @ s (s == 'up || s == 'done))

   ; --- the narrator: a bounded ring the moor reads, and stderr unless quiet ---
   (htake l n) (n < 1 || atom? l ? () (<l . htake >l (n - 1)))
   (hnote s)
    (hput 'events (htake (s . hcell 'events []) 200),
     hcell 'quiet 0 ? 0 (say err ("helm: " + s + "\n"), flush err),
     s)

   ; --- the child's environment ---
   ; set before the fork, put back after; spawnmap never parks, so no task sees the gap.
   ; no unsetenv nif: an invented name goes back as empty.
   (henv-pairs l) (atom? l || atom? >l ? []
                     (: k <l v <>l ([k v] . henv-pairs >>l)))
   (henv-with l f)
    (: ps  (henv-pairs l)
       old (map (\ [k v] [k (getenv k)]) ps)
       _   (each ps (\ [k v] (setenv k v)))
       r   (f 0)
       (each old (\ [k v] (setenv k (string? v ? v ""))),
        r))

   ; --- act: make the process ---
   ; stdin /dev/null, stdout and stderr to the unit's log (appended) or ours
   (hspawn u)
    (: argv (peep u 'exec [])
       lp   (u 'log)
       lfd  (string? lp ? (openfd lp 2) -1)
       nfd  (openfd "/dev/null" 0)
       i    (0 <= nfd ? nfd 0)
       o    (0 <= lfd ? lfd 1)
       e    (0 <= lfd ? lfd 2)
       fm   [(0 . i) (1 . o) (2 . e)]
       cl   (filter (f \ 2 < f) [lfd nfd])
       d    (u 'dir)
       old  (cwd 0)
       _    (string? d ? (chdir d) 0)
       pid  (henv-with (peep u 'env []) (_ \ (spawnmap argv fm cl 0 0)))
       (string? d ? (chdir old) 0,
        each cl (f \ close f),
        pid))

   ; --- act: one unit up ---
   ; a target is reached when its wants are. a oneshot BLOCKS, which is what gives
   ; `after` on it meaning.
   (hstart1 u)
    (: nm   (u 'name)
       kind (u 'kind)
       (kind == 'target
        ? (hmark nm 'state 'done, hnote ("target " + string nm + " reached"), 1)
          (hspawn u @ pid
             (? !(charm? pid && 0 < pid)
                  (hmark nm 'state 'failed,
                   hnote ("cannot spawn " + string nm + ": errno " + show (0 - pid)),
                   0)
                (pin (hpids 0) pid nm,
                 hmark nm 'pid pid,
                 hmark nm 'since (clock 0),
                 hmark nm 'state 'up,
                 hput 'order (nm . hcell 'order []),
                 hnote (string kind + " " + string nm + " pid " + show pid),
                 kind == 'oneshot ? (hwait nm pid hpatience) 1)))))

   ; --- perceive: a child died ---
   ; every dead pid comes here, ours or not: pid 1 reaps reparented orphans.
   (hreaped pid st)
    (: pids (hpids 0)
       nm   (pids pid)
       (!nm ? (hnote ("reaped orphan pid " + show pid + " status " + show st))
          (pull pids pid 0,
           (: u     (hby (hunits-now 0) nm)
             s     (hstat nm)
             kind  (u 'kind)
             rs    (peep u 'restart 'no)
             lived (clock 0 - peep s 'since 0)
             n     (hsteady < lived ? 0 (peep s 'tries 0))
             was   (s 'state)
             (hmark nm 'code st,
              hmark nm 'pid 0,
              hnote (string nm + " exited " + show st),
             ; a reload can drop a unit whose child still runs: reap, no policy.
              (? !u (hmark nm 'state 'down)
                 (was == 'stopping || hcell 'shutting 0) (hmark nm 'state 'down)
                 (kind == 'oneshot) (hmark nm 'state (st == 0 ? 'done 'failed))
                 (: want (rs == 'always || rs == 'on-fail && st != 0)
                    lim  (peep u 'tries 3)
                    (want && n < lim ?
                         (hmark nm 'tries (n + 1),
                          hmark nm 'state 'down,
                          hnote ("restart " + string nm + " #" + show (n + 1)),
                          hstart1 u)
                       (hmark nm 'state (st == 0 ? 'done 'failed),
                        want ? (hnote (string nm + " gave up after " + show n + " restarts")) 0,
                        0)))))))))

   ; drain every dead child: SIGCHLD coalesces.
   (hdrain _) (glean 0 @ e (two? e ? (hreaped <e >e, hdrain 0) 0))
   ; wait for a unit's recorded pid to clear -- this drain during boot or hloop's after
   ; may reap it. `rest` yields, so other tasks keep running.
   (hwait nm pid ms)
    (: t0 (clock 0)
       (go _) (hdrain 0,
               (? (peep (hstat nm) 'pid 0 != pid) 1
                  (clock 0 - t0 > ms) 0
                  (rest 5, go 0)))
       (go 0))

   ; --- decide: dependency order ---
   ; `after` first, depth first; `seen` guards a cycle in a config edited since hcheck.
   (hensure nm seen)
    (? (hup? nm) 1
       (elem nm seen) (hnote ("after cycles at " + string nm), 0)
       (hby (hunits-now 0) nm @ u
          (!u ? (hnote ("no unit " + string nm), 0)
             (each (peep u 'after []) (d \ hensure d (nm . seen)), hstart1 u))))

   (hboot nm)
    (hby (hunits-now 0) nm @ u
       (? !u (hnote ("no unit " + string nm), 0)
          (u 'kind == 'target)
            (each (peep u 'wants []) (w \ hensure w []), hstart1 u)
          (hensure nm [])))

   ; the `default` target if named, else every runnable unit in file order
   (hboot-all _)
    (hby (hunits-now 0) 'default @ d
       (d ? (hboot 'default)
          (each (hunits-now 0)
                (u \ (u 'kind == 'target ? 0 (hensure (u 'name) []))))))

   ; --- act: one unit down ---
   ; 'stopping suspends the restart policy for one exit; -pid takes the group whole.
   (hstop1 nm)
    (: s   (hstat nm)
       pid (peep s 'pid 0)
       (? !(charm? pid && 0 < pid) (hmark nm 'state 'down, 1)
          (hmark nm 'state 'stopping,
           still (0 - pid) sig-term,
           hnote ("term " + string nm + " pid " + show pid),
           hwait nm pid hpatience @ ok
             (ok ? 1 (still (0 - pid) sig-kill, hnote ("kill " + string nm),
                      hwait nm pid hpatience)))))

   (hbounce nm) (hstop1 nm, hmark nm 'tries 0, hensure nm [])

   ; shutdown walks 'order newest first: dependents before what they depend on. the flag
   ; suspends restarts for the walk.
   (hshutdown _)
    (hput 'shutting 1, each (hcell 'order []) (nm \ hstop1 nm), hnote "all stopped", 1)

   ; --- reload: re-read the config and adopt it; nothing restarts ---
   (hreload _)
    (: r  (hconf (hcell 'conf "/etc/helm.l"))
       us <r
       (each <>r (g \ hnote ("config: " + g)),
        two? us ? (hput 'units us, hnote ("config: " + show #us + " units")) 0,
        #us))

   ; --- the loop: park on the signal source ---
   (hloop sig)
    (await sig,
     (: ev (sigtake sig)
        s  (two? ev ? <ev 0)
        (? (s == sig-chld) (hdrain 0, hloop sig)
           (s == sig-hup)  (hreload 0, hloop sig)
           (s == sig-term || s == sig-int)
             (hnote ("signal " + show s + " -- shutting down"), hshutdown 0, 0)
           (hloop sig))))

   ; --- introspection ---
   (hpad s n) (n <= #s ? s (hpad (s + " ") n))
   (hstatus-line nm)
    (hstat nm @ s
       (hpad (string nm) 16 + hpad (string (peep s 'state 'down)) 10
        + "pid " + hpad (show (peep s 'pid 0)) 8
        + "tries " + show (peep s 'tries 0)
        + (s 'code @ c (charm? c ? (" last " + show c) ""))))))
