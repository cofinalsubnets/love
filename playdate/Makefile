# Playdate build. Run from project root via `make pd`, or directly via
# `cd pd && make`. Outputs land in b/ under this cwd. Requires
# PLAYDATE_SDK_PATH in the environment.
R := ..
include $(R)/common.mk

pd_sdk = $(PLAYDATE_SDK_PATH)
# ccache wraps the compiler when available; override with `make CCACHE=` to
# disable, or point CCACHE at a different launcher.
CCACHE ?= $(shell command -v ccache 2>/dev/null)
pd_gcc = $(CCACHE) arm-none-eabi-gcc
pd_cc = $(pd_gcc) -g3
pd_as = $(pd_gcc) -x assembler-with-cpp
pd_opt = -O2 -falign-functions=16 -fomit-frame-pointer
pd_fpu = -mfloat-abi=hard -mfpu=fpv5-sp-d16 -D__FPU_USED=1
pd_incdir = $(patsubst %,-I %, . $(pd_sdk)/C_API $(R)/core $(R)/host/b $(R)/font)
pd_defs = -DTARGET_PLAYDATE=1 -DTARGET_EXTENSION=1 -Dg_tco=0

# Sources split by group so the obj-path patsubst works cleanly:
# local pd/*.c stay rooted in cwd, shared g/*.c + f/*.c + libc/*.c carry
# the $(R)/ prefix, and the SDK helper has an absolute path we map by hand.
pd_local_c = $(wildcard *.c)
pd_shared_c = $(g_c) $(f_c) $R/libc/str.c
pd_sdk_c = $(pd_sdk)/C_API/buildsupport/setup.c
pd_src = $(pd_local_c) $(pd_shared_c) $(pd_sdk_c)

pd_local_o = $(pd_local_c:%.c=b/%.o)
pd_shared_o = $(pd_shared_c:$(R)/%.c=b/%.o)
pd_sdk_o = b/setup.o
pd_o = $(pd_local_o) $(pd_shared_o) $(pd_sdk_o)

# b/vt.h is reflected out of the device vt.o (core/vt.c, Thumb): the
# 24-byte sentinel body is 16-aligned, so the real stride is 32 and g_typ()
# shifts by 5 instead of doing the portable header's two link-time divides.
# Every device object below carries -Ib (ahead of pd_incdir's -I../core) so it
# shadows core/vt.h, and depends on $(vt_h) -- except vt.o, which builds
# without -Ib and bootstraps from the portable header (it never calls g_typ).
# The simulator .so (host x86_64, dev-only) is a single-shot compile with no
# intermediate vt.o, so it stays on the portable header.
vt_h = b/vt.h
gen_vt = $(R)/tools/gen_data_vt.py

pd_mcflags = -mthumb -mcpu=cortex-m7 $(pd_fpu)
pd_cpflags = \
  $(pd_mcflags) $(pd_opt) $(pd_defs) \
  -gdwarf-2 -Wall -Wno-unused -Wstrict-prototypes -Wno-unknown-pragmas \
  -fverbose-asm -Wdouble-promotion -mword-relocations -fno-common \
  -ffunction-sections -fdata-sections -Wa,-ahlms=b/$(notdir $(<:.c=.lst))
# gwen_pd.lds is the SDK link_map.ld plus the data self-quote sentinel
# block inlined into .text (see that file); used in its place because the
# stock SDK script orphans the sentinels and leaves __start_/__stop_ undefined.
pd_lds = gwen_pd.lds
pd_ldflags = \
  -nostartfiles $(pd_mcflags) -T$(pd_lds) \
  -Wl,-Map=b/pdex.map,--cref,--gc-sections,--no-warn-mismatch,--emit-relocs
pd_asflags = $(pd_mcflags) $(pd_opt) -g3 -gdwarf-2 -Wa,-amhls=$(<:.s=.lst) \
  -D__HEAP_SIZE=8388208 \
  -D__STACK_SIZE=4194304

.PHONY: default sim clean
default: b/$n.pdx

sim: b/$n.pdx
	@$(pd_sdk)/bin/PlaydateSimulator $^

clean:
	rm -rf b

# boot.h is owned by the host build.
$(R)/host/b/boot.h:
	@$(MAKE) -C $(R)/host b/boot.h

b/$n.pdx: b/Source/pdex.elf b/Source/pdex.so
	@echo PDC	$@
	@$(pd_sdk)/bin/pdc -sdkpath $(pd_sdk) b/Source $@

b/Source/pdex.%: b/pdex.%
	@echo CP	$@
	@mkdir -p $(dir $@)
	@cp $< $@

# The data-sentinel TU bootstraps from the portable header (no -Ib, no $(vt_h)
# prerequisite -- both would be circular, since b/vt.h is reflected out of
# this object). Its explicit recipe overrides the pattern rules below.
b/core/vt.o: $(R)/core/vt.c | $(R)/host/b/boot.h
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) -c $(pd_cpflags) -I. -I$(R)/host/b -I$(R)/f $(pd_incdir) $< -o $@

b/vt.h: b/core/vt.o $(gen_vt)
	@echo GEN	$@
	@$(gen_vt) $< -o $@

# Shared C sources from g/ and f/.
b/%.o: $(R)/%.c $(vt_h) | $(R)/host/b/boot.h
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) -c $(pd_cpflags) -Ib -I. -I$(R)/host/b -I$(R)/f $(pd_incdir) $< -o $@

# Local pd/*.c sources.
b/%.o: %.c $(vt_h) | $(R)/host/b/boot.h
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) -c $(pd_cpflags) -Ib -I. -I$(R)/host/b -I$(R)/f $(pd_incdir) $< -o $@

# Local pd/*.s assembly (rule preserved from original; no .s files exist
# today but keep the pattern in case one shows up).
b/%.o: %.s
	@echo AS	$@
	@mkdir -p $(dir $@)
	@$(pd_as) -c $(pd_asflags) $< -o $@

# SDK setup.c is reached via an absolute path; an explicit rule keeps
# its output filename predictable.
b/setup.o: $(pd_sdk)/C_API/buildsupport/setup.c $(vt_h) | $(R)/host/b/boot.h
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) -c $(pd_cpflags) -Ib -I. -I$(R)/host/b -I$(R)/f $(pd_incdir) $< -o $@

b/pdex.elf: $(pd_o) $(pd_lds)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) $(pd_o) $(pd_ldflags) -o $@

# The simulator .so is a host (x86_64) shared object loaded via dlopen, so it
# needs the data self-quote sentinels pinned too. It's an ordinary host link
# with no full -T script of its own, so the host INSERT-after-.text fragment
# (core/vt.ld) augments the default script exactly as it does for host/.
pd_host_vt_lds = $(R)/core/vt.ld
b/pdex.so: $(pd_src) $(pd_host_vt_lds)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(CCACHE) gcc -g -shared -fPIC -Wl,-T,$(pd_host_vt_lds) -lm -Dg_tco=0 -DTARGET_SIMULATOR=1 -DTARGET_EXTENSION=1 $(pd_incdir) -o b/pdex.so $(pd_src)

.PRECIOUS: b/%elf
