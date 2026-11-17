#!/bin/sh
# test/gate/objdump.sh -- love objdump -d against llvm-objdump -d, line for line: every test/cc
# file compiled to an object by gcc and clang at -O0 and -O2 for x86-64, and by mooncc and clang
# for rv64; the two disassemblies must be the same text. llvm is told rv64gc, since mooncc's
# objects carry no attributes. skips without llvm-objdump or a C compiler.
# usage: objdump.sh LOVE OUTDIR      (from the repo root; LOVE is a word list, not a path)
. test/gate/skip.sh
set -u
love=$1 ho=$2
command -v llvm-objdump > /dev/null 2>&1 || gate_skip "test_objdump: no llvm-objdump, skipped"
ccs=
for c in gcc clang; do command -v $c > /dev/null 2>&1 && ccs="$ccs $c"; done
[ -n "$ccs" ] || gate_skip "test_objdump: no C compiler, skipped"
d=$ho/.objdump
rm -rf $d && mkdir -p $d
n=0 bad=0 lines=0
# one object: llvm's text and ours, counted
judge() {
  x=$1; shift
  llvm-objdump -d "$@" $x.o > $x.llvm 2> /dev/null || return
  $love objdump -d $x.o > $x.ours 2>&1
  n=$((n + 1))
  k=$(diff $x.ours $x.llvm | grep -c '^>')
  if [ "$k" -gt 0 ]; then
    bad=$((bad + 1)) lines=$((lines + k))
    [ $bad -le 3 ] && { echo "  $x.o: $k lines differ"; diff $x.ours $x.llvm | head -6; }
  fi
}
for f in test/cc/*.c; do
  b=${f##*/}; b=${b%.c}
  for o in 0 2; do
    for c in $ccs; do
      x=$d/$b.$c.$o
      $c -c -O$o -fno-asynchronous-unwind-tables -fno-stack-protector -o $x.o $f > /dev/null 2>&1 && judge $x
    done
    x=$d/$b.rv.$o
    $love cc -t rv64 -O$o -c -o $x.o $f > /dev/null 2>&1 && judge $x --mattr=+m,+a,+f,+d,+c
    x=$d/$b.rvclang.$o
    command -v clang > /dev/null 2>&1 \
      && clang --target=riscv64-linux-gnu -march=rv64gc -c -O$o -o $x.o $f > /dev/null 2>&1 \
      && judge $x --mattr=+m,+a,+f,+d,+c
  done
done
echo "test_objdump: $n objects, $bad differ, $lines lines"
[ $bad -eq 0 ]
