# Project root. Single Makefile: cross-cutting tasks (test, clean, install, ...)
# plus the host (POSIX CLI) and kernel (freestanding) builds inlined directly
# here; wasm keeps its own Makefile. Device ports (playdate, rp2040) live in
# the separate l-ports repo. Build output lands under out/
# (out/host, out/free, out/lib, out/dl). Shared vars live in common.mk.
R := .
include common.mk

CCACHE ?= $(shell command -v ccache 2>/dev/null)

.PHONY: all install uninstall clean distclean hooks
.PHONY: host kernel wasm ai0
.PHONY: test test_host test_all test_tools test_ai0 test_wasm test_proof test_gen test_hostnif test_extract
.PHONY: valg disasm flame cat cata catav perf repl gdb vmret bench nettest
test: test_host test_ai0 test_proof test_gen
# test_kernel + test_wasm are in test_all but NOT the fast `test`: each needs an
# extra toolchain (qemu + OVMF, x86_64-only; emcc + node) and no-ops when that
# is absent. See their rules below.
test_all: test_host test_ai0 test_proof test_gen test_extract test_tools test_hostnif test_kernel test_wasm
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
test_host: host
	@echo TEST $m
	@cat $t | $m > out/host/.test_host.out; s=$$?; cat out/host/.test_host.out; \
	  [ $$s -eq 0 ] && grep -q "tests pass" out/host/.test_host.out
# Host-nif smoke tests: nifs defined in host/*.c link into `ai` but NOT ai0
# (which bakes the corpus), so they cannot live in test/*.l -- ai0 would read the
# names as missing and fail its self-test. Run them standalone against the built
# binary instead. Each script prints a "<name>: ok" sentinel and uses the
# test/00-init.l assert harness (which exits 1 on the first failure), so the gate
# checks BOTH exit 0 AND the sentinel -- a silent reader-stop exits 0 without it.
# Add a thread's smoke script to hostnif_tests (aineko: boot/net.l, &c).
hostnif_tests = boot/pty.l boot/net.l
test_hostnif: host
	@for s in $(hostnif_tests); do echo "HOSTNIF $$s"; \
	  cat test/00-init.l $$s | $m > out/host/.test_hostnif.out 2>&1; r=$$?; \
	  cat out/host/.test_hostnif.out; \
	  { [ $$r -eq 0 ] && grep -q ': ok' out/host/.test_hostnif.out; } \
	    || { echo "FAIL $$s (exit $$r)"; exit 1; }; \
	done
# aineko's two-process loopback gate: a server and a client over real TCP on
# 127.0.0.1, full-duplex, asserting each side received what the other sent (the
# socket nifs in host/net.c + the pump loops in tools/aineko.l). DELIBERATELY
# separate from `make test`/`test_all` -- it needs two live processes and a free
# loopback port, where the in-process `boot/net.l` smoke (in test_hostnif) covers
# the nifs portably. Override the port with `make nettest PORT=NNNN`.
PORT ?= 7390
nettest: host
	@echo NETTEST $m "(127.0.0.1:$(PORT))"
	@sh $R/test/net/loopback.sh $m $(PORT)
# Validate the l tool rewrites against their frozen Python references in
# tools/py/ (gen_data / vmret). See tools/Makefile + tools/py/README.md.
test_tools: host
	@$(MAKE) -C tools
# Machine-check rocq/spec.v -- ai's headline laws (the numeral / function /
# absence core of test/spec.l) as Rocq theorems, axiom-free (every proof
# "Closed under the global context"). This is what upgrades the executable
# spec from DEMONSTRATED on every target to PROVED in a consistent metatheory
# -- the README's "verified specification ... up to explosion of world" made
# load-bearing (the caveat is uu.l's type-in-type detonation; this file runs
# universe-checked, so it does not explode). coqc writes artifacts next to the
# source; clean them on success. No-op when coqc is missing, so the gate stays
# green without a Rocq install (like test_kernel / test_wasm).
COQC ?= $(shell command -v coqc 2>/dev/null)
ifeq ($(COQC),)
test_proof:
	@echo "test_proof: skipped (needs rocq/coqc)"
else
test_proof:
	@echo TEST rocq/spec.v "(coqc)"
	@$(COQC) -q rocq/spec.v
	@rm -f rocq/spec.vo rocq/spec.vok rocq/spec.vos rocq/spec.glob rocq/.spec.aux
endif
# The .l -> .v pipeline: tools/spec2coq.l (run on the host binary $m) reads
# test/spec.l and EMITS rocq/gen.v -- the spec generating Coq theorems for its
# own pure-numeral corpus facts, each closed by computation (over Z, since nat
# is unary and 3^27 would blow up vm_compute). coqc then checks them. Drift-proof:
# the asserts and their proofs cannot diverge -- regenerated every run from .l.
# Needs the host binary AND coqc; no-ops without coqc, like test_proof.
ifeq ($(COQC),)
test_gen:
	@echo "test_gen: skipped (needs rocq/coqc)"
else
test_gen: host
	@echo GEN	rocq/gen.v "(tools/spec2coq.l on $m)"
	@$m tools/spec2coq.l > rocq/gen.v
	@echo TEST rocq/gen.v "(coqc)"
	@$(COQC) -q rocq/gen.v
	@rm -f rocq/gen.vo rocq/gen.vok rocq/gen.vos rocq/gen.glob rocq/.gen.aux
endif

# test_extract: the differential oracle with a ROCQ-EXTRACTED reference. coqc
# extracts rocq/extract.v (the n-ary/CBV/weak/saturating normalizer built on
# spec.v's PROVEN subst/shift) to OCaml; rocq/oracle_drive.ml generates random
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
	@echo TEST rocq/extract.v "(coqc extraction -> ocaml ref vs ev)"
	@cd rocq && $(COQC) -R . "" spec.v >/dev/null && $(COQC) -R . "" extract.v >/dev/null \
	  && rm -f normalizer.mli && $(OCAMLOPT) -w -a normalizer.ml oracle_drive.ml -o oracle_drive
	@rocq/oracle_drive 2000 6 1 > out/.extract_oracle.l
	@$m out/.extract_oracle.l | grep -q "2000 / 2000 PASS" \
	  || { echo "EXTRACT ORACLE FAILED:"; $m out/.extract_oracle.l; exit 1; }
	@$m out/.extract_oracle.l
	@rm -f rocq/spec.vo rocq/spec.vok rocq/spec.vos rocq/spec.glob rocq/.spec.aux \
	  rocq/extract.vo rocq/extract.vok rocq/extract.vos rocq/extract.glob rocq/.extract.aux \
	  rocq/normalizer.ml rocq/normalizer.mli rocq/oracle_drive rocq/*.cmi rocq/*.cmx rocq/*.o \
	  out/.extract_oracle.l
endif
all: host kernel wasm blue

# Point git at the tracked hooks dir (.githooks). The pre-commit hook rebuilds
# wasm/ai.js whenever a commit touches what it is built from, so the committed
# artifact never lags the sources. One-time per clone; idempotent.
hooks:
	@git config core.hooksPath .githooks && echo "git hooks -> .githooks (pre-commit keeps wasm/ai.js fresh)"

# Static lisp headers: each ai/*.l is serialized to a C string literal in
# out/lib/*.h by tools/lcat.l (run on the bootstrap interpreter ai0). Frontends
# #include these and assemble the bootstrap with G_EGG_PRE/POST (ai.h).
# Drop a .l into ai/ and it is picked up automatically -- no rule to edit.
lib_h = $(patsubst ai/%.l,out/lib/%.h,$(wildcard ai/*.l))
# ai0's bootstrap headers: sed-wrapped raw source (a text->C-literal needing no
# interpreter -- the l reader strips the ; comments at read time), since ai0
# can't lcat the very sources it is assembled from (chicken/egg). cli.l doubles as
# ai0's CLI arg handler; prel/ev/egg/repl + the whole concatenated test corpus
# are baked in so ai0 self-tests both compilers in one run (see main.c). The final
# l uses the canonicalized lcat headers from the rule below instead.
sed_lit = sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/^/"/' -e 's/$$/\\n"/'
gl0_h = out/lib/cli0.h out/lib/egg0.h out/lib/prel0.h out/lib/ev0.h out/lib/repl0.h out/lib/tests0.h
.PHONY: lib
lib: $(lib_h) $(gl0_h)
$(lib_h): out/lib/%.h: ai/%.l tools/lcat.l   # + $(ai0), stated below where it is in scope
	@mkdir -p out/lib
	@echo GEN	$@
	@$(ai0) -l ai/prel.l tools/lcat.l $< > $@
out/lib/%0.h: ai/%.l
	@mkdir -p out/lib
	@echo GEN	$@
	@$(sed_lit) $< > $@
out/lib/tests0.h: $t
	@mkdir -p out/lib
	@echo GEN	$@
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
	@if cmp -s $@.tmp $@ 2>/dev/null; then rm -f $@.tmp; else mv $@.tmp $@; echo GEN $@; fi

# ====================================================================
# host (POSIX CLI) build -- outputs under out/host. Was host/Makefile.
# ====================================================================
ho = out/host
h_o = $(ai_c:$(R)/%.c=$(ho)/%.o)
# host/*.c: per-app host-nif files (auto-globbed, auto-registered via AI_NIF).
# Linked DIRECTLY into the binary (not via libai.a) so the ai_nifs section is
# never archive-collected. Drop a host/<app>.c in and it builds -- no rule edit.
host_o = $(patsubst host/%.c,$(ho)/host/%.o,$(wildcard host/*.c))
# the host runs $(tco) (common.mk; default 1 = tail-threaded, vmret-checked);
# ai0 below stays pinned 0, the deliberate trampoline-coverage lane.
# (-I$(ho) -Iout/lib for the generated egg/cli headers.)
hcc = $(CC) $(ai_cflags) -Dai_tco=$(tco) -fpic -I$(ho) -I. -Iout/lib
# whole-archive flag differs by linker (ld64 vs GNU ld); ai_typ is now a plain
# compare in ai.h, so there is no data.ld / generated data.h on any platform.
ifeq ($(shell uname -s),Darwin)
so_archive = -Wl,-force_load,$(ho)/libai.a       # ld64's whole-archive
else
so_archive = -Wl,--whole-archive $(ho)/libai.a -Wl,--no-whole-archive
endif
# STATIC=1 links a fully static `ai` (and skips libai.so, which a static build
# can't use). Pair with a musl-targeting CC so the binary runs on ANY Linux distro
# regardless of glibc version AND still does DNS -- static *glibc* can't resolve
# hostnames (getaddrinfo needs NSS via dlopen, impossible when static), but musl
# resolves itself, so aineko's `connect host port` works:
#   make STATIC=1 CC="zig cc -target x86_64-linux-musl"   (or CC=musl-gcc)
# (musl is Linux-only -- this is the Linux portable-binary artifact, NOT the mac
# build, which is a native Apple-clang build.)
# ⚠ SWITCHING CC CONTAMINATES out/host: the object tree is shared across compilers,
# and a musl-compiled object references bare `sigsetjmp` where glibc wants the
# `__sigsetjmp` macro -- so a later glibc/clang build fails to relink it. Always
# `rm -rf out/host` when crossing the musl<->glibc boundary (in EITHER direction).
ifdef STATIC
host_ldflags = -static
endif
ai0 = $(ho)/ai0

host: $(ho)/ai $(if $(STATIC),,$(ho)/libai.so) $(ho)/ai.1
ai0: $(ai0)

# cook/Cookfile: this Makefile transpiled into a resolved cook recipe by
# `cook --emit` (cook/cook.l). cook reads this Makefile directly too, but the
# emitted Cookfile is the build with every $(shell)/$(wildcard)/var/pattern
# RESOLVED -- a flat, self-documenting snapshot. Regenerate it whenever the
# Makefile changes. (A baked snapshot: re-run `make cook/Cookfile` after adding
# a source/test file, since the wildcard lists are frozen at emit time.)
cook/Cookfile: Makefile cook/cook.l $(ho)/ai
	@echo GEN	$@
	@$(ho)/ai -l cook/cook.l --emit Makefile > $@

# blue.html: the blue paper, generated from blue.md (with blue.css INLINED into a
# <style> block) by the ai markdown converter tools/blue.l. A committed artifact
# like wasm/ai.js -- it ships from the repo and is linked from index.html -- so it
# is regenerated whenever its source, style, or generator changes. `make blue`
# refreshes it; it is also part of `all`.
.PHONY: blue
blue: blue.html
blue.html: blue.md blue.css tools/blue.l $(ho)/ai
	@echo GEN	$@
	@$(ho)/ai -l ai/prel.l tools/blue.l blue.md > $@

# The lcat'd lib headers (egg.h et al) are PRODUCED BY running ai0, so re-lay
# them whenever ai0 changes. This dep belongs in the rule above, but $(ai0) is
# defined on the line above this one (Make expands prerequisites at PARSE time),
# so up there it expanded to empty -- the dep silently vanished. Stated here it
# binds. (The old "edit a .h => make clean or ai0 hangs" gum is otherwise
# cleaned: ai0's own objects already depend on $(ai_h), so ai0 can't go stale.)
$(lib_h): $(ai0)

$(ho)/libai.a: $(h_o)
	@echo AR	$@
	@mkdir -p $(dir $@)
	@rm -f $@; ar rcs $@ $^   # rm first: `ar r` REPLACES/ADDS but never REMOVES, so a
	                          # renamed/dropped source (e.g. love.c -> ai.c) would leave a
	                          # stale .o in the archive -> multiple-definition at link. the
	                          # rm rebuilds it fresh, so a rename no longer needs `make clean`.

$(ho)/libai.so: $(ho)/libai.a
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(hcc) -shared -o $@ $(so_archive) -lm

# Bootstrap interpreter, compiled against the fallback top-level data.h (no
# -I$(ho)) + -DGL_BOOTSTRAP -Dai_tco=0 (also exercises the non-threaded trampoline
# dispatch). Runs the l build tools that generate the lcat headers, so it can't
# depend on those; instead it #includes the sed-wrapped $(gl0_h) (cli0 + the baked
# prel/ev/egg/repl + the test corpus), all produced without an interpreter --
# hence -Iout/lib. Per-object into $(ho)/0/ so ccache caches each TU.
gl0_cc = $(CCACHE) $(CC) $(ai_cflags) -DGL_BOOTSTRAP -Dai_tco=0 -I. -Iout/lib
ai0_o = $(ho)/0/main.o $(ai_c:$(R)/%.c=$(ho)/0/%.o)
$(ho)/0/main.o: host/main.c $(ai_h) $(gl0_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(gl0_cc) -c $< -o $@
$(ho)/0/%.o: $(R)/%.c $(ai_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(gl0_cc) -c $< -o $@
$(ai0): $(ai0_o)
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(CC) $(ai_cflags) -o $@ $(ai0_o) -lm

# ai.c -> out/host/*.o
$(ho)/%.o: $(R)/%.c $(ai_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(hcc) -c $< -o $@

# l.o carries the version string (ai_version.h); relink it when the id changes.
$(ho)/ai.o $(ho)/0/ai.o: out/lib/ai_version.h
# host/main.o bakes the lcat lib headers inline (egg + prel/ev/repl/cli/bao). Now
# that it rides the host/*.c glob (compiled once, not recompiled on every link, as
# the old inline `$(hcc) main.c` did), recompile it when any baked header changes.
$(ho)/host/main.o: out/lib/egg.h out/lib/prel.h out/lib/ev.h out/lib/repl.h out/lib/cli.h out/lib/bao.h

# host/main.c (auto-globbed into $(host_o)) carries main() + the egg, assembled
# inline via G_EGG_PRE/POST. No separate main.c compile -- it rides the host/*.c
# glob now; the recompile-on-header-change dep is the line just above.
$(ho)/ai: $(host_o) $(ho)/libai.a out/lib/egg.h out/lib/prel.h out/lib/ev.h out/lib/repl.h out/lib/cli.h out/lib/bao.h
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(hcc) -o $@ $(host_o) $(ho)/libai.a -lm $(host_ldflags)

$(ho)/ai.1: doc/ai.1 out/lib/ai_version.h
	@echo GEN	$@
	@mkdir -p $(dir $@)
	@v=$$(sed -n 's/.*AI_VERSION "\(.*\)"/\1/p' out/lib/ai_version.h); \
	 sed "s/@VERSION@/$$v/" doc/ai.1 > $@

# ====================================================================
# kernel (freestanding) build -- outputs under out/free. Was free/Makefile.
# The kship kernel lives in port/kship/: arch-independent glue is kmain.c + k.h
# there, per-arch code in port/kship/<a>/ (arch.c, *.S, *.lds). Boots via Limine.
# ====================================================================
ko = out/free
dl = out/dl

# K_TEST=1 builds a headless serial test kernel (batch read-eval over COM1, with an
# `exit` nif that quits qemu) into its own odir / elf / iso, so it never clobbers the
# normal interactive kernel. See the test_kernel target below.
ifdef K_TEST
ksuf := -test
endif
# KSHIP=1 bakes the kship agent (port/kship/kship.l) into the image and boots
# straight into it (the heartbeat loop on the real timer tick) instead of the
# shell -- the kernel AS the self-driving agent. Its own suffix so it never
# clobbers the normal interactive kernel. See crew/kship.md.
ifdef KSHIP
ksuf := -kship
endif
# NETECHO=1 boots into an ai-driven UDP echo server over the `nic` port (stage 2e
# gate): the agent perceives a datagram with (slurp nic) and replies with
# (fputs nic d)(fflush nic). Own suffix; normal kernel unchanged.
ifdef NETECHO
ksuf := -netecho
endif
# NETAGENT=1 boots into the kship AGENT loop over the `nic` port (milestone 3):
# the agent perceives a UDP datagram (slurp nic), DECIDES via the policy, replies,
# and survives faults via the watchdog -- vs NETECHO's raw byte echo. Own suffix.
ifdef NETAGENT
ksuf := -netagent
endif

# Cross toolchain defaults to clang + lld (one multi-target pair covers every
# arch). Override for a GCC cross toolchain, e.g.
#   make kernel a=aarch64 KCC=aarch64-linux-gnu-gcc KLD=aarch64-linux-gnu-ld
KCC ?= clang
KLD ?= ld.lld
KCC_IS_CLANG := $(shell $(KCC) --version 2>/dev/null | grep -qiw clang && echo 1)

k_arch_c = $(wildcard $(R)/port/kship/$a/*.c)
k_asm = $(wildcard $(R)/port/kship/$a/*.asm)
k_free_c = $R/port/kship/kmain.c
k_shared_c = $(ai_c) $(f_c) $(c_c)
k_S = $(wildcard $(R)/port/kship/$a/*.S)
k_h = $(ai_h) $(wildcard *.h $(R)/port/kship/*.h $(R)/port/kship/$a/*.h)

k_odir = $(ko)/$a$(ksuf)

k_shared_o = $(k_shared_c:$(R)/%.c=$(k_odir)/%.o)
k_arch_o = $(k_arch_c:$(R)/%.c=$(k_odir)/%.o)
k_free_o = $(k_free_c:$(R)/%.c=$(k_odir)/%.o)
k_S_o = $(k_S:$(R)/%.S=$(k_odir)/%.o)
k_asm_o = $(k_asm:$(R)/%.asm=$(k_odir)/%.o)
k_o = $(k_shared_o) $(k_arch_o) $(k_free_o) $(k_S_o) $(k_asm_o)

kcflags = $(ai_cflags) -nostdinc -ffreestanding -fno-lto -fno-PIC \
  -ffunction-sections -fdata-sections
kldflags := -static -nostdlib --gc-sections -T $(R)/port/kship/$a/$a.lds -z max-page-size=0x1000
kcppflags := \
  -I$(k_odir) \
  -I. -I$(R)/out/host -Iout/lib -I$(R)/font -I$(R) -I$(R)/port/kship \
  -Ilibc \
  -isystem c \
  $(kcppflags) \
  -DLIMINE_API_REVISION=3
ifdef K_TEST
# Trampoline (ai_tco=0): the kernel test build HANGS at ai_tco=1 -- re-verified
# 2026-06-11 (clean build, qemu silent before the first corpus dot, killed by
# the gate's timeout; the host corpus is green at ai_tco=1, so this is kernel-
# specific -- likely the freestanding toolchain not guaranteeing the sibcall
# the tail-threaded path leans on). ai0 + this build are the two deliberate
# trampoline lanes; the host runs $(tco) below.
kcppflags += -DK_TEST -Dai_tco=0
endif
# KSHIP boots into the agent loop -- same settings as the normal interactive
# kernel (it is the shell's read-eval loop with kship as the program), just
# -DKSHIP to select the boot driver in kmain.c.
ifdef KSHIP
kcppflags += -DKSHIP
endif
ifdef NETECHO
kcppflags += -DNETECHO
endif
ifdef NETAGENT
kcppflags += -DNETAGENT
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

$(ko)/ai-$a$(ksuf).elf: $(R)/port/kship/$a/$a.lds $(k_o)
	@echo LD	$@
	@mkdir -p "$(dir $@)"
	@$(KLD) $(kldflags) $(k_o) -o $@

# Shared C sources (ai.c, font/, c/) + per-arch port//.
# Under K_TEST kmain.c #includes the baked corpus out/lib/ktests.h; under KSHIP
# the baked agent out/lib/kship.h.
$(k_odir)/%.o: $(R)/%.c $(k_h) out/lib/egg.h out/lib/prel.h out/lib/ev.h out/lib/repl.h $(if $(K_TEST),out/lib/ktests.h) $(if $(KSHIP)$(NETAGENT),out/lib/kship.h)
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

.PHONY: run run-hdd run-$a run-hdd-$a run-headless
run: run-$a
run-hdd: run-hdd-$a
run-$a: $(ko)/ai-$a.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) -cdrom $<
run-hdd-$a: $(ko)/ai-$a.hdd $(dl)/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) -hda $<
run-headless: $(ko)/ai-$a.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) -cdrom $< -display none -no-reboot

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
	@echo GEN	$@
	@$(ai0) -l ai/prel.l tools/lcatv.l out/lib/ktests.l > $@
# The kship agent, baked VERBATIM (lcatv) to a C string literal kmain.c #includes
# under KSHIP and drinks form-by-form through zevs at boot -- same path as the
# K_TEST corpus, one program instead of the test suite.
out/lib/kship.h: port/kship/kship.l $(ai0) tools/lcatv.l ai/prel.l
	@echo GEN	$@
	@$(ai0) -l ai/prel.l tools/lcatv.l port/kship/kship.l > $@
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
	@rm -f rocq/*.vo rocq/*.vok rocq/*.vos rocq/*.glob rocq/.*.aux
	@$(MAKE) -C wasm clean
distclean: clean

valg: host
	cat $t | valgrind --error-exitcode=1 --suppressions=$R/tools/valgrind.supp $m
out/host/perf.data: host
	cat $t | perf record -o $@ $m
perf: out/host/perf.data
	perf report -i $<
out/host/flamegraph.svg: out/host/perf.data
	flamegraph -o $@ --perfdata $<
repl: host
	@$m
cloc:
	cloc --by-file ai ai.c ai.h main.c port tools test vim
cat: clean all test
cata: clean all test_all
# Full clean rebuild, every frontend, all tests, then the corpus under valgrind.
catav: clean all test_all valg

disasm: host
	rizin -A $m
gdb: host
	gdb $m
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
  $d/bin/cook \
  $d/bin/aineko \
  $d/bin/bao \
  $d/share/man/man1/ai.1 \
  $d/lib/ai/prel.l \
  $d/lib/ai/ev.l \
  $d/lib/ai/repl.l \
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

$d/lib/libai.a: out/host/libai.a
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/libai.so: out/host/libai.so
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

$d/bin/ai: out/host/ai
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

# cook: the build tool (cook/cook.l) installed as an executable `cook` on PATH.
# Its `#!/usr/bin/env -S ai -l` shebang re-execs the installed `ai` to load it,
# then it discovers a Makefile/Cookfile/Cards.l in the cwd. A script, not a
# binary, so no -s strip.
$d/bin/cook: cook/cook.l
	@echo CP	$(abspath $@)
	@install -D -m 755 $< $@

# aineko: the netcat clone (tools/aineko.l). Same shebang-script mechanism as cook
# (`#!/usr/bin/env -S ai -l` re-execs the installed `ai` to load it).
$d/bin/aineko: tools/aineko.l
	@echo CP	$(abspath $@)
	@install -D -m 755 $< $@

# bao: the interactive shell. Unlike cook/aineko, ai/bao.l is DEFINE-ONLY (the
# launch `(bao 0)` is normally fired by main.c on a tty), so the bin is a tiny
# relocatable launcher: it loads the installed bao.l next door and fires it.
$d/bin/bao: Makefile
	@echo GEN	$(abspath $@)
	@install -d $(dir $@)
	@{ echo '#!/bin/sh'; \
	   echo 'h=$$(CDPATH= cd -- "$$(dirname -- "$$0")" && pwd)'; \
	   echo 'exec "$$h/ai" -l "$$h/../lib/ai/bao.l" -e "(bao 0)" "$$@"'; } > $@
	@chmod 755 $@

$d/share/man/man1/ai.1: out/host/ai.1
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
