#!/bin/sh
# LOVE_IMAGE on an unbaked binary: missing, it bakes and goes on; laid, it wakes; damaged, it bakes
# again, and no scratch name stays behind. $1 the raw love, $2 a scratch directory
raw=$1; d=$2; i=$d/env.image; log=$d/env.log
fail() { cat "$log"; echo "FAIL envimage: $1"; exit 1; }
rm -rf "$d"; mkdir -p "$d"
LOVE_IMAGE=$i "$raw" -v > "$log" 2>&1 || fail "the first run"
grep -q "love: first run, baking" "$log" || fail "the first run did not bake"
[ -s "$i" ] || fail "no image laid"
LOVE_IMAGE=$i "$raw" -v > "$log" 2>&1 || fail "the second run"
grep -q baking "$log" && fail "the second run baked again"
printf torn > "$i"
LOVE_IMAGE=$i "$raw" -v > "$log" 2>&1 || fail "the run after damage"
grep -q "love: first run, baking" "$log" || fail "a damaged image was not baked again"
[ "$(ls "$d" | grep -c 'env\.image\.')" = 0 ] || fail "a scratch image stayed"
echo "envimage: a named image bakes when missing or damaged, and wakes when laid"
