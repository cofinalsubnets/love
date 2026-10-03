#!/bin/sh
# test/gate/hearts.sh -- hearts builds the arm64 defconfig kernel Image byte-identical to
# kbuild's. from the pinned tarball: kbuild+clang makes defconfig and Image, then hearts
# (src/apps/hearts/build.l) makes defconfig, syncconfig and Image from an empty output dir,
# and the two Images must be the same bytes. both build at one canonical path, since the
# vdso's build-id hashes debug info that names the source and output dirs and the vdso is
# in the image; the build's identity is pinned. kbuild's half borrows the host's toolchain
# (clang, lld, llvm, flex, bison, perl). hearts' half borrows only clang/lld/llvm for the kernel's
# own units: the host programs build with mooncc (but certs/extract-cert, which wants openssl),
# flex and bison are ours (src/tools/moon-flex.sh, moon-bison.sh), perl's scripts are ported,
# and the commands run through lush with kore's verbs. where a tool's bytes reach the Image
# (config_data.gz), kbuild's half borrows OUR tool too: KGZIP is love's gzip on both sides.
# heavy (two kernel builds, and our flex/bison once when absent); opt-in by name.
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

# our flex and bison, each on our m4, built by their lanes when absent
fx=$R/out/moonflex/flex-2.6.4/src/flex
by=$R/out/moonbison/bison-3.8.2/src/bison
[ -x "$fx" ] || sh src/tools/moon-flex.sh > "$B/moon-flex.log" 2>&1 || { tail -5 "$B/moon-flex.log"; fail "our flex did not build"; }
[ -x "$by" ] || sh src/tools/moon-bison.sh > "$B/moon-bison.log" 2>&1 || { tail -5 "$B/moon-bison.log"; fail "our bison did not build"; }
mkdir -p "$B/tools"
printf '#!/bin/sh\nM4=%s BISON_PKGDATADIR=%s exec %s "$@"\n' \
  "$R/out/moonbison/m4-1.4.21/src/m4" "$R/out/moonbison/bison-3.8.2/data" "$by" > "$B/tools/bison"
chmod +x "$B/tools/bison"
gz="$love gzip"
# and neither half sees the host's rust or pahole: their versions reach .config, so the image
mk="LLVM=1 ARCH=arm64 RUSTC=false HOSTRUSTC=false BINDGEN=false PAHOLE=false"

mkdir -p "$O"
# shellcheck disable=SC2086
(cd "$K" && make O="$O" $mk KGZIP="$gz" defconfig && make O="$O" $mk KGZIP="$gz" -j"$J" Image) \
  > "$B/ref.log" 2>&1 || { tail -20 "$B/ref.log"; fail "kbuild's own build failed"; }
mv "$O" "$B/ref" || fail "cannot set kbuild's build aside"

mkdir -p "$O"
(cd "$O" && HEARTS_SRC="$K" HEARTS_JOBS="$J" LOVE_BUDGET_MB=${LOVE_BUDGET_MB:-1500} \
  HEARTS_LEX="$fx" HEARTS_YACC="$B/tools/bison" HEARTS_KGZIP="$gz" \
  "$love" "$R/src/apps/hearts/build.l") > "$B/hearts.log" 2>&1 \
  || { tail -20 "$B/hearts.log"; fail "hearts' build failed"; }

for f in .config kernel/config_data.gz arch/arm64/boot/Image; do
  [ -f "$O/$f" ] || fail "hearts made no $f"
  cmp -s "$B/ref/$f" "$O/$f" || fail "$f differs from kbuild's"
done
echo "hearts: Image $(sha256sum < "$O/arch/arm64/boot/Image" | cut -c1-16) = kbuild+clang's, from linux-$V defconfig, host programs by mooncc"
