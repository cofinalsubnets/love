#!/bin/sh
# arm64check.sh -- the aarch64 EXECUTION validator. Cross-builds `ai` for aarch64
# (reusing the native ai0-generated headers in out/lib) and RUNS a test corpus
# under qemu-aarch64. asm/asmtest.l proves the arm64 byte ENCODINGS; this proves
# they RUN -- the only trustworthy check for the glaze's second target, since the
# glaze self-test executes the machine code it emits.
#
# Needs qemu-aarch64 (qemu-user) + an aarch64 cross-gcc with a static libc. Point
# AARCH64_CC at it, or let the auto-find try the usual names + the local Nerves
# toolchain. No-ops (exit 0, a note) when either is missing -- like test_kernel /
# test_wasm. ai does its own write(2)-based I/O, so it is unaffected by the
# static-glibc printf-vararg quirk seen under qemu.
#
# Args: $1.. = the .l files to run (default: the corpus). The gate is the
# "tests pass" sentinel AND a clean exit (a reader-stop exits 0 without it).
set -e
cd "$(dirname "$0")/.."

QEMU=$(command -v qemu-aarch64 2>/dev/null || true)
GCC="$AARCH64_CC"
[ -z "$GCC" ] && GCC=$(command -v aarch64-linux-gnu-gcc 2>/dev/null || true)
[ -z "$GCC" ] && GCC=$(command -v aarch64-nerves-linux-gnu-gcc 2>/dev/null || true)
[ -z "$GCC" ] && GCC=$(ls /usr/local/data/*/.nerves/artifacts/nerves_toolchain_aarch64*/bin/aarch64-nerves-linux-gnu-gcc 2>/dev/null | head -1)
if [ -z "$QEMU" ] || [ -z "$GCC" ]; then
  echo "test_arm64: skipped (need qemu-aarch64 + an aarch64 cross-gcc; set AARCH64_CC)"; exit 0
fi

# the native headers (egg + lcat libs) must exist; they are arch-neutral source.
test -f out/lib/egg.h || { echo "test_arm64: run 'make host' first (need out/lib/*.h)"; exit 1; }

O=out/arm64; mkdir -p $O
# portable trampoline (ai_tco=0): the glaze native code is independent of the
# interpreter's dispatch, so this validates codegen without the threaded build.
CF="-std=gnu2x -O2 -Dai_tco=0 -I. -Iout/lib -fomit-frame-pointer -fno-stack-protector -fno-exceptions -w"
echo "AARCH64 cross-build ($GCC)"
for f in ai.c host/*.c; do
  o=$O/$(basename "$f" .c).o
  $GCC $CF -c "$f" -o "$o"
done
$GCC -static -o $O/ai $O/*.o -lm 2>/dev/null || $GCC -static -o $O/ai $O/*.o -lm

# the corpus (or the files named on the command line), under qemu.
if [ $# -gt 0 ]; then set -- "$@"; else
  set -- test/00-init.l test/spec.l $(ls test/*.l | grep -vE '00-init|spec\.l|glaze-x86')
fi
echo "AARCH64 qemu run ($(echo "$@" | wc -w) files)"
cat "$@" | AI_NO_IMAGE=1 "$QEMU" $O/ai > $O/.out 2>&1; r=$?
tail -1 $O/.out
{ [ $r -eq 0 ] && grep -q "tests pass" $O/.out; } || { echo "FAIL arm64 (exit $r)"; tail -20 $O/.out; exit 1; }
echo "test_arm64: ok"
