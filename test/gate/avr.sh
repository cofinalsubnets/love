#!/bin/sh
# test/gate/avr.sh -- holo's avr: test/holo/avrlaw.l holds the interpreter (avrrun.l) to the manual's
# flags and the refusals of a family; test/holo/avrcodec.l lays a corpus of every row of avr-tab, which
# llvm-mc assembles and llvm-objdump reads back as decode.l does; test/holo/avrqemu.l runs one image in
# the interpreter and on qemu's uno, whose bytes out the uart must agree; kore's objdump -d reads
# clang's object as llvm-objdump does; test/holo/avrobj.l lays an object
# whose relocations are llvm-mc's, which lld links alike
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
ob=""
osrc="src/love/holo/holo.l src/love/holo/elf.l src/love/holo/avr.l src/love/holo/obj.l"
for t in llvm-mc llvm-readelf llvm-objcopy; do command -v $t > /dev/null 2>&1 || ob="no $t"; done
for p in avr5:atmega32u4 avr25:attiny85; do
  f=${p%%:*}; c=${p##*:}
  cat $osrc test/holo/avrobj.l | AVR_FAM=$f AVR_OBJ="$d/$f.our.o" $love > "$d/$f.obj.log" 2>&1 || { cat "$d/$f.obj.log"; fail "avrobj.l could not lay $f"; }
  grep -q 'avrobj: ok' "$d/$f.obj.log" || { cat "$d/$f.obj.log"; fail "avrobj.l did not finish"; }
  [ -z "$ob" ] || continue
  far=""; [ $f = avr5 ] && far='call ext
 call f
 jmp ext+6'
  cat > "$d/$f.ref.s" <<EOF
.text
.global f
f: rjmp f
 rjmp ext
 rjmp ext+4
 breq loc
 brne ext
 $far
 ldi r24, lo8(v+5)
 ldi r25, hi8(v+5)
 ldi r24, lo8(v-3)
 ldi r25, hi8(v-3)
 ldi r24, lo8(-(v+5))
 ldi r25, hi8(-(v+5))
 ldi r30, pm_lo8(ext)
 ldi r31, pm_hi8(ext)
 .word ext
loc: ret
.data
.global v
v: .word ext
 .word v+2
 .word pm(ext)
 .long ext
 .byte v
 .byte 0
EOF
  llvm-mc --triple=avr --mcpu=$c -filetype=obj "$d/$f.ref.s" -o "$d/$f.ref.o" || fail "llvm-mc refused the $f object"
  for x in our ref; do
    llvm-readelf -rW "$d/$f.$x.o" | awk '/R_AVR/ { print $1, $3, $5, $6, $7 } /^Relocation/ { print $3 }' > "$d/$f.$x.rel"
    for q in text data; do llvm-objcopy -O binary -j .$q "$d/$f.$x.o" "$d/$f.$x.$q" || fail "llvm-objcopy"; done
    llvm-readelf -h "$d/$f.$x.o" | sed -n 's/.*Flags: *\(0x[0-9a-fA-F]*\).*/\1/p' > "$d/$f.$x.fl"
  done
  [ -s "$d/$f.ref.rel" ] && cmp -s "$d/$f.our.rel" "$d/$f.ref.rel" || { diff "$d/$f.ref.rel" "$d/$f.our.rel"; fail "our $f object's relocations are not llvm-mc's"; }
  # lld reads either; a branch's and an address's own field is the linker's, so a link tells the rest
  if command -v ld.lld > /dev/null 2>&1; then
    printf '.text\n.global ext\next: ret\n' > "$d/ext.s"; llvm-mc --triple=avr --mcpu=$c -filetype=obj "$d/ext.s" -o "$d/ext.o"
    for x in our ref; do ld.lld --image-base=0 -Ttext=0 -Tdata=0x80 -e f "$d/$f.$x.o" "$d/ext.o" -o "$d/$f.$x.elf" 2> "$d/lld.log" || { cat "$d/lld.log"; fail "lld refused $f $x"; }
      llvm-objcopy -O binary -j .text "$d/$f.$x.elf" "$d/$f.$x.lt" && llvm-objcopy -O binary -j .data "$d/$f.$x.elf" "$d/$f.$x.ld"; done
    cmp "$d/$f.our.lt" "$d/$f.ref.lt" && cmp "$d/$f.our.ld" "$d/$f.ref.ld" || fail "lld lays the $f objects differently"
  else
    gate_partly "$name: no link of the objects (no ld.lld)"
  fi
  # ours clears the relaxable bit, 0x80
  [ "$(printf '%d' $(cat "$d/$f.our.fl"))" = "$(( $(cat "$d/$f.ref.fl") & 127 ))" ] || fail "$f e_flags $(cat "$d/$f.our.fl") against $(cat "$d/$f.ref.fl")"
done
[ -z "$ob" ] && ob="; objects as llvm-mc's, linked alike by lld" || { gate_partly "$name: objects unchecked ($ob)"; ob=""; }
echo "$name: the interpreter's flags and refusals by the manual$co$qe$kr$ob"
