#!/bin/sh
# test/gate/rvgas.sh -- gas reads the riscv table: every full-length, non-branch instruction in
# rvcodec.sh's objects, as llvm-objdump spells it without aliases, assembled by mooncc and by
# llvm-mc (no C, so each line is one word); both disassembled must be the same text, a target
# note aside (mooncc compresses, so addresses move). run after rvcodec.sh; skips without llvm.
# usage: rvgas.sh LOVE OUTDIR      (from the repo root; LOVE is a word list, not a path)
. test/gate/skip.sh
set -u
love=$1 ho=$2
for t in llvm-objdump llvm-mc; do command -v $t > /dev/null 2>&1 || gate_skip "test/holo/rvgas: no $t, skipped"; done
s=$ho/.rvcodec d=$ho/.rvgas
ls $s/*.o > /dev/null 2>&1 || { echo "test/holo/rvgas: no rvcodec objects, nothing judged"; exit 1; }
rm -rf $d && mkdir -p $d
at="--mattr=+m,+a,+f,+d,+c --no-show-raw-insn --no-leading-addr"
# the instruction lines of an object, as llvm writes them
lines() { llvm-objdump -d "$@" | grep -P '^ *\t' | sed 's/^ *\t//'; }
for o in $s/*.o; do lines -M no-aliases $at $o; done \
  | grep -vP '^(c\.|b[a-z]*\t|jal\t|unimp|<unknown>)' | grep -v '<' | sort -u > $d/want
{ echo "  .text"; echo "f:"; sed 's/^/  /' $d/want; } > $d/t.S
$love cc -t rv64 -c -o $d/ours.o $d/t.S || { echo "test/holo/rvgas: mooncc refused the lines"; exit 1; }
llvm-mc -triple=riscv64 -mattr=+m,+a,+f,+d -filetype=obj -o $d/ref.o $d/t.S || exit 1
for x in ours ref; do lines $at $d/$x.o | sed 's/ <[^>]*>$//' > $d/$x.dis; done
n=$(wc -l < $d/want) k=$(diff $d/ref.dis $d/ours.dis | grep -c '^>')
echo "test/holo/rvgas: $n lines, $k differ"
[ "$k" -eq 0 ] || { diff $d/ref.dis $d/ours.dis | head -8; exit 1; }
