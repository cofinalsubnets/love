# Project root. This file defines the cross-cutting phony tasks (h, k,
# pd, test, clean, install, ...) and delegates the actual build logic
# to per-subfolder Makefiles (h/, k/, pd/). Each subfolder owns its
# own b/ build directory (and k/ owns dl/ for limine + edk2-ovmf).
# Shared variables live in common.mk.
R := .
include common.mk

.PHONY: all install uninstall clean distclean
.PHONY: host kernel playdate wasm rp2040
.PHONY: test test_host test_js test_all test_gen_vt test_gl0 test_elf2efi test_vmret
.PHONY: valg disasm flame cat cata perf repl gdb vmret
test: test_host
test_all: test_host test_gl0 test_js test_gen_vt
test_gl0: host
	@echo TEST $m0
	@cat $t | host/b/gl0 -l core/prelude.$x -l core/repl.$x
test_js:
	@cd js && npm test
test_host: host
	@echo TEST $m
	@cat $t | $m
# Phase-1 gate: the gwen rewrite tools/gen_data_vt.g must produce byte-identical
# output (the .py/.g generator-name aside) to gen_data_vt.py on every vt.o
# present in a build tree. Run after building the arches you want covered.
test_gen_vt: host
	@echo TEST gen_data_vt.g
	@for o in `find host/b playdate/b kernel/b -name vt.o 2>/dev/null`; do \
	  python3 tools/gen_data_vt.py $$o | sed 's@gen_data_vt\.py@gen_data_vt.g@' > host/b/.vt.py.h; \
	  $m tools/gen_data_vt.g $$o > host/b/.vt.g.h; \
	  cmp -s host/b/.vt.py.h host/b/.vt.g.h && echo "  ok   $$o" \
	    || { echo "  FAIL $$o"; rm -f host/b/.vt.py.h host/b/.vt.g.h; exit 1; }; \
	done; rm -f host/b/.vt.py.h host/b/.vt.g.h
# Phase-4 gate: the gwen rewrite tools/elf2efi.g must produce a byte-identical
# PE32+ image to elf2efi.py for every EFI ELF (riscv64/loongarch64) present in
# the build tree. Run after `make -C kernel EFI=1 a=riscv64` (and a=loongarch64).
test_elf2efi: host
	@echo TEST elf2efi.g
	@for e in `find kernel/b -name '*.efi.elf' 2>/dev/null`; do \
	  python3 tools/elf2efi.py $$e host/b/.efi.py; \
	  $m tools/elf2efi.g $$e host/b/.efi.g; \
	  cmp -s host/b/.efi.py host/b/.efi.g && echo "  ok   $$e" \
	    || { echo "  FAIL $$e"; rm -f host/b/.efi.py host/b/.efi.g; exit 1; }; \
	done; rm -f host/b/.efi.py host/b/.efi.g
# Phase-5 gate: the gwen rewrite tools/vmret.g must produce output identical to
# vmret.py for every ELF it's pointed at -- the host binaries plus any kernel
# arch ELFs present (x86_64/aarch64/riscv64/loongarch64, exercising each arch's
# ret matcher and the llvm-objdump preference). Needs objdump/llvm-objdump.
test_vmret: host
	@echo TEST vmret.g
	@for e in host/b/gl host/b/gl0 `find kernel/b -name 'gl-*.elf' 2>/dev/null`; do \
	  python3 tools/vmret.py $$e > host/b/.vmret.py 2>&1; \
	  $m tools/vmret.g $$e > host/b/.vmret.g 2>&1; \
	  cmp -s host/b/.vmret.py host/b/.vmret.g && echo "  ok   $$e" \
	    || { echo "  FAIL $$e"; diff host/b/.vmret.py host/b/.vmret.g; rm -f host/b/.vmret.py host/b/.vmret.g; exit 1; }; \
	done; rm -f host/b/.vmret.py host/b/.vmret.g
all: host kernel playdate wasm rp2040
host:
	@$(MAKE) -C host
kernel:
	@$(MAKE) -C kernel
playdate:
	@$(MAKE) -C playdate
wasm:
	@$(MAKE) -C wasm
rp2040: rp2040/Makefile
	@$(MAKE) -C rp2040
rp2040/Makefile: rp2040/CMakeLists.txt
	@cd rp2040 && cmake .
clean:
	@$(MAKE) -C host clean
	@$(MAKE) -C kernel clean
	@$(MAKE) -C playdate clean
	@$(MAKE) -C wasm clean
	@[ -e rp2040/Makefile ] && $(MAKE) -C rp2040 clean || true

distclean: clean
	@$(MAKE) -C kernel distclean

# Host artefacts produced by `make -C h`. Declaring them as targets that
# depend on the phony `h` means any other rule that consumes them (the
# install rules, valg, perf, etc.) triggers a single recursive `make -C
# h` rather than failing with "no rule to make target".
$(addprefix host/b/,$n $n.1 lib$n.a lib$n.so): host

.PHONY: valg perf repl cloc cat
valg: host
	cat $t | valgrind --error-exitcode=1 $m
host/b/perf.data: host
	cat $t | perf record -o $@ $m
perf: host/b/perf.data
	perf report -i $<
host/b/flamegraph.svg: host/b/perf.data
	flamegraph -o $@ --perfdata $<
repl: host
	@$m
cloc:
	cloc --by-file --force-lang=Lisp,$x core host js kernel playdate test vim
cat: clean all test
cata: clean all test_all

.PHONY: disasm gdb vmret
disasm: host
	rizin -A $m
gdb: host
	gdb $m
vmret: host
	@$m tools/vmret.g $m

# Pass-throughs for the kernel-specific phonies that need k_qemu etc.
.PHONY: run run-hdd run-headless run-efi run-efi-headless
run run-hdd run-headless run-efi run-efi-headless:
	$(MAKE) -C kernel $@

# Pass-through for the playdate simulator.
.PHONY: sim
sim:
	$(MAKE) -C playdate sim

# --- install / uninstall --------------------------------------------
PREFIX ?= .local/
VIMPREFIX ?= .vim/
DESTDIR ?= $(HOME)/
d = $(DESTDIR)/$(PREFIX)
v = $(DESTDIR)/$(VIMPREFIX)
installs = \
  $d/bin/$n \
  $d/share/man/man1/$n.1 \
  $d/lib/$n/prelude.$x \
  $d/lib/$n/ev.$x \
  $d/lib/$n/repl.$x \
  $d/lib/lib$n.a \
  $d/lib/lib$n.so \
  $d/include/$x.h \
  $v/ftdetect/$n.vim \
  $v/syntax/$n.vim \
  $v/ftplugin/$n.vim

.PHONY: install uninstall
install: $(installs)
uninstall:
	@echo RM	$(abspath $(installs))
	@rm -f $(installs)

$d/include/$x.h: core/$x.h
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/$n/%.$x: core/%.$x
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/lib$n.a: host/b/lib$n.a
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/lib$n.so: host/b/lib$n.so
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

$d/bin/$n: host/b/$n
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

$d/g/man/man1/$n.1: host/b/$n.1
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
