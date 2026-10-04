#!/bin/sh
# test/gate/ccwarn.sh -- each foreign cc builds love without a warning: love0, the bootstrap
# the ambient cc compiles in the default lane, and the whole hosted vm (HCC=1, tco=1), at
# the tree's own -W set with -Werror. a warning turns the lane red here, not a line in a log.
# out/cc is cleared first: its stamp keys on the cc, not the flags, so objects an earlier
# lane laid would be taken as they are and read by no one.
# usage: ccwarn.sh CC..
. test/gate/skip.sh
set -u
fail() { echo "FAIL test_ccwarn: $*" >&2; exit 1; }

# the hosted vm at tco=1 wants love_musttail, as test_hdiff says; a cc without it could not
# build love at all, which is an old toolchain and not a warning
mtc=out/.ccwarn-musttail.c
mkdir -p out
printf '%s\n' \
  '#if !defined(__clang__) && !(defined(__GNUC__) && __GNUC__ >= 15)' \
  '#error no musttail' \
  '#endif' \
  'int main(void) { return 0; }' > "$mtc"

ran=""
for cc in "$@"; do
  command -v "$cc" > /dev/null 2>&1 || { gate_partly "test_ccwarn: no $cc, skipped"; continue; }
  "$cc" -c "$mtc" -o "$mtc".o > /dev/null 2>&1 || {
    gate_partly "test_ccwarn: $cc has no musttail, so it cannot build the vm -- SKIPPED, not passed"
    continue; }
  log=out/.ccwarn-$cc.log
  rm -rf out/cc
  echo "  $cc: love0 and the hosted vm, -Werror"
  make --no-print-directory HCC=1 CC="$cc" EXTRA_CFLAGS=-Werror host > "$log" 2>&1 || {
    grep -e 'warning:' -e 'error:' "$log" | head -20 >&2
    fail "$cc does not build love clean (all of it in $log)"; }
  ran="$ran $cc"
done

rm -f "$mtc" "$mtc".o
[ -n "$ran" ] || gate_skip "test_ccwarn: no cc here could run this lane -- nothing was proved"
echo "test_ccwarn:$ran each build love0 and the hosted vm without a warning"
