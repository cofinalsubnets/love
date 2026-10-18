#!/bin/sh
# test/kore/ls.sh -- kore's ls against gnu's, byte for byte, over a flag matrix.
# TZ=UTC and LC_ALL=C on both sides (ours keeps no zones). the tree is built here, so no acl
# or selinux mark moves gnu's mode column. grid rows set COLUMNS on both sides (no terminal
# to ask); TABSIZE unset, ours and gnu's default both 8
set -u
m=${2:-./out/love}                   # (OUTDIR LOVE), as every subject here takes
LC_ALL=C TZ=UTC; export LC_ALL TZ
unset COLUMNS TABSIZE 2>/dev/null || :
w=${TMPDIR:-/tmp}/kore-ls.$$; mkdir -p "$w"; trap 'rm -rf "$w"' EXIT
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
# an mtime outside the six-month window: the other date format
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
# a plain file operand, and a link operand, not followed
try -l "$t/a"
try -l "$t/link"
try -ld "$t/link"
try "$t/a"
# several operands: files first, then a `dir:` block per directory
try "$t/a" "$t/bbb"
try -l "$t/a" "$t/bbb"
try "$t/sub" "$t/empty"
try -l "$t/sub" "$t/empty"
try "$t/a" "$t/sub"
try -l "$t/a" "$t/sub"
try -l "$t/empty"
# the old file: its date column takes the year form
try -l "$t/old"
# what is not there
try "$w/nope"
try -l "$t/a" "$w/nope"

# -C down and -x across over a width sweep: below a column, straddling the longest name, and
# odd widths that catch a pad rounding onto an unearned tab stop
for c in 1 2 3 5 8 9 16 17 23 24 25 31 32 33 40 60 79 80 81 120 200; do
  tryw "$c" -C "$t"
  tryw "$c" -x "$t"
  tryw "$c" -aC "$t"
  tryw "$c" -Cr "$t"
  tryw "$c" -Ct "$t"
done
# -1 beats a grid; the command-line block grids as a directory does
tryw 40 -1 "$t"
tryw 40 -C "$t/a" "$t/bbb" "$t/zero"
tryw 40 -x "$t/a" "$t/bbb" "$t/zero"
tryw 40 -C "$t/a" "$t/sub"
tryw 12 -C "$t/empty"

# vdir is ls -l by coreutils' other name
if command -v vdir >/dev/null 2>&1; then
  for f in "" -a -r; do
    ran=$((ran + 1))
    # shellcheck disable=SC2086
    "$m" vdir $f "$t" > "$w/mine" 2>&1; vdir $f "$t" > "$w/theirs" 2>&1
    cmp -s "$w/mine" "$w/theirs" || { echo "FAIL vdir $f"; fail=$((fail + 1)); }
  done
fi

# -h -S -s, -F -p, -i, -n -g -o, -u -c, -R (a link to a directory not followed), -L, colour;
# over a tree with a fifo, an executable and a link to a directory
u=$w/u; mkdir -p "$u/d/sub/deep"; head -c 3000 /dev/zero > "$u/d/big"; : > "$u/d/empty"; printf 'ab' > "$u/d/two"
chmod 755 "$u/d/big"; ln -s big "$u/d/lnk"; ln -s sub "$u/d/lsub"; mkfifo "$u/d/fifo"; echo z > "$u/d/sub/z"; echo q > "$u/d/sub/deep/q"
touch -d '2024-01-02 10:00' "$u/d/big"; touch -d '2024-01-03 10:00' "$u/d/two"; touch -d '2024-01-01 10:00' "$u/d/empty"
for f in -1S -1Sr -1F -1p -1i -1s -1si -lh -lS -ln -lg -lo -lgo -lF -lp -li -ls -lsh -1R -lR -1L -lL -R -1tu -1tc "-1 --color=never"; do
  # shellcheck disable=SC2086
  try $f "$u/d"
done
try -lh "$u/d/big" "$u/d/two"
[ "$("$m" ls --color=always -1 "$u/d" | head -1 | od -c | head -1 | tr -s ' ')" = "$(printf '0000000 033 [ 3 2 m b i g 033 [ 0 m \\n')" ] || { echo "FAIL ls --color=always"; fail=$((fail + 1)); }
echo "kore ls: $ran rows, $fail failed"
[ "$fail" = 0 ]
