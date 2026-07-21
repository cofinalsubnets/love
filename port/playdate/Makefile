# Playdate build. Run from the project root via `make -C port/playdate`, or
# directly via `cd port/playdate && make`. Output lands in $(R)/out/playdate/
# ($n.pdx at the top). Requires PLAYDATE_SDK_PATH (pdc + C_API + simulator)
# and arm-none-eabi-gcc for the device half; the simulator pdex.so is an
# ordinary host gcc shared object, so `make sim` runs with no cross tools.
#
# Both halves bake the same program: the egg bootstrap (out/lib lcat headers,
# delegated to the root), crew/rune/ as a registered module, and cas.l (this
# folder, lcat'd locally) driving the workbench. See main.c.
R := ../..
include $(R)/common.mk

o = $(R)/out/playdate
n = love
pd_sdk = $(PLAYDATE_SDK_PATH)
CCACHE ?= $(shell command -v ccache 2>/dev/null)
pd_cc = $(CCACHE) arm-none-eabi-gcc -g3
pd_opt = -Os -falign-functions=16 -fomit-frame-pointer
# the device M7's FPU is single-precision; gem (double) arithmetic rides the
# libgcc soft helpers, which the SDK link script GROUPs in.
pd_fpu = -mfloat-abi=hard -mfpu=fpv5-sp-d16 -D__FPU_USED=1
pd_mcflags = -mthumb -mcpu=cortex-m7 $(pd_fpu)
pd_incdir = -I. -I$(o) -I$(R) -I$(R)/out/lib -I$(R)/port/quay -I$(pd_sdk)/C_API
pd_defs = -DTARGET_PLAYDATE=1 -DTARGET_EXTENSION=1 -Dai_tco=0
# -ffreestanding keeps love.c off the hosted-only lanes (the W^X mmap arena);
# newlib's headers + libc.a still supply mem/str at compile and link.
pd_cpflags = $(pd_mcflags) $(pd_opt) $(pd_defs) -std=gnu2x -ffreestanding \
  -gdwarf-2 -Wall -Wno-unused -Wstrict-prototypes -Wno-unknown-pragmas \
  -Wdouble-promotion -mword-relocations -fno-common \
  -ffunction-sections -fdata-sections $(pd_incdir)
pd_lds = $(pd_sdk)/C_API/buildsupport/link_map.ld
pd_ldflags = -nostartfiles $(pd_mcflags) -T$(pd_lds) \
  -Wl,-Map=$(o)/pdex.map,--cref,--gc-sections,--no-warn-mismatch,--emit-relocs

# the lcat lib headers this frontend bakes (produced by the root's rules on
# love0, delegated below so a standalone make works from a clean tree)
lib_hs = $(patsubst %,$(R)/out/lib/%.h,egg prel ev rune runeseal)
pd_h = $(love_h) $(wildcard $(R)/port/quay/*.h) $(o)/cas.h $(lib_hs)

# local main.c stays rooted in cwd (and wins the object-name race against the
# top-level host main.c); the shared runtime (love.c + am.c) and quay carry
# the $(R)/ prefix; the SDK helper has an absolute path we map by hand.
pd_local_c = $(wildcard *.c)
pd_shared_c = $(love_c) $(f_c)
pd_sdk_c = $(pd_sdk)/C_API/buildsupport/setup.c
pd_src = $(pd_local_c) $(pd_shared_c) $(pd_sdk_c)
pd_local_o = $(pd_local_c:%.c=$(o)/%.o)
pd_shared_o = $(pd_shared_c:$(R)/%.c=$(o)/%.o)
pd_o = $(pd_local_o) $(pd_shared_o) $(o)/setup.o

.PHONY: default sim clean
default: $(o)/$n.pdx

sim: $(o)/$n.pdx
	@$(pd_sdk)/bin/PlaydateSimulator $^

clean:
	rm -rf $(o)

# delegate the lib headers and the host binary (which lcats cas.l) to the root
$(lib_hs):
	@$(MAKE) -C $(R) out/lib/$(@F)
$(m):
	@$(MAKE) -C $(R) out/host/love

# cas.l -> C string literal, atomically (a 0-byte header would silently drop
# the whole demo -- same discipline as the root's lcat_h)
$(o)/cas.h: cas.l $(R)/tools/lcat.l | $(m)
	@echo LOVE	$@
	@mkdir -p $(o)
	@$(m) $(R)/tools/lcat.l cas.l > $@.tmp && test -s $@.tmp && mv -f $@.tmp $@ \
	  || { rm -f $@.tmp; echo "FAIL: $@ empty"; exit 1; }

$(o)/$n.pdx: $(o)/Source/pdex.elf $(o)/Source/pdex.so
	@echo PDC	$@
	@$(pd_sdk)/bin/pdc -sdkpath $(pd_sdk) $(o)/Source $@

$(o)/Source/pdex.%: $(o)/pdex.%
	@echo CP	$@
	@mkdir -p $(dir $@)
	@cp $< $@

# local sources (listed before the shared rule so this main.c wins)
$(o)/%.o: %.c $(pd_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) -c $(pd_cpflags) $< -o $@
# shared runtime + quay
$(o)/%.o: $(R)/%.c $(pd_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) -c $(pd_cpflags) $< -o $@
# the SDK setup helper (absolute path, so an explicit rule)
$(o)/setup.o: $(pd_sdk)/C_API/buildsupport/setup.c $(pd_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) -c $(pd_cpflags) $< -o $@

$(o)/pdex.elf: $(pd_o)
	@echo LD	$@
	@$(pd_cc) $(pd_o) $(pd_ldflags) -o $@

# the simulator .so: a single-shot hosted build of the same sources
$(o)/pdex.so: $(pd_src) $(o)/cas.h
	@echo CC	$@
	@mkdir -p $(o)
	@$(CCACHE) gcc -g -O1 -shared -fPIC -Dai_tco=0 -DTARGET_SIMULATOR=1 -DTARGET_EXTENSION=1 \
	  -I. -I$(o) -I$(R) -I$(R)/out/lib -I$(R)/port/quay -I$(pd_sdk)/C_API \
	  -o $@ $(pd_src) -lm

.PRECIOUS: $(o)/%.elf
