#!/bin/sh
# test/gate/dwarfcode.sh -- -g leaves mooncc's code alone: love's own C on x64, and some on thumb2, compiled
# with and without -g, the same .text. one compile at a time, each held to a budget.
# usage: dwarfcode.sh OUTDIR
. test/gate/skip.sh
set -u

ho=$1
name=test_dwarfcode
oc=`command -v llvm-objcopy 2>/dev/null || true`
[ -n "$oc" ] || gate_skip "$name: no llvm-objcopy, skipped"
d=$ho/dwarfcode
rm -rf "$d"; mkdir -p "$d"
echo "DWARFCODE $d"
export LOVE_BUDGET_MB=1024
cd0() { "$ho/love" mooncc $2 -D tco=1 -Iout -I. -Isrc/love -Isrc/inle -Iout/lib -c "$1" -o "$3" \
          && "$oc" -O binary --only-section=.text "$3" "$3.text"; }
mkdir -p "$d/g"
for f in src/love/*.c; do
  b=`basename $f .c`
  cd0 $f "-t x64 -os linux" "$d/g/$b.o" && cd0 $f "-t x64 -os linux -g" "$d/g/$b.g.o" || echo "$b: mooncc" > "$d/g/$b.bad"
done
for f in src/love/*.c; do
  b=`basename $f .c`
  [ -f "$d/g/$b.bad" ] && { echo "FAIL $name: mooncc $f"; exit 1; }
  # ..and -g laid its marks there, so the sameness says something
  [ ! -s "$d/g/$b.o.text" ] || "$ho/love" readelf -S "$d/g/$b.g.o" | grep -q 'debug_line' || { echo "FAIL $name: -g lays no lines for $b.c"; exit 1; }
  cmp -s "$d/g/$b.o.text" "$d/g/$b.g.o.text" || { echo "FAIL $name: -g changes $b.c's code"; exit 1; }
done
for f in src/love/arr.c src/love/gc.c src/love/raster.c src/love/vfs.c src/apps/moon/lib/moonlibc/math/lm.c; do
  b=`basename $f .c`
  cd0 $f "-t thumb2" "$d/g/$b.t.o" && cd0 $f "-t thumb2 -g" "$d/g/$b.tg.o" || { echo "FAIL $name: mooncc -t thumb2 $f"; exit 1; }
  [ -s "$d/g/$b.t.o.text" ] && cmp -s "$d/g/$b.t.o.text" "$d/g/$b.tg.o.text" || { echo "FAIL $name: -g changes $b.c's code on thumb2"; exit 1; }
done
echo "dwarfcode: -g leaves the code of love's C alone, `ls src/love/*.c | wc -l` files, and five on thumb2"
