#!/bin/sh
# test/kore/misc.sh -- dd, xxd, strings, cal, timeout, which, tty, clear, hostname
. "$(dirname "$0")/common.sh"

# dd: the data AND the two record lines. a partial block is the +1 column, which is
# the half of dd's report that a `bs=` a file does not divide by is the only way to see
for c in "bs=1 count=5" "bs=6 skip=1" "bs=7" "bs=1000" "bs=3 count=2"; do
  # shellcheck disable=SC2086
  dd if="$ho/.arc1" $c > "$g" 2>/dev/null
  # shellcheck disable=SC2086
  korerun dd if="$ho/.arc1" $c > "$o" 2>/dev/null
  same "dd $c"
  # shellcheck disable=SC2086
  dd if="$ho/.arc1" $c of=/dev/null 2>&1 | head -2 > "$g"
  # shellcheck disable=SC2086
  korerun dd if="$ho/.arc1" $c of=/dev/null 2>&1 | head -2 > "$o"
  same "dd records $c"
done
korerun dd if="$ho/.arc1" of="$ho/.ddout" bs=2 2>/dev/null || fail "kore dd of="
cmp -s "$ho/.arc1" "$ho/.ddout" || fail "kore dd if=/of= is a copy"
korerun dd if="$ho/.arc1" of=/dev/null status=none > "$o" 2>&1
[ -s "$o" ] && fail "kore dd status=none still spoke" || true
# xxd: vim's, where the box has it; the -r round trip stands on its own either way
dd if=/dev/urandom of="$ho/.xxbin" bs=311 count=1 2>/dev/null
if command -v xxd >/dev/null 2>&1; then
  for f in .arc1 .xxbin .gs4 .gs5; do
    xxd "$ho/$f" > "$g" 2>/dev/null; korerun xxd "$ho/$f" > "$o" 2>/dev/null
    same "xxd $f"
  done
  xxd "$ho/.xxbin" | korerun xxd -r > "$o" 2>/dev/null
  cmp -s "$ho/.xxbin" "$o" || fail "kore xxd -r over GNU's dump"
fi
korerun xxd "$ho/.xxbin" | korerun xxd -r > "$o" 2>/dev/null
cmp -s "$ho/.xxbin" "$o" || fail "kore xxd | xxd -r round trip"
# strings: the printable runs, the floor moving, and a real binary
printf 'ab\0hello world\0\1\2cd\0longenough\n' > "$ho/.strbin"
if command -v strings >/dev/null 2>&1; then
  for n in "" "-n 2" "-n10"; do
    # shellcheck disable=SC2086
    strings $n "$ho/.strbin" > "$g" 2>/dev/null
    # shellcheck disable=SC2086
    korerun strings $n "$ho/.strbin" > "$o" 2>/dev/null
    same "strings $n"
  done
  strings -n 12 "$m" > "$g" 2>/dev/null; korerun strings -n 12 "$m" > "$o" 2>/dev/null
  same "strings over love itself"
fi
# cal: SIX week rows always, each padded to 20, and the year three abreast -- the
# leap years come off udays and want no table, so february is where a wrong one shows
if command -v cal >/dev/null 2>&1 && cal 9 2026 >/dev/null 2>&1; then
  for d in "9 2026" "2 2024" "2 2100" "2 2000" "2 2021" "12 1999" "1 1970" "8 2027" "5 2026"; do
    # shellcheck disable=SC2086
    cal $d > "$g" 2>/dev/null
    # shellcheck disable=SC2086
    korerun cal $d > "$o" 2>/dev/null
    same "cal $d"
  done
  cal 2026 > "$g" 2>/dev/null; korerun cal 2026 > "$o" 2>/dev/null; same "cal 2026 (the year)"
fi
# timeout: 124 when the clock wins, the command's own status when it does not, and
# the whole point -- that it comes back at the deadline and not at the command's end
t0=$(date +%s)
korerun timeout 1 sleep 20 > /dev/null 2>&1; r=$?
t1=$(date +%s)
[ $r -eq 124 ] || fail "kore timeout: want 124 for a command the clock ended (got $r)"
[ $((t1 - t0)) -le 5 ] || fail "kore timeout waited $((t1 - t0))s for a 1s limit"
korerun timeout 9 sh -c 'exit 7' > /dev/null 2>&1; r=$?
[ $r -eq 7 ] || fail "kore timeout: a command that finishes keeps its status (got $r)"
[ "$(korerun timeout 9 echo hi 2>/dev/null)" = hi ] || fail "kore timeout: the output passes"
[ "$(korerun timeout 0 echo hi 2>/dev/null)" = hi ] || fail "kore timeout 0 is no limit"
korerun timeout -s KILL 1 sleep 20 > /dev/null 2>&1; r=$?
[ $r -eq 124 ] || fail "kore timeout -s KILL (got $r)"
korerun timeout -k 1 1 sleep 20 > /dev/null 2>&1; r=$?
[ $r -eq 124 ] || fail "kore timeout -k (got $r)"
korerun timeout 9 /nonexistent-xyzzy > /dev/null 2>&1; r=$?
[ $r -eq 127 ] || fail "kore timeout: a command that will not start is 127 (got $r)"
# which, tty, clear, hostname
if command -v which >/dev/null 2>&1; then
  both "which sh"    which sh
  both "which -a sh" which -a sh
fi
korerun which no-such-tool-xyzzy > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "kore which: an unfound name exits 1 (got $r)"
[ "$(korerun which /bin/sh 2>/dev/null)" = /bin/sh ] || fail "kore which: a path answers itself"
[ "$(korerun hostname 2>/dev/null)" = "$(korerun uname -n 2>/dev/null)" ] \
  || fail "kore hostname and uname -n read the one file"
[ "$(korerun tty < /dev/null 2>/dev/null)" = "not a tty" ] || fail "kore tty off a pipe"
korerun tty < /dev/null > /dev/null 2>&1; r=$?
[ $r -eq 1 ] || fail "kore tty: not a terminal is exit 1 (got $r)"
[ "$(korerun clear 2>/dev/null | wc -c)" = 11 ] || fail "kore clear: home, 2J and 3J"
# the three read no options at all, so a dash word is refused and not ignored
korerun tty -Z > "$o" 2>&1; r=$?
[ $r -eq 2 ] && grep -q 'unknown option' "$o" || fail "kore tty -Z must be refused"
echo "kore: dd, xxd, strings, cal, timeout, which, tty, clear, hostname ok"
