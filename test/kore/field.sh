#!/bin/sh
# test/kore/field.sh -- cut, tr, nl, rev
. "$(dirname "$0")/common.sh"

printf 'a:b:c\nnodelim\nx:y\n' > "$ho/.fu1"
both "cut -f"    cut -d: -f1,3    "$ho/.fu1"
both "cut -s"    cut -d: -f1,3 -s "$ho/.fu1"
both "cut -f2-"  cut -d: -f2-     "$ho/.fu1"
pipe "cut -c"    'hello
hi
'                cut -c2-4
pipe "tr"        'hi there
'                tr a-z A-Z
pipe "tr class"  'Mixed Case 123
'                tr '[:lower:]' '[:upper:]'
pipe "tr pad"    'abcd
'                tr abcd xy
pipe "tr -d"     'hello world
'                tr -d aeiou
pipe "tr -s"     'aa  bb   cc
'                tr -s ' '
# -c reads SET1 as its COMPLEMENT. an unknown dash word used to be read as a set, so
# `tr -c a-z .` translated the literal two-charm set "-c" and answered in silence.
pipe "tr -c"     'hi there 42
'                tr -c 'a-z' .
pipe "tr -cd"    'hi there 42
'                tr -cd 'a-z\n'
pipe "tr -cs"    'one two  three
'                tr -cs '[:alnum:]' '\n'
# -ds deletes SET1 and then squeezes SET2 in what is left; -d took no -s and answered
# the delete alone. a SET2 beside a bare -d, or none beside -ds, is GNU's refusal (1)
pipe "tr -ds"    'aabbccaab
'                tr -ds a b
pipe "tr -cds"   'aabbccaab
'                tr -cds 'a\n' a
for c in "-d a b" "-ds a"; do
  # shellcheck disable=SC2086
  echo ab | korerun tr $c > /dev/null 2>&1; r=$?
  [ $r -eq 1 ] || fail "kore tr $c must refuse with 1 (got $r)"
done
# the classes past the three that were spelled: a [:name:] uset does not know stays
# LITERAL, so `tr -d [:space:]` quietly deleted a, c, e, p, s and the colon instead
for c in space alpha alnum punct blank xdigit cntrl print graph; do
  pipe "tr -d [:$c:]" 'a b,c	1F!
'                     tr -d "[:$c:]"
done
korerun tr -Z a b < /dev/null 2>&1 | grep -q 'unknown option' \
  || fail "kore tr: an unknown flag must be refused, not read as a set"
pipe "nl"        'a

b
'                nl
pipe "rev"       'abc
de
'                rev
[ "$(printf '日本語é\nab\n' | korerun rev)" = "$(printf 'é語本日\nba')" ] \
  || fail "kore rev: a character reverses whole, never its bytes"
[ "$(printf 'a日本b\n' | korerun cut -c 2-3)" = "日本" ] \
  || fail "kore cut -c: a list counts characters, never bytes"
[ "$(printf 'a日本b\n' | korerun cut -b 1,5)" = "$(printf 'a\xe6')" ] \
  || fail "kore cut -b: a list counts bytes"
[ "$(printf 'aa日日本 é\xff\n' | korerun tr -s 日é 日e)" = "$(printf 'aa日本 e\xff')" ] \
  || fail "kore tr: sets are characters, and a stray byte passes as itself"
[ "$(printf 'a日\xffb\n' | korerun tr -cd a-z)" = "ab" ] \
  || fail "kore tr -c: the complement takes a whole character, and a stray byte"
# cut's --complement, --output-delimiter (between fields, and between -c/-b's runs), -z,
# -n, --only-delimited and the long names
C=$ho/.cutf; printf 'a:b:c:d\ne:f:g:h\nnodelim\n' > "$C"; printf 'a:b\0c:d\0' > "$C.z"
for c in "-d: -f2 --complement" "-d: -f1,3 --output-delimiter=-" "-d: -f2- --complement --output-delimiter=::" "-c2-3 --complement" \
         "-c1,3-4 --output-delimiter=." "-b1-2,4 --output-delimiter=," "--delimiter=: --fields=2" "--characters=1-2" "--bytes=3" \
         "-d: -f2 --only-delimited" "-n -c1"; do
  # shellcheck disable=SC2086
  cut $c "$C" > "$g"; korerun cut $c "$C" > "$o"; same "cut $c"
done
cut -z -d: -f2 "$C.z" > "$g"; korerun cut -z -d: -f2 "$C.z" > "$o"; same "cut -z"
rm -f "$C" "$C.z"
echo "kore: field tools (cut/tr/nl/rev GNU-identical) ok"
