# Validation gates for the gwen rewrites of the old Python build tools.
#
# Each gwen tool in this directory (gen_data_vt.g, elf2efi.g, vmret.g) must
# produce output identical to the frozen Python reference under py/ (see
# py/README.md). These targets diff the two over every relevant build artifact
# present in the tree -- so they only check what you've actually built. Run all
# of them with `make test_tools` from the repo root, or `make -C tools` here.
#
# Needs: python3 (the references), and objdump/llvm-objdump for vmret.

R := ..
include $(R)/common.mk

.PHONY: all test_gen_vt test_elf2efi test_vmret
all: test_gen_vt test_elf2efi test_vmret

# Build the host gl on demand (it runs the .g tools); only if it's missing.
$(m):
	@$(MAKE) -C $(R)/host

# gen_data_vt.g vs py/gen_data_vt.py over every vt.o in a build tree (host,
# playdate ELF32, the kernel arches). The sed folds the .py's generator-name
# token in the header comment to the .g's so only the reflected stride is
# compared.
test_gen_vt: | $(m)
	@echo TEST gen_data_vt.g
	@for o in `find $(R)/out/host $(R)/out/playdate $(R)/out/free -name vt.o 2>/dev/null`; do \
	  python3 $(R)/tools/py/gen_data_vt.py $$o | sed 's@gen_data_vt\.py@gen_data_vt.g@' > $(R)/out/host/.vt.py.h; \
	  $(m) $(R)/tools/gen_data_vt.$x $$o > $(R)/out/host/.vt.g.h; \
	  cmp -s $(R)/out/host/.vt.py.h $(R)/out/host/.vt.g.h && echo "  ok   $$o" \
	    || { echo "  FAIL $$o"; rm -f $(R)/out/host/.vt.py.h $(R)/out/host/.vt.g.h; exit 1; }; \
	done; rm -f $(R)/out/host/.vt.py.h $(R)/out/host/.vt.g.h

# elf2efi.g vs py/elf2efi.py over every EFI ELF present (riscv64/loongarch64).
# Build them first with `make -C free EFI=1 a=riscv64` (and a=loongarch64).
test_elf2efi: | $(m)
	@echo TEST elf2efi.g
	@for e in `find $(R)/out/free -name '*.efi.elf' 2>/dev/null`; do \
	  python3 $(R)/tools/py/elf2efi.py $$e $(R)/out/host/.efi.py; \
	  $(m) $(R)/tools/elf2efi.$x $$e $(R)/out/host/.efi.g; \
	  cmp -s $(R)/out/host/.efi.py $(R)/out/host/.efi.g && echo "  ok   $$e" \
	    || { echo "  FAIL $$e"; rm -f $(R)/out/host/.efi.py $(R)/out/host/.efi.g; exit 1; }; \
	done; rm -f $(R)/out/host/.efi.py $(R)/out/host/.efi.g

# vmret.g vs py/vmret.py over the host binaries plus any kernel arch ELFs
# present (each arch exercises a different ret matcher + the objdump choice).
test_vmret: | $(m)
	@echo TEST vmret.g
	@for e in $(R)/out/host/gl $(R)/out/host/gl0 `find $(R)/out/free -name 'gl-*.elf' 2>/dev/null`; do \
	  python3 $(R)/tools/py/vmret.py $$e > $(R)/out/host/.vmret.py 2>&1; \
	  $(m) $(R)/tools/vmret.$x $$e > $(R)/out/host/.vmret.g 2>&1; \
	  cmp -s $(R)/out/host/.vmret.py $(R)/out/host/.vmret.g && echo "  ok   $$e" \
	    || { echo "  FAIL $$e"; diff $(R)/out/host/.vmret.py $(R)/out/host/.vmret.g; rm -f $(R)/out/host/.vmret.py $(R)/out/host/.vmret.g; exit 1; }; \
	done; rm -f $(R)/out/host/.vmret.py $(R)/out/host/.vmret.g
