# Kernel build. Run from project root via `make k`, or directly via
# `cd k && make`. Outputs (objects, kernel ELF/EFI, ISO/HDD/EFI images)
# all land in b/ under this cwd. Downloaded blobs (Limine, edk2-ovmf)
# live in dl/ under this cwd. The Limine vs UEFI direct-boot toggle
# is `EFI=1`.
R := ..
include $(R)/common.mk

# --- sources ---------------------------------------------------------
# The Limine build picks up arch.c + the nasm bits and omits the efi_*.c
# files. The EFI build (EFI=1) does the opposite. Shared sources from
# root (g/, f/, libc/) come in via common.mk; local kernel sources are
# reached from this cwd (k/).

# Default the cross toolchain to clang + lld: one multi-target pair covers
# every arch (Limine and EFI) with no per-arch GCC. Override CC/LD on the
# command line for a GCC cross toolchain, e.g.
#   make k a=aarch64 CC=aarch64-linux-gnu-gcc LD=aarch64-linux-gnu-ld
# (command-line assignments beat these). CC_IS_CLANG is detected from the
# chosen CC so the clang-only -target triples never reach a gcc.
CC := clang
LD := ld.lld
CC_IS_CLANG := $(shell $(CC) --version 2>/dev/null | grep -qiw clang && echo 1)

ifdef EFI
ifeq ($(filter $a,x86_64 aarch64 riscv64 loongarch64),)
$(error EFI=1 is only wired up for x86_64, aarch64, riscv64, and loongarch64)
endif
# Same sources as the Limine build, with two swaps: efi_main.c stands
# in for the Limine boot info, and efi_*.c stays excluded for backends
# that already exist (currently nothing -- the polled-mode stand-in is
# gone). arch.c + the per-arch .S come along; the SysV-tagged C callees
# keep the asm-to-C boundary correct under MS x64 on x86_64 (aarch64's
# default ABI matches the asm's call convention either way).
k_local_c = $(wildcard *.c $a/*.c)
k_asm =
else
k_local_c = $(filter-out $a/efi_%.c,$(wildcard *.c $a/*.c))
k_asm = $(wildcard $a/*.asm)
endif
k_shared_c = $(g_c) $(f_c) $(c_c)
k_S = $(wildcard $a/*.S)
k_h = $(g_h) $(wildcard *.h $a/*.h)

# Output objects live under b/$a/ for the Limine build and b/$a-efi/ for
# the EFI build, so the two coexist (different ABI/format objects).
ifdef EFI
k_odir = b/$a-efi
else
k_odir = b/$a
endif

# Split into shared (root) and local (cwd k/) so the patsubst forms are
# unambiguous; both groups land under k_odir.
k_shared_o = $(k_shared_c:$(R)/%.c=$(k_odir)/%.o)
k_local_o = $(k_local_c:%.c=$(k_odir)/%.o)
k_S_o = $(k_S:%.S=$(k_odir)/%.o)
k_asm_o = $(k_asm:%.asm=$(k_odir)/%.o)
k_o = $(k_shared_o) $(k_local_o) $(k_S_o) $(k_asm_o)

# --- flags -----------------------------------------------------------
kcflags = $(g_cflags) -nostdinc -ffreestanding -fno-lto -fno-PIC \
  -ffunction-sections -fdata-sections
kldflags := -static -nostdlib --gc-sections -T $a/$a.lds -z max-page-size=0x1000
kcppflags := \
  -I. -I$(R)/h/b -I$(R)/f -I$(R)/g \
  -Iinclude \
  -isystem include \
  $(kcppflags) \
  -DLIMINE_API_REVISION=3
ifdef EFI
kcppflags += -DK_EFI
endif

ifeq ($(CC_IS_CLANG),1)
ifdef EFI
# x86_64-unknown-windows defaults to MS x64 (matches the UEFI ABI on
# x86_64) and tells clang to invoke lld-link for the final link. For
# aarch64 the same triple yields PE32+/AArch64 with MS-AAPCS64, which
# is ABI-compatible with UEFI's AAPCS64 for the scalar-argument calls
# the firmware makes into us and we make back. riscv64 and loongarch64
# have no COFF backend in LLVM, so we keep the ELF target on those two
# and wrap the link output in a PE32+ container after the fact (see the
# .efi recipe below).
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
# Under UEFI we keep the kernel at whatever base the firmware places us
# (image is fully relocatable); -mcmodel=kernel and -mabi=sysv don't
# apply to the windows target, so drop them.
kcflags_x86_64 = -m64 -march=x86-64 -mno-red-zone
else
kcflags_x86_64 = -m64 -march=x86-64 -mabi=sysv -mno-red-zone -mcmodel=kernel
endif
kcflags_aarch64 = -mcpu=generic -march=armv8-a
kcflags_riscv64 = -march=rv64imafdc -mabi=lp64d -mno-relax \
  $(kcflags_riscv64_$(if $(EFI),efi,limine))
# Limine drops us at VMA 0xffffffff80000000, whose 32-bit truncation
# sign-extends back to the same address -- medlow's lui+addi sequences
# encode it correctly. UEFI loads the image at a runtime-chosen base
# instead, so we need PC-relative addressing (auipc+addi) everywhere;
# medany gives us that, and the PE base relocations only have to fix
# up the 64-bit absolute symbol references in static initializers.
kcflags_riscv64_limine =
kcflags_riscv64_efi = -mcmodel=medany
kcflags_loongarch64 = -march=loongarch64 -mabi=lp64d \
  $(kcflags_loongarch64_$(if $(EFI),efi,limine))
kcflags_loongarch64_limine =
# LoongArch clang defaults to routing cross-TU extern data accesses through
# a GOT entry (R_LARCH_GOT_PC_HI20/LO12), even with -fno-PIC -- and ld for
# a static link does NOT emit dynamic-style relocations against the GOT
# itself. The GOT ends up holding the symbol's link-time address, so any
# load at a runtime base other than the link-time base reads from the
# wrong place. UEFI hands us a firmware-chosen base, so we force clang to
# emit pcalau12i+addi.d (R_LARCH_PCALA_HI20/LO12) directly against the
# symbol; those are PC-relative and the PE base relocations handle them
# (well, the rest of the abs64 records do; PCALA pairs are PC-relative and
# need no fix-up). The 64-bit absolute references the compiler still emits
# for function-pointer tables and static initializers come out as
# R_LARCH_64 records, which elf2efi.py lifts into PE .reloc entries.
kcflags_loongarch64_efi = -fdirect-access-external-data

kldflags_x86_64 = -m elf_x86_64
kldflags_aarch64 = -m aarch64elf
kldflags_riscv64 = -m elf64lriscv --no-relax
kldflags_loongarch64 = -m elf64loongarch

kcc = $(CC) $(kcflags) $(kcflags_$a) $(kcppflags) $(kcc_if_clang)
k_nasmflags := -f elf64 -g -F dwarf -Wall -w-reloc-abs-qword -w-reloc-abs-dword -w-reloc-rel-dword

# --- targets ---------------------------------------------------------
.PHONY: default clean distclean
default: b/$n-$a.elf

clean:
	rm -rf b

distclean: clean
	rm -rf dl

# boot.h / repl.h are generated by the host build (it owns lcat). Depend on
# the .g sources so editing the prelude re-triggers the regen; without these
# prereqs the rule only fires when the header is missing, so a stale boot.h
# silently survives boot.g edits and the kernel boots an old prelude.
$(R)/h/b/boot.h: $(R)/g/boot.g
$(R)/h/b/repl.h: $(R)/g/repl.g
$(R)/h/b/boot.h $(R)/h/b/repl.h:
	@$(MAKE) -C $(R)/h $(notdir $@)

b/$n-$a.elf: $a/$a.lds $(k_o)
	@echo LD	$@
	@mkdir -p "$(dir $@)"
	@$(LD) $(kldflags) $(k_o) -o $@

# EFI link.
# x86_64 and aarch64: clang drives lld-link via -fuse-ld=lld against the
# *-unknown-windows triple. Subsystem flag picks EFI_APPLICATION (10);
# entry is efi_main. lld-link synthesises the .reloc table itself so the
# firmware can relocate the image at load time.
# riscv64 and loongarch64: LLVM has no COFF backend for either arch, so
# we cannot take that path. Instead we link a plain static ELF with
# --emit-relocs (preserving the relocation records ld would otherwise
# drop) and wrap the result in a PE32+ container via tools/elf2efi.py.
# The tool walks .rela.* for the absolute-64 entries (R_RISCV_64 or
# R_LARCH_64, both encoded as type 2) and stamps out IMAGE_REL_BASED_DIR64
# records that do the same job lld-link does for the other two arches.
kefi_elfmach_riscv64     = elf64lriscv
kefi_elfmach_loongarch64 = elf64loongarch
ifneq ($(filter $a,riscv64 loongarch64),)
b/$n-$a.efi: $(k_o) $a/$a.efi.lds $(R)/tools/elf2efi.py
	@echo LD	$(@:.efi=.efi.elf)
	@mkdir -p "$(dir $@)"
	@$(LD) -m $(kefi_elfmach_$a) --no-relax -static -nostdlib --gc-sections \
	  --emit-relocs -T $a/$a.efi.lds -e efi_main \
	  $(k_o) -o $(@:.efi=.efi.elf)
	@echo EFI	$@
	@python3 $(R)/tools/elf2efi.py $(@:.efi=.efi.elf) $@
else
b/$n-$a.efi: $(k_o)
	@echo LD	$@
	@mkdir -p "$(dir $@)"
	@$(CC) $(kcflags) $(kcflags_$a) $(kcc_if_clang) -nostdlib -fuse-ld=lld \
	  -Wl,-subsystem:efi_application -Wl,-entry:efi_main \
	  $(k_o) -o $@
endif

# Compile shared C sources from g/ and f/.
$(k_odir)/%.o: $(R)/%.c $(k_h) $(R)/h/b/boot.h $(R)/h/b/repl.h
	@echo CC	$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@

# Compile local kernel C sources (k/*.c, k/$a/*.c).
$(k_odir)/%.o: %.c $(k_h) $(R)/h/b/boot.h $(R)/h/b/repl.h
	@echo CC	$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@

$(k_odir)/%.o: %.S $(k_h)
	@echo AS	$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@

$(k_odir)/%.o: %.asm $(k_h)
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

b/$n-$a.iso: b/$n-$a.elf dl/limine/limine limine/limine.conf
	@echo MK $@
	@rm -rf b/iso_root
	@mkdir -p b/iso_root/boot
	@cp $< b/iso_root/boot/kernel
	@mkdir -p b/iso_root/boot/limine
	@cp limine/limine.conf b/iso_root/boot/limine/
	@mkdir -p b/iso_root/EFI/BOOT
	@cp dl/limine/limine-uefi-cd.bin b/iso_root/boot/limine/
	@cp dl/limine/limine-bios.sys dl/limine/limine-bios-cd.bin b/iso_root/boot/limine/
	@cp dl/limine/BOOTX64.EFI dl/limine/BOOTIA32.EFI b/iso_root/EFI/BOOT/
	@cp dl/limine/BOOTAA64.EFI b/iso_root/EFI/BOOT/
	@cp dl/limine/BOOTRISCV64.EFI b/iso_root/EFI/BOOT/
	@cp dl/limine/BOOTLOONGARCH64.EFI b/iso_root/EFI/BOOT/
	$(k_xorriso) b/iso_root -o $@
	@dl/limine/limine bios-install $@
	@rm -rf b/iso_root

b/$n-$a.hdd: b/$n-$a.elf dl/limine/limine limine/limine.conf
	@echo MK $@
	@rm -f $@
	@dd if=/dev/zero bs=1M count=0 seek=64 of=$@
	@PATH=$$PATH:/usr/sbin:/sbin sgdisk $@ -n 1:2048 -t 1:ef00
	@mformat -i $@@@1M
	@mmd -i $@@@1M ::/EFI ::/EFI/BOOT ::/boot ::/boot/limine
	@mcopy -i $@@@1M $< ::/boot/kernel
	@mcopy -i $@@@1M limine/limine.conf ::/boot/limine
	@mcopy -i $@@@1M dl/limine/limine-bios.sys ::/boot/limine
	@mcopy -i $@@@1M dl/limine/BOOTX64.EFI ::/EFI/BOOT
	@mcopy -i $@@@1M dl/limine/BOOTIA32.EFI ::/EFI/BOOT
	@mcopy -i $@@@1M dl/limine/BOOTAA64.EFI ::/EFI/BOOT
	@mcopy -i $@@@1M dl/limine/BOOTRISCV64.EFI ::/EFI/BOOT
	@mcopy -i $@@@1M dl/limine/BOOTLOONGARCH64.EFI ::/EFI/BOOT

# --- EFI-only boot media -----------------------------------------------
# A raw FAT image containing just /EFI/BOOT/BOOT<arch>.EFI under the UEFI
# spec's fallback name (X64 / AA64 / ...). OVMF reads this directly --
# no Limine, no second-stage loader, no config file. Same mformat path
# as the .hdd rule, just without the GPT wrapper and without the Limine
# BOOT*.EFI copies.
k_efi_short_x86_64 = BOOTX64
k_efi_short_aarch64 = BOOTAA64
k_efi_short_riscv64 = BOOTRISCV64
k_efi_short_loongarch64 = BOOTLOONGARCH64
b/$n-$a-efi.img: b/$n-$a.efi
	@echo MK $@
	@rm -f $@
	@dd if=/dev/zero bs=1M count=0 seek=64 of=$@ 2>/dev/null
	@mformat -i $@ -F
	@mmd -i $@ ::/EFI ::/EFI/BOOT
	@mcopy -i $@ $< ::/EFI/BOOT/$(k_efi_short_$a).EFI

# --- qemu run targets ------------------------------------------------
# x86_64's q35 has IDE so `-drive if=ide` works there; QEMU's virt
# machine (aarch64/riscv64) has no IDE controller, so attach the image
# as virtio-blk over the existing virtio-mmio bus instead. loongarch64's
# virt machine wires virtio on PCI (no virtio-mmio bus), so it needs
# virtio-blk-pci explicitly -- the mmio-transport `virtio-blk-device`
# alias fails to bind there.
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
  -drive if=pflash,unit=0,format=raw,file=dl/edk2-ovmf/ovmf-code-$a.fd,readonly=on

.PHONY: run run-hdd run-$a run-hdd-$a run-headless run-efi run-efi-headless
run: run-$a
run-hdd: run-hdd-$a
run-$a: b/$n-$a.iso dl/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) -cdrom $<
run-hdd-$a: b/$n-$a.hdd dl/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) -hda $<
# headless: no display, COM1 console on stdio (see k_qemu_x86_64) -- so
# the gwen repl can be driven over a pipe. -no-reboot exits on k_reset.
run-headless: b/$n-$a.iso dl/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) -cdrom $< -display none -no-reboot
run-efi: b/$n-$a-efi.img dl/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) $(k_efi_drive_$a)
run-efi-headless: b/$n-$a-efi.img dl/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) $(k_efi_drive_$a) -display none -no-reboot

# --- downloads -------------------------------------------------------
dl/edk2-ovmf/ovmf-code-%.fd:
	@echo MK ovmf
	@mkdir -p dl
	@curl -L https://github.com/osdev0/edk2-ovmf-nightly/releases/latest/download/edk2-ovmf.tar.gz | gunzip | tar -C dl -xf -
	@case "$a" in \
		aarch64) dd if=/dev/zero of=$@ bs=1 count=0 seek=67108864 2>/dev/null;; \
		riscv64) dd if=/dev/zero of=$@ bs=1 count=0 seek=33554432 2>/dev/null;; \
	esac

dl/limine/limine:
	@echo MK limine
	@rm -rf dl/limine
	@git clone https://codeberg.org/Limine/Limine.git dl/limine --branch=v10.x-binary --depth=1 > /dev/null 2>&1
	@$(MAKE) -sC dl/limine
