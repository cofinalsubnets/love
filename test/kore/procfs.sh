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
# the users clause is the host's utmp, counted as `who -q` counts it; with no utmp to
# read there is none, never an invented 0
korerun uptime | grep -qE '^ [0-9][0-9]:[0-9][0-9]:[0-9][0-9] up .*load average: [0-9]' \
  || fail "kore uptime shape"
nu=$(korerun who -q 2>/dev/null | sed -n 's/^# users=//p')
if [ -n "$nu" ]; then
  u=$(korerun uptime | sed -n 's/.*,  \([0-9]*\) users*,.*/\1/p')
  [ "$u" = "$nu" ] || fail "kore uptime's users ($u) vs who -q ($nu)"
else
  korerun uptime | grep -q users && fail "kore uptime invented a user count"
fi
# ps's faces byte for byte on pid 1's row and every header, under TZ=UTC0 (START and
# STIME are UTC here): -o with its headers renamed and blanked, -p, -f, BSD's aux, -e;
# -u, an unknown key and a pid not there
# a TIME may tick between the two reads, so its digits are blanked, its width kept; a
# size moves between them too, so vsz and rss are held to their headers alone
pstm() { sed -E 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/HH:MM:SS/; s/ [0-9]+:[0-9]{2} / M:SS /'; }
for c in "-o pid,ppid,user,comm,stat,tty -p 1" "-o pid=,ppid=,comm= -p 1" "-o pid,user,stat,ni -p 1" "-f -p 1"; do
  # shellcheck disable=SC2086
  TZ=UTC0 ps $c | pstm > "$g"; TZ=UTC0 korerun ps $c | pstm > "$o"; same "ps $c"
done
ps -o pid,user,vsz,rss,stat,ni -p 1 | head -1 > "$g"; korerun ps -o pid,user,vsz,rss,stat,ni -p 1 | head -1 > "$o"; same "ps -o vsz,rss's headers"
# aux's pid-1 row: %CPU %MEM VSZ RSS (fields 3-6) move too, so their digits are blanked in place
psmv() { awk -v on="$1" 'on && NR > 1 { o = ""; n = 0; w = 0
  for (i = 1; i <= length($0); i++) { ch = substr($0, i, 1)
    if (ch == " ") w = 0; else if (!w) { w = 1; n++ }
    if (n >= 3 && n <= 6 && ch ~ /[0-9]/) ch = "9"; o = o ch }
  $0 = o } { print }'; }
for c in -e -ef aux; do
  m=0; [ "$c" = aux ] && m=1
  # shellcheck disable=SC2086
  TZ=UTC0 ps $c | awk 'NR == 1 || $2 == 1 || $1 == 1' | pstm | psmv $m > "$g"; TZ=UTC0 korerun ps $c | awk 'NR == 1 || $2 == 1 || $1 == 1' | pstm | psmv $m > "$o"; same "ps $c"
done
[ "$(korerun ps -o pid=P,comm -p 1 | head -1)" = "      P COMMAND" ] || fail "kore ps -o, a header renamed"
korerun ps -u root | awk '{ print $1 }' | grep -qx 1 || fail "kore ps -u root"
korerun ps -o bogus > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore ps -o bogus ($r)"
korerun ps -p 999999999 > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore ps -p of no pid ($r)"
# pgrep's -l -a -c -d -n -o -f -x -u and a miss against procps over two naps of our own;
# pkill -e -n takes the newest alone and says so
PN=$PWD/$ho/.kore-pgnap; cp "$(command -v sleep)" "$PN"; chmod 755 "$PN"
"$PN" 30 & pa=$!; sleep 0.3; "$PN" 31 & pb=$!; sleep 0.3
for c in ".kore-pgnap" "-l .kore-pgnap" "-a .kore-pgnap" "-c .kore-pgnap" "-d , .kore-pgnap" "-n .kore-pgnap" "-o .kore-pgnap" \
         "-x .kore-pgnap" "-c -u root .kore-pgnap" "nosuchthing_q"; do
  # shellcheck disable=SC2086
  { pgrep $c; echo "rc=$?"; } > "$g" 2>&1; { korerun pgrep $c; echo "rc=$?"; } > "$o" 2>&1; same "pgrep $c"
done
[ "$(korerun pkill -e -n .kore-pgnap)" = ".kore-pgnap killed (pid $pb)" ] || fail "kore pkill -e -n"
wait $pb; kill -0 $pa || fail "kore pkill -n took the oldest too"
kill $pa; wait $pa 2> /dev/null; rm -f "$PN"
# free's -b -k -m -t -w: the header, each row's name and its total, which hold still while
# the used and free figures move
for c in -b -k -m -t -w -tw; do
  free $c | awk 'NR == 1 { print; next } { print $1, $2 }' > "$g"; korerun free $c | awk 'NR == 1 { print; next } { print $1, $2 }' > "$o"; same "free $c"
done
# uptime -p's words and -s's moment (btime, under TZ=UTC0); hostname -s -f
[ "$(uptime -p)" = "$(korerun uptime -p)" ] || fail "kore uptime -p: $(korerun uptime -p)"
[ "$(TZ=UTC0 uptime -s)" = "$(korerun uptime -s)" ] || fail "kore uptime -s: $(korerun uptime -s)"
for c in "-s" "-f" "--fqdn"; do [ "$(hostname $c)" = "$(korerun hostname $c)" ] || fail "kore hostname $c"; done
echo "kore: the /proc family (ps/free/uptime/pidof/pgrep/pkill/killall/pwdx vs procps) ok"
