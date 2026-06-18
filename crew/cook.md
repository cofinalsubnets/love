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
  (`hook`→`link`, `symp`→`nom?`), so every list-building call read the zero point.
  A two-token rename fixed all 30. **Lesson: when cook goes mass-red, first
  `out/host/ai -e "(puts (show NAME))"` the prel names cook leans on (`link`/`nom?`/
  `snip`/`tray?`/…) — a rename in the corpus surfaces as ALL tests red, not a logic
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

## ✅ LANDED 2026-06-18 — `exec` nif + interactive `cook repl` (commit `17a85032`)

`cook repl` (and `gdb`/`run`/`disasm`/`perf`) couldn't work: cook's `run` nif pipes
the child's stdout into a captured string and waits — no live tty. **Fix (user-approved
core touch):** added `(exec argv)` to `host/main.c` — an `execvp` passthrough that
REPLACES the cook process and inherits the terminal (returns only on failure, an errno
fixnum, marshalling argv into `cav` exactly like `host_run`). cook recognises an
**interactive step** two ways: a Cookfile `(exec PROG ARGS..)` form (`step1` → `do-exec`),
or a Makefile recipe line beginning with the shell **`exec`** builtin (`execp` in
`expand-steps`). One notation works in BOTH builders — `sh -c "exec ..."` already
replaces the shell in make. Verified under a pseudo-tty (`script -qec`); `make test`
green. Committed files: `host/main.c` + `cook/cook.l` only.

⚠ **Uncommitted, pending:** the `Makefile` interactive-target edits (`repl`/`gdb`/
`disasm`/`run*`/`perf` → `exec` prefix) are in the working tree but were NOT committed —
the `Makefile` had a parallel session's uncommitted edits (`GEN`→`AI` echo relabels), so
I couldn't cleanly separate hunks (`git add -p` is unavailable here). Commit my `exec`-
prefix lines once the Makefile settles, or hand to its owner.

## 🔲 DEFERRED — the build re-architecture (user paused: "do the rest later")

User's evolving vision across this session (NOT yet built):
1. **Cookfile = the build source of truth.** Seed it once from the current Makefile
   (`cook --emit Makefile > Cookfile`, at repo ROOT). The committed `cook/Cookfile` is
   STALE (references long-gone `data.h`/`repl.h`/`main.c`) — regenerate from scratch.
2. **Top-level `Makefile` = a GENERATED, checked-in bootstrap artifact**, regenerated
   from the Cookfile **each commit, like `wasm/ai.js`** (a `.githooks/pre-commit` rule).
   It exists so a fresh clone can `make` before any `cook` binary exists (chicken/egg).
3. **Archive the original hand-written Makefile → `doc/Makefile`** (COPY decided earlier,
   but #2 supersedes: with the Makefile regenerated, the archive is the reference).
4. **Reverse translation `cook --emit-makefile`** (Cookfile → Makefile) is the keystone
   that generates #2. ⚠ **Snapshot caveat to flag to the user:** `--emit` resolves
   `$(shell)`/`$(wildcard)`/`ifeq` + the git version AT EMIT TIME, so a flat Cookfile
   (and a Makefile regenerated from it) FREEZES the file list, toolchain probes, and
   version string. Verify the regenerated Makefile passes `make test` **before** swapping
   the real one — do not break the gate/bootstrap.
5. **User's open design Q: "can this share code with the other direction? a lens or
   something?"** — i.e. unify the forward (`emit-cookfile`, Makefile→Cookfile) and reverse
   (`emit-makefile`, Cookfile→Makefile) translators as ONE bidirectional lens over the
   `cards` representation, instead of two hand-written printers. Worth exploring: both
   directions are just (cards ↔ surface-syntax); a get/put lens or a single
   declarative rule table could halve the code. Design before building.

### Bug to resolve first (my `--emit-makefile` attempt, REVERTED in `17a85032`)
My WIP `--emit-makefile` (mkemitp box + `cook` guard + `emit-makefile`/`mk-rule`/`mk-line`
block + parse-args clause + dispatch branch) made cook's **dispatch stop firing under
`-l`** — even the previously-working `--emit` failed with `ai: cannot open --emit` (the
host CLI fell through to the flags). Yet all 5 top-level forms `read` AND `ev` fine in
isolation. So it's NOT a parse/compile error — the dispatch ran and took the wrong branch
(didn't `exit`), meaning `parse-args`/`mk-args` saw the flags differently, OR a runtime
raise under real `argv` aborted the `-l` load. **Next time: add a debug print of
`(mk-args argv)` + `opt` inside the dispatch to see exactly what cook receives under
`-l`, before re-adding the feature.** Clean save point: the green commit `17a85032`.
