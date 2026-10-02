#!/bin/sh
# src/tools/hotbake.sh -- the hot-first bake: the objects a short run touches laid first, so a
# lazy wake decodes a few chunks, not one in two.
#   sh src/tools/hotbake.sh RAW OUT CAT      bake RAW to OUT, laid by the tree's src/tools/hot.prof
#   sh src/tools/hotbake.sh -p RAW PROF CAT  profile RAW, writing the word ranges to PROF
# the profile is kept in the tree so the image is a function of the tree alone, not of the
# page size or libc of the machine that bakes it. a change to anything baked moves the
# heap under it: `make hotprof` writes it again, and test_bakerep fails while it is stale.
# the RAW profiled is the Makefile's prof_raw, a link carrying the tree less hot.prof: the
# profile never measures itself, so one pass is its fixed point.
# profiling bakes RAW with page-sized stream chunks and runs the fixed workloads below on
# that, each recording the chunks it woke (LOVE_TOUCH_OUT). both bakes are of the one crew,
# so their heaps agree word for word. the workloads read only files made here, under an
# empty environment, and the binary runs as `love` off PATH: a verb is found by the name it
# is run as, so any other name touches other slots.
set -u
here=$(cd "$(dirname "$0")" && pwd) || exit 1
# the bake is the script's last word: a bare `exit` in a recipe's script ends the whole
# recipe line when cook runs it in its own image
if [ "${1:-}" = -p ]; then
  raw=$2 prof=$3 cat=$4
  d=$(mktemp -d) || exit 1
  trap 'rm -rf "$d"' EXIT
  env LOVE_NO_IMAGE=1 LOVE_BAKE_CHUNK=512 "$raw" bake -o "$d/love" -l "$cat" || exit 1
  mkdir "$d/w" || exit 1
  i=0
  while [ $i -lt 40 ]; do
    echo "line $((i * 7 % 40)) of the lvm fixture: $((i * i)) words, $((40 - i)) left"
    i=$((i + 1))
  done > "$d/w/in"
  run() { (cd "$d/w" && env -i PATH="$d" LOVE_TOUCH_OUT="$d/touch" love "$@" > /dev/null 2>&1 < /dev/null); }
  run -e 1
  run kore echo hi
  run kore ls .
  run kore cat in
  run kore sort in
  run kore grep -c lvm in
  run kore wc in
  run kore head -3 in
  run lush -c true
  # a build whose wake is eager (not moonlibc's: HCC, the gcc lanes) records no touch
  [ -s "$d/touch" ] || { echo "hotbake: $raw woke eagerly, no profile" >&2; exit 1; }
  cp "$d/touch" "$prof"
else
  env LOVE_NO_IMAGE=1 LOVE_BAKE_HOT="$here/hot.prof" "$1" bake -o "$2" -l "$3"
fi
