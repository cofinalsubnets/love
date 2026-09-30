#!/bin/sh
# test/kore/top.sh -- top: the header block, a table, a pid we hold, and both faces on a pty
. "$(dirname "$0")/common.sh"

# every figure here is a clock and the table moves between two reads, so nothing
# below compares a number to procps'. what IS fixed is the shape -- the five header
# lines, the column row, a row per process -- and the two things only this tool can
# say: a pid we are holding open is in the listing, and -p narrows to it.
korerun top -b -n 1 > "$o" 2>&1 || fail "kore top -b"
for want in "top - " "Tasks: " "%Cpu(s):" "MiB Mem :" "MiB Swap:" "PID USER"; do
  grep -q "$want" "$o" || { cat "$o"; fail "kore top: no '$want' line"; }
done
# the header block is six lines (five and the blank), so a listing has rows under it
[ "$(wc -l < "$o")" -gt 8 ] || { cat "$o"; fail "kore top: a header and no table"; }
# a process we made ourselves is in it, by pid and by name
sleep 30 &
tpid=$!
korerun top -b -n 1 > "$o" 2>&1 || fail "kore top -b (with a child)"
awk -v p="$tpid" '$1 == p { found = 1 } END { exit !found }' "$o" \
  || { cat "$o"; fail "kore top: pid $tpid is not in the table"; }
# ..and -p is that pid and nothing else
korerun top -b -n 1 -p "$tpid" > "$o" 2>&1 || fail "kore top -p"
[ "$(awk 'NR > 7 && NF' "$o" | wc -l)" = 1 ] || { cat "$o"; fail "kore top -p: not one row"; }
awk -v p="$tpid" 'NR > 7 && NF { exit $1 != p }' "$o" || { cat "$o"; fail "kore top -p: the wrong row"; }
kill "$tpid" 2>/dev/null
wait "$tpid" 2>/dev/null
# -n 2 draws two frames, separated by a blank line
korerun top -b -n 2 > "$o" 2>&1 || fail "kore top -b -n 2"
[ "$(grep -c "PID USER" "$o")" = 2 ] || { cat "$o"; fail "kore top -n 2: not two frames"; }
# an unknown option is a usage refusal, the status every kore applet answers with
korerun top -Z > "$o" 2>&1
[ $? -eq 2 ] || { cat "$o"; fail "kore top -Z: not 2"; }
echo "kore: top (the header block, a table, a pid we hold, -p, -n 2, the refusal) ok"
# ..and the SCREEN faces, plain and rich, which need a terminal of their own
echo "TOP test/host/top.l (both faces on a pty)"
cat test/00-init.l test/host/top.l | LOVEBIN=$K "$m" > "$o" 2>&1
r=$?
{ [ $r -eq 0 ] && grep -q "test/host/top:" "$o"; } || { cat "$o"; fail "kore top on a pty (exit $r)"; }
tail -1 "$o"
