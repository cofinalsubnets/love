#!/bin/sh
# test/kore/procfs.sh -- the /proc family: ps, free, uptime, pidof, pgrep, pkill, killall, pwdx
. "$(dirname "$0")/common.sh"

# NOT byte-for-byte, and it cannot be: the process table moves between two runs and
# every number these read is a clock. The PARSERS are lawed in laws.sh (ustatf, uclk,
# utty, uupsay); what is asked here is that the FACES agree with procps about the machine
# they are both looking at -- the header they print, a process we made ourselves, and
# a number that has to come out of /proc/meminfo.
# the victim is a COPY of sleep under our own name: `killall sleep` on a shared box
# would reach into somebody else's build, and this gate has no business doing that.
nap=$ho/.kore-nap
cp "$(command -v sleep)" "$nap" 2>/dev/null && chmod 755 "$nap"
ps    | head -1 > "$g"; korerun ps -e | head -1 > "$o"; same "ps header"
free  | head -1 > "$g"; korerun free  | head -1 > "$o"; same "free header"
if [ -x "$nap" ]; then
  "$nap" 30 & n1=$!
  "$nap" 30 & n2=$!
  sleep 1
  korerun ps -e | awk '{print $1}' | grep -qx "$n1" || fail "kore ps -e missed our own child"
  korerun pidof .kore-nap | tr ' ' '\n' | grep -qx "$n1" || fail "kore pidof missed one"
  korerun pidof .kore-nap | tr ' ' '\n' | grep -qx "$n2" || fail "kore pidof missed one"
  # every pid we name is one procps names too -- the other way round is a race, since
  # a process can arrive between the two readings and neither tool is wrong about it
  korerun pgrep -x .kore-nap | LC_ALL=C sort > "$o"
  pgrep -x .kore-nap | LC_ALL=C sort > "$g"
  comm -23 "$o" "$g" > "$ho/.kore-px"
  [ ! -s "$ho/.kore-px" ] || fail "kore pgrep named a pid procps does not"
  korerun pkill -x .kore-nap || fail "kore pkill"
  wait $n1; r=$?; [ $r -eq 143 ] || fail "kore pkill did not TERM (rc $r)"
  wait $n2; r=$?; [ $r -eq 143 ] || fail "kore pkill left one alive (rc $r)"
  "$nap" 30 & n3=$!
  sleep 1
  [ "$(korerun pwdx $n3)" = "$(pwdx $n3)" ] || fail "kore pwdx vs procps"
  korerun killall .kore-nap || fail "kore killall"
  wait $n3; r=$?; [ $r -eq 143 ] || fail "kore killall did not TERM (rc $r)"
fi
korerun killall nosuchprocess 2>/dev/null; r=$?; [ $r -eq 1 ] || fail "kore killall miss exit (rc $r)"
korerun pidof nosuchprocess > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore pidof miss exit (rc $r)"
mt=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
[ "$(korerun free | awk 'NR==2{print $2}')" = "$mt" ] || fail "kore free total vs /proc/meminfo"
[ "$(korerun free -m | awk 'NR==2{print $2}')" = "$((mt / 1024))" ] || fail "kore free -m"
# no `N users` clause: it comes out of utmp, which this tree does not keep
korerun uptime | grep -qE '^ [0-9][0-9]:[0-9][0-9]:[0-9][0-9] up .*load average: [0-9]' \
  || fail "kore uptime shape"
korerun uptime | grep -q users && fail "kore uptime invented a user count"
echo "kore: the /proc family (ps/free/uptime/pidof/pgrep/pkill/killall/pwdx vs procps) ok"
