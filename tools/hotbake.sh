#!/bin/sh
# tools/hotbake.sh -- the hot-first bake: the objects a short run touches laid first, so a
# lazy wake decodes a few chunks, not one in two.
#   sh tools/hotbake.sh RAW OUT CAT
# bake RAW with page-sized stream chunks, run the fixed workloads below on that, each
# recording the chunks it woke (LOVE_TOUCH_OUT), then bake RAW again laying those ranges
# first (LOVE_BAKE_HOT). both bakes are of the one tree, so their heaps agree word for word.
# the workloads read only the tree, from its root, under an empty environment, and the
# profiling binary runs as `love` off PATH: a verb is found by the name it is run as, so
# any other name touches other slots. the profile, and so the image, is a function of the
# tree (test/gate/bakerep.sh holds it to that).
set -u
raw=$1 out=$2 cat=$3
d=$(mktemp -d) || exit 1
trap 'rm -rf "$d"' EXIT
env LOVE_NO_IMAGE=1 LOVE_BAKE_CHUNK=512 "$raw" bake -o "$d/love" -l "$cat" || exit 1
run() { env -i PATH="$d" LOVE_TOUCH_OUT="$d/touch" love "$@" > /dev/null 2>&1 < /dev/null; }
run -e 1
run kore echo hi
run kore ls love
run kore cat love/love.h
run kore sort love/love.h
run kore grep -c lvm love/love.c
run kore wc love/love.c
run kore head -3 love/love.c
run lush -c true
# a build whose wake is eager (not moonlibc's: HCC, the gcc lanes) records no touch, and
# bakes plain
hot=
[ -s "$d/touch" ] && hot="$d/touch"
env LOVE_NO_IMAGE=1 LOVE_BAKE_HOT="$hot" "$raw" bake -o "$out" -l "$cat"
