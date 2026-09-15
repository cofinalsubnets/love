#!/bin/sh
# lscmp.sh -- kore's ls against GNU's, byte for byte, over a flag matrix.
# called by test/gate/kore.sh; here as one file because the matrix is the test.
#
# TZ=UTC on BOTH sides. `ls -l`'s clock column is local time and this tree keeps
# no timezone database, so ours is UTC always; the comparison is only meaningful
# where GNU's is UTC too. (LC_ALL=C for the same reason on the name order.)
#
# the tree is BUILT here, never a real directory: a stray file, an ACL or an
# SELinux label would move GNU's mode column by one character and read as a bug.
#
# the grid rows set COLUMNS on both sides, which is the only way to compare a
# layout at all: neither ls columns into a pipe unless asked, and $COLUMNS is
# what both read when there is no terminal to ask. TABSIZE is unset for the same
# reason -- the pad elides onto tab stops and ours are 8, GNU's default.
set -u
m=${1:-./out/love}
LC_ALL=C TZ=UTC; export LC_ALL TZ
unset COLUMNS TABSIZE 2>/dev/null || :
w=${TMPDIR:-/tmp}/lscmp.$$; mkdir -p "$w"; trap 'rm -rf "$w"' EXIT
fail=0; ran=0

t=$w/t
mkdir -p "$t/sub" "$t/empty" "$t/.dotdir"
printf 'hello\n'          > "$t/a"
printf 'xx\n'             > "$t/bbb"
printf ''                 > "$t/zero"
head -c 3000 /dev/zero    > "$t/big"
printf 'x\n'              > "$t/.hidden"
printf 'y\n'              > "$t/sub/inner"
ln -s a                     "$t/link"
ln -s nowhere               "$t/dangling"
chmod 0751 "$t/bbb"
chmod 0700 "$t/sub"
# a mtime well outside the six-month window, which is the OTHER date format
touch -d '2019-03-04 05:06:07' "$t/old" 2>/dev/null || touch -t 201903040506 "$t/old"

try() {   # try FLAGS.. -- the tree is the last operand unless one is given
  ran=$((ran + 1))
  "$m" ls "$@" > "$w/mine" 2>"$w/mine.err"; rc=$?
  ls "$@" > "$w/theirs" 2>/dev/null; grc=$?
  if [ "$rc" != "$grc" ]; then
    echo "FAIL ls $*: exit $rc, GNU $grc"; sed -n 1,2p "$w/mine.err" | sed 's/^/    /'
    fail=$((fail + 1)); return
  fi
  if ! cmp -s "$w/mine" "$w/theirs"; then
    echo "FAIL ls $*:"; diff "$w/theirs" "$w/mine" | sed -n 1,8p | sed 's/^/    /'
    fail=$((fail + 1))
  fi
}

tryw() {  # tryw COLS FLAGS.. -- the same row with $COLUMNS pinned on both sides
  cols=$1; shift
  COLUMNS=$cols; export COLUMNS
  try "$@"
  unset COLUMNS
}

for f in "" -a -A -l -la -al -lA -1 -r -lr -t -lt -ltr -d -ld; do
  # shellcheck disable=SC2086
  try $f "$t"
done
# a plain file operand, and a link operand (which ls does NOT follow)
try -l "$t/a"
try -l "$t/link"
try -ld "$t/link"
try "$t/a"
# several operands: files first, then a `dir:` header block per directory
try "$t/a" "$t/bbb"
try -l "$t/a" "$t/bbb"
try "$t/sub" "$t/empty"
try -l "$t/sub" "$t/empty"
try "$t/a" "$t/sub"
try -l "$t/a" "$t/sub"
try -l "$t/empty"
# the old file, whose date column is the year form and not the clock
try -l "$t/old"
# what is not there
try "$w/nope"
try -l "$t/a" "$w/nope"

# -C down and -x across, over a width sweep: 1 and 2 are narrower than a column
# may be, 24 and 80 straddle the longest name, and the odd ones catch a pad that
# rounds onto a tab stop it did not earn.
for c in 1 2 3 5 8 9 16 17 23 24 25 31 32 33 40 60 79 80 81 120 200; do
  tryw "$c" -C "$t"
  tryw "$c" -x "$t"
  tryw "$c" -aC "$t"
  tryw "$c" -Cr "$t"
  tryw "$c" -Ct "$t"
done
# -1 wins over a grid, and the command-line block grids the same way a directory does
tryw 40 -1 "$t"
tryw 40 -C "$t/a" "$t/bbb" "$t/zero"
tryw 40 -x "$t/a" "$t/bbb" "$t/zero"
tryw 40 -C "$t/a" "$t/sub"
tryw 12 -C "$t/empty"

echo "lscmp: $ran rows, $fail failed"
[ "$fail" = 0 ]
