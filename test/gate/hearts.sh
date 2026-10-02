#!/bin/sh
# test/gate/hearts.sh -- hearts builds the arm64 defconfig kernel Image byte-identical to
# kbuild's. from the pinned tarball: kbuild+clang makes defconfig and Image, then hearts
# (src/apps/hearts/build.l) makes defconfig, syncconfig and Image from an empty output dir,
# and the two Images must be the same bytes. both build at one canonical path, since the
# vdso's build-id hashes debug info that names the source and output dirs and the vdso is
# in the image; the build's identity is pinned. the toolchain is the host's (clang, lld,
# llvm, flex, bison, perl), borrowed. heavy (two kernel builds); opt-in by name.
# usage: hearts.sh LOVE
. test/gate/skip.sh
set -u

love=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
R=$(pwd)
V=6.19.14
SHA=cde8bf6739be4a0777fedbbba5330b8188c55680c45a922a4dfa289cbec6f185
C=${HEARTS_CACHE:-$HOME/.cache/hearts}
B=/var/tmp/hearts
K=$B/linux-$V
O=$B/o
J=${HEARTS_GATE_JOBS:-8}
fail() { echo "FAIL hearts: $*" >&2; exit 1; }

for t in make clang ld.lld llvm-ar llvm-objcopy flex bison perl curl; do
  command -v $t >/dev/null 2>&1 || gate_skip "hearts: no $t, skipped"
done
mkdir -p "$B" "$C/src" || fail "cannot make $B"
mkdir "$B/.lock" 2>/dev/null || fail "$B is in use ($B/.lock)"
trap 'rm -rf "$O" "$B/ref" "$B/.lock"' EXIT

tgz=$C/src/linux-$V.tar.xz
[ -f "$tgz" ] || curl -sSfL -o "$tgz" "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$V.tar.xz" \
  || gate_skip "hearts: cannot fetch linux-$V, skipped"
[ "$(sha256sum < "$tgz" | cut -d' ' -f1)" = "$SHA" ] || fail "$tgz is not the pinned linux-$V"
rm -rf "$K" "$O" "$B/ref"
(cd "$B" && tar xf "$tgz") || fail "cannot unpack $tgz"

# each half compiles for itself: a compile cache would hand hearts kbuild's objects
export CCACHE_DISABLE=1
export KBUILD_BUILD_USER=hearts KBUILD_BUILD_HOST=hearts KBUILD_BUILD_VERSION=1
export KBUILD_BUILD_TIMESTAMP='Thu Jan  1 00:00:00 UTC 2026'

mkdir -p "$O"
(cd "$K" && make O="$O" LLVM=1 ARCH=arm64 defconfig && make O="$O" LLVM=1 ARCH=arm64 -j"$J" Image) \
  > "$B/ref.log" 2>&1 || { tail -20 "$B/ref.log"; fail "kbuild's own build failed"; }
mv "$O" "$B/ref" || fail "cannot set kbuild's build aside"

mkdir -p "$O"
(cd "$O" && HEARTS_SRC="$K" HEARTS_JOBS="$J" LOVE_BUDGET_MB=${LOVE_BUDGET_MB:-1500} \
  "$love" "$R/src/apps/hearts/build.l") > "$B/hearts.log" 2>&1 \
  || { tail -20 "$B/hearts.log"; fail "hearts' build failed"; }

for f in .config arch/arm64/boot/Image; do
  [ -f "$O/$f" ] || fail "hearts made no $f"
  cmp -s "$B/ref/$f" "$O/$f" || fail "$f differs from kbuild's"
done
echo "hearts: Image $(sha256sum < "$O/arch/arm64/boot/Image" | cut -c1-16) = kbuild+clang's, from linux-$V defconfig"
