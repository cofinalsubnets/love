#!/bin/sh
# test/gate/dialect.sh -- the x86 dialect lens (src/core/holo/dialect.l) against gcc's own two
# spellings: every test/cc file compiled with -masm=att and with -masm=intel must read to the
# same value. gcc is the oracle for what each dialect says; test/holo/dialect.l is the judge.
# skips without gcc.
#
# usage: dialect.sh LOVE OUTDIR      (from the repo root; LOVE is a word list, not a path)
set -u
love=$1 ho=$2
command -v gcc > /dev/null 2>&1 || { echo "test/holo/dialect: no gcc, skipped"; exit 0; }
d=$ho/.dialect
mkdir -p $d/att $d/intel
: > $d/pairs
flags="-S -O0 -fno-asynchronous-unwind-tables -fno-stack-protector"
for f in test/cc/*.c; do
  b=${f##*/}; b=${b%.c}
  gcc $flags -masm=att -o $d/att/$b.s $f > /dev/null 2>&1 || continue
  gcc $flags -masm=intel -o $d/intel/$b.s $f > /dev/null 2>&1 || continue
  # a segment override (thread-local storage) is outside the lens: both readers refuse it
  grep -q '%fs:\|%gs:' $d/att/$b.s && continue
  echo "$d/att/$b.s $d/intel/$b.s" >> $d/pairs
done
{ cat src/core/holo/holo.l src/core/holo/x64.l src/core/holo/dialect.l
  sed "s|@PAIRS@|$d/pairs|" test/holo/dialect.l
} | $love
