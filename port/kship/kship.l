; --- kship: a self-driving agent loop, modeled in ai (a runnable sketch) ---
; the EXECUTABLE companion to doc/kship.md. the real kship is the freestanding
; kernel (port/kship/kmain.c) grown a NIC; this file models the parts that STAY ai -- the
; perceive->decide->act fold, the watchdog, the checkpoint -- so the shape can be
; run and probed on the host before any C is written. like boot/tag.l, it is a
; sketch -- but milestone 1 (the heartbeat loop) is REAL on both frontends: it
; rides `sleep`/`clock`/`spawn`/`wait`, which are core nifs, so the same code runs
; on the host and, unchanged, in the kernel. the `; value` comments are the
; printed intent; run `out/host/ai port/kship/kship.l` to see them.
;
; the kernel ALREADY ships the perceive substrate (see kmain.c): k_sources[] is a
; getc/putc/ready/close vtable, ai_wait_fds() is select over fds, ai_ready() the
; ready probe, ai_clock()/ai_sleep() the clock. so networking is "add a virtio-net
; k_source slot + the IP/TCP state machine in C", and EVERYTHING BELOW is the part
; that stays ai. a net event stream is modeled as a list (`run`); the heartbeat
; stream (`run-beats`) is the REAL clock -- on metal the wait becomes ai_wait_fds
; over {socket, clock}, the merge happening in C, but the fold is identical.

; --- a tiny printer --- `.` taps a value to `out`; say adds a newline.
(: (say s) (: _ (. s) (. "\n"))

; --- an event is a chain (kind . payload) --- built with `link` (a bare `.` is
; the print operator, not cons). this is the merged stream the agent perceives:
; on metal, ai_wait_fds wakes on whichever source is ready, the kernel reads one
; datum and tags it with its source; here we just hand it a list.
   ev-kind cap   ev-load cup

; --- the agent state --- a plain 2-list (replies beats): an IMMUTABLE ai value,
; so show/read checkpoint it for free. (a book would NOT round-trip -- it is
; mutable, identity-compared, and its show reparses to nothing; the list is the
; honest carrier of doc/kship.md's "state is an ai value, persistence is
; show/read".) replies = packets answered, beats = heartbeats emitted. `with`
; builds a fresh state, so every step is pure: the same `fresh` seeds many runs.
   fresh (L 0 0)
   replies cap   beats caup
   (with rep bts) (L rep bts)

; --- decide: the policy --- pure (state, event) -> (state' . action), a chain.
; in a reactive agent this is a rule table; swap it for a socket round-trip and the
; SAME loop becomes an LLM-in-the-loop agent (the model IS the policy). an
; unrecognized event RAISES -- the watchdog below turns that into a survivable miss.
   (policy st ev)
     (? (idp (ev-kind ev) 'net)                     ; a packet arrived
          (link (with (+ 1 (replies st)) (beats st)) (link 'send "pong"))
        (idp (ev-kind ev) 'tick)                     ; the heartbeat clock fired
          (link (with (replies st) (+ 1 (beats st))) (link 'send "<3"))
        (scare 'bad-event (ev-kind ev)))             ; anything else: raise

; --- act: perform the action, return state' --- here say taps the wire; on metal
; (send . bytes) becomes (. bytes sock).
   (act step) (: st' (cap step) a (cup step)
                 _ (? (idp (cap a) 'send) (say (+ "  send: " (cup a))) 0)
                 st')

; --- the watchdog (in-loop) --- the policy runs under the global `help` (installed
; below). a scare in the policy (a malformed packet, a missing name, a driver fault)
; does NOT kill the agent: help welps it -- prints a face and returns the ZERO POINT
; -- so `(policy st ev)` comes back as () rather than a chain. help cannot see the
; loop's `st`, so guarded reads the recovery off the SHAPE: a chain is a real step
; (act it), anything else is a caught fault (carry the OLD state forward). that
; "survives its own faults" property is what makes the agent self-driving. on metal
; the kernel's top help additionally logs to a ring buffer and can respawn the task.
   (guarded st ev) (: out (policy st ev)
                      (? (chainp out) (act out) st))

; --- the scripted run --- perceive (next event) -> decide+act (guarded) -> recurse.
; a fold over a LIST of events: the model of the merged {net, clock} stream, bounded
; here by the demo list. on metal the list becomes ai_wait_fds. returns final state.
   (run st evs) (? !evs st (run (guarded st (cap evs)) (cup evs)))

; --- the heartbeat loop (MILESTONE 1: the clock alone, no net) --- perceive is one
; real clock tick: sleep the period, read `clock`, tag it 'tick. this is NOT a model
; -- sleep/clock are core nifs, so `run-beats` runs identically on the host and in
; the kernel. the agent acts on INITIATIVE, driven by time. non-terminating on metal;
; bounded by `n` here. returns final state.
   (beat st period) (: _ (sleep period) (guarded st (link 'tick (clock 0))))
   (run-beats st n period) (? (< n 1) st (run-beats (beat st period) (- n 1) period))

; --- checkpoint --- state is a plain value, so persistence is show/read. `bytes`
; lifts the saved string to the byte list `sip` reads (a string is a fn over its
; indices -- (map s (jot n))). on metal `save` writes to a flat region / virtio-blk
; so a restart resumes mid-mission.
   (bytes s)   (map s (jot (tally s)))
   (save st)   (show st)
   (restore s) (read (sip (bytes s)) fresh)

; --- the watchdog (task-level / self-restart) --- run the agent as a SUPERVISED
; task over a checkpoint string; re-checkpoint its result. a healthy round returns a
; state list (advance the checkpoint); a dead task returns a non-list (hold the SAME
; checkpoint -- no progress lost, none double-counted). on metal the timer tick polls
; done? and respawns the agent task; here spawn/wait + a shape check stand in.
   (supervise ckpt n period)
     (: p (spawn (\ s (run-beats (restore s) n period)) ckpt)
        st' (wait p)
        (? (chainp st') (save st') ckpt))

; --- a mission --- many supervised rounds, each a FRESH task, the state carried only
; by the checkpoint between them: the persistence story end to end. the count
; accumulates ACROSS task boundaries, which is the whole point -- the machine keeps
; its mission across its own restarts.
   (mission ckpt rounds n period)
     (? (< rounds 1) ckpt (mission (supervise ckpt n period) (- rounds 1) n period)))

; --- install the watchdog (a welp with a face) as the global help --- mirror
; repl.l's shell-help: the read-control statuses (incomplete / eof -- the more
; bit) keep the protocol silently through welp; only a genuine scare wears the
; face. file mode has no eofsym pre-catch, so help itself must gate -- otherwise
; the trailing end-of-script EOF prints a spurious face.
(: help (\ s a b
   (? (more? s)  (welp s a b)                                         ; read control: protocol only
      (scare? s) (: _ (say (+ "  caught: " (show a))) (welp s a b))   ; a real fault: face, then welp
      (welp s a b))))

; --- demo 1: the scripted merged stream --- two packets, two clock ticks, and one
; MALFORMED event the watchdog must absorb. the wire taps print as it runs.
(say "-- scripted {net, clock} stream; the watchdog absorbs the bad event --")
(: evs (L (link 'net "ping") (link 'tick 1) (link 'bogus 0)
          (link 'net "ping") (link 'tick 2))
   st (run fresh evs)
   _ (. "  replies=") _ (. (replies st))           ; 2   both packets answered
   _ (. " beats=")    _ (. (beats st)) (. "\n"))    ; 2   both ticks beat (bogus skipped)

; --- demo 2: MILESTONE 1 -- the heartbeat on the real clock, no net ---
(say "-- milestone 1: heartbeat on the real clock alone, no net (3 beats) --")
(: st (run-beats fresh 3 4)
   _ (. "  beats=") _ (. (beats st)) (. "\n"))      ; 3   three real clock ticks

; --- demo 3: the self-restart watchdog -- state survives task death ---
(say "-- watchdog: 3 supervised task-restarts, 2 beats each; state persists --")
(: end (mission (save fresh) 3 2 3)
   _ (. "  beats across the restarts=") _ (. (beats (restore end))) (. "\n"))  ; 6

; --- demo 4: the checkpoint round-trips faithfully ---
(say "-- checkpoint save/restore is faithful --")
(: a (run-beats fresh 4 3) back (restore (save a))
   _ (. "  resume beats=") _ (. (beats back))       ; 4
   _ (. " == live ")       _ (. (beats a))          ; 4
   _ (. " equal? ")        _ (. (= a back)) (. "\n")); true
