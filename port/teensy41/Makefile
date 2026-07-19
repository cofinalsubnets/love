# Teensy 4.1 (i.MX RT1062) build. Run from the project root via `make -C
# port/teensy41`, or directly via `cd port/teensy41 && make`. Standalone:
# it touches no file in the main tree -- it points R at a love checkout, pulls
# the shared vars from common.mk, and delegates the lcat lib headers back to
# the root Makefile on demand. Output lands in $(R)/out/teensy41/.
#
# Freestanding thumbv7em build of the love runtime + the arch backend here,
# booting XIP from the 8 MB FlexSPI NOR behind the FlexSPI config block + IVT
# (teensy41.c) and packed into a .hex for teensy_loader_cli / the Teensy Loader
# GUI. Mirrors the kernel build: the lcat lib headers shared from out/lib. The
# M7 has a double-precision FPU, so this build is hard-float (-mfpu=fpv5-d16);
# the compiler-rt / libgcc archive (te_rt) supplies the 64-bit / soft-helper
# __aeabi_* libcalls.
R := ../..
include $(R)/common.mk

KCC ?= clang
CCACHE ?= $(shell command -v ccache 2>/dev/null)
o = $(R)/out/teensy41

te_triple = -target thumbv7em-none-eabi -mcpu=cortex-m7 -mthumb
te_fpu = -mfloat-abi=hard -mfpu=fpv5-d16
te_cppflags = -I. -I$(R) -I$(R)/out/lib -I$(R)/libc
te_cc = $(CCACHE) $(KCC) $(te_triple) $(te_fpu) $(ai_cflags) -nostdinc -ffreestanding \
  -fno-lto -fno-PIC -ffunction-sections -fdata-sections -Dai_tco=0 $(te_cppflags)
te_rt := $(shell f=$$($(KCC) $(te_triple) $(te_fpu) -print-libgcc-file-name 2>/dev/null); \
  [ -e "$$f" ] && echo "$$f" || \
  arm-none-eabi-gcc -mcpu=cortex-m7 -mthumb $(te_fpu) -print-libgcc-file-name 2>/dev/null)

te_h = $(love_h) $(wildcard *.h)
lib_h = $(R)/out/lib/egg.h $(R)/out/lib/prel.h $(R)/out/lib/ev.h $(R)/out/lib/bao.h

# Local arch sources (teensy41.c, main.c) stay rooted in cwd; the shared runtime
# (love.c, libc/) carries the $(R)/ prefix. Local rule is listed first so this
# main.c wins the object-name race against the top-level host main.c.
te_local_c = $(wildcard *.c)
te_shared_c = $(love_c) $(c_c)
te_local_o = $(te_local_c:%.c=$(o)/%.o)
te_shared_o = $(te_shared_c:$(R)/%.c=$(o)/%.o)
te_o = $(te_local_o) $(te_shared_o)

OBJCOPY ?= $(shell command -v llvm-objcopy 2>/dev/null || echo arm-none-eabi-objcopy)

.PHONY: teensy41 flash clean
teensy41: $(o)/love.hex
default: teensy41

clean:
	rm -rf $(o)

# Delegate to the root: the lcat lib headers are produced by the root's own
# rules (on the bootstrap interpreter love0), built on demand so a standalone
# `make -C port/teensy41` works from a clean tree.
$(lib_h):
	@$(MAKE) -C $(R) out/lib/$(@F)

# Local arch sources (listed before the shared rule, see above).
$(o)/%.o: %.c $(te_h) $(lib_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(te_cc) -c $< -o $@
# Shared runtime + libc.
$(o)/%.o: $(R)/%.c $(te_h) $(lib_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(te_cc) -c $< -o $@

$(o)/love.elf: $(te_o) teensy41.lds
	@echo LD	$@
	@$(KCC) $(te_triple) $(te_fpu) -nostdlib -fuse-ld=lld -Wl,--gc-sections \
	  -Wl,-T,teensy41.lds $(te_o) $(te_rt) -o $@

# .hex (Intel HEX) is what teensy_loader_cli / the Teensy Loader GUI flash.
$(o)/love.hex: $(o)/love.elf
	@echo HEX	$@
	@$(OBJCOPY) -O ihex -R .eh_frame $< $@

# Flash a connected Teensy 4.1 (tap the on-board button to enter the bootloader):
flash: $(o)/love.hex
	teensy_loader_cli --mcu=TEENSY41 -w -v $(o)/love.hex
