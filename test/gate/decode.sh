#!/bin/sh
# test/gate/decode.sh -- the x86 decoder (core/holo/decode.l) against objdump: every test/cc
# file compiled to an object at -O0 and -O2, its .text decoded by decode.l and disassembled by
# objdump, and the two must agree on every instruction boundary and mnemonic. objdump is the
# oracle for what the bytes say; test/holo/decode.l is the judge. skips without gcc or objdump.
#
# usage: decode.sh LOVE OUTDIR      (from the repo root; LOVE is a word list, not a path)
set -u
love=$1 ho=$2
command -v gcc > /dev/null 2>&1 || { echo "test/holo/decode: no gcc, skipped"; exit 0; }
command -v objdump > /dev/null 2>&1 || { echo "test/holo/decode: no objdump, skipped"; exit 0; }
command -v objcopy > /dev/null 2>&1 || { echo "test/holo/decode: no objcopy, skipped"; exit 0; }
d=$ho/.decode
mkdir -p $d
: > $d/pairs
for f in test/cc/*.c; do
  b=${f##*/}; b=${b%.c}
  for o in 0 2; do
    gcc -c -O$o -fno-asynchronous-unwind-tables -fno-stack-protector -o $d/$b.$o.o $f > /dev/null 2>&1 || continue
    objcopy -O binary -j .text $d/$b.$o.o $d/$b.$o.bin 2> /dev/null || continue
    objdump -d --no-show-raw-insn -j .text $d/$b.$o.o > $d/$b.$o.dis 2> /dev/null || continue
    echo "$d/$b.$o.bin $d/$b.$o.dis" >> $d/pairs
  done
done
{ cat core/holo/holo.l core/holo/x64.l core/holo/dialect.l core/holo/decode.l
  sed "s|@PAIRS@|$d/pairs|" test/holo/decode.l
} | $love
