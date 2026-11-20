#!/bin/sh
# test/gate/a64gas.sh -- gas reads the aarch64 table: every non-branch instruction in a64codec.sh's
# objects, as llvm-objdump spells it, assembled by mooncc and by llvm-mc; both disassembled must be
# the same text. run after a64codec.sh; skips without llvm.
# usage: a64gas.sh LOVE OUTDIR      (from the repo root; LOVE is a word list, not a path)
. test/gate/skip.sh
set -u
love=$1 ho=$2
for t in llvm-objdump llvm-mc; do command -v $t > /dev/null 2>&1 || gate_skip "test/holo/a64gas: no $t, skipped"; done
s=$ho/.a64codec d=$ho/.a64gas
ls $s/*.o > /dev/null 2>&1 || { echo "test/holo/a64gas: no a64codec objects, nothing judged"; exit 1; }
rm -rf $d && mkdir -p $d
at="--no-show-raw-insn --no-leading-addr"
ma=+lse,+crc,+aes,+sha2
# the instruction lines of an object, as llvm writes them
lines() { llvm-objdump -d --mattr=$ma "$@" | grep -P '^ *\t' | sed 's/^ *\t//'; }
for o in $s/*.o; do lines $at $o; done \
  | grep -vP '^(b|bl|b\.[a-z]+|cbn?z|tbn?z|adrp?|udf)\t' | grep -v '<' | grep -vP '^\s*\.' | sort -u > $d/want
{ echo "  .text"; echo "f:"; sed 's/^/  /' $d/want; } > $d/t.S
$love cc -t a64 -c -o $d/ours.o $d/t.S || { echo "test/holo/a64gas: mooncc refused the lines"; exit 1; }
llvm-mc -triple=aarch64 -mattr=$ma -filetype=obj -o $d/ref.o $d/t.S || exit 1
for x in ours ref; do lines $at $d/$x.o > $d/$x.dis; done
n=$(wc -l < $d/want) k=$(diff $d/ref.dis $d/ours.dis | grep -c '^>')
echo "test/holo/a64gas: $n lines, $k differ"
[ "$k" -eq 0 ] || { diff $d/ref.dis $d/ours.dis | head -8; exit 1; }
