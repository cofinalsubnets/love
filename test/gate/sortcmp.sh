#!/bin/sh
# sortcmp.sh -- kore's sort against GNU's, byte for byte, over a flag matrix.
# not a gate of its own: test/gate/kore.sh calls it, and it is here as one file
# because the matrix is the test and a matrix reads badly inlined.
#
# ⚠ LC_ALL=C on BOTH sides. GNU's default collation ignores punctuation and case,
# ours is byte order, and without this every row disagrees for a reason that has
# nothing to do with the code.
set -u
m=${1:-./out/love}
LC_ALL=C; export LC_ALL
w=${TMPDIR:-/tmp}/sortcmp.$$; mkdir -p "$w"; trap 'rm -rf "$w"' EXIT
fail=0; ran=0

# the corpus: three shapes, because one input cannot exercise a numeric key, a
# field key and the last-resort compare at once.
cat > "$w/a" <<'EOF'
10 pear   3.5
2 apple   -1
-3 fig    0
2 apple   10
100 quince 2.25
0002 apple  -1.0
+5 date    7
apple 9 x
 7 grape   1e3
-0 zero    0
1000000000000000000001 big 1
1000000000000000000000 big 2
EOF
printf 'b\nA\na\nB\nb\n' > "$w/b"
printf 'x:9:c\nx:10:a\ny:2:b\nx:9:a\n\n:1:z\n' > "$w/c"

try() {   # try FILE FLAGS..
  f=$1; shift
  ran=$((ran + 1))
  "$m" sort "$@" < "$w/$f" > "$w/mine" 2>"$w/mine.err"; rc=$?
  sort "$@" < "$w/$f" > "$w/theirs" 2>/dev/null; grc=$?
  if [ "$rc" != "$grc" ]; then
    echo "FAIL sort $* ($f): exit $rc, GNU $grc"; sed -n 1,2p "$w/mine.err"; fail=$((fail + 1)); return
  fi
  if ! cmp -s "$w/mine" "$w/theirs"; then
    echo "FAIL sort $* ($f):"; diff "$w/theirs" "$w/mine" | sed -n 1,6p | sed 's/^/    /'
    fail=$((fail + 1))
  fi
}

for f in a b c; do
  try "$f"
  try "$f" -r
  try "$f" -u
  try "$f" -n
  try "$f" -nr
  try "$f" -ru
  try "$f" -nu
  try "$f" -b
  try "$f" -f
  try "$f" -fu
  try "$f" -s
done
# field keys, default separator
for k in 1 2 3 1,1 2,2 1,2 2,3; do
  try a -k "$k"
  try a -k "$k" -n
  try a -k "$k" -r
  try a -k "$k" -u
done
# the per-key letters, which must beat the globals rather than add to them
try a -k 2,2n
try a -k 1,1n -k 2,2
try a -k 2,2 -k 1,1n
try a -k 1,1nr
try a -k 2,2f
try a -k 1,1b
try a -k 2,2n -r
try a -k 3,3n
# -t, glued and split
try c -t: -k2
try c -t: -k2n
try c -t : -k 2,2n
try c -t: -k1,1 -k2,2n
try c -t: -k3
try c -t: -u -k1,1

echo "sortcmp: $ran rows, $fail failed"
[ "$fail" = 0 ]
