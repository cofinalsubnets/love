; cooperative tasks: twirl starts one (main is pid 0), rest yields or sleeps, catch collects,
; landed? asks whether catch would not wait, scoop harvests any finished task

(test
 ; twirl-catch round trip
 (42 = (twirl (x \ x) 42 @ p (catch p)))
 (43 = (twirl (x \ x + 1) 42 @ p (catch p)))
 (49 = (twirl (x \ x * x) 7 @ p (catch p)))

 ; a pid is a positive integer
 (twirl (_ \ 0) 0 @ p (catch p, charm? p && p > 0))

 ; pids are monotonically increasing within a VM.
 (: a (twirl (x \ x) 0)
    b (twirl (x \ x) 0)
    (catch a, catch b,
     b > a))

 ; wait on an unknown pid returns 0 without blocking.
 (0 = catch 99999)
 ; non-numeric pid argument: also 0.
 (0 = catch ())
 ; pid 0 (main) is treated as not-waitable from main itself.
 (0 = catch 0)

 ; collecting a dormant task removes it: a second wait on the same pid sees 0.
 (twirl (x \ x) 99 @ p
  ((99 = catch p) && (0 = catch p)))

 ; many tasks can be reaped in any order.
 (: a (twirl (x \ x * 10) 3)
    b (twirl (x \ x * 10) 4)
    c (twirl (x \ x * 10) 5)
    (50 = catch c
     && 30 = catch a
     && 40 = catch b))

 ; a task may yield mid-execution and still return its value through wait.
 (twirl (x \ do (rest 0) (rest 0) (rest 0) (x + 1)) 41 @ p
  (42 = catch p))

 ; a worker can twirl and catch its own subtask
 (twirl (_ \ twirl (x \ x + 1) 10 @ q (catch q)) 0 @ p
  (11 = catch p))

 ; tasks share the heap: a captured hash sees writes from the worker.
 (: t {}
    p (twirl (k \ pin t k 'done) 'key)
    (catch p,
     'done = peep t 'key 0))

 ; catching a running task waits until it finishes
 (: t {}
    _ (pin t 'n 0)
    p (twirl (_ \ (: (loop _) (? (peep t 'n 0 < 3)
                                (pin t 'n (1 + peep t 'n 0),
                                 rest 0,
                                 loop 0)
                                'done)
                    (loop 0))) 0)
    r (catch p)
    ('done = r && (3 = peep t 'n 0)))

 ; --- landed? predicate ---

 ; landed? on an unknown pid is true (catch would return 0 immediately).
 (1 = landed? 99999)
 ; landed? on a non-numeric pid is true.
 (1 = landed? ())
 ; landed? on the caller's own pid is true
 (1 = landed? 0)

 ; landed? on a freshly spawned task is false: the task hasn't completed.
 (: p (twirl (_ \ 42) 0) r (landed? p) (catch p, !r))

 ; after yielding, the worker completes and landed? becomes true.
 (: p (twirl (_ \ 42) 0) _ (rest 0) r (landed? p) (catch p, 1 = r))

 ; after catch collects the task, landed? is again true
 (twirl (_ \ 42) 0 @ p (catch p, 1 = landed? p))

 ; --- scoop: (pid . retval) of any finished task, or (); never waits ---
 ; every law drains first: an earlier file may have left a task dormant

 ; an empty ring answers the zero point.
 (: (drain _) (two? (scoop 0) ? (drain ()) 0)
    (drain (),
     !(scoop 0)))

 ; a finished task comes back whole: the pid in the car, its value in the cdr.
 (: (drain _) (two? (scoop 0) ? (drain ()) 0)
    _ (drain ())
    p (twirl (x \ x + 1) 41)
    _ (rest 0)
    s (scoop 0)
    (p = <s && 42 = >s))

 ; presence rides the pair, never the net: a task answering () still comes back
 (: (drain _) (two? (scoop 0) ? (drain ()) 0)
    _ (drain ())
    p (twirl (_ \ ()) ())
    _ (rest 0)
    s (scoop 0)
    (two? s && p = <s && nil? >s))

 ; scooping collects, exactly as catching does: the pid is gone afterwards.
 (: (drain _) (two? (scoop 0) ? (drain ()) 0)
    _ (drain ())
    p (twirl (_ \ 42) ())
    (rest 0,
     scoop 0,
     0 = catch p))

 ; a task still running is not harvested -- unfinished is the whole condition.
 (: (drain _) (two? (scoop 0) ? (drain ()) 0)
    _ (drain ())
    p (twirl (_ \ (rest 0, 42)) ())
    s (scoop 0)
    (catch p,
     !s))

 ; three finished tasks drain in three scoops, and the fourth answers nothing.
 (: (drain _) (two? (scoop 0) ? (drain ()) 0)
    (count k) (two? (scoop 0) ? (count (k + 1)) k)
    (drain (),
     twirl (_ \ 1) (), twirl (_ \ 2) (), twirl (_ \ 3) (),
     rest 0,
     3 = count 0))

 ; --- sleep ---

 ; sleep with non-positive n returns nil immediately without yielding.
 !(rest 0)
 !(rest -1)
 !(rest ())

 ; sleep takes at least n ms
 (: t0 (clock 0)
    _ (rest 30)
    elapsed (clock t0)
    (elapsed >= 30))

 ; sleeping tasks run concurrently: two parallel 30ms sleeps finish in well under 60ms.
 (: t0 (clock 0)
    a (twirl (_ \ rest 30) 0)
    b (twirl (_ \ rest 30) 0)
    _ (catch a) _ (catch b)
    elapsed (clock t0)
    (elapsed >= 30 && elapsed < 60))

 ; a peer waking mid-wait must not cut short main's longer sleep
 (: t0 (clock 0)
    p (twirl (_ \ rest 30) 0)
    _ (rest 0)
    _ (rest 80)
    _ (catch p)
    elapsed (clock t0)
    (elapsed >= 80 && elapsed < 120))

 ; sleep cooperates: while one task sleeps, another finishes its work.
 (: t {}
    _ (pin t 'flag 0)
    a (twirl (_ \ rest 30) 0)
    b (twirl (_ \ pin t 'flag 1) 0)
    (catch a, catch b,
     1 = peep t 'flag 0))

 ; --- freeze ---

 ; freeze on an unknown pid: 0, no-op.
 (0 = freeze 99999)
 ; freeze on a non-numeric pid: 0.
 (0 = freeze ())
 ; freeze on self (main = 0): 0 (self-freeze impossible by construction).
 (0 = freeze 0)

 ; freeze a running task: 1, and catch then answers 0
 (: t {}
    _ (pin t 'flag 0)
    p (twirl (_ \ (: (loop _) (rest 0, pin t 'flag 1, loop 0) (loop 0))) 0)
    r (freeze p)
    (1 = r && 0 = catch p))

 ; freeze a finished task: also 1, then catch sees 0
 (twirl (_ \ 42) 0 @ p
  (rest 0,
   ; p is dormant now (landed? would be 1).
   (1 = freeze p) && (0 = catch p)))

 ; double freeze: the second is a no-op since the pid is gone from the ring.
 (twirl (_ \ (: (loop _) (rest 0, loop 0) (loop 0))) 0 @ p
  ((1 = freeze p) && (0 = freeze p)))

 ; killing one of several tasks leaves the others intact.
 (: t {}
    a (twirl (_ \ (: (loop _) (rest 0, loop 0) (loop 0))) 0)
    b (twirl (x \ x * 10) 7)
    _ (freeze a)
    rb (catch b)
    ((0 = catch a) && 70 = rb))

 ; --- pause ---

 ; a paused task is held where it stands: catch answers at once, it has not landed, and
 ; a peer runs on; resumed, it finishes as it would have, its sleep kept
 (: t {}
    p (twirl (_ \ (rest 20, pin t 'a 1, 7)) 0)
    h (pause p)
    _ (catch p)
    q (twirl (_ \ pin t 'b 1) 0)
    _ (catch q, rest 60)
    l (landed? p) a (peep t 'a 0)
    w (resume p)
    r (catch p)
    (1 = h && 0 = l && 0 = a && 1 = peep t 'b 0 && 1 = w && 7 = r && 1 = peep t 'a 0))

 ; nothing is paused twice, or resumed that was not paused; never the running task
 (twirl (_ \ (: (loop _) (rest 0, loop 0) (loop 0))) 0 @ p
  (1 = pause p && () = pause p && 1 = resume p && () = resume p
   && () = pause 0 && () = pause 99999 && 1 = freeze p))

 ; --- yieldable bignum multiply ---

 ; a long bignum multiply yields in slices, so a ticker peer runs during it
 ; (capped so it cannot wrap the 1-byte cask)
 (: big (200000 2)
    ticks (cask 1)
    w (twirl (_ \ big * big) 0)
    t (twirl (_ \ (: (go _) (landed? w ? 0
                               (peep ticks 0 0 @ c
                                ((c < 250 ? (pin ticks 0 (c + 1)) 0),
                                 rest 0, go 0)))
                     (go 0))) 0)
    (catch w, catch t,
     5 < peep ticks 0 0))

 ; a task can be frozen mid-multiply
 (twirl (_ \ (200000 2) * (200000 2)) 0 @ w
  (rest 0,
   (1 = freeze w) && (0 = catch w)))

 ; --- sleeping tasks and the scheduler ---

 ; catching a sleeping task takes about its sleep
 (: t0 (clock 0)
    p (twirl (_ \ do (rest 30) 'done) 0)
    r (catch p)
    elapsed (clock t0)
    ('done = r && elapsed >= 30 && elapsed < 80))

 ; sleeps wake in order
 (: a (twirl (_ \ do (rest 10) 1) 0)
    b (twirl (_ \ do (rest 80) 2) 0)
    ra (catch a)               ; ~10ms; b still sleeping
    db (landed? b)              ; b should still be running
    rb (catch b)               ; ~70ms more
    (1 = ra && !db && 2 = rb))

 ; a sleeping task can be frozen
 (: p (twirl (_ \ do (rest 10000) 'never) 0)
    r (freeze p)
    (1 = r && 0 = catch p))

 ; a yielding worker gets time while another sleeps
 (: t {}
    _ (pin t 'n 0)
    a (twirl (_ \ rest 30) 0)
    b (twirl (_ \ (: (loop _) (? (peep t 'n 0 < 5)
                                (pin t 'n (1 + peep t 'n 0),
                                 rest 0,
                                 loop 0)
                                'done)
                    (loop 0))) 0)
    (catch a, catch b,
     5 = peep t 'n 0))

 ; --- (wear [i o e]) sets a task's own ports, () keeps the console; (worn ()) reads them ---

 ; a worn jug takes what the task says, and the console comes back after
 (jug 0 @ j
  (wear [() j ()],
   puts "into the jug",
   wear (),
   "into the jug" = slurp j && !(worn ())))

 ; a worn tap is what the task reads
 (: _ (wear [(tap '(104 105 33)) () ()])
    s (slurp in)
    (wear (),
     "hi!" = s))

 ; per task, across a switch: two tasks wearing different jugs never cross, and
 ; the main task keeps the console through both
 (: a (jug 0) b (jug 0)
    p (twirl (_ \ (wear [() a ()], puts "a1", rest 0, puts "a2", 1)) 0)
    q (twirl (_ \ (wear [() b ()], puts "b1", rest 0, puts "b2", 2)) 0)
    (catch p, catch q,
     "a1a2" = slurp a && "b1b2" = slurp b && !(worn ())))

 ; inherited at spawn: a child says its piece into the jug its parent wears
 (: j (jug 0)
    _ (wear [() j ()])
    p (twirl (_ \ (puts "the child's", 0)) 0)
    (catch p,
     wear (),
     "the child's" = (slurp j)))

 ; a child that wears its own leaves the parent's alone
 (: a (jug 0) b (jug 0)
    _ (wear [() a ()])
    p (twirl (_ \ (wear [() b ()], puts "child", 0)) 0)
    (catch p,
     puts "parent",
     wear (),
     "parent" = slurp a && "child" = slurp b))
)
