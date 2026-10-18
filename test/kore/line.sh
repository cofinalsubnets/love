#!/bin/sh
# test/kore/line.sh -- sort, uniq, head, tail, wc, cat, tac, shuf, seq, echo, basename, tee
. "$(dirname "$0")/common.sh"

printf 'b\na\nc\nb\n' > "$ho/.cu1"; printf 'x y\nz\n' > "$ho/.cu2"
LC_ALL=C sort "$ho/.cu1" > "$g"; korerun sort "$ho/.cu1" > "$o"; same "sort"
LC_ALL=C sort -u "$ho/.cu1" > "$g"; korerun sort -u "$ho/.cu1" > "$o"; same "sort -u"
LC_ALL=C sort "$ho/.cu1" | uniq -c > "$g"
korerun sort "$ho/.cu1" | korerun uniq -c > "$o"; same "uniq -c"
both "head"     head -n 2 "$ho/.cu1" "$ho/.cu2"
both "tail"     tail -n 2 "$ho/.cu1" "$ho/.cu2"
# the signed counts: tail -n +N opens at line N, head -n -N drops the last N
for c in "+1" "+2" "+9" "2" "-2"; do
  both "tail -n $c"  tail -n "$c" "$ho/.cu1"
  both "head -n $c"  head -n "$c" "$ho/.cu1"
done
# -c: bytes, the last of -c/-n winning, -c -N, multipliers, and a clip that stops reading /dev/zero
for c in "-c 3" "-c3" "-c 0" "-c 100" "-c -2" "-c -100" "-c +3" "-n 2 -c 3" "-c 3 -n 2" "--bytes=4" "-c 1b"; do
  # shellcheck disable=SC2086
  both "head $c"  head $c "$ho/.cu1" "$ho/.cu2"
done
[ "$(korerun head -c 48 /dev/zero | wc -c)" -eq 48 ] || fail "head -c must stop reading"
for c in "-c 3" "-c3" "-c 0" "-n 0" "-c 100" "-c +3" "-c +0" "-n +0" "-c +100" "-n 2 -c 3" "-c 3 -n 2" "--bytes=+4" "-c 1b"; do
  # shellcheck disable=SC2086
  both "tail $c"  tail $c "$ho/.cu1" "$ho/.cu2"
done
korerun head -c 3x "$ho/.cu1" > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "head -c 3x must refuse (rc $r)"
both "tail -n +2 many"  tail -n +2 "$ho/.cu1" "$ho/.cu2"
both "head -n -1 many"  head -n -1 "$ho/.cu1" "$ho/.cu2"
printf 'x\ny' > "$ho/.cun"                  # no trailing newline: the clip must keep that
both "head -n -1 no-nl" head -n -1 "$ho/.cun"
both "tail -n +2 no-nl" tail -n +2 "$ho/.cun"
pipe "tail -n +2 stdin" 'a
b
c
'                       tail -n +2
both "wc"       wc "$ho/.cu1" "$ho/.cu2"
wc -l < "$ho/.cu1" > "$g"; korerun wc -l < "$ho/.cu1" > "$o"; same "wc -l stdin"
both "cat"      cat "$ho/.cu1" "$ho/.cu2"
both "seq"      seq 5
both "echo"     echo hi there
both "basename" basename /a/b.txt .txt
both "tac"      tac "$ho/.cu1" "$ho/.cu2"
# tac: a last line without a newline comes back first without one
printf 'x\ny' > "$ho/.cu3"
both "tac no-nl" tac "$ho/.cu3"
# -s (NUL when empty), -b before, -r an emacs regex, gnu's backward search splitting a run
printf 'x,y,,z,' > "$ho/.cu4"; printf 'one12two345three6' > "$ho/.cu5"
printf 'aXXXbXXc' > "$ho/.cu6"; printf 'a\0b\0c' > "$ho/.cu7"; printf 'catdogcowdog' > "$ho/.cu8"
both "tac -s"           tac -s , "$ho/.cu4"
both "tac -bs"          tac -bs , "$ho/.cu4"
both "tac -b"           tac -b "$ho/.cu1"
both "tac overlap"      tac -s XX "$ho/.cu6"
both "tac -s ''"        tac -s '' "$ho/.cu7"
both "tac -r backward"  tac -r -s '[0-9][0-9]*' "$ho/.cu5"
both "tac -r emacs"     tac -r -s '[0-9]\+' "$ho/.cu5"
both "tac -r group"     tac -r -s '\(o\|g\)' "$ho/.cu8"
both "tac -br"          tac -b -r -s 'd.g' "$ho/.cu8"
# shuf has no fixed order: held to gnu through sort, each record once, a last one given a newline
for t in "shuf" "shuf -n 9"; do
  # shellcheck disable=SC2086
  $t "$ho/.cu1" | LC_ALL=C sort > "$g"; korerun $t "$ho/.cu1" | LC_ALL=C sort > "$o"; same "$t"
  $t "$ho/.cu3" | LC_ALL=C sort > "$g"; korerun $t "$ho/.cu3" | LC_ALL=C sort > "$o"; same "$t no-nl"
done
shuf -i 7-300 | sort -n > "$g"; korerun shuf -i 7-300 | sort -n > "$o"; same "shuf -i"
shuf -e p q r s | LC_ALL=C sort > "$g"; korerun shuf -e p q r s | LC_ALL=C sort > "$o"; same "shuf -e"
printf 'a\0b\0c' | shuf -z | tr '\0' '\n' | LC_ALL=C sort > "$g"
printf 'a\0b\0c' | korerun shuf -z | tr '\0' '\n' | LC_ALL=C sort > "$o"; same "shuf -z"
[ "$(korerun shuf -n 3 -i 1-1000000000 | sort -u | wc -l)" -eq 3 ] || fail "kore shuf -n: three distinct draws"
[ "$(korerun shuf -r -n 40 -e a b | sort -u | tr -d '\n')" = ab ] || fail "kore shuf -r: 40 draws over a b"
korerun shuf -r < /dev/null > /dev/null 2>&1 && fail "kore shuf -r: nothing to repeat must refuse"
# a shuf that never moves a record passes the above; two identity runs is 1 in 30!^2
a=$(korerun shuf -i 1-30 | tr '\n' ' '); b=$(korerun shuf -i 1-30 | tr '\n' ' ')
[ "$a" != "$b" ] || [ "$a" != "$(seq 30 | tr '\n' ' ')" ] || fail "kore shuf: the order never moves"
# tee: the file half as well as the stream
printf 'q\nq\nr\n' | tee "$ho/.cu-g2" > "$g"
printf 'q\nq\nr\n' | korerun tee "$ho/.cu-o2" > "$o"
cmp -s "$g" "$o" && cmp -s "$ho/.cu-g2" "$ho/.cu-o2" || fail "kore tee vs GNU"
[ "$(printf '日本語 かな\n\xff' | korerun wc -m)" = "7" ] \
  || fail "kore wc -m: valid characters, a stray byte none"
# cat's line flags, uniq's comparisons, head/tail headers; a file with no final newline runs on
L=$ho/.lineflags; rm -rf "$L"; mkdir "$L"
printf 'a\tb\n\n\n\nc\001d\177\n\200\211x\377\n\nlast' > "$L/i1"; printf 'one\n\ntwo\n' > "$L/i2"
for f in -n -b -s -E -T -v -A -e -t -ns -bs -nE -u; do
  cat $f "$L/i1" "$L/i2" > "$g"; korerun cat $f "$L/i1" "$L/i2" > "$o"; same "cat $f"
done
printf 'a 1\nA 1\nb 2\nb 2\nc  x 3\nd  y 3\ne\ne\ne\n' > "$L/u"
for f in -c -d -u -i -ic "-f 1" "-s 1" "-f 1 -s 1" -cd -cu "-f 2"; do
  # shellcheck disable=SC2086
  uniq $f "$L/u" > "$g"; korerun uniq $f "$L/u" > "$o"; same "uniq $f"
done
korerun uniq "$L/u" "$L/uo" && uniq "$L/u" > "$g" && cmp -s "$g" "$L/uo" || fail "kore uniq INPUT OUTPUT"
head -v "$L/i2" > "$g"; korerun head -v "$L/i2" > "$o"; same "head -v"
tail -q -n1 "$L/i1" "$L/i2" > "$g"; korerun tail -q -n1 "$L/i1" "$L/i2" > "$o"; same "tail -q"
# an unknown or trailing flag refuses with 2
for c in "cat -x" "head -x" "tail -x" "wc -x" "uniq -x" "nl -x" "cut -f1 -x" "paste -x" "split -Q" "join -x $L/i2" "cat $L/i2 -n"; do
  # shellcheck disable=SC2086
  korerun $c "$L/i1" > /dev/null 2>&1; r=$?; [ $r -eq 2 ] || fail "kore $c must refuse (rc $r)"
done
rm -rf "$L"
# tail -f: additions as they land, a last line without newline too; -F follows a replacement,
# a file that appears, and a truncation
T=$ho/.tailf; rm -rf "$T"; mkdir "$T"; printf '1\n2\n3\n' > "$T/f"
# the tail names its own pid: in the tool shell $! is a fork
MT=$PWD/$m
LOVE_NO_IMAGE= /bin/sh -c 'echo $$ > "$1.pid"; exec "$0" tail -n 2 -f -s 0.1 "$1"' "$MT" "$T/f" > "$T/o1" 2>&1 &
sleep 0.5; echo 4 >> "$T/f"; sleep 0.4; printf 'five' >> "$T/f"; sleep 0.4; kill "$(cat "$T/f.pid")"; wait
[ "$(cat "$T/o1")" = "$(printf '2\n3\n4\nfive')" ] || fail "kore tail -f: $(tr '\n' '|' < "$T/o1")"
printf 'a\n' > "$T/g"
LOVE_NO_IMAGE= /bin/sh -c 'echo $$ > "$1.pid"; exec "$0" tail -F -s 0.1 -n 1 "$1"' "$MT" "$T/g" > "$T/o2" 2> /dev/null &
sleep 0.4; echo b >> "$T/g"; sleep 0.3; echo new > "$T/g2"; mv "$T/g2" "$T/g"; sleep 0.4
: > "$T/g"; echo c >> "$T/g"; sleep 0.4; kill "$(cat "$T/g.pid")"; wait
[ "$(tr '\n' '|' < "$T/o2")" = "a|b|new|c|" ] || fail "kore tail -F: $(tr '\n' '|' < "$T/o2")"
rm -rf "$T"
# seq: fractions, FIRST's and INCR's decimals, negatives, -w -s -f, a count that runs no lines
for c in "5" "5 -1 1" "-5 -2" "0 0.5 2" "1 0.1 1.3" "0.5 3" "1 0.5 2.25" "-1.5 0.5 1" "-w 1 10" "-w -5 5" "-w 0 0.5 10" "-s , 1 5" \
         "-f %.3f 1 3" "-f %05.1f 0 0.5 2" "-w -s: 8 11" "--separator=- 1 3" "--equal-width 9 11" "10 1"; do
  # shellcheck disable=SC2086
  seq $c > "$g" 2>&1; korerun seq $c > "$o" 2>&1; same "seq $c"
done
# wc -L in columns: tab stops, a return, cjk double width, no final newline; and the total
W=$ho/.wcl; printf 'short\na much longer line here\n\ttab\nx\r\n\346\227\245\346\234\254\350\252\236\n' > "$W"; printf 'no newline at all but long' > "$W.j"; printf 'ab\tc\t\tx\ny\n' > "$W.t"
for c in "-L $W" "-L $W.j" "-L $W.t" "-lL $W" "-L $W $W.j" "-clwmL $W" "-Lc $W.j"; do
  # shellcheck disable=SC2086
  LC_ALL=C.UTF-8 wc $c > "$g"; korerun wc $c > "$o"; same "wc $c"
done
rm -f "$W" "$W.j" "$W.t"
# tee -i ignores SIGINT, read off /proc while in the foreground (a background job ignores it
# already); it waits on a fifo until read, then is ended; -p is taken
TI=$ho/.teei; M2=$PWD/$m; rm -f "$TI.f"; mkfifo "$TI.f"
( k=0; while [ $k -lt 50 ]; do
    for p in $(pgrep -x love); do
      tr '\0' ' ' 2>/dev/null < /proc/$p/cmdline | grep -q "tee -i $TI" && { grep SigIgn /proc/$p/status; kill $p; exit 0; }
    done; k=$((k + 1)); sleep 0.1
  done ) > "$TI.m" &
# a real process: the tool shell runs kore's tools aboard
LOVE_NO_IMAGE= /bin/sh -c 'exec "$0" tee -i "$1" <> "$2" > /dev/null' "$M2" "$TI" "$TI.f"; wait
sgm=$(awk '{ print $2 }' "$TI.m"); [ $(( 0x${sgm:-0} & 2 )) -eq 2 ] || fail "kore tee -i: SigIgn $sgm"
printf 'a\nb\n' | korerun tee -p "$TI" > /dev/null && [ "$(cat "$TI")" = "$(printf 'a\nb')" ] || fail "kore tee -p"
rm -f "$TI" "$TI.m" "$TI.f"
# echo -e/-E, the later winning, with -n; \c, octal, hex, \u; a word not all of neE is text;
# against /usr/bin/echo, not the shell's
if [ -x /usr/bin/echo ]; then
  for c in "-e a\tb\nc" "-E a\tb" "a\tb" "-ne a\n" "-en x\cy" "-e \0101\x42\e" "-eE a\tb" "-e -E a\tb" "-E -e a\tb" "-x hi" "-nx y" "-e é \\\\ \q"; do
    # shellcheck disable=SC2086
    /usr/bin/echo $c > "$g"; korerun echo $c > "$o"; same "echo $c"
  done
fi
# uniq -D, -w N, -z, beside -i -c -s
printf 'a 1\nA 1\nb 2\nb 2\nc  x 3\nd  y 3\ne\ne\ne\nabcX\nabcY\n' > "$ho/.uqd"; printf 'a\0a\0b\0' > "$ho/.uqz"
for c in "-D" "-D -i" "-w 3" "-w 3 -c" "-D -w 3" "-s 1 -w 1"; do
  # shellcheck disable=SC2086
  uniq $c "$ho/.uqd" > "$g"; korerun uniq $c "$ho/.uqd" > "$o"; same "uniq $c"
done
for c in -z -zc; do uniq $c "$ho/.uqz" > "$g"; korerun uniq $c "$ho/.uqz" > "$o"; same "uniq $c"; done
rm -f "$ho/.uqd" "$ho/.uqz"
echo "kore: line tools (sort/uniq/head/tail/wc/cat/tac/shuf/seq/echo/basename/tee GNU-identical) ok"
