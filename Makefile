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
.PHONY: test test_host test_all test_tools test_ai0 test_wasm test_proof test_gen
.PHONY: valg disasm flame cat cata catav perf repl gdb vmret bench
test: test_host test_ai0 test_proof test_gen
# test_kernel + test_wasm are in test_all but NOT the fast `test`: each needs an
# extra toolchain (qemu + OVMF, x86_64-only; emcc + node) and no-ops when that
# is absent. See their rules below.
test_all: test_host test_ai0 test_proof test_gen test_tools test_kernel test_wasm
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
	@echo GEN	rocq/gen.v "(tools/spec2coq.$x on $m)"
	@$m tools/spec2coq.$x > rocq/gen.v
	@echo TEST rocq/gen.v "(coqc)"
	@$(COQC) -q rocq/gen.v
	@rm -f rocq/gen.vo rocq/gen.vok rocq/gen.vos rocq/gen.glob rocq/.gen.aux
endif
all: host kernel wasm

# Point git at the tracked hooks dir (.githooks). The pre-commit hook rebuilds
# wasm/ai.js whenever a commit touches what it is built from, so the committed
# artifact never lags the sources. One-time per clone; idempotent.
hooks:
	@git config core.hooksPath .githooks && echo "git hooks -> .githooks (pre-commit keeps wasm/ai.js fresh)"

# Static lisp headers: each ai/*.l is serialized to a C string literal in
# out/lib/*.h by tools/lcat.l (run on the bootstrap interpreter ai0). Frontends
# #include these and assemble the bootstrap with G_EGG_PRE/POST (ai.h).
# Drop a .l into ai/ and it is picked up automatically -- no rule to edit.
lib_h = $(patsubst ai/%.$x,out/lib/%.h,$(wildcard ai/*.$x))
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
$(lib_h): out/lib/%.h: ai/%.$x tools/lcat.$x   # + $(ai0), stated below where it is in scope
	@mkdir -p out/lib
	@echo GEN	$@
	@$(ai0) -l ai/prel.$x tools/lcat.$x $< > $@
out/lib/%0.h: ai/%.$x
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
# -I$(ho) first so the generated $(ho)/data.h shadows the portable top-level data.h.
# the host runs $(tco) (common.mk; default 1 = tail-threaded, vmret-checked);
# ai0 below stays pinned 0, the deliberate trampoline-coverage lane.
hcc = $(CC) $(ai_cflags) -Dai_tco=$(tco) -fpic -I$(ho) -I. -Iout/lib
# The data-sentinel layout trick is ELF-only: data.ld (a GNU linker script) and
# the generated $(ho)/data.h (reflected from data.o's ELF section sizes by
# gen_data.l) give ai_typ its O(1) slot recovery. mach-o has neither, so on
# Darwin drop both -- data.c/ai.c fall back to the portable top-level data.h,
# whose __APPLE__ path recovers a kind by comparing an ap to the five sentinel
# addresses (no section, no linker script, no reflection).
ifeq ($(shell uname -s),Darwin)
data_ld =
ldflags =
hdata_h =
so_archive = -Wl,-force_load,$(ho)/lib$n.a       # ld64's whole-archive
else
data_ld = data.ld
ldflags = -Wl,-T,$(data_ld)
hdata_h = $(ho)/data.h
so_archive = -Wl,--whole-archive $(ho)/lib$n.a -Wl,--no-whole-archive
endif
ai0 = $(ho)/ai0

host: $(ho)/$n $(ho)/lib$n.so $(ho)/$n.1
ai0: $(ai0)

# cook/Cookfile: this Makefile transpiled into a resolved cook recipe by
# `cook --emit` (cook/cook.l). cook reads this Makefile directly too, but the
# emitted Cookfile is the build with every $(shell)/$(wildcard)/var/pattern
# RESOLVED -- a flat, self-documenting snapshot. Regenerate it whenever the
# Makefile changes. (A baked snapshot: re-run `make cook/Cookfile` after adding
# a source/test file, since the wildcard lists are frozen at emit time.)
cook/Cookfile: Makefile cook/cook.l $(ho)/$n
	@echo GEN	$@
	@$(ho)/$n -l cook/cook.l --emit Makefile > $@

# The lcat'd lib headers (egg.h et al) are PRODUCED BY running ai0, so re-lay
# them whenever ai0 changes. This dep belongs in the rule above, but $(ai0) is
# defined on the line above this one (Make expands prerequisites at PARSE time),
# so up there it expanded to empty -- the dep silently vanished. Stated here it
# binds. (The old "edit a .h => make clean or ai0 hangs" gum is otherwise
# cleaned: ai0's own objects already depend on $(ai_h), so ai0 can't go stale.)
$(lib_h): $(ai0)

$(ho)/lib$n.a: $(h_o)
	@echo AR	$@
	@mkdir -p $(dir $@)
	@rm -f $@; ar rcs $@ $^   # rm first: `ar r` REPLACES/ADDS but never REMOVES, so a
	                          # renamed/dropped source (e.g. love.c -> ai.c) would leave a
	                          # stale .o in the archive -> multiple-definition at link. the
	                          # rm rebuilds it fresh, so a rename no longer needs `make clean`.

$(ho)/lib$n.so: $(ho)/lib$n.a $(data_ld)
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(hcc) $(ldflags) -shared -o $@ $(so_archive) -lm

# The data-sentinel TU bootstraps from the portable top-level data.h (no $(hdata_h)
# prerequisite -- that would be circular, since $(hdata_h) is reflected out of it).
$(ho)/data.o: data.c $(ai_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(hcc) -c $< -o $@

# Bootstrap interpreter, compiled against the fallback top-level data.h (no
# -I$(ho)) + -DGL_BOOTSTRAP -Dai_tco=0 (also exercises the non-threaded trampoline
# dispatch). Runs the l build tools that generate the lcat headers, so it can't
# depend on those; instead it #includes the sed-wrapped $(gl0_h) (cli0 + the baked
# prel/ev/egg/repl + the test corpus), all produced without an interpreter --
# hence -Iout/lib. Per-object into $(ho)/0/ so ccache caches each TU.
gl0_cc = $(CCACHE) $(CC) $(ai_cflags) -DGL_BOOTSTRAP -Dai_tco=0 -I. -Iout/lib
ai0_o = $(ho)/0/main.o $(ai_c:$(R)/%.c=$(ho)/0/%.o)
$(ho)/0/main.o: main.c $(ai_h) $(gl0_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(gl0_cc) -c $< -o $@
$(ho)/0/%.o: $(R)/%.c $(ai_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(gl0_cc) -c $< -o $@
$(ai0): $(ai0_o) $(data_ld)
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(CC) $(ai_cflags) $(ldflags) -o $@ $(ai0_o) -lm

# tools/gen_data.l reflects $(ho)/data.o's ai_data.NN section sizes into
# $(ho)/data.h, whose ai_typ() shifts instead of the portable header's divides.
$(hdata_h): $(ho)/data.o $(ai0) tools/gen_data.$x ai/prel.$x
	@echo GEN	$@
	@$(ai0) -l ai/prel.$x tools/gen_data.$x $< -o $@

# ai.c/data.c -> out/host/*.o (against the generated data.h).
$(ho)/%.o: $(R)/%.c $(ai_h) $(hdata_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(hcc) -c $< -o $@

# l.o carries the version string (ai_version.h); relink it when the id changes.
$(ho)/ai.o $(ho)/0/ai.o: out/lib/ai_version.h

# main.c is compiled into the final l inline (G_EGG_PRE/POST assemble the lib
# headers); depend on them so it relinks when a lib source changes.
$(ho)/$n: main.c $(ho)/lib$n.a out/lib/egg.h out/lib/prel.h out/lib/ev.h out/lib/repl.h out/lib/cli.h $(hdata_h) $(data_ld)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(hcc) $(ldflags) -o $@ main.c $(ho)/lib$n.a -lm

$(ho)/$n.1: doc/$n.1 out/lib/ai_version.h
	@echo GEN	$@
	@mkdir -p $(dir $@)
	@v=$$(sed -n 's/.*AI_VERSION "\(.*\)"/\1/p' out/lib/ai_version.h); \
	 sed "s/@VERSION@/$$v/" doc/$n.1 > $@

# ====================================================================
# kernel (freestanding) build -- outputs under out/free. Was free/Makefile.
# Arch-independent glue is kmain.c + k.h at the root; per-arch code lives in
# port/<a>/ (arch.c, *.S, *.lds). Boots via Limine.
# ====================================================================
ko = out/free
dl = out/dl

# K_TEST=1 builds a headless serial test kernel (batch read-eval over COM1, with an
# `exit` nif that quits qemu) into its own odir / elf / iso, so it never clobbers the
# normal interactive kernel. See the test_kernel target below.
ifdef K_TEST
ksuf := -test
endif

# Cross toolchain defaults to clang + lld (one multi-target pair covers every
# arch). Override for a GCC cross toolchain, e.g.
#   make kernel a=aarch64 KCC=aarch64-linux-gnu-gcc KLD=aarch64-linux-gnu-ld
KCC ?= clang
KLD ?= ld.lld
KCC_IS_CLANG := $(shell $(KCC) --version 2>/dev/null | grep -qiw clang && echo 1)

k_arch_c = $(wildcard $(R)/port/$a/*.c)
k_asm = $(wildcard $(R)/port/$a/*.asm)
k_free_c = $R/kmain.c
k_shared_c = $(ai_c) $(f_c) $(c_c)
k_S = $(wildcard $(R)/port/$a/*.S)
k_h = $(ai_h) $(wildcard *.h $(R)/port/$a/*.h)

k_odir = $(ko)/$a$(ksuf)

k_shared_o = $(k_shared_c:$(R)/%.c=$(k_odir)/%.o)
k_arch_o = $(k_arch_c:$(R)/%.c=$(k_odir)/%.o)
k_free_o = $(k_free_c:$(R)/%.c=$(k_odir)/%.o)
k_S_o = $(k_S:$(R)/%.S=$(k_odir)/%.o)
k_asm_o = $(k_asm:$(R)/%.asm=$(k_odir)/%.o)
k_o = $(k_shared_o) $(k_arch_o) $(k_free_o) $(k_S_o) $(k_asm_o)

# Per-arch data.h reflected out of this arch's data.o (its sentinel stride differs
# by target). Every C object depends on it; data.o bootstraps from the portable
# top-level data.h (no $(kdata_h) prerequisite -- circular).
kdata_h = $(k_odir)/data.h
gen_data = $(R)/tools/gen_data.$x

kcflags = $(ai_cflags) -nostdinc -ffreestanding -fno-lto -fno-PIC \
  -ffunction-sections -fdata-sections
kldflags := -static -nostdlib --gc-sections -T $(R)/port/$a/$a.lds -z max-page-size=0x1000
kcppflags := \
  -I$(k_odir) \
  -I. -I$(R)/out/host -Iout/lib -I$(R)/font -I$(R) \
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

ifeq ($(KCC_IS_CLANG),1)
kcc_if_clang = -target $a-unknown-none-elf
endif

kcflags_x86_64 = -m64 -march=x86-64 -mabi=sysv -mno-red-zone -mcmodel=kernel
kcflags_aarch64 = -mcpu=generic -march=armv8-a

kldflags_x86_64 = -m elf_x86_64
kldflags_aarch64 = -m aarch64elf

kcc = $(KCC) $(kcflags) $(kcflags_$a) $(kcppflags) $(kcc_if_clang)
k_nasmflags := -f elf64 -g -F dwarf -Wall -w-reloc-abs-qword -w-reloc-abs-dword -w-reloc-rel-dword

kernel: $(ko)/$n-$a$(ksuf).elf

$(ko)/$n-$a$(ksuf).elf: $(R)/port/$a/$a.lds $(k_o)
	@echo LD	$@
	@mkdir -p "$(dir $@)"
	@$(KLD) $(kldflags) $(k_o) -o $@

# The data-sentinel TU bootstraps from the portable header (no $(kdata_h) prereq
# -- circular). On a clean build data.h doesn't exist yet, so -I$(k_odir) finds
# nothing and the compile falls through to the portable top-level data.h.
$(k_odir)/data.o: $(R)/data.c $(k_h) out/lib/egg.h out/lib/prel.h out/lib/ev.h out/lib/repl.h
	@echo CC	$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@

$(kdata_h): $(k_odir)/data.o $(gen_data) | $(m)
	@echo GEN	$@
	@$(m) $(gen_data) $< -o $@

# Shared C sources (ai.c/data.c, font/, c/) + per-arch port//.
# Under K_TEST kmain.c #includes the baked corpus out/lib/ktests.h.
$(k_odir)/%.o: $(R)/%.c $(k_h) $(kdata_h) out/lib/egg.h out/lib/prel.h out/lib/ev.h out/lib/repl.h $(if $(K_TEST),out/lib/ktests.h)
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

$(ko)/$n-$a$(ksuf).iso: $(ko)/$n-$a$(ksuf).elf $(dl)/limine/limine $(ko)/limine.conf
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

$(ko)/$n-$a.hdd: $(ko)/$n-$a.elf $(dl)/limine/limine $(ko)/limine.conf
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
run-$a: $(ko)/$n-$a.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) -cdrom $<
run-hdd-$a: $(ko)/$n-$a.hdd $(dl)/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) -hda $<
run-headless: $(ko)/$n-$a.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
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
out/lib/ktests.$x: $(kt) $(R)/Makefile
	@mkdir -p out/lib
	@cat $(kt) > $@
out/lib/ktests.h: out/lib/ktests.$x $(ai0) tools/lcatv.$x ai/prel.$x
	@echo GEN	$@
	@$(ai0) -l ai/prel.$x tools/lcatv.$x out/lib/ktests.$x > $@
.PHONY: test_kernel
ifeq ($a,x86_64)
test_kernel: host $(R)/tools/ktest.$x
	@$(MAKE) -s K_TEST=1 $(ko)/$n-$a-test.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
	@echo TEST $(ko)/$n-$a-test.iso "(serial, headless)"
	@$m $(R)/tools/ktest.$x $(ko)/$n-$a-test.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
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
	@echo TEST wasm/$n.js "(node)"
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
	cloc --by-file --force-lang=Lisp,$x ai ai.c ai.h data.c data.h kmain.c main.c k.h port tools test vim
cat: clean all test
cata: clean all test_all
# Full clean rebuild, every frontend, all tests, then the corpus under valgrind.
catav: clean all test_all valg

disasm: host
	rizin -A $m
gdb: host
	gdb $m
vmret: host
	@$m tools/vmret.$x $m

bench: host
	$(MAKE) -C bench bench

# --- install / uninstall --------------------------------------------
PREFIX ?= .local/
VIMPREFIX ?= .vim/
DESTDIR ?= $(HOME)/
d = $(DESTDIR)/$(PREFIX)
v = $(DESTDIR)/$(VIMPREFIX)
installs = \
  $d/bin/$n \
  $d/bin/cook \
  $d/share/man/man1/$n.1 \
  $d/lib/$n/prel.$x \
  $d/lib/$n/ev.$x \
  $d/lib/$n/repl.$x \
  $d/lib/lib$n.a \
  $d/lib/lib$n.so \
  $d/include/ai.h \
  $v/ftdetect/$n.vim \
  $v/syntax/$n.vim \
  $v/ftplugin/$n.vim

install: $(installs)
uninstall:
	@echo RM	$(abspath $(installs))
	@rm -f $(installs)

$d/include/ai.h: ai.h
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/$n/%.$x: ai/%.$x
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/lib$n.a: out/host/lib$n.a
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/lib$n.so: out/host/lib$n.so
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

$d/bin/$n: out/host/$n
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

# cook: the build tool (cook/cook.l) installed as an executable `cook` on PATH.
# Its `#!/usr/bin/env -S ai -l` shebang re-execs the installed `ai` to load it,
# then it discovers a Makefile/Cookfile/Cards.l in the cwd. A script, not a
# binary, so no -s strip.
$d/bin/cook: cook/cook.$x
	@echo CP	$(abspath $@)
	@install -D -m 755 $< $@

$d/share/man/man1/$n.1: out/host/$n.1
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$v/ftdetect/$n.vim: vim/ftdetect.vim
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$v/syntax/$n.vim: vim/syntax.vim
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$v/ftplugin/$n.vim: vim/ftplugin.vim
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@
