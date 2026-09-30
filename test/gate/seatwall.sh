#!/bin/sh
# test/gate/seatwall.sh -- what the wasm seat's node runner refuses a guest: a fetch that
# climbs out of --origin, by .. or by a link, and a lift nobody asked for -- which lands
# nowhere without --lifts, and under it never over a file already there.
# run from the tree's top. NOT set -e: each law reports its own failure with context.
#
# usage: seatwall.sh NODE MODULE IMAGE DIR
set -u

node=$1
wasm=$2
image=$3
d=$4
top=$(pwd)
case $wasm in /*) ;; *) wasm=$top/$wasm ;; esac
case $image in /*) ;; *) image=$top/$image ;; esac
case $d in /*) ;; *) d=$top/$d ;; esac
seat=$top/src/inle/wasm/inle.mjs
bad=0

rm -rf "$d"
mkdir -p "$d/o" "$d/cwd" "$d/l"
echo seat-secret > "$d/secret"
echo within > "$d/o/ok.txt"
ln -s ../secret "$d/o/ln"
echo old > "$d/l/x"

# one boot, from its own cwd: fetches under --origin, and a lift with no --lifts
(cd "$d/cwd" && INLE_RAM=256 "$node" "$seat" --origin "$d/o" --image "$image" "$wasm" \
   sh -c 'wget -q -O /tmp/a ../secret; echo climb: $?; wget -q -O /tmp/b ln; echo link: $?; wget -q -O /tmp/c ok.txt && cat /tmp/c; echo planted > /tmp/.profile; echo /tmp/.profile > /proc/lift; sleep 1' \
   < /dev/null > "$d/one.log" 2>&1)
grep -q "climb: 4" "$d/one.log" || { echo "seatwall: a fetch climbed out of --origin by .."; bad=1; }
grep -q "link: 4" "$d/one.log" || { echo "seatwall: a fetch left --origin through a link"; bad=1; }
grep -q "^within" "$d/one.log" || { echo "seatwall: a fetch under --origin was refused"; bad=1; }
grep -q "seat-secret" "$d/one.log" && { echo "seatwall: the host file reached the guest"; bad=1; }
grep -q "refused (no --lifts)" "$d/one.log" || { echo "seatwall: an unasked lift was not refused"; bad=1; }
[ -e "$d/cwd/.profile" ] && { echo "seatwall: an unasked lift landed beside the runner"; bad=1; }

# and with --lifts: a name already there stays as it was
INLE_RAM=256 "$node" "$seat" --lifts "$d/l" --image "$image" "$wasm" \
   sh -c 'echo new > /tmp/x; echo /tmp/x > /proc/lift; sleep 1' < /dev/null > "$d/two.log" 2>&1
grep -q "EEXIST" "$d/two.log" || { echo "seatwall: a lift did not refuse a file already there"; bad=1; }
[ "$(cat "$d/l/x")" = old ] || { echo "seatwall: a lift wrote over a file already there"; bad=1; }

if [ $bad = 0 ]; then echo "  seatwall: ok -- no climb, no link, no unasked lift, no overwrite"
else tail -8 "$d/one.log"; tail -8 "$d/two.log"; fi
exit $bad
