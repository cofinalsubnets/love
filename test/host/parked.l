; test/host/parked.l -- many tasks parked on many fds, and the wake finds them all. run by
; test/host/run.l as a bounded subprocess, since the regression is a hang; checks are `assert`.
; every task parked and no timer running, so the scheduler must really sleep on the fd set and the
; wake comes from outside the process; no `rest` anywhere, or a dropped fd is a latency, not a hang.
; the target is the first-twirled task, the one furthest from the ring's head.
(: (mk k acc) (k = 0 ? acc (mk (k - 1) (. (pipe 0) acc)))
   ps (mk 16 ())
   q (pipe 0)
   qw (fdopen >q)
   qr (fdopen <q)

   ; the write ends stay open here. close one and its reader gets the end of the
   ; stream instead of parking, and the whole shape evaporates.
   _ (each ps (p \ (twirl (_ \ (fdopen <p @ r
                                (see r,
                                 say qw "x",
                                 flush qw))) ())))

   ; the one byte from outside, a second from now: by then all 17 are parked.
   pid (spawnio ["sh" "-c" "sleep 1; printf x"] 0 ><ps 2 [] -1 0)

   b (see qr)                      ; parks; only the woken peer's byte releases it
   (wait pid,
    assert (b = 120)))

; --- defect 6: readiness is asked of an FD, but the bytes live in the port -----
; a task parked on a quiet fd over a buffer another task's gulp filled used to
; sleep on top of exactly what it was waiting for. reaching it takes two tasks on
; one heap port where one uses the bulk lane, which is why it sat written down and
; unfixed: `in` cannot reach it (trickle never runs ahead) and `wrap` cannot (two
; tasks, two fds).
;
; who wins the wake is not a race, and the law depends on that. both tasks park
; on the same fd; when the byte lands, yield_sw_wait asks about the running task's
; own fd before it re-scans the ring, so main always comes back first and its `see`
; gulps both bytes into the port. the peer is then parked on a fd with nothing left
; to say, over a buffer holding its byte -- and `catch` hangs instead of reaping.
(: p (pipe 0)
   r (fdopen <p)               ; one heap port; the write end stays a bare fd
   t (twirl (_ \ (see r)) ())
   _ (rest 20)                      ; t reaches its park before anything is written
   pid (spawnio ["sh" "-c" "sleep 0.3; printf AB"] 0 >p 2 [] -1 0)
   a (see r)
   b (catch t)                      ; hangs with the port half of the test taken out
   (wait pid,
    assert (a = 65) (b = 66)))    ; one byte each, in order

; --- the same defect at the entry: await asked the fd alone --------------------
; a port holding bytes is readable however quiet its fd is (love.c, bio_of's park
; law), so awaiting one whose buffer is already full parked on a device that has
; nothing left to say. one task is enough here, and the hang is the monotask wait.
(: p2 (pipe 0)
   r2 (fdopen <p2)
   pid2 (spawnio ["sh" "-c" "printf AB"] 0 >p2 2 [] -1 0)
   _ (wait pid2)
   a2 (see r2)                      ; gulps both; the second is in the buffer now
   _ (await r2)                     ; hangs with the buffer term taken out
   b2 (see r2)
   _ (assert (a2 = 65) (b2 = 66)))

; --- rung 2: a parked peer is not starved by tasks that never block ------------
; the two rings put the fd-parked tasks off the run ring, so the only thing that
; asks after them on behalf of a task deep in compute is the sweep counter
; (love.c, sweep_interval). gate that counter on "nothing else is runnable" and
; two compute tasks are enough to close the door forever: each is a runnable peer
; for the other, so the fairness yield always has someone to hand the cpu to, the
; sweep never fires, and the parked task waits for a wake that is never asked for.
; one compute task does not reach it -- it is the second that keeps the run ring
; from running dry, which is exactly why the bug survived the first reading.
; verified by fault injection: gating the sweep hangs this law and nothing else.
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
