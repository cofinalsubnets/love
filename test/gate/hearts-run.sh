#!/bin/sh
# test/gate/hearts-run.sh -- the a64 half of test_hearts_boot, run where test/gate/hearts-boot.sh
# laid it: on an a64 host (bee's registry, kvm-a64), or here under qemu-user and tcg. bakes the a64
# love, builds the chooser and the image with TOOL, boots the image, and writes a tar of out/ (the
# baked love, BOOTAA64.EFI, shas, serial.log, qemu.rc) to stdout -- every other word to stderr.
# the directory holds love (the a64 love, unbaked), cat.l, Image, fw/code.fd fw/vars.fd and the
# sources at their tree paths.
# usage: hearts-run.sh BAKE TOOL ACCEL STAMP   (BAKE "" or qemu-aarch64; TOOL a love, "" for the
#        baked one; ACCEL kvm or tcg)
set -u
bake=$1 tool=${2:-./out/love} accel=$3 stamp=$4
die() { echo "hearts-run: $*" >&2; exit 1; }
mkdir -p out
LOVE_NO_IMAGE=1 $bake ./love bake -o out/love -l cat.l > out/bake.log 2>&1 || { tail -5 out/bake.log >&2; die "the bake"; }
$tool mooncc -t a64 -c src/inle/uefi/slot.c -o out/slot.o >&2 || die "mooncc on slot.c"
{ echo "(borrow 'holo)"; cat src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/asbook.l \
    src/love/holo/elf.l src/love/holo/obj.l src/love/holo/link.l src/love/holo/pe.l src/inle/uefi/mkefi.l
  echo '(mkboot "out/BOOTAA64.EFI" "a64" (list "out/slot.o"))'; } | $tool > out/efi.log 2>&1 \
  || { tail -5 out/efi.log >&2; die "mkefi"; }
seed=$(printf 'hearts rung 0 key' | sha256sum | cut -c1-64)
bad=$(printf 'hearts rung 0 other key' | sha256sum | cut -c1-64)
$tool -l src/apps/sqfs.l src/apps/hearts/image.l out out/love Image out/BOOTAA64.EFI "$seed" "$bad" "$stamp" >&2 \
  || die "the image"
(cd out && sha256sum disk.img u1.hup u2.hup u3.hup BOOTAA64.EFI love > shas)
case $accel in kvm) a="-enable-kvm -cpu host" ;; *) a="-cpu cortex-a72" ;; esac
cp fw/vars.fd out/vars.fd
# shellcheck disable=SC2086
timeout "${HEARTS_BOOT_TIMEOUT:-1500}" qemu-system-aarch64 -M virt $a -m 2048 -smp 2 \
  -drive if=pflash,format=raw,readonly=on,file=fw/code.fd -drive if=pflash,format=raw,file=out/vars.fd \
  -drive file=out/disk.img,if=virtio,format=raw \
  -drive file=out/u1.hup,if=virtio,format=raw,readonly=on \
  -drive file=out/u2.hup,if=virtio,format=raw,readonly=on \
  -drive file=out/u3.hup,if=virtio,format=raw,readonly=on \
  -display none -serial file:out/serial.log -monitor none > out/qemu.log 2>&1
echo $? > out/qemu.rc
tar cf - -C out love BOOTAA64.EFI shas serial.log qemu.rc qemu.log
