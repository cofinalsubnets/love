#!/bin/sh
# test/gate/ccwarn.sh -- each foreign cc builds love without a warning: love0, the bootstrap
# the ambient cc compiles in the default lane, and the whole hosted vm (HCC=1, tco=1), at
# the tree's own -W set with -Werror. a warning turns the lane red here, not a line in a log.
# the ccs build at once, each in a copy of the tree of its own under out/.ccwarn/CC, from
# clean: love0 is out/0 whatever the cc, so two in one tree would build over each other.
# each make takes -j$CCWARN_J, or none under a parent's jobserver, whose pool it then shares.
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

ccs=""
for cc in "$@"; do
  command -v "$cc" > /dev/null 2>&1 || { gate_partly "test_ccwarn: no $cc, skipped"; continue; }
  "$cc" -c "$mtc" -o "$mtc".o > /dev/null 2>&1 || {
    gate_partly "test_ccwarn: $cc has no musttail, so it cannot build the vm -- SKIPPED, not passed"
    continue; }
  ccs="$ccs $cc"
done

case "${MAKEFLAGS:-}" in *jobserver*) j="";; *) j="-j${CCWARN_J:-4}";; esac
pids=""
for cc in $ccs; do
  d=out/.ccwarn/$cc log=out/.ccwarn-$cc.log
  rm -rf "$d" && mkdir -p "$d"
  tar -cf - --exclude=./out --exclude=./.git . | tar -xf - -C "$d"
  echo "  $cc: love0 and the hosted vm, -Werror"
  make -C "$d" --no-print-directory $j HCC=1 CC="$cc" EXTRA_CFLAGS=-Werror host > "$log" 2>&1 &
  pids="$pids $!"
done

ran="" bad=""
set -- $pids
for cc in $ccs; do
  if wait "$1"; then ran="$ran $cc"
  else grep -e 'warning:' -e 'error:' "out/.ccwarn-$cc.log" | head -20 >&2; bad="$bad $cc"; fi
  rm -rf "out/.ccwarn/$cc"                  # the log is outside it, and a build is a lot to keep
  shift
done
[ -z "$bad" ] || fail "$bad do not build love clean (all of it in out/.ccwarn-CC.log)"

rm -f "$mtc" "$mtc".o
[ -n "$ran" ] || gate_skip "test_ccwarn: no cc here could run this lane -- nothing was proved"
echo "test_ccwarn:$ran each build love0 and the hosted vm without a warning"
