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
echo "kore: line tools (sort/uniq/head/tail/wc/cat/tac/shuf/seq/echo/basename/tee GNU-identical) ok"

# sort's and ls's own flag matrices are subjects of their own (sort.sh, ls.sh): each
# sets its own LC_ALL, and ls.sh its own TZ, so neither can be compared under a
# collation or a clock this tree does not carry.
