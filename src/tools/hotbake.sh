#!/bin/sh
# src/tools/hotbake.sh -- the hot-first bake: the objects a short run touches laid first, so a
# lazy wake decodes a few chunks, not one in two.
#   sh src/tools/hotbake.sh RAW OUT CAT      bake RAW to OUT, laid by the tree's src/tools/hot.prof
#                                            and glazed by its src/tools/hot.calls
#   sh src/tools/hotbake.sh -p RAW PROF CAT  profile RAW, writing the word ranges to PROF
#   sh src/tools/hotbake.sh -c RAW CALLS CAT profile RAW's calls, writing "index count" to CALLS
#   sh src/tools/hotbake.sh -k               the bake indices hot.calls keeps
# the call profile: a leaf (a body that neither loops nor drives) keeps its native only when
# the workloads below called it 1024 times or more; a leaf is known by its place in the bake.
# its bake gives each leaf a counting cell, and each count is the last power of two it passed.
# the word ranges are of the image the call profile glazes, so -p reads the tree's hot.calls.
# the profile is kept in the tree so the image is a function of the tree alone, not of the
# page size or libc of the machine that bakes it. a change to anything baked moves the
# heap under it: `make hotprof` writes it again, and test_bakerep fails while it is stale.
# the RAW profiled is the Makefile's prof_raw, a link carrying the tree less hot.prof and
# hot.calls: a profile never measures itself, so one pass is its fixed point.
# profiling bakes RAW with page-sized stream chunks and runs the fixed workloads below on
# that, each recording the chunks it woke (LOVE_TOUCH_OUT). both bakes are of the one crew,
# so their heaps agree word for word. the workloads read only files made here and the tree's
# own C, under an empty environment, and the binary runs as `love` off PATH: a verb is found by the name it
# is run as, so any other name touches other slots.
set -u
here=$(cd "$(dirname "$0")" && pwd) || exit 1
keep() { k=; while read -r i n; do [ "$n" -lt 1024 ] || k="$k $i"; done < "$here/hot.calls"; echo "${k# }"; }
# the bake is the script's last word: a bare `exit` in a recipe's script ends the whole
# recipe line when cook runs it in its own image
if [ "${1:-}" = -k ]; then
  keep
elif [ "${1:-}" = -c ]; then
  raw=$2 calls=$3 cat=$4
  d=$(mktemp -d) || exit 1
  trap 'rm -rf "$d"' EXIT
  env LOVE_NO_IMAGE=1 LOVE_BAKE_COUNT="$d/bake" "$raw" bake -o "$d/love" -l "$cat" || exit 1
  mkdir "$d/w" || exit 1
  ln -s "$here/../.." "$d/w/t" || exit 1
  i=0
  while [ $i -lt 2000 ]; do
    echo "row$((i % 37)) $((i * i % 1009)) of the fixture, $((i % 11)) left: abc$((i % 5))"
    i=$((i + 1))
  done > "$d/w/in"
  # the tree's C is read by one relative path, so the counts never carry where the tree is
  run() { (cd "$d/w" && env -i PATH="$d" LOVE_BAKE_COUNT="$d/count" love "$@" > /dev/null 2>&1 < /dev/null); }
  for c in cb compress/zstd; do run mooncc -D tco=1 -It -It/src/love -It/src/inle -c "t/src/love/$c.c" -o o; done
  run sed -n 's/^\(row[0-9]*\) \([0-9]*\)/\2 \1/p' in
  run sed -E '/left: abc[13]/{s/[0-9]+/N/g;y/abc/ABC/};3,9d' in
  run awk '{ n[$1] += $2; s += length($0) } END { for (k in n) t += n[k]; print t, s }' in
  run awk '$2 ~ /^[0-9]+7$/ { printf "%s %d\n", toupper($1), $2 * 2 }' in
  [ -s "$d/count" ] || { echo "hotbake: $raw counted no calls" >&2; exit 1; }
  (cd "$d" && env -i PATH="$d" love awk '$2 > m[$1] { m[$1] = $2 } END { for (i in m) print i, m[i] }' count \
     | env -i PATH="$d" love sort -n) > "$calls"
elif [ "${1:-}" = -p ]; then
  raw=$2 prof=$3 cat=$4
  d=$(mktemp -d) || exit 1
  trap 'rm -rf "$d"' EXIT
  env LOVE_NO_IMAGE=1 LOVE_BAKE_CHUNK=512 LOVE_BAKE_CALLS="$(keep)" "$raw" bake -o "$d/love" -l "$cat" || exit 1
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
  env LOVE_NO_IMAGE=1 LOVE_BAKE_HOT="$here/hot.prof" LOVE_BAKE_CALLS="$(keep)" "$1" bake -o "$2" -l "$3"
fi
