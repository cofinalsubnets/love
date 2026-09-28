#!/usr/bin/env -S love -l
; apps/helm/sup.l -- the supervisor: units become processes, and stay processes.
;
; perceive, decide, act. perceive is a PARK on a signalfd (src/posix.c's sigfd),
; never a poll: SIGCHLD and SIGTERM are blocked at the source so they queue to an
; fd, which is what makes a TERM a graceful event instead of a death, and love's
; scheduler folds that fd in with every other parked task -- the control
; socket's accept loop among them -- into one wait. so the moor answers while the
; supervisor sleeps, and neither one spins.
;
; every child leads its OWN process group (spawnmap's pg 0), so stopping a unit
; is one signal to a negative pid and takes the whole tree it forked.
;
; all the live state is one book, `helm-cell`, because a supervisor IS its state
; and there is exactly one per process. what rides it:
;   'units   the config's units, in file order
;   'conf    the path they were read from
;   'st      name -> a status tablet (state pid tries code since)
;   'pids    pid -> name, the reverse the reaper needs
;   'order   the names that came up, newest first -- shutdown walks it as-is
;   'events  the recent event lines, newest first: helm's whole journal
(module 'helm
(borrow 'posix)
(: helm-cell {}
   (hcell k d) (peep helm-cell k d)
   (hput k v)  (pin helm-cell k v)

   sig-hup 1  sig-int 2  sig-kill 9  sig-term 15  sig-chld 17
   hpatience 3000    ; ms a TERM'd child gets before the KILL
   hsteady   2000    ; ms of life that clears a service's restart count

   ; --- the live state --------------------------------------------------------
   (helm-reset us)
    (hput 'units us, hput 'st {}, hput 'pids {}, hput 'order [], us)
   (hunits-now _) (hcell 'units [])
   (hpids _)      (: t (hcell 'pids ()) (tablet? t ? t (: n {} (hput 'pids n, n))))
   (hstat nm)
    (: t (hcell 'st ())
       b (tablet? t ? t (: n {} (hput 'st n, n)))
       s (b nm)
       (s ? s
          (: n (pins {} 'name nm 'state 'down 'pid 0 'tries 0 'code () 'since (clock 0))
             (pin b nm n, n))))
   (hstate nm)    (peep (hstat nm) 'state 'down)
   (hmark nm k v) (pin (hstat nm) k v)
   (hup? nm)      (: s (hstate nm) (s == 'up || s == 'done))

   ; --- the narrator ----------------------------------------------------------
   ; every event lands in a bounded ring the moor reads back, and on stderr
   ; unless the config asked for quiet. this is the whole of helm's journal.
   (htake l n) (n < 1 || atom? l ? () (<l . htake >l (n - 1)))
   (hnote s)
    (hput 'events (htake (s . hcell 'events []) 200),
     hcell 'quiet 0 ? 0 (say err ("helm: " + s + "\n"), flush err),
     s)

   ; --- the child's environment -----------------------------------------------
   ; set before the fork, put back after. love's tasks are cooperative and
   ; spawnmap never parks, so nothing else can see the gap. there is no unsetenv
   ; nif, so a name we invented goes back as empty rather than absent.
   (henv-pairs l) (atom? l || atom? >l ? []
                     (: k <l v <>l ([k v] . henv-pairs >>l)))
   (henv-with l f)
    (: ps  (henv-pairs l)
       old (map (\ [k v] [k (getenv k)]) ps)
       _   (each ps (\ [k v] (setenv k v)))
       r   (f 0)
       _   (each old (\ [k v] (setenv k (string? v ? v ""))))
       r)

   ; --- act: make the process -------------------------------------------------
   ; stdin from /dev/null, stdout and stderr to the unit's log (appended) or to
   ; ours. the fds the child dups are closed in it too, and in us right after.
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
       pid  (henv-with (peep u 'env []) (\ _ (spawnmap argv fm cl 0 0)))
       _    (string? d ? (chdir old) 0)
       _    (each cl (\ f (close f)))
       pid)

   ; --- act: one unit up ------------------------------------------------------
   ; a target has nothing to run, so reaching it is reaching its wants. a oneshot
   ; BLOCKS -- that is the whole difference between the two running kinds, and
   ; what makes `after` on a oneshot mean anything.
   (hstart1 u)
    (: nm   (u 'name)
       kind (u 'kind)
       (kind == 'target
        ? (hmark nm 'state 'done, hnote ("target " + string nm + " reached"), 1)
          (: pid (hspawn u)
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

   ; --- perceive: a child died ------------------------------------------------
   ; every dead pid comes through here, ours or not: pid 1 is handed reparented
   ; orphans it never spawned, and harvesting them is its defining duty.
   (hreaped pid st)
    (: pids (hpids 0)
       nm   (pids pid)
       (? !nm (hnote ("reaped orphan pid " + show pid + " status " + show st))
          (pull pids pid 0,
           (: u     (hby (hunits-now 0) nm)
             s     (hstat nm)
             kind  (peep u 'kind ())
             rs    (peep u 'restart 'no)
             lived (clock 0 - peep s 'since 0)
             n     (hsteady < lived ? 0 (peep s 'tries 0))
             was   (s 'state)
             _     (hmark nm 'code st)
             _     (hmark nm 'pid 0)
             _     (hnote (string nm + " exited " + show st))
             ; a reload can drop a unit while its child is still running: it is
             ; still ours to reap, and there is no policy left to apply to it.
             (? !u (hmark nm 'state 'down)
                (was == 'stopping || hcell 'shutting 0) (hmark nm 'state 'down)
                (kind == 'oneshot) (hmark nm 'state (st == 0 ? 'done 'failed))
                (: want (rs == 'always || rs == 'on-fail && st != 0)
                   lim  (peep u 'tries 3)
                   (? (want && n < lim)
                        (hmark nm 'tries (n + 1),
                         hmark nm 'state 'down,
                         hnote ("restart " + string nm + " #" + show (n + 1)),
                         hstart1 u)
                      (hmark nm 'state (st == 0 ? 'done 'failed),
                       want ? (hnote (string nm + " gave up after " + show n + " restarts")) 0,
                       0))))))))

   ; drain every dead child: SIGCHLD coalesces, so one wake can owe several.
   (hdrain _) (: e (glean 0) (two? e ? (hreaped <e >e, hdrain 0) 0))
   ; wait for one unit's pid to be gone. the condition is the UNIT's recorded
   ; pid, not this loop's own glean, because either of two hands may do the
   ; reaping -- this drain during boot, when hloop is not up yet, or hloop's own
   ; once it is -- and hreaped clears the pid whichever it was. paced, not
   ; blocking: `rest` yields, so the moor and every other task keep running.
   (hwait nm pid ms)
    (: t0 (clock 0)
       (go _) (hdrain 0,
               (? (peep (hstat nm) 'pid 0 != pid) 1
                  (clock 0 - t0 > ms) 0
                  (rest 5, go 0)))
       (go 0))

   ; --- decide: dependency order ----------------------------------------------
   ; `after` first, depth first, and `seen` is the seatbelt -- hcheck reports a
   ; cycle, but a config edited under a running helm does not go back through it.
   (hensure nm seen)
    (? (hup? nm) 1
       (elem nm seen) (hnote ("after cycles at " + string nm), 0)
       (: u (hby (hunits-now 0) nm)
          (? !u (hnote ("no unit " + string nm), 0)
             (each (peep u 'after []) (\ d (hensure d (nm . seen))), hstart1 u))))

   (hboot nm)
    (: u (hby (hunits-now 0) nm)
       (? !u (hnote ("no unit " + string nm), 0)
          (u 'kind == 'target)
            (each (peep u 'wants []) (\ w (hensure w [])), hstart1 u)
          (hensure nm [])))

   ; the boot goal: the `default` target if the config names one, every runnable
   ; unit in file order otherwise.
   (hboot-all _)
    (: d (hby (hunits-now 0) 'default)
       (? d (hboot 'default)
          (each (hunits-now 0)
                (\ u (u 'kind == 'target ? 0 (hensure (u 'name) []))))))

   ; --- act: one unit down ----------------------------------------------------
   ; 'stopping suspends the restart policy for exactly one exit. the negative pid
   ; is the process group, so a service that forked is taken whole.
   (hstop1 nm)
    (: s   (hstat nm)
       pid (peep s 'pid 0)
       (? !(charm? pid && 0 < pid) (hmark nm 'state 'down, 1)
          (hmark nm 'state 'stopping,
           still (0 - pid) sig-term,
           hnote ("term " + string nm + " pid " + show pid),
           (: ok (hwait nm pid hpatience)
              (ok ? 1 (still (0 - pid) sig-kill, hnote ("kill " + string nm),
                       hwait nm pid hpatience))))))

   (hbounce nm) (hstop1 nm, hmark nm 'tries 0, hensure nm [])

   ; shutdown walks 'order as it lies -- newest first is reverse start order,
   ; which is dependents before the things they depend on. the flag suspends the
   ; restart policy for the whole walk: a service dying while we take the system
   ; down is the system going down, not a service that needs help.
   (hshutdown _)
    (hput 'shutting 1, each (hcell 'order []) (\ nm (hstop1 nm)), hnote "all stopped", 1)

   ; --- reload ----------------------------------------------------------------
   ; re-read the config and adopt it. nothing is restarted: a reload is a READ,
   ; and the moor is where you say (bounce 'x) if that is what you meant.
   (hreload _)
    (: r  (hconf (hcell 'conf "/etc/helm.l"))
       us <r
       _  (each <>r (\ g (hnote ("config: " + g))))
       _  (two? us ? (hput 'units us, hnote ("config: " + show #us + " units")) 0)
       #us)

   ; --- the loop: park on the signal source -----------------------------------
   (hloop sig)
    (await sig,
     (: ev (sigtake sig)
        s  (two? ev ? <ev 0)
        (? (s == sig-chld) (hdrain 0, hloop sig)
           (s == sig-hup)  (hreload 0, hloop sig)
           (s == sig-term || s == sig-int)
             (hnote ("signal " + show s + " -- shutting down"), hshutdown 0, 0)
           (hloop sig))))

   ; --- introspection ---------------------------------------------------------
   (hpad s n) (n <= #s ? s (hpad (s + " ") n))
   (hstatus-line nm)
    (: s (hstat nm)
       (hpad (string nm) 16 + hpad (string (peep s 'state 'down)) 10
        + "pid " + hpad (show (peep s 'pid 0)) 8
        + "tries " + show (peep s 'tries 0)
        + (: c (s 'code) (charm? c ? (" last " + show c) ""))))))
