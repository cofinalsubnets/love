; --- kship: a self-driving agent loop, modeled in ai (a runnable sketch) ---
; the EXECUTABLE companion to doc/kship.md. the real kship is the freestanding
; kernel (kmain.c) grown a NIC; this file models the parts that STAY ai -- the
; perceive->decide->act fold, the watchdog, the checkpoint -- so the shape can be
; run and probed on the host before any C is written. like boot/tag.l, it is a
; sketch: the values in `; value` comments are the intent, not a gate.
;
; the kernel ALREADY ships the perceive substrate (see kmain.c): k_sources[] is a
; getc/putc/ready/close vtable, ai_wait_fds() is select over fds, ai_ready() the
; ready probe, ai_clock()/ai_sleep() the clock. so networking is "add a virtio-net
; k_source slot + the IP/TCP state machine in C", and EVERYTHING BELOW is the part
; that stays ai. here a real fd-stream is modeled as a list of events; on metal the
; same fold runs over ai_wait_fds, the merge happening in C.

; --- a tiny printer --- `.` taps a value to `out`; say adds a newline.
(: (say s) (: _ (. s) (. "\n"))

; --- an event is a chain (kind . payload) --- built with `link` (a bare `.` is
; the print operator, not cons). this is the merged stream the agent perceives:
; on metal, ai_wait_fds wakes on whichever source is ready, the kernel reads one
; datum and tags it with its source; here we just hand it a list.
   ev-kind cap   ev-load cup

; --- the agent state --- a plain ai value, so `show`/`read` checkpoint it for
; free. a book counting answered packets (replies) and emitted heartbeats (beats).
; bump returns a FRESH book (never mutates its argument), so a state is immutable
; and the same `fresh` can seed many independent runs.
   fresh #(replies 0 beats 0)
   (bump st k) (: t #(replies (peep st 'replies 0) beats (peep st 'beats 0))
                  _ (pin t k (+ 1 (peep t k 0)))
                  t)

; --- decide: the policy --- pure (state, event) -> (state' . action), a chain.
; in a reactive agent this is a rule table; swap it for a socket round-trip and the
; SAME loop becomes an LLM-in-the-loop agent (the model IS the policy). an
; unrecognized event RAISES -- the watchdog below turns that into a survivable miss.
   (policy st ev)
     (? (idp (ev-kind ev) 'net)                     ; a packet arrived
          (link (bump st 'replies) (link 'send "pong"))
        (idp (ev-kind ev) 'tick)                     ; the heartbeat clock fired
          (link (bump st 'beats) (link 'send "<3"))
        (scare 'bad-event (ev-kind ev)))             ; anything else: raise

; --- act: perform the action, return state' --- here say taps the wire; on metal
; (send . bytes) becomes (. bytes sock).
   (act step) (: st' (cap step) a (cup step)
                 _ (? (idp (cap a) 'send) (say (+ "  send: " (cup a))) 0)
                 st')

; --- the watchdog --- the policy runs under the global `help` (installed below). a
; scare in the policy (a malformed packet, a missing name, a driver fault) does NOT
; kill the agent: help welps it -- prints a face and returns the ZERO POINT -- so
; `(policy st ev)` comes back as () rather than a chain. help cannot see the loop's
; `st`, so guarded reads the recovery off the SHAPE: a chain is a real step (act it),
; anything else is a caught fault (carry the OLD state forward). that "survives its
; own faults" property is what makes the agent self-driving. on metal the kernel's
; top help additionally logs to a ring buffer and can respawn the agent task.
   (guarded st ev) (: out (policy st ev)
                      (? (chainp out) (act out) st))

; --- the loop --- perceive (next event) -> decide+act (guarded) -> recurse on
; state'. a fold over the event stream; non-terminating on metal (the stream is
; endless), bounded here by the demo list. returns the final state.
   (run st evs) (? !evs st (run (guarded st (cap evs)) (cup evs)))

; --- checkpoint --- state is an ai value, so persistence is show/read. on metal
; this writes to a flat region / virtio-blk so a restart resumes mid-mission.
   (save st)   (show st)
   (restore s) (read (sip s) fresh))

; --- install the watchdog (a welp with a face) as the global help ---
(: help (\ s a b (: _ (say (+ "  caught: " (string a))) (welp s a b))))

; --- demos (expr ; value) --- run the agent over a scripted event stream of two
; packets, two clock ticks, and one MALFORMED event the watchdog must absorb. the
; wire taps print as it runs:  send: pong / send: <3 / caught: bad-event / send: pong / send: <3
(: evs (L (link 'net "ping") (link 'tick 1) (link 'bogus 0)
          (link 'net "ping") (link 'tick 2))
   _ (run fresh evs))

(peep (run fresh evs) 'replies 0)   ; 2   both packets answered (bogus skipped)
(peep (run fresh evs) 'beats 0)     ; 2   both ticks beat
(chainp (policy fresh (link 'net "x")))   ; true   a good event yields a step

; --- checkpoint round-trips --- save the live state, restore it, resume identical.
(: st (run fresh evs)
   back (restore (save st))
   (idp (peep back 'replies 0) (peep st 'replies 0)))   ; true  resume is faithful
