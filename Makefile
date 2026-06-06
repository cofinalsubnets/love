# Project root. This file defines the cross-cutting phony tasks (host,
# kernel, playdate, test, clean, install, ...) and delegates the actual
# build logic to per-subfolder Makefiles (host/, free/, playdate/). Build
# output lands under the top-level b/ (b/host, b/free, b/dl, ...); free/
# downloads limine + edk2-ovmf into b/dl. Shared variables live in common.mk.
R := .
include common.mk

.PHONY: all install uninstall clean distclean
.PHONY: host kernel playdate wasm rp2040
.PHONY: test test_host test_js test_all test_tools test_gl0
.PHONY: valg disasm flame cat cata catav perf repl gdb vmret
test: test_host
test_all: test_host test_gl0 test_js test_tools
test_gl0: host
	@echo TEST $m0
	@cat $t | b/host/gl0 -l lib/prelude.$x -l lib/repl.$x
test_js:
	@cd js && npm test
test_host: host
	@echo TEST $m
	@cat $t | $m
# Validate the gwen tool rewrites against their frozen Python references in
# tools/py/ (gen_data_vt / elf2efi / vmret). See tools/Makefile + tools/py/README.md.
test_tools: host
	@$(MAKE) -C tools
all: host kernel playdate wasm rp2040
host: lib
	@$(MAKE) -C host

# Static lisp headers: each lib/*.g is serialized to a C string literal in
# b/lib/*.h by tools/lcat.g (run on the bootstrap interpreter gl0). Frontends
# #include these and assemble the bootstrap with G_EGG_PRE/POST (kernel/g.h).
# Drop a .g into lib/ and it is picked up automatically -- no rule to edit.
lib_h = $(patsubst lib/%.$x,b/lib/%.h,$(wildcard lib/*.$x))
.PHONY: lib
lib: $(lib_h)
$(lib_h): b/lib/%.h: lib/%.$x b/host/gl0 tools/lcat.$x
	@mkdir -p b/lib
	@echo GEN	$@
	@b/host/gl0 -l lib/prelude.$x tools/lcat.$x $< > $@
# gl0 (the prelude-less bootstrap interpreter that runs lcat) is a host subbuild.
b/host/gl0:
	@$(MAKE) -C host gl0
kernel:
	@$(MAKE) -C free
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
	@$(MAKE) -C free clean
	@$(MAKE) -C playdate clean
	@$(MAKE) -C wasm clean
	@[ -e rp2040/Makefile ] && $(MAKE) -C rp2040 clean || true

distclean: clean
	@$(MAKE) -C free distclean

# Host artefacts produced by `make -C host`. Declaring them as targets that
# depend on the phony `host` means any other rule that consumes them (the
# install rules, valg, perf, etc.) triggers a single recursive `make -C
# host` rather than failing with "no rule to make target".
$(addprefix b/host/,$n $n.1 lib$n.a lib$n.so): host

.PHONY: valg perf repl cloc cat
valg: host
	cat $t | valgrind --error-exitcode=1 --suppressions=$R/tools/valgrind.supp $m
b/host/perf.data: host
	cat $t | perf record -o $@ $m
perf: b/host/perf.data
	perf report -i $<
b/host/flamegraph.svg: b/host/perf.data
	flamegraph -o $@ --perfdata $<
repl: host
	@$m
cloc:
	cloc --by-file --force-lang=Lisp,$x lib kernel free host js x86_64 aarch64 riscv64 loongarch64 playdate test vim
cat: clean all test
cata: clean all test_all
# Full clean rebuild, every frontend, all tests, then the test corpus under
# valgrind. The most thorough single check before a commit.
catav: clean all test_all valg

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
	$(MAKE) -C free $@

# Pass-through for the playdate simulator.
.PHONY: sim
sim:
	$(MAKE) -C playdate sim

# Pass-through for the benchmark harness (gwen vs python/ruby; see bench/).
.PHONY: bench
bench: host
	$(MAKE) -C bench

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

$d/include/$x.h: kernel/$x.h
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/$n/%.$x: lib/%.$x
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/lib$n.a: b/host/lib$n.a
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/lib$n.so: b/host/lib$n.so
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

$d/bin/$n: b/host/$n
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

$d/g/man/man1/$n.1: b/host/$n.1
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
