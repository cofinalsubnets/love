#!/bin/sh
# test/gate/hearts-boot.sh -- hearts rung 0 under qemu virt (a64): the image boots our
# chooser (src/inle/uefi/slot.c), our kernel (the Image test_hearts certified) and helm as
# pid 1 off a squashfs root, then walks three updates in one run: one signed by another key
# (refused), v2 into slot b (tried, well, committed), and v3 into slot a, which never says it
# is well -- so the watch restarts it and it comes back on b. the serial log must say so, in order.
# usage: hearts-boot.sh LOVE XLOVE CAT   (XLOVE the a64 love, CAT the carried tree it bakes from)
# kvm when this box is a64 with /dev/kvm; HEARTS_BOOT_TIMEOUT bounds the run (default 1500 s).
. test/gate/skip.sh
set -u

love=$1 xlove=$2 cat=$3
R=$(pwd)
C=${HEARTS_CACHE:-$HOME/.cache/hearts}
K=$C/Image-6.19.14
KSHA=c15b13e63cb108a1e78f5d2aa10242b52d7efa9417723cc514d30c11889a73be
fail() { echo "FAIL hearts-boot: $*" >&2; exit 1; }
command -v qemu-system-aarch64 >/dev/null 2>&1 || gate_skip "hearts-boot: no qemu-system-aarch64, skipped"
dl=${DL:-$(sh src/tools/dlfind.sh .)}
fw=$dl/edk2-ovmf/ovmf-code-aarch64.fd
[ -f "$fw" ] || gate_skip "hearts-boot: no dl/edk2-ovmf/ovmf-code-aarch64.fd, skipped"
vars=$(dirname "$fw")/ovmf-vars-aarch64.fd
[ -f "$K" ] || fail "no $K -- a green test_hearts keeps it"
[ "$(sha256sum < "$K" | cut -d" " -f1)" = "$KSHA" ] || fail "$K is not the certified Image $KSHA"
w=$(mktemp -d -p /var/tmp) || exit 1
trap 'rm -rf "$w"' EXIT

# the a64 love, baked where it runs: natively on an a64 box, else under qemu-user
case $(uname -m) in
  aarch64) run= ;;
  *) command -v qemu-aarch64 >/dev/null 2>&1 || gate_skip "hearts-boot: no qemu-aarch64 to bake on, skipped"
     run=qemu-aarch64 ;;
esac
LOVE_NO_IMAGE=1 $run "$xlove" bake -o "$w/love" -l "$cat" > "$w/bake.log" 2>&1 \
  || { tail -5 "$w/bake.log"; fail "the a64 bake"; }

# the chooser, by mooncc and mkefi
"$love" mooncc -t a64 -c src/inle/uefi/slot.c -o "$w/slot.o" || fail "mooncc on slot.c"
{ echo "(borrow 'holo)"; cat src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/asbook.l \
    src/love/holo/elf.l src/love/holo/obj.l src/love/holo/link.l src/love/holo/pe.l src/inle/uefi/mkefi.l
  echo "(mkboot \"$w/BOOTAA64.EFI\" \"a64\" (list \"$w/slot.o\"))"; } | "$love" > "$w/efi.log" 2>&1 \
  || { tail -5 "$w/efi.log"; fail "mkefi"; }

seed=$(printf 'hearts rung 0 key' | sha256sum | cut -c1-64)
bad=$(printf 'hearts rung 0 other key' | sha256sum | cut -c1-64)
"$love" -l src/apps/sqfs.l src/apps/hearts/image.l "$w" "$w/love" "$K" "$w/BOOTAA64.EFI" "$seed" "$bad" \
  || fail "the image"

cp "$vars" "$w/vars.fd"
accel="-cpu cortex-a72"
[ "$(uname -m)" = aarch64 ] && [ -w /dev/kvm ] && accel="-enable-kvm -cpu host"
# shellcheck disable=SC2086
timeout "${HEARTS_BOOT_TIMEOUT:-1500}" qemu-system-aarch64 -M virt $accel -m 2048 -smp 2 \
  -drive if=pflash,format=raw,readonly=on,file="$fw" -drive if=pflash,format=raw,file="$w/vars.fd" \
  -drive file="$w/disk.img",if=virtio,format=raw \
  -drive file="$w/u1.hup",if=virtio,format=raw,readonly=on \
  -drive file="$w/u2.hup",if=virtio,format=raw,readonly=on \
  -drive file="$w/u3.hup",if=virtio,format=raw,readonly=on \
  -display none -serial file:"$w/serial.log" -monitor none > "$w/qemu.log" 2>&1
rc=$?
cp "$w/serial.log" /var/tmp/hearts-boot.serial 2>/dev/null
[ $rc = 0 ] || { tail -30 "$w/serial.log"; fail "qemu exited $rc (the log: /var/tmp/hearts-boot.serial)"; }

# the story, in order: each line must follow the one before it
grep -a '^hearts: ' "$w/serial.log" | tr -d '\r' > "$w/story"
pos=0
for want in "hearts: slot a" "hearts: app v1" "hearts: well on slot a" "refused /dev/vdb" \
    "written to slot b" "hearts: slot b, a trial" "hearts: app v2" "well on slot b: committed" \
    "written to slot a" "hearts: slot a, a trial" "hearts: app v3" "app sick" \
    "slot a never said it was well: back to slot b" "hearts: slot b" "hearts: app v2" "hearts: done"; do
  n=$(tail -n +$((pos + 1)) "$w/story" | grep -n -F -m1 -- "$want" | cut -d: -f1)
  [ -n "$n" ] || { cat "$w/story"; fail "the log never says '$want' after line $pos"; }
  pos=$((pos + n))
done
echo "hearts-boot: ok (v1 on a, a refused update, v2 committed on b, v3 reverted to b)"
