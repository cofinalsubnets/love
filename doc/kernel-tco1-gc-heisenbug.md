# the kernel tco=1 GC heisenbug

**Status:** open. The freestanding kernel test build is pinned to `ai_tco=0`
(`Makefile`, the `K_TEST` block). At `ai_tco=1` the corpus hangs partway. This
note records what the hang actually is, so it isn't re-derived from scratch.

**TL;DR.** It is *not* the eval loop, *not* a sibcall/stack problem, and *not*
clang-specific. It is a **heap-layout-sensitive GC corruption/hang in the major
collection (`gen_major`)** that `ai_tco=1`'s allocation pattern happens to
expose. The kernel does not load the glaze, so `tco=0` is correct today and this
has no functional payoff — it only matters as a prerequisite to running the
glaze *in* the kernel. Treat it as a focused GC-robustness project, not a
localized fix.

## why we looked

The glaze emits the threaded dispatch ABI and requires `ai_tco=1` (see
`doc/glaze-arm64.md` / the `glaze-arm64-tco` memory). The kernel runs `tco=0`,
so the glaze can't run there. Flipping the kernel to `tco=1` hangs the test
corpus — the question was whether that's a quick eval-loop fix.

## what it is NOT (ruled out)

- **Not the eval loop.** The non-hosted `tco=1` path in `ai_eval` (ai.c, the
  `#elif ai_tco` arm: `if (ai_ok(g)) g = g->ip->ap(g, g->ip, g->hp, g->sp);
  return g;`) is correct. Under `tco=1` the whole corpus runs in ONE ap-chain
  (the `reads` stream shell tail-calls per form), exactly like the hosted path's
  single call. A `while`-loop there would **infinite-loop**, because
  `ai_status_yield` == `ai_status_ok` under tco — the terminal yield never exits.

- **Not sibcall / C-stack overflow.** `tools/vmret.l` on the clang-freestanding
  `tco=1` kernel object reports **all 202 `lvm_*` functions ret-free** (fully
  tail-jumped). An earlier "37 don't sibcall" reading was a false alarm: a naive
  `objdump | grep ret` flags inter-function PADDING and error-path rets; vmret
  bounds each function by its symtab size and finds none.

- **Not clang-specific.** `make test_kernel KCC=gcc` at `tco=1` hangs the same
  way. Two independent compilers ⇒ a real bug, not a miscompilation.

- **Not pre-existing / not in the old collector.** `-DAI_NOGEN` forces the old
  single-pool collector (`gcg`) everywhere — the pre-generational behavior. Built
  at `-Dai_tco=1 -DAI_NOGEN`, the FULL corpus passes **2593, reliably (3/3)**. So
  the hang did NOT predate gen GC; it is specifically the **generational
  collector**. (This also gives a stopgap: a glaze-in-kernel build could run
  `tco=1 + AI_NOGEN` today, at the cost of gen GC's throughput, until the real
  bug is found.)

## what it IS (the evidence)

- **Heap-layout-sensitive.** Bisecting the corpus is unreliable because the baked
  `tests` string (kmain.c, `ktests.h`) is itself a heap allocation, so changing
  the file set shifts the layout that triggers the bug:
  - the subset `00-init + spec + apcap..box + zz-fin` hangs at **both** `tco=0`
    **and** `tco=1`;
  - the **full** corpus passes at `tco=0` but hangs at `tco=1` (~test 1194).
  So "box hangs in the subset" does NOT mean "box hangs in the full corpus" —
  same files, same order, different total string size ⇒ different outcome.

- **It's the major GC.** Instrumenting `gen_major` with phase markers
  (`serial_putc` at entry / after roots / after the cheney fixpoint / after the
  symbol rebuild / at exit) made the failing subset **pass reliably (3/3)**, with
  all 36 majors entering and exiting cleanly. So the hang is in/around the major
  collection, and any probe there changes whether it fires.

- **Timing/layout, not reordering.** A real external call (`serial_putc`, which
  clobbers caller-saved registers and does slow port I/O) **hides** it; a pure
  `__asm__ volatile("":::"memory")` barrier does **not**. More guest RAM defers
  it slightly (~+6 tests) but never fixes it — so it's not OOM, and not a simple
  cached-field reload.

Net: a latent corruption in the **generational** collector (confirmed by the
`AI_NOGEN` pass above) — a root the cheney pass misses, a rem-set entry dropped,
or a major-pool boundary off-by-one — that only manifests at certain heap
layouts. `tco=1` shifts the layout enough to hit it on the full corpus; certain
subsets hit it even at `tco=0`.

Because `gcg` (old collector) is clean and `gen` is not, the bug is in the
gen-only machinery: the rem set + `dirty` flag, `gen_scan_inplace` (the minor's
TERMINATOR-BOUNDED rescan of remembered major objects — see the warning in
`doc/gc-single-barrier.md` that a poke past a thread's terminator escapes it),
or `gen_major`'s two-from-space cheney. `tco=1` plausibly shifts the compiled
THREAD layout (the threaded-ABI cells) so a young pointer lands where the
terminator-bounded minor scan misses it. Start the audit there.

## the heisenbug trap

Every direct probe perturbs the layout/timing that triggers it:
- adding a print/marker in `gen_major` hides it;
- changing the corpus (to bisect) changes the layout;
- `-serial stdio` vs `-serial file:` and guest RAM all shift the trigger point.

So **do not bisect by editing the corpus or by printf**. Use the GC's existing
**differential oracle / reachability audit** (see `doc/gengc.md`,
`doc/gc-single-barrier.md`) to catch the corruption *deterministically* — e.g.
assert root/rem-set completeness on every collection and run the failing layout
until an assertion fires, rather than waiting for the downstream hang.

## reproduce (host, no interactive TTY needed)

```sh
# flip the kernel test build to tco=1
sed -i 's/-DK_TEST -Dai_tco=0/-DK_TEST -Dai_tco=1/' Makefile
make -s K_TEST=1 a=x86_64 out/free/ai-x86_64-test.iso
timeout 40 qemu-system-x86_64 -m 256M -M q35 \
  -serial file:/tmp/ser.txt -display none -no-reboot \
  -drive if=pflash,unit=0,format=raw,file=out/dl/edk2-ovmf/ovmf-code-x86_64.fd,readonly=on \
  -cdrom out/free/ai-x86_64-test.iso \
  -device isa-debug-exit,iobase=0xf4,iosize=0x04 </dev/null
grep -c "tests pass" /tmp/ser.txt    # 0 = hung (no "tests pass" in the serial)
git checkout Makefile                  # restore tco=0
```

Control (proves it's the generational collector): build the same at
`-Dai_tco=1 -DAI_NOGEN` (append `-DAI_NOGEN` to the `K_TEST` kcppflags line) and
it passes 2593 reliably.

`-serial file:` (not `stdio`) keeps the run independent of any controlling
terminal — unrelated to this bug, but see the `run`-nif TTY fix (`05c7296b`):
the capture nif now gives spawned children `/dev/null` stdin so an interactive
`make test_kernel` no longer SIGTTOU-stops qemu.

## recommended next step

Leave the kernel on `tco=0` (correct, 2593 green). Pick this up only when the
glaze is wanted in the kernel, as a GC-robustness task: stand up the
deterministic root/rem-set audit first, then reproduce the failing layout under
it. Likely adjacent to the in-flight single-barrier work (`doc/gc-single-barrier.md`).
