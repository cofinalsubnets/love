# AGENTS.md

Instructions for any coding agent in this tree. CLAUDE.md holds the rest and imports this file.

## the lanes a change owes

`make test` is the fast gate, and every change runs it. Beyond it, a change owes the lanes of the files it touches, not of what it meant to change. A branch that gates only its own lanes is how a union goes red.

- `src/apps/kore/*` -> `test_kore` `test_hostnif`
- `src/apps/lush.l`, `src/apps/cook.l`, `src/apps/bee.l` -> `test_hostnif`
- `src/love/snap.c`, `src/love/image.c`, `Makefile`, `src/tools/hotbake.sh` -> `test_ccwarn` `test_hdiff` `test_inle`
- a crewfiles member, or anything else baked -> `test_fixpoint` `test_bakerep`, and `make hotprof` to write `src/tools/hot.prof` again (bakerep fails while it is stale)
- `src/apps/moon/*` -> `test_moon` `test_clay` `test_cca64` `test_ccrv64` `test_ccwasm` `test_ccthumb1` `test_ccthumb2` `test_fixpoint`
- `src/love/holo/*` -> `test_holo` `test_as`
- `src/apps/sb/*` -> `test_sb`
- `src/apps/hearts/*` -> `test_hearts`

`test_slow` runs last, on the exact tree that lands. The `test_cc%` lanes are pattern rules in `test/test.mk`, so grepping for `^test_cc...:` misses them.

## the machine is shared

Several sessions gate on one box. Two makes in one `out/` race, and a box short of memory reaps gates. A heavy lane waits its turn through `src/apps/locks.l` (`locks-run`; bee's `lock_*` tools):

- heavy: `test_slow` `test_extra` `test_inle` `test_kernel_%` `test_gcstress` `test_boards` `test_hearts`, and a `make out/love` from a clean `out/`
- one make at a time in an `out/`: an exclusive lock named by its path
- a lane that boots on another box takes that box's slot, not a heavy one: `KTEST_A64_HOSTS="six.lan:3 pi.lan:1"` (host:slots, fastest first) gives the a64 kernel lane kvm there, and each slot is an exclusive lock `a64host-HOST-N`. without it the lane runs tcg here, and is heavy. `KTEST_VMX_HOSTS` (tau.lan, network infra: one slot) is the VT-x box `test_kernel_vmx` boots on, in `test_extra` only

## the merge queue

Take part in a merge queue only through bee's tools: as a bee agent, or from Claude Code through the tree's `.mcp.json`, which loads `love bee --mcp` (`mcp__bee__queue_row`, `queue_lead`, `queue_land`, `queue_landed`, `inbox`). Never edit a queue by hand. The protocol is written once in `doc/bee.md`, THE MERGE QUEUE, and each queue's header states it.

When the queue is long (two or more rows waiting or gating, or more heavy-lock waiters than slots), fold, don't line up. One owner's branches join as one union that gates once, and each branch runs only its light lanes.

Start a Claude Code session in this tree as `claude --dangerously-load-development-channels server:bee` (a resume too), so bee's mail wakes it when idle; `doc/bee.md` says how. Without the flag, mail waits for the session's next bee tool call. To bring a session back after a restart or a crash, `love bee --resume NAME` (the names: `love bee --resume`) relaunches it under its own name, ringing.

After a landing that changes bee, every live session restarts at its next convenient point: between tasks, never mid-gate, in the same directory. bee says so itself, in the release note and when its binary is replaced.
