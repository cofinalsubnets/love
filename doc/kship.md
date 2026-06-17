# kship — a freestanding ai-kernel as an autonomous agent

A design sketch. **kship** grows the existing freestanding ai kernel (`kmain.c`,
limine/ovmf under qemu) a network stack and a persistent agent loop, so the
machine *perceives* (network + clock), *decides* (a policy), and *acts* (network +
spawned tasks) unattended on bare metal — a prototype self-driving autonomous agent.

This is not a greenfield OS. The substrate is mostly here already; kship is "the
kernel grown a NIC and an agent loop on the egg." The runnable companion to this
doc is `boot/kship.l`, which models the ai half (the perceive→decide→act fold, the
watchdog, the checkpoint) so the shape runs and probes on the host before any C.

## What "self-driving" means here — one fork

- **(A) Reactive control loop** — a pure-ai policy: perceive → decide (rules /
  search) → act, no model. Buildable entirely on the egg today. The honest prototype.
- **(B) LLM-in-the-loop** — the kernel ships requests to a remote model and acts on
  replies; the "intelligence" is remote. Needs only the net stack + a JSON/SSE codec.

The harness is **identical** for both: (B) is (A) with the decide step being a
network round-trip — one `read` over a socket stream. Build (A) first; (B) falls out
once the stack is up. `boot/kship.l`'s `policy` is the swap point.

## What already exists (the perceive substrate)

`kmain.c` already carries most of the input machinery — kship reuses it verbatim:

| capability                | already in `kmain.c`            | kship role                       |
|---------------------------|---------------------------------|----------------------------------|
| per-source I/O vtable     | `k_sources[]` (getc/putc/flush/**ready**/close) | a socket is a new slot |
| multi-source wait         | `ai_wait_fds(fds, n, ticks)`    | **this is `select`**             |
| non-blocking probe        | `ai_ready(fd)`                  | the `ready?` of a stream         |
| clock                     | `ai_clock()` (`kticks`)         | the heartbeat tick               |
| timed wait                | `ai_sleep(ticks)`               | back-off / idle                  |
| the language image        | the egg (prel + ev + repl)      | the agent runs on it             |
| concurrency               | tasks: `spawn`/`wait`/`done?`/`sleep` | one task per connection    |
| fault survival            | the condition system (`help`/`welp`/`scare`) | the watchdog        |

So the only genuinely new native code is **the NIC driver + a thin IP/TCP** and a
`k_sources[]` slot bridging a socket to the stream surface. Everything above that is
ai closures — the project discipline (as little new C as possible) holds.

## Layer cake

```
┌─ boot/kship.l   the self-driving loop (perceive→decide→act), in ai   ← runnable today
├─ net.l          sockets as ai streams over the source surface
├─ ev / repl      the egg — already in the kernel image
├─ ai_io          path-A I/O surface (the aineko keystone)
├─ k_sources[]    per-fd vtable  + ai_wait_fds/ai_ready  — ALREADY PRESENT
├─ C net core     virtio-net driver + minimal IP/UDP/TCP        ← the new C
├─ kmain.c        boot, heap, framebuffer, timer tick, scheduler
└─ limine         boot (already wired)
```

## 1. The C floor (the only genuinely new native code)

- **NIC driver** — one device: **virtio-net** (qemu's default; far simpler than
  e1000). MMIO/virtqueue rings, RX/TX. The bulk of the C work.
- **A new `k_sources[]` slot** — a socket fd with `getc`/`putc`/`ready`/`close`,
  exactly like the keyboard (slot 0) and serial (slot 1) already there. `ready`
  feeds the existing `ai_wait_fds`, so `select` over {socket, keyboard, clock} works
  the moment the slot exists — no new wait primitive.
- **Thin IP/UDP/TCP** — *only what `aineko` needs.* UDP datagrams + one TCP
  connection's state machine. Do **not** build a general stack.
- **Timer tick** — already drives `ai_clock`/`ai_sleep`; the agent's heartbeat reads
  it. Confirm the tick can *preempt* a busy ai loop before relying on it (below).

## 2. The net surface in ai (`net.l`)

Sockets as ai values, mirroring the aineko / path-A plan:

- `(dial host port)` / `(listen port)` → a source-shaped stream both directions.
- `read` / `.` already work over a source; send is `(. bytes sock)`.
- A connection is a **task**: `(spawn handler sock)`, and *always* `(wait p)` — an
  orphan stalls the kernel runner (the corpus law, doubly true on metal).

## 3. The agent loop (`boot/kship.l`) — the self-driving part

A non-terminating perceive–decide–act fold, supervised by the condition system.
The runnable model is in `boot/kship.l`; the on-metal version differs only in that
the event stream is `ai_wait_fds` over real fds instead of a list:

- **Perceive** — `ai_wait_fds` over {socket, clock}; block until ready, no busy-poll.
  The kernel reads one datum and tags it with its source → a `(kind . payload)` event.
- **Decide** — `policy`: in (A) a rule table; in (B) marshal state+event to the model
  socket and `read` the reply.
- **Act** — emit on the net, `spawn` sub-tasks, return the next `state`. State is an
  explicit accumulator — the loop is a fold, state is the carry.
- **Survive** — the policy runs under the global `help`. A `scare` (driver fault,
  malformed packet, missing name) does not kill the machine: `help` welps it and the
  loop carries the prior state forward. *This is what makes it self-driving.* Note
  (verified in the sketch): a local `help` binding isn't seen by `scare` — install at
  top level; and `help` can't see the loop's `st`, so the loop reads recovery off the
  return **shape** (a real step is a chain; a caught fault is the zero point).

## 4. Autonomy primitives

What separates "an agent loop" from "a *self-driving autonomous* agent":

- **Watchdog / self-restart** — the timer tick checks the agent task is live
  (`done?`); on death, respawn from the last checkpoint. Built from existing
  task + condition primitives.
- **Checkpoint / persistence** — state is an ai value, so persistence is
  `show`/`read` (see `save`/`restore` in `boot/kship.l`). Write to a flat region /
  virtio-blk; a restart resumes mid-mission. No filesystem needed for the prototype.
- **Heartbeat** — a clock event every N ticks so the agent acts with no network input
  (initiative, not just reaction).
- **Resource floor** — wire the OOM blue-floor (`scare 'oom len` instead of a bare
  crash) and `apcap` (bound runaway compute) *before* letting it run free. These are
  exactly the safety nets an unattended agent needs.

## 5. Staging (each milestone gates green: host + ai0)

1. **Timer-tick + heartbeat stream** — agent loop runs on the clock alone, no net.
   Proves the supervised-task + watchdog shape. *(Smallest real milestone; the ai
   half is already runnable in `boot/kship.l`.)*
2. **virtio-net RX/TX + a `k_sources[]` socket slot** — echo a UDP datagram from the
   kernel. *(Hardest C; the keystone.)*
3. **`net.l` + `aineko` on bare metal** — the netcat clone runs *in the kernel*.
   Validates the whole stack end to end.
4. **`policy` reactive loop (A)** — a real policy over net + clock, checkpoint/restart
   working.
5. **(optional) LLM-in-the-loop (B)** — swap `policy` for a remote round-trip; needs
   only a JSON/SSE codec in ai.

## 6. Open questions / risks

- **virtio-net vs real hardware** — stay in qemu virtio for the prototype; a real NIC
  is a separate project.
- **TCP is the time sink** — if (A) tolerates it, do **UDP-first**; retransmit/
  windowing is weeks of work. (B) likely needs TLS → realistically a sidecar does TLS
  and the kernel talks plaintext to it on the local net.
- **Preemption depth** — is the scheduler cooperative (`yield`) or preemptive? An
  agent loop that never yields will starve net RX. Confirm the tick can preempt
  before milestone 4.
- **Determinism for testing** — drive the qemu net from a scripted peer so
  `make test_all` can assert agent behavior, like the existing kernel diffs.

## See also

- `boot/kship.l` — the runnable ai model of §3–§4.
- `kmain.c` — `k_sources[]`, `ai_wait_fds`, `ai_ready`, `ai_clock`, `ai_sleep`.
- the aineko / `ai_io` path-A plan (the netcat keystone that forces the net surface).
