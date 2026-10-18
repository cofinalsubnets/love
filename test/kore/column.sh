#!/bin/sh
# test/kore/column.sh -- fold, expand, unexpand -- the tab stops
. "$(dirname "$0")/common.sh"

# all three count columns, so the tab cases are the point
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
# a tab lands only where it saves two columns or more: a lone space on a stop stays a space
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
# column against util-linux: down and across, tables on whitespace and -s, -o, blank lines
# skipped, wide characters, a too-wide name. not -x below one column, where util-linux joins all
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
