#!/bin/sh
# LOVE_IMAGE on an unbaked binary: missing, it bakes and goes on; laid, it wakes; damaged, it bakes
# again, and no scratch name stays behind. $1 the raw love, $2 a scratch directory
d=$2; i=$d/env.image; log=$d/env.log; raw=$d/ro/love
fail() { cat "$log"; echo "FAIL envimage: $1"; exit 1; }
[ ! -d "$d/ro" ] || chmod 755 "$d/ro"
rm -rf "$d"; mkdir -p "$d/ro"; cp "$1" "$raw"; chmod 555 "$d/ro"   # an app's lib dir takes no scratch
LOVE_IMAGE=$i "$raw" -v > "$log" 2>&1 || fail "the first run"
grep -q "love: first run, baking" "$log" || fail "the first run did not bake"
[ -s "$i" ] || fail "no image laid"
LOVE_IMAGE=$i "$raw" -v > "$log" 2>&1 || fail "the second run"
grep -q baking "$log" && fail "the second run baked again"
[ "$(LOVE_IMAGE=$i "$raw" echo hi 2>&1)" = hi ] || fail "the image holds no crew"
printf torn > "$i"
LOVE_IMAGE=$i "$raw" -v > "$log" 2>&1 || fail "the run after damage"
grep -q "love: first run, baking" "$log" || fail "a damaged image was not baked again"
[ "$(ls "$d" | grep -c 'env\.image\.')" = 0 ] || fail "a scratch image stayed"
chmod 755 "$d/ro"
echo "envimage: a named image bakes when missing or damaged, and wakes when laid"
