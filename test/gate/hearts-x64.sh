#!/bin/sh
# test/gate/hearts-x64.sh -- hearts builds the x86_64 defconfig bzImage with mooncc, and it boots
# under q35 and OVMF, the firmware starting it as its own EFI program. from the pinned linux and
# elfutils tarballs and the tree's patches, hearts (src/apps/hearts/build.l, HEARTS_ARCH=x86_64)
# makes defconfig, syncconfig, headers and bzImage in an empty output dir: every unit by mooncc
# (its asm by holo) through kcc.l, objtool by mooncc on elfutils' libelf, every link by love's ld,
# the host programs by mooncc, the commands through lush. clang keeps what mooncc never takes
# (-E, -S), each file it lays named in .hearts/kcc.log and listed here.
# the bzImage must be a PE for the firmware, and the kernel must be entered through its EFI stub
# (OVMF's -kernel loader starts a PE as one, its load options the command line); init, ours (mooncc, love's cpio), says so and powers
# off. kvm where /dev/kvm opens, else tcg. a green run keeps the bzImage, named in
# $C/bzImage-$V.green. heavy (a kernel build, hours); opt-in by name.
# usage: hearts-x64.sh LOVE
. test/gate/skip.sh
. test/gate/dl.sh
set -u

love=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
R=$(pwd)
V=6.19.14
SHA=cde8bf6739be4a0777fedbbba5330b8188c55680c45a922a4dfa289cbec6f185
EV=0.197
ESHA=1fdf525f22dcf796d99a99ba3ea00a1f7b1ae5421bc62e8443a708920b99b904
C=${HEARTS_CACHE:-$HOME/.cache/hearts}
B=${HEARTS_X64_DIR:-$C/x64}
K=$B/linux-$V
E=$B/elfutils-$EV
O=$B/o
J=${HEARTS_GATE_JOBS:-6}
fail() { echo "FAIL hearts-x64: $*" >&2; exit 1; }

for t in clang curl qemu-system-x86_64; do
  command -v $t >/dev/null 2>&1 || gate_skip "hearts-x64: no $t, skipped"
done
dl_need edk2-ovmf
fw=$DL/edk2-ovmf/ovmf-code-x86_64.fd
# one run at a time in $B, under bee's lock named by it
[ -n "${HEARTS_HELD:-}" ] || { export HEARTS_HELD=1; exec "$love" bee --lock --out "$B" -- "$love" lush -g "$0" "$1"; }
mkdir -p "$B" "$C/src" || fail "cannot make $B"
# a red run keeps its build and boot log to read (the next run clears them); a green one leaves nothing

tgz=$C/src/linux-$V.tar.xz
[ -f "$tgz" ] || curl -sSfL -o "$tgz" "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$V.tar.xz" \
  || gate_skip "hearts-x64: cannot fetch linux-$V, skipped"
[ "$(sha256sum < "$tgz" | cut -d' ' -f1)" = "$SHA" ] || fail "$tgz is not the pinned linux-$V"
etb=$C/src/elfutils-$EV.tar.bz2
[ -f "$etb" ] || curl -sSfL -o "$etb" "https://sourceware.org/elfutils/ftp/$EV/elfutils-$EV.tar.bz2" \
  || gate_skip "hearts-x64: cannot fetch elfutils-$EV, skipped"
[ "$(sha256sum < "$etb" | cut -d' ' -f1)" = "$ESHA" ] || fail "$etb is not the pinned elfutils-$EV"
rm -rf "$K" "$E" "$O" "$B/boot"
(cd "$B" && tar xf "$tgz" && tar xf "$etb") || fail "cannot unpack the tarballs"
for p in "$R"/src/apps/hearts/patches/*.patch; do
  [ -f "$p" ] || continue
  patch -d "$K" -p1 -s < "$p" || fail "cannot apply $p"
done

# the build's identity, so no clock or host name reaches the image
export CCACHE_DISABLE=1
export KBUILD_BUILD_USER=hearts KBUILD_BUILD_HOST=hearts KBUILD_BUILD_VERSION=1
export KBUILD_BUILD_TIMESTAMP='Thu Jan  1 00:00:00 UTC 2026'

mkdir -p "$O"
(cd "$O" && HEARTS_SRC="$K" HEARTS_ARCH=x86_64 HEARTS_ELFUTILS="$E" HEARTS_JOBS="$J" HEARTS_KGZIP="$love gzip" \
  "$love" "$R/src/apps/hearts/build.l") > "$B/hearts.log" 2>&1 \
  || { tail -20 "$B/hearts.log"; fail "hearts' build failed"; }
I=$O/arch/x86/boot/bzImage
[ -f "$I" ] || fail "hearts made no bzImage"
n=0; [ -f "$O/.hearts/kcc.log" ] && n=$(wc -l < "$O/.hearts/kcc.log")
[ "$n" -eq 0 ] || { echo "hearts-x64: $n files are clang's:"; sed 's/^/  /' "$O/.hearts/kcc.log"; }

# a PE the firmware loads: MZ, the PE header where e_lfanew says, x86-64, an EFI application
pe=$(od -A n -t u4 -j 60 -N 4 "$I" | tr -d ' ')
[ "$(od -A n -c -N 2 "$I" | tr -d ' ')" = MZ ] || fail "the bzImage has no MZ header"
[ "$(od -A n -t x1 -j "$pe" -N 6 "$I" | tr -d ' ')" = 504500006486 ] || fail "the bzImage is no x86-64 PE"
[ "$(od -A n -t u2 -j $((pe + 24 + 68)) -N 2 "$I" | tr -d ' ')" = 10 ] || fail "the bzImage is no EFI application"

# pid 1: say so, then power off
d=$B/boot; mkdir -p "$d"
cat > "$d/init.c" <<'EOF'
#include <unistd.h>
#include <sys/reboot.h>
int main(void) {
  static char const m[] = "hearts: init ran\n";
  write(1, m, sizeof m - 1);
  sync();
  reboot(0x4321fedc);
  for (;;) sleep(60); }
EOF
"$love" mooncc -t x64 -O2 -o "$d/init" "$d/init.c" || fail "mooncc on init.c"
(cd "$d" && echo init | "$love" cpio -o -H newc > init.cpio 2> /dev/null) || fail "cpio on init"
cp "$DL/edk2-ovmf/ovmf-vars-x86_64.fd" "$d/vars.fd" || fail "cannot copy the firmware's vars"
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then a="-enable-kvm -cpu host"; where=kvm; else a="-cpu max"; where=tcg; fi
# shellcheck disable=SC2086
timeout "${HEARTS_BOOT_SECS:-900}" qemu-system-x86_64 -M q35 $a -m 1G -smp 2 -display none -no-reboot \
  -drive if=pflash,format=raw,readonly=on,file="$fw" -drive if=pflash,format=raw,file="$d/vars.fd" \
  -serial file:"$d/serial.log" -monitor none -kernel "$I" -initrd "$d/init.cpio" \
  -append "console=ttyS0 panic=-1 rdinit=/init" > "$d/qemu.log" 2>&1
grep -a -q '\] efi: EFI v' "$d/serial.log" || { tail -20 "$d/serial.log"; fail "the kernel was not entered through its EFI stub"; }
grep -a -q '^hearts: init ran' "$d/serial.log" || { tail -20 "$d/serial.log"; fail "the bzImage did not boot to init"; }
grep -a -q 'reboot: Power down' "$d/serial.log" || { tail -20 "$d/serial.log"; fail "init ran, but no power off"; }
e='WARNING|BUG|Oops|Kernel panic|Internal error'
w=$(grep -a -c -E "$e" "$d/serial.log")
[ "$w" -eq 0 ] || { grep -a -E "$e" "$d/serial.log" | head; fail "the boot logged $w faults"; }

# the bzImage a green run certifies, kept under its own hash and named in bzImage-$V.green
sha=$(sha256sum < "$I" | cut -d' ' -f1)
s16=$(echo "$sha" | cut -c1-16)
cp "$I" "$C/bzImage-$V-$s16.new" && mv "$C/bzImage-$V-$s16.new" "$C/bzImage-$V-$s16" \
  && echo "$sha" > "$C/bzImage-$V.green.new" && mv "$C/bzImage-$V.green.new" "$C/bzImage-$V.green" \
  || fail "cannot keep the bzImage in $C"
rm -rf "$K" "$E" "$O" "$d"
echo "hearts-x64: bzImage $s16 by mooncc ($n files clang's) from linux-$V and the tree's patches, defconfig; the firmware starts it as an EFI program ($where) and it boots to init"
