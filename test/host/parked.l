; test/host/parked.l -- many tasks parked on many fds, and the wake finds them all. run by
; test/host/run.l as a bounded subprocess, since a failure is a hang; checks are `assert`.
; no timer runs, so the wake must come from the fd set: a `rest` here would turn a hang into latency.
(: (mk k acc) (k = 0 ? acc (mk (k - 1) (. (pipe 0) acc)))
   ps (mk 16 ())
   q (pipe 0)
   qw (fdopen >q)
   qr (fdopen <q)

   ; the write ends stay open, or a reader gets EOF instead of parking
   _ (each ps (p \ (twirl (_ \ (fdopen <p @ r
                                (see r,
                                 say qw "x",
                                 flush qw))) ())))

   ; one byte from outside, after all 17 have parked
   pid (spawnio ["sh" "-c" "sleep 1; printf x"] 0 ><ps 2 [] -1 0)

   b (see qr)                      ; parks; only the woken peer's byte releases it
   (wait pid,
    assert (b = 120)))

; --- readiness is asked of an fd, but the bytes live in the port
; two tasks park on one port's fd; yield_sw_wait wakes main first, so its `see` gulps both
; bytes, and the peer must wake on its buffered byte though the fd is quiet
(: p (pipe 0)
   r (fdopen <p)               ; one heap port; the write end stays a bare fd
   t (twirl (_ \ (see r)) ())
   _ (rest 20)                      ; t reaches its park before anything is written
   pid (spawnio ["sh" "-c" "sleep 0.3; printf AB"] 0 >p 2 [] -1 0)
   a (see r)
   b (catch t)                      ; hangs with the port half of the test taken out
   (wait pid,
    assert (a = 65) (b = 66)))    ; one byte each, in order

; --- await on a port with buffered bytes is ready however quiet its fd; one task
(: p2 (pipe 0)
   r2 (fdopen <p2)
   pid2 (spawnio ["sh" "-c" "printf AB"] 0 >p2 2 [] -1 0)
   _ (wait pid2)
   a2 (see r2)                      ; gulps both; the second is in the buffer now
   _ (await r2)                     ; hangs with the buffer term taken out
   b2 (see r2)
   _ (assert (a2 = 65) (b2 = 66)))

; --- a parked peer is not starved by tasks that never block: only the sweep counter
; (task.c, sweep_interval) asks after it, and it must fire with a runnable peer. two
; compute tasks are needed, so the run ring never runs dry
(: p3 (pipe 0)
   r3 (fdopen <p3)
   (spin n) (n < 1 ? 0 (spin (n - 1)))
   t3 (twirl (_ \ (see r3)) ())
   _ (rest 30)                      ; t3 reaches its park before the compute starts
   c1 (twirl (_ \ (spin 4000000)) ())
   c2 (twirl (_ \ (spin 4000000)) ())
   pid3 (spawnio ["sh" "-c" "sleep 0.2; printf Z"] 0 >p3 2 [] -1 0)
   got (catch t3)                   ; never returns if the parked peer starves
   (wait pid3,
    freeze c1, freeze c2,
    assert (got = 90)))

(puts "parked: ok\n")
