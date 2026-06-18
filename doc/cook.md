# cook — the make-in-ai build tool

`cook/cook.l` is a GNU-make-compatible build tool written in ai: it reads a
Makefile (or a `Cookfile`), resolves recipes, and runs them — and `cook --emit`
transpiles a Makefile into a flat, fully-resolved `Cookfile`. It already builds the
host from scratch and passes the corpus. The man page is `doc/cook.1`.

## Agent brief — you are the cook thread

You build cook, in parallel with the aineko / bao / kship threads. You have the
**lightest coupling** of the four: cook is pure ai over `ai/cli.l`'s rebound argv,
so it needs **no entry change and no core change** to make progress.

- **Your territory (you own these):** `cook/cook.l`, `cook/cooktest.l`, `cook/`'s
  fixtures, `doc/cook.1`. The cook test is `test_cook` (run by `make -C tools`).
- **Read-only for you:** `ai.h`, this doc, `ai/cli.l` (cook reads the rebound
  `argv` — `cli.l` stops at the first non-flag; cook parses `(cup argv)`).
- **DO NOT EDIT `ai.c` / `ai.h` / `main.c`** or other threads' files
  (`host/*.c`, `tools/aineko.l`, `bao.l`, `kmain.c`). Need a core change? **Ask the
  core thread** (the main session) — but cook almost certainly doesn't need one.
- **✅ First task — the red tests (DONE).** `test_cook` was 2 pass / 30 FAIL — but
  the cause was NOT make-function bugs: cook.l had drifted off the vocab renames
  (`hook`→`link`, `symp`→`nomp`), so every list-building call read the zero point.
  A two-token rename fixed all 30. **Lesson: when cook goes mass-red, first
  `out/host/ai -e "(puts (show NAME))"` the prel names cook leans on (`link`/`nomp`/
  `snip`/`trayp`/…) — a rename in the corpus surfaces as ALL tests red, not a logic
  bug.** Now **32 pass**.
- **✅ Then the cook UX (DONE).** cook owns its own arg parse over the rebound argv
  (`parse-args`, a tablet of `'file 'emit 'help 'ver 'pos`):
  - recipes = non-flag args, **all built in order** (`make foo bar`) via `cook-all`;
  - `-f`/`--file FILE` (errors `cannot open` if missing); positional file still works
    for back-compat (`cook Makefile all`) when no `-f`;
  - `--emit`; `-h`/`--help`/`help`; `-v`/`--version`/`version` (bare words too).
  - **`cook-all` is exposed** for Cookfiles: `(cook-all 0)` builds every named recipe
    (or the default), `(cook (ticket 0))` builds just the first. `--emit` now ends the
    generated Cookfile with `(cook-all 0)`.
- **Policy (user-ratified):**
  - **Only a Makefile is make.** Type is probed by **name** (`makefilep`:
    `Makefile`/`makefile`/`GNUmakefile`/`*.mk`) — NOT by content. Everything else
    (`Cards.l`, `Cookfile`, any `-f FILE`) is ai source. (Considered a content probe;
    user said keep it name-based.)
  - **Discovery order = `Cards.l` → `Cookfile` → `Makefile`** (ai-native wins over
    make), reversed from the old Makefile-first order.
- **Gate:** `make -C tools test_cook` green; `make test` stays green (cook touches
  only `cook/` + `doc/`, never the corpus or core).
