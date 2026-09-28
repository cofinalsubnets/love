#!/bin/sh
# test/kore/grep.sh -- grep: the BRE and ERE batteries, the clustered flags, the step budget
. "$(dirname "$0")/common.sh"

# THE BACKTRACKER'S CLIFF, and it is timed on purpose. `(a|aa)+` over a run of a's
# is exponential in this engine -- it tries every split -- and before the step budget
# landed this line did not return AT ALL. What is gated is that it comes back, with
# the status and the sentence: a `grep` that hangs on a pattern a person can type is a
# different kind of defect from a wrong answer, and only a clock can see it.
awk 'BEGIN { s = ""; for (i = 0; i < 40; i++) s = s "a"; print s }' > "$ho/.rebt"
t0=$(date +%s)
korerun grep -E '^(a|aa)+b$' "$ho/.rebt" > /dev/null 2>&1
rc=$?
t1=$(date +%s)
[ "$rc" = 2 ] || fail "kore grep: the backtracker's budget must answer 2, got $rc"
[ $((t1 - t0)) -lt 20 ] || fail "kore grep: the budget did not bound the backtracking"
# and the budget must not fire on an ordinary repeat over the same text
korerun grep -E '^a+$' "$ho/.rebt" > /dev/null || fail "kore grep: a plain repeat must still match"
korerun grep -E '^(a|b)+$' "$ho/.rebt" > /dev/null \
  || fail "kore grep: an alternation of single charms must still match"
rm -f "$ho/.rebt"
echo "kore: grep's step budget (the (a|aa)+ cliff answers 2 in seconds, plain repeats untouched) ok"
printf 'abc\nxbz\nzzz\n+q\n*r\n' > "$ho/.gr1"; printf 'nope\nbc here\n' > "$ho/.gr2"
both "grep"          grep b "$ho/.gr1"
both "grep -n multi" grep -n b "$ho/.gr1" "$ho/.gr2"
both "grep -c"       grep -c b "$ho/.gr1" "$ho/.gr2"
both "grep -v"       grep -v b "$ho/.gr1"
both "grep -l"       grep -l b "$ho/.gr1" "$ho/.gr2"
pipe "grep -l stdin" 'q
'                    grep -l q
both "grep empty pattern" grep '' "$ho/.gr1"
# the BRE battery: star, anchors, classes, +/? , groups, and the two shapes where a
# leading + or * is a LITERAL because there is nothing to repeat
for p in 'ab*c' '^x' 'z$' '[abx]b' '[^a]b' 'b\+' 'xb\?z' '\(zz\)*z' '.z' '^\+q' '^*r' 'x[b-z]z' \
         'a\|z' 'abc\|zzz\|nope' '\(a\|x\)b' 'a\|b\|c' 'a\|' '\|a' \
         'b\{2\}' 'z\{2,\}' 'z\{1,2\}' '\{2\}' '\+q' 'a\{3,2\}' 'a\{2' \
         '[[:digit:]]' '[[:alpha:]][[:digit:]]' '[^[:alnum:]]' '[[:space:]]' \
         '[[:upper:]]' '[[:punct:]]' '[[:xdigit:]]' '[]a]' '[a-]' '[[:nope:]]'; do
  grep -c "$p" "$ho/.gr1" > "$g" 2>/dev/null; a=$?
  korerun grep -c "$p" "$ho/.gr1" > "$o" 2>/dev/null; b=$?
  cmp -s "$g" "$o" && [ $a -eq $b ] || fail "kore grep BRE '$p' vs GNU"
done
# the ERE battery. THE RAGGED EDGES ARE THE POINT: a loose repeat is DROPPED in
# ERE where BRE keeps it as ink, and an unclosed brace / stray ) are literals here
# and malformed there -- all four read off GNU, none of them guessable
for p in 'a|z' '(a|x)b' 'a{2}' 'z{2,}' 'z{1,2}' '[[:digit:]]+' 'a+' 'ab?c' '(a|b)+' \
         '^(a|x)' '(a|b|z)+$' 'a{1,2}b' '[[:digit:]]{2}' '*r' '+q' '?x' '{2}' \
         'a{' 'a)' 'a||z' 'a{3,2}' '(a'; do
  grep -Ec "$p" "$ho/.gr1" > "$g" 2>/dev/null; a=$?
  korerun grep -Ec "$p" "$ho/.gr1" > "$o" 2>/dev/null; b=$?
  cmp -s "$g" "$o" && [ $a -eq $b ] || fail "kore grep ERE '$p' vs GNU"
done
# the flag matrix, CLUSTERED as this tree's own scripts write them (-qF, -qiw, -oE):
# a walk that reads only whole words takes `-qF` for a pattern and passes every
# single-flag test while doing it
printf 'abc\nxbz\nzzz\n+q\n*r\nFoo Bar\nab_cd\nx{2}y\na1b2\n' > "$ho/.gr3"
# set -f FIRST: the word split below is deliberate, the PATHNAME EXPANSION that
# rides along with it is not -- `[a-z]*` and `*r` are globs, and an unguarded split
# hands grep whatever files happen to sit in the cwd instead of the pattern
set -f
for fl in '-c b' '-i FOO' '-i foo' '-w ab' '-w abc' '-x zzz' '-x zz' \
          '-F a\|z' '-F *r' '-F ab' '-o b' '-oE [a-z]+' '-n -i foo' '-h b' '-a b' \
          '-c -m 2 b' '-m 1 z' '-v b' '-iw foo' '-nv b' '-co b' '-iF foo' \
          '-ow [a-z]*' '-oE [0-9]|[A-Z]'; do
  # shellcheck disable=SC2086
  set -- $fl
  grep "$@" "$ho/.gr3" > "$g" 2>/dev/null; a=$?
  korerun grep "$@" "$ho/.gr3" > "$o" 2>/dev/null; b=$?
  cmp -s "$g" "$o" && [ $a -eq $b ] || fail "kore grep flags '$fl' vs GNU"
done
# THE EMPTY PATTERN IS ITS OWN ROW. `set -- $fl` word-splits, so an empty word cannot
# ride that list at all: the `-x ` and `-o ` rows above were really `grep -x FILE`, a
# pattern and NO file -- which reads STDIN, and hangs any run whose stdin is a pipe
# instead of a terminal. Both sides hung or both saw EOF, so it passed while proving
# nothing about the empty pattern it was written for.
for fl in -x -o -c -v; do
  grep $fl '' "$ho/.gr3" > "$g" 2>/dev/null; a=$?
  korerun grep $fl '' "$ho/.gr3" > "$o" 2>/dev/null; b=$?
  cmp -s "$g" "$o" && [ $a -eq $b ] || fail "kore grep $fl '' (the empty pattern) vs GNU"
done
set +f
# -e stacks and, once given, every positional word is a FILE
grep -e abc -e zzz "$ho/.gr3" > "$g"; korerun grep -e abc -e zzz "$ho/.gr3" > "$o"
same "grep -e stacking"
# -q is output-free and speaks only in the exit code (61 uses of it in this tree)
korerun grep -q b "$ho/.gr3" > "$o"; r=$?
[ $r -eq 0 ] && [ ! -s "$o" ] || fail "kore grep -q hit (exit $r, or it spoke)"
korerun grep -q qqq "$ho/.gr3" > "$o"; r=$?
[ $r -eq 1 ] && [ ! -s "$o" ] || fail "kore grep -q miss"
korerun grep b "$ho/.gr1" > /dev/null; r=$?; [ $r -eq 0 ] || fail "kore grep hit exit"
korerun grep qqq "$ho/.gr1" > /dev/null; r=$?; [ $r -eq 1 ] || fail "kore grep miss exit"
grep b "$ho/.gr-nope" 2> "$g"; a=$?
korerun grep b "$ho/.gr-nope" 2> "$o"; b=$?
cmp -s "$g" "$o" && [ $a -eq 2 ] && [ $b -eq 2 ] || fail "kore grep missing file vs GNU"
korerun grep b "$ho/.gr1" "$ho/.gr-nope" > /dev/null 2>&1; r=$?
[ $r -eq 2 ] || fail "kore grep err beats match exit"
# the two old spellings are grep -E and grep -F by name
printf 'a+b\naab\nx.y\n' > "$ho/.gr-eg"
for c in "egrep a+b" "fgrep a+b" "egrep -c x|a" "fgrep -v x.y"; do
  set -- $c
  "$@" "$ho/.gr-eg" > "$g" 2>/dev/null; korerun "$@" "$ho/.gr-eg" > "$o" 2>/dev/null; same "$c"
done
# a pattern reads utf-8 by character: GNU's answers under a utf-8 locale, spelled out so
# the gate's own locale cannot move them
gc() { want=$1; shift; got=$(printf '日本語 éé\na\377b\n' | korerun grep -ao "$@" | tr '\n' '|')
       [ "$got" = "$want" ] || fail "kore grep -o $* by character: got [$got] want [$want]"; }
gc '本語|' '本.'
gc 'éé|' 'é*'
gc '日本|éé|a|b|' -E '[^ 語]+'
gc '語 é|' '[à-語][^a]é'
gc '' 'a.b'
gc '' 'a[^x]b'
# the POSIX classes past ascii, and -i by gnulib's fold (ſ takes s, İ does not take i)
gi() { want=$1; shift; got=$(printf 'naïve ٣—x\nSTRAßE ſ İ\n' | korerun grep -o "$@" | tr '\n' '|')
       [ "$got" = "$want" ] || fail "kore grep -o $* by class: got [$got] want [$want]"; }
gi 'naïve|٣|x|STRAßE|ſ|İ|' '[[:alpha:]]*'
gi '—|' '[[:punct:]]'
gi 'STRAßE|' -i 'straße'
gi 'S|ſ|' -i 's'
gi '' -i 'i'
echo "kore: grep (BRE + ERE batteries + the clustered flag matrix GNU-identical, the exit triple, egrep/fgrep) ok"
