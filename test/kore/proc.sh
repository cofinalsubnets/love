#!/bin/sh
# test/kore/proc.sh -- env, printenv, sleep, kill, xargs, whoami, groups, arch, nproc, nohup,
# nice, renice, stty, who, users
. "$(dirname "$0")/common.sh"

pipe "xargs"     'a b
c
'                xargs
pipe "xargs -n 2" '1
2
3
4
5
'                 xargs -n 2 echo
pipe "xargs empty" '' xargs echo
# GLUED -n: every script writes -n1, and the word used to reach spawn as the COMMAND
pipe "xargs -n1" '1
2
3
'                xargs -n1 echo
# the quoting, -0 -d -I -L -r -t, -P's runs overlapping, and a command not there
pipe "xargs quotes" "'a b' \"c d\" e\\ f
" xargs -n 1
pipe "xargs -0" "$(printf 'a b\001c d' | tr '\001' '\0')" xargs -0 -n 1
pipe "xargs -d" 'a:b:c' xargs -d : -n 1
pipe "xargs -d \\n" 'a b
c
' xargs -d '\n' echo Z
pipe "xargs -I" '  x y
z

' xargs -I {} echo [{}] {}
pipe "xargs -L 2" 'x y
z w
q
' xargs -L 2
pipe "xargs -r" '' xargs -r echo nothing
pipe "xargs -I empty" '' xargs -I {} echo {}
printf 'a b\n' | xargs -t echo T > "$g" 2>&1; printf 'a b\n' | korerun xargs -t echo T > "$o" 2>&1; same "xargs -t"
t0=$(date +%s%N); printf '1\n1\n1\n' | korerun xargs -P 3 -n 1 sleep; t1=$(date +%s%N)
[ $(( (t1 - t0) / 1000000 )) -lt 2500 ] || fail "kore xargs -P 3: three 1 s sleeps took $(( (t1 - t0) / 1000000 )) ms"
printf 'a\n' | korerun xargs nosuchcmd_q > /dev/null 2>&1; r=$?; [ $r -eq 127 ] || fail "kore xargs of no command (rc $r)"
pipe "xargs -n3" '1
2
3
4
5
'                xargs -n3 echo
printf 'x\n' | korerun xargs false; r=$?
[ $r -eq 123 ] || fail "kore xargs fail exit (rc $r)"
printf 'x\n' | korerun xargs /no/such/cmd 2>/dev/null; r=$?
[ $r -eq 127 ] || fail "kore xargs 127 (rc $r)"
env AUP=44 sh -c 'printf %s "$AUP"' > "$g"
korerun env AUP=44 sh -c 'printf %s "$AUP"' > "$o"; same "env assign"
# _= is the shell's own last-argument variable and differs by who was exec'd
# the oracle wears korerun's own LOVE_NO_IMAGE= prefix, so the two children
# compare the same environment
LOVE_NO_IMAGE= env | grep -v '^_=' | LC_ALL=C sort > "$g"
korerun env | grep -v '^_=' | LC_ALL=C sort > "$o"; same "env print"
korerun env sh -c 'exit 3'; r=$?; [ $r -eq 3 ] || fail "kore env child exit (rc $r)"
korerun sleep 0.1 || fail "kore sleep"
korerun sleep xx 2>/dev/null; r=$?; [ $r -eq 1 ] || fail "kore sleep bad exit (rc $r)"
sleep 3 & sp=$!
korerun kill -9 $sp || fail "kore kill send"
wait $sp; r=$?; [ $r -eq 137 ] || fail "kore kill effect (rc $r)"
korerun kill -0 999999 2>/dev/null; r=$?; [ $r -eq 1 ] || fail "kore kill dead pid (rc $r)"
# printenv and the three one-line answers. `arch` is not a program on every distro
# (Arch ships none), so uname -m is its oracle -- and nproc's is --all: nothing here
# reads an affinity mask, so the count is the machine's and not this process's
[ "$(KAUP=7 korerun printenv KAUP)" = 7 ] || fail "kore printenv"
korerun printenv NO_SUCH_VAR_HERE > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "kore printenv miss (rc $r)"
LOVE_NO_IMAGE= printenv | grep -v '^_=' | LC_ALL=C sort > "$g"
korerun printenv | grep -v '^_=' | LC_ALL=C sort > "$o"; same "printenv print"
[ "$(korerun whoami)" = "$(whoami)" ] || fail "kore whoami"
[ "$(korerun groups)" = "$(groups)" ] || fail "kore groups"
[ "$(korerun arch)" = "$(uname -m)" ] || fail "kore arch"
# uname -s comes off love-os, not off /proc/sys -- that path is linux's spelling of
# sysctl and the other three kernels have none, so a file read answered "Linux"
# everywhere. This box is the linux arm of that; the inle arm is test/kernel/wfs.l.
[ "$(korerun uname -s)" = "$(uname -s)" ] || fail "kore uname -s"
[ "$(korerun nproc)" = "$(nproc --all)" ] || fail "kore nproc"
# nohup: HUP ignored across the exec, the command's own status back, 125/126/127 for its
# own trouble; under a terminal (script(1) makes one) output lands in nohup.out, 0600
[ "$(korerun nohup sh -c 'kill -HUP $$; echo survived')" = survived ] || fail "kore nohup: HUP must be ignored"
korerun nohup sh -c 'exit 3'; r=$?; [ $r -eq 3 ] || fail "kore nohup: the command's status (got $r)"
korerun nohup /nonexistent/cmd 2>/dev/null; r=$?; [ $r -eq 127 ] || fail "kore nohup: no such command is 127 (got $r)"
korerun nohup "$HO" 2>/dev/null; r=$?; [ $r -eq 126 ] || fail "kore nohup: a command that will not run is 126 (got $r)"
korerun nohup 2>/dev/null; r=$?; [ $r -eq 125 ] || fail "kore nohup: no operand is 125 (got $r)"
if script -qec true /dev/null > /dev/null 2>&1; then
  N=$HO/.nohup; rm -rf "$N"; mkdir "$N"
  (cd "$N" && script -qec "$K kore nohup sh -c 'echo out; echo errline >&2'" /dev/null > "$N/tty" 2>&1)
  grep -q "ignoring input and appending output to 'nohup.out'" "$N/tty" || fail "kore nohup: the terminal's sentence"
  [ "$(cat "$N/nohup.out")" = "out
errline" ] || fail "kore nohup: stdout and stderr land in nohup.out"
  [ "$(stat -c %a "$N/nohup.out")" = 600 ] || fail "kore nohup: nohup.out is made 0600"
fi
# nice: bare it says the niceness; -n N runs the command N lower (capped at 19); 125 its
# own trouble, 127 no such command. renice aims only at a child of this script, and at
# 19, which any caller may reach
n0=$(korerun nice); [ "$n0" = "$(nice)" ] || fail "kore nice: bare"
w=$((n0 + 3)); [ $w -gt 19 ] && w=19
[ "$(korerun nice -n 3 "$K" kore nice)" = $w ] || fail "kore nice -n 3"
[ "$(korerun nice -3 "$K" kore nice)" = $w ] || fail "kore nice -3, the old spelling"
korerun nice -n x true 2>/dev/null; r=$?; [ $r -eq 125 ] || fail "kore nice: a bad adjustment is 125 (got $r)"
korerun nice -n 3 2>/dev/null; r=$?; [ $r -eq 125 ] || fail "kore nice: an adjustment wants a command (got $r)"
korerun nice /nonexistent/cmd 2>/dev/null; r=$?; [ $r -eq 127 ] || fail "kore nice: no such command is 127 (got $r)"
sleep 5 & sp=$!
[ "$(korerun renice 19 -p $sp)" = "$sp (process ID) old priority $n0, new priority 19" ] || fail "kore renice -p"
korerun renice 19 -p 2147483646 2>/dev/null; r=$?; [ $r -eq 1 ] || fail "kore renice: no such pid is 1 (got $r)"
korerun renice x -p $sp 2>/dev/null; r=$?; [ $r -eq 1 ] || fail "kore renice: a bad priority is 1 (got $r)"
kill $sp 2>/dev/null
# stty: GNU's three views to the byte under a terminal script(1) makes, and settings
# GNU's own stty then reads back; off a terminal, GNU's refusal
korerun stty < /dev/null 2> "$o"; r=$?
[ $r -eq 1 ] || fail "kore stty off a terminal is 1 (got $r)"
grep -q "stty: 'standard input': Inappropriate ioctl for device" "$o" || fail "kore stty: the refusal's words"
if command -v stty >/dev/null 2>&1 && script -qec true /dev/null > /dev/null 2>&1; then
  for v in "" "-a" "size" "speed"; do
    script -qec "stty $v" /dev/null 2>&1 | tr -d '\r' > "$g"
    script -qec "$K kore stty $v" /dev/null 2>&1 | tr -d '\r' > "$o"; same "stty $v"
  done
  for v in "-echo intr ^A" "raw" "sane" "cbreak min 3 time 2" "evenp" "nl -ixon" "erase 0x8 kill undef"; do
    script -qec "stty $v; stty -a" /dev/null 2>&1 | tr -d '\r' | grep -v '^^D$' > "$g"
    script -qec "$K kore stty $v; stty -a" /dev/null 2>&1 | tr -d '\r' | grep -v '^^D$' > "$o"; same "stty $v"
  done
fi
# who, users: one set of records -- a boot, a user, a session that ended, a getty --
# laid in the three shapes the hosts write. GNU reads the glibc one as we do, and the
# freebsd and netbsd files must say exactly what the glibc one says
# the bytes are love's to lay: printf's octal escapes are not in every shell's printf
cat > "$ho/.who-fix.l" <<EOF
(borrow 'posix)
(: (zb n) (? (n < 1) "" (string 0 + zb (n - 1)))
   (sz s n) (s + zb (n - #s))
   (le v n) (? (n < 1) "" (string (v & 255) + le (v >> 8) (n - 1)))
   (be v n) (? (n < 1) "" (be (v >> 8) (n - 1) + string (v & 255)))
   (gl r) (le (r 0) 2 + zb 2 + le (r 1) 4 + sz (r 2) 32 + sz (r 3) 4 + sz (r 4) 32
           + sz (r 5) 256 + zb 8 + le (r 6) 4 + zb 40)
   (fb r) (string ([0 0 1 0 0 0 6 4 7] (r 0)) + be (r 6 * 1000000) 8 + sz (r 3) 8
           + be (r 1) 4 + sz (r 4) 32 + sz (r 2) 16 + sz (r 5) 128)
   (nb r) (sz (r 4) 32 + sz (r 3) 4 + sz (r 2) 32 + sz (r 5) 256 + zb 2 + le (r 0) 2
           + le (r 1) 4 + zb 132 + le (r 6) 8 + zb 48)
   t0 1790206500
   rs [[2 0 "~" "~~" "reboot" "7.2.6-test" t0]
       [7 0 "pts/9997" "9997" "alice" "example.org" (t0 + 60)]
       [8 4242 "pts/9998" "9998" "" "" (t0 + 3600)]
       [6 77 "tty9" "9" "LOGIN" "" (t0 + 90)]]
   (lay p f) (: q (open p "w") _ (say q (foldl (\\ a r (a + f r)) "" rs)) (close q))
   _ (lay "$HO/.who-gl" gl) _ (lay "$HO/utx.who-fb" fb) _ (lay "$HO/.who-nb.utmpx" nb)
   0)
EOF
LOVE_NO_IMAGE= "$m" "$ho/.who-fix.l" || fail "who: the utmp fixtures"
[ "$(wc -c < "$ho/.who-gl")" -eq 1536 ] && [ "$(wc -c < "$ho/utx.who-fb")" -eq 788 ] \
  && [ "$(wc -c < "$ho/.who-nb.utmpx")" -eq 2080 ] || fail "who: the utmp fixtures' sizes"
for v in "" "-a" "-b" "-d" "-l" "-q" "-H" "-uT"; do
  if command -v who >/dev/null 2>&1; then
    TZ=UTC LC_ALL=C who $v "$ho/.who-gl" > "$g" 2>&1; korerun who $v "$ho/.who-gl" > "$o" 2>&1; same "who $v (glibc utmp)"
  fi
  korerun who $v "$ho/.who-gl" > "$g" 2>&1
  korerun who $v "$ho/utx.who-fb" > "$o" 2>&1; same "who $v (freebsd utx, as the glibc file)"
  korerun who $v "$ho/.who-nb.utmpx" > "$o" 2>&1; same "who $v (netbsd utmpx, as the glibc file)"
done
[ "$(korerun users "$ho/.who-gl")" = alice ] || fail "kore users FILE"
korerun who "$ho/.who-none" 2>/dev/null; r=$?; [ $r -eq 1 ] || fail "kore who: no such file is 1 (got $r)"
if command -v who >/dev/null 2>&1 && [ -r /run/utmp -o -r /var/run/utmp ]; then
  [ "$(korerun users)" = "$(users)" ] || fail "kore users vs the host's"
fi
# hostid and dnsdomainname: what the host's own name resolves to, as glibc reads it here
command -v hostid >/dev/null 2>&1 && { [ "$(korerun hostid)" = "$(hostid)" ] || fail "kore hostid vs GNU"; }
korerun hostid | grep -qx '[0-9a-f]\{8\}' || fail "kore hostid's shape"
command -v dnsdomainname >/dev/null 2>&1 \
  && { [ "$(korerun dnsdomainname)" = "$(dnsdomainname 2>/dev/null)" ] || fail "kore dnsdomainname vs the host's"; }
# setsid: the command leads a session of its own -- forked first where kore leads its
# group, straight through where it does not -- and the statuses are util-linux's
lead='set -- $(cat /proc/$$/stat); [ "$1" = "$6" ]'
if [ -r /proc/self/stat ]; then
  korerun setsid sh -c "$lead" || fail "kore setsid: not a session leader"
  korerun setsid -f -w sh -c "$lead" || fail "kore setsid -f: not a session leader"
fi
korerun setsid -w sh -c 'exit 5'; r=$?; [ $r -eq 5 ] || fail "kore setsid -w status (got $r)"
korerun setsid -f -w sh -c 'exit 6'; r=$?; [ $r -eq 6 ] || fail "kore setsid -fw status (got $r)"
korerun setsid nosuchcommand 2>/dev/null; r=$?; [ $r -eq 127 ] || fail "kore setsid: no such command is 127 (got $r)"
: > "$ho/.setsid-noexec"; chmod 644 "$ho/.setsid-noexec"
korerun setsid "$ho/.setsid-noexec" 2>/dev/null; r=$?; [ $r -eq 126 ] || fail "kore setsid: not executable is 126 (got $r)"
korerun setsid 2>/dev/null; r=$?; [ $r -eq 1 ] || fail "kore setsid: no command is 1 (got $r)"
# watch: the title procps lays, -g leaving once the output moves, -e on a failure, -x
# the words execed rather than sh -c'd
COLUMNS=60 korerun watch -g -n 0.1 'date +%s%N' > "$o" || fail "kore watch -g"
head -1 "$o" | grep -q 'Every 0\.1s: date +%s%N  *[^ ]*: ' || fail "kore watch's title"
COLUMNS=60 korerun watch -t -e -n 0.1 'echo hi; exit 2' > "$o"; r=$?
[ $r -eq 1 ] && grep -q hi "$o" && ! grep -q Every "$o" || fail "kore watch -te (got $r)"
COLUMNS=60 korerun watch -t -g -x -n 0.1 date +%N > /dev/null || fail "kore watch -x"
korerun watch 2>/dev/null; r=$?; [ $r -eq 1 ] || fail "kore watch: no command is 1 (got $r)"
# pinky: GNU's two faces over the host's own utmp and passwd (TZ=UTC: ours keeps no zones)
if command -v pinky >/dev/null 2>&1; then
  me=$(id -un)
  for v in "" -f -w -i -q "-s $me" nobody "-l $me" "-lb $me" "-lhp $me" "-l nosuchuser" -l; do
    # shellcheck disable=SC2086
    TZ=UTC LC_ALL=C pinky $v > "$g" 2>&1; rg=$?; korerun pinky $v > "$o" 2>&1; ro=$?
    same "pinky $v"; [ $rg -eq $ro ] || fail "kore pinky $v exit ($ro vs $rg)"
  done
fi
# ts: each line stamped, toybox's formats; since the start and between lines, the
# stamps are the elapsed time, zero here
[ "$(printf 'a\nb\n' | korerun ts -s)" = "00:00:00 a
00:00:00 b" ] || fail "kore ts -s"
printf 'a\n' | korerun ts -m -i | grep -qx '00:00:00\.[0-9][0-9][0-9] a' || fail "kore ts -m -i"
printf 'x\n' | korerun ts '%Y' | grep -qx '[0-9][0-9][0-9][0-9] x' || fail "kore ts FORMAT"
printf 'x\n' | korerun ts | grep -qx '[A-Z][a-z][a-z] [0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9] x' || fail "kore ts's default"
# usleep, reset, fsync
korerun usleep 1000 || fail "kore usleep"
korerun usleep x 2>/dev/null; r=$?; [ $r -eq 1 ] || fail "kore usleep x is 1 (got $r)"
[ "$(korerun reset < /dev/null | od -An -c | tr -d ' ')" = '033c' ] || fail "kore reset's RIS"
: > "$ho/.kore-fsync"; korerun fsync "$ho/.kore-fsync" || fail "kore fsync"
korerun fsync -d "$ho/.kore-fsync" "$ho/.kore-nosuch" 2>/dev/null; r=$?; [ $r -eq 1 ] || fail "kore fsync of no file is 1 (got $r)"
# kill -l's names both ways (a status past 128 its signal), -s SIG, -SIGNAME, a group by
# -PGID, and a dash word that is no signal refused
[ "$(korerun kill -l 9 15 137 KILL SIGTERM | tr '\n' ' ')" = "KILL TERM KILL 9 15 " ] || fail "kore kill -l"
[ "$(korerun kill -l | wc -l)" -ge 31 ] || fail "kore kill -l lists the table"
sleep 30 & kp=$!; korerun kill -s KILL $kp; wait $kp; r=$?; [ $r -eq 137 ] || fail "kore kill -s KILL ($r)"
sleep 30 & kp=$!; korerun kill -SIGTERM $kp; wait $kp; r=$?; [ $r -eq 143 ] || fail "kore kill -SIGTERM ($r)"
korerun kill -x 1 > /dev/null 2>&1; r=$?; [ $r -eq 1 ] || fail "kore kill -x ($r)"
echo "kore: process tools (env/printenv/sleep/kill/xargs/whoami/groups/arch/nproc/nohup/nice/renice/stty/who/users/hostid/dnsdomainname/setsid/watch/pinky/ts/usleep/reset/fsync) ok"
