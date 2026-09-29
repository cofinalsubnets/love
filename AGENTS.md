# AGENTS.md

Instructions for any coding agent in this tree. CLAUDE.md holds the rest and imports this file.

## the lanes a change owes

`make test` is the fast gate, and every change runs it. Beyond it, a change owes the lanes of the files it touches, not of what it meant to change. A branch that gates only its own lanes is how a union goes red.

- `apps/kore/*` -> `test_kore` `test_hostnif`
- `apps/lush.l`, `apps/cook.l`, `apps/bee.l` -> `test_hostnif`
- `love/snap.c`, `love/image.c`, `Makefile`, `tools/hotbake.sh` -> `test_ccwarn` `test_hdiff` `test_inle`
- a crewfiles member, or anything else baked -> `test_fixpoint` `test_bakerep`, and `make hotprof` to write `tools/hot.prof` again (bakerep fails while it is stale)
- `apps/moon/*` -> `test_moon` `test_clay` `test_cca64` `test_ccrv64` `test_ccwasm` `test_ccthumb1` `test_ccthumb2` `test_fixpoint`
- `love/holo/*` -> `test_holo` `test_as`
- `apps/sb/*` -> `test_sb`

`test_slow` runs last, on the exact tree that lands. The `test_cc%` lanes are pattern rules in `test/test.mk`, so grepping for `^test_cc...:` misses them.
