#!/bin/sh
# test/gate/rvcodec.sh -- the riscv table both ways (test/holo/rvcodec.l): every test/cc file
# compiled to rv64 by mooncc at -O0 and -O2, and by clang when it targets riscv, its .text cut
# out by llvm-objcopy or objcopy (ours copies linked images only); each word decoded by its row
# and laid back by the same row must come back. skips with neither objcopy.
# usage: rvcodec.sh LOVE OUTDIR      (from the repo root; LOVE is a word list, not a path)
. test/gate/skip.sh
set -u
love=$1 ho=$2
oc=
for c in llvm-objcopy objcopy; do command -v $c > /dev/null 2>&1 && { oc=$c; break; }; done
[ -n "$oc" ] || gate_skip "test/holo/rvcodec: no objcopy, skipped"
d=$ho/.rvcodec
rm -rf $d && mkdir -p $d
: > $d/pairs
cl=
command -v clang > /dev/null 2>&1 && echo 'int f(void){return 0;}' | clang --target=riscv64-linux-gnu -march=rv64gc -x c -c -o $d/probe.o - 2> /dev/null && cl=1
# one object's .text, listed
cut() { $oc -O binary -j .text $1.o $1.bin > /dev/null 2>&1 && [ -s $1.bin ] && echo $1.bin >> $d/pairs; }
for f in test/cc/*.c; do
  b=${f##*/}; b=${b%.c}
  for o in 0 2; do
    $love cc -t rv64 -O$o -c -o $d/$b.m.$o.o $f > /dev/null 2>&1 && cut $d/$b.m.$o
    [ -n "$cl" ] && clang --target=riscv64-linux-gnu -march=rv64gc -c -O$o -o $d/$b.c.$o.o $f > /dev/null 2>&1 \
      && cut $d/$b.c.$o
  done
done
[ -s $d/pairs ] || { echo "test/holo/rvcodec: no object cut, nothing judged"; exit 1; }
{ cat src/love/holo/holo.l src/love/holo/x64.l src/love/holo/rv64.l src/love/holo/dialect.l src/love/holo/decode.l
  sed "s|@PAIRS@|$d/pairs|" test/holo/rvcodec.l
} | $love
