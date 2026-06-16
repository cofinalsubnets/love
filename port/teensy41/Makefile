# Teensy 4.1 (i.MX RT1062) build. Run from the project root via `make -C
# ports/teensy41`, or directly via `cd ports/teensy41 && make`. Standalone:
# it touches no file in the main tree -- it points R at a love checkout, pulls
# the shared vars from common.mk, and delegates the host interpreter + lcat lib
# headers back to the root Makefile on demand. Output lands in $(R)/out/teensy41/.
#
# Freestanding thumbv7em build of the love runtime + the arch backend here,
# booting XIP from the 8 MB FlexSPI NOR behind the FlexSPI config block + IVT
# (teensy41.c) and packed into a .hex for teensy_loader_cli / the Teensy Loader
# GUI. Mirrors the kernel + rp2040 builds: per-target data.h reflected out of
# this target's data.o, the lcat lib headers shared from out/lib. The M7 has a
# double-precision FPU, so this build is hard-float (-mfpu=fpv5-d16); the
# compiler-rt / libgcc archive (te_rt) supplies the 64-bit / soft-helper
# __aeabi_* libcalls.
R := ../..
include $(R)/common.mk

KCC ?= clang
o = $(R)/out/teensy41
gen_data = $(R)/tools/gen_data.$x

te_triple = -target thumbv7em-none-eabi -mcpu=cortex-m7 -mthumb
te_fpu = -mfloat-abi=hard -mfpu=fpv5-d16
te_cppflags = -I$(o) -I. -I$(R) -I$(R)/out/lib -I$(R)/libc
te_cc = $(CCACHE) $(KCC) $(te_triple) $(te_fpu) $(g_cflags) -nostdinc -ffreestanding \
  -fno-lto -fno-PIC -ffunction-sections -fdata-sections -Dai_tco=0 $(te_cppflags)
te_rt := $(shell f=$$($(KCC) $(te_triple) $(te_fpu) -print-libgcc-file-name 2>/dev/null); \
  [ -e "$$f" ] && echo "$$f" || \
  arm-none-eabi-gcc -mcpu=cortex-m7 -mthumb $(te_fpu) -print-libgcc-file-name 2>/dev/null)

te_h = $(g_h) $(wildcard *.h)
data_h = $(o)/data.h
lib_h = $(R)/out/lib/egg.h $(R)/out/lib/prel.h $(R)/out/lib/ev.h $(R)/out/lib/repl.h

# Local arch sources (teensy41.c, main.c) stay rooted in cwd; the shared runtime
# (ai.c, data.c, libc/) carries the $(R)/ prefix. Local rule is listed first
# so this main.c wins the object-name race against the top-level host main.c.
te_local_c = $(wildcard *.c)
te_shared_c = $(g_c) $(c_c)
te_local_o = $(te_local_c:%.c=$(o)/%.o)
te_shared_o = $(te_shared_c:$(R)/%.c=$(o)/%.o)
te_o = $(te_local_o) $(te_shared_o)

OBJCOPY ?= $(shell command -v llvm-objcopy 2>/dev/null || echo arm-none-eabi-objcopy)

.PHONY: teensy41 flash clean
teensy41: $(o)/$n.hex
default: teensy41

clean:
	rm -rf $(o)

# Delegate to the root: the host interpreter $m runs gen_data.l, and the lcat
# lib headers are produced by the root's own rules. Built on demand so a
# standalone `make -C ports/teensy41` works from a clean tree.
$(lib_h):
	@$(MAKE) -C $(R) out/lib/$(@F)
$(m):
	@$(MAKE) -C $(R) host

# data.o bootstraps from the portable top-level data.h (no data_h prereq -- it
# is circular); its sentinel stride is then reflected into the generated data.h,
# which -I$(o) puts ahead of the portable one. Explicit rule shadows the
# pattern rules below for data.o.
$(o)/data.o: $(R)/data.c $(te_h) $(lib_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(te_cc) -c $< -o $@
$(data_h): $(o)/data.o $(gen_data) | $(m)
	@echo GEN	$@
	@$(m) $(gen_data) $< -o $@

# Local arch sources (listed before the shared rule, see above).
$(o)/%.o: %.c $(te_h) $(data_h) $(lib_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(te_cc) -c $< -o $@
# Shared runtime + libc.
$(o)/%.o: $(R)/%.c $(te_h) $(data_h) $(lib_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(te_cc) -c $< -o $@

$(o)/$n.elf: $(te_o) teensy41.lds
	@echo LD	$@
	@$(KCC) $(te_triple) $(te_fpu) -nostdlib -fuse-ld=lld -Wl,--gc-sections \
	  -Wl,-T,teensy41.lds $(te_o) $(te_rt) -o $@

# .hex (Intel HEX) is what teensy_loader_cli / the Teensy Loader GUI flash.
$(o)/$n.hex: $(o)/$n.elf
	@echo HEX	$@
	@$(OBJCOPY) -O ihex -R .eh_frame $< $@

# Flash a connected Teensy 4.1 (tap the on-board button to enter the bootloader):
flash: $(o)/$n.hex
	teensy_loader_cli --mcu=TEENSY41 -w -v $(o)/$n.hex
