#!/bin/sh
# test/kore/record.sh -- paste, comm, join, split, od
. "$(dirname "$0")/common.sh"

# paste / comm / join / split / od, against the GNU tools. `both` carries most of
# it; split is checked by its EFFECT (the pieces it writes), which is the only
# thing it produces at all.
rt=$ho/.kore-rec
rm -rf "$rt"; mkdir -p "$rt"
printf 'a\nb\nc\n' > "$rt/p1"; printf '1\n2\n' > "$rt/p2"; printf 'X\nY\nZ\nW\n' > "$rt/p3"
both "paste"       paste "$rt/p1" "$rt/p2"
both "paste 3"     paste "$rt/p1" "$rt/p2" "$rt/p3"
both "paste -d"    paste -d: "$rt/p1" "$rt/p3"
# the delimiter LIST cycles per gap and starts over each row -- a two-delimiter
# list over three columns is the only shape that can tell that from "the first one"
both "paste -d2"   paste -d':|' "$rt/p1" "$rt/p2" "$rt/p3"
both "paste -s"    paste -s "$rt/p1" "$rt/p2"
both "paste -s -d" paste -s -d, "$rt/p1" "$rt/p3"
printf 'apple\nbanana\ncherry\n' > "$rt/c1"; printf 'banana\ndate\n' > "$rt/c2"
for fl in '' -1 -2 -3 -12 -13 -23 -123; do
  # shellcheck disable=SC2086
  both "comm $fl" comm $fl "$rt/c1" "$rt/c2"
done
printf 'a 1 x\nb 2 y\nc 3 z\nc 4 w\n' > "$rt/j1"; printf 'a A\nc C\nc D\nd E\n' > "$rt/j2"
printf 'a:1:x\nb:2:y\nc:3:z\n' > "$rt/j3"; printf 'a:A\nc:C\n' > "$rt/j4"
printf '  a   1  \nb 2\n' > "$rt/j5"; printf 'a A\nb B\n' > "$rt/j6"
both "join"         join "$rt/j1" "$rt/j2"
both "join -a1"     join -a 1 "$rt/j1" "$rt/j2"
both "join -a1 -a2" join -a 1 -a 2 "$rt/j1" "$rt/j2"
both "join -v1"     join -v 1 "$rt/j1" "$rt/j2"
both "join -v2"     join -v 2 "$rt/j1" "$rt/j2"
both "join -t:"     join -t: "$rt/j3" "$rt/j4"
both "join -t: -a1" join -t: -a 1 "$rt/j3" "$rt/j4"
both "join -1 -2"   join -1 2 -2 1 "$rt/j1" "$rt/j2"
both "join blanks"  join "$rt/j5" "$rt/j6"
# a key repeated on BOTH sides is the whole cross product, in file-1-outer order
both "join cross"   join "$rt/j1" "$rt/j1"
# split writes files and says nothing: the pieces are the comparison
seq 1 25 > "$rt/sq"; printf 'a\nb' > "$rt/nonl"; : > "$rt/none"
sp() { n=$1; shift
       rm -rf "$rt/sg" "$rt/so"; mkdir -p "$rt/sg" "$rt/so"
       ( cd "$rt/sg" && split "$@" ) 2>/dev/null
       ( cd "$rt/so" && LOVE_NO_IMAGE= "$K" kore split "$@" ) 2>/dev/null
       diff -r "$rt/sg" "$rt/so" > /dev/null 2>&1 || fail "kore split $n vs GNU"; }
sp "-l 10"   -l 10 ../sq
sp "-l 7 pre" -l 7 ../sq pre
sp "-b 13"   -b 13 ../sq
sp "-a 3"    -l 5 -a 3 ../sq
sp "-d"      -l 9 -d ../sq
sp "no final newline" -l 1 ../nonl
sp "empty writes nothing" -l 5 ../none
# od: the address radices, the readings, the limits, and the `*` a repeat collapses to
printf 'hello\nworld\n\001\002\377' > "$rt/o1"
printf 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB' > "$rt/odup"
printf '\0\1\7\10\11\12\13\14\15\134\177\377abc' > "$rt/oesc"
: > "$rt/oempty"
for f in o1 odup oesc oempty; do
  for fl in '' -c -b -x -a -d -s -i -tx1 -tx4 -to1 -to4 -tu1 -tu4 -td1 -td4 -tc -ta \
            -Ad -Ax -An '-v -c' '-N 5 -c' '-j 3 -c' '-j 3 -N 4 -c'; do
    # shellcheck disable=SC2086
    both "od $fl $f" od $fl "$rt/$f"
  done
done
both "od -An -tx1"  od -An -tx1 "$rt/o1"
both "od two files" od -c "$rt/o1" "$rt/oesc"
both "od -Ax -to2"  od -Ax -to2 "$rt/o1"
# od READS its operands now, a row at a time off a joined stream, so a row that
# spans a 4096-byte gulp, a -j that skips past one, and a `*` run that crosses one
# are all new seams -- and every fixture above is under fifty bytes.
awk 'BEGIN{for(i=0;i<1300;i++)printf "0123456789abcdef"}' > "$rt/obig"   # 20800, all dup
head -c 9000 /dev/urandom > "$rt/orand"
for fl in -c -tx1 '-j 4090 -c' '-j 4096 -tx1' '-N 4100 -c' '-j 4000 -N 200 -tx1' -v; do
  # shellcheck disable=SC2086
  both "od $fl obig"  od $fl "$rt/obig"
  both "od $fl orand" od $fl "$rt/orand"
done
both "od join skip"  od -j 5000 -tx1 "$rt/orand" "$rt/obig"
both "od join lim"   od -N 9100 -c   "$rt/orand" "$rt/obig"
both "od join three" od -tx1 "$rt/o1" "$rt/orand" "$rt/oesc"
# -j past the end of the COMBINED input is a diagnostic, and -j exactly at it is not
korerun od -j 999999 -c "$rt/o1" >/dev/null 2>&1 && fail "kore od: -j past the end must fail"
both "od -j at end" od -j 14 -c "$rt/o1"
echo "kore: record tools (paste/comm/join/split/od GNU-identical -- od over 4 files x 24 readings) ok"
echo "kore: od across the gulps (rows, -j, -N and the * run over 4096) ok"
