#!/bin/sh
# test/kore/sed.sh -- sed: s///gp, y, {}, d/p/q, addresses, -E/-e/-i and the per-file model
. "$(dirname "$0")/common.sh"

printf 'abc\nxbz\nzzz\nq4\nw5\n' > "$ho/.sd1"
for sc in 's/b/X/' 's/z/Q/g' '2d' '/x/,/q/d' '$d' '2q' 's/x*/-/g' 's/\(b*\)z/[\1]/' \
          's/b/[&]/' 's|z|_|g' 's/a/1/; s/b/2/' 's/q\(.\)/<\1>/' \
          's/a\|z/Y/g' 's/[[:digit:]]/#/g' 's/b\{2\}/B/' '/a\|q/d' 's/\(a\|x\)b/@/' \
          '/x/!d' '2! d' '$!s/z/Q/g' '2,4!d' '/^q4$/!s/[a-z].*/_/' \
          'y/abz/ABZ/' 'y,b/,\n_,' '2y/z/\\/;s/z/y/'; do
  sed "$sc" "$ho/.sd1" > "$g"; a=$?
  korerun sed "$sc" "$ho/.sd1" > "$o"; b=$?
  cmp -s "$g" "$o" && [ $a -eq $b ] || fail "kore sed '$sc' vs GNU"
done
# { } groups under an address, nested and negated; a bracket holds the delimiter as a byte
printf 'a/b]c:d\nxbz\nzzz\n' > "$ho/.sd2"
for sc in '/b/{s/b/X/;p}' '/b/!{p;p}' '2,3{/z/d;p}' '/a/{/b/{s/a/Q/};s/c/C/;p}' '$!{$!d};p' \
          '/x/,/z/{p;}' '{};p' 's/[/]/X/p' 's:[:]:X:p' 's/[]/]/X/gp' 's/[^]/]/X/gp' \
          's:[[:alpha:]]:Q:gp' '/[/]/s/a/A/p' '{p' 'p}' 's/[/X/'; do
  sed -n "$sc" "$ho/.sd2" > "$g" 2>/dev/null; a=$?
  korerun sed -n "$sc" "$ho/.sd2" > "$o" 2>/dev/null; b=$?
  cmp -s "$g" "$o" && [ $a -eq $b ] || fail "kore sed -n '$sc' vs GNU"
done
# -f takes a commented script: whole-line comments, and one after a command
printf '#!/bin/sed -f\n# drop the b lines\n\n/b/d   # gone\ns/z/Z/g;# then this\n' > "$ho/.sd3"
sed -f "$ho/.sd3" "$ho/.sd2" > "$g"; korerun sed -f "$ho/.sd3" "$ho/.sd2" > "$o"; same "sed -f with # comments"
# a y whose sets differ in length, or with a tail, is refused: exit 1, nothing out
for sc in 'y/ab/c/' 'y/a/b/x'; do
  sed "$sc" "$ho/.sd1" > "$g" 2>/dev/null; a=$?
  korerun sed "$sc" "$ho/.sd1" > "$o" 2>/dev/null; b=$?
  cmp -s "$g" "$o" && [ $a -eq $b ] || fail "kore sed '$sc' vs GNU"
done
# -E moves the backslashes; the dialect must reach BOTH an address and an s
for sc in 's/(a|x)b/@/' 's/a|z/Y/g' 's/[[:digit:]]+/#/' '/a|q/d' 's/b{1,2}/B/'; do
  sed -E "$sc" "$ho/.sd1" > "$g"; a=$?
  korerun sed -E "$sc" "$ho/.sd1" > "$o"; b=$?
  cmp -s "$g" "$o" && [ $a -eq $b ] || fail "kore sed -E '$sc' vs GNU"
done
# -e stacks in order, and clusters (-ne is how this tree writes it)
sed -n -e 1p -e 3p "$ho/.sd1" > "$g"; korerun sed -n -e 1p -e 3p "$ho/.sd1" > "$o"
same "sed -e stacking"
sed -ne 2p "$ho/.sd1" > "$g"; korerun sed -ne 2p "$ho/.sd1" > "$o"; same "sed -ne clustered"
sed -e 's/a/1/' -e 's/b/2/' "$ho/.sd1" > "$g"
korerun sed -e 's/a/1/' -e 's/b/2/' "$ho/.sd1" > "$o"; same "sed -e twice"
# -i IS A DIFFERENT STREAM MODEL, not just a different sink: each file is its own
# stream, so line numbers restart and $ is per-file. TWO files is the only test that
# can tell that from the joined lane -- with one file the two models agree
for t in 's/b/X/g' '1d' '$d' 's/[[:digit:]]/#/g'; do
  cp "$ho/.sd1" "$ho/.sdg"; cp "$ho/.sd1" "$ho/.sdo"
  sed -i "$t" "$ho/.sdg"; korerun sed -i "$t" "$ho/.sdo"
  cmp -s "$ho/.sdg" "$ho/.sdo" || fail "kore sed -i '$t' vs GNU"
done
cp "$ho/.sd1" "$ho/.sdga"; cp "$ho/.sd1" "$ho/.sdgb"
cp "$ho/.sd1" "$ho/.sdoa"; cp "$ho/.sd1" "$ho/.sdob"
sed -i '1d;$d' "$ho/.sdga" "$ho/.sdgb"
korerun sed -i '1d;$d' "$ho/.sdoa" "$ho/.sdob"
cmp -s "$ho/.sdga" "$ho/.sdoa" && cmp -s "$ho/.sdgb" "$ho/.sdob" \
  || fail "kore sed -i over TWO files (the per-file model) vs GNU"
for sc in '2,4p' '/z/p' 's/b/X/p' '/x/,/q/p'; do
  sed -n "$sc" "$ho/.sd1" > "$g"
  korerun sed -n "$sc" "$ho/.sd1" > "$o"
  cmp -s "$g" "$o" || fail "kore sed -n '$sc' vs GNU"
done
pipe "sed stdin" 'ab
'                sed 's/a/1/'
printf 'a\n' | sed 's/a' > /dev/null 2>&1; a=$?
printf 'a\n' | korerun sed 's/a' > /dev/null 2>&1; b=$?
[ $a -eq 1 ] && [ $b -eq 1 ] || fail "kore sed bad-script exit (gnu $a ours $b)"
sed p "$ho/.sd-nope" "$ho/.sd1" > "$g" 2>&1; a=$?
korerun sed p "$ho/.sd-nope" "$ho/.sd1" > "$o" 2>&1; b=$?
cmp -s "$g" "$o" && [ $a -eq 2 ] && [ $b -eq 2 ] || fail "kore sed missing file vs GNU"
# A MISSING FINAL NEWLINE IS DATA. GNU drops it after the LAST WRITE and not after
# every one, so `-n 'p;p'` keeps the inner newline and loses only the outer -- which is
# why the line rides a jug rather than a per-write flag. The whole line lane answers to
# this: sed, rev and the two clips (head that CUT before the last line does not).
printf 'a\nx' > "$ho/.nonl"
for sc in '' 'p' 's/a/A/' 's/x/Y/'; do
  sed "$sc" "$ho/.nonl" > "$g"; korerun sed "$sc" "$ho/.nonl" > "$o"
  same "sed '$sc' on a source with no final newline"
done
for sc in 'p' 'p;p'; do
  sed -n "$sc" "$ho/.nonl" > "$g"; korerun sed -n "$sc" "$ho/.nonl" > "$o"
  same "sed -n '$sc' on a source with no final newline"
done
for t in "rev" "head -n 5" "tail -n 5" "head -n 1" "head -1" "tail -1" "head -2"; do
  # shellcheck disable=SC2086
  $t "$ho/.nonl" > "$g"; korerun $t "$ho/.nonl" > "$o"
  same "$t on a source with no final newline"
done
rm -f "$ho/.nonl"
# -f FILE in its place among -e (either order, and in a cluster), --file, -r, -s's
# per-file streams, -i's suffix glued or long (and -in, which is a suffix of n), -f of no
# file answering GNU's 4
S=$ho/.sedf; rm -rf "$S"; mkdir "$S"; printf 's/a/X/\n2d\n' > "$S/sc"; printf 'abc\nbbb\nabab\n' > "$S/in"; printf 'a1\na2\n' > "$S/in2"
for c in "-f $S/sc" "-n -f $S/sc -e p" "-e s/b/Q/ -f $S/sc" "-f $S/sc -e s/b/Q/" "-nf $S/sc" "--file=$S/sc" "-r s/(a)+/<\1>/" "-s 1d $S/in2" "-s \$d $S/in2"; do
  # shellcheck disable=SC2086
  sed $c "$S/in" > "$g" 2>&1; korerun sed $c "$S/in" > "$o" 2>&1; same "sed $c"
done
for i in -i.bak --in-place=.orig -i -ni; do
  rm -f "$S"/w*; cp "$S/in" "$S/w"; sed $i 's/a/Z/p' "$S/w"; cp "$S/w" "$S/gw"; (cd "$S" && ls w*) > "$g"
  rm -f "$S"/w*; cp "$S/in" "$S/w"; korerun sed $i 's/a/Z/p' "$S/w"; (cd "$S" && ls w*) > "$o"
  same "sed $i leaves"; cmp -s "$S/w" "$S/gw" || fail "kore sed $i vs GNU"
done
korerun sed -f "$S/nosuch" "$S/in" > /dev/null 2>&1; r=$?; [ $r -eq 4 ] || fail "kore sed -f of no file (rc $r)"
rm -rf "$S"
echo "kore: sed (s///gp + y + {} + d/p/q + addresses + -E/-e/-i, the per-file model, GNU-identical, exits 1/2) ok"
echo "kore: the missing final newline is data (sed/rev/head/tail, and head -N) ok"
