#!/bin/sh
# test/gate/xtensa.sh -- holo's xtensa backend run whole on qemu-xtensa's dc233c, an LX core
# with the esp32's mul32, div32 and sext: test/holo/xtrun.l lays its checks as one linux
# program, which exits 42 when every answer held and 100+n at the first miss; test/holo/xtlink.l
# links two of its objects, which exit 42 too.
# usage: xtensa.sh LOVE OUTDIR
. test/gate/skip.sh
set -u

name=test_xtensa
love=$1
d=$2/xtensa
mkdir -p "$d"
fail() { echo "FAIL $name: $*"; exit 1; }

command -v qemu-xtensa > /dev/null 2>&1 || gate_skip "$name: skipped (no qemu-xtensa)"
cat src/love/holo/holo.l src/love/holo/xtensa.l test/holo/xtrun.l \
  | XT_OUT="$d/run.elf" $love > "$d/law.log" 2>&1 || { cat "$d/law.log"; fail "love could not lay xtrun.l"; }
chmod +x "$d/run.elf"
timeout 60 qemu-xtensa -cpu dc233c "$d/run.elf"
a=$?
[ "$a" -eq 42 ] || fail "the program answered $a, want 42 (100+n names the first miss in test/holo/xtrun.l)"
XT_OUT="$d/link.elf" $love test/holo/xtlink.l > "$d/link.log" 2>&1 || { cat "$d/link.log"; fail "love could not link xtlink.l"; }
chmod +x "$d/link.elf"
timeout 60 qemu-xtensa -cpu dc233c "$d/link.elf"
a=$?
[ "$a" -eq 42 ] || fail "the linked program answered $a, want 42"
echo "$name: $(sed -n 's/^xtrun: //p' "$d/law.log"), every answer as love's own on qemu-xtensa; two objects linked and run"
