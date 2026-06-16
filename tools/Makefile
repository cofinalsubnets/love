# Validation gates for the love rewrites of the old Python build tools.
#
# Each love tool in this directory (gen_data.l, vmret.l) must
# produce output identical to the frozen Python reference under py/ (see
# py/README.md). These targets diff the two over every relevant build artifact
# present in the tree -- so they only check what you've actually built. Run all
# of them with `make test_tools` from the repo root, or `make -C tools` here.
#
# Needs: python3 (the references), and objdump/llvm-objdump for vmret.

R := ..
include $(R)/common.mk

.PHONY: all test_gen_data test_vmret test_cook
all: test_gen_data test_vmret test_cook

# Build the host love on demand (it runs the .l tools); only if it's missing.
$(m):
	@$(MAKE) -C $(R)/host

# gen_data.l vs py/gen_data.py over every data.o in a build tree (host,
# the kernel arches). The sed folds the .py's generator-name
# token in the header comment to the .g's so only the reflected stride is
# compared.
test_gen_data: | $(m)
	@echo TEST gen_data.l
	@for o in `find $(R)/out/host $(R)/out/free -name data.o 2>/dev/null`; do \
	  python3 $(R)/tools/py/gen_data.py $$o | sed 's@gen_data\.py@gen_data.l@' > $(R)/out/host/.data.py.h; \
	  $(m) $(R)/tools/gen_data.$x $$o > $(R)/out/host/.data.l.h; \
	  cmp -s $(R)/out/host/.data.py.h $(R)/out/host/.data.l.h && echo "  ok   $$o" \
	    || { echo "  FAIL $$o"; rm -f $(R)/out/host/.data.py.h $(R)/out/host/.data.l.h; exit 1; }; \
	done; rm -f $(R)/out/host/.data.py.h $(R)/out/host/.data.l.h

# vmret.l vs py/vmret.py over the host binary plus any kernel arch ELFs
# present (each arch exercises a different ret matcher + the objdump choice).
# ai0 is skipped: it builds -Dai_tco=0 (trampoline), where handler rets are
# expected -- the vmret signal is noise there.
test_vmret: | $(m)
	@echo TEST vmret.l
	@for e in $(R)/out/host/love `find $(R)/out/free -name 'love-*.elf' 2>/dev/null`; do \
	  python3 $(R)/tools/py/vmret.py $$e > $(R)/out/host/.vmret.py 2>&1; \
	  $(m) $(R)/tools/vmret.$x $$e > $(R)/out/host/.vmret.l 2>&1; \
	  cmp -s $(R)/out/host/.vmret.py $(R)/out/host/.vmret.l && echo "  ok   $$e" \
	    || { echo "  FAIL $$e"; diff $(R)/out/host/.vmret.py $(R)/out/host/.vmret.l; rm -f $(R)/out/host/.vmret.py $(R)/out/host/.vmret.l; exit 1; }; \
	done; rm -f $(R)/out/host/.vmret.py $(R)/out/host/.vmret.l


# cook.l: run its Makefile-importer test suite. cooktest.l writes fixture
# Makefiles to a temp dir and runs cook on them as a subprocess, asserting over
# the captured output (variable expansion, the make functions, conditionals,
# include, pattern + static-pattern rules). It uses paths relative to the repo
# root, so run it from there.
test_cook: | $(m)
	@echo TEST cook.l
	@cd $(R) && out/host/$n tools/cooktest.$x
