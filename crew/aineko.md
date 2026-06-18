# aineko — a netcat clone in ~50 lines of ai

A design sketch (recon done, ready to build). **aineko** (neko = cat, 愛猫) is a
clone of OpenBSD `netcat`: `aineko host port` opens a TCP client, `aineko -l port`
listens; bytes pump both ways between the socket and stdin/stdout, with DNS. It is
the **flagship "real apps day one" demo** — the first app that proves ai can do
real host I/O — and the shared trunk the later tools (`bao`, `kship`, `doc/posix.md`)
hang off of.

We skip what netcat carries for completeness but a demo doesn't need: UDP, TLS,
`-z` (port scan), `-x` (proxy). Client + server + DNS is the whole thing.

## Agent brief — you are the aineko thread

You build aineko, in parallel with the bao / cook / kship threads. The rules that
keep us from colliding:

- **Your territory (you own these, edit freely):** `host/net.c` (the socket nifs),
  `tools/aineko.l`, a new `make nettest` target + its loopback fixture.
- **Read-only for you:** `ai.h` (your nif-writing surface), this doc, `main.c`
  (`lvm_open`/`host_run` are your templates — read, don't edit).
- **DO NOT EDIT `ai.c` or `ai.h` or `main.c`.** Those are the **core thread's**
  (the main Claude session). If you need a core change — a new accessor, a struct
  field, an `ai_io` tweak — **stop and ask the core thread**; don't reach in. Same
  for any other thread's files (`bao.l`, `host/pty.c`, `kmain.c`, `cook/cook.l`).
- **The nif pattern (no core edit needed):** add nifs in `host/net.c` —
  `#include "ai.h"`, define `lvm_<x>` + `nif_<x>[]`, then `AI_NIF("name", nif_<x>)`.
  The Makefile auto-globs `host/*.c` and boot drains the section. See `host/host.c`
  for the worked example (the `getpid` nif).
- **You are the shared trunk:** bao's pty-wrapper and kship's net layer reuse your
  pump/teardown discipline and the host-nif pattern. Land Stage 1 cleanly; it's the
  foundation two other threads build on.
- **First task:** Stage 1 (connect/listen/accept/shutdown + DNS) in `host/net.c`,
  gated by `make nettest` (host-only loopback). Then Stage 2 (`tools/aineko.l`).
- **Gate:** `make test` must stay green (you don't touch the corpus); your own gate
  is `make nettest`. Keep `ai/prel.l` free of unconditional socket refs so
  kernel/wasm stay green.

## Why netcat is the ideal first app

A netcat is a **bidirectional pump**: stdin → socket and socket → stdout, both
live at once. That shape is *exactly* what the cooperative poll scheduler was
built for. Two `(spawn)`ed pump loops, each blocked in a port read on a different
fd, interleave with **no select loop** — the scheduler `poll()`s every fd a parked
task blocks on (`ai_wait_fds`, main.c) and wakes the ready one. So the `.l` program
is tiny (~40–60 lines: spawn two pumps over the existing read/write port nifs); the
real work is the **socket nifs in C**.

## The mechanism — the host-nif pattern

Every host nif is four pieces (all host-only, in `main.c` — no `ai.c`/`ai.h` edits):

1. `call_X` — an `ai_noinline` syscall worker (the actual `connect`/`accept`/…).
2. `lvm_X` — the VM tail-call wrapper (Pack/Unpack around `call_X`, push the result).
3. `nif_X[]` — the threaded-code body (`{lvm_X}{lvm_ret0}` or curried).
4. a `{"name", (ai_word) nif_X}` row in the frontend's `d[]` defn table (main.c).

**`lvm_open` is the exact template.** It does `fd → ai_io_alloc(g, fd)` (ai.c) → a
heap port carrying a close finalizer. Once an fd is a port, **read and write come
free** through the existing `getc`/`putc` machinery — a socket nif only has to
produce the fd and hand it to `ai_io_alloc`.

**The yield seam (already built):** the io read path sets `g->next_wait_fd`
(ai.c) and the scheduler consults it via `ai_wait_fds` (main.c). The read path
*already yields*, so two spawned pumps interleave without any new async code. This
is why blocking sockets are fine for a one-shot tool.

## The socket nifs (Stage 1 — the netcat-complete stage)

All mirror `lvm_open` (fd → `ai_io_alloc` → port):

- `(connect host port)` — `socket()` + `connect()` → port. Blocking is fine
  (aineko is one-shot). `host` resolves through `getaddrinfo` (blocking one-shot
  DNS — acceptable).
- `(listen port)` — `socket()` + `SO_REUSEADDR` + `bind()` + `listen()`.
- `(accept l)` — blocking `accept()` → port.
- `(shutdown s how)` — clean half-close, so a stdin-EOF can make the peer see EOF.

Read/write are free. That is the whole TCP core; netcat works at the end of Stage 1.

## The aineko.l shape (Stage 2 — pure ai)

```
client (aineko host port):  connect → spawn (socket → out) pump
                                     + run   (in → socket)   pump
server (aineko -l port):    listen + accept → the same two pumps
```

**Teardown is the load-bearing detail** (the lesson from the `bao`/aiwrap design):
funnel all termination through one path. Either side's EOF → `hush` the other pump
and exit; a stdin-EOF → `shutdown(write)` so the peer sees EOF rather than a hung
half-open socket. A naive "park forever, hush it later" is the bug to avoid: a task
blocked on one fd can't wake on another fd's event, so the pump that owns the
socket owns teardown.

## The fork in the road — pick the io foundation first

Two foundations, **decided before writing any socket nif:**

- **(A) extend `ai_io`** — sockets as ports on the current model. The async
  substrate already exists (`ai_io_alloc` wraps any fd; the scheduler polls blocked
  fds; read/write free). Contained, ~1 session. But it builds *more* on the surface
  the stream redesign (see `crew/bao.md`) calls "POSIX-in-core gum."
- **(B) ride the coinductive stream redesign** — replace `get`/`ungetc`/`-1`/`key?`
  with `(source fd)` (a stream hot: bytes under `cap`/`cup`/`!`, EOF = `()`, `read`
  a pure `stream → (datum . stream')`). A socket is then just another `source`/`sink`.
  Cleaner and unifies sip/fd/reader, but a multi-session rewrite before any socket
  lands.

**Release scope forces (A):** there's no time for (B) before the cut, and (A) is
not a dead end — the socket *syscall* nifs survive a later migration to (B); only
the fd-wrapping moves to `(source fd)`. So aineko ships on (A); (B) stays the
long-term io foundation (it lands with `bao`).

## Gating — keep the other frontends green

Sockets are **host + ai0 only** (both link `main.c`). The kernel (`kmain.c`) and
wasm don't link `main.c`, so they auto-exclude — provided `ai/prel.l` gains **no
unconditional socket references**. The loopback test goes in a **new `make nettest`**
(host-only, like cook's separate test), NOT the portable corpus, so `make test`
(host + ai0 ×2 + rocq) and `make test_all` (kernel/wasm build green without
sockets) stay unaffected — no VM or `ai.c` change.

**Contract:** edits live ONLY in `main.c` (+ a tiny `ai/prel.l` wrapper if needed);
`ai.h`'s `struct ai_io` stays byte-frozen (each frontend owns its vtable).

## Staged plan

- **Stage 1** — blocking TCP core (connect/listen/accept/shutdown + DNS). ~1 session,
  `main.c` only. Gate: host-only loopback in `make nettest`.
- **Stage 2** — `tools/aineko.l` (client + server, two pumps + teardown). ~½ session.
  Gate: scripted loopback (server task ↔ client, pipe a payload, assert echo).
- **Stage 3** — non-blocking + buffering polish (O_NONBLOCK + EAGAIN→yield for a
  concurrent server; `struct fdio` prefix-extends `ai_io` to kill per-byte reads).
  OPTIONAL, post-release-OK — not needed for one-shot aineko.
- **Stage 4** — ship: the "a netcat clone in ~50 lines" line in the README/paper.

**Risks:** `getaddrinfo` blocks (fine for one-shot); host-only test gating (→
`make nettest`); half-close semantics (the `shutdown` nif); keeping kernel/wasm
green (auto-excluded, but verify prel.l stays socket-free).

## LANDED + SHIPPED — Stage 1 + Stage 2 (green, all committed on `post`)

Built, verified, committed, and **installed as a `bin/aineko`** (`make install`).
The doc body above describes the OLD `main.c`-everything nif pattern; the actual
work used the newer `host/*.c` glob + `AI_NIF` auto-registration (commit
`bf6535b4`) — **zero edits to `ai.c`/`ai.h`/`main.c`**, the brief's pattern. The
Makefile fold-in (`nettest` target, `hostnif_tests += boot/net.l`) is all landed.

**The files (all on `post`):**
- `host/net.c` — the four socket nifs `(connect host port)` / `(listen port)` /
  `(accept l)` / `(shutdown s how)`. Each mirrors `lvm_open`: make an fd →
  `ai_io_alloc(g, fd)` → heap port (close finalizer); read/write then free via
  get/put. Auto-globbed into `host_o`, registered with `AI_NIF`. Blocking
  (one-shot); `how` is the POSIX SHUT_* fixnum (1 = write half-close).
- `tools/aineko.l` — client (`aineko HOST PORT`) + server (`aineko -l PORT`), two
  pump loops. Carries a `#!/usr/bin/env -S ai -l` shebang and installs as
  `bin/aineko`; runnable in-tree via `out/host/ai -l ai/prel.l tools/aineko.l …`.
- `boot/net.l` — in-process loopback smoke (assert harness, prints `net: ok`),
  wired into `hostnif_tests` (`make test_hostnif`).
- `test/net/loopback.sh` — the two-process full-duplex fixture (`make nettest`,
  port via `make nettest PORT=NNNN`). Deliberately NOT in `make test`/`test_all`
  (needs two live processes + a free port); `boot/net.l` covers the nifs portably.

**Next / remaining:** Stage 3 (non-blocking + buffering polish — O_NONBLOCK +
EAGAIN→yield, `struct fdio` to kill per-byte reads) stays OPTIONAL / post-release.
Stage 4 (the "a netcat clone in ~50 lines" line in the README/paper) is the only
release-facing item left. The longer arc is folding aineko into the multi-call
binary (`runtime-personalities-so`) so it dispatches by `argv[0]` rather than via
the `bin/aineko` launcher.

**Teardown — corrects this doc's "hush the other pump" sketch.** The two
directions are INDEPENDENT half-duplex channels: a socket-READ EOF does NOT mean
the WRITE side is dead. "Hush the other pump on either EOF" TRUNCATES outbound
data (a peer half-closing its write read-EOFs you while your stdin pump still has
bytes). Correct shape: run **stdin→socket in the OWNING (main) task** so it always
drains every stdin byte before any teardown (then `shutdown s 1`); run
**socket→stdout in a spawned task**; **join with `wait`, not `hush`**. Verified
full-duplex over loopback, no truncation, no deadlock. (This is the discipline
bao/kship reuse — aineko is the shared trunk.)

**Verification:** `cat test/00-init.l boot/net.l | out/host/ai` → 10/10 asserts,
`net: ok`, exit 0. `sh test/net/loopback.sh out/host/ai 7390` → `nettest: PASS`
(full-duplex, each side got exactly what the other sent). `ai/*.l` socket-free.
⚠ `make host`/`make nettest` were transiently red during this session ONLY from
the core thread's concurrent `main.c → host/main.c` move (their territory); the
binary built before the move runs everything green.
