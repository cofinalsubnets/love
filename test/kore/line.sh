#!/bin/sh
# test/kore/line.sh -- sort, uniq, head, tail, wc, cat, tac, seq, echo, basename, tee
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
# tee writes twice: the file half is checked as well as the stream half
printf 'q\nq\nr\n' | tee "$ho/.cu-g2" > "$g"
printf 'q\nq\nr\n' | korerun tee "$ho/.cu-o2" > "$o"
cmp -s "$g" "$o" && cmp -s "$ho/.cu-g2" "$ho/.cu-o2" || fail "kore tee vs GNU"
echo "kore: line tools (sort/uniq/head/tail/wc/cat/tac/seq/echo/basename/tee GNU-identical) ok"

# sort's and ls's own flag matrices are subjects of their own (sort.sh, ls.sh): each
# sets its own LC_ALL, and ls.sh its own TZ, so neither can be compared under a
# collation or a clock this tree does not carry.
