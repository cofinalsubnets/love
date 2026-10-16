#!/bin/sh
# test/gate/raw-bake.sh -- test_raw's objects linked -pie by mooncc (high load, clear of
# the fixnum range), baked into the binary's own .image, woken, and the corpus run over it
# usage: raw-bake.sh OUTDIR CORPUS.l ..
. test/gate/skip.sh
. test/gate/cclib.sh
set -u

ho=$1
shift

arch=$(uname -m)
if [ "$arch" != x86_64 ]; then                 # the kernel's spelling, not the tree's
  gate_skip "test_raw_bake: x86-64 only, skipped on $arch"
fi

name=test_raw_bake

d=$ho/raw
ls "$d"/*.o >/dev/null 2>&1 || fail "no objects in $d -- run test_raw first"

echo "BAKE-WAKE $ho/love-raw-pie"
moonc -pie "$d"/*.o -o "$ho/love-raw-pie" || fail "-pie link love-raw-pie"

# bake a copy: the unbaked pie binary stays
cp "$ho/love-raw-pie" "$ho/love-raw-baked"
"$ho/love-raw-baked" bake >/dev/null 2>&1 \
  || fail "bake (the mooncc-PIE binary refused to snapshot its own image)"

# the corpus runs concatenated in one scope
out=$ho/.test_raw_bake.out
# the corpus as a file, stdin closed: the corpus tests stdin
cat "$@" > "$ho/.corpus-baked.l"
"$ho/love-raw-baked" "$ho/.corpus-baked.l" </dev/null > "$out" 2>&1
s=$?
tail -1 "$out"
[ $s -eq 0 ] && grep -q "tests pass" "$out" \
  || fail "the woken corpus (exit $s) -- love_image_load desync?"

echo "test_raw_bake: the mooncc-PIE binary bakes its own image and WAKES it -- corpus passes on the woken heap"
