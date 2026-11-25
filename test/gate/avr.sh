#!/bin/sh
# test/gate/avr.sh -- holo's avr: test/holo/avrlaw.l holds the interpreter (avrrun.l) to the manual's
# flags and the refusals of a family; test/holo/avrcodec.l lays a corpus of every row of avr-tab, which
# llvm-mc assembles and llvm-objdump reads back as decode.l does; test/holo/avrqemu.l runs one image in
# the interpreter and on qemu's uno, whose bytes out the uart must agree; kore's objdump -d reads
# clang's object as llvm-objdump does
# usage: avr.sh LOVE OUTDIR
. test/gate/skip.sh
set -u

name=test_avr
love=$1
d=$2/avr
mkdir -p "$d"
fail() { echo "FAIL $name: $*"; exit 1; }
src="src/love/holo/holo.l src/love/holo/avr.l src/love/holo/decode.l"

cat $src test/holo/avrrun.l test/holo/avrlaw.l | $love > "$d/law.log" 2>&1 || { cat "$d/law.log"; fail "the interpreter's laws"; }
grep -q 'avrlaw: 0 missed' "$d/law.log" || { cat "$d/law.log"; fail "avrlaw.l did not finish"; }

co=""
for t in llvm-mc llvm-objcopy llvm-objdump; do command -v $t > /dev/null 2>&1 || co="no $t"; done
if [ -z "$co" ]; then
  # the tidy ends of llvm's lines: the address, a tab, the text
  tidy() { sed -E 's/^[[:space:]]+//; s/:[[:space:]]+/:\t/; s/[[:space:]]+$//'; }
  for p in avr5:atmega32u4 avr25:attiny85; do
    f=${p%%:*}; c=${p##*:}
    cat $src test/holo/avrcodec.l | AVR_FAM=$f $love > "$d/$f.s" 2> "$d/$f.log" || { cat "$d/$f.log"; fail "avrcodec.l could not lay $f"; }
    llvm-mc --triple=avr --mcpu=$c -filetype=obj "$d/$f.s" -o "$d/$f.o" || fail "llvm-mc refused the $f corpus"
    llvm-objcopy -O binary -j .text "$d/$f.o" "$d/$f.bin" || fail "llvm-objcopy"
    llvm-objdump -d --no-show-raw-insn --mcpu=$c "$d/$f.o" | grep -E '^ *[0-9a-f]+:|^[[:space:]]+\.\.\.' | tidy > "$d/$f.ref"
    cat $src test/holo/avrcodec.l | AVR_FAM=$f AVR_BIN="$d/$f.bin" $love > "$d/$f.out" 2> "$d/$f.log" || { cat "$d/$f.log"; fail "a $f row laid back wrong"; }
    tidy < "$d/$f.out" > "$d/$f.txt"
    [ -s "$d/$f.ref" ] && cmp -s "$d/$f.ref" "$d/$f.txt" || { diff "$d/$f.ref" "$d/$f.txt" | head -10; fail "decode.l reads the $f corpus otherwise than llvm-objdump"; }
  done
  co="; every row of the table as llvm-mc and llvm-objdump have it, avr5 and avr25"
else
  gate_partly "$name: the table unchecked ($co)"; co=""
fi

qe=""
if command -v qemu-system-avr > /dev/null 2>&1; then
  cat $src test/holo/avrrun.l test/holo/avrqemu.l | AVR_OUT="$d/q.bin" AVR_REF="$d/q.ref" $love > "$d/q.log" 2>&1 || { cat "$d/q.log"; fail "avrqemu.l could not run"; }
  [ -s "$d/q.ref" ] || fail "the interpreter sent nothing"
  # the image ends in a jump to itself, so qemu is stopped once its bytes are in, or after 60 s
  rm -f "$d/q.got"
  qemu-system-avr -M uno -display none -monitor none -serial "file:$d/q.got" -bios "$d/q.bin" < /dev/null > "$d/qemu.log" 2>&1 &
  q=$!
  want=$(wc -c < "$d/q.ref"); n=0
  while [ $n -lt 60 ] && { [ ! -e "$d/q.got" ] || [ "$(wc -c < "$d/q.got")" -lt "$want" ]; }; do sleep 1; n=$((n + 1)); done
  sleep 1
  kill $q 2> /dev/null; wait $q 2> /dev/null
  cmp "$d/q.got" "$d/q.ref" || { cat "$d/qemu.log"; fail "qemu's uno answers otherwise than avrrun.l"; }
  qe="; one image alike in the interpreter and on qemu's uno"
else
  gate_partly "$name: qemu's run skipped (no qemu-system-avr)"
fi

kr=""
for t in clang llvm-objdump; do command -v $t > /dev/null 2>&1 || kr="no $t"; done
if [ -z "$kr" ]; then
  printf 'int x = 3;\nint g(int);\nint f(int a) { return g(a) + x; }\nint g(int a) { return a * x; }\nlong h(long a, char *p) { while (*p++) a += a << 3; return a; }\n' > "$d/k.c"
  for c in atmega32u4 attiny85; do
    clang --target=avr -mmcu=$c -Os -ffreestanding -c "$d/k.c" -o "$d/k.o" || fail "clang could not lay k.c"
    $love objdump -d "$d/k.o" > "$d/kore.txt" 2>&1; llvm-objdump -d "$d/k.o" > "$d/ref.txt" 2>&1
    cmp -s "$d/kore.txt" "$d/ref.txt" || { diff "$d/ref.txt" "$d/kore.txt" | head -10; fail "kore objdump -d reads $c's k.o otherwise than llvm-objdump"; }
  done
  kr="; kore's objdump -d as llvm's"
else
  gate_partly "$name: kore's objdump unchecked ($kr)"; kr=""
fi
echo "$name: the interpreter's flags and refusals by the manual$co$qe$kr"
