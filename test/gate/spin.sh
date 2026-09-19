#!/bin/sh
# test/gate/spin.sh -- the machine spends nothing while it waits.
# a scheduler bug that spins burns a core without dropping a single answer, so every gate
# in the tree stays green through it: correctness cannot see it, and only the cpu can.
# kiosko served every request it was given while pinning a core from the first one.
# the shape is test/gate/spin.l's; what is weighed here is /proc, so a seat without one
# skips whole rather than passing quietly.
#
# usage: sh test/gate/spin.sh LOVE
set -u

love=$1
ceiling=25            # per cent of one core: a waiting machine spends ~0, a spinning one 100

if [ ! -r /proc/self/stat ]; then
  echo "  spin: skipped (no /proc to weigh the machine with)"
  exit 0
fi

"$love" test/gate/spin.l > /dev/null 2>&1 &
pid=$!
sleep 1
[ -r /proc/$pid/stat ] || { echo "FAIL spin: the machine did not start"; exit 1; }
before=$(awk '{print $14+$15}' /proc/$pid/stat)
sleep 2
after=$(awk '{print $14+$15}' /proc/$pid/stat)
wait $pid
pct=$(( (after - before) * 100 / 200 ))
if [ $pct -lt $ceiling ]; then
  echo "  spin: ok -- $pct% of a core while a dead task sat beside a sleeping one"
else
  echo "FAIL spin: $pct% of a core with nothing to run -- a task on its way out is spinning" >&2
  exit 1
fi
