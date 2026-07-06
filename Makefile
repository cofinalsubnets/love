# Project root. Single Makefile: cross-cutting tasks (test, clean, install, ...)
# plus the host (POSIX CLI) and kernel (freestanding) builds inlined directly
# here; wasm keeps its own Makefile. Device ports (playdate, rp2040) live in
# the separate l-ports repo. Build output lands under out/
# (out/host, out/free, out/lib, out/dl). Shared vars live in common.mk.
R := .
include common.mk

CCACHE ?= $(shell command -v ccache 2>/dev/null)

# ai0 -- the bootstrap interpreter, PINNED to the canonical out/host tree (never
# $(hsuf)'d like $(ho)): it bakes the lcat headers every frontend shares. Defined
# UP HERE, not by the host-build block below, because test_ai0's prerequisite uses
# it -- and make expands prerequisites at PARSE time, so a later definition reads as
# empty, silently dropping test_ai0's dep on the binary. Serially that hides (the
# earlier test_host builds ai0 transitively via host -> lib_h -> ai0); under -j,
# test_ai0 then races ahead of the ai0 link ("out/host/ai0: No such file").
ai0 = out/host/ai0

# every ai run UNDER make boots deterministically: the test gate must exercise the freshly-built egg
# (not a stale baked image), and the bench controls glazed-vs-interp itself. So suppress the startup
# image auto-load for all recipes. The USER's binary (run outside make) still wakes its baked image.
export AI_NO_IMAGE := 1

.PHONY: all install uninstall clean distclean
.PHONY: host kernel wasm ai0
.PHONY: test test_host test_all test_tools test_ai0 test_wasm test_proof test_gen test_uugen test_uuwm uuwm test_gc test_hostnif test_glaze test_sat test_holo test_phos test_extract test_arm64
.PHONY: valg disasm flame cat cata catav perf repl gdb vmret bench nettest
# `make test` is the FAST gate: just the two egg self-tests (the host binary `ai`
# from-source under AI_NO_IMAGE, and ai0 -- c0 + the self-hosted ev, twice). It does
# NOT build the image (the --bake step), nor run coqc/lean/glaze/gc/tools, which
# are slow and/or need extra toolchains -- those live in `make test_all` (and the
# individual test_* targets). Serial by design: ~3s, no -j races, ctrl-C responsive.
JOBS  ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
osync := $(if $(filter output-sync,$(.FEATURES)),--output-sync=target,)
test_phases = test_host test_ai0
test:
	@$(MAKE) --no-print-directory $(test_phases)
# test_tools (vmret + cook + tele + xor) is in the fast `test` so an app breaks the
# gate the moment a rename lands -- the crew apps are part of the contract, not extras.
# test_kernel + test_wasm are in test_all but NOT the fast `test`: each needs an
# extra toolchain (qemu + OVMF, x86_64-only; emcc + node) and no-ops when that
# is absent. See their rules below.
test_all: test_host test_ai0 test_proof test_gen test_uugen test_uulean test_uuwm test_gc test_extract test_tools test_hostnif test_glaze test_sat test_holo test_phos test_utils nettest test_arm64 test_kernel test_wasm
# ai0 bakes prel+ev+repl + the whole test corpus (sed headers) and self-tests
# BOTH compilers in one run: eval prel (c0), run the corpus, bootstrap ev.l
# through c0, run the corpus again via the self-hosted ev. Built with -Dai_tco=0,
# so this also exercises the non-tail-threaded trampoline dispatch path.
# stdin is /dev/null: the corpus reads from the baked string, not stdin, but
# test/io.l exercises the real `in` port (a bare fgetc), which would otherwise
# block on a tty (the old `cat $t | ai0` fed the test stream in on stdin).
# Both gates require the zz-fin summary line, not just exit 0: a reader stop
# (e.g. a stray `)` mid-corpus) silently drops the rest of the stream and
# exits 0 without ever reaching zz-fin -- exit code alone green-lights a run
# that only executed a prefix of the corpus. ai0 must print TWO summaries
# (the corpus runs under both c0 and the self-hosted ev).
test_ai0: $(ai0)
	@echo TEST $(ai0)
	@$(ai0) </dev/null > out/host/.test_ai0.out; s=$$?; cat out/host/.test_ai0.out; \
	  [ $$s -eq 0 ] && [ `grep -c "tests pass" out/host/.test_ai0.out` -eq 2 ]
test_host: $m
	@echo TEST $m
	@cat $t | $m > out/host/.test_host.out; s=$$?; cat out/host/.test_host.out; \
	  [ $$s -eq 0 ] && grep -q "tests pass" out/host/.test_host.out
# Host-nif smoke tests: nifs defined in host/*.c link into `ai` but NOT ai0
# (which bakes the corpus), so they cannot live in test/*.l -- ai0 would read the
# names as missing and fail its self-test. Run them standalone against the built
# binary instead. Each script prints a "<name>: ok" sentinel and uses the
# test/00-init.l assert harness (which exits 1 on the first failure), so the gate
# checks BOTH exit 0 AND the sentinel -- a silent reader-stop exits 0 without it.
# Add a thread's smoke script to hostnif_tests (ain: boot/net.l, &c).
hostnif_tests = boot/pty.l boot/net.l boot/phos.l boot/phosui.l boot/baoedit.l boot/baotest.l boot/init.l boot/fs.l boot/sh.l boot/cb.l boot/berth.l boot/manifest.l boot/pier.l boot/font.l boot/haven.l boot/overlay.l
# haven's real-client smoke binary: libwayland-client + the generated
# xdg-shell glue -- deliberately NOT zero-dep, it exists to be the OTHER side
# of haven's wire. built only where wayland-scanner + libwayland live;
# boot/haven.l skips its smoke act when the binary is absent. pinned to the
# canonical out/host like ai0 (parse-time prereqs; it never links ai).
smoke = out/host/haven-smoke
xdgxml = $(shell pkg-config --variable=pkgdatadir wayland-protocols 2>/dev/null)/stable/xdg-shell/xdg-shell.xml
$(smoke): crew/haven/smoke.c
	@mkdir -p out/host
	@if command -v wayland-scanner >/dev/null 2>&1 && pkg-config --exists wayland-client 2>/dev/null && [ -f "$(xdgxml)" ]; then \
	  echo "CC $@"; \
	  wayland-scanner client-header "$(xdgxml)" out/host/xdg-shell-client-protocol.h; \
	  wayland-scanner private-code "$(xdgxml)" out/host/xdg-shell-protocol.c; \
	  $(CC) -O1 -Wall -Wextra -o $@ crew/haven/smoke.c out/host/xdg-shell-protocol.c -Iout/host `pkg-config --cflags --libs wayland-client`; \
	else echo "SKIP $@ (no libwayland here)"; fi
test_hostnif: host $(smoke)
	@for s in $(hostnif_tests); do echo "HOSTNIF $$s"; \
	  cat test/00-init.l $$s | $m > out/host/.test_hostnif.out 2>&1; r=$$?; \
	  cat out/host/.test_hostnif.out; \
	  { [ $$r -eq 0 ] && grep -q ': ok' out/host/.test_hostnif.out; } \
	    || { echo "FAIL $$s (exit $$r)"; exit 1; }; \
	done
# Native-codegen self-tests (the ai/glaze/ x86-64 jit): emit (the SSE emitter) +
# auto (ev's source-recognizer: counted loops, float grids, recursive arith
# groups) are exercised by test/glaze-x86.l (the asserts moved out of emit.l/
# auto.l so they no longer run at every glaze load/bake); it cats emit.l + auto.l
# ahead of itself, then runs each block through base-ev (the loader's global ev is
# now auto-ev, which mis-opfixes some pathological self-test forms). hook (ev.l's
# ala creation-hook) keeps its inline self-test, run with emit.l prepended. Each
# needs the built binary (the `nat` host nif) and prel's strict `assert` (SCARES
# on a false claim, terminal exit 1). x86-64 ONLY (real machine code); skipped
# elsewhere. Gate = exit 0 AND the sentinel (a reader-stop exits 0 without it).
.PHONY: test_glaze
ifeq ($a,x86_64)
test_glaze: host
	@echo "GLAZE test/glaze-x86.l (emit + auto)"; \
	  cat test/glaze-x86.l | $m > out/host/.test_glaze.out 2>&1; r=$$?; \
	  cat out/host/.test_glaze.out; \
	  { [ $$r -eq 0 ] && grep -q "test/glaze-x86:" out/host/.test_glaze.out; } \
	    || { echo "FAIL glaze x86 (exit $$r)"; exit 1; }; \
	  echo "GLAZE ai/glaze/hook.l"; \
	  cat ai/glaze/hook.l | $m > out/host/.test_glaze.out 2>&1; r=$$?; \
	  cat out/host/.test_glaze.out; \
	  { [ $$r -eq 0 ] && grep -q "ai/glaze/hook:" out/host/.test_glaze.out; } \
	    || { echo "FAIL glaze/hook (exit $$r)"; exit 1; }
else
test_glaze:
	@echo "test_glaze: skipped (host arch $a is not x86_64)"
endif
# crew/sat/ -- the CDCL SAT solver app. Portable ai (no glaze), so it runs on every arch.
# Gate = exit 0 AND the sentinel (a reader-stop or a strict-assert scare both miss it).
.PHONY: test_sat
test_sat: host
	@echo "SAT crew/sat/sat.l + crew/sat/dimacs.l + crew/sat/flat.l"; \
	  cat crew/sat/sat.l crew/sat/dimacs.l crew/sat/flat.l | $m > out/host/.test_sat.out 2>&1; r=$$?; \
	  cat out/host/.test_sat.out; \
	  { [ $$r -eq 0 ] && grep -q "sat: Stages 1-3 ok" out/host/.test_sat.out && grep -q "crew/sat/dimacs: ok" out/host/.test_sat.out && grep -q "crew/sat/flat: ok" out/host/.test_sat.out; } \
	    || { echo "FAIL sat (exit $$r)"; exit 1; }
# The DRAT lane's EXTERNAL check: flat.l's emitted refutations (fdrat0) verified by
# drat-trim, the SAT competition's independent checker (fetched + built into out/drat
# on first use; skips gracefully offline). The in-gate twin (fd-check, no external
# dependency) runs inside test_sat; this aims the third-party eye at php5-8 + a
# raw-RUP row. Not in test_all (network on first run); run after touching the emitter.
.PHONY: test_drat
test_drat: host
	@cd crew/sat && ./dratcheck.sh || { echo "FAIL drat"; exit 1; }
# The phos app's pure core (crew/phos/core.l): xmonad's StackSet -- the focus zipper, the
# workspace sheaf, the floating half -- with xmonad's QuickCheck laws + a seeded
# fuzz (crew/phos/law.l). Pure ai (no nif), so it self-tests portably; the X layers
# (wire.l/phos.l) need connectu and are proven against Xephyr, not here. Gate = the
# sentinel AND exit 0 (a reader-stop or strict-assert scare both miss it).
.PHONY: test_phos
test_phos: host
	@echo "PHOS crew/phos/core.l ... crew/phos/config.l + crew/phos/law.l (the whole app, host)"; \
	  cat test/00-init.l crew/phos/core.l crew/phos/layout.l crew/phos/wire.l crew/phos/ewmh.l crew/phos/manage.l crew/phos/keys.l crew/phos/config.l crew/phos/law.l | $m > out/host/.test_phos.out 2>&1; r=$$?; \
	  cat out/host/.test_phos.out; \
	  { [ $$r -eq 0 ] && grep -q "crew/phos/law: StackSet" out/host/.test_phos.out; } \
	    || { echo "FAIL phos (exit $$r)"; exit 1; }
# aiutils (crew/utils/): the myers + patience diff engines, the text/tool surface,
# the line tools (crew/utils/core.l: cat head tail wc sort uniq tee + the trivia),
# and `au`, the multi-call toolbox (busybox's trick -- one binary, the util picked
# off the command line or an argv[0] symlink; crew/utils/au.l is the dispatcher).
# The law file holds the engines to their projections, to an O(nm) LCS oracle
# (minimality), the u-floor to its GNU faces, and seeded fuzzes; the au smokes then
# drive the BUILT artifact: diff + the line tools byte-identical to GNU (LC_ALL=C
# for sort), the exit triple, argv[0] dispatch through a `diff` symlink, usage at 2,
# and (x86_64) `au as` assembling an exit(7) ELF that RUNS. Gate = the law sentinel
# AND exit 0 AND the smokes.
aufiles = crew/utils/text.l crew/utils/core.l crew/utils/fs.l crew/utils/re.l crew/utils/sed.l crew/utils/proc.l crew/utils/diff.l tools/ain.l crew/cook/cook.l crew/utils/asbook.l crew/holo/elf.l crew/utils/au.l
# (`ho` is defined further down, after this rule is READ -- target/prereq names
# expand at parse time, so these two lines spell out/host$(hsuf) themselves.)
out/host$(hsuf)/au: $(aufiles)
	@echo AI	$(abspath $@)
	@{ echo '#!/usr/bin/env -S ai'; cat $(aufiles); } > $@
	@chmod 755 $@
.PHONY: test_utils
test_utils: host out/host$(hsuf)/au
	@echo "UTILS crew/utils/{text,core,fs,re,sed,diff,law}.l"; \
	  cat test/00-init.l crew/utils/text.l crew/utils/core.l crew/utils/fs.l crew/utils/re.l crew/utils/sed.l crew/utils/proc.l crew/utils/diff.l crew/utils/law.l | $m > out/host/.test_utils.out 2>&1; r=$$?; \
	  cat out/host/.test_utils.out; \
	  { [ $$r -eq 0 ] && grep -q "crew/utils/law: myers" out/host/.test_utils.out; } \
	    || { echo "FAIL utils (exit $$r)"; exit 1; }
	@printf 'a\nb\nc\n' > $(ho)/.au1; printf 'a\nX\nc\n' > $(ho)/.au2; \
	  $m $(ho)/au diff $(ho)/.au1 $(ho)/.au1 > $(ho)/.au-same.out 2>&1; r=$$?; \
	  { [ $$r -eq 0 ] && [ ! -s $(ho)/.au-same.out ]; } || { echo "FAIL au diff same (exit $$r)"; exit 1; }; \
	  $m $(ho)/au diff $(ho)/.au1 $(ho)/.au2 > $(ho)/.au-diff.out 2>&1; r=$$?; \
	  [ $$r -eq 1 ] || { echo "FAIL au diff differ (exit $$r)"; exit 1; }; \
	  diff -u $(ho)/.au1 $(ho)/.au2 | tail -n +3 > $(ho)/.au-gnu.out; tail -n +3 $(ho)/.au-diff.out > $(ho)/.au-ours.out; \
	  cmp -s $(ho)/.au-gnu.out $(ho)/.au-ours.out || { echo "FAIL au diff vs GNU"; exit 1; }; \
	  ln -sf au $(ho)/diff; \
	  $m $(ho)/diff $(ho)/.au1 $(ho)/.au2 > $(ho)/.au-sym.out 2>&1; r=$$?; \
	  { [ $$r -eq 1 ] && cmp -s $(ho)/.au-diff.out $(ho)/.au-sym.out; } || { echo "FAIL au argv0 symlink (exit $$r)"; exit 1; }; \
	  $m $(ho)/au bogus > /dev/null 2>&1; r=$$?; \
	  [ $$r -eq 2 ] || { echo "FAIL au usage (exit $$r)"; exit 1; }; \
	  if [ "$$(uname -m)" = x86_64 ]; then \
	    printf '(li r0 60) (li r6 7) (sys)\n' > $(ho)/.au-as.l; \
	    $m $(ho)/au as x64 $(ho)/.au-as.l $(ho)/.au-as.elf > /dev/null 2>&1 || { echo "FAIL au as"; exit 1; }; \
	    chmod +x $(ho)/.au-as.elf; $(ho)/.au-as.elf; r=$$?; \
	    [ $$r -eq 7 ] || { echo "FAIL au as run (exit $$r)"; exit 1; }; \
	  fi; \
	  echo "au: diff (GNU-identical) + argv0 symlink + usage + as ok"
	@printf 'b\na\nc\nb\n' > $(ho)/.cu1; printf 'x y\nz\n' > $(ho)/.cu2; \
	  LC_ALL=C sort $(ho)/.cu1 > $(ho)/.cu-g; $m $(ho)/au sort $(ho)/.cu1 > $(ho)/.cu-o; \
	  cmp -s $(ho)/.cu-g $(ho)/.cu-o || { echo "FAIL au sort vs GNU"; exit 1; }; \
	  LC_ALL=C sort -u $(ho)/.cu1 > $(ho)/.cu-g; $m $(ho)/au sort -u $(ho)/.cu1 > $(ho)/.cu-o; \
	  cmp -s $(ho)/.cu-g $(ho)/.cu-o || { echo "FAIL au sort -u vs GNU"; exit 1; }; \
	  LC_ALL=C sort $(ho)/.cu1 | uniq -c > $(ho)/.cu-g; $m $(ho)/au sort $(ho)/.cu1 | $m $(ho)/au uniq -c > $(ho)/.cu-o; \
	  cmp -s $(ho)/.cu-g $(ho)/.cu-o || { echo "FAIL au uniq -c vs GNU"; exit 1; }; \
	  head -n 2 $(ho)/.cu1 $(ho)/.cu2 > $(ho)/.cu-g; $m $(ho)/au head -n 2 $(ho)/.cu1 $(ho)/.cu2 > $(ho)/.cu-o; \
	  cmp -s $(ho)/.cu-g $(ho)/.cu-o || { echo "FAIL au head vs GNU"; exit 1; }; \
	  tail -n 2 $(ho)/.cu1 $(ho)/.cu2 > $(ho)/.cu-g; $m $(ho)/au tail -n 2 $(ho)/.cu1 $(ho)/.cu2 > $(ho)/.cu-o; \
	  cmp -s $(ho)/.cu-g $(ho)/.cu-o || { echo "FAIL au tail vs GNU"; exit 1; }; \
	  wc $(ho)/.cu1 $(ho)/.cu2 > $(ho)/.cu-g; $m $(ho)/au wc $(ho)/.cu1 $(ho)/.cu2 > $(ho)/.cu-o; \
	  cmp -s $(ho)/.cu-g $(ho)/.cu-o || { echo "FAIL au wc vs GNU"; exit 1; }; \
	  wc -l < $(ho)/.cu1 > $(ho)/.cu-g; $m $(ho)/au wc -l < $(ho)/.cu1 > $(ho)/.cu-o; \
	  cmp -s $(ho)/.cu-g $(ho)/.cu-o || { echo "FAIL au wc -l stdin vs GNU"; exit 1; }; \
	  cat $(ho)/.cu1 $(ho)/.cu2 > $(ho)/.cu-g; $m $(ho)/au cat $(ho)/.cu1 $(ho)/.cu2 > $(ho)/.cu-o; \
	  cmp -s $(ho)/.cu-g $(ho)/.cu-o || { echo "FAIL au cat vs GNU"; exit 1; }; \
	  seq 5 > $(ho)/.cu-g; $m $(ho)/au seq 5 > $(ho)/.cu-o; \
	  cmp -s $(ho)/.cu-g $(ho)/.cu-o || { echo "FAIL au seq vs GNU"; exit 1; }; \
	  echo hi there > $(ho)/.cu-g; $m $(ho)/au echo hi there > $(ho)/.cu-o; \
	  cmp -s $(ho)/.cu-g $(ho)/.cu-o || { echo "FAIL au echo vs GNU"; exit 1; }; \
	  basename /a/b.txt .txt > $(ho)/.cu-g; $m $(ho)/au basename /a/b.txt .txt > $(ho)/.cu-o; \
	  cmp -s $(ho)/.cu-g $(ho)/.cu-o || { echo "FAIL au basename vs GNU"; exit 1; }; \
	  printf 'q\nq\nr\n' | tee $(ho)/.cu-g2 > $(ho)/.cu-g; printf 'q\nq\nr\n' | $m $(ho)/au tee $(ho)/.cu-o2 > $(ho)/.cu-o; \
	  { cmp -s $(ho)/.cu-g $(ho)/.cu-o && cmp -s $(ho)/.cu-g2 $(ho)/.cu-o2; } || { echo "FAIL au tee vs GNU"; exit 1; }; \
	  echo "au: line tools (sort/uniq/head/tail/wc/cat/seq/echo/basename/tee GNU-identical) ok"
	@printf 'a:b:c\nnodelim\nx:y\n' > $(ho)/.fu1; \
	  cut -d: -f1,3 $(ho)/.fu1 > $(ho)/.fu-g; $m $(ho)/au cut -d: -f1,3 $(ho)/.fu1 > $(ho)/.fu-o; \
	  cmp -s $(ho)/.fu-g $(ho)/.fu-o || { echo "FAIL au cut -f vs GNU"; exit 1; }; \
	  cut -d: -f1,3 -s $(ho)/.fu1 > $(ho)/.fu-g; $m $(ho)/au cut -d: -f1,3 -s $(ho)/.fu1 > $(ho)/.fu-o; \
	  cmp -s $(ho)/.fu-g $(ho)/.fu-o || { echo "FAIL au cut -s vs GNU"; exit 1; }; \
	  cut -d: -f2- $(ho)/.fu1 > $(ho)/.fu-g; $m $(ho)/au cut -d: -f2- $(ho)/.fu1 > $(ho)/.fu-o; \
	  cmp -s $(ho)/.fu-g $(ho)/.fu-o || { echo "FAIL au cut -f2- vs GNU"; exit 1; }; \
	  printf 'hello\nhi\n' | cut -c2-4 > $(ho)/.fu-g; printf 'hello\nhi\n' | $m $(ho)/au cut -c2-4 > $(ho)/.fu-o; \
	  cmp -s $(ho)/.fu-g $(ho)/.fu-o || { echo "FAIL au cut -c vs GNU"; exit 1; }; \
	  printf 'hi there\n' | tr a-z A-Z > $(ho)/.fu-g; printf 'hi there\n' | $m $(ho)/au tr a-z A-Z > $(ho)/.fu-o; \
	  cmp -s $(ho)/.fu-g $(ho)/.fu-o || { echo "FAIL au tr vs GNU"; exit 1; }; \
	  printf 'abcd\n' | tr abcd xy > $(ho)/.fu-g; printf 'abcd\n' | $m $(ho)/au tr abcd xy > $(ho)/.fu-o; \
	  cmp -s $(ho)/.fu-g $(ho)/.fu-o || { echo "FAIL au tr pad vs GNU"; exit 1; }; \
	  printf 'hello world\n' | tr -d aeiou > $(ho)/.fu-g; printf 'hello world\n' | $m $(ho)/au tr -d aeiou > $(ho)/.fu-o; \
	  cmp -s $(ho)/.fu-g $(ho)/.fu-o || { echo "FAIL au tr -d vs GNU"; exit 1; }; \
	  printf 'aa  bb   cc\n' | tr -s ' ' > $(ho)/.fu-g; printf 'aa  bb   cc\n' | $m $(ho)/au tr -s ' ' > $(ho)/.fu-o; \
	  cmp -s $(ho)/.fu-g $(ho)/.fu-o || { echo "FAIL au tr -s vs GNU"; exit 1; }; \
	  printf 'a\n\nb\n' | nl > $(ho)/.fu-g; printf 'a\n\nb\n' | $m $(ho)/au nl > $(ho)/.fu-o; \
	  cmp -s $(ho)/.fu-g $(ho)/.fu-o || { echo "FAIL au nl vs GNU"; exit 1; }; \
	  printf 'abc\nde\n' | rev > $(ho)/.fu-g; printf 'abc\nde\n' | $m $(ho)/au rev > $(ho)/.fu-o; \
	  cmp -s $(ho)/.fu-g $(ho)/.fu-o || { echo "FAIL au rev vs GNU"; exit 1; }; \
	  echo "au: field tools (cut/tr/nl/rev GNU-identical) ok"
	@P=$(ho)/.fsplay; rm -rf $$P; mkdir $$P; \
	  $m $(ho)/au mkdir -p $$P/a/b/c && [ -d $$P/a/b/c ] || { echo "FAIL au mkdir -p"; exit 1; }; \
	  printf 'hi there\n' > $$P/f1; \
	  $m $(ho)/au cp $$P/f1 $$P/f2 && cmp -s $$P/f1 $$P/f2 || { echo "FAIL au cp"; exit 1; }; \
	  $m $(ho)/au cp $$P/f1 $$P/a && cmp -s $$P/f1 $$P/a/f1 || { echo "FAIL au cp into dir"; exit 1; }; \
	  $m $(ho)/au mv $$P/f2 $$P/f3 && [ ! -e $$P/f2 ] && cmp -s $$P/f1 $$P/f3 || { echo "FAIL au mv"; exit 1; }; \
	  $m $(ho)/au ln -s f1 $$P/l1 && [ "$$(readlink $$P/l1)" = f1 ] || { echo "FAIL au ln -s"; exit 1; }; \
	  $m $(ho)/au ln $$P/f1 $$P/h1 && [ $$P/h1 -ef $$P/f1 ] || { echo "FAIL au ln"; exit 1; }; \
	  $m $(ho)/au touch $$P/new $$P/.hidden && [ -f $$P/new ] && [ -f $$P/.hidden ] || { echo "FAIL au touch"; exit 1; }; \
	  $m $(ho)/au chmod 600 $$P/f1 && [ "$$(stat -c %a $$P/f1)" = 600 ] || { echo "FAIL au chmod"; exit 1; }; \
	  LC_ALL=C ls -1 $$P > $(ho)/.fs-g; $m $(ho)/au ls $$P > $(ho)/.fs-o; \
	  cmp -s $(ho)/.fs-g $(ho)/.fs-o || { echo "FAIL au ls vs GNU"; exit 1; }; \
	  LC_ALL=C ls -A -1 $$P > $(ho)/.fs-g; $m $(ho)/au ls -a $$P > $(ho)/.fs-o; \
	  cmp -s $(ho)/.fs-g $(ho)/.fs-o || { echo "FAIL au ls -a vs GNU -A"; exit 1; }; \
	  [ "$$($m $(ho)/au pwd)" = "$$(pwd)" ] || { echo "FAIL au pwd"; exit 1; }; \
	  $m $(ho)/au rm $$P/f3 && [ ! -e $$P/f3 ] || { echo "FAIL au rm"; exit 1; }; \
	  $m $(ho)/au rm -r $$P/a && [ ! -e $$P/a ] || { echo "FAIL au rm -r"; exit 1; }; \
	  $m $(ho)/au mkdir $$P/empty && $m $(ho)/au rmdir $$P/empty && [ ! -e $$P/empty ] || { echo "FAIL au rmdir"; exit 1; }; \
	  $m $(ho)/au rm $$P/nope > /dev/null 2>&1; r=$$?; [ $$r -eq 1 ] || { echo "FAIL au rm miss exit"; exit 1; }; \
	  $m $(ho)/au rm -f $$P/nope > /dev/null 2>&1; r=$$?; [ $$r -eq 0 ] || { echo "FAIL au rm -f quiet"; exit 1; }; \
	  echo "au: fs tools (mkdir/cp/mv/ln/touch/chmod/ls/pwd/rm/rmdir) ok"
	@printf 'abc\nxbz\nzzz\n+q\n*r\n' > $(ho)/.gr1; printf 'nope\nbc here\n' > $(ho)/.gr2; \
	  grep b $(ho)/.gr1 > $(ho)/.gr-g; $m $(ho)/au grep b $(ho)/.gr1 > $(ho)/.gr-o; \
	  cmp -s $(ho)/.gr-g $(ho)/.gr-o || { echo "FAIL au grep vs GNU"; exit 1; }; \
	  grep -n b $(ho)/.gr1 $(ho)/.gr2 > $(ho)/.gr-g; $m $(ho)/au grep -n b $(ho)/.gr1 $(ho)/.gr2 > $(ho)/.gr-o; \
	  cmp -s $(ho)/.gr-g $(ho)/.gr-o || { echo "FAIL au grep -n multi vs GNU"; exit 1; }; \
	  grep -c b $(ho)/.gr1 $(ho)/.gr2 > $(ho)/.gr-g; $m $(ho)/au grep -c b $(ho)/.gr1 $(ho)/.gr2 > $(ho)/.gr-o; \
	  cmp -s $(ho)/.gr-g $(ho)/.gr-o || { echo "FAIL au grep -c vs GNU"; exit 1; }; \
	  grep -v b $(ho)/.gr1 > $(ho)/.gr-g; $m $(ho)/au grep -v b $(ho)/.gr1 > $(ho)/.gr-o; \
	  cmp -s $(ho)/.gr-g $(ho)/.gr-o || { echo "FAIL au grep -v vs GNU"; exit 1; }; \
	  grep -l b $(ho)/.gr1 $(ho)/.gr2 > $(ho)/.gr-g; $m $(ho)/au grep -l b $(ho)/.gr1 $(ho)/.gr2 > $(ho)/.gr-o; \
	  cmp -s $(ho)/.gr-g $(ho)/.gr-o || { echo "FAIL au grep -l vs GNU"; exit 1; }; \
	  printf 'q\n' | grep -l q > $(ho)/.gr-g; printf 'q\n' | $m $(ho)/au grep -l q > $(ho)/.gr-o; \
	  cmp -s $(ho)/.gr-g $(ho)/.gr-o || { echo "FAIL au grep -l stdin vs GNU"; exit 1; }; \
	  grep '' $(ho)/.gr1 > $(ho)/.gr-g; $m $(ho)/au grep '' $(ho)/.gr1 > $(ho)/.gr-o; \
	  cmp -s $(ho)/.gr-g $(ho)/.gr-o || { echo "FAIL au grep empty pattern vs GNU"; exit 1; }; \
	  for p in 'ab*c' '^x' 'z$$' '[abx]b' '[^a]b' 'b\+' 'xb\?z' '\(zz\)*z' '.z' '^\+q' '^*r' 'x[b-z]z'; do \
	    grep -c "$$p" $(ho)/.gr1 > $(ho)/.gr-g 2>/dev/null; a=$$?; \
	    $m $(ho)/au grep -c "$$p" $(ho)/.gr1 > $(ho)/.gr-o; b=$$?; \
	    { cmp -s $(ho)/.gr-g $(ho)/.gr-o && [ $$a -eq $$b ]; } \
	      || { echo "FAIL au grep BRE '$$p' vs GNU"; exit 1; }; \
	  done; \
	  $m $(ho)/au grep b $(ho)/.gr1 > /dev/null; r=$$?; [ $$r -eq 0 ] || { echo "FAIL au grep hit exit"; exit 1; }; \
	  $m $(ho)/au grep qqq $(ho)/.gr1 > /dev/null; r=$$?; [ $$r -eq 1 ] || { echo "FAIL au grep miss exit"; exit 1; }; \
	  grep b $(ho)/.gr-nope 2> $(ho)/.gr-g; a=$$?; $m $(ho)/au grep b $(ho)/.gr-nope 2> $(ho)/.gr-o; b=$$?; \
	  { cmp -s $(ho)/.gr-g $(ho)/.gr-o && [ $$a -eq 2 ] && [ $$b -eq 2 ]; } || { echo "FAIL au grep missing file vs GNU"; exit 1; }; \
	  $m $(ho)/au grep b $(ho)/.gr1 $(ho)/.gr-nope > /dev/null 2>&1; r=$$?; \
	  [ $$r -eq 2 ] || { echo "FAIL au grep err beats match exit"; exit 1; }; \
	  echo "au: grep (plain/-n/-c/-v/-l + BRE battery GNU-identical, the exit triple) ok"
	@printf 'abc\nxbz\nzzz\nq4\nw5\n' > $(ho)/.sd1; \
	  for sc in 's/b/X/' 's/z/Q/g' '2d' '/x/,/q/d' '$$d' '2q' 's/x*/-/g' 's/\(b*\)z/[\1]/' 's/b/[&]/' 's|z|_|g' 's/a/1/; s/b/2/' 's/q\(.\)/<\1>/'; do \
	    sed "$$sc" $(ho)/.sd1 > $(ho)/.sd-g; a=$$?; \
	    $m $(ho)/au sed "$$sc" $(ho)/.sd1 > $(ho)/.sd-o; b=$$?; \
	    { cmp -s $(ho)/.sd-g $(ho)/.sd-o && [ $$a -eq $$b ]; } \
	      || { echo "FAIL au sed '$$sc' vs GNU"; exit 1; }; \
	  done; \
	  for sc in '2,4p' '/z/p' 's/b/X/p' '/x/,/q/p'; do \
	    sed -n "$$sc" $(ho)/.sd1 > $(ho)/.sd-g; \
	    $m $(ho)/au sed -n "$$sc" $(ho)/.sd1 > $(ho)/.sd-o; \
	    cmp -s $(ho)/.sd-g $(ho)/.sd-o || { echo "FAIL au sed -n '$$sc' vs GNU"; exit 1; }; \
	  done; \
	  printf 'ab\n' | sed 's/a/1/' > $(ho)/.sd-g; printf 'ab\n' | $m $(ho)/au sed 's/a/1/' > $(ho)/.sd-o; \
	  cmp -s $(ho)/.sd-g $(ho)/.sd-o || { echo "FAIL au sed stdin vs GNU"; exit 1; }; \
	  printf 'a\n' | sed 's/a' > /dev/null 2>&1; a=$$?; printf 'a\n' | $m $(ho)/au sed 's/a' > /dev/null 2>&1; b=$$?; \
	  { [ $$a -eq 1 ] && [ $$b -eq 1 ]; } || { echo "FAIL au sed bad-script exit (gnu $$a ours $$b)"; exit 1; }; \
	  sed p $(ho)/.sd-nope $(ho)/.sd1 > $(ho)/.sd-g 2>&1; a=$$?; \
	  $m $(ho)/au sed p $(ho)/.sd-nope $(ho)/.sd1 > $(ho)/.sd-o 2>&1; b=$$?; \
	  { cmp -s $(ho)/.sd-g $(ho)/.sd-o && [ $$a -eq 2 ] && [ $$b -eq 2 ]; } \
	    || { echo "FAIL au sed missing file vs GNU"; exit 1; }; \
	  echo "au: sed (s///gp + d/p/q + number/\$$/regex/range addresses GNU-identical, exits 1/2) ok"
	@printf 'a b\nc\n' | xargs > $(ho)/.pc-g; printf 'a b\nc\n' | $m $(ho)/au xargs > $(ho)/.pc-o; \
	  cmp -s $(ho)/.pc-g $(ho)/.pc-o || { echo "FAIL au xargs vs GNU"; exit 1; }; \
	  printf '1\n2\n3\n4\n5\n' | xargs -n 2 echo > $(ho)/.pc-g; printf '1\n2\n3\n4\n5\n' | $m $(ho)/au xargs -n 2 echo > $(ho)/.pc-o; \
	  cmp -s $(ho)/.pc-g $(ho)/.pc-o || { echo "FAIL au xargs -n 2 vs GNU"; exit 1; }; \
	  printf '' | xargs echo > $(ho)/.pc-g; printf '' | $m $(ho)/au xargs echo > $(ho)/.pc-o; \
	  cmp -s $(ho)/.pc-g $(ho)/.pc-o || { echo "FAIL au xargs empty vs GNU"; exit 1; }; \
	  printf 'x\n' | $m $(ho)/au xargs false; r=$$?; [ $$r -eq 123 ] || { echo "FAIL au xargs fail exit (rc $$r)"; exit 1; }; \
	  printf 'x\n' | $m $(ho)/au xargs /no/such/cmd 2>/dev/null; r=$$?; [ $$r -eq 127 ] || { echo "FAIL au xargs 127 (rc $$r)"; exit 1; }; \
	  env AUP=44 sh -c 'printf %s "$$AUP"' > $(ho)/.pc-g; $m $(ho)/au env AUP=44 sh -c 'printf %s "$$AUP"' > $(ho)/.pc-o; \
	  cmp -s $(ho)/.pc-g $(ho)/.pc-o || { echo "FAIL au env assign vs GNU"; exit 1; }; \
	  env | grep -v '^_=' | LC_ALL=C sort > $(ho)/.pc-g; $m $(ho)/au env | grep -v '^_=' | LC_ALL=C sort > $(ho)/.pc-o; \
	  cmp -s $(ho)/.pc-g $(ho)/.pc-o || { echo "FAIL au env print vs GNU"; exit 1; }; \
	  $m $(ho)/au env sh -c 'exit 3'; r=$$?; [ $$r -eq 3 ] || { echo "FAIL au env child exit (rc $$r)"; exit 1; }; \
	  $m $(ho)/au sleep 0.1 || { echo "FAIL au sleep"; exit 1; }; \
	  $m $(ho)/au sleep xx 2>/dev/null; r=$$?; [ $$r -eq 1 ] || { echo "FAIL au sleep bad exit (rc $$r)"; exit 1; }; \
	  sleep 3 & sp=$$!; $m $(ho)/au kill -9 $$sp || { echo "FAIL au kill send"; exit 1; }; \
	  wait $$sp; r=$$?; [ $$r -eq 137 ] || { echo "FAIL au kill effect (rc $$r)"; exit 1; }; \
	  $m $(ho)/au kill -0 999999 2>/dev/null; r=$$?; [ $$r -eq 1 ] || { echo "FAIL au kill dead pid (rc $$r)"; exit 1; }; \
	  echo "au: process tools (env/sleep/kill/xargs -- GNU-identical output, the exit faces) ok"
# The neutral assembler (crew/holo/) + its x86-64 backend: every encoder golden is
# objdump-checked (crew/holo/holotest.l). A host-only app (like sat) -- it rides the
# core's lists/tablets, adds no nif, and is NOT baked into ai0. The gate greps
# the "N passed, 0 failed" sentinel AND exit 0 (a silent reader-stop exits 0).
.PHONY: test_holo
test_holo: host
	@echo "HOLO crew/holo/holotest.l"; \
	  cat crew/holo/holo.l crew/holo/x64.l crew/holo/arm64.l crew/holo/text.l crew/holo/elf.l crew/holo/holotest.l | $m > out/host/.test_holo.out 2>&1; r=$$?; \
	  cat out/host/.test_holo.out; \
	  { [ $$r -eq 0 ] && grep -q ", 0 failed" out/host/.test_holo.out; } \
	    || { echo "FAIL holo (exit $$r)"; exit 1; }
# ain's two-process loopback gate: a server and a client over real TCP on
# 127.0.0.1, full-duplex, asserting each side received what the other sent (the
# socket nifs in host/net.c + the pump loops in tools/ain.l). In `test_all`
# (the thorough gate) but NOT the fast `test` -- it needs two live processes and
# a free loopback port. It is the ONLY net gate that drives the real
# `ai tools/ain.l` cli path: the in-process `boot/net.l` smoke (in
# test_hostnif) pipes straight into the binary, so it covers the nifs portably
# but can't catch an invocation regression (e.g. a stale -l preload). Override
# the port with `make nettest PORT=NNNN`.
PORT ?= 7390
nettest: host
	@echo NETTEST $m "(127.0.0.1:$(PORT))"
	@sh $R/test/net/loopback.sh $m $(PORT)
# Validate the l tool rewrites against their frozen Python references in
# tools/py/ (gen_data / vmret). See tools/Makefile + tools/py/README.md.
test_tools: host
	@$(MAKE) -C tools
# Machine-check proof/rocq/spec.v -- ai's headline laws (the numeral / function /
# absence core of test/spec.l) as Rocq theorems, axiom-free (every proof
# "Closed under the global context"). This is what upgrades the executable
# spec from DEMONSTRATED on every target to PROVED in a consistent metatheory
# -- the README's "verified specification ... up to explosion of world" made
# load-bearing (the caveat is uu.l's type-in-type detonation; this file runs
# universe-checked, so it does not explode). coqc writes artifacts next to the
# source; clean them on success. No-op when coqc is missing, so the gate stays
# green without a Rocq install (like test_kernel / test_wasm).
COQC ?= $(shell command -v coqc 2>/dev/null)
LEAN ?= $(shell command -v lean 2>/dev/null)
ifeq ($(COQC),)
test_proof:
	@echo "test_proof: skipped (needs rocq/coqc)"
else
test_proof:
	@echo TEST proof/rocq/spec.v "(coqc)"
	@$(COQC) -q proof/rocq/spec.v
	@rm -f proof/rocq/spec.vo proof/rocq/spec.vok proof/rocq/spec.vos proof/rocq/spec.glob proof/rocq/.spec.aux
endif
# Machine-check proof/rocq/gc.v -- the generational MINOR is SOUND: under a complete
# write barrier (rem_complete) the nursery scan reaches every live young object,
# so no live young is lost (barrier_sound) -- the Coq proof of doc/proto/gengc.l's
# load-bearing self-check (3b, the barrier is necessary). Axiom-free like spec.v;
# the C stays connected by the differential oracle + gen_audit. No-op without coqc.
ifeq ($(COQC),)
test_gc:
	@echo "test_gc: skipped (needs rocq/coqc)"
else
test_gc:
	@echo TEST proof/rocq/gc.v "(coqc)"
	@$(COQC) -q proof/rocq/gc.v
	@rm -f proof/rocq/gc.vo proof/rocq/gc.vok proof/rocq/gc.vos proof/rocq/gc.glob proof/rocq/.gc.aux
endif
# The .l -> .v pipeline: tools/spec2coq.l (run on the host binary $m) reads
# test/spec.l and EMITS proof/rocq/gen.v -- the spec generating Coq theorems for its
# own pure-numeral corpus facts, each closed by computation (over Z, since nat
# is unary and 3^27 would blow up vm_compute). coqc then checks them. Drift-proof:
# the asserts and their proofs cannot diverge -- regenerated every run from .l.
# Needs the host binary AND coqc; no-ops without coqc, like test_proof.
ifeq ($(COQC),)
test_gen:
	@echo "test_gen: skipped (needs rocq/coqc)"
else
test_gen: host
	@echo AI	proof/rocq/gen.v "(tools/spec2coq.l on $m)"
	@$m tools/spec2coq.l > proof/rocq/gen.v
	@echo TEST proof/rocq/gen.v "(coqc, against spec.v's shared model)"
	@cd proof/rocq && $(COQC) -R . "" spec.v >/dev/null && $(COQC) -R . "" gen.v
	@rm -f proof/rocq/spec.vo proof/rocq/spec.vok proof/rocq/spec.vos proof/rocq/spec.glob proof/rocq/.spec.aux \
	  proof/rocq/gen.vo proof/rocq/gen.vok proof/rocq/gen.vos proof/rocq/gen.glob proof/rocq/.gen.aux
endif
# The PROOF half of the .l -> .v pipeline (cf. test_gen, which exports concrete
# ASSERTS): tools/uu2coq.l loads uu's kernel (test/uu.l), has it TYPE-CHECK a proof
# term against its theorem, and EMITS proof/rocq/uugen.v -- the same term in Gallina, which
# coqc re-checks independently. So a LAW (forall x, x^0 = 1 -- spec.v's const_one) is
# proved in ai's own kernel and certified by Rocq, axiom-free. Drift-proof like gen.v:
# regenerated every run, so the internal proof and the exported one cannot diverge.
# The skeleton of the internal-prover bridge. Needs the host binary AND coqc.
ifeq ($(COQC),)
test_uugen:
	@echo "test_uugen: skipped (needs rocq/coqc)"
else
test_uugen: host
	@echo AI	proof/rocq/uugen.v "(tools/uu2coq.l on $m)"
	@$m tools/uu2coq.l > proof/rocq/uugen.v
	@echo TEST proof/rocq/uugen.v "(coqc)"
	@$(COQC) -q proof/rocq/uugen.v
	@rm -f proof/rocq/uugen.vo proof/rocq/uugen.vok proof/rocq/uugen.vos proof/rocq/uugen.glob proof/rocq/.uugen.aux
endif

# The LEAN leg of the proof bridge (cf. test_uugen, the Rocq leg): tools/uu2lean.l emits
# the SAME uu corpus to Lean 4, which re-checks it -- a SECOND independent kernel, so each
# law is agreed by two unrelated implementations (the de Bruijn criterion, diversified).
# Drift-proof: regenerated every run. Needs the host binary AND lean.
ifeq ($(LEAN),)
test_uulean:
	@echo "test_uulean: skipped (needs lean)"
else
test_uulean: host
	@mkdir -p lean
	@echo AI	proof/lean/uugen.lean "(tools/uu2lean.l on $m)"
	@$m tools/uu2lean.l > proof/lean/uugen.lean
	@echo TEST proof/lean/uugen.lean "(lean)"
	@$(LEAN) proof/lean/uugen.lean > out/host/.uulean.out 2>&1; r=$$?; \
	  if [ $$r -ne 0 ] || grep -q sorryAx out/host/.uulean.out; then cat out/host/.uulean.out; exit 1; fi
endif

# test_extract: the differential oracle with a ROCQ-EXTRACTED reference. coqc
# extracts proof/rocq/extract.v (the n-ary/CBV/weak/saturating normalizer built on
# spec.v's PROVEN subst/shift) to OCaml; proof/rocq/oracle_drive.ml generates random
# closed affine terms, normalizes each with the extracted `nf`, and emits an ai
# program that checks ev EXTENSIONALLY agrees. So the reference the fuzzer runs
# IS the proven definitions (up to the standard nat->int mapping) -- machine-
# checked end to end. The hand-transcribed twin (test/oracle.l) stays in the
# fast `make test`; this heavier, higher-assurance variant needs coqc + ocamlopt,
# so it lives in test_all and no-ops when either tool is absent (like test_proof).
OCAMLOPT ?= $(shell command -v ocamlopt 2>/dev/null)
ifeq ($(and $(COQC),$(OCAMLOPT)),)
test_extract:
	@echo "test_extract: skipped (needs coqc + ocamlopt)"
else
test_extract: host
	@echo TEST proof/rocq/extract.v "(coqc extraction -> ocaml ref vs ev)"
	@cd proof/rocq && $(COQC) -R . "" spec.v >/dev/null && $(COQC) -R . "" extract.v >/dev/null \
	  && rm -f normalizer.mli && $(OCAMLOPT) -w -a normalizer.ml oracle_drive.ml -o oracle_drive
	@proof/rocq/oracle_drive 2000 6 1 > out/.extract_oracle.l
	@$m out/.extract_oracle.l | grep -q "2000 / 2000 PASS" \
	  || { echo "EXTRACT ORACLE FAILED:"; $m out/.extract_oracle.l; exit 1; }
	@$m out/.extract_oracle.l
	@rm -f proof/rocq/spec.vo proof/rocq/spec.vok proof/rocq/spec.vos proof/rocq/spec.glob proof/rocq/.spec.aux \
	  proof/rocq/extract.vo proof/rocq/extract.vok proof/rocq/extract.vos proof/rocq/extract.glob proof/rocq/.extract.aux \
	  proof/rocq/normalizer.ml proof/rocq/normalizer.mli proof/rocq/oracle_drive proof/rocq/*.cmi proof/rocq/*.cmx proof/rocq/*.o \
	  out/.extract_oracle.l
endif
all: host kernel wasm

# NB: there is NO git pre-commit hook -- committed artifacts (wasm/ai.js, bench/
# bench.html) are rebuilt MANUALLY (`make wasm`, `make -C bench html`) and staged
# by hand. An auto-rebuild hook re-ran the benchmarks on every commit (minutes);
# it was removed deliberately. Rebuild before committing artifact-affecting code.

# Static lisp headers: each ai/*.l is serialized to a C string literal in
# out/lib/*.h by tools/lcat.l (run on the bootstrap interpreter ai0). Frontends
# #include these and assemble the bootstrap with G_EGG_PRE/POST (ai.h).
# Drop a .l into ai/ and it is picked up automatically -- no rule to edit.
lib_h = $(patsubst ai/%.l,out/lib/%.h,$(wildcard ai/*.l))
# the crew/holo/ assembler baked into BOTH runtimes as a core language service: the
# neutral core + BOTH backends. They are pure ai (produce machine-code bytes as
# DATA, never execute them), so every backend is arch-neutral and rides along on
# every host -- only the glaze, which EXECUTES the bytes, is arch-bound (and it is
# cat-loaded + x86-gated separately, never baked). asm_h = lcat headers (host ai);
# asm0_h = sed-wrapped raw source (ai0, the bootstrap -- can't lcat its own sources).
holo_h = out/lib/holo.h  out/lib/x64.h  out/lib/arm64.h  out/lib/export.h
asm0_h = out/lib/holo0.h out/lib/x640.h out/lib/arm640.h out/lib/export0.h
# the glaze (native JIT, ai/glaze/{emit,auto}.l): baked to raw-text headers (sed_lit,
# like asm0 -- no lcat reader round-trip). Evaled ONLY before a --bake (x86-gated
# in main.c), so a normal boot never pays the ~810 ms; the baked snapshot then carries
# an always-on JIT at zero startup (Phase 4, doc/snapshot.md). Their self-test asserts
# native-compile transient closures -- the bake's gen_major drops them before serializing.
glaze_h = out/lib/emit.h out/lib/auto.h out/lib/gexport.h
# ai0's bootstrap headers: sed-wrapped raw source (a text->C-literal needing no
# interpreter -- the l reader strips the ; comments at read time), since ai0
# can't lcat the very sources it is assembled from (chicken/egg). cli.l doubles as
# ai0's CLI arg handler; prel/ev/egg/repl + the whole concatenated test corpus
# are baked in so ai0 self-tests both compilers in one run (see main.c). The final
# l uses the canonicalized lcat headers from the rule below instead.
sed_lit = sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/^/"/' -e 's/$$/\\n"/'
gl0_h = out/lib/cli0.h out/lib/egg0.h out/lib/prel0.h out/lib/ev0.h out/lib/bao0.h out/lib/tests0.h $(asm0_h)
.PHONY: lib
lib: $(lib_h) $(gl0_h)
# lcat a .l source into its C-string header, ATOMICALLY: generate to a temp, require it
# non-empty, then mv into place. A bare `> $@` truncates first, so a broken ai0 (or any
# lcat failure) would leave a 0-byte header that make then treats as up-to-date -- which
# SILENTLY drops a baked service (e.g. an empty holo.h => `assemble` unbound => the glaze's
# map lane emits nothing => a corrupt native => crash/hang). Fail loudly instead.
lcat_h = @mkdir -p out/lib; echo AI	$@; \
  $(ai0) -l ai/prel.l tools/lcat.l $< > $@.tmp && test -s $@.tmp && mv -f $@.tmp $@ \
    || { rm -f $@.tmp; echo "FAIL: $@ empty (ai0 lcat failed -- broken bootstrap?)"; exit 1; }
$(lib_h): out/lib/%.h: ai/%.l tools/lcat.l   # + $(ai0), stated below where it is in scope
	$(lcat_h)
# the crew/holo/ assembler (crew/holo/holo.l + crew/holo/x64.l) rides the SAME lcat pipeline into the
# post-egg layer -- a core language service (the glaze is its client). Explicit rules
# (their sources live in crew/holo/, not ai/, so the pattern rule above misses them).
out/lib/holo.h: crew/holo/holo.l tools/lcat.l
	$(lcat_h)
out/lib/x64.h: crew/holo/x64.l tools/lcat.l
	$(lcat_h)
out/lib/arm64.h: crew/holo/arm64.l tools/lcat.l
	$(lcat_h)
out/lib/export.h: crew/holo/export.l tools/lcat.l
	$(lcat_h)
# uu's NbE kernel bakes post.l-style so an overlay can reach (uu 'vof) in a bare
# host binary -- EXTRACTED from test/uu.l (the corpus file stays the one source of
# truth; the span is everything above its UniMath section), a names-mark ahead so
# ai/uuexport.l (lib_h pattern rule) can sweep the span into the `uu` book.
out/lib/uukern.l: test/uu.l
	@mkdir -p out/lib
	@echo AI	$@
	@{ echo "(: uu-mark (names ()))"; sed '/^; --- UniMath/q' test/uu.l; } > $@
out/lib/uu.h: out/lib/uukern.l tools/lcat.l
	$(lcat_h)
# test/uuwm.l is a COMMITTED GENERATED artifact: phos's zipper ops compiled
# from crew/phos/core.l into uu terms (tools/uuwmgen.l over tools/wm2uu.l, kind-
# directed by crew/phos/sigs.l), so test/uuwmlaw.l proves its theorems OF THE
# IMPLEMENTATION at corpus time. `make uuwm` refreshes it after a core.l edit;
# test_uuwm (in test_all) regenerates and diffs, failing loudly on drift.
uuwm: host
	@echo AI	test/uuwm.l "(tools/uuwmgen.l on $m)"
	@$m tools/uuwmgen.l > test/uuwm.l
test_uuwm: host
	@echo TEST test/uuwm.l "(regenerate + diff)"
	@$m tools/uuwmgen.l > out/host/.uuwm.l.tmp
	@cmp -s out/host/.uuwm.l.tmp test/uuwm.l \
	  || { echo "FAIL: test/uuwm.l is stale (crew/phos/core.l moved?) -- run: make uuwm"; exit 1; }
	@rm -f out/host/.uuwm.l.tmp
# ai0's sed-wrapped raw source of the same three (no interpreter -- the l reader
# strips ; comments at read time), baked into the bootstrap so the corpus can test
# the assembler under BOTH compilers (c0 + the self-hosted ev), like prel/ev/bao.
out/lib/holo0.h: crew/holo/holo.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/x640.h: crew/holo/x64.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/arm640.h: crew/holo/arm64.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/export0.h: crew/holo/export.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/%0.h: ai/%.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
# the glaze headers (ai/glaze/ -- outside the ai/*.l wildcard, so explicit). Raw sed_lit:
# the glaze source is sigil-heavy, so skip the lcat reader round-trip and bake it verbatim.
out/lib/emit.h: ai/glaze/emit.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/auto.h: ai/glaze/auto.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/gexport.h: ai/glaze/export.l
	@mkdir -p out/lib
	@echo AI	$@
	@$(sed_lit) $< > $@
out/lib/tests0.h: $t
	@mkdir -p out/lib
	@echo AI	$@
	@cat $t | $(sed_lit) > $@

# ai_version.h: the build's version-control id, surfaced in the runtime as the `ai-version`
# global (ai.c ai_ini_0). VCS-AGNOSTIC: a _darcs/ repo stamps darcs-<12-hex patch hash>
# (-dirty when darcs whatsnew is non-empty), else git describe, else "unknown" -- so the
# darcs snapshot import carries this rule verbatim and stamps itself. Regenerated every
# make but only rewritten when the id changes, so l.o relinks on a new revision, not on
# every build. Frontends without it on the include path fall back to "unknown" (ai.c
# uses __has_include).
.PHONY: force_version
force_version: ;
out/lib/ai_version.h: force_version
	@mkdir -p out/lib
	@if [ -d $(R)/_darcs ]; then \
	  v="darcs-$$(darcs log --repodir $(R) --last 1 2>/dev/null | awk '/^patch/{print substr($$2,1,12)}')"; \
	  darcs whatsnew --repodir $(R) >/dev/null 2>&1 && v="$$v-dirty"; \
	else \
	  v="$$(git -C $(R) describe --always --dirty 2>/dev/null || echo unknown)"; \
	fi; printf '#define AI_VERSION "%s"\n' "$$v" > $@.tmp
	@if cmp -s $@.tmp $@ 2>/dev/null; then rm -f $@.tmp; else mv $@.tmp $@; echo SH $@; fi

# ====================================================================
# host (POSIX CLI) build -- outputs under out/host. Was host/Makefile.
# ====================================================================
# The DEFAULT flavor owns out/host; the other flavor builds in its own hsuf'd
# tree (common.mk: out/host-glibc when musl is the default, out/host-musl when
# it isn't), so a musl build never overwrites glibc objects -- musl's bare
# `sigsetjmp` vs glibc's `__sigsetjmp` macro would otherwise poison a cross-libc
# relink. The .hostcc stamp below catches the IN-PLACE flips (musl-clang
# appearing/vanishing changes what out/host means). The bootstrap (ai0) + the
# generated out/lib/*.h headers stay PINNED to canonical out/host paths and
# plain $(CC): ai0 never goes musl.
ho = out/host$(hsuf)
h_o = $(ai_c:$(R)/%.c=$(ho)/%.o)
# host/*.c: per-app host-nif files (auto-globbed, auto-registered via AI_NIF).
# Linked DIRECTLY into the binary (not via libai.a) so the ai_nifs section is
# never archive-collected. Drop a host/<app>.c in and it builds -- no rule edit.
host_o = $(patsubst host/%.c,$(ho)/host/%.o,$(wildcard host/*.c))
# the host runs $(tco) (common.mk; default 1 = tail-threaded, vmret-checked);
# ai0 below stays pinned 0, the deliberate trampoline-coverage lane.
# (-I$(ho) -Iout/lib for the generated egg/cli headers.)
# host_cc: STATIC picks musl-clang unless CC was set explicitly (the musl-gcc
# fallback below); ai0 and the lib tools stay on plain $(CC) either way.
host_cc = $(if $(STATIC),$(if $(cc_user),$(CC),musl-clang),$(CC))
hcc = $(host_cc) $(ai_cflags) -Dai_tco=$(tco) -fpic -I$(ho) -I. -Iout/lib
# whole-archive flag differs by linker (ld64 vs GNU ld); ai_typ is now a plain
# compare in ai.h, so there is no data.ld / generated data.h on any platform.
ifeq ($(shell uname -s),Darwin)
so_archive = -Wl,-force_load,$(ho)/libai.a       # ld64's whole-archive
# the host contract (ai_clock, ai_fd_port_vt, ai_stdin/out/err -- defined in
# host/main.c, linked into `ai` itself, NOT the archive) is UNRESOLVED in the .so
# by design: the loading executable provides it. GNU ld allows that by default;
# ld64 rejects undefined symbols in a dylib unless told to defer them.
so_undef = -Wl,-undefined,dynamic_lookup
else
so_archive = -Wl,--whole-archive $(ho)/libai.a -Wl,--no-whole-archive
endif
# STATIC links a fully static `ai` against musl (and skips libai.so, which a
# static build can't produce) -- THE DEFAULT on Linux when musl-clang is present
# (common.mk static_default): the binary runs on ANY Linux distro regardless of
# glibc version AND still does DNS -- static *glibc* can't resolve hostnames
# (getaddrinfo needs NSS via dlopen, impossible when static), but musl resolves
# itself, so ain's `connect host port` works. Costs +1% size (~55K of text, the
# whole libc; the ~4M baked image dwarfs it) at the same test-corpus speed.
# musl-clang is clang (matches our clang default) + the musl libc -- the clean
# path. VALIDATED: fully static, `ldd` = not-a-dynamic-executable, runs,
# getaddrinfo baked in, full corpus green. `make STATIC=0` builds the dynamic
# glibc `ai` (plus libai.so) in its own out/host-glibc tree -- no need to clean
# between flavors.
# musl is Linux-only -- this is the Linux portable-binary artifact, NOT the mac
# build (mac = a native Apple-clang build; STATIC never defaults on there).
# FALLBACK: `STATIC=1 CC=musl-gcc` works too but is a gcc wrapper; on Arch its
# spec injects a phantom `-latomic_asneeded` (we use no real atomics -- only
# volatile sig_atomic_t flags), so it needs an empty stub on the link path:
#   ar rcs /tmp/libatomic_asneeded.a; make STATIC=1 CC=musl-gcc EXTRA_CFLAGS=-L/tmp
ifneq ($(STATIC),)
host_ldflags = -static
# the musl-clang wrapper injects LINK flags (-fuse-ld, -L…) into every clang call,
# incl. -c compiles, where clang warns "unused during compilation" -> our -Werror
# makes it fatal. Silence that one (harmless; gcc ignores unknown -Wno-*).
ai_cflags += -Wno-unused-command-line-argument
endif
# .hostcc -- the tree's compiler+link identity, content-stamped (cmp keeps the
# mtime when nothing changed). Every host object and the link depend on it, so
# an in-place flavor flip (musl-clang installed/removed flips what out/host
# means; an explicit CC=) rebuilds the tree instead of relinking mixed-libc
# objects (the sigsetjmp poison above -- a loud link error at best).
.PHONY: force_hostcc
force_hostcc: ;
$(ho)/.hostcc: force_hostcc
	@mkdir -p $(ho)
	@printf '%s\n' '$(host_cc) $(host_ldflags)' > $@.tmp
	@if cmp -s $@.tmp $@ 2>/dev/null; then rm -f $@.tmp; else mv $@.tmp $@; echo SH $@; fi
host: $(ho)/ai $(ho)/ai.baked $(if $(STATIC),,$(ho)/libai.so) $(ho)/ai.1
ai0: $(ai0)

# dock: launch the steering dock (port/inle/serve.l) from a stable COPY out/host/dock,
# so `adopt` can rebuild the canonical out/host/ai in place without ETXTBSY (the RELINK
# writes the exe file in place; the bake itself is rename-safe). loads the full crew -- the probe ladder
# (judge), the server (serve), and the self-modify loop (drive + the model proposer patch).
# PORT overrides the mooring; bind loopback and firewall/tunnel it -- it evals what it reads.
.PHONY: dock
DOCK_PORT ?= 7620
dock: host
	@cp $(ho)/ai $(ho)/dock
	exec $(ho)/dock -l port/inle/judge.l -l port/inle/serve.l -l port/inle/drive.l -l port/inle/patch.l -e "(dock $(DOCK_PORT))"
# the default BOOT IMAGE: `$< --bake` boots the freshly-linked binary, snapshots the post-warm
# heap (the glaze baked in, x86-64), and lays it back into the binary's OWN .image section --
# host/image.c copies the exe, pwrites the blob at the section's file offset, and atomically
# renames over the original (no objcopy/objdump, ETXTBSY-proof: a new inode, so anyone still
# executing keeps the old one). A plain `ai` then wakes it at ~4 ms cold start (glazed by
# default) instead of eval'ing the egg (~230 ms). The load is an OPTIMIZATION -- main.c falls
# back to a normal egg boot on any mismatch, so a stale bake is never fatal, only slower.
# (~1.5 s to bake: the glaze self-tests native-compile; paid once per ai rebuild, not per run.)
# The .baked STAMP carries the dependency (the bake mutates the binary itself); a static
# pattern so the CANDIDATE bakes by the same recipe at its side path.
$(ho)/ai.baked $(ho)/ai.cand.baked: %.baked: %
	@echo BAKE	$<
	@$< --bake
	@touch $@

# candidate: build + bake the NEXT GENERATION at the side path out/host/ai.cand.
# nothing executes that name, so the in-place bake can never hit ETXTBSY -- a
# rebuild succeeds no matter who is running `ai` (a repl, a test, the dock's own
# client). gate it with `make test m=$(ho)/ai.cand` (m routes the whole corpus;
# ai0 is independent), then promote on green with an ATOMIC RENAME (a new inode:
# executing processes keep the old one) -- the dock's `adopt` does exactly this.
# on a red gate the canonical binary is UNTOUCHED; the failed candidate dies at
# the side path like a to-space that never flips.
.PHONY: candidate
candidate: $(ho)/ai.cand.baked

# crew/cook/Cookfile: this Makefile transpiled into a resolved cook recipe by
# `cook --emit` (crew/cook/cook.l). cook reads this Makefile directly too, but the
# emitted Cookfile is the build with every $(shell)/$(wildcard)/var/pattern
# RESOLVED -- a flat, self-documenting snapshot. Regenerate it whenever the
# Makefile changes. (A baked snapshot: re-run `make crew/cook/Cookfile` after adding
# a source/test file, since the wildcard lists are frozen at emit time.)
crew/cook/Cookfile: Makefile crew/cook/cook.l $(ho)/ai
	@echo AI	$@
	@$(ho)/ai -l crew/cook/cook.l --emit Makefile > $@

# The lcat'd lib headers (egg.h et al) are PRODUCED BY running ai0, so re-lay
# them whenever ai0 changes. This dep belongs in the rule above, but $(ai0) is
# defined on the line above this one (Make expands prerequisites at PARSE time),
# so up there it expanded to empty -- the dep silently vanished. Stated here it
# binds. (The old "edit a .h => make clean or ai0 hangs" gum is otherwise
# cleaned: ai0's own objects already depend on $(ai_h), so ai0 can't go stale.)
$(lib_h): $(ai0)

# rm the archive first: `ar r` REPLACES/ADDS but never REMOVES, so a renamed/dropped
# source (e.g. love.c -> ai.c) would leave a stale .o in the archive -> multiple-
# definition at link. the rm rebuilds it fresh, so a rename no longer needs `make clean`.
$(ho)/libai.a: $(h_o)
	@echo AR	$@
	@mkdir -p $(dir $@)
	@rm -f $@; ar rcs $@ $^

$(ho)/libai.so: $(ho)/libai.a
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(hcc) -shared -o $@ $(so_archive) $(so_undef) -lm

# Bootstrap interpreter, compiled against the fallback top-level data.h (no
# -I$(ho)) + -DGL_BOOTSTRAP -Dai_tco=0 (also exercises the non-threaded trampoline
# dispatch). Runs the l build tools that generate the lcat headers, so it can't
# depend on those; instead it #includes the sed-wrapped $(gl0_h) (cli0 + the baked
# prel/ev/egg/repl + the test corpus), all produced without an interpreter --
# hence -Iout/lib. Per-object into $(ho)/0/ so ccache caches each TU.
gl0_cc = $(CCACHE) $(CC) $(ai_cflags) -DGL_BOOTSTRAP -Dai_tco=0 -I. -Iout/lib
ai0_o = out/host/0/main.o $(ai_c:$(R)/%.c=out/host/0/%.o)   # PINNED (not $(ho)/0)
out/host/0/main.o: host/main.c $(ai_h) $(gl0_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(gl0_cc) -c $< -o $@
out/host/0/%.o: $(R)/%.c $(ai_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(gl0_cc) -c $< -o $@
$(ai0): $(ai0_o)
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(CC) $(ai_cflags) -o $@ $(ai0_o) -lm

# ai.c -> out/host/*.o
$(ho)/%.o: $(R)/%.c $(ai_h) $(ho)/.hostcc
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(hcc) -c $< -o $@

# l.o carries the version string (ai_version.h); relink it when the id changes.
$(ho)/ai.o $(ho)/0/ai.o: out/lib/ai_version.h
# host/main.o bakes the lcat lib headers inline (egg + prel/ev/cli/bao -- bao is the
# baked shell core now, subsuming the old repl.h). Now that it rides the host/*.c
# glob (compiled once, not recompiled on every link, as the old inline `$(hcc)
# main.c` did), recompile it when any baked header changes.
$(ho)/host/main.o: out/lib/egg.h out/lib/prel.h out/lib/ev.h out/lib/cli.h out/lib/bao.h out/lib/post.h out/lib/uu.h out/lib/uuexport.h $(holo_h) $(glaze_h)
# host/cb.c rides port/quay/quay.c by unity include -- recompile when the engine moves.
$(ho)/host/cb.o: port/quay/quay.c port/quay/quay.h

# host/main.c (auto-globbed into $(host_o)) carries main() + the egg, assembled
# inline via G_EGG_PRE/POST. No separate main.c compile -- it rides the host/*.c
# glob now; the recompile-on-header-change dep is the line just above.
# one link rule, two names: `ai` (canonical) and `ai.cand` (the CANDIDATE -- the next
# generation built at a side path nothing executes, so the RELINK can never hit
# ETXTBSY no matter who is running `ai`; see the candidate target below).
$(ho)/ai $(ho)/ai.cand: $(host_o) $(ho)/libai.a $(ho)/.hostcc out/lib/egg.h out/lib/prel.h out/lib/ev.h out/lib/cli.h out/lib/bao.h out/lib/post.h out/lib/uu.h out/lib/uuexport.h $(holo_h) $(glaze_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(hcc) -o $@ $(host_o) $(ho)/libai.a -lm $(host_ldflags)

$(ho)/ai.1: doc/ai.1 out/lib/ai_version.h
	@echo SED	$@
	@mkdir -p $(dir $@)
	@v=$$(sed -n 's/.*AI_VERSION "\(.*\)"/\1/p' out/lib/ai_version.h); \
	 sed "s/@VERSION@/$$v/" doc/ai.1 > $@

# ====================================================================
# kernel (freestanding) build -- outputs under out/free. Was free/Makefile.
# The inle kernel lives in port/inle/: arch-independent glue is kmain.c + k.h
# there, per-arch code in port/inle/<a>/ (arch.c, *.S, *.lds). Boots via Limine.
# ====================================================================
ko = out/free
dl = out/dl

# K_TEST=1 builds a headless serial test kernel (batch read-eval over COM1, with an
# `exit` nif that quits qemu) into its own odir / elf / iso, so it never clobbers the
# normal interactive kernel. See the test_kernel target below.
ifdef K_TEST
ksuf := -test
endif
# INLE=1 bakes the inle agent (port/inle/inle.l) into the image and boots
# straight into it (the heartbeat loop on the real timer tick) instead of the
# shell -- the kernel AS the self-driving agent. Its own suffix so it never
# clobbers the normal interactive kernel. See port/inle/.
ifdef INLE
ksuf := -inle
endif
# NETECHO=1 boots into an ai-driven UDP echo server over the `nic` port (stage 2e
# gate): the agent perceives a datagram with (slurp nic) and replies with
# (fputs nic d)(fflush nic). Own suffix; normal kernel unchanged.
ifdef NETECHO
ksuf := -netecho
endif
# NETAGENT=1 boots into the inle AGENT loop over the `nic` port (milestone 3):
# the agent perceives a UDP datagram (slurp nic), CHOOSES a reply,
# and survives faults via the watchdog -- vs NETECHO's raw byte echo. Own suffix.
ifdef NETAGENT
ksuf := -netagent
endif
# NETBRAIN=1 boots into the OUTBOUND brain (milestone 5): on its own clock the agent
# INITIATES a UDP round-trip to a remote oracle (aim+say+flush+slurp) and acts on the
# reply -- the (B) fork (port/inle/), the decide step gone remote. Own suffix.
ifdef NETBRAIN
ksuf := -netbrain
endif

# Cross toolchain defaults to clang + lld (one multi-target pair covers every
# arch). Override for a GCC cross toolchain, e.g.
#   make kernel a=aarch64 KCC=aarch64-linux-gnu-gcc KLD=aarch64-linux-gnu-ld
KCC ?= clang
KLD ?= ld.lld
KCC_IS_CLANG := $(shell $(KCC) --version 2>/dev/null | grep -qiw clang && echo 1)

k_arch_c = $(wildcard $(R)/port/inle/$a/*.c)
k_asm = $(wildcard $(R)/port/inle/$a/*.asm)
k_free_c = $R/port/inle/kmain.c
k_shared_c = $(ai_c) $(f_c) $(c_c)
k_S = $(wildcard $(R)/port/inle/$a/*.S)
k_h = $(ai_h) $(wildcard *.h $(R)/port/inle/*.h $(R)/port/inle/$a/*.h)

k_odir = $(ko)/$a$(ksuf)

k_shared_o = $(k_shared_c:$(R)/%.c=$(k_odir)/%.o)
k_arch_o = $(k_arch_c:$(R)/%.c=$(k_odir)/%.o)
k_free_o = $(k_free_c:$(R)/%.c=$(k_odir)/%.o)
k_S_o = $(k_S:$(R)/%.S=$(k_odir)/%.o)
k_asm_o = $(k_asm:$(R)/%.asm=$(k_odir)/%.o)
k_o = $(k_shared_o) $(k_arch_o) $(k_free_o) $(k_S_o) $(k_asm_o)

# The kernel runs the GENERATIONAL collector (the host default), BOUNDED by g->budget: kmain sums the
# limine memmap into kram_words and sets budget = kram_words/8 after ai_ini (the Appel knob). Without
# that bound the nursery's copy-overhead resizer grows unbounded and gen_major's worst-case (all-survive)
# sizing then asks kmallocw for a contiguous block bigger than the largest physical RAM range -> OOM.
# See gen_please (ai.c) and the budget wiring (kmain.c).
kcflags = $(ai_cflags) -nostdinc -ffreestanding -fno-lto -fno-PIC \
  -ffunction-sections -fdata-sections
kldflags := -static -nostdlib --gc-sections -T $(R)/port/inle/$a/$a.lds -z max-page-size=0x1000
kcppflags := \
  -I$(k_odir) \
  -I. -I$(R)/out/host -Iout/lib -I$(R)/port/quay -I$(R) -I$(R)/port/inle \
  -Ilibc \
  -isystem c \
  $(kcppflags) \
  -DLIMINE_API_REVISION=3
ifdef K_TEST
# tail-threaded (ai_tco=1, matching the real kernel + host). This build was long
# PINNED to tco=0 because it "hung" at tco=1 -- ROOT-CAUSED 2026-06-29 (gdb on the
# qemu gdbstub): not a hang but a #PF, the GC's terminator scan following a tag-2
# young-pointing terminator off the heap (gcp gets a terminator as a field because
# range-gated tagp missed it). The kmallocw layout triggered it; glibc/host didn't.
# Fixed by range-independent terminator recognition (tagl/in_live_pool in ai.c), so
# the test gate now exercises tco=1 like everything else. ai0 stays the trampoline lane.
kcppflags += -DK_TEST -Dai_tco=1
endif
# INLE boots into the agent loop -- same settings as the normal interactive
# kernel (it is the shell's read-eval loop with inle as the program), just
# -DINLE to select the boot driver in kmain.c.
ifdef INLE
kcppflags += -DINLE
endif
ifdef NETECHO
kcppflags += -DNETECHO
endif
ifdef NETAGENT
kcppflags += -DNETAGENT
endif
ifdef NETBRAIN
kcppflags += -DNETBRAIN
endif

ifeq ($(KCC_IS_CLANG),1)
kcc_if_clang = -target $a-unknown-none-elf
endif

kcflags_x86_64 = -m64 -march=x86-64 -mabi=sysv -mno-red-zone -mcmodel=kernel
kcflags_aarch64 = -mcpu=generic -march=armv8-a

kldflags_x86_64 = -m elf_x86_64
kldflags_aarch64 = -m aarch64elf

kcc = $(KCC) $(kcflags) $(kcflags_$a) $(kcppflags) $(kcc_if_clang)
k_nasmflags := -f elf64 -g -F dwarf -Wall -w-reloc-abs-qword -w-reloc-abs-dword -w-reloc-rel-dword

kernel: $(ko)/ai-$a$(ksuf).elf

$(ko)/ai-$a$(ksuf).elf: $(R)/port/inle/$a/$a.lds $(k_o)
	@echo LD	$@
	@mkdir -p "$(dir $@)"
	@$(KLD) $(kldflags) $(k_o) -o $@

# Shared C sources (ai.c, port/quay/, c/) + per-arch port//.
# Under K_TEST kmain.c #includes the baked corpus out/lib/ktests.h; under INLE
# the baked agent out/lib/inle.h.
$(k_odir)/%.o: $(R)/%.c $(k_h) out/lib/egg.h out/lib/prel.h out/lib/ev.h out/lib/bao.h $(if $(K_TEST),out/lib/ktests.h) $(if $(INLE)$(NETAGENT)$(NETBRAIN),out/lib/inle.h)
	@echo CC	$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@

# l.o carries the version string (ai_version.h); recompile it when the id changes.
$(k_odir)/ai.o: out/lib/ai_version.h

$(k_odir)/%.o: $(R)/%.S $(k_h)
	@echo AS	$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@

$(k_odir)/%.o: $(R)/%.asm $(k_h)
	@echo AS	$@
	@mkdir -p "$(dir $@)"
	@nasm $< -o $@ $(k_nasmflags)

# --- ISO / HDD image rules -------------------------------------------
k_xorriso_x86_64 = \
  -b boot/limine/limine-bios-cd.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table
k_xorriso = xorriso -as mkisofs -quiet -R -r -J \
  -hfsplus -apm-block-size 2048 \
  --efi-boot boot/limine/limine-uefi-cd.bin \
  -efi-boot-part --efi-boot-image --protective-msdos-label \
  $(k_xorriso_$a)

# The Limine bootloader config is generated here rather than kept as a
# standalone source file (it is four static lines).
$(ko)/limine.conf:
	@mkdir -p $(dir $@)
	@printf 'timeout: 1\n/gk\n    protocol: limine\n    path: boot():/boot/kernel\n' > $@

$(ko)/ai-$a$(ksuf).iso: $(ko)/ai-$a$(ksuf).elf $(dl)/limine/limine $(ko)/limine.conf
	@echo MK $@
	@rm -rf $(ko)/iso_root
	@mkdir -p $(ko)/iso_root/boot
	@cp $< $(ko)/iso_root/boot/kernel
	@mkdir -p $(ko)/iso_root/boot/limine
	@cp $(ko)/limine.conf $(ko)/iso_root/boot/limine/
	@mkdir -p $(ko)/iso_root/EFI/BOOT
	@cp $(dl)/limine/limine-uefi-cd.bin $(ko)/iso_root/boot/limine/
	@cp $(dl)/limine/limine-bios.sys $(dl)/limine/limine-bios-cd.bin $(ko)/iso_root/boot/limine/
	@cp $(dl)/limine/BOOTX64.EFI $(dl)/limine/BOOTIA32.EFI $(ko)/iso_root/EFI/BOOT/
	@cp $(dl)/limine/BOOTAA64.EFI $(ko)/iso_root/EFI/BOOT/
	$(k_xorriso) $(ko)/iso_root -o $@
	@$(dl)/limine/limine bios-install $@
	@rm -rf $(ko)/iso_root

$(ko)/ai-$a.hdd: $(ko)/ai-$a.elf $(dl)/limine/limine $(ko)/limine.conf
	@echo MK $@
	@rm -f $@
	@dd if=/dev/zero bs=1M count=0 seek=64 of=$@
	@PATH=$$PATH:/usr/sbin:/sbin sgdisk $@ -n 1:2048 -t 1:ef00
	@mformat -i $@@@1M
	@mmd -i $@@@1M ::/EFI ::/EFI/BOOT ::/boot ::/boot/limine
	@mcopy -i $@@@1M $< ::/boot/kernel
	@mcopy -i $@@@1M $(ko)/limine.conf ::/boot/limine
	@mcopy -i $@@@1M $(dl)/limine/limine-bios.sys ::/boot/limine
	@mcopy -i $@@@1M $(dl)/limine/BOOTX64.EFI ::/EFI/BOOT
	@mcopy -i $@@@1M $(dl)/limine/BOOTIA32.EFI ::/EFI/BOOT
	@mcopy -i $@@@1M $(dl)/limine/BOOTAA64.EFI ::/EFI/BOOT

# --- qemu run targets ------------------------------------------------
k_qemu_x86_64 = -M q35 -serial stdio
k_qemu_risc = -device ramfb -device qemu-xhci -device usb-kbd -device usb-mouse
k_qemu_aarch64 = -M virt,gic-version=2 -cpu cortex-a72 -serial stdio $(k_qemu_risc)
k_qemu = qemu-system-$a -m 256M $(k_qemu_$a) \
  -drive if=pflash,unit=0,format=raw,file=$(dl)/edk2-ovmf/ovmf-code-$a.fd,readonly=on

# --- live-NIC agent boots (x86_64 only -- the virtio-net driver is port/inle/x86_64/net.c).
# net.c probes for a TRANSITIONAL virtio-net (legacy PCI id 0x1000 with an I/O BAR), so
# disable-modern=on is REQUIRED: a modern-only device (id 0x1040, no I/O BAR) is invisible to
# it. SLIRP user networking seats the guest at 10.0.2.15, the host/gateway at 10.0.2.2.
k_net = -device virtio-net-pci,netdev=n0,disable-modern=on
# inbound (NETAGENT): forward host udp 5555 -> guest 5555, so you can drive the agent:
#   printf '(* 6 7)' | nc -u -w1 127.0.0.1 5555    ->  42   (first datagram is lost to ARP)
k_net_in = -netdev user,id=n0,hostfwd=udp::5555-:5555 $(k_net)
# outbound (NETBRAIN): plain user net; the agent DIALS 10.0.2.2:9999 on its own clock, so
# stand up a UDP server on the host :9999 first -- it receives each datagram and whatever it
# replies is what the agent narrates (`oracle <- ...`). That server is the seam for a real brain.
k_net_out = -netdev user,id=n0 $(k_net)

.PHONY: run run-hdd run-$a run-hdd-$a run-headless run-inle run-netagent run-netbrain
run: run-$a
run-hdd: run-hdd-$a
run-$a: $(ko)/ai-$a.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
	exec $(k_qemu) -cdrom $<
run-hdd-$a: $(ko)/ai-$a.hdd $(dl)/edk2-ovmf/ovmf-code-$a.fd
	exec $(k_qemu) -hda $<
run-headless: $(ko)/ai-$a.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
	exec $(k_qemu) -cdrom $< -display none -no-reboot

# Boot the baked inle agent. INLE = heartbeat/watchdog/checkpoint demos then a serial shell
# (no NIC); NETAGENT = the inbound ai-REPL over the wire; NETBRAIN = the outbound brain that
# dials an oracle on its own clock. Each (re)builds its own-suffixed iso, then boots headless
# with serial on stdio so you watch the agent narrate in this terminal (Ctrl-C to stop).
run-inle:
	@$(MAKE) -s INLE=1 $(ko)/ai-$a-inle.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
	exec $(k_qemu) -cdrom $(ko)/ai-$a-inle.iso -display none -no-reboot
ifeq ($a,x86_64)
run-netagent:
	@$(MAKE) -s NETAGENT=1 $(ko)/ai-$a-netagent.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
	exec $(k_qemu) $(k_net_in) -cdrom $(ko)/ai-$a-netagent.iso -display none -no-reboot
run-netbrain:
	@$(MAKE) -s NETBRAIN=1 $(ko)/ai-$a-netbrain.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
	exec $(k_qemu) $(k_net_out) -cdrom $(ko)/ai-$a-netbrain.iso -display none -no-reboot
else
run-netagent run-netbrain:
	@echo "$@: x86_64 only (virtio-net driver is port/inle/x86_64/net.c); host arch is $a"
endif

# Boot init AS PID 1 in a container -- the Linux altitude of "ai as the system".
# A private pid+user+mount namespace (unprivileged, no daemon/image/root): --pid
# --fork makes the entrypoint pid 1, --user --map-root-user makes it root-in-ns so
# mount works, --mount-proc gives it a fresh /proc reflecting the namespace. ai then
# IS init: getpid 1, mounts the early filesystems, and reaps a reparented orphan
# (pid 1's defining duty). (pid1 0) is the deterministic tour; swap in (perceive 0)
# for the live signalfd supervisor. Needs unshare (util-linux) + unprivileged userns.
.PHONY: init-container
init-container: host
	@command -v unshare >/dev/null || { echo "init-container: needs unshare (util-linux)"; exit 1; }
	@echo "-- ai as PID 1 in a pid+user+mount namespace --"
	unshare --pid --fork --mount-proc --user --map-root-user -- $m -l init/init.l -e "(pid1 0)"

# --- headless serial test (wired into test_all; x86_64 + qemu only) ------------
# The K_TEST kernel boots, runs the baked corpus through the self-hosted ev, and
# PASSES (1708/1708 in ~2.5s). Two bugs were behind the long-parked hang:
#  (1) the cooperative scheduler deadlocked -- a task blocked in `(wait p)` was
#      saved by yield_sw parked on the kernel's serial input fd (a stale
#      next_wait_fd), so find_runnable never rescheduled it (fixed in ai.c
#      lvm_wait: clear next_wake_at/next_wait_fd before yielding);
#  (2) five float-sqrt asserts failed because libc/math.c pow(x,0.5) used
#      exp(0.5*log x) (drifts a few ULP) instead of the exact Newton sqrt(), and
#      cos_k's Taylor ran a couple terms short at the pi/4 boundary.
#
# A K_TEST kernel bakes the test corpus in (out/lib/ktests.h, baked VERBATIM by
# tools/lcatv.l -- lcat's inspect-reprint diverges when the corpus is read back
# incrementally via a strin port) and runs it through the self-hosted ev at boot,
# printing the usual summary over the serial console, then quits qemu (the `exit`
# nif -> isa-debug-exit). tools/ktest.l (run on
# the host l) boots it under qemu headless, captures the serial output, and checks
# it. So this exercises the freestanding kernel the way test_host/test_ai0 exercise
# the host. x86_64 only (qemu + isa-debug-exit); a no-op on other hosts.
#
# Drop from the kernel corpus: io.l (host file open) and run.l (subprocess/getenv)
# need host-OS nifs the kernel lacks; math.l pins transcendental results to glibc
# precision (1e-12/1e-15) that the freestanding libc/math.c series can't meet;
# bell.l's Bell-number bignums are too heavy for the emulated kernel.
kt = $(filter-out %/io.l %/run.l %/math.l %/bell.l,$t)
out/lib/ktests.l: $(kt) $(R)/Makefile
	@mkdir -p out/lib
	@cat $(kt) > $@
out/lib/ktests.h: out/lib/ktests.l $(ai0) tools/lcatv.l ai/prel.l
	@echo AI	$@
	@$(ai0) -l ai/prel.l tools/lcatv.l out/lib/ktests.l > $@
# The inle agent, baked VERBATIM (lcatv) to a C string literal kmain.c #includes
# under INLE and drinks form-by-form through zevs at boot -- same path as the
# K_TEST corpus, one program instead of the test suite.
out/lib/inle.h: port/inle/inle.l $(ai0) tools/lcatv.l ai/prel.l
	@echo AI	$@
	@$(ai0) -l ai/prel.l tools/lcatv.l port/inle/inle.l > $@
# arm64 EXECUTION validator: cross-build `ai` for aarch64 + run the corpus under
# qemu-aarch64 (the trustworthy check for the glaze's second target -- holotest
# proves byte encodings, this proves they run). No-ops without qemu + a cross-gcc.
.PHONY: test_arm64
test_arm64: host
	@./tools/arm64check.sh

.PHONY: test_kernel
ifeq ($a,x86_64)
test_kernel: host $(R)/tools/ktest.l
	@$(MAKE) -s K_TEST=1 $(ko)/ai-$a-test.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
	@echo TEST $(ko)/ai-$a-test.iso "(serial, headless)"
	@$m $(R)/tools/ktest.l $(ko)/ai-$a-test.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
else
test_kernel:
	@echo "test_kernel: skipped (host arch $a is not x86_64)"
endif

# --- wasm headless test (wired into test_all; emcc + node) -----------------
# Build ai.js and run the SAME $t corpus through it under node -- a third
# runtime after the host and ai0, exercising wasm's <data.h> override
# (sentinel-ap data kinds, no flat code-address space). The harness evals the
# whole corpus in one ai_eval and greps the drained output for the zz-fin
# summary, exactly as test_host greps `cat $t | ai`. No-op when emcc or node
# is missing (so a plain `make test_all` stays green on a host without them).
NODE ?= $(shell command -v node 2>/dev/null)
EMCC ?= $(or $(shell command -v emcc 2>/dev/null),/usr/lib/emscripten/emcc)
.PHONY: test_wasm
ifeq ($(and $(NODE),$(wildcard $(EMCC))),)
test_wasm:
	@echo "test_wasm: skipped (needs emcc + node)"
else
test_wasm: wasm
	@echo TEST wasm/ai.js "(node)"
	@$(NODE) $(R)/wasm/test.mjs $t
endif

# --- downloads -------------------------------------------------------
$(dl)/edk2-ovmf/ovmf-code-%.fd:
	@echo MK ovmf
	@mkdir -p $(dl)
	@curl -L https://github.com/osdev0/edk2-ovmf-nightly/releases/latest/download/edk2-ovmf.tar.gz | gunzip | tar -C $(dl) -xf -
	@case "$a" in \
		aarch64) dd if=/dev/zero of=$@ bs=1 count=0 seek=67108864 2>/dev/null;; \
	esac

$(dl)/limine/limine:
	@echo MK limine
	@rm -rf $(dl)/limine
	@git clone https://codeberg.org/Limine/Limine.git $(dl)/limine --branch=v10.x-binary --depth=1 > /dev/null 2>&1
	@$(MAKE) -sC $(dl)/limine

# ====================================================================
# wasm (own Makefile)
# ====================================================================
wasm:
	@$(MAKE) -C wasm

clean:
	rm -rf out
	@rm -f proof/rocq/*.vo proof/rocq/*.vok proof/rocq/*.vos proof/rocq/*.glob proof/rocq/.*.aux
	@$(MAKE) -C wasm clean
distclean: clean

valg: host
	cat $t | valgrind --error-exitcode=1 --suppressions=$R/tools/valgrind.supp $m
out/host/perf.data: host
	cat $t | perf record -o $@ $m
perf: out/host/perf.data
	exec perf report -i $<
out/host/flamegraph.svg: out/host/perf.data
	flamegraph -o $@ --perfdata $<
repl: host
	@exec $m
cloc:
	cloc --by-file ai ai.c ai.h main.c port tools test vim
cat: clean all test
cata: clean all test_all
# Full clean rebuild, every frontend, all tests, then the corpus under valgrind.
catav: clean all test_all valg

disasm: host
	exec rizin -A $m
gdb: host
	exec gdb $m
vmret: host
	@$m tools/vmret.l $m

bench: host
	$(MAKE) -C bench bench

# --- install / uninstall --------------------------------------------
PREFIX ?= .local/
VIMPREFIX ?= .vim/
DESTDIR ?= $(HOME)/
d = $(DESTDIR)/$(PREFIX)
v = $(DESTDIR)/$(VIMPREFIX)
installs = \
  $d/bin/ai \
  $d/bin/au \
  $d/bin/cook \
  $d/bin/ain \
  $d/bin/phos \
  $d/bin/bao \
  $d/share/man/man1/ai.1 \
  $d/lib/ai/prel.l \
  $d/lib/ai/ev.l \
  $d/lib/ai/bao.l \
  $d/lib/libai.a \
  $d/lib/libai.so \
  $d/include/ai.h \
  $v/ftdetect/ai.vim \
  $v/syntax/ai.vim \
  $v/ftplugin/ai.vim

install: $(installs)
uninstall:
	@echo RM	$(abspath $(installs))
	@rm -f $(installs)

$d/include/ai.h: ai.h
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/ai/%.l: ai/%.l
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

# the embeddable libs install GLIBC always: a musl-compiled archive poisons a
# glibc link (the sigsetjmp note in the host block), and a musl .so is useless
# to a dynamic (glibc) consumer. When the default flavor is musl, that tree is
# out/host-glibc and a sub-make builds it on demand.
glibc_ho = out/host$(if $(static_default),-glibc)
ifneq ($(glibc_ho),$(ho))
$(glibc_ho)/libai.a $(glibc_ho)/libai.so: force_hostcc
	@$(MAKE) --no-print-directory STATIC=0 $@
endif

$d/lib/libai.a: $(glibc_ho)/libai.a
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/libai.so: $(glibc_ho)/libai.so
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

$d/bin/ai: $(ho)/ai $(ho)/ai.baked
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@
# the boot image travels INSIDE the binary (.image is an allocated PROGBITS section, so the
# stripped install keeps it; strip removes only the symbol table -- .text/.rodata vaddrs are
# unchanged, so the image's lvm-table indices and base-delta still resolve, and a bad match
# just falls back to a normal egg boot).

# cook: the build tool (crew/cook/cook.l) installed as an executable `cook` on PATH.
# Its `#!/usr/bin/env -S ai -l` shebang re-execs the installed `ai` to load it,
# then it discovers a Makefile/Cookfile/Cards.l in the cwd. Installed as a SYMLINK
# to the source so edits to crew/cook/cook.l are picked up without a reinstall.
$d/bin/cook: crew/cook/cook.l
	@echo LN	$(abspath $@)
	@mkdir -p $(@D)
	@ln -sf $(abspath $<) $@

# ain: the netcat clone (tools/ain.l). Same shebang-script mechanism as cook
# (`#!/usr/bin/env -S ai -l` re-execs the installed `ai` to load it); the SEAT
# form inside the file finds its own name on the command line and fires.
$d/bin/ain: tools/ain.l
	@echo CP	$(abspath $@)
	@install -D -m 755 $< $@

# au: the multi-call toolbox -- ONE catted script (busybox's trick), the util
# picked off the command line (`au diff A B`, `au nc H P`, `au make`, `au as ..`)
# or off argv[0] through a tool-named symlink. Shadows nothing on the host: only
# `au` lands on PATH; the distro symlinks the tool names when shadowing is the
# point. The tool files' SEATs stay quiet inside the cat (no file of theirs sits
# in the program seat), so crew/utils/au.l's dispatcher is the one thing firing.
$d/bin/au: $(aufiles)
	@echo AI	$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/usr/bin/env -S ai'; cat $(aufiles); } > $@
	@chmod 755 $@

# phos: the window manager (crew/phos/*.l), the seven modules catted into one shebang
# script. DISPLAY picks the socket, ~/.Xauthority the cookie (crew/phos/config.l);
# mod+q restarts in place by exec'ing this same script.
phosfiles = crew/phos/core.l crew/phos/layout.l crew/phos/wire.l crew/phos/ewmh.l crew/phos/manage.l crew/phos/keys.l crew/phos/config.l crew/phos/phos.l
$d/bin/phos: $(phosfiles)
	@echo AI	$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/usr/bin/env -S ai -l'; cat $(phosfiles); } > $@
	@chmod 755 $@

# bao: the interactive shell. Unlike crew/cook/ain, ai/bao.l is DEFINE-ONLY (the
# launch `(bao 0)` is normally fired by main.c on a tty), so the bin is a tiny
# relocatable launcher: it loads the installed bao.l next door and fires it.
$d/bin/bao: Makefile
	@echo AI	$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/bin/sh'; \
	   echo 'h=$$(CDPATH= cd -- "$$(dirname -- "$$0")" && pwd)'; \
	   echo 'exec "$$h/ai" -l "$$h/../lib/ai/bao.l" -e "(bao 0)" "$$@"'; } > $@
	@chmod 755 $@

$d/share/man/man1/ai.1: $(ho)/ai.1
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$v/ftdetect/ai.vim: vim/ftdetect.vim
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$v/syntax/ai.vim: vim/syntax.vim
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$v/ftplugin/ai.vim: vim/ftplugin.vim
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@
