; tests for cooperative multitasking: spawn / yield / wait / sleep / done?.
; (spawn fn x)  -> pid (positive integer); starts a new task running (fn x).
;                  the main task has reserved pid 0.
; (yield 0)     -> nil; cooperatively suspends so other ready tasks can run.
;                  (yield) is just `yield` since (x)=x in gwen — call with an arg.
; (wait pid)    -> if pid is unknown / non-numeric / refers to the caller, 0.
;                  if the task is dormant (its fn has returned), collect it
;                  from the ring and return its return value.
;                  if the task is still running, yield until it becomes dormant.
; (sleep n)     -> nil; blocks the current task for at least n g_clock ticks.
;                  n <= 0 returns immediately. Other tasks run during the wait.
; (done? pid)   -> -1 if (wait pid) would not yield (pid unknown, self, dormant),
;                  nil if pid refers to a runnable task.

(assert
 ; spawn-wait round trip: fn is applied to x; the result flows back through wait.
 (= 42 (: p (spawn (\ x x) 42) (wait p)))
 (= 43 (: p (spawn (\ x (+ x 1)) 42) (wait p)))
 (= 49 (: p (spawn (\ x (* x x)) 7) (wait p)))

 ; spawn returns a positive integer pid (main reserves pid 0).
 (: p (spawn (\ _ 0) 0) _ (wait p) (&& (nump p) (> p 0)))

 ; pids are monotonically increasing within a VM.
 (: a (spawn (\ x x) 0)
    b (spawn (\ x x) 0)
    _ (wait a) _ (wait b)
    (> b a))

 ; wait on an unknown pid returns 0 without blocking.
 (= 0 (wait 99999))
 ; non-numeric pid argument: also 0.
 (= 0 (wait nil))
 ; pid 0 (main) is treated as not-waitable from main itself.
 (= 0 (wait 0))

 ; collecting a dormant task removes it: a second wait on the same pid sees 0.
 (: p (spawn (\ x x) 99)
    (&& (= 99 (wait p)) (= 0 (wait p))))

 ; many tasks can be reaped in any order.
 (: a (spawn (\ x (* x 10)) 3)
    b (spawn (\ x (* x 10)) 4)
    c (spawn (\ x (* x 10)) 5)
    (&& (= 50 (wait c))
        (= 30 (wait a))
        (= 40 (wait b))))

 ; a task may yield mid-execution and still return its value through wait.
 (: p (spawn (\ x (do (yield 0) (yield 0) (yield 0) (+ x 1))) 41)
    (= 42 (wait p)))

 ; nested spawn: a worker can spawn and wait on its own subtask.
 (: p (spawn (\ _ (: q (spawn (\ x (+ x 1)) 10) (wait q))) 0)
    (= 11 (wait p)))

 ; tasks share the heap: a captured table sees writes from the worker.
 (: t (new 0)
    p (spawn (\ k (put k 'done t)) 'key)
    _ (wait p)
    (= 'done (get 0 'key t)))

 ; waiting on a still-running task blocks until it finishes.
 ; here the worker only completes after several yields; main's wait yields
 ; alongside it and eventually returns the result.
 (: t (new 0)
    _ (put 'n 0 t)
    p (spawn (\ _ (: (loop _) (? (< (get 0 'n t) 3)
                                (do (put 'n (+ 1 (get 0 'n t)) t)
                                   (yield 0)
                                   (loop 0))
                                'done)
                    (loop 0))) 0)
    r (wait p)
    (&& (= 'done r) (= 3 (get 0 'n t))))

 ; --- done? predicate ---

 ; done? on an unknown pid is true (wait would return 0 immediately).
 (= -1 (done? 99999))
 ; done? on a non-numeric pid is true.
 (= -1 (done? nil))
 ; done? on the caller's own pid (main = 0) is true — wait skips self.
 (= -1 (done? 0))

 ; done? on a freshly spawned task is false: the task hasn't completed.
 (: p (spawn (\ _ 42) 0) r (done? p) _ (wait p) (nilp r))

 ; after yielding, the worker completes and done? becomes true.
 (: p (spawn (\ _ 42) 0) _ (yield 0) r (done? p) _ (wait p) (= -1 r))

 ; after wait collects the task, done? is again true (pid is gone).
 (: p (spawn (\ _ 42) 0) _ (wait p) (= -1 (done? p)))

 ; --- sleep ---

 ; sleep with non-positive n returns nil immediately without yielding.
 (nilp (sleep 0))
 (nilp (sleep -1))
 (nilp (sleep nil))

 ; sleep takes at least n ticks (g_clock ms on this frontend).
 ; allow generous slack for slow CI.
 (: t0 (clock 0)
    _ (sleep 30)
    elapsed (clock t0)
    (>= elapsed 30))

 ; sleeping tasks run concurrently: two parallel 30ms sleeps finish in well under 60ms.
 (: t0 (clock 0)
    a (spawn (\ _ (sleep 30)) 0)
    b (spawn (\ _ (sleep 30)) 0)
    _ (wait a) _ (wait b)
    elapsed (clock t0)
    (&& (>= elapsed 30) (< elapsed 60)))

 ; a peer waking mid-wait must NOT cut short main's longer sleep.
 ; (yield 0) forces peer to reach its (sleep 30) before main starts its (sleep 80),
 ; so main's yield_sw enters the deadline-coalesce wait with peer's 30 as min_wake.
 ; When peer wakes at ~30, main's pending wake_at must be preserved across the snapshot.
 (: t0 (clock 0)
    p (spawn (\ _ (sleep 30)) 0)
    _ (yield 0)
    _ (sleep 80)
    _ (wait p)
    elapsed (clock t0)
    (&& (>= elapsed 80) (< elapsed 120)))

 ; sleep cooperates: while one task sleeps, another finishes its work.
 (: t (new 0)
    _ (put 'flag 0 t)
    a (spawn (\ _ (sleep 30)) 0)
    b (spawn (\ _ (put 'flag -1 t)) 0)
    _ (wait a) _ (wait b)
    (= -1 (get 0 'flag t)))

 ; --- kill ---

 ; kill on an unknown pid: 0, no-op.
 (= 0 (kill 99999))
 ; kill on a non-numeric pid: 0.
 (= 0 (kill nil))
 ; kill on self (main = 0): 0 (self-kill impossible by construction).
 (= 0 (kill 0))

 ; kill a running task: returns -1. The task is gone from the ring, so
 ; wait on its pid returns 0 (unknown).
 (: t (new 0)
    _ (put 'flag 0 t)
    p (spawn (\ _ (: (loop _) (do (yield 0) (put 'flag -1 t) (loop 0)) (loop 0))) 0)
    r (kill p)
    (&& (= -1 r) (= 0 (wait p))))

 ; kill a dormant task (already finished): also returns -1, then wait sees 0.
 (: p (spawn (\ _ 42) 0)
    _ (yield 0)
    ; p is dormant now (done? would be -1).
    (&& (= -1 (kill p)) (= 0 (wait p))))

 ; double-kill: second kill is a no-op since the pid is gone from the ring.
 (: p (spawn (\ _ (: (loop _) (do (yield 0) (loop 0)) (loop 0))) 0)
    (&& (= -1 (kill p)) (= 0 (kill p))))

 ; killing one of several tasks leaves the others intact.
 (: t (new 0)
    a (spawn (\ _ (: (loop _) (do (yield 0) (loop 0)) (loop 0))) 0)
    b (spawn (\ x (* x 10)) 7)
    _ (kill a)
    rb (wait b)
    (&& (= 0 (wait a)) (= 70 rb)))

 ; --- wake_at scheduler behavior ---

 ; wait on a sleeping task: main has to sleep deeply alongside it, then
 ; collect the result. Elapsed should be ~30ms, not 0 or much more.
 (: t0 (clock 0)
    p (spawn (\ _ (do (sleep 30) 'done)) 0)
    r (wait p)
    elapsed (clock t0)
    (&& (= 'done r) (>= elapsed 30) (< elapsed 80)))

 ; tasks with different sleep durations wake in order: shorter sleep
 ; finishes first, longer still sleeping when we check, then completes.
 (: a (spawn (\ _ (do (sleep 10) 1)) 0)
    b (spawn (\ _ (do (sleep 80) 2)) 0)
    ra (wait a)               ; ~10ms; b still sleeping
    db (done? b)              ; b should still be running
    rb (wait b)               ; ~70ms more
    (&& (= 1 ra) (nilp db) (= 2 rb)))

 ; kill a sleeping task: scheduler skips it via wake_at, but kill walks the
 ; ring directly and finds it regardless of state.
 (: p (spawn (\ _ (do (sleep 10000) 'never)) 0)
    r (kill p)
    (&& (= -1 r) (= 0 (wait p))))

 ; sleep tasks coexist with non-sleeping ones: a worker that yields hot
 ; gets time while another sleeps.
 (: t (new 0)
    _ (put 'n 0 t)
    a (spawn (\ _ (sleep 30)) 0)
    b (spawn (\ _ (: (loop _) (? (< (get 0 'n t) 5)
                                (do (put 'n (+ 1 (get 0 'n t)) t)
                                   (yield 0)
                                   (loop 0))
                                'done)
                    (loop 0))) 0)
    _ (wait a) _ (wait b)
    (= 5 (get 0 'n t)))
)
