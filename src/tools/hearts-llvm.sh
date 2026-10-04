#!/bin/sh
# hearts-llvm.sh -- build the clang+lld that test_hearts' reference borrows: llvm 22.1.8 from the
# pinned tarball, configured the same on every host, so the reference's code is one compiler's.
# a distro's clang of the same version gives different code. hours of build; run by hand.
# usage: hearts-llvm.sh [PREFIX]   (default ~/.cache/hearts/llvm-22.1.8)
set -eu
V=22.1.8
SHA=922f1817a0df7b1489272d18134ee0087a8b068828f87ac63b9861b1a9965888
C=${HEARTS_CACHE:-$HOME/.cache/hearts}
P=${1:-$C/llvm-$V}
W=${HEARTS_LLVM_WORK:-/var/tmp/hearts/llvm-$V}
J=${HEARTS_LLVM_JOBS:-8}
for t in curl cmake ninja cc c++; do command -v $t >/dev/null || { echo "hearts-llvm: no $t" >&2; exit 1; }; done
tgz=$C/src/llvm-project-$V.src.tar.xz
mkdir -p "$C/src" "$W/tmp"
[ -f "$tgz" ] || curl -sSfL -o "$tgz" "https://github.com/llvm/llvm-project/releases/download/llvmorg-$V/llvm-project-$V.src.tar.xz"
[ "$(sha256sum < "$tgz" | cut -d' ' -f1)" = "$SHA" ] || { echo "hearts-llvm: $tgz is not the pinned llvm $V" >&2; exit 1; }
rm -rf "$W/llvm-project-$V.src" "$W/build"
(cd "$W" && tar xf "$tgz")
# kbuild asks clang some questions with no --target, so it defaults to arm64 on every host; no vc
# revision: it would carry a git suffix into the version text, so into .config
export TMPDIR=$W/tmp
cmake -S "$W/llvm-project-$V.src/llvm" -B "$W/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_PROJECTS='clang;lld' -DLLVM_TARGETS_TO_BUILD='AArch64;ARM' \
  -DLLVM_DEFAULT_TARGET_TRIPLE=aarch64-unknown-linux-gnu -DLLVM_APPEND_VC_REV=OFF \
  -DLLVM_ENABLE_ASSERTIONS=OFF -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
  -DCMAKE_INSTALL_PREFIX="$P"
ninja -C "$W/build" -j"$J" install
rm -rf "$W"
"$P/bin/clang" --version | head -1
