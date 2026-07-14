# makefile split — breaking up the 1635-line root

Status: **design note, not started.** The root `Makefile` inlined two builds that used to be
their own files — the banners still say so (`# host (POSIX CLI) build -- Was host/Makefile`,
`# kernel (freestanding) build -- Was free/Makefile`). This note plans splitting them back out
as **non-recursive include fragments**, each living next to the source it builds. `common.mk`
(shared vars) and `cook.mk` already exist; wasm/tools/bench keep their own recursive Makefiles.

## the regions today

| region | lines | ~size |
|---|---|---|
| header + cross-cut test orchestration (test/test_all/test_ai0/test_host/hostnif/doc) | 1–130 | 130 |
| **crew/app test targets** (glaze, sat, lux, kore, cc, vi, holo, selfhost, raw, proof, gc, gen, uu…) | 131–764 | ~630 |
| lib/header baking (`lib_h`, holo/x64/arm64/export, uuwm, emit/auto, version) | 765–868 | ~100 |
| **host build** (version, host, ai0, libai, object+link rules, dock, candidate, manpage) | 869–1090 | ~220 |
| **kernel build** + run/qemu/iso/hdd + kernel/wasm test wiring | 1092–1418 | ~330 |
| downloads + install + clean + valg + ulp | 1419–1635 | ~215 |

## the decisive constraint: non-recursive only

Do NOT make these child Makefiles (`$(MAKE) -C host`). The `lib_h` bake (`lib_h = $(patsubst
ai/%.l,out/lib/%.h,$(wildcard ai/*.l))`) is the shared spine — the baked `out/lib/{egg,prel,ev,…}.h`
feed host objects, kernel objects, AND wasm. Recursive sub-makes would each re-bake that spine and
serialize the `-j` build across frontends. Recursive make is correct ONLY for the genuinely
independent leaf builds already doing it (tools, wasm, bench, the limine download).

So: **`include` fragments, one make process, shared variable scope** — pure textual reorganization,
zero behavior change. That property is what makes the split mechanically verifiable (below).

## proposed layout

```
common.mk          — shared vars (absorb ai0 + ho/ko/hsuf/tco/lib_h/ai_h so fragments are self-sufficient)
Makefile           — thin: the include list + cross-cut orchestration (test_all umbrella,
                     the lib_h baking spine, install/clean/distclean, downloads) — ~350 lines
host/build.mk      — the host POSIX CLI build (was host/Makefile)      ~220 lines
port/inle/build.mk — the kernel build + run/iso/qemu + kernel tests    ~330 lines
mk/apps.mk         — the crew/app test-target block (the real bulk)    ~630 lines
```

`host/` and `port/inle/` place each build next to its source, matching the existing per-port
Makefiles. `mk/apps.mk` is the biggest single win — over a third of the file, all crew test
targets. (Alternative if scattering grates: park everything under a central `mk/`. The subfolder
placement is the recommendation for host/inle.)

## migration order — each step a clean, verifiable slice

1. **Consolidate shared vars into `common.mk`** (ai0, ho/ko/hsuf/tco, lib_h, ai_h). Verify:
   `make clean && make` unchanged.
2. **Extract kernel → `port/inle/build.mk`** first (most self-contained — separate object tree
   `$(k_odir)`, its own `KCC`). Verify: `make kernel`, `make test_kernel`, `make test_arm64`.
3. **Extract host → `host/build.mk`.** Verify: `make host`, `make test_host`, `make test_ai0`.
4. **Extract crew tests → `mk/apps.mk`.** Verify: `make test_all`.
5. Root is left as orchestration + the lib spine + includes.

Strong equivalence check at each step: diff `make -pqn` (the fully-resolved rule database)
before/after — if the split is pure motion, the dump is identical.

## gotchas to respect

- **Parse-time ordering** — the file already warns about it (the `ai0 =` comment): prerequisite
  lists and `:=` expand at parse time, so a var must be defined by an EARLIER include than the
  target that names it. Fixed include order handles it: `common.mk → lib-spine → host → inle →
  apps → install`.
- **Root-relative paths stay** — an included fragment runs with cwd=root, so `host/build.mk`
  still writes `host/main.c`, not `main.c`. Mildly odd but correct; it's the price of
  non-recursive include (and why `common.mk` carries the `$R` convention for out-of-tree ports).
- **Self-re-invocation targets keep working** — `run-inle`, the `K_TEST=1 …iso`, the `STATIC=0`
  valg line re-invoke the ROOT Makefile, which re-assembles all fragments. No change.
- **`.PHONY`** — each target's `.PHONY` moves with it; the umbrella (`all test test_all install
  clean`) stays in root.

Net: a 1635-line monolith → a ~350-line orchestration root plus three focused fragments of
220–630 lines, each next to what it builds, with a byte-for-byte verification at every step.
