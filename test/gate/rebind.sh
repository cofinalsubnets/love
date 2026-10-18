#!/bin/sh
# test/gate/rebind.sh LOVE LOVE0 -- test/gate/rebind.l three ways: the glazed love, the same with
# LOVE_NO_GLAZE=1, and love0; each must answer gwen's rebinding law
love=$1 love0=$2 want='(2 10 1 1 4)'
g=$($love test/gate/rebind.l 2>&1 | tail -1)
u=$(LOVE_NO_GLAZE=1 $love test/gate/rebind.l 2>&1 | tail -1)
z=$(LOVE_NO_IMAGE= $love0 test/gate/rebind.l 2>&1 | tail -1)
[ "$g" = "$want" ] || { echo "FAIL rebind (glazed): want $want, got $g"; exit 1; }
[ "$u" = "$want" ] || { echo "FAIL rebind (unglazed): want $want, got $u"; exit 1; }
[ "$z" = "$want" ] || { echo "FAIL rebind (love0): want $want, got $z"; exit 1; }
echo "rebind: a rebinding shadows past it, its own body sees the earlier one -- glazed, unglazed and in love0"
