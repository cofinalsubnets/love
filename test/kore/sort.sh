#!/bin/sh
# test/kore/sort.sh -- kore's sort against GNU's, byte for byte, over a flag matrix.
# one file because the matrix is the test and a matrix reads badly inlined.
#
# LC_ALL=C on BOTH sides. GNU's default collation ignores punctuation and case,
# ours is byte order, and without this every row disagrees for a reason that has
# nothing to do with the code.
set -u
m=${2:-./out/love}                   # (OUTDIR LOVE), as every subject here takes
LC_ALL=C; export LC_ALL
w=${TMPDIR:-/tmp}/kore-sort.$$; mkdir -p "$w"; trap 'rm -rf "$w"' EXIT
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

# -h by the unit first, -V by runs, both as keys too; -c -C -cu, their status and -c's
# sentence; long names; -m over a sorted input; -z; -o onto its own input
printf '10K\n2M\n1500K\n3\n1.5G\n512\n0\n1k\n-2K\n' > "$w/h"; printf 'v1.10\nv1.9\nv1.2.3\nv1.2\nfoo-2.0\nfoo-10.1\n1.0\n1.0.1\n' > "$w/v"
printf 'b\na\nc\na\n' > "$w/u"; printf 'a\nb\nc\n' > "$w/s"; printf 'x 3\ny 10K\nz 2M\n' > "$w/kh"
try h -h; try h -hr; try v -V; try v -Vr; try kh -k2h; try kh -k2,2h -r; try s -c; try u -C; try u --reverse; try s -m; try u -n --unique
for c in -c -cu; do
  ran=$((ran + 1)); "$m" sort $c < "$w/u" > "$w/mine" 2>&1; rc=$?; sort $c < "$w/u" > "$w/theirs" 2>&1; grc=$?
  [ "$rc" = "$grc" ] && cmp -s "$w/mine" "$w/theirs" || { echo "FAIL sort $c: exit $rc, GNU $grc"; fail=$((fail + 1)); }
done
ran=$((ran + 1)); printf 'b\0a\0c\0' | "$m" sort -z | od -c > "$w/mine"; printf 'b\0a\0c\0' | sort -z | od -c > "$w/theirs"
cmp -s "$w/mine" "$w/theirs" || { echo "FAIL sort -z"; fail=$((fail + 1)); }
ran=$((ran + 1)); cp "$w/u" "$w/o"; "$m" sort -o "$w/o" "$w/o"; sort "$w/u" | cmp -s - "$w/o" || { echo "FAIL sort -o onto its input"; fail=$((fail + 1)); }
echo "kore sort: $ran rows, $fail failed"
[ "$fail" = 0 ]
