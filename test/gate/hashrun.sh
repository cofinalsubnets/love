#!/bin/sh
# test/gate/hashrun.sh -- a value's hash is the value's, not the process's: two runs dig the
# same numbers out of a float, a bignum, a complex, both kinds of tray, a string and a list.
# a box's first word is its kind's op, an address the load moves (the binary is PIE), so a
# hash that read it moved with every run. without address randomization this passes vacuously
# usage: sh test/gate/hashrun.sh LOVE
set -u
love=${1:-out/love}
e='[(dig 1.5) (dig (2 ** 100)) (dig (1 ~ 2)) (dig (iota 3)) (dig (top-tray [3] 7)) (dig "ab") (dig [1 2])]'
a=$("$love" -e "$e" 2>&1)
b=$("$love" -e "$e" 2>&1)
[ "$a" = "$b" ] || { echo "FAIL hashrun: one run '$a', the next '$b'"; exit 1; }
echo "hashrun: a value hashes the same in every process"
