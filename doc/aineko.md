# aineko — a netcat clone in ~50 lines of ai

A design sketch (recon done, ready to build). **aineko** (neko = cat, 愛猫) is a
clone of OpenBSD `netcat`: `aineko host port` opens a TCP client, `aineko -l port`
listens; bytes pump both ways between the socket and stdin/stdout, with DNS. It is
the **flagship "real apps day one" demo** — the first app that proves ai can do
real host I/O — and the shared trunk the later tools (`bao`, `kship`, `doc/posix.md`)
hang off of.

We skip what netcat carries for completeness but a demo doesn't need: UDP, TLS,
`-z` (port scan), `-x` (proxy). Client + server + DNS is the whole thing.

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
  the stream redesign (see `doc/bao.md`) calls "POSIX-in-core gum."
- **(B) ride the coinductive stream redesign** — replace `fgetc`/`ungetc`/`-1`/`key?`
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
