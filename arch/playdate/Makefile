# Playdate build. Run from project root via `make playdate`, or directly via
# `cd playdate && make`. Outputs land in $(R)/out/playdate/. Requires
# PLAYDATE_SDK_PATH in the environment.
R := ../..
include $(R)/common.mk

# This frontend's build output directory under the top-level out/.
o = $(R)/out/playdate

pd_sdk = $(PLAYDATE_SDK_PATH)
# ccache wraps the compiler when available; override with `make CCACHE=` to
# disable, or point CCACHE at a different launcher.
CCACHE ?= $(shell command -v ccache 2>/dev/null)
pd_gcc = $(CCACHE) arm-none-eabi-gcc
pd_cc = $(pd_gcc) -g3
pd_as = $(pd_gcc) -x assembler-with-cpp
pd_opt = -Os -falign-functions=16 -fomit-frame-pointer
pd_fpu = -mfloat-abi=hard -mfpu=fpv5-sp-d16 -D__FPU_USED=1
pd_incdir = $(patsubst %,-I %, . $(pd_sdk)/C_API $(R) $(R)/out/host $(R)/font)
pd_defs = -DTARGET_PLAYDATE=1 -DTARGET_EXTENSION=1 -Dg_tco=0

# Sources split by group so the obj-path patsubst works cleanly:
# local pd/*.c stay rooted in cwd, shared kernel/*.c + font/*.c + libc/*.c carry
# the $(R)/ prefix, and the SDK helper has an absolute path we map by hand.
pd_local_c = $(wildcard *.c)
pd_shared_c = $(g_c) $(f_c) $R/libc/str.c
pd_sdk_c = $(pd_sdk)/C_API/buildsupport/setup.c
pd_src = $(pd_local_c) $(pd_shared_c) $(pd_sdk_c)

pd_local_o = $(pd_local_c:%.c=$(o)/%.o)
pd_shared_o = $(pd_shared_c:$(R)/%.c=$(o)/%.o)
pd_sdk_o = $(o)/setup.o
pd_o = $(pd_local_o) $(pd_shared_o) $(pd_sdk_o)

# $(o)/data.h is reflected out of the device data.o (kernel/data.c, Thumb): the
# 24-byte sentinel body is 16-aligned, so the real stride is 32 and g_typ()
# shifts by 5 instead of doing the portable header's two link-time divides.
# Every device object below carries -I$(o) (ahead of pd_incdir's -I../kernel) so
# it shadows kernel/data.h, and depends on $(data_h) -- except data.o, which builds
# without -I$(o) and bootstraps from the portable header (it never calls g_typ).
# The simulator .so (host x86_64, dev-only) is a single-shot compile with no
# intermediate data.o, so it stays on the portable header.
data_h = $(o)/data.h
# Run through the host interpreter $m (= $(R)/out/host/ll), built on demand below.
# py/gen_data.py is the cross-checked reference (make test_tools).
gen_data = $(R)/tools/gen_data.$x

pd_mcflags = -mthumb -mcpu=cortex-m7 $(pd_fpu)
pd_cpflags = \
  $(pd_mcflags) $(pd_opt) $(pd_defs) \
  -gdwarf-2 -Wall -Wno-unused -Wstrict-prototypes -Wno-unknown-pragmas \
  -fverbose-asm -Wdouble-promotion -mword-relocations -fno-common \
  -ffunction-sections -fdata-sections -Wa,-ahlms=$(o)/$(notdir $(<:.c=.lst))
# ll_pd.lds is the SDK link_map.ld plus the data self-quote sentinel
# block inlined into .text (see that file); used in its place because the
# stock SDK script orphans the sentinels and leaves __start_/__stop_ undefined.
pd_lds = ll_pd.lds
pd_ldflags = \
  -nostartfiles $(pd_mcflags) -T$(pd_lds) \
  -Wl,-Map=$(o)/pdex.map,--cref,--gc-sections,--no-warn-mismatch,--emit-relocs
pd_asflags = $(pd_mcflags) $(pd_opt) -g3 -gdwarf-2 -Wa,-amhls=$(<:.s=.lst) \
  -D__HEAP_SIZE=8388208 \
  -D__STACK_SIZE=4194304

.PHONY: default sim clean
default: $(o)/$n.pdx

sim: $(o)/$n.pdx
	@$(pd_sdk)/bin/PlaydateSimulator $^

clean:
	rm -rf $(o)

# A lib header (and the host ll, which runs gen_data.l) stand in for "the
# host build ran"; built on demand here so a standalone `make -C playdate` works.
# (playdate/main.c embeds no prelude -- this is just a build-order sentinel.)
$(R)/out/lib/prelude.h:
	@$(MAKE) -C $(R) out/lib/prelude.h
$(m):
	@$(MAKE) -C $(R)/host

$(o)/$n.pdx: $(o)/Source/pdex.elf $(o)/Source/pdex.so
	@echo PDC	$@
	@$(pd_sdk)/bin/pdc -sdkpath $(pd_sdk) $(o)/Source $@

$(o)/Source/pdex.%: $(o)/pdex.%
	@echo CP	$@
	@mkdir -p $(dir $@)
	@cp $< $@

# The data-sentinel TU bootstraps from the portable header (no -I$(o), no $(data_h)
# prerequisite -- both would be circular, since $(o)/data.h is reflected out of
# this object). Its explicit recipe overrides the pattern rules below.
$(o)/data.o: $(R)/data.c | $(R)/out/lib/prelude.h
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) -c $(pd_cpflags) -I. -I$(R)/out/host -I$(R)/font $(pd_incdir) $< -o $@

$(o)/data.h: $(o)/data.o $(gen_data) | $(m)
	@echo GEN	$@
	@$(m) $(gen_data) $< -o $@

# Local pd/*.c sources (e.g. playdate/main.c). Listed BEFORE the shared
# $(R)/%.c rule so a local source wins the object-name race against a
# same-named top-level file: top-level main.c is the host frontend, which
# must not be compiled here (it pulls in POSIX headers like <termios.h>).
# Shared sources fall through to the $(R) rule (no local ll.c/data.c exist).
$(o)/%.o: %.c $(data_h) | $(R)/out/lib/prelude.h
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) -c $(pd_cpflags) -I$(o) -I. -I$(R)/out/host -I$(R)/font $(pd_incdir) $< -o $@

# Shared C sources from ll.c/data.c and font/.
$(o)/%.o: $(R)/%.c $(data_h) | $(R)/out/lib/prelude.h
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) -c $(pd_cpflags) -I$(o) -I. -I$(R)/out/host -I$(R)/font $(pd_incdir) $< -o $@

# Local pd/*.s assembly (rule preserved from original; no .s files exist
# today but keep the pattern in case one shows up).
$(o)/%.o: %.s
	@echo AS	$@
	@mkdir -p $(dir $@)
	@$(pd_as) -c $(pd_asflags) $< -o $@

# SDK setup.c is reached via an absolute path; an explicit rule keeps
# its output filename predictable.
$(o)/setup.o: $(pd_sdk)/C_API/buildsupport/setup.c $(data_h) | $(R)/out/lib/prelude.h
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) -c $(pd_cpflags) -I$(o) -I. -I$(R)/out/host -I$(R)/font $(pd_incdir) $< -o $@

$(o)/pdex.elf: $(pd_o) $(pd_lds)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) $(pd_o) $(pd_ldflags) -o $@

# The simulator .so is a host (x86_64) shared object loaded via dlopen, so it
# needs the data self-quote sentinels pinned too. It's an ordinary host link
# with no full -T script of its own, so the host INSERT-after-.text fragment
# (kernel/data.ld) augments the default script exactly as it does for host/.
pd_host_data_lds = $(R)/data.ld
$(o)/pdex.so: $(pd_src) $(pd_host_data_lds)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(CCACHE) gcc -g -shared -fPIC -Wl,-T,$(pd_host_data_lds) -lm -Dg_tco=0 -DTARGET_SIMULATOR=1 -DTARGET_EXTENSION=1 $(pd_incdir) -o $(o)/pdex.so $(pd_src)

.PRECIOUS: $(o)/%elf
