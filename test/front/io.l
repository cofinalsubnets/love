; test/front/io.l -- the would-block park, under test/front/main.c, a frontend that lies:
; `ready` says go and then the device says no, a race a normal love cannot reach.
; the fault lives in test code only. `(stall p k)` arms k would-block answers on readn
; while `ready` says yes: the reader must park and re-run, not spin or lose the byte.

(: (take p n)                       ; n bytes off p as text, stopping at the end
   ((: (go k acc)
       (k @ 0 (string (rev acc))
        (see p @ -1 (string (rev acc)) c (go (k - 1) (c . acc)))))
    n ()))

; --- law 1: a stalled read loses nothing ---
; a refill that waited instead of parking makes the frontend's deadline-free wait exit 97
(: p (dev ())
   _ (feed p "abc")
   _ (stall p 3)
   _ (assert (take p 3 = "abc")))

; --- law 2: the park yields, it does not stop the vm ---
; the reader must give the scheduler its turn while a peer runs
(: p (dev ())
   _ (feed p "xy")
   _ (stall p 6)
   n {}
   t (twirl (_ \ (: (go u) (pin n 0 (1 + (peep n 0 0)), rest 0, go ())) ()) ())
   got (take p 2)
   _ (freeze t)
   _ (assert (got = "xy")
             (0 < (peep n 0 0))))       ; the peer ran while the reader waited

; --- law 3: would-block is not the end ---
; a shut empty device answers end; a stall in front of the end must not be taken for it
(: p (dev ())
   _ (stall p 2)
   _ (shut p)
   _ (assert ((see p) = -1)))

; and the end survives a re-read: a shut device owes -1 to every ask (readn's contract)
(: p (dev ())
   _ (shut p)
   _ (assert ((see p) = -1) ((see p) = -1)))

; --- law 4: a stall mid-run keeps the run ---
; the refill hands back byte 0 and stashes the rest; a later stall must not disturb it
(: p (dev ())
   _ (feed p "hello")
   c (see p)                          ; one refill: 'h' out, "ello" stashed
   _ (stall p 4)
   _ (assert (c = 104)
             ((take p 4) = "ello")))

; --- law 5: cue? agrees with the park ---
; a shut device is ready (the end is an answer), and a stall is a lie, not a fact
(: p (dev ())
   _ (shut p)
   _ (assert (cue? p)))
(: p (dev ())
   _ (feed p "z")
   _ (stall p 1)
   _ (assert (cue? p)))

; --- law 6: the colist rides the park ---
; `flow` gulps through `see`, so the stall lands inside the promise's force; it must memoize
(: p (dev ())
   _ (feed p "one")
   _ (shut p)
   _ (stall p 2)
   cl (flow p)
   _ (assert (string cl = "one")
             (string cl = "one")))

; --- law 7: a short write loses nothing ---
; `wcap` takes one byte per ask; every byte must still arrive, in order. `put` fills the
; port's write run, the part io_wdrain strokes; `say` would take the direct lane
(: p (dev ())
   _ (wcap p 1)
   _ (each '(97 98 99 100 101 102 103 104) (put p))
   _ (flush p)
   _ (assert (sent p = "abcdefgh")))

; --- law 8: a stalled write keeps its residue and its order ---
; a refused byte parks in the port while the next stroke would go straight to the device,
; so a two-lane writer shuffles its own stream. two refusals: the bulk stroke and a flush
(: p (dev ())
   _ (wstall p 2)
   _ (say p "hello world")
   _ (flush p)
   _ (assert (sent p = "hello world")))

; and the same over many small writes, where the residue has to survive the gaps
(: p (dev ())
   _ (wcap p 2)
   _ (wstall p 1)
   _ (each '("one" "two" "six") (say p))
   _ (flush p)
   _ (assert (sent p = "onetwosix")))

; --- law 9: flush delivers: the run parks and re-runs until the port is empty ---
(: p (dev ())
   _ (wstall p 5)
   _ (say p "hello")
   _ (flush p)
   _ (assert (sent p = "hello")))

; --- law 10: the writer parks, it does not stop the vm ---
(: p (dev ())
   _ (wstall p 30)
   n {}
   t (twirl (_ \ (: (go u) (pin n 0 (1 + (peep n 0 0)), rest 0, go ())) ()) ())
   _ (say p "xyz")
   _ (flush p)
   _ (freeze t)
   _ (assert (sent p = "xyz")
             (0 < peep n 0 0)))       ; the peer ran while the writer waited

; --- law 11: the write run is a buffer, not a queue ---
; `say` never refuses, so a say that would push the run past its size waits for the device;
; without that a peer that stops reading grows the run a whole string per say
(: p (dev ())
   s (: (dup t n) (n @ 0 t (dup (t + t) (n - 1))) (dup "0123456789abcdef" 8))
   _ (wstall p 40)
   hi (foldl (m \ _ \ (: _ (say p s) k (wpending p) (m < k ? k m))) 0 '(1 2 3 4))
   _ (flush p)
   _ (assert (#s = 4096)
             (hi <= 4096)                  ; 16384 with the park taken back out
             (#(sent p) = 16384)))  ; and not one byte lost to the waiting

; and the same bound on the byte lane (`put`); `putx` carries the identical guard
(: p (dev ())
   _ (wstall p 40)
   hi (: (go k m) (k @ 0 m
                   (: _ (put p 120) j (wpending p) (go (k - 1) (m < j ? j m))))
         (go 9000 0))
   _ (flush p)
   _ (assert (hi <= 4096)                 ; 8192 with the park taken back out
             (#(sent p) = 9000)))

; --- law 13: a catcher parks, so the scheduler gets to sleep ---
; a runnable catcher keeps find_runnable answering, so the scheduler never waits. this one
; is the catcher's own yield, which must not take yield_sw's "still runnable" arm: Ip
; still points at the catch. `rest 0` lets the peer park first; without it the arm is
; never reached and the law proves nothing
(: n0 (naps ())
   b (twirl (_ \ rest 60) ())
   _ (rest 0)
   _ (catch b)
   _ (assert (0 < naps () - n0)))    ; 0 with that arm's guard taken back out

; --- law 14: and find_runnable must not answer a catcher either ---
; the sleeper yields last, with a deadline, so law 13's arm is never offered
(: n0 (naps ())
   b (twirl (_ \ rest 60) ())
   a (twirl (_ \ catch b) ())
   _ (catch a)
   _ (assert (0 < naps () - n0)))    ; 0 with the find_runnable clause out

; --- law 15: the park still answers, on an exit and on a freeze ---
(: t (twirl (_ \ (rest 20, 41)) ())
   _ (assert (catch t = 41)))

; a peer frozen out from under the catcher wakes it too: freeze makes the pid gone, not
; dormant, and a park waiting for dormancy alone would exit 97 here
(: t (twirl (_ \ rest 5000) ())
   _ (twirl (_ \ freeze t) ())
   _ (assert !(catch t)))

(say out "front: ok\n")
