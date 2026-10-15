#!/bin/sh
# test/kore/expr.sh -- expr: the expressions and the 0/1/2 exit
. "$(dirname "$0")/common.sh"

# EXPR SPEAKS IN THE EXIT CODE as much as on stdout (0 the answer is neither ""
# nor "0", 1 it is, 2 the expression will not do), so `both` comparing both is the
# whole check. the arithmetic ones are here because C's TRUNCATING division and
# love's FLOORING // disagree on every negative pair.
for e in '1 + 2' '10 / 3' '10 % 3' '3 * 4' '1 + 2 * 3' '( 1 + 2 ) * 3' '5 - 8' \
         '-7 / 2' '-7 % 2' '7 / -2' 'abc = abc' 'abc = abd' '2 < 10' '2 < 10a' \
         'abc < abd' '3 >= 3' '3 != 4' '1 | 2' '0 | 3' '0 & 2' '1 & 2' \
         'abc : a.c' 'abcd : a.c' 'abc : x' 'length abcde' 'substr abcdef 2 3' \
         'substr abcdef 0 3' 'substr abcdef 5 99' 'index abcdef cd' 'index abcdef z' \
         '+ length' '0' 'foo' '1 / 0' 'a + 1' '1 +'; do
  # shellcheck disable=SC2086
  set -- $e
  bothrc "expr '$e'" expr "$@"
done
# the two the loop cannot carry: a group in the pattern, and the empty operand
expr abc : 'a\(.\)c' > "$g"; korerun expr abc : 'a\(.\)c' > "$o"; same "expr group"
bothrc "expr empty group" expr abc : 'a\(x\)c'
expr '' '|' foo > "$g"; korerun expr '' '|' foo > "$o"; same "expr empty | foo"
echo "kore: expr (36 expressions + the groups, stdout AND the 0/1/2 exit, GNU-identical) ok"
