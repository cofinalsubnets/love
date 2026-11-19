#!/bin/sh
# test/gate/mips.sh -- holo's mips backend: test/holo/mipsrun.l lays its checks as one big-endian
# linux program for qemu-mips's 24Kc, which exits 42 when every answer held and 100+n at the first
# miss; test/holo/mipscodec.l lays a word corpus of every row of mips-tab, which llvm-mc assembles
# and llvm-objdump reads back as decode.l does (rdhwr aside: llvm-objdump leaves it <unknown>)
# test/holo/mipslink.l links two of its objects, by holo and by lld, which exit 42 too, and which
# kore's objdump and readelf read as llvm's and gnu's do; clang's o32 REL objects link by holo too
# usage: mips.sh LOVE OUTDIR
. test/gate/skip.sh
set -u

name=test_mips
love=$1
d=$2/mips
mkdir -p "$d"
fail() { echo "FAIL $name: $*"; exit 1; }

command -v qemu-mips > /dev/null 2>&1 || gate_skip "$name: skipped (no qemu-mips)"
cat src/love/holo/holo.l src/love/holo/mips.l test/holo/mipsrun.l \
  | MIPS_OUT="$d/run.elf" $love > "$d/law.log" 2>&1 || { cat "$d/law.log"; fail "love could not lay mipsrun.l"; }
chmod +x "$d/run.elf"
timeout 60 qemu-mips -cpu 24Kc "$d/run.elf"
a=$?
[ "$a" -eq 42 ] || fail "the program answered $a, want 42 (100+n names the first miss in test/holo/mipsrun.l)"

# two objects through holo's link, and the same two through lld when it is here
mkdir -p "$d/obj"
cat src/love/holo/holo.l src/love/holo/mips.l src/love/holo/elf.l src/love/holo/obj.l src/love/holo/lds.l src/love/holo/link.l \
  test/holo/mipslink.l | MIPS_OUT="$d/link.elf" MIPS_OBJ="$d/obj" $love > "$d/link.log" 2>&1 \
  || { cat "$d/link.log"; fail "love could not link mipslink.l"; }
chmod +x "$d/link.elf"
timeout 60 qemu-mips -cpu 24Kc "$d/link.elf"
a=$?
[ "$a" -eq 42 ] || fail "the linked program answered $a, want 42"
lld=", and by lld"
if command -v ld.lld > /dev/null 2>&1; then
  ld.lld -static -e _start "$d/obj/a.o" "$d/obj/b.o" -o "$d/lld.elf" || fail "lld refused holo's objects"
  timeout 60 qemu-mips -cpu 24Kc "$d/lld.elf"
  a=$?
  [ "$a" -eq 42 ] || fail "lld's link of holo's objects answered $a, want 42"
else
  gate_partly "$name: lld's link skipped (no ld.lld)"; lld=""
fi

# kore reads them as the outside readers do: objdump -d as llvm-objdump, readelf as gnu
# readelf, its -r as llvm-readelf (kore's own split on every target)
kr=""
for t in llvm-objdump llvm-readelf readelf; do command -v $t > /dev/null 2>&1 || kr="no $t"; done
if [ -z "$kr" ]; then
  same() { cmp -s "$d/kore.txt" "$d/ref.txt" || { diff "$d/ref.txt" "$d/kore.txt" | head -10; fail "$*"; }; }
  for e in link.elf lld.elf; do
    $love objdump -d "$d/$e" > "$d/kore.txt" 2>&1; llvm-objdump -d "$d/$e" > "$d/ref.txt" 2>&1
    same "kore objdump -d reads $e otherwise than llvm-objdump"
  done
  for e in obj/a.o obj/b.o link.elf; do
    for o in -h -S -s -l; do
      $love readelf $o "$d/$e" > "$d/kore.txt" 2>&1; readelf $o "$d/$e" > "$d/ref.txt" 2>&1
      same "kore readelf $o reads $e otherwise than readelf"
    done
    $love readelf -r "$d/$e" > "$d/kore.txt" 2>&1; llvm-readelf -r "$d/$e" > "$d/ref.txt" 2>&1
    same "kore readelf -r reads $e otherwise than llvm-readelf"
  done
  kr="; kore's objdump and readelf read them as llvm and gnu do"
else
  gate_partly "$name: kore's readers unchecked ($kr)"; kr=""
fi

# o32 REL objects, as gcc and GNU as lay them, read by holo's link beside a mooncc object: clang
# builds test/holo/mipsrel.c, mipsrela.s and an archive of mipsrelb.c, which exit 42 linked by
# holo as by lld (100+n names the first address that disagreed)
rl=""
for t in clang llvm-ar; do command -v $t > /dev/null 2>&1 || rl="no $t"; done
if [ -z "$rl" ]; then
  mkdir -p "$d/rel"
  ras() { clang --target=mips-linux-gnu -mcpu=mips32r2 -msoft-float -fno-pic -mno-abicalls -c "$@"; }
  rcc() { ras -G0 -O1 "$@"; }
  rcc test/holo/mipsrel.c -o "$d/rel/rel.o" && ras test/holo/mipsrela.s -o "$d/rel/rela.o" \
    && rcc test/holo/mipsrelb.c -o "$d/rel/relb.o" || fail "clang could not lay the REL objects"
  rm -f "$d/rel/librelb.a"; llvm-ar rcs "$d/rel/librelb.a" "$d/rel/relb.o" || fail "llvm-ar could not lay librelb.a"
  $love mooncc -t mips -os none -c -o "$d/rel/relm.o" test/holo/mipsrelm.c || fail "mooncc could not lay mipsrelm.c"
  ro="$d/rel/relm.o $d/rel/rel.o $d/rel/rela.o $d/rel/librelb.a"
  $love mooncc -t mips -os none -nostdlib -Ttext 0x400000 -o "$d/rel/rel.elf" $ro || fail "holo's link refused the REL objects"
  timeout 60 qemu-mips -cpu 24Kc "$d/rel/rel.elf"
  a=$?
  [ "$a" -eq 42 ] || fail "holo's link of the REL objects answered $a, want 42"
  if command -v ld.lld > /dev/null 2>&1; then
    ld.lld -e _start -Ttext=0x400000 -o "$d/rel/rel.lld" $ro || fail "lld refused the REL objects"
    timeout 60 qemu-mips -cpu 24Kc "$d/rel/rel.lld"
    a=$?
    [ "$a" -eq 42 ] || fail "lld's link of the REL objects answered $a, want 42"
  fi
  # an abicalls object wants a got: refused by name
  clang --target=mips-linux-gnu -mcpu=mips32r2 -msoft-float -c test/holo/mipsrelb.c -o "$d/rel/pic.o" || fail "clang could not lay pic.o"
  ! $love mooncc -t mips -os none -nostdlib -Ttext 0x400000 -o "$d/rel/pic.elf" "$d/rel/relm.o" "$d/rel/pic.o" > "$d/rel/pic.log" 2>&1 \
    && grep -q link-mips-abicalls "$d/rel/pic.log" || { cat "$d/rel/pic.log"; fail "an abicalls object was not refused by name"; }
  rl="; REL objects from clang (and an archive of one) linked beside mooncc's to 42, an abicalls one refused"
else
  gate_partly "$name: the REL objects unchecked ($rl)"; rl=""
fi

for t in llvm-mc llvm-objcopy llvm-objdump; do
  command -v $t > /dev/null 2>&1 || gate_skip "$name: the run and the link held; codec skipped (no $t)"
done
codec() { cat src/love/holo/holo.l src/love/holo/mips.l src/love/holo/dialect.l src/love/holo/decode.l test/holo/mipscodec.l; }
codec | $love > "$d/words.s" 2> "$d/gen.log" || { cat "$d/gen.log"; fail "love could not lay the word corpus"; }
llvm-mc -triple=mips -mcpu=mips32r2 -filetype=obj -o "$d/words.o" "$d/words.s" || fail "llvm-mc refused the corpus"
llvm-objcopy -O binary --only-section=.text "$d/words.o" "$d/words.bin" || fail "llvm-objcopy could not cut .text"
codec | MIPS_BIN="$d/words.bin" $love > "$d/ours.txt" 2> "$d/codec.log" || { cat "$d/codec.log"; fail "a word laid back otherwise"; }
# llvm's rows as ours: the address and the text, a target's <symbol> gone
llvm-objdump -d --no-show-raw-insn "$d/words.o" | awk -F'\t' '
  /^ *[0-9a-f]+:/ { a = $1; gsub(/[ :]/, "", a); t = $2; for (i = 3; i <= NF; i++) t = t "\t" $i
                    sub(/ <[^>]*>$/, "", t); print a ":\t" t }
  /^\t\t\.\.\./ { print "..." }' > "$d/llvm.txt"
grep -v "	rdhwr	" "$d/ours.txt" > "$d/ours.cmp"
awk -F'\t' 'NR == FNR { if ($2 ~ /^rdhwr/) skip[$1] = 1; next } !($1 in skip)' "$d/ours.txt" "$d/llvm.txt" > "$d/llvm.cmp"
n=$(wc -l < "$d/ours.cmp" | tr -d ' ')
[ "$n" -gt 2000 ] || fail "only $n rows read back"
cmp -s "$d/llvm.cmp" "$d/ours.cmp" || { diff "$d/llvm.cmp" "$d/ours.cmp" | head -20; fail "decode.l reads the corpus otherwise than llvm-objdump"; }
echo "$name: $(sed -n 's/^mipsrun: //p' "$d/law.log"), every answer as love's own on qemu-mips; two objects linked and run$lld$kr$rl; $(sed -n 's/^test\/holo\/mipscodec: //p' "$d/codec.log"), $n as llvm-objdump writes them"
