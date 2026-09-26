#!/bin/sh
# test/kore/proc.sh -- env, printenv, sleep, kill, xargs, whoami, groups, arch, nproc
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
echo "kore: process tools (env/printenv/sleep/kill/xargs/whoami/groups/arch/nproc/nohup) ok"
