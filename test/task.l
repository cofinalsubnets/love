; tests for cooperative multitasking: hatch / yield / wait / sleep / done?.
; (spin fn x)  -> pid (positive integer); starts a new task running (fn x).
;                  the main task has reserved pid 0.
; (rest 0)     -> nil; cooperatively suspends so other ready tasks can run.
;                  (yield) is just `yield` since (x)=x in l — call with an arg.
; (catch pid)    -> if pid is unknown / non-numeric / refers to the caller, 0.
;                  if the task is dormant (its fn has returned), collect it
;                  from the ring and return its return value.
;                  if the task is still running, yield until it becomes dormant.
; (rest n)     -> nil; blocks the current task for at least n g_clock ticks.
;                  n <= 0 returns immediately. Other tasks run during the wait.
; (back? pid)   -> 1 if (catch pid) would not yield (pid unknown, self, dormant),
;                  nil if pid refers to a runnable task.

(assert
 ; hatch-wait round trip: fn is applied to x; the result flows back through wait.
 (= 42 (: p (spin (\ x x) 42) (catch p)))
 (= 43 (: p (spin (\ x (+ x 1)) 42) (catch p)))
 (= 49 (: p (spin (\ x (* x x)) 7) (catch p)))

 ; hatch returns a positive integer pid (main reserves pid 0).
 (: p (spin (\ _ 0) 0) _ (catch p) (&& (charm? p) (> p 0)))

 ; pids are monotonically increasing within a VM.
 (: a (spin (\ x x) 0)
    b (spin (\ x x) 0)
    _ (catch a) _ (catch b)
    (> b a))

 ; wait on an unknown pid returns 0 without blocking.
 (= 0 (catch 99999))
 ; non-numeric pid argument: also 0.
 (= 0 (catch nil))
 ; pid 0 (main) is treated as not-waitable from main itself.
 (= 0 (catch 0))

 ; collecting a dormant task removes it: a second wait on the same pid sees 0.
 (: p (spin (\ x x) 99)
    (&& (= 99 (catch p)) (= 0 (catch p))))

 ; many tasks can be reaped in any order.
 (: a (spin (\ x (* x 10)) 3)
    b (spin (\ x (* x 10)) 4)
    c (spin (\ x (* x 10)) 5)
    (&& (= 50 (catch c))
        (= 30 (catch a))
        (= 40 (catch b))))

 ; a task may yield mid-execution and still return its value through wait.
 (: p (spin (\ x (do (rest 0) (rest 0) (rest 0) (+ x 1))) 41)
    (= 42 (catch p)))

 ; nested hatch: a worker can hatch and wait on its own subtask.
 (: p (spin (\ _ (: q (spin (\ x (+ x 1)) 10) (catch q))) 0)
    (= 11 (catch p)))

 ; tasks share the heap: a captured hash sees writes from the worker.
 (: t (tablet 0)
    p (spin (\ k (pin t k 'done)) 'key)
    _ (catch p)
    (= 'done (peep t 'key 0)))

 ; waiting on a still-running task blocks until it finishes.
 ; here the worker only completes after several yields; main's wait yields
 ; alongside it and eventually returns the result.
 (: t (tablet 0)
    _ (pin t 'n 0)
    p (spin (\ _ (: (loop _) (? (< (peep t 'n 0) 3)
                                (do (pin t 'n (+ 1 (peep t 'n 0)))
                                   (rest 0)
                                   (loop 0))
                                'done)
                    (loop 0))) 0)
    r (catch p)
    (&& (= 'done r) (= 3 (peep t 'n 0))))

 ; --- done? predicate ---

 ; done? on an unknown pid is true (catch would return 0 immediately).
 (= 1 (back? 99999))
 ; done? on a non-numeric pid is true.
 (= 1 (back? nil))
 ; done? on the caller's own pid (main = 0) is true — wait skips self.
 (= 1 (back? 0))

 ; done? on a freshly spawned task is false: the task hasn't completed.
 (: p (spin (\ _ 42) 0) r (back? p) _ (catch p) (nil? r))

 ; after yielding, the worker completes and done? becomes true.
 (: p (spin (\ _ 42) 0) _ (rest 0) r (back? p) _ (catch p) (= 1 r))

 ; after wait collects the task, done? is again true (pid is gone).
 (: p (spin (\ _ 42) 0) _ (catch p) (= 1 (back? p)))

 ; --- sleep ---

 ; sleep with non-positive n returns nil immediately without yielding.
 (nil? (rest 0))
 (nil? (rest -1))
 (nil? (rest nil))

 ; sleep takes at least n ticks (g_clock ms on this frontend).
 ; allow generous slack for slow CI.
 (: t0 (clock 0)
    _ (rest 30)
    elapsed (clock t0)
    (>= elapsed 30))

 ; sleeping tasks run concurrently: two parallel 30ms sleeps finish in well under 60ms.
 (: t0 (clock 0)
    a (spin (\ _ (rest 30)) 0)
    b (spin (\ _ (rest 30)) 0)
    _ (catch a) _ (catch b)
    elapsed (clock t0)
    (&& (>= elapsed 30) (< elapsed 60)))

 ; a peer waking mid-wait must NOT cut short main's longer sleep.
 ; (rest 0) forces peer to reach its (rest 30) before main starts its (rest 80),
 ; so main's yield_sw enters the deadline-coalesce wait with peer's 30 as min_wake.
 ; When peer wakes at ~30, main's pending wake_at must be preserved across the snapshot.
 (: t0 (clock 0)
    p (spin (\ _ (rest 30)) 0)
    _ (rest 0)
    _ (rest 80)
    _ (catch p)
    elapsed (clock t0)
    (&& (>= elapsed 80) (< elapsed 120)))

 ; sleep cooperates: while one task sleeps, another finishes its work.
 (: t (tablet 0)
    _ (pin t 'flag 0)
    a (spin (\ _ (rest 30)) 0)
    b (spin (\ _ (pin t 'flag 1)) 0)
    _ (catch a) _ (catch b)
    (= 1 (peep t 'flag 0)))

 ; --- chill ---

 ; chill on an unknown pid: 0, no-op.
 (= 0 (freeze 99999))
 ; chill on a non-numeric pid: 0.
 (= 0 (freeze nil))
 ; chill on self (main = 0): 0 (self-chill impossible by construction).
 (= 0 (freeze 0))

 ; chill a running task: returns 1. The task is gone from the ring, so
 ; wait on its pid returns 0 (unknown).
 (: t (tablet 0)
    _ (pin t 'flag 0)
    p (spin (\ _ (: (loop _) (do (rest 0) (pin t 'flag 1) (loop 0)) (loop 0))) 0)
    r (freeze p)
    (&& (= 1 r) (= 0 (catch p))))

 ; chill a dormant task (already finished): also returns 1, then wait sees 0.
 (: p (spin (\ _ 42) 0)
    _ (rest 0)
    ; p is dormant now (back? would be 1).
    (&& (= 1 (freeze p)) (= 0 (catch p))))

 ; double-chill: second chill is a no-op since the pid is gone from the ring.
 (: p (spin (\ _ (: (loop _) (do (rest 0) (loop 0)) (loop 0))) 0)
    (&& (= 1 (freeze p)) (= 0 (freeze p))))

 ; killing one of several tasks leaves the others intact.
 (: t (tablet 0)
    a (spin (\ _ (: (loop _) (do (rest 0) (loop 0)) (loop 0))) 0)
    b (spin (\ x (* x 10)) 7)
    _ (freeze a)
    rb (catch b)
    (&& (= 0 (catch a)) (= 70 rb)))

 ; --- yieldable bignum multiply ---

 ; A single bignum multiply is O(n^2) but now yields cooperatively: it folds a
 ; bounded chunk of the product per VM dispatch, so a peer task runs *during* the
 ; product. This is what lets the repl's Ctrl-C poller interrupt a hung eval like
 ; (3 3 3 3) (see g/repl.l do_eval). Here a worker squares a ~200k-bit number
 ; once; a ticker peer counts how often it gets scheduled mid-multiply. Before
 ; chunking, the worker held the CPU for the whole product and the ticker (capped
 ; so it can't wrap the 1-byte cask) never ran -- post-chunking it runs many times.
 (: big (200000 2)
    ticks (cask 1)
    w (spin (\ _ (* big big)) 0)
    t (spin (\ _ (: (go _) (? (back? w) 0
                               (: c (peep ticks 0 0)
                                  _ (? (< c 250) (pin ticks 0 (+ c 1)) 0)
                                  _ (rest 0) (go 0)))
                     (go 0))) 0)
    _ (catch w) _ (catch t)
    (< 5 (peep ticks 0 0)))

 ; a peer can chill a task while it is mid-multiply, not only once it finishes:
 ; the worker parks at a yield inside the product, so chill finds it runnable.
 (: w (spin (\ _ (* (200000 2) (200000 2))) 0)
    _ (rest 0)
    (&& (= 1 (freeze w)) (= 0 (catch w))))

 ; --- wake_at scheduler behavior ---

 ; wait on a sleeping task: main has to sleep deeply alongside it, then
 ; collect the result. Elapsed should be ~30ms, not 0 or much more.
 (: t0 (clock 0)
    p (spin (\ _ (do (rest 30) 'done)) 0)
    r (catch p)
    elapsed (clock t0)
    (&& (= 'done r) (>= elapsed 30) (< elapsed 80)))

 ; tasks with different sleep durations wake in order: shorter sleep
 ; finishes first, longer still sleeping when we check, then completes.
 (: a (spin (\ _ (do (rest 10) 1)) 0)
    b (spin (\ _ (do (rest 80) 2)) 0)
    ra (catch a)               ; ~10ms; b still sleeping
    db (back? b)              ; b should still be running
    rb (catch b)               ; ~70ms more
    (&& (= 1 ra) (nil? db) (= 2 rb)))

 ; chill a sleeping task: scheduler skips it via wake_at, but chill walks the
 ; ring directly and finds it regardless of state.
 (: p (spin (\ _ (do (rest 10000) 'never)) 0)
    r (freeze p)
    (&& (= 1 r) (= 0 (catch p))))

 ; sleep tasks coexist with non-sleeping ones: a worker that yields ap
 ; gets time while another sleeps.
 (: t (tablet 0)
    _ (pin t 'n 0)
    a (spin (\ _ (rest 30)) 0)
    b (spin (\ _ (: (loop _) (? (< (peep t 'n 0) 5)
                                (do (pin t 'n (+ 1 (peep t 'n 0)))
                                   (rest 0)
                                   (loop 0))
                                'done)
                    (loop 0))) 0)
    _ (catch a) _ (catch b)
    (= 5 (peep t 'n 0)))
)
