n=gl
x=g
m=b/h/$n
a?=$(shell uname -m)

t=$(sort $(wildcard t/*.$x))

.PHONY: test all h k pd clean distclean
test: b/h/$n
	@echo TEST
	@cat $t | $m
all: h k pd
h: b/h/$n b/h/lib$n.so b/h/$n.1
k: b/k/$n-$a.elf
pd: b/pd/$n.pdx
clean:
	rm -rf b `git check-ignore esp/* wasm/* pico/*`
distclean: clean
	rm -rf dl

.PHONY: valg perf repl cloc cat
valg: b/h/$n
	cat $t | valgrind --error-exitcode=1 b/h/$n
b/perf.data: b/h/$n
	cat $t | perf record -o $@ b/h/$n
perf: b/perf.data
	perf report -i $<
b/flamegraph.svg: b/perf.data
	flamegraph -o $@ --perfdata $<
repl: b/h/$n
	@$<
cloc:
	cloc --by-file --force-lang=Lisp,$x g h js k p pd t vim
cat: clean all test
.PHONY: disasm debug
disasm: b/h/$n
	rizin -A $^
gdb: b/h/$n
	gdb $^



#build
# c files and headers
g_h=$(wildcard g/*.h)
g_c=$(wildcard g/*.c)
f_c=$(wildcard f/*.c)
h_o=$(addprefix b/h/, $(g_c:.c=.o))
g_cflags=-std=gnu23 -g -Os -pipe\
 	-Wall -Wextra -Wstrict-prototypes -Wno-unused-parameter\
	-falign-functions -fomit-frame-pointer -fno-stack-check -fno-stack-protector\
 	-fno-exceptions -fno-asynchronous-unwind-tables -fno-stack-clash-protection\
 	-fcf-protection=none
cc=$(CC) $(g_cflags) -fpic -I. -Ig/ -Ih/ -Ib/
b/h/lib$n.a: $(h_o)
	@echo AR	$@
	@mkdir -p $(dir $@)
	@ar rcs $@ $^

b/h/lib$n.so: b/h/lib$n.a
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(cc) -shared -o $@ -Wl,--whole-archive $^ -Wl,--no-whole-archive

b/h/%.o: %.c $(g_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -c $< -o $@

b/h/%.o: h/%.c $(g_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -c -Ib/h $< -o $@

b/h/$n: h/main.c b/h/lib$n.a b/boot.h b/infix.h b/repl.h
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -o $@ h/main.c b/h/lib$n.a

b/h/lcat: h/lcat.c b/h/$x/$x.o
	@echo CC $@
	@$(cc) -o $@ $^

b/repl.h: b/h/lcat $x/repl.$x
	@echo GEN	$@
	@cat $x/repl.$x | b/h/lcat >$@

b/infix.h: b/h/lcat $x/infix.$x
	@echo GEN	$@
	@cat $x/infix.$x | b/h/lcat >$@


# sed command to escape lisp text into C string format
b/boot.h: b/h/lcat $x/boot.$x
	@echo GEN	$@
	@cat $x/boot.$x | b/h/lcat >$@

b/h/$n.1: b/h/$n h/manpage.$x
	@echo GEN	$@
	@$m < h/manpage.$x > $@

# Source list: the Limine build picks up arch.c + the nasm bits and
# omits the efi_*.c files. The EFI build (EFI=1) does the opposite.
ifdef EFI
ifeq ($(filter $a,x86_64 aarch64 riscv64 loongarch64),)
$(error EFI=1 is only wired up for x86_64, aarch64, riscv64, and loongarch64)
endif
CC := clang
CC_IS_CLANG := 1
# Same sources as the Limine build, with two swaps: efi_main.c stands
# in for the Limine boot info, and efi_*.c stays excluded for backends
# that already exist (currently nothing -- the polled-mode stand-in is
# gone). arch.c + the per-arch .S come along; the SysV-tagged C callees
# keep the asm-to-C boundary correct under MS x64 on x86_64 (aarch64's
# default ABI matches the asm's call convention either way).
k_c=$(g_c) $(f_c) $(wildcard k/*.c k/$a/*.c)
k_S=$(wildcard k/$a/*.S)
k_asm=
else
k_c=$(g_c) $(f_c) $(filter-out k/$a/efi_%.c,$(wildcard k/*.c k/$a/*.c))
k_S=$(wildcard k/$a/*.S)
k_asm=$(wildcard k/$a/*.asm)
endif
k_h=$(g_h) $(wildcard k/*.h k/$a/*.h)
# Output objects live under b/k/$a/ for the Limine build and b/k/$a-efi/
# for the EFI build, so the two coexist (different ABI/format objects).
ifdef EFI
k_odir=b/k/$a-efi
else
k_odir=b/k/$a
endif
k_o=$(addprefix $(k_odir)/, $(k_c:.c=.o) $(k_S:.S=.o) $(k_asm:.asm=.o))

kcflags=$(g_cflags)	-nostdinc -ffreestanding -fno-lto -fno-PIC -ffunction-sections -fdata-sections
kldflags := -static -nostdlib --gc-sections -T k/$a/$a.lds -z max-page-size=0x1000
kcppflags := \
	-Ik  -Ib -If -Ig\
	-I k/include/ \
	-isystem k/include/ \
	$(kcppflags) \
	-DLIMINE_API_REVISION=3
ifdef EFI
kcppflags += -DK_EFI
endif

b/k/$n-$a.elf: k/$a/$a.lds $(k_o)
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
b/k/$n-$a.efi: $(k_o) k/$a/$a.efi.lds tools/elf2efi.py
	@echo LD	$(@:.efi=.efi.elf)
	@mkdir -p "$(dir $@)"
	@$(LD) -m $(kefi_elfmach_$a) --no-relax -static -nostdlib --gc-sections \
	  --emit-relocs -T k/$a/$a.efi.lds -e efi_main \
	  $(k_o) -o $(@:.efi=.efi.elf)
	@echo EFI	$@
	@python3 tools/elf2efi.py $(@:.efi=.efi.elf) $@
else
b/k/$n-$a.efi: $(k_o)
	@echo LD	$@
	@mkdir -p "$(dir $@)"
	@$(CC) $(kcflags) $(kcflags_$a) $(kcc_if_clang) -nostdlib -fuse-ld=lld \
	  -Wl,-subsystem:efi_application -Wl,-entry:efi_main \
	  $(k_o) -o $@
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
# .efi recipe above).
ifneq ($(filter $a,riscv64 loongarch64),)
kcc_if_clang=-target $a-unknown-none-elf
else
kcc_if_clang=-target $a-unknown-windows
endif
else
kcc_if_clang=-target $a-unknown-none-elf
endif
endif
ifdef EFI
# Under UEFI we keep the kernel at whatever base the firmware places us
# (image is fully relocatable); -mcmodel=kernel and -mabi=sysv don't
# apply to the windows target, so drop them.
kcflags_x86_64=-m64 -march=x86-64 -mno-80387 -mno-mmx -mno-sse -mno-sse2 -mno-red-zone
else
kcflags_x86_64=-m64 -march=x86-64 -mabi=sysv -mno-80387 -mno-mmx -mno-sse -mno-sse2 -mno-red-zone -mcmodel=kernel
endif
kcflags_aarch64=-mcpu=generic -march=armv8-a+nofp+nosimd -mgeneral-regs-only
kcflags_riscv64=-march=rv64imac -mabi=lp64 -mno-relax $(kcflags_riscv64_$(if $(EFI),efi,limine))
# Limine drops us at VMA 0xffffffff80000000, whose 32-bit truncation
# sign-extends back to the same address -- medlow's lui+addi sequences
# encode it correctly. UEFI loads the image at a runtime-chosen base
# instead, so we need PC-relative addressing (auipc+addi) everywhere;
# medany gives us that, and the PE base relocations only have to fix
# up the 64-bit absolute symbol references in static initializers.
kcflags_riscv64_limine=
kcflags_riscv64_efi=-mcmodel=medany
kcflags_loongarch64=-march=loongarch64 -mabi=lp64s  -mfpu=none -msimd=none \
  $(kcflags_loongarch64_$(if $(EFI),efi,limine))
kcflags_loongarch64_limine=
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
kcflags_loongarch64_efi=-fdirect-access-external-data

kldflags_x86_64=-m elf_x86_64
kldflags_aarch64=-m aarch64elf
kldflags_riscv64=-m elf64lriscv --no-relax
kldflags_loongarch64=-m elf64loongarch

kcc=$(CC) $(kcflags) $(kcflags_$a) $(kcppflags) $(kcc_if_clang)
kcc_loongarch64=-target loongarch64-unknown-none-elf
kcc_riscv64=-target riscv64-unknown-none-elf
kcc_aarch64=-target aarch64-unknown-none-elf
k_nasmflags := -f elf64 -g -F dwarf -Wall -w-reloc-abs-qword -w-reloc-abs-dword -w-reloc-rel-dword


$(k_odir)/%.o: %.c $(g_h) b/boot.h b/repl.h
	@echo CC	$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@

$(k_odir)/%.o: %.S $(g_h)
	@echo AS	$@
	@mkdir -p "$(dir $@)"
	@$(kcc) -c $< -o $@

$(k_odir)/%.o: %.asm $(g_h)
	@echo AS	$@
	@mkdir -p "$(dir $@)"
	@nasm $< -o $@ $(k_nasmflags)

pd_sdk=$(PLAYDATE_SDK_PATH)
pd_src=$(wildcard pd/*.c) $(g_c) $(f_c)
pd_gcc=arm-none-eabi-gcc
pd_cc=$(pd_gcc) -g3
pd_as=$(pd_gcc) -x assembler-with-cpp
pd_opt=-O2 -falign-functions=16 -fomit-frame-pointer
pd_lds=$(patsubst ~%,$(HOME)%,$(pd_sdk)/C_API/buildsupport/link_map.ld)
pd_fpu=-mfloat-abi=hard -mfpu=fpv5-sp-d16 -D__FPU_USED=1
pd_incdir=$(patsubst %,-I %, pd $(pd_sdk)/C_API g b f)
pd_defs =-DTARGET_PLAYDATE=1 -DTARGET_EXTENSION=1 -Dg_tco=0
pd_src +=$(pd_sdk)/C_API/buildsupport/setup.c
pd_o=$(addprefix b/pd/, $(pd_src:.c=.o))
pd_mcflags=-mthumb -mcpu=cortex-m7 $(pd_fpu)
pd_cpflags=\
	$(pd_mcflags) $(pd_opt) $(pd_defs)\
 	-gdwarf-2 -Wall -Wno-unused -Wstrict-prototypes -Wno-unknown-pragmas\
 	-fverbose-asm -Wdouble-promotion -mword-relocations -fno-common\
  -ffunction-sections -fdata-sections -Wa,-ahlms=b/pd/$(notdir $(<:.c=.lst))
pd_ldflags=\
	-nostartfiles $(pd_mcflags) -T$(pd_lds)\
 	-Wl,-Map=b/pd/pdex.map,--cref,--gc-sections,--no-warn-mismatch,--emit-relocs
pd_asflags=$(pd_mcflags) $(pd_opt) -g3 -gdwarf-2 -Wa,-amhls=$(<:.s=.lst)\
  -D__HEAP_SIZE=8388208 \
 	-D__STACK_SIZE=4194304

b/pd/$n.pdx: b/pd/Source/pdex.elf b/pd/Source/pdex.so
	@echo PDC	$@
	@$(pd_sdk)/bin/pdc -sdkpath $(pd_sdk) b/pd/Source $@

b/pd/Source/pdex.%: b/pd/pdex.%
	@echo CP	$@
	@mkdir -p $(dir $@)
	@cp $< $@

b/pd/%.o : %.c | b/boot.h
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) -c $(pd_cpflags) -I pd -I b -I f $(pd_incdir) $< -o $@

b/pd/%.o : %.s
	@echo AS	$@
	@$(pd_as) -c $(pd_asflags) $< -o $@

b/pd/pdex.elf: $(pd_o) $(pd_lds)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(pd_cc) $(pd_o) $(pd_ldflags) -o $@

b/pd/pdex.so: $(pd_src)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@gcc -g -shared -fPIC -lm -Dg_tco=0 -DTARGET_SIMULATOR=1 -DTARGET_EXTENSION=1 $(pd_incdir) -o b/pd/pdex.so $(pd_src)

sim: b/pd/$n.pdx
	@$(pd_sdk)/bin/PlaydateSimulator $^
.PHONY: sim

.PRECIOUS: b/pd/%elf

k_xorriso_x86_64=\
	-b boot/limine/limine-bios-cd.bin \
	-no-emul-boot -boot-load-size 4 -boot-info-table
k_xorriso=xorriso -as mkisofs -quiet -R -r -J\
	-hfsplus -apm-block-size 2048\
	--efi-boot boot/limine/limine-uefi-cd.bin\
	-efi-boot-part --efi-boot-image --protective-msdos-label\
	$(k_xorriso_$a)

b/$n-$a.iso: b/k/$n-$a.elf dl/limine/limine k/limine/limine.conf
	@echo MK $@
	@rm -rf b/iso_root
	@mkdir -p b/iso_root/boot
	@cp $< b/iso_root/boot/kernel
	@mkdir -p b/iso_root/boot/limine
	@cp k/limine/limine.conf b/iso_root/boot/limine/
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

b/$n-$a.hdd: b/k/$n-$a.elf dl/limine/limine k/limine/limine.conf
	@echo MK $@
	@rm -f $@
	@dd if=/dev/zero bs=1M count=0 seek=64 of=$@
	@PATH=$$PATH:/usr/sbin:/sbin sgdisk $@ -n 1:2048 -t 1:ef00
	@mformat -i $@@@1M
	@mmd -i $@@@1M ::/EFI ::/EFI/BOOT ::/boot ::/boot/limine
	@mcopy -i $@@@1M $< ::/boot/kernel
	@mcopy -i $@@@1M k/limine/limine.conf ::/boot/limine
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
# as b/$n-$a.hdd, just without the GPT wrapper and without the Limine
# BOOT*.EFI copies.
k_efi_short_x86_64=BOOTX64
k_efi_short_aarch64=BOOTAA64
k_efi_short_riscv64=BOOTRISCV64
k_efi_short_loongarch64=BOOTLOONGARCH64
b/$n-$a-efi.img: b/k/$n-$a.efi
	@echo MK $@
	@rm -f $@
	@dd if=/dev/zero bs=1M count=0 seek=64 of=$@ 2>/dev/null
	@mformat -i $@ -F
	@mmd -i $@ ::/EFI ::/EFI/BOOT
	@mcopy -i $@ $< ::/EFI/BOOT/$(k_efi_short_$a).EFI

# x86_64's q35 has IDE so `-drive if=ide` works there; QEMU's virt
# machine (aarch64/riscv64) has no IDE controller, so attach the image
# as virtio-blk over the existing virtio-mmio bus instead. loongarch64's
# virt machine wires virtio on PCI (no virtio-mmio bus), so it needs
# virtio-blk-pci explicitly -- the mmio-transport `virtio-blk-device`
# alias fails to bind there.
k_efi_drive_x86_64=-drive if=ide,format=raw,file=$<
k_efi_drive_aarch64=-drive if=none,format=raw,file=$<,id=hd0 -device virtio-blk-device,drive=hd0
k_efi_drive_riscv64=-drive if=none,format=raw,file=$<,id=hd0 -device virtio-blk-device,drive=hd0
k_efi_drive_loongarch64=-drive if=none,format=raw,file=$<,id=hd0 -device virtio-blk-pci,drive=hd0
run-efi: b/$n-$a-efi.img dl/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) $(k_efi_drive_$a)
run-efi-headless: b/$n-$a-efi.img dl/edk2-ovmf/ovmf-code-$a.fd
	$(k_qemu) $(k_efi_drive_$a) -display none -no-reboot
.PHONY: run-efi run-efi-headless

k_qemu_x86_64=-M q35 -serial stdio
k_qemu_risc=-device ramfb -device qemu-xhci -device usb-kbd -device usb-mouse
k_qemu_loongarch64=-M virt -cpu la464 -serial stdio $(k_qemu_risc)
k_qemu_aarch64=-M virt,gic-version=2 -cpu cortex-a72 -serial stdio $(k_qemu_risc)
k_qemu_riscv64=-M virt -cpu rv64 -serial stdio $(k_qemu_risc)
k_qemu=qemu-system-$a -m 256M $(k_qemu_$a)\
	-drive if=pflash,unit=0,format=raw,file=dl/edk2-ovmf/ovmf-code-$a.fd,readonly=on

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
.PHONY: run run-hdd run-$a run-hdd-$a run-headless

dl/edk2-ovmf/ovmf-code-%.fd:
	@echo MK ovmf
	@mkdir -p dl
	@curl -L https://github.com/osdev0/edk2-ovmf-nightly/releases/latest/download/edk2-ovmf.tar.gz | gunzip | tar -C dl -xf -
#	@curl -sLo $@ https://github.com/osdev0/edk2-ovmf-nightly/releases/latest/download/$(notdir $@)
	@case "$a" in \
		aarch64) dd if=/dev/zero of=$@ bs=1 count=0 seek=67108864 2>/dev/null;; \
		riscv64) dd if=/dev/zero of=$@ bs=1 count=0 seek=33554432 2>/dev/null;; \
	esac

dl/limine/limine:
	@echo MK limine
	@rm -rf dl/limine
	@git clone https://codeberg.org/Limine/Limine.git dl/limine --branch=v10.x-binary --depth=1 > /dev/null 2>&1
	@make -sC dl/limine

# installlation
# default install to home directory under ~/.local/
PREFIX ?= .local/
VIMPREFIX ?= .vim/
DESTDIR ?= $(HOME)/
d=$(DESTDIR)/$(PREFIX)
v=$(DESTDIR)/$(VIMPREFIX)
installs=\
 	$d/bin/$n\
		$d/bin/$nsh\
  $d/g/man/man1/$n.1\
		$d/lib/$n/boot.$x\
		$d/lib/$n/repl.$x\
  $d/lib/lib$n.a\
  $d/lib/lib$n.so\
  $d/include/$x.h\
  $v/ftdetect/$n.vim\
  $v/syntax/$n.vim\
  $v/ftplugin/$n.vim

.PHONY: install uninstall
install: $(installs)
uninstall:
	@echo RM	$(abspath $(installs))
	@rm -f $(installs)

$d/include/$x.h: g/$x.h
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/$n/boot.$x: g/boot.g
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/$n/%.$x: h/%.$x
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/lib$n.a: b/h/lib$n.a
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/lib$n.so: b/h/lib$n.so
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

$d/bin/$n: b/h/$n
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

$d/bin/$nsh: h/$nsh
	@echo CP	$(abspath $@)
	@install -D -m 755 $< $@

$d/g/man/man1/$n.1: b/h/$n.1
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
