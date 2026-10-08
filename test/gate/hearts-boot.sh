#!/bin/sh
# test/gate/hearts-boot.sh -- hearts rung 0 under qemu virt (a64): the image boots our chooser
# (src/inle/uefi/slot.c), which inflates and starts our kernel (the Image test_hearts certified,
# gzipped), and helm as pid 1 off a squashfs root, then walks four updates in one run: one signed
# by another key (refused), one whose root lost a byte under a good head (refused once it streams
# past), v2 into slot b (tried, well, committed), and v3 into slot a, which never says it is well --
# so the watch restarts it and it comes back on b. the serial log must say so, in order.
# and the image is reproducible: its a64 half (test/gate/hearts-run.sh) bakes, builds and boots on
# an a64 host under kvm, and here the chooser and the image are built again -- twice, from that
# host's baked love -- and every byte must match. with no a64 host the half runs here (qemu-user,
# tcg) and the cross-host check is a skip.
# usage: hearts-boot.sh LOVE XLOVE CAT   (XLOVE the a64 love, CAT the carried tree it bakes from)
. test/gate/skip.sh
set -u

love=$1 xlove=$2 cat=$3
C=${HEARTS_CACHE:-$HOME/.cache/hearts}
KSHA=06008d280d8e6311965b35efcc7f544d76e88b236a443c675ca24b41a61c47cd
K=$C/Image-6.19.14-$(echo $KSHA | cut -c1-16)
stamp=${HEARTS_STAMP:-0}
fail() { echo "FAIL hearts-boot: $*" >&2; exit 1; }
dl=${DL:-$(sh src/tools/dlfind.sh .)}
fw=$dl/edk2-ovmf/ovmf-code-aarch64.fd
[ -f "$fw" ] || gate_skip "hearts-boot: no dl/edk2-ovmf/ovmf-code-aarch64.fd, skipped"
[ -f "$K" ] || fail "no $K -- a green test_hearts keeps it"
[ "$(sha256sum < "$K" | cut -d" " -f1)" = "$KSHA" ] || fail "$K is not the certified Image $KSHA"
w=$(mktemp -d -p /var/tmp) || exit 1
trap 'rm -rf "$w"' EXIT

# the a64 half's directory: the unbaked love, its tree, the kernel, the firmware, the sources
s=$w/ship
mkdir -p "$s/fw"
cp "$xlove" "$s/love" && cp "$cat" "$s/cat.l" && cp "$K" "$s/Image" && cp test/gate/hearts-run.sh "$s/" \
  && cp "$fw" "$s/fw/code.fd" && cp "$(dirname "$fw")/ovmf-vars-aarch64.fd" "$s/fw/vars.fd" || fail "cannot lay $s"
for f in src/apps/sqfs.l src/apps/ext4.l src/apps/hearts/image.l src/apps/hearts/dev.l src/apps/hearts/app.l \
    src/apps/helm/unit.l src/apps/helm/sup.l src/apps/helm/moor.l src/apps/helm/helm.l \
    src/inle/uefi/slot.c src/love/inflate.h src/love/inf.h src/inle/uefi/mkefi.l src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/asbook.l \
    src/love/holo/elf.l src/love/holo/obj.l src/love/holo/link.l src/love/holo/pe.l; do
  mkdir -p "$s/$(dirname $f)" && cp "$f" "$s/$f" || fail "cannot lay $f"
done

r=$w/remote
mkdir -p "$r"
if "$love" bee --on kvm-a64 --probe > /dev/null 2>&1; then
  where="an a64 host, kvm"
  "$love" bee --on kvm-a64 --ship "$s" -- sh hearts-run.sh "" "" kvm "$stamp" > "$w/remote.tar" 2> "$w/remote.err" \
    || { tail -20 "$w/remote.err"; fail "the a64 half on the a64 host"; }
else
  where="here, qemu-user and tcg"
  command -v qemu-system-aarch64 >/dev/null 2>&1 || gate_skip "hearts-boot: no qemu-system-aarch64, skipped"
  command -v qemu-aarch64 >/dev/null 2>&1 || gate_skip "hearts-boot: no qemu-aarch64, skipped"
  (cd "$s" && sh hearts-run.sh qemu-aarch64 "$love" tcg "$stamp") > "$w/remote.tar" 2> "$w/remote.err" \
    || { tail -20 "$w/remote.err"; fail "the a64 half here"; }
fi
tar xf "$w/remote.tar" -C "$r" || fail "the a64 half sent no tar"
cp "$r/serial.log" /var/tmp/hearts-boot.serial 2>/dev/null
[ "$(cat "$r/qemu.rc")" = 0 ] || { tail -30 "$r/serial.log"; fail "qemu exited $(cat "$r/qemu.rc") ($where; the log: /var/tmp/hearts-boot.serial)"; }

# the story, in order: each line must follow the one before it
grep -a '^hearts: ' "$r/serial.log" | tr -d '\r' > "$w/story"
pos=0
for want in "hearts: slot a" "hearts: app v1" "hearts: well on slot a" "refused /dev/vdb: not signed" \
    "refused /dev/vdc: a part is not what its head signed" \
    "written to slot b" "hearts: slot b, a trial" "hearts: app v2" "well on slot b: committed" \
    "written to slot a" "hearts: slot a, a trial" "hearts: app v3" "app sick" \
    "slot a never said it was well: back to slot b" "hearts: slot b" "hearts: app v2" "hearts: done"; do
  n=$(tail -n +$((pos + 1)) "$w/story" | grep -n -F -m1 -- "$want" | cut -d: -f1)
  [ -n "$n" ] || { cat "$w/story"; fail "the log never says '$want' after line $pos"; }
  pos=$((pos + n))
done

# the same bytes here: the chooser by this host's mooncc, the image twice from the a64 half's love
"$love" mooncc -t a64 -c src/inle/uefi/slot.c -o "$w/slot.o" || fail "mooncc on slot.c"
{ echo "(borrow 'holo)"; cat src/apps/kore/text.l src/apps/kore/u.l src/apps/kore/asbook.l \
    src/love/holo/elf.l src/love/holo/obj.l src/love/holo/link.l src/love/holo/pe.l src/inle/uefi/mkefi.l
  echo "(mkboot \"$w/BOOTAA64.EFI\" \"a64\" (list \"$w/slot.o\"))"; } | "$love" > "$w/efi.log" 2>&1 \
  || { tail -5 "$w/efi.log"; fail "mkefi"; }
cmp -s "$w/BOOTAA64.EFI" "$r/BOOTAA64.EFI" || fail "the chooser built here differs from the a64 host's"
seed=$(printf 'hearts rung 0 key' | sha256sum | cut -c1-64)
bad=$(printf 'hearts rung 0 other key' | sha256sum | cut -c1-64)
for i in 1 2; do
  mkdir -p "$w/i$i"
  "$love" -l src/apps/sqfs.l -l src/apps/ext4.l src/apps/hearts/image.l "$w/i$i" "$r/love" "$K" "$r/BOOTAA64.EFI" "$seed" "$bad" "$stamp" \
    || fail "the image here ($i)"
  (cd "$w/i$i" && sha256sum disk.img u1.hup u2.hup u3.hup u4.hup) > "$w/i$i.shas"
  grep -v ' BOOTAA64.EFI$\| love$' "$r/shas" | cmp -s - "$w/i$i.shas" \
    || { diff "$w/i$i.shas" "$r/shas" >&2; fail "the image built here ($i) differs from the a64 host's"; }
done
img=$(grep ' disk.img$' "$r/shas" | cut -c1-16)
case $where in
  here*) gate_skip "hearts-boot: story ok and the image ($img) the same twice here, but no a64 host to build it (bee's registry: kvm-a64), skipped" ;;
esac
echo "hearts-boot: ok ($where; v1 on a, two refused updates, v2 committed on b, v3 reverted to b; the image $img, the same bytes there and twice here)"
