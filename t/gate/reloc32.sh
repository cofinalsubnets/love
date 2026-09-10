#!/bin/sh
# t/gate/reloc32.sh -- --emit-relocs: the table is exactly the words that move.
#
# One source, linked twice at two text addresses 64K apart. Every recorded
# R_ARM_ABS32 site must slide by that delta, and nothing else in the loaded image
# may differ. That is the whole contract a loader placing our image at a base of
# its own leans on -- complete (it slides everything that needs it) and minimal
# (it touches nothing that does not) -- and it is checked here against the image
# itself rather than against another toolchain's opinion of what a relocation is.
#
# thumb2 is deliberately not a lane. Its `la` is a MOVW/MOVT pair, an absolute
# carried as two split immediates that no loader slides by adding to a word, so
# the driver refuses --emit-relocs there before the link runs. thumb1 and thumb2sp
# route `la` through a pooled ABS32 word instead, which is why they can answer.
# Both refusals are rows here: a silently short table is the failure that would
# actually cost, and a refusal spelled as an internal error reads as a bug.
#
# usage: reloc32.sh OUTDIR MOONCC
set -u

ho=$1
m=$2
name=test_reloc32
fail() { echo "FAIL $name: $*" >&2; exit 1; }

for tool in arm-none-eabi-objcopy arm-none-eabi-readelf; do
  command -v $tool > /dev/null 2>&1 || {
    echo "$name: no arm-none-eabi toolchain, skipped"; exit 0; }
done

d=$ho/reloc32
mkdir -p "$d"
rm -f "$d"/*.elf "$d"/*.bin

# every absolute shape a bare image has: a pointer table of static functions (each
# carrying the thumb bit), a string literal's address, and a scalar global's.
{ printf 'int acc = 7;\n'
  printf 'static int f1(void){ return 3; }\n'
  printf 'static int f2(void){ return 4; }\n'
  printf 'int (*const vt[2])(void) = { f1, f2 };\n'
  printf 'const char *msg = "hi";\n'
  printf 'int *const ap = &acc;\n'
  printf 'int __ai_start(void){ return vt[0]() + vt[1]() + *ap + msg[0]; }\n'
} > "$d/rel.c"

delta=65536

lane() { # lane TGT
  t=$1
  LOVE_NO_IMAGE= "$m" mooncc -t "$t" -D __STDC_HOSTED__=0 -Ttext 0x0 \
    --emit-relocs -o "$d/$t.a.elf" "$d/rel.c" || fail "$t link at 0"
  LOVE_NO_IMAGE= "$m" mooncc -t "$t" -D __STDC_HOSTED__=0 -Ttext 0x10000 \
    --emit-relocs -o "$d/$t.b.elf" "$d/rel.c" || fail "$t link at 0x10000"
  arm-none-eabi-objcopy -O binary "$d/$t.a.elf" "$d/$t.a.bin" || fail "$t objcopy a"
  arm-none-eabi-objcopy -O binary "$d/$t.b.elf" "$d/$t.b.bin" || fail "$t objcopy b"

  sites=$(arm-none-eabi-readelf -rW "$d/$t.a.elf" | grep R_ARM_ABS32 \
          | while read -r off rest; do printf '%d ' "0x$off"; done)
  [ -n "$sites" ] || fail "$t recorded no relocations at all"
  # cmp -l numbers bytes from 1; the image is 0-based
  diffs=$(cmp -l "$d/$t.a.bin" "$d/$t.b.bin" | while read -r i rest; do printf '%d ' "$((i - 1))"; done)
  [ -n "$diffs" ] || fail "$t the two links are identical -- nothing moved to check"

  # complete: every byte that moved lies inside a recorded 4-byte site
  for b in $diffs; do
    inside=0
    for s in $sites; do
      [ "$b" -ge "$s" ] && [ "$b" -lt "$((s + 4))" ] && inside=1
    done
    [ "$inside" = 1 ] || fail "$t byte $b moved and no relocation names it"
  done
  # minimal: every recorded site actually moved
  for s in $sites; do
    moved=0
    for b in $diffs; do
      [ "$b" -ge "$s" ] && [ "$b" -lt "$((s + 4))" ] && moved=1
    done
    [ "$moved" = 1 ] || fail "$t site $s is recorded and did not move"
  done
  n=0
  for s in $sites; do n=$((n + 1)); done
  echo "  $t: $n ABS32 sites slide by $delta, no other byte differs"
}

lane thumb1
lane thumb2sp

# and the refusal, which is the other half of the contract
LOVE_NO_IMAGE= "$m" mooncc -t thumb2 -D __STDC_HOSTED__=0 -Ttext 0x0 \
  --emit-relocs -o "$d/no.elf" "$d/rel.c" > "$d/no.err" 2>&1 \
  && fail "thumb2 took --emit-relocs; its MOVW/MOVT absolutes cannot be slid"
grep -q "MOVW/MOVT" "$d/no.err" \
  || fail "thumb2 refused for the wrong reason: $(cat "$d/no.err")"
grep -q "internal error" "$d/no.err" \
  && fail "thumb2 refused as an internal error, not as a flag it cannot answer"
echo "  thumb2: --emit-relocs refused up front, naming the split immediate"

# ..and the 64-bit seats, where the flag has no meaning at all: ldlink carries its
# own table under -pie. Silence there would have looked like a table that was laid.
LOVE_NO_IMAGE= "$m" mooncc -Ttext 0x0 --emit-relocs -o "$d/no64.elf" "$d/rel.c" \
  > "$d/no64.err" 2>&1 \
  && fail "x64 took --emit-relocs, which lays no table there"
grep -q -- "--emit-relocs is the arm32 lane" "$d/no64.err" \
  || fail "x64 refused for the wrong reason: $(cat "$d/no64.err")"
echo "  x64: --emit-relocs refused as a flag the seat has no answer for"

echo "test_reloc32: --emit-relocs lays a complete and minimal R_ARM_ABS32 table on the pooled-la seats, and refuses up front on the seat whose absolutes ride split immediates and on the seats that carry their own"
