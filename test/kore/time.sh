#!/bin/sh
# test/kore/time.sh -- time: the three lines, the status, the ordering, 127
. "$(dirname "$0")/common.sh"

# time: the clock is the subject, so the SHAPE and the status are the check -- three
# lines on err, seconds to two places, after the command's own output, and a real no
# shorter than the sleep it was handed
korerun time -p "$K" kore sleep 1 2> "$o"; r=$?
[ $r -eq 0 ] || fail "kore time status (exit $r)"
[ "$(wc -l < "$o")" -eq 3 ] || fail "kore time report is not three lines"
grep -q '^real [0-9][0-9]*\.[0-9][0-9]$' "$o" || fail "kore time real"
grep -q '^user [0-9][0-9]*\.[0-9][0-9]$' "$o" || fail "kore time user"
grep -q '^sys [0-9][0-9]*\.[0-9][0-9]$' "$o" || fail "kore time sys"
awk '/^real/ { exit !($2 >= 1.0) }' "$o" || fail "kore time real under the sleep"
# the status answered is the command's, and the report comes after what it printed
korerun time "$K" kore false > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "kore time carries the command's status (exit $r)"
korerun time "$K" kore echo mid > "$o" 2>&1
[ "$(head -n 1 "$o")" = mid ] || fail "kore time reported before the command's output"
# a command that will not start costs 127, and no command at all is usage
korerun time "$ho/.kore-nocmd" > /dev/null 2>&1; r=$?
[ $r -eq 127 ] || fail "kore time missing command (exit $r)"
korerun time > /dev/null 2>&1; r=$?
[ $r -eq 2 ] || fail "kore time usage (exit $r)"
echo "kore: time (the three lines, the status, the ordering, 127) ok"
