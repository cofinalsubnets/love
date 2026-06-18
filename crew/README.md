# crew — the app personalities

These are the **agent personality files** for the apps built on top of the `ai`
core. Each `.md` is an *agent brief*: a self-contained doc a dedicated agent
session is pointed at to develop that app — its territory (which files it owns),
its do-not-touch list, the sync rule with the core, its current state, and its
roadmap. One doc per crew member; non-overlapping file territory so the sessions
run in parallel without colliding. (`ai.c`/`ai.h`/`host/main.c` are the only
shared files — core changes route through the core thread, never a crew session.)

The crew is built by [`crew/<member>.md` as personality], coded in `ai`/`host`/`port`,
and (for the runnable ones) installed on `PATH` by `make install`.

## Current crew

| member | what it is | lives in | installed bin |
|---|---|---|---|
| **aineko** | a netcat clone (愛猫, "beloved cat") — TCP client/server over the socket nifs | `tools/aineko.l`, `host/net.c` | `aineko` |
| **bao** | the interactive shell / rlwrap-style pty wrapper / debugger (one editor + the condition system) | `ai/bao.l`, `host/pty.c`, `boot/pty.l` | `bao` |
| **cook** | a GNU-make-compatible build tool written in ai (builds the host from scratch) | `cook/cook.l` | `cook` |
| **kship** | the freestanding ai-kernel as a self-driving agent — boots on bare metal, perceives the NIC, runs the language over UDP | `port/kship/` | (boot image: `make kernel KSHIP=1`) |

The personality docs are the *source of truth* for each app's design and status;
the code is in the `lives in` column. `make install` puts the runnable ones
(`aineko`, `bao`, `cook`) on `PATH` next to `ai`; kship ships as a bootable kernel
image instead of a bin (`make kernel KSHIP=1` → an ISO you `dd` to a USB stick).
