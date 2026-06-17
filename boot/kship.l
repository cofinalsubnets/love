; --- kship: a self-driving agent loop, modeled in ai (a runnable sketch) ---
; the EXECUTABLE companion to doc/kship.md. the real kship is the freestanding
; kernel (kmain.c) grown a NIC: this file models the parts that are ai -- the
; perceive->decide->act fold, the watchdog, the checkpoint -- so the shape can
; be run and probed on the host before any C is written.
;
; the kernel ALREADY ships the perceive substrate (see kmain.c): k_sources[] is a
; getc/putc/ready/close vtable, ai_wait_fds() is select over fds, ai_ready() the
; ready probe, ai_clock()/ai_sleep() the clock. so networking is "add a virtio-net
; k_source slot + the IP/TCP state machine in C", and EVERYTHING BELOW is the part
; that stays ai. here a real fd-stream is modeled as a list of events; on metal the
; same fold runs over ai_wait_fds, the merge happening in C.

; --- an event is (kind . payload) --- the merged stream the agent perceives.
; on metal: ai_wait_fds wakes on whichever source is ready, the kernel reads one
; datum, and tags it with its source. here we just hand it a list.
; demo:
(: e ('net . "ping") (cap e))   ; net    the kind
(: e ('net . "ping") (cup e))   ; "ping" the payload

; --- the agent state --- a plain ai value, so `show`/`read` checkpoint it for free.
; #(replies N  beats M) -- a book counting answered pings and emitted heartbeats.
(: fresh #(replies 0 beats 0)

   ; a tiny helper: bump a key in a (copied) state book
   (bump st k) (: t #(replies (peep st 'replies 0) beats (peep st 'beats 0))
                  _ (pin t k (+ 1 (peep t k 0)))
                  t)

; --- decide: the policy --- pure (state, event) -> (state' . action). in a
; reactive agent this is a rule table; swap it for a socket round-trip and the
; SAME loop becomes an LLM-in-the-loop agent (the model is the policy).
   (policy st ev)
     (? (idp (cap ev) 'net)                         ; a packet arrived
          ((bump st 'replies) . ('send . "pong"))
        (idp (cap ev) 'tick)                         ; the heartbeat clock fired
          ((bump st 'beats) . ('send . "<3"))
        (scare 'bad-event (cap ev)))                 ; anything else: raise

; --- act: perform the action, return state' --- here `.` taps the wire; on metal
; ('send . bytes) becomes (. bytes sock).
   (act step) (: st' (cap step) a (cup step)
                 _ (? (idp (cap a) 'send) (. (cup a)) 0)   ; emit to the "wire"
                 st')

; --- the watchdog --- the whole step runs under a help handler. a scare in the
; policy (a malformed packet, a missing name, a driver fault) does NOT kill the
; agent: welp answers the zero point and the loop carries the OLD state forward.
; this is what makes it self-driving -- it survives its own faults. on metal the
; kernel's top-level help additionally logs to a ring buffer and can respawn the
; agent task from the last checkpoint.
   (guarded st ev)
     (: help (\ s a b (: _ (. 'caught) _ (. a) st))   ; fault -> keep old state
        (act (policy st ev)))

; --- the loop --- perceive (next event) -> decide+act (guarded) -> recurse on
; state'. a fold over the event stream; non-terminating on metal (the stream is
; endless), bounded here by the demo list. returns the final state.
   (run st evs) (? !evs st
                   (run (guarded st (cap evs)) (cup evs)))

; --- checkpoint --- state is an ai value, so persistence is show/read. on metal
; this writes to a flat region / virtio-blk so a restart resumes mid-mission.
   (save st)    (show st)
   (restore s)  (read (sip s) fresh))

; --- demos (expr ; value) --- run the agent over a scripted event stream.
; two pings, two ticks, and one MALFORMED event that the watchdog must absorb.
(: evs (L ('net . "ping") ('tick . 1) ('bogus . 0) ('net . "ping") ('tick . 2))
   final (run fresh evs)
   _ (. 'final) _ (. final))
; the wire taps print: pong <3 caught bogus pong <3  -- the bogus event is caught,
; the agent keeps running, and:
(peep (run fresh evs) 'replies 0)   ; 2   both pings answered (bogus skipped)
(peep (run fresh evs) 'beats 0)     ; 2   both ticks beat

; --- checkpoint round-trips --- save the live state, restore it, resume identical.
(: st (run fresh evs)
   wire (save st)
   back (restore wire)
   (idp (peep back 'replies 0) (peep st 'replies 0)))   ; true  resume is faithful
