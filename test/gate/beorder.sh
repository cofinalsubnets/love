#!/bin/sh
# test/gate/beorder.sh -- holo's byte order: objects mooncc lays for each class and relocation
# shape, turned big-endian by elf-swap (beorder.l), read alike by ld-obj and by llvm-readelf,
# and a link of the turned objects the same file as a link of the originals.
# usage: beorder.sh LOVE OUTDIR
. test/gate/skip.sh
set -u

love=$1 d=$2/beorder t=test_beorder
fail() { echo "FAIL $t: $*" >&2; exit 1; }
rm -rf "$d"; mkdir -p "$d/be"

srcs="test/cc/01-arith.c test/cc/16-call.c test/cc/49-global-init.c test/cc/53-str-global.c test/cc/54-global-ptr.c"
names=
for tgt in x64 a64 rv64 rv32 xtensa arm thumb1 i386; do
  for f in $srcs; do
    n=$tgt-$(basename "$f" .c).o
    "$love" mooncc -c -t $tgt -o "$d/$n" "$f" > "$d/cc.log" 2>&1 || { cat "$d/cc.log"; fail "mooncc -t $tgt $f"; }
    names="$names \"$n\""
  done
done
echo "(be-check \"$d\" [$names])" | cat test/gate/beorder.l - | "$love" || fail "the swap"

# llvm-readelf reads each turned object as it reads the original, but for the byte order
if command -v llvm-readelf > /dev/null 2>&1; then
  for o in "$d"/*.o; do
    n=$(basename "$o")
    a=$(cd "$d" && llvm-readelf -h -S -s -r "$n" 2>&1 | grep -v 'Data:\|Magic:')
    b=$(cd "$d/be" && llvm-readelf -h -S -s -r "$n" 2>&1 | grep -v 'Data:\|Magic:')
    [ "$a" = "$b" ] || { printf '%s\n' "$a" > "$d/a.txt"; printf '%s\n' "$b" > "$d/b.txt"; diff "$d/a.txt" "$d/b.txt" | head -20; fail "llvm-readelf reads $n otherwise"; }
    (cd "$d/be" && llvm-readelf -h "$n" | grep -q 'big endian') || fail "llvm-readelf: $n is not big-endian"
  done
  how="llvm-readelf alike"
else
  how="no llvm-readelf"
fi

# a link reads the turned objects as the originals
for tgt in x64 rv32 arm i386; do
  "$love" mooncc -t $tgt -o "$d/$tgt.elf" "$d/$tgt-54-global-ptr.o" > "$d/ld.log" 2>&1 || { cat "$d/ld.log"; fail "link $tgt"; }
  "$love" mooncc -t $tgt -o "$d/be/$tgt.elf" "$d/be/$tgt-54-global-ptr.o" > "$d/ld.log" 2>&1 || { cat "$d/ld.log"; fail "link $tgt, turned"; }
  cmp -s "$d/$tgt.elf" "$d/be/$tgt.elf" || fail "$tgt: a link of the turned object differs"
done
rm -rf "$d"
echo "$t: objects of 8 targets turned big-endian and back, read alike ($how), linked alike on 4"
