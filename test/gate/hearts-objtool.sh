#!/bin/sh
# test/gate/hearts-objtool.sh -- hearts builds the kernel's own objtool for x86, by mooncc on elfutils'
# libelf (src/apps/hearts/libelf.l), and it answers byte for byte as the host-built one does. from
# the pinned linux and elfutils tarballs, hearts makes defconfig, syncconfig, headers and tools/objtool
# in an empty output dir; that objtool then runs the vmlinux.o pass on a kept x86 defconfig vmlinux.o,
# and its output is the host objtool's, pinned by hash. the pair lives in $C/objtool: pre.o is clang's
# ld.lld -r of a defconfig build's vmlinux.a, ot.o that after the tree's own objtool --link. heavy-ish
# (a few minutes, 2G); opt-in by name.
# usage: hearts-objtool.sh LOVE
. test/gate/skip.sh
set -u

love=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
R=$(pwd)
V=6.19.14
SHA=cde8bf6739be4a0777fedbbba5330b8188c55680c45a922a4dfa289cbec6f185
EV=0.197
ESHA=1fdf525f22dcf796d99a99ba3ea00a1f7b1ae5421bc62e8443a708920b99b904
PSHA=05db1e5e76ccce19ee525186f10baf4697819c26fd3854a6065bd75d98a8c15b
OSHA=8b81b438b1dd70e39a191cdce295bc2e7e6dc0bf84d7152daed5851c7fd4dfac
C=${HEARTS_CACHE:-$HOME/.cache/hearts}
B=/var/tmp/hearts-objtool
K=$B/linux-$V
E=$B/elfutils-$EV
O=$B/o
fail() { echo "FAIL hearts-objtool: $*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || gate_skip "hearts-objtool: no curl, skipped"
pre=$C/objtool/vmlinux-$V.pre.o
[ -f "$pre" ] || gate_skip "hearts-objtool: no $pre, skipped"
[ "$(sha256sum < "$pre" | cut -d' ' -f1)" = "$PSHA" ] || fail "$pre is not the pinned vmlinux.o"
# one run at a time in $B, under bee's lock named by it
[ -n "${HEARTS_HELD:-}" ] || { export HEARTS_HELD=1; exec "$love" bee --lock --out "$B" -- "$love" lush -g "$0" "$1"; }
mkdir -p "$B" "$C/src" || fail "cannot make $B"

tgz=$C/src/linux-$V.tar.xz
[ -f "$tgz" ] || curl -sSfL -o "$tgz" "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$V.tar.xz" \
  || gate_skip "hearts-objtool: cannot fetch linux-$V, skipped"
[ "$(sha256sum < "$tgz" | cut -d' ' -f1)" = "$SHA" ] || fail "$tgz is not the pinned linux-$V"
etb=$C/src/elfutils-$EV.tar.bz2
[ -f "$etb" ] || curl -sSfL -o "$etb" "https://sourceware.org/elfutils/ftp/$EV/elfutils-$EV.tar.bz2" \
  || gate_skip "hearts-objtool: cannot fetch elfutils-$EV, skipped"
[ "$(sha256sum < "$etb" | cut -d' ' -f1)" = "$ESHA" ] || fail "$etb is not the pinned elfutils-$EV"
rm -rf "$K" "$E" "$O"
(cd "$B" && tar xf "$tgz" && tar xf "$etb") || fail "cannot unpack the tarballs"
for p in "$R"/src/apps/hearts/patches/*.patch; do
  [ -f "$p" ] || continue
  patch -d "$K" -p1 -s < "$p" || fail "cannot apply $p"
done

mkdir -p "$O"
(cd "$O" && HEARTS_SRC="$K" HEARTS_ARCH=x86_64 HEARTS_ELFUTILS="$E" \
  HEARTS_GOALS="defconfig syncconfig headers tools/objtool" "$love" "$R/src/apps/hearts/build.l") > "$B/hearts.log" 2>&1 \
  || { tail -20 "$B/hearts.log"; fail "hearts' build failed"; }
ot=$O/tools/objtool/objtool
[ -x "$ot" ] || fail "hearts made no objtool"

# the vmlinux.o pass of an IBT defconfig, as scripts/Makefile.vmlinux_o runs it
cp "$pre" "$B/vmlinux.o" || fail "cannot copy $pre"
"$ot" --hacks=jump_label --hacks=noinstr --hacks=skylake --ibt --orc --retpoline --rethunk --static-call \
  --uaccess --prefix=16 --noinstr --unret --link "$B/vmlinux.o" > "$B/objtool.log" 2>&1 \
  || { tail -20 "$B/objtool.log"; fail "objtool refused vmlinux.o"; }
[ "$(sha256sum < "$B/vmlinux.o" | cut -d' ' -f1)" = "$OSHA" ] || fail "objtool's vmlinux.o is not the host objtool's"
rm -rf "$K" "$E" "$O" "$B/vmlinux.o"
echo "hearts-objtool: objtool by mooncc on elfutils-$EV's libelf, from linux-$V; its vmlinux.o pass is the host's"
