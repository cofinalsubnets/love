; cooperative tasks: twirl starts one (main is pid 0), rest yields or sleeps, catch collects,
; landed? asks whether catch would not wait, scoop harvests any finished task

(test
 (42 = (twirl (x \ x) 42 @ p (catch p)))
 (43 = (twirl (x \ x + 1) 42 @ p (catch p)))
 (49 = (twirl (x \ x * x) 7 @ p (catch p)))

 (twirl (_ \ 0) 0 @ p (catch p, charm? p && p > 0))

 ; pids increase within a VM
 (: a (twirl (x \ x) 0)
    b (twirl (x \ x) 0)
    (catch a, catch b,
     b > a))

 ; an unknown pid, a non-number, and main itself answer 0 without blocking
 (0 = catch 99999)
 (0 = catch ())
 (0 = catch 0)

 ; collecting a dormant task removes it
 (twirl (x \ x) 99 @ p
  ((99 = catch p) && (0 = catch p)))

 (: a (twirl (x \ x * 10) 3)
    b (twirl (x \ x * 10) 4)
    c (twirl (x \ x * 10) 5)
    (50 = catch c
     && 30 = catch a
     && 40 = catch b))

 ; a task may yield and still return its value
 (twirl (x \ do (rest 0) (rest 0) (rest 0) (x + 1)) 41 @ p
  (42 = catch p))

 (twirl (_ \ twirl (x \ x + 1) 10 @ q (catch q)) 0 @ p
  (11 = catch p))

 ; tasks share the heap
 (: t {}
    p (twirl (k \ pin t k 'done) 'key)
    (catch p,
     'done = peep t 'key 0))

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

 ; landed? is true where catch would not wait
 (1 = landed? 99999)
 (1 = landed? ())
 (1 = landed? 0)

 (: p (twirl (_ \ 42) 0) r (landed? p) (catch p, !r))

 (: p (twirl (_ \ 42) 0) _ (rest 0) r (landed? p) (catch p, 1 = r))

 (twirl (_ \ 42) 0 @ p (catch p, 1 = landed? p))

 ; --- scoop: (pid . retval) of any finished task, or (); never waits ---
 ; every law drains first: an earlier file may have left a task dormant

 (: (drain _) (two? (scoop 0) ? (drain ()) 0)
    (drain (),
     !(scoop 0)))

 ; the pid in the car, its value in the cdr
 (: (drain _) (two? (scoop 0) ? (drain ()) 0)
    _ (drain ())
    p (twirl (x \ x + 1) 41)
    _ (rest 0)
    s (scoop 0)
    (p = <s && 42 = >s))

 ; presence rides the pair, never the net
 (: (drain _) (two? (scoop 0) ? (drain ()) 0)
    _ (drain ())
    p (twirl (_ \ ()) ())
    _ (rest 0)
    s (scoop 0)
    (two? s && p = <s && nil? >s))

 ; scooping collects, as catching does
 (: (drain _) (two? (scoop 0) ? (drain ()) 0)
    _ (drain ())
    p (twirl (_ \ 42) ())
    (rest 0,
     scoop 0,
     0 = catch p))

 ; a task still running is not harvested
 (: (drain _) (two? (scoop 0) ? (drain ()) 0)
    _ (drain ())
    p (twirl (_ \ (rest 0, 42)) ())
    s (scoop 0)
    (catch p,
     !s))

 (: (drain _) (two? (scoop 0) ? (drain ()) 0)
    (count k) (two? (scoop 0) ? (count (k + 1)) k)
    (drain (),
     twirl (_ \ 1) (), twirl (_ \ 2) (), twirl (_ \ 3) (),
     rest 0,
     3 = count 0))

 ; --- sleep ---

 ; non-positive n answers () at once, without yielding
 !(rest 0)
 !(rest -1)
 !(rest ())

 (: t0 (clock 0)
    _ (rest 30)
    elapsed (clock t0)
    (elapsed >= 30))

 ; two parallel 30ms sleeps finish in well under 60ms
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

 (: t {}
    _ (pin t 'flag 0)
    a (twirl (_ \ rest 30) 0)
    b (twirl (_ \ pin t 'flag 1) 0)
    (catch a, catch b,
     1 = peep t 'flag 0))

 ; --- freeze ---

 ; unknown, non-number, self: 0
 (0 = freeze 99999)
 (0 = freeze ())
 (0 = freeze 0)

 (: t {}
    _ (pin t 'flag 0)
    p (twirl (_ \ (: (loop _) (rest 0, pin t 'flag 1, loop 0) (loop 0))) 0)
    r (freeze p)
    (1 = r && 0 = catch p))

 (twirl (_ \ 42) 0 @ p
  (rest 0,
   (1 = freeze p) && (0 = catch p)))

 ; double freeze: the pid is gone from the ring
 (twirl (_ \ (: (loop _) (rest 0, loop 0) (loop 0))) 0 @ p
  ((1 = freeze p) && (0 = freeze p)))

 (: t {}
    a (twirl (_ \ (: (loop _) (rest 0, loop 0) (loop 0))) 0)
    b (twirl (x \ x * 10) 7)
    _ (freeze a)
    rb (catch b)
    ((0 = catch a) && 70 = rb))

 ; --- pause ---

 ; a paused task is held: catch answers at once, it has not landed, a peer runs on;
 ; resumed, it finishes as it would have, its sleep kept
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

 ; a long bignum multiply yields in slices, so a ticker peer runs during it;
 ; capped so it cannot wrap the 1-byte cask
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

 (twirl (_ \ (200000 2) * (200000 2)) 0 @ w
  (rest 0,
   (1 = freeze w) && (0 = catch w)))

 ; --- sleeping tasks and the scheduler ---

 (: t0 (clock 0)
    p (twirl (_ \ do (rest 30) 'done) 0)
    r (catch p)
    elapsed (clock t0)
    ('done = r && elapsed >= 30 && elapsed < 80))

 (: a (twirl (_ \ do (rest 10) 1) 0)
    b (twirl (_ \ do (rest 80) 2) 0)
    ra (catch a)
    db (landed? b)
    rb (catch b)
    (1 = ra && !db && 2 = rb))

 (: p (twirl (_ \ do (rest 10000) 'never) 0)
    r (freeze p)
    (1 = r && 0 = catch p))

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

 (jug 0 @ j
  (wear [() j ()],
   puts "into the jug",
   wear (),
   "into the jug" = slurp j && !(worn ())))

 (: _ (wear [(tap '(104 105 33)) () ()])
    s (slurp in)
    (wear (),
     "hi!" = s))

 ; per task, across a switch: two jugs never cross, main keeps the console
 (: a (jug 0) b (jug 0)
    p (twirl (_ \ (wear [() a ()], puts "a1", rest 0, puts "a2", 1)) 0)
    q (twirl (_ \ (wear [() b ()], puts "b1", rest 0, puts "b2", 2)) 0)
    (catch p, catch q,
     "a1a2" = slurp a && "b1b2" = slurp b && !(worn ())))

 ; inherited at spawn
 (: j (jug 0)
    _ (wear [() j ()])
    p (twirl (_ \ (puts "the child's", 0)) 0)
    (catch p,
     wear (),
     "the child's" = (slurp j)))

 (: a (jug 0) b (jug 0)
    _ (wear [() a ()])
    p (twirl (_ \ (wear [() b ()], puts "child", 0)) 0)
    (catch p,
     puts "parent",
     wear (),
     "parent" = slurp a && "child" = slurp b))
)
