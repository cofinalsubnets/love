#!/bin/sh
# test/kore/procfs.sh -- the /proc family: ps, free, uptime, pidof, pgrep, pkill, killall, pwdx
. "$(dirname "$0")/common.sh"

# not byte for byte: the table moves and every number is a clock. the faces must agree with
# procps on the header, a process of our own, and a /proc/meminfo figure. the victim is a
# copy of sleep under our own name, so killall reaches no one else's
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
  # every pid we name procps names too; the reverse races a newcomer
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
# the users clause counts utmp as `who -q` does; no utmp, no clause
korerun uptime | grep -qE '^ [0-9][0-9]:[0-9][0-9]:[0-9][0-9] up .*load average: [0-9]' \
  || fail "kore uptime shape"
nu=$(korerun who -q 2>/dev/null | sed -n 's/^# users=//p')
if [ -n "$nu" ]; then
  u=$(korerun uptime | sed -n 's/.*,  \([0-9]*\) users*,.*/\1/p')
  [ "$u" = "$nu" ] || fail "kore uptime's users ($u) vs who -q ($nu)"
else
  korerun uptime | grep -q users && fail "kore uptime invented a user count"
fi
# ps's faces on pid 1 and every header, TZ=UTC0: -o renamed and blank, -p, -f, aux, -e, -u,
# an unknown key, a missing pid. TIME digits are blanked (width kept); vsz and rss by header
pstm() { sed -E 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/HH:MM:SS/; s/ [0-9]+:[0-9]{2} / M:SS /'; }
for c in "-o pid,ppid,user,comm,stat,tty -p 1" "-o pid=,ppid=,comm= -p 1" "-o pid,user,stat,ni -p 1" "-f -p 1"; do
  # shellcheck disable=SC2086
  TZ=UTC0 ps $c | pstm > "$g"; TZ=UTC0 korerun ps $c | pstm > "$o"; same "ps $c"
done
ps -o pid,user,vsz,rss,stat,ni -p 1 | head -1 > "$g"; korerun ps -o pid,user,vsz,rss,stat,ni -p 1 | head -1 > "$o"; same "ps -o vsz,rss's headers"
# aux's pid-1 row: %CPU %MEM VSZ RSS (fields 3-6) move too, blanked in place
psmvp='on && NR > 1 { o = ""; n = 0; w = 0; for (i = 1; i <= length($0); i++) { ch = substr($0, i, 1); if (ch == " ") w = 0; else if (!w) { w = 1; n++ }; if (n >= 3 && n <= 6 && ch ~ /[0-9]/) ch = "9"; o = o ch }; $0 = o } { print }'
psmv() { awk -v on="$1" "$psmvp"; }
for c in -e -ef aux; do
  blank=0; [ "$c" = aux ] && blank=1
  # shellcheck disable=SC2086
  TZ=UTC0 ps $c | awk 'NR == 1 || $2 == 1 || $1 == 1' | pstm | psmv $blank > "$g"; TZ=UTC0 korerun ps $c | awk 'NR == 1 || $2 == 1 || $1 == 1' | pstm | psmv $blank > "$o"; same "ps $c"
done
[ "$(korerun ps -o pid=P,comm -p 1 | head -1)" = "      P COMMAND" ] || fail "kore ps -o, a header renamed"
korerun ps -u root | awk '{ print $1 }' | grep -qx 1 || fail "kore ps -u root"
korerun ps -o bogus > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore ps -o bogus ($r)"
korerun ps -p 999999999 > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore ps -p of no pid ($r)"
# args with control bytes, procps's utf-8 face: a newline a space, the rest ?, C1 too; -f matches that face
qa=$(printf 'kq\tb\nc\001d\177e \303\251\302\233f')
sh -c 'sleep 30; :' kq "$qa" & pq=$!; sleep 0.3
for c in "ps -o args= -p $pq" "pgrep -a -f kq.b" "pgrep -f kq\\?b"; do
  # shellcheck disable=SC2086
  LC_ALL=C.UTF-8 $c > "$g" 2>&1; LC_ALL=C.UTF-8 korerun $c > "$o" 2>&1; same "$c, a control byte"
done
kill $pq; wait $pq 2> /dev/null
# a kernel thread has no cmdline: -f matches, and -a shows, its [comm]; -x is a whole regex match
for c in "pgrep -f ^.kthreadd.$" "pgrep -x -f .kthreadd." "pgrep -a -f ^.kthreadd.$" "pgrep -a -x kthreadd" "pgrep -x kthread."; do
  # shellcheck disable=SC2086
  { $c; echo "rc=$?"; } > "$g" 2>&1; { korerun $c; echo "rc=$?"; } > "$o" 2>&1; same "$c, a kernel thread"
done
# pgrep -l -a -c -d -n -o -f -x -u and a miss, over two naps of our own; pkill -e -n the newest alone
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
# free -b -k -m -t -w: the header, row names and totals, which hold still
for c in -b -k -m -t -w -tw; do
  free $c | awk 'NR == 1 { print; next } { print $1, $2 }' > "$g"; korerun free $c | awk 'NR == 1 { print; next } { print $1, $2 }' > "$o"; same "free $c"
done
# uptime -p and -s (btime, TZ=UTC0); hostname -s -f
[ "$(uptime -p)" = "$(korerun uptime -p)" ] || fail "kore uptime -p: $(korerun uptime -p)"
[ "$(TZ=UTC0 uptime -s)" = "$(korerun uptime -s)" ] || fail "kore uptime -s: $(korerun uptime -s)"
for c in "-s" "-f" "--fqdn"; do [ "$(hostname $c)" = "$(korerun hostname $c)" ] || fail "kore hostname $c"; done
echo "kore: the /proc family (ps/free/uptime/pidof/pgrep/pkill/killall/pwdx vs procps) ok"
