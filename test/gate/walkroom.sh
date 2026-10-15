#!/bin/sh
# test/gate/walkroom.sh -- a walk's room: a hash, an = or a compare keeps its worklist in the
# gap and never past it. spent, its op takes the room and runs again, so a value bigger than
# any gap answers as it would in a roomy session; past the budget it is the oom scare, which
# a trap catches, and the session carries on.
# usage: sh test/gate/walkroom.sh LOVE
set -u
love=${1:-out/love}
d=out/.walkroom && mkdir -p $d
fails=0
# a copy, so every run below is a process of its own: under lush the binary itself runs as
# a warm fork of the shell, whose pools were sized before LOVE_BUDGET_MB was read
cp "$love" $d/love && chmod +x $d/love || { echo "FAIL walkroom: cannot copy $love"; exit 1; }
love=$d/love

# a 1.5M-long list: its hash walks a word an element, far past a fresh nursery's gap
printf '%s\n' '(: l (jot 1500000) m (map (+ 0) l) t {} _ (pin t l (quote v))' \
  ' (puts (show [(dig l) (peep t m 0) (l = m) (sort [m l] = [l m])] + "\n")))' > $d/big.l
tight=$(LOVE_BUDGET_MB=96 "$love" $d/big.l 2>&1)
roomy=$(LOVE_BUDGET_MB=1024 "$love" $d/big.l 2>&1)
[ "$tight" = "$roomy" ] || { echo "FAIL walkroom: at 96 MB '$tight', at 1024 MB '$roomy'"; fails=$((fails+1)); }
case $tight in *" v 1 1)") ;; *) echo "FAIL walkroom: the big list answered '$tight'"; fails=$((fails+1)) ;; esac

# an object tray a third of a 64 MB budget: it fits, its hash's worklist (a word a cell) does not
printf '%s\n' '(: n (35 * 83886) r (trap (n \ dig (top-tray [n] [])) n (a \ b \ (quote scared)))' \
  ' (puts (show r + " after\n")))' > $d/oom.l
out=$(LOVE_BUDGET_MB=64 "$love" $d/oom.l 2>&1); st=$?
[ "$st" = 0 ] && [ "$out" = "scared after" ] || {
  echo "FAIL walkroom: past the budget, exit $st and '$out', wanted the scare caught"; fails=$((fails+1)); }

[ $fails = 0 ] || exit 1
echo "walkroom: a walk past the gap runs again in more room, past the budget it scares and the session lives"
