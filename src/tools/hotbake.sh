#!/bin/sh
# src/tools/hotbake.sh -- the profiles of the hot-first bake: a plain `love bake` lays the objects
# a short run touches first, by the hot.prof the binary carries, so a lazy wake decodes a few
# chunks, not one in two, and glazes by the hot.calls it carries.
#   sh src/tools/hotbake.sh -p RAW PROF CAT  profile RAW, writing the word ranges to PROF
#   sh src/tools/hotbake.sh -c RAW CALLS CAT profile RAW's calls, writing "index count" to CALLS for those kept
# the call profile: a leaf (a body that neither loops nor drives), or one the glaze's cost rule
# declines, keeps its native only when the workloads below called it 1024 times or more; each is
# known by its place in the bake. its bake gives each a counting cell, and each count is the last
# power of two it passed.
# the word ranges are of the image the call profile glazes, so -p bakes by the tree's hot.calls.
# the profile is kept in the tree so the image is a function of the tree alone, not of the
# page size or libc of the machine that bakes it. a change to anything baked moves the
# heap under it: `make hotprof` writes it again, and test_bakerep fails while it is stale.
# the RAW profiled is the Makefile's prof_raw, a link carrying the tree less hot.prof and
# hot.calls: a profile never measures itself, so one pass is its fixed point.
# `bake --profile layout` bakes RAW with page-sized stream chunks, and -p runs the fixed workloads below on
# that, each recording the chunks it woke (LOVE_TOUCH_OUT). both bakes are of the one crew,
# so their heaps agree word for word. the workloads read only files made here and the tree's
# own C, under an empty environment, and the binary runs as `love` off PATH: a verb is found by the name it
# is run as, so any other name touches other slots.
set -u
here=$(cd "$(dirname "$0")" && pwd) || exit 1
if [ "${1:-}" = -c ]; then
  raw=$2 calls=$3 cat=$4
  d=$(mktemp -d) || exit 1
  trap 'rm -rf "$d"' EXIT
  # the counting image: each leaf a counting cell, each count appended to LOVE_BAKE_COUNT
  env LOVE_NO_IMAGE=1 "$raw" bake --profile calls -o "$d/love" -l "$cat" || exit 1
  mkdir "$d/w" || exit 1
  ln -s "$here/../.." "$d/w/t" || exit 1
  i=0
  while [ $i -lt 2000 ]; do
    echo "row$((i % 37)) $((i * i % 1009)) of the fixture, $((i % 11)) left: abc$((i % 5))"
    i=$((i + 1))
  done > "$d/w/in"
  # ..and a preprocessed TU, what cpp sees of a header-heavy one: line markers, joined strings
  i=0
  while [ $i -lt 1200 ]; do
    printf '# 1 "include/h%d.h" 1 3\nstatic char const t%d[] __attribute__((unused)) = "s%d\\tof" " the fixture\\n" "%%d \\x41\\\\";\n# %d "t.c" 2\n\n' \
      $i $i $i $((i * 4 + 3))
    i=$((i + 1))
  done > "$d/w/fx.i"
  # the tree's C is read by one relative path, so the counts never carry where the tree is
  run() { (cd "$d/w" && env -i PATH="$d" LOVE_BAKE_COUNT="$d/count" love "$@" > /dev/null 2>&1 < /dev/null); }
  for c in cb compress/zstd; do run mooncc -D tco=1 -It -It/src/love -It/src/inle -c "t/src/love/$c.c" -o o; done
  run mooncc -c fx.i -o o
  run sed -n 's/^\(row[0-9]*\) \([0-9]*\)/\2 \1/p' in
  run sed -E '/left: abc[13]/{s/[0-9]+/N/g;y/abc/ABC/};3,9d' in
  run awk '{ n[$1] += $2; s += length($0) } END { for (k in n) t += n[k]; print t, s }' in
  run awk '$2 ~ /^[0-9]+7$/ { printf "%s %d\n", toupper($1), $2 * 2 }' in
  [ -s "$d/count" ] || { echo "hotbake: $raw counted no calls" >&2; exit 1; }
  (cd "$d" && env -i PATH="$d" love awk '$2 > m[$1] { m[$1] = $2 } END { for (i in m) if (m[i] >= 1024) print i, m[i] }' count \
     | env -i PATH="$d" love sort -n) > "$calls"
elif [ "${1:-}" = -p ]; then
  raw=$2 prof=$3 cat=$4
  d=$(mktemp -d) || exit 1
  trap 'rm -rf "$d"' EXIT
  env LOVE_NO_IMAGE=1 "$raw" bake --profile layout "$here/hot.calls" -o "$d/love" -l "$cat" || exit 1
  mkdir "$d/w" || exit 1
  i=0
  while [ $i -lt 40 ]; do
    echo "line $((i * 7 % 40)) of the lvm fixture: $((i * i)) words, $((40 - i)) left"
    i=$((i + 1))
  done > "$d/w/in"
  run() { (cd "$d/w" && env -i PATH="$d" LOVE_TOUCH_OUT="$d/touch" love "$@" > /dev/null 2>&1 < /dev/null); }
  run -e 1
  run echo hi
  run ls .
  run cat in
  run sort in
  run grep -c lvm in
  run wc in
  run head -3 in
  run lush -c true
  # a build whose wake is eager (not moonlibc's: HCC, the gcc lanes) records no touch
  [ -s "$d/touch" ] || { echo "hotbake: $raw woke eagerly, no profile" >&2; exit 1; }
  cp "$d/touch" "$prof"
else
  echo "usage: hotbake.sh -c RAW CALLS CAT | -p RAW PROF CAT" >&2
  exit 2
fi
