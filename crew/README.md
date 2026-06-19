# crew — the kship crew

The **agent personality files** for the **kship crew**: the programs that ride on
**kship**, the freestanding ai kernel (a ship in port). Each `.md` is an *agent
brief* — territory, do-not-touch list, sync rule with the core, state, roadmap. One
doc per member; non-overlapping file territory so the sessions run in parallel.
(`ai.c`/`ai.h`/`host/main.c` are the only shared files — core changes route through
the core thread.)

## Current crew

| member | sign | what it is | lives in |
|---|---|---|---|
| **tele** | ♊ | the pilot — sees and drives kship; the eye that scopes constellations (tensors + autograd) | `tele/tele.l`, `port/kship/kship.l` (the `policy` seam) |
| **zev** | ♓ | the sounder — `sound`: charms into forms, a parser-combinator vocabulary | `parse/zev.l` |
| **wev** | ♍ | the spinner — `feel`: the source prepass (macroexpand, boxfix, fold), grown into a partial evaluator | `peval/wev.l` |
| **bellberry** | — | the evaluator — `ev`: compiles the language and runs it (feel ∘ sound = wev ∘ zev); a silver rabbit | `ai/ev.l` |
| **gwen** | ♎ | the synthesist — keeps the human words and the ai words in agreement | `ai/{ev,prel,egg}.l` + the docs |
| **mow** | ♉ | the garbage collector — a cow; tends the two-space copying collector (the litter box) | the GC cluster in `ai.c` + `ai.h` |
| **bao** | ♋ | the shell — soft wrapper / rlwrap-style pty wrapper / debugger | `ai/bao.l`, `host/pty.c`, `boot/pty.l` |
| **aineko** | ♌ | the cat — netcat (愛猫, beloved cat) over the socket nifs | `tools/aineko.l`, `host/net.c` |
| **cook** | ♑ | the builder — make-in-ai (builds the host from scratch, passes the corpus) | `cook/cook.l` |
| **kship** | ♒ | the ship — the freestanding ai-kernel as a self-driving agent on bare metal | `port/kship/` |

**ev is bellberry** — the evaluator is the action made a member: **ev = feel ∘ sound**
(= wev ∘ zev), the spinner after the sounder. The two input lanes, characters and data,
meet at one core in her via the copairing `[sound, id]`.

The personality docs are the *source of truth* for each app's design and status.
`make install` puts the runnable ones (`aineko`, `bao`, `cook`) on `PATH` next to
`ai`; kship ships as a bootable image (`make kernel KSHIP=1`). gwen and mow are no-bin
roles — gwen keeps docs and surface in agreement, mow tends the collector.
