# Project root. Single Makefile: cross-cutting tasks (test, clean, install, ...)
# plus the host (POSIX CLI) and kernel (freestanding) builds inlined directly
# here. Embedded shells (playdate, rp2040) live under arch/ with their own
# build files; wasm keeps its own Makefile. Build output lands under out/
# (out/host, out/free, out/lib, out/playdate, out/dl). Shared vars live in common.mk.
R := .
include common.mk

CCACHE ?= $(shell command -v ccache 2>/dev/null)

.PHONY: all install uninstall clean distclean
.PHONY: host kernel playdate wasm rp2040 gl0
.PHONY: test test_host test_all test_tools test_gl0 hooks
.PHONY: valg disasm flame cat cata catav perf repl gdb vmret bench sim
test: test_host test_gl0
test_all: test_host test_gl0 test_tools
test_gl0: host
	@echo TEST $(gl0)
	@cat $t | $(gl0) -l gwen/prelude.$x -l gwen/repl.$x
test_host: host
	@echo TEST $m
	@cat $t | $m
# Validate the gwen tool rewrites against their frozen Python references in
# tools/py/ (gen_data / elf2efi / vmret). See tools/Makefile + tools/py/README.md.
test_tools: host
	@$(MAKE) -C tools
# CLAUDE.md is test/CLAUDE.g wrapped in a ```gwen fence (tools/gen_claudemd.g). It is
# NOT a make target: Claude regenerates it by hand after rewriting test/CLAUDE.g --
#   out/host/gl tools/gen_claudemd.g
# and the pre-commit hook (tools/hooks/) only checks freshness, failing a stale commit.
# Activate the tracked git hooks (tools/hooks/) for this clone.
hooks:
	@git config core.hooksPath tools/hooks
	@echo "hooks: core.hooksPath -> tools/hooks"
all: host kernel playdate wasm rp2040

# Static lisp headers: each gwen/*.g is serialized to a C string literal in
# out/lib/*.h by tools/lcat.g (run on the bootstrap interpreter gl0). Frontends
# #include these and assemble the bootstrap with G_EGG_PRE/POST (gwen.h).
# Drop a .g into gwen/ and it is picked up automatically -- no rule to edit.
lib_h = $(patsubst gwen/%.$x,out/lib/%.h,$(wildcard gwen/*.$x))
.PHONY: lib
lib: $(lib_h) out/lib/cli0.h
$(lib_h): out/lib/%.h: gwen/%.$x $(gl0) tools/lcat.$x
	@mkdir -p out/lib
	@echo GEN	$@
	@$(gl0) -l gwen/prelude.$x tools/lcat.$x $< > $@
# cli.g doubles as gl0's own CLI arg handler, so gl0 can't lcat it (chicken/egg).
# gl0 #includes the sed-wrapped raw cli0.h below -- a text->literal needing no
# interpreter (the gwen reader strips the ; comments at read time anyway). The
# final gl gets the canonicalized lcat cli.h from the rule above.
out/lib/cli0.h: gwen/cli.$x
	@mkdir -p out/lib
	@echo GEN	$@
	@sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/^/"/' -e 's/$$/\\n"/' $< > $@

# ====================================================================
# host (POSIX CLI) build -- outputs under out/host. Was host/Makefile.
# ====================================================================
ho = out/host
h_o = $(g_c:$(R)/%.c=$(ho)/%.o)
# -I$(ho) first so the generated $(ho)/data.h shadows the portable top-level data.h.
hcc = $(CC) $(g_cflags) -fpic -I$(ho) -I. -Iout/lib
data_ld = data.ld
ldflags = -Wl,-T,$(data_ld)
hdata_h = $(ho)/data.h
gl0 = $(ho)/gl0

host: $(ho)/$n $(ho)/lib$n.so $(ho)/$n.1
gl0: $(gl0)

$(ho)/lib$n.a: $(h_o)
	@echo AR	$@
	@mkdir -p $(dir $@)
	@ar rcs $@ $^

$(ho)/lib$n.so: $(ho)/lib$n.a $(data_ld)
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(hcc) $(ldflags) -shared -o $@ -Wl,--whole-archive $(ho)/lib$n.a -Wl,--no-whole-archive -lm

# The data-sentinel TU bootstraps from the portable top-level data.h (no $(hdata_h)
# prerequisite -- that would be circular, since $(hdata_h) is reflected out of it).
$(ho)/data.o: data.c $(g_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(hcc) -c $< -o $@

# Prelude-less bootstrap interpreter, compiled against the fallback top-level
# data.h (no -I$(ho)) + -DGL_BOOTSTRAP; runs the gwen build tools that generate
# the lcat headers, so it must need none of those. The one exception is cli0.h
# (its own CLI arg handler), which sed produces without an interpreter -- hence
# -Iout/lib. Per-object into $(ho)/0/ so ccache caches each TU.
gl0_cc = $(CCACHE) $(CC) $(g_cflags) -DGL_BOOTSTRAP -I. -Iout/lib
gl0_o = $(ho)/0/main.o $(g_c:$(R)/%.c=$(ho)/0/%.o)
$(ho)/0/main.o: main.c $(g_h) out/lib/cli0.h
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(gl0_cc) -c $< -o $@
$(ho)/0/%.o: $(R)/%.c $(g_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(gl0_cc) -c $< -o $@
$(gl0): $(gl0_o) $(data_ld)
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(CC) $(g_cflags) $(ldflags) -o $@ $(gl0_o) -lm

# tools/gen_data.g reflects $(ho)/data.o's gwen_data.NN section sizes into
# $(ho)/data.h, whose g_typ() shifts instead of the portable header's divides.
$(hdata_h): $(ho)/data.o $(gl0) tools/gen_data.$x gwen/prelude.$x
	@echo GEN	$@
	@$(gl0) -l gwen/prelude.$x tools/gen_data.$x $< -o $@

# gwen.c/data.c -> out/host/*.o (against the generated data.h).
$(ho)/%.o: $(R)/%.c $(g_h) $(hdata_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(hcc) -c $< -o $@

# main.c is compiled into the final gl inline (G_EGG_PRE/POST assemble the lib
# headers); depend on them so it relinks when a lib source changes.
$(ho)/$n: main.c $(ho)/lib$n.a out/lib/egg.h out/lib/prelude.h out/lib/ev.h out/lib/repl.h out/lib/cli.h $(hdata_h) $(data_ld)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(hcc) $(ldflags) -o $@ main.c $(ho)/lib$n.a -lm

$(ho)/$n.1: $(ho)/$n gwen/manpage.$x
	@echo GEN	$@
	@$(ho)/$n < gwen/manpage.$x > $@

# ====================================================================
# kernel (freestanding) build -- outputs under out/free. Was free/Makefile.
# Arch-independent glue is kmain.c + k.h at the root; per-arch code lives in
# arch/<a>/ (arch.c, *.S, *.lds, efi_main.c). Limine vs UEFI toggle is EFI=1.
# ====================================================================
ko = out/free
dl = out/dl

# Cross toolchain defaults to clang + lld (one multi-target pair covers every
# arch). Override for a GCC cross toolchain, e.g.
#   make kernel a=aarch64 KCC=aarch64-linux-gnu-gcc KLD=aarch64-linux-gnu-ld
KCC ?= clang
KLD ?= ld.lld
KCC_IS_CLANG := $(shell $(KCC) --version 2>/dev/null | grep -qiw clang && echo 1)

ifdef EFI
ifeq ($(filter $a,x86_64 aarch64 riscv64 loongarch64),)
$(error EFI=1 is only wired up for x86_64, aarch64, riscv64, and loongarch64)
endif
k_arch_c = $(wildcard $(R)/arch/$a/*.c)
k_asm =
else
k_arch_c = $(filter-out $(R)/arch/$a/efi_%.c,$(wildcard $(R)/arch/$a/*.c))
k_asm = $(wildcard $(R)/arch/$a/*.asm)
endif
k_free_c = $R/kmain.c
k_shared_c = $(g_c) $(f_c) $(c_c)
k_S = $(wildcard $(R)/arch/$a/*.S)
k_h = $(g_h) $(wildcard *.h $(R)/arch/$a/*.h)

ifdef EFI
k_odir = $(ko)/$a-efi
else
k_odir = $(ko)/$a
endif

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

kcflags = $(g_cflags) -nostdinc -ffreestanding -fno-lto -fno-PIC \
  -ffunction-sections -fdata-sections
kldflags := -static -nostdlib --gc-sections -T $(R)/arch/$a/$a.lds -z max-page-size=0x1000
kcppflags := \
  -I$(k_odir) \
  -I. -I$(R)/out/host -Iout/lib -I$(R)/font -I$(R) \
  -Ilibc \
  -isystem c \
  $(kcppflags) \
  -DLIMINE_API_REVISION=3
ifdef EFI
kcppflags += -DK_EFI
endif

ifeq ($(KCC_IS_CLANG),1)
ifdef EFI
ifneq ($(filter $a,riscv64 loongarch64),)
kcc_if_clang = -target $a-unknown-none-elf
else
kcc_if_clang = -target $a-unknown-windows
endif
else
kcc_if_clang = -target $a-unknown-none-elf
endif
endif

ifdef EFI
kcflags_x86_64 = -m64 -march=x86-64 -mno-red-zone
else
kcflags_x86_64 = -m64 -march=x86-64 -mabi=sysv -mno-red-zone -mcmodel=kernel
endif
kcflags_aarch64 = -mcpu=generic -march=armv8-a
kcflags_riscv64 = -march=rv64imafdc -mabi=lp64d -mno-relax \
  $(kcflags_riscv64_$(if $(EFI),efi,limine))
kcflags_riscv64_limine =
kcflags_riscv64_efi = -mcmodel=medany
kcflags_loongarch64 = -march=loongarch64 -mabi=lp64d \
  $(kcflags_loongarch64_$(if $(EFI),efi,limine))
kcflags_loongarch64_limine =
kcflags_loongarch64_efi = -fdirect-access-external-data

kldflags_x86_64 = -m elf_x86_64
kldflags_aarch64 = -m aarch64elf
kldflags_riscv64 = -m elf64lriscv --no-relax
kldflags_loongarch64 = -m elf64loongarch

kcc = $(KCC) $(kcflags) $(kcflags_$a) $(kcppflags) $(kcc_if_clang)
k_nasmflags := -f elf64 -g -F dwarf -Wall -w-reloc-abs-qword -w-reloc-abs-dword -w-reloc-rel-dword

kernel: $(ko)/$n-$a.elf

$(ko)/$n-$a.elf: $(R)/arch/$a/$a.lds $(k_o)
	@echo LD	$@
	@mkdir -p "$(dir $@)"
	@$(KLD) $(kldflags) $(k_o) -o $@

# EFI link. x86_64/aarch64: clang drives lld-link via the *-unknown-windows
# triple. riscv64/loongarch64: link a static ELF with --emit-relocs and wrap it
# in a PE32+ container via tools/elf2efi.g (run through the host gl, $m).
kefi_elfmach_riscv64     = elf64lriscv
kefi_elfmach_loongarch64 = elf64loongarch
ifneq ($(filter $a,riscv64 loongarch64),)
$(ko)/$n-$a.efi: $(k_o) $(R)/arch/$a/$a.efi.lds $(R)/tools/elf2efi.$x | $(m)
	@echo LD	$(@:.efi=.efi.elf)
	@mkdir -p "$(dir $@)"
	@$(KLD) -m $(kefi_elfmach_$a) --no-relax -static -nostdlib --gc-sections \
	  --emit-relocs -T $(R)/arch/$a/$a.efi.lds -e efi_main \
	  $(k_o) -o $(@:.efi=.efi.elf)
	@echo EFI	$@
	@$(m) $(R)/tools/elf2efi.$x $(@:.efi=.efi.elf) $@
else
$(ko)/$n-$a.efi: $(k_o)
	@echo LD	$@
	@mkdir -p "$(dir $@)"
	@$(KCC) $(kcflags) $(kcflags_$a) $(kcc_if_clang) -nostdlib -fuse-ld=lld \
	  -Wl,-subsystem:efi_application -Wl,-entry:efi_main \
	  $(k_o) -o $@
endif

# The data-sentinel TU bootstraps from the portable header (no $(kdata_h) prereq
# -- circular). On a clean build data.h doesn't exist yet, so -I$(k_odir) finds
# nothing and the compile falls through to the portable top-level data.h.
$(k_odir)/data.o: $(R)/data.c $(k_h) out/lib/egg.h out/lib/prelude.h out/lib/ev.h out/lib/repl.h
	@echo CC	$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@

$(kdata_h): $(k_odir)/data.o $(gen_data) | $(m)
	@echo GEN	$@
	@$(m) $(gen_data) $< -o $@

# Shared C sources (gwen.c/data.c, font/, c/) + per-arch arch/$a/.
$(k_odir)/%.o: $(R)/%.c $(k_h) $(kdata_h) out/lib/egg.h out/lib/prelude.h out/lib/ev.h out/lib/repl.h
	@echo CC	$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@

$(k_odir)/%.o: $(R)/%.S $(k_h)
	@echo AS	$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@

$(k_odir)/%.o: $(R)/%.asm $(k_h)
	@echo AS	$@
	@mkdir -p "$(dir $@)"
	@nasm $< -o $@ $(k_nasmflags)

# --- ISO / HDD / EFI image rules -------------------------------------
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

$(ko)/$n-$a.iso: $(ko)/$n-$a.elf $(dl)/limine/limine $(ko)/limine.conf
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
	@cp $(dl)/limine/BOOTRISCV64.EFI $(ko)/iso_root/EFI/BOOT/
	@cp $(dl)/limine/BOOTLOONGARCH64.EFI $(ko)/iso_root/EFI/BOOT/
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
	@mcopy -i $@@@1M $(dl)/limine/BOOTRISCV64.EFI ::/EFI/BOOT
	@mcopy -i $@@@1M $(dl)/limine/BOOTLOONGARCH64.EFI ::/EFI/BOOT

k_efi_short_x86_64 = BOOTX64
k_efi_short_aarch64 = BOOTAA64
k_efi_short_riscv64 = BOOTRISCV64
k_efi_short_loongarch64 = BOOTLOONGARCH64
$(ko)/$n-$a-efi.img: $(ko)/$n-$a.efi
	@echo MK $@
	@rm -f $@
	@dd if=/dev/zero bs=1M count=0 seek=64 of=$@ 2>/dev/null
	@mformat -i $@ -F
	@mmd -i $@ ::/EFI ::/EFI/BOOT
	@mcopy -i $@ $< ::/EFI/BOOT/$(k_efi_short_$a).EFI

# --- qemu run targets ------------------------------------------------
k_efi_drive_x86_64 = -drive if=ide,format=raw,file=$<
k_efi_drive_aarch64 = -drive if=none,format=raw,file=$<,id=hd0 -device virtio-blk-device,drive=hd0
k_efi_drive_riscv64 = -drive if=none,format=raw,file=$<,id=hd0 -device virtio-blk-device,drive=hd0
k_efi_drive_loongarch64 = -drive if=none,format=raw,file=$<,id=hd0 -device virtio-blk-pci,drive=hd0

k_qemu_x86_64 = -M q35 -serial stdio
k_qemu_risc = -device ramfb -device qemu-xhci -device usb-kbd -device usb-mouse
k_qemu_loongarch64 = -M virt -cpu la464 -serial stdio $(k_qemu_risc)
k_qemu_aarch64 = -M virt,gic-version=2 -cpu cortex-a72 -serial stdio $(k_qemu_risc)
k_qemu_riscv64 = -M virt -cpu rv64 -serial stdio $(k_qemu_risc)
k_qemu = qemu-system-$a -m 256M $(k_qemu_$a) \
  -drive if=pflash,unit=0,format=raw,file=$(dl)/edk2-ovmf/ovmf-code-$a.fd,readonly=on

.PHONY: run run-hdd run-$a run-hdd-$a run-headless run-efi run-efi-headless
run: run-$a
run-hdd: run-hdd-$a
run-$a: $(ko)/$n-$a.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) -cdrom $<
run-hdd-$a: $(ko)/$n-$a.hdd $(dl)/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) -hda $<
run-headless: $(ko)/$n-$a.iso $(dl)/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) -cdrom $< -display none -no-reboot
run-efi: $(ko)/$n-$a-efi.img $(dl)/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) $(k_efi_drive_$a)
run-efi-headless: $(ko)/$n-$a-efi.img $(dl)/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) $(k_efi_drive_$a) -display none -no-reboot

# --- downloads -------------------------------------------------------
$(dl)/edk2-ovmf/ovmf-code-%.fd:
	@echo MK ovmf
	@mkdir -p $(dl)
	@curl -L https://github.com/osdev0/edk2-ovmf-nightly/releases/latest/download/edk2-ovmf.tar.gz | gunzip | tar -C $(dl) -xf -
	@case "$a" in \
		aarch64) dd if=/dev/zero of=$@ bs=1 count=0 seek=67108864 2>/dev/null;; \
		riscv64) dd if=/dev/zero of=$@ bs=1 count=0 seek=33554432 2>/dev/null;; \
	esac

$(dl)/limine/limine:
	@echo MK limine
	@rm -rf $(dl)/limine
	@git clone https://codeberg.org/Limine/Limine.git $(dl)/limine --branch=v10.x-binary --depth=1 > /dev/null 2>&1
	@$(MAKE) -sC $(dl)/limine

# ====================================================================
# embedded shells (own build files, under arch/) + wasm
# ====================================================================
playdate:
	@$(MAKE) -C arch/playdate
wasm:
	@$(MAKE) -C wasm
sim:
	$(MAKE) -C arch/playdate sim

# --- rp2040: bare-metal Cortex-M0+ (no Pico SDK, no CMake) -----------
# Freestanding thumbv6m build of the gwen runtime + the arch/rp2040 backend,
# linked at flash XIP behind a 256-byte checksummed boot2 (tools/pad_checksum.g
# stamps the vendored arch/rp2040/boot2.bin) and packed into a flashable .uf2
# (tools/elf2uf2.g). Mirrors the kernel build: per-arch data.h reflected out of
# this target's data.o, the lcat lib headers shared from out/lib. The M0+ has no
# FPU or hardware divide, so the compiler-rt builtins archive (rp_rt) supplies
# the soft-float / 64-bit __aeabi_* libcalls -- from clang's compiler-rt when a
# thumbv6m build is installed, else the arm-none-eabi GCC libgcc multilib (the
# v6-m/nofp variant ships the same AAPCS __aeabi_* routines).
ro = out/rp2040
rp_triple = -target thumbv6m-none-eabi -mcpu=cortex-m0plus -mthumb
rp_cppflags = -I$(ro) -I. -Iout/lib -I$R/libc -I$R/arch/rp2040
rp_cc = $(KCC) $(rp_triple) $(g_cflags) -nostdinc -ffreestanding -fno-lto \
  -fno-PIC -ffunction-sections -fdata-sections -Dg_tco=0 $(rp_cppflags)
rp_rt := $(shell f=$$($(KCC) $(rp_triple) -print-libgcc-file-name 2>/dev/null); \
  [ -e "$$f" ] && echo "$$f" || \
  arm-none-eabi-gcc -mcpu=cortex-m0plus -mthumb -print-libgcc-file-name 2>/dev/null)
rp_h = $(g_h) $(wildcard $R/arch/rp2040/*.h)
rp_data_h = $(ro)/data.h
rp_lib_h = out/lib/egg.h out/lib/prelude.h out/lib/ev.h out/lib/repl.h
rp_src = $(g_c) $(c_c) $R/arch/rp2040/rp2040.c $R/arch/rp2040/main.c
rp_o = $(rp_src:$(R)/%.c=$(ro)/%.o)

rp2040: $(ro)/$n.uf2

# data.o bootstraps from the portable top-level data.h (no rp_data_h prereq -- it is
# circular); its sentinel stride is then reflected into the generated data.h,
# which -I$(ro) puts ahead of the portable one. The explicit rule shadows the
# %.o pattern below for data.o specifically.
$(ro)/data.o: $R/data.c $(rp_h) $(rp_lib_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(rp_cc) -c $< -o $@
$(rp_data_h): $(ro)/data.o $(gen_data) | $(m)
	@echo GEN	$@
	@$(m) $(gen_data) $< -o $@

$(ro)/%.o: $R/%.c $(rp_h) $(rp_data_h) $(rp_lib_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(rp_cc) -c $< -o $@

# boot2: stamp the CRC onto the vendored payload, then assemble the .byte blob
# into the .boot2 section the linker places at flash base (0x10000000).
$(ro)/boot2.s: $R/arch/rp2040/boot2.bin $R/tools/pad_checksum.$x | $(m)
	@echo GEN	$@
	@mkdir -p $(dir $@)
	@$(m) $R/tools/pad_checksum.$x $< > $@
$(ro)/boot2.o: $(ro)/boot2.s
	@echo AS	$@
	@$(KCC) $(rp_triple) -c $< -o $@

$(ro)/$n.elf: $(rp_o) $(ro)/boot2.o $R/arch/rp2040/rp2040.lds
	@echo LD	$@
	@$(KCC) $(rp_triple) -nostdlib -fuse-ld=lld -Wl,--gc-sections -Wl,-T,$R/arch/rp2040/rp2040.lds \
	  $(rp_o) $(ro)/boot2.o $(rp_rt) -o $@

$(ro)/$n.uf2: $(ro)/$n.elf $R/tools/elf2uf2.$x | $(m)
	@echo UF2	$@
	@$(m) $R/tools/elf2uf2.$x $< $@

clean:
	rm -rf out
	@$(MAKE) -C wasm clean
	@$(MAKE) -C arch/playdate clean 2>/dev/null || true
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
	cloc --by-file --force-lang=Lisp,$x gwen gwen.c gwen.h data.c data.h kmain.c main.c k.h arch tools test vim
cat: clean all test
cata: clean all test_all
# Full clean rebuild, every frontend, all tests, then the corpus under valgrind.
catav: clean all test_all valg

disasm: host
	rizin -A $m
gdb: host
	gdb $m
vmret: host
	@$m tools/vmret.g $m

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
  $d/share/man/man1/$n.1 \
  $d/lib/$n/prelude.$x \
  $d/lib/$n/ev.$x \
  $d/lib/$n/repl.$x \
  $d/liout/lib$n.a \
  $d/liout/lib$n.so \
  $d/include/gwen.h \
  $v/ftdetect/$n.vim \
  $v/syntax/$n.vim \
  $v/ftplugin/$n.vim

install: $(installs)
uninstall:
	@echo RM	$(abspath $(installs))
	@rm -f $(installs)

$d/include/gwen.h: gwen.h
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/$n/%.$x: gwen/%.$x
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/liout/lib$n.a: out/host/lib$n.a
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/liout/lib$n.so: out/host/lib$n.so
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

$d/bin/$n: out/host/$n
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

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
