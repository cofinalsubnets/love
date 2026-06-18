# bao — the shell, the rlwrap, and the debugger

The bao design + agent brief (see **Status** below for what has landed). **bao**
(steamed bun: a soft wrapper around a chewy command) is three things that turn out
to be one:

1. **the interactive shell** — line editing, history, prompt, the fault-face;
2. **the rlwrap replacement** — a pty wrapper that gives *any* program bao's editor;
3. **the debugger** — a `help` handler with a face, the condition system as a control plane.

All three are the same muscle (an editor + a wrapped process + the condition
system), so they share one tool.

## Status (2026-06-18)

Phase 1 is mostly landed; the next move is **path B** (the io/scheduler rework).
All bao work is on **`post`** now (the `trueblue` branch was dropped and its work
folded into `main`/`post`; `post` is the dev branch).

- **Landed:** the pty nifs (`host/pty.c`: `ptyrun`/`reap`/`kill`/`winsize`/`ptyecho`,
  `ab0e726b`), `wrap` (the transparent bidirectional pty pump with child-death
  teardown, `0420fe87`), `edraw` (bao's port-parameterized raw-line editor) +
  `bao.l` made **define-only** (`77c7cac0`), and the shell-split (`host/main.c`
  installs bao then launches `(bao 0)` on a tty; a pipe stays the bare filter —
  `74071dbb`). bao now also installs as a `bin/bao` launcher (`make install`).
  Gates: `make test_hostnif` (`pty: ok`), `cat test/00-init.l boot/baoedit.l |
  ai -l ai/bao.l` (`baoedit: ok`).
- **Blocked → path B:** wiring `edraw` *into* `wrap` (the real rlwrap: edited lines
  feed the child) was **built and reverted** — it deadlocks the cooperative
  scheduler (an editor task writing `out` while the pump task reads the master +
  writes `out`). The fix is not a half-duplex shortcut; it is the io rework below.
- **Path B — DESIGNED + MODELED, COMMITTED (`b9f87013`):** `doc/stream.md` (the
  four-defect diagnosis, the coinductive `source` hot, `read`-as-a-pure-fold,
  `select`/`ready?`, the staged migration) and the **pure half MODELED and green**
  in `boot/stream.l` (a `boot/tag.l`-style companion: `cat test/00-init.l
  boot/stream.l | out/host/ai` → 17 asserts + `stream: ok`). What remains is the
  **C build**: a dedicated **core `ai.c` session** (the core thread owns
  `ai.c`/`ai.h`); bao's part is then the `bao.l`/`repl.l` ports + the rlwrap wiring.
- **Next:** (1) core lands path B in `ai.c` (the `source` hot + `select`/`ready?`),
  unblocking the rlwrap wiring; (2) bao ports `bao.l`/`repl.l` onto the stream
  surface + re-lands `edraw`→`wrap`; (3) Phase 2 (the debugger — a `help` handler
  with a face).

## LANDED — repl → bao consolidation (the namespace cleanup, user-directed)

✅ DONE. **repl.l is gone; bao.l is the baked shell core for all three frontends**
(host + kernel + ai0). The editor (`ed*`), the history zipper, `parseall`,
`do_eval`, `repl`, `shell-help`, the raw-line decode (`bev`/`besc`), and the pty
pump (`pump`/`waitfor`) now live INSIDE one closure in `bao.l`, off the global
bag. Only the entry points are globals: `shell`, `welp`, `edraw`, `wrap`, `bao`,
`bao-selftest`, plus the stream shell `zev`/`zevs`/`charms`/`charms->chars` (+ one
intermediate holder `bao-exports`). `(names ())` dropped **276 → 248** (−28); the
`ed*` set went **15 → 1** (only the public `edraw` survives).

KEY MECHANISM (probed): post-egg the `bag` table is mopped, so a top-level
body-LESS `(: ..)` defglob is the ONLY way to add a global. The fix: a top-level
body-having `(: ..)` defines all the privates and RETURNS the public closures as a
list (`bao-exports`); a body-less `(: ..)` then defglobs `shell`/`welp`/... out of
it. The host-only pty nifs (`ptyrun`/`reap`) are DEFERRED via `(ev 'ptyrun)` --
quoted symbols are inert at bake time (a direct free ref would fire `missing` and
break ai0 pass 2 / the kernel bake; PROVED both ways), and resolve to the live
nifs on the host. The editor unit battery moved from the corpus (`test/repl.l` +
`test/replio.l`, deleted) into `bao-selftest` (computes the booleans against the
private helpers, returns a flat list) + `boot/baotest.l` (gates that list through
the real `assert`, wired into `make test_hostnif`). `test/zev.l` stays in the
corpus (zev/zevs/charms are public). Gate: host 2650 / ai0 2650×2 / kernel 2445
(qemu) / proof green / hostnif pty+net+baoedit+baotest all `: ok`.

The ORIGINAL plan (kept for the record):

Goal (user, as bao): the editor/repl internals must NOT leak as user-visible bag
globals just because the corpus tests them. **Move repl.l's content into bao.l,
remove repl.l, move its tests, so bao becomes the shell core and the `ed*`/repl
names leave the global namespace.** This is the bao half of [[siri-namespace-triage]]
release item #1.

⚠ ARCHITECTURE FINDING (probed `a8e32ad1`): `repl.l` is NOT host-only — it is the
**shared baked shell core** for THREE frontends, so this is an atomic multi-frontend
cut, not a file rename:
- **kernel** (`port/kship/kmain.c`) calls `(shell 0)` and BAKES repl — it has no file
  loader, so the shell must be baked into the kernel image (it can't `-l bao.l`).
- **ai0** (`host/main.c` `#include "repl0.h"`) — the self-test runner is
  `(zevs (sip (s2cl tests)))`; `zev`/`zevs`/`s2cl` come from repl.l.
- **host** (`host/main.c` `#include "repl.h"`) — non-tty stdin is `(zevs in)`.

So the end state is: **bao IS the baked shell core** (kernel + ai0 + host bake `bao`,
not `repl`). Defensible and cleaner (one shell, named bao); the `ed*` editor names
stop being user globals because the editor lives inside bao's scope.

Migration steps (atomic — gate host + ai0 + kernel together, can't half-land):
1. Move repl.l's bodies into bao.l: the editor (`ed*`, history), the stream shell
   (`zev`/`zevs`/`shell`/`charms`/`s2cl`), the floor handler. Keep ONLY the entry
   points the C bake resolves by name (`shell`, `zevs`, `s2cl`, `zev`) as bag
   globals; wrap the `ed*` editor + helpers in a closure so they don't leak.
2. Makefile: `repl0.h`/`repl.h` → `bao0.h`/`bao.h` (the `gl0_h` list, the `lib_h`
   lcat rule, the `$(ho)/host/main.o` + `$(ho)/ai` prereqs). bao.l is already lcat'd
   to `bao.h`; fold repl's role in.
3. `host/main.c`: `#include "repl0.h"`/`"repl.h"` → the bao headers; update the
   prose comments (they cite repl.l).
4. `port/kship/kmain.c`: bake bao instead of repl; `(shell 0)` still resolves.
5. Tests: `test/repl.l` + `test/replio.l` + `test/zev.l` test `ed*`/`parseall`/`zevs`
   by NAME in the CORPUS (concatenated, no `-l`) — that's the leak's root. Move the
   editor-internal asserts to a bao-loaded test (the `boot/baoedit.l` pattern:
   `cat test/00-init.l boot/baoX.l | ai -l ai/bao.l`, gated by `make test_hostnif`);
   keep only the genuinely-public behavior (if any) in the corpus. The kernel
   K_TEST corpus that needs `zevs` keeps reaching it (it's a baked bag entry still).
6. CLAUDE.md: the repl.l references (the "repl reads each LINE" note, the bootstrap
   section's `repl.l` mentions) → bao. grep repl across .l + C + docs.
7. `(names ())` should drop the `ed*` set (~22) once the editor is closure-scoped.

Gate: `make test` (host + ai0×2) AND `make test_all` (kernel) — the kernel bake is
the load-bearing verification. This is a clean-cut fresh-session job (like the
true-blue reseat); do NOT start it without room to finish + gate all three frontends.

## Agent brief — you are the bao thread

You build bao, in parallel with the aineko / cook / kship threads.

- **Your territory (you own these):** `bao.l` (the shell, split out of `repl.l`),
  `host/pty.c` (the ptyrun/reap/kill/winsize nifs).
- **Read-only for you:** `ai.h`, this doc, `ai/repl.l` (you reuse its editor —
  read it, and coordinate with the core thread before *moving* code out of it),
  `main.c` (`host_run` is the `ptyrun` template).
- **DO NOT EDIT `ai.c` / `ai.h` / `main.c`** or other threads' files
  (`host/net.c`, `tools/aineko.l`, `kmain.c`, `cook/cook.l`). Need a core change?
  **Stop and ask the core thread** (the main Claude session) — it owns ai.c/ai.h.
- **The nif pattern:** add pty nifs in `host/pty.c` via `AI_NIF` (see `host/host.c`
  for the worked `getpid` example) — auto-globbed, no core edit.
- **Two halves, different readiness:**
  1. **Shell-split (`repl.l` → `bao.l`) — start NOW**, independent of everything.
  2. **pty-wrapper (`host/pty.c`) — AFTER aineko's host-nif foundation lands**
     (you reuse its pump/teardown discipline; `ptyrun` extends `host_run`).
- **The `repl.l` split needs core-thread coordination** (it changes `main.c`'s
  shell auto-select + the egg bake) — propose it to the core thread, don't do the
  `main.c` half yourself.
- **Gate:** `make test` green; your pty nifs are gated by **`make test_hostnif`**
  (runs `boot/pty.l` against the built `ai` — host nifs aren't in ai0, so they
  can't be corpus tests; the target is the core thread's home for exactly this).
  Your `boot/pty.l` is already wired in (`hostnif_tests` in the Makefile) and
  passes. pty mechanics are scriptable; full interaction is manual.

## The core/shell split

Raw **`ai` shrinks to a pure read/eval/write filter** — trivially callable,
pipeable, embeddable — and **bao is the whole interactive shell.** This is mostly
*already* the factoring and needs **no new flag:**

- `cli.l` already read-eval-writes stdin to EOF when given no program (the bare
  filter exists), and `-l/--load FILE` already preloads a lib. So **bao is just a
  loadable lib: `ai -l bao` launches the shell** (no flag collision — bao *is* the lib).
- The work is a refactor: move `repl.l`'s editor/shell surface → **`bao.l`**;
  `main.c` stops auto-selecting `(shell 0)` and always runs the bare stdin runner.
- **tty default:** auto-load bao on an interactive tty (keep the `isatty` gate),
  but **piped/redirected stdin stays the bare filter** (`echo '1=1' | ai` → bare
  read/eval/write; `ai` on a tty → bao shell).
- Bonus: the egg need not bake `repl.l` unconditionally → a leaner core image, the
  shell loads on demand. Dovetails the shared-object/multi-call plan
  (`runtime-personalities-so`): thin core + `libai.so` egg + load the personality
  on demand.

bao keeps **both hats**: the in-process shell (the line editor, loaded as the
shell) and the pty-wrapper/debugger (wrapping *other* programs). Same bao, two roles.

## What already exists (so bao is mostly not new work)

- `ai/repl.l` is **already** a full raw-mode / ANSI / multiline / history editor (a
  four-zipper editor + history zipper) — the *readline* half of rlwrap is done.
- `main.c` already has termios raw mode + the `isatty` gate.
- `host_run` (main.c: fork/execvp + an errno-pipe handshake) is the `ptyrun` template.
- `ai_io_alloc(g, fd)` (ai.c) wraps any fd as a heap port with a close finalizer.
- **Multiplexing is free:** the cooperative scheduler `poll()`s every fd a parked
  task blocks on — two pumps on different fds interleave with no select loop.

## The io foundation bao carries — the stream redesign (path B)

> **Full implementable design: `doc/stream.md`** — the deadlock diagnosis (the four
> structural defects), the `source` hot, `read`-as-a-pure-fold, `select`/`ready?`,
> the delete/keep ledger, the staged migration, and the minimal-fix fallback. This
> section is the summary.

The current `get`/`unget`/`end?`/`key?` port surface is **POSIX wrongly
embedded in the core.** Four leaks: a mutable `ungetc_buf` in every port; the `-1`
EOF sentinel (un-ai — absence is the zero point, and `-1` collides with byte 0,
which already nets nothing); `next_wait_fd` set *inside* `lvm_fgetc` (the generic
VM knowing about fds/poll); `key?` polling only stdin (no general "ready?").

**Boundary principle:** the core knows generic-apply + scheduler-yield; "bytes out
of an fd" is a *host* concern presented as a value of an existing kind — the list.

Replace it with **an fd as a coinductive byte-stream** (a `two` whose tail forces
on demand; a stream `hot` presenting under `cap`/`cup`/`!`/`twop`):

- **EOF = `()`** — test the *stream* for emptiness, never a byte for `-1`. The
  condition rides the container, in-band, as a value. This is *floor-is-the-runtime*:
  a stream that bottoms out at `()` hands control back to `g`.
- **Lookahead = the cons cell** — hold the tail; `ungetc` is deleted. `read`
  becomes a pure `stream → (datum . stream')` parser, which **collapses the whole
  more-bit / port-back-when-incomplete / help-continuation read protocol**:
  "incomplete" just means you still hold the tail and force it when more arrives.
  The stream *is* the continuation.
- **Unifies three secretly-one things:** `sip` (charlist→stream), an fd-stream, and
  the reader's consume surface. `(source 0)` replaces `in`; `sip` is the same
  primitive fed from memory.
- Scheduling moves into the host's tail-forcing thunk — the one place fd-awareness
  legitimately meets `ai_wait_fds` — so `lvm_fgetc`'s fd logic and `key?` both delete.

**The one genuinely-new primitive:** you can't block on two streams with pure
`cap`/`cup`, so multiplexing needs `(select streams)` → the ready stream (or
`(ready? s)`). Stream-shaped, not fd-shaped — the real replacement for `key?` and
the only thing not already expressible. Design this one carefully. The runnable
companion is the pure half modeled over a list producer.

## Phase 1 — bao the wrapper (rlwrap). ~3 sessions. Build `aineko` first.

`aineko` establishes the pump/teardown/test infra bao reuses, so it comes first.

- **Stage 1 — `(ptyrun argv)` keystone (~1 session, main.c).** → `(pid . master-port)`
  | errno-fixnum. `posix_openpt`+`grantpt`+`unlockpt`+`ptsname` (avoids `-lutil`);
  fork; child `setsid` + open(slave) + `TIOCSCTTY` + dup slave→0/1/2 + `execvp`;
  parent master → `ai_io_alloc`. Extends `host_run` + the errno-pipe handshake.
  Gate: ptyrun `cat`, write a line to the master, read the echo back.
- **Stage 2 — lifecycle nifs (~½ session, main.c):** `(reap pid)` → status **as a
  PAIR** (status 0 is blue/false, so a bare status can't be told from `()` "still
  running" — a poll loop would spin; the pair distinguishes them); `(kill pid sig)`
  — note `(0 - pid)` signals the group, never `-pid` (which lexes as a kebab name);
  `(winsize)` get / set via `TIOC[GS]WINSZ` + SIGWINCH.
- **Stage 3 — `bao.l` (~1 session):** ptyrun the child; reuse repl.l's raw-mode
  editor as the line-reader; spawn a (master→stdout) pump; editor-line→master;
  teardown per the funnel-through-one-death rule: master EOF → hush the editor +
  restore tty + reap; your EOF → forward VEOF (byte 4) so the child exits (needs a
  canonical-mode child). **Key unknown:** is repl.l's editor cleanly callable as
  "read one edited line from fd X," or tangled in the repl read loop? Verify here.
- **Stage 4 — winsize/SIGWINCH polish + ship (~½ session).**

## Phase 2 — bao the debugger (post-v1, a design project)

The ai-native shape: **a debugger is a `help` handler with a face.** The condition
system (help/scare/welp, the more-bit resume, scare?/more?/eof?) was *built* for this.

- The child ai installs a debug `help` that, on a scare, instead of welping, **hands**
  the condition (status + data + scope/stack context) to bao over the pty (or a side
  channel) and **parks** on the help continuation.
- bao presents a debug REPL (its editor): inspect the condition + locals/scope +
  stack; `continue`/`abort`/`retry` flow back through the child's help continuation
  (the more-bit resume already exists).
- A meta-command plane (a prefix key / `:`-command) distinguishes bao's own debug
  commands from child passthrough.
- `(break)` = a form that raises a debug-scare bao catches (source-level breakpoints
  via the condition system). Single-step is harder (needs VM hooks) → defer.
- The design project is the debug *protocol* between child-help and bao.

## Where bao sits in the family

Roadmap: **true-blue → aineko → kship**, with **bao a sibling off aineko**, not on
the critical path. Three couplings keep it in the family:

1. **Needs aineko first** — bao's pty wrapper (`ptyrun` + lifecycle nifs) is the
   same host-nif muscle aineko builds.
2. **bao's debugger ≈ kship's watchdog** — both are "a `help` handler with a face":
   one watches a wrapped process, one watches its own agent loop; shared face-rendering.
3. **bao is where path-B lives** — the coinductive `(source fd)`/`select` stream
   redesign above, which is *also* the io abstraction kship's net-perceive layer
   wants (the kernel already has the `ai_wait_fds`/`ai_ready` half).

So aineko is the shared prereq; bao and kship are siblings — one wraps host
processes, one drives bare metal — that meet again at the stream + condition layer.

**Risks:** editor reusability (Stage 3); interactive testing is a weak gate
(mechanics scriptable, full interaction manual); signal safety (SIGWINCH/SIGCHLD in
the cooperative VM); VEOF needs a canonical child; the Phase-2 debug-protocol design.
