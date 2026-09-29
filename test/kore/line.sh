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
# the SIGNED counts: `tail -n +N` opens at line N and `head -n -N` drops the last N.
# both used to read as a plain count through uatoi, which has no sign, so each answered
# an EMPTY stream and exit 0 -- the shape a gate that only ever writes `-n 2` cannot see.
for c in "+1" "+2" "+9" "2" "-2"; do
  both "tail -n $c"  tail -n "$c" "$ho/.cu1"
  both "head -n $c"  head -n "$c" "$ho/.cu1"
done
# -c: bytes, the last of -c/-n winning, -c -N all but the last N, GNU's multipliers,
# and a byte clip that stops reading -- /dev/zero holds no newline to stop a line one
for c in "-c 3" "-c3" "-c 0" "-c 100" "-c -2" "-c -100" "-c +3" "-n 2 -c 3" "-c 3 -n 2" "--bytes=4" "-c 1b"; do
  # shellcheck disable=SC2086
  both "head $c"  head $c "$ho/.cu1" "$ho/.cu2"
done
[ "$(korerun head -c 48 /dev/zero | wc -c)" -eq 48 ] || fail "kore head -c must stop reading"
for c in "-c 3" "-c3" "-c 0" "-n 0" "-c 100" "-c +3" "-c +0" "-n +0" "-c +100" "-n 2 -c 3" "-c 3 -n 2" "--bytes=+4" "-c 1b"; do
  # shellcheck disable=SC2086
  both "tail $c"  tail $c "$ho/.cu1" "$ho/.cu2"
done
korerun head -c 3x "$ho/.cu1" > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore head -c 3x must refuse (rc $r)"
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
# the newline rides the line it FOLLOWED: a last line arriving without one comes
# back FIRST without one, which is the whole of tac's shape and easy to get wrong
printf 'x\ny' > "$ho/.cu3"
both "tac no-nl" tac "$ho/.cu3"
# the separator (-s, NUL when empty), before rather than after (-b), and a regex in
# Emacs's syntax (-r), GNU's backward search cutting a run into single digits
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
# shuf answers no fixed order, so it is held to GNU through sort: the same records,
# each once, a last one without its newline given one
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
# a shuf that never moves a record passes every check above; two identities running is 1 in 30!^2
a=$(korerun shuf -i 1-30 | tr '\n' ' '); b=$(korerun shuf -i 1-30 | tr '\n' ' ')
[ "$a" != "$b" ] || [ "$a" != "$(seq 30 | tr '\n' ' ')" ] || fail "kore shuf: the order never moves"
# tee writes twice: the file half is checked as well as the stream half
printf 'q\nq\nr\n' | tee "$ho/.cu-g2" > "$g"
printf 'q\nq\nr\n' | korerun tee "$ho/.cu-o2" > "$o"
cmp -s "$g" "$o" && cmp -s "$ho/.cu-g2" "$ho/.cu-o2" || fail "kore tee vs GNU"
[ "$(printf '日本語 かな\n\xff' | korerun wc -m)" = "7" ] \
  || fail "kore wc -m: valid characters, a stray byte none"
# cat's line flags, uniq's comparisons and head/tail's headers against GNU; a file with no
# final newline runs on into the next, as GNU's does
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
# a stranger or a trailing flag refuses with 2 -- they were opened as files
for c in "cat -x" "head -x" "tail -x" "wc -x" "uniq -x" "nl -x" "cut -f1 -x" "paste -x" "split -Q" "join -x $L/i2" "cat $L/i2 -n"; do
  # shellcheck disable=SC2086
  korerun $c "$L/i1" > /dev/null 2>&1; r=$?; [ $r -eq 2 ] || fail "kore $c must refuse (rc $r)"
done
rm -rf "$L"
# tail -f: what is added after the tail comes out as it lands, a last line with no newline
# too; -F follows the name through a replacement, a file that appears and a truncation
T=$ho/.tailf; rm -rf "$T"; mkdir "$T"; printf '1\n2\n3\n' > "$T/f"
# the binary itself, not korerun: a function backgrounds a subshell and the kill stops there
LOVE_NO_IMAGE= "$m" kore tail -n 2 -f -s 0.1 "$T/f" > "$T/o1" 2>&1 & tp=$!
sleep 0.5; echo 4 >> "$T/f"; sleep 0.4; printf 'five' >> "$T/f"; sleep 0.4; kill $tp; wait $tp 2> /dev/null
[ "$(cat "$T/o1")" = "$(printf '2\n3\n4\nfive')" ] || fail "kore tail -f: $(tr '\n' '|' < "$T/o1")"
printf 'a\n' > "$T/g"
LOVE_NO_IMAGE= "$m" kore tail -F -s 0.1 -n 1 "$T/g" > "$T/o2" 2> /dev/null & tp=$!
sleep 0.4; echo b >> "$T/g"; sleep 0.3; echo new > "$T/g2"; mv "$T/g2" "$T/g"; sleep 0.4
: > "$T/g"; echo c >> "$T/g"; sleep 0.4; kill $tp; wait $tp 2> /dev/null
[ "$(tr '\n' '|' < "$T/o2")" = "a|b|new|c|" ] || fail "kore tail -F: $(tr '\n' '|' < "$T/o2")"
rm -rf "$T"
# seq's fractions, exact and with FIRST's and INCR's decimals, negatives that are not
# flags, -w -s -f and the long names, a count that runs no lines
for c in "5" "5 -1 1" "-5 -2" "0 0.5 2" "1 0.1 1.3" "0.5 3" "1 0.5 2.25" "-1.5 0.5 1" "-w 1 10" "-w -5 5" "-w 0 0.5 10" "-s , 1 5" \
         "-f %.3f 1 3" "-f %05.1f 0 0.5 2" "-w -s: 8 11" "--separator=- 1 3" "--equal-width 9 11" "10 1"; do
  # shellcheck disable=SC2086
  seq $c > "$g" 2>&1; korerun seq $c > "$o" 2>&1; same "seq $c"
done
# wc -L: the widest line in columns -- a tab to its stop, a return ending a line, CJK two
# wide, a last line with no newline -- alone, among the others, and the total the widest
W=$ho/.wcl; printf 'short\na much longer line here\n\ttab\nx\r\n\346\227\245\346\234\254\350\252\236\n' > "$W"; printf 'no newline at all but long' > "$W.j"; printf 'ab\tc\t\tx\ny\n' > "$W.t"
for c in "-L $W" "-L $W.j" "-L $W.t" "-lL $W" "-L $W $W.j" "-clwmL $W" "-Lc $W.j"; do
  # shellcheck disable=SC2086
  LC_ALL=C.UTF-8 wc $c > "$g"; korerun wc $c > "$o"; same "wc $c"
done
rm -f "$W" "$W.j" "$W.t"
# tee -i ignores SIGINT: read off its /proc mask while it runs in the foreground (a
# background job has SIGINT ignored already, so killing one proves nothing); it waits
# on a fifo held open both ways until the reader has looked, then is ended; -p is taken
TI=$ho/.teei; M2=$PWD/$m; rm -f "$TI.f"; mkfifo "$TI.f"
( k=0; while [ $k -lt 50 ]; do
    for p in $(pgrep -x love); do
      tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null | grep -q "kore tee -i $TI" && { grep SigIgn /proc/$p/status; kill $p; exit 0; }
    done; k=$((k + 1)); sleep 0.1
  done ) > "$TI.m" &
# a real process of its own: the tool shell runs kore's tools aboard
LOVE_NO_IMAGE= /bin/sh -c 'exec "$0" kore tee -i "$1" <> "$2" > /dev/null' "$M2" "$TI" "$TI.f"; wait
sgm=$(awk '{ print $2 }' "$TI.m"); [ $(( 0x${sgm:-0} & 2 )) -eq 2 ] || fail "kore tee -i: SigIgn $sgm"
printf 'a\nb\n' | korerun tee -p "$TI" > /dev/null && [ "$(cat "$TI")" = "$(printf 'a\nb')" ] || fail "kore tee -p"
rm -f "$TI" "$TI.m" "$TI.f"
# echo's -e and -E, the later winning, clustered with -n; \c, octal, hex, \u; a word
# that is not all of n e E is text; against GNU's /usr/bin/echo, not the shell's
if [ -x /usr/bin/echo ]; then
  for c in "-e a\tb\nc" "-E a\tb" "a\tb" "-ne a\n" "-en x\cy" "-e \0101\x42\e" "-eE a\tb" "-e -E a\tb" "-E -e a\tb" "-x hi" "-nx y" "-e é \\\\ \q"; do
    # shellcheck disable=SC2086
    /usr/bin/echo $c > "$g"; korerun echo $c > "$o"; same "echo $c"
  done
fi
# uniq's -D (every line of a run), -w N, -z, with -i -c -s beside them
printf 'a 1\nA 1\nb 2\nb 2\nc  x 3\nd  y 3\ne\ne\ne\nabcX\nabcY\n' > "$ho/.uqd"; printf 'a\0a\0b\0' > "$ho/.uqz"
for c in "-D" "-D -i" "-w 3" "-w 3 -c" "-D -w 3" "-s 1 -w 1"; do
  # shellcheck disable=SC2086
  uniq $c "$ho/.uqd" > "$g"; korerun uniq $c "$ho/.uqd" > "$o"; same "uniq $c"
done
for c in -z -zc; do uniq $c "$ho/.uqz" > "$g"; korerun uniq $c "$ho/.uqz" > "$o"; same "uniq $c"; done
rm -f "$ho/.uqd" "$ho/.uqz"
echo "kore: line tools (sort/uniq/head/tail/wc/cat/tac/shuf/seq/echo/basename/tee GNU-identical) ok"

# sort's and ls's own flag matrices are subjects of their own (sort.sh, ls.sh): each
# sets its own LC_ALL, and ls.sh its own TZ, so neither can be compared under a
# collation or a clock this tree does not carry.
