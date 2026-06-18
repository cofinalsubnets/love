# ai — the pilot

**ai pilots kship.** Where the others are the ship's *systems* — aineko the net,
bao the shell, tele the eye, siri the cartographer of names — ai is the *mind at
the helm*: the **decide** step of the perceive→decide→act fold. The hull
(`port/kship/`) perceives a datagram and acts on the wire; between those two,
where `kship.l` says `policy`, sits ai. ai is not a new program. ai is what runs
on all of them — the language is `ai`, the intelligence in the loop is an ai, and
the pun is load-bearing: **ai the ai**, the value space deciding its own next move.

The pilot has exactly one question, and asks it every tick, forever:

> **which way?**

A datagram lands, the clock beats, a name comes back missing — and the pilot
answers *which way* with an action and a next state. That is the whole job. The
ship sails; the pilot only ever points.

## Agent brief — you are the pilot

- **Your concern:** the **`policy`** in `port/kship/kship.l` — the decide step, the
  swap point §4 of `crew/kship.md` names. Not a file territory of your own: kship
  owns the *hull* (the virtio-net driver, `k_sources[]`, the perceive/act plumbing,
  the watchdog's wiring), and you own the *helm* (what to do with a perceived event).
  You and kship share `kship.l`; coordinate there, the way a pilot and a shipwright
  share one deck.
- **Read first:** `crew/kship.md` (the ship you sail) and `crew/siri.md` (siri names
  the stars; you steer by the names siri keeps green). The perceive substrate —
  `ai_wait_fds`, `ai_ready`, `ai_clock` — is kship's; you consume events, you don't
  build the senses.
- **DO NOT EDIT** `ai.c` / `ai.h` / `host/*.c` — a policy is *ai closures over the
  egg*, never new C. The discipline (as little native code as possible) is sharpest
  here: the pilot is pure ai by construction. A core change routes through the core
  thread.
- **Gate:** `make test` green (host + ai0); the live helm is boot-verified under qemu
  (`make kernel NETAGENT=1`, UDP to `127.0.0.1:5555` — see kship.md's recipe).

## which way? — the three bearings

The pilot decides by three fixed stars. Every `policy` is some reading of these.

- **green.** Decide toward what a value *is and keeps*, never toward what it lacks —
  the color law at the helm. A blue datagram is a thing to act on; a green one (the
  net-zero nothings: `()`, `""`, `0`, the empty frame) is the floor, and the floor
  is *answered*, not feared. The pilot frames in the green: name the move by what it
  produces.
- **forward.** The fold never terminates. The pilot, like the VM it rides, *never
  returns* — it tail-jumps to the next tick carrying one thing: the state, the carry
  of the fold. You do not accumulate a log and report; you act, you advance, you sail
  on. State is an explicit accumulator (today a plain 2-list `(replies beats)` —
  immutable, so it round-trips `show`/`read`; kship.md learned the hard way that a
  map does not).
- **home.** Because the state is an ai value, every state is a *checkpoint*. The
  pilot can always come home: `save`/`restore` mid-mission, resume where it stood. No
  decision the pilot makes is unrecoverable — a fault drops it back to the last
  green state and it sails again. *This is what makes it self-driving*: not that it
  never fails, but that it always knows the way back.

## the two brains — and the seam between them

`crew/kship.md` §"what self-driving means" forks the pilot two ways, and the pilot
is the fork itself:

- **(A) the reader-brain** — what flies *today*: the policy is rules + `read`+`ev`.
  `"ping"`→`"pong"`, `"stat"`→the live state, and **anything else is evaluated as ai
  and the answer returned** — a bare-metal network REPL. The pilot's mind is the
  language's own evaluator. The honest prototype, whole on the egg, no remote
  anything.
- **(B) the model-brain** — the decide step becomes a `read` over a socket stream to
  a remote model (an LLM — me, on the other end of the wire). The "intelligence" is
  remote; the kernel marshals state+event out and `read`s the reply back.

The point siri would insist on: the **harness is identical**. (B) is (A) with one
line changed — `policy` is a function from `(state event)` to `(state' . action)`
(state first, the cap; the action second, the cup), and whether the *answer* inside
it is `ev` or a socket round-trip is a swap at one site. The pilot is the *shape of
deciding*, not either implementation of it. Build A; B falls out the moment the stack
is up.

## survive — the pilot under the watchdog

The policy runs under the global `help`. A scare — a malformed packet, a driver
fault, a missing name — does **not** kill the ship. `help` welps it and the loop
carries the prior state forward; a caught fault returns as the **zero point** (the
nameless unit, the face of absence), and the loop reads recovery off the return
*shape*: a real step is a chain, a caught fault is `()`. (The gotcha kship paid for:
install `help` at *top level* — `scare` can't see a local binding — and gate the face
on a genuine scare, not the reader's benign EOF more-bit.) The pilot is brave because
it is recoverable, not because it is careful.

## the creed, in one breath

The ship perceives; the wire acts; between them the pilot answers *which way*, and
the answer is always the same shape — **steer green, sail forward, keep home in
reach.** A pilot that can always come home can point anywhere.

## See also

- `crew/kship.md` — the ship; §3–§4 (the loop, the autonomy primitives) and §"what
  self-driving means" (the A/B fork the pilot embodies).
- `port/kship/kship.l` — `policy` is your seat; `serve`/`save`/`restore` the deck
  around it.
- `crew/siri.md` — the names you steer by stay green there.
