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
echo "kore: field tools (cut/tr/nl/rev GNU-identical) ok"
