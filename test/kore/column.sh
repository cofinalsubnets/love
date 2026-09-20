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
echo "kore: column tools (fold/expand/unexpand GNU-identical, the tab stops) ok"
