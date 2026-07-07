; --- inle: a self-driving agent loop, modeled in ai (a runnable sketch) ---
; the EXECUTABLE companion to crew/inle.md. the real inle is the freestanding
; kernel (port/inle/kmain.c) grown a NIC; this file models the parts that STAY ai -- the
; perceive->decide->act fold, the watchdog, the checkpoint -- so the shape can be
; run and probed on the host before any C is written. like boot/tag.l, it is a
; sketch -- but milestone 1 (the heartbeat loop) is REAL on both frontends: it
; rides `rest`/`clock`/`twirl`/`catch`, which are core nifs, so the same code runs
; on the host and, unchanged, in the kernel. the `; value` comments are the
; printed intent; run `out/host/ai -l port/inle/inle.l -e "(demos 0)"` to see them
; (the file only DEFINES demos now -- a plain load prints nothing; -l preloads it into
; the shared global scope so the -e call finds it).
;
; the kernel ALREADY ships the perceive substrate (see kmain.c): k_sources[] is a
; getc/putc/ready/close vtable, ai_wait_fds() is select over fds, ai_ready() the
; ready probe, ai_clock()/ai_sleep() the clock. so networking is "add a virtio-net
; k_source slot + the IP/TCP state machine in C", and EVERYTHING BELOW is the part
; that stays ai. a net event stream is modeled as a list (`run`); the heartbeat
; stream (`run-beats`) is the REAL clock -- on metal the wait becomes ai_wait_fds
; over {socket, clock}, the merge happening in C, but the fold is identical.

; --- a tiny printer --- `note` writes a line to `out` (the console). inle's narrator:
; a LOCAL helper named `note` so it doesn't shadow prel's port-first `say` -- which is
; the WIRE writer reply-to needs, (say port bytes). it uses `puts` (= prel's `say out`),
; NOT the `.`/dot operator: on the freestanding kernel `.` flushes after each write and
; the console flush (fbdraw) blocks the cooperative loop, so dot-narration never returns
; -- puts writes straight to the serial console with no flush, which is what we want.
(: (note s) (: _ (puts s) (puts "\n"))

; --- an event is a chain (kind . payload) --- built with `link` (a bare `.` is
; the print operator, not cons). this is the merged stream the agent perceives:
; on metal, ai_wait_fds wakes on whichever source is ready, the kernel reads one
; datum and tags it with its source; here we just hand it a list.
   ev-kind cap   ev-load cup

; --- the agent state --- a plain 2-list (replies beats): an IMMUTABLE ai value,
; so show/read checkpoint it for free. (a book would NOT round-trip -- it is
; mutable, identity-compared, and its show reparses to nothing; the list is the
; honest carrier of crew/inle.md's "state is an ai value, persistence is
; show/read".) replies = packets answered, beats = heartbeats emitted. `with`
; builds a fresh state, so every step is pure: the same `fresh` seeds many runs.
   fresh `(0 0)
   replies cap   beats caup
   (with rep bts) `(rep bts)

; --- decide: the policy --- pure (state, event) -> (state' . action), a chain.
; the policy DECIDES ON CONTENT (`answer`): a 'net datagram is a request -- "ping"
; and "stat" are commands, and ANYTHING ELSE is EVALUATED AS AI, the result returned.
; that makes the agent a network REPL on bare metal -- the brain plugs in HERE.
; today the "model" is read+ev, the language itself (send `(* 6 7)`, get `42`); swap
; in a socket round-trip or an LLM and the SAME loop is that agent. a parse/eval
; fault RAISES -> the watchdog welps it (old state carried, no crash). NB: inside
; `policy` the PARAM `ev` shadows the global evaluator, so the eval lives in `answer`.
   (answer st d)                                    ; d = the datagram (a string) -> a reply string
     (? (= d "ping") "pong"
        (= d "stat") (+ "replies=" (+ (show (replies st)) (+ " beats=" (show (beats st)))))  ; + is binary: nest right
        (show (ev (sound (tap (bytes d)) 0))))         ; else: run d AS AI, show the result
   (policy st ev)
     (? (id? (ev-kind ev) 'net)                     ; a packet: answer by its content
          (link (with (+ 1 (replies st)) (beats st)) (link 'send (answer st (ev-load ev))))
        (id? (ev-kind ev) 'tick)                     ; the heartbeat clock fired
          (link (with (replies st) (+ 1 (beats st))) (link 'send "<3"))
        (scare 'bad-event (ev-kind ev)))             ; anything else: raise

; --- act: perform the action, return state' --- here say taps the wire; on metal
; (send . bytes) becomes (. bytes sock).
   (act step) (: st' (cap step) a (cup step)
                 _ (? (id? (cap a) 'send) (note (+ "  send: " (cup a))) 0)
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
                      (? (two? out) (act out) st))

; --- the scripted run --- perceive (next event) -> decide+act (guarded) -> recurse.
; a fold over a LIST of events: the model of the merged {net, clock} stream, bounded
; here by the demo list. on metal the list becomes ai_wait_fds. returns final state.
   (run st evs) (? !evs st (run (guarded st (cap evs)) (cup evs)))

; --- the heartbeat loop (MILESTONE 1: the clock alone, no net) --- perceive is one
; real clock tick: rest the period, read `clock`, tag it 'tick. this is NOT a model
; -- rest/clock are core nifs, so `run-beats` runs identically on the host and in
; the kernel. the agent acts on INITIATIVE, driven by time. non-terminating on metal;
; bounded by `n` here. returns final state.
   (beat st period) (: _ (rest period) (guarded st (link 'tick (clock 0))))
   (run-beats st n period) (? (< n 1) st (run-beats (beat st period) (- n 1) period))

; --- the LIVE nic agent loop (MILESTONE 3: perceive the real NIC) --- perceive one
; UDP datagram off `port` ((slurp port) BLOCKS for it), tag it 'net, decide+act under
; the watchdog, reply to its sender through the port, loop forever. The SAME policy +
; watchdog as the scripted demos; only perceive (scripted list -> live slurp) and act
; (note-tap -> port write) change -- the fold is identical, which is the whole point.
; `port` is a PARAM, not a free `nic`, so this file still loads on the host (no nic
; there); the kernel's net-agent build passes its `nic` port. acts on INITIATIVE the
; instant a packet lands -- the agent IS the server (the C echo loop is gone).
; reply-to writes to the WIRE with prel's port-first `say` (raw, no newline -- the old
; `fputs`; NOT inle's local `note`), then flushes the port to its datagram's sender.
   (reply-to port bytes) (: _ (say port bytes) _ (flush port) 0)
   (serve st port)
     (: d   (slurp port)                                 ; perceive: BLOCK for one datagram
        _   (note (+ "  nic <- " d))                      ; narrate what landed (console observability)
        out (policy st (link 'net d))                    ; decide (policy runs under the watchdog help)
        st' (? (two? out)                              ; watchdog by SHAPE: real step vs welped fault
                 (: a (cup out)                          ; a real step: reply, advance the state
                    _ (? (id? (cap a) 'send) (reply-to port (cup a)) 0)
                    (cap out))
                 st)                                     ; a caught fault: carry the old state forward
        (serve st' port))

; --- the MERGED perceive (MILESTONE 4: react AND beat on initiative) --- serve only
; REACTS -- it blocks on the nic, so with no traffic the agent is asleep, never acting
; on its own. drive merges {nic, clock}: a reactor task BLOCKS on the nic (parks on its
; fd) and a heartbeat task BEATS on the timer (parks on a wake-time), and the kernel
; scheduler issues ONE ai_wait_fds over {nic-fd, the nearest wake} -- so the C floor
; does the select, exactly as crew/inle.md promised, with ZERO new C (cue?/key? is
; stdin-only, so the clean single-task poll isn't reachable from ai -- two tasks let
; the scheduler do the merge instead). the two tasks share ONE mutable counter cell:
; the immutable 2-list can't carry a live count between concurrent tasks, and under the
; cooperative scheduler pin/peep never yield mid-op, so the book is race-free (the
; reactor only ever writes 'replies, the heartbeat only 'beats -- disjoint fields, no
; lost update even though each snapshots the whole cell). checkpoint reads it back to
; the honest 2-list. keys are INTEGER SLOTS (0 = replies, 1 = beats), NOT symbols: on
; the freestanding kernel a symbol key baked into the egg doesn't round-trip through
; pin/peep (an interning seam between the baked image and live reads -- verified on
; metal: an integer-keyed tablet round-trips, a baked-symbol-keyed one reads back the
; default), so the cell counts by slot index. that is also the crew/inle.md advice
; ("avoid maps for state") honored at the one place state must be shared+mutable.
   (cell rep bts) (: c (tablet 0) _ (pin c 0 rep) _ (pin c 1 bts) c)   ; slot 0 replies, 1 beats
   (snap c)       `((peep c 0 0) (peep c 1 0))                ; the cell -> the 2-list

; the reactor half: block for a datagram, answer it by content (the same policy +
; watchdog as serve), reply on the WIRE, commit the new reply count to slot 0.
   (react c port)
     (: d   (slurp port)                                  ; perceive: PARK on the nic fd
        _   (note (+ "  nic <- " d))
        out (policy (snap c) (link 'net d))               ; decide under the watchdog help
        _   (? (two? out)                               ; a real step vs a welped fault
                 (: a (cup out)
                    _ (? (id? (cap a) 'send) (reply-to port (cup a)) 0)  ; reply to its sender
                    (pin c 0 (replies (cap out))))        ; commit the new reply count (slot 0)
                 0)                                        ; a caught fault: leave the count
        (react c port))

; the heartbeat half: beat every `period` ticks, on INITIATIVE (no input needed),
; bump the beat count (slot 1) and narrate. PARKS on the timer, so the scheduler waits
; {nic, clock} together -- this is the merge. a tick has no datagram sender, so it just
; beats to the console; the policy's 'tick branch is for the scripted demo, but the live
; heartbeat increments directly (a tick is not a request -- no decide step needed). `n`
; counts DOWN; reaching exactly 0 stops -- so a POSITIVE n bounds it (n beats; the host
; demo + a metal smoke test) and a NEGATIVE n runs unbounded (it counts down PAST 0,
; never back to it). always catch its orphan.
   (pulse c period n)
     (? (= n 0) (snap c)                                 ; bounded: done, hand back the counts
        (: _ (rest period)                               ; perceive: the clock deadline
           _ (pin c 1 (+ 1 (peep c 1 0)))                ; bump beats (slot 1), race-free
           _ (note "  beat <3")                          ; act on initiative: narrate the beat
           (pulse c period (- n 1))))

; drive: spawn the heartbeat, run the reactor in this task; the scheduler merges
; {nic-fd, clock}. the agent now REACTS to packets AND ACTS on its own clock. seeded
; from `st` (a checkpoint restore), counts carried in the shared cell. non-terminating
; on metal: react never returns, so the heartbeat is never orphaned and (catch p) is the
; corpus law honored, not reached. `period` is in kernel ticks (PIT 100 Hz -> 10 ms).
   (drive st port period)
     (: c (cell (replies st) (beats st))
        p (twirl (\ _ (pulse c period -1)) 0)            ; the heartbeat, unbounded (negative n)
        _ (react c port)                                 ; the reactor (this task), unbounded
        (catch p))                                        ; unreachable on metal; orphan law kept

; --- the OUTBOUND brain (MILESTONE 5: inle INITIATES a round-trip) --- m1-m4 only
; REACT to packets and BEAT on the clock; the decide step was LOCAL (read+ev, a REPL).
; (B) in crew/inle.md makes the brain REMOTE: on its own initiative inle ships a
; question OUT to an oracle and acts on the reply -- "the decide step being a network
; round-trip, one read over a socket stream." that round-trip reuses the port surface
; ENTIRELY: `aim` points the nic at an arbitrary (ip, oport) -- resolving the SLIRP
; gateway's MAC by ARP in C, since SLIRP routes every off-subnet datagram through the
; gateway -- and then prel's say/flush WRITE the question to the wire and slurp BLOCKS
; for the answer. so the only genuinely new C is `aim` + the ARP resolve; the byte
; marshaling is the say/slurp the reactor already uses. `aim` is a kernel-only nif, so
; it never appears here by name -- the whole round-trip is handed in as one closure
; `ask1` (a question -> its reply), the kernel building it over `aim`+`nic`, the host a
; stub. same discipline as `port`: a metal-only capability enters as a param, so this
; file still loads where no nic exists.
   (ask port aim ip oport q)                            ; the metal round-trip (kernel wraps this as ask1)
     (: _ (aim ip oport)                                ; point the nic outbound (ARP for the gateway, in C)
        _ (say port q)                                  ; write the question to the wire (raw, port-first)
        _ (flush port)                                  ; transmit the datagram to (ip, oport)
        (slurp port))                                   ; perceive: BLOCK for the oracle's reply
   (ip4 a b c d) (+ (* a 16777216) (+ (* b 65536) (+ (* c 256) d)))  ; a.b.c.d -> the fixnum aim reads

; quest: the outbound loop -- every `period` ticks, ASK the oracle the standing question
; and narrate the reply. inle acts on its OWN initiative (no incoming packet needed),
; the decide step a remote round-trip through `ask1`. bounded by n (positive: the host
; demo + a metal smoke test); a negative n runs unbounded on metal (counts down past 0,
; never back to it -- the same idiom as pulse). returns 0 when bounded out.
   (quest ask1 q period n)
     (? (= n 0) 0
        (: _ (rest period)                              ; perceive: the clock deadline (initiative)
           r (ask1 q)                                   ; decide: ask the remote brain (a wire round-trip)
           _ (note (+ "  oracle <- " r))                ; act: narrate the answer
           (quest ask1 q period (- n 1))))

; --- checkpoint --- state is a plain value, so persistence is show/read. `bytes`
; lifts the saved string to the byte list `sip` reads (a string is a fn over its
; indices -- (map s (jot n))). on metal `save` writes to a flat region / virtio-blk
; so a restart resumes mid-mission.
   (bytes s)   (map s (jot (tally s)))
   (save st)   (show st)
   (restore s) (sound (tap (bytes s)) fresh)

; --- the watchdog (task-level / self-restart) --- run the agent as a SUPERVISED
; task over a checkpoint string; re-checkpoint its result. a healthy round returns a
; state list (advance the checkpoint); a dead task returns a non-list (hold the SAME
; checkpoint -- no progress lost, none double-counted). on metal the timer tick polls
; back? and respawns the agent task; here twirl/catch + a shape check stand in.
   (supervise ckpt n period)
     (: p (twirl (\ s (run-beats (restore s) n period)) ckpt)
        st' (catch p)
        (? (two? st') (save st') ckpt))

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
      (scare? s) (: _ (note (+ "  caught: " (show a))) (welp s a b))   ; a real fault: face, then welp
      (welp s a b))))

; --- the demos, as a CALLABLE function (not auto-run) --- a body-less top-level `:`
; leaks `demos` to the global scope. the host sketch + the -inle build call (demos 0)
; explicitly; the net-agent build skips it and runs (serve fresh nic) directly (the
; demos' sleeps/spawns leave the NIC RX unpolled, so a live agent must start clean --
; exactly why netecho slurps immediately). run `out/host/ai -l port/inle/inle.l -e "(demos 0)"`
; (the -l preload shares the global scope so `demos` is defined when -e fires; a positional
; file arg with -e AFTER it does NOT run -- the file is the program and the -e tokens are
; ignored trailing argv).
(: (demos _)
   (: _ (note "-- scripted {net, clock} stream; the watchdog absorbs the bad event --")
      _ (: evs `((link 'net "ping") (link 'tick 1) (link 'bogus 0)
                  (link 'net "ping") (link 'tick 2))
           st (run fresh evs)
           _ (. "  replies=") _ (. (replies st))           ; 2   both packets answered
           _ (. " beats=")    _ (. (beats st)) (. "\n"))    ; 2   both ticks beat (bogus skipped)
      _ (note "-- milestone 1: heartbeat on the real clock alone, no net (3 beats) --")
      _ (: st (run-beats fresh 3 4)
           _ (. "  beats=") _ (. (beats st)) (. "\n"))      ; 3   three real clock ticks
      _ (note "-- watchdog: 3 supervised task-restarts, 2 beats each; state persists --")
      _ (: end (mission (save fresh) 3 2 3)
           _ (. "  beats across the restarts=") _ (. (beats (restore end))) (. "\n"))  ; 6
      _ (note "-- checkpoint save/restore is faithful --")
      _ (: a (run-beats fresh 4 3) back (restore (save a))
           _ (. "  resume beats=") _ (. (beats back))       ; 4
           _ (. " == live ")       _ (. (beats a))          ; 4
           _ (. " equal? ")        _ (. (= a back)) (. "\n")) ; true
      _ (note "-- milestone 4: a heartbeat TASK + scripted reactor steps share one cell --")
      _ (: c (cell 0 0)
           p (twirl (\ _ (pulse c 2 3)) 0)                 ; a concurrent heartbeat: 3 real beats
           _ (each `("ping" "stat")                       ; the reactor side, scripted (no host nic)
                   (\ d (: out (policy (snap c) (link 'net d))
                           (? (two? out)
                              (: _ (note (+ "  reply: " (cup (cup out))))
                                 (pin c 0 (replies (cap out))))   ; commit replies (slot 0)
                              0))))
           _ (catch p)                                     ; join the heartbeat (the orphan law)
           _ (. "  replies=") _ (. (peep c 0 0))           ; 2   both scripted packets answered
           _ (. " beats=")    _ (. (peep c 1 0)) (. "\n")) ; 3   three heartbeats, on initiative
      _ (note "-- milestone 5: the brain is REMOTE -- ask a (stub) oracle on initiative --")
      _ (quest (\ q (+ "oracle says " q)) "the meaning of life?" 2 2)  ; 2 rounds; metal ask1 is the real wire
      0))
