#!/bin/sh
# test/kore/column.sh -- fold, expand, unexpand -- the tab stops
. "$(dirname "$0")/common.sh"

# all three count COLUMNS: the tab cases are the point, since a byte count answers
# differently for every one of them
pipe "fold"        'abcdefghij
kl
'                  fold -w 4
pipe "fold -s"     'aaa bbb ccc ddd
'                  fold -s -w 6
pipe "fold tab"    'a	bcdefgh
'                  fold -w 8
pipe "fold -b"     'ab	cd
'                  fold -b -w 4
pipe "fold -N"     'abcdefghij
'                  fold -4
pipe "fold 80"     'the eighty-column default, unspoken
'                  fold
pipe "expand"      'a	b
	x
ab	c
'                  expand
pipe "expand -t 4" 'a	b
'                  expand -t 4
pipe "expand -i"   '	a	b
'                  expand -i
# a tab lands only where it saves at least TWO columns, so a lone space sitting on
# a stop stays a space -- the one rule the obvious implementation gets wrong
pipe "unexpand"    '   	ab   cd
'                  unexpand
pipe "unexpand -a" '        a       b
'                  unexpand -a
pipe "unexpand 1sp" 'abcdefg x
'                   unexpand -a
pipe "unexpand 2sp" 'abcdef  x
'                   unexpand -a
pipe "unexpand tail" 'a        
'                    unexpand -a
pipe "unexpand -t 4" '    a   b
'                    unexpand -t 4
# column against util-linux's: filling down and across, a table on whitespace and on -s,
# -o, blank lines skipped, wide characters two columns, a name too wide for the screen.
# not -x narrower than one column, where util-linux runs every name onto one line
if command -v column > /dev/null 2>&1; then
names='a
bb
ccc

dddd
eeeee
f
gg
hhh
iiii
jjjjjjjjjj
'
pipe "column"          "$names"   column -c 40
pipe "column -x"       "$names"   column -x -c 40
pipe "column 80"       "$names"   column -c 80
pipe "column narrow"   "$names"   column -c 9
pipe "column wide"     '日本語
あ
kana かな
漢字漢字漢字
x
'                                  column -c 30
pipe "column -t"       'name size owner
love 13020768 gwen
  kore 1	 root

x
'                                  column -t
pipe "column -t -s"    'a:b:c
d::f
  g  h
:lead
trail:
'                                  column -t -s :
pipe "column -t -o"    'a b  c
dd e f
'                                  column -t -o '|'
fi
echo "kore: column tools (fold/expand/unexpand GNU-identical, column util-linux's, the tab stops) ok"
